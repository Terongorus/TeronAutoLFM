--=============================================================================
-- TeronAutoLFM: Persistent Storage
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Core = TeronAutoLFM.Core or {}
TeronAutoLFM.Core.Storage = {}

--=============================================================================
-- PRIVATE STATE
--=============================================================================
local characterID

--=============================================================================
-- UTILITY FUNCTIONS
--=============================================================================
--- Maximum depth for deepCopy to prevent stack overflow on circular/deeply nested tables
local MAX_DEEP_COPY_DEPTH = 10

--- Creates a deep copy of a table (recursive) with depth limit
--- @param obj any - Object to copy (can be table or primitive)
--- @param depth number - Current recursion depth (internal use)
--- @return any - Deep copy of the object
local function deepCopy(obj, depth)
  if type(obj) ~= "table" then return obj end
  depth = depth or 0
  if depth >= MAX_DEEP_COPY_DEPTH then
    -- Return shallow copy at max depth to prevent stack overflow
    TeronAutoLFM.Core.Utils.LogWarning("deepCopy: max depth reached, returning shallow copy")
    local shallowCopy = {}
    for k, v in pairs(obj) do
      shallowCopy[k] = v
    end
    return shallowCopy
  end
  local copy = {}
  for k, v in pairs(obj) do
    copy[k] = type(v) == "table" and deepCopy(v, depth + 1) or v
  end
  return copy
end

--=============================================================================
-- SETTINGS REGISTRY
--=============================================================================
local SETTINGS_REGISTRY = {
  {key = "dungeonFilters", type = "table", default = {GRAY = true, GREEN = true, YELLOW = true, ORANGE = true, RED = true}},
  {key = "broadcastInterval", type = "number", default = 60},
  {key = "minimapHidden", type = "boolean", default = false},
  {key = "minimapPos", type = "table", default = nil},
  {key = "darkMode", type = "boolean", default = nil},
  {key = "previewMessageLines", type = "number", default = 2},
  {key = "customInput", type = "boolean", default = false},
  {key = "presetsCondensed", type = "boolean", default = false},
  {key = "defaultPanel", type = "string", default = "dungeons"},
  {key = "dryRun", type = "boolean", default = false},
  {key = "selectedChannels", type = "table", default = {}},
  {key = "autoInviteEnabled", type = "boolean", default = false},
  {key = "autoInviteKeywords", type = "table", default = {"+1"}},
  {key = "autoInviteConfirm", type = "boolean", default = true},
  {key = "autoInviteRandomMessages", type = "boolean", default = true},
  {key = "autoInviteRespondWhenNotLeader", type = "boolean", default = false},
  {key = "isHardcore", type = "boolean", default = nil},
  {key = "welcomeShown", type = "boolean", default = false},
  {key = "generalChannelIndex", type = "number", default = 1},
  {key = "showCustomInstances", type = "boolean", default = false},
  {key = "raidSizes", type = "table", default = {}},
  {key = "raidRoleCounts", type = "table", default = {}},
  -- NOTE: intentionally NOT using the auto-generated Get/SetMyRole accessors
  -- below - the auto-generated string setter coerces via tostring(value),
  -- which would turn a clear-to-nil call into the literal string "nil".
  -- Use Storage.Get("myRole", nil) / Storage.Set("myRole", role) directly.
  {key = "myRole", type = "string", default = nil}
}

--=============================================================================
-- HELPER FUNCTIONS
--=============================================================================
--- Retrieves character-specific persistent data, optionally creating it
--- @param ensure boolean - If true, creates character data if it doesn't exist
--- @return table|nil - Character data table, or nil if not available
local function getCharData(ensure)
  if not characterID then return nil end
  if not V3_Settings then
    if not ensure then return nil end
    V3_Settings = {}
  end
  if not V3_Settings[characterID] and ensure then
    local defaults = {}
    for i = 1, table.getn(SETTINGS_REGISTRY) do
      local setting = SETTINGS_REGISTRY[i]
      if setting.type == "table" and setting.default then
        defaults[setting.key] = deepCopy(setting.default)
      else
        defaults[setting.key] = setting.default
      end
    end
    if defaults.darkMode == nil then
      defaults.darkMode = (ShaguTweaks and ShaguTweaks.DarkMode) or nil
    end
    V3_Settings[characterID] = defaults
  end
  return V3_Settings[characterID]
