#!/bin/zsh

: HEADER = <<'EOL'

██████╗ ██╗ ██████╗ ██╗████████╗ █████╗ ██╗          ██████╗ ██████╗ ███╗   ██╗██╗   ██╗███████╗██████╗  ██████╗ ███████╗███╗   ██╗ ██████╗███████╗
██╔══██╗██║██╔════╝ ██║╚══██╔══╝██╔══██╗██║         ██╔════╝██╔═══██╗████╗  ██║██║   ██║██╔════╝██╔══██╗██╔════╝ ██╔════╝████╗  ██║██╔════╝██╔════╝
██║  ██║██║██║  ███╗██║   ██║   ███████║██║         ██║     ██║   ██║██╔██╗ ██║██║   ██║█████╗  ██████╔╝██║  ███╗█████╗  ██╔██╗ ██║██║     █████╗
██║  ██║██║██║   ██║██║   ██║   ██╔══██║██║         ██║     ██║   ██║██║╚██╗██║╚██╗ ██╔╝██╔══╝  ██╔══██╗██║   ██║██╔══╝  ██║╚██╗██║██║     ██╔══╝
██████╔╝██║╚██████╔╝██║   ██║   ██║  ██║███████╗    ╚██████╗╚██████╔╝██║ ╚████║ ╚████╔╝ ███████╗██║  ██║╚██████╔╝███████╗██║ ╚████║╚██████╗███████╗
╚═════╝ ╚═╝ ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝ ╚═════╝╚══════╝


       DESCRIPTION: This script creates and uploads logs to the Jamf Infrastructure

      REQUIREMENTS:
                    Jamf Pro
                    macOS Clients running version 10.13 or later

          FEATURES:
        Written by: Trevor Leadley | Digital Convergence
  Revision History:
        YYYY-MM-DD: Details
        2025-03-14: Created script
        2025-03-21: Updated header and description

 For more information, visit https://github.com/digitalconvergenceca/Mac_Admin_Jamf/tree/main/Scripts


EOL

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
## User Variables
jamfServer="$4"
jamfProUser="$5"
jamfProPassEnc="$6"
logFiles="$7"

## System Variables
mySerial=$( system_profiler SPHardwareDataType | grep Serial |  awk '{print $NF}' )
currentUser=$( stat -f%Su /dev/console )
compHostName=$( scutil --get LocalHostName )
timeStamp=$( date '+%Y-%m-%d-%H-%M-%S' )
osMajor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}')
osMinor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $2}')
fileName=$compHostName-$currentUser-$timeStamp.zip

# User password encrypted
jamfProPass=$( echo "$jamfProPassEnc" | /usr/bin/openssl enc -aes256 -d -a -A -S "$8" -k "$9" )

#set encoded username:password
APIauth="$jamfProUser:$jamfProPass"

# request auth token
authToken=$( /usr/bin/curl --request POST --silent --url "https://$jamfServer/api/v1/auth/token" --user "$APIauth" )

echo "$authToken"

# parse auth token
token=$( /usr/bin/plutil \
-extract token raw - <<< "$authToken" )

tokenExpiration=$( /usr/bin/plutil \
-extract expires raw - <<< "$authToken" )

localTokenExpirationEpoch=$( TZ=GMT /bin/date -j \
-f "%Y-%m-%dT%T" "$tokenExpiration" \
+"%s" 2> /dev/null )

echo Token: "$token"
echo Expiration: "$tokenExpiration"
echo Expiration epoch: "$localTokenExpirationEpoch"
# --- swiftDialog configuration ---
SwiftDialog="/usr/local/bin/dialog" # Adjust if your path is different

# --- Configuration ---
DIALOG_TITLE="Log\ Collection"
DIALOG_MESSAGE="Running\ the\ following\ tasks:"
DIALOG_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ProblemReport.icns" # SF Symbol name AppleTraceFile.icns
CMD_FILE="/var/tmp/dialog.log" # command file
LOG_FILE="/tmp/log_collection.log"

# --- remove command file if it exists ---
if [ -e "$CMD_FILE" ]; then
   rm -r "$CMD_FILE"
fi

# --- Task List ---
declare -a TASKS=("Collecting Logs" "Uploading Logs" "Clearing temp files"
)

# --- Functions ---
######################################################################################################################

