#!/usr/bin/env bash
# Build every TikZ figure to PDF (for the printed notes) and SVG (for the web).
# Only rebuilds a figure whose source is newer than its output.
set -euo pipefail

cd "$(dirname "$0")/figures"
mkdir -p out .work

for src in tikz/*.tex; do
  name="$(basename "$src" .tex)"
  [ "$name" = "_style" ] && continue

  if [ -f "out/$name.pdf" ] && [ "out/$name.pdf" -nt "$src" ] \
     && [ "out/$name.pdf" -nt tikz/_style.tex ]; then
    continue
  fi

  echo "  figure: $name"
  ( cd tikz && pdflatex -interaction=nonstopmode -halt-on-error \
      -output-directory=../.work "$name.tex" >/dev/null 2>&1 ) || {
        echo "    FAILED -- see figures/.work/$name.log" >&2
        exit 1
      }
  mv ".work/$name.pdf" "out/$name.pdf"
  pdftocairo -svg "out/$name.pdf" "out/$name.svg"
done

echo "figures up to date."
