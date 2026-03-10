#!/bin/bash

satty --filename "$1" \
  --output-filename "$1" \
  --actions-on-enter save-to-clipboard \
  --save-after-copy \
  --copy-command wl-copy
