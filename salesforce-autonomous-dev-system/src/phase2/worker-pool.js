// src/phase2/worker-pool.js
import { Worker } from 'worker_threads';
import EventEmitter from 'events';
import { TaskQueue } from './task-queue.js';
import { CostTracker } from './cost-tracker.js';

export class WorkerPool extends EventEmitter {
  constructor(workerCount = 3, options = {}) {
    super();
    this.workers = [];
    this.workerCount = workerCount;
    this.workerScript = options.workerScript || './src/phase2/worker.js';
    this.workerType = options.workerType || 'salesforce';
    this.taskQueue = new TaskQueue();
    this.costTracker = new CostTracker();
    this.activeJobs = new Map();
  }

  async start() {
    for (let i = 0; i < this.workerCount; i++) {
      const worker = new Worker(this.workerScript, {
        workerData: {
          workerId: i + 1,
          workerType: this.workerType,
          dbPath: process.env.DB_PATH
        }
      });

      worker.on('message', (msg) => this.handleWorkerMessage(worker, msg));
      worker.on('error', (err) => this.handleWorkerError(worker, err));

      this.workers.push(worker);
      this.assignNextTask(worker);
    }
  }

  async assignNextTask(worker) {
    // Get next task that matches this worker pool's type
    const task = await this.taskQueue.getNext(this.workerType);
    if (!task) {
      setTimeout(() => this.assignNextTask(worker), 5000);
      return;
    }

    this.activeJobs.set(worker.threadId, task);
    worker.postMessage({ type: 'EXECUTE_TASK', task });
  }

  handleWorkerMessage(worker, msg) {
    switch(msg.type) {
      case 'TASK_COMPLETE':
        this.handleTaskComplete(worker, msg);
        break;
      case 'COST_UPDATE':
        this.costTracker.addUsage(msg.usage);
        break;
      case 'PROGRESS':
        this.emit('progress', msg);
        break;
    }
  }

  handleWorkerError(worker, err) {
    console.error('Worker error:', err);
    this.emit('error', err);
  }

  async handleTaskComplete(worker, msg) {
    const task = this.activeJobs.get(worker.threadId);
    await this.taskQueue.markComplete(task.id, msg.result);
    this.activeJobs.delete(worker.threadId);

    // Check for deployment readiness
    if (msg.result.readyToDeploy) {
      await this.queueDeployment(msg.result);
    }

    // Assign next task
    this.assignNextTask(worker);
  }

  async queueDeployment(result) {
    // Add to deployment queue (serialized)
    await this.taskQueue.addDeployment(result);
  }

  async stop() {
    await Promise.all(this.workers.map(w => w.terminate()));
  }

  getStats() {
    return {
      activeWorkers: this.workers.length,
      activeTasks: this.activeJobs.size,
      queueSize: this.taskQueue.getQueueSize(),
      costUsage: this.costTracker.getCurrentUsage()
    };
  }
}