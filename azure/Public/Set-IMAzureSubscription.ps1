#Requires -Modules Az.Accounts

<#
.SYNOPSIS
    Helps with logging in to Azure account

.DESCRIPTION
    https://github.com/equinor/ideation-machine-infra/wiki/IM-Toolbox

.EXAMPLE
    EzAzLogin
    Set-AzureSubscription -Show
#>

function Set-IMAzureSubscription {
    [Alias('Set-AzureSubscription', 'EzAzLogin', 'Switch-AzureSubscription')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param([switch]$Show)
    if (!($Show)) {
        Write-Verbose '-Show parameter not defined'
        $i = 1
        $list = Get-AzContext -ListAvailable | ForEach-Object {
            [PSCustomObject]@{
                Index   = $i++
                Name    = $_.Subscription.Name
                Id      = $_.Subscription.Id
                Tenant  = $_.Tenant
                Account = $_.Account.Id
            }
        }
        $select = (Read-Host -Prompt (($list | Select-Object Index, Name, Id | Out-String) + 'Select'))
        $context = ($list | Where-Object { $_.Index -eq $select })

        try { Get-AzSubscription -SubscriptionId $context.Id -WarningAction Stop -ErrorAction Stop }
        catch {
            Write-Warning 'Looks like you need to authenticate with a web browser..'
            $catch = $true
        }

        if (((Get-AzContext).Account.Id -ne $context.Account) -or $catch) {
            Write-Verbose 'Opening Login page for PS Module on your web browser..' -Verbose
            Connect-AzAccount -SubscriptionId $context.Id -WarningAction SilentlyContinue | Out-Null
            Write-Verbose 'Opening Login page for Az Cli on your web browser..' -Verbose
            az login --only-show-errors | Out-Null #--output table
        }

        $ErrorActionPreference = 'Stop'
        while ($counter -lt 2 -and ((Get-AzContext).Subscription.Id -ne $context.Id -or (az account show --query 'id') -replace '"' -ne $context.Id)) {
            $counter++
            try {
                Set-AzContext -Subscription ($list | Where-Object { $_.Index -eq $select }).Id -WarningAction SilentlyContinue | Out-Null
                az account set --subscription ($list | Where-Object { $_.Index -eq $select }).Id
            }
            catch {
                Write-Warning 'Failed to set AzContext. Authenticate with a web browser..'
                Connect-AzAccount
                az login
            }
        }
        $ErrorActionPreference = 'Continue'
    }
    else { Write-Verbose '-Show parameter has been defined' }

    Write-Host -for Green "Logged in Ps Account: $((Get-AzContext).Subscription.Name)"
    Write-Host -for Green "Logged in Cli Account: $((az account show --query 'name') -replace '\"')"
}
