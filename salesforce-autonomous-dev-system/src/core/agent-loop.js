// src/core/agent-loop.js - ReAct Agent Loop Implementation
// Based on Anthropic's "Building Effective Agents" best practices

import { EventEmitter } from 'events';

/**
 * ReAct (Reasoning + Acting) Agent Loop
 *
 * Implements the Thought → Action → Observation cycle that enables
 * agents to reason about tasks, execute tools, and adapt based on results.
 *
 * Key Principles (from Anthropic):
 * 1. Agents receive initial commands
 * 2. Plan independently using reasoning
 * 3. Execute tool calls
 * 4. Gather ground truth from results
 * 5. Iterate until completion or stopping condition
 */
export class AgentLoop extends EventEmitter {
    constructor(options = {}) {
        super();
        this.anthropic = options.anthropic;
        this.logger = options.logger;
        this.tools = options.tools || [];
        this.maxIterations = options.maxIterations || 10;
        this.model = options.model || 'claude-sonnet-4-20250514';

        // State tracking
        this.iterations = 0;
        this.history = [];
        this.memory = [];
    }

    /**
     * Execute the ReAct loop for a given task
     * @param {Object} task - Task to execute
     * @param {Object} context - Initial context
     * @returns {Object} Final result
     */
    async execute(task, context = {}) {
        this.iterations = 0;
        this.history = [];

        // Initial observation is the task itself
        let observation = {
            type: 'task',
            content: task.description || task,
            context
        };

        this.emit('start', { task, context });
        this.logger?.info(`Starting ReAct loop for task: ${task.id || 'anonymous'}`);

        while (this.iterations < this.maxIterations) {
            this.iterations++;
            this.emit('iteration', { iteration: this.iterations });

            try {
                // PHASE 1: THINK - Reason about current state
                const thought = await this.think(observation);
                this.history.push({ type: 'thought', content: thought });
                this.emit('thought', { iteration: this.iterations, thought });

                // Check if agent decided task is complete
                if (thought.isComplete) {
                    this.logger?.info(`Task completed after ${this.iterations} iterations`);
                    return this.synthesize(thought.finalAnswer);
                }

                // PHASE 2: ACT - Select and prepare action
                const action = await this.selectAction(thought);
                this.history.push({ type: 'action', content: action });
                this.emit('action', { iteration: this.iterations, action });

                // PHASE 3: EXECUTE - Run the selected tool
                const result = await this.executeAction(action);
                this.history.push({ type: 'result', content: result });
                this.emit('result', { iteration: this.iterations, result });

                // PHASE 4: OBSERVE - Process tool output
                observation = await this.observe(action, result);
                this.history.push({ type: 'observation', content: observation });
                this.emit('observation', { iteration: this.iterations, observation });

                // PHASE 5: REFLECT - Verify and adapt
                const reflection = await this.reflect(observation);
                if (reflection.needsAdjustment) {
                    observation.adjustment = reflection.adjustment;
                }

            } catch (error) {
                this.logger?.error(`Error in iteration ${this.iterations}:`, error);
                this.emit('error', { iteration: this.iterations, error });

                // Add error to observation for next iteration to handle
                observation = {
                    type: 'error',
                    content: error.message,
                    previousObservation: observation
                };
            }
        }

        // Max iterations reached
        this.logger?.warn(`Max iterations (${this.maxIterations}) reached`);
        return this.synthesize(null, 'max_iterations_reached');
    }

    /**
     * THINK phase - Reason about current observation
     */
    async think(observation) {
        const thinkingPrompt = this.buildThinkingPrompt(observation);

        const response = await this.anthropic.messages.create({
            model: this.model,
            max_tokens: 4096,
            system: this.getThinkingSystemPrompt(),
            messages: [{ role: 'user', content: thinkingPrompt }]
        });

        return this.parseThought(response.content[0].text);
    }

    /**
     * Select appropriate action based on thought
     */
    async selectAction(thought) {
        // If thought includes a specific tool recommendation, use it
        if (thought.recommendedTool) {
            return {
                tool: thought.recommendedTool,
                input: thought.toolInput,
                reasoning: thought.reasoning
            };
        }

        // Otherwise, ask the model to select a tool
        const toolSelectionPrompt = this.buildToolSelectionPrompt(thought);

        const response = await this.anthropic.messages.create({
            model: this.model,
            max_tokens: 2048,
            tools: this.getToolDefinitions(),
            messages: [{ role: 'user', content: toolSelectionPrompt }]
        });

        return this.parseAction(response);
    }

