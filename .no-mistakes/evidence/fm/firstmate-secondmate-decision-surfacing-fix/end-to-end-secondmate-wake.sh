#!/usr/bin/env bash
set -euo pipefail
ROOT=/Users/dion/.no-mistakes/worktrees/774143b5fc8e/01M1X2G06A39W7EAT9F3TJFHJW
EVIDENCE=/Users/dion/.no-mistakes/evidence/01M1X2G06A39W7EAT9F3TJFHJW
CASE="$EVIDENCE/runtime-secondmate-wake"
rm -rf "$CASE"
mkdir -p "$CASE/fakebin"
cat > "$CASE/fakebin/tmux" <<'SH'
#!/usr/bin/env bash
# No ordinary crew windows are needed for this outcome-delivery scenario.
case "${1:-}" in list-windows|list-panes) exit 0 ;; esac
exit 1
SH
chmod +x "$CASE/fakebin/tmux"

wait_for_text() {
  local file=$1 text=$2 i
  for ((i=0; i<150; i++)); do
    grep -F "$text" "$file" >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}
wait_for_exit() {
  local pid=$1 i
  for ((i=0; i<150; i++)); do
    kill -0 "$pid" 2>/dev/null || { wait "$pid"; return $?; }
    sleep 0.1
  done
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  return 124
}
run_arm() {
  local home=$1 state=$2 output=$3
  PATH="$CASE/fakebin:$PATH" FM_HOME="$home" FM_STATE_OVERRIDE="$state" \
    FM_POLL=1 FM_SIGNAL_GRACE=0 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 \
    "$ROOT/bin/fm-watch-arm.sh" >"$output" 2>&1 &
  ARM_PID=$!
  wait_for_text "$output" 'watcher: started'
}
show_case() {
  local label=$1 state=$2 armout=$3 drainout=$4
  printf '\n=== %s ===\n' "$label"
  printf '%s\n' '[Claude Stop-hook arm output]'
  cat "$armout"
  printf '%s\n' '[durable wake queue]'
  cat "$state/.wake-queue"
  printf '%s\n' '[firstmate/captain drain output]'
  cat "$drainout"
}

# Local second mate: publish the outcome in its parent-owned status channel.
LOCAL_HOME="$CASE/local/home"; LOCAL_STATE="$LOCAL_HOME/state"
mkdir -p "$LOCAL_STATE" "$LOCAL_HOME/data"
printf 'kind=secondmate\nharness=claude\nhome=%s\n' "$LOCAL_HOME" > "$LOCAL_STATE/local-mate.meta"
run_arm "$LOCAL_HOME" "$LOCAL_STATE" "$CASE/local-arm.out"
printf 'needs-decision [key=release-target]: choose staging or production\n' > "$LOCAL_STATE/local-mate.status"
wait_for_exit "$ARM_PID"
FM_HOME="$LOCAL_HOME" FM_STATE_OVERRIDE="$LOCAL_STATE" \
  "$ROOT/bin/fm-wake-drain.sh" > "$CASE/local-drain.out" 2> "$CASE/local-drain.err"
grep -F 'local-mate [key=release-target] needs-decision: choose staging or production' "$CASE/local-drain.out" >/dev/null

# Remote second mate: ingest the real signed/delta protocol boundary into the
# parent's ios.status, while another plain arm invocation owns supervision.
REMOTE_HOME="$CASE/remote/home"; REMOTE_STATE="$REMOTE_HOME/state"
mkdir -p "$REMOTE_STATE" "$REMOTE_HOME/data"
printf 'kind=secondmate\nharness=claude\nhome=/remote/ios\nremote_host=remote-mac\n' > "$REMOTE_STATE/ios.meta"
PAYLOAD="$CASE/remote.payload"; EMPTY="$CASE/empty"; RESULT="$CASE/remote.result"
printf 'needs-decision [key=ios-signoff]: approve the iOS release candidate\n' > "$PAYLOAD"
: > "$EMPTY"
bytes=$(LC_ALL=C wc -c < "$PAYLOAD" | tr -d '[:space:]')
if command -v shasum >/dev/null 2>&1; then
  payload_hash=$(shasum -a 256 "$PAYLOAD" | awk '{print $1}')
  empty_hash=$(shasum -a 256 "$EMPTY" | awk '{print $1}')
else
  payload_hash=$(sha256sum "$PAYLOAD" | awk '{print $1}')
  empty_hash=$(sha256sum "$EMPTY" | awk '{print $1}')
fi
{
  printf 'schema=fm-remote-delta.v1\nstatus=delta\npath=state/parent-replies.status\n'
  printf 'from_offset=0\nto_offset=%s\n' "$bytes"
  printf 'from_prefix_sha256=%s\nto_prefix_sha256=%s\n' "$empty_hash" "$payload_hash"
  printf 'payload_sha256=%s\npayload_bytes=%s\nreason=e2e-evidence\n\n' "$payload_hash" "$bytes"
  cat "$PAYLOAD"
} > "$RESULT"
run_arm "$REMOTE_HOME" "$REMOTE_STATE" "$CASE/remote-arm.out"
FM_HOME="$REMOTE_HOME" FM_STATE_OVERRIDE="$REMOTE_STATE" FM_DATA_OVERRIDE="$REMOTE_HOME/data" \
  "$ROOT/bin/fm-procevent-remote-reply.sh" ingest ios "$RESULT" >/dev/null
wait_for_exit "$ARM_PID"
FM_HOME="$REMOTE_HOME" FM_STATE_OVERRIDE="$REMOTE_STATE" \
  "$ROOT/bin/fm-wake-drain.sh" > "$CASE/remote-drain.out" 2> "$CASE/remote-drain.err"
grep -F 'ios [key=ios-signoff] needs-decision: approve the iOS release candidate' "$CASE/remote-drain.out" >/dev/null

show_case 'LOCAL SECOND MATE' "$LOCAL_STATE" "$CASE/local-arm.out" "$CASE/local-drain.out"
show_case 'REMOTE SECOND MATE (real remote-delta ingest)' "$REMOTE_STATE" "$CASE/remote-arm.out" "$CASE/remote-drain.out"
printf '\nRESULT: both unsolicited decisions woke the plain Claude Stop-hook arm and appeared in the captain-facing drain without a status poll.\n'
