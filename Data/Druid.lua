-- Cartes et bibelots du Druide (fiche : docs/classes/druid.md ; décisions : docs/classes/decisions.md).
-- Mêmes champs que Data/Hunter.lua, plus `form` ("cat" | "bear" | "moonkin" | "tree" ; absent = carte sans
-- forme : Skull Bash, Nature's Swiftness, les Powers). Jouer une carte de forme fait entrer dans sa forme ;
-- règles (formes, réserve, effets de fin de tour, frappe de l'ours, Clearcasting) : Core/Classes/druid.lua ;
-- art et vue de classe : UI/Art/druid.lua.
--
-- Réserve (ressource « wild », 0 à 5, gardée) : « +1 Combo. » (Cat), « +1 Frenzy. » (Bear), « +1 Charge. »
-- (Moonkin) sont le même effet { "res", n } ; le nom vient de la forme de la carte. « Bear strikes. » = effet
-- { "bearStrike", n } (Surge : surge = true, au montant compté, sans gain).
-- Voies : Feral (Cat et Bear, Interrupt), Balance (Moonkin, Cast), Restoration (Tree of Life, Regen, Powers).
--
-- level = niveau de classe qui débloque la carte (fiche, § 7 Progression, 1 à 7 ; Core/Meta.lua).
local _, ns = ...

local Combat = ns.Combat
local C = ns.Cards

local function card(id, t)
  t.id = id
  t.class = "druid"
  C[id] = t
end

-- Départ ----------------------------------------------------------------------------------------------------

card("wrath", {
  level = 1, name = "Wrath", form = "moonkin", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 5 }, { "res", 1 } },
  text = "Deal 5.\n+1 Charge.",
  up = { effects = { { "damage", 8 }, { "res", 1 } }, text = "Deal 8.\n+1 Charge." },
  up2 = { effects = { { "damage", 10 }, { "res", 1 } }, text = "Deal 10.\n+1 Charge." },
  up3 = { effects = { { "damage", 12 }, { "res", 1 } }, text = "Deal 12.\n+1 Charge." },
})

card("thick_hide", {
  level = 1, name = "Thick Hide", form = "bear", cost = 1, type = "skill", rarity = "basic", path = "start",
  effects = { { "absorb", 5 } },
  text = "Gain 5 Absorb.",
  up = { effects = { { "absorb", 8 } }, text = "Gain 8 Absorb." },
  up2 = { effects = { { "absorb", 10 } }, text = "Gain 10 Absorb." },
  up3 = { retain = true, text = "Gain 10 Absorb.\nRetain." },
})

card("maul", {
  level = 1, name = "Maul", form = "bear", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 4 }, { "bearStrike", 1 } },
  text = "Deal 4.\nBear strikes.",
  up = { effects = { { "damage", 7 }, { "bearStrike", 1 } }, text = "Deal 7.\nBear strikes." },
  up2 = { effects = { { "damage", 9 }, { "bearStrike", 1 } }, text = "Deal 9.\nBear strikes." },
  up3 = { effects = { { "damage", 9 }, { "res", 1 }, { "bearStrike", 1 } }, text = "Deal 9.\n+1 Frenzy.\nBear strikes." },
})

card("ferocious_bite", {
  level = 1, name = "Ferocious Bite", form = "cat", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "damage", 4, per = { 4, "surge" } } },
  text = "Surge: deal 4 + 4 per Combo.",
  up = { effects = { { "surge" }, { "damage", 6, per = { 5, "surge" } } }, text = "Surge: deal 6 + 5 per Combo." },
  up2 = { effects = { { "surge" }, { "damage", 9, per = { 5, "surge" } } }, text = "Surge: deal 9 + 5 per Combo." },
  up3 = { retain = true, text = "Surge: deal 9 + 5 per Combo.\nRetain." },
})

-- Feral : monter en Cat (Combo), dépenser par un Surge, tenir et frapper en Bear (Frenzy) ---------------------

card("shred", {
  level = 1, name = "Shred", form = "cat", cost = 1, type = "attack", rarity = "common", path = "feral",
  target = "enemy", effects = { { "damage", 7 }, { "res", 1 } },
  text = "Deal 7.\n+1 Combo.",
  up = { effects = { { "damage", 10 }, { "res", 1 } }, text = "Deal 10.\n+1 Combo." },
  up2 = { effects = { { "damage", 12 }, { "res", 1 } }, text = "Deal 12.\n+1 Combo." },
  up3 = { effects = { { "damage", 14 }, { "res", 1 } }, text = "Deal 14.\n+1 Combo." },
})

