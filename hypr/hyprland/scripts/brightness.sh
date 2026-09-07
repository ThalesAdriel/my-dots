#!/bin/sh
state_dir=${XDG_RUNTIME_DIR:-/tmp}
id_file=$state_dir/brightness.id

notify_replacing() {
	last=$(cat "$id_file" 2>/dev/null)
	case $last in
	'' | *[!0-9]*) last=0 ;;
	esac

	new=$(notify-send -p -r "$last" -e -u low \
		-h string:x-canonical-private-synchronous:brightness "$@") || return
	case $new in
	'' | *[!0-9]*) ;;
	*) printf '%s\n' "$new" >"$id_file" ;;
	esac
}

apply() {
	state=$(brightnessctl -m set "$1")
	[ -n "$state" ] || exit 1

	percent=${state#*,*,*,}
	percent=${percent%%,*}
	percent=${percent%\%}

	notify_replacing -h int:value:"$percent" -i display-brightness "Brightness: $percent%"
}

case "$1" in
--inc) apply 10%+ ;;
--dec) apply 10%- ;;
--set)
	case $2 in
	'' | *[!0-9]*)
		echo "brightness.sh --set wants a percentage, 0 to 100" >&2
		exit 1
		;;
	esac
	[ "$2" -le 100 ] || exit 1
	apply "$2%"
	;;
--get) brightnessctl -m | cut -d, -f4 ;;
*) brightnessctl -m | cut -d, -f4 ;;
esac
