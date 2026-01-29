#!/bin/zsh

##  This script will attempt to audit all of the settings based on the installed profile.

##  This script is provided as-is and should be fully tested on a system that is not in a production environment.

###################  Variables  ###################

pwpolicy_file=""

###################  DEBUG MODE - hold shift when running the script  ###################

shiftKeyDown=$(osascript -l JavaScript -e "ObjC.import('Cocoa'); ($.NSEvent.modifierFlags & $.NSEventModifierFlagShift) > 1")

if [[ $shiftKeyDown == "true" ]]; then
    echo "-----DEBUG-----"
    set -o xtrace -o verbose
fi

###################  COMMANDS START BELOW THIS LINE  ###################

## Must be run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# path to PlistBuddy
plb="/usr/libexec/PlistBuddy"

# get the currently logged in user
CURRENT_USER=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }')
CURR_USER_UID=$(/usr/bin/id -u $CURRENT_USER)

# get system architecture
arch=$(/usr/bin/arch)

# configure colors for text
RED='\e[31m'
STD='\e[39m'
GREEN='\e[32m'
YELLOW='\e[33m'

audit_plist="/Library/Preferences/org.cis_lvl1.audit.plist"
audit_log="/Library/Logs/cis_lvl1_baseline.log"

# pause function
pause(){
vared -p "Press [Enter] key to continue..." -c fackEnterKey
}

ask() {
    # if fix flag is passed, assume YES for everything
    if [[ $fix ]] || [[ $cfc ]]; then
        return 0
    fi

    while true; do

        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        # Ask the question - use /dev/tty in case stdin is redirected from somewhere else
        printf "${YELLOW} $1 [$prompt] ${STD}"
        read REPLY

        # Default?
        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi

        # Check if the reply is valid
        case "$REPLY" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}

# function to display menus
show_menus() {
    lastComplianceScan=$(defaults read /Library/Preferences/org.cis_lvl1.audit.plist lastComplianceCheck)

    if [[ $lastComplianceScan == "" ]];then
        lastComplianceScan="No scans have been run"
    fi

    /usr/bin/clear
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "        M A I N - M E N U"
    echo "  macOS Security Compliance Tool"
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "Last compliance scan: $lastComplianceScan
"
    echo "1. View Last Compliance Report"
    echo "2. Run New Compliance Scan"
    echo "3. Run Commands to remediate non-compliant settings"
    echo "4. Exit"
}

# function to read options
read_options(){
    local choice
    vared -p "Enter choice [ 1 - 4 ] " -c choice
    case $choice in
        1) view_report ;;
        2) run_scan ;;
        3) run_fix ;;
        4) exit 0;;
        *) echo -e "${RED}Error: please choose an option 1-4...${STD}" && sleep 1
    esac
}

# function to reset and remove plist file.  Used to clear out any previous findings
reset_plist(){
    echo "Clearing results from /Library/Preferences/org.cis_lvl1.audit.plist"
    defaults delete /Library/Preferences/org.cis_lvl1.audit.plist
}

# Generate the Compliant and Non-Compliant counts. Returns: Array (Compliant, Non-Compliant)
compliance_count(){
    compliant=0
    non_compliant=0

    results=$(/usr/libexec/PlistBuddy -c "Print" /Library/Preferences/org.cis_lvl1.audit.plist)

    while IFS= read -r line; do
        if [[ "$line" =~ "finding = false" ]]; then
            compliant=$((compliant+1))
        fi
        if [[ "$line" =~ "finding = true" ]]; then
            non_compliant=$((non_compliant+1))
        fi
    done <<< "$results"

    # Enable output of just the compliant or non-compliant numbers.
    if [[ $1 = "compliant" ]]
    then
        echo $compliant
    elif [[ $1 = "non-compliant" ]]
    then
        echo $non_compliant
    else # no matching args output the array
        array=($compliant $non_compliant)
        echo ${array[@]}
    fi
}

exempt_count(){
    exempt=0

    if [[ -e "/Library/Managed Preferences/org.cis_lvl1.audit.plist" ]];then
        mscp_prefs="/Library/Managed Preferences/org.cis_lvl1.audit.plist"
    else
        mscp_prefs="/Library/Preferences/org.cis_lvl1.audit.plist"
    fi

    results=$(/usr/libexec/PlistBuddy -c "Print" "$mscp_prefs")

    while IFS= read -r line; do
        if [[ "$line" =~ "exempt = true" ]]; then
            exempt=$((exempt+1))
        fi
    done <<< "$results"

    echo $exempt
}


generate_report(){
    count=($(compliance_count))
    exempt_rules=$(exempt_count)
    compliant=${count[1]}
    non_compliant=${count[2]}

    total=$((non_compliant + compliant - exempt_rules))
    percentage=$(printf %.2f $(( compliant * 100. / total )) )
    echo
    echo "Number of tests passed: ${GREEN}$compliant${STD}"
    echo "Number of test FAILED: ${RED}$non_compliant${STD}"
    echo "Number of exempt rules: ${YELLOW}$exempt_rules${STD}"
    echo "You are ${YELLOW}$percentage%${STD} percent compliant!"
    pause
}

view_report(){

    if [[ $lastComplianceScan == "No scans have been run" ]];then
        echo "no report to run, please run new scan"
        pause
    else
        generate_report
    fi
}

# Designed for use with MDM - single unformatted output of the Compliance Report
generate_stats(){
    count=($(compliance_count))
    compliant=${count[1]}
    non_compliant=${count[2]}

    total=$((non_compliant + compliant))
    percentage=$(printf %.2f $(( compliant * 100. / total )) )
    echo "PASSED: $compliant FAILED: $non_compliant, $percentage percent compliant!"
}

run_scan(){
# append to existing logfile
if [[ $(/usr/bin/tail -n 1 "$audit_log" 2>/dev/null) = *"Remediation complete" ]]; then
 	echo "$(date -u) Beginning cis_lvl1 baseline scan" >> "$audit_log"
else
 	echo "$(date -u) Beginning cis_lvl1 baseline scan" > "$audit_log"
fi

# run mcxrefresh
/usr/bin/mcxrefresh -u $CURR_USER_UID

# write timestamp of last compliance check
/usr/bin/defaults write "$audit_plist" lastComplianceCheck "$(date)"
    
#####----- Rule: audit_auditd_enabled -----#####
## Addresses the following NIST 800-53 controls: 
# * AU-12, AU-12(1), AU-12(3)
# * AU-14(1)
# * AU-3, AU-3(1)
# * AU-8
# * CM-5(1)
# * MA-4(1)
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: audit_auditd_enabled ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/bin/launchctl list | /usr/bin/grep -c com.apple.auditd
)
    # expected result {'integer': 1}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('audit_auditd_enabled'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('audit_auditd_enabled'))["exempt_reason"]
