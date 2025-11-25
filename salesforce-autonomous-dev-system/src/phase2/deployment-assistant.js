// src/phase2/deployment-assistant.js
// Claude-Powered Deployment Assistant for Natural Language Deployment Controls

import { Anthropic } from '@anthropic-ai/sdk';
import { z } from 'zod';
import { trackApiUsage } from '../utils/ai-cost-tracker.js';

// Schema for deployment decision
const DeploymentDecisionSchema = z.object({
    action: z.enum([
        'deploy',
        'rollback',
        'schedule',
        'validate',
        'status',
        'list-snapshots',
        'explain',
        'abort',
        'clarify'
    ]),
    confidence: z.number().min(0).max(1),
    parameters: z.object({
        targetOrg: z.string().nullable().optional(),
        snapshotId: z.string().nullable().optional(),
        scheduledTime: z.string().nullable().optional(),
        deploymentId: z.string().nullable().optional(),
        force: z.boolean().optional(),
        skipTests: z.boolean().optional(),
        skipValidation: z.boolean().optional()
    }),
    reasoning: z.string(),
    warningLevel: z.enum(['none', 'low', 'medium', 'high', 'critical']),
    warnings: z.array(z.string()),
    confirmationRequired: z.boolean(),
    confirmationMessage: z.string().nullable(),
    responseMessage: z.string()
});

/**
 * DeploymentAssistant - Claude-powered deployment control interface
 * Provides natural language understanding for deployment operations
 */
export class DeploymentAssistant {
    constructor(deploymentPipeline, logger) {
        this.deploymentPipeline = deploymentPipeline;
        this.logger = logger;
        this.anthropic = new Anthropic({
            apiKey: process.env.ANTHROPIC_API_KEY,
            timeout: 120000,
            maxRetries: 3
        });

        // Conversation state per user
        this.conversations = new Map();

        // Pending confirmations
        this.pendingConfirmations = new Map();
    }

    /**
     * Process a natural language deployment command
     */
    async processCommand(userId, message, context = {}) {
        try {
            // Get conversation history
            const history = this.getConversationHistory(userId);

            // Get current system state
            const systemState = await this.getDeploymentState();

            // Parse intent with Claude
            const decision = await this.parseDeploymentIntent(message, history, systemState, context);

            // Add to conversation history
            this.addToHistory(userId, 'user', message);

            // Check if confirmation required
            if (decision.confirmationRequired) {
                this.pendingConfirmations.set(userId, {
                    decision,
                    timestamp: Date.now(),
                    expiresIn: 60000 // 1 minute
                });
                this.addToHistory(userId, 'assistant', decision.confirmationMessage);
                return {
                    type: 'confirmation_required',
                    message: decision.confirmationMessage,
                    warnings: decision.warnings,
                    warningLevel: decision.warningLevel
                };
            }

            // Execute the action
            const result = await this.executeAction(decision, userId);

            this.addToHistory(userId, 'assistant', result.message);

            return result;

        } catch (error) {
            this.logger.error('Deployment assistant error:', error);
            return {
                type: 'error',
                message: `Sorry, I encountered an error: ${error.message}`,
                success: false
            };
        }
    }

