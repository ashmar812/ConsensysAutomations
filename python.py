import subprocess

# This is our shell command, executed by Popen.

p = subprocess.Popen("ls -lh", stdout=subprocess.PIPE, shell=True)

print(p.communicate())
