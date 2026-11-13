-- Zone 4 de la campagne : Stranglethorn Vale (`stranglethorn`). Fiche : docs/zones/stranglethorn.md ; décisions :
-- docs/zones/decisions.md ; guide de l'agent de zone : docs/zones.md. Mécanique (le Hex) :
-- Core/ZoneRules/stranglethorn.lua (chargé juste après ce fichier : les actions « hex » et « hex_now », le
-- montant « hexed » y sont déclarés). Chiffres réglés par la simulation (section « Implémentation » de la fiche).
local _, ns = ...

local Combat = ns.Combat
local E = ns.Enemies
local D = ns.Declare
local event = D.event

-- Motif à la main (index propre dans e.mem.cyc) : renvoie le prochain move de pat ; swap(c, e, move) peut
-- le remplacer (Call the Pride -> Roar quand les deux tigres vivent).
local function cycle(pat, swap)
  return function(c, e)
    local k = (e.mem.cyc or 0) % #pat + 1
    e.mem.cyc = k
    local mv = pat[k]
    if swap then mv = swap(c, e, mv) or mv end
    return mv
  end
end

local function alive(c, id)
  local n = 0
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if not o.dead and o.id == id then n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------
-- Ennemis normaux
---------------------------------------------------------------------------

local HEX = { name = "Hex", intent = "hex", cast = true, text = "Hexes the costliest card left in your hand.",
  actions = { { "hex" } } }

E.bloodscalp_witch_doctor = {
  name = "Bloodscalp Witch Doctor", hp = { 21, 24 },
  moves = {
    hex = HEX,
    bolt = { name = "Shadow Bolt", intent = "attack", actions = { { "attack", 9, interrupts = true } } },
  },
  pattern = { "hex", "bolt" }, randomStart = true,
}

E.skullsplitter_mystic = {
  name = "Skullsplitter Mystic", hp = { 24, 27 },
  moves = {
    hex = HEX,
    wave = { name = "Healing Wave", intent = "heal", actions = { { "heal_ally", 10 } } },
    bolt = { name = "Lightning Bolt", intent = "attack", actions = { { "attack", 8, interrupts = true } } },
  },
  -- Hex si son dernier coup n'était pas un Hex ; sinon Healing Wave si un allié a perdu 8 PV ou plus ;
  -- sinon Lightning Bolt
  ai = function(c, e)
    if e.mem.last ~= "hex" then return "hex" end
    for i = 1, #c.enemies do
      local o = c.enemies[i]
      if not o.dead and o.maxHp - o.hp >= 8 then return "wave" end
    end
    return "bolt"
  end,
}

E.bloodscalp_headhunter = {
  name = "Bloodscalp Headhunter", hp = { 30, 34 },
  moves = {
    spear = { name = "Throw Spear", intent = "attack", actions = { { "attack", 6, times = 2 } } },
    trophy = { name = "Take a Trophy", intent = "attack", text = "Deals 3 more for each Hexed card you own.",
      actions = { { "attack", 10, per = { 3, "hexed" } } } },
  },
  pattern = { "spear", "trophy" }, randomStart = true,
}

-- Death Hex (champ deathHex, Core/ZoneRules/stranglethorn.lua) : tué pendant ton tour, il hexe la plus chère
-- des cartes de ta main.
E.zanzil_naga = {
  name = "Zanzil Naga", hp = { 30, 34 }, deathHex = true,
  moves = {
    trident = { name = "Trident", intent = "attack", actions = { { "attack", 12 } } },
    coil = { name = "Coil", intent = "defend", actions = { { "block", 8 }, { "attack", 6 } } },
  },
  pattern = { "trident", "coil" }, randomStart = true,
}

-- L'embuscade visible : départ fixe, le Ravage est annoncé au premier tour.
E.shadowmaw_panther = {
  name = "Shadowmaw Panther", hp = { 26, 29 },
  moves = {
    ravage = { name = "Ravage", intent = "attack", actions = { { "attack", 15 } } },
    prowl = { name = "Prowl", intent = "defend", actions = { { "block", 10 } } },
    claw = { name = "Claw", intent = "attack", actions = { { "attack", 10 } } },
  },
  pattern = { "ravage", "prowl", "claw" },
}

