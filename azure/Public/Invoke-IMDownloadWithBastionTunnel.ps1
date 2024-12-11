#Requires -Modules Az.Compute, Az.KeyVault, Az.Network, Microsoft.PowerShell.ConsoleGuiTools

<#
.SYNOPSIS
    Downloads files from a virtual machine using Bastion tunnel and scp

.DESCRIPTION
    https://github.com/equinor/ideation-machine-infra/wiki/IM-Toolbox.NOTES

.EXAMPLE
    Invoke-DownloadWithBastionTunnel `
        -SourceFile `
            '~/docker-compose.yaml', `
            '~/docker-compose-production.yaml', `
            '~/.env', `
            '~/.compose.backend.production.env' `
        -DestinationPath 'C:/temp/'

    Invoke-DownloadWithBastionTunnel -UseSshKey -SourceFile '~/*'
#>

function Invoke-IMDownloadWithBastionTunnel {
    [Alias('Invoke-DownloadWithBastionTunnel')]
    [CmdletBinding()]
    param (
        [string]$VmName,
        [string]$VmUserName = 'imadmin',
        [int]$ResourcePort = 22,
        [int]$LocalPort = 50022,
        [array]$SourceFile = '~/*',
        [string]$DestinationPath,
        [switch]$UseSshKey
    )

    Begin {
        $vm = Get-AzVM -Status | Where-Object { $_.Name -like "*$($VmName)*" }
        if ($vm.count -gt 1 -or $vm.Count -lt 1) {
            $VmTarget = $vm |
                Select-Object Name, @{n = 'OS'; e = { $_.StorageProfile.OsDisk.OSType } }, PowerState, Location |
                Out-ConsoleGridView -Title 'Select a Virtal Machine' -OutputMode 1
            $vm = $vm | Where-Object { $_.Name -eq $VmTarget.Name }
        }
        Write-Output "Source Vm: $($vm.Name)"
        $Bastion = Get-AzBastion | Where-Object { $_.Location -eq $Vm.Location }

        if ($IsWindows) {
            $sshFolder = "$env:USERPROFILE/.ssh"
            if (!($DestinationPath)) {
                $DestinationPath = "$env:USERPROFILE/Downloads"
            }
        }
        else {
            $sshFolder = "$env:HOME/.ssh"
            if (!($DestinationPath)) {
                $DestinationPath = "$env:HOME/Downloads"
            }
        }
    }

    Process {
        # Create tunnel
        Write-Output 'Starting Bastion Tunnel..'
        Start-Job -Name 'Tunnel' -ScriptBlock {
            az network bastion tunnel `
                --name ($using:Bastion).Name `
                --resource-group ($using:Bastion).ResourceGroupName `
                --target-resource-id ($using:vm).id `
                --resource-port $using:ResourcePort `
                --port $using:LocalPort
        }

        # Extract secret from KeyVault
        $ErrorActionPreference = 'Stop'
        try {
            $secret = @()
            foreach ($vault in (Get-AzKeyVault -ResourceGroupName $vm.ResourceGroupName)) {
                $secret += Get-AzKeyVaultSecret -VaultName $vault.VaultName
            }
            $key = $secret | Select-Object VaultName, Name | Out-ConsoleGridView -Title "Select the secret for $($vm.Name)" -OutputMode 1
            $SuperSecretPw = Get-AzKeyVaultSecret -VaultName $key.VaultName -Name $key.Name -AsPlainText
        }
        catch { Write-Warning "$_.Exception.Message" }
        $ErrorActionPreference = 'Continue'

        # Make a backup of the known_hosts file
        Write-Output 'Making a copy of the hostfile..'
        $knownHosts = "$sshFolder/known_hosts"
        try { Copy-Item $knownHosts "$($knownHosts).bkp" -Force -ErrorAction Stop }
        catch { Write-Warning "Cannot locate the hostfile:`n $_.Exception.Message" }

        # Create an SSH keyfile from the KeyVault secret
        if ($UseSshKey) {
            if ($SuperSecretPw) {
                Write-Output "Creating SSH keyfile $sshFolder/sshkey.tmp"
                $SuperSecretPw | Out-File -FilePath "$sshFolder/sshkey.tmp" -Encoding utf8
            }
            else {
                Write-Warning 'No secret to create key-file from. Make sure to import the private key into the key vault then retry.'
                return
            }

            # Copy files
            foreach ($s in $SourceFile) { scp -i "$sshFolder/sshkey.tmp" -P $LocalPort "$($VmUserName)@127.0.0.1:$($s)" $DestinationPath }
        }
        else {
            if ($SuperSecretPw) {
                $SuperSecretPw | Set-Clipboard
                Write-Output 'Right click to paste the password when prompted.'
            }
            else { Write-Warning "Failed to retrieve the password for $($VmUserName). You will have to input the password manually." }

            # Copy files
            foreach ($s in $SourceFile) { scp -P $LocalPort "$($VmUserName)@127.0.0.1:$($s)" $DestinationPath }
        }
        foreach ($f in $SourceFile) {
            if (Test-Path -Path "$DestinationPath/$($f -replace '.*(\\|/)')") {
                Write-Output "File has been copied to $DestinationPath/$($f -replace '.*(\\|/)')"
            }
        }
    }

    End {
        # Close the Bastion Tunnel
        Write-Output 'Closing Bastion Tunnel..'
        Get-Job | Where-Object { $_.Name -eq 'Tunnel' } | Stop-Job
        Get-Job | Where-Object { $_.Name -eq 'Tunnel' } | Remove-Job -Force

        # Restore the known_hosts file from backup
        Write-Output 'Restoring hostfile..'
        try { Copy-Item "$($knownHosts).bkp" $knownHosts -Force -ErrorAction Stop }
        catch { Write-Warning "Cannot locate the hostfile backup:`n $_.Exception.Message" }

        # Delete the key-file
        if (Test-Path "$sshFolder/sshkey.tmp") {
            Write-Output 'Deleting SSH keyfile..'
            Remove-Item -Path "$sshFolder/sshkey.tmp" -Confirm:$false -Force
        }
        Write-Output 'Bye bye!'
    }
}
