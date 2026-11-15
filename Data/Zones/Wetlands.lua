-- Zone 3 de la campagne : Wetlands (`wetlands`). Fiche : docs/zones/wetlands.md ; décisions : docs/zones/decisions.md ;
-- guide de l'agent de zone : docs/zones.md. Mécanique Pack (Core/ZoneRules/wetlands.lua) : champs libres des
-- ennemis lus par la règle de la zone :
--   pack = { "force" | "heal" | "absorb", n }  membre de la meute qui donne cette prime à sa mort ;
--   pack = true                                membre sans prime (élite, boss : reçoit, ne donne rien) ;
--   packLeader = true                          chef de meute (sa mort disperse la meute).
-- Chiffres réglés par la simulation (section « Implémentation » de la fiche).
local _, ns = ...

local Combat = ns.Combat
local E = ns.Enemies
local Declare = ns.Declare

---------------------------------------------------------------------------
-- Ennemis normaux
---------------------------------------------------------------------------

E.bluegill_raider = {
  name = "Bluegill Raider", hp = { 11, 13 }, pack = { "absorb", 3 },
  moves = {
    jab = { name = "Spear Jab", intent = "attack", actions = { { "attack", 5 } } },
    muck = { name = "Muck Toss", intent = "debuff", actions = { { "attack", 3 }, { "debuff", "demoralized", 1 } } },
  },
  pattern = { "jab", "muck" }, randomStart = true,
}

E.mosshide_brute = {
  name = "Mosshide Brute", hp = { 19, 22 }, pack = { "force", 2 },
  moves = {
    club = { name = "Club", intent = "attack", actions = { { "attack", 8 } } },
    knockdown = { name = "Knockdown", intent = "attack", actions = { { "attack", 5, interrupts = true } } },
  },
  pattern = { "club", "knockdown" }, randomStart = true,
}

-- Soigneur qui incante : Healing Wave si un allié a perdu au moins 9 PV et que son tour d'avant n'était
-- pas un soin, sinon Lightning Bolt.
E.mosshide_mystic = {
  name = "Mosshide Mystic", hp = { 15, 17 }, pack = { "heal", 6 },
  moves = {
    wave = { name = "Healing Wave", intent = "heal", actions = { { "heal_ally", 6 } } },
    bolt = { name = "Lightning Bolt", intent = "cast", cast = true, actions = { { "attack", 8 } } },
  },
  ai = function(c, e)
    if e.mem.last ~= "wave" then
      for i = 1, #c.enemies do
        local o = c.enemies[i]
        if not o.dead and o.maxHp - o.hp >= 6 then return "wave" end
      end
    end
    return "bolt"
  end,
}

-- Chef de meute : toujours à droite de son groupe (son Rally doit tenir pendant le tour du joueur).
E.mosshide_alpha = {
  name = "Mosshide Alpha", hp = { 24, 27 }, packLeader = true,
  moves = {
    rally = { name = "Rally", intent = "defend", text = "All enemies gain 4 Absorb.",
      actions = { { "block_allies", 4 } } },
    maul = { name = "Maul", intent = "attack", actions = { { "attack", 11 } } },
    howl = { name = "Savage Howl", intent = "buff", text = "All enemies gain Strength 1.",
      actions = { { "buff_allies", "force", 1 } } },
  },
  pattern = { "rally", "maul", "howl" },
}

E.mottled_screecher = {
  name = "Mottled Screecher", hp = { 13, 15 }, pack = { "force", 1 },
  moves = {
    screech = { name = "Screech", intent = "summon", cast = true, text = "Calls a Mottled Raptor.",
      actions = { { "summon", "mottled_raptor", max = 3 } } },
    claw = { name = "Claw", intent = "attack", actions = { { "attack", 3, times = 2 } } },
  },
  pattern = { "screech", "claw", "claw" },
}

E.mottled_raptor = {
  name = "Mottled Raptor", hp = { 13, 15 }, pack = { "force", 1 },
  moves = {
    rake = { name = "Rake", intent = "attack", actions = { { "attack", 3, times = 2 } } },
    lunge = { name = "Lunge", intent = "attack", actions = { { "attack", 7 } } },
  },
  pattern = { "rake", "lunge" }, randomStart = true,
}

