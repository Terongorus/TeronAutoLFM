--=============================================================================
-- TeronAutoLFM: Settings UI
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.UI = TeronAutoLFM.UI or {}
TeronAutoLFM.UI.Content = TeronAutoLFM.UI.Content or {}
TeronAutoLFM.UI.Content.Settings = {}

--=============================================================================
-- PRIVATE STATE
--=============================================================================
local panel = nil
local defaultPanelDropdown = nil
local isRestoringState = false  -- Flag to prevent OnClick during restoration

--=============================================================================
-- HELPERS - UI COLORING
--=============================================================================
--- Applies colors to filter checkboxes and labels
--- @param scrollChild frame - The scroll child container frame
local function applyColors(scrollChild)
  if not scrollChild or not TeronAutoLFM.Core.Utils or not TeronAutoLFM.Core.Constants then return end

  -- Color filter checkboxes from COLORS constant (priority 1-5 are dungeon filters)
  for _, color in ipairs(TeronAutoLFM.Core.Constants.COLORS) do
    if color.priority >= 1 and color.priority <= 5 then
      local checkbox = getglobal(scrollChild:GetName().."_FiltersContainer_Filter"..color.name)
      if checkbox then
        TeronAutoLFM.Core.Utils.SetCheckboxColorByName(checkbox, color.name)
      end
    end
  end

  -- Color labels
  TeronAutoLFM.Core.Utils.SetTextColorByName(getglobal(scrollChild:GetName().."_DryRun_Label"), "YELLOW")
  TeronAutoLFM.Core.Utils.SetTextColorByName(getglobal(scrollChild:GetName().."_Debug_Label"), "ORANGE")
end

--=============================================================================
-- HELPERS - UI STATE RESTORATION
--=============================================================================
--- Restores a set of checkboxes from persistent data
--- @param scrollChild frame - The scroll child container frame
--- @param basePath string - The base path for checkbox widget names (e.g., "_FiltersContainer_Filter")
--- @param mapping table - Map of {dataKey = checkboxSuffix} pairs
--- @param dataSource function - Function that returns the persistent data table
local function restoreCheckboxes(scrollChild, basePath, mapping, dataSource)
  if not scrollChild then return end

  local data = dataSource()
  for key, checkboxSuffix in pairs(mapping) do
      local checkbox = getglobal(scrollChild:GetName() .. basePath .. checkboxSuffix)
      if checkbox then
          local value = data[key]
          if value == nil then value = true end  -- Default to enabled
          checkbox:SetChecked(value and 1 or nil)
      end
  end
end

--- Restores a radio button pair (on/off) from persistent data
--- @param scrollChild frame - The scroll child container frame
--- @param onPath string - Widget path for the "On" radio button (e.g., "_DarkUIContainer_OnRadio")
--- @param offPath string - Widget path for the "Off" radio button (e.g., "_DarkUIContainer_OffRadio")
--- @param getValue function - Function that returns the boolean value from persistent storage
local function restoreRadioPair(scrollChild, onPath, offPath, getValue)
  if not scrollChild then return end

  local value = getValue()
  local onRadio = getglobal(scrollChild:GetName() .. onPath)
  local offRadio = getglobal(scrollChild:GetName() .. offPath)

  if onRadio and offRadio then
      -- Force uncheck both first
      onRadio:SetChecked(nil)
      offRadio:SetChecked(nil)
      -- Then check the correct one
      if value then
          onRadio:SetChecked(1)
      else
          offRadio:SetChecked(1)
      end
  end
end

--- Generic radio button pair click handler (on/off, show/hide, etc.)
--- @param radioButtons table - Table with { on = frame, off = frame }
--- @param isOn boolean - True to check 'on' radio, false to check 'off' radio
--- @param callback function|nil - Optional callback function to call with the boolean value
local function handleRadioClick(radioButtons, isOn, callback)
  if not radioButtons or not radioButtons.on or not radioButtons.off then return end

  if isOn then
  radioButtons.on:SetChecked(1)
  radioButtons.off:SetChecked(nil)
  else
  radioButtons.on:SetChecked(nil)
  radioButtons.off:SetChecked(1)
  end

  if callback then
  callback(isOn)
  end
end

