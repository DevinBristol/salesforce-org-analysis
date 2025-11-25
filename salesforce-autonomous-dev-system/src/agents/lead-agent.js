// src/agents/lead-agent.js - Orchestrator Lead Agent
// Based on Anthropic's multi-agent research system architecture

import { EventEmitter } from 'events';
import { ThinkingAgent } from '../core/thinking-agent.js';
import { SubAgent } from './subagent.js';

/**
 * LeadAgent - Orchestrator for Multi-Agent System
 *
 * From Anthropic's research:
 * "The lead agent analyzes user queries and develops a strategy,
 * and spawns subagents to explore different aspects in parallel."
 *
 * Key responsibilities:
 * 1. Analyze incoming tasks using extended thinking
 * 2. Create execution plans with parallel subtasks
 * 3. Spawn and manage subagents
 * 4. Synthesize results and iterate if needed
 * 5. Produce final cohesive output
 */
export class LeadAgent extends EventEmitter {
    constructor(options = {}) {
        super();
        this.anthropic = options.anthropic;
        this.logger = options.logger;

        // Lead agent uses Opus for complex reasoning
        this.model = options.model || 'claude-opus-4-20250514';
        this.subagentModel = options.subagentModel || 'claude-sonnet-4-20250514';

        // Initialize thinking agent for planning
        this.thinkingAgent = new ThinkingAgent({
            anthropic: this.anthropic,
            logger: this.logger,
            planningModel: this.model,
            executionModel: this.subagentModel
        });

        // Subagent management
        this.activeSubagents = new Map();
        this.maxSubagents = options.maxSubagents || 5;
        this.subagentTimeout = options.subagentTimeout || 300000; // 5 minutes

        // Tools available to subagents
        this.availableTools = options.tools || [];

        // Memory for cross-task learning
        this.taskMemory = [];
    }

    /**
     * Execute a task with the multi-agent system
     * @param {Object} task - Task to execute
     * @param {Object} context - Available context
     * @returns {Object} Final result
     */
    async execute(task, context = {}) {
        const taskId = task.id || `task-${Date.now()}`;
        this.logger?.info(`LeadAgent executing task: ${taskId}`);
        this.emit('task:start', { taskId, task });

        try {
            // PHASE 1: Analyze complexity
            this.emit('phase', { taskId, phase: 'analysis' });
            const complexity = await this.thinkingAgent.analyzeComplexity(task, context);
            this.logger?.info(`Task complexity: ${complexity.complexity}, subagents: ${complexity.recommendedSubagents}`);

            // PHASE 2: Create execution plan
            this.emit('phase', { taskId, phase: 'planning' });
            const planResult = await this.thinkingAgent.plan(task, {
                ...context,
                complexity
            });

            if (!planResult.success) {
                throw new Error(`Planning failed: ${planResult.error}`);
            }

            const plan = planResult.plan;
            this.emit('plan:created', { taskId, plan });

            // PHASE 3: Execute phases (potentially with subagents)
            const phaseResults = [];
            for (const phase of plan.phases) {
                this.emit('phase', { taskId, phase: phase.name });

                const phaseResult = await this.executePhase(phase, plan, context);
                phaseResults.push(phaseResult);

                // Check if we need to abort
                if (phaseResult.criticalFailure) {
                    this.logger?.error(`Critical failure in phase ${phase.name}`);
                    break;
                }
            }

            // PHASE 4: Synthesize results
            this.emit('phase', { taskId, phase: 'synthesis' });
            const synthesis = await this.thinkingAgent.synthesize(phaseResults, task);

            // PHASE 5: Evaluate completion
            const evaluation = await this.thinkingAgent.evaluateCompletion(synthesis.synthesis, task);

            // PHASE 6: Iterate if needed
            if (!evaluation.isComplete && evaluation.completionPercentage < 80) {
                this.logger?.info('Task incomplete, spawning additional work');
                const additionalResult = await this.handleIncomplete(
                    evaluation,
                    synthesis,
                    task,
                    context
                );
                return additionalResult;
            }

            // Store in memory for future learning
            this.taskMemory.push({
                taskId,
                task,
                plan,
                result: synthesis.synthesis,
                evaluation,
                timestamp: new Date().toISOString()
            });

            this.emit('task:complete', { taskId, result: synthesis.synthesis });

            return {
                success: true,
                taskId,
                result: synthesis.synthesis,
                thinking: planResult.thinking,
                evaluation,
                phases: phaseResults,
                usage: this.aggregateUsage(planResult, synthesis, phaseResults)
            };

        } catch (error) {
            this.logger?.error(`LeadAgent error for task ${taskId}:`, error);
            this.emit('task:error', { taskId, error });

            return {
                success: false,
                taskId,
                error: error.message
            };
        } finally {
            // Cleanup any remaining subagents
            await this.cleanupSubagents();
        }
    }

