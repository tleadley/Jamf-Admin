#!/bin/zsh
#
# Low Disk Space
#
# by: Scott Kendall
#     Updated Trevor Leadley
#
# Written: 01/03/2025
# Last updated: 02/13/2025
#
# Script Purpose: Display user friendly dialog to users about their disk space
#
# 1.0 - Initial
# 1.1 - Code cleanup to be more consistant with all apps
# 1.2 - Removed install trgger for jamf policy ( Trevor Leadley )
#     - Added installer function ( Trevor Leadley )
#     - Replace disk space volume to check the Data partitiononly ( Trevor Leadley )

######################################################################################################
#
# Gobal "Common" variables
#
######################################################################################################

LOGGED_IN_USER=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
USER_DIR=$( dscl . -read /Users/${LOGGED_IN_USER} NFSHomeDirectory | awk '{ print $2 }' )

OS_PLATFORM=$(/usr/bin/uname -p)

[[ "$OS_PLATFORM" == 'i386' ]] && HWtype="SPHardwareDataType.0.cpu_type" || HWtype="SPHardwareDataType.0.chip_type"

SYSTEM_PROFILER_BLOB=$( /usr/sbin/system_profiler -json 'SPHardwareDataType')
MAC_SERIAL_NUMBER=$( echo $SYSTEM_PROFILER_BLOB | /usr/bin/plutil -extract 'SPHardwareDataType.0.serial_number' 'raw' -)
MAC_CPU=$( echo $SYSTEM_PROFILER_BLOB | /usr/bin/plutil -extract "${HWtype}" 'raw' -)
MAC_HADWARE_CLASS=$( echo $SYSTEM_PROFILER_BLOB | /usr/bin/plutil -extract 'SPHardwareDataType.0.machine_name' 'raw' -)
MAC_RAM=$( echo $SYSTEM_PROFILER_BLOB | /usr/bin/plutil -extract 'SPHardwareDataType.0.physical_memory' 'raw' -)
#FREE_DISK_SPACE=$(($( /usr/sbin/diskutil info / | /usr/bin/grep "Free Space" | /usr/bin/awk '{print $6}' | /usr/bin/cut -c 2- ) / 1024 / 1024 / 1024 ))
MACOS_VERSION=$( sw_vers -productVersion | xargs)

HD_TOTAL=`df /System/Volumes/Data | tail -n +2 | awk '{ print $2 }'`
HD_FREE=`df /System/Volumes/Data | tail -n +2 | awk '{ print $4 }'`
PERCENT_TTL=$((${HD_FREE%.*}*100/${HD_TOTAL%.*}))
FREE_DISK_SPACE=$((100-$PERCENT_TTL))

SW_DIALOG="/usr/local/bin/dialog"
SD_BANNER_IMAGE="/Library/Application Support/GiantEagle/SupportFiles/GE_SD_BannerImage.png"
LOG_STAMP=$(echo $(/bin/date +%Y%m%d))
LOG_DIR="/var/log"
LOG_FILE="${LOG_DIR}/LowDiskSpace.log"

DIALOG_COMMAND_FILE=$(mktemp /var/tmp/FixProfileOwner.XXXXX)
ICON_FILES="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/"
SD_ICON_FILE=$ICON_FILES"ToolbarCustomizeIcon.icns"
OVERLAY_ICON="/usr/local/jamfconnect/images/Logo-dark.png"

# Swift Dialog version requirements

SW_DIALOG="/usr/local/bin/dialog"
[[ -e "${SW_DIALOG}" ]] && SD_VERSION=$( ${SW_DIALOG} --version) || SD_VERSION="0.0.0"
MIN_SD_REQUIRED_VERSION="2.3.3"
DIALOG_INSTALL_POLICY="install_SwiftDialog"
SUPPORT_FILE_INSTALL_POLICY="install_SymFiles"

SUPPORT_DIR="/System/Library/Extensions/IOStorageFamily.kext/Contents/Resources/"
OVERLAY_ICON="${SUPPORT_DIR}Internal.icns"
SD_BANNER_IMAGE="/usr/local/jamfconnect/images/backgrounds/Background_Hero.png"

ICON_FILES="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/"

BANNER_TEXT_PADDING="      " #5 spaces to accomodate for icon offset
SD_INFO_BOX_MSG=""
SD_WINDOW_TITLE="${BANNER_TEXT_PADDING}Disk Space Notification"
SHOW_DISK_USAGE="ShowDiskUsage"

SD_DIALOG_GREETING=$((){print Good ${argv[2+($1>11)+($1>18)]}} ${(%):-%D{%H}} morning afternoon evening)

##################################################
#
# Passed in variables
#
#################################################

JAMF_LOGGED_IN_USER=$3                          # Passed in by JAMF automatically
SD_FIRST_NAME="${(C)JAMF_LOGGED_IN_USER%%.*}"

####################################################################################################
#
# Functions
#
####################################################################################################

function create_log_directory ()
{
    # Ensure that the log directory and the log files exist. If they
    # do not then create them and set the permissions.
    #
    # RETURN: None

	# If the log directory doesnt exist - create it and set the permissions
	[[ ! -d "${LOG_DIR}" ]] && /bin/mkdir -p "${LOG_DIR}"
	/bin/chmod 755 "${LOG_DIR}"

	# If the log file does not exist - create it and set the permissions
	[[ ! -f "${LOG_FILE}" ]] && /usr/bin/touch "${LOG_FILE}"
	/bin/chmod 644 "${LOG_FILE}"
}

