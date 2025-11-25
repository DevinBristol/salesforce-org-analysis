/**
 * Monitoring System for Phase 4
 *
 * Comprehensive monitoring and observability for the autonomous development system.
 * Features:
 * - Real-time metrics collection
 * - Health checks
 * - Alerting
 * - Performance tracking
 * - Cost monitoring
 */

import EventEmitter from 'events';
import os from 'os';

class MonitoringSystem extends EventEmitter {
    constructor(options = {}) {
        super();

        this.db = options.db;
        this.slackBot = options.slackBot;
        this.logger = options.logger || console;

        // Metrics storage
        this.metrics = {
            tasks: {
                total: 0,
                completed: 0,
                failed: 0,
                inProgress: 0,
                averageDuration: 0,
                byType: {}
            },
            api: {
                claudeRequests: 0,
                claudeTokens: 0,
                claudeErrors: 0,
                salesforceRequests: 0,
                salesforceErrors: 0
            },
            system: {
                startTime: Date.now(),
                lastHealthCheck: null,
                memoryUsage: 0,
                cpuUsage: 0,
                activeWorkers: 0
            },
            cost: {
                estimatedClaude: 0,
                estimatedTotal: 0
            }
        };

        // Health check configuration
        this.healthChecks = new Map();
        this.healthCheckInterval = options.healthCheckInterval || 60000;

        // Alerting configuration
        this.alertThresholds = {
            errorRate: options.errorRateThreshold || 0.1, // 10%
            responseTime: options.responseTimeThreshold || 60000, // 60 seconds
            memoryUsage: options.memoryThreshold || 0.9, // 90%
            queueDepth: options.queueDepthThreshold || 100
        };

        // Alert channels
        this.alertChannel = options.alertChannel;
        this.alertCooldown = options.alertCooldown || 300000; // 5 minutes
        this.lastAlerts = new Map();

        // Time series data for trends
        this.timeSeries = {
            taskRate: [],
            errorRate: [],
            responseTime: [],
            tokenUsage: []
        };
        this.maxTimeSeriesLength = options.maxTimeSeriesLength || 1440; // 24 hours at 1 minute intervals

        // Start monitoring
        this.startMonitoring();
    }

    /**
     * Start all monitoring processes
     */
    startMonitoring() {
        // System metrics collection
        this.systemMetricsInterval = setInterval(() => {
            this.collectSystemMetrics();
        }, 10000);

        // Health checks
        this.healthCheckIntervalId = setInterval(() => {
            this.runHealthChecks();
        }, this.healthCheckInterval);

        // Time series aggregation
        this.timeSeriesInterval = setInterval(() => {
            this.aggregateTimeSeries();
        }, 60000);

        // Persist metrics periodically
        if (this.db) {
            this.persistInterval = setInterval(() => {
                this.persistMetrics();
            }, 300000); // Every 5 minutes
        }

        this.logger.info('[Monitoring] System started');
    }

    /**
     * Register a health check
     * @param {string} name - Check name
     * @param {Function} checkFn - Async function returning health status
     */
    registerHealthCheck(name, checkFn) {
        this.healthChecks.set(name, {
            name,
            checkFn,
            lastResult: null,
            lastCheck: null
        });

        this.logger.info(`[Monitoring] Registered health check: ${name}`);
    }

    /**
     * Run all registered health checks
     */
    async runHealthChecks() {
        const results = {};
        let overallHealthy = true;

        for (const [name, check] of this.healthChecks) {
            try {
                const start = Date.now();
                const result = await check.checkFn();
                const duration = Date.now() - start;

                results[name] = {
                    healthy: result.healthy !== false,
                    message: result.message || 'OK',
                    duration,
                    timestamp: new Date().toISOString()
                };

                check.lastResult = results[name];
                check.lastCheck = Date.now();

                if (!results[name].healthy) {
                    overallHealthy = false;
                    await this.sendAlert(`Health check failed: ${name}`, {
                        check: name,
                        message: result.message
                    }, 'warning');
                }

            } catch (error) {
                results[name] = {
                    healthy: false,
                    message: error.message,
                    duration: 0,
                    timestamp: new Date().toISOString()
                };
                overallHealthy = false;

                await this.sendAlert(`Health check error: ${name}`, {
                    check: name,
                    error: error.message
                }, 'error');
            }
        }

        this.metrics.system.lastHealthCheck = new Date().toISOString();
        this.emit('health:checked', { results, overallHealthy });

        return { results, overallHealthy };
    }

