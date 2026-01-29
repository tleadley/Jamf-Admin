#!/bin/sh
#This script is built to be used for a workaround of a PI known as PI111500.

defaults delete ~/Library/Preferences/com.jamf.connect.state.plist PasswordCurrent
defaults delete ~/Library/Preferences/com.jamf.connect.state.plist

exit 0
#end of script