#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This script was designed to be used in a security policy to allow the facilitation
# of updating the password status of user passwords. Avoids the possibility of lockouts
#
# REQUIREMENTS:
#           - Jamf Pro
#           - macOS Clients running version 10.13 or later
#
#
# 
#
# Written by: Trevor Leadley
#
#
# Revision History
# 
# 2023-10-23: Created script
# 2025-12-23: Bearer Token & Date Parse Fix
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

loggedInUser=$( ls -l /dev/console | awk '{print $3}' )

# Get Help = /Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -help
# Variables below can also be set to use script parameters: https://www.jamf.com/jamf-nation/articles/146/script-parameters
# Path to jamfHelper
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

# window position (ul | ur | ll | lr)
windowPosition="ll"

# Title text for the notification, example would be Company Name
titleText="Password out of sync"

# Custom heading text to display
headingText=""

# Description that will appear to the end user
descriptionText=""

# Enter a path to an icon to display. Example below will display the App Store icon
iconLocation="/Applications/Jamf Connect Sync.app/Contents/Resources/AppIcon.icns"
#Path for Icon Displayed
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolBarInfo.icns"

# Timeout in seconds
timeout=""

#set base server URL in parameter 4, add 8443 into variable in policy payload if self-hosted
jamfserver="$4"
# Jamf Username information
jamfProUser="$5"
jamfProPassEnc="$6"

# User password encrypted
jamfProPass=$( echo "$jamfProPassEnc" | /usr/bin/openssl enc -aes256 -d -a -A -S "$8" -k "$9" )

#set encoded username:password
APIauth="$jamfProUser:$jamfProPass"

get_token() {

echo "Fetching fresh API token..."
# request auth token
authToken=$( /usr/bin/curl --request POST --silent --url "https://$jamfserver/api/v1/auth/token" --user "$APIauth" )

# parse auth token
token=$( /usr/bin/plutil -extract token raw - <<< "$authToken" )

tokenExpiration=$( /usr/bin/plutil -extract expires raw - <<< "$authToken" )

cleanExpiration=$(echo "$tokenExpiration" | sed 's/\.[0-9]*//g; s/Z//g')
localTokenExpirationEpoch=$( /bin/date -j -f "%Y-%m-%dT%T" "$cleanExpiration" +"%s" 2> /dev/null )

# echo Token: "$token"
# echo Expiration: "$tokenExpiration"
# echo Expiration epoch: "$localTokenExpirationEpoch"

}
#####################################################################################################################################################
get_uptime() {
    # Returns uptime in days
    uptime_string=$(uptime | awk -F'up ' '{print $2}' | cut -d',' -f1)
    days=$(echo $uptime_string | awk '{print $1}')

    if [[ $uptime_string == *"day"* ]]; then
       echo "$days"
    else
        echo "0"
    fi
}

