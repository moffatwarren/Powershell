# PowerShell setup

My PowerShell 7 setup for Windows Terminal:

- **oh-my-posh** for the prompt (Catppuccin theme)
- **Catppuccin Mocha** colors for Windows Terminal
- **Terminal-Icons** for file and folder icons in `ls`
- **zoxide** for smarter `cd` (`z <folder>`)
- A profile with helper functions (run `Show-Help` to list them)

## What's in this repo

| Path | What it is | Where it goes |
| --- | --- | --- |
| `Microsoft.PowerShell_profile.ps1` | The PowerShell profile, which runs every time a shell opens | `C:\Users\<you>\Documents\PowerShell\` |
| `.poshthemes\*.omp.json` | oh-my-posh **prompt** themes, which style only the prompt line | `C:\Users\<you>\.poshthemes\` |
| `windows-terminal\catppuccin-mocha.json` | Windows Terminal **color scheme** (background, text, and ANSI colors) | Added to Terminal's `settings.json` |
| `windows-terminal\install-theme.ps1` | Adds the color scheme and Nerd Font to Windows Terminal | Run it from the repo |
| `setup.ps1` | Does every step below automatically | Run it from the repo |

> The Catppuccin look has **two parts**: the oh-my-posh theme (the prompt) and the Windows Terminal color scheme (everything else). You need both.

## Prerequisites

- Windows 10/11 with **Windows Terminal** (preinstalled on Windows 11). Open it once so it creates its settings file.
- **PowerShell 7** (`pwsh`). It is *not* the built-in blue "Windows PowerShell 5.1". Install it with:
  ```powershell
  winget install Microsoft.PowerShell
  ```
- **Git**:
  ```powershell
  winget install Git.Git
  ```

## Quick install (automatic)

Open **PowerShell 7** in Windows Terminal and run:

```powershell
cd $HOME\Documents\GitHub
git clone https://github.com/moffatwarren/Powershell.git
cd Powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\setup.ps1
```

Then close and reopen Windows Terminal.

## Manual install

Run each step in **PowerShell 7**.

1. **Clone the repo**
   ```powershell
   cd $HOME\Documents\GitHub
   git clone https://github.com/moffatwarren/Powershell.git
   cd Powershell
   ```

2. **Allow local scripts to run.** Without this, the profile won't load.
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```

3. **Install the tools**
   ```powershell
   winget install JanDeDobbeleer.OhMyPosh --source winget
   winget install ajeetdsouza.zoxide
   Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser -Force
   ```
   Close and reopen the terminal so `oh-my-posh` and `zoxide` are on your PATH.

4. **Install a Nerd Font.** Without it, the prompt icons show as boxes.
   ```powershell
   oh-my-posh font install JetBrainsMono
   ```

5. **Copy the prompt themes**
   ```powershell
   New-Item -ItemType Directory -Force $HOME\.poshthemes
   Copy-Item .\.poshthemes\* $HOME\.poshthemes\
   ```

6. **Install the profile**
   ```powershell
   New-Item -ItemType Directory -Force (Split-Path $PROFILE)
   Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE
   ```

7. **Apply the Catppuccin colors to Windows Terminal**
   ```powershell
   .\windows-terminal\install-theme.ps1
   ```
   This adds the `Catppuccin Mocha` scheme, makes it the default for all profiles, sets the font to `JetBrainsMono Nerd Font Mono`, and saves a backup of `settings.json` next to the original.

   To do it by hand instead: in Windows Terminal open Settings → **Open JSON file**, paste the contents of `windows-terminal\catppuccin-mocha.json` into the `"schemes": [ ... ]` list, and set `"colorScheme": "Catppuccin Mocha"` under `profiles.defaults`.

8. **Restart Windows Terminal.**

9. **Teach zoxide your GitHub folder.** The `g` alias jumps to it, but zoxide only knows folders you've visited, so `cd` into it once:
   ```powershell
   cd $HOME\Documents\GitHub
   ```

## Changing the prompt theme

Edit line 1 of `$PROFILE` and swap `catppuccin` for any file name in `.poshthemes` (`aliens`, `markbull`, `night-owl`, `paradox`):

```powershell
oh-my-posh init pwsh --config "$HOME\.poshthemes\catppuccin.omp.json" | Invoke-Expression
```

More themes: https://ohmyposh.dev/docs/themes

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Plain prompt, no theme | Make sure you opened **PowerShell** (7), not **Windows PowerShell** (5.1). 5.1 reads a different profile (`Documents\WindowsPowerShell\`). Run `$PSVersionTable.PSVersion` to check. |
| Prompt is themed but the background/colors are still default | The Terminal color scheme isn't applied. Run `.\windows-terminal\install-theme.ps1` and restart Terminal. |
| Boxes or `?` instead of icons | Nerd Font missing or not selected. Run `oh-my-posh font install JetBrainsMono`, then set Terminal's font to `JetBrainsMono Nerd Font Mono`. |
| "running scripts is disabled on this system" | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| `oh-my-posh` / `zoxide` not recognized | Restart the terminal after installing them with winget. |
| `g` doesn't go anywhere | `cd` into your GitHub folder once so zoxide learns it. |