EOS
)

    if [[ $result_value == "1" ]]; then
        echo "$(date -u) audit_auditd_enabled passed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" audit_auditd_enabled -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - audit_auditd_enabled passed (Result: $result_value, Expected: "{'integer': 1}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) audit_auditd_enabled failed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" audit_auditd_enabled -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - audit_auditd_enabled failed (Result: $result_value, Expected: "{'integer': 1}")"
        else
            echo "$(date -u) audit_auditd_enabled failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" audit_auditd_enabled -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - audit_auditd_enabled failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) audit_auditd_enabled does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" audit_auditd_enabled -dict-add finding -bool NO
fi
    
#####----- Rule: audit_retention_configure -----#####
## Addresses the following NIST 800-53 controls: 
# * AU-11
# * AU-4
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: audit_retention_configure ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/awk -F: '/expire-after/{print $2}' /etc/security/audit_control
)
    # expected result {'string': '60d or 1g'}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('audit_retention_configure'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('audit_retention_configure'))["exempt_reason"]
EOS
)

    if [[ $result_value == "60d OR 1G" ]]; then
        echo "$(date -u) audit_retention_configure passed (Result: $result_value, Expected: "{'string': '60d or 1g'}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" audit_retention_configure -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - audit_retention_configure passed (Result: $result_value, Expected: "{'string': '60d or 1g'}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) audit_retention_configure failed (Result: $result_value, Expected: "{'string': '60d or 1g'}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" audit_retention_configure -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - audit_retention_configure failed (Result: $result_value, Expected: "{'string': '60d or 1g'}")"
        else
            echo "$(date -u) audit_retention_configure failed (Result: $result_value, Expected: "{'string': '60d or 1g'}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" audit_retention_configure -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - audit_retention_configure failed (Result: $result_value, Expected: "{'string': '60d or 1g'}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) audit_retention_configure does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" audit_retention_configure -dict-add finding -bool NO
fi
    
