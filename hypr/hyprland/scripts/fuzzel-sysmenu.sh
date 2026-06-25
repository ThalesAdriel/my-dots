#!/bin/bash
set -euo pipefail

MODE="${1:-run}"

# Present options via fuzzel (or rofi/dmenu if you prefer)
action="$(sed '1,/^### DATA ###$/d' "$0" | fuzzel --match-mode fzf --dmenu | cut -d ' ' -f1)"

case "$MODE" in
    run)
        case "$action" in
            shutdown)
                systemctl poweroff
                ;;
            reboot)
                systemctl reboot
                ;;
            soft-reboot)
                systemctl soft-reboot
                ;;
            lock)
                # Try to lock with swaylock, fallback to loginctl if available
                swaylock || loginctl lock-session || echo "Lock command failed"
                ;;
            suspend)
                systemctl suspend
                ;;
            *)
                echo "No valid action selected or canceled."
                ;;
        esac
        ;;
    echo)
        echo "$action"
        ;;
    *)
        echo "Usage: $0 [run|echo]"
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
