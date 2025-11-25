// src/services/ai-code-generator.js - AI-Powered Code Generation

import fs from 'fs-extra';
import { z } from 'zod';
import { trackApiUsage } from '../utils/ai-cost-tracker.js';

// Define response schemas for structured outputs
const CodeGenerationSchema = z.object({
    apex: z.record(z.string()),
    tests: z.record(z.string()),
    metadata: z.record(z.string()),
    instructions: z.string()
});

// Schema for refactor mode - includes changes summary
const RefactorSchema = z.object({
    apex: z.record(z.string()),
    tests: z.record(z.string()).optional(),
    metadata: z.record(z.string()).optional(),
    changes: z.array(z.object({
        file: z.string(),
        type: z.enum(['modified', 'added', 'unchanged']),
        description: z.string()
    })),
    instructions: z.string()
});

const ApexImprovementSchema = z.object({
    improvedCode: z.string(),
    improvements: z.string()
});

// Generation modes
const GENERATION_MODE = {
    GREENFIELD: 'greenfield',  // New code from scratch
    REFACTOR: 'refactor'       // Modify existing code
};

export class AICodeGenerator {
    constructor(anthropic, logger) {
        this.anthropic = anthropic;
        this.logger = logger;
        this.salesforceManager = null;
    }

    /**
     * Set the Salesforce manager for fetching existing code
     */
    setSalesforceManager(salesforceManager) {
        this.salesforceManager = salesforceManager;
    }

    async generate(context) {
        const { task, orgContext, priority, mode = GENERATION_MODE.REFACTOR, targetOrg = 'Devin1' } = context;

        try {
            this.logger.info(`Starting AI code generation in ${mode} mode...`);

            // Fetch existing code context when in refactor mode
            let existingCode = {};
            if (mode === GENERATION_MODE.REFACTOR && this.salesforceManager) {
                this.logger.info('Fetching existing code from org...');
                existingCode = await this.fetchExistingCode(task, targetOrg);
                this.logger.info(`Found ${Object.keys(existingCode).length} related classes`);
            }

            // Build the prompt based on task type and mode
            const prompt = this.buildPrompt(task, orgContext, mode, existingCode);

            // Select system prompt based on mode
            const systemPrompt = mode === GENERATION_MODE.REFACTOR
                ? this.getRefactorSystemPrompt()
                : this.getSystemPrompt();

            // Call Claude API for code generation
            const response = await this.anthropic.messages.create({
                model: 'claude-sonnet-4-20250514',
                max_tokens: 16384,
                temperature: 0.2,
                system: [
                    {
                        type: "text",
                        text: systemPrompt,
                        cache_control: { type: "ephemeral" }
                    }
                ],
                messages: [
                    {
                        role: 'user',
                        content: prompt
                    }
                ]
            }, {
                headers: {
                    'anthropic-beta': 'prompt-caching-2024-07-31'
                }
            });

            // Check if response was truncated
            if (response.stop_reason === 'max_tokens') {
                this.logger.warn('Response was truncated due to max_tokens limit');
            }

            // Parse and validate with Zod schema
            // Strip markdown code blocks if present (Claude sometimes wraps JSON in ```json ... ```)
            let responseText = response.content[0].text;
            responseText = responseText.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();

            let rawData;
            try {
                rawData = JSON.parse(responseText);
            } catch (parseError) {
                this.logger.error(`JSON parse error at: ${parseError.message}`);
                this.logger.error(`Response length: ${responseText.length}, Stop reason: ${response.stop_reason}`);
                this.logger.error(`Response end: ...${responseText.slice(-200)}`);
                throw parseError;
            }
            const result = CodeGenerationSchema.safeParse(rawData);
            if (!result.success) {
                this.logger.error('Schema validation failed for code generation:', result.error.errors);
                throw new Error('Invalid AI response structure for code generation');
            }
            const generatedCode = {
                apex: result.data.apex || {},
                tests: result.data.tests || {},
                metadata: result.data.metadata || {},
                instructions: result.data.instructions || ''
            };

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

            // Post-process and validate
            const artifacts = await this.processArtifacts(generatedCode, task);

            // Add usage to artifacts
            artifacts.usage = usage;

            // Save artifacts
            await this.saveArtifacts(artifacts, task.taskId);

            return artifacts;
        } catch (error) {
            this.logger.error('Code generation failed:', error);
            throw error;
        }
    }

