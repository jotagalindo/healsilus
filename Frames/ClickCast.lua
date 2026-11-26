-- Click-casting: asignaciones del perfil → atributos de SecureActionButtonTemplate.
-- Solo se escriben atributos fuera de combate; los botones creados por una cabecera los copian de ella.
local _, ns = ...

local ClickCast = { current = {} }
ns.ClickCast = ClickCast

-- Si el hechizo principal no está aprendido pero el alternativo sí, se usa el alternativo.
function ClickCast.ResolveSpell(binding)
  local spellID = binding.spellID
  if binding.fallbackSpellID and not ns.Spells:IsKnown(spellID) and ns.Spells:IsKnown(binding.fallbackSpellID) then
    spellID = binding.fallbackSpellID
  end
  return (ns.Spells:CastString(spellID, binding.rank))
end

-- Lista ordenada { name, value }: prefijos en orden canónico y botones 1..5.
-- Sin asignación propia, el clic izquierdo selecciona y el derecho abre el menú de unidad.
function ClickCast.BuildAttributes(bindings, resolveSpell)
  local attributes = {}
  local function Add(name, value)
    attributes[#attributes + 1] = { name = name, value = value }
  end
  for _, prefix in ipairs(ns.BINDING_PREFIXES) do
    for _, button in ipairs(ns.MOUSE_BUTTONS) do
      local binding = bindings[prefix .. button]
      if binding then
        if binding.kind == "spell" then
          local castString = resolveSpell(binding)
          if castString then
            Add(prefix .. "type" .. button, "spell")
            Add(prefix .. "spell" .. button, castString)
          end
        elseif binding.kind == "macro" then
          Add(prefix .. "type" .. button, "macro")
          Add(prefix .. "macrotext" .. button, binding.text)
        elseif binding.kind == "target" then
          Add(prefix .. "type" .. button, "target")
        elseif binding.kind == "menu" then
          Add(prefix .. "type" .. button, "togglemenu")
        end
      elseif prefix == "" and button == "1" then
        Add("type1", "target")
      elseif prefix == "" and button == "2" then
        Add("type2", "togglemenu")
      end
    end
  end
  return attributes
end

function ClickCast.ApplyToButton(button, attributes)
  for _, name in ipairs(button.healsilusAttributeNames or {}) do
    button:SetAttribute(name, nil)
  end
  local names = {}
  for _, attribute in ipairs(attributes) do
    button:SetAttribute(attribute.name, attribute.value)
    names[#names + 1] = attribute.name
  end
  button.healsilusAttributeNames = names
end

-- La cabecera guarda la lista para su initialConfigFunction (ver Frames/Headers.lua).
function ClickCast.StoreOnHeader(header, attributes)
  local previous = header:GetAttribute("hs-attr-count") or 0
  for position = 1, previous do
    header:SetAttribute("hs-attr-name-" .. position, nil)
    header:SetAttribute("hs-attr-value-" .. position, nil)
  end
  for position, attribute in ipairs(attributes) do
    header:SetAttribute("hs-attr-name-" .. position, attribute.name)
    header:SetAttribute("hs-attr-value-" .. position, attribute.value)
  end
  header:SetAttribute("hs-attr-count", #attributes)
end

function ClickCast:Apply(profile)
  if InCombatLockdown() then
    error("ClickCast:Apply called in combat")
  end
  local attributes = ClickCast.BuildAttributes(profile.bindings, ClickCast.ResolveSpell)
  for button in pairs(ns.UnitButton.buttons) do
    ClickCast.ApplyToButton(button, attributes)
  end
  for _, header in ipairs(ns.Headers.list) do
    ClickCast.StoreOnHeader(header, attributes)
  end
  self.current = attributes
end

-- Un botón recién creado por la cabecera ya copió los atributos en el entorno seguro:
-- solo hay que recordar sus nombres para poder limpiarlos en el próximo Apply.
function ClickCast:AdoptButton(button)
  local names = {}
  for position, attribute in ipairs(self.current) do
    names[position] = attribute.name
  end
  button.healsilusAttributeNames = names
end

function ClickCast:Refresh()
  ns.CombatQueue:Run("clickcast", function()
    if ns.Profiles and ns.Profiles.active then
      ClickCast:Apply(ns.Profiles.active)
    end
  end)
end

ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "bindings" then
    ClickCast:Refresh()
  end
end)

ns.Events:Register("SPELLBOOK_UPDATED", function()
  ClickCast:Refresh()
end)
