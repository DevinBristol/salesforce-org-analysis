// src/phase2/error-reporter.js
import { WebClient } from '@slack/web-api';

export class ErrorReporter {
  constructor() {
    this.slackClient = new WebClient(process.env.SLACK_BOT_TOKEN);
    this.errorChannel = process.env.ERROR_CHANNEL || process.env.SLACK_CHANNEL;
    this.lastErrorTime = 0;
    this.errorCooldown = 60000; // 1 minute cooldown to prevent spam
  }

  async reportError(error, context = {}) {
    // Rate limiting to prevent spam
    const now = Date.now();
    if (now - this.lastErrorTime < this.errorCooldown) {
      console.log('[ErrorReporter] Skipping error report (cooldown active)');
      return;
    }
    this.lastErrorTime = now;

    const errorMessage = {
      text: `Bot Error: ${error.message}`,
      blocks: [
        {
          type: 'header',
          text: {
            type: 'plain_text',
            text: '🚨 Bot Error Detected'
          }
        },
        {
          type: 'section',
          fields: [
            {
              type: 'mrkdwn',
              text: `*Error:*\n\`\`\`${error.message}\`\`\``
            },
            {
              type: 'mrkdwn',
              text: `*Time:*\n${new Date().toISOString()}`
            }
          ]
        }
      ]
    };

    // Add context if provided
    if (Object.keys(context).length > 0) {
      errorMessage.blocks.push({
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Context:*\n${JSON.stringify(context, null, 2)}`
        }
      });
    }

    // Add stack trace if available
    if (error.stack) {
      const stackLines = error.stack.split('\n').slice(0, 5).join('\n');
      errorMessage.blocks.push({
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Stack Trace:*\n\`\`\`${stackLines}\`\`\``
        }
      });
    }

    // Add recovery suggestion
    errorMessage.blocks.push({
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: '💡 *Recovery Options:*\n• Use `/sf-dev restart-bot` to restart\n• Check logs: `npm run slack-bot:logs`\n• The bot will attempt auto-recovery'
      }
    });

    try {
      if (this.errorChannel) {
        await this.slackClient.chat.postMessage({
          channel: this.errorChannel,
          ...errorMessage
        });
        console.log('[ErrorReporter] Error reported to Slack');
      } else {
        console.warn('[ErrorReporter] No error channel configured, cannot report to Slack');
      }
    } catch (reportError) {
      console.error('[ErrorReporter] Failed to report error to Slack:', reportError);
    }
  }

  async reportRecovery(action) {
    try {
      if (this.errorChannel) {
        await this.slackClient.chat.postMessage({
          channel: this.errorChannel,
          text: `Recovery: ${action}`,
          blocks: [
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: `✅ *Auto-Recovery*\n\n${action}\n\nTime: ${new Date().toISOString()}`
              }
            }
          ]
        });
        console.log('[ErrorReporter] Recovery reported to Slack');
      }
    } catch (reportError) {
      console.error('[ErrorReporter] Failed to report recovery to Slack:', reportError);
    }
  }

  async reportCrash(error) {
    try {
      if (this.errorChannel) {
        await this.slackClient.chat.postMessage({
          channel: this.errorChannel,
          text: `Bot Crashed: ${error.message}`,
          blocks: [
            {
              type: 'header',
              text: {
                type: 'plain_text',
                text: '💥 Bot Crashed'
              }
            },
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: `*Error:* ${error.message}\n\n*The bot will attempt to restart automatically.*\n\nIf it doesn't come back online, check:\n• Process manager (pm2/systemd)\n• Application logs\n• Environment variables`
              }
            }
          ]
        });
        console.log('[ErrorReporter] Crash reported to Slack');
      }
    } catch (reportError) {
      console.error('[ErrorReporter] Failed to report crash to Slack:', reportError);
    }
  }
}
