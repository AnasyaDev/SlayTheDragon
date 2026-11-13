-- Zone 7 de la campagne : Blackrock Mountain (`blackrock`). Fiche : docs/zones/blackrock.md (section
-- « Implémentation » : écarts et nombres finaux) ; décisions : docs/zones/decisions.md ; guide : docs/zones.md.
-- Mécanique : les phases (seuils de PV, moteur commun : def.phases, Combat.enterPhase) ; règles propres
-- (Invincible, Fire Shield, Shadow of the Throne, Class Call…) : Core/ZoneRules/blackrock.lua.
-- Chargé après Data/Events.lua et AVANT Core/ZoneRules/blackrock.lua : les actions et états de zone sont
-- nommés ici par leur clé, définis là-bas.
local _, ns = ...

local Combat = ns.Combat
local E = ns.Enemies
local D = ns.Declare
local floor = math.floor

---------------------------------------------------------------------------
-- Texte des crans de phase (infobulle de la barre de vie : « Below 50%: Enraged. Gains Strength 3.
-- Opens with Whirlwind. ») composé d'après les données : note de la règle, actions d'entrée, ouverture.
-- Les nombres réglés par la simulation restent ainsi justes à l'écran.
---------------------------------------------------------------------------
local ENTER_TEXT = {
  buff = function(a)
    if a[2] == "force" then return "Gains Strength " .. a[3] .. "." end
    if a[2] == "fire_shield" then return "Fire Shield " .. a[3] .. "." end
    if a[2] == "cracked" then return "Takes 25% more damage." end
    if a[2] == "shadowflame_fury" then return "Shadowflame Fury " .. a[3] .. "." end
    return nil
  end,
  block = function(a) return "Gains " .. a[2] .. " Absorb." end,
  summon = function(a)
    local d = E[a[2]]
    return "Summons " .. ((a.count or 1) > 1 and (a.count .. " ") or "") .. (d and d.name or a[2]) .. "s."
  end,
  raise_bones = function() return "Raises a Bone Construct per Drakonid slain." end,
  clear_status = function(a) return a.text end,
}

