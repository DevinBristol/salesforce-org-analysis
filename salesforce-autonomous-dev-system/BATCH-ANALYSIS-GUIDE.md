# Batch Codebase Analysis Guide

## Overview

The batch analysis system allows you to analyze your entire Salesforce codebase (all ~3,934 Apex classes) to:

- **Rank classes** by improvement priority
- **Generate comprehensive org report** with actionable insights
- **Track progress** and resume analysis
- **Identify critical issues** (SOQL in loops, missing error handling, etc.)
- **Plan improvements** without deploying anything

## Quick Start

### Option 1: Fast Analysis (Recommended First Run)

Analyzes metadata only - completes in ~10-15 minutes for all classes:

```powershell
.\overnight-batch-analysis.ps1
```

### Option 2: Deep Analysis (Most Accurate)

Fetches and analyzes actual code content - takes 2-4 hours for all classes:

```powershell
.\overnight-batch-analysis.ps1 -Deep
```

### Option 3: Quick Test (20 classes)

Test the system on first 20 classes:

```powershell
.\overnight-batch-analysis.ps1 -Limit 20
```

---

## Analysis Modes

### Fast Mode (Metadata Only)

- **Speed:** ~0.5 seconds per class
- **Total Time:** ~15 minutes for 3,934 classes
- **Analyzes:**
  - Class name patterns (Handler, Util, Controller, etc.)
  - Last modified date
  - File age
- **Does NOT analyze:**
  - Actual code content
  - Complexity metrics
  - SOQL/DML patterns

**Use when:** You want a quick overview to prioritize which classes need attention

### Deep Mode (Content Analysis)

- **Speed:** ~2-5 seconds per class (API rate limits)
- **Total Time:** 2-4 hours for 3,934 classes
- **Analyzes:**
  - Everything from Fast Mode PLUS:
  - Lines of code
  - Method count
  - JavaDoc coverage
  - Try-catch presence
  - **SOQL in loops (CRITICAL)**
  - **DML in loops (CRITICAL)**
  - Error handling patterns

**Use when:** You want accurate, code-based priority scoring for improvement planning

---

## NPM Scripts

### Analyze Entire Codebase

```bash
npm run batch:analyze           # Fast mode (metadata only)
npm run batch:analyze-deep      # Deep mode (with content)
npm run batch:quick             # Test with 20 classes
```

### Advanced Options

```bash
# Deep analysis with all options
node demos/batch-analyzer.js --analyze-content --include-tests --include-managed

# Resume from previous run
node demos/batch-analyzer.js  # Automatically resumes

# Fresh start (ignore progress)
node demos/batch-analyzer.js --fresh
```

---

## Command Line Flags

| Flag                | Description                                           |
| ------------------- | ----------------------------------------------------- |
| `--analyze-content` | Fetch and analyze actual code (slower, more accurate) |
| `--limit <N>`       | Only analyze first N classes                          |
| `--include-tests`   | Include test classes (default: skip)                  |
| `--include-managed` | Include managed package classes (default: skip)       |
| `--fresh`           | Start fresh, ignore progress file                     |

---

## Output Files

### 1. Comprehensive Report

**File:** `./analysis/org-analysis-report.md`

Contains:

- Executive summary with org health grade
- Top 20 classes needing improvement
- Critical issues (60+ score)
- High priority items (40-59 score)
- Recommendations by priority
- Category breakdowns (documentation, bulkification, errors, complexity)
- Statistics and score distribution

**View:**

```bash
cat ./analysis/org-analysis-report.md
code ./analysis/org-analysis-report.md  # VS Code
```

### 2. Detailed JSON Data

**File:** `./analysis/org-analysis-data.json`

Contains:

- All analysis results in structured JSON
- Filterable by score, risk, categories
- Use for custom reporting or dashboards

### 3. Progress Tracker

**File:** `./analysis/progress.json`

Contains:

