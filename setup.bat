@echo off
rem Double-click to set up PowerShell 7, oh-my-posh, zoxide, Terminal-Icons, the profile,
rem and the Windows Terminal theme. Installs PowerShell 7 first if it's missing, then runs setup.ps1.
rem Don't run as administrator: everything installs for the current user.
setlocal
title PowerShell setup
cd /d "%~dp0"

call :ensure_winget

rem Find PowerShell 7 (pwsh), not the built-in Windows PowerShell 5.1
rem Call it by name when it's on PATH: capturing the full path with for /f can garble
rem non-English characters in the username
set "PWSH="
where pwsh >nul 2>&1 && set "PWSH=pwsh"
if not defined PWSH if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"

if not defined PWSH (
  echo.
  echo ==^> PowerShell 7 not found. Installing it with winget...
  where winget >nul 2>&1 || goto :no_winget
  call winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements
  if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
)
if not defined PWSH (
  echo.
  echo PowerShell 7 still isn't installed. Install it with "winget install Microsoft.PowerShell" and run this again.
  goto :fail
)

echo.
echo Using "%PWSH%"
rem -NoProfile so an existing, possibly broken profile can't interfere.
rem Bypass only applies to this run; setup.ps1 sets the permanent policy.
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
if errorlevel 1 goto :fail

echo.
echo Setup finished. Close and reopen Windows Terminal.
pause
exit /b 0

:ensure_winget
where winget >nul 2>&1 && exit /b 0
rem On a fresh install winget (App Installer) can exist but not be registered yet
echo ==^> winget not found. Registering App Installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" >nul 2>&1
set "PATH=%PATH%;%LOCALAPPDATA%\Microsoft\WindowsApps"
exit /b 0

:no_winget
echo.
echo winget isn't available. Install "App Installer" from the Microsoft Store, then run this again.

:fail
echo.
echo Setup failed. See the messages above.
pause
exit /b 1