function task_one() {
## LOG Creation and Collection
update="${progress}"
let "update+=2"
dialog_command "progress: "${update}""
ps -ax > /var/log/process.log
let "update+=2"
dialog_command "progress: "${update}""
ioreg -l > /var/log/sysinfo.log
let "update+=2"
dialog_command "progress: "${update}""
#zip -r /private/tmp/Notes.zip /Users/$currentUser/Library/Containers/com.apple.Notes/Data/Library/Notes
zip -r /private/tmp/ActivTrak.zip /Users/$currentUser/Library/Application\ Support/scthost/*.log
let "update+=2"
dialog_command "progress: "${update}""
/usr/local/bin/jamfconnect logs -o /private/tmp
let "update+=2"
dialog_command "progress: "${update}""

sleep 5
# Get artifacts
/usr/local/bin/aftermath 2>&1 >> $LOG_FILE
let "update+=2"
dialog_command "progress: "${update}""
zip -r /private/tmp/Aftermath_$compHostName.zip /private/tmp/Aftermath_$mySerial 2>&1 >> $LOG_FILE
let "update+=2"
dialog_command "progress: "${update}""

}

function task_two() {
## Zip Collection

zipit="zip /private/tmp/"${fileName}" "${logFiles}""
echo $zipit
eval $zipit
let "update+=2"
dialog_command "progress: "${update}""
## Upload Log Files
let "update+=5"
dialog_command "progress: "${update}""
echo "Debug Jamf :" $jamfServer $mySerial
jamfProID=`/usr/bin/curl -k --header "Authorization: Bearer ${token}" https://"${jamfServer}"/JSSResource/computers/serialnumber/"${mySerial}"/subset/general | xpath -e "//computer/general/id/text()"`
echo "Debug Jamf ID:" $jamfProID


let "update+=5"
dialog_command "progress: "${update}""
jamfupload="/usr/bin/curl -k --header 'Authorization: Bearer "${token}"' https://"${jamfServer}"/JSSResource/fileuploads/computers/id/"${jamfProID}" -F name=@/private/tmp/"${fileName}" -X POST"
echo "Debug Jamf :" $jamfupload
eval $jamfupload

}

function task_three() {

let "update+=5"
dialog_command "progress: "${update}""
## Cleanup
rm /private/tmp/$fileName
let "update+=5"
dialog_command "progress: "${update}""
# expire auth token
/usr/bin/curl --header "Authorization: Bearer "${token}"" --request POST --silent --url "https://$jamfServer/api/v1/auth/invalidate-token"

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

# Update progress bar to 100%
dialog_command "progress: 100"
dialog_command "progresstext: All tasks completed."
dialog_command "button1: enable"
dialog_command "button1text: Done"

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
    log "Task "$task_name" completed successfully."
    dialog_command "listitem: "$task_name": statustext:  ✅ Done"
  else
    log "Task "$task_name" failed."
    dialog_command "listitem: "$task_name": statustext:  ❌ Failed"
  fi

}

# Function to list the dialog
function listitems() {

num_tasks="${#TASKS[@]}"
echo "DEBUG: "${TASKS[*]}" "

dialog_list_items=""# Construct the initial dialog list items

for list in "${TASKS[@]}"; do
  taskname=$list
  echo "DEBUG Name: "$taskname" "
  #dialog_list_items+="--listitem '"${taskname}"' --status pending "
  dialog_list_items+="--listitem '"${taskname}"' "
done

echo "DEBUG Tasks: "$dialog_list_items" "

}

# Construct the initial dialog with list items
function create_dialog () {

# Show the initial dialog with the task list and progress bar
args="--title "${DIALOG_TITLE}" --message "${DIALOG_MESSAGE}" --icon "${DIALOG_ICON}" "${dialog_list_items}" --ontop --button1disabled --button1text none --progress show --progressbar 0 --width 640 --height 320 "
DISP_dialog="$SwiftDialog $args"

# Adjust height based on number of tasks

echo $DISP_dialog
eval $DISP_dialog &

sleep 1
dialog_command "progress: 10"

}

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
    *) TASK_COMMAND="echo 'No command defined for task $task'";;
  esac

  execute_task $task_item $TASK_COMMAND
  dialog_command "progress: "${progress}""

done

}

# create the list of items for the task list
listitems

# Creat the dialog
create_dialog

# Run all tasks
do_tasks

# Finalize and clear messsges
finalise

sleep 20
dialog_command "quit: 0"

exit 0
