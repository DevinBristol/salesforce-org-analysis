// src/services/repo-manager.js
// Repository Manager - Handles git operations and local repository management

import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs-extra';
import path from 'path';

const execAsync = promisify(exec);

export class RepoManager {
  constructor(workspaceRoot = null) {
    // Default to environment variable or current working directory
    this.workspaceRoot = workspaceRoot || process.env.WORKSPACE_ROOT || process.cwd();
    this.currentRepo = null;
  }

  /**
   * Set the current repository to work with
   * @param {string} repoPath - Path to repository (absolute or relative to workspace)
   */
  setRepo(repoPath) {
    if (path.isAbsolute(repoPath)) {
      this.currentRepo = repoPath;
    } else {
      this.currentRepo = path.join(this.workspaceRoot, repoPath);
    }

    // Validate that it's a git repository
    if (!fs.existsSync(path.join(this.currentRepo, '.git'))) {
      throw new Error(`Not a git repository: ${this.currentRepo}`);
    }

    return this.currentRepo;
  }

  /**
   * Get the current repository path
   */
  getCurrentRepo() {
    return this.currentRepo;
  }

  /**
   * Execute a git command in the current repository
   * @param {string} command - Git command (without 'git' prefix)
   * @param {string} customRepo - Optional custom repo path
   */
  async execGit(command, customRepo = null) {
    const repo = customRepo || this.currentRepo;
    if (!repo) {
      throw new Error('No repository set. Call setRepo() first.');
    }

    try {
      const { stdout, stderr } = await execAsync(`git ${command}`, {
        cwd: repo,
        maxBuffer: 10 * 1024 * 1024 // 10MB buffer for large outputs
      });

      return {
        success: true,
        stdout: stdout.trim(),
        stderr: stderr.trim()
      };
    } catch (error) {
      return {
        success: false,
        error: error.message,
        stdout: error.stdout?.trim() || '',
        stderr: error.stderr?.trim() || ''
      };
    }
  }

  /**
   * Get git status
   */
  async status() {
    const result = await this.execGit('status --porcelain');

    if (!result.success) {
      throw new Error(`Git status failed: ${result.error}`);
    }

    // Parse status output
    const lines = result.stdout.split('\n').filter(l => l.trim());
    const status = {
      modified: [],
      added: [],
      deleted: [],
      untracked: [],
      renamed: [],
      clean: lines.length === 0
    };

    lines.forEach(line => {
      const statusCode = line.substring(0, 2);
      const file = line.substring(3);

      if (statusCode.includes('M')) status.modified.push(file);
      if (statusCode.includes('A')) status.added.push(file);
      if (statusCode.includes('D')) status.deleted.push(file);
      if (statusCode.includes('?')) status.untracked.push(file);
      if (statusCode.includes('R')) status.renamed.push(file);
    });

    return status;
  }

  /**
   * Get current branch name
   */
  async getCurrentBranch() {
    const result = await this.execGit('rev-parse --abbrev-ref HEAD');

    if (!result.success) {
      throw new Error(`Failed to get current branch: ${result.error}`);
    }

    return result.stdout;
  }

  /**
   * Create a new branch
   * @param {string} branchName - Name of the new branch
   * @param {boolean} checkout - Whether to checkout the new branch (default: true)
   */
  async createBranch(branchName, checkout = true) {
    const command = checkout ? `checkout -b ${branchName}` : `branch ${branchName}`;
    const result = await this.execGit(command);

    if (!result.success) {
      throw new Error(`Failed to create branch: ${result.error}`);
    }

    return {
      branch: branchName,
      checkedOut: checkout
    };
  }

  /**
   * Checkout a branch
   * @param {string} branchName - Name of branch to checkout
   */
  async checkoutBranch(branchName) {
    const result = await this.execGit(`checkout ${branchName}`);

    if (!result.success) {
      throw new Error(`Failed to checkout branch: ${result.error}`);
    }

    return branchName;
  }

