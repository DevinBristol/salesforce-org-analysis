// src/services/org-analyzer.js - Salesforce Org Analysis

import fs from "fs-extra";

export class OrgAnalyzer {
  constructor(logger) {
    this.logger = logger;
    this.orgMetadata = null;
    this.schemaCache = {};
  }

  async analyzeOrg() {
    try {
      this.logger.info("Starting org analysis...");

      // Load existing metadata if available
      const metadataPath = "./metadata/org-metadata.json";
      if (await fs.pathExists(metadataPath)) {
        this.orgMetadata = await fs.readJson(metadataPath);
      }

      const analysis = {
        timestamp: new Date().toISOString(),
        summary: {
          customObjects: 0,
          apexClasses: 0,
          apexTriggers: 0,
          flows: 0,
          totalCustomFields: 0
        },
        complexity: "medium",
        recommendations: [],
        issues: []
      };

      if (this.orgMetadata) {
        // Count components
        if (this.orgMetadata.CustomObject) {
          analysis.summary.customObjects = this.orgMetadata.CustomObject.length;
        }
        if (this.orgMetadata.ApexClass) {
          analysis.summary.apexClasses = this.orgMetadata.ApexClass.length;
        }
        if (this.orgMetadata.ApexTrigger) {
          analysis.summary.apexTriggers = this.orgMetadata.ApexTrigger.length;
        }
        if (this.orgMetadata.Flow) {
          analysis.summary.flows = this.orgMetadata.Flow.length;
        }

        // Analyze complexity
        analysis.complexity = this.calculateComplexity(analysis.summary);

        // Generate recommendations
        analysis.recommendations = this.generateRecommendations(
          analysis.summary
        );

        // Identify potential issues
        analysis.issues = this.identifyIssues();
      }

      // Save analysis
      await fs.ensureDir("./analysis");
      await fs.writeJson("./analysis/org-analysis.json", analysis, {
        spaces: 2
      });

      this.logger.info("Org analysis completed");
      return analysis;
    } catch (error) {
      this.logger.error("Org analysis failed:", error);
      throw error;
    }
  }

  calculateComplexity(summary) {
    const score =
      summary.customObjects * 2 +
      summary.apexClasses * 3 +
      summary.apexTriggers * 4 +
      summary.flows * 2;

    if (score < 50) return "low";
    if (score < 200) return "medium";
    return "high";
  }

  generateRecommendations(summary) {
    const recommendations = [];

    if (summary.apexClasses > 100) {
      recommendations.push({
        type: "optimization",
        priority: "high",
        message: "Consider consolidating Apex classes to reduce complexity"
      });
    }

    if (summary.apexTriggers > summary.customObjects * 2) {
      recommendations.push({
        type: "architecture",
        priority: "medium",
        message:
          "Multiple triggers per object detected - consider trigger framework"
      });
    }

    if (summary.flows > 50) {
      recommendations.push({
        type: "governance",
        priority: "medium",
        message:
          "High number of flows - implement naming conventions and documentation"
      });
    }

    return recommendations;
  }

  identifyIssues() {
    const issues = [];

    if (this.orgMetadata && this.orgMetadata.ApexClass) {
      // Check for classes without test coverage
      const classesWithoutTest = this.orgMetadata.ApexClass.filter(
        (cls) =>
          !cls.fullName.includes("Test") && !this.hasTestClass(cls.fullName)
      );

      if (classesWithoutTest.length > 0) {
        issues.push({
          severity: "warning",
          type: "test-coverage",
          message: `${classesWithoutTest.length} Apex classes may lack test coverage`,
          affectedComponents: classesWithoutTest
            .slice(0, 5)
            .map((c) => c.fullName)
        });
      }
    }

    return issues;
  }

  hasTestClass(className) {
    if (!this.orgMetadata || !this.orgMetadata.ApexClass) return false;

    const testClassName = className + "Test";
    return this.orgMetadata.ApexClass.some(
      (cls) =>
        cls.fullName === testClassName || cls.fullName === "Test" + className
    );
  }

