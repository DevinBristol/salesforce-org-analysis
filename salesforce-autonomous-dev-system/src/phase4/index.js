/**
 * Phase 4: Autonomous Orchestration Platform
 *
 * This module exports all Phase 4 components for the
 * Salesforce Autonomous Development System.
 */

// Core Components
import { ResultCallbackSystem } from './result-callback.js';
import { ProgressReporter } from './progress-reporter.js';
import { EnhancedConversationManager } from './conversation-manager-enhanced.js';
import { MonitoringSystem } from './monitoring-system.js';
import { ClaudeCodeOrchestrator } from './claude-orchestrator.js';
import { WorkflowEngine } from './workflow-engine.js';
import { EnhancedWorkerPool } from './worker-pool-enhanced.js';

// Migrations
import { Phase4Migration, migrations } from './migrate-phase4.js';

// Main System
import { Phase4System } from './main.js';

export {
    // Core Components
    ResultCallbackSystem,
    ProgressReporter,
    EnhancedConversationManager,
    MonitoringSystem,
    ClaudeCodeOrchestrator,
    WorkflowEngine,
    EnhancedWorkerPool,

    // Migrations
    Phase4Migration,
    migrations,

    // Main System
    Phase4System
};

// Version info
export const version = '4.0.0';
export const name = 'Autonomous Orchestration Platform';
