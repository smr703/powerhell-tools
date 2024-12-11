#Requires -Modules Az.Accounts, Az.Network

<#
.SYNOPSIS
    Gets all subnets on a subscription. defaults to S294 Ideation Machine

.DESCRIPTION
    https://github.com/equinor/ideation-machine-infra/wiki/IM-Toolbox

.EXAMPLE
    Get-IMSubnets

.EXAMPLE
    Get-IMSubnets -TenantId "3aa4a235-b6e2-48d5-9195-7fcf05b459b0" -$SubscriptionId "115a0693-7b56-4f35-8b25-7898d4b60cef"
#>

function Get-IMSubnets {
    param(
        $TenantId = '3aa4a235-b6e2-48d5-9195-7fcf05b459b0',
        $SubscriptionId = '115a0693-7b56-4f35-8b25-7898d4b60cef'
    )
    $subscription = Get-AzSubscription -SubscriptionId $SubscriptionId -TenantId $TenantId
    Write-Host "Fetching subnets for the $($subscription.name) subscription ..." -ForegroundColor Blue

    $vnets = Get-AzVirtualNetwork
    $result = @()
    foreach ($v in $vnets) {
        $v.Subnets | ForEach-Object {
            $result += [PSCustomObject]@{
                SnetName         = $_.Name
                Prefix           = $_.AddressPrefix[0]
                VnetName         = $v.Name
                VnetAddressSpace = ($v.AddressSpaceText | ConvertFrom-Json).AddressPrefixes | Out-String
                ResourceGroup    = $_.Id.Split('/')[-1]
                Location         = $v.Location
            }
        }
    }
    $result | Sort-Object VnetName, SnetName
}
