// src/core/tool-definitions.js - Agent Tool Definitions
// Structured tool definitions for the agent system

/**
 * Tool Definition Format
 *
 * From Anthropic:
 * "Tools serve as primary execution building blocks. Tools are prominent
 * in Claude's context window, making them the primary actions Claude
 * will consider when solving problems."
 *
 * Best practices:
 * - Clear, descriptive names (e.g., fetchInbox, searchEmails)
 * - Comprehensive descriptions with examples
 * - Well-defined input schemas
 * - Poka-yoke: modify arguments to prevent mistakes
 */

/**
 * Create tool definitions for the Salesforce agent system
 * @param {Object} salesforceManager - Salesforce API wrapper
 * @param {Object} aiCodeGenerator - AI code generation service
 * @param {Object} deploymentPipeline - Deployment service
 */
export function createSalesforceTools(salesforceManager, aiCodeGenerator, deploymentPipeline) {
    return [
        // === CODE READING TOOLS ===
        {
            name: 'read_apex_class',
            description: `Read an Apex class from the Salesforce org.
Returns the full source code of the specified class.

Example usage:
- read_apex_class("AccountTriggerHandler") → Returns the handler code
- read_apex_class("ContactService") → Returns the service class code

Use this to understand existing code before making changes.`,
            inputSchema: {
                type: 'object',
                properties: {
                    className: {
                        type: 'string',
                        description: 'Name of the Apex class (without .cls extension)'
                    },
                    targetOrg: {
                        type: 'string',
                        description: 'Target org alias (default: dev-sandbox)',
                        default: 'dev-sandbox'
                    }
                },
                required: ['className']
            },
            execute: async (input) => {
                const result = await salesforceManager.getApexClass(input.className, input.targetOrg);
                return {
                    className: input.className,
                    body: result.body,
                    apiVersion: result.apiVersion,
                    status: result.status,
                    length: result.body?.length || 0
                };
            }
        },

        {
            name: 'search_code',
            description: `Search for patterns in the codebase.
Finds classes containing the specified text or pattern.

Example usage:
- search_code("DML in handler") → Find trigger handlers with DML
- search_code("without sharing") → Find classes without sharing rules
- search_code("System.debug") → Find debug statements

Returns matching classes and line numbers.`,
            inputSchema: {
                type: 'object',
                properties: {
                    query: {
                        type: 'string',
                        description: 'Search pattern or text to find'
                    },
                    fileTypes: {
                        type: 'array',
                        items: { type: 'string' },
                        description: 'File types to search (cls, trigger, etc.)',
                        default: ['cls', 'trigger']
                    },
                    targetOrg: {
                        type: 'string',
                        default: 'dev-sandbox'
                    }
                },
                required: ['query']
            },
            execute: async (input) => {
                return salesforceManager.searchCode(input.query, input.fileTypes, input.targetOrg);
            }
        },

        {
            name: 'list_classes',
            description: `List Apex classes in the org, optionally filtered.

Example usage:
- list_classes() → List all classes
- list_classes("TriggerHandler") → List classes containing "TriggerHandler"
- list_classes(null, "Test") → List test classes

Returns class names and metadata.`,
            inputSchema: {
                type: 'object',
                properties: {
                    filter: {
                        type: 'string',
                        description: 'Filter classes by name pattern'
                    },
                    suffix: {
                        type: 'string',
                        description: 'Filter by suffix (e.g., "Test", "Handler")'
                    },
                    targetOrg: {
                        type: 'string',
                        default: 'dev-sandbox'
                    }
                }
            },
            execute: async (input) => {
                return salesforceManager.listClasses(input.filter, input.suffix, input.targetOrg);
            }
        },

        // === CODE ANALYSIS TOOLS ===
        {
            name: 'analyze_code_quality',
            description: `Analyze Apex code for quality issues and best practice violations.

Checks for:
- DML statements in loops
- SOQL queries in loops
- Missing null checks
- Hardcoded IDs
- Missing error handling
- Governor limit risks

Example usage:
- analyze_code_quality("ContactTriggerHandler") → Full analysis

Returns structured analysis with severity levels.`,
            inputSchema: {
                type: 'object',
                properties: {
                    className: {
                        type: 'string',
                        description: 'Class to analyze'
                    },
                    analysisType: {
                        type: 'string',
                        enum: ['quick', 'standard', 'deep'],
                        description: 'Analysis depth',
                        default: 'standard'
                    }
                },
                required: ['className']
            },
            execute: async (input) => {
                const code = await salesforceManager.getApexClass(input.className);
                return analyzeCodeQuality(code.body, input.analysisType);
            }
        },

        {
            name: 'check_test_coverage',
            description: `Check test coverage for a class or trigger.

Example usage:
- check_test_coverage("AccountService") → Returns coverage percentage
- check_test_coverage("ContactTrigger") → Returns trigger coverage

Returns coverage percentage and uncovered lines.`,
            inputSchema: {
                type: 'object',
                properties: {
                    className: {
                        type: 'string',
                        description: 'Class or trigger name'
                    },
                    targetOrg: {
                        type: 'string',
                        default: 'dev-sandbox'
                    }
                },
                required: ['className']
            },
            execute: async (input) => {
                return salesforceManager.getTestCoverage(input.className, input.targetOrg);
            }
        },

        // === CODE GENERATION TOOLS ===
        {
            name: 'generate_apex_code',
            description: `Generate or improve Apex code using AI.

Modes:
- "improve": Make targeted improvements to existing code
- "generate": Create new code from scratch
- "refactor": Restructure without changing behavior

Example usage:
- generate_apex_code("Add empty checks", "ContactTriggerHandler", "improve")
- generate_apex_code("Create account service", null, "generate")

Returns generated code ready for validation.`,
            inputSchema: {
                type: 'object',
                properties: {
                    description: {
                        type: 'string',
                        description: 'What to generate or improve'
                    },
                    existingClass: {
                        type: 'string',
                        description: 'Existing class to improve (for improve/refactor modes)'
                    },
                    mode: {
                        type: 'string',
                        enum: ['improve', 'generate', 'refactor'],
                        default: 'improve'
                    },
                    preserveLogic: {
                        type: 'boolean',
                        description: 'Preserve existing business logic',
                        default: true
                    }
                },
                required: ['description']
            },
            execute: async (input) => {
                const context = {};
                if (input.existingClass) {
                    context.existingCode = await salesforceManager.getApexClass(input.existingClass);
                }
                return aiCodeGenerator.generate({
                    task: { description: input.description },
                    orgContext: context,
                    mode: input.mode,
                    preserveLogic: input.preserveLogic
                });
            }
        },

        {
            name: 'generate_test_class',
            description: `Generate a test class for existing Apex code.

Creates comprehensive tests with:
- Positive and negative test cases
- Bulk data handling (200+ records)
- Edge case coverage
- Proper Test.startTest()/stopTest() usage

Example usage:
- generate_test_class("AccountService") → Creates AccountServiceTest

Returns test class code with target 90%+ coverage.`,
            inputSchema: {
                type: 'object',
                properties: {
                    className: {
                        type: 'string',
                        description: 'Class to create tests for'
                    },
                    targetCoverage: {
                        type: 'number',
                        description: 'Target coverage percentage',
                        default: 90
                    },
                    includeBulkTests: {
                        type: 'boolean',
                        description: 'Include bulk data tests',
                        default: true
                    }
                },
                required: ['className']
            },
            execute: async (input) => {
                const classCode = await salesforceManager.getApexClass(input.className);
                return aiCodeGenerator.generateTests({
                    className: input.className,
                    classCode: classCode.body,
                    targetCoverage: input.targetCoverage,
                    includeBulkTests: input.includeBulkTests
                });
            }
        },

        // === VALIDATION TOOLS ===
        {
            name: 'validate_apex',
            description: `Validate Apex code for syntax errors and best practices.

Performs:
- Syntax validation
- Static analysis
- Best practice checks

Example usage:
- validate_apex("public class Foo { }") → Validates code string
- validate_apex(generatedCode) → Validates generated code

Returns validation result with any errors.`,
            inputSchema: {
                type: 'object',
                properties: {
                    code: {
                        type: 'string',
                        description: 'Apex code to validate'
                    },
                    className: {
                        type: 'string',
                        description: 'Class name for context'
                    }
                },
                required: ['code']
            },
            execute: async (input) => {
                return salesforceManager.validateApex(input.code, input.className);
            }
        },

        // === DEPLOYMENT TOOLS ===
        {
            name: 'create_deployment_package',
            description: `Create a deployment package from generated code.

Prepares code for deployment with:
- Package.xml generation
- Metadata formatting
- Dependency ordering

Example usage:
- create_deployment_package(artifacts) → Creates deployable package

Returns deployment package location.`,
            inputSchema: {
                type: 'object',
                properties: {
                    artifacts: {
                        type: 'object',
                        description: 'Generated code artifacts (apex, tests, metadata)'
                    },
                    deploymentId: {
                        type: 'string',
                        description: 'Optional deployment ID'
                    }
                },
                required: ['artifacts']
            },
            execute: async (input) => {
                return deploymentPipeline.createDeploymentPackage(
                    input.artifacts,
                    input.deploymentId || `deploy-${Date.now()}`
                );
            }
        },

        {
            name: 'validate_deployment',
            description: `Validate a deployment without actually deploying.

Runs Salesforce deployment validation to check:
- All components compile
- Tests pass
- No dependency issues

Example usage:
- validate_deployment("deploy-123") → Validates package

Returns validation status and any errors.`,
            inputSchema: {
                type: 'object',
                properties: {
                    deploymentId: {
                        type: 'string',
                        description: 'Deployment package ID'
                    },
                    targetOrg: {
                        type: 'string',
                        default: 'dev-sandbox'
                    },
                    runTests: {
                        type: 'boolean',
                        description: 'Run tests during validation',
                        default: true
                    }
                },
                required: ['deploymentId']
            },
            execute: async (input) => {
                return deploymentPipeline.validateDeployment(
                    input.deploymentId,
                    input.targetOrg,
                    input.runTests
                );
            }
        },

        {
            name: 'deploy_to_sandbox',
            description: `Deploy code to a sandbox environment.

IMPORTANT: Only deploys to whitelisted sandboxes.
Creates a pre-deployment snapshot for rollback.

Example usage:
- deploy_to_sandbox("deploy-123", "dev-sandbox") → Deploys package

Returns deployment status and snapshot ID for rollback.`,
            inputSchema: {
                type: 'object',
                properties: {
                    deploymentId: {
                        type: 'string',
                        description: 'Deployment package ID'
                    },
                    targetOrg: {
                        type: 'string',
                        description: 'Target sandbox (must be whitelisted)',
                        default: 'dev-sandbox'
                    },
                    skipTests: {
                        type: 'boolean',
                        description: 'Skip test execution (not recommended)',
                        default: false
                    }
                },
                required: ['deploymentId']
            },
            execute: async (input) => {
                return deploymentPipeline.deployToSandbox(
                    input.deploymentId,
                    input.targetOrg,
                    { skipTests: input.skipTests }
                );
            }
        },

        {
            name: 'rollback_deployment',
            description: `Rollback a deployment using a snapshot.

Restores the org to the state before deployment.

Example usage:
- rollback_deployment("snapshot-123") → Restores previous state

Returns rollback status.`,
            inputSchema: {
                type: 'object',
                properties: {
                    snapshotId: {
                        type: 'string',
                        description: 'Snapshot ID from deployment'
                    },
                    targetOrg: {
                        type: 'string',
                        default: 'dev-sandbox'
                    }
                },
                required: ['snapshotId']
            },
            execute: async (input) => {
                return deploymentPipeline.rollback(input.snapshotId, input.targetOrg);
            }
        },

        // === TEST EXECUTION TOOLS ===
        {
            name: 'run_tests',
            description: `Run Apex tests in the org.

Options:
- Run specific test classes
- Run all tests
- Run tests for specific classes

Example usage:
- run_tests(["AccountServiceTest"]) → Run specific tests
- run_tests(null, "AccountService") → Run tests covering class

Returns test results and coverage.`,
            inputSchema: {
                type: 'object',
                properties: {
                    testClasses: {
                        type: 'array',
                        items: { type: 'string' },
                        description: 'Specific test classes to run'
                    },
                    coverageFor: {
                        type: 'string',
                        description: 'Run tests that cover this class'
                    },
                    targetOrg: {
                        type: 'string',
                        default: 'dev-sandbox'
                    }
                }
            },
            execute: async (input) => {
                return salesforceManager.runTests(
                    input.testClasses,
                    input.coverageFor,
                    input.targetOrg
                );
            }
        }
    ];
}

