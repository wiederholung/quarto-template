-- Word-only geometry for Quarto's numbered floats. Keep Pandoc responsible for
-- writing the original paragraphs, math, media, relationships and bookmarks.
local function style(block, name)
  return pandoc.Div({block}, pandoc.Attr("", {}, {["custom-style"]=name}))
end

local function table_row(cells, fractions, name)
  local specs = {}
  for _, fraction in ipairs(fractions) do specs[#specs+1] = {pandoc.AlignDefault, fraction} end
  return pandoc.Table(pandoc.Caption(), specs, pandoc.TableHead({}),
    {pandoc.TableBody({pandoc.Row(cells)})}, pandoc.TableFoot({}),
    pandoc.Attr("", {}, {["custom-style"]=name}))
end

local function equation(p)
  if #p.content ~= 1 then return end
  local span = p.content[1]
  if span.t ~= "Span" or not span.identifier:match("^eq%-") or #span.content ~= 1 then return end
  local formula = span.content[1]
  if formula.t ~= "Math" or formula.mathtype ~= "DisplayMath" then return end
  -- Quarto 1.11 appends this suffix only to numbered display equations.
  local expression, number = formula.text:match("^(.*)%s+\\qquad%(([^()]*)%)%s*$")
  if not number then return end
  formula.text = expression
  local label = "(" .. number .. ")"
  local cells = {
    pandoc.Cell({pandoc.Plain({})}),
    pandoc.Cell({style(pandoc.Para({formula}), "Equation")}),
    pandoc.Cell({style(pandoc.Para({pandoc.Str(label)}), "Equation Number")}),
  }
  -- Symmetric side columns keep the formula on the text axis at any width.
  local side = math.min(.16, .055 + .012 * math.max(0, #number - 1))
  return pandoc.Div({table_row(cells, {side, 1-2*side, side}, "EquationLayout")}, span.attr)
end

local function note_kind(block)
  if not block or block.t ~= "Div" then return end
  for _, kind in ipairs({"Figure", "Table"}) do
    if block.attributes["custom-style"] == kind .. " Note"
        or block.classes:includes(kind:lower() .. "-note") then return kind end
  end
end

local function single_object(tbl)
  if tbl.t ~= "Table" or tbl.attributes["custom-style"] ~= "FloatLayout"
      or #tbl.colspecs ~= 1 or #tbl.bodies ~= 1 then return end
  local rows = tbl.bodies[1].body
  if #rows ~= 1 or #rows[1].cells ~= 1 then return end
  local content = rows[1].cells[1].contents
  if #content == 1 and content[1].t == "Div" then return content[1] end
end

local function image_fraction(img, width)
  local units = {["%"]=width/100, ["in"]=1440, cm=1440/2.54, mm=1440/25.4,
                 pt=20, px=1440/(PANDOC_WRITER_OPTIONS.dpi or 96)}
  local function measure(attr)
    local value, unit = (attr or ""):match("^([%d.]+)([%a%%]+)$")
    if value and units[unit] then return tonumber(value)*units[unit] end
  end
  local requested = measure(img.attributes.width)
  if requested then return math.min(1, requested/width) end
  local ok, info = pcall(function()
    local _, bytes = pandoc.mediabag.fetch(img.src)
    return pandoc.image.size(bytes)
  end)
  if not ok then return end
  local natural = info.width/info.dpi_horz*1440
  local height = measure(img.attributes.height)
  if height then natural = natural*height/(info.height/info.dpi_vert*1440) end
  return math.min(1, natural/width)
end

local function sized_paragraph(block, fraction)
  if fraction >= .9999 then return block end
  return table_row({pandoc.Cell({block})}, {fraction}, "FloatLayout")
end

local function single_figure(div, width)
  for i, block in ipairs(div.content) do
    if block.t == "Div" and block.attributes["custom-style"] == "Captioned Figure" then
      local images = {}
      block:walk({Image=function(img) images[#images+1] = img end})
      if #images ~= 1 then return end
      local fraction = image_fraction(images[1], width)
      if not fraction then return end
      -- Resolve the image before narrowing its container. Artwork in a note
      -- or a rich-text caption must retain its own size.
      div.content[i] = block:walk({Image=function(img)
        img.attributes.width = string.format("%.5fin", fraction*width/1440)
        return img
      end})
      return table_row({pandoc.Cell({div})}, {fraction}, "FloatLayout")
    end
  end
end

local function data_table(div)
  local data, has_note
  for _, block in ipairs(div.content) do
    if note_kind(block) == "Table" then has_note = true end
    if block.t == "Table" then
      if data then return end
      data = block
    end
  end
  if not data then return end
  -- Keep the header and first two data rows together, and the last two with
  -- their note. This also keeps the common three-row results table intact.
  local rows = {}
  for _, body in ipairs(data.bodies) do
    for _, row in ipairs(body.body) do rows[#rows+1] = row end
  end
  local function keep_row(row)
    for _, cell in ipairs(row.cells) do
      cell.contents = cell.contents:walk({Div=function(d)
        if d.attributes["custom-style"] == "Table Text" then
          d.attributes["custom-style"] = "Table Text Keep"
          return d
        end
      end})
    end
  end
  for _, row in ipairs(data.head.rows) do keep_row(row) end
  for i, row in ipairs(rows) do
    if (i < #rows and (i == 1 or i == #rows-1)) or (i == #rows and has_note) then
      keep_row(row)
    end
  end
  local total, defaults = 0, 0
  for _, col in ipairs(data.colspecs) do
    if col[2] then total = total + col[2] else defaults = defaults + 1 end
  end
  -- Make the table width determinate so an outside caption and note can share
  -- its edges. Explicit grid-table widths can sum to less than the text width.
  if defaults > 0 then
    local share = math.max(1-total, .01) / defaults
    local specs = data.colspecs
    for i, col in ipairs(specs) do specs[i] = {col[1], col[2] or share} end
    data.colspecs = specs
    total = total + defaults*share
  end
  total = math.min(1, total)
  local blocks = pandoc.Blocks({})
  for _, block in ipairs(div.content) do
    if block.t == "Table" then
      block = data
    elseif block.t == "Div" and (block.attributes["custom-style"] == "Table Caption" or note_kind(block)) then
      block = sized_paragraph(block, total)
    end
    if block.t == "Table" and #blocks > 0 and blocks[#blocks].t == "Table" then
      -- Word needs a paragraph boundary or it can merge adjacent tables.
      blocks:insert(pandoc.RawBlock("openxml",
        '<w:p><w:pPr><w:pStyle w:val="FloatSeparator"/></w:pPr></w:p>'))
    end
    blocks:insert(block)
  end
  div.content = blocks
  return div
end

local function floats(blocks, width)
  local result = pandoc.Blocks({})
  local i = 1
  while i <= #blocks do
    local block = blocks[i]
    local div = single_object(block)
    if div then
      local kind = div.identifier:match("^fig%-") and "Figure"
                or div.identifier:match("^tbl%-") and "Table"
      while kind and note_kind(blocks[i+1]) == kind do
        i = i + 1
        div.content:insert(blocks[i])
      end
      if kind == "Table" then
        -- A data table nested in a one-cell float cannot repeat its header in
        -- Word. Move it to the surrounding flow while retaining the float id.
        block = data_table(div) or table_row({pandoc.Cell({div})}, {1}, "FloatLayout")
      elseif kind == "Figure" then
        block = single_figure(div, width) or table_row({pandoc.Cell({div})}, {1}, "FloatLayout")
      end
    elseif block.t == "Div" and not block.identifier:match("^fig%-") then
      block.content = floats(block.content, width)
    end
    result:insert(block)
    i = i + 1
  end
  return result
end

return function(doc, width)
  doc.blocks = doc.blocks:walk({Para=equation, Div=function(div)
    local kind = note_kind(div)
    if kind then
      div.attributes["custom-style"] = kind .. " Note"
      return div
    end
  end})
  doc.blocks = floats(doc.blocks, width)
  return doc
end
