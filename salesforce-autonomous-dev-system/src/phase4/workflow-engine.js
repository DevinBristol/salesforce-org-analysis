/**
 * Workflow Engine for Phase 4
 *
 * Orchestrates complex multi-step development workflows.
 * Features:
 * - DAG-based workflow execution
 * - Conditional branching
 * - Parallel execution
 * - State persistence
 * - Error handling and recovery
 */

import EventEmitter from 'events';

class WorkflowEngine extends EventEmitter {
    constructor(options = {}) {
        super();

        this.orchestrator = options.orchestrator;
        this.logger = options.logger || console;
        this.db = options.db;
        this.progressReporter = options.progressReporter;

        // Active workflows
        this.activeWorkflows = new Map();

        // Workflow templates
        this.templates = new Map();

        // Register default templates
        this.registerDefaultTemplates();

        // Step executors
        this.stepExecutors = new Map();
        this.registerDefaultExecutors();
    }

    /**
     * Register default workflow templates
     */
    registerDefaultTemplates() {
        // Full Analysis + Improvement workflow
        this.templates.set('full-analysis-improvement', {
            name: 'Full Analysis and Improvement',
            description: 'Analyze code and implement improvements',
            steps: [
                {
                    id: 'analyze',
                    type: 'claude-task',
                    taskType: 'analysis',
                    prompt: 'Analyze the provided Salesforce code for best practices, security vulnerabilities, performance issues, and code quality.',
                    outputs: ['analysisReport', 'issues']
                },
                {
                    id: 'prioritize',
                    type: 'claude-task',
                    taskType: 'analysis',
                    dependsOn: ['analyze'],
                    prompt: 'Based on the analysis, prioritize the issues by impact and effort. Create an improvement plan.',
                    inputs: ['analysisReport'],
                    outputs: ['improvementPlan']
                },
                {
                    id: 'implement',
                    type: 'claude-task',
                    taskType: 'improvement',
                    dependsOn: ['prioritize'],
                    prompt: 'Implement the high-priority improvements from the plan.',
                    inputs: ['improvementPlan'],
                    outputs: ['implementedChanges']
                },
                {
                    id: 'test',
                    type: 'claude-task',
                    taskType: 'testing',
                    dependsOn: ['implement'],
                    prompt: 'Create and run tests for the implemented changes.',
                    inputs: ['implementedChanges'],
                    outputs: ['testResults']
                },
                {
                    id: 'report',
                    type: 'generate-report',
                    dependsOn: ['test'],
                    inputs: ['analysisReport', 'improvementPlan', 'implementedChanges', 'testResults'],
                    outputs: ['finalReport']
                }
            ]
        });

        // Bug Fix workflow
        this.templates.set('bug-fix', {
            name: 'Bug Fix Workflow',
            description: 'Diagnose and fix a bug',
            steps: [
                {
                    id: 'reproduce',
                    type: 'claude-task',
                    taskType: 'debugging',
                    prompt: 'Attempt to reproduce the bug and understand its symptoms.',
                    outputs: ['reproductionSteps', 'symptoms']
                },
                {
                    id: 'diagnose',
                    type: 'claude-task',
                    taskType: 'debugging',
                    dependsOn: ['reproduce'],
                    prompt: 'Analyze the code to identify the root cause of the bug.',
                    inputs: ['symptoms'],
                    outputs: ['rootCause', 'affectedCode']
                },
                {
                    id: 'fix',
                    type: 'claude-task',
                    taskType: 'improvement',
                    dependsOn: ['diagnose'],
                    prompt: 'Implement a fix for the identified root cause.',
                    inputs: ['rootCause', 'affectedCode'],
                    outputs: ['fix']
                },
                {
                    id: 'verify',
                    type: 'claude-task',
                    taskType: 'testing',
                    dependsOn: ['fix'],
                    prompt: 'Verify the fix resolves the bug without introducing regressions.',
                    inputs: ['fix', 'reproductionSteps'],
                    outputs: ['verificationResult']
                }
            ]
        });

        // Deployment workflow
        this.templates.set('deployment', {
            name: 'Deployment Workflow',
            description: 'Deploy changes to Salesforce org',
            steps: [
                {
                    id: 'validate',
                    type: 'salesforce-command',
                    command: 'deploy',
                    options: { checkOnly: true },
                    outputs: ['validationResult']
                },
                {
                    id: 'approval',
                    type: 'approval',
                    dependsOn: ['validate'],
                    condition: '${validationResult.success}',
                    message: 'Validation passed. Proceed with deployment?'
                },
                {
                    id: 'deploy',
                    type: 'salesforce-command',
                    dependsOn: ['approval'],
                    condition: '${approval.approved}',
                    command: 'deploy',
                    options: { checkOnly: false },
                    outputs: ['deploymentResult']
                },
                {
                    id: 'smoke-test',
                    type: 'claude-task',
                    taskType: 'testing',
                    dependsOn: ['deploy'],
                    prompt: 'Run smoke tests to verify the deployment.',
                    outputs: ['smokeTestResult']
                }
            ]
        });

        // Code Review workflow
        this.templates.set('code-review', {
            name: 'Code Review Workflow',
            description: 'Comprehensive code review',
            steps: [
                {
                    id: 'security-review',
                    type: 'claude-task',
                    taskType: 'analysis',
                    prompt: 'Review the code for security vulnerabilities including SOQL injection, XSS, and access control issues.',
                    outputs: ['securityFindings']
                },
                {
                    id: 'performance-review',
                    type: 'claude-task',
                    taskType: 'analysis',
                    prompt: 'Review the code for performance issues including governor limits, bulk patterns, and query optimization.',
                    outputs: ['performanceFindings']
                },
                {
                    id: 'quality-review',
                    type: 'claude-task',
                    taskType: 'analysis',
                    prompt: 'Review the code for quality including naming conventions, documentation, and design patterns.',
                    outputs: ['qualityFindings']
                },
                {
                    id: 'combine-results',
                    type: 'combine',
                    dependsOn: ['security-review', 'performance-review', 'quality-review'],
                    inputs: ['securityFindings', 'performanceFindings', 'qualityFindings'],
                    outputs: ['combinedReview']
                },
                {
                    id: 'generate-report',
                    type: 'generate-report',
                    dependsOn: ['combine-results'],
                    inputs: ['combinedReview'],
                    outputs: ['reviewReport']
                }
            ]
        });
    }

