--=============================================================================
-- TeronAutoLFM: Broadcaster
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Logic = TeronAutoLFM.Logic or {}
TeronAutoLFM.Logic.Broadcaster = {}

--=============================================================================
-- PRIVATE STATE
--=============================================================================
local SOUNDS = {
  START = "Start.ogg",
  STOP = "Stop.ogg",
  FULL = "Full.ogg"
}

-- Retry state for failed broadcasts
local retryState = {
  pending = false,
  retriesLeft = 0,
  message = nil,
  channelName = nil,
  startTime = 0,
  delay = 0
}

--=============================================================================
-- PRIVATE HELPERS
--=============================================================================
--- Gets the current broadcast interval from state
--- @return number - Broadcast interval in seconds
local function getBroadcastInterval()
  return TeronAutoLFM.Core.Maestro.GetState("Broadcaster.Interval") or TeronAutoLFM.Core.Constants.DEFAULT_BROADCAST_INTERVAL or 60
end

--=============================================================================
-- STATISTICS MANAGEMENT
--=============================================================================
--- Resets broadcast statistics to zero
local function resetStats()
  TeronAutoLFM.Core.Maestro.SetState("Broadcaster.MessagesSent", 0)
  TeronAutoLFM.Core.Maestro.SetState("Broadcaster.SessionStartTime", GetTime())
  TeronAutoLFM.Core.Maestro.SetState("Broadcaster.LastBroadcastTime", 0)
end

--- Increments the message counter
local function incrementMessageCount()
  local count = (TeronAutoLFM.Core.Maestro.GetState("Broadcaster.MessagesSent") or 0) + 1
  TeronAutoLFM.Core.Maestro.SetState("Broadcaster.MessagesSent", count)
end

--- Updates the last broadcast timestamp
local function updateLastBroadcastTime()
  TeronAutoLFM.Core.Maestro.SetState("Broadcaster.LastBroadcastTime", GetTime())
end

--=============================================================================
-- GROUP CHANGE HANDLING
--=============================================================================
--- Handles group changes: convert to raid if needed, stop if full
local function onGroupChange()
  -- Convert to raid if needed (regardless of broadcaster state)
  TeronAutoLFM.Logic.Group.ConvertToRaidIfNeeded()

  -- Only check for full group if broadcaster is running
  local isRunning = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.IsRunning")
  if not isRunning then
    return
  end

  -- If group is full, stop broadcasting
  local groupSize = TeronAutoLFM.Logic.Group.GetSize()
  local targetSize = TeronAutoLFM.Logic.Group.GetTargetSize()

  if groupSize >= targetSize then
    TeronAutoLFM.Core.Utils.PrintSuccess("Group is full! Stopping broadcast.")
    -- NOTE: pcall used intentionally - sound files are optional and may not exist
    -- Failure to play sound should not interrupt broadcast functionality
    pcall(PlaySoundFile, TeronAutoLFM.Core.Constants.SOUND_PATH .. SOUNDS.FULL)
    TeronAutoLFM.Logic.Broadcaster.Toggle()
  end
end

--=============================================================================
-- MESSAGE BROADCASTING
--=============================================================================
--- Forward declaration for sendToChannel (needed for retry callback)
local sendToChannel

--- Handles retry tick callback from Ticker system
--- Processes pending retry if delay has elapsed
local function onRetryTick()
  if not retryState.pending then
    TeronAutoLFM.Core.Ticker.Stop(TeronAutoLFM.Core.Constants.TICKER_IDS.BROADCASTER_RETRY)
    return
  end

  local now = GetTime()
  if now - retryState.startTime >= retryState.delay then
    retryState.pending = false
    TeronAutoLFM.Core.Ticker.Stop(TeronAutoLFM.Core.Constants.TICKER_IDS.BROADCASTER_RETRY)
    sendToChannel(retryState.channelName, retryState.message, retryState.retriesLeft - 1)
  end
end

--- Schedules a retry for a failed broadcast with exponential backoff
--- Delay increases with each retry attempt to avoid spam during network issues
--- @param channelName string - The channel name to retry
--- @param message string - The message to send
--- @param retriesLeft number - Number of retries remaining
local function scheduleRetry(channelName, message, retriesLeft)
  if retriesLeft <= 0 then return end

  local baseDelay = TeronAutoLFM.Core.Constants.BROADCAST_RETRY_DELAY or 1
  local maxRetries = TeronAutoLFM.Core.Constants.MAX_BROADCAST_RETRIES or 2

  -- Exponential backoff: delay = baseDelay * 2^(attempt-1)
  local attemptNumber = maxRetries - retriesLeft + 1
  local delay = baseDelay * math.pow(2, attemptNumber - 1)

  TeronAutoLFM.Core.Utils.LogInfo("Retry scheduled in " .. delay .. "s (attempt " .. attemptNumber .. "/" .. maxRetries .. ")")

  -- Store retry state
  retryState.pending = true
  retryState.retriesLeft = retriesLeft
  retryState.message = message
  retryState.channelName = channelName
  retryState.startTime = GetTime()
  retryState.delay = delay

  -- Start retry ticker (checks every 0.5 seconds)
  TeronAutoLFM.Core.Ticker.Start(TeronAutoLFM.Core.Constants.TICKER_IDS.BROADCASTER_RETRY)
