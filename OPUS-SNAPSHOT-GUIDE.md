# Opus Repository Snapshot Guide

This guide helps you create a complete snapshot of your repository to share with Claude Opus for Phase 2 planning.

## Quick Start

### Option 1: PowerShell (Easiest)

```powershell
cd C:\Users\devin\IdeaProjects\DevAgentWorkspace\salesforce-org-analysis
.\create-opus-snapshot.ps1
```

### Option 2: Node.js Directly

```powershell
cd C:\Users\devin\IdeaProjects\DevAgentWorkspace\salesforce-org-analysis
node create-opus-snapshot.js
```

## What It Does

The script will:

1. **Scan your repository** - Walks through `salesforce-autonomous-dev-system/`
2. **Extract all code** - Services, demos, scripts, CLI tools
3. **Include documentation** - README, implementation guides, snapshots
4. **Generate directory tree** - Visual project structure
5. **Bundle everything** - Creates a single markdown file

## Output Files

After running, you'll get two files:

### 1. `OPUS-REPO-SNAPSHOT.md`

- Complete, formatted repository snapshot
- Includes project structure, all code, documentation
- Organized with table of contents
- Good for viewing/editing

### 2. `OPUS-CLIPBOARD.txt`

- Identical content, optimized for copy/paste
- Easy to copy entire file contents
- Ready to paste into Opus conversation

## How to Use with Opus

### Step 1: Generate the Snapshot

```powershell
.\create-opus-snapshot.ps1
```

Expected output:

```
🚀 Creating Opus Repository Snapshot...

✓ Node.js v20.19.5 detected
📁 Generating project structure...
⚙️  Processing configuration files...
📚 Processing documentation...
💻 Processing service files...
  ✓ ai-code-generator.js (289 lines)
  ✓ deployment-pipeline.js (347 lines)
  ✓ salesforce-manager.js (512 lines)
  ✓ test-orchestrator.js (662 lines)
  ... (and more)

✅ Snapshot created successfully!

📄 Files processed: 25
📊 Total size: 428.5 KB
```

### Step 2: Copy to Clipboard

**Option A - Automatic (Recommended)**:

```powershell
Get-Content OPUS-CLIPBOARD.txt | Set-Clipboard
```

**Option B - Manual**:

1. Open `OPUS-REPO-SNAPSHOT.md` in any text editor
2. Select all (Ctrl+A)
3. Copy (Ctrl+C)

### Step 3: Paste into Opus Conversation

In your Opus conversation, paste the snapshot, then add:

```markdown
[Paste the entire OPUS-REPO-SNAPSHOT.md content here]

---

## Your Phase 2 Planning Task

[Add your Phase 2 planning prompt here - the one we created earlier]
```

## What's Included

The snapshot includes:

### ✅ Configuration Files

- `package.json` - Dependencies and scripts
- `.env.template` - Environment variable structure
- `.gitignore` - Git ignore patterns

### ✅ Documentation

- `README.md` - Project overview
- `IMPLEMENTATION.md` - Setup guide
- `QUICK-START.md` - Quick reference
- `PROJECT-SNAPSHOT-2025-11-24.md` - Current state

### ✅ Source Code - Services (10+ files)

- `ai-code-generator.js` - Claude Sonnet integration
- `test-orchestrator.js` - Test improvement orchestration
- `deployment-pipeline.js` - Salesforce deployment
- `salesforce-manager.js` - Salesforce API client
- `org-analyzer.js` - Org metadata analysis
- `task-analyzer.js` - Task analysis with AI
- `test-code-generator.js` - Test generation
- `test-quality-analyzer.js` - Test quality scoring
- `mock-framework-generator.js` - Mock generation
- `test-data-factory-generator.js` - Test data factories

### ✅ Demos

- `apex-improvement.js` - Main improvement demo
- `batch-analyzer.js` - Batch analysis
- `test-improvement-demo.js` - Test improvement demo

### ✅ Scripts

- `init-system.js` - System initialization
- `health-check.js` - Health validation
- `analyze-org.js` - Org analysis
- `setup.js` - Setup automation
- Plus deployment and changeset scripts

### ✅ CLI Tools

- `submit-task.js` - Task submission CLI
- `interactive.js` - Interactive mode
- `index.js` - Main orchestrator

## What's Excluded

To keep the snapshot manageable, these are excluded:

### ❌ Generated/Runtime Files

- `node_modules/` - Dependencies (referenced in package.json)
- `output/` - Generated reports and artifacts
- `logs/` - System logs
- `cache/` - Cached data
- `metadata/` - Org metadata exports
- `deployments/` - Deployment artifacts
- `analysis/` - Analysis results

### ❌ Environment/Credentials

- `.env` - Actual credentials (template included)
- `.git/` - Git metadata

## Snapshot Statistics

Typical snapshot includes:

- **~25-30 files**
- **~400-500 KB total**
- **~15,000-20,000 lines of code**
- **Organized into 7 sections** with table of contents

## Troubleshooting

### Error: "Node.js not found"

**Solution**: Install Node.js from https://nodejs.org/

### Error: "Cannot find module 'fs-extra'"

**Solution**: Install dependencies first

```powershell
cd salesforce-autonomous-dev-system
npm install
cd ..
```

### Snapshot is too large for Opus

**Solution**: The snapshot is optimized, but if Opus complains about size:

1. Remove some documentation sections
2. Focus only on core services
3. Split into multiple messages

### File paths not found

**Solution**: Make sure you're running from the correct directory:

```powershell
# Should be in the root of salesforce-org-analysis repo
cd C:\Users\devin\IdeaProjects\DevAgentWorkspace\salesforce-org-analysis
pwd  # Verify location
```

## Advanced Usage

### Custom File Selection

Edit `create-opus-snapshot.js` to customize what's included:

```javascript
// Add more patterns
const INCLUDE_PATTERNS = {
  source: [
    "salesforce-autonomous-dev-system/src/**/*.js",
    "salesforce-autonomous-dev-system/your-custom-dir/**/*.js" // Add this
  ]
  // ...
};
```

### Exclude Specific Files

```javascript
// Skip certain files
const SKIP_FILES = ['test-orchestrator.js'];  // Add this

// In the loop
if (SKIP_FILES.includes(serviceFile)) continue;
```

## Next Steps

After creating the snapshot:

1. ✅ **Copy snapshot to clipboard** (or open file)
2. ✅ **Open Opus conversation**
3. ✅ **Paste snapshot first**
4. ✅ **Add Phase 2 planning prompt after**
5. ✅ **Let Opus analyze and respond**

Opus will have complete visibility into your codebase and can design Phase 2 with full context!

---

**Questions?**

- Check if snapshot file was created: `ls OPUS-*.* | Format-List`
- View snapshot size: `(Get-Item OPUS-CLIPBOARD.txt).length / 1KB` (KB)
- Count lines: `(Get-Content OPUS-CLIPBOARD.txt | Measure-Object -Line).Lines`
