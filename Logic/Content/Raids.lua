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
--- Returns the array of raid definitions from Constants.RAIDS
--- @return table - Array of raid objects with name, tag, raidSizeMin, raidSizeMax
function TeronAutoLFM.Logic.Content.Raids.GetRaids()
  return TeronAutoLFM.Core.Constants.RAIDS
end
