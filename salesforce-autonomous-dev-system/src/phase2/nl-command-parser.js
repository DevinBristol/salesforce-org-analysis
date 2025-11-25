// src/phase2/nl-command-parser.js
// Natural Language Command Parser - Uses Claude to understand user intent

import { Anthropic } from '@anthropic-ai/sdk';
import { z } from 'zod';
import { trackApiUsage } from '../utils/ai-cost-tracker.js';

// Define intent schema
const CommandIntentSchema = z.object({
  intent: z.string(), // The detected command intent
  confidence: z.number().min(0).max(1), // Confidence level 0-1
  operationType: z.enum(['salesforce', 'local']), // Type of operation
  command: z.string().nullable(), // Mapped command or null if needs clarification
  parameters: z.record(z.any()), // Extracted parameters
  requiresClarification: z.boolean(), // Whether we need more info
  clarificationQuestion: z.string().nullable(), // Question to ask user if clarification needed
  reasoning: z.string() // Why this intent was chosen
});

export class NLCommandParser {
  constructor() {
    this.anthropic = new Anthropic({
      apiKey: process.env.ANTHROPIC_API_KEY,
      timeout: 120000,
      maxRetries: 3
    });
  }

  /**
   * Parse natural language message into structured command intent
   * @param {string} message - User's natural language message
   * @param {Array} conversationHistory - Previous messages for context
   * @param {Object} systemState - Current system state for context
   */
  async parseIntent(message, conversationHistory = [], systemState = {}) {
    try {
      const systemPrompt = this.buildSystemPrompt();
      const userPrompt = this.buildUserPrompt(message, conversationHistory, systemState);

      const response = await this.anthropic.messages.create({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 1000,
        temperature: 0.3,
        system: [
          {
            type: "text",
            text: systemPrompt,
            cache_control: { type: "ephemeral" }
          }
        ],
        messages: [{ role: 'user', content: userPrompt }]
      }, {
        headers: {
          'anthropic-beta': 'prompt-caching-2024-07-31'
        }
      });

      // Parse and validate response
      let responseText = response.content[0].text;

      // Strip markdown code blocks if present (```json ... ``` or ``` ... ```)
      responseText = responseText.replace(/```json\s*/g, '').replace(/```\s*/g, '').trim();

      const rawData = JSON.parse(responseText);
      const result = CommandIntentSchema.safeParse(rawData);

      if (!result.success) {
        console.error('Intent schema validation failed:', result.error.errors);
        return this.createFallbackIntent(message);
      }

      // Track cost
      trackApiUsage(response);

      return result.data;

    } catch (error) {
      console.error('Intent parsing failed:', error);
      return this.createFallbackIntent(message);
    }
  }

  buildSystemPrompt() {
    return `You are an intent parser for a unified Slack bot that handles BOTH Salesforce operations AND local repository operations. Your job is to understand what the user wants and route it correctly.

**SALESFORCE OPERATIONS (operationType: "salesforce"):**

**Test Management:**
- status: Show system status
- improve-tests [count]: Improve Salesforce tests
- generate-tests [count] [--coverage=X]: Generate new Apex tests
- quality-scan [className]: Analyze Apex test quality
- comprehensive-improve [--target-coverage=X]: Full improvement workflow
- rewrite-test [testClassName]: Rewrite an Apex test

**Org Analysis:**
- analyze-org [--deep]: Analyze entire Salesforce org
- coverage-report [--by-package]: Show coverage breakdown
- find-issues [--type=TYPE]: Find Salesforce code issues

**Deployment:**
- deploy-queue [--validate-only]: Deploy to Salesforce
- validate-deployment: Validate Salesforce deployment
- rollback [deploymentId]: Rollback Salesforce deployment

---

**LOCAL REPOSITORY OPERATIONS (operationType: "local"):**

**Code Analysis:**
- analyze-codebase [repo]: Analyze local codebase architecture
- search-code [pattern] [repo]: Search for code patterns
- find-files [pattern] [repo]: Find files matching pattern

**Code Editing:**
- edit-files [files] [instructions] [repo]: Edit multiple files
- refactor-code [description] [repo]: Refactor local code
- rename-symbol [old] [new] [repo]: Rename variables/functions across files

**Git Operations:**
- git-status [repo]: Show git status
- git-commit [message] [repo]: Commit changes
- git-push [repo]: Push to remote
- git-create-branch [name] [repo]: Create new branch
- git-diff [repo]: Show diff

**Testing & Building:**
- run-tests [repo]: Run local tests
- run-build [repo]: Build project

---

**SHARED OPERATIONS (can be either type):**

**Queue Management:**
- queue-status [taskId]: Check task queue
- pause-queue: Pause processing
- resume-queue: Resume processing
- cancel-task [taskId]: Cancel a task

**Budget & Monitoring:**
- cost [--forecast]: Show cost report
- workers [scale [count]]: Manage workers

**System:**
- stop: Stop workers
- help [command]: Show help
- report [--email]: Generate report

---

**ROUTING LOGIC - How to determine operationType:**

**Indicators for "salesforce":**
- Keywords: "salesforce", "apex", "org", "deployment", "coverage", "sandbox"
- Mentions: "AccountTriggerTest", "OpportunityHandler", class names ending in "Test"
- Phrases: "improve apex tests", "deploy to salesforce", "org coverage"

**Indicators for "local":**
- Keywords: "local", "repo", "codebase", "node", "javascript", "git", "refactor"
- File mentions: "slack-bot.js", ".js files", "package.json", "src/"
- Phrases: "my local code", "this repository", "git commit", "analyze the codebase"

**When AMBIGUOUS:**
- If you're 50/50, ask for clarification
- Set requiresClarification=true
- Ask: "Are you referring to Salesforce operations or local repository code?"

**Examples:**
- "improve 10 tests" → Could be either! Ask for clarification
- "improve 10 apex tests" → Salesforce (keyword "apex")
- "refactor slack-bot.js" → Local (specific file mentioned)
- "show status" → Salesforce (default for status unless context says otherwise)
- "git status" → Local (git operation)
- "commit my changes" → Local (git context)

---

**Your Task:**
1. Understand the user's intent
2. Determine operationType: "salesforce" or "local"
3. Map to appropriate command
4. Extract parameters (including repo name for local operations)
5. If ambiguous, ask for clarification
6. Provide confidence level (0-1)
7. Always respond in JSON

**Important:**
- Consider conversation history for context
- Handle casual language
- Extract parameters: "10 tests" → count=10, "slack-bot.js" → file=slack-bot.js
- If user says "yes" or "approve", intent is "approve-plan"
- Default repo for local operations is "salesforce-autonomous-dev-system"

**Response Format:**
{
  "intent": "Brief description of what user wants",
  "confidence": 0.95,
  "operationType": "salesforce" or "local",
  "command": "improve-tests" or "refactor-code" or null,
  "parameters": {"count": 10, "repo": "salesforce-autonomous-dev-system"},
  "requiresClarification": false,
  "clarificationQuestion": null,
  "reasoning": "User mentioned 'apex tests' which indicates Salesforce operation"
}`;
  }

