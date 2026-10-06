#!/bin/sh
case "$1" in
--volume) name=audio-volume-change ;;
*) exit 1 ;;
esac

for dir in "$HOME/.local/share/sounds/freedesktop" "/usr/share/sounds/freedesktop"; do
	for file in "$dir/stereo/$name."*; do
		[ -f "$file" ] || continue
		exec pw-play "$file"
	done
done

exit 1
