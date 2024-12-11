#Requires -Modules Az.Compute, Common

<#
.SYNOPSIS
    Copies selected disks and prompts you for diskname

.DESCRIPTION
    https://github.com/equinor/ideation-machine-infra/wiki/IM-Toolbox

.EXAMPLE
    Copy-IMDisks
#>

function Copy-IMDisks {

    # Function: SELECT DISK(S) DIALOG
    function Select-Disk {
        param (
            [Parameter(Mandatory = $true)][string]$ResourceGroupName
        )
        Write-Host 'Selecting disk(s)'
        $selection = Get-AzDisk | Where-Object { $ResourceGroupName -contains $_.ResourceGroupName } |
            Select-Object Name, ResourceGroupName, DiskSizeGB, DiskState |
            Out-ConsoleGridView -Title 'Select Disk(s)'

        return Get-AzDisk | Where-Object { $_.Name -in $Selection.Name }
    }

    $sourceResourceGroup = Select-ResourceGroup
    $sourceDisks = Select-Disk -ResourceGroupName $sourceResourceGroup.ResourceGroupName

    try {
        foreach ($disk in $sourceDisks) {
            $diskConfig = New-AzDiskConfig `
                -SkuName $disk.Sku.Name `
                -Location $disk.Location `
                -DiskSizeGB $disk.diskSizeGB `
                -SourceResourceId $disk.id `
                -CreateOption 'Copy'
            $newDiskName = Read-Host "Enter new disk name for $($disk.Name).`r`nNote: Use '-os' extension for osdisks and '-data' extension for datadisk"
            Write-Verbose "Creating the new Data Disk: $newDiskName"
            New-AzDisk `
                -Disk $diskConfig `
                -DiskName $newDiskName `
                -ResourceGroupName $disk.resourceGroupName
        }
    }
    catch {
        Write-Error $_.ErrorDetails.Message -ErrorAction Stop
    }
}
