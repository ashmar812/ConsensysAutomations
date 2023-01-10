import re
import socket
import time
import paramiko
import datetime
import  argparse

socket.getaddrinfo('localhost', 8080)
ssh = paramiko.SSHClient()
my_user = 'stark'
logs = []
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
allowed_delay = 10

def check(host_name:str , rounds:int , key_path:str,container_id:str):
    # pkey should be a PKey object and not a string
    ssh.connect(host_name, 22, my_user, pkey=paramiko.RSAKey.from_private_key_file(key_path))

    # command to get logs
    stdin, stdout, stderr = ssh.exec_command(f'docker logs -n 5  {container_id}')
    lines = ((stdout.readlines()).__str__())
    pattern = re.compile(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}', re.IGNORECASE)
    match = pattern.findall(lines)
    now = datetime.datetime.utcnow()
    current_time = now.strftime("%Y-%m-%d %H:%M:%S")
    last_log_time_obj = datetime.datetime.strptime(match[len(match) - 1], '%Y-%m-%d %H:%M:%S')
    current_time_obj = datetime.datetime.strptime(current_time, '%Y-%m-%d %H:%M:%S')
    the_difference = (current_time_obj - last_log_time_obj).total_seconds()
    print("------------------------------")
    print("last_log_time_obj: ", last_log_time_obj)
    print("current_time_obj: ", current_time_obj)
    print("the difference: ",the_difference,"sec")
    print("restart rounds: ",rounds)
    if the_difference > allowed_delay:
        if rounds:
            print("fail to restart  X")
            stdout = ssh.exec_command('echo "fail to restart->`date +"%d-%m-%Y+%T"`" >>jenkins_events.txt')
            sys.exit(1)
        else:
            stdout = ssh.exec_command(f'docker container restart {container_id}')
            rounds += 1
            print("restarting......")
            stdout = ssh.exec_command('echo "need a restart->`date +"%d-%m-%Y+%T"`" >>jenkins_events.txt')
            time.sleep(20)
            check(host_name, rounds, key_path)
    else:
        stdout = ssh.exec_command('echo "everything is Ok->`date +"%d-%m-%Y+%T"`" >>jenkins_events.txt')
        print("everything is Ok")
    ssh.close()


parser = argparse.ArgumentParser()
parser.add_argument("--ssh-path", type=str, required=True)
parser.add_argument("--hostname", type=str, required=True)
parser.add_argument("--rounds", type=int, default=0)
parser.add_argument("--container_id", type=str, required=True)
args = parser.parse_args()
check(args.hostname, args.rounds, args.ssh_path,args.container_id)
