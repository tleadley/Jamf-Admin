

# 🔐 Jamf Pro & Jamf Connect: Password Sync Remediation

**Version:** 2.2 (Dec 2025)

**Lead Engineer:** Trevor Leadley

**Platforms:** macOS 10.13+ | Jamf Pro | Jamf Protect | Okta/IDP

## 1. Executive Summary

This solution automates the remediation of "Password Out-of-Sync" states. It addresses the gap between local macOS account passwords and Identity Provider (IDP) passwords.

**Triggers:**

1. **Okta/IDP Password Change:** Detected via Jamf Connect.
    
2. **Unauthorized Local Change:** Detected by Jamf Protect via a custom analytic monitoring the local directory service.
    

---

## 2. Jamf Pro Configuration

### Script Parameter Mapping

|**Parameter**|**Label**|**Purpose**|
|---|---|---|
|**P4**|`Jamf Server URL`|FQDN (e.g., `company.jamfcloud.com`)|
|**P5**|`API Username`|Service account with Update permissions|
|**P6**|`Encrypted Password`|AES-256 Encrypted string of the API password|
|**P8**|`Encryption Salt`|Salt used for OpenSSL decryption|
|**P9**|`Encryption Key`|Passphrase/Key used for OpenSSL decryption|

### API Roles & Permissions

The account in **P5** requires:

- **Computers:** Read, Update
    
- **Computer Extension Attributes:** Read
    

---

## 3. Jamf Protect Custom Analytic

The remediation loop is triggered when Jamf Protect detects a change to the local user record.

**Analytic Name:** `password_update`

**Predicate:**

Plaintext

```
( $event.path BEGINSWITH[cd] "/var/db/dslocal/nodes/Default/users" 
  AND $event.path CONTAINS[cd] ".plist" 
  AND $event.isModified == 1 
  AND $event.file.contentsAsDict.accountPolicyData.asPlistDict.passwordLastSetTime != $event.file.snapshotData.asPlistDict.accountPolicyData.asPlistDict.passwordLastSetTime )
```

---

## 4. The Remediation Script

This script uses **Bearer Token Authentication** and includes a critical fix for **ISO 8601 Date Parsing** to ensure the API token remains valid during execution.

```
#!/bin/bash

# --- PRE-FLIGHT ---
loggedInUser=$( ls -l /dev/console | awk '{print $3}' )
jamfserver="$4"
jamfProUser="$5"
jamfProPassEnc="$6"

# Decrypt password
jamfProPass=$( echo "$jamfProPassEnc" | /usr/bin/openssl enc -aes256 -d -a -A -S "$8" -k "$9" )
APIauth="$jamfProUser:$jamfProPass"

# --- CORE FUNCTIONS ---

get_token() {
    echo "Fetching fresh API token..."
    authToken=$( /usr/bin/curl --request POST --silent --url "https://$jamfserver/api/v1/auth/token" --user "$APIauth" )
    token=$( /usr/bin/plutil -extract token raw - <<< "$authToken" )
    tokenExpiration=$( /usr/bin/plutil -extract expires raw - <<< "$authToken" )
    
    # Strip milliseconds and Z for macOS date compatibility
    cleanExpiration=$(echo "$tokenExpiration" | sed 's/\.[0-9]*//g; s/Z//g')
    localTokenExpirationEpoch=$( /bin/date -j -f "%Y-%m-%dT%T" "$cleanExpiration" +"%s" 2> /dev/null )
}

update_ea(){	
    currentEpoch=$(date +%s)
    if [[ -n "$token" ]] && [[ $localTokenExpirationEpoch -gt $currentEpoch ]]; then
        getudid=$(ioreg -d2 -c IOPlatformExpertDevice | awk -F\" '/IOPlatformUUID/{print $(NF-1)}')
        eaID="33"
        eaName="Password Update" 
        value="" # This clears the Extension Attribute

        curl -k -s --header "Authorization: Bearer $token" -X "PUT" \
             "https://$jamfserver/JSSResource/computers/udid/$getudid/subset/extension_attributes" \
              -H "Content-Type: application/xml" \
              -H "Accept: application/xml" \
              -d "<computer><extension_attributes><extension_attribute><id>$eaID</id><name>$eaName</name><value>$value</value></extension_attribute></extension_attributes></computer>"
    else
        echo "API Token invalid or date parsing failed. EA update skipped."
    fi
}

get_uptime() {
    uptime_string=$(uptime | awk -F'up ' '{print $2}' | cut -d',' -f1)
    days=$(echo $uptime_string | awk '{print $1}')
    if [[ $uptime_string == *"day"* ]]; then
       echo "$days"
    else
       echo "0"
    fi
}

# [Remediation Logic & Secure Token Checks...]
```

---

## 5. Help Desk Triage & The "Danger Path"

### 🚩 Danger Path Identification

If the script alerts **"Security Authorization Issue"**, the user lacks a **Secure Token**.

**THE GOLDEN RULE: DO NOT RESTART THE COMPUTER.**

### Danger Path Remediation (Tier 2/3)

1. Grant Token: If another admin is present:
    
    sysadminctl -adminUser [Admin] -adminPassword - -secureTokenOn [User] -password -
    
2. Escrow Bootstrap Token: If missing from Jamf:
    
    sudo profiles install -type bootstraptoken
    
3. **Validate:** `sysadminctl -secureTokenStatus [User]` should now be **ENABLED**.
    

---

## 6. Testing & Validation Loop

1. **Create Dummy:** `sudo sysadminctl -addUser testuser -password "Pass123"`
    
2. **Trigger Analytic:** `sudo dscl . -passwd /Users/testuser "Pass123" "NewPass456"`
    
3. **Watch Path:** Check `/Library/Application Support/JamfProtect/groups/` for the trigger file.
    
4. **Verify Inventory:** Check Jamf Pro Computer Record -> Extension Attributes -> ID 33 "Password Update" should be **Blank**.
    

---

## 7. Troubleshooting API Status Codes

|**Code**|**Meaning**|**Fix**|
|---|---|---|
|**401**|Unauthorized|Check P5/P6/P8/P9 decryption logic.|
|**403**|Forbidden|Grant "Update" permissions to the API account.|
|**404**|Not Found|Ensure EA ID 33 "Password Update" exists in Jamf settings.|

---

**Maintenance Contact:** Trevor Leadley

**Last Updated:** Dec 2025