    /**
     * Register default step executors
     */
    registerDefaultExecutors() {
        // Claude task executor
        this.stepExecutors.set('claude-task', async (step, context, workflow) => {
            const prompt = this.interpolateTemplate(step.prompt, context);

            const taskId = await this.orchestrator.submitTask({
                type: step.taskType,
                prompt,
                context: {
                    files: context.files,
                    ...context.metadata
                },
                callback: workflow.callback
            });

            // Wait for task completion
            return await this.waitForTask(taskId);
        });

        // Salesforce command executor
        this.stepExecutors.set('salesforce-command', async (step, context, workflow) => {
            // This would integrate with SF CLI
            return {
                success: true,
                message: `Salesforce ${step.command} completed`
            };
        });

        // Approval step executor
        this.stepExecutors.set('approval', async (step, context, workflow) => {
            // Emit approval request event
            this.emit('approval:requested', {
                workflowId: workflow.id,
                stepId: step.id,
                message: this.interpolateTemplate(step.message, context)
            });

            // Wait for approval response
            return await this.waitForApproval(workflow.id, step.id);
        });

        // Combine results executor
        this.stepExecutors.set('combine', async (step, context, workflow) => {
            const combined = {};
            for (const input of step.inputs) {
                if (context[input]) {
                    combined[input] = context[input];
                }
            }
            return combined;
        });

        // Report generator executor
        this.stepExecutors.set('generate-report', async (step, context, workflow) => {
            const inputData = {};
            for (const input of step.inputs) {
                if (context[input]) {
                    inputData[input] = context[input];
                }
            }

            // Generate markdown report
            let report = `# Workflow Report: ${workflow.name}\n\n`;
            report += `**Completed:** ${new Date().toISOString()}\n\n`;

            for (const [key, value] of Object.entries(inputData)) {
                report += `## ${this.formatSectionName(key)}\n\n`;
                if (typeof value === 'string') {
                    report += value + '\n\n';
                } else if (value.summary) {
                    report += value.summary + '\n\n';
                } else {
                    report += '```json\n' + JSON.stringify(value, null, 2) + '\n```\n\n';
                }
            }

            return { report };
        });
    }

