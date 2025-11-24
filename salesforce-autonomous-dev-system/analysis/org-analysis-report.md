# Salesforce Org Codebase Analysis Report

**Generated:** 2025-11-24T05:51:23.453Z
**Total Classes Analyzed:** 141
**Analysis Type:** Deep (with content analysis)

---

## Executive Summary

### Overall Org Health Score

**🟠 Fair** (43.5 / 100)

### Key Metrics

- **Total Classes:** 141
- **Org Test Coverage:** 79% 🟡
- **Average Improvement Score:** 43.5
- **Classes Needing Attention:** 95 (67.4%)
- **Security Issues:** 39 CRITICAL, 8 HIGH
- **Technical Debt:** 255.4 hours (31.9 days)

### Priority Breakdown

- 🔴 **Critical (60+ points):** 14 classes
- 🟠 **High (40-59 points):** 81 classes
- 🟡 **Medium (20-39 points):** 43 classes
- 🟢 **Low (<20 points):** 3 classes

### Test Coverage Breakdown

- **0% Coverage:** 17 classes (🔴 HIGH PRIORITY)
- **<75% Coverage:** 13 classes (🟠 Blocks deployment)
- **75-90% Coverage:** 36 classes (🟡 Good)
- **90%+ Coverage:** 75 classes (✅ Excellent)

### Security Alert Summary

- **🚨 CRITICAL:** 39 classes with critical vulnerabilities
- **⚠️ HIGH:** 8 classes with high-risk issues

### Risk Distribution

- ⚠️ **High Risk:** 14 classes
- ⚡ **Medium Risk:** 42 classes
- ✅ **Low Risk:** 85 classes

---

## Top 20 Classes Needing Improvement

| Rank | Class Name                         | Score | Risk   | Key Issues                                                                               |
| ---- | ---------------------------------- | ----- | ------ | ---------------------------------------------------------------------------------------- |
| 1    | AutocreatedRegHandler1712123914661 | 70    | MEDIUM | Last modified 20 months ago; Handler class - likely needs bulkification review           |
| 2    | DispoHandler                       | 70    | MEDIUM | Last modified 9 months ago; Handler class - likely needs bulkification review            |
| 3    | PropertyTriggerHelper              | 65    | MEDIUM | Last modified 14 months ago; Utility/Helper class - safe to optimize                     |
| 4    | AccountTriggerHandler              | 65    | MEDIUM | Last modified 14 months ago; Handler class - likely needs bulkification review           |
| 5    | TriggerHandler                     | 65    | MEDIUM | Last modified 19 months ago; Handler class - likely needs bulkification review           |
| 6    | CollectionProcessorsUtils          | 65    | LOW    | Last modified 21 months ago; Utility/Helper class - safe to optimize                     |
| 7    | PhoneRelationHelper                | 63    | HIGH   | Last modified 10 months ago; Utility/Helper class - safe to optimize                     |
| 8    | TaskTriggerHandler                 | 60    | MEDIUM | Last modified 9 months ago; Handler class - likely needs bulkification review            |
| 9    | PropertyTriggerHandler             | 60    | MEDIUM | Last modified 10 months ago; Handler class - likely needs bulkification review           |
| 10   | ExecuteSOQL                        | 60    | LOW    | Not modified for 25 months - high priority for review; Missing class-level documentation |
| 11   | OpportunityTriggerHandler          | 60    | MEDIUM | Last modified 9 months ago; Handler class - likely needs bulkification review            |
| 12   | WorkOrderTriggerHandler            | 60    | MEDIUM | Last modified 10 months ago; Handler class - likely needs bulkification review           |
| 13   | ContactTriggerHandler              | 60    | MEDIUM | Last modified 10 months ago; Handler class - likely needs bulkification review           |
| 14   | LeadTriggerHandler                 | 60    | MEDIUM | Last modified 10 months ago; Handler class - likely needs bulkification review           |
| 15   | AniAssignerBatchable               | 58    | HIGH   | Last modified 7 months ago; Batch/Scheduled class - performance critical                 |
| 16   | AudioScavengeBatch                 | 56    | HIGH   | Last modified 9 months ago; Batch/Scheduled class - performance critical                 |
| 17   | AccountService                     | 56    | LOW    | Last modified 14 months ago; Service class - good candidate for improvement              |
| 18   | LeadService                        | 56    | LOW    | Last modified 14 months ago; Service class - good candidate for improvement              |
| 19   | QuoteAmountChangesService          | 56    | LOW    | Last modified 14 months ago; Service class - good candidate for improvement              |
| 20   | WorkOrderRelationHandler           | 55    | MEDIUM | Last modified 13 months ago; Handler class - likely needs bulkification review           |

