/**
 * Enhanced Worker Pool for Phase 4
 *
 * Extends the Phase 2 worker pool with:
 * - Result callback integration
 * - Progress reporting
 * - Monitoring integration
 * - Better error handling and recovery
 */

import { Worker } from 'worker_threads';
import EventEmitter from 'events';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

class EnhancedWorkerPool extends EventEmitter {
    constructor(options = {}) {
        super();

        this.workerCount = options.workerCount || 3;
        this.workerScript = options.workerScript || path.join(__dirname, '../phase2/worker.js');
        this.workerType = options.workerType || 'salesforce';

        // Phase 4 integrations
        this.taskQueue = options.taskQueue;
        this.resultCallback = options.resultCallback;
        this.progressReporter = options.progressReporter;
        this.monitoring = options.monitoring;
        this.logger = options.logger || console;

        // Worker tracking
        this.workers = new Map();
        this.activeJobs = new Map();
        this.jobCallbacks = new Map();

        // Statistics
        this.stats = {
            tasksCompleted: 0,
            tasksFailed: 0,
            totalDuration: 0,
            restarts: 0
        };

        // Auto-restart configuration
        this.autoRestart = options.autoRestart !== false;
        this.maxRestarts = options.maxRestarts || 5;
        this.restartDelay = options.restartDelay || 5000;
    }

    /**
     * Start the worker pool
     */
    async start() {
        this.logger.info(`[WorkerPool] Starting ${this.workerCount} workers...`);

        for (let i = 0; i < this.workerCount; i++) {
            await this.startWorker(i + 1);
        }

        this.logger.info('[WorkerPool] All workers started');

        // Start polling for tasks
        this.pollInterval = setInterval(() => {
            this.assignPendingTasks();
        }, 1000);

        return this;
    }

    /**
     * Start a single worker
     */
    async startWorker(workerId) {
        const worker = new Worker(this.workerScript, {
            workerData: {
                workerId,
                workerType: this.workerType,
                dbPath: process.env.DB_PATH
            }
        });

        const workerInfo = {
            id: workerId,
            worker,
            status: 'idle',
            currentTask: null,
            startTime: Date.now(),
            restarts: 0
        };

        // Set up event handlers
        worker.on('message', (msg) => this.handleWorkerMessage(workerId, msg));
        worker.on('error', (err) => this.handleWorkerError(workerId, err));
        worker.on('exit', (code) => this.handleWorkerExit(workerId, code));

        this.workers.set(workerId, workerInfo);
        this.logger.info(`[WorkerPool] Worker ${workerId} started`);

        return workerInfo;
    }

    /**
     * Handle messages from workers
     */
    handleWorkerMessage(workerId, msg) {
        const workerInfo = this.workers.get(workerId);
        if (!workerInfo) return;

        switch (msg.type) {
            case 'TASK_COMPLETE':
                this.handleTaskComplete(workerId, msg);
                break;

            case 'TASK_FAILED':
                this.handleTaskFailed(workerId, msg);
                break;

            case 'PROGRESS':
                this.handleProgress(workerId, msg);
                break;

            case 'COST_UPDATE':
                if (this.monitoring) {
                    this.monitoring.trackApiUsage('claude', {
                        tokens: msg.usage?.totalTokens || 0,
                        model: msg.usage?.model
                    });
                }
                this.emit('cost:update', msg);
                break;

            case 'LOG':
                this.logger.info(`[Worker ${workerId}] ${msg.message}`);
                break;

            default:
                this.logger.debug(`[WorkerPool] Unknown message type: ${msg.type}`);
        }
    }

    /**
     * Handle task completion
     */
    async handleTaskComplete(workerId, msg) {
        const workerInfo = this.workers.get(workerId);
        const taskId = workerInfo?.currentTask?.id;

        if (!taskId) {
            this.logger.warn(`[WorkerPool] Task complete but no current task for worker ${workerId}`);
            return;
        }

        const duration = Date.now() - workerInfo.currentTask.startTime;

        // Update statistics
        this.stats.tasksCompleted++;
        this.stats.totalDuration += duration;

        // Update monitoring
        if (this.monitoring) {
            this.monitoring.trackTask('completed', {
                type: workerInfo.currentTask.type,
                duration
            });
        }

        // Mark task complete in queue
        if (this.taskQueue) {
            await this.taskQueue.markComplete(taskId, msg.result);
        }

        // Deliver result via callback
        if (this.resultCallback) {
            const callback = this.jobCallbacks.get(taskId);
            if (callback) {
                await this.resultCallback.deliverResult(taskId, {
                    success: true,
                    duration,
                    summary: msg.result?.summary,
                    output: msg.result?.output,
                    artifacts: msg.result?.artifacts
                });
                this.jobCallbacks.delete(taskId);
            }
        }

        // Complete progress tracking
        if (this.progressReporter) {
            await this.progressReporter.completeTracking(taskId, {
                success: true,
                summary: msg.result?.summary
            });
        }

        // Clean up and make worker available
        this.activeJobs.delete(workerInfo.worker.threadId);
        workerInfo.status = 'idle';
        workerInfo.currentTask = null;

        this.emit('task:complete', { taskId, result: msg.result, duration });

        // Check for deployment
        if (msg.result?.readyToDeploy) {
            await this.queueDeployment(msg.result);
        }
    }

