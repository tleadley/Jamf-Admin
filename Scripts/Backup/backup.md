To achieve local backups and automate mounting of encrypted drives on macOS, this process configures Time Machine, and initiates the backup. It executes Jamf Proscript. This script facilitates the mounting of the encrypted drive and the commencement of backups. This process uses Jamf Protect Analytics to detect when a USB device is added.

## ![play button](https://pf-emoji-service--cdn.us-east-1.prod.public.atl-paas.net/standard/ef8b0642-7523-4e13-9fd3-01b65648acf6/32x32/25b6.png) Workflow:

<img width="1920" height="1969" alt="backup-wf" src="https://github.com/user-attachments/assets/7d9d2bd2-2593-4aab-9c09-41f4e3207f5c" />

## ![locked with key](https://pf-emoji-service--cdn.us-east-1.prod.public.atl-paas.net/standard/ef8b0642-7523-4e13-9fd3-01b65648acf6/32x32/1f510.png) Device Controls:

### Device Controls

As per policy Digital Convergence is set to allow only encrypted media, unencrypted media is only allowed by exception

<img width="1648" height="705" alt="Screenshot 2024-08-06 at 10 25 20 AM" src="https://github.com/user-attachments/assets/dc65d3ce-0edc-4501-b6bf-e91f2246187b" />

Adding a serial number for system overrides, this is necessary to allow for devices to become encrypted

#### About this Mac

<img width="277" height="465" alt="about_this_mac" src="https://github.com/user-attachments/assets/c7cf2231-6ed1-43c5-8a07-864acbd904a5" />

#### More info → General

<img width="700" height="206" alt="More_info" src="https://github.com/user-attachments/assets/20ab1704-77ae-4603-8a17-2992c7f11124" />

#### System Report

<img width="897" height="427" alt="system_report" src="https://github.com/user-attachments/assets/387275bd-8739-49ad-9a63-18e701198300" />

List all the USB devices and copy the Serial Number from the target device

<img width="1619" height="612" alt="list_usb_devices" src="https://github.com/user-attachments/assets/59cff52d-ed08-4d3f-8b58-d577510dff2d" />

Track serial of the storage device and add to spreadsheet tracking user assigned, computer serial, and computer device name

## ![diamond with a dot](https://pf-emoji-service--cdn.us-east-1.prod.public.atl-paas.net/standard/ef8b0642-7523-4e13-9fd3-01b65648acf6/32x32/1f4a0.png) Computer Management:

**Jamf Protection:** Smart Group - Removable_drive

**Jamf Pro:** Smart Computer Group - Removable Drive

## ![bar chart](https://pf-emoji-service--cdn.us-east-1.prod.public.atl-paas.net/standard/ef8b0642-7523-4e13-9fd3-01b65648acf6/32x32/1f4ca.png) Analytics:

### Device mount

This analytic detects mounted storage devices.

``` Bash
$event.type == 1 AND $event.process.signingInfo.appid == "com.apple.mount_apfs" AND $event.process.commandLine CONTAINS "/Volumes/BAK-"
```

<img width="838" height="800" alt="analytic_screen" src="https://github.com/user-attachments/assets/5f79b444-6dc1-454a-a580-ccdf01a7977a" />

### USB Detected

This detects when a writable USB device is inserted.

``` Bash
$event.type == 0 AND $event.device.writable == 1
```

<img width="499" height="744" alt="device_detected" src="https://github.com/user-attachments/assets/db04cf3c-15bd-4552-aa62-b1347d9d961d" />

## ![floppy disk](https://pf-emoji-service--cdn.us-east-1.prod.public.atl-paas.net/standard/ef8b0642-7523-4e13-9fd3-01b65648acf6/32x32/1f4be.png) Script:

 The Backup bash script for assisting in the automation for the process of mounting, checking, and backing up an encrypted drive on macOS.

Here's a brief explanation of its components:

<img width="919" height="680" alt="Jamf_script" src="https://github.com/user-attachments/assets/cfee4336-2ecc-4342-86d7-09b6e38b2155" />

``` Bash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
Script Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Variables Jamf Pro
jamfServer="$4"
jamfProUser="$5"
jamfProPassEnc="$6"
jamfSalt="$8"
jamfPassphrase="$9"
prot_group="$10"
```

