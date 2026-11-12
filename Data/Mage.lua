-- Cartes et bibelots du Mage (fiche : docs/classes/mage.md ; règles communes : docs/classes/decisions.md).
-- Mêmes champs que Data/Priest.lua ; règles propres (Arcane Charges, deux Cast, Frozen, Ice Block) :
-- Core/Classes/mage.lua ; art : UI/Art/mage.lua. Chiffres de la fiche, à régler par la simulation
-- (luajit Sim/sim.lua ... class=mage, docs/classes.md).
--
-- Arcane Charges (0 à 4, gardées d'un tour à l'autre) : gagnées par « +1 Arcane Charge. » (effet res),
-- +1 dégât par charge à chaque coup des cartes Attack (Arcane Power : +2), vidées par « Surge: ».
-- Deux incantations à la fois ; Instant (état commun) fait partir la prochaine carte Cast tout de suite.
-- École (champ school) : fire, frost, arcane. Voies : Fire (enchaîner les gros sorts sous Instant),
-- Frost (Stunned et Demoralized, condition Frozen), Arcane (charges, un tour à 6 mana).
--
-- level = niveau de classe qui débloque la carte ou le bibelot (fiche, section 5), posé mais pas encore
-- appliqué (progression par classe à venir) ; rep = palier de réputation lu aujourd'hui par le socle
-- (20 / 5 / 5, dans l'ordre des niveaux : niveau 1 et deux cartes du niveau 2 en rep 0).
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
  text = "Deal 6.\n+1 Arcane Charge.",
  up = { effects = { { "damage", 9 }, { "res", 1 } }, text = "Deal 9.\n+1 Arcane Charge." },
})

-- Fire : les petites cartes Fire remplissent le compte du tour, l'Instant fait partir les gros Cast ----

card("fire_blast", {
  level = 1, rep = 0, name = "Fire Blast", cost = 1, type = "attack", school = "fire", rarity = "common", path = "fire",
  target = "enemy", cooldown = 2, effects = { { "damage", 5 }, { "apply", "instant", 1, self = true } },
  text = "Deal 5.\nGain Instant 1\nCooldown 2.",
  up = { effects = { { "damage", 8 }, { "apply", "instant", 1, self = true } }, text = "Deal 8.\nGain Instant 1\nCooldown 2." },
})

-- Execute : forme du socle (« Execute: deal X. » = total), la fiche écrivait « deal 4 more ».
card("scorch", {
  level = 1, rep = 0, name = "Scorch", cost = 0, type = "attack", school = "fire", rarity = "common", path = "fire",
  target = "enemy", effects = { { "damage", 3, more = { { 4, "execute" } } } },
  text = "Deal 3.\nExecute: deal 7.",
  up = { effects = { { "damage", 5, more = { { 5, "execute" } } } }, text = "Deal 5.\nExecute: deal 10." },
})

card("flamestrike", {
  level = 1, rep = 0, name = "Flamestrike", cost = 2, type = "attack", school = "fire", rarity = "common", path = "fire",
  cast = true, effects = { { "damage", 12, all = true }, { "apply", "pain", 3, all = true, icon = "burn" } },
  text = "Cast.\nDeal 12 to all.\nApply DoT 3 to all",
  up = { effects = { { "damage", 16, all = true }, { "apply", "pain", 4, all = true, icon = "burn" } },
    text = "Cast.\nDeal 16 to all.\nApply DoT 4 to all" },
})

card("blazing_barrier", {
  level = 1, rep = 0, name = "Blazing Barrier", cost = 1, type = "skill", school = "fire", rarity = "common", path = "fire",
  effects = { { "absorb", 7 } },
  text = "Gain 7 Absorb.",
  up = { effects = { { "absorb", 10 } }, text = "Gain 10 Absorb." },
})

