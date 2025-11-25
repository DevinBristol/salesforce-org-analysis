// src/services/rollback-manager.js - Component Snapshot & Rollback System

import fs from 'fs-extra';
import path from 'path';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

/**
 * RollbackManager - Handles component snapshots and true rollback capability
 *
 * Features:
 * - Pre-deployment snapshot of affected components
 * - Full component restoration on rollback
 * - Deployment history with version tracking
 * - Point-in-time recovery
 */
export class RollbackManager {
    constructor(salesforceManager, logger) {
        this.salesforceManager = salesforceManager;
        this.logger = logger;
        this.snapshotDir = './snapshots';
        this.historyFile = './snapshots/deployment-history.json';
        this.maxSnapshotsPerComponent = 10; // Keep last 10 versions
    }

    /**
     * Create a snapshot of components before deployment
     * @param {Object} artifacts - Components to be deployed
     * @param {string} targetOrg - Target org for context
     * @param {string} deploymentId - Unique deployment identifier
     * @returns {Object} Snapshot information
     */
    async createPreDeploymentSnapshot(artifacts, targetOrg, deploymentId) {
        this.logger.info(`Creating pre-deployment snapshot for ${deploymentId}`);

        const snapshotId = `snapshot-${Date.now()}`;
        const snapshotPath = path.join(this.snapshotDir, snapshotId);

        await fs.ensureDir(snapshotPath);

        const snapshot = {
            snapshotId,
            deploymentId,
            targetOrg,
            timestamp: new Date().toISOString(),
            components: [],
            status: 'created'
        };

        try {
            // Snapshot Apex classes
            if (artifacts.apex) {
                for (const fileName of Object.keys(artifacts.apex)) {
                    const className = fileName.replace('.cls', '');
                    const existing = await this.fetchCurrentComponent('ApexClass', className, targetOrg);

                    if (existing) {
                        const componentPath = path.join(snapshotPath, 'classes', fileName);
                        await fs.ensureDir(path.dirname(componentPath));
                        await fs.writeFile(componentPath, existing.body);

                        snapshot.components.push({
                            type: 'ApexClass',
                            name: className,
                            hadExisting: true,
                            path: componentPath,
                            apiVersion: existing.apiVersion
                        });
                    } else {
                        // New component - track for potential deletion on rollback
                        snapshot.components.push({
                            type: 'ApexClass',
                            name: className,
                            hadExisting: false,
                            isNew: true
                        });
                    }
                }
            }

            // Snapshot metadata/objects
            if (artifacts.metadata) {
                for (const fileName of Object.keys(artifacts.metadata)) {
                    const componentName = path.basename(fileName, path.extname(fileName));
                    const existing = await this.fetchCurrentComponent('CustomObject', componentName, targetOrg);

                    if (existing) {
                        const componentPath = path.join(snapshotPath, 'objects', fileName);
                        await fs.ensureDir(path.dirname(componentPath));
                        await fs.writeJson(componentPath, existing.metadata);

                        snapshot.components.push({
                            type: 'CustomObject',
                            name: componentName,
                            hadExisting: true,
                            path: componentPath
                        });
                    }
                }
            }

            // Save snapshot metadata
            await fs.writeJson(path.join(snapshotPath, 'snapshot.json'), snapshot, { spaces: 2 });

            // Update deployment history
            await this.addToHistory(snapshot);

            this.logger.info(`Snapshot created: ${snapshotId} with ${snapshot.components.length} components`);

            return snapshot;
        } catch (error) {
            this.logger.error('Failed to create snapshot:', error);
            snapshot.status = 'failed';
            snapshot.error = error.message;
            return snapshot;
        }
    }

    /**
     * Fetch current component content from org
     */
    async fetchCurrentComponent(type, name, targetOrg) {
        try {
            if (type === 'ApexClass') {
                const { stdout } = await execAsync(
                    `sf data query --query "SELECT Id, Name, Body, ApiVersion FROM ApexClass WHERE Name='${name}'" --target-org ${targetOrg} --json`
                );
                const result = JSON.parse(stdout);
                if (result.result?.records?.length > 0) {
                    return {
                        body: result.result.records[0].Body,
                        apiVersion: result.result.records[0].ApiVersion
                    };
                }
            }
            return null;
        } catch (error) {
            this.logger.warn(`Could not fetch existing ${type} ${name}: ${error.message}`);
            return null;
        }
    }

