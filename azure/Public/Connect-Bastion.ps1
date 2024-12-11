#Requires -Modules Az.Compute, Common

<#
.SYNOPSIS
    Connects to a virtual machine using bastion (Window=RDP, Linux=SSH)

.DESCRIPTION
   Tool to connect to VM using Bastion.

.EXAMPLE
    Connect-Bastion
    Connect-Bastion -VMName <some_name>
    Connect-Bastion -VMName <some_name> -Bastion 'bas-github-runner'
#>

function Connect-Bastion {
    param([string]$VMName <#= '*'#>, $Bastion)

    $ErrorActionPreference = 'Stop'

    # Using $VMName as a search string. if result is more than 1 open ConsoleGridview
    $vm = Get-AzVM -Name *$VMName*
    if ($vm.count -ne 1) {
        try { $vm = Select-Vm -VMName $VMName }
        catch { Write-Error $_ }
    }
    else { $vm | Add-Member -MemberType NoteProperty -Name 'OS' -Value $vm.StorageProfile.OsDisk.OSType }

    # Exits if $vm is null
    if ($null -eq $vm -or $vm -eq 'good bye..') { Write-Host 'RETREAT!!' -for Yellow ; break }
    else { Write-Host "Connecting to $($vm.name)" -ForegroundColor Blue }

    # Use the Bastion defined in parameter or tries to find the correct Bastion for you
    if ($Bastion) { $Bastion = (Get-AzBastion | Where-Object { $_.Name -eq $Bastion }) }
    else {
        $Bastion = (Get-AzBastion | Where-Object {
                $_.Location -eq $vm.Location -and
                $_.Name -ne 'bas-github-runner'
            })
    }
    Write-Output "Connecting to Bastion in $($Bastion.Location) for your convenience :)"

    # Connecting to Vm
    if ($vm.OS -eq 'Linux') {
        az network bastion ssh --name $Bastion.Name `
            --resource-group $Bastion.ResourceGroupName `
            --target-resource-id $($vm.Id) `
            --auth-type 'AAD'
    }
    elseif ($vm.OS -eq 'Windows') {
        az network bastion rdp --name $Bastion.Name `
            --resource-group $Bastion.ResourceGroupName `
            --target-resource-id $($vm.Id)
    }
}
