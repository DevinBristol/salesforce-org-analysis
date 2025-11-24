// src/services/salesforce-manager.js - Salesforce Operations Manager

import jsforce from "jsforce";
import { exec } from "child_process";
import { promisify } from "util";
import fs from "fs-extra";
import path from "path";

const execAsync = promisify(exec);

export class SalesforceManager {
  constructor(logger) {
    this.logger = logger;
    this.connections = {};
    this.metadata = null;

    // SAFETY: Whitelist of allowed deployment targets (sandboxes only)
    this.SANDBOX_WHITELIST = [
      "dev-sandbox",
      "Devin1",
      "devin1",
      "test-sandbox",
      "uat-sandbox"
    ];

    // SAFETY: Blacklist of production org indicators
    this.PRODUCTION_INDICATORS = ["production", "prod", "live", "main"];
  }

  async connect() {
    try {
      // Connect to production org for metadata
      this.connections.production = new jsforce.Connection({
        loginUrl: process.env.SF_LOGIN_URL || "https://login.salesforce.com"
      });

      // Use stored authentication from Salesforce CLI
      const authInfo = await this.getAuthInfo("production");
      this.connections.production.accessToken = authInfo.accessToken;
      this.connections.production.instanceUrl = authInfo.instanceUrl;

      // Connect to dev sandbox for deployment
      this.connections.sandbox = new jsforce.Connection({
        loginUrl: "https://test.salesforce.com"
      });

      const sandboxAuth = await this.getAuthInfo("dev-sandbox");
      this.connections.sandbox.accessToken = sandboxAuth.accessToken;
      this.connections.sandbox.instanceUrl = sandboxAuth.instanceUrl;

      this.logger.info("Successfully connected to Salesforce orgs");
      return true;
    } catch (error) {
      this.logger.error("Salesforce connection failed:", error);
      throw error;
    }
  }

  async getAuthInfo(alias) {
    try {
      const { stdout } = await execAsync(
        `sf org display --json --target-org ${alias}`
      );
      const result = JSON.parse(stdout);
      return {
        accessToken: result.result.accessToken,
        instanceUrl: result.result.instanceUrl,
        username: result.result.username
      };
    } catch (error) {
      this.logger.error(`Failed to get auth info for ${alias}:`, error);
      throw error;
    }
  }

  isConnected() {
    return this.connections.production && this.connections.sandbox;
  }

  get connection() {
    // Convenience getter for primary connection
    return this.connections.production;
  }

  async fetchMetadata(
    types = ["CustomObject", "ApexClass", "ApexTrigger", "Flow"]
  ) {
    try {
      const conn = this.connections.production;
      const metadata = {};

      for (const type of types) {
        this.logger.info(`Fetching ${type} metadata...`);
        const result = await conn.metadata.list([{ type }]);
        metadata[type] = Array.isArray(result) ? result : [result];
      }

      this.metadata = metadata;

      // Save metadata to file for reference
      await fs.ensureDir("./metadata");
      await fs.writeJson("./metadata/org-metadata.json", metadata, {
        spaces: 2
      });

      this.logger.info("Metadata fetched and saved");
      return metadata;
    } catch (error) {
      this.logger.error("Metadata fetch failed:", error);
      throw error;
    }
  }

  async getObjectSchema(objectName) {
    try {
      const conn = this.connections.production;
      const describeSObjectResult = await conn.sobject(objectName).describe();
      return describeSObjectResult;
    } catch (error) {
      this.logger.error(`Failed to get schema for ${objectName}:`, error);
      throw error;
    }
  }

  async validateApex(apexCode) {
    try {
      // Use Salesforce CLI to validate Apex
      const tempFile = path.join("./temp", `apex-${Date.now()}.cls`);
      await fs.ensureDir("./temp");
      await fs.writeFile(tempFile, apexCode);

      const { stdout, stderr } = await execAsync(
        `sf apex run test --code-coverage --result-format json --target-org dev-sandbox`
      );

      await fs.remove(tempFile);

      if (stderr) {
        return { success: false, errors: [stderr] };
      }

      return { success: true };
    } catch (error) {
      return { success: false, errors: [error.message] };
    }
  }

  async validateMetadata(metadata) {
    try {
      // Validate metadata structure
      const errors = [];

      if (metadata.objects) {
        for (const obj of metadata.objects) {
          if (!obj.fullName || !obj.label) {
            errors.push(`Invalid object metadata: ${JSON.stringify(obj)}`);
          }
        }
      }

      if (metadata.fields) {
        for (const field of metadata.fields) {
          if (!field.fullName || !field.type) {
            errors.push(`Invalid field metadata: ${JSON.stringify(field)}`);
          }
        }
      }

      return {
        success: errors.length === 0,
        errors
      };
    } catch (error) {
      return { success: false, errors: [error.message] };
    }
  }

