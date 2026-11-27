-- Arranque: datos guardados al cargar el addon, todo lo demás al entrar al mundo.
-- También reacciona a cambios del libro de hechizos y de especialización.
local addonName, ns = ...

ns.Events:RegisterGameEvent("ADDON_LOADED", function(_, loadedName)
  if loadedName ~= addonName then
    return
  end
  ns.Database:Initialize()
end)

ns.Events:RegisterGameEvent("PLAYER_LOGIN", function()
  ns.Spells:Scan()
  ns.Profiles:Initialize()
  ns.UnitButton:Initialize()
  ns.Headers:Initialize()
  ns.Config:RegisterSettingsCategory()
  ns.MinimapButton:Initialize()
  ns.Events:Fire("READY")
end)

ns.Events:RegisterGameEvent("SPELLS_CHANGED", function()
  if not ns.Profiles.active then
    return
  end
  ns.Spells:Scan()
  ns.Events:Fire("SPELLBOOK_UPDATED")
end)

local function OnSpecializationChanged(_, unit)
  if unit and unit ~= "player" then
    return
  end
  if ns.Profiles.active then
    ns.Profiles:Refresh()
  end
end

ns.Events:RegisterGameEvent("PLAYER_SPECIALIZATION_CHANGED", OnSpecializationChanged)
ns.Events:RegisterGameEvent("ACTIVE_TALENT_GROUP_CHANGED", OnSpecializationChanged)
