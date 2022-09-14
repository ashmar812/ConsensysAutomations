import subprocess

# This is our shell command, executed by Popen.
ssh -o StrictHostKeyChecking=no stark@52.191.129.181 
p = subprocess.Popen("ls -lh", stdout=subprocess.PIPE, shell=True)

print(p.communicate())
