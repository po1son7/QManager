#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCALES_DIR="$ROOT_DIR/public/locales"
AVAIL_TS="$ROOT_DIR/lib/i18n/available-languages.ts"
LP_LIB="$ROOT_DIR/scripts/usr/lib/qmanager/language_packs.sh"
MANIFEST="$ROOT_DIR/language-packs/manifest.json"
HELPER="$ROOT_DIR/build-lang-pack-helpers.mjs"
OUT_DIR="$ROOT_DIR/qmanager-build/lang"

if [ -t 1 ]; then
  GREEN='\033[0;32m' BOLD='\033[1m' RED='\033[0;31m' YELLOW='\033[0;33m' NC='\033[0m'
else
  GREEN='' BOLD='' RED='' YELLOW='' NC=''
fi

step() { printf "${GREEN}[%s]${NC} %s\n" "$(date +%H:%M:%S)" "$1"; }
warn() { printf "${YELLOW}[%s] WARN:${NC} %s\n" "$(date +%H:%M:%S)" "$1"; }
fail() { printf "${RED}[%s] ERROR:${NC} %s\n" "$(date +%H:%M:%S)" "$1" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: bun run package:lang <code> [version] [--update-manifest <url>] [--skip-check]

Arguments:
  <code>              BCP-47 language code (e.g., it, fr, de). Must be registered
                      in lib/i18n/available-languages.ts as bundled: false.
  [version]           Date-style version string (default: today's UTC date as YYYY.MM.DD).

Options:
  --update-manifest <url>   After building, patch language-packs/manifest.json
                            with the entry, using <url> as the download URL.
                            Replaces any existing entry with the same code.
  --skip-check              Skip 'bun run i18n:check'.

Outputs:
  qmanager-build/lang/qmanager-lang-<code>-<version>.tar.gz
  qmanager-build/lang/qmanager-lang-<code>-<version>.sha256
  A manifest entry JSON block printed to stdout (url = "<FILL_URL>" if not provided).
EOF
}

CODE=""
VERSION=""
UPDATE_URL=""
SKIP_CHECK=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --update-manifest)
      shift
      [ $# -gt 0 ] || fail "--update-manifest requires a URL argument"
      UPDATE_URL="$1"
      ;;
    --skip-check) SKIP_CHECK=1 ;;
    -*) fail "Unknown option: $1" ;;
    *)
      if [ -z "$CODE" ]; then
        CODE="$1"
      elif [ -z "$VERSION" ]; then
        VERSION="$1"
      else
        fail "Unexpected positional argument: $1"
      fi
      ;;
  esac
  shift
done

[ -n "$CODE" ] || { usage; exit 1; }

case "$CODE" in
  *[!a-zA-Z0-9-]*) fail "Invalid code '$CODE': only [A-Za-z0-9-] allowed" ;;
esac

[ -n "$VERSION" ] || VERSION=$(date -u +%Y.%m.%d)
case "$VERSION" in
  [0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]) : ;;
  *) warn "Version '$VERSION' is not date-style YYYY.MM.DD — frontend compareVersion() relies on lexicographic order" ;;
esac

command -v sha256sum >/dev/null 2>&1 || fail "sha256sum not found in PATH"
command -v tar >/dev/null 2>&1 || fail "tar not found in PATH"
command -v bun >/dev/null 2>&1 || fail "bun not found in PATH (required to run scripts/build-lang-pack-helpers.mjs)"

[ -f "$AVAIL_TS" ] || fail "Missing $AVAIL_TS"
[ -f "$LP_LIB" ] || fail "Missing $LP_LIB"
[ -f "$HELPER" ] || fail "Missing helper: $HELPER"
[ -d "$LOCALES_DIR/$CODE" ] || fail "Locale directory does not exist: public/locales/$CODE"

# helper <subcommand> ...args
helper() { bun run "$HELPER" "$@"; }

