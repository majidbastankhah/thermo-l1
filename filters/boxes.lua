--[[
  boxes.lua -- the recurring "Note / Warning / Key result / Example" boxes.

  In the .qmd you write

      ::: {.note}
      Work and heat are path functions.
      :::

  and this filter turns it into the matching LaTeX environment (defined in
  tex/preamble.tex) or an HTML div that styles/labels itself from styles.css.

  Supported classes: note, warning, key, example, activity, objectives.
  An optional `title="..."` replaces the default label.
--]]

local ENV = {
  note       = { env = "tnote",       label = "Note"          },
  warning    = { env = "twarning",    label = "Warning"       },
  key        = { env = "tkey",        label = "Key result"    },
  example    = { env = "texample",    label = "Example"       },
  activity   = { env = "tactivity",   label = "In-class activity" },
  objectives = { env = "tobjectives", label = "Learning objectives" },
  solution   = { env = "tsolution",   label = "Solution"       },
}

local function is_latex() return FORMAT:match("latex") or FORMAT:match("beamer") end

-- put the label inline at the very front of the first paragraph, the way the
-- original Word notes read ("Note: ..."), rather than on a line of its own
local function prepend_label(blocks, label)
  local marker = pandoc.RawInline("latex", "\\boxlabel{" .. label .. "}")
  local first = blocks[1]
  if first and (first.t == "Para" or first.t == "Plain") then
    table.insert(first.content, 1, marker)
  else
    table.insert(blocks, 1, pandoc.Plain({ marker }))
  end
  return blocks
end

function Div(el)
  for class, spec in pairs(ENV) do
    if el.classes:includes(class) then
      local label = el.attributes["title"] or spec.label

      if is_latex() then
        local blocks = prepend_label(el.content, label)
        local out = { pandoc.RawBlock("latex", "\\begin{" .. spec.env .. "}") }
        for _, b in ipairs(blocks) do out[#out + 1] = b end
        out[#out + 1] = pandoc.RawBlock("latex", "\\end{" .. spec.env .. "}")
        return out
      end

      local head = pandoc.Div(
        { pandoc.Plain({ pandoc.Str(label) }) },
        pandoc.Attr("", { "box-label" })
      )
      local body = {}
      body[1] = head
      for _, b in ipairs(el.content) do body[#body + 1] = b end
      return pandoc.Div(body, pandoc.Attr(el.identifier, { "tbox", "tbox-" .. class }))
    end
  end
end
