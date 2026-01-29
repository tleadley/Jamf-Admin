#!/bin/zsh

: HEADER = <<'EOL'

██████╗ ██╗ ██████╗ ██╗████████╗ █████╗ ██╗          ██████╗ ██████╗ ███╗   ██╗██╗   ██╗███████╗██████╗  ██████╗ ███████╗███╗   ██╗ ██████╗███████╗
██╔══██╗██║██╔════╝ ██║╚══██╔══╝██╔══██╗██║         ██╔════╝██╔═══██╗████╗  ██║██║   ██║██╔════╝██╔══██╗██╔════╝ ██╔════╝████╗  ██║██╔════╝██╔════╝
██║  ██║██║██║  ███╗██║   ██║   ███████║██║         ██║     ██║   ██║██╔██╗ ██║██║   ██║█████╗  ██████╔╝██║  ███╗█████╗  ██╔██╗ ██║██║     █████╗
██║  ██║██║██║   ██║██║   ██║   ██╔══██║██║         ██║     ██║   ██║██║╚██╗██║╚██╗ ██╔╝██╔══╝  ██╔══██╗██║   ██║██╔══╝  ██║╚██╗██║██║     ██╔══╝
██████╔╝██║╚██████╔╝██║   ██║   ██║  ██║███████╗    ╚██████╗╚██████╔╝██║ ╚████║ ╚████╔╝ ███████╗██║  ██║╚██████╔╝███████╗██║ ╚████║╚██████╗███████╗
╚═════╝ ╚═╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝


       DESCRIPTION: This script generates a list of CIDR notation Network Ranges for use in the network isolation procedure

      REQUIREMENTS:
                    Jamf Pro
                    macOS Clients running version 10.13 or later

          FEATURES:
        Written by: Trevor Leadley | Digital Convergence
  Revision History:
        YYYY-MM-DD: Details
        2025-03-14: Created script

 For more information, visit https://github.com/digitalconvergenceca/Mac_Admin_Jamf/tree/main/Scripts


EOL

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Function to perform nslookup and extract IP addresses
get_ips() {
  local hostname="$1"
  local ips=()

  # Use nslookup to find IP addresses
  nslookup "$hostname" | \
    awk '/Address: / {print $2}' | \
    while read -r ip; do
      # Validate IP address format
      if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        ips+=("$ip")
      fi
    done

  # Check if any IPs were found
  if [ ${#ips[@]} -eq 0 ]; then
    echo "No IP addresses found for $hostname"
    return 1 # Return non-zero to indicate failure
  else
    # echo "Found IPs: ${ips[*]}" # echo the IPs found
    printf "%s\n" "${ips[@]}" # return the ips, one per line.
  fi
}

# Function to perform whois lookup and extract NetRange and CIDR
get_net_info() {
  local ip="$1"
  local netrange=""
  local cidr=""

  # Use whois to find NetRange and CIDR
  whois "$ip" | \
    awk '
      /^NetRange:/ { netrange = $2 }
      /^CIDR:/     { cidr = $2 }
      END {
        if (netrange != "" && cidr != "") {
          printf "%s,%s\n", netrange, cidr
        } else {
          printf ",\n" # Print commas even if no data found
        }
      }
    '
}

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

echo "Hostname,IP Addresses,CIDR" # header

# Loop through each hostname in the array
for hostname in "${hostnames[@]}"; do
  ips=($(get_ips "$hostname")) # get ips for the hostname
  if [ ${#ips[@]} -eq 0 ]; then
    continue # Skip to the next hostname if no IPs found
  fi
  # Loop through each IP address
  for ip in "${ips[@]}"; do
    net_info=$(get_net_info "$ip")
    IFS=',' read -r netrange cidr <<< "$net_info"
    echo "$hostname,$ip,$cidr"
  done
done

exit 0;