card("rake", {
  level = 1, name = "Rake", form = "cat", cost = 1, type = "attack", rarity = "common", path = "feral",
  target = "enemy", effects = { { "damage", 3 }, { "res", 1 }, { "apply", "pain", 3, icon = "bleed" } },
  text = "Deal 3.\n+1 Combo.\nApply DoT 3",
  up = { effects = { { "damage", 4 }, { "res", 1 }, { "apply", "pain", 5, icon = "bleed" } },
    text = "Deal 4.\n+1 Combo.\nApply DoT 5" },
  up2 = { effects = { { "damage", 4 }, { "res", 1 }, { "apply", "pain", 7, icon = "bleed" } },
    text = "Deal 4.\n+1 Combo.\nApply DoT 7" },
  up3 = { effects = { { "damage", 6 }, { "res", 1 }, { "apply", "pain", 7, icon = "bleed" } },
    text = "Deal 6.\n+1 Combo.\nApply DoT 7" },
})

-- Swipe : sans cible, la frappe de l'ours reste sur la dernière cible.
card("swipe", {
  level = 1, name = "Swipe", form = "bear", cost = 1, type = "attack", rarity = "common", path = "feral",
  effects = { { "damage", 4, all = true }, { "bearStrike", 1 } },
  text = "Deal 4 to all.\nBear strikes.",
  up = { effects = { { "damage", 6, all = true }, { "bearStrike", 1 } }, text = "Deal 6 to all.\nBear strikes." },
  up2 = { effects = { { "damage", 7, all = true }, { "bearStrike", 1 } }, text = "Deal 7 to all.\nBear strikes." },
  up3 = { effects = { { "damage", 7, all = true }, { "res", 1 }, { "bearStrike", 1 } },
    text = "Deal 7 to all.\n+1 Frenzy.\nBear strikes." },
})

-- Skull Bash : l'Interrupt, sans forme (ne casse pas la forme de fin de tour).
card("skull_bash", {
  level = 1, name = "Skull Bash", cost = 0, type = "skill", rarity = "common", path = "feral",
  target = "enemy", cooldown = 2, effects = { { "interrupt" }, { "draw", 1 } },
  text = "Interrupt the target's cast.\nDraw 1.\nCooldown 2.",
  up = { cooldown = 1, text = "Interrupt the target's cast.\nDraw 1.\nCooldown 1." },
  up2 = { retain = true, text = "Interrupt the target's cast.\nDraw 1.\nCooldown 1.\nRetain." },
  up3 = { effects = { { "interrupt", all = true }, { "draw", 1 } }, text = "Interrupt all casts.\nDraw 1.\nCooldown 1.\nRetain." },
})

-- Rip : Rupture du Voleur (effet dotPer, Core/Classes/rogue.lua).
card("rip", {
  level = 1, name = "Rip", form = "cat", cost = 1, type = "skill", rarity = "uncommon", path = "feral",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "dotPer", 3, icon = "bleed" } },
  text = "Surge: apply DoT 3 per Combo.",
  up = { effects = { { "surge" }, { "dotPer", 4, icon = "bleed" } }, text = "Surge: apply DoT 4 per Combo." },
  up2 = { retain = true, text = "Surge: apply DoT 4 per Combo.\nRetain." },
  up3 = { effects = { { "surge" }, { "dotPer", 5, icon = "bleed" } }, text = "Surge: apply DoT 5 per Combo.\nRetain." },
})