E.dragonmaw_raider = {
  name = "Dragonmaw Raider", hp = { 24, 27 }, pack = { "force", 2 },
  moves = {
    bash = { name = "Shield Bash", intent = "attack", actions = { { "attack", 5, interrupts = true } } },
    strike = { name = "Mortal Strike", intent = "attack", actions = { { "attack", 11 }, { "debuff", "mortal_wound", 3 } } },
  },
  pattern = { "bash", "strike" }, randomStart = true,
}

-- Le solitaire : ni Pack, ni prime.
E.wetlands_crocolisk = {
  name = "Wetlands Crocolisk", hp = { 32, 36 },
  moves = {
    snap = { name = "Snap", intent = "attack", actions = { { "attack", 10 } } },
    submerge = { name = "Submerge", intent = "defend", actions = { { "block", 12 } } },
    roll = { name = "Death Roll", intent = "attack", actions = { { "attack", 4, times = 3 } } },
  },
  pattern = { "snap", "submerge", "roll" }, randomStart = true,
}

-- Limon : à sa mort, deux Black Slime (pas Pack, pas sbires).
E.black_ooze = {
  name = "Black Ooze", hp = { 22, 25 },
  moves = {
    acid = { name = "Corrosive Acid", intent = "debuff", actions = { { "attack", 5 }, { "debuff", "armor_broken", 1 } } },
    slam = { name = "Ooze Slam", intent = "attack", actions = { { "attack", 8 } } },
  },
  pattern = { "acid", "slam" },
  splits = 2, -- affichage : « Splits into 2 Black Slime when it dies. »
  onDeath = function(c, e)
    if c.result then return end
    for _ = 1, 2 do Combat.spawn(c, "black_slime", e) end
  end,
}

E.black_slime = {
  name = "Black Slime", hp = { 6, 7 },
  moves = {
    bolt = { name = "Slime Bolt", intent = "attack", actions = { { "attack", 3 } } },
  },
  pattern = { "bolt" },
}

---------------------------------------------------------------------------
-- Élites
---------------------------------------------------------------------------

-- Sarltooth : l'alpha qui grossit. Membre de la meute sans prime ; chaque Scytheclaw tué lui donne
-- Strength 2. Ses Scytheclaws s'enfuient à sa mort (sbires).
E.mottled_scytheclaw = {
  name = "Mottled Scytheclaw", hp = { 12, 14 }, minion = true, pack = { "force", 1 },
  moves = {
    slash = { name = "Slash", intent = "attack", actions = { { "attack", 5 } } },
  },
  pattern = { "slash" },
}

E.sarltooth = {
  name = "Sarltooth", hp = 66, elite = true, pack = true,
  moves = {
    call = { name = "Call the Pack", intent = "summon", text = "Calls a Mottled Scytheclaw.",
      actions = { { "summon", "mottled_scytheclaw", max = 2 } } },
    rend = { name = "Rend", intent = "attack", actions = { { "attack", 7 }, { "debuff", "pain", 3 } } },
    leap = { name = "Leap", intent = "attack", actions = { { "attack", 16, interrupts = true } } },
  },
  pattern = { "call", "rend", "leap" },
}

-- Modr : le test de rafale. Earthen Charge (état, 3 au plus) : au début de son tour, après son DoT, s'il
-- a perdu moins de 15 PV depuis son tour précédent, il gagne 1 Charge (Core/ZoneRules/wetlands.lua) ;
-- Seismic Slam : 6 + 8 par Charge, puis les Charges retombent à 0.
E.modr = {
  name = "Modr", hp = 110, elite = true, chargeAt = 15,
  moves = {
    fist = { name = "Stone Fist", intent = "attack", actions = { { "attack", 15 } } },
    slam = { name = "Seismic Slam", intent = "attack",
      text = "Deals 6, plus 8 per Earthen Charge. Charges drop to 0.",
      actions = { { "attack", 6, per = { 8, "earthen_charge" }, interrupts = true }, { "discharge" } } },
  },
  pattern = { "fist", "fist", "slam" },
}

