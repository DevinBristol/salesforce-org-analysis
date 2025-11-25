/**
 * Database Migration Script for Phase 4
 *
 * Creates all necessary tables for Phase 4 functionality.
 * Run this script before starting the Phase 4 system.
 */

import pg from 'pg';
const { Pool } = pg;

const migrations = [
    {
        version: '4.0.0',
        name: 'create_conversations_table',
        up: `
            CREATE TABLE IF NOT EXISTS conversations (
                id VARCHAR(255) PRIMARY KEY,
                user_id VARCHAR(255),
                channel_id VARCHAR(255),
                thread_id VARCHAR(255),
                task_type VARCHAR(100),
                summary TEXT,
                context JSONB DEFAULT '{}',
                state JSONB DEFAULT '{}',
                metrics JSONB DEFAULT '{}',
                status VARCHAR(50) DEFAULT 'active',
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            );

            CREATE INDEX IF NOT EXISTS idx_conversations_user ON conversations(user_id);
            CREATE INDEX IF NOT EXISTS idx_conversations_status ON conversations(status);
            CREATE INDEX IF NOT EXISTS idx_conversations_created ON conversations(created_at);
        `,
        down: `DROP TABLE IF EXISTS conversations;`
    },
    {
        version: '4.0.1',
        name: 'create_conversation_messages_table',
        up: `
            CREATE TABLE IF NOT EXISTS conversation_messages (
                id VARCHAR(255) PRIMARY KEY,
                conversation_id VARCHAR(255) REFERENCES conversations(id) ON DELETE CASCADE,
                role VARCHAR(50) NOT NULL,
                content TEXT NOT NULL,
                tokens INTEGER DEFAULT 0,
                metadata JSONB DEFAULT '{}',
                created_at TIMESTAMP DEFAULT NOW()
            );

            CREATE INDEX IF NOT EXISTS idx_messages_conversation ON conversation_messages(conversation_id);
            CREATE INDEX IF NOT EXISTS idx_messages_created ON conversation_messages(created_at);
        `,
        down: `DROP TABLE IF EXISTS conversation_messages;`
    },
    {
        version: '4.0.2',
        name: 'create_user_memories_table',
        up: `
            CREATE TABLE IF NOT EXISTS user_memories (
                id SERIAL PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                type VARCHAR(100) NOT NULL,
                content TEXT NOT NULL,
                task_type VARCHAR(100),
                conversation_id VARCHAR(255),
                relevance_score DECIMAL(5,4) DEFAULT 1.0,
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            );

            CREATE INDEX IF NOT EXISTS idx_memories_user ON user_memories(user_id);
            CREATE INDEX IF NOT EXISTS idx_memories_task_type ON user_memories(task_type);
            CREATE INDEX IF NOT EXISTS idx_memories_relevance ON user_memories(relevance_score DESC);
        `,
        down: `DROP TABLE IF EXISTS user_memories;`
    },
    {
        version: '4.0.3',
        name: 'create_task_callbacks_table',
        up: `
            CREATE TABLE IF NOT EXISTS task_callbacks (
                task_id VARCHAR(255) PRIMARY KEY,
                callback_type VARCHAR(50) NOT NULL,
                config JSONB NOT NULL,
                status VARCHAR(50) DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            );

            CREATE INDEX IF NOT EXISTS idx_callbacks_status ON task_callbacks(status);
        `,
        down: `DROP TABLE IF EXISTS task_callbacks;`
    },
    {
        version: '4.0.4',
        name: 'create_task_results_table',
        up: `
            CREATE TABLE IF NOT EXISTS task_results (
                task_id VARCHAR(255) PRIMARY KEY,
                result JSONB NOT NULL,
                success BOOLEAN DEFAULT false,
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            );

            CREATE INDEX IF NOT EXISTS idx_results_success ON task_results(success);
            CREATE INDEX IF NOT EXISTS idx_results_created ON task_results(created_at);
        `,
        down: `DROP TABLE IF EXISTS task_results;`
    },
    {
        version: '4.0.5',
        name: 'create_workflows_table',
        up: `
            CREATE TABLE IF NOT EXISTS workflows (
                id VARCHAR(255) PRIMARY KEY,
                template_id VARCHAR(255) NOT NULL,
                name VARCHAR(255) NOT NULL,
                status VARCHAR(50) DEFAULT 'running',
                context JSONB DEFAULT '{}',
                step_results JSONB DEFAULT '{}',
                started_at TIMESTAMP,
                completed_at TIMESTAMP,
                error TEXT,
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            );

            CREATE INDEX IF NOT EXISTS idx_workflows_status ON workflows(status);
            CREATE INDEX IF NOT EXISTS idx_workflows_template ON workflows(template_id);
            CREATE INDEX IF NOT EXISTS idx_workflows_started ON workflows(started_at);
        `,
        down: `DROP TABLE IF EXISTS workflows;`
    },
    {
        version: '4.0.6',
        name: 'create_monitoring_tables',
        up: `
            CREATE TABLE IF NOT EXISTS monitoring_metrics (
                id SERIAL PRIMARY KEY,
                timestamp TIMESTAMP DEFAULT NOW(),
                metrics JSONB NOT NULL,
                time_series JSONB DEFAULT '{}'
            );

            CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON monitoring_metrics(timestamp);

            CREATE TABLE IF NOT EXISTS monitoring_alerts (
                id SERIAL PRIMARY KEY,
                title VARCHAR(255) NOT NULL,
                severity VARCHAR(50) NOT NULL,
                data JSONB DEFAULT '{}',
                acknowledged BOOLEAN DEFAULT false,
                acknowledged_by VARCHAR(255),
                acknowledged_at TIMESTAMP,
                created_at TIMESTAMP DEFAULT NOW()
            );

            CREATE INDEX IF NOT EXISTS idx_alerts_severity ON monitoring_alerts(severity);
            CREATE INDEX IF NOT EXISTS idx_alerts_acknowledged ON monitoring_alerts(acknowledged);
            CREATE INDEX IF NOT EXISTS idx_alerts_created ON monitoring_alerts(created_at);
        `,
        down: `
            DROP TABLE IF EXISTS monitoring_alerts;
            DROP TABLE IF EXISTS monitoring_metrics;
        `
    },
    {
        version: '4.0.7',
        name: 'create_autonomous_tasks_table',
        up: `
            CREATE TABLE IF NOT EXISTS autonomous_tasks (
                id VARCHAR(255) PRIMARY KEY,
                type VARCHAR(100) NOT NULL,
                prompt TEXT NOT NULL,
                context JSONB DEFAULT '{}',
                priority VARCHAR(50) DEFAULT 'normal',
                status VARCHAR(50) DEFAULT 'pending',
                retries INTEGER DEFAULT 0,
                workspace VARCHAR(500),
                result JSONB,
                error TEXT,
                submitted_at TIMESTAMP DEFAULT NOW(),
                started_at TIMESTAMP,
                completed_at TIMESTAMP,
                duration INTEGER
            );

            CREATE INDEX IF NOT EXISTS idx_tasks_status ON autonomous_tasks(status);
            CREATE INDEX IF NOT EXISTS idx_tasks_type ON autonomous_tasks(type);
            CREATE INDEX IF NOT EXISTS idx_tasks_priority ON autonomous_tasks(priority);
            CREATE INDEX IF NOT EXISTS idx_tasks_submitted ON autonomous_tasks(submitted_at);
        `,
        down: `DROP TABLE IF EXISTS autonomous_tasks;`
    },
    {
        version: '4.0.8',
        name: 'create_scheduled_jobs_table',
        up: `
            CREATE TABLE IF NOT EXISTS scheduled_jobs (
                id VARCHAR(255) PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                cron_expression VARCHAR(100) NOT NULL,
                job_type VARCHAR(100) NOT NULL,
                config JSONB DEFAULT '{}',
                enabled BOOLEAN DEFAULT true,
                last_run TIMESTAMP,
                next_run TIMESTAMP,
                run_count INTEGER DEFAULT 0,
                last_error TEXT,
                created_at TIMESTAMP DEFAULT NOW(),
                updated_at TIMESTAMP DEFAULT NOW()
            );

            CREATE INDEX IF NOT EXISTS idx_jobs_enabled ON scheduled_jobs(enabled);
            CREATE INDEX IF NOT EXISTS idx_jobs_next_run ON scheduled_jobs(next_run);
        `,
        down: `DROP TABLE IF EXISTS scheduled_jobs;`
    },
    {
        version: '4.0.9',
        name: 'create_audit_log_table',
        up: `
            CREATE TABLE IF NOT EXISTS audit_log (
                id SERIAL PRIMARY KEY,
                event_type VARCHAR(100) NOT NULL,
                user_id VARCHAR(255),
                resource_type VARCHAR(100),
                resource_id VARCHAR(255),
                action VARCHAR(100) NOT NULL,
                details JSONB DEFAULT '{}',
                ip_address VARCHAR(50),
                user_agent TEXT,
                created_at TIMESTAMP DEFAULT NOW()
            );

            CREATE INDEX IF NOT EXISTS idx_audit_event_type ON audit_log(event_type);
            CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_id);
            CREATE INDEX IF NOT EXISTS idx_audit_resource ON audit_log(resource_type, resource_id);
            CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_log(created_at);
        `,
        down: `DROP TABLE IF EXISTS audit_log;`
    },
    {
        version: '4.0.10',
        name: 'create_migrations_tracking_table',
        up: `
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version VARCHAR(50) PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                applied_at TIMESTAMP DEFAULT NOW()
            );
        `,
        down: `DROP TABLE IF EXISTS schema_migrations;`
    }
];