-- Frenzied Regeneration : Growl du Hunter (Spend 2 retire 2 Frenzy contre de l'Absorb en plus).
card("frenzied_regeneration", {
  level = 1, name = "Frenzied Regeneration", form = "bear", cost = 1, type = "skill", rarity = "uncommon",
  path = "feral", spend = 2, effects = { { "absorb", 6, more = { { 6, "spent" } } } },
  text = "Gain 6 Absorb.\nSpend 2: gain 6 more.",
  up = { effects = { { "absorb", 8, more = { { 8, "spent" } } } }, text = "Gain 8 Absorb.\nSpend 2: gain 8 more." },
  up2 = { effects = { { "absorb", 10, more = { { 8, "spent" } } } }, text = "Gain 10 Absorb.\nSpend 2: gain 8 more." },
  up3 = { spend = 1, text = "Gain 10 Absorb.\nSpend 1: gain 8 more." },
})

card("tigers_fury", {
  level = 2, name = "Tiger's Fury", form = "cat", cost = 0, type = "skill", rarity = "uncommon", path = "feral",
  cooldown = 2, effects = { { "res", 1 }, { "draw", 1 } },
  text = "+1 Combo.\nDraw 1.\nCooldown 2.",
  up = { cooldown = 1, text = "+1 Combo.\nDraw 1.\nCooldown 1." },
  up2 = { retain = true, text = "+1 Combo.\nDraw 1.\nCooldown 1.\nRetain." },
  up3 = { effects = { { "res", 2 }, { "draw", 1 } }, text = "+2 Combo.\nDraw 1.\nCooldown 1.\nRetain." },
})

-- Mangle : Bestial Wrath du Hunter (une frappe par point compté, chacune à 1 + le montant, sans gain) ;
-- palier 2 : « +2 Frenzy. » après les frappes (la carte n'est plus faite que de Surge : jouable à 0).
card("mangle", {
  level = 4, name = "Mangle", form = "bear", cost = 2, type = "skill", rarity = "rare", path = "feral",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "bearStrike", 0, per = { 1, "surge" }, surge = true } },
  text = "Surge: Bear strikes once per Frenzy.",
  up = { cost = 1, text = "Surge: Bear strikes once per Frenzy." },
  up2 = { minRes = 0, effects = { { "surge" }, { "bearStrike", 0, per = { 1, "surge" }, surge = true }, { "res", 2 } },
    text = "Surge: Bear strikes once per Frenzy.\n+2 Frenzy." },
  up3 = { retain = true, text = "Surge: Bear strikes once per Frenzy.\n+2 Frenzy.\nRetain." },
})

card("demoralizing_roar", {
  level = 6, name = "Demoralizing Roar", form = "bear", cost = 0, type = "skill", rarity = "uncommon",
  path = "feral", cooldown = 4, effects = { { "res", 1 }, { "apply", "demoralized", 2, all = true } },
  text = "+1 Frenzy.\nApply Demoralized 2 ⌛ to all\nCooldown 4.",
  up = { cooldown = 3, text = "+1 Frenzy.\nApply Demoralized 2 ⌛ to all\nCooldown 3." },
  up2 = { effects = { { "res", 2 }, { "apply", "demoralized", 2, all = true } },
    text = "+2 Frenzy.\nApply Demoralized 2 ⌛ to all\nCooldown 3." },
  up3 = { effects = { { "res", 2 }, { "absorb", 4 }, { "apply", "demoralized", 2, all = true } },
    text = "+2 Frenzy.\nGain 4 Absorb.\nApply Demoralized 2 ⌛ to all\nCooldown 3." },
})

-- Leader of the Pack : chaque carte Attack de forme Cat, après sa résolution (copie comprise), +n Combo ;
-- palier 3 : ses coups font aussi 2 de plus.
local function leaderHooks(n, more)
  return {
    onCardPlayed = function(c, power, inst, ctx)
      local d = ctx.def
      if d and d.type == "attack" and d.form == "cat" and not c.result then Combat.gainRes(c, n, "card") end
    end,
    damage = more > 0 and function(c, power, v, dst, cardDef)
      if cardDef and cardDef.type == "attack" and cardDef.form == "cat" then return v + more end
      return v
    end or nil,
  }
end

card("leader_of_the_pack", {
  level = 7, name = "Leader of the Pack", cost = 1, type = "power", rarity = "rare", path = "feral",
  power = true, effects = {}, hooks = leaderHooks(1, 0),
  text = "Power.\nCat Attacks: +1 Combo.",
  up = { cost = 0, text = "Power.\nCat Attacks: +1 Combo." },
  up2 = { innate = true, text = "Power.\nCat Attacks: +1 Combo.\nInnate." },
  up3 = { hooks = leaderHooks(1, 2), text = "Power.\nCat Attacks: +1 Combo, deal 2 more.\nInnate." },
})

-- Balance : monter les Charges en Moonkin (bonus à chaque coup des Attack), les vider d'un Surge, Cast -------

-- Starfire : Cast ; résolue au tour suivant dans la forme où le tour a fini (bonus des Charges en Moonkin).
card("starfire", {
  level = 1, name = "Starfire", form = "moonkin", cost = 2, type = "attack", rarity = "common", path = "balance",
  target = "enemy", cast = true, effects = { { "damage", 20 } },
  text = "Cast.\nDeal 20.",
  up = { effects = { { "damage", 26 } }, text = "Cast.\nDeal 26." },
  up2 = { effects = { { "damage", 30 } }, text = "Cast.\nDeal 30." },
  up3 = { effects = { { "damage", 34 } }, text = "Cast.\nDeal 34." },
})

