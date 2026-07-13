--=============================================================================
-- TeronAutoLFM: Event Handling
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Core = TeronAutoLFM.Core or {}
TeronAutoLFM.Core.Events = {}

--=============================================================================
-- PRIVATE STATE
--=============================================================================
local eventFrame
local lastGroupSize = 0

--=============================================================================
-- PRIVATE HELPERS
--=============================================================================
--- Gets current group size and type
--- @return number, string - Current size and type ("solo", "party", "raid")
local function getGroupInfo()
  local raidCount = GetNumRaidMembers() or 0
  local partyCount = GetNumPartyMembers() or 0

  if raidCount > 0 then
    return raidCount, "raid"
  elseif partyCount > 0 then
    return partyCount + 1, "party"
  else
    return 1, "solo"
  end
end

--=============================================================================
-- EVENT HANDLERS
--=============================================================================
--- Handles QUEST_LOG_UPDATE event - clears cache and refreshes quest UI
local function onQuestLogUpdate()
  if TeronAutoLFM.Logic.Content.Quests then
    TeronAutoLFM.Logic.Content.Quests.ClearCache()
  end

  if TeronAutoLFM_MainFrame and TeronAutoLFM_MainFrame:IsVisible() then
    TeronAutoLFM.Core.Maestro.Dispatch("QuestsList.Refresh")
  end
end

--- Handles PLAYER_LEVEL_UP event - clears caches and refreshes dungeon/quest UI
local function onPlayerLevelUp()
  local newLevel = arg1
  if not newLevel then
    TeronAutoLFM.Core.Utils.LogWarning("PLAYER_LEVEL_UP: arg1 (newLevel) is nil")
    return
  end

  if TeronAutoLFM.Logic.Content.Quests then
    TeronAutoLFM.Logic.Content.Quests.ClearCache()
  end

  if TeronAutoLFM.Logic.Content.Dungeons then
    TeronAutoLFM.Logic.Content.Dungeons.ClearCache()
  end

  if TeronAutoLFM_MainFrame and TeronAutoLFM_MainFrame:IsVisible() then
    TeronAutoLFM.Core.Maestro.Dispatch("QuestsList.Refresh")
  end

  TeronAutoLFM.Core.Utils.LogInfo("Level up! New level: " .. tostring(newLevel))
end

--- Handles group roster change events - tracks group size and dispatches events
local function onGroupRosterChange()
  local currentSize, groupType = getGroupInfo()

  if currentSize ~= lastGroupSize then
    TeronAutoLFM.Core.Utils.LogAction("Group size: " .. lastGroupSize .. " -> " .. currentSize)

    lastGroupSize = currentSize

    -- Update Maestro states and dispatch event
    TeronAutoLFM.Core.Maestro.SetState("Group.Type", groupType)
    TeronAutoLFM.Core.Maestro.SetState("Group.Size", currentSize)
    TeronAutoLFM.Core.Maestro.Dispatch("Group.SizeChanged", { size = currentSize })
  end
end

--- Checks if player can lead (is leader, raid leader, or raid assistant)
--- @return boolean - True if player is leader, raid leader, or raid officer
local function canPlayerLead()
  -- Solo or party leader
  if UnitIsPartyLeader("player") then
    return true
  end
  -- Raid leader
  if IsRaidLeader and IsRaidLeader() then
    return true
  end
  -- Raid assistant (officer) can also invite
  if IsRaidOfficer and IsRaidOfficer() then
    return true
  end
  return false
end

--- Handles PARTY_LEADER_CHANGED event - dispatches event
local function onPartyLeaderChanged()
  local isLeader = canPlayerLead()
  TeronAutoLFM.Core.Maestro.SetState("Group.IsLeader", isLeader)
  TeronAutoLFM.Core.Maestro.Dispatch("Group.LeaderChanged", { isLeader = isLeader })
end

--- Handles CHAT_MSG_WHISPER event - dispatches whisper data to modules
local function onChatMsgWhisper()
  local message = arg1
  local sender = arg2

  if not message or not sender then
    TeronAutoLFM.Core.Utils.LogWarning("CHAT_MSG_WHISPER: arg1 or arg2 is nil")
    return
  end

  TeronAutoLFM.Core.Maestro.Dispatch("Chat.WhisperReceived", {
    message = message,
    sender = sender
  })
end

--- Handles SPELLS_CHANGED event - detects hardcore status when spellbook is loaded
local function onSpellsChanged()
  TeronAutoLFM.Core.Storage.DetectAndPersistHardcore()
  -- Unregister: spellbook is loaded, detection is done
  if eventFrame then
    eventFrame:UnregisterEvent("SPELLS_CHANGED")
  end
