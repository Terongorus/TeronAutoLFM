--=============================================================================
-- TeronAutoLFM: Eye Animation Component
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Components = TeronAutoLFM.Components or {}
TeronAutoLFM.Components.EyeAnimation = {}

--=============================================================================
-- CONSTANTS
--=============================================================================
local ANIMATION_FRAMES = {
  "Eye01", "Eye02", "Eye03", "Eye04", "Eye05", "Eye04", "Eye03", "Eye02", "Eye01", "Eye00",
  "Eye06", "Eye07", "Eye08", "Eye09", "Eye10", "Eye09", "Eye08", "Eye07", "Eye06", "Eye00",
  "Eye11", "Eye12", "Eye13", "Eye14", "Eye15", "Eye14", "Eye13", "Eye12", "Eye11", "Eye00"
}

local ANIMATION_SPEED = 0.15  -- seconds per frame

--=============================================================================
-- PRIVATE STATE
--=============================================================================
local animationTimer = nil
local currentFrameIndex = 1
local lastFrameTime = 0
local isAnimating = false

--=============================================================================
-- HELPER FUNCTIONS
--=============================================================================
--- Updates the texture of an icon to display the current animation frame
--- @param textureName string - The global name of the texture (e.g., "TeronAutoLFM_MainFrame_Icon")
--- @param frameName string - The name of the frame (e.g., "Eye01")
local function updateIconTexture(textureName, frameName)
  local texture = getglobal(textureName)
  if not texture then return end
  
  local path = "Interface\\AddOns\\TeronAutoLFM\\UI\\Textures\\Eye\\" .. frameName
  texture:SetTexture(path)
end

--- Ensures the animation frame exists (created once, reused)
local function ensureAnimationFrame()
  if animationTimer then return end
  animationTimer = CreateFrame("Frame", "TeronAutoLFM_EyeAnimationTimer")
  animationTimer:Hide()
  animationTimer:SetScript("OnUpdate", function()
    local currentTime = GetTime()
    if currentTime - lastFrameTime >= ANIMATION_SPEED then
      lastFrameTime = currentTime
      currentFrameIndex = currentFrameIndex + 1
      if currentFrameIndex > table.getn(ANIMATION_FRAMES) then
        currentFrameIndex = 1
      end
      local frameName = ANIMATION_FRAMES[currentFrameIndex]
      updateIconTexture("TeronAutoLFM_MainFrame_Icon", frameName)
      updateIconTexture("TeronAutoLFM_MinimapButton_Icon", frameName)
    end
  end)
end

--- Starts the animation loop
local function startAnimation()
  if isAnimating then return end
  isAnimating = true
  currentFrameIndex = 0
  lastFrameTime = GetTime()
  ensureAnimationFrame()
  animationTimer:Show()
end

--- Stops the animation loop
local function stopAnimation()
  isAnimating = false
  currentFrameIndex = 1
  if animationTimer then
    animationTimer:Hide()
  end
  updateIconTexture("TeronAutoLFM_MainFrame_Icon", "Eye00")
  updateIconTexture("TeronAutoLFM_MinimapButton_Icon", "Eye00")
end

--=============================================================================
-- PUBLIC API
--=============================================================================
--- Starts the eye animation
function TeronAutoLFM.Components.EyeAnimation.Start()
  if not isAnimating then
    startAnimation()
  end
end

--- Stops the eye animation
function TeronAutoLFM.Components.EyeAnimation.Stop()
  if isAnimating then
    stopAnimation()
  end
end

--- Returns whether animation is currently running
--- @return boolean - True if animation is active
function TeronAutoLFM.Components.EyeAnimation.IsAnimating()
  return isAnimating
end

--=============================================================================
-- INITIALIZATION
--=============================================================================
TeronAutoLFM.Core.SafeRegisterInit("Components.EyeAnimation", function()
  --- Listen to Broadcaster.IsRunning state changes
  TeronAutoLFM.Core.Maestro.SubscribeState("Broadcaster.IsRunning", function(newValue, oldValue)
    if newValue then
      -- Start animation when broadcast starts
      TeronAutoLFM.Components.EyeAnimation.Start()
    else
      -- Stop animation when broadcast stops
      TeronAutoLFM.Components.EyeAnimation.Stop()
    end
  end)
  
  -- Start animation if broadcaster is already running
  if TeronAutoLFM.Core.Maestro.GetState("Broadcaster.IsRunning") then
    TeronAutoLFM.Components.EyeAnimation.Start()
  end
end, {
  id = "I19",
  dependencies = { "Logic.Broadcaster" }
})
