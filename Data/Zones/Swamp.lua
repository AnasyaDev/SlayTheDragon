-- Zone 5 de la campagne : Swamp of Sorrows (`swamp`). Fiche : docs/zones/swamp.md ; décisions :
-- docs/zones/decisions.md ; guide de l'agent de zone : docs/zones.md. Mécanique (Slumber : dormeurs, réveil,
-- Rude Awakening) : Core/ZoneRules/swamp.lua ; art et vue : UI/Art/Zones/swamp.lua.
-- Champs libres des ennemis lus par la règle : asleep = N (dort au début du combat), opener = move joué au
-- réveil ; phases[k].dream = actions jouées après l'effet qui a fait franchir le seuil (Slumber).
-- Chiffres : fiche (Westfall × 1,48), puis réglés par la simulation (section « Implémentation » de la fiche).
local _, ns = ...

local Combat, Card = ns.Combat, ns.Card
local E = ns.Enemies
local D = ns.Declare

---------------------------------------------------------------------------
-- Ennemis normaux
---------------------------------------------------------------------------

E.sawtooth_crocolisk = {
  name = "Sawtooth Crocolisk", hp = { 37, 42 }, asleep = 2, opener = "death_roll",
  moves = {
    death_roll = { name = "Death Roll", intent = "attack", actions = { { "attack", 10, times = 2 } } },
    snap = { name = "Snap", intent = "attack", actions = { { "attack", 10 } } },
    submerge = { name = "Submerge", intent = "defend", actions = { { "block", 7 } } },
  },
  pattern = { "snap", "submerge" },
}

E.dreaming_whelp = {
  name = "Dreaming Whelp", hp = { 15, 16 }, asleep = 2, opener = "dream_breath",
  moves = {
    dream_breath = { name = "Dream Breath", intent = "attack", actions = { { "attack", 10 } } },
    bite = { name = "Bite", intent = "attack", actions = { { "attack", 4 } } },
  },
  pattern = { "bite" },
}

E.swampwalker = {
  name = "Swampwalker", hp = { 45, 49 }, asleep = 3, opener = "bog_crush",
  moves = {
    bog_crush = { name = "Bog Crush", intent = "attack", actions = { { "attack", 22, interrupts = true } } },
    lash = { name = "Vine Lash", intent = "attack", actions = { { "attack", 7 } } },
    shield = { name = "Bog Shield", intent = "defend", actions = { { "block", 6 }, { "block_wounded", 6 } } },
  },
  pattern = { "lash", "shield" },
}

E.green_scalebane = {
  name = "Green Scalebane", hp = { 42, 45 }, asleep = 2, opener = "cleave",
  moves = {
    cleave = { name = "Cleave", intent = "attack", actions = { { "attack", 23 } } },
    strike = { name = "Strike", intent = "attack", actions = { { "attack", 10 } } },
    guard = { name = "Scale Guard", intent = "defend", actions = { { "block", 10 }, { "buff", "force", 1 } } },
  },
  pattern = { "strike", "guard" },
}

-- Lull si un allié éveillé valable (au moins 8 PV perdus, jamais rendormi) existe et que le tour d'avant
-- n'était pas Lull ; sinon Dream Bolt (+3 par allié endormi, +9 au plus).
E.wyrmkin_dreamwalker = {
  name = "Wyrmkin Dreamwalker", hp = { 28, 31 },
  moves = {
    lull = { name = "Lull", intent = "lull", cast = true, actions = { { "lull", 2, heal = 8 } } },
    bolt = { name = "Dream Bolt", intent = "attack",
      actions = { { "attack", 4, per = { 3, "asleepAllies" }, cap = 9 } } },
  },
  ai = function(c, e)
    if e.mem.last ~= "lull" and ns.Swamp.lullTarget(c, e) then return "lull" end
    return "bolt"
  end,
}

