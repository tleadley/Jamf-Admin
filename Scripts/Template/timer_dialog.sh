#!/bin/zsh

: HEADER = <<'EOL'

██████╗ ██╗ ██████╗ ██╗████████╗ █████╗ ██╗          ██████╗ ██████╗ ███╗   ██╗██╗   ██╗███████╗██████╗  ██████╗ ███████╗███╗   ██╗ ██████╗███████╗
██╔══██╗██║██╔════╝ ██║╚══██╔══╝██╔══██╗██║         ██╔════╝██╔═══██╗████╗  ██║██║   ██║██╔════╝██╔══██╗██╔════╝ ██╔════╝████╗  ██║██╔════╝██╔════╝
██║  ██║██║██║  ███╗██║   ██║   ███████║██║         ██║     ██║   ██║██╔██╗ ██║██║   ██║█████╗  ██████╔╝██║  ███╗█████╗  ██╔██╗ ██║██║     █████╗
██║  ██║██║██║   ██║██║   ██║   ██╔══██║██║         ██║     ██║   ██║██║╚██╗██║╚██╗ ██╔╝██╔══╝  ██╔══██╗██║   ██║██╔══╝  ██║╚██╗██║██║     ██╔══╝
██████╔╝██║╚██████╔╝██║   ██║   ██║  ██║███████╗    ╚██████╗╚██████╔╝██║ ╚████║ ╚████╔╝ ███████╗██║  ██║╚██████╔╝███████╗██║ ╚████║╚██████╗███████╗
╚═════╝ ╚═╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝


       DESCRIPTION: This script is a template dialog with timer bar

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
SwiftDialog="/usr/local/bin/dialog" # Adjust if your path is different

# --- Configuration ---
DIALOG_TITLE="Task Execution"
DIALOG_MESSAGE="Running the following tasks:"
DIALOG_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ProblemReport.icns" # SF Symbol name AppleTraceFile.icns
CMD_FILE="/private/tmp/dialog.log" # command file
LOG_FILE="/private/tmp/task_log_file.log" # descriptive name

#remove command file if it exists
if [ -e "$CMD_FILE" ]; then
   rm -r "$CMD_FILE"
fi

# --- Functions ---

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

# Update Status
dialog_command "progresstext: All tasks completed."
dialog_command "button1: enable"
dialog_command "button1text: Done"

}

# --- Main Script ---

# Construct the initial dialog list items
function create_dialog () {

# Show the initial dialog with the task list and progress bar
DISP_dialog=`$SwiftDialog --title $DIALOG_TITLE --message $DIALOG_MESSAGE --icon $DIALOG_ICON --ontop --timer 20 --width 640 --height 320 --commandfile $CMD_FILE`

# Check if the user cancelled the dialog (optional)
case $? in
  0)
  echo "Pressed OK"
  # Button 1 processing here
  ;;
  2)
  echo "Pressed Cancel Button (button 2)"
  # Button 2 processing here
  ;;
  3)
  echo "Pressed Info Button (button 3)"
  # Button 3 processing here
  ;;
  4)
  echo "Timer Expired"
  # Timer ran out code here
  ;;
  5)
  echo "quit: command used"
  # post quit: command code here
  ;;
  10)
  echo "User quit with cmd+q"
  # User quit code here
  ;;
  30)
  echo "Key Authorisation Failed"
  # Key auth failure code here
  ;;
  201)
  echo "Image resource not found"
  ;;
  202)
  echo "Image for icon not found"
  ;;
  *)
  echo "Something else happened"
  ;;
esac

}

# Creat the dialog
create_dialog

# Finalize and clear messsges
finalise

# wait to tasks to end and then close all dialog actions and destroy dialog message

exit 0
