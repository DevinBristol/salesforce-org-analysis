// src/core/thinking-agent.js - Extended Thinking Agent
// Implements Claude's thinking mode for complex planning and reasoning

import { EventEmitter } from 'events';

/**
 * ThinkingAgent - Uses Claude's Extended Thinking for Deep Reasoning
 *
 * Based on Anthropic's multi-agent research system:
 * "The lead agent uses extended thinking mode to plan its approach,
 * assessing tool suitability and determining how many specialized
 * workers to deploy based on query complexity."
 *
 * Extended thinking allows the model to:
 * 1. Break down complex problems systematically
 * 2. Consider multiple approaches before committing
 * 3. Self-correct during reasoning
 * 4. Produce more accurate plans
 */
export class ThinkingAgent extends EventEmitter {
    constructor(options = {}) {
        super();
        this.anthropic = options.anthropic;
        this.logger = options.logger;

        // Model configuration
        this.planningModel = options.planningModel || 'claude-opus-4-20250514';
        this.executionModel = options.executionModel || 'claude-sonnet-4-20250514';

        // Thinking configuration
        this.thinkingBudget = options.thinkingBudget || 10000;
        this.maxPlanningTime = options.maxPlanningTime || 120000; // 2 minutes
    }

    /**
     * Plan a complex task using extended thinking
     * @param {Object} task - Task to plan
     * @param {Object} context - Available context
     * @returns {Object} Execution plan
     */
    async plan(task, context = {}) {
        this.logger?.info(`Planning task with extended thinking: ${task.id || 'anonymous'}`);
        this.emit('planning:start', { task });

        const startTime = Date.now();

        try {
            const response = await this.anthropic.messages.create({
                model: this.planningModel,
                max_tokens: 16000,
                thinking: {
                    type: "enabled",
                    budget_tokens: this.thinkingBudget
                },
                messages: [{
                    role: 'user',
                    content: this.buildPlanningPrompt(task, context)
                }]
            });

            const duration = Date.now() - startTime;

            // Extract thinking and response
            const thinkingBlock = response.content.find(c => c.type === 'thinking');
            const textBlock = response.content.find(c => c.type === 'text');

            const plan = this.parsePlan(textBlock?.text || '');

            this.emit('planning:complete', {
                task,
                plan,
                thinking: thinkingBlock?.thinking,
                duration,
                usage: response.usage
            });

            return {
                success: true,
                plan,
                thinking: thinkingBlock?.thinking,
                duration,
                usage: {
                    inputTokens: response.usage.input_tokens,
                    outputTokens: response.usage.output_tokens,
                    thinkingTokens: thinkingBlock?.thinking?.length || 0
                }
            };

        } catch (error) {
            this.logger?.error('Planning failed:', error);
            this.emit('planning:error', { task, error });

            return {
                success: false,
                error: error.message
            };
        }
    }

    /**
     * Analyze task complexity to determine agent strategy
     */
    async analyzeComplexity(task, context = {}) {
        const response = await this.anthropic.messages.create({
            model: this.planningModel,
            max_tokens: 4000,
            thinking: {
                type: "enabled",
                budget_tokens: 5000
            },
            messages: [{
                role: 'user',
                content: `Analyze the complexity of this task and recommend an execution strategy.

## Task
${JSON.stringify(task, null, 2)}

## Available Context
${JSON.stringify(context, null, 2)}

## Analysis Required
1. Task Complexity: simple | moderate | complex | highly_complex
2. Estimated Steps: How many distinct operations needed?
3. Parallelization: Can subtasks run in parallel?
4. Subagent Recommendation: How many subagents should work on this?
5. Risk Assessment: What could go wrong?

Respond with JSON:
{
    "complexity": "simple|moderate|complex|highly_complex",
    "estimatedSteps": number,
    "canParallelize": boolean,
    "recommendedSubagents": number,
    "subagentRoles": ["role1", "role2", ...],
    "risks": ["risk1", "risk2", ...],
    "reasoning": "explanation of analysis"
}`
            }]
        });

        const textBlock = response.content.find(c => c.type === 'text');
        const thinkingBlock = response.content.find(c => c.type === 'thinking');

        try {
            const analysis = JSON.parse(
                textBlock.text.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim()
            );
            analysis.thinking = thinkingBlock?.thinking;
            return analysis;
        } catch {
            return {
                complexity: 'moderate',
                estimatedSteps: 5,
                canParallelize: false,
                recommendedSubagents: 1,
                reasoning: textBlock?.text || 'Analysis failed'
            };
        }
    }

