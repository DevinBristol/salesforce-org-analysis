#!/usr/bin/env node
/**
 * Creates a comprehensive repository snapshot for Claude Opus analysis
 * Bundles all relevant code and documentation into a single markdown file
 */

import fs from "fs-extra";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Files and directories to include
const INCLUDE_PATTERNS = {
  // Core source files
  source: [
    "salesforce-autonomous-dev-system/src/**/*.js",
    "salesforce-autonomous-dev-system/demos/*.js",
    "salesforce-autonomous-dev-system/scripts/*.js"
  ],

  // Configuration and metadata
  config: [
    "salesforce-autonomous-dev-system/package.json",
    "salesforce-autonomous-dev-system/.env.template",
    "salesforce-autonomous-dev-system/.gitignore"
  ],

  // Documentation
  docs: [
    "salesforce-autonomous-dev-system/README.md",
    "salesforce-autonomous-dev-system/IMPLEMENTATION.md",
    "salesforce-autonomous-dev-system/QUICK-START.md",
    "salesforce-autonomous-dev-system/TEST-IMPROVEMENT-GUIDE.md",
    "salesforce-autonomous-dev-system/PROJECT-SNAPSHOT-2025-11-24.md"
  ],

  // Root level important files
  root: ["package.json", "README.md"]
};

// Directories to ignore
const IGNORE_DIRS = [
  "node_modules",
  ".git",
  "output",
  "logs",
  "cache",
  "metadata",
  "deployments",
  "analysis",
  "temp"
];

// File extensions to include
const INCLUDE_EXTENSIONS = [
  ".js",
  ".json",
  ".md",
  ".txt",
  ".ps1",
  ".sh",
  ".yml",
  ".yaml"
];

/**
 * Get all files in directory recursively
 */
function getAllFiles(dirPath, arrayOfFiles = []) {
  const files = fs.readdirSync(dirPath);

  files.forEach((file) => {
    const filePath = path.join(dirPath, file);
    const stat = fs.statSync(filePath);

    // Skip ignored directories
    if (stat.isDirectory()) {
      const dirName = path.basename(filePath);
      if (!IGNORE_DIRS.includes(dirName)) {
        arrayOfFiles = getAllFiles(filePath, arrayOfFiles);
      }
    } else {
      // Only include files with specified extensions
      const ext = path.extname(file);
      if (INCLUDE_EXTENSIONS.includes(ext)) {
        arrayOfFiles.push(filePath);
      }
    }
  });

  return arrayOfFiles;
}

/**
 * Get language identifier for code block
 */
function getLanguage(filename) {
  const ext = path.extname(filename);
  const langMap = {
    ".js": "javascript",
    ".json": "json",
    ".md": "markdown",
    ".ps1": "powershell",
    ".sh": "bash",
    ".yml": "yaml",
    ".yaml": "yaml",
    ".txt": "text"
  };
  return langMap[ext] || "text";
}

/**
 * Format file size
 */
