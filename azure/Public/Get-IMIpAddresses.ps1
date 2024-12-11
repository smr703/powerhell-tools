#Requires -Modules Az.Accounts, Az.Network

<#
.SYNOPSIS
    Gets all IP Addresses on a subscription. defaults to S294 Ideation Machine

.DESCRIPTION
    https://github.com/equinor/ideation-machine-infra/wiki/IM-Toolbox

.EXAMPLE
    Get-IMIpAddresses

.EXAMPLE
    Get-IMIpAddresses -TenantId "3aa4a235-b6e2-48d5-9195-7fcf05b459b0" -$SubscriptionId "115a0693-7b56-4f35-8b25-7898d4b60cef"
#>

function Get-IMIpAddresses {
    param(
        $TenantId = '3aa4a235-b6e2-48d5-9195-7fcf05b459b0',
        $SubscriptionId = '115a0693-7b56-4f35-8b25-7898d4b60cef'
    )
    $subscription = Get-AzSubscription -SubscriptionId $SubscriptionId -TenantId $TenantId
    Write-Host "Fetching ip address for the $($subscription.name) subscription ..." -ForegroundColor Blue
    $ips = Get-AzPublicIpAddress | ForEach-Object {
        return [PSCustomObject]@{
            Name          = $_.Name
            Type          = 'Public'
            IpAddress     = $_.IpAddress
            ResourceGroup = $_.ResourceGroupName
        }
    }
    $ips += Get-AzNetworkInterface | ForEach-Object {
        return [PSCustomObject]@{
            Name          = $_.Name
            Type          = 'Private'
            IpAddress     = $_.IpConfigurations.PrivateIpAddress
            ResourceGroup = $_.ResourceGroupName
        }
    }
    $ips
}
