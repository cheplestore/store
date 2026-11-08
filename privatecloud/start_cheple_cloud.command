#!/bin/bash
# Double-click me on your Mac to start Cheple Private Cloud.
# (First time: right-click > Open, because macOS asks about files from the internet.)
cd "$(dirname "$0")"
python3 -c "import cryptography" 2>/dev/null || pip3 install --user cryptography
caffeinate -i python3 cheple_private_cloud.py --lite-model llama3.2:1b "$@"
