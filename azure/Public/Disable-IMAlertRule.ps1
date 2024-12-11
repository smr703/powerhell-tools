#Requires -Modules Az.Monitor, Microsoft.PowerShell.ConsoleGuiTools

<#
.SYNOPSIS
    Disable enabled alert rules

.DESCRIPTION
    Disable alert rules. input a search string as argument and all matches will be listed on the screen.
    Select the ones you like to disable.

.EXAMPLE
    Disable-IMAlertRule -SearchString dev
#>

function Disable-IMAlertRule {
    [CmdletBinding()]
    param(
        $SearchString
    )

    # Select alert rules to be changed
    $alerts = Get-AzScheduledQueryRule
    $selected = $alerts | Select-Object Name, Location, @{N = 'Enabled'; E = { $_.Enabled } }, Description |
        Out-ConsoleGridView -Title 'Select Alerts to Disable' -Filter $SearchString -OutputMode Multiple
    $alerts = $alerts | Where-Object { $_.Name -in $selected.Name }

    # Process selected rules
    foreach ($a in $alerts) {
        $ErrorActionPreference = 'Stop'
        if ($a.Enabled -eq $true) {
            try {
                $a | Update-AzScheduledQueryRule -Enabled:$false | Out-Null
                Write-Verbose "Alert rule `"$($a.Name)`" has been disabled" -Verbose
            }
            catch { $_ }
        }
        else {
            Write-Verbose "Alert rule `"$($a.Name)`" is already disabled" -Verbose
        }
        $ErrorActionPreference = 'Continue'
    }
}
