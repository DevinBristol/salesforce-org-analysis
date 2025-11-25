// demos/apex-improvement.js - Autonomous Apex Improvement Demo

import { Anthropic } from '@anthropic-ai/sdk';
import dotenv from 'dotenv';
import chalk from 'chalk';
import ora from 'ora';
import fs from 'fs-extra';
import path from 'path';
import winston from 'winston';
import { SalesforceManager } from '../src/services/salesforce-manager.js';
import { AICodeGenerator } from '../src/services/ai-code-generator.js';
import { DeploymentPipeline } from '../src/services/deployment-pipeline.js';
import { OrgAnalyzer } from '../src/services/org-analyzer.js';

dotenv.config();

// Configure logging
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple()
    ),
    transports: [
        new winston.transports.File({ filename: 'logs/demo.log' }),
        new winston.transports.Console()
    ]
});

class ApexImprovementDemo {
    constructor() {
        this.anthropic = new Anthropic({
            apiKey: process.env.CLAUDE_API_KEY
        });
        this.salesforceManager = new SalesforceManager(logger);
        this.aiCodeGenerator = new AICodeGenerator(this.anthropic, logger);
        this.deploymentPipeline = new DeploymentPipeline(logger);
        this.orgAnalyzer = new OrgAnalyzer(logger);
    }

    async run() {
        console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════╗'));
        console.log(chalk.cyan.bold('║     Autonomous Apex Improvement Demo                ║'));
        console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════╝\n'));

        try {
            // Step 1: Connect to Salesforce
            const connectSpinner = ora('Connecting to Salesforce...').start();
            await this.salesforceManager.connect();
            connectSpinner.succeed('Connected to Salesforce');

            // Step 2: Fetch org metadata
            const metadataSpinner = ora('Fetching org metadata...').start();
            await this.salesforceManager.fetchMetadata(['ApexClass']);
            metadataSpinner.succeed('Metadata fetched');

            // Step 3: Find improvement targets
            const scanSpinner = ora('Scanning for improvement targets...').start();
            const targets = await this.findImprovementTargets();
            scanSpinner.succeed(`Found ${targets.length} potential targets`);

            if (targets.length === 0) {
                console.log(chalk.yellow('\nNo suitable Apex classes found for improvement.'));
                console.log('Creating a sample class for demonstration...');
                await this.createSampleClass();
                // Re-scan
                const newTargets = await this.findImprovementTargets();
                if (newTargets.length > 0) {
                    targets.push(...newTargets);
                }
            }

            // Step 4: Select a low-risk target
            const selectedTarget = targets.find(t => t.riskLevel === 'low') || targets[0];
            
            if (!selectedTarget) {
                throw new Error('No improvement targets available');
            }

            console.log(chalk.green(`\n✓ Selected target: ${selectedTarget.className}`));
            console.log(chalk.gray(`  Risk Level: ${selectedTarget.riskLevel}`));
            console.log(chalk.gray(`  Score: ${selectedTarget.score}`));
            console.log(chalk.gray(`  Reasons: ${selectedTarget.reasons.join(', ')}`));

            // Step 5: Fetch the class content
            const fetchSpinner = ora(`Fetching ${selectedTarget.className}...`).start();
            const classContent = await this.salesforceManager.getApexClassContent(selectedTarget.className);
            fetchSpinner.succeed('Class content retrieved');

            // Step 6: Generate improvements
            const improveSpinner = ora('Analyzing and improving code...').start();
            const improvement = await this.aiCodeGenerator.generateApexImprovement(
                classContent,
                selectedTarget.className
            );
            improveSpinner.succeed('Improvements generated');

            console.log(chalk.blue('\nImprovements Made:'));
            console.log(chalk.gray(improvement.improvements));

            // Step 7: Prepare deployment artifacts
            const artifacts = {
                apex: {
                    [`${selectedTarget.className}.cls`]: improvement.improvedCode
                }
            };

            // Step 8: Deploy to sandbox
            const devSandbox = process.env.DEV_SANDBOX || 'Devin1';
            const deploySpinner = ora(`Deploying to ${devSandbox}...`).start();
            const deploymentResult = await this.deploymentPipeline.deployToSandbox(
                artifacts,
                devSandbox
            );
            
            if (deploymentResult.deployed) {
                deploySpinner.succeed('Successfully deployed to sandbox');
                
                // Step 9: Run tests
                if (deploymentResult.testResults) {
                    console.log(chalk.green('\n✓ Test Results:'));
                    console.log(`  Tests Passed: ${deploymentResult.testResults.testsPassed}/${deploymentResult.testResults.testsRun}`);
                    console.log(`  Code Coverage: ${deploymentResult.testResults.coverage}%`);
                }
            } else {
                deploySpinner.fail('Deployment failed');
                console.log(chalk.red(`Error: ${deploymentResult.error}`));
            }

            // Step 10: Generate report
            await this.generateReport({
                target: selectedTarget,
                originalCode: classContent,
                improvedCode: improvement.improvedCode,
                improvements: improvement.improvements,
                deploymentResult
            });

            console.log(chalk.green.bold('\n✓ Demo completed successfully!'));
            console.log(chalk.gray(`Report saved to: ./output/demo-apex-improvement/report.md`));

        } catch (error) {
            console.error(chalk.red('\n✗ Demo failed:'), error.message);
            logger.error('Demo error:', error);
            process.exit(1);
        }
    }

