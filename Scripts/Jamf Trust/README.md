## Purpose:

This alert workflow is to give users a heads up when their connection drops. When the connection drops, access to applications also drop. The zero trust rules require Jamf Trust Access to be fully functional. There is no current builtin feature for this process and procedure. Since this can cause many support calls, a process was necessary to automate and alert users to this problem and to offer an easy corrective workflow.

## Workflow

<img alt="Jamf Trust alert Workflow" src="https://github.com/user-attachments/assets/e0e3b6e9-4fa3-4d86-9a3d-7fcc229e6efe">

### **Smart Group**

***Jamf Trusted Access Disabled***

Devices that have disabled Jamf Trust or if Jamf Trust fails will end up in this smart group

### **Status for EA’s**

<div align="center">

|   |   |
|---|---|
|**Extension Attribute Name**|**Status Message**|
|Jamf Trust - Access|Running<br><br>Not Running|
|Jamf Protect - Smart Groups|Access_Disabled|

</div>

### Jamf Protect custom analytic with smart group

Jamf Protect agent will notify and update smart group when the application has been disabled or has closed

<p align="center">
  
<img alt="Jamf Analytic 1" src="https://github.com/user-attachments/assets/48fe7832-74b6-4e0a-8d5b-43ef8cfd44f9">

<img alt="Jamf Analytic 2" src="https://github.com/user-attachments/assets/7bd6804a-7022-4dd3-a870-91f2f7feb812">

</p>

### Jamf EA

During each check in this Extension Attribute will detect if the Jamf Trust Access process is running.

**EA Name:** Jamf Trust - Access

#### **Script:**

```
#!/bin/bash
#####################################################################################
# This script detects if Jamf Trust is running at checkin.                          #
# Jamf EA : Jamf Trust - Access (string)                                            #
# Result = "Running" 0r "Not Running"                                               #
#####################################################################################

ProcessName=JamfPrivateAccess
number=$(ps aux | grep -v grep | grep -ci $ProcessName)

if [ "$number" = "1" ]
    then
        result="Running"

    elif [ "$number" = "0" ]
    then
        result="Not Running"

fi

echo "<result>$result</result>"

exit 0;
```

### Jamf Helper script

Computer Management script named **Jamf Access Disabled**

This is the script that notifies the end user and will allow the user to enable Jamf Trust Access. The script will present the user with a button to initiate the “Enable Access” menu item.

<p align="center">
  
<img alt="Jamf Trust Menu" src="https://github.com/user-attachments/assets/3278d7e2-803c-4e72-a7d3-84ebbe2c7f74" width="40%" height="40%">

</p>

Script will also check again to make sure that the Jamf Private access process is active and will only notify the end user if the service is actually not running at the time the script is processing the corrective action.

#### End Result Alert

<p align="center">
  
<img alt="Jamf Trust Menu" src="https://github.com/user-attachments/assets/dd5708f8-d95a-46a6-b288-494eeb511ac9" >

</p> 

***Note!***

Ignoring the prompt by choosing "OK" will not clear the EA, thus next checkin the user will be prompted to enable Jamf Trust access again!

## Jamf Trust Login

This script was created to aid with the issue that sometimes the Jamf Trust installer fails to create a login item, thus Jamf Trust not running at startup.

This can occur during initial install or after a major MacOS update.

Added to a policy that gets triggered once a week
