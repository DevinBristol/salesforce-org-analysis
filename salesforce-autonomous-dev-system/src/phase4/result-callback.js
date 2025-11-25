/**
 * Result Callback System for Phase 4
 *
 * Provides async result handling with multiple delivery mechanisms:
 * - Slack notifications
 * - Webhook callbacks
 * - Event-driven notifications
 * - Result persistence and retrieval
 */

import EventEmitter from 'events';
import https from 'https';
import http from 'http';
import { URL } from 'url';

class ResultCallbackSystem extends EventEmitter {
    constructor(options = {}) {
        super();

        this.db = options.db;
        this.slackBot = options.slackBot;
        this.logger = options.logger || console;

        // Callback registry - maps task IDs to callback configurations
        this.callbackRegistry = new Map();

        // Result cache for retrieval
        this.resultCache = new Map();
        this.maxCacheSize = options.maxCacheSize || 1000;
        this.cacheTTL = options.cacheTTL || 24 * 60 * 60 * 1000; // 24 hours

        // Retry configuration
        this.maxRetries = options.maxRetries || 3;
        this.retryDelay = options.retryDelay || 5000;

        // Webhook timeout
        this.webhookTimeout = options.webhookTimeout || 30000;

        // Start cache cleanup interval
        this.cleanupInterval = setInterval(() => this.cleanupCache(), 60 * 60 * 1000);
    }

    /**
     * Register a callback for a task
     * @param {string} taskId - Unique task identifier
     * @param {Object} callbackConfig - Callback configuration
     */
    registerCallback(taskId, callbackConfig) {
        const config = {
            taskId,
            type: callbackConfig.type || 'slack', // 'slack', 'webhook', 'event'
            slackChannel: callbackConfig.slackChannel,
            slackUserId: callbackConfig.slackUserId,
            slackThreadTs: callbackConfig.slackThreadTs,
            webhookUrl: callbackConfig.webhookUrl,
            webhookHeaders: callbackConfig.webhookHeaders || {},
            webhookMethod: callbackConfig.webhookMethod || 'POST',
            eventName: callbackConfig.eventName,
            metadata: callbackConfig.metadata || {},
            retryCount: 0,
            registeredAt: new Date().toISOString(),
            status: 'pending'
        };

        this.callbackRegistry.set(taskId, config);
        this.logger.info(`[ResultCallback] Registered callback for task ${taskId}`, { type: config.type });

        // Persist to database if available
        if (this.db) {
            this.persistCallback(taskId, config).catch(err => {
                this.logger.error(`[ResultCallback] Failed to persist callback: ${err.message}`);
            });
        }

        return config;
    }

    /**
     * Deliver a result to registered callbacks
     * @param {string} taskId - Task identifier
     * @param {Object} result - Result data
     */
    async deliverResult(taskId, result) {
        const callback = this.callbackRegistry.get(taskId);

        if (!callback) {
            this.logger.warn(`[ResultCallback] No callback registered for task ${taskId}`);
            // Still cache the result for polling retrieval
            this.cacheResult(taskId, result);
            return { delivered: false, reason: 'no_callback_registered' };
        }

        // Cache result first
        this.cacheResult(taskId, result);

        // Persist result to database
        if (this.db) {
            await this.persistResult(taskId, result);
        }

        try {
            let deliveryResult;

            switch (callback.type) {
                case 'slack':
                    deliveryResult = await this.deliverSlackNotification(taskId, callback, result);
                    break;
                case 'webhook':
                    deliveryResult = await this.deliverWebhook(taskId, callback, result);
                    break;
                case 'event':
                    deliveryResult = this.deliverEvent(taskId, callback, result);
                    break;
                default:
                    throw new Error(`Unknown callback type: ${callback.type}`);
            }

            callback.status = 'delivered';
            callback.deliveredAt = new Date().toISOString();
            this.emit('result:delivered', { taskId, callback, result });

            return { delivered: true, method: callback.type, ...deliveryResult };

        } catch (error) {
            this.logger.error(`[ResultCallback] Delivery failed for task ${taskId}: ${error.message}`);

            // Attempt retry
            if (callback.retryCount < this.maxRetries) {
                callback.retryCount++;
                callback.status = 'retry_pending';

                setTimeout(() => {
                    this.deliverResult(taskId, result).catch(err => {
                        this.logger.error(`[ResultCallback] Retry failed: ${err.message}`);
                    });
                }, this.retryDelay * callback.retryCount);

                return { delivered: false, reason: 'retry_scheduled', retryCount: callback.retryCount };
            }

            callback.status = 'failed';
            callback.error = error.message;
            this.emit('result:delivery_failed', { taskId, callback, error });

            return { delivered: false, reason: 'max_retries_exceeded', error: error.message };
        }
    }

