#!/bin/bash
set -uo pipefail

MODE="${1:-run}"

action="$(sed '1,/^### DATA ###$/d' "$0" | fuzzel --match-mode fzf --dmenu | cut -d ' ' -f1)"

case "$MODE" in
    run)
        case "$action" in
            shutdown)    systemctl poweroff ;;
            reboot)      systemctl reboot ;;
            soft-reboot) systemctl soft-reboot ;;
            lock)        loginctl lock-session ;;
            suspend)     systemctl suspend ;;
            *)           exit 0 ;;
        esac
        ;;
    echo)
        echo "$action"
        ;;
    *)
        echo "Usage: $0 [run|echo]" >&2
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
