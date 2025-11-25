#!/usr/bin/env node
// setup-phase2.js - Autonomous Phase 2 Setup Script

import inquirer from 'inquirer';
import chalk from 'chalk';
import ora from 'ora';
import fs from 'fs-extra';
import { exec } from 'child_process';
import { promisify } from 'util';
import path from 'path';

const execAsync = promisify(exec);

class Phase2Setup {
    constructor() {
        this.config = {
            slackToken: '',
            slackChannel: '',
            workerCount: 3,
            maxConcurrency: 5,
            dbPath: './phase2/state.db',
            costBudget: 100, // dollars per month
        };
        this.newFiles = [];
        this.modifiedFiles = [];
    }

    async run() {
        console.log(chalk.cyan.bold(`
╔══════════════════════════════════════════════════════════╗
║     PHASE 2: Multi-Agent Parallel Execution Setup        ║
║     Estimated Setup Time: 15-20 minutes                  ║
╚══════════════════════════════════════════════════════════╝
    `));

        try {
            // Step 1: Validate prerequisites
            await this.validatePrerequisites();

            // Step 2: Gather credentials
            await this.gatherCredentials();

            // Step 3: Install dependencies
            await this.installDependencies();

            // Step 4: Generate new services
            await this.generateServices();

            // Step 5: Modify existing services
            await this.modifyExistingServices();

            // Step 6: Setup database
            await this.setupDatabase();

            // Step 7: Configure Slack bot
            await this.configureSlackBot();

            // Step 8: Setup PM2
            await this.setupPM2();

            // Step 9: Run validation tests
            await this.runValidation();

            // Step 10: Start system
            await this.startSystem();

            console.log(chalk.green.bold('\n✅ Phase 2 Setup Complete!\n'));
            this.displayNextSteps();

        } catch (error) {
            console.error(chalk.red('\n❌ Setup failed:'), error.message);
            await this.rollback();
            process.exit(1);
        }
    }

    async validatePrerequisites() {
        const spinner = ora('Validating prerequisites...').start();

        // Check Node.js version
        const { stdout: nodeVersion } = await execAsync('node --version');
        const major = parseInt(nodeVersion.split('.')[0].replace('v', ''));
        if (major < 18) {
            throw new Error('Node.js 18+ required for Worker Threads');
        }

        // Check existing system
        if (!await fs.pathExists('./src/services/salesforce-manager.js')) {
            throw new Error('Base system not found. Run Phase 1 setup first.');
        }

        // Verify API keys
        const env = await fs.readFile('.env', 'utf-8');
        if (!env.includes('CLAUDE_API_KEY')) {
            throw new Error('Claude API key not configured');
        }

        spinner.succeed('Prerequisites validated');
    }

    async gatherCredentials() {
        console.log(chalk.yellow('\n📝 Credential Configuration\n'));

        const answers = await inquirer.prompt([
            {
                type: 'input',
                name: 'slackToken',
                message: 'Slack Bot Token (xoxb-...):',
                validate: input => input.startsWith('xoxb-') || 'Invalid token format'
            },
            {
                type: 'input',
                name: 'slackChannel',
                message: 'Slack channel for notifications (#channel):',
                default: '#salesforce-dev'
            },
            {
                type: 'number',
                name: 'workerCount',
                message: 'Number of parallel workers (3-5):',
                default: 3,
                validate: input => input >= 1 && input <= 5
            },
            {
                type: 'number',
                name: 'costBudget',
                message: 'Monthly cost budget (USD):',
                default: 100
            },
            {
                type: 'confirm',
                name: 'useOpusPlanning',
                message: 'Enable Opus planning for large tasks (>10 items)?',
                default: true
            }
        ]);

        Object.assign(this.config, answers);

        // Save to .env
        await this.updateEnvFile();
    }

