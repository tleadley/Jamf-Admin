#!/bin/bash#
#file audit-permissions.sh
# Requirments: install jq and curl
# bash script to run in MacOS, linux or similar terminal
# How to run: ./audit-permissions.sh

projectkeys=(BFMS)  # insert here the list of project keys
APItoken="<API Token>" #generate here https://id.atlassian.com/manage-profile/security/api-tokens
AdminEmail="trevor.leadley@digitalconvergence.ca"
tenant="digitalconvergence.atlassian.net"

for pkey in "${projectkeys[@]}"
do
echo "" > $pkey.csv
echo "working on project: $pkey"
echo -e "NAME;accountID;email* (public profiles);permission type" > $pkey.csv
# put the desired permission for this endpoint https://developer.atlassian.com/cloud/jira/platform/rest/v2/api-group-user-search/#api-rest-api-2-user-permission-search-get
permissions=(BROWSE_PROJECTS PROJECT_ADMIN ASSIGN_ISSUE CREATE_ISSUE DELETE_ISSUE EDIT_ISSUE SCHEDULE_ISSUE COMMENT_ISSUE TRANSITION_ISSUE)
  for permission in "${permissions[@]}"
  do
  curl -s --request GET --url "https://$tenant/rest/api/2/user/permission/search?permissions=$permission&projectKey=$pkey" --header 'Accept: application/json' --user $AdminEmail:$APItoken | jq --arg perm "$permission" '.[] | ."permission"=$perm | "\(.displayName); \(.accountId); \(.emailAddress); \(.permission)"' | tr -d '"' >> $pkey.csv
  done
done
