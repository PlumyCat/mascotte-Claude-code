# Hooks Claude Code -> Mascotte

`mascotte-hook.sh` traduit les hooks Claude Code en fichiers d'état lus par
l'app (`SessionStore`). Un fichier par session dans
`~/.local/state/claude-mascotte/sessions/<session_id>.json` :

```json
{"state":"running","ts":1783432473,"cwd":"/path/du/projet"}
```

## Mapping événement -> état

| Hook Claude Code    | État écrit | Effet                    |
|----------------------|------------|--------------------------|
| `UserPromptSubmit`   | `running`  | -                        |
| `Notification`       | `waiting`  | -                        |
| `Stop`               | `review`   | -                        |
| `SessionStart`       | `idle`     | -                        |
| `SessionEnd`         | -          | supprime le fichier      |
| tout autre événement | -          | ignoré                   |

Le script ne produit jamais de sortie stdout et sort toujours en code 0 :
un hook qui échoue ou bloque ne doit jamais gêner Claude Code.

## Installation (manuelle, hors périmètre de cette story)

1. Ouvrir `~/.claude/settings.json`.
2. Fusionner le contenu de `claude-settings-snippet.json` dans la clé
   `"hooks"` existante (ou créer la clé si absente).
3. Remplacer `<CHEMIN_ABSOLU_VERS_LE_REPO>` par le chemin absolu réel du
   clone de ce repo sur la machine (ex. `/Users/<user>/projects/Mascotte`).
4. Vérifier que le script est exécutable : `chmod +x hooks/mascotte-hook.sh`.
5. Redémarrer les sessions Claude Code pour que les hooks soient pris en
   compte.

## Test manuel du script seul

```bash
echo '{"session_id":"test-1","hook_event_name":"UserPromptSubmit","cwd":"/tmp"}' \
  | ./hooks/mascotte-hook.sh
cat ~/.local/state/claude-mascotte/sessions/test-1.json
```

`MASCOTTE_STATE_DIR` peut être défini dans l'environnement pour rediriger
le dossier de sessions vers un chemin de test.
