#!/usr/bin/env bash
set -eu
ROOT=$PWD
E=/Users/dion/.no-mistakes/evidence/01M6GWFG610E192Q958AF5EZMK
export FM_HERDR_LAB_STATE_DIR="$ROOT/.test-lab-state"
H="$ROOT/bin/fm-herdr-lab.sh"
S=$($H name popup-proof)
LAB="$ROOT/.popup-lab-home"
bin/fm-lab-home.sh create "$LAB"
ORIGINAL_PATH=$PATH
cleanup() { rc=$?; trap - EXIT; PATH="$ORIGINAL_PATH" "$H" teardown "$S"; rm -rf "$LAB" "$ROOT/.popup-fakebin"; exit "$rc"; }
trap cleanup EXIT
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_SESSION
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE
export FM_HOME="$LAB"
"$H" provision "$S"
lab() { "$H" run "$S" "$@"; }
lab viewer --help >/dev/null 2>&1 || true
W=$(lab workspace create --cwd "$ROOT" --label popup-proof --no-focus)
P=$(printf '%s' "$W" | jq -er '.result.root_pane.pane_id')
"$H" viewer start "$S"
lab pane run "$P" "env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS FM_HOME='$LAB' CLAUDE_CODE_NO_FLICKER=0 CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false '$ROOT/.claude303/node_modules/.bin/claude' --dangerously-skip-permissions" >/dev/null
ready=0
for ((i=0;i<60;i++)); do
 screen=$(lab pane read "$P" --source visible)
 case "$screen" in
 *'bypass permissions on'*) ready=1; break;;
 *'Yes, I trust this folder'*) lab pane send-keys "$P" down enter >/dev/null;;
 esac
 sleep 1
done
printf '%s\n' "$screen" > "$E/live-startup.txt"
[ "$ready" = 1 ] || { echo 'Claude did not reach idle composer'; exit 2; }
# A genuine draft must stay content and must never be mistaken for popup furniture.
lab pane send-text "$P" '/exit now' >/dev/null
sleep 1
lab pane read "$P" --source visible --format ansi > "$E/live-draft.ansi"
. "$ROOT/bin/fm-composer-lib.sh"
draft=$(FM_COMPOSER_GHOST_LUMA_MAX=0 fm_composer_extract_selected_content $'styled=1\ncursor=0\nidentity=1\nrows=40' "$(<"$E/live-draft.ansi")")
printf 'Real slash draft selected: <%s>\n' "$draft"
[ "$draft" = '/exit now' ]
lab pane send-keys "$P" ctrl+u escape >/dev/null
lab pane send-text "$P" '/exit' >/dev/null
sleep 2
lab pane read "$P" --source visible > "$E/live-popup.txt"
lab pane read "$P" --source visible --format ansi > "$E/live-popup.ansi"
. "$ROOT/bin/fm-composer-lib.sh"
cap=$(<"$E/live-popup.ansi")
content=$(FM_COMPOSER_GHOST_LUMA_MAX=0 fm_composer_extract_selected_content $'styled=1\ncursor=0\nidentity=1\nrows=40' "$cap")
printf 'Popup selected composer: <%s>\n' "$content"
[ "$content" = /exit ]
# Clear the manually typed probe, then exercise the real submit adapter.
lab pane send-keys "$P" ctrl+u escape >/dev/null
sleep 1
ORIGINAL_PATH=$PATH
mkdir -p "$ROOT/.popup-fakebin"
printf '#!/usr/bin/env bash\nargs=("$@")\nn=${#args[@]}\n[ "${args[n-2]}" = --session ] && [ "${args[n-1]}" = "%s" ] || exit 97\nunset "args[n-1]" "args[n-2]"\nexec env PATH="%s" "%s" run "%s" "${args[@]}"\n' "$S" "$ORIGINAL_PATH" "$H" "$S" > "$ROOT/.popup-fakebin/herdr"
chmod +x "$ROOT/.popup-fakebin/herdr"
export PATH="$ROOT/.popup-fakebin:$PATH"
. "$ROOT/bin/backends/herdr.sh"
v=$(fm_backend_herdr_send_text_submit "$S:$P" /exit 3 0.4 1.2)
printf 'Real /exit submit verdict: %s\n' "$v"
[ "$v" != send-failed ]
for ((i=0;i<30;i++)); do
 if ! lab agent get "$P" >/dev/null 2>&1; then echo 'Claude exited; native agent absent'; break; fi
 sleep 1
done
[ "$i" -lt 30 ]
lab pane read "$P" --source visible > "$E/live-after-exit.txt"