E.lashtail_raptor = {
  name = "Lashtail Raptor", hp = { 21, 24 },
  moves = {
    bite = { name = "Bite", intent = "attack", actions = { { "attack", 10 } } },
    tail = { name = "Lashing Tail", intent = "attack", actions = { { "attack", 4, times = 2 } } },
  },
  pattern = { "bite", "tail" }, randomStart = true,
}

E.mistvale_gorilla = {
  name = "Mistvale Gorilla", hp = { 36, 40 },
  moves = {
    pound = { name = "Pound", intent = "attack", actions = { { "attack", 14 } } },
    beat_chest = { name = "Beat Chest", intent = "buff", actions = { { "block", 8 }, { "buff", "force", 2 } } },
  },
  pattern = { "pound", "beat_chest" },
}

E.bloodsail_swashbuckler = {
  name = "Bloodsail Swashbuckler", hp = { 29, 32 },
  moves = {
    cutlass = { name = "Cutlass", intent = "attack", actions = { { "attack", 11 } } },
    trick = { name = "Dirty Trick", intent = "debuff", actions = { { "attack", 5 }, { "debuff", "demoralized", 1 } } },
    kick = { name = "Kick", intent = "attack", text = "Interrupts your cast, even through Absorb.",
      actions = { { "interrupt" }, { "attack", 8 } } },
  },
  pattern = { "cutlass", "trick", "kick" }, randomStart = true,
}

---------------------------------------------------------------------------
-- Élites et leurs serviteurs
---------------------------------------------------------------------------

E.young_stranglethorn_tiger = {
  name = "Young Stranglethorn Tiger", hp = { 10, 12 }, minion = true,
  moves = { bite = { name = "Bite", intent = "attack", actions = { { "attack", 6 } } } },
  pattern = { "bite" },
}

-- Ouverture fixe (Pounce annoncé au premier tour) puis renforts : Call the Pride devient Roar quand les deux
-- tigres vivent déjà.
E.king_bangalash = {
  name = "King Bangalash", hp = 94, elite = true,
  moves = {
    pounce = { name = "Pounce", intent = "attack", text = "Interrupts your cast, even through Absorb.",
      actions = { { "interrupt" }, { "attack", 18 } } },
    rake = { name = "Rake", intent = "attack", actions = { { "attack", 4, times = 3 } } },
    call = { name = "Call the Pride", intent = "summon",
      actions = { { "summon", "young_stranglethorn_tiger", count = 2, max = 2 } } },
    roar = { name = "Roar", intent = "buff", actions = { { "buff_allies", "force", 2 } } },
    maul = { name = "Maul", intent = "attack", actions = { { "attack", 13 } } },
  },
  ai = cycle({ "pounce", "rake", "call", "maul" }, function(c, e, mv)
    if mv == "call" and alive(c, "young_stranglethorn_tiger") >= 2 then return "roar" end
  end),
}

E.mokk_the_savage = {
  name = "Mokk the Savage", hp = 98, elite = true,
  moves = {
    thrash = { name = "Thrash", intent = "attack", actions = { { "attack", 6, times = 2 } } },
    pound = { name = "Pound", intent = "attack", actions = { { "attack", 15 } } },
    beat_chest = { name = "Beat Chest", intent = "buff", actions = { { "block", 12 }, { "buff", "force", 2 } } },
  },
  pattern = { "thrash", "pound", "beat_chest" },
  phases = {
    { at = 0.5, name = "Berserk", text = "Gains Strength 3, then only attacks.", enter = { { "buff", "force", 3 } },
      pattern = { "thrash", "pound" } },
  },
}

E.zanzil_zombie = {
  name = "Zanzil Zombie", hp = { 13, 15 }, minion = true,
  moves = { claw = { name = "Claw", intent = "attack", actions = { { "attack", 7 } } } },
  pattern = { "claw" },
}

