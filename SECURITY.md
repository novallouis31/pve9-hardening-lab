# Security Policy

## Supported versions

Ce depot est un **lab de test** (environnement de laboratoire VirtualBox).
Il n'est pas destine a la production. Les correctifs sont apportes sur la
branche `master`.

## Perimetre

Ce projet manipule des **identifiants de laboratoire uniquement** :

| Element | Nature |
|---|---|
| Cle privee du lab (`.keys/id_ed25519`) | **jamais** versionnee (`.gitignore`) |
| Mot de passe root des VM | `19581958`, valeur de lab documentee dans `docs/` |
| Cle publique du lab (`.keys/id_ed25519.pub`) | presente localement uniquement |

Les mots de passe et cles reellement utilises dans vos environnements de
production ne doivent **jamais** transiter par ce depot.

## Signalement d'une vulnerabilite

Si vous identifiez un probleme dans les scripts de durcissement (par exemple
un controle qui echoue silencieusement, ou une deviation de securite
introduite par erreur) :

1. ouvrez une issue **privée** ou contactez directement le maintaineur ;
2. decrivez la version (tag), la VM concernee et les etapes de
   reproduction ;
3. ne publiez pas de detail exploitable avant correction.

Pour une vulnerabilite dans **Proxmox VE** ou **Debian**, signalez directement
le projet amont :

- Proxmox VE : https://forum.proxmox.com / https://bugzilla.proxmox.com
- Debian : https://www.debian.org/security/

## Points de securite connus du lab

Ces ecarts sont **assumes** et documentes dans les rapports :

| Point | Position retenue |
|---|---|
| Root SSH | `PermitRootLogin no` global + exception `Match Address <reseau de management>` (option B du guide PVE 9, qui interdit `no` sur Proxmox) |
| Chiffrement de disque | hors perimetre d'installation du lab |
| Secure Boot | indisponible sous VirtualBox (firmware BIOS) |
| Ceph sans cluster | le lab durcit la configuration client, pas un cluster reel |
| Depots enterprise Proxmox | desactives dans le lab (licence non requise) |

Le rapport PDF de chaque cycle liste les controles `NA` avec leur motif : ce
sont les seuls ecarts assumes.

## Verification de l'etat d'un snapshot

Les snapshots VirtualBox `pristine` representent un etat **non durci** et
sont le point de depart de chaque cycle. Ne les modifiez pas a la main :
un etat contamine fausserait la baseline et les conclusions de
non-regression.
