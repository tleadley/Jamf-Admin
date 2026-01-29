#!/bin/bash
#file get_roles.sh
# Requirments: install jq and curl
# bash script to run in MacOS, linux or similar terminal
# How to run: ./get_roles.sh
# Set your Atlassian Cloud API credentials

APItoken="<API TOKEN>" #generate here https://id.atlassian.com/manage-profile/security/api-tokens
AdminEmail="trevor.leadley@digitalconvergence.ca"
tenant="digitalconvergence.atlassian.net"
filename="projects.csv"
proj_header="id,key,name,ProjectTypeKey"
role_header="Project Key,Roleid,Username,UserID"
projectroles=(10200 10296 10202 10295 10558 10002)
proj_role="proj_role.csv"

echo -e "${proj_header}" > "$filename"
echo -e "${role_header}" > "$roj_role"

# Make the API GET request
curl --request GET --url "https://${tenant}/rest/api/2/project" --header 'Accept: application/json' --user $AdminEmail:$APItoken | jq > projects.json
cat projects.json | jq --raw-output '.[] | [.id, .key, .name, .projectTypeKey] | @csv' >> $filename
json=`cat projects.json`

while IFS= read -r file; do
   proj=$(echo $file | tr -d '"' )
echo $proj

#proj="BFMS"
for prole in "${projectroles[@]}"
do

curl --request GET --url "https://${tenant}/rest/api/2/project/${proj}/role/${prole}" --header 'Accept: application/json' --user $AdminEmail:$APItoken | jq --raw-output '.actors[] | ["'$proj'", "'$prole'", .displayName, .id] | @csv' >> $proj_role

done

done < <(jq '.[] | .key' <<<"$json") #< projects.json
