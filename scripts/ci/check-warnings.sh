#!/bin/bash
# Swiftのコンパイル警告が1件でもあれば失敗させる（CLAUDE.md「毎回の確認」1）。
set -uo pipefail

LOG="${1:?usage: check-warnings.sh <xcodebuild.log>}"
if [ ! -f "$LOG" ]; then
  echo "log not found: $LOG"
  exit 1
fi

WARNINGS=$(grep -E '\.swift:[0-9]+:[0-9]+: warning:' "$LOG" | sort -u)
if [ -n "$WARNINGS" ]; then
  COUNT=$(echo "$WARNINGS" | wc -l | tr -d ' ')
  echo "Swift warnings: $COUNT"
  echo "$WARNINGS"
  exit 1
fi
echo "Swift warnings: 0"
