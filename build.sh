#!/usr/bin/env bash
# Build everything: the TikZ figures, the three printed copies, and the website.
#
#   ./build.sh          -- figures + PDFs + website
#   ./build.sh pdf      -- figures + PDFs only
#   ./build.sh site     -- figures + website only
set -euo pipefail
cd "$(dirname "$0")"

what="${1:-all}"

./build-figures.sh

CHAPTER=ch02-first-law

build_pdf () {           # $1 = gapmode, $2 = output name
  echo "  pdf: $2"
  quarto render "$CHAPTER.qmd" --to pdf \
    --metadata-file _pdf.yml \
    -M "gapmode:$1" \
    --output "$2.pdf" \
    --quiet
  mkdir -p pdf
  mv "_site/$2.pdf" "pdf/$2.pdf"
}

if [ "$what" = "all" ] || [ "$what" = "pdf" ]; then
  build_pdf student  ch02-student
  build_pdf complete ch02-complete
  build_pdf lecturer ch02-lecturer
fi

if [ "$what" = "all" ] || [ "$what" = "site" ]; then
  echo "  site: _site/"
  quarto render --quiet
fi

echo
echo "done."
[ -d pdf ]   && ls -la pdf/
