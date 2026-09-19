--[[
  figext.lua -- write figure paths once, get the right file per format.

  Every TikZ figure is built to BOTH figures/out/name.svg and
  figures/out/name.pdf. In the .qmd you always write the .svg path;
  this filter swaps the extension to .pdf when the target is LaTeX,
  because pdflatex cannot include SVG.
--]]

function Image(img)
  if not (FORMAT:match("latex") or FORMAT:match("beamer")) then return nil end
  if img.src:match("%.svg$") then
    img.src = img.src:gsub("%.svg$", ".pdf")
    return img
  end
end
