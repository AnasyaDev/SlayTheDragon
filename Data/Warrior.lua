-- Cartes et bibelots du Guerrier (GDD des classes, docs/gdd-classes.md, section Warrior).
-- Mêmes champs que Data/Priest.lua ; règles propres (Rage) : Core/Classes/warrior.lua ; art :
-- UI/Art/warrior.lua. Chiffres calés sur le Priest à coût égal, puis réglés par la simulation
-- (luajit Sim/sim.lua ... class=warrior, docs/classes.md).
--
-- Rage (0 à 5, gardée d'un tour à l'autre) : +1 par PV perdus (coup, DoT, « Pay N HP »), +1 par carte
-- Attack jouée. Dépensée par « Spend N: » (champ spend, payé au jeu si la Rage suffit) ou « Surge: »
-- (effet surge, toute la Rage). Voies : Arms (Sundered, gros coup, Execute), Fury (petites attaques,
-- Strength, cartes payées en PV), Protection (Absorb converti en dégâts, ripostes).
local _, ns = ...

local Combat = ns.Combat
local C = ns.Cards

local function card(id, t)
  t.id = id
  t.class = "warrior"
  C[id] = t
end

-- Départ -------------------------------------------------------------------

card("strike", {
  name = "Strike", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 6 } },
  text = "Deal 6.",
  up = { effects = { { "damage", 9 } }, text = "Deal 9." },
})

card("defend", {
  name = "Defend", cost = 1, type = "skill", rarity = "basic", path = "start",
  effects = { { "absorb", 5 } },
  text = "Gain 5 Absorb.",
  up = { effects = { { "absorb", 8 } }, text = "Gain 8 Absorb." },
})

card("heroic_strike", {
  name = "Heroic Strike", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", spend = 2, effects = { { "damage", 7, more = { { 5, "spent" } } } },
  text = "Deal 7.\nSpend 2: deal 5 more.",
  up = { effects = { { "damage", 9, more = { { 7, "spent" } } } }, text = "Deal 9.\nSpend 2: deal 7 more." },
})

card("bloodrage", {
  name = "Bloodrage", cost = 0, type = "skill", rarity = "basic", path = "start",
  payHp = 2, effects = { { "res", 2 }, { "draw", 1 } },
  text = "Pay 2 HP.\n+2 Rage.\nDraw 1.",
  up = { effects = { { "res", 3 }, { "draw", 1 } }, text = "Pay 2 HP.\n+3 Rage.\nDraw 1." },
})

-- Arms : Sundered, puis un seul gros coup ; Execute sur les cibles entamées ---------------------

card("rend", {
  rep = 0, name = "Rend", cost = 1, type = "attack", rarity = "common", path = "arms",
  target = "enemy", effects = { { "damage", 3 }, { "apply", "pain", 4, icon = "bleed" } },
  text = "Deal 3.\nApply DoT 4",
  up = { effects = { { "damage", 4 }, { "apply", "pain", 6, icon = "bleed" } }, text = "Deal 4.\nApply DoT 6" },
})

card("overpower", {
  rep = 0, name = "Overpower", cost = 0, type = "attack", rarity = "common", path = "arms",
  target = "enemy", effects = { { "damage", 3, more = { { 4, "status:armor_broken" } } } },
  text = "Deal 3.\nSundered: deal 4 more.",
  up = { effects = { { "damage", 5, more = { { 5, "status:armor_broken" } } } }, text = "Deal 5.\nSundered: deal 5 more." },
})

card("slam", {
  rep = 0, name = "Slam", cost = 1, type = "attack", rarity = "common", path = "arms",
  target = "enemy", cast = true, effects = { { "damage", 14 } },
  text = "Cast.\nDeal 14.",
  up = { effects = { { "damage", 18 } }, text = "Cast.\nDeal 18." },
})

card("cleave", {
  rep = 1, name = "Cleave", cost = 1, type = "attack", rarity = "common", path = "arms",
  effects = { { "damage", 7, all = true } },
  text = "Deal 7 to all.",
  up = { effects = { { "damage", 10, all = true } }, text = "Deal 10 to all." },
})

card("mortal_strike", {
  rep = 0, name = "Mortal Strike", cost = 2, type = "attack", rarity = "uncommon", path = "arms",
  target = "enemy", effects = { { "damage", 16 }, { "apply", "armor_broken", 2 } },
  text = "Deal 16.\nApply Sundered 2 ⌛",
  up = { effects = { { "damage", 21 }, { "apply", "armor_broken", 3 } }, text = "Deal 21.\nApply Sundered 3 ⌛" },
})

