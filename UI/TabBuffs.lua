-- Pestaña Buffs (como en HealBot): qué buffs tuyos vigilar, a quién, su versión de grupo, colorear la
-- barra de quien no los tenga y avisar antes de que se acaben. Todo se revisa fuera de combate.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabBuffs = { options = nil, pool = nil, overrideCheckbox = nil }
ns.TabBuffs = TabBuffs

local LIST_TOP, ROW_HEIGHT = -170, 26

TabBuffs.TARGET_LABELS = {
  ALL = L.TARGETS_ALL,
  TANKS = L.TARGETS_TANKS,
  HEALERS = L.TARGETS_HEALERS,
  SELF = L.TARGETS_SELF,
}

local TARGET_CYCLE = { ALL = "TANKS", TANKS = "HEALERS", HEALERS = "SELF", SELF = "ALL" }

function TabBuffs.NextTargets(targets)
  return TARGET_CYCLE[targets] or "ALL"
end

local function Watched()
  return ns.Profiles.active.buffs.watched
end

function TabBuffs.Items()
  local items = {}
  for position, entry in ipairs(Watched()) do
    local groupName = entry.groupSpellID and (ns.Spells:GetName(entry.groupSpellID) or ("#" .. entry.groupSpellID))
    items[#items + 1] = {
      position = position,
      entry = entry,
      name = ns.Spells:GetName(entry.spellID) or ("#" .. entry.spellID),
      groupName = groupName,
      icon = ns.Spells:GetIcon(entry.spellID),
    }
  end
  return items
end

local function CreateBuffRow(parent)
  local row = Widgets.SpellRow(parent, 700)
  row.targets = Widgets.Button(row, "", 110, function()
    if row.onTargets then
      row.onTargets()
    end
  end)
  row.targets:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
  row.group = Widgets.Button(row, L.BUFFS_SET_GROUP, 130, function(self)
    if row.onGroup then
      row.onGroup(self)
    end
  end)
  row.group:SetPoint("RIGHT", row.targets, "LEFT", -6, 0)
  return row
end

local function PaintRow(row, item)
  row.icon:SetTexture(item.icon)
  local suffix = item.groupName and (" · " .. string.format(L.BUFFS_GROUP_VARIANT, item.groupName)) or ""
  row.text:SetText(item.name .. suffix)
  row.targets:SetText(TabBuffs.TARGET_LABELS[item.entry.targets])
  row.onTargets = function()
    item.entry.targets = TabBuffs.NextTargets(item.entry.targets)
    ns.Config:Changed("buffs")
  end
  row.onGroup = function(owner)
    Widgets.OpenMenu(owner, function(root)
      root:CreateButton(L.NONE, function()
        item.entry.groupSpellID = nil
        ns.Config:Changed("buffs")
      end)
      for _, entry in ipairs(ns.Spells:KnownList()) do
        root:CreateButton(entry.name, function()
          item.entry.groupSpellID = ns.Spells.PreferredSpellID(entry)
          ns.Config:Changed("buffs")
        end)
      end
    end)
  end
  row.onRemove = function()
    table.remove(Watched(), item.position)
    ns.Config:Changed("buffs")
  end
end

function TabBuffs.Build(panel)
  local options = Widgets.Stack(panel, 0, 0)
  options:Add(Widgets.Checkbox(panel, L.BUFFS_ENABLED, Widgets.SectionGetter("buffs", "enabled"), Widgets.SectionSetter("buffs", "enabled")), 28)
  options:Add(Widgets.Checkbox(panel, L.BUFFS_COLOR_BAR, Widgets.SectionGetter("buffs", "colorBar"), Widgets.SectionSetter("buffs", "colorBar")), 28)
  local swatch = Widgets.ColorSwatch(panel, Widgets.SectionGetter("buffs", "barColor"), function(red, green, blue)
    Widgets.Debounce("buffs:barColor", function()
      Widgets.SectionSetter("buffs", "barColor")({ r = red, g = green, b = blue })
    end)
  end)
  local swatchLabel = Widgets.Label(panel, L.BUFFS_BAR_COLOR)
  swatchLabel:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
  options:Add(swatch, 30)
  local range = ns.Database.RANGES.refreshBelow
  options:Add(Widgets.Slider(panel, L.BUFFS_REFRESH_BELOW, range[1], range[2], 1,
    Widgets.SectionGetter("buffs", "refreshBelow"), Widgets.SectionSetter("buffs", "refreshBelow")), 48)
  TabBuffs.options = options
  local help = Widgets.Label(panel, L.BUFFS_HELP, "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", panel, "TOPLEFT", 330, -4)
  help:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  -- Misma opción que en la pestaña Clics: fuera de combate, cualquier clic pone el buff que falta.
  local override = Widgets.Checkbox(panel, L.CLICKS_BUFF_OVERRIDE, Widgets.SectionGetter("clicks", "buffOverride"),
    Widgets.SectionSetter("clicks", "buffOverride"))
  override:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -8)
  TabBuffs.overrideCheckbox = override
  local title = Widgets.Label(panel, L.BUFFS_LIST, "GameFontNormal")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -122)
  local add = Widgets.Button(panel, L.ADD_SPELL, 140, function(self)
    if #Watched() >= Widgets.MAX_LIST_ROWS then
      ns.Print(L.LIST_FULL)
      return
    end
    Widgets.OpenSpellMenu(self, function(entry)
      local list = Watched()
      list[#list + 1] = { spellID = ns.Spells.PreferredSpellID(entry), targets = "ALL" }
      ns.Config:Changed("buffs")
    end)
  end)
  add:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -142)
  TabBuffs.pool = Widgets.RowPool(panel, CreateBuffRow)
end

function TabBuffs.Refresh()
  TabBuffs.options:Refresh()
  TabBuffs.overrideCheckbox:Refresh()
  TabBuffs.pool:Render(TabBuffs.Items(), PaintRow, 0, LIST_TOP, ROW_HEIGHT)
end

ns.Config:RegisterTab("buffs", L.TAB_BUFFS, TabBuffs.Build, TabBuffs.Refresh)
