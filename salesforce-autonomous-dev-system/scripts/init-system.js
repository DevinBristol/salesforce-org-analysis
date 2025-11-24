// scripts/init-system.js - System Initialization Script

import ora from "ora";
import chalk from "chalk";
import fs from "fs-extra";
import { exec } from "child_process";
import { promisify } from "util";
import dotenv from "dotenv";
import winston from "winston";
import { SalesforceManager } from "../src/services/salesforce-manager.js";
import { OrgAnalyzer } from "../src/services/org-analyzer.js";

const execAsync = promisify(exec);
dotenv.config();

// Configure logging
const logger = winston.createLogger({
  level: "info",
  format: winston.format.simple(),
  transports: [
    new winston.transports.File({ filename: "logs/init.log" }),
    new winston.transports.Console()
  ]
});

class SystemInitializer {
  constructor() {
    this.salesforceManager = new SalesforceManager(logger);
    this.orgAnalyzer = new OrgAnalyzer(logger);
  }

  async run() {
    console.log(
      chalk.cyan.bold(
        "\n╔══════════════════════════════════════════════════════╗"
      )
    );
    console.log(
      chalk.cyan.bold("║     Autonomous Salesforce System Initialization     ║")
    );
    console.log(
      chalk.cyan.bold(
        "╚══════════════════════════════════════════════════════╝\n"
      )
    );

    try {
      // Step 1: Check prerequisites
      await this.checkPrerequisites();

      // Step 2: Create directory structure
      await this.createDirectoryStructure();

      // Step 3: Validate environment variables
      await this.validateEnvironment();

      // Step 4: Connect to Salesforce
      const connectSpinner = ora("Connecting to Salesforce orgs...").start();
      await this.salesforceManager.connect();
      connectSpinner.succeed("Connected to Salesforce");

      // Step 5: Fetch and index org metadata
      const metadataSpinner = ora("Fetching org metadata...").start();
      const metadata = await this.salesforceManager.fetchMetadata([
        "CustomObject",
        "ApexClass",
        "ApexTrigger",
        "Flow",
        "CustomField"
      ]);
      metadataSpinner.succeed(
        `Metadata fetched: ${Object.keys(metadata).length} types`
      );

      // Step 6: Build schema index
      const indexSpinner = ora("Building schema index...").start();
      await this.buildSchemaIndex(metadata);
      indexSpinner.succeed("Schema index built");

      // Step 7: Initialize AI context
      const contextSpinner = ora("Initializing AI context...").start();
      await this.initializeAIContext();
      contextSpinner.succeed("AI context initialized");

      // Step 8: Analyze org
      const analyzeSpinner = ora("Analyzing org structure...").start();
      const analysis = await this.orgAnalyzer.analyzeOrg();
      analyzeSpinner.succeed("Org analysis complete");

      // Display summary
      this.displaySummary(metadata, analysis);

      console.log(chalk.green.bold("\n✓ System initialization complete!"));
      console.log(chalk.gray("\nYou can now:"));
      console.log(chalk.gray("  • Start the system: npm run start"));
      console.log(chalk.gray('  • Submit a task: npm run task "your request"'));
      console.log(
        chalk.gray("  • Run the demo: npm run demo:apex-improvement\n")
      );
    } catch (error) {
      console.error(chalk.red("\n✗ Initialization failed:"), error.message);
      logger.error("Initialization error:", error);
      process.exit(1);
    }
  }

  async checkPrerequisites() {
    const spinner = ora("Checking prerequisites...").start();

    const checks = [
      { cmd: "node --version", name: "Node.js", minVersion: "18" },
      { cmd: "npm --version", name: "npm" },
      { cmd: "sf --version", name: "Salesforce CLI" }
    ];

    for (const check of checks) {
      try {
        const { stdout } = await execAsync(check.cmd);
        logger.info(`${check.name}: ${stdout.trim()}`);
      } catch (error) {
        spinner.fail(`${check.name} not found`);
        throw new Error(`${check.name} is required. Please install it first.`);
      }
    }

    spinner.succeed("All prerequisites met");
  }

