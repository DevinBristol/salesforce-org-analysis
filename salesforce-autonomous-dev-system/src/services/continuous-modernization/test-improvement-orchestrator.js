/**
 * Test Improvement Orchestrator
 *
 * Coordinates the full test class analysis, prioritization, and improvement pipeline.
 * This is the main entry point for the continuous modernization test evolution system.
 */

import Anthropic from '@anthropic-ai/sdk';
import fs from 'fs-extra';
import path from 'path';
import { TestEvolutionService } from './test-evolution-service.js';
import { PrioritizationService } from './prioritization-service.js';

export class TestImprovementOrchestrator {
    constructor(config = {}) {
        this.anthropic = new Anthropic();
        this.model = config.model || 'claude-sonnet-4-20250514';
        this.evolutionService = new TestEvolutionService(config);
        this.prioritizationService = new PrioritizationService(config);

        this.outputDir = config.outputDir || './output/test-improvements';
        this.targetSandbox = config.targetSandbox || 'Devin1';
        this.maxConcurrent = config.maxConcurrent || 3;
        this.qualityThreshold = config.qualityThreshold || 70;
    }

    /**
     * Analyze all test classes in a directory
     */
    async analyzeTestClasses(classesDir) {
        console.log('\n🔍 PHASE 1: Analyzing Test Classes\n');
        console.log('='.repeat(50));

        const files = await fs.readdir(classesDir);
        const testFiles = files.filter(f =>
            f.endsWith('Test.cls') || f.endsWith('Tests.cls')
        );

        console.log(`Found ${testFiles.length} test classes to analyze\n`);

        const analyses = [];
        let processed = 0;

        for (const testFile of testFiles) {
            const testClassName = testFile.replace('.cls', '');
            const testCode = await fs.readFile(path.join(classesDir, testFile), 'utf-8');

            // Try to find the class being tested
            const testedClassName = testClassName.replace(/Tests?$/, '');
            const testedFile = path.join(classesDir, `${testedClassName}.cls`);
            let testedClassCode = null;

            if (await fs.pathExists(testedFile)) {
                testedClassCode = await fs.readFile(testedFile, 'utf-8');
            }

            try {
                const analysis = await this.evolutionService.analyzeTestClass(testCode, testedClassCode);

                if (analysis) {
                    analyses.push({
                        testClassName,
                        testedClassName,
                        testFile,
                        testCode,
                        testedClassCode,
                        ...analysis
                    });

                    const score = analysis.qualityScore || 0;
                    const status = score >= 70 ? '✅' : score >= 50 ? '⚠️' : '❌';
                    console.log(`${status} ${testClassName}: ${score}/100`);
                }
            } catch (error) {
                console.log(`❌ ${testClassName}: Analysis failed - ${error.message}`);
            }

            processed++;

            // Rate limiting
            if (processed % 5 === 0) {
                await this.sleep(1000);
            }
        }

        return analyses;
    }

    /**
     * Find classes without test coverage
     */
    async findClassesWithoutTests(classesDir) {
        console.log('\n🔍 Finding Classes Without Tests\n');
        console.log('='.repeat(50));

        const files = await fs.readdir(classesDir);
        const allClasses = files.filter(f =>
            f.endsWith('.cls') &&
            !f.endsWith('Test.cls') &&
            !f.endsWith('Tests.cls') &&
            !f.endsWith('-meta.xml')
        );

        const testClasses = files.filter(f =>
            f.endsWith('Test.cls') || f.endsWith('Tests.cls')
        );

        const testedClassNames = new Set(
            testClasses.map(t => t.replace(/Tests?\.cls$/, ''))
        );

        const classesWithoutTests = [];

        for (const classFile of allClasses) {
            const className = classFile.replace('.cls', '');

            // Skip certain patterns
            if (
                className.includes('Mock') ||
                className.includes('Stub') ||
                className.includes('Factory') ||
                className.startsWith('Autocreated')
            ) {
                continue;
            }

            if (!testedClassNames.has(className)) {
                const classPath = path.join(classesDir, classFile);
                const classCode = await fs.readFile(classPath, 'utf-8');

                // Skip empty or very small classes
                const lines = classCode.split('\n').filter(l => l.trim()).length;
                if (lines < 5) continue;

                classesWithoutTests.push({
                    className,
                    classFile,
                    classCode,
                    lineCount: lines,
                    needsTest: true
                });

                console.log(`📝 ${className} (${lines} lines) - No test class found`);
            }
        }

        console.log(`\nFound ${classesWithoutTests.length} classes without tests`);
        return classesWithoutTests;
    }

