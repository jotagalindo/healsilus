-- Hechizos: nombres localizados por ID y rangos aprendidos leídos del libro de hechizos.
-- El atributo "spell" usa el nombre (rango más alto) o "Nombre(subtexto del rango)" para un rango fijo.
local _, ns = ...

local Spells = { byName = {}, scanned = false }
ns.Spells = Spells

function Spells.ParseRank(subName)
  if type(subName) ~= "string" then
    return nil
  end
  local digits = string.match(subName, "(%d+)")
  return digits and tonumber(digits) or nil
end

local function SpellInfo(spellID)
  if not C_Spell or not C_Spell.GetSpellInfo then
    return nil
  end
  return C_Spell.GetSpellInfo(spellID)
end

function Spells:GetName(spellID)
  local info = SpellInfo(spellID)
  return info and info.name or nil
end

function Spells:GetIcon(spellID)
  local info = SpellInfo(spellID)
  return info and info.iconID or nil
end

function Spells:AddSpellbookEntry(name, spellID, subName, iconID)
  local entry = self.byName[name]
  if not entry then
    entry = { name = name, ranks = {}, maxRank = 0, spellIDs = {}, icon = iconID }
    self.byName[name] = entry
  end
  entry.spellIDs[spellID] = true
  local rank = Spells.ParseRank(subName)
  if rank then
    entry.ranks[rank] = { spellID = spellID, subName = subName }
    if rank > entry.maxRank then
      entry.maxRank = rank
    end
  end
end

function Spells:Scan()
  wipe(self.byName)
  if not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines or not C_SpellBook.GetSpellBookItemInfo then
    ns.RecordError("Spells:Scan", "C_SpellBook API missing")
    return
  end
  local bank = Enum.SpellBookSpellBank.Player
  local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
  for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
    if lineInfo and not lineInfo.shouldHide then
      local first = lineInfo.itemIndexOffset + 1
      local last = lineInfo.itemIndexOffset + lineInfo.numSpellBookItems
      for slot = first, last do
        local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
        if item and item.spellID and item.name and not item.isPassive
          and (spellType == nil or item.itemType == spellType) then
          self:AddSpellbookEntry(item.name, item.spellID, item.subName, item.iconID)
        end
      end
    end
  end
  self.scanned = true
end

-- Conocido = algún rango con ese nombre está en el libro.
function Spells:IsKnown(spellID)
  local name = self:GetName(spellID)
  return name ~= nil and self.byName[name] ~= nil
end

function Spells:CastString(spellID, rank)
  local name = self:GetName(spellID)
  if not name then
    return nil, "unknown spell"
  end
  if rank == nil then
    return name
  end
  local entry = self.byName[name]
  local rankInfo = entry and entry.ranks[rank]
  if not rankInfo then
    return nil, "rank not learned"
  end
  return name .. "(" .. rankInfo.subName .. ")"
end

-- En vanilla cada rango tiene su ID; los filtros de auras necesitan todos.
function Spells:ExpandRanks(spellIDSet)
  local expanded = {}
  for spellID in pairs(spellIDSet) do
    expanded[spellID] = true
    local name = self:GetName(spellID)
    local entry = name and self.byName[name]
    if entry then
      for rankSpellID in pairs(entry.spellIDs) do
        expanded[rankSpellID] = true
      end
    end
  end
  return expanded
end

function Spells:KnownList()
  local list = {}
  for _, entry in pairs(self.byName) do
    list[#list + 1] = entry
  end
  table.sort(list, function(left, right)
    return left.name < right.name
  end)
  return list
end

-- El ID del rango más alto (o cualquiera si no hay rangos) para guardar una asignación.
function Spells.PreferredSpellID(entry)
  local best = entry.ranks[entry.maxRank]
  if best then
    return best.spellID
  end
  for spellID in pairs(entry.spellIDs) do
    return spellID
  end
  return nil
end