-- Dragonmaw Centurion : l'armure de Ma'ruk Wyrmscale de la fiche (décisions du 13/11/2026 : créature
-- réelle). Wyrmscale Armor : le premier coup qu'il subit après le début de chaque tour du joueur
-- n'inflige rien (pas le DoT). Membre de la meute sans prime : la mort du Raider lui donne Strength 2.
E.dragonmaw_centurion = {
  name = "Dragonmaw Centurion", hp = 56, elite = true, pack = true, wyrmscale = 10,
  moves = {
    bash = { name = "Shield Bash", intent = "attack", actions = { { "attack", 6, interrupts = true } } },
    cleave = { name = "Cleave", intent = "attack", actions = { { "attack", 7, times = 2 }, { "debuff", "mortal_wound", 2 } } },
    shout = { name = "Demoralizing Shout", intent = "debuff", actions = { { "attack", 4 }, { "debuff", "demoralized", 2 } } },
  },
  pattern = { "bash", "cleave", "shout" },
  init = function(c, e) Combat.applyStatus(c, e, "wyrmscale", 1) end,
}

---------------------------------------------------------------------------
-- Boss : Chieftain Nek'rosh
---------------------------------------------------------------------------

E.dragonmaw_bonewarder = {
  name = "Dragonmaw Bonewarder", hp = { 13, 15 }, minion = true, pack = { "heal", 6 },
  moves = {
    ward = { name = "Bone Ward", intent = "defend", text = "Chieftain Nek'rosh gains 6 Absorb.",
      actions = { { "block_boss", 6 } } },
    bolt = { name = "Shadow Bolt", intent = "attack", actions = { { "attack", 3 } } },
  },
  pattern = { "ward", "bolt" }, randomStart = true,
}

E.crimson_whelp = {
  name = "Crimson Whelp", hp = { 8, 10 }, minion = true,
  moves = {
    breath = { name = "Fire Breath", intent = "attack", actions = { { "attack", 3 } } },
  },
  pattern = { "breath" },
}

E.nekrosh = {
  name = "Chieftain Nek'rosh", hp = 84, boss = true, pack = true,
  moves = {
    cleave = { name = "Cleave", intent = "attack", actions = { { "attack", 9, times = 2 }, { "debuff", "mortal_wound", 3 } } },
    command = { name = "Clan Command", intent = "buff", text = "All enemies gain Strength 3. Nek'rosh gains 8 Absorb.",
      actions = { { "buff_allies", "force", 3 }, { "block", 8 } } },
    sunder = { name = "Sunder Armor", intent = "attack", actions = { { "attack", 12 }, { "debuff", "armor_broken", 1 },
      { "debuff", "mortal_wound", 3 } } },
    shadow_bolt = { name = "Shadow Bolt", intent = "cast", cast = true, actions = { { "attack", 14 } } },
    whelps = { name = "Call Whelps", intent = "summon", text = "Calls 2 Crimson Whelps (4 at most).",
      actions = { { "summon", "crimson_whelp", count = 2, max = 4 } } },
  },
  pattern = { "cleave", "sunder", "command" },
  phases = {
    { at = 0.5, name = "Whelps", text = "Calls 2 Crimson Whelps. Casts Shadow Bolt (14).",
      say = "Whelps! Burn them!", enter = { { "summon", "crimson_whelp", count = 2 } },
      pattern = { "shadow_bolt", "cleave", "whelps", "sunder" } },
  },
}

---------------------------------------------------------------------------
-- Groupes
---------------------------------------------------------------------------

ns.Encounters.wetlands = {
  easy = {
    { "bluegill_raider", "bluegill_raider", "bluegill_raider" },
    { "mottled_screecher", "mottled_raptor" },
    { "wetlands_crocolisk" },
    { "black_ooze" },
  },
  normal = {
    { "mosshide_brute", "mosshide_mystic", "mosshide_alpha" },
    { "mosshide_brute", "mosshide_brute", "mosshide_mystic" },
    { "bluegill_raider", "wetlands_crocolisk", "bluegill_raider" },
    { "mottled_screecher", "mottled_raptor", "mottled_raptor" },
    { "dragonmaw_raider", "dragonmaw_raider" },
    { "dragonmaw_raider", "black_ooze" },
  },
  elite = {
    { "mottled_scytheclaw", "sarltooth" },
    { "modr" },
    { "dragonmaw_raider", "dragonmaw_centurion" },
  },
  boss = {
    { "nekrosh", "dragonmaw_bonewarder", "dragonmaw_bonewarder" },
  },
  -- Combats déclenchés par une rencontre (effet « fight »).
  event_crocolisk = { { "bluegill_raider", "wetlands_crocolisk" } },
  event_raptors = { { "mottled_screecher", "mottled_raptor", "mottled_raptor" } },
  event_mosshide = { { "mosshide_brute", "mosshide_mystic", "mosshide_alpha" } },
  event_dragonmaw = { { "dragonmaw_raider", "dragonmaw_raider" } },
  event_ooze = { { "black_ooze", "black_ooze" } },
}

