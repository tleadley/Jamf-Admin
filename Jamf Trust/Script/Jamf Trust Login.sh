#!/bin/bash
#####################################################################################
# This script adds Jamf Trust as a login item.                                      #
# Jamf EA : Jamf Trust login Item creation                                          #
# Result = Creates login item                                                       #
# Usage = "Setup a policy and run this script once a week or after major OS Updates #
#####################################################################################

## Current User
CURRENT_USER=$(ls -l /dev/console | awk '{print $3}')
CURRENT_USER_UID=$(id -u $CURRENT_USER)

launchctl asuser $CURRENT_USER_UID osascript -e 'tell application "System Events" to make login item at end with properties {name: "Jamf Trust",path:"/Applications/Jamf Trust.app", hidden:false}'

exit 0;
