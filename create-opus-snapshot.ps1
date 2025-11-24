# PowerShell wrapper for creating Opus repository snapshot
# Run this script to generate a complete snapshot of the repo for Opus analysis

Write-Host "🚀 Creating Opus Repository Snapshot..." -ForegroundColor Cyan
Write-Host ""

# Check if Node.js is available
try {
    $nodeVersion = node --version
    Write-Host "✓ Node.js $nodeVersion detected" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js not found. Please install Node.js first." -ForegroundColor Red
    exit 1
}

# Run the snapshot generator
node create-opus-snapshot.js

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Success! Snapshot created." -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 To copy to clipboard, run:" -ForegroundColor Yellow
    Write-Host "   Get-Content OPUS-CLIPBOARD.txt | Set-Clipboard" -ForegroundColor White
    Write-Host ""
    Write-Host "Or open the file manually:" -ForegroundColor Yellow
    Write-Host "   notepad OPUS-REPO-SNAPSHOT.md" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ Failed to create snapshot. Check errors above." -ForegroundColor Red
}