-- Alarm Cry si un allié dort et que le tour d'avant n'était pas Alarm Cry ; sinon Lightning Bolt.
E.marsh_oracle = {
  name = "Marsh Oracle", hp = { 23, 25 },
  moves = {
    alarm_cry = { name = "Alarm Cry", intent = "alarm", cast = true, actions = { { "alarm" } } },
    bolt = { name = "Lightning Bolt", intent = "attack", actions = { { "attack", 7 } } },
  },
  ai = function(c, e)
    if e.mem.last ~= "alarm_cry" and ns.Swamp.asleepAllies(c, e) > 0 then return "alarm_cry" end
    return "bolt"
  end,
}

E.deathstrike_tarantula = {
  name = "Deathstrike Tarantula", hp = { 28, 31 },
  moves = {
    bite = { name = "Venomous Bite", intent = "attack", actions = { { "attack", 5 }, { "debuff", "pain", 3 } } },
    web = { name = "Web", intent = "debuff", actions = { { "attack", 4 }, { "debuff", "demoralized", 1 } } },
  },
  pattern = { "bite", "web" }, randomStart = true,
}

E.marsh_inkspewer = {
  name = "Marsh Inkspewer", hp = { 15, 17 },
  moves = {
    claw = { name = "Claw", intent = "attack", actions = { { "attack", 4 } } },
    ink = { name = "Ink Spit", intent = "debuff", actions = { { "attack", 3 }, { "debuff", "armor_broken", 1 } } },
  },
  pattern = { "ink", "claw" }, randomStart = true,
}

E.lost_one_hunter = {
  name = "Lost One Hunter", hp = { 30, 33 },
  moves = {
    thrust = { name = "Spear Thrust", intent = "attack", actions = { { "attack", 10 } } },
    net = { name = "Net", intent = "debuff", actions = { { "attack", 4 }, { "debuff", "demoralized", 1 } } },
  },
  pattern = { "thrust", "net" }, randomStart = true,
}

---------------------------------------------------------------------------
-- Élites
---------------------------------------------------------------------------

E.lost_one_chieftain = {
  name = "Lost One Chieftain", hp = 108, elite = true, asleep = 2, opener = "spear",
  moves = {
    spear = { name = "Spear of the Lost", intent = "attack", actions = { { "attack", 24, interrupts = true } } },
    thrust = { name = "Spear Thrust", intent = "attack", actions = { { "attack", 7, times = 2 } } },
    rally = { name = "Rally", intent = "buff", actions = { { "block", 8 }, { "buff", "force", 2 } } },
    crush = { name = "Crushing Blow", intent = "debuff", actions = { { "attack", 7 }, { "debuff", "armor_broken", 1 } } },
  },
  pattern = { "thrust", "rally", "crush" },
}

-- Sentinelle du chef (serviteur : sa mort ne termine pas le combat).
E.lost_one_muckdweller = {
  name = "Lost One Muckdweller", hp = { 21, 23 }, minion = true,
  moves = {
    horn = { name = "Warning Horn", intent = "alarm", cast = true, actions = { { "alarm" } } },
    stab = { name = "Stab", intent = "attack", actions = { { "attack", 5 } } },
  },
  ai = function(c, e)
    if e.mem.last ~= "horn" and ns.Swamp.asleepAllies(c, e) > 0 then return "horn" end
    return "stab"
  end,
}

-- À mi-vie, après l'effet en cours : Slumber 2, soin 9 par tour de sommeil, ouverture Dream Fury ; le
-- motif reprend ensuite à Cleave.
E.wyrmak = {
  name = "Lord Captain Wyrmak", hp = 116, elite = true,
  moves = {
    cleave = { name = "Cleave", intent = "attack", actions = { { "attack", 15 } } },
    sweep = { name = "Tail Sweep", intent = "attack", actions = { { "attack", 7, interrupts = true }, { "block", 8 } } },
    buffet = { name = "Wing Buffet", intent = "debuff", actions = { { "attack", 10 }, { "debuff", "demoralized", 1 } } },
    dream_fury = { name = "Dream Fury", intent = "attack", actions = { { "attack", 14, times = 2 } } },
  },
  pattern = { "cleave", "sweep", "buffet" },
  phases = {
    { at = 0.5, name = "The Dream", text = "Falls asleep: Asleep 2, heals 9 each turn it sleeps.",
      dream = { { "slumber", 2, mend = 9, opener = "dream_fury" } } },
  },
}

