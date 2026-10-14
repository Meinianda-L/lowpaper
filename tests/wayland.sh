#!/usr/bin/env bash
# Smoke test on a headless Sway: build the helper, play, pause, a wrong -o, monitor hotplug, stop.
# Needs: sway, mpv, ffmpeg, gcc. Rendering is software (pixman + llvmpipe), so no GPU is needed.
set -u
L=$(readlink -f "${0%/*}/../lowpaper")
T=$(mktemp -d)
export XDG_RUNTIME_DIR=$T/run XDG_CONFIG_HOME=$T/cfg XDG_CACHE_HOME=$T/cache LIBGL_ALWAYS_SOFTWARE=1
mkdir -m 700 "$XDG_RUNTIME_DIR"
fail=0
check() { local d=$1; shift; if "$@"; then echo "ok   $d"; else echo "FAIL $d"; fail=1; fi; }
not() { ! "$@"; }
st() { "$L" status; }

ffmpeg -loglevel error -f lavfi -i testsrc=size=320x240:rate=10:duration=2 -pix_fmt yuv420p "$T/clip.mp4"
WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 sway -c /dev/null >"$T/sway.log" 2>&1 &
sway=$!
for _ in $(seq 50); do [ -S "$XDG_RUNTIME_DIR/wayland-1" ] && break; sleep 0.2; done
export WAYLAND_DISPLAY=wayland-1 SWAYSOCK
SWAYSOCK=$(ls "$XDG_RUNTIME_DIR"/sway-ipc.*.sock)

check "helper builds" "$L" _build
"$L" "$T/clip.mp4"; sleep 3; st
check "plays on HEADLESS-1" grep -q '^HEADLESS-1  playing' <<< "$(st)"
"$L" pause;  check "pause"  grep -q paused  <<< "$(st)"
"$L" resume; check "resume" grep -q playing <<< "$(st)"
check "wrong -o fails" not "$L" -o NOPE "$T/clip.mp4"
check "wrong -o keeps the wallpaper" grep -q '^HEADLESS-1  playing' <<< "$(st)"

swaymsg create_output >/dev/null; sleep 5; st
check "added monitor gets the wallpaper" grep -q '^HEADLESS-2  playing' <<< "$(st)"
swaymsg output HEADLESS-2 unplug >/dev/null; sleep 5; st
check "removed monitor is dropped" not grep -q HEADLESS-2 <<< "$(st)"
check "remaining monitor still plays" grep -q '^HEADLESS-1  playing' <<< "$(st)"

"$L" stop; sleep 1
check "stop ends the helper" not pgrep -x lowpaper-wl
kill "$sway"
[ $fail = 0 ] || { echo "--- sway log"; tail -20 "$T/sway.log"; }
exit $fail