    /**
     * Prioritize test improvements
     */
    prioritizeImprovements(analyses, classesWithoutTests) {
        console.log('\n📊 PHASE 2: Prioritizing Improvements\n');
        console.log('='.repeat(50));

        // Prioritize existing tests that need improvement
        const prioritizedTests = this.prioritizationService.prioritizeTests(analyses);

        // Also prioritize classes without tests (high priority)
        const classesNeedingTests = classesWithoutTests.map(c => ({
            ...c,
            qualityScore: 0,
            priority: {
                priorityScore: 85, // High priority for missing tests
                category: 'QUICK_WIN',
                isQuickWin: true,
                components: { risk: 80, impact: 90, effort: 40, dependencies: 30 }
            }
        }));

        // Generate improvement plan
        const plan = this.prioritizationService.generateImprovementPlan(prioritizedTests);

        console.log('\nPriority Summary:');
        console.log(`  Quick Wins: ${plan.summary.quickWinCount}`);
        console.log(`  Strategic: ${plan.summary.strategicCount}`);
        console.log(`  Fill-ins: ${plan.summary.fillInCount}`);
        console.log(`  Classes needing new tests: ${classesNeedingTests.length}`);

        if (plan.recommendations.length > 0) {
            console.log('\nRecommendations:');
            plan.recommendations.forEach(r => {
                console.log(`  [${r.priority}] ${r.message}`);
            });
        }

        return {
            prioritizedTests,
            classesNeedingTests,
            plan
        };
    }

    /**
     * Improve test classes based on priority
     */
    async improveTestClasses(prioritizedTests, limit = 10) {
        console.log('\n🔧 PHASE 3: Improving Test Classes\n');
        console.log('='.repeat(50));

        const testsToImprove = prioritizedTests
            .filter(t => t.qualityScore < this.qualityThreshold)
            .slice(0, limit);

        console.log(`Improving top ${testsToImprove.length} test classes...\n`);

        const improvements = [];

        for (const test of testsToImprove) {
            console.log(`\n📝 Processing: ${test.testClassName}`);
            console.log(`   Priority Score: ${test.priority.priorityScore}`);
            console.log(`   Category: ${test.priority.category}`);

            try {
                const result = await this.evolutionService.runEvolutionPipeline(
                    test.testClassName,
                    test.testCode,
                    test.testedClassCode
                );

                if (result.success && result.improved) {
                    improvements.push({
                        ...result,
                        priority: test.priority
                    });
                    console.log(`   ✅ Improved: ${result.originalScore} → ${result.newScore}`);
                } else if (result.success && !result.improved) {
                    console.log(`   ℹ️ ${result.reason}`);
                } else {
                    console.log(`   ❌ Failed: ${result.error}`);
                }
            } catch (error) {
                console.log(`   ❌ Error: ${error.message}`);
            }

            // Rate limiting
            await this.sleep(2000);
        }

        return improvements;
    }

