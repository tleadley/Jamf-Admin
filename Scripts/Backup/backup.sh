#!/bin/bash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#
#
# DESCRIPTION:
# To mount an encrypted drive on macOS, setting up Time Machine and starting a backup by 
# running this script for mounting and starting backups. Detecting device mount
# and USB insertion actions.
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
# 2024-07-24: Created script
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
prot_group="$7"
jamfSalt="$8"
jamfPassphrase="$9"

## Amount of time (in seconds) to allow a user to connect to AC power before moving on
## If null or 0, then the user will not have the opportunity to connect to AC power
acPowerWaitTimer="300"

## Declare the sysRequirementErrors array
declare -a sysRequirementErrors=()

## Icon to display during the AC Power warning
warnIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns"

## Icon to display when errors are found
errorIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"

## System Variables
getudid=$(system_profiler SPHardwareDataType | grep UUID | awk '{print $3}')
ComputerSerial=$( system_profiler SPHardwareDataType | grep Serial |  awk '{print $NF}' )
loggedInUser=$( ls -l /dev/console | awk '{print $3}' )

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
kill_process() {
    processPID="$1"
    if /bin/ps -p "$processPID" > /dev/null ; then
        /bin/kill "$processPID"
        wait "$processPID" 2>/dev/null
    fi
}

# # # # # # # # # #
wait_for_ac_power() {
    local jamfHelperPowerPID
    jamfHelperPowerPID="$1"
    ## Loop for "acPowerWaitTimer" seconds until either AC Power is detected or the timer is up
    /bin/echo "Waiting for AC power..."
    while [[ "$acPowerWaitTimer" -gt "0" ]]; do
        if /usr/bin/pmset -g ps | /usr/bin/grep "AC Power" > /dev/null ; then
            /bin/echo "Power Check: OK - AC Power Detected"
            kill_process "$jamfHelperPowerPID"
            return
        fi
        /bin/sleep 1
        ((acPowerWaitTimer--))
    done
    kill_process "$jamfHelperPowerPID"
    sysRequirementErrors+=("Is connected to AC power")
    /bin/echo "Power Check: ERROR - No AC Power Detected"
}

# # # # # # # # # #
validate_power_status() {
    ## Check if device is on battery or ac power
    ## If not, and our acPowerWaitTimer is above 1, allow user to connect to power for specified time period
descriptionText="Please connect your computer to power using an AC power adapter. This process will continue once AC power is detected."
    if /usr/bin/pmset -g ps | /usr/bin/grep "AC Power" > /dev/null ; then
        /bin/echo "Power Check: OK - AC Power Detected"
    else
        if [[ "$acPowerWaitTimer" -gt 0 ]]; then
            "$jamfHelper" -windowType utility -title "Waiting for AC Power Connection" -description "$descriptionText" -icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns" & wait_for_ac_power "$!"
        else
            sysRequirementErrors+=("Is connected to AC power")
            /bin/echo "Power Check: ERROR - No AC Power Detected"
        fi
    fi
}

# # # # # # # # # #
update_ea(){ # syntax :- update_ea $eaID $eaName $eaValue

# set EA ID
eaID="$1" # Extended Attribute ID Number we wish to update or retrieve
# set EA Name
eaName="$2" # Name of Extended Attribute in Jamf Pro
eavalue="$3" # set desired EA value in this case clear the value

# Submit unmanage payload to the Jamf Pro Server
curl -k -s --header "Authorization: Bearer $token" -X "PUT" "https://$jamfServer/JSSResource/computers/udid/$getudid/subset/extension_attributes" \
      -H "Content-Type: application/xml" -H "Accept: application/xml" \
      -d "<computer><extension_attributes><extension_attribute><id>$eaID</id><name>$eaName</name><type>String</type><value>$eavalue</value></extension_attribute></extension_attributes></computer>"

}

# # # # # # # # # #
read_ea(){ # syntax :- read_ea $eaID

# set EA ID
RDeaID="$1" # Extended Attribute ID Number we wish to update or retrieve

xml=$(curl -k -s --header "Authorization: Bearer $token" --request GET "https://$jamfServer/JSSResource/computers/udid/$getudid/subset/extension_attributes" \
      -H "Accept: application/xml" )
value=$(echo $xml | /usr/bin/xpath -e "//*[id=$RDeaID]/value/text()" 2>/dev/null)

echo $value

}

