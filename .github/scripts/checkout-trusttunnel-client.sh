#!/usr/bin/env bash
set -euo pipefail

repo="${TRUSTTUNNEL_CLIENT_REPO:-https://github.com/TrustTunnel/TrustTunnelClient.git}"
ref="${TRUSTTUNNEL_CLIENT_REF:-e365309c7d6ad92a0f92096e613f9acd06fd1d5a}"
dest="${TRUSTTUNNEL_CLIENT_SOURCE_DIR:-$PWD/.deps/TrustTunnelClient}"

if [ -d "$dest/.git" ]; then
  git -C "$dest" fetch --depth 1 origin "$ref"
  git -C "$dest" checkout --force FETCH_HEAD
else
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  git init "$dest"
  git -C "$dest" remote add origin "$repo"
  git -C "$dest" fetch --depth 1 origin "$ref"
  git -C "$dest" checkout --force FETCH_HEAD
fi

echo "TrustTunnelClient source: $dest"
git -C "$dest" rev-parse HEAD

if [ -n "${GITHUB_ENV:-}" ]; then
  {
    echo "TRUSTTUNNEL_CLIENT_SOURCE_DIR=$dest"
    echo "TRUSTTUNNEL_CLIENT_REF=$ref"
  } >> "$GITHUB_ENV"
fi