- List of processed classes
- Intermediate results
- Resume capability

---

## Scoring System

Classes are scored 0-100 based on multiple factors:

### Score Categories

| Category           | Max Points | What It Measures                             |
| ------------------ | ---------- | -------------------------------------------- |
| **Age**            | 20         | How long since last modified                 |
| **Type**           | 25         | Class type (Handler=25, Trigger=20, Util=15) |
| **Complexity**     | 15         | Lines of code, method count                  |
| **Documentation**  | 20         | JavaDoc coverage                             |
| **Error Handling** | 15         | Try-catch presence                           |
| **Bulkification**  | 10         | SOQL/DML in loops (CRITICAL)                 |

### Priority Levels

- **🔴 Critical (60+ points):** Immediate attention needed
- **🟠 High (40-59 points):** Address in next sprint
- **🟡 Medium (20-39 points):** Plan for next month
- **🟢 Low (<20 points):** Monitor, no immediate action

### Risk Levels

- **⚠️ High Risk:** Batch/Scheduled classes, SOQL/DML in loops
- **⚡ Medium Risk:** Handlers, Controllers, Triggers
- **✅ Low Risk:** Utils, Helpers, Services

---

## Example Workflows

### Workflow 1: Full Overnight Analysis (Recommended)

**Night 1: Fast Analysis**

```powershell
.\overnight-batch-analysis.ps1
```

- Completes in ~15 minutes
- Review report in the morning
- Identify top priority classes

**Night 2: Deep Analysis on Priority Classes**

```powershell
.\overnight-batch-analysis.ps1 -Deep -Limit 100
```

- Analyzes top 100 classes with content
- Get accurate scoring
- Plan sprint work

**Day: Review & Improve**

```bash
cat ./analysis/org-analysis-report.md  # Read the report
npm run demo:apex-improvement          # Improve one class at a time
```

### Workflow 2: Quick Test & Iterate

```powershell
# 1. Test with 10 classes first
.\overnight-batch-analysis.ps1 -Limit 10

# 2. Review the report format
cat ./analysis/org-analysis-report.md

# 3. Run on more classes
.\overnight-batch-analysis.ps1 -Limit 50

# 4. Full analysis overnight
.\overnight-batch-analysis.ps1 -Deep
```

### Workflow 3: Resume After Interruption

The batch analyzer automatically saves progress every 10 classes:

```powershell
# Start analysis
.\overnight-batch-analysis.ps1 -Deep

# ... gets interrupted after 500 classes ...

# Resume where you left off (automatic)
.\overnight-batch-analysis.ps1 -Deep
# Output: "Resuming from previous run: 500 classes already analyzed"
```

---

## Understanding the Report

### Executive Summary

Shows org health grade:

- 🟢 Excellent (<15 avg score): Well-maintained codebase
- 🟡 Good (15-30): Normal maintenance needed
- 🟠 Fair (30-50): Significant tech debt
- 🔴 Needs Attention (50+): Critical issues present

### Top 20 Table

Ranked list with:

- Score (higher = more improvement needed)
- Risk level
- Key issues summary

### Critical Issues Section

Details for each critical class:

- Full score breakdown
- Specific issues found
- Category scores

### Recommendations

Actionable items grouped by:

- Immediate (this sprint)
- Short-term (this month)
- Long-term (this quarter)

### Category Analysis

Deep dives into:

- **Documentation:** Classes missing JavaDoc
- **Bulkification:** SOQL/DML in loops (fix immediately!)
- **Error Handling:** Missing try-catch blocks
- **Complexity:** Large/complex classes

---

## Next Steps After Analysis

### 1. Review the Report

```bash
cat ./analysis/org-analysis-report.md
```

Look for:

- Bulkification issues (SOQL/DML in loops) - **FIX FIRST!**
- Classes with 60+ scores
- Your most critical business logic classes

### 2. Improve Individual Classes

**Manual selection:**

