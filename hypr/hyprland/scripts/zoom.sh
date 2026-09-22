#!/usr/bin/env bash
set -uo pipefail

get_zoom() {
	hyprctl getoption -j cursor:zoom_factor | jq -r '.float'
}

set_zoom() {
	local clamped
	clamped=$(awk -v v="$1" 'BEGIN { if (v < 1) v = 1; if (v > 3) v = 3; printf "%.3f\n", v }')
	hyprctl eval "hl.config({ cursor = { zoom_factor = $clamped } })"
}

need_step() {
	case ${1-} in
	'' | *[!0-9.]* | *.*.*)
		echo "usage: ${0##*/} {reset|increase STEP|decrease STEP}" >&2
		exit 1
		;;
	esac
}

case "${1-}" in
reset)
	set_zoom 1
	;;
increase)
	need_step "${2-}"
	set_zoom "$(awk -v c="$(get_zoom)" -v s="$2" 'BEGIN { print c + s }')"
	;;
decrease)
	need_step "${2-}"
	set_zoom "$(awk -v c="$(get_zoom)" -v s="$2" 'BEGIN { print c - s }')"
	;;
*)
	echo "usage: ${0##*/} {reset|increase STEP|decrease STEP}" >&2
	exit 1
	;;
esac
