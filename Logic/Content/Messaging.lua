--=============================================================================
-- TeronAutoLFM: Messaging Logic
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Logic = TeronAutoLFM.Logic or {}
TeronAutoLFM.Logic.Content = TeronAutoLFM.Logic.Content or {}
TeronAutoLFM.Logic.Content.Messaging = {}

--=============================================================================
-- PRIVATE STATE
--=============================================================================
local Original_ContainerFrameItemButton_OnClick = nil
local Original_ChatFrame_OnHyperlinkShow = nil

--=============================================================================
-- LINK INTEGRATION
--=============================================================================
--- Retrieves the custom message editbox from the Messaging UI
--- @return frame|nil - The editbox frame, or nil if UI not initialized
local function getCustomMessageEditBox()
  if TeronAutoLFM.UI and TeronAutoLFM.UI.Content and TeronAutoLFM.UI.Content.Messaging then
    return TeronAutoLFM.UI.Content.Messaging.GetCustomMessageEditBox and
           TeronAutoLFM.UI.Content.Messaging.GetCustomMessageEditBox()
  end
  return nil
end

--- Checks if TeronAutoLFM main window is visible and ready to receive links
--- @return boolean - True if main window is visible
local function isTeronAutoLFMReady()
  return TeronAutoLFM_MainFrame and TeronAutoLFM_MainFrame:IsVisible()
end

--- Inserts an item/quest link into the custom message editbox
--- @param link string - The hyperlink text to insert (e.g., item link, quest link)
--- @return boolean - True if link was successfully inserted, false otherwise
local function insertLinkIntoEditBox(link)
  if not link then
    if TeronAutoLFM.Core and TeronAutoLFM.Core.Utils then
      TeronAutoLFM.Core.Utils.LogWarning("InsertLink: no link provided")
    end
    return false
  end

  local editBox = getCustomMessageEditBox()
  if not editBox then
    if TeronAutoLFM.Core and TeronAutoLFM.Core.Utils then
      TeronAutoLFM.Core.Utils.LogWarning("InsertLink: editbox not found")
    end
    return false
  end

  local currentText = editBox:GetText() or ""
  local newText = (currentText == "" and link) or (currentText .. " " .. link)

  editBox:SetText(newText)
  editBox:SetFocus()
  editBox:HighlightText(0, 0)

  if TeronAutoLFM.Core and TeronAutoLFM.Core.Utils then
    TeronAutoLFM.Core.Utils.LogAction("Link inserted: " .. link)
  end

  return true
end

--- Hooks bag item button clicks to enable Shift+Click link insertion
--- Overrides ContainerFrameItemButton_OnClick to intercept Shift+Click
local function hookBagClicks()
  if not ContainerFrameItemButton_OnClick then return end
  Original_ContainerFrameItemButton_OnClick = ContainerFrameItemButton_OnClick

  ContainerFrameItemButton_OnClick = function(button, ignoreModifiers)
    local success, err = pcall(function()
      if IsShiftKeyDown() and isTeronAutoLFMReady() then
        local bag = this:GetParent():GetID()
        local slot = this:GetID()
        local itemLink = GetContainerItemLink(bag, slot)

        if itemLink and insertLinkIntoEditBox(itemLink) then
          return
        end
      end

      if Original_ContainerFrameItemButton_OnClick then
        Original_ContainerFrameItemButton_OnClick(button, ignoreModifiers)
      end
    end)

    if not success and Original_ContainerFrameItemButton_OnClick then
      Original_ContainerFrameItemButton_OnClick(button, ignoreModifiers)
    end
  end
end

--- Hooks chat hyperlink clicks to enable Shift+Click link insertion and right-click player menus
--- Overrides ChatFrame_OnHyperlinkShow to intercept Shift+Click and right-click events
local isHandlingHyperlink = false

