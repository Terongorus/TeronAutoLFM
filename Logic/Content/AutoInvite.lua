--=============================================================================
-- TeronAutoLFM: AutoInvite Logic
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Logic = TeronAutoLFM.Logic or {}
TeronAutoLFM.Logic.AutoInvite = {}

--=============================================================================
-- PRIVATE STATE
--=============================================================================
-- Cooldown tracking: stores last invite time per player to prevent spam
-- Key: player name (lowercase), Value: GetTime() timestamp of last invite
local lastInviteTime = {}

--=============================================================================
-- INVITE MESSAGES
--=============================================================================
-- Mixed pool of themed (Light/Crusade) and generic messages for variety
local inviteMessages = {
  "%s, the Light demands your presence!",
  "%s, by the Light! Join us!",
  "%s, the Light calls you to adventure!",
  "%s, the crusade awaits!",
  "%s, blessed hammer in hand, join the fight!",
  "%s, you're in! Welcome aboard.",
  "%s, grab your gear and let's go!",
  "Welcome %s! Let's do this.",
  "%s, invitation sent! See you soon.",
  "Hey %s! You're invited, join up!",
  "%s, pack your bags, adventure awaits!",
  "Roger that %s, you're in!",
  "%s, we've got room for one more hero!"
}

--- Returns a random invitation message with the target name
--- @param target string - Player name to insert in the message
--- @return string - Formatted invitation message
local function getRandomInviteMessage(target)
  local index = math.random(1, table.getn(inviteMessages))
  return string.format(inviteMessages[index], target)
end

--=============================================================================
-- HELPERS
--=============================================================================
--- Checks if a player is on cooldown (recently invited)
--- Prevents spam if someone sends multiple whispers quickly
--- @param sender string - Player name to check
--- @return boolean - True if player can be invited, false if on cooldown
local function canInvitePlayer(sender)
  local senderLower = string.lower(sender)
  local now = GetTime()
  local lastTime = lastInviteTime[senderLower]
  local cooldown = TeronAutoLFM.Core.Constants.INVITE_COOLDOWN or 5

  if lastTime and (now - lastTime) < cooldown then
    TeronAutoLFM.Core.Utils.LogInfo("Auto-invite cooldown: " .. sender .. " (wait " .. math.ceil(cooldown - (now - lastTime)) .. "s)")
    return false
  end

  return true
end

--- Records an invite timestamp for cooldown tracking
--- @param sender string - Player name that was invited
local function recordInvite(sender)
  local senderLower = string.lower(sender)
  lastInviteTime[senderLower] = GetTime()
end

--- Removes expired entries from cooldown table to prevent unbounded memory growth
--- Called periodically by the centralized Ticker system
--- @param elapsed number - Time elapsed since last tick (provided by Ticker)
local function cleanupExpiredCooldowns(elapsed)
  local now = GetTime()
  local cooldown = TeronAutoLFM.Core.Constants.INVITE_COOLDOWN or 5
  local removedCount = 0

  for playerName, timestamp in pairs(lastInviteTime) do
    if (now - timestamp) > cooldown then
      lastInviteTime[playerName] = nil
      removedCount = removedCount + 1
    end
  end

  if removedCount > 0 then
    TeronAutoLFM.Core.Utils.LogInfo("Auto-invite cleanup: removed " .. removedCount .. " expired entries")
  end
end

--- Starts the periodic cleanup using the centralized Ticker system
local function startCleanupTimer()
  TeronAutoLFM.Core.Ticker.Start(TeronAutoLFM.Core.Constants.TICKER_IDS.INVITE_CLEANUP)
end

--- Stops the periodic cleanup and clears cooldown data
local function stopCleanupTimer()
  TeronAutoLFM.Core.Ticker.Stop(TeronAutoLFM.Core.Constants.TICKER_IDS.INVITE_CLEANUP)
  -- Clear cooldown table to free memory immediately
  lastInviteTime = {}
end

--- Checks if a message matches any of the configured keywords
--- Keywords are sanitized to prevent pattern injection attacks
--- @param message string - The whisper message to check
--- @param keywords table - Array of keyword strings to match
--- @return boolean - True if any keyword matches
local function matchesKeyword(message, keywords)
  local lowerMsg = string.lower(TeronAutoLFM.Core.Utils.Trim(message))

  for i = 1, table.getn(keywords) do
    local keyword = keywords[i]
    if keyword and keyword ~= "" then
      -- Sanitize keyword to prevent pattern injection
      local sanitizedKey = TeronAutoLFM.Core.Utils.EscapePattern(string.lower(keyword))
      if string.find(lowerMsg, sanitizedKey) then
        return true
      end
    end
  end

  return false
end

--- Sends confirmation whisper to invited player
--- @param sender string - Player name to send to
--- @param useRandomMsg boolean - Whether to use random message
local function sendInviteConfirmation(sender, useRandomMsg)
  if useRandomMsg then
    SendChatMessage(getRandomInviteMessage(sender), "WHISPER", nil, sender)
  else
    SendChatMessage("Invitation sent!", "WHISPER", nil, sender)
  end
end

--- Sends rejection message when not leader or assist
--- @param sender string - Player name to send to
local function sendNotLeaderMessage(sender)
  SendChatMessage("Cannot invite: I'm not leader or assist.", "WHISPER", nil, sender)
end

