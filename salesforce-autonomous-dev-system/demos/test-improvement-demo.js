// demos/test-improvement-demo.js - Test Improvement System Demo

import { SalesforceManager } from '../src/services/salesforce-manager.js';
import { TestOrchestrator } from '../src/services/test-orchestrator.js';
import { Logger } from '../src/utils/logger.js';
import chalk from 'chalk';
import ora from 'ora';

/**
 * Demo script for test improvement system
 *
 * Usage:
 *   node demos/test-improvement-demo.js --mode=improve
 *   node demos/test-improvement-demo.js --mode=generate
 *   node demos/test-improvement-demo.js --mode=comprehensive
 *   node demos/test-improvement-demo.js --mode=improve --class=LeadTriggerHandlerTest
 */

class TestImprovementDemo {
    constructor() {
        this.logger = new Logger();
        this.salesforceManager = new SalesforceManager(this.logger);
        this.orchestrator = new TestOrchestrator(this.salesforceManager, this.logger);
    }

    async run() {
        try {
            console.log(chalk.cyan.bold('\n╔════════════════════════════════════════════════════════╗'));
            console.log(chalk.cyan.bold('║   SALESFORCE TEST IMPROVEMENT SYSTEM                  ║'));
            console.log(chalk.cyan.bold('║   Autonomous Test Generation & Refactoring            ║'));
            console.log(chalk.cyan.bold('╚════════════════════════════════════════════════════════╝\n'));

            // Parse command line arguments
            const args = this.parseArgs();

            // Display configuration
            this.displayConfiguration(args);

            // Connect to Salesforce
            const connectionSpinner = ora('Connecting to Salesforce...').start();
            await this.salesforceManager.connect();
            connectionSpinner.succeed('Connected to Salesforce');

            // Run the appropriate mode
            let results;
            switch (args.mode) {
                case 'improve':
                    results = await this.runImproveMode(args);
                    break;
                case 'generate':
                    results = await this.runGenerateMode(args);
                    break;
                case 'comprehensive':
                    results = await this.runComprehensiveMode(args);
                    break;
                case 'analyze':
                    results = await this.runAnalyzeMode(args);
                    break;
                default:
                    throw new Error(`Unknown mode: ${args.mode}`);
            }

            // Display results
            this.displayResults(results, args.mode);

        } catch (error) {
            console.error(chalk.red('\n❌ Error:'), error.message);
            this.logger.error('Demo failed:', error);
            process.exit(1);
        }
    }

    parseArgs() {
        const args = {
            mode: 'comprehensive',  // improve | generate | comprehensive | analyze
            class: null,            // Specific class name
            targetOrg: 'Devin1',    // SAFETY: Default to Devin1 sandbox only
            autoDeploy: true,
            targetCoverage: 100,
            focusOnCritical: true,
            generateDocs: true
        };

        process.argv.slice(2).forEach(arg => {
            if (arg.startsWith('--mode=')) {
                args.mode = arg.split('=')[1];
            } else if (arg.startsWith('--class=')) {
                args.class = arg.split('=')[1];
            } else if (arg.startsWith('--target-org=')) {
                args.targetOrg = arg.split('=')[1];
            } else if (arg.startsWith('--target-coverage=')) {
                args.targetCoverage = parseInt(arg.split('=')[1]);
            } else if (arg === '--no-deploy') {
                args.autoDeploy = false;
            } else if (arg === '--all-classes') {
                args.focusOnCritical = false;
            } else if (arg === '--no-docs') {
                args.generateDocs = false;
            }
        });

        return args;
    }

