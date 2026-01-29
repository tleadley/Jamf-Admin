#!/bin/bash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#
# DESCRIPTION:
#
# This script runs some basic network diagnostics for the specified application, looking for processes and ports of interest.
#
#
# REQUIREMENTS:
#           - Jamf Pro
#           - macOS Clients running version 10.13 or later
#
# USAGE:
#
#  ./network_diags.sh

# Options:
#  None
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
hostname=$5
pids=$(pgrep -f scthost | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')

# Function to run lsof and netstat commands
run_diagnostics() {
    echo "Showing all network socket outputs"
    lsof -i 4 -a -p $pids || (echo "No network sockets found"; exit 1) && echo

    echo "Showing all active network socket connections"
    netstat -a | grep "$process_name" || (echo "No active sockets found"; exit 1) && echo

    echo "List all Established and Listening connections"
    netstat -an | awk '/LISTEN/ {print} /ESTABLISHED/ {print}' || (echo "No connection found"; exit 1) && echo
    
    echo "List active network interface stats"
    device=$(networksetup -listnetworkserviceorder | grep 'Wi-Fi, Device' | sed -E "s/.*(en[0-9]).*/\1/")
    ipconfig getpacket $device || (echo "No socket found"; exit 1) && echo

    echo "Trace route to host"
    traceroute $hostname || (echo "Destination host not found"; exit 1) && echo

    echo "Name server lookup for host"
    nslookup $hostname || (echo "Host name not found"; exit 1) && echo

    echo "Show network routes"
    netstat -nr -f inet && echo

}

# Run diagnostics
echo "Showing the output of the host file"
cat /etc/hosts || (echo "Failed to print contents of /etc/hosts"; exit 1) && echo

run_diagnostics

echo "Script completed with $?"

exit 0;
