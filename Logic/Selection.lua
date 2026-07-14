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

-- Dungeons always use a fixed 1 tank / 1 healer / 3 DPS composition, unlike
-- raids where the leader configures a per-role headcount manually
local DUNGEON_ROLE_QUOTAS = { TANK = 1, HEAL = 1, DPS = 3 }

--=============================================================================
-- STATE DECLARATIONS (MUST BE FIRST)
--=============================================================================
TeronAutoLFM.Core.SafeRegisterState("Selection.Mode", "none", { id = "S05" })
TeronAutoLFM.Core.SafeRegisterState("Selection.Roles", {}, { id = "S08" })
TeronAutoLFM.Core.SafeRegisterState("Selection.DungeonNames", {}, { id = "S04" })
TeronAutoLFM.Core.SafeRegisterState("Selection.RaidName", nil, { id = "S06" })
TeronAutoLFM.Core.SafeRegisterState("Selection.RaidSize", 40, { id = "S07" })
TeronAutoLFM.Core.SafeRegisterState("Selection.RoleCounts", {}, { id = "S21" })
TeronAutoLFM.Core.SafeRegisterState("Selection.MyRole", nil, { id = "S22" })
TeronAutoLFM.Core.SafeRegisterState("Selection.FilledDungeonRoles", {}, { id = "S23" })
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

--- Clamps a role's headcount so the sum of every role's headcount never
--- exceeds the raid's current (possibly scaled) target size. The 40-player
--- cap on Selection.SetRoleCount is a hard ceiling; this is what actually
--- keeps role counts from over-allocating the group as a whole
--- @param roleCounts table - Current role counts (role being set may or may not be present)
--- @param role string - The role being set
--- @param desiredCount number - The count being requested for this role
--- @param targetSize number - The raid's current target group size (pass
---   through GetEffectiveRaidPool() first if Selection.MyRole is set)
--- @return number - The clamped count (at least 1)
local function clampRoleCount(roleCounts, role, desiredCount, targetSize)
  local othersTotal = 0
  for r, c in pairs(roleCounts) do
    if r ~= role then
      othersTotal = othersTotal + c
    end
  end

  local maxAllowed = math.max(1, targetSize - othersTotal)
  return math.max(1, math.min(maxAllowed, math.floor(desiredCount)))
end

--- Reduces a dungeon role's fixed quota by 1 if the leader has set that as
--- their own role (Selection.MyRole), since they already fill that slot
--- themselves without needing to recruit it. Dungeon-specific: a standard
--- 5-man has an exact fixed composition (1/1/3), so the leader playing a
--- role directly zeroes out that role's own need. Raids don't use this -
--- see GetEffectiveRaidPool instead, which reduces the shared pool rather
--- than any one role's starting count, since raid comps aren't fixed and
--- the leader should be free to still recruit more of their own role.
--- @param role string - "TANK", "HEAL", or "DPS"
--- @param quota number - The base quota (always DUNGEON_ROLE_QUOTAS[role])
--- @return number - Adjusted quota, 0 or more
local function applySelfRoleAdjustment(role, quota)
  local myRole = TeronAutoLFM.Core.Maestro.GetState("Selection.MyRole")
  if myRole == role then
    return math.max(0, quota - 1)
  end
  return quota
end

--- Reduces a raid's target size by 1 if the leader has set their own role
--- (Selection.MyRole), regardless of which role, since they already occupy
--- one of the raid's slots and shouldn't be counted as still needed. This
--- shrinks the shared pool that clampRoleCount sums every role's headcount
--- against - it does NOT reduce any individual role's own starting count,
--- so the leader remains free to recruit more of their own role too.
--- @param targetSize number - The raid's current (possibly scaled) target size
--- @return number - Adjusted target size, at least 1
local function getEffectiveRaidPool(targetSize)
  local myRole = TeronAutoLFM.Core.Maestro.GetState("Selection.MyRole")
  if myRole then
    return math.max(1, targetSize - 1)
  end
  return targetSize
end

