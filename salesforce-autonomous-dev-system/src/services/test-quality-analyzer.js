// src/services/test-quality-analyzer.js - Test Quality Analysis Service

/**
 * Analyzes Apex test class quality and identifies improvement opportunities
 */
export class TestQualityAnalyzer {
  constructor(logger) {
    this.logger = logger;
  }

  /**
   * Analyzes test class quality across multiple dimensions
   * @param {string} testClassContent - The test class source code
   * @param {string} testClassName - Name of the test class
   * @returns {Object} Quality analysis with score, issues, and recommendations
   */
  analyzeTestQuality(testClassContent, testClassName) {
    const issues = {
      critical: [],
      high: [],
      medium: [],
      low: []
    };

    // Analyze different quality aspects
    const bulkTesting = this.analyzeBulkTesting(testClassContent);
    const assertions = this.analyzeAssertions(testClassContent);
    const testDataPractices = this.analyzeTestDataPractices(testClassContent);
    const errorHandling = this.analyzeErrorHandling(testClassContent);
    const mockingUsage = this.analyzeMockingUsage(testClassContent);
    const testCoverage = this.analyzeTestMethodCoverage(testClassContent);
    const documentation = this.analyzeDocumentation(testClassContent);

    // Collect issues from each analysis
    this.collectIssues(issues, bulkTesting.issues);
    this.collectIssues(issues, assertions.issues);
    this.collectIssues(issues, testDataPractices.issues);
    this.collectIssues(issues, errorHandling.issues);
    this.collectIssues(issues, mockingUsage.issues);
    this.collectIssues(issues, testCoverage.issues);
    this.collectIssues(issues, documentation.issues);

    // Calculate overall quality score (0-100)
    const score = this.calculateQualityScore({
      bulkTesting,
      assertions,
      testDataPractices,
      errorHandling,
      mockingUsage,
      testCoverage,
      documentation
    });

    return {
      className: testClassName,
      score,
      issues,
      metrics: {
        bulkTesting: bulkTesting.score,
        assertions: assertions.score,
        testDataPractices: testDataPractices.score,
        errorHandling: errorHandling.score,
        mockingUsage: mockingUsage.score,
        testCoverage: testCoverage.score,
        documentation: documentation.score
      },
      recommendations: this.generateRecommendations(issues, score)
    };
  }

