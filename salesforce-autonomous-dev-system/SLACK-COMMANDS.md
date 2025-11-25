# Slack Commands Reference - Phase 2 System

Complete reference for all `/sf-dev` commands in your Salesforce Autonomous Development System.

## Table of Contents
- [Test Management](#test-management)
- [Org Analysis](#org-analysis)
- [Queue Management](#queue-management)
- [Deployment](#deployment)
- [Budget & Monitoring](#budget--monitoring)
- [System Commands](#system-commands)
- [Command Patterns](#command-patterns)

---

## Test Management

### `/sf-dev status`
Shows real-time system status including active workers, tasks, queue size, and daily cost.

**Example:**
```
/sf-dev status
```

**Response:**
- Active Workers count
- Active Tasks count
- Queue Size
- Cost Today
- Smart suggestions based on current state

---

### `/sf-dev improve-tests [count]`
Queues improvement tasks for existing test classes.

**Usage:**
```
/sf-dev improve-tests 10
```

**Parameters:**
- `count` - Number of tests to improve (default: 10)

**Response:**
- Confirmation of queued tasks
- Progress tracking starts automatically
- Updates every 30 seconds until complete

---

### `/sf-dev generate-tests [count] [--coverage=X]`
Generates new tests for untested classes.

**Usage:**
```
/sf-dev generate-tests 10
/sf-dev generate-tests 5 --coverage=95
```

**Parameters:**
- `count` - Number of tests to generate (default: 10)
- `--coverage` - Target coverage percentage (default: 100)

**Response:**
- Analysis of classes needing tests
- Cost and time estimates
- Requires `APPROVE` confirmation

---

### `/sf-dev quality-scan [className]`
Analyzes the quality of a specific test class.

**Usage:**
```
/sf-dev quality-scan AccountTriggerTest
```

**Response:**
- Quality score (0-100)
- Critical/High/Medium issues breakdown
- Cost and time estimates
- Interactive buttons:
  - `Improve Now` - Queue improvement
  - `View Details` - See full analysis
  - `Ignore` - Dismiss

---

### `/sf-dev comprehensive-improve [--target-coverage=X]`
Runs full 3-phase improvement workflow: improve tests → generate missing → deploy.

**Usage:**
```
/sf-dev comprehensive-improve
/sf-dev comprehensive-improve --target-coverage=95
```

**Parameters:**
- `--target-coverage` - Target org coverage (default: 90)

**Response:**
- 3-phase plan with cost/time estimates
- Requires `APPROVE` confirmation
- Progress updates throughout execution

---

### `/sf-dev rewrite-test [testClassName]`
Completely rewrites a low-quality test class.

**Usage:**
```
/sf-dev rewrite-test AccountTriggerTest
```

**Response:**
- Analysis and cost estimate
- Requires `APPROVE` confirmation
- Shows old vs new score after completion

---

## Org Analysis

### `/sf-dev analyze-org [--deep]`
Performs comprehensive org analysis.

**Usage:**
```
/sf-dev analyze-org           # Quick analysis (3-5 min)
/sf-dev analyze-org --deep    # Deep analysis (15-20 min)
```

**Response:**
- Total classes, coverage %, technical debt
- Low-quality tests identified
- Untested classes found
- Generates report file
- Notification when complete

---

### `/sf-dev coverage-report [--by-package]`
Generates detailed coverage breakdown.

**Usage:**
```
/sf-dev coverage-report
/sf-dev coverage-report --by-package
```

**Response:**
- Org-wide coverage percentage
- Per-class breakdown with color coding:
  - 🟢 Green: >90%
  - 🟡 Yellow: 75-90%
  - 🔴 Red: <75%
- Interactive buttons:
  - `Improve Low Coverage`
  - `Export Full Report`

---

### `/sf-dev find-issues [--type=TYPE]`
Scans for specific issue types.

**Usage:**
```
/sf-dev find-issues
/sf-dev find-issues --type=security
/sf-dev find-issues --type=performance
/sf-dev find-issues --type=quality
```

**Response:**
- Issue count by severity
- Recommendations for fixes

---

## Queue Management

### `/sf-dev queue-status [taskId]`
Shows queue status or specific task progress.

**Usage:**
```
/sf-dev queue-status        # Show all queue stats
/sf-dev queue-status 123    # Show specific task
```

**Response:**
- Task counts by status (pending/processing/completed/failed)
- For specific task: current progress percentage

---

### `/sf-dev pause-queue`
Pauses task processing (completes in-flight tasks first).

**Usage:**
```
/sf-dev pause-queue
```

**Response:**
- Confirmation with pending task count
- Instructions to resume

---

### `/sf-dev resume-queue`
Resumes paused task processing.

**Usage:**
```
/sf-dev resume-queue
```

**Response:**
- Confirmation that processing has resumed

---

### `/sf-dev cancel-task [taskId]`
Cancels a pending or processing task.

**Usage:**
```
/sf-dev cancel-task 123
```

**Response:**
- Task details
- Requires `APPROVE` confirmation

---

### `/sf-dev clear-failed`
Removes failed tasks from the queue.

**Usage:**
```
/sf-dev clear-failed
```

**Response:**
- List of failed tasks with error messages
- Requires `APPROVE` confirmation

---

## Deployment

### `/sf-dev deploy-queue [--validate-only]`
Deploys all ready-to-deploy items.

**Usage:**
```
/sf-dev deploy-queue                  # Deploy to Devin1
/sf-dev deploy-queue --validate-only  # Dry-run only
```

**Response:**
- Target org (always Devin1 for safety)
- File list (condensed if >10 files)
- Coverage impact projection
- Requires typing `DEPLOY` to confirm

**Safety:**
- Only deploys to whitelisted sandboxes
- Shows all files being deployed
- 4-layer safety validation

---

### `/sf-dev validate-deployment`
Validates deployment without deploying.

**Usage:**
```
/sf-dev validate-deployment
```

**Response:**
- Validation results
- Test pass/fail status
- Coverage impact
- Conflict detection

---

### `/sf-dev rollback [deploymentId]`
Rolls back a failed deployment.

**Usage:**
```
/sf-dev rollback deploy-123
```

**Response:**
- Warning message
- Requires typing `ROLLBACK [deploymentId]` to confirm

**Safety:**
- Double confirmation required
- Shows what will be reverted

---

## Budget & Monitoring

### `/sf-dev cost [--forecast]`
Shows monthly cost report.

**Usage:**
```
/sf-dev cost
/sf-dev cost --forecast
```

**Response:**
- Opus vs Sonnet cost breakdown
- Total spend
- Budget remaining
- Optional: Month-end projection

**Auto-alerts:**
- Warning at 80% budget
- Stop at 100% budget

---

### `/sf-dev set-budget [amount]`
Updates monthly cost budget.

**Usage:**
```
/sf-dev set-budget 150
```

**Response:**
- Current vs new budget
- Requires `APPROVE` confirmation
- Updates .env file

---

### `/sf-dev workers [scale [count]]`
Views or scales worker count.

**Usage:**
```
/sf-dev workers              # View current workers
/sf-dev workers scale 5      # Scale to 5 workers
```

**Parameters:**
- `count` - Number of workers (1-5)

**Response:**
- Current worker status
- Confirmation of scaling operation

---

## System Commands

### `/sf-dev stop`
Stops all workers gracefully.

**Usage:**
```
/sf-dev stop
```

**Response:**
- Confirmation when workers stopped
- In-flight tasks complete first

---

### `/sf-dev help [command]`
Shows help documentation.

**Usage:**
```
/sf-dev help                    # List all commands
/sf-dev help improve-tests      # Help for specific command
```

**Response:**
- Command description
- Usage examples
- Parameter explanations

---

### `/sf-dev report [--email]`
Generates comprehensive system report.

**Usage:**
```
/sf-dev report
/sf-dev report --email
```

**Response:**
- Tasks completed
- Cost summary
- Coverage trends
- Optional email delivery

---

## Command Patterns

### Confirmation Types

#### 1. Simple Confirmation (Low Risk)
Commands like `quality-scan` show results with interactive buttons:
- ✅ `Improve Now`
- 📊 `View Details`
- ❌ `Ignore`

#### 2. Text Confirmation (Medium Risk)
Commands like `generate-tests` require typing:
- Type `APPROVE` to proceed
- Type `CANCEL` to abort

#### 3. Explicit Confirmation (High Risk)
Commands like `deploy-queue` require exact text:
- Type `DEPLOY` to deploy
- Type `ROLLBACK [id]` to rollback

### Progress Updates

Long-running tasks automatically send progress updates:
- Initial confirmation
- Progress bars every 30 seconds
- Stage descriptions
- Cost tracking
- Completion notification

Example:
```
📊 Progress Update

Completed: 8/20 (40%) ████████░░░░░░░░░░░░
In Progress: 3 tasks (Workers: 1, 2, 3)
Pending: 9 tasks
Failed: 0 tasks

Cost so far: $1.20 / $4.00 estimated
Time remaining: ~8 minutes
```

### Error Handling

When tasks fail, you receive:
- Error description
- Recommended actions
- Interactive recovery options:
  - ⏸️ Pause & Resume Later
  - 🔄 Retry with Delays
  - ❌ Cancel All

### Smart Suggestions

The bot provides contextual suggestions:
- Empty queue → suggests running analysis
- Low budget → suggests pausing or increasing
- Low coverage detected → suggests comprehensive improvement
- Multiple failures → suggests investigating issues

---

## Quick Reference Card

| Command | Purpose | Confirmation |
|---------|---------|--------------|
| `status` | View system status | None |
| `improve-tests [n]` | Improve n tests | None |
| `generate-tests [n]` | Generate n tests | APPROVE |
| `quality-scan [class]` | Analyze test quality | None |
| `comprehensive-improve` | Full 3-phase workflow | APPROVE |
| `rewrite-test [class]` | Rewrite test completely | APPROVE |
| `analyze-org` | Analyze entire org | None |
| `coverage-report` | Show coverage breakdown | None |
| `queue-status` | View queue state | None |
| `pause-queue` | Pause processing | None |
| `resume-queue` | Resume processing | None |
| `deploy-queue` | Deploy to Devin1 | DEPLOY |
| `validate-deployment` | Dry-run validation | None |
| `rollback [id]` | Revert deployment | ROLLBACK |
| `cost` | View cost report | None |
| `workers` | View/scale workers | None |
| `help` | Show help | None |

---

## Best Practices

1. **Start Small**: Begin with `quality-scan` on a few tests before running comprehensive improvements
2. **Monitor Costs**: Check `/sf-dev cost` regularly, especially during large operations
3. **Use Validate**: Always run `validate-deployment` before deploying
4. **Watch Queue**: Use `queue-status` to monitor progress on large batches
5. **Pause When Needed**: Use `pause-queue` if you need to stop and review
6. **Read Progress**: Progress updates provide valuable insights into what's happening

---

## Example Workflows

### Workflow 1: Quick Test Improvements
```
1. /sf-dev analyze-org
2. /sf-dev quality-scan AccountTriggerTest
3. [Click "Improve Now" button]
4. /sf-dev queue-status
5. [Wait for completion]
6. /sf-dev deploy-queue --validate-only
7. /sf-dev deploy-queue
8. [Type: DEPLOY]
```

### Workflow 2: Comprehensive Improvement
```
1. /sf-dev coverage-report
2. /sf-dev comprehensive-improve --target-coverage=90
3. [Type: APPROVE]
4. [Monitor progress updates]
5. /sf-dev cost
```

### Workflow 3: Generate Missing Tests
```
1. /sf-dev analyze-org
2. /sf-dev generate-tests 10 --coverage=95
3. [Type: APPROVE]
4. /sf-dev queue-status
5. /sf-dev deploy-queue
6. [Type: DEPLOY]
```

---

## Getting Started

To test your setup:
1. Go to your #salesforce-dev channel
2. Type: `/sf-dev status`
3. You should see system status with active workers

For help at any time: `/sf-dev help`

---

**System Status**: Phase 2 Multi-Agent System Ready ✅
**Slack Bot**: Connected to #salesforce-dev
**Workers**: 3 parallel workers configured
**Budget**: $100/month
**Safety**: 4-layer deployment protection active
