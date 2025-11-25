// src/phase2/local-formatters.js
// Formatters for local repository operations in Slack messages

/**
 * Format git status output
 */
export function formatGitStatus(result) {
  const { repo, branch, status } = result;

  const sections = [];

  sections.push({
    type: 'section',
    text: {
      type: 'mrkdwn',
      text: `*Git Status - ${repo}*\n\n📌 Branch: \`${branch}\``
    }
  });

  if (status.clean) {
    sections.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: '✅ *Working directory is clean* - No uncommitted changes'
      }
    });
  } else {
    let statusText = '';

    if (status.modified.length > 0) {
      statusText += `\n📝 *Modified* (${status.modified.length}):\n`;
      statusText += status.modified.slice(0, 10).map(f => `  • ${f}`).join('\n');
      if (status.modified.length > 10) {
        statusText += `\n  ... and ${status.modified.length - 10} more`;
      }
    }

    if (status.added.length > 0) {
      statusText += `\n\n➕ *Added* (${status.added.length}):\n`;
      statusText += status.added.slice(0, 10).map(f => `  • ${f}`).join('\n');
      if (status.added.length > 10) {
        statusText += `\n  ... and ${status.added.length - 10} more`;
      }
    }

    if (status.untracked.length > 0) {
      statusText += `\n\n❓ *Untracked* (${status.untracked.length}):\n`;
      statusText += status.untracked.slice(0, 10).map(f => `  • ${f}`).join('\n');
      if (status.untracked.length > 10) {
        statusText += `\n  ... and ${status.untracked.length - 10} more`;
      }
    }

    if (status.deleted.length > 0) {
      statusText += `\n\n🗑️ *Deleted* (${status.deleted.length}):\n`;
      statusText += status.deleted.slice(0, 10).map(f => `  • ${f}`).join('\n');
      if (status.deleted.length > 10) {
        statusText += `\n  ... and ${status.deleted.length - 10} more`;
      }
    }

    sections.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: statusText
      }
    });
  }

  return { blocks: sections };
}

/**
 * Format git commit result
 */
export function formatGitCommit(result) {
  const { repo, committed, hash, message } = result;

  if (!committed) {
    return {
      blocks: [
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: `⚠️ *No changes to commit* in ${repo}`
          }
        }
      ]
    };
  }

  return {
    blocks: [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `✅ *Committed to ${repo}*\n\n🔖 Commit: \`${hash}\`\n💬 Message: "${message}"`
        }
      }
    ]
  };
}

/**
 * Format git push result
 */
export function formatGitPush(result) {
  const { repo, pushed, remote, branch } = result;

  return {
    blocks: [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `✅ *Pushed ${repo}*\n\n🌐 Remote: ${remote}\n📌 Branch: ${branch}`
        }
      }
    ]
  };
}

/**
 * Format git diff output
 */
export function formatGitDiff(result) {
  const { repo, diff, staged, file } = result;

  if (!diff || diff.trim() === '') {
    return {
      blocks: [
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: `ℹ️ *No differences* found in ${repo}${file ? ` for ${file}` : ''}`
          }
        }
      ]
    };
  }

  // Truncate diff for Slack
  const maxLines = 20;
  const diffLines = diff.split('\n');
  const truncated = diffLines.length > maxLines;
  const displayDiff = diffLines.slice(0, maxLines).join('\n');

  const sections = [
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `*Git Diff - ${repo}*${staged ? ' (staged)' : ''}${file ? `\n📄 File: ${file}` : ''}`
      }
    },
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `\`\`\`\n${displayDiff}\n\`\`\``
      }
    }
  ];

  if (truncated) {
    sections.push({
      type: 'context',
      elements: [
        {
          type: 'mrkdwn',
          text: `_Showing first ${maxLines} lines of ${diffLines.length}. Use "git diff" command for full output._`
        }
      ]
    });
  }

  return { blocks: sections };
}

/**
 * Format codebase analysis result
 */
export function formatCodebaseAnalysis(result) {
  const { repo, analysis, fileCount } = result;

  return {
    text: `Codebase Analysis - ${repo}: ${fileCount} files analyzed`,
    blocks: [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Codebase Analysis - ${repo}*\n\n📁 ${fileCount} files analyzed`
        }
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: analysis
        }
      }
    ]
  };
}

/**
 * Format code search results
 */
export function formatCodeSearch(result) {
  const { pattern, matchCount, matches } = result;

  if (matchCount === 0) {
    return {
      blocks: [
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: `🔍 No matches found for pattern: \`${pattern}\``
          }
        }
      ]
    };
  }

  const sections = [
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `🔍 *Search Results*\n\nPattern: \`${pattern}\`\nMatches: ${matchCount}`
      }
    }
  ];

  if (matches && matches.length > 0) {
    let matchText = '';
    matches.slice(0, 15).forEach(match => {
      matchText += `\n📄 \`${match.file}:${match.line}\`\n    ${match.content}\n`;
    });

    if (matches.length > 15) {
      matchText += `\n... and ${matches.length - 15} more matches`;
    }

    sections.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: matchText
      }
    });
  }

  return { blocks: sections };
}

/**
 * Format file editing results
 */
