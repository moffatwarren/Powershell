# One-shot setup for a fresh Windows install. Run from the repo folder in PowerShell 7:
#   .\setup.ps1
# Safe to re-run: installs are skipped if already present, and existing files are backed up.

$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

Step "Installing oh-my-posh and zoxide (winget)"
winget install --id JanDeDobbeleer.OhMyPosh --source winget --accept-package-agreements --accept-source-agreements
winget install --id ajeetdsouza.zoxide --source winget --accept-package-agreements --accept-source-agreements

# winget updates PATH for new shells only; pick up the new entries here too
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

Step "Installing Terminal-Icons module"
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
  Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser -Force
}

Step "Installing JetBrainsMono Nerd Font"
oh-my-posh font install JetBrainsMono

Step "Copying oh-my-posh themes to $HOME\.poshthemes"
New-Item -ItemType Directory -Force "$HOME\.poshthemes" | Out-Null
Copy-Item "$repo\.poshthemes\*" "$HOME\.poshthemes\" -Force

Step "Installing PowerShell profile to $PROFILE"
New-Item -ItemType Directory -Force (Split-Path $PROFILE) | Out-Null
if (Test-Path $PROFILE) {
  Copy-Item $PROFILE "$PROFILE.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
}
Copy-Item "$repo\Microsoft.PowerShell_profile.ps1" $PROFILE -Force

Step "Applying Catppuccin Mocha to Windows Terminal"
& "$repo\windows-terminal\install-theme.ps1"

Write-Host "`nDone. Close and reopen Windows Terminal." -ForegroundColor Green
