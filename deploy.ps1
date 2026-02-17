<#
.SYNOPSIS
  Build chat-history.html, commit, push to GitHub, and deploy to Azure SWA.
.DESCRIPTION
  1. Runs build-chat-html.ps1 to generate chat-history.html from the chat history text file
  2. Commits all changes and pushes to GitHub
  3. Deploys web files to Azure Static Web App
#>
param(
  [string]$CommitMessage = "docs: update chat history"
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $root) { $root = Get-Location }
Set-Location $root

$deployToken = "b650006f8bac777431fbd361c7b94ca53c356cde3b33dc829a77208a738d168f04-4197987b-215c-4ee1-a1d4-5ce7a56b31b701e10060a3c6351e"

# Workaround for SWA CLI "Could not load StaticSitesClient metadata" error
$env:SWA_CLI_DEPLOY_BINARY_VERSION = "stable"

# Step 1: Build chat-history.html
Write-Host "`n📄 Building chat-history.html..." -ForegroundColor Cyan
& "$root\build-chat-html.ps1"

# Step 2: Git commit and push
Write-Host "`n📦 Committing and pushing to GitHub..." -ForegroundColor Cyan
git add -A
$status = git status --porcelain
if ($status) {
  git commit -m $CommitMessage
  git push
  Write-Host "✅ Pushed to GitHub" -ForegroundColor Green
} else {
  Write-Host "ℹ️  No changes to commit" -ForegroundColor Yellow
}

# Step 3: Deploy to Azure SWA
Write-Host "`n🚀 Deploying to Azure Static Web App..." -ForegroundColor Cyan
$deployDir = Join-Path $root "deploy_out"
New-Item -ItemType Directory -Path $deployDir -Force | Out-Null

# Copy all web files
$webFiles = @("index.html", "app.js", "style.css", "chat-history.html", "initial-prompt.html", "yolo2-initial-prompt.txt", "yolo2-copilot-chat-history.txt")
foreach ($f in $webFiles) {
  $src = Join-Path $root $f
  if (Test-Path $src) {
    Copy-Item $src $deployDir
  }
}

npx @azure/static-web-apps-cli deploy $deployDir --deployment-token $deployToken --env production

# Cleanup
Remove-Item $deployDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "`n✅ Deploy complete!" -ForegroundColor Green
Write-Host "🌐 https://red-ground-0a3c6351e.4.azurestaticapps.net" -ForegroundColor Cyan