--=============================================================================
-- INITIALIZATION
--=============================================================================
--- XML OnLoad callback - initializes the Settings panel UI
--- @param frame frame - The Settings panel frame
function TeronAutoLFM.UI.Content.Settings.OnLoad(frame)
  panel = frame
  applyColors(TeronAutoLFM.UI.RowList.GetScrollChild(panel))
  TeronAutoLFM.UI.Content.Settings.CreateDefaultPanelDropdown()
end

--- XML OnShow callback - restores saved option states when panel is shown
--- @param frame frame - The Settings panel frame
function TeronAutoLFM.UI.Content.Settings.OnShow(frame)
  applyColors(TeronAutoLFM.UI.RowList.GetScrollChild(panel))
  TeronAutoLFM.UI.Content.Settings.RestoreState()
end

--- Creates the default panel dropdown menu using WoW's native dropdown system
--- Allows user to select which panel (Dungeons, Raids, Quests, Messaging, Presets) opens by default
function TeronAutoLFM.UI.Content.Settings.CreateDefaultPanelDropdown()
  local scrollChild = TeronAutoLFM.UI.RowList.GetScrollChild(panel)
  local placeholderFrame = getglobal(scrollChild:GetName().."_DefaultPanelContainer_DropdownPlaceholder")
  if not placeholderFrame then return end

  -- Create dropdown using WoW's native dropdown system
  defaultPanelDropdown = CreateFrame("Frame", panel:GetName().."_DefaultPanelDropdown", placeholderFrame, "UIDropDownMenuTemplate")
  defaultPanelDropdown:SetPoint("TOPLEFT", placeholderFrame, "TOPLEFT", 0, 0)
  UIDropDownMenu_SetWidth(135, defaultPanelDropdown)

  -- Initialize dropdown
  UIDropDownMenu_Initialize(defaultPanelDropdown, function(self)
      local items = {"Dungeons", "Raids", "Quests", "Messaging", "Presets"}
      for i = 1, table.getn(items) do
          local itemName = items[i]
          local info = {}
          info.text = itemName
          info.value = itemName
          info.func = function()
              UIDropDownMenu_SetSelectedValue(defaultPanelDropdown, itemName)
              UIDropDownMenu_SetText(itemName, defaultPanelDropdown)

              -- Save to persistent storage
              local internalName = string.lower(itemName)
              TeronAutoLFM.Core.Storage.SetDefaultPanel(internalName)

              -- Log the change
              TeronAutoLFM.Core.Utils.LogInfo("Set default panel to " .. itemName)
          end
          info.checked = nil
          UIDropDownMenu_AddButton(info)
      end
  end)

  -- Set initial value from saved setting
  local defaultPanel = TeronAutoLFM.Core.Storage.GetDefaultPanel()
  if not defaultPanel then
      defaultPanel = "dungeons"
  end
  -- Capitalize first letter for display
  local displayName = string.upper(string.sub(defaultPanel, 1, 1)) .. string.sub(defaultPanel, 2)
  UIDropDownMenu_SetSelectedValue(defaultPanelDropdown, displayName)
  UIDropDownMenu_SetText(displayName, defaultPanelDropdown)
end

--=============================================================================
-- EVENT HANDLERS - DUNGEON FILTERS
--=============================================================================
--- Handles dungeon filter checkbox toggle events
--- Saves to persistent storage and refreshes dungeon list UI
--- @param filterId string - Color filter ID (e.g., "GRAY", "GREEN", "YELLOW", "ORANGE", "RED")
--- @param isEnabled boolean - New state of the filter (true = enabled, false = disabled)
function TeronAutoLFM.UI.Content.Settings.OnFilterToggle(filterId, isEnabled)
  if isRestoringState then return end

  -- Update local state in Logic layer
  if TeronAutoLFM.Logic.Content.Settings and TeronAutoLFM.Logic.Content.Settings.SetDungeonFilter then
      TeronAutoLFM.Logic.Content.Settings.SetDungeonFilter(filterId, isEnabled)
  end

  -- Save to persistent storage
  if TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.SetDungeonFilter then
      TeronAutoLFM.Core.Storage.SetDungeonFilter(filterId, isEnabled)
  end

  -- Clear dungeon cache to force rebuild with new filter
  if TeronAutoLFM.Logic.Content.Dungeons and TeronAutoLFM.Logic.Content.Dungeons.ClearCache then
      TeronAutoLFM.Logic.Content.Dungeons.ClearCache()
  end

  -- Refresh dungeons UI if visible
  if TeronAutoLFM.UI.Content.Dungeons and TeronAutoLFM.UI.Content.Dungeons.Refresh then
      TeronAutoLFM.UI.Content.Dungeons.Refresh()
  end
