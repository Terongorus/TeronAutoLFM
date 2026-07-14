--=============================================================================
-- TeronAutoLFM: Dungeons UI
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.UI = TeronAutoLFM.UI or {}
TeronAutoLFM.UI.Content = TeronAutoLFM.UI.Content or {}

--=============================================================================
-- ROW CREATION
--=============================================================================
--- Creates and updates dungeon rows in the scroll frame
--- Reuses existing row frames for performance
--- @param scrollChild frame - The scroll child frame to populate
local function CreateDungeonRows(scrollChild)
  if not scrollChild then
    return
  end

  local sorted = TeronAutoLFM.Logic.Content.Dungeons.GetSortedDungeons()
  if not sorted then
    return
  end

  local rowHeight = TeronAutoLFM.Core.Constants.ROW_HEIGHT
  local numRows = table.getn(sorted)
  local scrollHeight = TeronAutoLFM.UI.RowList.CalculateScrollHeight(numRows, rowHeight)

  scrollChild:SetHeight(scrollHeight)

  for i = 1, numRows do
    local entry = sorted[i]
    local dungeon = entry.dungeon
    local color = entry.color
    local rowName = "TeronAutoLFM_DungeonRow" .. i

    -- Get or create row using factory
    local row = TeronAutoLFM.UI.RowList.GetOrCreateRow(rowName, scrollChild, "TeronAutoLFM_DungeonRow_Template", i, rowHeight)
    if not row then
      return
    end
    row.dungeonIndex = entry.index

    local checkbox = getglobal(rowName .. "_CheckButton")
    local label = getglobal(rowName .. "_Label")
    local secondaryLabel = getglobal(rowName .. "_SecondaryLabel")

    if label then
      label:SetText(dungeon.name)
      label:SetTextColor(color.r, color.g, color.b)
    end

    if secondaryLabel then
      secondaryLabel:SetText("(" .. dungeon.levelMin .. " - " .. dungeon.levelMax .. ")")
      secondaryLabel:SetTextColor(color.r, color.g, color.b)
    end

    -- Setup hover effect
    local elements = {}
    if label then table.insert(elements, label) end
    if secondaryLabel then table.insert(elements, secondaryLabel) end
    TeronAutoLFM.UI.RowList.SetupHover(checkbox, row, color, elements)

    if checkbox then
      local selectedDungeonNames = TeronAutoLFM.Core.Maestro.GetState("Selection.DungeonNames") or {}
      local isSelected = false
      for j = 1, table.getn(selectedDungeonNames) do
        if selectedDungeonNames[j] == dungeon.name then
          isSelected = true
          break
        end
      end
      checkbox:SetChecked(isSelected)

      checkbox:SetScript("OnClick", function()
        -- Clicking a checkbox doesn't naturally release a focused edit box in WoW
        TeronAutoLFM.Core.Utils.ClearFocusedEditBox()
        TeronAutoLFM.Core.Maestro.Dispatch("Selection.ToggleDungeon", row.dungeonIndex)
      end)
    end

    row:Show()
  end

  -- Force scroll frame update
  TeronAutoLFM.UI.RowList.UpdateScrollFrame(scrollChild)
end

--=============================================================================
-- PUBLIC API
--=============================================================================
-- Create panel using ContentPanel factory
-- Init Handler ID will be auto-assigned by ContentPanel factory
TeronAutoLFM.UI.Content.Dungeons = TeronAutoLFM.UI.CreateContentPanel({
  name = "Dungeons",
  rowTemplatePrefix = "TeronAutoLFM_DungeonRow",
  createRowsFunc = CreateDungeonRows,
  clearCacheFunc = TeronAutoLFM.Logic.Content.Dungeons.ClearCache,
  listeningEvent = "Selection.Changed",
  listenerDependencies = { "Logic.Selection" },
  listenerId = "L10"
})
