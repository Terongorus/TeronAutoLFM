--=============================================================================
-- TeronAutoLFM: Raids Logic
--=============================================================================
TeronAutoLFM = TeronAutoLFM or {}
TeronAutoLFM.Logic = TeronAutoLFM.Logic or {}
TeronAutoLFM.Logic.Content = TeronAutoLFM.Logic.Content or {}
TeronAutoLFM.Logic.Content.Raids = {}

--=============================================================================
-- PUBLIC API
--=============================================================================
--- Returns raids filtered by the "show custom instances" setting, wrapped with
--- their original Constants.RAIDS index (required since Selection.ToggleRaid
--- looks up raids by that original index, not by position in this filtered list)
--- @return table - Array of {index, raid} where raid has name, tag, raidSizeMin, raidSizeMax
function TeronAutoLFM.Logic.Content.Raids.GetRaids()
  local raids = TeronAutoLFM.Core.Constants.RAIDS
  local vanillaNames = TeronAutoLFM.Core.Constants.VANILLA_INSTANCE_NAMES
  local showCustom = TeronAutoLFM.Core.Storage and TeronAutoLFM.Core.Storage.GetShowCustomInstances and TeronAutoLFM.Core.Storage.GetShowCustomInstances()

  local filtered = {}
  for i = 1, table.getn(raids) do
    local raid = raids[i]
    local isCustom = not (vanillaNames and vanillaNames[raid.name])
    if showCustom or not isCustom then
      table.insert(filtered, { index = i, raid = raid })
    end
  end

  return filtered
end