card("moonfire", {
  level = 1, name = "Moonfire", form = "moonkin", cost = 1, type = "attack", rarity = "common", path = "balance",
  target = "enemy", effects = { { "damage", 3 }, { "res", 1 }, { "apply", "pain", 3 } },
  text = "Deal 3.\n+1 Charge.\nApply DoT 3",
  up = { effects = { { "damage", 5 }, { "res", 1 }, { "apply", "pain", 4 } }, text = "Deal 5.\n+1 Charge.\nApply DoT 4" },
  up2 = { effects = { { "damage", 5 }, { "res", 1 }, { "apply", "pain", 6 } }, text = "Deal 5.\n+1 Charge.\nApply DoT 6" },
  up3 = { effects = { { "damage", 7 }, { "res", 1 }, { "apply", "pain", 6 } }, text = "Deal 7.\n+1 Charge.\nApply DoT 6" },
})

-- Starsurge : les Charges sont dépensées avant le coup (aucun bonus de Moonkin sur un Surge).
card("starsurge", {
  level = 1, name = "Starsurge", form = "moonkin", cost = 1, type = "attack", rarity = "common", path = "balance",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "damage", 0, per = { 6, "surge" } } },
  text = "Surge: deal 6 per Charge.",
  up = { effects = { { "surge" }, { "damage", 0, per = { 7, "surge" } } }, text = "Surge: deal 7 per Charge." },
  up2 = { retain = true, text = "Surge: deal 7 per Charge.\nRetain." },
  up3 = { effects = { { "surge" }, { "damage", 0, per = { 8, "surge" } } }, text = "Surge: deal 8 per Charge.\nRetain." },
})

card("faerie_fire", {
  level = 1, name = "Faerie Fire", form = "moonkin", cost = 0, type = "skill", rarity = "common", path = "balance",
  target = "enemy", cooldown = 3, effects = { { "res", 1 }, { "apply", "armor_broken", 2 } },
  text = "+1 Charge.\nApply Sundered 2 ⌛\nCooldown 3.",
  up = { cooldown = 2, text = "+1 Charge.\nApply Sundered 2 ⌛\nCooldown 2." },
  up2 = { effects = { { "res", 1 }, { "apply", "armor_broken", 3 } }, text = "+1 Charge.\nApply Sundered 3 ⌛\nCooldown 2." },
  up3 = { retain = true, text = "+1 Charge.\nApply Sundered 3 ⌛\nCooldown 2.\nRetain." },
})

-- Insect Swarm : la carte de contrôle de Balance, sans gain de réserve avant le palier 2.
card("insect_swarm", {
  level = 1, name = "Insect Swarm", form = "moonkin", cost = 1, type = "skill", rarity = "common", path = "balance",
  target = "enemy", effects = { { "apply", "pain", 4 }, { "apply", "demoralized", 1 } },
  text = "Apply DoT 4\nApply Demoralized 1 ⌛",
  up = { effects = { { "apply", "pain", 6 }, { "apply", "demoralized", 1 } }, text = "Apply DoT 6\nApply Demoralized 1 ⌛" },
  up2 = { effects = { { "res", 1 }, { "apply", "pain", 6 }, { "apply", "demoralized", 1 } },
    text = "+1 Charge.\nApply DoT 6\nApply Demoralized 1 ⌛" },
  up3 = { effects = { { "res", 1 }, { "apply", "pain", 6 }, { "apply", "demoralized", 2 } },
    text = "+1 Charge.\nApply DoT 6\nApply Demoralized 2 ⌛" },
})

card("hurricane", {
  level = 1, name = "Hurricane", form = "moonkin", cost = 2, type = "attack", rarity = "uncommon", path = "balance",
  cast = true, effects = { { "damage", 12, all = true } },
  text = "Cast.\nDeal 12 to all.",
  up = { effects = { { "damage", 15, all = true } }, text = "Cast.\nDeal 15 to all." },
  up2 = { retain = true, text = "Cast.\nDeal 15 to all.\nRetain." },
  up3 = { effects = { { "damage", 18, all = true } }, text = "Cast.\nDeal 18 to all.\nRetain." },
})

