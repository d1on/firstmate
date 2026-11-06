#!/usr/bin/env bash
set -eu
E=/Users/dion/.no-mistakes/evidence/01M6QSN9FAK9FEV37TK4WBEWHR
LAB="$PWD/.l"
bash bin/fm-lab-home.sh create "$LAB"
mkdir -p "$LAB/tmux"
touch "$LAB/config/supervision-host"
t() { TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab "$@"; }
trap 't kill-server 2>/dev/null || true; rm -rf "$LAB"' EXIT
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1 TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab new-session -d -s primary -x 120 -y 40 -c "$PWD" -e FM_HOME="$LAB" "$PWD/.live-tools/node_modules/.bin/claude"
sleep 10
t send-keys -t primary -l /exit
sleep 2
screen=$(t capture-pane -e -p -t primary)
printf '%s\n' "$screen" > "$E/live-classic-popup.ansi"
t capture-pane -p -t primary > "$E/live-classic-popup.txt"
. bin/fm-composer-lib.sh
caps=$'styled=1\ncursor=0\nidentity=0\nrows=0'
actual=$(FM_COMPOSER_HARNESS=claude fm_composer_extract_selected_content "$caps" "$screen")
printf 'Claude 2.1.303 classic popup: selected=%s\n' "$actual"
[ "$actual" = /exit ]
for h in '' codex kiro; do
  actual=$(FM_COMPOSER_HARNESS="$h" fm_composer_extract_selected_content "$caps" "$screen")
  case "$actual" in '/exit Exit the CLI'*) ;; *) printf 'unexpected caller=%s content=%s\n' "${h:-unknown}" "$actual"; exit 1;; esac
  printf 'caller=%s: lower selected popup row retained (not demoted to /exit); selected=%s\n' "${h:-unknown}" "$actual"
done
t send-keys -t primary Escape
sleep 0.5
t send-keys -t primary C-a C-k
sleep 0.5
t send-keys -t primary -l '/exit!  real draft'
sleep 2
screen=$(t capture-pane -e -p -t primary)
printf '%s\n' "$screen" > "$E/live-invalid-draft.ansi"
t capture-pane -p -t primary > "$E/live-invalid-draft.txt"
actual=$(FM_COMPOSER_HARNESS=claude fm_composer_extract_selected_content "$caps" "$screen")
printf 'Claude 2.1.303 typed invalid token: selected=%s\n' "$actual"
[ "$actual" = '/exit! real draft' ]
printf 'Note: invalid draft is inside its own rule pair in the real vendor UI; the older-composer/lower-bare-draft adversarial geometry is covered separately by guard-probes.sh and the targeted suite, not this live check.\n'
