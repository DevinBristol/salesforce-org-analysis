// src/services/deployment-scheduler.js - Automated Deployment Scheduling

import fs from 'fs-extra';
import path from 'path';
import schedule from 'node-schedule';

/**
 * DeploymentScheduler - Schedule and manage timed deployments
 *
 * Features:
 * - Schedule deployments for specific times
 * - Define deployment windows
 * - Queue multiple scheduled deployments
 * - Notifications before/after deployment
 * - Automatic retry on failure
 */
export class DeploymentScheduler {
    constructor(deploymentPipeline, logger, notificationCallback = null) {
        this.deploymentPipeline = deploymentPipeline;
        this.logger = logger;
        this.notificationCallback = notificationCallback;

        this.scheduledJobs = new Map();
        this.scheduledDeployments = [];
        this.storageFile = './deployments/scheduled.json';

        // Deployment windows configuration
        this.windows = {
            development: {
                enabled: true,
                days: [1, 2, 3, 4, 5], // Mon-Fri
                hours: { start: 6, end: 22 }, // 6am - 10pm
                timezone: 'UTC'
            },
            uat: {
                enabled: true,
                days: [1, 2, 3, 4, 5],
                hours: { start: 9, end: 18 }, // 9am - 6pm
                timezone: 'UTC'
            },
            production: {
                enabled: true,
                days: [0], // Sunday only
                hours: { start: 2, end: 6 }, // 2am - 6am
                timezone: 'UTC'
            }
        };

        // Load persisted scheduled deployments
        this.loadScheduledDeployments();
    }

