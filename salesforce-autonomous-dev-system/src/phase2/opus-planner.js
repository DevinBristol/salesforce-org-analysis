// src/phase2/opus-planner.js
import { Anthropic } from '@anthropic-ai/sdk';
import { CostTracker } from './cost-tracker.js';

export class OpusPlanner {
  constructor() {
    this.anthropic = new Anthropic({
      apiKey: process.env.ANTHROPIC_API_KEY,
      timeout: 120000, // 120 seconds
      maxRetries: 3
    });
    this.costTracker = new CostTracker();
  }

  async shouldPlan(tasks) {
    // Only use Opus for complex planning scenarios
    if (tasks.length < 10) return false;
    if (process.env.USE_OPUS_PLANNING !== 'true') return false;

    // Check if tasks are heterogeneous (need planning)
    const types = new Set(tasks.map(t => t.type));
    return types.size > 3; // Multiple task types benefit from planning
  }

  async createExecutionPlan(tasks) {
    if (!await this.shouldPlan(tasks)) {
      // Simple batching for homogeneous tasks
      return this.createSimpleBatches(tasks);
    }

    const planPrompt = `You are orchestrating ${tasks.length} Salesforce development tasks.

Tasks:
${tasks.map((t, i) => `${i+1}. ${t.description} (Priority: ${t.priority})`).join('\n')}

Create an optimal execution plan that:
1. Groups similar tasks for context efficiency
2. Prioritizes based on dependencies and risk
3. Distributes work across ${process.env.WORKER_COUNT} workers
4. Minimizes context switching
5. Estimates time and token usage

Return a structured plan with phases and worker assignments.`;

    const response = await this.anthropic.messages.create({
      model: 'claude-opus-4-20250514',
      max_tokens: 2000,
      messages: [{ role: 'user', content: planPrompt }]
    });

    // Track cost
    this.costTracker.addUsage({
      model: 'claude-opus',
      inputTokens: this.estimateTokens(planPrompt),
      outputTokens: 2000,
      taskId: 0
    });

    return this.parseExecutionPlan(response.content[0].text);
  }

  createSimpleBatches(tasks) {
    // Simple round-robin batching
    const workerCount = parseInt(process.env.WORKER_COUNT);
    const batches = Array.from({ length: workerCount }, () => []);

    tasks.forEach((task, i) => {
      batches[i % workerCount].push(task);
    });

    return {
      strategy: 'simple-batching',
      batches,
      estimatedTime: tasks.length * 5, // 5 min per task average
      estimatedCost: tasks.length * 0.10 // $0.10 per task average
    };
  }

  parseExecutionPlan(planText) {
    // Parse Opus response into structured plan
    return {
      strategy: 'opus-optimized',
      batches: [],
      estimatedTime: 0,
      estimatedCost: 0
    };
  }

  estimateTokens(text) {
    // Rough estimation: 1 token ≈ 4 characters
    return Math.ceil(text.length / 4);
  }
}