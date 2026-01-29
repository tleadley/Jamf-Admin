#!/bin/bash
###########################################################################################
#		Script to Modify the username on the macOS.
###########################################################################################
actionLabel="Continue"
# pick a corporate icon
icon="/usr/local/JamfConnect/images/logo-Light.png"
Success="Username on both the MacBook and in OKTA match. The Setup will now exit"
# Logging file created in same directory as this script
d=$(date +%Y-%m-%d--%I:%M:%S)
log="${d} Account_RENAME:"
logfile="/Library/DigitalConvergence/logs/Account_RENAME.log"
mkdir -p /Library/DigitalConvergence/logs
# Create the log file
touch $logfile
# Open permissions to account for all error catching
chmod 777 $logfile

StartRenameScript(){
# Begin Logging
echo "${log} ## Rename Script Begin ##" 2>&1 | tee -a $logfile

# Ensures that script is run as ROOT
if [[ "${UID}" != 0 ]]; then
	echo "${log} Error: $0 script must be run as root" 2>&1 | tee -a $logfile
	exit 1
fi


oldUser=$loggedInUser
newUser=$OKTACheck

# Test to ensure account update is needed
if [[ "${oldUser}" == "${newUser}" ]]; then
	echo "${log} Error: Account ${oldUser}" is the same name "${newUser}" 2>&1 | tee -a $logfile
	exit 0
fi

# Query existing user accounts
readonly existingUsers=($(dscl . -list /Users | grep -Ev "^_|com.*|root|nobody|daemon|\/" | cut -d, -f1 | sed 's|CN=||g'))

# Ensure old user account is correct and account exists on system
if [[ ! " ${existingUsers[@]} " =~ " ${oldUser} " ]]; then
	echo "${log} Error: ${oldUser} account not present on system to update" 2>&1 | tee -a JC_RENAME.log
	exit 1
fi

# Ensure new user account is not already in use
if [[ " ${existingUsers[@]} " =~ " ${newUser} " ]]; then
	echo "${log} Error: ${newUser} account already present on system. Cannot add duplicate" 2>&1 | tee -a $logfile
	exit 1
fi

# Query existing home folders
readonly existingHomeFolders=($(ls /Users))

# Ensure existing home folder is not in use
if [[ " ${existingHomeFolders[@]} " =~ " ${newUser} " ]]; then
	echo "${log} Error: ${newUser} home folder already in use on system. Cannot add duplicate" 2>&1 | tee -a $logfile
	exit 1
fi

# Check if username differs from home directory name
actual=$(eval echo "~${oldUser}")
if [[ "/Users/${oldUser}" != "$actual" ]]; then
	echo "${log} Error: Username differs from home directory name!" 2>&1 | tee -a $logfile
	echo "${log} Error: home directory: ${actual} should be: /Users/${oldUser}." 2>&1 | tee -a $logfile
fi

# Updates NFS home directory
ORGhomeFolder=$(dscl . read "/Users/$oldUser" NFSHomeDirectory | cut -d: -f 2 | sed "s/^ *//"| tr -d "\n")
sudo dscl . -change "/Users/$oldUser" NFSHomeDirectory "${ORGhomeFolder}" "/Users/$newUser"
if [[ $? -ne 0 ]]; then
	echo "${log} Could not rename the user's home directory pointer, aborting further changes! - err=$?" 2>&1 | tee -a $logfile
	echo "${log} Reverting Home Directory changes" 2>&1 | tee -a $logfile
	sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${ORGhomeFolder}"
	echo "${log} Reverting RealName changes" 2>&1 | tee -a $logfile
	exit 1
else
	echo "${log} NFSHomeDirectory successfully changed to "/Users/${newUser}"" 2>&1 | tee -a $logfile
fi
# Actual username change
sudo dscl . -change "/Users/$oldUser" RecordName "$oldUser" "$newUser"
if [[ $? -ne 0 ]]; then
	echo "${log} Could not rename the user's RecordName in dscl - the user should still be able to login, but with user name ${oldUser}" 2>&1 | tee -a $logfile
	echo "${log} Reverting username change" 2>&1 | tee -a $logfile
	sudo dscl . -change "/Users/${oldUser}" RecordName "${newUser}" "${oldUser}"
	echo "${log} Reverting Home Directory changes" 2>&1 | tee -a $logfile
	mv "/Users/${newUser}" "${ORGhomeFolder}"
	sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${ORGhomeFolder}"
	exit 1
else
	echo "${log} RecordName successfully changed to "${newUser}""
fi
# Updates name of home directory to new usernam
sudo mv "$ORGhomeFolder" "/Users/$newUser"
if [[ $? -ne 0 ]]; then
	echo "${log} Could not rename the user's home directory in /Users" 2>&1 | tee -a $logfile
	echo "${log} Reverting Home Directory changes" 2>&1 | tee -a $logfile
	mv "/Users/${newUser}" "${ORGhomeFolder}"
	sudo dscl . -change "/Users/${oldUser}" NFSHomeDirectory "/Users/${newUser}" "${ORGhomeFolder}"
	echo "${log} Reverting username change" 2>&1 | tee -a $logfile 2>&1 | tee -a $logfile
	sudo dscl . -change "/Users/${oldUser}" RecordName "${newUser}" "${oldUser}"
	exit 1
else
	echo "${log} HomeDirectory successfully changed to "/Users/${newUser}"" 2>&1 | tee -a $logfile
fi
# Links old home directory to new. Fixes dock mapping issue
sudo ln -s "/Users/$newUser" "$homeFolder"
# Fixing the permissions on the Home Directory
sudo chown -R $newUser:staff /Users/$newUser
#Updating all other entires of Directory Utility
sudo dscl . -change "/Users/$newUser" dsAttrTypeNative:_writers_AvatarRepresentation "$oldUser" "$newUser" 2>&1 | tee -a $logfile
sudo dscl . -change "/Users/$newUser" dsAttrTypeNative:_writers_hint "$oldUser" "$newUser" 2>&1 | tee -a $logfile
sudo dscl . -change "/Users/$newUser" dsAttrTypeNative:_writers_jpegphoto "$oldUser" "$newUser" 2>&1 | tee -a $logfile
sudo dscl . -change "/Users/$newUser" dsAttrTypeNative:_writers_passwd "$oldUser" "$newUser" 2>&1 | tee -a $logfile
sudo dscl . -change "/Users/$newUser" dsAttrTypeNative:_writers_picture "$oldUser" "$newUser" 2>&1 | tee -a $logfile
sudo dscl . -change "/Users/$newUser" dsAttrTypeNative:_writers_unlockOptions "$oldUser" "$newUser" 2>&1 | tee -a $logfile
sudo dscl . -change "/Users/$newUser" dsAttrTypeNative:_writers_UserCertificate "$oldUser" "$newUser" 2>&1 | tee -a $logfile

# Success message
read -r -d '' successOutput <<EOM
Success ${oldUser} username has been updated to ${newUser}
Folder "${origHomeDir}" has been renamed to "/Users/${newUser}"
RecordName: ${newUser}
NFSHomeDirectory: "/Users/${newUser}"
SYSTEM RESTARTING in 2 minutes to complete username update.
EOM

echo "${log} ${successOutput}" 2>&1 | tee -a $logfile

# System restart
Sleep 10
sudo jamf policy -event RestartMyMacbook
}