card("pyroblast", {
  level = 1, rep = 0, name = "Pyroblast", cost = 2, type = "attack", school = "fire", rarity = "uncommon", path = "fire",
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
  level = 1, rep = 0, name = "Hot Streak", cost = 1, type = "power", school = "fire", rarity = "uncommon", path = "fire",
  power = true, effects = {}, hooks = hotStreakHooks,
  text = "Power.\n2nd Fire card each turn: gain Instant 1.",
  up = { cost = 0, text = "Power.\n2nd Fire card each turn: gain Instant 1." },
})

card("living_bomb", {
  level = 2, rep = 0, name = "Living Bomb", cost = 1, type = "attack", school = "fire", rarity = "uncommon", path = "fire",
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
  level = 4, rep = 1, name = "Phoenix Flames", cost = 1, type = "attack", school = "fire", rarity = "uncommon", path = "fire",
  target = "enemy", cooldown = 1, effects = { { "damage", 7 }, { "fn", phoenix } },
  text = "Deal 7.\nDoT: gain Instant 1.\nCooldown 1.",
  up = { effects = { { "damage", 10 }, { "fn", phoenix } }, text = "Deal 10.\nDoT: gain Instant 1.\nCooldown 1." },
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
  level = 6, rep = 2, name = "Ignite", cost = 1, type = "power", school = "fire", rarity = "rare", path = "fire",
  power = true, effects = {}, hooks = igniteHooks(2),
  text = "Power.\nFire hits: apply DoT 2.",
  up = { hooks = igniteHooks(3), text = "Power.\nFire hits: apply DoT 3." },
})

card("combustion", {
  level = 7, rep = 2, name = "Combustion", cost = 1, type = "skill", school = "fire", rarity = "rare", path = "fire",
  exhaust = true, effects = { { "draw", 2 }, { "apply", "instant", 2, self = true } },
  text = "Draw 2.\nGain Instant 2\nExhaust.",
  up = { cost = 0, text = "Draw 2.\nGain Instant 2\nExhaust." },
})

-- Frost : contrôle (Stunned, Demoralized), puis la condition Frozen fait payer ce contrôle ---------------

card("ice_lance", {
  level = 1, rep = 0, name = "Ice Lance", cost = 0, type = "attack", school = "frost", rarity = "common", path = "frost",
  target = "enemy", effects = { { "damage", 4, more = { { 8, "frozen" } } } },
  text = "Deal 4.\nFrozen: deal 8 more.",
  up = { effects = { { "damage", 5, more = { { 10, "frozen" } } } }, text = "Deal 5.\nFrozen: deal 10 more." },
})

card("frost_nova", {
  level = 1, rep = 0, name = "Frost Nova", cost = 1, type = "skill", school = "frost", rarity = "common", path = "frost",
  cooldown = 4, effects = { { "absorb", 4 }, { "apply", "stunned", 1, all = true } },
  text = "Gain 4 Absorb.\nApply Stunned 1 ⌛ to all\nCooldown 4.",
  up = { cooldown = 3, effects = { { "absorb", 6 }, { "apply", "stunned", 1, all = true } },
    text = "Gain 6 Absorb.\nApply Stunned 1 ⌛ to all\nCooldown 3." },
})

card("ice_barrier", {
  level = 1, rep = 0, name = "Ice Barrier", cost = 1, type = "skill", school = "frost", rarity = "common", path = "frost",
  retain = true, effects = { { "absorb", 8 } },
  text = "Gain 8 Absorb.\nRetain.",
  up = { effects = { { "absorb", 11 } }, text = "Gain 11 Absorb.\nRetain." },
})

card("cone_of_cold", {
  level = 1, rep = 0, name = "Cone of Cold", cost = 1, type = "attack", school = "frost", rarity = "common", path = "frost",
  cooldown = 2, effects = { { "damage", 4, all = true }, { "apply", "demoralized", 1, all = true } },
  text = "Deal 4 to all.\nApply Demoralized 1 ⌛ to all\nCooldown 2.",
  up = { effects = { { "damage", 6, all = true }, { "apply", "demoralized", 1, all = true } },
    text = "Deal 6 to all.\nApply Demoralized 1 ⌛ to all\nCooldown 2." },
})

