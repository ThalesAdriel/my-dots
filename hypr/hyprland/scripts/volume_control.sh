#!/bin/sh
. "${0%/*}/lib/notify.sh"
. "${0%/*}/lib/sound.sh"

step=5

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
	state=$(pamixer --get-volume-human) || return
	if [ "$state" = muted ]; then
		notify_replacing volume -i audio-volume-muted "Volume: Muted"
		return
	fi

	level=${state%\%}
	notify_replacing volume -h int:value:"$level" -i "$(sink_icon "$level")" "Volume: $level%"
	play_sound_once volume
}

notify_source() {
	if [ "$(pamixer --default-source --get-mute)" = true ]; then
		notify_replacing microphone -i microphone-sensitivity-muted "Microphone: Muted"
		return
	fi

	level=$(pamixer --default-source --get-volume) || return
	notify_replacing microphone -h int:value:"$level" -i audio-input-microphone "Microphone: $level%"
}

case "${1-}" in
--inc)
	pamixer -u
	pamixer -i "$step" && notify_sink
	;;
--dec)
	pamixer -u
	pamixer -d "$step" && notify_sink
	;;
--toggle) pamixer -t && notify_sink ;;
--mic-inc)
	pamixer --default-source -u
	pamixer --default-source -i "$step" && notify_source
	;;
--mic-dec)
	pamixer --default-source -u
	pamixer --default-source -d "$step" && notify_source
	;;
--toggle-mic) pamixer --default-source -t && notify_source ;;
--get-icon)
	state=$(pamixer --get-volume-human)
	[ "$state" = muted ] && sink_icon 0 || sink_icon "${state%\%}"
	;;
--get-mic-icon)
	[ "$(pamixer --default-source --get-mute)" = true ] && echo microphone-sensitivity-muted || echo audio-input-microphone
	;;
*) pamixer --get-volume-human ;;
esac