    /**
     * Execute a single phase, potentially spawning subagents
     */
    async executePhase(phase, plan, context) {
        const results = [];

        if (phase.canParallelize && phase.subtasks.length > 1) {
            // Spawn parallel subagents
            this.logger?.info(`Spawning ${phase.subtasks.length} parallel subagents for ${phase.name}`);

            const subagentPromises = phase.subtasks.map(subtask =>
                this.spawnSubagent(subtask, plan.subagentRoles, context)
            );

            const subagentResults = await Promise.allSettled(subagentPromises);

            for (const [index, result] of subagentResults.entries()) {
                if (result.status === 'fulfilled') {
                    results.push({
                        subtask: phase.subtasks[index],
                        ...result.value
                    });
                } else {
                    results.push({
                        subtask: phase.subtasks[index],
                        success: false,
                        error: result.reason?.message || 'Subagent failed'
                    });
                }
            }
        } else {
            // Execute sequentially
            for (const subtask of phase.subtasks) {
                // Check dependencies
                if (subtask.dependencies?.length > 0) {
                    const dependencyMet = subtask.dependencies.every(dep =>
                        results.some(r => r.subtask.id === dep && r.success)
                    );
                    if (!dependencyMet) {
                        results.push({
                            subtask,
                            success: false,
                            error: 'Dependencies not met'
                        });
                        continue;
                    }
                }

                const result = await this.spawnSubagent(subtask, plan.subagentRoles, context);
                results.push({ subtask, ...result });
            }
        }

        return {
            phase: phase.name,
            results,
            success: results.every(r => r.success),
            criticalFailure: results.some(r => r.criticalFailure)
        };
    }

    /**
     * Spawn a subagent for a specific subtask
     */
    async spawnSubagent(subtask, roles, context) {
        const role = subtask.assignTo;
        const roleDescription = roles[role] || 'General purpose agent';

        this.logger?.info(`Spawning subagent: ${role} for ${subtask.id}`);
        this.emit('subagent:spawn', { role, subtask });

        const subagent = new SubAgent({
            anthropic: this.anthropic,
            logger: this.logger,
            model: this.subagentModel,
            role,
            roleDescription,
            tools: this.getToolsForRole(role)
        });

        this.activeSubagents.set(subtask.id, subagent);

        try {
            const result = await Promise.race([
                subagent.execute(subtask, context),
                this.createTimeout(this.subagentTimeout)
            ]);

            this.emit('subagent:complete', { role, subtask, result });
            return result;

        } catch (error) {
            this.logger?.error(`Subagent ${role} failed:`, error);
            this.emit('subagent:error', { role, subtask, error });

            return {
                success: false,
                error: error.message
            };
        } finally {
            this.activeSubagents.delete(subtask.id);
        }
    }

    /**
     * Handle incomplete task - spawn additional work
     */
    async handleIncomplete(evaluation, previousSynthesis, task, context) {
        this.logger?.info('Handling incomplete task, creating additional plan');

        const additionalTask = {
            ...task,
            previousAttempt: previousSynthesis.synthesis,
            missingElements: evaluation.missingElements,
            nextSteps: evaluation.nextSteps
        };

        // Recursive call with additional context
        return this.execute(additionalTask, {
            ...context,
            iteration: (context.iteration || 0) + 1,
            previousEvaluation: evaluation
        });
    }

    /**
     * Get tools appropriate for a specific role
     */
    getToolsForRole(role) {
        const roleToolMap = {
            analyzer: ['read_code', 'search_code', 'analyze_coverage', 'list_classes'],
            generator: ['read_code', 'write_code', 'validate_apex', 'create_metadata'],
            tester: ['read_code', 'write_test', 'run_tests', 'check_coverage'],
            reviewer: ['read_code', 'analyze_code', 'check_best_practices', 'validate_apex'],
            deployer: ['create_deployment', 'validate_deployment', 'deploy', 'rollback']
        };

        const toolNames = roleToolMap[role] || this.availableTools.map(t => t.name);
        return this.availableTools.filter(t => toolNames.includes(t.name));
    }

    /**
     * Create a timeout promise
     */
    createTimeout(ms) {
        return new Promise((_, reject) =>
            setTimeout(() => reject(new Error('Subagent timeout')), ms)
        );
    }

    /**
     * Cleanup all active subagents
     */
    async cleanupSubagents() {
        for (const [id, subagent] of this.activeSubagents) {
            try {
                await subagent.abort?.();
            } catch {
                // Ignore cleanup errors
            }
        }
        this.activeSubagents.clear();
    }

    /**
     * Aggregate usage statistics
     */
    aggregateUsage(planResult, synthesis, phaseResults) {
        let totalInput = planResult.usage?.inputTokens || 0;
        let totalOutput = planResult.usage?.outputTokens || 0;

        if (synthesis.usage) {
            totalInput += synthesis.usage.input_tokens || 0;
            totalOutput += synthesis.usage.output_tokens || 0;
        }

        for (const phase of phaseResults) {
            for (const result of phase.results || []) {
                if (result.usage) {
                    totalInput += result.usage.inputTokens || 0;
                    totalOutput += result.usage.outputTokens || 0;
                }
            }
        }

        return { totalInput, totalOutput };
    }
}

export default LeadAgent;
