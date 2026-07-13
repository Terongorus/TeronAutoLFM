--=============================================================================
-- TeronAutoLFM: Presets UI
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.UI = TeronAutoLFM.UI or {}
TeronAutoLFM.UI.Content = TeronAutoLFM.UI.Content or {}
TeronAutoLFM.UI.Content.Presets = {}

--=============================================================================
-- PRIVATE STATE
--=============================================================================
local contentFrame = nil
local scrollChild = nil
local presetRows = {}
local isCondensed = false

--=============================================================================
-- HELPERS
--=============================================================================
local measureFrame, measureFontString
--- Measures the rendered height of a text string at a given width
--- @param text string - The text to measure
--- @param width number - The available width for wrapping
--- @return number - The computed text height in pixels
local function measureTextHeight(text, width)
  if not measureFrame then
    measureFrame = CreateFrame("Frame", nil, UIParent)
    measureFrame:Hide()
    measureFontString = measureFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  end
  measureFrame:SetWidth(width)
  measureFontString:SetWidth(width)
  measureFontString:SetJustifyH("LEFT")
  measureFontString:SetText(text)
  return measureFontString:GetHeight()
end

--- Captures the current selection state from Maestro into a snapshot table
--- @return table - Snapshot containing dungeonNames, raidName, raidSize, roles, customMessage, detailsText, customGroupSize, mode
local function saveSelectionState()
  return {
    dungeonNames = TeronAutoLFM.Core.Maestro.GetState("Selection.DungeonNames"),
    raidName = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidName"),
    raidSize = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidSize"),
    roles = TeronAutoLFM.Core.Maestro.GetState("Selection.Roles"),
    customMessage = TeronAutoLFM.Core.Maestro.GetState("Selection.CustomMessage"),
    detailsText = TeronAutoLFM.Core.Maestro.GetState("Selection.DetailsText"),
    customGroupSize = TeronAutoLFM.Core.Maestro.GetState("Selection.CustomGroupSize"),
    mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")
  }
end

--- Restores a previously saved selection state snapshot back into Maestro
--- @param state table - The snapshot table returned by saveSelectionState
local function restoreSelectionState(state)
  TeronAutoLFM.Core.Maestro.SetState("Selection.DungeonNames", state.dungeonNames)
  TeronAutoLFM.Core.Maestro.SetState("Selection.RaidName", state.raidName)
  TeronAutoLFM.Core.Maestro.SetState("Selection.RaidSize", state.raidSize)
  TeronAutoLFM.Core.Maestro.SetState("Selection.Roles", state.roles)
  TeronAutoLFM.Core.Maestro.SetState("Selection.CustomMessage", state.customMessage)
  TeronAutoLFM.Core.Maestro.SetState("Selection.DetailsText", state.detailsText)
  TeronAutoLFM.Core.Maestro.SetState("Selection.CustomGroupSize", state.customGroupSize)
  TeronAutoLFM.Core.Maestro.SetState("Selection.Mode", state.mode)
end

--- Applies preset data fields to the current Maestro selection state and sets the mode
--- @param presetData table - The preset's stored data (dungeonNames, raidName, roles, etc.)
--- @param presetType string - The resolved preset type: "Custom", "Dungeons", or "Raid"
local function applyPresetData(presetData, presetType)
  if presetData.dungeonNames then TeronAutoLFM.Core.Maestro.SetState("Selection.DungeonNames", presetData.dungeonNames) end
  if presetData.raidName then 
    TeronAutoLFM.Core.Maestro.SetState("Selection.RaidName", presetData.raidName)
    TeronAutoLFM.Core.Maestro.SetState("Selection.RaidSize", presetData.raidSize or 40)
  end
  if presetData.roles then TeronAutoLFM.Core.Maestro.SetState("Selection.Roles", presetData.roles) end
  if presetData.customMessage then TeronAutoLFM.Core.Maestro.SetState("Selection.CustomMessage", presetData.customMessage) end
  if presetData.detailsText then TeronAutoLFM.Core.Maestro.SetState("Selection.DetailsText", presetData.detailsText) end
  if presetData.customGroupSize then TeronAutoLFM.Core.Maestro.SetState("Selection.CustomGroupSize", presetData.customGroupSize) end
  
  if presetType == "Custom" then
    TeronAutoLFM.Core.Maestro.SetState("Selection.Mode", "custom")
  elseif presetType == "Dungeons" then
    TeronAutoLFM.Core.Maestro.SetState("Selection.Mode", "dungeons")
  elseif presetType == "Raid" then
    TeronAutoLFM.Core.Maestro.SetState("Selection.Mode", "raid")
  end
