// src/phase2/local-repo-worker.js
// Local Repository Worker - Handles local code operations in worker thread

import { parentPort, workerData } from 'worker_threads';
import { Anthropic } from '@anthropic-ai/sdk';
import dotenv from 'dotenv';
import fs from 'fs-extra';
import path from 'path';
import { RepoManager } from '../services/repo-manager.js';
import { exec } from 'child_process';
import { promisify } from 'util';

dotenv.config();

const execAsync = promisify(exec);

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
  timeout: 120000,
  maxRetries: 3
});

// Initialize repo manager
const workspaceRoot = process.env.WORKSPACE_ROOT || 'C:\\Users\\devin\\IdeaProjects\\DevAgentWorkspace';
const repoManager = new RepoManager(workspaceRoot);

// Worker message handler
parentPort.on('message', async (msg) => {
  if (msg.type === 'EXECUTE_TASK') {
    await executeTask(msg.task);
  }
});

async function executeTask(task) {
  try {
    console.log(`Local Worker ${workerData.workerId}: Processing task ${task.id} (${task.type})`);

    // Execute based on task type
    let result;
    switch (task.type) {
      // File Operations
      case 'read-file':
        result = await readFile(task);
        break;
      case 'write-file':
        result = await writeFile(task);
        break;
      case 'edit-files':
        result = await editFiles(task);
        break;
      case 'delete-file':
        result = await deleteFile(task);
        break;

      // Code Analysis
      case 'analyze-codebase':
        result = await analyzeCodebase(task);
        break;
      case 'search-code':
        result = await searchCode(task);
        break;
      case 'find-pattern':
        result = await findPattern(task);
        break;

      // Refactoring
      case 'refactor-code':
        result = await refactorCode(task);
        break;
      case 'rename-symbol':
        result = await renameSymbol(task);
        break;
      case 'extract-function':
        result = await extractFunction(task);
        break;

      // Git Operations
      case 'git-status':
        result = await gitStatus(task);
        break;
      case 'git-commit':
        result = await gitCommit(task);
        break;
      case 'git-push':
        result = await gitPush(task);
        break;
      case 'git-create-branch':
        result = await gitCreateBranch(task);
        break;
      case 'git-diff':
        result = await gitDiff(task);
        break;

      // Testing
      case 'run-tests':
        result = await runTests(task);
        break;
      case 'run-build':
        result = await runBuild(task);
        break;

      default:
        throw new Error(`Unknown task type: ${task.type}`);
    }

    // Send progress updates
    parentPort.postMessage({
      type: 'PROGRESS',
      progress: {
        taskId: task.id,
        stage: 'completed',
        percentage: 100
      }
    });

    // Send completion message
    parentPort.postMessage({
      type: 'TASK_COMPLETE',
      result: {
        taskId: task.id,
        success: true,
        data: result
      }
    });

    // Report cost if API was used
    if (result.usage) {
      parentPort.postMessage({
        type: 'COST_UPDATE',
        usage: {
          model: result.usage.model || 'claude-sonnet-4-20250514',
          inputTokens: result.usage.inputTokens || 0,
          outputTokens: result.usage.outputTokens || 0,
          cacheCreationTokens: result.usage.cacheCreationTokens || 0,
          cacheReadTokens: result.usage.cacheReadTokens || 0
        }
      });
    }

  } catch (error) {
    console.error(`Worker ${workerData.workerId}: Task ${task.id} failed:`, error);

    parentPort.postMessage({
      type: 'TASK_FAILED',
      result: {
        taskId: task.id,
        success: false,
        error: error.message,
        stack: error.stack
      }
    });
  }
}

// ==================== FILE OPERATIONS ====================

async function readFile(task) {
  const { filePath } = task.payload;
  const fullPath = path.isAbsolute(filePath) ? filePath : path.join(workspaceRoot, filePath);

  const content = await fs.readFile(fullPath, 'utf-8');

  return {
    filePath,
    content,
    lines: content.split('\n').length,
    size: Buffer.byteLength(content, 'utf-8')
  };
}

async function writeFile(task) {
  const { filePath, content } = task.payload;
  const fullPath = path.isAbsolute(filePath) ? filePath : path.join(workspaceRoot, filePath);

  // Ensure directory exists
  await fs.ensureDir(path.dirname(fullPath));

  // Write file
  await fs.writeFile(fullPath, content, 'utf-8');

  return {
    filePath,
    written: true,
    size: Buffer.byteLength(content, 'utf-8')
  };
}

