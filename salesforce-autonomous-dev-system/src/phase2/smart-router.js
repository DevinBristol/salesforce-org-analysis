// src/phase2/smart-router.js
// Smart Router - Routes intents to appropriate worker pool (Salesforce or Local)

export class SmartRouter {
  constructor(salesforceWorkerPool, localWorkerPool, taskQueue) {
    this.salesforceWorkerPool = salesforceWorkerPool;
    this.localWorkerPool = localWorkerPool;
    this.taskQueue = taskQueue;
  }

  /**
   * Route an intent to the appropriate execution path
   * @param {Object} intent - Parsed intent from NLCommandParser
   * @returns {Object} Routing decision with worker type and task details
   */
  route(intent) {
    const { operationType, command, parameters } = intent;

    // Determine worker type
    const workerType = operationType === 'local' ? 'local' : 'salesforce';

    // Map command to task type
    const taskType = this.mapCommandToTaskType(command, operationType);

    // Build task payload
    const payload = this.buildTaskPayload(command, parameters, operationType);

    return {
      workerType,
      taskType,
      payload,
      priority: this.calculatePriority(command, operationType),
      estimatedCost: this.estimateCost(taskType, payload),
      estimatedTime: this.estimateTime(taskType, payload)
    };
  }

  /**
   * Map natural language command to worker task type
   * @param {string} command - Command from intent
   * @param {string} operationType - 'salesforce' or 'local'
   */
  mapCommandToTaskType(command, operationType) {
    if (operationType === 'salesforce') {
      const salesforceMapping = {
        'improve-tests': 'improve-test',
        'generate-tests': 'generate-test',
        'quality-scan': 'quality-scan',
        'rewrite-test': 'rewrite-test',
        'analyze-org': 'analyze-org',
        'coverage-report': 'coverage-analysis',
        'comprehensive-improve': 'comprehensive-improve',
        'deploy-queue': 'deploy-all',
        'validate-deployment': 'validate-deployment',
        'find-issues': 'analyze-code'
      };

      return salesforceMapping[command] || command;
    }

    if (operationType === 'local') {
      const localMapping = {
        'analyze-codebase': 'analyze-codebase',
        'search-code': 'search-code',
        'find-files': 'find-pattern',
        'edit-files': 'edit-files',
        'refactor-code': 'refactor-code',
        'rename-symbol': 'rename-symbol',
        'git-status': 'git-status',
        'git-commit': 'git-commit',
        'git-push': 'git-push',
        'git-create-branch': 'git-create-branch',
        'git-diff': 'git-diff',
        'run-tests': 'run-tests',
        'run-build': 'run-build'
      };

      return localMapping[command] || command;
    }

    return command;
  }

  /**
   * Build task payload from parameters
   * @param {string} command - Command from intent
   * @param {Object} parameters - Parameters from intent
   * @param {string} operationType - 'salesforce' or 'local'
   */
  buildTaskPayload(command, parameters, operationType) {
    const payload = { ...parameters };

    // Add default repo for local operations if not specified
    if (operationType === 'local' && !payload.repo) {
      payload.repo = 'salesforce-autonomous-dev-system';
    }

    // Command-specific payload adjustments
    switch (command) {
      case 'improve-tests':
      case 'generate-tests':
        if (!payload.count) payload.count = 10;
        break;

      case 'comprehensive-improve':
        if (!payload.targetCoverage) payload.targetCoverage = 90;
        break;

      case 'analyze-codebase':
        if (!payload.scope) payload.scope = 'full';
        break;

      case 'search-code':
        if (!payload.filePattern) payload.filePattern = '**/*.js';
        break;

      case 'edit-files':
        if (!payload.files) payload.files = [];
        break;

      case 'git-commit':
        if (!payload.files) payload.files = '.';
        break;

      case 'run-tests':
        if (!payload.testCommand) payload.testCommand = 'npm test';
        break;

      case 'run-build':
        if (!payload.buildCommand) payload.buildCommand = 'npm run build';
        break;
    }

    return payload;
  }

  /**
   * Calculate task priority (1=highest, 3=lowest)
   * @param {string} command - Command from intent
   * @param {string} operationType - 'salesforce' or 'local'
   */
  calculatePriority(command, operationType) {
    // High priority commands (priority 1)
    const highPriority = ['deploy-queue', 'rollback', 'git-push', 'validate-deployment'];
    if (highPriority.includes(command)) return 1;

    // Medium priority commands (priority 2)
    const mediumPriority = ['comprehensive-improve', 'analyze-org', 'analyze-codebase', 'refactor-code'];
    if (mediumPriority.includes(command)) return 2;

    // Default priority (priority 3)
    return 3;
  }

