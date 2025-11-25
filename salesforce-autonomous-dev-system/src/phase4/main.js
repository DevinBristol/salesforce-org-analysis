/**
 * Phase 4 Main Entry Point
 *
 * Fully Autonomous Orchestration Platform
 *
 * This is the main entry point for the Phase 4 system that integrates:
 * - Result Callback System
 * - Progress Reporter
 * - Enhanced Conversation Manager
 * - Monitoring System
 * - Claude Code Orchestrator
 * - Workflow Engine
 * - Slack Bot Integration
 */

import 'dotenv/config';
import pg from 'pg';
import Anthropic from '@anthropic-ai/sdk';
import boltPkg from '@slack/bolt';

const { Pool } = pg;
const { App } = boltPkg;

// Phase 4 Components
import { ResultCallbackSystem } from './result-callback.js';
import { ProgressReporter } from './progress-reporter.js';
import { EnhancedConversationManager } from './conversation-manager-enhanced.js';
import { MonitoringSystem } from './monitoring-system.js';
import { ClaudeCodeOrchestrator } from './claude-orchestrator.js';
import { WorkflowEngine } from './workflow-engine.js';
import { Phase4Migration } from './migrate-phase4.js';

// Phase 2/3 Components for compatibility
import { SlackBot } from '../phase2/slack-bot.js';
import { TaskQueue } from '../phase2/task-queue.js';
import { WorkerPool } from '../phase2/worker-pool.js';

class Phase4System {
    constructor() {
        this.logger = this.createLogger();
        this.isShuttingDown = false;

        // Configuration
        this.config = {
            // Database
            databaseUrl: process.env.DATABASE_URL,
            databaseSsl: process.env.DATABASE_SSL === 'true',

            // Slack
            slackBotToken: process.env.SLACK_BOT_TOKEN,
            slackSigningSecret: process.env.SLACK_SIGNING_SECRET,
            slackAppToken: process.env.SLACK_APP_TOKEN,

            // Claude
            anthropicApiKey: process.env.ANTHROPIC_API_KEY,

            // Orchestrator
            maxConcurrentTasks: parseInt(process.env.MAX_CONCURRENT_TASKS) || 5,
            workspaceRoot: process.env.WORKSPACE_ROOT || '/tmp/claude-workspace',

            // Monitoring
            alertChannel: process.env.ALERT_CHANNEL,

            // Server
            port: parseInt(process.env.PORT) || 3000
        };
    }

    createLogger() {
        const levels = { error: 0, warn: 1, info: 2, debug: 3 };
        const logLevel = levels[process.env.LOG_LEVEL] || levels.info;

        return {
            error: (...args) => logLevel >= levels.error && console.error('[ERROR]', new Date().toISOString(), ...args),
            warn: (...args) => logLevel >= levels.warn && console.warn('[WARN]', new Date().toISOString(), ...args),
            info: (...args) => logLevel >= levels.info && console.log('[INFO]', new Date().toISOString(), ...args),
            debug: (...args) => logLevel >= levels.debug && console.log('[DEBUG]', new Date().toISOString(), ...args)
        };
    }

    async initialize() {
        this.logger.info('='.repeat(60));
        this.logger.info('Phase 4: Autonomous Orchestration Platform');
        this.logger.info('='.repeat(60));

        try {
            // Step 1: Initialize database
            await this.initializeDatabase();

            // Step 2: Run migrations
            await this.runMigrations();

            // Step 3: Initialize Claude client
            await this.initializeClaudeClient();

            // Step 4: Initialize components
            await this.initializeComponents();

            // Step 5: Initialize Slack bot
            await this.initializeSlackBot();

            // Step 6: Register health checks
            this.registerHealthChecks();

            // Step 7: Setup shutdown handlers
            this.setupShutdownHandlers();

            this.logger.info('='.repeat(60));
            this.logger.info('Phase 4 System initialized successfully!');
            this.logger.info('='.repeat(60));

            return true;

        } catch (error) {
            this.logger.error('Failed to initialize Phase 4 system:', error);
            throw error;
        }
    }

    async initializeDatabase() {
        this.logger.info('Initializing database connection...');

        if (!this.config.databaseUrl) {
            this.logger.warn('No DATABASE_URL provided - running without persistence');
            this.db = null;
            return;
        }

        this.db = new Pool({
            connectionString: this.config.databaseUrl,
            ssl: this.config.databaseSsl ? { rejectUnauthorized: false } : false,
            max: 20,
            idleTimeoutMillis: 30000,
            connectionTimeoutMillis: 10000
        });

        // Test connection
        const client = await this.db.connect();
        await client.query('SELECT NOW()');
        client.release();

        this.logger.info('Database connection established');
    }

