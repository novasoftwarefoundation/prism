#!/usr/bin/env bash
# Fails when the generator depends on Prism's design, directly or through
# another file, or mentions Prism's values. The generator gets its design only
# from --design or the config.
set -euo pipefail

failed=0

while IFS= read -r file; do
  deps=$(mix xref graph --source "$file" --format plain)
  if grep -q 'lib/design/' <<<"$deps"; then
    echo "::error file=$file::$file depends on lib/design/:"
    echo "$deps"
    failed=1
  fi
done < <(find lib/generator -name '*.ex' | sort)

# `lib/design` also catches reading the design's files by path.
if grep -rniE 'nunito|novasoftwarefoundation|0\.1\.7|Prism\.Design|lib/design|4272EF' \
  lib/generator test/generator; then
  echo "::error::The generator mentions Prism's design or package. Keep Prism-specific values in lib/design/."
  failed=1
fi

exit "$failed"