#####----- Rule: os_airdrop_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * AC-20
# * AC-3
# * CM-7, CM-7(1)
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: os_airdrop_disable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/osascript -l JavaScript << EOS
$.NSUserDefaults.alloc.initWithSuiteName('com.apple.applicationaccess')\
.objectForKey('allowAirDrop').js
EOS
)
    # expected result {'string': 'false'}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_airdrop_disable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_airdrop_disable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "false" ]]; then
        echo "$(date -u) os_airdrop_disable passed (Result: $result_value, Expected: "{'string': 'false'}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" os_airdrop_disable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - os_airdrop_disable passed (Result: $result_value, Expected: "{'string': 'false'}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) os_airdrop_disable failed (Result: $result_value, Expected: "{'string': 'false'}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_airdrop_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_airdrop_disable failed (Result: $result_value, Expected: "{'string': 'false'}")"
        else
            echo "$(date -u) os_airdrop_disable failed (Result: $result_value, Expected: "{'string': 'false'}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_airdrop_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_airdrop_disable failed (Result: $result_value, Expected: "{'string': 'false'}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) os_airdrop_disable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" os_airdrop_disable -dict-add finding -bool NO
fi
    
#####----- Rule: os_gatekeeper_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * CM-14
# * CM-5
# * SI-3
# * SI-7(1), SI-7(15)
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: os_gatekeeper_enable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/sbin/spctl --status | /usr/bin/grep -c "assessments enabled"
)
    # expected result {'integer': 1}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_gatekeeper_enable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_gatekeeper_enable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "1" ]]; then
        echo "$(date -u) os_gatekeeper_enable passed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" os_gatekeeper_enable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - os_gatekeeper_enable passed (Result: $result_value, Expected: "{'integer': 1}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) os_gatekeeper_enable failed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_gatekeeper_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_gatekeeper_enable failed (Result: $result_value, Expected: "{'integer': 1}")"
        else
            echo "$(date -u) os_gatekeeper_enable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_gatekeeper_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_gatekeeper_enable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) os_gatekeeper_enable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" os_gatekeeper_enable -dict-add finding -bool NO
fi
    
#####----- Rule: os_power_nap_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * CM-7, CM-7(1)
rule_arch="i386"
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: os_power_nap_disable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/pmset -g custom | /usr/bin/awk '/powernap/ { sum+=$2 } END {print sum}'
)
    # expected result {'integer': 0}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_power_nap_disable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_power_nap_disable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "0" ]]; then
        echo "$(date -u) os_power_nap_disable passed (Result: $result_value, Expected: "{'integer': 0}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" os_power_nap_disable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - os_power_nap_disable passed (Result: $result_value, Expected: "{'integer': 0}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) os_power_nap_disable failed (Result: $result_value, Expected: "{'integer': 0}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_power_nap_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_power_nap_disable failed (Result: $result_value, Expected: "{'integer': 0}")"
        else
            echo "$(date -u) os_power_nap_disable failed (Result: $result_value, Expected: "{'integer': 0}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_power_nap_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_power_nap_disable failed (Result: $result_value, Expected: "{'integer': 0}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) os_power_nap_disable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" os_power_nap_disable -dict-add finding -bool NO
fi
    
#####----- Rule: os_safari_open_safe_downloads_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: os_safari_open_safe_downloads_disable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/profiles -P -o stdout | /usr/bin/grep -c 'AutoOpenSafeDownloads = 0' | /usr/bin/awk '{ if ($1 >= 1) {print "1"} else {print "0"}}'
)
    # expected result {'integer': 1}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_safari_open_safe_downloads_disable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_safari_open_safe_downloads_disable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "1" ]]; then
        echo "$(date -u) os_safari_open_safe_downloads_disable passed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" os_safari_open_safe_downloads_disable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - os_safari_open_safe_downloads_disable passed (Result: $result_value, Expected: "{'integer': 1}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) os_safari_open_safe_downloads_disable failed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_safari_open_safe_downloads_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_safari_open_safe_downloads_disable failed (Result: $result_value, Expected: "{'integer': 1}")"
        else
            echo "$(date -u) os_safari_open_safe_downloads_disable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_safari_open_safe_downloads_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_safari_open_safe_downloads_disable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) os_safari_open_safe_downloads_disable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" os_safari_open_safe_downloads_disable -dict-add finding -bool NO
fi
    
#####----- Rule: os_safari_prevent_cross-site_tracking_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: os_safari_prevent_cross-site_tracking_enable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/profiles -P -o stdout | /usr/bin/grep -cE '"WebKitPreferences.storageBlockingPolicy" = 1|"WebKitStorageBlockingPolicy" = 1|"BlockStoragePolicy" =2' | /usr/bin/awk '{ if ($1 >= 1) {print "1"} else {print "0"}}'
)
    # expected result {'integer': 1}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_safari_prevent_cross-site_tracking_enable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_safari_prevent_cross-site_tracking_enable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "1" ]]; then
        echo "$(date -u) os_safari_prevent_cross-site_tracking_enable passed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" os_safari_prevent_cross-site_tracking_enable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - os_safari_prevent_cross-site_tracking_enable passed (Result: $result_value, Expected: "{'integer': 1}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) os_safari_prevent_cross-site_tracking_enable failed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_safari_prevent_cross-site_tracking_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_safari_prevent_cross-site_tracking_enable failed (Result: $result_value, Expected: "{'integer': 1}")"
        else
            echo "$(date -u) os_safari_prevent_cross-site_tracking_enable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_safari_prevent_cross-site_tracking_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_safari_prevent_cross-site_tracking_enable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) os_safari_prevent_cross-site_tracking_enable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" os_safari_prevent_cross-site_tracking_enable -dict-add finding -bool NO
fi
    
#####----- Rule: os_safari_show_full_website_address_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: os_safari_show_full_website_address_enable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/profiles -P -o stdout | /usr/bin/grep -c 'ShowFullURLInSmartSearchField = 1' | /usr/bin/awk '{ if ($1 >= 1) {print "1"} else {print "0"}}'
)
    # expected result {'integer': 1}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_safari_show_full_website_address_enable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_safari_show_full_website_address_enable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "1" ]]; then
        echo "$(date -u) os_safari_show_full_website_address_enable passed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" os_safari_show_full_website_address_enable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - os_safari_show_full_website_address_enable passed (Result: $result_value, Expected: "{'integer': 1}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) os_safari_show_full_website_address_enable failed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_safari_show_full_website_address_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_safari_show_full_website_address_enable failed (Result: $result_value, Expected: "{'integer': 1}")"
        else
            echo "$(date -u) os_safari_show_full_website_address_enable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_safari_show_full_website_address_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_safari_show_full_website_address_enable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) os_safari_show_full_website_address_enable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" os_safari_show_full_website_address_enable -dict-add finding -bool NO
fi
    
#####----- Rule: os_safari_warn_fraudulent_website_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: os_safari_warn_fraudulent_website_enable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/profiles -P -o stdout | /usr/bin/grep -c 'WarnAboutFraudulentWebsites = 1' | /usr/bin/awk '{ if ($1 >= 1) {print "1"} else {print "0"}}'
)
    # expected result {'integer': 1}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_safari_warn_fraudulent_website_enable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_safari_warn_fraudulent_website_enable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "1" ]]; then
        echo "$(date -u) os_safari_warn_fraudulent_website_enable passed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" os_safari_warn_fraudulent_website_enable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - os_safari_warn_fraudulent_website_enable passed (Result: $result_value, Expected: "{'integer': 1}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) os_safari_warn_fraudulent_website_enable failed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_safari_warn_fraudulent_website_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_safari_warn_fraudulent_website_enable failed (Result: $result_value, Expected: "{'integer': 1}")"
        else
            echo "$(date -u) os_safari_warn_fraudulent_website_enable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_safari_warn_fraudulent_website_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_safari_warn_fraudulent_website_enable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) os_safari_warn_fraudulent_website_enable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" os_safari_warn_fraudulent_website_enable -dict-add finding -bool NO
fi
    
#####----- Rule: os_show_filename_extensions_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: os_show_filename_extensions_enable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/sudo -u "$CURRENT_USER" /usr/bin/defaults read .GlobalPreferences AppleShowAllExtensions 2>/dev/null
)
    # expected result {'boolean': 1}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_show_filename_extensions_enable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_show_filename_extensions_enable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "1" ]]; then
        echo "$(date -u) os_show_filename_extensions_enable passed (Result: $result_value, Expected: "{'boolean': 1}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" os_show_filename_extensions_enable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - os_show_filename_extensions_enable passed (Result: $result_value, Expected: "{'boolean': 1}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) os_show_filename_extensions_enable failed (Result: $result_value, Expected: "{'boolean': 1}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_show_filename_extensions_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_show_filename_extensions_enable failed (Result: $result_value, Expected: "{'boolean': 1}")"
        else
            echo "$(date -u) os_show_filename_extensions_enable failed (Result: $result_value, Expected: "{'boolean': 1}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_show_filename_extensions_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_show_filename_extensions_enable failed (Result: $result_value, Expected: "{'boolean': 1}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) os_show_filename_extensions_enable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" os_show_filename_extensions_enable -dict-add finding -bool NO
fi
    
#####----- Rule: os_sip_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * AC-3
# * AU-9, AU-9(3)
# * CM-5, CM-5(6)
# * SC-4
# * SI-2
# * SI-7
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: os_sip_enable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/csrutil status | /usr/bin/grep -c 'System Integrity Protection status: enabled.'
)
    # expected result {'integer': 1}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_sip_enable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_sip_enable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "1" ]]; then
        echo "$(date -u) os_sip_enable passed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" os_sip_enable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - os_sip_enable passed (Result: $result_value, Expected: "{'integer': 1}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) os_sip_enable failed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_sip_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_sip_enable failed (Result: $result_value, Expected: "{'integer': 1}")"
        else
            echo "$(date -u) os_sip_enable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_sip_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_sip_enable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) os_sip_enable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" os_sip_enable -dict-add finding -bool NO
fi
    
#####----- Rule: os_terminal_secure_keyboard_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: os_terminal_secure_keyboard_enable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/osascript -l JavaScript << EOS
$.NSUserDefaults.alloc.initWithSuiteName('com.apple.Terminal')\
.objectForKey('SecureKeyboardEntry').js
EOS
)
    # expected result {'string': 'true'}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_terminal_secure_keyboard_enable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_terminal_secure_keyboard_enable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "true" ]]; then
        echo "$(date -u) os_terminal_secure_keyboard_enable passed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" os_terminal_secure_keyboard_enable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - os_terminal_secure_keyboard_enable passed (Result: $result_value, Expected: "{'string': 'true'}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) os_terminal_secure_keyboard_enable failed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_terminal_secure_keyboard_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_terminal_secure_keyboard_enable failed (Result: $result_value, Expected: "{'string': 'true'}")"
        else
            echo "$(date -u) os_terminal_secure_keyboard_enable failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_terminal_secure_keyboard_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - os_terminal_secure_keyboard_enable failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) os_terminal_secure_keyboard_enable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" os_terminal_secure_keyboard_enable -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_airplay_receiver_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * CM-7, CM-7(1)
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_airplay_receiver_disable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/osascript -l JavaScript << EOS
$.NSUserDefaults.alloc.initWithSuiteName('com.apple.applicationaccess')\
.objectForKey('allowAirPlayIncomingRequests').js
EOS
)
    # expected result {'string': 'false'}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_airplay_receiver_disable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_airplay_receiver_disable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "false" ]]; then
        echo "$(date -u) system_settings_airplay_receiver_disable passed (Result: $result_value, Expected: "{'string': 'false'}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_airplay_receiver_disable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - system_settings_airplay_receiver_disable passed (Result: $result_value, Expected: "{'string': 'false'}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_airplay_receiver_disable failed (Result: $result_value, Expected: "{'string': 'false'}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_airplay_receiver_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_airplay_receiver_disable failed (Result: $result_value, Expected: "{'string': 'false'}")"
        else
            echo "$(date -u) system_settings_airplay_receiver_disable failed (Result: $result_value, Expected: "{'string': 'false'}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_airplay_receiver_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_airplay_receiver_disable failed (Result: $result_value, Expected: "{'string': 'false'}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_airplay_receiver_disable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_airplay_receiver_disable -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_bluetooth_menu_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_bluetooth_menu_enable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/osascript -l JavaScript << EOS
$.NSUserDefaults.alloc.initWithSuiteName('com.apple.controlcenter')\
.objectForKey('Bluetooth').js
EOS
)
    # expected result {'integer': 18}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_bluetooth_menu_enable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_bluetooth_menu_enable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "18" ]]; then
        echo "$(date -u) system_settings_bluetooth_menu_enable passed (Result: $result_value, Expected: "{'integer': 18}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_bluetooth_menu_enable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - system_settings_bluetooth_menu_enable passed (Result: $result_value, Expected: "{'integer': 18}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_bluetooth_menu_enable failed (Result: $result_value, Expected: "{'integer': 18}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_bluetooth_menu_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_bluetooth_menu_enable failed (Result: $result_value, Expected: "{'integer': 18}")"
        else
            echo "$(date -u) system_settings_bluetooth_menu_enable failed (Result: $result_value, Expected: "{'integer': 18}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_bluetooth_menu_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_bluetooth_menu_enable failed (Result: $result_value, Expected: "{'integer': 18}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_bluetooth_menu_enable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_bluetooth_menu_enable -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_bluetooth_sharing_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * AC-18(4)
# * AC-3
# * CM-7, CM-7(1)
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_bluetooth_sharing_disable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/sudo -u "$CURRENT_USER" /usr/bin/defaults -currentHost read com.apple.Bluetooth PrefKeyServicesEnabled
)
    # expected result {'boolean': 0}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_bluetooth_sharing_disable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_bluetooth_sharing_disable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "0" ]]; then
        echo "$(date -u) system_settings_bluetooth_sharing_disable passed (Result: $result_value, Expected: "{'boolean': 0}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_bluetooth_sharing_disable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - system_settings_bluetooth_sharing_disable passed (Result: $result_value, Expected: "{'boolean': 0}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_bluetooth_sharing_disable failed (Result: $result_value, Expected: "{'boolean': 0}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_bluetooth_sharing_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_bluetooth_sharing_disable failed (Result: $result_value, Expected: "{'boolean': 0}")"
        else
            echo "$(date -u) system_settings_bluetooth_sharing_disable failed (Result: $result_value, Expected: "{'boolean': 0}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_bluetooth_sharing_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_bluetooth_sharing_disable failed (Result: $result_value, Expected: "{'boolean': 0}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_bluetooth_sharing_disable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_bluetooth_sharing_disable -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_filevault_enforce -----#####
## Addresses the following NIST 800-53 controls: 
# * SC-28, SC-28(1)
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_filevault_enforce ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(dontAllowDisable=$(/usr/bin/osascript -l JavaScript << EOS
$.NSUserDefaults.alloc.initWithSuiteName('com.apple.MCX')\
.objectForKey('dontAllowFDEDisable').js
EOS
)
fileVault=$(/usr/bin/fdesetup status | /usr/bin/grep -c "FileVault is On.")
if [[ "$dontAllowDisable" == "true" ]] && [[ "$fileVault" == 1 ]]; then
  echo "1"
else
  echo "0"
fi
)
    # expected result {'integer': 1}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_filevault_enforce'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_filevault_enforce'))["exempt_reason"]
EOS
)

    if [[ $result_value == "1" ]]; then
        echo "$(date -u) system_settings_filevault_enforce passed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_filevault_enforce -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - system_settings_filevault_enforce passed (Result: $result_value, Expected: "{'integer': 1}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_filevault_enforce failed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_filevault_enforce -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_filevault_enforce failed (Result: $result_value, Expected: "{'integer': 1}")"
        else
            echo "$(date -u) system_settings_filevault_enforce failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_filevault_enforce -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_filevault_enforce failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_filevault_enforce does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_filevault_enforce -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_firewall_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * AC-4
# * CM-7, CM-7(1)
# * SC-7, SC-7(12)
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_firewall_enable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/osascript -l JavaScript << EOS
$.NSUserDefaults.alloc.initWithSuiteName('com.apple.security.firewall')\
.objectForKey('EnableFirewall').js
EOS
)
    # expected result {'string': 'true'}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_firewall_enable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_firewall_enable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "true" ]]; then
        echo "$(date -u) system_settings_firewall_enable passed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_firewall_enable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - system_settings_firewall_enable passed (Result: $result_value, Expected: "{'string': 'true'}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_firewall_enable failed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_firewall_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_firewall_enable failed (Result: $result_value, Expected: "{'string': 'true'}")"
        else
            echo "$(date -u) system_settings_firewall_enable failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_firewall_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_firewall_enable failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_firewall_enable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_firewall_enable -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_firewall_stealth_mode_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * CM-7, CM-7(1)
# * SC-7, SC-7(16)
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_firewall_stealth_mode_enable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/osascript -l JavaScript << EOS
$.NSUserDefaults.alloc.initWithSuiteName('com.apple.security.firewall')\
.objectForKey('EnableStealthMode').js
EOS
)
    # expected result {'string': 'true'}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_firewall_stealth_mode_enable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_firewall_stealth_mode_enable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "true" ]]; then
        echo "$(date -u) system_settings_firewall_stealth_mode_enable passed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_firewall_stealth_mode_enable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - system_settings_firewall_stealth_mode_enable passed (Result: $result_value, Expected: "{'string': 'true'}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_firewall_stealth_mode_enable failed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_firewall_stealth_mode_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_firewall_stealth_mode_enable failed (Result: $result_value, Expected: "{'string': 'true'}")"
        else
            echo "$(date -u) system_settings_firewall_stealth_mode_enable failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_firewall_stealth_mode_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_firewall_stealth_mode_enable failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_firewall_stealth_mode_enable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_firewall_stealth_mode_enable -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_guest_account_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * AC-2, AC-2(9)
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_guest_account_disable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/osascript -l JavaScript << EOS
function run() {
  let pref1 = ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('com.apple.MCX')\
.objectForKey('DisableGuestAccount'))
  let pref2 = ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('com.apple.MCX')\
.objectForKey('EnableGuestAccount'))
  if ( pref1 == true && pref2 == false ) {
    return("true")
  } else {
    return("false")
  }
}
EOS
)
    # expected result {'string': 'true'}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_guest_account_disable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_guest_account_disable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "true" ]]; then
        echo "$(date -u) system_settings_guest_account_disable passed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_guest_account_disable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - system_settings_guest_account_disable passed (Result: $result_value, Expected: "{'string': 'true'}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_guest_account_disable failed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_guest_account_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_guest_account_disable failed (Result: $result_value, Expected: "{'string': 'true'}")"
        else
            echo "$(date -u) system_settings_guest_account_disable failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_guest_account_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_guest_account_disable failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_guest_account_disable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_guest_account_disable -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_personalized_advertising_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * AC-20
