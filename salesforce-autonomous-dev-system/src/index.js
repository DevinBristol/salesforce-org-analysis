// src/index.js - Main Autonomous Development Orchestrator

import express from 'express';
import dotenv from 'dotenv';
import { Anthropic } from '@anthropic-ai/sdk';
import jsforce from 'jsforce';
import winston from 'winston';
import { SalesforceManager } from './services/salesforce-manager.js';
import { AICodeGenerator } from './services/ai-code-generator.js';
import { DeploymentPipeline } from './services/deployment-pipeline.js';
import { DeploymentScheduler } from './services/deployment-scheduler.js';
import { TaskAnalyzer } from './services/task-analyzer.js';
import { OrgAnalyzer } from './services/org-analyzer.js';
import { AgentOrchestrator } from './agents/agent-orchestrator.js';
import fs from 'fs-extra';

// Load environment variables
dotenv.config();

// Configure logging
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
        new winston.transports.File({ filename: 'logs/system.log' }),
        new winston.transports.Console({
            format: winston.format.simple()
        })
    ]
});

// Initialize services
const anthropic = new Anthropic({
    apiKey: process.env.ANTHROPIC_API_KEY,
    timeout: 120000, // 120 seconds
    maxRetries: 3
});

class AutonomousDevelopmentSystem {
    constructor() {
        this.salesforceManager = new SalesforceManager(logger);
        this.aiCodeGenerator = new AICodeGenerator(anthropic, logger);
        // Pass salesforceManager to AI generator for context-aware refactoring
        this.aiCodeGenerator.setSalesforceManager(this.salesforceManager);
        // Pass salesforceManager to enable rollback snapshots
        this.deploymentPipeline = new DeploymentPipeline(logger, this.salesforceManager);
        // Initialize scheduler with notification callback
        this.deploymentScheduler = new DeploymentScheduler(
            this.deploymentPipeline,
            logger,
            (notification) => this.handleSchedulerNotification(notification)
        );
        this.taskAnalyzer = new TaskAnalyzer(anthropic, logger);
        this.orgAnalyzer = new OrgAnalyzer(logger);

        // NEW: Initialize the upgraded multi-agent orchestrator
        this.agentOrchestrator = new AgentOrchestrator({
            anthropic,
            logger,
            salesforceManager: this.salesforceManager,
            aiCodeGenerator: this.aiCodeGenerator,
            deploymentPipeline: this.deploymentPipeline
        });

        // Enable new agent system via environment variable
        this.useAgentSystem = process.env.USE_AGENT_SYSTEM === 'true';

        this.app = express();
        this.setupRoutes();

        // Log which system is active
        if (this.useAgentSystem) {
            logger.info('Using NEW multi-agent orchestrator (ReAct + Extended Thinking)');
        } else {
            logger.info('Using legacy linear processing (set USE_AGENT_SYSTEM=true to upgrade)');
        }
    }

    // Handle notifications from the deployment scheduler
    async handleSchedulerNotification(notification) {
        logger.info(`[Scheduler] ${notification.type}: ${notification.message}`);
        // Could integrate with Slack notifications here
    }

