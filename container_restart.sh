#!/bin/bash

declare -A containers
Color="$1"
retry_interval=60 # in seconds
max_retries=7
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
echo "Get the index of the container in the addresses pool"
index=$(echo $json_data | jq -r --arg fqdn "$container_name" '.[0].backendAddresses | index(map(select(.fqdn == $fqdn)))')
echo "index of the container in the addresses pool: $index"
# Remove a container
 if [ -n "$index" ]; then
  az network application-gateway address-pool update -g "$resource_group" --gateway-name "$agw_name" -n signers-pool --remove backendAddresses "$index"
 else
  echo "ERROR: The variable 'index' is not set or has a null value. Cannot remove backend address."
 fi

echo "Stop the container"
echo "Wait for the container to stop"
az container stop --name $container --resource-group $resource_group
for i in $(seq 1 $max_retries); do
	Status=$(az container show --name $container --resource-group $resource_group --query "instanceView.state");Status=${Status//\"}
	if [ $Status != "Stopped" ] && [ $Status != "Succeeded" ]; then
		echo "Container group is still transitioning, status : $Status, waiting for $retry_interval seconds before retrying..."
		sleep $retry_interval
		Status=$(az container show --name $container --resource-group $resource_group --query "instanceView.state");Status=${Status//\"}
	else
		break
	fi
done
if [ $Status != "Stopped" ] && [ $Status != "Succeeded" ]; then
	echo "Maximum number of retries reached, giving up."
	exit 1
fi
  
echo "Start container"
sleep $retry_interval
az container start --name $container --resource-group $resource_group
echo "Wait for the container to start"
for i in $(seq 1 $max_retries); do
	Status=$(az container show --name $container --resource-group $resource_group --query "instanceView.state");Status=${Status//\"}
	if [ $Status != "Running" ] && [ $Status != "Succeeded" ]; then
		echo "Container group is still transitioning, status : $Status, waiting for $retry_interval seconds before retrying..."
		sleep $retry_interval
		Status=$(az container show --name $container --resource-group $resource_group --query "instanceView.state");Status=${Status//\"}
	else
		break
	fi
done
if [ $Status != "Running" ] && [ $Status != "Succeeded" ]; then
	echo "Maximum number of retries reached, giving up."
	exit 1
fi

echo "Add a container"
az network application-gateway address-pool update -g $resource_group --gateway-name $agw_name -n signers-pool --add backendAddresses fqdn=$container_name
echo "restart is completed"

echo "Waiting for the container to be live"
# Set the time when the loop should end (in seconds)7 minutes
DURATION_IN_MINUTES=7
END_TIME=$(date -u -d "+ $DURATION_IN_MINUTES minutes" +"%Y-%m-%d %H:%M:%S")
echo $END_TIME
# Wait time between log checks (in seconds)
WAIT_TIME_IN_SECONDS=60

# Time difference threshold for considering a log entry (in seconds)
TIME_DIFF_THRESHOLD=30000

# Loop for the specified duration
while [[ $(date -u +"%Y-%m-%d %H:%M:%S") < $END_TIME ]]; do
  # Wait for the specified time before checking again
  sleep $WAIT_TIME_IN_SECONDS
  # Run the az container logs command and retrieve the second-to-last log
  LOG=$(az container logs --resource-group $resource_group --name $container | tail -n 2 | head -n 1 || true)

  # Check if the log contains "200" or "210"
  if [[ "$LOG" =~ (200|210) ]]; then
    LOG_TIME=$(echo $LOG | awk '{print $1" "$2}')
    # Get the current time in UTC format
    CURRENT_TIME=$(date -u +"%Y-%m-%d %H:%M:%S.%3N+00:00")

    # Convert the log's time to UTC format
    LOG_TIME_UTC=$(date -u -d "$LOG_TIME" +"%Y-%m-%d %H:%M:%S.%3N+00:00")

    # Calculate the difference between the two times in seconds using awk
    TIME_DIFF=$(echo "$(date -u -d "$CURRENT_TIME" +"%s.%N") - $(date -u -d "$LOG_TIME_UTC" +"%s.%N")" | awk '{printf "%.0f\n", $1 * 1000}')

    # Check if the time difference is less than 30 seconds
    if [[ $TIME_DIFF -lt TIME_DIFF_THRESHOLD ]]; then
      echo "The difference between the log's time and the current time in UTC is less than 30 seconds and status code is 200/210"
      break
    else
      echo "The difference between the log's time and the current time in UTC is more than 30 seconds,checking agian"
    fi
  fi

done

echo "Conditions not met within $DURATION_IN_SECONDS seconds"
exit 1