---

## Critical Issues (60+ Score)

### 1. AutocreatedRegHandler1712123914661

- **Score:** 70 / 100
- **Risk Level:** MEDIUM
- **Last Modified:** 4/3/2024
- **Issues:**
  - Last modified 20 months ago
  - Handler class - likely needs bulkification review
  - Missing class-level documentation
  - Low documentation coverage (0%)
  - Minimal error handling - needs try-catch blocks
- **Score Breakdown:**
  - Age: 15 pts
  - Type: 20 pts
  - Complexity: 0 pts
  - Documentation: 20 pts
  - Error Handling: 15 pts
  - Bulkification: 0 pts

---

### 2. DispoHandler

- **Score:** 70 / 100
- **Risk Level:** MEDIUM
- **Last Modified:** 2/20/2025
- **Issues:**
  - Last modified 9 months ago
  - Handler class - likely needs bulkification review
  - Medium-large class (379 lines)
  - Many methods (23) - needs organization
  - Low documentation coverage (4%)
  - Minimal error handling - needs try-catch blocks
- **Score Breakdown:**
  - Age: 10 pts
  - Type: 20 pts
  - Complexity: 15 pts
  - Documentation: 10 pts
  - Error Handling: 15 pts
  - Bulkification: 0 pts

---

### 3. PropertyTriggerHelper

- **Score:** 65 / 100
- **Risk Level:** MEDIUM
- **Last Modified:** 10/9/2024
- **Issues:**
  - Last modified 14 months ago
  - Utility/Helper class - safe to optimize
  - Trigger handler - critical for bulkification
  - Low documentation coverage (20%)
  - Minimal error handling - needs try-catch blocks
- **Score Breakdown:**
  - Age: 15 pts
  - Type: 25 pts
  - Complexity: 0 pts
  - Documentation: 10 pts
  - Error Handling: 15 pts
  - Bulkification: 0 pts

---

### 4. AccountTriggerHandler

- **Score:** 65 / 100
- **Risk Level:** MEDIUM
- **Last Modified:** 10/9/2024
- **Issues:**
  - Last modified 14 months ago
  - Handler class - likely needs bulkification review
  - Trigger handler - critical for bulkification
  - Low documentation coverage (0%)
  - Minimal error handling - needs try-catch blocks
- **Score Breakdown:**
  - Age: 15 pts
  - Type: 25 pts
  - Complexity: 0 pts
  - Documentation: 10 pts
  - Error Handling: 15 pts
  - Bulkification: 0 pts

---

### 5. TriggerHandler

- **Score:** 65 / 100
- **Risk Level:** MEDIUM
- **Last Modified:** 5/17/2024
- **Issues:**
  - Last modified 19 months ago
  - Handler class - likely needs bulkification review
  - Trigger handler - critical for bulkification
  - Partial documentation - needs completion
  - Minimal error handling - needs try-catch blocks
- **Score Breakdown:**
  - Age: 15 pts
  - Type: 25 pts
  - Complexity: 5 pts
  - Documentation: 5 pts
  - Error Handling: 15 pts
  - Bulkification: 0 pts

---

### 6. CollectionProcessorsUtils

- **Score:** 65 / 100
- **Risk Level:** LOW
- **Last Modified:** 3/6/2024
- **Issues:**
  - Last modified 21 months ago
  - Utility/Helper class - safe to optimize
  - Missing class-level documentation
  - Low documentation coverage (0%)
  - Minimal error handling - needs try-catch blocks
