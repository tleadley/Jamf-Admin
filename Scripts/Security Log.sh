#!/bin/bash

FILE=/etc/security/audit_control.bak

if test -f "$FILE"; then
    rm -f /etc/security/audit_control.bak
fi

cp /etc/security/audit_control /etc/security/audit_control.bak
/usr/bin/sed -i '' 's/^expire-after.*/expire-after:60d OR 1G/' /etc/security/audit_control.bak
rm -f /etc/security/audit_control
cp /etc/security/audit_control.bak /etc/security/audit_control
chmod 400 /etc/security/audit_control
/usr/sbin/audit -s