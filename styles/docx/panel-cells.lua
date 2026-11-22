-- Quarto inserts a literal space paragraph between adjacent Word floats.
-- Inside a panel it would consume a layout cell and shift subsequent widths.
local function remove_panel_separators(panel)
  local attr=panel.attributes
  if not (attr.layout or attr["layout-ncol"] or attr["layout-nrow"]) then return end
  local blocks=quarto.utils.as_blocks(panel.content)
  local content=blocks:filter(function(block)
    return not (block.t=="Para" and #block.content==1 and block.content[1].t=="Str"
      and block.content[1].text==" ")
  end)
  if #content~=#blocks then
    panel.content=content
    return panel
  end
end

return {{FloatRefTarget=remove_panel_separators, Div=remove_panel_separators}}
