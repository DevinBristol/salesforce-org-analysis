// src/services/deployment-pipeline.js - Automated Deployment Pipeline
// Enhanced with rollback support, strict safety, and pre-deployment validation

import fs from 'fs-extra';
import path from 'path';
import { exec } from 'child_process';
import { promisify } from 'util';
import { RollbackManager } from './rollback-manager.js';
import { QualityGate } from './quality-gate.js';

const execAsync = promisify(exec);

export class DeploymentPipeline {
    constructor(logger, salesforceManager = null) {
        this.logger = logger;
        this.salesforceManager = salesforceManager;
        this.deploymentHistory = [];
        this.rollbackManager = new RollbackManager(salesforceManager, logger);
        this.qualityGate = new QualityGate();

        // Quality gate enabled by default for code improvements
        this.QUALITY_GATE_ENABLED = process.env.QUALITY_GATE_ENABLED !== 'false';

        // Circuit breaker state
        this.circuitBreaker = {
            failures: 0,
            lastFailure: null,
            isOpen: false,
            threshold: 3,
            resetTimeout: 60000 // 1 minute
        };

        // Deployment windows (hours in 24h format, UTC)
        this.deploymentWindows = {
            enabled: process.env.DEPLOYMENT_WINDOWS_ENABLED === 'true',
            allowedHours: { start: 6, end: 22 }, // 6am - 10pm UTC
            blockedDays: [0, 6] // Sunday, Saturday
        };

        // SAFETY: Whitelist of allowed deployment targets (sandboxes only)
        this.SANDBOX_WHITELIST = [
            'dev-sandbox',
            'Devin1',
            'devin1',
            'test-sandbox',
            'uat-sandbox'
        ];

        // SAFETY: Blacklist of production org indicators - STRICT BLOCKING
        this.PRODUCTION_INDICATORS = [
            'production',
            'prod',
            'live',
            'main'
        ];

        // SAFETY: Strict mode - block ALL non-whitelisted orgs
        this.STRICT_MODE = process.env.DEPLOYMENT_STRICT_MODE !== 'false';
    }

    /**
     * SAFETY: Validates that target org is a sandbox (not production)
     * @param {string} targetOrg - Target org alias or username
     * @throws {Error} If target org appears to be production or is not whitelisted
     */
    validateSandboxTarget(targetOrg) {
        // Check if org is in whitelist
        if (this.SANDBOX_WHITELIST.includes(targetOrg)) {
            this.logger.info(`✓ SAFETY CHECK: ${targetOrg} is whitelisted sandbox`);
            return true;
        }

        // Check if org contains production indicators - ALWAYS BLOCK
        const orgLower = targetOrg.toLowerCase();
        for (const indicator of this.PRODUCTION_INDICATORS) {
            if (orgLower.includes(indicator)) {
                const error = `DEPLOYMENT BLOCKED: "${targetOrg}" appears to be a production org. Only sandbox deployments are allowed. Whitelisted sandboxes: ${this.SANDBOX_WHITELIST.join(', ')}`;
                this.logger.error(error);
                throw new Error(error);
            }
        }

        // STRICT MODE: Block ALL non-whitelisted orgs
        if (this.STRICT_MODE) {
            const error = `DEPLOYMENT BLOCKED (STRICT MODE): "${targetOrg}" is not in the sandbox whitelist. Add it to SANDBOX_WHITELIST or disable STRICT_MODE. Whitelisted: ${this.SANDBOX_WHITELIST.join(', ')}`;
            this.logger.error(error);
            throw new Error(error);
        }

        // Non-strict mode: warn but allow
        this.logger.warn(`⚠ WARNING: "${targetOrg}" is not in the sandbox whitelist. Proceeding with caution.`);
        this.logger.warn(`⚠ Enable STRICT_MODE to block non-whitelisted deployments.`);
        return true;
    }

    /**
     * Check if deployment is within allowed window
     */
    isWithinDeploymentWindow() {
        if (!this.deploymentWindows.enabled) return true;

        const now = new Date();
        const hour = now.getUTCHours();
        const day = now.getUTCDay();

        // Check blocked days
        if (this.deploymentWindows.blockedDays.includes(day)) {
            return false;
        }

        // Check allowed hours
        const { start, end } = this.deploymentWindows.allowedHours;
        return hour >= start && hour < end;
    }

