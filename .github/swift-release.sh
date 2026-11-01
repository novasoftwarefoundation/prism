#!/bin/sh
# Releases the Swift package: mirrors targets/swift/ to the root of a clone of the
# prism-swift repository, commits it as "Prism vX.Y.Z (<prism commit>)", tags it vX.Y.Z,
# the same version as the npm packages, and pushes the branch and the tag.
#
#   .github/swift-release.sh vX.Y.Z <path to a clone of prism-swift>
#
# Run it from the repository root, with Prism's tag vX.Y.Z checked out and checked as
# README → Publish says. The clone must be clean, on the branch the release goes to.
# With SWIFT_RELEASE_PUSH=no it commits and tags but pushes nothing, to look first.
set -eu

usage() {
  echo "usage: $0 vX.Y.Z <path to a clone of prism-swift>" >&2
  exit 2
}

[ $# -eq 2 ] || usage
version=$1
clone=$2

case $version in
  v[0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "$version is no version tag (vX.Y.Z)" >&2; exit 2 ;;
esac

fail() {
  echo "$1" >&2
  exit 1
}

[ -f targets/swift/Package.swift ] || fail "run it from the repository root (no targets/swift/Package.swift here)"

# Prism: the tag, checked out, with nothing changed.
head=$(git rev-parse HEAD)
[ "$(git rev-parse -q --verify "refs/tags/$version^{commit}" || true)" = "$head" ] ||
  fail "HEAD is not Prism's tag $version: check it out first (git checkout $version)"
[ -z "$(git status --porcelain)" ] || fail "Prism's tree has changes or untracked files"

# The package's version is Prism's.
grep -q "version: \"${version#v}\"" design/mix.exs ||
  fail "design/mix.exs is not at ${version#v}"

# The clone: a git repository of its own, clean, without the tag yet.
[ -d "$clone/.git" ] || fail "$clone is not a clone of prism-swift (no .git)"
[ -z "$(git -C "$clone" status --porcelain)" ] || fail "$clone has changes or untracked files"
! git -C "$clone" rev-parse -q --verify "refs/tags/$version" >/dev/null ||
  fail "$clone already has the tag $version"

# The mirror: the package at the clone's root, everything else there removed.
rsync -a --delete --exclude .git targets/swift/ "$clone/"

git -C "$clone" add -A
if git -C "$clone" diff --cached --quiet; then
  git -C "$clone" commit -q --allow-empty -m "Prism $version ($head)"
else
  git -C "$clone" commit -q -m "Prism $version ($head)"
fi
git -C "$clone" tag -a "$version" -m "Prism $version"

branch=$(git -C "$clone" symbolic-ref --short HEAD)
if [ "${SWIFT_RELEASE_PUSH-yes}" = no ]; then
  echo "Committed and tagged $version in $clone; not pushed. Push with:"
  echo "  git -C $clone push origin $branch $version"
else
  git -C "$clone" push origin "$branch" "$version"
  echo "Released prism-swift $version from Prism $head."
fi
