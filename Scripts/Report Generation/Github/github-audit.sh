#!/bin/bash

#==============================================================================
# Description:  Retrieves branch listing for all active repositories and
#               permissions of users for a GitHub Organization and exports them
#               to CSV files.
#
# Usage:        ./git_audit.sh <OUTPUT_Audit_FILE.csv>
# Example:      ./git_audit.sh owner_user_permissions.csv
# Outputs:      <OUTPUT_Audit_FILE.csv> and repolist.csv
#
# Dependencies:
#   - GitHub CLI (gh): https://cli.github.com/
#   - jq: https://stedolan.github.io/jq/
# Author: Trevor Leadley <trevor.leadley@digitalconvergence.ca>
#==============================================================================

# Set your GitHub username and token variables
GITHUB_USERNAME="[ User_Name ]"
GITHUB_TOKEN="" # Future consideration #
GITHUB_ORG="digitalconvergenceca"
# List all repositories owned by the user
gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /orgs/$GITHUB_ORG/repos --paginate | jq '.[] | {name, id, created_at, archived, visibility, description}' > repos.json
json=`cat repos.json`
echo "Name, ID, Created, Archived, Visibility, Description" > repolist.csv
jq -r '[.name, .id, .created_at, .archived, .visibility, .description] | @csv' repos.json >> repolist.csv
#echo $json
# Loop through each repository and list collaborators with their access permissions
while IFS= read -r line; do
  repo_name=$(echo $line)
  #repo_id=$(echo $line | jq -r '.id')
  repo=$(echo $repo_name | tr -d '"')

# Use the GitHub API to get collaborators for this repository
gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/$GITHUB_ORG/$repo/collaborators --paginate | jq '.[] | {login, email, permissions}' > collab.json

collab=`cat collab.json`

# Print out the repository name and a list of collaborators with their access permissions
#echo "$repo"

while IFS= read -r collab && read -r perms; do
   username=$(echo $collab | tr -d '"' )
   permissions=$(echo $perms | tr -d '{}"' )
   line=$(echo $repo,$username,$permissions)
   echo $line
    # Print out the collaborator's access permissions (e.g., "pull", "push", etc.)

 done < <(jq -c '.login, .permissions' <<<"$collab")

done < <(jq '.name' <<<"$json") #< repos.json
