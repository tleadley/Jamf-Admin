
# S.U.P.E.R.M.A.N. (super) Deployment via Jamf Pro

This repository documents the standard operating procedure (SOP) for deploying and configuring the S.U.P.E.R.M.A.N. script to enforce macOS minor updates and major upgrades using Jamf Pro.

**S.U.P.E.R.M.A.N.**—an acronym for **S**oftware **U**pdate **P**olicy **E**nforcement **R**ecursive **M**essaging **A**nd **N**otifications—is a binary application that "optimizes the macOS update and upgrade experience."

<img width="2560" height="4096" alt="superman-deployment-infographic" src="https://github.com/user-attachments/assets/9b6ba965-180f-4be2-bbc3-2b14d8a199c4" />

## 1. Overview and Policy Summary

This configuration is designed to provide a balance between user flexibility and security compliance by establishing a clear timeline for mandatory updates.

### Enforcement Timeline Visual

A quick visualization of the update lifecycle, starting from the OS release date:

|Phase|Days Since Release|Action|
|---|---|---|
|**Grace Period**|Day 0 - 30|Updates ignored, device protected by `DaysDeadlineStart`.|
|**User Deferral**|Day 30 - 40|Enforcement begins. User can defer **5 times** (24 hours each).|
|**Soft Deadline**|Day 40 - 45|Prompts become persistent (`DialogTimeoutSoftDeadline`).|
|**Hard Deadline**|Day 45+|Forced install and restart (`HardDeadlineDays`).|

**▶️ Timeline Flow:**

`[Day 0: Release] ⏳ Grace Period (30 days) ➡️ [Day 30: Start] 🚪 User Deferral (Max 5x) 🛑 [Day 40: Soft Deadline] 🚨 Persistent Prompt 💥 [Day 45: Hard Deadline] 🤖 Forced Install`

|Feature|Description|Key Value|
|---|---|---|
|**Grace Period**|Updates are **ignored** for 30 days post-OS release for testing purposes.|`DaysDeadlineStart: 30`|
|**User Deferrals**|Users receive 5 deferral opportunities before the soft deadline.|`SoftDeadlineCount: 5`|
|**Deferral Duration**|Each deferral postpones the next prompt by 24 hours.|`DefaultDeferralTimer: 86400`|
|**Update Window**|The full enforcement period runs from Day 30 (Start) to Day 45 (Hard Deadline).|`SoftDeadlineDays: 40`, `HardDeadlineDays: 45`|
|**Mandatory Interaction**|Dialogs cannot be ignored; users must click "Defer" or "Restart Now".|`DialogTimeout*Deadline: 31536000`|
|**Authentication**|Uses modern, secure Jamf API Client credentials.|`--auth-jamf-client`|
|**Failover**|If the MDM API push fails, the user is prompted for local credentials as a fallback.|`AllowAuthMDMFailoverToUser: true`|
|**Upgrades**|Major macOS upgrades (e.g., Ventura to Sequoia) are permitted by this workflow.|`AllowUpgrade: true`|

## 2. Secure API Client Setup in Jamf Pro

**Best Practice:** The `--auth-jamf-client` method is mandatory for security and resolves the deprecated user/password method warning.

### Step 2.1: Create API Role

1. Navigate to **Settings > System > API Roles and Clients > API Roles**.
    
2. Create a role (e.g., `SUPERMAN-Update-Role`).
    
3. Grant the following **minimum privileges**:
    
    - **Jamf Pro Server Objects:** `Computers` (Read)
        
    - **Jamf Pro Server Actions:** `Send Computer Remote Command` (Download and Install OS X Update), `Create Managed Software Updates`, `Read Managed Software Updates`.
        

### Step 2.2: Create API Client

1. Navigate to **Settings > System > API Roles and Clients > API Clients**.
    
2. Create a client linked to the `SUPERMAN-Update-Role`.
    
3. **Security Constraint: Access Token Expiration:** Set the expiration to a low value, such as **60 minutes (1 hour)**. S.U.P.E.R.M.A.N. handles token refresh internally, ensuring compliance while minimizing credential exposure risk.
    
4. Securely store the generated **Client ID** and **Client Secret**.
    

## 3. Configuration Profile (`.plist` Content)

This configuration is deployed using a Jamf Pro **Configuration Profile** with an **Application & Custom Settings > Custom** payload.

- **Preference Domain:** `com.macjutsu.super`
    

Use the following XML content for the Custom Settings payload:

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>

<!-- Allows for the use of Jamf Pro API credentials --> 
<key>AuthJamfComputerID</key>
<string>$JSSID</string>
   
<!-- ============================================= -->
<!-- 1. UPGRADE/UPDATE CONFIGURATION -->
<!-- ============================================= -->

<!-- Enables the super script to manage and install macOS Major Upgrades (e.g., Ventura to Sonoma) -->
<key>AllowUpgrade</key>
<true/>

<!-- Automatically retrieves the "Zero Date" (release date) for the OS update via SOFA data -->
<key>DaysDeadlinesZeroDateSOFA</key>
<true/>

<!-- Grace Period: Update is ignored until 30 days after the OS release date. -->
<key>DaysDeadlineStart</key>
<integer>30</integer>

<!-- Soft Deadline: Starts 40 days after release (30 days grace + 10 days of user prompting) -->
<key>SoftDeadlineDays</key>
<integer>40</integer> 

<!-- Hard Deadline: Mandatory update/restart 45 days after release (30 days grace + 15 days of enforcement) -->
<key>HardDeadlineDays</key>
<integer>45</integer>


<!-- ============================================= -->
<!-- 2. USER DEFERRAL CONFIGURATION -->
<!-- ============================================= -->

<!-- The maximum number of user-selected deferrals allowed (5 times) before Soft Deadline dialog appears. -->
<key>SoftDeadlineCount</key>
<integer>5</integer>

