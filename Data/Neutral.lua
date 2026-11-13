-- Cartes neutres (fiche docs/cartes-neutres.md) : tirées des métiers et des objets de WoW, offertes à
-- toutes les classes, chez le marchand (emplacement « Neutral ») et dans quelques rencontres
-- seulement, jamais en récompense de combat.
-- Champs propres : pas de champ class (Card.inClass : carte commune), neutral = true, path = "neutral",
-- tier = palier commun qui la débloque (0 d'emblée, N = première victoire du compte dans la zone N ; docs/zones.md),
-- noReward = true (jamais dans X.cardPool : récompenses). Aucune ressource ni aucun état de classe :
-- Absorb, DoT, Strength, Stunned, mana, pioche, Interrupt et les mots de plaque communs seulement.
-- payHp = N : « Pay N HP. » en première ligne, coût payé au jeu, injouable s'il ferait tomber à 0 (décisions
-- communes : une seule formulation pour une perte de PV sur une carte).
-- Textes dans le langage des cartes (docs/classes.md, « Langage des cartes »), affichés en anglais.
local _, ns = ...

local Combat, Card = ns.Combat, ns.Card
local C = ns.Cards

local function card(id, t)
  t.id = id
  t.neutral = true
  t.path = "neutral"
  t.noReward = true
  C[id] = t
end

-- Disponible d'emblée (tier 0) ------------------------------------------------------------------------

card("rough_dynamite", {
  tier = 0, name = "Rough Dynamite", cost = 1, type = "attack", rarity = "common",
  exhaust = true, effects = { { "damage", 6, all = true } },
  text = "Deal 6 to all.\nExhaust.",
  up = { effects = { { "damage", 9, all = true } }, text = "Deal 9 to all.\nExhaust." },
})

card("heavy_silk_bandage", {
  tier = 0, name = "Heavy Silk Bandage", cost = 1, type = "skill", rarity = "common",
  exhaust = true, effects = { { "heal", 6 } },
  text = "Heal 6.\nExhaust.",
  up = { effects = { { "heal", 9 } }, text = "Heal 9.\nExhaust." },
})

card("rugged_armor_kit", {
  tier = 0, name = "Rugged Armor Kit", cost = 1, type = "skill", rarity = "common",
  retain = true, effects = { { "absorb", 4 } },
  text = "Gain 4 Absorb.\nRetain.",
  up = { effects = { { "absorb", 7 } }, text = "Gain 7 Absorb.\nRetain." },
})

card("smoked_desert_dumplings", {
  tier = 0, name = "Smoked Desert Dumplings", cost = 1, type = "skill", rarity = "uncommon",
  exhaust = true, effects = { { "apply", "force", 1, self = true } },
  text = "Gain Strength 1\nExhaust.",
  up = { effects = { { "apply", "force", 2, self = true } }, text = "Gain Strength 2\nExhaust." },
})

-- Westfall, zone 1 (tier 1) ------------------------------------------------------------------------

card("runecloth_bag", {
  tier = 1, name = "Runecloth Bag", cost = 1, type = "skill", rarity = "common",
  exhaust = true, effects = { { "draw", 2 } },
  text = "Draw 2.\nExhaust.",
  up = { cost = 0, text = "Draw 2.\nExhaust." },
})

card("iron_grenade", {
  tier = 1, name = "Iron Grenade", cost = 1, type = "attack", rarity = "uncommon",
  target = "enemy", exhaust = true, effects = { { "damage", 5 }, { "apply", "stunned", 1 } },
  text = "Deal 5.\nApply Stunned 1 ⌛\nExhaust.",
  up = { effects = { { "damage", 8 }, { "apply", "stunned", 1 } }, text = "Deal 8.\nApply Stunned 1 ⌛\nExhaust." },
})

-- Duskwood, zone 2 (tier 2) ------------------------------------------------------------------------

card("arcane_bomb", {
  tier = 2, name = "Arcane Bomb", cost = 0, type = "skill", rarity = "uncommon",
  target = "enemy", exhaust = true, effects = { { "interrupt" } },
  text = "Interrupt the target's cast.\nExhaust.",
  up = { effects = { { "interrupt" }, { "draw", 1 } }, text = "Interrupt the target's cast.\nDraw 1.\nExhaust." },
})

-- Power : Absorb au début de chaque tour (après DoT et Regen, Absorb remise à 0 juste avant).
local elixirHooks = {
  onTurnStart = function(c, inst)
    Combat.gainBlock(c, c.player, Card.def(inst).turnAbsorb or 3)
  end,
}

card("elixir_of_superior_defense", {
  tier = 2, name = "Elixir of Superior Defense", cost = 1, type = "power", rarity = "uncommon",
  power = true, turnAbsorb = 3, effects = {}, hooks = elixirHooks,
  text = "Power.\nStart of turn: gain 3 Absorb.",
  up = { turnAbsorb = 4, text = "Power.\nStart of turn: gain 4 Absorb." },
})

-- Wetlands, zone 3 (tier 3) ------------------------------------------------------------------------

card("black_lotus", {
  tier = 3, name = "Black Lotus", cost = 0, type = "skill", rarity = "rare",
  exhaust = true, effects = { { "mana", 2 } },
  text = "+2 mana.\nExhaust.",
  up = { effects = { { "mana", 2 }, { "draw", 1 } }, text = "+2 mana.\nDraw 1.\nExhaust." },
})

card("goblin_sapper_charge", {
  tier = 3, name = "Goblin Sapper Charge", cost = 2, type = "attack", rarity = "rare",
  exhaust = true, payHp = 5, effects = { { "damage", 14, all = true } },
  text = "Pay 5 HP.\nDeal 14 to all.\nExhaust.",
  up = { effects = { { "damage", 18, all = true } }, text = "Pay 5 HP.\nDeal 18 to all.\nExhaust." },
})

-- Conseils aux bots de simulation (Sim/run.lua les réunit avec ceux des classes) : note des cartes
-- pour les choix : 5 + écart / 2, écart moyen des cinq classes au balayage sweep=cards only=<neutres>
-- (meta=start level=7, 500 expéditions par ligne ; docs/equilibrage.md). Le bot n'achète ou ne prend
-- une carte que si sa valeur dans le deck dépasse son prix ou ce qu'il laisse.
ns.NeutralBot = {
  rating = {
    rough_dynamite = 4.5, heavy_silk_bandage = 6.5, rugged_armor_kit = 4, smoked_desert_dumplings = 4.5,
    runecloth_bag = 3.5, iron_grenade = 6.5, arcane_bomb = 4, elixir_of_superior_defense = 5.5,
    black_lotus = 6, goblin_sapper_charge = 4,
  },
}
