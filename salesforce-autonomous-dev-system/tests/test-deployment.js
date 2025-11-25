// tests/test-deployment.js - Test the deployment capability

import dotenv from 'dotenv';
import chalk from 'chalk';
import winston from 'winston';
import { DeploymentPipeline } from '../src/services/deployment-pipeline.js';

dotenv.config();

const logger = winston.createLogger({
    level: 'info',
    format: winston.format.simple(),
    transports: [new winston.transports.Console()]
});

async function testDeployment() {
    console.log(chalk.blue.bold('\n🚀 Testing Deployment Pipeline\n'));

    const pipeline = new DeploymentPipeline(logger);

    // Create a simple test artifact
    const testArtifacts = {
        apex: {
            'TestHelper.cls': `public class TestHelper {
    public static String getTestMessage() {
        return 'Deployment test successful';
    }
}`
        }
    };

    try {
        console.log('Testing deployment validation...');
        
        // Just test the package creation, not actual deployment
        const deploymentDir = './temp/test-deploy-' + Date.now();
        await pipeline.createDeploymentPackage(testArtifacts, deploymentDir);
        
        console.log(chalk.green('✓ Deployment package created successfully'));
        
        // Clean up
        const fs = await import('fs-extra');
        await fs.remove(deploymentDir);
        
        return true;
    } catch (error) {
        console.error(chalk.red('✗ Deployment test failed:'), error.message);
        return false;
    }
}

testDeployment().then(success => {
    process.exit(success ? 0 : 1);
});
