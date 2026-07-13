--=============================================================================
-- TeronAutoLFM: Selection Logic
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Logic = TeronAutoLFM.Logic or {}
TeronAutoLFM.Logic.Selection = {}

--=============================================================================
-- CONSTANTS
--=============================================================================
local MAX_DUNGEONS = TeronAutoLFM.Core.Constants.MAX_DUNGEONS or 3
local MODES = TeronAutoLFM.Core.Constants.SELECTION_MODES
local VALID_ROLES = TeronAutoLFM.Core.Constants.VALID_ROLES

--=============================================================================
-- STATE DECLARATIONS (MUST BE FIRST)
--=============================================================================
TeronAutoLFM.Core.SafeRegisterState("Selection.Mode", "none", { id = "S05" })
TeronAutoLFM.Core.SafeRegisterState("Selection.Roles", {}, { id = "S08" })
TeronAutoLFM.Core.SafeRegisterState("Selection.DungeonNames", {}, { id = "S04" })
TeronAutoLFM.Core.SafeRegisterState("Selection.RaidName", nil, { id = "S06" })
TeronAutoLFM.Core.SafeRegisterState("Selection.RaidSize", 40, { id = "S07" })
TeronAutoLFM.Core.SafeRegisterState("Selection.DetailsText", "", { id = "S03" })
TeronAutoLFM.Core.SafeRegisterState("Selection.CustomMessage", "", { id = "S02" })
TeronAutoLFM.Core.SafeRegisterState("Selection.CustomGroupSize", 5, { id = "S01" })

--=============================================================================
-- PRIVATE HELPERS
--=============================================================================
--- Checks if a dungeon is visible (not filtered by color)
--- @param index number - Dungeon index to check
--- @return boolean - True if dungeon appears in sorted (filtered) list
local function isDungeonVisible(index)
  if not TeronAutoLFM.Logic.Content.Dungeons or not TeronAutoLFM.Logic.Content.Dungeons.GetSortedDungeons then
    return true  -- If Dungeons module not loaded, assume visible
  end

  local sortedDungeons = TeronAutoLFM.Logic.Content.Dungeons.GetSortedDungeons()
  for i = 1, table.getn(sortedDungeons) do
    if sortedDungeons[i].index == index then
      return true
    end
  end

  return false
end

--- Sets the selection mode and clears incompatible selections
--- Ensures mutual exclusivity between dungeons, raids, custom, and quests modes
--- @param newMode string - The new mode to switch to (use MODES constants)
local function setSelectionMode(newMode)
  -- Clear all modes except the new one (atomic operation)
  if newMode ~= MODES.DUNGEONS then
    TeronAutoLFM.Core.Maestro.SetState("Selection.DungeonNames", {})
  end

  if newMode ~= MODES.RAID then
    TeronAutoLFM.Core.Maestro.SetState("Selection.RaidName", nil)
    TeronAutoLFM.Core.Maestro.SetState("Selection.RaidSize", 40)
  end

  if newMode ~= MODES.CUSTOM then
    TeronAutoLFM.Core.Maestro.SetState("Selection.CustomMessage", "")
  end

  -- Set the new mode
  TeronAutoLFM.Core.Maestro.SetState("Selection.Mode", newMode)
end

