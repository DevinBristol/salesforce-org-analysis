# Quick Task Submission Script
# Usage: .\submit-task.ps1 "Your task description here"

param(
    [Parameter(Mandatory=$true)]
    [string]$TaskDescription
)

Write-Host "🤖 Submitting task to Autonomous Dev System..." -ForegroundColor Cyan
Write-Host "Task: $TaskDescription" -ForegroundColor Yellow
Write-Host ""

cd $PSScriptRoot
npm run task "$TaskDescription"
