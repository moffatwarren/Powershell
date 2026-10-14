# Adds the Catppuccin Mocha color scheme to Windows Terminal and makes it the default
# for every profile. Also sets the Nerd Font so oh-my-posh icons render, and makes
# PowerShell 7 the profile Terminal opens with.
# Safe to run more than once. A backup of settings.json is written next to it.

$schemeFile = Join-Path $PSScriptRoot "catppuccin-mocha.json"
$fontFace = "JetBrainsMono Nerd Font Mono"
# Terminal's generated "PowerShell" (7) profile always gets this GUID
$pwshProfileGuid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"

$candidates = @(
  "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
  "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
  "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$settingsPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$backup = $null

if (-not $settingsPath) {
  # Terminal writes settings.json the first time it opens. If it's installed but has never
  # been opened, start a minimal one; Terminal fills in the rest on first launch.
  $settingsPath = $candidates[0..1] | Where-Object { Test-Path (Split-Path $_) } | Select-Object -First 1
  if (-not $settingsPath) {
    Write-Warning "Windows Terminal isn't installed. Install it (winget install Microsoft.WindowsTerminal), open it once, then run windows-terminal\install-theme.ps1."
    return
  }
  '{ "profiles": { "defaults": {}, "list": [] }, "schemes": [] }' | Set-Content $settingsPath -Encoding utf8
  Write-Host "Created $settingsPath"
} else {
  $backup = "$settingsPath.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
  Copy-Item $settingsPath $backup
}

$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
$scheme = Get-Content $schemeFile -Raw | ConvertFrom-Json

# Replace any existing copy of the scheme, then add it
# Check the property itself: an empty "schemes": [] is falsy but still exists
if (-not $settings.PSObject.Properties["schemes"]) { $settings | Add-Member -NotePropertyName schemes -NotePropertyValue @() }
$settings.schemes = @($settings.schemes | Where-Object { $_.name -ne $scheme.name }) + $scheme

if (-not $settings.PSObject.Properties["profiles"]) {
  $settings | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{})
}
if (-not $settings.profiles.PSObject.Properties["defaults"]) {
  $settings.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{})
}
$defaults = $settings.profiles.defaults
$defaults | Add-Member -NotePropertyName colorScheme -NotePropertyValue $scheme.name -Force
if (-not $defaults.PSObject.Properties["font"]) { $defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{}) }
# Keep a Nerd Font that's already chosen (e.g. the non-Mono variant); otherwise set ours
if ($defaults.font.face -notlike "*Nerd Font*") {
  $defaults.font | Add-Member -NotePropertyName face -NotePropertyValue $fontFace -Force
}

# Individual profiles override the defaults, so clear any per-profile scheme
foreach ($p in $settings.profiles.list) {
  if ($p.PSObject.Properties["colorScheme"]) { $p.PSObject.Properties.Remove("colorScheme") }
}

# Open PowerShell 7 by default; a new PC defaults to Windows PowerShell 5.1, which doesn't load this profile
$pwshProfiles = @($settings.profiles.list | Where-Object { $_.source -eq "Windows.Terminal.PowershellCore" -and -not $_.hidden })
$defaultGuid = $pwshProfileGuid
if ($pwshProfiles -and -not ($pwshProfiles.guid -contains $pwshProfileGuid)) { $defaultGuid = $pwshProfiles[0].guid }
if ($settings.PSObject.Properties["defaultProfile"]) {
  $settings.defaultProfile = $defaultGuid
} else {
  $settings | Add-Member -NotePropertyName defaultProfile -NotePropertyValue $defaultGuid
}

$settings | ConvertTo-Json -Depth 20 | Set-Content $settingsPath -Encoding utf8

Write-Host "Catppuccin Mocha applied to Windows Terminal, default profile set to PowerShell 7." -ForegroundColor Green
if ($backup) { Write-Host "Backup saved to $backup" }
