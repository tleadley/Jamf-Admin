<p align="center">
<img width="286" height="286" alt="password" src="https://github.com/user-attachments/assets/92853641-619a-424f-846c-e2daee790dee" />
</p>

## Purpose


The purpose of this password update process is to enable end users to securely and efficiently update their passwords on their local devices while ensuring that these changes are synchronized with essential security systems, including Okta for directory services, Jamf Connect for device management, and FileVault for local file encryption. This process enhances user experience by simplifying password management while maintaining robust security protocols.

This method also streamlines the process by eliminating the need to send a password reset email to the secondary account used for recovery. This reduces complications and the extra step of resetting the password again immediately after creating a new one with the recovery key.

## Scope

The scope of this password update process includes the following key components:

- **User Interaction**: The process is designed for end users to securely update their passwords on their local devices.
    
- **Integration with Security Systems**: It ensures synchronization of password changes with essential security systems, including:
    
    - Okta for directory services
        
    - Jamf Connect for device management
        
    - FileVault for local file encryption
        
- **User Experience**: The process aims to enhance user experience by simplifying password management while maintaining robust security protocols.
    
- **Security Protocols**: The implementation of security measures to protect user data during the password update process.
    
- **Functionality**: The process includes various functions to support password management, such as validation of password complexity, user authentication, and logging of actions.
    

### Overview

The following process enables end users to securely update their passwords locally on their devices while synchronizing changes with Okta, Jamf Connect, and FileVault.

#### Step by Step process

1. The end user initiates a password update on their local device using the standard system password change procedure.
    <img width="455" height="271" alt="Screenshot 2025-07-16 at 8 26 09 AM" src="https://github.com/user-attachments/assets/f6865a6c-fbc0-41b4-9eb6-5228c293dc9c" />

2. The updated password is automatically synchronized with:
    
    - Okta (directory service integration)
        
    - Jamf Connect (device management integration)
        
    - FileVault (local file encryption and decryption integration)
        
3. The updated password is securely transmitted to Okta and Jamf connect is initiated for synchronization.
    

**Additional Notes:**

This process ensures that end users can easily update their passwords while maintaining seamless integration with our organization's security solutions.

## Self Service
<img width="1084" height="726" alt="Screenshot 2025-07-15 at 7 19 38 AM" src="https://github.com/user-attachments/assets/e9ec87c3-378c-4c6e-ac69-4f4a43226cc0" />

## Interface
<p align="center">
<img width="824" height="409" alt="Screenshot 2025-07-15 at 7 20 13 AM" src="https://github.com/user-attachments/assets/a064f3b0-a906-442b-a959-88a47747e2c7" />
</p>

## Workflow
<img width="918" height="1539" alt="Password Update" src="https://github.com/user-attachments/assets/9a9aaca9-b54c-455f-b39e-6330a5779789" />

## Functions

#### string_to_hex

    Function to convert a string to its hexadecimal representation

    This ensures we're comparing raw bytes.

#### get_expiry

    Function to show how many days till the password expires

#### log_message

    Function to log messages to local log file /var/log/swift_password_update.log

#### check_swift_dialog_install

    Function to check for swift dialogue using the following varibles

    SD_VERSION=$( ${DIALOG} --version)  
    MIN_SD_REQUIRED_VERSION="2.3.3"

#### install_swift_dialog

    Install function for the swift dialogue package

#### api_authentication

    Function to login to the Jamf API

#### invalidate_token

    function to invalidate Jamf API token

#### get_user_email

    Function to gather the email address of the user from Jamf Pro API

#### show_dialog_and_exit

    Function to display SwiftDialog with a message and exit

#### validate_password_complexity

    Function to validate password complexity

#### get_user_id_by_login

    Function to get okta user id

#### update_password

    Function to update password using api calls to Okta

    This function now expects a user_id, not a login, for the API call.

#### Important inputs for Jamf Pro Self Serrvice
```bash
# Your Jamf Pro server URL (e.g., https://yourjamfpro.jamfcloud.com)
JAMF_PRO_URL="$4"
JAMF_API_USER="$5"
USER_PASS_ENC="$6"
PW_SALT="$7"
PW_PASS_KEY="$8"

# Okta Organization Url
OKTA_ORG_URL="https://digitalconvergence.okta.com"# Replace with your Okta domain
OKTA_API_TOKEN="$9" # Set this or export key
```
<img width="974" height="721" alt="Screenshot 2025-07-16 at 9 30 14 AM" src="https://github.com/user-attachments/assets/f2be0435-071a-4fb0-a050-76c3de9d7eb9" />

## Troubleshooting

When an Okta API call attempts to set a password that has been used previously and violates the configured password history policy, you will typically receive an error with the `errorCode` **E0000014**.

Specifically, the error response will often look something like this:

```json
{
 "errorCode": "E0000014",
 "errorSummary": "Update of credentials failed",
 "errorLink": "E0000014",
 "errorId": "oae-Q0hctCUSD2cz64VSA69BQ",// This ID will be unique to your error
 "errorCauses": [
  {
    "errorSummary": "Password has been used too recently"
  }
 ]
}
```

While `E0000014` generally indicates "Update of credentials failed," the `errorCauses` array provides more specific details about why the update failed. In this case, the `errorSummary` "Password has been used too recently" directly points to the password reuse policy being violated.

It's also worth noting that the general error code for any password policy violation is often **E0000080**, which has an `errorSummary` of "Password policy violation exception." However, for previously used passwords, `E0000014` with the specific cause is more common and descriptive.