  /**
   * Stage files
   * @param {string|string[]} files - File(s) to stage (or '.' for all)
   */
  async add(files) {
    const fileList = Array.isArray(files) ? files.join(' ') : files;
    const result = await this.execGit(`add ${fileList}`);

    if (!result.success) {
      throw new Error(`Failed to stage files: ${result.error}`);
    }

    return true;
  }

  /**
   * Commit staged changes
   * @param {string} message - Commit message
   */
  async commit(message) {
    // Escape double quotes in message
    const escapedMessage = message.replace(/"/g, '\\"');
    const result = await this.execGit(`commit -m "${escapedMessage}"`);

    if (!result.success) {
      // Check if failure is due to nothing to commit
      if (result.stderr.includes('nothing to commit')) {
        return {
          committed: false,
          reason: 'nothing to commit'
        };
      }
      throw new Error(`Failed to commit: ${result.error}`);
    }

    // Extract commit hash from output
    const hashMatch = result.stdout.match(/\[.+?\s([a-f0-9]+)\]/);
    const commitHash = hashMatch ? hashMatch[1] : null;

    return {
      committed: true,
      hash: commitHash,
      message: message
    };
  }

  /**
   * Push changes to remote
   * @param {string} remote - Remote name (default: 'origin')
   * @param {string} branch - Branch name (default: current branch)
   * @param {boolean} setUpstream - Set upstream branch (default: false)
   */
  async push(remote = 'origin', branch = null, setUpstream = false) {
    if (!branch) {
      branch = await this.getCurrentBranch();
    }

    const upstreamFlag = setUpstream ? '-u' : '';
    const command = `push ${upstreamFlag} ${remote} ${branch}`;
    const result = await this.execGit(command);

    if (!result.success) {
      throw new Error(`Failed to push: ${result.error}`);
    }

    return {
      remote,
      branch,
      pushed: true
    };
  }

  /**
   * Pull changes from remote
   * @param {string} remote - Remote name (default: 'origin')
   * @param {string} branch - Branch name (default: current branch)
   */
  async pull(remote = 'origin', branch = null) {
    if (!branch) {
      branch = await this.getCurrentBranch();
    }

    const result = await this.execGit(`pull ${remote} ${branch}`);

    if (!result.success) {
      // Check for conflicts
      if (result.stderr.includes('CONFLICT') || result.stdout.includes('CONFLICT')) {
        return {
          success: false,
          hasConflicts: true,
          message: 'Pull resulted in merge conflicts'
        };
      }
      throw new Error(`Failed to pull: ${result.error}`);
    }

    return {
      success: true,
      hasConflicts: false,
      updated: !result.stdout.includes('Already up to date')
    };
  }

  /**
   * Get diff of changes
   * @param {boolean} staged - Show staged changes only (default: false)
   * @param {string} file - Specific file to diff (optional)
   */
  async diff(staged = false, file = null) {
    const stagedFlag = staged ? '--cached' : '';
    const fileArg = file ? `-- ${file}` : '';
    const result = await this.execGit(`diff ${stagedFlag} ${fileArg}`);

    if (!result.success) {
      throw new Error(`Failed to get diff: ${result.error}`);
    }

    return result.stdout;
  }

  /**
   * Get commit log
   * @param {number} count - Number of commits to retrieve
   * @param {string} format - Format string (default: oneline)
   */
  async log(count = 10, format = 'oneline') {
    const formatArg = format === 'oneline' ? '--oneline' : `--pretty=format:${format}`;
    const result = await this.execGit(`log ${formatArg} -n ${count}`);

    if (!result.success) {
      throw new Error(`Failed to get log: ${result.error}`);
    }

    return result.stdout.split('\n').filter(l => l.trim());
  }

  /**
   * Clone a repository
   * @param {string} url - Git URL to clone
   * @param {string} targetPath - Where to clone (relative to workspace or absolute)
   * @param {boolean} shallow - Shallow clone (default: false)
   */
  async clone(url, targetPath, shallow = false) {
    const fullPath = path.isAbsolute(targetPath)
      ? targetPath
      : path.join(this.workspaceRoot, targetPath);

    // Check if directory already exists
    if (fs.existsSync(fullPath)) {
      throw new Error(`Directory already exists: ${fullPath}`);
    }

    const shallowFlag = shallow ? '--depth 1' : '';
    const command = `git clone ${shallowFlag} ${url} ${fullPath}`;

    try {
      const { stdout, stderr } = await execAsync(command, {
        cwd: this.workspaceRoot,
        maxBuffer: 10 * 1024 * 1024
      });

      return {
        success: true,
        path: fullPath,
        stdout: stdout.trim(),
        stderr: stderr.trim()
      };
    } catch (error) {
      return {
        success: false,
        error: error.message,
        stdout: error.stdout?.trim() || '',
        stderr: error.stderr?.trim() || ''
      };
    }
  }

  /**
   * Check if there are uncommitted changes
   */
  async hasUncommittedChanges() {
    const status = await this.status();
    return !status.clean;
  }

  /**
   * Check if branch exists
   * @param {string} branchName - Branch name to check
   */
  async branchExists(branchName) {
    const result = await this.execGit(`rev-parse --verify ${branchName}`);
    return result.success;
  }

  /**
   * List all branches
   * @param {boolean} remote - Include remote branches (default: false)
   */
  async listBranches(remote = false) {
    const flag = remote ? '-a' : '';
    const result = await this.execGit(`branch ${flag}`);

    if (!result.success) {
      throw new Error(`Failed to list branches: ${result.error}`);
    }

    return result.stdout
      .split('\n')
      .map(b => b.trim().replace('* ', ''))
      .filter(b => b);
  }

  /**
   * Stash changes
   * @param {string} message - Stash message (optional)
   */
  async stash(message = null) {
    const messageArg = message ? `save "${message}"` : '';
    const result = await this.execGit(`stash ${messageArg}`);

    if (!result.success) {
      throw new Error(`Failed to stash changes: ${result.error}`);
    }

    return {
      stashed: !result.stdout.includes('No local changes to save')
    };
  }

  /**
   * Apply stashed changes
   * @param {string} stashRef - Stash reference (default: latest)
   */
  async stashPop(stashRef = null) {
    const ref = stashRef || '';
    const result = await this.execGit(`stash pop ${ref}`);

    if (!result.success) {
      // Check for conflicts
      if (result.stderr.includes('CONFLICT')) {
        return {
          success: false,
          hasConflicts: true,
          message: 'Stash application resulted in conflicts'
        };
      }
      throw new Error(`Failed to apply stash: ${result.error}`);
    }

    return {
      success: true,
      hasConflicts: false
    };
  }

  /**
   * Get repository root directory
   */
  async getRepoRoot() {
    const result = await this.execGit('rev-parse --show-toplevel');

    if (!result.success) {
      throw new Error(`Failed to get repo root: ${result.error}`);
    }

    return result.stdout;
  }

  /**
   * List all available repositories in workspace
   */
  async listWorkspaceRepos() {
    const repos = [];

    try {
      const entries = await fs.readdir(this.workspaceRoot, { withFileTypes: true });

      for (const entry of entries) {
        if (entry.isDirectory()) {
          const repoPath = path.join(this.workspaceRoot, entry.name);
          const gitPath = path.join(repoPath, '.git');

          if (await fs.pathExists(gitPath)) {
            repos.push({
              name: entry.name,
              path: repoPath
            });
          }
        }
      }
    } catch (error) {
      console.error('Error listing workspace repos:', error);
    }

    return repos;
  }

  /**
   * Get remote information
   */
  async getRemotes() {
    const result = await this.execGit('remote -v');

    if (!result.success) {
      throw new Error(`Failed to get remotes: ${result.error}`);
    }

    const remotes = {};
    result.stdout.split('\n').forEach(line => {
      const match = line.match(/^(\S+)\s+(\S+)\s+\((fetch|push)\)$/);
      if (match) {
        const [, name, url, type] = match;
        if (!remotes[name]) {
          remotes[name] = {};
        }
        remotes[name][type] = url;
      }
    });

    return remotes;
  }
}

export default RepoManager;
