/**
 * Progress Reporter for Phase 4
 *
 * Real-time progress tracking and reporting for long-running autonomous tasks.
 * Supports multiple output channels with configurable update frequencies.
 */

import EventEmitter from 'events';

class ProgressReporter extends EventEmitter {
    constructor(options = {}) {
        super();

        this.slackBot = options.slackBot;
        this.logger = options.logger || console;

        // Active progress trackers
        this.activeTrackers = new Map();

        // Update configuration
        this.defaultUpdateInterval = options.updateInterval || 30000; // 30 seconds
        this.minUpdateInterval = options.minUpdateInterval || 5000; // 5 seconds
        this.maxUpdateInterval = options.maxUpdateInterval || 300000; // 5 minutes

        // Slack message tracking for updates
        this.slackMessages = new Map();

        // Progress history for trend analysis
        this.progressHistory = new Map();
        this.maxHistoryLength = options.maxHistoryLength || 100;
    }

    /**
     * Start tracking progress for a task
     * @param {string} taskId - Task identifier
     * @param {Object} config - Progress tracking configuration
     */
    startTracking(taskId, config = {}) {
        if (this.activeTrackers.has(taskId)) {
            this.logger.warn(`[ProgressReporter] Tracker already exists for task ${taskId}`);
            return this.activeTrackers.get(taskId);
        }

        const tracker = {
            taskId,
            taskType: config.taskType || 'unknown',
            startTime: Date.now(),
            lastUpdate: Date.now(),
            updateInterval: config.updateInterval || this.defaultUpdateInterval,
            stages: config.stages || [],
            currentStage: 0,
            currentStageProgress: 0,
            overallProgress: 0,
            status: 'running',
            metrics: {
                messagesProcessed: 0,
                tokensUsed: 0,
                filesModified: 0,
                testsRun: 0,
                errors: 0
            },
            output: {
                slack: config.slackConfig || null,
                webhook: config.webhookConfig || null,
                console: config.consoleOutput !== false
            },
            intervalId: null,
            estimatedCompletion: null
        };

        // Initialize stages if provided
        if (tracker.stages.length > 0) {
            tracker.stages = tracker.stages.map((stage, idx) => ({
                name: typeof stage === 'string' ? stage : stage.name,
                weight: stage.weight || 1,
                status: idx === 0 ? 'running' : 'pending',
                progress: 0,
                startTime: idx === 0 ? Date.now() : null,
                endTime: null
            }));
        }

        this.activeTrackers.set(taskId, tracker);
        this.progressHistory.set(taskId, []);

        // Start periodic updates
        tracker.intervalId = setInterval(() => {
            this.sendProgressUpdate(taskId);
        }, tracker.updateInterval);

        // Send initial progress notification
        this.sendInitialNotification(taskId, tracker);

        this.logger.info(`[ProgressReporter] Started tracking task ${taskId}`, {
            stages: tracker.stages.length,
            updateInterval: tracker.updateInterval
        });

        return tracker;
    }

    /**
     * Update progress for a task
     * @param {string} taskId - Task identifier
     * @param {Object} update - Progress update
     */
    updateProgress(taskId, update) {
        const tracker = this.activeTrackers.get(taskId);
        if (!tracker) {
            this.logger.warn(`[ProgressReporter] No tracker found for task ${taskId}`);
            return;
        }

        // Update metrics
        if (update.metrics) {
            Object.assign(tracker.metrics, update.metrics);
        }

        // Update stage progress
        if (typeof update.stageProgress === 'number') {
            tracker.currentStageProgress = Math.min(100, Math.max(0, update.stageProgress));
            if (tracker.stages[tracker.currentStage]) {
                tracker.stages[tracker.currentStage].progress = tracker.currentStageProgress;
            }
        }

        // Advance to next stage
        if (update.advanceStage && tracker.currentStage < tracker.stages.length - 1) {
            this.completeStage(tracker);
            tracker.currentStage++;
            tracker.currentStageProgress = 0;
            if (tracker.stages[tracker.currentStage]) {
                tracker.stages[tracker.currentStage].status = 'running';
                tracker.stages[tracker.currentStage].startTime = Date.now();
            }
        }

        // Calculate overall progress
        tracker.overallProgress = this.calculateOverallProgress(tracker);

        // Update status message
        if (update.statusMessage) {
            tracker.statusMessage = update.statusMessage;
        }

        // Record history
        this.recordProgressHistory(taskId, tracker);

        // Calculate ETA
        tracker.estimatedCompletion = this.calculateETA(taskId, tracker);

        tracker.lastUpdate = Date.now();

        // Emit progress event
        this.emit('progress:updated', {
            taskId,
            progress: tracker.overallProgress,
            stage: tracker.currentStage,
            stageProgress: tracker.currentStageProgress,
            eta: tracker.estimatedCompletion
        });

        return tracker;
    }

