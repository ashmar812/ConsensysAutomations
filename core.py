import json
import re
import sys

BODY_FILE_NAME = "eventData.json"
VIRTUAL_MACHINE_NAME_REGEX_PATTERN = r"\/microsoft\.compute\/virtualmachines\/(\w*)]"
VM_TO_IP = {
    "stark-immuta-vm981d04ce":"52.191.129.181",
    "starkware44a5d128":"52.156.73.202"
}


def get_description(body):
    return body["description"]

def get_virtual_machine_name(description:str):
    matches = re.finditer(VIRTUAL_MACHINE_NAME_REGEX_PATTERN, description, re.MULTILINE)

    for matchNum, match in enumerate(matches, start=1):
        return match.groups()[0]
    return None

def get_machine_ip(machine_name:str):
    if machine_name in VM_TO_IP:
        return VM_TO_IP[machine_name]
    return None
if __name__ == "__main__":
    with open(BODY_FILE_NAME) as f:
        body = json.load(f)[1]
        description = get_description(body)
    virtual_machine_name = get_virtual_machine_name(description)
    if virtual_machine_name is not None:
        print(get_machine_ip(virtual_machine_name))
    else:
        print("There is no virtual machine info in the description", file=sys.stderr)
