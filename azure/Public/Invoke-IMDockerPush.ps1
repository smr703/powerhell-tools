#Requires -Module Az.ContainerRegistry, Common

<#
.SYNOPSIS
	Import files to Docker Desktop, Re-Tags Images & Push to Container Registry

.DESCRIPTION
    https://github.com/equinor/ideation-machine-infra/wiki/IM-Toolbox.LINK

    This function will do the following:
	- Import files to Docker Desktop as Images
    - Automatically Re-Tags newly imported Images according to Container Registry name
    - Push newly re-tagged images to the defined Container Registry

    The -SkipImport switch will skip importing files to Docker Desktop and go straight to re-tag images that doesnt start with -CrName
    The -PushOnly switch will skip all other steps and go straight to pushing all images that starts with -CrName
    The -AsJob switch will create a background job for pushing images to Container Registry instead of pushing them in the terminal scope

.EXAMPLE
	Invoke-DockerPush -CrName 'crimcommon'
	Invoke-DockerPush -CrName 'crimcommon' -AsJob
#>

function Invoke-IMDockerPush {
    [CmdletBinding()]
    [Alias('Invoke-DockerPush')]

    param(
        [string]$CrName = 'crimcommon',
        $LocalSource,
        [switch]$SkipImport,
        [switch]$PushOnly,
        [switch]$AsJob
    )


    # Get Container Registry Object
    $cr = Get-AzContainerRegistry | Where-Object { $_.Name -eq $CrName }

    # Load new images to Docker Desktop
    if (!($SkipImport -or $PushOnly)) {
        if (!($LocalSource)) {
            if ($IsWindows) {
                $LocalSource = (Open-File -multiSelect $true)
            }
            else { $LocalSource = Read-Host -Prompt 'Input at least one path for -LocalSource' }
        }
        [array]$oldImg = (docker images --format json) | ConvertFrom-Json
        $items = Get-ChildItem $LocalSource
        $items | ForEach-Object {
            Write-Output "Importing image to Docker Desktop: $($_.Name)"
            docker load -i $_.FullName
        }
    }
    else { Write-Output 'Skipping Import' }

    # Collect all newly added images in Docker Desktop and re-Tag them to crimcommon
    if (!($PushOnly)) {
        [array]$img = (docker images --format json) | ConvertFrom-Json | Where-Object {
            "$($_.Repository):$($_.Tag)" -notin ($oldImg | ForEach-Object { "$($_.Repository):$($_.Tag)" })
        }
        $img | ForEach-Object {
            if ($_.Repository -in @('nginx', 'mongo')) {
                $newTag = "$($cr.LoginServer)/$($_.Repository -replace '^(.*?)/'):$($_.Tag)"
            }
            else {
                $newTag = "$($cr.LoginServer)/sparkbeyond/$($_.Repository -replace '^(.*?)/'):$($_.Tag)"
            }
            if (
                $_.Repository -notlike "$($cr.LoginServer)*" -and
                $newTag -notin ($img | ForEach-Object { "$($_.Repository):$($_.Tag)" })
            ) {
                Write-Output "Tagging image $($_.Repository):$($_.Tag) to $newTag"
                docker tag "$($_.Repository):$($_.Tag)" $newTag
            }
            else { "Skipping re-tag on $($_.Repository):$($_.Tag)" }
        }
    }
    else { Write-Output 'Skipping Re-Tag' }

    # Login to the Container Registry
    $key = Get-AzContainerRegistryCredential -RegistryName $cr.Name -ResourceGroupName $cr.ResourceGroupName
    $key.Password | docker login --username $cr.Name --password-stdin $cr.LoginServer

    # Collect newly re-tagged images Upload to Container Registry
    [array]$crimg = (docker images --format json) | ConvertFrom-Json | Where-Object {
        "$($_.Repository):$($_.Tag)" -notin ($img + $oldImg | ForEach-Object { "$($_.Repository):$($_.Tag)" }) -and
        $_.Repository -like "$($cr.LoginServer)*"
    }

    if ($AsJob) {
        Start-Job -Name 'Pusher' -ScriptBlock {
            $using:crimg | ForEach-Object {
                docker push "$($_.Repository):$($_.Tag)"
            }
        }
        Write-Output 'docker push has been started as a Job in Powershell. Use the cmdlet Get-Job to check the status.'
    }
    else {
        $crimg | ForEach-Object {
            Write-Output "Pushing $($_.Repository):$($_.Tag) to $($cr.LoginServer)"
            docker push "$($_.Repository):$($_.Tag)"
        }
    }
}
