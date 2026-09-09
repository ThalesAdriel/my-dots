#!/bin/sh
case "${1-}" in
lock) exec loginctl lock-session ;;
suspend)
	sleep 0.1
	systemctl suspend || exec loginctl suspend
	;;
poweroff) systemctl poweroff || exec loginctl poweroff ;;
reboot) systemctl reboot || exec loginctl reboot ;;
soft-reboot) exec systemctl soft-reboot ;;
*)
	echo "usage: ${0##*/} {lock|suspend|poweroff|reboot|soft-reboot}" >&2
	exit 1
	;;
esac
