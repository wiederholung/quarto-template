-- LaTeX renderer: preserve Quarto metadata and the class's maketitle.
local M = {}
local str = pandoc.utils.stringify
local orcid = require('orcid')
local function tex(value)
  if not value then return '' end
  if type(value)=='string' then value=pandoc.Inlines{pandoc.Str(value)} end
  return pandoc.write(pandoc.Pandoc{pandoc.Plain(value)}, 'latex'):gsub('%s+$','')
end
local function flag(a,key)
  local v=(a.attributes or {})[key] or a[key]
  return v~=nil and v~=false and str(v)~='false'
end
function M.render(doc)
  local meta=doc.meta
  local class=str(meta.documentclass or 'scrartcl')
  assert(class=='ctexart' or class=='scrartcl',
    'authors-block PDF currently supports ctexart and scrartcl; disable the filter for other classes')
  local authors=meta['by-author']
  if not authors or #authors==0 then return doc end
  local zh=str(meta.lang or ''):match('^zh')~=nil
  local used={}
  doc:walk{Block=function(e) if e.identifier then used[e.identifier]=true end end,
    Inline=function(e) if e.identifier then used[e.identifier]=true end end}
  local function anchor(base)
    local key,n='authors-block-'..base,1
    while used[key] do n=n+1;key='authors-block-'..base..'-'..n end
    used[key]=true; return key
  end
  local affs,ids,targets={}, {}, {}
  for _,aff in ipairs(meta['by-affiliation'] or {}) do
    local n=#affs+1; affs[n]=aff; ids[str(aff.id)]=n; targets[n]=anchor('aff-'..n)
  end
  local eqtarget=anchor('equal')
  local function asset(name)
    local path=quarto.utils.resolve_path('assets/'..name..'.pdf'):gsub('\\','/')
    return '\\AuthorsBlockIcon{\\detokenize{'..path..'}}'
  end
  local function link(url,label) return '\\href{'..tex(url)..'}{'..label..'}' end
  local names,notes,emails={}, {}, {}
  local equal=false
  for _,a in ipairs(authors) do
    local name=tex(a.name.literal)
    local id=orcid.normalize(a.orcid)
    if id then name=name..'\\nobreak\\hspace{\\AuthorsBlockIconGap}'..link('https://orcid.org/'..id,asset('orcid')) end
    local marks,seen={},{}
    for _,aff in ipairs(a.affiliations or {}) do
      local n=ids[str(aff.id)]
      if n and not seen[n] then
        marks[#marks+1]='\\hyperlink{'..targets[n]..'}{'..n..'}';seen[n]=true
      end
    end
    if flag(a,'equal-contributor') then
      equal=true;marks[#marks+1]='\\hyperlink{'..eqtarget..'}{\\textdagger}'
    end
    if #marks>0 then name=name..'\\AuthorsBlockMark{'..table.concat(marks,',')..'}' end
    if flag(a,'corresponding') then
      local email=a.email and str(a.email) or ''
      name=name..'\\nobreak\\hspace{\\AuthorsBlockIconGap}'..(email~='' and link('mailto:'..email,asset('envelope')) or asset('envelope'))
      if email~='' then emails[#emails+1]=link('mailto:'..email,tex(a.email)) end
    end
    names[#names+1]='\\AuthorsBlockPerson{'..name..'}'
  end
  for n,aff in ipairs(affs) do
    notes[#notes+1]='\\AuthorsBlockNote{\\hypertarget{'..targets[n]..'}{\\textsuperscript{'..n..'}}}{'..tex(aff.name)..'}'
  end
  if equal then notes[#notes+1]='\\AuthorsBlockNote{\\hypertarget{'..eqtarget..'}{\\textsuperscript{\\textdagger}}}{'..
    (zh and '同等贡献' or 'Equal contribution')..'}' end
  if #emails>0 then notes[#notes+1]='\\AuthorsBlockNote{'..asset('envelope')..'}{'..table.concat(emails,';\\allowbreak\\ ' )..'}' end
  quarto.doc.include_file('in-header','latex-author-block.tex')
  quarto.doc.include_text('in-header','\\AtBeginDocument{\\author{\\AuthorsBlockLayout{'..
    table.concat(names,',\\allowbreak\\ ')..'}{'..table.concat(notes,'\n')..'}}}')
  return doc
end
return M
