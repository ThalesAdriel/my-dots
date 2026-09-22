#!/bin/sh
set -f
for cmd in "$@"; do
	set -- $cmd
	command -v "$1" >/dev/null 2>&1 && exec "$@"
done
exit 1
