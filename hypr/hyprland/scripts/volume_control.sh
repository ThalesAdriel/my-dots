#!/bin/sh
step=5
sounds="${0%/*}/Sounds.sh"
sync_hint=string:x-canonical-private-synchronous:volume_notif

sink_icon() {
	if [ "$1" -le 0 ]; then
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
	state=$(pamixer --get-volume-human)
	if [ "$state" = muted ]; then
		notify-send -e -u low -h "$sync_hint" -i audio-volume-muted "Volume: Muted"
		return
	fi

	level=${state%\%}
	notify-send -e -u low -h "$sync_hint" -h int:value:"$level" -i "$(sink_icon "$level")" "Volume: $level%"
	[ -x "$sounds" ] && "$sounds" --volume &
}

notify_source() {
	if [ "$(pamixer --default-source --get-mute)" = true ]; then
		notify-send -e -u low -h "$sync_hint" -i microphone-sensitivity-muted "Microphone: Muted"
		return
	fi

	level=$(pamixer --default-source --get-volume)
	notify-send -e -u low -h "$sync_hint" -h int:value:"$level" -i audio-input-microphone "Mic-Level: $level%"
}

case "$1" in
--inc)
	pamixer -u; pamixer -i "$step" && notify_sink
	;;
--dec)
	pamixer -u; pamixer -d "$step" && notify_sink
	;;
--toggle)
	pamixer -t && notify_sink
	;;
--mic-inc)
	pamixer --default-source -u; pamixer --default-source -i "$step" && notify_source
	;;
--mic-dec)
	pamixer --default-source -u; pamixer --default-source -d "$step" && notify_source
	;;
--toggle-mic)
	pamixer --default-source -t && notify_source
	;;
--get-icon)
	state=$(pamixer --get-volume-human)
	[ "$state" = muted ] && sink_icon 0 || sink_icon "${state%\%}"
	;;
--get-mic-icon)
	[ "$(pamixer --default-source --get-mute)" = true ] && echo microphone-sensitivity-muted || echo audio-input-microphone
	;;
*)
	pamixer --get-volume-human
	;;
esac
