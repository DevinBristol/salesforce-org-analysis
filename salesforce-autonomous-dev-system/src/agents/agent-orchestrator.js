// src/agents/agent-orchestrator.js - Main Agent Orchestrator Integration
// Integrates the new multi-agent system with the existing infrastructure

import { EventEmitter } from 'events';
import { Anthropic } from '@anthropic-ai/sdk';
import { LeadAgent } from './lead-agent.js';
import { createSalesforceTools } from '../core/tool-definitions.js';
import {
    REFACTOR_SYSTEM_PROMPT,
    GREENFIELD_SYSTEM_PROMPT,
    TEST_GENERATION_PROMPT
} from '../prompts/salesforce-examples.js';

/**
 * AgentOrchestrator - Main entry point for the upgraded agent system
 *
 * This class provides a drop-in replacement for the previous linear
 * task processing, now powered by:
 * 1. Extended thinking for planning (Opus)
 * 2. Parallel subagents for execution (Sonnet)
 * 3. ReAct loops for tool use
 * 4. Verification and iteration
 */
export class AgentOrchestrator extends EventEmitter {
    constructor(options = {}) {
        super();

        this.logger = options.logger;
        this.salesforceManager = options.salesforceManager;
        this.aiCodeGenerator = options.aiCodeGenerator;
        this.deploymentPipeline = options.deploymentPipeline;

        // Initialize Anthropic client
        this.anthropic = options.anthropic || new Anthropic({
            apiKey: process.env.ANTHROPIC_API_KEY,
            timeout: 180000, // 3 minutes for complex tasks
            maxRetries: 3
        });

        // Model configuration - use tiered approach
        this.models = {
            orchestrator: 'claude-opus-4-20250514',    // Lead agent - complex planning
            worker: 'claude-sonnet-4-20250514',        // Subagents - code generation
            validator: 'claude-haiku-4-20250514'       // Quick validation checks
        };

        // Create tools for agents
        this.tools = createSalesforceTools(
            this.salesforceManager,
            this.aiCodeGenerator,
            this.deploymentPipeline
        );

        // Initialize lead agent
        this.leadAgent = new LeadAgent({
            anthropic: this.anthropic,
            logger: this.logger,
            model: this.models.orchestrator,
            subagentModel: this.models.worker,
            tools: this.tools,
            maxSubagents: 5
        });

        // Wire up events
        this.setupEventForwarding();

        // Task tracking
        this.activeTasks = new Map();
        this.taskHistory = [];
    }

    /**
     * Process a task using the multi-agent system
     * @param {Object} task - Task to process
     * @returns {Object} Processing result
     */
    async processTask(task) {
        const taskId = task.id || `task-${Date.now()}`;
        this.logger?.info(`AgentOrchestrator processing task: ${taskId}`);

        this.activeTasks.set(taskId, {
            task,
            status: 'processing',
            startTime: Date.now()
        });

        try {
            // Determine task type and prepare context
            const context = await this.prepareContext(task);

            // Add system prompts based on task type
            context.systemPrompt = this.getSystemPrompt(task.type || context.inferredType);

            // Execute through lead agent
            const result = await this.leadAgent.execute(task, context);

            // Post-process result
            const processedResult = await this.postProcess(result, task);

            // Update tracking
            this.activeTasks.set(taskId, {
                task,
                status: 'completed',
                result: processedResult,
                endTime: Date.now()
            });

            // Store in history
            this.taskHistory.push({
                taskId,
                task,
                result: processedResult,
                timestamp: new Date().toISOString()
            });

            return processedResult;

        } catch (error) {
            this.logger?.error(`AgentOrchestrator error for ${taskId}:`, error);

            this.activeTasks.set(taskId, {
                task,
                status: 'failed',
                error: error.message,
                endTime: Date.now()
            });

            return {
                success: false,
                taskId,
                error: error.message
            };
        }
    }

    /**
     * Prepare context for task execution
     */
    async prepareContext(task) {
        const context = {
            targetOrg: task.targetOrg || 'dev-sandbox',
            existingCode: {},
            orgMetadata: {}
        };

        // Fetch existing code if this is a refactor task
        if (task.className || task.description?.includes('refactor') || task.description?.includes('improve')) {
            context.inferredType = 'refactor';

            if (task.className) {
                try {
                    const code = await this.salesforceManager?.getApexClass(task.className, context.targetOrg);
                    context.existingCode[task.className] = code?.body;

                    // Also fetch related classes
                    const related = await this.salesforceManager?.getRelatedClasses(task.className, context.targetOrg);
                    if (related) {
                        Object.assign(context.existingCode, related);
                    }
                } catch (error) {
                    this.logger?.warn(`Could not fetch existing code for ${task.className}:`, error.message);
                }
            }
        } else if (task.description?.includes('test')) {
            context.inferredType = 'test';
        } else {
            context.inferredType = 'greenfield';
        }

        return context;
    }

