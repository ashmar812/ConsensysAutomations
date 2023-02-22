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
az container stop --name $container --resource-group $resource_group

echo "Wait for the container to stop"
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