/**
 * Analyze code quality (helper function)
 */
function analyzeCodeQuality(code, analysisType = 'standard') {
    const issues = [];

    // DML in loops
    if (/for\s*\([^)]*\)[^}]*\b(insert|update|delete|upsert)\b/gis.test(code)) {
        issues.push({
            type: 'dml_in_loop',
            severity: 'critical',
            message: 'DML statement inside loop - will hit governor limits'
        });
    }

    // SOQL in loops
    if (/for\s*\([^)]*\)[^}]*\[SELECT/gis.test(code)) {
        issues.push({
            type: 'soql_in_loop',
            severity: 'critical',
            message: 'SOQL query inside loop - will hit governor limits'
        });
    }

    // Missing null checks before DML
    if (/(?<!if\s*\([^)]*\s*!=\s*null[^)]*\)\s*\{?\s*)(insert|update|delete)\s+\w+\s*;/gi.test(code)) {
        issues.push({
            type: 'missing_null_check',
            severity: 'high',
            message: 'DML without null/empty check'
        });
    }

    // Hardcoded IDs
    if (/['"][a-zA-Z0-9]{15,18}['"]/.test(code)) {
        issues.push({
            type: 'hardcoded_id',
            severity: 'high',
            message: 'Hardcoded Salesforce ID - use Custom Metadata instead'
        });
    }

    // System.debug statements
    if (/System\.debug/g.test(code)) {
        const debugCount = (code.match(/System\.debug/g) || []).length;
        issues.push({
            type: 'debug_statements',
            severity: 'low',
            message: `${debugCount} debug statement(s) - remove before production`
        });
    }

    // Missing sharing keyword
    if (/public\s+class\s+\w+/.test(code) && !/with\s+sharing|without\s+sharing|inherited\s+sharing/.test(code)) {
        issues.push({
            type: 'missing_sharing',
            severity: 'medium',
            message: 'Missing sharing keyword - defaults to without sharing'
        });
    }

    // Magic numbers in array access
    if (/\[\s*\d+\s*\]/.test(code)) {
        issues.push({
            type: 'magic_numbers',
            severity: 'medium',
            message: 'Magic numbers in array access - use named constants'
        });
    }

    return {
        issues,
        summary: {
            critical: issues.filter(i => i.severity === 'critical').length,
            high: issues.filter(i => i.severity === 'high').length,
            medium: issues.filter(i => i.severity === 'medium').length,
            low: issues.filter(i => i.severity === 'low').length
        },
        overallScore: calculateQualityScore(issues)
    };
}

function calculateQualityScore(issues) {
    let score = 100;
    for (const issue of issues) {
        switch (issue.severity) {
            case 'critical': score -= 25; break;
            case 'high': score -= 15; break;
            case 'medium': score -= 5; break;
            case 'low': score -= 2; break;
        }
    }
    return Math.max(0, score);
}

export default createSalesforceTools;