end

--=============================================================================
-- GENERIC GET/SET
--=============================================================================
--- Gets a value from character-specific persistent storage
--- @param key string - The setting key to retrieve
--- @param defaultValue any - Value to return if key is not found or nil
--- @return any - The stored value or defaultValue
function TeronAutoLFM.Core.Storage.Get(key, defaultValue)
  local charData = getCharData()
  if not charData then
      return defaultValue
  end
  local value = charData[key]
  if value == nil then
      return defaultValue
  end

  return value
end

--- Sets a value in character-specific persistent storage
--- @param key string - The setting key to store
--- @param value any - The value to store (will be saved to SavedVariables)
function TeronAutoLFM.Core.Storage.Set(key, value)
  local charData = getCharData(true)
  if not charData then return end

  charData[key] = value
end

--=============================================================================
-- AUTO-GENERATED ACCESSORS
--=============================================================================
for i = 1, table.getn(SETTINGS_REGISTRY) do
  local setting = SETTINGS_REGISTRY[i]
  local capitalizedKey = string.upper(string.sub(setting.key, 1, 1)) .. string.sub(setting.key, 2)
  TeronAutoLFM.Core.Storage["Get" .. capitalizedKey] = function()
      return TeronAutoLFM.Core.Storage.Get(setting.key, setting.default)
  end
  TeronAutoLFM.Core.Storage["Set" .. capitalizedKey] = function(value)
      local coerced = value
      if setting.type == "boolean" then
          coerced = value == true
      elseif setting.type == "string" then
          coerced = tostring(value)
      elseif setting.type == "number" then
          coerced = tonumber(value)
      end
      TeronAutoLFM.Core.Storage.Set(setting.key, coerced)
  end
end

--=============================================================================
-- SPECIALIZED ACCESSORS
--=============================================================================
--- Sets minimap button position or clears it if nil
--- @param x number - X coordinate (optional, pass nil to clear position)
--- @param y number - Y coordinate (optional, pass nil to clear position)
function TeronAutoLFM.Core.Storage.SetMinimapPos(x, y)
  if x and y then
      TeronAutoLFM.Core.Storage.Set("minimapPos", { x = x, y = y })
  else
      TeronAutoLFM.Core.Storage.Set("minimapPos", nil)
  end
end

--- Updates a single dungeon color filter state
--- @param filterId string - Color name (e.g., "RED", "GREEN", "YELLOW")
--- @param enabled boolean - Whether dungeons of this color should be shown
function TeronAutoLFM.Core.Storage.SetDungeonFilter(filterId, enabled)
  local filters = TeronAutoLFM.Core.Storage.GetDungeonFilters()
  filters[filterId] = enabled
  TeronAutoLFM.Core.Storage.SetDungeonFilters(filters)
end

--- Remembers the last-configured group size for a specific raid instance
--- @param raidName string - Name of the raid
--- @param size number - Group size to remember for this raid
function TeronAutoLFM.Core.Storage.SetRaidInstanceSize(raidName, size)
  local sizes = TeronAutoLFM.Core.Storage.GetRaidSizes()
  sizes[raidName] = size
  TeronAutoLFM.Core.Storage.SetRaidSizes(sizes)
end

--- Retrieves the last-configured group size for a specific raid instance
--- @param raidName string - Name of the raid
--- @return number|nil - Previously saved size, or nil if never configured
function TeronAutoLFM.Core.Storage.GetRaidInstanceSize(raidName)
  local sizes = TeronAutoLFM.Core.Storage.GetRaidSizes()
  return sizes[raidName]
end

--- Remembers the last-configured headcount for a specific role on a specific raid
--- @param raidName string - Name of the raid
--- @param role string - Role name ("TANK", "HEAL", or "DPS")
--- @param count number - Headcount to remember for this raid+role
function TeronAutoLFM.Core.Storage.SetRaidInstanceRoleCount(raidName, role, count)
  local allCounts = TeronAutoLFM.Core.Storage.GetRaidRoleCounts()
  allCounts[raidName] = allCounts[raidName] or {}
  allCounts[raidName][role] = count
  TeronAutoLFM.Core.Storage.SetRaidRoleCounts(allCounts)
