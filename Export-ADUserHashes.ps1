# Script Name: Export-ADUserHashes.ps1
# Description: This script exports account hashes and domain information from a source domain.
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

# Prompt for the attribute to use for filtering
$attribute = Read-Host "Enter the attribute to filter on (default is 'pager')"
if (-not $attribute) {
    $attribute = 'pager'
}

# Check if the source credential file exists, if not prompt for credentials
$sourceCredPath = 'C:/scripts/source1cred.xml'
if (Test-Path -Path $sourceCredPath) {
    Write-Output "Using existing source domain credentials."
    $sourceDomainCredential = Import-CliXml -Path $sourceCredPath
} else {
    Write-Output "Prompting for source domain credentials..."
    $credential1 = Get-Credential
    $credential1 | Export-CliXml -Path $sourceCredPath
    Write-Output "Source domain credentials exported."
    $sourceDomainCredential = $credential1
}

# Set the necessary domain variables for the source domain
Write-Output "Setting domain variables for the source domain..."
$sourceDomainNetBIOS = 'source1'
$sourceDomainFQDN = 'source1.local'
$sourceDomainDN = 'DC=source1,DC=local'

# Function to get account hashes with error handling
function Get-AccountHashes {
    param (
        [Parameter(Mandatory = $true)]
        [PSCredential] $Credential
    )
    try {
        $allHashes = Get-ADReplAccount -All -NamingContext $sourceDomainDN -Server $sourceDomainFQDN -Credential $Credential
        $allUsers = Get-ADUser -Filter * -SearchBase $sourceDomainDN -Server $sourceDomainFQDN -Credential $Credential -Properties $attribute
        $migrateUsers = $allUsers | Where-Object { $_.$attribute -eq 'migrate' }
        return $allHashes | Where-Object { $migrateUsers.DistinguishedName -contains $_.DistinguishedName }
    } catch {
        Write-Output "Failed to retrieve account hashes with the current credentials. Prompting for new credentials."
        $newCredential = Get-Credential
        $newCredential | Export-CliXml -Path $sourceCredPath
        Write-Output "New source domain credentials exported."
        $allHashes = Get-ADReplAccount -All -NamingContext $sourceDomainDN -Server $sourceDomainFQDN -Credential $newCredential
        $allUsers = Get-ADUser -Filter * -SearchBase $sourceDomainDN -Server $sourceDomainFQDN -Credential $newCredential -Properties $attribute
        $migrateUsers = $allUsers | Where-Object { $_.$attribute -eq 'migrate' }
        return $allHashes | Where-Object { $migrateUsers.DistinguishedName -contains $_.DistinguishedName }
    }
}

# Retrieve account hashes from the source domain
Write-Output "Retrieving account hashes from the source domain..."
$hashes = Get-AccountHashes -Credential $sourceDomainCredential

if ($hashes) {
    # Export the hashes to a file
    Write-Output "Exporting account hashes to file..."
    $hashes | Export-Clixml -Path 'C:/scripts/sourceHashes.xml'
    
    # Export the necessary variables to a file
    Write-Output "Exporting domain variables to file..."
    $exportData = @{
        SourceDomainNetBIOS = $sourceDomainNetBIOS
        SourceDomainFQDN = $sourceDomainFQDN
        SourceDomainDN = $sourceDomainDN
        Attribute = $attribute
    }
    $exportData | Export-Clixml -Path 'C:/scripts/exportData.xml'
    
    # Success message
    Write-Host ("SUCCESS: {0} password hashes were exported for {1} based on all accounts with the AD Attribute '{2}' set to 'migrate'." -f $hashes.Count, $sourceDomainFQDN, $attribute) -ForegroundColor Green
} else {
    Write-Output "No account hashes retrieved from the source domain."
}