```bash
npm run demo:apex-improvement
# Picks random low-risk class
```

**Target specific classes:**
Edit `demos/apex-improvement.js` to target specific class names from the report.

### 3. Deploy to Sandbox

All improvements deploy to Devin1 sandbox automatically:

```bash
sf org open --target-org Devin1
# Navigate to: Setup → Apex Classes → <ClassName>
```

### 4. Re-analyze

After improvements, re-run analysis to track progress:

```bash
.\overnight-batch-analysis.ps1 --fresh -Deep
```

Compare reports to see improvement.

---

## Collapsible Regions in IntelliJ

Improved code now includes collapsible regions:

```apex
//region IMPROVED: Error handling and validation
public static void processData(List<Lead> leads) {
    // IMPROVED: Added null check
    if (leads == null || leads.isEmpty()) {
        return;
    }
    // ... code ...
}
//endregion
```

**In IntelliJ:**

- Click the **minus (-)** in the gutter to collapse
- `Ctrl + Minus` to collapse all regions
- `Ctrl + Plus` to expand all regions

All changed sections are wrapped in regions, unchanged code has JavaDoc only.

---

## Troubleshooting

### Analysis Stops/Fails

Check logs:

```bash
cat logs/batch-analysis.log
```

Common issues:

- **Authentication expired:** Re-auth with `sf org login web`
- **Rate limits:** Add delays or run Fast Mode first
- **Memory issues:** Use `--limit` to process in batches

### Progress Not Saving

Progress saves every 10 classes. If interrupted:

1. Check `./analysis/progress.json` exists
2. Resume with same command (no --fresh flag)

### Report Looks Wrong

Re-generate report from saved data:

```bash
node demos/batch-analyzer.js --limit 0 --fresh
```

Or delete progress and re-run:

```bash
rm ./analysis/progress.json
.\overnight-batch-analysis.ps1
```

---

## Performance Tips

1. **Start with Fast Mode** - Get overview in 15 minutes
2. **Use --limit for testing** - Test with 10-20 classes first
3. **Run Deep Mode overnight** - Let it run for 2-4 hours unattended
4. **Skip tests/managed** - Default behavior, saves time
5. **Resume automatically** - Progress saves every 10 classes

---

## Cost Considerations

### Fast Mode (Metadata Only)

- **API Calls:** Minimal (1 metadata fetch)
- **Claude API:** None
- **Cost:** $0
- **Time:** ~15 minutes

### Deep Mode (Content Analysis)

- **API Calls:** ~4,000 (1 per class)
- **Claude API:** None (scoring is regex-based)
- **Cost:** Salesforce API usage only
- **Time:** 2-4 hours

---

## Comparison: Batch Analysis vs Individual Improvement

| Feature        | Batch Analysis    | Individual Improvement     |
| -------------- | ----------------- | -------------------------- |
| **Purpose**    | Rank & report     | Improve & deploy           |
| **Scope**      | All 3,934 classes | 1 class at a time          |
| **Speed**      | 15 min - 4 hours  | 1-2 minutes per class      |
| **Deployment** | None              | Deploys to Devin1          |
| **Output**     | Org report        | Class improvement + report |
| **Use when**   | Planning phase    | Execution phase            |

**Recommended Workflow:**

1. Run batch analysis → Get org report
2. Review report → Identify priorities
3. Run individual improvements → Deploy targeted fixes

---

## Summary

### Fast Analysis Command

```powershell
.\overnight-batch-analysis.ps1
# ~15 minutes, scores all 3,934 classes
```

### Deep Analysis Command

```powershell
.\overnight-batch-analysis.ps1 -Deep
# ~2-4 hours, analyzes actual code
```

### View Report

```bash
cat ./analysis/org-analysis-report.md
```

### Improve Classes

```bash
npm run demo:apex-improvement
```

---

**You're now ready to analyze your entire Salesforce codebase overnight!** 🌙
