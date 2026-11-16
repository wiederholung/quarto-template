-- Archived opt-in experiment; not invoked by the project configuration.
-- Native Word heading numbering and REF fields; repair Quarto callout tables.
-- Runs with Quarto's bundled Lua/Pandoc. Other output formats are untouched.
local base=pandoc.path.directory(PANDOC_SCRIPT_FILE)
local function module(name)
  local path=base.."/vendor/slaxml/"..name..".lua"
  return assert(load(pandoc.system.read_file(path),"@"..path))()
end
package.loaded.slaxml=module("slaxml")
local xml=module("slaxdom")
local environment=pandoc.system.environment()
local native_numbering=environment.QUARTO_DOCX_NATIVE_NUMBERING=="1"
local W="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
local function elements(n,name)
  local out={}
  for _,c in ipairs(n and n.kids or {}) do
    if c.type=="element" and c.nsURI==W and (not name or c.name==name) then out[#out+1]=c end
  end
  return out
end
local function first(n,name) return elements(n,name)[1] end
local function attr(n,name)
  if n then for _,a in ipairs(n.attr or {}) do if a.name==name then return a.value end end end
end
local function node(name,attrs,kids)
  local n={type="element",name=name,nsURI=W,nsPrefix="w",attr={},kids=kids or {}}
  for k,v in pairs(attrs or {}) do
    n.attr[#n.attr+1]={type="attribute",name=k,value=tostring(v),nsURI=W,nsPrefix="w"}
  end
  return n
end
local function remove(n,name)
  for i=#n.kids,1,-1 do
    local c=n.kids[i]
    if c.type=="element" and c.nsURI==W and c.name==name then table.remove(n.kids,i) end
  end
end
local function set(n,name,attrs,kids)
  remove(n,name); local c=node(name,attrs,kids); n.kids[#n.kids+1]=c; return c
end
local function ensure(n,name)
  local found=first(n,name)
  if found then return found end
  local c=node(name); table.insert(n.kids,1,c); return c
end
local function walk(n,fn)
  fn(n)
  for _,c in ipairs(n.kids or {}) do walk(c,fn) end
end
local function descendants(n,name)
  local out={}; walk(n,function(c)
    if c.type=="element" and c.nsURI==W and c.name==name then out[#out+1]=c end
  end); return out
end
local function text(n)
  local s={}; walk(n,function(c) if c.type=="text" then s[#s+1]=c.value end end)
  return table.concat(s)
end
local function literal(s) return {type="text",name="#text",value=s} end
local function clone(n)
  local copy={}
  for _,key in ipairs({"type","name","nsURI","nsPrefix","value","cdata"}) do copy[key]=n[key] end
  for _,key in ipairs({"kids","attr"}) do
    if n[key] then copy[key]={}; for _,c in ipairs(n[key]) do copy[key][#copy[key]+1]=clone(c) end end
  end
  return copy
end
local function number_props(p,num,level)
  set(p,"numPr",nil,{node("ilvl",{val=level}),node("numId",{val=num})})
end
local orders={
  pPr="pStyle keepNext keepLines pageBreakBefore framePr widowControl numPr suppressLineNumbers pBdr shd tabs suppressAutoHyphens kinsoku wordWrap overflowPunct topLinePunct autoSpaceDE autoSpaceDN bidi adjustRightInd snapToGrid spacing ind contextualSpacing mirrorIndents suppressOverlap jc textDirection textAlignment textboxTightWrap outlineLvl divId cnfStyle rPr sectPr pPrChange",
  tblPr="tblStyle tblpPr tblOverlap bidiVisual tblStyleRowBandSize tblStyleColBandSize tblW jc tblCellSpacing tblInd tblBorders shd tblLayout tblCellMar tblLook tblCaption tblDescription tblPrChange",
  tcPr="cnfStyle tcW gridSpan hMerge vMerge tcBorders shd noWrap tcMar textDirection tcFitText vAlign hideMark headers cellIns cellDel cellMerge tcPrChange",
}
local function order(n)
  walk(n,function(c)
    local seq=c.nsURI==W and orders[c.name]
    if seq then
      local rank={}; local k=0
      for key in seq:gmatch("%S+") do k=k+1; rank[key]=k end
      table.sort(c.kids,function(a,b) return (rank[a.name] or 999)<(rank[b.name] or 999) end)
    end
  end)
end
local function merge_ppr(p)
  local all=elements(p,"pPr"); local merged=node("pPr")
  for _,pr in ipairs(all) do for _,c in ipairs(elements(pr)) do
    remove(merged,c.name); merged.kids[#merged.kids+1]=c
  end end
  remove(p,"pPr"); table.insert(p.kids,1,merged); return merged
end
local function repair_callouts(doc)
  -- Layout sections can omit inherited page settings; use the document's final
  -- section, with Word's Letter / one-inch defaults for an unspecified page.
  local section=first(first(doc.root,"body"),"sectPr")
  local page,margin=first(section,"pgSz"),first(section,"pgMar")
  local available=tonumber(attr(page,"w") or 12240)-tonumber(attr(margin,"left") or 1440)-tonumber(attr(margin,"right") or 1440)
  for _,tbl in ipairs(descendants(doc,"tbl")) do
    local pr=first(tbl,"tblPr"); local borders=pr and first(pr,"tblBorders")
    local left=borders and first(borders,"left")
    local color=attr(left,"color")
    if color and color~="000000" and color~="auto" and tonumber(attr(left,"sz") or 0)>=16 then
      local rows=elements(tbl,"tr"); local columns=0
      for _,row in ipairs(rows) do columns=math.max(columns,#elements(row,"tc")) end
      assert(columns==1 or columns==2,"Unsupported Quarto callout column structure")
      local width=available-120 -- inset the accent rule and keep within the text area
      set(pr,"tblStyle",{val="FloatLayout"})
      set(pr,"tblInd",{w=60,type="dxa"}); set(pr,"tblW",{w=width,type="dxa"})
      set(pr,"tblLayout",{type="fixed"})
      for _,side in ipairs({"top","bottom","right","insideH","insideV"}) do set(borders,side,{val="nil"}) end
      local grid=set(tbl,"tblGrid")
      local widths=columns==2 and {420,width-420} or {width}
      for _,w in ipairs(widths) do grid.kids[#grid.kids+1]=node("gridCol",{w=w}) end
      -- tblGrid precedes rows in WordprocessingML.
      for i,c in ipairs(tbl.kids) do if c==grid then table.remove(tbl.kids,i);break end end
      local grid_at=#tbl.kids+1
      for i,c in ipairs(tbl.kids) do if c.name=="tr" then grid_at=i;break end end
      table.insert(tbl.kids,grid_at,grid)
      local title=true
      for _,row in ipairs(rows) do
        set(ensure(row,"trPr"),"cantSplit")
        local cells=elements(row,"tc")
        for i,cell in ipairs(cells) do
          local cp=ensure(cell,"tcPr")
          set(cp,"tcW",{w=#cells==1 and width or widths[i],type="dxa"})
          if #cells==1 and columns==2 then set(cp,"gridSpan",{val=2}) end
          set(cp,"vAlign",{val="top"})
          local mar=set(cp,"tcMar")
          for _,side in ipairs({"top","bottom","left","right"}) do
            set(mar,side,{w=(side=="top" or side=="bottom") and 80 or 100,type="dxa"})
          end
          for _,p in ipairs(elements(cell,"p")) do
            local pp=merge_ppr(p)
            local icon=(#descendants(p,"drawing")>0 and #descendants(p,"t")==0)
            set(pp,"pStyle",{val=icon and "CalloutIcon" or (title and "CalloutTitle" or "CalloutBody")})
            remove(pp,"spacing"); remove(pp,"ind"); remove(pp,"jc")
            if not icon then title=false end
          end
        end
      end
    end
  end
end
local function finalize(path)
  local archive=pandoc.zip.Archive(pandoc.system.read_file(path))
  local entries,parts={},{}
  for _,entry in ipairs(archive.entries) do entries[#entries+1]=entry; parts[entry.path]=entry:contents() end
  local doc=xml:dom(assert(parts["word/document.xml"]))
  local requested=false
  walk(doc,function(n)
    for i=#(n.kids or {}),1,-1 do
      if n.kids[i].type=="comment" and n.kids[i].value=="qt-docx-finalize" then
        requested=true; table.remove(n.kids,i)
      end
    end
  end)
  if not requested then return end
  local changed={}
  -- Disabled by default; keep Quarto's heading text and section hyperlinks.
  if native_numbering then
  local styles=xml:dom(assert(parts["word/styles.xml"]))
  local headings,targets={},{}
  for _,p in ipairs(descendants(doc,"p")) do
    for i=#p.kids,1,-1 do
      local c=p.kids[i]
      if c.type=="comment" then
        local level,num=c.value:match("^qt%-heading:(%d+):(.*)$")
        if level then
          headings[#headings+1]={p=p,level=tonumber(level)-1,num=num}
          for _,bm in ipairs(descendants(p,"bookmarkStart")) do targets[attr(bm,"name")]=num end
          table.remove(p.kids,i)
        end
      end
    end
  end
  -- Heading-free documents still need callout repairs; the document marker
  -- makes the whole operation idempotent, including that case.
  -- Pandoc places some heading bookmarks immediately before the paragraph.
  local byparagraph={}; for _,h in ipairs(headings) do byparagraph[h.p]=h.num end
  local function external_bookmarks(n)
    local pending={}
    for _,c in ipairs(n.kids or {}) do
      if c.nsURI==W and c.name=="bookmarkStart" then pending[#pending+1]=attr(c,"name")
      elseif c.type=="element" then
        if byparagraph[c]~=nil then for _,name in ipairs(pending) do targets[name]=byparagraph[c] end end
        if c.name~="bookmarkEnd" then pending={} end
        external_bookmarks(c)
      end
    end
  end
  external_bookmarks(doc)
  local numbered=false; for _,h in ipairs(headings) do if h.num~="" then numbered=true end end
  local numbering=xml:dom(assert(parts["word/numbering.xml"]))
  local root=numbering.root
  local absid,numid=0,1
  for _,a in ipairs(elements(root,"abstractNum")) do absid=math.max(absid,tonumber(attr(a,"abstractNumId"))+1) end
  for _,a in ipairs(elements(root,"num")) do numid=math.max(numid,tonumber(attr(a,"numId"))+1) end
  local heading_styles={}
  for _,s in ipairs(descendants(styles,"style")) do
    local name=attr(first(s,"name"),"val") or ""
    local level=tonumber(name:lower():match("^heading (%d+)$"))
    if level and level<=9 then
      heading_styles[level-1]=attr(s,"styleId")
      if numbered then
        local pp=ensure(s,"pPr"); number_props(pp,numid,level-1)
        local indent=math.max(360,level*220)
        set(pp,"ind",{left=indent,hanging=indent,firstLineChars=0})
        set(pp,"tabs",nil,{node("tab",{val="num",pos=indent})})
      end
    end
  end
  if numbered then
    local abstract=node("abstractNum",{abstractNumId=absid},{node("multiLevelType",{val="multilevel"}),node("name",{val="QuartoNativeHeadings"})})
    for level=0,8 do
      local labels={}; for n=1,level+1 do labels[#labels+1]="%"..n end
      local indent=math.max(360,(level+1)*220)
      abstract.kids[#abstract.kids+1]=node("lvl",{ilvl=level},{
        node("start",{val=1}),node("numFmt",{val="decimal"}),
        node("pStyle",{val=assert(heading_styles[level])}),node("suff",{val="tab"}),
        node("lvlText",{val=table.concat(labels,".")}),node("lvlJc",{val="left"}),
        node("pPr",nil,{node("tabs",nil,{node("tab",{val="num",pos=indent})}),node("ind",{left=indent,hanging=indent})})})
    end
    -- All abstract definitions must precede concrete numbering instances.
    local at=#root.kids+1
    for i,c in ipairs(root.kids) do if c.name=="num" then at=i;break end end
    table.insert(root.kids,at,abstract)
    root.kids[#root.kids+1]=node("num",{numId=numid},{node("abstractNumId",{val=absid})})
  end
  for _,h in ipairs(headings) do
    local pp=merge_ppr(h.p)
    number_props(pp,h.num~="" and numid or 0,h.level)
    if h.num~="" then
      -- Explicit reference paragraph indents would otherwise override the list.
      remove(pp,"ind")
    end
  end
  -- Replace only section references emitted by the filter, never arbitrary links.
  local function fields(n)
    local kids={}
    for _,c in ipairs(n.kids or {}) do
      local target=c.name=="hyperlink" and attr(c,"anchor")
      local num=target and targets[target]
      local marked=false
      for _,ch in ipairs(c.kids or {}) do if ch.type=="comment" and ch.value=="qt-section-link" then marked=true end end
      if marked and num and num~="" then
        local replaced=false
        for _,run in ipairs(c.kids) do
          if run.type=="comment" and run.value=="qt-section-link" then
            -- discard the private marker
          elseif run.name=="r" and num and num~="" and not replaced then
            local t=first(run,"t")
            local value=t and text(t)
            if value and value:sub(-#num)==num then
              local prefix=value:sub(1,#value-#num)
              if prefix~="" then
                local prefixrun=clone(run)
                first(prefixrun,"t").kids={literal(prefix)}
                kids[#kids+1]=prefixrun
              end
              t.kids={literal(num)}
              kids[#kids+1]=node("r",nil,{node("fldChar",{fldCharType="begin",dirty="true"})})
              local instr=node("instrText",nil,{literal(' REF "'..target..'" \\w \\h ')})
              instr.attr={{name="space",value="preserve",nsPrefix="xml",nsURI="http://www.w3.org/XML/1998/namespace"}}
              kids[#kids+1]=node("r",nil,{instr})
              kids[#kids+1]=node("r",nil,{node("fldChar",{fldCharType="separate"})})
              kids[#kids+1]=run
              kids[#kids+1]=node("r",nil,{node("fldChar",{fldCharType="end"})})
              replaced=true
            else kids[#kids+1]=run end
          else kids[#kids+1]=run end
        end
        assert(not num or num=="" or replaced,"Cannot convert section reference: "..target)
      else
        for i=#(c.kids or {}),1,-1 do
          if c.kids[i].type=="comment" and c.kids[i].value=="qt-section-link" then table.remove(c.kids,i) end
        end
        fields(c); kids[#kids+1]=c
      end
    end
    n.kids=kids
  end
  fields(doc)
  order(styles)
  local settings=xml:dom(assert(parts["word/settings.xml"]))
  set(settings.root,"updateFields",{val="true"})
  changed={["word/styles.xml"]=xml:xml(styles),
    ["word/numbering.xml"]=xml:xml(numbering),["word/settings.xml"]=xml:xml(settings)}
  end
  repair_callouts(doc)
  order(doc)
  changed["word/document.xml"]=xml:xml(doc)
  for i,e in ipairs(entries) do
    if changed[e.path] then entries[i]=pandoc.zip.Entry(e.path,changed[e.path],e.modtime) end
  end
  -- A failed write leaves the generated DOCX in place. Replace only after close.
  local temp=path..".tmp"
  pandoc.system.write_file(temp,pandoc.zip.Archive(entries):bytestring())
  pandoc.system.rename(temp,path)
  print("Finalized Word callouts"..(native_numbering and ", native numbering and REF fields" or "")..": "..path)
end

local paths={}
for _,p in ipairs(arg or {}) do if p:lower():match("%.docx$") then paths[#paths+1]=p end end
if #paths==0 then
  local files=environment.QUARTO_PROJECT_OUTPUT_FILES or ""
  local listfile=environment.QUARTO_USE_FILE_FOR_PROJECT_OUTPUT_FILES
  if listfile then
    files=pandoc.system.read_file(listfile)
  end
  for p in files:gmatch("[^\r\n]+") do if p:lower():match("%.docx$") then paths[#paths+1]=p end end
end
for _,path in ipairs(paths) do finalize(path) end
