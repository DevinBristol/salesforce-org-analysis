// src/phase2/slack-formatters.js
// Utility functions for formatting Slack block messages

/**
 * Creates a status block with system metrics
 */
export function formatStatusBlock(stats) {
  return {
    text: `System Status: ${stats.activeWorkers} workers active, ${stats.activeTasks} tasks running, Queue: ${stats.queueSize}, Cost: $${stats.costUsage.toFixed(2)}`,
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: '🤖 Phase 3 System Status'
        }
      },
      {
        type: 'section',
        fields: [
          {
            type: 'mrkdwn',
            text: `*Active Workers:* ${stats.activeWorkers}`
          },
          {
            type: 'mrkdwn',
            text: `*Active Tasks:* ${stats.activeTasks}`
          },
          {
            type: 'mrkdwn',
            text: `*Queue Size:* ${stats.queueSize}`
          },
          {
            type: 'mrkdwn',
            text: `*Cost Today:* $${stats.costUsage.toFixed(2)}`
          }
        ]
      }
    ]
  };
}

/**
 * Creates a quality scan report block
 */
export function formatQualityReport(className, analysis) {
  const scoreEmoji = analysis.score >= 80 ? '✅' : analysis.score >= 50 ? '⚠️' : '🔴';

  const issueBlocks = [];
  if (analysis.issues.critical.length > 0) {
    issueBlocks.push(`• 🔴 Critical (${analysis.issues.critical.length}): ${analysis.issues.critical.join(', ')}`);
  }
  if (analysis.issues.high.length > 0) {
    issueBlocks.push(`• 🟡 High (${analysis.issues.high.length}): ${analysis.issues.high.join(', ')}`);
  }
  if (analysis.issues.medium.length > 0) {
    issueBlocks.push(`• 🟢 Medium (${analysis.issues.medium.length}): ${analysis.issues.medium.join(', ')}`);
  }

  return {
    text: `Quality Analysis: ${className} - Score: ${analysis.score}/100`,
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: `📊 Quality Analysis: ${className}`
        }
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Score:* ${analysis.score}/100 ${scoreEmoji}\n\n*Issues Found:*\n${issueBlocks.join('\n')}\n\n*Estimated improvement cost:* $${analysis.estimatedCost.toFixed(2)} | *Time:* ~${analysis.estimatedTime} min`
        }
      },
      {
        type: 'actions',
        elements: [
          {
            type: 'button',
            text: { type: 'plain_text', text: 'Improve Now' },
            style: 'primary',
            value: `improve_${className}`,
            action_id: 'improve_test'
          },
          {
            type: 'button',
            text: { type: 'plain_text', text: 'View Details' },
            value: `details_${className}`,
            action_id: 'view_details'
          },
          {
            type: 'button',
            text: { type: 'plain_text', text: 'Ignore' },
            style: 'danger',
            value: `ignore_${className}`,
            action_id: 'ignore_issue'
          }
        ]
      }
    ]
  };
}

/**
 * Creates a comprehensive improvement plan block
 */
export function formatComprehensivePlan(plan) {
  return {
    text: `Comprehensive Improvement Plan: Total Cost $${plan.totalCost.toFixed(2)}, Time ~${plan.totalTime} min, Coverage ${plan.currentCoverage}% → ${plan.targetCoverage}%`,
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: '📋 Comprehensive Improvement Plan'
        }
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Phase 1: Improve Low-Quality Tests*\n• ${plan.phase1.count} tests scoring <70\n• Estimated cost: $${plan.phase1.cost.toFixed(2)} | Time: ~${plan.phase1.time} min\n\n*Phase 2: Generate Missing Tests*\n• ${plan.phase2.count} classes with <75% coverage\n• Estimated cost: $${plan.phase2.cost.toFixed(2)} | Time: ~${plan.phase2.time} min\n\n*Phase 3: Deploy & Validate*\n• Total items: ${plan.phase3.items} test classes\n• Deployment time: ~${plan.phase3.time} min\n\n*Total Cost:* $${plan.totalCost.toFixed(2)} | *Total Time:* ~${plan.totalTime} min\nCurrent coverage: ${plan.currentCoverage}% → Target: ${plan.targetCoverage}%`
        }
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `⚠️ This will make changes to ${plan.totalItems} test classes.\n\nType *APPROVE* to proceed or *CANCEL* to abort.`
        }
      }
    ]
  };
}

/**
 * Creates a progress update block
 */
