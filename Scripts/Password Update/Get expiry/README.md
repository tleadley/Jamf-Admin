# Password Expiry Sync & Jamf Pro EA Update

## Overview

This script provides a resilient workaround for macOS local password metadata corruption. It bypasses local `dscl` dependencies by fetching the authoritative "Last Password Changed" timestamp directly from **Okta** and synchronizing the calculated "Days Remaining" to a **Jamf Pro Extension Attribute (EA)**.

This ensures that Jamf Connect notifications and Smart Groups remain accurate even if the local directory service reports incorrect data.

---

## Technical Specifications

|**Requirement**|**Detail**|
|---|---|
|**Primary Platforms**|Jamf Pro, Okta Identity Cloud|
|**Client OS**|macOS 10.13 or later|
|**Dependencies**|`jq` (Binary), `openssl` (Native), `curl` (Native)|
|**API Permissions**|Jamf Pro (Read/Update Computers), Okta (Read Users)|
|**Target EA ID**|27 (Jamf Connect Password - Expiration in days)|

---

## Logic Flow & Architecture

### 1. Authentication & Security

The script utilizes a secure handshaking process:

- **Encrypted Parameters:** Jamf Pro script parameters ($4-$8) pass encrypted API credentials.
    
- **OpenSSL Decryption:** Credentials are decrypted in-memory using a unique salt and passkey; no plain-text passwords reside in the script or policy logs.
    
- **Token Disposal:** The Jamf Pro API token is explicitly invalidated (`POST /api/v1/auth/invalidate-token`) at the end of every run.
    

### 2. Multi-Point Identity Mapping

To ensure the correct user is targeted, the script performs a three-way lookup:

1. **Local:** Identifies the current `console` user and hardware `Serial Number`.
    
2. **Jamf Pro:** Queries the Jamf API for the **Email Address** associated with that Serial Number.
    
3. **Okta:** Uses the Email Address to retrieve the unique **Okta User ID** (needed for specific user profile queries).
    

### 3. Expiry Logic

The script assumes a **60-day** rotation policy (configurable in the `get_expiry` function).

- It retrieves the `passwordChanged` attribute from Okta.
    
- It converts the ISO 8601 timestamp to a Unix Epoch.
    
- **Calculation:** $60 - (\text{CurrentTime} - \text{LastChangedTime}) / 86,400$
    

---

## Setup & Deployment (SOP)

### Step 1: Jamf Pro Extension Attribute

Ensure you have an Extension Attribute created with the following settings:

- **Name:** `Jamf Connect Password - Expiration in days`
    
- **Data Type:** `String` (or Integer)
    
- **Input Type:** `Script` (Note: This script will populate this via API, not via the EA script field itself).
    

### Step 2: Policy Configuration

1. Create a new Policy in Jamf Pro.
    
2. **Payload:** Scripts -> Add this script.
    
3. **Parameters:**

    - `$4`: Jamf Pro URL
    
    - `$5`: API Username
        
    - `$6`: Encrypted Password
        
    - `$7`: Salt
        
    - `$8`: Passphrase
        
    - `$9`: Okta API Token
        
5. **Frequency:** Set to `Once per day`.
    
6. **Trigger:** `Recurring Check-in`.
    

### Step 3: Troubleshooting

All execution details are logged locally on the client machine:

tail -f /var/log/get_expiry.log

> **Note:** If the log shows "User not found in Okta," verify that the email address in the user's Jamf Pro Inventory record matches their Okta Primary Login.

---

## Maintenance

- **Password Policy Change:** If the organization changes the password expiry from 60 days to 90 days, update the `days` variable in the `get_expiry()` function.
    
- **API Token Rotation:** Ensure the Okta API token is rotated according to security policy and updated in the Jamf Policy Parameter $9.
