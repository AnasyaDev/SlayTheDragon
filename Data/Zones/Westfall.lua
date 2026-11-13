-- Zone 1 de la campagne : Marche de l'Ouest (Westfall). Contrat d'une zone : docs/zones.md. Chiffres réglés par la simulation (voir docs/equilibrage.md).
-- Ennemi : name, hp (nombre ou {min, max}), moves, pattern (+ randomStart) ou ai,
-- boss, minion, crochets onDamaged / onDeath / onAllyDeath.
-- Intention : name, intent (attack|defend|cast|watch|debuff|buff|heal|summon), cast,
-- actions = { {"attack", n, times=k, interrupts=bool}, {"block", n}, {"debuff", état, n},
--             {"buff", état, n}, {"buff_allies", état, n}, {"heal_ally", n}, {"block_ally", n},
--             {"interrupt"}, {"summon", id, count=k}, {"fn", f} }
-- interrupts = true : si le coup te fait perdre des PV, ton incantation est interrompue
-- (l'Absorption protège donc l'incantation).
local _, ns = ...

local Combat, Card = ns.Combat, ns.Card
local E = ns.Enemies

E.gnoll = {
  name = "Riverpaw Gnoll", hp = { 19, 22 },
  moves = {
    bite = { name = "Bite", intent = "attack", actions = { { "attack", 7 } } },
    rend = { name = "Rend", intent = "attack", actions = { { "attack", 4 }, { "debuff", "armor_broken", 1 } } },
  },
  pattern = { "bite", "rend" }, randomStart = true,
}

