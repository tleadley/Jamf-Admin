### Overview

This script is a "Fix-It" utility designed to resolve synchronization issues between a user's local macOS account, their Login Keychain, and their Okta identity. It moves beyond simple "restart" commands by performing a **Triple-Corroboration** check to ensure all identity components are functionally healthy.

### Key Features

- **State Verification:** Confirms the local password matches the IdP via the Jamf Connect state file.
    
- **Keychain Validation:** Physically checks for the "Jamf Connect" token in the login keychain to prevent "Access Denied" loops.
    
- **Lock-Aware Execution:** Uses native `ioreg` queries to detect if the screen is locked, automatically skipping interactive tasks (like BTM resets) to avoid system errors (Error -60007).
    
- **Targeted Remediation:** Chooses between `networkcheck` or `signin` based on the specific failure point discovered.
    

---

### How the Decision Logic Works

The script evaluates the system and selects the least intrusive path for the user:

1. **Healthy (Silent):** If state, keychain, and logs are good, it runs `jamfconnect://networkcheck` to refresh the session silently.
    
2. **Missing Token (Prompt):** If the password is in sync but the keychain entry is missing, it triggers `jamfconnect://signin` enforcing re-authentication to rebuild the credential.
    
3. **Critical Desync (Force):** If a password mismatch or log error is found, it triggers `jamfconnect://signin` to force a full re-authentication.
    

---

### Prerequisites

- **Permissions:** Script must run as `root` (standard via Jamf Policy).
    
- **Dependencies:** Uses native macOS binaries (`ioreg`, `security`, `sfltool`). No Python installation required.
    
- **Assets:** Requires `jamfHelper` (standard on managed devices) and a defined Icon path (defaults to Self Service).
    

---

### Logs & Reporting

The script provides verbose output to the Jamf Policy logs, including:

- Current User identification.
    
- Success/Failure of Background Task Management (BTM) resets.
    
- Detailed status of the "Triple-Corroboration" check.
    

---

### Support & Troubleshooting

If the script reports **"Skipping BTM reset: Screen is locked"**, this is expected behavior. The script will still attempt to verify the keychain and state. If the device remains "Out of Sync" in your Extension Attributes after a run, it likely requires a manual user sign-in via the `signin` prompt
