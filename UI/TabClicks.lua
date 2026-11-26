-- Pestaña Clics: tabla de 8 combinaciones de modificadores × 5 botones del ratón.
-- Cada casilla acepta arrastrar un hechizo, elegirlo de un menú (con rango), escribir una macro, objetivo o menú.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabClicks = { cells = {} }
ns.TabClicks = TabClicks

local MACRO_ICON = "Interface\\Icons\\INV_Misc_Note_01"
local CELL_WIDTH, CELL_HEIGHT, LABEL_WIDTH, GRID_TOP = 118, 24, 100, -48
local MAX_MACRO_LENGTH = 1023

local MODIFIER_LABELS = {
  [""] = L.MODIFIER_NONE,
  ["alt-"] = "Alt",
  ["ctrl-"] = "Ctrl",
  ["shift-"] = "Shift",
  ["alt-ctrl-"] = "Alt+Ctrl",
  ["alt-shift-"] = "Alt+Shift",
  ["ctrl-shift-"] = "Ctrl+Shift",
  ["alt-ctrl-shift-"] = "Alt+Ctrl+Shift",
}

local BUTTON_LABELS = {
  ["1"] = L.BUTTON_LEFT,
  ["2"] = L.BUTTON_RIGHT,
  ["3"] = L.BUTTON_MIDDLE,
  ["4"] = L.BUTTON_4,
  ["5"] = L.BUTTON_5,
}

local function Bindings()
  return ns.Profiles.active.bindings
end

local function SetBinding(key, binding)
  Bindings()[key] = binding
  ns.Config:Changed("bindings")
end

-- Devuelve texto, icono y si la casilla es válida (false = se pinta en rojo).
function TabClicks.Describe(binding, key)
  if not binding then
    if key == "1" then
      return L.BINDING_DEFAULT_TARGET, nil, true
    end
    if key == "2" then
      return L.BINDING_DEFAULT_MENU, nil, true
    end
    return L.BINDING_EMPTY, nil, true
  end
  if binding.kind == "spell" then
    local name = ns.Spells:GetName(binding.spellID) or ("#" .. binding.spellID)
    local text = binding.rank and string.format(L.BINDING_RANK, name, binding.rank) or name
    local known = ns.Spells:IsKnown(binding.spellID)
      or (binding.fallbackSpellID ~= nil and ns.Spells:IsKnown(binding.fallbackSpellID))
    local valid = known and ns.ClickCast.ResolveSpell(binding) ~= nil
    return text, ns.Spells:GetIcon(binding.spellID), valid
  elseif binding.kind == "macro" then
    return L.BINDING_MACRO, MACRO_ICON, true
  elseif binding.kind == "target" then
    return L.BINDING_TARGET, nil, true
  end
  return L.BINDING_MENU, nil, true
end

function TabClicks:ReceiveDrag(cell)
  local cursorType, _, _, spellID = GetCursorInfo()
  if cursorType ~= "spell" or not spellID then
    return
  end
  ClearCursor()
  SetBinding(cell.key, { kind = "spell", spellID = spellID })
end

local function EditMacro(cell)
  local current = Bindings()[cell.key]
  local initial = (current and current.kind == "macro") and current.text or "/cast [@mouseover] "
  Widgets.TextDialog(L.MACRO_TITLE, initial, L.ACCEPT, function(text)
    text = strtrim(text)
    if text == "" then
      SetBinding(cell.key, nil)
    elseif #text > MAX_MACRO_LENGTH then
      ns.Print(L.MACRO_TOO_LONG)
    else
      SetBinding(cell.key, { kind = "macro", text = text })
    end
  end)
end

