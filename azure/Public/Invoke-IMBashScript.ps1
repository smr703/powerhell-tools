#Requires -Modules Az.Compute, Common

<#
.SYNOPSIS
    Invokes a bash script on a virtual machine running Linux using AzVMRunCommand

.DESCRIPTION
    https://github.com/equinor/ideation-machine-infra/wiki/IM-Toolbox

.EXAMPLE
    Invoke-BashScriptOnVM
#>
function Invoke-IMBashScript {
    # Select VM
    Write-Host 'Select VM where the script will be invoked' -ForegroundColor yellow
    $vm = Select-Vm -OsTypes @('Linux')
    Write-Host $vm.Name

    # Select script file
    Write-Host 'Select script file: ' -ForegroundColor yellow
    $fileParams = @{
        title       = 'Select script file'
        multiSelect = $false
        filter      = 'Bash Scripts (*.sh)| *.sh'
    }
    $scriptPath = Open-File @fileParams
    $scriptName = $scriptPath.Split('\')[-1]
    Write-Host $scriptName

    $scriptParams = @{
        ResourceGroupName = $vm.ResourceGroupName
        Name              = $vm.Name
        CommandId         = 'RunShellScript'
        ScriptPath        = $scriptPath
    }
    Write-Host "Invoking $scriptName on $($vm.Name) ..." -ForegroundColor Blue -NoNewline
    Invoke-AzVMRunCommand @scriptParams
}
