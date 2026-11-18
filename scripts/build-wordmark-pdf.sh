#!/usr/bin/env bash
# Rebuild the vector PDF wordmark that xelatex includes in the PDF title block.
# The PDF is committed so rendering a paper needs no SVG conversion step; run
# this script whenever assets/axiom-wordmark.svg changes, then commit both
# files. scripts/check.sh fails if the two drift apart; it passes an output
# path to build its fresh copy elsewhere.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
assets="$root/_extensions/axiom/assets"
output="${1:-$assets/axiom-wordmark.pdf}"

# A fixed epoch keeps cairo's CreationDate stable, so a rebuild with the same
# librsvg and cairo versions is byte-identical.
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-0}" rsvg-convert \
  --format=pdf \
  --output="$output" \
  "$assets/axiom-wordmark.svg"

echo "Wrote $output"
