<#
.SYNOPSIS
    Merges all IMToolbox functions to a .psm1 file and place it into a module folder of your choise.

.DESCRIPTION
    For First Time Install Only
    Merges all IMToolbox functions to a .psm1 file and place it into a module folder of your choise.
    just run this script and follow the prompts.

.NOTES
    Should work...

.EXAMPLE
    . src/IMToolbox/FirstTimeInstall.ps1
#>

[CmdletBinding()]
param(
    $Folder = 'IMToolbox',
    $Name = 'IMToolbox.psm1'
)

# Color Codes
$orange = $([char]27) + '[38;5;214m'
$yellow = $([char]27) + '[38;5;11m'
$green = $([char]27) + '[38;5;46m'
$cyan = $([char]27) + '[38;5;51m'
$blue = $([char]27) + '[38;5;75m'
$white = $([char]27) + '[0m'

# Checks that required modules are installed
$installedModules = Get-InstalledModule
if ($installedModules.Name -notcontains 'Az') {
    Write-Output "$($orange)Required PSModule Az is not installed. Starting installation.$($white)"
    try {
        Install-Module -Name Az -Force -Verbose -ErrorAction Stop
        Write-Output "$($green)Az has been successfully installed.$($white)"
    }
    catch { Write-Error $_ ; exit 1 }
}

$requirements = @(
    'Az.Accounts'
    'Az.Compute'
    'Az.ContainerRegistry'
    'Az.KeyVault'
    'Az.MachineLearningServices'
    'Az.Monitor'
    'Az.Network'
    'Az.RecoveryServices'
    'Az.Resources'
    'Az.Storage'
    'Microsoft.PowerShell.ConsoleGuiTools'
)
$installList = $requirements | ForEach-Object {
    if ($_ -notin $installedModules.Name) { $_ }
}
if ($installList) {
    $installList | ForEach-Object {
        Write-Output "$($orange)Required module $($_) is not installed. Starting installation..$($white)"
        try {
            Install-Module -Name $_ -Force -Verbose -ErrorAction Stop
            Write-Output "$($green)$($_) has been successfully installed.$($white)"
        }
        catch { Write-Error $_ ; exit 1 }
    }
}

# Check if IMToolbox is already installed
Write-Output "$($cyan)Checking if IMToolbox is already installed..$($white)"
$ModulePath = $env:PSModulePath.Split(';') | Where-Object {
    Test-Path -Path "$($_)/$($Folder)/$($Name)"
}
if (!($ModulePath)) {
    $ModulePath = $env:PSModulePath.Split(';') |
        Where-Object { $_ -notmatch 'program\sfiles|windows' } |
        Out-ConsoleGridView -Title 'Select a Module folder for IM Toolbox to be installed' -OutputMode Single

    # Test if folder exist
    if (!(Test-Path -Path "$($ModulePath)/$($Folder)")) {
        New-Item -Path $ModulePath -Name $Folder -ItemType Directory | Out-Null
    }
}

# Remove and replace old IMToolbox.psm1 file
if (Test-Path -Path "$($ModulePath)/$($Folder)/$($Name)") {
    $old = (Get-Item -Path "$($ModulePath)/$($Folder)/$($Name)")
    Write-Output "$($orange)Removing old version of IMToolbox..$($white)"
    Remove-Item -Path "$($ModulePath)/$($Folder)/$($Name)"
}

# Rebuild new IMToolbox module file
Write-Output 'Rebuilding new IMToolbox file..'

@'
# Requires -Modules Az.Accounts, Az.Compute, Az.ContainerRegistry, Az.KeyVault, Az.MachineLearningServices, Az.Monitor, Az.Network, Az.RecoveryServices, Az.Resources, Az.Storage, Common, Microsoft.PowerShell.ConsoleGuiTools

<#
.SYNOPSIS
    Lists all IMToolbox cmdlets
#>

function Get-IMCommands {
    Get-Command -Module IMToolbox | Where-Object { $_.CommandType -eq 'Function' } | ForEach-Object {
        [PSCustomObject]@{
            CommandName = $_.Name
            Description = (Get-Help -Name $_.Name).Synopsis
        }
    }
}
'@ | Out-File -FilePath "$($ModulePath)/$($Folder)/$($Name)"

# Merge all function scripts
$currentDir = $PSScriptRoot

$path = ($currentDir -replace '(ideation-machine-infra)(.*)', '$1') + '/'
$items = Get-ChildItem "$($path)/Public" -Filter '*.ps1'
foreach ($i in $items) {
    Write-Output "Merging $($i.Name) into new module.."
    $content = Get-Content $i.FullName
    $content | Where-Object {
        (-not($_ -like '#Requires *' -and $_.Length -lt 200))
    } | Out-File -FilePath "$($ModulePath)/$($Folder)/$($Name)" -Append
}

# Copy any existing .psm1 files from source
$modules = Get-ChildItem "$($path)/Public" -Filter '*.psm1'
$modObj = @()
foreach ($m in $modules) {
    Write-Output "$($cyan)Checking module $($m.BaseName)..$($white)"

    # Test if folder exist
    if (!(Test-Path -Path "$($ModulePath)/$($m.BaseName)")) {
        New-Item -Path $ModulePath -Name $m.BaseName -ItemType Directory | Out-Null
    }

    # Remove and replace old file
    if (Test-Path -Path "$($ModulePath)/$($m.BaseName)/$($m.Name)") {
        $modObj += (Get-Item -Path "$($ModulePath)/$($m.BaseName)/$($m.Name)")
        Write-Output "$($orange)Removing old version of $($m.Name)..$($white)"
        Remove-Item -Path "$($ModulePath)/$($m.BaseName)/$($m.Name)"
    }

    Write-Output "Copying module $($m.Name) to $($ModulePath)/$($m.BaseName)"
    Copy-Item -Path $m.FullName -Destination "$($ModulePath)/$($m.BaseName)" -Force -Confirm:$false
}

# Test LastWriteTime of IMToolbox
$new = (Get-Item -Path "$($ModulePath)/$($Folder)/$($Name)")
if (!($old)) { $old = [PSCustomObject]@{CreationTime = 'non-existing' } }
Write-Output "$($blue)CreationTime on $($new.Name) has changed from $($old.CreationTime) to $($new.CreationTime)$($white)"

# Test LastWriteTime of extra modules
foreach ($m in $modules) {
    $n = (Get-Item -Path "$($ModulePath)/$($m.BaseName)/$($m.Name)")
    $o = $modObj | Where-Object { $_.Name -eq $n.Name }
    if (!($o)) { $o = [PSCustomObject]@{CreationTime = 'non-existing' } }
    Write-Output "$($blue)CreationTime on $($m.Name) has changed from $($o.CreationTime) to $($n.CreationTime)$($white)"
}

# Finnished
try { Import-Module -Name IMToolbox -ErrorAction Stop }
catch { Write-Error $_ ; exit 1 }
Write-Output "$($green)IMToolbox has been successfully installed. Type `"Get-IMCommands`" to see a list of available functions.$($white)"
