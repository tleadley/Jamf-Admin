#!/bin/bash
: HEADER = <<'EOL'

██████╗ ██╗ ██████╗ ██╗████████╗ █████╗ ██╗          ██████╗ ██████╗ ███╗   ██╗██╗   ██╗███████╗██████╗  ██████╗ ███████╗███╗   ██╗ ██████╗███████╗
██╔══██╗██║██╔════╝ ██║╚══██╔══╝██╔══██╗██║         ██╔════╝██╔═══██╗████╗  ██║██║   ██║██╔════╝██╔══██╗██╔════╝ ██╔════╝████╗  ██║██╔════╝██╔════╝
██║  ██║██║██║  ███╗██║   ██║   ███████║██║         ██║     ██║   ██║██╔██╗ ██║██║   ██║█████╗  ██████╔╝██║  ███╗█████╗  ██╔██╗ ██║██║     █████╗
██║  ██║██║██║   ██║██║   ██║   ██╔══██║██║         ██║     ██║   ██║██║╚██╗██║╚██╗ ██╔╝██╔══╝  ██╔══██╗██║   ██║██╔══╝  ██║╚██╗██║██║     ██╔══╝
██████╔╝██║╚██████╔╝██║   ██║   ██║  ██║███████╗    ╚██████╗╚██████╔╝██║ ╚████║ ╚████╔╝ ███████╗██║  ██║╚██████╔╝███████╗██║ ╚████║╚██████╗███████╗
╚═════╝ ╚═╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝


       DESCRIPTION: This script allows for thr easy update of user passwords and to sync them with Okta and Jamf Connect

      REQUIREMENTS:
                    Jamf Pro
                    macOS Clients running version 10.13 or later

          FEATURES:
        Written by: Trevor Leadley | Digital Convergence
  Revision History:
        YYYY-MM-DD: Details
        2025-06-11: Created script
        2025-06-11: Updated header and description

 For more information, visit https://github.com/digitalconvergenceca/Mac_Admin_Jamf/tree/main/Scripts


EOL
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# SwiftDialog Path (adjust if needed)
DIALOG="/usr/local/bin/dialog"

# Log file for debugging (optional)
LOG_FILE="/var/log/swift_password_update.log"

# Your Jamf Pro server URL (e.g., https://yourjamfpro.jamfcloud.com)
JAMF_PRO_URL="$4"
JAMF_API_USER="$5"
USER_PASS_ENC="$6"
PW_SALT="$7"
PW_PASS_KEY="$8"

# Okta Organization Url
OKTA_ORG_URL="https://digitalconvergence.okta.com" # Replace with your Okta domain $9
OKTA_API_TOKEN="$9" # Set this or export key $10

# Local user and computer details
CURRENT_USER=$( ls -l /dev/console | awk '{print $3}' )
SERIAL_NUMBER=$( system_profiler SPHardwareDataType | awk '/Serial/ {print $4}' )
USER_ID=""

# Password Requirements
MIN_LENGTH=15
REQUIRE_UPPER=1
REQUIRE_LOWER=1
REQUIRE_NUMBER=1
REQUIRE_SPECIAL=1

#Swift Dialogue version expecetd
SD_VERSION=$( ${DIALOG} --version)
MIN_SD_REQUIRED_VERSION="2.3.3"

# Backtick '`' does not need escaping when double-quoted.
SPECIAL_CHARS_ARRAY=(
    "!" "@" "#" "$" "%" "^" "&" "*" "(" ")" "_" "+" "-" "="
    "[" "]" "{" "}" "|" ";" ":" "'" "\"" "," "." "<" ">" "/"
    "?" "$(printf '\x60')" "~" "\\"
)

# For the message displayed to the user, you can easily reconstruct the string:
SPECIAL_CHARS_STRING=$(IFS=''; echo "${SPECIAL_CHARS_ARRAY[*]}")

# Function to convert a string to its hexadecimal representation
# This ensures we're comparing raw bytes.
string_to_hex() {

    echo -n "$1" | od -tx1 | head -n1 | cut -d' ' -f2- | tr -d ' \n'

}
# Debug hex output of entered characters
# echo "--- Debugging Special Characters and Password Input ---" >> "${LOG_FILE}"
# echo "Hex dump of SPECIAL_CHARS:" >> "${LOG_FILE}"
# echo -n "$SPECIAL_CHARS" | od -xc >> "${LOG_FILE}" # od -xc gives hex and char
# echo "---------------------------------------------------" >> "${LOG_FILE}"

