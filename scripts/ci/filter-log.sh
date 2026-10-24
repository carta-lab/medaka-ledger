#!/bin/bash
# xcodebuildの出力から、エラー、警告、テスト結果の行だけを流す（全文はbuild/xcodebuild.logに残る）。
grep --line-buffered -E "error:|warning:|\*\* (BUILD|TEST)|Test Suite|Test Case .*(passed|failed)|✔|✘|◇|Executed|Testing failed|Test run with|crashed|Crash|signal [0-9]+|Fatal error|Restarting after|性能:" || true
