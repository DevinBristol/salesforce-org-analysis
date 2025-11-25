/**
 * Claude Code Orchestrator for Phase 4
 *
 * Manages Claude Code instances for autonomous task execution.
 * Features:
 * - Dynamic instance management
 * - Task scheduling and distribution
 * - Session state management
 * - Error recovery and retry logic
 * - Resource optimization
 */

import EventEmitter from 'events';
import { spawn } from 'child_process';
import path from 'path';
import fs from 'fs/promises';

class ClaudeCodeOrchestrator extends EventEmitter {
    constructor(options = {}) {
        super();

        this.logger = options.logger || console;
        this.db = options.db;
        this.progressReporter = options.progressReporter;
        this.resultCallback = options.resultCallback;
        this.monitoring = options.monitoring;

        // Instance configuration
        this.maxInstances = options.maxInstances || 5;
        this.instanceTimeout = options.instanceTimeout || 30 * 60 * 1000; // 30 minutes
        this.idleTimeout = options.idleTimeout || 5 * 60 * 1000; // 5 minutes

        // Active instances
        this.instances = new Map();
        this.instanceQueue = [];

        // Task management
        this.pendingTasks = [];
        this.activeTasks = new Map();
        this.taskHistory = new Map();

        // Project workspace configuration
        this.workspaceRoot = options.workspaceRoot || process.env.WORKSPACE_ROOT || '/tmp/claude-workspace';
        this.projectTemplates = options.projectTemplates || {};

        // Start instance management
        this.managementInterval = setInterval(() => {
            this.manageInstances();
        }, 30000);
    }

