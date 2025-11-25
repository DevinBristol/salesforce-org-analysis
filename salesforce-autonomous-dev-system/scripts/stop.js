// scripts/stop.js - Gracefully stop the autonomous system

import fetch from 'node-fetch';
import chalk from 'chalk';
import ora from 'ora';

async function stopSystem() {
    console.log(chalk.yellow.bold('\n🛑 Stopping Autonomous System\n'));
    
    const spinner = ora('Shutting down server...').start();
    
    try {
        // Try to gracefully shutdown
        const response = await fetch('http://localhost:3000/shutdown', {
            method: 'POST',
            timeout: 5000
        });
        
        if (response.ok) {
            spinner.succeed('Server shutdown gracefully');
        } else {
            spinner.warn('Server may still be running - check processes');
        }
    } catch (error) {
        // Server might already be stopped
        if (error.code === 'ECONNREFUSED') {
            spinner.succeed('Server is not running');
        } else {
            spinner.warn('Could not connect to server - it may already be stopped');
        }
    }
    
    console.log(chalk.gray('\nTo ensure all processes are stopped:'));
    console.log(chalk.gray('  Windows: Close all Node.js windows or use Task Manager'));
    console.log(chalk.gray('  Mac/Linux: killall node'));
}

stopSystem();