function formatBytes(bytes) {
  if (bytes === 0) return "0 Bytes";
  const k = 1024;
  const sizes = ["Bytes", "KB", "MB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + " " + sizes[i];
}

/**
 * Create directory tree
 */
function createDirectoryTree(dirPath, prefix = "", isLast = true) {
  const files = fs.readdirSync(dirPath).filter((file) => {
    const filePath = path.join(dirPath, file);
    const stat = fs.statSync(filePath);
    if (stat.isDirectory()) {
      return !IGNORE_DIRS.includes(file);
    }
    return true;
  });

  let tree = "";
  files.forEach((file, index) => {
    const isLastFile = index === files.length - 1;
    const filePath = path.join(dirPath, file);
    const stat = fs.statSync(filePath);
    const connector = isLastFile ? "└── " : "├── ";
    const extension = isLastFile ? "    " : "│   ";

    tree += prefix + connector + file;

    if (stat.isDirectory()) {
      tree += "/\n";
      tree += createDirectoryTree(filePath, prefix + extension, isLastFile);
    } else {
      tree += "\n";
    }
  });

  return tree;
}

/**
 * Main function
 */
async function createSnapshot() {
  console.log("🚀 Creating Opus Repository Snapshot...\n");

  const repoRoot = path.resolve(__dirname);
  const autonomousSystemPath = path.join(
    repoRoot,
    "salesforce-autonomous-dev-system"
  );
  const outputFile = path.join(repoRoot, "OPUS-REPO-SNAPSHOT.md");

  let output = "";
  let totalFiles = 0;
  let totalSize = 0;

  // Header
  output += "# Repository Snapshot for Claude Opus Analysis\n\n";
  output += `**Generated**: ${new Date().toISOString()}\n`;
  output += `**Repository**: https://github.com/DevinBristol/salesforce-org-analysis\n`;
  output += `**Branch**: master\n`;
  output += `**Focus**: salesforce-autonomous-dev-system/\n\n`;
  output += "---\n\n";

  // Table of Contents
  output += "## Table of Contents\n\n";
  output += "1. [Project Structure](#project-structure)\n";
  output += "2. [Configuration Files](#configuration-files)\n";
  output += "3. [Documentation](#documentation)\n";
  output += "4. [Source Code - Services](#source-code---services)\n";
  output += "5. [Source Code - Demos](#source-code---demos)\n";
  output += "6. [Source Code - Scripts](#source-code---scripts)\n";
  output += "7. [CLI Tools](#cli-tools)\n\n";
  output += "---\n\n";

  // Project Structure
  console.log("📁 Generating project structure...");
  output += "## Project Structure\n\n";
  output += "```\n";
  output += "salesforce-autonomous-dev-system/\n";
  output += createDirectoryTree(autonomousSystemPath);
  output += "```\n\n";
  output += "---\n\n";

  // Configuration Files
  console.log("⚙️  Processing configuration files...");
  output += "## Configuration Files\n\n";

  const configFiles = [
    "salesforce-autonomous-dev-system/package.json",
    "salesforce-autonomous-dev-system/.env.template",
    "salesforce-autonomous-dev-system/.gitignore"
  ];

  for (const configFile of configFiles) {
    const filePath = path.join(repoRoot, configFile);
    if (await fs.pathExists(filePath)) {
      const content = await fs.readFile(filePath, "utf-8");
      const lang = getLanguage(configFile);
      const stats = await fs.stat(filePath);

      output += `### ${configFile}\n\n`;
      output += `**Size**: ${formatBytes(stats.size)}\n\n`;
      output += `\`\`\`${lang}\n${content}\n\`\`\`\n\n`;

      totalFiles++;
      totalSize += stats.size;
    }
  }

  output += "---\n\n";

  // Documentation
  console.log("📚 Processing documentation...");
  output += "## Documentation\n\n";

  const docFiles = [
    "salesforce-autonomous-dev-system/README.md",
    "salesforce-autonomous-dev-system/IMPLEMENTATION.md",
    "salesforce-autonomous-dev-system/QUICK-START.md",
    "salesforce-autonomous-dev-system/PROJECT-SNAPSHOT-2025-11-24.md"
  ];

  for (const docFile of docFiles) {
    const filePath = path.join(repoRoot, docFile);
    if (await fs.pathExists(filePath)) {
      const content = await fs.readFile(filePath, "utf-8");
      const stats = await fs.stat(filePath);

      output += `### ${docFile}\n\n`;
      output += `**Size**: ${formatBytes(stats.size)}\n\n`;
      output += `\`\`\`markdown\n${content}\n\`\`\`\n\n`;

      totalFiles++;
      totalSize += stats.size;
    }
  }

  output += "---\n\n";

  // Source Code - Services
  console.log("💻 Processing service files...");
  output += "## Source Code - Services\n\n";

  const servicesPath = path.join(autonomousSystemPath, "src", "services");
  if (await fs.pathExists(servicesPath)) {
    const serviceFiles = (await fs.readdir(servicesPath))
      .filter((f) => f.endsWith(".js"))
      .sort();

    for (const serviceFile of serviceFiles) {
      const filePath = path.join(servicesPath, serviceFile);
      const content = await fs.readFile(filePath, "utf-8");
      const stats = await fs.stat(filePath);
      const lines = content.split("\n").length;

      output += `### src/services/${serviceFile}\n\n`;
      output += `**Size**: ${formatBytes(stats.size)} | **Lines**: ${lines}\n\n`;
      output += `\`\`\`javascript\n${content}\n\`\`\`\n\n`;

      totalFiles++;
      totalSize += stats.size;
      console.log(`  ✓ ${serviceFile} (${lines} lines)`);
    }
  }

  output += "---\n\n";

  // Source Code - Demos
  console.log("🎯 Processing demo files...");
  output += "## Source Code - Demos\n\n";

  const demosPath = path.join(autonomousSystemPath, "demos");
  if (await fs.pathExists(demosPath)) {
    const demoFiles = (await fs.readdir(demosPath))
      .filter((f) => f.endsWith(".js"))
      .sort();

    for (const demoFile of demoFiles) {
      const filePath = path.join(demosPath, demoFile);
      const content = await fs.readFile(filePath, "utf-8");
      const stats = await fs.stat(filePath);
      const lines = content.split("\n").length;

      output += `### demos/${demoFile}\n\n`;
      output += `**Size**: ${formatBytes(stats.size)} | **Lines**: ${lines}\n\n`;
      output += `\`\`\`javascript\n${content}\n\`\`\`\n\n`;

      totalFiles++;
      totalSize += stats.size;
      console.log(`  ✓ ${demoFile} (${lines} lines)`);
    }
  }

  output += "---\n\n";

  // Source Code - Scripts
  console.log("🔧 Processing script files...");
  output += "## Source Code - Scripts\n\n";

  const scriptsPath = path.join(autonomousSystemPath, "scripts");
  if (await fs.pathExists(scriptsPath)) {
    const scriptFiles = (await fs.readdir(scriptsPath))
      .filter((f) => f.endsWith(".js"))
      .sort();

    for (const scriptFile of scriptFiles) {
      const filePath = path.join(scriptsPath, scriptFile);
      const content = await fs.readFile(filePath, "utf-8");
      const stats = await fs.stat(filePath);
      const lines = content.split("\n").length;

      output += `### scripts/${scriptFile}\n\n`;
      output += `**Size**: ${formatBytes(stats.size)} | **Lines**: ${lines}\n\n`;
      output += `\`\`\`javascript\n${content}\n\`\`\`\n\n`;

      totalFiles++;
      totalSize += stats.size;
      console.log(`  ✓ ${scriptFile} (${lines} lines)`);
    }
  }

  output += "---\n\n";

  // CLI Tools
  console.log("🖥️  Processing CLI files...");
  output += "## CLI Tools\n\n";

  const cliPath = path.join(autonomousSystemPath, "src", "cli");
  if (await fs.pathExists(cliPath)) {
    const cliFiles = (await fs.readdir(cliPath))
      .filter((f) => f.endsWith(".js"))
      .sort();

    for (const cliFile of cliFiles) {
      const filePath = path.join(cliPath, cliFile);
      const content = await fs.readFile(filePath, "utf-8");
      const stats = await fs.stat(filePath);
      const lines = content.split("\n").length;

      output += `### src/cli/${cliFile}\n\n`;
      output += `**Size**: ${formatBytes(stats.size)} | **Lines**: ${lines}\n\n`;
      output += `\`\`\`javascript\n${content}\n\`\`\`\n\n`;

      totalFiles++;
      totalSize += stats.size;
      console.log(`  ✓ ${cliFile} (${lines} lines)`);
    }
  }

  // Add main orchestrator
  const mainFile = path.join(autonomousSystemPath, "src", "index.js");
  if (await fs.pathExists(mainFile)) {
    const content = await fs.readFile(mainFile, "utf-8");
    const stats = await fs.stat(mainFile);
    const lines = content.split("\n").length;

    output += `### src/index.js (Main Orchestrator)\n\n`;
    output += `**Size**: ${formatBytes(stats.size)} | **Lines**: ${lines}\n\n`;
    output += `\`\`\`javascript\n${content}\n\`\`\`\n\n`;

    totalFiles++;
    totalSize += stats.size;
  }

  output += "---\n\n";

  // Summary
  output += "## Snapshot Summary\n\n";
  output += `- **Total Files**: ${totalFiles}\n`;
  output += `- **Total Size**: ${formatBytes(totalSize)}\n`;
  output += `- **Generated**: ${new Date().toLocaleString()}\n\n`;
  output += "---\n\n";
  output += "*End of Repository Snapshot*\n";

  // Write to file
  await fs.writeFile(outputFile, output);

  // Also write to clipboard-ready file (without too much whitespace)
  const clipboardFile = path.join(repoRoot, "OPUS-CLIPBOARD.txt");
  await fs.writeFile(clipboardFile, output);

  console.log("\n✅ Snapshot created successfully!\n");
  console.log(`📄 Files processed: ${totalFiles}`);
  console.log(`📊 Total size: ${formatBytes(totalSize)}`);
  console.log(`\n📁 Output files:`);
  console.log(`   - ${outputFile}`);
  console.log(`   - ${clipboardFile} (for easy copying)\n`);
  console.log(`\n📋 Next steps:`);
  console.log(`   1. Open OPUS-REPO-SNAPSHOT.md or OPUS-CLIPBOARD.txt`);
  console.log(`   2. Copy the entire contents`);
  console.log(`   3. Paste into your Opus conversation`);
  console.log(`   4. Add your Phase 2 planning prompt after the snapshot\n`);
}

// Run
createSnapshot().catch((error) => {
  console.error("❌ Error creating snapshot:", error);
  process.exit(1);
});