function TabClicks:OpenMenu(cell)
  Widgets.OpenMenu(cell, function(root)
    root:CreateTitle(cell.title)
    local spellMenu = root:CreateButton(L.MENU_SPELL)
    if spellMenu.SetScrollMode then
      spellMenu:SetScrollMode(400)
    end
    for _, entry in ipairs(ns.Spells:KnownList()) do
      local preferred = ns.Spells.PreferredSpellID(entry)
      local spellItem = spellMenu:CreateButton(entry.name, function()
        SetBinding(cell.key, { kind = "spell", spellID = preferred })
      end)
      if entry.maxRank > 1 then
        spellItem:CreateButton(L.MENU_MAX_RANK, function()
          SetBinding(cell.key, { kind = "spell", spellID = preferred })
        end)
        for rank = entry.maxRank, 1, -1 do
          local rankInfo = entry.ranks[rank]
          if rankInfo then
            spellItem:CreateButton(rankInfo.subName, function()
              SetBinding(cell.key, { kind = "spell", spellID = rankInfo.spellID, rank = rank })
            end)
          end
        end
      end
    end
    root:CreateButton(L.MENU_MACRO, function()
      EditMacro(cell)
    end)
    root:CreateButton(L.BINDING_TARGET, function()
      SetBinding(cell.key, { kind = "target" })
    end)
    root:CreateButton(L.BINDING_MENU, function()
      SetBinding(cell.key, { kind = "menu" })
    end)
    root:CreateButton(L.MENU_CLEAR, function()
      SetBinding(cell.key, nil)
    end)
  end)
end

local CELL_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

local function CreateCell(panel, key, title)
  local cell = CreateFrame("Button", nil, panel, "BackdropTemplate")
  cell:SetSize(CELL_WIDTH - 4, CELL_HEIGHT - 2)
  cell:SetBackdrop(CELL_BACKDROP)
  cell.icon = cell:CreateTexture(nil, "ARTWORK")
  cell.icon:SetSize(18, 18)
  cell.icon:SetPoint("LEFT", cell, "LEFT", 3, 0)
  cell.text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cell.text:SetPoint("LEFT", cell.icon, "RIGHT", 4, 0)
  cell.text:SetPoint("RIGHT", cell, "RIGHT", -3, 0)
  cell.text:SetJustifyH("LEFT")
  cell.text:SetWordWrap(false)
  cell.key, cell.title = key, title
  cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  cell:SetScript("OnClick", function(self, mouseButton)
    if GetCursorInfo() then
      TabClicks:ReceiveDrag(self)
    elseif mouseButton == "RightButton" then
      SetBinding(self.key, nil)
    else
      TabClicks:OpenMenu(self)
    end
  end)
  cell:SetScript("OnReceiveDrag", function(self)
    TabClicks:ReceiveDrag(self)
  end)
  return cell
end

function TabClicks.Build(panel)
  local help = Widgets.Label(panel, L.CLICKS_HELP, "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  help:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  for column, button in ipairs(ns.MOUSE_BUTTONS) do
    local header = Widgets.Label(panel, BUTTON_LABELS[button], "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", LABEL_WIDTH + (column - 1) * CELL_WIDTH, GRID_TOP + 16)
  end
  for row, prefix in ipairs(ns.BINDING_PREFIXES) do
    local rowTop = GRID_TOP - (row - 1) * CELL_HEIGHT
    local rowLabel = Widgets.Label(panel, MODIFIER_LABELS[prefix], "GameFontNormalSmall")
    rowLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, rowTop - 5)
    for column, button in ipairs(ns.MOUSE_BUTTONS) do
      local key = prefix .. button
      local cell = CreateCell(panel, key, MODIFIER_LABELS[prefix] .. " + " .. BUTTON_LABELS[button])
      cell:SetPoint("TOPLEFT", panel, "TOPLEFT", LABEL_WIDTH + (column - 1) * CELL_WIDTH, rowTop)
      TabClicks.cells[key] = cell
    end
  end
end

function TabClicks.Refresh()
  for key, cell in pairs(TabClicks.cells) do
    local text, icon, valid = TabClicks.Describe(Bindings()[key], key)
    cell.text:SetText(text)
    cell.icon:SetTexture(icon)
    cell.icon:SetShown(icon ~= nil)
    if valid then
      cell:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
      cell:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    else
      cell:SetBackdropColor(0.35, 0.05, 0.05, 0.8)
      cell:SetBackdropBorderColor(0.9, 0.2, 0.2, 1)
    end
  end
end

ns.Config:RegisterTab("clicks", L.TAB_CLICKS, TabClicks.Build, TabClicks.Refresh)

ns.Events:Register("SPELLBOOK_UPDATED", function()
  ns.Config:Refresh()
end)
