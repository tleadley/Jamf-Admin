#!/bin/bash
: HEADER = <<'EOL'

██████╗ ██╗ ██████╗ ██╗████████╗ █████╗ ██╗          ██████╗ ██████╗ ███╗   ██╗██╗   ██╗███████╗██████╗  ██████╗ ███████╗███╗   ██╗ ██████╗███████╗
██╔══██╗██║██╔════╝ ██║╚══██╔══╝██╔══██╗██║         ██╔════╝██╔═══██╗████╗  ██║██║   ██║██╔════╝██╔══██╗██╔════╝ ██╔════╝████╗  ██║██╔════╝██╔════╝
██║  ██║██║██║  ███╗██║   ██║   ███████║██║         ██║     ██║   ██║██╔██╗ ██║██║   ██║█████╗  ██████╔╝██║  ███╗█████╗  ██╔██╗ ██║██║     █████╗
██║  ██║██║██║   ██║██║   ██║   ██╔══██║██║         ██║     ██║   ██║██║╚██╗██║╚██╗ ██╔╝██╔══╝  ██╔══██╗██║   ██║██╔══╝  ██║╚██╗██║██║     ██╔══╝
██████╔╝██║╚██████╔╝██║   ██║   ██║  ██║███████╗    ╚██████╗╚██████╔╝██║ ╚████║ ╚████╔╝ ███████╗██║  ██║╚██████╔╝███████╗██║ ╚████║╚██████╗███████╗
╚═════╝ ╚═╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝


       DESCRIPTION: This script retrieves password expiry in days, this allows for the update of user passwords within compliance and to sync them with 
                    Okta and Jamf Connect. Built in MacOS file associated with password expiry becomes corrupt, this is a workaround.
         FREQUENCY: This script to to be run once a day if password expiry EA is empty
      REQUIREMENTS:
                    Jamf Pro
                    macOS Clients running version 10.13 or later

          FEATURES: API interface and user confirmation
        Written by: Trevor Leadley | Digital Convergence
  Revision History:
        YYYY-MM-DD: Details
        2025-07-31: Created script

 For more information, visit https://github.com/digitalconvergenceca/Mac_Admin_Jamf/tree/main/Scripts


EOL
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# --- Configuration ---

# Your Jamf Pro server URL (e.g., https://yourjamfpro.jamfcloud.com)
JAMF_PRO_URL="$4"
JAMF_API_USER="$5"
USER_PASS_ENC="$6"
PW_SALT="$7"
PW_PASS_KEY="$8"

OKTA_ORG_URL="https://digitalconvergence.okta.com" # Replace with your Okta domain
OKTA_API_TOKEN="$9"   # Replace with your Okta API Token
USER_ID=""         # Replace with the actual Okta User ID

# Local user and computer details
CURRENT_USER=$( ls -l /dev/console | awk '{print $3}' )
SERIAL_NUMBER=$( system_profiler SPHardwareDataType | awk '/Serial/ {print $4}' )
GUDID=$(system_profiler SPHardwareDataType | grep UUID | awk '{print $3}')

# Log file for debugging (optional)
LOG_FILE="/var/log/get_expiry.log"

# Function to convert ISO 8601 to Unix Timestamp
iso_to_unix_timestamp() {
    local iso_datetime="$1"
    local unix_timestamp

    # Remove the 'Z' (Zulu time/UTC) if present, as it can sometimes cause issues
    # and we're converting to local system time or assuming UTC-awareness in date command.
    # The 'date' command usually handles 'Z' implicitly or converts to local time if not specified.
    # For simplicity, we'll strip it if present as it's often the same as +0000.
    local clean_datetime="${iso_datetime%Z}"

    # Try GNU date first (common on Linux, installable on macOS via coreutils)
    if command -v gdate &> /dev/null; then
        unix_timestamp=$(gdate -d "$clean_datetime" +%s 2>/dev/null)
    # Try macOS/BSD date
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS date -j -f format_string input_string +output_format
        # ISO 8601 example: 2025-07-18T14:30:00.000Z
        # Format string needs to match closely: "%Y-%m-%dT%H:%M:%S"
        # We might need to handle milliseconds if they cause issues, but often ignored for %s
        unix_timestamp=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$clean_datetime" | cut -d'.' -f1)" +%s 2>/dev/null)
    else
        # Fallback to standard 'date' (often GNU date on Linux, less robust without -d on BSD)
        unix_timestamp=$(date -d "$clean_datetime" +%s 2>/dev/null)
    fi

    echo "$unix_timestamp"
}

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${LOG_FILE}"
}

