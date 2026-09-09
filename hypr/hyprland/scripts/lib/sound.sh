#!/bin/sh
sound_state_dir=${XDG_RUNTIME_DIR:-/tmp}
sound_player=${0%/*}/Sounds.sh

play_sound_once() {
	sound_file=$sound_state_dir/sound.$1.pid
	sound_last=
	[ -r "$sound_file" ] && read -r sound_last <"$sound_file"
	if [ -n "$sound_last" ] && kill -0 "$sound_last" 2>/dev/null; then
		return 0
	fi

	[ -x "$sound_player" ] || return 0
	"$sound_player" "--$1" &
	printf '%s\n' "$!" >"$sound_file"
}
