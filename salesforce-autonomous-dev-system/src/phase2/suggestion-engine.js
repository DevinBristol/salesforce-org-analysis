// src/phase2/suggestion-engine.js
// Proactive suggestion engine - recommends actions based on system state

export class SuggestionEngine {
  constructor(workerPool, taskQueue, costTracker) {
    this.workerPool = workerPool;
    this.taskQueue = taskQueue;
    this.costTracker = costTracker;
    this.lastSuggestionTime = new Map(); // user → timestamp
    this.SUGGESTION_COOLDOWN = 5 * 60 * 1000; // 5 minutes between suggestions
  }

  /**
   * Get proactive suggestions based on current system state
   * @param {string} userId - User ID
   * @param {Object} context - Current conversation context
   * @returns {Array} Array of suggestions
   */
  async getSuggestions(userId, context = {}) {
    // Check cooldown
    if (!this.shouldSuggest(userId)) {
      return [];
    }

    const systemState = await this.getSystemState();
    const suggestions = [];

    // Queue is empty - suggest analysis
    if (systemState.queueSize === 0 && !context.recentlyAnalyzed) {
      suggestions.push({
        type: 'analyze-org',
        priority: 'medium',
        message: "💡 Your queue is empty. Want to analyze your org for improvement opportunities?",
        action: 'analyze-org',
        reason: 'empty-queue'
      });
    }

    // Low coverage detected
    if (systemState.coverage && systemState.coverage < 75) {
      suggestions.push({
        type: 'improve-coverage',
        priority: 'high',
        message: `⚠️ Org coverage is at ${systemState.coverage}%. I can help improve it to 90%+.`,
        action: 'comprehensive-improve',
        reason: 'low-coverage'
      });
    }

    // Budget warning
    if (systemState.budgetUsagePercent > 80) {
      suggestions.push({
        type: 'budget-warning',
        priority: 'high',
        message: `💰 Budget alert: You've used ${systemState.budgetUsagePercent}% of your monthly budget. Consider reviewing costs.`,
        action: 'cost',
        reason: 'budget-high'
      });
    }

    // Failed tasks in queue
    if (systemState.failedTasks > 0) {
      suggestions.push({
        type: 'failed-tasks',
        priority: 'medium',
        message: `⚠️ ${systemState.failedTasks} tasks failed. Want me to clear them or retry?`,
        action: 'clear-failed',
        reason: 'has-failures'
      });
    }

    // Many tests ready to deploy
    if (systemState.readyToDeploy > 10) {
      suggestions.push({
        type: 'ready-deploy',
        priority: 'medium',
        message: `🚀 ${systemState.readyToDeploy} test classes are ready to deploy. Want to deploy them now?`,
        action: 'deploy-queue',
        reason: 'ready-items'
      });
    }

    // Long-running queue
    if (systemState.queueSize > 20 && systemState.avgTaskTime > 5) {
      suggestions.push({
        type: 'long-queue',
        priority: 'low',
        message: `⏱️ Queue has ${systemState.queueSize} tasks (avg ${systemState.avgTaskTime}min each). This might take a while.`,
        action: 'queue-status',
        reason: 'long-queue'
      });
    }

    // Cost optimization opportunity (lots of cache misses)
    if (systemState.cacheHitRate && systemState.cacheHitRate < 50) {
      suggestions.push({
        type: 'cache-optimization',
        priority: 'low',
        message: "💡 Tip: Running similar tasks together improves caching and reduces costs.",
        action: null,
        reason: 'low-cache-hit'
      });
    }

    // Sort by priority and return top 2
    const priorityOrder = { high: 3, medium: 2, low: 1 };
    suggestions.sort((a, b) => priorityOrder[b.priority] - priorityOrder[a.priority]);

    // Mark that we suggested
    if (suggestions.length > 0) {
      this.lastSuggestionTime.set(userId, Date.now());
    }

    return suggestions.slice(0, 2); // Max 2 suggestions at a time
  }

  /**
   * Get contextual suggestion after a command completes
   */
  async getFollowUpSuggestion(commandType, result, context = {}) {
    const suggestions = [];

    switch (commandType) {
      case 'analyze-org':
        if (result.lowQualityTests > 0) {
          suggestions.push({
            type: 'improve-tests',
            message: `Found ${result.lowQualityTests} low-quality tests. Want to improve them?`,
            action: 'improve-tests',
            parameters: { count: Math.min(result.lowQualityTests, 10) }
          });
        }
        break;

      case 'improve-tests':
        if (result.success) {
          suggestions.push({
            type: 'deploy',
            message: "Tests improved! Want to deploy them to Devin1 for validation?",
            action: 'deploy-queue'
          });
        }
        break;

      case 'quality-scan':
        if (result.score < 70) {
          suggestions.push({
            type: 'improve',
            message: `Score is ${result.score}/100. I can improve this test class for you.`,
            action: 'improve-test',
            parameters: { className: result.className }
          });
        }
        break;

      case 'deploy-queue':
        if (result.success) {
          suggestions.push({
            type: 'coverage-report',
            message: "Deployment successful! Want to see the updated coverage report?",
            action: 'coverage-report'
          });
        }
        break;

      case 'generate-tests':
        if (result.success) {
          suggestions.push({
            type: 'quality-scan',
            message: "Tests generated! Want me to scan their quality before deploying?",
            action: 'quality-scan'
          });
        }
        break;
    }

    return suggestions[0] || null;
  }

  /**
   * Check if we should suggest (respects cooldown)
   */
  shouldSuggest(userId) {
    const lastTime = this.lastSuggestionTime.get(userId);
    if (!lastTime) return true;

    return Date.now() - lastTime > this.SUGGESTION_COOLDOWN;
  }

  /**
   * Get current system state for suggestion logic
   */
  async getSystemState() {
    const stats = this.workerPool.getStats();
    const costToday = this.costTracker.getCurrentUsage();
    const monthlyTotal = await this.costTracker.getMonthlyTotal();
    const budget = parseFloat(process.env.COST_BUDGET_MONTHLY || 100);

    return {
      queueSize: stats.queueSize || 0,
      activeWorkers: stats.activeWorkers || 0,
      failedTasks: stats.failedTasks || 0,
      readyToDeploy: stats.readyToDeploy || 0,
      coverage: stats.coverage || null,
      costToday,
      budgetUsagePercent: Math.round((monthlyTotal / budget) * 100),
      avgTaskTime: stats.avgTaskTime || 0,
      cacheHitRate: stats.cacheHitRate || null
    };
  }

  /**
   * Format suggestion as a friendly message
   */
  formatSuggestion(suggestion) {
    let message = suggestion.message;

    // Add quick action button text if applicable
    if (suggestion.action) {
      message += `\n\nSay "${this.getSuggestedCommand(suggestion.action)}" to proceed.`;
    }

    return message;
  }

  /**
   * Get user-friendly command for an action
   */
  getSuggestedCommand(action) {
    const friendlyCommands = {
      'analyze-org': 'analyze my org',
      'comprehensive-improve': 'improve coverage',
      'cost': 'show costs',
      'clear-failed': 'clear failed tasks',
      'deploy-queue': 'deploy now',
      'queue-status': 'show queue',
      'coverage-report': 'show coverage'
    };

    return friendlyCommands[action] || action;
  }

  /**
   * Reset suggestion cooldown for a user
   */
  resetCooldown(userId) {
    this.lastSuggestionTime.delete(userId);
  }
}
