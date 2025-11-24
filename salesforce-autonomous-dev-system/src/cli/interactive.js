// src/cli/interactive.js - Interactive CLI for task submission

import inquirer from "inquirer";
import chalk from "chalk";
import ora from "ora";
import fetch from "node-fetch";
import fs from "fs-extra";

class InteractiveCLI {
  constructor() {
    this.serverPort = process.env.PORT || 3000;
    this.taskHistory = [];
  }

  async run() {
    console.clear();
    console.log(
      chalk.cyan.bold(
        "╔══════════════════════════════════════════════════════╗"
      )
    );
    console.log(
      chalk.cyan.bold("║   Autonomous Salesforce Development System          ║")
    );
    console.log(
      chalk.cyan.bold(
        "║              Interactive Mode                        ║"
      )
    );
    console.log(
      chalk.cyan.bold(
        "╚══════════════════════════════════════════════════════╝\n"
      )
    );

    // Check if server is running
    const serverRunning = await this.checkServer();
    if (!serverRunning) {
      console.log(chalk.red("✗ Server is not running"));
      console.log(
        chalk.yellow("Please start the server first: npm run start\n")
      );
      process.exit(1);
    }

    // Main menu loop
    let exit = false;
    while (!exit) {
      const action = await this.showMainMenu();

      switch (action) {
        case "new_task":
          await this.createNewTask();
          break;
        case "view_history":
          await this.viewTaskHistory();
          break;
        case "check_status":
          await this.checkTaskStatus();
          break;
        case "run_demo":
          await this.runDemo();
          break;
        case "org_analysis":
          await this.runOrgAnalysis();
          break;
        case "health_check":
          await this.runHealthCheck();
          break;
        case "exit":
          exit = true;
          break;
      }
    }

    console.log(
      chalk.cyan(
        "\nThank you for using the Autonomous Salesforce Development System!"
      )
    );
  }

  async checkServer() {
    try {
      const response = await fetch(
        `http://localhost:${this.serverPort}/health`
      );
      return response.ok;
    } catch {
      return false;
    }
  }

  async showMainMenu() {
    const { action } = await inquirer.prompt([
      {
        type: "list",
        name: "action",
        message: "What would you like to do?",
        choices: [
          { name: "🚀 Create New Development Task", value: "new_task" },
          { name: "📋 View Task History", value: "view_history" },
          { name: "🔍 Check Task Status", value: "check_status" },
          { name: "🎭 Run Demo", value: "run_demo" },
          { name: "📊 Analyze Org", value: "org_analysis" },
          { name: "❤️  Health Check", value: "health_check" },
          new inquirer.Separator(),
          { name: "🚪 Exit", value: "exit" }
        ]
      }
    ]);
    return action;
  }