end

--=============================================================================
-- FRAME LIFECYCLE
--=============================================================================
--- Initializes the presets content frame, resolves scroll child, and loads condensed preference
--- @param frame frame - The presets content frame
function TeronAutoLFM.UI.Content.Presets.OnLoad(frame)
  contentFrame = frame
  local scrollFrame = getglobal(frame:GetName() .. "_ScrollFrame")
  if scrollFrame then
    scrollChild = getglobal(scrollFrame:GetName() .. "_ScrollChild")
  end
  
  isCondensed = TeronAutoLFM.Core.Storage.GetPresetsCondensed()
end

--- Handles the presets frame becoming visible; refreshes condensed state and redraws rows
--- @param frame frame - The presets content frame
function TeronAutoLFM.UI.Content.Presets.OnShow(frame)
  isCondensed = TeronAutoLFM.Core.Storage.GetPresetsCondensed()
  TeronAutoLFM.UI.Content.Presets.Refresh()
end

--- Handles the presets frame being hidden; clears all preset rows
--- @param frame frame - The presets content frame
function TeronAutoLFM.UI.Content.Presets.OnHide(frame)
  TeronAutoLFM.UI.Content.Presets.ClearRows()
end

--=============================================================================
-- ROW MANAGEMENT
--=============================================================================
--- Hides and removes all preset row frames from the scroll child
function TeronAutoLFM.UI.Content.Presets.ClearRows()
  for i = 1, table.getn(presetRows) do
    presetRows[i]:Hide()
  end
  presetRows = {}
end

