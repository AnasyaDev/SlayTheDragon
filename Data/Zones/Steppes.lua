-- Zone 6 de la campagne : Burning Steppes (`steppes`). Fiche : docs/zones/steppes.md ; décisions :
-- docs/zones/decisions.md ; guide de l'agent de zone : docs/zones.md. Mécanique Wildfire (compte à rebours du
-- champ de bataille, puis brûlure qui monte) : Core/ZoneRules/steppes.lua.
-- Champs propres aux ennemis lus par la règle : wildfire = N (compte à rebours du combat, Volchan 3).
-- Actions de zone : { "stoke", n } (Wildfire n rounds plus tôt ; sol déjà embrasé : Blaze + 2 par point),
-- { "ignite", n } (sol embrasé tout de suite ; déjà embrasé : Blaze + n). Condition « lit » : le sol brûle
-- (attaque { "attack", 10, more = { { 5, "lit" } } }).
-- Chiffres réglés par la simulation : docs/zones/steppes.md, « Implémentation ».
local _, ns = ...

local Combat = ns.Combat
local E = ns.Enemies
local D = ns.Declare

-- Motif qui reprend après le dernier coup joué (e.mem.last) : une phase sans motif propre ne
-- recommence pas le cycle au début (Gruklash, phases 2 et 3 de Grark).
local function cycle(list)
  return function(c, e)
    local last = e.mem.last
    for i = 1, #list do
      if list[i] == last then return list[i % #list + 1] end
    end
    return list[1]
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

-- Le mur : coupe les Cast du joueur, protège les attiseurs.
E.blackrock_soldier = {
  name = "Blackrock Soldier", hp = { 29, 32 },
  moves = {
    strike = { name = "Strike", intent = "attack", actions = { { "attack", 7 } } },
    bash = { name = "Shield Bash", intent = "attack", actions = { { "attack", 5, interrupts = true }, { "block", 6 } } },
    sunder = { name = "Sunder Armor", intent = "debuff", actions = { { "attack", 4 }, { "debuff", "armor_broken", 1 } } },
  },
  pattern = { "strike", "bash", "sunder" }, randomStart = true,
}

-- Cible d'interruption : un Interrupt annule les dégâts et le Stoke.
E.blackrock_sorcerer = {
  name = "Blackrock Sorcerer", hp = { 19, 21 },
  moves = {
    flamestrike = { name = "Flamestrike", intent = "cast", cast = true, actions = { { "attack", 7 }, { "stoke", 1 } } },
    fireball = { name = "Fireball", intent = "attack", actions = { { "attack", 7 } } },
  },
  pattern = { "flamestrike", "fireball" }, randomStart = true,
}

-- Punit les combats longs : plus fort sur sol embrasé.
E.blackrock_worg = {
  name = "Blackrock Worg", hp = { 21, 23 },
  moves = {
    bite = { name = "Bite", intent = "attack", actions = { { "attack", 6, more = { { 3, "lit" } } } } },
    rend = { name = "Rend Flesh", intent = "attack", actions = { { "attack", 3, times = 2 } } },
  },
  pattern = { "bite", "rend" }, randomStart = true,
}

-- Gros PV : l'étourdir avant Searing Roar arrête le Stoke.
E.black_dragonspawn = {
  name = "Black Dragonspawn", hp = { 36, 39 },
  moves = {
    guard = { name = "Scale Guard", intent = "defend", actions = { { "block", 14 } } },
    roar = { name = "Searing Roar", intent = "attack", actions = { { "attack", 7 }, { "stoke", 1 } } },
    cleave = { name = "Cleave", intent = "attack", actions = { { "attack", 11 } } },
  },
  pattern = { "guard", "roar", "cleave" },
}

-- L'attiseur pur : Stoke 2 en Cast sans attaque (ne déclenche pas les Traps), frappe un tour sur deux.
E.black_wyrmkin = {
  name = "Black Wyrmkin", hp = { 23, 26 },
  moves = {
    fan = { name = "Fan the Flames", intent = "cast", cast = true, actions = { { "stoke", 2 } } },
    buffet = { name = "Flame Buffet", intent = "attack", actions = { { "attack", 9 } } },
  },
  pattern = { "fan", "buffet" }, randomStart = true,
}

-- Le gros coup qui interrompt ; Strength qui monte si le combat dure.
E.firegut_brute = {
  name = "Firegut Brute", hp = { 42, 45 },
  moves = {
    bellow = { name = "Bellow", intent = "buff", actions = { { "block", 12 }, { "buff", "force", 2 } } },
    smash = { name = "Smash", intent = "attack", actions = { { "attack", 13, interrupts = true } } },
    embers = { name = "Kick Embers", intent = "attack", actions = { { "attack", 8 }, { "stoke", 1 } } },
  },
  pattern = { "bellow", "smash", "embers" },
}

-- Soutien : Bloodlust si un autre ennemi vit et qu'il ne l'a pas lancé au tour d'avant, deux fois au plus.
E.firegut_ogre_mage = {
  name = "Firegut Ogre Mage", hp = { 21, 23 },
  moves = {
    bloodlust = { name = "Bloodlust", intent = "buff", actions = { { "buff_allies", "force", 1 }, { "fn", function(c, e)
      e.mem.lusts = (e.mem.lusts or 0) + 1
    end } } },
    fireball = { name = "Fireball", intent = "attack", actions = { { "attack", 9 } } },
  },
  ai = function(c, e)
    if e.mem.last ~= "bloodlust" and (e.mem.lusts or 0) < 2 and Combat.ENEMY_CONDITIONS.allies(c, e) then
      return "bloodlust"
    end
    return "fireball"
  end,
}

-- Par trois : chaque mort recule le feu.
E.flamekin_torcher = {
  name = "Flamekin Torcher", hp = { 10, 11 },
  moves = {
    torch = { name = "Torch", intent = "cast", cast = true, actions = { { "attack", 3 }, { "stoke", 1 } } },
    ember = { name = "Ember", intent = "attack", actions = { { "attack", 6 } } },
  },
  pattern = { "torch", "ember" }, randomStart = true,
}

-- Le Dark Iron isolé : il attise sans attaquer, puis frappe fort sur sol embrasé.
E.thaurissan_firewalker = {
  name = "Thaurissan Firewalker", hp = { 31, 34 },
  moves = {
    firewalk = { name = "Firewalk", intent = "defend", actions = { { "block", 12 }, { "stoke", 1 } } },
    nova = { name = "Fire Nova", intent = "attack", actions = { { "attack", 9, more = { { 5, "lit" } } } } },
  },
  pattern = { "firewalk", "nova" },
}

---------------------------------------------------------------------------
-- Élites
---------------------------------------------------------------------------

-- Le seuil : coupe un Cast sur trois, Frenzy sous la moitié.
E.gruklash = {
  name = "Gruklash", hp = 100, elite = true,
  moves = {
    pummel = { name = "Pummel", intent = "attack", actions = { { "attack", 13, interrupts = true } } },
    backhand = { name = "Backhand", intent = "debuff", actions = { { "attack", 14 }, { "debuff", "demoralized", 2 } } },
    mortal = { name = "Mortal Strike", intent = "attack", actions = { { "attack", 18 } } },
  },
  ai = cycle({ "pummel", "backhand", "mortal" }),
  phases = {
    { at = 0.5, name = "Frenzy", text = "Gains Strength 2.", enter = { { "buff", "force", 2 } } },
  },
}

-- Les mines : serviteurs à désamorcer, qui ne reculent pas le feu en mourant.
local THAURIS = { "mine", "shoot", "net", "shoot" }
E.thauris_balgarr = {
  name = "Thauris Balgarr", hp = 116, elite = true,
  moves = {
    mine = { name = "Dark Iron Land Mine", intent = "summon", actions = { { "summon", "dark_iron_land_mine" } } },
    shoot = { name = "Shoot", intent = "attack", actions = { { "attack", 16 } } },
    net = { name = "Net", intent = "debuff", actions = { { "attack", 11 }, { "debuff", "demoralized", 2 } } },
  },
  ai = function(c, e)
    local k = (e.mem.k or 0) % #THAURIS + 1
    e.mem.k = k
    local mv = THAURIS[k]
    if mv == "mine" and alive(c, "dark_iron_land_mine") >= 2 then mv = "shoot" end
    return mv
  end,
}

E.dark_iron_land_mine = {
  name = "Dark Iron Land Mine", hp = 10, minion = true,
  moves = {
    arm = { name = "Arming", intent = "buff", text = "Explodes on its next turn.", actions = {} },
    detonate = { name = "Detonate", intent = "attack", text = "Then the mine is destroyed.",
      actions = { { "attack", 16 }, { "stoke", 1 }, { "die" } } },
  },
  pattern = { "arm", "detonate" },
}

-- La course perdue d'avance : seul, le compte le plus court (Wildfire 3 ; décision du 13/11 : pas de soin par la brûlure).
E.volchan = {
  name = "Volchan", hp = 90, elite = true, wildfire = 3,
  moves = {
    crack = { name = "Flamecrack", intent = "attack", actions = { { "attack", 8 }, { "stoke", 1 } } },
    stomp = { name = "Stomp", intent = "attack", actions = { { "attack", 16, interrupts = true } } },
    nova = { name = "Fire Nova", intent = "cast", cast = true, actions = { { "attack", 15 } } },
  },
  pattern = { "crack", "stomp", "nova" },
}

---------------------------------------------------------------------------
-- Boss : Grark Lorkrub
---------------------------------------------------------------------------

E.ember_worg = {
  name = "Ember Worg", hp = 5, minion = true,
  moves = {
    bite = { name = "Bite", intent = "attack", actions = { { "attack", 3 } } },
  },
  pattern = { "bite" },
}

local GRARK2 = { "torch", "mortal", "rend", "block" }
E.grark_lorkrub = {
  name = "Grark Lorkrub", hp = 123, boss = true, wildfire = 5,
  moves = {
    orders = { name = "Call the Pack", intent = "summon", actions = { { "summon", "ember_worg", max = 2 } } },
    cleave = { name = "Cleave", intent = "attack", actions = { { "attack", 23 } } },
    strike = { name = "Heroic Strike", intent = "attack", actions = { { "attack", 26 } } },
    block = { name = "Shield Block", intent = "buff", actions = { { "block", 12 }, { "buff", "force", 1 } } },
    torch = { name = "Torch the Field", intent = "attack", actions = { { "attack", 12 }, { "stoke", 1 } } },
    mortal = { name = "Mortal Strike", intent = "attack", actions = { { "attack", 22, interrupts = true } } },
    rend = { name = "Rend", intent = "debuff", actions = { { "attack", 7 }, { "debuff", "pain", 3 } } },
  },
  pattern = { "orders", "cleave", "strike", "block" },
  phases = {
    { at = 0.3, name = "Burn them out", text = "Wildfire ignites at once.",
      say = "Burn them out! Let the Steppes take them!",
      enter = { { "ignite", 4 } }, open = "torch", ai = cycle(GRARK2) },
    { at = 0.2, name = "Blackrock, to me", text = "Summons 2 Ember Worgs, gains 12 Absorb.",
      say = "Blackrock, to me!",
      enter = { { "summon", "ember_worg", count = 2 }, { "block", 12 } }, ai = cycle(GRARK2) },
  },
}

---------------------------------------------------------------------------
-- Groupes
---------------------------------------------------------------------------

ns.Encounters.steppes = {
  easy = {
    { "blackrock_soldier", "blackrock_worg" },
    { "flamekin_torcher", "flamekin_torcher", "flamekin_torcher" },
    { "black_dragonspawn" },
    { "black_wyrmkin", "flamekin_torcher" },
  },
  normal = {
    { "blackrock_soldier", "blackrock_sorcerer", "blackrock_worg" },
    { "blackrock_worg", "blackrock_worg", "blackrock_sorcerer" },
    { "black_dragonspawn", "black_wyrmkin" },
    { "firegut_brute", "firegut_ogre_mage" },
    { "thaurissan_firewalker", "flamekin_torcher", "flamekin_torcher" },
  },
  elite = {
    { "gruklash" },
    { "thauris_balgarr" },
    { "volchan" },
  },
  boss = {
    { "grark_lorkrub" },
  },
  -- Combats déclenchés par une rencontre.
  event_firegut = { { "firegut_brute", "firegut_ogre_mage" } },
  event_dragonkin = { { "black_dragonspawn", "black_wyrmkin" } },
  event_volchan = { { "volchan" } },
  -- Compte à rebours du Wildfire selon le genre du combat ; blaze = première brûlure ; step = hausse de la
  -- brûlure après chaque brûlure, et par point de Stoke qui tombe sur un sol déjà embrasé.
  wildfire = { normal = 4, elite = 5, boss = 5, blaze = 1, step = 2 },
}

---------------------------------------------------------------------------
-- Rencontres de la zone (tier 0 : la zone n'est ouverte qu'après les cinq premières)
---------------------------------------------------------------------------

D.event("oralius_firegut", {
  name = "Extinguish the Firegut", zone = "steppes", tier = 0,
  speaker = "Oralius", npc = "oralius", scene = "camp",
  text = "\"The Firegut ogres of Dreadmaul Rock raid our supply carts every night. Kill a few of them "
    .. "and the Vigil pays you. If you won't fight, I can sell you what is left in the carts.\"",
  choices = {
    { label = "Raid Dreadmaul Rock", outcome = "Fight 2 ogres: usual reward + 25g",
      result = "You attack the ogres at the foot of Dreadmaul Rock.",
      effects = { { "fight", "event_firegut", gold = 25 } } },
    { label = "Buy from the carts", outcome = "Pay 30g, a potion",
      result = "Oralius hands you a flask from the last cart that got through.",
      effects = { { "pay", 30 }, { "potion" } } },
    { label = "Move on", outcome = "Nothing",
      result = "You leave Oralius to his count of the carts.",
      effects = {} },
  },
})

D.event("marshal_maxwell", {
  name = "Morgan's Vigil", zone = "steppes", tier = 0,
  speaker = "Marshal Maxwell", npc = "marshal_maxwell", scene = "camp",
  text = "\"Marshal Windsor went into Blackrock Mountain a month ago and has not come back. I cannot "
    .. "spare a single soldier to look for him. If you are going that way, the Vigil will equip you.\"",
  choices = {
    { label = "Drill with the guard", outcome = "-7 HP, upgrade a card of your choice",
      result = "You spar with the Vigil's guards until dusk.",
      effects = { { "loseHp", 7 }, { "upgrade" } } },
    -- drapeau lu par la zone 7 (Blackrock Mountain) : Windsor retrouvé ou non
    { label = "Promise to find Windsor", outcome = "+30g. He will remember.",
      result = "Maxwell pays you in advance. \"Bring him back, or bring me news.\"",
      effects = { { "gold", 30 }, { "flag", "maxwell_windsor" } } },
    { label = "Leave", outcome = "Nothing",
      result = "You salute the marshal and take the road north.",
      effects = {} },
  },
})

D.event("ragged_john", {
  name = "Ragged John's Camp", zone = "steppes", tier = 0,
  speaker = "Ragged John", npc = "ragged_john", scene = "road",
  text = "\"Sit down, friend, you've got burns all over you. I've lived on these steppes for twenty years "
    .. "without a single one. Drink some of my milk, that's the secret.\"",
  choices = {
    { label = "Drink his milk", outcome = "50%: +7 max HP, else -9 HP",
      effects = { { "gamble", 0.5,
        win = { { "maxHp", 7 } },
        winText = "The milk tastes foul, but you feel tougher.",
        lose = { { "loseHp", 9 } },
        loseText = "The milk has turned. You spend the night sick." } } },
    { label = "Rest by his fire", outcome = "+12 HP",
      result = "Ragged John talks until dawn. You sleep through most of it.",
      effects = { { "heal", 12 } } },
    { label = "Buy his map of the Spire", outcome = "Pay 25g, one of 3 uncommon cards",
      result = "John draws the gates and patrols of Blackrock Spire on the back of a wanted poster.",
      effects = { { "pay", 25 }, { "cardChoice", n = 3, rarity = "uncommon" } } },
  },
})

D.event("mathredis_librams", {
  name = "The Libram Binder", zone = "steppes", tier = 0,
  speaker = "Mathredis Firestar", npc = "mathredis_firestar", scene = "shop",
  text = "\"I bind librams to armor and weapons. Bring me arcane components and the work is cheap. "
    .. "Without them, I charge in gold.\"",
  choices = {
    { label = "Pay for a binding", outcome = "Pay 45g, upgrade a card of your choice and a random card",
      result = "Mathredis reads the libram over your gear. The runes hold.",
      effects = { { "pay", 45 }, { "upgradeRandom", 1 }, { "upgrade" } } },
    { label = "Trade him a potion", outcome = "Lose a potion, upgrade 2 random cards",
      when = { { "potion" } },
      result = "Mathredis pours the potion into his ink and binds two runes.",
      effects = { { "losePotion" }, { "upgradeRandom", 2 } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Come back with components.\"",
      effects = {} },
  },
})

D.event("tinkee_incarcinatrix", {
  name = "The Draco-Incarcinatrix 900", zone = "steppes", tier = 0,
  speaker = "Tinkee Steamboil", npc = "tinkee_steamboil", scene = "shop",
  text = "\"My Draco-Incarcinatrix 900 captures the essence of a dragonkin when it dies. I need field "
    .. "data! Wear it near the broodlings for a day, or fund my next prototype.\"",
  choices = {
    { label = "Wear the device", outcome = "-6 HP, +40g",
      result = "The broodlings attack whoever carries the device. Tinkee pays for the data.",
      effects = { { "loseHp", 6 }, { "gold", 40 } } },
    { label = "Fund the prototype", outcome = "Pay 30g. 50%: 75g",
      effects = { { "pay", 30 }, { "gamble", 0.5,
        win = { { "gold", 75 } },
        winText = "The prototype works. Tinkee sells it to Gadgetzan and pays you your share.",
        lose = {},
        loseText = "The prototype explodes. \"Version 901 will work!\"" } } },
    { label = "Leave", outcome = "Nothing",
      result = "Tinkee goes back to her soldering.",
      effects = {} },
  },
})

D.event("helendis_dragonkin", {
  name = "Dragonkin Menace", zone = "steppes", tier = 0,
  speaker = "Helendis Riverhorn", npc = "helendis_riverhorn", scene = "camp",
  text = "\"The black dragonkin on these slopes take orders from someone in Stormwind, and nobody there "
    .. "listens to me. Kill their dragonspawn and I will pay for the work. I can also treat your burns.\"",
  choices = {
    { label = "Clear the slopes", outcome = "Fight 2 dragonkin: usual reward + 20g",
      result = "You climb the slopes toward the dragonkin.",
      effects = { { "fight", "event_dragonkin", gold = 20 } } },
    { label = "Let him treat your burns", outcome = "Pay 20g, heal 30% of max HP",
      result = "Helendis covers your burns with a cold salve.",
      effects = { { "pay", 20 }, { "healPct", 0.30 } } },
    -- carte neutre débloquée par la première victoire du compte dans les Steppes
    { label = "Buy his fire salve", outcome = "Pay 25g, Fire Protection Potion (card)",
      when = { { "unlocked", "greater_fire_protection_potion", hide = true } },
      result = "\"One flask before you walk on the ash.\"",
      effects = { { "pay", 25 }, { "card", "greater_fire_protection_potion" } } },
  },
})

D.event("yuka_ribbly", {
  name = "Ribbly's Bounty", zone = "steppes", tier = 0,
  speaker = "Yuka Screwspigot", npc = "yuka_screwspigot", scene = "shop",
  text = "\"My brother Ribbly owes money to half the goblins in Kalimdor, and to me. Bring me his head "
    .. "and I split the bounty with you. Or buy something. Anyone who isn't Ribbly gets a discount.\"",
  choices = {
    { label = "Hunt Ribbly down", outcome = "60%: +55g, else -9 HP",
      effects = { { "gamble", 0.6,
        win = { { "gold", 55 } },
        winText = "You find Ribbly in a cave and bring back the proof. Yuka pays.",
        lose = { { "loseHp", 9 } },
        loseText = "Ribbly's hired guards were waiting. You fall back empty-handed." } } },
    { label = "Buy from her stock", outcome = "Pay 70g, a relic",
      result = "\"Good choice. It belonged to Ribbly.\"",
      effects = { { "pay", 70 }, { "relic" } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"If you see Ribbly, he owes me.\"",
      effects = {} },
  },
})

-- Rare : combat d'élite, proposé seulement en bonne santé.
D.event("cyrus_taste_of_flame", {
  name = "A Taste of Flame", zone = "steppes", tier = 0, rarity = "rare",
  speaker = "Cyrus Therepentous", npc = "cyrus_therepentous", scene = "hill",
  when = { { "hpAbove", 0.6 } },
  text = "\"You want to know what the Black Dragonflight is planning? Prove you are worth the answer. "
    .. "A molten giant named Volchan walks the lava under the bridge. Kill it.\"",
  choices = {
    { label = "Hunt Volchan", outcome = "Elite fight: elite reward + 40g",
      result = "You go down to the lava under the bridge.",
      effects = { { "fight", "event_volchan", kind = "elite", gold = 40 } } },
    { label = "Drink the essence he offers", outcome = "-5 max HP, one of 3 rare cards",
      result = "The essence burns your throat. Cyrus watches you without a word.",
      effects = { { "loseMaxHp", 5 }, { "cardChoice", n = 3, rarity = "rare" } } },
    { label = "Refuse", outcome = "Nothing",
      result = "\"Then you will learn nothing.\"",
      effects = {} },
  },
})

---------------------------------------------------------------------------
-- Commun débloqué par la première victoire du compte dans les Steppes (tier 6)
---------------------------------------------------------------------------

-- Cartes neutres
D.neutralCard("greater_fire_protection_potion", {
  tier = 6, name = "Fire Protection Potion", cost = 1, type = "skill", rarity = "uncommon",
  exhaust = true, effects = { { "douse", 3 }, { "absorb", 6 } },
  text = "Douse 3.\nGain 6 Absorb.\nExhaust.",
  up = { effects = { { "douse", 3 }, { "absorb", 9 } }, text = "Douse 3.\nGain 9 Absorb.\nExhaust." },
})

D.neutralCard("thorium_grenade", {
  tier = 6, name = "Thorium Grenade", cost = 2, type = "attack", rarity = "uncommon",
  exhaust = true, effects = { { "damage", 10, all = true } },
  text = "Deal 10 to all.\nExhaust.",
  up = { effects = { { "damage", 13, all = true } }, text = "Deal 13 to all.\nExhaust." },
})

-- Bibelots communs
D.relic("blackrock_medallion", {
  name = "Blackrock Medallion", rarity = "common", tier = 6,
  text = "Whenever an enemy dies, gain 3 Absorb.",
  hooks = {
    onEnemyDeath = function(c, src)
      if not c.result then Combat.gainBlock(c, c.player, 3) end
    end,
  },
})

D.relic("gortesh_head", {
  name = "Gor'tesh's Lopped Off Head", rarity = "uncommon", tier = 6,
  text = "At the start of each combat, apply Demoralized 1 to all enemies.",
  hooks = {
    onCombatStart = function(c, src)
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if not e.dead then Combat.applyStatus(c, e, "demoralized", 1) end
      end
    end,
  },
})

D.relic("draco_incarcinatrix", {
  name = "Draco-Incarcinatrix 900", rarity = "uncommon", tier = 6,
  text = "The first time an enemy dies in each combat, draw 2 cards.",
  hooks = {
    onEnemyDeath = function(c, src)
      if c.result or c.relicState.draco_incarcinatrix then return end
      c.relicState.draco_incarcinatrix = true
      Combat.drawCards(c, 2)
    end,
  },
})

-- Rencontre commune : l'affiche de prime, tirée dans toutes les zones (le combat est une élite de la
-- zone en cours, tirée à l'entrée : son nom est dans le texte).
D.event("wanted_poster", {
  name = "WANTED", tier = 6,
  speaker = "Town Crier", npc = "wanted_poster", scene = "camp",
  text = "\"WANTED: %s. Reward paid at the camp, on proof of death.\"",
  choices = {
    { label = "Take the bounty", outcome = "Elite fight: elite reward + 50g",
      result = "You follow the tracks given on the poster.",
      effects = { { "fight", "elite", kind = "elite", group = true, gold = 50 } } },
    { label = "Collect the small bounties", outcome = "-6 HP, +35g",
      result = "You bring in two lesser outlaws listed under the main notice.",
      effects = { { "loseHp", 6 }, { "gold", 35 } } },
    { label = "Leave", outcome = "Nothing",
      result = "You leave the poster on the board.",
      effects = {} },
  },
})

---------------------------------------------------------------------------
-- Bibelots de clé (première victoire d'une classe dans les Steppes à +1, +3, +5)
---------------------------------------------------------------------------

-- Annule la première perte de PV du combat : coup qui passerait l'Absorb, brûlure, Pay N HP.
D.relic("libram_of_resilience", {
  name = "Libram of Resilience", rarity = "rare", key = { zone = "steppes", level = 1 },
  text = "The first time you would lose HP in each combat, lose none.",
  hooks = {
    beforeHit = function(c, src, v)
      if c.relicState.libram_of_resilience or v <= c.player.block then return v end
      c.relicState.libram_of_resilience = true
      Combat.log(c, { t = "float", unit = "player", text = "Libram of Resilience", color = "defendText" })
      return 0
    end,
    hpLoss = function(c, src, v)
      if c.relicState.libram_of_resilience or v <= 0 then return v end
      c.relicState.libram_of_resilience = true
      Combat.log(c, { t = "float", unit = "player", text = "Libram of Resilience", color = "defendText" })
      return 0
    end,
  },
})

D.relic("libram_of_voracity", {
  name = "Libram of Voracity", rarity = "rare", key = { zone = "steppes", level = 3 },
  text = "Whenever an enemy dies, gain Strength 1 for this combat.",
  hooks = {
    onEnemyDeath = function(c, src)
      if not c.result then Combat.applyStatus(c, c.player, "force", 1) end
    end,
  },
})

D.relic("heart_of_the_mountain", {
  name = "Heart of the Mountain", rarity = "rare", key = { zone = "steppes", level = 5 },
  text = "At the start of your turn, if you have half your HP or less: +1 mana and draw 1.",
  hooks = {
    onTurnStart = function(c, src)
      local p = c.player
      if p.hp * 2 <= p.maxHp then
        p.mana = p.mana + 1
        Combat.drawCards(c, 1)
      end
    end,
  },
})

---------------------------------------------------------------------------
-- La zone devient jouable ; ses décors (clés d'Art.scenes, UI/Art/Zones/steppes.lua)
---------------------------------------------------------------------------

ns.Zones.steppes.scenes = {
  road = "steppes_road", hill = "steppes_hill", camp = "steppes_camp", shop = "steppes_shop",
  night = "steppes_night", mine = "steppes_boss", ruins = "steppes_hill", farm = "steppes_road",
  coast = "steppes_road",
}
ns.Zones.steppes.encounters = "steppes"