-- Execute : la Rage n'est dépensée que si la cible est entamée (condition lue à la résolution).
card("execute", {
  rep = 0, name = "Execute", cost = 1, type = "attack", rarity = "uncommon", path = "arms",
  target = "enemy", effects = { { "surge", cond = "execute" }, { "damage", 5, per = { 4, "surge" } } },
  text = "Deal 5.\nExecute: Surge: deal 4 per Rage.",
  up = { effects = { { "surge", cond = "execute" }, { "damage", 7, per = { 5, "surge" } } },
    text = "Deal 7.\nExecute: Surge: deal 5 per Rage." },
})

card("colossus_smash", {
  rep = 0, name = "Colossus Smash", cost = 1, type = "attack", rarity = "uncommon", path = "arms",
  target = "enemy", effects = { { "damage", 6 }, { "apply", "armor_broken", 3 } },
  text = "Deal 6.\nApply Sundered 3 ⌛",
  up = { effects = { { "damage", 8 }, { "apply", "armor_broken", 4 } }, text = "Deal 8.\nApply Sundered 4 ⌛" },
})

card("pummel", {
  rep = 0, name = "Pummel", cost = 0, type = "attack", rarity = "uncommon", path = "arms",
  target = "enemy", cooldown = 2, effects = { { "interrupt" }, { "damage", 3 } },
  text = "Interrupt the target's cast.\nDeal 3.\nCooldown 2.",
  up = { cooldown = 1, effects = { { "interrupt" }, { "damage", 5 } },
    text = "Interrupt the target's cast.\nDeal 5.\nCooldown 1." },
})

card("bladestorm", {
  rep = 2, name = "Bladestorm", cost = 2, type = "attack", rarity = "rare", path = "arms",
  effects = { { "damage", 4, all = true, times = 3 } },
  text = "Deal 4 to all three times.",
  up = { effects = { { "damage", 6, all = true, times = 3 } }, text = "Deal 6 to all three times." },
})

-- Deep Wounds : chaque carte Attack jouée pose un DoT (saignement) sur sa cible, ou sur tous les
-- ennemis pour une attaque sans cible.
local function deepWoundsHooks(n)
  return {
    onCardPlayed = function(c, power, inst, ctx)
      if ctx.def.type ~= "attack" then return end
      local list = (ctx.target and not ctx.target.dead) and { ctx.target } or Combat.aliveEnemies(c)
      for i = 1, #list do Combat.applyStatus(c, list[i], "pain", n, "bleed") end
    end,
  }
end

card("deep_wounds", {
  rep = 2, name = "Deep Wounds", cost = 1, type = "power", rarity = "rare", path = "arms",
  power = true, effects = {}, hooks = deepWoundsHooks(2),
  text = "Power.\nAttacks: apply DoT 2.",
  up = { hooks = deepWoundsHooks(3), text = "Power.\nAttacks: apply DoT 3." },
})

-- Fury : beaucoup de petites attaques, Strength qui monte, cartes payées en PV ---------------------

card("raging_blow", {
  rep = 0, name = "Raging Blow", cost = 1, type = "attack", rarity = "common", path = "fury",
  target = "enemy", effects = { { "damage", 5, times = 2 } },
  text = "Deal 5 twice.",
  up = { effects = { { "damage", 7, times = 2 } }, text = "Deal 7 twice." },
})

card("whirlwind", {
  rep = 0, name = "Whirlwind", cost = 1, type = "attack", rarity = "common", path = "fury",
  effects = { { "damage", 4, all = true, times = 2 } },
  text = "Deal 4 to all twice.",
  up = { effects = { { "damage", 5, all = true, times = 2 } }, text = "Deal 5 to all twice." },
})

card("victory_rush", {
  rep = 0, name = "Victory Rush", cost = 0, type = "attack", rarity = "common", path = "fury",
  target = "enemy", exhaust = true, effects = { { "damage", 4 }, { "heal", 4 } },
  text = "Deal 4.\nHeal 4.\nExhaust.",
  up = { effects = { { "damage", 6 }, { "heal", 6 } }, text = "Deal 6.\nHeal 6.\nExhaust." },
})

