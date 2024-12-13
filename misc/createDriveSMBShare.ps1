# Storage account. You’ll need the following information:
# new line
# Storage Account Name: The name of your Azure Storage account.
# File Share Name: The name of the file share in the Storage account.
# Storage Account Key: The access key for the storage account.
# Local Drive Letter: The drive letter you want to assign to the mapped drive (e.g., Z:).



# Define variables
$StorageAccountName = "<YourStorageAccountName>" # Replace with your storage account name
$FileShareName = "<YourFileShareName>"          # Replace with your file share name
$StorageAccountKey = "<YourStorageAccountKey>"  # Replace with your storage account key
$LocalDriveLetter = "F:"                        # Replace with desired drive letter

# Construct the UNC path for the SMB file share
$UNCPath = "\\$StorageAccountName.file.core.windows.net\$FileShareName"

# Create the credentials object
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList `
    ($StorageAccountName, (ConvertTo-SecureString $StorageAccountKey -AsPlainText -Force))

# Map the network drive
# The -Persist parameter ensures the drive mapping persists across reboots.
New-PSDrive -Name $LocalDriveLetter.Substring(0,1) -PSProvider FileSystem -Root $UNCPath -Credential $Credential -Persist

# Confirm success
Write-Host "Drive $LocalDriveLetter has been successfully mapped to $UNCPath" -ForegroundColor Green