--- Creates a clickable preset row with name, type tag, content preview, and action buttons
--- @param index number - The 1-based index used for unique frame naming
--- @param presetName string - The display name of the preset
--- @param presetData table - The preset's stored configuration data
--- @param isFirst boolean - Whether this is the first row (hides up button)
--- @param isLast boolean - Whether this is the last row (hides down button)
--- @param yOffset number - The vertical offset from the top of the scroll child
--- @return frame - The created preset row button frame
local function createPresetRow(index, presetName, presetData, isFirst, isLast, yOffset)
  -- Ensure lookup tables are built for dungeon/raid lookups
  if TeronAutoLFM.Core.Utils then
    TeronAutoLFM.Core.Utils.EnsureLookupTables()
  end

  local presetType = "Custom"
  if presetData.dungeonNames and table.getn(presetData.dungeonNames) > 0 then
    presetType = "Dungeons"
  elseif presetData.raidName then
    presetType = "Raid"
  end
  
  local rowHeight = 38
  
  local row = CreateFrame("Button", "TeronAutoLFM_PresetRow" .. index, scrollChild)
  row:SetWidth(295)
  row:SetHeight(rowHeight)
  row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
  row.rowHeight = rowHeight
  
  local bg = row:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(0, 0, 0, 0)
  row.bg = bg
  
  local border = row:CreateTexture(nil, "BORDER")
  border:SetTexture(0.3, 0.3, 0.3, 0.5)
  border:SetHeight(1)
  border:SetWidth(295)
  border:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
  
  if isCondensed then
    local oldState = saveSelectionState()
    applyPresetData(presetData, presetType)
    TeronAutoLFM.Logic.Message.RebuildMessage()
    local previewMsg = TeronAutoLFM.Core.Maestro.GetState("Message.ToBroadcast") or ""
    restoreSelectionState(oldState)
    TeronAutoLFM.Logic.Message.RebuildMessage()
    
    local msgHeight = measureTextHeight(previewMsg, 230)
    rowHeight = 26 + msgHeight
    row:SetHeight(rowHeight)
    row.rowHeight = rowHeight
    
    local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -6)
    nameLabel:SetText(presetName)
    nameLabel:SetTextColor(1, 0.82, 0)
    row.nameLabel = nameLabel
    
    local previewText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewText:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -20)
    previewText:SetWidth(230)
    previewText:SetJustifyH("LEFT")
    previewText:SetTextColor(1, 1, 1)
    previewText:SetText(previewMsg)
  else
    local typeTag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeTag:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -6)
    typeTag:SetText("[" .. presetType .. "]")
    typeTag:SetTextColor(1, 1, 1)
    
    local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("LEFT", typeTag, "RIGHT", 4, 0)
    nameLabel:SetText(presetName)
    nameLabel:SetTextColor(1, 0.82, 0)
    row.nameLabel = nameLabel
    
    local xOffset = 5
    local iconSize = 16
    
    if presetData.roles and table.getn(presetData.roles) > 0 then
      local roleTextures = {
        TANK = "Interface\\AddOns\\TeronAutoLFM\\UI\\Textures\\Icons\\Tank",
        HEAL = "Interface\\AddOns\\TeronAutoLFM\\UI\\Textures\\Icons\\Heal",
        DPS = "Interface\\AddOns\\TeronAutoLFM\\UI\\Textures\\Icons\\Dps"
      }
      for i = 1, table.getn(presetData.roles) do
        local role = presetData.roles[i]
        local texture = roleTextures[role]
        if texture then
          local icon = row:CreateTexture(nil, "ARTWORK")
          icon:SetWidth(iconSize)
          icon:SetHeight(iconSize)
          icon:SetPoint("TOPLEFT", row, "TOPLEFT", xOffset, -20)
          icon:SetTexture(texture)
          xOffset = xOffset + iconSize - 2
        end
      end
      xOffset = xOffset + 3
    end
    
    local contentText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    contentText:SetPoint("TOPLEFT", row, "TOPLEFT", xOffset, -20)
    contentText:SetWidth(200)
    contentText:SetJustifyH("LEFT")
    
    if presetType == "Custom" then
      local groupSize = presetData.customGroupSize or 5
      local customMsg = TeronAutoLFM.Logic.Message.ReplaceVariables(presetData.customMessage or "", 1, groupSize, presetData.roles)
      local customHeight = measureTextHeight(customMsg, 200)
      rowHeight = 26 + customHeight
      row:SetHeight(rowHeight)
      row.rowHeight = rowHeight
      
      contentText:SetTextColor(1, 0.82, 0)
      contentText:SetText(customMsg)
    else
      contentText:SetTextColor(0.8, 0.8, 0.8)
      local tagsText = ""
      if presetData.dungeonNames and table.getn(presetData.dungeonNames) > 0 then
        local tags = {}
        for i = 1, table.getn(presetData.dungeonNames) do
          local dungeonName = presetData.dungeonNames[i]
          local dungeonInfo = TeronAutoLFM.Core.Constants.DUNGEONS_BY_NAME[dungeonName]
          if dungeonInfo then
            table.insert(tags, dungeonInfo.data.tag)
          end
        end
        tagsText = table.concat(tags, ", ")
      elseif presetData.raidName then
        local raidInfo = TeronAutoLFM.Core.Constants.RAIDS_BY_NAME[presetData.raidName]
        if raidInfo then
          tagsText = raidInfo.data.tag
          if presetData.raidSize then
            tagsText = tagsText .. " (" .. presetData.raidSize .. ")"
          end
        end
      end
      contentText:SetText(tagsText)
    end
    
    if presetType ~= "Custom" and presetData.detailsText and presetData.detailsText ~= "" then
      local detailsHeight = measureTextHeight(presetData.detailsText, 230)
      rowHeight = 40 + detailsHeight
      row:SetHeight(rowHeight)
      row.rowHeight = rowHeight
      
      local detailsMsg = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      detailsMsg:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -34)
      detailsMsg:SetWidth(230)
      detailsMsg:SetJustifyH("LEFT")
      detailsMsg:SetTextColor(1, 0.82, 0)
      detailsMsg:SetText(presetData.detailsText)
    end
  end
  
  local btnSize = 20
  local btnY = 0
  local btnSpacing = 15
  
  if not isFirst then
    local upBtn = CreateFrame("Button", nil, row)
    upBtn:SetWidth(btnSize)
    upBtn:SetHeight(btnSize)
    local upBtnOffset = isLast and (-2 - btnSpacing) or (-2 - (btnSpacing * 2))
    upBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", upBtnOffset, btnY)
    local upIcon = upBtn:CreateTexture(nil, "ARTWORK")
    upIcon:SetAllPoints()
    upIcon:SetTexture("Interface\\AddOns\\TeronAutoLFM\\UI\\Textures\\Icons\\Up")
    local upHighlight = upBtn:CreateTexture(nil, "HIGHLIGHT")
    upHighlight:SetAllPoints()
    upHighlight:SetTexture("Interface\\AddOns\\TeronAutoLFM\\UI\\Textures\\Icons\\Up")
    upHighlight:SetBlendMode("ADD")
    upBtn:SetScript("OnClick", function()
      if TeronAutoLFM.Core.Storage.MovePresetUp(presetName) then
        TeronAutoLFM.UI.Content.Presets.Refresh()
      end
    end)
  end
  
  if not isLast then
    local downBtn = CreateFrame("Button", nil, row)
    downBtn:SetWidth(btnSize)
    downBtn:SetHeight(btnSize)
    downBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -1 - btnSpacing, btnY)
    local downIcon = downBtn:CreateTexture(nil, "ARTWORK")
    downIcon:SetAllPoints()
    downIcon:SetTexture("Interface\\AddOns\\TeronAutoLFM\\UI\\Textures\\Icons\\Down")
    local downHighlight = downBtn:CreateTexture(nil, "HIGHLIGHT")
    downHighlight:SetAllPoints()
    downHighlight:SetTexture("Interface\\AddOns\\TeronAutoLFM\\UI\\Textures\\Icons\\Down")
    downHighlight:SetBlendMode("ADD")
    downBtn:SetScript("OnClick", function()
      if TeronAutoLFM.Core.Storage.MovePresetDown(presetName) then
        TeronAutoLFM.UI.Content.Presets.Refresh()
      end
    end)
  end
  
  local deleteBtn = CreateFrame("Button", nil, row)
  deleteBtn:SetWidth(btnSize)
  deleteBtn:SetHeight(btnSize)
  deleteBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, btnY)
  local deleteIcon = deleteBtn:CreateTexture(nil, "ARTWORK")
  deleteIcon:SetAllPoints()
  deleteIcon:SetTexture("Interface\\AddOns\\TeronAutoLFM\\UI\\Textures\\Icons\\Close")
  local deleteHighlight = deleteBtn:CreateTexture(nil, "HIGHLIGHT")
  deleteHighlight:SetAllPoints()
  deleteHighlight:SetTexture("Interface\\AddOns\\TeronAutoLFM\\UI\\Textures\\Icons\\Close")
  deleteHighlight:SetBlendMode("ADD")
  deleteBtn:SetScript("OnClick", function()
    TeronAutoLFM.Core.Maestro.Dispatch("Presets.Delete", presetName)
  end)
  
  row:SetScript("OnClick", function()
    TeronAutoLFM.Core.Maestro.Dispatch("Presets.Load", presetName)
  end)
  
  row:SetScript("OnEnter", function()
    bg:SetTexture(0.2, 0.2, 0.2, 0.2)
    local blueColor = TeronAutoLFM.Core.Utils.GetColor("BLUE")
    if blueColor then
      row.nameLabel:SetTextColor(blueColor.r, blueColor.g, blueColor.b)
    end
  end)
  
  row:SetScript("OnLeave", function()
    bg:SetTexture(0, 0, 0, 0)
    row.nameLabel:SetTextColor(1, 0.82, 0)
  end)
  
  return row
