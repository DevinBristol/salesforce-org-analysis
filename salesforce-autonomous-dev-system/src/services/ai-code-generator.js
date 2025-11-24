// src/services/ai-code-generator.js - AI-Powered Code Generation

import fs from "fs-extra";
import { z } from "zod";

// Define response schemas for structured outputs
const CodeGenerationSchema = z.object({
  apex: z.record(z.string()),
  tests: z.record(z.string()),
  metadata: z.record(z.string()),
  instructions: z.string()
});

const ApexImprovementSchema = z.object({
  improvedCode: z.string(),
  improvements: z.string()
});

export class AICodeGenerator {
  constructor(anthropic, logger) {
    this.anthropic = anthropic;
    this.logger = logger;
  }

  async generate(context) {
    const { task, orgContext, priority } = context;

    try {
      this.logger.info("Starting AI code generation...");

      // Build the prompt based on task type
      const prompt = this.buildPrompt(task, orgContext);

      // Call Claude API for code generation
      const response = await this.anthropic.messages.create(
        {
          model: "claude-sonnet-4-20250514",
          max_tokens: 4000,
          temperature: 0.2,
          system: [
            {
              type: "text",
              text: this.getSystemPrompt(),
              cache_control: { type: "ephemeral" }
            }
          ],
          messages: [
            {
              role: "user",
              content: prompt
            }
          ]
        },
        {
          headers: {
            "anthropic-beta": "prompt-caching-2024-07-31"
          }
        }
      );

      // Parse the generated code from structured response
      const responseData = JSON.parse(response.content[0].text);
      const generatedCode = {
        apex: responseData.apex || {},
        tests: responseData.tests || {},
        metadata: responseData.metadata || {},
        instructions: responseData.instructions || ""
      };

      // Post-process and validate
      const artifacts = await this.processArtifacts(generatedCode, task);

      // Save artifacts
      await this.saveArtifacts(artifacts, task.taskId);

      return artifacts;
    } catch (error) {
      this.logger.error("Code generation failed:", error);
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

  buildPrompt(task, orgContext) {
    let prompt = `Task: ${task.description}\n\n`;
    prompt += `Task Type: ${task.type}\n`;
    prompt += `Affected Objects: ${task.affectedObjects.join(", ")}\n\n`;

    if (orgContext) {
      prompt += `Current Org Context:\n`;
      if (orgContext.objects) {
        prompt += `Objects in org: ${Object.keys(orgContext.objects).join(", ")}\n`;
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

  parseResponse(responseText) {
    const artifacts = {
      apex: {},
      tests: {},
      metadata: {},
      instructions: ""
    };

    // Parse Apex classes
    const apexRegex = /\[APEX_CLASS:(.+?)\]([\s\S]*?)\[\/APEX_CLASS\]/g;
    let match;
    while ((match = apexRegex.exec(responseText)) !== null) {
      artifacts.apex[`${match[1]}.cls`] = match[2].trim();
    }

    // Parse test classes
    const testRegex = /\[TEST_CLASS:(.+?)\]([\s\S]*?)\[\/TEST_CLASS\]/g;
    while ((match = testRegex.exec(responseText)) !== null) {
      artifacts.tests[`${match[1]}.cls`] = match[2].trim();
    }

    // Parse metadata
    const metadataRegex = /\[METADATA:(.+?)\]([\s\S]*?)\[\/METADATA\]/g;
    while ((match = metadataRegex.exec(responseText)) !== null) {
      artifacts.metadata[match[1]] = match[2].trim();
    }

    // Extract any instructions
    const instructionRegex = /\[INSTRUCTIONS\]([\s\S]*?)\[\/INSTRUCTIONS\]/;
    const instructionMatch = responseText.match(instructionRegex);
    if (instructionMatch) {
      artifacts.instructions = instructionMatch[1].trim();
    }

    return artifacts;
  }

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
      await fs.writeFile(
        `${outputDir}/instructions.md`,
        artifacts.instructions
      );
    }

    // Save summary
    await fs.writeJson(
      `${outputDir}/artifacts.json`,
      {
        taskId,
        timestamp: artifacts.timestamp,
        files: {
          apex: Object.keys(artifacts.apex || {}),
          metadata: Object.keys(artifacts.metadata || {})
        }
      },
      { spaces: 2 }
    );

    this.logger.info(`Artifacts saved to ${outputDir}`);
  }

  async generateApexImprovement(
    classContent,
    className,
    documentationOnly = false
  ) {
    try {
      const systemPrompt = documentationOnly
        ? `You are an expert Salesforce developer and technical writer. Your task is to add comprehensive documentation to existing code WITHOUT changing the code logic.`
        : `You are an expert Salesforce developer. You MUST make actual improvements to the code AND add comprehensive documentation. Every improvement must be wrapped in collapsible regions.`;

      const userPrompt = documentationOnly
        ? this.buildDocumentationPrompt(classContent, className)
        : this.buildImprovementPrompt(classContent, className);

      const response = await this.anthropic.messages.create(
        {
          model: "claude-sonnet-4-20250514",
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
              role: "user",
              content: userPrompt
            }
          ]
        },
        {
          headers: {
            "anthropic-beta": "prompt-caching-2024-07-31"
          }
        }
      );

      // Parse structured response
      const responseData = JSON.parse(response.content[0].text);

      return {
        improvedCode: responseData.improvedCode,
        improvements: responseData.improvements,
        originalCode: classContent
      };
    } catch (error) {
      this.logger.error("Failed to generate improvement:", error);
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
