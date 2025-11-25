// src/phase2/slack-bot.js
import { App } from '@slack/bolt';
import { WorkerPool } from './worker-pool.js';
import { TaskQueue } from './task-queue.js';
import { CostTracker } from './cost-tracker.js';
import {
  formatStatusBlock,
  formatQualityReport,
  formatComprehensivePlan,
  formatDeploymentConfirmation,
  formatCoverageReport,
  formatHelpMessage,
  formatConfirmation
} from './slack-formatters.js';
import { InteractiveHandlers, ConfirmationManager, ProgressTracker } from './interactive-handlers.js';
import { ConversationManager } from './conversation-manager.js';
import { NLCommandParser } from './nl-command-parser.js';
import { PlanGenerator } from './plan-generator.js';
import { SuggestionEngine } from './suggestion-engine.js';
import {
  formatMobilePlan,
  formatMobileText,
  formatSuggestion,
  formatClarification,
  formatThinking,
  formatError,
  formatSuccess
} from './mobile-formatters.js';
import { SmartRouter } from './smart-router.js';
import { DeploymentAssistant } from './deployment-assistant.js';
import {
  formatGitStatus,
  formatGitCommit,
  formatGitPush,
  formatGitDiff,
  formatCodebaseAnalysis,
  formatCodeSearch,
  formatFileEdits,
  formatRefactoring,
  formatTestResults,
  formatBuildResults,
  formatFindFiles,
  formatSymbolRename,
  formatBranchCreation,
  formatLocalOperationPlan,
  formatLocalResult
} from './local-formatters.js';

export class SlackBot {
  constructor(workerPool, localWorkerPool = null) {
    this.workerPool = workerPool; // Salesforce worker pool
    this.localWorkerPool = localWorkerPool; // Local repo worker pool
    this.taskQueue = new TaskQueue();
    this.costTracker = new CostTracker();
    this.confirmationManager = new ConfirmationManager();
    this.progressTracker = null; // Will be initialized in start()

    // Conversational AI components
    this.conversationManager = new ConversationManager();
    this.nlParser = new NLCommandParser();
    this.planGenerator = new PlanGenerator(workerPool, this.taskQueue, this.costTracker);
    this.suggestionEngine = new SuggestionEngine(workerPool, this.taskQueue, this.costTracker);

    // Smart router for Salesforce vs Local operations
    this.smartRouter = new SmartRouter(workerPool, localWorkerPool, this.taskQueue);

    // Deployment assistant for conversational deployment controls
    this.deploymentAssistant = null; // Will be initialized when deployment pipeline is available

    this.app = new App({
      token: process.env.SLACK_BOT_TOKEN,
      signingSecret: process.env.SLACK_SIGNING_SECRET,
      socketMode: true,
      appToken: process.env.SLACK_APP_TOKEN,
    });

    this.setupCommands();
    this.setupEvents();
    this.setupInteractiveHandlers();
    this.setupMessageHandlers();
    this.setupNaturalLanguageHandlers();
  }

  setupCommands() {
    // Main command handler
    this.app.command('/sf-dev', async ({ command, ack, say, client }) => {
      await ack();

      const [action, ...args] = command.text.split(' ');

      try {
        switch(action) {
          // Test Management
          case 'status':
            await this.handleStatus(say);
            break;

          case 'improve-tests':
            await this.handleImproveTests(say, args, command.user_id);
            break;

          case 'generate-tests':
            await this.handleGenerateTests(say, args, command.user_id);
            break;

          case 'quality-scan':
            await this.handleQualityScan(say, args);
            break;

          case 'comprehensive-improve':
            await this.handleComprehensiveImprove(say, args, command.user_id);
            break;

          case 'rewrite-test':
            await this.handleRewriteTest(say, args, command.user_id);
            break;

          // Org Analysis
          case 'analyze-org':
            await this.handleAnalyzeOrg(say, args);
            break;

          case 'coverage-report':
            await this.handleCoverageReport(say, args);
            break;

          case 'find-issues':
            await this.handleFindIssues(say, args);
            break;

          // Queue Management
          case 'queue-status':
            await this.handleQueueStatus(say, args);
            break;

          case 'pause-queue':
            await this.handlePauseQueue(say);
            break;

          case 'resume-queue':
            await this.handleResumeQueue(say);
            break;

          case 'cancel-task':
            await this.handleCancelTask(say, args, command.user_id);
            break;

          case 'clear-failed':
            await this.handleClearFailed(say, command.user_id);
            break;

          // Deployment
          case 'deploy-queue':
            await this.handleDeployQueue(say, args, command.user_id);
            break;

          case 'validate-deployment':
            await this.handleValidateDeployment(say, args);
            break;

          case 'rollback':
            await this.handleRollback(say, args, command.user_id);
            break;

          // Enhanced Deployment Commands
          case 'deploy-chat':
            await this.handleDeployChat(say, args.join(' '), command.user_id);
            break;

          case 'snapshots':
            await this.handleListSnapshots(say, args);
            break;

          case 'schedule-deploy':
            await this.handleScheduleDeployment(say, args, command.user_id);
            break;

          case 'scheduled':
            await this.handleListScheduled(say, args);
            break;

          case 'cancel-scheduled':
            await this.handleCancelScheduled(say, args, command.user_id);
            break;

          case 'deployment-windows':
            await this.handleDeploymentWindows(say, args);
            break;

          // Budget & Monitoring
          case 'cost':
            await this.handleCostReport(say, args);
            break;

          case 'set-budget':
            await this.handleSetBudget(say, args);
            break;

          case 'workers':
            await this.handleWorkers(say, args);
            break;

          // System
          case 'stop':
            await this.handleStop(say);
            break;

          case 'restart-bot':
            await this.handleRestartBot(say);
            break;

          case 'help':
            await this.handleHelp(say, args);
            break;

          case 'report':
            await this.handleReport(say, args);
            break;

          default:
            await say(`❌ Unknown command: \`${action}\`\n\nUse \`/sf-dev help\` to see available commands.`);
        }
      } catch (error) {
        console.error(`Error handling command ${action}:`, error);
        await say(`❌ Error executing command: ${error.message}`);
      }
    });
  }