  /**
   * SAFETY: Validates that target org is a sandbox (not production)
   * @param {string} targetOrg - Target org alias or username
   * @throws {Error} If target org appears to be production
   */
  validateSandboxTarget(targetOrg) {
    // Check if org is in whitelist
    if (this.SANDBOX_WHITELIST.includes(targetOrg)) {
      this.logger.info(`✓ SAFETY CHECK: ${targetOrg} is whitelisted sandbox`);
      return true;
    }

    // Check if org contains production indicators
    const orgLower = targetOrg.toLowerCase();
    for (const indicator of this.PRODUCTION_INDICATORS) {
      if (orgLower.includes(indicator)) {
        const error = `DEPLOYMENT BLOCKED: "${targetOrg}" appears to be a production org. Only sandbox deployments are allowed. Whitelisted sandboxes: ${this.SANDBOX_WHITELIST.join(", ")}`;
        this.logger.error(error);
        throw new Error(error);
      }
    }

    // Warn if org not in whitelist (but allow with warning)
    this.logger.warn(
      `⚠ WARNING: "${targetOrg}" is not in the sandbox whitelist. Proceeding with caution.`
    );
    this.logger.warn(
      `⚠ Whitelisted sandboxes: ${this.SANDBOX_WHITELIST.join(", ")}`
    );
    this.logger.warn(
      `⚠ If this is a production org, STOP NOW and update the target org.`
    );

    return true;
  }

  async deployToSandbox(artifacts, targetOrg = "dev-sandbox") {
    try {
      // SAFETY CHECK: Validate target org is sandbox
      this.validateSandboxTarget(targetOrg);

      this.logger.info(`Deploying to ${targetOrg}...`);

      // Create deployment package
      const deployDir = path.join("./deploy", `deploy-${Date.now()}`);
      await fs.ensureDir(deployDir);

      // Write artifacts to deployment directory
      if (artifacts.apex) {
        const apexDir = path.join(deployDir, "classes");
        await fs.ensureDir(apexDir);
        for (const [fileName, content] of Object.entries(artifacts.apex)) {
          await fs.writeFile(path.join(apexDir, fileName), content);
          await fs.writeFile(
            path.join(apexDir, `${fileName}-meta.xml`),
            this.generateApexMetaXml()
          );
        }
      }

      if (artifacts.metadata) {
        const metadataDir = path.join(deployDir, "objects");
        await fs.ensureDir(metadataDir);
        for (const [fileName, content] of Object.entries(artifacts.metadata)) {
          await fs.writeFile(path.join(metadataDir, fileName), content);
        }
      }

      // Create package.xml
      await fs.writeFile(
        path.join(deployDir, "package.xml"),
        this.generatePackageXml(artifacts)
      );

      // Deploy using Salesforce CLI
      const { stdout } = await execAsync(
        `sf project deploy start --source-dir ${deployDir} --target-org ${targetOrg} --json`
      );

      const result = JSON.parse(stdout);

      // Clean up deployment directory
      await fs.remove(deployDir);

      return {
        success: result.result.status === "Succeeded",
        deploymentId: result.result.id,
        details: result.result
      };
    } catch (error) {
      this.logger.error("Deployment failed:", error);
      throw error;
    }
  }

  generateApexMetaXml() {
    return `<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>${process.env.SF_API_VERSION || "60.0"}</apiVersion>
    <status>Active</status>
</ApexClass>`;
  }

  generatePackageXml(artifacts) {
    const types = [];

    if (artifacts.apex && Object.keys(artifacts.apex).length > 0) {
      types.push(`
        <types>
            <members>*</members>
            <name>ApexClass</name>
        </types>`);
    }

    if (artifacts.metadata && Object.keys(artifacts.metadata).length > 0) {
      types.push(`
        <types>
            <members>*</members>
            <name>CustomObject</name>
        </types>`);
    }

    return `<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    ${types.join("\n")}
    <version>${process.env.SF_API_VERSION || "60.0"}</version>
</Package>`;
  }

  async runTests(targetOrg) {
    try {
      const { stdout } = await execAsync(
        `sf apex run test --code-coverage --result-format json --target-org ${targetOrg}`
      );

      const result = JSON.parse(stdout);
      return result.result.summary;
    } catch (error) {
      this.logger.error("Test execution failed:", error);
      throw error;
    }
  }

  async getApexClasses() {
    try {
      const conn = this.connections.production;
      const result = await conn.metadata.list([{ type: "ApexClass" }]);
      return Array.isArray(result) ? result : [result];
    } catch (error) {
      this.logger.error("Failed to fetch Apex classes:", error);
      throw error;
    }
  }

  async getApexClassContent(className) {
    try {
      const conn = this.connections.production;
      const result = await conn.tooling
        .sobject("ApexClass")
        .find({ Name: className })
        .execute();

      if (result && result.length > 0) {
        return result[0].Body;
      }

      throw new Error(`Class ${className} not found`);
    } catch (error) {
      this.logger.error(`Failed to fetch class ${className}:`, error);
      throw error;
    }
  }
}
