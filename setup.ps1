# One-shot setup for a fresh Windows install. Run setup.bat, or from the repo folder in PowerShell 7:
#   .\setup.ps1
# Safe to re-run: installs are skipped if already present, and existing files are backed up.

$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

if ($PSVersionTable.PSVersion.Major -lt 7) {
  throw "Run this in PowerShell 7 (pwsh), not Windows PowerShell $($PSVersionTable.PSVersion). Or double-click setup.bat."
}

# winget updates PATH for new shells only; pick up the new entries here too
function Update-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

function Install-WingetPackage($id, $command) {
  if (Get-Command $command -ErrorAction SilentlyContinue) {
    Write-Host "$command is already installed"
    return
  }
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget isn't available, so $command can't be installed. Install 'App Installer' from the Microsoft Store and run this again."
  }
  winget install --id $id --source winget --accept-package-agreements --accept-source-agreements
  Update-Path
  if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "$command still isn't on PATH after installing $id. Restart the terminal and run this again."
  }
}

Step "Allowing local scripts to run (execution policy RemoteSigned for the current user)"
try {
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
} catch {
  # Expected when this run uses -ExecutionPolicy Bypass: the policy is saved but this session overrides it
  if (-not ($_.FullyQualifiedErrorId -like "ExecutionPolicyOverride*")) { Write-Warning $_ }
}
Write-Host "CurrentUser policy: $(Get-ExecutionPolicy -Scope CurrentUser)"

Step "Installing oh-my-posh and zoxide (winget)"
Install-WingetPackage JanDeDobbeleer.OhMyPosh oh-my-posh
Install-WingetPackage ajeetdsouza.zoxide zoxide

Step "Installing Terminal-Icons module"
if (Get-Module -ListAvailable -Name Terminal-Icons) {
  Write-Host "Terminal-Icons is already installed"
} else {
  Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser -Force
}

Step "Installing JetBrainsMono Nerd Font"
$fontDirs = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts", "$env:WINDIR\Fonts"
if (Get-ChildItem $fontDirs -Filter "JetBrainsMonoNerdFont*" -ErrorAction SilentlyContinue) {
  Write-Host "JetBrainsMono Nerd Font is already installed"
} else {
  oh-my-posh font install JetBrainsMono --headless
}

Step "Copying oh-my-posh themes to $HOME\.poshthemes"
New-Item -ItemType Directory -Force "$HOME\.poshthemes" | Out-Null
Copy-Item "$repo\.poshthemes\*" "$HOME\.poshthemes\" -Force
# Files from a downloaded zip are marked as from the internet, which RemoteSigned blocks
Get-ChildItem "$HOME\.poshthemes" | Unblock-File

Step "Installing PowerShell profile to $PROFILE"
$source = "$repo\Microsoft.PowerShell_profile.ps1"
New-Item -ItemType Directory -Force (Split-Path $PROFILE) | Out-Null
if ((Test-Path $PROFILE) -and (Get-FileHash $PROFILE).Hash -eq (Get-FileHash $source).Hash) {
  Write-Host "Profile is already up to date"
} else {
  if (Test-Path $PROFILE) {
    $backup = "$PROFILE.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
    Copy-Item $PROFILE $backup
    Write-Host "Existing profile backed up to $backup"
  }
  Copy-Item $source $PROFILE -Force
}
Unblock-File $PROFILE

Step "Applying Catppuccin Mocha to Windows Terminal"
& "$repo\windows-terminal\install-theme.ps1"

Step "Checking the profile loads"
# Load it in a fresh shell on this console, with the saved execution policy, and collect any
# errors it raised. PSReadLine needs a real console, so skip this when output is redirected.
if ([Console]::IsOutputRedirected) {
  Write-Host "Skipped: no interactive console"
} else {
  $errorLog = New-TemporaryFile
  # Double any apostrophes (e.g. a username like O'Brien) so the quoted path stays intact
  $quotedLog = $errorLog.FullName.Replace("'", "''")
  $command = "`$Error | ForEach-Object { `$_.ToString() } | Set-Content -LiteralPath '$quotedLog'"
  $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
  # setup.bat's -ExecutionPolicy Bypass is passed to child shells through this variable; drop it
  # so the check uses the saved policy, like a new terminal would
  $savedPolicy = $env:PSExecutionPolicyPreference
  $env:PSExecutionPolicyPreference = $null
  try {
    Start-Process (Get-Process -Id $PID).Path -ArgumentList "-NoLogo", "-EncodedCommand", $encoded -NoNewWindow -Wait
  } finally {
    $env:PSExecutionPolicyPreference = $savedPolicy
  }
  $profileErrors = Get-Content -LiteralPath $errorLog
  Remove-Item -LiteralPath $errorLog
  if ($profileErrors) {
    Write-Warning "The profile reported errors when loading:"
    $profileErrors | ForEach-Object { Write-Host "  $_" }
  } else {
    Write-Host "Profile loaded without errors" -ForegroundColor Green
  }
}

Write-Host "`nDone. Close and reopen Windows Terminal." -ForegroundColor Green
