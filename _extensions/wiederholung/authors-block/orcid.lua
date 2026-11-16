local M = {}
function M.normalize(value)
  if not value then return nil end
  local id = pandoc.utils.stringify(value):gsub('^https?://orcid%.org/', ''):gsub('/$', ''):upper()
  assert(id:match('^%d%d%d%d%-%d%d%d%d%-%d%d%d%d%-%d%d%d[%dX]$'),
    'authors-block: invalid ORCID syntax: '..id)
  local digits, total = id:gsub('%-', ''), 0
  for i=1,15 do total=(total+tonumber(digits:sub(i,i)))*2 end
  local check=(12-total%11)%11
  assert(digits:sub(16,16)==(check==10 and 'X' or tostring(check)),
    'authors-block: invalid ORCID check digit: '..id)
  return id
end
return M
