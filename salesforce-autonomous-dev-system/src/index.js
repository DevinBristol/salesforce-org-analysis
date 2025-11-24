// src/index.js - Main Autonomous Development Orchestrator

import express from "express";
import dotenv from "dotenv";
import { Anthropic } from "@anthropic-ai/sdk";
import jsforce from "jsforce";
import winston from "winston";
import { SalesforceManager } from "./services/salesforce-manager.js";
import { AICodeGenerator } from "./services/ai-code-generator.js";
import { DeploymentPipeline } from "./services/deployment-pipeline.js";
import { TaskAnalyzer } from "./services/task-analyzer.js";
import { OrgAnalyzer } from "./services/org-analyzer.js";

// Load environment variables
dotenv.config();

// Configure logging
const logger = winston.createLogger({
  level: "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: "logs/error.log", level: "error" }),
    new winston.transports.File({ filename: "logs/system.log" }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

// Initialize services
const anthropic = new Anthropic({
  apiKey: process.env.CLAUDE_API_KEY
});

class AutonomousDevelopmentSystem {
  constructor() {
    this.salesforceManager = new SalesforceManager(logger);
    this.aiCodeGenerator = new AICodeGenerator(anthropic, logger);
    this.deploymentPipeline = new DeploymentPipeline(logger);
    this.taskAnalyzer = new TaskAnalyzer(anthropic, logger);
    this.orgAnalyzer = new OrgAnalyzer(logger);
    this.app = express();
    this.setupRoutes();
  }

  setupRoutes() {
    this.app.use(express.json());

    // Health check endpoint
    this.app.get("/health", (req, res) => {
      res.json({
        status: "healthy",
        timestamp: new Date().toISOString(),
        services: {
          salesforce: this.salesforceManager.isConnected(),
          ai: true,
          deployment: true
        }
      });
    });

    // Submit development task
    this.app.post("/task", async (req, res) => {
      try {
        const {
          description,
          priority = "medium",
          autoDeploy = false
        } = req.body;

        logger.info(`New task received: ${description}`);

        // Process the task
        const result = await this.processTask(
          description,
          priority,
          autoDeploy
        );

        res.json({
          success: true,
          taskId: result.taskId,
          status: result.status,
          artifacts: result.artifacts,
          deploymentStatus: result.deploymentStatus
        });
      } catch (error) {
        logger.error("Task processing failed:", error);
        res.status(500).json({
          success: false,
          error: error.message
        });
      }
    });

    // Get task status
    this.app.get("/task/:taskId", async (req, res) => {
      try {
        const status = await this.getTaskStatus(req.params.taskId);
        res.json(status);
      } catch (error) {
        res.status(404).json({
          error: "Task not found"
        });
      }
    });

    // Analyze org
    this.app.get("/analyze", async (req, res) => {
      try {
        const analysis = await this.orgAnalyzer.analyzeOrg();
        res.json(analysis);
      } catch (error) {
        logger.error("Org analysis failed:", error);
        res.status(500).json({
          error: error.message
        });
      }
    });
  }

  async processTask(description, priority, autoDeploy) {
    const taskId = `task-${Date.now()}`;
    const taskDir = `./output/${taskId}`;

    try {
      // Step 1: Analyze the task
      logger.info(`Analyzing task: ${taskId}`);
      const taskAnalysis = await this.taskAnalyzer.analyze(description);

      // Step 2: Get current org context
      logger.info("Fetching org context...");
      const orgContext = await this.orgAnalyzer.getContext(
        taskAnalysis.affectedObjects
      );

      // Step 3: Generate code/configuration
      logger.info("Generating solution...");
      const generatedArtifacts = await this.aiCodeGenerator.generate({
        task: taskAnalysis,
        orgContext: orgContext,
        priority: priority
      });

      // Step 4: Validate the generated solution
      logger.info("Validating solution...");
      const validationResult = await this.validateSolution(generatedArtifacts);

      if (!validationResult.isValid) {
        throw new Error(
          `Validation failed: ${validationResult.errors.join(", ")}`
        );
      }

      // Step 5: Deploy to sandbox
      let deploymentStatus = { deployed: false };
      if (autoDeploy || priority === "high") {
        logger.info("Deploying to sandbox...");
        deploymentStatus = await this.deploymentPipeline.deployToSandbox(
          generatedArtifacts,
          "dev-sandbox"
        );
      }

      // Step 6: Run tests
      if (deploymentStatus.deployed) {
        logger.info("Running tests...");
        const testResults = await this.runTests(taskId);
        deploymentStatus.testResults = testResults;
      }

      // Step 7: Generate report
      const report = await this.generateReport({
        taskId,
        description,
        analysis: taskAnalysis,
        artifacts: generatedArtifacts,
        validation: validationResult,
        deployment: deploymentStatus
      });

      return {
        taskId,
        status: "completed",
        artifacts: generatedArtifacts,
        deploymentStatus,
        report
      };
    } catch (error) {
      logger.error(`Task ${taskId} failed:`, error);
      throw error;
    }
  }

  async validateSolution(artifacts) {
    // Validate the generated artifacts
    const errors = [];

    // Check for syntax errors
    if (artifacts.apex) {
      const apexValidation = await this.salesforceManager.validateApex(
        artifacts.apex
      );
      if (!apexValidation.success) {
        errors.push(...apexValidation.errors);
      }
    }

    // Check for metadata validity
    if (artifacts.metadata) {
      const metadataValidation = await this.salesforceManager.validateMetadata(
        artifacts.metadata
      );
      if (!metadataValidation.success) {
        errors.push(...metadataValidation.errors);
      }
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }

  async runTests(taskId) {
    try {
      const testResults = await this.salesforceManager.runTests("dev-sandbox");
      return {
        passed: testResults.numTestsRun === testResults.numTestsPassed,
        coverage: testResults.codeCoverage,
        details: testResults
      };
    } catch (error) {
      logger.error("Test execution failed:", error);
      return {
        passed: false,
        error: error.message
      };
    }
  }

  async generateReport(data) {
    const report = {
      taskId: data.taskId,
      timestamp: new Date().toISOString(),
      description: data.description,
      analysis: data.analysis,
      generatedArtifacts: Object.keys(data.artifacts),
      validation: data.validation,
      deployment: {
        status: data.deployment.deployed ? "SUCCESS" : "PENDING",
        target: "dev-sandbox",
        testResults: data.deployment.testResults
      },
      nextSteps: []
    };

    if (data.deployment.deployed) {
      report.nextSteps.push("Review changes in sandbox");
      report.nextSteps.push("Run user acceptance testing");
      report.nextSteps.push("Prepare for production deployment");
    } else {
      report.nextSteps.push("Review generated artifacts");
      report.nextSteps.push("Deploy to sandbox for testing");
    }

    // Save report
    const fs = await import("fs-extra");
    await fs.ensureDir(`./output/${data.taskId}`);
    await fs.writeJson(`./output/${data.taskId}/report.json`, report, {
      spaces: 2
    });

    return report;
  }

  async getTaskStatus(taskId) {
    const fs = await import("fs-extra");
    const reportPath = `./output/${taskId}/report.json`;

    if (await fs.pathExists(reportPath)) {
      return await fs.readJson(reportPath);
    }

    throw new Error("Task not found");
  }

  async start() {
    const port = process.env.PORT || 3000;

    // Initialize Salesforce connection
    await this.salesforceManager.connect();

    // Start the server
    this.app.listen(port, () => {
      logger.info(
        `Autonomous Development System running on http://localhost:${port}`
      );
      logger.info("Ready to receive development tasks");
      console.log(`
╔════════════════════════════════════════════════════╗
║   Autonomous Salesforce Development System        ║
║   Status: OPERATIONAL                              ║
║   Endpoint: http://localhost:${port}              ║
║                                                    ║
║   Submit tasks via:                               ║
║   - Web API: POST /task                          ║
║   - CLI: npm run task "your request"             ║
║   - Interactive: npm run interactive             ║
╚════════════════════════════════════════════════════╝
            `);
    });
  }
}

// Start the system
const system = new AutonomousDevelopmentSystem();
system.start().catch((error) => {
  logger.error("Failed to start system:", error);
  process.exit(1);
});

export { AutonomousDevelopmentSystem };
