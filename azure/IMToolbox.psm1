# IMPORT COMMON
Import-Module $PSScriptRoot\Public\Common.psm1

# IMPORT PUBLIC FUNCTIONS
$functions = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction Ignore )
Foreach ($import in $functions) {
    Try { . $import.fullname }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

<#
.SYNOPSIS
    Shows a list of all available commands

.DESCRIPTION
    https://github.com/equinor/ideation-machine-infra/wiki/IM-Toolbox

.EXAMPLE
    Get-IMCommands
#>

function Get-Commands {
    Get-Command -Module IMToolbox | Get-Help |
        Select-Object @{name = 'Command'; expr = { $_.Name } }, @{ name = 'Description'; expr = { $_.synopsis } }
}