end

--=============================================================================
-- EVENT HANDLERS - MINIMAP RADIO BUTTONS
--=============================================================================
--- Handles minimap visibility radio button clicks (Show/Hide)
--- @param isShow boolean - True to show minimap button, false to hide
function TeronAutoLFM.UI.Content.Settings.OnMinimapRadioClick(isShow)
  if isRestoringState then return end

  local scrollChild = TeronAutoLFM.UI.RowList.GetScrollChild(panel)
  if not scrollChild then return end

  local radios = {
  on = getglobal(scrollChild:GetName().."_MinimapContainer_ShowRadio"),
  off = getglobal(scrollChild:GetName().."_MinimapContainer_HideRadio")
  }

  handleRadioClick(radios, isShow, function(value)
  if TeronAutoLFM.Logic.Content.Settings then
    TeronAutoLFM.Logic.Content.Settings.ToggleMinimapVisibility(value)
  end
  end)
end

--- Handles minimap reset button click - resets minimap button to default position
function TeronAutoLFM.UI.Content.Settings.OnMinimapResetClick()
  -- Delegate to Logic layer
  if TeronAutoLFM.Logic.Content.Settings then
      TeronAutoLFM.Logic.Content.Settings.ResetMinimapPosition()
  end
end

--=============================================================================
-- EVENT HANDLERS - DARKUI RADIO BUTTONS
--=============================================================================
--- Handles dark mode radio button clicks (On/Off)
--- @param isEnabled boolean - True to enable dark mode, false to disable
function TeronAutoLFM.UI.Content.Settings.OnDarkUIRadioClick(isEnabled)
  if isRestoringState then return end

  local scrollChild = TeronAutoLFM.UI.RowList.GetScrollChild(panel)
  if not scrollChild then return end

  local radios = {
  on = getglobal(scrollChild:GetName().."_DarkUIContainer_OnRadio"),
  off = getglobal(scrollChild:GetName().."_DarkUIContainer_OffRadio")
  }

  handleRadioClick(radios, isEnabled, function(value)
  if TeronAutoLFM.Logic.Content.Settings then
    TeronAutoLFM.Logic.Content.Settings.ToggleDarkMode(value)
  end
  end)
end

--- Handles reload button click - reloads the UI to apply dark mode changes
function TeronAutoLFM.UI.Content.Settings.OnDarkUIReloadClick()
  ReloadUI()
end

--=============================================================================
-- EVENT HANDLERS - MESSAGE MODE RADIO BUTTONS
--=============================================================================
--- Handles message mode radio button clicks (Details/Custom)
--- @param mode string - "details" for details mode, "custom" for custom mode
function TeronAutoLFM.UI.Content.Settings.OnMessagingModeRadioClick(mode)
  if isRestoringState then return end

  local scrollChild = TeronAutoLFM.UI.RowList.GetScrollChild(panel)
  if not scrollChild then return end

  local isDetails = (mode == "details")
  local radios = {
  on = getglobal(scrollChild:GetName().."_MessagingModeContainer_SimpleRadio"),
  off = getglobal(scrollChild:GetName().."_MessagingModeContainer_CustomRadio")
  }

  handleRadioClick(radios, isDetails, function(value)
  local isCustom = not value
  if TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.SetCustomInput then
    TeronAutoLFM.Core.Storage.SetCustomInput(isCustom)
    TeronAutoLFM.Core.Utils.LogInfo("Set custom input mode to " .. tostring(isCustom))
  end
  end)
end

