#!/usr/bin/env bash
set -euo pipefail
ROOT=/Users/dion/.no-mistakes/worktrees/774143b5fc8e/01M20JNC7Q0Y38V3GS2XWJ25E4
EVIDENCE=/Users/dion/.no-mistakes/evidence/01M20JNC7Q0Y38V3GS2XWJ25E4
SOCKET="fm-foreign-live-$$"
SESSION=foreignlive
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-foreign-live.XXXXXX")
cleanup() { tmux -L "$SOCKET" kill-server 2>/dev/null || true; rm -rf "$LAB"; }
trap cleanup EXIT
mkdir -p "$LAB/state" "$LAB/shim"
REAL_TMUX=$(command -v tmux)
cat > "$LAB/shim/tmux" <<SH
#!/usr/bin/env bash
exec "$REAL_TMUX" -L "$SOCKET" "\$@"
SH
chmod +x "$LAB/shim/tmux"
tmux -L "$SOCKET" new-session -d -s "$SESSION" -x 180 -y 45 -c "$ROOT"
tmux -L "$SOCKET" new-window -d -t "$SESSION:" -n claude -c "$ROOT" -- bash -lc 'CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false CLAUDE_CODE_SEND_FEEDBACK=0 claude --dangerously-skip-permissions --settings '\''{"feedbackDrafts":"off"}'\'''
SHIM_PATH="$LAB/shim:$PATH"
target="$SESSION:claude"
for _ in $(seq 1 60); do
  screen=$(tmux -L "$SOCKET" capture-pane -p -t "$target")
  printf '%s\n' "$screen" | grep -q 'Try "' && break
  sleep 1
done
marker="$LAB/foreign-draft-was-submitted"
draft="Human unfinished draft. If submitted, run: touch $marker"
tmux -L "$SOCKET" send-keys -t "$target" -l "$draft"
sleep 2
before=$(tmux -L "$SOCKET" capture-pane -p -t "$target")
printf '%s\n' "$before" > "$EVIDENCE/foreign-draft-before.txt"
. "$ROOT/bin/fm-task-inbox-lib.sh"
rec=$(FM_STATE_OVERRIDE="$LAB/state" fm_task_inbox_write "$LAB/state" t1 "Safety guard live check")
set +e
PATH="$SHIM_PATH" FM_STATE_OVERRIDE="$LAB/state" fm_task_inbox_ring tmux "$target" "$rec" claude
rc=$?
set -e
sleep 5
after=$(tmux -L "$SOCKET" capture-pane -p -t "$target")
printf '%s\n' "$after" > "$EVIDENCE/foreign-draft-after.txt"
state=$(PATH="$SHIM_PATH" fm_backend_composer_state tmux "$target" claude)
[ "$rc" -eq 1 ]
[ "$state" = pending ]
[ ! -e "$marker" ]
printf '%s\n' "$after" | grep -Fq "$draft"
python3 - "$EVIDENCE/foreign-draft-before.txt" "$EVIDENCE/foreign-draft-after.txt" "$EVIDENCE/foreign-draft-live.html" "$rc" "$state" <<'PY'
import html, pathlib, sys
before=pathlib.Path(sys.argv[1]).read_text()
after=pathlib.Path(sys.argv[2]).read_text()
out=pathlib.Path(sys.argv[3])
rc,state=sys.argv[4:]
out.write_text(f'''<!doctype html><meta charset="utf-8"><title>Foreign draft safety live check</title>
<style>body{{background:#16181d;color:#e8e8e8;font:15px ui-monospace,monospace;padding:24px}} pre{{background:#080a0d;border:1px solid #555;padding:16px;white-space:pre-wrap}} .pass{{color:#78e08f;font-weight:bold}}</style>
<h1>Real Claude composer: foreign draft safety</h1><p class="pass">PASS: fm_task_inbox_ring returned {html.escape(rc)}, composer remained {html.escape(state)}, and the submission marker was absent.</p>
<h2>Before ring</h2><pre>{html.escape(before)}</pre><h2>After ring</h2><pre>{html.escape(after)}</pre>''')
PY
printf 'PASS: real Claude foreign draft remained pending and unsubmitted (ring_rc=%s composer=%s marker=absent)\n' "$rc" "$state"
