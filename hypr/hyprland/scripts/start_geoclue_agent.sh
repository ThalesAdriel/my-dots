#!/bin/sh
pgrep -f 'geoclue-2.0/demos/agent' >/dev/null && exit 0

for path in \
	/usr/libexec/geoclue-2.0/demos/agent \
	/usr/lib/geoclue-2.0/demos/agent; do
	[ -x "$path" ] && exec "$path"
done

echo "GeoClue agent not found in /usr/libexec or /usr/lib." >&2
exit 1