# Function to show how many days till the password expires
get_expiry(){

defaults read /var/db/dslocal/nodes/Default/users/$CURRENT_USER.plist > /dev/null 2>&1

    # Check if CURRENT_USER is set
    if [ -z "$CURRENT_USER" ]; then
        log_message "Error: CURRENT_USER is not set. Please set the CURRENT_USER variable before calling get_expiry." >&2
        return 1
    fi

    # Get the day the password was last changed
    # We'll use a subshell to capture stderr and check the exit code
    if ! LocalDate=$(dscl . -read /Users/"$CURRENT_USER" accountPolicyData 2>/dev/null | tail -n +2 | plutil -extract passwordLastSetTime xml1 -o - -- - 2>/dev/null | sed -n "s/<real>\([0-9]*\).*/\1/p"); then
        log_message "Error: Could not retrieve password last set time for user '$CURRENT_USER'." >&2
        log_message "Please ensure the user exists and you have appropriate permissions." >&2
        return 1
    fi

    # Check if LocalDate is empty, which means extraction might have failed silently
    if [ -z "$LocalDate" ]; then
        log_message "Error: Password last set time was empty or could not be extracted for user '$CURRENT_USER'." >&2
        return 1
    fi

    # Get today's date (Unix timestamp)
    datum=$(date "+%s")

    # Calculate how many days since the last password change
    # Ensure LocalDate is a valid number before performing arithmetic
    if ! [[ "$LocalDate" =~ ^[0-9]+$ ]]; then
        log_message "Error: Invalid 'passwordLastSetTime' format retrieved: '$LocalDate'." >&2
        return 1
    fi
    # echo "Password Last Set (Unix TS):         ${LocalDate}"
    #Get today's date
    datum=$(date "+%s")
    # echo "Current Unix Timestamp:              ${datum}"
    #Calculate how many days since the last password change
    diff=$(($datum-$LocalDate))

    #Convert time code to a readable number
    days=$((60-$diff/(60*60*24)))

}
# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${LOG_FILE}"
}
# Returns 0 (true) if current_version is >= required_version, 1 (false) otherwise.
is_at_least() {
    local required_version="$1"
    local current_version="$2"

    # Split versions into arrays based on '.'
    IFS='.' read -r -a required_parts <<< "$required_version"
    IFS='.' read -r -a current_parts <<< "$current_version"

    # Get the maximum number of parts to compare
    local max_parts=${#required_parts[@]}
    if (( ${#current_parts[@]} > max_parts )); then
        max_parts=${#current_parts[@]}
    fi

    for (( i=0; i<max_parts; i++ )); do
        # Get numerical value for each part, default to 0 if part is missing
        local r_part=${required_parts[i]:-0}
        local c_part=${current_parts[i]:-0}

        if (( c_part < r_part )); then
            return 1 # Current is less than required
        elif (( c_part > r_part )); then
            return 0 # Current is greater than required
        fi
        # If parts are equal, continue to the next part
    done

    return 0 # All parts were equal, so current is equal to required
}
# Function to check for swift dialogue
function check_swift_dialog_install ()
{
    # Check to make sure that Swift Dialog is installed and functioning correctly
    # Will install process if missing or corrupted
    #
    # RETURN: None
	# VARIABLES expected: SD_VERSION & MIN_SD_REQUIRED_VERSION must be set first
	# PARMS Passed: none

    log_message "Ensuring that swiftDialog is installed and up to date..."
    if [[ ! -x "/usr/local/bin/dialog" ]]; then
        log_message "Swift Dialog is missing or corrupted - Installing from JAMF"
        install_swift_dialog
    fi
    DIALOGUE_CHECK=$(is_at_least "${MIN_SD_REQUIRED_VERSION}" "${SD_VERSION}")
    DIALOGUE_CHECK=$?
    
    if [ $DIALOGUE_CHECK -eq 0 ]; then
        log_message "Installed version ${SD_VERSION} is newer than or equal to the required version ${MIN_SD_REQUIRED_VERSION}. Continuing..."
    else
        log_message "Swift Dialog is outdated - Installing version '${MIN_SD_REQUIRED_VERSION}' from JAMF..."
        install_swift_dialog
    fi
}

# Install function for swift dialogue
function install_swift_dialog ()
{
    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    log_message "Installing swiftDialog..."

    # Create temporary working directory
    workDirectory=$( /usr/bin/basename "$0" )
    tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

    # Download the installer package
    /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"

    # Verify the download
    teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

    # Install the package if Team ID validates
    if [[ "$expectedDialogTeamID" == "$teamID" ]]; then

        /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
        sleep 2
        dialogVersion=$( /usr/local/bin/dialog --version )
        log_message "swiftDialog version ${dialogVersion} installed; proceeding..."

    else

        # Display a so-called "simple" dialog if Team ID fails to validate
        osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Error" buttons {"Close"} with icon caution'
        quitScript

    fi

    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"
}
# Function to login to the Jamf API
api_authentication()
{

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

# Function to display SwiftDialog with a message and exit
show_dialog_and_exit() {
    local title="$1"
    local message="$2"
    local icon="$3"
    local exit_code="${4:-0}" # Default exit code to 0

    "${DIALOG}" \
        --title "${title}" \
        --message "${message}" \
        --icon "${icon}" \
        --button1text "OK" \
        --size small \
        --ontop \
        --centericon \
        --commandfile /var/tmp/dialog_command.log # A dummy command file, not strictly needed for just a message

    log_message "Dialog displayed: Title='${title}', Message='${message}', Icon='${icon}', Exited with code ${exit_code}"
    exit "${exit_code}"
}

# Function to validate password complexity
validate_password_complexity() {
    local password="$1"
    local errors=""

    # echo "DEBUG: Checking password: '$password'" >> "${LOG_FILE}"
    # echo "DEBUG: Password length: ${#password}, Min length: ${MIN_LENGTH}" >> "${LOG_FILE}"

    if [[ ${#password} -lt ${MIN_LENGTH} ]]; then
        errors+="• Must be at least ${MIN_LENGTH} characters long.\n"
        echo "DEBUG: Failed: Length" >> "${LOG_FILE}"
    fi
    if [[ ${REQUIRE_UPPER} -eq 1 && ! "$password" =~ [A-Z] ]]; then
        errors+="• Must contain at least one uppercase letter.\n"
        echo "DEBUG: Failed: Uppercase" >> "${LOG_FILE}"
    fi
    if [[ ${REQUIRE_LOWER} -eq 1 && ! "$password" =~ [a-z] ]]; then
        errors+="• Must contain at least one lowercase letter.\n"
        echo "DEBUG: Failed: Lowercase" >> "${LOG_FILE}"
    fi
    if [[ ${REQUIRE_NUMBER} -eq 1 && ! "$password" =~ [0-9] ]]; then
        errors+="• Must contain at least one number.\n"
        echo "DEBUG: Failed: Number" >> "${LOG_FILE}"
    fi

if [[ ${REQUIRE_SPECIAL} -eq 1 ]]; then
        local found_special=false
        local i
        local char
        local array_char # To hold character from special chars array

        log_message "DEBUG: Iterating through password characters for special check (ARRAY-BASED):" >> "${LOG_FILE}"
        for (( i=0; i<${#password}; i++ )); do
            char="${password:$i:1}"
             # echo "  DEBUG: Checking password char: '$char'" >> "${LOG_FILE}"

            # Loop through the SPECIAL_CHARS_ARRAY to see if the current password char matches any special char
            for array_char in "${SPECIAL_CHARS_ARRAY[@]}"; do
                if [[ "$char" == "$array_char" ]]; then
                    found_special=true
                    # echo "  DEBUG: Match found for char: '$char' (Matched: '$array_char')!" >> "${LOG_FILE}"
                    break 2 # Break both inner and outer loops
                fi
            done
        done

        if ! $found_special; then
            errors+="• Must contain at least one special character (${SPECIAL_CHARS_STRING}).\n"
            log_message "DEBUG: Failed: Special Character (ARRAY-BASED check found no match)" >> "${LOG_FILE}"
        else
            log_message "DEBUG: Passed: Special Character (ARRAY-BASED check found a match)" >> "${LOG_FILE}"
        fi
    fi

    log_message "DEBUG: Returning errors: '$errors'" >> "${LOG_FILE}"
    echo "$errors"
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

# --- Function to update password ---
# This function now expects a user_id, not a login, for the API call.
update_password() {

    local old_password="$1"
    local new_password="$2"
    local okta_errors=""
    
    log_message "Attempting to update password for user ID: $USER_ID..."

    API_ENDPOINT="${OKTA_ORG_URL}/api/v1/users/${USER_ID}/credentials/change_password"
    log_message $API_ENDPOINT
    # Construct the JSON payload
    PAYLOAD=$(jq -n \
              --arg old_pass "$old_password" \
              --arg new_pass "$new_password" \
              '{
                "oldPassword": { "value": $old_pass },
                "newPassword": { "value": $new_pass },
                "revokeSessions": false
              }')

    # Make the API call using curl
    RESPONSE=$(/usr/bin/curl -sS -X POST \
                    -H "Content-Type: application/json" \
                    -H "Authorization: SSWS ${OKTA_API_TOKEN}" \
                    -d "$PAYLOAD" \
                    "${API_ENDPOINT}" 2>&1)

    CURL_EXIT_CODE=$?
    # Debug payload outpuT
    # log_message "$PAYLOAD"
    # --- Error Trapping and Handling ---
    if [ $CURL_EXIT_CODE -ne 0 ]; then
        log_message "Error: curl command failed with exit code $CURL_EXIT_CODE."
        log_message "Curl Error Message: $RESPONSE"
        log_message "Please check network connectivity, Okta Org URL, and API token validity."
        return 1
    fi

    # Check if the response is valid JSON and contains an errorCode
    if echo "$RESPONSE" | jq -e '.errorCode' >/dev/null 2>&1; then
        # This is an Okta API error response
        ERROR_CODE=$(echo "$RESPONSE" | jq -r '.errorCode')
        ERROR_SUMMARY=$(echo "$RESPONSE" | jq -r '.errorSummary')
        ERROR_ID=$(echo "$RESPONSE" | jq -r '.errorId')
        ERROR_CAUSES=$(echo "$RESPONSE" | jq -r '.errorCauses[].errorSummary // empty')

        log_message "Okta API Error: $ERROR_CODE - $ERROR_SUMMARY"
        if [ -n "$ERROR_CAUSES" ]; then
            log_message "Details:"
            log_message "$ERROR_CAUSES" | while read -r cause; do
                log_message "  - $cause"
            done
        fi

        case "$ERROR_CODE" in
            "E0000001")
                log_message "Action: API validadtion. new password value."
                ;;
            "E0000003")
                log_message "Action: Malformed request. Check your JSON payload and input parameters."
                ;;
            "E0000004")
                log_message "Action: Authentication failed. Verify your Okta API token and its permissions."
                ;;
            "E0000011") # New error code for user not found
                log_message "Action: User not found. The user ID provided does not exist or is invalid."
                log_message "        Ensure the user login provided as input is correct and exists in Okta."
                ;;
            "E0000014"|"E0000080")
                log_message "Action: Password policy violation. The new password does not meet Okta's requirements."
                log_message "        Review Okta's password policy for this user's group."
		
                ;;
            "E0000069")
                log_message "Action: User account is locked out. An administrator needs to unlock the account."
                ;;
            *)
                log_message "Action: Unrecognized Okta error code. Consult Okta documentation or contact support."
                ;;
        esac
	    log_message "$RESPONSE"
	    echo "$ERROR_CODE"
        return 1 # Indicate failure
    else
        # Success (or an unexpected non-JSON response, but Okta usually sends JSON)
        if [ -z "$RESPONSE" ]; then
            log_message "Password might have been updated, but inspect the response for user login: $CURRENT_USER."
            return 0 # Indicate success
        else
	# Expected respones {"password": { },"provider": {"type": "OKTA","name": "OKTA"}}
            log_message "$RESPONSE"
            log_message "Password updated successfully for user login: $CURRENT_USER."
            return 0 # Assume success for now, but log for inspection
        fi
    fi

}
# Main script logic
# autoload 'is-at-least'
# Check if SwiftDialog is installed
check_swift_dialog_install 

log_message "Script started for user: ${CURRENT_USER}"

api_authentication

get_expiry

get_user_email

log_message "User Account: $USER_INFO" >> "${LOG_FILE}"
log_message "Password expires in $days days" >> "${LOG_FILE}"

# --- Input Validation ---
if [ -z "$OKTA_ORG_URL" ]; then
    log_message "Error: OKTA_ORG_URL is not set. Please set it in the script or as an environment variable."
    exit 1
fi

if [ -z "$OKTA_API_TOKEN" ]; then
    log_message "Error: OKTA_API_TOKEN is not set. Please set it in the script or as an environment variable."
    exit 1
fi

 # First, get the user ID from the provided login
USER_ID=$(get_user_id_by_login "$USER_INFO")

LOOKUP_STATUS=$?

if [ $LOOKUP_STATUS -ne 0 ]; then
    log_message "$USER_ID $USER_INFO"
    log_message "Failed to retrieve user ID. Exiting."
    exit 1
fi 

# Password input loop
while true; do
    # Display the password change dialog
    password_input=$("${DIALOG}" \
        --title "Update Your Password" \
        --message "Please enter your current and new password.\n\n**Password Requirements:**\n\n
        • Minimum ${MIN_LENGTH} characters\n
        • At least one uppercase letter\n
        • At least one lowercase letter\n
        • At least one number\n
        • At least one special character\n 
          (${SPECIAL_CHARS_STRING})\n
        not the same as the prevoius 15 passwords" \
        --icon "sf=lock.fill" \
	--ontop \
        --textfield "Current Password",secure,required \
        --textfield "New Password",secure,required,confirm \
        --button1text "Update Password" \
        --button2text "Cancel" \
        --json )

    # Check if user cancelled
    if [[ "$?" -ne 0 ]]; then
        echo "Password Update Cancelled by user"
        show_dialog_and_exit "Password Update Cancelled" "You have cancelled the password update." "sf=xmark.circle.fill" 0
    fi

    OLD_PASSWORD=$(echo "${password_input}" | jq -r '."Current Password"')
    NEW_PASSWORD=$(echo "${password_input}" | jq -r '."New Password"')
    CONFIRM_NEW_PASSWORD=$(echo "${password_input}" | jq -r '."New Password (Confirm)"') # This is how confirm textfield names are returned

    # Validate new password complexity
    COMPLEXITY_ERRORS=$(validate_password_complexity "${NEW_PASSWORD}")
    if [[ -n "${COMPLEXITY_ERRORS}" ]]; then
        "${DIALOG}" \
            --title "Password Requirements Not Met" \
            --message "Your new password does not meet the following requirements:\n\n${COMPLEXITY_ERRORS}" \
            --icon "sf=exclamationmark.triangle.fill" \
            --button1text "Try Again" \
            --size small \
            --ontop \
            --centericon
        log_message "New password complexity failed."
        continue # Loop back to prompt for password again
    fi

    # Check if new password is the same as the old password
    if [[ "${OLD_PASSWORD}" == "${NEW_PASSWORD}" ]]; then
        "${DIALOG}" \
            --title "Password Error" \
            --message "Your new password cannot be the same as your current password. Please choose a different new password." \
            --icon "sf=exclamationmark.triangle.fill" \
            --button1text "Try Again" \
            --size small \
            --ontop \
            --centericon
        log_message "New password is the same as old password."
        continue # Loop back to prompt for password again
    fi

    log_message "Attempting to authenticate current password for user: ${CURRENT_USER}"
    # log_message "DEBUG: --- RIGHT BEFORE DSCL CALL ---" # <--- ADD THIS LINE
    
    AUTH_COMMAND_OUTPUT=""
    AUTH_EXIT_CODE=""

    # Using dscl:
    AUTH_COMMAND_OUTPUT=$(dscl . -authonly "${CURRENT_USER}" "${OLD_PASSWORD}" 2>&1)
    AUTH_EXIT_CODE=$?

    log_message "Authentication command output: '${AUTH_COMMAND_OUTPUT}', exit code: ${AUTH_EXIT_CODE}"
 
    # Verify current password using dscl . -authonly
    # Note: dscl . -authonly will return 0 on success, non-zero on failure.
    # It requires stdin for the password.
    if [[ ${AUTH_EXIT_CODE} -ne 0 ]]; then
        "${DIALOG}" \
            --title "Authentication Failed" \
            --message "The current password you entered is incorrect. Please try again." \
            --icon "sf=xmark.circle.fill" \
            --button1text "Try Again" \
            --size small \
            --ontop \
            --centericon
        log_message "Current password verification failed for user: ${CURRENT_USER}"
        continue # Loop back to prompt for password again
    fi

    # Update Passwod command
    ## Debug userid lookup value
    # echo "$USER_ID"
    ### --> update_password "$USER_ID_OR_LOGIN" "$OLD_PASSWORD" "$NEW_PASSWORD"
    OKTA_UP=$(update_password "$OLD_PASSWORD" "$NEW_PASSWORD")
    # Check if new password is the same as any of the previous passwords
    if [[ "${OKTA_UP}" == "E0000014" ]]; then
        "${DIALOG}" \
            --title "Password Error" \
            --message "Your new password cannot be the same as your one of your previous passwords. Please choose a different new password." \
            --icon "sf=exclamationmark.triangle.fill" \
            --button1text "Try Again" \
            --size small \
            --ontop \
            --centericon
        log_message "New password is the same as previously used password."
        continue # Loop back to prompt for password again
    fi

    # Check if the password change was successful
    # passwd returns 0 on success.
    # A more robust check might involve trying to auth with the new password, but dscl -passwd handles this usually.
    if [[ $? -eq 0 ]]; then
        sleep 30
        su "$CURRENT_USER" -c "open -g jamfconnect://signin"
        invalidate_token
        show_dialog_and_exit "Password Updated Successfully!" "Your password has been successfully updated : ${CURRENT_USER}." "sf=checkmark.circle.fill" 0
    else
        invalidate_token
        show_dialog_and_exit "Password Update Failed" "There was an error updating your password. Please try again or contact IT support." "sf=exclamationmark.triangle.fill" 1
    fi

done