-- Chaque Hex qui passe lève un zombie (serviteur : il fuit à la mort de Zanzil).
E.zanzil_the_outcast = {
  name = "Zanzil the Outcast", hp = 96, elite = true,
  moves = {
    hex = { name = "Hex", intent = "hex", cast = true,
      text = "Hexes the costliest card left in your hand. If it lands, raises a Zanzil Zombie.",
      actions = { { "hex", summon = "zanzil_zombie" } } },
    bolt = { name = "Shadow Bolt", intent = "attack", actions = { { "attack", 16, interrupts = true } } },
    mixture = { name = "Zanzil's Mixture", intent = "buff", actions = { { "attack", 8 }, { "buff_allies", "force", 2 } } },
  },
  pattern = { "hex", "bolt", "hex", "mixture" },
}

---------------------------------------------------------------------------
-- Boss : Jin'do the Hexxer, aux portes de Zul'Gurub
---------------------------------------------------------------------------

E.healing_ward = {
  name = "Powerful Healing Ward", hp = 16, minion = true,
  moves = { heal = { name = "Healing Ward", intent = "heal", actions = { { "heal_ally", 8 } } } },
  pattern = { "heal" },
}

E.brain_wash_totem = {
  name = "Brain Wash Totem", hp = 10, minion = true,
  moves = { wash = { name = "Brain Wash", intent = "hex", cast = true,
    text = "Hexes the costliest card left in your hand.", actions = { { "hex" } } } },
  pattern = { "wash" },
}

-- Phase 1 : Hex, Shadow Bolt, Healing Ward (Shadow Bolt si un Ward vit déjà), Delusions. À 50 % (88 PV) :
-- Brain Wash Totem, puis Shadow Volley, Hex, Shadow Bolt. Immunisé à Stunned (boss) : seul l'Interrupt
-- arrête ses Hex.
E.jindo = {
  name = "Jin'do the Hexxer", hp = 176, boss = true,
  moves = {
    hex = HEX,
    bolt = { name = "Shadow Bolt", intent = "attack", text = "Interrupts your cast, even through Absorb.",
      actions = { { "interrupt" }, { "attack", 26 } } },
    delusion = { name = "Delusions of Jin'do", intent = "watch", text = "Interrupts your cast; otherwise, deals 13.",
      -- coup ordinaire (Parry, Absorb, Trap) seulement sans incantation ; sinon l'Interrupt seul
      actions = { { "attack", 13, cond = function(c) return not c.player.cast end }, { "interrupt" } } },
    ward = { name = "Powerful Healing Ward", intent = "summon", text = "Summons a ward that heals him each turn.",
      actions = { { "summon", "healing_ward" } } },
    volley = { name = "Shadow Volley", intent = "attack", text = "Interrupts your cast, even through Absorb.",
      actions = { { "interrupt" }, { "attack", 10, times = 3 } } },
  },
  ai = cycle({ "hex", "bolt", "ward", "delusion" }, function(c, e, mv)
    if mv == "ward" and alive(c, "healing_ward") > 0 then return "bolt" end
  end),
  phases = {
    { at = 0.5, name = "Brain Wash", text = "Summons a Brain Wash Totem that hexes every turn.",
      say = "Your soul belongs to Hakkar!", enter = { { "summon", "brain_wash_totem" } },
      pattern = { "volley", "hex", "bolt" } },
  },
}

---------------------------------------------------------------------------
-- Groupes
---------------------------------------------------------------------------

ns.Encounters.stranglethorn = {
  easy = {
    { "lashtail_raptor", "lashtail_raptor" },
    { "shadowmaw_panther" },
    { "mistvale_gorilla" },
    { "bloodscalp_witch_doctor", "lashtail_raptor" },
  },
  normal = {
    { "bloodscalp_headhunter", "bloodscalp_witch_doctor" },
    { "skullsplitter_mystic", "lashtail_raptor", "lashtail_raptor" },
    { "zanzil_naga", "skullsplitter_mystic" },
    { "bloodsail_swashbuckler", "bloodsail_swashbuckler" },
    { "mistvale_gorilla", "bloodscalp_witch_doctor" },
    { "shadowmaw_panther", "bloodscalp_headhunter" },
  },
  elite = {
    { "king_bangalash" },
    { "mokk_the_savage" },
    { "zanzil_the_outcast" },
  },
  boss = {
    { "jindo" },
  },
  -- combats des rencontres
  event_panthers = { { "shadowmaw_panther", "shadowmaw_panther" } },
  event_bloodsail = { { "bloodsail_swashbuckler", "bloodsail_swashbuckler" } },
  event_hexers = { { "skullsplitter_mystic", "bloodscalp_witch_doctor" } },
  event_mokk = { { "mokk_the_savage" } },
  event_bangalash = { { "king_bangalash" } },
}