card("entangling_roots", {
  level = 2, name = "Entangling Roots", form = "moonkin", cost = 1, type = "skill", rarity = "uncommon",
  path = "balance", target = "enemy", cooldown = 4, effects = { { "res", 1 }, { "apply", "stunned", 1 } },
  text = "+1 Charge.\nApply Stunned 1 ⌛\nCooldown 4.",
  up = { cooldown = 3, text = "+1 Charge.\nApply Stunned 1 ⌛\nCooldown 3." },
  up2 = { effects = { { "res", 1 }, { "apply", "pain", 4 }, { "apply", "stunned", 1 } },
    text = "+1 Charge.\nApply DoT 4\nApply Stunned 1 ⌛\nCooldown 3." },
  up3 = { retain = true, text = "+1 Charge.\nApply DoT 4\nApply Stunned 1 ⌛\nCooldown 3.\nRetain." },
})

card("starfall", {
  level = 4, name = "Starfall", form = "moonkin", cost = 1, type = "attack", rarity = "rare", path = "balance",
  minRes = 1, effects = { { "surge" }, { "damage", 0, per = { 6, "surge" }, all = true } },
  text = "Surge: deal 6 per Charge to all.",
  up = { effects = { { "surge" }, { "damage", 0, per = { 7, "surge" }, all = true } }, text = "Surge: deal 7 per Charge to all." },
  up2 = { retain = true, text = "Surge: deal 7 per Charge to all.\nRetain." },
  up3 = { effects = { { "surge" }, { "damage", 0, per = { 8, "surge" }, all = true } },
    text = "Surge: deal 8 per Charge to all.\nRetain." },
})

local graceHooks = {
  cost = function(c, power, v, d)
    if d.cast then return v - 1 end
    return v
  end,
}

card("natures_grace", {
  level = 6, name = "Nature's Grace", cost = 2, type = "power", rarity = "uncommon", path = "balance",
  power = true, effects = {}, hooks = graceHooks,
  text = "Power.\nCast cards: cost −1.",
  up = { cost = 1, text = "Power.\nCast cards: cost −1." },
  up2 = { innate = true, text = "Power.\nCast cards: cost −1.\nInnate." },
  up3 = { effects = { { "apply", "instant", 1, self = true } }, text = "Power.\nCast cards: cost −1.\nGain Instant 1\nInnate." },
})

-- Moonkin Aura : à la fin de chaque tour fini en Moonkin (après les coups à tous de la forme), +n Charges.
local function auraHooks(n)
  return {
    onTurnEnd = function(c)
      if c.cls.form == "moonkin" and not c.result then Combat.gainRes(c, n, "card") end
    end,
  }
end

card("moonkin_aura", {
  level = 7, name = "Moonkin Aura", cost = 1, type = "power", rarity = "rare", path = "balance",
  power = true, effects = {}, hooks = auraHooks(1),
  text = "Power.\nEnd of turn in Moonkin: +1 Charge.",
  up = { cost = 0, text = "Power.\nEnd of turn in Moonkin: +1 Charge." },
  up2 = { innate = true, text = "Power.\nEnd of turn in Moonkin: +1 Charge.\nInnate." },
  up3 = { hooks = auraHooks(2), text = "Power.\nEnd of turn in Moonkin: +2 Charges.\nInnate." },
})

-- Restoration : soins Tree (tous Exhaust sauf Mark of the Wild), Regen, Powers ------------------------------

card("rejuvenation", {
  level = 1, name = "Rejuvenation", form = "tree", cost = 1, type = "skill", rarity = "common", path = "restoration",
  exhaust = true, effects = { { "apply", "regen", 4, self = true } },
  text = "Gain Regen 4\nExhaust.",
  up = { effects = { { "apply", "regen", 6, self = true } }, text = "Gain Regen 6\nExhaust." },
  up2 = { effects = { { "apply", "regen", 7, self = true } }, text = "Gain Regen 7\nExhaust." },
  up3 = { retain = true, text = "Gain Regen 7\nExhaust.\nRetain." },
})

