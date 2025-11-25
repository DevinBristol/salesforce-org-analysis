// scripts/setup.js - Cross-platform setup script

import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs-extra';
import chalk from 'chalk';
import ora from 'ora';
import path from 'path';

const execAsync = promisify(exec);

class Setup {
    async run() {
        console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════╗'));
        console.log(chalk.cyan.bold('║   Autonomous Salesforce Development System Setup    ║'));
        console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════╝\n'));

        try {
            // Check Node version
            await this.checkNodeVersion();
            
            // Install Salesforce CLI
            await this.installSalesforceCLI();
            
            // Create directories
            await this.createDirectories();
            
            // Setup environment file
            await this.setupEnvironment();
            
            console.log(chalk.green.bold('\n✓ Setup complete!'));
            console.log(chalk.gray('\nNext steps:'));
            console.log(chalk.gray('1. Edit .env file with your API keys'));
            console.log(chalk.gray('2. Run: npm run init-system'));
            console.log(chalk.gray('3. Start the system: npm run start'));
            
        } catch (error) {
            console.error(chalk.red('\nSetup failed:'), error.message);
            process.exit(1);
        }
    }

    async checkNodeVersion() {
        const spinner = ora('Checking Node.js version...').start();
        const { stdout } = await execAsync('node --version');
        const version = stdout.trim();
        const major = parseInt(version.split('.')[0].replace('v', ''));
        
        if (major >= 18) {
            spinner.succeed(`Node.js ${version} ✓`);
        } else {
            spinner.fail(`Node.js ${version} (requires v18+)`);
            throw new Error('Please upgrade Node.js to version 18 or higher');
        }
    }

    async installSalesforceCLI() {
        const spinner = ora('Checking Salesforce CLI...').start();
        try {
            await execAsync('sf --version');
            spinner.succeed('Salesforce CLI already installed');
        } catch {
            spinner.text = 'Installing Salesforce CLI...';
            await execAsync('npm install -g @salesforce/cli@latest');
            spinner.succeed('Salesforce CLI installed');
        }
    }

    async createDirectories() {
        const spinner = ora('Creating directory structure...').start();
        const dirs = ['logs', 'metadata', 'output', 'deployments', 'analysis', 'temp', 'cache'];
        
        for (const dir of dirs) {
            await fs.ensureDir(dir);
        }
        
        spinner.succeed('Directory structure created');
    }

    async setupEnvironment() {
        if (!await fs.pathExists('.env')) {
            const spinner = ora('Creating .env file...').start();
            await fs.copy('.env.template', '.env');
            spinner.succeed('.env file created - please add your API keys');
        }
    }
}

const setup = new Setup();
setup.run();
