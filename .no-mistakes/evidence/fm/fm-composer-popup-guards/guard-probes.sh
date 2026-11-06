#!/usr/bin/env bash
set -eu
lib=$1
. "$lib"
caps=$'styled=1\ncursor=0\nidentity=0\nrows=0'
rule='────────────────────────'
for h in claude '' codex kiro; do
  for row in '/exit!  real draft' '/exit    Exit the CLI'; do
    screen="$rule"$'\n❯ /exit\n'"$rule"$'\n❯ '"$row"
    actual=$(FM_COMPOSER_HARNESS="$h" fm_composer_extract_selected_content "$caps" "$screen")
    printf 'caller=%s lower=%s selected=%s\n' "${h:-unknown}" "$row" "$actual"
  done
done
