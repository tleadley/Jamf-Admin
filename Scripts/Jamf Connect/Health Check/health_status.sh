#!/bin/bash

#########################################################################################
# Jamf Connect & Okta Health EA (V2 - Tahoe Optimized)
# Returns a summary of the device health for Jamf Pro reporting.
#########################################################################################

# --- PREP ---
LOG_PATH="/Library/Application Support/Digital Convergence/ea_history.csv"
LOG_DIR=$(dirname "$LOG_PATH")

CURRENT_USER=$(stat -f "%Su" /dev/console)

[ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"

# 1. Check Identity (OIDC Tenant & Connectivity)
OIDC_TENANT=$(/usr/libexec/PlistBuddy -c "Print :OIDCIssuer" /Library/Managed\ Preferences/com.jamf.connect.login.plist 2>/dev/null)

if [ -z "$OIDC_TENANT" ]; then
    HEALTH_STATUS="Missing Config"
else
    MAX_ATTEMPTS=6
    for (( i=1; i<=$MAX_ATTEMPTS; i++ )); do
        # We check for the tunnel first
        TUNNEL_COUNT=$(ifconfig -a | grep -c "utun")
        
        if [ "$TUNNEL_COUNT" -eq 0 ]; then
            # Jamf Trust isn't up yet. Don't even try to reach Okta.
            # Just wait 5 seconds and check again.
            sleep 5
            continue 
        fi

        # If we are here, a tunnel is present. Now we test the actual traffic flow.
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$OIDC_TENANT/.well-known/openid-configuration")

        if [ "$HTTP_STATUS" -eq 200 ]; then
            CONNECTION_SUCCESS="true"
            break
        fi

        sleep 5
    done

    if [ "$CONNECTION_SUCCESS" != "true" ]; then
        HEALTH_STATUS="Okta Unreachable ($HTTP_STATUS)"
    fi
fi
# 2. Check Background Task Permissions (Tahoe Specific)
if [ -z "$HEALTH_STATUS" ]; then
    BGO_DUMP=$(sfltool dumpbtm 2>/dev/null)
    # Check if the primary daemon is disabled by user/developer
    JC_STATUS=$(echo "$BGO_DUMP" | grep -A 15 "16.com.jamf.connect.daemon" | grep "disposition" | awk '{print $2}')
    
    if [[ "$JC_STATUS" == *"disabled"* ]] || [[ "$JC_STATUS" == "2" ]] || [[ "$JC_STATUS" == "3" ]]; then
        HEALTH_STATUS="Background Tasks Disabled"
    fi
fi

# 3. Check License
if [ -z "$HEALTH_STATUS" ]; then
    # 1. Check the primary License key first
    LICENSE_DATA=$(defaults read /Library/Managed\ Preferences/com.jamf.connect LicenseFile 2>/dev/null)

    # 2. Fallback: Check for the local plist file ONLY if the MDM key is missing
    if [ -z "$LICENSE_DATA" ]; then
        if [ -n "$CURRENT_USER" ] && [ -f "/Users/$CURRENT_USER/Library/Application Support/com.jamf.connect/license.plist" ]; then
            LICENSE_DATA="Local File Found"
        fi
    fi

    # 3. Final verification
    if [ -z "$LICENSE_DATA" ]; then
        HEALTH_STATUS="Missing License"
    fi
fi

# 4. Check Processes
if [ -z "$HEALTH_STATUS" ]; then
    if ! pgrep -x "Jamf Connect" > /dev/null && ! pgrep -f "Self Service+" > /dev/null; then
        HEALTH_STATUS="App Not Running"
    fi
fi

# 5. Check Authentication (State & Keychain Corroboration)
if [ -z "$HEALTH_STATUS" ]; then
    # A. Check if IdP and Local passwords match (1 = True)
    SYNC_STATE=$(sudo -u "$CURRENT_USER" defaults read com.jamf.connect.state PasswordCurrent 2>/dev/null)
    
    # B. Check for the "Jamf Connect" Keychain Item
    # We target the user's login keychain database directly for accuracy
    security find-generic-password -l "Jamf Connect" "/Users/$CURRENT_USER/Library/Keychains/login.keychain-db" &>/dev/null
    KEYCHAIN_EXISTS=$?

    if [[ "$SYNC_STATE" != "1" ]]; then
        HEALTH_STATUS="Passwords Out of Sync"
    elif [[ $KEYCHAIN_EXISTS -ne 0 ]]; then
        HEALTH_STATUS="Keychain Item Missing"
    fi
fi

# --- LOGGING ---
[ -z "$HEALTH_STATUS" ] && HEALTH_STATUS="Healthy"

LAST_ENTRY=$(tail -n 1 "$LOG_PATH" 2>/dev/null | awk -F " | " '{print $NF}')
TIMESTAMP=$(date "+%Y-%m-%d %H:%M")

# Only log if status has changed to keep the log concise
if [ "$HEALTH_STATUS" != "$LAST_ENTRY" ]; then
    echo "JC Health | $TIMESTAMP | $HEALTH_STATUS" >> "$LOG_PATH"
fi

# Keep local file to 50 lines max
echo "$(tail -n 50 "$LOG_PATH")" > "$LOG_PATH"

# --- FINAL OUTPUT ---
if [ -z "$HEALTH_STATUS" ]; then
    echo "<result>Healthy</result>"
else
    echo "<result>$HEALTH_STATUS</result>"
fi