    /**
     * Complete the current stage
     */
    completeStage(tracker) {
        if (tracker.stages[tracker.currentStage]) {
            tracker.stages[tracker.currentStage].status = 'completed';
            tracker.stages[tracker.currentStage].progress = 100;
            tracker.stages[tracker.currentStage].endTime = Date.now();
        }
    }

    /**
     * Calculate overall progress based on stages
     */
    calculateOverallProgress(tracker) {
        if (tracker.stages.length === 0) {
            return tracker.currentStageProgress;
        }

        const totalWeight = tracker.stages.reduce((sum, s) => sum + s.weight, 0);
        let completedWeight = 0;

        for (let i = 0; i < tracker.stages.length; i++) {
            const stage = tracker.stages[i];
            if (stage.status === 'completed') {
                completedWeight += stage.weight;
            } else if (stage.status === 'running') {
                completedWeight += (stage.weight * stage.progress / 100);
            }
        }

        return Math.round((completedWeight / totalWeight) * 100);
    }

    /**
     * Record progress history for trend analysis
     */
    recordProgressHistory(taskId, tracker) {
        const history = this.progressHistory.get(taskId) || [];

        history.push({
            timestamp: Date.now(),
            progress: tracker.overallProgress,
            stage: tracker.currentStage,
            stageProgress: tracker.currentStageProgress
        });

        // Trim history if too long
        if (history.length > this.maxHistoryLength) {
            history.shift();
        }

        this.progressHistory.set(taskId, history);
    }

    /**
     * Calculate estimated time of completion
     */
    calculateETA(taskId, tracker) {
        const history = this.progressHistory.get(taskId) || [];

        if (history.length < 2 || tracker.overallProgress <= 0) {
            return null;
        }

        // Use recent progress rate for estimation
        const recentHistory = history.slice(-10);
        const firstPoint = recentHistory[0];
        const lastPoint = recentHistory[recentHistory.length - 1];

        const progressDelta = lastPoint.progress - firstPoint.progress;
        const timeDelta = lastPoint.timestamp - firstPoint.timestamp;

        if (progressDelta <= 0 || timeDelta <= 0) {
            return null;
        }

        const remainingProgress = 100 - tracker.overallProgress;
        const progressRate = progressDelta / timeDelta; // progress per ms
        const remainingTime = remainingProgress / progressRate;

        return new Date(Date.now() + remainingTime);
    }

    /**
     * Send initial notification
     */
    async sendInitialNotification(taskId, tracker) {
        if (tracker.output.slack && this.slackBot) {
            try {
                const message = await this.slackBot.app.client.chat.postMessage({
                    channel: tracker.output.slack.channel,
                    thread_ts: tracker.output.slack.threadTs,
                    ...this.formatSlackProgress(tracker, true)
                });

                this.slackMessages.set(taskId, {
                    channel: message.channel,
                    ts: message.ts
                });
            } catch (error) {
                this.logger.error(`[ProgressReporter] Failed to send Slack notification: ${error.message}`);
            }
        }

        if (tracker.output.console) {
            this.logConsoleProgress(tracker);
        }
    }