E.mystic = {
  name = "Riverpaw Mystic", hp = { 14, 16 },
  moves = {
    -- Guette (réglage du 14/11/2026, bot human) : un coup affiché qui coupe l'incantation si tu perds des
    -- PV, comme Kick (l'Absorb la protège), jamais deux tours de suite. Avant : coupait à coup sûr à chaque
    -- tour où tu avais une incantation en main, sinon 3, sans dégâts affichés.
    watch = { name = "Watch", intent = "attack", actions = { { "attack", 3, interrupts = true } } },
    mend = { name = "Heal", intent = "heal", actions = { { "heal_ally", 5 } } },
    zap = { name = "Shock", intent = "attack", actions = { { "attack", 4 } } },
  },
  ai = function(c, e, rng)
    if e.mem.last ~= "watch" then
      for i = 1, #c.hand do
        if Card.def(c.hand[i]).cast then return "watch" end
      end
    end
    if e.mem.last ~= "mend" then
      for i = 1, #c.enemies do
        local o = c.enemies[i]
        if not o.dead and o.maxHp - o.hp >= 5 then return "mend" end
      end
    end
    return "zap"
  end,
}

E.murloc = {
  name = "Murloc Coastrunner", hp = { 10, 12 },
  moves = {
    claw = { name = "Claw", intent = "attack", actions = { { "attack", 4 } } },
  },
  pattern = { "claw" },
  onAllyDeath = function(c, self, dead)
    if dead.id == "murloc" then Combat.applyStatus(c, self, "force", 1) end
  end,
}

-- Malandrin défias (Defias Highwayman), bandit de grand chemin de la Marche. Avant le 13/11/2026 :
-- « Defias Bandit », d'Elwynn ; mêmes chiffres, id `bandit` gardé (sauvegardes).
E.bandit = {
  name = "Defias Highwayman", hp = { 25, 28 },
  moves = {
    kick = { name = "Kick", intent = "attack", actions = { { "attack", 5, interrupts = true } } },
    guard = { name = "Guard", intent = "defend", actions = { { "block", 8 } } },
    flurry = { name = "Flurry", intent = "attack", actions = { { "attack", 5, times = 2 } } },
  },
  pattern = { "kick", "guard", "flurry" }, randomStart = true,
}

E.sorcerer = {
  name = "Defias Conjurer", hp = { 18, 21 },
  moves = {
    fireball = { name = "Fireball", intent = "cast", cast = true, actions = { { "attack", 12 } } },
    shards = { name = "Frost Shards", intent = "attack", actions = { { "attack", 4, interrupts = true } } },
  },
  pattern = { "fireball", "shards" }, randomStart = true,
}

E.harvest_golem = {
  name = "Harvest Golem", hp = 72, elite = true,
  moves = {
    harden = { name = "Harden", intent = "defend", actions = { { "block", 12 } } },
    smash = { name = "Smash", intent = "attack", actions = { { "attack", 19, interrupts = true } } },
    reap = { name = "Reap", intent = "attack", actions = { { "attack", 7, times = 3 } } },
  },
  pattern = { "harden", "smash", "reap" },
}

E.rhahkzor = {
  name = "Rhahk'Zor", hp = 75, elite = true,
  moves = {
    roar = { name = "Roar", intent = "debuff", actions = { { "attack", 7 }, { "debuff", "demoralized", 2 } } },
    slam = { name = "Slam", intent = "attack", actions = { { "attack", 17, interrupts = true } } },
    punch = { name = "Punch", intent = "attack", actions = { { "attack", 11 } } },
  },
  pattern = { "roar", "slam", "punch", "slam" },
}

E.defias_henchman = {
  name = "Defias Henchman", hp = { 10, 12 }, minion = true,
  moves = {
    stab = { name = "Stab", intent = "attack", actions = { { "attack", 5 } } },
  },
  pattern = { "stab" },
}

-- Edwin VanCleef. Réglage du 14/11/2026 (bot human) : l'appel des sbires à 50 % est une phase (cran sur la
-- barre de vie, infobulle) qui remplace son intention par « To me, Brotherhood! » : visible dès le seuil
-- franchi, sans coup ce tour-là, sbires à son tour. Avant : deux sbires apparus sans préavis au coup qui
-- franchissait le seuil.
E.vancleef = {
  name = "Edwin VanCleef", hp = 98, boss = true,
  moves = {
    combo = { name = "Combo", intent = "attack",
      actions = { { "attack", 10, times = 2 }, { "debuff", "armor_broken", 1 } } },
    kick = { name = "Kick", intent = "attack", actions = { { "attack", 9, interrupts = true } } },
    strike = { name = "Mortal Strike", intent = "attack", actions = { { "attack", 22 } } },
    guard = { name = "Parry", intent = "buff", actions = { { "block", 12 }, { "buff", "force", 3 } } },
    call = { name = "To me, Brotherhood!", intent = "summon",
      actions = { { "summon", "defias_henchman", count = 2 } } },
  },
  pattern = { "combo", "kick", "strike", "guard" },
  phases = { { at = 0.5, name = "Brotherhood", say = "To me, Brotherhood!", open = "call", label = "Next",
    text = "Calls 2 Defias Henchmen instead of his next attack." } },
}

ns.Encounters.westfall = {
  easy = {
    { "gnoll", "gnoll" },
    { "murloc", "murloc", "murloc" },
    { "bandit" },
    { "sorcerer", "murloc" },
  },
  normal = {
    { "gnoll", "gnoll", "mystic" },
    { "murloc", "murloc", "murloc", "murloc" },
    { "bandit", "sorcerer" },
    { "bandit", "gnoll" },
    { "gnoll", "sorcerer", "mystic" },
  },
  elite = {
    { "harvest_golem" },
    { "rhahkzor" },
  },
  boss = {
    { "vancleef" },
  },
  -- Combats déclenchés par une rencontre (Data/Events.lua, effet « fight »).
  event_murlocs = { { "murloc", "murloc", "murloc", "murloc" } },
  event_gnolls = { { "gnoll", "gnoll", "mystic" } },
  event_golem = { { "harvest_golem" } },
  event_tobin = { { "bandit", "defias_henchman", "defias_henchman" } },
}

-- Décors de la zone (clés d'Art.scenes, UI/Art.lua) à la place des décors communs : décors peints
-- couleur blé (docs/zones.md, champ `scenes`).
ns.Zones.westfall.scenes = {
  road = "westfall_road", hill = "westfall_hill", camp = "westfall_camp", shop = "westfall_shop",
  night = "westfall_night",
}

-- La zone devient jouable : ses groupes de combats (docs/zones.md).
ns.Zones.westfall.encounters = "westfall"
