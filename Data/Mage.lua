-- Cartes et bibelots du Mage (fiche : docs/classes/mage.md ; règles communes : docs/classes/decisions.md).
-- Mêmes champs que Data/Priest.lua ; règles propres (Charges, deux Cast, Frozen, Ice Block) :
-- Core/Classes/mage.lua ; art : UI/Art/mage.lua. Chiffres de la fiche, à régler par la simulation
-- (luajit Sim/sim.lua ... class=mage, docs/classes.md).
--
-- Charges (0 à 4, gardées d'un tour à l'autre) : gagnées par « +1 Charge. » (effet res),
-- +1 dégât par charge à chaque coup des cartes Attack (Arcane Power : +2), vidées par « Surge: ».
-- Deux incantations à la fois ; Instant (état commun) fait partir la prochaine carte Cast tout de suite.
-- École (champ school) : fire, frost, arcane. Voies : Fire (enchaîner les gros sorts sous Instant),
-- Frost (Stunned et Demoralized, condition Frozen), Arcane (charges, un tour à 6 mana).
--
-- level = niveau de classe qui débloque la carte ou le bibelot (fiche, section 5 ; Core/Meta.lua).
local _, ns = ...

local Combat = ns.Combat
local C = ns.Cards

local function card(id, t)
  t.id = id
  t.class = "mage"
  C[id] = t
end

local function hasDot(t) return t ~= nil and (t.st.pain or 0) > 0 end

-- Départ -------------------------------------------------------------------

-- Fireball : 10 (fiche : 12) ; le deck de départ seul gagnait 67 % des expéditions (Priest 14 %),
-- 48 % à 10 (simulation de fumée du 12/11/2026, pick=skip).
card("fireball", {
  level = 1, name = "Fireball", cost = 1, type = "attack", school = "fire", rarity = "basic", path = "start",
  target = "enemy", cast = true, effects = { { "damage", 10 }, { "apply", "pain", 2, icon = "burn" } },
  text = "Cast.\nDeal 10.\nApply DoT 2",
  up = { effects = { { "damage", 14 }, { "apply", "pain", 3, icon = "burn" } }, text = "Cast.\nDeal 14.\nApply DoT 3" },
})

card("frostbolt", {
  level = 1, name = "Frostbolt", cost = 1, type = "attack", school = "frost", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 6 }, { "apply", "demoralized", 1 } },
  text = "Deal 6.\nApply Demoralized 1 ⌛",
  up = { effects = { { "damage", 9 }, { "apply", "demoralized", 1 } }, text = "Deal 9.\nApply Demoralized 1 ⌛" },
})

card("mana_shield", {
  level = 1, name = "Mana Shield", cost = 1, type = "skill", school = "arcane", rarity = "basic", path = "start",
  effects = { { "absorb", 5 } },
  text = "Gain 5 Absorb.",
  up = { effects = { { "absorb", 8 } }, text = "Gain 8 Absorb." },
})

card("arcane_blast", {
  level = 1, name = "Arcane Blast", cost = 1, type = "attack", school = "arcane", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 6 }, { "res", 1 } },
  text = "Deal 6.\n+1 Charge.",
  up = { effects = { { "damage", 9 }, { "res", 1 } }, text = "Deal 9.\n+1 Charge." },
})

-- Fire : les petites cartes Fire remplissent le compte du tour, l'Instant fait partir les gros Cast ----

card("fire_blast", {
  level = 1, name = "Fire Blast", cost = 1, type = "attack", school = "fire", rarity = "common", path = "fire",
  target = "enemy", cooldown = 2, effects = { { "damage", 5 }, { "apply", "instant", 1, self = true } },
  text = "Deal 5.\nGain Instant 1\nCooldown 2.",
  up = { effects = { { "damage", 8 }, { "apply", "instant", 1, self = true } }, text = "Deal 8.\nGain Instant 1\nCooldown 2." },
})

-- Execute : forme du socle (« Execute: deal X. » = total), la fiche écrivait « deal 4 more ».
card("scorch", {
  level = 1, name = "Scorch", cost = 0, type = "attack", school = "fire", rarity = "common", path = "fire",
  target = "enemy", effects = { { "damage", 3, more = { { 4, "execute" } } } },
  text = "Deal 3.\nExecute: deal 7.",
  up = { effects = { { "damage", 5, more = { { 5, "execute" } } } }, text = "Deal 5.\nExecute: deal 10." },
})

