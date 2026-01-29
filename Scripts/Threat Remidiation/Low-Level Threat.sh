#!/bin/bash
# Jamf Helper Script for Jamf Protect (Low-Level Threat)

jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

#Header for Pop Up
heading="DC Security Notification"
#Description for Pop Up
description="Unexplained system change detected. Report to IT if you didn't initiate the change yourself."
#Button Text
button1="Ok"
#Path for Icon Displayed
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"

userChoice=$("$jamfHelper" -windowType utility -heading "$heading" -description "$description" -button1 "$button1" -icon "$icon")

#Remove Jamf Protect Extension Attribute
rm /Library/Application\ Support/JamfProtect/groups/*

#Update Jamf Inventroy
jamf recon

exit 0;