    /**
     * Check circuit breaker state
     */
    checkCircuitBreaker() {
        if (!this.circuitBreaker.isOpen) return true;

        // Check if reset timeout has passed
        const timeSinceFailure = Date.now() - this.circuitBreaker.lastFailure;
        if (timeSinceFailure > this.circuitBreaker.resetTimeout) {
            this.circuitBreaker.isOpen = false;
            this.circuitBreaker.failures = 0;
            this.logger.info('Circuit breaker reset - resuming deployments');
            return true;
        }

        return false;
    }

    /**
     * Record failure for circuit breaker
     */
    recordFailure() {
        this.circuitBreaker.failures++;
        this.circuitBreaker.lastFailure = Date.now();

        if (this.circuitBreaker.failures >= this.circuitBreaker.threshold) {
            this.circuitBreaker.isOpen = true;
            this.logger.error(`Circuit breaker OPEN after ${this.circuitBreaker.failures} failures`);
        }
    }

    /**
     * Reset circuit breaker on success
     */
    recordSuccess() {
        this.circuitBreaker.failures = 0;
        this.circuitBreaker.isOpen = false;
    }

    async deployToSandbox(artifacts, targetOrg = 'Devin1', options = {}) {
        const deploymentId = `deploy-${Date.now()}`;
        const deploymentDir = path.join('./deployments', deploymentId);
        let snapshot = null;

        const {
            skipSnapshot = false,
            skipValidation = false,
            skipTests = false,
            force = false // Override deployment window checks
        } = options;

        try {
            // SAFETY CHECK 1: Circuit breaker
            if (!this.checkCircuitBreaker()) {
                throw new Error('Circuit breaker is OPEN - deployments temporarily blocked due to repeated failures');
            }

            // SAFETY CHECK 2: Deployment window
            if (!force && !this.isWithinDeploymentWindow()) {
                throw new Error('Deployment blocked: Outside allowed deployment window. Use force=true to override.');
            }

            // SAFETY CHECK 3: Validate target org is sandbox
            this.validateSandboxTarget(targetOrg);

            this.logger.info(`Starting deployment ${deploymentId} to ${targetOrg}`);

            // Step 1: Create snapshot for rollback capability
            if (!skipSnapshot) {
                this.logger.info('Creating pre-deployment snapshot...');
                snapshot = await this.rollbackManager.createPreDeploymentSnapshot(
                    artifacts,
                    targetOrg,
                    deploymentId
                );
                this.logger.info(`Snapshot created: ${snapshot.snapshotId}`);
            }

            // Step 2: Create deployment package
            await this.createDeploymentPackage(artifacts, deploymentDir);

            // Step 3: Pre-deployment validation with static analysis
            if (!skipValidation) {
                const validationResult = await this.validateDeployment(deploymentDir, targetOrg, artifacts);
                if (!validationResult.success) {
                    throw new Error(`Validation failed: ${validationResult.errors?.join(', ') || validationResult.error}`);
                }
            }

            // Step 4: Deploy to sandbox
            const deployResult = await this.executeDeploy(deploymentDir, targetOrg);

            // Step 5: Run post-deployment tests
            let testResults = null;
            if (!skipTests && deployResult.success) {
                this.logger.info('Running post-deployment tests...');
                testResults = await this.runPostDeploymentTests(targetOrg);

                // Auto-rollback on test failure if we have a snapshot
                if (!testResults.passed && snapshot && !skipSnapshot) {
                    this.logger.warn('Tests failed - initiating automatic rollback...');
                    const rollbackResult = await this.rollbackManager.executeRollback(
                        snapshot.snapshotId,
                        targetOrg
                    );
                    if (rollbackResult.success) {
                        this.logger.info('Automatic rollback completed');
                        return {
                            deployed: false,
                            deploymentId,
                            rolledBack: true,
                            rollbackReason: 'Post-deployment tests failed',
                            testResults,
                            details: deployResult
                        };
                    }
                }
            }

            // Step 6: Record deployment
            const record = {
                deploymentId,
                snapshotId: snapshot?.snapshotId,
                timestamp: new Date().toISOString(),
                targetOrg,
                success: deployResult.success,
                artifacts: Object.keys(artifacts.apex || {}).concat(Object.keys(artifacts.metadata || {})),
                testResults,
                details: deployResult
            };

            this.deploymentHistory.push(record);
            await this.saveDeploymentHistory();

            // Record success for circuit breaker
            if (deployResult.success) {
                this.recordSuccess();
                await fs.remove(deploymentDir);
            }

            return {
                deployed: deployResult.success,
                deploymentId,
                snapshotId: snapshot?.snapshotId,
                testResults,
                details: deployResult
            };

        } catch (error) {
            this.logger.error(`Deployment ${deploymentId} failed:`, error);

            // Record failure for circuit breaker
            this.recordFailure();

            // Keep failed deployment for debugging
            this.logger.info(`Failed deployment artifacts saved in ${deploymentDir}`);

            return {
                deployed: false,
                deploymentId,
                snapshotId: snapshot?.snapshotId,
                error: error.message
            };
        }
    }