export function formatProgressUpdate(progress) {
  const percentage = Math.round((progress.completed / progress.total) * 100);
  const barLength = 20;
  const filledBars = Math.round((percentage / 100) * barLength);
  const progressBar = '█'.repeat(filledBars) + '░'.repeat(barLength - filledBars);

  return {
    text: `Progress Update: ${progress.completed}/${progress.total} (${percentage}%) completed, Cost: $${progress.costSoFar.toFixed(2)}, Time remaining: ~${progress.timeRemaining} min`,
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: '📊 Progress Update'
        }
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Completed:* ${progress.completed}/${progress.total} (${percentage}%) ${progressBar}\n*In Progress:* ${progress.inProgress} tasks (Workers: ${progress.activeWorkers.join(', ')})\n*Pending:* ${progress.pending} tasks\n*Failed:* ${progress.failed} tasks\n\n*Cost so far:* $${progress.costSoFar.toFixed(2)} / $${progress.estimatedTotal.toFixed(2)} estimated\n*Time remaining:* ~${progress.timeRemaining} minutes`
        }
      },
      {
        type: 'actions',
        elements: [
          {
            type: 'button',
            text: { type: 'plain_text', text: 'View Details' },
            value: 'view_progress_details',
            action_id: 'view_details'
          },
          {
            type: 'button',
            text: { type: 'plain_text', text: 'Pause Queue' },
            style: 'danger',
            value: 'pause_queue',
            action_id: 'pause_queue'
          }
        ]
      }
    ]
  };
}

/**
 * Creates a deployment confirmation block
 */
export function formatDeploymentConfirmation(deployment) {
  const fileList = deployment.files.length > 10
    ? `${deployment.files.slice(0, 10).join('\n')}\n... and ${deployment.files.length - 10} more`
    : deployment.files.join('\n');

  return {
    text: `Deployment Confirmation Required: ${deployment.files.length} files to ${deployment.targetOrg}, Time: ~${deployment.estimatedTime} min, Coverage: ${deployment.currentCoverage}% → ${deployment.projectedCoverage}%`,
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: '🚀 Deployment Confirmation Required'
        }
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Target Org:* ${deployment.targetOrg}\n*Files to deploy:* ${deployment.files.length}\n\n\`\`\`${fileList}\`\`\`\n\n*Estimated deployment time:* ~${deployment.estimatedTime} min\n*Test coverage impact:* ${deployment.currentCoverage}% → ${deployment.projectedCoverage}%`
        }
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `⚠️ *This will deploy to ${deployment.targetOrg}.*\n\nType *DEPLOY* to confirm or *CANCEL* to abort.`
        }
      }
    ]
  };
}

/**
 * Creates a cost warning block
 */
export function formatCostWarning(costData) {
  const percentage = Math.round((costData.used / costData.budget) * 100);
  const emoji = percentage >= 100 ? '🔴' : percentage >= 80 ? '⚠️' : '🟡';

  return {
    text: `Budget Alert: Used $${costData.used.toFixed(2)} of $${costData.budget.toFixed(2)} (${percentage}%), Queue cost: $${costData.queueCost.toFixed(2)}, Remaining tasks: ${costData.remainingTasks}`,
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: `${emoji} Budget Alert`
        }
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `You've used *$${costData.used.toFixed(2)}* of your *$${costData.budget.toFixed(2)}* monthly budget (${percentage}%)\n\nCurrent queue will cost an additional ~$${costData.queueCost.toFixed(2)}\n\n*Recommendations:*\n• Pause non-critical tasks\n• Increase budget: \`/sf-dev set-budget [amount]\`\n• Review cost report: \`/sf-dev cost\`\n\nRemaining tasks: ${costData.remainingTasks} | Est. additional cost: $${costData.queueCost.toFixed(2)}`
        }
      },
      {
        type: 'actions',
        elements: [
          {
            type: 'button',
            text: { type: 'plain_text', text: 'Pause Queue' },
            style: 'danger',
            value: 'pause_queue',
            action_id: 'pause_queue'
          },
          {
            type: 'button',
            text: { type: 'plain_text', text: 'Increase Budget' },
            value: 'increase_budget',
            action_id: 'increase_budget'
          },
          {
            type: 'button',
            text: { type: 'plain_text', text: 'Continue Anyway' },
            style: 'primary',
            value: 'continue_anyway',
            action_id: 'continue_anyway'
          }
        ]
      }
    ]
  };
}

