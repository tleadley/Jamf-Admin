#!/bin/sh
#/bin/echo 'Defaults timestamp_timeout=0' | /usr/bin/sudo EDITOR='tee -a' visudo

FILE=/etc/sudoers.d/CIS_LEVEL1
FOLDER=/etc/sudoers.d

if [ ! -f $FOLDER ]
then 
     /bin/echo 'Defaults timestamp_timeout=0' | /usr/bin/sudo EDITOR='tee -a' visudo
     exit 0;
fi

if [ ! -f $FILE ]
then
     /bin/echo 'Defaults timestamp_timeout=0' >> /tmp/CIS_LEVEL1
     /usr/bin/sudo cp /tmp/CIS_LEVEL1 /etc/sudoers.d/
     /usr/bin/sudo /usr/sbin/chown root:wheel /etc/sudoers.d/CIS_LEVEL1
     /usr/bin/sudo chmod 644 /etc/sudoers.d/CIS_LEVEL1
     rm /tmp/CIS_LEVEL1
fi

exit 0