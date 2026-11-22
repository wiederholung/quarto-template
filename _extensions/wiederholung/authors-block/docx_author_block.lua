-- DOCX author block, copyright (c) 2026 authors-block contributors.
-- Distributed under the repository's MIT license.
local M = {}
local stringify = pandoc.utils.stringify
local module_dir = pandoc.path.directory(debug.getinfo(1,"S").source:gsub("^@", ""))

-- Fallback point sizes for references without a usable Author / Affiliation size.
-- Other dimensions are relative to the effective paragraph size.
local layout = {
  author_size = 12, note_size = 10.5,
  orcid = .75, envelope_width = .85, envelope_canvas_height = .75,
  marker_size = 2/3, marker_raise = .375,
  name_orcid = .15, orcid_mark = .10, name_mark = .05,
  before_envelope = .15, note_gap = .25, email_gap = .30,
  -- Optical correction for Word's extra visible clearance before its SVG.
  orcid_optical_correction = .0125,
}
local NBSP = "\u{00A0}"

local function bind_cjk(text)
  -- Word honors its legacy zero-width no-break character between CJK letters,
  -- while U+2060 is ignored by its Chinese line-breaking rules.
  local function cjk(c)
    return c and ((c>=0x3400 and c<=0x9fff) or (c>=0x20000 and c<=0x323af)
      or (c>=0x3040 and c<=0x30ff) or (c>=0xac00 and c<=0xd7af))
  end
  local out,previous={},nil
  for _,c in utf8.codes(text) do
    if cjk(previous) and cjk(c) then out[#out+1]="\u{feff}" end
    out[#out+1]=utf8.char(c); previous=c
  end
  return table.concat(out)
end

local function xml(value)
  return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function inlines(value)
  if not value then return pandoc.Inlines({}) end
  if type(value) == "string" then return pandoc.Inlines({pandoc.Str(value)}) end
  if pandoc.utils.type(value) == "Inlines" then return pandoc.Inlines(value) end
  if value.literal then return inlines(value.literal) end
  if value.given or value.family then
    return inlines(stringify(value.given or "") .. " " .. stringify(value.family or ""))
  end
  return inlines(stringify(value))
end

local function display_name(content)
  -- Normal names stay together. Very long names retain their word break points.
  if utf8.len(stringify(content)) <= 40 then
    content = pandoc.Span(content):walk({
      Space = function() return pandoc.Str(NBSP) end,
      Str = function(s) s.text = bind_cjk(s.text:gsub(" ", NBSP)); return s end,
    }).content
  end
  return content
end

local function flag(author, key)
  local value=author[key] or (author.attributes and author.attributes[key])
  return value ~= nil and value ~= false and stringify(value) ~= "false"
end

local normalize_orcid = require('orcid').normalize

local function gap(size, em)
  -- U+00A0 must directly touch the inline drawing to keep it with the name.
  -- U+202F or an intervening U+2060 allows orphan icons in native Word.
  -- TNR's NBSP advances .25 em; character spacing uses twentieths of a point.
  local spacing = math.floor((em-.25)*size*20+.5)
  local half_points = math.floor(size*2+.5)
  return pandoc.RawInline("openxml", string.format(
    '<w:r><w:rPr>' ..
    '<w:spacing w:val="%d"/><w:sz w:val="%d"/><w:szCs w:val="%d"/>' ..
    '</w:rPr><w:t xml:space="preserve">\u{00A0}</w:t></w:r>',
    spacing,half_points,half_points))
end

local function marker(text,size,target,title)
  -- Explicit size/position avoids Word applying its own second scaling to
  -- w:vertAlign="superscript". Family and color inherit the paragraph.
  local points = math.floor(size*layout.marker_size*2+.5)
  local raise = math.floor(size*layout.marker_raise*2+.5)
  local color = target and '<w:color w:val="000000"/>' or ''
  local underline = target and '<w:u w:val="none"/>' or ''
  local run = pandoc.RawInline("openxml", string.format(
    '<w:r><w:rPr>' .. color .. '<w:position w:val="%d"/><w:sz w:val="%d"/>' ..
    '<w:szCs w:val="%d"/>' .. underline .. '</w:rPr><w:t>%s</w:t></w:r>',
    raise,points,points,xml(text)))
  return target and pandoc.Link({run},"#"..target,title or "") or run
end

local function image(kind,alt,size,width,height)
  local source = "authors-block-" .. kind .. ".svg"
  for _,asset in ipairs({
    {kind..".svg",source,"image/svg+xml"},
    -- Pandoc recognizes this exact suffix as the native SVG's PNG fallback.
    {kind..".png",source..".png","image/png"},
  }) do
    local path=pandoc.path.join({module_dir,"assets",asset[1]})
    local f=assert(io.open(path,"rb"),"authors-block: missing bundled "..kind.." icon")
    pandoc.mediabag.insert(asset[2],asset[3],f:read("*a")); f:close()
  end
  return pandoc.Image({pandoc.Str(alt)},source,"",pandoc.Attr("",{}, {
    width=string.format("%.8fin",size*width/72),
    height=string.format("%.8fin",size*height/72),
  }))
end

local function orcid_icon(id,size)
  return pandoc.Link({image("orcid","ORCID iD "..id,size,layout.orcid,layout.orcid)},
    "https://orcid.org/"..id)
end

local function envelope(size,email)
  -- .05 em clear space above/below a .65 em outline aligns its visual center
  -- with the ORCID without raising or superscripting the image run.
  local icon=image("envelope","Corresponding author",size,
    layout.envelope_width,layout.envelope_canvas_height)
  return email and pandoc.Link({icon},"mailto:"..stringify(email)) or icon
end

local function append_icon(content,icon)
  content:insert(icon)
end

local function styled(content,name,target)
  if target then content={pandoc.Span(content,pandoc.Attr(target))} end
  return pandoc.Div({pandoc.Para(content)},pandoc.Attr("",{}, {["custom-style"]=name}))
end

function M.render(doc)
  local meta=doc.meta
  local authors=meta.authors or meta.author
  if not authors or not authors[1] or not authors[1].name then return doc end
  local options=meta["authors-block"]
  options=type(options)=="table" and options.docx or nil
  local function size_option(key,default)
    local value=options and options[key]
    if not value then return default end
    local size=tonumber(stringify(value))
    assert(size and size>0,"authors-block: "..key.." must be a positive point size")
    return size
  end
  local sizes=require("docx_style_sizes")(PANDOC_WRITER_OPTIONS.reference_doc)
  local author_size=size_option("author-size",sizes.author or layout.author_size)
  local note_size=size_option("note-size",sizes.note or layout.note_size)
  local zh=stringify(meta.lang or ""):match("^zh") ~= nil
  local affiliations=meta.affiliations or {}
  -- Let Pandoc allocate bookmark IDs; reserve names against existing content.
  local used={}
  local function remember(el)
    if el.attr and el.identifier~="" then used[el.identifier]=true end
  end
  doc:walk({Block=remember,Inline=remember})
  local function anchor(suffix)
    local base="authors_block_"..suffix
    local name,n=base,2
    while used[name] do name=base.."_"..n; n=n+1 end
    used[name]=true
    return name
  end
  local index,aff_targets={},{}
  for n,a in ipairs(affiliations) do
    index[stringify(a.id or n)]=n
    aff_targets[n]=anchor("aff_"..n)
  end
  local equal_target=anchor("equal")
  local names=pandoc.Inlines({})
  local plain_names={}
  local emails={}
  local equal=false
  for n,author in ipairs(authors) do
    if n>1 then
      names:insert(pandoc.Str(zh and "，" or ","))
      if not zh then names:insert(pandoc.Space()) end
    end
    local name = inlines(author.name)
    plain_names[n] = stringify(name):match("^%s*(.-)%s*$")
    names:extend(display_name(name))
    local numbers,seen={},{}
    for _,ref in ipairs(author.affiliations or {}) do
      local number=index[stringify(ref.ref or ref.id or "")]
      if number and not seen[number] then numbers[#numbers+1]=number; seen[number]=true end
    end
    table.sort(numbers)
    local marks={}
    for _,number in ipairs(numbers) do
      marks[#marks+1]={tostring(number),aff_targets[number],
        (zh and "机构 " or "Affiliation ")..number}
    end
    if flag(author,"equal-contributor") then
      marks[#marks+1]={"†",equal_target,zh and "同等贡献" or "Equal contribution"}
      equal=true
    end
    local orcid=normalize_orcid(author.orcid)
    if orcid then
      names:insert(gap(author_size,layout.name_orcid-layout.orcid_optical_correction))
      append_icon(names,orcid_icon(orcid,author_size))
    end
    if #marks>0 then
      names:insert(gap(author_size,orcid and layout.orcid_mark or layout.name_mark))
      for i,mark in ipairs(marks) do
        if i>1 then names:insert(marker(",",author_size)) end
        names:insert(marker(mark[1],author_size,mark[2],mark[3]))
      end
    end
    if flag(author,"corresponding") then
      local email=author.email
      if email and stringify(email)=="" then email=nil end
      names:insert(gap(author_size,layout.before_envelope))
      append_icon(names,envelope(author_size,email))
      if email then emails[#emails+1]=email end
    end
  end

  local details=pandoc.Blocks({})
  for n,aff in ipairs(affiliations) do
    local line=pandoc.Inlines({marker(tostring(n),note_size),gap(note_size,layout.note_gap)})
    line:extend(inlines(aff.name))
    local last=n==#affiliations and not equal and #emails==0
    details:insert(styled(line,last and "Affiliation Last" or "Affiliation",aff_targets[n]))
  end
  if equal then
    local line=pandoc.Inlines({marker("†",note_size),gap(note_size,layout.note_gap)})
    line:extend(inlines(zh and "同等贡献" or "Equal contribution"))
    details:insert(styled(line,#emails==0 and "Author Note Last" or "Author Note",equal_target))
  end
  if #emails>0 then
    local line=pandoc.Inlines({})
    append_icon(line,envelope(note_size))
    line:insert(gap(note_size,layout.email_gap))
    for n,email in ipairs(emails) do
      if n>1 then line:insert(pandoc.Str(";")); line:insert(pandoc.Space()) end
      local label=pandoc.Span(inlines(email),pandoc.Attr("",{}, {["custom-style"]="Author Email"}))
      line:insert(pandoc.Link({label},"mailto:"..stringify(email)))
    end
    details:insert(styled(line,equal and "Author Contact Continued" or "Author Contact"))
  end
  meta.authors=nil; meta.affiliations=nil
  local placement = options and stringify(options.placement or "")
  if placement == "template" then
    -- Pandoc writes dc:creator from author. Keep the decorated byline in the
    -- template's header so icon descriptions and line-break controls stay local.
    meta.author = pandoc.MetaList(plain_names)
    details:insert(1, styled(names, "Author"))
    meta["authors-block-header"] = pandoc.MetaBlocks(details)
    return pandoc.Pandoc(doc.blocks, meta)
  end

  -- Stock and earlier custom templates print their byline from the author loop.
  meta.author=pandoc.MetaList({pandoc.MetaInlines(names)})
  if placement == "metadata" then
    meta["authors-block-details"]=pandoc.MetaBlocks(details)
    return pandoc.Pandoc(doc.blocks,meta)
  end
  -- Preserve title-block order for standalone users of Pandoc's stock template.
  if meta.date then
    details:insert(styled(inlines(meta.date),"Date")); meta.date=nil
  end
  -- Preserve the established order: author details, date, abstract, then body.
  if meta.abstract then
    local label=meta["abstract-title"] or (zh and "摘要" or "Abstract")
    details:insert(styled({pandoc.Strong(inlines(label))},"Abstract"))
    local abstract=meta.abstract
    if pandoc.utils.type(abstract)~="Blocks" then abstract={pandoc.Para(inlines(abstract))} end
    details:insert(pandoc.Div(abstract,pandoc.Attr("",{}, {["custom-style"]="Abstract"})))
    meta.abstract=nil
  end
  details:extend(doc.blocks)
  return pandoc.Pandoc(details,meta)
end
return M