end

--- Routes WoW events to appropriate handler functions
--- @param eventName string - WoW event name
local function onEvent(eventName)

  if eventName == "QUEST_LOG_UPDATE" then
    onQuestLogUpdate()
  elseif eventName == "PLAYER_LEVEL_UP" then
    onPlayerLevelUp()
  elseif eventName == "PARTY_MEMBERS_CHANGED" then
    onGroupRosterChange()
  elseif eventName == "RAID_ROSTER_UPDATE" then
    onGroupRosterChange()
    -- Also check leader/officer status on raid roster changes (promotions/demotions)
    onPartyLeaderChanged()
  elseif eventName == "PARTY_LEADER_CHANGED" then
    onPartyLeaderChanged()
  elseif eventName == "CHAT_MSG_WHISPER" then
    onChatMsgWhisper()
  elseif eventName == "SPELLS_CHANGED" then
    onSpellsChanged()
  end
end

--=============================================================================
-- PUBLIC API
--=============================================================================
--- Initializes the WoW event system and registers all required event listeners
function TeronAutoLFM.Core.Events.Init()
  if not eventFrame then
    eventFrame = CreateFrame("Frame", "TeronAutoLFM_EventFrame")
    eventFrame:SetScript("OnEvent", function()
      onEvent(event)
    end)
  end

  -- Register all events
  eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
  eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
  eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
  eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
  eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
  eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
  eventFrame:RegisterEvent("SPELLS_CHANGED")

  -- Initialize group size tracker and Maestro states
  local initialSize, initialType = getGroupInfo()
  lastGroupSize = initialSize

  TeronAutoLFM.Core.Maestro.SetState("Group.Type", initialType)
  TeronAutoLFM.Core.Maestro.SetState("Group.Size", initialSize)
  TeronAutoLFM.Core.Maestro.SetState("Group.IsLeader", canPlayerLead())

  TeronAutoLFM.Core.Utils.LogInfo("Event system initialized (7 WoW events monitored)")
end

--- Forces a refresh of the group size (useful when starting broadcaster)
function TeronAutoLFM.Core.Events.RefreshGroupSize()
  onGroupRosterChange()
end

--=============================================================================
-- SLASH COMMANDS
--=============================================================================
--- Handles slash command input and routes to appropriate actions
--- @param msg string - Command arguments (empty for toggle, "debug" for debug window)
local function handleSlashCommand(msg)
  msg = msg or ""
  local cmd = string.lower(string.sub(msg, 1, string.find(msg .. " ", " ") - 1))

  if cmd == "" then
    TeronAutoLFM.Core.Maestro.Dispatch("MainFrame.Toggle")
  elseif cmd == "debug" then
    TeronAutoLFM.Core.Maestro.Dispatch("Debug.Toggle")
  else
    TeronAutoLFM.Core.Utils.PrintTitle("=== TeronAutoLFM Commands ===")
    TeronAutoLFM.Core.Utils.Print("  /lfm - Toggle main window")
    TeronAutoLFM.Core.Utils.Print("  /lfm debug - Toggle debug window")
  end
end

--=============================================================================
-- STATE DECLARATIONS
--=============================================================================
TeronAutoLFM.Core.SafeRegisterState("Group.Type", "solo", { id = "S11" })
TeronAutoLFM.Core.SafeRegisterState("Group.Size", 1, { id = "S10" })
TeronAutoLFM.Core.SafeRegisterState("Group.IsLeader", false, { id = "S09" })

--=============================================================================
-- EVENT DECLARATIONS
--=============================================================================
TeronAutoLFM.Core.Maestro.RegisterEvent("Group.SizeChanged", { id = "E02" })
TeronAutoLFM.Core.Maestro.RegisterEvent("Group.LeaderChanged", { id = "E03" })
TeronAutoLFM.Core.Maestro.RegisterEvent("Chat.WhisperReceived", { id = "E08" })

--=============================================================================
-- INITIALIZATION
--=============================================================================
TeronAutoLFM.Core.SafeRegisterInit("Core.Events", function()
  TeronAutoLFM.Core.Events.Init()
end, { id = "I01" })

--=============================================================================
-- SLASH COMMAND REGISTRATION
--=============================================================================
SLASH_TERONAUTOLFM1 = "/lfm"
SlashCmdList["TERONAUTOLFM"] = handleSlashCommand
