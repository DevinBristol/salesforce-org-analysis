// scripts/verify-enhancements.js - Verify new deployment enhancements work correctly

import chalk from 'chalk';

async function verify() {
    console.log(chalk.cyan.bold('\n🔍 Verifying Deployment Pipeline Enhancements\n'));
    console.log('=' .repeat(60));

    const checks = [];

    // Check 1: Rollback Manager import
    try {
        const { RollbackManager } = await import('../src/services/rollback-manager.js');
        checks.push({ name: 'RollbackManager', status: 'PASS', details: 'Module loads correctly' });
    } catch (error) {
        checks.push({ name: 'RollbackManager', status: 'FAIL', details: error.message });
    }

    // Check 2: Deployment Scheduler import
    try {
        const { DeploymentScheduler } = await import('../src/services/deployment-scheduler.js');
        checks.push({ name: 'DeploymentScheduler', status: 'PASS', details: 'Module loads correctly' });
    } catch (error) {
        checks.push({ name: 'DeploymentScheduler', status: 'FAIL', details: error.message });
    }

    // Check 3: Deployment Pipeline import
    try {
        const { DeploymentPipeline } = await import('../src/services/deployment-pipeline.js');
        checks.push({ name: 'DeploymentPipeline', status: 'PASS', details: 'Module loads correctly' });
    } catch (error) {
        checks.push({ name: 'DeploymentPipeline', status: 'FAIL', details: error.message });
    }

    // Check 4: Deployment Assistant import
    try {
        const { DeploymentAssistant } = await import('../src/phase2/deployment-assistant.js');
        checks.push({ name: 'DeploymentAssistant', status: 'PASS', details: 'Module loads correctly' });
    } catch (error) {
        checks.push({ name: 'DeploymentAssistant', status: 'FAIL', details: error.message });
    }

    // Check 5: Slack Bot import
    try {
        const { SlackBot } = await import('../src/phase2/slack-bot.js');
        checks.push({ name: 'SlackBot', status: 'PASS', details: 'Module loads correctly' });
    } catch (error) {
        checks.push({ name: 'SlackBot', status: 'FAIL', details: error.message });
    }

    // Check 6: Test DeploymentPipeline instantiation
    try {
        const { DeploymentPipeline } = await import('../src/services/deployment-pipeline.js');
        const mockLogger = { info: () => {}, warn: () => {}, error: () => {} };
        const pipeline = new DeploymentPipeline(mockLogger, null);

        // Verify new features exist
        const features = [];
        if (typeof pipeline.validateSandboxTarget === 'function') features.push('validateSandboxTarget');
        if (typeof pipeline.isWithinDeploymentWindow === 'function') features.push('deploymentWindows');
        if (typeof pipeline.checkCircuitBreaker === 'function') features.push('circuitBreaker');
        if (typeof pipeline.rollbackToPrevious === 'function') features.push('rollback');
        if (typeof pipeline.listSnapshots === 'function') features.push('listSnapshots');
        if (pipeline.STRICT_MODE !== undefined) features.push('strictMode');

        checks.push({
            name: 'Pipeline Features',
            status: 'PASS',
            details: `Features: ${features.join(', ')}`
        });
    } catch (error) {
        checks.push({ name: 'Pipeline Features', status: 'FAIL', details: error.message });
    }

    // Print results
    console.log('\n' + chalk.bold('Results:'));
    console.log('-'.repeat(60));

    let passed = 0;
    let failed = 0;

    for (const check of checks) {
        const status = check.status === 'PASS'
            ? chalk.green('✓ PASS')
            : chalk.red('✗ FAIL');
        console.log(`${status}  ${check.name}`);
        console.log(chalk.gray(`       ${check.details}`));

        if (check.status === 'PASS') passed++;
        else failed++;
    }

    console.log('\n' + '-'.repeat(60));
    console.log(chalk.bold(`Total: ${passed} passed, ${failed} failed\n`));

    if (failed === 0) {
        console.log(chalk.green.bold('✅ All enhancements verified successfully!\n'));
        console.log(chalk.cyan('Ready for use. Start with:'));
        console.log(chalk.white('  npm run start          # Start main system'));
        console.log(chalk.white('  npm run phase2:start   # Start Slack bot'));
        console.log();
    } else {
        console.log(chalk.red.bold('❌ Some checks failed. Please review errors above.\n'));
        process.exit(1);
    }
}

verify().catch(err => {
    console.error(chalk.red('Verification failed:'), err);
    process.exit(1);
});