end

--- Retrieves the last-configured headcount for a specific role on a specific raid
--- @param raidName string - Name of the raid
--- @param role string - Role name ("TANK", "HEAL", or "DPS")
--- @return number|nil - Previously saved headcount, or nil if never configured
function TeronAutoLFM.Core.Storage.GetRaidInstanceRoleCount(raidName, role)
  local allCounts = TeronAutoLFM.Core.Storage.GetRaidRoleCounts()
  local raidCounts = allCounts[raidName]
  return raidCounts and raidCounts[role]
end

--- Deep copy utility for cloning tables recursively
--- @param tbl table - The table to deep copy
--- @return table - A new table with all nested tables copied
TeronAutoLFM.Core.Storage.DeepCopy = deepCopy

--=============================================================================
-- ADDITIONAL SPECIALIZED ACCESSORS
--=============================================================================
--- Sets the broadcast interval with validation
--- @param interval number - Interval in seconds (30-7200)
function TeronAutoLFM.Core.Storage.SetBroadcastInterval(interval)
  -- Clamp between 30 seconds and 2 hours
  local clamped = math.max(30, math.min(7200, tonumber(interval) or 60))
  TeronAutoLFM.Core.Storage.Set("broadcastInterval", clamped)
end

--=============================================================================
-- HARDCORE DETECTION
--=============================================================================
--- Detects if character is in hardcore mode by scanning spellbook
--- @return boolean - True if "hardcore" spell found in spellbook
local function detectHardcoreCharacter()
  for tab = 1, GetNumSpellTabs() do
    local _, _, offset, numSpells = GetSpellTabInfo(tab)
    for i = 1, numSpells do
      local spellName = GetSpellName(offset + i, "spell")
      if spellName and string.find(string.lower(spellName), "hardcore") then
        return true
      end
    end
  end
  return false
end

--=============================================================================
-- INITIALIZATION
--=============================================================================
--- Adds missing settings from SETTINGS_REGISTRY to existing character data
--- This ensures new settings are available after addon updates
local function migrateSettings()
  local charData = getCharData()
  if not charData then return end

  -- v3.12: One-time reset of hardcore status so SPELLS_CHANGED can re-detect reliably
  if charData.isHardcore == false and not charData._hardcoreMigrated then
    charData.isHardcore = nil
  end
  charData._hardcoreMigrated = true

  for i = 1, table.getn(SETTINGS_REGISTRY) do
    local setting = SETTINGS_REGISTRY[i]
    if charData[setting.key] == nil then
      if setting.type == "table" and setting.default then
        charData[setting.key] = deepCopy(setting.default)
      else
        charData[setting.key] = setting.default
      end
    end
  end
end

--- Initializes persistent storage for current character
--- Creates character-specific storage and detects hardcore mode
--- @return boolean - True if initialization succeeded, false otherwise
function TeronAutoLFM.Core.Storage.Init()
  local name = UnitName("player")
  local realm = GetRealmName()
  if not name or not realm then
    TeronAutoLFM.Core.Utils.LogError("Storage.Init failed: UnitName or GetRealmName returned nil (name=" .. tostring(name) .. ", realm=" .. tostring(realm) .. ")")
    return false
  end
  characterID = name .. "-" .. realm
  getCharData(true)
  migrateSettings()
  if not V3_Presets then
      V3_Presets = {}
  end
  if not V3_Presets[characterID] then
      V3_Presets[characterID] = {
          data = {},
          order = {}
      }
  end

  -- Hardcore detection is deferred to SPELLS_CHANGED event (see Events.lua)
  -- to guarantee the spellbook is fully loaded.

  return true
end

--=============================================================================
-- PRESETS MANAGEMENT
--=============================================================================
--- Gets all presets for the current character
--- @return table - Table with 'data' (preset name -> preset data) and 'order' (array of preset names)
function TeronAutoLFM.Core.Storage.GetPresets()
  if not V3_Presets or not characterID then
    return { data = {}, order = {} }
  end
  if not V3_Presets[characterID] then
    V3_Presets[characterID] = { data = {}, order = {} }
  end
  return V3_Presets[characterID]
