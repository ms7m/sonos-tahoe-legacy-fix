#!/bin/bash
# Patch Sonos for macOS 17.2.3 (build 90.0.79210) to suppress its false
# "firewall setting has changed" screen on macOS Tahoe and later.
#
# This leaves /Applications/Sonos.app untouched. It creates a separately
# signed copy at ~/Applications/Sonos Patched.app instead.

set -euo pipefail

SOURCE_APP="${1:-/Applications/Sonos.app}"
OUTPUT_APP="${2:-$HOME/Applications/Sonos Patched.app}"
EXPECTED_VERSION="17.2.3"
EXPECTED_BUILD="90.0.79210"

fail() {
  echo "error: $*" >&2
  exit 1
}

for tool in ditto lipo codesign otool plutil xxd dd; do
  command -v "$tool" >/dev/null || fail "missing required tool: $tool"
done

[[ -d "$SOURCE_APP" ]] || fail "Sonos app not found: $SOURCE_APP"
[[ ! -e "$OUTPUT_APP" ]] || fail "refusing to overwrite existing output: $OUTPUT_APP"

INFO="$SOURCE_APP/Contents/Info.plist"
BIN="$SOURCE_APP/Contents/MacOS/Sonos"
[[ -f "$INFO" && -f "$BIN" ]] || fail "not a Sonos desktop app bundle: $SOURCE_APP"

version="$(plutil -extract CFBundleShortVersionString raw "$INFO")"
build="$(plutil -extract CFBundleVersion raw "$INFO")"
[[ "$version" == "$EXPECTED_VERSION" && "$build" == "$EXPECTED_BUILD" ]] || \
  fail "unsupported Sonos build $version ($build); this script is intentionally limited to $EXPECTED_VERSION ($EXPECTED_BUILD)"

# The method exists only in the affected controller. Its two code slices are
# checked before modification, so an unexpectedly repackaged build fails safe.
strings -a "$BIN" | grep -F 'SMSCLibLimitedContentViewController' >/dev/null || fail "expected controller class not found"
strings -a "$BIN" | grep -F 'shouldShowTahoeS1FirewallMessage' >/dev/null || fail "expected Tahoe firewall method not found"

mkdir -p "$(dirname "$OUTPUT_APP")"
ditto "$SOURCE_APP" "$OUTPUT_APP"

PATCHED_BIN="$OUTPUT_APP/Contents/MacOS/Sonos"
TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/sonos-patch.XXXXXX")"
trap 'rm -rf "$TMPDIR"' EXIT

lipo -thin x86_64 "$PATCHED_BIN" -output "$TMPDIR/Sonos.x86_64"
lipo -thin arm64 "$PATCHED_BIN" -output "$TMPDIR/Sonos.arm64"

# Start of -[SMSCLibLimitedContentViewController shouldShowTahoeS1FirewallMessage]
[[ "$(xxd -p -l 6 -s $((0x7ea68)) "$TMPDIR/Sonos.x86_64")" == "554889e55350" ]] || fail "unexpected Intel method bytes"
[[ "$(xxd -p -l 12 -s $((0x6d8f4)) "$TMPDIR/Sonos.arm64")" == "f44fbea9fd7b01a9fd430091" ]] || fail "unexpected Apple-silicon method bytes"

# Replace only that method with `return false`:
# x86_64: xor eax,eax; ret    arm64: mov w0,#0; ret
printf '\x31\xc0\xc3' | dd of="$TMPDIR/Sonos.x86_64" bs=1 seek=$((0x7ea68)) conv=notrunc status=none
printf '\x00\x00\x80\x52\xc0\x03\x5f\xd6' | dd of="$TMPDIR/Sonos.arm64" bs=1 seek=$((0x6d8f4)) conv=notrunc status=none
lipo -create "$TMPDIR/Sonos.x86_64" "$TMPDIR/Sonos.arm64" -output "$PATCHED_BIN"

# Modifying Mach-O code invalidates the vendor signature. Re-sign the copy
# locally; the original bundle remains vendor-signed and unchanged.
codesign --force --deep --sign - "$OUTPUT_APP"
codesign --force --deep --sign - "$OUTPUT_APP"
codesign --verify --deep --strict --verbose=2 "$OUTPUT_APP"

echo "Patched copy created: $OUTPUT_APP"
echo "Quit any running Sonos instance, then open this patched copy."
