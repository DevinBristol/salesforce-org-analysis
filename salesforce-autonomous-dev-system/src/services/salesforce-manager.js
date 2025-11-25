// src/services/salesforce-manager.js - Salesforce Operations Manager

import jsforce from 'jsforce';
import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs-extra';
import path from 'path';

const execAsync = promisify(exec);

export class SalesforceManager {
    constructor(logger) {
        this.logger = logger;
        this.connections = {};
        this.metadata = null;

        // SAFETY: Whitelist of allowed deployment targets (sandboxes only)
        this.SANDBOX_WHITELIST = [
            'dev-sandbox',
            'Devin1',
            'devin1',
            'test-sandbox',
            'uat-sandbox'
        ];

        // SAFETY: Blacklist of production org indicators
        this.PRODUCTION_INDICATORS = [
            'production',
            'prod',
            'live',
            'main'
        ];
    }

    async connect() {
        try {
            // Connect to production org for metadata
            this.connections.production = new jsforce.Connection({
                loginUrl: process.env.SF_LOGIN_URL || 'https://login.salesforce.com'
            });

            // Use stored authentication from Salesforce CLI
            const authInfo = await this.getAuthInfo('production');
            this.connections.production.accessToken = authInfo.accessToken;
            this.connections.production.instanceUrl = authInfo.instanceUrl;

            // Connect to dev sandbox for deployment
            this.connections.sandbox = new jsforce.Connection({
                loginUrl: 'https://test.salesforce.com'
            });

            const sandboxAuth = await this.getAuthInfo('dev-sandbox');
            this.connections.sandbox.accessToken = sandboxAuth.accessToken;
            this.connections.sandbox.instanceUrl = sandboxAuth.instanceUrl;

            this.logger.info('Successfully connected to Salesforce orgs');
            return true;
        } catch (error) {
            this.logger.error('Salesforce connection failed:', error);
            throw error;
        }
    }

