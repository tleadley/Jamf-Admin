#!/bin/zsh

: HEADER = <<'EOL'

██████╗ ██╗ ██████╗ ██╗████████╗ █████╗ ██╗          ██████╗ ██████╗ ███╗   ██╗██╗   ██╗███████╗██████╗  ██████╗ ███████╗███╗   ██╗ ██████╗███████╗
██╔══██╗██║██╔════╝ ██║╚══██╔══╝██╔══██╗██║         ██╔════╝██╔═══██╗████╗  ██║██║   ██║██╔════╝██╔══██╗██╔════╝ ██╔════╝████╗  ██║██╔════╝██╔════╝
██║  ██║██║██║  ███╗██║   ██║   ███████║██║         ██║     ██║   ██║██╔██╗ ██║██║   ██║█████╗  ██████╔╝██║  ███╗█████╗  ██╔██╗ ██║██║     █████╗
██║  ██║██║██║   ██║██║   ██║   ██╔══██║██║         ██║     ██║   ██║██║╚██╗██║╚██╗ ██╔╝██╔══╝  ██╔══██╗██║   ██║██╔══╝  ██║╚██╗██║██║     ██╔══╝
██████╔╝██║╚██████╔╝██║   ██║   ██║  ██║███████╗    ╚██████╗╚██████╔╝██║ ╚████║ ╚████╔╝ ███████╗██║  ██║╚██████╔╝███████╗██║ ╚████║╚██████╗███████╗
╚═════╝ ╚═╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝


       DESCRIPTION: This script modifies the host file temporily to allow the device to communicate with Jamf Infrastructure

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


FILE="/etc/hosts.bak"

[ -e "$FILE" ] && rm $FILE

cp /etc/hosts $FILE

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

output_list="/etc/hosts" # Default output file is ips.txt if not specified

# Process each hostname in the file
for hostname in "${hostnames[@]}"; do
  # Perform nslookup and extract IP addresses, excluding those with #53
  ips=$(nslookup "$hostname" | grep "Address:" | awk '!/:#[0-9]+$/ {print $2"\t""'"$hostname"'"}')

  # Append the IP and hostname to the output file
  if [ -n "$ips" ]; then
    echo "$ips" >> "$output_list"
    # echo "IP addresses for '$hostname' appended to '$output_list'."
  else
    echo "No IP addresses found for '$hostname'."
  fi
done

exit 0
