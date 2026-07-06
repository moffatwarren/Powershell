.poshthemes -> goes in C:\Users\USERNAME\
Microsoft.PowerShell_profile.ps1 -> goes in C:\Users\USERNAME\Documents\PowerShell

edit Microsoft.PowerShell_profile.ps1 line:
oh-my-posh init pwsh --config "C:\Users\moffa\.poshthemes\catppuccin.omp.json" | Invoke-Expression
-> change "catppuccin" to whatever theme you want in .poshthemes