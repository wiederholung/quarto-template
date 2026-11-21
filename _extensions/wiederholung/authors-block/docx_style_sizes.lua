-- Resolve the paragraph sizes that Word will use for inline drawing geometry.
local W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

local function child(node, name)
  for _, element in ipairs(node and node.el or {}) do
    if element.nsURI == W and element.name == name then return element end
  end
end

return function(reference)
  if not reference or not pandoc.zip or not pandoc.system.read_file then return {} end
  local readable, bytes = pcall(pandoc.system.read_file, reference)
  if not readable then return {} end
  local archive = pandoc.zip.Archive(bytes)
  local part = archive.entries:find_if(function(e) return e.path == "word/styles.xml" end)
  if not part then return {} end
  local root = require("vendor.slaxdom"):dom(part:contents()).root
  local ids, names = {}, {}
  for _, style in ipairs(root.el) do
    if style.name == "style" and style.attr.type == "paragraph" then
      ids[style.attr.styleId] = style
      local name = child(style, "name")
      if name then names[name.attr.val:lower()] = style end
    end
  end
  local defaults = child(child(root, "docDefaults"), "rPrDefault")
  local function point_size(name)
    local style = names[name:lower()] or ids[name]
    if not style then return nil end
    local seen = {}
    while style and not seen[style] do
      seen[style] = true
      local size = child(child(style, "rPr"), "sz")
      if size and tonumber(size.attr.val) then return tonumber(size.attr.val) / 2 end
      local base = child(style, "basedOn")
      style = base and ids[base.attr.val]
    end
    local size = child(child(defaults, "rPr"), "sz")
    return size and tonumber(size.attr.val) and tonumber(size.attr.val) / 2
  end
  return {author = point_size("Author"), note = point_size("Affiliation")}
end
