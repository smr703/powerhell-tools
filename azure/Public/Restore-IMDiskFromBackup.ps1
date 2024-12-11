#Requires -Modules Az.Network, Az.RecoveryServices, Common

<#
.SYNOPSIS
    Restores a Virtual Machine from a Recovery Vault by creating a new VM

.DESCRIPTION
    https://github.com/equinor/ideation-machine-infra/wiki/IM-Toolbox

.EXAMPLE
    Restore-IMDiskFromBackup
#>

function Restore-IMDiskFromBackup {

    # SELECT RECOVERY VAULT DIALOG
    function Select-RecoveryVault {
        Write-Host 'Selecting recovery vault'
        return Get-AzRecoveryServicesVault `
        | Select-Object Name, ResourceGroupName, Id, Location
        | Out-ConsoleGridView -Title 'Select Recovery Vault' -OutputMode 1
    }

    # SELECT BACKUP CONTAINER DIALOG
    function Select-BackupContainer {
        param (
            [Parameter(Mandatory = $true)][string]$RecoveryVaultId
        )
        Write-Host 'Selecting backup container'
        return Get-AzRecoveryServicesBackupContainer -ContainerType 'AzureVM' -VaultId $recoveryVaultId `
        | Out-ConsoleGridView -Title 'Select which VM to restore' -OutputMode 1
    }

    # SELECT RECOVERY POINT DIALOG
    function Select-RecoveryPoint {
        param (
            [Parameter(Mandatory = $true)][string]$RecoveryVaultId,
            [Parameter(Mandatory = $true)][PSCustomObject]$BackupItem
        )
        Write-Host 'Selecting recovery point'
        $startDate = (Get-Date).AddDays(-14)
        $endDate = Get-Date
        return Get-AzRecoveryServicesBackupRecoveryPoint -Item $BackupItem -StartDate $startdate.ToUniversalTime() -EndDate $enddate.ToUniversalTime() -VaultId $recoveryVaultId `
        | Out-ConsoleGridView -Title 'Select Recovery Vault' -OutputMode 1
    }

    # SELECT STORAGE ACCOUNT DIALOG
    function Select-StorageAccount {
        Write-Host 'Selecting storage account'
        return Get-AzStorageAccount `
        | Select-Object StorageAccountName, ResourceGroupName
        | Out-ConsoleGridView -Title 'Select Storage Account' -OutputMode 1
    }

    # SELECT VIRTUAL NETWORK DIALOG
    function Select-VirtualNetwork {
        param (
            [Parameter(Mandatory = $true)][string]$ResourceGroupName
        )
        Write-Host 'Selecting virtual network'
        return Get-AzVirtualNetwork `
        | Select-Object Name, ResourceGroupName, Subnets, Id
        | Where-Object { $ResourceGroupName -contains $_.ResourceGroupName }
        | Out-ConsoleGridView -Title 'Select Virtual Network' -OutputMode 1
    }

    # SELECT SUBNET DIALOG
    function Select-Subnet {
        param (
            [Parameter(Mandatory = $true)][PSCustomObject]$VirtualNetwork
        )
        Write-Host 'Selecting subnet'
        return Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VirtualNetwork `
        | Select-Object Name, ResourceGroupName, Id
        | Out-ConsoleGridView -Title 'Select Subnet' -OutputMode 1
    }

    try {

        # Collecting variables
        $recoveryVault = Select-RecoveryVault
        $backupContainer = Select-BackupContainer `
            -RecoveryVaultId $recoveryVault.ID
        $backupItem = Get-AzRecoveryServicesBackupItem `
            -Container $backupContainer  `
            -WorkloadType 'AzureVM' `
            -VaultId $recoveryVault.ID
        $recoveryPoint = Select-RecoveryPoint `
            -RecoveryVaultId $recoveryVault.ID `
            -BackupItem $backupItem
        $storageAccount = Select-StorageAccount
        $targetVMName = Read-Host 'Enter name for new Virtual Machine'
        $targetResourceGroup = Select-ResourceGroup
        $targetVnet = Select-VirtualNetwork `
            -ResourceGroupName $targetResourceGroup.ResourceGroupName
        $vnetObject = Get-AzVirtualNetwork -ResourceName $($targetVnet.Name)
        $subnetName = (Select-Subnet -VirtualNetwork $vnetObject).Name

        # Restorejob
        $restorejob = Restore-AzRecoveryServicesBackupItem `
            -RecoveryPoint $recoveryPoint `
            -TargetResourceGroupName $targetResourceGroup.ResourceGroupName `
            -StorageAccountName $storageAccount.StorageAccountName `
            -StorageAccountResourceGroupName $storageAccount.ResourceGroupName `
            -TargetVMName $targetVMName `
            -TargetVNetName $targetVnet.Name `
            -TargetVNetResourceGroup $targetVnet.ResourceGroupName `
            -TargetSubnetName $subnetName `
            -VaultId $recoveryVault.ID `
            -VaultLocation $recoveryVault.Location

        'Waiting for restore job to finish. This might take some time'
        Wait-AzRecoveryServicesBackupJob `
            -Job $restorejob `
            -Timeout 43200 `
            -VaultId $recoveryVault.ID
        Get-AzRecoveryServicesBackupJobDetail `
            -Job $restorejob `
            -VaultId $recoveryVault.ID
    }
    catch {
        Write-Error $_.ErrorDetails.Message -ErrorAction Stop
    }
}