--- Sets the selection mode and clears incompatible selections
--- Ensures mutual exclusivity between dungeons, raids, custom, and quests modes
--- @param newMode string - The new mode to switch to (use MODES constants)
local function setSelectionMode(newMode)
  local previousMode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")

  -- Clear all modes except the new one (atomic operation)
  if newMode ~= MODES.DUNGEONS then
    TeronAutoLFM.Core.Maestro.SetState("Selection.DungeonNames", {})
  end

  if newMode ~= MODES.RAID then
    TeronAutoLFM.Core.Maestro.SetState("Selection.RaidName", nil)
    TeronAutoLFM.Core.Maestro.SetState("Selection.RaidSize", 40)
    TeronAutoLFM.Core.Maestro.SetState("Selection.RoleCounts", {})
  end

  if newMode ~= MODES.CUSTOM then
    TeronAutoLFM.Core.Maestro.SetState("Selection.CustomMessage", "")
  end

  -- Fresh dungeon-recruiting session: reset which roles have already been
  -- filled (Selection.FilledDungeonRoles) whenever entering or leaving
  -- dungeon mode, but not when merely changing which dungeons are
  -- advertised while staying in dungeon mode - the actual party
  -- composition doesn't change just because the dungeon list did
  if newMode ~= previousMode and (newMode == MODES.DUNGEONS or previousMode == MODES.DUNGEONS) then
    TeronAutoLFM.Core.Maestro.SetState("Selection.FilledDungeonRoles", {})
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

  -- Backfill role headcounts for any already-checked roles now that dungeon
  -- mode is active (fixed 1/1/3 quota). Mirrors the same reconciliation
  -- ToggleRaid does for raids - without this, roles checked *before*
  -- picking a dungeon would never get tracked, silently breaking the Role
  -- Assign popup and auto-decrement (shouldPrompt() requires RoleCounts to
  -- be non-empty)
  local currentRoles = TeronAutoLFM.Core.Maestro.GetState("Selection.Roles") or {}
  if table.getn(currentRoles) > 0 then
    local roleCounts = TeronAutoLFM.Core.Utils.ShallowCopy(TeronAutoLFM.Core.Maestro.GetState("Selection.RoleCounts") or {})
    local changed = false
    for i = 1, table.getn(currentRoles) do
      local r = currentRoles[i]
      if not roleCounts[r] then
        roleCounts[r] = DUNGEON_ROLE_QUOTAS[r] or 1
        changed = true
      end
    end
    if changed then
      TeronAutoLFM.Core.Maestro.SetState("Selection.RoleCounts", roleCounts)
    end
  end

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
    -- Deselect: clear raid and switch to none mode (setSelectionMode also
    -- resets Selection.RoleCounts since it's leaving raid mode)
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

    -- Restore this raid's saved per-role headcounts for whichever roles are
    -- currently selected (defaulting to 1 for roles never configured),
    -- clamped against this raid's scaled size minus 1 if the leader has set
    -- their own role (Selection.MyRole) - they already occupy one of the
    -- raid's slots, shrinking the shared pool every role's headcount sums
    -- against, without reducing any individual role's own starting count
    local currentRoles = TeronAutoLFM.Core.Maestro.GetState("Selection.Roles") or {}
    local roleCounts = {}
    local raidPool = getEffectiveRaidPool(raidSize)
    for i = 1, table.getn(currentRoles) do
      local r = currentRoles[i]
      local savedCount = TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.GetRaidInstanceRoleCount and TeronAutoLFM.Core.Storage.GetRaidInstanceRoleCount(raidName, r)
      roleCounts[r] = clampRoleCount(roleCounts, r, savedCount or 1, raidPool)
    end
    TeronAutoLFM.Core.Maestro.SetState("Selection.RoleCounts", roleCounts)

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

    -- Safeguard: the raid was actually rescaled while role counts were
    -- already allocated - reset every role's count back to 1 rather than
    -- risk an over-allocated total left over from the previous size
    local roleCounts = TeronAutoLFM.Core.Maestro.GetState("Selection.RoleCounts")
    if roleCounts and next(roleCounts) then
      local resetCounts = {}
      for r, _ in pairs(roleCounts) do
        resetCounts[r] = 1
      end
      TeronAutoLFM.Core.Maestro.SetState("Selection.RoleCounts", resetCounts)
    end
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
  TeronAutoLFM.Core.Maestro.SetState("Selection.RoleCounts", {})

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
  local roleCounts = TeronAutoLFM.Core.Utils.ShallowCopy(TeronAutoLFM.Core.Maestro.GetState("Selection.RoleCounts") or {})
  local isCurrentlySelected = TeronAutoLFM.Core.Utils.ArrayContains(currentRoles, role)

  -- Dungeons have no manual override for role counts (always the fixed
  -- 1/1/3 minus whatever the leader plays themselves - Selection.MyRole),
  -- so refuse to select a role that's already fully covered by the leader
  -- or has already been filled by a player who joined (see
  -- Selection.FilledDungeonRoles, set by Selection.DecrementRoleCount)
  if not isCurrentlySelected then
    local currentMode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")
    if currentMode == MODES.DUNGEONS then
      local effective = applySelfRoleAdjustment(role, DUNGEON_ROLE_QUOTAS[role] or 1)
      local filledRoles = TeronAutoLFM.Core.Maestro.GetState("Selection.FilledDungeonRoles") or {}
      if effective <= 0 or filledRoles[role] then
        TeronAutoLFM.Core.Utils.LogWarning("Cannot select " .. role .. ": already covered for this dungeon")
        return
      end
    end
  end

  local newRoles
  if isCurrentlySelected then
    newRoles = TeronAutoLFM.Core.Utils.RemoveFromArray(currentRoles, role)
    roleCounts[role] = nil
    TeronAutoLFM.Core.Utils.LogAction("Deselected role " .. role)
  else
    -- Create a copy and add new role
    newRoles = TeronAutoLFM.Core.Utils.ShallowCopy(currentRoles)
    table.insert(newRoles, role)
    TeronAutoLFM.Core.Utils.LogAction("Selected role " .. role)

    -- Raids show a per-role headcount the leader configures manually;
    -- dungeons always use the fixed 1/1/3 composition. Either way, this
    -- count also drives auto-decrementing as players join (see
    -- Selection.DecrementRoleCount) even though dungeons never display it.
    -- Raids account for the leader's own role (Selection.MyRole) by
    -- shrinking the shared pool (GetEffectiveRaidPool), not this role's own
    -- starting count; dungeons reduce this specific role's fixed quota
    -- directly, since a standard 5-man has no manual override.
    local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")
    if mode == MODES.RAID then
      local raidName = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidName")
      local savedCount = raidName and TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.GetRaidInstanceRoleCount and TeronAutoLFM.Core.Storage.GetRaidInstanceRoleCount(raidName, role)
      local targetSize = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidSize") or 40
      local raidPool = getEffectiveRaidPool(targetSize)
      roleCounts[role] = clampRoleCount(roleCounts, role, savedCount or 1, raidPool)
    elseif mode == MODES.DUNGEONS then
      roleCounts[role] = applySelfRoleAdjustment(role, DUNGEON_ROLE_QUOTAS[role] or 1)
    end
  end

  -- Update state
  TeronAutoLFM.Core.Maestro.SetState("Selection.Roles", newRoles)
  TeronAutoLFM.Core.Maestro.SetState("Selection.RoleCounts", roleCounts)

  -- Emit event
  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C14" })

--- Sets (or clears, if it's already set to the same role) the leader's own
--- role, so it's automatically excluded from what still needs recruiting.
--- Dungeons have no manual override, so changing this retroactively
--- rechecks/unchecks already-selected dungeon roles; raids let the leader
--- configure counts manually, so this only affects roles selected/raids
--- picked from this point forward.
--- @param role string|nil - "TANK", "HEAL", "DPS", or nil to clear directly
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.SetMyRole", function(role)
  if role ~= nil and not VALID_ROLES[role] then
    TeronAutoLFM.Core.Utils.LogError("Selection.SetMyRole: Invalid role '" .. tostring(role) .. "' (valid: TANK, HEAL, DPS, or nil)")
    return
  end

  local currentMyRole = TeronAutoLFM.Core.Maestro.GetState("Selection.MyRole")
  local newMyRole = role

  -- Clicking the already-selected role clears it back to unspecified
  if role ~= nil and currentMyRole == role then
    newMyRole = nil
  end

  TeronAutoLFM.Core.Maestro.SetState("Selection.MyRole", newMyRole)
  TeronAutoLFM.Core.Storage.Set("myRole", newMyRole)
  TeronAutoLFM.Core.Utils.LogAction("Set my role to " .. tostring(newMyRole))

  local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")
  if mode == MODES.DUNGEONS then
    local currentRoles = TeronAutoLFM.Core.Maestro.GetState("Selection.Roles") or {}
    local roleCounts = TeronAutoLFM.Core.Utils.ShallowCopy(TeronAutoLFM.Core.Maestro.GetState("Selection.RoleCounts") or {})
    local newRoles = {}
    for i = 1, table.getn(currentRoles) do
      local r = currentRoles[i]
      local effective = applySelfRoleAdjustment(r, DUNGEON_ROLE_QUOTAS[r] or 1)
      if effective > 0 then
        roleCounts[r] = effective
        table.insert(newRoles, r)
      else
        roleCounts[r] = nil
      end
    end
    TeronAutoLFM.Core.Maestro.SetState("Selection.Roles", newRoles)
    TeronAutoLFM.Core.Maestro.SetState("Selection.RoleCounts", roleCounts)
  end

  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C28" })

--- Sets how many of a specific role are still needed (raid mode only)
--- @param role string - The role to set a count for ("TANK", "HEAL", or "DPS")
--- @param count number - The headcount needed for this role
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.SetRoleCount", function(role, count)
  if not role or not VALID_ROLES[role] then
    TeronAutoLFM.Core.Utils.LogError("Selection.SetRoleCount: Invalid role '" .. tostring(role) .. "' (valid: TANK, HEAL, DPS)")
    return
  end

  local newCount = tonumber(count)
  if not newCount then
    TeronAutoLFM.Core.Utils.LogError("Selection.SetRoleCount: Invalid count value " .. tostring(count) .. " (expected number)")
    return
  end

  -- Clamp to a sane range (1-40) before weighing it against other roles
  newCount = math.max(1, math.min(40, math.floor(newCount)))

  local roleCounts = TeronAutoLFM.Core.Utils.ShallowCopy(TeronAutoLFM.Core.Maestro.GetState("Selection.RoleCounts") or {})

  -- Further clamp so this role + every other role's count never exceeds the
  -- raid's current (possibly scaled) target size, minus 1 if the leader has
  -- set their own role (they occupy one of the raid's slots). This only
  -- limits how role counts are allocated between each other - it has no
  -- effect on the "LF#M ... X/Y" headcount shown in the broadcast message.
  local targetSize = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidSize") or 40
  local raidPool = getEffectiveRaidPool(targetSize)
  newCount = clampRoleCount(roleCounts, role, newCount, raidPool)

  roleCounts[role] = newCount
  TeronAutoLFM.Core.Maestro.SetState("Selection.RoleCounts", roleCounts)

  TeronAutoLFM.Core.Utils.LogAction("Set " .. role .. " count to " .. newCount)

  -- Remember this count for the currently selected raid
  local raidName = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidName")
  if raidName and TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.SetRaidInstanceRoleCount then
    TeronAutoLFM.Core.Storage.SetRaidInstanceRoleCount(raidName, role, newCount)
  end

  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C25" })

--- Decrements a role's remaining headcount by 1 (called when the Role Assign
--- popup assigns a newly-joined player to a role). Once a role's count
--- reaches 0 it's fully filled, so it's removed from Selection.Roles
--- entirely - which naturally drops it from the broadcast message too,
--- whether that's a raid's numbered role text or a dungeon's flat role list.
--- @param role string - The role that was just filled ("TANK", "HEAL", or "DPS")
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.DecrementRoleCount", function(role)
  if not role or not VALID_ROLES[role] then
    TeronAutoLFM.Core.Utils.LogError("Selection.DecrementRoleCount: Invalid role '" .. tostring(role) .. "' (valid: TANK, HEAL, DPS)")
    return
  end

  local roleCounts = TeronAutoLFM.Core.Utils.ShallowCopy(TeronAutoLFM.Core.Maestro.GetState("Selection.RoleCounts") or {})
  local currentCount = roleCounts[role]
  if not currentCount then
    -- Role isn't currently being tracked/needed - nothing to decrement
    return
  end

  local newCount = currentCount - 1

  if newCount <= 0 then
    roleCounts[role] = nil

    local currentRoles = TeronAutoLFM.Core.Maestro.GetState("Selection.Roles") or {}
    local newRoles = TeronAutoLFM.Core.Utils.RemoveFromArray(currentRoles, role)
    TeronAutoLFM.Core.Maestro.SetState("Selection.Roles", newRoles)

    -- Dungeons have no manual override, so remember this role is fully
    -- filled (distinct from "never selected") so the UI can keep its
    -- checkbox disabled even though it's no longer in Selection.Roles -
    -- see Selection.IncrementRoleCount, which clears this if the player
    -- filling it later leaves
    local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")
    if mode == MODES.DUNGEONS then
      local filled = TeronAutoLFM.Core.Utils.ShallowCopy(TeronAutoLFM.Core.Maestro.GetState("Selection.FilledDungeonRoles") or {})
      filled[role] = true
      TeronAutoLFM.Core.Maestro.SetState("Selection.FilledDungeonRoles", filled)
    end

    TeronAutoLFM.Core.Utils.LogAction(role .. " fully filled - removed from selection")
  else
    roleCounts[role] = newCount

    -- Remember the reduced count for the currently selected raid (dungeons
    -- don't persist role counts - their quota is always the fixed 1/1/3)
    local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")
    local raidName = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidName")
    if mode == MODES.RAID and raidName and TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.SetRaidInstanceRoleCount then
      TeronAutoLFM.Core.Storage.SetRaidInstanceRoleCount(raidName, role, newCount)
    end

    TeronAutoLFM.Core.Utils.LogAction(role .. " count decremented to " .. newCount)
  end

  TeronAutoLFM.Core.Maestro.SetState("Selection.RoleCounts", roleCounts)
  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C26" })

--- Increments a role's remaining headcount by 1 (called when a player who'd
--- been assigned that role leaves the group - see RoleAssignPopup.lua). If
--- the role had been fully filled and removed from Selection.Roles, this
--- re-adds it, since a slot just opened back up.
--- @param role string - The role whose player left ("TANK", "HEAL", or "DPS")
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.IncrementRoleCount", function(role)
  if not role or not VALID_ROLES[role] then
    TeronAutoLFM.Core.Utils.LogError("Selection.IncrementRoleCount: Invalid role '" .. tostring(role) .. "' (valid: TANK, HEAL, DPS)")
    return
  end

  local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")
  if mode ~= MODES.RAID and mode ~= MODES.DUNGEONS then
    -- No longer recruiting for a raid/dungeon - nothing meaningful to restore
    return
  end

  local roleCounts = TeronAutoLFM.Core.Utils.ShallowCopy(TeronAutoLFM.Core.Maestro.GetState("Selection.RoleCounts") or {})
  local currentCount = roleCounts[role]
  local newCount

  if currentCount then
    -- Role is still selected/needed - bump its count, capped at what this
    -- mode could ever actually need for that role
    newCount = currentCount + 1
    if mode == MODES.RAID then
      local targetSize = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidSize") or 40
      local raidPool = getEffectiveRaidPool(targetSize)
      newCount = clampRoleCount(roleCounts, role, newCount, raidPool)
    else
      newCount = math.min(newCount, DUNGEON_ROLE_QUOTAS[role] or newCount)
    end
  else
    -- Role had been fully filled and unchecked - re-select it, since a
    -- slot just opened back up
    local currentRoles = TeronAutoLFM.Core.Maestro.GetState("Selection.Roles") or {}
    if not TeronAutoLFM.Core.Utils.ArrayContains(currentRoles, role) then
      local newRoles = TeronAutoLFM.Core.Utils.ShallowCopy(currentRoles)
      table.insert(newRoles, role)
      TeronAutoLFM.Core.Maestro.SetState("Selection.Roles", newRoles)
    end
    newCount = 1

    -- Clear the dungeon "fully filled" marker (see DecrementRoleCount) -
    -- the checkbox becomes selectable/enabled again
    if mode == MODES.DUNGEONS then
      local filled = TeronAutoLFM.Core.Maestro.GetState("Selection.FilledDungeonRoles")
      if filled and filled[role] then
        filled = TeronAutoLFM.Core.Utils.ShallowCopy(filled)
        filled[role] = nil
        TeronAutoLFM.Core.Maestro.SetState("Selection.FilledDungeonRoles", filled)
      end
    end
  end

  roleCounts[role] = newCount
  TeronAutoLFM.Core.Maestro.SetState("Selection.RoleCounts", roleCounts)

  -- Remember the increased count for the currently selected raid (dungeons
  -- don't persist role counts - their quota is always the fixed 1/1/3)
  local raidName = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidName")
  if mode == MODES.RAID and raidName and TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.SetRaidInstanceRoleCount then
    TeronAutoLFM.Core.Storage.SetRaidInstanceRoleCount(raidName, role, newCount)
  end

  TeronAutoLFM.Core.Utils.LogAction(role .. " count restored to " .. newCount .. " (player left)")
  TeronAutoLFM.Core.Maestro.Dispatch("Selection.Changed")
end, { id = "C27" })

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

--- Returns how many of a role a standard 5-man dungeon still needs after
--- accounting for the leader's own role (Selection.MyRole). Used by the UI
--- to decide whether a role checkbox should be disabled (0 = leader already
--- covers it, nothing to recruit).
--- @param role string - "TANK", "HEAL", or "DPS"
--- @return number - Effective quota, 0 or more
function TeronAutoLFM.Logic.Selection.GetEffectiveDungeonQuota(role)
  return applySelfRoleAdjustment(role, DUNGEON_ROLE_QUOTAS[role] or 1)
end

--- Returns whether a dungeon role has already been fully filled by a
--- player who joined this session (distinct from never having been
--- selected). Used by the UI to keep a role's checkbox disabled even
--- after it's been auto-removed from Selection.Roles.
--- @param role string - "TANK", "HEAL", or "DPS"
--- @return boolean - True if this role is already covered for this dungeon
function TeronAutoLFM.Logic.Selection.IsDungeonRoleFilled(role)
  local filled = TeronAutoLFM.Core.Maestro.GetState("Selection.FilledDungeonRoles") or {}
  return filled[role] == true
end

--- Clears all selections (dungeons, raids, roles, custom, details text, group size)
--- NOTE: Does NOT clear channels and intervals
TeronAutoLFM.Core.Maestro.RegisterCommand("Selection.ClearAll", function()
  TeronAutoLFM.Core.Maestro.SetState("Selection.DungeonNames", {})
  TeronAutoLFM.Core.Maestro.SetState("Selection.RaidName", nil)
  TeronAutoLFM.Core.Maestro.SetState("Selection.RaidSize", 40)
  TeronAutoLFM.Core.Maestro.SetState("Selection.RoleCounts", {})
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
  -- Load the leader's own role from persistent storage. Uses Storage.Get
  -- directly rather than an auto-generated accessor, since myRole's
  -- default/cleared value is nil and the generated string setter would
  -- coerce that to the literal string "nil" (see Core/Storage.lua)
  if TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.Get then
    local savedMyRole = TeronAutoLFM.Core.Storage.Get("myRole", nil)
    TeronAutoLFM.Core.Maestro.SetState("Selection.MyRole", savedMyRole)
  end
end, {
  id = "I05",
  dependencies = { "Core.Storage" }
})