E.gilmorian = {
  name = "Gilmorian", hp = 108, elite = true,
  moves = {
    bolt = { name = "Lightning Bolt", intent = "cast", cast = true, actions = { { "attack", 16 } } },
    shock = { name = "Frost Shock", intent = "attack",
      actions = { { "attack", 6, interrupts = true }, { "debuff", "demoralized", 1 } } },
    wave = { name = "Healing Wave", intent = "heal", cast = true, actions = { { "heal_ally", 24 } } },
  },
  pattern = { "bolt", "shock", "wave" },
}

---------------------------------------------------------------------------
-- Boss : Somnus
---------------------------------------------------------------------------

-- Dragonnets de Somnus (phase 3) : éveillés, serviteurs.
E.somnus_whelp = {
  name = "Dreaming Whelp", hp = 14, minion = true,
  moves = { bite = { name = "Bite", intent = "attack", actions = { { "attack", 4 } } } },
  pattern = { "bite" },
}

E.somnus = {
  name = "Somnus", hp = 140, boss = true, asleep = 2, opener = "roar",
  moves = {
    roar = { name = "Bellowing Roar", intent = "attack", actions = { { "attack", 16 }, { "debuff", "demoralized", 1 } } },
    breath = { name = "Noxious Breath", intent = "attack", actions = { { "attack", 6, times = 2 }, { "debuff", "pain", 3 } } },
    claw = { name = "Claw", intent = "attack", actions = { { "attack", 20 } } },
    buffet = { name = "Wing Buffet", intent = "attack", actions = { { "attack", 10, interrupts = true }, { "block", 10 }, { "buff", "force", 3 } } },
    deep_breath = { name = "Deep Breath", intent = "attack", actions = { { "attack", 10, times = 2 } } },
    claw2 = { name = "Claw", intent = "attack", actions = { { "attack", 21 } } },
    breath2 = { name = "Noxious Breath", intent = "attack", actions = { { "attack", 7, times = 2 }, { "debuff", "pain", 3 } } },
  },
  pattern = { "breath", "claw", "buffet" },
  phases = {
    { at = 0.5, name = "The Dream", text = "Summons 2 Dreaming Whelps, then sleeps: Asleep 2, heals 5 each turn it sleeps.",
      pattern = { "claw2", "breath2", "buffet" },
      dream = {
        { "say", "Children of the Dream, defend me!" },
        { "summon", "somnus_whelp", count = 2 },
        { "slumber", 2, mend = 5, opener = "deep_breath" },
      } },
  },
}

---------------------------------------------------------------------------
-- Groupes
---------------------------------------------------------------------------

