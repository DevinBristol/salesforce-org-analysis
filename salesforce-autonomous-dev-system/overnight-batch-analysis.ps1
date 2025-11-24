# Overnight Batch Codebase Analysis
# Analyzes entire codebase and generates comprehensive org report

param(
    [switch]$Deep,          # Use --analyze-content for deep analysis (slower)
    [int]$Limit = 0,        # Limit number of classes (0 = all)
    [switch]$IncludeTests,  # Include test classes
    [switch]$IncludeManaged # Include managed package classes
)

Write-Host "Starting Overnight Batch Codebase Analysis" -ForegroundColor Cyan
Write-Host ""

cd $PSScriptRoot

# Build command arguments
$args = @()
if ($Deep) {
    Write-Host "Deep Analysis Mode: Will fetch and analyze class content" -ForegroundColor Yellow
    Write-Host "This will be slower but more accurate" -ForegroundColor Gray
    $args += "--analyze-content"
} else {
    Write-Host "Fast Analysis Mode: Metadata-based scoring only" -ForegroundColor Yellow
}

if ($Limit -gt 0) {
    Write-Host "Analyzing first $Limit classes" -ForegroundColor Yellow
    $args += "--limit"
    $args += $Limit
} else {
    Write-Host "Analyzing ALL classes in org (~3,934 classes)" -ForegroundColor Yellow
}

if ($IncludeTests) {
    $args += "--include-tests"
}

if ($IncludeManaged) {
    $args += "--include-managed"
}

Write-Host ""
Write-Host "=======================================" -ForegroundColor Blue
Write-Host "Running Batch Analysis" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Blue
Write-Host ""

# Run the batch analyzer
if ($args.Count -gt 0) {
    npm run batch:analyze -- $args
} else {
    npm run batch:analyze
}

Write-Host ""
Write-Host "Batch analysis complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Reports Generated:" -ForegroundColor Cyan
Write-Host "  - ./analysis/org-analysis-report.md  (Comprehensive markdown report)" -ForegroundColor White
Write-Host "  - ./analysis/org-analysis-data.json  (Detailed JSON data)" -ForegroundColor White
Write-Host "  - ./analysis/progress.json           (Progress tracking)" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Read the report:  cat ./analysis/org-analysis-report.md" -ForegroundColor Gray
Write-Host "  2. Review top issues in the Critical section" -ForegroundColor Gray
Write-Host "  3. Run improvements on specific classes with: npm run demo:apex-improvement" -ForegroundColor Gray
Write-Host "  4. Re-run deep analysis on high-priority files: .\overnight-batch-analysis.ps1 -Deep -Limit 50" -ForegroundColor Gray
Write-Host ""
