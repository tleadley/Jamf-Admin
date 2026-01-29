#!/bin/bash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#
#
# DESCRIPTION:
# This script prompts a user to add permissions for ActiveTrak, opens the Privacy Preferences for Screen capture
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
# 2024-08-12: Created script
#
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## System Variables
getudid=$(system_profiler SPHardwareDataType | grep UUID | awk '{print $3}')
ComputerSerial=$( system_profiler SPHardwareDataType | grep Serial |  awk '{print $NF}' )
loggedInUser=$( ls -l /dev/console | awk '{print $3}' )

## JamfHelper Script Variables
# Get Help = /Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -help
# Variables below can also be set to use script parameters: https://www.jamf.com/jamf-nation/articles/146/script-parameters
# Path to jamfHelper
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
# window position (ul | ur | ll | lr)
windowPosition="ll"
# Title text for the notification, example would be Company Name
titleText="Digital Convergence ActivTrak"
# Custom heading text to display
headingText=""
# Description that will appear to the end user
descriptionText=""
# Enter a path to an icon to display. Example below will display the App Store icon
iconLocation="/Applications/Jamf Connect Sync.app/Contents/Resources/AppIcon.icns"
# Path for Icon Displayed
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AppleTraceFile.icns"
# Timeout in seconds
timeout=""

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function Commands
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # # # # # # # #
shw_msg(){
headingText="ActivTrak Permissions Check"
descriptionText="Click OK to set the appropriate permissions"

# Showing user message and executing commands based on dialogue
buttonClicked=$( "$jamfHelper" -windowType utility -defaultButton "1" -button1 "Ok" -button2 "Moreinfo" -title "$titleText" -description "$descriptionText" -icon "$icon" -heading "$headingText")

while [ "$buttonClicked" == "2" ]
do
    su "$loggedInUser" -c "open 'https://digitalconvergence.atlassian.net/servicedesk/customer/portal/27/topic/57622345-7551-4bc5-a6d2-ef491d0ccba5/article/2862972929'"
# Showing user message and executing commands based on dialogue
buttonClicked=$( "$jamfHelper" -windowType utility -defaultButton "1" -button1 "Ok" -button2 "Moreinfo" -title "$titleText" -description "$descriptionText" -icon "$icon" -heading "$headingText")
done

if [[ "$buttonClicked" = "0" ]];then
    su "$loggedInUser" -c "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'"
fi

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Commandline Actions
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## Commands that need to be run
shw_msg # Message to be shown to user if required

exit 0

