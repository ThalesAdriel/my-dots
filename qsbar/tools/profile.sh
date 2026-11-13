#!/bin/sh
# Measures where qsbar spends: its own CPU, the CPU and number of the processes
# it spawns, and what each external command it uses costs.
#
#   tools/profile.sh            20 s idle
#   tools/profile.sh 30         30 s idle
#   tools/profile.sh 20 --ui    also with the overview and the settings window open
#
# Runs on the host, inside the Hyprland session, with the bar already up. It
# changes nothing; --ui opens and closes the overview and the settings window.

SECS=${1:-20}
UI=${2:-}
SHELL_QML=${QSBAR_SHELL:-$HOME/.config/qsbar/shell.qml}
WALLPAPERS=${QSBAR_WALLPAPERS:-$HOME/Pictures/wallpapers}
TICK=$(getconf CLK_TCK 2>/dev/null || echo 100)
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

now_ms() { echo $(($(date +%s%N) / 1000000)); }

# utime stime cutime cstime threads rss_pages, without a fork: the name in
# parentheses may have spaces, so everything up to the last ")" is cut off.
read_stat() {
    read -r line <"/proc/$PID/stat" || return 1
    set -- ${line##*) }
    UT=${12} ST=${13} CUT=${14} CST=${15} THREADS=${18} RSS=${22}
}

# /proc/PID/task/*/children where the kernel has it, pgrep -P where it does not.
children_of() {
    found=
    for f in /proc/"$PID"/task/*/children; do
        # No trailing newline, so read fails even though it read the line.
        kids=
        [ -r "$f" ] && { read -r kids <"$f" || true; }
        found="$found$kids"
    done
    [ -n "$found" ] && echo "$found" || pgrep -P "$PID" 2>/dev/null
}

# One phase: samples the children every 50 ms and compares /proc/PID/stat before and after.
phase() {
    label=$1
    secs=$2
    : >"$LOG"
    seen=" "
    read_stat || { echo "qsbar exited during the measurement"; exit 1; }
    ut0=$UT st0=$ST cut0=$CUT cst0=$CST
    read -r _ forks0 <<EOF
$(grep '^processes' /proc/stat)
EOF
    t0=$(now_ms)
    i=0
    while [ $i -lt $((secs * 20)) ]; do
        for kid in $(children_of); do
            case $seen in
            *" $kid "*) ;;
            *)
                seen="$seen$kid "
                # A script handed to sh -c spans several lines; here it becomes one.
                { tr '\0\n' '  ' <"/proc/$kid/cmdline" 2>/dev/null; echo; } >>"$LOG"
                ;;
            esac
        done
        sleep 0.05
        i=$((i + 1))
    done
    t1=$(now_ms)
    read_stat || { echo "qsbar exited during the measurement"; exit 1; }
    read -r _ forks1 <<EOF
$(grep '^processes' /proc/stat)
EOF
    elapsed=$((t1 - t0))
    own=$(((UT + ST - ut0 - st0) * 1000 / TICK))
    kids=$(((CUT + CST - cut0 - cst0) * 1000 / TICK))

    echo
    echo "== $label ($((elapsed / 1000)) s)"
    echo "  qsbar CPU:           $own ms  ($(awk "BEGIN{printf \"%.2f\", $own*100/$elapsed}")% of one core)"
    echo "  children CPU:        $kids ms  ($(awk "BEGIN{printf \"%.2f\", $kids*100/$elapsed}")% of one core)"
    echo "  memory (RSS):        $((RSS * 4 / 1024)) MB, $THREADS threads"
    echo "  forks system-wide:   $((forks1 - forks0)) (includes this script's ~$((secs * 20)) sleeps)"
    echo "  children seen (sampled every 50 ms, very short ones can slip through):"
    tr '\0' ' ' <"$LOG" | awk '
        NF == 0 { next }
        {
            if (match($0, /qsbar-[a-z-]+/)) key = substr($0, RSTART, RLENGTH)
            else { key = $1; sub(/.*\//, "", key); if (NF > 1) key = key " " $2; if (NF > 2) key = key " " $3 }
            count[substr(key, 1, 48)]++
        }
        END { for (k in count) printf "    %4d  %s\n", count[k], k }' | sort -rn
    [ -s "$LOG" ] || echo "    none"
}

# Median of 5 runs, in ms.
bench() {
    name=$1
    needs=$2
    shift 2
    command -v "$needs" >/dev/null 2>&1 || { printf '  %-44s %s\n' "$name" "(no $needs)"; return; }
    for _ in 1 2 3 4 5; do
        a=$(date +%s%N)
        "$@" >/dev/null 2>&1
        b=$(date +%s%N)
        echo $(((b - a) / 1000000))
    done | sort -n | sed -n 3p | {
        read -r ms
        printf '  %-44s %5s ms\n' "$name" "$ms"
    }
}

ipc() { qs ipc -p "$SHELL_QML" call "$@" >/dev/null 2>&1; }

echo "qsbar profile, $(date '+%Y-%m-%d %H:%M'), $(uname -r)"

# The Quickshell process itself, not an sh or a "qs ipc" with the same path on its command line.
PID=${QSBAR_PID:-}
for candidate in $(pgrep -f -- "-p $SHELL_QML" 2>/dev/null); do
    [ -n "$PID" ] && break
    read -r comm <"/proc/$candidate/comm" 2>/dev/null || continue
    case $comm in
    qs | quickshell | .quickshell* | .qs*) PID=$candidate ;;
    esac
done
if [ -n "$PID" ] && [ -r "/proc/$PID/stat" ]; then
    echo "pid $PID, up for $(ps -o etime= -p "$PID" | tr -d ' ')"
    phase "idle" "$SECS"
    if [ "$UI" = "--ui" ]; then
        ipc overview open
        phase "overview open" $((SECS / 2))
        ipc overview close
        ipc settings open
        phase "settings open" $((SECS / 2))
        ipc settings close
    fi
else
    echo "qsbar not found running with -p $SHELL_QML (set QSBAR_SHELL); skipping the phases."
fi

echo
echo "== cost of each external command (median of 5)"
echo " keybinds (per key press):"
bench "qs ipc show (IPC round trip)" qs qs ipc -p "$SHELL_QML" show
echo " overview and monitors:"
bench "hyprctl -j clients" hyprctl hyprctl -j clients
bench "hyprctl -j monitors" hyprctl hyprctl -j monitors
bench "hyprctl -j monitors all" hyprctl hyprctl -j monitors all
echo " network (one read = all four):"
bench "nmcli radio wifi" nmcli nmcli -t radio wifi
bench "nmcli device status" nmcli nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status
bench "nmcli device wifi list" nmcli nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no
bench "nmcli connection show" nmcli nmcli -t -f NAME,TYPE connection show
echo " bluetooth (one full read = all four):"
bench "bluetoothctl show" bluetoothctl timeout 5 bluetoothctl show
bench "bluetoothctl devices Connected" bluetoothctl timeout 5 bluetoothctl devices Connected
bench "bluetoothctl devices Paired" bluetoothctl timeout 5 bluetoothctl devices Paired
bench "bluetoothctl devices" bluetoothctl timeout 5 bluetoothctl devices
echo " brightness, power, recording:"
bench "brightnessctl -m" brightnessctl brightnessctl -m
bench "powerprofilesctl get" powerprofilesctl powerprofilesctl get
bench "powerprofilesctl list" powerprofilesctl powerprofilesctl list
bench "pgrep -f gpu-screen-recorder" pgrep pgrep -f gpu-screen-recorder
echo " settings pages (once per visit, or per search):"
bench "awww query" awww awww query
bench "find over the wallpapers" find find -L "$WALLPAPERS" -maxdepth 1 -type f
bench "gsettings list-recursively interface" gsettings gsettings list-recursively org.gnome.desktop.interface
bench "fc-list : family" fc-list fc-list : family
bench "fc-list :spacing=mono family" fc-list fc-list :spacing=mono family
bench "awk over every .desktop" awk sh -c 'IFS=:; for d in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do [ -d "$d/applications" ] && find -L "$d/applications" -name "*.desktop" -type f -exec awk "/^MimeType=/" {} +; done'
bench "gio mime (x8 per read)" gio gio mime x-scheme-handler/https