- **Score Breakdown:**
  - Age: 15 pts
  - Type: 15 pts
  - Complexity: 0 pts
  - Documentation: 20 pts
  - Error Handling: 15 pts
  - Bulkification: 0 pts

---

### 7. PhoneRelationHelper

- **Score:** 63 / 100
- **Risk Level:** HIGH
- **Last Modified:** 2/5/2025
- **Issues:**
  - Last modified 10 months ago
  - Utility/Helper class - safe to optimize
  - Medium-large class (386 lines)
  - Partial documentation - needs completion
  - Minimal error handling - needs try-catch blocks
  - DML in loop detected - CRITICAL bulkification needed
- **Score Breakdown:**
  - Age: 10 pts
  - Type: 15 pts
  - Complexity: 10 pts
  - Documentation: 5 pts
  - Error Handling: 15 pts
  - Bulkification: 8 pts

---

### 8. TaskTriggerHandler

- **Score:** 60 / 100
- **Risk Level:** MEDIUM
- **Last Modified:** 2/21/2025
- **Issues:**
  - Last modified 9 months ago
  - Handler class - likely needs bulkification review
  - Trigger handler - critical for bulkification
  - Low documentation coverage (0%)
  - Minimal error handling - needs try-catch blocks
- **Score Breakdown:**
  - Age: 10 pts
  - Type: 25 pts
  - Complexity: 0 pts
  - Documentation: 10 pts
  - Error Handling: 15 pts
  - Bulkification: 0 pts

---

### 9. PropertyTriggerHandler

- **Score:** 60 / 100
- **Risk Level:** MEDIUM
- **Last Modified:** 2/5/2025
- **Issues:**
  - Last modified 10 months ago
  - Handler class - likely needs bulkification review
  - Trigger handler - critical for bulkification
  - Low documentation coverage (0%)
  - Minimal error handling - needs try-catch blocks
- **Score Breakdown:**
  - Age: 10 pts
  - Type: 25 pts
  - Complexity: 0 pts
  - Documentation: 10 pts
  - Error Handling: 15 pts
  - Bulkification: 0 pts

---

### 10. ExecuteSOQL

- **Score:** 60 / 100
- **Risk Level:** LOW
- **Last Modified:** 11/10/2023
- **Issues:**
  - Not modified for 25 months - high priority for review
  - Missing class-level documentation
  - Low documentation coverage (0%)
  - Minimal error handling - needs try-catch blocks
- **Score Breakdown:**
  - Age: 20 pts
  - Type: 0 pts
  - Complexity: 5 pts
  - Documentation: 20 pts
  - Error Handling: 15 pts
  - Bulkification: 0 pts

---

## High Priority (40-59 Score)

- **AniAssignerBatchable** (Score: 58, Risk: high)
  - Last modified 7 months ago
  - Batch/Scheduled class - performance critical
  - Low documentation coverage (25%)
  - Minimal error handling - needs try-catch blocks

- **AudioScavengeBatch** (Score: 56, Risk: high)
  - Last modified 9 months ago
  - Batch/Scheduled class - performance critical
  - Partial documentation - needs completion
  - Minimal error handling - needs try-catch blocks
  - DML in loop detected - CRITICAL bulkification needed

- **AccountService** (Score: 56, Risk: low)
  - Last modified 14 months ago
  - Service class - good candidate for improvement
  - Low documentation coverage (0%)
  - Minimal error handling - needs try-catch blocks

- **LeadService** (Score: 56, Risk: low)
  - Last modified 14 months ago
  - Service class - good candidate for improvement
  - Low documentation coverage (0%)
  - Minimal error handling - needs try-catch blocks

- **QuoteAmountChangesService** (Score: 56, Risk: low)
  - Last modified 14 months ago
  - Service class - good candidate for improvement
  - Low documentation coverage (25%)
  - Minimal error handling - needs try-catch blocks

- **WorkOrderRelationHandler** (Score: 55, Risk: medium)
  - Last modified 13 months ago
  - Handler class - likely needs bulkification review
  - Partial documentation - needs completion
  - Minimal error handling - needs try-catch blocks

