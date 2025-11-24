// demos/batch-analyzer.js - Batch Codebase Analysis Without Deployment

import { Anthropic } from "@anthropic-ai/sdk";
import dotenv from "dotenv";
import chalk from "chalk";
import ora from "ora";
import fs from "fs-extra";
import path from "path";
import winston from "winston";
import { SalesforceManager } from "../src/services/salesforce-manager.js";
import { AICodeGenerator } from "../src/services/ai-code-generator.js";
import { OrgAnalyzer } from "../src/services/org-analyzer.js";

dotenv.config();

// Configure logging
const logger = winston.createLogger({
  level: "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.simple()
  ),
  transports: [
    new winston.transports.File({ filename: "logs/batch-analysis.log" }),
    new winston.transports.Console()
  ]
});

class BatchCodebaseAnalyzer {
  constructor() {
    this.anthropic = new Anthropic({
      apiKey: process.env.CLAUDE_API_KEY
    });
    this.salesforceManager = new SalesforceManager(logger);
    this.aiCodeGenerator = new AICodeGenerator(this.anthropic, logger);
    this.orgAnalyzer = new OrgAnalyzer(logger);
    this.analysisResults = [];
    this.progressFile = "./analysis/progress.json";
  }

  async run(options = {}) {
    const {
      maxClasses = null, // null = analyze all
      analyzeContent = false, // if true, fetches and analyzes class content
      skipManaged = true,
      skipTests = true,
      resumeFromProgress = true
    } = options;

    console.log(
      chalk.cyan.bold(
        "\n╔══════════════════════════════════════════════════════╗"
      )
    );
    console.log(
      chalk.cyan.bold(
        "║     Batch Codebase Analysis (No Deployment)          ║"
      )
    );
    console.log(
      chalk.cyan.bold(
        "╚══════════════════════════════════════════════════════╝\n"
      )
    );

    try {
      // Load progress if resuming
      let processedClasses = new Set();
      if (resumeFromProgress && (await fs.pathExists(this.progressFile))) {
        const progress = await fs.readJson(this.progressFile);
        processedClasses = new Set(progress.processedClasses || []);
        this.analysisResults = progress.results || [];
        console.log(
          chalk.yellow(
            `Resuming from previous run: ${processedClasses.size} classes already analyzed\n`
          )
        );
      }

      // Step 1: Connect to Salesforce
      const connectSpinner = ora("Connecting to Salesforce...").start();
      await this.salesforceManager.connect();
      connectSpinner.succeed("Connected to Salesforce");

      // Step 2: Fetch org metadata
      const metadataSpinner = ora("Fetching org metadata...").start();
      await this.salesforceManager.fetchMetadata(["ApexClass"]);
      metadataSpinner.succeed("Metadata fetched");

      // Step 2.5: Fetch test coverage data
      const coverageSpinner = ora("Fetching test coverage data...").start();
      const coverageMap = await this.orgAnalyzer.getTestCoverage(
        this.salesforceManager
      );
      const orgCoverage = this.orgAnalyzer.calculateOrgCoverage(coverageMap);
      coverageSpinner.succeed(`Test coverage fetched - Org: ${orgCoverage}%`);
      this.coverageMap = coverageMap;
      this.orgCoverage = orgCoverage;

      // Step 3: Get all Apex classes
      const scanSpinner = ora("Scanning Apex classes...").start();
      let allClasses = await this.salesforceManager.getApexClasses();

      // Filter classes
      if (skipTests) {
        allClasses = allClasses.filter(
          (c) => !c.fullName.toLowerCase().includes("test")
        );
      }
      if (skipManaged) {
        allClasses = allClasses.filter((c) => !c.fullName.includes("__"));
      }

      // Remove already processed
      allClasses = allClasses.filter((c) => !processedClasses.has(c.fullName));

      // Limit if specified
      if (maxClasses) {
        allClasses = allClasses.slice(0, maxClasses);
      }

      scanSpinner.succeed(
        `Found ${allClasses.length} classes to analyze (${processedClasses.size} already done)`
      );

      // Step 4: Analyze each class
      console.log(chalk.blue(`\nAnalyzing ${allClasses.length} classes...\n`));

      for (let i = 0; i < allClasses.length; i++) {
        const apexClass = allClasses[i];
        const progress = `[${i + 1}/${allClasses.length}]`;

        const spinner = ora(
          `${progress} Analyzing ${apexClass.fullName}...`
        ).start();

        try {
          let classContent = null;

          // Fetch content if requested (slower but more accurate)
          if (analyzeContent) {
            try {
              classContent = await this.salesforceManager.getApexClassContent(
                apexClass.fullName
              );
            } catch (error) {
              logger.warn(
                `Could not fetch content for ${apexClass.fullName}: ${error.message}`
              );
            }
          }

          // Calculate score
          const score = this.orgAnalyzer.calculateImprovementScore(
            apexClass,
            classContent
          );

          // Get test coverage
          const coverage = this.coverageMap[apexClass.fullName] || {
            coverage: 0,
            linesCovered: 0,
            linesUncovered: 0,
            totalLines: 0
          };

          // Calculate complexity metrics (if content available)
          const complexity = classContent
            ? this.orgAnalyzer.calculateComplexityMetrics(classContent)
            : {
                cyclomaticComplexity: 0,
                cognitiveComplexity: 0,
                maintainabilityIndex: 0,
                technicalDebtMinutes: 0
              };

          // Scan for security vulnerabilities (if content available)
          const security = classContent
            ? this.orgAnalyzer.scanSecurityVulnerabilities(
                classContent,
                apexClass.fullName
              )
            : { critical: [], high: [], medium: [], low: [] };

          // Analyze API version
          const apiVersion = this.orgAnalyzer.analyzeApiVersion(apexClass);

          const result = {
            className: apexClass.fullName,
            lastModified: apexClass.lastModifiedDate,
            score: score.total,
            riskLevel: score.risk,
            reasons: score.reasons,
            categories: score.categories,
            lineCount: classContent ? classContent.split("\n").length : "N/A",
            analyzedContent: analyzeContent,
            // New enhanced metrics
            coverage: coverage.coverage,
            coverageDetails: coverage,
            complexity: complexity,
            security: security,
            apiVersion: apiVersion,
            // Derived flags
            hasCriticalSecurity: security.critical.length > 0,
            hasHighSecurity: security.high.length > 0,
            blocksDeployment: coverage.coverage < 75,
            highComplexity: complexity.cyclomaticComplexity > 50,
            technicalDebtHours:
              Math.round((complexity.technicalDebtMinutes / 60) * 10) / 10
          };

          this.analysisResults.push(result);
          processedClasses.add(apexClass.fullName);

          // Enhanced spinner message
          const securityBadge =
            security.critical.length > 0
              ? " 🔴SEC"
              : security.high.length > 0
                ? " 🟠SEC"
                : "";
          const coverageBadge =
            coverage.coverage === 0
              ? " 📊0%"
              : coverage.coverage < 75
                ? ` 📊${coverage.coverage}%`
                : "";
          spinner.succeed(
            `${progress} ${apexClass.fullName} - Score: ${score.total} (${score.risk})${securityBadge}${coverageBadge}`
          );

          // Save progress periodically (every 10 classes)
          if ((i + 1) % 10 === 0) {
            await this.saveProgress(processedClasses);
          }
        } catch (error) {
          spinner.fail(`${progress} Failed to analyze ${apexClass.fullName}`);
          logger.error(`Analysis error for ${apexClass.fullName}:`, error);
        }
      }

      // Step 5: Save final progress
      await this.saveProgress(processedClasses);

      // Step 6: Generate comprehensive report
      console.log(chalk.blue("\nGenerating comprehensive org report...\n"));
      await this.generateOrgReport();

      console.log(chalk.green.bold("\n✓ Batch analysis completed!"));
      console.log(
        chalk.gray(`Report saved to: ./analysis/org-analysis-report.md`)
      );
      console.log(
        chalk.gray(`Detailed data saved to: ./analysis/org-analysis-data.json`)
      );
    } catch (error) {
      console.error(chalk.red("\n✗ Batch analysis failed:"), error.message);
      logger.error("Batch analysis error:", error);
      process.exit(1);
    }
  }

