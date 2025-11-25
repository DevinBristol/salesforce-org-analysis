// src/phase2/self-healer.js
import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';

const execAsync = promisify(exec);

export class SelfHealer {
  constructor(errorReporter) {
    this.errorReporter = errorReporter;
    this.healingAttempts = new Map();
    this.maxAttemptsPerError = 3;
  }

  /**
   * Attempt to heal from an error
   * @param {Error} error - The error to heal from
   * @returns {Promise<boolean>} - Whether healing was successful
   */
  async attemptHeal(error) {
    const errorKey = this.getErrorKey(error);
    const attempts = this.healingAttempts.get(errorKey) || 0;

    if (attempts >= this.maxAttemptsPerError) {
      console.log(`[SelfHealer] Max healing attempts reached for: ${errorKey}`);
      return false;
    }

    this.healingAttempts.set(errorKey, attempts + 1);

    // Detect error type and apply appropriate healing
    const healingResult = await this.detectAndHeal(error);

    if (healingResult.healed) {
      await this.errorReporter.reportRecovery(healingResult.action);
      this.healingAttempts.delete(errorKey); // Reset counter on success
      return true;
    }

    return false;
  }

  getErrorKey(error) {
    // Create a unique key for this error type
    const message = error.message || 'unknown';
    const firstLine = message.split('\n')[0];
    return firstLine.substring(0, 100);
  }

  async detectAndHeal(error) {
    const errorMessage = error.message || '';
    const errorStack = error.stack || '';

    // Database locked error
    if (errorMessage.includes('database is locked') || errorMessage.includes('SQLITE_BUSY')) {
      return await this.healDatabaseLocked();
    }

    // Missing module error
    if (errorMessage.includes('Cannot find module')) {
      return await this.healMissingModule(error);
    }

    // Port already in use (Slack socket)
    if (errorMessage.includes('EADDRINUSE') || errorMessage.includes('address already in use')) {
      return await this.healPortInUse();
    }

    // Slack connection error
    if (errorMessage.includes('slack') && (errorMessage.includes('connection') || errorMessage.includes('timeout'))) {
      return await this.healSlackConnection();
    }

    // Worker thread crashed
    if (errorMessage.includes('worker') && errorMessage.includes('terminated')) {
      return await this.healWorkerCrash();
    }

    // Database schema mismatch
    if (errorMessage.includes('no such column') || errorMessage.includes('no such table')) {
      return await this.healDatabaseSchema();
    }

    // File permission error
    if (errorMessage.includes('EACCES') || errorMessage.includes('permission denied')) {
      return await this.healPermissionError(error);
    }

    // Memory error
    if (errorMessage.includes('out of memory') || errorMessage.includes('heap')) {
      return await this.healMemoryError();
    }

    return { healed: false, action: 'No healing strategy available' };
  }

  async healDatabaseLocked() {
    console.log('[SelfHealer] Attempting to heal database lock...');
    // Wait and retry
    await new Promise(resolve => setTimeout(resolve, 2000));
    return { healed: true, action: 'Waited 2s for database lock to release' };
  }

  async healMissingModule(error) {
    console.log('[SelfHealer] Attempting to heal missing module...');
    const match = error.message.match(/Cannot find module '(.+?)'/);
    if (match) {
      const moduleName = match[1];
      try {
        await execAsync('npm install');
        return { healed: true, action: `Ran npm install to restore dependencies` };
      } catch (err) {
        return { healed: false, action: 'Failed to install missing modules' };
      }
    }
    return { healed: false, action: 'Could not determine missing module' };
  }

  async healPortInUse() {
    console.log('[SelfHealer] Port in use - will restart with new connection...');
    // Just restart - pm2 will handle it
    return { healed: true, action: 'Restarting to establish new connection' };
  }

  async healSlackConnection() {
    console.log('[SelfHealer] Attempting to heal Slack connection...');
    // Wait before retry
    await new Promise(resolve => setTimeout(resolve, 5000));
    return { healed: true, action: 'Waited 5s before reconnecting to Slack' };
  }

  async healWorkerCrash() {
    console.log('[SelfHealer] Worker crashed - pool will recreate automatically');
    return { healed: true, action: 'Worker pool automatically recreated crashed worker' };
  }

  async healDatabaseSchema() {
    console.log('[SelfHealer] Database schema issue - migrations will run on restart');
    // The migration code in task-queue.js and cost-tracker.js will handle this
    return { healed: true, action: 'Database migrations will apply on restart' };
  }

  async healPermissionError(error) {
    console.log('[SelfHealer] Permission error detected:', error.message);
    return { healed: false, action: 'Permission errors require manual intervention' };
  }

  async healMemoryError() {
    console.log('[SelfHealer] Memory error - forcing garbage collection and restart');
    if (global.gc) {
      global.gc();
    }
    // Need to restart to clear memory
    setTimeout(() => process.exit(1), 2000);
    return { healed: true, action: 'Forced garbage collection and scheduled restart' };
  }

  /**
   * Check system health and preemptively fix issues
   */
  async performHealthCheck() {
    const issues = [];

    // Check database accessibility
    try {
      const dbPath = process.env.DB_PATH;
      if (dbPath && !fs.existsSync(dbPath)) {
        issues.push('Database file missing');
      }
    } catch (err) {
      issues.push(`Database check failed: ${err.message}`);
    }

    // Check environment variables
    const required = ['SLACK_BOT_TOKEN', 'SLACK_APP_TOKEN', 'ANTHROPIC_API_KEY'];
    for (const envVar of required) {
      if (!process.env[envVar]) {
        issues.push(`Missing environment variable: ${envVar}`);
      }
    }

    // Check disk space (basic check)
    try {
      const { stdout } = await execAsync('df -h . | tail -1 | awk \'{print $5}\'');
      const usage = parseInt(stdout.trim().replace('%', ''));
      if (usage > 95) {
        issues.push(`Disk usage high: ${usage}%`);
      }
    } catch (err) {
      // Ignore disk check errors on Windows
    }

    return {
      healthy: issues.length === 0,
      issues
    };
  }
}