- **AnalyticsUtility** (Score: 55, Risk: high)
  - Utility/Helper class - safe to optimize
  - Large class (611 lines) - high complexity
  - Low documentation coverage (6%)
  - Minimal error handling - needs try-catch blocks

- **MyProfilePageController** (Score: 55, Risk: medium)
  - Not modified for 26 months - high priority for review
  - Controller class - may benefit from optimization
  - Low documentation coverage (17%)
  - Minimal error handling - needs try-catch blocks

- **AccountTriggerHelper** (Score: 55, Risk: medium)
  - Last modified 12 months ago
  - Utility/Helper class - safe to optimize
  - Trigger handler - critical for bulkification
  - Partial documentation - needs completion
  - Minimal error handling - needs try-catch blocks

- **CollectionCalculate** (Score: 55, Risk: low)
  - Last modified 21 months ago
  - Missing class-level documentation
  - Low documentation coverage (0%)
  - Minimal error handling - needs try-catch blocks

- **GenerateCollectionReport** (Score: 55, Risk: low)
  - Last modified 21 months ago
  - Missing class-level documentation
  - Low documentation coverage (0%)
  - Minimal error handling - needs try-catch blocks

- **DispositionHelper** (Score: 55, Risk: low)
  - Last modified 14 months ago
  - Utility/Helper class - safe to optimize
  - Low documentation coverage (25%)
  - Minimal error handling - needs try-catch blocks

- **WorkOrderTriggerHelper** (Score: 55, Risk: medium)
  - Last modified 14 months ago
  - Utility/Helper class - safe to optimize
  - Trigger handler - critical for bulkification
  - Minimal error handling - needs try-catch blocks

- **LeadTriggerHelper** (Score: 55, Risk: medium)
  - Utility/Helper class - safe to optimize
  - Trigger handler - critical for bulkification
  - Low documentation coverage (11%)
  - Minimal error handling - needs try-catch blocks

- **OpportunityTriggerHelper** (Score: 55, Risk: medium)
  - Last modified 9 months ago
  - Utility/Helper class - safe to optimize
  - Trigger handler - critical for bulkification
  - Partial documentation - needs completion
  - Minimal error handling - needs try-catch blocks

---

## 🔐 Security Vulnerabilities

### 🚨 CRITICAL Security Issues (Immediate Fix Required)

#### 1. AutocreatedRegHandler1712123914661

- **SOQL Injection Risk**
  - Severity: CRITICAL
  - Description: Dynamic SOQL without proper escaping detected
  - Recommendation: Use String.escapeSingleQuotes() or static SOQL with bind variables

#### 2. DispoHandler

- **SOQL Injection Risk**
  - Severity: CRITICAL
  - Description: Dynamic SOQL without proper escaping detected
  - Recommendation: Use String.escapeSingleQuotes() or static SOQL with bind variables

#### 3. PhoneRelationHelper

- **SOQL Injection Risk**
  - Severity: CRITICAL
  - Description: Dynamic SOQL without proper escaping detected
  - Recommendation: Use String.escapeSingleQuotes() or static SOQL with bind variables

#### 4. ExecuteSOQL

- **SOQL Injection Risk**
  - Severity: CRITICAL
  - Description: Dynamic SOQL without proper escaping detected
  - Recommendation: Use String.escapeSingleQuotes() or static SOQL with bind variables

#### 5. AniAssignerBatchable

- **SOQL Injection Risk**
  - Severity: CRITICAL
  - Description: Dynamic SOQL without proper escaping detected
  - Recommendation: Use String.escapeSingleQuotes() or static SOQL with bind variables

#### 6. AudioScavengeBatch

- **SOQL Injection Risk**
  - Severity: CRITICAL
  - Description: Dynamic SOQL without proper escaping detected
  - Recommendation: Use String.escapeSingleQuotes() or static SOQL with bind variables

#### 7. AnalyticsUtility

