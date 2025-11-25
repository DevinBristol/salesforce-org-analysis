// scripts/generate-changeset.js - Generate changeset for production deployment

import fs from 'fs-extra';
import path from 'path';
import chalk from 'chalk';
import ora from 'ora';
import inquirer from 'inquirer';

async function generateChangeset() {
    console.log(chalk.blue.bold('\n📦 Generate Changeset for Production\n'));

    try {
        // Find recent deployments
        const deploymentsDir = './deployments';
        const historyPath = path.join(deploymentsDir, 'history.json');
        
        if (!await fs.pathExists(historyPath)) {
            console.log(chalk.yellow('No deployment history found.'));
            console.log('Deploy to sandbox first using: npm run task "your task"');
            return;
        }

        const history = await fs.readJson(historyPath);
        
        if (history.length === 0) {
            console.log(chalk.yellow('No deployments found in history.'));
            return;
        }

        // Show recent successful deployments
        const successful = history.filter(d => d.success);
        
        if (successful.length === 0) {
            console.log(chalk.yellow('No successful deployments found.'));
            return;
        }

        console.log(chalk.cyan('Recent successful deployments:\n'));
        successful.slice(-5).forEach((deployment, index) => {
            console.log(`${index + 1}. ${deployment.deploymentId}`);
            console.log(`   Target: ${deployment.targetOrg}`);
            console.log(`   Time: ${deployment.timestamp}`);
            console.log(`   Artifacts: ${deployment.artifacts.join(', ')}\n`);
        });

        const { selectedIndex } = await inquirer.prompt([
            {
                type: 'number',
                name: 'selectedIndex',
                message: 'Select deployment to create changeset from (enter number):',
                validate: (input) => input > 0 && input <= successful.length
            }
        ]);

        const selected = successful[selectedIndex - 1];
        const spinner = ora('Generating changeset...').start();

        // Create changeset directory
        const changesetDir = path.join('./output', 'changeset');
        await fs.ensureDir(changesetDir);

        // Generate package.xml
        const packageXml = `<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>*</members>
        <name>ApexClass</name>
    </types>
    <types>
        <members>*</members>
        <name>CustomObject</name>
    </types>
    <version>${process.env.SF_API_VERSION || '60.0'}</version>
</Package>`;

        await fs.writeFile(path.join(changesetDir, 'package.xml'), packageXml);

        // Generate manifest
        const manifest = {
            deploymentId: selected.deploymentId,
            sourceOrg: selected.targetOrg,
            targetOrg: 'production',
            artifacts: selected.artifacts,
            generatedAt: new Date().toISOString(),
            status: 'ready',
            approvalRequired: true
        };

        await fs.writeJson(path.join(changesetDir, 'manifest.json'), manifest, { spaces: 2 });

        spinner.succeed('Changeset generated');

        console.log(chalk.green('\n✓ Changeset ready for production deployment'));
        console.log(chalk.gray(`Location: ${changesetDir}`));
        console.log(chalk.yellow('\n⚠️  Manual Review Required:'));
        console.log('1. Review the changeset in: ./output/changeset/');
        console.log('2. Get approval from stakeholders');
        console.log('3. Deploy using: npm run deploy:production');

    } catch (error) {
        console.error(chalk.red('Failed to generate changeset:'), error.message);
        process.exit(1);
    }
}

generateChangeset();
