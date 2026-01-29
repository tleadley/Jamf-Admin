#!/bin/bash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#
#
# DESCRIPTION:
# This is the script is used to kill a process on a remote computer
#
#
# REQUIREMENTS:
#           - Jamf Pro
#           - macOS Clients running version 10.13 or later
#
# FEATURES:
#
# For more information, visit https://github.com/digitalconvergenceca/Mac_Admin_Jamf/tree/main/Scripts
#
# Written by: Trevor Leadley | Digital Convergence
#
#
# Revision History:
# YYYY-MM-DD: Details
# 2024-12-16: Created script
#
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Use pgrep to search for a process by name and store its PID in a variable
process_name=$4
pids=$(pgrep -f "$process_name")

# Validate output as non-empty array
if [ ${#pids[@]} -gt 0 ]; then
    # Iterate over each PID in the array and kill the corresponding process
    for pid in "${pids[@]}"; do
        if kill -9 $pid; then
            echo "Process(es) $process_name terminated successfully."
        else
            echo "Failed to terminate process(es). Is it running?"
        fi
    done
# If no matching process is found, inform the user and exit
else
    echo "$process_name not found. Please verify the process name."
fi

#Kill and flushDNS cache
killall -HUP mDNSResponder
killall mDNSResponderHelper
dscacheutil -flushcache

exit 0
