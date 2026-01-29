**Audit User Permissions and List Repositories**
=====================================================

Scripts used to audit user permissions and list all repositories, with output written and imported into to a Google Spreadsheet.

**Overview**
------------

These scripts use the `gh` CLI tool to create a report on user permission access and list all repositories. The output is then imported into a Google Spreadsheet for further analysis.
Authentication is through Github oauth and will prompt for authorization for the tool

**Usage**
--------

### Prerequisites

* Install the `gh` CLI tool using [this guide](https://github.com/cli/cli?tab=readme-ov-file#installation)
* Use the created Google Spreadsheet to store the output
* Open each of the import sheets created for importing both files
* User with admin access to comapany repos

### Running the Scripts

1. Run ` ./git_audit.sh > github-permsissions.csv` to execute the audit and output the report to a file
2. This will also create a list of all reposistories use and outputs to `repolist.csv`
3. Import the generated CSV file into your Google Spreadsheet for further analysis

**Script Configuration**
------------------------

The script uses a simple configuration variables.

Example `config variables`:

`git_audit.sh` - Generates a list of Repos and User permissions
```sh
# Set your GitHub username and token variables
GITHUB_USERNAME="[ USER_HANDLE ]"
GITHUB_TOKEN="[ ACCESS_TOKEN ]" # future consideration #
GITHUB_ORG="digitalconvergenceca"
```

`gitlist.sh` - Generates a limited list of repos
```sh
# Define a variable for the offset value
Org_Prefex="digitalconvergenceca/"
Org_Repo_Count=450
```
**Output**
----------

Each script generates a CSV file containing their perspective audit results, which can be imported into your Google Spreadsheet. The output includes:

* User permission access information for each repository
  * Repo, user handle and permissions ( Admin,	Maintain,	Push,	Triage,	Pull )
* List of all repositories
  * Name, ID, Created, Archived, Visibility, Description  

**Troubleshooting**
-------------------

If you encounter any issues while running the script, please check the following:

* Ensure the `gh` CLI tool is installed and updated to the latest version
* Check the script configuration for any errors or typos

