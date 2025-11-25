# Phase 3 Testing Guide

Step-by-step guide to test your Phase 3 Slack bot implementation.

## Pre-Flight Checks

### 1. Check Environment Variables

Create your `.env` file if you haven't already:

```bash
cp .env.template .env
```

**Minimum required for testing (without Slack)**:
```bash
ANTHROPIC_API_KEY=your-key-here
WORKSPACE_ROOT=C:\Users\devin\IdeaProjects\DevAgentWorkspace
```

**For full Slack testing, also add**:
```bash
SLACK_BOT_TOKEN=xoxb-your-token
SLACK_SIGNING_SECRET=your-secret
SLACK_APP_TOKEN=xapp-your-token
SLACK_CHANNEL=#salesforce-dev
```

### 2. Verify Dependencies

```bash
npm install
```

### 3. Check File Structure

Verify Phase 3 files exist:

```bash
# Run this command
dir src\services\repo-manager.js
dir src\phase2\local-repo-worker.js
dir src\phase2\smart-router.js
dir src\phase2\local-formatters.js
```

All should exist and not show errors.

---

## Stage 1: Unit Tests (No Slack Required)

Test individual components work correctly.

### Test 1: RepoManager

```bash
node tests/test-repo-manager.js
```

**Expected Output**:
```
🧪 Testing RepoManager...

Test 1: Setting repository...
✅ Repository set: C:\Users\devin\IdeaProjects\DevAgentWorkspace\salesforce-autonomous-dev-system

Test 2: Getting current branch...
✅ Current branch: master (or your current branch)

Test 3: Getting git status...
✅ Status: { clean: true/false, modified: [...], ... }

Test 4: Listing workspace repos...
✅ Found repos: 2
  - salesforce-autonomous-dev-system
  - salesforce-org-analysis

Test 5: Getting remotes...
✅ Remotes: { "origin": { "fetch": "...", "push": "..." } }

🎉 All RepoManager tests passed!
```

**If it fails**: Check that you're in a git repository and `WORKSPACE_ROOT` is set correctly.

### Test 2: NL Parser (Extended)

Create a test file to verify the parser handles both operation types:

```bash
node -e "
import { NLCommandParser } from './src/phase2/nl-command-parser.js';
const parser = new NLCommandParser();

// Test Salesforce intent
const sf = parser.quickClassify('improve 10 apex tests');
console.log('Salesforce test:', sf?.operationType === 'salesforce' ? '✅' : '❌');

// Test Local intent
const local = parser.quickClassify('git status');
console.log('Local test:', local?.operationType === 'local' ? '✅' : '❌');

// Test approval
const approve = parser.quickClassify('approve');
console.log('Approve test:', approve?.intent === 'approve' ? '✅' : '❌');
"
```

**Expected Output**:
```
Salesforce test: ✅
Local test: ✅
Approve test: ✅
```

---

## Stage 2: Integration Tests (With Slack - Basic)

These tests require Slack to be configured.

### Test 1: Start the Bot

```bash
npm run slack-bot
```

**Expected Output**:
```
🚀 Starting Phase 3 Multi-Agent System...
📦 Initializing Salesforce + Local Repository Operations

✅ Started 3 Salesforce workers
✅ Started 2 Local repository workers
✅ Slack bot connected

🎉 Phase 3 system is running!
📱 Salesforce operations: Active
💻 Local repository operations: Active

Try these commands in Slack:
  - "show git status"
  - "analyze my local codebase"
  - "/sf-dev status"
```

**If it fails**:
- Check Slack tokens in `.env`
- Verify Socket Mode is enabled in Slack app
- Check bot is invited to your channel

### Test 2: Slash Command

In Slack, type:
```
/sf-dev status
```

**Expected Response**:
- System status message
- Active workers count
- Queue size
- Cost information

**If it fails**:
- Check bot is running
- Verify slash command is configured in Slack
- Check console logs for errors

### Test 3: App Mention (Salesforce)

In Slack, type:
```
@YourBot show status
```