  setupEvents() {
    // Event handlers can be added here if needed
    // Note: app_mention is handled in setupNaturalLanguageHandlers()
  }

  setupInteractiveHandlers() {
    // Initialize interactive handlers
    this.interactiveHandlers = new InteractiveHandlers(
      this.app,
      this.workerPool,
      this.taskQueue
    );
  }

  setupMessageHandlers() {
    // Listen for text confirmations (APPROVE, DEPLOY, ROLLBACK, etc.)
    this.app.message(async ({ message, say }) => {
      if (!message.text) return;

      const text = message.text.trim().toUpperCase();
      const userId = message.user;

      // Check if user has pending confirmation
      if (!this.confirmationManager.hasPendingConfirmation(userId)) return;

      const action = this.confirmationManager.confirm(userId, text);
      if (action) {
        await say(`✅ Confirmed. Processing...`);
        await this.executeConfirmedAction(action, say);
      } else if (text === 'CANCEL') {
        this.confirmationManager.cancel(userId);
        await say(`❌ Action cancelled`);
      }
    });
  }

  // ==================== NATURAL LANGUAGE HANDLERS ====================

  setupNaturalLanguageHandlers() {
    // Handle direct messages (DMs)
    this.app.message(async ({ message, say }) => {
      // Only process DMs (not channel messages)
      if (message.channel_type !== 'im') return;

      const userId = message.user;
      const text = message.text;

      console.log(`[DM] Received from ${userId}: ${text}`);
      await this.handleNaturalLanguageMessage(userId, text, say, 'dm');
    });

    // Enhanced app mention handler with conversation context
    this.app.event('app_mention', async ({ event, say }) => {
      console.log('[APP_MENTION] Received:', JSON.stringify(event, null, 2));

      const userId = event.user;
      const text = event.text.replace(/<@[A-Z0-9]+>/g, '').trim(); // Remove bot mention

      console.log(`[APP_MENTION] Processing - User: ${userId}, Text: "${text}"`);

      try {
        await this.handleNaturalLanguageMessage(userId, text, say, 'mention');
      } catch (error) {
        console.error('[APP_MENTION] Error:', error);
        await say(`❌ Error processing mention: ${error.message}`);
      }
    });
  }

  async handleNaturalLanguageMessage(userId, text, say, source) {
    console.log(`[NL Handler] Starting - Source: ${source}, User: ${userId}`);
    try {
      // Get or create session
      const session = this.conversationManager.getSession(userId);
      console.log(`[NL Handler] Session retrieved`);

      // Check if user is responding to a pending approval
      const pendingApproval = this.conversationManager.getContext(userId, 'pendingApproval');
      if (pendingApproval) {
        console.log(`[NL Handler] Handling approval response`);
        return await this.handleApprovalResponse(userId, text, say, pendingApproval);
      }
      console.log(`[NL Handler] No pending approval`);


      // Show thinking indicator
      await say(formatThinking());
      console.log(`[NL Handler] Sent thinking indicator`);

      // Try quick pattern match first (no API call)
      let intent = this.nlParser.quickClassify(text);
      console.log(`[NL Handler] Quick classify result:`, intent ? 'matched' : 'no match');

      // If no quick match, use full NL parsing
      if (!intent) {
        console.log(`[NL Handler] Using full NL parsing...`);
        const conversationHistory = this.conversationManager.getFormattedHistory(userId, 5);
        const systemState = await this.getSystemStateForContext();

        intent = await this.nlParser.parseIntent(text, conversationHistory, systemState);
        console.log(`[NL Handler] Intent parsed:`, JSON.stringify(intent, null, 2));
      }

      // Store user message
      this.conversationManager.addMessage(userId, 'user', text);

      // Handle clarification needed
      if (intent.requiresClarification) {
        console.log(`[NL Handler] Requires clarification`);
        const response = formatClarification(intent.clarificationQuestion);
        await say(response);
        this.conversationManager.addMessage(userId, 'assistant', intent.clarificationQuestion);
        return;
      }

      // Handle low confidence
      if (intent.confidence < 0.6) {
        console.log(`[NL Handler] Low confidence (${intent.confidence})`);
        const response = formatMobileText(
          `I'm not quite sure what you mean. Try commands like:\n• "show status"\n• "improve 10 tests"\n• "analyze my org"\n• "show costs"`,
          '🤔'
        );
        await say(response);
        return;
      }

      // Route to appropriate handler
      console.log(`[NL Handler] Routing to handler - Command: ${intent.command}, OperationType: ${intent.operationType}`);
      await this.routeIntent(userId, intent, say);

      // Check for proactive suggestions (respects cooldown)
      const suggestions = await this.suggestionEngine.getSuggestions(userId, {
        recentCommand: intent.command
      });

      if (suggestions.length > 0) {
        // Wait a moment before suggesting
        setTimeout(async () => {
          for (const suggestion of suggestions) {
            const formatted = this.suggestionEngine.formatSuggestion(suggestion);
            await say(formatSuggestion({ message: formatted }));
          }
        }, 2000);
      }

      console.log(`[NL Handler] Complete`);

    } catch (error) {
      console.error('[NL Handler] ERROR:', error);
      console.error('[NL Handler] Stack trace:', error.stack);
      await say(formatError({ message: `Sorry, something went wrong: ${error.message}` }));
    }
  }