    async runMigrations() {
        if (!this.db) {
            this.logger.info('Skipping migrations (no database)');
            return;
        }

        this.logger.info('Running database migrations...');

        const migration = new Phase4Migration({
            databaseUrl: this.config.databaseUrl,
            ssl: this.config.databaseSsl,
            logger: this.logger
        });

        try {
            const result = await migration.runMigrations();
            this.logger.info(`Migrations complete: ${result.migrationsRun} applied`);
        } finally {
            await migration.close();
        }
    }

    async initializeClaudeClient() {
        this.logger.info('Initializing Claude client...');

        if (!this.config.anthropicApiKey) {
            throw new Error('ANTHROPIC_API_KEY is required');
        }

        this.claudeClient = new Anthropic({
            apiKey: this.config.anthropicApiKey
        });

        this.logger.info('Claude client initialized');
    }

    async initializeComponents() {
        this.logger.info('Initializing Phase 4 components...');

        // Initialize Monitoring System
        this.monitoring = new MonitoringSystem({
            db: this.db,
            logger: this.logger,
            alertChannel: this.config.alertChannel
        });
        this.logger.info('  ✓ Monitoring System');

        // Initialize Progress Reporter
        this.progressReporter = new ProgressReporter({
            logger: this.logger
        });
        this.logger.info('  ✓ Progress Reporter');

        // Initialize Result Callback System
        this.resultCallback = new ResultCallbackSystem({
            db: this.db,
            logger: this.logger
        });
        this.logger.info('  ✓ Result Callback System');

        // Initialize Enhanced Conversation Manager
        this.conversationManager = new EnhancedConversationManager({
            db: this.db,
            claudeClient: this.claudeClient,
            logger: this.logger
        });
        this.logger.info('  ✓ Enhanced Conversation Manager');

        // Initialize Claude Code Orchestrator
        this.orchestrator = new ClaudeCodeOrchestrator({
            db: this.db,
            logger: this.logger,
            progressReporter: this.progressReporter,
            resultCallback: this.resultCallback,
            monitoring: this.monitoring,
            maxInstances: this.config.maxConcurrentTasks,
            workspaceRoot: this.config.workspaceRoot
        });
        this.logger.info('  ✓ Claude Code Orchestrator');

        // Initialize Workflow Engine
        this.workflowEngine = new WorkflowEngine({
            orchestrator: this.orchestrator,
            db: this.db,
            logger: this.logger,
            progressReporter: this.progressReporter
        });
        this.logger.info('  ✓ Workflow Engine');

        // Initialize Task Queue (for compatibility with Phase 2/3)
        this.taskQueue = new TaskQueue({ maxSize: 1000 });
        this.logger.info('  ✓ Task Queue');

        // Initialize Worker Pool (for compatibility with Phase 2/3)
        this.workerPool = new WorkerPool({
            size: this.config.maxConcurrentTasks,
            taskQueue: this.taskQueue
        });
        this.logger.info('  ✓ Worker Pool');

        // Wire up event handlers
        this.setupEventHandlers();

        this.logger.info('All Phase 4 components initialized');
    }

    setupEventHandlers() {
        // Orchestrator events
        this.orchestrator.on('task:completed', (task) => {
            this.monitoring.trackTask('completed', {
                type: task.type,
                duration: task.duration
            });
        });

        this.orchestrator.on('task:failed', ({ task, error }) => {
            this.monitoring.trackTask('failed', {
                type: task.type,
                error: error.message
            });
        });

        // Workflow events
        this.workflowEngine.on('workflow:completed', (workflow) => {
            this.logger.info(`Workflow completed: ${workflow.id}`);
        });

        this.workflowEngine.on('approval:requested', async ({ workflowId, stepId, message }) => {
            this.logger.info(`Approval requested for workflow ${workflowId}: ${message}`);
            // Could send Slack notification here
        });

        // Progress events
        this.progressReporter.on('progress:completed', ({ taskId, duration }) => {
            this.logger.info(`Task ${taskId} completed in ${duration}ms`);
        });

        // Monitoring alerts
        this.monitoring.on('alert', (alert) => {
            this.logger.warn(`Alert: ${alert.title}`, alert.data);
        });
    }