card("regrowth", {
  level = 1, name = "Regrowth", form = "tree", cost = 1, type = "skill", rarity = "common", path = "restoration",
  exhaust = true, effects = { { "heal", 4 }, { "apply", "regen", 3, self = true } },
  text = "Heal 4.\nGain Regen 3\nExhaust.",
  up = { effects = { { "heal", 6 }, { "apply", "regen", 4, self = true } }, text = "Heal 6.\nGain Regen 4\nExhaust." },
  up2 = { effects = { { "heal", 6 }, { "draw", 1 }, { "apply", "regen", 4, self = true } },
    text = "Heal 6.\nDraw 1.\nGain Regen 4\nExhaust." },
  up3 = { effects = { { "heal", 8 }, { "draw", 1 }, { "apply", "regen", 4, self = true } },
    text = "Heal 8.\nDraw 1.\nGain Regen 4\nExhaust." },
})

card("mark_of_the_wild", {
  level = 1, name = "Mark of the Wild", form = "tree", cost = 1, type = "skill", rarity = "common",
  path = "restoration", effects = { { "absorb", 4 }, { "apply", "regen", 2, self = true } },
  text = "Gain 4 Absorb.\nGain Regen 2",
  up = { effects = { { "absorb", 6 }, { "apply", "regen", 3, self = true } }, text = "Gain 6 Absorb.\nGain Regen 3" },
  up2 = { effects = { { "absorb", 8 }, { "apply", "regen", 3, self = true } }, text = "Gain 8 Absorb.\nGain Regen 3" },
  up3 = { retain = true, text = "Gain 8 Absorb.\nGain Regen 3\nRetain." },
})

-- Thorns : chaque coup ennemi (même absorbé) renvoie n dégâts à l'attaquant (Retaliation du Guerrier).
local function thornsHooks(n)
  return {
    afterHit = function(c, power, enemy)
      if enemy.dead or c.result then return end
      Combat.dealDamage(c, c.player, enemy, Combat.calcDamage(c, c.player, enemy, n))
    end,
  }
end

card("thorns", {
  level = 1, name = "Thorns", cost = 1, type = "power", rarity = "common", path = "restoration",
  power = true, effects = {}, hooks = thornsHooks(3),
  text = "Power.\nWhen hit: deal 3 to the attacker.",
  up = { cost = 0, text = "Power.\nWhen hit: deal 3 to the attacker." },
  up2 = { hooks = thornsHooks(4), text = "Power.\nWhen hit: deal 4 to the attacker." },
  up3 = { innate = true, text = "Power.\nWhen hit: deal 4 to the attacker.\nInnate." },
})

-- Swiftmend : soigne k par point de Regen du Druide, sans la retirer (montant « regen », Core/Classes/druid.lua).
card("swiftmend", {
  level = 1, name = "Swiftmend", form = "tree", cost = 0, type = "skill", rarity = "uncommon", path = "restoration",
  exhaust = true, effects = { { "heal", 0, per = { 2, "regen" } } },
  text = "Heal 2 per Regen.\nExhaust.",
  up = { effects = { { "heal", 0, per = { 2, "regen" } }, { "draw", 1 } }, text = "Heal 2 per Regen.\nDraw 1.\nExhaust." },
  up2 = { retain = true, text = "Heal 2 per Regen.\nDraw 1.\nExhaust.\nRetain." },
  up3 = { effects = { { "heal", 0, per = { 3, "regen" } }, { "draw", 1 } },
    text = "Heal 3 per Regen.\nDraw 1.\nExhaust.\nRetain." },
})

-- Rebirth : Last Breath (Last Stand du Guerrier).
local function rebirthHooks(n)
  return {
    preventDeath = function(c, power)
      if not Combat.lastBreath(c, "rebirth") then return false end
      c.player.hp = 1
      Combat.heal(c, c.player, n)
      return true
    end,
  }
end

card("rebirth", {
  level = 1, name = "Rebirth", cost = 1, type = "power", rarity = "rare", path = "restoration",
  power = true, effects = {}, hooks = rebirthHooks(12),
  text = "Power.\nLast Breath: stay at 1 HP, heal 12.",
  up = { cost = 0, text = "Power.\nLast Breath: stay at 1 HP, heal 12." },
  up2 = { hooks = rebirthHooks(16), text = "Power.\nLast Breath: stay at 1 HP, heal 16." },
  up3 = { innate = true, text = "Power.\nLast Breath: stay at 1 HP, heal 16.\nInnate." },
})

