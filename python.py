socket.getaddrinfo('localhost', 8080)
ssh = paramiko.SSHClient()
hostname = '52.191.129.181'
my_user = 'stark'

logs = []
my_key_file = OS.environ['SSH_PRIVATE_KEY']
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
allowed_delay = 10
rounds = 0


def check(host_name, rounds):
    # pkey should be a PKey object and not a string
    ssh.connect(host_name, 22, my_user, pkey=my_key_file)

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
            # stdout = ssh.exec_command('touch NewFile.txt')
            # stdout = ssh.exec_command('docker container restart committee_committee_1')
            # time.sleep(120)
            check(hostname, rounds)
    else:
        print("everything is Ok")

    ssh.close()


check(hostname, rounds)