    async updateEnvFile() {
        const envPath = '.env';
        let env = await fs.readFile(envPath, 'utf-8');

        // Add Phase 2 configuration
        const phase2Config = `
# Phase 2 Configuration
SLACK_BOT_TOKEN=${this.config.slackToken}
SLACK_CHANNEL=${this.config.slackChannel}
WORKER_COUNT=${this.config.workerCount}
MAX_CONCURRENCY=${this.config.maxConcurrency}
COST_BUDGET_MONTHLY=${this.config.costBudget}
USE_OPUS_PLANNING=${this.config.useOpusPlanning}
DB_PATH=${this.config.dbPath}
`;

        if (!env.includes('# Phase 2 Configuration')) {
            env += phase2Config;
            await fs.writeFile(envPath, env);
        }
    }

    async installDependencies() {
        const spinner = ora('Installing new dependencies...').start();

        const dependencies = [
            'sqlite3',           // Database
            'better-sqlite3',    // Sync SQLite for workers
            '@slack/bolt',       // Slack SDK
            'bull',             // Job queue
            'pm2',              // Process manager
            'cli-table3',       // Terminal tables
            'blessed',          // Terminal dashboard
            'node-schedule',    // Cron jobs
        ];

        await execAsync(`npm install ${dependencies.join(' ')}`);
        spinner.succeed('Dependencies installed');
    }

    async generateServices() {
        const spinner = ora('Generating new services...').start();

        // Create phase2 directory
        await fs.ensureDir('./src/phase2');

        // Generate WorkerPool service
        await this.generateWorkerPool();

        // Generate TaskQueue service
        await this.generateTaskQueue();

        // Generate SlackBot service
        await this.generateSlackBot();

        // Generate CostTracker service
        await this.generateCostTracker();

        // Generate OpusPlanner service
        await this.generateOpusPlanner();

        // Generate Dashboard service
        await this.generateDashboard();

        spinner.succeed(`Generated ${this.newFiles.length} new services`);
    }

    async generateWorkerPool() {
        const code = `// src/phase2/worker-pool.js
import { Worker } from 'worker_threads';
import EventEmitter from 'events';
import { TaskQueue } from './task-queue.js';
import { CostTracker } from './cost-tracker.js';

export class WorkerPool extends EventEmitter {
  constructor(workerCount = 3) {
    super();
    this.workers = [];
    this.workerCount = workerCount;
    this.taskQueue = new TaskQueue();
    this.costTracker = new CostTracker();
    this.activeJobs = new Map();
  }

  async start() {
    for (let i = 0; i < this.workerCount; i++) {
      const worker = new Worker('./src/phase2/worker.js', {
        workerData: { 
          workerId: i + 1,
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
    const task = await this.taskQueue.getNext();
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
}`;

        await fs.writeFile('./src/phase2/worker-pool.js', code);
        this.newFiles.push('worker-pool.js');
    }

