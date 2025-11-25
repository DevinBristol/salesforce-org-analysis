// src/phase2/mobile-formatters.js
// Mobile-optimized formatters for conversational responses

/**
 * Format execution plan for mobile (concise, scannable)
 */
export function formatMobilePlan(plan) {
  const blocks = [
    {
      type: 'header',
      text: {
        type: 'plain_text',
        text: plan.title
      }
    }
  ];

  // Description
  if (plan.description) {
    blocks.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: plan.description
      }
    });
  }

  // Actions (if present)
  if (plan.actions && plan.actions.length > 0) {
    const actionText = plan.actions.map((action, i) => `${i + 1}. ${action}`).join('\n');
    blocks.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `*Steps:*\n${actionText}`
      }
    });
  }

  // Phases (for comprehensive plans)
  if (plan.phases && plan.phases.length > 0) {
    const phaseText = plan.phases.map(phase =>
      `*${phase.name}*\n${phase.actions.join('\n')}\n${phase.cost} | ${phase.time}`
    ).join('\n\n');
    blocks.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: phaseText
      }
    });
  }

  // Impact
  if (plan.impact) {
    const impactLines = Object.entries(plan.impact)
      .map(([key, value]) => `• ${key}: ${value}`)
      .join('\n');
    blocks.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `*Impact:*\n${impactLines}`
      }
    });
  }

  // Resources (cost, time)
  if (plan.resources) {
    blocks.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `💰 ${plan.resources.cost} | ⏱️ ${plan.resources.time}`
      }
    });
  }

  // Status (for info-only plans)
  if (plan.status) {
    const statusText = Object.entries(plan.status)
      .map(([key, value]) => `*${key}:* ${value}`)
      .join('\n');
    blocks.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: statusText
      }
    });
  }

  // Approval prompt
  if (plan.requiresApproval) {
    blocks.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `Type *${plan.approvalText || 'APPROVE'}* to proceed or *CANCEL* to abort.`
      }
    });
  }

  // Build text fallback
  let textFallback = plan.title;
  if (plan.description) textFallback += ` - ${plan.description}`;
  if (plan.resources) textFallback += ` | Cost: ${plan.resources.cost}, Time: ${plan.resources.time}`;

  return {
    text: textFallback,
    blocks
  };
}

/**
 * Format simple text response for mobile
 */
export function formatMobileText(text, emoji = null) {
  return {
    text: emoji ? `${emoji} ${text}` : text
  };
}

/**
 * Format suggestion message
 */
export function formatSuggestion(suggestion) {
  return {
    text: suggestion.message,
    blocks: [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: suggestion.message
        }
      }
    ]
  };
}

/**
 * Format clarification question
 */
export function formatClarification(question, options = null) {
  const blocks = [
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `❓ ${question}`
      }
    }
  ];

  // Add options as buttons if provided
  if (options && options.length > 0) {
    blocks.push({
      type: 'actions',
      elements: options.slice(0, 5).map(option => ({
        type: 'button',
        text: { type: 'plain_text', text: option.label },
        value: option.value,
        action_id: 'clarification_response'
      }))
    });
  }

  return {
    text: question,
    blocks
  };
}

/**
 * Format progress update (mobile-optimized)
 */
export function formatMobileProgress(progress) {
  const percentage = Math.round((progress.completed / progress.total) * 100);
  const progressBar = '▓'.repeat(Math.floor(percentage / 10)) + '░'.repeat(10 - Math.floor(percentage / 10));

  return {
    text: `⏳ Progress: ${progress.completed}/${progress.total} (${percentage}%)\n${progressBar}\n\n${progress.currentTask || 'Processing...'}`
  };
}

/**
 * Format thinking/processing indicator
 */
export function formatThinking(message = "Thinking...") {
  return {
    text: `🤔 ${message}`
  };
}

/**
 * Format error message (mobile-friendly)
 */
export function formatError(error) {
  return {
    text: `❌ ${error.message || 'Something went wrong. Please try again.'}`
  };
}

/**
 * Format success message
 */
export function formatSuccess(message) {
  return {
    text: `✅ ${message}`
  };
}
