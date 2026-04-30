#!/bin/sh
# =============================================================================
# QManager Bootstrap Installer
# =============================================================================
# Downloads a release tarball from a configurable mirror (default: Gitee for
# mainland reachability), verifies SHA-256, extracts, and runs install.sh or
# uninstall.sh. HTTP via curl only.
#
# Usage:
#   sh qmanager-installer.sh [OPTIONS]
#
# Options:
#   --uninstall             Run uninstall.sh instead of install.sh
#   --tag <tag>             Use an explicit release tag (e.g., v0.1.14)
#   --channel <ch>          Release channel: stable|prerelease|any (default: any)
#   --mirror <m>            gitee | github | github_proxy (default: gitee)
#   --repo <owner/repo>     GitHub owner/repo (used when mirror is github*)
#   --gitee-repo <o/r>      Gitee owner/repo (used when mirror is gitee)
#   -h, --help              Show this help
#
# Environment overrides:
#   QMANAGER_TAG            Same as --tag
#   QMANAGER_CHANNEL        Same as --channel
#   QMANAGER_MIRROR         Same as --mirror
#   QMANAGER_REPO           GitHub owner/repo (default: po1son7/QManager)
#   QMANAGER_GITEE_REPO     Gitee owner/repo (default: aowu2048/QManager)
# =============================================================================

set -e

MIRROR="${QMANAGER_MIRROR:-gitee}"
GITEE_REPO="${QMANAGER_GITEE_REPO:-aowu2048/QManager}"
REPO="${QMANAGER_REPO:-po1son7/QManager}"
TAG="${QMANAGER_TAG:-}"
CHANNEL="${QMANAGER_CHANNEL:-any}"
ACTION="install"

usage() {
    cat <<'EOF'
QManager bootstrap installer

Usage:
  sh qmanager-installer.sh [OPTIONS]

Options:
  --uninstall           Run uninstall.sh instead of install.sh
  --tag <tag>           Use an explicit release tag (e.g., v0.1.14)
  --channel <ch>        Release channel: stable | prerelease | any (default: any)
  --mirror <m>          gitee | github | github_proxy (default: gitee)
  --repo <owner/repo>   GitHub owner/repo for github / github_proxy (default: po1son7/QManager)
  --gitee-repo <o/r>    Gitee owner/repo when using gitee mirror
  -h, --help            Show this help

Environment overrides:
  QMANAGER_TAG          Same as --tag
  QMANAGER_CHANNEL      Same as --channel
  QMANAGER_MIRROR       Same as --mirror
  QMANAGER_REPO         GitHub owner/repo
  QMANAGER_GITEE_REPO   Gitee owner/repo

Examples (mainland — Gitee raw + gitee mirror):
  curl -fsSL -o /tmp/qmanager-installer.sh \\
    "https://gitee.com/aowu2048/QManager/raw/main/qmanager-installer.sh" && sh /tmp/qmanager-installer.sh

Examples (GitHub via ghproxy — if Gitee is outdated):
  curl -fsSL -o /tmp/qmanager-installer.sh \\
    "https://ghproxy.net/https://raw.githubusercontent.com/po1son7/QManager/main/qmanager-installer.sh" \\
    && sh /tmp/qmanager-installer.sh --mirror github_proxy

  sh /tmp/qmanager-installer.sh --mirror github --channel stable
  sh /tmp/qmanager-installer.sh --uninstall
EOF
}

# --- Arg parsing -------------------------------------------------------------

while [ "$#" -gt 0 ]; do
    case "$1" in
        --uninstall)
            ACTION="uninstall"
            ;;
        --tag)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --tag" >&2; exit 1; }
            TAG="$1"
            ;;
        --channel)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --channel" >&2; exit 1; }
            CHANNEL="$1"
            ;;
        --mirror)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --mirror" >&2; exit 1; }
            MIRROR="$1"
            ;;
        --repo)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --repo" >&2; exit 1; }
            REPO="$1"
            ;;
        --gitee-repo)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --gitee-repo" >&2; exit 1; }
            GITEE_REPO="$1"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

case "$MIRROR" in
    gitee|github|github_proxy) ;;
    *)
        echo "Invalid --mirror: $MIRROR (expected: gitee, github, github_proxy)" >&2
        exit 1
        ;;
esac

# --- Dependency checks -------------------------------------------------------

if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required but not installed." >&2
    echo "Install it first:  opkg update && opkg install curl ca-bundle" >&2
    exit 1
fi

