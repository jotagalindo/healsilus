-- Perfil de serie del druida. IDs de vanilla (rango 1): el atributo usa el nombre, así que se lanza
-- el rango más alto aprendido. /hs diag avisa si algún ID no existe en el cliente de Forever.
local _, ns = ...

ns.ClassDefaults = ns.ClassDefaults or {}

ns.DRUID_SPELLS = {
  HEALING_TOUCH = 5185,
  REJUVENATION = 774,
  REGROWTH = 8936,
  REMOVE_CURSE = 2782,
  ABOLISH_POISON = 2893,
  CURE_POISON = 8946,
  REBIRTH = 20484,
  MARK_OF_THE_WILD = 1126,
  GIFT_OF_THE_WILD = 21849,
  THORNS = 467,
}

local SPELLS = ns.DRUID_SPELLS

function ns.ClassDefaults.DRUID()
  local profile = ns.Database.DefaultProfile()
  profile.bindings = {
    ["1"] = { kind = "spell", spellID = SPELLS.HEALING_TOUCH },
    ["2"] = { kind = "spell", spellID = SPELLS.REJUVENATION },
    ["shift-1"] = { kind = "spell", spellID = SPELLS.REGROWTH },
    ["shift-2"] = { kind = "spell", spellID = SPELLS.REMOVE_CURSE },
    ["ctrl-1"] = { kind = "spell", spellID = SPELLS.ABOLISH_POISON, fallbackSpellID = SPELLS.CURE_POISON },
    ["ctrl-2"] = { kind = "spell", spellID = SPELLS.REBIRTH },
    ["3"] = { kind = "target" },
  }
  profile.auras.hotSpellIDs = { [SPELLS.REJUVENATION] = true, [SPELLS.REGROWTH] = true }
  profile.buffs.watched = {
    { spellID = SPELLS.MARK_OF_THE_WILD, groupSpellID = SPELLS.GIFT_OF_THE_WILD, targets = "ALL" },
    { spellID = SPELLS.THORNS, targets = "TANKS" },
  }
  return profile
end