--=============================================================================
-- EVENT HANDLERS - PREVIEW LINES RADIO BUTTONS
--=============================================================================
--- Handles preview message lines radio button clicks (1 line / 2 lines)
--- @param lines number - 1 for single line, 2 for two lines
function TeronAutoLFM.UI.Content.Settings.OnPreviewLinesRadioClick(lines)
  if isRestoringState then return end

  local scrollChild = TeronAutoLFM.UI.RowList.GetScrollChild(panel)
  if not scrollChild then return end

  local is1Line = (lines == 1)
  local radios = {
  on = getglobal(scrollChild:GetName().."_PreviewLinesContainer_1LineRadio"),
  off = getglobal(scrollChild:GetName().."_PreviewLinesContainer_2LinesRadio")
  }

  handleRadioClick(radios, is1Line, function(value)
  local lineCount = value and 1 or 2
  if TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.SetPreviewMessageLines then
    TeronAutoLFM.Core.Storage.SetPreviewMessageLines(lineCount)
    TeronAutoLFM.Core.Utils.LogInfo("Set preview message lines to " .. lineCount)

    -- Update the message preview immediately
    local currentMessage = TeronAutoLFM.Core.Maestro.GetState("Message.ToBroadcast")
    if TeronAutoLFM.UI.MainFrame and TeronAutoLFM.UI.MainFrame.UpdateMessagePreview and currentMessage then
      TeronAutoLFM.UI.MainFrame.UpdateMessagePreview(currentMessage)
    end
  end
  end)
end

--=============================================================================
-- EVENT HANDLERS - PRESETS RADIO BUTTONS
--=============================================================================
--- Handles presets view mode radio button clicks (Condensed/Full)
--- @param isCondensed boolean - True for condensed view, false for full view
function TeronAutoLFM.UI.Content.Settings.OnPresetsRadioClick(isCondensed)
  if isRestoringState then return end

  local scrollChild = TeronAutoLFM.UI.RowList.GetScrollChild(panel)
  if not scrollChild then return end

  local radios = {
  on = getglobal(scrollChild:GetName().."_PresetsContainer_CondensedRadio"),
  off = getglobal(scrollChild:GetName().."_PresetsContainer_FullRadio")
  }

  handleRadioClick(radios, isCondensed, function(value)
  if TeronAutoLFM.Logic.Content.Settings then
    TeronAutoLFM.Logic.Content.Settings.TogglePresetsCondensed(value)
  end
  end)
end

--=============================================================================
-- EVENT HANDLERS - BROADCAST INTERVAL SLIDER
--=============================================================================
--- Handles broadcast interval slider value changes
--- Updates both the display label and saves the value to Broadcaster
--- @param slider frame - The broadcast interval slider
function TeronAutoLFM.UI.Content.Settings.OnBroadcastIntervalSliderChanged(slider)
  if isRestoringState then return end

  local value = math.floor(slider:GetValue())

  -- Update display label (inside SliderValueFrame)
  local container = slider:GetParent()
  local valueLabel = container and getglobal(container:GetName() .. "_SliderValueFrame_Text")
  if valueLabel then
    valueLabel:SetText(value .. " secs")
  end

  -- Save to Broadcaster (which will save to persistent storage)
  if TeronAutoLFM.Logic and TeronAutoLFM.Logic.Broadcaster and TeronAutoLFM.Logic.Broadcaster.SetInterval then
    TeronAutoLFM.Logic.Broadcaster.SetInterval(value)
  end
end

--- Handles broadcast interval slider mousewheel scrolling
--- @param slider frame - The broadcast interval slider
--- @param delta number - Mouse wheel direction (positive = scroll up, negative = scroll down)
function TeronAutoLFM.UI.Content.Settings.OnBroadcastIntervalSliderMouseWheel(slider, delta)
  local value = slider:GetValue()
  local step = delta > 0 and 10 or -10
  local min = TeronAutoLFM.Core.Constants.MIN_BROADCAST_INTERVAL or 30
  local max = TeronAutoLFM.Core.Constants.MAX_BROADCAST_INTERVAL or 120
  local newValue = math.max(min, math.min(max, value + step))
  slider:SetValue(newValue)
end

--=============================================================================
-- EVENT HANDLERS - BOTTOM CHECKBOXES
--=============================================================================
--- Handles dry run checkbox toggle - enables/disables message simulation mode
--- @param isEnabled boolean - True to enable dry run mode, false to disable
function TeronAutoLFM.UI.Content.Settings.OnDryRunToggle(isEnabled)
  -- Delegate to Logic layer
  if TeronAutoLFM.Logic.Content.Settings then
      TeronAutoLFM.Logic.Content.Settings.ToggleDryRun(isEnabled)
  end
