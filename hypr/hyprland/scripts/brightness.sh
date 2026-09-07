#!/bin/sh
sync_hint=string:x-canonical-private-synchronous:brightness_notif

apply() {
	state=$(brightnessctl -m set "$1")
	[ -n "$state" ] || exit 1

	percent=${state#*,*,*,}
	percent=${percent%%,*}
	percent=${percent%\%}

	notify-send -e -u low -h "$sync_hint" -h int:value:"$percent" -i display-brightness "Brightness: $percent%"
}

case "$1" in
--inc) apply 10%+ ;;
--dec) apply 10%- ;;
--get) brightnessctl -m | cut -d, -f4 ;;
*) brightnessctl -m | cut -d, -f4 ;;
esac