    setupRoutes() {
        this.app.use(express.json());

        // Health check endpoint
        this.app.get('/health', (req, res) => {
            res.json({
                status: 'healthy',
                timestamp: new Date().toISOString(),
                services: {
                    salesforce: this.salesforceManager.isConnected(),
                    ai: true,
                    deployment: true
                }
            });
        });

        // Submit development task
        this.app.post('/task', async (req, res) => {
            try {
                const { description, priority = 'medium', autoDeploy = false } = req.body;
                
                logger.info(`New task received: ${description}`);
                
                // Process the task
                const result = await this.processTask(description, priority, autoDeploy);
                
                res.json({
                    success: true,
                    taskId: result.taskId,
                    status: result.status,
                    artifacts: result.artifacts,
                    deploymentStatus: result.deploymentStatus
                });
            } catch (error) {
                logger.error('Task processing failed:', error);
                res.status(500).json({
                    success: false,
                    error: error.message
                });
            }
        });

        // Get task status
        this.app.get('/task/:taskId', async (req, res) => {
            try {
                const status = await this.getTaskStatus(req.params.taskId);
                res.json(status);
            } catch (error) {
                res.status(404).json({
                    error: 'Task not found'
                });
            }
        });

        // Analyze org
        this.app.get('/analyze', async (req, res) => {
            try {
                const analysis = await this.orgAnalyzer.analyzeOrg();
                res.json(analysis);
            } catch (error) {
                logger.error('Org analysis failed:', error);
                res.status(500).json({
                    error: error.message
                });
            }
        });

        // ==================== NEW DEPLOYMENT ENDPOINTS ====================

        // List available snapshots for rollback
        this.app.get('/snapshots', async (req, res) => {
            try {
                const { org } = req.query;
                const snapshots = await this.deploymentPipeline.listSnapshots(org);
                res.json({ success: true, snapshots });
            } catch (error) {
                res.status(500).json({ success: false, error: error.message });
            }
        });

        // Execute rollback to snapshot
        this.app.post('/rollback', async (req, res) => {
            try {
                const { snapshotId, targetOrg = 'Devin1' } = req.body;
                let result;
                if (snapshotId) {
                    result = await this.deploymentPipeline.rollbackToSnapshot(snapshotId, targetOrg);
                } else {
                    result = await this.deploymentPipeline.rollbackToPrevious(targetOrg);
                }
                res.json({ success: result.success, result });
            } catch (error) {
                res.status(500).json({ success: false, error: error.message });
            }
        });

        // Schedule a deployment
        this.app.post('/schedule', async (req, res) => {
            try {
                const { artifacts, targetOrg, scheduledTime, options, userId, description } = req.body;
                const result = await this.deploymentScheduler.scheduleDeployment({
                    artifacts,
                    targetOrg,
                    scheduledTime,
                    options,
                    userId,
                    description
                });
                res.json({ success: true, ...result });
            } catch (error) {
                res.status(500).json({ success: false, error: error.message });
            }
        });

        // List scheduled deployments
        this.app.get('/scheduled', async (req, res) => {
            try {
                const { status, targetOrg } = req.query;
                const deployments = this.deploymentScheduler.getScheduledDeployments({ status, targetOrg });
                res.json({ success: true, deployments });
            } catch (error) {
                res.status(500).json({ success: false, error: error.message });
            }
        });

        // Cancel scheduled deployment
        this.app.delete('/scheduled/:scheduledId', async (req, res) => {
            try {
                const result = await this.deploymentScheduler.cancelScheduledDeployment(req.params.scheduledId);
                res.json({ success: true, ...result });
            } catch (error) {
                res.status(500).json({ success: false, error: error.message });
            }
        });

        // Get deployment windows
        this.app.get('/deployment-windows', (req, res) => {
            res.json({
                success: true,
                windows: this.deploymentScheduler.windows,
                nextWindow: this.deploymentScheduler.getNextWindow(req.query.org)
            });
        });

        // Get scheduler statistics
        this.app.get('/scheduler-stats', (req, res) => {
            res.json({
                success: true,
                stats: this.deploymentScheduler.getStatistics()
            });
        });
    }

