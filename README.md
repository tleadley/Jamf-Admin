## ⚠️ Disclaimer

**Use at your own risk.**

The scripts, tools, and code provided in this repository are offered **as-is**, without any warranty of any kind, express or implied.

### Important Notes:

- I am **not responsible** for any damage, data loss, service disruption, security issues, or other consequences that may result from using these scripts.
- These scripts interact with critical systems (Jamf Pro and Okta). Improper use or execution can lead to unintended changes, deletions, or outages in your environment.
- **Always test thoroughly** in an isolated, non-production environment before deploying to production.
- It is your responsibility to:
  - Review and understand the code before running it.
  - Validate the scripts against your specific Jamf and Okta configuration.
  - Ensure proper backups and rollback plans are in place.
  - Test for edge cases and potential side effects.

By using any code from this repository, you acknowledge that you assume full responsibility for any outcomes or consequences.

**No liability** — The author(s) shall not be held liable for any direct, indirect, incidental, special, exemplary, or consequential damages arising from the use of this software.

---

**Recommendation**:  
Create a dedicated testing instance of Jamf Pro and Okta (or use a sandbox/dev tenant) to safely validate these scripts before applying them in any production setting.
This repository contains the following files and scripts to help with settings for Okta and Jamf Admin:

- **<code>Extension Attributes (EA)</code>** These are the simple scripts used to manage attributes used for Jamf Admin and it’s automated procedures.
- **<code>Script</code>** This folder houses the scripts used for managing Jamf Pro and endpoints
- **<code>README.md</code>** file contains instructions on how to use the files and scripts in this $\large\color{red}{\textsf{repo}}$.

## How to Use

1. Download the files and scripts from this repository.
2. Open the appropriate dashboards for computer management.
3. Upload the files that are for the appropriate computer management groups.
4. Verify that Okta and Jamf Admin are configured correctly.

### Requirements

- Okta account with administrator privileges
- Jamf Admin account with administrator privileges
- A computer with a command-line interface (CLI)
- Xcode code editor or Text editor

#### Troubleshooting-----

If you encounter any issues, please refer to the following troubleshooting tips:

- Make sure that you have the correct permissions to run the scripts.
- Make sure that the Okta and Jamf Admin groups files are in the correct format.
- Make sure that the CLI is working properly.
- If you are still having issues, please contact the Okta or Jamf Admin support teams.
