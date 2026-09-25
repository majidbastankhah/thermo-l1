--[[
  gaps.lua -- one source, three audiences.

  Any block wrapped in

      ::: {.gap height="45mm" hint="derive dW = -P_ext dV"}
      $$ \mathrm{d}W = -P_\text{ext}\,\mathrm{d}V $$
      :::

  is rendered according to the `gapmode` metadata value:

    student   -> a blank ruled box of the stated height (the printed handout
                 students bring to the lecture and write into)
    reveal    -> the same content, covered, uncovered one gap at a time during
                 the lecture (the website: the screen in the room AND the file
                 posted afterwards, so the two can never drift apart)
    complete  -> everything shown (the printable version of the reveal view)
    lecturer  -> everything shown in small grey type, plus the hint as a
                 one-line prompt (your presenter notes)

  `height` sets the blank space in student mode and the size of the cover in
  reveal mode. `hint` only shows in lecturer mode.
--]]

local mode = "complete"
local show_solutions = nil   -- nil => decide from `mode`

function Meta(m)
  if m.gapmode then mode = pandoc.utils.stringify(m.gapmode) end
  if m.solutions ~= nil then
    local s = pandoc.utils.stringify(m.solutions)
    show_solutions = (s == "true" or s == "yes")
  end
  if show_solutions == nil then
    -- by default the handout students get BEFORE the lecture carries the
    -- problems but not the answers; every other build carries both
    show_solutions = (mode ~= "student")
  end
end

local function is_latex() return FORMAT:match("latex") or FORMAT:match("beamer") end

-- ---------------------------------------------------------------- student --

local function blank(height)
  if is_latex() then
    return { pandoc.RawBlock("latex", "\\gapblank{" .. height .. "}") }
  end
  return {
    pandoc.RawBlock("html",
      '<div class="gap-blank" style="min-height:' .. height .. '"></div>')
  }
end

-- --------------------------------------------------------------- complete --

local function filled(blocks)
  if is_latex() then
    local out = { pandoc.RawBlock("latex", "\\begin{gapfilled}") }
    for _, b in ipairs(blocks) do out[#out + 1] = b end
    out[#out + 1] = pandoc.RawBlock("latex", "\\end{gapfilled}")
    return out
  end
  return { pandoc.Div(blocks, pandoc.Attr("", { "gap-filled" })) }
end

-- ----------------------------------------------------------------- reveal --

-- The lecture view: the same content as `complete`, but each gap starts
-- covered and is uncovered one at a time during the lecture. Because it is
-- the same file, what is on the screen in the room and what is posted
-- afterwards can never drift apart. Print falls back to `complete`.

local reveal_count = 0

local function revealable(blocks, height)
  if is_latex() then return filled(blocks) end

  reveal_count = reveal_count + 1
  local body = pandoc.Div(blocks, pandoc.Attr("", { "gap-body" }))

  -- a gap that holds an end-of-chapter solution is not a lecture step: it
  -- opens on its own when clicked and is skipped by the keyboard sequence
  local classes = { "gap-reveal" }
  for _, b in ipairs(blocks) do
    if b.t == "Div" and b.classes:includes("worked") then
      classes[#classes + 1] = "gap-solo"
    end
  end

  return {
    pandoc.Div({ body }, pandoc.Attr(
      "gap-" .. reveal_count,
      classes,
      {
        ["data-gap"] = tostring(reveal_count),
        ["style"]    = "--gap-h: " .. height,
      }))
  }
end

-- --------------------------------------------------------------- lecturer --

-- The hint is authored as markdown, so it can carry maths
-- ($W = -\int P_\text{ext}\,\mathrm{d}V$) and is escaped properly on the way
-- into LaTeX. It is parsed into blocks rather than assembled inline, which
-- keeps this working under Quarto's filter emulation.
local function hint_blocks(hint)
  local ok, doc = pcall(pandoc.read, hint, "markdown")
  if ok and doc.blocks and #doc.blocks > 0 then return doc.blocks end
  return { pandoc.Plain({ pandoc.Str(hint) }) }
end

local function lecturer(blocks, hint)
  local out = {}
  local function add(b) out[#out + 1] = b end
  local function addall(bs) for _, b in ipairs(bs) do add(b) end end

  if is_latex() then
    add(pandoc.RawBlock("latex", "\\begin{gaplecturer}"))
    if hint and hint ~= "" then
      add(pandoc.RawBlock("latex", "{\\gaphintlabel{}"))
      addall(hint_blocks(hint))
      add(pandoc.RawBlock("latex", "}"))
    end
    addall(blocks)
    add(pandoc.RawBlock("latex", "\\end{gaplecturer}"))
    return out
  end

  if hint and hint ~= "" then
    add(pandoc.Div(hint_blocks(hint), pandoc.Attr("", { "gap-hint" })))
  end
  addall(blocks)
  return { pandoc.Div(out, pandoc.Attr("", { "gap-lecturer" })) }
end

-- ------------------------------------------------------------------ hooks --

function Div(el)
  -- worked solutions to the end-of-chapter problems
  if el.classes:includes("worked") then
    if not show_solutions then return {} end
    return nil   -- left for boxes.lua to style
  end

  if not el.classes:includes("gap") then return nil end

  local height = el.attributes["height"] or "40mm"
  local hint   = el.attributes["hint"]

  -- height="fill": the rest of the page in the printed student copy (one
  -- end-of-chapter problem per page); a fixed panel on screen
  local fill = (height == "fill")
  if fill then height = "70mm" end

  if mode == "student" then
    if fill and is_latex() then
      return { pandoc.RawBlock("latex", "\\gapfill") }
    end
    return blank(height)
  elseif mode == "lecturer" then
    return lecturer(el.content, hint)
  elseif mode == "reveal" then
    return revealable(el.content, height)
  else
    return filled(el.content)
  end
end

-- stamp the footer of the PDF with which of the three copies this is, so the
-- student handout and the lecturer copy can never be confused for each other
local LABEL = {
  student  = "Chapter 2 -- student copy (gaps filled in during the lecture)",
  complete = "Chapter 2 -- completed copy",
  reveal   = "Chapter 2 -- completed copy",
  lecturer = "Chapter 2 -- presenter notes, do not circulate",
}

function Pandoc(doc)
  if is_latex() then
    local label = LABEL[mode] or LABEL.complete
    table.insert(doc.blocks, 1,
      pandoc.RawBlock("latex", "\\renewcommand{\\gapvariant}{" .. label .. "}"))
  end
  return doc
end

return {
  { Meta = Meta },
  { Div = Div },
  { Pandoc = Pandoc },
}