---------------------------------------------------------------------------
-- Rencontres (zone = "wetlands")
---------------------------------------------------------------------------

Declare.event("halloran_skins", {
  name = "The Tanner's Order", zone = "wetlands", tier = 0,
  speaker = "James Halloran", npc = "james_halloran", scene = "coast",
  text = "\"I'm James Halloran, the tanner. My apprentice went out for giant crocolisk skins and the "
    .. "crocolisks got him first. Bring me a skin and I'll pay you for it.\"",
  choices = {
    { label = "Hunt a crocolisk", outcome = "Fight: usual reward + 25g",
      result = "You wade into the marsh after a crocolisk.",
      effects = { { "fight", "event_crocolisk", gold = 25 } } },
    { label = "Scrape hides for him", outcome = "-4 HP, +20g",
      result = "You scrape hides until evening. Halloran pays you for the day.",
      effects = { { "loseHp", 4 }, { "gold", 20 } } },
    { label = "Leave", outcome = "Nothing",
      result = "Halloran goes back to his hides.",
      effects = {} },
    { label = "Buy his crocolisk gumbo", outcome = "Pay 25g, Crocolisk Gumbo (card)",
      when = { { "unlocked", "crocolisk_gumbo", hide = true } },
      result = "\"My wife makes it with the tail meat. Eat it hot.\"",
      effects = { { "pay", 25 }, { "card", "crocolisk_gumbo" } } },
  },
})

-- Fouilles de Whelgar : décor de la colline (scene = "hill", la colline des fouilles dans les Wetlands).
Declare.event("ormers_revenge", {
  name = "Ormer's Revenge", zone = "wetlands", tier = 0,
  speaker = "Ormer Ironbraid", npc = "ormer_ironbraid", scene = "hill",
  text = "\"The raptors killed my brethren and trapped me, Merrin and the Prospector up here. "
    .. "Clear them out of the dig, or help me get the others down to the road.\"",
  choices = {
    { label = "Clear the dig site", outcome = "Fight 3 raptors: usual reward + 20g",
      result = "You go down into the dig site.",
      effects = { { "fight", "event_raptors", gold = 20 } } },
    { label = "Lead the survivors out", outcome = "-6 HP, upgrade a card of your choice",
      result = "You carry the Prospector down to the road. Ormer shows you how the diggers fight.",
      effects = { { "loseHp", 6 }, { "upgrade" } } },
    { label = "Leave", outcome = "Nothing",
      result = "Ormer stays behind the barricade.",
      effects = {} },
  },
})

Declare.event("greenwarden", {
  name = "The Greenwarden", zone = "wetlands", tier = 0,
  speaker = "Rethiel the Greenwarden", npc = "rethiel", scene = "road",
  text = "\"The Mosshide gnolls cut the trees of the Wetlands to feed their fires. Take their "
    .. "flints from them. If you are only passing through, I can tend your wounds.\"",
  choices = {
    { label = "Raid the Mosshide camp", outcome = "Fight 3 gnolls: usual reward + 30g",
      result = "You attack the Mosshide camp.",
      effects = { { "fight", "event_mosshide", gold = 30 } } },
    { label = "Let him tend your wounds", outcome = "+15 HP",
      result = "Rethiel presses wet moss on your wounds.",
      effects = { { "heal", 15 } } },
    { label = "Steal the flints at night", outcome = "50%: a potion and 25g, else -8 HP",
      effects = { { "gamble", 0.5,
        win = { { "potion" }, { "gold", 25 } },
        winText = "The gnolls are asleep. You take the flints and a potion from their supplies.",
        lose = { { "loseHp", 8 } },
        loseText = "A Mosshide Mongrel wakes up and bites you before you get away." } } },
  },
})