    /**
     * Handle confirmation response
     */
    async handleConfirmation(userId, response) {
        const pending = this.pendingConfirmations.get(userId);

        if (!pending) {
            return {
                type: 'error',
                message: 'No pending confirmation found. Please start a new request.'
            };
        }

        // Check expiration
        if (Date.now() - pending.timestamp > pending.expiresIn) {
            this.pendingConfirmations.delete(userId);
            return {
                type: 'expired',
                message: 'Confirmation expired. Please start a new request.'
            };
        }

        const lowerResponse = response.toLowerCase().trim();

        // Check for approval
        const approvalPatterns = /^(yes|approve|confirm|deploy|ok|do it|proceed|go|execute)/i;
        const cancelPatterns = /^(no|cancel|abort|stop|dont|don't|nevermind)/i;

        if (approvalPatterns.test(lowerResponse)) {
            this.pendingConfirmations.delete(userId);
            return await this.executeAction(pending.decision, userId);
        }

        if (cancelPatterns.test(lowerResponse)) {
            this.pendingConfirmations.delete(userId);
            return {
                type: 'cancelled',
                message: 'Action cancelled.',
                success: true
            };
        }

        // Unclear response
        return {
            type: 'clarification_needed',
            message: `I didn't understand. Please say "yes" to proceed or "cancel" to abort.`
        };
    }

    /**
     * Parse deployment intent using Claude
     */
    async parseDeploymentIntent(message, history, systemState, context) {
        const systemPrompt = this.buildSystemPrompt(systemState);
        const userPrompt = this.buildUserPrompt(message, history, context);

        const response = await this.anthropic.messages.create({
            model: 'claude-sonnet-4-20250514',
            max_tokens: 2000,
            temperature: 0.2,
            system: [
                {
                    type: "text",
                    text: systemPrompt,
                    cache_control: { type: "ephemeral" }
                }
            ],
            messages: [{ role: 'user', content: userPrompt }]
        }, {
            headers: {
                'anthropic-beta': 'prompt-caching-2024-07-31'
            }
        });

        // Track API usage
        trackApiUsage(response);

        // Parse response
        let responseText = response.content[0].text;
        responseText = responseText.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();

        const rawData = JSON.parse(responseText);
        const result = DeploymentDecisionSchema.safeParse(rawData);

        if (!result.success) {
            this.logger.error('Deployment decision schema validation failed:', result.error.errors);
            return this.createFallbackDecision(message);
        }

        return result.data;
    }

    buildSystemPrompt(systemState) {
        return `You are a Salesforce Deployment Assistant. You help users manage deployments safely and efficiently through natural conversation.

**CURRENT SYSTEM STATE:**
- Whitelisted Sandboxes: ${systemState.sandboxWhitelist.join(', ')}
- Available Snapshots: ${systemState.snapshotCount}
- Circuit Breaker: ${systemState.circuitBreakerOpen ? 'OPEN (deployments blocked)' : 'CLOSED (normal)'}
- Recent Failures: ${systemState.recentFailures}
- Deployment Window: ${systemState.isWithinWindow ? 'OPEN' : 'CLOSED'}
- Pending Deployments: ${systemState.pendingDeployments}

**AVAILABLE ACTIONS:**

1. **deploy** - Deploy code to sandbox
   - Parameters: targetOrg, force, skipTests, skipValidation
   - ALWAYS requires confirmation unless explicitly skipped
   - Default targetOrg is "Devin1"

2. **rollback** - Rollback to previous state
   - Parameters: snapshotId (optional - uses latest if not specified), targetOrg
   - ALWAYS requires confirmation
   - High warning level

3. **schedule** - Schedule a deployment for later
   - Parameters: targetOrg, scheduledTime
   - Parse times like "tomorrow at 2pm", "in 3 hours", "Sunday 6am"

4. **validate** - Run validation without deploying
   - Parameters: targetOrg
   - No confirmation needed

5. **status** - Show deployment status
   - No parameters needed
   - No confirmation needed

6. **list-snapshots** - List available rollback points
   - Parameters: targetOrg (optional)
   - No confirmation needed

7. **explain** - Explain a concept or status
   - No parameters needed
   - No confirmation needed

8. **abort** - User wants to cancel/abort
   - No parameters needed

9. **clarify** - Need more information
   - Ask clarifying question

**SAFETY RULES:**
1. NEVER allow deployment to production orgs
2. If target org is not whitelisted, require explicit force=true
3. Rollbacks should ALWAYS warn about data implications
4. If circuit breaker is open, explain why and suggest waiting

**CONFIRMATION LEVELS:**
- deploy with tests: Medium confirmation
- deploy without tests: High confirmation + warning
- rollback: High confirmation + data warning
- schedule: Low confirmation

**WARNING LEVELS:**
- none: Informational commands (status, explain)
- low: Safe operations (validate, list)
- medium: Standard deployments
- high: Risky operations (skip tests, force)
- critical: Dangerous operations (rollback with data, production indicators)

**NATURAL LANGUAGE EXAMPLES:**

"Deploy my changes" →
  action: deploy, targetOrg: "Devin1", confirmationRequired: true

"Deploy to sandbox but skip the tests" →
  action: deploy, skipTests: true, warningLevel: high, warnings: ["Skipping tests is risky"]

"Rollback the last deployment" →
  action: rollback, snapshotId: null (latest), confirmationRequired: true, warningLevel: high

"What deployments are available to rollback?" →
  action: list-snapshots, confirmationRequired: false

"Schedule a deployment for tomorrow morning" →
  action: schedule, scheduledTime: parse to ISO, confirmationRequired: true

"Is it safe to deploy right now?" →
  action: explain, responseMessage: explanation of current state

**RESPONSE FORMAT:**
{
    "action": "deploy|rollback|schedule|validate|status|list-snapshots|explain|abort|clarify",
    "confidence": 0.95,
    "parameters": {
        "targetOrg": "Devin1",
        "snapshotId": null,
        "scheduledTime": null,
        "force": false,
        "skipTests": false,
        "skipValidation": false
    },
    "reasoning": "User wants to deploy changes to default sandbox",
    "warningLevel": "medium",
    "warnings": ["Consider running tests before deploying"],
    "confirmationRequired": true,
    "confirmationMessage": "Deploy to Devin1 sandbox with test execution. Proceed?",
    "responseMessage": "I'll deploy your changes to Devin1 and run all tests."
}`;
    }

    buildUserPrompt(message, history, context) {
        let prompt = `Parse this deployment request:\n\n`;
        prompt += `**User Message:** "${message}"\n\n`;

        if (history.length > 0) {
            prompt += `**Recent Conversation:**\n`;
            history.slice(-5).forEach(msg => {
                prompt += `${msg.role === 'user' ? 'User' : 'Assistant'}: ${msg.content}\n`;
            });
            prompt += `\n`;
        }

        if (context.lastDeployment) {
            prompt += `**Last Deployment:** ${context.lastDeployment.id} (${context.lastDeployment.status})\n`;
        }

        if (context.artifacts) {
            prompt += `**Pending Artifacts:** ${context.artifacts.length} files\n`;
        }

        prompt += `\nParse the intent and return JSON.`;
        return prompt;
    }

    /**
     * Execute the parsed deployment action
     */
    async executeAction(decision, userId) {
        const { action, parameters } = decision;

        try {
            switch (action) {
                case 'deploy':
                    return await this.executeDeploy(parameters, userId);

                case 'rollback':
                    return await this.executeRollback(parameters, userId);

                case 'schedule':
                    return await this.executeSchedule(parameters, userId);

                case 'validate':
                    return await this.executeValidate(parameters);

                case 'status':
                    return await this.getStatusReport();

                case 'list-snapshots':
                    return await this.listSnapshots(parameters.targetOrg);

                case 'explain':
                    return {
                        type: 'explanation',
                        message: decision.responseMessage,
                        success: true
                    };

                case 'abort':
                    return {
                        type: 'aborted',
                        message: 'Operation aborted.',
                        success: true
                    };

                case 'clarify':
                    return {
                        type: 'clarification',
                        message: decision.responseMessage,
                        success: true
                    };

                default:
                    return {
                        type: 'error',
                        message: `Unknown action: ${action}`,
                        success: false
                    };
            }
        } catch (error) {
            this.logger.error(`Action ${action} failed:`, error);
            return {
                type: 'error',
                message: `Failed to execute ${action}: ${error.message}`,
                success: false
            };
        }
    }

    async executeDeploy(parameters, userId) {
        const {
            targetOrg = 'Devin1',
            force = false,
            skipTests = false,
            skipValidation = false
        } = parameters;

        // Get pending artifacts (would be retrieved from context)
        const artifacts = this.getPendingArtifacts(userId);

        if (!artifacts || Object.keys(artifacts).length === 0) {
            return {
                type: 'error',
                message: 'No artifacts to deploy. Generate some code first!',
                success: false
            };
        }

        const result = await this.deploymentPipeline.deployToSandbox(
            artifacts,
            targetOrg,
            { force, skipTests, skipValidation }
        );

        if (result.deployed) {
            return {
                type: 'success',
                message: `Deployed successfully to ${targetOrg}!\n\n` +
                    `Deployment ID: ${result.deploymentId}\n` +
                    `Snapshot ID: ${result.snapshotId}\n` +
                    (result.testResults ?
                        `Tests: ${result.testResults.passed ? 'PASSED' : 'FAILED'}\n` +
                        `Coverage: ${result.testResults.coverage}%` : ''),
                deploymentId: result.deploymentId,
                snapshotId: result.snapshotId,
                success: true
            };
        } else if (result.rolledBack) {
            return {
                type: 'auto_rollback',
                message: `Deployment completed but tests failed.\n\n` +
                    `Automatic rollback was performed.\n` +
                    `Reason: ${result.rollbackReason}`,
                success: false
            };
        } else {
            return {
                type: 'error',
                message: `Deployment failed: ${result.error}`,
                success: false
            };
        }
    }

    async executeRollback(parameters, userId) {
        const { snapshotId, targetOrg = 'Devin1' } = parameters;

        let result;
        if (snapshotId) {
            result = await this.deploymentPipeline.rollbackToSnapshot(snapshotId, targetOrg);
        } else {
            result = await this.deploymentPipeline.rollbackToPrevious(targetOrg);
        }

        if (result.success) {
            return {
                type: 'success',
                message: `Rollback completed!\n\n` +
                    `Restored: ${result.restored.length} components\n` +
                    `Deleted: ${result.deleted.length} new components`,
                success: true
            };
        } else {
            return {
                type: 'error',
                message: `Rollback failed: ${result.error}`,
                success: false
            };
        }
    }

    async executeSchedule(parameters, userId) {
        const { targetOrg = 'Devin1', scheduledTime } = parameters;

        // Parse scheduled time
        const scheduledDate = this.parseScheduledTime(scheduledTime);

        if (!scheduledDate) {
            return {
                type: 'error',
                message: 'Could not parse scheduled time. Try "tomorrow at 2pm" or "in 3 hours".',
                success: false
            };
        }

        // Store scheduled deployment (would integrate with job scheduler)
        const scheduledId = `scheduled-${Date.now()}`;

        return {
            type: 'scheduled',
            message: `Deployment scheduled!\n\n` +
                `Scheduled ID: ${scheduledId}\n` +
                `Target: ${targetOrg}\n` +
                `Time: ${scheduledDate.toISOString()}\n\n` +
                `I'll notify you when it starts.`,
            scheduledId,
            scheduledTime: scheduledDate.toISOString(),
            success: true
        };
    }

    async executeValidate(parameters) {
        const { targetOrg = 'Devin1' } = parameters;

        // Run validation only
        const result = await this.deploymentPipeline.validateDeployment(
            './deployments/pending',
            targetOrg,
            {}
        );

        if (result.success) {
            return {
                type: 'validation_success',
                message: `Validation passed!\n\n` +
                    (result.warnings?.length ?
                        `Warnings:\n${result.warnings.map(w => `- ${w}`).join('\n')}` :
                        'No issues found.'),
                success: true
            };
        } else {
            return {
                type: 'validation_failed',
                message: `Validation failed:\n\n` +
                    result.errors.map(e => `- ${e}`).join('\n'),
                success: false
            };
        }
    }

    async getStatusReport() {
        const state = await this.getDeploymentState();
        const history = this.deploymentPipeline.deploymentHistory.slice(-5);

        let message = `**Deployment Status**\n\n`;
        message += `Circuit Breaker: ${state.circuitBreakerOpen ? 'OPEN (paused)' : 'CLOSED (normal)'}\n`;
        message += `Deployment Window: ${state.isWithinWindow ? 'OPEN' : 'CLOSED'}\n`;
        message += `Available Snapshots: ${state.snapshotCount}\n\n`;

        if (history.length > 0) {
            message += `**Recent Deployments:**\n`;
            history.forEach(d => {
                message += `- ${d.deploymentId}: ${d.success ? 'SUCCESS' : 'FAILED'} (${d.timestamp})\n`;
            });
        }

        return {
            type: 'status',
            message,
            state,
            success: true
        };
    }

    async listSnapshots(targetOrg) {
        const snapshots = await this.deploymentPipeline.listSnapshots(targetOrg);

        if (snapshots.length === 0) {
            return {
                type: 'info',
                message: 'No snapshots available for rollback.',
                success: true
            };
        }

        let message = `**Available Snapshots:**\n\n`;
        snapshots.slice(0, 10).forEach(s => {
            message += `- ${s.snapshotId}\n`;
            message += `  Org: ${s.targetOrg} | Components: ${s.componentCount}\n`;
            message += `  Created: ${s.timestamp}\n\n`;
        });

        return {
            type: 'snapshot_list',
            message,
            snapshots,
            success: true
        };
    }

    /**
     * Get current deployment state for context
     */
    async getDeploymentState() {
        const snapshots = await this.deploymentPipeline.listSnapshots();

        return {
            sandboxWhitelist: this.deploymentPipeline.SANDBOX_WHITELIST,
            snapshotCount: snapshots.length,
            circuitBreakerOpen: this.deploymentPipeline.circuitBreaker.isOpen,
            recentFailures: this.deploymentPipeline.circuitBreaker.failures,
            isWithinWindow: this.deploymentPipeline.isWithinDeploymentWindow(),
            pendingDeployments: this.deploymentPipeline.deploymentHistory.filter(
                d => d.success && Date.now() - new Date(d.timestamp).getTime() < 3600000
            ).length
        };
    }

    /**
     * Parse natural language time to Date
     */
    parseScheduledTime(timeStr) {
        if (!timeStr) return null;

        const now = new Date();
        const lower = timeStr.toLowerCase();

        // "in X hours/minutes"
        const inMatch = lower.match(/in (\d+) (hour|minute|min)s?/);
        if (inMatch) {
            const amount = parseInt(inMatch[1]);
            const unit = inMatch[2].startsWith('min') ? 60000 : 3600000;
            return new Date(now.getTime() + amount * unit);
        }

        // "tomorrow at Xam/pm"
        if (lower.includes('tomorrow')) {
            const timeMatch = lower.match(/(\d+)\s*(am|pm)/);
            if (timeMatch) {
                let hours = parseInt(timeMatch[1]);
                if (timeMatch[2] === 'pm' && hours !== 12) hours += 12;
                if (timeMatch[2] === 'am' && hours === 12) hours = 0;

                const tomorrow = new Date(now);
                tomorrow.setDate(tomorrow.getDate() + 1);
                tomorrow.setHours(hours, 0, 0, 0);
                return tomorrow;
            }
        }

        // Try direct ISO parsing
        try {
            return new Date(timeStr);
        } catch {
            return null;
        }
    }

    getPendingArtifacts(userId) {
        // Would retrieve from context/session
        return this.pendingArtifacts?.[userId] || {};
    }

    setPendingArtifacts(userId, artifacts) {
        if (!this.pendingArtifacts) this.pendingArtifacts = {};
        this.pendingArtifacts[userId] = artifacts;
    }

    createFallbackDecision(message) {
        return {
            action: 'clarify',
            confidence: 0.5,
            parameters: {},
            reasoning: 'Could not parse intent',
            warningLevel: 'none',
            warnings: [],
            confirmationRequired: false,
            confirmationMessage: null,
            responseMessage: "I'm not sure what you'd like to do. Try:\n" +
                "- 'Deploy my changes'\n" +
                "- 'Rollback the last deployment'\n" +
                "- 'Show deployment status'\n" +
                "- 'List available snapshots'"
        };
    }

    // Conversation history management
    getConversationHistory(userId) {
        return this.conversations.get(userId) || [];
    }

    addToHistory(userId, role, content) {
        if (!this.conversations.has(userId)) {
            this.conversations.set(userId, []);
        }
        const history = this.conversations.get(userId);
        history.push({ role, content, timestamp: Date.now() });

        // Keep only last 20 messages
        if (history.length > 20) {
            history.shift();
        }
    }

    clearHistory(userId) {
        this.conversations.delete(userId);
        this.pendingConfirmations.delete(userId);
    }
}
