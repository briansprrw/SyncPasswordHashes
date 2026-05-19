# Script Name: Import-ADUserHashes.ps1
# Description: This script imports account hashes and synchronizes passwords in a target domain.
# Maintainer: https://briansprrw.com
# Date: 2024-08-07
# Version: 1.0
# 
# This work is licensed under the Creative Commons Attribution 4.0 International License.
# To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

# Check if the DS-Internals module is installed and up to date
Write-Output "Checking DS-Internals module installation and version..."
$moduleName = 'DSInternals'
$installedModule = Get-Module -ListAvailable -Name $moduleName
$publishedModule = Find-Module -Name $moduleName

if ($installedModule) {
    $installedVersion = $installedModule.Version
    $publishedVersion = $publishedModule.Version

    if ($installedVersion -lt $publishedVersion) {
        Write-Output "Updating $moduleName module from version $installedVersion to $publishedVersion"
        Update-Module -Name $moduleName
    } else {
        Write-Output "$moduleName module is up to date (version $installedVersion)"
    }
} else {
    Write-Output "Installing $moduleName module"
    Install-Module -Name $moduleName
}

# Check if the target credential file exists, if not prompt for credentials
$targetCredPath = 'C:/scripts/target1cred.xml'
if (Test-Path -Path $targetCredPath) {
    Write-Output "Using existing target domain credentials."
    $targetDomainCredential = Import-CliXml -Path $targetCredPath
} else {
    Write-Output "Prompting for target domain credentials..."
    $credential2 = Get-Credential
    $credential2 | Export-CliXml -Path $targetCredPath
    Write-Output "Target domain credentials exported."
    $targetDomainCredential = $credential2
}

# Import the necessary variables from the export file
Write-Output "Importing domain variables from file..."
$exportData = Import-Clixml -Path 'C:/scripts/exportData.xml'
$attribute = $exportData.Attribute

# Set the necessary domain variables for the target domain
Write-Output "Setting domain variables for the target domain..."
$targetDomainNetBIOS = 'target1'
$targetDomainFQDN = 'target1.local'

# Function to synchronize password hashes with error handling
function Sync-PasswordHashes {
    param (
        [Parameter(Mandatory = $true)]
        [PSCredential] $Credential
    )
    $syncCount = 0
    foreach ($hash in $hashes) {
        if ($hash.NTHash) {
            $NTHash = ([System.BitConverter]::ToString($hash.NTHash) -replace '-', '').ToLower()
            try {
                Set-SamAccountPasswordHash -SamAccountName $hash.SamAccountName -Domain $targetDomainNetBIOS -NTHash $NTHash -Server $targetDomainFQDN -Credential $Credential
                Write-Output "Password hash for user $($hash.SamAccountName) synchronized successfully."
                $syncCount++
            } catch {
                Write-Output "Failed to set password hash for user $($hash.SamAccountName): $_"
            }
        } else {
            Write-Output "No NT hash found for user $($hash.SamAccountName). Skipping."
        }
    }
    return $syncCount
}

# Import the hashes from the exported file
Write-Output "Importing account hashes from file..."
$hashes = Import-Clixml -Path 'C:/scripts/sourceHashes.xml'

if ($hashes) {
    Write-Output "Synchronizing password hashes for users with $attribute set to 'migrate'..."
    try {
        $syncCount = Sync-PasswordHashes -Credential $targetDomainCredential
    } catch {
        Write-Output "Failed to synchronize password hashes with the current credentials. Prompting for new credentials."
        $newCredential = Get-Credential
        $newCredential | Export-CliXml -Path $targetCredPath
        Write-Output "New target domain credentials exported."
        $syncCount = Sync-PasswordHashes -Credential $newCredential
    }
    # Success message
    Write-Host ("SUCCESS: {0} password hashes were imported for {1} based on all accounts with the AD Attribute '{2}' set to 'migrate'" -f $syncCount, $targetDomainFQDN, $attribute) -ForegroundColor Green
} else {
    Write-Output "No account hashes found to import for users with $attribute set to 'migrate'."
}
