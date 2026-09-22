#!/bin/sh
case "$1" in
--screenshot) name=screen-capture ;;
--volume) name=audio-volume-change ;;
*)
	echo "Available sounds: --screenshot, --volume"
	exit 0
	;;
esac

for dir in "$HOME/.local/share/sounds/freedesktop" "/usr/share/sounds/freedesktop"; do
	for file in "$dir/stereo/$name."*; do
		[ -f "$file" ] || continue
		exec pw-play "$file"
	done
done

exit 1
