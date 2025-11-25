// src/utils/ai-cost-tracker.js
// Shared utility for tracking AI API costs across services

import { CostTracker } from '../phase2/cost-tracker.js';

let costTrackerInstance = null;

/**
 * Get or create a singleton CostTracker instance
 */
export function getCostTracker() {
  if (!costTrackerInstance) {
    costTrackerInstance = new CostTracker();
  }
  return costTrackerInstance;
}

/**
 * Track usage from an Anthropic API response
 * @param {Object} response - Anthropic API response
 * @param {string} taskId - Optional task ID for tracking
 * @param {string} model - Model name override (optional, auto-detected from response)
 */
export function trackApiUsage(response, taskId = null, model = null) {
  try {
    const tracker = getCostTracker();

    const usage = {
      model: model || response.model || 'claude-sonnet-4-20250514',
      inputTokens: response.usage.input_tokens,
      outputTokens: response.usage.output_tokens,
      cacheReadTokens: response.usage.cache_read_input_tokens || 0,
      cacheCreationTokens: response.usage.cache_creation_input_tokens || 0,
      taskId: taskId
    };

    tracker.addUsage(usage);

    return {
      tracked: true,
      usage
    };
  } catch (error) {
    console.error('Failed to track API usage:', error);
    return {
      tracked: false,
      error: error.message
    };
  }
}

/**
 * Extract usage object from Anthropic response for return values
 * @param {Object} response - Anthropic API response
 */
export function extractUsage(response) {
  return {
    inputTokens: response.usage.input_tokens,
    outputTokens: response.usage.output_tokens,
    cacheReadTokens: response.usage.cache_read_input_tokens || 0,
    cacheCreationTokens: response.usage.cache_creation_input_tokens || 0,
    model: response.model
  };
}

/**
 * Get current cost statistics
 */
export async function getCostStats() {
  const tracker = getCostTracker();
  return {
    today: tracker.getCurrentUsage(),
    monthly: await tracker.getMonthlyTotal(),
    report: await tracker.getMonthlyReport()
  };
}