    /**
     * Collect system metrics
     */
    collectSystemMetrics() {
        // Memory usage
        const memUsage = process.memoryUsage();
        this.metrics.system.memoryUsage = memUsage.heapUsed / memUsage.heapTotal;

        // CPU usage (simple approximation)
        const cpus = os.cpus();
        let totalIdle = 0, totalTick = 0;
        cpus.forEach(cpu => {
            for (const type in cpu.times) {
                totalTick += cpu.times[type];
            }
            totalIdle += cpu.times.idle;
        });
        this.metrics.system.cpuUsage = 1 - (totalIdle / totalTick);

        // Check thresholds
        if (this.metrics.system.memoryUsage > this.alertThresholds.memoryUsage) {
            this.sendAlert('High memory usage', {
                usage: Math.round(this.metrics.system.memoryUsage * 100) + '%'
            }, 'warning');
        }
    }

    /**
     * Track a task event
     * @param {string} event - Event type (started, completed, failed)
     * @param {Object} data - Event data
     */
    trackTask(event, data) {
        switch (event) {
            case 'started':
                this.metrics.tasks.total++;
                this.metrics.tasks.inProgress++;
                if (data.type) {
                    this.metrics.tasks.byType[data.type] = (this.metrics.tasks.byType[data.type] || 0) + 1;
                }
                break;

            case 'completed':
                this.metrics.tasks.completed++;
                this.metrics.tasks.inProgress = Math.max(0, this.metrics.tasks.inProgress - 1);
                if (data.duration) {
                    this.updateAverageDuration(data.duration);
                }
                break;

            case 'failed':
                this.metrics.tasks.failed++;
                this.metrics.tasks.inProgress = Math.max(0, this.metrics.tasks.inProgress - 1);
                this.checkErrorRate();
                break;
        }

        this.emit('task:tracked', { event, data });
    }

    /**
     * Update average task duration
     */
    updateAverageDuration(duration) {
        const total = this.metrics.tasks.completed;
        const current = this.metrics.tasks.averageDuration;
        // Running average
        this.metrics.tasks.averageDuration = ((current * (total - 1)) + duration) / total;
    }

    /**
     * Check and alert on error rate
     */
    checkErrorRate() {
        const total = this.metrics.tasks.total;
        if (total < 10) return; // Need minimum samples

        const errorRate = this.metrics.tasks.failed / total;
        if (errorRate > this.alertThresholds.errorRate) {
            this.sendAlert('High task error rate', {
                rate: Math.round(errorRate * 100) + '%',
                failed: this.metrics.tasks.failed,
                total: this.metrics.tasks.total
            }, 'error');
        }
    }

    /**
     * Track API usage
     * @param {string} api - API name (claude, salesforce)
     * @param {Object} data - Usage data
     */
    trackApiUsage(api, data) {
        switch (api) {
            case 'claude':
                this.metrics.api.claudeRequests++;
                if (data.tokens) {
                    this.metrics.api.claudeTokens += data.tokens;
                    this.updateCostEstimate(data.tokens, data.model);
                }
                if (data.error) {
                    this.metrics.api.claudeErrors++;
                }
                break;

            case 'salesforce':
                this.metrics.api.salesforceRequests++;
                if (data.error) {
                    this.metrics.api.salesforceErrors++;
                }
                break;
        }

        this.emit('api:tracked', { api, data });
    }

    /**
     * Update cost estimate based on token usage
     */
    updateCostEstimate(tokens, model = 'claude-sonnet-4-20250514') {
        // Pricing per 1M tokens (approximate)
        const pricing = {
            'claude-opus-4-20250514': { input: 15, output: 75 },
            'claude-sonnet-4-20250514': { input: 3, output: 15 },
            'claude-3-haiku-20240307': { input: 0.25, output: 1.25 }
        };

        const rates = pricing[model] || pricing['claude-sonnet-4-20250514'];
        // Assume 70% input, 30% output ratio
        const inputTokens = tokens * 0.7;
        const outputTokens = tokens * 0.3;

        const cost = (inputTokens * rates.input + outputTokens * rates.output) / 1000000;
        this.metrics.cost.estimatedClaude += cost;
        this.metrics.cost.estimatedTotal = this.metrics.cost.estimatedClaude;
    }

