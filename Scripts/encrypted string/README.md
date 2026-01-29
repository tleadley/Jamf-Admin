# Securely Passing Credentials from JSS Policy to Client Script for API Access

## Encrypted String Approach for Enhanced Security

In this article, we'll discuss a common use case for client scripts within a Jamf Pro Server System (JSS) policy: passing credentials to access APIs (JSS API). To ensure the confidentiality of sensitive data like passwords, encryption functions can be employed. 

Here's a step-by-step breakdown of the process:

1. **Encrypted String**
   - The password for the service account is encrypted using predefined functions to provide additional protection for the information.

2. **Policy Parameter**
   - The encrypted string will be entered as a parameter within the JSS policy.
   - The unique 'salt' and 'passphrase' values are also entered as paramters.

3. **Script**
   - A script containing variable place holders for the unique 'salt' and 'passphrase' with only the values being sent over an ssl encrypted connection. These values are essential for decrypting the password stored in the policy.

4. **Access Requirements**
   - To gain access to the encrypted data, any third party must possess both the script code and the JSS policy within their control. This enhanced security measure ensures that unauthorized individuals cannot decode the encrypted string without both components.

By implementing this strategy, you can create a more secure environment for handling sensitive data within your JSS policies, particularly when interacting with APIs on client run scripts so that passwords are not passed in plaintext and parameters like the salt as well as the passphrase are not hard coded in the script itself rather they all get passed within the encrypted ssl payload to the script within a protected memmory space.
