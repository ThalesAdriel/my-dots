#!/bin/sh
set -eu
dir=${ARRPC_DIR:-$HOME/Downloads/arrpc-3.7.0}
cd "$dir" || exit 1
exec npx --no-install arrpc
