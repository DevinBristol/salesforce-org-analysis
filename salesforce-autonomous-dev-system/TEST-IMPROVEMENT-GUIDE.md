# Test Improvement System Guide

Comprehensive test generation, refactoring, and documentation system for Salesforce Apex test classes.

## Overview

The Test Improvement System provides AI-powered capabilities to:

1. **Analyze** existing test class quality
2. **Refactor** tests with best practices (bulkification, meaningful assertions, mocking)
3. **Generate** new test classes for classes with low/no coverage
4. **Document** all test methods with comprehensive JavaDoc
5. **Deploy** improved tests automatically to sandbox

## Features

### 1. Test Quality Analysis

- **Bulkification Testing**: Detects tests with 200+ records for governor limits
- **Assertion Quality**: Identifies meaningless System.assert(true), missing assertions
- **Test Data Practices**: Checks for hardcoded IDs, SeeAllData=true, @testSetup usage
- **Error Handling**: Verifies negative test cases and exception handling
- **Mocking Usage**: Detects need for HttpCalloutMock, StubProvider
- **Documentation**: Analyzes JavaDoc coverage for test methods
- **Scoring**: 0-100 quality score with prioritized recommendations

### 2. Test Refactoring

- **Best Practices**: Add Test.startTest/stopTest, @testSetup, proper assertions
- **Bulk Testing**: Add 200-record tests for all DML operations
- **Meaningful Assertions**: Replace System.assert(true) with descriptive assertEquals
- **Error Cases**: Add try-catch blocks for negative testing
- **Mocking**: Implement HttpCalloutMock for external dependencies
- **Documentation**: Add comprehensive JavaDoc with Given/When/Then structure
- **Collapsible Regions**: Wrap improvements in `//region IMPROVED:` blocks

### 3. Test Generation

- **Comprehensive Coverage**: Generate tests achieving 100% coverage
- **All Scenarios**: Positive, negative, edge cases, bulk operations
- **Smart Analysis**: AI analyzes production code to identify all code paths
- **Mock Implementation**: Auto-generate mocks for callouts and dependencies
- **Full Documentation**: Every test method documented with scenario description

### 4. Mock Framework

- **HttpCalloutMock**: Generate mocks for REST API testing
- **StubProvider**: Generate interface mocks with call tracking
- **Test Data Builders**: Builder pattern classes for SObjects
- **Test Data Factories**: Reusable factories for common objects

## Commands

### Analyze Test Quality (No Changes)

```bash
# Analyze all test classes
npm run test:analyze

# Analyze specific test class
node demos/test-improvement-demo.js --mode=analyze --class=LeadTriggerHandlerTest
```

**Output**: Quality scores, issues breakdown, recommendations (no code changes)

### Improve Existing Tests

```bash
# Improve all test classes
npm run test:improve

# Improve specific test class
node demos/test-improvement-demo.js --mode=improve --class=LeadTriggerHandlerTest

# Improve without deploying
node demos/test-improvement-demo.js --mode=improve --no-deploy
```

**Output**: Refactored test code with best practices, deployed to dev-sandbox

### Generate New Tests

```bash
# Generate tests for all classes with low coverage
npm run test:generate

# Generate for specific target coverage
node demos/test-improvement-demo.js --mode=generate --target-coverage=90

# Include all classes (not just critical)
node demos/test-improvement-demo.js --mode=generate --all-classes
```

**Output**: New test classes achieving target coverage, deployed to dev-sandbox

### Comprehensive Mode (Refactor + Generate)

```bash
# Full test suite improvement
npm run test:comprehensive

# Comprehensive with custom target
node demos/test-improvement-demo.js --mode=comprehensive --target-coverage=100

# Comprehensive without auto-deploy
node demos/test-improvement-demo.js --mode=comprehensive --no-deploy
```

**Output**: Both refactored existing tests AND generated new tests, all deployed

## Command Options

| Option                        | Description                                               | Example                          |
| ----------------------------- | --------------------------------------------------------- | -------------------------------- |
| `--mode=<mode>`               | Operation mode: analyze, improve, generate, comprehensive | `--mode=comprehensive`           |
| `--class=<name>`              | Specific test class to process                            | `--class=LeadTriggerHandlerTest` |
| `--target-org=<org>`          | Target Salesforce org for deployment                      | `--target-org=dev-sandbox`       |
| `--target-coverage=<percent>` | Target coverage percentage (default: 100)                 | `--target-coverage=90`           |
| `--no-deploy`                 | Skip automatic deployment                                 | `--no-deploy`                    |
| `--all-classes`               | Process all classes, not just critical ones               | `--all-classes`                  |
| `--no-docs`                   | Skip documentation generation                             | `--no-docs`                      |