card("berserker_rage", {
  rep = 1, name = "Berserker Rage", cost = 0, type = "skill", rarity = "common", path = "fury",
  cooldown = 2, effects = { { "res", 1 }, { "cleanse" }, { "draw", 1 } },
  text = "+1 Rage.\nRemove negative effects.\nDraw 1.\nCooldown 2.",
  up = { effects = { { "res", 2 }, { "cleanse" }, { "draw", 1 } },
    text = "+2 Rage.\nRemove negative effects.\nDraw 1.\nCooldown 2." },
})

card("bloodthirst", {
  rep = 0, name = "Bloodthirst", cost = 1, type = "attack", rarity = "uncommon", path = "fury",
  target = "enemy", cooldown = 3,
  effects = { { "damage", 6 }, { "heal", 2 }, { "apply", "force", 1, self = true } },
  text = "Deal 6.\nHeal 2.\nGain Strength 1\nCooldown 3.",
  up = { effects = { { "damage", 8 }, { "heal", 3 }, { "apply", "force", 1, self = true } },
    text = "Deal 8.\nHeal 3.\nGain Strength 1\nCooldown 3." },
})

card("rampage", {
  rep = 0, name = "Rampage", cost = 1, type = "attack", rarity = "uncommon", path = "fury",
  target = "enemy", payHp = 3, effects = { { "damage", 4, times = 4 } },
  text = "Pay 3 HP.\nDeal 4 four times.",
  up = { effects = { { "damage", 5, times = 4 } }, text = "Pay 3 HP.\nDeal 5 four times." },
})

card("battle_shout", {
  rep = 1, name = "Battle Shout", cost = 1, type = "skill", rarity = "uncommon", path = "fury",
  exhaust = true, effects = { { "apply", "force", 2, self = true } },
  text = "Gain Strength 2\nExhaust.",
  up = { effects = { { "apply", "force", 3, self = true } }, text = "Gain Strength 3\nExhaust." },
})

card("onslaught", {
  rep = 2, name = "Onslaught", cost = 1, type = "attack", rarity = "uncommon", path = "fury",
  target = "enemy", spend = 2, effects = { { "damage", 8 }, { "draw", 2, cond = "spent" } },
  text = "Deal 8.\nSpend 2: draw 2.",
  up = { effects = { { "damage", 11 }, { "draw", 2, cond = "spent" } }, text = "Deal 11.\nSpend 2: draw 2." },
})

-- Enrage : chaque perte de PV donne Strength 1, une fois par tour (par round).
local enrageHooks = {
  onHpLost = function(c, power, n)
    local key = "enrage" .. power.uid
    if c.player.flags[key] == c.round then return end
    c.player.flags[key] = c.round
    Combat.applyStatus(c, c.player, "force", 1)
  end,
}

card("enrage", {
  rep = 0, name = "Enrage", cost = 1, type = "power", rarity = "rare", path = "fury",
  power = true, effects = {}, hooks = enrageHooks,
  text = "Power.\nHP lost: gain Strength 1, once per turn.",
  up = { cost = 0, text = "Power.\nHP lost: gain Strength 1, once per turn." },
})

card("recklessness", {
  rep = 2, name = "Recklessness", cost = 1, type = "skill", rarity = "rare", path = "fury",
  payHp = 4, exhaust = true, effects = { { "apply", "force", 3, self = true } },
  text = "Pay 4 HP.\nGain Strength 3\nExhaust.",
  up = { effects = { { "apply", "force", 4, self = true } }, text = "Pay 4 HP.\nGain Strength 4\nExhaust." },
})

-- Protection : Absorb converti en dégâts, ripostes quand il est frappé ------------------------------

card("shield_block", {
  rep = 0, name = "Shield Block", cost = 1, type = "skill", rarity = "common", path = "protection",
  cooldown = 1, effects = { { "absorb", 8 } },
  text = "Gain 8 Absorb.\nCooldown 1.",
  up = { effects = { { "absorb", 11 } }, text = "Gain 11 Absorb.\nCooldown 1." },
})

-- Revenge : coûte 0 si des PV ont été perdus au tour précédent (règle de classe, champ hurtCost).
card("revenge", {
  rep = 0, name = "Revenge", cost = 1, type = "attack", rarity = "common", path = "protection",
  target = "enemy", retain = true, hurtCost = 0, effects = { { "damage", 6 } },
  text = "Deal 6.\nCosts 0 if hit last turn.\nRetain.",
  up = { effects = { { "damage", 9 } }, text = "Deal 9.\nCosts 0 if hit last turn.\nRetain." },
})