end

--- Saves a preset with the given name and data
--- If preset already exists, it will be overwritten (data updated, order preserved)
--- @param presetName string - Name of the preset
--- @param presetData table - Preset data to save
--- @return boolean - True if successful
function TeronAutoLFM.Core.Storage.SavePreset(presetName, presetData)
  if not presetName or presetName == "" then return false end
  if not V3_Presets or not characterID then return false end

  local presets = TeronAutoLFM.Core.Storage.GetPresets()

  -- Check if preset already exists
  local exists = false
  for i = 1, table.getn(presets.order) do
    if presets.order[i] == presetName then
      exists = true
      break
    end
  end

  -- Add to order if new (preserve order for existing presets)
  if not exists then
    table.insert(presets.order, presetName)
  end

  -- Save data (deep copy to avoid reference issues)
  -- This will overwrite existing preset data if it exists
  presets.data[presetName] = deepCopy(presetData)

  return true
end

--- Checks if a preset exists
--- @param presetName string - Name of the preset
--- @return boolean - True if preset exists
function TeronAutoLFM.Core.Storage.PresetExists(presetName)
  if not presetName or presetName == "" then return false end
  local presets = TeronAutoLFM.Core.Storage.GetPresets()
  return presets.data[presetName] ~= nil
end

--- Deletes a preset
--- @param presetName string - Name of the preset to delete
--- @return boolean - True if successful
function TeronAutoLFM.Core.Storage.DeletePreset(presetName)
  if not presetName or presetName == "" then return false end
  local presets = TeronAutoLFM.Core.Storage.GetPresets()

  -- Remove from data
  presets.data[presetName] = nil

  -- Remove from order
  local newOrder = {}
  for i = 1, table.getn(presets.order) do
    if presets.order[i] ~= presetName then
      table.insert(newOrder, presets.order[i])
    end
  end
  presets.order = newOrder

  return true
end

--- Moves a preset up in the order
--- @param presetName string - Name of the preset to move
--- @return boolean - True if successful
function TeronAutoLFM.Core.Storage.MovePresetUp(presetName)
  if not presetName or presetName == "" then return false end
  local presets = TeronAutoLFM.Core.Storage.GetPresets()

  local index
  for i = 1, table.getn(presets.order) do
    if presets.order[i] == presetName then
      index = i
      break
    end
  end
  if not index or index == 1 then return false end

  presets.order[index - 1], presets.order[index] = presets.order[index], presets.order[index - 1]
  return true
end

--- Moves a preset down in the order
--- @param presetName string - Name of the preset to move
--- @return boolean - True if successful
function TeronAutoLFM.Core.Storage.MovePresetDown(presetName)
  if not presetName or presetName == "" then return false end
  local presets = TeronAutoLFM.Core.Storage.GetPresets()

  local index
  for i = 1, table.getn(presets.order) do
    if presets.order[i] == presetName then
      index = i
      break
    end
  end
  if not index or index == table.getn(presets.order) then return false end

  presets.order[index], presets.order[index + 1] = presets.order[index + 1], presets.order[index]
  return true
end

--=============================================================================
-- DEFERRED HARDCORE DETECTION
--=============================================================================
--- Detects and persists hardcore status by scanning the spellbook.
--- Must be called when the spellbook is guaranteed to be loaded (SPELLS_CHANGED).
--- Only runs once: skips if isHardcore is already set.
--- @return boolean - True if character is hardcore
function TeronAutoLFM.Core.Storage.DetectAndPersistHardcore()
  local charData = getCharData()
  if not charData or charData.isHardcore ~= nil then return false end

  local isHardcore = detectHardcoreCharacter()
  TeronAutoLFM.Core.Storage.SetIsHardcore(isHardcore)
  return isHardcore
end

--=============================================================================
-- REGISTRATION
--=============================================================================
TeronAutoLFM.Core.SafeRegisterInit("Core.Storage", function()
  TeronAutoLFM.Core.Storage.Init()
end, { id = "I02" })
