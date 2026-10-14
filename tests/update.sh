#!/usr/bin/env bash
# lowpaper update: an older copy is replaced by the latest release, which must still be a working script.
# Needs network access to github.com.
set -u
T=$(mktemp -d)
export XDG_RUNTIME_DIR=$T/run XDG_CONFIG_HOME=$T/cfg
mkdir -m 700 "$XDG_RUNTIME_DIR" "$T/bin"
fail=0
check() { local d=$1; shift; if "$@"; then echo "ok   $d"; else echo "FAIL $d"; fail=1; fi; }

sed 's/^VERSION=.*/VERSION=0.0.1/' "${0%/*}/../lowpaper" > "$T/bin/lowpaper"; chmod +x "$T/bin/lowpaper"
out=$("$T/bin/lowpaper" update); echo "$out"
check "update reports what it did" grep -qE '^(updated lowpaper 0.0.1 -> |lowpaper 0.0.1 is up to date)' <<< "$out"
check "the file is still a valid script" bash -n "$T/bin/lowpaper"
check "the file is executable" test -x "$T/bin/lowpaper"
check "no temporary file is left" test -z "$(find "$T/bin" -name '.lowpaper.*')"
cp "$T/bin/lowpaper" "$T/bin/again"
out=$("$T/bin/again" update); echo "$out"
check "a current copy is left alone" grep -q 'is up to date' <<< "$out"
exit $fail
