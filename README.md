# Mascotte

Mascotte — Casquette, un chat compact et geek portant une casquette et un
Mac en bandoulière — est une petite application macOS qui vit dans la barre
de menus et sur votre bureau (fenêtre flottante multi-Spaces). Elle reflète
en temps réel l'état de vos sessions Claude Code via des hooks : elle
tourne quand vous travaillez, s'agite quand Claude attend une réponse, se
pose en revue quand une session s'arrête, et se repose sinon.

## Prérequis

- macOS 13 (Ventura) ou plus récent.
- Xcode Command Line Tools (`swift build`, `codesign`) — `xcode-select --install`.
- `python3` (préinstallé sur macOS) pour la fusion des hooks dans
  `~/.claude/settings.json`.
- `jq` optionnel côté hooks (le script utilise `jq` si présent, sinon
  bascule automatiquement sur `python3`).

## Build

```bash
scripts/build-app.sh
```

Compile en release (`swift build -c release`) et assemble un bundle
autonome `dist/Mascotte.app` (binaire + `Info.plist` + `Resources/` avec le
spritesheet et les métadonnées du pet), signé en ad-hoc
(`codesign -s - --force --deep`).

Pour développer sans repackager à chaque changement :

```bash
swift run MascotteApp
```

(charge le spritesheet directement depuis `pets/casquette/` du dépôt).

## Installation

```bash
scripts/install.sh
```

Par défaut, installe :

| Élément                     | Destination par défaut              | Variable de surcharge |
|------------------------------|--------------------------------------|------------------------|
| `Mascotte.app`               | `~/Applications`                     | `APP_DIR`               |
| `mascotte-hook.sh`           | `~/.local/share/claude-mascotte`     | `HOOK_DIR`               |
| Entrées hooks Claude Code    | `~/.claude/settings.json`            | `CLAUDE_SETTINGS`       |

`install.sh` **fusionne** son bloc de hooks dans `CLAUDE_SETTINGS` sans
jamais écraser les hooks déjà présents : il ajoute une entrée par
événement uniquement si elle n'existe pas déjà (comparaison sur la commande
exacte), et sauvegarde toujours le fichier existant en
`settings.json.bak.<horodatage>` avant modification. Relancer `install.sh`
est donc sans danger (idempotent, pas de doublons).

Ouvre ensuite `Mascotte.app`, ou active « Lancer au login » depuis le menu
de la mascotte (barre de menus) pour un démarrage automatique.

## Mapping hooks Claude Code -> état de la mascotte

Chaque hook Claude Code écrit un fichier d'état par session
(`~/.local/state/claude-mascotte/sessions/<session_id>.json`), lu et
agrégé par l'app :

| Hook Claude Code    | État écrit |
|----------------------|------------|
| `UserPromptSubmit`   | `running`  |
| `Notification`       | `waiting`  |
| `Stop`               | `review`   |
| `SessionStart`       | `idle`     |
| `SessionEnd`         | supprime le fichier de la session |

Quand plusieurs sessions sont actives, la mascotte affiche l'état le plus
prioritaire selon l'ordre : **waiting > running > review > idle**.

## Personnalisation

Pour utiliser un autre spritesheet :

1. Remplacer `pets/casquette/spritesheet.webp` par votre image, au format
   grille **8 colonnes x 9 lignes** de cellules **192x208 px** (soit une
   image de 1536x1872 px), une ligne par état (`idle`, `running-right`,
   `running-left`, `waving`, `jumping`, `failed`, `waiting`, `running`,
   `review`, dans cet ordre — voir `Sources/MascotteApp/PetState.swift`).
2. Mettre à jour `pets/casquette/pet.json` (id, nom, description) si besoin.
3. Relancer `scripts/build-app.sh`.

## Désinstallation

```bash
scripts/uninstall.sh
```

Retire l'app, le hook, le dossier d'état, et les entrées ajoutées par
`install.sh` dans `settings.json` (backup préalable, hooks d'autres outils
préservés). Utiliser les mêmes variables (`APP_DIR`, `HOOK_DIR`,
`CLAUDE_SETTINGS`) si l'installation avait été personnalisée. Si la
mascotte avait « Lancer au login » activé, le script vous invite à le
désactiver depuis le menu de la mascotte (ou Réglages Système > Général >
Éléments de connexion) : cette bascule dépend de `SMAppService` et ne peut
être défaite que depuis l'app elle-même, pas depuis un script shell.

## Dépannage

- **Le hook ne fait rien / pas de fichier d'état créé** : vérifier que
  `python3` est disponible dans le `PATH` (le script s'en sert quand `jq`
  est absent). Tester manuellement :
  ```bash
  echo '{"session_id":"test-1","hook_event_name":"UserPromptSubmit","cwd":"/tmp"}' \
    | ~/.local/share/claude-mascotte/mascotte-hook.sh
  cat ~/.local/state/claude-mascotte/sessions/test-1.json
  ```
- **La mascotte ne bouge jamais** : vérifier que les hooks sont bien
  fusionnés dans `~/.claude/settings.json` (clé `hooks`) et que le chemin
  vers `mascotte-hook.sh` qu'ils référencent existe et est exécutable.
- **`install.sh`/`uninstall.sh` échouent silencieusement sur les hooks** :
  ils dépendent de `python3` pour lire/écrire `settings.json` en JSON ;
  sans lui, la fusion est impossible.
