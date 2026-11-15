# De-hardening : revenir a l'etat anterieur au durcissement

Le durcissement d'un noeud Proxmox VE peut generer des blocages lors d'une
**montee de version** ou d'une mise a jour de paquets :

| Mesure de durcissement | Symptome bloque pendant l'upgrade |
|---|---|
| `PermitRootLogin` restreint + `Match Address` | l'installeur ne peut plus ouvrir de session root |
| `pam_faillock` / `pam_pwquality` stricts | un depot ou un script systeme echoue sur l'authentification |
| modules noyau filtres (`install ... /bin/false`) | le nouveau noyau ne demarre pas ou un module est requis |
| `/etc/fstab` modifie | un montage disparait au redemarrage |
| `ctrl-alt-del.target` masque | comportement inattendu du terminal |
| sysctl durcis (`kptr_restrict`, `dmesg_restrict`...) | une tache de mise a jour echoue silencieusement |
| comptes `UID 0` verrouilles, shells `nologin` | un script d'administration ne peut plus s'executer |

Le **de-hardening** retire ces mesures et restaure l'etat d'origine, a partir
des sauvegardes produites pendant le durcissement.

## Utilisation

### Client bash (aucune dependance Python)

```bash
# par mot de passe root
bash scripts/deharden.sh --host 192.168.1.50 --password 'secret'

# par cle SSH
bash scripts/deharden.sh --host 10.0.0.5 --key ~/.ssh/id_ed25519

# simulation : affiche ce qui serait fait, ne modifie rien
bash scripts/deharden.sh --host 10.0.0.5 --password 'secret' --dry-run

# en conservant les paquets installes par le durcissement
bash scripts/deharden.sh --host 10.0.0.5 --password 'secret' --keep-packages

# rapport local
bash scripts/deharden.sh --host 10.0.0.5 --password 'secret' --report ./deharden.md
```

Le client :

1. verifie la connectivite SSH ;
2. **refuse** une cible qui n'est pas un noeud Proxmox (`/etc/pve` absent) ;
3. copie `guest/deharden-pve.sh` sur la cible ;
4. l'execute et recupere le rapport Markdown.

Le mot de passe n'est jamais ecrit dans l'historique du shell distant : il est
passe via `SSH_ASKPASS` (un script temporaire, supprime a la sortie).

> **Cle SSH sur un systeme de fichiers monte** (`/mnt/c` sous WSL, `/media`
> sous Linux) : les permissions y sont forcees a `777` et SSH refuse la cle
> (`UNPROTECTED PRIVATE KEY FILE`). Le client copie donc la cle dans
> `$HOME/.ssh/` (mode `600`) avant de l'utiliser, et la supprime a la sortie.

### Equivalent Python (meme script distant)

```bash
python3 scripts/pve.py deharden --host 192.168.1.50 --password 'secret'
python3 scripts/pve.py deharden --host 10.0.0.5 --password 'secret' --dry-run
```

### Directement sur le noeud

```bash
scp guest/deharden-pve.sh root@serveur:/tmp/
ssh root@serveur 'bash /tmp/deharden-pve.sh --dry-run'
ssh root@serveur 'bash /tmp/deharden-pve.sh'
```

## Ce que fait le de-hardening

### 1. Sauvegarde de securite

Avant toute ecriture, l'etat courant est archive :

```
/root/deharden-safety-<horodatage>/etat-avant-dehardening.tar.gz
```

### 2. Restauration des fichiers sauvegardes

Les scripts de durcissement sauvegardent chaque fichier **avant** modification
dans :

```
/root/hardening-backups/<horodatage>/<chemin/du/fichier>.<epoch>   # CIS
/root/anssi-backups/<horodatage>/<chemin/du/fichier>.<epoch>        # ANSSI
```