  async createNewTask() {
    console.log(chalk.blue.bold("\n📝 Create New Development Task\n"));

    // Task type selection
    const { taskType } = await inquirer.prompt([
      {
        type: "list",
        name: "taskType",
        message: "Select task type:",
        choices: [
          { name: "Apex Class/Trigger", value: "apex" },
          { name: "Custom Field", value: "field" },
          { name: "Custom Object", value: "object" },
          { name: "Flow/Process Builder", value: "flow" },
          { name: "Lightning Web Component", value: "lwc" },
          { name: "Integration", value: "integration" },
          { name: "Other/Custom", value: "other" }
        ]
      }
    ]);

    // Get task description based on type
    let promptMessage = "Describe what you want to build:";
    let exampleText = "";

    switch (taskType) {
      case "apex":
        exampleText =
          'e.g., "Create a trigger on Account that updates related contacts when account status changes"';
        break;
      case "field":
        exampleText =
          'e.g., "Add a Priority_Score__c number field to the Account object"';
        break;
      case "flow":
        exampleText =
          'e.g., "Create a flow that sends an email when opportunity stage changes to Closed Won"';
        break;
      default:
        exampleText = "Describe your requirement in natural language";
    }

    const { description } = await inquirer.prompt([
      {
        type: "input",
        name: "description",
        message: promptMessage,
        suffix: chalk.gray(`\n  ${exampleText}\n  `),
        validate: (input) =>
          input.length > 10 || "Please provide a detailed description"
      }
    ]);

    // Additional options
    const { priority, autoDeploy, runTests } = await inquirer.prompt([
      {
        type: "list",
        name: "priority",
        message: "Task priority:",
        choices: ["low", "medium", "high"],
        default: "medium"
      },
      {
        type: "confirm",
        name: "autoDeploy",
        message: "Auto-deploy to sandbox?",
        default: true
      },
      {
        type: "confirm",
        name: "runTests",
        message: "Run automated tests after deployment?",
        default: true
      }
    ]);

    // Submit the task
    const spinner = ora("Submitting task to autonomous system...").start();

    try {
      const response = await fetch(`http://localhost:${this.serverPort}/task`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          description,
          priority,
          autoDeploy,
          taskType
        })
      });

      const result = await response.json();

      if (result.success) {
        spinner.succeed("Task submitted successfully!");

        // Store in history
        this.taskHistory.push({
          taskId: result.taskId,
          description,
          timestamp: new Date().toISOString()
        });

        // Display results
        console.log(chalk.green(`\n✅ Task ID: ${result.taskId}`));
        console.log(chalk.blue("\n📊 Task Analysis:"));
        console.log(`  Status: ${result.status}`);

        if (result.artifacts) {
          console.log(
            `  Generated: ${Object.keys(result.artifacts).join(", ")}`
          );
        }

        if (result.deploymentStatus && result.deploymentStatus.deployed) {
          console.log(chalk.green("\n✅ Deployment Status: SUCCESS"));

          if (result.deploymentStatus.testResults) {
            const tests = result.deploymentStatus.testResults;
            console.log(
              `  Tests: ${tests.testsPassed}/${tests.testsRun} passed`
            );
            console.log(`  Coverage: ${tests.coverage}%`);
          }
        }

        console.log(
          chalk.gray(`\nOutput saved to: ./output/${result.taskId}/`)
        );

        // Ask if user wants to view the generated code
        const { viewCode } = await inquirer.prompt([
          {
            type: "confirm",
            name: "viewCode",
            message: "Would you like to view the generated code?",
            default: false
          }
        ]);

        if (viewCode) {
          await this.displayGeneratedCode(result.taskId);
        }
      } else {
        spinner.fail("Task submission failed");
        console.error(chalk.red(`Error: ${result.error}`));
      }
    } catch (error) {
      spinner.fail("Failed to submit task");
      console.error(chalk.red(`Error: ${error.message}`));
    }

    await this.pause();
  }

  async viewTaskHistory() {
    console.log(chalk.blue.bold("\n📜 Task History\n"));

    if (this.taskHistory.length === 0) {
      console.log(chalk.gray("No tasks submitted in this session"));
    } else {
      this.taskHistory.forEach((task, index) => {
        console.log(chalk.cyan(`${index + 1}. ${task.taskId}`));
        console.log(`   ${task.description}`);
        console.log(chalk.gray(`   ${task.timestamp}\n`));
      });
    }

    await this.pause();
  }

  async checkTaskStatus() {
    const { taskId } = await inquirer.prompt([
      {
        type: "input",
        name: "taskId",
        message: "Enter Task ID:",
        validate: (input) =>
          input.startsWith("task-") || "Invalid task ID format"
      }
    ]);

    const spinner = ora("Checking task status...").start();

    try {
      const response = await fetch(
        `http://localhost:${this.serverPort}/task/${taskId}`
      );

      if (response.ok) {
        const status = await response.json();
        spinner.succeed("Task found");

        console.log(chalk.blue("\n📊 Task Status:"));
        console.log(`  ID: ${status.taskId}`);
        console.log(`  Description: ${status.description}`);
        console.log(`  Timestamp: ${status.timestamp}`);
        console.log(`  Status: ${status.deployment?.status || "Pending"}`);

        if (status.deployment?.testResults) {
          console.log(chalk.green("\n✅ Test Results:"));
          console.log(
            `  Tests Passed: ${status.deployment.testResults.passed}`
          );
          console.log(`  Coverage: ${status.deployment.testResults.coverage}%`);
        }
      } else {
        spinner.fail("Task not found");
      }
    } catch (error) {
      spinner.fail("Failed to check status");
      console.error(chalk.red(`Error: ${error.message}`));
    }

    await this.pause();
  }

  async runDemo() {
    console.log(chalk.blue.bold("\n🎭 Running Apex Improvement Demo\n"));
    console.log(
      chalk.gray("This will find and improve an Apex class autonomously...\n")
    );

    const { confirm } = await inquirer.prompt([
      {
        type: "confirm",
        name: "confirm",
        message: "Continue with demo?",
        default: true
      }
    ]);

    if (confirm) {
      const { exec } = await import("child_process");
      exec("npm run demo:apex-improvement", (error, stdout, stderr) => {
        if (error) {
          console.error(chalk.red("Demo failed:", error));
        } else {
          console.log(stdout);
        }
      });
    }

    await this.pause();
  }

  async runOrgAnalysis() {
    const spinner = ora("Analyzing Salesforce org...").start();

    try {
      const response = await fetch(
        `http://localhost:${this.serverPort}/analyze`
      );
      const analysis = await response.json();

      spinner.succeed("Org analysis complete");

      console.log(chalk.blue.bold("\n📊 Org Analysis Results:\n"));
      console.log(`  Custom Objects: ${analysis.summary.customObjects}`);
      console.log(`  Apex Classes: ${analysis.summary.apexClasses}`);
      console.log(`  Apex Triggers: ${analysis.summary.apexTriggers}`);
      console.log(`  Flows: ${analysis.summary.flows}`);
      console.log(`  Complexity: ${analysis.complexity.toUpperCase()}`);

      if (analysis.recommendations && analysis.recommendations.length > 0) {
        console.log(chalk.yellow("\n⚠️  Recommendations:"));
        analysis.recommendations.forEach((rec) => {
          console.log(`  • ${rec.message}`);
        });
      }
    } catch (error) {
      spinner.fail("Analysis failed");
      console.error(chalk.red(`Error: ${error.message}`));
    }

    await this.pause();
  }

  async runHealthCheck() {
    console.log(chalk.blue.bold("\n❤️  Running Health Check\n"));

    const { exec } = await import("child_process");
    exec("npm run health-check", (error, stdout, stderr) => {
      if (error) {
        console.error(chalk.red("Health check failed:", error));
      } else {
        console.log(stdout);
      }
    });

    await this.pause();
  }

  async displayGeneratedCode(taskId) {
    try {
      const outputDir = `./output/${taskId}`;
      const apexDir = `${outputDir}/apex`;

      if (await fs.pathExists(apexDir)) {
        const files = await fs.readdir(apexDir);

        if (files.length > 0) {
          console.log(chalk.blue.bold("\n📝 Generated Code:\n"));

          for (const file of files) {
            console.log(chalk.cyan(`File: ${file}`));
            console.log(chalk.gray("─".repeat(50)));
            const content = await fs.readFile(`${apexDir}/${file}`, "utf-8");
            console.log(content.substring(0, 500) + "...\n");
          }
        }
      }
    } catch (error) {
      console.error(chalk.red("Could not display code:", error.message));
    }
  }

  async pause() {
    await inquirer.prompt([
      {
        type: "input",
        name: "continue",
        message: chalk.gray("Press Enter to continue...")
      }
    ]);
  }
}

// Run the interactive CLI
const cli = new InteractiveCLI();
cli.run();
