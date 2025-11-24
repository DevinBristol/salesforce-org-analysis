// scripts/health-check.js - System Health Check

import chalk from "chalk";
import ora from "ora";
import fs from "fs-extra";
import { exec } from "child_process";
import { promisify } from "util";
import fetch from "node-fetch";
import dotenv from "dotenv";

const execAsync = promisify(exec);
dotenv.config();

class HealthChecker {
  constructor() {
    this.checks = [];
    this.passed = 0;
    this.failed = 0;
  }

  async run() {
    console.log(
      chalk.cyan.bold(
        "\n╔══════════════════════════════════════════════════════╗"
      )
    );
    console.log(
      chalk.cyan.bold("║     System Health Check                             ║")
    );
    console.log(
      chalk.cyan.bold(
        "╚══════════════════════════════════════════════════════╝\n"
      )
    );

    // Run all health checks
    await this.checkEnvironmentVariables();
    await this.checkNodeVersion();
    await this.checkNpmPackages();
    await this.checkSalesforceCLI();
    await this.checkDirectoryStructure();
    await this.checkSalesforceAuth();
    await this.checkServerStatus();
    await this.checkAIConnection();

    // Display results
    this.displayResults();
  }

  async checkEnvironmentVariables() {
    const spinner = ora("Checking environment variables...").start();
    const required = ["CLAUDE_API_KEY", "SF_USERNAME", "SF_LOGIN_URL"];
    const missing = [];

    for (const key of required) {
      if (!process.env[key]) {
        missing.push(key);
      }
    }

    if (missing.length === 0) {
      spinner.succeed("Environment variables configured");
      this.passed++;
    } else {
      spinner.fail(`Missing environment variables: ${missing.join(", ")}`);
      this.failed++;
    }
  }

  async checkNodeVersion() {
    const spinner = ora("Checking Node.js version...").start();
    try {
      const { stdout } = await execAsync("node --version");
      const version = stdout.trim();
      const major = parseInt(version.split(".")[0].replace("v", ""));

      if (major >= 18) {
        spinner.succeed(`Node.js ${version} ✓`);
        this.passed++;
      } else {
        spinner.fail(`Node.js ${version} (requires v18+)`);
        this.failed++;
      }
    } catch (error) {
      spinner.fail("Node.js not found");
      this.failed++;
    }
  }

  async checkNpmPackages() {
    const spinner = ora("Checking npm packages...").start();
    try {
      const packageJson = await fs.readJson("./package.json");
      const nodeModulesExists = await fs.pathExists("./node_modules");

      if (nodeModulesExists) {
        spinner.succeed("NPM packages installed");
        this.passed++;
      } else {
        spinner.fail("NPM packages not installed (run: npm install)");
        this.failed++;
      }
    } catch (error) {
      spinner.fail("package.json not found");
      this.failed++;
    }
  }

  async checkSalesforceCLI() {
    const spinner = ora("Checking Salesforce CLI...").start();
    try {
      const { stdout } = await execAsync("sf --version");
      spinner.succeed(`Salesforce CLI installed: ${stdout.trim()}`);
      this.passed++;
    } catch (error) {
      spinner.fail(
        "Salesforce CLI not found (install: npm install -g @salesforce/cli)"
      );
      this.failed++;
    }
  }

  async checkDirectoryStructure() {
    const spinner = ora("Checking directory structure...").start();
    const requiredDirs = ["./logs", "./metadata", "./output", "./src"];
    const missing = [];

    for (const dir of requiredDirs) {
      if (!(await fs.pathExists(dir))) {
        missing.push(dir);
      }
    }

    if (missing.length === 0) {
      spinner.succeed("Directory structure intact");
      this.passed++;
    } else {
      spinner.fail(`Missing directories: ${missing.join(", ")}`);
      this.failed++;
    }
  }

  async checkSalesforceAuth() {
    const spinner = ora("Checking Salesforce authentication...").start();
    try {
      const { stdout } = await execAsync("sf org list --json");
      const result = JSON.parse(stdout);

      const hasProduction = result.result.nonScratchOrgs?.some(
        (org) => org.alias === "production" || org.isDefaultUsername
      );
      const hasSandbox = result.result.nonScratchOrgs?.some(
        (org) => org.alias === "dev-sandbox"
      );

      if (hasProduction || hasSandbox) {
        spinner.succeed("Salesforce orgs authenticated");
        this.passed++;
      } else {
        spinner.warn(
          "No Salesforce orgs authenticated (run: sf org login web)"
        );
        this.failed++;
      }
    } catch (error) {
      spinner.fail("Failed to check Salesforce authentication");
      this.failed++;
    }
  }

  async checkServerStatus() {
    const spinner = ora("Checking server status...").start();
    try {
      const response = await fetch("http://localhost:3000/health", {
        timeout: 2000
      });

      if (response.ok) {
        const data = await response.json();
        spinner.succeed(`Server running (status: ${data.status})`);
        this.passed++;
      } else {
        spinner.warn("Server not responding properly");
        this.failed++;
      }
    } catch (error) {
      spinner.warn("Server not running (start with: npm run start)");
      // Not counting as failure since server might not be started yet
    }
  }

  async checkAIConnection() {
    const spinner = ora("Checking AI service connection...").start();

    if (!process.env.CLAUDE_API_KEY) {
      spinner.fail("Claude API key not configured");
      this.failed++;
      return;
    }

    // Just check if the key looks valid (basic format check)
    if (process.env.CLAUDE_API_KEY.startsWith("sk-ant-")) {
      spinner.succeed("Claude API key configured");
      this.passed++;
    } else {
      spinner.warn("Claude API key may be invalid");
      this.passed++; // Still pass if key exists
    }
  }

  displayResults() {
    console.log(
      chalk.cyan.bold(
        "\n╔══════════════════════════════════════════════════════╗"
      )
    );
    console.log(
      chalk.cyan.bold("║     Health Check Results                            ║")
    );
    console.log(
      chalk.cyan.bold(
        "╚══════════════════════════════════════════════════════╝"
      )
    );

    const total = this.passed + this.failed;
    const percentage = Math.round((this.passed / total) * 100);

    console.log(chalk.green(`\n✓ Passed: ${this.passed}/${total}`));
    if (this.failed > 0) {
      console.log(chalk.red(`✗ Failed: ${this.failed}/${total}`));
    }

    console.log(chalk.blue(`\nHealth Score: ${percentage}%`));

    if (percentage === 100) {
      console.log(chalk.green.bold("\n🎉 System is fully operational!"));
    } else if (percentage >= 70) {
      console.log(
        chalk.yellow.bold("\n⚠️  System is operational with warnings")
      );
    } else {
      console.log(chalk.red.bold("\n❌ System needs configuration"));
      console.log(chalk.gray('\nRun "npm run init-system" to complete setup'));
    }

    process.exit(this.failed > 0 ? 1 : 0);
  }
}

// Run health check
const checker = new HealthChecker();
checker.run();