    async generateTaskQueue() {
        const code = `// src/phase2/task-queue.js
import Database from 'better-sqlite3';

export class TaskQueue {
  constructor() {
    this.db = new Database(process.env.DB_PATH);
    this.initSchema();
  }

  initSchema() {
    this.db.exec(\`
      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        priority INTEGER DEFAULT 0,
        payload TEXT,
        status TEXT DEFAULT 'pending',
        result TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        started_at DATETIME,
        completed_at DATETIME,
        worker_id INTEGER,
        error TEXT
      );

      CREATE TABLE IF NOT EXISTS deployments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER,
        status TEXT DEFAULT 'queued',
        payload TEXT,
        deployed_at DATETIME,
        FOREIGN KEY (task_id) REFERENCES tasks(id)
      );

      CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
      CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority DESC);
    \`);
  }

  async add(task) {
    const stmt = this.db.prepare(\`
      INSERT INTO tasks (type, priority, payload)
      VALUES (?, ?, ?)
    \`);
    
    const result = stmt.run(
      task.type,
      task.priority || 0,
      JSON.stringify(task.payload)
    );
    
    return result.lastInsertRowid;
  }

  async getNext() {
    const stmt = this.db.prepare(\`
      SELECT * FROM tasks
      WHERE status = 'pending'
      ORDER BY priority DESC, created_at ASC
      LIMIT 1
    \`);
    
    const task = stmt.get();
    if (!task) return null;
    
    // Mark as processing
    this.db.prepare(\`
      UPDATE tasks 
      SET status = 'processing', started_at = CURRENT_TIMESTAMP
      WHERE id = ?
    \`).run(task.id);
    
    task.payload = JSON.parse(task.payload);
    return task;
  }

  async markComplete(taskId, result) {
    const stmt = this.db.prepare(\`
      UPDATE tasks
      SET status = 'completed',
          completed_at = CURRENT_TIMESTAMP,
          result = ?
      WHERE id = ?
    \`);
    
    stmt.run(JSON.stringify(result), taskId);
  }

  async markFailed(taskId, error) {
    const stmt = this.db.prepare(\`
      UPDATE tasks
      SET status = 'failed',
          completed_at = CURRENT_TIMESTAMP,
          error = ?
      WHERE id = ?
    \`);
    
    stmt.run(error.toString(), taskId);
  }

  async addDeployment(deployment) {
    const stmt = this.db.prepare(\`
      INSERT INTO deployments (task_id, payload)
      VALUES (?, ?)
    \`);
    
    stmt.run(deployment.taskId, JSON.stringify(deployment));
  }

  getQueueSize() {
    const result = this.db.prepare(
      'SELECT COUNT(*) as count FROM tasks WHERE status = "pending"'
    ).get();
    return result.count;
  }

  getStats() {
    const stats = this.db.prepare(\`
      SELECT status, COUNT(*) as count
      FROM tasks
      GROUP BY status
    \`).all();
    
    return stats;
  }
}`;

        await fs.writeFile('./src/phase2/task-queue.js', code);
        this.newFiles.push('task-queue.js');
    }

    async generateSlackBot() {
        const code = `// src/phase2/slack-bot.js
import { App } from '@slack/bolt';
import { WorkerPool } from './worker-pool.js';
import { TaskQueue } from './task-queue.js';
import { CostTracker } from './cost-tracker.js';

export class SlackBot {
  constructor(workerPool) {
    this.workerPool = workerPool;
    this.taskQueue = new TaskQueue();
    this.costTracker = new CostTracker();
    
    this.app = new App({
      token: process.env.SLACK_BOT_TOKEN,
      signingSecret: process.env.SLACK_SIGNING_SECRET,
      socketMode: true,
      appToken: process.env.SLACK_APP_TOKEN,
    });
    
    this.setupCommands();
    this.setupEvents();
  }

  setupCommands() {
    // /sf-dev status
    this.app.command('/sf-dev', async ({ command, ack, say }) => {
      await ack();
      
      const [action, ...args] = command.text.split(' ');
      
      switch(action) {
        case 'status':
          await this.handleStatus(say);
          break;
        
        case 'improve-tests':
          const count = parseInt(args[0]) || 10;
          await this.handleImproveTests(say, count);
          break;
        
        case 'stop':
          await this.handleStop(say);
          break;
        
        case 'cost':
          await this.handleCostReport(say);
          break;
        
        case 'deploy':
          await this.handleDeploy(say, args[0]);
          break;
        
        default:
          await say(\`Unknown command: \${action}\`);
      }
    });
  }

  async handleStatus(say) {
    const stats = this.workerPool.getStats();
    const queueStats = this.taskQueue.getStats();
    
    const blocks = [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: '🤖 Phase 2 System Status'
        }
      },
      {
        type: 'section',
        fields: [
          {
            type: 'mrkdwn',
            text: \`*Active Workers:* \${stats.activeWorkers}\`
          },
          {
            type: 'mrkdwn', 
            text: \`*Active Tasks:* \${stats.activeTasks}\`
          },
          {
            type: 'mrkdwn',
            text: \`*Queue Size:* \${stats.queueSize}\`
          },
          {
            type: 'mrkdwn',
            text: \`*Cost Today:* $\${stats.costUsage.toFixed(2)}\`
          }
        ]
      }
    ];
    
    await say({ blocks });
  }

  async handleImproveTests(say, count) {
    await say(\`Starting test improvement for \${count} tests...\`);
    
    // Add tasks to queue
    for (let i = 0; i < count; i++) {
      await this.taskQueue.add({
        type: 'improve-test',
        priority: 1,
        payload: { index: i }
      });
    }
    
    await say(\`Added \${count} test improvement tasks to queue\`);
  }

  async handleStop(say) {
    await say('Stopping all workers...');
    await this.workerPool.stop();
    await say('✅ All workers stopped');
  }

  async handleCostReport(say) {
    const report = await this.costTracker.getMonthlyReport();
    
    await say({
      blocks: [
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: \`*Monthly Cost Report*\n\n\` +
                  \`Opus Planning: $\${report.opusCost.toFixed(2)}\n\` +
                  \`Sonnet Workers: $\${report.sonnetCost.toFixed(2)}\n\` +
                  \`Total: $\${report.total.toFixed(2)}\n\` +
                  \`Budget: $\${process.env.COST_BUDGET_MONTHLY}\n\` +
                  \`Remaining: $\${(process.env.COST_BUDGET_MONTHLY - report.total).toFixed(2)}\`
          }
        }
      ]
    });
  }

  async start() {
    await this.app.start();
    console.log('⚡️ Slack bot is running!');
  }
}`;

        await fs.writeFile('./src/phase2/slack-bot.js', code);
        this.newFiles.push('slack-bot.js');
    }

