---- run these commands
git clone https://github.com/moffatwarren/Powershell.git
winget install JanDeDobbeleer.OhMyPosh --source winget
winget install ajeetdsouza.zoxide
Install-Module -Name Terminal-Icons -Repository PSGallery -Force

you have to cd directly into the GitHub folder once for zoxide to remember it to use the g alias

---- move stuff here
.poshthemes -> goes in C:\Users\USERNAME\
Microsoft.PowerShell_profile.ps1 -> goes in C:\Users\USERNAME\Documents\PowerShell

edit Microsoft.PowerShell_profile.ps1 line:
oh-my-posh init pwsh --config "C:\Users\moffa\.poshthemes\catppuccin.omp.json" | Invoke-Expression
-> change "catppuccin" to whatever theme you want in .poshthemes