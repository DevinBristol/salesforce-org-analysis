// src/phase2/cost-tracker.js
import Database from 'better-sqlite3';

export class CostTracker {
  constructor() {
    this.db = new Database(process.env.DB_PATH);
    this.initSchema();

    // Pricing (as of 2025)
    this.pricing = {
      'claude-opus-4-20250514': { input: 0.015, output: 0.075 }, // per 1K tokens
      'claude-opus': { input: 0.015, output: 0.075 }, // Legacy
      'claude-sonnet-4-5': { input: 0.003, output: 0.015 },
      'claude-sonnet-4-20250514': { input: 0.003, output: 0.015 },
      'gpt-4': { input: 0.03, output: 0.06 }
    };
  }

  initSchema() {
    this.db.exec(`
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
    `);

    // Migration: Add cache token columns if they don't exist
    try {
      this.db.exec(`
        ALTER TABLE api_usage ADD COLUMN cache_read_tokens INTEGER DEFAULT 0;
      `);
      console.log('✅ Migration: Added cache_read_tokens column');
    } catch (err) {
      if (!err.message.includes('duplicate column')) {
        console.error('Migration warning:', err.message);
      }
    }

    try {
      this.db.exec(`
        ALTER TABLE api_usage ADD COLUMN cache_creation_tokens INTEGER DEFAULT 0;
      `);
      console.log('✅ Migration: Added cache_creation_tokens column');
    } catch (err) {
      if (!err.message.includes('duplicate column')) {
        console.error('Migration warning:', err.message);
      }
    }
  }

  addUsage(usage) {
    const cost = this.calculateCost(
      usage.model,
      usage.inputTokens,
      usage.outputTokens,
      usage.cacheReadTokens || 0,
      usage.cacheCreationTokens || 0
    );

    const stmt = this.db.prepare(`
      INSERT INTO api_usage (model, input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens, cost, task_id)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    stmt.run(
      usage.model,
      usage.inputTokens,
      usage.outputTokens,
      usage.cacheReadTokens || 0,
      usage.cacheCreationTokens || 0,
      cost,
      usage.taskId
    );

    // Check budget
    this.checkBudget();
  }

  calculateCost(model, inputTokens, outputTokens, cacheReadTokens = 0, cacheCreationTokens = 0) {
    const pricing = this.pricing[model] || this.pricing['claude-sonnet-4-20250514'];

    // Regular input tokens at full price
    const inputCost = (inputTokens / 1000) * pricing.input;

    // Output tokens at full price
    const outputCost = (outputTokens / 1000) * pricing.output;

    // Cache read tokens at 90% discount (10% of regular price)
    const cacheReadCost = (cacheReadTokens / 1000) * (pricing.input * 0.1);

    // Cache creation tokens at regular price (same as input)
    const cacheCreationCost = (cacheCreationTokens / 1000) * pricing.input;

    return inputCost + outputCost + cacheReadCost + cacheCreationCost;
  }

  async checkBudget() {
    const monthly = await this.getMonthlyTotal();
    const budget = parseFloat(process.env.COST_BUDGET_MONTHLY);

    if (monthly > budget * 0.8) {
      // Alert at 80% budget
      console.warn(`⚠️ Cost warning: $${monthly.toFixed(2)} of $${budget} budget used`);
    }

    if (monthly > budget) {
      // Stop at 100% budget
      throw new Error(`Budget exceeded: $${monthly.toFixed(2)} > $${budget}`);
    }
  }

  getCurrentUsage() {
    const result = this.db.prepare(`
      SELECT SUM(cost) as total
      FROM api_usage
      WHERE DATE(created_at) = DATE('now')
    `).get();

    return result.total || 0;
  }

  async getMonthlyTotal() {
    const result = this.db.prepare(`
      SELECT SUM(cost) as total
      FROM api_usage
      WHERE strftime('%Y-%m', created_at) = strftime('%Y-%m', 'now')
    `).get();

    return result.total || 0;
  }

  async getMonthlyReport() {
    const stats = this.db.prepare(`
      SELECT
        model,
        SUM(input_tokens) as total_input,
        SUM(output_tokens) as total_output,
        SUM(cost) as total_cost,
        COUNT(*) as call_count
      FROM api_usage
      WHERE strftime('%Y-%m', created_at) = strftime('%Y-%m', 'now')
      GROUP BY model
    `).all();

    const opusCost = stats.find(s => s.model.includes('opus'))?.total_cost || 0;
    const sonnetCost = stats.find(s => s.model.includes('sonnet'))?.total_cost || 0;

    return {
      opusCost,
      sonnetCost,
      total: opusCost + sonnetCost,
      details: stats
    };
  }
}