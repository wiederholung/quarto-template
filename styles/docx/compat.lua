-- Quarto DOCX float compatibility, verified with Quarto 1.11 / Pandoc 3.10.
-- Formatting belongs in reference.docx; this only removes conflicting direct
-- properties and distinguishes layout wrappers from actual data tables.
local function styled(block,name)
  return pandoc.Div({block},pandoc.Attr("",{}, {["custom-style"]=name}))
end

local function caption(p,kind)
  local found=false
  local content=pandoc.Inlines({})
  for _,i in ipairs(p.content) do
    if i.t=="RawInline" and i.format=="openxml" and i.text:find("<w:pPr",1,true)
        and (i.text:find('w:val="ImageCaption"',1,true) or i.text:find('w:val="TableCaption"',1,true)) then
      found=true
    else content:insert(i) end
  end
  if found then return styled(pandoc.Para(content),kind=="tbl" and "Table Caption" or "Image Caption") end
end

function Table(tbl)
  if FORMAT~="docx" then return nil end
  local kind
  tbl:walk({Div=function(div)
    if not kind then
      if div.identifier:match("^fig%-") then kind="fig"
      elseif div.identifier:match("^tbl%-") then kind="tbl" end
    end
  end})
  if not kind then
    -- Pandoc uses Compact in cells; it overrides the table style's font size.
    -- Bind actual headed data tables to a dedicated paragraph style instead.
    if #tbl.head.rows>0 then
      local function table_text(p) return styled(pandoc.Para(p.content),"Table Text") end
      return tbl:walk({Para=table_text,Plain=table_text})
    end
    return nil
  end
  tbl=tbl:walk({Para=function(p) return caption(p,kind) end})
  tbl.attributes["custom-style"]="FloatLayout"
  for n,spec in ipairs(tbl.colspecs) do tbl.colspecs[n]={pandoc.AlignDefault,spec[2]} end
  local function row(r)
    for _,cell in ipairs(r.cells) do
      cell.alignment=pandoc.AlignDefault
      local function image_paragraph(p)
        local has_image=false
        p:walk({Image=function() has_image=true end})
        if has_image then return styled(pandoc.Para(p.content),"Captioned Figure") end
      end
      cell.contents=cell.contents:walk({Para=image_paragraph,Plain=image_paragraph})
    end
  end
  for _,r in ipairs(tbl.head.rows) do row(r) end
  for _,b in ipairs(tbl.bodies) do
    for _,r in ipairs(b.head) do row(r) end
    for _,r in ipairs(b.body) do row(r) end
  end
  for _,r in ipairs(tbl.foot.rows) do row(r) end
  return tbl
end

function Div(div)
  if FORMAT~="docx" or not div.identifier:match("^fig%-") then return nil end
  local panels={}
  div:walk({Div=function(d)
    if d.classes:includes("quarto-layout-cell-subref") and d.attributes["ref-parent"]==div.identifier then
      panels[#panels+1]=d
    end
  end})
  if #panels<2 then return nil end
  local fraction=tonumber((panels[1].attributes.width or ""):match("^([%d%.]+)%%$"))
  if not fraction then return nil end
  local ncol=math.floor(100/fraction+0.5)
  if ncol<2 then return nil end
  for _,panel in ipairs(panels) do
    if panel.attributes.width~=panels[1].attributes.width then return nil end
  end
  -- Quarto's frame-based DOCX panel layout can stack or clip in Word.
  -- Equal-width panels need only one real table row, with no nested layout tables.
  local first
  local tail=pandoc.Blocks({})
  for _,block in ipairs(div.content) do
    if block.t=="Table" then first=first or block
    elseif not (block.t=="RawBlock" and block.format=="openxml" and block.text:find("w:framePr",1,true)) then
      tail:insert(block)
    end
  end
  if not first then return nil end
  local rows={}
  local cells={}
  for n,panel in ipairs(panels) do
    panel=panel:walk({Table=function(t)
      if t.attributes["custom-style"]=="FloatLayout" and #t.colspecs==1 and #t.bodies==1
          and #t.bodies[1].body==1 and #t.bodies[1].body[1].cells==1 then
        return t.bodies[1].body[1].cells[1].contents
      end
    end})
    panel=panel:walk({Div=function(d)
      if not d.identifier:match("^fig%-") then return nil end
      local paragraphs={}
      d:walk({Para=function(p) paragraphs[#paragraphs+1]=p end})
      if #paragraphs~=2 then return nil end
      local images=0
      paragraphs[1]:walk({Image=function() images=images+1 end})
      if images~=1 then return nil end
      -- Word can split a table cell between separate image/caption paragraphs,
      -- even with keepNext. One keepLines paragraph preserves their association.
      local content=pandoc.Inlines({})
      content:extend(paragraphs[1].content)
      content:insert(pandoc.LineBreak())
      content:extend(paragraphs[2].content)
      content=content:walk({Image=function(img)
        local width=tonumber((img.attributes.width or ""):match("^([%d%.]+)in$"))
        if width then img.attributes.width=string.format("%.4fin",width*.96) end
        return img
      end})
      d.content=pandoc.Blocks({styled(pandoc.Para(content),"Panel Figure")})
      return d
    end})
    cells[#cells+1]=pandoc.Cell({panel},pandoc.AlignDefault)
    if #cells==ncol or n==#panels then
      while #cells<ncol do cells[#cells+1]=pandoc.Cell({}) end
      rows[#rows+1]=pandoc.Row(cells); cells={}
    end
  end
  local body=first.bodies[1]
  body.body=rows
  first.bodies={body}
  local specs={}
  for _=1,ncol do specs[#specs+1]={pandoc.AlignDefault,1/ncol} end
  first.colspecs=specs
  first.attributes["custom-style"]="FloatLayout"
  tail=tail:walk({Para=function(p) return caption(p,"fig") end})
  div.content=pandoc.Blocks({first})
  div.content:extend(tail)
  return div
end
