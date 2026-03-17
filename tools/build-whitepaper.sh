#!/usr/bin/env bash
# Copyright (c) 2026 Brandon T. Collins
# Licensed under the Creative Commons Attribution 4.0 International License (CC BY 4.0).
# See https://creativecommons.org/licenses/by/4.0/ for details.

set -euo pipefail

echo "== Whitepaper build =="

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 whitepaper-name" >&2
  exit 1
fi

PAPER="$1"
BASE_URL="https://research.c0llins.us/${PAPER}"

# ROOT_DIR is whitepapers/
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${TOOLS_DIR}/.." && pwd)"
PAPER_DIR="${ROOT_DIR}/${PAPER}"
SRC_DIR="${PAPER_DIR}/src"
DIST_ROOT="${PAPER_DIR}/dist"
SRC_MD="${SRC_DIR}/${PAPER}.md"
INDEX_MD="${PAPER_DIR}/index.md"
FILTER_PY="${TOOLS_DIR}/format_filter.py"

echo "Paper:       ${PAPER}"
echo "Root dir:    ${ROOT_DIR}"
echo "Source dir:  ${SRC_DIR}"
echo "Output root: ${DIST_ROOT}"
echo "Index file:  ${INDEX_MD}"
echo "Filter:      ${FILTER_PY}"

if [[ ! -f "$SRC_MD" ]]; then
  echo "Error: source markdown not found: $SRC_MD" >&2
  exit 1
fi

if [[ ! -f "$FILTER_PY" ]]; then
  echo "Error: format filter not found: $FILTER_PY" >&2
  exit 1
fi

# Extract version from line like: **Version:** 1.0.0
MATCH="$(grep -m1 '^\*\*Version:\*\*' "$SRC_MD" || true)"
echo "Debug: raw version line: '$MATCH'"

VERSION="$(printf '%s\n' "$MATCH" \
  | sed -E 's/^\*\*Version:\*\*[[:space:]]*//' \
  | sed -E 's/[[:space:]]+$//')"
echo "Debug: parsed VERSION: '$VERSION'"

if [[ -z "${VERSION:-}" ]]; then
  echo "Error: Could not extract version from $SRC_MD (looking for '**Version:** X.Y.Z')." >&2
  exit 1
fi

# Extract Date from source: **Date:** February 2026
DATE_MATCH="$(grep -m1 '^\*\*Date:\*\*' "$SRC_MD" || true)"
DATE_STR="$(printf '%s\n' "$DATE_MATCH" \
  | sed -E 's/^\*\*Date:\*\*[[:space:]]*//' \
  | sed -E 's/[[:space:]]+$//')"

if [[ -z "${DATE_STR:-}" ]]; then
  DATE_STR="$(date +"%B %Y")"
  echo "Note: **Date:** not found in ${SRC_MD}; using current month/year: ${DATE_STR}"
else
  echo "Debug: parsed DATE: '$DATE_STR'"
fi

mkdir -p "$DIST_ROOT"

PDF_FILE="${PAPER}_v${VERSION}.pdf"
HTML_FILE="${PAPER}_v${VERSION}.html"

PDF_OUT="${DIST_ROOT}/${PDF_FILE}"
HTML_OUT="${DIST_ROOT}/${HTML_FILE}"

echo "PDF will be:   $PDF_OUT"
echo "HTML will be:  $HTML_OUT"

echo "Running pandoc (PDF) with filter..."
python "$FILTER_PY" pdf < "$SRC_MD" \
  | pandoc \
      --from=markdown \
      --pdf-engine=xelatex \
      --toc-depth=3 \
      -V geometry:margin=1in \
      -V fontsize=11pt \
      -o "$PDF_OUT"

PDF_STATUS=$?
echo "Pandoc (PDF) exit status: $PDF_STATUS"

if [[ $PDF_STATUS -ne 0 ]]; then
  echo "Error: pandoc (PDF) exited with status $PDF_STATUS." >&2
  exit $PDF_STATUS
fi

echo "Success: generated '$PDF_OUT'."

echo "Running pandoc (HTML) with filter..."
if python "$FILTER_PY" html < "$SRC_MD" \
  | pandoc \
      --from=markdown \
      --toc-depth=3 \
      -s \
      -o "$HTML_OUT"; then
  echo "Success: generated '$HTML_OUT'."
else
  echo "Warning: HTML generation failed, but PDF is available at '$PDF_OUT'." >&2
fi

# Update metadata and links in index.md if it exists
if [[ -f "$INDEX_MD" ]]; then
  echo "Updating metadata and download links in index.md..."

  # Update Version line in index.md
  sed -i.bak \
    -E "s/^(\*\*Version:\*\*[[:space:]]*)[0-9]+\.[0-9]+\.[0-9]+/\1${VERSION}/" \
    "$INDEX_MD"

  # Update Date line in index.md
  sed -i.bak \
    -E "s/^(\*\*Date:\*\*[[:space:]]*).*/\1${DATE_STR}/" \
    "$INDEX_MD"

  # Update HTML/PDF links to point at current version
  sed -i.bak \
    -E "s|(dist/${PAPER}_v)[0-9]+\.[0-9]+\.[0-9]+(\.html)|\1${VERSION}\2|g; s|(dist/${PAPER}_v)[0-9]+\.[0-9]+\.[0-9]+(\.pdf)|\1${VERSION}\2|g" \
    "$INDEX_MD"

  echo "index.md updated (backup at index.md.bak)."
else
  echo "Note: index.md not found at $INDEX_MD; skipping index updates."
fi

echo
echo "== GitHub Pages URLs =="
echo "PDF:  ${BASE_URL}/dist/${PDF_FILE}"
echo "HTML: ${BASE_URL}/dist/${HTML_FILE}"
