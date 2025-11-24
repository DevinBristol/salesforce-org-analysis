# setup.ps1 - Windows Setup Script for Autonomous Salesforce Development System

Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Autonomous Salesforce Development System Setup    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Function to check if a command exists
function Test-Command {
    param($Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Step 1: Check Node.js
Write-Host "Checking Node.js..." -ForegroundColor Yellow
if (Test-Command "node") {
    $nodeVersion = node --version
    Write-Host "✓ Node.js installed: $nodeVersion" -ForegroundColor Green
} else {
    Write-Host "✗ Node.js not found" -ForegroundColor Red
    Write-Host "Please install Node.js from: https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

# Step 2: Check npm
Write-Host "Checking npm..." -ForegroundColor Yellow
if (Test-Command "npm") {
    $npmVersion = npm --version
    Write-Host "✓ npm installed: $npmVersion" -ForegroundColor Green
} else {
    Write-Host "✗ npm not found" -ForegroundColor Red
    exit 1
}

# Step 3: Install Salesforce CLI
Write-Host "Installing Salesforce CLI..." -ForegroundColor Yellow
npm install -g @salesforce/cli@latest
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Salesforce CLI installed" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to install Salesforce CLI" -ForegroundColor Red
    exit 1
}

# Step 4: Install project dependencies
Write-Host "Installing project dependencies..." -ForegroundColor Yellow
npm install
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Step 5: Create .env file if it doesn't exist
if (!(Test-Path ".env")) {
    Write-Host "Creating .env file..." -ForegroundColor Yellow
    Copy-Item ".env.template" ".env"
    Write-Host "✓ .env file created" -ForegroundColor Green
    Write-Host ""
    Write-Host "IMPORTANT: Please edit the .env file with your API keys and Salesforce credentials" -ForegroundColor Yellow
    notepad .env
} else {
    Write-Host "✓ .env file already exists" -ForegroundColor Green
}

# Step 6: Create required directories
Write-Host "Creating directory structure..." -ForegroundColor Yellow
$directories = @("logs", "metadata", "output", "deployments", "analysis", "temp", "cache")
foreach ($dir in $directories) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}
Write-Host "✓ Directory structure created" -ForegroundColor Green

# Step 7: Authenticate to Salesforce
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Authenticate to Salesforce:" -ForegroundColor Yellow
Write-Host "   Production org:" -ForegroundColor Gray
Write-Host "   sf org login web --alias production --instance-url https://login.salesforce.com" -ForegroundColor White
Write-Host ""
Write-Host "   Developer Sandbox:" -ForegroundColor Gray
Write-Host "   sf org login web --alias dev-sandbox --instance-url https://test.salesforce.com" -ForegroundColor White
Write-Host ""
Write-Host "2. Initialize the system:" -ForegroundColor Yellow
Write-Host "   npm run init-system" -ForegroundColor White
Write-Host ""
Write-Host "3. Run health check:" -ForegroundColor Yellow
Write-Host "   npm run health-check" -ForegroundColor White
Write-Host ""
Write-Host "4. Start the system:" -ForegroundColor Yellow
Write-Host "   npm run start" -ForegroundColor White
Write-Host ""
Write-Host "5. Run the demo:" -ForegroundColor Yellow
Write-Host "   npm run demo:apex-improvement" -ForegroundColor White
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Setup complete! Follow the steps above to get started." -ForegroundColor Green