    /**
     * Submit a task for execution
     * @param {Object} task - Task configuration
     */
    async submitTask(task) {
        const taskId = task.id || `task_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

        const enrichedTask = {
            id: taskId,
            type: task.type,
            prompt: task.prompt,
            context: task.context || {},
            priority: task.priority || 'normal',
            timeout: task.timeout || this.instanceTimeout,
            retries: task.retries || 3,
            retriesRemaining: task.retries || 3,
            workspace: task.workspace,
            stages: task.stages || this.getDefaultStages(task.type),
            callback: task.callback,
            submittedAt: new Date().toISOString(),
            status: 'pending'
        };

        // Add to pending queue
        this.pendingTasks.push(enrichedTask);

        // Sort by priority
        this.prioritizeTasks();

        this.logger.info(`[Orchestrator] Task submitted: ${taskId}`, {
            type: task.type,
            priority: task.priority
        });

        this.emit('task:submitted', enrichedTask);

        // Try to execute immediately
        this.processQueue();

        return taskId;
    }

    /**
     * Get default stages for a task type
     */
    getDefaultStages(taskType) {
        const stageTemplates = {
            analysis: [
                { name: 'Setup', weight: 1 },
                { name: 'Code Analysis', weight: 3 },
                { name: 'Report Generation', weight: 1 }
            ],
            improvement: [
                { name: 'Setup', weight: 1 },
                { name: 'Analysis', weight: 2 },
                { name: 'Implementation', weight: 4 },
                { name: 'Testing', weight: 2 },
                { name: 'Cleanup', weight: 1 }
            ],
            debugging: [
                { name: 'Reproduction', weight: 2 },
                { name: 'Root Cause Analysis', weight: 3 },
                { name: 'Fix Implementation', weight: 3 },
                { name: 'Verification', weight: 2 }
            ],
            deployment: [
                { name: 'Validation', weight: 2 },
                { name: 'Deployment', weight: 3 },
                { name: 'Testing', weight: 2 },
                { name: 'Verification', weight: 1 }
            ],
            default: [
                { name: 'Setup', weight: 1 },
                { name: 'Execution', weight: 4 },
                { name: 'Completion', weight: 1 }
            ]
        };

        return stageTemplates[taskType] || stageTemplates.default;
    }

    /**
     * Prioritize pending tasks
     */
    prioritizeTasks() {
        const priorityOrder = { high: 0, normal: 1, low: 2 };
        this.pendingTasks.sort((a, b) => {
            const pA = priorityOrder[a.priority] ?? 1;
            const pB = priorityOrder[b.priority] ?? 1;
            if (pA !== pB) return pA - pB;
            return new Date(a.submittedAt) - new Date(b.submittedAt);
        });
    }

    /**
     * Process the task queue
     */
    async processQueue() {
        // Check if we can start more tasks
        if (this.activeTasks.size >= this.maxInstances) {
            return;
        }

        if (this.pendingTasks.length === 0) {
            return;
        }

        // Get next task
        const task = this.pendingTasks.shift();

        // Start execution
        await this.executeTask(task);
    }

    /**
     * Execute a task with Claude Code
     */
    async executeTask(task) {
        const startTime = Date.now();

        try {
            // Update task status
            task.status = 'running';
            task.startedAt = new Date().toISOString();
            this.activeTasks.set(task.id, task);

            // Start progress tracking
            if (this.progressReporter) {
                this.progressReporter.startTracking(task.id, {
                    taskType: task.type,
                    stages: task.stages,
                    slackConfig: task.callback?.slackConfig
                });
            }

            // Track in monitoring
            if (this.monitoring) {
                this.monitoring.trackTask('started', { type: task.type });
            }

            this.emit('task:started', task);

            // Prepare workspace
            const workspace = await this.prepareWorkspace(task);

            // Create Claude Code instance
            const instance = await this.createInstance(task, workspace);

            // Execute the task
            const result = await this.runClaudeCode(instance, task);

            // Task completed successfully
            task.status = 'completed';
            task.completedAt = new Date().toISOString();
            task.duration = Date.now() - startTime;
            task.result = result;

            // Update progress
            if (this.progressReporter) {
                await this.progressReporter.completeTracking(task.id, {
                    success: true,
                    summary: result.summary
                });
            }

            // Deliver result
            if (this.resultCallback && task.callback) {
                await this.resultCallback.deliverResult(task.id, {
                    success: true,
                    duration: task.duration,
                    summary: result.summary,
                    output: result.output,
                    artifacts: result.artifacts
                });
            }

            // Track completion
            if (this.monitoring) {
                this.monitoring.trackTask('completed', {
                    type: task.type,
                    duration: task.duration
                });
            }

            this.emit('task:completed', task);

            // Store in history
            this.taskHistory.set(task.id, task);

        } catch (error) {
            this.logger.error(`[Orchestrator] Task failed: ${task.id}`, error);

            task.status = 'failed';
            task.error = error.message;
            task.duration = Date.now() - startTime;

            // Check for retries
            if (task.retriesRemaining > 0) {
                task.retriesRemaining--;
                task.status = 'retrying';
                this.pendingTasks.unshift(task); // Add back to front of queue
                this.logger.info(`[Orchestrator] Retrying task ${task.id}, ${task.retriesRemaining} retries left`);
            } else {
                // Final failure
                if (this.progressReporter) {
                    await this.progressReporter.failTracking(task.id, error);
                }

                if (this.resultCallback && task.callback) {
                    await this.resultCallback.deliverResult(task.id, {
                        success: false,
                        duration: task.duration,
                        error: error.message
                    });
                }

                if (this.monitoring) {
                    this.monitoring.trackTask('failed', {
                        type: task.type,
                        error: error.message
                    });
                }

                this.emit('task:failed', { task, error });
                this.taskHistory.set(task.id, task);
            }

        } finally {
            // Cleanup
            this.activeTasks.delete(task.id);

            // Process next task
            this.processQueue();
        }
    }

    /**
     * Prepare workspace for task
     */
    async prepareWorkspace(task) {
        const workspacePath = path.join(
            this.workspaceRoot,
            task.id
        );

        // Create workspace directory
        await fs.mkdir(workspacePath, { recursive: true });

        // If task includes source files, write them
        if (task.context.files) {
            for (const [filePath, content] of Object.entries(task.context.files)) {
                const fullPath = path.join(workspacePath, filePath);
                await fs.mkdir(path.dirname(fullPath), { recursive: true });
                await fs.writeFile(fullPath, content);
            }
        }

        // If using a project template, copy it
        if (task.context.template && this.projectTemplates[task.context.template]) {
            const templatePath = this.projectTemplates[task.context.template];
            await this.copyDirectory(templatePath, workspacePath);
        }

        // If cloning from repo, do that
        if (task.context.repoUrl) {
            await this.cloneRepository(task.context.repoUrl, workspacePath, task.context.branch);
        }

        return workspacePath;
    }

    /**
     * Clone a git repository
     */
    async cloneRepository(repoUrl, destPath, branch) {
        return new Promise((resolve, reject) => {
            const args = ['clone', '--depth', '1'];
            if (branch) {
                args.push('-b', branch);
            }
            args.push(repoUrl, destPath);

            const git = spawn('git', args);

            git.on('close', code => {
                if (code === 0) {
                    resolve();
                } else {
                    reject(new Error(`Git clone failed with code ${code}`));
                }
            });

            git.on('error', reject);
        });
    }

    /**
     * Copy directory recursively
     */
    async copyDirectory(src, dest) {
        await fs.mkdir(dest, { recursive: true });
        const entries = await fs.readdir(src, { withFileTypes: true });

        for (const entry of entries) {
            const srcPath = path.join(src, entry.name);
            const destPath = path.join(dest, entry.name);

            if (entry.isDirectory()) {
                await this.copyDirectory(srcPath, destPath);
            } else {
                await fs.copyFile(srcPath, destPath);
            }
        }
    }

    /**
     * Create a Claude Code instance
     */
    async createInstance(task, workspace) {
        const instanceId = `inst_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

        const instance = {
            id: instanceId,
            taskId: task.id,
            workspace,
            process: null,
            status: 'initializing',
            createdAt: Date.now(),
            output: [],
            errors: []
        };

        this.instances.set(instanceId, instance);

        return instance;
    }

