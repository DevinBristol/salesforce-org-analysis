/**
 * Phase 4 Component Test Script
 *
 * Tests that all Phase 4 components can be loaded and initialized.
 */

import 'dotenv/config';

console.log('='.repeat(60));
console.log('Phase 4: Component Test');
console.log('='.repeat(60));
console.log('');

async function testComponents() {
    const results = [];

    // Test 1: Result Callback System
    try {
        const { ResultCallbackSystem } = await import('./result-callback.js');
        const rcs = new ResultCallbackSystem({ logger: console });
        results.push({ name: 'ResultCallbackSystem', status: 'OK' });
    } catch (err) {
        results.push({ name: 'ResultCallbackSystem', status: 'FAIL', error: err.message });
    }

    // Test 2: Progress Reporter
    try {
        const { ProgressReporter } = await import('./progress-reporter.js');
        const pr = new ProgressReporter({ logger: console });
        results.push({ name: 'ProgressReporter', status: 'OK' });
    } catch (err) {
        results.push({ name: 'ProgressReporter', status: 'FAIL', error: err.message });
    }

    // Test 3: Enhanced Conversation Manager
    try {
        const { EnhancedConversationManager } = await import('./conversation-manager-enhanced.js');
        const ecm = new EnhancedConversationManager({ logger: console });
        results.push({ name: 'EnhancedConversationManager', status: 'OK' });
    } catch (err) {
        results.push({ name: 'EnhancedConversationManager', status: 'FAIL', error: err.message });
    }

    // Test 4: Monitoring System
    try {
        const { MonitoringSystem } = await import('./monitoring-system.js');
        const ms = new MonitoringSystem({ logger: console });
        results.push({ name: 'MonitoringSystem', status: 'OK' });

        // Test health check registration
        ms.registerHealthCheck('test', async () => ({ healthy: true }));
        results.push({ name: 'MonitoringSystem.registerHealthCheck', status: 'OK' });

        // Get metrics
        const metrics = ms.getMetrics();
        results.push({ name: 'MonitoringSystem.getMetrics', status: metrics ? 'OK' : 'FAIL' });

        await ms.shutdown();
    } catch (err) {
        results.push({ name: 'MonitoringSystem', status: 'FAIL', error: err.message });
    }

    // Test 5: Claude Code Orchestrator
    try {
        const { ClaudeCodeOrchestrator } = await import('./claude-orchestrator.js');
        const cco = new ClaudeCodeOrchestrator({
            logger: console,
            maxInstances: 2,
            workspaceRoot: '/tmp/test-workspace'
        });
        results.push({ name: 'ClaudeCodeOrchestrator', status: 'OK' });

        // Test status
        const status = cco.getStatus();
        results.push({ name: 'ClaudeCodeOrchestrator.getStatus', status: status ? 'OK' : 'FAIL' });

        await cco.shutdown();
    } catch (err) {
        results.push({ name: 'ClaudeCodeOrchestrator', status: 'FAIL', error: err.message });
    }

    // Test 6: Workflow Engine
    try {
        const { WorkflowEngine } = await import('./workflow-engine.js');
        const we = new WorkflowEngine({ logger: console });
        results.push({ name: 'WorkflowEngine', status: 'OK' });

        // Test templates
        const templates = we.getTemplates();
        results.push({
            name: 'WorkflowEngine.getTemplates',
            status: templates.length > 0 ? 'OK' : 'FAIL',
            info: `${templates.length} templates available`
        });

        await we.shutdown();
    } catch (err) {
        results.push({ name: 'WorkflowEngine', status: 'FAIL', error: err.message });
    }

    // Test 7: Enhanced Worker Pool
    try {
        const { EnhancedWorkerPool } = await import('./worker-pool-enhanced.js');
        const ewp = new EnhancedWorkerPool({ logger: console, workerCount: 1 });
        results.push({ name: 'EnhancedWorkerPool', status: 'OK' });
    } catch (err) {
        results.push({ name: 'EnhancedWorkerPool', status: 'FAIL', error: err.message });
    }

    // Test 8: Migration module
    try {
        const { Phase4Migration, migrations } = await import('./migrate-phase4.js');
        results.push({
            name: 'Phase4Migration',
            status: 'OK',
            info: `${migrations.length} migrations defined`
        });
    } catch (err) {
        results.push({ name: 'Phase4Migration', status: 'FAIL', error: err.message });
    }

    // Print results
    console.log('Component Test Results:');
    console.log('-'.repeat(60));

    let passed = 0, failed = 0;
    for (const result of results) {
        const statusIcon = result.status === 'OK' ? '✓' : '✗';
        let line = `${statusIcon} ${result.name}: ${result.status}`;
        if (result.info) line += ` (${result.info})`;
        if (result.error) line += ` - ${result.error}`;
        console.log(line);

        if (result.status === 'OK') passed++;
        else failed++;
    }

    console.log('-'.repeat(60));
    console.log(`Total: ${passed} passed, ${failed} failed`);
    console.log('');

    // Environment check
    console.log('Environment:');
    console.log('-'.repeat(60));
    console.log(`ANTHROPIC_API_KEY: ${process.env.ANTHROPIC_API_KEY ? 'Set' : 'Not set'}`);
    console.log(`DATABASE_URL: ${process.env.DATABASE_URL ? (process.env.DATABASE_URL.includes('user:pass') ? 'Placeholder' : 'Set') : 'Not set'}`);
    console.log(`SLACK_BOT_TOKEN: ${process.env.SLACK_BOT_TOKEN ? 'Set' : 'Not set'}`);
    console.log(`WORKSPACE_ROOT: ${process.env.WORKSPACE_ROOT || 'Not set'}`);
    console.log('');

    return failed === 0;
}

testComponents()
    .then(success => {
        console.log('='.repeat(60));
        if (success) {
            console.log('All Phase 4 components loaded successfully!');
            console.log('');
            console.log('To start the full system:');
            console.log('  1. Configure a PostgreSQL database (optional)');
            console.log('  2. Run: node src/phase4/main.js');
        } else {
            console.log('Some components failed to load. Check errors above.');
        }
        console.log('='.repeat(60));
        process.exit(success ? 0 : 1);
    })
    .catch(err => {
        console.error('Test failed:', err);
        process.exit(1);
    });