**Expected Response**:
- Bot responds with Salesforce system status
- Shows worker information
- Default routes to Salesforce (not local)

---

## Stage 3: Local Operations Testing

Test all local repository operations.

### Test 1: Git Status

In Slack:
```
@YourBot show git status
```

**Expected Response**:
```
📌 Branch: master
✅ Working directory is clean
(or list of modified files)
```

**Verify**:
- ✅ Bot detected "git" keyword
- ✅ Routed to local operations
- ✅ Shows current branch
- ✅ Shows file status

### Test 2: Git Diff

```
@YourBot show git diff
```

**Expected Response**:
- Shows diff of unstaged changes
- Or "No differences" if clean

### Test 3: Code Search

```
@YourBot search for TODO in the code
```

**Expected Response**:
```
🔍 Search Results
Pattern: `TODO`
Matches: X

📄 `file.js:123`
    // TODO: Fix this
...
```

### Test 4: Find Files

```
@YourBot find all .js files in src/
```

**Expected Response**:
- List of matching files
- File count
- Truncated if many files

### Test 5: Analyze Codebase

```
@YourBot analyze my local codebase
```

**Expected Response**:
- "⏳ Analyzing..." (thinking indicator)
- Architecture overview
- Key components identified
- Suggestions

**Note**: This costs ~$0.40 (uses Claude API)

---

## Stage 4: Approval Workflow Testing

Test that high-risk operations require approval.

### Test 1: Refactoring (Requires Approval)

```
@YourBot refactor slack-bot.js to use better error handling
```

**Expected Response**:
```
📝 Execution Plan

Refactor code in salesforce-autonomous-dev-system: ...

Estimated Cost: $0.50
Estimated Time: ~4 min

⚠️ Type APPROVE to proceed or CANCEL to abort.
```

**Then type**:
```
APPROVE
```

**Expected**:
- Bot confirms: "Approved! Starting execution..."
- Shows progress
- Shows results when complete

**Then type**:
```
@YourBot show git status
```

**Expected**: Should show slack-bot.js as modified

### Test 2: Git Commit (Requires Approval)

```
@YourBot commit these changes with message "Test Phase 3"
```

**Expected**:
- Shows commit plan
- Asks for approval

**Type**: `APPROVE`

**Expected**:
- Commits changes
- Shows commit hash

### Test 3: Cancellation

```
@YourBot git push
```

**Expected**: Shows push plan

**Type**: `CANCEL`

**Expected**:
- "Action cancelled"
- No push occurs

---

## Stage 5: Smart Routing Tests

Test that the bot correctly identifies operation types.

### Test 1: Salesforce Keywords

```
@YourBot improve 10 apex tests
```

**Expected**:
- Bot detects "apex" → Salesforce
- Routes to Salesforce worker pool
- Queues Salesforce test improvements

### Test 2: Local Keywords

```
@YourBot refactor the local worker code
```

**Expected**:
- Bot detects "local" → Local operations
- Routes to local worker pool

### Test 3: File Names

```
@YourBot analyze slack-bot.js
```

**Expected**:
- Bot detects ".js" file → Local
- Analyzes local file

### Test 4: Ambiguous (Should Ask)

```
@YourBot improve 10 tests
```

**Expected**:
- Bot is unsure (could be Apex or JavaScript tests)
- Asks: "Are you referring to Salesforce Apex tests or local JavaScript tests?"

**Then clarify**:
```
local
```

**Expected**:
- Bot proceeds with local test operation

---

## Stage 6: End-to-End Workflows

Test complete workflows from start to finish.

### Workflow 1: Code Change Flow

**Step 1**: Check status
```
@YourBot git status
```

**Step 2**: Make a change (manually edit a file, add a comment)

**Step 3**: Check status again
```
@YourBot git status
```
**Expected**: Shows modified file

**Step 4**: Commit
```
@YourBot commit with message "Test Phase 3 workflow"
```
**Type**: `APPROVE`

**Step 5**: Verify
```
@YourBot git log
```
**Expected**: Shows your new commit

### Workflow 2: Search → Create Branch → Edit