    /**
     * Aggregate time series data
     */
    aggregateTimeSeries() {
        const now = Date.now();

        // Task rate (tasks per minute)
        this.timeSeries.taskRate.push({
            timestamp: now,
            value: this.metrics.tasks.total
        });

        // Error rate
        const errorRate = this.metrics.tasks.total > 0
            ? this.metrics.tasks.failed / this.metrics.tasks.total
            : 0;
        this.timeSeries.errorRate.push({
            timestamp: now,
            value: errorRate
        });

        // Response time
        this.timeSeries.responseTime.push({
            timestamp: now,
            value: this.metrics.tasks.averageDuration
        });

        // Token usage
        this.timeSeries.tokenUsage.push({
            timestamp: now,
            value: this.metrics.api.claudeTokens
        });

        // Trim old data
        for (const key of Object.keys(this.timeSeries)) {
            while (this.timeSeries[key].length > this.maxTimeSeriesLength) {
                this.timeSeries[key].shift();
            }
        }
    }

    /**
     * Send an alert
     * @param {string} title - Alert title
     * @param {Object} data - Alert data
     * @param {string} severity - Alert severity (info, warning, error)
     */
    async sendAlert(title, data, severity = 'info') {
        // Check cooldown
        const alertKey = `${title}:${severity}`;
        const lastAlert = this.lastAlerts.get(alertKey);
        if (lastAlert && Date.now() - lastAlert < this.alertCooldown) {
            return; // Skip alert, still in cooldown
        }

        this.lastAlerts.set(alertKey, Date.now());

        const alert = {
            title,
            data,
            severity,
            timestamp: new Date().toISOString()
        };

        this.emit('alert', alert);
        this.logger.warn(`[Monitoring] Alert: ${title}`, data);

        // Send to Slack if configured
        if (this.slackBot && this.alertChannel) {
            try {
                const emoji = severity === 'error' ? ':rotating_light:'
                    : severity === 'warning' ? ':warning:'
                    : ':information_source:';

                await this.slackBot.app.client.chat.postMessage({
                    channel: this.alertChannel,
                    blocks: [
                        {
                            type: 'header',
                            text: {
                                type: 'plain_text',
                                text: `${emoji} ${title}`,
                                emoji: true
                            }
                        },
                        {
                            type: 'section',
                            fields: Object.entries(data).map(([k, v]) => ({
                                type: 'mrkdwn',
                                text: `*${k}:*\n${v}`
                            }))
                        },
                        {
                            type: 'context',
                            elements: [{
                                type: 'mrkdwn',
                                text: `Severity: ${severity} | Time: ${new Date().toLocaleString()}`
                            }]
                        }
                    ]
                });
            } catch (error) {
                this.logger.error(`[Monitoring] Failed to send Slack alert: ${error.message}`);
            }
        }

        // Persist alert
        if (this.db) {
            await this.persistAlert(alert);
        }
    }

    /**
     * Get current metrics snapshot
     */
    getMetrics() {
        return {
            ...this.metrics,
            uptime: Date.now() - this.metrics.system.startTime,
            timestamp: new Date().toISOString()
        };
    }

    /**
     * Get dashboard data
     */
    getDashboardData() {
        const metrics = this.getMetrics();

        return {
            summary: {
                tasksTotal: metrics.tasks.total,
                tasksCompleted: metrics.tasks.completed,
                tasksFailed: metrics.tasks.failed,
                successRate: metrics.tasks.total > 0
                    ? Math.round((metrics.tasks.completed / metrics.tasks.total) * 100)
                    : 100,
                averageResponseTime: Math.round(metrics.tasks.averageDuration / 1000),
                activeWorkers: metrics.system.activeWorkers,
                estimatedCost: metrics.cost.estimatedTotal.toFixed(2)
            },
            system: {
                uptime: this.formatUptime(metrics.uptime),
                memoryUsage: Math.round(metrics.system.memoryUsage * 100),
                cpuUsage: Math.round(metrics.system.cpuUsage * 100),
                lastHealthCheck: metrics.system.lastHealthCheck
            },
            api: {
                claudeRequests: metrics.api.claudeRequests,
                claudeTokens: this.formatNumber(metrics.api.claudeTokens),
                claudeErrors: metrics.api.claudeErrors,
                salesforceRequests: metrics.api.salesforceRequests
            },
            charts: {
                taskRate: this.timeSeries.taskRate.slice(-60),
                errorRate: this.timeSeries.errorRate.slice(-60),
                responseTime: this.timeSeries.responseTime.slice(-60),
                tokenUsage: this.timeSeries.tokenUsage.slice(-60)
            },
            tasksByType: metrics.tasks.byType,
            healthChecks: this.getHealthCheckResults()
        };
    }

