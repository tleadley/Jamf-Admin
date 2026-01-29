#!/bin/bash

# Identify the username of the logged-in user

currentUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Create file named "standard" and place in /private/tmp/

touch /private/tmp/standard 

# Populate "standard" file with desired permissions

echo "$currentUser ALL= (ALL) ALL
$currentUser    ALL= !/usr/bin/passwd root, !/usr/bin/su root, !/bin/bash, !/bin/sh, !/usr/bin/defaults, !/usr/sbin/visudo, !/usr/bin/vi /etc/sudoers, !/usr/bin/vi /private/etc/sudoers, !/usr/bin/sudo -e /etc/sudoers, !/usr/bin/sudo -e /private/etc/sudoers, !/usr/bin/su" >> /private/tmp/standard

# Move "standard" file to /etc/sudoers.d

mv /private/tmp/standard /etc/sudoers.d

# Change permissions for "standard" file

chmod 644 /etc/sudoers.d/standard

exit 0;     ## Sucess
exit 1;     ## Failure