end

--- Sends a message to a specific channel with retry support
--- @param channelName string - The name of the channel
--- @param message string - The message to send
--- @param retries number - Number of retries remaining (optional, defaults to MAX_BROADCAST_RETRIES)
--- @return boolean - True if message was sent successfully
sendToChannel = function(channelName, message, retries)
  if retries == nil then
    retries = TeronAutoLFM.Core.Constants.MAX_BROADCAST_RETRIES or 2
  end

  local channelID = GetChannelName(channelName)

  if channelID > 0 then
    local success, err = pcall(SendChatMessage, message, "CHANNEL", nil, channelID)
    if success then
      TeronAutoLFM.Core.Utils.LogAction("Broadcast to " .. channelName .. ": " .. message)
      return true
    else
      TeronAutoLFM.Core.Utils.LogWarning("Failed to send to " .. channelName .. ": " .. tostring(err))
      if retries > 0 then
        TeronAutoLFM.Core.Utils.LogInfo("Retrying broadcast to " .. channelName .. " (" .. retries .. " attempts left)")
        scheduleRetry(channelName, message, retries)
      end
      return false
    end
  else
    TeronAutoLFM.Core.Utils.LogWarning("Not in channel: " .. channelName)
    return false
  end
end

--- Sends a message to the General channel (configurable index, default /1)
--- Channel index is read from Storage (set via V3_Settings.generalChannelIndex)
--- @param message string - The message to send
--- @return boolean - True if message was sent successfully
local function sendToGeneralChannel(message)
  local channelIndex = 1
  if TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.GetGeneralChannelIndex then
    channelIndex = TeronAutoLFM.Core.Storage.GetGeneralChannelIndex() or 1
  end
  local channelID, channelName = GetChannelName(channelIndex)
  if channelID and channelID > 0 then
    local success, err = pcall(SendChatMessage, message, "CHANNEL", nil, channelID)
    if success then
      TeronAutoLFM.Core.Utils.LogAction("Broadcast to General /" .. channelIndex .. " (" .. (channelName or tostring(channelIndex)) .. "): " .. message)
      return true
    else
      TeronAutoLFM.Core.Utils.LogWarning("Failed to send to General /" .. channelIndex .. ": " .. tostring(err))
      return false
    end
  else
    TeronAutoLFM.Core.Utils.LogWarning("Not in General channel /" .. channelIndex)
    return false
  end
end

--- Sends a message to the Hardcore channel (special handling)
--- @param message string - The message to send
--- @return boolean - True if message was sent successfully
local function sendToHardcoreChannel(message)
  local success, err = pcall(SendChatMessage, message, "Hardcore")
  if success then
    TeronAutoLFM.Core.Utils.LogAction("Broadcast to Hardcore: " .. message)
    return true
  else
    TeronAutoLFM.Core.Utils.LogWarning("Failed to send to Hardcore: " .. tostring(err))
    return false
  end
end

--- Sends the broadcast message to all selected channels
--- @return boolean - True if message was sent successfully
local function broadcastMessage()
  local message = TeronAutoLFM.Logic.Message.GetMessage()

  if not message or message == "" then
    TeronAutoLFM.Core.Utils.LogWarning("No message to broadcast (empty selection)")
    return false
  end

  local isDryRun = TeronAutoLFM.Core.Maestro.GetState("Settings.DryRun") or false
  local channels = TeronAutoLFM.Core.Maestro.GetState("Channels.ActiveChannels") or {}

  if table.getn(channels) == 0 and not isDryRun then
    TeronAutoLFM.Core.Utils.LogWarning("No channels selected for broadcast")
    return false
  end

  if isDryRun then
    local dryRunPrefix = TeronAutoLFM.Core.Utils.ColorText("[DRY RUN]", "YELLOW")
    TeronAutoLFM.Core.Utils.Print(dryRunPrefix .. " " .. message)
    TeronAutoLFM.Core.Utils.LogAction("Dry run broadcast: " .. message)
  else
    for i = 1, table.getn(channels) do
      local channelName = channels[i]
      if channelName == "Hardcore" then
        sendToHardcoreChannel(message)
      elseif channelName == "General" then
        sendToGeneralChannel(message)
      else
        sendToChannel(channelName, message)
      end
    end
  end

  incrementMessageCount()
  updateLastBroadcastTime()
  return true
