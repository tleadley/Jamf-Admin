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

audit_plist="/Library/Preferences/org.cis_lvl2.audit.plist"
audit_log="/Library/Logs/cis_lvl2_baseline.log"

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
    lastComplianceScan=$(defaults read /Library/Preferences/org.cis_lvl2.audit.plist lastComplianceCheck)

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
    echo "Clearing results from /Library/Preferences/org.cis_lvl2.audit.plist"
    defaults delete /Library/Preferences/org.cis_lvl2.audit.plist
}

# Generate the Compliant and Non-Compliant counts. Returns: Array (Compliant, Non-Compliant)
compliance_count(){
    compliant=0
    non_compliant=0

    results=$(/usr/libexec/PlistBuddy -c "Print" /Library/Preferences/org.cis_lvl2.audit.plist)

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

    if [[ -e "/Library/Managed Preferences/org.cis_lvl2.audit.plist" ]];then
        mscp_prefs="/Library/Managed Preferences/org.cis_lvl2.audit.plist"
    else
        mscp_prefs="/Library/Preferences/org.cis_lvl2.audit.plist"
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
 	echo "$(date -u) Beginning cis_lvl2 baseline scan" >> "$audit_log"
else
 	echo "$(date -u) Beginning cis_lvl2 baseline scan" > "$audit_log"
fi

# run mcxrefresh
/usr/bin/mcxrefresh -u $CURR_USER_UID

# write timestamp of last compliance check
/usr/bin/defaults write "$audit_plist" lastComplianceCheck "$(date)"
    
#####----- Rule: os_sudo_timeout_configure -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: os_sudo_timeout_configure ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/sudo /usr/bin/sudo -V | /usr/bin/grep -c "Authentication timestamp timeout: 0.0 minutes"
)
    # expected result {'integer': 1}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('os_sudo_timeout_configure'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('os_sudo_timeout_configure'))["exempt_reason"]
EOS
)

    if [[ $result_value == "1" ]]; then
        echo "$(date -u) os_sudo_timeout_configure passed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" os_sudo_timeout_configure -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl2 - os_sudo_timeout_configure passed (Result: $result_value, Expected: "{'integer': 1}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) os_sudo_timeout_configure failed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_sudo_timeout_configure -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl2 - os_sudo_timeout_configure failed (Result: $result_value, Expected: "{'integer': 1}")"
        else
            echo "$(date -u) os_sudo_timeout_configure failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" os_sudo_timeout_configure -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl2 - os_sudo_timeout_configure failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) os_sudo_timeout_configure does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" os_sudo_timeout_configure -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_internet_sharing_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * AC-20
# * AC-4
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_internet_sharing_disable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/osascript -l JavaScript << EOS
$.NSUserDefaults.alloc.initWithSuiteName('com.apple.MCX')\
.objectForKey('forceInternetSharingOff').js
EOS
)
    # expected result {'string': 'true'}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('system_settings_internet_sharing_disable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('system_settings_internet_sharing_disable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "true" ]]; then
        echo "$(date -u) system_settings_internet_sharing_disable passed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_internet_sharing_disable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl2 - system_settings_internet_sharing_disable passed (Result: $result_value, Expected: "{'string': 'true'}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_internet_sharing_disable failed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_internet_sharing_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl2 - system_settings_internet_sharing_disable failed (Result: $result_value, Expected: "{'string': 'true'}")"
        else
            echo "$(date -u) system_settings_internet_sharing_disable failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_internet_sharing_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl2 - system_settings_internet_sharing_disable failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_internet_sharing_disable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_internet_sharing_disable -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_location_services_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_location_services_enable ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/sudo -u _locationd /usr/bin/osascript -l JavaScript << EOS
$.NSUserDefaults.alloc.initWithSuiteName('com.apple.locationd')\
.objectForKey('LocationServicesEnabled').js
EOS
)
    # expected result {'string': 'true'}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('system_settings_location_services_enable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('system_settings_location_services_enable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "true" ]]; then
        echo "$(date -u) system_settings_location_services_enable passed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_location_services_enable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl2 - system_settings_location_services_enable passed (Result: $result_value, Expected: "{'string': 'true'}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_location_services_enable failed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_location_services_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl2 - system_settings_location_services_enable failed (Result: $result_value, Expected: "{'string': 'true'}")"
        else
            echo "$(date -u) system_settings_location_services_enable failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_location_services_enable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl2 - system_settings_location_services_enable failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_location_services_enable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_location_services_enable -dict-add finding -bool NO
fi
    
#####----- Rule: system_settings_location_services_menu_enforce -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A
rule_arch=""
if [[ "$arch" == "$rule_arch" ]] || [[ -z "$rule_arch" ]]; then
    #echo 'Running the command to check the settings for: system_settings_location_services_menu_enforce ...' | tee -a "$audit_log"
    unset result_value
    result_value=$(/usr/bin/osascript -l JavaScript << EOS
$.NSUserDefaults.alloc.initWithSuiteName('com.apple.locationmenu')\
.objectForKey('ShowSystemServices').js
EOS
)
    # expected result {'string': 'true'}


    # check to see if rule is exempt
    unset exempt
    unset exempt_reason

    exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('system_settings_location_services_menu_enforce'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('system_settings_location_services_menu_enforce'))["exempt_reason"]