--- Hooks ChatFrame_OnHyperlinkShow for Shift+Click link insertion and right-click menus
local function hookChatLinks()
  if not ChatFrame_OnHyperlinkShow then return end
  Original_ChatFrame_OnHyperlinkShow = ChatFrame_OnHyperlinkShow

  ChatFrame_OnHyperlinkShow = function(link, text, button)
    -- Reentrancy guard: prevent stack overflow when other addons hook the same chain
    if isHandlingHyperlink then
      if Original_ChatFrame_OnHyperlinkShow then
        return Original_ChatFrame_OnHyperlinkShow(link, text, button)
      end
      return
    end
    isHandlingHyperlink = true

    -- Try our custom handling first
    local handled = false

    -- Right click on player → show menu
    local _, _, linkType, playerName = string.find(link or "", "^(%a+):([^:]+)")
    if linkType == "player" and playerName and button == "RightButton" then
      playerName = gsub(playerName, "-.*", "")
      if HideDropDownMenu then HideDropDownMenu(1) end
      if ChatFrameDropDown_Show then
        ChatFrameDropDown_Show(nil, playerName)
        isHandlingHyperlink = false
        return -- Handled, don't call original
      end
    end

    -- Shift+Click on item/quest → insert into editbox
    if IsShiftKeyDown() and isTeronAutoLFMReady() then
      -- Check if it's an item or quest link
      local isItemOrQuest = link and (string.find(link, "^item:") or string.find(link, "^quest:"))

      if isItemOrQuest and text then
        if TeronAutoLFM.Core and TeronAutoLFM.Core.Utils then
          TeronAutoLFM.Core.Utils.LogInfo("Attempting to insert link: " .. tostring(text))
        end

        if insertLinkIntoEditBox(text) then
          isHandlingHyperlink = false
          -- Successfully inserted, don't call original
          return
        end
      end
    end

    -- Call original for all other cases
    if Original_ChatFrame_OnHyperlinkShow then
      Original_ChatFrame_OnHyperlinkShow(link, text, button)
    end
    isHandlingHyperlink = false
  end
end

--=============================================================================
-- CHANNEL MANAGEMENT
--=============================================================================
--- Joins a chat channel if the player is not already in it
--- @param channelName string - The name of the channel to join (e.g., "LookingForGroup")
--- @return boolean - True if in channel (already or newly joined), false if invalid channel name
function TeronAutoLFM.Logic.Content.Messaging.JoinChannel(channelName)
  if not channelName or channelName == "" then
    if TeronAutoLFM.Core and TeronAutoLFM.Core.Utils then
      TeronAutoLFM.Core.Utils.LogWarning("JoinChannel: no channel name provided")
    end
    return false
  end

  -- General channel is auto-joined per zone, no need to join manually
  if channelName == "General" then
    -- Check if we're in the General channel (slot 1)
    -- GetChannelName returns: id, name (id first!)
    local generalID, generalName = GetChannelName(1)
    if generalID and generalID > 0 then
      if TeronAutoLFM.Core and TeronAutoLFM.Core.Utils then
        TeronAutoLFM.Core.Utils.LogInfo("General channel available: " .. (generalName or "1"))
      end
      return true
    else
      if TeronAutoLFM.Core and TeronAutoLFM.Core.Utils then
        TeronAutoLFM.Core.Utils.LogWarning("General channel not available in this zone")
      end
      return false
    end
  end

  -- Matched case-insensitively - different servers use different casing for the same
  -- global channel (e.g. Turtle WoW's "World" vs Kronos's "world")
  local channelID = TeronAutoLFM.Core.Utils.FindChannelID(channelName)

  if channelID > 0 then
    if TeronAutoLFM.Core and TeronAutoLFM.Core.Utils then
      TeronAutoLFM.Core.Utils.LogInfo("Already in channel: " .. channelName .. " (ID: " .. channelID .. ")")
    end
    return true
  end

  -- Join the channel and show it in the selected chat frame
  local chatFrame = SELECTED_CHAT_FRAME or ChatFrame1
  local frameId = chatFrame:GetID()
  JoinChannelByName(channelName, nil, frameId)

  -- Verify the join succeeded by checking if we're now in the channel
  local verifyChannelID = TeronAutoLFM.Core.Utils.FindChannelID(channelName)
  if verifyChannelID <= 0 then
    if TeronAutoLFM.Core and TeronAutoLFM.Core.Utils then
      TeronAutoLFM.Core.Utils.LogWarning("Failed to join channel: " .. channelName)
    end
    return false
  end

  if TeronAutoLFM.Core and TeronAutoLFM.Core.Utils then
    TeronAutoLFM.Core.Utils.LogAction("Joined channel: " .. channelName .. " (ID: " .. verifyChannelID .. ")")
    TeronAutoLFM.Core.Utils.Print("Joined channel: " .. channelName)
  end

  return true
end