# Function to show how many days till the password expires
get_expiry() {

local timestamp="$1"
#Get Day the password was last changed
#LocalDate=$(dscl . -read /Users/$CURRENT_USER accountPolicyData | tail -n +2 | plutil -extract passwordLastSetTime xml1 -o - -- - | sed -n "s/<real>\([0-9]*\).*/\1/p")

#Get today's date
datum=$(date "+%s")

#Calculate how many days since the last password change
diff=$(($datum-$timestamp))

#Convert time code to a readable number
days=$((60-$diff/(60*60*24)))
echo "$days"

}

# Function to login to the Jamf API
api_authentication() {

# User password encrypted
USER_PASS_DEC=$( echo "$USER_PASS_ENC" | /usr/bin/openssl enc -aes256 -d -a -A -S "$PW_SALT" -k "$PW_PASS_KEY" )

#set encoded username:password
API_AUTH="$JAMF_API_USER:$USER_PASS_DEC"

AUTH_RESPONSE=$( /usr/bin/curl --request POST --silent --url "$JAMF_PRO_URL/api/v1/auth/token" --user "$API_AUTH" )
# echo $AUTH_TOKEN
AUTH_TOKEN=$( /usr/bin/plutil -extract token raw - <<< "$AUTH_RESPONSE" )

}
# function to invalidate Jamf API token
invalidate_token() {

# Invalidate the Jamf API Authentication Token
/usr/bin/curl --header "Authorization: Bearer "${AUTH_TOKEN}"" --request POST --silent --url ""${JAMF_PRO_URL}"/api/v1/auth/invalidate-token"

}

# Function to gather the eamil address of the user from JAmf Pro API
get_user_email() {
# Build the Jamf Hardware inquery to lookup the device ID for the current device
JAMF_QUERY="$JAMF_PRO_URL/api/v1/computers-inventory?section=HARDWARE&page=0&page-size=100&filter=hardware.serialNumber=="${SERIAL_NUMBER}""

# extract the device ID from the Jamf API
COMPUTER_INFO=$( /usr/bin/curl -s -X GET "$JAMF_QUERY" -H "Authorization: Bearer ${AUTH_TOKEN}" -H "Accept: application/json" | jq '.results[] | {id}' | jq -r '.id' )

# Get inventory details from the hardware ID, and isolate the email address associated with assigned ID
USER_INFO=$( /usr/bin/curl -s -X GET "$JAMF_PRO_URL/api/v1/computers-inventory-detail/${COMPUTER_INFO}" -H "Authorization: Bearer ${AUTH_TOKEN}" -H "Accept: application/json" | jq -r '.userAndLocation.email' )

}

# --- Function to get okta user id ---
get_user_id_by_login() {
    local user_login="$1"
    local SEARCH_RESPONSE=""
    log_message "Attempting to find user ID for login: $user_login..."
    URL_QUERY="${OKTA_ORG_URL}/api/v1/users?filter=profile.email%20eq%20%22${user_login}%22"
    # Make the API call to search for the user
    # -G: Sends data as a GET request with parameters appended to the URL
    # --data-urlencode: URL-encodes the query parameter to handle special characters
    SEARCH_RESPONSE=$(/usr/bin/curl -sS -X GET \
                       -H "Accept: application/json" \
                       -H "Content-Type: application/json" \
                       -H "Authorization: SSWS $OKTA_API_TOKEN" \
                      "${URL_QUERY}" 2>&1)
    CURL_EXIT_CODE=$?

    if [ $CURL_EXIT_CODE -ne 0 ]; then
        log_message "Error: curl command failed during user lookup with exit code $CURL_EXIT_CODE."
        log_message "Curl Error Message: $SEARCH_RESPONSE"
        return 1
    fi

    # Check if the response is valid JSON and contains an errorCode
    if echo "$SEARCH_RESPONSE" | jq -e '.errorCode' >/dev/null 2>&1; then
        ERROR_CODE=$(echo "$SEARCH_RESPONSE" | jq -r '.errorCode')
        ERROR_SUMMARY=$(echo "$SEARCH_RESPONSE" | jq -r '.errorSummary')
        log_message "Okta API Error during user lookup: $ERROR_CODE - $ERROR_SUMMARY"
        return 1
    fi

    # Extract the user ID from the response.
    # We expect an array of users, and we take the 'id' of the first user found.
    OKTA_USER_ID=$(echo "$SEARCH_RESPONSE" | jq -r '.[] | .id' | head -n 1)

    if [ -z "$OKTA_USER_ID" ]; then
        log_message "Error: User with login '$user_login' not found in Okta or no ID returned."
        return 1
    else
        log_message "Found user ID: $OKTA_USER_ID for login: $user_login."
        echo "$OKTA_USER_ID" # Output the user ID for the caller
        return 0
    fi
}