EOS
)

    if [[ $result_value == "true" ]]; then
        echo "$(date -u) system_settings_location_services_menu_enforce passed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_location_services_menu_enforce -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl2 - system_settings_location_services_menu_enforce passed (Result: $result_value, Expected: "{'string': 'true'}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_location_services_menu_enforce failed (Result: $result_value, Expected: "{'string': 'true'}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_location_services_menu_enforce -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl2 - system_settings_location_services_menu_enforce failed (Result: $result_value, Expected: "{'string': 'true'}")"
        else
            echo "$(date -u) system_settings_location_services_menu_enforce failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_location_services_menu_enforce -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl2 - system_settings_location_services_menu_enforce failed (Result: $result_value, Expected: "{'string': 'true'}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_location_services_menu_enforce does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_location_services_menu_enforce -dict-add finding -bool NO
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
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('system_settings_ssh_disable'))["exempt"]
EOS
)
    exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('system_settings_ssh_disable'))["exempt_reason"]
EOS
)

    if [[ $result_value == "1" ]]; then
        echo "$(date -u) system_settings_ssh_disable passed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
        /usr/bin/defaults write "$audit_plist" system_settings_ssh_disable -dict-add finding -bool NO
        /usr/bin/logger "mSCP: cis_lvl2 - system_settings_ssh_disable passed (Result: $result_value, Expected: "{'integer': 1}")"
    else
        if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
            echo "$(date -u) system_settings_ssh_disable failed (Result: $result_value, Expected: "{'integer': 1}")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_ssh_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl2 - system_settings_ssh_disable failed (Result: $result_value, Expected: "{'integer': 1}")"
        else
            echo "$(date -u) system_settings_ssh_disable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write "$audit_plist" system_settings_ssh_disable -dict-add finding -bool YES
            /usr/bin/logger "mSCP: cis_lvl2 - system_settings_ssh_disable failed (Result: $result_value, Expected: "{'integer': 1}") - Exemption Allowed (Reason: "$exempt_reason")"
            /bin/sleep 1
        fi
    fi


else
    echo "$(date -u) system_settings_ssh_disable does not apply to this architechture" | tee -a "$audit_log"
    /usr/bin/defaults write "$audit_plist" system_settings_ssh_disable -dict-add finding -bool NO
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


    
#####----- Rule: os_sudo_timeout_configure -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A

# check to see if rule is exempt
unset exempt
unset exempt_reason

exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('os_sudo_timeout_configure'))["exempt"]
EOS
)

exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('os_sudo_timeout_configure'))["exempt_reason"]
EOS
)

os_sudo_timeout_configure_audit_score=$($plb -c "print os_sudo_timeout_configure:finding" $audit_plist)
if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
    if [[ $os_sudo_timeout_configure_audit_score == "true" ]]; then
        ask 'os_sudo_timeout_configure - Run the command(s)-> /usr/bin/find /etc/sudoers* -type f -exec sed -i '"'"''"'"' '"'"'/timestamp_timeout/d'"'"' '"'"'{}'"'"' \;
/bin/echo "Defaults timestamp_timeout=0" >> /etc/sudoers.d/mscp ' N
        if [[ $? == 0 ]]; then
            echo "$(date -u) Running the command to configure the settings for: os_sudo_timeout_configure ..." | /usr/bin/tee -a "$audit_log"
            /usr/bin/find /etc/sudoers* -type f -exec sed -i '' '/timestamp_timeout/d' '{}' \;
/bin/echo "Defaults timestamp_timeout=0" >> /etc/sudoers.d/mscp
        fi
    else
        echo "$(date -u) Settings for: os_sudo_timeout_configure already configured, continuing..." | /usr/bin/tee -a "$audit_log"
    fi
elif [[ ! -z "$exempt_reason" ]];then
    echo "$(date -u) os_sudo_timeout_configure has an exemption, remediation skipped (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
fi
    
#####----- Rule: system_settings_location_services_enable -----#####
## Addresses the following NIST 800-53 controls: 
# * N/A

# check to see if rule is exempt
unset exempt
unset exempt_reason

exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('system_settings_location_services_enable'))["exempt"]
EOS
)

exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('system_settings_location_services_enable'))["exempt_reason"]
EOS
)

system_settings_location_services_enable_audit_score=$($plb -c "print system_settings_location_services_enable:finding" $audit_plist)
if [[ ! $exempt == "1" ]] || [[ -z $exempt ]];then
    if [[ $system_settings_location_services_enable_audit_score == "true" ]]; then
        ask 'system_settings_location_services_enable - Run the command(s)-> /usr/bin/defaults write /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd LocationServicesEnabled -bool true; /bin/launchctl kickstart -k system/com.apple.locationd ' N
        if [[ $? == 0 ]]; then
            echo "$(date -u) Running the command to configure the settings for: system_settings_location_services_enable ..." | /usr/bin/tee -a "$audit_log"
            /usr/bin/defaults write /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd LocationServicesEnabled -bool true; /bin/launchctl kickstart -k system/com.apple.locationd
        fi
    else
        echo "$(date -u) Settings for: system_settings_location_services_enable already configured, continuing..." | /usr/bin/tee -a "$audit_log"
    fi
elif [[ ! -z "$exempt_reason" ]];then
    echo "$(date -u) system_settings_location_services_enable has an exemption, remediation skipped (Reason: "$exempt_reason")" | /usr/bin/tee -a "$audit_log"
fi
    
#####----- Rule: system_settings_ssh_disable -----#####
## Addresses the following NIST 800-53 controls: 
# * AC-17
# * CM-7, CM-7(1)

# check to see if rule is exempt
unset exempt
unset exempt_reason

exempt=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('system_settings_ssh_disable'))["exempt"]
EOS
)

exempt_reason=$(/usr/bin/osascript -l JavaScript << EOS 2>/dev/null
ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('org.cis_lvl2.audit').objectForKey('system_settings_ssh_disable'))["exempt_reason"]
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
