#!/usr/bin/env bash
# Run on the forum server: writes the settings under settings/ into the running Discourse.
#
#   sudo infra/forum/scripts/apply.sh
#
# Re-runnable. Requires the container to have been built with containers/app.yml and to be running (./launcher rebuild app).
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
if grep -q '<<FILL' "$FORUM/settings/site_settings.yml"; then
  echo "note: site_settings.yml still contains <<FILL placeholders; those items will be skipped" >&2
fi

install -d -m 0755 "$STAGE"
install -m 0644 "$HERE/apply_settings.rb" "$STAGE/apply_settings.rb"
install -m 0644 "$FORUM/settings/site_settings.yml" "$STAGE/site_settings.yml"
install -m 0644 "$FORUM/settings/community.yml" "$STAGE/community.yml"
if [[ -f "$FORUM/settings/secrets.yml" ]]; then
  # rails in the container runs as the discourse user and must be able to read this; deleted right after the run
  install -m 0644 "$FORUM/settings/secrets.yml" "$STAGE/secrets.yml"
fi
trap 'rm -f "$STAGE/secrets.yml"' EXIT

docker exec "$CONTAINER" rails runner /shared/dshgo/apply_settings.rb /shared/dshgo
