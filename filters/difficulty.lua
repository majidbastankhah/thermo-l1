--[[
  difficulty.lua -- problem difficulty as stars.

  In the source a problem is written  **P3.2 [medium].** ...
  and this filter shows the tag as stars instead of a word, so that a student
  who cannot solve an "easy" problem is not told so:

      [easy]   -> one green star
      [medium] -> two amber stars
      [hard]   -> three red stars

  The number of stars carries the meaning; the colour only reinforces it.
  On the website the stars have a tooltip ("difficulty 2 of 3").
--]]

local LEVEL = { easy = 1, medium = 2, hard = 3 }

local function is_latex() return FORMAT:match("latex") or FORMAT:match("beamer") end

local function stars(n)
  if is_latex() then
    return pandoc.RawInline("latex", "\\difficulty{" .. n .. "}")
  end
  return pandoc.Span({ pandoc.Str(string.rep("\u{2605}", n)) },
    pandoc.Attr("", { "difficulty", "difficulty-" .. n },
      { title = "difficulty " .. n .. " of 3", ["aria-label"] = "difficulty " .. n .. " of 3" }))
end

-- only inside the bold problem label, e.g. Strong{ "P3.2", Space, "[medium]." }
function Strong(el)
  local c = el.content
  if #c >= 3 and c[1].t == "Str" and c[1].text:match("^P%d+%.%d+$")
     and c[#c].t == "Str" then
    local level = c[#c].text:match("^%[(%a+)%]%.?$")
    if level and LEVEL[level] then
      local out = {}
      for i = 1, #c - 1 do out[#out + 1] = c[i] end   -- "P3.2" and the space
      return { pandoc.Strong(out), pandoc.Space(), stars(LEVEL[level]) }
    end
  end
end
