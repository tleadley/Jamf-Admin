#!/bin/bash

#########################################################################################
# Jamf Connect & Okta "Fix-It" Tool - Corroborated Edition
#########################################################################################

# --- PREP ---
CURRENT_USER=$(stat -f "%Su" /dev/console)
USER_ID=$(id -u "$CURRENT_USER")
JAMF_HELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
ICON="/Applications/Self Service+.app/Contents/Resources/AppIcon.icns"

# Function to check if the screen is locked
is_screen_locked() {
    # Queries the I/O Kit registry for the 'CGSSessionScreenIsLocked' key
    # Returns 1 if locked, 0 if unlocked
    if ioreg -n Root -d1 | grep -C 2 'IOConsoleUsers' | grep -q 'CGSSessionScreenIsLocked'; then
        echo "1"
    else
        echo "0"
    fi
}

# Fallback icon if Self Service is missing
if [ ! -f "$ICON" ]; then
    ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns"
fi

# --- 1. DISPLAY REPAIR HUD ---
"$JAMF_HELPER" -windowType hud -title "IT Maintenance" -description "Verifying and repairing your Okta & Jamf Connect connection..." -icon "$ICON" -lockHUD &>/dev/null &
HELPER_PID=$!

echo "--- Starting Remediation for $CURRENT_USER ---"

# --- 2. CHECK TRIPLE-CORROBORATION STATE ---
echo "Checking Keychain and Sync integrity..."

# A. Jamf Connect State (1 = In Sync)
SYNC_STATE=$(sudo -u "$CURRENT_USER" defaults read com.jamf.connect.state PasswordCurrent 2>/dev/null)

# B. Check for the "Jamf Connect" Keychain Item (Exists = 0)
# We target the login keychain specifically to ensure it's accessible.
security find-generic-password -l "Jamf Connect" "/Users/$CURRENT_USER/Library/Keychains/login.keychain-db" &>/dev/null
KEYCHAIN_EXISTS=$?

# C. Scan logs for Keychain-specific errors in the last 15 minutes
LOG_ERRORS=$(log show --predicate 'subsystem == "com.jamf.connect"' --last 15m 2>/dev/null | grep -i "Keychain" | grep -E "error|fail|denied")

# --- 3. REMEDIATE BACKGROUND TASKS & PROCESSES ---
JC_BTM_BLOCK=$(sfltool dumpbtm 2>/dev/null | grep -A 15 "com.jamf.connect")
if [ "$(is_screen_locked)" == "1" ]; then
    echo "Skipping BTM reset: Screen is locked."
else
    if echo "$JC_BTM_BLOCK" | grep -q "disabled"; then
        echo "Resetting BTM..."
        /usr/bin/sfltool resetbtm &>/dev/null
    fi
fi

if ! pgrep -x "Jamf Connect" > /dev/null; then
    echo "Launching Jamf Connect..."
    sudo -u "$CURRENT_USER" open "/Applications/Jamf Connect.app"
    sleep 3
fi

# --- 4. DECISION ENGINE (The "Corroboration" Logic) ---

if [[ "$SYNC_STATE" == "1" ]] && [[ $KEYCHAIN_EXISTS -eq 0 ]] && [[ -z "$LOG_ERRORS" ]]; then
    echo "✅ Success: State, Keychain, and Logs all look healthy. Refreshing session..."
    sudo -u "$CURRENT_USER" open "jamfconnect://networkcheck"
    
elif [[ "$SYNC_STATE" == "1" ]] && [[ $KEYCHAIN_EXISTS -ne 0 ]]; then
    echo "⚠️ Warning: Passwords match but Keychain item is missing. Triggering Sign-in to recreate..."
    sudo -u "$CURRENT_USER" open "jamfconnect://signin"

else
    echo "❌ Critical: Out of sync or Keychain errors detected. Forcing full re-auth..."
    # We use verify here as it's the most robust way to force a credential check
    sudo -u "$CURRENT_USER" open "jamfconnect://signin"
fi

# --- 5. CLEANUP ---
echo "Remediation finished. Updating Inventory..."

# Kill the Jamf Helper window
if [ -n "$HELPER_PID" ] && ps -p "$HELPER_PID" > /dev/null; then
    kill $HELPER_PID 2>/dev/null
    wait $HELPER_PID 2>/dev/null
fi

# Final User Notification
/usr/local/bin/jamf displayMessage -message "Connection Check Complete. If you see a login prompt, please enter your Okta credentials to finalize the sync."

# Run recon in background
/usr/local/bin/jamf recon
