#!/usr/bin/env bash
# Build everything: the TikZ figures, the three printed copies of the combined
# notes, and the website (notes with gaps + completed notes).
#
#   ./build.sh          -- figures + PDFs + website
#   ./build.sh pdf      -- figures + PDFs only
#   ./build.sh site     -- figures + website only
set -euo pipefail
cd "$(dirname "$0")"

what="${1:-all}"

./build-figures.sh

# All chapters live in chapters/_chNN-*.qmd and are combined into ONE document,
# notes.qmd. The printed copies are built from it in three gap modes.
# $1 = gapmode, $2 = output name, $3 = destination directory.
# pdf/ is copied into the published site by _quarto.yml, so anything written
# there is PUBLIC. The presenter copy goes to presenter/ instead, which is not
# a Quarto resource and never reaches _site.
build_pdf () {
  echo "  pdf: $3/$2"
  quarto render notes.qmd --to pdf \
    --metadata-file _pdf.yml \
    -M "gapmode:$1" \
    --output "$2.pdf" \
    --quiet
  mkdir -p "$3"
  mv "_site/$2.pdf" "$3/$2.pdf"
}

if [ "$what" = "all" ] || [ "$what" = "pdf" ]; then
  build_pdf student  notes-with-gaps  pdf
  build_pdf complete notes-complete   pdf
  build_pdf lecturer notes-presenter  presenter
fi

if [ "$what" = "all" ] || [ "$what" = "site" ]; then
  echo "  site: _site/  (lecture view -- gaps start covered)"
  quarto render --quiet
fi

echo
echo "done."
[ -d pdf ]       && ls -la pdf/
[ -d presenter ] && ls -la presenter/