    /**
     * Register a custom step executor
     */
    registerExecutor(type, executorFn) {
        this.stepExecutors.set(type, executorFn);
    }

    /**
     * Register a workflow template
     */
    registerTemplate(id, template) {
        this.templates.set(id, template);
    }

    /**
     * Start a workflow
     * @param {string} templateId - Workflow template ID
     * @param {Object} params - Workflow parameters
     */
    async startWorkflow(templateId, params = {}) {
        const template = this.templates.get(templateId);
        if (!template) {
            throw new Error(`Unknown workflow template: ${templateId}`);
        }

        const workflowId = `wf_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

        const workflow = {
            id: workflowId,
            templateId,
            name: template.name,
            description: template.description,
            steps: JSON.parse(JSON.stringify(template.steps)), // Deep clone
            context: {
                ...params.context,
                files: params.files || {},
                metadata: params.metadata || {}
            },
            callback: params.callback,
            status: 'running',
            currentSteps: [],
            completedSteps: [],
            failedSteps: [],
            stepResults: {},
            startedAt: new Date().toISOString(),
            error: null
        };

        this.activeWorkflows.set(workflowId, workflow);

        // Start progress tracking
        if (this.progressReporter) {
            this.progressReporter.startTracking(workflowId, {
                taskType: 'workflow',
                stages: template.steps.map(s => ({
                    name: s.id,
                    weight: 1
                })),
                slackConfig: params.callback?.slackConfig
            });
        }

        this.logger.info(`[Workflow] Started workflow ${workflowId}`, {
            template: templateId,
            steps: template.steps.length
        });

        this.emit('workflow:started', workflow);

        // Persist workflow
        if (this.db) {
            await this.persistWorkflow(workflow);
        }

        // Start execution
        this.executeWorkflow(workflowId).catch(error => {
            this.logger.error(`[Workflow] Execution error: ${error.message}`);
        });

        return workflowId;
    }

    /**
     * Execute a workflow
     */
    async executeWorkflow(workflowId) {
        const workflow = this.activeWorkflows.get(workflowId);
        if (!workflow) return;

        try {
            while (workflow.status === 'running') {
                // Find executable steps (dependencies met, not yet executed)
                const executableSteps = this.findExecutableSteps(workflow);

                if (executableSteps.length === 0) {
                    // Check if all steps are done
                    if (workflow.completedSteps.length === workflow.steps.length) {
                        workflow.status = 'completed';
                        break;
                    }

                    // Check for waiting on approval
                    const waitingForApproval = workflow.steps.find(s =>
                        s.type === 'approval' &&
                        !workflow.completedSteps.includes(s.id) &&
                        this.dependenciesMet(s, workflow)
                    );

                    if (waitingForApproval) {
                        workflow.status = 'awaiting_approval';
                        break;
                    }

                    // Check for deadlock (shouldn't happen with valid DAG)
                    this.logger.error(`[Workflow] Deadlock detected in ${workflowId}`);
                    workflow.status = 'failed';
                    workflow.error = 'Workflow deadlock detected';
                    break;
                }

                // Execute steps in parallel
                await Promise.all(
                    executableSteps.map(step => this.executeStep(workflow, step))
                );

                // Update progress
                if (this.progressReporter) {
                    const completedCount = workflow.completedSteps.length;
                    this.progressReporter.updateProgress(workflowId, {
                        stageProgress: Math.round((completedCount / workflow.steps.length) * 100)
                    });
                }
            }

            // Workflow completed
            workflow.completedAt = new Date().toISOString();
            workflow.duration = new Date(workflow.completedAt) - new Date(workflow.startedAt);

            if (workflow.status === 'completed') {
                if (this.progressReporter) {
                    await this.progressReporter.completeTracking(workflowId, {
                        success: true,
                        summary: `Workflow completed with ${workflow.steps.length} steps`
                    });
                }

                this.emit('workflow:completed', workflow);
            } else if (workflow.status === 'failed') {
                if (this.progressReporter) {
                    await this.progressReporter.failTracking(workflowId, workflow.error);
                }

                this.emit('workflow:failed', { workflow, error: workflow.error });
            }

            // Persist final state
            if (this.db) {
                await this.persistWorkflow(workflow);
            }

        } catch (error) {
            workflow.status = 'failed';
            workflow.error = error.message;
            this.emit('workflow:failed', { workflow, error });

            if (this.progressReporter) {
                await this.progressReporter.failTracking(workflowId, error);
            }
        }
    }

    /**
     * Find steps that can be executed
     */
    findExecutableSteps(workflow) {
        return workflow.steps.filter(step => {
            // Not already completed or in progress
            if (workflow.completedSteps.includes(step.id)) return false;
            if (workflow.currentSteps.includes(step.id)) return false;
            if (workflow.failedSteps.includes(step.id)) return false;

            // Dependencies met
            if (!this.dependenciesMet(step, workflow)) return false;

            // Condition met (if any)
            if (step.condition && !this.evaluateCondition(step.condition, workflow.context)) {
                workflow.completedSteps.push(step.id);
                workflow.stepResults[step.id] = { skipped: true, reason: 'condition_not_met' };
                return false;
            }

            return true;
        });
    }

    /**
     * Check if step dependencies are met
     */
    dependenciesMet(step, workflow) {
        if (!step.dependsOn || step.dependsOn.length === 0) return true;
        return step.dependsOn.every(dep => workflow.completedSteps.includes(dep));
    }

    /**
     * Evaluate a condition
     */
    evaluateCondition(condition, context) {
        // Simple template-based condition evaluation
        const evaluated = this.interpolateTemplate(condition, context);
        return evaluated === 'true' || evaluated === true;
    }

    /**
     * Execute a single step
     */
    async executeStep(workflow, step) {
        workflow.currentSteps.push(step.id);

        this.logger.info(`[Workflow] Executing step ${step.id} in ${workflow.id}`);
        this.emit('step:started', { workflowId: workflow.id, step });

        try {
            // Get executor
            const executor = this.stepExecutors.get(step.type);
            if (!executor) {
                throw new Error(`Unknown step type: ${step.type}`);
            }

            // Prepare step context with inputs
            const stepContext = { ...workflow.context };
            if (step.inputs) {
                for (const input of step.inputs) {
                    if (workflow.stepResults[input]) {
                        stepContext[input] = workflow.stepResults[input];
                    }
                }
            }

            // Execute
            const result = await executor(step, stepContext, workflow);

            // Store outputs
            if (step.outputs) {
                for (const output of step.outputs) {
                    workflow.stepResults[output] = result[output] || result;
                    workflow.context[output] = result[output] || result;
                }
            }
            workflow.stepResults[step.id] = result;

            // Mark complete
            workflow.currentSteps = workflow.currentSteps.filter(s => s !== step.id);
            workflow.completedSteps.push(step.id);

            this.emit('step:completed', { workflowId: workflow.id, step, result });

        } catch (error) {
            workflow.currentSteps = workflow.currentSteps.filter(s => s !== step.id);
            workflow.failedSteps.push(step.id);
            workflow.error = `Step ${step.id} failed: ${error.message}`;
            workflow.status = 'failed';

            this.emit('step:failed', { workflowId: workflow.id, step, error });
            throw error;
        }
    }

    /**
     * Wait for a task to complete
     */
    async waitForTask(taskId) {
        return new Promise((resolve, reject) => {
            const checkInterval = setInterval(async () => {
                const status = this.orchestrator.getTaskStatus(taskId);

                if (!status) {
                    clearInterval(checkInterval);
                    reject(new Error(`Task ${taskId} not found`));
                    return;
                }

                if (status.status === 'completed') {
                    clearInterval(checkInterval);
                    resolve(status.result);
                } else if (status.status === 'failed') {
                    clearInterval(checkInterval);
                    reject(new Error(status.error || 'Task failed'));
                }
            }, 5000);
        });
    }

    /**
     * Wait for approval
     */
    waitForApproval(workflowId, stepId) {
        return new Promise((resolve) => {
            // Store resolver for later
            const workflow = this.activeWorkflows.get(workflowId);
            if (workflow) {
                workflow.pendingApproval = { stepId, resolve };
            }
        });
    }

    /**
     * Respond to approval request
     */
    async respondToApproval(workflowId, approved, comment = '') {
        const workflow = this.activeWorkflows.get(workflowId);
        if (!workflow || !workflow.pendingApproval) {
            throw new Error('No pending approval found');
        }

        const { stepId, resolve } = workflow.pendingApproval;
        delete workflow.pendingApproval;

        resolve({ approved, comment });

        if (approved && workflow.status === 'awaiting_approval') {
            workflow.status = 'running';
            // Resume execution
            this.executeWorkflow(workflowId);
        }

        this.emit('approval:responded', { workflowId, stepId, approved, comment });
    }

    /**
     * Interpolate template strings
     */
    interpolateTemplate(template, context) {
        if (typeof template !== 'string') return template;

        return template.replace(/\$\{([^}]+)\}/g, (match, path) => {
            const value = this.getNestedValue(context, path);
            return value !== undefined ? String(value) : match;
        });
    }

    /**
     * Get nested value from object
     */
    getNestedValue(obj, path) {
        return path.split('.').reduce((curr, key) => curr?.[key], obj);
    }

    /**
     * Format section name for display
     */
    formatSectionName(name) {
        return name
            .replace(/([A-Z])/g, ' $1')
            .replace(/^./, str => str.toUpperCase())
            .trim();
    }

    /**
     * Get workflow status
     */
    getWorkflowStatus(workflowId) {
        const workflow = this.activeWorkflows.get(workflowId);
        if (!workflow) return null;

        return {
            id: workflow.id,
            name: workflow.name,
            status: workflow.status,
            progress: Math.round((workflow.completedSteps.length / workflow.steps.length) * 100),
            currentSteps: workflow.currentSteps,
            completedSteps: workflow.completedSteps,
            failedSteps: workflow.failedSteps,
            startedAt: workflow.startedAt,
            completedAt: workflow.completedAt,
            duration: workflow.duration,
            error: workflow.error
        };
    }

    /**
     * Cancel a workflow
     */
    async cancelWorkflow(workflowId) {
        const workflow = this.activeWorkflows.get(workflowId);
        if (!workflow) return false;

        workflow.status = 'cancelled';
        workflow.completedAt = new Date().toISOString();

        if (this.progressReporter) {
            await this.progressReporter.failTracking(workflowId, 'Workflow cancelled');
        }

        this.emit('workflow:cancelled', workflow);
        this.activeWorkflows.delete(workflowId);

        return true;
    }

    /**
     * Get available workflow templates
     */
    getTemplates() {
        return Array.from(this.templates.entries()).map(([id, template]) => ({
            id,
            name: template.name,
            description: template.description,
            steps: template.steps.length
        }));
    }

    /**
     * Persist workflow to database
     */
    async persistWorkflow(workflow) {
        if (!this.db) return;

        const query = `
            INSERT INTO workflows (id, template_id, name, status, context, step_results, started_at, completed_at, error, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW())
            ON CONFLICT (id) DO UPDATE SET
                status = $4,
                context = $5,
                step_results = $6,
                completed_at = $8,
                error = $9,
                updated_at = NOW()
        `;

        await this.db.query(query, [
            workflow.id,
            workflow.templateId,
            workflow.name,
            workflow.status,
            JSON.stringify(workflow.context),
            JSON.stringify(workflow.stepResults),
            workflow.startedAt,
            workflow.completedAt,
            workflow.error
        ]);
    }

    /**
     * Load workflow from database
     */
    async loadWorkflow(workflowId) {
        if (!this.db) return null;

        const result = await this.db.query(
            'SELECT * FROM workflows WHERE id = $1',
            [workflowId]
        );

        if (result.rows.length === 0) return null;

        const row = result.rows[0];
        return {
            id: row.id,
            templateId: row.template_id,
            name: row.name,
            status: row.status,
            context: JSON.parse(row.context),
            stepResults: JSON.parse(row.step_results),
            startedAt: row.started_at,
            completedAt: row.completed_at,
            error: row.error
        };
    }

    /**
     * Shutdown workflow engine
     */
    async shutdown() {
        // Cancel all active workflows
        for (const [id, workflow] of this.activeWorkflows) {
            workflow.status = 'cancelled';
            this.emit('workflow:cancelled', workflow);
        }

        this.activeWorkflows.clear();
        this.removeAllListeners();

        this.logger.info('[Workflow] Engine shutdown complete');
    }
}

export { WorkflowEngine };
