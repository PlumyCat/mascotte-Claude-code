#!/usr/bin/env bash
# Installs Mascotte.app and wires its Claude Code hooks into settings.json.
#
# Overridable targets (for testing, point these at a scratch directory):
#   APP_DIR          default: ~/Applications
#   CLAUDE_SETTINGS   default: ~/.claude/settings.json
#   HOOK_DIR          default: ~/.local/share/claude-mascotte
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP_DIR="${APP_DIR:-$HOME/Applications}"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
HOOK_DIR="${HOOK_DIR:-$HOME/.local/share/claude-mascotte}"

SRC_APP="$REPO_ROOT/dist/Mascotte.app"
DEST_APP="$APP_DIR/Mascotte.app"
HOOK_SCRIPT="$HOOK_DIR/mascotte-hook.sh"

if [ ! -d "$SRC_APP" ]; then
    echo "error: $SRC_APP introuvable. Lance d'abord scripts/build-app.sh." >&2
    exit 1
fi

echo "==> installe l'app dans $APP_DIR"
mkdir -p "$APP_DIR"
rm -rf "$DEST_APP"
cp -R "$SRC_APP" "$DEST_APP"

echo "==> installe le hook dans $HOOK_DIR"
mkdir -p "$HOOK_DIR"
cp "$REPO_ROOT/hooks/mascotte-hook.sh" "$HOOK_SCRIPT"
chmod +x "$HOOK_SCRIPT"

echo "==> met à jour $CLAUDE_SETTINGS"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"

CLAUDE_SETTINGS="$CLAUDE_SETTINGS" HOOK_SCRIPT="$HOOK_SCRIPT" python3 - <<'PYEOF'
import json
import os
import shutil
import sys
import time

settings_path = os.environ["CLAUDE_SETTINGS"]
hook_script = os.environ["HOOK_SCRIPT"]
events = ["UserPromptSubmit", "Notification", "Stop", "SessionStart", "SessionEnd"]

file_exists = os.path.exists(settings_path)

try:
    with open(settings_path, "r", encoding="utf-8") as f:
        settings = json.load(f)
except FileNotFoundError:
    settings = {}
except json.JSONDecodeError as e:
    print(f"error: {settings_path} contient un JSON invalide ({e}).", file=sys.stderr)
    print("installation interrompue, rien n'a été modifié.", file=sys.stderr)
    sys.exit(1)

if not isinstance(settings, dict):
    raise SystemExit(f"error: {settings_path} ne contient pas un objet JSON")

if file_exists:
    backup = f"{settings_path}.bak.{time.strftime('%Y%m%d%H%M%S')}.{os.getpid()}"
    shutil.copy2(settings_path, backup)
    print(f"    backup: {backup}")

hooks = settings.setdefault("hooks", {})

for event in events:
    blocks = hooks.setdefault(event, [])

    already_present = any(
        isinstance(block, dict)
        and any(
            isinstance(h, dict) and h.get("command") == hook_script
            for h in block.get("hooks", [])
        )
        for block in blocks
    )

    if not already_present:
        blocks.append({
            "matcher": "*",
            "hooks": [{"type": "command", "command": hook_script}],
        })

tmp_path = settings_path + ".tmp"
with open(tmp_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp_path, settings_path)
PYEOF

echo "==> installation terminée"
echo "    app:    $DEST_APP"
echo "    hook:   $HOOK_SCRIPT"
echo "    settings: $CLAUDE_SETTINGS"