    getSystemPrompt() {
        return `You are an expert Salesforce developer assistant. You generate high-quality, production-ready Salesforce code including:
- Apex classes and triggers
- Lightning Web Components (LWC)
- Flows and Process Builders (as metadata XML)
- Custom objects, fields, and relationships
- Validation rules and formulas

Follow Salesforce best practices:
- Bulkify all Apex code
- Include proper error handling
- Add comprehensive test classes with >75% coverage
- Use meaningful variable and method names
- Include comments for complex logic
- Follow Salesforce naming conventions

Return your response as JSON with this structure:
{
    "apex": {"ClassName.cls": "apex code here"},
    "tests": {"TestClassName.cls": "test code here"},
    "metadata": {"filename.xml": "metadata XML here"},
    "instructions": "deployment instructions here"
}`;
    }

    /**
     * System prompt for REFACTOR mode - emphasizes preservation and minimal changes
     */
    getRefactorSystemPrompt() {
        return `You are an expert Salesforce developer performing TARGETED REFACTORING.

CRITICAL RULES - YOU MUST FOLLOW THESE:
1. PRESERVE ALL EXISTING BUSINESS LOGIC - Do not remove or replace functionality
2. PRESERVE CLASS INHERITANCE - If a class extends TriggerHandler, keep that inheritance
3. PRESERVE HELPER CLASS CALLS - Keep all calls to existing helper/utility classes
4. MINIMAL CHANGES ONLY - Make the smallest possible changes to fix the issues
5. NO COMPLETE REWRITES - Modify existing code, don't replace it entirely

Your job is to make SURGICAL improvements:
- Add null/empty checks where missing
- Add constants for magic numbers
- Add try-catch blocks for error handling
- Move DML to a service class IF NEEDED (but keep orchestration in handler)
- Add comments explaining changes

NEVER:
- Remove existing method implementations
- Change method signatures that other code depends on
- Remove calls to existing helper classes
- Change the overall architecture
- Add unnecessary features

Return your response as JSON:
{
    "apex": {"ClassName.cls": "complete modified class code"},
    "tests": {"TestClassName.cls": "test code if needed"},
    "metadata": {},
    "changes": [
        {"file": "ClassName.cls", "type": "modified", "description": "Added null checks, constants"},
    ],
    "instructions": "deployment instructions"
}`;
    }

    /**
     * Fetch existing code from the org for context
     */
    async fetchExistingCode(task, targetOrg) {
        if (!this.salesforceManager) {
            return {};
        }

        // Extract class name from task description
        const classNameMatch = task.description.match(/(\w+(?:TriggerHandler|Handler|Helper|Service|Trigger))/i);
        if (!classNameMatch) {
            // Try to find class based on affected objects
            if (task.affectedObjects && task.affectedObjects.length > 0) {
                const objectName = task.affectedObjects[0].replace('__c', '');
                return await this.salesforceManager.getRelatedClasses(`${objectName}TriggerHandler`, targetOrg);
            }
            return {};
        }

        const className = classNameMatch[1];
        return await this.salesforceManager.getRelatedClasses(className, targetOrg);
    }

