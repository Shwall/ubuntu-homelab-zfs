#!/usr/bin/env bash
# Builds a NoCloud seed ISO (volume label "cidata") from user-data + meta-data.
# Attach it as a 2nd CD/disk (VM) or dd it to a spare USB stick, boot the Ubuntu
# Server ISO, and append "autoinstall" to the kernel command line (press 'e' in GRUB).
set -euo pipefail
cd "$(dirname "$0")"
OUT="${1:-seed.iso}"

if command -v cloud-localds >/dev/null; then
  cloud-localds "$OUT" user-data meta-data
elif command -v genisoimage >/dev/null; then
  genisoimage -output "$OUT" -volid cidata -joliet -rock user-data meta-data
elif command -v xorriso >/dev/null; then
  xorriso -as mkisofs -o "$OUT" -V cidata -J -r user-data meta-data
else
  echo "Install cloud-image-utils, genisoimage or xorriso" >&2; exit 1
fi
echo "Built $OUT"
