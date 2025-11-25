# Local Repository Operations Guide - Phase 3

Complete guide for using the Slack bot to manage local repositories remotely.

## Table of Contents
- [Overview](#overview)
- [Setup](#setup)
- [Natural Language Commands](#natural-language-commands)
- [Git Operations](#git-operations)
- [Code Analysis](#code-analysis)
- [Code Editing & Refactoring](#code-editing--refactoring)
- [Testing & Building](#testing--building)
- [Smart Routing](#smart-routing)
- [Examples](#examples)

---

## Overview

Phase 3 extends the Slack bot to handle **both** Salesforce operations **and** local repository operations through a unified natural language interface.

**What you can do:**
- Manage git operations remotely (status, commit, push, branches)
- Analyze local codebases
- Search and find files
- Refactor and edit code across multiple files
- Run tests and builds
- All through natural conversation in Slack!

---

## Setup

### 1. Environment Configuration

Copy `.env.template` to `.env` and configure:

```bash
# Slack Configuration
SLACK_BOT_TOKEN=xoxb-your-slack-bot-token
SLACK_SIGNING_SECRET=your-slack-signing-secret
SLACK_APP_TOKEN=xapp-your-slack-app-token
SLACK_CHANNEL=#salesforce-dev

# Local Repository Operations
WORKSPACE_ROOT=C:\Users\devin\IdeaProjects\DevAgentWorkspace
DEFAULT_REPO=salesforce-autonomous-dev-system

# Budget Management
COST_BUDGET_MONTHLY=100
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Start the Slack Bot

```bash
# Run directly (on-demand)
npm run slack-bot

# Or use PM2 for background operation
npm run slack-bot:start
npm run slack-bot:logs    # View logs
npm run slack-bot:stop    # Stop bot
```

### 4. Slack Bot Setup

Ensure your Slack app has:
- Socket Mode enabled
- Bot Token Scopes: `chat:write`, `commands`, `app_mentions:read`, `im:read`, `im:write`
- Event Subscriptions: `app_mention`, `message.im`
- Slash Command: `/sf-dev`

---

## Natural Language Commands

The bot understands natural language! No need for exact syntax.

### How It Works

**Smart Routing**: The bot automatically detects whether you're talking about:
- **Salesforce operations** (apex, tests, org, deployment)
- **Local repository operations** (git, files, refactoring)

**When Ambiguous**: The bot will ask for clarification.

---

## Git Operations

### Git Status

**Natural Language**:
```
"show git status"
"what's the git status of my repo?"
"git status"
```

**Response**:
- Current branch
- Modified files
- Untracked files
- Staged changes

### Git Commit

**Natural Language**:
```
"commit my changes with message 'Add new feature'"
"git commit -m 'Fix bug in worker'"
"commit these changes"
```

**Requires Approval**: Yes (unless configured for full trust)

**Response**:
- Commit hash
- Files committed
- Success confirmation

### Git Push

**Natural Language**:
```
"push to remote"
"git push"
"push my changes to origin"
```

**Requires Approval**: Yes

**Response**:
- Remote name
- Branch pushed
- Success confirmation

### Create Branch

**Natural Language**:
```
"create a new branch called feature/phase3"
"git checkout -b hotfix/bug-123"
"make a branch named refactor-code"
```

**Response**:
- Branch name
- Whether it was checked out

### Git Diff

**Natural Language**:
```
"show me the diff"
"what changed in slack-bot.js?"
"git diff"
```

**Response**:
- Diff output (first 20 lines)
- File changes
- Line numbers

---

## Code Analysis

### Analyze Codebase

**Natural Language**:
```
"analyze my local codebase"
"what's the architecture of phase2 folder?"
"give me an overview of the project structure"
```

**Response**:
- Architecture overview
- Key components
- Code quality observations
- Suggestions for improvement

**Cost**: ~$0.40 per analysis

### Search Code

**Natural Language**:
```
"search for TODO comments"
"find all instances of 'SlackBot' in the code"
"where is the function 'routeIntent' used?"
```

**Response**:
- Number of matches
- File locations
- Line numbers
- Context around each match

**Cost**: Free (no AI)

### Find Files

**Natural Language**:
```
"find all .js files"
"show me files matching '**/*worker*.js'"
"list all markdown files"
```

**Response**:
- List of matching files
- File count
- Paths

**Cost**: Free (no AI)

---

## Code Editing & Refactoring

### Refactor Code

**Natural Language**:
```
"refactor slack-bot.js to use async/await"
"clean up the worker.js file"
"modernize the code in repo-manager.js"
```

**Requires Approval**: Yes

**Response**:
- Files refactored
- Summary of changes
- Success confirmation

**Cost**: ~$0.50 per refactoring

### Edit Files

**Natural Language**:
```
"edit slack-bot.js and worker.js to fix the bug"
"update these files: [file1, file2]"
```

**Requires Approval**: Yes

**Response**:
- Files edited
- Changes applied
- Success confirmation

**Cost**: ~$0.30 per edit operation

### Rename Symbol

**Natural Language**:
```
"rename the variable 'workerPool' to 'salesforceWorkerPool'"
"change all instances of 'executeTask' to 'processTask'"
```

**Requires Approval**: Yes

**Response**:
- Old and new symbol names
- Files modified
- Number of occurrences changed

**Cost**: ~$0.10 per rename

---

## Testing & Building

### Run Tests

**Natural Language**:
```
"run the tests"
"test the local code"
"npm test"
```

**Response**:
- Test results (passed/failed)
- Output (last 10 lines)
- Errors if any

**Cost**: Free (no AI)

### Run Build

**Natural Language**:
```
"build the project"
"run npm build"
"compile the code"
```

**Response**:
- Build status (success/failed)
- Output
- Errors if any

**Cost**: Free (no AI)

---

## Smart Routing

The bot uses intelligent routing to determine if you're talking about Salesforce or local operations.

### Indicators for LOCAL Operations

**Keywords**: `local`, `repo`, `git`, `refactor`, `codebase`, `node`, `javascript`

**File mentions**: `slack-bot.js`, `.js files`, `package.json`, `src/`

**Git commands**: `git status`, `git commit`, `git push`

**Examples**:
- ✅ "show git status" → **Local**
- ✅ "refactor slack-bot.js" → **Local** (file mentioned)
- ✅ "analyze my local codebase" → **Local** (keyword "local")

### Indicators for SALESFORCE Operations

**Keywords**: `salesforce`, `apex`, `org`, `deployment`, `coverage`, `sandbox`

**Class mentions**: `AccountTriggerTest`, `OpportunityHandler`

**Examples**:
- ✅ "improve 10 apex tests" → **Salesforce** (keyword "apex")
- ✅ "deploy to salesforce" → **Salesforce**
- ✅ "show org coverage" → **Salesforce**

### Ambiguous Cases

When the bot is unsure, it will ask:

**You**: "improve 10 tests"
**Bot**: "Are you referring to Salesforce Apex tests or local JavaScript tests?"
**You**: "local"
**Bot**: ✅ Proceeds with local test improvement

---

## Examples

### Example 1: Complete Git Workflow

```
You: "show git status"
Bot: [Shows current branch, modified files]

You: "commit these changes with message 'Add Phase 3 local operations'"
Bot: [Shows commit plan, asks for approval]

You: "approve"
Bot: ✅ Committed [hash: abc123]
     📦 3 files committed

You: "push to remote"
Bot: [Shows push plan]

You: "yes"
Bot: ✅ Pushed to origin/main
```

### Example 2: Code Refactoring

```
You: "analyze the slack-bot.js file"
Bot: [Shows architecture analysis, suggestions]

You: "refactor it to use cleaner async/await patterns"
Bot: 📝 Execution Plan:
     Refactor code in salesforce-autonomous-dev-system
     Estimated: $0.50, ~4 min
     Type APPROVE to proceed

You: "approve"
Bot: ⏳ Refactoring...
     [Progress updates]
     ✅ Code Refactored - 12 functions updated

You: "run the tests"
Bot: ✅ Tests PASSED
```

### Example 3: Search and Edit

```
You: "search for all TODO comments"
Bot: 🔍 Found 15 TODOs across 8 files:
     [Shows matches with file:line numbers]

You: "create a branch called fix/todos"
Bot: ✅ Branch created: fix/todos
     ✓ Checked out

You: "commit with message 'Start TODO cleanup'"
Bot: ✅ Committed [hash: def456]
```

### Example 4: Mixed Salesforce & Local

```
You: "show status"
Bot: [Shows Salesforce system status by default]

You: "now show git status"
Bot: [Shows local git status]

You: "improve 5 apex tests"
Bot: [Queues Salesforce test improvements]

You: "and refactor the local worker.js"
Bot: [Plans local refactoring]
```

---

## Approval Workflow

### Commands Requiring Approval

**High Risk**:
- `git-push`
- `git-commit`
- `refactor-code`
- `edit-files`
- `rename-symbol`
- `deploy-queue`

**Low Risk** (instant execution):
- `git-status`
- `git-diff`
- `analyze-codebase`
- `search-code`
- `find-files`
- `run-tests`

### Approval Keywords

To approve:
- "approve"
- "yes"
- "confirmed"
- "do it"
- "go ahead"

To cancel:
- "cancel"
- "no"
- "stop"
- "abort"

---

## Cost Management

All operations are tracked against your monthly budget:

```
You: "show costs"
Bot: 💰 Monthly Cost Report
     Opus Planning: $12.50
     Sonnet Workers: $28.30
     Total: $40.80
     Budget: $100.00
     Remaining: $59.20
```

### Typical Costs

| Operation | Cost |
|-----------|------|
| Git operations | Free |
| File search | Free |
| Test/Build | Free |
| Codebase analysis | $0.40 |
| Code refactoring | $0.50 |
| File editing | $0.30 |
| Symbol rename | $0.10 |

---

## Troubleshooting

### Bot Not Responding

1. Check bot is running: `npm run slack-bot:status`
2. Check logs: `npm run slack-bot:logs`
3. Verify Slack tokens in `.env`
4. Ensure Socket Mode is enabled

### Wrong Operation Type

If the bot routes incorrectly:
- Be more specific: "git status" instead of just "status"
- Mention file names: "refactor slack-bot.js"
- Use keywords: "local tests" vs "apex tests"

### Approval Not Working

Ensure you're typing exactly:
- `APPROVE` or `YES` (case-insensitive)
- In the same channel/DM as the request
- Within 30 minutes of the request

---

## Best Practices

1. **Be Specific**: Mention file names, repos, or keywords
2. **Check Git Status**: Before committing/pushing
3. **Test First**: Run tests after refactoring
4. **Use Branches**: Create feature branches for changes
5. **Monitor Costs**: Check `/sf-dev cost` regularly
6. **Approve Carefully**: Review plans before approving

---

## Advanced Features

### Multi-Repo Management

```
You: "switch to repo project-x"
Bot: [Sets context to project-x repo]

You: "analyze this codebase"
Bot: [Analyzes project-x]
```

### Batch Operations

```
You: "refactor all files in src/phase2/"
Bot: [Plans bulk refactoring]
```

### Follow-Up Suggestions

The bot proactively suggests next steps:

```
Bot: ✅ Code refactored successfully
     💡 Suggestion: Run tests to verify changes?
```

---

## Security Notes

- **Full Trust Mode**: All approved users can perform any operation
- **Git Push**: Always requires explicit approval
- **File Operations**: Can modify any file in workspace
- **Recommendation**: Limit Slack bot access to trusted users

---

## Getting Help

```
You: "help with local operations"
Bot: [Shows available local commands]

You: "what can you do?"
Bot: [Lists all capabilities]
```

---

**Phase 3 Status**: ✅ Ready
**Slack Bot**: Connected
**Local Operations**: Enabled
**Smart Routing**: Active
