## Purpose:
Check each local computer to ensure that the proper permissions are correctly set. It is essential to verify that the installation process pushed through Jamf has been completed successfully. Granting local permissions is crucial to ensure full access, which is vital for the software to operate effectively.

### Jamf Pro - settings

### Policies

*ActiveTrak*

- Install package 

- Install script - ActiveTrak installer 

  - displays a message to end user and directs user to permission preference panel

*ActivTrak Permissions*

- Install script - ActiveTrak installer 

  - displays a message to end user and directs user to permission preference panel, when the permission gets changed or has not been set.

Even though the application prompts the user to enable permissions upon installation, occasionally this prompt fails and gets obscured by other windows. However, the script generates a prompt that remains on top of all windows during installation indicating to the user that something has to be done.

---

### Smart Computer Group

*ActivTrak - Permission Required*

*Criteria - ActivTrak is like* $\large\color{red}{\textsf{"kTCCServiceScreenCapture|0"}}$

This process identifies computers with unresolved permission settings, thus allowing the system to prompt users via policy to rectify this permission requirement by directing the user to enable the screen capture access required by the application.

---

### Extended Attribute

*ActivTrak Permissions*

Expected Results  

- $\large\color{green}{\textsf{Set = "kTCCServiceScreenCapture|2"}}$
- $\large\color{red}{\textsf{Not set = "kTCCServiceScreenCapture|0"}}$  

This attribute check ensures that the condition is met before moving on to the next step, If the condition is not met, the computer will be placed in the appropriate smart group and the user will be prompted for additional information to set permission before proceeding.

---

### Script

This script serves a dual purpose: firstly, notifying the user about the necessity to modify a permission, and secondly, providing a link to the relevant HelpDesk how-to page for the specific installed application.

#### ActiveTrak Installer

<p align="center">
  <img alt="Screenshot 2024-08-23 at 2 16 35 PM" src="https://github.com/user-attachments/assets/763fe68d-f1ae-4540-b216-1b4d16014ff0"></p>

“**Moreinfo**”  [Active Trak installation](https://digitalconvergence.atlassian.net/servicedesk/customer/portal/27/topic/57622345-7551-4bc5-a6d2-ef491d0ccba5/article/2862972929)

“**Ok**” button Launches the Security & Privacy - Screen Recording preference panel where ***<code>scthostp</code>*** needs to be enabled.

<p align="center">
<img width="721" alt="Screenshot 2024-08-12 at 8 45 48 AM" src="https://github.com/user-attachments/assets/7c690f4d-a9a4-40fb-a834-dcf8b8a579d2">
</p>

ActivTrak Screen Nag

Script to stop this annoying popup as it gets too intrusive!
<img width="620" alt="Screenshot 2025-03-14 at 8 02 05 AM" src="https://github.com/user-attachments/assets/ef7ba8b0-04f2-4589-bcdc-4dffe5d25866" />