    async processTask(description, priority, autoDeploy) {
        const taskId = `task-${Date.now()}`;
        const taskDir = `./output/${taskId}`;

        // NEW: Use multi-agent orchestrator if enabled
        if (this.useAgentSystem) {
            return this.processTaskWithAgents(description, priority, autoDeploy, taskId);
        }

        try {
            // Step 1: Analyze the task
            logger.info(`Analyzing task: ${taskId}`);
            const taskAnalysis = await this.taskAnalyzer.analyze(description);
            
            // Step 2: Get current org context
            logger.info('Fetching org context...');
            const orgContext = await this.orgAnalyzer.getContext(taskAnalysis.affectedObjects);
            
            // Step 3: Generate code/configuration
            // Default to refactor mode for context-aware code generation
            logger.info('Generating solution in refactor mode...');
            const generatedArtifacts = await this.aiCodeGenerator.generate({
                task: taskAnalysis,
                orgContext: orgContext,
                priority: priority,
                mode: 'refactor',      // Use refactor mode to preserve existing code
                targetOrg: 'Devin1'    // Target org for fetching existing code
            });
            
            // Step 4: Validate the generated solution
            logger.info('Validating solution...');
            const validationResult = await this.validateSolution(generatedArtifacts);
            
            if (!validationResult.isValid) {
                throw new Error(`Validation failed: ${validationResult.errors.join(', ')}`);
            }
            
            // Step 5: Deploy to sandbox
            let deploymentStatus = { deployed: false };
            if (autoDeploy || priority === 'high') {
                logger.info('Deploying to sandbox...');
                deploymentStatus = await this.deploymentPipeline.deployToSandbox(
                    generatedArtifacts,
                    'dev-sandbox'
                );
            }
            
            // Step 6: Run tests
            if (deploymentStatus.deployed) {
                logger.info('Running tests...');
                const testResults = await this.runTests(taskId);
                deploymentStatus.testResults = testResults;
            }
            
            // Step 7: Generate report
            const report = await this.generateReport({
                taskId,
                description,
                analysis: taskAnalysis,
                artifacts: generatedArtifacts,
                validation: validationResult,
                deployment: deploymentStatus
            });
            
            return {
                taskId,
                status: 'completed',
                artifacts: generatedArtifacts,
                deploymentStatus,
                report
            };
            
        } catch (error) {
            logger.error(`Task ${taskId} failed:`, error);
            throw error;
        }
    }

    /**
     * NEW: Process task using the multi-agent orchestrator
     * Uses ReAct loops, extended thinking, and parallel subagents
     */
    async processTaskWithAgents(description, priority, autoDeploy, taskId) {
        logger.info(`Processing task ${taskId} with multi-agent system`);

        try {
            // Build task object for agent orchestrator
            const task = {
                id: taskId,
                description,
                priority,
                autoDeploy,
                targetOrg: 'dev-sandbox'
            };

            // Process with new agent system
            const result = await this.agentOrchestrator.processTask(task);

            if (!result.success) {
                throw new Error(result.error || 'Agent processing failed');
            }

            // Handle deployment if requested and artifacts exist
            let deploymentStatus = { deployed: false };
            if ((autoDeploy || priority === 'high') && result.artifacts?.apex) {
                logger.info('Deploying generated artifacts to sandbox...');
                deploymentStatus = await this.deploymentPipeline.deployToSandbox(
                    result.artifacts,
                    'dev-sandbox'
                );

                // Run tests after deployment
                if (deploymentStatus.deployed) {
                    const testResults = await this.runTests(taskId);
                    deploymentStatus.testResults = testResults;
                }
            }

            // Generate enhanced report with agent metadata
            const report = await this.generateAgentReport({
                taskId,
                description,
                agentResult: result,
                deployment: deploymentStatus
            });

            return {
                taskId,
                status: 'completed',
                artifacts: result.artifacts,
                deploymentStatus,
                report,
                agentMetadata: {
                    thinking: result.thinking?.substring(0, 500), // Truncate for response
                    phases: result.phases?.length || 0,
                    evaluation: result.evaluation,
                    cost: result.cost
                }
            };

        } catch (error) {
            logger.error(`Agent processing failed for ${taskId}:`, error);
            throw error;
        }
    }

    /**
     * Generate report for agent-processed tasks
     */
    async generateAgentReport(data) {
        const report = {
            taskId: data.taskId,
            timestamp: new Date().toISOString(),
            description: data.description,
            processingMode: 'multi-agent',
            agentEvaluation: data.agentResult.evaluation,
            generatedArtifacts: {
                apex: Object.keys(data.agentResult.artifacts?.apex || {}),
                tests: Object.keys(data.agentResult.artifacts?.tests || {}),
                metadata: Object.keys(data.agentResult.artifacts?.metadata || {})
            },
            validation: data.agentResult.artifacts?.validation,
            deployment: {
                status: data.deployment.deployed ? 'SUCCESS' : 'PENDING',
                target: 'dev-sandbox',
                testResults: data.deployment.testResults
            },
            cost: data.agentResult.cost,
            nextSteps: []
        };

        if (data.deployment.deployed) {
            report.nextSteps.push('Review changes in sandbox');
            report.nextSteps.push('Run user acceptance testing');
            report.nextSteps.push('Prepare for production deployment');
        } else {
            report.nextSteps.push('Review generated artifacts');
            report.nextSteps.push('Deploy to sandbox for testing');
        }

        // Save report
        await fs.ensureDir(`./output/${data.taskId}`);
        await fs.writeJson(`./output/${data.taskId}/report.json`, report, { spaces: 2 });

        // Also save thinking/reasoning if available
        if (data.agentResult.thinking) {
            await fs.writeFile(
                `./output/${data.taskId}/agent-thinking.txt`,
                data.agentResult.thinking
            );
        }

        return report;
    }