card("flurry", {
  level = 1, rep = 0, name = "Flurry", cost = 1, type = "attack", school = "frost", rarity = "uncommon", path = "frost",
  target = "enemy", effects = { { "damage", 3, times = 3 }, { "apply", "demoralized", 1 } },
  text = "Deal 3 three times.\nApply Demoralized 1 ⌛",
  up = { effects = { { "damage", 4, times = 3 }, { "apply", "demoralized", 1 } },
    text = "Deal 4 three times.\nApply Demoralized 1 ⌛" },
})

card("blizzard", {
  level = 1, rep = 0, name = "Blizzard", cost = 2, type = "attack", school = "frost", rarity = "uncommon", path = "frost",
  cast = true, effects = { { "damage", 12, all = true }, { "apply", "demoralized", 2, all = true } },
  text = "Cast.\nDeal 12 to all.\nApply Demoralized 2 ⌛ to all",
  up = { effects = { { "damage", 15, all = true }, { "apply", "demoralized", 2, all = true } },
    text = "Cast.\nDeal 15 to all.\nApply Demoralized 2 ⌛ to all" },
})

card("glacial_spike", {
  level = 2, rep = 0, name = "Glacial Spike", cost = 2, type = "attack", school = "frost", rarity = "uncommon", path = "frost",
  target = "enemy", cast = true, effects = { { "damage", 24 }, { "apply", "demoralized", 2 } },
  text = "Cast.\nDeal 24.\nApply Demoralized 2 ⌛",
  up = { effects = { { "damage", 30 }, { "apply", "demoralized", 2 } }, text = "Cast.\nDeal 30.\nApply Demoralized 2 ⌛" },
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
  level = 4, rep = 1, name = "Ice Block", cost = 1, type = "power", school = "frost", rarity = "rare", path = "frost",
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
  level = 6, rep = 1, name = "Deep Freeze", cost = 1, type = "attack", school = "frost", rarity = "uncommon", path = "frost",
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
  level = 7, rep = 2, name = "Shatter", cost = 1, type = "power", school = "frost", rarity = "rare", path = "frost",
  power = true, effects = {}, hooks = shatterHooks(3),
  text = "Power.\nFrozen: Attack hits deal 3 more.",
  up = { hooks = shatterHooks(4), text = "Power.\nFrozen: Attack hits deal 4 more." },
})

-- Arcane : monter les charges, les vider d'un Surge ; Evocation prépare un tour à 6 mana ----------------

card("arcane_missiles", {
  level = 1, rep = 0, name = "Arcane Missiles", cost = 1, type = "attack", school = "arcane", rarity = "common", path = "arcane",
  target = "enemy", effects = { { "damage", 3, times = 3 }, { "res", 1 } },
  text = "Deal 3 three times.\n+1 Arcane Charge.",
  up = { effects = { { "damage", 4, times = 3 }, { "res", 1 } }, text = "Deal 4 three times.\n+1 Arcane Charge." },
})

card("arcane_explosion", {
  level = 1, rep = 0, name = "Arcane Explosion", cost = 1, type = "attack", school = "arcane", rarity = "common", path = "arcane",
  effects = { { "damage", 4, all = true }, { "res", 1 } },
  text = "Deal 4 to all.\n+1 Arcane Charge.",
  up = { effects = { { "damage", 6, all = true }, { "res", 1 } }, text = "Deal 6 to all.\n+1 Arcane Charge." },
})

card("prismatic_barrier", {
  level = 1, rep = 0, name = "Prismatic Barrier", cost = 1, type = "skill", school = "arcane", rarity = "common", path = "arcane",
  effects = { { "absorb", 6 }, { "res", 1 } },
  text = "Gain 6 Absorb.\n+1 Arcane Charge.",
  up = { effects = { { "absorb", 9 }, { "res", 1 } }, text = "Gain 9 Absorb.\n+1 Arcane Charge." },
})

