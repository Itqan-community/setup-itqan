#!/usr/bin/env bash
# shellcheck disable=SC2153  # VERSION, OS, ARCH and DIR come from action.yml
# Steps of the setup-itqan action (action.yml). Runs in bash on every runner OS, Git Bash on
# Windows.
#
#   setup.sh resolve   reads VERSION, writes version, os, arch, dir and binary to $GITHUB_OUTPUT
#   setup.sh download  reads VERSION, OS, ARCH and DIR; downloads the binary into DIR as
#                      itqan (itqan.exe on Windows) after checking it against SHA256SUMS
set -euo pipefail

REPO="${ITQAN_CLI_REPO:-Itqan-community/itqan-cli}"

fail() {
  echo "::error::$1"
  exit 1
}

resolve() {
  local version="${VERSION#v}"
  if [ -z "$version" ] || [ "$version" = latest ]; then
    # The /releases/latest page redirects to the latest final release's tag. Unlike the REST
    # API, it has no rate limit and needs no token. Only the redirect is read: the release
    # page it points to is slow to render and sometimes times out.
    local url
    url="$(curl -fsS --retry 5 -o /dev/null -w '%{redirect_url}' "https://github.com/$REPO/releases/latest")" \
      || fail "Could not look up the latest itqan release"
    version="${url##*/tag/v}"
    [ "$version" != "$url" ] || fail "Could not read the latest itqan version from $url"
  fi

  local os arch ext=""
  case "$RUNNER_OS" in
    Linux) os=linux ;;
    macOS) os=macos ;;
    Windows) os=windows; ext=".exe" ;;
    *) fail "setup-itqan doesn't support $RUNNER_OS runners" ;;
  esac
  case "$RUNNER_ARCH" in
    X64) arch=x86_64 ;;
    ARM64) arch=arm64 ;;
    *) fail "setup-itqan doesn't support $RUNNER_ARCH runners" ;;
  esac
  if [ "$os-$arch" = windows-arm64 ]; then
    fail "itqan has no Windows arm64 binary; use an x64 Windows runner"
  fi

  {
    echo "version=$version"
    echo "os=$os"
    echo "arch=$arch"
    echo "dir=$RUNNER_TOOL_CACHE/itqan/$version/$arch"
    echo "binary=$RUNNER_TOOL_CACHE/itqan/$version/$arch/itqan$ext"
  } >> "$GITHUB_OUTPUT"
}

sha256() {
  if command -v sha256sum > /dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

download() {
  local ext=""
  [ "$OS" = windows ] && ext=".exe"
  local name="itqan-$VERSION-$OS-$ARCH$ext"
  local target="$DIR/itqan$ext"
  if [ -x "$target" ]; then
    echo "itqan $VERSION is already in $DIR"
    return
  fi

  local base="https://github.com/$REPO/releases/download/v$VERSION"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL --retry 5 -o "$tmp/SHA256SUMS" "$base/SHA256SUMS" \
    || fail "Could not download SHA256SUMS for itqan $VERSION. Is $VERSION a released version? See https://github.com/$REPO/releases"
  local expected
  expected="$(awk -v n="$name" '$2 == n || $2 == "*" n { print $1 }' "$tmp/SHA256SUMS")"
  [ -n "$expected" ] || fail "itqan $VERSION has no $name binary"

  echo "Downloading $base/$name"
  curl -fsSL --retry 5 -o "$tmp/$name" "$base/$name" || fail "Could not download $name"
  local actual
  actual="$(sha256 "$tmp/$name")"
  [ "$actual" = "$expected" ] || fail "Checksum mismatch for $name: expected $expected, got $actual"

  mkdir -p "$DIR"
  chmod +x "$tmp/$name"
  mv "$tmp/$name" "$target"
  rm -rf "$tmp"
}

case "${1:-}" in
  resolve) resolve ;;
  download) download ;;
  *) fail "usage: setup.sh resolve|download" ;;
esac
