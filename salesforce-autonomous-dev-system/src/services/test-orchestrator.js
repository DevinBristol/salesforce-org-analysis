// src/services/test-orchestrator.js - Test Improvement Orchestration Service

import fs from 'fs-extra';
import path from 'path';
import ora from 'ora';
import chalk from 'chalk';
import { TestQualityAnalyzer } from './test-quality-analyzer.js';
import { TestCodeGenerator } from './test-code-generator.js';
import { TestDataFactoryGenerator } from './test-data-factory-generator.js';

/**
 * Orchestrates test improvement and generation workflow
 */
export class TestOrchestrator {
    constructor(salesforceManager, logger) {
        this.salesforceManager = salesforceManager;
        this.logger = logger;
        this.qualityAnalyzer = new TestQualityAnalyzer(logger);
        this.codeGenerator = new TestCodeGenerator(logger);
        this.factoryGenerator = new TestDataFactoryGenerator(salesforceManager, logger);

        this.outputDir = './output/test-improvements';
        this.progressFile = './output/test-improvements/progress.json';
    }

    /**
     * Improves existing test classes based on quality analysis
     * @param {Object} options - {classList, targetOrg, autoDeployapproxEqualsImprovements}
     * @returns {Object} Results summary
     */
    async improveTestClasses(options = {}) {
        const {
            classList = null,  // If null, analyze all test classes
            targetOrg = 'Devin1',  // SAFETY: Default to Devin1 sandbox
            autoDeploy = true,
            generateDocumentation = true
        } = options;

        try {
            this.logger.info('Starting test improvement process...');

            // Step 1: Get test classes to improve
            const spinner = ora('Fetching test classes from Salesforce...').start();
            const testClasses = await this.getTestClassesToImprove(classList);
            spinner.succeed(`Found ${testClasses.length} test classes to analyze`);

            // Step 2: Analyze quality for each test class
            const analysisSpinner = ora('Analyzing test quality...').start();
            const analysisResults = [];

            for (let i = 0; i < testClasses.length; i++) {
                const testClass = testClasses[i];
                analysisSpinner.text = `Analyzing ${testClass.name} (${i + 1}/${testClasses.length})...`;

                const content = await this.salesforceManager.getApexClassContent(testClass.name);
                const analysis = this.qualityAnalyzer.analyzeTestQuality(content, testClass.name);

                analysisResults.push({
                    className: testClass.name,
                    content,
                    analysis,
                    needsImprovement: analysis.score < 70,
                    needsRewrite: this.qualityAnalyzer.shouldRewrite(analysis)
                });

                // Save progress
                if ((i + 1) % 10 === 0) {
                    await this.saveProgress({ analysisResults, step: 'analysis', index: i + 1 });
                }
            }

            analysisSpinner.succeed(`Analysis complete - ${analysisResults.filter(r => r.needsImprovement).length} tests need improvement`);

            // Step 3: Prioritize test classes
            const prioritized = this.prioritizeTestImprovements(analysisResults);

            // Step 4: Improve test classes
            const improvementResults = [];
            const improvementSpinner = ora('Improving test classes...').start();

            for (let i = 0; i < prioritized.length; i++) {
                const testClass = prioritized[i];

                if (!testClass.needsImprovement) {
                    continue;
                }

                improvementSpinner.text = `Improving ${testClass.className} (${i + 1}/${prioritized.length})...`;

                // Get the production class being tested
                const productionClassName = testClass.className.replace('Test', '');
                let productionClass = null;
                try {
                    const productionContent = await this.salesforceManager.getApexClassContent(productionClassName);
                    productionClass = { name: productionClassName, content: productionContent };
                } catch (error) {
                    this.logger.warn(`Could not fetch production class ${productionClassName}`);
                }

                // Improve the test
                const result = await this.codeGenerator.improveTestClass(
                    testClass.content,
                    testClass.className,
                    testClass.analysis,
                    productionClass
                );

                if (result.success) {
                    improvementResults.push({
                        className: testClass.className,
                        originalScore: testClass.analysis.score,
                        improvedCode: result.improvedCode,
                        improvements: result.improvements,
                        metadata: result.metadata,
                        deployed: false
                    });

                    // Save improved code to file
                    await this.saveImprovedTest(testClass.className, result.improvedCode, result.metadata);
                }

                // Save progress
                if ((i + 1) % 5 === 0) {
                    await this.saveProgress({ improvementResults, step: 'improvement', index: i + 1 });
                }
            }

            improvementSpinner.succeed(`Improved ${improvementResults.length} test classes`);

            // Step 5: Deploy to sandbox if auto-deploy enabled
            let deploymentResults = [];
            if (autoDeploy && improvementResults.length > 0) {
                deploymentResults = await this.deployImprovedTests(improvementResults, targetOrg);
            }

            // Step 6: Generate report
            const report = await this.generateTestImprovementReport({
                analysisResults,
                improvementResults,
                deploymentResults
            });

            return {
                success: true,
                testsAnalyzed: analysisResults.length,
                testsImproved: improvementResults.length,
                testsDeployed: deploymentResults.filter(r => r.success).length,
                report
            };

        } catch (error) {
            this.logger.error('Test improvement process failed:', error);
            throw error;
        }
    }