    /**
     * Execute rollback to previous state
     */
    async rollbackToPrevious(targetOrg) {
        const latestSnapshot = await this.rollbackManager.getLatestSnapshot(targetOrg);
        if (!latestSnapshot) {
            throw new Error('No snapshot available for rollback');
        }
        return await this.rollbackManager.executeRollback(latestSnapshot.snapshotId, targetOrg);
    }

    /**
     * Execute rollback to specific snapshot
     */
    async rollbackToSnapshot(snapshotId, targetOrg) {
        return await this.rollbackManager.executeRollback(snapshotId, targetOrg);
    }

    /**
     * Deploy code improvement with Claude CLI quality gate review
     *
     * This is the recommended method for deploying AI-generated improvements.
     * The quality gate reviews the proposed changes and can simplify/reject them.
     *
     * @param {Object} improvement - The improvement proposal
     * @param {string} improvement.className - Name of the Apex class
     * @param {string} improvement.originalCode - Original source code
     * @param {string} improvement.improvedCode - Agent-generated improved code
     * @param {string[]} improvement.improvements - List of improvements made
     * @param {Object} improvement.metadata - Additional context
     * @param {string} targetOrg - Target org alias (default: Devin1)
     * @param {Object} options - Deployment options
     * @returns {Promise<Object>} Deployment result with quality gate review
     */
    async deployWithQualityGate(improvement, targetOrg = 'Devin1', options = {}) {
        const { className, originalCode, improvedCode, improvements, metadata } = improvement;

        this.logger.info(`=== Quality Gate Deployment: ${className} ===`);

        // Step 1: Quality Gate Review
        if (this.QUALITY_GATE_ENABLED && !options.skipQualityGate) {
            this.logger.info('Submitting to Claude CLI quality gate for review...');

            const review = await this.qualityGate.review({
                className,
                originalCode,
                improvedCode,
                improvements,
                metadata
            });

            if (!review.approved) {
                this.logger.warn(`Quality gate REJECTED ${className}: ${review.reason}`);
                return {
                    deployed: false,
                    qualityGate: review,
                    reason: review.reason,
                    stage: 'quality-gate'
                };
            }

            this.logger.info(`Quality gate APPROVED ${className}: ${review.reason}`);

            // Use the simplified/cleaned code from quality gate
            if (review.finalCode) {
                this.logger.info('Using quality gate refined code');
                improvement.improvedCode = review.finalCode;
                improvement.qualityGateChanges = review.changes || [];
            }
        } else {
            this.logger.info('Quality gate skipped (disabled or bypassed)');
        }

        // Step 2: Prepare deployment artifacts with the (potentially refined) code
        const artifacts = await this.prepareDeploymentArtifacts([{
            className,
            code: improvement.improvedCode,
            type: 'ApexClass'
        }]);

        // Step 3: Deploy to sandbox
        const deployResult = await this.deployToSandbox(artifacts, targetOrg, options);

        return {
            ...deployResult,
            qualityGate: this.QUALITY_GATE_ENABLED ? 'approved' : 'skipped',
            className
        };
    }

    /**
     * Batch deploy multiple improvements with quality gate
     */
    async deployBatchWithQualityGate(improvements, targetOrg = 'Devin1', options = {}) {
        const results = {
            total: improvements.length,
            approved: 0,
            rejected: 0,
            deployed: 0,
            failed: 0,
            details: []
        };

        for (const improvement of improvements) {
            const result = await this.deployWithQualityGate(improvement, targetOrg, options);

            if (result.qualityGate === 'approved' || result.qualityGate === 'skipped') {
                results.approved++;
                if (result.deployed) {
                    results.deployed++;
                } else {
                    results.failed++;
                }
            } else {
                results.rejected++;
            }

            results.details.push({
                className: improvement.className,
                ...result
            });
        }

        this.logger.info(`Batch deployment complete: ${results.deployed}/${results.total} deployed, ${results.rejected} rejected by quality gate`);

        return results;
    }

