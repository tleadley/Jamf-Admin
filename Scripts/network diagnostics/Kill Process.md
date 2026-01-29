# Kill Process Script

## Description

This script is designed to terminate a specific process named in the Jamf Pro variable on MacOS devices managed by Jamf Pro. It also flushes the DNS cache.

## Requirements

* Jamf Pro
* macOS Clients running version 10.13 or later

## Usage

1. Save this script as a file (e.g., `kill_process.sh`)
2. Make the file executable using `chmod +x kill_process.sh`
3. Run the script on your device using `./kill_process.sh`

## Revision History

* 2024-12-16: Created script
