#!/bin/sh
fail() {
  [ -n "$1" ] && msg="$1" || msg="erro desconhecido"
  command -v notify-send >/dev/null 2>&1 &&
    notify-send -u critical -a "power.sh" "Falha em '${action}'" "$msg"
  printf '%s: %s\n' "${0##*/}" "$msg" >&2
  exit 1
}

attempt() {
  err=$("$@" 2>&1) && exit 0
  [ -n "$err" ] && last_err="$err"
  return 1
}

power() {
  attempt systemctl "$action"
  attempt systemctl --check-inhibitors=no "$action"
  attempt systemctl -i "$action"
  attempt loginctl "$action"
  fail "$last_err"
}

action="${1-}"
case "$action" in
lock) exec loginctl lock-session ;;
suspend)
  sleep 0.1
  power
  ;;
poweroff | reboot) power ;;
soft-reboot) exec systemctl soft-reboot ;;
*)
  fail "ação inválida: '$action' (use lock|suspend|poweroff|reboot|soft-reboot)"
  ;;
esac
