#!/bin/bash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#
#
# DESCRIPTION:
# This is the script template and this is where you put what the script is suppose to accomplish in a detailed summary
# 
#
# REQUIREMENTS:
#           - Jamf Pro
#           - macOS Clients running version 10.13 or later
#
# FEATURES:
#           - Jamf Pro API bearer token security
#           - Decrypt / Encrypt Password
#           - Token credential expiry
#
# For more information, visit https://github.com/digitalconvergenceca/Mac_Admin_Jamf/tree/main/Scripts
#
# Written by: Trevor Leadley | Digital Convergence
#
#
# Revision History:
# YYYY-MM-DD: Details
# 2023-10-24: Created script
# 
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## Script Variables Jamf Pro
jamfServer="$4"
jamfProUser="$5"
jamfProPassEnc="$6"
jamfSalt="$8"
jamfPassphrase="$9"
prot_group="$10"

## System Variables
getudid=$(system_profiler SPHardwareDataType | grep UUID | awk '{print $3}')
ComputerSerial=$( system_profiler SPHardwareDataType | grep Serial |  awk '{print $NF}' )
loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

## Disk Variables
SERIAL=$( system_profiler SPHardwareDataType | awk '/Serial/ {print $4}' )
VOLUMENAME="BAK-$SERIAL"
UUID=$( diskutil info $VOLUMENAME | grep UUID | awk '{print $3}' | head -n 1 )

## JamfHelper Script Variables
# Get Help = /Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -help
# Variables below can also be set to use script parameters: https://www.jamf.com/jamf-nation/articles/146/script-parameters
# Path to jamfHelper
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
# window position (ul | ur | ll | lr)
windowPosition="ll"
# Title text for the notification, example would be Company Name
titleText="Digital Convergence Backup Utility"
# Custom heading text to display
headingText=""
# Description that will appear to the end user
descriptionText=""
# Enter a path to an icon to display. Example below will display the App Store icon
iconLocation="/Applications/Jamf Connect Sync.app/Contents/Resources/AppIcon.icns"
# Path for Icon Displayed
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericTimeMachineDiskIcon.icns"
# Timeout in seconds
timeout=""

## Jamf Pro API Variables
# User password encrypted
jamfProPass=$( echo "$jamfProPassEnc" | /usr/bin/openssl enc -aes256 -d -a -A -S "$jamfSalt" -k "$jamfPassphrase" )
# set encoded username:password
APIauth="$jamfProUser:$jamfProPass"
# request auth token
authToken=$( /usr/bin/curl --request POST --silent --url "https://$jamfServer/api/v1/auth/token" --user "$APIauth" )
# echo "$authToken"

# parse auth token
token=$( /usr/bin/plutil -extract token raw - <<< "$authToken" )
tokenExpiration=$( /usr/bin/plutil -extract expires raw - <<< "$authToken" )
localTokenExpirationEpoch=$( TZ=GMT /bin/date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s" 2> /dev/null )

# echo Token: "$token"
# echo Expiration: "$tokenExpiration"
# echo Expiration epoch: "$localTokenExpirationEpoch"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function Commands
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # # # # # # # #
update_ea(){	

# set EA ID
eaID="33" # Extended Attribute ID Number we wish to update or retrieve
# set EA Name
eaName="Password Update" # Name of Extended Attribute in Jamf Pro
value="" # set desired EA value in this case clear the value

# Submit unmanage payload to the Jamf Pro Server
curl -k -s --header "Authorization: Bearer $token" -X "PUT" "https://$jamfServer/JSSResource/computers/udid/$getudid/subset/extension_attributes" \
      -H "Content-Type: application/xml" \
      -H "Accept: application/xml" \
      -d "<computer><extension_attributes><extension_attribute><id>$eaID</id><name>$eaName</name><type>String</type><value>$value</value></extension_attribute></extension_attributes></computer>"
}

# # # # # # # # # #
read_ea(){

response=$(curl -s --header "Authorization: Bearer $token" -H "Accept: text/xml" https://$jamfServer/JSSResource/computers/serialnumber/"$ComputerSerial")
ATTRIBUTE_INFO=$(echo $response | /usr/bin/awk -F '<asset_tag>|</asset_tag>' '{print $2}');

}

# # # # # # # # # #
shw_msg(){

# Showing user message and executing commands based on dialogue
buttonClicked=$( "$jamfHelper" -windowType utility -defaultButton "1" -button1 "Ok" -title "$titleText" -description "$descriptionText" -icon "$icon" -heading "$headingText")

if [[ "$buttonClicked" = "0" ]];then
    su "$loggedInUser" -c "open -g jamfconnect://signin"
fi
}

# # # # # # # # # #
clean_up(){

file="/Library/Application Support/JamfProtect/groups/$prot_group"

echo "Updating Jamf EA and clearing Jamf Protection Groups"

unmount_drive

# Remove from Jamf Protect Group
if [[ -f "$file" ]]; then
    rm "$file"
    echo "Jamf Protection Group cleared"
else
    echo "Not added to a Jamf Protection Group"
    
fi

sleep 60
jamf recon
# expire auth token
/usr/bin/curl --header "Authorization: Bearer $token" --request POST --silent --url "https://$jamfserver/api/v1/auth/invalidate-token"

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Commandline Actions
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## Commands that need to be run
shw_msg # Message to be shown to user if required
clean_up # Cleanup any commands or files

exit 0
