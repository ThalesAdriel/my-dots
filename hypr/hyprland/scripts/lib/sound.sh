#!/bin/sh
sound_state_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
sound_player=${0%/*}/sounds.sh

play_sound_once() {
  sound_file=$sound_state_dir/sound.$1.pid
  sound_last=
  [ -r "$sound_file" ] && read -r sound_last <"$sound_file"
  if [ -n "$sound_last" ] && kill -0 "$sound_last" 2>/dev/null; then
    return 0
  fi

  [ -r "$sound_player" ] || return 0
  sh "$sound_player" "--$1" &
  printf '%s\n' "$!" >"$sound_file"
}
