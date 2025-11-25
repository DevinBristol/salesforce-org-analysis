// src/phase2/plan-generator.js
// Generates execution plans from parsed command intents

export class PlanGenerator {
  constructor(workerPool, taskQueue, costTracker) {
    this.workerPool = workerPool;
    this.taskQueue = taskQueue;
    this.costTracker = costTracker;
  }

  /**
   * Generate execution plan from command intent
   * @param {Object} intent - Parsed command intent
   * @param {Object} systemState - Current system state
   * @returns {Object} Execution plan with mobile-friendly formatting
   */
  async generatePlan(intent, systemState = {}) {
    const { command, parameters } = intent;

    // Route to appropriate plan generator based on command
    switch (command) {
      case 'status':
        return this.generateStatusPlan(systemState);

      case 'improve-tests':
        return this.generateImproveTestsPlan(parameters, systemState);

      case 'generate-tests':
        return this.generateGenerateTestsPlan(parameters, systemState);

      case 'comprehensive-improve':
        return this.generateComprehensivePlan(parameters, systemState);

      case 'analyze-org':
        return this.generateAnalyzeOrgPlan(parameters, systemState);

      case 'coverage-report':
        return this.generateCoverageReportPlan(systemState);

      case 'deploy-queue':
        return this.generateDeploymentPlan(parameters, systemState);

      case 'quality-scan':
        return this.generateQualityScanPlan(parameters, systemState);

      case 'cost':
        return this.generateCostReportPlan(systemState);

      default:
        return this.generateSimplePlan(command, parameters);
    }
  }

  /**
   * Generate plan for improving tests
   */
  async generateImproveTestsPlan(parameters, systemState) {
    const count = parameters.count || 10;
    const estimatedCost = count * 0.25; // $0.25 per test improvement
    const estimatedTime = Math.ceil(count * 2); // 2 min per test

    return {
      type: 'improve-tests',
      title: '🔧 Test Improvement Plan',
      description: `Improve ${count} existing test classes`,
      actions: [
        `Analyze ${count} lowest-scoring tests`,
        'Apply best practices and bulkification',
        'Validate all improvements',
        'Prepare for deployment'
      ],
      impact: {
        tests: `${count} test classes`,
        estimated: `Score improvement: +20-30 points average`
      },
      resources: {
        cost: `$${estimatedCost.toFixed(2)}`,
        time: `~${estimatedTime} minutes`,
        workers: 3
      },
      requiresApproval: true,
      approvalText: 'APPROVE',
      command: `/sf-dev improve-tests ${count}`
    };
  }

  /**
   * Generate plan for generating new tests
   */
  async generateGenerateTestsPlan(parameters, systemState) {
    const count = parameters.count || 10;
    const coverage = parameters.coverage || 100;
    const estimatedCost = count * 0.35; // $0.35 per test generation
    const estimatedTime = Math.ceil(count * 3); // 3 min per test

    return {
      type: 'generate-tests',
      title: '⚡ Test Generation Plan',
      description: `Generate ${count} new test classes`,
      actions: [
        `Find ${count} classes with lowest coverage`,
        `Generate comprehensive tests (${coverage}% target)`,
        'Include bulkification and edge cases',
        'Validate syntax and coverage'
      ],
      impact: {
        tests: `${count} new test classes`,
        estimated: `Coverage increase: ~5-10%`
      },
      resources: {
        cost: `$${estimatedCost.toFixed(2)}`,
        time: `~${estimatedTime} minutes`,
        workers: 3
      },
      requiresApproval: true,
      approvalText: 'APPROVE',
      command: `/sf-dev generate-tests ${count} --coverage=${coverage}`
    };
  }

  /**
   * Generate plan for comprehensive improvement
   */
  async generateComprehensivePlan(parameters, systemState) {
    const targetCoverage = parameters.targetCoverage || 90;
    const currentCoverage = systemState.coverage || 79;
    const gap = targetCoverage - currentCoverage;

    return {
      type: 'comprehensive-improve',
      title: '🚀 Comprehensive Improvement Plan',
      description: `Improve org coverage: ${currentCoverage}% → ${targetCoverage}%`,
      phases: [
        {
          name: 'Phase 1: Improve Tests',
          actions: ['Improve 12 low-quality tests', 'Apply best practices'],
          cost: '$3.20',
          time: '15 min'
        },
        {
          name: 'Phase 2: Generate Tests',
          actions: ['Generate 8 missing tests', 'Target untested classes'],
          cost: '$2.40',
          time: '12 min'
        },
        {
          name: 'Phase 3: Deploy',
          actions: ['Deploy to Devin1', 'Run all tests', 'Verify coverage'],
          cost: '$0.00',
          time: '5 min'
        }
      ],
      impact: {
        coverage: `${currentCoverage}% → ${targetCoverage}%`,
        tests: '20 test classes affected'
      },
      resources: {
        cost: '$5.60',
        time: '~32 minutes',
        workers: 3
      },
      requiresApproval: true,
      approvalText: 'APPROVE',
      command: `/sf-dev comprehensive-improve --target-coverage=${targetCoverage}`
    };
  }

