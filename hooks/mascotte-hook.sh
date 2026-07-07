#!/usr/bin/env bash
# Hook Claude Code -> état de session pour l'agrégation Mascotte.
# Ne doit jamais bloquer Claude Code : aucune sortie stdout, exit 0 toujours.

STATE_DIR="${MASCOTTE_STATE_DIR:-$HOME/.local/state/claude-mascotte/sessions}"

main() {
    local input
    input="$(cat)"

    local parsed session_id hook_event cwd
    if command -v jq >/dev/null 2>&1; then
        parsed="$(printf '%s' "$input" | jq -r '[(.session_id // ""), (.hook_event_name // ""), (.cwd // "")] | @tsv' 2>/dev/null)"
    else
        parsed="$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    if not isinstance(d, dict):
        d = {}
except Exception:
    d = {}
print("\t".join([str(d.get("session_id") or ""), str(d.get("hook_event_name") or ""), str(d.get("cwd") or "")]))
' 2>/dev/null)"
    fi

    IFS=$'\t' read -r session_id hook_event cwd <<<"$parsed"

    [ -z "$session_id" ] && return 0
    [ -z "$hook_event" ] && return 0

    case "$session_id" in
        ''|*/*|*\\*|*..*) return 0 ;;
    esac

    local file="$STATE_DIR/$session_id.json"

    local state
    case "$hook_event" in
        SessionEnd)
            rm -f "$file" 2>/dev/null
            return 0
            ;;
        UserPromptSubmit) state="running" ;;
        Notification) state="waiting" ;;
        Stop) state="review" ;;
        SessionStart) state="idle" ;;
        *) return 0 ;;
    esac

    mkdir -p "$STATE_DIR" 2>/dev/null || return 0

    local ts
    ts="$(date +%s)"

    local tmp
    tmp="$(mktemp "$STATE_DIR/.tmp.XXXXXX" 2>/dev/null)" || return 0

    # Échappement minimal (backslash puis guillemet) pour cwd dans le JSON écrit à la main.
    local cwd_escaped="${cwd//\\/\\\\}"
    cwd_escaped="${cwd_escaped//\"/\\\"}"

    printf '{"state":"%s","ts":%s,"cwd":"%s"}' "$state" "$ts" "$cwd_escaped" >"$tmp" 2>/dev/null
    mv -f "$tmp" "$file" 2>/dev/null

    return 0
}

main "$@" >/dev/null 2>&1

exit 0
