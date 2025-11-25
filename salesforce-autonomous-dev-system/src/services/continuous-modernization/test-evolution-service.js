/**
 * Test Evolution Service
 *
 * Evolves test classes to modern standards through intelligent analysis
 * and AI-powered improvement generation.
 */

import Anthropic from '@anthropic-ai/sdk';
import fs from 'fs-extra';
import path from 'path';

export class TestEvolutionService {
    constructor(config = {}) {
        this.anthropic = new Anthropic();
        this.model = config.model || 'claude-sonnet-4-20250514';
        this.targetCoverage = config.targetCoverage || 85;
        this.qualityThreshold = config.qualityThreshold || 70;
    }

    /**
     * Analyze a test class and identify improvement opportunities
     */
    async analyzeTestClass(testCode, testedClassCode) {
        const prompt = `Analyze this Apex test class and provide a comprehensive quality assessment.

## Test Class:
\`\`\`apex
${testCode}
\`\`\`

## Class Being Tested:
\`\`\`apex
${testedClassCode || 'Not provided'}
\`\`\`

Provide analysis in this JSON format:
{
    "qualityScore": <0-100>,
    "dimensions": {
        "bulkTesting": {
            "score": <0-100>,
            "issues": ["list of issues"],
            "hasTests200Records": <boolean>
        },
        "assertions": {
            "score": <0-100>,
            "count": <number>,
            "meaningfulCount": <number>,
            "issues": ["list of issues"]
        },
        "testDataPractices": {
            "score": <0-100>,
            "usesTestSetup": <boolean>,
            "usesFactory": <boolean>,
            "issues": ["list of issues"]
        },
        "errorHandling": {
            "score": <0-100>,
            "hasNegativeTests": <boolean>,
            "issues": ["list of issues"]
        },
        "mockingUsage": {
            "score": <0-100>,
            "usesHttpMock": <boolean>,
            "usesDmlMock": <boolean>,
            "issues": ["list of issues"]
        },
        "documentation": {
            "score": <0-100>,
            "hasMethodComments": <boolean>,
            "issues": ["list of issues"]
        }
    },
    "antiPatterns": [
        {
            "pattern": "name of anti-pattern",
            "location": "method or line",
            "severity": "critical|high|medium|low",
            "recommendation": "how to fix"
        }
    ],
    "missingTests": [
        {
            "scenario": "description of missing test",
            "priority": "high|medium|low",
            "type": "positive|negative|bulk|boundary"
        }
    ],
    "improvementPotential": {
        "estimatedNewScore": <0-100>,
        "effort": "low|medium|high",
        "quickWins": ["list of quick improvements"]
    }
}`;

        const response = await this.anthropic.messages.create({
            model: this.model,
            max_tokens: 4096,
            messages: [{ role: 'user', content: prompt }]
        });

        try {
            const content = response.content[0].text;
            const jsonMatch = content.match(/\{[\s\S]*\}/);
            return jsonMatch ? JSON.parse(jsonMatch[0]) : null;
        } catch (error) {
            console.error('Failed to parse analysis:', error);
            return null;
        }
    }

    /**
     * Generate an improved version of a test class
     */
    async evolveTestClass(testCode, testedClassCode, analysis) {
        const prompt = `You are an expert Salesforce Apex developer. Improve this test class based on the analysis provided.

## Current Test Class:
\`\`\`apex
${testCode}
\`\`\`

## Class Being Tested:
\`\`\`apex
${testedClassCode || 'Not provided'}
\`\`\`

## Analysis Results:
${JSON.stringify(analysis, null, 2)}

## Requirements for Improved Test Class:

1. **Bulk Testing**: Add tests that process 200+ records to verify bulkification
2. **Meaningful Assertions**: Replace any System.assert(true) with meaningful assertions
3. **Test Data**: Use @TestSetup methods for shared data, create data factories if needed
4. **Negative Tests**: Add tests for error conditions and edge cases
5. **Mocking**: Add HttpCalloutMock for any HTTP callouts
6. **Documentation**: Add clear comments explaining each test scenario
7. **Test.startTest/stopTest**: Use to reset governor limits for accurate testing

## Anti-Patterns to Remove:
- SeeAllData=true (create test data instead)
- Hard-coded IDs
- Tests that only check coverage without assertions
- Single-record tests for bulk-capable code

## Output Format:
Return ONLY the improved Apex test class code. Include inline comments explaining significant improvements.
The class must be syntactically valid Apex code ready for deployment.

\`\`\`apex
// Your improved test class here
\`\`\``;

        const response = await this.anthropic.messages.create({
            model: this.model,
            max_tokens: 8192,
            messages: [{ role: 'user', content: prompt }]
        });

        const content = response.content[0].text;
        const codeMatch = content.match(/```apex\n([\s\S]*?)```/);
        return codeMatch ? codeMatch[1].trim() : content;
    }

