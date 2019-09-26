#/bin/bash
while getopts a:o:r:d:m:f: option
do
case "${option}"
in
a) AUTH_TOKEN=${OPTARG};;
o) REPO_OWNER=${OPTARG};;
r) REPO=${OPTARG};;
d) DIST_FOLDER=${OPTARG};;
m) COMMIT_MESSAGE=${OPTARG};;
f) UP_FILE=$OPTARG;;
esac
done

git_repo=$REPO_OWNER'/'$REPO
path_Artifacts=$UP_FILE
zip_artifacts='./'$UP_FILE

zip_artifacts64=$(cat $zip_artifacts | base64 -w 0)
touch blob_data.txt
echo $'{"content":"'$zip_artifacts64'","encoding": "base64"}' >> blob_data.txt
latest_commit=$(curl -k -X 'GET' "https://api.github.com/repos/${git_repo}/commits/master" -H $'Authorization: Basic '$AUTH_TOKEN$'' | jq -r '.sha')
current_reference=$(curl -k -X 'GET' "https://api.github.com/repos/${git_repo}/git/refs/heads/master" -H $'Authorization: Basic '$AUTH_TOKEN$'' | jq -r '.object | .sha')
root_tree=$(curl -k -X 'GET' "https://api.github.com/repos/${git_repo}/git/trees/${latest_commit}" -H $'Authorization: Basic '$AUTH_TOKEN$'' | jq -r '.sha')
dist_tree=$(curl -k -X 'GET' "https://api.github.com/repos/${git_repo}/git/trees/${latest_commit}" -H $'Authorization: Basic '$AUTH_TOKEN$'' | jq -r '.tree[] | select(.path=="'$DIST_FOLDER$'") | .sha')
blob_artifacts=$(curl -k -X 'POST' "https://api.github.com/repos/${git_repo}/git/blobs" -H "Content-type: application/json" -H 'User-Agent: curl/7.47.0' -H $'Authorization: Basic '$AUTH_TOKEN$'' --data-binary "@./blob_data.txt" | jq -r '.sha')
new_dist_tree=$(curl -k -X 'POST' "https://api.github.com/repos/${git_repo}/git/trees" -H "Content-type: application/json" -H 'User-Agent: curl/7.47.0' -H $'Authorization: Basic '$AUTH_TOKEN$'' --data-binary $'{\"base_tree\": \"'"$dist_tree"$'\", \"tree\": [{\"path\": \"'"$path_Artifacts"$'\",\"mode\": \"100644\",\"type\": \"blob\",\"sha\": \"'"$blob_artifacts"$'\"}]}' | jq -r '.sha')
new_root_tree=$(curl -k -X 'POST' "https://api.github.com/repos/${git_repo}/git/trees" -H "Content-type: application/json" -H 'User-Agent: curl/7.47.0' -H $'Authorization: Basic '$AUTH_TOKEN$'' --data-binary $'{\"base_tree\": \"'"$root_tree"$'\", \"tree\": [{\"path\": \"'"$DIST_FOLDER"$'\",\"mode\": \"040000\",\"type\": \"tree\",\"sha\": \"'"$new_dist_tree"$'\"}]}' | jq -r '.sha')
new_commit=$(curl -k -X 'POST' "https://api.github.com/repos/${git_repo}/git/commits" -H "Content-type: application/json" -H 'User-Agent: curl/7.47.0' -H $'Authorization: Basic '$AUTH_TOKEN$'' --data-binary $'{\"message\": \"'"$COMMIT_MESSAGE"$'\",\"parents\": [\"'"$latest_commit"$'\"],\"tree\": \"'"$new_root_tree"$'\"}' | jq -r '.sha')
curl -k -X 'PATCH' "https://api.github.com/repos/${git_repo}/git/refs/heads/master" -H $'Authorization: Basic '$AUTH_TOKEN$'' --data-binary $'{\"sha\": \"'"$new_commit"$'\",\"force\": true}'
