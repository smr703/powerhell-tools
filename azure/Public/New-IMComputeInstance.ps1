#Requires -Modules Az.Accounts, Az.MachineLearningServices, Az.Resources, Az.Storage, Microsoft.PowerShell.ConsoleGuiTools

<#
.SYNOPSIS
    Creates a new Compute instance in the chosen AzureML Workspace.

.DESCRIPTION
    https://github.com/equinor/ideation-machine-infra/wiki/IM-Toolbox
    This function will create compute instances to the workspace you choose.
    If you dont want to use a creation or startup script, use the switch -DefinScriptsManually, but
    without defining -CreationScriptSourcePath or -StartupScriptSourcePath.

.NOTES
    Support for OS patching will be added in a future release.

.EXAMPLE
    New-IMComputeInstance
    New-IMComputeInstance -WorkspaceName 'mlw-dev' -UserName 'xxx@equinor.com'
    New-IMComputeInstance -ComputeSize 'Standard_DS2_v2'
    New-IMComputeInstance -DefinScriptsManually -CreationScriptSourcePath 'C:\Temp\FormatAllDisks.bat'
#>

function New-IMComputeInstance {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(HelpMessage = 'Define a name for the ML Workspace')]
        [string]$WorkspaceName,
        [Parameter(HelpMessage = 'UserPrincipleName of the dedicated user of the Compute Instance')]
        [string]$UserName,
        [Parameter(HelpMessage = 'Object Id of the dedicated user of the Compute Instance')]
        [string]$ObjectId,
        [Parameter(HelpMessage = 'Use this switch if you need to define scripts manually or if you dont want to add scripts at all')]
        [switch]$DefineScriptsManually,
        [Parameter(HelpMessage = 'Defines the path to the Creation script. If you dont want to add a Creation script, use the DefineScriptsManually switch without this parameter')]
        [string]$CreationScriptSourcePath,
        [Parameter(HelpMessage = 'Defines the path to the Startup script. If you dont want to add a Startup script, use the DefineScriptsManually switch without this parameter')]
        [string]$StartupScriptSourcePath,
        [Parameter(HelpMessage = 'Sets the ApplicationSharingPolicy for the Compute Instance. Possible values are "Personal" or "Shared"')]
        [ValidateSet('Personal', 'Shared')]
        $ApplicationSharingPolicy = 'Personal',
        [Parameter(HelpMessage = 'Set the Compute Instance SKU')]
        [ValidateSet(
            'Standard_D13',
            'Standard_D13_v2',
            'Standard_DS11_v2',
            'Standard_DS2_v2',
            'Standard_DS3_v2',
            'Standard_E4ds_v4',
            'Standard_E4ds_v5',
            'Standard_NV12s_v3',
            'Standard_D14_v2',
            'Standard_D15_v2',
            'Standard_D8_v3'
        )]
        $ComputeSize
    )

    # Checks that function is run in the repository folder
    if ((Get-Location).Path -like '*ideation-machine-infra*') {
        $repo = ((Get-Location).Path -replace '(.*ideation-machine-infra).*', '$1' -replace '\\', '/') + '/'
    }
    else {
        Write-Warning "Please change directory to the `'ideation-machine-infra`' repository and re-run the command"
        return
    }

    # Get the Azure Context and Workspaces
    $azContext = Get-AzContext
    $workspaces = Get-AzMLWorkspace

    # Choose workspace
    if ($WorkspaceName) { $workspace = $workspaces | Where-Object { $_.Name -eq $WorkspaceName } }
    else {
        $selection = $workspaces |
            Select-Object Name, ResourceGroupName, Location |
            Out-ConsoleGridView -Title 'Select a Workspace' -OutputMode 1
        $workspace = $workspaces | Where-Object { $_.Name -eq $selection.Name }
    }
    if (!($workspace)) {
        Write-Warning "Found no workspace with the name $($WorkspaceName)"
        return
    }
    Write-Output "Workspace name: $($workspace.Name)"

    # Getting Azure AD Object ID
    if ($UserName -or $ObjectId) {
        if ($ObjectId) { $azureAdObject = Get-AzADUser -ObjectId $ObjectId -ErrorAction SilentlyContinue }
        else { $azureAdObject = Get-AzADUser -UserPrincipalName $UserName }
        if (!($azureAdObject)) { Write-Warning 'Found no user' }
        else { Write-Output "Found user $($azureAdObject.UserPrincipalName)" }
    }
    while (!($azureAdObject)) {
        $searchString = Read-Host -Prompt 'Type an ObjectId or a UserPrincipalName to search for'
        if ($searchString) {
            if ($searchString -match '\w{8}-(\w{4}-){3}\w{12}') {
                Write-Output 'Looking for ObjectId'
                $azureAdObject = Get-AzADUser -ObjectId $searchstring
            }
            else {
                $userObject = Get-AzADUser -Filter "startsWith(UserPrincipalName,`'$searchString`')"
                if ($userObject) {
                    if ($userObject.Count -gt 1) {
                        $azureAdObject = $userObject |
                            Out-ConsoleGridView -Title "Found $($userObject.Count) users" -OutputMode Single
                    }
                    else { $azureAdObject = $userObject }
                }
                else { Write-Warning "No Users found: $($searchstring)" }
            }
        }
        if ($azureAdObject) {
            Write-Output "Found user $($azureAdObject.UserPrincipalName)"
            if ((Read-Host -Prompt 'Is this correct? (y/n)') -ne 'y') {
                Remove-Variable azureAdObject
            }
        }
    }

    # Get available AML Compute sizes
    if ($ComputeSize) {
        $sku = Get-AzMLServiceVMSize -Location $workspace.Location | Where-Object { $_.Name -eq $ComputeSize }
    }
    else {
        $sku = Get-AzMLServiceVMSize -Location $workspace.Location |
            Where-Object { $_.SupportedComputeType -contains 'ComputeInstance' } |
            Select-Object Name, VCpUs, MemoryGB, OSVhdSizeMB, Gpu |
            Out-ConsoleGridView -Title 'Select a Compute Instance size' -OutputMode 1 -Filter 'ds2|ds3|d8_v3|ds11|d13|d14_v2|d15_v2|e4ds|nv12s'
    }
    if (!($sku)) {
        Write-Warning "Bad SKU: $($ComputeSize)"
        return
    }
    Write-Output "Compute size: $($sku.Name)"

    # Construct a name for the new Compute Instance
    $computePool = Get-AzMLWorkspaceCompute -ResourceGroupName $workspace.ResourceGroupName -WorkspaceName $workspace.Name
    $compute = $computePool | Where-Object { $_.Name -match ($azureAdObject.UserPrincipalName -replace '\@.*$') }
    $version = ([int]($compute.Name -replace '\D' | ForEach-Object { [int]$_ } | Sort-Object -Descending)[0] + 1).ToString('00')
    $computeName = ("$(($azureAdObject.UserPrincipalName -split '@')[0])$($version)-$(($WorkSpace.Name.Split('-')[-1]).ToUpper())")
    Write-Output "Name for new Compute Instance will be $($computeName)"

    # Define location for Creation script & Startup script
    if (!($DefineScriptsManually)) {
        $CreationScriptSourcePath = $repo + 'src/scripts/azureml/creation-script.sh'
        $StartupScriptSourcePath = $repo + 'src/scripts/azureml/startup-script.sh'
    }

    # Prepare for uploading scripts to fileshare
    if ($CreationScriptSourcePath -or $StartupScriptSourcePath) {
        $storageAccountName = $WorkSpace.StorageAccount.Split('/')[-1]
        $path = '.Scripts'
        $shareName = 'code-391ff5ac-6576-460f-ba4d-7e03433c68b6'

        # Getting storage account
        $param = @{
            ResourceGroupName = $workspace.ResourceGroupName
            Name              = $StorageAccountName
        }
        $storageAccount = Get-AzStorageAccount @param

        # Getting directory
        $param = @{
            Context       = $storageAccount.Context
            ShareName     = $ShareName
            WarningAction = 'SilentlyContinue'
        }
        $dir = Get-AzStorageFile @param | Where-Object { $_.Name -eq $path }

        # Check if Targetpath already exists
        if (!($dir)) {
            Write-Verbose "$($StorageAccountName)/$($shareName)/$($path) does not exist. Creating new.."
            New-AzStorageDirectory -ShareName $shareName -Path $path -Context $storageAccount.Context
        }
        else { Write-Verbose "$($StorageAccountName)/$($shareName)/$($path) already exists" }
    }

    # Add creation script to workspace
    if ($CreationScriptSourcePath) {
        if (!(Test-Path -Path $CreationScriptSourcePath)) {
            Write-Warning "Cannot find the file $($CreationScriptSourcePath)"
            if ((Read-Host -Prompt 'Do want to continue without a Creation script?(Y/N)') -ne 'y') { return }
            else { Remove-Variable CreationScriptSourcePath }
        }
        if ($CreationScriptSourcePath) {
            Write-Output "Adding creation script to fileshare on $storageAccountName"
            $creationScriptName = ($CreationScriptSourcePath -split '/')[-1]
            $param = @{
                Context       = $storageAccount.Context
                ShareName     = $shareName
                Source        = $CreationScriptSourcePath
                Path          = $path + '/' + $creationScriptName
                Force         = $true
                WarningAction = 'SilentlyContinue'
            }
            Set-AzStorageFileContent @param
        }
    }
    else { Write-Output 'No creation script added.' }

    # Add startup script to workspace
    if ($StartupScriptSourcePath) {
        if (!(Test-Path -Path $StartupScriptSourcePath)) {
            Write-Warning "Cannot find the file $($StartupScriptSourcePath)"
            if ((Read-Host -Prompt 'Do want to continue without a Startup script?(Y/N)') -ne 'y') { return }
            else { Remove-Variable StartupScriptSourcePath }
        }
        if ($StartupScriptSourcePath) {
            Write-Output "Adding startup script to fileshare on $storageAccountName"
            $startupScriptName = ($StartupScriptSourcePath -split '/')[-1]
            $param = @{
                Context       = $storageAccount.Context
                ShareName     = $shareName
                Source        = $StartupScriptSourcePath
                Path          = $path + '/' + $startupScriptName
                Force         = $true
                WarningAction = 'SilentlyContinue'
            }
            Set-AzStorageFileContent @param
        }
    }
    else { Write-Output 'No startup script added.' }

    # Construct CreationScript Object
    $CreationScript = [PsCustomObject]@{
        scriptSource    = 'workspace'
        scriptData      = ".Scripts/$creationScriptName"
        timeout         = '25m'
        scriptArguments = ($WorkSpace.Name.Split('-')[-1]).ToUpper()
    }

    # Construct StartupScript Object
    $StartupScript = [PsCustomObject]@{
        scriptSource    = 'workspace'
        scriptData      = ".Scripts/$startupScriptName"
        timeout         = '25m'
        scriptArguments = ($WorkSpace.Name.Split('-')[-1]).ToUpper()
    }

    # Find Subnet Id
    # $subnetId = $WorkSpace.PrivateEndpointConnection.PrivateEndpointSubnetArmId | Where-Object { $_ -match 'AzureML' }
    $pe = Get-AzPrivateEndpoint | Where-Object { $_.Id -eq $WorkSpace.PrivateEndpointConnection.PrivateEndpointId }
    $subnetId = $pe.Subnet.Id

    # Define API version
    $APIVersion = '2024-04-01'

    # Url
    $url = "https://management.azure.com/subscriptions/$($azContext.Subscription.Id)" +
    "/resourceGroups/$($Workspace.ResourceGroupName)/providers/Microsoft.MachineLearningServices" +
    "/workspaces/$($Workspace.Name)/computes/$($computeName.ToUpper())?api-version=$($APIVersion)"

    # Define the body
    $body = @{
        location   = $workspace.Location
        properties = @{
            computeType      = 'ComputeInstance'
            description      = 'Created with Powershell'
            disableLocalAuth = $true
            properties       = @{
                vmSize                           = $sku.Name
                subnet                           = @{
                    id = $subnetId
                }
                applicationSharingPolicy         = $ApplicationSharingPolicy
                # customServices = ''
                enableOSPatching                 = $false
                sshSettings                      = @{
                    sshPublicAccess = 'Disabled'
                }
                computeInstanceAuthorizationType = 'personal'
                personalComputeInstanceSettings  = @{
                    assignedUser = @{
                        objectId = $azureAdObject.Id
                        tenantId = $azContext.Tenant.Id
                    }
                }
                enableNodePublicIp               = $false
                idleTimeBeforeShutdown           = 'PT120M'
                setupScripts                     = @{
                    scripts = @{
                        creationscript = $CreationScript
                        startupscript  = $StartupScript
                    }
                }
            }
        }
    } | ConvertTo-Json -Depth 10

    # Create Authorization Header
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Bearer ' + (Get-AzAccessToken -WarningAction 'SilentlyContinue').Token
    }

    # Send the request
    Invoke-RestMethod -Uri $url -Method PUT -Body $body -Headers $authHeader
}
