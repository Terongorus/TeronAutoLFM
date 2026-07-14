--=============================================================================
-- TeronAutoLFM: MainFrame Logic
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Logic = TeronAutoLFM.Logic or {}
TeronAutoLFM.Logic.MainFrame = {}

--=============================================================================
-- PRIVATE STATE
--=============================================================================
local currentBottomTab = 1  -- 1=Dungeons, 2=Raids, 3=Quests, 4=Messaging
local currentSideTab = nil  -- nil or 2=Presets, 4=AutoInvite, 5=Settings

local BOTTOM_TABS = {
  "Dungeons",
  "Raids",
  "Quests",
  "Messaging"
}

local SIDE_TABS = {
  [2] = "Presets",
  [4] = "AutoInvite",
  [5] = "Settings"
}

--=============================================================================
-- PUBLIC API
--=============================================================================
--- Toggles the main frame visibility (show/hide)
--- Uses WoW UI panel system for proper strata management
function TeronAutoLFM.Logic.MainFrame.Toggle()
  local frame = getglobal("TeronAutoLFM_MainFrame")
  if not frame then
    return
  end

  if frame:IsVisible() then
    TeronAutoLFM.Core.Utils.LogAction("Hide MainFrame")
    HideUIPanel(frame)
  else
    TeronAutoLFM.Core.Utils.LogAction("Show MainFrame")
    ShowUIPanel(frame)
  end
end

--=============================================================================
-- TAB MANAGEMENT
--=============================================================================
--- Selects a bottom tab and switches to its content
--- @param tabIndex number - Tab index (1-4: Dungeons, Raids, Quests, Messaging)
--- @param tabName string - Optional display name for logging
function TeronAutoLFM.Logic.MainFrame.SelectBottomTab(tabIndex, tabName)
  if tabIndex < 1 or tabIndex > 4 then
    return
  end

  -- Switching panels doesn't naturally release a focused edit box in WoW
  TeronAutoLFM.Core.Utils.ClearFocusedEditBox()

  currentBottomTab = tabIndex
  currentSideTab = nil

  local displayName = tabName or BOTTOM_TABS[tabIndex]
  TeronAutoLFM.Core.Utils.LogInfo("Show " .. displayName .. " content")

  TeronAutoLFM.Logic.MainFrame.UpdateTabVisuals()
  TeronAutoLFM.Logic.MainFrame.UpdateContent()
end

--- Selects a side tab and switches to its content
--- @param tabIndex number - Tab index (2=Presets, 4=AutoInvite, 5=Settings)
--- @param tabName string - Optional display name for logging
function TeronAutoLFM.Logic.MainFrame.SelectSideTab(tabIndex, tabName)
  if not SIDE_TABS[tabIndex] then
    return
  end

  -- Switching panels doesn't naturally release a focused edit box in WoW
  TeronAutoLFM.Core.Utils.ClearFocusedEditBox()

  currentSideTab = tabIndex

  local displayName = tabName or SIDE_TABS[tabIndex]
  TeronAutoLFM.Core.Utils.LogInfo("Show " .. displayName .. " content")

  TeronAutoLFM.Logic.MainFrame.UpdateTabVisuals()
  TeronAutoLFM.Logic.MainFrame.UpdateContent()
end

--- Determines if a bottom tab should show hover highlight
--- Bottom tabs show highlight when not selected OR when a side tab is active
--- @param tabIndex number - The bottom tab index to check
--- @return boolean - True if highlight should be shown
function TeronAutoLFM.Logic.MainFrame.ShouldShowTabHighlight(tabIndex)
  return tabIndex ~= currentBottomTab or currentSideTab
end

--- Returns the currently selected bottom tab index
--- @return number - Current bottom tab (1-4)
function TeronAutoLFM.Logic.MainFrame.GetCurrentBottomTab()
  return currentBottomTab
end

--- Returns the currently selected side tab index or nil
--- @return number|nil - Current side tab (2, 4, 5) or nil if no side tab active
function TeronAutoLFM.Logic.MainFrame.GetCurrentSideTab()
  return currentSideTab
end

