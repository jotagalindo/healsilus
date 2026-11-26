-- Pestaña Estilos: qué estilo usar en cada situación (solo, grupo, banda 10/20/40) y tus estilos,
-- compartidos por todos tus personajes: crear desde uno de serie, duplicar, renombrar, borrar, exportar e importar.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabStyles = { rules = nil, pool = nil, inUse = nil }
ns.TabStyles = TabStyles

local LIST_X, LIST_TOP, ROW_HEIGHT = 300, -78, 26

TabStyles.CONTEXT_LABELS = {
  solo = L.CONTEXT_SOLO,
  party = L.CONTEXT_PARTY,
  raid10 = L.CONTEXT_RAID10,
  raid20 = L.CONTEXT_RAID20,
  raid40 = L.CONTEXT_RAID40,
}

local ERRORS = {
  ["invalid name"] = L.STYLE_ERROR_INVALID,
  ["name taken"] = L.STYLE_ERROR_TAKEN,
  ["last style"] = L.STYLE_ERROR_LAST,
  ["unknown style"] = L.STYLE_ERROR_UNKNOWN,
}

function TabStyles.ErrorText(reason)
  return ERRORS[reason] or tostring(reason)
end

local function Report(result, failure)
  if not result then
    ns.Print(TabStyles.ErrorText(failure))
  end
  return result
end

function TabStyles.Rows()
  local rows = {}
  for _, name in ipairs(ns.Styles:Names()) do
    rows[#rows + 1] = { name = name, active = name == ns.Styles.activeName }
  end
  return rows
end

-- Importa un estilo compartido con un nombre libre ("Estilo importado", "Estilo importado 2"...).
function TabStyles.ImportText(text)
  local style, failure = ns.Serializer.ImportStyle(text)
  if not style then
    ns.Print(string.format(L.IMPORT_FAILED, failure))
    return nil
  end
  local name = Report(ns.Styles:Create(ns.Styles:UniqueName(L.STYLES_IMPORTED_NAME), style))
  if name then
    ns.Print(string.format(L.STYLES_IMPORTED, name))
  end
  return name
end

local function AskName(initial, onName)
  Widgets.TextDialog(L.STYLES_NAME_TITLE, initial, L.ACCEPT, function(text)
    onName(strtrim(text))
  end)
end

local function StyleOptions()
  local options = {}
  for _, name in ipairs(ns.Styles:Names()) do
    options[#options + 1] = { value = name, label = name }
  end
  return options
end

local function CreateStyleRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(470, 24)
  row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.text:SetWidth(180)
  row.text:SetJustifyH("LEFT")
  row.text:SetWordWrap(false)
  row.delete = Widgets.Button(row, L.STYLES_DELETE, 90, function()
    row.onDelete()
  end)
  row.delete:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  row.rename = Widgets.Button(row, L.STYLES_RENAME, 90, function()
    row.onRename()
  end)
  row.rename:SetPoint("RIGHT", row.delete, "LEFT", -4, 0)
  row.duplicate = Widgets.Button(row, L.STYLES_DUPLICATE, 90, function()
    row.onDuplicate()
  end)
  row.duplicate:SetPoint("RIGHT", row.rename, "LEFT", -4, 0)
  return row
end

local function PaintRow(row, item)
  row.text:SetText(item.active and (item.name .. L.STYLES_ACTIVE_MARK) or item.name)
  row.onDuplicate = function()
    AskName(ns.Styles:UniqueName(item.name), function(name)
      Report(ns.Styles:Create(name, ns.Database.db.styles[item.name]))
    end)
  end
  row.onRename = function()
    AskName(item.name, function(name)
      Report(ns.Styles:Rename(item.name, name))
    end)
  end
  row.onDelete = function()
    Widgets.Confirm(string.format(L.STYLES_DELETE_CONFIRM, item.name), function()
      Report(ns.Styles:Delete(item.name))
    end)
  end
end

local function OpenPresetMenu(owner)
  Widgets.OpenMenu(owner, function(root)
    for _, preset in ipairs(ns.StyleData.PRESETS) do
      root:CreateButton(preset.name, function()
        AskName(ns.Styles:UniqueName(preset.name), function(name)
          Report(ns.Styles:Create(name, preset.build()))
        end)
      end)
    end
  end)
end

function TabStyles.Build(panel)
  TabStyles.inUse = Widgets.Label(panel, "", "GameFontHighlight")
  TabStyles.inUse:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)

  local rulesTitle = Widgets.Label(panel, L.STYLES_RULES, "GameFontNormal")
  rulesTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -26)
  local rules = Widgets.Stack(panel, 0, -46)
  for _, context in ipairs(ns.StyleData.CONTEXTS) do
    rules:Add(Widgets.Dropdown(panel, TabStyles.CONTEXT_LABELS[context], 240, StyleOptions, function()
      return ns.Profiles.active.styleRules[context]
    end, function(name)
      ns.Styles:SetRule(context, name)
      ns.Config:Refresh()
    end), 50)
  end
  TabStyles.rules = rules

  local listTitle = Widgets.Label(panel, L.STYLES_LIST, "GameFontNormal")
  listTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", LIST_X, -26)
  local new = Widgets.Button(panel, L.STYLES_NEW, 200, function(self)
    OpenPresetMenu(self)
  end)
  new:SetPoint("TOPLEFT", panel, "TOPLEFT", LIST_X, -46)
  TabStyles.pool = Widgets.RowPool(panel, CreateStyleRow)

  local export = Widgets.Button(panel, L.STYLES_EXPORT, 200, function()
    Widgets.TextDialog(L.STYLES_EXPORT_TITLE, ns.Serializer.ExportStyle(ns.Styles.active), nil, nil)
  end)
  export:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", LIST_X, 6)
  local import = Widgets.Button(panel, L.STYLES_IMPORT, 200, function()
    Widgets.TextDialog(L.STYLES_IMPORT_TITLE, "", L.STYLES_IMPORT, TabStyles.ImportText)
  end)
  import:SetPoint("LEFT", export, "RIGHT", 10, 0)
end

function TabStyles.Refresh()
  TabStyles.inUse:SetText(string.format(L.STYLES_IN_USE, tostring(ns.Styles.activeName),
    TabStyles.CONTEXT_LABELS[ns.Styles.context] or ""))
  TabStyles.rules:Refresh()
  TabStyles.pool:Render(TabStyles.Rows(), PaintRow, LIST_X, LIST_TOP, ROW_HEIGHT)
end

ns.Config:RegisterTab("styles", L.TAB_STYLES, TabStyles.Build, TabStyles.Refresh)

local function RefreshWindow()
  ns.Config:Refresh()
end
ns.Events:Register("STYLE_CHANGED", RefreshWindow)
ns.Events:Register("STYLES_LIST_CHANGED", RefreshWindow)