FetchOKTAID(){
  OKTACheck=$(osascript -e 'display dialog "Please Enter your OKTA ID. Name before the @ in email" default answer "" buttons {"Continue"} default button 1' | tr [A-Z] [a-z] | awk -F ':' '{print $3}')
  echo $OKTACheck
  callButton=$(osascript -e 'display dialog "The OKTA ID entered is '$OKTACheck'

  If it is correct, please click Confirm.

  Else, Click on Re-Enter." buttons {"Confirm", "Re-Enter"} default button "Confirm"')
  if [[ $callButton == "button returned:Confirm" ]]; then
  if [ "$loggedInUser" == "$OKTACheck" ]; then
  echo "Usernames Match OKTA ID: $OKTACheck and MacBook User ID: $loggedInUser"
"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType utility -icon "$icon" -title "$title" -description "$Success" -button1 "$actionLabel" -defaultButton 1 -lockHUD -startlaunchd -windowPosition center -timeout 5
  else
  echo "Usernames Don't Match OKTA ID: $OKTACheck and MacBook User ID: $loggedInUser"
  StartRenameScript
  fi
else
FetchOKTAID
fi
}
AlertUser(){
	loggedInUser=`ls -l /dev/console | awk '/ / { print $3 }'`
	loggedInUID=$(id -u "$loggedInUser")
	homeFolder=$(dscl . read "/Users/$loggedInUser" NFSHomeDirectory | cut -d: -f 2 | sed "s/^ *//"| tr -d "\n")
  title="Name Change update"
  message="
User name update. This tool will modify the local username to reflect the updated changes as per request and automatically restart the device.

After your name has been updated, the device will continue post restart"
  # Call window with appropriate messaging
	userClick=$( "/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType utility -icon "$icon" -title "$title" -description "$message" -button1 "$actionLabel" -defaultButton 1 -lockHUD -startlaunchd -windowPosition center )
	# Call function to capture user input
	jamfHelperClick
}
jamfHelperClick() {
if [[ $userClick == 0 ]]; then
	echo "$currentUser chose to proceed..."
  FetchOKTAID
elif [[ $userClick == 2 ]]; then
	echo "$currentUser Aborted Tool"
	exit 0
fi
}
AlertUser
exit 0
