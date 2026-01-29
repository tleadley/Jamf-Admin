#!/bin/bash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#
#
# DESCRIPTION:
# This is the script checks and corrects Jamf Trust access related issues
#
#
# REQUIREMENTS:
#           - Jamf Pro
#           - macOS Clients running version 10.13 or later
#
# FEATURES:
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

## Get the logged in username
currUser=$(/usr/bin/stat -f%Su /dev/console)

## Jamf Pro variables
## prot_group="$4"
prot_group="Access_Disabled"

# Jamf Helper Script for Jamf Protect (Low-Level Threat)
## JamfHelper Script Variables
# Get Help = /Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -help
# Variables below can also be set to use script parameters: https://www.jamf.com/jamf-nation/articles/146/script-parameters
# Path to jamfHelper
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

#Title for Pop Up
msgtitle="Digital Convergence Group"

#Header for Pop Up
heading="Jamf Private Access"

#Description for Pop Up
description="Looks Like Jamf Access has stopped running!

If this is something you have initiated you can disregard this message,
Otherwise Click Enable to reactivate your connection!

Please report to IT if you suspect anything wrong or if this becomes persistent."

#Button Text
button1="Ok"
#Button Text
button2="Enable"
#Path for Icon Displayed
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolBarInfo.icns"

# # # # # # # # # #
clean_up(){

file="/Library/Application Support/JamfProtect/groups/$prot_group"

echo "Collecting Inventory and Clearing Jamf Protection Groups"

# Remove from Jamf Protect Group
if [[ -f "$file" ]]; then
    rm "$file"
    echo "Jamf Protection Group cleared"
else
    echo "Not added to a Jamf Protection Group"

fi

sleep 60
jamf recon

}

# # # # # # # # # #
check_jamf(){
## Check to make sure that Jamf Trust and Private Access is actually not running
Child=$(ps aux | grep -v grep | grep -ci JamfPrivateAccess)
Parent=$(ps aux | grep -v grep | grep -ci "Jamf Trust")

if [ "$Child" = "1" ]
    then
        result="Jamf Trust VPN is Running"
        echo $result
        clean_up
        exit 0;
fi
}

# # # # # # # # # #
shw_msg(){
userChoice=$("$jamfHelper" -windowType utility -title "$msgtitle" -windowPosition "ur" -heading "$heading" -description "$description" -button1 "$button1" -button2 "$button2" -icon "$icon")

if [[ "$userChoice" == "2" ]]; then

## Check to see if Parent is running before executing workflow automation

     if [ "$Parent" == "0" ]
        then
        result="Jamf Trust Not Running"
        echo $result
        /usr/bin/open -a "Jamf Trust" "com.jamf.trust://?action=open"
        echo "Restarting Jamf Trust - Jamf Trust was not running"
        sleep 5
        /usr/bin/open -a "Jamf Trust" "com.jamf.trust://?action=enable_vpn"
        echo "Sending user the enable prompt"

     elif [ "$Parent" == "1" ]
        then
        result="Jamf Trust is Running, restarting VPN"
        echo $result
        /usr/bin/open -a "Jamf Trust" "com.jamf.trust://?action=enable_vpn"
        echo "Sending user the enable prompt"
     fi
     
elif [[ "$userChoice" == "0" ]]; then 
     result="User chose to ignore message, we will check next system checkin"
     echo $result
fi
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Commandline Actions
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## Commands that need to be run
check_jamf # Check to see if the service is running
shw_msg # Message to be shown to user for any required action
clean_up # Cleanup any commands or files

exit 0