Declare.event("dun_modr_camp", {
  name = "Longbraid's Camp", zone = "wetlands", tier = 1,
  speaker = "Longbraid the Grim", npc = "longbraid", scene = "ruins",
  text = "\"Many of my soldiers died in the battle of Dun Modr. We hold this camp with what we "
    .. "have left. Fight with my men for a day, or share our rations.\"",
  choices = {
    { label = "Train with the soldiers", outcome = "-6 HP, upgrade 2 random cards",
      result = "You spar with the dwarves until dark.",
      effects = { { "loseHp", 6 }, { "upgradeRandom", 2 } } },
    { label = "Share their rations", outcome = "+12 HP",
      result = "You eat hard bread and salted fish with the soldiers.",
      effects = { { "heal", 12 } } },
    { label = "Buy from their quartermaster", outcome = "Pay 40g, one of 3 uncommon cards",
      result = "\"We need gold more than spare gear.\"",
      effects = { { "pay", 40 }, { "cardChoice", n = 3, rarity = "uncommon" } } },
  },
})

Declare.event("deepwater_tavern", {
  name = "The Deepwater Tavern", zone = "wetlands", tier = 0,
  speaker = "Mikhail", npc = "mikhail", scene = "coast",
  text = "\"Welcome to the Deepwater Tavern. A room is 20 gold. First Mate Fitzsimmons will tell "
    .. "you about the Third Fleet if you buy him a drink.\"",
  choices = {
    { label = "Rent a room", outcome = "Pay 20g, +16 HP",
      result = "You sleep until morning.",
      effects = { { "pay", 20 }, { "heal", 16 } } },
    { label = "Buy Fitzsimmons a drink", outcome = "Pay 15g, upgrade a random card",
      result = "Fitzsimmons tells you how the Dragonmaw boarded the Third Fleet. You note how they fight.",
      effects = { { "pay", 15 }, { "upgradeRandom", 1 } } },
    { label = "Leave", outcome = "Nothing",
      result = "Mikhail wipes the counter.",
      effects = {} },
    { label = "Buy fire oil from the fishermen", outcome = "Pay 20g, Fire Oil (card)",
      when = { { "unlocked", "fire_oil", hide = true } },
      result = "\"Firefin snapper oil. Keep it away from the fire, unless you mean it.\"",
      effects = { { "pay", 20 }, { "card", "fire_oil" } } },
  },
})

Declare.event("sida_bag", {
  name = "Sida's Bag", zone = "wetlands", tier = 1,
  speaker = "Sida", npc = "sida", scene = "road",
  text = "\"On my weekly visit to Ironbeard's Tomb, an ooze swallowed my bag. I don't know which one. "
    .. "Can you get it back for me?\"",
  choices = {
    { label = "Fight the oozes", outcome = "Fight 2 oozes: usual reward + 25g",
      result = "You walk up to the oozes at the tomb.",
      effects = { { "fight", "event_ooze", gold = 25 } } },
    { label = "Reach into the oozes", outcome = "-8 HP, +40g",
      result = "The acid burns your arms. The third ooze has the bag; Sida pays you.",
      effects = { { "loseHp", 8 }, { "gold", 40 } } },
    { label = "Leave", outcome = "Nothing",
      result = "Sida sits down on the road.",
      effects = {} },
  },
})

Declare.event("flagongut_fossil", {
  name = "The Absent-Minded Archaeologist", zone = "wetlands", tier = 1, rarity = "rare",
  speaker = "Archaeologist Flagongut", npc = "flagongut", scene = "coast",
  text = "\"Raptors attacked me on the road to Whelgar's site and I lost the Stone of Relu. Without "
    .. "it, the fossil cannot be read. Find it, or fund a second dig.\"",
  choices = {
    { label = "Search the raptor nests", outcome = "-10 HP, a relic",
      result = "You find the Stone of Relu under a nest. Flagongut gives you a find from his crates.",
      effects = { { "loseHp", 10 }, { "relic" } } },
    { label = "Fund a second dig", outcome = "Pay 40g. 50%: 100g",
      effects = { { "pay", 40 }, { "gamble", 0.5,
        win = { { "gold", 100 } },
        winText = "The diggers find a second fossil. Flagongut sells it in Ironforge and pays you back.",
        lose = {},
        loseText = "The diggers find nothing." } } },
    { label = "Decline", outcome = "Nothing",
      result = "Flagongut goes back to his notes.",
      effects = {} },
  },
})

