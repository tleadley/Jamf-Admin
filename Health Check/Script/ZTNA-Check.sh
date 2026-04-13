#!/bin/bash

#########################################################################################
# Jamf Connect & Okta Robust Health Check - Final "Best Practice" Edition
# Target: macOS 15 Tahoe (and newer)
# Focus: Identity, License, Connectivity, and Auth Tokens
# Usage: Run with sudo 
#########################################################################################

# --- [0] PREP & UI ---
CURRENT_USER=$(stat -f "%Su" /dev/console)
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# --- [0] SELF-ELEVATION ---
# Check if we are root. If not, try to restart with sudo.
if [ "$EUID" -ne 0 ]; then
    echo "This script requires administrative privileges. Please enter your password:"
    exec sudo "$0" "$@"
fi

echo "==============================================================="
echo "   JAMF CONNECT & OKTA INTEGRATION HEALTH CHECK"
echo "   Target User: $CURRENT_USER | Date: $(date)"
echo "==============================================================="

# --- [1] IDENTITY LAYER: OKTA CONFIG & CONNECTIVITY ---
echo -e "\n[1] IDENTITY LAYER: OKTA CONFIGURATION"

OIDC_TENANT=$(defaults read /Library/Managed\ Preferences/com.jamf.connect.login OIDCIssuer 2>/dev/null)

if [ -z "$OIDC_TENANT" ]; then
    echo -e "${RED}❌ ERROR: OIDCIssuer is MISSING.${NC}"
    echo "   Action: Deploy 'OIDCIssuer' key to com.jamf.connect.login."
else
    echo -e "${GREEN}✅ PASS: Okta Tenant found ($OIDC_TENANT).${NC}"
    
    # Robust HTTP 200 check for Okta Discovery
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$OIDC_TENANT/.well-known/openid-configuration")
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo -e "${GREEN}✅ PASS: Okta Discovery URL is reachable.${NC}"
    else
        echo -e "${RED}❌ ERROR: Okta unreachable. Status: $HTTP_STATUS.${NC}"
        echo "   Check: DNS, Firewall, or Zscaler status."
    fi
fi

# --- [2] LICENSE LAYER: DEEP SCAN ---
echo -e "\n[2] LICENSE LAYER: VERIFICATION"

# Search across all possible domains and key names
LICENSE_DATA=$(defaults read /Library/Managed\ Preferences/com.jamf.connect LicenseFile 2>/dev/null \
    || defaults read /Library/Managed\ Preferences/com.jamf.connect.login LicenseFile 2>/dev/null \
    || defaults read /Library/Managed\ Preferences/com.jamf.connect License 2>/dev/null)

LOCAL_LICENSE="/Users/$CURRENT_USER/Library/Application Support/com.jamf.connect/license.plist"

if [ -n "$LICENSE_DATA" ]; then
    echo -e "${GREEN}✅ PASS: Jamf Connect is Licensed via MDM.${NC}"
elif [ -f "$LOCAL_LICENSE" ]; then
    echo -e "${GREEN}✅ PASS: Jamf Connect Licensed (found in local cache).${NC}"
else
    echo -e "${RED}❌ ERROR: License not found. App may expire or show Trial banner.${NC}"
fi

# --- [3] TRUST LAYER: AUTHENTICATION TOKEN CHECK ---
echo -e "\n[3] TRUST LAYER: AUTHENTICATION STATUS"

# Security check for the Keychain item (Most reliable proof of sign-in)
TOKEN_CHECK=$(sudo -u "$CURRENT_USER" security find-generic-password -l "Jamf Connect" 2>/dev/null)

if [ -n "$TOKEN_CHECK" ]; then
    echo -e "${GREEN}✅ PASS: Okta Auth Tokens found in Keychain.${NC}"
else
    echo -e "${RED}❌ ERROR: No Auth Tokens found.${NC}"
    echo "   Fix: Open Jamf Connect menu bar and 'Sign In' to Okta."
fi

# --- [4] SOFTWARE LAYER: MacOS BACKGROUND PERMISSIONS ---
echo -e "\n[4] SYSTEM LAYER: MacOS BACKGROUND TASKS"

# Check for Jamf/Self Service+ processes
if pgrep -x "Jamf Connect" > /dev/null || pgrep -f "Self Service+" > /dev/null; then
    echo -e "${GREEN}✅ PASS: Jamf Identity Agent is running.${NC}"
else
    echo -e "${RED}❌ ERROR: Jamf Connect process NOT found.${NC}"
fi

# 2. SFLTOOL Check (Refined for Tahoe)
# We look for the Jamf identifiers and check if the 'disposition' is 'disabled'
BGO_DUMP=$(sfltool dumpbtm 2>/dev/null)
# Search specifically for Jamf Connect and Jamf Trust identifiers
JC_DISABLED=$(echo "$BGO_DUMP" | grep -A 5 "com.jamf.connect" | grep -i "Disabled")
TRUST_DISABLED=$(echo "$BGO_DUMP" | grep -A 5 "com.jamf.trust" | grep -i "Disabled")

if [ -n "$JC_DISABLED" ] || [ -n "$TRUST_DISABLED" ]; then
    echo -e "${RED}❌ ERROR: Jamf tasks appear to be DISABLED in Login Items.${NC}"
else
    # Double check: if it's managed by MDM, sfltool might not show "Disabled" 
    # but the background item will exist.
    if echo "$BGO_DUMP" | grep -q "JAMF Software"; then
        echo -e "${GREEN}✅ PASS: Jamf background tasks are registered and permitted.${NC}"
    else
        echo -e "⚠️  WARN: Jamf background tasks not found in BTM database.${NC}"
    fi
fi

echo -e "\n==============================================================="
echo "   HEALTH CHECK COMPLETE"
echo "==============================================================="