end

--- Handles the "show custom instances" checkbox toggle - shows/hides Turtle WoW
--- custom dungeons/raids in the Dungeons and Raids lists (vanilla always shown)
--- @param isEnabled boolean - True to show custom instances, false to hide them
function TeronAutoLFM.UI.Content.Settings.OnShowCustomInstancesToggle(isEnabled)
  if isRestoringState then return end

  -- Delegate to Logic layer
  if TeronAutoLFM.Logic.Content.Settings then
      TeronAutoLFM.Logic.Content.Settings.ToggleShowCustomInstances(isEnabled)
  end
end

--- Handles a "My Role" checkbox click - sets (or clears, if it's already
--- set to the same role) the leader's own role via Selection.SetMyRole.
--- The checkbox's own visual state is resynced from Selection.MyRole
--- afterward (see UpdateMyRoleCheckboxes), rather than trusting WoW's
--- native toggle, since clicking an already-selected role should visually
--- uncheck it rather than stay checked.
--- @param role string - "TANK", "HEAL", or "DPS"
function TeronAutoLFM.UI.Content.Settings.OnMyRoleClick(role)
  if isRestoringState then return end
  TeronAutoLFM.Core.Maestro.Dispatch("Selection.SetMyRole", role)
  TeronAutoLFM.UI.Content.Settings.UpdateMyRoleCheckboxes()
end

--- Syncs the three "My Role" checkboxes with Selection.MyRole state
function TeronAutoLFM.UI.Content.Settings.UpdateMyRoleCheckboxes()
  if not panel then return end

  local scrollChild = TeronAutoLFM.UI.RowList.GetScrollChild(panel)
  if not scrollChild then return end

  local myRole = TeronAutoLFM.Core.Maestro.GetState("Selection.MyRole")
  local prefix = scrollChild:GetName() .. "_MyRoleContainer_"

  local boxes = {
    TANK = getglobal(prefix .. "TankCheck"),
    HEAL = getglobal(prefix .. "HealCheck"),
    DPS = getglobal(prefix .. "DPSCheck")
  }

  for role, box in pairs(boxes) do
    if box then
      box:SetChecked(myRole == role and 1 or nil)
    end
  end
end

--- Handles debug window checkbox toggle - shows/hides the debug console
--- @param isEnabled boolean - True to show debug window, false to hide
function TeronAutoLFM.UI.Content.Settings.OnDebugToggle(isEnabled)
  if isRestoringState then return end

  -- Call Debug window show/hide directly
  if TeronAutoLFM.Components.Debug then
      if isEnabled then
          TeronAutoLFM.Components.Debug.Show()
      else
          TeronAutoLFM.Components.Debug.Hide()
      end
  end
end

--- Syncs the debug checkbox with the actual debug window state
--- Called after tab changes to ensure checkbox reflects if debug window is open
function TeronAutoLFM.UI.Content.Settings.SyncDebugCheckbox()
  if not panel then return end

  local scrollChild = TeronAutoLFM.UI.RowList.GetScrollChild(panel)
  if not scrollChild then return end

  local debugCheckbox = getglobal(scrollChild:GetName().."_Debug")
  if debugCheckbox then
      -- Check if debug window is actually visible
      local isDebugWindowOpen = false
      if TeronAutoLFM.Components.Debug then
          local debugFrame = getglobal("TeronAutoLFM_DebugWindow")
          if debugFrame and debugFrame:IsVisible() then
              isDebugWindowOpen = true
          end
      end
      debugCheckbox:SetChecked(isDebugWindowOpen and 1 or nil)
  end
end

--=============================================================================
-- PUBLIC API
--=============================================================================
--- Updates a dungeon filter checkbox state (called by Logic layer)
--- @param colorId string - Color filter ID to update
--- @param isEnabled boolean - New state of the filter
function TeronAutoLFM.UI.Content.Settings.UpdateFilterCheckbox(colorId, isEnabled)
  if not panel then return end

  local scrollChild = TeronAutoLFM.UI.RowList.GetScrollChild(panel)
  if not scrollChild then return end

  local checkbox = getglobal(scrollChild:GetName().."_FiltersContainer_Filter"..colorId)
  if checkbox then
      checkbox:SetChecked(isEnabled and 1 or nil)
  end