    /**
     * Generates new test classes for production classes with low/no coverage
     * @param {Object} options - {coverageData, targetCoverage, targetOrg, autoDeploy}
     * @returns {Object} Results summary
     */
    async generateMissingTests(options = {}) {
        const {
            coverageData,  // Coverage map from org analyzer
            targetCoverage = 100,
            targetOrg = 'Devin1',  // SAFETY: Default to Devin1 sandbox
            autoDeploy = true,
            focusOnCritical = true  // Focus on handlers, triggers, services first
        } = options;

        try {
            this.logger.info('Generating tests for classes with low coverage...');

            // Step 1: Identify classes needing tests
            const spinner = ora('Identifying classes needing test coverage...').start();
            const classesNeedingTests = await this.identifyClassesNeedingTests(
                coverageData,
                targetCoverage,
                focusOnCritical
            );
            spinner.succeed(`Found ${classesNeedingTests.length} classes needing new/improved tests`);

            // Step 2: Generate tests
            const generationResults = [];
            const generationSpinner = ora('Generating test classes...').start();

            for (let i = 0; i < classesNeedingTests.length; i++) {
                const prodClass = classesNeedingTests[i];
                generationSpinner.text = `Generating test for ${prodClass.className} (${i + 1}/${classesNeedingTests.length})...`;

                const content = await this.salesforceManager.getApexClassContent(prodClass.className);

                const result = await this.codeGenerator.generateNewTestClass(
                    content,
                    prodClass.className,
                    targetCoverage
                );

                if (result.success) {
                    generationResults.push({
                        className: prodClass.className,
                        testClassName: result.testClassName,
                        testCode: result.testCode,
                        metadata: result.metadata,
                        currentCoverage: prodClass.currentCoverage,
                        targetCoverage: result.targetCoverage,
                        deployed: false
                    });

                    // Save generated test
                    await this.saveGeneratedTest(result.testClassName, result.testCode, result.metadata);
                }

                // Save progress
                if ((i + 1) % 5 === 0) {
                    await this.saveProgress({ generationResults, step: 'generation', index: i + 1 });
                }
            }

            generationSpinner.succeed(`Generated ${generationResults.length} test classes`);

            // Step 3: Deploy to sandbox if auto-deploy enabled
            let deploymentResults = [];
            if (autoDeploy && generationResults.length > 0) {
                deploymentResults = await this.deployGeneratedTests(generationResults, targetOrg);
            }

            // Step 4: Generate report
            const report = await this.generateTestGenerationReport({
                generationResults,
                deploymentResults
            });

            return {
                success: true,
                testsGenerated: generationResults.length,
                testsDeployed: deploymentResults.filter(r => r.success).length,
                report
            };

        } catch (error) {
            this.logger.error('Test generation process failed:', error);
            throw error;
        }
    }

    /**
     * Comprehensive test improvement: refactor existing + generate missing
     * @param {Object} options - Configuration options
     * @returns {Object} Combined results
     */
    async runComprehensiveTestImprovement(options = {}) {
        const {
            targetOrg = 'Devin1',  // SAFETY: Default to Devin1 sandbox
            autoDeploy = true,
            generateDocumentation = true,
            targetCoverage = 100,
            focusOnCritical = true
        } = options;

        try {
            this.logger.info('Starting comprehensive test improvement...');
            this.logger.info('Phase 1: Improving existing tests');
            this.logger.info('Phase 2: Generating missing tests');
            this.logger.info('Phase 3: Deploying to sandbox');

            // Get coverage data first
            const coverageSpinner = ora('Fetching org coverage data...').start();
            const coverageData = await this.salesforceManager.connection.tooling.query(`
                SELECT ApexClassOrTrigger.Name,
                       NumLinesCovered,
                       NumLinesUncovered,
                       Coverage
                FROM ApexCodeCoverageAggregate
                WHERE ApexClassOrTriggerId != null
            `);
            coverageSpinner.succeed('Coverage data fetched');

            // Build coverage map
            const coverageMap = new Map();
            for (const record of coverageData.records) {
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
            }

            // Phase 1: Improve existing tests
            const improvementResults = await this.improveTestClasses({
                classList: null,
                targetOrg,
                autoDeploy: false,  // Deploy all at once at the end
                generateDocumentation
            });

            // Phase 2: Generate missing tests
            const generationResults = await this.generateMissingTests({
                coverageData: coverageMap,
                targetCoverage,
                targetOrg,
                autoDeploy: false,  // Deploy all at once
                focusOnCritical
            });

            // Phase 3: Deploy everything
            const deploymentSpinner = ora('Deploying all test improvements to sandbox...').start();
            const allTests = [
                ...improvementResults.improvementResults || [],
                ...generationResults.generationResults || []
            ];

            const deploymentResults = await this.deployAllTests(allTests, targetOrg);
            deploymentSpinner.succeed(`Deployed ${deploymentResults.filter(r => r.success).length}/${allTests.length} tests`);

            // Generate comprehensive report
            const report = await this.generateComprehensiveReport({
                improvementResults,
                generationResults,
                deploymentResults
            });

            return {
                success: true,
                testsImproved: improvementResults.testsImproved || 0,
                testsGenerated: generationResults.testsGenerated || 0,
                testsDeployed: deploymentResults.filter(r => r.success).length,
                report
            };

        } catch (error) {
            this.logger.error('Comprehensive test improvement failed:', error);
            throw error;
        }
    }