-- Surge : les charges sont lues puis remises à 0 avant le coup, le bonus passif ne s'y ajoute donc pas.
card("arcane_barrage", {
  level = 1, rep = 0, name = "Arcane Barrage", cost = 1, type = "attack", school = "arcane", rarity = "common", path = "arcane",
  minRes = 1, effects = { { "surge" }, { "damage", 0, all = true, per = { 6, "surge" } } },
  text = "Surge: deal 6 per Arcane Charge to all.",
  up = { effects = { { "surge" }, { "damage", 0, all = true, per = { 8, "surge" } } },
    text = "Surge: deal 8 per Arcane Charge to all." },
})

card("counterspell", {
  level = 1, rep = 0, name = "Counterspell", cost = 0, type = "skill", school = "arcane", rarity = "uncommon", path = "arcane",
  target = "enemy", cooldown = 2, effects = { { "interrupt" }, { "res", 1 } },
  text = "Interrupt the target's cast.\n+1 Arcane Charge.\nCooldown 2.",
  up = { cooldown = 1, text = "Interrupt the target's cast.\n+1 Arcane Charge.\nCooldown 1." },
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
  level = 1, rep = 0, name = "Evocation", cost = 0, type = "skill", school = "arcane", rarity = "uncommon", path = "arcane",
  cast = true, exhaust = true, evoMana = 3, effects = { { "fn", manaGain(3) } },
  text = "Cast.\n+3 mana.\nExhaust.",
  up = { evoMana = 4, effects = { { "fn", manaGain(4) } }, text = "Cast.\n+4 mana.\nExhaust." },
})

card("polymorph", {
  level = 2, rep = 1, name = "Polymorph", cost = 1, type = "skill", school = "arcane", rarity = "common", path = "arcane",
  target = "enemy", exhaust = true, effects = { { "res", 1 }, { "apply", "stunned", 2 } },
  text = "+1 Arcane Charge.\nApply Stunned 2 ⌛\nExhaust.",
  up = { cost = 0, text = "+1 Arcane Charge.\nApply Stunned 2 ⌛\nExhaust." },
})

card("presence_of_mind", {
  level = 4, rep = 1, name = "Presence of Mind", cost = 0, type = "skill", school = "arcane", rarity = "uncommon", path = "arcane",
  cooldown = 3, effects = { { "draw", 1 }, { "res", 1 }, { "apply", "instant", 1, self = true } },
  text = "Draw 1.\n+1 Arcane Charge.\nGain Instant 1\nCooldown 3.",
  up = { cooldown = 2, text = "Draw 1.\n+1 Arcane Charge.\nGain Instant 1\nCooldown 2." },
})

-- Arcane Power : chaque charge ajoute 2 au lieu de 1 (lu par la règle de classe ; deux exemplaires
-- ne font pas 3).
card("arcane_power", {
  level = 6, rep = 2, name = "Arcane Power", cost = 1, type = "power", school = "arcane", rarity = "rare", path = "arcane",
  power = true, effects = {}, chargeBonus = 2,
  text = "Power.\nArcane Charges add 2 damage, not 1.",
  up = { cost = 0, text = "Power.\nArcane Charges add 2 damage, not 1." },
})

local function surgeMana(c, ctx)
  local n = ctx.surge or 0
  if n > 0 then manaGain(n)(c) end
end

card("arcane_surge", {
  level = 7, rep = 2, name = "Arcane Surge", cost = 1, type = "skill", school = "arcane", rarity = "rare", path = "arcane",
  minRes = 1, effects = { { "surge" }, { "fn", surgeMana }, { "draw", 0, per = { 1, "surge" } } },
  text = "Surge: +1 mana, draw 1 per Arcane Charge.",
  up = { cost = 0, text = "Surge: +1 mana, draw 1 per Arcane Charge." },
})

-- Bibelots du Mage (class = "mage" : tirés seulement pour lui) -------------------------------------
-- tier = palier de Ligue lu aujourd'hui par le socle ; level = niveau de classe de la fiche (pas encore
-- appliqué).