# * CM-7, CM-7(1)
# * SC-7(10)
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_personalized_advertising_disable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/osascript -l JavaScript << EOS
$.NSUserDefaults.alloc.initWithSuiteName('com.apple.applicationaccess')\
.objectForKey('allowApplePersonalizedAdvertising').js
EOS
)
    # expected result {'string': 'false'}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_personalized_advertising_disable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_personalized_advertising_disable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "false" ]]; then
        echo "$(date -u) system_settings_personalized_advertising_disable passed (Result: $result_value, Expected: "{'string': 'false'}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_personalized_advertising_disable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - system_settings_personalized_advertising_disable passed (Result: $result_value, Expected: "{'string': 'false'}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_personalized_advertising_disable failed (Result: $result_value, Expected: "{'string': 'false'}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_personalized_advertising_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_personalized_advertising_disable failed (Result: $result_value, Expected: "{'string': 'false'}")"
        else
            echo "$(date -u) system_settings_personalized_advertising_disable failed (Result: $result_value, Expected: "{'string': 'false'}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_personalized_advertising_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_personalized_advertising_disable failed (Result: $result_value, Expected: "{'string': 'false'}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_personalized_advertising_disable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_personalized_advertising_disable -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_remote_management_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * CM-7, CM-7(1)
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_remote_management_disable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/libexec/mdmclient QuerySecurityInfo | /usr/bin/grep -c "RemoteDesktopEnabled = 0"
)
    # expected result {'integer': 1}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_remote_management_disable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_remote_management_disable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "1" ]]; then
        echo "$(date -u) system_settings_remote_management_disable passed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_remote_management_disable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - system_settings_remote_management_disable passed (Result: $result_value, Expected: "{'integer': 1}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_remote_management_disable failed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_remote_management_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_remote_management_disable failed (Result: $result_value, Expected: "{'integer': 1}")"
        else
            echo "$(date -u) system_settings_remote_management_disable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_remote_management_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_remote_management_disable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_remote_management_disable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_remote_management_disable -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_ssh_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * AC-17
# * CM-7, CM-7(1)
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_ssh_disable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/bin/launchctl print-disabled system | /usr/bin/grep -c '"com.openssh.sshd" => disabled'
)
    # expected result {'integer': 1}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_ssh_disable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_ssh_disable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "1" ]]; then
        echo "$(date -u) system_settings_ssh_disable passed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_ssh_disable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - system_settings_ssh_disable passed (Result: $result_value, Expected: "{'integer': 1}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_ssh_disable failed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_ssh_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_ssh_disable failed (Result: $result_value, Expected: "{'integer': 1}")"
        else
            echo "$(date -u) system_settings_ssh_disable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_ssh_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_ssh_disable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_ssh_disable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_ssh_disable -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_time_server_enforce -----#####