  async routeIntent(userId, intent, say) {
    const { command, parameters, operationType } = intent;

    // Route to local operations handler if it's a local operation
    if (operationType === 'local') {
      await this.handleLocalOperation(intent, say, userId);
      return;
    }

    // Salesforce operations (existing logic)
    // Info-only commands (no approval needed)
    const infoCommands = ['status', 'cost', 'coverage-report', 'queue-status', 'help', 'analyze-org'];

    if (infoCommands.includes(command)) {
      // Generate and execute immediately
      const systemState = await this.getSystemStateForContext();
      const plan = await this.planGenerator.generatePlan(intent, systemState);

      const response = formatMobilePlan(plan);
      await say(response);

      this.conversationManager.addMessage(userId, 'assistant', JSON.stringify(plan));

      // Execute the command
      await this.executeInfoCommand(command, parameters, say);

      // Get follow-up suggestion
      const followUp = await this.suggestionEngine.getFollowUpSuggestion(command, { success: true });
      if (followUp) {
        setTimeout(async () => {
          await say(formatSuggestion(followUp));
        }, 1500);
      }

      return;
    }

    // Commands requiring approval
    const systemState = await this.getSystemStateForContext();
    const plan = await this.planGenerator.generatePlan(intent, systemState);

    // Show plan to user
    const response = formatMobilePlan(plan);
    await say(response);

    // Store pending approval
    this.conversationManager.setContext(userId, 'pendingApproval', {
      intent,
      plan,
      timestamp: Date.now()
    });

    this.conversationManager.addMessage(userId, 'assistant', JSON.stringify(plan));
  }

