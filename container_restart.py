import time
import json

retry_interval = 20  # in seconds
max_retries = 10
def container_restart(container_color:str):
  containers = {
      "orange": "az-jpeast-00-dev-ci-orange.dev.japaneast.az.staking.codefi az-jpeast-00-dev-rg az-jpeast-00-dev-agw az-jpeast-00-dev-ci-orange",
     "red": "az-jpeast-00-dev-ci-red.dev.japaneast.az.staking.codefi az-jpeast-00-dev-rg az-jpeast-00-dev-agw az-jpeast-00-dev-ci-red",
     "key3": "container_name3 resourcegroup3 agw3 container3"
  }

  values = containers[container_color].split(" ")
  container_name = values[0]
  resource_group = values[1]
  agw_name = values[2]
  container = values[3]

  json_data = json.loads(subprocess.run(["az", "network", "application-gateway", "address-pool", "list", "-g", resource_group, "--gateway-name", agw_name], stdout=subprocess.PIPE).stdout.decode('utf-8'))

  index = [i for i, v in enumerate(json_data[0]['backendAddresses']) if v['fqdn'] == container_name][0]
  print("index of the container in the addresses pool:", index)

  if index is not None:
      subprocess.run(["az", "network", "application-gateway", "address-pool", "update", "-g", resource_group, "--gateway-name", agw_name, "-n", "signers-pool", "--remove", "backendAddresses", str(index)])

  subprocess.run(["az", "container", "stop", "--name", container, "--resource-group", resource_group])

  status = json.loads(subprocess.run(["az", "container", "show", "--name", container, "--resource-group", resource_group, "--query", "instanceView.state"], stdout=subprocess.PIPE).stdout.decode('utf-8'))
  status = status.strip('"')

  for i in range(1, max_retries+1):
      if status != "Stopped" and status != "Succeeded":
          print("Container group is still transitioning, waiting for", retry_interval, "seconds before retrying...")
          time.sleep(retry_interval)
          status = json.loads(subprocess.run(["az", "container", "show", "--name", container, "--resource-group", resource_group, "--query", "instanceView.state"], stdout=subprocess.PIPE).stdout.decode('utf-8'))
          status = status.strip('"')
      else:
          break

  if status != "Stopped" and status != "Succeeded":
      print("Maximum number of retries reached, giving up.")
      exit(1)

  subprocess.
  
  
parser = argparse.ArgumentParser()
parser.add_argument("--container_color", type=str, required=True)
args = parser.parse_args()
container_restart(args.container_color)