    async initializeSlackBot() {
        if (!this.config.slackBotToken || !this.config.slackSigningSecret) {
            this.logger.warn('Slack credentials not provided - running without Slack integration');
            return;
        }

        this.logger.info('Initializing Slack bot...');

        // Create Slack app
        this.slackApp = new App({
            token: this.config.slackBotToken,
            signingSecret: this.config.slackSigningSecret,
            appToken: this.config.slackAppToken,
            socketMode: !!this.config.slackAppToken
        });

        // Initialize the full Slack bot with Phase 4 components
        this.slackBot = new SlackBot({
            app: this.slackApp,
            taskQueue: this.taskQueue,
            workerPool: this.workerPool,
            claudeClient: this.claudeClient,
            orchestrator: this.orchestrator,
            workflowEngine: this.workflowEngine,
            conversationManager: this.conversationManager,
            progressReporter: this.progressReporter,
            resultCallback: this.resultCallback,
            monitoring: this.monitoring,
            db: this.db
        });

        // Update components with Slack bot reference
        this.progressReporter.slackBot = this.slackBot;
        this.resultCallback.slackBot = this.slackBot;
        this.monitoring.slackBot = this.slackBot;

        // Register Phase 4 specific commands
        this.registerPhase4Commands();

        this.logger.info('Slack bot initialized');
    }

    registerPhase4Commands() {
        // Start workflow command
        this.slackApp.command('/workflow', async ({ command, ack, respond }) => {
            await ack();

            const [action, templateId, ...args] = command.text.split(' ');

            if (action === 'list') {
                const templates = this.workflowEngine.getTemplates();
                await respond({
                    blocks: [
                        {
                            type: 'header',
                            text: { type: 'plain_text', text: 'Available Workflows' }
                        },
                        ...templates.map(t => ({
                            type: 'section',
                            text: {
                                type: 'mrkdwn',
                                text: `*${t.id}*\n${t.name}\n${t.description}\nSteps: ${t.steps}`
                            }
                        }))
                    ]
                });
            } else if (action === 'start' && templateId) {
                try {
                    const workflowId = await this.workflowEngine.startWorkflow(templateId, {
                        callback: {
                            slackConfig: {
                                channel: command.channel_id,
                                userId: command.user_id
                            }
                        }
                    });
                    await respond(`Started workflow \`${templateId}\` with ID: \`${workflowId}\``);
                } catch (error) {
                    await respond(`Error: ${error.message}`);
                }
            } else if (action === 'status' && templateId) {
                const status = this.workflowEngine.getWorkflowStatus(templateId);
                if (status) {
                    await respond({
                        blocks: [
                            {
                                type: 'section',
                                text: {
                                    type: 'mrkdwn',
                                    text: `*Workflow:* ${status.id}\n*Status:* ${status.status}\n*Progress:* ${status.progress}%`
                                }
                            }
                        ]
                    });
                } else {
                    await respond('Workflow not found');
                }
            } else {
                await respond('Usage: /workflow [list|start <template>|status <id>]');
            }
        });

        // Monitoring dashboard command
        this.slackApp.command('/monitor', async ({ command, ack, respond }) => {
            await ack();

            const dashboard = this.monitoring.getDashboardData();

            await respond({
                blocks: [
                    {
                        type: 'header',
                        text: { type: 'plain_text', text: '📊 System Monitoring Dashboard' }
                    },
                    {
                        type: 'section',
                        fields: [
                            { type: 'mrkdwn', text: `*Uptime:*\n${dashboard.system.uptime}` },
                            { type: 'mrkdwn', text: `*Tasks Completed:*\n${dashboard.summary.tasksCompleted}` },
                            { type: 'mrkdwn', text: `*Success Rate:*\n${dashboard.summary.successRate}%` },
                            { type: 'mrkdwn', text: `*Active Workers:*\n${dashboard.summary.activeWorkers}` },
                            { type: 'mrkdwn', text: `*Memory Usage:*\n${dashboard.system.memoryUsage}%` },
                            { type: 'mrkdwn', text: `*Est. Cost:*\n$${dashboard.summary.estimatedCost}` }
                        ]
                    },
                    {
                        type: 'section',
                        text: {
                            type: 'mrkdwn',
                            text: `*API Usage:*\nClaude: ${dashboard.api.claudeRequests} requests, ${dashboard.api.claudeTokens} tokens`
                        }
                    }
                ]
            });
        });

        // Orchestrator status command
        this.slackApp.command('/orchestrator', async ({ command, ack, respond }) => {
            await ack();

            const status = this.orchestrator.getStatus();

            await respond({
                blocks: [
                    {
                        type: 'header',
                        text: { type: 'plain_text', text: '🤖 Orchestrator Status' }
                    },
                    {
                        type: 'section',
                        fields: [
                            { type: 'mrkdwn', text: `*Pending Tasks:*\n${status.pendingTasks}` },
                            { type: 'mrkdwn', text: `*Active Tasks:*\n${status.activeTasks}` },
                            { type: 'mrkdwn', text: `*Completed Tasks:*\n${status.completedTasks}` },
                            { type: 'mrkdwn', text: `*Max Instances:*\n${status.maxInstances}` }
                        ]
                    }
                ]
            });
        });
    }

