--=============================================================================
-- TeronAutoLFM: Message Builder
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Logic = TeronAutoLFM.Logic or {}
TeronAutoLFM.Logic.Message = {}

--=============================================================================
-- PRIVATE HELPERS
--=============================================================================
--- Checks if group is full and returns missing count
--- @param targetSize number - Target group size
--- @return number, boolean - Missing count and whether group is full
local function calculateMissing(targetSize)
  local currentSize = TeronAutoLFM.Logic.Group.GetSize()
  local missing = targetSize - currentSize
  return missing, missing <= 0
end

--- Gets formatted roles text (e.g., "Tank & Healer", "All")
--- @param roles table - Array of role strings ("TANK", "HEAL", "DPS")
--- @return string - Role text without "Need" prefix
local function getRolesText(roles)
  if not roles or table.getn(roles) == 0 then
    return ""
  end

  -- If all 3 roles selected, return "All"
  if table.getn(roles) == 3 then
    return "All"
  end

  -- Build O(1) lookup table for selected roles
  local roleMap = {}
  for i = 1, table.getn(roles) do
    roleMap[roles[i]] = true
  end

  -- Build ordered list of role names (always Tank -> Healer -> DPS)
  local roleOrder = {"TANK", "HEAL", "DPS"}
  local roleNames = {TANK = "Tank", HEAL = "Healer", DPS = "DPS"}
  local parts = {}

  -- Check roles in order (now O(n) instead of O(n²))
  for i = 1, table.getn(roleOrder) do
    local roleKey = roleOrder[i]
    if roleMap[roleKey] then
      table.insert(parts, roleNames[roleKey])
    end
  end

  if table.getn(parts) == 0 then
    return ""
  end

  return table.concat(parts, " & ")
end

local ROLE_DISPLAY_NAMES = {
  TANK = { singular = "Tank", plural = "Tanks" },
  HEAL = { singular = "Healer", plural = "Healers" },
  DPS = { singular = "DPS", plural = "DPS" }
}

--- Returns the singular or plural display name for a role based on count
--- @param role string - Role key ("TANK", "HEAL", "DPS")
--- @param count number - Headcount, used to pick singular vs plural
--- @return string - Display name (e.g. "Tank"/"Tanks", "Healer"/"Healers", "DPS")
local function getRoleDisplayName(role, count)
  local names = ROLE_DISPLAY_NAMES[role]
  if not names then return role end
  if count == 1 then
    return names.singular
  end
  return names.plural
end