end

--=============================================================================
-- TIMER MANAGEMENT
--=============================================================================
--- Timer tick handler - broadcasts message at regular intervals
--- Called by the Ticker system every second
--- @param elapsed number - Time elapsed since last tick (provided by Ticker)
local function onTimerTick(elapsed)
  local isRunning = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.IsRunning")
  if not isRunning then
    return
  end

  local currentTime = GetTime()
  local lastBroadcastTime = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.LastBroadcastTime") or 0
  local timeSinceLastBroadcast = currentTime - lastBroadcastTime
  local interval = getBroadcastInterval()

  if timeSinceLastBroadcast >= interval then
    broadcastMessage()
  end

  local timeRemaining = interval - timeSinceLastBroadcast
  if timeRemaining < 0 then timeRemaining = 0 end
  TeronAutoLFM.Core.Maestro.SetState("Broadcaster.TimeRemaining", timeRemaining)
end

--- Starts the broadcast timer using the centralized Ticker system
--- Performance: Uses shared OnUpdate frame instead of dedicated frame
local function startTimer()
  TeronAutoLFM.Core.Ticker.Start(TeronAutoLFM.Core.Constants.TICKER_IDS.BROADCASTER)
end

--- Stops the broadcast timer
--- Performance: Ticker system handles frame visibility automatically
local function stopTimer()
  TeronAutoLFM.Core.Ticker.Stop(TeronAutoLFM.Core.Constants.TICKER_IDS.BROADCASTER)
end

--=============================================================================
-- START/STOP (PRIVATE)
--=============================================================================
--- Starts broadcasting
local function start()
  local isRunning = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.IsRunning")
  if isRunning then
    TeronAutoLFM.Core.Utils.LogWarning("Broadcaster already running")
    return
  end

  local isDryRun = TeronAutoLFM.Core.Maestro.GetState("Settings.DryRun") or false

  resetStats()
  TeronAutoLFM.Core.Maestro.SetState("Broadcaster.IsRunning", true)
  -- NOTE: pcall used intentionally - sound files are optional and may not exist
  -- Failure to play sound should not interrupt broadcast functionality
  pcall(PlaySoundFile, TeronAutoLFM.Core.Constants.SOUND_PATH .. SOUNDS.START)

  if isDryRun then
    TeronAutoLFM.Core.Utils.PrintSuccess("Broadcast started in DRY RUN mode (messages will print to chat)")
  else
    TeronAutoLFM.Core.Utils.PrintSuccess("Broadcast started")
  end

  -- Convert to raid if needed
  TeronAutoLFM.Logic.Group.ConvertToRaidIfNeeded()

  -- Prompt for role assignment on anyone already in the group - the
  -- join-diff in Core/Events.lua only fires for players who join *after*
  -- this point, so pre-existing members need to be queued up separately
  if TeronAutoLFM.Components.RoleAssignPopup and TeronAutoLFM.Components.RoleAssignPopup.QueueExistingMembers then
    TeronAutoLFM.Components.RoleAssignPopup.QueueExistingMembers()
  end

  broadcastMessage()
  startTimer()
end

--- Stops broadcasting
local function stop()
  local isRunning = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.IsRunning")
  if not isRunning then
    TeronAutoLFM.Core.Utils.LogWarning("Broadcaster not running")
    return
  end

  stopTimer()
  TeronAutoLFM.Core.Maestro.SetState("Broadcaster.IsRunning", false)
  TeronAutoLFM.Core.Maestro.SetState("Broadcaster.TimeRemaining", 0)
  -- NOTE: pcall used intentionally - sound files are optional and may not exist
  -- Failure to play sound should not interrupt broadcast functionality
  pcall(PlaySoundFile, TeronAutoLFM.Core.Constants.SOUND_PATH .. SOUNDS.STOP)

  TeronAutoLFM.Core.Utils.PrintSuccess("Broadcast stopped")

  local sessionStartTime = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.SessionStartTime") or 0
  local messagesSent = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.MessagesSent") or 0
  local sessionDuration = GetTime() - sessionStartTime
  local minutes = math.floor(sessionDuration / 60)
  TeronAutoLFM.Core.Utils.Print(string.format("Session stats: %d messages in %d minutes", messagesSent, minutes))
end

--=============================================================================
-- PUBLIC API
--=============================================================================
--- Toggles broadcasting on/off
function TeronAutoLFM.Logic.Broadcaster.Toggle()
  local isRunning = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.IsRunning")
  if isRunning then
    stop()
  else
    start()
  end
end

--- Returns whether broadcaster is currently running
--- @return boolean - True if broadcasting is active
function TeronAutoLFM.Logic.Broadcaster.IsRunning()
  return TeronAutoLFM.Core.Maestro.GetState("Broadcaster.IsRunning") or false
