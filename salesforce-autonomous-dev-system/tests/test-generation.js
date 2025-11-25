// tests/test-generation.js - Test the code generation capability

import { Anthropic } from '@anthropic-ai/sdk';
import dotenv from 'dotenv';
import chalk from 'chalk';
import { AICodeGenerator } from '../src/services/ai-code-generator.js';
import winston from 'winston';

dotenv.config();

const logger = winston.createLogger({
    level: 'info',
    format: winston.format.simple(),
    transports: [new winston.transports.Console()]
});

async function testGeneration() {
    console.log(chalk.blue.bold('\n🧪 Testing Code Generation\n'));

    const anthropic = new Anthropic({
        apiKey: process.env.CLAUDE_API_KEY
    });

    const generator = new AICodeGenerator(anthropic, logger);

    const testTask = {
        taskId: 'test-' + Date.now(),
        type: 'field',
        description: 'Create a Priority_Score__c number field on Account',
        affectedObjects: ['Account']
    };

    const testOrgContext = {
        objects: {
            Account: {
                name: 'Account',
                fields: ['Name', 'Type', 'Industry']
            }
        }
    };

    try {
        console.log('Generating code for test task...');
        const artifacts = await generator.generate({
            task: testTask,
            orgContext: testOrgContext,
            priority: 'low'
        });

        console.log(chalk.green('✓ Code generation successful'));
        console.log('Generated artifacts:', Object.keys(artifacts));
        
        return true;
    } catch (error) {
        console.error(chalk.red('✗ Generation failed:'), error.message);
        return false;
    }
}

testGeneration().then(success => {
    process.exit(success ? 0 : 1);
});