    /**
     * Send periodic progress update
     */
    async sendProgressUpdate(taskId) {
        const tracker = this.activeTrackers.get(taskId);
        if (!tracker || tracker.status !== 'running') {
            return;
        }

        // Update Slack message
        if (tracker.output.slack && this.slackBot) {
            const slackMsg = this.slackMessages.get(taskId);
            if (slackMsg) {
                try {
                    await this.slackBot.app.client.chat.update({
                        channel: slackMsg.channel,
                        ts: slackMsg.ts,
                        ...this.formatSlackProgress(tracker)
                    });
                } catch (error) {
                    this.logger.error(`[ProgressReporter] Failed to update Slack: ${error.message}`);
                }
            }
        }

        // Console output
        if (tracker.output.console) {
            this.logConsoleProgress(tracker);
        }

        // Webhook update
        if (tracker.output.webhook) {
            this.sendWebhookUpdate(tracker).catch(err => {
                this.logger.error(`[ProgressReporter] Webhook update failed: ${err.message}`);
            });
        }
    }

    /**
     * Format progress for Slack display
     */
    formatSlackProgress(tracker, isInitial = false) {
        const elapsed = Math.round((Date.now() - tracker.startTime) / 1000);
        const elapsedStr = this.formatDuration(elapsed);

        const progressBar = this.createProgressBar(tracker.overallProgress);
        const etaStr = tracker.estimatedCompletion
            ? `ETA: ${tracker.estimatedCompletion.toLocaleTimeString()}`
            : 'Calculating...';

        const blocks = [
            {
                type: 'header',
                text: {
                    type: 'plain_text',
                    text: isInitial ? `🚀 Task Started: ${tracker.taskType}` : `⏳ Task Progress: ${tracker.taskType}`,
                    emoji: true
                }
            },
            {
                type: 'section',
                text: {
                    type: 'mrkdwn',
                    text: `*Overall Progress:* ${tracker.overallProgress}%\n${progressBar}`
                }
            },
            {
                type: 'section',
                fields: [
                    { type: 'mrkdwn', text: `*Elapsed:*\n${elapsedStr}` },
                    { type: 'mrkdwn', text: `*${etaStr}*` }
                ]
            }
        ];

        // Add stage details
        if (tracker.stages.length > 0) {
            const stageText = tracker.stages.map((stage, idx) => {
                const icon = stage.status === 'completed' ? '✅'
                    : stage.status === 'running' ? '🔄'
                    : '⏸️';
                const progress = stage.status === 'running' ? ` (${stage.progress}%)` : '';
                return `${icon} ${stage.name}${progress}`;
            }).join('\n');

            blocks.push({
                type: 'section',
                text: {
                    type: 'mrkdwn',
                    text: `*Stages:*\n${stageText}`
                }
            });
        }

        // Add metrics
        const metricsText = Object.entries(tracker.metrics)
            .filter(([_, v]) => v > 0)
            .map(([k, v]) => `${this.formatMetricName(k)}: ${v}`)
            .join(' | ');

        if (metricsText) {
            blocks.push({
                type: 'context',
                elements: [{ type: 'mrkdwn', text: metricsText }]
            });
        }

        // Add status message if present
        if (tracker.statusMessage) {
            blocks.push({
                type: 'context',
                elements: [{ type: 'mrkdwn', text: `_${tracker.statusMessage}_` }]
            });
        }

        return { blocks };
    }

    /**
     * Create ASCII progress bar
     */
    createProgressBar(percent, length = 20) {
        const filled = Math.round((percent / 100) * length);
        const empty = length - filled;
        return `\`[${'█'.repeat(filled)}${'░'.repeat(empty)}]\` ${percent}%`;
    }

