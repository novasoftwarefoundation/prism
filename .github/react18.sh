#!/bin/sh
# CI's React 18 leg, for the npm package in the current folder (targets/react, or the
# generator's React fixtures): package.json gets React 18 at exact versions, and
# package-lock.json the package's React 18 lockfile, test/react18/package-lock.json,
# which pins their dependencies too. Then `npm ci` installs React 18.
#
# With --update, it writes that lockfile instead, from the package's own package.json
# and lockfile as they are now, committed or not, and puts both back as they were,
# also when it fails. Run it after a change to the package's version or
# dependencies:
#
#   cd targets/react && npm install --package-lock-only && ../../.github/react18.sh --update
set -eu

if [ "${1-}" = --update ]; then
  saved=$(mktemp -d)
  cp package.json package-lock.json "$saved/"
  trap 'cp "$saved/package.json" "$saved/package-lock.json" . && rm -rf "$saved"' EXIT
fi

npm pkg set \
  devDependencies.react=18.3.1 \
  devDependencies.react-dom=18.3.1 \
  devDependencies.@types/react=18.3.31 \
  devDependencies.@types/react-dom=18.3.7

if [ "${1-}" = --update ]; then
  npm install --package-lock-only --ignore-scripts --no-audit --no-fund
  mkdir -p test/react18
  cp package-lock.json test/react18/package-lock.json
else
  cp test/react18/package-lock.json package-lock.json
fi
