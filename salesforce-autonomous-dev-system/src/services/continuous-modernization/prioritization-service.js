/**
 * Prioritization Service
 *
 * Implements intelligent prioritization of test improvements
 * based on risk, impact, effort, and dependencies.
 */

export class PrioritizationService {
    constructor(config = {}) {
        this.weights = {
            risk: config.riskWeight || 0.35,
            impact: config.impactWeight || 0.30,
            effort: config.effortWeight || 0.20,
            dependencies: config.dependenciesWeight || 0.15
        };
    }

    /**
     * Calculate priority score for a test improvement
     */
    calculatePriorityScore(testAnalysis) {
        const risk = this.calculateRisk(testAnalysis);
        const impact = this.calculateImpact(testAnalysis);
        const effort = this.calculateEffort(testAnalysis);
        const dependencies = this.calculateDependencies(testAnalysis);

        const score =
            (risk * this.weights.risk) +
            (impact * this.weights.impact) +
            ((100 - effort) * this.weights.effort) + // Inverse - lower effort = higher priority
            (dependencies * this.weights.dependencies);

        return {
            priorityScore: Math.round(score),
            components: { risk, impact, effort, dependencies },
            category: this.categorize(impact, effort),
            isQuickWin: impact >= 60 && effort <= 30
        };
    }

    /**
     * Calculate risk score based on class characteristics
     */
    calculateRisk(analysis) {
        let risk = 0;

        // Classes with low test coverage are higher risk
        if (analysis.qualityScore < 30) {
            risk += 40;
        } else if (analysis.qualityScore < 50) {
            risk += 25;
        } else if (analysis.qualityScore < 70) {
            risk += 10;
        }

        // Anti-patterns increase risk
        if (analysis.antiPatterns) {
            const criticalPatterns = analysis.antiPatterns.filter(p => p.severity === 'critical');
            const highPatterns = analysis.antiPatterns.filter(p => p.severity === 'high');
            risk += criticalPatterns.length * 15;
            risk += highPatterns.length * 8;
        }

        // Missing assertions are high risk
        if (analysis.dimensions?.assertions?.meaningfulCount === 0) {
            risk += 20;
        }

        // No bulk testing is risky
        if (!analysis.dimensions?.bulkTesting?.hasTests200Records) {
            risk += 15;
        }

        return Math.min(risk, 100);
    }

    /**
     * Calculate impact of improving this test
     */
    calculateImpact(analysis) {
        let impact = 0;

        // Quality improvement potential
        const potentialGain = analysis.improvementPotential?.estimatedNewScore - analysis.qualityScore || 0;
        impact += potentialGain * 0.5;

        // Missing tests have high impact
        if (analysis.missingTests) {
            impact += Math.min(analysis.missingTests.length * 5, 30);
        }

        // Fixing anti-patterns has high impact
        if (analysis.antiPatterns) {
            impact += Math.min(analysis.antiPatterns.length * 8, 30);
        }

        // Improving coverage has impact
        if (analysis.dimensions?.bulkTesting?.score < 50) {
            impact += 15;
        }

        return Math.min(impact, 100);
    }

    /**
     * Estimate effort to improve this test
     */
    calculateEffort(analysis) {
        let effort = 20; // Base effort

        // More anti-patterns = more effort
        if (analysis.antiPatterns) {
            effort += analysis.antiPatterns.length * 5;
        }

        // More missing tests = more effort
        if (analysis.missingTests) {
            effort += analysis.missingTests.length * 8;
        }

        // Complex improvements take more effort
        if (analysis.improvementPotential?.effort === 'high') {
            effort += 30;
        } else if (analysis.improvementPotential?.effort === 'medium') {
            effort += 15;
        }

        return Math.min(effort, 100);
    }

    /**
     * Calculate dependency impact (how many other classes depend on this)
     */
    calculateDependencies(analysis) {
        // Default low dependency score - would need codebase graph for accurate calculation
        return analysis.dependencyCount ? Math.min(analysis.dependencyCount * 5, 100) : 20;
    }

    /**
     * Categorize into priority matrix quadrant
     */
    categorize(impact, effort) {
        if (impact >= 60 && effort <= 40) return 'QUICK_WIN';
        if (impact >= 60 && effort > 40) return 'STRATEGIC';
        if (impact < 60 && effort <= 40) return 'FILL_IN';
        return 'MONEY_PIT';
    }