ns.Encounters.swamp = {
  easy = {
    { "sawtooth_crocolisk" },
    { "marsh_inkspewer", "marsh_inkspewer", "marsh_inkspewer" },
    { "dreaming_whelp", "dreaming_whelp", "marsh_inkspewer" },
    { "deathstrike_tarantula", "marsh_inkspewer" },
  },
  normal = {
    { "deathstrike_tarantula", "sawtooth_crocolisk", "marsh_inkspewer" },
    { "wyrmkin_dreamwalker", "dreaming_whelp", "dreaming_whelp", "marsh_inkspewer" },
    { "marsh_oracle", "swampwalker", "marsh_inkspewer" },
    { "green_scalebane", "wyrmkin_dreamwalker" },
    { "lost_one_hunter", "deathstrike_tarantula" },
    { "marsh_oracle", "sawtooth_crocolisk", "dreaming_whelp" },
  },
  elite = {
    { "lost_one_muckdweller", "lost_one_chieftain" },
    { "wyrmak" },
    { "gilmorian" },
  },
  boss = {
    { "somnus" },
  },
  -- Combats déclenchés par une rencontre (effet « fight »).
  event_crocs = { { "sawtooth_crocolisk", "sawtooth_crocolisk" } },
  event_galen = { { "marsh_inkspewer", "marsh_inkspewer", "marsh_inkspewer", "marsh_inkspewer" } },
  -- tous Asleep 3 : posé par la rencontre (effet « fight », st = { asleep = 3 })
  event_dragonkin = { { "green_scalebane", "dreaming_whelp", "dreaming_whelp" } },
  event_gilmorian = { { "gilmorian" } },
}

---------------------------------------------------------------------------
-- Commun débloqué par la première victoire du compte dans la zone (tier = 5)
---------------------------------------------------------------------------

-- Dream Dust porte Slumber dans toutes les zones (Core/ZoneRules/swamp.lua : règles actives dans un combat
-- dont le deck pose Asleep) ; sans effet sur les élites et les boss.
D.neutralCard("dream_dust", {
  tier = 5, name = "Dream Dust", cost = 1, type = "skill", rarity = "uncommon",
  target = "enemy", exhaust = true, effects = { { "apply", "asleep", 2 } },
  text = "Apply Asleep 2 ⌛\nExhaust.",
  up = { cost = 0, text = "Apply Asleep 2 ⌛\nExhaust." },
})

-- « End your turn » de la fiche : aucun effet ne termine le tour depuis une carte ; « Lose all mana. » en
-- tient lieu (le tour est fini pour les cartes qui coûtent du mana).
D.neutralCard("dreamless_sleep_potion", {
  tier = 5, name = "Dreamless Sleep Potion", cost = 0, type = "skill", rarity = "common",
  exhaust = true, effects = { { "heal", 10 }, { "fn", function(c) c.player.mana = 0 end } },
  text = "Heal 10.\nLose all mana.\nExhaust.",
  up = { effects = { { "heal", 14 }, { "fn", function(c) c.player.mana = 0 end } },
    text = "Heal 14.\nLose all mana.\nExhaust." },
})

-- The first attack each enemy makes against you deals 3 less (premier coup de chaque ennemi).
D.relic("green_dragonscale", {
  name = "Green Dragonscale", rarity = "common", tier = 5,
  text = "The first attack each enemy makes against you deals 3 less.",
  hooks = {
    beforeHit = function(c, src, dmg, e)
      if not e or e.side ~= "enemy" then return dmg end
      local k = "green_dragonscale:" .. e.uid
      if c.relicState[k] then return dmg end
      c.relicState[k] = true
      return math.max(0, dmg - 3)
    end,
  },
})

D.relic("tender_crocolisk_meat", {
  name = "Tender Crocolisk Meat", rarity = "common", tier = 5,
  text = "After each elite combat won, heal 8 HP.",
  hooks = {
    onVictory = function(c)
      if c.kind == "elite" then Combat.heal(c, c.player, 8) end
    end,
  },
})

D.relic("atalai_artifact", {
  name = "Atal'ai Artifact", rarity = "uncommon", tier = 5,
  text = "At the start of each combat, apply Sundered 1 to all enemies.",
  hooks = {
    onCombatStart = function(c)
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if not e.dead then Combat.applyStatus(c, e, "armor_broken", 1) end
      end
    end,
  },
})

---------------------------------------------------------------------------
-- Bibelots de clé (+1, +3, +5) : première victoire de la classe dans le marais à cette clé
---------------------------------------------------------------------------