---------------------------------------------------------------------------
-- Carte de combat : Hexed (posée par un Hex, jamais dans le deck de l'expédition)
---------------------------------------------------------------------------

ns.Cards.hexed = {
  id = "hexed", name = "Hexed", cost = 1, type = "skill", rarity = "basic", token = true, vanish = true,
  effects = { { "restore" } },
  text = "Return the original card to hand.",
  up = { text = "Return the original card to hand." }, -- jamais améliorée (contrat commun des cartes)
}

---------------------------------------------------------------------------
-- Commun débloqué par la première victoire du compte dans Stranglethorn (tier = 4)
---------------------------------------------------------------------------

-- Cartes neutres
D.neutralCard("jungle_remedy", {
  tier = 4, name = "Jungle Remedy", cost = 0, type = "skill", rarity = "uncommon", exhaust = true,
  effects = { { "restoreAll", id = "hexed" }, { "cleanse" }, { "draw", 1 } },
  text = "Restore all Hexed cards to hand.\nRemove negative effects.\nDraw 1.\nExhaust.",
  up = { effects = { { "restoreAll", id = "hexed" }, { "cleanse" }, { "draw", 2 } },
    text = "Restore all Hexed cards to hand.\nRemove negative effects.\nDraw 2.\nExhaust." },
})

D.neutralCard("rumsey_rum_black_label", {
  tier = 4, name = "Rumsey Rum Black Label", cost = 0, type = "skill", rarity = "common", exhaust = true,
  effects = { { "absorb", 6 } },
  text = "Gain 6 Absorb.\nExhaust.",
  up = { effects = { { "absorb", 9 } }, text = "Gain 9 Absorb.\nExhaust." },
})

-- Bibelots communs
D.relic("green_hills_of_stranglethorn", {
  name = "The Green Hills of Stranglethorn", rarity = "common", tier = 4,
  text = "On the first turn of each combat, draw 1 more card.",
  hooks = {
    drawPerTurn = function(c, src, v)
      if c.round == 1 then return v + 1 end
      return v
    end,
  },
})

-- Première incantation ennemie du combat : interrompue dès son annonce (Hex, Fireball, premier Hex de Jin'do).
D.relic("shrunken_head", {
  name = "Shrunken Head", rarity = "uncommon", tier = 4,
  text = "The first enemy cast of each combat fails.",
  hooks = {
    onEnemyCastStart = function(c, src, e, move)
      if c.relicState.shrunken_head_used or e.interrupted then return end
      c.relicState.shrunken_head_used = true
      e.interrupted = true
      Combat.log(c, { t = "interrupt", src = "player", dst = e.uid, move = move, by = "shrunken_head" })
      Combat.zfire(c, "onEnemyCastInterrupted", e, move, "relic")
    end,
  },
})

D.relic("gorilla_fang", {
  name = "Gorilla Fang", rarity = "common", tier = 4, needs = "attack",
  text = "On the first turn of each combat, Attacks deal 2 more per hit.",
  hooks = {
    damage = function(c, src, v, dst, cardDef)
      if c.round == 1 and cardDef and cardDef.type == "attack" then return v + 2 end
      return v
    end,
  },
})

-- Bibelots de clé (première victoire de la classe à +1, +3, +5 dans Stranglethorn ; communs aux classes)
D.relic("nesingwary_4000", {
  name = "Nesingwary 4000", rarity = "rare", key = { zone = "stranglethorn", level = 1 },
  text = "At the start of each combat, deal 10 to the enemy with the most HP.",
  hooks = {
    -- dégâts hors carte (ni Strength ni Sundered), boss compris
    onCombatStart = function(c, src)
      local best
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if not e.dead and (not best or e.hp > best.hp) then best = e end
      end
      if not best then return end
      local k0, a0 = c.hitKind, c.hitAll
      c.hitKind, c.hitAll = "other", false
      Combat.dealDamage(c, c.player, best, 10)
      c.hitKind, c.hitAll = k0, a0
    end,
  },
})

D.relic("jindos_bag_of_whammies", {
  name = "Jin'do's Bag of Whammies", rarity = "rare", key = { zone = "stranglethorn", level = 3 },
  text = "Whenever you interrupt an enemy cast: +1 mana, draw 1.",
  hooks = {
    onEnemyCastInterrupted = function(c, src, e, move, by)
      if by ~= "player" or c.phase ~= "player" then return end
      c.player.mana = c.player.mana + 1
      Combat.drawCards(c, 1)
    end,
  },
})

D.relic("zandalarian_hero_charm", {
  name = "Zandalarian Hero Charm", rarity = "rare", key = { zone = "stranglethorn", level = 5 },
  text = "At the end of each turn, 1 chosen card stays in hand.",
  hooks = {
    retainPicks = function(c, src, v) return v + 1 end,
  },
})

---------------------------------------------------------------------------
-- Rencontres (zone 4)
---------------------------------------------------------------------------

event("nesingwary_expedition", {
  name = "Nesingwary's Expedition", zone = "stranglethorn", tier = 0,
  speaker = "Hemet Nesingwary Jr.", npc = "hemet_nesingwary", scene = "camp",
  text = "\"I'm writing the definitive book on big game in Stranglethorn, and chapter four needs a Shadowmaw "
    .. "panther. My hunters are out after King Bangalash. Bring me two pelts and I'll pay you.\"",
  choices = {
    { label = "Hunt the panthers", outcome = "Fight 2 Shadowmaw Panthers: usual reward + 25g",
      result = "You track the panthers to a clearing south of the camp.",
      effects = { { "fight", "event_panthers", gold = 25 } } },
    { label = "Shoot with his hunters", outcome = "-6 HP, upgrade a card of your choice",
      result = "Ajeck Rouack shows you how to lead a moving target. The rifle kicks hard.",
      effects = { { "loseHp", 6 }, { "upgrade" } } },
    { label = "Rest at the camp", outcome = "+12 HP",
      result = "Barnil Stonepot serves you a plate of tiger meat. You sleep by the fire.",
      effects = { { "heal", 12 } } },
  },
})

event("booty_bay_docks", {
  name = "The Booty Bay Docks", zone = "stranglethorn", tier = 0,
  speaker = "Baron Revilgaz", npc = "baron_revilgaz", scene = "coast",
  text = "\"The Bloodsail sank two of my ships this month. I pay for every pirate you put in the water. "
    .. "If you'd rather spend than fight, my warehouse is open.\"",
  choices = {
    { label = "Hunt the Bloodsail", outcome = "Fight 2 Bloodsail Swashbucklers: usual reward + 30g",
      result = "You find two Bloodsail pirates loading a rowboat at the end of the pier.",
      effects = { { "fight", "event_bloodsail", gold = 30 } } },
    { label = "Buy from the warehouse", outcome = "Pay 45g, a relic",
      result = "\"No refunds. This is Booty Bay.\"",
      effects = { { "pay", 45 }, { "relic" } } },
    { label = "Sell him a potion", outcome = "Lose a potion, +40g",
      when = { { "potion" } },
      result = "Revilgaz checks the seal on the bottle and counts out the coins.",
      effects = { { "losePotion" }, { "gold", 40 } } },
    { label = "Leave", outcome = "Nothing",
      result = "You leave the docks.",
      effects = {} },
  },
})

event("fishing_extravaganza", {
  name = "The Fishing Extravaganza", zone = "stranglethorn", tier = 0,
  speaker = "Riggle Bassbait", npc = "riggle_bassbait", scene = "coast",
  text = "\"The Stranglethorn Fishing Extravaganza starts in an hour. The first angler to bring me forty "
    .. "Speckled Tastyfish wins the prize. Enter, or buy a basket from someone who gave up.\"",
  choices = {
    { label = "Enter the contest", outcome = "35%: a relic, else -7 HP",
      effects = { { "gamble", 0.35,
        win = { { "relic" } },
        winText = "You bring in forty tastyfish first. Riggle hands you the prize.",
        lose = { { "loseHp", 7 } },
        loseText = "A shark takes your catch and bites your arm. You finish last." } } },
    { label = "Buy a basket of tastyfish", outcome = "Pay 20g, +15 HP",
      result = "You eat grilled tastyfish on the pier.",
      effects = { { "pay", 20 }, { "heal", 15 } } },
    { label = "Fish off the pier", outcome = "+7 HP",
      result = "You catch three small fish and cook them.",
      effects = { { "heal", 7 } } },
  },
})

event("hexed_partner", {
  name = "The Frog in the Satchel", zone = "stranglethorn", tier = 0,
  speaker = "Surveyor Brannock", npc = "explorer_dwarf", scene = "ruins",
  text = "\"A Skullsplitter witch doctor turned my partner into a frog at Zul'Mamwe. I have the cure, but "
    .. "the trolls are still in the ruins. Clear them out, or buy my copies of the tablets.\"",
  choices = {
    { label = "Clear the ruins", outcome = "Fight a Mystic and a Witch Doctor: usual reward + 20g",
      result = "Two troll casters are guarding the tablets.",
      effects = { { "fight", "event_hexers", gold = 20 } } },
    { label = "Buy his tablet copies", outcome = "Pay 30g, upgrade a card of your choice",
      result = "Brannock unrolls his rubbings and explains the troll glyphs.",
      effects = { { "pay", 30 }, { "upgrade" } } },
    { label = "Carry the frog to Booty Bay", outcome = "-5 HP, a potion",
      result = "The frog bites you twice on the road. Brannock pays you with a potion.",
      effects = { { "loseHp", 5 }, { "potion" } } },
  },
})

event("bloodsail_cache", {
  name = "The Bloodsail Powder Store", zone = "stranglethorn", tier = 0,
  speaker = "Fleet Master Seahorn", npc = "fleet_master_seahorn", scene = "coast",
  text = "\"The Bloodsail keep their powder in a cove south of Booty Bay. Blow it up and their ships stay in "
    .. "port for a month. Their captain's charts are in the same tent.\"",
  choices = {
    { label = "Blow up the powder", outcome = "-8 HP, +50g",
      result = "The store goes up while you are still on the beach. Seahorn pays in full.",
      effects = { { "loseHp", 8 }, { "gold", 50 } } },
    { label = "Steal the charts", outcome = "50%: a relic, else -12 HP",
      effects = { { "gamble", 0.5,
        win = { { "relic" } },
        winText = "You take the charts and a strongbox from the captain's tent.",
        lose = { { "loseHp", 12 } },
        loseText = "A guard sees you. You swim back to Booty Bay under fire." } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Then I'll find someone else.\"",
      effects = {} },
  },
})

event("zandalar_envoy", {
  name = "Yojamba Isle", zone = "stranglethorn", tier = 0,
  speaker = "Rin'wosho the Trader", npc = "rinwosho", scene = "coast",
  text = "\"The Zandalar watch Zul'Gurub from this island. Jin'do serves Hakkar now, and his hexes reach "
    .. "Booty Bay. Our mojo protects against them. It costs gold, or blood.\"",
  choices = {
    { label = "Buy a Zandalar charm", outcome = "Pay 50g, Shrunken Head (relic)",
      result = "\"Wear it where the witch doctors can see it.\"",
      effects = { { "pay", 50 }, { "relic", "shrunken_head" } } },
    { label = "Pay in blood", outcome = "-6 max HP, one of 3 rare cards",
      result = "Rin'wosho cuts your palm and mixes the blood into the paint of a tablet.",
      effects = { { "loseMaxHp", 6 }, { "cardChoice", n = 3, rarity = "rare" } } },
    -- carte neutre de la zone, absente tant qu'elle n'est pas débloquée
    { label = "Buy a jungle remedy", outcome = "Pay 25g, Jungle Remedy (card)",
      when = { { "unlocked", "jungle_remedy", hide = true } },
      result = "\"Drink it when the frog comes.\"",
      effects = { { "pay", 25 }, { "card", "jungle_remedy" } } },
    { label = "Leave", outcome = "Nothing",
      result = "You take the boat back to the mainland.",
      effects = {} },
  },
})

event("stranglethorn_fever", {
  name = "Stranglethorn Fever", zone = "stranglethorn", tier = 0, rarity = "rare",
  speaker = "Witch Doctor Unbagwa", npc = "witch_doctor_unbagwa", scene = "ruins",
  when = { { "hpAbove", 0.6 } },
  text = "\"Fin Fizracket has the fever, and only the heart of Mokk cures it. Give me the gorilla fangs and "
    .. "I call him. When he comes, you fight him, not me.\"",
  choices = {
    { label = "Call Mokk", outcome = "Elite fight: elite reward + 40g",
      result = "Unbagwa beats his drum. Mokk the Savage comes out of the trees.",
      effects = { { "fight", "event_mokk", kind = "elite", gold = 40 } } },
    { label = "Take his mojo", outcome = "-5 max HP, one of 3 rare cards",
      result = "Unbagwa paints a troll sign on your chest. You feel weaker.",
      effects = { { "loseMaxHp", 5 }, { "cardChoice", n = 3, rarity = "rare" } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Fin will wait. Or not.\"",
      effects = {} },
  },
})

event("bangalash_hunt", {
  name = "Big Game Hunter", zone = "stranglethorn", tier = 0, rarity = "rare",
  speaker = "Ajeck Rouack", npc = "ajeck_rouack", scene = "camp",
  when = { { "hpAbove", 0.6 } },
  text = "\"King Bangalash leads the tigers on the hill north of camp. Hemet wants his head for the trophy "
    .. "wall. Two of my hunters went up yesterday and came back on stretchers.\"",
  choices = {
    { label = "Hunt King Bangalash", outcome = "Elite fight: elite reward + 40g",
      result = "You climb the hill. Bangalash is waiting on the rocks above you.",
      effects = { { "fight", "event_bangalash", kind = "elite", gold = 40 } } },
    { label = "Tend the wounded hunters", outcome = "-5 HP, a potion",
      result = "You change their bandages all afternoon. Ajeck gives you a potion.",
      effects = { { "loseHp", 5 }, { "potion" } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Hemet will find someone else.\"",
      effects = {} },
  },
})

-- Gurubashi Arena : rencontre ouverte par sa case de parcours (Core/ZoneRules/stranglethorn.lua), dans toutes
-- les zones une fois débloquée ; le groupe (un groupe normal de la zone jouée, PV + 15 %) est tiré à l'entrée.
event("gurubashi_arena", {
  name = "Gurubashi Arena", tier = 4, node = true,
  speaker = "Short John Mithril", npc = "short_john_mithril", scene = "ruins",
  text = "\"Step into the arena! Today's fighters: %g. Win, and the crowd throws you better gear than you "
    .. "find on the road.\"",
  choices = {
    { label = "Fight", outcome = "Fight (+15% HP): usual reward with better cards + 25g",
      result = "The gate closes behind you. The crowd shouts for blood.",
      effects = { { "fight", "normal", group = true, hpMul = 1.15, gold = 25, reward = { shift = 1 } } } },
    { label = "Leave", outcome = "Nothing",
      result = "You leave the arena to the gladiators.",
      effects = {} },
  },
})

---------------------------------------------------------------------------
-- Décors de la zone (clés d'Art.scenes, UI/Art/Zones/stranglethorn.lua), puis la zone devient jouable
---------------------------------------------------------------------------

ns.Zones.stranglethorn.scenes = {
  road = "stranglethorn_road", hill = "stranglethorn_ruins", camp = "stranglethorn_camp",
  shop = "stranglethorn_coast", coast = "stranglethorn_coast", night = "stranglethorn_night",
  ruins = "stranglethorn_ruins", mine = "stranglethorn_gates", farm = "stranglethorn_camp",
}

ns.Zones.stranglethorn.encounters = "stranglethorn"
