#!/bin/bash

declare -A containers
Color="$1"
retry_interval=20 # in seconds
max_retries=5
# Add keys and values to the array
containers=( ["orange"]="az-jpeast-00-dev-ci-orange.dev.japaneast.az.staking.codefi az-jpeast-00-dev-rg az-jpeast-00-dev-agw az-jpeast-00-dev-ci-orange" ["red"]="az-jpeast-00-dev-ci-red.dev.japaneast.az.staking.codefi az-jpeast-00-dev-rg az-jpeast-00-dev-agw az-jpeast-00-dev-ci-red" ["key3"]="container_name3 resourcegroup3 agw3 container3" )

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
if [ "$index" ]; then
	az network application-gateway address-pool update -g $resource_group --gateway-name $agw_name -n signers-pool --remove backendAddresses $index
fi

# Stop container
az container stop --name $container --resource-group $resource_group

# Wait for the container to stop
for i in $(seq 1 $max_retries); do
	Status=$(az container show --name $container --resource-group $resource_group --query "instanceView.state");Status=${Status//\"}
	if [ $Status != "Stopped" ] && [ $Status != "Succeeded" ]; then
		echo "Container group is still transitioning, waiting for $retry_interval seconds before retrying..."
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
  
# Start container
az container start --name $container --resource-group $resource_group
# Wait for the container to start
for i in $(seq 1 $max_retries); do
	Status=$(az container show --name $container --resource-group $resource_group --query "instanceView.state");Status=${Status//\"}
	if [ $Status != "Running" ] && [ $Status != "Succeeded" ]; then
		echo "Container group is still transitioning, waiting for $retry_interval seconds before retrying..."
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

# Add a container
az network application-gateway address-pool update -g $resource_group --gateway-name $agw_name -n signers-pool --add backendAddresses fqdn=$container_name

	
