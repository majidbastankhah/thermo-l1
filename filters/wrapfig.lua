--[[
  wrapfig.lua -- let a small figure sit beside the text instead of below it.

      ![](figures/img/balanced-rocks.png){.wrap width=30%}
      ![](figures/img/motor.png){.wrap side=left width=26%}

  In PDF this becomes a `wrapfigure`; in HTML, a float. Only use it on an image
  that is a paragraph of its own and OUTSIDE a note/example box -- wrapfigure
  and breakable tcolorboxes do not get on.

  Must run AFTER figext.lua so the .svg -> .pdf swap has already happened.
--]]

local function frac(img, dflt)
  local w = img.attributes["width"]
  if w then
    local n = w:match("^(%d+%.?%d*)%%$")
    if n then return tonumber(n) / 100 end
  end
  return dflt
end

function Para(el)
  if #el.content ~= 1 then return nil end
  local img = el.content[1]
  if img.t ~= "Image" or not img.classes:includes("wrap") then return nil end

  local w    = frac(img, 0.32)
  local left = img.attributes["side"] == "left"

  if FORMAT:match("latex") then
    return pandoc.RawBlock("latex", string.format(
      "\\begin{wrapfigure}{%s}{%.3f\\textwidth}\n" ..
      "\\vspace{-1.2\\baselineskip}\\centering\n" ..
      "\\includegraphics[width=%.3f\\textwidth]{%s}\n" ..
      "\\vspace{-1.4\\baselineskip}\\end{wrapfigure}",
      left and "l" or "r", w + 0.02, w, img.src))
  end

  img.classes = img.classes:filter(function (c) return c ~= "wrap" end)
  return pandoc.Div({ pandoc.Plain({ img }) },
    pandoc.Attr("", { left and "wrap-left" or "wrap-right" }))
end