    /**
     * Generate new test classes for untested classes
     */
    async generateMissingTests(classesNeedingTests, limit = 10) {
        console.log('\n✨ PHASE 4: Generating Missing Test Classes\n');
        console.log('='.repeat(50));

        const toGenerate = classesNeedingTests.slice(0, limit);
        console.log(`Generating ${toGenerate.length} new test classes...\n`);

        const generated = [];

        for (const classInfo of toGenerate) {
            console.log(`\n📝 Generating test for: ${classInfo.className}`);

            try {
                const testCode = await this.evolutionService.generateTestClass(
                    classInfo.classCode,
                    classInfo.className
                );

                // Validate the generated test
                const analysis = await this.evolutionService.analyzeTestClass(
                    testCode,
                    classInfo.classCode
                );

                if (analysis && analysis.qualityScore >= 60) {
                    generated.push({
                        className: classInfo.className,
                        testClassName: `${classInfo.className}Test`,
                        testCode,
                        qualityScore: analysis.qualityScore,
                        analysis
                    });
                    console.log(`   ✅ Generated with quality score: ${analysis.qualityScore}/100`);
                } else {
                    console.log(`   ⚠️ Generated but quality score too low: ${analysis?.qualityScore || 'N/A'}`);

                    // Still include but flag for review
                    generated.push({
                        className: classInfo.className,
                        testClassName: `${classInfo.className}Test`,
                        testCode,
                        qualityScore: analysis?.qualityScore || 0,
                        analysis,
                        needsReview: true
                    });
                }
            } catch (error) {
                console.log(`   ❌ Error: ${error.message}`);
            }

            // Rate limiting
            await this.sleep(2000);
        }

        return generated;
    }

    /**
     * Save improvements to output directory
     */
    async saveImprovements(improvements, generated) {
        console.log('\n💾 PHASE 5: Saving Results\n');
        console.log('='.repeat(50));

        await fs.ensureDir(this.outputDir);
        await fs.ensureDir(path.join(this.outputDir, 'improved'));
        await fs.ensureDir(path.join(this.outputDir, 'generated'));

        // Save improved test classes
        for (const imp of improvements) {
            const filePath = path.join(this.outputDir, 'improved', `${imp.testClassName}.cls`);
            await fs.writeFile(filePath, imp.improvedCode);

            // Save meta file
            const metaPath = path.join(this.outputDir, 'improved', `${imp.testClassName}.cls-meta.xml`);
            await fs.writeFile(metaPath, this.generateMetaXml());

            console.log(`✅ Saved: improved/${imp.testClassName}.cls`);
        }

        // Save generated test classes
        for (const gen of generated) {
            const filePath = path.join(this.outputDir, 'generated', `${gen.testClassName}.cls`);
            await fs.writeFile(filePath, gen.testCode);

            // Save meta file
            const metaPath = path.join(this.outputDir, 'generated', `${gen.testClassName}.cls-meta.xml`);
            await fs.writeFile(metaPath, this.generateMetaXml());

            console.log(`✅ Saved: generated/${gen.testClassName}.cls`);
        }

        // Generate summary report
        const report = this.generateReport(improvements, generated);
        const reportPath = path.join(this.outputDir, 'improvement-report.md');
        await fs.writeFile(reportPath, report);
        console.log(`\n📊 Report saved: improvement-report.md`);

        // Save JSON data
        const dataPath = path.join(this.outputDir, 'improvement-data.json');
        await fs.writeFile(dataPath, JSON.stringify({
            timestamp: new Date().toISOString(),
            improvements: improvements.map(i => ({
                testClassName: i.testClassName,
                originalScore: i.originalScore,
                newScore: i.newScore,
                improvements: i.improvements
            })),
            generated: generated.map(g => ({
                testClassName: g.testClassName,
                qualityScore: g.qualityScore,
                needsReview: g.needsReview
            }))
        }, null, 2));

        return { reportPath, dataPath };
    }

    /**
     * Generate meta XML for Apex class
     */
    generateMetaXml() {
        return `<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>60.0</apiVersion>
    <status>Active</status>
</ApexClass>`;
    }