end

--- Restores all option states from persistent storage
--- Called when Settings panel is shown to sync UI with saved settings
function TeronAutoLFM.UI.Content.Settings.RestoreState()
  if not panel then return end

  isRestoringState = true

  local scrollChild = TeronAutoLFM.UI.RowList.GetScrollChild(panel)
  if scrollChild then
      -- Build filter mapping from COLORS constant (priority 1-5)
      local filterMapping = {}
      if TeronAutoLFM.Core.Constants and TeronAutoLFM.Core.Constants.COLORS then
        for _, color in ipairs(TeronAutoLFM.Core.Constants.COLORS) do
          if color.priority >= 1 and color.priority <= 5 then
            filterMapping[color.name] = color.name
          end
        end
      end

      -- Restore dungeon filters using helper
      restoreCheckboxes(scrollChild, "_FiltersContainer_Filter", filterMapping, TeronAutoLFM.Core.Storage.GetDungeonFilters)

      -- Restore minimap visibility using helper
      restoreRadioPair(scrollChild, "_MinimapContainer_ShowRadio", "_MinimapContainer_HideRadio",
          function() return not TeronAutoLFM.Core.Storage.GetMinimapHidden() end)

      -- Restore DarkUI using helper
      restoreRadioPair(scrollChild, "_DarkUIContainer_OnRadio", "_DarkUIContainer_OffRadio",
          TeronAutoLFM.Core.Storage.GetDarkMode)

      -- Restore preview message lines using helper
      restoreRadioPair(scrollChild, "_PreviewLinesContainer_1LineRadio", "_PreviewLinesContainer_2LinesRadio",
          function() return TeronAutoLFM.Core.Storage.GetPreviewMessageLines() == 1 end)

      -- Restore messaging view using helper
      restoreRadioPair(scrollChild, "_MessagingModeContainer_SimpleRadio", "_MessagingModeContainer_CustomRadio",
          function() return not TeronAutoLFM.Core.Storage.GetCustomInput() end)

      -- Restore presets condensed using helper
      restoreRadioPair(scrollChild, "_PresetsContainer_CondensedRadio", "_PresetsContainer_FullRadio",
          TeronAutoLFM.Core.Storage.GetPresetsCondensed)

      -- Restore default panel dropdown
      local defaultPanel = TeronAutoLFM.Core.Storage.GetDefaultPanel()
      if defaultPanelDropdown and defaultPanel then
          -- Capitalize first letter for display
          local displayName = string.upper(string.sub(defaultPanel, 1, 1)) .. string.sub(defaultPanel, 2)
          UIDropDownMenu_SetSelectedValue(defaultPanelDropdown, displayName)
          UIDropDownMenu_SetText(displayName, defaultPanelDropdown)
      end

      -- Restore broadcast interval slider
      local broadcastIntervalSlider = getglobal(scrollChild:GetName().."_BroadcastIntervalContainer_Slider")
      if broadcastIntervalSlider and TeronAutoLFM.Core.Maestro then
        local interval = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.Interval") or 60
        broadcastIntervalSlider:SetValue(interval)
        local valueLabel = getglobal(scrollChild:GetName() .. "_BroadcastIntervalContainer_SliderValueFrame_Text")
        if valueLabel then
          valueLabel:SetText(interval .. " secs")
        end
      end

      -- Restore dry run
      local dryRun = TeronAutoLFM.Core.Storage.GetDryRun()
      local dryRunCheckbox = getglobal(scrollChild:GetName().."_DryRun")
      if dryRunCheckbox then dryRunCheckbox:SetChecked(dryRun and 1 or nil) end

      -- Restore show custom instances
      local showCustom = TeronAutoLFM.Core.Storage.GetShowCustomInstances()
      local showCustomCheckbox = getglobal(scrollChild:GetName().."_ShowCustomInstances")
      if showCustomCheckbox then showCustomCheckbox:SetChecked(showCustom and 1 or nil) end

      -- Restore my role
      TeronAutoLFM.UI.Content.Settings.UpdateMyRoleCheckboxes()

      -- Restore debug checkbox to reflect actual window state
      TeronAutoLFM.UI.Content.Settings.SyncDebugCheckbox()
  end

  isRestoringState = false
end
