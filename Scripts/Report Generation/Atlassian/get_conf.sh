#!/bin/bash#
#file get_conf.sh
# Requirments: install jq and curl
# bash script to run in MacOS, linux or similar terminal
# How to run: ./get_conf.sh

APItoken="<API Token>" #generate here https://id.atlassian.com/manage-profile/security/api-tokens
AdminEmail="trevor.leadley@digitalconvergence.ca"
tenant="digitalconvergence.atlassian.net"
spaces_header="SpaceId,Key,Name"
space_perm_header="SpaceId,UserType,UserID,Operation,Target"
filename="spaces.csv"
perm_file="spaces_perm.csv"

echo -e "${spaces_header}" > "$filename"
echo -e "${space_perm_header}" > "$perm_file"

curl --request GET --url "https://$tenant/wiki/rest/api/space?type=global&start=1&limit=1000" --header 'Accept: application/json' --user $AdminEmail:$APItoken | jq > spaces.json
cat projects.json | jq --raw-output '.[] | [.id, .key, .name] | @csv'  >> $filename
json=`cat spaces.json`

while IFS= read -r file; do
   spaceId=$(echo $file | tr -d '"' )
echo $spaceId > /dev/null 2>&1
# https://community.atlassian.com/t5/Confluence-questions/Fetch-list-of-all-spaces-in-Confluence/qaq-p/1452744
curl -s --request GET --url "https://$tenant/wiki/api/v2/spaces/${spaceId}/permissions" --header 'Accept: application/json' --user $AdminEmail:$APItoken | jq --raw-output '.results[] | [ "'$spaceId'", .principal.type, .principal.id, .operation.key, .operation.targetType] | @csv' >> $perm_file

done < <(jq '.results.[] | .id' <<<"$json") #< projects.json