    /**
     * Format duration in human-readable form
     */
    formatDuration(seconds) {
        if (seconds < 60) return `${seconds}s`;
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        if (mins < 60) return `${mins}m ${secs}s`;
        const hours = Math.floor(mins / 60);
        const remMins = mins % 60;
        return `${hours}h ${remMins}m`;
    }

    /**
     * Format metric name for display
     */
    formatMetricName(name) {
        return name.replace(/([A-Z])/g, ' $1')
            .replace(/^./, str => str.toUpperCase())
            .trim();
    }

    /**
     * Log progress to console
     */
    logConsoleProgress(tracker) {
        const bar = this.createProgressBar(tracker.overallProgress, 30);
        const elapsed = this.formatDuration(Math.round((Date.now() - tracker.startTime) / 1000));

        this.logger.info(`[Progress] ${tracker.taskId} | ${bar} | Elapsed: ${elapsed}`);

        if (tracker.stages.length > 0 && tracker.stages[tracker.currentStage]) {
            const currentStage = tracker.stages[tracker.currentStage];
            this.logger.info(`  Stage ${tracker.currentStage + 1}/${tracker.stages.length}: ${currentStage.name} (${currentStage.progress}%)`);
        }
    }

    /**
     * Send webhook progress update
     */
    async sendWebhookUpdate(tracker) {
        const { webhookUrl, webhookHeaders } = tracker.output.webhook;

        const payload = {
            taskId: tracker.taskId,
            taskType: tracker.taskType,
            progress: tracker.overallProgress,
            currentStage: tracker.currentStage,
            stageProgress: tracker.currentStageProgress,
            stages: tracker.stages,
            metrics: tracker.metrics,
            elapsed: Date.now() - tracker.startTime,
            estimatedCompletion: tracker.estimatedCompletion,
            timestamp: new Date().toISOString()
        };

        const response = await fetch(webhookUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                ...webhookHeaders
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            throw new Error(`Webhook returned ${response.status}`);
        }
    }

    /**
     * Complete tracking for a task
     * @param {string} taskId - Task identifier
     * @param {Object} finalResult - Final result data
     */
    async completeTracking(taskId, finalResult = {}) {
        const tracker = this.activeTrackers.get(taskId);
        if (!tracker) {
            return;
        }

        // Stop periodic updates
        if (tracker.intervalId) {
            clearInterval(tracker.intervalId);
        }

        // Mark all stages complete
        tracker.stages.forEach(stage => {
            if (stage.status === 'running' || stage.status === 'pending') {
                stage.status = 'completed';
                stage.progress = 100;
                stage.endTime = Date.now();
            }
        });

        tracker.overallProgress = 100;
        tracker.status = 'completed';
        tracker.endTime = Date.now();
        tracker.duration = tracker.endTime - tracker.startTime;
        tracker.finalResult = finalResult;

        // Send final update
        await this.sendFinalNotification(taskId, tracker, finalResult);

        this.emit('progress:completed', {
            taskId,
            duration: tracker.duration,
            metrics: tracker.metrics
        });

        // Clean up
        this.activeTrackers.delete(taskId);
        this.slackMessages.delete(taskId);

        this.logger.info(`[ProgressReporter] Completed tracking for ${taskId}`, {
            duration: tracker.duration,
            metrics: tracker.metrics
        });

        return tracker;
    }

