# Requires -Modules Az.Compute, Az.Network, Az.RecoveryServices, Az.Resources, Az.Storage, Microsoft.PowerShell.ConsoleGuiTools

# OPEN FILE DIALOG
function Open-File {
    [CmdletBinding()]
    param(
        $initialDirectory,
        $multiSelect = $false,
        $filter = 'All files (*.*)| *.*',
        $title = 'Select file(s)'
    )
    [System.Reflection.Assembly]::LoadWithPartialName('System.windows.forms') | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $openFileDialog.Title = $title
    $OpenFileDialog.Multiselect = $multiSelect
    $OpenFileDialog.filter = $filter
    $OpenFileDialog.ShowDialog() | Out-Null

    return $OpenFileDialog.Filenames
}

# SELECT VIRTUAL MACHINE DIALOG
function Select-Vm {
    param (
        [string]$VMName = '.',
        [string[]]$OsTypes = @('Linux', 'Windows')
    )
    if ($VMName -eq '*') { $VMName = '.' }

    $VMList = Get-AzVM -Status `
    | Where-Object { $OsTypes -contains $_.StorageProfile.OsDisk.OSType -and $_.Name -match $VMName }

    if ($VMList) {
        $vm = $VMList `
        | Select-Object Name, @{n = 'OS'; e = { $_.StorageProfile.OsDisk.OSType } }, PowerState, Location
        | Out-ConsoleGridView -Title 'Select a Virtal Machine' -OutputMode 1
    }
    else { Write-Error -Exception 'No good input!' -Message 'Hit & Miss..' ; exit 1 }

    if ($vm) {
        return $VMList | Where-Object { $_.Name -eq $vm.Name } `
        | Select-Object * , @{n = 'OS'; e = { $_.StorageProfile.OsDisk.OSType } }
    }
    else { return 'good bye..' }
}

# SELECT RESOURCE GROUP DIALOG
function Select-ResourceGroup {
    Write-Host 'Selecting resource group'
    return Get-AzResourceGroup `
    | Select-Object ResourceGroupName
    | Out-ConsoleGridView -Title 'Select Resource Group' -OutputMode 1
}

Export-ModuleMember -Function * -Alias * -Variable *