-- +4 au premier coup subi par chaque ennemi (avant Rude Awakening : crochet enemyDamageTaken).
D.relic("chained_essence_of_eranikus", {
  name = "Chained Essence of Eranikus", rarity = "rare", key = { zone = "swamp", level = 1 },
  text = "The first time each enemy takes damage, it takes 4 more.",
  hooks = {
    enemyDamageTaken = function(c, src, v, e)
      if v <= 0 then return v end
      local k = "chained_essence:" .. e.uid
      if c.relicState[k] then return v end
      c.relicState[k] = true
      return v + 4
    end,
  },
})

-- Asleep 1 sur l'ennemi non boss le plus robuste (élites comprises), au début du combat.
D.relic("egg_of_hakkar", {
  name = "Egg of Hakkar", rarity = "rare", key = { zone = "swamp", level = 3 },
  text = "Start of each combat: the enemy with the most HP, bosses excepted, gains Asleep 1.",
  hooks = {
    onCombatStart = function(c)
      local best
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if not e.dead and not e.boss and (not best or e.hp > best.hp) then best = e end
      end
      if best and ns.Swamp then ns.Swamp.sleep(c, best, 1) end
    end,
  },
})

D.relic("essence_of_eranikus", {
  name = "Essence of Eranikus", rarity = "rare", key = { zone = "swamp", level = 5 },
  text = "Start of your turn: if an enemy is Asleep or Stunned, +1 mana.",
  hooks = {
    onTurnStart = function(c)
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if not e.dead and ((e.st.asleep or 0) > 0 or (e.st.stunned or 0) > 0) then
          c.player.mana = c.player.mana + 1
          return
        end
      end
    end,
  },
})

---------------------------------------------------------------------------
-- Rencontres (palier : 0 d'emblée ; toutes ouvertes à l'arrivée dans la zone 5)
---------------------------------------------------------------------------

D.event("stonard_outpost", {
  name = "Stonard", zone = "swamp", tier = 0,
  speaker = "Dispatch Commander Ruag", npc = "dispatch_commander_ruag", scene = "shop",
  text = "\"Stonard does not turn away travelers who can fight. Two Sawtooth crocolisks sleep on the "
    .. "riverbank south of the outpost, and my grunts need their hides. If you want a bed, the inn is open.\"",
  choices = {
    { label = "Hunt the crocolisks", outcome = "Fight 2 sleeping crocolisks: usual reward + 25g",
      result = "Ruag sends you to the riverbank south of the outpost.",
      effects = { { "fight", "event_crocs", gold = 25 } } },
    { label = "Pay the healer", outcome = "Pay 30g, +18 HP",
      result = "The healer cleans your wounds and gives you a bitter tea.",
      effects = { { "pay", 30 }, { "heal", 18 } } },
    { label = "Rest at the inn", outcome = "+10 HP",
      result = "The innkeeper gives you a bed for the afternoon.",
      effects = { { "heal", 10 } } },
    { label = "Visit the alchemist", outcome = "Pay 25g, Dreamless Sleep Potion (card)",
      when = { { "unlocked", "dreamless_sleep_potion", hide = true } },
      result = "Rartar sells you a vial from his shelf.",
      effects = { { "pay", 25 }, { "card", "dreamless_sleep_potion" } } },
  },
})

D.event("pool_of_tears", {
  name = "The Pool of Tears", zone = "swamp", tier = 0,
  speaker = "Fel'Zerul", npc = "fel_zerul", scene = "mine",
  text = "\"The Atal'ai threw their artifacts into the Pool of Tears when the temple sank. I want them "
    .. "back. The water is full of Sawtooth crocolisks, so I am not going in myself.\"",
  choices = {
    { label = "Dive into the pool", outcome = "50%: a relic, else -10 HP",
      effects = { { "gamble", 0.5,
        win = { { "relic" } },
        winText = "You find an Atal'ai idol in the mud at the bottom. Fel'Zerul lets you keep it.",
        lose = { { "loseHp", 10 } },
        loseText = "A crocolisk bites your leg before you reach the bottom." } } },
    { label = "Search the shallows", outcome = "+35g, -5 HP",
      result = "You pull two artifacts from the reeds and cut your hand on the second. Fel'Zerul pays you.",
      effects = { { "gold", 35 }, { "loseHp", 5 } } },
    { label = "Leave", outcome = "Nothing",
      result = "Fel'Zerul goes back to watching the water.",
      effects = {} },
  },
})

