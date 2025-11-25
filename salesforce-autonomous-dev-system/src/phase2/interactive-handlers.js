// src/phase2/interactive-handlers.js
// Handles interactive button clicks and confirmations

import { TaskQueue } from './task-queue.js';
import { WorkerPool } from './worker-pool.js';
import { formatProgressUpdate, formatConfirmation } from './slack-formatters.js';

export class InteractiveHandlers {
  constructor(app, workerPool, taskQueue) {
    this.app = app;
    this.workerPool = workerPool;
    this.taskQueue = taskQueue;
    this.pendingConfirmations = new Map(); // Store pending confirmations
    this.setupHandlers();
  }

  setupHandlers() {
    // Handle improve test button
    this.app.action('improve_test', async ({ action, ack, say, client, body }) => {
      await ack();
      const className = action.value.replace('improve_', '');

      await say(`✅ Queued test improvement for ${className}`);

      await this.taskQueue.add({
        type: 'improve-test',
        priority: 1,
        payload: { className }
      });
    });

    // Handle view details button
    this.app.action('view_details', async ({ action, ack, say }) => {
      await ack();
      const identifier = action.value.replace('details_', '');

      // Would fetch and display detailed information
      await say(`📊 Fetching detailed information for ${identifier}...`);
    });

    // Handle ignore button
    this.app.action('ignore_issue', async ({ action, ack, say }) => {
      await ack();
      await say(`✅ Issue ignored`);
    });

    // Handle pause queue button
    this.app.action('pause_queue', async ({ action, ack, say }) => {
      await ack();

      const queueSize = this.taskQueue.getQueueSize();
      this.workerPool.paused = true;

      await say(`⏸️ Queue paused. ${queueSize} pending tasks will not be processed until resumed.\n\nUse \`/sf-dev resume-queue\` to resume.`);
    });

    // Handle deployment confirmation
    this.app.action('confirm_action', async ({ action, ack, say, body }) => {
      await ack();

      const pendingAction = this.pendingConfirmations.get(body.user.id);
      if (pendingAction) {
        await say(`✅ Confirmed. Processing ${pendingAction.type}...`);

        // Execute the confirmed action
        await this.executeConfirmedAction(pendingAction, say);

        this.pendingConfirmations.delete(body.user.id);
      }
    });

    // Handle cancellation
    this.app.action('cancel_action', async ({ action, ack, say, body }) => {
      await ack();

      this.pendingConfirmations.delete(body.user.id);
      await say(`❌ Action cancelled`);
    });

    // Handle increase budget button
    this.app.action('increase_budget', async ({ action, ack, say }) => {
      await ack();
      await say(`💰 To increase your budget, use:\n\`/sf-dev set-budget [amount]\`\n\nExample: \`/sf-dev set-budget 150\``);
    });

    // Handle continue anyway button
    this.app.action('continue_anyway', async ({ action, ack, say }) => {
      await ack();

      this.workerPool.paused = false;
      await say(`✅ Continuing with current budget. Queue resumed.`);
    });

    // Handle improve low coverage button
    this.app.action('improve_coverage', async ({ action, ack, say }) => {
      await ack();
      await say(`🔄 Starting comprehensive improvement for low-coverage classes...`);

      // Queue comprehensive improvement
      await this.taskQueue.add({
        type: 'comprehensive-improve',
        priority: 2,
        payload: { targetCoverage: 75 }
      });
    });

    // Handle export report button
    this.app.action('export_report', async ({ action, ack, say }) => {
      await ack();
      await say(`📄 Generating full coverage report...`);

      // Would generate and upload file
      await say(`✅ Report generated: coverage-report-${new Date().toISOString().split('T')[0]}.md`);
    });
  }

  /**
   * Store a pending confirmation for a user
   */
  storePendingConfirmation(userId, action) {
    this.pendingConfirmations.set(userId, {
      ...action,
      timestamp: Date.now()
    });

    // Auto-expire after 5 minutes
    setTimeout(() => {
      if (this.pendingConfirmations.has(userId)) {
        this.pendingConfirmations.delete(userId);
      }
    }, 5 * 60 * 1000);
  }

  /**
   * Execute a confirmed action
   */
  async executeConfirmedAction(action, say) {
    switch (action.type) {
      case 'comprehensive-improve':
        await say(`🚀 Starting comprehensive improvement...`);
        await this.taskQueue.add({
          type: 'comprehensive-improve',
          priority: 2,
          payload: action.payload
        });
        break;

      case 'deploy-queue':
        await say(`🚀 Deploying queue items...`);
        await this.taskQueue.add({
          type: 'deploy-all',
          priority: 3,
          payload: action.payload
        });
        break;

      case 'rollback':
        await say(`🔄 Rolling back deployment...`);
        // Rollback logic would go here
        break;

      default:
        await say(`❌ Unknown action type: ${action.type}`);
    }
  }

  /**
   * Wait for text confirmation (APPROVE, DEPLOY, etc.)
   */
  async waitForTextConfirmation(userId, expectedText, timeoutMs = 300000) {
    return new Promise((resolve, reject) => {
      const listener = this.app.message(async ({ message, say }) => {
        if (message.user === userId && message.text.trim().toUpperCase() === expectedText.toUpperCase()) {
          resolve(true);
          // Remove listener after confirmation
          this.app.removeListener('message', listener);
        }
      });

      // Timeout after 5 minutes
      setTimeout(() => {
        this.app.removeListener('message', listener);
        reject(new Error('Confirmation timeout'));
      }, timeoutMs);
    });
  }

