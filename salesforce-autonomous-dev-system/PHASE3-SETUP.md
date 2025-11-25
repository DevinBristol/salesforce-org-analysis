# Phase 3 Setup Guide - Unified Slack Interface

Quick start guide for setting up Phase 3: Slack-based control of both Salesforce operations AND local repository management.

## What's New in Phase 3?

Phase 3 extends your autonomous Salesforce development system with **local repository operations**:

✅ **Salesforce Operations** (Phase 2)
- Improve Apex tests
- Generate new tests
- Deploy to sandboxes
- Analyze org coverage

✅ **Local Repository Operations** (Phase 3 - NEW!)
- Git operations (status, commit, push, branches)
- Code analysis & refactoring
- Search & find files
- Run tests & builds
- Edit multiple files

**All through natural conversation in Slack!**

---

## Prerequisites

- Node.js 18+ installed
- Slack workspace with admin access
- Anthropic API key
- Salesforce CLI configured (for Salesforce operations)

---

## Step 1: Slack App Setup

### 1.1 Create Slack App

1. Go to https://api.slack.com/apps
2. Click "Create New App" → "From scratch"
3. Name: "Salesforce Dev Assistant"
4. Choose your workspace

### 1.2 Enable Socket Mode

1. Go to "Socket Mode" in left sidebar
2. Enable Socket Mode
3. Generate app-level token:
   - Token Name: "socket-token"
   - Scopes: `connections:write`
   - Copy the token (starts with `xapp-`)

### 1.3 Configure OAuth & Permissions

Go to "OAuth & Permissions":

**Bot Token Scopes** (add these):
```
chat:write
commands
app_mentions:read
im:read
im:write
im:history
channels:history
```

**Install App** to your workspace and copy the **Bot User OAuth Token** (starts with `xoxb-`)

### 1.4 Enable Events

Go to "Event Subscriptions":
- Enable Events
- Subscribe to bot events:
  - `app_mention`
  - `message.im`

### 1.5 Add Slash Command

Go to "Slash Commands":
- Command: `/sf-dev`
- Request URL: (leave blank for Socket Mode)
- Short Description: "Salesforce development operations"

### 1.6 Get Signing Secret

Go to "Basic Information":
- Copy "Signing Secret"

---

## Step 2: Environment Configuration

### 2.1 Copy Environment Template

```bash
cd salesforce-autonomous-dev-system
copy .env.template .env
```

### 2.2 Configure .env

Open `.env` and set:

```bash
# Anthropic API
ANTHROPIC_API_KEY=sk-ant-your-api-key

# Slack Configuration
SLACK_BOT_TOKEN=xoxb-your-bot-token
SLACK_SIGNING_SECRET=your-signing-secret
SLACK_APP_TOKEN=xapp-your-app-token
SLACK_CHANNEL=#salesforce-dev

# Local Repository Operations
WORKSPACE_ROOT=C:\Users\devin\IdeaProjects\DevAgentWorkspace
DEFAULT_REPO=salesforce-autonomous-dev-system

# Salesforce (for Salesforce operations)
SF_USERNAME=your@salesforce.com
SF_LOGIN_URL=https://login.salesforce.com

# Budget
COST_BUDGET_MONTHLY=100
```

### 2.3 Create Slack Channel

Create a channel `#salesforce-dev` and invite your bot:
```
/invite @Salesforce Dev Assistant
```

---

## Step 3: Install Dependencies

```bash
npm install
```

Ensure these are installed:
- `@slack/bolt` - Slack SDK
- `@anthropic-ai/sdk` - Claude API
- `fs-extra` - File operations
- `better-sqlite3` - Task queue database

---

## Step 4: Start the Bot

### Option A: On-Demand (Recommended for Testing)

```bash
npm run slack-bot
```

**When to use**: Testing, development, or when you want manual control

**To stop**: Press `Ctrl+C`

### Option B: Background Service (Production)

```bash
npm run slack-bot:start
```

**When to use**: Production, always-on operation

**Useful commands**:
```bash
npm run slack-bot:logs     # View logs
npm run slack-bot:restart  # Restart bot
npm run slack-bot:stop     # Stop bot
pm2 status                 # Check status
```

---

## Step 5: Test the Setup

### 5.1 Test in Slack Channel

Go to `#salesforce-dev` and try:

```
/sf-dev status
```

Expected response: System status with active workers, queue size, costs

### 5.2 Test Natural Language

Try these commands:

**Test 1: Salesforce Operation**
```
@Salesforce Dev Assistant show org coverage
```

**Test 2: Local Git Operation**
```
@Salesforce Dev Assistant show git status
```

**Test 3: Ambiguous (Should Ask for Clarification)**
```
@Salesforce Dev Assistant improve 10 tests
```
Bot should ask: "Are you referring to Salesforce Apex tests or local tests?"

**Test 4: Code Analysis**
```
@Salesforce Dev Assistant analyze my local codebase
```

---

## Step 6: Verify Components

### 6.1 Check File Structure

Ensure these Phase 3 files exist:

```
src/
  ├── services/
  │   └── repo-manager.js          ✅ NEW
  └── phase2/
      ├── local-repo-worker.js     ✅ NEW
      ├── smart-router.js          ✅ NEW
      ├── local-formatters.js      ✅ NEW
      ├── slack-bot.js             ⚡ EXTENDED
      └── nl-command-parser.js     ⚡ EXTENDED
```

### 6.2 Test Local Operations

```bash
# In Slack:
"show git status"
"search for TODO in the code"
"list all .js files in src/"
```

---

## Architecture Overview

