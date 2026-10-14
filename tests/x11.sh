#!/usr/bin/env bash
# Smoke test on a headless X server: play, pause, a wrong -o, re-layout after a resolution change, stop.
# Needs: mpv, ffmpeg, python3, x11-utils (xprop, xev, xkill, xwininfo), xrandr, and Xorg's dummy driver
# (falls back to Xvfb, which cannot change resolution, so the resize check is skipped there).
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
if [ -e /usr/lib/xorg/modules/drivers/dummy_drv.so ] && sudo -n true 2>/dev/null; then
  printf '%s\n' \
    'Section "Device"' '  Identifier "d"' '  Driver "dummy"' '  VideoRam 64000' 'EndSection' \
    'Section "Monitor"' '  Identifier "m"' '  HorizSync 5.0-1000.0' '  VertRefresh 5.0-200.0' \
    '  Modeline "1280x720" 74.25 1280 1390 1430 1650 720 725 730 750 +hsync +vsync' \
    '  Modeline "1024x768" 65.00 1024 1048 1184 1344 768 771 777 806 -hsync -vsync' 'EndSection' \
    'Section "Screen"' '  Identifier "s"' '  Device "d"' '  Monitor "m"' '  DefaultDepth 24' \
    '  SubSection "Display"' '    Depth 24' '    Modes "1280x720" "1024x768"' '  EndSubSection' 'EndSection' \
    > "$T/dummy.conf"
  sudo Xorg :99 -noreset -config "$T/dummy.conf" -logfile "$T/xorg.log" >/dev/null 2>&1 &
  resize() { xrandr -s 1024x768; }
  stopx() { sudo pkill -x Xorg; }
else
  Xvfb :99 -screen 0 1280x720x24 +extension RANDR >"$T/xvfb.log" 2>&1 &
  resize() { return 1; }
  stopx() { pkill -x Xvfb; }
fi
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
if resize; then
  # restore waits up to 20s for a desktop window, and there is none here
  for _ in $(seq 40); do [ "$(mpvpid)" != "$before" ] && [ -n "$(mpvpid)" ] && break; sleep 1; done
  st
  check "resolution change lays the wallpaper out again" test -n "$(mpvpid)" -a "$(mpvpid)" != "$before"
  check "still plays after the change" grep -q "^$mon  playing" <<< "$(st)"
else
  echo "skip resolution change (needs Xorg with the dummy driver)"
fi

"$L" stop; sleep 1
check "stop ends mpv" not pgrep -x mpv
check "stop ends the watcher" not watcher
stopx
[ $fail = 0 ] || tail -n 20 "$XDG_RUNTIME_DIR"/lowpaper-*/*.log 2>/dev/null
exit $fail