    /**
     * Prepare deployment artifacts from code objects
     */
    async prepareDeploymentArtifacts(codeItems) {
        const artifacts = {
            classes: [],
            triggers: [],
            components: []
        };

        for (const item of codeItems) {
            if (item.type === 'ApexClass') {
                artifacts.classes.push({
                    name: item.className,
                    body: item.code,
                    apiVersion: '64.0'
                });
            }
        }

        return artifacts;
    }

    /**
     * List available snapshots
     */
    async listSnapshots(targetOrg = null) {
        return await this.rollbackManager.listSnapshots(targetOrg);
    }

    async createDeploymentPackage(artifacts, deploymentDir) {
        await fs.ensureDir(deploymentDir);
        
        // Create proper Salesforce DX project structure
        const projectJson = {
            packageDirectories: [
                {
                    path: 'force-app',
                    default: true
                }
            ],
            namespace: '',
            sfdcLoginUrl: 'https://test.salesforce.com',
            sourceApiVersion: process.env.SF_API_VERSION || '60.0'
        };
        
        await fs.writeJson(path.join(deploymentDir, 'sfdx-project.json'), projectJson, { spaces: 2 });
        
        // Create force-app directory structure
        const forceAppDir = path.join(deploymentDir, 'force-app', 'main', 'default');
        
        // Deploy Apex classes
        if (artifacts.apex && Object.keys(artifacts.apex).length > 0) {
            const classesDir = path.join(forceAppDir, 'classes');
            await fs.ensureDir(classesDir);
            
            for (const [fileName, content] of Object.entries(artifacts.apex)) {
                await fs.writeFile(path.join(classesDir, fileName), content);
                
                // Create meta-xml file
                const metaXml = this.generateApexMetaXml();
                await fs.writeFile(path.join(classesDir, `${fileName}-meta.xml`), metaXml);
            }
        }
        
        // Deploy custom objects/fields
        if (artifacts.metadata && Object.keys(artifacts.metadata).length > 0) {
            const objectsDir = path.join(forceAppDir, 'objects');
            await fs.ensureDir(objectsDir);
            
            for (const [fileName, content] of Object.entries(artifacts.metadata)) {
                // Determine the correct subdirectory based on metadata type
                const metadataType = this.getMetadataType(fileName);
                const targetDir = path.join(forceAppDir, metadataType);
                await fs.ensureDir(targetDir);
                await fs.writeFile(path.join(targetDir, fileName), content);
            }
        }
        
        this.logger.info(`Deployment package created in ${deploymentDir}`);
    }

    generateApexMetaXml() {
        return `<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>${process.env.SF_API_VERSION || '60.0'}</apiVersion>
    <status>Active</status>
</ApexClass>`;
    }

    getMetadataType(fileName) {
        if (fileName.includes('.object')) return 'objects';
        if (fileName.includes('.field')) return 'fields';
        if (fileName.includes('.flow')) return 'flows';
        if (fileName.includes('.permissionset')) return 'permissionsets';
        return 'objects'; // default
    }

