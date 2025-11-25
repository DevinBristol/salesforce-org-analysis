// src/phase2/task-queue.js
import Database from 'better-sqlite3';

export class TaskQueue {
  constructor() {
    this.db = new Database(process.env.DB_PATH);
    this.initSchema();
  }

  initSchema() {
    // Create tables without worker_type first (for existing databases)
    this.db.exec(`
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
    `);

    // Migration: Add worker_type column if it doesn't exist
    try {
      this.db.exec(`
        ALTER TABLE tasks ADD COLUMN worker_type TEXT DEFAULT 'salesforce';
      `);
      console.log('✅ Migration: Added worker_type column to tasks table');
    } catch (err) {
      // Column already exists, ignore error
      if (!err.message.includes('duplicate column')) {
        console.error('Migration warning:', err.message);
      }
    }

    // Create index on worker_type after column exists
    try {
      this.db.exec(`
        CREATE INDEX IF NOT EXISTS idx_tasks_worker_type ON tasks(worker_type);
      `);
    } catch (err) {
      // Index might already exist or other issue
      if (!err.message.includes('already exists')) {
        console.error('Index creation warning:', err.message);
      }
    }
  }

  async add(task) {
    const stmt = this.db.prepare(`
      INSERT INTO tasks (type, worker_type, priority, payload)
      VALUES (?, ?, ?, ?)
    `);

    const result = stmt.run(
      task.type,
      task.workerType || 'salesforce',
      task.priority || 0,
      JSON.stringify(task.payload)
    );

    return result.lastInsertRowid;
  }

  async getNext(workerType = 'salesforce') {
    const stmt = this.db.prepare(`
      SELECT * FROM tasks
      WHERE status = 'pending' AND worker_type = ?
      ORDER BY priority DESC, created_at ASC
      LIMIT 1
    `);

    const task = stmt.get(workerType);
    if (!task) return null;

    // Mark as processing
    this.db.prepare(`
      UPDATE tasks
      SET status = 'processing', started_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(task.id);

    task.payload = JSON.parse(task.payload);
    return task;
  }

  async markComplete(taskId, result) {
    const stmt = this.db.prepare(`
      UPDATE tasks
      SET status = 'completed',
          completed_at = CURRENT_TIMESTAMP,
          result = ?
      WHERE id = ?
    `);

    stmt.run(JSON.stringify(result), taskId);
  }

  async markFailed(taskId, error) {
    const stmt = this.db.prepare(`
      UPDATE tasks
      SET status = 'failed',
          completed_at = CURRENT_TIMESTAMP,
          error = ?
      WHERE id = ?
    `);

    stmt.run(error.toString(), taskId);
  }

  async addDeployment(deployment) {
    const stmt = this.db.prepare(`
      INSERT INTO deployments (task_id, payload)
      VALUES (?, ?)
    `);

    stmt.run(deployment.taskId, JSON.stringify(deployment));
  }

  getQueueSize() {
    const result = this.db.prepare(
      "SELECT COUNT(*) as count FROM tasks WHERE status = 'pending'"
    ).get();
    return result.count;
  }

  getStats() {
    const stats = this.db.prepare(`
      SELECT status, COUNT(*) as count
      FROM tasks
      GROUP BY status
    `).all();

    return stats;
  }
}