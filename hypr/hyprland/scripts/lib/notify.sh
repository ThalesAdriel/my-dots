#!/bin/sh
notify_state_dir=${XDG_RUNTIME_DIR:-/tmp}

is_uint() {
	case ${1-} in
	'' | *[!0-9]*) return 1 ;;
	esac
}

notify_replacing() {
	notify_name=$1
	notify_file=$notify_state_dir/$notify_name.id
	shift

	notify_last=0
	[ -r "$notify_file" ] && read -r notify_last <"$notify_file"
	is_uint "$notify_last" || notify_last=0

	notify_id=$(notify-send -p -r "$notify_last" -e -u low \
		-h "string:x-canonical-private-synchronous:$notify_name" "$@") || return 1
	is_uint "$notify_id" && printf '%s\n' "$notify_id" >"$notify_file"
	return 0
}