    /**
     * Deliver result via Slack notification
     */
    async deliverSlackNotification(taskId, callback, result) {
        if (!this.slackBot) {
            throw new Error('Slack bot not configured');
        }

        const message = this.formatSlackResult(taskId, callback, result);

        // Send to channel/thread or DM
        if (callback.slackChannel) {
            await this.slackBot.app.client.chat.postMessage({
                channel: callback.slackChannel,
                thread_ts: callback.slackThreadTs,
                ...message
            });
        } else if (callback.slackUserId) {
            // Open DM and send
            const dm = await this.slackBot.app.client.conversations.open({
                users: callback.slackUserId
            });
            await this.slackBot.app.client.chat.postMessage({
                channel: dm.channel.id,
                ...message
            });
        }

        return { slackDelivered: true };
    }

    /**
     * Format result for Slack display
     */
    formatSlackResult(taskId, callback, result) {
        const status = result.success ? ':white_check_mark: Success' : ':x: Failed';
        const duration = result.duration ? `${(result.duration / 1000).toFixed(1)}s` : 'N/A';

        const blocks = [
            {
                type: 'header',
                text: {
                    type: 'plain_text',
                    text: `Task Completed: ${callback.metadata.taskType || 'Unknown'}`,
                    emoji: true
                }
            },
            {
                type: 'section',
                fields: [
                    { type: 'mrkdwn', text: `*Status:*\n${status}` },
                    { type: 'mrkdwn', text: `*Duration:*\n${duration}` },
                    { type: 'mrkdwn', text: `*Task ID:*\n\`${taskId}\`` },
                    { type: 'mrkdwn', text: `*Completed:*\n${new Date().toLocaleString()}` }
                ]
            }
        ];

        // Add summary if available
        if (result.summary) {
            blocks.push({
                type: 'section',
                text: {
                    type: 'mrkdwn',
                    text: `*Summary:*\n${result.summary.substring(0, 2000)}`
                }
            });
        }

        // Add error details if failed
        if (!result.success && result.error) {
            blocks.push({
                type: 'section',
                text: {
                    type: 'mrkdwn',
                    text: `*Error:*\n\`\`\`${result.error.substring(0, 500)}\`\`\``
                }
            });
        }

        // Add action buttons
        blocks.push({
            type: 'actions',
            elements: [
                {
                    type: 'button',
                    text: { type: 'plain_text', text: 'View Details' },
                    action_id: `view_result_${taskId}`,
                    value: taskId
                },
                {
                    type: 'button',
                    text: { type: 'plain_text', text: 'Download Report' },
                    action_id: `download_result_${taskId}`,
                    value: taskId
                }
            ]
        });

        return { blocks };
    }