## Addresses the following NIST 800-53 controls: 
# * AU-12(1)
# * SC-45(1)
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_time_server_enforce ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/osascript -l JavaScript << EOS
$.NSUserDefaults.alloc.initWithSuiteName('com.apple.timed')\
.objectForKey('TMAutomaticTimeOnlyEnabled').js
EOS
)
    # expected result {'string': 'true'}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_time_server_enforce'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_time_server_enforce'))["exempt_reason"]
EOS
)

    if [[ $result_value == "true" ]]; then
        echo "$(date -u) system_settings_time_server_enforce passed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_time_server_enforce -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - system_settings_time_server_enforce passed (Result: $result_value, Expected: "{'string': 'true'}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_time_server_enforce failed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_time_server_enforce -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_time_server_enforce failed (Result: $result_value, Expected: "{'string': 'true'}")"
        else
            echo "$(date -u) system_settings_time_server_enforce failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_time_server_enforce -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_time_server_enforce failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_time_server_enforce does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_time_server_enforce -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_wake_network_access_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_wake_network_access_disable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/pmset -g custom | /usr/bin/awk '/womp/ { sum+=$2 } END {print sum}'
)
    # expected result {'integer': 0}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_wake_network_access_disable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_wake_network_access_disable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "0" ]]; then
        echo "$(date -u) system_settings_wake_network_access_disable passed (Result: $result_value, Expected: "{'integer': 0}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_wake_network_access_disable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - system_settings_wake_network_access_disable passed (Result: $result_value, Expected: "{'integer': 0}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_wake_network_access_disable failed (Result: $result_value, Expected: "{'integer': 0}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_wake_network_access_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_wake_network_access_disable failed (Result: $result_value, Expected: "{'integer': 0}")"
        else
            echo "$(date -u) system_settings_wake_network_access_disable failed (Result: $result_value, Expected: "{'integer': 0}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_wake_network_access_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_wake_network_access_disable failed (Result: $result_value, Expected: "{'integer': 0}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_wake_network_access_disable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_wake_network_access_disable -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_wifi_menu_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_wifi_menu_enable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/osascript -l JavaScript << EOS
$.NSUserDefaults.alloc.initWithSuiteName('com.apple.controlcenter')\
.objectForKey('WiFi').js
EOS
)
    # expected result {'integer': 18}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_wifi_menu_enable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_wifi_menu_enable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "18" ]]; then
        echo "$(date -u) system_settings_wifi_menu_enable passed (Result: $result_value, Expected: "{'integer': 18}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_wifi_menu_enable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl1 - system_settings_wifi_menu_enable passed (Result: $result_value, Expected: "{'integer': 18}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_wifi_menu_enable failed (Result: $result_value, Expected: "{'integer': 18}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_wifi_menu_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_wifi_menu_enable failed (Result: $result_value, Expected: "{'integer': 18}")"
        else
            echo "$(date -u) system_settings_wifi_menu_enable failed (Result: $result_value, Expected: "{'integer': 18}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_wifi_menu_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl1 - system_settings_wifi_menu_enable failed (Result: $result_value, Expected: "{'integer': 18}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_wifi_menu_enable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_wifi_menu_enable -dict-add finding -bool NO
fi
    
lastComplianceScan=$(defaults read "$audit_plist" lastComplianceCheck)
echo "Results written to $audit_plist"

if [[ ! $check ]] && [[ ! $cfc ]];then
    pause
fi

}

run_fix(){

if [[ ! -e "$audit_plist" ]]; then
    echo "Audit plist doesn't exist, please run Audit Check First" | tee -a "$audit_log"

    if [[ ! $fix ]]; then
        pause
        show_menus
        read_options
    else
        exit 1
    fi
fi

if [[ ! $fix ]] && [[ ! $cfc ]]; then
    ask 'THE SOFTWARE IS PROVIDED "AS IS" WITHOUT ANY WARRANTY OF ANY KIND, EITHER EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, ANY WARRANTY THAT THE SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND FREEDOM FROM INFRINGEMENT, AND ANY WARRANTY THAT THE DOCUMENTATION WILL CONFORM TO THE SOFTWARE, OR ANY WARRANTY THAT THE SOFTWARE WILL BE ERROR FREE.  IN NO EVENT SHALL NIST BE LIABLE FOR ANY DAMAGES, INCLUDING, BUT NOT LIMITED TO, DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES, ARISING OUT OF, RESULTING FROM, OR IN ANY WAY CONNECTED WITH THIS SOFTWARE, WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR OTHERWISE, WHETHER OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR OTHERWISE, AND WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF THE RESULTS OF, OR USE OF, THE SOFTWARE OR SERVICES PROVIDED HEREUNDER. WOULD YOU LIKE TO CONTINUE? ' N

    if [[ $? != 0 ]]; then
        show_menus
        read_options
    fi
fi

# append to existing logfile
echo "$(date -u) Beginning remediation of non-compliant settings" >> "$audit_log"

# remove uchg on audit_control
/usr/bin/chflags nouchg /etc/security/audit_control

# run mcxrefresh
/usr/bin/mcxrefresh -u $CURR_USER_UID


    
#####----- Rule: audit_auditd_enabled -----#####
## Addresses the following NIST 800-53 controls: 
# * AU-12, AU-12(1), AU-12(3)
# * AU-14(1)
# * AU-3, AU-3(1)
# * AU-8
# * CM-5(1)
# * MA-4(1)

# check to see if rule is exempt
unset exempt
unset exempt_reason

exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('audit_auditd_enabled'))["exempt"]
EOS
)

exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('audit_auditd_enabled'))["exempt_reason"]
EOS
)

