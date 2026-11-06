#!/usr/bin/env bash
set -euo pipefail
E=/Users/dion/.no-mistakes/evidence/01M6QSN9FAK9FEV37TK4WBEWHR
LAB="$PWD/.l"
bin/fm-lab-home.sh create "$LAB"
mkdir -p "$LAB/tmux"
touch "$LAB/config/supervision-host"
t() { TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab "$@"; }
trap 't kill-server 2>/dev/null || true; rm -rf "$LAB"' EXIT
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1 TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab new-session -d -x 120 -y 40 -s primary -c "$PWD" -e FM_HOME="$LAB" "$PWD/.live-tools/node_modules/.bin/claude"
sleep 18
t send-keys -t primary -l /exit
sleep 3
t capture-pane -p -t primary > "$E/isolation-classic-popup.txt"
t capture-pane -e -p -t primary > "$E/isolation-classic-popup.ansi"
screen=$(<"$E/isolation-classic-popup.ansi")
plain=$(<"$E/isolation-classic-popup.txt")
git show 8b1618a49511d67b247f5f8091868b812bfcae2d:bin/fm-composer-lib.sh > "$LAB/base.sh"
. bin/fm-composer-lib.sh
for locale in en_US.UTF-8 C; do
  for profile in styled styled-noidentity plain; do
    case "$profile" in
      styled) caps=$'styled=1\ncursor=0\nidentity=1\nrows=40'; frame="$screen" ;;
      styled-noidentity) caps=$'styled=1\ncursor=0\nidentity=0\nrows=40'; frame="$screen" ;;
      plain) caps=$'styled=0\ncursor=0\nidentity=0\nrows=40'; frame="$plain" ;;
    esac
    for harness in '' codex kiro claude; do
      out=$(LC_ALL="$locale" FM_COMPOSER_HARNESS="$harness" fm_composer_extract_selected_content "$caps" "$frame")
      printf 'locale=%s profile=%s caller=%s selected-content=<%s>\n' "$locale" "$profile" "${harness:-unknown}" "$out"
      if [ "$harness" = claude ]; then
        [ "$out" = /exit ]
      else
        case "$out" in '/exit Exit the CLI'*) ;; *) echo 'FAIL: popup row not retained'; exit 1 ;; esac
      fi
      before=$( . "$LAB/base.sh"; LC_ALL="$locale" FM_COMPOSER_HARNESS="$harness" fm_composer_extract_selected_content "$caps" "$frame")
      printf 'base selected-content=<%s>\n' "$before"
      [ "$before" = /exit ]
    done
  done
done
printf 'Live classic-popup assertions passed; baseline incorrectly demotes non-Claude callers.\n'
python3 - "$E" <<'PY'
import sys,html,pathlib
p=pathlib.Path(sys.argv[1]); t=(p/'isolation-classic-popup.txt').read_text()
(p/'isolation-classic-popup.html').write_text('<!doctype html><meta charset="utf-8"><title>Live Claude 2.1.303 classic popup capture</title><style>body{background:#171717;color:#eee}pre{font:16px/1.25 monospace;white-space:pre}</style><pre>'+html.escape(t)+'</pre>')
PY
# Submit the actual command from the live composer, not a synthetic screen.
t send-keys -t primary Enter
sleep 4
if t has-session -t primary 2>/dev/null; then
  t capture-pane -p -t primary > "$E/isolation-after-enter.txt"
else
  printf 'Real Claude /exit submitted with Enter: primary session terminated.\n' > "$E/isolation-after-enter.txt"
fi