step "Validating '$CODE' is registered in available-languages.ts..."
set +e
awk -v code="$CODE" '
  /code:[[:space:]]*"/ {
    if (match($0, /"[^"]+"/)) {
      c = substr($0, RSTART+1, RLENGTH-2)
      if (c == code) { found = 1 }
    }
  }
  found && /bundled:[[:space:]]*true/ { bundled = 1; exit }
  found && /bundled:[[:space:]]*false/ { exit }
  END {
    if (!found) exit 2
    if (bundled) exit 3
    exit 0
  }
' "$AVAIL_TS"
rc=$?
set -e
case "$rc" in
  0) : ;;
  2) fail "Code '$CODE' is not registered in lib/i18n/available-languages.ts — add an entry first" ;;
  3) fail "Code '$CODE' is bundled: true — bundled packs ship with the firmware, no tarball needed" ;;
  *) fail "Failed to validate '$CODE' in available-languages.ts (awk rc=$rc)" ;;
esac

REQUIRED_NS=$(sed -n 's/^LP_REQUIRED_NS="\(.*\)"/\1/p' "$LP_LIB")
[ -n "$REQUIRED_NS" ] || fail "Could not parse LP_REQUIRED_NS from $LP_LIB"

step "Validating required namespaces: $REQUIRED_NS"
MISSING_NS=""
for ns in $REQUIRED_NS; do
  if [ ! -f "$LOCALES_DIR/$CODE/$ns.json" ]; then
    MISSING_NS="$MISSING_NS $ns"
  fi
done
if [ -n "$MISSING_NS" ]; then
  fail "Missing required namespace file(s) in $LOCALES_DIR/$CODE/:$MISSING_NS"
fi