    displayConfiguration(args) {
        console.log(chalk.yellow('Configuration:'));
        console.log(chalk.gray('  Mode:'), chalk.white(args.mode));
        console.log(chalk.gray('  Target Org:'), chalk.white(args.targetOrg));
        console.log(chalk.gray('  Auto Deploy:'), chalk.white(args.autoDeploy ? 'Yes' : 'No'));
        console.log(chalk.gray('  Target Coverage:'), chalk.white(`${args.targetCoverage}%`));
        console.log(chalk.gray('  Focus on Critical:'), chalk.white(args.focusOnCritical ? 'Yes' : 'No'));
        console.log(chalk.gray('  Generate Documentation:'), chalk.white(args.generateDocs ? 'Yes' : 'No'));
        if (args.class) {
            console.log(chalk.gray('  Specific Class:'), chalk.white(args.class));
        }
        console.log('');
    }

    async runImproveMode(args) {
        console.log(chalk.cyan.bold('\n📝 IMPROVE MODE: Refactoring Existing Tests\n'));

        const classList = args.class ? [args.class] : null;

        const results = await this.orchestrator.improveTestClasses({
            classList,
            targetOrg: args.targetOrg,
            autoDeploy: args.autoDeploy,
            generateDocumentation: args.generateDocs
        });

        return results;
    }

    async runGenerateMode(args) {
        console.log(chalk.cyan.bold('\n⚡ GENERATE MODE: Creating New Tests\n'));

        // Get coverage data
        const coverageSpinner = ora('Fetching coverage data...').start();
        const coverageData = await this.fetchCoverageData();
        coverageSpinner.succeed(`Coverage data fetched - Org average: ${coverageData.orgAverage}%`);

        const results = await this.orchestrator.generateMissingTests({
            coverageData: coverageData.map,
            targetCoverage: args.targetCoverage,
            targetOrg: args.targetOrg,
            autoDeploy: args.autoDeploy,
            focusOnCritical: args.focusOnCritical
        });

        return results;
    }

    async runComprehensiveMode(args) {
        console.log(chalk.cyan.bold('\n🚀 COMPREHENSIVE MODE: Full Test Suite Improvement\n'));
        console.log(chalk.yellow('This will:'));
        console.log(chalk.gray('  1. Analyze and improve existing test classes'));
        console.log(chalk.gray('  2. Generate new tests for classes with low coverage'));
        console.log(chalk.gray('  3. Deploy all improvements to sandbox'));
        console.log(chalk.gray('  4. Generate comprehensive coverage report\n'));

        const results = await this.orchestrator.runComprehensiveTestImprovement({
            targetOrg: args.targetOrg,
            autoDeploy: args.autoDeploy,
            generateDocumentation: args.generateDocs,
            targetCoverage: args.targetCoverage,
            focusOnCritical: args.focusOnCritical
        });

        return results;
    }

    async runAnalyzeMode(args) {
        console.log(chalk.cyan.bold('\n🔍 ANALYZE MODE: Test Quality Analysis Only\n'));

        const { TestQualityAnalyzer } = await import('../src/services/test-quality-analyzer.js');
        const analyzer = new TestQualityAnalyzer(this.logger);

        const spinner = ora('Fetching test classes...').start();
        const testClasses = await this.orchestrator.getTestClassesToImprove(
            args.class ? [args.class] : null
        );
        spinner.succeed(`Found ${testClasses.length} test classes`);

        const analysisResults = [];
        const analysisSpinner = ora('Analyzing test quality...').start();

        for (let i = 0; i < testClasses.length; i++) {
            const testClass = testClasses[i];
            analysisSpinner.text = `Analyzing ${testClass.name} (${i + 1}/${testClasses.length})...`;

            const content = await this.salesforceManager.getApexClassContent(testClass.name);
            const analysis = analyzer.analyzeTestQuality(content, testClass.name);

            analysisResults.push(analysis);
        }

        analysisSpinner.succeed('Analysis complete');

        return { analysisResults };
    }