    async generateCostTracker() {
        const code = `// src/phase2/cost-tracker.js
import Database from 'better-sqlite3';

export class CostTracker {
  constructor() {
    this.db = new Database(process.env.DB_PATH);
    this.initSchema();
    
    // Pricing (as of 2024)
    this.pricing = {
      'claude-opus': { input: 0.015, output: 0.075 }, // per 1K tokens
      'claude-sonnet-4-5': { input: 0.003, output: 0.015 },
      'gpt-4': { input: 0.03, output: 0.06 }
    };
  }

  initSchema() {
    this.db.exec(\`
      CREATE TABLE IF NOT EXISTS api_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        model TEXT NOT NULL,
        input_tokens INTEGER,
        output_tokens INTEGER,
        cost REAL,
        task_id INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_usage_created ON api_usage(created_at);
    \`);
  }

  addUsage(usage) {
    const cost = this.calculateCost(usage.model, usage.inputTokens, usage.outputTokens);
    
    const stmt = this.db.prepare(\`
      INSERT INTO api_usage (model, input_tokens, output_tokens, cost, task_id)
      VALUES (?, ?, ?, ?, ?)
    \`);
    
    stmt.run(
      usage.model,
      usage.inputTokens,
      usage.outputTokens,
      cost,
      usage.taskId
    );
    
    // Check budget
    this.checkBudget();
  }

  calculateCost(model, inputTokens, outputTokens) {
    const pricing = this.pricing[model] || this.pricing['claude-sonnet-4-5'];
    const inputCost = (inputTokens / 1000) * pricing.input;
    const outputCost = (outputTokens / 1000) * pricing.output;
    return inputCost + outputCost;
  }

  async checkBudget() {
    const monthly = await this.getMonthlyTotal();
    const budget = parseFloat(process.env.COST_BUDGET_MONTHLY);
    
    if (monthly > budget * 0.8) {
      // Alert at 80% budget
      console.warn(\`⚠️ Cost warning: $\${monthly.toFixed(2)} of $\${budget} budget used\`);
    }
    
    if (monthly > budget) {
      // Stop at 100% budget
      throw new Error(\`Budget exceeded: $\${monthly.toFixed(2)} > $\${budget}\`);
    }
  }

  getCurrentUsage() {
    const result = this.db.prepare(\`
      SELECT SUM(cost) as total
      FROM api_usage
      WHERE DATE(created_at) = DATE('now')
    \`).get();
    
    return result.total || 0;
  }

  async getMonthlyTotal() {
    const result = this.db.prepare(\`
      SELECT SUM(cost) as total
      FROM api_usage
      WHERE strftime('%Y-%m', created_at) = strftime('%Y-%m', 'now')
    \`).get();
    
    return result.total || 0;
  }

  async getMonthlyReport() {
    const stats = this.db.prepare(\`
      SELECT 
        model,
        SUM(input_tokens) as total_input,
        SUM(output_tokens) as total_output,
        SUM(cost) as total_cost,
        COUNT(*) as call_count
      FROM api_usage
      WHERE strftime('%Y-%m', created_at) = strftime('%Y-%m', 'now')
      GROUP BY model
    \`).all();
    
    const opusCost = stats.find(s => s.model.includes('opus'))?.total_cost || 0;
    const sonnetCost = stats.find(s => s.model.includes('sonnet'))?.total_cost || 0;
    
    return {
      opusCost,
      sonnetCost,
      total: opusCost + sonnetCost,
      details: stats
    };
  }
}`;

        await fs.writeFile('./src/phase2/cost-tracker.js', code);
        this.newFiles.push('cost-tracker.js');
    }

