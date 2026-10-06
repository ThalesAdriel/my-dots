#!/bin/sh
. "${0%/*}/lib/notify.sh"

apply() {
	state=$(brightnessctl -m set "$1")
	[ -n "$state" ] || exit 1

	percent=${state#*,*,*,}
	percent=${percent%%,*}
	percent=${percent%\%}

	notify_replacing brightness -h int:value:"$percent" -i display-brightness "Brightness: $percent%"
}

case "${1-}" in
--inc) apply 10%+ ;;
--dec) apply 10%- ;;
esac
