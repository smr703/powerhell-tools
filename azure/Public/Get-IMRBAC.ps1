#Requires -Modules Az.Resources

<#
.SYNOPSIS
    Lists all Role Assignments in the subscription based on your chosen Scope and ObjectType.
    Default Scope is set to ResourceGroupLevel.
    Default ObjectType is set to User.

.DESCRIPTION
    https://github.com/equinor/ideation-machine-infra/wiki/IM-Toolbox

    Lists all Role Assignments in the subscription based on your chosen Scope and ObjectType.

    -Scope
        Sets the hierarchical level from where to collect Role Assignments. Defaults to ResourceGroupLevel.
            ResourceGroupLevel will get you everything from resource groups and below.
            SubscriptionLevel will get you everything from the subscription level and below.
            ResourceLevel will only get you Role Assignments from resources.

    -ObjectType
        Choose one or more object types to show. Defaults to User.
            User will get all user objects from the scope you defined.
            Group will get all Entra Id groups from the scope you defined.
            ServicePrincipal will get all ServicePrincipals from the scope you defined.
            Unknown will get all objects that for some reason has no visible ObjectType.


.EXAMPLE
    Get-IMRBAC -ObjectType Group
    Get-IMRBAC -ObjectType Group | Format-Table
    Get-IMRBAC -ObjectType User,ServicePrincipal -Scope ResourceLevel
#>

function Get-IMRBAC {
    [CmdletBinding()]
    [alias('Get-IMRBACsScopedToResourcesAndReResourceGroups')]
    param(
        [ValidateSet('SubscriptionLevel', 'ResourceGroupLevel', 'ResourceLevel')]$Scope = 'ResourceGroupLevel',
        [ValidateSet('User', 'Group', 'ServicePrincipal', 'Unknown')]$ObjectType = @('User')
    )

    switch ($Scope) {
        'SubscriptionLevel' { $s = '.' }
        'ResourceGroupLevel' { $s = 'resource' }
        'ResourceLevel' { $s = 'resourceGroups/.*/' }
    }

    $Selection = @(
        @{ N = 'ResourceName'; E = { $_.Scope -replace '.*/' } }
        @{ N = 'ResourceGroup'; E = { $_.Scope -replace '.*resourceGroups/' -replace '/.*' } }
        'SignInName'
        'DisplayName'
        'RoleDefinitionName'
        'ObjectType'
        'Description'
    )
    Get-AzRoleAssignment | Where-Object { $_.ObjectType -in $ObjectType -and $_.Scope -match $s } | Select-Object $Selection
}
