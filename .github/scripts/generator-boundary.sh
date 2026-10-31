#!/usr/bin/env bash
# Fails when the generator depends on Prism's design, directly or through
# another file, or mentions Prism's values. The generator gets its design only
# from --design or the config.
set -euo pipefail

failed=0

for file in lib/generator/*.ex; do
  deps=$(mix xref graph --source "$file" --format plain)
  if grep -q 'lib/design/' <<<"$deps"; then
    echo "::error file=$file::$file depends on lib/design/:"
    echo "$deps"
    failed=1
  fi
done

if grep -rniE 'nunito|novasoftwarefoundation|0\.1\.7|Prism\.Design|4272EF' \
  lib/generator test/generator; then
  echo "::error::The generator mentions Prism's design or package. Keep Prism-specific values in lib/design/."
  failed=1
fi

exit "$failed"