- **SOQL Injection Risk**
  - Severity: CRITICAL
  - Description: Dynamic SOQL without proper escaping detected
  - Recommendation: Use String.escapeSingleQuotes() or static SOQL with bind variables

#### 8. LeadTriggerHelper

- **SOQL Injection Risk**
  - Severity: CRITICAL
  - Description: Dynamic SOQL without proper escaping detected
  - Recommendation: Use String.escapeSingleQuotes() or static SOQL with bind variables

#### 9. LeadPropertyRelationshipBatchable

- **SOQL Injection Risk**
  - Severity: CRITICAL
  - Description: Dynamic SOQL without proper escaping detected
  - Recommendation: Use String.escapeSingleQuotes() or static SOQL with bind variables

#### 10. GetRecordsFromIds

- **SOQL Injection Risk**
  - Severity: CRITICAL
  - Description: Dynamic SOQL without proper escaping detected
  - Recommendation: Use String.escapeSingleQuotes() or static SOQL with bind variables

### ⚠️ HIGH Security Issues (Fix This Sprint)

- **AssertionIterators**
  - Sensitive Data Exposure: Potentially logging sensitive data in debug statements

- **JsonUtility**
  - Sensitive Data Exposure: Potentially logging sensitive data in debug statements

- **Five9Helper**
  - Sensitive Data Exposure: Potentially logging sensitive data in debug statements

- **SObjectDeepClone**
  - Sensitive Data Exposure: Potentially logging sensitive data in debug statements

- **Five9Response**
  - Sensitive Data Exposure: Potentially logging sensitive data in debug statements

- **RefreshCompanyCamTokenJob**
  - Sensitive Data Exposure: Potentially logging sensitive data in debug statements

- **CommunitiesSelfRegController**
  - Sensitive Data Exposure: Potentially logging sensitive data in debug statements

- **Response**
  - Sensitive Data Exposure: Potentially logging sensitive data in debug statements

---

## 📊 Test Coverage Analysis

### Coverage Summary

- **Org-Wide Coverage:** 79% (Production deployable)
- **Goal:** 90%
- **Gap to Goal:** 11%

### Path to 90% Coverage

**1. Zero Coverage Classes (17 classes)**

Priority: 🔴 CRITICAL - Generate tests immediately

Top 10 classes needing tests:

1. AutocreatedRegHandler1712123914661 (93 lines, 0% coverage)
2. AccountService (7 lines, 0% coverage)
3. LeadService (24 lines, 0% coverage)
4. FilterByCollection (59 lines, 0% coverage)
5. QueryWithLimit (43 lines, 0% coverage)
6. DedupeRecordCollection (49 lines, 0% coverage)
7. AssertionIterators (339 lines, 0% coverage)
8. RundownExportController (484 lines, 0% coverage)
9. ManageOppTeamMembersService (228 lines, 0% coverage)
10. LWCHelperFunctions (12 lines, 0% coverage)

**Estimated Effort:** 34 hours (4.3 days @ 2 hrs/class)

**2. Sub-75% Coverage Classes (13 classes)**

Priority: 🟠 HIGH - Blocking production deployment

Classes closest to 75% (quick wins):

1. AniBatchAssigner (70% - need 5% more)
2. CompanyCamAPI (70% - need 5% more)
3. BinaryFile (68% - need 7% more)
4. CompanyCamAuthController (65% - need 10% more)
5. AniAssignerBatchable (63% - need 12% more)
6. PropertyService (63% - need 12% more)
7. WorkOrderRelationHelper (54% - need 21% more)
8. GetLookupCollection (54% - need 21% more)
9. OpportunityTriggerHelper (48% - need 27% more)
10. CollectionProcessorsUtils (34% - need 41% more)

**Estimated Effort:** 20 hours (2.4 days @ 1.5 hrs/class)

**3. Total Path to 90%**

- Generate tests for 17 zero-coverage classes
- Improve 13 sub-75% classes
- **Total Estimated Effort:** 54 hours (6.7 days)
- **At 20 hrs/week:** 2.7 weeks

---

## 🧮 Code Complexity & Technical Debt

### Complexity Overview

