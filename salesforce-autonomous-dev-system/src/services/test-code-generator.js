// src/services/test-code-generator.js - AI-Powered Test Code Generation Service

import Anthropic from '@anthropic-ai/sdk';
import { z } from 'zod';
import { trackApiUsage } from '../utils/ai-cost-tracker.js';

// Define response schemas for structured outputs
const TestImprovementSchema = z.object({
    improvedCode: z.string(),
    improvements: z.array(z.object({
        type: z.string(),
        description: z.string()
    }))
});

const TestGenerationSchema = z.object({
    testCode: z.string()
});

/**
 * Generates and improves Apex test classes using AI
 */
export class TestCodeGenerator {
    constructor(logger) {
        this.logger = logger;
        this.anthropic = new Anthropic({
            apiKey: process.env.ANTHROPIC_API_KEY,
            timeout: 120000, // 120 seconds
            maxRetries: 3
        });
    }

    /**
     * Improves an existing test class based on quality analysis
     * @param {string} testClassContent - Current test class code
     * @param {string} testClassName - Name of the test class
     * @param {Object} qualityAnalysis - Results from TestQualityAnalyzer
     * @param {Object} classToTest - The production class being tested (optional)
     * @returns {Object} {improvedCode, improvements, documentation}
     */
    async improveTestClass(testClassContent, testClassName, qualityAnalysis, classToTest = null) {
        try {
            this.logger.info(`Improving test class: ${testClassName} (Score: ${qualityAnalysis.score}/100)`);

            const systemPrompt = this.buildTestImprovementSystemPrompt();
            const userPrompt = this.buildTestImprovementPrompt(
                testClassContent,
                testClassName,
                qualityAnalysis,
                classToTest
            );

            const response = await this.anthropic.messages.create({
                model: process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-20250514',
                max_tokens: 8000,
                temperature: 0.3,
                system: [
                    {
                        type: "text",
                        text: systemPrompt,
                        cache_control: { type: "ephemeral" }
                    }
                ],
                messages: [{
                    role: 'user',
                    content: userPrompt
                }]
            }, {
                headers: {
                    'anthropic-beta': 'prompt-caching-2024-07-31'
                }
            });

            // Parse and validate with Zod schema
            const rawData = JSON.parse(response.content[0].text);
            const result = TestImprovementSchema.safeParse(rawData);
            if (!result.success) {
                this.logger.error('Schema validation failed for test improvement:', result.error.errors);
                throw new Error('Invalid AI response structure for test improvement');
            }
            const { improvedCode, improvements } = result.data;

            // Capture token usage
            const usage = {
                inputTokens: response.usage.input_tokens,
                outputTokens: response.usage.output_tokens,
                cacheReadTokens: response.usage.cache_read_input_tokens || 0,
                cacheCreationTokens: response.usage.cache_creation_input_tokens || 0
            };

            // Track cost in database
            trackApiUsage(response);

            this.logger.info(`Tokens used - Input: ${usage.inputTokens}, Output: ${usage.outputTokens}, Cache Read: ${usage.cacheReadTokens}`);

            return {
                success: true,
                improvedCode,
                improvements,
                originalScore: qualityAnalysis.score,
                metadata: this.generateTestMetadata(),
                usage
            };
        } catch (error) {
            this.logger.error(`Failed to improve test class ${testClassName}:`, error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    /**
     * Generates a new test class from scratch for a production class
     * @param {string} classContent - Production class source code
     * @param {string} className - Name of the production class
     * @param {number} targetCoverage - Target coverage percentage (default 100)
     * @returns {Object} {testCode, testClassName, coverage, documentation}
     */
    async generateNewTestClass(classContent, className, targetCoverage = 100) {
        try {
            this.logger.info(`Generating new test class for: ${className} (Target: ${targetCoverage}%)`);

            const systemPrompt = this.buildTestGenerationSystemPrompt();
            const userPrompt = this.buildTestGenerationPrompt(
                classContent,
                className,
                targetCoverage
            );

            const response = await this.anthropic.messages.create({
                model: process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-20250514',
                max_tokens: 8000,
                temperature: 0.3,
                system: [
                    {
                        type: "text",
                        text: systemPrompt,
                        cache_control: { type: "ephemeral" }
                    }
                ],
                messages: [{
                    role: 'user',
                    content: userPrompt
                }]
            }, {
                headers: {
                    'anthropic-beta': 'prompt-caching-2024-07-31'
                }
            });

            // Parse and validate with Zod schema
            const rawData = JSON.parse(response.content[0].text);
            const result = TestGenerationSchema.safeParse(rawData);
            if (!result.success) {
                this.logger.error('Schema validation failed for test generation:', result.error.errors);
                throw new Error('Invalid AI response structure for test generation');
            }
            const testCode = result.data.testCode;
            const testClassName = `${className}Test`;

            // Capture token usage
            const usage = {
                inputTokens: response.usage.input_tokens,
                outputTokens: response.usage.output_tokens,
                cacheReadTokens: response.usage.cache_read_input_tokens || 0,
                cacheCreationTokens: response.usage.cache_creation_input_tokens || 0
            };

            // Track cost in database
            trackApiUsage(response);

            this.logger.info(`Tokens used - Input: ${usage.inputTokens}, Output: ${usage.outputTokens}, Cache Read: ${usage.cacheReadTokens}`);

            return {
                success: true,
                testCode,
                testClassName,
                targetCoverage,
                metadata: this.generateTestMetadata(),
                usage
            };
        } catch (error) {
            this.logger.error(`Failed to generate test class for ${className}:`, error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    /**
     * Builds system prompt for test improvement
     */
    buildTestImprovementSystemPrompt() {
        return `You are an expert Salesforce test automation engineer specializing in writing high-quality, comprehensive test classes.

YOUR TASK: Improve an existing Apex test class to follow Salesforce best practices and achieve comprehensive coverage.

CRITICAL REQUIREMENTS:
1. **Bulkification Testing**: ALWAYS test with 200 records to verify governor limit handling
2. **Meaningful Assertions**: Use System.assertEquals/assertNotEquals with descriptive messages, NEVER System.assert(true)
3. **Test.startTest/stopTest**: Wrap test execution to reset governor limits
4. **@testSetup**: Use for shared test data when appropriate
5. **Error Handling**: Test negative scenarios with try-catch for expected exceptions
6. **Edge Cases**: Test null inputs, empty collections, boundary values
7. **Mocking**: Use HttpCalloutMock or StubProvider for external dependencies
8. **Documentation**: Add comprehensive JavaDoc to all test methods
9. **No SeeAllData**: NEVER use SeeAllData=true, create all test data explicitly
10. **Descriptive Naming**: Use clear method names like testBulkInsertSuccess(), testInvalidInputThrowsException()

IMPROVEMENT FORMAT:
- Add //region IMPROVED: <description> around changed sections
- Add // IMPROVED: <inline comment> for specific improvements
- Document all improvements in method-level JavaDoc

CODE STRUCTURE:
\`\`\`apex
/**
 * Test class documentation
 * IMPROVEMENTS:
 * - Added bulk testing with 200 records
 * - Replaced System.assert(true) with meaningful assertions
 * - Added error handling test methods
 */
@isTest
private class YourTestClass {

    @testSetup
    static void setupTestData() {
        // Shared test data
    }

    //region IMPROVED: Added bulk testing for governor limits
    @isTest
    static void testBulkInsertSuccess() {
        // Given: 200 test records
        // When: Bulk insert operation
        // Then: All records processed without hitting governor limits
    }
    //endregion
}
\`\`\`

OUTPUT: Provide ONLY the complete improved Apex test class code, no explanations.`;
    }

    /**
     * Builds system prompt for new test generation
     */
    buildTestGenerationSystemPrompt() {
        return `You are an expert Salesforce test automation engineer specializing in writing comprehensive test classes from scratch.

YOUR TASK: Generate a complete Apex test class that achieves ${100}% code coverage for the provided production class.

CRITICAL REQUIREMENTS:
1. **Comprehensive Coverage**: Test ALL public methods, ALL code paths, ALL error conditions
2. **Bulkification Testing**: ALWAYS include tests with 200 records to verify governor limits
3. **Meaningful Assertions**: Use System.assertEquals/assertNotEquals with descriptive messages
4. **Test.startTest/stopTest**: Wrap all test execution blocks
5. **@testSetup**: Create shared test data efficiently
6. **Positive Tests**: Test happy path scenarios with valid inputs
7. **Negative Tests**: Test error conditions, exceptions, invalid inputs
8. **Edge Cases**: Test null, empty, boundary values, large datasets
9. **Mocking**: Implement mocks for callouts, external dependencies, interfaces
10. **Documentation**: Add comprehensive JavaDoc explaining each test scenario

TEST ORGANIZATION:
- Group related tests together
- Use descriptive method names following pattern: test[Method][Scenario][ExpectedResult]
- Example: testProcessRecordsBulkInsertSuccess(), testProcessRecordsNullInputThrowsException()

TEST METHOD STRUCTURE:
\`\`\`apex
/**
 * Tests [scenario description]
 * Given: [initial conditions]
 * When: [action being tested]
 * Then: [expected outcome]
 */
@isTest
static void testMethodScenarioResult() {
    // Given: Setup test data

    Test.startTest();
    // When: Execute the method being tested
    Test.stopTest();

    // Then: Assert expected outcomes with descriptive messages
    System.assertEquals(expected, actual, 'Description of what should happen');
}
\`\`\`

MOCKING PATTERN (for callouts):
\`\`\`apex
@isTest
private class MockHttpResponse implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HTTPResponse res = new HTTPResponse();
        res.setStatusCode(200);
        res.setBody('{"status": "success"}');
        return res;
    }
}
\`\`\`

OUTPUT: Provide ONLY the complete Apex test class code, no explanations.`;
    }

    /**
     * Builds user prompt for test improvement
     */
    buildTestImprovementPrompt(testClassContent, testClassName, qualityAnalysis, classToTest) {
        let prompt = `IMPROVE THIS TEST CLASS:\n\n`;
        prompt += `Class Name: ${testClassName}\n`;
        prompt += `Current Quality Score: ${qualityAnalysis.score}/100\n\n`;

        // Add quality issues
        if (qualityAnalysis.issues.critical.length > 0) {
            prompt += `CRITICAL ISSUES TO FIX:\n`;
            qualityAnalysis.issues.critical.forEach(issue => {
                prompt += `- ${issue.type}: ${issue.description}\n`;
                prompt += `  Fix: ${issue.recommendation}\n`;
            });
            prompt += `\n`;
        }

        if (qualityAnalysis.issues.high.length > 0) {
            prompt += `HIGH PRIORITY ISSUES:\n`;
            qualityAnalysis.issues.high.forEach(issue => {
                prompt += `- ${issue.type}: ${issue.description}\n`;
                prompt += `  Fix: ${issue.recommendation}\n`;
            });
            prompt += `\n`;
        }

        if (qualityAnalysis.issues.medium.length > 0) {
            prompt += `MEDIUM PRIORITY IMPROVEMENTS:\n`;
            qualityAnalysis.issues.medium.forEach(issue => {
                prompt += `- ${issue.type}: ${issue.description}\n`;
            });
            prompt += `\n`;
        }

        // Add production class if available
        if (classToTest) {
            prompt += `PRODUCTION CLASS BEING TESTED:\n\`\`\`apex\n${classToTest.content}\n\`\`\`\n\n`;
        }

        prompt += `CURRENT TEST CLASS CODE:\n\`\`\`apex\n${testClassContent}\n\`\`\`\n\n`;

        prompt += `Generate the improved test class that addresses all issues and achieves 100% coverage.`;

        return prompt;
    }

    /**
     * Builds user prompt for new test generation
     */
    buildTestGenerationPrompt(classContent, className, targetCoverage) {
        let prompt = `GENERATE A COMPREHENSIVE TEST CLASS:\n\n`;
        prompt += `Production Class Name: ${className}\n`;
        prompt += `Target Coverage: ${targetCoverage}%\n`;
        prompt += `Test Class Name: ${className}Test\n\n`;

        prompt += `PRODUCTION CLASS TO TEST:\n\`\`\`apex\n${classContent}\n\`\`\`\n\n`;

        prompt += `REQUIREMENTS:\n`;
        prompt += `1. Achieve ${targetCoverage}% code coverage by testing all methods and branches\n`;
        prompt += `2. Include bulk testing with 200 records for all DML operations\n`;
        prompt += `3. Test positive scenarios, negative scenarios, and edge cases\n`;
        prompt += `4. Use meaningful assertions with descriptive messages\n`;
        prompt += `5. Implement mocks for any external dependencies (callouts, etc.)\n`;
        prompt += `6. Add comprehensive JavaDoc documentation\n`;
        prompt += `7. Follow Salesforce best practices (Test.startTest/stopTest, @testSetup, etc.)\n\n`;

        prompt += `Generate the complete test class now.`;

        return prompt;
    }

    /**
     * Generates a complete test suite with documentation generation
     * @param {string} classContent - Production class code
     * @param {string} className - Production class name
     * @returns {Object} Test class with comprehensive documentation
     */
    async generateTestClassWithDocumentation(classContent, className) {
        try {
            this.logger.info(`Generating test class with full documentation for: ${className}`);

            const systemPrompt = this.buildTestGenerationSystemPrompt() + `\n\nADDITIONAL REQUIREMENT: Add comprehensive documentation to EVERY method including:
- Class-level JavaDoc describing the test suite
- Method-level JavaDoc with Given/When/Then structure
- Inline comments explaining complex test logic
- Documentation of mock implementations`;

            const userPrompt = this.buildTestGenerationPrompt(classContent, className, 100);

            const response = await this.anthropic.messages.create({
                model: process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-20250514',
                max_tokens: 8000,
                temperature: 0.3,
                system: [
                    {
                        type: "text",
                        text: systemPrompt,
                        cache_control: { type: "ephemeral" }
                    }
                ],
                messages: [{
                    role: 'user',
                    content: userPrompt
                }]
            }, {
                headers: {
                    'anthropic-beta': 'prompt-caching-2024-07-31'
                }
            });

            // Parse and validate with Zod schema
            const rawData = JSON.parse(response.content[0].text);
            const result = TestGenerationSchema.safeParse(rawData);
            if (!result.success) {
                this.logger.error('Schema validation failed for documented test generation:', result.error.errors);
                throw new Error('Invalid AI response structure for documented test generation');
            }
            const testCode = result.data.testCode;
            const testClassName = `${className}Test`;

            // Capture token usage
            const usage = {
                inputTokens: response.usage.input_tokens,
                outputTokens: response.usage.output_tokens,
                cacheReadTokens: response.usage.cache_read_input_tokens || 0,
                cacheCreationTokens: response.usage.cache_creation_input_tokens || 0
            };

            // Track cost in database
            trackApiUsage(response);

            this.logger.info(`Tokens used - Input: ${usage.inputTokens}, Output: ${usage.outputTokens}, Cache Read: ${usage.cacheReadTokens}`);

            return {
                success: true,
                testCode,
                testClassName,
                hasFullDocumentation: true,
                metadata: this.generateTestMetadata(),
                usage
            };
        } catch (error) {
            this.logger.error(`Failed to generate documented test for ${className}:`, error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    /**
     * Extracts code from AI response
     */
    extractCodeFromResponse(responseText) {
        // Extract code from markdown code blocks
        const codeBlockMatch = responseText.match(/```apex\n([\s\S]*?)```/);
        if (codeBlockMatch) {
            return codeBlockMatch[1].trim();
        }

        // If no code block, return the whole response (might be just code)
        return responseText.trim();
    }

    /**
     * Extracts improvements list from AI response
     */
    extractImprovementsFromResponse(responseText) {
        const improvements = [];

        // Look for IMPROVED comments
        const improvedRegions = responseText.match(/\/\/region IMPROVED: ([^\n]+)/g) || [];
        improvedRegions.forEach(region => {
            const description = region.replace('//region IMPROVED: ', '').trim();
            improvements.push({
                type: 'Code Improvement',
                description
            });
        });

        // Look for inline improvements
        const inlineImprovements = responseText.match(/\/\/ IMPROVED: ([^\n]+)/g) || [];
        inlineImprovements.forEach(comment => {
            const description = comment.replace('// IMPROVED: ', '').trim();
            improvements.push({
                type: 'Inline Improvement',
                description
            });
        });

        return improvements;
    }

    /**
     * Generates metadata XML for test class
     */
    generateTestMetadata() {
        return `<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>${process.env.SF_API_VERSION || '60.0'}</apiVersion>
    <status>Active</status>
</ApexClass>`;
    }

    /**
     * Validates that generated test code meets quality standards
     * @param {string} testCode - Generated test code
     * @returns {Object} {valid, issues}
     */
    validateGeneratedTest(testCode) {
        const issues = [];

        // Check for @isTest annotation
        if (!testCode.includes('@isTest')) {
            issues.push('Missing @isTest annotation on class or methods');
        }

        // Check for Test.startTest/stopTest
        if (!testCode.includes('Test.startTest()') || !testCode.includes('Test.stopTest()')) {
            issues.push('Missing Test.startTest()/stopTest() blocks');
        }

        // Check for assertions
        const hasAssertions = testCode.includes('System.assert') ||
                             testCode.includes('Assert.areEqual') ||
                             testCode.includes('Assert.isTrue');
        if (!hasAssertions) {
            issues.push('No assertions found in test code');
        }

        // Check for meaningful assertions (not just true)
        if (testCode.includes('System.assert(true)')) {
            issues.push('Contains meaningless System.assert(true) assertions');
        }

        // Check for bulk testing (200 records)
        const hasBulkTesting = testCode.includes('200') || testCode.includes('201');
        if (!hasBulkTesting) {
            issues.push('No bulk testing detected (should test with 200+ records)');
        }

        return {
            valid: issues.length === 0,
            issues
        };
    }
}
