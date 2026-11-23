#!/bin/sh
# Releases the Kotlin library to Maven Central: builds targets/kotlin/ as Prism's tag vX.Y.Z
# has it, at the version X.Y.Z, signs every file, adds its checksums, and uploads the bundle
# through the Central Publisher Portal, which publishes it once it validates.
#
#   .github/kotlin-release.sh vX.Y.Z
#   .github/kotlin-release.sh --bundle X.Y.Z <out dir>
#
# Run it from the repository root, with Prism's tag vX.Y.Z checked out and checked as
# README → Publish says, and Gradle, a JDK 17, the Android SDK, gpg, openssl, zip and curl
# on the PATH. It reads four secrets from the environment, and fails before anything else
# when one is missing:
#
#   MAVEN_CENTRAL_USERNAME, MAVEN_CENTRAL_PASSWORD  the Central Portal user token's two parts
#   MAVEN_SIGNING_KEY                               the ASCII-armored secret key that signs
#   MAVEN_SIGNING_KEY_PASSWORD                      its passphrase
#
# A version Maven Central already has is not uploaded again: the script compares its POM
# with the one it builds and stops, so a rerun after a publish is safe. A published version
# is never changed: a broken release is followed by a patch release.
#
# --bundle builds the bundle's files in <out dir> as the release does, with their checksums
# and without signatures, for any version, with no secrets and no upload: CI checks with it
# that the bundle has every file and the POM every field Maven Central requires.
set -eu

central=https://central.sonatype.com/api/v1/publisher
library=targets/kotlin

usage() {
  echo "usage: $0 vX.Y.Z | $0 --bundle X.Y.Z <out dir>" >&2
  exit 2
}

fail() {
  echo "$1" >&2
  exit 1
}

[ -f "$library/build.gradle.kts" ] || fail "run it from the repository root (no $library/build.gradle.kts here)"

# The library's coordinates, from its gradle.properties and settings.
group=$(sed -n 's/^group=//p' "$library/gradle.properties")
artifact=$(sed -n 's/^rootProject.name = "\(.*\)"$/\1/p' "$library/settings.gradle.kts")
[ -n "$group" ] && [ -n "$artifact" ] || fail "no group in $library/gradle.properties or no rootProject.name in its settings"
path=$(printf '%s' "$group" | tr . /)/$artifact

# Builds the release variant at version $1 into a Maven repository and copies its files, the
# library, its POM and Gradle module, its sources and javadoc, into $2 in Maven's layout, each
# with its .md5 and .sha1 and, when $3 is a gpg home with the signing key, its .asc.
bundle() {
  version=$1 out=$2 gpg_home=${3-}
  repo=$(mktemp -d)
  gradle -p "$library" --no-daemon --quiet publishToMavenLocal \
    -Pversion="$version" -Dmaven.repo.local="$repo"
  dir="$out/$path/$version"
  mkdir -p "$dir"
  for file in "$repo/$path/$version"/*; do
    cp "$file" "$dir/"
  done
  rm -rf "$repo"
  for file in "$dir"/*; do
    openssl dgst -md5 "$file" | sed 's/.*= //' > "$file.md5"
    openssl dgst -sha1 "$file" | sed 's/.*= //' > "$file.sha1"
    if [ -n "$gpg_home" ]; then
      printf '%s' "$MAVEN_SIGNING_KEY_PASSWORD" |
        gpg --homedir "$gpg_home" --batch --quiet --pinentry-mode loopback --passphrase-fd 0 \
          --armor --detach-sign --output "$file.asc" "$file"
    fi
  done
}

if [ "${1-}" = --bundle ]; then
  [ $# -eq 3 ] || usage
  bundle "$2" "$3"
  echo "Built the bundle of $group:$artifact:$2 in $3 (unsigned)."
  exit 0
fi

[ $# -eq 1 ] || usage
tag=$1
case $tag in
  v[0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "$tag is no version tag (vX.Y.Z)" >&2; exit 2 ;;
esac
version=${tag#v}

# The secrets, before anything else.
for name in MAVEN_CENTRAL_USERNAME MAVEN_CENTRAL_PASSWORD MAVEN_SIGNING_KEY MAVEN_SIGNING_KEY_PASSWORD; do
  eval "value=\${$name-}"
  [ -n "$value" ] ||
    fail "$name is not set: the release reads it from novasoftwarefoundation/prism's Actions secret $name (README → Publish → One-time release setup)"
done

# Prism: the tag, checked out, with nothing changed, at the library's version.
head=$(git rev-parse HEAD)
[ "$(git rev-parse -q --verify "refs/tags/$tag^{commit}" || true)" = "$head" ] ||
  fail "HEAD is not Prism's tag $tag: check it out first (git checkout $tag)"
[ -z "$(git status --porcelain)" ] || fail "Prism's tree has changes or untracked files"
grep -q "version: \"$version\"" design/mix.exs || fail "design/mix.exs is not at $version"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A version Central has is released: its POM must be the one this tag builds.
published="https://repo1.maven.org/maven2/$path/$version/$artifact-$version.pom"
if curl -sSfL -o "$work/published.pom" "$published" 2>/dev/null; then
  bundle "$version" "$work/check"
  cmp -s "$work/published.pom" "$work/check/$path/$version/$artifact-$version.pom" ||
    fail "Maven Central has $group:$artifact:$version with another POM than $tag builds; release a patch version"
  echo "Maven Central already has $group:$artifact:$version from $tag; nothing to upload."
  exit 0
fi

# The signing key, in a gpg home of its own that goes with the work folder.
gpg_home="$work/gnupg"
mkdir -m 700 "$gpg_home"
printf '%s\n' "$MAVEN_SIGNING_KEY" | gpg --homedir "$gpg_home" --batch --quiet --import
gpg --homedir "$gpg_home" --batch --list-secret-keys --with-colons | grep -q '^sec' ||
  fail "MAVEN_SIGNING_KEY holds no secret key"

bundle "$version" "$work/bundle" "$gpg_home"
(cd "$work/bundle" && zip -qr "$work/bundle.zip" .)

token=$(printf '%s:%s' "$MAVEN_CENTRAL_USERNAME" "$MAVEN_CENTRAL_PASSWORD" | base64 | tr -d '\n')
deployment=$(curl -sS --fail-with-body -X POST -H "Authorization: Bearer $token" \
  -F "bundle=@$work/bundle.zip;type=application/octet-stream" \
  "$central/upload?name=$artifact-$version&publishingType=AUTOMATIC") ||
  fail "The upload failed: $deployment"
echo "Uploaded $group:$artifact:$version as deployment $deployment; waiting for Central to publish it."

# Central validates the bundle, then publishes it; that takes minutes, sometimes longer.
tries=0
while :; do
  status=$(curl -sS --fail-with-body -X POST -H "Authorization: Bearer $token" \
    "$central/status?id=$deployment") || fail "The status request failed: $status"
  state=$(printf '%s' "$status" | sed -n 's/.*"deploymentState" *: *"\([A-Z]*\)".*/\1/p')
  case $state in
    PUBLISHED)
      echo "Released $group:$artifact:$version from Prism $head."
      exit 0
      ;;
    FAILED)
      fail "Central refused deployment $deployment: $status"
      ;;
  esac
  tries=$((tries + 1))
  [ $tries -lt 120 ] ||
    fail "Deployment $deployment is still $state after an hour; check it in the Central Portal before running again"
  sleep 30
done