/**
 * Creates an error recovery block
 */
export function formatErrorRecovery(error) {
  return {
    text: `Task Failed: ${error.taskId} - ${error.taskType} - Error: ${error.message} - Queue: ${error.queueSize} tasks pending`,
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: '❌ Task Failed'
        }
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Task:* ${error.taskId} - ${error.taskType}\n\n*Error:* ${error.message}\n\n*Recommended Actions:*\n1. ⏸️ ${error.recommendations[0]}\n2. 🔄 ${error.recommendations[1]}\n3. ❌ ${error.recommendations[2]}\n\nCurrent queue: ${error.queueSize} tasks pending\n\nWhat would you like to do?`
        }
      },
      {
        type: 'actions',
        elements: error.actions.map(action => ({
          type: 'button',
          text: { type: 'plain_text', text: action.label },
          style: action.style || undefined,
          value: action.value,
          action_id: action.action_id
        }))
      }
    ]
  };
}

/**
 * Creates a coverage report block
 */
export function formatCoverageReport(coverage) {
  const classLines = coverage.classes
    .slice(0, 15)
    .map(cls => {
      const emoji = cls.coverage >= 90 ? '🟢' : cls.coverage >= 75 ? '🟡' : '🔴';
      return `${emoji} ${cls.name}: ${cls.coverage}%`;
    })
    .join('\n');

  const moreClasses = coverage.classes.length > 15 ? `\n... and ${coverage.classes.length - 15} more classes` : '';

  return {
    text: `Coverage Report: Org-Wide ${coverage.orgWide}%, Total Classes: ${coverage.totalClasses}, Classes <75%: ${coverage.lowCoverage}`,
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: '📊 Coverage Report'
        }
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Org-Wide Coverage:* ${coverage.orgWide}%\n*Total Classes:* ${coverage.totalClasses}\n*Classes <75%:* ${coverage.lowCoverage}\n\n*Coverage by Class:*\n\`\`\`${classLines}${moreClasses}\`\`\``
        }
      },
      {
        type: 'actions',
        elements: [
          {
            type: 'button',
            text: { type: 'plain_text', text: 'Improve Low Coverage' },
            style: 'primary',
            value: 'improve_low_coverage',
            action_id: 'improve_coverage'
          },
          {
            type: 'button',
            text: { type: 'plain_text', text: 'Export Full Report' },
            value: 'export_report',
            action_id: 'export_report'
          }
        ]
      }
    ]
  };
}

/**
 * Creates a simple confirmation prompt
 */