    /**
     * Handle task failure
     */
    async handleTaskFailed(workerId, msg) {
        const workerInfo = this.workers.get(workerId);
        const taskId = workerInfo?.currentTask?.id;

        if (!taskId) return;

        const duration = Date.now() - workerInfo.currentTask.startTime;

        // Update statistics
        this.stats.tasksFailed++;

        // Update monitoring
        if (this.monitoring) {
            this.monitoring.trackTask('failed', {
                type: workerInfo.currentTask.type,
                error: msg.error
            });
        }

        // Mark task failed in queue
        if (this.taskQueue) {
            await this.taskQueue.markFailed(taskId, msg.error);
        }

        // Deliver failure via callback
        if (this.resultCallback) {
            const callback = this.jobCallbacks.get(taskId);
            if (callback) {
                await this.resultCallback.deliverResult(taskId, {
                    success: false,
                    duration,
                    error: msg.error
                });
                this.jobCallbacks.delete(taskId);
            }
        }

        // Fail progress tracking
        if (this.progressReporter) {
            await this.progressReporter.failTracking(taskId, msg.error);
        }

        // Clean up
        this.activeJobs.delete(workerInfo.worker.threadId);
        workerInfo.status = 'idle';
        workerInfo.currentTask = null;

        this.emit('task:failed', { taskId, error: msg.error, duration });
    }

    /**
     * Handle progress updates
     */
    handleProgress(workerId, msg) {
        const workerInfo = this.workers.get(workerId);
        const taskId = workerInfo?.currentTask?.id;

        if (!taskId) return;

        // Update progress reporter
        if (this.progressReporter) {
            this.progressReporter.updateProgress(taskId, {
                stageProgress: msg.progress,
                advanceStage: msg.advanceStage,
                statusMessage: msg.message,
                metrics: msg.metrics
            });
        }

        this.emit('progress', { taskId, ...msg });
    }

    /**
     * Handle worker errors
     */
    handleWorkerError(workerId, error) {
        this.logger.error(`[WorkerPool] Worker ${workerId} error:`, error);

        const workerInfo = this.workers.get(workerId);
        if (workerInfo?.currentTask) {
            this.handleTaskFailed(workerId, { error: error.message });
        }

        this.emit('error', { workerId, error });

        // Attempt restart
        if (this.autoRestart) {
            this.restartWorker(workerId);
        }
    }

    /**
     * Handle worker exit
     */
    handleWorkerExit(workerId, code) {
        this.logger.warn(`[WorkerPool] Worker ${workerId} exited with code ${code}`);

        const workerInfo = this.workers.get(workerId);
        if (workerInfo?.currentTask) {
            this.handleTaskFailed(workerId, { error: `Worker exited with code ${code}` });
        }

        // Attempt restart
        if (this.autoRestart && code !== 0) {
            this.restartWorker(workerId);
        }
    }

    /**
     * Restart a worker
     */
    async restartWorker(workerId) {
        const workerInfo = this.workers.get(workerId);

        if (workerInfo && workerInfo.restarts >= this.maxRestarts) {
            this.logger.error(`[WorkerPool] Worker ${workerId} exceeded max restarts`);
            this.emit('worker:maxRestarts', { workerId });
            return;
        }

        this.logger.info(`[WorkerPool] Restarting worker ${workerId}...`);
        this.stats.restarts++;

        // Clean up old worker
        this.workers.delete(workerId);

        // Wait before restart
        await new Promise(resolve => setTimeout(resolve, this.restartDelay));

        // Start new worker
        const newWorkerInfo = await this.startWorker(workerId);
        newWorkerInfo.restarts = (workerInfo?.restarts || 0) + 1;
    }

    /**
     * Assign pending tasks to idle workers
     */
    async assignPendingTasks() {
        if (!this.taskQueue) return;

        for (const [workerId, workerInfo] of this.workers) {
            if (workerInfo.status !== 'idle') continue;

            const task = await this.taskQueue.getNext(this.workerType);
            if (!task) break;

            await this.assignTask(workerId, task);
        }
    }