local function finish(def)
  for _, ph in ipairs(def.phases or {}) do
    if not ph.text then
      local parts = {}
      if ph.note then parts[#parts + 1] = ph.note end
      for _, a in ipairs(ph.enter or {}) do
        local f = ENTER_TEXT[a[1]]
        local s = f and f(a)
        if s then parts[#parts + 1] = s end
      end
      if ph.open then parts[#parts + 1] = "Opens with " .. def.moves[ph.open].name .. "." end
      -- le moteur ajoute « Below N%: <nom>. » devant
      ph.text = table.concat(parts, " ")
    end
    ph.label = ph.label or "Next"
  end
  return def
end

-- Soigneur (Anvilrage Medic) : soigne l'allié à qui il manque au moins `gap` PV, jamais deux fois de suite.
local function medicAi(gap)
  return function(c, e)
    if e.mem.last ~= "heal" then
      for i = 1, #c.enemies do
        local o = c.enemies[i]
        if not o.dead and o.maxHp - o.hp >= gap then return "heal" end
      end
    end
    return "smite"
  end
end

local function isWhelp(id) return id == "rookery_whelp" or id == "rookery_whelpling" end

---------------------------------------------------------------------------
-- Ennemis normaux (seuil de phase à 50 %, décisions du 13/11/2026)
---------------------------------------------------------------------------

E.firebrand_grunt = finish({
  name = "Firebrand Grunt", hp = { 26, 29 },
  moves = {
    hack = { name = "Hack", intent = "attack", actions = { { "attack", 13 } } },
    sunder = { name = "Sunder Armor", intent = "attack", actions = { { "attack", 5 }, { "debuff", "armor_broken", 1 } } },
  },
  pattern = { "hack", "sunder" }, randomStart = true,
})

-- Nuée : chaque Rookery Whelp gagne Strength 1 à la mort d'un autre (la version invoquée par le Hatcher
-- compte aussi).
local function whelpRage(c, self, dead)
  if isWhelp(dead.id) then Combat.applyStatus(c, self, "force", 1) end
end
E.rookery_whelp = {
  name = "Rookery Whelp", hp = { 13, 15 },
  moves = { bite = { name = "Bite", intent = "attack", actions = { { "attack", 4 } } } },
  pattern = { "bite" }, onAllyDeath = whelpRage,
}
E.rookery_whelpling = {
  name = "Rookery Whelp", hp = { 7, 8 }, minion = true,
  moves = { bite = { name = "Bite", intent = "attack", actions = { { "attack", 4 } } } },
  pattern = { "bite" }, onAllyDeath = whelpRage,
}

E.anvilrage_guardsman = finish({
  name = "Anvilrage Guardsman", hp = { 36, 40 },
  moves = {
    bash = { name = "Shield Bash", intent = "attack", actions = { { "attack", 7, interrupts = true } } },
    guard = { name = "Guard", intent = "defend", actions = { { "block", 10 } } },
    strike = { name = "Strike", intent = "attack", actions = { { "attack", 9, times = 2 } } },
    shield_wall = { name = "Shield Wall", intent = "defend", actions = { { "block", 15 } } },
    shield_slam = { name = "Shield Slam", intent = "attack", actions = { { "attack", 8 }, { "block", 6 } } },
  },
  pattern = { "bash", "guard", "strike" }, randomStart = true,
  phases = { { at = 0.5, name = "Shield Wall", open = "shield_wall", pattern = { "shield_slam", "bash" } } },
})

E.anvilrage_medic = finish({
  name = "Anvilrage Medic", hp = { 21, 23 },
  moves = {
    heal = { name = "Heal", intent = "heal", actions = { { "heal_ally", 8 } } },
    smite = { name = "Holy Smite", intent = "attack", actions = { { "attack", 8 } } },
    prayer = { name = "Desperate Prayer", intent = "heal", actions = { { "heal_self", 10 } } },
  },
  ai = medicAi(8),
  phases = { { at = 0.5, name = "Desperate Prayer", open = "prayer", ai = medicAi(8) } },
})

E.blazing_fireguard = finish({
  name = "Blazing Fireguard", hp = { 27, 30 },
  moves = {
    lash = { name = "Flame Lash", intent = "attack", actions = { { "attack", 12 } } },
    nova = { name = "Fire Nova", intent = "attack", actions = { { "attack", 4 }, { "debuff", "pain", 2 } } },
  },
  pattern = { "lash", "nova" }, randomStart = true,
  phases = { { at = 0.5, name = "Fire Shield", enter = { { "buff", "fire_shield", 2 } }, open = "nova",
    pattern = { "lash", "nova" } } },
})

E.firebrand_pyromancer = finish({
  name = "Firebrand Pyromancer", hp = { 24, 27 },
  moves = {
    fireball = { name = "Fireball", intent = "cast", cast = true, actions = { { "attack", 22 } } },
    scorch = { name = "Scorch", intent = "attack", actions = { { "attack", 5, interrupts = true } } },
    flamestrike = { name = "Flamestrike", intent = "cast", cast = true,
      actions = { { "attack", 12 }, { "debuff", "pain", 3 } } },
  },
  pattern = { "fireball", "scorch" }, randomStart = true,
  phases = { { at = 0.5, name = "Combustion", open = "flamestrike", pattern = { "fireball", "scorch" } } },
})

E.blackhand_veteran = finish({
  name = "Blackhand Veteran", hp = { 35, 38 },
  moves = {
    strike = { name = "Strike", intent = "attack", actions = { { "attack", 13 } } },
    bash = { name = "Shield Bash", intent = "attack", actions = { { "attack", 6, interrupts = true } } },
    shout = { name = "Battle Shout", intent = "buff", actions = { { "buff_allies", "force", 1 } } },
    whirlwind = { name = "Whirlwind", intent = "attack", actions = { { "attack", 6, times = 2 } } },
  },
  pattern = { "strike", "bash", "shout" }, randomStart = true,
  phases = { { at = 0.5, name = "Enraged", enter = { { "buff", "force", 3 } }, open = "whirlwind",
    pattern = { "strike", "whirlwind" } } },
})

E.rage_talon_dragonspawn = finish({
  name = "Rage Talon Dragonspawn", hp = { 36, 39 },
  moves = {
    cleave = { name = "Cleave", intent = "attack", actions = { { "attack", 16 } } },
    thunderclap = { name = "Thunderclap", intent = "debuff", actions = { { "attack", 6 }, { "debuff", "demoralized", 1 } } },
    roar = { name = "Bellowing Roar", intent = "debuff",
      actions = { { "debuff", "armor_broken", 2 }, { "debuff", "demoralized", 2 } } },
  },
  pattern = { "cleave", "thunderclap" }, randomStart = true,
  phases = { { at = 0.5, name = "Bellowing Roar", open = "roar", pattern = { "cleave", "thunderclap" } } },
})

E.rookery_hatcher = finish({
  name = "Rookery Hatcher", hp = { 32, 35 },
  moves = {
    strike = { name = "Strike", intent = "attack", actions = { { "attack", 12 } } },
    tend = { name = "Tend Eggs", intent = "defend", actions = { { "block", 8 } } },
    hatch = { name = "Hatch the Eggs", intent = "summon", actions = { { "summon", "rookery_whelpling", count = 2 } } },
  },
  pattern = { "strike", "tend" },
  phases = { { at = 0.5, name = "Hatch", open = "hatch", pattern = { "strike", "tend" } } },
})

---------------------------------------------------------------------------
-- Élites : tous Indomitable (indomitable = true : immunisés à Stunned comme les boss, Combat.stunImmune ;
-- décision du joueur du 14/11/2026)
---------------------------------------------------------------------------

-- Panzor the Invincible : phase 1, chaque coup lui fait 8 au plus (le DoT passe en entier : règle de
-- zone « maxHit ») ; phase 2, plus de plafond, et il prend 25 % de plus (état Cracked Plating).
E.panzor = finish({
  name = "Panzor the Invincible", hp = 110, elite = true, indomitable = true, maxHit = 8,
  moves = {
    stomp = { name = "Stomp", intent = "attack", actions = { { "attack", 5, times = 2 } } },
    pulverize = { name = "Pulverize", intent = "attack", actions = { { "attack", 11, interrupts = true } } },
    overheat = { name = "Overheat", intent = "buff", actions = { { "buff", "force", 1 } } },
    rampage = { name = "Rampage", intent = "attack", actions = { { "attack", 4, times = 3 } } },
  },
  pattern = { "stomp", "pulverize", "overheat" },
  phases = { { at = 0.5, name = "Cracked Plating", maxHit = false, note = "Loses Invincible.",
    enter = { { "buff", "cracked", 1 } }, open = "rampage", pattern = { "pulverize", "stomp" } } },
})

-- Warchief Rend Blackhand sur Gyth : une seule barre ; Gyth d'abord, Rend à pied sous la moitié.
E.rend_gyth = finish({
  name = "Gyth", hp = 106, elite = true, indomitable = true,
  moves = {
    flame = { name = "Flame Breath", intent = "attack", actions = { { "attack", 8 }, { "debuff", "pain", 2 } } },
    corrosive = { name = "Corrosive Acid", intent = "debuff", actions = { { "attack", 5 }, { "debuff", "armor_broken", 1 } } },
    freeze = { name = "Freeze", intent = "debuff", actions = { { "attack", 4 }, { "debuff", "demoralized", 1 } } },
    knock = { name = "Knock Away", intent = "attack", actions = { { "attack", 7, interrupts = true } } },
    cleave = { name = "Cleave", intent = "attack", actions = { { "attack", 9 } } },
    whirlwind = { name = "Whirlwind", intent = "attack", actions = { { "attack", 4, times = 3 } } },
    mortal = { name = "Mortal Strike", intent = "attack", actions = { { "attack", 12 } } },
  },
  pattern = { "flame", "knock", "corrosive", "freeze" },
  phases = { { at = 0.5, name = "Rend Dismounts", rename = "Warchief Rend Blackhand", art = "rend_blackhand",
    say = "I'll finish this myself!", enter = { { "buff", "force", 1 } }, open = "cleave",
    pattern = { "whirlwind", "mortal" } } },
})

-- Vaelastrasz the Corrupt : 45 % de ses PV au départ, Essence of the Red sur le joueur (+2 mana) jusqu'au
-- seuil de 15 % ; Burning Adrenaline : +50 % aux Attacks pendant 2 tours, puis 15 PV perdus.
E.vaelastrasz = finish({
  name = "Vaelastrasz the Corrupt", hp = 200, elite = true, indomitable = true, essence = true,
  -- le combat commence à 45 % de ses PV ; il n'est pas « tombé à la moitié » (onEnemyBloodied ne part pas)
  init = function(c, e)
    e.hp = floor(e.maxHp * 0.45)
    e.mem.bloodied = true
  end,
  moves = {
    adrenaline = { name = "Burning Adrenaline", intent = "debuff", actions = { { "debuff", "burning_adrenaline", 2 } } },
    flame = { name = "Flame Breath", intent = "attack", actions = { { "attack", 9 }, { "debuff", "pain", 2 } } },
    cleave = { name = "Cleave", intent = "attack", actions = { { "attack", 13 } } },
    nova = { name = "Fire Nova", intent = "attack", actions = { { "attack", 6, times = 2 } } },
  },
  pattern = { "flame", "adrenaline", "cleave" },
  phases = { { at = 0.15, name = "Essence Fades",
    enter = { { "clear_status", "essence_of_red", text = "Essence of the Red ends." } }, open = "nova",
    pattern = { "cleave", "flame" } } },
})

---------------------------------------------------------------------------
-- Boss : Nefarian (Lord Victor Nefarius, puis Nefarian), combat final de la campagne
---------------------------------------------------------------------------

-- Drakônides : sbires (la mort de Nefarian met fin au combat). Chaque Drakonid tué pendant la phase 1
-- relèvera un Bone Construct en phase 3 (mem.fallen du boss, 3 au plus).
local function drakonidFell(c, e)
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if o.id == "nefarian" and not o.dead and (o.mem.phase or 0) == 0 then
      o.mem.fallen = (o.mem.fallen or 0) + 1
    end
  end
end
E.red_drakonid = {
  name = "Red Drakonid", hp = 10, minion = true, drakonid = true,
  moves = {
    claw = { name = "Claw", intent = "attack", actions = { { "attack", 8 } } },
    breath = { name = "Flame Breath", intent = "attack", actions = { { "attack", 3 }, { "debuff", "pain", 2 } } },
  },
  pattern = { "claw", "breath" }, onDeath = drakonidFell,
}
E.blue_drakonid = {
  name = "Blue Drakonid", hp = 10, minion = true, drakonid = true,
  moves = {
    claw = { name = "Claw", intent = "attack", actions = { { "attack", 8 } } },
    breath = { name = "Frost Breath", intent = "debuff", actions = { { "attack", 3 }, { "debuff", "demoralized", 1 } } },
  },
  pattern = { "breath", "claw" }, onDeath = drakonidFell,
}
E.bone_construct = {
  name = "Bone Construct", hp = 8, minion = true,
  moves = { strike = { name = "Bone Strike", intent = "attack", actions = { { "attack", 7 } } } },
  pattern = { "strike" },
}

-- Phase 1 (Nefarius sur le trône) : appel des Drakonids s'il en vit moins de 2, soin d'un allié blessé,
-- sinon Shadow Bolt, Shadow Bolt Volley, Fear.
local NEF_PATTERN = { "shadow_bolt", "volley", "fear" }
local function nefariusAi(c, e)
  local mem = e.mem
  local alive = 0
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if not o.dead and E[o.id].drakonid then alive = alive + 1 end
  end
  if alive < 2 and mem.last ~= "call" and #Combat.aliveEnemies(c) < Combat.MAX_ENEMIES then return "call" end
  if mem.last ~= "mending" then
    for i = 1, #c.enemies do
      local o = c.enemies[i]
      if not o.dead and o.maxHp - o.hp >= 8 then return "mending" end
    end
  end
  mem.pidx = (mem.pidx or 0) % #NEF_PATTERN + 1
  return NEF_PATTERN[mem.pidx]
end

E.nefarian = finish({
  name = "Lord Victor Nefarius", hp = 138, boss = true, throne = true,
  moves = {
    -- phase 1 : Lord Victor Nefarius
    shadow_bolt = { name = "Shadow Bolt", intent = "cast", cast = true, actions = { { "attack", 22 } } },
    volley = { name = "Shadow Bolt Volley", intent = "attack", actions = { { "attack", 7, times = 2 } } },
    fear = { name = "Fear", intent = "debuff", actions = { { "attack", 5 }, { "debuff", "demoralized", 2 } } },
    mending = { name = "Dark Mending", intent = "heal", actions = { { "heal_ally", 8 } } },
    call = { name = "Call Drakonids", intent = "summon", actions = { { "call_drakonid" } } },
    -- phases 2 et 3 : Nefarian
    class_call = { name = "Class Call", intent = "debuff", actions = { { "class_call", 2 } } },
    shadow_flame = { name = "Shadow Flame", intent = "cast", cast = true,
      actions = { { "attack", 24 }, { "debuff", "pain", 3, cond = "noOnyxiaCloak" } } },
    tail_sweep = { name = "Tail Sweep", intent = "attack", actions = { { "attack", 11, times = 2 } } },
    veil = { name = "Veil of Shadow", intent = "debuff", actions = { { "attack", 6 }, { "debuff", "veil_of_shadow", 4 } } },
    roar = { name = "Bellowing Roar", intent = "attack", actions = { { "attack", 7, times = 2 }, { "debuff", "demoralized", 1 } } },
    cleave = { name = "Cleave", intent = "attack", actions = { { "attack", 20 } } },
  },
  ai = nefariusAi,
  phases = {
    { at = 0.75, cap = true, name = "Nefarian Lands", rename = "Nefarian", art = "nefarian_dragon",
      say = "Well done, my minions. The mortals' courage begins to wane! Now let's see how they contend "
        .. "with the true Lord of Blackrock Spire!",
      note = "Shadow of the Throne ends.", open = "class_call",
      pattern = { "veil", "shadow_flame", "tail_sweep", "class_call" } },
    { at = 0.25, cap = true, name = "Rise, My Minions",
      say = "Impossible! Rise, my minions! Serve your master once more!",
      enter = { { "raise_bones" }, { "buff", "force", 3 }, { "buff", "shadowflame_fury", 3 } }, open = "roar",
      pattern = { "veil", "shadow_flame", "cleave", "tail_sweep" } },
  },
  onDeath = function(c, e)
    Combat.log(c, { t = "say", unit = e.uid, text = "This cannot be! I am the master here! You mortals are "
      .. "nothing to my kind! Do you hear me? Nothing!" })
  end,
})

---------------------------------------------------------------------------
-- Groupes
---------------------------------------------------------------------------

ns.Encounters.blackrock = {
  easy = {
    { "firebrand_grunt", "firebrand_grunt" },
    { "rookery_whelp", "rookery_whelp", "rookery_whelp" },
    { "anvilrage_guardsman" },
    { "firebrand_pyromancer", "rookery_whelp" },
  },
  normal = {
    { "firebrand_grunt", "firebrand_grunt", "anvilrage_medic" },
    { "anvilrage_guardsman", "firebrand_pyromancer" },
    { "blackhand_veteran", "anvilrage_medic" },
    { "rookery_hatcher", "rookery_whelp" },
    { "blazing_fireguard", "blazing_fireguard" },
    { "rage_talon_dragonspawn", "firebrand_grunt" },
    { "rookery_whelp", "rookery_whelp", "rookery_whelp", "rookery_whelp" },
  },
  elite = {
    { "panzor" },
    { "rend_gyth" },
    { "vaelastrasz" },
  },
  boss = {
    { "nefarian", "red_drakonid", "blue_drakonid" },
  },
  -- Combats déclenchés par les rencontres
  event_fineous = { { "anvilrage_guardsman", "anvilrage_medic" } },
  event_jail = { { "anvilrage_guardsman", "anvilrage_guardsman" } },
  event_rookery = { { "rookery_whelp", "rookery_whelp", "rookery_whelp", "rookery_whelp" } },
  event_core = { { "blazing_fireguard", "blazing_fireguard" } },
  event_nefarius = { { "blackhand_veteran", "blackhand_veteran" } },
}

---------------------------------------------------------------------------
-- Rencontres de la zone (Data/Events.lua : format ; décors : clés d'Art.scenes de UI/Art/Zones/blackrock.lua)
---------------------------------------------------------------------------

local event = D.event

event("dark_iron_legacy", {
  name = "The Dark Iron Legacy", zone = "blackrock", tier = 0,
  speaker = "Franclorn Forgewright", npc = "franclorn_forgewright", scene = "road",
  text = "\"I built this city for the Dark Iron, and Fineous Darkvire took my hammer, Ironfel, when I died. "
    .. "Kill him and bring Ironfel to the Shrine of Thaurissan.\"",
  choices = {
    { label = "Hunt down Darkvire", outcome = "Fight 2 Dark Iron: usual reward + 25g",
      result = "You find Fineous Darkvire in the Halls of Crafting, with his guards.",
      effects = { { "fight", "event_fineous", gold = 25 } } },
    { label = "Rest at his statue", outcome = "Heal 25% of max HP",
      result = "You sleep at the foot of Franclorn's statue. The Dark Iron patrols do not come here.",
      effects = { { "healPct", 0.25 } } },
    -- (fiche : la Shadowforge Key elle-même ; une rencontre ne donne un bibelot précis que s'il lui est propre,
    -- noPool : un bibelot tiré à la place)
    { label = "Ask about the Shadowforge vault", outcome = "Pay 60g, a relic",
      result = "\"Darkvire sold what he took from the vault to a goblin. I know which one.\" You buy it back.",
      effects = { { "pay", 60 }, { "relic" } } },
    { label = "Leave", outcome = "Nothing",
      result = "You leave the ghost on the bridge.", effects = {} },
  },
})

event("thorium_brotherhood", {
  name = "The Thorium Brotherhood", zone = "blackrock", tier = 0,
  speaker = "Lokhtos Darkbargainer", npc = "lokhtos_darkbargainer", scene = "shop",
  text = "\"The Thorium Brotherhood trades with anyone who pays. I have smithing plans, "
    .. "and a Dark Iron recipe that costs more than gold.\"",
  choices = {
    { label = "Buy smithing plans", outcome = "Pay 45g, upgrade a card, then 1 random card",
      result = "You work at the Black Anvil with the Brotherhood's smiths.",
      effects = { { "pay", 45 }, { "upgrade" }, { "upgradeRandom", 1 } } },
    { label = "Pay in blood", outcome = "-6 max HP, one of 3 rare cards",
      result = "Lokhtos fills a vial with your blood and hands you the recipe.",
      effects = { { "loseMaxHp", 6 }, { "cardChoice", n = 3, rarity = "rare" } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Come back with gold.\"", effects = {} },
  },
})

event("kharan_mighthammer", {
  name = "The Prisoner of Ironforge", zone = "blackrock", tier = 1,
  speaker = "Kharan Mighthammer", npc = "kharan_mighthammer", scene = "hill",
  text = "\"I'm Kharan Mighthammer, of Ironforge. Thaurissan has kept me in this cell for years. "
    .. "Give me a weapon and I'll break out on my own, or listen to what I know about this place.\"",
  choices = {
    { label = "Give him a weapon", outcome = "Remove a card from the deck, +20g",
      result = "Kharan takes the weapon and gives you the coins hidden in his boot.",
      effects = { { "remove" }, { "gold", 20 } } },
    { label = "Listen to him", outcome = "-5 HP, one of 3 uncommon cards",
      result = "The guards hear you talking and you have to fight one at the door. Kharan's advice was worth it.",
      effects = { { "loseHp", 5 }, { "cardChoice", n = 3, rarity = "uncommon" } } },
    { label = "Leave", outcome = "Nothing",
      result = "You leave the Detention Block.", effects = {} },
  },
})

event("jail_break", {
  name = "Jail Break!", zone = "blackrock", tier = 1,
  speaker = "Marshal Windsor", npc = "marshal_windsor", scene = "hill",
  text = "\"Get me out of here. The Anvilrage guards carry the cell keys. Help me break out "
    .. "and Stormwind will pay you.\"",
  choices = {
    { label = "Break him out", outcome = "Fight 2 guards: usual reward, upgrade 1 random card",
      result = "You attack the two guards in front of the cells.",
      effects = { { "fight", "event_jail" }, { "upgradeRandom", 1 } } },
    { label = "Pick the lock", outcome = "40%: a relic, else -10 HP",
      effects = { { "gamble", 0.4,
        win = { { "relic" } },
        winText = "The lock opens. Windsor gives you what he hid in the cell.",
        lose = { { "loseHp", 10 } },
        loseText = "A guard catches you at the door and hits you before you escape." } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Then tell Stormwind where I am.\"", effects = {} },
  },
})

event("egg_collection", {
  name = "Egg Collection", zone = "blackrock", tier = 2,
  speaker = "Tinkee Steamboil", npc = "tinkee_steamboil", scene = "camp",
  text = "\"I need Rookery eggs from the Spire for my research. The whelps guard the nests. "
    .. "Bring me some and I'll pay you, or buy one of my potions and go around.\"",
  choices = {
    { label = "Raid the Rookery", outcome = "Fight 4 whelps: usual reward + 30g",
      result = "You climb into the Rookery. The whelps attack.",
      effects = { { "fight", "event_rookery", gold = 30 } } },
    { label = "Buy a potion", outcome = "Pay 25g, a potion",
      result = "\"Fire resistance. Mostly.\"",
      effects = { { "pay", 25 }, { "potion" } } },
    { label = "Buy a Dark Iron Bomb", outcome = "Pay 40g, Dark Iron Bomb (card)",
      when = { { "unlocked", "dark_iron_bomb", hide = true } },
      result = "Tinkee hands you a bomb from under her table.",
      effects = { { "pay", 40 }, { "card", "dark_iron_bomb" } } },
    { label = "Decline", outcome = "Nothing",
      result = "Tinkee goes back to her notes.", effects = {} },
  },
})

event("molten_core", {
  name = "The Molten Core", zone = "blackrock", tier = 2, rarity = "rare",
  speaker = "Lothos Riftwaker", npc = "lothos_riftwaker", scene = "road",
  when = { { "hpAbove", 0.6 } },
  text = "\"I send those who are attuned down to the Molten Core. The fire elementals there are "
    .. "stronger than the ones in the Depths, and they guard Ragnaros's treasure.\"",
  choices = {
    { label = "Go down", outcome = "Elite fight (2 Blazing Fireguards): elite reward + 40g",
      result = "Lothos opens the portal. Two Fireguards wait on the other side.",
      effects = { { "fight", "event_core", kind = "elite", gold = 40 } } },
    { label = "Take a Core Fragment", outcome = "-8 HP, one of 3 rare cards",
      result = "You pick up a fragment of the Core at the edge of the lava. It burns your hand.",
      effects = { { "loseHp", 8 }, { "cardChoice", n = 3, rarity = "rare" } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Come back when you're ready.\"", effects = {} },
  },
})

event("bodley", {
  name = "Bodley's Ghost", zone = "blackrock", tier = 1, rarity = "rare",
  speaker = "Bodley", npc = "bodley", scene = "camp",
  text = "You turn on the Extra-Dimensional Ghost Revealer and a gnome ghost appears. \"Finally! "
    .. "I'm Bodley. I died before I finished the Seal of Ascension. The gems I need are in the Spire.\"",
  choices = {
    { label = "Search the Spire for the gems", outcome = "50%: a relic, else -10 HP",
      effects = { { "gamble", 0.5,
        win = { { "relic" } },
        winText = "You find the gem in a chest of the Spire. Bodley gives you his reward.",
        lose = { { "loseHp", 10 } },
        loseText = "Orcs of the Blackhand find you first." } } },
    { label = "Buy his notes", outcome = "Pay 50g, upgrade 2 random cards",
      result = "Bodley dictates his notes on the Spire's defenders.",
      effects = { { "pay", 50 }, { "upgradeRandom", 2 } } },
    { label = "Turn the device off", outcome = "Nothing",
      result = "The ghost disappears.", effects = {} },
  },
})

event("lord_victor_nefarius", {
  name = "Lord Victor Nefarius", zone = "blackrock", tier = 0, rarity = "story", once = true,
  speaker = "Lord Victor Nefarius", npc = "lord_victor_nefarius", scene = "camp",
  when = { { "floor", 5 } },
  text = "A tall man in black and red waits at the top of the stairs. \"I am Lord Victor Nefarius. "
    .. "You have killed many of my servants. Serve me instead, and I will make you stronger.\"",
  choices = {
    { label = "Accept his gift", outcome = "-6 max HP, a relic",
      result = "Nefarius hands you a relic from his vault. You feel weaker as soon as you take it.",
      effects = { { "loseMaxHp", 6 }, { "relic" } } },
    { label = "Refuse", outcome = "Fight 2 Blackhand Veterans: usual reward + 30g",
      result = "\"Then die.\" Two of his guards step forward.",
      effects = { { "fight", "event_nefarius", gold = 30 } } },
    { label = "Walk past him", outcome = "Nothing",
      result = "Nefarius lets you pass. \"We will meet again, upstairs.\"", effects = {} },
  },
})

---------------------------------------------------------------------------
-- Commun débloqué par la première victoire du compte à Blackrock Mountain (tier = 7)
---------------------------------------------------------------------------

D.neutralCard("dark_iron_bomb", {
  tier = 7, fromZone = "blackrock", name = "Dark Iron Bomb", cost = 2, type = "attack", rarity = "rare",
  exhaust = true, effects = { { "damage", 4, all = true }, { "apply", "stunned", 1, all = true } },
  text = "Deal 4 to all.\nApply Stunned 1 ⌛ to all\nExhaust.",
  up = { effects = { { "damage", 8, all = true }, { "apply", "stunned", 1, all = true } },
    text = "Deal 8 to all.\nApply Stunned 1 ⌛ to all\nExhaust." },
})

D.neutralCard("dark_iron_ale_mug", {
  tier = 7, fromZone = "blackrock", name = "Dark Iron Ale Mug", cost = 0, type = "skill", rarity = "uncommon",
  exhaust = true, payHp = 3, effects = { { "apply", "force", 2, self = true } },
  text = "Pay 3 HP.\nGain Strength 2\nExhaust.",
  up = { payHp = 2, text = "Pay 2 HP.\nGain Strength 2\nExhaust." },
})

D.relic("blood_of_the_mountain", {
  name = "Blood of the Mountain", rarity = "common", tier = 7, fromZone = "blackrock",
  text = "The first time each enemy drops to half HP, gain 4 Absorb.",
  hooks = {
    onEnemyBloodied = function(c, src, e)
      Combat.gainBlock(c, c.player, 4)
    end,
  },
})

D.relic("black_dragonscale", {
  name = "Black Dragonscale", rarity = "uncommon", tier = 7, fromZone = "blackrock",
  text = "Enemy Cast attacks deal 4 less damage.",
  hooks = {
    beforeHit = function(c, src, dmg, enemy)
      local mv = enemy and enemy.intent and ns.Enemies[enemy.id].moves[enemy.intent]
      if mv and mv.cast and dmg > 0 then return math.max(0, dmg - 4) end
      return dmg
    end,
  },
})

-- « Treasure chests offer a choice of 2 relics » (fiche) : la récompense n'offre pas de choix de bibelot
-- (docs/zones.md § 10) ; à la place, le coffre contient aussi une potion (tirée du flux du butin).
D.relic("shadowforge_key", {
  name = "Shadowforge Key", rarity = "uncommon", tier = 7, fromZone = "blackrock",
  text = "Treasure chests also hold a potion.",
  run = {
    onRewardRolled = function(exp, r, kind)
      if kind == "chest" and not r.potion then r.potion = ns.Expedition.randomPotion(exp, exp.rng.loot) end
    end,
  },
})

---------------------------------------------------------------------------
-- Bibelots de clé (première victoire de la classe à +1, +3, +5 à Blackrock Mountain)
---------------------------------------------------------------------------

D.relic("blackhands_breadth", {
  name = "Blackhand's Breadth", rarity = "rare", key = { zone = "blackrock", level = 1 }, fromZone = "blackrock",
  text = "Attacks deal 4 more damage per hit to enemies at half HP or less.",
  hooks = {
    damage = function(c, src, v, dst, cardDef)
      if cardDef and cardDef.type == "attack" and dst and dst.side == "enemy" and dst.hp * 2 <= dst.maxHp then
        return v + 4
      end
      return v
    end,
  },
})

-- Une seule pioche quand le seuil de phase et la moitié des PV tombent sur le même coup (normaux à 50 %).
D.relic("draconic_infused_emblem", {
  name = "Draconic Infused Emblem", rarity = "rare", key = { zone = "blackrock", level = 3 }, fromZone = "blackrock",
  text = "Whenever an enemy changes phase or first drops to half HP, draw 1.",
  hooks = {
    onEnemyPhase = function(c, src, e)
      c.relicState.emblemUid, c.relicState.emblemHp = e.uid, e.hp
      Combat.drawCards(c, 1)
    end,
    onEnemyBloodied = function(c, src, e)
      local rs = c.relicState
      if rs.emblemUid == e.uid and rs.emblemHp == e.hp then return end
      Combat.drawCards(c, 1)
    end,
  },
})

D.relic("neltharions_tear", {
  name = "Neltharion's Tear", rarity = "rare", key = { zone = "blackrock", level = 5 }, fromZone = "blackrock",
  text = "The first card played each turn costs 1 less.",
  hooks = {
    cost = function(c, src, v)
      if c.phase == "player" and c.turn.played == 0 then return v - 1 end
      return v
    end,
  },
})

---------------------------------------------------------------------------
-- Case de parcours : la taverne du Grim Guzzler (commun de la zone 7, à Blackrock seulement). Une
-- boisson offerte, puis une seconde à 30 po parmi les trois autres ; effet au prochain combat seulement
-- (exp.nextCombat), sauf la Thunderbrew Lager (soin tout de suite).
---------------------------------------------------------------------------

local DRINKS = {
  { id = "ale", label = "Dark Iron Ale", outcome = "Next combat: start with Strength 2.",
    result = "Plugger pours you a mug of Dark Iron Ale. It burns on the way down.",
    effects = { { "nextCombat", { { "apply", "force", 2, self = true } } } } },
  { id = "chili", label = "Dragonbreath Chili", outcome = "Next combat: deal 6 to all enemies at the start.",
    result = "The chili is hot enough to breathe fire. You save the next breath for your enemies.",
    effects = { { "nextCombat", { { "damage", 6, all = true } } } } },
  { id = "lager", label = "Thunderbrew Lager", outcome = "Heal 12 now.",
    result = "A cold lager from Ironforge. You sit down for a moment.",
    effects = { { "heal", 12 } } },
  { id = "rum", label = "Rumsey Rum Black Label", outcome = "Next combat: start with 10 Absorb.",
    result = "Plugger hands you a bottle from under the bar. \"The good stuff.\"",
    effects = { { "nextCombat", { { "absorb", 10 } } } } },
}
local function copyEffects(list)
  local out = {}
  for i, e in ipairs(list) do out[i] = e end
  return out
end
local free = {}
for _, d in ipairs(DRINKS) do
  local fx = copyEffects(d.effects)
  fx[#fx + 1] = { "chain", "grim_guzzler_" .. d.id }
  free[#free + 1] = { label = d.label, outcome = d.outcome .. " Free.", result = d.result, effects = fx }
  -- seconde boisson, payante, parmi les trois autres
  local paid = {}
  for _, o in ipairs(DRINKS) do
    if o ~= d then
      local pfx = { { "pay", 30 } }
      for _, e in ipairs(o.effects) do pfx[#pfx + 1] = e end
      paid[#paid + 1] = { label = o.label, outcome = "Pay 30g. " .. o.outcome, result = o.result, effects = pfx }
    end
  end
  paid[#paid + 1] = { label = "Leave the bar", outcome = "Nothing",
    result = "You leave the Grim Guzzler before Plugger fills another mug.", effects = {} }
  event("grim_guzzler_" .. d.id, {
    name = "The Grim Guzzler", zone = "blackrock", tier = 7, node = true,
    speaker = "Plugger Spazzring", npc = "plugger_spazzring", scene = "shop",
    text = "\"Another round? The second one isn't free. Thirty gold, and I don't take promises.\"",
    choices = paid,
  })
end
event("grim_guzzler", {
  name = "The Grim Guzzler", zone = "blackrock", tier = 7, node = true,
  speaker = "Plugger Spazzring", npc = "plugger_spazzring", scene = "shop",
  text = "\"Welcome to the Grim Guzzler. The first drink is on the house. Pick one, and don't "
    .. "start a fight with the Dark Iron at the bar.\"",
  choices = free,
})

ns.Expedition.nodeKind("grim_guzzler", { name = "Grim Guzzler", tier = 7, zone = "blackrock",
  event = "grim_guzzler", replaces = { "event" }, minFloor = 3 })

---------------------------------------------------------------------------
-- Décors (clés d'Art.scenes, UI/Art/Zones/blackrock.lua) et zone jouable
---------------------------------------------------------------------------

ns.Zones.blackrock.scenes = {
  road = "blackrock_span", hill = "blackrock_prison", camp = "blackrock_spire", shop = "blackrock_tavern",
  night = "blackrock_forge", mine = "blackrock_lair",
}

ns.Zones.blackrock.encounters = "blackrock"
