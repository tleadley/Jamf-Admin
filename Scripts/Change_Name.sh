#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This script was designed to be used in a security policy to allow the facilitation
# of computer renaming. Avoids the possibility of duplicate computer names
#
# REQUIREMENTS:
#           - Jamf Pro
#           - macOS Clients running version 10.13 or later
#
#
# 
#
# Written by: Trevor Leadley | Digital Convergence
#
#
# Revision History
# 
# 2023-10-24: Created script
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## User Variables
jamfserver="$5"
jamfProUser="$6"
jamfProPassEnc="$7"

###########################################################################################
# User password encrypted
jamfProPass=$( echo "$jamfProPassEnc" | /usr/bin/openssl enc -aes256 -d -a -A -S "$8" -k "$9" )

#set encoded username:password
APIauth="$jamfProUser:$jamfProPass"

# request auth token
authToken=$( /usr/bin/curl --request POST --silent --url "https://$jamfserver/api/v1/auth/token" --user "$APIauth" )

echo "$authToken"

# parse auth token
token=$( /usr/bin/plutil \
-extract token raw - <<< "$authToken" )

tokenExpiration=$( /usr/bin/plutil \
-extract expires raw - <<< "$authToken" )

localTokenExpirationEpoch=$( TZ=GMT /bin/date -j \
-f "%Y-%m-%dT%T" "$tokenExpiration" \
+"%s" 2> /dev/null )

echo Token: "$token"
echo Expiration: "$tokenExpiration"
echo Expiration epoch: "$localTokenExpirationEpoch"

###########################################################################################

SERIAL_NUMBER=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')

response=$(curl -s --header "Authorization: Bearer $token" -H "Accept: text/xml" https://$jamfserver/JSSResource/computers/serialnumber/"$SERIAL_NUMBER")

ASSET_TAG_INFO=$(echo $response | /usr/bin/awk -F '<asset_tag>|</asset_tag>' '{print $2}');

SUFFIX="-SER"

if [ -n "$ASSET_TAG_INFO" ]; then
  echo "Processing new name for this client..."
  echo "Changing name..."
  scutil --set HostName "$ASSET_TAG_INFO"
  scutil --set ComputerName "$ASSET_TAG_INFO"
  echo "Name change complete. ("$ASSET_TAG_INFO")"

elif [ -z "$ASSET_TAG_INFO"]; then
  echo "Asset Tag information was unavailable. Using Serial Number instead."
  echo "Changing Name..."
  scutil --set HostName "$SERIAL_NUMBER$SUFFIX"
  scutil --set ComputerName "$SERIAL_NUMBER$SUFFIX"
  echo "Name Change Complete ($SERIAL_NUMBER$SUFFIX)"

fi

# expire auth token
/usr/bin/curl --header "Authorization: Bearer $token" --request POST --silent --url "https://$jamfserver/api/v1/auth/invalidate-token"

exit 0;