- jamfServer - the server url without “https://”
    
- jamfProUser - user with permissions to update settings and text fields
    

_**Jamf api settings using**_ [Jamf Pro - Encrypted Strings](https://digitalconvergence.atlassian.net/wiki/spaces/DC/pages/2541060098)

Decryption variables

- jamfProPassEnc - encrypted password that was encrypted prior
    
- jamfSalt - A random string of data that was generated at the time the password was encrypted to introduce unpredictability into the process.
    
- jamfPassphrase - Randomly generated string that is utilized for the encryption of of the password created during the password encryption process.
    

- **update_ea()** - Updates a status in an extended attribute ( EA )
    
    - _syntax_ - `update_ea $eaID $eaName $eaValue`
        
        - $eaID : Extension Attribute ID numerical value
            
        - $eaName : Extension Attribute text name
            
        - $eaValue : Text that indicates current status of the backup
            
- **read_ea()** - reads an extended attribute (EA) . This is a helper function defined elsewhere in the script.
    
    - _syntax_ - `read_ea $eaID`
        
        - $eaID : Extension Attribute ID numerical value
            
- **add_key()** - adds a new cryptographic login key entry for the specified drive, with the appropriate permissions granted passphrases
    
- **check_drive()** - checks if the encrypted drive has a login key in the macOS Keychain. If not, it will add the key using a helper function called 'add_key'.
    
- **start_bkup()** - starts the backup process.
    
    - Enables Time Machine
        
    - Sets the Backup volume location
        
    - Opens Time Machine preference pane to show status of backup
        
- **validate()** - checks if the specified volume is connected and accessible. If not, it prints an error message and exits with a non-zero status. It will call to have the device mounted if it is not mounted
    
- **validate_power_status()** - Ensuring the AC adapter is connected is crucial for operation.
    
<img width="483" height="202" alt="ac_power" src="https://github.com/user-attachments/assets/a94e19b8-f865-4563-966d-20ab3848b8d3" />

- **unmount_drive()** - unmounts the specified volume if it's currently mounted.
    
- **mount_drive()** - mounts the specified volume if it's currently unmounted.
    
- **clean_up()** - clears any Jamf Protection Groups and updates Jamf extended attributes (EAs). It also invalidates the current api authentication token and waits for 60 seconds before running 'jamf recon' to update Jamf inventory.
    
- **shw_msg()** - Message to be shown and will wait till the user presses ok in order to begin the backup process
    
<img width="483" height="202" alt="backup_dialog" src="https://github.com/user-attachments/assets/75a8eb58-267a-40bc-a80a-80c19d60f8d7" />

## ![locked with pen](https://pf-emoji-service--cdn.us-east-1.prod.public.atl-paas.net/standard/ef8b0642-7523-4e13-9fd3-01b65648acf6/32x32/1f50f.png) Jamf Policy:

### Restrictions

This policy restricts user access to TimeMachine and other preferences and panels. An exception will be granted once the backup process has been thoroughly tested.

### TimeMachine

This policy aims to deactivate the automatic backup feature for Time Machine. The purpose behind this action is to guarantee that the backup process can smoothly proceed through Jamf Protect and Jamf Pro once a user connects the designated removable drive for backups.

<img width="1640" height="797" alt="time_machine" src="https://github.com/user-attachments/assets/a6c06bc8-cae2-47b5-9f5d-503d7bf3240a" />

## ![writing hand](https://pf-emoji-service--cdn.us-east-1.prod.public.atl-paas.net/standard/ef8b0642-7523-4e13-9fd3-01b65648acf6/32x32/270d.png) Extension Attributes:

Two extension attributes are utilized in this backup procedure for the logical processing.

### Backup Drive

This shows the current Status of the backup process and the final results.

eaID = 34

- **Enabled** - for script input
    
- **Data Type** - String
    
- **Inventory Display** - General
    
- **Input** - Text Field
    

### Backup

This holds the passphrase for the device and is currently the serial number of the assigned computer for the user. In the future, there may be provisions to encrypt this passphrase and implement a process for updating and rotating it.

eaID = 35

- **Enabled** - for script input
    
- **Data Type** - String
    
- **Inventory Display** - General
    
- **Input** - Text Field
