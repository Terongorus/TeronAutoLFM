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
local assignedRoles = {}       -- [playerName] = role, for players already assigned a role

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

--- Removes a name from the pending queue, if present (e.g. they left the
--- group before the leader got around to assigning them a role)
--- @param playerName string - Name to remove from the queue
local function removeFromQueue(playerName)
  local newQueue = {}
  for i = 1, table.getn(pendingQueue) do
    if pendingQueue[i] ~= playerName then
      table.insert(newQueue, pendingQueue[i])
    end
  end
  pendingQueue = newQueue
end

--- Clears all pending/assigned tracking and hides the popup. Called when
--- broadcasting stops, since a stale assignment from a finished recruiting
--- session could otherwise incorrectly restore a role count in a later,
--- unrelated one if that same player happens to leave afterward
local function resetTracking()
  pendingQueue = {}
  assignedRoles = {}
  currentPlayerName = nil

  local popup = getglobal("TeronAutoLFM_RoleAssignPopup")
  if popup then popup:Hide() end
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

--- Queues every group member already present (besides the leader) for role
--- assignment. Call this when broadcasting starts - the join-diff in
--- Core/Events.lua only ever fires for names it hasn't already seen, so
--- players who were in the group *before* recruiting began would otherwise
--- never get prompted at all
function TeronAutoLFM.Components.RoleAssignPopup.QueueExistingMembers()
  if not TeronAutoLFM.Core.Events or not TeronAutoLFM.Core.Events.GetCurrentMemberList then return end

  local members = TeronAutoLFM.Core.Events.GetCurrentMemberList()
  local selfName = UnitName("player")

  for i = 1, table.getn(members) do
    local name = members[i]
    if name ~= selfName then
      TeronAutoLFM.Components.RoleAssignPopup.QueueJoin(name)
    end
  end
end

--- XML OnClick callback for a role button - decrements that role's count,
--- remembers the assignment (so the count can be restored if this player
--- later leaves), and advances to the next queued player
--- @param role string - "TANK", "HEAL", or "DPS"
function TeronAutoLFM.Components.RoleAssignPopup.OnRoleClick(role)
  TeronAutoLFM.Core.Maestro.Dispatch("Selection.DecrementRoleCount", role)
  if currentPlayerName then
    assignedRoles[currentPlayerName] = role
  end
  TeronAutoLFM.Core.Utils.LogAction(tostring(currentPlayerName) .. " assigned as " .. role)
  showNext()
end

--- XML OnClick callback for the Skip button - advances without changing
--- any role count
function TeronAutoLFM.Components.RoleAssignPopup.OnSkipClick()
  showNext()
end

--- Handles a group member leaving. If they'd already been assigned a role,
--- restores that role's headcount (see Selection.IncrementRoleCount).
--- Otherwise, if they were still waiting in the queue (or are the player
--- currently shown in the popup), removes them so the leader is never
--- asked to assign a role to someone who's no longer in the group.
--- @param playerName string - Name of the player who left
function TeronAutoLFM.Components.RoleAssignPopup.OnPlayerLeft(playerName)
  if not playerName then return end

  local role = assignedRoles[playerName]
  if role then
    assignedRoles[playerName] = nil
    TeronAutoLFM.Core.Maestro.Dispatch("Selection.IncrementRoleCount", role)
    TeronAutoLFM.Core.Utils.LogAction(playerName .. " left - " .. role .. " headcount restored")
    return
  end

  removeFromQueue(playerName)

  if currentPlayerName == playerName then
    showNext()
  end
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

  TeronAutoLFM.Core.Maestro.Listen(
    "Components.RoleAssignPopup.OnPlayerLeft",
    "Group.PlayerLeft",
    function(payload)
      if payload and payload.name then
        TeronAutoLFM.Components.RoleAssignPopup.OnPlayerLeft(payload.name)
      end
    end,
    { id = "L13" }
  )

  TeronAutoLFM.Core.Maestro.SubscribeState("Broadcaster.IsRunning", function(newValue)
    if not newValue then
      resetTracking()
    end
  end)
end, {
  id = "I28",
  dependencies = { "Core.Events", "Logic.Selection", "Logic.Broadcaster" }
})
