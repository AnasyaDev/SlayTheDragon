-- Potions : à usage unique, bues pendant son tour sans mana (Combat.usePotion).
-- Champs : name, text, rarity (common|uncommon|rare), tier (palier de la Ligue des
-- explorateurs qui la débloque), target = true si elle vise un ennemi,
-- effects = mêmes effets que les cartes (sans Expiation ni crochet onCardPlayed).
local _, ns = ...

local P = ns.Potions

local function potion(id, t)
  t.id = id
  P[id] = t
end

-- Neutre (palier 0) ---------------------------------------------------------

potion("healing_potion", {
  name = "Potion de soins", rarity = "common", tier = 0,
  effects = { { "heal", 15 } },
  text = "Soigne 15 PV.",
})

potion("mana_potion", {
  name = "Potion de mana", rarity = "common", tier = 0,
  effects = { { "mana", 2 } },
  text = "+2 mana ce tour.",
})

potion("shadow_protection", {
  name = "Potion de protection contre l'ombre", rarity = "uncommon", tier = 0,
  effects = { { "absorb", 12 } },
  text = "Gagne 12 Absorption.",
})

-- Honoré (palier 2) ---------------------------------------------------------

potion("liquid_fire", {
  name = "Feu liquide", rarity = "uncommon", tier = 2, target = true,
  effects = { { "damage", 10 }, { "apply", "pain", 3 } },
  text = "Inflige 10 à la cible et Douleur 3.",
})

potion("wisdom_elixir", {
  name = "Élixir de sagesse", rarity = "rare", tier = 2,
  effects = { { "draw", 3 }, { "cleanse" } },
  text = "Pioche 3 cartes et retire les états négatifs.",
})
