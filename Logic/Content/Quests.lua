--=============================================================================
-- TeronAutoLFM: Quests Logic
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Logic = TeronAutoLFM.Logic or {}
TeronAutoLFM.Logic.Content = TeronAutoLFM.Logic.Content or {}
TeronAutoLFM.Logic.Content.Quests = {}

--=============================================================================
-- PRIVATE HELPERS
--=============================================================================
--- Calculates the difficulty color for a quest based on player level
--- @param questLevel number - Quest level from quest log
--- @param playerLevel number - Current player level
--- @return table - Color object with r, g, b, hex, name, priority fields
local function getQuestColor(questLevel, playerLevel)
  if not questLevel or not playerLevel then
    return TeronAutoLFM.Core.Utils.GetColorForLevel(1, TeronAutoLFM.Core.Constants.INVALID_LEVEL, TeronAutoLFM.Core.Constants.INVALID_LEVEL)
  end

  return TeronAutoLFM.Core.Utils.GetColorForLevel(playerLevel, questLevel, questLevel)
end

--- Retrieves the zone name for a quest by scanning upward for its header
--- @param questIndex number - Quest log index to find zone for
--- @return string|nil - Zone name (quest log header), or nil if not found
local function getQuestZone(questIndex)
  if not questIndex or questIndex <= 0 then return nil end

  local numEntries = GetNumQuestLogEntries()
  for i = questIndex - 1, 1, -1 do
    local headerTitle, headerLevel, _, isHeader = GetQuestLogTitle(i)
    if headerTitle and isHeader then
      return headerTitle
    end
  end

  return nil
end

--- Builds a sorted list of quests from the player's quest log
--- Extracts quest data, calculates colors, finds zones, sorts by level
--- @return table - Array of {index, name, level, tag, zone, color} sorted by level
local function buildSortedQuests()
  local playerLevel = UnitLevel("player") or 1
  local quests = {}
  local numEntries = GetNumQuestLogEntries()

  for i = 1, numEntries do
    local questLogTitleText, level, questTag, isHeader = GetQuestLogTitle(i)

    if questLogTitleText and not isHeader then
      local color = getQuestColor(level, playerLevel)
      local zone = getQuestZone(i)

      table.insert(quests, {
        index = i,
        name = questLogTitleText,
        level = level or 1,
        tag = questTag,
        zone = zone,
        color = color
      })
    end
  end

  table.sort(quests, function(a, b)
    return a.level < b.level
  end)

  return quests
end

--=============================================================================
-- QUEST LINK CREATION
--=============================================================================
--- Creates a quest hyperlink for chat messages
--- @param questIndex number - Quest log index
--- @return string|nil - Formatted quest link, or nil if quest not found
function TeronAutoLFM.Logic.Content.Quests.CreateQuestLink(questIndex)
  if not questIndex or questIndex < 1 then return nil end

  local title, level, _, _, _, _, _, questID = GetQuestLogTitle(questIndex)
  if not title then return nil end

  questID = questID or 0
  level = level or 0

  -- Remove quest tag prefix like [Elite], [Dungeon], etc.
  local cleanTitle = string.gsub(title, "^%[.-%]%s*", "")

  -- Calculate color based on quest level vs player level
  local playerLevel = UnitLevel("player") or 1
  local color = getQuestColor(level, playerLevel)

  -- Create quest link format: |cFFHEXCODE|Hquest:questID:level|h[title]|h|r
  return string.format("|cFF%s|Hquest:%d:%d|h[%s]|h|r", color.hex, questID, level, cleanTitle)
end

