// src/services/task-analyzer.js - Natural Language Task Analysis

import { z } from "zod";

// Define response schema for structured outputs
const TaskAnalysisSchema = z.object({
  type: z.enum([
    "apex",
    "flow",
    "field",
    "object",
    "integration",
    "report",
    "other"
  ]),
  complexity: z.enum(["low", "medium", "high"]),
  affectedObjects: z.array(z.string()),
  requiredComponents: z.array(z.string()),
  estimatedEffort: z.string(),
  riskLevel: z.enum(["low", "medium", "high"]),
  testingRequired: z.boolean(),
  description: z.string(),
  technicalRequirements: z.array(z.string())
});

export class TaskAnalyzer {
  constructor(anthropic, logger) {
    this.anthropic = anthropic;
    this.logger = logger;
  }

  async analyze(description) {
    try {
      this.logger.info("Analyzing task description...");

      const response = await this.anthropic.messages.create(
        {
          model: "claude-sonnet-4-20250514",
          max_tokens: 1000,
          temperature: 0.1,
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
              content: `Analyze this Salesforce development task: "${description}"`
            }
          ]
        },
        {
          headers: {
            "anthropic-beta": "prompt-caching-2024-07-31"
          }
        }
      );

      // With structured outputs, response is already parsed JSON
      const analysis = response.content[0].text
        ? JSON.parse(response.content[0].text)
        : response.content[0];

      // Enhance and validate the analysis
      return this.enhanceAnalysis(analysis, description);
    } catch (error) {
      this.logger.error("Task analysis failed:", error);
      // Return a basic analysis on error
      return this.basicAnalysis(description);
    }
  }

  getSystemPrompt() {
    return `You are a Salesforce development expert. Analyze development task descriptions and provide structured analysis.

Return your analysis as JSON with this structure:
{
    "type": "apex|flow|field|object|integration|report|other",
    "complexity": "low|medium|high",
    "affectedObjects": ["Object1", "Object2"],
    "requiredComponents": ["component1", "component2"],
    "estimatedEffort": "hours",
    "riskLevel": "low|medium|high",
    "testingRequired": true|false,
    "description": "Parsed understanding of the task",
    "technicalRequirements": ["req1", "req2"]
}`;
  }

  basicAnalysis(description) {
    // Fallback analysis based on keywords
    const desc = description.toLowerCase();

    let type = "other";
    if (desc.includes("field")) type = "field";
    else if (desc.includes("flow")) type = "flow";
    else if (
      desc.includes("apex") ||
      desc.includes("class") ||
      desc.includes("trigger")
    )
      type = "apex";
    else if (desc.includes("object")) type = "object";
    else if (desc.includes("integration") || desc.includes("api"))
      type = "integration";
    else if (desc.includes("report") || desc.includes("dashboard"))
      type = "report";

    const affectedObjects = this.extractObjects(description);

    return {
      type,
      complexity: "medium",
      affectedObjects,
      requiredComponents: [type],
      estimatedEffort: "2",
      riskLevel: "medium",
      testingRequired: true,
      description: description,
      technicalRequirements: []
    };
  }

  extractObjects(description) {
    const objects = [];
    const commonObjects = [
      "Account",
      "Contact",
      "Lead",
      "Opportunity",
      "Case",
      "Task",
      "Event"
    ];

    for (const obj of commonObjects) {
      if (description.includes(obj)) {
        objects.push(obj);
      }
    }

    // Look for custom objects (ending with __c)
    const customObjPattern = /\b([A-Z][a-z]+(?:_[A-Z][a-z]+)*__c)\b/g;
    let match;
    while ((match = customObjPattern.exec(description)) !== null) {
      objects.push(match[1]);
    }

    return objects.length > 0 ? objects : ["Account"]; // Default to Account if none found
  }

  enhanceAnalysis(analysis, originalDescription) {
    // Ensure all required fields are present
    const enhanced = {
      taskId: `task-${Date.now()}`,
      timestamp: new Date().toISOString(),
      originalDescription: originalDescription,
      type: analysis.type || "other",
      complexity: analysis.complexity || "medium",
      affectedObjects: analysis.affectedObjects || [],
      requiredComponents: analysis.requiredComponents || [],
      estimatedEffort: analysis.estimatedEffort || "2",
      riskLevel: analysis.riskLevel || "medium",
      testingRequired: analysis.testingRequired !== false,
      description: analysis.description || originalDescription,
      technicalRequirements: analysis.technicalRequirements || []
    };

    // Add deployment strategy based on risk
    if (enhanced.riskLevel === "low") {
      enhanced.deploymentStrategy = "auto-deploy";
    } else if (enhanced.riskLevel === "medium") {
      enhanced.deploymentStrategy = "sandbox-validation";
    } else {
      enhanced.deploymentStrategy = "manual-review";
    }

    this.logger.info(
      `Task analyzed - Type: ${enhanced.type}, Risk: ${enhanced.riskLevel}`
    );

    return enhanced;
  }
}
