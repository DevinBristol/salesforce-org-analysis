/**
 * Quality Gate Service - Wraps Claude CLI for code review before deployment
 *
 * This service acts as the final quality check between the autonomous agent
 * framework (which generates improvements) and actual deployment to Salesforce.
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs/promises';
import path from 'path';
import { createLogger } from '../utils/logger.js';

const execAsync = promisify(exec);
const logger = createLogger('QualityGate');

export class QualityGate {
  constructor(options = {}) {
    this.tempDir = options.tempDir || './temp/quality-gate';
    this.timeout = options.timeout || 120000; // 2 minutes for review
    this.maxRetries = options.maxRetries || 2;
  }

  /**
   * Review a proposed code improvement using Claude CLI
   *
   * @param {Object} proposal - The improvement proposal
   * @param {string} proposal.className - Name of the Apex class
   * @param {string} proposal.originalCode - Original source code
   * @param {string} proposal.improvedCode - Agent-generated improved code
   * @param {string[]} proposal.improvements - List of improvements made
   * @param {Object} proposal.metadata - Additional context (coverage, risk, etc.)
   * @returns {Promise<Object>} Review result with approval status and final code
   */
  async review(proposal) {
    const { className, originalCode, improvedCode, improvements, metadata } = proposal;

    logger.info(`Starting quality gate review for ${className}`);

    // Ensure temp directory exists
    await fs.mkdir(this.tempDir, { recursive: true });

    // Build the combined review prompt with code included
    const promptPath = path.join(this.tempDir, `${className}_prompt.md`);
    const prompt = this.buildReviewPrompt(className, improvements, metadata, originalCode, improvedCode);
    await fs.writeFile(promptPath, prompt);

    try {
      // Invoke Claude CLI with the review task
      const result = await this.invokeClaudeCLI(className, promptPath);

      // Parse and validate the response
      const review = this.parseReviewResponse(result);

      // Log the decision
      if (review.approved) {
        logger.info(`APPROVED: ${className} - ${review.reason}`);
      } else {
        logger.warn(`REJECTED: ${className} - ${review.reason}`);
      }

      // Save the final code if approved
      if (review.approved && review.finalCode) {
        const finalPath = path.join(this.tempDir, `${className}_final.cls`);
        await fs.writeFile(finalPath, review.finalCode);
        review.finalCodePath = finalPath;
      }

      return review;

    } catch (error) {
      logger.error(`Quality gate error for ${className}: ${error.message}`);
      return {
        approved: false,
        reason: `Review failed: ${error.message}`,
        error: true
      };
    } finally {
      // Cleanup temp files (optional - keep for debugging)
      // await this.cleanup(className);
    }
  }

  buildReviewPrompt(className, improvements, metadata, originalCode, improvedCode) {
    return `# Code Review Task: ${className}

## Your Role
You are the quality gate reviewer. The autonomous agent framework has generated code improvements. Your job is to:
1. Determine if the changes are genuinely better or over-engineered
2. Simplify if the agent added unnecessary complexity
3. Ensure the code will compile and deploy
4. Return the final approved code (or reject with reason)

## Agent's Claimed Improvements
${improvements.map((imp, i) => `${i + 1}. ${imp}`).join('\n')}

## Context
- Class: ${className}
- Current Coverage: ${metadata?.coverage || 'Unknown'}%
- Risk Level: ${metadata?.riskLevel || 'Unknown'}
- Lines Changed: ${metadata?.linesChanged || 'Unknown'}

## Review Criteria
1. **Simplicity**: Is the improvement actually simpler/cleaner, or did it bloat the code?
2. **Correctness**: Will this compile? Does it change behavior unintentionally?
3. **Value**: Does this improvement provide real value or is it cosmetic?
4. **Logging**: Are there excessive debug statements that should be removed?
5. **Comments**: Are there redundant "IMPROVED:" comments that should be stripped?

## Original Code
\`\`\`apex
${originalCode}
\`\`\`

## Agent's Improved Code
\`\`\`apex
${improvedCode}
\`\`\`

## Your Response Format
Respond with a JSON object (and nothing else) in this exact format:
\`\`\`json
{
  "approved": true|false,
  "reason": "Brief explanation of your decision",
  "changes": ["List of changes you made to simplify/fix"],
  "finalCode": "The complete final Apex code to deploy (if approved)"
}
\`\`\`

If rejecting, set finalCode to null and explain why in reason.`;
  }

  async invokeClaudeCLI(className, promptPath) {
    // Use spawn for better cross-platform compatibility
    // Read the prompt file and pipe to claude
    const { spawn } = await import('child_process');

    logger.info(`Invoking Claude CLI for ${className}...`);

    return new Promise(async (resolve, reject) => {
      // Read prompt content
      const promptContent = await fs.readFile(promptPath, 'utf-8');

      // Use claude with --print flag for non-interactive mode
      const claude = spawn('claude', ['--print'], {
        cwd: process.cwd(),
        shell: true
      });

      let stdout = '';
      let stderr = '';

      claude.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      claude.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      // Set timeout
      const timeoutId = setTimeout(() => {
        claude.kill();
        reject(new Error('Review timed out'));
      }, this.timeout);

      claude.on('close', (code) => {
        clearTimeout(timeoutId);
        if (code !== 0 && !stdout) {
          reject(new Error(`Claude CLI exited with code ${code}: ${stderr}`));
        } else {
          if (stderr && !stderr.includes('warning')) {
            logger.warn(`Claude CLI stderr: ${stderr}`);
          }
          resolve(stdout);
        }
      });

      claude.on('error', (err) => {
        clearTimeout(timeoutId);
        reject(err);
      });

      // Write the prompt to stdin
      claude.stdin.write(promptContent);
      claude.stdin.end();
    });
  }

  parseReviewResponse(response) {
    // Try to extract JSON from the response
    // Claude might include explanation text around the JSON

    const jsonMatch = response.match(/```json\s*([\s\S]*?)\s*```/);
    if (jsonMatch) {
      try {
        return JSON.parse(jsonMatch[1]);
      } catch (e) {
        logger.warn('Failed to parse JSON from code block, trying raw parse');
      }
    }

    // Try to find JSON object directly
    const jsonObjectMatch = response.match(/\{[\s\S]*"approved"[\s\S]*\}/);
    if (jsonObjectMatch) {
      try {
        return JSON.parse(jsonObjectMatch[0]);
      } catch (e) {
        logger.warn('Failed to parse JSON object from response');
      }
    }

    // If no valid JSON, return rejection with the raw response
    return {
      approved: false,
      reason: 'Could not parse review response',
      rawResponse: response.substring(0, 500)
    };
  }

  async cleanup(className) {
    const files = [
      `${className}_original.cls`,
      `${className}_improved.cls`,
      `${className}_prompt.md`,
      `${className}_final.cls`
    ];

    for (const file of files) {
      try {
        await fs.unlink(path.join(this.tempDir, file));
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }

  /**
   * Batch review multiple proposals
   */
  async reviewBatch(proposals) {
    const results = [];

    for (const proposal of proposals) {
      const result = await this.review(proposal);
      results.push({
        className: proposal.className,
        ...result
      });

      // Small delay between reviews to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 1000));
    }

    return results;
  }

  /**
   * Get summary statistics from batch review
   */
  summarize(results) {
    const approved = results.filter(r => r.approved);
    const rejected = results.filter(r => !r.approved);

    return {
      total: results.length,
      approved: approved.length,
      rejected: rejected.length,
      approvalRate: ((approved.length / results.length) * 100).toFixed(1) + '%',
      rejectionReasons: rejected.map(r => ({
        className: r.className,
        reason: r.reason
      }))
    };
  }
}

export default QualityGate;
