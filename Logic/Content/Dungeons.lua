--=============================================================================
-- TeronAutoLFM: Dungeons Logic
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Logic = TeronAutoLFM.Logic or {}
TeronAutoLFM.Logic.Content = TeronAutoLFM.Logic.Content or {}
TeronAutoLFM.Logic.Content.Dungeons = {}

--=============================================================================
-- PRIVATE HELPERS
--=============================================================================
--- Calculates the difficulty color for a dungeon based on player level
--- @param dungeon table - Dungeon data with levelMin and levelMax fields
--- @param playerLevel number - Current player level
--- @return table - Color object with r, g, b, hex, name, priority fields
local function getDungeonColor(dungeon, playerLevel)
  if not dungeon or not dungeon.levelMin or not playerLevel then
    return TeronAutoLFM.Core.Utils.GetColorForLevel(1, TeronAutoLFM.Core.Constants.INVALID_LEVEL, TeronAutoLFM.Core.Constants.INVALID_LEVEL)
  end
  return TeronAutoLFM.Core.Utils.GetColorForLevel(playerLevel, dungeon.levelMin, dungeon.levelMax)
end

--- Builds a sorted list of dungeons filtered by active color filters
--- @return table - Array of {index, dungeon, color} sorted by priority then level
local function buildSortedDungeons()
  local playerLevel = UnitLevel("player") or 1
  local dungeons = TeronAutoLFM.Core.Constants.DUNGEONS
  local vanillaNames = TeronAutoLFM.Core.Constants.VANILLA_INSTANCE_NAMES
  local sorted = {}

  local activeFilters = {}
  if TeronAutoLFM.Logic.Content.Settings and TeronAutoLFM.Logic.Content.Settings.GetDungeonFilters then
    activeFilters = TeronAutoLFM.Logic.Content.Settings.GetDungeonFilters()
  end

  local showCustom = TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.GetShowCustomInstances and TeronAutoLFM.Core.Storage.GetShowCustomInstances()

  for i = 1, table.getn(dungeons) do
    local dungeon = dungeons[i]
    local color = getDungeonColor(dungeon, playerLevel)

    local colorId = color.name
    local isEnabled = activeFilters[colorId]
    if isEnabled == nil then isEnabled = true end

    local isCustom = not (vanillaNames and vanillaNames[dungeon.name])
    if isCustom and not showCustom then
      isEnabled = false
    end

    if isEnabled then
      table.insert(sorted, {
        index = i,
        dungeon = dungeon,
        color = color
      })
    end
  end

  table.sort(sorted, function(a, b)
    if a.color.priority ~= b.color.priority then
      return a.color.priority < b.color.priority
    end
    return a.dungeon.levelMin < b.dungeon.levelMin
  end)

  return sorted
end

--- Counts dungeons that would be hidden by a specific color filter
--- @param colorId string - Color name to check (e.g., "GREEN", "YELLOW")
--- @return number - Count of dungeons with that color
local function countDungeonsByColor(colorId)
  local playerLevel = UnitLevel("player") or 1
  local dungeons = TeronAutoLFM.Core.Constants.DUNGEONS
  local count = 0

  for i = 1, table.getn(dungeons) do
    local dungeon = dungeons[i]
    local color = getDungeonColor(dungeon, playerLevel)
    if color.name == colorId then
      count = count + 1
    end
  end

  return count
end

--=============================================================================
-- PUBLIC API
--=============================================================================
--- Returns dungeons sorted by difficulty color and level (uses cache)
--- @return table - Array of {index, dungeon, color} sorted by priority and level
function TeronAutoLFM.Logic.Content.Dungeons.GetSortedDungeons()
  return TeronAutoLFM.Core.Cache.Get("Dungeons")
end

--- Clears the cached sorted dungeon list
--- Call this when player level changes or filters are updated
function TeronAutoLFM.Logic.Content.Dungeons.ClearCache()
  TeronAutoLFM.Core.Cache.Clear("Dungeons")
end

--- Refreshes the dungeon list and UI after a filter change
--- @param changedColorId string - Color filter that changed (for logging)
--- @param changedState boolean - New state of the filter (for logging)
function TeronAutoLFM.Logic.Content.Dungeons.RefreshList(changedColorId, changedState)
  -- Log the filter change
  if changedColorId then
    if changedState then
      TeronAutoLFM.Core.Utils.LogAction("Show dungeons " .. changedColorId)
    else
      local count = countDungeonsByColor(changedColorId)
      TeronAutoLFM.Core.Utils.LogAction("Hide dungeons " .. changedColorId .. " (" .. count .. ")")
    end
  else
    TeronAutoLFM.Core.Utils.LogAction("Refresh Dungeons list")
  end

  -- Clear cache and refresh UI
  TeronAutoLFM.Core.Cache.Clear("Dungeons")

  if TeronAutoLFM.UI.Content.Dungeons and TeronAutoLFM.UI.Content.Dungeons.Refresh then
    TeronAutoLFM.UI.Content.Dungeons.Refresh()
  end
end

--=============================================================================
-- INITIALIZATION
--=============================================================================
TeronAutoLFM.Core.SafeRegisterInit("Logic.Content.Dungeons", function()
  TeronAutoLFM.Core.Cache.Register("Dungeons", buildSortedDungeons)
end, { id = "I06" })
