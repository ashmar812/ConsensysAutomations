#!/bin/bash

declare -A containers
Color="$1"
retry_interval=20 # in seconds
max_retries=5
# Add keys and values to the array
containers=( ["blue"]="az-cntrus-00-prod-ci-blue.centralus.az.staking.codefi az-cntrus-00-prod-rg az-cntrus-00-prod-agw az-cntrus-00-prod-ci-blue" 
	     ["red"]="az-cntrus-00-prod-ci-red.centralus.az.staking.codefi az-cntrus-00-prod-rg az-cntrus-00-prod-agw az-cntrus-00-prod-ci-red" 
	     ["black"]="az-jpeast-00-prod-ci-black.japaneast.az.staking.codefi az-jpeast-00-prod-rg az-jpeast-00-prod-agw az-jpeast-00-prod-ci-black"
	     ["white"]="az-jpeast-00-prod-ci-white.japaneast.az.staking.codefi az-jpeast-00-prod-rg az-jpeast-00-prod-agw az-jpeast-00-prod-ci-white"
	     ["green"]="az-neurop-00-prod-ci-green.northeurope.az.staking.codefi az-neurop-00-prod-rg az-neurop-00-prod-agw az-neurop-00-prod-ci-green"
	     ["yellow"]="az-neurop-00-prod-ci-yellow.northeurope.az.staking.codefi az-neurop-00-prod-rg az-neurop-00-prod-agw az-neurop-00-prod-ci-yellow"
	     ["pink"]="staking-signer-prod-ci-pink.staking.codefi staking-signer-prod-rg staking-signer-prod-agw staking-signer-prod-ci-pink"
	     ["purple"]="staking-signer-prod-ci-purple.staking.codefi staking-signer-prod-rg staking-signer-prod-agw staking-signer-prod-ci-purple")
			 
# Split the values on the space character
IFS=' ' read -r -a values <<< "${containers[$Color]}"
container_name=${values[0]}
resource_group=${values[1]}
agw_name=${values[2]}
container=${values[3]}


json_data=$(az network application-gateway address-pool list -g $resource_group --gateway-name $agw_name)
# Get the index of the container in the addresses pool
index=$(echo $json_data | jq -r --arg fqdn "$container_name" '.[0].backendAddresses | index(map(select(.fqdn == $fqdn)))')
echo "index of the container in the addresses pool: $index"
# Remove a container

last_log=$(az container logs --resource-group az-cntrus-00-prod-rg --name az-cntrus-00-prod-ci-blue --since-time "$(az container show --resource-group az-cntrus-00-prod-rg --name az-cntrus-00-prod-ci-blue --query 'logs[].time' --output tsv | tail -2 | head -1)" --tail 1)
echo $last_log
# Convert the last log timestamp to Unix epoch time
last_log_time=$(date -d "$last_log" +%s)
echo $last_log_time
# Get the current time in Unix epoch time
current_time=$(date -u +%s)
echo $current_time
# Calculate the difference between the last log time and the current time
time_diff=$((current_time - last_log_time))
echo $time_diff
# Define a threshold value in seconds (e.g., 60 seconds)
threshold=60

# Check if the time difference is less than the threshold
if [ "$time_diff" -lt "$threshold" ]; then
  echo "Last log time is near real-time."
else
  echo "Last log time is not near real-time."
fi
