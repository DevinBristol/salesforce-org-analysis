// src/agents/subagent.js - Specialized Subagent Implementation
// Isolated context workers that report back to the lead agent

import { EventEmitter } from 'events';
import { AgentLoop } from '../core/agent-loop.js';

/**
 * SubAgent - Specialized Worker Agent
 *
 * From Anthropic:
 * "Subagents are useful for two main reasons:
 * 1. They enable parallelization - you can spin up multiple subagents
 *    to work on different tasks simultaneously
 * 2. They help manage context - subagents use their own isolated context
 *    windows, and only send relevant information back to the orchestrator"
 *
 * Each subagent:
 * - Has a specific role and expertise
 * - Operates in isolated context
 * - Uses ReAct loop for tool execution
 * - Returns structured results to lead agent
 */
export class SubAgent extends EventEmitter {
    constructor(options = {}) {
        super();
        this.anthropic = options.anthropic;
        this.logger = options.logger;
        this.model = options.model || 'claude-sonnet-4-20250514';

        // Role configuration
        this.role = options.role || 'general';
        this.roleDescription = options.roleDescription || 'General purpose agent';

        // Tools available to this subagent
        this.tools = options.tools || [];

        // Execution limits
        this.maxIterations = options.maxIterations || 8;
        this.maxTokens = options.maxTokens || 8192;

        // Internal state
        this.context = [];
        this.aborted = false;

        // Initialize ReAct loop
        this.agentLoop = new AgentLoop({
            anthropic: this.anthropic,
            logger: this.logger,
            tools: this.tools,
            maxIterations: this.maxIterations,
            model: this.model
        });
    }

    /**
     * Execute a subtask
     * @param {Object} subtask - Subtask to execute
     * @param {Object} context - Context from lead agent
     * @returns {Object} Execution result
     */
    async execute(subtask, context = {}) {
        if (this.aborted) {
            return { success: false, error: 'Subagent was aborted' };
        }

        const startTime = Date.now();
        this.emit('start', { role: this.role, subtask });

        try {
            // Build role-specific prompt
            const task = this.buildTask(subtask, context);

            // Execute using ReAct loop
            const result = await this.agentLoop.execute(task, {
                role: this.role,
                roleDescription: this.roleDescription,
                ...context
            });

            const duration = Date.now() - startTime;

            // Extract and structure the output
            const structuredOutput = this.structureOutput(result, subtask);

            this.emit('complete', {
                role: this.role,
                subtask,
                output: structuredOutput,
                duration
            });

            return {
                success: result.success,
                role: this.role,
                status: result.success ? 'completed' : 'partial',
                output: structuredOutput,
                iterations: result.iterations,
                duration,
                usage: this.calculateUsage(result)
            };

        } catch (error) {
            const duration = Date.now() - startTime;

            this.emit('error', { role: this.role, subtask, error });

            return {
                success: false,
                role: this.role,
                status: 'failed',
                error: error.message,
                duration
            };
        }
    }

    /**
     * Build a task prompt specific to this subagent's role
     */
    buildTask(subtask, context) {
        return {
            id: subtask.id,
            description: this.buildRolePrompt(subtask, context),
            tools: subtask.tools || this.tools.map(t => t.name),
            expectedOutput: subtask.expectedOutput,
            constraints: this.getRoleConstraints()
        };
    }

    /**
     * Build role-specific prompt
     */
    buildRolePrompt(subtask, context) {
        const basePrompt = `You are a specialized ${this.role} agent.

## Your Role
${this.roleDescription}

## Your Task
${subtask.description}

## Expected Output
${subtask.expectedOutput || 'Complete the task and return results'}

## Available Tools
${this.tools.map(t => `- ${t.name}: ${t.description}`).join('\n')}

## Guidelines
1. Focus ONLY on your assigned task
2. Use the available tools to gather information and take actions
3. Return structured, actionable results
4. If you encounter blockers, report them clearly
5. Do NOT try to do work outside your role
`;

        // Add role-specific instructions
        const roleInstructions = this.getRoleInstructions();

        // Add relevant context
        const contextSection = context.existingCode
            ? `\n## Existing Code Context\n${JSON.stringify(context.existingCode).substring(0, 3000)}`
            : '';

        return basePrompt + roleInstructions + contextSection;
    }