    async findImprovementTargets() {
        // Use org analyzer to find targets
        const targets = await this.orgAnalyzer.findImprovementTargets();

        // If no targets from analyzer, create mock targets
        if (targets.length === 0) {
            // Look for any Apex class we can use
            const classes = await this.salesforceManager.getApexClasses();
            if (classes && classes.length > 0) {
                // Filter out test classes and managed package classes (those with namespace prefixes like sf_devops__)
                const nonTestClasses = classes.filter(c =>
                    !c.fullName.includes('Test') &&
                    !c.fullName.includes('__') // Skip managed package classes with namespaces
                );
                if (nonTestClasses.length > 0) {
                    return [{
                        className: nonTestClasses[0].fullName,
                        score: 5,
                        riskLevel: 'low',
                        reasons: ['Selected for demo'],
                        lastModified: nonTestClasses[0].lastModifiedDate
                    }];
                }
            }
        }

        return targets;
    }

    async createSampleClass() {
        // Create a simple Apex class for demonstration
        const sampleClass = `public class AccountHelper {
    public static void updateAccountRating(List<Account> accounts) {
        for(Account acc : accounts) {
            if(acc.AnnualRevenue > 1000000) {
                acc.Rating = 'Hot';
            }
        }
        update accounts;
    }
    
    public static List<Account> getHighValueAccounts() {
        return [SELECT Id, Name FROM Account WHERE AnnualRevenue > 500000];
    }
}`;

        const artifacts = {
            apex: {
                'AccountHelper.cls': sampleClass
            }
        };

        const devSandbox = process.env.DEV_SANDBOX || 'Devin1';
        logger.info('Creating sample class for demo');
        await this.deploymentPipeline.deployToSandbox(artifacts, devSandbox);
    }

    async generateReport(data) {
        const reportDir = './output/demo-apex-improvement';
        await fs.ensureDir(reportDir);

        // Generate simple diff highlighting
        const diff = this.generateSimpleDiff(data.originalCode, data.improvedCode);
        const changeCount = this.countChanges(data.originalCode, data.improvedCode);

        const report = `# Apex Improvement Demo Report

## Target Class
- **Name:** ${data.target.className}
- **Risk Level:** ${data.target.riskLevel}
- **Improvement Score:** ${data.target.score}
- **Reasons for Selection:** ${data.target.reasons.join(', ')}

## Summary
- **Total Changes:** ${changeCount.added} lines added, ${changeCount.removed} lines removed, ${changeCount.modified} lines modified
- **Change Percentage:** ${changeCount.percentage}%

## Improvements Applied
${data.improvements}

## Changes Made (Diff View)

${diff}

## Side-by-Side Comparison

### Original Code
\`\`\`apex
${data.originalCode}
\`\`\`

### Improved Code (with IMPROVED comments showing changes)
\`\`\`apex
${data.improvedCode}
\`\`\`

## Deployment Results
- **Status:** ${data.deploymentResult.deployed ? 'SUCCESS' : 'FAILED'}
- **Target Org:** ${process.env.DEV_SANDBOX || 'dev-sandbox'}
- **Deployment ID:** ${data.deploymentResult.deploymentId}

${data.deploymentResult.testResults ? `
## Test Results
- **Tests Passed:** ${data.deploymentResult.testResults.testsPassed}/${data.deploymentResult.testResults.testsRun}
- **Code Coverage:** ${data.deploymentResult.testResults.coverage}%
` : ''}

## Timestamp
Generated: ${new Date().toISOString()}

## Next Steps
1. Review the improved code in ${process.env.DEV_SANDBOX || 'Devin1'} sandbox
2. Look for lines marked with "// IMPROVED:" comments
3. Run additional manual tests if needed
4. Promote to ${process.env.UAT_SANDBOX || 'dev-sandbox'} for UAT
5. Deploy to production after approval
`;

        await fs.writeFile(path.join(reportDir, 'report.md'), report);
        await fs.writeJson(path.join(reportDir, 'data.json'), data, { spaces: 2 });

        logger.info('Report generated');
    }

    generateSimpleDiff(original, improved) {
        const origLines = original.split('\n');
        const improvLines = improved.split('\n');

        let diff = '```diff\n';
        const maxLen = Math.max(origLines.length, improvLines.length);

        for (let i = 0; i < maxLen; i++) {
            const origLine = origLines[i] || '';
            const improvLine = improvLines[i] || '';

            if (origLine !== improvLine) {
                if (origLine && !improvLines.includes(origLine)) {
                    diff += `- ${origLine}\n`;
                }
                if (improvLine && !origLines.includes(improvLine)) {
                    diff += `+ ${improvLine}\n`;
                }
            }
        }

        diff += '```\n';
        return diff.length > 20 ? diff : '*(No changes detected - code may be identical)*';
    }

    countChanges(original, improved) {
        const origLines = original.split('\n');
        const improvLines = improved.split('\n');

        let added = 0, removed = 0, modified = 0;

        improvLines.forEach(line => {
            if (!origLines.includes(line) && line.trim()) {
                added++;
            }
        });

        origLines.forEach(line => {
            if (!improvLines.includes(line) && line.trim()) {
                removed++;
            }
        });

        const totalLines = origLines.length;
        const changedLines = added + removed;
        const percentage = totalLines > 0 ? ((changedLines / totalLines) * 100).toFixed(1) : 0;

        return { added, removed, modified, percentage };
    }
}

// Run the demo
const demo = new ApexImprovementDemo();
demo.run();
