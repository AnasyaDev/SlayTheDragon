-- Cartes et bibelots du Guerrier (GDD des classes, docs/gdd-classes.md, section Warrior).
-- Mêmes champs que Data/Priest.lua ; règles propres (Rage) : Core/Classes/warrior.lua ; art :
-- UI/Art/warrior.lua. Chiffres calés sur le Priest à coût égal, puis réglés par la simulation
-- (luajit Sim/sim.lua ... class=warrior, docs/classes.md).
--
-- Rage (0 à 5, gardée d'un tour à l'autre) : +1 par PV perdus (coup, DoT, « Pay N HP »), +1 par carte
-- Attack jouée. Dépensée par « Spend N: » (champ spend, payé au jeu si la Rage suffit) ou « Surge: »
-- (effet surge, toute la Rage). Voies : Arms (Sundered, gros coup, Execute), Fury (petites attaques,
-- Strength, cartes payées en PV), Protection (Absorb converti en dégâts, ripostes).
--
-- level = niveau de classe qui débloque la carte ou le bibelot (Core/Meta.lua ; table du GDD, répartition
-- et raisons : docs/classes.md, « Progression par classe »). Niveau 1 : chaque voie garde son moteur
-- (Arms : Sundered, Overpower, Execute ; Fury : Strength par Battle Shout et Recklessness, PV payés ;
-- Protection : Absorb converti, Shield Slam, Ignore Pain), l'Interrupt (Pummel) et le Last Breath (Last
-- Stand). Les cartes verrouillées ouvrent des façons de jouer et pèsent plus que la moyenne du niveau 1
-- (12/11/2026 : le niveau 7 n'apportait rien de plus que le niveau 1) : zone (Cleave 2, Thunder Clap 2),
-- Strength à chaque recharge (Bloodthirst 2), Cast (Slam 4), Rage sans attaquer (Berserker Rage 4),
-- Demoralized gratuit (Demoralizing Shout 4), pioche par la Rage (Onslaught 6), gros coup (Mortal Strike 6),
-- ripostes (Retaliation 6), moteurs rares (Deep Wounds, Enrage, Shield Wall au niveau 7).
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
  level = 1, name = "Strike", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 6 } },
  text = "Deal 6.",
  up = { effects = { { "damage", 9 } }, text = "Deal 9." },
})

card("defend", {
  level = 1, name = "Defend", cost = 1, type = "skill", rarity = "basic", path = "start",
  effects = { { "absorb", 5 } },
  text = "Gain 5 Absorb.",
  up = { effects = { { "absorb", 8 } }, text = "Gain 8 Absorb." },
})

card("heroic_strike", {
  level = 1, name = "Heroic Strike", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", spend = 2, effects = { { "damage", 7, more = { { 5, "spent" } } } },
  text = "Deal 7.\nSpend 2: deal 5 more.",
  up = { effects = { { "damage", 9, more = { { 7, "spent" } } } }, text = "Deal 9.\nSpend 2: deal 7 more." },
})

card("bloodrage", {
  level = 1, name = "Bloodrage", cost = 0, type = "skill", rarity = "basic", path = "start",
  payHp = 2, effects = { { "res", 2 }, { "draw", 1 } },
  text = "Pay 2 HP.\n+2 Rage.\nDraw 1.",
  up = { effects = { { "res", 3 }, { "draw", 1 } }, text = "Pay 2 HP.\n+3 Rage.\nDraw 1." },
})

-- Arms : Sundered, puis un seul gros coup ; Execute sur les cibles entamées ---------------------

card("rend", {
  level = 1, name = "Rend", cost = 1, type = "attack", rarity = "common", path = "arms",
  target = "enemy", effects = { { "damage", 3 }, { "apply", "pain", 4, icon = "bleed" } },
  text = "Deal 3.\nApply DoT 4",
  up = { effects = { { "damage", 4 }, { "apply", "pain", 6, icon = "bleed" } }, text = "Deal 4.\nApply DoT 6" },
})

card("overpower", {
  level = 1, name = "Overpower", cost = 0, type = "attack", rarity = "common", path = "arms",
  target = "enemy", effects = { { "damage", 3, more = { { 4, "status:armor_broken" } } } },
  text = "Deal 3.\nSundered: deal 4 more.",
  up = { effects = { { "damage", 5, more = { { 5, "status:armor_broken" } } } }, text = "Deal 5.\nSundered: deal 5 more." },
})