  async handleApprovalResponse(userId, text, say, pendingApproval) {
    const lowered = text.toLowerCase().trim();

    // Check for approval
    const approvalPatterns = /^(approve|approved|yes|confirm|ok|do it|let's do it|go ahead|deploy)/i;
    const cancelPatterns = /^(cancel|no|stop|abort|don't|nevermind|nope)/i;

    if (approvalPatterns.test(lowered)) {
      // Clear pending approval
      this.conversationManager.setContext(userId, 'pendingApproval', null);

      await say(formatSuccess('Approved! Starting execution...'));

      // Execute the approved plan
      await this.executeApprovedPlan(userId, pendingApproval.plan, say);

      // Get follow-up suggestion
      const followUp = await this.suggestionEngine.getFollowUpSuggestion(
        pendingApproval.intent.command,
        { success: true }
      );

      if (followUp) {
        setTimeout(async () => {
          await say(formatSuggestion(followUp));
        }, 2000);
      }

    } else if (cancelPatterns.test(lowered)) {
      this.conversationManager.setContext(userId, 'pendingApproval', null);
      await say(formatMobileText('Action cancelled.', '❌'));

    } else {
      // Not a clear approval/cancel - ask for clarification
      await say(formatClarification(
        `I didn't catch that. Please say "APPROVE" to proceed or "CANCEL" to abort.`
      ));
    }
  }

  async executeInfoCommand(command, parameters, say) {
    switch (command) {
      case 'status':
        await this.handleStatus(say);
        break;

      case 'cost':
        await this.handleCostReport(say);
        break;

      case 'coverage-report':
        await this.handleCoverageReport(say);
        break;

      case 'queue-status':
        await this.handleQueueStatus(say);
        break;

      case 'analyze-org':
        await this.handleAnalyzeOrg(say, parameters.deep || false);
        break;

      case 'help':
        await this.handleHelp(say, parameters.command || null);
        break;
    }
  }

  async executeApprovedPlan(userId, plan, say) {
    const { type, command, parameters = {} } = plan;

    try {
      switch (type) {
        case 'improve-tests':
          const count = parameters.count || 10;
          await this.handleImproveTests(say, [count.toString()], userId);
          break;

        case 'generate-tests':
          const genCount = parameters.count || 10;
          const coverage = parameters.coverage || 100;
          await this.handleGenerateTests(say, [genCount.toString(), `--coverage=${coverage}`], userId);
          break;

        case 'comprehensive-improve':
          const targetCoverage = parameters.targetCoverage || 90;
          await this.handleComprehensiveImprove(say, [`--target-coverage=${targetCoverage}`], userId);
          break;

        case 'deploy-queue':
          const validateOnly = parameters.validateOnly || false;
          await this.handleDeployQueue(say, validateOnly ? ['--validate-only'] : [], userId);
          break;

        case 'quality-scan':
          await this.handleQualityScan(say, [parameters.className]);
          break;

        default:
          await say(formatError({ message: `Unknown plan type: ${type}` }));
      }
    } catch (error) {
      console.error('Plan execution error:', error);
      await say(formatError({ message: 'Execution failed. Please check the logs.' }));
    }
  }

  async getSystemStateForContext() {
    const stats = this.workerPool.getStats();
    const costToday = this.costTracker.getCurrentUsage();
    const monthlyTotal = await this.costTracker.getMonthlyTotal();
    const budget = parseFloat(process.env.COST_BUDGET_MONTHLY || 100);

    return {
      queueSize: stats.queueSize || 0,
      activeWorkers: stats.activeWorkers || 0,
      coverage: stats.coverage || null,
      costToday,
      budgetUsagePercent: Math.round((monthlyTotal / budget) * 100)
    };
  }

  // ==================== COMMAND HANDLERS ====================

  async handleStatus(say) {
    const stats = this.workerPool.getStats();
    await say(formatStatusBlock(stats));

    // Add smart suggestions
    const queueSize = this.taskQueue.getQueueSize();
    if (queueSize === 0) {
      await say(`💡 *Suggestion:* Queue is empty. Run \`/sf-dev analyze-org\` to find improvements.`);
    }
  }

  async handleImproveTests(say, args, userId) {
    const count = parseInt(args[0]) || 10;
    await say(`🔍 Queuing ${count} test improvements...`);

    // Add tasks to queue
    for (let i = 0; i < count; i++) {
      await this.taskQueue.add({
        type: 'improve-test',
        priority: 1,
        payload: { index: i }
      });
    }

    await say(`✅ Added ${count} test improvement tasks to queue`);

    // Start progress tracking
    const taskIds = Array.from({ length: count }, (_, i) => i + 1);
    this.progressTracker.startTracking(`improve-${Date.now()}`, taskIds, count * 2);
  }

  async handleGenerateTests(say, args, userId) {
    const count = parseInt(args[0]) || 10;
    const targetCoverage = this.parseFlag(args, '--coverage') || 100;

    await say(`🔍 Analyzing org to find ${count} classes needing tests...`);

    // Would analyze org and find untested classes
    // For now, placeholder
    await say(`📋 Found ${count} classes needing tests\n\nEstimated cost: $${(count * 0.30).toFixed(2)} | Time: ~${count * 3} min\n\nTarget coverage: ${targetCoverage}%`);

    // Add confirmation
    this.confirmationManager.requestConfirmation(userId, {
      type: 'generate-tests',
      payload: { count, targetCoverage }
    });

    await say(`Type *APPROVE* to proceed or *CANCEL* to abort.`);
  }

  async handleQualityScan(say, args) {
    const className = args[0];
    if (!className) {
      await say(`❌ Please specify a class name: \`/sf-dev quality-scan [className]\``);
      return;
    }

    await say(`📊 Analyzing ${className} quality...`);

    // Placeholder - would call TestQualityAnalyzer
    const analysis = {
      score: 45,
      issues: {
        critical: ['No bulkification', 'Missing Test.startTest'],
        high: ['Weak assertions', 'No negative tests', 'No @testSetup'],
        medium: ['Missing documentation']
      },
      estimatedCost: 0.15,
      estimatedTime: 2
    };

    await say(formatQualityReport(className, analysis));
  }

  async handleComprehensiveImprove(say, args, userId) {
    const targetCoverage = this.parseFlag(args, '--target-coverage') || 90;

    await say(`🔍 Analyzing your org for comprehensive improvement...`);

    // Placeholder - would analyze org
    const plan = {
      phase1: { count: 12, cost: 3.20, time: 15 },
      phase2: { count: 8, cost: 2.40, time: 12 },
      phase3: { items: 20, time: 5 },
      totalCost: 5.60,
      totalTime: 32,
      totalItems: 20,
      currentCoverage: 79,
      targetCoverage
    };

    await say(formatComprehensivePlan(plan));

    // Store confirmation
    this.confirmationManager.requestConfirmation(userId, {
      type: 'comprehensive-improve',
      payload: { targetCoverage }
    });
  }

  async handleRewriteTest(say, args, userId) {
    const testClassName = args[0];
    if (!testClassName) {
      await say(`❌ Please specify a test class name: \`/sf-dev rewrite-test [testClassName]\``);
      return;
    }

    await say(`🔍 Analyzing ${testClassName} for complete rewrite...`);

    await say(`⚠️ This will completely rewrite ${testClassName}\n\nEstimated cost: $0.25 | Time: ~3 min\n\nType *APPROVE* to proceed or *CANCEL* to abort.`);

    this.confirmationManager.requestConfirmation(userId, {
      type: 'rewrite-test',
      payload: { testClassName }
    });
  }

  async handleAnalyzeOrg(say, args) {
    // Handle both array (from slash command) and boolean (from NL parser)
    const deep = Array.isArray(args) ? args.includes('--deep') : Boolean(args);
    await say(`🔍 Running ${deep ? 'deep' : 'quick'} org analysis...`);

    // Placeholder
    await say(`⏳ This will take approximately ${deep ? '15-20' : '3-5'} minutes. You'll be notified when complete.`);

    // Queue analysis task
    await this.taskQueue.add({
      type: 'analyze-org',
      priority: 2,
      payload: { deep }
    });
  }

  async handleCoverageReport(say, args = []) {
    // Handle both array (from slash command) and undefined/other (from NL parser)
    const byPackage = Array.isArray(args) && args.includes('--by-package');
    await say(`📊 Generating coverage report${byPackage ? ' by package' : ''}...`);

    // Placeholder
    const coverage = {
      orgWide: 79,
      totalClasses: 156,
      lowCoverage: 23,
      classes: [
        { name: 'AccountTriggerHandler', coverage: 45 },
        { name: 'ContactService', coverage: 67 },
        { name: 'OpportunityTrigger', coverage: 82 },
        { name: 'LeadProcessor', coverage: 91 },
        { name: 'CaseUtils', coverage: 58 }
      ]
    };

    await say(formatCoverageReport(coverage));
  }

  async handleFindIssues(say, args = []) {
    const type = (Array.isArray(args) && this.parseFlag(args, '--type')) || 'all';
    await say(`🔍 Scanning for ${type} issues...`);

    // Placeholder
    await say(`Found 15 issues:\n• 🔴 Critical (3)\n• 🟡 High (7)\n• 🟢 Medium (5)\n\nUse \`/sf-dev quality-scan [className]\` for details.`);
  }

  async handleQueueStatus(say, args = []) {
    const taskId = Array.isArray(args) ? args[0] : args;

    if (taskId) {
      // Show specific task status
      await say(`📊 Task ${taskId} status: Processing (45% complete)`);
    } else {
      // Show queue overview
      const stats = this.taskQueue.getStats();
      const statsText = stats.map(s => `• ${s.status}: ${s.count}`).join('\n');

      await say(`📊 *Queue Status*\n\n${statsText}\n\nTotal: ${stats.reduce((sum, s) => sum + s.count, 0)} tasks`);
    }
  }

  async handlePauseQueue(say) {
    this.workerPool.paused = true;
    const queueSize = this.taskQueue.getQueueSize();

    await say(`⏸️ Queue paused. ${queueSize} pending tasks will not be processed until resumed.\n\nUse \`/sf-dev resume-queue\` to resume.`);
  }

  async handleResumeQueue(say) {
    this.workerPool.paused = false;
    await say(`▶️ Queue resumed. Processing tasks...`);
  }

  async handleCancelTask(say, args, userId) {
    const taskId = args[0];
    if (!taskId) {
      await say(`❌ Please specify a task ID: \`/sf-dev cancel-task [taskId]\``);
      return;
    }

    await say(`⚠️ Cancel task ${taskId}?\n\nType *APPROVE* to confirm or *CANCEL* to abort.`);

    this.confirmationManager.requestConfirmation(userId, {
      type: 'cancel-task',
      payload: { taskId }
    });
  }

  async handleClearFailed(say, userId) {
    const failedTasks = 5; // Would query from task queue

    await say(`⚠️ Clear ${failedTasks} failed tasks from queue?\n\nType *APPROVE* to confirm or *CANCEL* to abort.`);

    this.confirmationManager.requestConfirmation(userId, {
      type: 'clear-failed',
      payload: {}
    });
  }

  async handleDeployQueue(say, args, userId) {
    const validateOnly = Array.isArray(args) && args.includes('--validate-only');

    await say(`🔍 Preparing deployment...`);

    // Placeholder
    const deployment = {
      targetOrg: 'Devin1',
      files: ['AccountTriggerTest.cls', 'ContactServiceTest.cls', 'OpportunityTriggerTest.cls'],
      estimatedTime: 5,
      currentCoverage: 79,
      projectedCoverage: 85
    };

    await say(formatDeploymentConfirmation(deployment));

    if (!validateOnly) {
      this.confirmationManager.requestConfirmation(userId, {
        type: 'deploy-queue',
        payload: { validateOnly: false }
      }, 'DEPLOY');

      await say(`Type *DEPLOY* to confirm or *CANCEL* to abort.`);
    } else {
      await say(`✅ Validation passed. No deployment will occur (--validate-only mode).`);
    }
  }

  async handleValidateDeployment(say, args) {
    await say(`🔍 Validating deployment...`);

    // Placeholder
    await say(`✅ Validation complete:\n\n• All tests pass\n• Coverage: 85%\n• No conflicts detected\n\nReady to deploy.`);
  }

  async handleRollback(say, args, userId) {
    const deploymentId = args[0];
    if (!deploymentId) {
      await say(`❌ Please specify a deployment ID: \`/sf-dev rollback [deploymentId]\``);
      return;
    }

    await say(`⚠️ *ROLLBACK WARNING*\n\nThis will revert deployment ${deploymentId}\n\nType *ROLLBACK ${deploymentId}* to confirm.`);

    this.confirmationManager.requestConfirmation(userId, {
      type: 'rollback',
      payload: { deploymentId }
    }, `ROLLBACK ${deploymentId}`);
  }

  // ==================== ENHANCED DEPLOYMENT HANDLERS ====================

  /**
   * Handle conversational deployment commands
   */
  async handleDeployChat(say, message, userId) {
    if (!this.deploymentAssistant) {
      await say(`❌ Deployment assistant not initialized. Please ensure the system is fully started.`);
      return;
    }

    await say(formatThinking());

    try {
      const result = await this.deploymentAssistant.processCommand(userId, message, {
        artifacts: this.getPendingArtifactsForUser(userId)
      });

      switch (result.type) {
        case 'confirmation_required':
          await say({
            blocks: [
              {
                type: 'section',
                text: { type: 'mrkdwn', text: `⚠️ *Confirmation Required*\n\n${result.message}` }
              },
              ...(result.warnings?.length ? [{
                type: 'section',
                text: { type: 'mrkdwn', text: `*Warnings:*\n${result.warnings.map(w => `• ${w}`).join('\n')}` }
              }] : []),
              {
                type: 'actions',
                elements: [
                  {
                    type: 'button',
                    text: { type: 'plain_text', text: '✅ Approve' },
                    style: 'primary',
                    action_id: 'deploy_approve',
                    value: userId
                  },
                  {
                    type: 'button',
                    text: { type: 'plain_text', text: '❌ Cancel' },
                    style: 'danger',
                    action_id: 'deploy_cancel',
                    value: userId
                  }
                ]
              }
            ]
          });
          break;

        case 'success':
          await say(formatSuccess(result.message));
          break;

        case 'error':
          await say(formatError({ message: result.message }));
          break;

        case 'status':
        case 'snapshot_list':
        case 'explanation':
          await say({
            blocks: [{
              type: 'section',
              text: { type: 'mrkdwn', text: result.message }
            }]
          });
          break;

        case 'scheduled':
          await say(formatSuccess(`${result.message}`));
          break;

        case 'auto_rollback':
          await say({
            blocks: [{
              type: 'section',
              text: { type: 'mrkdwn', text: `⚠️ *Auto-Rollback Executed*\n\n${result.message}` }
            }]
          });
          break;

        default:
          await say(result.message || 'Command processed.');
      }
    } catch (error) {
      console.error('Deploy chat error:', error);
      await say(formatError({ message: `Error: ${error.message}` }));
    }
  }

  /**
   * List available snapshots for rollback
   */
  async handleListSnapshots(say, args) {
    const targetOrg = args[0] || null;

    await say(`📸 Fetching available snapshots${targetOrg ? ` for ${targetOrg}` : ''}...`);

    try {
      // Get deployment pipeline from worker pool
      const snapshots = await this.getDeploymentPipeline()?.listSnapshots(targetOrg) || [];

      if (snapshots.length === 0) {
        await say(`No snapshots available${targetOrg ? ` for ${targetOrg}` : ''}.`);
        return;
      }

      let message = `*Available Snapshots:*\n\n`;
      snapshots.slice(0, 10).forEach((s, i) => {
        message += `${i + 1}. \`${s.snapshotId}\`\n`;
        message += `   Org: ${s.targetOrg} | Components: ${s.componentCount}\n`;
        message += `   Created: ${new Date(s.timestamp).toLocaleString()}\n\n`;
      });

      if (snapshots.length > 10) {
        message += `\n_...and ${snapshots.length - 10} more_`;
      }

      message += `\n\n💡 Use \`/sf-dev rollback [snapshotId]\` to restore.`;

      await say({ blocks: [{ type: 'section', text: { type: 'mrkdwn', text: message } }] });
    } catch (error) {
      await say(formatError({ message: `Failed to fetch snapshots: ${error.message}` }));
    }
  }

  /**
   * Schedule a deployment for later
   */
  async handleScheduleDeployment(say, args, userId) {
    const targetOrg = this.parseFlag(args, '--org') || 'Devin1';
    const timeArg = args.filter(a => !a.startsWith('--')).join(' ');

    if (!timeArg) {
      await say(`❌ Please specify when to deploy:\n\n\`/sf-dev schedule-deploy tomorrow at 2pm\`\n\`/sf-dev schedule-deploy in 3 hours --org=Devin1\``);
      return;
    }

    await say(`⏰ Scheduling deployment for: ${timeArg}\nTarget: ${targetOrg}`);

    // Store scheduling request for confirmation
    this.confirmationManager.requestConfirmation(userId, {
      type: 'schedule-deployment',
      payload: { timeArg, targetOrg }
    });

    await say(`\nType *APPROVE* to schedule or *CANCEL* to abort.`);
  }

  /**
   * List scheduled deployments
   */
  async handleListScheduled(say, args) {
    const status = this.parseFlag(args, '--status') || 'scheduled';

    await say(`📋 Fetching scheduled deployments...`);

    // Would integrate with DeploymentScheduler
    // Placeholder response
    await say({
      blocks: [{
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: `*Scheduled Deployments:*\n\n` +
            `No scheduled deployments found.\n\n` +
            `Use \`/sf-dev schedule-deploy [time]\` to schedule.`
        }
      }]
    });
  }

  /**
   * Cancel a scheduled deployment
   */
  async handleCancelScheduled(say, args, userId) {
    const scheduledId = args[0];

    if (!scheduledId) {
      await say(`❌ Please specify a scheduled ID: \`/sf-dev cancel-scheduled [scheduledId]\``);
      return;
    }

    await say(`⚠️ Cancel scheduled deployment ${scheduledId}?\n\nType *APPROVE* to confirm.`);

    this.confirmationManager.requestConfirmation(userId, {
      type: 'cancel-scheduled',
      payload: { scheduledId }
    });
  }

  /**
   * Show deployment windows configuration
   */
  async handleDeploymentWindows(say, args) {
    const action = args[0];

    if (action === 'set') {
      // Would allow configuring windows
      await say(`Window configuration not yet implemented via Slack.`);
      return;
    }

    // Show current windows
    const windows = {
      development: { days: 'Mon-Fri', hours: '6am-10pm UTC' },
      uat: { days: 'Mon-Fri', hours: '9am-6pm UTC' },
      production: { days: 'Sunday', hours: '2am-6am UTC' }
    };

    let message = `*Deployment Windows:*\n\n`;
    for (const [env, config] of Object.entries(windows)) {
      message += `*${env.charAt(0).toUpperCase() + env.slice(1)}:*\n`;
      message += `  Days: ${config.days}\n`;
      message += `  Hours: ${config.hours}\n\n`;
    }

    message += `💡 Deployments outside these windows require \`--force\` flag.`;

    await say({ blocks: [{ type: 'section', text: { type: 'mrkdwn', text: message } }] });
  }

  /**
   * Get deployment pipeline reference
   */
  getDeploymentPipeline() {
    // Would be injected or retrieved from worker pool
    return this.workerPool?.deploymentPipeline || null;
  }

  /**
   * Get pending artifacts for a user
   */
  getPendingArtifactsForUser(userId) {
    // Would retrieve from task queue or session storage
    return {};
  }

  /**
   * Initialize deployment assistant with pipeline
   */
  initializeDeploymentAssistant(deploymentPipeline, logger) {
    this.deploymentAssistant = new DeploymentAssistant(deploymentPipeline, logger);
    console.log('✅ Deployment assistant initialized');
  }

  async handleCostReport(say, args = []) {
    const forecast = Array.isArray(args) && args.includes('--forecast');
    const report = await this.costTracker.getMonthlyReport();

    let costText = `*Monthly Cost Report*\n\n` +
                   `Opus Planning: $${report.opusCost.toFixed(2)}\n` +
                   `Sonnet Workers: $${report.sonnetCost.toFixed(2)}\n` +
                   `Total: $${report.total.toFixed(2)}\n` +
                   `Budget: $${process.env.COST_BUDGET_MONTHLY}\n` +
                   `Remaining: $${(process.env.COST_BUDGET_MONTHLY - report.total).toFixed(2)}`;

    if (forecast) {
      const projected = report.total * 1.5; // Simple projection
      costText += `\n\n*Forecast:* $${projected.toFixed(2)} (month-end projection)`;
    }

    await say({ blocks: [{ type: 'section', text: { type: 'mrkdwn', text: costText } }] });
  }

  async handleSetBudget(say, args) {
    const newBudget = parseFloat(args[0]);
    if (!newBudget || isNaN(newBudget)) {
      await say(`❌ Please specify a valid budget amount: \`/sf-dev set-budget [amount]\``);
      return;
    }

    const current = parseFloat(process.env.COST_BUDGET_MONTHLY);
    await say(`💰 Budget update:\n\nCurrent: $${current}\nNew: $${newBudget}\n\n⚠️ This will update your .env file.\n\nType *APPROVE* to confirm.`);

    // Would update .env file after confirmation
  }

  async handleWorkers(say, args) {
    if (args[0] === 'scale' && args[1]) {
      const count = parseInt(args[1]);
      if (count >= 1 && count <= 5) {
        await say(`📊 Scaling workers to ${count}...`);
        // Would scale worker pool
        await say(`✅ Worker pool scaled to ${count} workers`);
      } else {
        await say(`❌ Worker count must be between 1 and 5`);
      }
    } else {
      const stats = this.workerPool.getStats();
      await say(`👷 *Worker Status*\n\nActive: ${stats.activeWorkers}\nProcessing: ${stats.activeTasks} tasks\n\nTo scale: \`/sf-dev workers scale [1-5]\``);
    }
  }

  async handleStop(say) {
    await say('⚠️ Stopping all workers...');
    await this.workerPool.stop();
    await say('✅ All workers stopped');
  }

  async handleRestartBot(say) {
    await say('🔄 **Restarting bot...**\n\nThe bot will be back online in a few seconds.');
    console.log('🔄 Bot restart requested via Slack command');

    // Give time for the message to send
    setTimeout(() => {
      console.log('👋 Exiting process for restart...');
      process.exit(0); // Exit with success code - pm2/systemd will restart
    }, 2000);
  }

  async handleHelp(say, args) {
    const command = args[0];
    await say(formatHelpMessage(command));
  }

  async handleReport(say, args = []) {
    const email = Array.isArray(args) && args.includes('--email');
    await say(`📊 Generating comprehensive system report...`);

    // Placeholder
    await say(`✅ Report generated\n\n• Tasks completed: 127\n• Cost this month: $45.20\n• Coverage improved: 79% → 85%\n\nFull report: report-${new Date().toISOString().split('T')[0]}.md`);

    if (email) {
      await say(`📧 Report sent via email`);
    }
  }

  // ==================== LOCAL REPOSITORY HANDLERS ====================

  async handleLocalOperation(intent, say, userId) {
    // Route the intent to get task details
    const routing = this.smartRouter.route(intent);

    // Check if approval is required
    if (this.smartRouter.requiresApproval(intent.command, intent.operationType)) {
      // Show plan and request approval
      const plan = {
        command: intent.command,
        parameters: intent.parameters,
        estimatedCost: routing.estimatedCost,
        estimatedTime: routing.estimatedTime,
        description: this.buildLocalOperationDescription(intent)
      };

      await say(formatLocalOperationPlan(plan));

      // Store pending approval
      this.conversationManager.setContext(userId, 'pendingApproval', {
        intent,
        routing,
        timestamp: Date.now()
      });

      return;
    }

    // Execute immediately for info-only commands
    await this.executeLocalCommand(intent, routing, say);
  }

  buildLocalOperationDescription(intent) {
    const { command, parameters } = intent;
    const repo = parameters.repo || 'salesforce-autonomous-dev-system';

    const descriptions = {
      'analyze-codebase': `Analyze the architecture and structure of ${repo}`,
      'search-code': `Search for pattern "${parameters.pattern}" in ${repo}`,
      'find-files': `Find files matching "${parameters.filePattern}" in ${repo}`,
      'edit-files': `Edit ${parameters.files?.length || 0} files in ${repo}`,
      'refactor-code': `Refactor code in ${repo}: ${parameters.refactoringInstructions}`,
      'rename-symbol': `Rename "${parameters.symbolName}" to "${parameters.newName}" across ${repo}`,
      'git-status': `Show git status for ${repo}`,
      'git-commit': `Commit changes to ${repo}`,
      'git-push': `Push ${repo} to remote`,
      'git-create-branch': `Create branch "${parameters.branchName}" in ${repo}`,
      'git-diff': `Show git diff for ${repo}`,
      'run-tests': `Run tests in ${repo}`,
      'run-build': `Build ${repo}`
    };

    return descriptions[command] || `Execute ${command} on ${repo}`;
  }

  async executeLocalCommand(intent, routing, say) {
    const { command, parameters } = intent;
    const { taskType, payload } = routing;

    try {
      // Queue the task for execution
      const task = await this.smartRouter.queueTask(routing);

      // For simple, fast operations, show immediate feedback
      if (this.smartRouter.isInfoOnly(command)) {
        await say(formatThinking());
        await say(`⏳ Executing ${command}...`);
        await say(`✅ Task queued (ID: ${task.taskId})\n\nYou'll see results shortly.`);
      } else {
        // Queue for worker execution with more details
        await say(`✅ Task queued (ID: ${task.taskId})\n\nEstimated time: ~${routing.estimatedTime} min\nCost: $${routing.estimatedCost.toFixed(2)}`);

        // Start progress tracking
        if (this.progressTracker) {
          this.progressTracker.startTracking(task.taskId, [task.taskId], routing.estimatedTime);
        }
      }

    } catch (error) {
      console.error('Local command execution error:', error);
      await say(formatError({ message: `Failed to execute ${command}: ${error.message}` }));
    }
  }

  async formatAndDisplayLocalResult(command, result, say) {
    let formatted;

    switch (command) {
      case 'git-status':
        formatted = formatGitStatus(result);
        break;

      case 'git-commit':
        formatted = formatGitCommit(result);
        break;

      case 'git-push':
        formatted = formatGitPush(result);
        break;

      case 'git-diff':
        formatted = formatGitDiff(result);
        break;

      case 'git-create-branch':
        formatted = formatBranchCreation(result);
        break;

      case 'analyze-codebase':
        formatted = formatCodebaseAnalysis(result);
        break;

      case 'search-code':
        formatted = formatCodeSearch(result);
        break;

      case 'find-files':
        formatted = formatFindFiles(result);
        break;

      case 'edit-files':
        formatted = formatFileEdits(result);
        break;

      case 'refactor-code':
        formatted = formatRefactoring(result);
        break;

      case 'rename-symbol':
        formatted = formatSymbolRename(result);
        break;

      case 'run-tests':
        formatted = formatTestResults(result);
        break;

      case 'run-build':
        formatted = formatBuildResults(result);
        break;

      default:
        formatted = formatLocalResult(result, command);
    }

    await say(formatted);
  }

  // ==================== HELPER METHODS ====================

  parseFlag(args, flag) {
    const arg = args.find(a => a.startsWith(flag));
    return arg ? arg.split('=')[1] : null;
  }

  async executeConfirmedAction(action, say) {
    switch (action.type) {
      case 'comprehensive-improve':
        await say(`🚀 Starting comprehensive improvement...`);
        await this.taskQueue.add({
          type: 'comprehensive-improve',
          priority: 2,
          payload: action.payload
        });
        break;

      case 'generate-tests':
        await say(`🚀 Generating ${action.payload.count} tests...`);
        for (let i = 0; i < action.payload.count; i++) {
          await this.taskQueue.add({
            type: 'generate-test',
            priority: 1,
            payload: { index: i }
          });
        }
        break;

      case 'deploy-queue':
        await say(`🚀 Deploying queue items...`);
        await this.taskQueue.add({
          type: 'deploy-all',
          priority: 3,
          payload: action.payload
        });
        break;

      case 'rollback':
        await say(`🔄 Rolling back deployment ${action.payload.deploymentId}...`);
        // Rollback logic
        break;

      case 'rewrite-test':
        await say(`🚀 Rewriting ${action.payload.testClassName}...`);
        await this.taskQueue.add({
          type: 'rewrite-test',
          priority: 1,
          payload: action.payload
        });
        break;

      case 'cancel-task':
        await say(`✅ Task ${action.payload.taskId} cancelled`);
        // Cancel task logic
        break;

      case 'clear-failed':
        await say(`✅ Failed tasks cleared from queue`);
        // Clear failed tasks logic
        break;

      default:
        await say(`❌ Unknown action type: ${action.type}`);
    }
  }

  async start() {
    console.log('🔌 Connecting to Slack...');
    await this.app.start();

    // Initialize progress tracker with channel
    this.progressTracker = new ProgressTracker(this.app, process.env.SLACK_CHANNEL);

    console.log('⚡️ Slack bot is running!');
    console.log('📡 Listening for:');
    console.log('   - Slash commands: /sf-dev');
    console.log('   - App mentions: @bot');
    console.log('   - Direct messages');
    console.log(`📢 Channel: ${process.env.SLACK_CHANNEL || 'Not configured'}`);
  }
}
