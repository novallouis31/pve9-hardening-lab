# Gestion du projet avec GitKraken

Ce guide explique les operations courantes sur ce depot avec
[GitKraken](https://www.gitkraken.com/) (client Git graphique, version 12.6.2
utilisee sur le poste de developpement). La **CLI GitKraken** (`gk`) est
egalement utilisable pour les operations scriptables.

## Prerequis

| Element | Valeur |
|---|---|
| Depot local | `C:\Users\Louis\Documents\Projet par defaut\pve9-hardening-lab` |
| Branche de travail | `master` |
| Compte auteur | `Louis <ads.novallouis@gmail.com>` (configure dans GitKraken) |
| Tags de livraison | `v1.0.0`, `v1.1.0`, `v1.2.0` |

## 1. Cloner le depot

Dans GitKraken : **File > Clone > Local** ou **Clone or Create > Repository**.

```
Repository URL : https://github.com/<votre-compte>/pve9-hardening-lab
Destination    : C:\Users\Louis\Documents\Projet par defaut\pve9-hardening-lab
```

En ligne de commande (equivalent) :

```bash
git clone https://github.com/<votre-compte>/pve9-hardening-lab.git
```

## 2. Se connecter a GitHub depuis GitKraken

GitKraken utilise un **Personal Access Token** (PAT) pour les depots
GitHub. Le PAT est stocke dans le magasin chiffre de l'application
(`%APPDATA%\.gitkraken\secFile`) et n'est jamais ecrit dans le depot.

### Creer le PAT

1. GitHub > **Settings** > **Developer settings** > **Personal access tokens**
   > **Tokens (classic)**
2. **Generate new token (classic)**
3. Perimetres :
   - `repo` (acces complet aux depots prives) — ou `public_repo` si le depot
     est public
   - `read:org` si le depot est dans une organisation
   - `workflow` si vous publiez des workflows GitHub Actions
4. **Generate token** puis copiez le jeton (il n'est plus affiche ensuite)

### Enregistrer le PAT dans la CLI GitKraken

```bash
gk provider add github -t ghp_VOTRE_JETON
gk provider list
gk whoami
```

Le jeton est ecrit dans le magasin chiffre local de `gk`
(`%LOCALAPPDATA%\GitKrakenCLI\store`). **Ne committez jamais ce jeton.**

### Enregistrer le PAT dans l'interface GitKraken

**File > Preferences > Authentication** (ou l'icone de profil en haut a
gauche) > **+** > **GitHub** > coller le PAT > **Add**.

GitKraken verifie le jeton aupres de l'API GitHub et affiche le compte
associe.

## 3. Operations courantes

| Action | Dans GitKraken | En ligne de commande |
|---|---|---|
| Voir l'historique | **Graph** (onglet de gauche) | `gk graph` |
| Preparer un commit | onglet **Uncommitted changes** | `git add -A && git commit` |
| Pousser (`Push`) | bouton **Push** en haut a droite | `git push origin master` |
| Tirer (`Pull`) | bouton **Pull** | `git pull --rebase` |
| Creer une branche | ** branches > New Branch** | `git switch -c <nom>` |
| Fusionner | **branches > Merge** | `git merge <branche>` |
| Voir un commit precis | clic sur le noeud du Graph | `git show <sha>` |

### Premier push

Si le depot GitHub n'existe pas encore, creez-le depuis GitKraken :

**File > Clone > Create > GitHub** (ou **+ > Create GitHub repo**), puis :

- Repository name : `pve9-hardening-lab`
- Visibility : `Public` (les rapports PDF sont destines a la publication)
- **Create**

GitKraken configure alors automatiquement le remote `origin`. Verifiez avec :

```bash
git remote -v
```

Si le remote n'est pas configure :

```bash
git remote add origin https://github.com/<votre-compte>/pve9-hardening-lab.git
git push -u origin master --tags
```

## 4. Publication des rapports PDF

Les rapports sont **versionnes** dans `reports/` (ce sont eux la livraison
principale du projet). Ils sont regeneres par les cycles de test :

```bash
python3 scripts/pve.py run --phase all --target core --level 2 \
    --audit-extra anssi,ceph,cis13,communautaire --run-func
```

Puis :

```bash
git add reports/
git commit -m "docs: rapports PDF du cycle CIS L2 + ANSSI N3 + Ceph"
git push origin master
```

Les rapports PDF regeneres sont volumineux (~800 Ko chacun). Pour ne pas
alourdir l'historique, **preferez amend** plutot qu'un nouveau commit quand il
s'agit uniquement de regenerer un rapport :

```bash
git add reports/rapport-stack-complet.pdf
git commit --amend --no-edit
git push --force-with-lease origin master
```

> `--force-with-lease` est preferable a `--force` : il refuse d'ecraser des
> commits que vous n'avez pas encore recuperes.

## 5. Branche de travail pour une nouvelle serie de tests

```bash
git switch -c feature/nouvelle-campagne
# ... travaux ...
git add -A
git commit -m "feat: nouvelle campagne de tests"
git push -u origin feature/nouvelle-campagne
```

Puis ouvrez une **Pull Request** depuis GitKraken (onglet **Pull Requests**).

## 6. Resolution de conflits avec GitKraken

GitKraken propose un **merge editor** graphique. Les conflits apparaissent
dans l'onglet **Uncommitted changes** avec les marqueurs `<<<<<<<`,
`=======`, `>>>>>>>`.

Workflow :

1. Bouton **Solve conflicts** (icone de bouclier)
2. Resoudre fichier par fichier dans l'editeur (bouton **Accept Current** /
   **Accept Incoming** / **Accept Both**)
3. **Stage Changes** puis **Commit**

Si un conflit est bloque, abandonnez proprement :

```bash
git merge --abort
```

## 7. Securite du depot

Le depot ne contient **aucun secret** :

| Element | Traitement |
|---|---|
| `.keys/` (cle privee du lab) | ignore par `.gitignore` |
| `.local/`, `vendor/`, `artifacts/` | ignores par `.gitignore` |
| `reports/*.html` | ignores (seuls les PDF et MD sont versionnes) |
| mots de passe root des VM | uniquement dans `docs/` (valeurs de lab) |

La commande `pve.py publish` verifie qu'aucun fichier suspect
n'est suivi avant de pousser :

```bash
python3 scripts/pve.py publish --repo pve9-hardening-lab --token ghp_... --owner <votre-compte>
```

## 8. Depannage

| Symptome | Cause | Correctif |
|---|---|---|
| `fatal: Authentication failed for 'https://github.com/...'` | PAT absent, expire ou mauvais perimetre | regenere le PAT (`repo`) et `gk provider add github -t ...` |
| `remote: Permission to ... denied` | le PAT n'a pas le perimetre `repo` | regenere le PAT |
| `Updates were rejected` | commits distants en avance | `git pull --rebase` puis `git push` |
| `! [rejected] ... (non-fast-forward)` | divergence d'historique | `git pull --rebase origin master` puis `git push` |
| GitKraken affiche `unknown error` sur le push | proxy/VPN de l'entreprise | verifier `git config --get http.proxy` ; tester `git ls-remote origin` |
| `error: unable to access 'https://github.com/...': Could not resolve host` | DNS du poste | `ipconfig /flushdns` puis re-tester |

Test rapide de l'authentification :

```bash
git ls-remote origin
```

Si la commande renvoie les references du depot, l'authentification est
operationnelle.
