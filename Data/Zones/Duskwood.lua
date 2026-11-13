-- Zone 2 de la campagne : Duskwood (`duskwood`). Fiche : docs/zones/duskwood.md (section « Implémentation » :
-- écarts et nombres finaux) ; décisions : docs/zones/decisions.md ; guide de l'agent de zone : docs/zones.md.
-- Mécanique : Curse (cartes ennemies glissées dans les piles du joueur pour le combat), règles dans
-- Core/ZoneRules/duskwood.lua (chargé juste après ce fichier : les actions « curse », « gorge » et l'effet
-- « removeUnholyShield » cités ici y sont définis).
-- Ennemi : même format que Data/Zones/Westfall.lua. Drapeau d'attaque `curse = id` (Bite) : si l'attaque fait
-- perdre des PV, la Curse id va dans la défausse (une fois par action). Action `{ "curse", id, n = 1,
-- to = "discard" | "draw" | "hand" }` (Hex) : la Curse arrive sans condition. `gift` = carte de combat donnée
-- en main au début du combat (Morbent's Bane).
local _, ns = ...

local Combat, Card = ns.Combat, ns.Card
local E, C = ns.Enemies, ns.Cards
local D = ns.Declare

---------------------------------------------------------------------------
-- Curses (cartes ennemies, pour le combat seulement : token = true, curse = true, toujours épuisées)
---------------------------------------------------------------------------
-- Sans classe, jamais tirées (Card.inClass : ni classe ni neutral) ; type « curse » : ni Attack ni Skill
-- (pas de Rage d'Attack, pas de Combo). Effets « In hand » : crochets damage / drawPerTurn / cost de la zone.
local function curse(id, t)
  t.id = id
  t.token, t.curse, t.exhaust = true, true, true
  t.type, t.rarity = "curse", "basic"
  t.effects = t.effects or {}
  t.up = { text = t.text } -- contrat commun des cartes (jamais améliorée : hors du deck)
  C[id] = t
end

curse("rabies", {
  name = "Rabies", cost = 1, endOfTurn = { { "loseHp", 3, why = "curse" } },
  text = "Curse.\nEnd of turn: lose 3 HP.\nExhaust.",
})

curse("curse_of_weakness", {
  name = "Curse of Weakness", cost = 1, weakness = 3,
  text = "Curse.\nIn hand: Attacks deal 3 less per hit.\nExhaust.",
})

curse("web", {
  name = "Web", cost = 0, payHp = 2, retain = true, drawLess = 1,
  text = "Pay 2 HP.\nCurse.\nIn hand: draw 1 less each turn.\nExhaust.\nRetain.",
})

curse("fevered_plague", {
  name = "Fevered Plague", cost = 0, unplayable = true, endOfTurn = { { "loseHp", 2, why = "curse" } },
  text = "Curse.\nUnplayable.\nEnd of turn: lose 2 HP.",
})
C.fevered_plague.exhaust = nil -- jamais jouée : rien à épuiser (levée ou nettoyée seulement)

curse("curse_of_tongues", {
  name = "Curse of Tongues", cost = 2, retain = true, tongues = 1,
  text = "Curse.\nIn hand: the first card played each turn costs 1 more.\nExhaust.\nRetain.",
})

-- Carte donnée par Morbent Fel au début du combat (préparation de Madame Eva) : propre au combat.
C.morbents_bane = {
  id = "morbents_bane", name = "Morbent's Bane", cost = 1, type = "skill", token = true, target = "enemy",
  retain = true, cooldown = 2, effects = { { "removeUnholyShield" }, { "damage", 6 } },
  text = "Remove Unholy Shield.\nDeal 6.\nCooldown 2.\nRetain.", rarity = "basic",
}
C.morbents_bane.up = { text = C.morbents_bane.text }

---------------------------------------------------------------------------
-- Ennemis normaux (9)
---------------------------------------------------------------------------

E.dark_runner = {
  name = "Nightbane Dark Runner", hp = { 23, 26 },
  moves = {
    bite = { name = "Bite", intent = "attack", actions = { { "attack", 7, curse = "rabies" } } },
    pounce = { name = "Pounce", intent = "attack", actions = { { "attack", 4, times = 2 } } },
  },
  pattern = { "bite", "pounce" }, randomStart = true,
}

E.vile_fang = {
  name = "Nightbane Vile Fang", hp = { 30, 33 },
  moves = {
    vile_bite = { name = "Vile Bite", intent = "attack", actions = { { "attack", 9, curse = "rabies" } } },
    maul = { name = "Maul", intent = "attack", actions = { { "attack", 12 } } },
    howl = { name = "Howl", intent = "buff", actions = { { "buff_allies", "force", 1 } } },
  },
  pattern = { "vile_bite", "maul", "howl" },
}

E.shadow_weaver = {
  name = "Nightbane Shadow Weaver", hp = { 19, 22 },
  moves = {
    hex = { name = "Curse of Weakness", intent = "curse", cast = true,
      actions = { { "curse", "curse_of_weakness", to = "draw" } } },
    bolt = { name = "Shadow Bolt", intent = "cast", cast = true, actions = { { "attack", 15 } } },
  },
  pattern = { "hex", "bolt" }, randomStart = true,
}

E.plague_spreader = {
  name = "Plague Spreader", hp = { 16, 18 },
  moves = {
    cloud = { name = "Plague Cloud", intent = "curse", actions = { { "curse", "fevered_plague", to = "discard" } } },
    claw = { name = "Claw", intent = "attack", actions = { { "attack", 6 } } },
  },
  pattern = { "cloud", "claw" },
}

E.venom_spider = {
  name = "Venom Web Spider", hp = { 21, 24 },
  moves = {
    web = { name = "Web", intent = "curse", actions = { { "curse", "web", to = "hand" } } },
    venom_bite = { name = "Venom Bite", intent = "attack", actions = { { "attack", 6 }, { "debuff", "pain", 2 } } },
  },
  pattern = { "web", "venom_bite" }, randomStart = true,
}

E.pygmy_spider = {
  name = "Pygmy Venom Web Spider", hp = { 10, 12 },
  moves = {
    nip = { name = "Nip", intent = "attack", actions = { { "attack", 3 }, { "debuff", "pain", 1 } } },
  },
  pattern = { "nip" },
}

E.rotted_one = {
  name = "Rotted One", hp = { 37, 41 },
  moves = {
    claw = { name = "Putrid Claw", intent = "attack", actions = { { "attack", 10 } } },
    shamble = { name = "Shamble", intent = "defend", actions = { { "block_ally", 9 } } },
  },
  pattern = { "claw", "shamble" },
}

E.splinter_fist = {
  name = "Splinter Fist Warrior", hp = { 39, 43 },
  moves = {
    club = { name = "Club", intent = "attack", actions = { { "attack", 9 } } },
    bellow = { name = "Bellow", intent = "buff", actions = { { "block", 8 }, { "buff", "force", 2 } } },
    smash = { name = "Smash", intent = "attack", actions = { { "attack", 15, interrupts = true } } },
  },
  pattern = { "club", "bellow", "smash" },
}

-- Ouverture violente (Ambush au premier tour), puis Stab et Kick en alternance.
E.night_runner = {
  name = "Defias Night Runner", hp = { 23, 26 },
  moves = {
    ambush = { name = "Ambush", intent = "attack", actions = { { "attack", 13 } } },
    stab = { name = "Stab", intent = "attack", actions = { { "attack", 7 } } },
    kick = { name = "Kick", intent = "attack", actions = { { "attack", 6, interrupts = true } } },
  },
  open = "ambush", pattern = { "stab", "kick" },
}

---------------------------------------------------------------------------
-- Élites (3)
---------------------------------------------------------------------------

-- L'horloge : chaque Fevered Plague de Stitches encore en jeu lui donne Strength à chaque Gorge.
E.stitches = {
  name = "Stitches", hp = 86, elite = true,
  moves = {
    spew = { name = "Spew", intent = "curse",
      actions = { { "attack", 6 }, { "curse", "fevered_plague", n = 2, to = "discard" } } },
    slam = { name = "Slam", intent = "attack", actions = { { "attack", 17, interrupts = true } } },
    gorge = { name = "Gorge", intent = "buff", text = "Gains Strength 1 per Fevered Plague of his in your cards.",
      actions = { { "block", 10 }, { "gorge", 1 } } },
  },
  pattern = { "spew", "slam", "gorge" },
}

-- Petits de Naraxis : sbires (fuient à sa mort).
E.pygmy_brood = {
  name = "Pygmy Venom Web Spider", hp = { 9, 11 }, minion = true,
  moves = {
    nip = { name = "Nip", intent = "attack", actions = { { "attack", 3 }, { "debuff", "pain", 1 } } },
  },
  pattern = { "nip" },
}

-- La main étouffée : Webs en main, petits à tuer en plus (4 ennemis vivants au plus).
E.naraxis = {
  name = "Naraxis", hp = 78, elite = true,
  moves = {
    web_spray = { name = "Web Spray", intent = "curse", actions = { { "curse", "web", n = 2, to = "hand" } } },
    poison_fangs = { name = "Poison Fangs", intent = "attack",
      actions = { { "attack", 8, times = 2 }, { "debuff", "pain", 3 } } },
    brood = { name = "Brood", intent = "summon", actions = { { "summon", "pygmy_brood", count = 2, max = 3 } } },
  },
  pattern = { "web_spray", "poison_fangs", "brood", "poison_fangs" },
}

-- L'armure contre la faiblesse : son Absorb tient face à des Attacks à -3 par coup.
E.morladim = {
  name = "Mor'Ladim", hp = 84, elite = true,
  moves = {
    bone_armor = { name = "Bone Armor", intent = "defend", actions = { { "block", 14 }, { "attack", 7 } } },
    hex = { name = "Curse of Weakness", intent = "curse", cast = true,
      actions = { { "curse", "curse_of_weakness", n = 2, to = "draw" } } },
    crushing_blow = { name = "Crushing Blow", intent = "attack", actions = { { "attack", 21, interrupts = true } } },
  },
  pattern = { "bone_armor", "hex", "crushing_blow" },
}

---------------------------------------------------------------------------
-- Boss : Morbent Fel (Tranquil Gardens Cemetery)
---------------------------------------------------------------------------

-- Goule relevée par Morbent (sbire) : Bite qui pose Fevered Plague.
E.fetid_corpse = {
  name = "Fetid Corpse", hp = { 15, 17 }, minion = true,
  moves = {
    rotting_claw = { name = "Rotting Claw", intent = "attack", actions = { { "attack", 6, curse = "fevered_plague" } } },
  },
  pattern = { "rotting_claw" },
}

E.morbent_fel = {
  name = "Morbent Fel", hp = 92, boss = true, gift = "morbents_bane",
  moves = {
    shadow_bolt = { name = "Shadow Bolt", intent = "cast", cast = true, actions = { { "attack", 17 } } },
    tongues = { name = "Curse of Tongues", intent = "curse",
      actions = { { "attack", 7, times = 2 }, { "curse", "curse_of_tongues", to = "hand" } } },
    drain_life = { name = "Drain Life", intent = "attack", actions = { { "attack", 14 }, { "heal_self", 6 } } },
    unholy_shield = { name = "Unholy Shield", intent = "defend", cast = true,
      actions = { { "block", 10 }, { "buff", "unholy_shield", 1 } } },
    shadow_bolt2 = { name = "Shadow Bolt", intent = "cast", cast = true, actions = { { "attack", 20 } } },
    drain_life2 = { name = "Drain Life", intent = "attack", actions = { { "attack", 16 }, { "heal_self", 8 } } },
  },
  pattern = { "shadow_bolt", "tongues", "drain_life" },
  init = function(c, e) Combat.applyStatus(c, e, "unholy_shield", 1) end,
  phases = {
    { at = 0.5, name = "Raise Dead", text = "Summons 2 Fetid Corpses, then casts Unholy Shield again.",
      say = "Rise, and serve your master!", enter = { { "summon", "fetid_corpse", count = 2 } },
      open = "unholy_shield", pattern = { "unholy_shield", "shadow_bolt2", "tongues", "drain_life2", "tongues" }, startAt = 2 },
  },
}

ns.Encounters.duskwood = {
  easy = {
    { "dark_runner", "dark_runner" },
    { "pygmy_spider", "pygmy_spider", "pygmy_spider" },
    { "night_runner" },
    { "venom_spider", "pygmy_spider" },
  },
  normal = {
    { "dark_runner", "dark_runner", "shadow_weaver" },
    { "vile_fang", "dark_runner" },
    { "vile_fang", "shadow_weaver" },
    { "rotted_one", "plague_spreader" },
    { "venom_spider", "venom_spider" },
    { "pygmy_spider", "pygmy_spider", "pygmy_spider", "pygmy_spider" },
    { "splinter_fist" },
    { "night_runner", "night_runner" },
  },
  elite = {
    { "stitches" },
    { "naraxis" },
    { "morladim" },
  },
  boss = {
    { "morbent_fel" },
  },
  -- Combats déclenchés par une rencontre (effet « fight »).
  event_worgen = { { "vile_fang", "dark_runner" } },
  event_ghouls = { { "rotted_one", "plague_spreader" } },
  event_ogres = { { "splinter_fist", "splinter_fist" } },
  event_morladim = { { "morladim" } },
  event_naraxis = { { "naraxis" } },
}

---------------------------------------------------------------------------
-- Rencontres (8) et affiche WANTED (case de parcours, commun de la zone 2)
---------------------------------------------------------------------------
local event = D.event

event("scarlet_raven_tavern", {
  name = "The Scarlet Raven", zone = "duskwood", tier = 0,
  speaker = "Tavernkeep Smitts", npc = "tavernkeep_smitts", scene = "town",
  text = "\"Welcome to the Scarlet Raven. Nobody takes the Raven Hill road after dark, so a room is "
    .. "20 gold tonight. I also sell Zombie Juice, if you can stand the taste.\"",
  choices = {
    { label = "Rent a room", outcome = "Pay 20g, heal 40% of max HP",
      result = "You sleep behind a barred door until morning.",
      effects = { { "pay", 20 }, { "healPct", 0.40 } } },
    { label = "Eat at the bar", outcome = "+7 HP",
      result = "Smitts serves you a bowl of stew and bread.",
      effects = { { "heal", 7 } } },
    { label = "Buy a bottle of Zombie Juice", outcome = "Pay 25g, Zombie Juice (card)",
      when = { { "unlocked", "zombie_juice", hide = true } },
      result = "Smitts corks a green bottle. \"Drink it fast.\"",
      effects = { { "pay", 25 }, { "card", "zombie_juice" } } },
  },
})

event("night_watch_wall", {
  name = "The Night Watch", zone = "duskwood", tier = 0,
  speaker = "Commander Althea Ebonlocke", npc = "althea_ebonlocke", scene = "town",
  text = "\"The Nightbane have attacked three farms this week and the Night Watch is short of men. "
    .. "Take a shift on the wall tonight, or give us gold for arrows.\"",
  choices = {
    { label = "Take a shift on the wall", outcome = "-8 HP, upgrade 2 random cards",
      result = "You hold the wall with the watchers until dawn.",
      effects = { { "loseHp", 8 }, { "upgradeRandom", 2 } } },
    { label = "Pay for arrows", outcome = "Pay 40g, remove a card from the deck",
      result = "\"Thank you. Leave what you don't need at the armory.\"",
      effects = { { "pay", 40 }, { "remove" } } },
    { label = "Leave", outcome = "Nothing",
      result = "You leave Darkshire by the south road.",
      effects = {} },
  },
})

event("sven_camp", {
  name = "Sven's Camp", zone = "duskwood", tier = 0,
  speaker = "Sven Yorgen", npc = "sven_yorgen", scene = "camp",
  text = "\"The Nightbane killed my family and burned my farm. A pack of them sleeps by the road. "
    .. "Help me hunt them, or sit by my fire and rest.\"",
  choices = {
    { label = "Hunt the pack with Sven", outcome = "Fight 2 worgen: usual reward + 20g",
      result = "You and Sven attack the Nightbane.",
      effects = { { "fight", "event_worgen", gold = 20 } } },
    { label = "Rest by his fire", outcome = "+10 HP",
      result = "Sven keeps watch while you sleep.",
      effects = { { "heal", 10 } } },
    { label = "Give him a potion", outcome = "Lose a potion, +6 max HP",
      when = { { "potion" } },
      result = "Sven drinks it and shows you how he fights the worgen.",
      effects = { { "losePotion" }, { "maxHp", 6 } } },
  },
})

event("madame_eva", {
  name = "Madame Eva's Cards", zone = "duskwood", tier = 1,
  speaker = "Madame Eva", npc = "madame_eva", scene = "town",
  text = "\"Sit down. For 15 gold I will read your cards. Or draw one from my deck yourself, "
    .. "but what you draw, you keep.\"",
  choices = {
    { label = "Have your cards read", outcome = "Pay 15g, one of 3 uncommon cards",
      result = "Madame Eva lays out three cards and tells you which one to take.",
      effects = { { "pay", 15 }, { "cardChoice", n = 3, rarity = "uncommon" } } },
    { label = "Draw from her deck", outcome = "50%: one of 3 rare cards, else -5 max HP",
      effects = { { "gamble", 0.5,
        win = { { "cardChoice", n = 3, rarity = "rare" } },
        winText = "You draw a gold card. Madame Eva nods.",
        lose = { { "loseMaxHp", 5 } },
        loseText = "You draw a black card. You feel weaker at once." } } },
    { label = "Leave", outcome = "Nothing",
      result = "You leave her house.",
      effects = {} },
  },
})

event("abercrombie_shack", {
  name = "The Hermit", zone = "duskwood", tier = 1,
  speaker = "Abercrombie", npc = "abercrombie", scene = "woods",
  text = "\"A visitor! I need ghoul ribs for my work. The cemetery on Raven Hill is full of ghouls. "
    .. "Bring me some and I'll pay you, or have some of my soup.\"",
  choices = {
    { label = "Hunt ghouls on Raven Hill", outcome = "Fight 2 undead: usual reward + 25g",
      result = "You attack the undead in the cemetery.",
      effects = { { "fight", "event_ghouls", gold = 25 } } },
    { label = "Eat his soup", outcome = "50%: +6 max HP, else -6 HP",
      effects = { { "gamble", 0.5,
        win = { { "maxHp", 6 } },
        winText = "The soup is thick and hot. You feel stronger.",
        lose = { { "loseHp", 6 } },
        loseText = "There is a finger bone in the soup. You are sick for an hour." } } },
    { label = "Leave", outcome = "Nothing",
      result = "Abercrombie closes his door.",
      effects = {} },
  },
})

event("viktori_monocle", {
  name = "Look to the Stars", zone = "duskwood", tier = 2,
  speaker = "Viktori Prism'Antras", npc = "viktori", scene = "town",
  text = "\"I need an ogre's monocle for my telescope. The Splinter Fist ogres at Vul'Gol have one. "
    .. "Bring it to me, or pay me to teach you what I know.\"",
  choices = {
    { label = "Raid the ogre mound", outcome = "Fight 2 ogres: usual reward + 30g",
      result = "You attack the Splinter Fist ogres.",
      effects = { { "fight", "event_ogres", gold = 30 } } },
    { label = "Take a lesson", outcome = "Pay 35g, upgrade a card of your choice",
      result = "Viktori teaches you for an hour.",
      effects = { { "pay", 35 }, { "upgrade" } } },
    { label = "Leave", outcome = "Nothing",
      result = "Viktori goes back to his books.",
      effects = {} },
  },
})

-- Rare : combat d'élite facultatif, proposé en bonne santé.
event("weathered_grave", {
  name = "The Weathered Grave", zone = "duskwood", tier = 1, rarity = "rare",
  speaker = "Jonathan Carevin", npc = "jonathan_carevin", scene = "graveyard",
  when = { { "hpAbove", 0.6 } },
  text = "\"Mor'Ladim walks Raven Hill Cemetery every night. He was Morgan Ladimore of the Night "
    .. "Watch before he died. I pay 40 gold to whoever puts him down.\"",
  choices = {
    { label = "Hunt Mor'Ladim", outcome = "Elite fight: elite reward + 40g",
      result = "You wait for Mor'Ladim at the cemetery gate.",
      effects = { { "fight", "event_morladim", kind = "elite", gold = 40 } } },
    { label = "Read the Ladimore records", outcome = "-4 max HP, one of 3 rare cards",
      result = "You spend the night reading Clerk Daltry's records by candlelight.",
      effects = { { "loseMaxHp", 4 }, { "cardChoice", n = 3, rarity = "rare" } } },
    { label = "Leave", outcome = "Nothing",
      result = "Jonathan goes back inside.",
      effects = {} },
  },
})

-- Rare : sauver le guetteur ou attaquer le nid.
event("webbed_watcher", {
  name = "The Webbed Watcher", zone = "duskwood", tier = 2, rarity = "rare",
  speaker = "Watcher Dodds", npc = "watcher_dodds", scene = "woods",
  text = "Watcher Dodds hangs wrapped in webs at the edge of a spider nest. \"Cut me loose! Naraxis "
    .. "is in there, and she'll be back soon.\"",
  choices = {
    { label = "Cut him loose", outcome = "-6 HP, a potion and 20g",
      result = "You cut the webs. A spider bites you before you get him out. He pays you from his purse.",
      effects = { { "loseHp", 6 }, { "potion" }, { "gold", 20 } } },
    { label = "Burn the nest", outcome = "Elite fight: elite reward + 40g",
      result = "You set fire to the webs. Naraxis comes out of the nest.",
      effects = { { "fight", "event_naraxis", kind = "elite", gold = 40 } } },
    { label = "Leave him", outcome = "Nothing",
      result = "You go back to the road.",
      effects = {} },
  },
})

-- Affiche de la Night Watch (case de parcours « night_watch_poster », Core/ZoneRules/duskwood.lua) : l'élite
-- nommée (tirée à l'entrée) sera la prochaine élite du chemin ; la battre rapporte 50 po et une carte
-- améliorée au hasard. Jamais tirée au hasard (node = true).
event("night_watch_poster", {
  name = "Wanted Poster", zone = "duskwood", tier = 2, node = true,
  speaker = "Watcher Backus", npc = "watcher_backus", scene = "road",
  text = "Watcher Backus nails a poster to a post by the road: \"WANTED: %s. The Night Watch pays 50 gold "
    .. "for proof of the kill.\"",
  choices = {
    { label = "Take the poster", outcome = "Next elite: +50g and a random card upgraded",
      result = "You fold the poster and put it in your pack.",
      effects = { { "wanted" } } },
    { label = "Leave it", outcome = "Nothing",
      result = "You leave the poster on its post.",
      effects = {} },
  },
})

---------------------------------------------------------------------------
-- Commun débloqué par la première victoire du compte à Duskwood (palier 2)
---------------------------------------------------------------------------
-- sheet = "duskwood" : contenu venu de la fiche de la zone (les tests des listes d'origine, cartes neutres et
-- bibelots communs de Sim/tests.lua, le laissent à part).

D.neutralCard("anti_venom", {
  sheet = "duskwood",
  tier = 2, name = "Anti-Venom", cost = 0, type = "skill", rarity = "common",
  exhaust = true, effects = { { "cleanse" }, { "draw", 1 } },
  text = "Remove negative effects.\nDraw 1.\nExhaust.",
  up = { effects = { { "cleanse" }, { "draw", 2 } }, text = "Remove negative effects.\nDraw 2.\nExhaust." },
})

D.neutralCard("zombie_juice", {
  sheet = "duskwood",
  tier = 2, name = "Zombie Juice", cost = 0, type = "skill", rarity = "uncommon",
  exhaust = true, effects = { { "mana", 1 }, { "draw", 1 } },
  text = "+1 mana.\nDraw 1.\nExhaust.",
  up = { effects = { { "mana", 1 }, { "draw", 2 } }, text = "+1 mana.\nDraw 2.\nExhaust." },
})

D.relic("ogres_monocle", {
  sheet = "duskwood",
  name = "Ogre's Monocle", rarity = "common", tier = 2,
  text = "Card rewards offer 4 cards instead of 3.",
  run = {
    rewardCards = function(exp, v, kind) if kind ~= "chest" then return v + 1 end return v end,
  },
})

-- L'épée courte de la Night Watch : la première Attack jouée dans le tour (marquée au jeu, comme Ironfoe)
-- porte 2 dégâts de plus par coup, même résolue plus tard (Cast).
D.relic("night_watch_shortsword", {
  sheet = "duskwood",
  name = "Night Watch Shortsword", rarity = "uncommon", tier = 2, needs = "attack",
  text = "The first Attack played each turn deals 2 more damage per hit.",
  hooks = {
    onCardCommitted = function(c, src, inst, d)
      if d.type == "attack" and c.relicState.shortsword_round ~= c.round then
        c.relicState.shortsword_round = c.round
        c.relicState.shortsword_uid = inst.uid
      end
    end,
    damage = function(c, src, v, dst, cardDef)
      local ctx = c.cardCtx
      if cardDef and cardDef.type == "attack" and ctx and ctx.card and ctx.card.uid == c.relicState.shortsword_uid then
        return v + 2
      end
      return v
    end,
  },
})

D.relic("mistmantle_family_ring", {
  sheet = "duskwood",
  name = "Mistmantle Family Ring", rarity = "uncommon", tier = 2,
  text = "Whenever an enemy dies, gain 4 Absorb.",
  hooks = {
    onEnemyDeath = function(c, src) if not c.result then Combat.gainBlock(c, c.player, 4) end end,
  },
})

---------------------------------------------------------------------------
-- Bibelots de clé (+1, +3, +5) : première victoire de la classe à cette clé à Duskwood
---------------------------------------------------------------------------

-- Côte de goule (quête d'Abercrombie) : le premier état négatif ou la première Curse de chaque round est
-- empêché (crochets applySelf et preventCurse, ce dernier appelé par l'ajout de Curse de la zone).
local function ribReady(c)
  if c.relicState.ghoul_rib == c.round then return false end
  c.relicState.ghoul_rib = c.round
  Combat.log(c, { t = "float", unit = "player", text = "Ghoul Rib", color = "healText" })
  return true
end
D.relic("ghoul_rib", {
  sheet = "duskwood",
  name = "Ghoul Rib", rarity = "rare", key = { zone = "duskwood", level = 1 },
  text = "The first negative effect or Curse put on you each turn is prevented.",
  hooks = {
    applySelf = function(c, src, n, id)
      local s = ns.Statuses[id]
      if n > 0 and s and s.debuff and ribReady(c) then return 0 end
      return n
    end,
    preventCurse = function(c, src, v)
      if not v and ribReady(c) then return true end
      return v
    end,
  },
})

-- Crâne de Mor'Ladim (quête de Jonathan Carevin) : chaque carte épuisée en étant jouée (Exhaust, Curse
-- payée) inflige 3 à tous les ennemis ; une carte levée ou nettoyée ne compte pas.
D.relic("morladims_skull", {
  sheet = "duskwood",
  name = "Mor'Ladim's Skull", rarity = "rare", key = { zone = "duskwood", level = 3 },
  text = "Whenever an Exhaust card is played, deal 3 to all enemies.",
  hooks = {
    onExhaust = function(c, src, inst, why)
      if why ~= "played" or c.result then return end
      local k0, a0 = c.hitKind, c.hitAll
      c.hitKind, c.hitAll = "other", true
      for _, e in ipairs(Combat.aliveEnemies(c)) do
        Combat.dealDamage(c, c.player, e, 3)
        if c.result then break end
      end
      c.hitKind, c.hitAll = k0, a0
    end,
  },
})

-- Préparation de Madame Eva : +1 mana les tours où un ennemi annonce une incantation (intentions posées).
D.relic("morbents_bane_relic", {
  sheet = "duskwood",
  name = "Morbent's Bane", rarity = "rare", key = { zone = "duskwood", level = 5 },
  text = "+1 mana on turns when an enemy announces a Cast.",
  hooks = {
    onIntents = function(c, src)
      for _, e in ipairs(c.enemies) do
        local mv = not e.dead and ns.Enemies[e.id].moves[e.intent]
        if mv and mv.cast then
          c.player.mana = c.player.mana + 1
          Combat.log(c, { t = "float", unit = "player", text = "+1 mana", color = "defendText" })
          return
        end
      end
    end,
  },
})

---------------------------------------------------------------------------
-- Décors (UI/Art/Zones/duskwood.lua) et zone jouable
---------------------------------------------------------------------------

-- Décors peints de la zone à la place des décors communs ; rencontres : town (Darkshire), graveyard
-- (Raven Hill), woods (Twilight Grove) ; boss : mine -> le cimetière de Tranquil Gardens.
ns.Zones.duskwood.scenes = {
  road = "duskwood_road", hill = "duskwood_graveyard", camp = "duskwood_camp", shop = "duskwood_shop",
  night = "duskwood_night", mine = "duskwood_boss", town = "duskwood_shop", graveyard = "duskwood_graveyard",
  woods = "duskwood_woods",
}

-- La zone devient jouable : ses groupes de combats (docs/zones.md).
ns.Zones.duskwood.encounters = "duskwood"