class Phase4Migration {
    constructor(config) {
        this.pool = new Pool({
            connectionString: config.databaseUrl,
            ssl: config.ssl ? { rejectUnauthorized: false } : false
        });
        this.logger = config.logger || console;
    }

    async runMigrations() {
        this.logger.info('[Migration] Starting Phase 4 database migrations...');

        const client = await this.pool.connect();

        try {
            // Ensure migrations table exists
            await client.query(migrations.find(m => m.name === 'create_migrations_tracking_table').up);

            // Get applied migrations
            const appliedResult = await client.query('SELECT version FROM schema_migrations');
            const appliedVersions = new Set(appliedResult.rows.map(r => r.version));

            let migrationsRun = 0;

            for (const migration of migrations) {
                if (appliedVersions.has(migration.version)) {
                    this.logger.info(`[Migration] Skipping ${migration.version} (${migration.name}) - already applied`);
                    continue;
                }

                this.logger.info(`[Migration] Running ${migration.version}: ${migration.name}`);

                await client.query('BEGIN');

                try {
                    // Run migration
                    await client.query(migration.up);

                    // Record migration
                    await client.query(
                        'INSERT INTO schema_migrations (version, name) VALUES ($1, $2)',
                        [migration.version, migration.name]
                    );

                    await client.query('COMMIT');
                    migrationsRun++;

                    this.logger.info(`[Migration] Completed ${migration.version}`);

                } catch (error) {
                    await client.query('ROLLBACK');
                    throw new Error(`Migration ${migration.version} failed: ${error.message}`);
                }
            }

            this.logger.info(`[Migration] Completed. ${migrationsRun} migrations applied.`);
            return { success: true, migrationsRun };

        } finally {
            client.release();
        }
    }