audit_auditd_enabled_audit_score=$($plb -c "print audit_auditd_enabled:finding" $audit_plist)
if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
    if [[ $audit_auditd_enabled_audit_score == "true" ]]; then
        ask 'audit_auditd_enabled - Run the command(s)-> /bin/launchctl load -w /System/Library/LaunchDaemons/com.apple.auditd.plist ' N
        if [[ $? == 0 ]]; then
            echo "$(date -u) Running the command to configure the settings for: audit_auditd_enabled ..." | /usr/bin/tee -a "$audit_log"
            /bin/launchctl load -w /System/Library/LaunchDaemons/com.apple.auditd.plist
        fi
    else
        echo "$(date -u) Settings for: audit_auditd_enabled already configured, continuing..." | /usr/bin/tee -a "$audit_log"
    fi
elif [[ ! -z "$exempt_reason" ]];then
    echo "$(date -u) audit_auditd_enabled has an exemption, remediation skipped (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
fi
    
#####----- Rule: audit_retention_configure -----#####
## Addresses the following NIST 800-53 controls: 
# * AU-11
# * AU-4

# check to see if rule is exempt
unset exempt
unset exempt_reason

exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('audit_retention_configure'))["exempt"]
EOS
)

exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('audit_retention_configure'))["exempt_reason"]
EOS
)