    /**
     * Format uptime for display
     */
    formatUptime(ms) {
        const seconds = Math.floor(ms / 1000);
        const minutes = Math.floor(seconds / 60);
        const hours = Math.floor(minutes / 60);
        const days = Math.floor(hours / 24);

        if (days > 0) return `${days}d ${hours % 24}h`;
        if (hours > 0) return `${hours}h ${minutes % 60}m`;
        if (minutes > 0) return `${minutes}m ${seconds % 60}s`;
        return `${seconds}s`;
    }

    /**
     * Format large numbers
     */
    formatNumber(num) {
        if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
        if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
        return num.toString();
    }

    /**
     * Get health check results
     */
    getHealthCheckResults() {
        const results = {};
        for (const [name, check] of this.healthChecks) {
            results[name] = check.lastResult || { healthy: null, message: 'Not yet checked' };
        }
        return results;
    }

    /**
     * Persist metrics to database
     */
    async persistMetrics() {
        if (!this.db) return;

        const query = `
            INSERT INTO monitoring_metrics (timestamp, metrics, time_series)
            VALUES (NOW(), $1, $2)
        `;

        await this.db.query(query, [
            JSON.stringify(this.metrics),
            JSON.stringify(this.timeSeries)
        ]);
    }

    /**
     * Persist alert to database
     */
    async persistAlert(alert) {
        if (!this.db) return;

        const query = `
            INSERT INTO monitoring_alerts (title, severity, data, created_at)
            VALUES ($1, $2, $3, NOW())
        `;

        await this.db.query(query, [
            alert.title,
            alert.severity,
            JSON.stringify(alert.data)
        ]);
    }

    /**
     * Load historical metrics
     */
    async loadHistoricalMetrics(hours = 24) {
        if (!this.db) return null;

        const query = `
            SELECT timestamp, metrics, time_series
            FROM monitoring_metrics
            WHERE timestamp > NOW() - INTERVAL '${hours} hours'
            ORDER BY timestamp ASC
        `;

        const result = await this.db.query(query);
        return result.rows.map(row => ({
            timestamp: row.timestamp,
            metrics: JSON.parse(row.metrics),
            timeSeries: JSON.parse(row.time_series)
        }));
    }

    /**
     * Reset metrics (for testing/development)
     */
    resetMetrics() {
        this.metrics = {
            tasks: {
                total: 0,
                completed: 0,
                failed: 0,
                inProgress: 0,
                averageDuration: 0,
                byType: {}
            },
            api: {
                claudeRequests: 0,
                claudeTokens: 0,
                claudeErrors: 0,
                salesforceRequests: 0,
                salesforceErrors: 0
            },
            system: {
                startTime: Date.now(),
                lastHealthCheck: null,
                memoryUsage: 0,
                cpuUsage: 0,
                activeWorkers: 0
            },
            cost: {
                estimatedClaude: 0,
                estimatedTotal: 0
            }
        };

        for (const key of Object.keys(this.timeSeries)) {
            this.timeSeries[key] = [];
        }

        this.logger.info('[Monitoring] Metrics reset');
    }

    /**
     * Shutdown monitoring
     */
    async shutdown() {
        clearInterval(this.systemMetricsInterval);
        clearInterval(this.healthCheckIntervalId);
        clearInterval(this.timeSeriesInterval);

        if (this.persistInterval) {
            clearInterval(this.persistInterval);
        }

        // Final persist
        if (this.db) {
            await this.persistMetrics();
        }

        this.removeAllListeners();
        this.logger.info('[Monitoring] System shutdown complete');
    }
}

export { MonitoringSystem };