    /**
     * Assign a task to a worker
     */
    async assignTask(workerId, task) {
        const workerInfo = this.workers.get(workerId);
        if (!workerInfo || workerInfo.status !== 'idle') {
            throw new Error(`Worker ${workerId} not available`);
        }

        workerInfo.status = 'busy';
        workerInfo.currentTask = {
            ...task,
            startTime: Date.now()
        };

        this.activeJobs.set(workerInfo.worker.threadId, task);

        // Store callback configuration
        if (task.callback) {
            this.jobCallbacks.set(task.id, task.callback);

            // Register with result callback system
            if (this.resultCallback) {
                this.resultCallback.registerCallback(task.id, task.callback);
            }
        }

        // Start progress tracking
        if (this.progressReporter) {
            this.progressReporter.startTracking(task.id, {
                taskType: task.type,
                stages: task.stages,
                slackConfig: task.callback?.slackConfig
            });
        }

        // Track task start
        if (this.monitoring) {
            this.monitoring.trackTask('started', { type: task.type });
        }

        // Send task to worker
        workerInfo.worker.postMessage({
            type: 'EXECUTE_TASK',
            task
        });

        this.logger.info(`[WorkerPool] Assigned task ${task.id} to worker ${workerId}`);

        this.emit('task:assigned', { taskId: task.id, workerId });
    }

    /**
     * Submit a task directly to the pool
     */
    async submitTask(task) {
        if (this.taskQueue) {
            return await this.taskQueue.add(task);
        }

        // Find an idle worker
        for (const [workerId, workerInfo] of this.workers) {
            if (workerInfo.status === 'idle') {
                await this.assignTask(workerId, task);
                return task.id;
            }
        }

        throw new Error('No workers available');
    }

    /**
     * Queue a deployment task
     */
    async queueDeployment(result) {
        if (this.taskQueue) {
            await this.taskQueue.addDeployment(result);
        }
        this.emit('deployment:queued', result);
    }

    /**
     * Get pool statistics
     */
    getStats() {
        const idle = Array.from(this.workers.values()).filter(w => w.status === 'idle').length;
        const busy = this.workers.size - idle;

        return {
            totalWorkers: this.workers.size,
            idleWorkers: idle,
            busyWorkers: busy,
            activeJobs: this.activeJobs.size,
            queueSize: this.taskQueue?.getQueueSize() || 0,
            tasksCompleted: this.stats.tasksCompleted,
            tasksFailed: this.stats.tasksFailed,
            averageDuration: this.stats.tasksCompleted > 0
                ? Math.round(this.stats.totalDuration / this.stats.tasksCompleted)
                : 0,
            restarts: this.stats.restarts
        };
    }

    /**
     * Get worker details
     */
    getWorkerDetails() {
        return Array.from(this.workers.entries()).map(([id, info]) => ({
            id,
            status: info.status,
            currentTask: info.currentTask?.id || null,
            taskType: info.currentTask?.type || null,
            uptime: Date.now() - info.startTime,
            restarts: info.restarts
        }));
    }

    /**
     * Scale the worker pool
     */
    async scale(newCount) {
        if (newCount === this.workers.size) return;

        if (newCount > this.workers.size) {
            // Scale up
            for (let i = this.workers.size + 1; i <= newCount; i++) {
                await this.startWorker(i);
            }
        } else {
            // Scale down - remove idle workers first
            const toRemove = this.workers.size - newCount;
            let removed = 0;

            for (const [workerId, workerInfo] of this.workers) {
                if (removed >= toRemove) break;
                if (workerInfo.status === 'idle') {
                    workerInfo.worker.terminate();
                    this.workers.delete(workerId);
                    removed++;
                }
            }
        }

        this.workerCount = newCount;
        this.logger.info(`[WorkerPool] Scaled to ${this.workers.size} workers`);
    }

    /**
     * Stop the worker pool
     */
    async stop() {
        this.logger.info('[WorkerPool] Stopping...');

        clearInterval(this.pollInterval);

        // Wait for active jobs to complete (with timeout)
        const timeout = 30000;
        const start = Date.now();

        while (this.activeJobs.size > 0 && Date.now() - start < timeout) {
            await new Promise(resolve => setTimeout(resolve, 1000));
        }

        // Terminate all workers
        await Promise.all(
            Array.from(this.workers.values()).map(w => w.worker.terminate())
        );

        this.workers.clear();
        this.activeJobs.clear();
        this.jobCallbacks.clear();

        this.logger.info('[WorkerPool] Stopped');
    }
}

export { EnhancedWorkerPool };
