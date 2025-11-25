/**
 * Test script for Quality Gate integration
 *
 * Tests the Claude CLI quality gate review on the Five9Response proposal
 * to verify it properly simplifies over-engineered code.
 */

import { QualityGate } from '../src/services/quality-gate.js';
import fs from 'fs/promises';
import path from 'path';

async function main() {
  console.log('='.repeat(60));
  console.log('Quality Gate Test - Five9Response Review');
  console.log('='.repeat(60));

  // Load the proposal data
  const dataPath = path.join(process.cwd(), 'output/demo-apex-improvement/data.json');
  console.log(`\nLoading proposal from: ${dataPath}`);

  const data = JSON.parse(await fs.readFile(dataPath, 'utf-8'));

  console.log(`\nTarget: ${data.target.className}`);
  console.log(`Risk Level: ${data.target.riskLevel}`);
  console.log(`Original Lines: ${data.originalCode.split('\n').length}`);
  console.log(`Improved Lines: ${data.improvedCode.split('\n').length}`);
  console.log(`Code Growth: ${((data.improvedCode.split('\n').length / data.originalCode.split('\n').length) * 100 - 100).toFixed(1)}%`);

  // Parse improvements list
  const improvements = data.improvements.split('\n')
    .filter(line => line.match(/^\d+\./))
    .map(line => line.replace(/^\d+\.\s*/, '').trim());

  console.log(`\nAgent claimed ${improvements.length} improvements:`);
  improvements.forEach((imp, i) => console.log(`  ${i + 1}. ${imp.substring(0, 60)}...`));

  // Create proposal for quality gate
  const proposal = {
    className: data.target.className,
    originalCode: data.originalCode,
    improvedCode: data.improvedCode,
    improvements: improvements,
    metadata: {
      coverage: 'Unknown',
      riskLevel: data.target.riskLevel,
      linesChanged: Math.abs(data.improvedCode.split('\n').length - data.originalCode.split('\n').length)
    }
  };

  // Initialize quality gate
  const qualityGate = new QualityGate({
    timeout: 180000 // 3 minutes for thorough review
  });

  console.log('\n' + '-'.repeat(60));
  console.log('Submitting to Claude CLI Quality Gate...');
  console.log('-'.repeat(60));
  console.log('\nThis will invoke Claude CLI to review the proposed changes.');
  console.log('Expected outcome: REJECT or APPROVE with simplifications\n');

  const startTime = Date.now();

  try {
    const review = await qualityGate.review(proposal);
    const duration = ((Date.now() - startTime) / 1000).toFixed(1);

    console.log('\n' + '='.repeat(60));
    console.log(`QUALITY GATE RESULT (${duration}s)`);
    console.log('='.repeat(60));

    console.log(`\nDecision: ${review.approved ? '✅ APPROVED' : '❌ REJECTED'}`);
    console.log(`Reason: ${review.reason}`);

    if (review.changes && review.changes.length > 0) {
      console.log(`\nChanges made by reviewer:`);
      review.changes.forEach((change, i) => console.log(`  ${i + 1}. ${change}`));
    }

    if (review.finalCode) {
      const finalLines = review.finalCode.split('\n').length;
      const originalLines = data.originalCode.split('\n').length;
      const improvedLines = data.improvedCode.split('\n').length;

      console.log(`\nCode Statistics:`);
      console.log(`  Original:  ${originalLines} lines`);
      console.log(`  Agent:     ${improvedLines} lines (+${((improvedLines/originalLines - 1) * 100).toFixed(0)}%)`);
      console.log(`  Final:     ${finalLines} lines (${((finalLines/originalLines - 1) * 100).toFixed(0)}% vs original)`);

      // Save final code
      const outputDir = path.join(process.cwd(), 'output/quality-gate-test');
      await fs.mkdir(outputDir, { recursive: true });

      await fs.writeFile(
        path.join(outputDir, 'Five9Response_final.cls'),
        review.finalCode
      );
      console.log(`\nFinal code saved to: output/quality-gate-test/Five9Response_final.cls`);
    }

    if (review.error) {
      console.log(`\n⚠️  Review had errors: ${review.rawResponse?.substring(0, 200) || 'Unknown'}`);
    }

    // Save full review result
    const outputDir = path.join(process.cwd(), 'output/quality-gate-test');
    await fs.mkdir(outputDir, { recursive: true });
    await fs.writeFile(
      path.join(outputDir, 'review-result.json'),
      JSON.stringify(review, null, 2)
    );
    console.log(`Review result saved to: output/quality-gate-test/review-result.json`);

  } catch (error) {
    console.error(`\n❌ Quality gate test failed: ${error.message}`);
    console.error(error.stack);
    process.exit(1);
  }

  console.log('\n' + '='.repeat(60));
  console.log('Quality Gate Test Complete');
  console.log('='.repeat(60));
}

main().catch(console.error);