D.event("galen_escape", {
  name = "Galen's Escape", zone = "swamp", tier = 0,
  speaker = "Galen Goodward", npc = "galen_goodward", scene = "road",
  text = "\"Marsh murlocs dragged me to their camp and took my strongbox. I got loose, but I can't get "
    .. "past them alone. Get me to the road and we split what's in the box.\"",
  choices = {
    { label = "Escort Galen", outcome = "Fight 4 murlocs: usual reward + 30g",
      result = "The murlocs see you coming and charge.",
      effects = { { "fight", "event_galen", gold = 30 } } },
    { label = "Take the strongbox back alone", outcome = "50%: 60g, else -9 HP",
      effects = { { "gamble", 0.5,
        win = { { "gold", 60 } },
        winText = "The murlocs are fishing. You carry the strongbox out of the camp and Galen pays you.",
        lose = { { "loseHp", 9 } },
        loseText = "A murloc spears you as you lift the strongbox. You drop it and run." } } },
    { label = "Show him the way to the road", outcome = "Nothing",
      result = "Galen thanks you and heads for the road on foot.",
      effects = {} },
  },
})

D.event("fallow_sanctuary", {
  name = "Fallow Sanctuary", zone = "swamp", tier = 1,
  speaker = "Magtoor", npc = "magtoor", scene = "camp",
  text = "\"We are the Lost Ones. We came here from Draenor, and the dragons of the temple hunt us. "
    .. "Share your food with us and our elders will teach you what they know.\"",
  choices = {
    { label = "Share your rations", outcome = "Pay 20g, remove a card from your deck",
      result = "The elders eat with you and show you what to leave behind.",
      effects = { { "pay", 20 }, { "remove" } } },
    { label = "Help them rebuild their huts", outcome = "-6 HP, upgrade a card of your choice",
      result = "You carry logs from the river all day and learn from the Lost Ones as you work.",
      effects = { { "loseHp", 6 }, { "upgrade" } } },
    { label = "Move on", outcome = "Nothing",
      result = "Magtoor goes back to his hut.",
      effects = {} },
    { label = "Ask for their dust", outcome = "Pay 25g, Dream Dust (card)",
      when = { { "unlocked", "dream_dust", hide = true } },
      result = "Magtoor fills a pouch with green dust. The Lost Ones gather it where the dragonkin sleep.",
      effects = { { "pay", 25 }, { "card", "dream_dust" } } },
  },
})

D.event("lost_one_cook", {
  name = "The Lost One Cook", zone = "swamp", tier = 1,
  speaker = "Lost One Cook", npc = "lost_one_cook", scene = "camp",
  text = "\"I cook what the swamp gives me. Today it is crocolisk. Sit and eat, or catch me a fresh "
    .. "Sawtooth and I will show you my recipes.\"",
  choices = {
    { label = "Eat with him", outcome = "+10 HP",
      result = "He fills your bowl twice.",
      effects = { { "heal", 10 } } },
    { label = "Catch a crocolisk for him", outcome = "-7 HP, one of 3 common cards",
      result = "The crocolisk bites you before you drag it to the pot. The cook keeps his word.",
      effects = { { "loseHp", 7 }, { "cardChoice", n = 3, rarity = "common" } } },
    { label = "Buy smoked meat for the road", outcome = "Pay 20g, a potion",
      result = "He wraps the meat in leaves and adds a flask of his broth.",
      effects = { { "pay", 20 }, { "potion" } } },
  },
})