export function formatConfirmation(title, message, confirmText = 'Confirm', cancelText = 'Cancel') {
  return {
    text: `${title}: ${message}`,
    blocks: [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*${title}*\n\n${message}`
        }
      },
      {
        type: 'actions',
        elements: [
          {
            type: 'button',
            text: { type: 'plain_text', text: confirmText },
            style: 'primary',
            value: 'confirm',
            action_id: 'confirm_action'
          },
          {
            type: 'button',
            text: { type: 'plain_text', text: cancelText },
            style: 'danger',
            value: 'cancel',
            action_id: 'cancel_action'
          }
        ]
      }
    ]
  };
}

/**
 * Creates a help message block
 */
export function formatHelpMessage(command) {
  const commands = {
    'status': {
      description: 'Shows real-time system status',
      usage: '/sf-dev status',
      examples: ['/sf-dev status']
    },
    'improve-tests': {
      description: 'Improves existing test classes',
      usage: '/sf-dev improve-tests [count]',
      examples: ['/sf-dev improve-tests 10', '/sf-dev improve-tests 5']
    },
    'generate-tests': {
      description: 'Generates missing tests for untested classes',
      usage: '/sf-dev generate-tests [count] [--coverage=90]',
      examples: ['/sf-dev generate-tests 10', '/sf-dev generate-tests 5 --coverage=95']
    },
    'quality-scan': {
      description: 'Analyzes specific test quality',
      usage: '/sf-dev quality-scan [className]',
      examples: ['/sf-dev quality-scan AccountTriggerTest']
    },
    'comprehensive-improve': {
      description: 'Runs full improvement workflow',
      usage: '/sf-dev comprehensive-improve [--target-coverage=90]',
      examples: ['/sf-dev comprehensive-improve', '/sf-dev comprehensive-improve --target-coverage=95']
    },
    'analyze-org': {
      description: 'Comprehensive org analysis',
      usage: '/sf-dev analyze-org [--deep]',
      examples: ['/sf-dev analyze-org', '/sf-dev analyze-org --deep']
    },
    'coverage-report': {
      description: 'Coverage breakdown by class',
      usage: '/sf-dev coverage-report [--by-package]',
      examples: ['/sf-dev coverage-report', '/sf-dev coverage-report --by-package']
    },
    'cost': {
      description: 'Shows cost report',
      usage: '/sf-dev cost [--forecast]',
      examples: ['/sf-dev cost', '/sf-dev cost --forecast']
    },
    'deploy-queue': {
      description: 'Deploys all ready-to-deploy items',
      usage: '/sf-dev deploy-queue [--validate-only]',
      examples: ['/sf-dev deploy-queue', '/sf-dev deploy-queue --validate-only']
    },
    'queue-status': {
      description: 'Shows queue status',
      usage: '/sf-dev queue-status [taskId]',
      examples: ['/sf-dev queue-status', '/sf-dev queue-status 123']
    }
  };

  if (command && commands[command]) {
    const cmd = commands[command];
    return {
      text: `Help: ${command} - ${cmd.description} - Usage: ${cmd.usage}`,
      blocks: [
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: `*📚 Help: ${command}*\n\n${cmd.description}\n\n*Usage:*\n\`${cmd.usage}\`\n\n*Examples:*\n${cmd.examples.map(ex => `\`${ex}\``).join('\n')}`
          }
        }
      ]
    };
  }

  // Show all commands
  const commandList = Object.keys(commands).map(cmd => {
    return `• \`${cmd}\` - ${commands[cmd].description}`;
  }).join('\n');

  return {
    text: `Available Commands: ${Object.keys(commands).length} commands available. Use /sf-dev help [command] for details.`,
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: '📚 Available Commands'
        }
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: commandList + '\n\nFor detailed help on a specific command, use:\n`/sf-dev help [command]`'
        }
      }
    ]
  };
}

/**
 * Format quality gate review result for Slack
 */
export function formatQualityGateResult(result) {
  const emoji = result.approved ? '✅' : '❌';
  const status = result.approved ? 'APPROVED' : 'REJECTED';

  const blocks = [
    {
      type: 'header',
      text: {
        type: 'plain_text',
        text: `${emoji} Quality Gate ${status}: ${result.className}`
      }
    },
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `*Reason:* ${result.reason}`
      }
    }
  ];

  // Add changes if approved and simplified
  if (result.approved && result.changes && result.changes.length > 0) {
    blocks.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `*Simplifications made:*\n${result.changes.map(c => `• ${c}`).join('\n')}`
      }
    });
  }

  return { blocks };
}

/**
 * Format batch quality gate summary for Slack
 */
export function formatQualityGateBatchSummary(summary) {
  const approvalEmoji = summary.approved > summary.rejected ? '✅' : '⚠️';

  const blocks = [
    {
      type: 'header',
      text: {
        type: 'plain_text',
        text: `${approvalEmoji} Quality Gate Batch Summary`
      }
    },
    {
      type: 'section',
      fields: [
        { type: 'mrkdwn', text: `*Total:* ${summary.total}` },
        { type: 'mrkdwn', text: `*Approved:* ${summary.approved}` },
        { type: 'mrkdwn', text: `*Rejected:* ${summary.rejected}` },
        { type: 'mrkdwn', text: `*Deployed:* ${summary.deployed}` }
      ]
    }
  ];

  // Add rejection reasons if any
  if (summary.rejectionReasons && summary.rejectionReasons.length > 0) {
    blocks.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `*Rejection reasons:*\n${summary.rejectionReasons.map(r => `• ${r.className}: ${r.reason}`).join('\n')}`
      }
    });
  }

  return { blocks };
}

/**
 * Format quality gate deployment result for Slack
 */
export function formatQualityGateDeployment(result) {
  const blocks = [];

  if (result.qualityGate === 'approved') {
    if (result.deployed) {
      blocks.push({
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `✅ *${result.className}*: Quality gate approved and deployed successfully!`
        }
      });
    } else {
      blocks.push({
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `⚠️ *${result.className}*: Quality gate approved but deployment failed: ${result.error || 'Unknown error'}`
        }
      });
    }
  } else if (result.stage === 'quality-gate') {
    blocks.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `❌ *${result.className}*: Rejected by quality gate\n_Reason:_ ${result.reason}`
      }
    });
  }

  return { blocks };
}