card("flamestrike", {
  level = 1, name = "Flamestrike", cost = 2, type = "attack", school = "fire", rarity = "common", path = "fire",
  cast = true, effects = { { "damage", 12, all = true }, { "apply", "pain", 3, all = true, icon = "burn" } },
  text = "Cast.\nDeal 12 to all.\nApply DoT 3 to all",
  up = { effects = { { "damage", 16, all = true }, { "apply", "pain", 4, all = true, icon = "burn" } },
    text = "Cast.\nDeal 16 to all.\nApply DoT 4 to all" },
})

card("blazing_barrier", {
  level = 1, name = "Blazing Barrier", cost = 1, type = "skill", school = "fire", rarity = "common", path = "fire",
  effects = { { "absorb", 7 } },
  text = "Gain 7 Absorb.",
  up = { effects = { { "absorb", 10 } }, text = "Gain 10 Absorb." },
})

card("pyroblast", {
  level = 1, name = "Pyroblast", cost = 2, type = "attack", school = "fire", rarity = "uncommon", path = "fire",
  target = "enemy", cast = true, effects = { { "damage", 30 } },
  text = "Cast.\nDeal 30.",
  up = { effects = { { "damage", 38 } }, text = "Cast.\nDeal 38." },
})

-- Hot Streak : quand la deuxième carte Fire du tour a fini d'être jouée (résolue, ou posée dans un
-- emplacement d'incantation), Instant 1 ; une fois par tour et par exemplaire. Elle ne profite pas à la
-- carte qui la déclenche (gagnée après la mise en emplacement). Jouée en cours de tour après deux cartes
-- Fire, elle se déclenche à la carte Fire suivante.
local function hotStreakCheck(c, power, d)
  if not d or d.school ~= "fire" or (c.turn.bySchool.fire or 0) < 2 then return end
  local key = "hotStreak" .. power.uid
  if c.player.flags[key] == c.round then return end
  c.player.flags[key] = c.round
  Combat.applyStatus(c, c.player, "instant", 1)
end

local hotStreakHooks = {
  onCardPlayed = function(c, power, inst, ctx)
    if not ctx.cast then hotStreakCheck(c, power, ctx.def) end -- une incantation résolue a compté à son jeu
  end,
  onCastStart = function(c, power, inst) hotStreakCheck(c, power, ns.Card.def(inst)) end,
}

card("hot_streak", {
  level = 1, name = "Hot Streak", cost = 1, type = "power", school = "fire", rarity = "uncommon", path = "fire",
  power = true, effects = {}, hooks = hotStreakHooks,
  text = "Power.\n2nd Fire card each turn: gain Instant 1.",
  up = { cost = 0, text = "Power.\n2nd Fire card each turn: gain Instant 1." },
})

card("living_bomb", {
  level = 2, name = "Living Bomb", cost = 1, type = "attack", school = "fire", rarity = "uncommon", path = "fire",
  effects = { { "damage", 3, all = true }, { "apply", "pain", 3, all = true, icon = "burn" } },
  text = "Deal 3 to all.\nApply DoT 3 to all",
  up = { effects = { { "damage", 4, all = true }, { "apply", "pain", 5, all = true, icon = "burn" } },
    text = "Deal 4 to all.\nApply DoT 5 to all" },
})

-- « DoT: gain Instant 1. » : lu après le coup (Ignite peut avoir posé le DoT). Effet sur mesure : un
-- état posé sous condition n'a pas sa ligne « Gain » (langage des cartes).
local function phoenix(c, ctx)
  if hasDot(ctx.target) then Combat.applyStatus(c, c.player, "instant", 1) end
end

card("phoenix_flames", {
  level = 4, name = "Phoenix Flames", cost = 1, type = "attack", school = "fire", rarity = "uncommon", path = "fire",
  target = "enemy", cooldown = 1, effects = { { "damage", 8 }, { "apply", "instant", 1, self = true, cond = "status:pain" } },
  text = "Deal 8.\nDoT: gain Instant 1\nCooldown 1.",
  up = { effects = { { "damage", 11 }, { "apply", "instant", 1, self = true, cond = "status:pain" } }, text = "Deal 11.\nDoT: gain Instant 1\nCooldown 1." },
})

-- Ignite : chaque coup d'une carte Attack Fire pose aussi un DoT sur la cible touchée.
local function igniteHooks(n)
  return {
    onAttackHit = function(c, power, t, ctx)
      if ctx.def and ctx.def.school == "fire" and t and not t.dead then Combat.applyStatus(c, t, "pain", n, "burn") end
    end,
  }
end

