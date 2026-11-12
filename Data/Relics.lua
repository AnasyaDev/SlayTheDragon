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
  name = "Cracked Hearthstone", rarity = "uncommon", tier = 0,
  text = "Once per expedition, flee a normal or elite combat, with no reward.",
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
  name = "Defias Purse", rarity = "uncommon", tier = 0,
  text = "+25% gold gained.",
  run = {
    gold = function(run, v) return floor(v * 1.25 + 0.5) end,
  },
})

relic("linen_bandage", {
  name = "Linen Bandage", rarity = "common", tier = 0,
  text = "After each combat won, heal 3 HP.",
  hooks = {
    onVictory = function(c, src)
      Combat.heal(c, c.player, 3)
    end,
  },
})

relic("stormwind_tabard", {
  name = "Stormwind Tabard", rarity = "common", tier = 0,
  text = "On the first turn of each combat, gain 5 Absorb.",
  hooks = {
    onTurnStart = function(c, src)
      if c.round == 1 then Combat.gainBlock(c, c.player, 5) end
    end,
  },
})

-- Bibelot de boss de l'acte 1 : fort, avec une contrepartie.
relic("vancleef_bandana", {
  name = "VanCleef's Red Bandana", rarity = "boss", tier = 0,
  text = "+1 mana each turn. At the start of each combat, enemies gain 2 Strength.",
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
  name = "Insignia of the Alliance", nameHorde = "Insignia of the Horde", rarity = "rare", tier = 1,
  text = "Once per combat, at the start of the turn, remove all negative effects.",
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
  name = "Coarse Sharpening Stone", rarity = "uncommon", tier = 1,
  text = "Attack cards deal 1 more damage per hit.",
  hooks = {
    damage = function(c, src, v, dst, cardDef)
      if cardDef and cardDef.type == "attack" then return v + 1 end
      return v
    end,
  },
})

-- Honoré (palier 2) ---------------------------------------------------------

relic("focus_talisman", {
  name = "Talisman of Focus", rarity = "uncommon", tier = 2,
  text = "The first interrupt suffered in each combat has no effect.",
  hooks = {
    preventInterrupt = function(c, src)
      if c.relicState.talisman_used then return false end
      c.relicState.talisman_used = true
      return true
    end,
  },
})

relic("camp_kettle", {
  name = "Camp Kettle", rarity = "common", tier = 2,
  text = "Resting at a campfire heals 10 more HP.",
  run = {
    restHeal = function(run, v) return v + 10 end,
  },
})

-- Bibelots de rencontre (noPool : jamais tirés, donnés par une rencontre précise) --------

-- La roulotte de Grisette (rencontre rare) : contre 8 PV max.
relic("harvest_cog", {
  name = "Harvest Golem Cog", rarity = "rare", tier = 0, noPool = true,
  text = "On the first turn of each combat, draw 2 more cards.",
  hooks = {
    drawPerTurn = function(c, src, v)
      if c.round == 1 then return v + 2 end
      return v
    end,
  },
})

-- Le guetteur de la Colline (suite de l'histoire de Tobin).
relic("tobin_knife", {
  name = "Tobin's Pocketknife", rarity = "rare", tier = 0, noPool = true,
  text = "At the start of each combat, apply DoT 3 to all enemies.",
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
  name = "Mana Ruby", rarity = "rare", tier = 3,
  text = "On the first turn of each combat, +1 mana.",
  hooks = {
    onTurnStart = function(c, src)
      if c.round == 1 then
        c.player.mana = c.player.mana + 1
      end
    end,
  },
})
