#!/bin/bash

sudo /usr/bin/sed -i '' "s/\* file \/var\/log\/install.log.*/\* file \/var\/log \/install.log format='\$\(\(Time\)\(JZ\)\) \$Host \$\(Sender\)\[\$\(PID\\)\]: \$Message' rotate=utc compress file_max=50M size_only ttl=365/g" /etc/asl/com.apple.install >/dev/null