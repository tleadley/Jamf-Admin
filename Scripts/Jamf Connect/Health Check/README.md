
<img width="1158" height="839" alt="Screenshot 2026-01-21 at 9 50 42 AM" src="https://github.com/user-attachments/assets/c971abce-1a40-45ce-9f53-b8abc9b02d1e" />

## 1. Overview

This suite of tools (Maintenance Script & Jamf Pro Extension Attribute) provides robust validation of the Jamf Connect and Okta integration. It is specifically optimized for **macOS Tahoe (15) and Sonoma (14)**, addressing **Service Management (BTM)**, **ZTNA Tunnel initialization**, and **Keychain-based session validation**.

## 2. Methodology & Logic

The tools follow a **"Dependency Chain"** logic. The script checks requirements in order of operations; if a foundational requirement (like a network tunnel) is missing, the script stops and reports that specific failure rather than guessing at secondary issues.

### A. Identity & Connectivity (ZTNA Aware)

- **Key:** `OIDCIssuer`
    
- **Logic:** Reads the managed preference from `com.jamf.connect.login`.
    
- **The "Tunnel Gate":** To prevent false positives during reboot, the script monitors for the presence of a `utun` (Userspace Tunnel) interface. It will wait up to 30 seconds for **Jamf Trust** to initialize its secure pipe before attempting to reach Okta.
    
- **Validation:** Performs a `curl` to the `.well-known/openid-configuration` endpoint to ensure the path to the Identity Provider is clear.
    

### B. System Integrity (Tahoe Background Tasks)

- **Tool:** `sfltool dumpbtm`
    
- **Nuance:** In macOS 14/15, users can disable background agents in System Settings.
    
- **Detection:** The script parses the "Disposition" of the Jamf Connect daemon. If the status is `disabled`, `2`, or `3`, background password synchronization is effectively dead.
    

### C. License Verification

- **Logic:** Performs a deep scan of `com.jamf.connect` and `com.jamf.connect.login` for `LicenseFile` or `License` keys.
    
- **Fallback:** If no MDM-delivered license is found, it checks the local cache at `/Library/Application Support/com.jamf.connect/license.plist`.
    

### D. Authentication & Sync State

- **Process Check:** Verifies that the Jamf Connect app is actually running in the user session.
    
- **Password Sync:** Checks the `PasswordCurrent` key in the user's state file.
    
- **Keychain Truth:** Performs a direct query of the user's `login.keychain-db` for the "Jamf Connect" OIDC token. This is the most reliable way to verify a successful Okta handshake has occurred.
    

---

## 3. Reporting: Status Glossary

The Extension Attribute will return exactly **one** of the following statuses, prioritized by the order of the dependency chain:

|**Status Result**|**Logic Meaning**|
|---|---|
|**Healthy**|All checks passed. Connectivity, License, BTM, and Auth are green.|
|**Missing Config**|The `OIDCIssuer` plist key is missing. The device isn't scoped correctly.|
|**Okta Unreachable (HTTP)**|The tunnel exists, but the Okta tenant is not responding (e.g., 404, 503, 000).|
|**Background Tasks Disabled**|The user (or a system error) has disabled Jamf Connect in Login Items.|
|**Missing License**|No valid license found in preferences or the local app support folder.|
|**App Not Running**|The Jamf Connect binary is not active in the current user session.|
|**Passwords Out of Sync**|The IdP password and local Mac password do not match.|
|**Keychain Item Missing**|The user has no valid OIDC token. Re-authentication is required.|

---

## 4. Troubleshooting Guide for Admins

|**Status**|**Potential Cause**|**Recommended Action**|
|---|---|---|
|**Okta Unreachable**|Jamf Trust / VPN handshake timeout or Zscaler blockage.|Verify App Steering Bypasses for the Okta URL.|
|**Background Tasks Disabled**|User modified Login Items.|Push a **Service Management - Managed Login Items** MDM profile.|
|**Keychain Item Missing**|Session expired or MFA failure.|Instruct user to click the Menu Bar icon and select **"Sign In"**.|
|**Passwords Out of Sync**|User changed password on another device.|Jamf Connect should prompt; if not, use `jamfconnect://sync`.|

---

## 5. Deployment Recommendation

To resolve these issues automatically, create a **Self Service "Fix-It" Policy** scoped to any device where the Health Status `is not` Healthy. This policy should:

1. Run a script to `sfltool resetbtm` (to fix background tasks).
    
2. Open the URL `jamfconnect://signin` (to trigger the Okta handshake).
    
3. Run `jamf recon` to update the status in your dashboard immediately.
