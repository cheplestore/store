#!/bin/bash
# Double-click me to pair a phone (shows a code for 10 minutes).
cd "$(dirname "$0")"
python3 -c "import cryptography" 2>/dev/null || pip3 install --user cryptography
caffeinate -i python3 cheple_private_cloud.py --pair