    /**
     * Get appropriate system prompt for task type
     */
    getSystemPrompt(taskType) {
        switch (taskType) {
            case 'refactor':
            case 'improve':
                return REFACTOR_SYSTEM_PROMPT;
            case 'test':
                return TEST_GENERATION_PROMPT;
            case 'greenfield':
            default:
                return GREENFIELD_SYSTEM_PROMPT;
        }
    }

    /**
     * Post-process agent result for compatibility with existing system
     */
    async postProcess(result, task) {
        if (!result.success) {
            return result;
        }

        // Extract artifacts from the synthesized result
        const artifacts = this.extractArtifacts(result.result);

        // Validate generated code
        if (artifacts.apex && Object.keys(artifacts.apex).length > 0) {
            const validation = await this.validateArtifacts(artifacts);
            artifacts.validation = validation;
        }

        // Calculate cost
        const cost = this.calculateCost(result.usage);

        return {
            success: true,
            taskId: result.taskId,
            artifacts,
            thinking: result.thinking,
            evaluation: result.evaluation,
            phases: result.phases,
            cost,
            usage: result.usage
        };
    }

    /**
     * Extract code artifacts from synthesized result
     */
    extractArtifacts(synthesisResult) {
        if (!synthesisResult) {
            return { apex: {}, tests: {}, metadata: {} };
        }

        // Handle if result is already in artifact format
        if (synthesisResult.apex || synthesisResult.tests) {
            return {
                apex: synthesisResult.apex || {},
                tests: synthesisResult.tests || {},
                metadata: synthesisResult.metadata || {},
                instructions: synthesisResult.instructions || ''
            };
        }

        // Handle combined output from synthesis
        if (synthesisResult.combinedOutput) {
            return this.extractArtifacts(synthesisResult.combinedOutput);
        }

        // Try to extract from findings
        const artifacts = { apex: {}, tests: {}, metadata: {} };

        if (Array.isArray(synthesisResult.findings)) {
            for (const finding of synthesisResult.findings) {
                if (finding.apex) Object.assign(artifacts.apex, finding.apex);
                if (finding.tests) Object.assign(artifacts.tests, finding.tests);
                if (finding.metadata) Object.assign(artifacts.metadata, finding.metadata);
            }
        }

        return artifacts;
    }

    /**
     * Validate generated artifacts
     */
    async validateArtifacts(artifacts) {
        const validation = {
            apex: [],
            tests: [],
            overall: 'unknown'
        };

        // Validate each Apex file
        for (const [fileName, code] of Object.entries(artifacts.apex || {})) {
            try {
                const result = await this.salesforceManager?.validateApex(code, fileName);
                validation.apex.push({
                    file: fileName,
                    valid: result?.success !== false,
                    errors: result?.errors || [],
                    warnings: result?.warnings || []
                });
            } catch (error) {
                validation.apex.push({
                    file: fileName,
                    valid: false,
                    errors: [error.message]
                });
            }
        }

        // Determine overall validation status
        const hasErrors = validation.apex.some(v => !v.valid);
        validation.overall = hasErrors ? 'failed' : 'passed';

        return validation;
    }

    /**
     * Calculate cost from usage
     */
    calculateCost(usage) {
        if (!usage) return { total: 0 };

        // Pricing per 1K tokens (approximate)
        const pricing = {
            'claude-opus-4-20250514': { input: 0.015, output: 0.075 },
            'claude-sonnet-4-20250514': { input: 0.003, output: 0.015 },
            'claude-haiku-4-20250514': { input: 0.00025, output: 0.00125 }
        };

        // Use Sonnet pricing as default (most common)
        const price = pricing['claude-sonnet-4-20250514'];

        const inputCost = ((usage.totalInput || 0) / 1000) * price.input;
        const outputCost = ((usage.totalOutput || 0) / 1000) * price.output;

        return {
            inputTokens: usage.totalInput || 0,
            outputTokens: usage.totalOutput || 0,
            inputCost: inputCost.toFixed(4),
            outputCost: outputCost.toFixed(4),
            total: (inputCost + outputCost).toFixed(4)
        };
    }

    /**
     * Forward events from lead agent
     */
    setupEventForwarding() {
        const eventsToForward = [
            'task:start', 'task:complete', 'task:error',
            'phase', 'plan:created',
            'subagent:spawn', 'subagent:complete', 'subagent:error'
        ];

        for (const event of eventsToForward) {
            this.leadAgent.on(event, (data) => {
                this.emit(event, data);
            });
        }
    }

    /**
     * Get status of active tasks
     */
    getActiveTasks() {
        const tasks = [];
        for (const [id, data] of this.activeTasks) {
            tasks.push({
                id,
                status: data.status,
                startTime: data.startTime,
                endTime: data.endTime,
                duration: data.endTime ? data.endTime - data.startTime : Date.now() - data.startTime
            });
        }
        return tasks;
    }

    /**
     * Get task history
     */
    getTaskHistory(limit = 10) {
        return this.taskHistory.slice(-limit);
    }
}

export default AgentOrchestrator;