--- Updates tab visual states (delegates to UI layer)
--- Refreshes tab colors and highlights based on current selection
function TeronAutoLFM.Logic.MainFrame.UpdateTabVisuals()
  -- Delegate to UI layer
  if TeronAutoLFM.UI and TeronAutoLFM.UI.MainFrame and TeronAutoLFM.UI.MainFrame.UpdateTabVisuals then
    TeronAutoLFM.UI.MainFrame.UpdateTabVisuals(currentBottomTab, currentSideTab)
  end
end

--- Shows/hides content frames based on currently active tab
--- Hides all content frames, then shows the active one
function TeronAutoLFM.Logic.MainFrame.UpdateContent()
  local activeContent
  if currentSideTab and SIDE_TABS[currentSideTab] then
    activeContent = SIDE_TABS[currentSideTab]
  else
    activeContent = BOTTOM_TABS[currentBottomTab]
  end

  for _, contentName in ipairs(BOTTOM_TABS) do
    local frame = getglobal("TeronAutoLFM_Content_" .. contentName)
    if frame then
      frame:Hide()
    end
  end

  for _, contentName in pairs(SIDE_TABS) do
    local frame = getglobal("TeronAutoLFM_Content_" .. contentName)
    if frame then
      frame:Hide()
    end
  end

  local activeFrame = getglobal("TeronAutoLFM_Content_" .. activeContent)
  if activeFrame then
    activeFrame:Show()
  else
    TeronAutoLFM.Core.Utils.LogWarning("Content frame not found: " .. activeContent)
  end
end

--=============================================================================
-- CONTENT FRAME MANAGEMENT
--=============================================================================
--- Initializes content frames and applies default panel from settings
--- Content frames are defined in XML, this just sets up the initial state
function TeronAutoLFM.Logic.MainFrame.InitializeContentFrames()
  -- All content frames are now defined directly in XML with parent="TeronAutoLFM_MainFrame_ContentContainer"
  -- No need to create them dynamically anymore

  -- Apply default panel from settings
  TeronAutoLFM.Logic.MainFrame.ApplyDefaultPanel()

  -- Rows will be created by OnShow handlers when each content frame is first shown
end

--- Applies the default panel setting from persistent storage
--- Opens the configured panel (dungeons, raids, quests, messaging, or presets)
function TeronAutoLFM.Logic.MainFrame.ApplyDefaultPanel()
  local defaultPanel = TeronAutoLFM.Core.Storage.GetDefaultPanel()
  if not defaultPanel then
    defaultPanel = "dungeons"
  end

  -- Map panel names to tab indices/types
  local panelMap = {
    dungeons = {type = "bottom", index = 1},
    raids = {type = "bottom", index = 2},
    quests = {type = "bottom", index = 3},
    messaging = {type = "bottom", index = 4},
    presets = {type = "side", index = 2}
  }

  local panel = panelMap[defaultPanel]
  if panel then
    if panel.type == "bottom" then
      TeronAutoLFM.Logic.MainFrame.SelectBottomTab(panel.index, defaultPanel)
    elseif panel.type == "side" then
      TeronAutoLFM.Logic.MainFrame.SelectSideTab(panel.index, defaultPanel)
    end
  else
    -- Fallback to dungeons
    TeronAutoLFM.Logic.MainFrame.SelectBottomTab(1, "dungeons")
  end
end

--=============================================================================
-- INITIALIZATION
--=============================================================================
TeronAutoLFM.Core.SafeRegisterInit("MainFrame", function()
  TeronAutoLFM.Core.Maestro.RegisterCommand("MainFrame.Toggle", TeronAutoLFM.Logic.MainFrame.Toggle, { id = "C01" })

  -- Subscribe to message state changes to update the preview
  TeronAutoLFM.Core.Maestro.SubscribeState("Message.ToBroadcast", function(newMessage, oldMessage)
    if TeronAutoLFM.UI.MainFrame and TeronAutoLFM.UI.MainFrame.UpdateMessagePreview then
      TeronAutoLFM.UI.MainFrame.UpdateMessagePreview(newMessage)
    end
  end)
end, { id = "I22" })
