#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Copyright (c) 2021 Jamf.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the Jamf nor the names of its contributors may be
#                 used to endorse or promote products derived from this software without
#                 specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This script was designed to be used in a Self Service policy to allow the facilitation
# or log collection by the end-user and upload the logs to the device record in Jamf Pro
# as an attachment.
#
# REQUIREMENTS:
#           - Jamf Pro
#           - macOS Clients running version 10.13 or later
#
#
# For more information, visit https://github.com/kc9wwh/logCollection
#
# Written by: Joshua Roskos | Jamf
#
#
# Revision History
# 2020-12-01: Added support for macOS Big Sur
# 2021-02-24: Fixed missing variables
# 2024-03-18: Addec support for bearer token addaption - Trevor Leadley
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## User Variables
jamfServer="$4"
jamfProUser="$5"
jamfProPassEnc="$6"
logFiles="$7"

## System Variables
mySerial=$( system_profiler SPHardwareDataType | grep Serial |  awk '{print $NF}' )
currentUser=$( stat -f%Su /dev/console )
compHostName=$( scutil --get LocalHostName )
timeStamp=$( date '+%Y-%m-%d-%H-%M-%S' )
osMajor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}')
osMinor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $2}')
# User password encrypted
jamfProPass=$( echo "$jamfProPassEnc" | /usr/bin/openssl enc -aes256 -d -a -A -S "$8" -k "$9" )

#set encoded username:password
APIauth="$jamfProUser:$jamfProPass"

# request auth token
authToken=$( /usr/bin/curl --request POST --silent --url "https://$jamfServer/api/v1/auth/token" --user "$APIauth" )

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


#####################################################################################################################################################

## Log Collection
fileName=$compHostName-$currentUser-$timeStamp.zip
zip /private/tmp/$fileName $logFiles

## Upload Log File
if [[ "$osMajor" -ge 11 ]]; then
    jamfProID=$( curl -k --header "Authorization: Bearer $token" https://$jamfServer/JSSResource/computers/serialnumber/$mySerial/subset/general | xpath -e "//computer/general/id/text()" )
elif [[ "$osMajor" -eq 10 && "$osMinor" -gt 12 ]]; then
    jamfProID=$( curl -k --header "Authorization: Bearer $token" https://$jamfServer/JSSResource/computers/serialnumber/$mySerial/subset/general | xpath "//computer/general/id/text()" )
fi

curl -k -u --header "Authorization: Bearer $token" https://$jamfServer/JSSResource/fileuploads/computers/id/$jamfProID -F name=@/private/tmp/$fileName -X POST

## Cleanup
rm /private/tmp/$fileName

# expire auth token
/usr/bin/curl --header "Authorization: Bearer $token" --request POST --silent --url "https://$jamfServer/api/v1/auth/invalidate-token"

exit 0
