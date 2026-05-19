# AD User Password Hash Sync

Export and import Active Directory user password hashes between domains securely and efficiently.

## Overview

This toolset provides two PowerShell scripts designed to export and import Active Directory (AD) user account password hashes between domains. Users are selected for migration based on a specified AD attribute set to `"migrate"`. The scripts operate independently and are designed to work in disconnected environments—exported files must be manually transferred between source and target domains.

**Maintainer:** [briansprrw.com](https://briansprrw.com)  
**Date:** 2024-08-07  
**Version:** 1.0

## Prerequisites

- **Active Directory Access:** Administrative permissions in both source and target domains
- **DSInternals Module:** PowerShell module must be installed and current (automatically installed if missing)
- **Migration Marker:** Set your migration attribute (default: `pager`) to `"migrate"` for accounts you want to sync
- **PowerShell:** Windows PowerShell 5.0+ or PowerShell Core
- **Network:** No inter-domain connectivity required (files transferred manually)

## Quick Start

### Step 1: Export from Source Domain

```powershell
.\Export-ADUserHashes.ps1
```

When prompted:
- Enter the AD attribute to filter on (press Enter to use default: `pager`)
- Provide source domain credentials if prompted
- Script generates `sourceHashes.xml` and `exportData.xml`

### Step 2: Transfer Files

Copy the generated files to the target domain environment:
- `C:/scripts/sourceHashes.xml`
- `C:/scripts/exportData.xml`

### Step 3: Import to Target Domain

```powershell
.\Import-ADUserHashes.ps1
```

When prompted:
- Provide target domain credentials if prompted
- Script synchronizes password hashes for all marked users

## Detailed Script Behavior

### Export-ADUserHashes.ps1

1. **Module Check:** Verifies DSInternals is installed and current; installs/updates as needed
2. **Attribute Prompt:** Requests the AD attribute to filter users on (defaults to `pager`)
3. **Credential Handling:** Uses cached credentials from `C:/scripts/source1cred.xml` if available, otherwise prompts and caches them
4. **Hash Retrieval:** Queries source domain for all user accounts with the specified attribute set to `"migrate"`
5. **Export Files:** 
   - `sourceHashes.xml` — Encrypted credential-containing hash data
   - `exportData.xml` — Domain configuration and filter attribute metadata
6. **Status Output:** Displays count of exported accounts in green

### Import-ADUserHashes.ps1

1. **Module Check:** Verifies DSInternals is installed and current
2. **Credential Handling:** Uses cached credentials from `C:/scripts/target1cred.xml` if available, otherwise prompts and caches them
3. **Metadata Import:** Reads domain configuration from `exportData.xml`
4. **Hash Import:** Loads hashes from `sourceHashes.xml`
5. **Synchronization:** Sets NT hashes for matching users in target domain
6. **Status Output:** Displays count of successfully synchronized accounts in green

## Configuration

### Domain Settings

Edit the hardcoded domain variables in each script to match your environment:

**Export Script:**
```powershell
$sourceDomainNetBIOS = 'source1'
$sourceDomainFQDN = 'source1.local'
$sourceDomainDN = 'DC=source1,DC=local'
```

**Import Script:**
```powershell
$targetDomainNetBIOS = 'target1'
$targetDomainFQDN = 'target1.local'
$targetDomainDN = 'DC=target1,DC=local'
```

### Attribute Selection

The default filtering attribute is `pager`. You can use any AD attribute; ensure all users to migrate have that attribute set to exactly `"migrate"`.

## Security Best Practices

⚠️ **Credential Management**
- Cached credentials are stored in `C:/scripts/` as encrypted XML files—restrict access to this directory
- Use service accounts with minimal required permissions (password hash read/write only)
- Delete credential files after migration is complete
- Never commit credential files to version control

⚠️ **File Handling**
- Store `sourceHashes.xml` securely during transfer between domains
- Consider encrypting files in transit or using secure channels (SFTP, encrypted USB)
- Delete export files from the source domain after successful import verification
- Validate file integrity if transferring across untrusted networks

⚠️ **Testing**
- Test on a small subset of users first in a non-production environment
- Verify password synchronization with a test user before full migration
- Have a rollback plan in case of issues

## Troubleshooting

### Issue: "Module 'DSInternals' not found"
- The script will automatically install DSInternals; ensure NuGet provider is available
- If installation fails, manually install: `Install-Module -Name DSInternals`

### Issue: "Failed to retrieve account hashes"
- Verify credentials have admin rights in source domain
- Confirm domain FQDN and DN are correct
- Check that the specified attribute exists in your AD schema

### Issue: "No account hashes retrieved"
- Ensure target users have the migration attribute set to exactly `"migrate"`
- Check the attribute name matches what you specified during export

### Issue: "Failed to set password hash"
- Verify target domain credentials have permission to modify user accounts
- Confirm users exist in target domain with matching SAM account names
- Check target domain FQDN and NetBIOS are correct

### Credential Errors
- Delete the cached credential file (`C:/scripts/source1cred.xml` or `target1cred.xml`)
- Re-run the script to re-prompt for credentials
- Verify credentials are correct and have necessary permissions

## Important Notes

- **Disconnected Operation:** Designed for environments where source and target domains cannot communicate directly
- **Incremental Runs:** Scripts can be run multiple times; only marked users are processed
- **User Matching:** Accounts are matched by `SamAccountName`; ensure naming is consistent between domains
- **Error Handling:** Individual user failures don't stop the process; check output for any failed accounts

## License

This work is released into the public domain under CC0 1.0 Universal.  
Visit https://creativecommons.org/publicdomain/zero/1.0/ for details.

## Disclaimer

⚠️ This script was partially written, formatted, and documented by ChatGPT (OpenAI). While significant effort has been made to ensure accuracy and reliability, please note:

1. **Testing Required:** Thoroughly validate and test in a controlled environment before production use
2. **Potential Issues:** Despite careful review, unintended bugs may exist; review code and adjust as needed
3. **Security:** Handle credentials and sensitive data with care; follow best practices for secure storage
4. **Customization:** Adapt scripts to your specific AD schema and environment requirements
5. **Warranty:** Provided "as-is" without warranty. User assumes full responsibility for outcomes

By using these scripts, you acknowledge understanding and accepting these conditions.

## Version History

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2024-08-07 | Initial Release |