export function formatFileEdits(result) {
  const { filesEdited, files } = result;

  const sections = [
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `✅ *Files Edited*\n\n${filesEdited} file${filesEdited !== 1 ? 's' : ''} modified`
      }
    }
  ];

  if (files && files.length > 0) {
    const fileList = files.map(f => `  • ${f.file}`).join('\n');
    sections.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: fileList
      }
    });
  }

  return { blocks: sections };
}

/**
 * Format refactoring results
 */
export function formatRefactoring(result) {
  const { filesRefactored, changes } = result;

  return {
    blocks: [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `✅ *Code Refactored*\n\n${filesRefactored} file${filesRefactored !== 1 ? 's' : ''} refactored`
        }
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Changes:*\n${changes}`
        }
      }
    ]
  };
}

/**
 * Format test run results
 */
export function formatTestResults(result) {
  const { repo, command, passed, output, errors } = result;

  const statusEmoji = passed ? '✅' : '❌';
  const statusText = passed ? 'PASSED' : 'FAILED';

  const sections = [
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `${statusEmoji} *Tests ${statusText}* - ${repo}\n\n📦 Command: \`${command}\``
      }
    }
  ];

  if (!passed && errors) {
    // Show first few lines of error
    const errorLines = errors.split('\n').slice(0, 15).join('\n');
    sections.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `\`\`\`\n${errorLines}\n\`\`\``
      }
    });
  }

  // Show truncated output
  if (output) {
    const outputLines = output.split('\n');
    const summary = outputLines.slice(-10).join('\n'); // Last 10 lines
    sections.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `*Output (last 10 lines):*\n\`\`\`\n${summary}\n\`\`\``
      }
    });
  }

  return { blocks: sections };
}

/**
 * Format build results
 */
export function formatBuildResults(result) {
  const { repo, command, success, output, errors } = result;

  const statusEmoji = success ? '✅' : '❌';
  const statusText = success ? 'SUCCESS' : 'FAILED';

  const sections = [
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `${statusEmoji} *Build ${statusText}* - ${repo}\n\n🔨 Command: \`${command}\``
      }
    }
  ];

  if (!success && errors) {
    const errorLines = errors.split('\n').slice(0, 15).join('\n');
    sections.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `*Errors:*\n\`\`\`\n${errorLines}\n\`\`\``
      }
    });
  }

  return { blocks: sections };
}

/**
 * Format find files results
 */
export function formatFindFiles(result) {
  const { filePattern, fileCount, files } = result;

  const sections = [
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `🔍 *Files Found*\n\nPattern: \`${filePattern}\`\nMatches: ${fileCount}`
      }
    }
  ];

  if (files && files.length > 0) {
    const fileList = files.slice(0, 30).map(f => `  • ${f}`).join('\n');
    let text = fileList;

    if (files.length > 30) {
      text += `\n\n... and ${files.length - 30} more files`;
    }

    sections.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text
      }
    });
  }

  return { blocks: sections };
}

/**
 * Format symbol rename results
 */
export function formatSymbolRename(result) {
  const { symbolName, newName, filesModified, files } = result;

  const sections = [
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: `✅ *Symbol Renamed*\n\n\`${symbolName}\` → \`${newName}\`\n\n${filesModified} file${filesModified !== 1 ? 's' : ''} modified`
      }
    }
  ];

  if (files && files.length > 0) {
    const fileList = files.slice(0, 20).map(f => `  • ${f}`).join('\n');
    let text = fileList;

    if (files.length > 20) {
      text += `\n\n... and ${files.length - 20} more files`;
    }

    sections.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text
      }
    });
  }

  return { blocks: sections };
}

/**
 * Format branch creation result
 */
export function formatBranchCreation(result) {
  const { repo, branch, checkedOut } = result;

  return {
    blocks: [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `✅ *Branch Created* - ${repo}\n\n🌿 Branch: \`${branch}\`${checkedOut ? '\n✓ Checked out' : ''}`
        }
      }
    ]
  };
}

/**
 * Format local operation plan for approval
 */
export function formatLocalOperationPlan(plan) {
  const { command, parameters, estimatedCost, estimatedTime, description } = plan;

  return {
    text: `Execution Plan: ${description} - Cost: $${estimatedCost.toFixed(2)}, Time: ~${estimatedTime} min`,
    blocks: [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*📝 Execution Plan*\n\n${description}`
        }
      },
      {
        type: 'section',
        fields: [
          {
            type: 'mrkdwn',
            text: `*Operation:*\n\`${command}\``
          },
          {
            type: 'mrkdwn',
            text: `*Repo:*\n${parameters.repo || 'salesforce-autonomous-dev-system'}`
          },
          {
            type: 'mrkdwn',
            text: `*Estimated Cost:*\n$${estimatedCost.toFixed(2)}`
          },
          {
            type: 'mrkdwn',
            text: `*Estimated Time:*\n~${estimatedTime} min`
          }
        ]
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: '⚠️ Type *APPROVE* to proceed or *CANCEL* to abort.'
        }
      }
    ]
  };
}

/**
 * Format generic local operation result
 */
export function formatLocalResult(result, operation = 'Operation') {
  if (result.error) {
    return {
      blocks: [
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: `❌ *${operation} Failed*\n\nError: ${result.error}`
          }
        }
      ]
    };
  }

  return {
    blocks: [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `✅ *${operation} Complete*`
        }
      }
    ]
  };
}
