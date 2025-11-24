# Overnight Autonomous Improvements Script
# Runs multiple improvement cycles while you sleep

param(
    [int]$Count = 5  # Number of improvements to run
)

Write-Host "🌙 Starting Overnight Autonomous Improvements" -ForegroundColor Cyan
Write-Host "Will run $Count improvement cycles" -ForegroundColor Yellow
Write-Host "Each cycle picks a different class and improves it" -ForegroundColor Gray
Write-Host ""

cd $PSScriptRoot

for ($i = 1; $i -le $Count; $i++) {
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "🔄 Improvement Cycle $i of $Count" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""

    # Run the demo which picks a random low-risk class and improves it
    npm run demo:apex-improvement

    Write-Host ""
    Write-Host "✅ Cycle $i complete!" -ForegroundColor Green
    Write-Host "Waiting 30 seconds before next cycle..." -ForegroundColor Gray
    Start-Sleep -Seconds 30
}

Write-Host ""
Write-Host "🎉 All improvement cycles complete!" -ForegroundColor Green
Write-Host "Check ./output/demo-apex-improvement/report.md for latest results" -ForegroundColor Yellow
Write-Host "Check Devin1 sandbox for deployed changes" -ForegroundColor Yellow
