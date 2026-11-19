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
  level = 2, name = "Rip", form = "cat", cost = 1, type = "skill", rarity = "uncommon", path = "feral",
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
  level = 1, name = "Tiger's Fury", form = "cat", cost = 0, type = "skill", rarity = "uncommon", path = "feral",
  cooldown = 2, effects = { { "res", 1 }, { "draw", 1 } },
  text = "+1 Combo.\nDraw 1.\nCooldown 2.",
  up = { cooldown = 1, text = "+1 Combo.\nDraw 1.\nCooldown 1." },
  up2 = { retain = true, text = "+1 Combo.\nDraw 1.\nCooldown 1.\nRetain." },
  up3 = { effects = { { "res", 2 }, { "draw", 1 } }, text = "+2 Combo.\nDraw 1.\nCooldown 1.\nRetain." },
})

-- Mangle : Bestial Wrath du Hunter (une frappe par point compté, chacune à 1 + le montant, sans gain), puis
-- « +2 Frenzy. » (jouable à 0 : la carte n'est plus faite que de Surge) ; coût 1. Jusqu'au 19/11/2026 : coût 2,
-- sans le gain (palier 2), gardée en main 63 % des fois où elle était piochée.
card("mangle", {
  level = 4, name = "Mangle", form = "bear", cost = 1, type = "skill", rarity = "rare", path = "feral",
  target = "enemy", minRes = 0,
  effects = { { "surge" }, { "bearStrike", 0, per = { 1, "surge" }, surge = true }, { "res", 2 } },
  text = "Surge: Bear strikes once per Frenzy.\n+2 Frenzy.",
  up = { effects = { { "surge" }, { "bearStrike", 0, per = { 1, "surge" }, surge = true }, { "res", 3 } },
    text = "Surge: Bear strikes once per Frenzy.\n+3 Frenzy." },
  up2 = { retain = true, text = "Surge: Bear strikes once per Frenzy.\n+3 Frenzy.\nRetain." },
  up3 = { cost = 0, text = "Surge: Bear strikes once per Frenzy.\n+3 Frenzy.\nRetain." },
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
-- palier 1 : ses coups font aussi 2 de plus (3 au palier 3).
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

-- Coût 0 (1 jusqu'au 19/11/2026 : gardée en main 45 % des fois).
card("leader_of_the_pack", {
  level = 7, name = "Leader of the Pack", cost = 0, type = "power", rarity = "rare", path = "feral",
  power = true, effects = {}, hooks = leaderHooks(1, 0),
  text = "Power.\nCat Attacks: +1 Combo.",
  up = { hooks = leaderHooks(1, 2), text = "Power.\nCat Attacks: +1 Combo, deal 2 more." },
  up2 = { innate = true, text = "Power.\nCat Attacks: +1 Combo, deal 2 more.\nInnate." },
  up3 = { hooks = leaderHooks(1, 3), text = "Power.\nCat Attacks: +1 Combo, deal 3 more.\nInnate." },
})

-- Balance : monter les Charges en Moonkin (bonus à chaque coup des Attack), les vider d'un Surge, Cast -------

-- Starfire : Cast ; résolue au tour suivant dans la forme où le tour a fini (bonus des Charges en Moonkin).
card("starfire", {
  level = 1, name = "Starfire", form = "moonkin", cost = 2, type = "attack", rarity = "common", path = "balance",
  target = "enemy", cast = true, effects = { { "damage", 24 } },
  text = "Cast.\nDeal 24.",
  up = { effects = { { "damage", 30 } }, text = "Cast.\nDeal 30." },
  up2 = { effects = { { "damage", 34 } }, text = "Cast.\nDeal 34." },
  up3 = { effects = { { "damage", 38 } }, text = "Cast.\nDeal 38." },
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
  target = "enemy", minRes = 1, effects = { { "surge" }, { "damage", 0, per = { 7, "surge" } } },
  text = "Surge: deal 7 per Charge.",
  up = { effects = { { "surge" }, { "damage", 0, per = { 8, "surge" } } }, text = "Surge: deal 8 per Charge." },
  up2 = { retain = true, text = "Surge: deal 8 per Charge.\nRetain." },
  up3 = { effects = { { "surge" }, { "damage", 0, per = { 9, "surge" } } }, text = "Surge: deal 9 per Charge.\nRetain." },
})

-- Faerie Fire : 3 Absorb depuis le 19/11/2026 (défense de Balance, avec Insect Swarm).
card("faerie_fire", {
  level = 1, name = "Faerie Fire", form = "moonkin", cost = 0, type = "skill", rarity = "common", path = "balance",
  target = "enemy", cooldown = 3, effects = { { "res", 1 }, { "absorb", 3 }, { "apply", "armor_broken", 2 } },
  text = "+1 Charge.\nGain 3 Absorb.\nApply Sundered 2 ⌛\nCooldown 3.",
  up = { cooldown = 2, text = "+1 Charge.\nGain 3 Absorb.\nApply Sundered 2 ⌛\nCooldown 2." },
  up2 = { effects = { { "res", 1 }, { "absorb", 3 }, { "apply", "armor_broken", 3 } },
    text = "+1 Charge.\nGain 3 Absorb.\nApply Sundered 3 ⌛\nCooldown 2." },
  up3 = { retain = true, text = "+1 Charge.\nGain 3 Absorb.\nApply Sundered 3 ⌛\nCooldown 2.\nRetain." },
})

-- Insect Swarm : la carte de contrôle et de défense de Balance (Absorb depuis le 19/11/2026 : tenir le tour
-- ennemi sans quitter Moonkin), sans gain de réserve avant le palier 2.
card("insect_swarm", {
  level = 1, name = "Insect Swarm", form = "moonkin", cost = 1, type = "skill", rarity = "common", path = "balance",
  target = "enemy", effects = { { "absorb", 5 }, { "apply", "pain", 4 }, { "apply", "demoralized", 1 } },
  text = "Gain 5 Absorb.\nApply DoT 4\nApply Demoralized 1 ⌛",
  up = { effects = { { "absorb", 7 }, { "apply", "pain", 6 }, { "apply", "demoralized", 1 } },
    text = "Gain 7 Absorb.\nApply DoT 6\nApply Demoralized 1 ⌛" },
  up2 = { effects = { { "res", 1 }, { "absorb", 7 }, { "apply", "pain", 6 }, { "apply", "demoralized", 1 } },
    text = "+1 Charge.\nGain 7 Absorb.\nApply DoT 6\nApply Demoralized 1 ⌛" },
  up3 = { effects = { { "res", 1 }, { "absorb", 7 }, { "apply", "pain", 6 }, { "apply", "demoralized", 2 } },
    text = "+1 Charge.\nGain 7 Absorb.\nApply DoT 6\nApply Demoralized 2 ⌛" },
})

card("hurricane", {
  level = 2, name = "Hurricane", form = "moonkin", cost = 2, type = "attack", rarity = "uncommon", path = "balance",
  cast = true, effects = { { "damage", 15, all = true } },
  text = "Cast.\nDeal 15 to all.",
  up = { effects = { { "damage", 18, all = true } }, text = "Cast.\nDeal 18 to all." },
  up2 = { retain = true, text = "Cast.\nDeal 18 to all.\nRetain." },
  up3 = { effects = { { "damage", 21, all = true } }, text = "Cast.\nDeal 21 to all.\nRetain." },
})

card("entangling_roots", {
  level = 1, name = "Entangling Roots", form = "moonkin", cost = 1, type = "skill", rarity = "uncommon",
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
  level = 6, name = "Nature's Grace", cost = 1, type = "power", rarity = "uncommon", path = "balance",
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
  level = 4, name = "Rebirth", cost = 1, type = "power", rarity = "rare", path = "restoration",
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
  level = 1, name = "Healing Touch", form = "tree", cost = 1, type = "skill", rarity = "uncommon",
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
-- Une épique est une règle en jeu dès le début de chaque combat (c.epic, hors des piles) : jamais piochée ni
-- jouée, sans coût. Crochets en deckHooks (src = c.epic, passés après pouvoirs et bibelots) ; la carte dit
-- « Déclencheur: Mot N. », le mot de règle (L.rule, Core/Classes/druid.lua) donne la règle complète.
-- Nombres : tables { base, +1, +2, +3 } de ns.DruidEpic, seule source des textes, des règles et des à-côtés ;
-- points de départ de la fiche, à régler par la simulation. Heart of the Wild : une réserve par forme
-- (Druid.kinship…, Core/Classes/druid.lua ; minRes et Spend lisent la réserve de la carte : Combat.cardRes).
local EPIC = {
  primal = { 2, 3, 4, 5 },          -- Furor : changements de forme qui donnent +1 réserve, par tour
  ironfur = { 50, 75, 100, 125 },   -- Mark of Ursol : Absorb = ce pourcentage des dégâts de chaque frappe de l'ours
  lunar = { 5, 4, 4, 3 },           -- Eclipse : réserve qu'il faut pour qu'un Cast Moonkin se résolve tout de suite
  solar = { 0, 0, 3, 3 },           -- Eclipse : dégâts en plus de chaque coup de ce Cast (paliers 2 et 3 : « Solar »)
  predator = { 1, 2, 2, 3 },        -- King of the Jungle : réserve laissée par chaque Surge (au plus le montant)
  apex = { 0, 0, 1, 1 },            -- King of the Jungle : pioche au premier Surge de chaque tour (« Apex »)
  bloom = { 1, 1, 2, 2 },           -- Lifebloom : réserve gagnée à chaque tic de Regen
  bloomStart = { 0, 3, 3, 5 },      -- Lifebloom : Regen au début de chaque combat (+3 : « Overgrowth »)
  moonfury = { 1, 2, 2, 3 },        -- Owlkin Frenzy : réserve par attaque ennemie qui coûte des PV en Moonkin
  barkskin = { 0, 0, 3, 3 },        -- Owlkin Frenzy : Absorb à la fin d'un tour fini en Moonkin (« Barkskin »)
  kinship = { 3, 4, 5, 5 },         -- Heart of the Wild : plafond de chaque réserve (Cat, Bear, Moonkin)
  kinStart = { 0, 0, 0, 1 },        -- Heart of the Wild : chaque réserve au début du combat (+3 : « Kindred »)
}
ns.DruidEpic = EPIC

local function D() return ns.Druid end -- Core/Classes/druid.lua, chargé après ce fichier

local function epic(id, t)
  t.type, t.rarity, t.epic, t.cost = "power", "epic", true, 0 -- coût jamais payé ni affiché
  t.effects = t.effects or {}
  card(id, t)
end

-- Nombre d'une épique à son palier : t[palier + 1].
local function nt(t, src) return t[math.min(#t, ns.Card.level(src) + 1)] end

-- Textes : « Epic.\nDéclencheur: Mot N. » à chaque palier (fn(k) = mot et nombre du palier k, 1 à 4).
local function tiers(t, label, fn)
  local function text(k) return "Epic.\n" .. label .. ": " .. fn(k) .. "." end
  t.text = text(1)
  t.up = { text = text(2) }
  t.up2 = { text = text(3) }
  t.up3 = { text = text(4) }
  return t
end

-- Westfall — Furor : chaque changement de forme donne +1 à la réserve, EPIC.primal fois par tour au plus
-- (l'entrée dans la première forme du combat compte ; c.cls.furor = changements payés du tour c.cls.furorRound).
epic("furor", tiers({
  zone = "westfall", path = "restoration", name = "Furor",
  deckHooks = {
    onShift = function(c, src)
      if c.result then return end
      local cls = c.cls
      if cls.furorRound ~= c.round then cls.furorRound, cls.furor = c.round, 0 end
      if cls.furor >= nt(EPIC.primal, src) then return end
      cls.furor = cls.furor + 1
      Combat.gainRes(c, 1, "epic")
    end,
  },
}, "Form changes", function(k) return "Primal " .. EPIC.primal[k] end))

-- Duskwood — Mark of Ursol : après chaque frappe de l'ours (fin de tour, carte, Surge), Absorb = EPIC.ironfur %
-- des dégâts de la frappe, arrondi à l'inférieur.
epic("mark_of_ursol", tiers({
  zone = "duskwood", path = "feral", name = "Mark of Ursol",
  deckHooks = {
    onBearStrike = function(c, src, t, dmg)
      if c.result or not dmg or dmg <= 0 then return end
      local n = math.floor(dmg * nt(EPIC.ironfur, src) / 100)
      if n > 0 then Combat.gainBlock(c, c.player, n) end
    end,
  },
}, "Bear strikes", function(k) return "Ironfur " .. EPIC.ironfur[k] .. "%" end))

-- Wetlands — Eclipse : avec au moins EPIC.lunar en réserve, une carte Cast de forme Moonkin se résout tout de
-- suite (crochet instantCast, lu après le changement de forme : dans Moonkin, avec le bonus des Charges), sans
-- emplacement ni interruption ; paliers 2 et 3 : ses coups font EPIC.solar de plus (c.cls.eclipse = uid de
-- la carte en cours). L'état Instant n'est pas consommé quand l'épique fait partir la carte.
epic("eclipse", tiers({
  zone = "wetlands", path = "balance", name = "Eclipse",
  deckHooks = {
    instantCast = function(c, src, v, d, inst, commit)
      if v or not d.cast or d.form ~= "moonkin" then return v end
      if (c.player.res or 0) < nt(EPIC.lunar, src) then return v end
      if commit then
        Combat.log(c, { t = "cast_instant", card = inst.uid, by = "eclipse" })
        if c.stats then c.stats.castsInstant = (c.stats.castsInstant or 0) + 1 end
        if nt(EPIC.solar, src) > 0 then c.cls.eclipse = inst.uid end
      end
      return true
    end,
    damage = function(c, src, v, dst, cardDef)
      if c.cls.eclipse and cardDef and cardDef.cast and cardDef.form == "moonkin" then
        return v + nt(EPIC.solar, src)
      end
      return v
    end,
    afterCast = function(c, src, inst)
      if c.cls.eclipse == inst.uid then c.cls.eclipse = nil end
    end,
  },
}, "Cast cards", function(k)
  return (EPIC.solar[k] > 0 and "Solar " or "Lunar ") .. EPIC.lunar[k]
end))

-- Stranglethorn Vale — King of the Jungle : un Surge compte toute la réserve, puis min(EPIC.predator, montant)
-- y revient à la fin de la résolution de la carte (onCardPlayed : aucun bonus de Moonkin sur la carte Surge
-- elle-même) ; paliers 2 et 3 : le premier Surge de chaque tour pioche EPIC.apex (c.cls.apexRound).
epic("king_of_the_jungle", tiers({
  zone = "stranglethorn", path = "feral", name = "King of the Jungle",
  deckHooks = {
    onSurge = function(c, src, n, ctx)
      if c.result or not ctx then return end
      ctx.predator = (ctx.predator or 0) + math.min(n, nt(EPIC.predator, src))
      local draw = nt(EPIC.apex, src)
      if draw > 0 and c.cls.apexRound ~= c.round then
        c.cls.apexRound = c.round
        Combat.drawCards(c, draw)
      end
    end,
    onCardPlayed = function(c, src, inst, ctx)
      local keep = ctx and ctx.predator
      if keep and keep > 0 and not c.result then
        ctx.predator = nil
        Combat.gainRes(c, keep, "epic")
      end
    end,
  },
}, "Surge cards", function(k)
  return (EPIC.apex[k] > 0 and "Apex " or "Predator ") .. EPIC.predator[k]
end))

-- Swamp of Sorrows — Lifebloom : chaque tic de Regen du Druide (même à PV pleins) donne EPIC.bloom à la réserve ;
-- améliorée : EPIC.bloomStart Regen au début de chaque combat (whileInDeck, avant le premier tour : elle tique
-- dès le premier début de tour).
epic("lifebloom", tiers({
  zone = "swamp", path = "restoration", name = "Lifebloom",
  whileInDeck = function(c, src)
    local n = nt(EPIC.bloomStart, src)
    if n > 0 then Combat.applyStatus(c, c.player, "regen", n) end
  end,
  deckHooks = {
    onRegenTick = function(c, src)
      if not c.result then Combat.gainRes(c, nt(EPIC.bloom, src), "epic") end
    end,
  },
}, "Each Regen heal", function(k)
  return (EPIC.bloomStart[k] > EPIC.bloomStart[2] and "Overgrowth " or "Bloom ") .. EPIC.bloom[k]
end))

-- Burning Steppes — Owlkin Frenzy : en Moonkin, une attaque ennemie qui coûte des PV donne EPIC.moonfury à la
-- réserve, une fois par attaque (c.cls.owlFx = numéro de l'effet de l'action ennemie, Combat.fxBegin) ;
-- paliers 2 et 3 : EPIC.barkskin Absorb à la fin de chaque tour fini en Moonkin (après les coups à tous).
epic("owlkin_frenzy", tiers({
  zone = "steppes", path = "balance", name = "Owlkin Frenzy",
  deckHooks = {
    onPlayerHit = function(c, src, enemy, n)
      if c.result or c.cls.form ~= "moonkin" or (n or 0) <= 0 then return end
      local fx = c.fxId
      if fx and c.cls.owlFx == fx then return end
      c.cls.owlFx = fx
      Combat.gainRes(c, nt(EPIC.moonfury, src), "epic")
    end,
    onTurnEnd = function(c, src)
      local n = nt(EPIC.barkskin, src)
      if n > 0 and c.cls.form == "moonkin" and not c.result then Combat.gainBlock(c, c.player, n) end
    end,
  },
}, "When hit", function(k)
  return (EPIC.barkskin[k] > 0 and "Barkskin " or "Moonfury ") .. EPIC.moonfury[k]
end))

-- Blackrock Mountain — Heart of the Wild : Cat, Bear et Moonkin gardent chacune leur réserve (plafond
-- EPIC.kinship, crochet resCap) ; c.player.res est celle de la forme active, les autres attendent dans
-- c.cls.kin (Druid.kinStart, Druid.usePool : au changement de forme, et au jeu d'une carte de forme avant son
-- Spend ; minRes et Spend lisent la réserve de la forme de la carte, Combat.cardRes). Sans forme et en Tree of
-- Life : une quatrième réserve, que rien ne remplit. +3 : chaque réserve commence à EPIC.kinStart.
epic("heart_of_the_wild", tiers({
  zone = "blackrock", path = "feral", name = "Heart of the Wild",
  whileInDeck = function(c, src) D().kinStart(c, nt(EPIC.kinStart, src)) end,
  deckHooks = {
    resCap = function(c, src, v) return math.min(v, nt(EPIC.kinship, src)) end,
    onShift = function(c, src, from, to) D().usePool(c, to) end,
  },
}, "Forms", function(k)
  return (EPIC.kinStart[k] > 0 and "Kindred " or "Kinship ") .. EPIC.kinship[k]
end))

-- Bots (classDef.bot.epic et bot.byEpic, attachés en fin de fichier) : note d'une épique proposée ≈ 5 + gain
-- / 2 (gain non mesuré : 10 pour toutes, estimation à remplacer par la mesure epic=<id>) ; l'épique du deck
-- vaut EPIC_KEEP de plus. Builds pilotés par l'épique (« Ce qu'elle fait construire », fiche § 5), notes qui
-- priment sur bot.rating tant que l'épique est dans le deck.
local EPIC_KEEP = 5
local EPIC_BOT = {
  furor = 10, mark_of_ursol = 10, eclipse = 10, king_of_the_jungle = 10, lifebloom = 10, owlkin_frenzy = 10,
  heart_of_the_wild = 10,
}
local EPIC_BUILDS = {
  -- cartes de forme à 0 ou 1 mana qui changent souvent la forme
  furor = {
    rating = { tigers_fury = 9, faerie_fire = 8.5, demoralizing_roar = 9, entangling_roots = 8.5, shred = 7.5,
      moonfire = 7, ferocious_bite = 7, starsurge = 7, rip = 6.5 },
    upgrade = { furor = 4, tigers_fury = 3 },
  },
  -- un ours qui frappe souvent et haut
  mark_of_ursol = {
    rating = { maul = 8, swipe = 8, mangle = 9, demoralizing_roar = 9, frenzied_regeneration = 6, thorns = 6.5 },
    upgrade = { mark_of_ursol = 4, maul = 3.5 },
  },
  -- monter à N, puis Starfire et Hurricane tout de suite
  eclipse = {
    rating = { starfire = 9, hurricane = 9, faerie_fire = 8.5, moonfire = 7.5, entangling_roots = 8.5,
      moonkin_aura = 7.5, natures_grace = 6.5, starsurge = 4.5, starfall = 5 },
    upgrade = { eclipse = 4, starfire = 3.5 },
  },
  -- plusieurs Surge par combat
  king_of_the_jungle = {
    rating = { rip = 7.5, starsurge = 8, starfall = 8.5, mangle = 8, tigers_fury = 8 },
    upgrade = { king_of_the_jungle = 4, ferocious_bite = 3 },
  },
  -- la Regen comme générateur, dépensée par les Surge des autres formes
  lifebloom = {
    rating = { rejuvenation = 8, regrowth = 7.5, mark_of_the_wild = 8, tranquility = 8, gift_of_nature = 7,
      starsurge = 7, rip = 6.5, starfall = 7.5 },
    upgrade = { lifebloom = 4, rejuvenation = 3 },
  },
  -- finir en Moonkin et encaisser
  owlkin_frenzy = {
    rating = { moonfire = 7.5, starsurge = 7.5, starfall = 8.5, moonkin_aura = 8, thorns = 7, starfire = 7 },
    upgrade = { owlkin_frenzy = 4, starsurge = 3 },
  },
  -- un deck à trois formes, chacune avec sa dépense
  heart_of_the_wild = {
    rating = { shred = 7.5, tigers_fury = 8, starsurge = 7.5, mangle = 7.5, rip = 6.5, moonfire = 7 },
    upgrade = { heart_of_the_wild = 4, ferocious_bite = 3 },
  },
}

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
  -- PV : 65 décidés par le joueur (18/11/2026), 58 après la mesure au bot heuristic, 65 de nouveau au bot human
  -- (docs/equilibrage.md, « Druid : réglage au bot human »), 59 avec l'Absorb de Tree of Life, Cat <-> Bear hors
  -- taxe et les cartes offensives relevées (19/11/2026, « Druid : Absorb en Tree, Cat/Bear hors taxe »)
  id = "druid", name = "Druid", order = 6, hp = 59,
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

-- Épiques pour les bots (tables de la section des cartes épiques ci-dessus ; Sim/expedition.lua).
do
  local bot = ns.Classes.druid.bot
  bot.epic = function(exp, id)
    local v = EPIC_BOT[id]
    local i = v and exp and ns.Expedition.epicIndex(exp)
    if i and exp.deck[i].id == id then v = v + EPIC_KEEP end
    return v
  end
  bot.byEpic = EPIC_BUILDS
end
