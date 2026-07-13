--=============================================================================
-- TeronAutoLFM: Group Management
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Logic = TeronAutoLFM.Logic or {}
TeronAutoLFM.Logic.Group = {}

--=============================================================================
-- PRIVATE STATE
--=============================================================================
local conversionPending = false
local conversionFrame = CreateFrame("Frame")
conversionFrame:Hide()

-- Retry logic for failed conversion attempts
local MAX_CONVERSION_ATTEMPTS = 3
local conversionAttempts = 0

--=============================================================================
-- PUBLIC API
--=============================================================================
--- Gets current group size (1 for solo, 2-5 for party, 6-40 for raid)
--- @return number - Current group size
function TeronAutoLFM.Logic.Group.GetSize()
  return TeronAutoLFM.Core.Maestro.GetState("Group.Size") or 1
end

--- Gets current group type
--- @return string - "solo", "party", or "raid"
function TeronAutoLFM.Logic.Group.GetType()
  return TeronAutoLFM.Core.Maestro.GetState("Group.Type") or "solo"
end

--- Checks if player is party/raid leader or solo
--- @return boolean - True if player can invite
function TeronAutoLFM.Logic.Group.IsLeader()
  return TeronAutoLFM.Core.Maestro.GetState("Group.IsLeader") or false
end

--- Checks if player can invite (leader or solo)
--- @return boolean - True if player can invite
function TeronAutoLFM.Logic.Group.CanInvite()
  local groupType = TeronAutoLFM.Logic.Group.GetType()
  if groupType == "solo" then return true end
  return TeronAutoLFM.Logic.Group.IsLeader()
end

--- Gets the target group size based on current selection mode
--- @return number - Target group size (5 for dungeons, variable for raids/custom)
function TeronAutoLFM.Logic.Group.GetTargetSize()
  local selectionMode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")

  if selectionMode == "raid" then
    return TeronAutoLFM.Core.Maestro.GetState("Selection.RaidSize") or 40
  elseif selectionMode == "custom" then
    return TeronAutoLFM.Core.Maestro.GetState("Selection.CustomGroupSize") or 5
  end
  return 5
end

--- Attempts to convert party to raid if conditions are met
--- Uses deferred execution to avoid API call issues in event callbacks
--- Implements retry logic with exponential backoff for failed conversion attempts
--- Conditions: 2+ players, target size > 5, player is leader, in party (not raid)
function TeronAutoLFM.Logic.Group.ConvertToRaidIfNeeded()
  local groupSize = TeronAutoLFM.Logic.Group.GetSize()
  local targetSize = TeronAutoLFM.Logic.Group.GetTargetSize()

  -- Need at least 2 players and target > 5
  if groupSize < 2 or targetSize <= 5 then
    return
  end

  -- Must be in party (not already raid)
  local groupType = TeronAutoLFM.Logic.Group.GetType()
  if groupType ~= "party" then
    return
  end

  -- Must be leader
  if not TeronAutoLFM.Logic.Group.IsLeader() then
    return
  end

  -- Defer conversion to next frame to avoid API issues
  if conversionPending then
    return
  end

  conversionPending = true
  conversionAttempts = 0

  local function attemptConversion()
    conversionAttempts = conversionAttempts + 1
    local success, err = pcall(ConvertToRaid)

    if success then
      TeronAutoLFM.Core.Utils.PrintSuccess("Converted party to raid")
      conversionPending = false
      return true
    end

    -- Retry with exponential backoff if attempts remain
    if conversionAttempts < MAX_CONVERSION_ATTEMPTS then
      TeronAutoLFM.Core.Utils.LogWarning("Conversion attempt " .. conversionAttempts .. " failed, retrying...")
      -- Exponential backoff: 1 frame, 2 frames, 3 frames
      local backoffFrames = conversionAttempts
      local frameCounter = 0

      conversionFrame:SetScript("OnUpdate", function()
        frameCounter = frameCounter + 1
        if frameCounter >= backoffFrames then
          conversionFrame:SetScript("OnUpdate", nil)
          attemptConversion()
        end
      end)
      conversionFrame:Show()
      return false
    end

    -- Max attempts reached
    TeronAutoLFM.Core.Utils.LogError("Failed to convert to raid after " .. MAX_CONVERSION_ATTEMPTS .. " attempts: " .. tostring(err))
    conversionPending = false
    conversionFrame:Hide()
    return false
  end

  conversionFrame:SetScript("OnUpdate", function()
    conversionFrame:SetScript("OnUpdate", nil)
    conversionFrame:Hide()
    attemptConversion()
  end)
  conversionFrame:Show()
end

--=============================================================================
-- INITIALIZATION
--=============================================================================
TeronAutoLFM.Core.SafeRegisterInit("Logic.Group", function() end, {
  id = "I07",
  dependencies = { "Core.Events" }
})
