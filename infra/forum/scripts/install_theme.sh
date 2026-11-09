#!/usr/bin/env bash
# Run on the forum server: packages theme-dshgo and installs / updates it on the running Discourse.
#
#   sudo infra/forum/scripts/install_theme.sh
#
# Afterwards fill in "download_url" under Admin → Appearance → Themes → dsh-go 分享码卡片 → Settings.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORUM="$(dirname "$HERE")"
SHARED="${DISCOURSE_SHARED:-/var/discourse/shared/standalone}"
CONTAINER="${DISCOURSE_CONTAINER:-app}"
STAGE="$SHARED/dshgo"

if [[ $EUID -ne 0 ]]; then
  echo "run as root (sudo)" >&2
  exit 1
fi
if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "container $CONTAINER is not running: first cd /var/discourse && ./launcher rebuild app" >&2
  exit 1
fi

install -d -m 0755 "$STAGE"
tar -C "$FORUM" -czf "$STAGE/theme-dshgo.tar.gz" theme-dshgo
chmod 0644 "$STAGE/theme-dshgo.tar.gz"
install -m 0644 "$HERE/install_theme.rb" "$STAGE/install_theme.rb"

docker exec "$CONTAINER" rails runner /shared/dshgo/install_theme.rb /shared/dshgo/theme-dshgo.tar.gz