-- Réservée aux clés hautes (comme les maraudeurs Rivepatte de Westfall).
Declare.event("stoutfist_banners", {
  name = "War Banners", zone = "wetlands", tier = 3,
  speaker = "Captain Stoutfist", npc = "stoutfist", scene = "camp",
  when = { { "key", 2 } },
  text = "\"The Dragonmaw are stockpiling weapons at the Angerfang Encampment. Burn their war "
    .. "banners, and Menethil Keep will pay for every one.\"",
  choices = {
    { label = "Raid the encampment", outcome = "Fight 2 Dragonmaw: usual reward + 35g",
      result = "You attack the Dragonmaw guarding the banners.",
      effects = { { "fight", "event_dragonmaw", gold = 35 } } },
    { label = "Take the armaments at night", outcome = "40%: a relic, else -10 HP",
      effects = { { "gamble", 0.4,
        win = { { "relic" } },
        winText = "You carry a crate out of the camp without being seen.",
        lose = { { "loseHp", 10 } },
        loseText = "A Dragonmaw Raider sees you and throws an axe." } } },
    { label = "Refuse", outcome = "Nothing",
      result = "\"Then don't get in the way of those who will.\"",
      effects = {} },
  },
})

---------------------------------------------------------------------------
-- Commun débloqué par la première victoire du compte dans les Wetlands (tier = 3)
---------------------------------------------------------------------------

Declare.neutralCard("crocolisk_gumbo", {
  fromZone = "wetlands", tier = 3, name = "Crocolisk Gumbo", cost = 1, type = "skill", rarity = "uncommon",
  exhaust = true, effects = { { "heal", 5 }, { "apply", "force", 1, self = true } },
  text = "Heal 5.\nGain Strength 1\nExhaust.",
  up = { effects = { { "heal", 8 }, { "apply", "force", 1, self = true } }, text = "Heal 8.\nGain Strength 1\nExhaust." },
  up2 = { effects = { { "heal", 10 }, { "apply", "force", 1, self = true } }, text = "Heal 10.\nGain Strength 1\nExhaust." },
  up3 = { cost = 0, text = "Heal 10.\nGain Strength 1\nExhaust." },
})

Declare.neutralCard("fire_oil", {
  fromZone = "wetlands", tier = 3, name = "Fire Oil", cost = 1, type = "skill", rarity = "common",
  exhaust = true, effects = { { "apply", "pain", 4, all = true } },
  text = "Apply DoT 4 to all\nExhaust.",
  up = { effects = { { "apply", "pain", 6, all = true } }, text = "Apply DoT 6 to all\nExhaust." },
  up2 = { effects = { { "apply", "pain", 7, all = true } }, text = "Apply DoT 7 to all\nExhaust." },
  up3 = { innate = true, text = "Apply DoT 7 to all\nExhaust.\nInnate." },
})
if ns.NeutralBot and ns.NeutralBot.rating then
  ns.NeutralBot.rating.crocolisk_gumbo = 5
  ns.NeutralBot.rating.fire_oil = 5
end

-- Crude Flint : dans l'effet en cours (des morts en chaîne comptent comme « en même temps »).
Declare.relic("crude_flint", {
  fromZone = "wetlands", name = "Crude Flint", rarity = "uncommon", tier = 3,
  text = "Whenever an enemy dies, deal 2 to all enemies.",
  hooks = {
    onEnemyDeath = function(c, src, e, info)
      if c.result then return end
      local k0, a0 = c.hitKind, c.hitAll
      c.hitKind, c.hitAll = "other", true
      local list = Combat.aliveEnemies(c)
      for i = 1, #list do
        local o = list[i]
        if not o.dead and not c.result then Combat.dealDamage(c, c.player, o, Combat.calcDamage(c, c.player, o, 2)) end
      end
      c.hitKind, c.hitAll = k0, a0
    end,
  },
})

