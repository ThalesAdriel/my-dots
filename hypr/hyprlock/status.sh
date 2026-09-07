#!/usr/bin/env bash
for battery in /sys/class/power_supply/*BAT*; do
	[[ -r $battery/capacity && -r $battery/status ]] || continue

	read -r capacity <"$battery/capacity"
	read -r state <"$battery/status"

	if [[ $state == Charging ]]; then
		printf '(+) %s%%' "$capacity"
	else
		printf '%s%% remaining' "$capacity"
	fi
	break
done
echo
