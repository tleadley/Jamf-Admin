# Network Diagnostics Script

This script runs basic network diagnostics on macOS clients.

### Description

Runs various network-related commands, including `lsof`, `netstat`, and `traceroute`.

### Requirements

* Jamf Pro
* macOS Clients running version 10.13 or later

### Usage

1. Save this script to a file named `network_diags.sh`.
2. Make the script executable with `chmod +x network_diags.sh`.
3. Run the script by executing `./network_diags.sh` in the terminal.

### Output

The script will print various network-related output, including:

* Network socket outputs
* Filters some infromation for specified applications (`$process_name`)
* Active network connections and established/listening connections
* Active network interface stats
* Traceroute to a specific host (`$hostname`)
* Name server lookup for that host
* Generates a current routing table for the endpoint
* Contents of `/etc/hosts` to check for misconfiguartions

### Revision History

* 2024-12-16: Created script