card("slam", {
  level = 4, name = "Slam", cost = 1, type = "attack", rarity = "common", path = "arms",
  target = "enemy", cast = true, effects = { { "damage", 16 } },
  text = "Cast.\nDeal 16.",
  up = { effects = { { "damage", 20 } }, text = "Cast.\nDeal 20." },
})

card("cleave", {
  level = 2, name = "Cleave", cost = 1, type = "attack", rarity = "common", path = "arms",
  effects = { { "damage", 8, all = true } },
  text = "Deal 8 to all.",
  up = { effects = { { "damage", 11, all = true } }, text = "Deal 11 to all." },
})

card("mortal_strike", {
  level = 6, name = "Mortal Strike", cost = 2, type = "attack", rarity = "uncommon", path = "arms",
  target = "enemy", effects = { { "damage", 22 }, { "apply", "armor_broken", 2 } },
  text = "Deal 22.\nApply Sundered 2 ⌛",
  up = { effects = { { "damage", 28 }, { "apply", "armor_broken", 3 } }, text = "Deal 28.\nApply Sundered 3 ⌛" },
})

-- Execute : la Rage n'est dépensée que si la cible est entamée (condition lue à la résolution).
card("execute", {
  level = 1, name = "Execute", cost = 1, type = "attack", rarity = "uncommon", path = "arms",
  target = "enemy", effects = { { "surge", cond = "execute" }, { "damage", 5, per = { 4, "surge" } } },
  text = "Deal 5.\nExecute: Surge: deal 4 per Rage.",
  up = { effects = { { "surge", cond = "execute" }, { "damage", 7, per = { 5, "surge" } } },
    text = "Deal 7.\nExecute: Surge: deal 5 per Rage." },
})

card("colossus_smash", {
  level = 1, name = "Colossus Smash", cost = 1, type = "attack", rarity = "uncommon", path = "arms",
  target = "enemy", effects = { { "damage", 6 }, { "apply", "armor_broken", 3 } },
  text = "Deal 6.\nApply Sundered 3 ⌛",
  up = { effects = { { "damage", 8 }, { "apply", "armor_broken", 4 } }, text = "Deal 8.\nApply Sundered 4 ⌛" },
})

card("pummel", {
  level = 1, name = "Pummel", cost = 0, type = "attack", rarity = "uncommon", path = "arms",
  target = "enemy", cooldown = 2, effects = { { "interrupt" }, { "damage", 3 } },
  text = "Interrupt the target's cast.\nDeal 3.\nCooldown 2.",
  up = { cooldown = 1, effects = { { "interrupt" }, { "damage", 5 } },
    text = "Interrupt the target's cast.\nDeal 5.\nCooldown 1." },
})

card("bladestorm", {
  level = 1, name = "Bladestorm", cost = 2, type = "attack", rarity = "rare", path = "arms",
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
  level = 7, name = "Deep Wounds", cost = 1, type = "power", rarity = "rare", path = "arms",
  power = true, effects = {}, hooks = deepWoundsHooks(1),
  text = "Power.\nAttacks: apply DoT 1.",
  up = { hooks = deepWoundsHooks(2), text = "Power.\nAttacks: apply DoT 2." },
})

-- Fury : beaucoup de petites attaques, Strength qui monte, cartes payées en PV ---------------------

card("raging_blow", {
  level = 1, name = "Raging Blow", cost = 1, type = "attack", rarity = "common", path = "fury",
  target = "enemy", effects = { { "damage", 5, times = 2 } },
  text = "Deal 5 twice.",
  up = { effects = { { "damage", 7, times = 2 } }, text = "Deal 7 twice." },
})

card("whirlwind", {
  level = 1, name = "Whirlwind", cost = 1, type = "attack", rarity = "common", path = "fury",
  effects = { { "damage", 4, all = true, times = 2 } },
  text = "Deal 4 to all twice.",
  up = { effects = { { "damage", 5, all = true, times = 2 } }, text = "Deal 5 to all twice." },
})

card("victory_rush", {
  level = 1, name = "Victory Rush", cost = 0, type = "attack", rarity = "common", path = "fury",
  target = "enemy", exhaust = true, effects = { { "damage", 3 }, { "heal", 4 } },
  text = "Deal 3.\nHeal 4.\nExhaust.",
  up = { effects = { { "damage", 5 }, { "heal", 6 } }, text = "Deal 5.\nHeal 6.\nExhaust." },
})

