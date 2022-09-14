import subprocess
subprocess.Popen(f"ssh {"stark"}@{"52.191.129.181"} {cmd}", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).communicate()