  async saveProgress(processedClasses) {
    await fs.ensureDir("./analysis");
    await fs.writeJson(
      this.progressFile,
      {
        lastUpdated: new Date().toISOString(),
        processedClasses: Array.from(processedClasses),
        results: this.analysisResults
      },
      { spaces: 2 }
    );
  }

  async generateOrgReport() {
    await fs.ensureDir("./analysis");

    // Sort results by score (highest first)
    const sortedResults = [...this.analysisResults].sort(
      (a, b) => b.score - a.score
    );

    // Calculate statistics
    const stats = this.calculateStatistics(sortedResults);

    // Group by risk level
    const critical = sortedResults.filter((r) => r.score >= 60);
    const high = sortedResults.filter((r) => r.score >= 40 && r.score < 60);
    const medium = sortedResults.filter((r) => r.score >= 20 && r.score < 40);
    const low = sortedResults.filter((r) => r.score < 20);

    // Group by risk level
    const highRisk = sortedResults.filter((r) => r.riskLevel === "high");
    const mediumRisk = sortedResults.filter((r) => r.riskLevel === "medium");
    const lowRisk = sortedResults.filter((r) => r.riskLevel === "low");

    // NEW: Test Coverage Groups
    const zeroCoverage = sortedResults.filter((r) => r.coverage === 0);
    const lowCoverage = sortedResults.filter(
      (r) => r.coverage > 0 && r.coverage < 75
    );
    const goodCoverage = sortedResults.filter(
      (r) => r.coverage >= 75 && r.coverage < 90
    );
    const excellentCoverage = sortedResults.filter((r) => r.coverage >= 90);

    // NEW: Security Groups
    const criticalSecurity = sortedResults.filter((r) => r.hasCriticalSecurity);
    const highSecurity = sortedResults.filter(
      (r) => r.hasHighSecurity && !r.hasCriticalSecurity
    );

    // NEW: Complexity Groups
    const highComplexityClasses = sortedResults.filter((r) => r.highComplexity);
    const totalTechDebt = sortedResults.reduce(
      (sum, r) => sum + (r.technicalDebtHours || 0),
      0
    );

    // NEW: API Version Groups
    const outdatedApi = sortedResults.filter(
      (r) => r.apiVersion && r.apiVersion.isOutdated
    );
    const deprecatedApi = sortedResults.filter(
      (r) => r.apiVersion && r.apiVersion.isDeprecated
    );

    // Build report
    const report = `# Salesforce Org Codebase Analysis Report

**Generated:** ${new Date().toISOString()}
**Total Classes Analyzed:** ${sortedResults.length}
**Analysis Type:** ${sortedResults[0]?.analyzedContent ? "Deep (with content analysis)" : "Fast (metadata only)"}

---

## Executive Summary

### Overall Org Health Score
**${this.calculateHealthGrade(stats.averageScore)}** (${stats.averageScore.toFixed(1)} / 100)

### Key Metrics
- **Total Classes:** ${sortedResults.length}
- **Org Test Coverage:** ${this.orgCoverage}% ${this.orgCoverage >= 90 ? "✅" : this.orgCoverage >= 75 ? "🟡" : "🔴"}
- **Average Improvement Score:** ${stats.averageScore.toFixed(1)}
- **Classes Needing Attention:** ${critical.length + high.length} (${(((critical.length + high.length) / sortedResults.length) * 100).toFixed(1)}%)
- **Security Issues:** ${criticalSecurity.length} CRITICAL, ${highSecurity.length} HIGH
- **Technical Debt:** ${totalTechDebt.toFixed(1)} hours (${(totalTechDebt / 8).toFixed(1)} days)

### Priority Breakdown
- 🔴 **Critical (60+ points):** ${critical.length} classes
- 🟠 **High (40-59 points):** ${high.length} classes
- 🟡 **Medium (20-39 points):** ${medium.length} classes
- 🟢 **Low (<20 points):** ${low.length} classes

### Test Coverage Breakdown
- **0% Coverage:** ${zeroCoverage.length} classes (🔴 HIGH PRIORITY)
- **<75% Coverage:** ${lowCoverage.length} classes (🟠 Blocks deployment)
- **75-90% Coverage:** ${goodCoverage.length} classes (🟡 Good)
- **90%+ Coverage:** ${excellentCoverage.length} classes (✅ Excellent)

### Security Alert Summary
- **🚨 CRITICAL:** ${criticalSecurity.length} classes with critical vulnerabilities
- **⚠️ HIGH:** ${highSecurity.length} classes with high-risk issues

### Risk Distribution
- ⚠️  **High Risk:** ${highRisk.length} classes
- ⚡ **Medium Risk:** ${mediumRisk.length} classes
- ✅ **Low Risk:** ${lowRisk.length} classes

---

## Top 20 Classes Needing Improvement

| Rank | Class Name | Score | Risk | Key Issues |
|------|------------|-------|------|------------|
${sortedResults
  .slice(0, 20)
  .map(
    (r, i) =>
      `| ${i + 1} | ${r.className} | ${r.score} | ${r.riskLevel.toUpperCase()} | ${r.reasons.slice(0, 2).join("; ")} |`
  )
  .join("\n")}

---

## Critical Issues (60+ Score)

${critical.length === 0 ? "*No critical issues found - excellent!*" : ""}
${critical
  .slice(0, 10)
  .map(
    (r, i) => `
### ${i + 1}. ${r.className}
- **Score:** ${r.score} / 100
- **Risk Level:** ${r.riskLevel.toUpperCase()}
- **Last Modified:** ${new Date(r.lastModified).toLocaleDateString()}
- **Issues:**
${r.reasons.map((reason) => `  - ${reason}`).join("\n")}
- **Score Breakdown:**
  - Age: ${r.categories.age} pts
  - Type: ${r.categories.type} pts
  - Complexity: ${r.categories.complexity} pts
  - Documentation: ${r.categories.documentation} pts
  - Error Handling: ${r.categories.errorHandling} pts
  - Bulkification: ${r.categories.bulkification} pts
`
  )
  .join("\n---\n")}

---

## High Priority (40-59 Score)

${high.length === 0 ? "*No high priority issues*" : ""}
${high
  .slice(0, 15)
  .map(
    (r) => `
- **${r.className}** (Score: ${r.score}, Risk: ${r.riskLevel})
  - ${r.reasons.join("\n  - ")}
`
  )
  .join("\n")}

---

## 🔐 Security Vulnerabilities

${criticalSecurity.length === 0 && highSecurity.length === 0 ? "*No security vulnerabilities detected - excellent!*" : ""}

${
  criticalSecurity.length > 0
    ? `
### 🚨 CRITICAL Security Issues (Immediate Fix Required)

${criticalSecurity
  .slice(0, 10)
  .map(
    (r, i) => `
#### ${i + 1}. ${r.className}
${r.security.critical
  .map(
    (v) => `
- **${v.type}**
  - Severity: ${v.severity}
  - Description: ${v.description}
  - Recommendation: ${v.recommendation}
`
  )
  .join("\n")}
`
  )
  .join("\n")}
`
    : ""
}

${
  highSecurity.length > 0
    ? `
### ⚠️ HIGH Security Issues (Fix This Sprint)

${highSecurity
  .slice(0, 10)
  .map(
    (r) => `
- **${r.className}**
${r.security.high.map((v) => `  - ${v.type}: ${v.description}`).join("\n")}
`
  )
  .join("\n")}
`
    : ""
}

---

## 📊 Test Coverage Analysis

### Coverage Summary
- **Org-Wide Coverage:** ${this.orgCoverage}% ${this.orgCoverage >= 90 ? "(🎯 GOAL MET!)" : this.orgCoverage >= 75 ? "(Production deployable)" : "(🔴 Below deployment threshold)"}
- **Goal:** 90%
- **Gap to Goal:** ${Math.max(0, 90 - this.orgCoverage)}%

### Path to 90% Coverage

**1. Zero Coverage Classes (${zeroCoverage.length} classes)**
${
  zeroCoverage.length > 0
    ? `
Priority: 🔴 CRITICAL - Generate tests immediately

Top 10 classes needing tests:
${zeroCoverage
  .slice(0, 10)
  .map((r, i) => `${i + 1}. ${r.className} (${r.lineCount} lines, 0% coverage)`)
  .join("\n")}

**Estimated Effort:** ${(zeroCoverage.length * 2).toFixed(0)} hours (${((zeroCoverage.length * 2) / 8).toFixed(1)} days @ 2 hrs/class)
`
    : "*All classes have some test coverage!*"
}

**2. Sub-75% Coverage Classes (${lowCoverage.length} classes)**
${
  lowCoverage.length > 0
    ? `
Priority: 🟠 HIGH - Blocking production deployment

Classes closest to 75% (quick wins):
${lowCoverage
  .sort((a, b) => b.coverage - a.coverage)
  .slice(0, 10)
  .map(
    (r, i) =>
      `${i + 1}. ${r.className} (${r.coverage}% - need ${75 - r.coverage}% more)`
  )
  .join("\n")}

**Estimated Effort:** ${(lowCoverage.length * 1.5).toFixed(0)} hours (${((lowCoverage.length * 1.5) / 8).toFixed(1)} days @ 1.5 hrs/class)
`
    : "*All classes meet 75% threshold!*"
}

**3. Total Path to 90%**
- Generate tests for ${zeroCoverage.length} zero-coverage classes
- Improve ${lowCoverage.length} sub-75% classes
- **Total Estimated Effort:** ${(zeroCoverage.length * 2 + lowCoverage.length * 1.5).toFixed(0)} hours (${((zeroCoverage.length * 2 + lowCoverage.length * 1.5) / 8).toFixed(1)} days)
- **At 20 hrs/week:** ${((zeroCoverage.length * 2 + lowCoverage.length * 1.5) / 20).toFixed(1)} weeks

---

## 🧮 Code Complexity & Technical Debt

### Complexity Overview
- **High Complexity Classes (>50):** ${highComplexityClasses.length} classes
- **Total Technical Debt:** ${totalTechDebt.toFixed(1)} hours (${(totalTechDebt / 8).toFixed(1)} days)
- **Average Debt per Class:** ${(totalTechDebt / sortedResults.length).toFixed(2)} hours

### Highest Complexity Classes (Refactor Candidates)

${highComplexityClasses
  .slice(0, 10)
  .map(
    (r, i) => `
${i + 1}. **${r.className}**
   - Cyclomatic Complexity: ${r.complexity.cyclomaticComplexity}
   - Maintainability Index: ${r.complexity.maintainabilityIndex}/100 ${r.complexity.maintainabilityIndex < 50 ? "🔴" : r.complexity.maintainabilityIndex < 75 ? "🟡" : "✅"}
   - Technical Debt: ${r.technicalDebtHours} hours
   - Lines of Code: ${r.lineCount}
`
  )
  .join("\n")}

### Technical Debt Breakdown
- **High Priority (Complexity >50):** ${highComplexityClasses.reduce((sum, r) => sum + (r.technicalDebtHours || 0), 0).toFixed(1)} hours
- **Medium Priority (30-50):** ${sortedResults
      .filter(
        (r) =>
          r.complexity.cyclomaticComplexity >= 30 &&
          r.complexity.cyclomaticComplexity < 50
      )
      .reduce((sum, r) => sum + (r.technicalDebtHours || 0), 0)
      .toFixed(1)} hours
- **Low Priority (<30):** ${sortedResults
      .filter((r) => r.complexity.cyclomaticComplexity < 30)
      .reduce((sum, r) => sum + (r.technicalDebtHours || 0), 0)
      .toFixed(1)} hours

---

## 📱 API Version Health

${
  deprecatedApi.length > 0 || outdatedApi.length > 0
    ? `
### Summary
- **Deprecated (API <50):** ${deprecatedApi.length} classes 🔴 CRITICAL
- **Outdated (API <60):** ${outdatedApi.length} classes 🟠 Recommended upgrade
- **Current (API >=60):** ${sortedResults.length - outdatedApi.length} classes ✅

${
  deprecatedApi.length > 0
    ? `
### 🔴 CRITICAL: Deprecated API Versions
These classes use deprecated API versions and may have security/compatibility issues:

${deprecatedApi
  .slice(0, 10)
  .map((r) => `- ${r.className} (API v${r.apiVersion.current})`)
  .join("\n")}

**Action Required:** Upgrade to API v${deprecatedApi[0]?.apiVersion.latest || "64.0"} immediately
`
    : ""
}

${
  outdatedApi.length > 0 && deprecatedApi.length === 0
    ? `
### Outdated API Versions
${outdatedApi
  .slice(0, 15)
  .map(
    (r) =>
      `- ${r.className} (API v${r.apiVersion.current} - ${r.apiVersion.versionsBehind} versions behind)`
  )
  .join("\n")}

**Recommendation:** Consider upgrading to API v${outdatedApi[0]?.apiVersion.latest || "64.0"} for new features
`
    : ""
}
`
    : "*All classes use current API versions!*"
}

---

## Recommendations

### Immediate Actions (Next Sprint)
${this.generateRecommendations(critical, "critical")}

### Short-Term Actions (Next Month)
${this.generateRecommendations(high, "high")}

### Long-Term Strategy
${this.generateRecommendations(medium, "medium")}

---

## Category Analysis

### Documentation Needs
${this.getCategoryLeaders("documentation", sortedResults)
  .map(
    (r) =>
      `- **${r.className}** (${r.categories.documentation} pts) - ${r.reasons.find((s) => s.includes("documentation") || s.includes("coverage"))}`
  )
  .join("\n")}

### Bulkification Issues
${this.getCategoryLeaders("bulkification", sortedResults)
  .map(
    (r) =>
      `- **${r.className}** (${r.categories.bulkification} pts) - ${r.reasons.find((s) => s.includes("loop") || s.includes("SOQL") || s.includes("DML"))}`
  )
  .join("\n")}

### Error Handling Gaps
${this.getCategoryLeaders("errorHandling", sortedResults)
  .map(
    (r) =>
      `- **${r.className}** (${r.categories.errorHandling} pts) - ${r.reasons.find((s) => s.includes("error") || s.includes("try"))}`
  )
  .join("\n")}

### Complexity Concerns
${this.getCategoryLeaders("complexity", sortedResults)
  .map(
    (r) =>
      `- **${r.className}** (${r.categories.complexity} pts) - ${r.reasons.find((s) => s.includes("lines") || s.includes("methods"))}`
  )
  .join("\n")}

---

## Statistics

- **Average Score:** ${stats.averageScore.toFixed(1)}
- **Median Score:** ${stats.medianScore}
- **Highest Score:** ${stats.maxScore} (${stats.maxScoreClass})
- **Lowest Score:** ${stats.minScore} (${stats.minScoreClass})

### Score Distribution
${this.generateHistogram(sortedResults)}

---

## Next Steps

1. **Review Critical Classes** - Start with the top 10 classes listed above
2. **Run Improvements** - Use \`npm run demo:apex-improvement\` to improve individual classes
3. **Documentation Pass** - Add JavaDoc to classes with high documentation scores
4. **Bulkification Review** - Fix SOQL/DML in loops immediately
5. **Deploy to Sandbox** - Test improvements in Devin1 before production

## Commands

**Analyze specific class:**
\`\`\`bash
npm run demo:apex-improvement
\`\`\`

**Re-run batch analysis with content (slower, more accurate):**
\`\`\`bash
node demos/batch-analyzer.js --analyze-content
\`\`\`

---

*Generated by Autonomous Salesforce Development System*
`;

    // Save report
    await fs.writeFile("./analysis/org-analysis-report.md", report);

    // Save detailed JSON data
    await fs.writeJson(
      "./analysis/org-analysis-data.json",
      {
        generatedAt: new Date().toISOString(),
        statistics: stats,
        results: sortedResults,
        priorityGroups: {
          critical,
          high,
          medium,
          low
        },
        riskGroups: {
          highRisk,
          mediumRisk,
          lowRisk
        }
      },
      { spaces: 2 }
    );

    logger.info("Comprehensive org report generated");
  }

