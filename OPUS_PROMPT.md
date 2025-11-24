# MISSION: Build Autonomous Salesforce Development Acceleration System (12-Hour Sprint)

## Objective
Build and deploy a **fully operational autonomous development system** that enables rapid, AI-assisted Salesforce development. This system should be running and usable within 12 hours.

## Critical Context: What You're Building FOR (Not What You're Fixing)

### Business Context
- **Company**: Bristol Windows Inc (residential window replacement)
- **User**: Devin (owns business, leads all teams, currently bottlenecked by development/IT work)
- **Core Problem**: Development velocity is the #1 constraint on business growth
- **Systems in Play**: Salesforce (messy production org), CompanyCam, Five9, Birdeye, Boomerang, Excel/Sheets

### Why This Context Matters
You're not being asked to fix these systems. You're being asked to understand what KIND of development work needs to happen rapidly:
- Salesforce customizations (objects, flows, apex, LWC)
- Data transformations and migrations
- System integrations (APIs, webhooks)
- Report/dashboard automation (replacing manual Excel work)
- Testing and deployment to production org
- Bug fixes and rapid iterations on existing code

## What Success Looks Like

By the end of 12 hours, Devin should be able to:

1. **Describe a development task** in natural language (e.g., "Create a flow that syncs CompanyCam photos to Salesforce when a job status changes")
2. **Have the system autonomously**:
   - Analyze the current org state
   - Generate the code/configuration
   - Test it in a sandbox
   - Provide deployment-ready artifacts
   - Document what it built and why
3. **Deploy with one command** (or have the system deploy automatically with approval)
4. **Iterate rapidly** if something needs adjustment

## Your Mission: Build the System, Not Fix the Problems

**DO THIS:**
- ✅ Design an autonomous development pipeline
- ✅ Use the BEST available tools (AI coding assistants, modern deployment tools, whatever works)
- ✅ Build scripts that orchestrate the full development lifecycle
- ✅ Create a self-adapting system that learns from the org structure
- ✅ Make it production-ready and operable tonight
- ✅ Provide clear setup instructions and usage examples

**DO NOT DO THIS:**
- ❌ Try to fix specific bugs in the current org
- ❌ Analyze and solve business problems directly
- ❌ Get bogged down in "what should we build"
- ❌ Spend time on perfect documentation or polish
- ❌ Constrain yourself to traditional Salesforce tools if better options exist

## Required Deliverables

1. **One-Command Setup Script**
   - Installs all dependencies
   - Configures connections to Salesforce org
   - Sets up AI tooling integrations
   - Verifies everything is working

2. **Autonomous Development Engine**
   - Takes natural language input describing a dev task
   - Analyzes current org metadata
   - Generates code/config (Apex, Flows, LWC, integrations, etc.)
   - Runs tests automatically
   - Provides deployment artifacts

3. **Rapid Iteration Loop**
   - Fast feedback on what was built
   - Easy modification/refinement process
   - One-command deploy or auto-deploy with approval

4. **Quick Start Guide**
   - How to run the setup
   - How to submit a development task
   - How to deploy results
   - How to troubleshoot common issues

## Technical Freedom

You have COMPLETE freedom to choose:
- Any AI models/services (Claude API, OpenAI, local models, whatever is fastest)
- Any deployment tools (SFDX, Salesforce CLI, custom scripts, CI/CD platforms)
- Any languages (Python, Node.js, Bash, whatever works)
- Any architecture (local scripts, cloud functions, containers, whatever is most reliable)

**The only constraint**: It must work and be operational in 12 hours.

## Current State

You have access to:
- Salesforce production org metadata export (in `/salesforce-org-export/`)
- CONTEXT.md with business overview
- A working Salesforce DX project structure
- Devin's full attention for the next 12 hours to test and refine

## Success Metrics

At hour 12, this system should be able to:
1. Take a development request and produce deployable artifacts in < 30 minutes
2. Successfully deploy to sandbox for testing
3. Reduce Devin's time-to-solution by 10x compared to manual development
4. Handle common Salesforce development patterns autonomously

## Get Started

Begin by:
1. Analyzing the org export to understand the metadata structure
2. Designing the autonomous development pipeline architecture
3. Building the core orchestration scripts
4. Testing with a simple example (e.g., "create a custom field on Account object")
5. Iterating until the full workflow is smooth

**Timeline**: Start now. Ship in 12 hours. Prioritize working over perfect.

---

## Questions to Answer in Your Implementation

- What AI service(s) will power the code generation?
- How will you handle Salesforce authentication/connection?
- What's the fastest path from "natural language request" to "deployed code"?
- How will you make this self-adapting as the org changes?
- What's your testing strategy to avoid breaking production?

Build this like you're building for a startup that needs to ship tonight. Functional > Beautiful.