    /**
     * Generate markdown report
     */
    generateReport(improvements, generated) {
        const timestamp = new Date().toISOString();

        let report = `# Test Class Improvement Report

Generated: ${timestamp}

## Summary

| Metric | Count |
|--------|-------|
| Test Classes Improved | ${improvements.length} |
| New Test Classes Generated | ${generated.length} |
| Total Files Updated | ${improvements.length + generated.length} |

## Improved Test Classes

`;

        if (improvements.length > 0) {
            report += `| Class | Original Score | New Score | Improvement |
|-------|---------------|-----------|-------------|
`;
            for (const imp of improvements) {
                const improvement = imp.newScore - imp.originalScore;
                report += `| ${imp.testClassName} | ${imp.originalScore} | ${imp.newScore} | +${improvement} |
`;
            }

            report += `
### Improvement Details

`;
            for (const imp of improvements) {
                report += `#### ${imp.testClassName}

**Score:** ${imp.originalScore} → ${imp.newScore}

**Improvements Made:**
${imp.improvements?.map(i => `- ${i}`).join('\n') || '- General improvements applied'}

---

`;
            }
        } else {
            report += '*No test classes were improved (all met quality threshold)*\n\n';
        }

        report += `## Generated Test Classes

`;

        if (generated.length > 0) {
            report += `| Class | Quality Score | Needs Review |
|-------|--------------|--------------|
`;
            for (const gen of generated) {
                report += `| ${gen.testClassName} | ${gen.qualityScore} | ${gen.needsReview ? 'Yes' : 'No'} |
`;
            }
        } else {
            report += '*No new test classes were generated*\n\n';
        }

        report += `
## Next Steps

1. Review the generated/improved test classes in the output directory
2. Deploy to sandbox: \`sf project deploy start --source-dir output/test-improvements -o ${this.targetSandbox}\`
3. Run tests to verify: \`sf apex run test --test-level RunLocalTests -o ${this.targetSandbox}\`
4. Review test results and iterate as needed

## Files Location

- Improved tests: \`output/test-improvements/improved/\`
- Generated tests: \`output/test-improvements/generated/\`
`;

        return report;
    }

    /**
     * Run the full improvement pipeline
     */
    async runFullPipeline(classesDir, options = {}) {
        const startTime = Date.now();

        console.log('\n' + '='.repeat(60));
        console.log('   CONTINUOUS MODERNIZATION - TEST IMPROVEMENT PIPELINE');
        console.log('='.repeat(60));
        console.log(`\nSource Directory: ${classesDir}`);
        console.log(`Target Sandbox: ${this.targetSandbox}`);
        console.log(`Quality Threshold: ${this.qualityThreshold}`);

        try {
            // Phase 1: Analyze existing tests
            const analyses = await this.analyzeTestClasses(classesDir);

            // Phase 2: Find classes without tests
            const classesWithoutTests = await this.findClassesWithoutTests(classesDir);

            // Phase 3: Prioritize
            const { prioritizedTests, classesNeedingTests, plan } =
                this.prioritizeImprovements(analyses, classesWithoutTests);

            // Phase 4: Improve existing tests
            const improvements = await this.improveTestClasses(
                prioritizedTests,
                options.improveLimit || 10
            );

            // Phase 5: Generate missing tests
            const generated = await this.generateMissingTests(
                classesNeedingTests,
                options.generateLimit || 10
            );

            // Phase 6: Save results
            const { reportPath } = await this.saveImprovements(improvements, generated);

            const duration = Math.round((Date.now() - startTime) / 1000);

            console.log('\n' + '='.repeat(60));
            console.log('   PIPELINE COMPLETE');
            console.log('='.repeat(60));
            console.log(`\n✅ Duration: ${duration} seconds`);
            console.log(`✅ Tests Improved: ${improvements.length}`);
            console.log(`✅ Tests Generated: ${generated.length}`);
            console.log(`✅ Report: ${reportPath}`);

            return {
                success: true,
                analyses,
                improvements,
                generated,
                plan,
                duration,
                reportPath
            };

        } catch (error) {
            console.error('\n❌ Pipeline failed:', error.message);
            return {
                success: false,
                error: error.message
            };
        }
    }

    /**
     * Sleep utility
     */
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}