async function editFiles(task) {
  const { files, instructions } = task.payload;

  reportProgress(task.id, 'Reading files', 10);

  // Read all files
  const fileContents = await Promise.all(
    files.map(async (file) => {
      const fullPath = path.isAbsolute(file) ? file : path.join(workspaceRoot, file);
      const content = await fs.readFile(fullPath, 'utf-8');
      return { path: file, content };
    })
  );

  reportProgress(task.id, 'Planning edits with Claude', 30);

  // Use Claude to plan edits
  const prompt = buildEditPrompt(fileContents, instructions);
  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 8000,
    temperature: 0.3,
    system: [
      {
        type: "text",
        text: "You are a code editor. Analyze the provided files and return structured edits to apply the requested changes. Return JSON with an array of edits.",
        cache_control: { type: "ephemeral" }
      }
    ],
    messages: [{ role: 'user', content: prompt }]
  }, {
    headers: {
      'anthropic-beta': 'prompt-caching-2024-07-31'
    }
  });

  const edits = JSON.parse(response.content[0].text);

  reportProgress(task.id, 'Applying edits', 70);

  // Apply edits
  const results = [];
  for (const edit of edits.edits) {
    const fullPath = path.isAbsolute(edit.file) ? edit.file : path.join(workspaceRoot, edit.file);
    const content = await fs.readFile(fullPath, 'utf-8');

    // Apply the edit (simple search-replace for now)
    const newContent = content.replace(edit.old, edit.new);

    await fs.writeFile(fullPath, newContent, 'utf-8');

    results.push({
      file: edit.file,
      applied: true
    });
  }

  return {
    filesEdited: results.length,
    files: results,
    usage: {
      model: response.model,
      inputTokens: response.usage.input_tokens,
      outputTokens: response.usage.output_tokens,
      cacheCreationTokens: response.usage.cache_creation_input_tokens || 0,
      cacheReadTokens: response.usage.cache_read_input_tokens || 0
    }
  };
}

async function deleteFile(task) {
  const { filePath } = task.payload;
  const fullPath = path.isAbsolute(filePath) ? filePath : path.join(workspaceRoot, filePath);

  await fs.remove(fullPath);

  return {
    filePath,
    deleted: true
  };
}

// ==================== CODE ANALYSIS ====================

async function analyzeCodebase(task) {
  const { repo, scope = 'full' } = task.payload;

  reportProgress(task.id, 'Scanning codebase', 10);

  // Set the repo
  repoManager.setRepo(repo);
  const repoRoot = repoManager.getCurrentRepo();

  // Get file tree
  const files = await getFileTree(repoRoot, scope);

  reportProgress(task.id, 'Analyzing with Claude', 40);

  // Build analysis prompt
  const prompt = buildAnalysisPrompt(files, scope);

  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 4000,
    temperature: 0.3,
    system: [
      {
        type: "text",
        text: "You are a senior software architect. Analyze codebases and provide architectural insights, identify patterns, and suggest improvements.",
        cache_control: { type: "ephemeral" }
      }
    ],
    messages: [{ role: 'user', content: prompt }]
  }, {
    headers: {
      'anthropic-beta': 'prompt-caching-2024-07-31'
    }
  });

  const analysis = response.content[0].text;

  return {
    repo,
    analysis,
    fileCount: files.length,
    usage: {
      model: response.model,
      inputTokens: response.usage.input_tokens,
      outputTokens: response.usage.output_tokens,
      cacheCreationTokens: response.usage.cache_creation_input_tokens || 0,
      cacheReadTokens: response.usage.cache_read_input_tokens || 0
    }
  };
}