    /**
     * Generate a completely new test class for a class without tests
     */
    async generateTestClass(classCode, className) {
        const prompt = `You are an expert Salesforce Apex developer. Generate a comprehensive test class for the following Apex class.

## Class to Test:
\`\`\`apex
${classCode}
\`\`\`

## Class Name: ${className}

## Requirements:

### Coverage Requirements:
- Target 90%+ code coverage
- Test ALL public methods
- Test ALL code branches (if/else, try/catch, loops)

### Bulk Testing:
- ALL tests must handle 200+ records
- Use Test.startTest() and Test.stopTest() to reset governor limits

### Test Data:
- Use @TestSetup for shared test data
- Create a TestDataFactory inner class if complex data needed
- NEVER use SeeAllData=true
- NEVER hard-code Salesforce IDs

### Assertions:
- Every test method must have at least 2 meaningful assertions
- Use descriptive assertion messages: System.assertEquals(expected, actual, 'Description of what failed')
- Assert both positive outcomes AND state changes

### Negative Testing:
- Test error conditions and exceptions
- Test null/empty inputs
- Test boundary conditions
- Use try-catch with System.assert in catch block for expected exceptions

### Mocking:
- If the class makes HTTP callouts, implement HttpCalloutMock
- If external services are called, create mock responses

### Documentation:
- JavaDoc comment at class level describing test coverage
- Each test method should have a brief comment explaining the scenario
- Use Given/When/Then pattern in comments

### Naming Convention:
- Test class name: ${className}Test
- Test methods: test<MethodName>_<Scenario> (e.g., testProcessRecords_WithValidInput)

## Output:
Return ONLY valid Apex code for the test class. No explanations outside the code.

\`\`\`apex
// Your test class here
\`\`\``;

        const response = await this.anthropic.messages.create({
            model: this.model,
            max_tokens: 8192,
            messages: [{ role: 'user', content: prompt }]
        });

        const content = response.content[0].text;
        const codeMatch = content.match(/```apex\n([\s\S]*?)```/);
        return codeMatch ? codeMatch[1].trim() : content;
    }

    /**
     * Validate improved test class
     */
    async validateImprovement(originalCode, improvedCode, analysis) {
        const prompt = `Validate that the improved test class is better than the original.

## Original Test Class:
\`\`\`apex
${originalCode}
\`\`\`

## Improved Test Class:
\`\`\`apex
${improvedCode}
\`\`\`

## Original Analysis:
${JSON.stringify(analysis, null, 2)}

Evaluate the improvement and return JSON:
{
    "isValid": <boolean - is the code syntactically valid>,
    "isImproved": <boolean - is it genuinely better>,
    "estimatedNewScore": <0-100>,
    "improvements": ["list of specific improvements made"],
    "remainingIssues": ["any issues still present"],
    "deploymentReady": <boolean - safe to deploy>,
    "riskLevel": "low|medium|high"
}`;

        const response = await this.anthropic.messages.create({
            model: this.model,
            max_tokens: 2048,
            messages: [{ role: 'user', content: prompt }]
        });

        try {
            const content = response.content[0].text;
            const jsonMatch = content.match(/\{[\s\S]*\}/);
            return jsonMatch ? JSON.parse(jsonMatch[0]) : { isValid: false };
        } catch (error) {
            return { isValid: false, error: error.message };
        }
    }

    /**
     * Full evolution pipeline for a single test class
     */
    async runEvolutionPipeline(testClassName, testCode, testedClassCode) {
        console.log(`\n📊 Analyzing ${testClassName}...`);

        // Step 1: Analyze current state
        const analysis = await this.analyzeTestClass(testCode, testedClassCode);
        if (!analysis) {
            return { success: false, error: 'Analysis failed' };
        }

        console.log(`   Current quality score: ${analysis.qualityScore}/100`);

        // Step 2: Check if improvement needed
        if (analysis.qualityScore >= this.qualityThreshold) {
            console.log(`   ✅ Already meets quality threshold (${this.qualityThreshold})`);
            return {
                success: true,
                improved: false,
                reason: 'Already meets quality threshold',
                analysis
            };
        }

        console.log(`   🔧 Evolving test class...`);

        // Step 3: Generate improved version
        const improvedCode = await this.evolveTestClass(testCode, testedClassCode, analysis);

        // Step 4: Validate improvement
        const validation = await this.validateImprovement(testCode, improvedCode, analysis);

        if (!validation.isValid || !validation.isImproved) {
            console.log(`   ⚠️ Improvement validation failed`);
            return {
                success: false,
                error: 'Validation failed',
                validation
            };
        }

        console.log(`   ✅ Improved: ${analysis.qualityScore} → ${validation.estimatedNewScore}`);

        return {
            success: true,
            improved: true,
            testClassName,
            originalCode: testCode,
            improvedCode,
            originalScore: analysis.qualityScore,
            newScore: validation.estimatedNewScore,
            improvements: validation.improvements,
            analysis,
            validation
        };
    }
}