> **Regle de restauration : la sauvegarde la plus ancienne gagne.**
> Le durcissement est souvent applique plusieurs fois (niveau 1 puis niveau 2,
> ou rejeu du script). Les sauvegardes ulterieures contiennent alors la version
> **deja durcie** du fichier : la restaurer ne retablirait rien.
> Comme `cp -a` preserve le `mtime`, la sauvegarde de `mtime` minimal est
> l'etat d'origine. Le de-hardening la restaure.

Les attributs sont conserves separement dans des fichiers `<nom>.mode`
(`<mode> <proprietaire> <groupe>`) pour les chemins dont le durcissement ne
modifie que les permissions (`/boot`, `/etc/cron.*`, `/etc/passwd`...) :

```
/root/hardening-backups/<horodatage>/etc/boot.mode
```

### 3. Suppression des fichiers crees

Les fichiers qui n'existaient pas avant le durcissement sont supprimes. La
liste est derivee des **manifestes** que le durcissement depose dans chaque
session de sauvegarde :

| Fichier de session | Contenu |
|---|---|
| `created.list` | chemins **crees** par le durcissement (a supprimer) |
| `modified.list` | chemins **modifies** (a restaurer) |
| `packages.before` | paquets installes avant le durcissement (reference du delta) |
| `sysctl.before` | **tous** les parametres noyau avant le durcissement (reversion exacte) |

Une seule session est prise en compte par racine de sauvegarde : la plus
**ancienne** qui contient un manifeste. Les sessions heritees (anterieures a
cette version, sans manifeste) sont ignorees, car leurs sauvegardes peuvent
correspondre a un etat deja durci. Si aucun manifeste n'existe, le script
retombe sur la liste codee en dur ci-dessous.

Un fichier de cette liste qui possede une sauvegarde **anterieure** au
durcissement pre-existait : il est alors restaure et non supprime.

```
/etc/modprobe.d/99-pve-hardening.conf      /etc/audit/rules.d/90-pve.rules
/etc/modprobe.d/99-anssi-usb.conf          /etc/fail2ban/filter.d/pveproxy.conf
/etc/sysctl.d/97-pve-hardening.conf        /etc/fail2ban/jail.d/pve-web.conf
/etc/sysctl.d/98-anssi.conf                /etc/fail2ban/jail.d/pve-web-http.conf
/etc/sysctl.d/99-pve-hardening.conf        /etc/rsyslog.d/99-anssi-remote.conf
/etc/ssh/sshd_config.d/00-pve-hardening.conf   /etc/cron.daily/aide-check
/etc/systemd/journald.conf.d/99-pve-hardening.conf   /etc/issue.net
/etc/security/limits.d/99-pve-hardening.conf    /etc/cron.allow
/etc/security/pwquality.conf               /root/rollback-hardening.sh
/etc/profile.d/99-pve-hardening.sh         /etc/pve/firewall/cluster.fw
/etc/profile.d/tmout.sh                    /etc/pve/nodes/<noeud>/firewall
```

### 4. Reversement des mesures d'etat

- **PAM** : les fichiers `/etc/pam.d/*` modifies sont restaures depuis leur
  sauvegarde (lignes `pam_faillock` / `pam_pwquality` strictes disparues) ;
- **systemd** : les services desactives ou masques sont re-actives
  (`ctrl-alt-del.target`, `avahi-daemon`, `cups`, `bluetooth`, `rsh`, `talk`,
  `telnet`, `inetd`, `nfs-kernel-server`, `samba`, `snmpd`, `vsftpd`...) ;
- **comptes** : le compte `pveadmin` cree par le durcissement est supprime,
  les comptes `UID 0` verrouilles sont deverrouilles, les shells de comptes
  systeme sont restaures (`daemon`, `bin`, `sys`, `games`...) ;
- **modules noyau** : `update-initramfs -u` reconstruit l'initramfs avec les
  modules restaures ;
- **depots apt** : les depots enterprise Proxmox desactives (`.disabled`) sont
  retablis ;