  calculateStatistics(results) {
    const scores = results.map((r) => r.score);
    return {
      averageScore: scores.reduce((sum, s) => sum + s, 0) / scores.length,
      medianScore: scores[Math.floor(scores.length / 2)],
      maxScore: Math.max(...scores),
      minScore: Math.min(...scores),
      maxScoreClass: results.find((r) => r.score === Math.max(...scores))
        ?.className,
      minScoreClass: results.find((r) => r.score === Math.min(...scores))
        ?.className
    };
  }

  calculateHealthGrade(avgScore) {
    if (avgScore >= 50) return "🔴 Needs Attention";
    if (avgScore >= 30) return "🟠 Fair";
    if (avgScore >= 15) return "🟡 Good";
    return "🟢 Excellent";
  }

  generateRecommendations(classes, priority) {
    if (classes.length === 0) {
      return `- No ${priority} priority items`;
    }

    const recommendations = [];

    // Check for bulkification issues
    const bulkIssues = classes.filter((c) => c.categories.bulkification > 0);
    if (bulkIssues.length > 0) {
      recommendations.push(
        `- Fix bulkification issues in ${bulkIssues.length} classes (CRITICAL)`
      );
    }

    // Check for documentation needs
    const docIssues = classes.filter((c) => c.categories.documentation >= 10);
    if (docIssues.length > 0) {
      recommendations.push(
        `- Add comprehensive documentation to ${docIssues.length} classes`
      );
    }

    // Check for error handling
    const errorIssues = classes.filter((c) => c.categories.errorHandling >= 10);
    if (errorIssues.length > 0) {
      recommendations.push(
        `- Implement error handling in ${errorIssues.length} classes`
      );
    }

    // Age-based
    const oldClasses = classes.filter((c) => c.categories.age >= 15);
    if (oldClasses.length > 0) {
      recommendations.push(
        `- Review and modernize ${oldClasses.length} outdated classes`
      );
    }

    return recommendations.length > 0
      ? recommendations.join("\n")
      : "- Continue monitoring";
  }

