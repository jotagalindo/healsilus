-- Pestaña Perfiles: perfil de clase o propio, perfiles por especialización, copiar, restablecer, exportar e importar.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabProfiles = { stack = nil, specText = nil }
ns.TabProfiles = TabProfiles

local function Character()
  return ns.Profiles:Character()
end

local function OpenCopyMenu(owner)
  Widgets.OpenMenu(owner, function(root)
    local sources = ns.Profiles:ListCopySources()
    if #sources == 0 then
      root:CreateTitle(L.PROFILES_NO_SOURCES)
      return
    end
    for _, source in ipairs(sources) do
      local label = ns.Config.DescribeCopySource(source)
      root:CreateButton(label, function()
        Widgets.Confirm(string.format(L.PROFILES_COPY_CONFIRM, label), function()
          ns.Profiles:CopyFrom(source.profile)
        end)
      end)
    end
  end)
end

local function ImportText(text)
  local profile, failure = ns.Serializer.Import(text)
  if not profile then
    ns.Print(string.format(L.IMPORT_FAILED, failure))
    return
  end
  Widgets.Confirm(L.IMPORT_CONFIRM, function()
    ns.Profiles:ReplaceActive(profile)
  end)
end

function TabProfiles.Build(panel)
  local stack = Widgets.Stack(panel, 0, 0)
  stack:Add(Widgets.Checkbox(panel, L.PROFILES_USE_CLASS, function()
    return Character().useClassProfile
  end, function(enabled)
    ns.Profiles:SetUseClassProfile(enabled)
  end), 30)
  stack:Add(Widgets.Checkbox(panel, L.PROFILES_USE_SPEC, function()
    return Character().useSpecProfiles
  end, function(enabled)
    ns.Profiles:SetUseSpecProfiles(enabled)
  end), 30)
  TabProfiles.stack = stack

  local specText = Widgets.Label(panel, "", "GameFontHighlight")
  specText:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -70)
  TabProfiles.specText = specText

  local copy = Widgets.Button(panel, L.PROFILES_COPY, 150, function(self)
    OpenCopyMenu(self)
  end)
  copy:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -100)
  local reset = Widgets.Button(panel, L.PROFILES_RESET, 150, function()
    Widgets.Confirm(L.PROFILES_RESET_CONFIRM, function()
      ns.Profiles:ResetActive()
    end)
  end)
  reset:SetPoint("LEFT", copy, "RIGHT", 10, 0)
  local export = Widgets.Button(panel, L.PROFILES_EXPORT, 150, function()
    Widgets.TextDialog(L.PROFILES_EXPORT_TITLE, ns.Serializer.Export(ns.Profiles.active), nil, nil)
  end)
  export:SetPoint("TOPLEFT", copy, "BOTTOMLEFT", 0, -10)
  local import = Widgets.Button(panel, L.PROFILES_IMPORT, 150, function()
    Widgets.TextDialog(L.PROFILES_IMPORT_TITLE, "", L.PROFILES_IMPORT, ImportText)
  end)
  import:SetPoint("LEFT", export, "RIGHT", 10, 0)

  local note = Widgets.Label(panel, L.PROFILES_COMBAT_NOTE, "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", export, "BOTTOMLEFT", 0, -16)
end

function TabProfiles.Refresh()
  TabProfiles.stack:Refresh()
  TabProfiles.specText:SetText(string.format(L.PROFILES_SPEC_GROUP, ns.Profiles.ActiveSpecGroup()))
end

ns.Config:RegisterTab("profiles", L.TAB_PROFILES, TabProfiles.Build, TabProfiles.Refresh)