--=============================================================================
-- COMMANDS - DUNGEONS
--=============================================================================
--- Toggles dungeon selection with FIFO limit
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.ToggleDungeon", function(index)
  if not index or type(index) ~= "number" then
    TeronAutoLFM.Core.Utils.LogError("Selection.ToggleDungeon: Invalid index type " .. tostring(type(index)) .. " (expected number)")
    return
  end

  -- Verify dungeon exists and get its name
  local dungeon = TeronAutoLFM.Core.Constants.DUNGEONS[index]
  if not dungeon then
    TeronAutoLFM.Core.Utils.LogError("Selection.ToggleDungeon: Dungeon at index " .. tostring(index) .. " does not exist (max: " .. table.getn(TeronAutoLFM.Core.Constants.DUNGEONS) .. ")")
    return
  end

  local dungeonName = dungeon.name

  -- Check if dungeon is visible (not filtered by color)
  if not isDungeonVisible(index) then
    TeronAutoLFM.Core.Utils.LogWarning("Cannot select dungeon: filtered out by color")
    return
  end

  -- Read current state and create a copy to avoid mutation
  local currentNames = TeronAutoLFM.Core.Maestro.GetState("Selection.DungeonNames") or {}
  local dungeonNames = TeronAutoLFM.Core.Utils.ShallowCopy(currentNames)

  -- Toggle selection
  if TeronAutoLFM.Core.Utils.ArrayContains(dungeonNames, dungeonName) then
    -- Deselect
    dungeonNames = TeronAutoLFM.Core.Utils.RemoveFromArray(dungeonNames, dungeonName)
    TeronAutoLFM.Core.Utils.LogAction("Deselected dungeon " .. dungeonName)

    -- If no more dungeons selected, reset mode
    if table.getn(dungeonNames) == 0 then
      setSelectionMode(MODES.NONE)
      TeronAutoLFM.Core.Maestro.SetState("Selection.DungeonNames", dungeonNames)
      TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
      return
    end
  else
    -- Check FIFO limit
    local count = table.getn(dungeonNames)

    if count >= MAX_DUNGEONS then
      -- Remove oldest (first element)
      local oldName = dungeonNames[1]
      table.remove(dungeonNames, 1)
      TeronAutoLFM.Core.Utils.LogInfo("FIFO: Removed dungeon " .. oldName)
    end

    -- Select new
    table.insert(dungeonNames, dungeonName)
    TeronAutoLFM.Core.Utils.LogAction("Selected dungeon " .. dungeonName)
  end

  -- Update states and ensure dungeons mode is active
  TeronAutoLFM.Core.Maestro.SetState("Selection.DungeonNames", dungeonNames)
  setSelectionMode(MODES.DUNGEONS)

  -- Emit event
  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C12" })

--- Clears all dungeon selections
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.ClearDungeons", function()
  local dungeonNames = TeronAutoLFM.Core.Maestro.GetState("Selection.DungeonNames") or {}

  if table.getn(dungeonNames) == 0 then
    return  -- Nothing to clear
  end

  local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")

  if mode == MODES.DUNGEONS then
    TeronAutoLFM.Core.Maestro.SetState("Selection.Mode", MODES.NONE)
  end

  TeronAutoLFM.Core.Maestro.SetState("Selection.DungeonNames", {})
  TeronAutoLFM.Core.Utils.LogAction("Cleared all dungeons")

  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C05" })

--=============================================================================
-- COMMANDS - RAIDS
--=============================================================================
--- Toggles raid selection (exclusive with dungeons)
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.ToggleRaid", function(index)
  if not index or type(index) ~= "number" then
    TeronAutoLFM.Core.Utils.LogError("Selection.ToggleRaid: Invalid index type " .. tostring(type(index)) .. " (expected number)")
    return
  end

  -- Verify raid exists and get its name
  local raid = TeronAutoLFM.Core.Constants.RAIDS[index]
  if not raid then
    TeronAutoLFM.Core.Utils.LogError("Selection.ToggleRaid: Raid at index " .. tostring(index) .. " does not exist (max: " .. table.getn(TeronAutoLFM.Core.Constants.RAIDS) .. ")")
    return
  end

  local raidName = raid.name

  -- Read current state
  local selectedRaidName = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidName")

  -- Toggle selection
  if selectedRaidName == raidName then
    -- Deselect: clear raid and switch to none mode
    setSelectionMode(MODES.NONE)
    TeronAutoLFM.Core.Utils.LogAction("Deselected raid " .. raidName)
  else
    -- Select: clear other modes and set raid
    setSelectionMode(MODES.RAID)

    -- Prefer the size the user last configured for this raid; otherwise
    -- default to the maximum group size (clamped in case min/max changed
    -- since it was saved)
    local raidSize = TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.GetRaidInstanceSize and TeronAutoLFM.Core.Storage.GetRaidInstanceSize(raidName)
    if raidSize then
      if raidSize < raid.raidSizeMin then raidSize = raid.raidSizeMin end
      if raidSize > raid.raidSizeMax then raidSize = raid.raidSizeMax end
    else
      raidSize = raid.raidSizeMax or raid.raidSizeMin or 40
    end

    TeronAutoLFM.Core.Maestro.SetState("Selection.RaidName", raidName)
    TeronAutoLFM.Core.Maestro.SetState("Selection.RaidSize", raidSize)

    TeronAutoLFM.Core.Utils.LogAction("Selected raid " .. raidName .. " (size: " .. raidSize .. ")")
  end

  -- Emit event
  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C13" })

