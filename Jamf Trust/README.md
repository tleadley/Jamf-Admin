## Purpose:

This alert workflow is to give users a heads up when their connection drops. When the connection drops, access to applications also drop. The zero trust rules require Jamf Trust Access to be fully functional. There is no current builtin feature for this process and procedure. Since this can cause many support calls, a process was necessary to automate and alert users to this problem and to offer an easy corrective workflow.

## Workflow


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


Script will also check again to make sure that the Jamf Private access process is active and will only notify the end user if the service is actually not running at the time the script is processing the corrective action.

#### End Result Alert


>[!NOTE]
>Ignoring the prompt by choosing "OK" will not clear the EA, thus next checkin the user will be prompted to enable Jamf Trust access again!

## Jamf Trust Login

This script was created to aid with the issue that sometimes the Jamf Trust installer fails to create a login item, thus Jamf Trust not running at startup.

This can occur during initial install or after a major MacOS update.

Added to a policy that gets triggered once a week