card("berserker_rage", {
  level = 4, name = "Berserker Rage", cost = 0, type = "skill", rarity = "common", path = "fury",
  cooldown = 2, effects = { { "res", 2 }, { "cleanse" }, { "draw", 1 } },
  text = "+2 Rage.\nRemove negative effects.\nDraw 1.\nCooldown 2.",
  up = { effects = { { "res", 3 }, { "cleanse" }, { "draw", 1 } },
    text = "+3 Rage.\nRemove negative effects.\nDraw 1.\nCooldown 2." },
})

card("bloodthirst", {
  level = 2, name = "Bloodthirst", cost = 1, type = "attack", rarity = "uncommon", path = "fury",
  target = "enemy", cooldown = 4,
  effects = { { "damage", 6 }, { "heal", 2 }, { "apply", "force", 1, self = true } },
  text = "Deal 6.\nHeal 2.\nGain Strength 1\nCooldown 4.",
  up = { effects = { { "damage", 8 }, { "heal", 3 }, { "apply", "force", 1, self = true } },
    text = "Deal 8.\nHeal 3.\nGain Strength 1\nCooldown 4." },
})

card("rampage", {
  level = 1, name = "Rampage", cost = 1, type = "attack", rarity = "uncommon", path = "fury",
  target = "enemy", payHp = 3, effects = { { "damage", 4, times = 4 } },
  text = "Pay 3 HP.\nDeal 4 four times.",
  up = { effects = { { "damage", 5, times = 4 } }, text = "Pay 3 HP.\nDeal 5 four times." },
})

card("battle_shout", {
  level = 1, name = "Battle Shout", cost = 1, type = "skill", rarity = "uncommon", path = "fury",
  exhaust = true, effects = { { "apply", "force", 2, self = true } },
  text = "Gain Strength 2\nExhaust.",
  up = { effects = { { "apply", "force", 3, self = true } }, text = "Gain Strength 3\nExhaust." },
})

card("onslaught", {
  level = 6, name = "Onslaught", cost = 1, type = "attack", rarity = "uncommon", path = "fury",
  target = "enemy", spend = 2, effects = { { "damage", 10 }, { "draw", 2, cond = "spent" } },
  text = "Deal 10.\nSpend 2: draw 2.",
  up = { effects = { { "damage", 13 }, { "draw", 2, cond = "spent" } }, text = "Deal 13.\nSpend 2: draw 2." },
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
  level = 7, name = "Enrage", cost = 1, type = "power", rarity = "rare", path = "fury",
  power = true, effects = {}, hooks = enrageHooks,
  text = "Power.\nHP lost: gain Strength 1, once per turn.",
  up = { cost = 0, text = "Power.\nHP lost: gain Strength 1, once per turn." },
})

card("recklessness", {
  level = 1, name = "Recklessness", cost = 1, type = "skill", rarity = "rare", path = "fury",
  payHp = 3, exhaust = true, effects = { { "apply", "force", 3, self = true } },
  text = "Pay 3 HP.\nGain Strength 3\nExhaust.",
  up = { effects = { { "apply", "force", 4, self = true } }, text = "Pay 3 HP.\nGain Strength 4\nExhaust." },
})

-- Protection : Absorb converti en dégâts, ripostes quand il est frappé ------------------------------

card("shield_block", {
  level = 1, name = "Shield Block", cost = 1, type = "skill", rarity = "common", path = "protection",
  cooldown = 1, effects = { { "absorb", 8 } },
  text = "Gain 8 Absorb.\nCooldown 1.",
  up = { effects = { { "absorb", 11 } }, text = "Gain 11 Absorb.\nCooldown 1." },
})

-- Revenge : coûte 0 si des PV ont été perdus au tour précédent (règle de classe, champ hurtCost).
card("revenge", {
  level = 1, name = "Revenge", cost = 1, type = "attack", rarity = "common", path = "protection",
  target = "enemy", retain = true, hurtCost = 0, effects = { { "damage", 6 } },
  text = "Deal 6.\nCosts 0 if hit last turn.\nRetain.",
  up = { effects = { { "damage", 9 } }, text = "Deal 9.\nCosts 0 if hit last turn.\nRetain." },
})