  async getContext(objectNames = []) {
    try {
      const context = {
        objects: {},
        customFields: [],
        relationships: []
      };

      // Load cached schema or metadata
      for (const objName of objectNames) {
        if (this.schemaCache[objName]) {
          context.objects[objName] = this.schemaCache[objName];
        }
      }

      // Get custom field information from metadata
      if (this.orgMetadata && this.orgMetadata.CustomObject) {
        context.customFields = this.orgMetadata.CustomObject.filter((obj) =>
          objectNames.includes(obj.fullName.replace("__c", ""))
        ).map((obj) => ({
          object: obj.fullName,
          label: obj.label
        }));
      }

      return context;
    } catch (error) {
      this.logger.error("Failed to get org context:", error);
      return { objects: {}, customFields: [], relationships: [] };
    }
  }

  async findImprovementTargets() {
    try {
      const targets = [];

      if (!this.orgMetadata || !this.orgMetadata.ApexClass) {
        return targets;
      }

      // Score each Apex class for improvement potential
      for (const apexClass of this.orgMetadata.ApexClass) {
        if (apexClass.fullName.includes("Test")) continue;

        const score = this.calculateImprovementScore(apexClass);
        if (score.total > 0) {
          targets.push({
            className: apexClass.fullName,
            score: score.total,
            riskLevel: score.risk,
            reasons: score.reasons,
            lastModified: apexClass.lastModifiedDate
          });
        }
      }

      // Sort by score (higher is better for improvement)
      targets.sort((a, b) => b.score - a.score);

      return targets;
    } catch (error) {
      this.logger.error("Failed to find improvement targets:", error);
      return [];
    }
  }

  calculateImprovementScore(apexClass, classContent = null) {
    const score = {
      total: 0,
      risk: "low",
      reasons: [],
      categories: {
        age: 0,
        type: 0,
        complexity: 0,
        documentation: 0,
        errorHandling: 0,
        bulkification: 0
      }
    };

    const name = apexClass.fullName.toLowerCase();

    // AGE SCORE (0-20 points)
    const lastModified = new Date(apexClass.lastModifiedDate);
    const monthsOld = (Date.now() - lastModified) / (1000 * 60 * 60 * 24 * 30);
    if (monthsOld > 24) {
      score.categories.age = 20;
      score.reasons.push(
        `Not modified for ${Math.round(monthsOld)} months - high priority for review`
      );
    } else if (monthsOld > 12) {
      score.categories.age = 15;
      score.reasons.push(`Last modified ${Math.round(monthsOld)} months ago`);
    } else if (monthsOld > 6) {
      score.categories.age = 10;
      score.reasons.push(`Last modified ${Math.round(monthsOld)} months ago`);
    } else if (monthsOld > 3) {
      score.categories.age = 5;
    }

    // TYPE SCORE (0-25 points)
    if (name.includes("util") || name.includes("helper")) {
      score.categories.type = 15;
      score.reasons.push("Utility/Helper class - safe to optimize");
      score.risk = "low";
    }

    if (name.includes("handler")) {
      score.categories.type = 20;
      score.risk = "medium";
      score.reasons.push("Handler class - likely needs bulkification review");
    }

    if (name.includes("trigger")) {
      score.categories.type = 25;
      score.risk = "medium";
      score.reasons.push("Trigger handler - critical for bulkification");
    }

    if (name.includes("controller")) {
      score.categories.type = 10;
      score.risk = "medium";
      score.reasons.push("Controller class - may benefit from optimization");
    }

    if (name.includes("batch") || name.includes("schedulable")) {
      score.categories.type = 18;
      score.risk = "high";
      score.reasons.push("Batch/Scheduled class - performance critical");
    }

    if (name.includes("service")) {
      score.categories.type = 16;
      score.risk = "low";
      score.reasons.push("Service class - good candidate for improvement");
    }

    // CONTENT-BASED SCORING (if we have the class content)
    if (classContent) {
      const contentAnalysis = this.analyzeClassContent(classContent);
      score.categories.complexity = contentAnalysis.complexityScore;
      score.categories.documentation = contentAnalysis.documentationScore;
      score.categories.errorHandling = contentAnalysis.errorHandlingScore;
      score.categories.bulkification = contentAnalysis.bulkificationScore;

      score.reasons.push(...contentAnalysis.reasons);

      // Upgrade risk if content analysis shows issues
      if (contentAnalysis.riskLevel === "high" && score.risk !== "high") {
        score.risk = "high";
      } else if (
        contentAnalysis.riskLevel === "medium" &&
        score.risk === "low"
      ) {
        score.risk = "medium";
      }
    }

    // Calculate total
    score.total = Object.values(score.categories).reduce(
      (sum, val) => sum + val,
      0
    );

    return score;
  }

