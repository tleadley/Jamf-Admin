#!/bin/bash

# Description:
#   Script to extract a specific part of output from `gh repo list` command.
#
# Usage:
#   ./gitlist.sh
#
# Author: Trevor Leadley <trevor.leadley@digitalconvergence.ca>

# Define a variable for the offset value

Org_Prefex="digitalconvergenceca/"
Org_Repo_Count=450

function char-count() {

local res=$(echo -n "$Org_Prefex" | wc -c | awk '{print $1}')

echo "$((res + 1))"

}
# Get offset count for character removal
offset=$(char-count)
#echo $offset

# Use the variable in your command
gh repo list digitalconvergenceca -L $Org_Repo_Count | awk '{print substr($0,'$offset')}' >> gitlist.csv