--=============================================================================
-- CUSTOM MESSAGE MANIPULATION
--=============================================================================
--- Checks if a quest link is present in either details or custom message
--- @param link string - The quest link to check
--- @return boolean - True if link is in any message
local function isQuestLinkInMessage(link)
  if not link then return false end

  -- Escape special pattern characters in the link
  local escapedLink = string.gsub(link, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")

  -- Check both States
  local detailsText = TeronAutoLFM.Core.Maestro.GetState("Selection.DetailsText") or ""
  local customText = TeronAutoLFM.Core.Maestro.GetState("Selection.CustomMessage") or ""

  return string.find(detailsText, escapedLink) ~= nil or string.find(customText, escapedLink) ~= nil
end

--- Adds a quest link to the current editbox text (details or custom mode)
--- @param link string - The quest link to add
local function addQuestLinkToMessage(link)
  if not link then return end

  -- Determine current broadcast mode from UI
  local broadcastMode = "details"  -- Default
  if TeronAutoLFM.UI and TeronAutoLFM.UI.Content and TeronAutoLFM.UI.Content.Messaging then
    if TeronAutoLFM.UI.Content.Messaging.GetCurrentMode then
      broadcastMode = TeronAutoLFM.UI.Content.Messaging.GetCurrentMode()
    end
  end

  -- Get the appropriate State based on current broadcast mode
  local currentText = ""
  if broadcastMode == "custom" then
    currentText = TeronAutoLFM.Core.Maestro.GetState("Selection.CustomMessage") or ""
    local newText = currentText == "" and link or (currentText .. " " .. link)
    TeronAutoLFM.Core.Maestro.Dispatch("Selection.SetCustomMessage", newText)
  else
    -- Details mode (default)
    currentText = TeronAutoLFM.Core.Maestro.GetState("Selection.DetailsText") or ""
    local newText = currentText == "" and link or (currentText .. " " .. link)
    TeronAutoLFM.Core.Maestro.Dispatch("Selection.SetDetailsText", newText)
  end
end

--- Removes a quest link from the current editbox text (details or custom mode)
--- @param link string - The quest link to remove
local function removeQuestLinkFromMessage(link)
  if not link then return end

  -- Get current mode to determine which State to update
  local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode") or "none"

  -- Try both States to find and remove the link
  local detailsText = TeronAutoLFM.Core.Maestro.GetState("Selection.DetailsText") or ""
  local customText = TeronAutoLFM.Core.Maestro.GetState("Selection.CustomMessage") or ""

  -- Escape special pattern characters in the link
  local escapedLink = string.gsub(link, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")

  -- Check which State contains the link and remove it
  if string.find(detailsText, escapedLink) then
    local newText = string.gsub(detailsText, escapedLink, "")
    -- Clean up extra spaces
    newText = string.gsub(newText, "%s+", " ")
    newText = string.gsub(newText, "^%s+", "")
    newText = string.gsub(newText, "%s+$", "")
    TeronAutoLFM.Core.Maestro.Dispatch("Selection.SetDetailsText", newText)
  elseif string.find(customText, escapedLink) then
    local newText = string.gsub(customText, escapedLink, "")
    -- Clean up extra spaces
    newText = string.gsub(newText, "%s+", " ")
    newText = string.gsub(newText, "^%s+", "")
    newText = string.gsub(newText, "%s+$", "")
    TeronAutoLFM.Core.Maestro.Dispatch("Selection.SetCustomMessage", newText)
  end
end

--=============================================================================
-- COMMANDS
--=============================================================================
--- Toggles quest selection and adds/removes its link from the current message
TeronAutoLFM.Core.Maestro.RegisterCommand("Quests.Toggle", function(questIndex)
  if not questIndex or type(questIndex) ~= "number" then
    TeronAutoLFM.Core.Utils.LogError("Quests.Toggle: Invalid index type " .. type(questIndex) .. " (expected number)")
    return
  end

  -- Create quest link
  local link = TeronAutoLFM.Logic.Content.Quests.CreateQuestLink(questIndex)
  if not link then
    TeronAutoLFM.Core.Utils.LogError("Quests.Toggle: Failed to create link for quest at index " .. questIndex .. " (quest may not exist)")
    return
  end

  -- Toggle link in current message (details or custom)
  if isQuestLinkInMessage(link) then
    removeQuestLinkFromMessage(link)
    TeronAutoLFM.Core.Utils.LogAction("Removed quest link from message")
  else
    addQuestLinkToMessage(link)
    TeronAutoLFM.Core.Utils.LogAction("Added quest link to message")
  end
end, { id = "C20" })

--=============================================================================
-- PUBLIC API
--=============================================================================
--- Returns quests from quest log sorted by level (uses cache)
--- @return table - Array of {index, name, level, tag, zone, color} sorted by level
function TeronAutoLFM.Logic.Content.Quests.GetSortedQuests()
  return TeronAutoLFM.Core.Cache.Get("Quests")
end

--- Clears the cached quest list
--- Call this when quest log is updated or player levels up
function TeronAutoLFM.Logic.Content.Quests.ClearCache()
  TeronAutoLFM.Core.Cache.Clear("Quests")
end

--- Checks if a quest link is in any message (details or custom)
--- @param questIndex number - Quest log index
--- @return boolean - True if quest link is in any message
function TeronAutoLFM.Logic.Content.Quests.IsQuestSelected(questIndex)
  local link = TeronAutoLFM.Logic.Content.Quests.CreateQuestLink(questIndex)
  if not link then return false end
  return isQuestLinkInMessage(link)
end

--=============================================================================
-- INITIALIZATION
--=============================================================================
--- Register cache builder for quests
if TeronAutoLFM.Core.Cache then
  TeronAutoLFM.Core.Cache.Register("Quests", buildSortedQuests)
end