## Usage Examples

### Example 1: Quick Test Quality Audit

```bash
npm run test:analyze
```

**Result**:

- Quality scores for all test classes
- Critical issues identified
- No code changes made

### Example 2: Fix Bad Test Practices

```bash
npm run test:improve
```

**Result**:

- System.assert(true) replaced with meaningful assertions
- Added bulk testing with 200 records
- Added Test.startTest/stopTest blocks
- Implemented mocking for callouts
- Deployed to dev-sandbox

### Example 3: Boost Coverage to 90%

```bash
node demos/test-improvement-demo.js --mode=generate --target-coverage=90
```

**Result**:

- New test classes generated for classes under 90% coverage
- Tests cover positive, negative, and edge cases
- All deployed and ready for validation

### Example 4: Full Org Test Suite Overhaul

```bash
npm run test:comprehensive
```

**Result**:

- All existing tests refactored with best practices
- New tests generated for coverage gaps
- Full documentation added
- Everything deployed to dev-sandbox
- Comprehensive report generated

### Example 5: Improve Specific Test Without Deploy

```bash
node demos/test-improvement-demo.js --mode=improve --class=AccountTriggerHandlerTest --no-deploy
```

**Result**:

- AccountTriggerHandlerTest refactored locally
- Saved to `./output/test-improvements/AccountTriggerHandlerTest.cls`
- NOT deployed (review first)

## Output Structure

All outputs are saved to `./output/test-improvements/`:

```
output/test-improvements/
├── AccountTriggerHandlerTest.cls          # Improved test code
├── AccountTriggerHandlerTest.cls-meta.xml # Metadata
├── LeadTriggerHandlerTest.cls
├── LeadTriggerHandlerTest.cls-meta.xml
├── test-improvement-report.json           # Improvement results
├── test-generation-report.json            # Generation results
├── comprehensive-test-report.json         # Combined results
└── progress.json                          # Progress for resume
```

## Salesforce Best Practices Applied

### 1. Bulkification Testing

```apex
@isTest
static void testBulkInsertSuccess() {
    // Given: 200 test records
    List<Lead> leads = new List<Lead>();
    for (Integer i = 0; i < 200; i++) {
        leads.add(new Lead(
            FirstName = 'Test',
            LastName = 'Lead ' + i,
            Company = 'Test Company'
        ));
    }

    Test.startTest();
    // When: Bulk insert
    insert leads;
    Test.stopTest();

    // Then: All records inserted successfully
    List<Lead> inserted = [SELECT Id FROM Lead];
    System.assertEquals(200, inserted.size(), 'All 200 leads should be inserted');
}
```

### 2. Meaningful Assertions

```apex
// BAD
System.assert(true);

// GOOD
System.assertEquals(200, results.size(),
    'Should process all 200 records without hitting governor limits');
System.assertNotEquals(null, result.opportunityId,
    'Opportunity should be created with valid Id');
```

### 3. Proper Test Data Setup

```apex
@testSetup
static void setupTestData() {
    // Shared test data for all test methods
    Account acc = new Account(
        Name = 'Test Account',
        Industry = 'Technology'
    );
    insert acc;
}

@isTest
static void testProcessAccount() {
    // Query test data created in @testSetup
    Account acc = [SELECT Id FROM Account LIMIT 1];

    Test.startTest();
    // Test logic
    Test.stopTest();

    // Assertions
}
```

### 4. HttpCalloutMock Implementation

```apex
@isTest
private class MockHttpResponse implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HTTPResponse res = new HTTPResponse();
        res.setStatusCode(200);
        res.setBody('{"status": "success"}');
        res.setHeader('Content-Type', 'application/json');
        return res;
    }
}

@isTest
static void testExternalCallout() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

    Test.startTest();
    // Code that makes callout
    Test.stopTest();

    // Assertions
}
```

### 5. Negative Testing

```apex
@isTest
static void testInvalidInputThrowsException() {
    // Given: Invalid input
    Lead invalidLead = new Lead(LastName = null);

    Test.startTest();
    try {
        // When: Attempt to process invalid lead
        LeadTriggerHandler.processLead(invalidLead);
        System.assert(false, 'Should have thrown exception');
    } catch (IllegalArgumentException e) {
        // Then: Exception thrown with appropriate message
        System.assert(e.getMessage().contains('LastName'),
            'Exception should mention missing LastName');
    }
    Test.stopTest();
}
```

