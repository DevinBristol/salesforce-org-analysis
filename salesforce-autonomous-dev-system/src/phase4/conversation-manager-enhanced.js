/**
 * Enhanced Conversation Manager for Phase 4
 *
 * Advanced conversation management with:
 * - Database persistence
 * - Context memory with semantic search
 * - Conversation summarization
 * - Multi-session management
 * - Learning from past conversations
 */

import EventEmitter from 'events';

class EnhancedConversationManager extends EventEmitter {
    constructor(options = {}) {
        super();

        this.db = options.db;
        this.claudeClient = options.claudeClient;
        this.logger = options.logger || console;

        // Active conversations
        this.conversations = new Map();

        // Conversation configuration
        this.maxContextTokens = options.maxContextTokens || 100000;
        this.summaryThreshold = options.summaryThreshold || 50000;
        this.maxMessagesBeforeSummary = options.maxMessagesBeforeSummary || 50;

        // Memory configuration
        this.memoryEnabled = options.memoryEnabled !== false;
        this.maxMemoryItems = options.maxMemoryItems || 100;

        // Session timeout (default 4 hours)
        this.sessionTimeout = options.sessionTimeout || 4 * 60 * 60 * 1000;

        // Start cleanup interval
        this.cleanupInterval = setInterval(() => this.cleanupStaleSessions(), 30 * 60 * 1000);
    }

    /**
     * Get or create a conversation
     * @param {string} conversationId - Unique conversation identifier
     * @param {Object} options - Conversation options
     */
    async getOrCreateConversation(conversationId, options = {}) {
        // Check in-memory first
        if (this.conversations.has(conversationId)) {
            const conv = this.conversations.get(conversationId);
            conv.lastAccessed = Date.now();
            return conv;
        }

        // Try to load from database
        if (this.db) {
            const existing = await this.loadConversation(conversationId);
            if (existing) {
                this.conversations.set(conversationId, existing);
                return existing;
            }
        }

        // Create new conversation
        const conversation = {
            id: conversationId,
            userId: options.userId,
            channelId: options.channelId,
            threadId: options.threadId,
            taskType: options.taskType,
            messages: [],
            summary: null,
            context: {
                systemPrompt: options.systemPrompt || this.getDefaultSystemPrompt(options.taskType),
                metadata: options.metadata || {},
                memory: [],
                learnedFacts: []
            },
            state: {
                currentStage: null,
                pendingAction: null,
                variables: {}
            },
            metrics: {
                totalTokens: 0,
                messageCount: 0,
                summaryCount: 0
            },
            createdAt: new Date().toISOString(),
            lastAccessed: Date.now(),
            status: 'active'
        };

        this.conversations.set(conversationId, conversation);

        // Load relevant memories
        if (this.memoryEnabled && options.userId) {
            conversation.context.memory = await this.loadRelevantMemories(
                options.userId,
                options.taskType
            );
        }

        // Persist new conversation
        if (this.db) {
            await this.persistConversation(conversation);
        }

        this.emit('conversation:created', { conversationId, conversation });

        return conversation;
    }

    /**
     * Get default system prompt based on task type
     */
    getDefaultSystemPrompt(taskType) {
        const prompts = {
            analysis: `You are an expert Salesforce developer assistant specializing in code analysis.
                      Analyze code for best practices, security vulnerabilities, performance issues, and maintainability.
                      Provide detailed, actionable recommendations with specific code examples.`,

            improvement: `You are an expert Salesforce developer assistant specializing in code improvement.
                         Help improve code quality, implement best practices, and add features.
                         Always explain your changes and their benefits.`,

            debugging: `You are an expert Salesforce debugging assistant.
                       Help identify and fix bugs in Apex, LWC, and other Salesforce code.
                       Explain root causes and provide comprehensive fixes.`,

            documentation: `You are a technical documentation specialist for Salesforce.
                          Generate clear, comprehensive documentation for Salesforce code and processes.
                          Include examples, diagrams where helpful, and best practices.`,

            default: `You are an expert Salesforce development assistant.
                     Help with any Salesforce development tasks including Apex, LWC, Flows, and configuration.
                     Provide detailed, accurate, and helpful responses.`
        };

        return prompts[taskType] || prompts.default;
    }