  async getTestCoverage(salesforceManager) {
    try {
      this.logger.info("Fetching test coverage data...");

      // Use Tooling API to query ApexCodeCoverageAggregate
      const coverageQuery = `
                SELECT ApexClassOrTrigger.Name,
                       NumLinesCovered,
                       NumLinesUncovered,
                       Coverage
                FROM ApexCodeCoverageAggregate
                WHERE ApexClassOrTriggerId != null
            `;

      const coverageResults =
        await salesforceManager.connection.tooling.query(coverageQuery);

      // Build coverage map
      const coverageMap = {};
      if (coverageResults.records) {
        for (const record of coverageResults.records) {
          const className = record.ApexClassOrTrigger.Name;
          const covered = record.NumLinesCovered || 0;
          const uncovered = record.NumLinesUncovered || 0;
          const total = covered + uncovered;
          const percentage =
            total > 0 ? Math.round((covered / total) * 100) : 0;

          coverageMap[className] = {
            coverage: percentage,
            linesCovered: covered,
            linesUncovered: uncovered,
            totalLines: total
          };
        }
      }

      this.logger.info(
        `Test coverage data fetched for ${Object.keys(coverageMap).length} classes`
      );
      return coverageMap;
    } catch (error) {
      this.logger.warn("Could not fetch test coverage:", error.message);
      this.logger.warn(
        "Test coverage requires tests to be run at least once in the org"
      );
      return {};
    }
  }

  calculateOrgCoverage(coverageMap) {
    const classes = Object.values(coverageMap);
    if (classes.length === 0) return 0;

    const totalLines = classes.reduce((sum, c) => sum + c.totalLines, 0);
    const coveredLines = classes.reduce((sum, c) => sum + c.linesCovered, 0);

    return totalLines > 0 ? Math.round((coveredLines / totalLines) * 100) : 0;
  }