  /**
   * Analyzes whether tests properly test bulk operations (200+ records)
   */
  analyzeBulkTesting(content) {
    const issues = [];
    let score = 0;

    // Check for bulk testing patterns
    const hasBulkTest =
      content.includes("200") ||
      content.includes("201") ||
      content.match(/for\s*\(\s*Integer\s+i\s*=\s*0\s*;\s*i\s*<\s*\d{3}/);

    if (!hasBulkTest) {
      issues.push({
        severity: "critical",
        type: "Missing Bulk Testing",
        description:
          "No bulk testing detected. Tests should verify governor limit handling with 200+ records.",
        recommendation:
          "Add test methods that create and process 200+ records to verify bulkification."
      });
      score = 0;
    } else {
      score = 20;
    }

    // Check for single-record tests only
    const testMethods =
      content.match(/@isTest\s+static\s+void\s+\w+\s*\(\)/g) || [];
    const bulkTestMethods =
      content.match(/\b(bulk|batch|200|governor)/gi) || [];

    if (testMethods.length > 0 && bulkTestMethods.length === 0) {
      issues.push({
        severity: "high",
        type: "Single Record Testing Only",
        description: "All test methods appear to test single records only.",
        recommendation:
          'Add test methods with "bulk" or "batch" naming to clearly indicate bulk testing.'
      });
    } else if (bulkTestMethods.length > 0) {
      score = 20;
    }

    return { score, issues };
  }

  /**
   * Analyzes assertion quality and usage
   */
  analyzeAssertions(content) {
    const issues = [];
    let score = 0;

    // Count different assertion types
    const systemAssertCount = (content.match(/System\.assert\(/g) || []).length;
    const systemAssertEqualsCount = (
      content.match(/System\.assertEquals\(/g) || []
    ).length;
    const systemAssertNotEqualsCount = (
      content.match(/System\.assertNotEquals\(/g) || []
    ).length;
    const assertCount = (content.match(/Assert\./g) || []).length; // New Assert class (API 56+)

    const totalAssertions =
      systemAssertCount +
      systemAssertEqualsCount +
      systemAssertNotEqualsCount +
      assertCount;

    // Check for meaningless assertions
    const meaninglessAssertions =
      content.match(/System\.assert\s*\(\s*true\s*\)/g) || [];
    if (meaninglessAssertions.length > 0) {
      issues.push({
        severity: "critical",
        type: "Meaningless Assertions",
        description: `Found ${meaninglessAssertions.length} System.assert(true) assertions that don't validate anything.`,
        recommendation:
          "Replace System.assert(true) with meaningful assertions that validate actual outcomes."
      });
      score = 0;
    }

    // Check for no assertions
    if (totalAssertions === 0) {
      issues.push({
        severity: "critical",
        type: "No Assertions",
        description:
          "Test class contains no assertions. Tests must validate outcomes.",
        recommendation:
          "Add System.assertEquals/assertNotEquals to verify expected behavior."
      });
      score = 0;
    } else {
      // Score based on assertion density (assertions per test method)
      const testMethods = (content.match(/@isTest/g) || []).length;
      const assertionsPerMethod =
        testMethods > 0 ? totalAssertions / testMethods : 0;

      if (assertionsPerMethod < 1) {
        issues.push({
          severity: "high",
          type: "Insufficient Assertions",
          description: `Only ${assertionsPerMethod.toFixed(1)} assertions per test method on average.`,
          recommendation:
            "Add more assertions to validate all aspects of functionality."
        });
        score = 10;
      } else if (assertionsPerMethod < 3) {
        score = 15;
      } else {
        score = 20;
      }
    }

    // Check for assertion messages
    const assertionsWithMessages =
      content.match(
        /System\.assert(?:Equals|NotEquals)?\s*\([^,)]+,[^,)]+,[^)]+\)/g
      ) || [];
    const assertionMessagePercentage =
      totalAssertions > 0
        ? (assertionsWithMessages.length / totalAssertions) * 100
        : 0;

    if (assertionMessagePercentage < 50 && totalAssertions > 0) {
      issues.push({
        severity: "medium",
        type: "Missing Assertion Messages",
        description: `Only ${assertionMessagePercentage.toFixed(0)}% of assertions have descriptive messages.`,
        recommendation:
          "Add descriptive messages to assertions for easier debugging when tests fail."
      });
    }

    return { score, issues };
  }

  /**
   * Analyzes test data setup practices
   */
  analyzeTestDataPractices(content) {
    const issues = [];
    let score = 0;

    // Check for hardcoded IDs
    const hardcodedIds = content.match(/['"]0[0-9A-Za-z]{14,17}['"]/g) || [];
    if (hardcodedIds.length > 0) {
      issues.push({
        severity: "critical",
        type: "Hardcoded Record IDs",
        description: `Found ${hardcodedIds.length} hardcoded Salesforce IDs. Tests will fail in other orgs.`,
        recommendation:
          "Remove hardcoded IDs. Create test records dynamically or query by unique field."
      });
      score = 0;
    } else {
      score += 10;
    }

    // Check for @testSetup usage
    const hasTestSetup =
      content.includes("@testSetup") || content.includes("@TestSetup");
    if (!hasTestSetup && content.includes("@isTest")) {
      issues.push({
        severity: "medium",
        type: "No @testSetup Method",
        description:
          "Consider using @testSetup for shared test data to improve performance.",
        recommendation:
          "Add @testSetup method to create common test data once for all test methods."
      });
    } else if (hasTestSetup) {
      score += 5;
    }

    // Check for Test.startTest/stopTest usage
    const hasStartStopTest =
      content.includes("Test.startTest") && content.includes("Test.stopTest");
    if (!hasStartStopTest) {
      issues.push({
        severity: "high",
        type: "Missing Test.startTest/stopTest",
        description:
          "Test.startTest() and Test.stopTest() are not used. Governor limits won't reset.",
        recommendation:
          "Wrap test execution in Test.startTest/stopTest to reset governor limits."
      });
    } else {
      score += 10;
    }

    // Check for SeeAllData=true (bad practice)
    const hasSeeAllData = content.match(
      /@isTest\s*\(\s*SeeAllData\s*=\s*true\s*\)/i
    );
    if (hasSeeAllData) {
      issues.push({
        severity: "critical",
        type: "SeeAllData=true Usage",
        description:
          "SeeAllData=true makes tests dependent on org data. Tests will be flaky.",
        recommendation:
          "Remove SeeAllData=true and create all necessary test data explicitly."
      });
      score = 0;
    } else {
      score += 5;
    }

    return { score: Math.min(score, 20), issues };
  }

  /**
   * Analyzes error handling and edge case testing
   */
  analyzeErrorHandling(content) {
    const issues = [];
    let score = 0;

    // Check for negative test cases (expected exceptions)
    const hasNegativeTests =
      content.match(/try\s*\{[\s\S]*?\}\s*catch\s*\(/g) || [];
    const hasExpectedExceptions = hasNegativeTests.length > 0;

    if (!hasExpectedExceptions) {
      issues.push({
        severity: "high",
        type: "No Negative Test Cases",
        description: "No error handling or exception testing detected.",
        recommendation:
          "Add test methods that verify exception handling for invalid inputs and error conditions."
      });
      score = 0;
    } else {
      score = 15;
    }

    // Check for null/empty input testing
    const hasNullTests = content.match(/\bnull\b/g) || [];
    const hasEmptyTests =
      content.match(/\.isEmpty\(\)|\.size\(\)\s*==\s*0|new List</g) || [];

    if (hasNullTests.length === 0 || hasEmptyTests.length === 0) {
      issues.push({
        severity: "medium",
        type: "Missing Edge Case Tests",
        description:
          "Tests don't appear to cover null values or empty collections.",
        recommendation:
          "Add tests for edge cases: null inputs, empty lists, boundary values."
      });
    } else {
      score += 5;
    }

    return { score, issues };
  }

  /**
   * Analyzes mocking and stubbing usage for external dependencies
   */
  analyzeMockingUsage(content) {
    const issues = [];
    let score = 10; // Default middle score

    // Check if class needs mocking (has callouts or dependencies)
    const needsMocking =
      content.includes("HttpCallout") ||
      content.includes("WebService") ||
      content.includes("@future") ||
      content.includes("Database.query");

    if (needsMocking) {
      // Check for mock implementations
      const hasMocking =
        content.includes("HttpCalloutMock") ||
        content.includes("StubProvider") ||
        content.includes("Test.setMock");

      if (!hasMocking) {
        issues.push({
          severity: "high",
          type: "Missing Mock Implementation",
          description:
            "Test involves external dependencies but doesn't use mocking.",
          recommendation:
            "Implement HttpCalloutMock or StubProvider to isolate test from external dependencies."
        });
        score = 0;
      } else {
        score = 15;
      }
    }

    return { score, issues };
  }

  /**
   * Analyzes test method coverage (positive, negative, edge cases)
   */
  analyzeTestMethodCoverage(content) {
    const issues = [];
    let score = 0;

    // Count test methods
    const testMethods =
      content.match(/@isTest\s+(?:static\s+)?void\s+\w+/g) || [];
    const testMethodCount = testMethods.length;

    if (testMethodCount === 0) {
      issues.push({
        severity: "critical",
        type: "No Test Methods",
        description: "Test class contains no @isTest methods.",
        recommendation: "Add test methods to verify functionality."
      });
      score = 0;
    } else if (testMethodCount === 1) {
      issues.push({
        severity: "high",
        type: "Single Test Method",
        description:
          "Only one test method. Insufficient coverage of scenarios.",
        recommendation:
          "Add separate test methods for positive, negative, and edge cases."
      });
      score = 5;
    } else if (testMethodCount < 3) {
      issues.push({
        severity: "medium",
        type: "Limited Test Methods",
        description: `Only ${testMethodCount} test methods. Consider more comprehensive scenarios.`,
        recommendation:
          "Add test methods for: bulk operations, error cases, edge conditions, security."
      });
      score = 10;
    } else {
      score = 15;
    }

    // Check for test method naming conventions
    const positiveTests = testMethods.filter((m) =>
      m.match(/success|should|valid|correct/i)
    );
    const negativeTests = testMethods.filter((m) =>
      m.match(/fail|error|invalid|exception/i)
    );
    const bulkTests = testMethods.filter((m) =>
      m.match(/bulk|batch|governor|200/i)
    );

    if (positiveTests.length === 0 && testMethodCount > 0) {
      issues.push({
        severity: "low",
        type: "Unclear Test Naming",
        description:
          "Test method names don't clearly indicate positive test cases.",
        recommendation:
          "Use descriptive names like testValidInputSuccess() for clarity."
      });
    }

    return { score, issues };
  }

  /**
   * Analyzes test documentation quality
   */
  analyzeDocumentation(content) {
    const issues = [];
    let score = 0;

    // Check for class-level documentation
    const hasClassDoc = content.match(/\/\*\*[\s\S]*?\*\/\s*@isTest/);
    if (!hasClassDoc) {
      issues.push({
        severity: "low",
        type: "Missing Class Documentation",
        description: "Test class lacks JavaDoc documentation.",
        recommendation:
          "Add class-level JavaDoc describing what functionality is being tested."
      });
    } else {
      score += 5;
    }

    // Check for method-level documentation
    const testMethods =
      content.match(/@isTest\s+(?:static\s+)?void\s+\w+/g) || [];
    const documentedMethods =
      content.match(/\/\*\*[\s\S]*?\*\/\s*@isTest/g) || [];

    const docPercentage =
      testMethods.length > 0
        ? (documentedMethods.length / testMethods.length) * 100
        : 0;

    if (docPercentage < 50) {
      issues.push({
        severity: "medium",
        type: "Insufficient Method Documentation",
        description: `Only ${docPercentage.toFixed(0)}% of test methods have documentation.`,
        recommendation:
          "Add JavaDoc to test methods describing: Given/When/Then or scenario being tested."
      });
    } else {
      score += 5;
    }

    return { score, issues };
  }

  /**
   * Collects issues from individual analyses into main issue object
   */
  collectIssues(targetIssues, sourceIssues) {
    for (const issue of sourceIssues) {
      targetIssues[issue.severity].push(issue);
    }
  }

  /**
   * Calculates overall quality score based on all metrics
   */
  calculateQualityScore(metrics) {
    const weights = {
      bulkTesting: 0.2, // 20% - Critical for governor limits
      assertions: 0.2, // 20% - Must validate outcomes
      testDataPractices: 0.2, // 20% - Data setup quality
      errorHandling: 0.15, // 15% - Edge case coverage
      mockingUsage: 0.1, // 10% - Isolation from dependencies
      testCoverage: 0.1, // 10% - Number of test scenarios
      documentation: 0.05 // 5% - Documentation quality
    };

    let totalScore = 0;
    for (const [key, weight] of Object.entries(weights)) {
      totalScore += metrics[key].score * weight;
    }

    return Math.round(totalScore);
  }

  /**
   * Generates prioritized recommendations based on issues
   */
  generateRecommendations(issues, score) {
    const recommendations = [];

    // Priority 1: Critical issues
    if (issues.critical.length > 0) {
      recommendations.push({
        priority: "CRITICAL",
        action: "Fix Critical Issues",
        details: issues.critical.map((i) => i.type),
        impact: "High - Tests may be invalid or unmaintainable"
      });
    }

    // Priority 2: High severity issues
    if (issues.high.length > 0) {
      recommendations.push({
        priority: "HIGH",
        action: "Address High Priority Issues",
        details: issues.high.map((i) => i.type),
        impact: "Medium - Tests incomplete or fragile"
      });
    }

    // Priority 3: Score-based recommendations
    if (score < 40) {
      recommendations.push({
        priority: "HIGH",
        action: "Complete Test Rewrite",
        details: ["Quality score too low for incremental improvement"],
        impact: "Test class needs comprehensive refactoring"
      });
    } else if (score < 70) {
      recommendations.push({
        priority: "MEDIUM",
        action: "Significant Test Improvements",
        details: ["Add missing test scenarios", "Improve assertion quality"],
        impact: "Moderate improvements needed for production quality"
      });
    }

    return recommendations;
  }

  /**
   * Determines if a test class needs complete rewrite vs incremental improvement
   */
  shouldRewrite(analysisResult) {
    return (
      analysisResult.score < 40 ||
      analysisResult.issues.critical.length >= 3 ||
      analysisResult.issues.high.length >= 5
    );
  }
}
