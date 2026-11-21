-- Render metadata to styled, native paragraphs for the DOCX title template.
local function inlines(value)
  if pandoc.utils.type(value) == "Inlines" then return value:clone() end
  return pandoc.Inlines({pandoc.Str(pandoc.utils.stringify(value))})
end

local function labelled(text, label, role, zh)
  local attr = pandoc.Attr("", {}, {["custom-style"]=role .. " Label"})
  local out = pandoc.Inlines({pandoc.Span(inlines(label), attr),
    zh and pandoc.Str("　") or pandoc.Space()})
  out:extend(text)
  return pandoc.Para(out)
end

local function paragraph(block, role)
  return pandoc.Div({block}, pandoc.Attr("", {}, {["custom-style"]=role}))
end

return function(meta)
  local zh = pandoc.utils.stringify(meta.lang or "en"):match("^zh") ~= nil
  if meta.abstract then
    local value = meta.abstract
    local blocks = pandoc.utils.type(value) == "Blocks" and value or {pandoc.Para(inlines(value))}
    local body = pandoc.Blocks({})
    local label = meta["abstract-title"] or (zh and "摘要" or "Abstract")
    for i, block in ipairs(blocks) do
      if i == 1 and (block.t == "Para" or block.t == "Plain") then
        body:insert(paragraph(labelled(block.content, label, "Abstract", zh), "Abstract"))
      else
        if i == 1 then body:insert(paragraph(labelled({}, label, "Abstract", zh), "Abstract")) end
        body:insert(paragraph(block, "Abstract Continuation"))
      end
    end
    meta["word-abstract"] = pandoc.MetaBlocks(body)
  end
  if meta.keywords then
    local list = pandoc.utils.type(meta.keywords) == "List" and meta.keywords or {meta.keywords}
    local words = pandoc.Inlines({})
    for _, value in ipairs(list) do
      if pandoc.utils.stringify(value) ~= "" then
        if #words > 0 then
          words:insert(pandoc.Str(zh and "；" or ";"))
          if not zh then words:insert(pandoc.Space()) end
        end
        words:extend(inlines(value))
      end
    end
    if #words > 0 then
      meta["word-keywords"] = pandoc.MetaBlocks({paragraph(
        labelled(words, zh and "关键词" or "Keywords", "Keywords", zh), "Keywords")})
    end
  end
  return meta
end
