-- Potions : à usage unique, bues pendant son tour sans mana (Combat.usePotion).
-- Champs : name, text, rarity (common|uncommon|rare), tier (palier commun
-- qui la débloque : 0 d'emblée, N = première victoire du compte dans la zone N), target = true si elle vise un ennemi,
-- effects = mêmes effets que les cartes (sans Expiation ni crochet onCardPlayed).
local _, ns = ...

local P = ns.Potions

local function potion(id, t)
  t.id = id
  P[id] = t
end
ns.Declare = ns.Declare or {}
ns.Declare.potion = potion -- fichiers de zone : ns.Declare.potion(id, t)

-- Disponible d'emblée (tier 0) ---------------------------------------------------------

potion("healing_potion", {
  name = "Healing Potion", rarity = "common", tier = 0,
  effects = { { "heal", 15 } },
  text = "Heal 15 HP.",
})

potion("mana_potion", {
  name = "Mana Potion", rarity = "common", tier = 0,
  effects = { { "mana", 2 } },
  text = "+2 mana this turn.",
})

potion("shadow_protection", {
  name = "Shadow Protection Potion", rarity = "uncommon", tier = 0,
  effects = { { "absorb", 12 } },
  text = "Gain 12 Absorb.",
})

-- Duskwood, zone 2 (tier 2) ---------------------------------------------------------

potion("liquid_fire", {
  name = "Liquid Fire", rarity = "uncommon", tier = 2, target = true,
  effects = { { "damage", 10 }, { "apply", "pain", 3 } },
  text = "Deal 10 to the target and apply DoT 3.",
})

potion("wisdom_elixir", {
  name = "Elixir of Wisdom", rarity = "rare", tier = 2,
  effects = { { "draw", 3 }, { "cleanse" } },
  text = "Draw 3 cards and remove negative effects.",
})