<!-- Default deferral time in seconds when the user clicks 'Defer' (24 hours = 86400 seconds) -->
<key>DefaultDeferralTimer</key>
<integer>86400</integer>

<!-- Allows the user to select from a menu of deferral times (e.g., 1hr, 4hr, 8hr, 24hr) -->
<key>DeferralTimerMenu</key>
<string>60,480,1440,10080</string>

<!-- ============================================= -->
<!-- 3. GENERAL WORKFLOW & TIMEOUT SETTINGS -->
<!-- ============================================= -->

<!-- Enables the user to be prompted for their password if the primary MDM (Jamf Pro API) update command fails. -->
<key>AllowAuthMDMFailoverToUser</key>
<true/>

<!-- This sets the relaunch delay to 1440 minutes / 24 hours after a full workflow completes with an error, ensuring the user gets a full day to contact IT. -->
<key>WorkflowRelaunchAfterFailure</key>
<string>1440</string>

<!-- Ensures the super script acts as a persistent agent, checking for updates daily -->
<key>RecheckDeferralTimer</key>
<integer>86400</integer>

<!-- Prevents the Soft Deadline dialog from automatically timing out and deferring (set to 1 year). -->
<key>DialogTimeoutSoftDeadline</key>
<integer>86400</integer>

<!-- Prevents the Hard Deadline dialog from automatically timing out and initiating a restart (set to 1 year). -->
<key>DialogTimeoutHardDeadline</key>
<integer>86400</integer>
 
<!-- Ensures the super script acts as a persistent agent autolaunch, checking for updates daily -->   
<key>StartInterval</key>
<integer>86400</integer>

<!-- Ensures the LaunchDaemon only runs the workflow check weekly (when no active update is underway), preventing daily passive pop-ups. -->
<key>DeferralTimerWorkflowRelaunch</key>
<string>10080</string>

</dict>
</plist>
```

## 4. Policy Execution and Script Parameters

The Jamf Pro policy that executes the `super` script must pass the secure credentials using encrypted parameters.

1. Add the S.U.P.E.R.M.A.N. script to the policy's **Scripts** payload.
    
2. Configure the script parameters, ensuring the values are set to **Encrypted** (or similar hidden/secure option) in Jamf Pro:

|   |   |   |    
|---|---|---|
|Parameter Slot|Option|Value / Description|
|**P4**|--auth-jamf-client|[Your API Client ID]|
|**P5**|--auth-jamf-secret|[Your API Client Secret]|
|**P6**|--workflow-install-now|starts the workflow immediately upon install|
|**P7**|--reset-super|Resets any previous configuration|
|**P8**|--test-mode|Optional to do test runs of the configured parameters|

3. Execution Frequency: Set the frequency (e.g., `Once per computer`) to ensure the script installs the LaunchDaemon and sets the credentials initially. The LaunchDaemon handles subsequent daily checks based on the `RecheckDeferralTimer` and `DeferralTimerWorkflowRelaunch` in the plist.

---

# Effective overall setup

This configuration profile is **well-balanced** and **not overly aggressive** while successfully maintaining the intent of automatic enforcement.

It provides a long, reasonable window for users before enforcement begins, and crucially, gives them ample notification and deferral options.

## ✅ Assessment: Balanced and Effective

### 1. Grace and Enforcement Period (Balanced)

|   |   |   |   |
|---|---|---|---|
|**Key**|**Value**|**Result**|**Aggressiveness**|
|DaysDeadlineStart|30 days|**Grace Period:** Users are ignored for the first 30 days after the OS is released. This is excellent for ensuring stability.|**Low**|
|SoftDeadlineDays|40 days|**User Prompting:** Users are prompted for 10 days (Day 31 to Day 40) but can defer multiple times.|**Moderate**|
|HardDeadlineDays|45 days|**Mandatory Enforcement:** The update must happen between Day 41 and Day 45. The user gets a **5-day final window**.|**Moderate**|
|**Overall Window**|45 days|**Overall:** A six-week window from release to mandatory install is very reasonable for organizational patching.|**Low/Moderate**|

### 2. User Deferral Settings (User-Friendly)

|   |   |   |   |
|---|---|---|---|
|**Key**|**Value**|**Result**|**Aggressiveness**|
|SoftDeadlineCount|5|Allows the user to defer the _start_ of the process 5 times.|**Low**|
|DefaultDeferralTimer|86400 (24 hrs)|The default deferral time is 24 hours.|**Low**|
|DeferralTimerMenu|60,480,1440,10080 (1 hr, 8 hr, 24 hr, 7 days)|Providing a 7-day deferral option is highly user-friendly and avoids panic.|**Very Low**|

### 3. Workflow and Relaunch Timers (Good Control)

|   |   |   |   |
|---|---|---|---|
|**Key**|**Value**|**Result**|**Aggressiveness**|
|RecheckDeferralTimer|86400 (24 hrs)|The system will check for updates daily. This is standard and not overly aggressive.|**Low**|
|DialogTimeoutSoftDeadline / DialogTimeoutHardDeadline|86400 (1 year)|**Crucial:** By setting this to a very high value, you prevent the script from automatically clicking 'defer' or 'restart' on the user. **The user must interact** before the deadline is hit, which is a great safety measure.|**Low**|
|DeferralTimerWorkflowRelaunch|10080 (7 days)|Ensures the LaunchDaemon only runs the workflow check weekly (when no active update is underway), preventing daily passive pop-ups.|**Low**|
|WorkflowRelaunchAfterFailure|1440 (24 hrs)|This sets the relaunch delay to **1440 minutes / 24 hours** after a full workflow completes with an error, ensuring the user gets a full day to contact IT.|**Low**|

---
