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

-- Guette : coupe l'incantation du joueur ; s'il n'y en a pas, lui inflige n.
-- (Une version qui soignait un allié à la place rendait le Mystique trop fort contre un
-- deck d'incantations : il guette à chaque tour où tu as une incantation en main.)
local function watchOrZap(n)
  return function(c, e)
    if c.player.cast then
      Combat.interruptPlayer(c, e)
      return
    end
    Combat.dealDamage(c, e, c.player, Combat.calcDamage(c, e, c.player, n))
  end
end

E.gnoll = {
  name = "Riverpaw Gnoll", hp = { 19, 22 },
  moves = {
    bite = { name = "Bite", intent = "attack", actions = { { "attack", 8 } } },
    rend = { name = "Rend", intent = "attack", actions = { { "attack", 5 }, { "debuff", "armor_broken", 1 } } },
  },
  pattern = { "bite", "rend" }, randomStart = true,
}

E.mystic = {
  name = "Riverpaw Mystic", hp = { 15, 17 },
  moves = {
    watch = { name = "Watch", intent = "watch", text = "Interrupts your cast; otherwise, deals 3.",
      actions = { { "fn", watchOrZap(3) } } },
    mend = { name = "Heal", intent = "heal", actions = { { "heal_ally", 6 } } },
    zap = { name = "Shock", intent = "attack", actions = { { "attack", 5 } } },
  },
  ai = function(c, e, rng)
    for i = 1, #c.hand do
      if Card.def(c.hand[i]).cast then return "watch" end
    end
    if e.mem.last ~= "mend" then
      for i = 1, #c.enemies do
        local o = c.enemies[i]
        if not o.dead and o.maxHp - o.hp >= 6 then return "mend" end
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

E.bandit = {
  name = "Defias Bandit", hp = { 25, 28 },
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
    fireball = { name = "Fireball", intent = "cast", cast = true, actions = { { "attack", 16 } } },
    shards = { name = "Frost Shards", intent = "attack", actions = { { "attack", 4, interrupts = true } } },
  },
  pattern = { "fireball", "shards" }, randomStart = true,
}

E.harvest_golem = {
  name = "Harvest Golem", hp = 72, elite = true,
  moves = {
    harden = { name = "Harden", intent = "defend", actions = { { "block", 12 } } },
    smash = { name = "Smash", intent = "attack", actions = { { "attack", 19, interrupts = true } } },
    reap = { name = "Reap", intent = "attack", actions = { { "attack", 8, times = 3 } } },
  },
  pattern = { "harden", "smash", "reap" },
}

E.rhahkzor = {
  name = "Rhahk'Zor", hp = 75, elite = true,
  moves = {
    roar = { name = "Roar", intent = "debuff", actions = { { "attack", 7 }, { "debuff", "demoralized", 2 } } },
    slam = { name = "Slam", intent = "attack", actions = { { "attack", 18, interrupts = true } } },
    punch = { name = "Punch", intent = "attack", actions = { { "attack", 12 } } },
  },
  pattern = { "roar", "slam", "punch", "slam" },
}

E.defias_henchman = {
  name = "Defias Henchman", hp = { 11, 13 }, minion = true,
  moves = {
    stab = { name = "Stab", intent = "attack", actions = { { "attack", 5 } } },
  },
  pattern = { "stab" },
}

E.vancleef = {
  name = "Edwin VanCleef", hp = 92, boss = true,
  moves = {
    combo = { name = "Combo", intent = "attack",
      actions = { { "attack", 11, times = 2 }, { "debuff", "armor_broken", 1 } } },
    kick = { name = "Kick", intent = "attack", actions = { { "attack", 9, interrupts = true } } },
    strike = { name = "Mortal Strike", intent = "attack", actions = { { "attack", 23 } } },
    guard = { name = "Parry", intent = "buff", actions = { { "block", 12 }, { "buff", "force", 3 } } },
  },
  pattern = { "combo", "kick", "strike", "guard" },
  onDamaged = function(c, e, loss)
    if not e.mem.summoned and e.hp <= e.maxHp / 2 then
      e.mem.summoned = true
      Combat.log(c, { t = "say", unit = e.uid, text = "To me, Brotherhood!" })
      Combat.spawn(c, "defias_henchman")
      Combat.spawn(c, "defias_henchman")
    end
  end,
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

-- La zone devient jouable : ses groupes de combats (docs/zones.md).
ns.Zones.westfall.encounters = "westfall"
