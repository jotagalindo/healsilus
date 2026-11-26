-- Pestaña Auras: HoTs propios (lista de hechizos vigilados) y tamaño de los iconos.
-- Los debuffs tienen su propia pestaña (UI/TabDebuffs.lua).
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabAuras = { stack = nil, pool = nil }
ns.TabAuras = TabAuras

local LIST_X, LIST_TOP, ROW_HEIGHT = 300, -56, 26

TabAuras.CHECKBOXES = {
  { key = "hotsEnabled", label = L.AURAS_HOTS },
}

TabAuras.SLIDERS = {
  { key = "hotsMax", label = L.AURAS_HOTS_MAX },
  { key = "iconSize", label = L.AURAS_ICON_SIZE },
}

local function HotSpellIDs()
  return ns.Profiles.active.auras.hotSpellIDs
end

function TabAuras.HotItems()
  local items = {}
  for spellID in pairs(HotSpellIDs()) do
    items[#items + 1] = { spellID = spellID, name = ns.Spells:GetName(spellID) or ("#" .. spellID), icon = ns.Spells:GetIcon(spellID) }
  end
  table.sort(items, function(left, right)
    return left.name < right.name
  end)
  return items
end

local function PaintRow(row, item)
  row.icon:SetTexture(item.icon)
  row.text:SetText(item.name)
  row.onRemove = function()
    HotSpellIDs()[item.spellID] = nil
    ns.Config:Changed("auras")
  end
end

function TabAuras.Build(panel)
  local stack = Widgets.Stack(panel, 0, 0)
  for _, spec in ipairs(TabAuras.CHECKBOXES) do
    stack:Add(Widgets.Checkbox(panel, spec.label, Widgets.SectionGetter("auras", spec.key), Widgets.SectionSetter("auras", spec.key)), 30)
  end
  for _, spec in ipairs(TabAuras.SLIDERS) do
    local range = ns.Database.RANGES[spec.key]
    stack:Add(Widgets.Slider(panel, spec.label, range[1], range[2], 1,
      Widgets.SectionGetter("auras", spec.key), Widgets.SectionSetter("auras", spec.key)), 48)
  end
  TabAuras.stack = stack

  local title = Widgets.Label(panel, L.AURAS_HOT_LIST, "GameFontNormal")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", LIST_X, 0)
  local add = Widgets.Button(panel, L.ADD_SPELL, 140, function(self)
    if #TabAuras.HotItems() >= Widgets.MAX_LIST_ROWS then
      ns.Print(L.LIST_FULL)
      return
    end
    Widgets.OpenSpellMenu(self, function(entry)
      HotSpellIDs()[ns.Spells.PreferredSpellID(entry)] = true
      ns.Config:Changed("auras")
    end)
  end)
  add:SetPoint("TOPLEFT", panel, "TOPLEFT", LIST_X, -22)
  TabAuras.pool = Widgets.RowPool(panel, function(parent)
    return Widgets.SpellRow(parent, 380)
  end)
end

function TabAuras.Refresh()
  TabAuras.stack:Refresh()
  TabAuras.pool:Render(TabAuras.HotItems(), PaintRow, LIST_X, LIST_TOP, ROW_HEIGHT)
end

ns.Config:RegisterTab("auras", L.TAB_AURAS, TabAuras.Build, TabAuras.Refresh)
