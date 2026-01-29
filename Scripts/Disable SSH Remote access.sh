#!/bin/sh

/usr/bin/sudo /bin/launchctl disable system/com.openssh.sshd

if [ -d /System/Library/LaunchDaemons/ssh.plist ]; then

/usr/bin/sudo /bin/launchctl unload /System/Library/LaunchDaemons/ssh.plist >/dev/null

fi

/usr/bin/sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off >/dev/null
/usr/bin/sudo systemsetup -f -setremotelogin off >/dev/null

exit 0;