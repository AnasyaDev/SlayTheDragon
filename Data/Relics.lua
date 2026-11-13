-- Bibelots : effets passifs pour toute l'expédition.
-- Champs : name, text, rarity (common|uncommon|rare|boss), tier (palier commun qui le débloque : 0 d'emblée,
-- N = première victoire du compte dans la zone d'ordre N ; docs/zones.md), ou class + level (bibelot de
-- classe), ou key = { zone, level } (bibelot de clé : première victoire de la classe à +level dans la zone),
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
ns.Declare = ns.Declare or {}
ns.Declare.relic = relic -- fichiers de zone : ns.Declare.relic(id, t)

-- Disponible d'emblée (tier 0) ---------------------------------------------------------

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

-- Westfall, zone 1 (tier 1) ---------------------------------------------------------

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

-- Duskwood, zone 2 (tier 2) ---------------------------------------------------------

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

-- Wetlands, zone 3 (tier 3) ---------------------------------------------------------

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

---------------------------------------------------------------------------
-- Bibelots communs de la fiche (docs/bibelots-communs.md, 12/11/2026) : offerts à toutes les classes,
-- débloqués par les zones gagnées par le compte (tier). Aucun ne suppose un soin venant des cartes, une ressource
-- ni un état de classe. needs = genre de cartes que la classe doit avoir pour qu'il lui soit proposé
-- (Expedition.usefulFor : « cast », « castDamage », « cooldown », « exhaust », « attack », « absorb »).
-- Deux ids de la fiche étaient déjà pris par des bibelots du Guerrier (hand_of_justice,
-- force_reactive_disk) : leurs équivalents communs s'appellent Ironfoe et Gnomish Harm Prevention Belt.
-- Traveler's Backpack (garder une carte au choix en fin de tour) : crochet « retainPicks », choix posé
-- avant la fin du tour par Combat.markRetain (interface : « End Turn » puis clic sur la carte ; bots :
-- Sim/bots.lua, Bots.retainPick).
---------------------------------------------------------------------------

local Card = ns.Card

-- Disponible d'emblée (tier 0) ---------------------------------------------------------

relic("scroll_of_intellect", {
  name = "Scroll of Intellect", rarity = "common", tier = 0,
  text = "Whenever the draw pile is reshuffled, draw 1 card.",
  hooks = {
    onReshuffle = function(c, src)
      Combat.drawCards(c, 1)
    end,
  },
})

relic("bloodsail_admirals_hat", {
  name = "Bloodsail Admiral's Hat", rarity = "common", tier = 0,
  text = "Elite and boss combats give 20 more gold.",
  run = {
    -- ajout fixe, après les pourcentages (Defias Purse) : crochet goldBonus
    goldBonus = function(run, v, source)
      if source == "elite" or source == "boss" then return v + 20 end
      return v
    end,
  },
})

relic("herb_pouch", {
  name = "Herb Pouch", rarity = "common", tier = 0,
  text = "+1 potion slot.",
  run = {
    onPickup = function(run) ns.Expedition.addPotionSlot(run) end,
  },
})

relic("lifegiving_gem", {
  name = "Lifegiving Gem", rarity = "common", tier = 0,
  text = "+8 max HP.",
  run = {
    onPickup = function(run)
      run.maxHp = run.maxHp + 8
      run.hp = run.hp + 8
    end,
  },
})

-- Westfall, zone 1 (tier 1) ---------------------------------------------------------

relic("darkmoon_prize_ticket", {
  name = "Darkmoon Faire Prize Ticket", rarity = "common", tier = 1,
  text = "The first card removal at each merchant is free.",
  run = {
    removePrice = function(run, v)
      if run.phase == "merchant" and run.shop and (run.shop.removed or 0) == 0 then return 0 end
      return v
    end,
  },
})

relic("head_of_onyxia", {
  name = "Head of Onyxia", rarity = "common", tier = 1,
  text = "After each elite combat won, gain a potion.",
  run = {
    -- rien si les emplacements sont pleins (comme la potion de récompense)
    onCombatWon = function(run, kind)
      if kind ~= "elite" then return end
      local X = ns.Expedition
      local id = X.freeSlot(run) and X.randomPotion(run)
      if id then X.gainPotion(run, id) end
    end,
  },
})

relic("demonic_rune", {
  name = "Demonic Rune", rarity = "common", tier = 1, needs = "exhaust",
  text = "Whenever an Exhaust card is played, gain 3 Absorb.",
  hooks = {
    onCardPlayed = function(c, src, inst, ctx)
      if ctx and ctx.copy then return end
      if Card.def(inst).exhaust then Combat.gainBlock(c, c.player, 3) end
    end,
  },
})

relic("brilliant_mana_oil", {
  name = "Brilliant Mana Oil", rarity = "uncommon", tier = 1,
  text = "Every third turn, +1 mana.",
  hooks = {
    onTurnStart = function(c, src)
      if c.round % 3 == 0 then
        c.player.mana = c.player.mana + 1
        Combat.log(c, { t = "mana", n = 1, total = c.player.mana })
      end
    end,
  },
})