  /**
   * Generate simple status report (no approval needed)
   */
  generateStatusPlan(systemState) {
    return {
      type: 'status',
      title: '📊 System Status',
      description: null,
      status: {
        workers: systemState.activeWorkers || 3,
        queue: systemState.queueSize || 0,
        cost: `$${(systemState.costToday || 0).toFixed(2)}`,
        health: 'Healthy'
      },
      requiresApproval: false,
      isInfo: true
    };
  }

  /**
   * Generate plan for org analysis
   */
  generateAnalyzeOrgPlan(parameters, systemState) {
    const deep = parameters.deep || false;

    return {
      type: 'analyze-org',
      title: '🔍 Org Analysis Plan',
      description: deep ? 'Deep analysis of entire org' : 'Quick org analysis',
      actions: [
        'Scan all Apex classes and triggers',
        'Analyze test coverage by class',
        'Identify technical debt',
        'Generate recommendations report'
      ],
      impact: {
        scope: deep ? 'Deep analysis (all code)' : 'Quick scan',
        output: 'Detailed analysis report'
      },
      resources: {
        cost: deep ? '$2.50' : '$0.80',
        time: deep ? '~15 minutes' : '~5 minutes',
        workers: 1
      },
      requiresApproval: false,
      command: deep ? '/sf-dev analyze-org --deep' : '/sf-dev analyze-org'
    };
  }

  /**
   * Generate deployment plan
   */
  async generateDeploymentPlan(parameters, systemState) {
    const validateOnly = parameters.validateOnly || false;
    const readyCount = systemState.readyToDeploy || 0;

    return {
      type: 'deploy-queue',
      title: '🚀 Deployment Plan',
      description: validateOnly ? 'Validate deployment (dry run)' : 'Deploy to Devin1 sandbox',
      actions: [
        `Deploy ${readyCount} test classes`,
        'Run all tests in org',
        'Verify coverage impact',
        validateOnly ? 'Dry run only (no changes)' : 'Update sandbox'
      ],
      impact: {
        target: 'Devin1 sandbox',
        files: `${readyCount} test classes`,
        coverage: 'Expected +5-10%'
      },
      resources: {
        cost: '$0.00',
        time: '~3 minutes',
        workers: 0
      },
      requiresApproval: !validateOnly,
      approvalText: 'DEPLOY',
      command: validateOnly ? '/sf-dev deploy-queue --validate-only' : '/sf-dev deploy-queue'
    };
  }

  /**
   * Generate quality scan plan
   */
  generateQualityScanPlan(parameters, systemState) {
    const className = parameters.className || 'specified class';

    return {
      type: 'quality-scan',
      title: '📋 Quality Scan Plan',
      description: `Analyze quality of ${className}`,
      actions: [
        'Scan for best practice violations',
        'Check bulkification',
        'Analyze assertion quality',
        'Generate improvement recommendations'
      ],
      impact: {
        scope: `1 test class (${className})`,
        output: 'Quality score and recommendations'
      },
      resources: {
        cost: '$0.15',
        time: '~2 minutes',
        workers: 1
      },
      requiresApproval: false,
      command: `/sf-dev quality-scan ${className}`
    };
  }

  /**
   * Generate coverage report plan
   */
  generateCoverageReportPlan(systemState) {
    return {
      type: 'coverage-report',
      title: '📊 Coverage Report',
      description: 'Generate detailed coverage breakdown',
      actions: [
        'Fetch coverage for all classes',
        'Identify low-coverage areas',
        'Categorize by package',
        'Generate interactive report'
      ],
      impact: {
        scope: 'All Apex classes',
        output: 'Coverage breakdown with recommendations'
      },
      resources: {
        cost: '$0.00',
        time: '~1 minute',
        workers: 0
      },
      requiresApproval: false,
      isInfo: true,
      command: '/sf-dev coverage-report'
    };
  }

  /**
   * Generate cost report plan
   */
  generateCostReportPlan(systemState) {
    return {
      type: 'cost',
      title: '💰 Cost Report',
      description: 'Current spending and budget status',
      isInfo: true,
      requiresApproval: false,
      command: '/sf-dev cost'
    };
  }

  /**
   * Generate simple plan for unknown commands
   */
  generateSimplePlan(command, parameters) {
    return {
      type: command,
      title: `Execute: ${command}`,
      description: `Run ${command} command`,
      parameters,
      requiresApproval: true,
      approvalText: 'APPROVE',
      command: `/sf-dev ${command}`
    };
  }
}