-- Type « Sleeping Camp » : un groupe endormi garde quelque chose sur le chemin.
D.event("temple_steps", {
  name = "The Temple Steps", zone = "swamp", tier = 2,
  speaker = "Temple of Atal'Hakkar", npc = "atalai_chest", scene = "hill",
  text = "A Green Scalebane and two Dreaming Whelps sleep on the steps of the Temple of Atal'Hakkar. "
    .. "An Atal'ai offering chest stands open between them.",
  choices = {
    { label = "Take from the chest quietly", outcome = "50%: a relic, else -10 HP",
      effects = { { "gamble", 0.5,
        win = { { "relic" } },
        winText = "You take an idol from the chest and walk back down the steps. The dragonkin do not move.",
        lose = { { "loseHp", 10 } },
        loseText = "A whelp wakes up and breathes on you. You drop the idol and run." } } },
    { label = "Attack the sleepers", outcome = "Fight 3 sleeping dragonkin: usual reward + 30g",
      result = "You choose which one to strike first.",
      effects = { { "fight", "event_dragonkin", gold = 30, st = { asleep = 3 } } } },
    { label = "Go around the temple", outcome = "Nothing",
      result = "You take the long way through the water.",
      effects = {} },
  },
})

D.event("cortello_riddle", {
  name = "Cortello's Riddle", zone = "swamp", tier = 1, rarity = "rare",
  speaker = "Cortello's Riddle", npc = "cortello_scroll", scene = "road",
  text = "In a dead adventurer's pack, you find a sealed scroll signed by Cortello. The riddle points to a "
    .. "cave in the hills of the swamp. Deathstrike tarantulas nest in that cave.",
  choices = {
    { label = "Search the cave", outcome = "-10 HP, a relic and 40g",
      result = "You find Cortello's chest behind the webs. The tarantulas bite you twice on the way out.",
      effects = { { "loseHp", 10 }, { "relic" }, { "gold", 40 } } },
    { label = "Sell the scroll in Stonard", outcome = "+50g",
      result = "A trader in Stonard buys the scroll without reading it.",
      effects = { { "gold", 50 } } },
    { label = "Leave the scroll", outcome = "Nothing",
      result = "You put the scroll back in the pack.",
      effects = {} },
  },
})

D.event("misty_reed_strand", {
  name = "Misty Reed Strand", zone = "swamp", tier = 2, rarity = "rare",
  speaker = "Stonard fisherman", npc = "stonard_fisherman", scene = "coast",
  -- proposée seulement en bonne santé : la réponse principale est un combat d'élite
  when = { { "hpAbove", 0.6 } },
  text = "\"A naga called Gilmorian came up from the sea and took the Misty Reed Strand. She drowned two "
    .. "of our fishermen. Stonard pays for her head.\"",
  choices = {
    { label = "Hunt Gilmorian", outcome = "Elite fight: elite reward + 40g",
      result = "Gilmorian rises from the water as you reach the strand.",
      effects = { { "fight", "event_gilmorian", kind = "elite", gold = 40 } } },
    { label = "Fish the north end of the strand", outcome = "-4 HP, a potion",
      result = "You fish out of her sight until dark. A fisherman trades you a potion for your catch.",
      effects = { { "loseHp", 4 }, { "potion" } } },
    { label = "Leave the strand", outcome = "Nothing",
      result = "The fisherman goes back to Stonard.",
      effects = {} },
  },
})

-- Décors de la zone (clés d'Art.scenes, UI/Art/Zones/swamp.lua) à la place des décors communs.
ns.Zones.swamp.scenes = {
  road = "swamp_road", hill = "swamp_temple", camp = "swamp_camp", shop = "swamp_shop",
  night = "swamp_night", mine = "swamp_pool", coast = "swamp_strand",
}

-- La zone devient jouable : ses groupes de combats.
ns.Zones.swamp.encounters = "swamp"
