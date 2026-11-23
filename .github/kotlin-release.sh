#!/bin/sh
# Releases the Kotlin library to Maven Central, in two steps that never meet: one builds, the
# other signs and uploads.
#
#   .github/kotlin-release.sh --bundle X.Y.Z <out dir>
#   .github/kotlin-release.sh --check X.Y.Z <bundle dir>
#   .github/kotlin-release.sh --digest <bundle dir>
#   .github/kotlin-release.sh vX.Y.Z <bundle dir>
#
# --bundle builds targets/kotlin/ at the version X.Y.Z with Gradle, and writes the bundle's
# files into <out dir> in Maven's layout: the library, its POM and Gradle module, its sources
# and javadoc, each with its .md5 and .sha1. It needs Gradle, a JDK 17 and the Android SDK,
# and no secret: the release runs it in a job that has none, so the Android Gradle plugin,
# Kotlin's and their plugins never run where the signing key and the Central token are (ADR
# 0015). CI runs it too.
#
# --check checks a bundle: it holds exactly the files of .github/maven-files.txt for the
# version, each matches its checksums, and its POM has every field Maven Central requires.
#
# --digest prints the bundle's sha256: of each file's path and sha256, in order. The job that
# builds the bundle gives it as its output, so the job that signs can tell that the bundle it
# got is the one that job built, not one another job of the run put in its place.
#
# vX.Y.Z releases a bundle: it checks that its digest is MAVEN_BUNDLE_SHA256, the building
# job's, and checks it as --check does, before it imports the key; then it signs every file,
# and uploads it
# through the Central Publisher Portal, which publishes it once it validates, then waits until
# it has. It runs no Gradle, only gpg, openssl, zip and curl. Run it from the repository
# root, with Prism's tag vX.Y.Z checked out and checked as README → Publish says. It reads four
# secrets from the environment, and fails before anything else when one is missing:
#
#   MAVEN_CENTRAL_USERNAME, MAVEN_CENTRAL_PASSWORD  the Central Portal user token's two parts
#   MAVEN_SIGNING_KEY                               the ASCII-armored secret key that signs
#   MAVEN_SIGNING_KEY_PASSWORD                      its passphrase
#
# A version Maven Central already has is not uploaded again: the script compares Central's
# POM with the bundle's and stops, so a rerun after a publish is safe. A published version is
# never changed: a broken release is followed by a patch release.
set -eu

central=https://central.sonatype.com/api/v1/publisher
library=targets/kotlin

usage() {
  echo "usage: $0 --bundle X.Y.Z <out dir> | $0 --check X.Y.Z <bundle dir> | $0 --digest <bundle dir> | $0 vX.Y.Z <bundle dir>" >&2
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

# Checks the bundle in $2 for version $1: exactly the files Central requires, each as its
# checksums say, and a POM with the fields Central requires.
check() {
  version=$1 bundle=$2
  expected=$(sed "s/VERSION/$version/g" .github/maven-files.txt)
  found=$(cd "$bundle" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
  [ "$found" = "$expected" ] ||
    fail "$bundle doesn't hold exactly the files of .github/maven-files.txt for $version"
  dir="$bundle/$path/$version"
  for file in "$dir"/*; do
    case $file in *.md5 | *.sha1) continue ;; esac
    [ "$(openssl dgst -md5 "$file" | sed 's/.*= //')" = "$(cat "$file.md5")" ] &&
      [ "$(openssl dgst -sha1 "$file" | sed 's/.*= //')" = "$(cat "$file.sha1")" ] ||
      fail "$file doesn't match its checksums"
  done
  # The release compares this POM with Central's.
  pom="$dir/$artifact-$version.pom"
  for element in groupId artifactId version name description url licenses developers scm connection; do
    grep -q "<$element>" "$pom" || fail "The POM has no <$element>"
  done
  grep -q "<version>$version</version>" "$pom" || fail "The POM is not at $version"
}

# The sha256 of the bundle in $1: of each file's path and sha256, in the paths' order.
digest() {
  [ -d "$1" ] || fail "$1 is no folder: no bundle to take the digest of"
  (cd "$1" && find . -type f | LC_ALL=C sort | while read -r file; do
    printf '%s %s\n' "$(openssl dgst -sha256 "$file" | sed 's/.*= //')" "$file"
  done) | openssl dgst -sha256 | sed 's/.*= //'
}

if [ "${1-}" = --digest ]; then
  [ $# -eq 2 ] || usage
  digest "$2"
  exit 0
fi

if [ "${1-}" = --check ]; then
  [ $# -eq 3 ] || usage
  check "$2" "$3"
  echo "The bundle of $group:$artifact:$2 in $3 has every file and field Maven Central requires."
  exit 0
fi

# The bundle: the release variant at version $2, built into a Maven repository of its own, its
# files copied into $3 in Maven's layout, each with its .md5 and .sha1.
if [ "${1-}" = --bundle ]; then
  [ $# -eq 3 ] || usage
  version=$2 out=$3
  repo=$(mktemp -d)
  gradle -p "$library" --no-daemon --quiet publishToMavenLocal \
    -Pversion="$version" -Dmaven.repo.local="$repo"
  dir="$out/$path/$version"
  mkdir -p "$dir"
  for file in "$repo/$path/$version"/*; do
    cp "$file" "$dir/"
  done
  for file in "$dir"/*; do
    openssl dgst -md5 "$file" | sed 's/.*= //' > "$file.md5"
    openssl dgst -sha1 "$file" | sed 's/.*= //' > "$file.sha1"
  done
  echo "Built the bundle of $group:$artifact:$version in $out (unsigned)."
  exit 0
fi

[ $# -eq 2 ] || usage
tag=$1 bundle=$2
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

# The bundle the job without secrets built, and no other: its digest is that job's output.
[ -n "${MAVEN_BUNDLE_SHA256-}" ] ||
  fail "MAVEN_BUNDLE_SHA256 is not set: the release gives it from maven-bundle's output"
actual=$(digest "$bundle")
[ "$actual" = "$MAVEN_BUNDLE_SHA256" ] ||
  fail "The bundle's digest is $actual, not maven-bundle's $MAVEN_BUNDLE_SHA256: not signing it"

# As Central requires it.
check "$version" "$bundle"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A version Central has is released: its POM must be the bundle's.
published="https://repo1.maven.org/maven2/$path/$version/$artifact-$version.pom"
if curl -sSfL -o "$work/published.pom" "$published" 2>/dev/null; then
  cmp -s "$work/published.pom" "$pom" ||
    fail "Maven Central has $group:$artifact:$version with another POM than $tag builds; release a patch version"
  echo "Maven Central already has $group:$artifact:$version from $tag; nothing to upload."
  exit 0
fi

# The signing key, in a gpg home of its own that goes with the work folder; the signatures,
# in a copy of the bundle there.
gpg_home="$work/gnupg"
mkdir -m 700 "$gpg_home"
printf '%s\n' "$MAVEN_SIGNING_KEY" | gpg --homedir "$gpg_home" --batch --quiet --import
gpg --homedir "$gpg_home" --batch --list-secret-keys --with-colons | grep -q '^sec' ||
  fail "MAVEN_SIGNING_KEY holds no secret key"
cp -R "$bundle" "$work/bundle"
for file in "$work/bundle/$path/$version"/*; do
  case $file in *.md5 | *.sha1) continue ;; esac
  printf '%s' "$MAVEN_SIGNING_KEY_PASSWORD" |
    gpg --homedir "$gpg_home" --batch --quiet --pinentry-mode loopback --passphrase-fd 0 \
      --armor --detach-sign --output "$file.asc" "$file"
done
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