    buildPrompt(task, orgContext, mode = 'greenfield', existingCode = {}) {
        let prompt = `Task: ${task.description}\n\n`;
        prompt += `Task Type: ${task.type}\n`;
        prompt += `Affected Objects: ${task.affectedObjects.join(', ')}\n\n`;

        // Add existing code context for refactor mode
        if (mode === 'refactor' && Object.keys(existingCode).length > 0) {
            prompt += `=== EXISTING CODE (YOU MUST PRESERVE THIS STRUCTURE) ===\n\n`;
            for (const [className, code] of Object.entries(existingCode)) {
                prompt += `--- ${className} ---\n`;
                prompt += `${code}\n\n`;
            }
            prompt += `=== END EXISTING CODE ===\n\n`;

            prompt += `REFACTORING REQUIREMENTS:\n`;
            prompt += `1. Keep the class inheritance (extends TriggerHandler if present)\n`;
            prompt += `2. Keep all existing helper class calls (ContactTriggerHelper, NamingUtility, etc.)\n`;
            prompt += `3. Make MINIMAL changes to address the issues\n`;
            prompt += `4. Add constants for any magic numbers (recordLists[2] -> ACCOUNTS_INDEX = 2)\n`;
            prompt += `5. Add empty/null checks before DML and method calls\n`;
            prompt += `6. Add try-catch blocks for error handling\n`;
            prompt += `7. If creating a service class, keep handler methods calling existing helpers\n\n`;
        }

        if (orgContext) {
            prompt += `Current Org Context:\n`;
            if (orgContext.objects) {
                prompt += `Objects in org: ${Object.keys(orgContext.objects).join(', ')}\n`;
            }
            if (orgContext.customFields) {
                prompt += `Custom fields available: ${orgContext.customFields.length} fields\n`;
            }
        }
        
        prompt += `\nGenerate the complete solution including:
1. All necessary Apex code
2. Test classes with >75% coverage
3. Any required metadata (as XML)
4. Deployment instructions

Return as JSON following the schema in the system prompt.`;

        return prompt;
    }

    // Legacy regex parsing method removed - now using Zod schema validation
    // All responses are validated with CodeGenerationSchema in generate() method

    async processArtifacts(generatedCode, task) {
        // Combine apex and test classes
        const allApex = { ...generatedCode.apex, ...generatedCode.tests };
        
        // Ensure proper formatting and add headers
        for (const [fileName, content] of Object.entries(allApex)) {
            allApex[fileName] = this.addApexHeader(content, fileName, task);
        }

        return {
            apex: allApex,
            metadata: generatedCode.metadata,
            instructions: generatedCode.instructions,
            taskId: task.taskId,
            timestamp: new Date().toISOString()
        };
    }

    addApexHeader(content, fileName, task) {
        const header = `/**
 * Generated by Autonomous Salesforce Development System
 * Task: ${task.description}
 * Date: ${new Date().toISOString()}
 * File: ${fileName}
 */\n\n`;
        
        return header + content;
    }

    async saveArtifacts(artifacts, taskId) {
        const outputDir = `./output/${taskId}`;
        await fs.ensureDir(outputDir);
        
        // Save Apex files
        if (artifacts.apex) {
            const apexDir = `${outputDir}/apex`;
            await fs.ensureDir(apexDir);
            for (const [fileName, content] of Object.entries(artifacts.apex)) {
                await fs.writeFile(`${apexDir}/${fileName}`, content);
            }
        }
        
        // Save metadata files
        if (artifacts.metadata) {
            const metadataDir = `${outputDir}/metadata`;
            await fs.ensureDir(metadataDir);
            for (const [fileName, content] of Object.entries(artifacts.metadata)) {
                await fs.writeFile(`${metadataDir}/${fileName}`, content);
            }
        }
        
        // Save instructions
        if (artifacts.instructions) {
            await fs.writeFile(`${outputDir}/instructions.md`, artifacts.instructions);
        }
        
        // Save summary
        await fs.writeJson(`${outputDir}/artifacts.json`, {
            taskId,
            timestamp: artifacts.timestamp,
            files: {
                apex: Object.keys(artifacts.apex || {}),
                metadata: Object.keys(artifacts.metadata || {})
            }
        }, { spaces: 2 });
        
        this.logger.info(`Artifacts saved to ${outputDir}`);
    }

