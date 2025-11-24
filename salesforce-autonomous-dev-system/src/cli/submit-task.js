// src/cli/submit-task.js - CLI for submitting development tasks

import fetch from "node-fetch";
import chalk from "chalk";
import ora from "ora";
import { program } from "commander";

program
  .description("Submit a development task to the autonomous system")
  .argument("<description>", "Task description in natural language")
  .option(
    "-p, --priority <priority>",
    "Task priority (low, medium, high)",
    "medium"
  )
  .option("-d, --deploy", "Auto-deploy to sandbox", false)
  .option("--port <port>", "Server port", "3000")
  .parse(process.argv);

const options = program.opts();
const [description] = program.args;

if (!description) {
  console.error(chalk.red("Error: Task description is required"));
  console.log('Usage: npm run task "Create a custom field on Account"');
  process.exit(1);
}

async function submitTask() {
  const spinner = ora("Submitting task to autonomous system...").start();

  try {
    // Check if server is running
    const healthResponse = await fetch(
      `http://localhost:${options.port}/health`
    );
    if (!healthResponse.ok) {
      throw new Error(
        "Autonomous system is not running. Start it with: npm run start"
      );
    }

    // Submit the task
    const response = await fetch(`http://localhost:${options.port}/task`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        description,
        priority: options.priority,
        autoDeploy: options.deploy
      })
    });

    const result = await response.json();

    if (result.success) {
      spinner.succeed("Task submitted successfully");

      console.log(chalk.green(`\n✓ Task ID: ${result.taskId}`));
      console.log(chalk.blue("\nTask Analysis:"));
      console.log(`  Status: ${result.status}`);

      if (result.artifacts) {
        console.log(`  Generated: ${Object.keys(result.artifacts).join(", ")}`);
      }

      if (result.deploymentStatus) {
        console.log(chalk.blue("\nDeployment:"));
        console.log(
          `  Deployed: ${result.deploymentStatus.deployed ? "YES" : "NO"}`
        );

        if (result.deploymentStatus.testResults) {
          const tests = result.deploymentStatus.testResults;
          console.log(`  Tests: ${tests.testsPassed}/${tests.testsRun} passed`);
          console.log(`  Coverage: ${tests.coverage}%`);
        }
      }

      console.log(
        chalk.gray(
          `\nView details: http://localhost:${options.port}/task/${result.taskId}`
        )
      );
      console.log(chalk.gray(`Output saved to: ./output/${result.taskId}/`));
    } else {
      spinner.fail("Task submission failed");
      console.error(chalk.red(`Error: ${result.error}`));
    }
  } catch (error) {
    spinner.fail("Failed to submit task");

    if (error.message.includes("ECONNREFUSED")) {
      console.error(
        chalk.red("\nError: Cannot connect to the autonomous system")
      );
      console.log(
        chalk.yellow("Please start the system first with: npm run start")
      );
    } else {
      console.error(chalk.red(`\nError: ${error.message}`));
    }

    process.exit(1);
  }
}

// Run the task submission
console.log(chalk.cyan.bold("\nAutonomous Salesforce Development System"));
console.log(chalk.gray("─".repeat(45)));
console.log(`Task: ${description}`);
console.log(`Priority: ${options.priority}`);
console.log(`Auto-deploy: ${options.deploy}`);
console.log(chalk.gray("─".repeat(45)));

submitTask();