async function searchCode(task) {
  const { repo, pattern, filePattern = '**/*.js' } = task.payload;

  repoManager.setRepo(repo);
  const repoRoot = repoManager.getCurrentRepo();

  // Use grep-like search
  const { stdout } = await execAsync(
    `grep -r -n "${pattern}" --include="${filePattern}" .`,
    { cwd: repoRoot, maxBuffer: 10 * 1024 * 1024 }
  );

  const matches = stdout.trim().split('\n').map(line => {
    const [file, lineNum, ...rest] = line.split(':');
    return {
      file: file.replace(/^\.\//, ''),
      line: parseInt(lineNum),
      content: rest.join(':').trim()
    };
  });

  return {
    pattern,
    matchCount: matches.length,
    matches: matches.slice(0, 50) // Limit to first 50
  };
}

async function findPattern(task) {
  const { repo, filePattern } = task.payload;

  repoManager.setRepo(repo);
  const repoRoot = repoManager.getCurrentRepo();

  // Use glob-like file finding
  const files = await findFiles(repoRoot, filePattern);

  return {
    filePattern,
    fileCount: files.length,
    files
  };
}

// ==================== REFACTORING ====================

async function refactorCode(task) {
  const { repo, files, refactoringInstructions } = task.payload;

  reportProgress(task.id, 'Analyzing code to refactor', 10);

  repoManager.setRepo(repo);
  const repoRoot = repoManager.getCurrentRepo();

  // Read files to refactor
  const fileContents = await Promise.all(
    files.map(async (file) => {
      const fullPath = path.join(repoRoot, file);
      const content = await fs.readFile(fullPath, 'utf-8');
      return { path: file, content };
    })
  );

  reportProgress(task.id, 'Planning refactoring with Claude', 30);

  // Use Claude to plan and execute refactoring
  const prompt = buildRefactoringPrompt(fileContents, refactoringInstructions);

  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 8000,
    temperature: 0.3,
    system: [
      {
        type: "text",
        text: "You are an expert code refactoring assistant. Refactor code according to instructions while maintaining functionality. Return JSON with refactored files.",
        cache_control: { type: "ephemeral" }
      }
    ],
    messages: [{ role: 'user', content: prompt }]
  }, {
    headers: {
      'anthropic-beta': 'prompt-caching-2024-07-31'
    }
  });

  const refactoredData = JSON.parse(response.content[0].text);

  reportProgress(task.id, 'Applying refactored code', 70);

  // Write refactored files
  for (const file of refactoredData.files) {
    const fullPath = path.join(repoRoot, file.path);
    await fs.writeFile(fullPath, file.content, 'utf-8');
  }

  return {
    filesRefactored: refactoredData.files.length,
    changes: refactoredData.summary,
    usage: {
      model: response.model,
      inputTokens: response.usage.input_tokens,
      outputTokens: response.usage.output_tokens,
      cacheCreationTokens: response.usage.cache_creation_input_tokens || 0,
      cacheReadTokens: response.usage.cache_read_input_tokens || 0
    }
  };
}