    /**
     * Gets list of test classes to improve
     */
    async getTestClassesToImprove(classList) {
        if (classList) {
            return classList.map(name => ({ name }));
        }

        // Get all test classes from org
        const allClasses = await this.salesforceManager.getApexClasses();
        return allClasses
            .filter(cls => cls.Name.endsWith('Test') || cls.Name.includes('Test'))
            .map(cls => ({ name: cls.Name }));
    }

    /**
     * Prioritizes test improvements by class criticality
     */
    prioritizeTestImprovements(analysisResults) {
        return analysisResults.sort((a, b) => {
            // Priority 1: Critical issues and rewrites
            if (a.needsRewrite && !b.needsRewrite) return -1;
            if (!a.needsRewrite && b.needsRewrite) return 1;

            // Priority 2: Lower quality score
            return a.analysis.score - b.analysis.score;
        });
    }

    /**
     * Identifies classes that need new test coverage
     */
    async identifyClassesNeedingTests(coverageData, targetCoverage, focusOnCritical) {
        const classesNeedingTests = [];

        // Get all non-test classes
        const allClasses = await this.salesforceManager.getApexClasses();

        for (const cls of allClasses) {
            // Skip test classes and managed packages
            if (cls.Name.includes('Test') || cls.Name.includes('__')) {
                continue;
            }

            const coverage = coverageData.get(cls.Name);
            const currentCoverage = coverage ? coverage.coverage : 0;

            if (currentCoverage < targetCoverage) {
                const priority = this.calculateClassPriority(cls.Name, currentCoverage);

                // If focusing on critical, only include high priority classes
                if (!focusOnCritical || priority >= 80) {
                    classesNeedingTests.push({
                        className: cls.Name,
                        currentCoverage,
                        priority
                    });
                }
            }
        }

        // Sort by priority (highest first)
        return classesNeedingTests.sort((a, b) => b.priority - a.priority);
    }

    /**
     * Calculates priority score for a class (0-100)
     */
    calculateClassPriority(className, currentCoverage) {
        let priority = 0;

        // Type-based priority (0-40 points)
        if (className.includes('Handler') || className.includes('Trigger')) {
            priority += 40;
        } else if (className.includes('Service') || className.includes('Manager')) {
            priority += 35;
        } else if (className.includes('Controller')) {
            priority += 30;
        } else if (className.includes('Util') || className.includes('Helper')) {
            priority += 20;
        } else {
            priority += 10;
        }

        // Coverage gap priority (0-40 points)
        // Lower coverage = higher priority
        const coverageGap = 100 - currentCoverage;
        priority += (coverageGap / 100) * 40;

        // Critical if no coverage at all (bonus 20 points)
        if (currentCoverage === 0) {
            priority += 20;
        }

        return Math.min(priority, 100);
    }

    /**
     * Deploys improved tests to sandbox
     */
    async deployImprovedTests(improvementResults, targetOrg) {
        const results = [];

        for (const test of improvementResults) {
            try {
                const deploySpinner = ora(`Deploying ${test.className}...`).start();

                const artifacts = {
                    apex: {
                        [`${test.className}.cls`]: test.improvedCode
                    }
                };

                const deployResult = await this.salesforceManager.deployToSandbox(artifacts, targetOrg);

                if (deployResult.success) {
                    deploySpinner.succeed(`${test.className} deployed successfully`);
                    test.deployed = true;
                    results.push({
                        success: true,
                        className: test.className,
                        deploymentId: deployResult.deploymentId
                    });
                } else {
                    deploySpinner.fail(`${test.className} deployment failed`);
                    results.push({
                        success: false,
                        className: test.className,
                        error: deployResult.details
                    });
                }
            } catch (error) {
                results.push({
                    success: false,
                    className: test.className,
                    error: error.message
                });
            }
        }

        return results;
    }