--=============================================================================
-- INVITE LOGIC
--=============================================================================
--- Handles incoming whisper messages and auto-invites if keyword matches
--- @param data table - Whisper data with message and sender fields
local function handleWhisper(data)
  if not data then return end

  local enabled = TeronAutoLFM.Core.Storage.GetAutoInviteEnabled()
  if not enabled then return end

  local message = data.message
  local sender = data.sender
  if not message or not sender then return end

  -- Ignore self-whispers
  if sender == UnitName("player") then return end

  -- Check if message matches any keyword
  local keywords = TeronAutoLFM.Core.Storage.GetAutoInviteKeywords() or {"+1"}
  if not matchesKeyword(message, keywords) then return end

  -- Check cooldown to prevent spam from same player
  if not canInvitePlayer(sender) then return end

  -- Get settings
  local sendConfirm = TeronAutoLFM.Core.Storage.GetAutoInviteConfirm()
  local useRandomMsg = TeronAutoLFM.Core.Storage.GetAutoInviteRandomMessages()
  local respondWhenNotLeader = TeronAutoLFM.Core.Storage.GetAutoInviteRespondWhenNotLeader()

  -- Check if we can invite
  if TeronAutoLFM.Logic.Group.CanInvite() then
    InviteByName(sender)
    recordInvite(sender)  -- Record invite for cooldown tracking

    if sendConfirm then
      sendInviteConfirmation(sender, useRandomMsg)
    end

    TeronAutoLFM.Core.Utils.LogAction("Auto-invited " .. sender)
  else
    -- Not leader, optionally send message
    if respondWhenNotLeader and sendConfirm then
      sendNotLeaderMessage(sender)
      recordInvite(sender)  -- Also record to prevent spam of "not leader" messages
    end
  end
end

--=============================================================================
-- COMMANDS
--=============================================================================
--- Command: Enable AutoInvite
--- Activates automatic group invitations based on whisper keywords
TeronAutoLFM.Core.Maestro.RegisterCommand("AutoInvite.Enable", function()
  TeronAutoLFM.Core.Storage.SetAutoInviteEnabled(true)
  startCleanupTimer()
  TeronAutoLFM.Core.Utils.PrintSuccess("Auto Invite enabled")
  TeronAutoLFM.Core.Maestro.Dispatch("AutoInvite.Changed")
end, { id = "C23" })

--- Command: Disable AutoInvite
--- Deactivates automatic group invitations
TeronAutoLFM.Core.Maestro.RegisterCommand("AutoInvite.Disable", function()
  TeronAutoLFM.Core.Storage.SetAutoInviteEnabled(false)
  stopCleanupTimer()
  TeronAutoLFM.Core.Utils.PrintWarning("Auto Invite disabled")
  TeronAutoLFM.Core.Maestro.Dispatch("AutoInvite.Changed")
end, { id = "C22" })

--- Command: Toggle confirmation messages
--- Enables/disables sending confirmation whispers to invited players
TeronAutoLFM.Core.Maestro.RegisterCommand("AutoInvite.ToggleConfirm", function()
  local current = TeronAutoLFM.Core.Storage.GetAutoInviteConfirm()
  TeronAutoLFM.Core.Storage.SetAutoInviteConfirm(not current)
  local status = (not current) and "enabled" or "disabled"
  TeronAutoLFM.Core.Utils.PrintInfo("Confirmation whisper " .. status)
  TeronAutoLFM.Core.Maestro.Dispatch("AutoInvite.Changed")
end, { id = "C24" })

--=============================================================================
-- EVENTS
--=============================================================================
--- Event: AutoInvite.Changed
--- Dispatched when AutoInvite settings change (enabled, keyword, confirmation)
TeronAutoLFM.Core.Maestro.RegisterEvent("AutoInvite.Changed", { id = "E09" })

--=============================================================================
-- EVENT HANDLERS
--=============================================================================
--- Handles group leader/assist changes
--- No longer disables AutoInvite; it simply won't work until player becomes leader or assist again
--- @param data table - Leader change data with isLeader field
local function onLeaderChanged(data)
  -- AutoInvite remains enabled even if player loses leadership/assist
  -- It will simply not invite anyone until player becomes leader or assist again
  if not data.isLeader then
    TeronAutoLFM.Core.Utils.LogInfo("Auto Invite paused: You are no longer leader or assist (will resume if you become leader or assist again)")
  else
    TeronAutoLFM.Core.Utils.LogInfo("Auto Invite active: You are now leader or assist")
  end
end

--=============================================================================
-- INITIALIZATION
--=============================================================================
--- Initializes AutoInvite module
--- Registers listeners for whisper and leader change events
TeronAutoLFM.Core.SafeRegisterInit("Logic.AutoInvite", function()
  -- Register cleanup ticker (60 second interval, starts stopped)
  local cleanupInterval = TeronAutoLFM.Core.Constants.INVITE_COOLDOWN_CLEANUP_INTERVAL or 60
  TeronAutoLFM.Core.Ticker.Register(
    TeronAutoLFM.Core.Constants.TICKER_IDS.INVITE_CLEANUP,
    cleanupInterval,
    cleanupExpiredCooldowns,
    false  -- Don't start immediately
  )

  TeronAutoLFM.Core.Maestro.Listen(
    "AutoInvite.OnWhisper",
    "Chat.WhisperReceived",
    handleWhisper,
    { id = "L07" }
  )

  TeronAutoLFM.Core.Maestro.Listen(
    "AutoInvite.OnLeaderChanged",
    "Group.LeaderChanged",
    onLeaderChanged,
    { id = "L08" }
  )

  -- Start periodic cleanup only if auto-invite is already enabled
  if TeronAutoLFM.Core.Storage.GetAutoInviteEnabled() then
    startCleanupTimer()
  end
end, {
  id = "I16",
  dependencies = { "Core.Events", "Core.Ticker" }
})
