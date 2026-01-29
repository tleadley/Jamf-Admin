#!/bin/bash

# Target directory and file path for the newsyslog configuration
CONFIG_DIR="/etc/newsyslog.d"
CONFIG_FILE="${CONFIG_DIR}/super_logs.conf"

# The newsyslog configuration content for the super script log archives:
# Fields: LogFile [Mode] [Count] [Size] [When] [Flags] [Path to Command]
# This line rotates when the system checks (typically daily), keeps a max of 30 archives, 
# and deletes files older than 90 days.
NEWSYSLOG_CONFIG='/Library/Management/super/logs-archive/*.zip 644 30 * $W0T0 90Z'

# Overwrite the existing configuration file with the new content
# The single > ensures that if $CONFIG_FILE exists, its contents are completely replaced.
echo "$NEWSYSLOG_CONFIG" > "$CONFIG_FILE"

# Set ownership and permissions (must be root:wheel and 644)
/usr/sbin/chown root:wheel "$CONFIG_FILE"
/bin/chmod 644 "$CONFIG_FILE"

# NOTE: logrotate is usually run daily by a launchd job (like /etc/periodic/daily/400.logrotate). 
# This script only deploys the config; the system handles the schedule.

exit 0