card("thunder_clap", {
  rep = 0, name = "Thunder Clap", cost = 1, type = "attack", rarity = "common", path = "protection",
  effects = { { "damage", 4, all = true }, { "apply", "demoralized", 1, all = true } },
  text = "Deal 4 to all.\nApply Demoralized 1 ⌛ to all",
  up = { effects = { { "damage", 6, all = true }, { "apply", "demoralized", 2, all = true } },
    text = "Deal 6 to all.\nApply Demoralized 2 ⌛ to all" },
})

card("devastate", {
  rep = 0, name = "Devastate", cost = 1, type = "attack", rarity = "common", path = "protection",
  target = "enemy", effects = { { "damage", 6 }, { "absorb", 3 } },
  text = "Deal 6.\nGain 3 Absorb.",
  up = { effects = { { "damage", 8 }, { "absorb", 5 } }, text = "Deal 8.\nGain 5 Absorb." },
})

card("demoralizing_shout", {
  rep = 0, name = "Demoralizing Shout", cost = 1, type = "skill", rarity = "common", path = "protection",
  cooldown = 3, effects = { { "apply", "demoralized", 2, all = true }, { "res", 1 } },
  text = "+1 Rage.\nApply Demoralized 2 ⌛ to all\nCooldown 3.",
  up = { cost = 0, text = "+1 Rage.\nApply Demoralized 2 ⌛ to all\nCooldown 3." },
})

card("shield_slam", {
  rep = 0, name = "Shield Slam", cost = 1, type = "attack", rarity = "uncommon", path = "protection",
  target = "enemy", effects = { { "absorb", 4 }, { "damage", 0, per = { 1, "block" } } },
  text = "Gain 4 Absorb.\nDeal damage equal to Absorb.",
  up = { effects = { { "absorb", 6 }, { "damage", 0, per = { 1, "block" } } },
    text = "Gain 6 Absorb.\nDeal damage equal to Absorb." },
})

card("ignore_pain", {
  rep = 1, name = "Ignore Pain", cost = 1, type = "skill", rarity = "uncommon", path = "protection",
  minRes = 1, effects = { { "surge" }, { "absorb", 0, per = { 3, "surge" } } },
  text = "Surge: gain 3 Absorb per Rage.",
  up = { effects = { { "surge" }, { "absorb", 0, per = { 4, "surge" } } }, text = "Surge: gain 4 Absorb per Rage." },
})

-- Retaliation : chaque coup ennemi (même absorbé) renvoie des dégâts à l'attaquant.
local function retaliationHooks(n)
  return {
    afterHit = function(c, power, enemy)
      if enemy.dead or c.result then return end
      Combat.dealDamage(c, c.player, enemy, Combat.calcDamage(c, c.player, enemy, n))
    end,
  }
end

card("retaliation", {
  rep = 0, name = "Retaliation", cost = 1, type = "power", rarity = "uncommon", path = "protection",
  power = true, effects = {}, hooks = retaliationHooks(4),
  text = "Power.\nWhen hit: deal 4 to the attacker.",
  up = { hooks = retaliationHooks(6), text = "Power.\nWhen hit: deal 6 to the attacker." },
})

card("shield_wall", {
  rep = 2, name = "Shield Wall", cost = 2, type = "skill", rarity = "rare", path = "protection",
  cooldown = 3, effects = { { "absorb", 18 } },
  text = "Gain 18 Absorb.\nCooldown 3.",
  up = { effects = { { "absorb", 24 } }, text = "Gain 24 Absorb.\nCooldown 3." },
})

card("last_stand", {
  rep = 1, name = "Last Stand", cost = 1, type = "power", rarity = "rare", path = "protection",
  power = true, effects = {},
  hooks = {
    preventDeath = function(c, power)
      if not Combat.lastBreath(c, "last_stand") then return false end
      c.player.hp = 1
      Combat.heal(c, c.player, 15)
      return true
    end,
  },
  text = "Power.\nLast Breath: stay at 1 HP, heal 15.",
  up = { cost = 0, text = "Power.\nLast Breath: stay at 1 HP, heal 15." },
})

-- Bibelots du Guerrier (class = "warrior" : tirés seulement pour lui) ------------------------------