    /**
     * Run Claude Code for a task
     */
    async runClaudeCode(instance, task) {
        return new Promise((resolve, reject) => {
            const prompt = this.buildPrompt(task);

            // Build Claude Code command - use stdin for prompt (handles long prompts)
            const args = [
                '--print',
                '--dangerously-skip-permissions'
            ];

            // Set working directory to workspace
            const options = {
                cwd: instance.workspace,
                env: {
                    ...process.env,
                    ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY
                },
                maxBuffer: 50 * 1024 * 1024, // 50MB buffer
                shell: process.platform === 'win32' // Use shell on Windows
            };

            this.logger.info(`[Orchestrator] Starting Claude Code for task ${task.id}`);
            this.logger.info(`[Orchestrator] Working directory: ${instance.workspace}`);

            // Use claude.cmd on Windows
            const command = process.platform === 'win32' ? 'claude.cmd' : 'claude';
            const child = spawn(command, args, options);
            instance.process = child;
            instance.status = 'running';

            // Write prompt to stdin
            child.stdin.write(prompt);
            child.stdin.end();

            let output = '';
            let currentStage = 0;

            child.stdout.on('data', (data) => {
                const text = data.toString();
                output += text;
                instance.output.push(text);

                // Parse progress indicators
                const stageMatch = text.match(/\[STAGE:(\d+)\]/);
                if (stageMatch) {
                    const newStage = parseInt(stageMatch[1]);
                    if (newStage !== currentStage) {
                        currentStage = newStage;
                        if (this.progressReporter) {
                            this.progressReporter.updateProgress(task.id, {
                                advanceStage: true
                            });
                        }
                    }
                }

                // Parse progress percentage
                const progressMatch = text.match(/\[PROGRESS:(\d+)\]/);
                if (progressMatch) {
                    const progress = parseInt(progressMatch[1]);
                    if (this.progressReporter) {
                        this.progressReporter.updateProgress(task.id, {
                            stageProgress: progress
                        });
                    }
                }
            });

            child.stderr.on('data', (data) => {
                const text = data.toString();
                instance.errors.push(text);
                this.logger.warn(`[Orchestrator] Claude Code stderr: ${text}`);
            });

            // Set timeout
            const timeout = setTimeout(() => {
                child.kill('SIGTERM');
                reject(new Error(`Task timed out after ${task.timeout}ms`));
            }, task.timeout);

            child.on('close', (code) => {
                clearTimeout(timeout);
                instance.status = 'completed';
                instance.exitCode = code;

                if (code === 0) {
                    const result = this.parseClaudeOutput(output, task);
                    resolve(result);
                } else {
                    reject(new Error(`Claude Code exited with code ${code}: ${instance.errors.join('\n')}`));
                }
            });

            child.on('error', (error) => {
                clearTimeout(timeout);
                instance.status = 'error';
                reject(error);
            });
        });
    }

    /**
     * Build prompt for Claude Code
     */
    buildPrompt(task) {
        let prompt = '';

        // Add system context
        if (task.context.systemContext) {
            prompt += `${task.context.systemContext}\n\n`;
        }

        // Add task-specific instructions
        prompt += `# Task: ${task.type}\n\n`;
        prompt += task.prompt;

        // Add progress reporting instructions
        prompt += `\n\n# Progress Reporting
As you work through this task, please output progress markers:
- When starting a new stage, output: [STAGE:N] where N is the stage number (1-indexed)
- Periodically output: [PROGRESS:P] where P is the percentage (0-100) of the current stage

# Stages for this task:
${task.stages.map((s, i) => `${i + 1}. ${s.name}`).join('\n')}
`;

        // Add any file context
        if (task.context.files && Object.keys(task.context.files).length > 0) {
            prompt += '\n\n# Files provided:\n';
            for (const filePath of Object.keys(task.context.files)) {
                prompt += `- ${filePath}\n`;
            }
        }

        return prompt;
    }

