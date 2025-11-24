// scripts/analyze-org.js - Analyze Salesforce org structure

import fetch from "node-fetch";
import chalk from "chalk";
import ora from "ora";

async function analyzeOrg() {
  const spinner = ora("Analyzing Salesforce org...").start();

  try {
    const response = await fetch("http://localhost:3000/analyze");

    if (!response.ok) {
      throw new Error("Server not running. Start with: npm run start");
    }

    const analysis = await response.json();
    spinner.succeed("Org analysis complete");

    console.log(chalk.blue.bold("\n📊 Org Analysis Results:\n"));
    console.log(chalk.gray("─".repeat(40)));
    console.log(`Custom Objects: ${analysis.summary.customObjects}`);
    console.log(`Apex Classes: ${analysis.summary.apexClasses}`);
    console.log(`Apex Triggers: ${analysis.summary.apexTriggers}`);
    console.log(`Flows: ${analysis.summary.flows}`);
    console.log(chalk.gray("─".repeat(40)));
    console.log(
      `Complexity: ${chalk.yellow(analysis.complexity.toUpperCase())}`
    );

    if (analysis.recommendations && analysis.recommendations.length > 0) {
      console.log(chalk.yellow.bold("\n⚠️  Recommendations:"));
      analysis.recommendations.forEach((rec) => {
        console.log(`  [${rec.priority.toUpperCase()}] ${rec.message}`);
      });
    }

    if (analysis.issues && analysis.issues.length > 0) {
      console.log(chalk.red.bold("\n❌ Issues Found:"));
      analysis.issues.forEach((issue) => {
        console.log(`  [${issue.severity.toUpperCase()}] ${issue.message}`);
      });
    }
  } catch (error) {
    spinner.fail("Analysis failed");
    console.error(chalk.red(`\nError: ${error.message}`));
    process.exit(1);
  }
}

analyzeOrg();
