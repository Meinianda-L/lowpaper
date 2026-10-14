#!/usr/bin/env bash
# Smoke test on Xvfb: play, pause, a wrong -o, re-layout after a screen resize, stop.
# Needs: Xvfb, mpv, ffmpeg, python3, x11-utils (xprop, xev, xkill, xwininfo), xrandr.
set -u
L=$(readlink -f "${0%/*}/../lowpaper")
T=$(mktemp -d)
export XDG_RUNTIME_DIR=$T/run XDG_CONFIG_HOME=$T/cfg DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1
unset WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
mkdir -m 700 "$XDG_RUNTIME_DIR"
fail=0
check() { local d=$1; shift; if "$@"; then echo "ok   $d"; else echo "FAIL $d"; fail=1; fi; }
not() { ! "$@"; }
st() { "$L" status; }
mpvpid() { awk 'NR==1{print $2}' "$XDG_RUNTIME_DIR/lowpaper-$(id -u)/state" 2>/dev/null; }
watcher() { pgrep -f "^bash $L _watch" >/dev/null; }

ffmpeg -loglevel error -f lavfi -i testsrc=size=320x240:rate=10:duration=2 -pix_fmt yuv420p "$T/clip.mp4"
Xvfb :99 -screen 0 1280x720x24 +extension RANDR >"$T/xvfb.log" 2>&1 &
xvfb=$!
for _ in $(seq 50); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
mon=$(xrandr --listmonitors | awk 'NR==2{print $NF}')

"$L" "$T/clip.mp4"; sleep 3; st
check "plays on $mon" grep -q "^$mon  playing" <<< "$(st)"
check "watcher runs" watcher
"$L" pause;  check "pause"  grep -q paused  <<< "$(st)"
"$L" resume; check "resume" grep -q playing <<< "$(st)"
check "wrong -o fails" not "$L" -o NOPE "$T/clip.mp4"
check "wrong -o keeps the wallpaper" grep -q "^$mon  playing" <<< "$(st)"

before=$(mpvpid)
xrandr --fb 1024x768
# restore waits up to 20s for a desktop window, and Xvfb has none
for _ in $(seq 40); do [ "$(mpvpid)" != "$before" ] && [ -n "$(mpvpid)" ] && break; sleep 1; done
st
check "screen resize lays the wallpaper out again" test "$(mpvpid)" != "$before"
check "still plays after the resize" grep -q "^$mon  playing" <<< "$(st)"

"$L" stop; sleep 1
check "stop ends mpv" not pgrep -x mpv
check "stop ends the watcher" not watcher
kill "$xvfb"
exit $fail
