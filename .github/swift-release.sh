#!/bin/sh
# Releases the Swift package: mirrors targets/swift/ as Prism's tag vX.Y.Z has it to the
# root of a clone of the prism-swift repository, commits it as "Prism vX.Y.Z (<prism
# commit>)", tags it vX.Y.Z, the same version as the npm packages, and pushes the branch
# and the tag together.
#
#   .github/swift-release.sh vX.Y.Z <path to a clone of prism-swift>
#
# Run it from the repository root, with Prism's tag vX.Y.Z checked out and checked as
# README → Publish says. The clone must be clean, on the branch the release goes to, and
# up to date with origin. Only the files the tag tracks are mirrored, never ignored or
# untracked ones.
#
# Everything is checked before the clone changes. When the push fails, the clone is put
# back as it was (no commit, no local tag), so the script can simply run again. With
# SWIFT_RELEASE_PUSH=no it commits and tags but pushes nothing, to look first; undo that
# with `git -C <clone> tag -d vX.Y.Z && git -C <clone> reset --hard origin/<branch>`.
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

# The clone: a clone of its own, on a branch, clean, up to date with origin, and
# without the tag, here or on origin.
[ -d "$clone/.git" ] || fail "$clone is not a clone of prism-swift (no .git)"
branch=$(git -C "$clone" symbolic-ref -q --short HEAD) ||
  fail "$clone is not on a branch (detached HEAD): check out the branch the release goes to"
[ -z "$(git -C "$clone" status --porcelain)" ] || fail "$clone has changes or untracked files"
git -C "$clone" fetch -q origin
[ "$(git -C "$clone" rev-parse HEAD)" = "$(git -C "$clone" rev-parse -q --verify "refs/remotes/origin/$branch" || true)" ] ||
  fail "$clone's $branch is not origin/$branch: pull (or reclone) first"
! git -C "$clone" ls-remote --exit-code --tags origin "refs/tags/$version" >/dev/null ||
  fail "origin already has the tag $version: that version is released"
! git -C "$clone" rev-parse -q --verify "refs/tags/$version" >/dev/null ||
  fail "$clone already has the tag $version; delete it there if no release went out (git -C $clone tag -d $version)"

# The mirror: the tag's tracked files of targets/swift/, at the clone's root; everything
# else there but .git removed.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git archive --format=tar "$version" targets/swift | tar -x -C "$work"
rsync -a --delete --exclude .git "$work/targets/swift/" "$clone/"

# Back to the clone as it was, when anything below fails.
restore() {
  git -C "$clone" tag -d "$version" >/dev/null 2>&1 || true
  git -C "$clone" reset -q --hard "origin/$branch"
  git -C "$clone" clean -q -fd
}

git -C "$clone" add -A
if git -C "$clone" diff --cached --quiet; then
  git -C "$clone" commit -q --allow-empty -m "Prism $version ($head)" || { restore; fail "commit failed"; }
else
  git -C "$clone" commit -q -m "Prism $version ($head)" || { restore; fail "commit failed"; }
fi
git -C "$clone" tag -a "$version" -m "Prism $version" || { restore; fail "tag failed"; }

if [ "${SWIFT_RELEASE_PUSH-yes}" = no ]; then
  echo "Committed and tagged $version in $clone; not pushed. Push with:"
  echo "  git -C $clone push --atomic origin $branch $version"
else
  # Both or neither: a tag on origin without its commit on the branch can't happen.
  if git -C "$clone" push --atomic origin "$branch" "$version"; then
    echo "Released prism-swift $version from Prism $head."
  else
    restore
    fail "The push failed; nothing was pushed and the clone is as it was. Fix the cause and run again."
  fi
fi
