<#
.SYNOPSIS
    Fetches all Service Principals based on a filter.
    Checks the expiry dates of the secret and creates a github issue on each secret.
    Needs to be run manually. See wiki for depenedencies.

.DESCRIPTION
    Returns disks that are going to expire

.EXAMPLE
    SecretExpiry.ps1
#>

function Get-SPSecretExpiry {

    # Define how to filter Service Principals and set amount of days ahead you want a notification
    $servicePrincipalFilter = 'your Filter'
    $amountOfDays = 14
    $thresholdDate = (Get-Date).AddDays($amountOfDays)

    # Get all Service Principals filtered on display name

    Write-Output "Getting all Service Principals starting with '$($servicePrincipalFilter)' in display name."
    Write-Output 'Please wait..'
    $servicePrincipals = az ad app list `
        --filter "startswith(displayName, '$servicePrincipalFilter')" `
        --query '[].{id:id, name:displayName, secrets:passwordCredentials}' | ConvertFrom-Json -Depth 10

    # Getting secrets that either is expired or will expire within 14 days
    $result = @()

    Write-Output $title
    foreach ($sp in $servicePrincipals) {
        foreach ($secret in $sp.secrets) {
            if ($secret.endDateTime -le $thresholdDate) {
                $formattedDate = $secret.endDateTime.ToString('dd-MM-yyyy', $culture)
                $result += [PSCustomObject]@{
                    AppName    = $sp.name
                    AppId      = $sp.id
                    SecretName = $secret.displayName
                    ExpiryDate = $formattedDate
                }
            }
        }
    }

    # Creating issue in Github Repo

    $ignoreList = @('ignorevalues') #Ignoring Service Principals that is not managed by you
    $projectName = 'Your project - DevOps'
    $label = 'secret-expiry'
    $counter = 0

    $title = "The following secrets is expired or will expire within $($amountOfDays) days:`n"

    foreach ($res in $result) {
        if ($ignoreList -notcontains $($res.AppName)) {
            Write-Output "Creating issue for expired secret in '$($res.AppName)' app registration"
            Write-Output "Secret name: '$($res.SecretName)'"
            Write-Output "Expiry date: $($res.ExpiryDate)"
            $counter += 1
            gh issue create `
                --title "SECRET EXPIRY - $($res.AppName)" `
                --body "Secret in with name '$($res.SecretName)' will or did expire $($res.ExpiryDate)" `
                --project $projectName `
                --label $label
            Write-Output ''
        }
    }

    if (!$counter) {
        Write-Output 'All secrets are up to date!'
    }

}
