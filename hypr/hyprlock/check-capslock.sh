#!/usr/bin/env bash
caps=$(hyprctl -j devices | jq -r '[.keyboards[] | select(.main) | .capsLock] | first // false')
[ "$caps" = true ] && echo "Caps Lock active" || echo
