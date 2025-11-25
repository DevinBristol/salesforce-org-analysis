# Deployment Safety - Devin1 Sandbox Only

## Safety Measures Implemented

All deployment code has been configured with **multiple layers of safety** to ensure deployments ONLY go to Devin1 sandbox and never to production.

## 🛡️ Safety Layers

### Layer 1: Default Target Org
**All deployment methods default to Devin1 sandbox**

Files updated:
- ✅ `src/services/salesforce-manager.js` - Default: `'dev-sandbox'`
- ✅ `src/services/deployment-pipeline.js` - Default: `'Devin1'`
- ✅ `src/services/test-orchestrator.js` - Default: `'Devin1'` (3 methods)
- ✅ `demos/test-improvement-demo.js` - Default: `'Devin1'`
- ✅ `demos/apex-improvement.js` - Default: `process.env.DEV_SANDBOX || 'Devin1'`

### Layer 2: Sandbox Whitelist
**Whitelisted sandbox orgs only**

Both `SalesforceManager` and `DeploymentPipeline` have whitelists:
```javascript
SANDBOX_WHITELIST = [
    'dev-sandbox',
    'Devin1',
    'devin1',
    'test-sandbox',
    'uat-sandbox'
]
```

### Layer 3: Production Blacklist
**Deployment blocked if org name contains production indicators**

```javascript
PRODUCTION_INDICATORS = [
    'production',
    'prod',
    'live',
    'main'
]
```

If you try to deploy to an org with these words, deployment will be **BLOCKED** with error:
```
DEPLOYMENT BLOCKED: "production" appears to be a production org.
Only sandbox deployments are allowed.
Whitelisted sandboxes: dev-sandbox, Devin1, devin1, test-sandbox, uat-sandbox
```

### Layer 4: Runtime Validation
**Every deployment validates target org before executing**

Method: `validateSandboxTarget(targetOrg)`

For whitelisted orgs:
```
✓ SAFETY CHECK: Devin1 is whitelisted sandbox
```

For non-whitelisted orgs (warning, but allowed):
```
⚠ WARNING: "my-custom-sandbox" is not in the sandbox whitelist. Proceeding with caution.
⚠ Whitelisted sandboxes: dev-sandbox, Devin1, devin1, test-sandbox, uat-sandbox
⚠ If this is a production org, STOP NOW and update the target org.
```

For production orgs (BLOCKED):
```
❌ DEPLOYMENT BLOCKED: "production" appears to be a production org.
```

## Where Safety Checks Apply

### All Deployment Points

1. **SalesforceManager.deployToSandbox()**
   - Test class deployments
   - Apex class deployments
   - Metadata deployments

2. **DeploymentPipeline.deployToSandbox()**
   - Full deployment pipeline
   - Apex improvement deployments

3. **TestOrchestrator**
   - `improveTestClasses()` - Default: Devin1
   - `generateMissingTests()` - Default: Devin1
   - `runComprehensiveTestImprovement()` - Default: Devin1

## Default Commands

All these commands default to **Devin1**:

```bash
# Test improvement commands (all default to Devin1)
npm run test:improve
npm run test:generate
npm run test:comprehensive
npm run test:analyze

# Apex improvement demo (defaults to Devin1)
npm run demo:apex-improvement
```

## How to Use Different Sandbox

If you want to deploy to a different sandbox:

```bash
# Add it to whitelist first (edit the files)
# Then use --target-org flag:
node demos/test-improvement-demo.js --mode=improve --target-org=my-other-sandbox
```

## Environment Variable Override

Set in `.env`:
```
DEV_SANDBOX=Devin1
```

The apex-improvement demo uses this:
```javascript
const devSandbox = process.env.DEV_SANDBOX || 'Devin1';
```

## Adding New Sandboxes to Whitelist

If you create new sandboxes and want to whitelist them:

**Edit these files:**

1. `src/services/salesforce-manager.js` (line ~18)
2. `src/services/deployment-pipeline.js` (line ~16)

**Add to SANDBOX_WHITELIST:**
```javascript
this.SANDBOX_WHITELIST = [
    'dev-sandbox',
    'Devin1',
    'devin1',
    'test-sandbox',
    'uat-sandbox',
    'your-new-sandbox'  // Add here
];
```

## What Happens If You Try Production

**Example 1: Using blacklisted name**
```bash
node demos/test-improvement-demo.js --target-org=production
```

**Result:**
```
❌ Error: DEPLOYMENT BLOCKED: "production" appears to be a production org.
Only sandbox deployments are allowed.
Whitelisted sandboxes: dev-sandbox, Devin1, devin1, test-sandbox, uat-sandbox
```
**Deployment will NOT execute.**

**Example 2: Using non-whitelisted name without production indicators**
```bash
node demos/test-improvement-demo.js --target-org=my-custom-org
```

**Result:**
```
⚠ WARNING: "my-custom-org" is not in the sandbox whitelist. Proceeding with caution.
⚠ Whitelisted sandboxes: dev-sandbox, Devin1, devin1, test-sandbox, uat-sandbox
⚠ If this is a production org, STOP NOW and update the target org.

[Deployment proceeds]
```
**Deployment will execute with warnings.**

## Verification

To verify safety checks are working:

```bash
# This should succeed (whitelisted)
node demos/test-improvement-demo.js --mode=analyze --target-org=Devin1

# This should be BLOCKED (production indicator)
node demos/test-improvement-demo.js --mode=analyze --target-org=production
# Expected: Error thrown, deployment blocked

# This should warn but proceed
node demos/test-improvement-demo.js --mode=analyze --target-org=unknown-sandbox
# Expected: Warning messages, then proceeds
```

## Summary

✅ **Default org:** Devin1 (everywhere)
✅ **Whitelist:** Devin1, devin1, dev-sandbox, test-sandbox, uat-sandbox
✅ **Blacklist:** production, prod, live, main (BLOCKED)
✅ **Runtime validation:** Every deployment checks target org
✅ **Multiple layers:** 4 layers of protection

**You are protected from accidental production deployments.** 🛡️

All deployments will go to Devin1 by default, and any attempt to deploy to a production org will be blocked or heavily warned.