    /**
     * Parse Claude Code output
     */
    parseClaudeOutput(output, task) {
        // Extract summary (first paragraph or explicitly marked)
        let summary = '';
        const summaryMatch = output.match(/# Summary\n([\s\S]*?)(?=\n#|$)/);
        if (summaryMatch) {
            summary = summaryMatch[1].trim();
        } else {
            // Use first 500 chars as summary
            summary = output.substring(0, 500).trim();
        }

        // Extract artifacts (files created/modified)
        const artifacts = [];
        const filePattern = /(?:Created|Modified|Updated):\s*([^\n]+)/g;
        let match;
        while ((match = filePattern.exec(output)) !== null) {
            artifacts.push(match[1].trim());
        }

        return {
            output,
            summary,
            artifacts,
            taskId: task.id,
            taskType: task.type
        };
    }

    /**
     * Manage Claude Code instances (cleanup idle/stale)
     */
    manageInstances() {
        const now = Date.now();

        for (const [id, instance] of this.instances) {
            // Clean up completed instances after idle timeout
            if (instance.status === 'completed' && now - instance.createdAt > this.idleTimeout) {
                this.cleanupInstance(id);
            }

            // Kill stuck instances
            if (instance.status === 'running' && now - instance.createdAt > this.instanceTimeout) {
                this.logger.warn(`[Orchestrator] Killing stuck instance ${id}`);
                if (instance.process) {
                    instance.process.kill('SIGKILL');
                }
                this.cleanupInstance(id);
            }
        }

        // Update active worker count
        if (this.monitoring) {
            this.monitoring.metrics.system.activeWorkers = this.activeTasks.size;
        }
    }

    /**
     * Clean up an instance
     */
    async cleanupInstance(instanceId) {
        const instance = this.instances.get(instanceId);
        if (!instance) return;

        // Clean up workspace
        try {
            await fs.rm(instance.workspace, { recursive: true, force: true });
        } catch (error) {
            this.logger.error(`[Orchestrator] Failed to clean workspace: ${error.message}`);
        }

        // Kill process if still running
        if (instance.process && !instance.process.killed) {
            instance.process.kill();
        }

        this.instances.delete(instanceId);
    }

    /**
     * Get task status
     */
    getTaskStatus(taskId) {
        // Check active tasks
        const active = this.activeTasks.get(taskId);
        if (active) {
            return {
                status: active.status,
                progress: this.progressReporter?.getTracker(taskId)?.overallProgress || 0,
                startedAt: active.startedAt
            };
        }

        // Check history
        const history = this.taskHistory.get(taskId);
        if (history) {
            return {
                status: history.status,
                progress: 100,
                startedAt: history.startedAt,
                completedAt: history.completedAt,
                duration: history.duration,
                result: history.result,
                error: history.error
            };
        }

        // Check pending
        const pending = this.pendingTasks.find(t => t.id === taskId);
        if (pending) {
            return {
                status: 'pending',
                progress: 0,
                submittedAt: pending.submittedAt,
                position: this.pendingTasks.indexOf(pending) + 1
            };
        }

        return null;
    }

    /**
     * Cancel a task
     */
    async cancelTask(taskId) {
        // Check pending
        const pendingIdx = this.pendingTasks.findIndex(t => t.id === taskId);
        if (pendingIdx >= 0) {
            this.pendingTasks.splice(pendingIdx, 1);
            this.emit('task:cancelled', { taskId, reason: 'user_request' });
            return true;
        }

        // Check active
        const active = this.activeTasks.get(taskId);
        if (active) {
            // Find and kill the instance
            for (const [id, instance] of this.instances) {
                if (instance.taskId === taskId && instance.process) {
                    instance.process.kill('SIGTERM');
                    break;
                }
            }

            active.status = 'cancelled';
            this.activeTasks.delete(taskId);
            this.emit('task:cancelled', { taskId, reason: 'user_request' });
            return true;
        }

        return false;
    }

    /**
     * Get orchestrator status
     */
    getStatus() {
        return {
            pendingTasks: this.pendingTasks.length,
            activeTasks: this.activeTasks.size,
            completedTasks: this.taskHistory.size,
            activeInstances: this.instances.size,
            maxInstances: this.maxInstances,
            tasks: {
                pending: this.pendingTasks.map(t => ({ id: t.id, type: t.type, priority: t.priority })),
                active: Array.from(this.activeTasks.values()).map(t => ({
                    id: t.id,
                    type: t.type,
                    status: t.status,
                    startedAt: t.startedAt
                }))
            }
        };
    }

    /**
     * Shutdown orchestrator
     */
    async shutdown() {
        this.logger.info('[Orchestrator] Shutting down...');

        clearInterval(this.managementInterval);

        // Cancel pending tasks
        for (const task of this.pendingTasks) {
            this.emit('task:cancelled', { taskId: task.id, reason: 'shutdown' });
        }
        this.pendingTasks = [];

        // Kill active instances
        for (const [id, instance] of this.instances) {
            if (instance.process && !instance.process.killed) {
                instance.process.kill('SIGTERM');
            }
            await this.cleanupInstance(id);
        }

        this.removeAllListeners();
        this.logger.info('[Orchestrator] Shutdown complete');
    }
}

export { ClaudeCodeOrchestrator };