end

--- Rebuilds the entire preset list by clearing rows and recreating them from storage
function TeronAutoLFM.UI.Content.Presets.Refresh()
  TeronAutoLFM.UI.Content.Presets.ClearRows()
  
  local presets = TeronAutoLFM.Core.Storage.GetPresets()
  if not presets or not presets.order then return end
  
  local totalPresets = table.getn(presets.order)
  local yOffset = 0
  for i = 1, totalPresets do
    local presetName = presets.order[i]
    local presetData = presets.data[presetName]
    if presetData then
      local isFirst = (i == 1)
      local isLast = (i == totalPresets)
      local row = createPresetRow(i, presetName, presetData, isFirst, isLast, yOffset)
      table.insert(presetRows, row)
      yOffset = yOffset + (row.rowHeight or 0)
    end
  end
  
  scrollChild:SetHeight(yOffset)
  TeronAutoLFM.UI.RowList.UpdateScrollFrame(scrollChild)
end

--=============================================================================
-- SAVE POPUP
--=============================================================================
--- Opens the save preset popup, clears previous input and error state, and focuses the name field
function TeronAutoLFM.UI.Content.Presets.ShowSavePopup()
  local popup = getglobal("TeronAutoLFM_SavePresetPopup")
  if not popup then return end
  
  local errorText = getglobal("TeronAutoLFM_SavePresetPopup_ErrorText")
  if errorText then errorText:Hide() end
  
  local input = getglobal("TeronAutoLFM_SavePresetPopup_NameInput")
  if input then
    input:SetText("")
    input:SetFocus()
  end
  
  popup:Show()