    async validateSolution(artifacts) {
        // Validate the generated artifacts
        const errors = [];
        
        // Check for syntax errors
        if (artifacts.apex) {
            const apexValidation = await this.salesforceManager.validateApex(artifacts.apex);
            if (!apexValidation.success) {
                errors.push(...apexValidation.errors);
            }
        }
        
        // Check for metadata validity
        if (artifacts.metadata) {
            const metadataValidation = await this.salesforceManager.validateMetadata(artifacts.metadata);
            if (!metadataValidation.success) {
                errors.push(...metadataValidation.errors);
            }
        }
        
        return {
            isValid: errors.length === 0,
            errors
        };
    }

    async runTests(taskId) {
        try {
            const testResults = await this.salesforceManager.runTests('dev-sandbox');
            return {
                passed: testResults.numTestsRun === testResults.numTestsPassed,
                coverage: testResults.codeCoverage,
                details: testResults
            };
        } catch (error) {
            logger.error('Test execution failed:', error);
            return {
                passed: false,
                error: error.message
            };
        }
    }

    async generateReport(data) {
        const report = {
            taskId: data.taskId,
            timestamp: new Date().toISOString(),
            description: data.description,
            analysis: data.analysis,
            generatedArtifacts: Object.keys(data.artifacts),
            validation: data.validation,
            deployment: {
                status: data.deployment.deployed ? 'SUCCESS' : 'PENDING',
                target: 'dev-sandbox',
                testResults: data.deployment.testResults
            },
            nextSteps: []
        };
        
        if (data.deployment.deployed) {
            report.nextSteps.push('Review changes in sandbox');
            report.nextSteps.push('Run user acceptance testing');
            report.nextSteps.push('Prepare for production deployment');
        } else {
            report.nextSteps.push('Review generated artifacts');
            report.nextSteps.push('Deploy to sandbox for testing');
        }
        
        // Save report
        await fs.ensureDir(`./output/${data.taskId}`);
        await fs.writeJson(`./output/${data.taskId}/report.json`, report, { spaces: 2 });
        
        return report;
    }

    async getTaskStatus(taskId) {
        const reportPath = `./output/${taskId}/report.json`;

        if (await fs.pathExists(reportPath)) {
            return await fs.readJson(reportPath);
        }
        
        throw new Error('Task not found');
    }

    async start() {
        const port = process.env.PORT || 3000;
        
        // Initialize Salesforce connection
        await this.salesforceManager.connect();
        
        // Start the server
        this.app.listen(port, () => {
            logger.info(`Autonomous Development System running on http://localhost:${port}`);
            logger.info('Ready to receive development tasks');
            console.log(`
╔════════════════════════════════════════════════════╗
║   Autonomous Salesforce Development System        ║
║   Status: OPERATIONAL                              ║
║   Endpoint: http://localhost:${port}              ║
║                                                    ║
║   Submit tasks via:                               ║
║   - Web API: POST /task                          ║
║   - CLI: npm run task "your request"             ║
║   - Interactive: npm run interactive             ║
╚════════════════════════════════════════════════════╝
            `);
        });
    }
}

// Start the system
const system = new AutonomousDevelopmentSystem();
system.start().catch(error => {
    logger.error('Failed to start system:', error);
    process.exit(1);
});

export { AutonomousDevelopmentSystem };
