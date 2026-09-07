#!/bin/sh
set -eu

case ${1-} in
workspace | movetoworkspace | movetoworkspacesilent) ;;
*)
	echo "usage: ${0##*/} <workspace|movetoworkspace|movetoworkspacesilent> <1-10>" >&2
	exit 1
	;;
esac

case ${2-} in
'' | *[!0-9]*)
	echo "usage: ${0##*/} $1 <1-10>" >&2
	exit 1
	;;
esac

current=$(hyprctl activeworkspace -j | jq -r .id)
case $current in
'' | *[!0-9]*) exit 1 ;;
esac

hyprctl dispatch "$1" "$(((current - 1) / 10 * 10 + $2))"
