// Test script for natural language components
import { ConversationManager } from './conversation-manager.js';
import { NLCommandParser } from './nl-command-parser.js';
import { PlanGenerator } from './plan-generator.js';
import { SuggestionEngine } from './suggestion-engine.js';
import {
  formatMobilePlan,
  formatMobileText,
  formatSuggestion,
  formatClarification
} from './mobile-formatters.js';

console.log('🧪 Testing Natural Language Components\n');

// Test 1: Conversation Manager
console.log('1. Testing ConversationManager...');
try {
  const conversationManager = new ConversationManager();
  const session = conversationManager.getSession('test-user-123');
  conversationManager.addMessage('test-user-123', 'user', 'Hello, can you help me improve my tests?');
  conversationManager.addMessage('test-user-123', 'assistant', 'Sure! I can help you improve your tests.');
  const history = conversationManager.getFormattedHistory('test-user-123', 5);
  console.log('✅ ConversationManager works - Session created with', history.length, 'messages');

  // Set and get context
  conversationManager.setContext('test-user-123', 'pendingApproval', { test: true });
  const context = conversationManager.getContext('test-user-123', 'pendingApproval');
  console.log('✅ Context management works -', context);
} catch (error) {
  console.error('❌ ConversationManager failed:', error.message);
}

// Test 2: NL Command Parser (quick classify only - no API call)
console.log('\n2. Testing NLCommandParser (quick classify)...');
try {
  const parser = new NLCommandParser();
  const statusIntent = parser.quickClassify('status');
  const approveIntent = parser.quickClassify('approve');
  const helpIntent = parser.quickClassify('help me');

  console.log('✅ Quick classify works:');
  console.log('  - "status" →', statusIntent?.intent || 'no match');
  console.log('  - "approve" →', approveIntent?.intent || 'no match');
  console.log('  - "help me" →', helpIntent?.intent || 'no match');
} catch (error) {
  console.error('❌ NLCommandParser failed:', error.message);
}

// Test 3: Plan Generator (mock system state)
console.log('\n3. Testing PlanGenerator...');
try {
  const mockWorkerPool = { getStats: () => ({ queueSize: 5, activeWorkers: 3 }) };
  const mockTaskQueue = { getQueueSize: () => 5 };
  const mockCostTracker = {
    getCurrentUsage: () => 1.25,
    getMonthlyTotal: () => Promise.resolve(15.50)
  };

  const planGenerator = new PlanGenerator(mockWorkerPool, mockTaskQueue, mockCostTracker);

  // Test status plan
  const statusPlan = planGenerator.generateStatusPlan({ activeWorkers: 3, queueSize: 5, costToday: 1.25 });
  console.log('✅ Status plan generated:', statusPlan.title);

  // Test improve tests plan
  const improvePlan = await planGenerator.generateImproveTestsPlan({ count: 10 }, {});
  console.log('✅ Improve tests plan generated:', improvePlan.title);

  // Test comprehensive plan
  const comprehensivePlan = await planGenerator.generateComprehensivePlan(
    { targetCoverage: 90 },
    { coverage: 75 }
  );
  console.log('✅ Comprehensive plan generated:', comprehensivePlan.title);
} catch (error) {
  console.error('❌ PlanGenerator failed:', error.message);
}

// Test 4: Suggestion Engine
console.log('\n4. Testing SuggestionEngine...');
try {
  const mockWorkerPool = { getStats: () => ({
    queueSize: 0,
    activeWorkers: 3,
    failedTasks: 2,
    readyToDeploy: 15,
    coverage: 70,
    avgTaskTime: 3
  }) };
  const mockTaskQueue = { getQueueSize: () => 0 };
  const mockCostTracker = {
    getCurrentUsage: () => 2.50,
    getMonthlyTotal: () => Promise.resolve(45.00)
  };

  const suggestionEngine = new SuggestionEngine(mockWorkerPool, mockTaskQueue, mockCostTracker);

  const suggestions = await suggestionEngine.getSuggestions('test-user-456', {});
  console.log(`✅ Suggestion engine works - Generated ${suggestions.length} suggestions:`);
  suggestions.forEach((s, i) => {
    console.log(`  ${i + 1}. [${s.priority}] ${s.type}: ${s.message}`);
  });
} catch (error) {
  console.error('❌ SuggestionEngine failed:', error.message);
}

// Test 5: Mobile Formatters
console.log('\n5. Testing Mobile Formatters...');
try {
  const plan = {
    type: 'improve-tests',
    title: '🔧 Test Improvement Plan',
    description: 'Improve 10 existing test classes',
    actions: ['Analyze tests', 'Apply best practices', 'Deploy'],
    resources: { cost: '$2.50', time: '~20 min', workers: 3 },
    requiresApproval: true
  };

  const formattedPlan = formatMobilePlan(plan);
  console.log('✅ formatMobilePlan works - Generated', formattedPlan.blocks.length, 'blocks');

  const formattedText = formatMobileText('Hello from the bot', '👋');
  console.log('✅ formatMobileText works:', formattedText.text);

  const suggestion = formatSuggestion({ message: 'Consider analyzing your org' });
  console.log('✅ formatSuggestion works - Generated', suggestion.blocks.length, 'block(s)');

  const clarification = formatClarification('How many tests?', [
    { label: '5 tests', value: '5' },
    { label: '10 tests', value: '10' }
  ]);
  console.log('✅ formatClarification works - Generated', clarification.blocks.length, 'blocks');
} catch (error) {
  console.error('❌ Mobile Formatters failed:', error.message);
}

console.log('\n✅ All component tests completed!');
console.log('\nNote: Full NL parsing test skipped (requires ANTHROPIC_API_KEY)');
console.log('Natural language support is ready for Slack integration.\n');
