#!/usr/bin/env python3
"""ssh-exec.py - Wrapper SSH via paramiko pour run-phase.ps1
Usage : ssh-exec.py <host> <port> <user> <key_path> <command> [stdin_data]
"""
import sys
import paramiko

HOST = sys.argv[1]
PORT = int(sys.argv[2])
USER = sys.argv[3]
KEY_PATH = sys.argv[4]
COMMAND = sys.argv[5]
STDIN_DATA = sys.argv[6] if len(sys.argv) > 6 else None

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, port=PORT, username=USER, key_filename=KEY_PATH,
               look_for_keys=False, allow_agent=False, timeout=30)

if STDIN_DATA is not None:
    stdin, stdout, stderr = client.exec_command(COMMAND, timeout=120)
    stdin.write(STDIN_DATA)
    stdin.channel.shutdown_write()
else:
    stdin, stdout, stderr = client.exec_command(COMMAND, timeout=120)

out = stdout.read().decode(errors="replace")
err = stderr.read().decode(errors="replace")
code = stdout.channel.recv_exit_status()

sys.stdout.write(out)
sys.stderr.write(err)
client.close()
sys.exit(code)
