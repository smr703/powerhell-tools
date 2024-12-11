#Requires -Modules Az.Accounts, Az.Resources, Microsoft.PowerShell.ConsoleGuiTools

<#
.SYNOPSIS
    Check if your PIM is still active

.DESCRIPTION
    Check if your PIM is still active

.NOTES
    Make sure that you are logged into the correct tenant (Set-AzContext) before running this script.

.EXAMPLE
    Get-IMRoleAssignmentSchedule
    Get-PIM
#>

function Get-IMRoleAssignmentSchedule {
    [CmdletBinding()]
    [Alias('Get-PIM')]

    $context = Get-AzContext
    $aduser = Get-AzADUser -UserPrincipalName $context.Account.Id

    # List available RoleEligibilitySchedule
    $RoleEligibilitySchedule = Get-AzRoleEligibilitySchedule -Scope '/' -Filter 'asTarget()'
    $selection = $RoleEligibilitySchedule |
        Select-Object ScopeDisplayName, RoleDefinitionDisplayName, ScopeType, EndDateTime |
        Out-ConsoleGridView -Title "Hei $($aduser.DisplayName)!" -OutputMode Single

    $Role = $RoleEligibilitySchedule | Where-Object {
        $_.ScopeDisplayName -eq $selection.ScopeDisplayName -and
        $_.RoleDefinitionDisplayName -eq $selection.RoleDefinitionDisplayName
    }

    # Get RoleAssignmentSchedule
    $param = @{
        Scope  = $Role.Scope
        Filter = "principalId eq $($aduser.Id) and roleDefinitionId eq '$($Role.RoleDefinitionId)'"
    }
    $RoleAssignmentSchedule = Get-AzRoleAssignmentSchedule @param
    $properties = @(
        'ScopeDisplayName'
        'RoleDefinitionDisplayName'
        'PrincipalEmail'
        'Status'
        'CreatedOn'
        'EndDateTime'
        'Justification'
        'RequestType'
        @{ N = 'RequestorId'; E = { $_.PrincipalId } }
        @{ N = 'RoleAssignmentScheduleName'; E = { $_.Name } }
    )
    return $RoleAssignmentSchedule | Select-Object $properties
}