    /**
     * Synthesize results from multiple subagents
     */
    async synthesize(subagentResults, originalTask) {
        this.logger?.info('Synthesizing subagent results with extended thinking');

        const response = await this.anthropic.messages.create({
            model: this.planningModel,
            max_tokens: 16000,
            thinking: {
                type: "enabled",
                budget_tokens: this.thinkingBudget
            },
            messages: [{
                role: 'user',
                content: this.buildSynthesisPrompt(subagentResults, originalTask)
            }]
        });

        const thinkingBlock = response.content.find(c => c.type === 'thinking');
        const textBlock = response.content.find(c => c.type === 'text');

        return {
            synthesis: this.parseSynthesis(textBlock?.text || ''),
            thinking: thinkingBlock?.thinking,
            usage: response.usage
        };
    }

    /**
     * Decide if more work is needed after synthesis
     */
    async evaluateCompletion(synthesis, originalTask) {
        const response = await this.anthropic.messages.create({
            model: this.executionModel, // Use faster model for evaluation
            max_tokens: 2000,
            messages: [{
                role: 'user',
                content: `Evaluate if this task is complete.

## Original Task
${JSON.stringify(originalTask, null, 2)}

## Current Synthesis
${JSON.stringify(synthesis, null, 2)}

## Evaluation
Is the task fully complete? If not, what additional work is needed?

Respond with JSON:
{
    "isComplete": boolean,
    "completionPercentage": number,
    "missingElements": ["element1", ...],
    "nextSteps": ["step1", ...],
    "qualityScore": number (1-10)
}`
            }]
        });

        try {
            return JSON.parse(
                response.content[0].text.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim()
            );
        } catch {
            return {
                isComplete: true,
                completionPercentage: 100,
                qualityScore: 7
            };
        }
    }

    // === Prompt Building ===

    buildPlanningPrompt(task, context) {
        return `You are a Lead Agent responsible for planning complex tasks.

## Your Role
- Analyze the task thoroughly
- Break it down into subtasks
- Determine which subtasks can run in parallel
- Assign roles to subagents
- Define clear success criteria

## Task to Plan
${JSON.stringify(task, null, 2)}

## Available Context
${JSON.stringify(context, null, 2)}

## Available Tools/Capabilities
- Salesforce metadata operations (read/write Apex, triggers, objects)
- Code analysis and generation
- Test creation and execution
- Deployment with rollback capabilities
- Git operations for local repositories

## Output Format
Provide a detailed execution plan as JSON:
{
    "taskSummary": "Brief description of what needs to be done",
    "complexity": "simple|moderate|complex",
    "phases": [
        {
            "phase": 1,
            "name": "Phase name",
            "description": "What this phase accomplishes",
            "subtasks": [
                {
                    "id": "subtask-1",
                    "description": "Subtask description",
                    "assignTo": "subagent_role",
                    "dependencies": [],
                    "tools": ["tool1", "tool2"],
                    "expectedOutput": "What this subtask should produce"
                }
            ],
            "canParallelize": true/false
        }
    ],
    "subagentRoles": {
        "analyzer": "Analyzes existing code and identifies issues",
        "generator": "Generates improved code",
        "tester": "Creates and runs tests",
        "reviewer": "Reviews changes for quality"
    },
    "successCriteria": [
        "Criterion 1",
        "Criterion 2"
    ],
    "risks": [
        {
            "risk": "Description",
            "mitigation": "How to handle it"
        }
    ],
    "estimatedDuration": "X minutes"
}`;
    }

    buildSynthesisPrompt(results, task) {
        return `You are synthesizing results from multiple subagents.

## Original Task
${JSON.stringify(task, null, 2)}

## Subagent Results
${results.map((r, i) => `
### Subagent ${i + 1}: ${r.role}
Status: ${r.status}
Output:
${JSON.stringify(r.output, null, 2)}
`).join('\n')}

## Your Job
1. Combine the best elements from each subagent's work
2. Resolve any conflicts or contradictions
3. Fill in any gaps
4. Produce a cohesive final output

## Output Format
{
    "combinedOutput": { ... },
    "conflictsResolved": ["conflict1: resolution", ...],
    "gapsFilled": ["gap1: how filled", ...],
    "qualityAssessment": {
        "overall": 1-10,
        "completeness": 1-10,
        "consistency": 1-10,
        "correctness": 1-10
    },
    "recommendations": ["recommendation1", ...]
}`;
    }

    parsePlan(text) {
        try {
            const cleaned = text.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();
            return JSON.parse(cleaned);
        } catch {
            return {
                taskSummary: 'Plan parsing failed',
                phases: [{
                    phase: 1,
                    name: 'Execute task',
                    subtasks: [{
                        id: 'task-1',
                        description: text.substring(0, 500)
                    }]
                }]
            };
        }
    }

    parseSynthesis(text) {
        try {
            const cleaned = text.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();
            return JSON.parse(cleaned);
        } catch {
            return {
                combinedOutput: text,
                qualityAssessment: { overall: 5 }
            };
        }
    }
}

export default ThinkingAgent;
