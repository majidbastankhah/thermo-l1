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
local chapter = nil          -- from the chapter's own front matter
local qa_url, qa_presenter = "", ""   -- live questions (see _quarto.yml)
local show_solutions = nil   -- nil => decide from `mode`

function Meta(m)
  if m.gapmode then mode = pandoc.utils.stringify(m.gapmode) end
  if m.chapter then chapter = pandoc.utils.stringify(m.chapter) end
  if m["qa-url"] then qa_url = pandoc.utils.stringify(m["qa-url"]) end
  if m["qa-presenter-url"] then qa_presenter = pandoc.utils.stringify(m["qa-presenter-url"]) end
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

-- The layers of help under an end-of-chapter problem, in the order they are
-- offered. Each is a div inside the problem's gap; in the notes with gaps each
-- one is a separate covered panel, opened with a click.
local LAYERS = {
  { class = "hint",   title = "Hint",          h = "9mm"  },
  { class = "answer", title = "Final answer",  h = "9mm"  },
  { class = "worked", title = "Full solution", h = "24mm" },
}
local function layer_of(b)
  if b.t ~= "Div" then return nil end
  for _, L in ipairs(LAYERS) do
    if b.classes:includes(L.class) then return L end
  end
end

-- `solo`: the label of an end-of-chapter layer. Such a panel is not a lecture
-- step: it opens on its own when clicked and the keyboard sequence skips it.
local function revealable(blocks, height, solo)
  if is_latex() then return filled(blocks) end

  reveal_count = reveal_count + 1
  local body = pandoc.Div(blocks, pandoc.Attr("", { "gap-body" }))

  local classes = { "gap-reveal" }
  local attrs = {
    ["data-gap"] = tostring(reveal_count),
    ["style"]    = "--gap-h: " .. height,
  }
  if solo then
    classes[#classes + 1] = "gap-solo"
    attrs["data-label"] = solo
  end

  return { pandoc.Div({ body }, pandoc.Attr("gap-" .. reveal_count, classes, attrs)) }
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
  -- the layers under an end-of-chapter problem (hint, final answer,
  -- full solution): dropped from the student copy, styled by boxes.lua
  if layer_of(el) then
    if not show_solutions then return {} end
    return nil
  end

  if not el.classes:includes("gap") then return nil end

  local height = el.attributes["height"] or "40mm"
  local hint   = el.attributes["hint"]

  -- height="fill": the rest of the page in the printed student copy (one
  -- end-of-chapter problem per page); a fixed panel on screen
  local fill = (height == "fill")
  if fill then height = "70mm" end

  -- a gap that holds an end-of-chapter solution: in print, the solution box
  -- goes out on its own, NOT inside the gap's frame -- tcolorbox cannot break
  -- a box nested in another box across pages, and long solutions need to
  local holds_solution = false
  for _, b in ipairs(el.content) do
    if layer_of(b) then holds_solution = true end
  end
  if holds_solution and mode ~= "student" then
    if mode == "reveal" and not is_latex() then
      -- one covered panel per layer, each opened on its own, with its title
      -- visible above it, so students can see what they are about to open
      local out = {}
      for _, b in ipairs(el.content) do
        local L = layer_of(b)
        if L then
          out[#out + 1] = pandoc.Div({ pandoc.Plain({ pandoc.Str(L.title) }) },
                                     pandoc.Attr("", { "layer-title", "layer-" .. L.class }))
          for _, x in ipairs(revealable({ b }, L.h, L.title)) do out[#out + 1] = x end
        else
          out[#out + 1] = b
        end
      end
      return out
    end
    return el.content   -- complete / lecturer: all layers, in order
  end

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
  student  = "student copy (gaps filled in during the lecture)",
  complete = "completed copy",
  reveal   = "completed copy",
  lecturer = "presenter notes, do not circulate",
}

local function attr_escape(s)
  return (s:gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"))
end

function Pandoc(doc)
  -- the live-questions settings, read by js/lecture-reveal.html; only the
  -- lecture view (notes with gaps) gets them
  if mode == "reveal" and not is_latex() and qa_url ~= "" then
    table.insert(doc.blocks, 1, pandoc.RawBlock("html",
      '<div id="qa-config" hidden data-url="' .. attr_escape(qa_url) ..
      '" data-presenter="' .. attr_escape(qa_presenter) .. '"></div>'))
  end
  if is_latex() then
    local label = LABEL[mode] or LABEL.complete
    if chapter then label = "Chapter " .. chapter .. " -- " .. label end
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
