#!/usr/bin/env bash
set -euo pipefail

if [ -n "${RELEASE_TAG:-}" ]; then
  tag="$RELEASE_TAG"
else
  tag="$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.1")"
fi

echo "TAG=$tag">> "$GITHUB_ENV"
echo "Tag: $tag"