update_ea(){	
    # Check if token is still valid
    currentEpoch=$(date +%s)
    
    # Verify we have a token and it isn't expired
    if [[ -n "$token" ]] && [[ $localTokenExpirationEpoch -gt $currentEpoch ]]; then
        getudid=$(ioreg -d2 -c IOPlatformExpertDevice | awk -F\" '/IOPlatformUUID/{print $(NF-1)}')
        eaID=(Number) # replace with your EA ID number
        eaName="Password Update" 
        value="" 

        curl -k -s --header "Authorization: Bearer $token" -X "PUT" "https://$jamfserver/JSSResource/computers/udid/$getudid/subset/extension_attributes" \
              -H "Content-Type: application/xml" \
              -H "Accept: application/xml" \
              -d "<computer><extension_attributes><extension_attribute><id>$eaID</id><name>$eaName</name><type>String</type><value>$value</value></extension_attribute></extension_attributes></computer>"
    else
        echo "API Token expired while waiting for user interaction. EA update skipped."
    fi
}

shw_msg(){

# Check to see if variables were passed in Jamf Pro

buttonClicked=$( "$jamfHelper" -windowType utility -defaultButton "1" -button1 "Ok" -title "$titleText" -description "$descriptionText" -icon "$icon" -heading "$headingText")

if [[ "$buttonClicked" = "0" ]];then
    su "$loggedInUser" -c "open -g jamfconnect://signin"
fi

}

clean_up(){
    
        if [ "$(ls -A /Library/Application\ Support/JamfProtect/groups/)" ]; then
                   echo "Jamf Protect Analytic - Password State was checked"
                   echo "Resetting EA and clearing Protection Groups"
                   #Remove Jamf Protect Extension Attribute
                   rm /Library/Application\ Support/JamfProtect/groups/*
                   get_token
                   update_ea
                   sleep 60
                   jamf recon
                   # expire auth token
                   if [[ $localTokenExpirationEpoch -gt $(date +%s) ]]; then
                      /usr/bin/curl --header "Authorization: Bearer $token" --request POST --silent --url "https://$jamfserver/api/v1/auth/invalidate-token"
                   fi
                   exit 0;
                   
         else
                   echo "Extension Attrubute Check - Password update status"
                   echo "Resetting EA"
                   get_token
                   update_ea
                   # expire auth token
                   if [[ $localTokenExpirationEpoch -gt $(date +%s) ]]; then
                      /usr/bin/curl --header "Authorization: Bearer $token" --request POST --silent --url "https://$jamfserver/api/v1/auth/invalidate-token"
                   fi
                   exit 0;
         fi

}

get_expiry() {

    # Check if CURRENT_USER is set
    if [ -z "$loggedInUser" ]; then
        echo "Error: CURRENT_USER is not set. Please set the CURRENT_USER variable before calling get_expiry." >&2
        return 1
    fi

    # Get the day the password was last changed
    # We'll use a subshell to capture stderr and check the exit code
    if ! LocalDate=$(dscl . -read /Users/"$loggedInUser" accountPolicyData 2>/dev/null | tail -n +2 | plutil -extract passwordLastSetTime xml1 -o - -- - 2>/dev/null | sed -n "s/<real>\([0-9]*\).*/\1/p"); then
        echo "Error: Could not retrieve password last set time for user '$loggedInUser'." >&2
        echo "Please ensure the user exists and you have appropriate permissions." >&2
        return 1
    fi

    # Check if LocalDate is empty, which means extraction might have failed silently
    if [ -z "$LocalDate" ]; then
        echo "Error: Password last set time was empty or could not be extracted for user '$loggedInUser'." >&2
        return 1
    fi

    # Get today's date (Unix timestamp)
    datum=$(date "+%s")

    # Calculate how many days since the last password change
    # Ensure LocalDate is a valid number before performing arithmetic
    if ! [[ "$LocalDate" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid 'passwordLastSetTime' format retrieved: '$LocalDate'." >&2
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
    echo "$days"
    
}

is_current() {

#forcing a network password status check
su "$loggedInUser" -c "open -g jamfconnect://networkcheck"

sleep 5

isCurrent=$(defaults read /Users/"$loggedInUser"/Library/Preferences/com.jamf.connect.state PasswordCurrent)

        if [ "$isCurrent" == 1 ];then
                result="true"
        elif [ "$isCurrent" == 0 ];then
                result="false"     
        fi
        
echo $result

}

#########################################################################################################################################################
echo "Jamf Connect - Network Status Check"
defaults read /var/db/dslocal/nodes/Default/users/$loggedInUser.plist > /dev/null 2>&1

# Check FileVault Status
filevault_status=$(fdesetup status)

if [[ "$filevault_status" == *"FileVault is Off."* ]]; then
  echo "FileVault is disabled. Skipping Secure Token check."
  exit 1
fi

# Check Secure Token Status
secure_token_status=$(sysadminctl -secureTokenStatus "$loggedInUser" 2>&1)
bt_status=$(profiles status -type bootstraptoken 2>&1 | grep -q "YES" && echo "YES" || echo "NO")

if ! echo "$secure_token_status" | grep -q "ENABLED"; then
   if [ "$bt_status" == "YES" ]; then
      # The "Self-Heal" path
      descriptionText="Your security credentials need to be refreshed. Please RESTART your Mac and log in to stay in sync."
      headingText="Restart Required"
   else
       # The "Danger" path
       descriptionText="Secure Token is not enabled for $loggedInUser. Please contact IT before restarting."
       headingText="Security Authorization Issue"
   fi
   shw_msg
   exit 1
fi

check_status=$(is_current)

if [ "$(get_expiry)" -lt 1 ]; then 
         
         # Description that will appear to the end user
         descriptionText="Your password has expired, Please click OK to sign into Jamf Connect Sync to update your password!"
         echo "<result>Password Expired</result>"
         shw_msg
         clean_up
fi

if [ "$check_status" == "false" ]; then 
         
         # Description that will appear to the end user
         descriptionText="Your local Mac password does not match Okta. Please click OK to sign into Jamf Connect Sync."
         echo "<result>Password Not Synced</result>"
         shw_msg
         clean_up

elif [ "$check_status" == "true" ]; then

        uptime_days=$(get_uptime)
    
        # If password is synced but machine hasn't restarted in over 7 days
        if [ "$uptime_days" -gt 7 ]; then
              titleText="Restart Recommended"
              descriptionText="Your password is in sync, but your Mac hasn't restarted in $uptime_days days. To ensure FileVault stays updated, please restart your computer today."
              icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/Sync.icns"
              shw_msg
        fi

        echo "<result>Password Synced</result>"
        clean_up     
else
         echo "No Check Performed"
fi

exit 0;