# # # # # # # # # #
shw_msg(){

# Description that will appear to the end user
descriptionText="Would You like to backup your device?"
update_ea "34" "Backup Drive" "Backup Process"
echo " "

# Showing user message and executing commands based on dialogue
buttonClicked=$( "$jamfHelper" -windowType utility -button1 "Ok" -button2 "Cancel" -title "$titleText" -description "$descriptionText" -icon "$icon" -heading "$headingText")

if [[ "$buttonClicked" == "0" ]];then
   update_ea "34" "Backup Drive" "Backup Started"
   echo " "
   validate_power_status # Lets make sure power is connected before proceeding
   check_drive
   start_bkup
   
elif [[ "$buttonClicked" == "2" ]];then

   update_ea "34" "Backup Drive" "Backup canceled"
   echo " "
   echo "Canceled"
   clean_up
   exit 0;
    
fi

}

# # # # # # # # # #
add_key(){

PASSPHRASE=$(read_ea "35")

sudo security add-generic-password -a "$UUID" -D "Encrypted Volume Password" -s "$UUID" -l "$VOLUMENAME" -w "$PASSPHRASE" -T /System/Applications/Utilities/Disk\ Utility.app/ -T /System/Library/CoreServices/APFSUserAgent -T /System/Library/CoreServices/CSUserAgent -A ~/Library/Keychains/login.keychain

}

# # # # # # # # # #
mount_drive(){

PASSPHRASE=$(read_ea "35")
mounted=$( mount | awk '$3 == "/Volumes/'$VOLUMENAME'" {print $3}' )

if [[ $mounted ]]; then

 echo /Volumes/$VOLUMENAME is mounted
 
else

diskutil apfs unlockVolume $VOLUMENAME -passphrase $PASSPHRASE
diskutil mount $VOLUMENAME

fi

}

# # # # # # # # # #
unmount_drive(){

if [[ $(mount | awk '$3 == "/Volumes/'$VOLUMENAME'" {print $3}') != "" ]]; then

 echo /Volumes/$VOLUMENAME is be being unmounted
 diskutil unmount $VOLUMENAME
 
fi

}

# # # # # # # # # #
check_drive(){

# Check to see if the keystore entry for this encrypted drive exists
key_check=$( security find-generic-password -a "$UUID" | grep $ComputerSerial | awk -F'"' '{print $2}' )

if [ "$key_check" == "$VOLUMENAME" ]; then

   echo "Login key exists in keystore"

elif [[ "$key_check" != "$VOLUMENAME" ]]; then

   echo "Creating keystore login for encrypted device"
   add_key

fi

}

# # # # # # # # # #
start_bkup(){

update_ea "34" "Backup Drive" "Backup in progress"
open "x-apple.systempreferences:com.apple.Time-Machine-Settings.extension"
echo " "

tmutil enable
tmutil setdestination -a /Volumes/$VOLUMENAME
diskID=$(tmutil destinationinfo /Volumes/$VOLUMENAME | grep ID | awk {'print $3'})
sleep 30
tmutil startbackup --auto --block --destination $diskID
echo " "

echo "Backup Completed Successfully! Your data is now safe and secure." # Descriptive action taken
# put current date as yyyy-mm-dd HH:MM:SS in $date
date=$(date '+%Y-%m-%d %H:%M:%S')

update_ea "34" "Backup Drive" "Backup Complete - $date"
echo " "

}

# # # # # # # # # #
validate(){

# Define the volume name to check
#VOLUMENAME="Your_Volume_Name"
MOUNTPOINT=$(diskutil list | grep "$VOLUMENAME" )

# Check if the volume exists and is accessible
if [ ! -z "$MOUNTPOINT" -a "$MOUNTPOINT" != " " ]; then
    # Volume exists, check if it's mounted
    MOUNTED=$(diskutil info $VOLUMENAME | grep "Mounted:" | awk '{print $2}' | grep -c "Yes" )

    if [ $MOUNTED -eq 1 ]; then
        echo "Mounted Backup Media found"
    elif [ $MOUNTED -eq 0 ]; then
        echo "Unmounted Backup Media found, mounting!"
        mount_drive
    fi
else
    # Volume not connected, print a user-friendly message
    update_ea "34" "Backup Drive" "Backup Media Missing"
    echo " "
    echo "Backup Media is not currently connected. Please connect the backup media and try again."
    clean_up
    exit 1;
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

validate # Validate the existance of a backup device

shw_msg # Message to be shown to begin the backup process

clean_up # Cleanup any commands or files that are left over and unmount drives

exit 0