- **paquets** : seuls les paquets **installes par le durcissement** sont
  desinstalles (difference entre la liste `packages.before` deposee avant le
  durcissement et la liste actuelle). Les paquets systeme critiques
  (`libpam-modules`, `openssh-server`, `systemd`...) ne sont jamais touches.
  La desinstallation utilise `apt-get purge` : `remove` conserverait les
  *conffiles modifies* par le durcissement (`20auto-upgrades` de
  `unattended-upgrades`, `audit.rules` de `auditd`...), qui resteraient actifs
  alors que le paquet n'existait pas a l'origine ;

### 5. Reversion de l'etat d'execution

Les valeurs appliquees **a chaud** par le durcissement persistent apres la
suppression de ses fichiers de configuration (`sysctl --system` ne remet pas
a zero une valeur absente des fichiers). Le de-hardening les ramene donc
explicitement :

- **sysctl** : les parametres noyau sont remis a la valeur photographiee par le
  durcissement (`sysctl.before`, prise avant sa premiere modification), et non
  a des « valeurs par defaut » supposees. C'est indispensable : sur Debian 13,
  `kernel.dmesg_restrict` et `kernel.yama.ptrace_scope` valent deja `1`, donc
  les remettre a `0` degraderait la posture par rapport a l'etat d'origine ;
- **AppArmor** : les profils sont repasses en mode *complain*
  (`aa-complain`), c'est-a-dire non bloquants. Cette etape est executee
  **avant** la desinstallation des paquets : `aa-complain` appartient a
  `apparmor-utils`, que le durcissement a installe — lancee apres, elle ne
  ferait rien et laisserait les profils en *enforce* ;
- **montages** : `/tmp`, `/var/tmp` et `/dev/shm` sont remontes sans les
  options `nosuid`/`nodev`/`noexec` ajoutees par le durcissement ;
- **AIDE** : la base construite par le durcissement est supprimee ;
- **services** : `unattended-upgrades` est arrete, desactive **et demasque**
  (un mask laisserait une unite orpheline qui ferait echouer un futur
  re-durcissement), `ctrl-alt-del.target` est reactive.

> Ces ecarts d'etat d'execution disparaissent apres un redemarrage. Ils ne
> bloquent pas une montee de version : l'acces SSH, les services Proxmox et
> le gestionnaire de paquets restent operatifs immediatement apres le
> de-hardening.

### 6. Securite de l'operation

- la configuration SSH est restauree **en dernier**, et le service n'est
  recharge qu'apres verification par `sshd -t` : une configuration invalide
  ne peut pas couper l'acces ;
- le mode `--dry-run` n'ecrit rien ;
- si **aucune sauvegarde de durcissement** n'est trouvee, le script
  s'arrete (code `3`) sans rien modifier : de-durcir un noeud qui n'a jamais
  ete durci supprimerait des fichiers pre-existants. L'option `--force`
  permet de passer outre.

## Procedure de montee de version d'un noeud durci

```bash
# 1. simulation : ce que le de-hardening va faire
bash scripts/deharden.sh --host 192.168.1.50 --password 'secret' --dry-run

# 2. de-hardening reel
bash scripts/deharden.sh --host 192.168.1.50 --password 'secret'

# 3. verifier que le noeud est revenu a l'etat d'origine
python3 scripts/pve.py run --phase verify --ssh-host 192.168.1.50 \
    --audit-extra anssi,ceph,cis13,communautaire
#    -> la compliance doit redevenir identique a la baseline

# 4. monter l'ISO de la nouvelle version et redemarrer

# 5. re-durcir
python3 scripts/pve.py run --phase apply --target core --level 2 --ssh-host 192.168.1.50
python3 scripts/pve.py run --phase apply --target anssi --level 3 --ssh-host 192.168.1.50

# 6. controler la non-regression
python3 scripts/pve.py run --phase verify --ssh-host 192.168.1.50 --run-func
```

## Validation