  buildUserPrompt(message, conversationHistory, systemState) {
    let prompt = `Parse this user message into a command intent:\n\n`;
    prompt += `**User Message:** "${message}"\n\n`;

    // Add conversation context if available
    if (conversationHistory.length > 0) {
      prompt += `**Recent Conversation:**\n`;
      conversationHistory.slice(-3).forEach(msg => {
        prompt += `${msg.role === 'user' ? 'User' : 'Bot'}: ${msg.content}\n`;
      });
      prompt += `\n`;
    }

    // Add system state context
    if (Object.keys(systemState).length > 0) {
      prompt += `**System State:**\n`;
      if (systemState.queueSize !== undefined) {
        prompt += `- Queue size: ${systemState.queueSize}\n`;
      }
      if (systemState.coverage !== undefined) {
        prompt += `- Org coverage: ${systemState.coverage}%\n`;
      }
      if (systemState.activeWorkers !== undefined) {
        prompt += `- Active workers: ${systemState.activeWorkers}\n`;
      }
      prompt += `\n`;
    }

    prompt += `Parse the intent and return JSON.`;

    return prompt;
  }

  /**
   * Create fallback intent when parsing fails
   */
  createFallbackIntent(message) {
    return {
      intent: "Unclear request",
      confidence: 0,
      operationType: 'salesforce', // Default to salesforce
      command: null,
      parameters: {},
      requiresClarification: true,
      clarificationQuestion: "I'm not sure what you'd like me to do. Could you rephrase or use commands like:\n• Salesforce: 'improve tests', 'analyze org', 'show coverage'\n• Local Repo: 'refactor code', 'git status', 'analyze codebase'",
      reasoning: "Failed to parse intent"
    };
  }

  /**
   * Quick intent classification for common patterns (no API call)
   */
  quickClassify(message) {
    const lowered = message.toLowerCase().trim();

    // Check for git operations (always local)
    if (lowered.startsWith('git ') || lowered.includes('git status') || lowered.includes('git commit')) {
      return {
        intent: 'git operation',
        confidence: 0.9,
        operationType: 'local',
        command: 'git-status', // Default, will be refined by full parser
        parameters: {},
        requiresClarification: false,
        clarificationQuestion: null,
        reasoning: 'Git operation detected',
        isQuickMatch: true
      };
    }

    // Simple keyword matching for very common cases
    const patterns = {
      'status': {
        pattern: /^(status|what's (the )?status|how('s| is) (it|the system|everything))/,
        operationType: 'salesforce'
      },
      'approve': {
        pattern: /^(approve|approved|yes|confirm|ok|do it|let's do it|go ahead)/,
        operationType: 'salesforce' // default
      },
      'cancel': {
        pattern: /^(cancel|no|stop|abort|don't|nevermind)/,
        operationType: 'salesforce' // default
      },
      'help': {
        pattern: /^(help|what can you do|commands)/,
        operationType: 'salesforce' // default
      }
    };

    for (const [intent, config] of Object.entries(patterns)) {
      if (config.pattern.test(lowered)) {
        return {
          intent,
          confidence: 0.9,
          operationType: config.operationType,
          command: intent === 'approve' || intent === 'cancel' ? null : intent,
          parameters: {},
          requiresClarification: false,
          clarificationQuestion: null,
          reasoning: 'Quick pattern match',
          isQuickMatch: true
        };
      }
    }

    return null; // No quick match, use full parsing
  }
}
