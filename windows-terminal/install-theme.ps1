# Adds the Catppuccin Mocha color scheme to Windows Terminal and makes it the default
# for every profile. Also sets the Nerd Font so oh-my-posh icons render.
# Safe to run more than once. A backup of settings.json is written next to it.

$schemeFile = Join-Path $PSScriptRoot "catppuccin-mocha.json"
$fontFace = "JetBrainsMono Nerd Font Mono"

$settingsPath = @(
  "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
  "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
  "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $settingsPath) {
  Write-Error "Windows Terminal settings.json not found. Open Windows Terminal once, then run this again."
  return
}

$backup = "$settingsPath.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
Copy-Item $settingsPath $backup

$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
$scheme = Get-Content $schemeFile -Raw | ConvertFrom-Json

# Replace any existing copy of the scheme, then add it
if (-not $settings.schemes) { $settings | Add-Member -NotePropertyName schemes -NotePropertyValue @() }
$settings.schemes = @($settings.schemes | Where-Object { $_.name -ne $scheme.name }) + $scheme

if (-not $settings.profiles.defaults) {
  $settings.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{})
}
$defaults = $settings.profiles.defaults
$defaults | Add-Member -NotePropertyName colorScheme -NotePropertyValue $scheme.name -Force
if (-not $defaults.font) { $defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{}) }
$defaults.font | Add-Member -NotePropertyName face -NotePropertyValue $fontFace -Force

# Individual profiles override the defaults, so clear any per-profile scheme
foreach ($p in $settings.profiles.list) {
  if ($p.PSObject.Properties["colorScheme"]) { $p.PSObject.Properties.Remove("colorScheme") }
}

$settings | ConvertTo-Json -Depth 20 | Set-Content $settingsPath -Encoding utf8

Write-Host "Catppuccin Mocha applied to Windows Terminal." -ForegroundColor Green
Write-Host "Backup saved to $backup"
