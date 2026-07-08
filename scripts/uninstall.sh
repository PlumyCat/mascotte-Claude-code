#!/usr/bin/env bash
# Reverses install.sh: removes the app, the hook, the hook entries added to
# settings.json, the session state directory, and warns about any pending
# "launch at login" registration.
#
# Overridable targets (must match what install.sh used):
#   APP_DIR          default: ~/Applications
#   CLAUDE_SETTINGS   default: ~/.claude/settings.json
#   HOOK_DIR          default: ~/.local/share/claude-mascotte
#   STATE_DIR         default: ~/.local/state/claude-mascotte
set -euo pipefail

APP_DIR="${APP_DIR:-$HOME/Applications}"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
HOOK_DIR="${HOOK_DIR:-$HOME/.local/share/claude-mascotte}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/claude-mascotte}"

DEST_APP="$APP_DIR/Mascotte.app"
HOOK_SCRIPT="$HOOK_DIR/mascotte-hook.sh"

check_login_item_registered() {
    # sfltool can hang waiting on system permissions in some contexts, so it's
    # run with a hard 3s watchdog instead of blocking uninstall indefinitely.
    local out
    out="$(mktemp)"
    sfltool dumpbtm >"$out" 2>/dev/null </dev/null &
    local sfl_pid=$!
    ( sleep 3; kill -9 "$sfl_pid" 2>/dev/null ) &
    local watchdog_pid=$!
    wait "$sfl_pid" 2>/dev/null || true
    kill "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
    local found=1
    grep -q "fr.ericfer.mascotte" "$out" 2>/dev/null && found=0
    rm -f "$out"
    return "$found"
}

if [ -d "$DEST_APP" ] && command -v sfltool >/dev/null 2>&1; then
    if check_login_item_registered; then
        echo "note: Mascotte semble enregistrée en \"Lancer au login\"."
        echo "      Désactive l'option depuis le menu de la mascotte (ou Réglages Système"
        echo "      > Général > Éléments de connexion) avant/après la désinstallation :"
        echo "      SMAppService ne peut pas être désenregistré depuis un script shell."
    fi
fi

echo "==> retire l'app ($DEST_APP)"
rm -rf "$DEST_APP"

echo "==> retire le hook ($HOOK_DIR)"
rm -rf "$HOOK_DIR"

echo "==> retire le dossier d'état ($STATE_DIR)"
rm -rf "$STATE_DIR"

if [ -f "$CLAUDE_SETTINGS" ]; then
    echo "==> nettoie $CLAUDE_SETTINGS"
    backup="$CLAUDE_SETTINGS.bak.$(date +%Y%m%d%H%M%S).$$"
    cp "$CLAUDE_SETTINGS" "$backup"
    echo "    backup: $backup"

    CLAUDE_SETTINGS="$CLAUDE_SETTINGS" HOOK_SCRIPT="$HOOK_SCRIPT" python3 - <<'PYEOF'
import json
import os
import sys

settings_path = os.environ["CLAUDE_SETTINGS"]
hook_script = os.environ["HOOK_SCRIPT"]

try:
    with open(settings_path, "r", encoding="utf-8") as f:
        settings = json.load(f)
except json.JSONDecodeError as e:
    print(f"error: {settings_path} contient un JSON invalide ({e}).", file=sys.stderr)
    print("désinstallation interrompue côté hooks, le fichier n'a pas été modifié.", file=sys.stderr)
    sys.exit(1)

hooks = settings.get("hooks")
if isinstance(hooks, dict):
    for event in list(hooks.keys()):
        blocks = hooks[event]
        if not isinstance(blocks, list):
            continue

        kept_blocks = []
        for block in blocks:
            if not isinstance(block, dict):
                kept_blocks.append(block)
                continue
            kept_hooks = [
                h for h in block.get("hooks", [])
                if not (isinstance(h, dict) and h.get("command") == hook_script)
            ]
            if kept_hooks:
                block["hooks"] = kept_hooks
                kept_blocks.append(block)
            # else: block only contained our hook -> drop the whole block

        if kept_blocks:
            hooks[event] = kept_blocks
        else:
            del hooks[event]

    if not hooks:
        del settings["hooks"]

tmp_path = settings_path + ".tmp"
with open(tmp_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp_path, settings_path)
PYEOF
else
    echo "==> $CLAUDE_SETTINGS introuvable, rien à nettoyer côté hooks"
fi

echo "==> désinstallation terminée"
