#!/bin/sh
application="$4"

#user=`ls -l /dev/console | awk '/ / { print $3 }'`

# remove brew cask apps from quarantine
xattr -d com.apple.quarantine /Applications/$application || true
exit 0