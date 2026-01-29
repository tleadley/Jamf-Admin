#!/bin/bash

# Configuration
OKTA_ORG_URL="https://digitalconvergence.okta.com" # Set this or export OKTA_ORG_URL
OKTA_API_TOKEN="" # Set this or export OKTA_API_TOKEN

# --- Input Validation ---
if [ -z "$OKTA_ORG_URL" ]; then
    echo "Error: OKTA_ORG_URL is not set. Please set it in the script or as an environment variable."
    exit 1
fi

if [ -z "$OKTA_API_TOKEN" ]; then
    echo "Error: OKTA_API_TOKEN is not set. Please set it in the script or as an environment variable."
    exit 1
fi

# --- Function to update password ---
get_user_id_by_login() {
    local user_login="$1"
    local SEARCH_RESPONSE=""
    echo "Attempting to find user ID for login: $user_login..."
    URL_QUERY="${OKTA_ORG_URL}/api/v1/users?filter=profile.email%20eq%20%22${user_login}%22"
    # Make the API call to search for the user
    # -G: Sends data as a GET request with parameters appended to the URL
    # --data-urlencode: URL-encodes the query parameter to handle special characters
    SEARCH_RESPONSE=$(/usr/bin/curl -sS -X GET \
                       -H "Accept: application/json" \
                       -H "Content-Type: application/json" \
                       -H "Authorization: SSWS ${OKTA_API_TOKEN}" \
                      "${URL_QUERY}" 2>&1)
    CURL_EXIT_CODE=$?
echo $URL_QUERY
    if [ $CURL_EXIT_CODE -ne 0 ]; then
        echo "Error: curl command failed during user lookup with exit code $CURL_EXIT_CODE."
        echo "Curl Error Message: $SEARCH_RESPONSE"
        return 1
    fi

    # Check if the response is valid JSON and contains an errorCode
    if echo "$SEARCH_RESPONSE" | jq -e '.errorCode' >/dev/null 2>&1; then
        ERROR_CODE=$(echo "$SEARCH_RESPONSE" | jq -r '.errorCode')
        ERROR_SUMMARY=$(echo "$SEARCH_RESPONSE" | jq -r '.errorSummary')
        echo "Okta API Error during user lookup: $ERROR_CODE - $ERROR_SUMMARY"
        return 1
    fi

    # Extract the user ID from the response.
    # We expect an array of users, and we take the 'id' of the first user found.
    USER_ID=$(echo "$SEARCH_RESPONSE" | jq -r '.[] | .id' | head -n 1)

    if [ -z "$USER_ID" ] || [ "$USER_ID" == "null" ]; then
        echo "Error: User with login '$user_login' not found in Okta or no ID returned."
        return 1
    else
        echo "Found user ID: $USER_ID for login: $user_login."
        echo "$USER_ID" # Output the user ID for the caller
        return 0
    fi
}


# --- Main execution ---
get_user_id_by_login "todd.technical@digitalconvergence.ca"

EXIT_STATUS=$?

if [ $EXIT_STATUS -eq 0 ]; then
    echo "Script finished successfully."
else
    echo "Script finished with errors."
fi

exit $EXIT_STATUS