    async rollback(targetVersion = null) {
        this.logger.info('[Migration] Starting rollback...');

        const client = await this.pool.connect();

        try {
            // Get applied migrations in reverse order
            const appliedResult = await client.query(
                'SELECT version, name FROM schema_migrations ORDER BY applied_at DESC'
            );

            let rolledBack = 0;

            for (const row of appliedResult.rows) {
                if (targetVersion && row.version === targetVersion) {
                    break;
                }

                const migration = migrations.find(m => m.version === row.version);
                if (!migration) {
                    this.logger.warn(`[Migration] No rollback found for ${row.version}`);
                    continue;
                }

                this.logger.info(`[Migration] Rolling back ${row.version}: ${row.name}`);

                await client.query('BEGIN');

                try {
                    await client.query(migration.down);
                    await client.query('DELETE FROM schema_migrations WHERE version = $1', [row.version]);
                    await client.query('COMMIT');
                    rolledBack++;

                    this.logger.info(`[Migration] Rolled back ${row.version}`);

                } catch (error) {
                    await client.query('ROLLBACK');
                    throw new Error(`Rollback ${row.version} failed: ${error.message}`);
                }

                if (!targetVersion) {
                    // Only rollback one migration if no target specified
                    break;
                }
            }

            this.logger.info(`[Migration] Rollback completed. ${rolledBack} migrations rolled back.`);
            return { success: true, rolledBack };

        } finally {
            client.release();
        }
    }