end

--- Gets current broadcast statistics
--- @return table - Statistics object
function TeronAutoLFM.Logic.Broadcaster.GetStats()
  return {
    messagesSent = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.MessagesSent") or 0,
    sessionStartTime = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.SessionStartTime") or 0,
    lastBroadcastTime = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.LastBroadcastTime") or 0,
    isRunning = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.IsRunning") or false
  }
end

--- Sets the broadcast interval
--- @param interval number - Interval in seconds (30-120)
function TeronAutoLFM.Logic.Broadcaster.SetInterval(interval)
  -- Validate interval parameter
  if type(interval) ~= "number" then
    TeronAutoLFM.Core.Utils.LogError("SetInterval: interval must be number, got " .. type(interval))
    return false
  end

  -- Validate interval is within acceptable range
  if interval < TeronAutoLFM.Core.Constants.MIN_BROADCAST_INTERVAL or interval > TeronAutoLFM.Core.Constants.MAX_BROADCAST_INTERVAL then
    TeronAutoLFM.Core.Utils.LogWarning("SetInterval: interval out of range [" .. TeronAutoLFM.Core.Constants.MIN_BROADCAST_INTERVAL .. "-" .. TeronAutoLFM.Core.Constants.MAX_BROADCAST_INTERVAL .. "], got " .. interval)
  end

  local clampedInterval = math.max(TeronAutoLFM.Core.Constants.MIN_BROADCAST_INTERVAL, math.min(TeronAutoLFM.Core.Constants.MAX_BROADCAST_INTERVAL, interval))
  local oldInterval = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.Interval") or 60

  if oldInterval == clampedInterval then return end

  TeronAutoLFM.Core.Maestro.SetState("Broadcaster.Interval", clampedInterval)

  if TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.SetBroadcastInterval then
    TeronAutoLFM.Core.Storage.SetBroadcastInterval(clampedInterval)
  end
end

--- Gets the current broadcast interval
--- @return number - Interval in seconds
function TeronAutoLFM.Logic.Broadcaster.GetInterval()
  return getBroadcastInterval()
end

--=============================================================================
-- STATE DECLARATIONS
--=============================================================================
TeronAutoLFM.Core.SafeRegisterState("Broadcaster.IsRunning", false, { id = "S13" })
TeronAutoLFM.Core.SafeRegisterState("Broadcaster.Interval", 60, { id = "S12" })
TeronAutoLFM.Core.SafeRegisterState("Broadcaster.MessagesSent", 0, { id = "S15" })
TeronAutoLFM.Core.SafeRegisterState("Broadcaster.SessionStartTime", 0, { id = "S16" })
TeronAutoLFM.Core.SafeRegisterState("Broadcaster.LastBroadcastTime", 0, { id = "S14" })
TeronAutoLFM.Core.SafeRegisterState("Broadcaster.TimeRemaining", 0, { id = "S17" })

--=============================================================================
-- COMMAND DECLARATIONS
--=============================================================================
TeronAutoLFM.Core.Maestro.RegisterCommand("Broadcaster.Toggle", function()
  TeronAutoLFM.Logic.Broadcaster.Toggle()
end, { id = "C15" })

--=============================================================================
-- INITIALIZATION
--=============================================================================
TeronAutoLFM.Core.SafeRegisterInit("Logic.Broadcaster", function()
  -- Register broadcast timer ticker (1 second interval, starts stopped)
  TeronAutoLFM.Core.Ticker.Register(
    TeronAutoLFM.Core.Constants.TICKER_IDS.BROADCASTER,
    TeronAutoLFM.Core.Constants.BROADCASTER_TIMER_INTERVAL or 1,
    onTimerTick,
    false  -- Don't start immediately
  )

  -- Register retry ticker (0.5 second interval for responsive retries, starts stopped)
  TeronAutoLFM.Core.Ticker.Register(
    TeronAutoLFM.Core.Constants.TICKER_IDS.BROADCASTER_RETRY,
    0.5,
    onRetryTick,
    false  -- Don't start immediately
  )

  TeronAutoLFM.Core.Maestro.Listen(
    "Broadcaster.OnGroupSizeChanged",
    "Group.SizeChanged",
    onGroupChange,
    { id = "L03" }
  )

  if TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.GetBroadcastInterval then
    local savedInterval = TeronAutoLFM.Core.Storage.GetBroadcastInterval()
    -- NOTE: Use explicit nil check instead of 'if savedInterval' to handle interval = 0 correctly
    if savedInterval ~= nil then
      TeronAutoLFM.Core.Maestro.SetState("Broadcaster.Interval", savedInterval)
    end
  end
end, {
  id = "I09",
  dependencies = { "Logic.Message", "Logic.Group", "Logic.Content.Messaging", "Core.Events", "Core.Ticker" }
})