- **High Complexity Classes (>50):** 11 classes
- **Total Technical Debt:** 255.4 hours (31.9 days)
- **Average Debt per Class:** 1.81 hours

### Highest Complexity Classes (Refactor Candidates)

1. **DispoHandler**
   - Cyclomatic Complexity: 63
   - Maintainability Index: 17/100 🔴
   - Technical Debt: 11.4 hours
   - Lines of Code: 379

2. **PhoneRelationHelper**
   - Cyclomatic Complexity: 91
   - Maintainability Index: 11/100 🔴
   - Technical Debt: 11.6 hours
   - Lines of Code: 386

3. **AnalyticsUtility**
   - Cyclomatic Complexity: 119
   - Maintainability Index: 0/100 🔴
   - Technical Debt: 27.5 hours
   - Lines of Code: 611

4. **GenerateCollectionReport**
   - Cyclomatic Complexity: 58
   - Maintainability Index: 24/100 🔴
   - Technical Debt: 4.5 hours
   - Lines of Code: 300

5. **SortCollection**
   - Cyclomatic Complexity: 64
   - Maintainability Index: 20/100 🔴
   - Technical Debt: 10 hours
   - Lines of Code: 333

6. **NamingUtility**
   - Cyclomatic Complexity: 72
   - Maintainability Index: 22/100 🔴
   - Technical Debt: 4.2 hours
   - Lines of Code: 281

7. **SfMapsRetriever**
   - Cyclomatic Complexity: 175
   - Maintainability Index: 0/100 🔴
   - Technical Debt: 32.4 hours
   - Lines of Code: 719

8. **Five9ReportManager**
   - Cyclomatic Complexity: 78
   - Maintainability Index: 5/100 🔴
   - Technical Debt: 26.6 hours
   - Lines of Code: 590

9. **AniAssigner**
   - Cyclomatic Complexity: 60
   - Maintainability Index: 20/100 🔴
   - Technical Debt: 10.4 hours
   - Lines of Code: 346

10. **SFMapsAPI**

- Cyclomatic Complexity: 60
- Maintainability Index: 34/100 🔴
- Technical Debt: 2.7 hours
- Lines of Code: 177

### Technical Debt Breakdown

- **High Priority (Complexity >50):** 171.7 hours
- **Medium Priority (30-50):** 35.0 hours
- **Low Priority (<30):** 48.7 hours

---

## 📱 API Version Health

### Summary

- **Deprecated (API <50):** 141 classes 🔴 CRITICAL
- **Outdated (API <60):** 141 classes 🟠 Recommended upgrade
- **Current (API >=60):** 0 classes ✅

### 🔴 CRITICAL: Deprecated API Versions

These classes use deprecated API versions and may have security/compatibility issues:

- AutocreatedRegHandler1712123914661 (API v0)
- DispoHandler (API v0)
- PropertyTriggerHelper (API v0)
- AccountTriggerHandler (API v0)
- TriggerHandler (API v0)
- CollectionProcessorsUtils (API v0)
- PhoneRelationHelper (API v0)
- TaskTriggerHandler (API v0)
- PropertyTriggerHandler (API v0)
- ExecuteSOQL (API v0)

**Action Required:** Upgrade to API v64 immediately

---

## Recommendations

### Immediate Actions (Next Sprint)

- Fix bulkification issues in 1 classes (CRITICAL)
- Add comprehensive documentation to 12 classes
- Implement error handling in 14 classes
- Review and modernize 6 outdated classes

### Short-Term Actions (Next Month)

- Fix bulkification issues in 2 classes (CRITICAL)
- Add comprehensive documentation to 60 classes
- Implement error handling in 77 classes
- Review and modernize 47 outdated classes

### Long-Term Strategy

- Add comprehensive documentation to 17 classes
- Implement error handling in 31 classes
- Review and modernize 4 outdated classes

---

## Category Analysis

### Documentation Needs

