# Phase 3 Testing Checklist

Quick reference checklist for testing your implementation.

## Pre-Testing Setup

- [ ] `.env` file created with required variables
- [ ] `npm install` completed successfully
- [ ] All Phase 3 files exist (repo-manager.js, local-repo-worker.js, etc.)

## Unit Tests (No Slack Required)

- [ ] **RepoManager Test**: Run `node tests/test-repo-manager.js` → All tests pass
- [ ] **File Structure Check**: All new files exist and have no syntax errors

## Start the Bot

- [ ] Run `npm run slack-bot`
- [ ] See: "✅ Started 3 Salesforce workers"
- [ ] See: "✅ Started 2 Local repository workers"
- [ ] See: "✅ Slack bot connected"
- [ ] See: "🎉 Phase 3 system is running!"

## Basic Slack Commands

- [ ] `/sf-dev status` → Bot responds with system status
- [ ] `@Bot show status` → Bot responds with Salesforce info

## Local Git Operations (Free)

- [ ] `git status` → Shows current branch and file changes
- [ ] `git diff` → Shows uncommitted changes
- [ ] `git log` → Shows commit history

## Local Code Operations (Free - No AI)

- [ ] `search for TODO` → Finds and lists TODO comments
- [ ] `find all .js files` → Lists JavaScript files
- [ ] `find files in src/` → Lists files in src directory

## Smart Routing Tests

- [ ] `improve 10 apex tests` → Routes to **Salesforce**
- [ ] `refactor slack-bot.js` → Routes to **Local**
- [ ] `git status` → Routes to **Local**
- [ ] `improve 10 tests` → Bot **asks for clarification**

## Approval Workflow

- [ ] `commit my changes` → Shows plan, asks for APPROVE
- [ ] Type `APPROVE` → Commits successfully
- [ ] `git push` → Shows plan
- [ ] Type `CANCEL` → Cancels without pushing

## AI Operations (Costs $)

- [ ] `analyze codebase` → Analyzes and costs ~$0.40
- [ ] `show costs` → Shows updated cost tracking

## Error Handling

- [ ] Invalid command → Bot asks for clarification
- [ ] Invalid git operation → Shows helpful error

## End-to-End Workflow

- [ ] Check status → Edit file → Check status → Commit → Push
- [ ] All steps work smoothly

## Success!

If all checkboxes are ticked: **✅ Phase 3 is fully operational!**

---

## Quick Start Testing (5 minutes)

1. `npm run slack-bot`
2. In Slack: `/sf-dev status`
3. In Slack: `@Bot git status`
4. In Slack: `@Bot search for TODO`
5. All respond? **You're good to go!**

---

## Troubleshooting

**Bot won't start?**
- Check `.env` file has Slack tokens
- Verify Socket Mode is enabled in Slack app

**Bot doesn't respond?**
- Invite bot to channel: `/invite @Bot`
- Check bot is running
- View logs: `npm run slack-bot:logs`

**Wrong routing?**
- Be more specific with keywords
- Mention file names
- Use "local" or "salesforce" explicitly

---

**Full Testing Guide**: See `TESTING-GUIDE.md`
