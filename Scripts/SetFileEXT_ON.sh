#!/bin/sh
#sudo -u $3 osascript <<eos
#tell application "Finder"
#    activate
#    set all name extensions showing of Finder preferences to true
#end tell
#eos
CURRENT_USER=`ls -l /dev/console | awk '/ / { print $3 }'`

echo "<result>$CURRENT_USER</result>"

/usr/bin/sudo -u "$CURRENT_USER" /usr/bin/defaults write /Users/"$CURRENT_USER"/Library/Preferences/.GlobalPreferences AppleShowAllExtensions -bool true

exit 0;