--- Sets custom raid size
--- @param size number - The new raid size
--- @param silent boolean - If true, don't dispatch Selection.Changed event (for slider dragging)
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.SetRaidSize", function(size, silent)
  local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")
  local selectedRaidName = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidName")

  if mode ~= MODES.RAID or not selectedRaidName then
    TeronAutoLFM.Core.Utils.LogWarning("Cannot set raid size: no raid selected")
    return
  end

  local newSize = tonumber(size)
  if not newSize then
    TeronAutoLFM.Core.Utils.LogError("Selection.SetRaidSize: Invalid size value " .. tostring(size) .. " (expected number)")
    return
  end

  -- Find the selected raid by name using O(1) lookup table
  TeronAutoLFM.Core.Utils.EnsureLookupTables()
  local raidInfo = TeronAutoLFM.Core.Constants.RAIDS_BY_NAME[selectedRaidName]
  local raid = raidInfo and raidInfo.data

  if not raid then
    TeronAutoLFM.Core.Utils.LogError("Selection.SetRaidSize: Selected raid '" .. tostring(selectedRaidName) .. "' not found in raid database")
    return
  end

  -- Clamp between raid's min/max size
  if newSize < raid.raidSizeMin then newSize = raid.raidSizeMin end
  if newSize > raid.raidSizeMax then newSize = raid.raidSizeMax end

  local oldSize = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidSize") or 40
  TeronAutoLFM.Core.Maestro.SetState("Selection.RaidSize", newSize)

  if oldSize ~= newSize then
    TeronAutoLFM.Core.Utils.LogAction("Set raid size to " .. newSize)
  end

  -- Remember this size so it's restored next time this raid is selected
  if TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.SetRaidInstanceSize then
    TeronAutoLFM.Core.Storage.SetRaidInstanceSize(selectedRaidName, newSize)
  end

  -- Emit event only if not silent
  if not silent then
    TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
  end
end, { id = "C11" })

--- Clears raid selection
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.ClearRaid", function()
  local selectedRaidName = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidName")

  if not selectedRaidName then
    return  -- Nothing to clear
  end

  local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")

  if mode == MODES.RAID then
    TeronAutoLFM.Core.Maestro.SetState("Selection.Mode", MODES.NONE)
  end

  TeronAutoLFM.Core.Maestro.SetState("Selection.RaidName", nil)
  TeronAutoLFM.Core.Maestro.SetState("Selection.RaidSize", 40)

  TeronAutoLFM.Core.Utils.LogAction("Cleared raid")

  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C06" })

--=============================================================================
-- COMMANDS - ROLES
--=============================================================================
--- Toggles role selection
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.ToggleRole", function(role)
  if not role or type(role) ~= "string" then
    TeronAutoLFM.Core.Utils.LogError("Selection.ToggleRole: Invalid role type " .. tostring(type(role)) .. " (expected string)")
    return
  end

  -- Validate role using constants
  if not VALID_ROLES[role] then
    TeronAutoLFM.Core.Utils.LogError("Selection.ToggleRole: Invalid role '" .. tostring(role) .. "' (valid: TANK, HEAL, DPS)")
    return
  end

  -- Read current roles and create a copy to avoid mutation
  local currentRoles = TeronAutoLFM.Core.Maestro.GetState("Selection.Roles") or {}

  local newRoles
  if TeronAutoLFM.Core.Utils.ArrayContains(currentRoles, role) then
    newRoles = TeronAutoLFM.Core.Utils.RemoveFromArray(currentRoles, role)
    TeronAutoLFM.Core.Utils.LogAction("Deselected role " .. role)
  else
    -- Create a copy and add new role
    newRoles = TeronAutoLFM.Core.Utils.ShallowCopy(currentRoles)
    table.insert(newRoles, role)
    TeronAutoLFM.Core.Utils.LogAction("Selected role " .. role)
  end

  -- Update state
  TeronAutoLFM.Core.Maestro.SetState("Selection.Roles", newRoles)

  -- Emit event
  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C14" })

--- Clears all role selections
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.ClearRoles", function()
  local selectedRoles = TeronAutoLFM.Core.Maestro.GetState("Selection.Roles") or {}

  if table.getn(selectedRoles) == 0 then
    return  -- Nothing to clear
  end

  TeronAutoLFM.Core.Maestro.SetState("Selection.Roles", {})
  TeronAutoLFM.Core.Utils.LogAction("Cleared all roles")

  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C07" })

--=============================================================================
-- COMMANDS - CUSTOM MESSAGE
--=============================================================================
--- Sets custom message (clears dungeons/raids)
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.SetCustomMessage", function(text)
  if not text then
    text = ""
  end

  -- If non-empty, switch to custom mode
  if text ~= "" then
    setSelectionMode(MODES.CUSTOM)
    TeronAutoLFM.Core.Maestro.SetState("Selection.CustomMessage", text)
    TeronAutoLFM.Core.Utils.LogAction("Set custom message")
  else
    -- If empty, clear custom mode
    setSelectionMode(MODES.NONE)
    TeronAutoLFM.Core.Maestro.SetState("Selection.CustomMessage", "")
  end

  -- Emit event
  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C09" })

