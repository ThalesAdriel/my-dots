#!/bin/sh
. "${0%/*}/lib/notify.sh"
. "${0%/*}/lib/sound.sh"

audio() {
	qs ipc -p "$HOME/.config/qsbar/shell.qml" call audio "$1" 2>/dev/null
}

sink_icon() {
	if ! is_uint "$1" || [ "$1" -le 0 ]; then
		echo audio-volume-muted
	elif [ "$1" -le 30 ]; then
		echo audio-volume-low
	elif [ "$1" -le 60 ]; then
		echo audio-volume-medium
	else
		echo audio-volume-high
	fi
}

notify_sink() {
	[ -n "${1-}" ] || return

	if [ "$1" = muted ]; then
		notify_replacing volume -i audio-volume-muted "Volume: Muted"
		return
	fi

	level=${1%\%}
	notify_replacing volume -h int:value:"$level" -i "$(sink_icon "$level")" "Volume: $level%"
	play_sound_once volume
}

notify_source() {
	[ -n "${1-}" ] || return

	if [ "$1" = muted ]; then
		notify_replacing microphone -i microphone-sensitivity-muted "Microphone: Muted"
		return
	fi

	level=${1%\%}
	notify_replacing microphone -h int:value:"$level" -i audio-input-microphone "Microphone: $level%"
}

case "${1-}" in
--inc) notify_sink "$(audio sinkUp)" ;;
--dec) notify_sink "$(audio sinkDown)" ;;
--toggle) notify_sink "$(audio sinkToggle)" ;;
--mic-inc) notify_source "$(audio sourceUp)" ;;
--mic-dec) notify_source "$(audio sourceDown)" ;;
--toggle-mic) notify_source "$(audio sourceToggle)" ;;
*) audio sinkStatus ;;
esac
