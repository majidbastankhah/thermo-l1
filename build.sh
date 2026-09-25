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

# Every chNN-*.qmd in this folder is a chapter; its outputs are named chNN-...
CHAPTERS=(ch[0-9][0-9]-*.qmd)

# $1 = chapter file, $2 = gapmode, $3 = output name, $4 = destination directory.
# pdf/ is copied into the published site by _quarto.yml, so anything written
# there is PUBLIC. The presenter copy goes to presenter/ instead, which is not
# a Quarto resource and never reaches _site.
build_pdf () {
  echo "  pdf: $4/$3"
  quarto render "$1" --to pdf \
    --metadata-file _pdf.yml \
    -M "gapmode:$2" \
    --output "$3.pdf" \
    --quiet
  mkdir -p "$4"
  mv "_site/$3.pdf" "$4/$3.pdf"
}

if [ "$what" = "all" ] || [ "$what" = "pdf" ]; then
  for qmd in "${CHAPTERS[@]}"; do
    ch="${qmd:0:4}"                       # ch01, ch02, ...
    build_pdf "$qmd" student  "$ch-student"   pdf
    build_pdf "$qmd" complete "$ch-complete"  pdf
    build_pdf "$qmd" lecturer "$ch-presenter" presenter
  done
fi

if [ "$what" = "all" ] || [ "$what" = "site" ]; then
  echo "  site: _site/  (lecture view -- gaps start covered)"
  quarto render --quiet
fi

echo
echo "done."
[ -d pdf ]       && ls -la pdf/
[ -d presenter ] && ls -la presenter/
