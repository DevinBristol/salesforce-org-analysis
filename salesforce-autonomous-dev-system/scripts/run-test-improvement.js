#!/usr/bin/env node

/**
 * Run Test Improvement Pipeline
 *
 * This script runs the continuous modernization test improvement pipeline
 * on a Salesforce codebase to analyze, prioritize, and improve test classes.
 *
 * Usage:
 *   node scripts/run-test-improvement.js [options]
 *
 * Options:
 *   --source     Source directory containing Apex classes (default: ../salesforce-org-analysis/force-app/main/default/classes)
 *   --output     Output directory for improved tests (default: ./output/test-improvements)
 *   --sandbox    Target sandbox for deployment (default: Devin1)
 *   --improve    Max number of tests to improve (default: 10)
 *   --generate   Max number of new tests to generate (default: 10)
 *   --threshold  Quality threshold (0-100) below which tests are improved (default: 70)
 */

import path from 'path';
import { fileURLToPath } from 'url';
import { TestImprovementOrchestrator } from '../src/services/continuous-modernization/index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Parse command line arguments
const args = process.argv.slice(2);
const getArg = (name, defaultValue) => {
    const index = args.indexOf(`--${name}`);
    return index !== -1 && args[index + 1] ? args[index + 1] : defaultValue;
};

const config = {
    sourceDir: getArg('source', path.resolve(__dirname, '../../salesforce-org-analysis/force-app/main/default/classes')),
    outputDir: getArg('output', path.resolve(__dirname, '../output/test-improvements')),
    targetSandbox: getArg('sandbox', 'Devin1'),
    improveLimit: parseInt(getArg('improve', '10')),
    generateLimit: parseInt(getArg('generate', '10')),
    qualityThreshold: parseInt(getArg('threshold', '70'))
};

async function main() {
    console.log('\n🚀 Starting Test Improvement Pipeline\n');
    console.log('Configuration:');
    console.log(`  Source: ${config.sourceDir}`);
    console.log(`  Output: ${config.outputDir}`);
    console.log(`  Sandbox: ${config.targetSandbox}`);
    console.log(`  Improve Limit: ${config.improveLimit}`);
    console.log(`  Generate Limit: ${config.generateLimit}`);
    console.log(`  Quality Threshold: ${config.qualityThreshold}`);

    const orchestrator = new TestImprovementOrchestrator({
        outputDir: config.outputDir,
        targetSandbox: config.targetSandbox,
        qualityThreshold: config.qualityThreshold
    });

    const result = await orchestrator.runFullPipeline(config.sourceDir, {
        improveLimit: config.improveLimit,
        generateLimit: config.generateLimit
    });

    if (result.success) {
        console.log('\n✅ Pipeline completed successfully!');
        console.log(`\nNext steps:`);
        console.log(`1. Review files in: ${config.outputDir}`);
        console.log(`2. Deploy to ${config.targetSandbox}:`);
        console.log(`   sf project deploy start --source-dir ${config.outputDir} -o ${config.targetSandbox}`);
        process.exit(0);
    } else {
        console.log('\n❌ Pipeline failed:', result.error);
        process.exit(1);
    }
}

main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
