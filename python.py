import re
import socket

import paramiko
import datetime

import  argparse

socket.getaddrinfo('localhost', 8080)
ssh = paramiko.SSHClient()
my_user = 'stark'
logs = []
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
allowed_delay = 1



def check(host_name:str , rounds:int , key_path:str):
    # pkey should be a PKey object and not a string
    ssh.connect(host_name, 22, my_user, pkey=paramiko.RSAKey.from_private_key_file(key_path))

    # command to get logs
    stdin, stdout, stderr = ssh.exec_command('docker logs -n 5  committee_committee_1')
    lines = ((stdout.readlines()).__str__())
    pattern = re.compile(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}', re.IGNORECASE)
    match = pattern.findall(lines)
    now = datetime.datetime.utcnow()
    current_time = now.strftime("%Y-%m-%d %H:%M:%S")
    last_log_time_obj = datetime.datetime.strptime(match[len(match) - 1], '%Y-%m-%d %H:%M:%S')
    current_time_obj = datetime.datetime.strptime(current_time, '%Y-%m-%d %H:%M:%S')
    the_difference = (current_time_obj - last_log_time_obj).total_seconds()
    print(the_difference)
    print("last_log_time_obj", last_log_time_obj)
    print("current_time_obj", current_time_obj)
    print(rounds)
    if the_difference < allowed_delay:
        if rounds:
            print("fail to restart")
        else:
            rounds += 1
            print("need restart")
            stdout = ssh.exec_command('touch NewFile.txt')
            # stdout = ssh.exec_command('docker container restart committee_committee_1')
            # time.sleep(120)
            check(hostname, rounds, key_path)
    else:
        print("everything is Ok")
    ssh.close()


parser = argparse.ArgumentParser()
parser.add_argument("--ssh-path", type=str, required=True)
parser.add_argument("--hostname", type=str, required=True)
parser.add_argument("--rounds", type=int, default=0)
args = parser.parse_args()
print(f"ssh-path: {args.ssh_path}")
check(args.hostname, args.rounds, args.ssh_path)