    /**
     * Send final completion notification
     */
    async sendFinalNotification(taskId, tracker, result) {
        if (tracker.output.slack && this.slackBot) {
            const slackMsg = this.slackMessages.get(taskId);
            if (slackMsg) {
                try {
                    const success = result.success !== false;
                    const emoji = success ? '✅' : '❌';
                    const duration = this.formatDuration(Math.round(tracker.duration / 1000));

                    const blocks = [
                        {
                            type: 'header',
                            text: {
                                type: 'plain_text',
                                text: `${emoji} Task Completed: ${tracker.taskType}`,
                                emoji: true
                            }
                        },
                        {
                            type: 'section',
                            fields: [
                                { type: 'mrkdwn', text: `*Status:*\n${success ? 'Success' : 'Failed'}` },
                                { type: 'mrkdwn', text: `*Duration:*\n${duration}` }
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

                    // Add metrics
                    const metricsText = Object.entries(tracker.metrics)
                        .filter(([_, v]) => v > 0)
                        .map(([k, v]) => `${this.formatMetricName(k)}: ${v}`)
                        .join(' | ');

                    if (metricsText) {
                        blocks.push({
                            type: 'context',
                            elements: [{ type: 'mrkdwn', text: `📊 ${metricsText}` }]
                        });
                    }

                    await this.slackBot.app.client.chat.update({
                        channel: slackMsg.channel,
                        ts: slackMsg.ts,
                        blocks
                    });
                } catch (error) {
                    this.logger.error(`[ProgressReporter] Final notification failed: ${error.message}`);
                }
            }
        }
    }

    /**
     * Fail tracking for a task
     * @param {string} taskId - Task identifier
     * @param {Error|string} error - Error that caused failure
     */
    async failTracking(taskId, error) {
        const tracker = this.activeTrackers.get(taskId);
        if (!tracker) {
            return;
        }

        // Stop periodic updates
        if (tracker.intervalId) {
            clearInterval(tracker.intervalId);
        }

        tracker.status = 'failed';
        tracker.endTime = Date.now();
        tracker.duration = tracker.endTime - tracker.startTime;
        tracker.error = error instanceof Error ? error.message : error;

        // Send failure notification
        await this.sendFailureNotification(taskId, tracker);

        this.emit('progress:failed', {
            taskId,
            error: tracker.error,
            duration: tracker.duration
        });

        // Clean up
        this.activeTrackers.delete(taskId);
        this.slackMessages.delete(taskId);

        return tracker;
    }

    /**
     * Send failure notification
     */
    async sendFailureNotification(taskId, tracker) {
        if (tracker.output.slack && this.slackBot) {
            const slackMsg = this.slackMessages.get(taskId);
            if (slackMsg) {
                try {
                    await this.slackBot.app.client.chat.update({
                        channel: slackMsg.channel,
                        ts: slackMsg.ts,
                        blocks: [
                            {
                                type: 'header',
                                text: {
                                    type: 'plain_text',
                                    text: `❌ Task Failed: ${tracker.taskType}`,
                                    emoji: true
                                }
                            },
                            {
                                type: 'section',
                                text: {
                                    type: 'mrkdwn',
                                    text: `*Error:*\n\`\`\`${tracker.error}\`\`\``
                                }
                            },
                            {
                                type: 'section',
                                fields: [
                                    { type: 'mrkdwn', text: `*Progress:*\n${tracker.overallProgress}%` },
                                    { type: 'mrkdwn', text: `*Duration:*\n${this.formatDuration(Math.round(tracker.duration / 1000))}` }
                                ]
                            }
                        ]
                    });
                } catch (err) {
                    this.logger.error(`[ProgressReporter] Failure notification failed: ${err.message}`);
                }
            }
        }
    }

    /**
     * Get active trackers
     */
    getActiveTrackers() {
        return Array.from(this.activeTrackers.values());
    }

    /**
     * Get tracker by task ID
     */
    getTracker(taskId) {
        return this.activeTrackers.get(taskId);
    }

    /**
     * Get progress history for a task
     */
    getProgressHistory(taskId) {
        return this.progressHistory.get(taskId) || [];
    }

    /**
     * Shutdown all tracking
     */
    async shutdown() {
        // Complete all active trackers
        for (const [taskId, tracker] of this.activeTrackers) {
            if (tracker.intervalId) {
                clearInterval(tracker.intervalId);
            }
        }

        this.activeTrackers.clear();
        this.slackMessages.clear();
        this.progressHistory.clear();
        this.removeAllListeners();

        this.logger.info('[ProgressReporter] Shutdown complete');
    }
}

export { ProgressReporter };