    async validateDeployment(deploymentDir, targetOrg, artifacts = {}) {
        const errors = [];
        const warnings = [];

        try {
            this.logger.info('Running pre-deployment validation...');

            // 1. Static Analysis of Apex code
            if (artifacts.apex) {
                for (const [fileName, content] of Object.entries(artifacts.apex)) {
                    const analysisResult = this.analyzeApexCode(content, fileName);
                    errors.push(...analysisResult.errors);
                    warnings.push(...analysisResult.warnings);
                }
            }

            // 2. Security Scanning
            const securityIssues = this.scanForSecurityIssues(artifacts);
            errors.push(...securityIssues.critical);
            warnings.push(...securityIssues.warnings);

            // 3. Governor Limit Risk Analysis
            const governorRisks = this.analyzeGovernorLimitRisks(artifacts);
            warnings.push(...governorRisks);

            // 4. Run Salesforce CLI validation (check-only deploy)
            try {
                const { stdout } = await execAsync(
                    `sf project deploy validate --source-dir force-app --target-org ${targetOrg} --json`,
                    { cwd: deploymentDir, timeout: 120000 }
                );
                const result = JSON.parse(stdout);
                if (result.status !== 0 && result.result?.status !== 'Succeeded') {
                    errors.push(`Salesforce validation failed: ${result.result?.message || result.message}`);
                }
            } catch (sfError) {
                // Parse SF CLI error response
                try {
                    const errorResult = JSON.parse(sfError.stdout || '{}');
                    if (errorResult.result?.details?.componentFailures) {
                        for (const failure of errorResult.result.details.componentFailures) {
                            errors.push(`${failure.componentType} ${failure.fullName}: ${failure.problem}`);
                        }
                    } else {
                        errors.push(`SF validation error: ${sfError.message}`);
                    }
                } catch {
                    errors.push(`SF validation error: ${sfError.message}`);
                }
            }

            // Log warnings
            for (const warning of warnings) {
                this.logger.warn(`Validation warning: ${warning}`);
            }

            // Return results
            if (errors.length > 0) {
                this.logger.error(`Validation failed with ${errors.length} errors`);
                return { success: false, errors, warnings };
            }

            this.logger.info('Validation passed');
            return { success: true, warnings, details: { message: 'All validations passed' } };

        } catch (error) {
            return { success: false, errors: [error.message], warnings };
        }
    }

    /**
     * Static analysis of Apex code
     */
    analyzeApexCode(code, fileName) {
        const errors = [];
        const warnings = [];

        // Check for SOQL in loops
        const soqlInLoopPattern = /for\s*\([^)]*\)\s*\{[^}]*\[SELECT/gi;
        if (soqlInLoopPattern.test(code)) {
            errors.push(`${fileName}: SOQL query inside loop detected - will hit governor limits`);
        }

        // Check for DML in loops
        const dmlInLoopPattern = /for\s*\([^)]*\)\s*\{[^}]*(insert|update|delete|upsert)\s+/gi;
        if (dmlInLoopPattern.test(code)) {
            errors.push(`${fileName}: DML operation inside loop detected - will hit governor limits`);
        }

        // Check for hardcoded IDs
        const hardcodedIdPattern = /['"][a-zA-Z0-9]{15,18}['"]/g;
        if (hardcodedIdPattern.test(code)) {
            warnings.push(`${fileName}: Hardcoded Salesforce ID detected - use Custom Metadata instead`);
        }

        // Check for System.debug in non-test classes
        if (!fileName.toLowerCase().includes('test') && code.includes('System.debug')) {
            const debugCount = (code.match(/System\.debug/g) || []).length;
            if (debugCount > 10) {
                warnings.push(`${fileName}: Excessive debug statements (${debugCount}) may impact performance`);
            }
        }

        // Check for missing null checks before SOQL
        if (code.includes('[SELECT') && !code.includes('!= null')) {
            warnings.push(`${fileName}: Consider adding null checks before SOQL queries`);
        }

        return { errors, warnings };
    }

