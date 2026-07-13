--=============================================================================
-- TeronAutoLFM: Minimap Button
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Components = TeronAutoLFM.Components or {}
TeronAutoLFM.Components.MinimapButton = {}

--=============================================================================
-- PUBLIC API
--=============================================================================
--- Shows the minimap button and saves visibility state
function TeronAutoLFM.Components.MinimapButton.Show()
  local button = getglobal("TeronAutoLFM_MinimapButton")
  if button then
      button:Show()
      TeronAutoLFM.Core.Storage.SetMinimapHidden(false)
  end
end

--- Hides the minimap button and saves visibility state
function TeronAutoLFM.Components.MinimapButton.Hide()
  local button = getglobal("TeronAutoLFM_MinimapButton")
  if button then
      button:Hide()
      TeronAutoLFM.Core.Storage.SetMinimapHidden(true)
  end
end

--- Toggles minimap button visibility (show/hide)
function TeronAutoLFM.Components.MinimapButton.Toggle()
  local button = getglobal("TeronAutoLFM_MinimapButton")
  if not button then return end

  if button:IsVisible() then
      TeronAutoLFM.Components.MinimapButton.Hide()
  else
      TeronAutoLFM.Components.MinimapButton.Show()
  end
end

--- Resets minimap button to default position (left side of minimap)
function TeronAutoLFM.Components.MinimapButton.ResetPosition()
  local button = getglobal("TeronAutoLFM_MinimapButton")
  if button then
      button:ClearAllPoints()
      button:SetPoint("LEFT", Minimap, "LEFT", 16, -68)
  end
end

--=============================================================================
-- EVENT HANDLERS
--=============================================================================
--- Handles minimap button click events
--- Left-click: Toggle main frame
--- Ctrl+Right-click: Reset position
--- @param button frame - The minimap button frame
--- @param mouseButton string - "LeftButton" or "RightButton"
function TeronAutoLFM.Components.MinimapButton.OnClick(button, mouseButton)
  if mouseButton == "LeftButton" then
      TeronAutoLFM.Core.Maestro.Dispatch("MainFrame.Toggle")
  elseif mouseButton == "RightButton" and IsControlKeyDown() then
      -- Reset minimap button position directly
      TeronAutoLFM.Core.Storage.SetMinimapPos(nil, nil)
      TeronAutoLFM.Components.MinimapButton.ResetPosition()
      TeronAutoLFM.Core.Utils.LogInfo("Reset minimap button position")
  end
end

--- Handles minimap button drag stop event, saves new position
--- @param button frame - The minimap button frame
function TeronAutoLFM.Components.MinimapButton.OnDragStop(button)
  if not button then return end

  -- Get current position
  local scale = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
  local x, y = button:GetCenter()
  if x and y then
      x = x * scale
      y = y * scale

      -- Save position to Persistent
      TeronAutoLFM.Core.Storage.SetMinimapPos(x, y)
  end
end

--- Shows tooltip on minimap button hover
--- @param button frame - The minimap button frame
function TeronAutoLFM.Components.MinimapButton.OnEnter(button)
  GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  GameTooltip:SetText("TeronAuto|cff0070DDL|r|cffffffffF|r|cffff0000M")
  GameTooltip:AddLine("Left-click to open main window.", 1, 1, 1)
  GameTooltip:AddLine("Hold control and drag to move.", 1, 1, 1)
  GameTooltip:AddLine("Hold control and right-click to reset position.", 1, 1, 1)
  GameTooltip:Show()
end

--=============================================================================
-- INITIALIZATION
--=============================================================================
--- Initializes minimap button from persistent settings
--- Restores saved position and visibility state
function TeronAutoLFM.Components.MinimapButton.Init()
  local button = getglobal("TeronAutoLFM_MinimapButton")
  if not button then return end

  -- Load saved position
  local pos = TeronAutoLFM.Core.Storage.GetMinimapPos()
  if pos and pos.x and pos.y then
      button:ClearAllPoints()
      button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
  end

  -- Load visibility state (minimapHidden stored, so we invert it)
  local isHidden = TeronAutoLFM.Core.Storage.GetMinimapHidden()
  if isHidden then
      button:Hide()
  else
      button:Show()
  end
end

TeronAutoLFM.Core.SafeRegisterInit("Minimap", function()
  -- Initialize button from saved state
  TeronAutoLFM.Components.MinimapButton.Init()

  -- No commands to register - all minimap operations go through Settings commands
end, {
  id = "I23",
  dependencies = {"Core.Storage"} -- Must run after Persistent loads
})