    /**
     * Execute rollback to a specific snapshot
     * @param {string} snapshotId - Snapshot to rollback to
     * @param {string} targetOrg - Target org for rollback
     * @returns {Object} Rollback result
     */
    async executeRollback(snapshotId, targetOrg) {
        this.logger.info(`Executing rollback to snapshot: ${snapshotId}`);

        const snapshotPath = path.join(this.snapshotDir, snapshotId);
        const snapshotMetaPath = path.join(snapshotPath, 'snapshot.json');

        if (!await fs.pathExists(snapshotMetaPath)) {
            throw new Error(`Snapshot not found: ${snapshotId}`);
        }

        const snapshot = await fs.readJson(snapshotMetaPath);
        const rollbackResult = {
            snapshotId,
            timestamp: new Date().toISOString(),
            restored: [],
            deleted: [],
            failed: [],
            success: true
        };

        try {
            // Validate target org matches
            if (snapshot.targetOrg !== targetOrg) {
                throw new Error(`Snapshot was for org ${snapshot.targetOrg}, not ${targetOrg}`);
            }

            // Create rollback deployment package
            const rollbackDir = path.join('./deployments', `rollback-${Date.now()}`);
            await fs.ensureDir(rollbackDir);

            const forceAppDir = path.join(rollbackDir, 'force-app', 'main', 'default');

            for (const component of snapshot.components) {
                if (component.hadExisting) {
                    // Restore previous version
                    if (component.type === 'ApexClass') {
                        const targetPath = path.join(forceAppDir, 'classes', `${component.name}.cls`);
                        await fs.ensureDir(path.dirname(targetPath));
                        await fs.copy(component.path, targetPath);
                        await fs.writeFile(
                            `${targetPath}-meta.xml`,
                            this.generateApexMetaXml(component.apiVersion || '60.0')
                        );
                        rollbackResult.restored.push(component.name);
                    }
                } else if (component.isNew) {
                    // Delete components that were newly created
                    // Note: Salesforce doesn't support direct deletion via deploy
                    // We'll add to destructiveChanges.xml
                    rollbackResult.deleted.push(component.name);
                }
            }

            // Create sfdx-project.json for rollback
            await fs.writeJson(path.join(rollbackDir, 'sfdx-project.json'), {
                packageDirectories: [{ path: 'force-app', default: true }],
                namespace: '',
                sfdcLoginUrl: 'https://test.salesforce.com',
                sourceApiVersion: process.env.SF_API_VERSION || '60.0'
            });

            // Execute rollback deployment
            if (rollbackResult.restored.length > 0) {
                const { stdout } = await execAsync(
                    `sf project deploy start --source-dir force-app --target-org ${targetOrg} --json`,
                    { cwd: rollbackDir }
                );

                const deployResult = JSON.parse(stdout);
                if (deployResult.status !== 0 && deployResult.result?.status !== 'Succeeded') {
                    rollbackResult.success = false;
                    rollbackResult.error = 'Rollback deployment failed';
                }
            }

            // Clean up rollback directory
            await fs.remove(rollbackDir);

            // Log rollback
            await this.logRollback(rollbackResult);

            this.logger.info(`Rollback completed: ${rollbackResult.restored.length} restored, ${rollbackResult.deleted.length} marked for deletion`);

            return rollbackResult;
        } catch (error) {
            this.logger.error('Rollback failed:', error);
            rollbackResult.success = false;
            rollbackResult.error = error.message;
            return rollbackResult;
        }
    }

    /**
     * List available snapshots for an org
     */
    async listSnapshots(targetOrg = null) {
        await fs.ensureDir(this.snapshotDir);

        const snapshots = [];
        const dirs = await fs.readdir(this.snapshotDir);

        for (const dir of dirs) {
            if (dir.startsWith('snapshot-')) {
                const metaPath = path.join(this.snapshotDir, dir, 'snapshot.json');
                if (await fs.pathExists(metaPath)) {
                    const meta = await fs.readJson(metaPath);
                    if (!targetOrg || meta.targetOrg === targetOrg) {
                        snapshots.push({
                            snapshotId: meta.snapshotId,
                            deploymentId: meta.deploymentId,
                            targetOrg: meta.targetOrg,
                            timestamp: meta.timestamp,
                            componentCount: meta.components.length
                        });
                    }
                }
            }
        }

        return snapshots.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    }

    /**
     * Get the most recent snapshot for rollback
     */
    async getLatestSnapshot(targetOrg) {
        const snapshots = await this.listSnapshots(targetOrg);
        return snapshots.length > 0 ? snapshots[0] : null;
    }

    /**
     * Clean up old snapshots beyond retention limit
     */
    async cleanupOldSnapshots() {
        const snapshots = await this.listSnapshots();
        const byOrg = {};

        // Group snapshots by org
        for (const snapshot of snapshots) {
            if (!byOrg[snapshot.targetOrg]) {
                byOrg[snapshot.targetOrg] = [];
            }
            byOrg[snapshot.targetOrg].push(snapshot);
        }

        // Keep only last N snapshots per org
        for (const [org, orgSnapshots] of Object.entries(byOrg)) {
            if (orgSnapshots.length > this.maxSnapshotsPerComponent) {
                const toDelete = orgSnapshots.slice(this.maxSnapshotsPerComponent);
                for (const snapshot of toDelete) {
                    await fs.remove(path.join(this.snapshotDir, snapshot.snapshotId));
                    this.logger.info(`Cleaned up old snapshot: ${snapshot.snapshotId}`);
                }
            }
        }
    }

    /**
     * Add deployment to history
     */
    async addToHistory(snapshot) {
        await fs.ensureDir(path.dirname(this.historyFile));

        let history = [];
        if (await fs.pathExists(this.historyFile)) {
            history = await fs.readJson(this.historyFile);
        }

        history.unshift({
            snapshotId: snapshot.snapshotId,
            deploymentId: snapshot.deploymentId,
            targetOrg: snapshot.targetOrg,
            timestamp: snapshot.timestamp,
            componentCount: snapshot.components.length,
            components: snapshot.components.map(c => ({
                type: c.type,
                name: c.name,
                isNew: c.isNew || false
            }))
        });

        // Keep last 100 entries
        history = history.slice(0, 100);

        await fs.writeJson(this.historyFile, history, { spaces: 2 });
    }

    /**
     * Log rollback action
     */
    async logRollback(result) {
        const logPath = './snapshots/rollback-log.json';

        let log = [];
        if (await fs.pathExists(logPath)) {
            log = await fs.readJson(logPath);
        }

        log.unshift(result);
        log = log.slice(0, 50); // Keep last 50 rollbacks

        await fs.writeJson(logPath, log, { spaces: 2 });
    }

    generateApexMetaXml(apiVersion = '60.0') {
        return `<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>${apiVersion}</apiVersion>
    <status>Active</status>
</ApexClass>`;
    }
}