function logMe ()
{
    # Basic two pronged logging function that will log like this:
    #
    # 20231204 12:00:00: Some message here
    #
    # This function logs both to STDOUT/STDERR and a file
    # The log file is set by the $LOG_FILE variable.
    #
    # RETURN: None
    echo "${1}" 1>&2
    echo "$(/bin/date '+%Y-%m-%d %H:%M:%S'): ${1}" | tee -a "${LOG_FILE}"
}

function check_swift_dialog_install ()
{
    # Check to make sure that Swift Dialog is installed and functioning correctly
    # Will install process if missing or corrupted
    #
    # RETURN: None

    logMe "Ensuring that swiftDialog version is installed..."
    if [[ ! -x "${SW_DIALOG}" ]]; then
        logMe "Swift Dialog is missing or corrupted - Installing from JAMF"
        dialogInstall
        SD_VERSION=$( ${SW_DIALOG} --version)
    fi

    if ! is-at-least "${MIN_SD_REQUIRED_VERSION}" "${SD_VERSION}"; then
        logMe "Swift Dialog is outdated - Installing version '${MIN_SD_REQUIRED_VERSION}' from JAMF..."
        dialogInstall
    else
        logMe "Swift Dialog is currently running: ${SD_VERSION}"
    fi
}

function install_swift_dialog ()
{
    # Install Swift dialog From JAMF
    # PARMS Expected: DIALOG_INSTALL_POLICY - policy trigger from JAMF
    #
    # RETURN: None

	#usr/local/bin/jamf policy -trigger ${DIALOG_INSTALL_POLICY}
}

function create_infobox_message()
{
	################################
	#
	# Swift Dialog InfoBox message construct
	#
	################################

	SD_INFO_BOX_MSG="## System Info ##\n"
	SD_INFO_BOX_MSG+="${MAC_CPU}<br>"
	SD_INFO_BOX_MSG+="${MAC_SERIAL_NUMBER}<br>"
	SD_INFO_BOX_MSG+="${MAC_RAM} RAM<br>"
	SD_INFO_BOX_MSG+="${FREE_DISK_SPACE}GB Available<br>"
	SD_INFO_BOX_MSG+="macOS ${MACOS_VERSION}<br>"
}

function cleanup_and_exit ()
{
	[[ -f ${JSON_OPTIONS} ]] && /bin/rm -rf ${JSON_OPTIONS}
	[[ -f ${TMP_FILE_STORAGE} ]] && /bin/rm -rf ${TMP_FILE_STORAGE}
    [[ -f ${DIALOG_COMMAND_FILE} ]] && /bin/rm -rf ${DIALOG_COMMAND_FILE}
	exit 0
}

function welcomemsg ()
{
    DiskUsage=$(df -h /Users | awk 'END{ print $(NF-4) }' | tr -d '%' )

    messagebody='This is an automated message from JAMF<br>'
    messagebody+="to let you know that your available space on your hard drive is "
    messagebody+="getting very low. Your are currently using ${DiskUsage}% of "
    messagebody+="available space.  Anything over 80% utilized can result in problems "
    messagebody+="with software updates, poor system and application performance.  "
    messagebody+="It is recommended that you remove any uncessary files "
    messagebody+="(and make sure to empty the Trash when you are done).\n\n"
    messagebody+="This message will appear if your space utilization gets above 75%, as a "
    messagebody+="friendly reminder to peform routine maintenance to keep your system in good operating condition.\n\n"
    messagebody+="Click on \"Show Files\" to view the largest files on your hard drive."

	MainDialogBody=(
		--message "$SD_DIALOG_GREETING $SD_FIRST_NAME. $messagebody"
		--icon "${OVERLAY_ICON}"
		--height 520
        --width 850
		--ontop
		--bannerimage "${SD_BANNER_IMAGE}"
		--bannertitle "${SD_WINDOW_TITLE}"
        --infobox "${SD_INFO_BOX_MSG}"
        --titlefont shadow=1
        --moveable
		--button2text "Show Files"
		--button1text "OK"
		--buttonstyle center
    )

	# Show the dialog screen and allow the user to choose

    "${SW_DIALOG}" "${MainDialogBody[@]}" 2>/dev/null
	buttonpress=$?

	# User wants to continue, so delete the files

	[[ ${buttonpress} -eq 2 ]] && show_disk_usage
    [[ ${buttonpress} -eq 0 ]] && jamf recon
}

function show_disk_usage ()
{
    /usr/local/bin/jamf policy -trigger ${SHOW_DISK_USAGE}
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate / install swiftDialog ( @acodega )
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogInstall () {

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    logMe "Installing swiftDialog..."

    # Create temporary working directory
    workDirectory=$( /usr/bin/basename "$0" )
    tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

    # Download the installer package
    /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"

    # Verify the download
    teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

    # Install the package if Team ID validates
    if [[ "$expectedDialogTeamID" == "$teamID" ]]; then

        /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
        sleep 2
        dialogVersion=$( /usr/local/bin/dialog --version )
        logMe "swiftDialog version ${dialogVersion} installed; proceeding..."

    else

        # Display a so-called "simple" dialog if Team ID fails to validate
        #osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Error" buttons {"Close"} with icon caution'
        quitScript

    fi

    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"

}
####################################################################################################
#
# Main Program
#
####################################################################################################

autoload 'is-at-least'
create_log_directory
check_swift_dialog_install
create_infobox_message
welcomemsg

exit 0