  async createDirectoryStructure() {
    const spinner = ora("Creating directory structure...").start();

    const directories = [
      "./logs",
      "./metadata",
      "./output",
      "./deployments",
      "./analysis",
      "./temp",
      "./cache"
    ];

    for (const dir of directories) {
      await fs.ensureDir(dir);
    }

    // Create .gitignore if it doesn't exist
    const gitignore = `
node_modules/
.env
logs/
temp/
cache/
output/
deployments/
*.log
.DS_Store
`;

    if (!(await fs.pathExists("./.gitignore"))) {
      await fs.writeFile("./.gitignore", gitignore.trim());
    }

    spinner.succeed("Directory structure created");
  }

  async validateEnvironment() {
    const spinner = ora("Validating environment variables...").start();

    const required = ["CLAUDE_API_KEY", "SF_USERNAME", "SF_LOGIN_URL"];

    const missing = [];
    for (const key of required) {
      if (!process.env[key]) {
        missing.push(key);
      }
    }

    if (missing.length > 0) {
      spinner.fail("Missing environment variables");
      console.log(chalk.yellow("\nMissing environment variables:"));
      missing.forEach((key) => console.log(chalk.yellow(`  • ${key}`)));
      console.log(
        chalk.gray("\nPlease update your .env file with the required values.")
      );
      throw new Error("Environment validation failed");
    }

    spinner.succeed("Environment variables validated");
  }

  async buildSchemaIndex(metadata) {
    const index = {
      timestamp: new Date().toISOString(),
      objects: {},
      classes: {},
      triggers: {},
      flows: {}
    };

    // Index custom objects
    if (metadata.CustomObject) {
      for (const obj of metadata.CustomObject) {
        index.objects[obj.fullName] = {
          name: obj.fullName,
          lastModified: obj.lastModifiedDate,
          createdBy: obj.createdByName
        };
      }
    }

    // Index Apex classes
    if (metadata.ApexClass) {
      for (const cls of metadata.ApexClass) {
        index.classes[cls.fullName] = {
          name: cls.fullName,
          lastModified: cls.lastModifiedDate
        };
      }
    }

    // Index triggers
    if (metadata.ApexTrigger) {
      for (const trigger of metadata.ApexTrigger) {
        index.triggers[trigger.fullName] = {
          name: trigger.fullName,
          lastModified: trigger.lastModifiedDate
        };
      }
    }

    // Index flows
    if (metadata.Flow) {
      for (const flow of metadata.Flow) {
        index.flows[flow.fullName] = {
          name: flow.fullName,
          lastModified: flow.lastModifiedDate
        };
      }
    }

    // Save index
    await fs.writeJson("./metadata/schema-index.json", index, { spaces: 2 });
    logger.info("Schema index saved");
  }

  async initializeAIContext() {
    const context = {
      initialized: new Date().toISOString(),
      orgInfo: {
        username: process.env.SF_USERNAME,
        loginUrl: process.env.SF_LOGIN_URL
      },
      capabilities: [
        "apex-generation",
        "flow-creation",
        "field-creation",
        "object-creation",
        "test-generation",
        "code-review",
        "optimization"
      ],
      settings: {
        autoDeployment: false,
        testCoverageRequired: 75,
        maxDeploymentRetries: 3,
        sandboxFirst: true
      }
    };

    await fs.writeJson("./cache/ai-context.json", context, { spaces: 2 });
    logger.info("AI context saved");
  }

  displaySummary(metadata, analysis) {
    console.log(chalk.blue.bold("\n📊 Org Summary:"));
    console.log(chalk.gray("─".repeat(40)));

    if (metadata.CustomObject) {
      console.log(`  Custom Objects: ${metadata.CustomObject.length}`);
    }
    if (metadata.ApexClass) {
      console.log(`  Apex Classes: ${metadata.ApexClass.length}`);
    }
    if (metadata.ApexTrigger) {
      console.log(`  Apex Triggers: ${metadata.ApexTrigger.length}`);
    }
    if (metadata.Flow) {
      console.log(`  Flows: ${metadata.Flow.length}`);
    }

    console.log(chalk.gray("─".repeat(40)));
    console.log(`  Org Complexity: ${analysis.complexity.toUpperCase()}`);

    if (analysis.recommendations.length > 0) {
      console.log(chalk.yellow("\n⚠️  Recommendations:"));
      analysis.recommendations.slice(0, 3).forEach((rec) => {
        console.log(chalk.gray(`  • ${rec.message}`));
      });
    }
  }
}

// Run initialization
const initializer = new SystemInitializer();
initializer.run();
