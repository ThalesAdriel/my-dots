#!/bin/bash

format_name() {
  name="$1"

  lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')

  if [[ "$lower" == *"hdmi"* ]] || [[ "$lower" == *"displayport"* ]]; then
    num=$(echo "$name" | grep -o '[0-9]\+' | head -n1)
    if [ -n "$num" ]; then
      echo "HDMI $num [hdmi]"
    else
      echo "HDMI [hdmi]"
    fi
    return
  fi

  clean=$(echo "$name" | sed -E '
        s/Raptor Lake-[^ ]+ //g;
        s/cAVS //g;
        s/Analog Stereo//g;
        s/Output//g;
        s/ +/ /g;
        s/^ //;
        s/ $//;
    ')

  lower=$(echo "$clean" | tr '[:upper:]' '[:lower:]')

  if [[ "$lower" == *"headphone"* ]]; then
    type="headphone"
  elif [[ "$lower" == *"speaker"* ]] || [[ "$lower" == *"line"* ]]; then
    type="speaker"
  elif [[ "$lower" == *"bluetooth"* ]] || [[ "$lower" == *"a2dp"* ]]; then
    type="bluetooth"
  elif [[ "$lower" == *"usb"* ]]; then
    type="usb"
  else
    type="audio"
  fi

  echo "$clean [$type]"
}

mapfile -t sinks < <(pactl -f json list sinks | jq -r '.[] | "\(.description)|\(.name)"')

menu=""
declare -A map

for s in "${sinks[@]}"; do
  desc="${s%%|*}"
  real="${s##*|}"

  pretty=$(format_name "$desc")

  count=1
  base="$pretty"
  while [[ -n "${map[$pretty]}" ]]; do
    ((count++))
    pretty="$base $count"
  done

  menu+="$pretty\n"
  map["$pretty"]="$real"
done

choice=$(echo -e "$menu" | fuzzel --dmenu)

sink="${map[$choice]}"

if [ -n "$sink" ]; then
  pactl set-default-sink "$sink"

  for input in $(pactl list short sink-inputs | awk '{print $1}'); do
    pactl move-sink-input "$input" "$sink"
  done
fi