if ! command -v sha256sum >/dev/null 2>&1; then
    echo "sha256sum is required but not available" >&2
    exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
    echo "tar is required but not available" >&2
    exit 1
fi

case "$CHANNEL" in
    stable|prerelease|any) ;;
    *)
        echo "Invalid --channel: $CHANNEL (expected: stable, prerelease, any)" >&2
        exit 1
        ;;
esac

# --- HTTP helpers (curl-only) ------------------------------------------------

fetch_text() {
    curl -fsSL --max-time 30 --connect-timeout 10 "$1" 2>/dev/null
}

download_file() {
    _url="$1"
    _out="$2"
    curl -fsSL --max-time 600 --connect-timeout 15 -o "$_out" "$_url"
}

releases_api_url() {
    case "$MIRROR" in
        gitee)
            echo "https://gitee.com/api/v5/repos/${GITEE_REPO}/releases?per_page=50&direction=desc"
            ;;
        github_proxy)
            echo "https://ghproxy.net/https://api.github.com/repos/${REPO}/releases?per_page=50"
            ;;
        *)
            echo "https://api.github.com/repos/${REPO}/releases?per_page=50"
            ;;
    esac
}

download_base_url() {
    _t="$1"
    case "$MIRROR" in
        gitee)
            echo "https://gitee.com/${GITEE_REPO}/releases/download/${_t}"
            ;;
        github_proxy)
            echo "https://ghproxy.net/https://github.com/${REPO}/releases/download/${_t}"
            ;;
        *)
            echo "https://github.com/${REPO}/releases/download/${_t}"
            ;;
    esac
}

resolve_tag_from_json() {
    _json="$1"
    _channel="$2"
    printf '%s' "$_json" | jq -r --arg ch "$_channel" '
      if $ch == "any" then
        .[0].tag_name // empty
      elif $ch == "prerelease" then
        ([ .[] | select(.prerelease == true) ] | .[0].tag_name // empty)
      else
        ([ .[] | select((.prerelease // false) == false) ] | .[0].tag_name // empty)
      end
    '
}

# --- Tag resolution ----------------------------------------------------------

if [ -z "$TAG" ]; then
    if ! command -v jq >/dev/null 2>&1; then
        echo "jq is required to resolve the latest release tag." >&2
        echo "Install: opkg update && opkg install jq" >&2
        exit 1
    fi

    case "$MIRROR" in
        gitee)
            echo "Resolving latest $CHANNEL release from Gitee $GITEE_REPO..."
            ;;
        *)
            echo "Resolving latest $CHANNEL release from GitHub $REPO..."
            ;;
    esac

    API=$(releases_api_url)
    JSON="$(fetch_text "$API" || true)"

    if [ -z "$JSON" ]; then
        echo "Failed to fetch release metadata from $API" >&2
        exit 1
    fi

    TAG=$(resolve_tag_from_json "$JSON" "$CHANNEL")
fi

if [ -z "$TAG" ]; then
    echo "Failed to resolve a release tag from channel '$CHANNEL'" >&2
    if [ "$CHANNEL" = "stable" ]; then
        echo "There may be no stable releases published yet — try --channel prerelease or --channel any" >&2
    fi
    exit 1
fi

echo "Using release: $TAG"

BASE=$(download_base_url "$TAG")
WORK_DIR="/tmp/qmanager-bootstrap"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

cd "$WORK_DIR"

echo "Downloading qmanager.tar.gz..."
if ! download_file "$BASE/qmanager.tar.gz" qmanager.tar.gz; then
    echo "Failed to download qmanager.tar.gz from $BASE" >&2
    exit 1
fi

echo "Downloading sha256sum.txt..."
if ! download_file "$BASE/sha256sum.txt" sha256sum.txt; then
    echo "Failed to download sha256sum.txt from $BASE" >&2
    exit 1
fi

echo "Verifying SHA-256..."
sha256sum -c sha256sum.txt

echo "Extracting..."
if tar xzf qmanager.tar.gz 2>/dev/null; then
    :
elif command -v gzip >/dev/null 2>&1; then
    gzip -dc qmanager.tar.gz | tar xf -
else
    echo "Unable to extract qmanager.tar.gz (tar -z and gzip both missing)" >&2
    exit 1
fi

[ -d "$WORK_DIR/qmanager_install" ] || {
    echo "Extraction produced no qmanager_install directory — archive layout invalid" >&2
    exit 1
}

if [ "$ACTION" = "uninstall" ]; then
    exec sh "$WORK_DIR/qmanager_install/uninstall.sh"
else
    exec sh "$WORK_DIR/qmanager_install/install.sh"
fi