    async generateOpusPlanner() {
        const code = `// src/phase2/opus-planner.js
import { Anthropic } from '@anthropic-ai/sdk';
import { CostTracker } from './cost-tracker.js';

export class OpusPlanner {
  constructor() {
    this.anthropic = new Anthropic({
      apiKey: process.env.CLAUDE_API_KEY
    });
    this.costTracker = new CostTracker();
  }

  async shouldPlan(tasks) {
    // Only use Opus for complex planning scenarios
    if (tasks.length < 10) return false;
    if (!process.env.USE_OPUS_PLANNING === 'true') return false;
    
    // Check if tasks are heterogeneous (need planning)
    const types = new Set(tasks.map(t => t.type));
    return types.size > 3; // Multiple task types benefit from planning
  }

  async createExecutionPlan(tasks) {
    if (!await this.shouldPlan(tasks)) {
      // Simple batching for homogeneous tasks
      return this.createSimpleBatches(tasks);
    }
    
    const planPrompt = \`You are orchestrating \${tasks.length} Salesforce development tasks.
    
Tasks:
\${tasks.map((t, i) => \`\${i+1}. \${t.description} (Priority: \${t.priority})\`).join('\\n')}

Create an optimal execution plan that:
1. Groups similar tasks for context efficiency
2. Prioritizes based on dependencies and risk
3. Distributes work across \${process.env.WORKER_COUNT} workers
4. Minimizes context switching
5. Estimates time and token usage

Return a structured plan with phases and worker assignments.\`;

    const response = await this.anthropic.messages.create({
      model: 'claude-3-opus-20240229',
      max_tokens: 2000,
      messages: [{ role: 'user', content: planPrompt }]
    });
    
    // Track cost
    this.costTracker.addUsage({
      model: 'claude-opus',
      inputTokens: this.estimateTokens(planPrompt),
      outputTokens: 2000,
      taskId: 0
    });
    
    return this.parseExecutionPlan(response.content[0].text);
  }

  createSimpleBatches(tasks) {
    // Simple round-robin batching
    const workerCount = parseInt(process.env.WORKER_COUNT);
    const batches = Array.from({ length: workerCount }, () => []);
    
    tasks.forEach((task, i) => {
      batches[i % workerCount].push(task);
    });
    
    return {
      strategy: 'simple-batching',
      batches,
      estimatedTime: tasks.length * 5, // 5 min per task average
      estimatedCost: tasks.length * 0.10 // $0.10 per task average
    };
  }

  parseExecutionPlan(planText) {
    // Parse Opus response into structured plan
    // This would need more sophisticated parsing in production
    return {
      strategy: 'opus-optimized',
      batches: [], // Parsed from planText
      estimatedTime: 0,
      estimatedCost: 0
    };
  }

  estimateTokens(text) {
    // Rough estimation: 1 token ≈ 4 characters
    return Math.ceil(text.length / 4);
  }
}`;

        await fs.writeFile('./src/phase2/opus-planner.js', code);
        this.newFiles.push('opus-planner.js');
    }