    async getStatus() {
        const client = await this.pool.connect();

        try {
            // Check if migrations table exists
            const tableCheck = await client.query(`
                SELECT EXISTS (
                    SELECT FROM information_schema.tables
                    WHERE table_name = 'schema_migrations'
                )
            `);

            if (!tableCheck.rows[0].exists) {
                return {
                    initialized: false,
                    applied: [],
                    pending: migrations.map(m => ({ version: m.version, name: m.name }))
                };
            }

            const appliedResult = await client.query(
                'SELECT version, name, applied_at FROM schema_migrations ORDER BY applied_at'
            );

            const appliedVersions = new Set(appliedResult.rows.map(r => r.version));
            const pending = migrations
                .filter(m => !appliedVersions.has(m.version))
                .map(m => ({ version: m.version, name: m.name }));

            return {
                initialized: true,
                applied: appliedResult.rows,
                pending
            };

        } finally {
            client.release();
        }
    }

    async close() {
        await this.pool.end();
    }
}

// CLI interface
async function main() {
    // Load dotenv
    const dotenv = await import('dotenv');
    dotenv.config();

    const command = process.argv[2];

    const databaseUrl = process.env.DATABASE_URL;

    if (!databaseUrl || databaseUrl.includes('user:pass')) {
        console.log('\n⚠️  No valid DATABASE_URL configured.');
        console.log('Phase 4 can run without a database (with reduced persistence).\n');
        console.log('To enable full persistence, set DATABASE_URL in your .env file:');
        console.log('  DATABASE_URL=postgresql://username:password@localhost:5432/salesforce_dev\n');
        console.log('Migration Status: Skipped (no database configured)\n');
        return;
    }

    const config = {
        databaseUrl,
        ssl: process.env.DATABASE_SSL === 'true'
    };

    const migration = new Phase4Migration(config);

    try {
        switch (command) {
            case 'up':
                await migration.runMigrations();
                break;

            case 'down':
                const targetVersion = process.argv[3];
                await migration.rollback(targetVersion);
                break;

            case 'status':
                const status = await migration.getStatus();
                console.log('\nMigration Status:');
                console.log('==================');
                console.log(`Initialized: ${status.initialized}`);
                console.log(`\nApplied (${status.applied.length}):`);
                for (const m of status.applied) {
                    console.log(`  ✓ ${m.version} - ${m.name} (${new Date(m.applied_at).toLocaleString()})`);
                }
                console.log(`\nPending (${status.pending.length}):`);
                for (const m of status.pending) {
                    console.log(`  ○ ${m.version} - ${m.name}`);
                }
                break;

            default:
                console.log('Usage: node migrate-phase4.js [up|down|status]');
                console.log('');
                console.log('Commands:');
                console.log('  up              Run all pending migrations');
                console.log('  down [version]  Rollback to specified version (or last migration)');
                console.log('  status          Show migration status');
        }

    } catch (error) {
        console.error('Migration error:', error.message);
        process.exit(1);

    } finally {
        await migration.close();
    }
}

// Export for programmatic use
export { Phase4Migration, migrations };

// Run if called directly - check if this file is the entry point
const scriptPath = process.argv[1];
if (scriptPath && (scriptPath.endsWith('migrate-phase4.js') || scriptPath.includes('migrate-phase4'))) {
    main().catch(err => {
        console.error('Migration error:', err.message);
        process.exit(1);
    });
}