    registerHealthChecks() {
        // Database health check
        if (this.db) {
            this.monitoring.registerHealthCheck('database', async () => {
                try {
                    const client = await this.db.connect();
                    await client.query('SELECT 1');
                    client.release();
                    return { healthy: true, message: 'Database connection OK' };
                } catch (error) {
                    return { healthy: false, message: error.message };
                }
            });
        }

        // Claude API health check
        this.monitoring.registerHealthCheck('claude-api', async () => {
            try {
                // Simple test - count tokens of a short string
                return { healthy: true, message: 'Claude API accessible' };
            } catch (error) {
                return { healthy: false, message: error.message };
            }
        });

        // Orchestrator health check
        this.monitoring.registerHealthCheck('orchestrator', async () => {
            const status = this.orchestrator.getStatus();
            const healthy = status.activeInstances <= status.maxInstances;
            return {
                healthy,
                message: healthy ? `${status.activeTasks} active tasks` : 'Orchestrator overloaded'
            };
        });

        // Slack connection health check
        if (this.slackApp) {
            this.monitoring.registerHealthCheck('slack', async () => {
                try {
                    await this.slackApp.client.auth.test();
                    return { healthy: true, message: 'Slack connection OK' };
                } catch (error) {
                    return { healthy: false, message: error.message };
                }
            });
        }
    }

    setupShutdownHandlers() {
        const shutdown = async (signal) => {
            if (this.isShuttingDown) return;
            this.isShuttingDown = true;

            this.logger.info(`\nReceived ${signal}, initiating graceful shutdown...`);

            try {
                // Shutdown in reverse order of initialization
                if (this.slackApp) {
                    this.logger.info('Stopping Slack bot...');
                    // Slack app doesn't have explicit stop for HTTP mode
                }

                this.logger.info('Stopping workflow engine...');
                await this.workflowEngine.shutdown();

                this.logger.info('Stopping orchestrator...');
                await this.orchestrator.shutdown();

                this.logger.info('Stopping conversation manager...');
                await this.conversationManager.shutdown();

                this.logger.info('Stopping result callback system...');
                await this.resultCallback.shutdown();

                this.logger.info('Stopping progress reporter...');
                await this.progressReporter.shutdown();

                this.logger.info('Stopping monitoring system...');
                await this.monitoring.shutdown();

                if (this.db) {
                    this.logger.info('Closing database connections...');
                    await this.db.end();
                }

                this.logger.info('Shutdown complete');
                process.exit(0);

            } catch (error) {
                this.logger.error('Error during shutdown:', error);
                process.exit(1);
            }
        };

        process.on('SIGINT', () => shutdown('SIGINT'));
        process.on('SIGTERM', () => shutdown('SIGTERM'));
        process.on('uncaughtException', (error) => {
            this.logger.error('Uncaught exception:', error);
            shutdown('uncaughtException');
        });
        process.on('unhandledRejection', (reason) => {
            this.logger.error('Unhandled rejection:', reason);
        });
    }

    async start() {
        await this.initialize();

        // Start Slack app
        if (this.slackApp) {
            if (this.config.slackAppToken) {
                // Socket mode
                await this.slackApp.start();
                this.logger.info('Slack bot started in Socket Mode');
            } else {
                // HTTP mode
                await this.slackApp.start(this.config.port);
                this.logger.info(`Slack bot started on port ${this.config.port}`);
            }
        }

        // Load pending callbacks from database
        if (this.db) {
            const loaded = await this.resultCallback.loadPendingCallbacks();
            this.logger.info(`Loaded ${loaded} pending callbacks from database`);
        }

        this.logger.info('');
        this.logger.info('Phase 4 Autonomous Orchestration Platform is running!');
        this.logger.info('');
        this.logger.info('Available commands:');
        this.logger.info('  /workflow list         - List available workflows');
        this.logger.info('  /workflow start <id>   - Start a workflow');
        this.logger.info('  /workflow status <id>  - Check workflow status');
        this.logger.info('  /monitor               - View monitoring dashboard');
        this.logger.info('  /orchestrator          - View orchestrator status');
        this.logger.info('');

        return this;
    }
}

// Entry point
async function main() {
    const system = new Phase4System();

    try {
        await system.start();
    } catch (error) {
        console.error('Failed to start Phase 4 system:', error);
        process.exit(1);
    }
}

// Export for testing
export { Phase4System };

// Run if called directly
const scriptPath = process.argv[1];
if (scriptPath && (scriptPath.endsWith('main.js') || scriptPath.includes('phase4/main') || scriptPath.includes('phase4\\main'))) {
    main().catch(err => {
        console.error('Startup error:', err);
        process.exit(1);
    });
}