--- Clears custom message
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.ClearCustomMessage", function()
  local customMessage = TeronAutoLFM.Core.Maestro.GetState("Selection.CustomMessage")

  if customMessage == "" then
    return  -- Nothing to clear
  end

  setSelectionMode(MODES.NONE)
  TeronAutoLFM.Core.Maestro.SetState("Selection.CustomMessage", "")
  TeronAutoLFM.Core.Utils.LogAction("Cleared custom message")

  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C04" })

--- Sets custom group size for custom messages with variables
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.SetCustomGroupSize", function(size)
  local newSize = tonumber(size)
  if not newSize then
    TeronAutoLFM.Core.Utils.LogError("SetCustomGroupSize: invalid size")
    return
  end

  if newSize < 1 then newSize = 1 end
  if newSize > TeronAutoLFM.Core.Constants.MAX_GROUP_SIZE then newSize = TeronAutoLFM.Core.Constants.MAX_GROUP_SIZE end

  local oldSize = TeronAutoLFM.Core.Maestro.GetState("Selection.CustomGroupSize") or 5
  if oldSize == newSize then return end

  TeronAutoLFM.Core.Maestro.SetState("Selection.CustomGroupSize", newSize)
  TeronAutoLFM.Core.Utils.LogAction("Set custom group size to " .. newSize)

  local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")
  local customMessage = TeronAutoLFM.Core.Maestro.GetState("Selection.CustomMessage") or ""
  if mode == MODES.CUSTOM and customMessage ~= "" then
    TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
  end
end, { id = "C08" })

--- Sets details text (appended to auto-generated message in details mode)
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.SetDetailsText", function(text)
  if not text then
    text = ""
  end

  TeronAutoLFM.Core.Maestro.SetState("Selection.DetailsText", text)

  -- Emit event to rebuild message
  -- In dungeons/raid mode: appends to auto-generated message
  -- In "none" mode: displays details text alone
  -- In custom mode: no effect (custom message is independent)
  local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")
  if mode ~= MODES.CUSTOM then
    TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
  end
end, { id = "C10" })

--=============================================================================
-- COMMANDS - GLOBAL
--=============================================================================
--- Checks if there are any selections to clear
--- @return boolean - True if there are any active selections
function TeronAutoLFM.Logic.Selection.HasSelections()
  local dungeonNames = TeronAutoLFM.Core.Maestro.GetState("Selection.DungeonNames") or {}
  local raidName = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidName")
  local roles = TeronAutoLFM.Core.Maestro.GetState("Selection.Roles") or {}
  local customMessage = TeronAutoLFM.Core.Maestro.GetState("Selection.CustomMessage") or ""
  local detailsText = TeronAutoLFM.Core.Maestro.GetState("Selection.DetailsText") or ""

  return table.getn(dungeonNames) > 0
    or raidName ~= nil
    or table.getn(roles) > 0
    or customMessage ~= ""
    or detailsText ~= ""
end

--- Clears all selections (dungeons, raids, roles, custom, details text, group size)
--- NOTE: Does NOT clear channels and intervals
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.ClearAll", function()
  TeronAutoLFM.Core.Maestro.SetState("Selection.DungeonNames", {})
  TeronAutoLFM.Core.Maestro.SetState("Selection.RaidName", nil)
  TeronAutoLFM.Core.Maestro.SetState("Selection.RaidSize", 40)
  TeronAutoLFM.Core.Maestro.SetState("Selection.Roles", {})
  TeronAutoLFM.Core.Maestro.SetState("Selection.CustomMessage", "")
  TeronAutoLFM.Core.Maestro.SetState("Selection.DetailsText", "")
  TeronAutoLFM.Core.Maestro.SetState("Selection.CustomGroupSize", 5)
  TeronAutoLFM.Core.Maestro.SetState("Selection.Mode", MODES.NONE)

  TeronAutoLFM.Core.Utils.LogAction("Cleared all selections")

  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C03" })

--=============================================================================
-- EVENT DECLARATIONS
--=============================================================================
TeronAutoLFM.Core.Maestro.RegisterEvent("Selection.Changed", { id = "E01" })

--=============================================================================
-- INITIALIZATION
--=============================================================================
TeronAutoLFM.Core.SafeRegisterInit("Logic.Selection", function()
  -- No initialization needed - selection state is managed by Maestro
end, { id = "I05" })