    /**
     * Security vulnerability scanning
     */
    scanForSecurityIssues(artifacts) {
        const critical = [];
        const warnings = [];

        if (artifacts.apex) {
            for (const [fileName, code] of Object.entries(artifacts.apex)) {
                const codeLower = code.toLowerCase();

                // CRITICAL: Hardcoded credentials
                if (/password\s*=\s*['"]/.test(codeLower) ||
                    /api[_-]?key\s*=\s*['"]/.test(codeLower) ||
                    /secret\s*=\s*['"]/.test(codeLower)) {
                    critical.push(`${fileName}: SECURITY - Potential hardcoded credentials detected`);
                }

                // CRITICAL: SOQL Injection risk
                if (codeLower.includes('database.query(') &&
                    code.includes('+') &&
                    !codeLower.includes('escapesinglequotes')) {
                    critical.push(`${fileName}: SECURITY - Potential SOQL injection vulnerability`);
                }

                // Warning: Sensitive data in debug
                if (codeLower.includes('system.debug') &&
                    (codeLower.includes('password') || codeLower.includes('token'))) {
                    warnings.push(`${fileName}: SECURITY - Potentially logging sensitive data`);
                }

                // Warning: Missing sharing declaration
                if ((fileName.toLowerCase().includes('controller') ||
                     fileName.toLowerCase().includes('service')) &&
                    !codeLower.includes('with sharing') &&
                    !codeLower.includes('without sharing') &&
                    !codeLower.includes('inherited sharing')) {
                    warnings.push(`${fileName}: Missing sharing keyword - defaults to without sharing`);
                }
            }
        }

        return { critical, warnings };
    }

    /**
     * Analyze potential governor limit issues
     */
    analyzeGovernorLimitRisks(artifacts) {
        const warnings = [];

        if (artifacts.apex) {
            for (const [fileName, code] of Object.entries(artifacts.apex)) {
                // Count SOQL queries
                const soqlCount = (code.match(/\[SELECT/g) || []).length;
                if (soqlCount > 50) {
                    warnings.push(`${fileName}: High SOQL count (${soqlCount}) - risk of hitting 100 query limit`);
                }

                // Check for recursive trigger risk
                if (fileName.toLowerCase().includes('trigger') ||
                    fileName.toLowerCase().includes('handler')) {
                    if (!code.includes('recursion') && !code.includes('alreadyRun')) {
                        warnings.push(`${fileName}: Consider adding recursion prevention for trigger handler`);
                    }
                }

                // Check for large collection operations
                if (code.includes('for (') && code.includes('.size()')) {
                    warnings.push(`${fileName}: Consider adding collection size checks to prevent CPU time limit`);
                }
            }
        }

        return warnings;
    }

    async executeDeploy(deploymentDir, targetOrg) {
        try {
            this.logger.info(`Deploying to ${targetOrg}...`);

            // For sandbox deployments, skip all tests
            // For production, run local tests
            const testLevel = targetOrg.includes('sandbox') || targetOrg.includes('dev-') || targetOrg.includes('Devin')
                ? '' // No test level = no tests run in sandbox
                : '--test-level RunLocalTests';

            const { stdout, stderr } = await execAsync(
                `sf project deploy start --source-dir force-app --target-org ${targetOrg} ${testLevel} --json`,
                { cwd: deploymentDir }
            );

            // Parse stdout even if stderr has warnings
            const result = JSON.parse(stdout);

            this.logger.info(`Deployment status: ${result.result?.status || result.status}`);

            return {
                success: result.status === 0 || result.result?.status === 'Succeeded',
                id: result.result?.id,
                status: result.result?.status || result.status,
                details: result.result || result
            };
        } catch (error) {
            this.logger.error('Deployment execution failed:', error);
            try {
                const errorResult = JSON.parse(error.stdout || error.message);
                return {
                    success: false,
                    error: errorResult.message || error.message,
                    details: errorResult
                };
            } catch {
                return { success: false, error: error.message };
            }
        }
    }

    async runPostDeploymentTests(targetOrg) {
        try {
            this.logger.info('Running post-deployment tests...');
            
            const { stdout } = await execAsync(
                `sf apex run test --code-coverage --result-format json --target-org ${targetOrg} --wait 10`
            );
            
            const result = JSON.parse(stdout);
            
            const summary = {
                passed: result.result.summary.outcome === 'Passed',
                testsRun: result.result.summary.testsRan,
                testsPassed: result.result.summary.passing,
                coverage: result.result.summary.testRunCoverage,
                time: result.result.summary.testExecutionTime
            };
            
            this.logger.info(`Tests: ${summary.testsPassed}/${summary.testsRun} passed, Coverage: ${summary.coverage}%`);
            
            return summary;
        } catch (error) {
            this.logger.error('Test execution failed:', error);
            return {
                passed: false,
                error: error.message
            };
        }
    }

    async saveDeploymentHistory() {
        await fs.ensureDir('./deployments');
        await fs.writeJson(
            './deployments/history.json',
            this.deploymentHistory,
            { spaces: 2 }
        );
    }

    async rollback(deploymentId, targetOrg) {
        try {
            this.logger.info(`Rolling back deployment ${deploymentId}`);
            
            // Find the deployment record
            const deployment = this.deploymentHistory.find(d => d.deploymentId === deploymentId);
            if (!deployment) {
                throw new Error('Deployment not found');
            }
            
            // Use Salesforce CLI to rollback
            const { stdout } = await execAsync(
                `sf project deploy cancel --job-id ${deployment.details.id} --target-org ${targetOrg} --json`
            );
            
            const result = JSON.parse(stdout);
            
            return {
                success: true,
                details: result
            };
        } catch (error) {
            this.logger.error('Rollback failed:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }
}