    /**
     * Deliver result via webhook
     */
    async deliverWebhook(taskId, callback, result) {
        return new Promise((resolve, reject) => {
            const url = new URL(callback.webhookUrl);
            const isHttps = url.protocol === 'https:';
            const lib = isHttps ? https : http;

            const payload = JSON.stringify({
                taskId,
                result,
                metadata: callback.metadata,
                timestamp: new Date().toISOString()
            });

            const options = {
                hostname: url.hostname,
                port: url.port || (isHttps ? 443 : 80),
                path: url.pathname + url.search,
                method: callback.webhookMethod,
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(payload),
                    'X-Task-Id': taskId,
                    'X-Callback-Source': 'salesforce-autonomous-dev-system',
                    ...callback.webhookHeaders
                },
                timeout: this.webhookTimeout
            };

            const req = lib.request(options, (res) => {
                let data = '';
                res.on('data', chunk => data += chunk);
                res.on('end', () => {
                    if (res.statusCode >= 200 && res.statusCode < 300) {
                        resolve({
                            webhookDelivered: true,
                            statusCode: res.statusCode,
                            response: data.substring(0, 500)
                        });
                    } else {
                        reject(new Error(`Webhook returned status ${res.statusCode}: ${data.substring(0, 200)}`));
                    }
                });
            });

            req.on('error', reject);
            req.on('timeout', () => {
                req.destroy();
                reject(new Error('Webhook request timed out'));
            });

            req.write(payload);
            req.end();
        });
    }

    /**
     * Deliver result via event emission
     */
    deliverEvent(taskId, callback, result) {
        const eventName = callback.eventName || 'task:completed';
        this.emit(eventName, {
            taskId,
            result,
            metadata: callback.metadata,
            timestamp: new Date().toISOString()
        });

        return { eventEmitted: true, eventName };
    }

    /**
     * Cache a result for later retrieval
     */
    cacheResult(taskId, result) {
        // Enforce cache size limit
        if (this.resultCache.size >= this.maxCacheSize) {
            // Remove oldest entry
            const oldestKey = this.resultCache.keys().next().value;
            this.resultCache.delete(oldestKey);
        }

        this.resultCache.set(taskId, {
            result,
            cachedAt: Date.now()
        });
    }

    /**
     * Retrieve a cached result
     */
    getResult(taskId) {
        const cached = this.resultCache.get(taskId);
        if (!cached) return null;

        // Check TTL
        if (Date.now() - cached.cachedAt > this.cacheTTL) {
            this.resultCache.delete(taskId);
            return null;
        }

        return cached.result;
    }

    /**
     * Get callback status for a task
     */
    getCallbackStatus(taskId) {
        const callback = this.callbackRegistry.get(taskId);
        if (!callback) return null;

        return {
            taskId: callback.taskId,
            type: callback.type,
            status: callback.status,
            registeredAt: callback.registeredAt,
            deliveredAt: callback.deliveredAt,
            retryCount: callback.retryCount,
            error: callback.error
        };
    }

    /**
     * Persist callback to database
     */
    async persistCallback(taskId, config) {
        const query = `
            INSERT INTO task_callbacks (task_id, callback_type, config, status, created_at)
            VALUES ($1, $2, $3, $4, NOW())
            ON CONFLICT (task_id) DO UPDATE SET
                callback_type = $2,
                config = $3,
                status = $4,
                updated_at = NOW()
        `;

        await this.db.query(query, [
            taskId,
            config.type,
            JSON.stringify(config),
            config.status
        ]);
    }

    /**
     * Persist result to database
     */
    async persistResult(taskId, result) {
        const query = `
            INSERT INTO task_results (task_id, result, success, created_at)
            VALUES ($1, $2, $3, NOW())
            ON CONFLICT (task_id) DO UPDATE SET
                result = $2,
                success = $3,
                updated_at = NOW()
        `;

        await this.db.query(query, [
            taskId,
            JSON.stringify(result),
            result.success
        ]);
    }

    /**
     * Load pending callbacks from database on startup
     */
    async loadPendingCallbacks() {
        if (!this.db) return;

        const query = `
            SELECT task_id, config FROM task_callbacks
            WHERE status IN ('pending', 'retry_pending')
            AND created_at > NOW() - INTERVAL '24 hours'
        `;

        const result = await this.db.query(query);

        for (const row of result.rows) {
            const config = JSON.parse(row.config);
            this.callbackRegistry.set(row.task_id, config);
            this.logger.info(`[ResultCallback] Loaded pending callback: ${row.task_id}`);
        }

        return result.rows.length;
    }

    /**
     * Clean up expired cache entries
     */
    cleanupCache() {
        const now = Date.now();
        let cleaned = 0;

        for (const [taskId, cached] of this.resultCache) {
            if (now - cached.cachedAt > this.cacheTTL) {
                this.resultCache.delete(taskId);
                cleaned++;
            }
        }

        if (cleaned > 0) {
            this.logger.info(`[ResultCallback] Cleaned up ${cleaned} expired cache entries`);
        }
    }

    /**
     * Get system statistics
     */
    getStats() {
        let pending = 0, delivered = 0, failed = 0;

        for (const callback of this.callbackRegistry.values()) {
            switch (callback.status) {
                case 'pending':
                case 'retry_pending':
                    pending++;
                    break;
                case 'delivered':
                    delivered++;
                    break;
                case 'failed':
                    failed++;
                    break;
            }
        }

        return {
            registeredCallbacks: this.callbackRegistry.size,
            cachedResults: this.resultCache.size,
            callbacksByStatus: { pending, delivered, failed }
        };
    }

    /**
     * Shutdown and cleanup
     */
    async shutdown() {
        clearInterval(this.cleanupInterval);
        this.removeAllListeners();
        this.callbackRegistry.clear();
        this.resultCache.clear();
        this.logger.info('[ResultCallback] System shut down');
    }
}

export { ResultCallbackSystem };