relic("talisman_of_ephemeral_power", {
  name = "Talisman of Ephemeral Power", rarity = "uncommon", tier = 1, needs = "castDamage",
  text = "Cast cards deal 3 more damage per hit.",
  hooks = {
    damage = function(c, src, v, dst, cardDef)
      if cardDef and cardDef.cast then return v + 3 end
      return v
    end,
  },
})

relic("bag_of_marbles", {
  name = "Bag of Marbles", rarity = "rare", tier = 1,
  text = "Start of each combat: apply Stunned 1 to a random enemy that can be Stunned.",
  hooks = {
    -- tirage par le flux « misc » du combat (sauvegardé, cloné)
    onCombatStart = function(c, src)
      local list = {}
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if not e.dead and not Combat.stunImmune(e) then list[#list + 1] = e end
      end
      if #list == 0 then return end
      Combat.applyStatus(c, list[ns.Rng.int(c.rng.misc, 1, #list)], "stunned", 1)
    end,
  },
})

relic("royal_seal_of_eldre_thalas", {
  name = "Royal Seal of Eldre'Thalas", rarity = "boss", tier = 1,
  text = "+1 mana each turn. Campfires heal half as much.",
  hooks = {
    maxMana = function(c, src, v) return v + 1 end,
  },
  run = {
    restFraction = function(run, v) return v * 0.5 end,
  },
})

-- Duskwood, zone 2 (tier 2) ---------------------------------------------------------

relic("philosophers_stone", {
  name = "Philosopher's Stone", rarity = "uncommon", tier = 2,
  text = "Whenever a potion is drunk, gain 6 Absorb.",
  hooks = {
    onPotion = function(c, src)
      Combat.gainBlock(c, c.player, 6)
    end,
  },
})

relic("mark_of_the_champion", {
  name = "Mark of the Champion", rarity = "uncommon", tier = 2, needs = "attack",
  text = "Attacks deal 3 more damage per hit to elites and bosses.",
  hooks = {
    damage = function(c, src, v, dst, cardDef)
      if cardDef and cardDef.type == "attack" and dst and dst.side == "enemy"
          and (dst.boss or (ns.Enemies[dst.id] and ns.Enemies[dst.id].elite)) then
        return v + 3
      end
      return v
    end,
  },
})

relic("onyxia_scale_cloak", {
  name = "Onyxia Scale Cloak", rarity = "uncommon", tier = 2,
  text = "Bosses deal 2 less damage per hit.",
  hooks = {
    enemyDamage = function(c, src, v, enemy)
      if enemy and enemy.boss then return math.max(0, v - 2) end
      return v
    end,
  },
})

relic("hourglass_sand", {
  name = "Hourglass Sand", rarity = "uncommon", tier = 2, needs = "cooldown",
  text = "Cooldown cards come back 1 turn sooner (minimum 1).",
  hooks = {
    -- durée de la recharge (le moteur la garde à 1 au moins)
    cooldown = function(c, src, v) return v - 1 end,
  },
})

relic("flint_and_tinder", {
  name = "Flint and Tinder", rarity = "rare", tier = 2,
  text = "Resting at a campfire also upgrades a random card.",
  run = {
    onRest = function(run) ns.Expedition.upgradeRandom(run, 1, run.rng.loot) end,
  },
})

relic("harm_prevention_belt", {
  name = "Gnomish Harm Prevention Belt", rarity = "rare", tier = 2, needs = "absorb",
  text = "Up to 5 Absorb carries over to the next turn.",
  hooks = {
    -- Absorb gardée au début du tour (0 par défaut)
    blockKeep = function(c, src, v) return v + 5 end,
  },
})

relic("drake_fang_talisman", {
  name = "Drake Fang Talisman", rarity = "boss", tier = 2,
  text = "At the start of each combat, gain 2 Strength. Enemies gain 6 Absorb.",
  hooks = {
    onCombatStart = function(c, src)
      Combat.applyStatus(c, c.player, "force", 2)
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if not e.dead then Combat.gainBlock(c, e, 6) end
      end
    end,
  },
})

-- Wetlands, zone 3 (tier 3) ---------------------------------------------------------

relic("ironfoe", {
  name = "Ironfoe", rarity = "rare", tier = 3, needs = "attack",
  text = "The first Attack played in each combat is played twice.",
  hooks = {
    -- la première Attack jouée (au jeu, même Cast ou Trap) est marquée ; sa résolution est doublée
    onCardCommitted = function(c, src, inst, d)
      if d.type == "attack" and not c.relicState.ironfoe_used then
        c.relicState.ironfoe_used = true
        c.relicState.ironfoe_uid = inst.uid
      end
    end,
    replay = function(c, src, v, inst, ctx)
      if c.relicState.ironfoe_uid == inst.uid and not ctx.copy then
        c.relicState.ironfoe_uid = nil
        return v + 1
      end
      return v
    end,
  },
})

relic("travelers_backpack", {
  name = "Traveler's Backpack", rarity = "rare", tier = 3,
  text = "At the end of each turn, 1 chosen card stays in hand.",
  hooks = {
    -- une carte au choix gardée en fin de tour (choix posé par Combat.markRetain : interface, bots)
    retainPicks = function(c, src, v) return v + 1 end,
  },
})

-- Bibelots d'origine liés à un genre de cartes : jamais proposés à une classe qui n'en a pas
-- (Talisman of Focus sans carte Cast : Rogue).
R.focus_talisman.needs = "cast"
