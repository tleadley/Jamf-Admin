#!/bin/bash
# Jamf Helper Script for Jamf Protect (High Threat Level)

jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

#Header for Pop Up
heading="IT Security Notification"
#Description for Pop Up
description="Critical Alert: Malware detected on your device. Immediate action required.

Your computer may be infected with malicious software (malware), which could compromise your personal data, as well as the security of the network. 

To protect yourself and prevent further damage, please do not power down your Mac IMMEDIATELY and contact your IT administrator at 778-722-9858 for assistance.
 
DO NOT attempt to restart or use your device until further instructions from IT are received."

#Button Text
button1="Ok"
#Path for Icon Displayed
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"

userChoice=$("$jamfHelper" -windowType utility -heading "$heading" -description "$description" -button1 "$button1" -icon "$icon")
        
        if [[ $userChoice == 0 ]]; then
                echo "user clicked $button1"
                /usr/local/bin/aftermath
                exit 0 
fi

exit 0;