    async getAuthInfo(alias) {
        try {
            const { stdout } = await execAsync(`sf org display --json --target-org ${alias}`);
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

    async fetchMetadata(types = ['CustomObject', 'ApexClass', 'ApexTrigger', 'Flow']) {
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
            await fs.ensureDir('./metadata');
            await fs.writeJson('./metadata/org-metadata.json', metadata, { spaces: 2 });
            
            this.logger.info('Metadata fetched and saved');
            return metadata;
        } catch (error) {
            this.logger.error('Metadata fetch failed:', error);
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

    /**
     * Fetch existing Apex class code from the org
     * @param {string} className - Name of the Apex class
     * @param {string} targetOrg - Target org alias (default: Devin1)
     * @returns {Object} - { name, body, found }
     */
    async getApexClass(className, targetOrg = 'Devin1') {
        try {
            const { stdout } = await execAsync(
                `sf data query --query "SELECT Id, Name, Body FROM ApexClass WHERE Name = '${className}'" --target-org ${targetOrg} --json`
            );
            const result = JSON.parse(stdout);
            if (result.result?.records?.length > 0) {
                const record = result.result.records[0];
                return { name: record.Name, body: record.Body, found: true };
            }
            return { name: className, body: null, found: false };
        } catch (error) {
            this.logger.error(`Failed to fetch Apex class ${className}:`, error);
            return { name: className, body: null, found: false, error: error.message };
        }
    }

    /**
     * Fetch multiple Apex classes by name pattern
     * @param {string} pattern - LIKE pattern for class names (e.g., 'Contact%Handler')
     * @param {string} targetOrg - Target org alias
     * @returns {Array} - Array of { name, body }
     */
    async getApexClassesByPattern(pattern, targetOrg = 'Devin1') {
        try {
            const { stdout } = await execAsync(
                `sf data query --query "SELECT Id, Name, Body FROM ApexClass WHERE Name LIKE '${pattern}'" --target-org ${targetOrg} --json`
            );
            const result = JSON.parse(stdout);
            if (result.result?.records?.length > 0) {
                return result.result.records.map(r => ({ name: r.Name, body: r.Body }));
            }
            return [];
        } catch (error) {
            this.logger.error(`Failed to fetch Apex classes matching ${pattern}:`, error);
            return [];
        }
    }

    /**
     * Fetch related classes for a given class (handler, helper, service, test)
     * @param {string} baseClassName - Base class name (e.g., 'ContactTriggerHandler')
     * @param {string} targetOrg - Target org alias
     * @returns {Object} - { main, helper, service, test, trigger, baseClass }
     */
    async getRelatedClasses(baseClassName, targetOrg = 'Devin1') {
        // Extract the object name from the class name
        const objectMatch = baseClassName.match(/^(\w+?)(?:Trigger|Handler|Helper|Service|Test)?$/i);
        const objectName = objectMatch ? objectMatch[1] : baseClassName;

        const patterns = [
            baseClassName,                           // Main class
            `${objectName}TriggerHandler`,          // Handler
            `${objectName}TriggerHelper`,           // Helper
            `${objectName}Helper`,                  // Alternative helper
            `${objectName}Service`,                 // Service
            `${objectName}Trigger`,                 // Trigger (ApexTrigger table)
            `${baseClassName}Test`,                 // Test class
            `Test${baseClassName}`,                 // Alternative test
            'TriggerHandler'                        // Base class
        ];

        const uniquePatterns = [...new Set(patterns)];
        const relatedClasses = {};

        for (const pattern of uniquePatterns) {
            const result = await this.getApexClass(pattern, targetOrg);
            if (result.found) {
                relatedClasses[pattern] = result.body;
            }
        }

        // Also try to get the trigger
        try {
            const { stdout } = await execAsync(
                `sf data query --query "SELECT Id, Name, Body FROM ApexTrigger WHERE Name = '${objectName}Trigger'" --target-org ${targetOrg} --json`
            );
            const result = JSON.parse(stdout);
            if (result.result?.records?.length > 0) {
                relatedClasses[`${objectName}Trigger`] = result.result.records[0].Body;
            }
        } catch (e) {
            // Ignore trigger fetch errors
        }

        return relatedClasses;
    }

    async validateApex(apexCode) {
        try {
            // Handle both string and object formats
            // Object format: { "ClassName.cls": "apex code content", ... }
            // String format: direct apex code string
            const filesToValidate = typeof apexCode === 'object' ? apexCode : { 'temp.cls': apexCode };

            await fs.ensureDir('./temp');
            const errors = [];

            for (const [fileName, content] of Object.entries(filesToValidate)) {
                if (typeof content !== 'string') {
                    errors.push(`Invalid content type for ${fileName}: expected string`);
                    continue;
                }

                const tempFile = path.join('./temp', `apex-${Date.now()}-${fileName}`);
                await fs.writeFile(tempFile, content);

                // Basic syntax validation - check for common issues
                const syntaxErrors = this.checkApexSyntax(content, fileName);
                if (syntaxErrors.length > 0) {
                    errors.push(...syntaxErrors);
                }

                await fs.remove(tempFile);
            }

            return { success: errors.length === 0, errors };
        } catch (error) {
            return { success: false, errors: [error.message] };
        }
    }

    checkApexSyntax(code, fileName) {
        const errors = [];

        // Check for basic syntax issues
        const openBraces = (code.match(/\{/g) || []).length;
        const closeBraces = (code.match(/\}/g) || []).length;
        if (openBraces !== closeBraces) {
            errors.push(`${fileName}: Mismatched braces (${openBraces} open, ${closeBraces} close)`);
        }

        // Check for SOQL in loops (common issue)
        if (/for\s*\([^)]*\)[^{]*\{[^}]*\[SELECT/gi.test(code)) {
            errors.push(`${fileName}: Potential SOQL query inside loop detected`);
        }

        // Check for DML in loops
        if (/for\s*\([^)]*\)[^{]*\{[^}]*(insert|update|delete|upsert)\s+/gi.test(code)) {
            errors.push(`${fileName}: Potential DML operation inside loop detected`);
        }

        return errors;
    }

    async validateMetadata(metadata) {
        try {
            const errors = [];

            // Handle both formats:
            // 1. Object format: { "filename.xml": "xml content", ... } (from AI generator)
            // 2. Structured format: { objects: [...], fields: [...] }
            if (typeof metadata === 'object') {
                // Check if it's the filename:content format
                const keys = Object.keys(metadata);
                const isFileFormat = keys.some(key => key.endsWith('.xml') || key.endsWith('.cls'));

                if (isFileFormat) {
                    // Validate each metadata file
                    for (const [fileName, content] of Object.entries(metadata)) {
                        if (typeof content !== 'string') {
                            errors.push(`Invalid content type for ${fileName}: expected string`);
                            continue;
                        }

                        // Basic XML validation for metadata files
                        if (fileName.endsWith('.xml')) {
                            if (!content.includes('<?xml') && !content.includes('<')) {
                                errors.push(`${fileName}: Invalid XML structure`);
                            }
                        }
                    }
                } else {
                    // Original structured format
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
                const error = `DEPLOYMENT BLOCKED: "${targetOrg}" appears to be a production org. Only sandbox deployments are allowed. Whitelisted sandboxes: ${this.SANDBOX_WHITELIST.join(', ')}`;
                this.logger.error(error);
                throw new Error(error);
            }
        }

        // Warn if org not in whitelist (but allow with warning)
        this.logger.warn(`⚠ WARNING: "${targetOrg}" is not in the sandbox whitelist. Proceeding with caution.`);
        this.logger.warn(`⚠ Whitelisted sandboxes: ${this.SANDBOX_WHITELIST.join(', ')}`);
        this.logger.warn(`⚠ If this is a production org, STOP NOW and update the target org.`);

        return true;
    }

    async deployToSandbox(artifacts, targetOrg = 'dev-sandbox') {
        try {
            // SAFETY CHECK: Validate target org is sandbox
            this.validateSandboxTarget(targetOrg);

            this.logger.info(`Deploying to ${targetOrg}...`);

            // Create deployment package
            const deployDir = path.join('./deploy', `deploy-${Date.now()}`);
            await fs.ensureDir(deployDir);

            // Write artifacts to deployment directory
            if (artifacts.apex) {
                const apexDir = path.join(deployDir, 'classes');
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
                const metadataDir = path.join(deployDir, 'objects');
                await fs.ensureDir(metadataDir);
                for (const [fileName, content] of Object.entries(artifacts.metadata)) {
                    await fs.writeFile(path.join(metadataDir, fileName), content);
                }
            }

            // Create package.xml
            await fs.writeFile(
                path.join(deployDir, 'package.xml'),
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
                success: result.result.status === 'Succeeded',
                deploymentId: result.result.id,
                details: result.result
            };
        } catch (error) {
            this.logger.error('Deployment failed:', error);
            throw error;
        }
    }

    generateApexMetaXml() {
        return `<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>${process.env.SF_API_VERSION || '60.0'}</apiVersion>
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
    ${types.join('\n')}
    <version>${process.env.SF_API_VERSION || '60.0'}</version>
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
            this.logger.error('Test execution failed:', error);
            throw error;
        }
    }

    async getApexClasses() {
        try {
            const conn = this.connections.production;
            const result = await conn.metadata.list([{ type: 'ApexClass' }]);
            return Array.isArray(result) ? result : [result];
        } catch (error) {
            this.logger.error('Failed to fetch Apex classes:', error);
            throw error;
        }
    }

    async getApexClassContent(className) {
        try {
            const conn = this.connections.production;
            const result = await conn.tooling.sobject('ApexClass')
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