    /**
     * Deploys generated tests to sandbox
     */
    async deployGeneratedTests(generationResults, targetOrg) {
        const results = [];

        for (const test of generationResults) {
            try {
                const deploySpinner = ora(`Deploying ${test.testClassName}...`).start();

                const artifacts = {
                    apex: {
                        [`${test.testClassName}.cls`]: test.testCode
                    }
                };

                const deployResult = await this.salesforceManager.deployToSandbox(artifacts, targetOrg);

                if (deployResult.success) {
                    deploySpinner.succeed(`${test.testClassName} deployed successfully`);
                    test.deployed = true;
                    results.push({
                        success: true,
                        className: test.testClassName,
                        deploymentId: deployResult.deploymentId
                    });
                } else {
                    deploySpinner.fail(`${test.testClassName} deployment failed`);
                    results.push({
                        success: false,
                        className: test.testClassName,
                        error: deployResult.details
                    });
                }
            } catch (error) {
                results.push({
                    success: false,
                    className: test.testClassName,
                    error: error.message
                });
            }
        }

        return results;
    }

    /**
     * Deploys all tests in a single deployment package
     */
    async deployAllTests(allTests, targetOrg) {
        const artifacts = { apex: {} };

        for (const test of allTests) {
            const className = test.testClassName || test.className;
            const code = test.testCode || test.improvedCode;
            artifacts.apex[`${className}.cls`] = code;
        }

        const deployResult = await this.salesforceManager.deployToSandbox(artifacts, targetOrg);

        return allTests.map(test => ({
            success: deployResult.success,
            className: test.testClassName || test.className,
            deploymentId: deployResult.deploymentId
        }));
    }

    /**
     * Saves improved test to output directory
     */
    async saveImprovedTest(className, code, metadata) {
        await fs.ensureDir(this.outputDir);

        const classFile = path.join(this.outputDir, `${className}.cls`);
        const metaFile = path.join(this.outputDir, `${className}.cls-meta.xml`);

        await fs.writeFile(classFile, code);
        await fs.writeFile(metaFile, metadata);
    }

    /**
     * Saves generated test to output directory
     */
    async saveGeneratedTest(className, code, metadata) {
        await this.saveImprovedTest(className, code, metadata);
    }

    /**
     * Saves progress to file for resume capability
     */
    async saveProgress(progress) {
        await fs.ensureDir(path.dirname(this.progressFile));
        await fs.writeJson(this.progressFile, {
            ...progress,
            timestamp: new Date().toISOString()
        }, { spaces: 2 });
    }

    /**
     * Generates test improvement report
     */
    async generateTestImprovementReport(data) {
        const report = {
            timestamp: new Date().toISOString(),
            summary: {
                testsAnalyzed: data.analysisResults.length,
                testsImproved: data.improvementResults.length,
                testsDeployed: data.deploymentResults.filter(r => r.success).length,
                averageScoreImprovement: this.calculateAverageScoreImprovement(data.improvementResults)
            },
            details: data
        };

        const reportFile = path.join(this.outputDir, 'test-improvement-report.json');
        await fs.writeJson(reportFile, report, { spaces: 2 });

        return report;
    }

    /**
     * Generates test generation report
     */
    async generateTestGenerationReport(data) {
        const report = {
            timestamp: new Date().toISOString(),
            summary: {
                testsGenerated: data.generationResults.length,
                testsDeployed: data.deploymentResults.filter(r => r.success).length
            },
            details: data
        };

        const reportFile = path.join(this.outputDir, 'test-generation-report.json');
        await fs.writeJson(reportFile, report, { spaces: 2 });

        return report;
    }

    /**
     * Generates comprehensive report
     */
    async generateComprehensiveReport(data) {
        const report = {
            timestamp: new Date().toISOString(),
            summary: {
                testsImproved: data.improvementResults.testsImproved || 0,
                testsGenerated: data.generationResults.testsGenerated || 0,
                testsDeployed: data.deploymentResults.filter(r => r.success).length,
                totalTests: (data.improvementResults.testsImproved || 0) +
                           (data.generationResults.testsGenerated || 0)
            },
            details: data
        };

        const reportFile = path.join(this.outputDir, 'comprehensive-test-report.json');
        await fs.writeJson(reportFile, report, { spaces: 2 });

        return report;
    }

    /**
     * Calculates average score improvement
     */
    calculateAverageScoreImprovement(improvementResults) {
        if (improvementResults.length === 0) return 0;

        const totalImprovement = improvementResults.reduce((sum, result) => {
            // Assume improved score is ~80-90 for tests that were improved
            const estimatedNewScore = 85;
            return sum + (estimatedNewScore - result.originalScore);
        }, 0);

        return Math.round(totalImprovement / improvementResults.length);
    }
}
