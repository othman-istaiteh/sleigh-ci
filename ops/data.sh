#!/usr/bin/env bash
# Bootstrap: code, step scripts and data live in a private repository reached with DATA_TOKEN.
#   data.sh pull | push MSG FILE... | put TAG FILE... (private release asset, replaced) | get TAG PATTERN DIR
set -euo pipefail
OWNER=${DATA_OWNER:-${GITHUB_REPOSITORY_OWNER:-othman-istaiteh}}
REPO=${DATA_REPO:-sleigh-private}
ROOT=${GITHUB_WORKSPACE:-$(pwd)}
D=$ROOT/priv
[ -n "${DATA_TOKEN:-}" ] || { echo "data.sh: DATA_TOKEN is not set"; exit 1; }
URL="https://x-access-token:${DATA_TOKEN}@github.com/$OWNER/$REPO.git"
cmd=${1:-}; shift || true
case "$cmd" in
  pull)
    rm -rf "$D"
    for i in 1 2 3; do git clone -q --depth 1 "$URL" "$D" 2> clone.err && break; sleep $((i * 10)); done
    [ -d "$D/.git" ] || { echo "data.sh: clone failed: $(sed 's#https://[^@]*@#https://#g' clone.err | head -c 300)"; exit 1; }
    rm -f clone.err
    (cd "$D" && tar --exclude=.git -cf - .) | tar -C "$ROOT" -xf -; echo "data: pulled $REPO@$(git -C "$D" rev-parse --short HEAD)" ;;
  push)
    MSG=$1; shift
    for f in "$@"; do mkdir -p "$D/$(dirname "$f")"; cp "$ROOT/$f" "$D/$f"; done
    cd "$D"
    git config user.name "othman-istaiteh" && git config user.email "othmanistaiteh@gmail.com"
    for f in "$@"; do git add -A -- "$f"; done
    git commit -q -m "$MSG" || { echo "data: nothing to commit"; exit 0; }
    B=$(git rev-parse --abbrev-ref HEAD)
    for i in 1 2 3 4 5; do git pull -q --rebase origin "$B" && git push -q origin "HEAD:$B" && { echo "data: pushed $*"; exit 0; }; sleep $((i * 15)); done
    echo "data.sh: push failed"; exit 1 ;;
  put)
    TAG=$1; shift; export GH_TOKEN=$DATA_TOKEN
    for i in 1 2 3 4 5; do
      if gh release view "$TAG" -R "$OWNER/$REPO" > /dev/null 2>&1; then gh release upload "$TAG" "$@" -R "$OWNER/$REPO" --clobber && { echo "data: $TAG updated"; exit 0; }
      else gh release create "$TAG" "$@" -R "$OWNER/$REPO" --title "$TAG" --notes "rolling asset" && { echo "data: $TAG created"; exit 0; }; fi
      sleep $((i * 15))
    done; echo "data.sh: put $TAG failed"; exit 1 ;;
  get)
    TAG=$1 PAT=$2 DIR=$3; export GH_TOKEN=$DATA_TOKEN; mkdir -p "$DIR"
    gh release download "$TAG" -R "$OWNER/$REPO" -p "$PAT" -D "$DIR" --clobber 2> /dev/null && echo "data: $TAG fetched" || echo "data: no $PAT in $TAG" ;;
  *) echo "usage: data.sh pull | push MSG FILE..."; exit 2 ;;
esac