Declare.relic("young_crocolisk_skin", {
  fromZone = "wetlands", name = "Young Crocolisk Skin", rarity = "common", tier = 3,
  text = "At the start of each combat, gain 3 Absorb per enemy.",
  hooks = {
    -- l'Absorb du joueur retombe au début de son tour : gagnée au premier tour (comme Stormwind Tabard)
    onTurnStart = function(c, src)
      if c.round ~= 1 then return end
      local n = #Combat.aliveEnemies(c)
      if n > 0 then Combat.gainBlock(c, c.player, 3 * n) end
    end,
  },
})

Declare.relic("flagonguts_fossil", {
  fromZone = "wetlands", name = "Flagongut's Fossil", rarity = "common", tier = 3,
  text = "Card rewards after elite combats offer 4 cards, not 3.",
  run = {
    rewardCards = function(exp, v, kind) if kind == "elite" then return v + 1 end return v end,
  },
})

-- Gryphon Master (Shellei Brondir) : case de parcours débloquée par la zone, dans toutes les zones.
Declare.event("gryphon_master", {
  name = "Gryphon Master", tier = 3, node = true,
  speaker = "Shellei Brondir", npc = "shellei_brondir", scene = "coast",
  text = "\"I'm Shellei Brondir, the gryphon master. A gryphon can take you past the next stretch of road "
    .. "for 30 gold. Or rest at the roost while the birds are fed.\"",
  choices = {
    { label = "Fly ahead", outcome = "Pay 30g, skip the next step",
      result = "The gryphon sets you down further along the road.",
      effects = { { "pay", 30 }, { "skipFloors", 1 } } },
    { label = "Rest at the roost", outcome = "Heal 15% of max HP",
      result = "You sleep in the straw of the roost.",
      effects = { { "healPct", 0.15 } } },
    { label = "Leave", outcome = "Nothing",
      result = "Shellei goes back to her gryphons.",
      effects = {} },
  },
})
ns.Expedition.nodeKind("gryphon_master", { name = "Gryphon Master", tier = 3, event = "gryphon_master",
  replaces = { "event" }, minFloor = 2 })

---------------------------------------------------------------------------
-- Bibelots de clé (+1, +3, +5)
---------------------------------------------------------------------------

Declare.relic("dragonmaw_war_banner", {
  fromZone = "wetlands", name = "Dragonmaw War Banner", rarity = "rare", key = { zone = "wetlands", level = 1 },
  text = "Each combat, when one of the first two enemies dies, gain Strength 1.",
  hooks = {
    onEnemyDeath = function(c, src, e)
      local n = c.relicState.war_banner or 0
      if n >= 2 or c.result then return end
      c.relicState.war_banner = n + 1
      Combat.applyStatus(c, c.player, "force", 1)
    end,
  },
})

Declare.relic("cursed_eye_of_paleth", {
  fromZone = "wetlands", name = "Cursed Eye of Paleth", rarity = "rare", key = { zone = "wetlands", level = 3 },
  text = "+1 mana per turn. Healing outside combat is halved.",
  hooks = {
    maxMana = function(c, src, v) return v + 1 end,
  },
  run = {
    healOut = function(exp, v) return v / 2 end,
  },
})

Declare.relic("goaz_stone", {
  fromZone = "wetlands", name = "Goaz Stone", rarity = "rare", key = { zone = "wetlands", level = 5 },
  text = "Start of turn: if an enemy died since the last turn, +1 mana and draw 1.",
  hooks = {
    onEnemyDeath = function(c, src) c.relicState.goaz = true end,
    onTurnStart = function(c, src)
      if not c.relicState.goaz then return end
      c.relicState.goaz = nil
      c.player.mana = c.player.mana + 1
      Combat.drawCards(c, 1)
    end,
  },
})

---------------------------------------------------------------------------
-- Décors et zone jouable (en dernier)
---------------------------------------------------------------------------

-- Décors peints de la zone (UI/Art/Zones/wetlands.lua) à la place des décors communs ; boss : « mine ».
ns.Zones.wetlands.scenes = {
  road = "wetlands_road", hill = "wetlands_hill", camp = "wetlands_camp", shop = "wetlands_shop",
  night = "wetlands_night", mine = "wetlands_gates", coast = "wetlands_coast", ruins = "wetlands_ruins",
}

ns.Zones.wetlands.encounters = "wetlands"