card("thunder_clap", {
  level = 2, name = "Thunder Clap", cost = 1, type = "attack", rarity = "common", path = "protection",
  effects = { { "damage", 3, all = true }, { "apply", "demoralized", 1, all = true } },
  text = "Deal 3 to all.\nApply Demoralized 1 ⌛ to all",
  up = { effects = { { "damage", 5, all = true }, { "apply", "demoralized", 2, all = true } },
    text = "Deal 5 to all.\nApply Demoralized 2 ⌛ to all" },
})

card("devastate", {
  level = 1, name = "Devastate", cost = 1, type = "attack", rarity = "common", path = "protection",
  target = "enemy", effects = { { "damage", 7 }, { "absorb", 3 } },
  text = "Deal 7.\nGain 3 Absorb.",
  up = { effects = { { "damage", 10 }, { "absorb", 5 } }, text = "Deal 10.\nGain 5 Absorb." },
})

card("demoralizing_shout", {
  level = 4, name = "Demoralizing Shout", cost = 0, type = "skill", rarity = "common", path = "protection",
  cooldown = 4, effects = { { "apply", "demoralized", 2, all = true }, { "res", 1 } },
  text = "+1 Rage.\nApply Demoralized 2 ⌛ to all\nCooldown 4.",
  up = { cooldown = 3, text = "+1 Rage.\nApply Demoralized 2 ⌛ to all\nCooldown 3." },
})

card("shield_slam", {
  level = 1, name = "Shield Slam", cost = 1, type = "attack", rarity = "uncommon", path = "protection",
  target = "enemy", effects = { { "absorb", 4 }, { "damage", 0, per = { 1, "block" } } },
  text = "Gain 4 Absorb.\nDeal damage equal to Absorb.",
  up = { effects = { { "absorb", 6 }, { "damage", 0, per = { 1, "block" } } },
    text = "Gain 6 Absorb.\nDeal damage equal to Absorb." },
})

card("ignore_pain", {
  level = 1, name = "Ignore Pain", cost = 1, type = "skill", rarity = "uncommon", path = "protection",
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
  level = 6, name = "Retaliation", cost = 1, type = "power", rarity = "uncommon", path = "protection",
  power = true, effects = {}, hooks = retaliationHooks(4),
  text = "Power.\nWhen hit: deal 4 to the attacker.",
  up = { hooks = retaliationHooks(6), text = "Power.\nWhen hit: deal 6 to the attacker." },
})

card("shield_wall", {
  level = 7, name = "Shield Wall", cost = 2, type = "skill", rarity = "rare", path = "protection",
  cooldown = 3, effects = { { "absorb", 18 } },
  text = "Gain 18 Absorb.\nCooldown 3.",
  up = { effects = { { "absorb", 24 } }, text = "Gain 24 Absorb.\nCooldown 3." },
})