    /**
     * Prioritize a list of test analyses
     */
    prioritizeTests(testAnalyses) {
        const scored = testAnalyses.map(analysis => ({
            ...analysis,
            priority: this.calculatePriorityScore(analysis)
        }));

        // Sort by priority score (highest first)
        scored.sort((a, b) => b.priority.priorityScore - a.priority.priorityScore);

        // Add rank
        return scored.map((item, index) => ({
            ...item,
            rank: index + 1
        }));
    }

    /**
     * Get quick wins from prioritized list
     */
    getQuickWins(prioritizedTests, limit = 10) {
        return prioritizedTests
            .filter(t => t.priority.isQuickWin)
            .slice(0, limit);
    }

    /**
     * Generate improvement plan
     */
    generateImprovementPlan(prioritizedTests) {
        const quickWins = this.getQuickWins(prioritizedTests);
        const strategic = prioritizedTests.filter(t => t.priority.category === 'STRATEGIC');
        const fillIns = prioritizedTests.filter(t => t.priority.category === 'FILL_IN');

        const totalEffortMinutes = quickWins.reduce((sum, t) =>
            sum + this.effortToMinutes(t.priority.components.effort), 0
        );

        return {
            summary: {
                totalTests: prioritizedTests.length,
                quickWinCount: quickWins.length,
                strategicCount: strategic.length,
                fillInCount: fillIns.length,
                estimatedQuickWinHours: Math.ceil(totalEffortMinutes / 60),
                averagePriorityScore: Math.round(
                    prioritizedTests.reduce((sum, t) => sum + t.priority.priorityScore, 0) / prioritizedTests.length
                )
            },
            phases: [
                {
                    name: 'Phase 1: Quick Wins',
                    description: 'High impact, low effort improvements',
                    tests: quickWins.map(t => t.testClassName || t.className),
                    estimatedHours: Math.ceil(totalEffortMinutes / 60)
                },
                {
                    name: 'Phase 2: Strategic Improvements',
                    description: 'High impact improvements requiring more effort',
                    tests: strategic.slice(0, 10).map(t => t.testClassName || t.className),
                    estimatedHours: 'Variable based on complexity'
                },
                {
                    name: 'Phase 3: Fill-ins',
                    description: 'Lower impact quick improvements',
                    tests: fillIns.slice(0, 10).map(t => t.testClassName || t.className),
                    estimatedHours: Math.ceil(fillIns.slice(0, 10).length * 0.5)
                }
            ],
            recommendations: this.generateRecommendations(prioritizedTests)
        };
    }

    /**
     * Convert effort score to estimated minutes
     */
    effortToMinutes(effortScore) {
        // Effort 0-100 maps to 15-120 minutes
        return 15 + (effortScore * 1.05);
    }

    /**
     * Generate improvement recommendations
     */
    generateRecommendations(prioritizedTests) {
        const recommendations = [];

        // Check for common patterns
        const noBulkTesting = prioritizedTests.filter(
            t => !t.dimensions?.bulkTesting?.hasTests200Records
        ).length;

        if (noBulkTesting > prioritizedTests.length * 0.5) {
            recommendations.push({
                type: 'PATTERN',
                priority: 'HIGH',
                message: `${noBulkTesting} test classes lack bulk testing. Consider creating a bulk testing utility.`
            });
        }

        const noTestSetup = prioritizedTests.filter(
            t => !t.dimensions?.testDataPractices?.usesTestSetup
        ).length;

        if (noTestSetup > prioritizedTests.length * 0.3) {
            recommendations.push({
                type: 'PATTERN',
                priority: 'MEDIUM',
                message: `${noTestSetup} test classes don't use @TestSetup. Implementing this pattern will improve test performance.`
            });
        }

        const criticalAntiPatterns = prioritizedTests.filter(t =>
            t.antiPatterns?.some(ap => ap.severity === 'critical')
        ).length;

        if (criticalAntiPatterns > 0) {
            recommendations.push({
                type: 'URGENT',
                priority: 'CRITICAL',
                message: `${criticalAntiPatterns} test classes have critical anti-patterns that should be fixed immediately.`
            });
        }

        return recommendations;
    }
}
