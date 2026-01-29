#!/bin/zsh

: HEADER = <<'EOL'

██████╗ ██╗ ██████╗ ██╗████████╗ █████╗ ██╗          ██████╗ ██████╗ ███╗   ██╗██╗   ██╗███████╗██████╗  ██████╗ ███████╗███╗   ██╗ ██████╗███████╗
██╔══██╗██║██╔════╝ ██║╚══██╔══╝██╔══██╗██║         ██╔════╝██╔═══██╗████╗  ██║██║   ██║██╔════╝██╔══██╗██╔════╝ ██╔════╝████╗  ██║██╔════╝██╔════╝
██║  ██║██║██║  ███╗██║   ██║   ███████║██║         ██║     ██║   ██║██╔██╗ ██║██║   ██║█████╗  ██████╔╝██║  ███╗█████╗  ██╔██╗ ██║██║     █████╗
██║  ██║██║██║   ██║██║   ██║   ██╔══██║██║         ██║     ██║   ██║██║╚██╗██║╚██╗ ██╔╝██╔══╝  ██╔══██╗██║   ██║██╔══╝  ██║╚██╗██║██║     ██╔══╝
██████╔╝██║╚██████╔╝██║   ██║   ██║  ██║███████╗    ╚██████╗╚██████╔╝██║ ╚████║ ╚████╔╝ ███████╗██║  ██║╚██████╔╝███████╗██║ ╚████║╚██████╗███████╗
╚═════╝ ╚═╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝


       DESCRIPTION: This script is a template dialog with tasks and progress bar

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

# --- swiftDialog configuration ---
SW_DIALOG="/usr/local/bin/dialog" # Adjust if your path is different

# --- Configuration ---
DIALOG_TITLE="Task Execution"
DIALOG_MESSAGE="Running the following tasks:"
DIALOG_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ProblemReport.icns" # SF Symbol name AppleTraceFile.icns
CMD_FILE="/private/tmp/dialog.log" # command file
LOG_FILE="/private/tmp/task_log_file.log" # descriptive name
MIN_SD_REQUIRED_VERSION="2.3.3"

#remove command file if it exists
if [ -e "$CMD_FILE" ]; then
   rm -r "$CMD_FILE"
fi
# --- Task List ---
declare -a TASKS=("Update Software Repositories" "Upgrade Installed Packages" "Show Output")

# --- Functions ---
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

function dialogInstall() {

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    LogMe "Installing swiftDialog..."

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
        LogMe "swiftDialog version ${dialogVersion} installed; proceeding..."

    else

        # Display a so-called "simple" dialog if Team ID fails to validate
        osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Error" buttons {"Close"} with icon caution'
        quitScript

    fi

    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"

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

function task_one() {
update="${progress}"
let "update+=5"
dialog_command "progress: "${update}""

sleep 5
let "update+=5"
dialog_command "progress: "${update}""

dialogsleep 5
let "update+=5"
dialog_command "progress: "${update}""

}

function task_two() {

let "update+=5"
dialog_command "progress: "${update}""
sleep 5

return 1; #shows an error

}

function task_three() {

let "update+=5"
dialog_command "progress: "${update}""
sleep 5


}
# Function to log messages (optional)
function log() {

  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"

}

# execute a dialog command
function dialog_command(){

	echo $1
	echo $1  >> $CMD_FILE

}

function finalise(){

# Update progress bar to 100% and enable button
dialog_command "progress: 100"
dialog_command "progresstext: All tasks completed."
#dialog_command "button1: enable"
#dialog_command "button1text: Done"

}

# Function to execute a task and update the dialog
function execute_task() {
  local index="$1"
  local task_name="${TASKS[$index]}"
  local task_command="$2"

  dialog_command "Starting task: "$task_name""

  # Update dialog item status to "In Progress"
  dialog_command "listitem: "$task_name": status: pending statustext: Pending..."
  echo "Debug executing Task:" $task_command $index

  # Execute the actual command
  if eval $task_command; then
    logMe "Task "$task_name" completed successfully."
    dialog_command "listitem: "$task_name": statustext:  ✅ Done"
  else
    logMe "Task "$task_name" failed."
    dialog_command "listitem: "$task_name": statustext:  ❌ Failed"
  fi
  return

}

# --- Main Script ---
function listitems() {

num_tasks="${#TASKS[@]}"
echo "DEBUG: "${TASKS[*]}" "

dialog_list_items=""

for list in "${TASKS[@]}"; do
  taskname=$list
  echo "DEBUG Name: "$taskname" "
  #dialog_list_items+="--listitem '"${taskname}"' --status pending "
  dialog_list_items+="--listitem '"${taskname}"' "
done

}
# Construct the initial dialog list items
function create_dialog () {

# Show the initial dialog with the task list and progress bar
args="--title '"${DIALOG_TITLE}"' --message '"${DIALOG_MESSAGE}"' --icon "${DIALOG_ICON}" "${dialog_list_items}" --ontop --button1disabled --button1text none --progress show --progressbar 0 --width 640 --height 320 --commandfile "${CMD_FILE}""
DISP_dialog="$SW_DIALOG $args"

# Execute the dialog

echo $DISP_dialog
eval $DISP_dialog &
sleep 1
dialog_command "progress: 10"

}

# Check if the user cancelled the dialog (optional)
if [[ "$dialog_output" == "Cancel" ]]; then
  echo "User cancelled the task execution."
  exit 1
fi
function do_tasks () {

task_item=0 # initialize the task item number placeholder

# Execute each task
for task in "${TASKS[@]}"; do
  let "task_item+=1"

  progress=$(( (task_item) * 100 / $num_tasks ))
  dialog_command "progresstext: Running Tasks "

# Define the command to run for each task
  case $task_item in
    0) TASK_COMMAND="sleep 1";; # Example: Simulate updating repos
    1) TASK_COMMAND="task_one";; # Example: Simulate upgrading packages
    2) TASK_COMMAND="task_two";; # Example: Verify disk permissions
    3) TASK_COMMAND="task_three";; # Example: Check for recent errors
    *) TASK_COMMAND="echo 'No command defined for task $task_item'";;
  esac

  execute_task $task_item $TASK_COMMAND
  dialog_command "progress: "${progress}""

done

}

autoload 'is-at-least'

check_swift_dialog_install

# create the list of items for the task list
listitems

# Creat the dialog
create_dialog

# Run all tasks
do_tasks

# Finalize and clear messsges
finalise

dialog_command "progresstext: Window will close in 10 seconds"

# wait to tasks to end and then close all dialog actions and destroy dialog message
sleep 10
dialog_command "quit: 0"

exit 0
