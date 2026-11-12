#!/usr/bin/env python3
"""ssh-tool.py - Outil SSH/SFTP via paramiko pour run-phase.ps1
Usage : ssh-tool.py <action> <host> <port> <user> <key_path> [action_args...]

Actions:
  test     - Test de connexion SSH : test <host> <port> <user> <key_path>
  exec     - Exécute une commande : exec <host> <port> <user> <key_path> <command> [stdin_data]
  put      - Copie un fichier vers la VM : put <host> <port> <user> <key_path> <local_path> <remote_path>
  get      - Récupère un fichier depuis la VM : get <host> <port> <user> <key_path> <remote_path> <local_path>
"""
import sys
import os
import paramiko

# La console Windows est en cp1252 : l'ecriture directe de sortie UTF-8
# (apt, log systemd, etc.) leve UnicodeEncodeError et fait echouer l'appel.
# On configure la sortie en UTF-8 avec replacement des caracteres non
# representables.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

ACTION = sys.argv[1]
HOST = sys.argv[2]
PORT = int(sys.argv[3])
USER = sys.argv[4]
KEY_PATH = sys.argv[5]

# Timeout d'execution : configurable via SSH_TIMEOUT (les installations de
# paquets via apt peuvent depasser plusieurs minutes).
EXEC_TIMEOUT = int(os.environ.get("SSH_TIMEOUT", "120"))

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, port=PORT, username=USER, key_filename=KEY_PATH,
               look_for_keys=False, allow_agent=False, timeout=30)

if ACTION == 'test':
    stdin, stdout, stderr = client.exec_command('true', timeout=30)
    code = stdout.channel.recv_exit_status()
    client.close()
    sys.exit(code)

elif ACTION == 'exec':
    COMMAND = sys.argv[6]
    STDIN_DATA = sys.argv[7] if len(sys.argv) > 7 else None
    if STDIN_DATA is not None:
        stdin, stdout, stderr = client.exec_command(COMMAND, timeout=EXEC_TIMEOUT)
        stdin.write(STDIN_DATA)
        stdin.channel.shutdown_write()
    else:
        stdin, stdout, stderr = client.exec_command(COMMAND, timeout=EXEC_TIMEOUT)
    out = stdout.read().decode(errors="replace")
    err = stderr.read().decode(errors="replace")
    code = stdout.channel.recv_exit_status()
    sys.stdout.write(out)
    sys.stderr.write(err)
    client.close()
    sys.exit(code)

elif ACTION == 'put':
    LOCAL_PATH = sys.argv[6]
    REMOTE_PATH = sys.argv[7]
    # Taille et empreinte du fichier local : servent de reference pour
    # verifier que le transfert n'a pas ete tronque (connexion coupee en
    # cours de route => fichier distant vide ou partiel).
    import hashlib
    with open(LOCAL_PATH, 'rb') as fh:
        local_data = fh.read()
    local_size = len(local_data)
    local_sha = hashlib.sha256(local_data).hexdigest()

    def verify_remote():
        """Retourne (ok, taille, sha) du fichier distant."""
        cmd = "stat -c %s {} 2>/dev/null; sha256sum {} 2>/dev/null | cut -d' ' -f1".format(
            REMOTE_PATH, REMOTE_PATH)
        stdin, stdout, stderr = client.exec_command(cmd, timeout=60)
        o = stdout.read().decode(errors='replace').split()
        e = stderr.read().decode(errors='replace')
        code = stdout.channel.recv_exit_status()
        if code != 0 or len(o) < 2:
            return (False, 0, '', e)
        try:
            size = int(o[0])
        except ValueError:
            return (False, 0, '', 'taille illisible: %r' % o[0])
        return (size == local_size and o[1] == local_sha, size, o[1], e)

    ok = False
    try:
        sftp = client.open_sftp()
        sftp.put(LOCAL_PATH, REMOTE_PATH)
        sftp.close()
        ok, rsize, rsha, err = verify_remote()
    except Exception as e:
        # Fallback : transfert par base64 via exec (si le sous-systeme sftp est indisponible)
        import base64
        payload = base64.b64encode(local_data).decode()
        cmd = "echo '{}' | base64 -d > {}".format(payload, REMOTE_PATH)
        stdin, stdout, stderr = client.exec_command(cmd, timeout=EXEC_TIMEOUT)
        out = stdout.read().decode(errors='replace')
        err = stderr.read().decode(errors='replace')
        code = stdout.channel.recv_exit_status()
        if code != 0:
            sys.stderr.write("put fallback failed: {} {}".format(err, out))
            client.close()
            sys.exit(1)
        ok, rsize, rsha, err = verify_remote()

    if not ok:
        sys.stderr.write(
            "put VERIFIE KO : {} attendu={} octets sha={} obtenu={} octets sha={} {}\n".format(
                REMOTE_PATH, local_size, local_sha[:16], rsize, (rsha or '')[:16], err))
        client.close()
        sys.exit(1)
    # Message de succes sur stdout : sur stderr, PowerShell 5.1 le
    # convertirait en erreur bloquante (ErrorActionPreference = Stop).
    print("put OK : {} ({} octets, sha {})".format(REMOTE_PATH, local_size, local_sha[:16]))
    client.close()
    sys.exit(0)

elif ACTION == 'get':
    REMOTE_PATH = sys.argv[6]
    LOCAL_PATH = sys.argv[7]
    try:
        sftp = client.open_sftp()
        sftp.get(REMOTE_PATH, LOCAL_PATH)
        sftp.close()
    except Exception:
        import base64
        stdin, stdout, stderr = client.exec_command(
            "base64 {}".format(REMOTE_PATH), timeout=EXEC_TIMEOUT)
        data = stdout.read().decode(errors='replace').strip()
        code = stdout.channel.recv_exit_status()
        if code != 0:
            client.close()
            sys.exit(1)
        with open(LOCAL_PATH, 'wb') as fh:
            fh.write(base64.b64decode(data))
    client.close()
    sys.exit(0)

else:
    print("Action inconnue: {}".format(ACTION), file=sys.stderr)
    sys.exit(2)