    /**
     * Execute the selected action/tool
     */
    async executeAction(action) {
        const tool = this.tools.find(t => t.name === action.tool);

        if (!tool) {
            return {
                success: false,
                error: `Unknown tool: ${action.tool}`,
                availableTools: this.tools.map(t => t.name)
            };
        }

        try {
            const startTime = Date.now();
            const result = await tool.execute(action.input);
            const duration = Date.now() - startTime;

            return {
                success: true,
                tool: action.tool,
                input: action.input,
                output: result,
                duration
            };
        } catch (error) {
            return {
                success: false,
                tool: action.tool,
                input: action.input,
                error: error.message
            };
        }
    }

    /**
     * Process tool result into observation
     */
    async observe(action, result) {
        return {
            type: 'tool_result',
            tool: action.tool,
            success: result.success,
            content: result.success ? result.output : result.error,
            duration: result.duration,
            timestamp: new Date().toISOString()
        };
    }

    /**
     * Reflect on observation and decide if adjustment needed
     */
    async reflect(observation) {
        // Quick verification check
        if (!observation.success) {
            return {
                needsAdjustment: true,
                adjustment: {
                    type: 'retry_with_modification',
                    reason: observation.content
                }
            };
        }

        // For successful results, verify quality
        const verificationPrompt = `
Evaluate this tool result:
Tool: ${observation.tool}
Result: ${JSON.stringify(observation.content).substring(0, 2000)}

Is this result:
1. Complete and usable?
2. Does it need refinement?
3. Should we try a different approach?

Respond with JSON: {"quality": "good|needs_refinement|try_different", "reason": "..."}
`;

        try {
            const response = await this.anthropic.messages.create({
                model: 'claude-haiku-4-20250514', // Use fast model for reflection
                max_tokens: 256,
                messages: [{ role: 'user', content: verificationPrompt }]
            });

            const evaluation = JSON.parse(response.content[0].text);

            return {
                needsAdjustment: evaluation.quality !== 'good',
                adjustment: evaluation.quality !== 'good' ? {
                    type: evaluation.quality,
                    reason: evaluation.reason
                } : null
            };
        } catch {
            // Default to accepting result if reflection fails
            return { needsAdjustment: false };
        }
    }

    /**
     * Synthesize final result from history
     */
    synthesize(finalAnswer, stopReason = 'complete') {
        const successfulResults = this.history
            .filter(h => h.type === 'result' && h.content.success)
            .map(h => h.content.output);

        return {
            success: stopReason === 'complete',
            stopReason,
            iterations: this.iterations,
            finalAnswer,
            artifacts: successfulResults,
            history: this.history
        };
    }

    // === Prompt Building Methods ===

    getThinkingSystemPrompt() {
        return `You are an AI agent in a ReAct (Reasoning + Acting) loop.

Your job is to THINK about the current observation and decide:
1. What does this observation tell us?
2. Are we done, or do we need more actions?
3. If not done, what tool should we use next?

ALWAYS respond with valid JSON in this format:
{
    "reasoning": "Your step-by-step reasoning about the observation",
    "isComplete": true/false,
    "finalAnswer": "Only if isComplete=true, the final result",
    "recommendedTool": "Only if isComplete=false, the tool to use",
    "toolInput": "Only if isComplete=false, the input for the tool"
}

Available tools: ${this.tools.map(t => t.name).join(', ')}`;
    }

    buildThinkingPrompt(observation) {
        const historyContext = this.history.slice(-6).map(h =>
            `[${h.type.toUpperCase()}]: ${JSON.stringify(h.content).substring(0, 500)}`
        ).join('\n');

        return `## Current Observation
Type: ${observation.type}
Content: ${JSON.stringify(observation.content).substring(0, 2000)}

## Recent History
${historyContext || 'No previous history'}

## Task
Think about this observation. What should we do next?`;
    }

    buildToolSelectionPrompt(thought) {
        return `Based on this reasoning:
${thought.reasoning}

Select the appropriate tool and provide input.`;
    }

    getToolDefinitions() {
        return this.tools.map(tool => ({
            name: tool.name,
            description: tool.description,
            input_schema: tool.inputSchema
        }));
    }

    parseThought(text) {
        try {
            // Strip markdown if present
            const cleaned = text.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();
            return JSON.parse(cleaned);
        } catch {
            // Fallback: extract key information from text
            return {
                reasoning: text,
                isComplete: text.toLowerCase().includes('complete') || text.toLowerCase().includes('done'),
                recommendedTool: null,
                toolInput: null
            };
        }
    }

    parseAction(response) {
        // Check for tool use in response
        const toolUse = response.content.find(c => c.type === 'tool_use');
        if (toolUse) {
            return {
                tool: toolUse.name,
                input: toolUse.input,
                reasoning: 'Model selected tool via tool_use'
            };
        }

        // Fallback to text parsing
        const text = response.content.find(c => c.type === 'text')?.text || '';
        return {
            tool: 'unknown',
            input: {},
            reasoning: text
        };
    }
}

export default AgentLoop;