```
┌──────────────────────────────────────┐
│          Slack Interface             │
│    (DMs, Mentions, /sf-dev)         │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│      NL Command Parser               │
│  (Determines: Salesforce or Local)   │
└───────┬──────────────────┬───────────┘
        │                  │
        │                  │
        ▼                  ▼
┌───────────────┐  ┌──────────────────┐
│   Salesforce  │  │  Local Repo      │
│  Worker Pool  │  │  Worker Pool     │
│               │  │                  │
│ • Apex Tests  │  │ • Git Ops        │
│ • Deployment  │  │ • Refactoring    │
│ • Coverage    │  │ • Analysis       │
└───────────────┘  └──────────────────┘
        │                  │
        ▼                  ▼
┌───────────────┐  ┌──────────────────┐
│  Salesforce   │  │  Local Files     │
│      Org      │  │  & Git Repo      │
└───────────────┘  └──────────────────┘
```

---

## Common Issues & Solutions

### Issue 1: Bot Not Responding

**Symptoms**: No response to commands

**Solutions**:
1. Check bot is running: `pm2 status` or check console
2. Verify Slack tokens in `.env`
3. Ensure Socket Mode is enabled
4. Check bot is invited to channel: `/invite @bot`
5. View logs: `npm run slack-bot:logs`

### Issue 2: "Wrong Operation Type"

**Symptoms**: Bot treats local commands as Salesforce (or vice versa)

**Solutions**:
- Be more specific: "git status" instead of just "status"
- Mention files: "refactor slack-bot.js"
- Use keywords: "local repo" or "apex tests"
- The bot will ask if unsure!

### Issue 3: Permission Denied

**Symptoms**: Can't read/write files

**Solutions**:
1. Check `WORKSPACE_ROOT` path in `.env`
2. Ensure bot process has file permissions
3. Try absolute paths in commands

### Issue 4: High Costs

**Symptoms**: Budget alerts

**Solutions**:
1. Check costs: `@bot show costs`
2. Reduce usage of expensive operations (refactoring, analysis)
3. Increase budget: `COST_BUDGET_MONTHLY=200` in `.env`
4. Use git/search operations (free)

---

## Usage Tips

### Tip 1: Use Natural Language

Don't memorize commands! Just talk:
- ✅ "hey, show me what's changed in git"
- ✅ "can you refactor the worker file?"
- ✅ "list all my TODO comments"

### Tip 2: Context Awareness

The bot remembers your conversation:
```
You: "analyze the slack-bot.js file"
Bot: [Analysis]
You: "now refactor it"
Bot: [Knows you mean slack-bot.js]
```

### Tip 3: Approval Workflow

High-risk operations require approval:
```
You: "commit my changes"
Bot: [Shows plan, asks for approval]
You: "yes"
Bot: [Commits]
```

### Tip 4: Multi-Operation Workflows

```
You: "show git status"
Bot: [Shows changes]
You: "commit with message 'Add feature'"
Bot: [Commits]
You: "push to remote"
Bot: [Pushes]
You: "show me the cost so far"
Bot: [Shows $0.00 - git ops are free!]
```

---

## Next Steps

### Learn Available Commands

Read: `LOCAL-OPERATIONS-GUIDE.md`

### Try Examples

```
# Git workflow
"show git status" → "commit changes" → "push"

# Code analysis
"analyze codebase" → "refactor suggested files"

# Search & edit
"find TODO comments" → "create branch" → "edit files"
```

### Monitor Costs

```
"show costs"           # Current spending
"show costs --forecast" # Projected end-of-month
```

### Get Help

```
"help with local operations"
"what can you do?"
"/sf-dev help"
```

---

## Production Deployment

### Using PM2 (Recommended)

```bash
# Start
npm run slack-bot:start

# Monitor
pm2 monit

# Auto-restart on crash
pm2 startup
pm2 save

# View logs
pm2 logs slack-bot --lines 100
```

### Using systemd (Linux)

Create `/etc/systemd/system/slack-bot.service`:

```ini
[Unit]
Description=Salesforce Slack Bot
After=network.target

[Service]
Type=simple
User=your-user
WorkingDirectory=/path/to/salesforce-autonomous-dev-system
ExecStart=/usr/bin/node src/phase2/main.js
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable slack-bot
sudo systemctl start slack-bot
sudo systemctl status slack-bot
```

---

## Security Considerations

1. **Slack Token Security**: Never commit `.env` to git
2. **User Access**: Limit who can use the bot in Slack
3. **File Access**: Bot can modify any file in `WORKSPACE_ROOT`
4. **Git Push**: Always requires explicit approval
5. **Budget Limits**: Set `COST_BUDGET_MONTHLY` to prevent overspending

---

## Support & Troubleshooting

### Check Logs

```bash
# PM2
pm2 logs slack-bot

# Direct run
# Logs appear in console
```

### Debug Mode

Add to `.env`:
```
ENABLE_DEBUG_MODE=true
LOG_LEVEL=debug
```

### Common Log Messages

```
✅ "Local Worker 1 started" - Worker initialized
⚡ "Slack bot is running!" - Bot connected
📊 "Processing task 123 (git-status)" - Task executing
❌ "Task 123 failed" - Check error details
```

---

## Congratulations! 🎉

You now have a unified Slack interface for:
- ✅ Salesforce development (Apex, tests, deployments)
- ✅ Local repository management (git, refactoring, analysis)
- ✅ Natural language control
- ✅ Cost tracking
- ✅ Smart routing

**Start conversing with your bot and watch the magic happen!**

---

**Questions?** Check `LOCAL-OPERATIONS-GUIDE.md` for detailed command reference.

**Phase 3 Status**: ✅ Ready to Use
