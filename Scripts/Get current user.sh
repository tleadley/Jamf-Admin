#!/bin/sh

user=`ls -l /dev/console | awk '/ / { print $3 }'`

echo "<result>$user</result>"

#sudo jamf recon -endUsername $3

exit 0