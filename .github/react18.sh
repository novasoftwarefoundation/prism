#!/bin/sh
# CI's React 18 leg, for the npm package in the current folder (targets/react, or the
# generator's React fixtures): package.json gets React 18 at exact versions, and
# package-lock.json the package's React 18 lockfile, test/react18/package-lock.json,
# which pins their dependencies too. Then `npm ci` installs React 18.
#
# With --update, it writes that lockfile instead, from the package's own lockfile,
# and leaves package.json and package-lock.json as they were. Run it after a change
# to the package's dependencies:
#
#   cd targets/react && ../../.github/react18.sh --update
set -eu

npm pkg set \
  devDependencies.react=18.3.1 \
  devDependencies.react-dom=18.3.1 \
  devDependencies.@types/react=18.3.31 \
  devDependencies.@types/react-dom=18.3.7

if [ "${1-}" = --update ]; then
  npm install --package-lock-only --ignore-scripts --no-audit --no-fund
  mkdir -p test/react18
  cp package-lock.json test/react18/package-lock.json
  git checkout -- package.json package-lock.json
else
  cp test/react18/package-lock.json package-lock.json
fi
