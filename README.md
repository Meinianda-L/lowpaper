# lowpaper

Ultra-lightweight, low-resource video wallpaper for Linux, designed for low-end and old hardware.

A minimal Bash script around mpv, with automatic pausing when the wallpaper is not visible.

![lowpaper playing a video wallpaper on XFCE, with Task Manager showing its processes](docs/demo.gif)

- **Lightweight / low resource**: ~2% of one CPU core while playing, 0% when covered. See [Measured](#measured).
- **Runs on low-end, old hardware**: tested on a Core2 Duo with no hardware video decoding.
- **Minimal**: one bash script, no daemon, no GUI, no Electron.
- **Built on mpv**: a mature, light player does the decoding; lowpaper only places and pauses it.
- **Video wallpaper, image or slideshow**: mp4/webm/gif/jpg/png, or a whole folder.
- **X11 and Wayland**: XFCE, MATE, Cinnamon, Sway, Hyprland, KDE.
- **Pauses itself** when a fullscreen or maximized window covers the desktop.

## Install
```sh
sudo apt install mpv
git clone https://github.com/Meinianda-L/lowpaper-live-wallpaper.git
install -Dm755 lowpaper-live-wallpaper/lowpaper ~/.local/bin/lowpaper
```

## Usage
```sh
lowpaper ~/Videos/rain.mp4        
lowpaper ~/Pictures/sky.jpg       
lowpaper -i 600 -s ~/Pictures     # folder = slideshow; -i image interval in seconds, -s shuffle
lowpaper -f fit video.mp4         # fill (default, crop) | fit (letterbox) | stretch
lowpaper -o HDMI-1 video.mp4      # one monitor only
lowpaper                          # show what is playing
lowpaper pause | resume | toggle | next | stop | status | restore
lowpaper fit fill|fit|stretch     # change scaling live
lowpaper autopause on|off         # pause while the focused window is fullscreen/maximized (default on)
lowpaper startup on|off           # start at login, restoring the last wallpaper
```
Settings live in `~/.config/lowpaper/config` (FIT, INTERVAL, AUTOPAUSE, CACHE_MB, ICONS, HWDEC).

## Requirements
| Environment | Needs |
|---|---|
| all | mpv |
| X11 desktop (XFCE, MATE, Cinnamon, … — anything with a desktop window) | python3, xprop, xrandr, xkill (preinstalled on Debian/Ubuntu/Mint) |
| Wayland with layer-shell (Sway, Hyprland, KDE, …) | mpvpaper |

Optional: `gcc` keeps XFCE desktop icons above the video. OpenBSD `nc` (default on Debian/Ubuntu) is used for mpv IPC (~3ms per call); without it lowpaper falls back to python, which is much slower on old CPUs.
GNOME Wayland has no layer-shell; use the Hanabi extension there. Bare window managers (i3, openbox) without a desktop window are not supported.

## Measured
Linux Mint 22.3 XFCE/X11, Core2 Duo P8600, GeForce 320M (nouveau, no usable hwdec), 1080p display, 1280×962 10fps H.264 clip (3s).

| | CPU (% of one core) | RAM |
|---|---|---|
| playing: mpv (short clip, decoded once and replayed from RAM) | 2.1% | 138MB |
| playing: mpv (decoding every loop, `CACHE_MB=0`) | 13.9% | 94MB |
| playing: Xorg + xfwm4 compositor, icons above the video | ~12–14% | — |
| watcher (bash + 2 × xprop) | ~0% | 8MB |
| covered by a fullscreen/maximized window | 0% | same |
| single image on XFCE | 0 | 0 |
| single image through mpv (`--mpv` or slideshow) | 0 | ~200MB |

## Known limits
- After a resolution or monitor change, or if xfdesktop restarts on its own, run `lowpaper restore`.
