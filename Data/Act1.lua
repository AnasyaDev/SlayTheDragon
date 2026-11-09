-- Acte 1 : Marche de l'Ouest. Chiffres = points de départ pour la simulation.
-- Ennemi : name, hp (nombre ou {min, max}), moves, pattern (+ randomStart) ou ai,
-- boss, minion, crochets onDamaged / onDeath / onAllyDeath.
-- Intention : name, intent (attack|defend|cast|watch|debuff|buff|heal|summon), cast,
-- actions = { {"attack", n, times=k}, {"block", n}, {"debuff", état, n}, {"buff", état, n},
--             {"buff_allies", état, n}, {"heal_ally", n}, {"block_ally", n}, {"interrupt"},
--             {"summon", id, count=k}, {"fn", f} }
local _, ns = ...

local Combat, Card = ns.Combat, ns.Card
local E = ns.Enemies

E.gnoll = {
  name = "Gnoll Rivepatte", hp = { 13, 15 },
  moves = {
    bite = { name = "Morsure", intent = "attack", actions = { { "attack", 6 } } },
    rend = { name = "Lacération", intent = "attack", actions = { { "attack", 4 }, { "debuff", "armor_broken", 1 } } },
  },
  pattern = { "bite", "rend" }, randomStart = true,
}

E.mystic = {
  name = "Mystique Rivepatte", hp = { 11, 13 },
  moves = {
    watch = { name = "Guette", intent = "watch", actions = { { "interrupt" } } },
    mend = { name = "Soins", intent = "heal", actions = { { "heal_ally", 5 } } },
    zap = { name = "Horion", intent = "attack", actions = { { "attack", 3 } } },
  },
  ai = function(c, e, rng)
    for i = 1, #c.hand do
      if Card.def(c.hand[i]).cast then return "watch" end
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
  name = "Murloc côtier", hp = { 7, 9 },
  moves = {
    claw = { name = "Griffe", intent = "attack", actions = { { "attack", 3 } } },
  },
  pattern = { "claw" },
  onAllyDeath = function(c, self, dead)
    if dead.id == "murloc" then Combat.applyStatus(c, self, "force", 1) end
  end,
}

E.bandit = {
  name = "Bandit défias", hp = { 17, 19 },
  moves = {
    stab = { name = "Coup de dague", intent = "attack", actions = { { "attack", 7 } } },
    guard = { name = "Garde", intent = "defend", actions = { { "block", 6 } } },
    flurry = { name = "Rafale", intent = "attack", actions = { { "attack", 3, times = 2 } } },
  },
  pattern = { "stab", "guard", "flurry" }, randomStart = true,
}

E.sorcerer = {
  name = "Sorcier défias", hp = { 13, 15 },
  moves = {
    fireball = { name = "Boule de feu", intent = "cast", cast = true, actions = { { "attack", 14 } } },
    shards = { name = "Éclats", intent = "attack", actions = { { "attack", 3 } } },
  },
  pattern = { "fireball", "shards" }, randomStart = true,
}

E.harvest_golem = {
  name = "Golem moissonneur", hp = 45, elite = true,
  moves = {
    harden = { name = "Blindage", intent = "defend", actions = { { "block", 10 } } },
    smash = { name = "Écrasement", intent = "attack", actions = { { "attack", 14 } } },
  },
  pattern = { "harden", "smash" },
}

E.rhahkzor = {
  name = "Rhahk'Zor", hp = 50, elite = true,
  moves = {
    roar = { name = "Rugissement", intent = "debuff", actions = { { "debuff", "demoralized", 2 }, { "block", 6 } } },
    slam = { name = "Fracas", intent = "attack", actions = { { "attack", 12 } } },
    punch = { name = "Coup de poing", intent = "attack", actions = { { "attack", 6 } } },
  },
  pattern = { "roar", "slam", "punch", "slam" },
}

E.defias_henchman = {
  name = "Sbire défias", hp = { 11, 13 }, minion = true,
  moves = {
    stab = { name = "Coup de dague", intent = "attack", actions = { { "attack", 5 } } },
  },
  pattern = { "stab" },
}

E.vancleef = {
  name = "Edwin VanCleef", hp = 110, boss = true,
  moves = {
    combo = { name = "Enchaînement", intent = "attack",
      actions = { { "attack", 5, times = 2 }, { "debuff", "armor_broken", 1 } } },
    strike = { name = "Frappe mortelle", intent = "attack", actions = { { "attack", 13 } } },
    guard = { name = "Parade", intent = "buff", actions = { { "block", 10 }, { "buff", "force", 2 } } },
  },
  pattern = { "combo", "strike", "guard" },
  onDamaged = function(c, e, loss)
    if not e.mem.summoned and e.hp <= e.maxHp / 2 then
      e.mem.summoned = true
      Combat.log(c, { t = "say", unit = e.uid, text = "À moi, la Confrérie !" })
      Combat.spawn(c, "defias_henchman")
      Combat.spawn(c, "defias_henchman")
    end
  end,
}

ns.Encounters.act1 = {
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
}