card("ignite", {
  level = 6, name = "Ignite", cost = 1, type = "power", school = "fire", rarity = "rare", path = "fire",
  power = true, effects = {}, hooks = igniteHooks(3),
  text = "Power.\nFire hits: apply DoT 3.",
  up = { hooks = igniteHooks(4), text = "Power.\nFire hits: apply DoT 4." },
})

card("combustion", {
  level = 7, name = "Combustion", cost = 0, type = "skill", school = "fire", rarity = "rare", path = "fire",
  exhaust = true, effects = { { "draw", 2 }, { "apply", "instant", 2, self = true } },
  text = "Draw 2.\nGain Instant 2\nExhaust.",
  up = { effects = { { "draw", 3 }, { "apply", "instant", 2, self = true } }, text = "Draw 3.\nGain Instant 2\nExhaust." },
})

-- Frost : contrôle (Stunned, Demoralized), puis la condition Frozen fait payer ce contrôle ---------------

card("ice_lance", {
  level = 1, name = "Ice Lance", cost = 0, type = "attack", school = "frost", rarity = "common", path = "frost",
  target = "enemy", effects = { { "damage", 3, more = { { 6, "frozen" } } } },
  text = "Deal 3.\nFrozen: deal 6 more.",
  up = { effects = { { "damage", 4, more = { { 8, "frozen" } } } }, text = "Deal 4.\nFrozen: deal 8 more." },
})

card("frost_nova", {
  level = 1, name = "Frost Nova", cost = 1, type = "skill", school = "frost", rarity = "common", path = "frost",
  cooldown = 4, effects = { { "absorb", 2 }, { "apply", "stunned", 1, all = true } },
  text = "Gain 2 Absorb.\nApply Stunned 1 ⌛ to all\nCooldown 4.",
  up = { cooldown = 3, effects = { { "absorb", 4 }, { "apply", "stunned", 1, all = true } },
    text = "Gain 4 Absorb.\nApply Stunned 1 ⌛ to all\nCooldown 3." },
})

card("ice_barrier", {
  level = 1, name = "Ice Barrier", cost = 1, type = "skill", school = "frost", rarity = "common", path = "frost",
  retain = true, effects = { { "absorb", 8 } },
  text = "Gain 8 Absorb.\nRetain.",
  up = { effects = { { "absorb", 11 } }, text = "Gain 11 Absorb.\nRetain." },
})

card("cone_of_cold", {
  level = 1, name = "Cone of Cold", cost = 1, type = "attack", school = "frost", rarity = "common", path = "frost",
  cooldown = 2, effects = { { "damage", 4, all = true }, { "apply", "demoralized", 1, all = true } },
  text = "Deal 4 to all.\nApply Demoralized 1 ⌛ to all\nCooldown 2.",
  up = { effects = { { "damage", 6, all = true }, { "apply", "demoralized", 1, all = true } },
    text = "Deal 6 to all.\nApply Demoralized 1 ⌛ to all\nCooldown 2." },
})

card("flurry", {
  level = 1, name = "Flurry", cost = 1, type = "attack", school = "frost", rarity = "uncommon", path = "frost",
  target = "enemy", effects = { { "damage", 3, times = 3 }, { "apply", "demoralized", 1 } },
  text = "Deal 3 three times.\nApply Demoralized 1 ⌛",
  up = { effects = { { "damage", 4, times = 3 }, { "apply", "demoralized", 1 } },
    text = "Deal 4 three times.\nApply Demoralized 1 ⌛" },
})

card("blizzard", {
  level = 1, name = "Blizzard", cost = 2, type = "attack", school = "frost", rarity = "uncommon", path = "frost",
  cast = true, effects = { { "damage", 12, all = true }, { "apply", "demoralized", 2, all = true } },
  text = "Cast.\nDeal 12 to all.\nApply Demoralized 2 ⌛ to all",
  up = { effects = { { "damage", 15, all = true }, { "apply", "demoralized", 2, all = true } },
    text = "Cast.\nDeal 15 to all.\nApply Demoralized 2 ⌛ to all" },
})

card("glacial_spike", {
  level = 2, name = "Glacial Spike", cost = 2, type = "attack", school = "frost", rarity = "uncommon", path = "frost",
  target = "enemy", cast = true, effects = { { "damage", 26 }, { "apply", "demoralized", 2 } },
  text = "Cast.\nDeal 26.\nApply Demoralized 2 ⌛",
  up = { effects = { { "damage", 32 }, { "apply", "demoralized", 2 } }, text = "Cast.\nDeal 32.\nApply Demoralized 2 ⌛" },
})