--- Formats roles with a per-role headcount for raid messages (e.g. "2 Tanks & 3 Healers")
--- Unlike getRolesText, this never collapses to "All" since each role carries
--- its own distinct count
--- @param roles table - Array of role strings ("TANK", "HEAL", "DPS")
--- @param roleCounts table - Map of role -> headcount (e.g. {TANK = 2, HEAL = 3})
--- @return string - Role text with counts, or "" if no roles selected
local function formatRoleCounts(roles, roleCounts)
  if not roles or table.getn(roles) == 0 then
    return ""
  end

  roleCounts = roleCounts or {}

  local roleOrder = {"TANK", "HEAL", "DPS"}
  local roleSet = {}
  for i = 1, table.getn(roles) do
    roleSet[roles[i]] = true
  end

  local parts = {}
  for i = 1, table.getn(roleOrder) do
    local roleKey = roleOrder[i]
    if roleSet[roleKey] then
      local count = roleCounts[roleKey]
      if count == nil then count = 1 end
      -- A role can be checked with a count of exactly 0 (the leader's own
      -- role fully covers a raid's default headcount) - skip it from the
      -- message rather than announcing "need 0 Tanks"
      if count > 0 then
        table.insert(parts, count .. " " .. getRoleDisplayName(roleKey, count))
      end
    end
  end

  if table.getn(parts) == 0 then
    return ""
  end

  return table.concat(parts, " & ")
end

--- Builds dungeon message
--- @return string - Formatted dungeon message
local function buildDungeonMessage()
  local dungeonNames = TeronAutoLFM.Core.Maestro.GetState("Selection.DungeonNames")
  if not dungeonNames or table.getn(dungeonNames) == 0 then
    return ""
  end

  TeronAutoLFM.Core.Utils.EnsureLookupTables()

  local targetSize = 5
  local missing, isFull = calculateMissing(targetSize)
  if isFull then
    return ""
  end

  local roles = TeronAutoLFM.Core.Maestro.GetState("Selection.Roles") or {}
  local rolesText = getRolesText(roles)

  local dungeonTags = {}
  for i = 1, table.getn(dungeonNames) do
    local dungeonName = dungeonNames[i]
    local dungeonInfo = TeronAutoLFM.Core.Constants.DUNGEONS_BY_NAME[dungeonName]
    if dungeonInfo then
      table.insert(dungeonTags, dungeonInfo.data.tag)
    end
  end

  if table.getn(dungeonTags) == 0 then
    return ""
  end

  -- Format message: "LF3M for RFC or SFK - need Tank & Healer" or "LF3M for RFC"
  local dungeonList = table.concat(dungeonTags, " or ")

  local message
  if rolesText ~= "" then
    message = string.format("LF%dM for %s - need %s", missing, dungeonList, rolesText)
  else
    message = string.format("LF%dM for %s", missing, dungeonList)
  end

  -- Append details text if present
  local detailsText = TeronAutoLFM.Core.Maestro.GetState("Selection.DetailsText") or ""
  if detailsText ~= "" then
    message = message .. " " .. detailsText
  end

  return message
end

--- Builds raid message
--- @return string - Formatted raid message
local function buildRaidMessage()
  local raidName = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidName")
  if not raidName then
    return ""
  end

  -- Trigger lazy loading of lookup tables
  TeronAutoLFM.Core.Utils.EnsureLookupTables()

  -- Find the raid by name (O(1) lookup)
  local raidInfo = TeronAutoLFM.Core.Constants.RAIDS_BY_NAME[raidName]
  if not raidInfo then
    return ""
  end

  local raid = raidInfo.data

  -- Get target size and calculate missing
  -- Selection.RaidSize defaults to the raid's saved size, or its max group
  -- size if never configured before (see Selection.ToggleRaid)
  local targetSize = TeronAutoLFM.Core.Maestro.GetState("Selection.RaidSize") or 40
  local missing, isFull = calculateMissing(targetSize)
  
  -- If raid is full, don't show LFM
  if isFull then
    return ""
  end
  
  local currentSize = TeronAutoLFM.Logic.Group.GetSize()

  -- Get roles with their per-role headcounts
  local roles = TeronAutoLFM.Core.Maestro.GetState("Selection.Roles") or {}
  local roleCounts = TeronAutoLFM.Core.Maestro.GetState("Selection.RoleCounts") or {}
  local rolesText = formatRoleCounts(roles, roleCounts)

  -- Format message: "LF5M for MC - need Tank2 & Heal3 35/40" or "LF5M for MC 35/40"
  local message
  if rolesText ~= "" then
    message = string.format("LF%dM for %s - need %s %d/%d", missing, raid.tag, rolesText, currentSize, targetSize)
  else
    message = string.format("LF%dM for %s %d/%d", missing, raid.tag, currentSize, targetSize)
  end

  -- Append details text if present
  local detailsText = TeronAutoLFM.Core.Maestro.GetState("Selection.DetailsText") or ""
  if detailsText ~= "" then
    message = message .. " " .. detailsText
  end

  return message
end

--- Builds custom message with variable substitution
--- @return string - Formatted custom message
local function buildCustomMessage()
  local customMessage = TeronAutoLFM.Core.Maestro.GetState("Selection.CustomMessage") or ""
  if customMessage == "" then
    return ""
  end

  local targetSize = TeronAutoLFM.Core.Maestro.GetState("Selection.CustomGroupSize") or 5
  local missing, isFull = calculateMissing(targetSize)
  local currentSize = TeronAutoLFM.Logic.Group.GetSize()

  if isFull then
    return ""
  end

  -- Get roles
  local roles = TeronAutoLFM.Core.Maestro.GetState("Selection.Roles") or {}
  local rolesText = getRolesText(roles)

  -- Replace variables in message
  local message = customMessage
  message = string.gsub(message, "{MIS}", tostring(missing))
  message = string.gsub(message, "{CUR}", tostring(currentSize))
  message = string.gsub(message, "{TAR}", tostring(targetSize))
  message = string.gsub(message, "{ROL}", rolesText)

  return message
end

--- Converts embedded quest hyperlinks (as produced by Quests.CreateQuestLink)
--- into plain "[Title]" text. Pure vanilla 1.12.1 clients don't support quest
--- links in chat, so the colored |Hquest:id:level|h[Title]|h|r escape sequence
--- must be stripped down to a plain literal before the message is sent, even
--- though the addon itself still uses the real link for its own preview/edit
--- workflow (see Quests.lua's isQuestLinkInMessage/removeQuestLinkFromMessage,
--- which operate on the raw Selection.DetailsText/CustomMessage state, not on
--- this already-stripped broadcast string)
--- @param text string - Message text potentially containing quest links
--- @return string - Message text with quest links replaced by "[Title]"
local function stripQuestLinks(text)
  if not text or text == "" then return text end
  local result = string.gsub(text, "|c%x%x%x%x%x%x%x%x|Hquest:%d+:%d+|h(%[.-%])|h|r", "%1")
  return result
end

--- Builds the complete broadcast message based on current selection
--- @return string - The message to broadcast
local function buildMessage()
  local selectionMode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")

  if selectionMode == "custom" then
    return buildCustomMessage()
  elseif selectionMode == "dungeons" then
    return buildDungeonMessage()
  elseif selectionMode == "raid" then
    return buildRaidMessage()
  end

  -- Mode "none" is typically a quest-only broadcast (quest links added via
  -- Shift+Click populate DetailsText): "LFM <quest link> - need Tank & Healer"
  local detailsText = TeronAutoLFM.Core.Maestro.GetState("Selection.DetailsText") or ""
  local roles = TeronAutoLFM.Core.Maestro.GetState("Selection.Roles") or {}
  local rolesText = getRolesText(roles)

  if detailsText ~= "" then
    local message = "LFM " .. detailsText
    if rolesText ~= "" then
      message = message .. " - need " .. rolesText
    end
    return message
  end

  -- No dungeon/raid/custom content and no details text (e.g. a quest link)
  -- to attach roles to - a bare "Need Tank & Healer" with no context on
  -- what you're actually recruiting for doesn't make sense as a broadcast,
  -- so produce no message at all rather than something ambiguous
  return ""
end

--=============================================================================
-- PUBLIC API
--=============================================================================
--- Gets the current broadcast message
--- @return string - The message to broadcast
function TeronAutoLFM.Logic.Message.GetMessage()
  return TeronAutoLFM.Core.Maestro.GetState("Message.ToBroadcast") or ""
end

--- Manually rebuilds the message (usually triggered by Selection.Changed)
function TeronAutoLFM.Logic.Message.RebuildMessage()
  local message = buildMessage()
  message = stripQuestLinks(message)
  TeronAutoLFM.Core.Maestro.SetState("Message.ToBroadcast", message)
end

--- Replaces variables in custom message (for preview/presets)
--- @param message string - The message template with {MIS}, {CUR}, {TAR}, {ROL} placeholders
--- @param currentSize number - Current group size
--- @param targetSize number - Target group size
--- @param roles table - Array of role strings
--- @return string - Message with variables replaced
function TeronAutoLFM.Logic.Message.ReplaceVariables(message, currentSize, targetSize, roles)
  -- Validate message parameter
  if type(message) ~= "string" then
    TeronAutoLFM.Core.Utils.LogError("ReplaceVariables: message must be string, got " .. type(message))
    return ""
  end

  if message == "" then return "" end

  -- Validate numeric parameters
  if type(currentSize) ~= "number" then
    TeronAutoLFM.Core.Utils.LogError("ReplaceVariables: currentSize must be number, got " .. type(currentSize))
    return message
  end

  if type(targetSize) ~= "number" then
    TeronAutoLFM.Core.Utils.LogError("ReplaceVariables: targetSize must be number, got " .. type(targetSize))
    return message
  end

  -- Validate roles parameter
  if roles and type(roles) ~= "table" then
    TeronAutoLFM.Core.Utils.LogError("ReplaceVariables: roles must be table or nil, got " .. type(roles))
    roles = {}
  end

  local missing = targetSize - currentSize
  local rolesText = getRolesText(roles or {})
  
  local result = message
  result = string.gsub(result, "{MIS}", tostring(missing))
  result = string.gsub(result, "{CUR}", tostring(currentSize))
  result = string.gsub(result, "{TAR}", tostring(targetSize))
  result = string.gsub(result, "{ROL}", rolesText)
  
  return result
end

--=============================================================================
-- STATE DECLARATIONS
--=============================================================================
TeronAutoLFM.Core.SafeRegisterState("Message.ToBroadcast", "", { id = "S19" })

--=============================================================================
-- INITIALIZATION
--=============================================================================
TeronAutoLFM.Core.SafeRegisterInit("Logic.Message", function()
  -- Register event listeners (wait for Selection.Changed and Group.SizeChanged to be registered)

  --- Rebuilds message when selection changes
  TeronAutoLFM.Core.Maestro.Listen(
    "Logic.Message.OnSelectionChanged",
    "Selection.Changed",
    function()
      TeronAutoLFM.Logic.Message.RebuildMessage()
    end,
    { id = "L01" }
  )

  --- Rebuilds message when group size changes (for LF3M -> LF2M updates)
  TeronAutoLFM.Core.Maestro.Listen(
    "Logic.Message.OnGroupSizeChanged",
    "Group.SizeChanged",
    function(payload)
      local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")

      -- Rebuild for dungeons, raid, AND custom (custom can have {MIS}/{CUR} variables)
      if mode == "dungeons" or mode == "raid" or mode == "custom" then
        TeronAutoLFM.Logic.Message.RebuildMessage()

        -- Log the automatic update
        if payload and payload.size then
          TeronAutoLFM.Core.Utils.LogAction("Message auto-updated (group size: " .. payload.size .. ")")
        end
      end
    end,
    { id = "L02" }
  )

  TeronAutoLFM.Logic.Message.RebuildMessage()
end, {
  id = "I08",
  dependencies = { "Logic.Selection", "Logic.Group", "Core.Events" }
})
