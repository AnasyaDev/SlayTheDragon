-- Bibelots : effets passifs pour toute l'expédition.
-- Champs : name, text, rarity (common|uncommon|rare|boss), tier (palier de la Ligue des
-- explorateurs qui le débloque : 0 Neutre, 1 Amical, 2 Honoré, 3 Révéré),
-- hooks = crochets de combat (comme les pouvoirs ; src = id du bibelot),
-- run = crochets d'expédition appelés par la couche expédition :
--   gold(run, v) -> v, restHeal(run, v) -> v, onPickup(run).
-- État : c.relicState[clé] dure un combat ; c.charges[clé] dure toute l'expédition
-- (la couche expédition le passe à Combat.new via opts.charges et le relit après).
local _, ns = ...

local Combat = ns.Combat
local R = ns.Relics
local floor = math.floor

local function relic(id, t)
  t.id = id
  t.hooks = t.hooks or {}
  R[id] = t
end

-- Neutre (palier 0) ---------------------------------------------------------

relic("hearthstone", {
  name = "Pierre de foyer fêlée", rarity = "uncommon", tier = 0,
  text = "Une fois par expédition, permet de fuir un combat normal ou d'élite, sans récompense.",
  hooks = {
    canFlee = function(c, src, v)
      if c.charges.hearthstone_used then return v end
      return true
    end,
    onFlee = function(c, src)
      c.charges.hearthstone_used = true
    end,
  },
})

relic("defias_purse", {
  name = "Bourse défias", rarity = "uncommon", tier = 0,
  text = "+25 % d'or gagné.",
  run = {
    gold = function(run, v) return floor(v * 1.25 + 0.5) end,
  },
})

relic("linen_bandage", {
  name = "Bandage en lin", rarity = "common", tier = 0,
  text = "À la fin de chaque combat gagné, soigne 3 PV.",
  hooks = {
    onVictory = function(c, src)
      Combat.heal(c, c.player, 3)
    end,
  },
})

relic("stormwind_tabard", {
  name = "Tabard de Hurlevent", rarity = "common", tier = 0,
  text = "Au premier tour de chaque combat, gagne 5 Absorption.",
  hooks = {
    onTurnStart = function(c, src)
      if c.round == 1 then Combat.gainBlock(c, c.player, 5) end
    end,
  },
})

-- Bibelot de boss de l'acte 1 : fort, avec une contrepartie.
relic("vancleef_bandana", {
  name = "Bandeau rouge de VanCleef", rarity = "boss", tier = 0,
  text = "+1 mana à chaque tour. Au début de chaque combat, les ennemis gagnent 2 Force.",
  hooks = {
    maxMana = function(c, src, v) return v + 1 end,
    onCombatStart = function(c, src)
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if not e.dead then Combat.applyStatus(c, e, "force", 2) end
      end
    end,
  },
})

-- Amical (palier 1) ---------------------------------------------------------

relic("faction_insignia", {
  name = "Insigne de l'Alliance", nameHorde = "Insigne de la Horde", rarity = "rare", tier = 1,
  text = "Une fois par combat, au début du tour, retire tous les états négatifs.",
  hooks = {
    onTurnStart = function(c, src)
      if c.relicState.insignia_used then return end
      if Combat.hasDebuff(c.player) then
        c.relicState.insignia_used = true
        Combat.cleanse(c, c.player)
      end
    end,
  },
})

relic("sharpening_stone", {
  name = "Pierre à aiguiser grossière", rarity = "uncommon", tier = 1,
  text = "Les cartes d'attaque infligent 1 de plus par coup.",
  hooks = {
    damage = function(c, src, v, dst, cardDef)
      if cardDef and cardDef.type == "attack" then return v + 1 end
      return v
    end,
  },
})

-- Honoré (palier 2) ---------------------------------------------------------

relic("focus_talisman", {
  name = "Talisman de concentration", rarity = "uncommon", tier = 2,
  text = "La première interruption subie, à chaque combat, est sans effet.",
  hooks = {
    preventInterrupt = function(c, src)
      if c.relicState.talisman_used then return false end
      c.relicState.talisman_used = true
      return true
    end,
  },
})

relic("camp_kettle", {
  name = "Marmite de campagne", rarity = "common", tier = 2,
  text = "Se reposer au feu de camp soigne 10 PV de plus.",
  run = {
    restHeal = function(run, v) return v + 10 end,
  },
})

-- Bibelots de rencontre (noPool : jamais tirés, donnés par une rencontre précise) --------

-- La roulotte de Grisette (rencontre rare) : contre 8 PV max.
relic("harvest_cog", {
  name = "Engrenage de moissonneur", rarity = "rare", tier = 0, noPool = true,
  text = "Au premier tour de chaque combat, pioche 2 cartes de plus.",
  hooks = {
    drawPerTurn = function(c, src, v)
      if c.round == 1 then return v + 2 end
      return v
    end,
  },
})

-- Le guetteur de la Colline (suite de l'histoire de Tobin).
relic("tobin_knife", {
  name = "Canif de Tobin", rarity = "rare", tier = 0, noPool = true,
  text = "Au début de chaque combat, inflige Douleur 3 à tous les ennemis.",
  hooks = {
    onCombatStart = function(c, src)
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if not e.dead then Combat.applyStatus(c, e, "pain", 3) end
      end
    end,
  },
})

-- Révéré (palier 3) ---------------------------------------------------------

relic("mana_ruby", {
  name = "Rubis de mana", rarity = "rare", tier = 3,
  text = "Au premier tour de chaque combat, +1 mana.",
  hooks = {
    onTurnStart = function(c, src)
      if c.round == 1 then
        c.player.mana = c.player.mana + 1
      end
    end,
  },
})