  analyzeClassContent(classContent) {
    const analysis = {
      complexityScore: 0,
      documentationScore: 0,
      errorHandlingScore: 0,
      bulkificationScore: 0,
      riskLevel: "low",
      reasons: []
    };

    const lines = classContent.split("\n");
    const lineCount = lines.length;

    // COMPLEXITY (0-15 points)
    if (lineCount > 500) {
      analysis.complexityScore = 15;
      analysis.reasons.push(
        `Large class (${lineCount} lines) - high complexity`
      );
      analysis.riskLevel = "high";
    } else if (lineCount > 300) {
      analysis.complexityScore = 10;
      analysis.reasons.push(`Medium-large class (${lineCount} lines)`);
    } else if (lineCount > 150) {
      analysis.complexityScore = 5;
    }

    // Count methods (approximate)
    const methodCount = (
      classContent.match(
        /\b(public|private|global)\s+(static\s+)?\w+\s+\w+\s*\(/g
      ) || []
    ).length;
    if (methodCount > 20) {
      analysis.complexityScore += 5;
      analysis.reasons.push(
        `Many methods (${methodCount}) - needs organization`
      );
    }

    // DOCUMENTATION (0-20 points) - Higher score = needs more docs
    const hasClassDoc =
      classContent.includes("/**") &&
      classContent.indexOf("/**") < classContent.indexOf("class ");
    const javaDocCount = (classContent.match(/\/\*\*/g) || []).length;
    const docRatio = methodCount > 0 ? javaDocCount / methodCount : 0;

    if (!hasClassDoc) {
      analysis.documentationScore += 10;
      analysis.reasons.push("Missing class-level documentation");
    }

    if (docRatio < 0.3) {
      analysis.documentationScore += 10;
      analysis.reasons.push(
        `Low documentation coverage (${Math.round(docRatio * 100)}%)`
      );
    } else if (docRatio < 0.6) {
      analysis.documentationScore += 5;
      analysis.reasons.push("Partial documentation - needs completion");
    }

    // ERROR HANDLING (0-15 points) - Higher score = needs error handling
    const tryCatchCount = (classContent.match(/\btry\s*\{/g) || []).length;
    const errorRatio = methodCount > 0 ? tryCatchCount / methodCount : 0;

    if (errorRatio < 0.2) {
      analysis.errorHandlingScore = 15;
      analysis.reasons.push("Minimal error handling - needs try-catch blocks");
    } else if (errorRatio < 0.5) {
      analysis.errorHandlingScore = 8;
      analysis.reasons.push("Limited error handling");
    }

    // BULKIFICATION (0-10 points) - Check for anti-patterns
    const hasLoopSOQL = /for\s*\([^)]*\)\s*{[^}]*\[SELECT/i.test(classContent);
    const hasLoopDML =
      /for\s*\([^)]*\)\s*{[^}]*(insert|update|delete|upsert)\s+/i.test(
        classContent
      );

    if (hasLoopSOQL) {
      analysis.bulkificationScore += 7;
      analysis.reasons.push("SOQL in loop detected - needs bulkification");
      analysis.riskLevel = "high";
    }

    if (hasLoopDML) {
      analysis.bulkificationScore += 8;
      analysis.reasons.push(
        "DML in loop detected - CRITICAL bulkification needed"
      );
      analysis.riskLevel = "high";
    }

    return analysis;
  }

  calculateComplexityMetrics(classContent) {
    const metrics = {
      cyclomaticComplexity: 0,
      cognitiveComplexity: 0,
      maintainabilityIndex: 100,
      technicalDebtMinutes: 0
    };

    if (!classContent) return metrics;

    // Cyclomatic Complexity = decision points + 1
    const decisionKeywords = /\b(if|else|for|while|case|catch|&&|\|\||\?)\b/g;
    const decisions = (classContent.match(decisionKeywords) || []).length;
    metrics.cyclomaticComplexity = decisions + 1;

    // Cognitive Complexity (approximation) - nested structures increase weight
    let cognitiveScore = 0;
    const lines = classContent.split("\n");
    let nestingLevel = 0;

    for (const line of lines) {
      const openBraces = (line.match(/{/g) || []).length;
      const closeBraces = (line.match(/}/g) || []).length;

      if (line.match(/\b(if|for|while)\b/)) {
        cognitiveScore += 1 + nestingLevel;
      }

      nestingLevel += openBraces - closeBraces;
      if (nestingLevel < 0) nestingLevel = 0;
    }
    metrics.cognitiveComplexity = cognitiveScore;

    // Maintainability Index (simplified formula)
    // MI = 171 - 5.2 * ln(HV) - 0.23 * CC - 16.2 * ln(LOC)
    const loc = lines.length;
    const cc = metrics.cyclomaticComplexity;

    if (loc > 0) {
      const halsteadVolume = loc * 10; // Approximation
      const mi =
        171 - 5.2 * Math.log(halsteadVolume) - 0.23 * cc - 16.2 * Math.log(loc);
      metrics.maintainabilityIndex = Math.max(0, Math.min(100, Math.round(mi)));
    }

    // Technical Debt = f(complexity, size)
    // Higher complexity + larger size = more debt
    const complexityFactor =
      metrics.cyclomaticComplexity > 50
        ? 3
        : metrics.cyclomaticComplexity > 30
          ? 2
          : 1;
    const sizeFactor = loc > 500 ? 3 : loc > 300 ? 2 : 1;

    metrics.technicalDebtMinutes = Math.round(
      (loc / 100) * complexityFactor * sizeFactor * 30
    );

    return metrics;
  }

  scanSecurityVulnerabilities(classContent, className) {
    const vulnerabilities = {
      critical: [],
      high: [],
      medium: [],
      low: []
    };

    if (!classContent) return vulnerabilities;

    const content = classContent.toLowerCase();

    // CRITICAL: SOQL Injection Risk
    const dynamicSoqlPatterns = [
      /string\.escapesinglequotes\s*\(/i,
      /\+\s*['"]/ // String concatenation in queries
    ];

    if (content.includes("database.query(") || content.includes("[select")) {
      if (
        !content.includes("escapesinglequotes") &&
        content.match(/\+.*['"`]/)
      ) {
        vulnerabilities.critical.push({
          type: "SOQL Injection Risk",
          description: "Dynamic SOQL without proper escaping detected",
          severity: "CRITICAL",
          recommendation:
            "Use String.escapeSingleQuotes() or static SOQL with bind variables"
        });
      }
    }

    // CRITICAL: Hardcoded Credentials
    const credentialPatterns = [
      /password\s*=\s*['"]/i,
      /api[_-]?key\s*=\s*['"]/i,
      /secret\s*=\s*['"]/i,
      /token\s*=\s*['"]/i
    ];

    for (const pattern of credentialPatterns) {
      if (content.match(pattern)) {
        vulnerabilities.critical.push({
          type: "Hardcoded Credentials",
          description: "Potential hardcoded credentials found",
          severity: "CRITICAL",
          recommendation:
            "Use Custom Metadata, Custom Settings, or Named Credentials"
        });
        break;
      }
    }

    // HIGH: Sensitive Data in Debug Logs
    if (
      content.includes("system.debug") &&
      (content.includes("password") ||
        content.includes("ssn") ||
        content.includes("credit") ||
        content.includes("token"))
    ) {
      vulnerabilities.high.push({
        type: "Sensitive Data Exposure",
        description: "Potentially logging sensitive data in debug statements",
        severity: "HIGH",
        recommendation: "Remove sensitive data from debug logs or mask it"
      });
    }

    // HIGH: Missing @isTest annotation security
    if (
      className.toLowerCase().includes("test") &&
      !content.includes("@istest")
    ) {
      vulnerabilities.high.push({
        type: "Test Class Without @IsTest",
        description: "Test class missing @IsTest annotation",
        severity: "HIGH",
        recommendation:
          "Add @IsTest annotation to prevent accidental deployment"
      });
    }

    // MEDIUM: Insecure random number generation
    if (content.includes("math.random()")) {
      vulnerabilities.medium.push({
        type: "Weak Random Generation",
        description: "Using Math.random() for random numbers",
        severity: "MEDIUM",
        recommendation:
          "Use Crypto.getRandomInteger() for security-sensitive operations"
      });
    }

    // MEDIUM: Without Sharing keyword missing on controllers
    if (
      (className.toLowerCase().includes("controller") ||
        className.toLowerCase().includes("service")) &&
      !content.includes("with sharing") &&
      !content.includes("without sharing") &&
      !content.includes("inherited sharing")
    ) {
      vulnerabilities.medium.push({
        type: "Missing Sharing Declaration",
        description:
          "Class lacks sharing keyword - defaults to without sharing",
        severity: "MEDIUM",
        recommendation:
          'Explicitly declare "with sharing" or "inherited sharing"'
      });
    }

    return vulnerabilities;
  }

  analyzeApiVersion(classMetadata) {
    const apiVersion = parseFloat(classMetadata.apiVersion || "0.0");
    const latestVersion = 64.0; // Update this as new versions release
    const recommendedMinVersion = 60.0;

    const analysis = {
      current: apiVersion,
      latest: latestVersion,
      isOutdated: apiVersion < recommendedMinVersion,
      isDeprecated: apiVersion < 50.0,
      versionsBehind: latestVersion - apiVersion,
      recommendation: ""
    };

    if (analysis.isDeprecated) {
      analysis.recommendation = `CRITICAL: API v${apiVersion} is deprecated. Upgrade to v${latestVersion} immediately.`;
    } else if (analysis.isOutdated) {
      analysis.recommendation = `Outdated: Consider upgrading from v${apiVersion} to v${latestVersion} for new features.`;
    } else {
      analysis.recommendation = `Current: API version is up to date.`;
    }

    return analysis;
  }
}
