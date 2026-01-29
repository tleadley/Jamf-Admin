#!/bin/bash
# Move all files downloaded in the last 24 hours to the trash

#Move the files from Downloads to the Trash
find ~/Downloads/ -type fd -mtime 0 -exec mv {} ~/.Trash \;

#Remove Jamf Protect Extension Attribute
rm /Library/Application\ Support/JamfProtect/groups/*

#Update Jamf Inventroy
jamf recon

exit 0
