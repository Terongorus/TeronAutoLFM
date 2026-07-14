--=============================================================================
-- TeronAutoLFM: My Role Prompt
--=============================================================================
-- Shown once whenever a dungeon or raid is first selected while the leader
-- hasn't set their own role (Selection.MyRole) yet, so it can be accounted
-- for automatically. Dismissing without picking just means it asks again
-- the next time a dungeon/raid is selected - picking a role (anywhere,
-- including the Settings tab) stops it from firing again.
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Components = TeronAutoLFM.Components or {}
TeronAutoLFM.Components.MyRolePrompt = {}

--=============================================================================
-- PRIVATE HELPERS
--=============================================================================
--- Shows the prompt if a dungeon/raid is selected and no role is set yet
local function maybeShow()
  local mode = TeronAutoLFM.Core.Maestro.GetState("Selection.Mode")
  if mode ~= "dungeons" and mode ~= "raid" then return end

  local myRole = TeronAutoLFM.Core.Maestro.GetState("Selection.MyRole")
  if myRole then return end

  local popup = getglobal("TeronAutoLFM_MyRolePrompt")
  if popup then popup:Show() end
end

--=============================================================================
-- PUBLIC API
--=============================================================================
--- XML OnClick callback for a role button - sets the leader's own role and
--- closes the prompt
--- @param role string - "TANK", "HEAL", or "DPS"
function TeronAutoLFM.Components.MyRolePrompt.OnRoleClick(role)
  TeronAutoLFM.Core.Maestro.Dispatch("Selection.SetMyRole", role)

  local popup = getglobal("TeronAutoLFM_MyRolePrompt")
  if popup then popup:Hide() end
end

--- XML OnClick callback for the close button - dismisses without picking
function TeronAutoLFM.Components.MyRolePrompt.OnCloseClick()
  local popup = getglobal("TeronAutoLFM_MyRolePrompt")
  if popup then popup:Hide() end
end

--=============================================================================
-- INITIALIZATION
--=============================================================================
TeronAutoLFM.Core.SafeRegisterInit("Components.MyRolePrompt", function()
  TeronAutoLFM.Core.Maestro.SubscribeState("Selection.Mode", function(newValue, oldValue)
    maybeShow()
  end)
end, {
  id = "I29",
  dependencies = { "Logic.Selection" }
})
