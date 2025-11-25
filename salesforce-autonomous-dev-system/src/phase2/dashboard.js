// src/phase2/dashboard.js
import blessed from 'blessed';
import { WorkerPool } from './worker-pool.js';
import { TaskQueue } from './task-queue.js';
import { CostTracker } from './cost-tracker.js';

export class Dashboard {
  constructor(workerPool) {
    this.workerPool = workerPool;
    this.taskQueue = new TaskQueue();
    this.costTracker = new CostTracker();

    this.screen = blessed.screen({
      smartCSR: true,
      title: 'Phase 2 Dashboard'
    });
  }

  init() {
    // Create dashboard layout
    this.createWorkerBox();
    this.createQueueBox();
    this.createCostBox();
    this.createLogBox();

    // Refresh every second
    setInterval(() => this.update(), 1000);

    // Quit on Q or Control-C
    this.screen.key(['q', 'C-c'], () => {
      return process.exit(0);
    });

    this.screen.render();
  }

  createWorkerBox() {
    this.workerBox = blessed.box({
      label: ' Workers ',
      top: 0,
      left: 0,
      width: '50%',
      height: '30%',
      border: { type: 'line' },
      style: {
        border: { fg: 'cyan' }
      }
    });
    this.screen.append(this.workerBox);
  }

  createQueueBox() {
    this.queueBox = blessed.box({
      label: ' Task Queue ',
      top: 0,
      left: '50%',
      width: '50%',
      height: '30%',
      border: { type: 'line' },
      style: {
        border: { fg: 'yellow' }
      }
    });
    this.screen.append(this.queueBox);
  }

  createCostBox() {
    this.costBox = blessed.box({
      label: ' Cost Tracking ',
      top: '30%',
      left: 0,
      width: '100%',
      height: '20%',
      border: { type: 'line' },
      style: {
        border: { fg: 'green' }
      }
    });
    this.screen.append(this.costBox);
  }

  createLogBox() {
    this.logBox = blessed.log({
      label: ' Activity Log ',
      top: '50%',
      left: 0,
      width: '100%',
      height: '50%',
      border: { type: 'line' },
      scrollable: true,
      alwaysScroll: true,
      style: {
        border: { fg: 'white' }
      }
    });
    this.screen.append(this.logBox);
  }

  async update() {
    const stats = this.workerPool.getStats();
    const queueStats = this.taskQueue.getStats();
    const costData = await this.costTracker.getMonthlyReport();

    // Update worker status
    this.workerBox.setContent(
      `Active: ${stats.activeWorkers}\n` +
      `Tasks: ${stats.activeTasks}`
    );

    // Update queue
    const queueContent = queueStats.map(s =>
      `${s.status}: ${s.count}`
    ).join('\n');
    this.queueBox.setContent(queueContent);

    // Update cost
    this.costBox.setContent(
      `Today: $${costData.total.toFixed(2)}\n` +
      `Budget: $${process.env.COST_BUDGET_MONTHLY}\n` +
      `Remaining: $${(process.env.COST_BUDGET_MONTHLY - costData.total).toFixed(2)}`
    );

    this.screen.render();
  }

  log(message) {
    const timestamp = new Date().toISOString().split('T')[1].split('.')[0];
    this.logBox.log(`[${timestamp}] ${message}`);
  }
}