local R = ns.Relics
local function relic(id, t)
  t.id = id
  t.class = "warrior"
  t.hooks = t.hooks or {}
  R[id] = t
end

-- Bibelot de départ (GDD) : amorce la Rage dès le premier tour.
relic("battle_standard", {
  name = "Battle Standard", rarity = "common", tier = 0, noPool = true,
  text = "At the start of each combat, +1 Rage.",
  hooks = {
    onCombatStart = function(c) Combat.gainRes(c, 1, "relic") end,
  },
})

relic("diamond_flask", {
  name = "Diamond Flask", rarity = "uncommon", tier = 0,
  text = "Once per combat, upon dropping below half HP, gain Regen 5.",
  hooks = {
    onHpLost = function(c)
      local p = c.player
      if c.relicState.diamond_flask or p.hp * 2 >= p.maxHp or p.hp <= 0 then return end
      c.relicState.diamond_flask = true
      Combat.applyStatus(c, p, "regen", 5)
    end,
  },
})

relic("hand_of_justice", {
  name = "Hand of Justice", rarity = "common", tier = 0,
  text = "The third Attack played each turn draws 1 card.",
  hooks = {
    onCardCommitted = function(c, src, inst, d)
      if d.type == "attack" and c.turn.byType.attack == 3 then Combat.drawCards(c, 1) end
    end,
  },
})

relic("lionheart_helm", {
  name = "Lionheart Helm", rarity = "uncommon", tier = 1,
  text = "At the start of each combat, gain Strength 1.",
  hooks = {
    onCombatStart = function(c) Combat.applyStatus(c, c.player, "force", 1) end,
  },
})

relic("force_reactive_disk", {
  name = "Force Reactive Disk", rarity = "rare", tier = 1,
  text = "When an attack is fully absorbed, deal 4 to the attacker.",
  hooks = {
    afterHit = function(c, src, enemy, loss, absorbed)
      if loss > 0 or (absorbed or 0) <= 0 or enemy.dead then return end
      Combat.dealDamage(c, c.player, enemy, Combat.calcDamage(c, c.player, enemy, 4))
    end,
  },
})

relic("skullflame_shield", {
  name = "Skullflame Shield", rarity = "rare", tier = 2,
  text = "At the start of each turn, gain 2 Absorb per Rage.",
  hooks = {
    onTurnStart = function(c)
      local n = c.player.res or 0
      if n > 0 then Combat.gainBlock(c, c.player, 2 * n) end
    end,
  },
})

-- Classe ------------------------------------------------------------------------

ns.Classes.warrior = {
  id = "warrior", name = "Warrior", order = 2, hp = 75,
  resource = { id = "rage", cap = 5, keep = true },
  deck = {
    "strike", "strike", "strike", "strike",
    "defend", "defend", "defend", "defend",
    "heroic_strike", "bloodrage",
  },
  startRelic = "battle_standard",
  paths = { { id = "arms", name = "Arms" }, { id = "fury", name = "Fury" }, { id = "protection", name = "Protection" } },
  survival = "absorb",
  bot = {
    resValue = 8,
    -- notes des choix : premier balayage sweep=cards (reports/warrior_sweep1.txt, écart ramené à 4,5..7),
    -- vérifiées en expédition complète (le second balayage, cartes ajoutées de force au deck de départ,
    -- surcote les défenses : choisies d'après lui, les decks perdaient 14 points)
    rating = {
      rend = 7, deep_wounds = 7, execute = 7, ignore_pain = 7, bloodthirst = 7,
      victory_rush = 6.5, bladestorm = 6.5, revenge = 6.5, enrage = 6.5, pummel = 6.5,
      shield_block = 6, thunder_clap = 6, overpower = 6, last_stand = 6, shield_wall = 6,
      demoralizing_shout = 5.5, retaliation = 5.5, berserker_rage = 5.5, rampage = 5.5, slam = 5.5,
      devastate = 5.5, whirlwind = 5.5, raging_blow = 5.5, battle_shout = 5, onslaught = 5, cleave = 5,
      colossus_smash = 5, mortal_strike = 5, shield_slam = 5, recklessness = 4.5,
    },

    upgrade = { strike = 2.5, defend = 2, heroic_strike = 2.5, bloodrage = 1.5 },
    remove = { defend = 1, strike = 1.5 },
  },
}