    /**
     * Get role-specific instructions
     */
    getRoleInstructions() {
        const instructions = {
            analyzer: `
## Analyzer-Specific Instructions
- Thoroughly examine all code for issues
- Check for: DML in loops, SOQL in loops, missing null checks, hardcoded IDs
- Identify Salesforce best practice violations
- Rank issues by severity: critical, high, medium, low
- Provide specific line numbers and code snippets
`,
            generator: `
## Generator-Specific Instructions
- Generate production-quality Apex code
- Follow Salesforce best practices for bulkification
- Include proper error handling with try-catch
- Add meaningful comments only where logic is complex
- Preserve existing business logic when modifying code
- Use dependency injection patterns for testability
`,
            tester: `
## Tester-Specific Instructions
- Create comprehensive test classes
- Target 90%+ code coverage
- Test both positive and negative scenarios
- Include bulk data tests (200+ records)
- Test edge cases and boundary conditions
- Use Test.startTest() and Test.stopTest() properly
- Create test data factories instead of hardcoding
`,
            reviewer: `
## Reviewer-Specific Instructions
- Review code for adherence to best practices
- Check for security vulnerabilities (SOQL injection, XSS)
- Verify proper sharing model (with sharing vs without)
- Ensure error handling is appropriate
- Check for performance issues
- Provide actionable feedback with severity levels
`,
            deployer: `
## Deployer-Specific Instructions
- Validate all components before deployment
- Check for dependency issues
- Verify test coverage meets minimum requirements
- Create deployment package correctly
- Ensure rollback capability exists
- Never deploy to production without explicit approval
`
        };

        return instructions[this.role] || '';
    }

    /**
     * Get role-specific constraints
     */
    getRoleConstraints() {
        const constraints = {
            analyzer: {
                maxFilesToAnalyze: 20,
                focusOn: ['apex', 'triggers', 'classes']
            },
            generator: {
                preserveExistingLogic: true,
                minDocumentation: 'public_methods',
                targetCoverage: 75
            },
            tester: {
                minAssertions: 3,
                testBulkOperations: true,
                mockExternalServices: true
            },
            reviewer: {
                checklistRequired: true,
                severityLevels: ['critical', 'high', 'medium', 'low']
            },
            deployer: {
                sandboxOnly: true,
                requireValidation: true,
                requireSnapshot: true
            }
        };

        return constraints[this.role] || {};
    }

    /**
     * Structure the output for the lead agent
     */
    structureOutput(result, subtask) {
        // Extract artifacts from successful iterations
        const artifacts = result.artifacts || [];

        // Get key findings from history
        const findings = result.history
            ?.filter(h => h.type === 'observation' && h.content.success)
            ?.map(h => h.content.content) || [];

        return {
            taskId: subtask.id,
            role: this.role,
            summary: this.generateSummary(result, findings),
            artifacts,
            findings,
            recommendations: this.extractRecommendations(result),
            metrics: {
                iterations: result.iterations,
                toolCalls: result.history?.filter(h => h.type === 'action')?.length || 0,
                successfulActions: result.history?.filter(h =>
                    h.type === 'result' && h.content?.success
                )?.length || 0
            }
        };
    }

    /**
     * Generate a summary of the work done
     */
    generateSummary(result, findings) {
        if (!result.success) {
            return `Task incomplete after ${result.iterations} iterations. Reason: ${result.stopReason}`;
        }

        const actionCount = result.history?.filter(h => h.type === 'action')?.length || 0;
        return `Completed in ${result.iterations} iterations with ${actionCount} tool calls. ` +
            `Found ${findings.length} relevant results.`;
    }

    /**
     * Extract recommendations from results
     */
    extractRecommendations(result) {
        const recommendations = [];

        // Look for recommendations in thoughts
        const thoughts = result.history?.filter(h => h.type === 'thought') || [];
        for (const thought of thoughts) {
            if (thought.content?.recommendations) {
                recommendations.push(...thought.content.recommendations);
            }
        }

        return recommendations;
    }

    /**
     * Calculate token usage
     */
    calculateUsage(result) {
        // Estimate based on iterations
        // In production, would aggregate from actual API calls
        return {
            inputTokens: result.iterations * 1500,
            outputTokens: result.iterations * 800
        };
    }

    /**
     * Abort the subagent
     */
    abort() {
        this.aborted = true;
        this.emit('abort', { role: this.role });
    }
}

export default SubAgent;
