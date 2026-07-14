--=============================================================================
-- TeronAutoLFM: Role Assign Popup
--=============================================================================
-- Shown when a new player joins while actively recruiting, letting the
-- leader assign the role they filled so role headcounts (and dungeon's
-- fixed 1/1/3 composition) auto-decrement without manual editing.
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Components = TeronAutoLFM.Components or {}
TeronAutoLFM.Components.RoleAssignPopup = {}

--=============================================================================
-- PRIVATE STATE
--=============================================================================
local pendingQueue = {}        -- FIFO array of player names awaiting assignment
local currentPlayerName = nil  -- Name currently shown in the popup, or nil

--=============================================================================
-- PRIVATE HELPERS
--=============================================================================
--- Determines whether the join popup should fire right now
--- @return boolean - True only when actively recruiting as the group leader
local function shouldPrompt()
  local isLeader = TeronAutoLFM.Core.Maestro.GetState("Group.IsLeader")
  local isBroadcasting = TeronAutoLFM.Core.Maestro.GetState("Broadcaster.IsRunning")
  local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")
  local roleCounts = TeronAutoLFM.Core.Maestro.GetState("Selection.RoleCounts") or {}

  if not isLeader or not isBroadcasting then return false end
  if mode ~= "dungeons" and mode ~= "raid" then return false end

  return next(roleCounts) ~= nil
end

--- Shows/hides each role button based on which roles are still being tracked
local function updateButtonVisibility()
  local roleCounts = TeronAutoLFM.Core.Maestro.GetState("Selection.RoleCounts") or {}
  local buttons = {
    TANK = getglobal("TeronAutoLFM_RoleAssignPopup_TankButton"),
    HEAL = getglobal("TeronAutoLFM_RoleAssignPopup_HealButton"),
    DPS = getglobal("TeronAutoLFM_RoleAssignPopup_DPSButton")
  }

  for role, button in pairs(buttons) do
    if button then
      if roleCounts[role] then
        button:Show()
      else
        button:Hide()
      end
    end
  end
end

--- Shows the next queued player in the popup, or hides it if the queue is empty
local function showNext()
  local popup = getglobal("TeronAutoLFM_RoleAssignPopup")

  if table.getn(pendingQueue) == 0 then
    currentPlayerName = nil
    if popup then popup:Hide() end
    return
  end

  -- Skip anyone who no longer makes sense to prompt for (e.g. broadcast
  -- was stopped, or every role got filled while they were queued)
  if not shouldPrompt() then
    pendingQueue = {}
    currentPlayerName = nil
    if popup then popup:Hide() end
    return
  end

  currentPlayerName = table.remove(pendingQueue, 1)

  local nameText = getglobal("TeronAutoLFM_RoleAssignPopup_NameText")
  if nameText then
    nameText:SetText(currentPlayerName)
  end

  updateButtonVisibility()

  if popup then
    popup:Show()
  end
end

--=============================================================================
-- PUBLIC API
--=============================================================================
--- Queues a newly-joined player for role assignment, if currently recruiting
--- @param playerName string - Name of the player who joined
function TeronAutoLFM.Components.RoleAssignPopup.QueueJoin(playerName)
  if not playerName or playerName == "" then return end
  if not shouldPrompt() then return end

  table.insert(pendingQueue, playerName)

  -- If nothing is currently displayed, start processing right away
  if not currentPlayerName then
    showNext()
  end
end

--- XML OnClick callback for a role button - decrements that role's count
--- and advances to the next queued player
--- @param role string - "TANK", "HEAL", or "DPS"
function TeronAutoLFM.Components.RoleAssignPopup.OnRoleClick(role)
  TeronAutoLFM.Core.Maestro.Dispatch("Selection.DecrementRoleCount", role)
  TeronAutoLFM.Core.Utils.LogAction(tostring(currentPlayerName) .. " assigned as " .. role)
  showNext()
end

--- XML OnClick callback for the Skip button - advances without changing
--- any role count
function TeronAutoLFM.Components.RoleAssignPopup.OnSkipClick()
  showNext()
end

--=============================================================================
-- INITIALIZATION
--=============================================================================
TeronAutoLFM.Core.SafeRegisterInit("Components.RoleAssignPopup", function()
  TeronAutoLFM.Core.Maestro.Listen(
    "Components.RoleAssignPopup.OnPlayerJoined",
    "Group.PlayerJoined",
    function(payload)
      if payload and payload.name then
        TeronAutoLFM.Components.RoleAssignPopup.QueueJoin(payload.name)
      end
    end,
    { id = "L09" }
  )
end, {
  id = "I25",
  dependencies = { "Core.Events", "Logic.Selection" }
})
