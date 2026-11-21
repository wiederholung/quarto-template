-- Quarto DOCX float compatibility, verified with Quarto 1.11 / Pandoc 3.10.
-- Formatting belongs in reference.docx; this only removes conflicting direct
-- properties and distinguishes layout wrappers from actual data tables.
local function styled(block,name)
  return pandoc.Div({block},pandoc.Attr("",{}, {["custom-style"]=name}))
end

-- Keep Quarto's section index for cross-references, but let Word display and
-- maintain the heading numbers. The post-render step binds native numbering.
-- Retained as an opt-in experiment; normal renders use Quarto numbering.
local native_numbering=os.getenv("QUARTO_DOCX_NATIVE_NUMBERING")=="1"
function Header(h)
  if FORMAT~="docx" or not native_numbering then return nil end
  local number=h.attributes.number
  if h.classes:includes("unnumbered") then number=nil end
  if number then
    assert(h.content[1] and h.content[1].t=="Str" and h.content[1].text==number,
      "Unexpected Quarto heading number: "..pandoc.utils.stringify(h.content))
    h.content:remove(1)
    if h.content[1] and (h.content[1].t=="Space" or
      (h.content[1].t=="Str" and h.content[1].text==". ")) then h.content:remove(1) end
  end
  h.content:insert(1,pandoc.RawInline("openxml",string.format(
    "<!--qt-heading:%d:%s-->",h.level,number or "")))
  return h
end

function Link(link)
  if native_numbering and FORMAT=="docx" and link.target:match("^#sec%-") and link.classes:includes("quarto-xref") then
    link.content:insert(1,pandoc.RawInline("openxml","<!--qt-section-link-->"))
    return link
  end
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

-- Read the reference document's text width once, before Pandoc writes output.
-- Without a reference, Pandoc's default is Letter with one-inch margins.
local cached_width
local function text_width()
  if cached_width then return cached_width end
  local width=9360
  local ref=PANDOC_WRITER_OPTIONS.reference_doc
  if ref then
    local archive=pandoc.zip.Archive(pandoc.system.read_file(ref))
    for _,entry in ipairs(archive.entries) do
      if entry.path=="word/document.xml" then
        local section
        for s in entry:contents():gmatch("<w:sectPr[%s>].-</w:sectPr>") do section=s end
        local page=section and section:match("<w:pgSz%s[^>]+>")
        local margin=section and section:match("<w:pgMar%s[^>]+>")
        local function value(tag,key,default)
          return tonumber(tag and tag:match('w:'..key..'="([%d]+)"')) or default
        end
        width=value(page,"w",12240)-value(margin,"left",1440)-value(margin,"right",1440)
        break
      end
    end
  end
  cached_width=width
  return cached_width
end

local function callout(div)
  if div.attributes["docx-compat"]=="true" then return div end
  local columns=1
  div:walk({RawBlock=function(b)
    if b.format=="openxml" and b.text:match("</w:tc>%s*<w:tc>") then columns=2 end
  end})
  local width=text_width()-120
  local widths=columns==2 and {420,width-420} or {width}
  local column,title=0,true
  local function raw(b)
    if b.format~="openxml" then return nil end
    local s=b.text
    local shade=s:match("<w:shd%s[^>]+/>") or ""
    if s:find("<w:tblPr>",1,true) then
      local accent=assert(s:match("<w:left%s[^>]-w:color=[^>]+/>"),"Missing callout accent")
      local pr='<w:tblPr><w:tblStyle w:val="FloatLayout"/>'..
        string.format('<w:tblW w:w="%d" w:type="dxa"/><w:tblInd w:w="60" w:type="dxa"/>',width)..
        '<w:tblBorders><w:top w:val="nil"/>'..accent..
        '<w:bottom w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/>'..
        '</w:tblBorders><w:tblLayout w:type="fixed"/></w:tblPr>'
      local grid='<w:tblGrid>'
      for _,w in ipairs(widths) do grid=grid..string.format('<w:gridCol w:w="%d"/>',w) end
      grid=grid..'</w:tblGrid>'
      s=s:gsub('<w:tblGrid>.-</w:tblGrid>',''):gsub('<w:tblPr>.-</w:tblPr>',pr..grid)
    end
    s=s:gsub('<w:tcPr>.-</w:tcPr>','')
    s=s:gsub('<w:tc>',function()
      column=column%columns+1
      return string.format('<w:tc><w:tcPr><w:tcW w:w="%d" w:type="dxa"/>',widths[column])..shade..
        '<w:tcMar><w:top w:w="80" w:type="dxa"/><w:left w:w="100" w:type="dxa"/>'..
        '<w:bottom w:w="80" w:type="dxa"/><w:right w:w="100" w:type="dxa"/></w:tcMar>'..
        '<w:vAlign w:val="top"/></w:tcPr>'
    end)
    -- Keep the required final cell paragraph, using the same body style.
    s=s:gsub('<w:p%s*/>','<w:p><w:pPr><w:pStyle w:val="CalloutBody"/></w:pPr></w:p>')
    b.text=s; return b
  end
  local function paragraph(p)
    p=p:walk({RawInline=function(i)
      if i.format=="openxml" then
        i.text=i.text:gsub('<w:pPr>.-</w:pPr>','')
        return i.text~="" and i or pandoc.Inlines({})
      end
    end})
    local image=false
    p:walk({Image=function() image=true end})
    local icon=image and pandoc.utils.stringify(p)==""
    local style=icon and "Callout Icon" or (title and "Callout Title" or "Callout Body")
    if not icon then title=false end
    return styled(pandoc.Para(p.content),style),false
  end
  div=div:walk({traverse="topdown",RawBlock=raw,Para=paragraph,Plain=paragraph,
    Table=function(t) return t,false end})
  div.attributes["docx-compat"]="true"
  return div
end

function Div(div)
  if FORMAT~="docx" then return nil end
  if div.classes:includes("docx-callout") then return callout(div) end
  if not div.identifier:match("^fig%-") then return nil end
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

local directory = pandoc.path.directory(debug.getinfo(1, "S").source:gsub("^@", ""))
local front_matter = dofile(pandoc.path.join({directory, "front-matter.lua"}))
local layout = dofile(pandoc.path.join({directory, "layout.lua"}))

function Pandoc(doc)
  if FORMAT ~= "docx" then return end
  doc.meta = front_matter(doc.meta)
  doc = layout(doc, text_width())
  if native_numbering then
    doc.blocks:insert(1, pandoc.RawBlock("openxml", "<!--qt-docx-finalize-->"))
  end
  return doc
end
