#!/bin/zsh

: HEADER = <<'EOL'

██████╗ ██╗ ██████╗ ██╗████████╗ █████╗ ██╗          ██████╗ ██████╗ ███╗   ██╗██╗   ██╗███████╗██████╗  ██████╗ ███████╗███╗   ██╗ ██████╗███████╗
██╔══██╗██║██╔════╝ ██║╚══██╔══╝██╔══██╗██║         ██╔════╝██╔═══██╗████╗  ██║██║   ██║██╔════╝██╔══██╗██╔════╝ ██╔════╝████╗  ██║██╔════╝██╔════╝
██║  ██║██║██║  ███╗██║   ██║   ███████║██║         ██║     ██║   ██║██╔██╗ ██║██║   ██║█████╗  ██████╔╝██║  ███╗█████╗  ██╔██╗ ██║██║     █████╗
██║  ██║██║██║   ██║██║   ██║   ██╔══██║██║         ██║     ██║   ██║██║╚██╗██║╚██╗ ██╔╝██╔══╝  ██╔══██╗██║   ██║██╔══╝  ██║╚██╗██║██║     ██╔══╝
██████╔╝██║╚██████╔╝██║   ██║   ██║  ██║███████╗    ╚██████╗╚██████╔╝██║ ╚████║ ╚████╔╝ ███████╗██║  ██║╚██████╔╝███████╗██║ ╚████║╚██████╗███████╗
╚═════╝ ╚═╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝


       DESCRIPTION: This script creates a list of hosts and their IP's used to communicate with the Jamf Infrastructure

      REQUIREMENTS:
                    Jamf Pro
                    macOS Clients running version 10.13 or later

          FEATURES:
        Written by: Trevor Leadley | Digital Convergence
  Revision History:
        YYYY-MM-DD: Details
        2025-03-27: Created script

 For more information, visit https://github.com/digitalconvergenceca/Mac_Admin_Jamf/tree/main/Scripts


EOL

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Check if an input file with hostnames is provided
if [ -z "$1" ]; then
  echo "Usage: $0 [output_file]"
  echo "Default output file is ips.txt if not specified."
fi

# List of hostanmes to lookup ips for the Jamf Platform
hostnames=(
"download.jra.services.jamfcloud.com"
"experience.jamfcloud.com"
"files.jra.services.jamfcloud.com"
"jamf.com"
"prod-use1-jamf-jpt-configs.s3.amazonaws.com"
"sentry.pub.jamf.build"
"shared-jamf-jpt-generic-packages.s3.amazonaws.com"
"us.jra.services.jamfcloud.com"
"use1-jcds.services.jamfcloud.com"
"use1-jcdsdownloads.services.jamfcloud.com"
"digitalconvergence.jamfcloud.com"
)

output_list="${1:-ips.txt}" # Default output file is ips.txt if not specified

# Process each hostname in the file
for hostname in "${hostnames[@]}"; do
  # Perform nslookup and extract IP addresses, excluding those with #53
  ips=$(nslookup "$hostname" | grep "Address:" | awk '!/:#[0-9]+$/ {print $2"\t""'"$hostname"'"}')

  # Append the IP and hostname to the output file
  if [ -n "$ips" ]; then
    echo "$ips" >> "$output_list"
    # Debug output
    # echo "IP addresses for '$hostname' appended to '$output_list'."
  else
    echo "No IP addresses found for '$hostname'."
  fi
done

echo "Processing of all hostnames complete. Results are in '$output_list'."

exit 0;
