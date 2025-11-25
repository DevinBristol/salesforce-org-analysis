# Phase 4: Autonomous Orchestration Platform

## Overview

Phase 4 transforms the Salesforce Autonomous Development System into a fully autonomous orchestration platform. Building on the Phase 3 Slack bot foundation, it adds sophisticated task orchestration, workflow management, and real-time progress tracking.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Phase 4 System                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │  Slack Bot  │    │   Claude    │    │  Workflow   │         │
│  │ Integration │◄───│ Orchestrator│◄───│   Engine    │         │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘         │
│         │                  │                   │                │
│         ▼                  ▼                   ▼                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Enhanced Conversation Manager               │   │
│  │           (Persistence, Memory, Summarization)          │   │
│  └─────────────────────────────────────────────────────────┘   │
│         │                  │                   │                │
│         ▼                  ▼                   ▼                │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │  Progress   │    │   Result    │    │ Monitoring  │         │
│  │  Reporter   │    │  Callback   │    │   System    │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    PostgreSQL Database                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Result Callback System (`result-callback.js`)

Handles asynchronous result delivery with multiple mechanisms:

- **Slack Notifications**: Rich formatted messages with action buttons
- **Webhook Callbacks**: POST results to external endpoints
- **Event Emission**: Internal event-driven notifications
- **Result Caching**: Store results for polling retrieval

```javascript
const { ResultCallbackSystem } = require('./phase4');

const callbacks = new ResultCallbackSystem({ db, slackBot });

// Register a callback
callbacks.registerCallback(taskId, {
    type: 'slack',
    slackChannel: '#dev-results',
    slackThreadTs: 'thread-id'
});

// Deliver result
await callbacks.deliverResult(taskId, {
    success: true,
    summary: 'Task completed successfully'
});
```

### 2. Progress Reporter (`progress-reporter.js`)

Real-time progress tracking for long-running tasks:

- **Stage-based Progress**: Track multi-stage task progress
- **ETA Calculation**: Estimate completion time based on trends
- **Live Updates**: Real-time Slack message updates
- **Metrics Tracking**: Messages, tokens, files modified, etc.

```javascript
const { ProgressReporter } = require('./phase4');

const reporter = new ProgressReporter({ slackBot });

// Start tracking
reporter.startTracking(taskId, {
    taskType: 'analysis',
    stages: [
        { name: 'Setup', weight: 1 },
        { name: 'Analysis', weight: 3 },
        { name: 'Report', weight: 1 }
    ]
});

// Update progress
reporter.updateProgress(taskId, {
    stageProgress: 50,
    statusMessage: 'Analyzing triggers...'
});
```

### 3. Enhanced Conversation Manager (`conversation-manager-enhanced.js`)

Advanced conversation management with:

- **Database Persistence**: Store conversation history
- **Context Memory**: Remember important facts across sessions
- **Automatic Summarization**: Compress long conversations
- **Multi-session Support**: Track multiple conversations

```javascript
const { EnhancedConversationManager } = require('./phase4');

const manager = new EnhancedConversationManager({ db, claudeClient });

// Get or create conversation
const conv = await manager.getOrCreateConversation(conversationId, {
    userId: 'U123',
    taskType: 'analysis'
});

// Add message
await manager.addMessage(conversationId, {
    role: 'user',
    content: 'Analyze this Apex class...'
});

// Get context for Claude API
const context = await manager.getContextForApi(conversationId);
```

### 4. Monitoring System (`monitoring-system.js`)

Comprehensive monitoring and alerting:

- **Real-time Metrics**: Tasks, API usage, costs
- **Health Checks**: Database, API, orchestrator status
- **Alerting**: Slack notifications for issues
- **Dashboard Data**: Aggregate metrics for display

```javascript
const { MonitoringSystem } = require('./phase4');

const monitoring = new MonitoringSystem({
    alertChannel: '#dev-alerts',
    errorRateThreshold: 0.1
});

// Register health check
monitoring.registerHealthCheck('database', async () => {
    // Check database connection
    return { healthy: true };
});

// Track task
monitoring.trackTask('completed', { type: 'analysis', duration: 5000 });

// Get dashboard data
const dashboard = monitoring.getDashboardData();
```

### 5. Claude Code Orchestrator (`claude-orchestrator.js`)

Manages Claude Code instances for task execution:

- **Dynamic Instance Management**: Scale up/down based on load
- **Task Scheduling**: Priority-based task queue
- **Workspace Management**: Isolated task workspaces
- **Error Recovery**: Automatic retries with backoff

```javascript
const { ClaudeCodeOrchestrator } = require('./phase4');

const orchestrator = new ClaudeCodeOrchestrator({
    maxInstances: 5,
    workspaceRoot: '/tmp/workspaces'
});

// Submit task
const taskId = await orchestrator.submitTask({
    type: 'analysis',
    prompt: 'Analyze this Apex code...',
    context: {
        files: { 'AccountTrigger.cls': '...' }
    },
    priority: 'high'
});

// Get status
const status = orchestrator.getTaskStatus(taskId);
```