-- Nature's Swiftness : sans forme, prépare un Cast de n'importe quelle forme (résolu tout de suite, dans sa forme).
card("natures_swiftness", {
  level = 2, name = "Nature's Swiftness", cost = 0, type = "skill", rarity = "uncommon", path = "restoration",
  exhaust = true, effects = { { "draw", 1 }, { "apply", "instant", 1, self = true } },
  text = "Draw 1.\nGain Instant 1\nExhaust.",
  up = { effects = { { "draw", 2 }, { "apply", "instant", 1, self = true } }, text = "Draw 2.\nGain Instant 1\nExhaust." },
  up2 = { retain = true, text = "Draw 2.\nGain Instant 1\nExhaust.\nRetain." },
  up3 = { effects = { { "draw", 2 }, { "apply", "instant", 2, self = true } }, text = "Draw 2.\nGain Instant 2\nExhaust.\nRetain." },
})

-- Healing Touch : Cast ; entre en Tree of Life au jeu, le soin se résout au tour suivant dans n'importe quelle
-- forme ; palier 3 : sans Cast (se résout tout de suite).
card("healing_touch", {
  level = 4, name = "Healing Touch", form = "tree", cost = 1, type = "skill", rarity = "uncommon",
  path = "restoration", cast = true, exhaust = true, effects = { { "heal", 12 } },
  text = "Cast.\nHeal 12.\nExhaust.",
  up = { effects = { { "heal", 16 } }, text = "Cast.\nHeal 16.\nExhaust." },
  up2 = { retain = true, text = "Cast.\nHeal 16.\nExhaust.\nRetain." },
  up3 = { cast = false, text = "Heal 16.\nExhaust.\nRetain." },
})

-- Gift of Nature : sous Regen, chaque coup d'une carte Attack (toutes formes) fait n de plus ; jamais la
-- frappe de l'ours ni les coups de fin de tour de Moonkin (coups sans carte).
local function giftHooks(n)
  return {
    damage = function(c, power, v, dst, cardDef)
      if cardDef and cardDef.type == "attack" and (c.player.st.regen or 0) > 0 then return v + n end
      return v
    end,
  }
end

card("gift_of_nature", {
  level = 6, name = "Gift of Nature", cost = 1, type = "power", rarity = "uncommon", path = "restoration",
  power = true, effects = {}, hooks = giftHooks(2),
  text = "Power.\nRegen: Attack hits deal 2 more.",
  up = { cost = 0, text = "Power.\nRegen: Attack hits deal 2 more." },
  up2 = { innate = true, text = "Power.\nRegen: Attack hits deal 2 more.\nInnate." },
  up3 = { hooks = giftHooks(3), text = "Power.\nRegen: Attack hits deal 3 more.\nInnate." },
})

card("tranquility", {
  level = 7, name = "Tranquility", form = "tree", cost = 2, type = "skill", rarity = "rare", path = "restoration",
  exhaust = true, effects = { { "heal", 6 }, { "apply", "regen", 5, self = true } },
  text = "Heal 6.\nGain Regen 5\nExhaust.",
  up = { effects = { { "heal", 9 }, { "apply", "regen", 6, self = true } }, text = "Heal 9.\nGain Regen 6\nExhaust." },
  up2 = { cost = 1, text = "Heal 9.\nGain Regen 6\nExhaust." },
  up3 = { retain = true, text = "Heal 9.\nGain Regen 6\nExhaust.\nRetain." },
})

-- Cartes épiques (cartes de zone, docs/classes/druid.md, § 5) -----------------------------------------------
-- Lot suivant : Furor (Westfall), Mark of Ursol (Duskwood), Eclipse (Wetlands), King of the Jungle
-- (Stranglethorn Vale), Lifebloom (Swamp of Sorrows), Owlkin Frenzy (Burning Steppes), Heart of the Wild
-- (Blackrock Mountain). À écrire ici sur le modèle de Data/Hunter.lua (epic(id, t) : rarity = "epic",
-- zone = "<id>", cost = 0, deckHooks / whileInDeck), règles dans Core/Classes/druid.lua ; notes des bots :
-- bot.epic et bot.byEpic de la définition de classe ci-dessous.

-- Bibelots du Druide (class = "druid" : tirés seulement pour lui) ------------------------------------------
-- level = niveau de classe qui les débloque.

local R = ns.Relics
local function relic(id, t)
  t.id = id
  t.class = "druid"
  t.hooks = t.hooks or {}
  R[id] = t
end

