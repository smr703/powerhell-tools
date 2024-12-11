#Requires -Modules Az.Accounts, Az.Resources, Microsoft.PowerShell.ConsoleGuiTools

<#
.SYNOPSIS
    Sends a request to activate a role in Privileged Identity Management.

.DESCRIPTION
    Use this funtion instead of the portal when you want to elevate your Owner / Contributor role in the Privileged Identity Management.
    If your PIM is already active it will automatically extend the duration instead.

.NOTES
    Make sure that you are logged into the correct tenant (Set-AzContext) before running this script.

.EXAMPLE
    Activate-PIM
    Activate-PIM -Justification 'Testing' -Duration 3

    Parameters:
        -Justification = Message to explain your purpose ,
        -Duration = The duration of the PIM (must be in whole hours. ex: 3 for three hours),
#>

function Request-RoleAssignmentSchedule {
    [Alias('Activate-PIM', 'PIM', 'Start-PIM')]
    param(
        $Justification = 'General Maintenance',
        $Duration = 'PT8H'
    )

    $cyan = $([char]27) + '[38;5;51m'
    $nocolor = $([char]27) + '[0m'

    # Select RoleAssignmentSchedule
    Write-Output "$($cyan)Please wait while I pull myself together..$($nocolor)"
    if (!(Get-AzTenant)) {
        Write-Warning 'Looks like you are not logged in to any Azure Tenants.'
        Write-Output 'Please login with the webpage that just opend in your default browser'
        Connect-AzAccount
    }
    $context = Get-AzContext
    $aduser = Get-AzADUser -UserPrincipalName $context.Account.Id
    $RoleEligibilitySchedule = Get-AzRoleEligibilitySchedule -Scope '/' -Filter 'asTarget()'
    $selection = $RoleEligibilitySchedule |
        Select-Object ScopeDisplayName, RoleDefinitionDisplayName, ScopeType, EndDateTime |
        Out-ConsoleGridView -Title "Hei $($aduser.DisplayName)!" -OutputMode Single

    $Role = $RoleEligibilitySchedule | Where-Object {
        $_.ScopeDisplayName -eq $selection.ScopeDisplayName -and
        $_.RoleDefinitionDisplayName -eq $selection.RoleDefinitionDisplayName
    }

    # (Ideation-Machine Only) Limits $Duration based on context
    if ($Role.ScopeDisplayName -eq 'S294-Ideation Machine') {
        if ([int]($Duration -replace '\D') -gt 9) { $ExpirationDuration = 'PT9H' }
        else { $ExpirationDuration = "PT$($Duration -replace '\D')H" }
    }
    else {
        if ([int]($Duration -replace '\D') -gt 8) { $ExpirationDuration = 'PT8H' }
        else { $ExpirationDuration = "PT$($Duration -replace '\D')H" }
    }

    # Output confirmation message
    Write-Output "$($cyan)I hereby sentence you to $($Role.RoleDefinitionDisplayName) in $($Role.ScopeDisplayName) for the duration of $($ExpirationDuration -replace '\D') hours!$($nocolor)"

    # Check if RoleAssignmentSchedule is already active
    $param = @{
        Scope  = $Role.Scope
        Filter = "principalId eq $($aduser.Id) and roleDefinitionId eq '$($Role.RoleDefinitionId)'"
    }
    $RoleAssignmentSchedule = Get-AzRoleAssignmentSchedule @param
    if ($RoleAssignmentSchedule) {
        $RequestType = 'SelfExtend'
        Write-Warning 'AzRoleAssignmentSchedule is still active. This tenant does not support SelfExtend without AdminConsent. Conviction canceled..'
        break
    }
    else { $RequestType = 'SelfActivate' }
    Write-Output "$($cyan)Request type will be set to $($RequestType)$($nocolor)."

    # Send RoleAssignmentScheduleRequest
    $param = @{
        Name                      = New-Guid
        Scope                     = $Role.Scope
        PrincipalId               = $aduser.Id
        RequestType               = $RequestType
        Justification             = $Justification
        ScheduleInfoStartDateTime = Get-Date -Format o
        ExpirationType            = 'AfterDuration'
        ExpirationDuration        = $ExpirationDuration
        RoleDefinitionId          = $Role.RoleDefinitionId
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