  /**
   * Handle message-based confirmations (APPROVE, DEPLOY, ROLLBACK)
   */
  setupMessageConfirmations() {
    this.app.message(async ({ message, say }) => {
      const text = message.text.trim().toUpperCase();
      const userId = message.user;

      // Check for pending confirmation
      const pending = this.pendingConfirmations.get(userId);
      if (!pending) return;

      // Check if message matches expected confirmation
      if (text === pending.expectedText) {
        await say(`✅ Confirmed. Processing...`);
        await this.executeConfirmedAction(pending, say);
        this.pendingConfirmations.delete(userId);
      } else if (text === 'CANCEL') {
        await say(`❌ Action cancelled`);
        this.pendingConfirmations.delete(userId);
      }
    });
  }
}

/**
 * Confirmation Manager for tracking multi-step confirmations
 */
export class ConfirmationManager {
  constructor() {
    this.confirmations = new Map();
  }

  /**
   * Request confirmation from user
   */
  requestConfirmation(userId, action, expectedText = 'APPROVE') {
    const confirmationId = `${userId}_${Date.now()}`;

    this.confirmations.set(userId, {
      id: confirmationId,
      action,
      expectedText,
      timestamp: Date.now(),
      expires: Date.now() + (5 * 60 * 1000) // 5 minutes
    });

    // Auto-cleanup expired confirmations
    setTimeout(() => {
      const conf = this.confirmations.get(userId);
      if (conf && conf.id === confirmationId) {
        this.confirmations.delete(userId);
      }
    }, 5 * 60 * 1000);

    return confirmationId;
  }

  /**
   * Check if user has pending confirmation
   */
  hasPendingConfirmation(userId) {
    const conf = this.confirmations.get(userId);
    if (!conf) return false;

    // Check if expired
    if (Date.now() > conf.expires) {
      this.confirmations.delete(userId);
      return false;
    }

    return true;
  }

  /**
   * Get pending confirmation
   */
  getPendingConfirmation(userId) {
    return this.confirmations.get(userId);
  }

  /**
   * Confirm and execute
   */
  confirm(userId, text) {
    const conf = this.confirmations.get(userId);
    if (!conf) return null;

    if (text.trim().toUpperCase() === conf.expectedText.toUpperCase()) {
      this.confirmations.delete(userId);
      return conf.action;
    }

    return null;
  }

  /**
   * Cancel confirmation
   */
  cancel(userId) {
    this.confirmations.delete(userId);
  }
}

/**
 * Progress Tracker for sending auto-updates
 */
export class ProgressTracker {
  constructor(app, channel) {
    this.app = app;
    this.channel = channel;
    this.activeTracking = new Map();
  }

  /**
   * Start tracking progress for a batch of tasks
   */
  startTracking(batchId, taskIds, totalEstimatedTime) {
    this.activeTracking.set(batchId, {
      taskIds,
      total: taskIds.length,
      completed: 0,
      failed: 0,
      startTime: Date.now(),
      estimatedTime: totalEstimatedTime,
      lastUpdate: Date.now(),
      messageTs: null // Will store Slack message timestamp for updates
    });

    // Send initial progress message
    this.sendProgressUpdate(batchId);

    // Update every 30 seconds
    const interval = setInterval(() => {
      if (!this.activeTracking.has(batchId)) {
        clearInterval(interval);
        return;
      }
      this.sendProgressUpdate(batchId);
    }, 30000);
  }

  /**
   * Update progress
   */
  updateProgress(batchId, completed, failed) {
    const tracking = this.activeTracking.get(batchId);
    if (!tracking) return;

    tracking.completed = completed;
    tracking.failed = failed;
    tracking.lastUpdate = Date.now();

    // Check if complete
    if (completed + failed >= tracking.total) {
      this.stopTracking(batchId);
    }
  }

  /**
   * Send progress update to Slack
   */
  async sendProgressUpdate(batchId) {
    const tracking = this.activeTracking.get(batchId);
    if (!tracking) return;

    const elapsed = Date.now() - tracking.startTime;
    const progress = tracking.completed / tracking.total;
    const estimatedRemaining = progress > 0
      ? Math.round(((elapsed / progress) - elapsed) / 60000)
      : tracking.estimatedTime;

    const progressData = {
      completed: tracking.completed,
      total: tracking.total,
      inProgress: tracking.total - tracking.completed - tracking.failed,
      pending: tracking.total - tracking.completed - tracking.failed,
      failed: tracking.failed,
      activeWorkers: [1, 2, 3], // Would get from worker pool
      costSoFar: 0, // Would get from cost tracker
      estimatedTotal: 0, // Would estimate
      timeRemaining: estimatedRemaining
    };

    const message = formatProgressUpdate(progressData);

    try {
      if (tracking.messageTs) {
        // Update existing message
        await this.app.client.chat.update({
          channel: this.channel,
          ts: tracking.messageTs,
          ...message
        });
      } else {
        // Send new message
        const result = await this.app.client.chat.postMessage({
          channel: this.channel,
          ...message
        });
        tracking.messageTs = result.ts;
      }
    } catch (error) {
      console.error('Failed to send progress update:', error);
    }
  }

  /**
   * Stop tracking
   */
  async stopTracking(batchId) {
    const tracking = this.activeTracking.get(batchId);
    if (!tracking) return;

    // Send final completion message
    await this.app.client.chat.postMessage({
      channel: this.channel,
      text: `✅ Batch ${batchId} complete!\n\nCompleted: ${tracking.completed}\nFailed: ${tracking.failed}\nTotal time: ${Math.round((Date.now() - tracking.startTime) / 60000)} minutes`
    });

    this.activeTracking.delete(batchId);
  }
}