card("last_stand", {
  level = 1, name = "Last Stand", cost = 1, type = "power", rarity = "rare", path = "protection",
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

-- Cartes épiques (cartes de zone, docs/zones/cartes-de-zone.md, « Warrior ») ------------------------------
-- Une par zone, débloquée par la première victoire du Guerrier dans la zone ; une seule par expédition.
-- Règle active dès le début de chaque combat (ni piochée, ni jouée, sans coût) : les crochets (deckHooks,
-- whileInDeck) et les nombres (ns.Warrior.EPIC) sont posés par Core/Classes/warrior.lua ; les textes ici
-- disent ces nombres. « Epic. » = mot de plaque (en tête, retiré à l'affichage comme « Power. »).
local function epic(id, t)
  t.type, t.power, t.epic, t.rarity, t.effects, t.cost = "power", true, true, "epic", {}, 0 -- coût jamais payé ni affiché
  card(id, t)
end

epic("death_wish", {
  zone = "westfall", name = "Death Wish", path = "fury",
  text = "Epic.\nCan't gain Absorb.\nAttacks: 50% more damage.",
  up = { text = "Epic.\nCan't gain Absorb.\nAttacks: 50% more damage.\nKills: heal 3." },
})

epic("thunderous_roar", {
  zone = "duskwood", name = "Thunderous Roar", path = "protection",
  text = "Epic.\nAt 5 Rage: spend it, deal 3 to all.",
  up = { text = "Epic.\nAt 5 Rage: spend it, deal 4 to all.\nAt 5 Rage: apply Demoralized 1 ⌛ to all" },
})

epic("sweeping_strikes", {
  zone = "wetlands", name = "Sweeping Strikes", path = "arms",
  text = "Epic.\nTargeted Attack hits: also hit another enemy for half.",
  up = { text = "Epic.\nTargeted Attack hits: also hit 2 other enemies for half." },
})

epic("titans_grip", {
  zone = "stranglethorn", name = "Titan's Grip", path = "fury",
  text = "Epic.\nAttacks: cost 1 more, resolve twice.\nAt most 2 per turn.",
  up = { text = "Epic.\nAttacks: cost 1 more, resolve twice.\nAt most 2 per turn, 0-cost free." },
})

epic("shield_charge", {
  zone = "swamp", name = "Shield Charge", path = "protection",
  text = "Epic.\nEnd of turn: deal a quarter of the Absorb to the last target.",
  up = { text = "Epic.\nEnd of turn: deal 4 + a quarter of the Absorb to the last target." },
})

epic("anger_management", {
  zone = "steppes", name = "Anger Management", path = "arms",
  text = "Epic.\nSpend and Surge cards: Cooldown 1.\nEach Rage spent: all Cooldowns −1.",
  up = { text = "Epic.\nSpend and Surge cards: Cooldown 1.\nEach Rage spent: all Cooldowns −2." },
})

epic("avatar", {
  zone = "blackrock", name = "Avatar", path = "arms",
  text = "Epic.\nRage up to 10.\nStart of turn: +2 Rage.\nAt 10 Rage: Attacks deal 1 more.",
  up = { text = "Epic.\nRage up to 10.\nStart of turn: +3 Rage.\nAt 10 Rage: Attacks deal 1 more." },
})

-- Bibelots du Guerrier (class = "warrior" : tirés seulement pour lui) ------------------------------
-- level = niveau de classe qui les débloque (dans la réserve de la classe ; la Ligue ne compte pas).

local R = ns.Relics
local function relic(id, t)
  t.id = id
  t.class = "warrior"
  t.hooks = t.hooks or {}
  R[id] = t
end

-- Bibelot de départ (GDD) : amorce la Rage dès le premier tour.
relic("battle_standard", {
  level = 1, name = "Battle Standard", rarity = "common", noPool = true,
  text = "At the start of each combat, +1 Rage.",
  hooks = {
    onCombatStart = function(c) Combat.gainRes(c, 1, "relic") end,
  },
})

relic("diamond_flask", {
  level = 3, name = "Diamond Flask", rarity = "uncommon",
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
  level = 1, name = "Hand of Justice", rarity = "common",
  text = "The third Attack played each turn draws 1 card.",
  hooks = {
    onCardCommitted = function(c, src, inst, d)
      if d.type == "attack" and c.turn.byType.attack == 3 then Combat.drawCards(c, 1) end
    end,
  },
})

relic("lionheart_helm", {
  level = 5, name = "Lionheart Helm", rarity = "uncommon",
  text = "At the start of each combat, gain Strength 1.",
  hooks = {
    onCombatStart = function(c) Combat.applyStatus(c, c.player, "force", 1) end,
  },
})

relic("force_reactive_disk", {
  level = 7, name = "Force Reactive Disk", rarity = "rare",
  text = "When an attack is fully absorbed, deal 4 to the attacker.",
  hooks = {
    afterHit = function(c, src, enemy, loss, absorbed)
      if loss > 0 or (absorbed or 0) <= 0 or enemy.dead then return end
      Combat.dealDamage(c, c.player, enemy, Combat.calcDamage(c, c.player, enemy, 4))
    end,
  },
})

relic("skullflame_shield", {
  level = 7, name = "Skullflame Shield", rarity = "rare",
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
  id = "warrior", name = "Warrior", order = 2, hp = 74,
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
    -- notes des choix : 5 + écart / 2 du balayage sweep=cards (meta=start level=7, 500 expéditions par ligne),
    -- vérifiées en expédition complète (méthode : docs/equilibrage.md, « Notes des cartes du bot »)
    -- (rebalayé le 12/11/2026 après la nouvelle répartition par niveau, PV 77, base 76 %)
    rating = {
      bloodthirst = 12.5, shield_slam = 12, mortal_strike = 11, revenge = 11, battle_shout = 10.5,
      demoralizing_shout = 10.5, ignore_pain = 10.5, whirlwind = 10.5, execute = 10, pummel = 10, rend = 10,
      deep_wounds = 9.5, onslaught = 9.5, retaliation = 9.5, shield_block = 9.5, victory_rush = 9.5,
      bladestorm = 9, cleave = 9, enrage = 9, last_stand = 9, rampage = 9, shield_wall = 9, slam = 9,
      thunder_clap = 9, recklessness = 8.5, devastate = 8, raging_blow = 8, overpower = 7.5,
      berserker_rage = 7, colossus_smash = 7,
    },

    upgrade = { strike = 2.5, defend = 2, heroic_strike = 2.5, bloodrage = 1.5 },
    remove = { defend = 1, strike = 1.5 },
  },
}

-- Bots : construire autour de l'épique du deck (docs/zones/cartes-de-zone.md, « Deck piloté » de chaque
-- épique). Notes absolues qui remplacent celles de bot.rating tant que l'épique est dans le deck (centrales
-- relevées, mauvaises sous 5 : jamais prises), valeurs d'amélioration (feu de camp) et de retrait (marchand,
-- rencontres : les plus basses partent d'abord, à 1,5 ou moins chez le marchand). L'épique elle-même ne part
-- jamais (retrait 99) ; son amélioration vaut ce que la règle y gagne.
local ADVICE = {
  death_wish = {
    rating = { bloodthirst = 13.5, victory_rush = 11.5, raging_blow = 10.5, whirlwind = 12, rampage = 11.5,
      battle_shout = 12, recklessness = 10.5, enrage = 11, mortal_strike = 12.5, execute = 11, bladestorm = 11,
      cleave = 10, slam = 10.5, rend = 10.5, onslaught = 10.5, overpower = 9, colossus_smash = 9, revenge = 11.5,
      thunder_clap = 9.5, deep_wounds = 10.5, demoralizing_shout = 11, last_stand = 10.5, devastate = 8,
      shield_block = 2, shield_wall = 2, ignore_pain = 2, shield_slam = 2.5 },
    upgrade = { heroic_strike = 12, bloodthirst = 13, strike = 5, defend = 0, death_wish = 11 },
    remove = { defend = 0, shield_block = 0.5, shield_wall = 0.5, ignore_pain = 0.5, shield_slam = 0.5,
      strike = 3, death_wish = 99 },
  },
  thunderous_roar = {
    rating = { bloodrage = 11, berserker_rage = 12, demoralizing_shout = 12, revenge = 12, overpower = 10.5,
      victory_rush = 11, rampage = 11, raging_blow = 10, thunder_clap = 11, battle_shout = 11.5, enrage = 11,
      whirlwind = 11, cleave = 9.5, bladestorm = 9.5, pummel = 10.5, rend = 10, bloodthirst = 12,
      execute = 4, ignore_pain = 4, onslaught = 4.5, shield_wall = 7, shield_block = 7 },
    upgrade = { thunderous_roar = 14, bloodrage = 11, heroic_strike = 1, defend = 1.5 },
    remove = { heroic_strike = 0.5, defend = 1.2, execute = 1, ignore_pain = 1, onslaught = 1.5, strike = 3,
      thunderous_roar = 99 },
  },
  sweeping_strikes = {
    rating = { mortal_strike = 12.5, execute = 11.5, raging_blow = 10.5, rampage = 11, overpower = 9,
      colossus_smash = 9.5, slam = 10.5, bloodthirst = 13, onslaught = 10.5, revenge = 11.5, rend = 10,
      cleave = 4, whirlwind = 4.5, bladestorm = 5, thunder_clap = 4.5 },
    upgrade = { heroic_strike = 11, sweeping_strikes = 10, strike = 3.5, mortal_strike = 12 },
    remove = { defend = 1, strike = 2.5, cleave = 1, whirlwind = 1.2, thunder_clap = 1.2, sweeping_strikes = 99 },
  },
  titans_grip = {
    -- chaque Attack coûte 1 de plus et frappe deux fois : les Attacks à 0 (1 pour deux coups) et celles qui
    -- comptent double (Strength, Sundered, Spend, pioche) montent ; les Skills gardent le mana du tour
    rating = { mortal_strike = 13, rampage = 12, bladestorm = 11.5, execute = 11.5, onslaught = 11.5,
      bloodthirst = 13.5, battle_shout = 12, recklessness = 11, colossus_smash = 10.5, slam = 10, whirlwind = 10.5,
      cleave = 9.5, shield_block = 10.5, shield_wall = 10, ignore_pain = 11, demoralizing_shout = 11.5,
      berserker_rage = 10.5, last_stand = 10, overpower = 11, revenge = 11, pummel = 10.5, victory_rush = 10.5,
      raging_blow = 9, enrage = 11, deep_wounds = 11.5 },
    upgrade = { titans_grip = 12, mortal_strike = 13, bloodthirst = 13, heroic_strike = 11, overpower = 10,
      strike = 2 },
    remove = { strike = 1, defend = 2, titans_grip = 99 },
  },
  shield_charge = {
    rating = { shield_block = 12.5, shield_wall = 13, ignore_pain = 12.5, devastate = 11, shield_slam = 13,
      last_stand = 10.5, demoralizing_shout = 11, thunder_clap = 9.5, bloodrage = 9, berserker_rage = 9,
      revenge = 10, retaliation = 10, rampage = 3, recklessness = 3, raging_blow = 5, whirlwind = 7 },
    upgrade = { defend = 9, shield_block = 12, shield_charge = 11, shield_wall = 11.5, ignore_pain = 11,
      strike = 1 },
    remove = { strike = 0, rampage = 0.5, recklessness = 0.5, defend = 4, shield_charge = 99 },
  },
  anger_management = {
    -- les cartes fortes sans recharge gardent leur rang (Deep Wounds, Enrage, Bladestorm relevées d'autant que
    -- les cartes centrales ; Battle Shout, Recklessness, Victory Rush ne sont plus écartées : 15/11/2026)
    rating = { bloodthirst = 14, shield_wall = 11.5, shield_block = 11, berserker_rage = 11, demoralizing_shout = 12,
      pummel = 11, onslaught = 11.5, execute = 11, ignore_pain = 11.5, mortal_strike = 11, bladestorm = 10.5,
      deep_wounds = 11, enrage = 10.5 },
    upgrade = { anger_management = 12, bloodthirst = 13, onslaught = 11, heroic_strike = 10, bloodrage = 8 },
    remove = { strike = 1, defend = 1.2, victory_rush = 1.5, anger_management = 99 },
  },
  avatar = {
    -- la Rage abonde : il faut de quoi la dépenser (Execute, Ignore Pain, puis Onslaught et Heroic Strike,
    -- seules dépenses du deck de départ) ; Bloodrage et Berserker Rage n'apportent presque plus rien
    rating = { execute = 13.5, ignore_pain = 13, colossus_smash = 10.5, mortal_strike = 12, rend = 10,
      demoralizing_shout = 11, shield_slam = 11, onslaught = 12, bloodrage = 5, berserker_rage = 6 },
    upgrade = { execute = 13, avatar = 12, ignore_pain = 12, heroic_strike = 11, onslaught = 10, bloodrage = 1,
      strike = 2 },
    remove = { bloodrage = 1, strike = 1.2, defend = 2, heroic_strike = 4, avatar = 99 },
  },
}

-- Conseils lus par Sim/expedition.lua tant que l'épique est dans le deck (classDef.bot.byEpic, priment sur
-- rating / upgrade / remove de la classe).
ns.Classes.warrior.bot.byEpic = ADVICE

-- Épique du deck d'une expédition (id) ou nil.
local function deckEpic(exp)
  for i = 1, #exp.deck do
    local d = C[exp.deck[i].id]
    if d and d.rarity == "epic" then return exp.deck[i].id end
  end
  return nil
end

-- Note d'une épique proposée (offre, marchand) : une note commune, plus l'accord avec le deck (cartes
-- centrales présentes, cartes mauvaises sous sa règle), plus un attachement à celle du deck (le build est
-- déjà construit autour). Une épique de même note n'en remplace jamais une autre.
ns.Classes.warrior.bot.EPIC_BASE = 10
ns.Classes.warrior.bot.epic = function(exp, id)
  local adv = ADVICE[id]
  if not adv then return nil end
  local v = ns.Classes.warrior.bot.EPIC_BASE
  for i = 1, #exp.deck do
    local r = adv.rating[exp.deck[i].id]
    if r and r >= 10.5 then v = v + 0.25 elseif r and r < 5 then v = v - 0.4 end
  end
  if deckEpic(exp) == id then v = v + 1.5 end
  return v
end

