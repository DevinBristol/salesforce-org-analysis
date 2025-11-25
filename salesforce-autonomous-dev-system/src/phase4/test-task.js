/**
 * Test script to submit a task directly to the orchestrator
 */

import 'dotenv/config';
import fs from 'fs/promises';
import path from 'path';
import { ClaudeCodeOrchestrator } from './claude-orchestrator.js';
import { ProgressReporter } from './progress-reporter.js';
import { MonitoringSystem } from './monitoring-system.js';

const sampleCode = `
/**
 * Utility class to handle Account trigger logic.
 */
public with sharing class AccountTriggerHelper {
    public static List<List<SObject>> processAccountTrigger(List<Account> accounts) {
        List<List<SObject>> returnLists = new List<List<SObject>>();
        Set<Id> accountIdsWithNameChange = new Set<Id>();

        // Handle before update/insert logic
        if (Trigger.isBefore && (Trigger.isUpdate || Trigger.isInsert)) {
            for (Account account : accounts) {
                if (account.Open_Opportunity_Count__c > 0) {
                    account.Stage__c = 'Active';
                }
            }
        }

        // Handle after update logic - potential SOQL in loop issue
        if (Trigger.isUpdate && Trigger.isAfter) {
            for (Account account : accounts) {
                Account oldAccount = (Account)Trigger.oldMap.get(account.Id);
                if (account.Name != oldAccount.Name) {
                    // Query inside loop - BAD PRACTICE
                    List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE AccountId = :account.Id];
                }
            }
        }

        return returnLists;
    }
}
`;

async function main() {
    console.log('='.repeat(60));
    console.log('Phase 4: Direct Task Test');
    console.log('='.repeat(60));
    console.log('');

    // Initialize components
    const monitoring = new MonitoringSystem({ logger: console });
    const progressReporter = new ProgressReporter({ logger: console });

    const orchestrator = new ClaudeCodeOrchestrator({
        logger: console,
        monitoring,
        progressReporter,
        maxInstances: 1,
        workspaceRoot: 'C:/tmp/claude-workspace'
    });

    console.log('Submitting analysis task...');
    console.log('');

    try {
        const taskId = await orchestrator.submitTask({
            type: 'analysis',
            prompt: `Analyze this Apex code for:
1. Security vulnerabilities (SOQL injection, etc)
2. Performance issues (SOQL in loops, governor limits)
3. Best practices violations

Code to analyze:
\`\`\`apex
${sampleCode}
\`\`\`

Provide a brief summary of issues found.`,
            context: {
                files: {
                    'AccountTriggerHelper.cls': sampleCode
                }
            },
            priority: 'high'
        });

        console.log(`Task submitted: ${taskId}`);
        console.log('');
        console.log('Waiting for completion (timeout: 2 minutes)...');
        console.log('');

        // Poll for status
        const startTime = Date.now();
        const timeout = 2 * 60 * 1000; // 2 minutes

        while (Date.now() - startTime < timeout) {
            const status = orchestrator.getTaskStatus(taskId);

            if (!status) {
                console.log('Task not found!');
                break;
            }

            if (status.status === 'completed') {
                console.log('');
                console.log('='.repeat(60));
                console.log('Task Completed!');
                console.log('='.repeat(60));
                console.log('');
                console.log('Result:', JSON.stringify(status.result, null, 2).substring(0, 2000));
                break;
            }

            if (status.status === 'failed') {
                console.log('');
                console.log('Task Failed:', status.error);
                break;
            }

            // Wait 5 seconds before checking again
            await new Promise(resolve => setTimeout(resolve, 5000));
        }

    } catch (error) {
        console.error('Error:', error.message);
    } finally {
        await orchestrator.shutdown();
        await monitoring.shutdown();
        await progressReporter.shutdown();
    }
}

main().catch(console.error);