**Step 1**: Search
```
@YourBot search for FIXME comments
```

**Step 2**: Create branch
```
@YourBot create branch called fix/cleanup
```

**Step 3**: Verify
```
@YourBot git status
```
**Expected**: Shows new branch "fix/cleanup"

### Workflow 3: Mixed Operations

**Step 1**: Local operation
```
@YourBot analyze my local codebase
```

**Step 2**: Salesforce operation (in same conversation)
```
@YourBot now show my salesforce org coverage
```

**Expected**: Bot seamlessly switches between operation types

---

## Stage 7: Error Handling Tests

Test that errors are handled gracefully.

### Test 1: Invalid Git Operation

```
@YourBot git push to nonexistent-remote
```

**Expected**:
- Error message
- Helpful guidance

### Test 2: Permission Denied

```
@YourBot edit /etc/hosts
```

**Expected**:
- Permission denied error
- Graceful failure

### Test 3: Invalid Command

```
@YourBot do something impossible
```

**Expected**:
- Bot doesn't understand
- Asks for clarification or suggests valid commands

---

## Stage 8: Cost Tracking Tests

Verify cost tracking works across both operation types.

### Test 1: Check Initial Costs

```
@YourBot show costs
```

**Expected**:
- Current month's spending
- Budget remaining
- Breakdown by operation type

### Test 2: Perform Paid Operation

```
@YourBot analyze codebase
```

**Expected**: Costs ~$0.40

### Test 3: Check Updated Costs

```
@YourBot show costs
```

**Expected**:
- Increased by ~$0.40
- Shows updated totals

### Test 4: Free Operations

```
@YourBot git status
@YourBot search code
@YourBot find files
```

**Then**:
```
@YourBot show costs
```

**Expected**: Cost unchanged (these are free)

---

## Troubleshooting Common Issues

### Issue: Bot doesn't respond

**Check**:
1. Is bot running? (`pm2 status` or check console)
2. Is bot invited to channel? (`/invite @bot`)
3. Check logs: `npm run slack-bot:logs`

**Solution**: Restart bot: `npm run slack-bot:restart`

### Issue: "Wrong operation type"

**Check**:
- What keywords did you use?
- Were you specific enough?

**Solution**:
- Be more explicit: "git status" not just "status"
- Mention file names
- Use "local" or "salesforce" keywords

### Issue: Approval not working

**Check**:
- Did you type exact word: "APPROVE" or "YES"?
- Are you in the same channel/DM?
- Has 30 minutes passed?

**Solution**: Type the exact approval keyword

### Issue: High costs

**Check**: `@YourBot show costs`

**Solution**:
- Use free operations (git, search)
- Reduce AI operations (refactor, analyze)
- Increase budget if needed

---

## Success Criteria

Your Phase 3 bot is working correctly if:

✅ Bot starts without errors
✅ Responds to `/sf-dev status`
✅ Responds to natural language
✅ Git operations work (status, diff)
✅ Routes Salesforce vs Local correctly
✅ Asks for clarification when ambiguous
✅ Approval workflow functions
✅ Cost tracking is accurate
✅ Both worker pools are active

---

## Next Steps After Testing

Once all tests pass:

1. **Use in production**: Start with `npm run slack-bot:start`
2. **Monitor logs**: `pm2 logs slack-bot`
3. **Track costs**: Check daily with `@bot show costs`
4. **Iterate**: Based on usage, adjust worker counts
5. **Enjoy**: Control your entire dev environment from Slack!

---

## Quick Test Script

Run all basic tests at once:

```bash
# Test 1: RepoManager
node tests/test-repo-manager.js

# Test 2: Check bot can start (will need to stop manually)
timeout /t 10 npm run slack-bot
```

Then in Slack:
```
/sf-dev status
@YourBot git status
@YourBot search for TODO
@YourBot analyze codebase
```

If all respond correctly: **✅ Phase 3 is working!**

---

**Testing Status**: Follow this guide step-by-step
**Support**: Check logs and console output for detailed error messages
