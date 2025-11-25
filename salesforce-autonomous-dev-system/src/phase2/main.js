// src/phase2/main.js
import dotenv from 'dotenv';
import { WorkerPool } from './worker-pool.js';
import { SlackBot } from './slack-bot.js';
import { Dashboard } from './dashboard.js';
import { ErrorReporter } from './error-reporter.js';
import { SelfHealer } from './self-healer.js';

// Load environment variables
dotenv.config();

// Initialize error reporter and self-healer
const errorReporter = new ErrorReporter();
const selfHealer = new SelfHealer(errorReporter);

// Global error handlers with self-healing
process.on('uncaughtException', async (error) => {
  console.error('💥 Uncaught Exception:', error);

  // Attempt self-healing
  const healed = await selfHealer.attemptHeal(error);

  if (!healed) {
    await errorReporter.reportCrash(error);
    // Give time for error to be reported before exiting
    setTimeout(() => process.exit(1), 3000);
  } else {
    console.log('✅ Error healed, continuing operation');
  }
});

process.on('unhandledRejection', async (reason, promise) => {
  console.error('💥 Unhandled Rejection at:', promise, 'reason:', reason);
  const error = new Error(String(reason));

  // Attempt self-healing
  const healed = await selfHealer.attemptHeal(error);

  if (!healed) {
    await errorReporter.reportError(error, { type: 'unhandledRejection' });
  }
});

async function main() {
  console.log('🚀 Starting Phase 3 Multi-Agent System...');
  console.log('📦 Initializing Salesforce + Local Repository Operations\n');

  // Initialize Salesforce worker pool
  const salesforceWorkerPool = new WorkerPool(parseInt(process.env.WORKER_COUNT) || 3);
  await salesforceWorkerPool.start();
  console.log(`✅ Started ${process.env.WORKER_COUNT || 3} Salesforce workers`);

  // Initialize Local repository worker pool (Phase 3)
  const localWorkerPool = new WorkerPool(parseInt(process.env.LOCAL_WORKER_COUNT) || 2, {
    workerScript: './src/phase2/local-repo-worker.js',
    workerType: 'local'
  });
  await localWorkerPool.start();
  console.log(`✅ Started ${process.env.LOCAL_WORKER_COUNT || 2} Local repository workers`);

  // Initialize Slack bot with both worker pools (Phase 3)
  const slackBot = new SlackBot(salesforceWorkerPool, localWorkerPool);
  await slackBot.start();
  console.log('✅ Slack bot connected');

  // Initialize dashboard (optional)
  if (process.env.ENABLE_DASHBOARD === 'true') {
    const dashboard = new Dashboard(salesforceWorkerPool);
    dashboard.init();
    console.log('✅ Dashboard initialized');
  }

  console.log('\n🎉 Phase 3 system is running!');
  console.log('📱 Salesforce operations: Active');
  console.log('💻 Local repository operations: Active');
  console.log('🛡️  Self-healing: Active');
  console.log('\nTry these commands in Slack:');
  console.log('  - "show git status"');
  console.log('  - "analyze my local codebase"');
  console.log('  - "/sf-dev status"');
  console.log('  - "/sf-dev restart-bot" (remote restart)');

  // Periodic health check (every 5 minutes)
  setInterval(async () => {
    console.log('[HealthCheck] Running system health check...');
    const health = await selfHealer.performHealthCheck();

    if (!health.healthy) {
      console.warn('[HealthCheck] Issues detected:', health.issues);
      await errorReporter.reportError(
        new Error('Health check failed'),
        { issues: health.issues }
      );
    } else {
      console.log('[HealthCheck] System healthy ✓');
    }
  }, 5 * 60 * 1000); // 5 minutes
}

main().catch(async (error) => {
  console.error('❌ Failed to start Phase 3 system:', error);
  await errorReporter.reportCrash(error);
  // Give time for error to be reported
  setTimeout(() => process.exit(1), 3000);
});