-- Bibelot de départ : la première carte du combat qui change la forme coûte 0 (le combat commence sans
-- forme : c'est la première carte de forme jouée). Servi au premier changement (événement « onShift »).
relic("idol_of_the_wild", {
  level = 1, name = "Idol of the Wild", rarity = "common", noPool = true,
  text = "The first card each combat that changes form costs 0.",
  hooks = {
    cost = function(c, src, v, d)
      if d.form and d.form ~= c.cls.form and not c.relicState.idol_of_the_wild then return 0 end
      return v
    end,
    onShift = function(c) c.relicState.idol_of_the_wild = true end,
  },
})

-- Idol of Brutality : base de la frappe de l'ours (crochet de classe « bearStrike », Core/Classes/druid.lua).
relic("idol_of_brutality", {
  level = 1, name = "Idol of Brutality", rarity = "common",
  text = "Bear strikes deal 2 more.",
  hooks = {
    bearStrike = function(c, src, v) return v + 2 end,
  },
})

relic("idol_of_ferocity", {
  level = 3, name = "Idol of Ferocity", rarity = "uncommon",
  text = "Each Surge in Cat: draw 1.",
  hooks = {
    onSurge = function(c)
      if c.cls.form == "cat" and not c.result then Combat.drawCards(c, 1) end
    end,
  },
})

-- Idol of the Moon : après les coups à tous de la forme (crochet de classe d'abord) ; l'Absorb tient le tour ennemi.
relic("idol_of_the_moon", {
  level = 5, name = "Idol of the Moon", rarity = "uncommon",
  text = "End of turn in Moonkin: gain 4 Absorb.",
  hooks = {
    onTurnEnd = function(c)
      if c.cls.form == "moonkin" and not c.result then Combat.gainBlock(c, c.player, 4) end
    end,
  },
})

-- Idol of Rejuvenation : au jeu de chaque carte Tree (Cast compris : au jeu, pas à la résolution).
relic("idol_of_rejuvenation", {
  level = 7, name = "Idol of Rejuvenation", rarity = "rare",
  text = "Each Tree card played: gain 3 Absorb.",
  hooks = {
    onCardCommitted = function(c, src, inst, d)
      if d.form == "tree" and not c.result then Combat.gainBlock(c, c.player, 3) end
    end,
  },
})

-- Wolfshead Helm : une pioche au premier changement de forme de chaque tour (c.relicState = tour servi).
relic("wolfshead_helm", {
  level = 7, name = "Wolfshead Helm", rarity = "rare",
  text = "The first form change each turn: draw 1.",
  hooks = {
    onShift = function(c)
      if c.relicState.wolfshead_helm == c.round or c.result then return end
      c.relicState.wolfshead_helm = c.round
      Combat.drawCards(c, 1)
    end,
  },
})

-- Classe ------------------------------------------------------------------------------------------------

ns.Classes.druid = {
  -- PV : 65 (décision du joueur, 18/11/2026), à régler par la simulation comme ceux des autres classes
  id = "druid", name = "Druid", order = 6, hp = 65,
  resource = { id = "wild", cap = 5, keep = true },
  deck = {
    "wrath", "wrath", "wrath",
    "thick_hide", "thick_hide", "thick_hide", "thick_hide",
    "maul", "maul", "ferocious_bite",
  },
  startRelic = "idol_of_the_wild",
  paths = { { id = "feral", name = "Feral" }, { id = "balance", name = "Balance" },
    { id = "restoration", name = "Restoration" } },
  survival = "absorb",
  bot = {
    -- un point de réserve : entre un Combo (Rogue 4) et un Frenzy (Hunter 6), fiche § 9
    resValue = 5,
    -- notes de départ (≈ 5 + écart / 2), à remplacer par un balayage (sweep=cards class=druid)
    rating = {
      demoralizing_roar = 8, entangling_roots = 8, tigers_fury = 7.5, shred = 7, skull_bash = 7,
      frenzied_regeneration = 7, faerie_fire = 7, hurricane = 7, starfall = 7, rebirth = 7,
      swipe = 6.5, moonfire = 6.5, mark_of_the_wild = 6.5, rake = 6, mangle = 6, starfire = 6, starsurge = 6,
      insect_swarm = 6, natures_swiftness = 6, leader_of_the_pack = 6, tranquility = 6, rip = 5.5, thorns = 5.5,
      regrowth = 5.5, moonkin_aura = 5, rejuvenation = 5, swiftmend = 5, healing_touch = 5, gift_of_nature = 5,
      natures_grace = 4.5,
    },
    upgrade = { wrath = 2.5, maul = 2.5, thick_hide = 2, ferocious_bite = 2 },
    remove = { thick_hide = 1, wrath = 1.5 },
  },
}