  /**
   * Estimate API cost for a task
   * @param {string} taskType - Task type
   * @param {Object} payload - Task payload
   */
  estimateCost(taskType, payload) {
    const costEstimates = {
      // Salesforce operations
      'improve-test': 0.20,
      'generate-test': 0.30,
      'quality-scan': 0.10,
      'rewrite-test': 0.25,
      'analyze-org': 0.50,
      'coverage-analysis': 0.15,
      'comprehensive-improve': 5.00,
      'deploy-all': 0.05,

      // Local operations
      'analyze-codebase': 0.40,
      'search-code': 0.05,
      'find-pattern': 0.02,
      'edit-files': 0.30,
      'refactor-code': 0.50,
      'rename-symbol': 0.10,
      'git-status': 0.00,
      'git-commit': 0.00,
      'git-push': 0.00,
      'git-diff': 0.00,
      'run-tests': 0.00,
      'run-build': 0.00
    };

    const baseCost = costEstimates[taskType] || 0.10;

    // Adjust for count if present
    if (payload.count) {
      return baseCost * payload.count;
    }

    // Adjust for multiple files
    if (payload.files && Array.isArray(payload.files)) {
      return baseCost * Math.max(1, payload.files.length * 0.5);
    }

    return baseCost;
  }

  /**
   * Estimate time for a task (in minutes)
   * @param {string} taskType - Task type
   * @param {Object} payload - Task payload
   */
  estimateTime(taskType, payload) {
    const timeEstimates = {
      // Salesforce operations
      'improve-test': 2,
      'generate-test': 3,
      'quality-scan': 1,
      'rewrite-test': 3,
      'analyze-org': 5,
      'coverage-analysis': 2,
      'comprehensive-improve': 30,
      'deploy-all': 5,

      // Local operations
      'analyze-codebase': 3,
      'search-code': 0.5,
      'find-pattern': 0.5,
      'edit-files': 2,
      'refactor-code': 4,
      'rename-symbol': 1,
      'git-status': 0.1,
      'git-commit': 0.2,
      'git-push': 0.5,
      'git-diff': 0.1,
      'run-tests': 1,
      'run-build': 2
    };

    const baseTime = timeEstimates[taskType] || 1;

    // Adjust for count if present
    if (payload.count) {
      return baseTime * payload.count;
    }

    // Adjust for multiple files
    if (payload.files && Array.isArray(payload.files)) {
      return baseTime * Math.max(1, payload.files.length * 0.7);
    }

    return baseTime;
  }

  /**
   * Queue a task based on routing decision
   * @param {Object} routingDecision - Result from route()
   * @param {string} userId - Slack user ID
   */
  async queueTask(routingDecision, userId = null) {
    const { workerType, taskType, payload, priority } = routingDecision;

    const task = {
      type: taskType,
      workerType, // Tag task with worker type
      priority,
      payload,
      userId,
      createdAt: Date.now()
    };

    // Add to task queue
    const taskId = await this.taskQueue.add(task);

    return {
      taskId,
      ...routingDecision
    };
  }

  /**
   * Execute a task immediately (bypass queue)
   * @param {Object} routingDecision - Result from route()
   */
  async executeImmediate(routingDecision) {
    const { workerType, taskType, payload } = routingDecision;

    const workerPool = workerType === 'local'
      ? this.localWorkerPool
      : this.salesforceWorkerPool;

    // Execute task directly
    const result = await workerPool.executeTask({
      type: taskType,
      payload
    });

    return result;
  }

  /**
   * Get routing statistics
   */
  getStats() {
    return {
      salesforceQueueSize: this.taskQueue.getQueueSizeByType('salesforce'),
      localQueueSize: this.taskQueue.getQueueSizeByType('local'),
      totalQueueSize: this.taskQueue.getQueueSize()
    };
  }

  /**
   * Validate if a command requires approval
   * @param {string} command - Command from intent
   * @param {string} operationType - 'salesforce' or 'local'
   */
  requiresApproval(command, operationType) {
    // Commands that require approval
    const approvalRequired = [
      // Salesforce - high risk
      'deploy-queue',
      'rollback',
      'comprehensive-improve',
      'generate-tests',
      'clear-failed',

      // Local - high risk
      'refactor-code',
      'edit-files',
      'git-push',
      'git-commit',
      'rename-symbol'
    ];

    return approvalRequired.includes(command);
  }

  /**
   * Check if command is info-only (no side effects)
   * @param {string} command - Command from intent
   */
  isInfoOnly(command) {
    const infoOnlyCommands = [
      'status',
      'cost',
      'coverage-report',
      'queue-status',
      'help',
      'analyze-org',
      'analyze-codebase',
      'search-code',
      'find-files',
      'git-status',
      'git-diff',
      'quality-scan'
    ];

    return infoOnlyCommands.includes(command);
  }

  /**
   * Get recommended follow-up commands
   * @param {string} completedCommand - Command that just completed
   * @param {string} operationType - 'salesforce' or 'local'
   */
  getRecommendedFollowUps(completedCommand, operationType) {
    const followUps = {
      'analyze-org': ['improve-tests', 'generate-tests'],
      'analyze-codebase': ['refactor-code', 'search-code'],
      'quality-scan': ['improve-tests', 'rewrite-test'],
      'improve-tests': ['deploy-queue', 'validate-deployment'],
      'refactor-code': ['run-tests', 'git-commit'],
      'edit-files': ['run-tests', 'git-diff'],
      'git-status': ['git-commit', 'git-diff'],
      'git-commit': ['git-push'],
      'run-tests': ['git-commit', 'deploy-queue']
    };

    return followUps[completedCommand] || [];
  }
}

export default SmartRouter;