    /**
     * Add a message to the conversation
     * @param {string} conversationId - Conversation identifier
     * @param {Object} message - Message to add
     */
    async addMessage(conversationId, message) {
        const conversation = await this.getOrCreateConversation(conversationId);

        const enrichedMessage = {
            id: `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            role: message.role, // 'user', 'assistant', 'system'
            content: message.content,
            timestamp: new Date().toISOString(),
            tokens: this.estimateTokens(message.content),
            metadata: message.metadata || {}
        };

        conversation.messages.push(enrichedMessage);
        conversation.metrics.totalTokens += enrichedMessage.tokens;
        conversation.metrics.messageCount++;
        conversation.lastAccessed = Date.now();

        // Check if we need to summarize
        if (this.shouldSummarize(conversation)) {
            await this.summarizeConversation(conversationId);
        }

        // Extract and store facts/learnings
        if (this.memoryEnabled && message.role === 'assistant') {
            await this.extractAndStoreFacts(conversation, message.content);
        }

        // Persist update
        if (this.db) {
            await this.persistMessage(conversationId, enrichedMessage);
        }

        this.emit('message:added', { conversationId, message: enrichedMessage });

        return enrichedMessage;
    }

    /**
     * Check if conversation needs summarization
     */
    shouldSummarize(conversation) {
        return conversation.metrics.totalTokens > this.summaryThreshold ||
               conversation.messages.length > this.maxMessagesBeforeSummary;
    }

    /**
     * Summarize older messages to reduce context
     */
    async summarizeConversation(conversationId) {
        const conversation = this.conversations.get(conversationId);
        if (!conversation || !this.claudeClient) return;

        // Keep last 10 messages
        const keepMessages = 10;
        const messagesToSummarize = conversation.messages.slice(0, -keepMessages);

        if (messagesToSummarize.length < 5) return;

        this.logger.info(`[ConversationManager] Summarizing ${messagesToSummarize.length} messages for ${conversationId}`);

        try {
            const summaryPrompt = `Summarize the following conversation, preserving:
1. Key decisions made
2. Important information shared
3. Current task context
4. Any pending actions or questions

Conversation:
${messagesToSummarize.map(m => `${m.role}: ${m.content}`).join('\n\n')}

Provide a concise but comprehensive summary:`;

            const response = await this.claudeClient.messages.create({
                model: 'claude-sonnet-4-20250514',
                max_tokens: 2000,
                messages: [{ role: 'user', content: summaryPrompt }]
            });

            const newSummary = response.content[0].text;

            // Combine with existing summary if present
            if (conversation.summary) {
                conversation.summary = `Previous context:\n${conversation.summary}\n\nRecent context:\n${newSummary}`;
            } else {
                conversation.summary = newSummary;
            }

            // Remove summarized messages but keep recent ones
            conversation.messages = conversation.messages.slice(-keepMessages);

            // Recalculate tokens
            conversation.metrics.totalTokens = conversation.messages.reduce(
                (sum, m) => sum + m.tokens, 0
            ) + this.estimateTokens(conversation.summary);

            conversation.metrics.summaryCount++;

            // Persist summary
            if (this.db) {
                await this.persistConversation(conversation);
            }

            this.emit('conversation:summarized', { conversationId, summary: newSummary });

        } catch (error) {
            this.logger.error(`[ConversationManager] Summarization failed: ${error.message}`);
        }
    }

    /**
     * Extract facts and learnings from assistant responses
     */
    async extractAndStoreFacts(conversation, content) {
        if (!this.claudeClient) return;

        // Only extract facts occasionally to save API calls
        if (conversation.metrics.messageCount % 5 !== 0) return;

        try {
            const extractPrompt = `Extract any important facts, preferences, or learnings from this response that should be remembered for future conversations.

Response:
${content.substring(0, 3000)}

If there are facts worth remembering, list them as JSON:
{"facts": ["fact 1", "fact 2"]}

If nothing worth remembering, return: {"facts": []}`;

            const response = await this.claudeClient.messages.create({
                model: 'claude-sonnet-4-20250514',
                max_tokens: 500,
                messages: [{ role: 'user', content: extractPrompt }]
            });

            const result = JSON.parse(response.content[0].text);

            if (result.facts && result.facts.length > 0) {
                conversation.context.learnedFacts.push(...result.facts);

                // Persist facts to user's memory
                if (this.db && conversation.userId) {
                    for (const fact of result.facts) {
                        await this.persistMemory(conversation.userId, {
                            type: 'learned_fact',
                            content: fact,
                            taskType: conversation.taskType,
                            conversationId: conversation.id
                        });
                    }
                }
            }
        } catch (error) {
            // Silently fail - fact extraction is optional
            this.logger.debug(`[ConversationManager] Fact extraction failed: ${error.message}`);
        }
    }

    /**
     * Get conversation context for Claude API
     */
    async getContextForApi(conversationId) {
        const conversation = await this.getOrCreateConversation(conversationId);

        const messages = [];

        // Add summary as system context if present
        if (conversation.summary) {
            messages.push({
                role: 'user',
                content: `[Previous conversation summary]\n${conversation.summary}`
            });
            messages.push({
                role: 'assistant',
                content: 'I understand the context from our previous conversation. How can I help you now?'
            });
        }

        // Add relevant memories
        if (conversation.context.memory.length > 0) {
            const memoryContext = conversation.context.memory
                .map(m => `- ${m.content}`)
                .join('\n');

            messages.push({
                role: 'user',
                content: `[Relevant context from previous sessions]\n${memoryContext}`
            });
            messages.push({
                role: 'assistant',
                content: 'I\'ll keep this context in mind.'
            });
        }

        // Add conversation messages
        for (const msg of conversation.messages) {
            messages.push({
                role: msg.role,
                content: msg.content
            });
        }

        return {
            systemPrompt: conversation.context.systemPrompt,
            messages,
            state: conversation.state,
            metadata: conversation.context.metadata
        };
    }

    /**
     * Update conversation state
     */
    async updateState(conversationId, stateUpdate) {
        const conversation = await this.getOrCreateConversation(conversationId);

        Object.assign(conversation.state, stateUpdate);

        if (this.db) {
            await this.persistConversation(conversation);
        }

        this.emit('state:updated', { conversationId, state: conversation.state });
    }

    /**
     * Estimate token count for text
     */
    estimateTokens(text) {
        if (!text) return 0;
        // Rough estimate: ~4 characters per token
        return Math.ceil(text.length / 4);
    }

    /**
     * Load conversation from database
     */
    async loadConversation(conversationId) {
        if (!this.db) return null;

        const query = `
            SELECT * FROM conversations WHERE id = $1
        `;

        const result = await this.db.query(query, [conversationId]);

        if (result.rows.length === 0) return null;

        const row = result.rows[0];

        // Load messages
        const messagesQuery = `
            SELECT * FROM conversation_messages
            WHERE conversation_id = $1
            ORDER BY created_at ASC
        `;
        const messagesResult = await this.db.query(messagesQuery, [conversationId]);

        return {
            id: row.id,
            userId: row.user_id,
            channelId: row.channel_id,
            threadId: row.thread_id,
            taskType: row.task_type,
            messages: messagesResult.rows.map(m => ({
                id: m.id,
                role: m.role,
                content: m.content,
                timestamp: m.created_at,
                tokens: m.tokens,
                metadata: m.metadata || {}
            })),
            summary: row.summary,
            context: JSON.parse(row.context || '{}'),
            state: JSON.parse(row.state || '{}'),
            metrics: JSON.parse(row.metrics || '{}'),
            createdAt: row.created_at,
            lastAccessed: Date.now(),
            status: row.status
        };
    }

    /**
     * Persist conversation to database
     */
    async persistConversation(conversation) {
        if (!this.db) return;

        const query = `
            INSERT INTO conversations (id, user_id, channel_id, thread_id, task_type, summary, context, state, metrics, status, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW())
            ON CONFLICT (id) DO UPDATE SET
                summary = $6,
                context = $7,
                state = $8,
                metrics = $9,
                status = $10,
                updated_at = NOW()
        `;

        await this.db.query(query, [
            conversation.id,
            conversation.userId,
            conversation.channelId,
            conversation.threadId,
            conversation.taskType,
            conversation.summary,
            JSON.stringify(conversation.context),
            JSON.stringify(conversation.state),
            JSON.stringify(conversation.metrics),
            conversation.status,
            conversation.createdAt
        ]);
    }

    /**
     * Persist a single message
     */
    async persistMessage(conversationId, message) {
        if (!this.db) return;

        const query = `
            INSERT INTO conversation_messages (id, conversation_id, role, content, tokens, metadata, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
        `;

        await this.db.query(query, [
            message.id,
            conversationId,
            message.role,
            message.content,
            message.tokens,
            JSON.stringify(message.metadata),
            message.timestamp
        ]);
    }

    /**
     * Load relevant memories for a user/task
     */
    async loadRelevantMemories(userId, taskType) {
        if (!this.db) return [];

        const query = `
            SELECT content, task_type, relevance_score
            FROM user_memories
            WHERE user_id = $1
            AND (task_type = $2 OR task_type IS NULL)
            ORDER BY relevance_score DESC, created_at DESC
            LIMIT $3
        `;

        const result = await this.db.query(query, [userId, taskType, this.maxMemoryItems]);

        return result.rows.map(row => ({
            content: row.content,
            taskType: row.task_type,
            relevanceScore: row.relevance_score
        }));
    }

    /**
     * Persist a memory item
     */
    async persistMemory(userId, memory) {
        if (!this.db) return;

        const query = `
            INSERT INTO user_memories (user_id, type, content, task_type, conversation_id, relevance_score, created_at)
            VALUES ($1, $2, $3, $4, $5, 1.0, NOW())
        `;

        await this.db.query(query, [
            userId,
            memory.type,
            memory.content,
            memory.taskType,
            memory.conversationId
        ]);
    }

    /**
     * Search conversations by content
     */
    async searchConversations(userId, searchQuery, options = {}) {
        if (!this.db) return [];

        const query = `
            SELECT c.id, c.task_type, c.summary, c.created_at,
                   (SELECT COUNT(*) FROM conversation_messages WHERE conversation_id = c.id) as message_count
            FROM conversations c
            WHERE c.user_id = $1
            AND (
                c.summary ILIKE $2
                OR EXISTS (
                    SELECT 1 FROM conversation_messages cm
                    WHERE cm.conversation_id = c.id
                    AND cm.content ILIKE $2
                )
            )
            ORDER BY c.created_at DESC
            LIMIT $3
        `;

        const result = await this.db.query(query, [
            userId,
            `%${searchQuery}%`,
            options.limit || 20
        ]);

        return result.rows;
    }

    /**
     * Close a conversation
     */
    async closeConversation(conversationId, reason = 'completed') {
        const conversation = this.conversations.get(conversationId);
        if (!conversation) return;

        conversation.status = 'closed';
        conversation.closedAt = new Date().toISOString();
        conversation.closeReason = reason;

        if (this.db) {
            await this.persistConversation(conversation);
        }

        this.emit('conversation:closed', { conversationId, reason });

        // Remove from active conversations
        this.conversations.delete(conversationId);
    }

    /**
     * Clean up stale sessions
     */
    cleanupStaleSessions() {
        const now = Date.now();
        let cleaned = 0;

        for (const [id, conv] of this.conversations) {
            if (now - conv.lastAccessed > this.sessionTimeout) {
                this.closeConversation(id, 'timeout');
                cleaned++;
            }
        }

        if (cleaned > 0) {
            this.logger.info(`[ConversationManager] Cleaned up ${cleaned} stale sessions`);
        }
    }

    /**
     * Get conversation statistics
     */
    async getStats(userId = null) {
        const stats = {
            activeConversations: this.conversations.size,
            totalMessages: 0,
            totalTokens: 0
        };

        for (const conv of this.conversations.values()) {
            if (!userId || conv.userId === userId) {
                stats.totalMessages += conv.metrics.messageCount;
                stats.totalTokens += conv.metrics.totalTokens;
            }
        }

        if (this.db && userId) {
            const dbStats = await this.db.query(`
                SELECT
                    COUNT(DISTINCT c.id) as total_conversations,
                    COUNT(cm.id) as total_messages
                FROM conversations c
                LEFT JOIN conversation_messages cm ON c.id = cm.conversation_id
                WHERE c.user_id = $1
            `, [userId]);

            if (dbStats.rows.length > 0) {
                stats.historicalConversations = parseInt(dbStats.rows[0].total_conversations);
                stats.historicalMessages = parseInt(dbStats.rows[0].total_messages);
            }
        }

        return stats;
    }

    /**
     * Export conversation history
     */
    async exportConversation(conversationId, format = 'json') {
        const conversation = await this.getOrCreateConversation(conversationId);

        if (format === 'json') {
            return JSON.stringify(conversation, null, 2);
        }

        if (format === 'markdown') {
            let md = `# Conversation: ${conversationId}\n\n`;
            md += `**Created:** ${conversation.createdAt}\n`;
            md += `**Task Type:** ${conversation.taskType || 'General'}\n\n`;

            if (conversation.summary) {
                md += `## Summary\n${conversation.summary}\n\n`;
            }

            md += `## Messages\n\n`;
            for (const msg of conversation.messages) {
                const role = msg.role === 'user' ? '**User**' : '**Assistant**';
                md += `### ${role} (${msg.timestamp})\n${msg.content}\n\n`;
            }

            return md;
        }

        throw new Error(`Unsupported export format: ${format}`);
    }

    /**
     * Shutdown manager
     */
    async shutdown() {
        clearInterval(this.cleanupInterval);

        // Persist all active conversations
        for (const [id, conv] of this.conversations) {
            if (this.db) {
                await this.persistConversation(conv);
            }
        }

        this.conversations.clear();
        this.removeAllListeners();

        this.logger.info('[ConversationManager] Shutdown complete');
    }
}

export { EnhancedConversationManager };