    async fetchCoverageData() {
        const coverageQuery = `
            SELECT ApexClassOrTrigger.Name,
                   NumLinesCovered,
                   NumLinesUncovered,
                   Coverage
            FROM ApexCodeCoverageAggregate
            WHERE ApexClassOrTriggerId != null
        `;

        const result = await this.salesforceManager.connection.tooling.query(coverageQuery);

        const coverageMap = new Map();
        let totalCovered = 0;
        let totalLines = 0;

        for (const record of result.records) {
            const className = record.ApexClassOrTrigger.Name;
            const covered = record.NumLinesCovered || 0;
            const uncovered = record.NumLinesUncovered || 0;
            const total = covered + uncovered;
            const percentage = total > 0 ? Math.round((covered / total) * 100) : 0;

            coverageMap.set(className, {
                className,
                coverage: percentage,
                linesCovered: covered,
                linesUncovered: uncovered
            });

            totalCovered += covered;
            totalLines += total;
        }

        const orgAverage = totalLines > 0 ? Math.round((totalCovered / totalLines) * 100) : 0;

        return {
            map: coverageMap,
            orgAverage
        };
    }

    displayResults(results, mode) {
        console.log(chalk.green.bold('\n✅ RESULTS\n'));

        if (mode === 'analyze') {
            this.displayAnalysisResults(results);
        } else if (mode === 'improve') {
            this.displayImprovementResults(results);
        } else if (mode === 'generate') {
            this.displayGenerationResults(results);
        } else if (mode === 'comprehensive') {
            this.displayComprehensiveResults(results);
        }

        console.log(chalk.cyan('\n📊 Reports saved to:'), chalk.white('./output/test-improvements/'));
    }

    displayAnalysisResults(results) {
        const { analysisResults } = results;

        // Group by quality score
        const excellent = analysisResults.filter(r => r.score >= 80);
        const good = analysisResults.filter(r => r.score >= 60 && r.score < 80);
        const needsWork = analysisResults.filter(r => r.score >= 40 && r.score < 60);
        const poor = analysisResults.filter(r => r.score < 40);

        console.log(chalk.green(`✓ Excellent (80-100):`), chalk.white(excellent.length));
        console.log(chalk.yellow(`⚠ Good (60-79):`), chalk.white(good.length));
        console.log(chalk.yellow(`⚠ Needs Work (40-59):`), chalk.white(needsWork.length));
        console.log(chalk.red(`✗ Poor (0-39):`), chalk.white(poor.length));

        console.log(chalk.cyan('\nTop 5 Tests Needing Improvement:'));
        analysisResults
            .sort((a, b) => a.score - b.score)
            .slice(0, 5)
            .forEach((result, index) => {
                console.log(chalk.gray(`  ${index + 1}. ${result.className}:`),
                    chalk.red(`${result.score}/100`),
                    chalk.gray(`(${result.issues.critical.length} critical, ${result.issues.high.length} high)`));
            });
    }

    displayImprovementResults(results) {
        console.log(chalk.white('Tests Analyzed:'), chalk.cyan(results.testsAnalyzed));
        console.log(chalk.white('Tests Improved:'), chalk.cyan(results.testsImproved));
        console.log(chalk.white('Tests Deployed:'), chalk.green(results.testsDeployed));

        if (results.report && results.report.summary) {
            console.log(chalk.white('Avg Score Improvement:'),
                chalk.green(`+${results.report.summary.averageScoreImprovement} points`));
        }
    }

    displayGenerationResults(results) {
        console.log(chalk.white('Tests Generated:'), chalk.cyan(results.testsGenerated));
        console.log(chalk.white('Tests Deployed:'), chalk.green(results.testsDeployed));
    }

    displayComprehensiveResults(results) {
        console.log(chalk.white('Tests Improved:'), chalk.cyan(results.testsImproved));
        console.log(chalk.white('Tests Generated:'), chalk.cyan(results.testsGenerated));
        console.log(chalk.white('Total Tests Deployed:'), chalk.green(results.testsDeployed));
        console.log(chalk.white('Total Tests Affected:'), chalk.cyan(results.testsImproved + results.testsGenerated));
    }
}

// Run the demo
const demo = new TestImprovementDemo();
demo.run();