-- Ice Block : Last Breath ; PV remis à 0 puis soignés de 10 (Combat.heal), état Ice Block (aucun dégât
-- de coup ennemi jusqu'au début du prochain tour : Core/Classes/mage.lua, crochet enemyDamage).
local iceBlockHooks = {
  preventDeath = function(c, power)
    if not Combat.lastBreath(c, "ice_block") then return false end
    c.player.hp = 0
    Combat.heal(c, c.player, 10)
    Combat.applyStatus(c, c.player, "ice_block", 1)
    return true
  end,
}

card("ice_block", {
  level = 4, name = "Ice Block", cost = 1, type = "power", school = "frost", rarity = "rare", path = "frost",
  power = true, effects = {}, hooks = iceBlockHooks,
  text = "Power.\nLast Breath: heal 10, no damage until next turn.",
  up = { cost = 0, text = "Power.\nLast Breath: heal 10, no damage until next turn." },
})

-- Deep Freeze : « Frozen: apply Stunned 1. » lu après le coup, sur la cible (effet sur mesure : un état
-- posé sous condition n'a pas sa ligne « Apply … ⌛ », langage des cartes).
local function deepFreeze(c, ctx)
  local t = ctx.target
  if t and not t.dead and Combat.isFrozen(t) then Combat.applyStatus(c, t, "stunned", 1) end
end

card("deep_freeze", {
  level = 6, name = "Deep Freeze", cost = 1, type = "attack", school = "frost", rarity = "uncommon", path = "frost",
  target = "enemy", cooldown = 2, effects = { { "damage", 8 }, { "fn", deepFreeze } },
  text = "Deal 8.\nFrozen: apply Stunned 1.\nCooldown 2.",
  up = { effects = { { "damage", 11 }, { "fn", deepFreeze } }, text = "Deal 11.\nFrozen: apply Stunned 1.\nCooldown 2." },
})

-- Shatter : chaque coup d'une carte Attack sur une cible Frozen fait N de plus (testé coup par coup).
local function shatterHooks(n)
  return {
    damage = function(c, power, v, dst, cardDef)
      if cardDef and cardDef.type == "attack" and dst and dst.side == "enemy" and Combat.isFrozen(dst) then return v + n end
      return v
    end,
  }
end

card("shatter", {
  level = 7, name = "Shatter", cost = 1, type = "power", school = "frost", rarity = "rare", path = "frost",
  power = true, effects = {}, hooks = shatterHooks(4),
  text = "Power.\nFrozen: Attack hits deal 4 more.",
  up = { hooks = shatterHooks(5), text = "Power.\nFrozen: Attack hits deal 5 more." },
})

-- Arcane : monter les charges, les vider d'un Surge ; Evocation prépare un tour à 6 mana ----------------

card("arcane_missiles", {
  level = 1, name = "Arcane Missiles", cost = 1, type = "attack", school = "arcane", rarity = "common", path = "arcane",
  target = "enemy", effects = { { "damage", 3, times = 3 }, { "res", 1 } },
  text = "Deal 3 three times.\n+1 Charge.",
  up = { effects = { { "damage", 4, times = 3 }, { "res", 1 } }, text = "Deal 4 three times.\n+1 Charge." },
})

card("arcane_explosion", {
  level = 1, name = "Arcane Explosion", cost = 1, type = "attack", school = "arcane", rarity = "common", path = "arcane",
  effects = { { "damage", 4, all = true }, { "res", 1 } },
  text = "Deal 4 to all.\n+1 Charge.",
  up = { effects = { { "damage", 6, all = true }, { "res", 1 } }, text = "Deal 6 to all.\n+1 Charge." },
})

card("prismatic_barrier", {
  level = 1, name = "Prismatic Barrier", cost = 1, type = "skill", school = "arcane", rarity = "common", path = "arcane",
  effects = { { "absorb", 5 }, { "res", 1 } },
  text = "Gain 5 Absorb.\n+1 Charge.",
  up = { effects = { { "absorb", 8 }, { "res", 1 } }, text = "Gain 8 Absorb.\n+1 Charge." },
})

-- Surge : les charges sont lues puis remises à 0 avant le coup, le bonus passif ne s'y ajoute donc pas.
card("arcane_barrage", {
  level = 1, name = "Arcane Barrage", cost = 1, type = "attack", school = "arcane", rarity = "common", path = "arcane",
  minRes = 1, effects = { { "surge" }, { "damage", 0, all = true, per = { 6, "surge" } } },
  text = "Surge: deal 6 per Charge to all.",
  up = { effects = { { "surge" }, { "damage", 0, all = true, per = { 8, "surge" } } },
    text = "Surge: deal 8 per Charge to all." },
})

card("counterspell", {
  level = 1, name = "Counterspell", cost = 0, type = "skill", school = "arcane", rarity = "uncommon", path = "arcane",
  target = "enemy", cooldown = 2, effects = { { "interrupt" }, { "res", 1 } },
  text = "Interrupt the target's cast.\n+1 Charge.\nCooldown 2.",
  up = { cooldown = 1, text = "Interrupt the target's cast.\n+1 Charge.\nCooldown 1." },
})

-- Evocation : Cast à 0 mana ; le mana est remis au maximum AVANT la résolution des incantations (socle),
-- d'où un tour à 6 mana ; sous Instant, +3 tout de suite.
local function manaGain(n)
  return function(c)
    c.player.mana = c.player.mana + n
    Combat.log(c, { t = "mana", n = n, total = c.player.mana })
  end
end

card("evocation", {
  level = 1, name = "Evocation", cost = 0, type = "skill", school = "arcane", rarity = "uncommon", path = "arcane",
  cast = true, exhaust = true, evoMana = 3, effects = { { "fn", manaGain(3) } },
  text = "Cast.\n+3 mana.\nExhaust.",
  up = { evoMana = 4, effects = { { "fn", manaGain(4) } }, text = "Cast.\n+4 mana.\nExhaust." },
})

card("polymorph", {
  level = 2, name = "Polymorph", cost = 2, type = "skill", school = "arcane", rarity = "common", path = "arcane",
  target = "enemy", exhaust = true, effects = { { "res", 1 }, { "apply", "stunned", 2 } },
  text = "+1 Charge.\nApply Stunned 2 ⌛\nExhaust.",
  up = { cost = 1, text = "+1 Charge.\nApply Stunned 2 ⌛\nExhaust." },
})

card("presence_of_mind", {
  level = 4, name = "Presence of Mind", cost = 0, type = "skill", school = "arcane", rarity = "uncommon", path = "arcane",
  cooldown = 4, effects = { { "draw", 1 }, { "res", 1 }, { "apply", "instant", 1, self = true } },
  text = "Draw 1.\n+1 Charge.\nGain Instant 1\nCooldown 4.",
  up = { cooldown = 3, text = "Draw 1.\n+1 Charge.\nGain Instant 1\nCooldown 3." },
})

-- Arcane Power : chaque charge ajoute 2 au lieu de 1 (lu par la règle de classe ; deux exemplaires
-- ne font pas 3).
card("arcane_power", {
  level = 6, name = "Arcane Power", cost = 1, type = "power", school = "arcane", rarity = "rare", path = "arcane",
  power = true, effects = {}, chargeBonus = 2,
  text = "Power.\n+2 damage per Charge, not +1.",
  up = { cost = 0, text = "Power.\n+2 damage per Charge, not +1." },
})

local function surgeMana(c, ctx)
  local n = ctx.surge or 0
  if n > 0 then manaGain(n)(c) end
end

card("arcane_surge", {
  level = 7, name = "Arcane Surge", cost = 1, type = "skill", school = "arcane", rarity = "rare", path = "arcane",
  minRes = 1, effects = { { "surge" }, { "fn", surgeMana }, { "draw", 0, per = { 1, "surge" } } },
  text = "Surge: +1 mana, draw 1 per Charge.",
  up = { cost = 0, text = "Surge: +1 mana, draw 1 per Charge." },
})

-- Cartes épiques (une par zone, docs/zones/cartes-de-zone.md, « Mage ») -----------------------------
-- Règles en jeu dès le début du combat (c.epic) : ni piochées, ni jouées ; cost = 0, jamais payé ni affiché. Les crochets (deckHooks)
-- sont posés par Core/Classes/mage.lua ; les nombres sont ici (epicN, epicM, epicPeriod, epicEvery, lus par
-- les crochets, base et améliorée).
local function epic(id, t)
  t.type, t.power, t.epic, t.rarity, t.effects, t.cost = "power", true, true, "epic", {}, 0
  card(id, t)
end

-- Westfall : chaque Cast frappe une seconde fois (premier coup, base + epicN, au moins 0) un ennemi au hasard.
-- Fiche : 0 / + 4 ; à 0, + 14 points à Westfall ; à - 3, + 12,9 (réglage du 14/11/2026 : - 6 / - 2).
epic("mirror_image", {
  name = "Mirror Image", zone = "westfall", path = "fire", school = "arcane", epicN = -6,
  text = "Epic.\nCast cards: deal their damage - 6 again to a random enemy.",
  up = { epicN = -2, text = "Epic.\nCast cards: deal their damage - 2 again to a random enemy." },
})

-- Duskwood : chaque coup ennemi sur le Mage, même absorbé, pose DoT epicN à son auteur.
epic("molten_armor", {
  name = "Molten Armor", zone = "duskwood", path = "fire", school = "fire", epicN = 1,
  text = "Epic.\nWhen hit: apply DoT 1 to the attacker",
  up = { epicN = 3, text = "Epic.\nWhen hit: apply DoT 3 to the attacker" },
})

-- Wetlands : un tour sur epicPeriod (3 : les tours 3, 6, 9…), au début du tour, l'élémentaire inflige epicN à la
-- dernière cible, puis Demoralized epicM (chaque tour : 100 % de victoires, réglage du 13/11/2026).
epic("water_elemental", {
  name = "Water Elemental", zone = "wetlands", path = "frost", school = "frost", epicN = 5, epicM = 1, epicPeriod = 3,
  text = "Epic.\nEvery 3rd turn: deal 5 to the last target and apply Demoralized 1.",
  up = { epicN = 8, text = "Epic.\nEvery 3rd turn: deal 8 to the last target and apply Demoralized 1." },
})

-- Stranglethorn : une carte Cast visant un ennemi Frozen part tout de suite (sans Instant) ; améliorée,
-- ses coups font epicN de plus.
epic("fingers_of_frost", {
  name = "Fingers of Frost", zone = "stranglethorn", path = "frost", school = "frost", epicN = 0,
  text = "Epic.\nCast cards aimed at a Frozen enemy resolve at once.",
  up = { epicN = 4, text = "Epic.\nCast cards aimed at a Frozen enemy resolve at once and deal 4 more." },
})

-- Swamp of Sorrows : le mana non dépensé (epicN au plus) s'ajoute au tour suivant.
epic("arcane_meditation", {
  name = "Arcane Meditation", zone = "swamp", path = "arcane", school = "arcane", epicN = 4,
  text = "Epic.\nUnspent mana carries over to the next turn, up to 4.",
  up = { epicN = 6, text = "Epic.\nUnspent mana carries over to the next turn, up to 6." },
})

-- Burning Steppes : un ennemi qui meurt avec du DoT le donne (+ epicN) à chaque autre ennemi.
epic("conflagration", {
  name = "Conflagration", zone = "steppes", path = "fire", school = "fire", epicN = 8,
  text = "Epic.\nAn enemy dying with DoT gives that DoT + 8 to each other enemy.",
  up = { epicN = 11, text = "Epic.\nAn enemy dying with DoT gives that DoT + 11 to each other enemy." },
})

-- Blackrock Mountain : un tour sur epicPeriod (3 : les tours 3, 6, 9…), la 3e carte jouée (améliorée : chaque 3e) se
-- résout deux fois si c'est une Attack.
epic("rule_of_threes", {
  name = "Rule of Threes", zone = "blackrock", path = "arcane", school = "arcane", epicEvery = false, epicPeriod = 3,
  text = "Epic.\nEvery 3rd turn: an Attack played 3rd resolves twice.",
  up = { epicEvery = true, text = "Epic.\nEvery 3rd turn: Attacks played 3rd, 6th, 9th resolve twice." },
})

-- Bibelots du Mage (class = "mage" : tirés seulement pour lui) -------------------------------------
-- level = niveau de classe qui les débloque (dans la réserve de la classe ; la Ligue ne compte pas).

local R = ns.Relics
local function relic(id, t)
  t.id = id
  t.class = "mage"
  t.hooks = t.hooks or {}
  R[id] = t
end

-- Bibelot de départ : la première carte Cast jouée dans le combat coûte 0 (même si elle coûtait déjà 0).
relic("apprentice_wand", {
  level = 1, name = "Apprentice's Wand", rarity = "common", noPool = true,
  text = "The first Cast card each combat costs 0.",
  hooks = {
    cost = function(c, src, v, d)
      if d.cast and not c.relicState.apprentice_wand then return 0 end
      return v
    end,
    onCardCommitted = function(c, src, inst, d)
      if d.cast then c.relicState.apprentice_wand = true end
    end,
  },
})

relic("tome_arcane_brilliance", {
  level = 1, name = "Tome of Arcane Brilliance", rarity = "common",
  text = "Start each combat with 1 Charge.",
  hooks = {
    onCombatStart = function(c) Combat.gainRes(c, 1, "relic") end,
  },
})

-- Robe : aussi pour une carte Cast résolue sous Instant (résolue au jeu, sans onCastResolved).
relic("robe_archmage", {
  level = 3, name = "Robe of the Archmage", rarity = "uncommon",
  text = "When a Cast card resolves, gain 4 Absorb.",
  hooks = {
    onCastResolved = function(c) Combat.gainBlock(c, c.player, 4) end,
    onCardPlayed = function(c, src, inst, ctx)
      if ctx.def.cast and not ctx.cast then Combat.gainBlock(c, c.player, 4) end
    end,
  },
})

relic("glacial_cloak", {
  level = 5, name = "Glacial Cloak", rarity = "uncommon",
  text = "At the start of each combat, apply Demoralized 1 to all enemies.",
  hooks = {
    onCombatStart = function(c)
      local list = Combat.aliveEnemies(c)
      for i = 1, #list do Combat.applyStatus(c, list[i], "demoralized", 1) end
    end,
  },
})

relic("fire_ruby", {
  level = 7, name = "Fire Ruby", rarity = "rare",
  text = "Start each combat with Instant 1.",
  hooks = {
    onCombatStart = function(c) Combat.applyStatus(c, c.player, "instant", 1) end,
  },
})

relic("mind_quickening_gem", {
  level = 7, name = "Mind Quickening Gem", rarity = "rare",
  text = "At the start of each turn with 4 Charges, +1 mana.",
  hooks = {
    onTurnStart = function(c)
      if (c.player.res or 0) >= 4 then manaGain(1)(c) end
    end,
  },
})

-- Bots : notes des épiques et construction autour de chacune ----------------------------------------
-- Note : ≈ 5 + écart / 2 (points de victoire gagnés à Westfall avec l'épique, Sim/sim.lua epic=). Conseils
-- (rating, upgrade, remove) : remplacent ceux de la classe tant que l'épique est dans le deck.
local MAGE_EPIC_NOTE = {
  mirror_image = 10, molten_armor = 9.5, water_elemental = 9.5, fingers_of_frost = 10.5,
  arcane_meditation = 7.5, conflagration = 7.5, rule_of_threes = 9.5, -- mesures du 14/11/2026, clé 0, zones=7
}
local MAGE_EPIC_ADVICE = {
  -- chaque Cast frappe deux fois : les gros Cast, de quoi tenir l'incantation, les Cast immédiats
  mirror_image = {
    rating = { pyroblast = 11.5, glacial_spike = 11, flamestrike = 10.5, blizzard = 10, presence_of_mind = 14,
      combustion = 12, fire_blast = 9, hot_streak = 7, counterspell = 9, ice_barrier = 10.5, ice_lance = 7.5,
      arcane_missiles = 7.5, arcane_barrage = 7 },
    upgrade = { fireball = 4, mirror_image = 3.5, frostbolt = 1.5, arcane_blast = 0.5 },
    remove = { arcane_blast = 0.5, frostbolt = 1.4 },
  },
  -- se laisser frapper : Absorb partout, puis le feu qui suit ; pas de contrôle (un ennemi étourdi ne frappe pas)
  molten_armor = {
    rating = { blazing_barrier = 11, ice_barrier = 11.5, prismatic_barrier = 10.5, phoenix_flames = 10, ignite = 9,
      living_bomb = 10, frost_nova = 6, polymorph = 6, deep_freeze = 7, cone_of_cold = 7.5, ice_block = 11 },
    upgrade = { mana_shield = 3.5, molten_armor = 4.5, fireball = 2 },
    remove = { arcane_blast = 0.5, frostbolt = 1.4 },
  },
  -- le gel vient tout seul : les cartes qui frappent sous Frozen, sans contrôle en double
  water_elemental = {
    rating = { ice_lance = 13, shatter = 10, deep_freeze = 10.5, flurry = 12.5, arcane_missiles = 11, glacial_spike = 9.5,
      frost_nova = 7, cone_of_cold = 7.5, polymorph = 7.5, scorch = 9.5 },
    upgrade = { water_elemental = 4, frostbolt = 3, fireball = 2.5 },
    remove = { mana_shield = 0.8, arcane_blast = 1.2 },
  },
  -- le contrôle lance les sorts : Frozen d'abord, puis les gros Cast tout de suite
  fingers_of_frost = {
    rating = { cone_of_cold = 11, frost_nova = 11, flurry = 12, polymorph = 11, deep_freeze = 10, pyroblast = 11.5,
      glacial_spike = 11.5, hot_streak = 2, fire_blast = 5, combustion = 7, blizzard = 7 },
    upgrade = { frostbolt = 3.5, fireball = 3, fingers_of_frost = 3.5 },
    remove = { arcane_blast = 0.5, mana_shield = 1.2 },
  },
  -- économiser son mana : cartes à 0 pour les tours d'attente, puis deux gros sorts dans le même tour
  arcane_meditation = {
    rating = { pyroblast = 11.5, glacial_spike = 11, flamestrike = 10.5, blizzard = 10, polymorph = 11, evocation = 10.5,
      arcane_surge = 9, ice_barrier = 11, ice_lance = 11.5, scorch = 10.5, counterspell = 9.5, presence_of_mind = 14,
      fire_blast = 5.5 },
    upgrade = { arcane_meditation = 3.5, fireball = 3 },
    remove = { arcane_blast = 0.5, frostbolt = 1.4 },
  },
  -- le feu passe d'un mort à l'autre : poser le DoT partout, achever le porteur
  conflagration = {
    rating = { living_bomb = 10.5, flamestrike = 9.5, ignite = 8, phoenix_flames = 8.5, scorch = 10, cone_of_cold = 10,
      arcane_explosion = 6.5 },
    upgrade = { fireball = 3.5, conflagration = 3.5 },
    remove = { arcane_blast = 0.5, mana_shield = 1.3 },
  },
  -- la troisième carte compte double : cartes à 0 pour y arriver, puis le contrôle et les gros coups
  rule_of_threes = {
    rating = { ice_lance = 12, scorch = 11, counterspell = 9.5, presence_of_mind = 14, evocation = 9.5,
      arcane_barrage = 11, pyroblast = 9.5, glacial_spike = 9.5, flurry = 12, hot_streak = 2, ignite = 3,
      arcane_power = 4 },
    upgrade = { rule_of_threes = 4.5, frostbolt = 2 },
    remove = { mana_shield = 0.8, frostbolt = 1.4 },
  },
}

-- Classe ------------------------------------------------------------------------

-- PV : 52 (fiche : 60, « à régler par simulation », decisions.md) ; à 60, 94 % de victoires au bot
-- heuristic, clé 0 ; à 52 avec Fireball 10, 84 à 85 % (300 expéditions, deux graines). Les Arcane
-- Charges valent à elles seules ~16 points (à 60 PV, sans leur bonus : 78 %) : à revoir à l'équilibrage fin.
ns.Classes.mage = {
  id = "mage", name = "Mage", order = 4, hp = 42,
  resource = { id = "arcane", cap = 4, keep = true },
  deck = {
    "frostbolt", "frostbolt", "frostbolt",
    "mana_shield", "mana_shield", "mana_shield", "mana_shield",
    "fireball", "fireball", "arcane_blast",
  },
  startRelic = "apprentice_wand",
  paths = { { id = "fire", name = "Fire" }, { id = "frost", name = "Frost" }, { id = "arcane", name = "Arcane" } },
  survival = "control",
  bot = {
    resValue = 10,
    rating = {
      presence_of_mind = 13, flurry = 11.5, combustion = 10, ice_lance = 10, polymorph = 10, frost_nova = 10,
      cone_of_cold = 9.5, ice_barrier = 9.5, arcane_missiles = 9.5, ice_block = 9.5, arcane_barrage = 9,
      scorch = 9, evocation = 8.5, deep_freeze = 8.5, blazing_barrier = 8, living_bomb = 8,
      counterspell = 7.5, phoenix_flames = 7.5, glacial_spike = 7.5, prismatic_barrier = 7.5,
      pyroblast = 7.5, flamestrike = 7.5, fire_blast = 7, blizzard = 7, arcane_surge = 6.5, shatter = 5.5,
      arcane_explosion = 5, arcane_power = 4.5, ignite = 4, hot_streak = 3,
    },
    upgrade = { fireball = 2.5, frostbolt = 2.5, mana_shield = 2, arcane_blast = 2 },
    remove = { mana_shield = 1, frostbolt = 1.5 },
    -- Épiques : note (bot.epic) et conseils de construction tant qu'elle est dans le deck (bot.byEpic, lus par
    -- Sim/expedition.lua : notes des cartes, améliorations, retraits ; tirés de la fiche, « Deck piloté »).
    byEpic = MAGE_EPIC_ADVICE,
    epic = function(exp, id)
      local n = MAGE_EPIC_NOTE[id]
      if not n then return nil end
      -- l'épique du deck vaut plus : le deck est déjà construit autour (changer de build coûte)
      local i = ns.Expedition.epicIndex(exp)
      if i and exp.deck[i].id == id then n = n + 3 end
      return n
    end,
  },
}