- **AutocreatedRegHandler1712123914661** (20 pts) - Missing class-level documentation
- **CollectionProcessorsUtils** (20 pts) - Missing class-level documentation
- **ExecuteSOQL** (20 pts) - Missing class-level documentation
- **CollectionCalculate** (20 pts) - Missing class-level documentation
- **GenerateCollectionReport** (20 pts) - Missing class-level documentation
- **JoinCollections** (20 pts) - Missing class-level documentation
- **CopyCollection** (20 pts) - Missing class-level documentation
- **EvaluateFormula** (20 pts) - Missing class-level documentation
- **GetRecordsFromIds** (20 pts) - Missing class-level documentation
- **ConvertStringCollectionToCSV_CP** (20 pts) - Missing class-level documentation

### Bulkification Issues

- **PhoneRelationHelper** (8 pts) - DML in loop detected - CRITICAL bulkification needed
- **AudioScavengeBatch** (8 pts) - DML in loop detected - CRITICAL bulkification needed
- **ManageOppTeamMembersService** (7 pts) - SOQL in loop detected - needs bulkification

### Error Handling Gaps

- **AutocreatedRegHandler1712123914661** (15 pts) - Minimal error handling - needs try-catch blocks
- **DispoHandler** (15 pts) - Minimal error handling - needs try-catch blocks
- **PropertyTriggerHelper** (15 pts) - Minimal error handling - needs try-catch blocks
- **AccountTriggerHandler** (15 pts) - Minimal error handling - needs try-catch blocks
- **TriggerHandler** (15 pts) - Minimal error handling - needs try-catch blocks
- **CollectionProcessorsUtils** (15 pts) - Minimal error handling - needs try-catch blocks
- **PhoneRelationHelper** (15 pts) - Minimal error handling - needs try-catch blocks
- **TaskTriggerHandler** (15 pts) - Minimal error handling - needs try-catch blocks
- **PropertyTriggerHandler** (15 pts) - Minimal error handling - needs try-catch blocks
- **ExecuteSOQL** (15 pts) - Minimal error handling - needs try-catch blocks

### Complexity Concerns

- **PropertyWorkOrderApi** (20 pts) - Large class (676 lines) - high complexity
- **DispoHandler** (15 pts) - Medium-large class (379 lines)
- **AnalyticsUtility** (15 pts) - Large class (611 lines) - high complexity
- **SfMapsRetriever** (15 pts) - Large class (719 lines) - high complexity
- **Five9ReportManager** (15 pts) - Large class (590 lines) - high complexity
- **PhoneRelationHelper** (10 pts) - Medium-large class (386 lines)
- **AssertionIterators** (10 pts) - Medium-large class (339 lines)
- **SortCollection** (10 pts) - Medium-large class (333 lines)
- **RundownExportController** (10 pts) - Medium-large class (484 lines)
- **AniAssigner** (10 pts) - Medium-large class (346 lines)

---

## Statistics

- **Average Score:** 43.5
- **Median Score:** 45
- **Highest Score:** 70 (AutocreatedRegHandler1712123914661)
- **Lowest Score:** 15 (DeepClone)

### Score Distribution

0-10: 0 (0.0%)
10-20: █ 3 (2.1%)
20-30: █████ 13 (9.2%)
30-40: ███████████ 30 (21.3%)
40-50: ███████████ 32 (22.7%)
50-60: █████████████████ 49 (34.8%)
60-70: ████ 12 (8.5%)
70-80: █ 2 (1.4%)
80-90: 0 (0.0%)
90-100: 0 (0.0%)

---

## Next Steps

1. **Review Critical Classes** - Start with the top 10 classes listed above
2. **Run Improvements** - Use `npm run demo:apex-improvement` to improve individual classes
3. **Documentation Pass** - Add JavaDoc to classes with high documentation scores
4. **Bulkification Review** - Fix SOQL/DML in loops immediately
5. **Deploy to Sandbox** - Test improvements in Devin1 before production

## Commands

**Analyze specific class:**

```bash
npm run demo:apex-improvement
```

**Re-run batch analysis with content (slower, more accurate):**

```bash
node demos/batch-analyzer.js --analyze-content
```

---

_Generated by Autonomous Salesforce Development System_
