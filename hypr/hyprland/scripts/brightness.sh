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
--set)
	if ! is_uint "${2-}" || [ "$2" -gt 100 ]; then
		echo "${0##*/} --set wants a percentage, 0 to 100" >&2
		exit 1
	fi
	apply "$2%"
	;;
*) brightnessctl -m | cut -d, -f4 ;;
esac
