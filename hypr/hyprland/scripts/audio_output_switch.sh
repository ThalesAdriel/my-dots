#!/usr/bin/env bash
set -uo pipefail
shopt -s extglob

format_name() {
	local name=$1 lower=${1,,} clean type

	if [[ $lower == *hdmi* || $lower == *displayport* ]]; then
		if [[ $lower =~ (hdmi|displayport)[^0-9]*([0-9]+) ]]; then
			printf 'HDMI %s [hdmi]\n' "${BASH_REMATCH[2]}"
		else
			printf 'HDMI [hdmi]\n'
		fi
		return
	fi

	clean=${name//Raptor Lake-+([^ ]) /}
	clean=${clean//cAVS /}
	clean=${clean//Analog Stereo/}
	clean=${clean//Output/}
	clean=${clean//+( )/ }
	clean=${clean##+( )}
	clean=${clean%%+( )}

	lower=${clean,,}
	case $lower in
	*headphone*) type=headphone ;;
	*speaker* | *line*) type=speaker ;;
	*bluetooth* | *a2dp*) type=bluetooth ;;
	*usb*) type=usb ;;
	*) type=audio ;;
	esac

	printf '%s [%s]\n' "$clean" "$type"
}

declare -A map=()
menu=()

while IFS='|' read -r desc real; do
	[ -n "$real" ] || continue

	pretty=$(format_name "$desc")
	base=$pretty
	count=1
	while [ -n "${map[$pretty]-}" ]; do
		count=$((count + 1))
		pretty="$base $count"
	done

	menu+=("$pretty")
	map[$pretty]=$real
done < <(pactl -f json list sinks | jq -r '.[] | "\(.description)|\(.name)"')

[ ${#menu[@]} -gt 0 ] || exit 0

choice=$(printf '%s\n' "${menu[@]}" | fuzzel --dmenu)
sink=${map[$choice]-}
[ -n "$sink" ] || exit 0

pactl set-default-sink "$sink" || exit 1

while read -r input _; do
	[ -n "$input" ] && pactl move-sink-input "$input" "$sink"
done < <(pactl list short sink-inputs)