step "Validating JSON files parse cleanly..."
for f in "$LOCALES_DIR/$CODE"/*.json; do
  helper validate-json "$f" || fail "Invalid JSON: $f"
done

if [ "$SKIP_CHECK" -eq 0 ]; then
  step "Running 'bun run i18n:check' (warnings OK, errors abort)..."
  CHECK_OUT=$(bun run i18n:check 2>&1) || {
    printf "%s\n" "$CHECK_OUT"
    fail "i18n:check failed — fix errors before building the pack (pass --skip-check to bypass)"
  }
  SUMMARY=$(printf "%s\n" "$CHECK_OUT" | grep -E '^\[i18n:check\]' || true)
  [ -n "$SUMMARY" ] && printf "  %s\n" "$SUMMARY"
else
  warn "Skipping i18n:check (--skip-check)"
fi

mkdir -p "$OUT_DIR"
ARCHIVE_NAME="qmanager-lang-$CODE-$VERSION.tar.gz"
ARCHIVE_PATH="$OUT_DIR/$ARCHIVE_NAME"
SHA_PATH="$OUT_DIR/qmanager-lang-$CODE-$VERSION.sha256"

step "Creating flat tarball: $ARCHIVE_NAME"
rm -f "$ARCHIVE_PATH" "$SHA_PATH"
# --owner/--group pin UID/GID to 0 on GNU tar. BSD tar (macOS) ignores them,
# but the resulting metadata is still valid; the on-device extractor doesn't
# care about ownership.
if tar --help 2>&1 | grep -q -- '--owner'; then
  ( cd "$LOCALES_DIR/$CODE" && tar -czf "$ARCHIVE_PATH" --owner=0 --group=0 -- *.json )
else
  ( cd "$LOCALES_DIR/$CODE" && tar -czf "$ARCHIVE_PATH" -- *.json )
fi

SIZE_BYTES=$(stat -c %s "$ARCHIVE_PATH" 2>/dev/null || stat -f %z "$ARCHIVE_PATH")
SHA256=$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')
printf "%s  %s\n" "$SHA256" "$ARCHIVE_NAME" > "$SHA_PATH"

step "Computing completeness against public/locales/en/..."
EN_KEYS=$(helper count-keys "$LOCALES_DIR/en")
TR_KEYS=$(helper count-keys "$LOCALES_DIR/$CODE")
if [ "$EN_KEYS" -gt 0 ]; then
  COMPLETENESS=$(awk -v t="$TR_KEYS" -v e="$EN_KEYS" 'BEGIN { r = t/e; if (r > 1) r = 1; printf "%.3f", r }')
else
  COMPLETENESS="1.000"
fi

parse_meta() {
  local field="$1"
  awk -v code="$CODE" -v field="$field" '
    /code:[[:space:]]*"/ {
      if (match($0, /"[^"]+"/)) {
        c = substr($0, RSTART+1, RLENGTH-2)
        in_entry = (c == code) ? 1 : 0
      }
    }
    in_entry && $0 ~ field":[[:space:]]*\"" {
      if (match($0, /"[^"]+"[[:space:]]*,?[[:space:]]*$/)) {
        s = substr($0, RSTART+1, RLENGTH-2)
        sub(/",?[[:space:]]*$/, "", s)
        print s
        exit
      }
    }
    in_entry && $0 ~ field":[[:space:]]*(true|false)" {
      if (match($0, /(true|false)/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    }
  ' "$AVAIL_TS"
}

NATIVE_NAME=$(parse_meta native_name)
ENGLISH_NAME=$(parse_meta english_name)
RTL=$(parse_meta rtl)
[ -n "$NATIVE_NAME" ] || fail "Could not parse native_name for '$CODE' from $AVAIL_TS"
[ -n "$ENGLISH_NAME" ] || fail "Could not parse english_name for '$CODE' from $AVAIL_TS"
[ -n "$RTL" ] || fail "Could not parse rtl for '$CODE' from $AVAIL_TS"

URL_VALUE="${UPDATE_URL:-<FILL_URL>}"

ARGS_FILE="$OUT_DIR/.entry-args.$$.json"
cat > "$ARGS_FILE" <<EOF
{
  "code": "$CODE",
  "native_name": "$NATIVE_NAME",
  "english_name": "$ENGLISH_NAME",
  "rtl": $RTL,
  "version": "$VERSION",
  "completeness": $COMPLETENESS,
  "size_bytes": $SIZE_BYTES,
  "sha256": "$SHA256",
  "url": "$URL_VALUE"
}
EOF

ENTRY_JSON=$(helper entry "$ARGS_FILE") || { rm -f "$ARGS_FILE"; fail "Failed to generate entry JSON"; }
ENTRY_FILE="$OUT_DIR/.entry.$$.json"
printf "%s" "$ENTRY_JSON" > "$ENTRY_FILE"

if [ -n "$UPDATE_URL" ]; then
  step "Updating $MANIFEST..."
  [ -f "$MANIFEST" ] || { rm -f "$ARGS_FILE" "$ENTRY_FILE"; fail "Manifest not found: $MANIFEST"; }
  helper update-manifest "$MANIFEST" "$CODE" "$ENTRY_FILE" \
    || { rm -f "$ARGS_FILE" "$ENTRY_FILE"; fail "Failed to update manifest"; }
  step "Manifest updated — review 'git diff language-packs/manifest.json'"
fi

rm -f "$ARGS_FILE" "$ENTRY_FILE"

printf "\n${GREEN}${BOLD}Pack built!${NC} %s (%s bytes, completeness %s)\n" \
  "$ARCHIVE_PATH" "$SIZE_BYTES" "$COMPLETENESS"
printf "SHA-256: %s\n\n" "$SHA256"

printf "${BOLD}Manifest entry:${NC}\n"
printf "%s\n\n" "$ENTRY_JSON"

if [ -z "$UPDATE_URL" ]; then
  cat <<EOF
Next steps:
  1. Upload $ARCHIVE_NAME to a hosted URL (GitHub Release asset recommended).
  2. Re-run with --update-manifest <url> to patch language-packs/manifest.json,
     OR paste the entry above into manifest.json manually.
  3. Commit language-packs/manifest.json to development-home and push.
EOF
fi
