#Requires -Modules Az.Accounts, Az.Resources, Microsoft.PowerShell.ConsoleGuiTools

<#
.SYNOPSIS
    Sends a request to deactivate a role in Privileged Identity Management.

.DESCRIPTION
    Use this funtion instead of the portal when you want to deactivate your Owner / Contributor role in the Privileged Identity Management.

.NOTES
    Make sure that you are logged into the correct tenant (Set-AzContext) before running this script.

.EXAMPLE
    Revoke-IMRoleAssignmentSchedule
    Deactivate-PIM
#>

function Revoke-IMRoleAssignmentSchedule {
    [Alias('Deactivate-PIM', 'Stop-PIM')]

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

    # Deactivate RoleAssignmentSchedule
    $param = @{
        Name                      = New-Guid
        Scope                     = $Role.Scope
        ExpirationType            = 'AfterDuration'
        PrincipalId               = $aduser.Id
        RequestType               = 'SelfDeactivate'
        RoleDefinitionId          = $Role.RoleDefinitionId
        ScheduleInfoStartDateTime = Get-Date -Format o
    }
    $response = New-AzRoleAssignmentScheduleRequest @param
    $properties = @(
        'ScopeDisplayName'
        'RoleDefinitionDisplayName'
        'PrincipalEmail'
        'Status'
        'CreatedOn'
        'ExpirationDuration'
        'Justification'
        'RequestType'
        'RequestorId'
        @{N = 'RoleAssignmentScheduleName'; E = { $_.Name } }
    )
    return $response | Select-Object $properties
}