    /**
     * Schedule a deployment for a specific time
     * @param {Object} config - Deployment configuration
     * @returns {Object} Scheduled deployment info
     */
    async scheduleDeployment(config) {
        const {
            artifacts,
            targetOrg = 'Devin1',
            scheduledTime,
            options = {},
            userId,
            description = '',
            retryOnFailure = true,
            maxRetries = 3,
            notifyBefore = true,
            notifyAfter = true
        } = config;

        const scheduledId = `scheduled-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
        const scheduledDate = new Date(scheduledTime);

        // Validate scheduled time
        if (scheduledDate <= new Date()) {
            throw new Error('Scheduled time must be in the future');
        }

        // Check if within deployment window
        const windowCheck = this.isWithinWindow(scheduledDate, targetOrg);
        if (!windowCheck.allowed && !options.force) {
            throw new Error(`Scheduled time is outside deployment window for ${targetOrg}. ${windowCheck.reason}`);
        }

        // Create scheduled deployment record
        const scheduledDeployment = {
            scheduledId,
            artifacts,
            targetOrg,
            scheduledTime: scheduledDate.toISOString(),
            options,
            userId,
            description,
            retryOnFailure,
            maxRetries,
            retryCount: 0,
            notifyBefore,
            notifyAfter,
            status: 'scheduled',
            createdAt: new Date().toISOString(),
            result: null
        };

        // Save to scheduled deployments
        this.scheduledDeployments.push(scheduledDeployment);
        await this.saveScheduledDeployments();

        // Schedule the job
        const job = schedule.scheduleJob(scheduledDate, async () => {
            await this.executeScheduledDeployment(scheduledId);
        });

        this.scheduledJobs.set(scheduledId, job);

        // Schedule pre-deployment notification (15 minutes before)
        if (notifyBefore && this.notificationCallback) {
            const notifyTime = new Date(scheduledDate.getTime() - 15 * 60000);
            if (notifyTime > new Date()) {
                schedule.scheduleJob(notifyTime, async () => {
                    await this.notificationCallback({
                        type: 'deployment_reminder',
                        scheduledId,
                        message: `Reminder: Deployment ${scheduledId} will start in 15 minutes.`,
                        targetOrg,
                        userId
                    });
                });
            }
        }

        this.logger.info(`Deployment scheduled: ${scheduledId} for ${scheduledDate.toISOString()}`);

        return {
            scheduledId,
            scheduledTime: scheduledDate.toISOString(),
            targetOrg,
            status: 'scheduled',
            withinWindow: windowCheck.allowed
        };
    }

    /**
     * Execute a scheduled deployment
     */
    async executeScheduledDeployment(scheduledId) {
        const deployment = this.scheduledDeployments.find(d => d.scheduledId === scheduledId);

        if (!deployment) {
            this.logger.error(`Scheduled deployment not found: ${scheduledId}`);
            return;
        }

        if (deployment.status === 'cancelled') {
            this.logger.info(`Scheduled deployment ${scheduledId} was cancelled`);
            return;
        }

        this.logger.info(`Executing scheduled deployment: ${scheduledId}`);
        deployment.status = 'executing';
        await this.saveScheduledDeployments();

        try {
            // Execute deployment
            const result = await this.deploymentPipeline.deployToSandbox(
                deployment.artifacts,
                deployment.targetOrg,
                deployment.options
            );

            deployment.result = result;
            deployment.status = result.deployed ? 'completed' : 'failed';
            deployment.completedAt = new Date().toISOString();

            // Send post-deployment notification
            if (deployment.notifyAfter && this.notificationCallback) {
                await this.notificationCallback({
                    type: 'deployment_complete',
                    scheduledId,
                    success: result.deployed,
                    message: result.deployed
                        ? `Deployment ${scheduledId} completed successfully.`
                        : `Deployment ${scheduledId} failed: ${result.error}`,
                    targetOrg: deployment.targetOrg,
                    userId: deployment.userId,
                    result
                });
            }

            // Handle retry on failure
            if (!result.deployed && deployment.retryOnFailure && deployment.retryCount < deployment.maxRetries) {
                deployment.retryCount++;
                const retryTime = new Date(Date.now() + 5 * 60000); // Retry in 5 minutes

                this.logger.info(`Scheduling retry ${deployment.retryCount}/${deployment.maxRetries} for ${scheduledId}`);

                const job = schedule.scheduleJob(retryTime, async () => {
                    await this.executeScheduledDeployment(scheduledId);
                });

                this.scheduledJobs.set(`${scheduledId}-retry-${deployment.retryCount}`, job);
                deployment.status = 'retry_scheduled';
            }

            await this.saveScheduledDeployments();

            return result;

        } catch (error) {
            this.logger.error(`Scheduled deployment ${scheduledId} error:`, error);
            deployment.status = 'error';
            deployment.result = { error: error.message };
            await this.saveScheduledDeployments();

            if (this.notificationCallback) {
                await this.notificationCallback({
                    type: 'deployment_error',
                    scheduledId,
                    message: `Deployment ${scheduledId} encountered an error: ${error.message}`,
                    userId: deployment.userId
                });
            }
        }
    }

    /**
     * Cancel a scheduled deployment
     */
    async cancelScheduledDeployment(scheduledId) {
        const deployment = this.scheduledDeployments.find(d => d.scheduledId === scheduledId);

        if (!deployment) {
            throw new Error(`Scheduled deployment not found: ${scheduledId}`);
        }

        if (deployment.status !== 'scheduled') {
            throw new Error(`Cannot cancel deployment in status: ${deployment.status}`);
        }

        // Cancel the job
        const job = this.scheduledJobs.get(scheduledId);
        if (job) {
            job.cancel();
            this.scheduledJobs.delete(scheduledId);
        }

        deployment.status = 'cancelled';
        deployment.cancelledAt = new Date().toISOString();
        await this.saveScheduledDeployments();

        this.logger.info(`Scheduled deployment cancelled: ${scheduledId}`);

        return { success: true, scheduledId };
    }

    /**
     * Get all scheduled deployments
     */
    getScheduledDeployments(filter = {}) {
        let deployments = [...this.scheduledDeployments];

        if (filter.status) {
            deployments = deployments.filter(d => d.status === filter.status);
        }

        if (filter.targetOrg) {
            deployments = deployments.filter(d => d.targetOrg === filter.targetOrg);
        }

        if (filter.userId) {
            deployments = deployments.filter(d => d.userId === filter.userId);
        }

        return deployments.sort((a, b) =>
            new Date(a.scheduledTime) - new Date(b.scheduledTime)
        );
    }

    /**
     * Check if a time is within the deployment window for an org
     */
    isWithinWindow(date, targetOrg) {
        // Determine window based on org type
        let windowKey = 'development';
        if (targetOrg.toLowerCase().includes('uat')) {
            windowKey = 'uat';
        } else if (targetOrg.toLowerCase().includes('prod')) {
            windowKey = 'production';
        }

        const window = this.windows[windowKey];

        if (!window.enabled) {
            return { allowed: true, reason: 'Windows disabled' };
        }

        const day = date.getUTCDay();
        const hour = date.getUTCHours();

        if (!window.days.includes(day)) {
            return {
                allowed: false,
                reason: `Day ${day} is not allowed. Allowed days: ${window.days.join(', ')}`
            };
        }

        if (hour < window.hours.start || hour >= window.hours.end) {
            return {
                allowed: false,
                reason: `Hour ${hour} is outside window ${window.hours.start}-${window.hours.end}`
            };
        }

        return { allowed: true, reason: 'Within window' };
    }

    /**
     * Get next available deployment window
     */
    getNextWindow(targetOrg) {
        let windowKey = 'development';
        if (targetOrg?.toLowerCase().includes('uat')) {
            windowKey = 'uat';
        } else if (targetOrg?.toLowerCase().includes('prod')) {
            windowKey = 'production';
        }

        const window = this.windows[windowKey];
        const now = new Date();

        // Find next allowed day and hour
        for (let daysAhead = 0; daysAhead < 7; daysAhead++) {
            const checkDate = new Date(now.getTime() + daysAhead * 24 * 60 * 60 * 1000);
            const day = checkDate.getUTCDay();

            if (window.days.includes(day)) {
                // Check if we're still within today's window
                if (daysAhead === 0) {
                    const currentHour = now.getUTCHours();
                    if (currentHour >= window.hours.start && currentHour < window.hours.end) {
                        return {
                            available: true,
                            nextWindow: now,
                            windowEnd: new Date(now.setUTCHours(window.hours.end, 0, 0, 0))
                        };
                    }
                }

                // Return start of next available window
                const nextWindow = new Date(checkDate);
                nextWindow.setUTCHours(window.hours.start, 0, 0, 0);

                if (nextWindow > now) {
                    return {
                        available: false,
                        nextWindow,
                        windowEnd: new Date(nextWindow.getTime()).setUTCHours(window.hours.end, 0, 0, 0)
                    };
                }
            }
        }

        return { available: false, nextWindow: null, reason: 'No window found in next 7 days' };
    }

    /**
     * Configure deployment window
     */
    setDeploymentWindow(orgType, config) {
        if (!this.windows[orgType]) {
            this.windows[orgType] = {};
        }

        this.windows[orgType] = {
            ...this.windows[orgType],
            ...config
        };

        this.logger.info(`Updated ${orgType} deployment window:`, this.windows[orgType]);
    }

    /**
     * Save scheduled deployments to file
     */
    async saveScheduledDeployments() {
        await fs.ensureDir(path.dirname(this.storageFile));
        await fs.writeJson(this.storageFile, this.scheduledDeployments, { spaces: 2 });
    }

    /**
     * Load scheduled deployments from file
     */
    async loadScheduledDeployments() {
        try {
            if (await fs.pathExists(this.storageFile)) {
                this.scheduledDeployments = await fs.readJson(this.storageFile);

                // Re-schedule any pending deployments
                for (const deployment of this.scheduledDeployments) {
                    if (deployment.status === 'scheduled') {
                        const scheduledDate = new Date(deployment.scheduledTime);

                        if (scheduledDate > new Date()) {
                            const job = schedule.scheduleJob(scheduledDate, async () => {
                                await this.executeScheduledDeployment(deployment.scheduledId);
                            });
                            this.scheduledJobs.set(deployment.scheduledId, job);
                            this.logger.info(`Restored scheduled deployment: ${deployment.scheduledId}`);
                        } else {
                            // Mark as missed if past due
                            deployment.status = 'missed';
                        }
                    }
                }

                await this.saveScheduledDeployments();
            }
        } catch (error) {
            this.logger.error('Failed to load scheduled deployments:', error);
            this.scheduledDeployments = [];
        }
    }

    /**
     * Clean up old completed deployments
     */
    async cleanupOldDeployments(olderThanDays = 30) {
        const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000);

        const before = this.scheduledDeployments.length;
        this.scheduledDeployments = this.scheduledDeployments.filter(d => {
            const completedAt = d.completedAt ? new Date(d.completedAt) : null;
            return !completedAt || completedAt > cutoff;
        });

        const removed = before - this.scheduledDeployments.length;
        if (removed > 0) {
            await this.saveScheduledDeployments();
            this.logger.info(`Cleaned up ${removed} old scheduled deployments`);
        }

        return { removed };
    }

    /**
     * Get deployment statistics
     */
    getStatistics() {
        const stats = {
            total: this.scheduledDeployments.length,
            byStatus: {},
            upcomingCount: 0,
            completedToday: 0,
            failedToday: 0
        };

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        for (const d of this.scheduledDeployments) {
            // Count by status
            stats.byStatus[d.status] = (stats.byStatus[d.status] || 0) + 1;

            // Count upcoming
            if (d.status === 'scheduled') {
                stats.upcomingCount++;
            }

            // Count today's completions/failures
            if (d.completedAt) {
                const completedDate = new Date(d.completedAt);
                completedDate.setHours(0, 0, 0, 0);
                if (completedDate.getTime() === today.getTime()) {
                    if (d.status === 'completed') {
                        stats.completedToday++;
                    } else if (d.status === 'failed') {
                        stats.failedToday++;
                    }
                }
            }
        }

        return stats;
    }
}