async function renameSymbol(task) {
  const { repo, symbolName, newName, filePattern = '**/*.js' } = task.payload;

  repoManager.setRepo(repo);
  const repoRoot = repoManager.getCurrentRepo();

  // Find all occurrences
  const { stdout } = await execAsync(
    `grep -r -l "\\b${symbolName}\\b" --include="${filePattern}" .`,
    { cwd: repoRoot, maxBuffer: 10 * 1024 * 1024 }
  );

  const affectedFiles = stdout.trim().split('\n').filter(f => f);

  // Replace in all files
  for (const file of affectedFiles) {
    const fullPath = path.join(repoRoot, file.replace(/^\.\//, ''));
    let content = await fs.readFile(fullPath, 'utf-8');

    // Simple regex replace (more sophisticated AST-based renaming would be better)
    const regex = new RegExp(`\\b${symbolName}\\b`, 'g');
    content = content.replace(regex, newName);

    await fs.writeFile(fullPath, content, 'utf-8');
  }

  return {
    symbolName,
    newName,
    filesModified: affectedFiles.length,
    files: affectedFiles
  };
}

async function extractFunction(task) {
  // TODO: Implement function extraction
  return { message: 'Extract function not yet implemented' };
}

// ==================== GIT OPERATIONS ====================

async function gitStatus(task) {
  const { repo } = task.payload;
  repoManager.setRepo(repo);

  const status = await repoManager.status();
  const currentBranch = await repoManager.getCurrentBranch();

  return {
    repo,
    branch: currentBranch,
    status
  };
}

async function gitCommit(task) {
  const { repo, message, files = '.' } = task.payload;

  repoManager.setRepo(repo);

  // Stage files
  await repoManager.add(files);

  // Commit
  const result = await repoManager.commit(message);

  return {
    repo,
    committed: result.committed,
    hash: result.hash,
    message
  };
}

async function gitPush(task) {
  const { repo, remote = 'origin', branch = null, setUpstream = false } = task.payload;

  repoManager.setRepo(repo);

  const result = await repoManager.push(remote, branch, setUpstream);

  return {
    repo,
    pushed: result.pushed,
    remote: result.remote,
    branch: result.branch
  };
}

async function gitCreateBranch(task) {
  const { repo, branchName, checkout = true } = task.payload;

  repoManager.setRepo(repo);

  const result = await repoManager.createBranch(branchName, checkout);

  return {
    repo,
    branch: result.branch,
    checkedOut: result.checkedOut
  };
}

async function gitDiff(task) {
  const { repo, staged = false, file = null } = task.payload;

  repoManager.setRepo(repo);

  const diff = await repoManager.diff(staged, file);

  return {
    repo,
    diff,
    staged,
    file
  };
}

// ==================== TESTING ====================

async function runTests(task) {
  const { repo, testCommand = 'npm test' } = task.payload;

  repoManager.setRepo(repo);
  const repoRoot = repoManager.getCurrentRepo();

  reportProgress(task.id, 'Running tests', 30);

  const { stdout, stderr } = await execAsync(testCommand, {
    cwd: repoRoot,
    maxBuffer: 10 * 1024 * 1024
  });

  return {
    repo,
    command: testCommand,
    passed: !stderr.includes('FAIL') && !stderr.includes('Error'),
    output: stdout,
    errors: stderr
  };
}

async function runBuild(task) {
  const { repo, buildCommand = 'npm run build' } = task.payload;

  repoManager.setRepo(repo);
  const repoRoot = repoManager.getCurrentRepo();

  reportProgress(task.id, 'Running build', 30);

  const { stdout, stderr } = await execAsync(buildCommand, {
    cwd: repoRoot,
    maxBuffer: 10 * 1024 * 1024
  });

  return {
    repo,
    command: buildCommand,
    success: !stderr.includes('Error') && !stderr.includes('FAIL'),
    output: stdout,
    errors: stderr
  };
}

// ==================== HELPER FUNCTIONS ====================

function reportProgress(taskId, stage, percentage) {
  parentPort.postMessage({
    type: 'PROGRESS',
    progress: {
      taskId,
      stage,
      percentage
    }
  });
}

async function getFileTree(rootPath, scope) {
  const files = [];
  const ignoreDirs = ['node_modules', '.git', 'dist', 'build'];

  async function walk(dir) {
    const entries = await fs.readdir(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);

      if (entry.isDirectory()) {
        if (!ignoreDirs.includes(entry.name)) {
          await walk(fullPath);
        }
      } else {
        files.push(path.relative(rootPath, fullPath));
      }
    }
  }

  await walk(rootPath);

  // Filter by scope
  if (scope === 'src') {
    return files.filter(f => f.startsWith('src/'));
  }

  return files;
}

async function findFiles(rootPath, pattern) {
  // Simple glob implementation
  const files = await getFileTree(rootPath, 'full');

  // Convert glob pattern to regex
  const regexPattern = pattern
    .replace(/\./g, '\\.')
    .replace(/\*\*/g, '.*')
    .replace(/\*/g, '[^/]*');

  const regex = new RegExp(regexPattern);

  return files.filter(f => regex.test(f));
}

function buildEditPrompt(fileContents, instructions) {
  let prompt = `I need to edit the following files:\n\n`;

  fileContents.forEach((file, idx) => {
    prompt += `**File ${idx + 1}: ${file.path}**\n\`\`\`\n${file.content}\n\`\`\`\n\n`;
  });

  prompt += `**Instructions**: ${instructions}\n\n`;
  prompt += `Return JSON in this format:\n`;
  prompt += `{\n  "edits": [\n    {"file": "path/to/file.js", "old": "code to replace", "new": "replacement code"}\n  ]\n}`;

  return prompt;
}

function buildAnalysisPrompt(files, scope) {
  let prompt = `Analyze this codebase (${files.length} files, scope: ${scope}):\n\n`;
  prompt += `Files:\n${files.slice(0, 100).join('\n')}\n\n`;
  prompt += `Provide:\n`;
  prompt += `1. Architecture overview\n`;
  prompt += `2. Key components and their responsibilities\n`;
  prompt += `3. Code quality observations\n`;
  prompt += `4. Suggestions for improvement\n`;

  return prompt;
}

function buildRefactoringPrompt(fileContents, instructions) {
  let prompt = `Refactor the following code:\n\n`;

  fileContents.forEach((file, idx) => {
    prompt += `**File ${idx + 1}: ${file.path}**\n\`\`\`\n${file.content}\n\`\`\`\n\n`;
  });

  prompt += `**Refactoring Instructions**: ${instructions}\n\n`;
  prompt += `Return JSON:\n`;
  prompt += `{\n  "files": [{"path": "...", "content": "..."}],\n  "summary": "description of changes"\n}`;

  return prompt;
}

console.log(`Local Worker ${workerData.workerId} started`);
