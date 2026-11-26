-- Comandos: /hs (configuración), /hs diag, /hs debug, /hs lock, /hs preview N, /hs minimap.
local _, ns = ...
local L = ns.L

local MAX_PREVIEW = 40

local function HandleCommand(message)
  local command, argument = string.match(strtrim(message or ""), "^(%S*)%s*(.-)$")
  command = string.lower(command or "")
  if command == "" or command == "config" then
    ns.Config:Toggle()
  elseif command == "diag" then
    ns.Diagnostics:Run()
  elseif command == "debug" then
    HealsilusDB.debug = not HealsilusDB.debug
    ns.Print(HealsilusDB.debug and L.DEBUG_ON or L.DEBUG_OFF)
  elseif command == "lock" then
    local frames = ns.Profiles.active.frames
    frames.locked = not frames.locked
    ns.Events:Fire("SETTINGS_CHANGED", "frames")
    ns.Print(frames.locked and L.LOCKED or L.UNLOCKED)
  elseif command == "preview" then
    local count = tonumber(argument)
    if count and count >= 1 then
      ns.Preview:Show(math.min(MAX_PREVIEW, math.floor(count)))
    else
      ns.Preview:Hide()
    end
  elseif command == "minimap" then
    ns.MinimapButton:SetHidden(not HealsilusDB.minimap.hide)
  else
    ns.Print(L.HELP)
  end
end
ns.HandleCommand = HandleCommand

SLASH_HEALSILUS1 = "/hs"
SLASH_HEALSILUS2 = "/healsilus"
SlashCmdList.HEALSILUS = HandleCommand