update_ea(){ # syntax :- update_ea $eaID $eaName $eaValue

# set EA ID
eaID="$1" # Extended Attribute ID Number we wish to update or retrieve
# set EA Name
eaName="$2" # Name of Extended Attribute in Jamf Pro
eavalue="$3" # set desired EA value in this case clear the value

# Submit unmanage payload to the Jamf Pro Server
curl -k -s --header "Authorization: Bearer ${AUTH_TOKEN}" -X "PUT" "${JAMF_PRO_URL}/JSSResource/computers/udid/${GUDID}/subset/extension_attributes" \
      -H "Content-Type: application/xml" -H "Accept: application/xml" \
      -d "<computer><extension_attributes><extension_attribute><id>$eaID</id><name>$eaName</name><type>String</type><value>$eavalue</value></extension_attribute></extension_attributes></computer>"

}

# Get the last time a password was updated in Okta
last_password_update (){

# The endpoint to retrieve a user's details
API_ENDPOINT="${OKTA_ORG_URL}/api/v1/users/${USER_ID}"

log_message "Fetching user details for ID: ${USER_ID}..."

response=$(curl -s -X GET \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "Authorization: SSWS ${OKTA_API_TOKEN}" \
  "${API_ENDPOINT}")

# --- Process Response ---
# Check for common API errors first
if echo "${response}" | grep -q '"errorCode"'; then
  log_message "Error retrieving user details from Okta:"
  log_message "${response}" | jq . # Use jq for pretty printing JSON
  exit 1
fi
}

# --- Main execution ---
defaults read /var/db/dslocal/nodes/Default/users/$CURRENT_USER.plist > /dev/null 2>&1

api_authentication

get_user_email

USER_ID=$(get_user_id_by_login "${USER_INFO}")

last_password_update

LAST_PASSWORD_CHANGE_DATETIME=$(echo "${response}" | jq -r '.passwordChanged')
TIMESTAMP=$(iso_to_unix_timestamp "$LAST_PASSWORD_CHANGE_DATETIME")

if [ -z "$LAST_PASSWORD_CHANGE_DATETIME" ] || [ "$LAST_PASSWORD_CHANGE_DATETIME" == "null" ]; then
  log_message "Could not find 'passwordChanged' information for user ID: ${CURRENT_USER}."
  log_message "This might mean the password has never been changed since the account was created or is managed externally (e.g., via AD/LDAP)."
else
  log_message "Last password change for user ID ${CURRENT_USER}:"
  log_message "Full Timestamp: ${LAST_PASSWORD_CHANGE_DATETIME}"

  # You can further format this if needed, e.g., to just the date
  # Extract just the date part (YYYY-MM-DD)
  LAST_PASSWORD_CHANGE_DATE=$(echo "$LAST_PASSWORD_CHANGE_DATETIME" | cut -d'T' -f1)
  log_message "Date (YYYY-MM-DD): ${LAST_PASSWORD_CHANGE_DATE}"
  log_message "Okta Expiry : $(get_expiry "$TIMESTAMP") Days"

  days_exp=$(get_expiry "$TIMESTAMP")

fi

update_ea "27" "Jamf Connect Password - Expiration in days" $days_exp

invalidate_token

exit 0
