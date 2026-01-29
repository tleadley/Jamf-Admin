#!/bin/bash

# Malware Cleanup for Jamf Protect

if [ -z "$(ls -A /Library/Application\ Support/JamfProtect/Quarantine)" ]; then

   exit 0;
   
else

#Zip Malware

cd /Library/Application\ Support/JamfProtect/Quarantine/*; zip -r -X "../Malware-$(date +%Y_%m_%d-%H_%M_%S).zip" *

#Move Malware to a new location, Default is /Users/Shared

cd /Library/Application\ Support/JamfProtect/Quarantine/; mv Malware*.zip /tmp

#Remove the Malware

rm -R /Library/Application\ Support/JamfProtect/Quarantine/*
   
fi

exit 0;