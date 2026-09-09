#!/bin/sh
. "${0%/*}/lib/menu.sh"

action=$(menu_from_data "$0" | cut -d ' ' -f1)
[ -n "$action" ] || exit 0

case "${1:-run}" in
run) exec "${0%/*}/power.sh" "$action" ;;
echo) echo "$action" ;;
*)
	echo "usage: ${0##*/} [run|echo]" >&2
	exit 1
	;;
esac
exit

### DATA ###
shutdown  ⏻  Power off the system
reboot    🗘  Reboot the system
soft-reboot ♻  Restart user session (systemd soft-reboot)
lock      ꗃ  Lock the screen
suspend   ⏾  Suspend the system