    async generateApexImprovement(classContent, className, documentationOnly = false) {
        try {
            const systemPrompt = documentationOnly
                ? `You are an expert Salesforce developer and technical writer. Your task is to add comprehensive documentation to existing code WITHOUT changing the code logic.`
                : `You are an expert Salesforce developer. You MUST make actual improvements to the code AND add comprehensive documentation. Every improvement must be wrapped in collapsible regions.`;

            const userPrompt = documentationOnly
                ? this.buildDocumentationPrompt(classContent, className)
                : this.buildImprovementPrompt(classContent, className);

            const response = await this.anthropic.messages.create({
                model: 'claude-sonnet-4-20250514',
                max_tokens: 8000,
                temperature: 0.3,
                system: [
                    {
                        type: "text",
                        text: systemPrompt,
                        cache_control: { type: "ephemeral" }
                    }
                ],
                messages: [
                    {
                        role: 'user',
                        content: userPrompt
                    }
                ]
            }, {
                headers: {
                    'anthropic-beta': 'prompt-caching-2024-07-31'
                }
            });

            // Parse and validate with Zod schema
            // Strip markdown code blocks if present
            let responseText2 = response.content[0].text;
            responseText2 = responseText2.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();
            const rawData = JSON.parse(responseText2);
            const result = ApexImprovementSchema.safeParse(rawData);
            if (!result.success) {
                this.logger.error('Schema validation failed for Apex improvement:', result.error.errors);
                throw new Error('Invalid AI response structure for Apex improvement');
            }

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
                improvedCode: result.data.improvedCode,
                improvements: result.data.improvements,
                originalCode: classContent,
                usage
            };
        } catch (error) {
            this.logger.error('Failed to generate improvement:', error);
            throw error;
        }
    }

    buildDocumentationPrompt(classContent, className) {
        return `Add comprehensive JavaDoc documentation to this Apex class WITHOUT changing any code logic.

Class Name: ${className}

Current Code:
${classContent}

DOCUMENTATION REQUIREMENTS:

1. Add JavaDoc to ALL methods (public, private, static) with:
   - Brief one-line summary
   - @param for each parameter with description
   - @return with description
   - @throws for any exceptions

2. Add JavaDoc to the class itself explaining its purpose

3. Add inline comments for complex logic blocks

4. DO NOT change any code logic, variable names, or structure
5. DO NOT wrap anything in regions (no //region tags)
6. Return valid Apex code only (no markdown, no backticks)

Return as JSON:
{
    "improvedCode": "complete class code with comprehensive documentation",
    "improvements": "list of documentation added"
}`;
    }

    buildImprovementPrompt(classContent, className) {
        return `Analyze this Apex class and MAKE REAL IMPROVEMENTS with comprehensive documentation.

Class Name: ${className}

Current Code:
${classContent}

DOCUMENTATION REQUIREMENTS (for ALL code, changed or unchanged):

1. Add JavaDoc to ALL methods with:
   - Brief one-line summary
   - @param descriptions
   - @return description
   - IMPROVEMENTS section (if method was changed) listing what was improved

2. Add class-level JavaDoc

IMPROVEMENT REQUIREMENTS (wrap ALL changes in regions):

Required changes (make at least 5):
1. Add try-catch blocks with proper error handling
2. Add null checks before object access
3. Optimize SOQL queries (move outside loops, reduce queries)
4. Improve variable names for clarity
5. Add input validation
6. Improve bulkification
7. Add logging for debugging
8. Extract magic numbers/strings to constants
9. Create helper methods to reduce duplication
10. Add custom exception classes

REGION FORMAT for changed sections:
//region IMPROVED: Brief description of change
<changed code with inline // IMPROVED: comments>
//endregion

EXAMPLE:
/**
 * Processes lead phone numbers with formatting and validation
 *
 * @param leads List of lead records to process
 * @return void
 *
 * IMPROVEMENTS:
 * - Added null/empty validation
 * - Wrapped in try-catch for error handling
 * - Extracted validation to helper method
 */
//region IMPROVED: Error handling and validation enhancements
public static void processPhones(List<Lead> leads) {
    // IMPROVED: Added null/empty check
    if (leads == null || leads.isEmpty()) {
        return;
    }

    try { // IMPROVED: Added error handling
        for (Lead l : leads) {
            // existing logic
        }
    } catch (Exception e) {
        // IMPROVED: Added error logging
        System.debug(LoggingLevel.ERROR, 'Error: ' + e.getMessage());
    }
}
//endregion

CRITICAL REQUIREMENTS:
- Add JavaDoc to EVERY method (changed or not)
- Wrap ALL changed sections in //region IMPROVED: ... //endregion
- Add inline // IMPROVED: comments within regions
- Return valid Apex code only (no markdown, no backticks)

Return as JSON:
{
    "improvedCode": "complete improved class with regions and full documentation",
    "improvements": "numbered list of improvements"
}`;
    }
}