  getCategoryLeaders(category, results) {
    return results
      .filter((r) => r.categories[category] > 0)
      .sort((a, b) => b.categories[category] - a.categories[category])
      .slice(0, 10);
  }

  generateHistogram(results) {
    const bins = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
    const counts = bins.map((_, i) => {
      if (i === bins.length - 1) return 0;
      const min = bins[i];
      const max = bins[i + 1];
      return results.filter((r) => r.score >= min && r.score < max).length;
    });

    return bins
      .slice(0, -1)
      .map((bin, i) => {
        const count = counts[i];
        const percentage = ((count / results.length) * 100).toFixed(1);
        const bar = "█".repeat(Math.round((count / results.length) * 50));
        return `  ${bin}-${bins[i + 1]}: ${bar} ${count} (${percentage}%)`;
      })
      .join("\n");
  }
}

// Parse command line arguments
const args = process.argv.slice(2);
const options = {
  maxClasses: args.includes("--limit")
    ? parseInt(args[args.indexOf("--limit") + 1])
    : null,
  analyzeContent: args.includes("--analyze-content"),
  skipManaged: !args.includes("--include-managed"),
  skipTests: !args.includes("--include-tests"),
  resumeFromProgress: !args.includes("--fresh")
};

// Run the analyzer
const analyzer = new BatchCodebaseAnalyzer();
analyzer.run(options);
