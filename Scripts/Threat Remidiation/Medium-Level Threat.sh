#!/bin/bash
# Jamf Helper Script for Jamf Protect (Medium Threat Level)

jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

#Header for Pop Up
heading="IT Security Notification"
#Description for Pop Up
description="Warning: The system has attempted to launch an application that may not be authorized on corporate systems, which could potentially contain malicious software (malware).

To ensure your security and compliance, we recommend reviewing recently downloaded files from the past 24 hours through Self Service.

Please move any suspicious or unauthorized files to the trash for removal.

If you need further assistance or have questions, don't hesitate to reach out to Corporate IT for support."
#Button Text
button1="Ok"
#Policy ID for policy in Self Service
policyID="37"
#Path for Icon Displayed
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"

userChoice=$("$jamfHelper" -windowType utility -heading "$heading" -description "$description" -button1 "$button1" -icon "$icon")
    
    if [[ $userChoice == 0 ]]; then
        echo "user clicked $button1"
        open "jamfselfservice://content?entity=policy&id=$policyID&action=view"
fi

exit 0;
