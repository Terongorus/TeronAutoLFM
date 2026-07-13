--=============================================================================
-- TeronAutoLFM: Settings Logic
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Logic = TeronAutoLFM.Logic or {}
TeronAutoLFM.Logic.Content = TeronAutoLFM.Logic.Content or {}
TeronAutoLFM.Logic.Content.Settings = {}

--=============================================================================
-- PRIVATE STATE
--=============================================================================
-- Initialize with default values (all filters enabled)
local dungeonFilters = {
  GRAY = true,
  GREEN = true,
  YELLOW = true,
  ORANGE = true,
  RED = true
}

--=============================================================================
-- INITIALIZATION
--=============================================================================
--- Loads all setting values from persistent storage into local state
--- Called during initialization to restore saved settings (dungeon filters, etc.)
function TeronAutoLFM.Logic.Content.Settings.LoadSettings()
  -- Load dungeon filters
  if TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.GetDungeonFilters then
      local filters = TeronAutoLFM.Core.Storage.GetDungeonFilters()
      if filters then
          if TeronAutoLFM.Core.Storage.DeepCopy then
              dungeonFilters = TeronAutoLFM.Core.Storage.DeepCopy(filters)
          else
              dungeonFilters = filters
          end
      end
  end
end

--- Initializes settings logic (currently no commands to register)
function TeronAutoLFM.Logic.Content.Settings.Init()
  -- No commands to register anymore
  -- Filter toggles are now handled directly by UI layer
end

--=============================================================================
-- PUBLIC GETTERS
--=============================================================================
--- Returns the current dungeon filter states for all difficulty colors
--- @return table - Table with color names as keys (GRAY, GREEN, YELLOW, ORANGE, RED) and boolean values
function TeronAutoLFM.Logic.Content.Settings.GetDungeonFilters()
  return dungeonFilters
end

--=============================================================================
-- PUBLIC SETTERS
--=============================================================================
--- Updates a single dungeon filter state in local memory
--- @param colorId string - Color filter ID (e.g., "GRAY", "GREEN", "YELLOW", "ORANGE", "RED")
--- @param isEnabled boolean - New state of the filter (true = enabled, false = disabled)
--- @return boolean - True if filter was set, false on validation error
function TeronAutoLFM.Logic.Content.Settings.SetDungeonFilter(colorId, isEnabled)
  -- Validate colorId parameter
  if type(colorId) ~= "string" then
    TeronAutoLFM.Core.Utils.LogError("SetDungeonFilter: colorId must be string, got " .. type(colorId))
    return false
  end

  -- Validate isEnabled parameter
  if type(isEnabled) ~= "boolean" then
    TeronAutoLFM.Core.Utils.LogError("SetDungeonFilter: isEnabled must be boolean, got " .. type(isEnabled))
    return false
  end

  -- Initialize missing color keys with default value (enabled)
  if dungeonFilters[colorId] == nil then
    dungeonFilters[colorId] = true
  end

  dungeonFilters[colorId] = isEnabled
  return true
end

--=============================================================================
-- MINIMAP MANAGEMENT
--=============================================================================
--- Toggles minimap button visibility and saves the setting
--- @param isShow boolean - True to show the minimap button, false to hide it
--- @return boolean|nil - False on validation error
function TeronAutoLFM.Logic.Content.Settings.ToggleMinimapVisibility(isShow)
  -- Validate isShow parameter
  if type(isShow) ~= "boolean" then
    TeronAutoLFM.Core.Utils.LogError("ToggleMinimapVisibility: isShow must be boolean, got " .. type(isShow))
    return false
  end

  -- Save to persistent storage
  TeronAutoLFM.Core.Storage.SetMinimapHidden(not isShow)

  -- Log the change
  local action = isShow and "Show" or "Hide"
  TeronAutoLFM.Core.Utils.LogInfo(action .. " minimap button")

  -- Update minimap button visibility
  if TeronAutoLFM.Components.MinimapButton then
      if isShow then
          TeronAutoLFM.Components.MinimapButton.Show()
      else
          TeronAutoLFM.Components.MinimapButton.Hide()
      end
  end
end

--- Resets minimap button to its default position (left side of minimap)
--- Clears saved position from persistent storage and repositions the button
function TeronAutoLFM.Logic.Content.Settings.ResetMinimapPosition()
  -- Clear saved position
  TeronAutoLFM.Core.Storage.SetMinimapPos(nil, nil)

  -- Reset minimap button to default position
  if TeronAutoLFM.Components.MinimapButton and TeronAutoLFM.Components.MinimapButton.ResetPosition then
      TeronAutoLFM.Components.MinimapButton.ResetPosition()
      TeronAutoLFM.Core.Utils.LogInfo("Reset minimap button position")
  end
end

--=============================================================================
-- DARKUI MANAGEMENT
--=============================================================================
--- Toggles dark mode theme and prompts user to reload UI
--- Changes require UI reload to take effect on all frames
--- @param isEnabled boolean - True to enable dark mode, false to disable
--- @return boolean|nil - False on validation error
function TeronAutoLFM.Logic.Content.Settings.ToggleDarkMode(isEnabled)
  -- Validate isEnabled parameter
  if type(isEnabled) ~= "boolean" then
    TeronAutoLFM.Core.Utils.LogError("ToggleDarkMode: isEnabled must be boolean, got " .. type(isEnabled))
    return false
  end

  -- Save to persistent storage
  TeronAutoLFM.Core.Storage.SetDarkMode(isEnabled)

  -- Log the change
  local action = isEnabled and "Enable" or "Disable"
  TeronAutoLFM.Core.Utils.LogInfo(action .. " dark mode")

  -- Show reload message
  local reloadText = TeronAutoLFM.Core.Utils.ColorText("Reload", "GREEN")
  if isEnabled then
      TeronAutoLFM.Core.Utils.Print("Dark mode enabled. Click " .. reloadText .. " to apply changes.")
  else
      TeronAutoLFM.Core.Utils.Print("Dark mode disabled. Click " .. reloadText .. " to apply changes.")
  end