## Quality Score Breakdown

| Score Range | Grade      | Description                                      |
| ----------- | ---------- | ------------------------------------------------ |
| 80-100      | Excellent  | Comprehensive tests following all best practices |
| 60-79       | Good       | Solid tests with minor improvements needed       |
| 40-59       | Needs Work | Significant gaps in coverage or practices        |
| 0-39        | Poor       | Major issues, recommend complete rewrite         |

## Issue Severity Levels

### CRITICAL

- Meaningless System.assert(true) assertions
- Hardcoded Salesforce IDs
- SeeAllData=true usage
- No assertions at all
- No bulk testing for DML operations

### HIGH

- Missing Test.startTest/stopTest
- Insufficient assertions (< 1 per test method)
- No negative test cases
- Missing mocks for external dependencies
- Single record testing only

### MEDIUM

- No @testSetup method
- Missing assertion messages
- Limited test method coverage
- Insufficient method documentation

### LOW

- Missing class-level documentation
- Unclear test method naming
- Minor documentation gaps

## Integration with Org Analysis

The test improvement system integrates with the batch analysis system:

```bash
# Step 1: Run org analysis
npm run batch:analyze-deep

# Step 2: Review coverage gaps in report
cat ./analysis/org-analysis-report.md

# Step 3: Run comprehensive test improvement
npm run test:comprehensive

# Step 4: Re-run org analysis to verify improvements
npm run batch:analyze-deep
```

## Troubleshooting

### Issue: Tests fail after deployment

**Solution**: Check the deployment errors in the report. Common issues:

- Test data references non-existent records
- API version mismatch
- Missing required fields in test data

### Issue: Coverage didn't increase as expected

**Solution**:

- Check that tests were actually deployed (look for "deployed: true" in report)
- Run tests in sandbox: `sf apex run test --target-org dev-sandbox`
- Review generated test code for completeness

### Issue: Mock errors during test execution

**Solution**:

- Ensure Test.setMock() is called before the callout
- Verify mock class implements correct interface
- Check endpoint matching in multi-endpoint mocks

## Next Steps

After running test improvements:

1. **Review Generated Code**: Check `./output/test-improvements/` for all generated tests
2. **Validate in Sandbox**: Run tests manually in dev-sandbox to verify
3. **Check Coverage**: Use `sf apex get test --coverage-formatters html` to view coverage report
4. **Iterate**: Run test:analyze again to verify improvements
5. **Deploy to Production**: Once validated, deploy improved tests to production

## Advanced Usage

### Generate Test Data Factories

```javascript
import { TestDataFactoryGenerator } from "./src/services/test-data-factory-generator.js";

const generator = new TestDataFactoryGenerator(salesforceManager, logger);

// Generate builder for Account
const accountBuilder = await generator.generateFactoryForSObject("Account");
// Output: AccountBuilder.cls with builder pattern

// Generate universal factory
const universalFactory = generator.generateUniversalFactory();
// Output: TestDataFactory.cls with createAccount(), createContact(), etc.
```

### Generate Custom Mocks

```javascript
import { MockFrameworkGenerator } from "./src/services/mock-framework-generator.js";

const generator = new MockFrameworkGenerator(logger);

// Generate HTTP mock for specific endpoints
const mock = generator.generateMultiEndpointMock("ExternalAPIMock", [
  {
    method: "GET",
    endpoint: "/api/users",
    statusCode: 200,
    responseBody: '{"users": []}'
  },
  {
    method: "POST",
    endpoint: "/api/users",
    statusCode: 201,
    responseBody: '{"id": "123"}'
  }
]);
```

## Architecture

```
Test Improvement System
├── TestQualityAnalyzer - Analyzes test quality (0-100 score)
├── TestCodeGenerator - AI-powered test generation/improvement
├── MockFrameworkGenerator - Generates mocks, stubs, builders
├── TestDataFactoryGenerator - Generates SObject factories
└── TestOrchestrator - Orchestrates workflow + deployment
```

## Environment Variables

Required in `.env`:

```
ANTHROPIC_API_KEY=<your-key>
SF_LOGIN_URL=https://login.salesforce.com
SF_API_VERSION=60.0
```

## Support

For issues or questions:

1. Check logs: `npm run logs`
2. Review reports in `./output/test-improvements/`
3. Check progress.json for resume capability
4. Consult org-analysis-report.md for context