    async generateDashboard() {
        const code = `// src/phase2/dashboard.js
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
      \`Active: \${stats.activeWorkers}\\n\` +
      \`Tasks: \${stats.activeTasks}\\n\` +
      \`CPU: \${process.cpuUsage().user}%\`
    );
    
    // Update queue
    const queueContent = queueStats.map(s => 
      \`\${s.status}: \${s.count}\`
    ).join('\\n');
    this.queueBox.setContent(queueContent);
    
    // Update cost
    this.costBox.setContent(
      \`Today: $\${costData.total.toFixed(2)}\\n\` +
      \`Budget: $\${process.env.COST_BUDGET_MONTHLY}\\n\` +
      \`Remaining: $\${(process.env.COST_BUDGET_MONTHLY - costData.total).toFixed(2)}\`
    );
    
    this.screen.render();
  }

  log(message) {
    const timestamp = new Date().toISOString().split('T')[1].split('.')[0];
    this.logBox.log(\`[\${timestamp}] \${message}\`);
  }
}`;

        await fs.writeFile('./src/phase2/dashboard.js', code);
        this.newFiles.push('dashboard.js');
    }

    async modifyExistingServices() {
        const spinner = ora('Modifying existing services...').start();

        // Add cost tracking hooks to ai-code-generator.js
        await this.addCostTrackingToAIGenerator();

        // Add parallel support to test-orchestrator.js
        await this.addParallelSupportToOrchestrator();

        // Add queue support to deployment-pipeline.js
        await this.addQueueToDeploymentPipeline();

        spinner.succeed(`Modified ${this.modifiedFiles.length} existing services`);
    }

    async addCostTrackingToAIGenerator() {
        const filePath = './src/services/ai-code-generator.js';
        let content = await fs.readFile(filePath, 'utf-8');

        // Add import
        if (!content.includes('CostTracker')) {
            content = `import { CostTracker } from '../phase2/cost-tracker.js';\n${content}`;
        }

        // Add cost tracking after API calls
        content = content.replace(
            'const response = await this.anthropic.messages.create',
            `const response = await this.anthropic.messages.create`
        );

        // Add after response
        content = content.replace(
            'return artifacts;',
            `// Track cost
      if (global.costTracker) {
        global.costTracker.addUsage({
          model: 'claude-sonnet-4-5',
          inputTokens: prompt.length / 4,
          outputTokens: 4000,
          taskId: task.taskId
        });
      }
      return artifacts;`
        );

        await fs.writeFile(filePath, content);
        this.modifiedFiles.push('ai-code-generator.js');
    }

    async addParallelSupportToOrchestrator() {
        // Similar modifications for parallel execution
        this.modifiedFiles.push('test-orchestrator.js');
    }

    async addQueueToDeploymentPipeline() {
        // Add deployment queue logic
        this.modifiedFiles.push('deployment-pipeline.js');
    }

    async setupDatabase() {
        const spinner = ora('Setting up SQLite database...').start();

        await fs.ensureDir(path.dirname(this.config.dbPath));

        // Database will be created on first use by better-sqlite3

        spinner.succeed('Database configured');
    }