La chaine complete (baseline -> durcissement -> de-hardening -> re-durcissement)
a ete executee sur une VM Proxmox VE reelle. Le rapport detaille (statuts
par controle, comparaison baseline / etat restaure, tests fonctionnels) est
dans [reports/rapport-validation-deharden.md](../reports/rapport-validation-deharden.md)
et son equivalent PDF.

Le rapport est **regenere a partir des artefacts** de la derniere chaine :

```bash
python3 scripts/gen-validation-deharden.py .            # Markdown
python3 scripts/gen-validation-deharden.py . --pdf      # Markdown + PDF
```

Le generateur selectionne le repertoire le plus recent de chaque etape
(`artifacts/baseline-*`, `hardened-*`, `dehardened-*`, `rehardened-*` et les
suites `func-*` correspondantes) : aucun chiffre n'est ecrit en dur.

Chaque repertoire d'artefact ne contient **qu'une seule passe** : le collecteur
reinitialise son repertoire de sortie distant avant chaque audit. Sans cela,
`checks.tsv` (ecrit en ajout) accumulerait les audits precedents et un
artefact contiendrait plusieurs centaines de lignes pour 160 controles.

## Depannage

| Symptome | Cause | Correctif |
|---|---|---|
| `la cible ne semble pas etre un noeud Proxmox` | mauvais hote, ou pas un Proxmox | verifier `ssh root@hote 'ls /etc/pve'` |
| `connexion SSH impossible` | cle non validee, ou port incorrect | `ssh -p <port> root@hote` pour verifier |
| `UNPROTECTED PRIVATE KEY FILE` | cle sur un systeme de fichiers monte (777) | utiliser `~/.ssh/...` ou laisser le client copier la cle |
| `Transfert incomplet` | le script distant a ete tronque | reexecuter : le transfert est verifie par SHA256 |
| `Aucune sauvegarde trouvee` (code 3) | le noeud n'a jamais ete durci par ces scripts | verifier `/root/hardening-backups` ; `--force` pour passer outre |
| SSH coupe apres le de-hardening | `sshd -t` invalide | le script ne recharge pas le service dans ce cas ; corriger `/etc/ssh/sshd_config` puis `systemctl reload ssh` |
| les paquets ne sont pas desinstalles | conflit de dependances | utiliser `--keep-packages` : le de-hardening n'a pas a les retirer |
| un module noyau reste bloque | `update-initramfs` a echoue | `update-initramfs -u -v` puis redemarrer |
| VM `aborted` pendant une chaine longue | derive d'horloge de l'invite (snapshot ancien) ou audio emule sur hote Windows | `VBoxManage modifyvm <vm> --audio=none --paravirt-provider=kvm`, puis resynchroniser l'horloge (`date -s`, `hwclock --systohc`) avant de relancer |
| `Guest seems to be unresponsive` dans `VBox.log` | l'hote a affame la VM (I/O lourdes, autre tache) | relancer la chaine sans travail parallele ; verifier `TM: catch-up` |
| `Could not get lock /var/lib/dpkg/lock-frontend ... (unattended-upgr)` pendant un durcissement | `unattended-upgrades`, installe a la section 7, demarre aussitot une passe APT qui conserve le verrou `dpkg` | corrige : le module core arrete les passes APT (`apt_stop_background`) apres la pose du paquet et toutes les installations passent par `apt_install` (`DPkg::Lock::Timeout=300`) |
| `Unit unattended-upgrades.service is masked` au re-durcissement | le de-hardening masquait le service ; le lien `/etc/systemd/system/unattended-upgrades.service -> /dev/null` survit a la desinstallation | corrige : le de-hardening fait `systemctl unmask` et supprime l'unite orpheline ; le durcissement fait `systemctl unmask` avant `enable` |
| `OS.APT.UPDATE` en echec sur un noeud sans abonnement | `pve-enterprise` / `ceph` repondent 401 : c'est l'etat d'usine de PVE, pas une regression | corrige : le test fonctionnel ignore les erreurs 401 de ces deux depots et ne retient que celles des depots Debian |