end

--=============================================================================
-- PRESETS MANAGEMENT
--=============================================================================
--- Toggles between condensed and full presets view mode
--- Condensed mode shows compact preset list, full mode shows expanded details
--- @param isCondensed boolean - True for condensed view, false for full view
--- @return boolean|nil - False on validation error
function TeronAutoLFM.Logic.Content.Settings.TogglePresetsCondensed(isCondensed)
  -- Validate isCondensed parameter
  if type(isCondensed) ~= "boolean" then
    TeronAutoLFM.Core.Utils.LogError("TogglePresetsCondensed: isCondensed must be boolean, got " .. type(isCondensed))
    return false
  end

  -- Save to persistent storage
  TeronAutoLFM.Core.Storage.SetPresetsCondensed(isCondensed)

  -- Log the change
  local mode = isCondensed and "condensed" or "full"
  TeronAutoLFM.Core.Utils.LogAction("Set presets view to " .. mode)
end

--=============================================================================
-- DRY RUN MANAGEMENT
--=============================================================================
--- Toggles dry run mode for testing without actually sending messages
--- When enabled, addon simulates actions but doesn't perform actual chat/whisper operations
--- @param isEnabled boolean - True to enable dry run mode, false to disable
--- @return boolean|nil - False on validation error
function TeronAutoLFM.Logic.Content.Settings.ToggleDryRun(isEnabled)
  -- Validate isEnabled parameter
  if type(isEnabled) ~= "boolean" then
    TeronAutoLFM.Core.Utils.LogError("ToggleDryRun: isEnabled must be boolean, got " .. type(isEnabled))
    return false
  end

  -- Update Maestro state
  TeronAutoLFM.Core.Maestro.SetState("Settings.DryRun", isEnabled)

  -- Save to persistent storage
  if TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.SetDryRun then
    TeronAutoLFM.Core.Storage.SetDryRun(isEnabled)
  end

  -- Log the change
  local action = isEnabled and "Enabled" or "Disabled"
  TeronAutoLFM.Core.Utils.LogInfo(action .. " dry run mode")
end

--=============================================================================
-- CUSTOM INSTANCE VISIBILITY MANAGEMENT
--=============================================================================
--- Toggles visibility of Turtle WoW custom dungeons/raids (vs vanilla-only)
--- @param isEnabled boolean - True to show custom instances, false to hide them
--- @return boolean|nil - False on validation error
function TeronAutoLFM.Logic.Content.Settings.ToggleShowCustomInstances(isEnabled)
  -- Validate isEnabled parameter
  if type(isEnabled) ~= "boolean" then
    TeronAutoLFM.Core.Utils.LogError("ToggleShowCustomInstances: isEnabled must be boolean, got " .. type(isEnabled))
    return false
  end

  -- Save to persistent storage
  TeronAutoLFM.Core.Storage.SetShowCustomInstances(isEnabled)

  -- Log the change
  local action = isEnabled and "Show" or "Hide"
  TeronAutoLFM.Core.Utils.LogInfo(action .. " Turtle WoW custom instances")

  -- Clear dungeon cache and refresh both lists (raids have no cache to clear)
  if TeronAutoLFM.Logic.Content.Dungeons and TeronAutoLFM.Logic.Content.Dungeons.ClearCache then
    TeronAutoLFM.Logic.Content.Dungeons.ClearCache()
  end
  if TeronAutoLFM.UI.Content.Dungeons and TeronAutoLFM.UI.Content.Dungeons.Refresh then
    TeronAutoLFM.UI.Content.Dungeons.Refresh()
  end
  if TeronAutoLFM.UI.Content.Raids and TeronAutoLFM.UI.Content.Raids.Refresh then
    TeronAutoLFM.UI.Content.Raids.Refresh()
  end
end

--=============================================================================
-- EVENT AND STATE DECLARATIONS
--=============================================================================
--- Event: Settings changed
TeronAutoLFM.Core.Maestro.RegisterEvent("Settings.Changed", { id = "E07" })

--- State: Dry run mode enabled/disabled
TeronAutoLFM.Core.SafeRegisterState("Settings.DryRun", false, { id = "S20" })

--=============================================================================
-- AUTO-REGISTER INITIALIZATION
--=============================================================================
TeronAutoLFM.Core.SafeRegisterInit("Logic.Content.Settings", function()
  TeronAutoLFM.Logic.Content.Settings.LoadSettings()
  TeronAutoLFM.Logic.Content.Settings.Init()

  -- Load dry run state from persistent storage
  if TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.GetDryRun then
    local dryRunEnabled = TeronAutoLFM.Core.Storage.GetDryRun()
    TeronAutoLFM.Core.Maestro.SetState("Settings.DryRun", dryRunEnabled)
  end
end, {
  id = "I13",
  dependencies = {"Core.Storage"} -- Must run after Storage
})
