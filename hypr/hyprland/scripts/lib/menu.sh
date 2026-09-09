#!/bin/sh
menu_from_data() {
	sed "1,/^### DATA ###\$/d" "$1" | fuzzel --match-mode fzf --dmenu
}
