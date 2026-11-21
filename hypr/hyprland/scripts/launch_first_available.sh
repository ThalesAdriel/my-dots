#!/bin/sh
set -f
for cmd in "$@"; do
	set -- $cmd
	if [ "$1" = "flatpak" ] && [ "$2" = "run" ] && [ -n "$3" ]; then
		if command -v flatpak >/dev/null 2>&1; then
			if [ -d "${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/app/$3" ] || [ -d "/var/lib/flatpak/app/$3" ] || flatpak info "$3" >/dev/null 2>&1; then
				exec "$@"
			fi
		fi
	else
		command -v "$1" >/dev/null 2>&1 && exec "$@"
	fi
done
exit 1