audit_retention_configure_audit_score=$($plb -c "print audit_retention_configure:finding" $audit_plist)
if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
    if [[ $audit_retention_configure_audit_score == "true" ]]; then
        ask 'audit_retention_configure - Run the command(s)-> /usr/bin/sed -i.bak '"'"'s/^expire-after.*/expire-after:60d OR 1G'"'"' /etc/security/audit_control; /usr/sbin/audit -s ' N
        if [[ $? == 0 ]]; then
            echo "$(date -u) Running the command to configure the settings for: audit_retention_configure ..." | /usr/bin/tee -a "$audit_log"
            /usr/bin/sed -i.bak 's/^expire-after.*/expire-after:60d OR 1G' /etc/security/audit_control; /usr/sbin/audit -s
        fi
    else
        echo "$(date -u) Settings for: audit_retention_configure already configured, continuing..." | /usr/bin/tee -a "$audit_log"
    fi
elif [[ ! -z "$exempt_reason" ]];then
    echo "$(date -u) audit_retention_configure has an exemption, remediation skipped (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
fi
    
#####----- Rule: os_gatekeeper_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * CM-14
# * CM-5
# * SI-3
# * SI-7(1), SI-7(15)

# check to see if rule is exempt
unset exempt
unset exempt_reason

exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_gatekeeper_enable'))["exempt"]
EOS
)

exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_gatekeeper_enable'))["exempt_reason"]
EOS
)

os_gatekeeper_enable_audit_score=$($plb -c "print os_gatekeeper_enable:finding" $audit_plist)
if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
    if [[ $os_gatekeeper_enable_audit_score == "true" ]]; then
        ask 'os_gatekeeper_enable - Run the command(s)-> /usr/sbin/spctl --global-enable ' N
        if [[ $? == 0 ]]; then
            echo "$(date -u) Running the command to configure the settings for: os_gatekeeper_enable ..." | /usr/bin/tee -a "$audit_log"
            /usr/sbin/spctl --global-enable
        fi
    else
        echo "$(date -u) Settings for: os_gatekeeper_enable already configured, continuing..." | /usr/bin/tee -a "$audit_log"
    fi
elif [[ ! -z "$exempt_reason" ]];then
    echo "$(date -u) os_gatekeeper_enable has an exemption, remediation skipped (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
fi
    
#####----- Rule: os_power_nap_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * CM-7, CM-7(1)

# check to see if rule is exempt
unset exempt
unset exempt_reason

exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_power_nap_disable'))["exempt"]
EOS
)

exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_power_nap_disable'))["exempt_reason"]
EOS
)

os_power_nap_disable_audit_score=$($plb -c "print os_power_nap_disable:finding" $audit_plist)
if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
    if [[ $os_power_nap_disable_audit_score == "true" ]]; then
        ask 'os_power_nap_disable - Run the command(s)-> /usr/bin/pmset -a powernap 0 ' N
        if [[ $? == 0 ]]; then
            echo "$(date -u) Running the command to configure the settings for: os_power_nap_disable ..." | /usr/bin/tee -a "$audit_log"
            /usr/bin/pmset -a powernap 0
        fi
    else
        echo "$(date -u) Settings for: os_power_nap_disable already configured, continuing..." | /usr/bin/tee -a "$audit_log"
    fi
elif [[ ! -z "$exempt_reason" ]];then
    echo "$(date -u) os_power_nap_disable has an exemption, remediation skipped (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
fi
    
#####----- Rule: os_show_filename_extensions_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A

# check to see if rule is exempt
unset exempt
unset exempt_reason

exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_show_filename_extensions_enable'))["exempt"]
EOS
)

exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_show_filename_extensions_enable'))["exempt_reason"]
EOS
)

os_show_filename_extensions_enable_audit_score=$($plb -c "print os_show_filename_extensions_enable:finding" $audit_plist)
if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
    if [[ $os_show_filename_extensions_enable_audit_score == "true" ]]; then
        ask 'os_show_filename_extensions_enable - Run the command(s)-> /usr/bin/sudo -u "$CURRENT_USER" /usr/bin/defaults write /Users/"$CURRENT_USER"/Library/Preferences/.GlobalPreferences AppleShowAllExtensions -bool true ' N
        if [[ $? == 0 ]]; then
            echo "$(date -u) Running the command to configure the settings for: os_show_filename_extensions_enable ..." | /usr/bin/tee -a "$audit_log"
            /usr/bin/sudo -u "$CURRENT_USER" /usr/bin/defaults write /Users/"$CURRENT_USER"/Library/Preferences/.GlobalPreferences AppleShowAllExtensions -bool true
        fi
    else
        echo "$(date -u) Settings for: os_show_filename_extensions_enable already configured, continuing..." | /usr/bin/tee -a "$audit_log"
    fi
elif [[ ! -z "$exempt_reason" ]];then
    echo "$(date -u) os_show_filename_extensions_enable has an exemption, remediation skipped (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
fi
    
#####----- Rule: os_sip_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * AC-3
# * AU-9, AU-9(3)
# * CM-5, CM-5(6)
# * SC-4
# * SI-2
# * SI-7

# check to see if rule is exempt
unset exempt
unset exempt_reason

exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_sip_enable'))["exempt"]
EOS
)

exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('os_sip_enable'))["exempt_reason"]
EOS
)

os_sip_enable_audit_score=$($plb -c "print os_sip_enable:finding" $audit_plist)
if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
    if [[ $os_sip_enable_audit_score == "true" ]]; then
        ask 'os_sip_enable - Run the command(s)-> /usr/bin/csrutil enable ' N
        if [[ $? == 0 ]]; then
            echo "$(date -u) Running the command to configure the settings for: os_sip_enable ..." | /usr/bin/tee -a "$audit_log"
            /usr/bin/csrutil enable
        fi
    else
        echo "$(date -u) Settings for: os_sip_enable already configured, continuing..." | /usr/bin/tee -a "$audit_log"
    fi
elif [[ ! -z "$exempt_reason" ]];then
    echo "$(date -u) os_sip_enable has an exemption, remediation skipped (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
fi
    