--=============================================================================
-- CHANNEL SELECTION MANAGEMENT
--=============================================================================
--- Toggles a channel in the selection and joins it if selected
--- @param channelName string - The name of the channel to toggle
function TeronAutoLFM.Logic.Content.Messaging.ToggleChannel(channelName)
  if not channelName or channelName == "" then
    if TeronAutoLFM.Core and TeronAutoLFM.Core.Utils then
      TeronAutoLFM.Core.Utils.LogWarning("ToggleChannel: no channel name provided")
    end
    return
  end

  -- Get current channels from Maestro State
  local channelsList = TeronAutoLFM.Core.Maestro.GetState("Channels.ActiveChannels") or {}
  
  -- Check if channel is already selected
  local isSelected = false
  for i = 1, table.getn(channelsList) do
    if channelsList[i] == channelName then
      isSelected = true
      break
    end
  end

  local newChannelsList
  if isSelected then
    -- Remove channel from list
    newChannelsList = TeronAutoLFM.Core.Utils.RemoveFromArray(channelsList, channelName)
    if TeronAutoLFM.Core and TeronAutoLFM.Core.Utils then
      TeronAutoLFM.Core.Utils.LogAction("Channel deselected: " .. channelName)
    end
  else
    -- Add channel to list
    newChannelsList = {}
    for i = 1, table.getn(channelsList) do
      table.insert(newChannelsList, channelsList[i])
    end
    table.insert(newChannelsList, channelName)
    -- Join the channel
    TeronAutoLFM.Logic.Content.Messaging.JoinChannel(channelName)
  end

  -- Update state
  TeronAutoLFM.Core.Maestro.SetState("Channels.ActiveChannels", newChannelsList)

  -- Save to persistent storage
  if TeronAutoLFM.Core and TeronAutoLFM.Core.Storage then
    TeronAutoLFM.Core.Storage.SetSelectedChannels(newChannelsList)
  end

  -- Dispatch event
  TeronAutoLFM.Core.Maestro.Dispatch("Channels.Changed")
end

--=============================================================================
-- PUBLIC API
--=============================================================================
--- Initializes link integration for item and quest links
--- Hooks bag item clicks and chat hyperlinks to enable Shift+Click link insertion
--- into the custom message editbox in the Messaging UI
function TeronAutoLFM.Logic.Content.Messaging.InitLinkIntegration()
  local success, err = pcall(function()
    hookBagClicks()
    hookChatLinks()
  end)
  if not success and TeronAutoLFM.Core and TeronAutoLFM.Core.Utils then
    TeronAutoLFM.Core.Utils.PrintError("Failed to initialize link integration: " .. tostring(err))
  end
end

--=============================================================================
-- MAESTRO DECLARATIONS
--=============================================================================
--- Command: Toggle channel selection
TeronAutoLFM.Core.Maestro.RegisterCommand("Channels.ToggleChannel", function(channelName)
  TeronAutoLFM.Logic.Content.Messaging.ToggleChannel(channelName)
end, { id = "C16" })

--- Event: Channels selection changed
TeronAutoLFM.Core.Maestro.RegisterEvent("Channels.Changed", { id = "E04" })

--- State: Active channels list
TeronAutoLFM.Core.SafeRegisterState("Channels.ActiveChannels", {}, { id = "S18" })

--- Loads selected channels from persistent storage and restores selection state
local function loadSavedChannels()
  if not TeronAutoLFM.Core or not TeronAutoLFM.Core.Storage then return end

  local savedChannels = TeronAutoLFM.Core.Storage.GetSelectedChannels()
  if not savedChannels or type(savedChannels) ~= "table" then return end

  -- Join all saved channels
  for i = 1, table.getn(savedChannels) do
    local channelName = savedChannels[i]
    if channelName and channelName ~= "" then
      -- Join the channel
      TeronAutoLFM.Logic.Content.Messaging.JoinChannel(channelName)
    end
  end

  -- Update Maestro state with saved channels
  TeronAutoLFM.Core.Maestro.SetState("Channels.ActiveChannels", savedChannels)
end

TeronAutoLFM.Core.SafeRegisterInit("Logic.Content.Messaging", function()
  TeronAutoLFM.Logic.Content.Messaging.InitLinkIntegration()
  loadSavedChannels()
end, { id = "I10", dependencies = { "Core.Storage" } })
