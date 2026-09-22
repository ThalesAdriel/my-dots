#!/usr/bin/env bash
set -uo pipefail

audio_monitor() {
	pactl list short sources | awk '/\.monitor\b/ { print $2; exit }'
}

active_monitor() {
	hyprctl monitors -j | jq -r 'first(.[] | select(.focused) | .name)'
}

if pgrep -x wf-recorder >/dev/null; then
	pkill -INT -x wf-recorder
	notify-send "Recording Stopped" "Stopped" -a Recorder
	exit 0
fi

target=$(xdg-user-dir VIDEOS 2>/dev/null)
[ -n "$target" ] && [ "$target" != "$HOME" ] || target=$HOME/Videos
mkdir -p "$target" || exit 1

name="recording_$(date '+%Y-%m-%d_%H.%M.%S').mp4"
args=(--pixel-format yuv420p -t -f "$target/$name")

case "${1-}" in
--fullscreen | --fullscreen-sound)
	args+=(-o "$(active_monitor)")
	;;
*)
	if ! region=$(slurp 2>/dev/null); then
		notify-send "Recording cancelled" "Selection was cancelled" -a Recorder
		exit 1
	fi
	args+=(--geometry "$region")
	;;
esac

case "${1-}" in
--fullscreen-sound | --sound)
	args+=(--audio="$(audio_monitor)")
	;;
esac

notify-send "Starting recording" "$name" -a Recorder
exec wf-recorder "${args[@]}"