#####----- Rule: system_settings_bluetooth_sharing_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * AC-18(4)
# * AC-3
# * CM-7, CM-7(1)

# check to see if rule is exempt
unset exempt
unset exempt_reason

exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_bluetooth_sharing_disable'))["exempt"]
EOS
)

exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_bluetooth_sharing_disable'))["exempt_reason"]
EOS
)

system_settings_bluetooth_sharing_disable_audit_score=$($plb -c "print system_settings_bluetooth_sharing_disable:finding" $audit_plist)
if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
    if [[ $system_settings_bluetooth_sharing_disable_audit_score == "true" ]]; then
        ask 'system_settings_bluetooth_sharing_disable - Run the command(s)-> /usr/bin/sudo -u "$CURRENT_USER" /usr/bin/defaults -currentHost write com.apple.Bluetooth PrefKeyServicesEnabled -bool false ' N
        if [[ $? == 0 ]]; then
            echo "$(date -u) Running the command to configure the settings for: system_settings_bluetooth_sharing_disable ..." | /usr/bin/tee -a "$audit_log"
            /usr/bin/sudo -u "$CURRENT_USER" /usr/bin/defaults -currentHost write com.apple.Bluetooth PrefKeyServicesEnabled -bool false
        fi
    else
        echo "$(date -u) Settings for: system_settings_bluetooth_sharing_disable already configured, continuing..." | /usr/bin/tee -a "$audit_log"
    fi
elif [[ ! -z "$exempt_reason" ]];then
    echo "$(date -u) system_settings_bluetooth_sharing_disable has an exemption, remediation skipped (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
fi
    
#####----- Rule: system_settings_remote_management_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * CM-7, CM-7(1)

# check to see if rule is exempt
unset exempt
unset exempt_reason

exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_remote_management_disable'))["exempt"]
EOS
)

exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_remote_management_disable'))["exempt_reason"]
EOS
)

system_settings_remote_management_disable_audit_score=$($plb -c "print system_settings_remote_management_disable:finding" $audit_plist)
if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
    if [[ $system_settings_remote_management_disable_audit_score == "true" ]]; then
        ask 'system_settings_remote_management_disable - Run the command(s)-> /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -stop ' N
        if [[ $? == 0 ]]; then
            echo "$(date -u) Running the command to configure the settings for: system_settings_remote_management_disable ..." | /usr/bin/tee -a "$audit_log"
            /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -stop
        fi
    else
        echo "$(date -u) Settings for: system_settings_remote_management_disable already configured, continuing..." | /usr/bin/tee -a "$audit_log"
    fi
elif [[ ! -z "$exempt_reason" ]];then
    echo "$(date -u) system_settings_remote_management_disable has an exemption, remediation skipped (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
fi
    
#####----- Rule: system_settings_ssh_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * AC-17
# * CM-7, CM-7(1)

# check to see if rule is exempt
unset exempt
unset exempt_reason

exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_ssh_disable'))["exempt"]
EOS
)

exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_ssh_disable'))["exempt_reason"]
EOS
)

system_settings_ssh_disable_audit_score=$($plb -c "print system_settings_ssh_disable:finding" $audit_plist)
if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
    if [[ $system_settings_ssh_disable_audit_score == "true" ]]; then
        ask 'system_settings_ssh_disable - Run the command(s)-> /usr/sbin/systemsetup -f -setremotelogin off >/dev/null
/bin/launchctl disable system/com.openssh.sshd ' N
        if [[ $? == 0 ]]; then
            echo "$(date -u) Running the command to configure the settings for: system_settings_ssh_disable ..." | /usr/bin/tee -a "$audit_log"
            /usr/sbin/systemsetup -f -setremotelogin off >/dev/null
/bin/launchctl disable system/com.openssh.sshd
        fi
    else
        echo "$(date -u) Settings for: system_settings_ssh_disable already configured, continuing..." | /usr/bin/tee -a "$audit_log"
    fi
elif [[ ! -z "$exempt_reason" ]];then
    echo "$(date -u) system_settings_ssh_disable has an exemption, remediation skipped (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
fi
    
#####----- Rule: system_settings_wake_network_access_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A

# check to see if rule is exempt
unset exempt
unset exempt_reason

exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_wake_network_access_disable'))["exempt"]
EOS
)

exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl1.audit').objectForKey('system_settings_wake_network_access_disable'))["exempt_reason"]
EOS
)

system_settings_wake_network_access_disable_audit_score=$($plb -c "print system_settings_wake_network_access_disable:finding" $audit_plist)
if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
    if [[ $system_settings_wake_network_access_disable_audit_score == "true" ]]; then
        ask 'system_settings_wake_network_access_disable - Run the command(s)-> /usr/bin/pmset -a womp 0 ' N
        if [[ $? == 0 ]]; then
            echo "$(date -u) Running the command to configure the settings for: system_settings_wake_network_access_disable ..." | /usr/bin/tee -a "$audit_log"
            /usr/bin/pmset -a womp 0
        fi
    else
        echo "$(date -u) Settings for: system_settings_wake_network_access_disable already configured, continuing..." | /usr/bin/tee -a "$audit_log"
    fi
elif [[ ! -z "$exempt_reason" ]];then
    echo "$(date -u) system_settings_wake_network_access_disable has an exemption, remediation skipped (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
fi
    
echo "$(date -u) Remediation complete" >> "$audit_log"

}

zparseopts -D -E -check=check -fix=fix -stats=stats -compliant=compliant_opt -non_compliant=non_compliant_opt -reset=reset -cfc=cfc

if [[ $reset ]]; then reset_plist; fi

if [[ $check ]] || [[ $fix ]] || [[ $cfc ]] || [[ $stats ]] || [[ $compliant_opt ]] || [[ $non_compliant_opt ]]; then
    if [[ $fix ]]; then run_fix; fi
    if [[ $check ]]; then run_scan; fi
    if [[ $cfc ]]; then run_scan; run_fix; run_scan; fi
    if [[ $stats ]];then generate_stats; fi
    if [[ $compliant_opt ]];then compliance_count "compliant"; fi
    if [[ $non_compliant_opt ]];then compliance_count "non-compliant"; fi
else
    while true; do
        show_menus
        read_options
    done
fi

exit 0    