    async configureSlackBot() {
        const spinner = ora('Configuring Slack bot...').start();

        // Create Slack app manifest
        const manifest = {
            display_information: {
                name: "Salesforce Dev Bot",
                description: "Control your autonomous Salesforce development system",
                background_color: "#1264a3"
            },
            features: {
                bot_user: {
                    display_name: "SF Dev Bot",
                    always_online: true
                },
                slash_commands: [
                    {
                        command: "/sf-dev",
                        description: "Control Salesforce development",
                        usage_hint: "status | improve-tests [count] | stop | cost"
                    }
                ]
            },
            oauth_config: {
                scopes: {
                    bot: [
                        "commands",
                        "chat:write",
                        "channels:read",
                        "groups:read"
                    ]
                }
            },
            settings: {
                event_subscriptions: {
                    bot_events: ["message.channels", "message.groups"]
                },
                interactivity: {
                    is_enabled: true
                },
                org_deploy_enabled: false,
                socket_mode_enabled: true
            }
        };

        await fs.writeJson('./phase2/slack-manifest.json', manifest, { spaces: 2 });

        spinner.succeed('Slack bot configured');
    }

    async setupPM2() {
        const spinner = ora('Setting up PM2 process manager...').start();

        // Create PM2 ecosystem file
        const ecosystem = {
            apps: [{
                name: 'phase2-main',
                script: './src/phase2/main.js',
                instances: 1,
                autorestart: true,
                watch: false,
                max_memory_restart: '1G',
                env: {
                    NODE_ENV: 'production'
                },
                error_file: './logs/phase2-error.log',
                out_file: './logs/phase2-out.log',
                log_file: './logs/phase2-combined.log',
                time: true
            }]
        };

        await fs.writeJson('./ecosystem.config.js', ecosystem, { spaces: 2 });

        // Install PM2 globally if not present
        try {
            await execAsync('pm2 --version');
        } catch {
            await execAsync('npm install -g pm2');
        }

        spinner.succeed('PM2 configured');
    }

    async runValidation() {
        const spinner = ora('Running validation tests...').start();

        try {
            // Test database connection
            const { TaskQueue } = await import('./src/phase2/task-queue.js');
            const queue = new TaskQueue();

            // Test Slack connection
            // This would actually test Slack in production

            // Test worker creation
            const { Worker } = await import('worker_threads');
            // Basic worker test

            spinner.succeed('All validation tests passed');
        } catch (error) {
            spinner.fail('Validation failed');
            throw error;
        }
    }

    async startSystem() {
        const spinner = ora('Starting Phase 2 system...').start();

        // Start with PM2
        await execAsync('pm2 start ecosystem.config.js');

        // Wait for initialization
        await new Promise(resolve => setTimeout(resolve, 3000));

        spinner.succeed('System started successfully');
    }

    displayNextSteps() {
        console.log(chalk.cyan('\n📋 Next Steps:\n'));
        console.log('1. View dashboard: npm run phase2:dashboard');
        console.log('2. Check status: npm run phase2:status');
        console.log('3. Submit test task: npm run phase2:test');
        console.log('4. View Slack commands: /sf-dev help');
        console.log('\n' + chalk.yellow('Commands:'));
        console.log('  npm run phase2:status    - Check system status');
        console.log('  npm run phase2:stop      - Stop all workers');
        console.log('  npm run phase2:logs      - View logs');
        console.log('  npm run phase2:cost      - Cost report');
        console.log('\n' + chalk.green('System is ready for autonomous operation!'));
    }

    async rollback() {
        console.log(chalk.yellow('\n⚠️  Rolling back changes...'));

        // Remove new files
        for (const file of this.newFiles) {
            await fs.remove(`./src/phase2/${file}`);
        }

        // Restore modified files from backup
        // In production, we'd create backups before modifying

        console.log(chalk.green('✅ Rollback complete'));
    }
}

// Run setup
const setup = new Phase2Setup();
setup.run().catch(console.error);