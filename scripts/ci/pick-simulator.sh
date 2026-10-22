#!/bin/bash
# 利用できるiPhoneシミュレータのUDIDを1つ出力する。iPhone 17を優先し、無ければ最新のiOSのiPhoneを選ぶ。
set -euo pipefail

xcrun simctl list devices available -j | python3 -c '
import json, re, sys

devices = json.load(sys.stdin)["devices"]
candidates = []
for runtime, entries in devices.items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    for device in entries:
        if device["name"].startswith("iPhone"):
            candidates.append((version, device["name"], device["udid"]))

if not candidates:
    sys.exit("no iPhone simulator available")

candidates.sort()
preferred = [c for c in candidates if c[1] == "iPhone 17"] or candidates
print(preferred[-1][2])
'
