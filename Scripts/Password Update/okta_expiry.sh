#!/bin/bash

# --- Configuration ---
OKTA_ORG_URL="https://digitalconvergence.okta.com" # Replace with your Okta domain
OKTA_API_TOKEN="00On.............."   # Replace with your Okta API Token
USER_ID="00u"         # Replace with the actual Okta User ID

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
# Function to show how many days till the password expires
get_expiry(){
local timestamp="$1"
#Get Day the password was last changed
#LocalDate=$(dscl . -read /Users/$CURRENT_USER accountPolicyData | tail -n +2 | plutil -extract passwordLastSetTime xml1 -o - -- - | sed -n "s/<real>\([0-9]*\).*/\1/p")
# echo "Password Last Set (Unix TS):         ${LocalDate}"
#Get today's date
datum=$(date "+%s")
# cho "Current Unix Timestamp:              ${datum}"
#Calculate how many days since the last password change
diff=$(($datum-$timestamp))

#Convert time code to a readable number
days=$((60-$diff/(60*60*24)))
echo "$days"

}
# --- API Call ---
# The endpoint to retrieve a user's details
API_ENDPOINT="${OKTA_ORG_URL}/api/v1/users/${USER_ID}"

echo "Fetching user details for ID: ${USER_ID}..."

response=$(curl -s -X GET \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "Authorization: SSWS ${OKTA_API_TOKEN}" \
  "${API_ENDPOINT}")

# --- Process Response ---
# Check for common API errors first
if echo "${response}" | grep -q '"errorCode"'; then
  echo "Error retrieving user details from Okta:"
  echo "${response}" | jq . # Use jq for pretty printing JSON
  exit 1
fi

# Extract the 'passwordChanged' timestamp
# The 'passwordChanged' field is typically at the top level of the user object.
# It's in ISO 8601 format (e.g., "2025-07-18T14:30:00.000Z")
LAST_PASSWORD_CHANGE_DATETIME=$(echo "${response}" | jq -r '.passwordChanged')
TIMESTAMP=$(iso_to_unix_timestamp "$LAST_PASSWORD_CHANGE_DATETIME")

if [ -z "$LAST_PASSWORD_CHANGE_DATETIME" ] || [ "$LAST_PASSWORD_CHANGE_DATETIME" == "null" ]; then
  echo "Could not find 'passwordChanged' information for user ID: ${USER_ID}."
  echo "This might mean the password has never been changed since the account was created or is managed externally (e.g., via AD/LDAP)."
else
  echo "Last password change for user ID ${USER_ID}:"
  echo "Full Timestamp: ${LAST_PASSWORD_CHANGE_DATETIME}"

  # You can further format this if needed, e.g., to just the date
  # Extract just the date part (YYYY-MM-DD)
  LAST_PASSWORD_CHANGE_DATE=$(echo "$LAST_PASSWORD_CHANGE_DATETIME" | cut -d'T' -f1)
  echo "Date (YYYY-MM-DD): ${LAST_PASSWORD_CHANGE_DATE}"
  get_expiry "$TIMESTAMP"
fi
