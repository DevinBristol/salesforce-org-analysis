// scripts/deploy-production.js - Deploy to production with safety checks

import fs from "fs-extra";
import path from "path";
import chalk from "chalk";
import ora from "ora";
import inquirer from "inquirer";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

async function deployToProduction() {
  console.log(chalk.red.bold("\n⚠️  PRODUCTION DEPLOYMENT\n"));
  console.log(
    chalk.yellow("This will deploy changes to your PRODUCTION Salesforce org.")
  );
  console.log(chalk.yellow("This action cannot be easily undone.\n"));

  try {
    // Check for changeset
    const changesetPath = "./output/changeset/manifest.json";

    if (!(await fs.pathExists(changesetPath))) {
      console.log(chalk.red("No changeset found."));
      console.log("Generate a changeset first: npm run generate-changeset");
      return;
    }

    const manifest = await fs.readJson(changesetPath);

    console.log(chalk.cyan("Changeset Details:"));
    console.log(`  Deployment ID: ${manifest.deploymentId}`);
    console.log(`  Source: ${manifest.sourceOrg}`);
    console.log(`  Target: ${chalk.red.bold("PRODUCTION")}`);
    console.log(`  Artifacts: ${manifest.artifacts.join(", ")}`);
    console.log(`  Generated: ${manifest.generatedAt}\n`);

    // Multiple confirmation steps for production
    const { confirm1 } = await inquirer.prompt([
      {
        type: "confirm",
        name: "confirm1",
        message: "Have you reviewed and tested these changes in sandbox?",
        default: false
      }
    ]);

    if (!confirm1) {
      console.log(chalk.yellow("Please test in sandbox first."));
      return;
    }

    const { confirm2 } = await inquirer.prompt([
      {
        type: "confirm",
        name: "confirm2",
        message: "Do you have approval from stakeholders?",
        default: false
      }
    ]);

    if (!confirm2) {
      console.log(
        chalk.yellow("Please get approval before deploying to production.")
      );
      return;
    }

    const { confirmFinal } = await inquirer.prompt([
      {
        type: "input",
        name: "confirmFinal",
        message: 'Type "DEPLOY TO PRODUCTION" to confirm:',
        validate: (input) =>
          input === "DEPLOY TO PRODUCTION" ||
          "Type exactly: DEPLOY TO PRODUCTION"
      }
    ]);

    // Run validation first
    const validateSpinner = ora(
      "Running validation against production..."
    ).start();

    try {
      const { stdout: valOutput } = await execAsync(
        "sf project deploy validate --source-dir ./output/changeset --target-org production --json"
      );

      const valResult = JSON.parse(valOutput);

      if (valResult.result.status === "Succeeded") {
        validateSpinner.succeed("Validation passed");
      } else {
        validateSpinner.fail("Validation failed");
        console.log(chalk.red("Cannot deploy - validation failed"));
        return;
      }
    } catch (error) {
      validateSpinner.fail("Validation failed");
      console.error(chalk.red("Validation error:"), error.message);
      return;
    }

    // Actual deployment
    const deploySpinner = ora("Deploying to production...").start();

    try {
      const { stdout } = await execAsync(
        "sf project deploy start --source-dir ./output/changeset --target-org production --json"
      );

      const result = JSON.parse(stdout);

      if (result.result.status === "Succeeded") {
        deploySpinner.succeed("Successfully deployed to production!");

        // Log deployment
        const log = {
          timestamp: new Date().toISOString(),
          deploymentId: manifest.deploymentId,
          status: "success",
          deployedBy: process.env.SF_USERNAME,
          artifacts: manifest.artifacts
        };

        const logPath = "./deployments/production-log.json";
        const existingLog = (await fs.pathExists(logPath))
          ? await fs.readJson(logPath)
          : [];
        existingLog.push(log);
        await fs.writeJson(logPath, existingLog, { spaces: 2 });

        console.log(chalk.green.bold("\n✅ Production deployment complete!"));
        console.log(
          chalk.gray("Deployment logged to: ./deployments/production-log.json")
        );
      } else {
        deploySpinner.fail("Deployment failed");
        console.log(chalk.red("Status:"), result.result.status);
      }
    } catch (error) {
      deploySpinner.fail("Deployment failed");
      console.error(chalk.red("Deployment error:"), error.message);

      // Offer rollback option
      const { rollback } = await inquirer.prompt([
        {
          type: "confirm",
          name: "rollback",
          message: "Would you like to rollback this deployment?",
          default: true
        }
      ]);

      if (rollback) {
        console.log(
          chalk.yellow(
            "Please use Salesforce Setup UI to rollback the deployment."
          )
        );
      }
    }
  } catch (error) {
    console.error(chalk.red("Production deployment error:"), error.message);
    process.exit(1);
  }
}

// Run deployment with final warning
console.log(chalk.red("═".repeat(60)));
console.log(chalk.red.bold("         ⚠️  PRODUCTION DEPLOYMENT WARNING ⚠️"));
console.log(chalk.red("═".repeat(60)));

deployToProduction();