### 6. Workflow Engine (`workflow-engine.js`)

DAG-based workflow execution:

- **Multi-step Workflows**: Chain tasks together
- **Conditional Branching**: Execute based on conditions
- **Parallel Execution**: Run independent steps concurrently
- **Approval Steps**: Pause for human approval

```javascript
const { WorkflowEngine } = require('./phase4');

const engine = new WorkflowEngine({ orchestrator });

// Start predefined workflow
const workflowId = await engine.startWorkflow('full-analysis-improvement', {
    context: { files: {...} },
    callback: { slackConfig: { channel: '#dev' } }
});

// Respond to approval
await engine.respondToApproval(workflowId, true, 'Approved for production');
```

## Setup

### 1. Install Dependencies

```bash
npm install pg @anthropic-ai/sdk @slack/bolt dotenv
```

### 2. Configure Environment

Copy `.env.template` to `.env` and configure:

```env
# Required
DATABASE_URL=postgresql://user:pass@localhost:5432/salesforce_dev
ANTHROPIC_API_KEY=sk-ant-...
SLACK_BOT_TOKEN=xoxb-...
SLACK_SIGNING_SECRET=...
SLACK_APP_TOKEN=xapp-...

# Optional
ORCHESTRATOR_MAX_INSTANCES=5
ALERT_CHANNEL=#dev-alerts
```

### 3. Run Migrations

```bash
node src/phase4/migrate-phase4.js up
```

### 4. Start the System

```bash
node src/phase4/main.js
```

## Slack Commands

Phase 4 adds these Slack commands:

| Command | Description |
|---------|-------------|
| `/workflow list` | List available workflow templates |
| `/workflow start <template>` | Start a workflow |
| `/workflow status <id>` | Check workflow status |
| `/monitor` | View monitoring dashboard |
| `/orchestrator` | View orchestrator status |

## Database Schema

Phase 4 uses these PostgreSQL tables:

- `conversations` - Conversation metadata and state
- `conversation_messages` - Individual messages
- `user_memories` - Learned facts and preferences
- `task_callbacks` - Registered callbacks
- `task_results` - Task results for retrieval
- `workflows` - Workflow instances
- `monitoring_metrics` - Time-series metrics
- `monitoring_alerts` - Alert history
- `autonomous_tasks` - Task queue
- `scheduled_jobs` - Scheduled task definitions
- `audit_log` - System audit trail

## Workflow Templates

### Full Analysis & Improvement
Analyzes code and implements improvements:
1. Analyze code for issues
2. Prioritize improvements
3. Implement high-priority fixes
4. Run tests
5. Generate report

### Bug Fix
Diagnoses and fixes bugs:
1. Reproduce the bug
2. Identify root cause
3. Implement fix
4. Verify fix

### Deployment
Deploys changes to Salesforce:
1. Validate deployment
2. Request approval
3. Deploy to org
4. Run smoke tests

### Code Review
Comprehensive code review:
1. Security review (parallel)
2. Performance review (parallel)
3. Quality review (parallel)
4. Combine results
5. Generate report

## Event Hooks

The system emits events for integration:

```javascript
// Task events
orchestrator.on('task:completed', ({ taskId, result }) => {...});
orchestrator.on('task:failed', ({ task, error }) => {...});

// Workflow events
workflow.on('workflow:completed', (workflow) => {...});
workflow.on('approval:requested', ({ workflowId, message }) => {...});

// Progress events
progress.on('progress:updated', ({ taskId, progress }) => {...});
progress.on('progress:completed', ({ taskId, duration }) => {...});

// Monitoring events
monitoring.on('alert', (alert) => {...});
```

## Performance Tuning

### Orchestrator
- `ORCHESTRATOR_MAX_INSTANCES`: Max concurrent Claude Code instances (default: 5)
- `ORCHESTRATOR_TIMEOUT`: Task timeout in ms (default: 1800000 / 30 min)

### Conversation Manager
- `CONVERSATION_MAX_TOKENS`: Max context tokens (default: 100000)
- `CONVERSATION_SUMMARY_THRESHOLD`: When to summarize (default: 50000)

### Monitoring
- `ALERT_ERROR_RATE_THRESHOLD`: Error rate to alert (default: 0.1 / 10%)
- `ALERT_COOLDOWN`: Time between repeated alerts (default: 300000 / 5 min)

## Migration from Phase 3

Phase 4 is backward compatible with Phase 3. Existing Slack commands continue to work. To use Phase 4 features:

1. Set up PostgreSQL database
2. Run migrations
3. Update `.env` with Phase 4 settings
4. Replace `src/phase2/main.js` with `src/phase4/main.js`

## Troubleshooting

### Database Connection Issues
```bash
# Check connection
node -e "require('pg').Pool({connectionString: process.env.DATABASE_URL}).query('SELECT 1').then(console.log)"
```

### Migration Status
```bash
node src/phase4/migrate-phase4.js status
```

### Reset Migrations
```bash
node src/phase4/migrate-phase4.js down
```

## License

MIT License - See LICENSE file for details.