local R = ns.Relics
local function relic(id, t)
  t.id = id
  t.class = "mage"
  t.hooks = t.hooks or {}
  R[id] = t
end

-- Bibelot de départ : la première carte Cast jouée dans le combat coûte 0 (même si elle coûtait déjà 0).
relic("apprentice_wand", {
  level = 1, name = "Apprentice's Wand", rarity = "common", tier = 0, noPool = true,
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
  level = 1, name = "Tome of Arcane Brilliance", rarity = "common", tier = 0,
  text = "Start each combat with 1 Arcane Charge.",
  hooks = {
    onCombatStart = function(c) Combat.gainRes(c, 1, "relic") end,
  },
})

-- Robe : aussi pour une carte Cast résolue sous Instant (résolue au jeu, sans onCastResolved).
relic("robe_archmage", {
  level = 3, name = "Robe of the Archmage", rarity = "uncommon", tier = 1,
  text = "When a Cast card resolves, gain 4 Absorb.",
  hooks = {
    onCastResolved = function(c) Combat.gainBlock(c, c.player, 4) end,
    onCardPlayed = function(c, src, inst, ctx)
      if ctx.def.cast and not ctx.cast then Combat.gainBlock(c, c.player, 4) end
    end,
  },
})

relic("glacial_cloak", {
  level = 5, name = "Glacial Cloak", rarity = "uncommon", tier = 1,
  text = "At the start of each combat, apply Demoralized 1 to all enemies.",
  hooks = {
    onCombatStart = function(c)
      local list = Combat.aliveEnemies(c)
      for i = 1, #list do Combat.applyStatus(c, list[i], "demoralized", 1) end
    end,
  },
})

relic("fire_ruby", {
  level = 7, name = "Fire Ruby", rarity = "rare", tier = 2,
  text = "Start each combat with Instant 1.",
  hooks = {
    onCombatStart = function(c) Combat.applyStatus(c, c.player, "instant", 1) end,
  },
})

relic("mind_quickening_gem", {
  level = 7, name = "Mind Quickening Gem", rarity = "rare", tier = 2,
  text = "At the start of each turn with 4 Arcane Charges, +1 mana.",
  hooks = {
    onTurnStart = function(c)
      if (c.player.res or 0) >= 4 then manaGain(1)(c) end
    end,
  },
})

-- Classe ------------------------------------------------------------------------

-- PV : 52 (fiche : 60, « à régler par simulation », decisions.md) ; à 60, 94 % de victoires au bot
-- heuristic, clé 0 ; à 52 avec Fireball 10, 84 à 85 % (300 expéditions, deux graines). Les Arcane
-- Charges valent à elles seules ~16 points (à 60 PV, sans leur bonus : 78 %) : à revoir à l'équilibrage fin.
ns.Classes.mage = {
  id = "mage", name = "Mage", order = 4, hp = 52,
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
      fire_blast = 6, scorch = 6, flamestrike = 6, blazing_barrier = 5.5, pyroblast = 6, hot_streak = 5.5,
      living_bomb = 6, phoenix_flames = 5.5, ignite = 6, combustion = 5.5,
      ice_lance = 6.5, frost_nova = 6.5, ice_barrier = 6, cone_of_cold = 6.5, flurry = 6, blizzard = 6,
      glacial_spike = 6, ice_block = 5.5, deep_freeze = 6, shatter = 6,
      arcane_missiles = 6, arcane_explosion = 6, prismatic_barrier = 6, arcane_barrage = 6, counterspell = 5,
      evocation = 4.5, polymorph = 6.5, presence_of_mind = 5.5, arcane_power = 6, arcane_surge = 5,
    },
    upgrade = { fireball = 2.5, frostbolt = 2.5, mana_shield = 2, arcane_blast = 2 },
    remove = { mana_shield = 1, frostbolt = 1.5 },
  },
}
