--=============================================================================
-- TeronAutoLFM: Quests UI
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.UI = TeronAutoLFM.UI or {}
TeronAutoLFM.UI.Content = TeronAutoLFM.UI.Content or {}

--=============================================================================
-- ROW CREATION
--=============================================================================
--- Creates and updates quest rows in the scroll frame with zone tooltips
--- @param scrollChild frame - The scroll child frame to populate
local function CreateQuestRows(scrollChild)
  if not scrollChild then
    return
  end

  local sorted = TeronAutoLFM.Logic.Content.Quests.GetSortedQuests()
  if not sorted then
    return
  end

  local rowHeight = TeronAutoLFM.Core.Constants.ROW_HEIGHT
  local numRows = table.getn(sorted)

  scrollChild:SetHeight(TeronAutoLFM.UI.RowList.CalculateScrollHeight(numRows, rowHeight))

  for i = 1, numRows do
    local entry = sorted[i]
    local color = entry.color
    local rowName = "TeronAutoLFM_QuestRow" .. i

    -- Get or create row using factory
    local row = TeronAutoLFM.UI.RowList.GetOrCreateRow(rowName, scrollChild, "TeronAutoLFM_QuestRow_Template", i, rowHeight)
    if not row then
      return
    end
    row.questIndex = entry.index
    row.questZone = entry.zone

    local checkbox = getglobal(rowName .. "_CheckButton")
    local label = getglobal(rowName .. "_Label")
    local secondaryLabel = getglobal(rowName .. "_SecondaryLabel")

    if label then
      local mainText = "[" .. entry.level .. "] " .. entry.name
      label:SetText(mainText)
      label:SetTextColor(color.r, color.g, color.b)
    end

    if secondaryLabel then
      local rightText = ""
      if entry.tag then
        rightText = "(" .. entry.tag .. ")"
      end
      secondaryLabel:SetText(rightText)
      secondaryLabel:SetTextColor(color.r, color.g, color.b)
    end

    -- Setup hover effect with tooltip
    local elements = {}
    if label then table.insert(elements, label) end
    if secondaryLabel then table.insert(elements, secondaryLabel) end
    TeronAutoLFM.UI.RowList.SetupHover(checkbox, row, color, elements, {
      tooltipZone = entry.zone
    })

    if checkbox then
      -- Sync checkbox state with custom message (check if quest link is present)
      local isSelected = TeronAutoLFM.Logic.Content.Quests.IsQuestSelected(entry.index)
      checkbox:SetChecked(isSelected)

      checkbox:SetScript("OnClick", function()
        local parentRow = this:GetParent()
        if parentRow and parentRow.questIndex then
          -- Dispatch command to toggle quest link in custom message
          TeronAutoLFM.Core.Maestro.Dispatch("Quests.Toggle", parentRow.questIndex)
        end
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
TeronAutoLFM.UI.Content.Quests = TeronAutoLFM.UI.CreateContentPanel({
  name = "Quests",
  rowTemplatePrefix = "TeronAutoLFM_QuestRow",
  createRowsFunc = CreateQuestRows,
  clearCacheFunc = TeronAutoLFM.Logic.Content.Quests.ClearCache,
  listeningEvent = "Selection.Changed",
  listenerDependencies = {},
  listenerId = "L12"
})

-- Additional command registration for QuestsList.Refresh (legacy support)
TeronAutoLFM.Core.SafeRegisterInit("UI.Quests.Commands", function()
  TeronAutoLFM.Core.Maestro.RegisterCommand("QuestsList.Refresh", TeronAutoLFM.UI.Content.Quests.Refresh, { id = "C21" })
end, { id = "I18", dependencies = { "UI.Quests" } })