end

--- Validates the preset name input and dispatches a save action, or shows an error if the name already exists
function TeronAutoLFM.UI.Content.Presets.OnSaveConfirm()
  local input = getglobal("TeronAutoLFM_SavePresetPopup_NameInput")
  if not input then return end

  local presetName = input:GetText()
  if presetName and presetName ~= "" then
    local presets = TeronAutoLFM.Core.Storage.GetPresets()
    if presets and presets.data and presets.data[presetName] then
      local errorText = getglobal("TeronAutoLFM_SavePresetPopup_ErrorText")
      if errorText then
        errorText:SetText("Preset already exists")
        errorText:Show()
      end
      return
    end
    TeronAutoLFM.Core.Maestro.Dispatch("Presets.Save", presetName)
    getglobal("TeronAutoLFM_SavePresetPopup"):Hide()
  end
end

--- Closes the save preset popup without saving
function TeronAutoLFM.UI.Content.Presets.OnSaveCancel()
  local popup = getglobal("TeronAutoLFM_SavePresetPopup")
  if popup then popup:Hide() end
end

--=============================================================================
-- INITIALIZATION
--=============================================================================
TeronAutoLFM.Core.SafeRegisterInit("UI.Content.Presets", function()
  TeronAutoLFM.Core.Maestro.Listen(
    "UI.Presets.OnChanged",
    "Presets.Changed",
    function()
      if contentFrame and contentFrame:IsVisible() then
        TeronAutoLFM.UI.Content.Presets.Refresh()
      end
    end,
    { id = "L05" }
  )
end, {
  id = "I17",
  dependencies = { "Logic.Content.Presets" }
})
