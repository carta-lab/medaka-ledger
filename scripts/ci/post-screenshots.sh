#!/bin/bash
# UIテストで撮ったスクリーンショットを ci-screenshots ブランチに置き、PRのコメントに貼る（DECISIONS A）。
# 必要な環境変数: GH_TOKEN, PR_NUMBER, HEAD_SHA, REPO, RUN_URL
set -euo pipefail

SRC_DIR="${1:?usage: post-screenshots.sh <dir>}"
SHORT_SHA="${HEAD_SHA:0:7}"
DEST="pr-${PR_NUMBER}/${SHORT_SHA}"
BRANCH="ci-screenshots"
REMOTE="https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git"
WORK="$(mktemp -d)"

shopt -s nullglob
SHOTS=("$SRC_DIR"/*.png)
if [ ${#SHOTS[@]} -eq 0 ]; then
  BODY="**画面のスクリーンショット**（${SHORT_SHA}）

スクリーンショットはありません。ビルドかUIテストが失敗した可能性があります。
[CIの実行結果](${RUN_URL})"
else
  # ブランチが無いときだけ新しく作る。認証や通信の失敗では先へ進まない
  if git ls-remote --exit-code --heads "$REMOTE" "$BRANCH" >/dev/null 2>&1; then
    git clone --quiet --depth 1 --branch "$BRANCH" "$REMOTE" "$WORK"
  else
    if git ls-remote "$REMOTE" >/dev/null 2>&1; then
      git -C "$WORK" init --quiet -b "$BRANCH"
      git -C "$WORK" remote add origin "$REMOTE"
    else
      echo "ci-screenshots の状態を確認できませんでした（認証か通信の失敗）" >&2
      exit 1
    fi
  fi
  mkdir -p "$WORK/$DEST"
  cp "${SHOTS[@]}" "$WORK/$DEST/"
  git -C "$WORK" config user.name "github-actions[bot]"
  git -C "$WORK" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git -C "$WORK" add "$DEST"
  git -C "$WORK" commit --quiet -m "PR #${PR_NUMBER} ${SHORT_SHA} のスクリーンショット"
  # 別のPRの実行と同時に push したときは、取り込み直して再試行する
  pushed=0
  for attempt in 1 2 3; do
    if git -C "$WORK" push --quiet origin "$BRANCH"; then pushed=1; break; fi
    git -C "$WORK" pull --quiet --rebase origin "$BRANCH" || true
    sleep $((attempt * 2))
  done
  if [ "$pushed" -ne 1 ]; then
    echo "ci-screenshots への push に失敗しました" >&2
    exit 1
  fi

  BODY="**画面のスクリーンショット**（${SHORT_SHA}）

"
  for SHOT in $(cd "$WORK/$DEST" && ls *.png | sort); do
    NAME="${SHOT%.png}"
    URL="https://github.com/${REPO}/blob/${BRANCH}/${DEST}/${SHOT}?raw=true"
    BODY+="**${NAME}**
<img src=\"${URL}\" width=\"300\">

"
  done
  BODY+="[CIの実行結果](${RUN_URL})"
fi

printf '%s\n' "$BODY" > "$WORK/comment.md"
gh pr comment "$PR_NUMBER" --repo "$REPO" --edit-last --body-file "$WORK/comment.md" 2>/dev/null \
  || gh pr comment "$PR_NUMBER" --repo "$REPO" --body-file "$WORK/comment.md"
