-- Cartes et bibelots du Voleur (fiche : docs/classes/rogue.md ; règles communes : docs/classes/decisions.md).
-- Mêmes champs que Data/Warrior.lua ; règles propres (Parry, Stealth, effets du DoT) :
-- Core/Classes/rogue.lua ; art : UI/Art/rogue.lua. Chiffres de la fiche, réglés par la simulation
-- (luajit Sim/sim.lua ... class=rogue, docs/classes.md).
--
-- Combo (0 à 5, gardés d'un tour à l'autre) : « +N Combo(s). » (effet res), dépensés par
-- « Surge: » (effet surge, tous les points). Parry : charges (3 au plus) qui annulent chacune un coup
-- ennemi jusqu'à 8 dégâts, avant l'Absorb. Stealth : présent au début du combat, consommé par la
-- première carte Attack jouée (sa ligne « Stealth: » s'applique), lu sans être consommé par les Skills.
-- Voies : Assassination (DoT qui éclate), Combat (cartes à 0, Attack en chaîne), Subtlety (ouvertures).
--
-- level = niveau de classe qui débloque la carte ou le bibelot (fiche § 5 ; Core/Meta.lua).
local _, ns = ...

local Combat = ns.Combat
local C = ns.Cards

local function card(id, t)
  t.id = id
  t.class = "rogue"
  C[id] = t
end

-- Départ -------------------------------------------------------------------

card("sinister_strike", {
  level = 1, name = "Sinister Strike", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 5 }, { "res", 1 } },
  text = "Deal 5.\n+1 Combo.",
  up = { effects = { { "damage", 8 }, { "res", 1 } }, text = "Deal 8.\n+1 Combo." },
})

card("feint", {
  level = 1, name = "Feint", cost = 1, type = "skill", rarity = "basic", path = "start",
  effects = { { "apply", "parry", 1, self = true } },
  text = "Gain Parry 1",
  up = { effects = { { "draw", 1 }, { "apply", "parry", 1, self = true } }, text = "Draw 1.\nGain Parry 1" },
})

card("backstab", {
  level = 1, name = "Backstab", cost = 0, type = "attack", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 3, more = { { 7, "stealth" } } }, { "res", 1 } },
  text = "Deal 3.\n+1 Combo.\nStealth: deal 7 more.",
  up = { effects = { { "damage", 5, more = { { 9, "stealth" } } }, { "res", 1 } },
    text = "Deal 5.\n+1 Combo.\nStealth: deal 9 more." },
})

card("eviscerate", {
  level = 1, name = "Eviscerate", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "damage", 4, per = { 4, "surge" } } },
  text = "Surge: deal 4 + 4 per Combo.",
  up = { effects = { { "surge" }, { "damage", 6, per = { 5, "surge" } } }, text = "Surge: deal 6 + 5 per Combo." },
})

-- Assassination : poser du DoT en montant les points, puis le faire éclater -------------------------

card("mutilate", {
  level = 1, name = "Mutilate", cost = 1, type = "attack", rarity = "common", path = "assassination",
  target = "enemy", effects = { { "damage", 3, times = 2 }, { "res", 1 }, { "res", 1, cond = "status:pain" } },
  text = "Deal 3 twice.\n+1 Combo.\nDoT: +1 Combo.",
  up = { effects = { { "damage", 5, times = 2 }, { "res", 1 }, { "res", 1, cond = "status:pain" } },
    text = "Deal 5 twice.\n+1 Combo.\nDoT: +1 Combo." },
})

card("garrote", {
  level = 1, name = "Garrote", cost = 1, type = "attack", rarity = "common", path = "assassination",
  target = "enemy", effects = { { "damage", 3 }, { "res", 1 }, { "apply", "pain", 3, icon = "bleed" } },
  text = "Deal 3.\n+1 Combo.\nApply DoT 3",
  up = { effects = { { "damage", 4 }, { "res", 1 }, { "apply", "pain", 5, icon = "bleed" } },
    text = "Deal 4.\n+1 Combo.\nApply DoT 5" },
})

-- « Surge: apply DoT K per Combo. » : effet propre dotPer (Core/Classes/rogue.lua), comme la
-- Peste du Priest, pour que la ligne reste une clause Surge (et non une ligne d'état).
card("rupture", {
  level = 1, name = "Rupture", cost = 1, type = "skill", rarity = "common", path = "assassination",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "dotPer", 3, icon = "bleed" } },
  text = "Surge: apply DoT 3 per Combo.",
  up = { effects = { { "surge" }, { "dotPer", 4, icon = "bleed" } }, text = "Surge: apply DoT 4 per Combo." },
})

card("fan_of_knives", {
  level = 1, name = "Fan of Knives", cost = 1, type = "attack", rarity = "common", path = "assassination",
  effects = { { "damage", 3, all = true }, { "res", 1 }, { "apply", "pain", 2, all = true, icon = "poison" } },
  text = "Deal 3 to all.\n+1 Combo.\nApply DoT 2 to all",
  up = { effects = { { "damage", 4, all = true }, { "res", 1 }, { "apply", "pain", 3, all = true, icon = "poison" } },
    text = "Deal 4 to all.\n+1 Combo.\nApply DoT 3 to all" },
})

-- Envenom : jouable à 0 point (règle commune : une autre clause que le Surge), elle ne fait alors
-- qu'éclater le DoT déjà posé.
card("envenom", {
  level = 1, name = "Envenom", cost = 1, type = "attack", rarity = "uncommon", path = "assassination",
  target = "enemy", effects = { { "surge" }, { "dotPer", 2, icon = "poison" }, { "tickDot" } },
  text = "Surge: apply DoT 2 per Combo.\nIts DoT ticks now.",
  up = { effects = { { "surge" }, { "dotPer", 3, icon = "poison" }, { "tickDot" } },
    text = "Surge: apply DoT 3 per Combo.\nIts DoT ticks now." },
})

card("cloak_of_shadows", {
  level = 1, name = "Cloak of Shadows", cost = 1, type = "skill", rarity = "uncommon", path = "assassination",
  cooldown = 2, effects = { { "cleanse" }, { "apply", "parry", 1, self = true } },
  text = "Remove negative effects.\nGain Parry 1\nCooldown 2.",
  up = { effects = { { "cleanse" }, { "apply", "parry", 2, self = true } },
    text = "Remove negative effects.\nGain Parry 2\nCooldown 2." },
})

card("crippling_poison", {
  level = 2, name = "Crippling Poison", cost = 1, type = "skill", rarity = "common", path = "assassination",
  target = "enemy", effects = { { "apply", "pain", 2, icon = "poison" }, { "apply", "demoralized", 1 } },
  text = "Apply DoT 2\nApply Demoralized 1 ⌛",
  up = { effects = { { "apply", "pain", 4, icon = "poison" }, { "apply", "demoralized", 1 } },
    text = "Apply DoT 4\nApply Demoralized 1 ⌛" },
})

card("exsanguinate", {
  level = 4, name = "Exsanguinate", cost = 1, type = "skill", rarity = "rare", path = "assassination",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "tickDotPer" } },
  text = "Surge: its DoT ticks once per Combo.",
  up = { cost = 0, text = "Surge: its DoT ticks once per Combo." },
})

-- Deadly Poison : après chaque coup d'une carte Attack sur un ennemi vivant, DoT 1 (crochet
-- onAttackHit ; le crochet « apply » passe, pour Crystal Vial).
local deadlyPoisonHooks = {
  onAttackHit = function(c, power, t)
    if t.dead or c.result then return end
    local n = Combat.modify(c, "apply", 1, "pain", t)
    if n > 0 then Combat.applyStatus(c, t, "pain", n, "poison") end
  end,
}

card("deadly_poison", {
  level = 6, name = "Deadly Poison", cost = 1, type = "power", rarity = "uncommon", path = "assassination",
  power = true, effects = {}, hooks = deadlyPoisonHooks,
  text = "Power.\nEach Attack hit: apply DoT 1.",
  up = { cost = 0, text = "Power.\nEach Attack hit: apply DoT 1." },
})

local venomousHooks = {
  onTurnStart = function(c)
    local n = 0
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      if not e.dead and (e.st.pain or 0) > 0 then n = n + 1 end
    end
    if n > 0 then Combat.gainRes(c, n, "power") end
  end,
}

card("venomous_wounds", {
  level = 7, name = "Venomous Wounds", cost = 1, type = "power", rarity = "rare", path = "assassination",
  power = true, effects = {}, hooks = venomousHooks,
  text = "Power.\nStart of turn: +1 Combo per enemy with DoT.",
  up = { cost = 0, text = "Power.\nStart of turn: +1 Combo per enemy with DoT." },
})

-- Combat : cartes à 0 mana, Attack en chaîne, Parry sans casser le rythme ---------------------------

card("kick", {
  level = 1, name = "Kick", cost = 0, type = "skill", rarity = "common", path = "combat",
  target = "enemy", cooldown = 2, effects = { { "interrupt" }, { "res", 1 } },
  text = "Interrupt the target's cast.\n+1 Combo.\nCooldown 2.",
  up = { cooldown = 1, text = "Interrupt the target's cast.\n+1 Combo.\nCooldown 1." },
})

card("pistol_shot", {
  level = 1, name = "Pistol Shot", cost = 0, type = "attack", rarity = "common", path = "combat",
  target = "enemy", effects = { { "damage", 3 }, { "draw", 1 } },
  text = "Deal 3.\nDraw 1.",
  up = { effects = { { "damage", 5 }, { "draw", 1 } }, text = "Deal 5.\nDraw 1." },
})

card("sprint", {
  level = 1, name = "Sprint", cost = 0, type = "skill", rarity = "common", path = "combat",
  cooldown = 3, effects = { { "draw", 2 } },
  text = "Draw 2.\nCooldown 3.",
  up = { cooldown = 2, text = "Draw 2.\nCooldown 2." },
})

card("riposte", {
  level = 1, name = "Riposte", cost = 1, type = "attack", rarity = "common", path = "combat",
  target = "enemy", effects = { { "damage", 4 }, { "apply", "parry", 1, self = true } },
  text = "Deal 4.\nGain Parry 1",
  up = { effects = { { "damage", 7 }, { "apply", "parry", 1, self = true } }, text = "Deal 7.\nGain Parry 1" },
})

card("evasion", {
  level = 1, name = "Evasion", cost = 1, type = "skill", rarity = "uncommon", path = "combat",
  cooldown = 3, effects = { { "apply", "parry", 2, self = true } },
  text = "Gain Parry 2\nCooldown 3.",
  up = { cooldown = 2, text = "Gain Parry 2\nCooldown 2." },
})

-- Blade Flurry : après la résolution de chaque carte Attack, N à chaque ennemi vivant (dégâts du
-- joueur sans carte : Strength et Sundered comptent ; pas un coup d'Attack, donc pas de Deadly Poison).
local function bladeFlurryHooks(n)
  return {
    onCardPlayed = function(c, power, inst, ctx)
      if ctx.def.type ~= "attack" then return end
      local list = Combat.aliveEnemies(c)
      for i = 1, #list do
        local t = list[i]
        if not t.dead then Combat.dealDamage(c, c.player, t, Combat.calcDamage(c, c.player, t, n)) end
        if c.result then return end
      end
    end,
  }
end

card("blade_flurry", {
  level = 1, name = "Blade Flurry", cost = 1, type = "power", rarity = "uncommon", path = "combat",
  power = true, effects = {}, hooks = bladeFlurryHooks(2),
  text = "Power.\nAttacks: deal 2 to all.",
  up = { hooks = bladeFlurryHooks(3), text = "Power.\nAttacks: deal 3 to all." },
})

-- Slice and Dice : tant qu'aucune Attack n'a été jouée ce tour-ci (compteur c.turn.byType), les
-- cartes Attack coûtent 0. Deux exemplaires ne donnent pas deux Attack gratuites.
local sliceHooks = {
  cost = function(c, power, v, d)
    if d.type == "attack" and (c.turn.byType.attack or 0) == 0 then return 0 end
    return v
  end,
}

card("slice_and_dice", {
  level = 2, name = "Slice and Dice", cost = 1, type = "power", rarity = "uncommon", path = "combat",
  power = true, effects = {}, hooks = sliceHooks,
  text = "Power.\nFirst Attack each turn costs 0.",
  up = { cost = 0, text = "Power.\nFirst Attack each turn costs 0." },
})

card("killing_spree", {
  level = 4, name = "Killing Spree", cost = 2, type = "attack", rarity = "rare", path = "combat",
  effects = { { "randomHits", 4, times = 6 } },
  text = "Deal 4 to a random enemy six times.",
  up = { effects = { { "randomHits", 6, times = 6 } }, text = "Deal 6 to a random enemy six times." },
})

-- Between the Eyes : jouable à 0 point (autre clause que le Surge) : Stunned seul, sans dégâts.
card("between_the_eyes", {
  level = 6, name = "Between the Eyes", cost = 1, type = "attack", rarity = "uncommon", path = "combat",
  target = "enemy", cooldown = 2, effects = { { "surge" }, { "damage", 0, per = { 4, "surge" } }, { "apply", "stunned", 1 } },
  text = "Surge: deal 4 per Combo.\nApply Stunned 1 ⌛\nCooldown 2.",
  up = { effects = { { "surge" }, { "damage", 0, per = { 6, "surge" } }, { "apply", "stunned", 1 } },
    text = "Surge: deal 6 per Combo.\nApply Stunned 1 ⌛\nCooldown 2." },
})

card("adrenaline_rush", {
  level = 7, name = "Adrenaline Rush", cost = 1, type = "skill", rarity = "rare", path = "combat",
  exhaust = true, effects = { { "mana", 2 }, { "draw", 2 } },
  text = "+2 mana.\nDraw 2.\nExhaust.",
  up = { cost = 0, text = "+2 mana.\nDraw 2.\nExhaust." },
})

-- Subtlety : ouvrir sous Stealth, le retrouver, préparer l'ouverture -------------------------------

card("ambush", {
  level = 1, name = "Ambush", cost = 1, type = "attack", rarity = "common", path = "subtlety",
  target = "enemy", effects = { { "damage", 6, more = { { 12, "stealth" } } }, { "res", 2 } },
  text = "Deal 6.\n+2 Combo.\nStealth: deal 12 more.",
  up = { effects = { { "damage", 8, more = { { 16, "stealth" } } }, { "res", 2 } },
    text = "Deal 8.\n+2 Combo.\nStealth: deal 16 more." },
})

card("hemorrhage", {
  level = 1, name = "Hemorrhage", cost = 1, type = "attack", rarity = "common", path = "subtlety",
  target = "enemy", effects = { { "damage", 7 }, { "res", 1 }, { "apply", "armor_broken", 2 } },
  text = "Deal 7.\n+1 Combo.\nApply Sundered 2 ⌛",
  up = { effects = { { "damage", 9 }, { "res", 1 }, { "apply", "armor_broken", 3 } },
    text = "Deal 9.\n+1 Combo.\nApply Sundered 3 ⌛" },
})

card("vanish", {
  level = 1, name = "Vanish", cost = 0, type = "skill", rarity = "common", path = "subtlety",
  exhaust = true, effects = { { "draw", 1 }, { "apply", "stealth", 1, self = true } },
  text = "Draw 1.\nGain Stealth\nExhaust.",
  up = { effects = { { "draw", 2 }, { "apply", "stealth", 1, self = true } }, text = "Draw 2.\nGain Stealth\nExhaust." },
})

card("shadowstep", {
  level = 1, name = "Shadowstep", cost = 1, type = "skill", rarity = "common", path = "subtlety",
  cooldown = 2, effects = { { "apply", "parry", 1, self = true }, { "apply", "stealth", 1, self = true } },
  text = "Gain Parry 1\nGain Stealth\nCooldown 2.",
  up = { cooldown = 1, text = "Gain Parry 1\nGain Stealth\nCooldown 1." },
})

-- Cheap Shot : Skill, lit Stealth sans le consommer ; l'état posé sous condition reste dans sa clause.
card("cheap_shot", {
  level = 1, name = "Cheap Shot", cost = 1, type = "skill", rarity = "uncommon", path = "subtlety",
  target = "enemy", cooldown = 2, effects = { { "res", 2 }, { "apply", "stunned", 1, cond = "stealth" } },
  text = "+2 Combo.\nStealth: apply Stunned 1 ⌛\nCooldown 2.",
  up = { cost = 0, text = "+2 Combo.\nStealth: apply Stunned 1 ⌛\nCooldown 2." },
})

-- Secret Technique : jouable à 0 point (règle commune : la ligne Stealth n'est pas un Surge).
card("secret_technique", {
  level = 1, name = "Secret Technique", cost = 1, type = "attack", rarity = "uncommon", path = "subtlety",
  effects = { { "surge" }, { "damage", 0, per = { 4, "surge" }, all = true },
    { "damage", 0, per = { 4, "surge" }, all = true, cond = "stealth" } },
  text = "Surge: deal 4 per Combo to all.\nStealth: hits twice.",
  up = { effects = { { "surge" }, { "damage", 0, per = { 5, "surge" }, all = true },
    { "damage", 0, per = { 5, "surge" }, all = true, cond = "stealth" } },
    text = "Surge: deal 5 per Combo to all.\nStealth: hits twice." },
})

-- Nightblade : coup de grâce mono-cible de la voie (ajouté le 12/11/2026, décision du joueur : Subtlety
-- jouée seule à 19-26 %). Il rend Stealth après le coup (la carte, une Attack, consomme d'abord un
-- Stealth présent) : l'ouverture suivante (Backstab, Ambush) est prête. Jouable à 0 point (autre clause
-- que le Surge) : Stealth seul. Débloqué au niveau 3, avec Flash Powder.
card("nightblade", {
  level = 3, name = "Nightblade", cost = 1, type = "attack", rarity = "common", path = "subtlety",
  target = "enemy", effects = { { "surge" }, { "damage", 0, per = { 6, "surge" } },
    { "apply", "stealth", 1, self = true } },
  text = "Surge: deal 6 per Combo.\nGain Stealth",
  up = { effects = { { "surge" }, { "damage", 0, per = { 8, "surge" } }, { "apply", "stealth", 1, self = true } },
    text = "Surge: deal 8 per Combo.\nGain Stealth" },
})

card("premeditation", {
  level = 2, name = "Premeditation", cost = 0, type = "skill", rarity = "uncommon", path = "subtlety",
  effects = { { "draw", 1 }, { "res", 2, cond = "stealth" } },
  text = "Draw 1.\nStealth: +2 Combo.",
  up = { effects = { { "draw", 2 }, { "res", 2, cond = "stealth" } }, text = "Draw 2.\nStealth: +2 Combo." },
})

local cheatDeathHooks = {
  preventDeath = function(c, power)
    if not Combat.lastBreath(c, "cheat_death") then return false end
    c.player.hp = 1
    Combat.applyStatus(c, c.player, "parry", 3)
    Combat.applyStatus(c, c.player, "stealth", 1)
    return true
  end,
}

card("cheat_death", {
  level = 4, name = "Cheat Death", cost = 1, type = "power", rarity = "rare", path = "subtlety",
  power = true, effects = {}, hooks = cheatDeathHooks,
  text = "Power.\nLast Breath: stay at 1 HP, gain Parry 3 and Stealth.",
  up = { cost = 0, text = "Power.\nLast Breath: stay at 1 HP, gain Parry 3 and Stealth." },
})

card("smoke_bomb", {
  level = 6, name = "Smoke Bomb", cost = 1, type = "skill", rarity = "uncommon", path = "subtlety",
  cooldown = 4, effects = { { "apply", "demoralized", 2, all = true }, { "apply", "stealth", 1, self = true } },
  text = "Apply Demoralized 2 ⌛ to all\nGain Stealth\nCooldown 4.",
  up = { cooldown = 3, text = "Apply Demoralized 2 ⌛ to all\nGain Stealth\nCooldown 3." },
})

local shadowDanceHooks = {
  onTurnStart = function(c)
    Combat.applyStatus(c, c.player, "stealth", 1)
  end,
}

card("shadow_dance", {
  level = 7, name = "Shadow Dance", cost = 2, type = "power", rarity = "rare", path = "subtlety",
  power = true, effects = {}, hooks = shadowDanceHooks,
  text = "Power.\nStart of turn: gain Stealth.",
  up = { cost = 1, text = "Power.\nStart of turn: gain Stealth." },
})

-- Cartes épiques (une par zone, docs/zones/cartes-de-zone.md, « Rogue ») ------------------------------
-- Règles en jeu dès le début de chaque combat (Combat.new : c.epic), jamais piochées ni jouées (cost 0 :
-- contrat des données de Sim/tests.lua, jamais payé ni affiché). Leurs crochets (deckHooks, src = c.epic)
-- sont posés par Core/Classes/rogue.lua ; « Epic. » = mot de plaque en tête.
-- Nombres des épiques (base, amélioré), seule source : les textes ci-dessous et les règles
-- (Core/Classes/rogue.lua, ns.Rogue.EPIC) les lisent. Fiche entre parenthèses ; réglés le 14/11/2026 sur
-- les zones dures (Duskwood, Stranglethorn, Steppes ; simulation epic=<id>, docs/classes.md).
local EPIC_N = {
  deflection = { 1, 2 },          -- première riposte du tour (fiche : 3 / 4)
  deflectionStep = { 2, 2 },      -- de plus par riposte précédente du tour : k-ième = N + S × (k − 1) (fiche : 3 / 4)
  doomblade = { 0.9, 1 },         -- part des dégâts d'un coup de grâce posée en DoT, arrondie au-dessus (fiche : ½ / 1)
  atrophic_poison = { 5, 5 },     -- DoT montré (avant son tic) qu'il faut au moins (fiche : 2, « garde du DoT après son tic »)
  echoing_reprimand = { 3, 4 },   -- un Surge de 2 (à M) Combo compte N (fiche : 5 / 6)
  echoingMax = { 2, 3 },          -- M : dépense la plus haute qui compte N (fiche : 3)
  subterfuge = { 0, 0 },          -- Combo par Stealth gagné (fiche : 0 / 1 ; la ligne ne tient plus sur la carte)
  subterfugeTurns = { 2, 3 },     -- tours que dure un Stealth (le tour où il est gagné compris ; fiche : 1)
  subterfugeSurge = { true, true }, -- chaque Surge rend Stealth (source incluse ; fiche : aucune)
  kidney_shot = { 5, 4 },         -- Combo dépensés au moins (fiche : 5 / 4)
  danse_macabre = { 2, 3 },       -- par autre nom joué dans le tour, au-delà des F premiers (fiche : 2 / 3)
  danseFree = { 2, 2 },           -- F : autres noms joués qui ne comptent pas encore (fiche : 0)
  danseCap = { 0, 0 },            -- bonus par coup au plus, 0 = sans plafond (fiche : aucun ; repli de la fiche : +10)
}
ns.RogueEpicNumbers = EPIC_N

-- Déclencheur de Kidney Shot selon le seuil : « Surge of 5+ Combo », « Surge of 4+ Combo » (« 5+ » même au
-- plafond de 5 : « Surge of 5 Combo » se coupait entre « of » et « 5 » pour tenir en deux lignes).
local function kidneyLabel(k) return ("Surge of %d+ Combo"):format(k) end
ns.RogueKidneyLabel = kidneyLabel

local function epic(id, zone, path, name, text)
  local function t(k) return "Epic.\n" .. (type(text) == "function" and text(k) or text[k]) end
  card(id, { zone = zone, rarity = "epic", epic = true, name = name, cost = 0, type = "power", power = true,
    path = path, effects = {}, text = t(1), up = { text = t(2) } })
end
local function n(id, k) return tostring(EPIC_N[id][k]) end

-- Textes : déclencheur et mot de règle (deux lignes au plus) ; la règle complète est l'à-côté du mot
-- (L.rule, Core/Classes/rogue.lua), écrite avec les mêmes nombres.
epic("deflection", "westfall", "combat", "Deflection", function(k)
  return "Each Parry gained: Riposte " .. n("deflection", k) .. "."
end)
epic("doomblade", "duskwood", "assassination", "Doomblade", function(k)
  return "Surge Attacks: Bleed " .. math.floor(EPIC_N.doomblade[k] * 100 + 0.5) .. "%."
end)
epic("atrophic_poison", "wetlands", "assassination", "Atrophic Poison", function(k)
  return "DoT " .. n("atrophic_poison", k) .. "+: Atrophy" .. (k == 2 and ", Sundered." or ".")
end)
epic("echoing_reprimand", "stranglethorn", "combat", "Echoing Reprimand", function(k)
  return "Surge cards: Animacharge " .. n("echoing_reprimand", k) .. "."
end)
epic("subterfuge", "swamp", "subtlety", "Subterfuge", function(k)
  return "Surge cards: Shroud " .. n("subterfugeTurns", k) .. "."
end)
epic("kidney_shot", "steppes", "subtlety", "Kidney Shot", function(k)
  return kidneyLabel(EPIC_N.kidney_shot[k]) .. ": Gouge."
end)
epic("danse_macabre", "blackrock", "subtlety", "Danse Macabre", function(k)
  return "Attack hits: Flourish " .. n("danse_macabre", k) .. "."
end)

-- Bibelots du Voleur (class = "rogue" : tirés seulement pour lui) ---------------------------------
-- level = niveau de classe qui les débloque (dans la réserve de la classe ; la Ligue ne compte pas).

local R = ns.Relics
local function relic(id, t)
  t.id = id
  t.class = "rogue"
  t.hooks = t.hooks or {}
  R[id] = t
end

-- Bibelot de départ (GDD) : une carte de plus au premier tour.
relic("thieves_tools", {
  level = 1, name = "Thieves' Tools", rarity = "common", noPool = true,
  text = "On the first turn of each combat, draw 1 more card.",
  hooks = {
    drawPerTurn = function(c, src, v)
      if c.round == 1 then return v + 1 end
      return v
    end,
  },
})

relic("blinding_powder", {
  level = 1, name = "Blinding Powder", rarity = "common",
  text = "At the start of each combat, gain Parry 1.",
  hooks = {
    onCombatStart = function(c) Combat.applyStatus(c, c.player, "parry", 1) end,
  },
})

-- Flash Powder : seulement quand une carte fait passer Stealth d'absent à présent (le Stealth du début
-- de combat ne compte pas) : c.cls.stealthGained, posé par la règle de classe juste avant ce crochet.
relic("flash_powder", {
  level = 3, name = "Flash Powder", rarity = "uncommon",
  text = "Each time a card grants Stealth, draw 1 card.",
  hooks = {
    onStatusApplied = function(c, src, unit, id)
      if id == "stealth" and unit == c.player and c.cls.stealthGained then Combat.drawCards(c, 1) end
    end,
  },
})

relic("crystal_vial", {
  level = 5, name = "Crystal Vial", rarity = "uncommon",
  text = "Each time DoT is applied to an enemy, apply 1 more.",
  hooks = {
    apply = function(c, src, n, id)
      if id == "pain" and n > 0 then return n + 1 end
      return n
    end,
  },
})

relic("ravenholdt_signet", {
  level = 7, name = "Ravenholdt Signet", rarity = "rare",
  text = "After each Surge, gain Parry 1.",
  hooks = {
    onSurge = function(c) Combat.applyStatus(c, c.player, "parry", 1) end,
  },
})

relic("shadowfang", {
  level = 7, name = "Shadowfang", rarity = "rare",
  text = "At the start of each combat, +2 Combo.",
  hooks = {
    onCombatStart = function(c) Combat.gainRes(c, 2, "relic") end,
  },
})

-- Classe ------------------------------------------------------------------------

ns.Classes.rogue = {
  id = "rogue", name = "Rogue", order = 3, hp = 50,
  resource = { id = "combo", cap = 5, keep = true },
  -- 5 Sinister Strike, 3 Feint (décision du joueur, 12/11/2026 : Parry annulait presque tous les coups des
  -- normaux avec 4 Feint). Le deck tue plus vite sans perdre plus de PV : les PV n'ont pu monter que de
  -- 49 à 50 sans sortir des cibles de victoires (docs/equilibrage.md, « Passe 2 »).
  deck = {
    "sinister_strike", "sinister_strike", "sinister_strike", "sinister_strike", "sinister_strike",
    "feint", "feint", "feint",
    "backstab", "eviscerate",
  },
  startRelic = "thieves_tools",
  paths = { { id = "assassination", name = "Assassination" }, { id = "combat", name = "Combat" },
    { id = "subtlety", name = "Subtlety" } },
  survival = "kill",
  bot = {
    resValue = 8,
    -- 12/11/2026 : Nightblade 9 (coup de grâce : le balayage sous-évalue les Surge, comme Rupture et
    -- Envenom) ; Shadowstep, Secret Technique, Hemorrhage, Vanish relevées au-dessus de 5 (positives au
    -- balayage avec le nouveau deck de départ, reports/sw2-rogue-l7) ; le reste inchangé (un rebalayage
    -- complet fait perdre 10 à 20 points au bot : il sous-cote les Surge et les moteurs).
    rating = {
      blade_flurry = 13.5, deadly_poison = 12, envenom = 12, rupture = 12, adrenaline_rush = 10,
      nightblade = 9, fan_of_knives = 8, ambush = 7.5, crippling_poison = 7.5, slice_and_dice = 7.5,
      smoke_bomb = 7.5, shadowstep = 7, sprint = 7, between_the_eyes = 6.5, evasion = 6.5, pistol_shot = 6.5,
      killing_spree = 6, secret_technique = 6, cheap_shot = 5.5, cheat_death = 5.5, hemorrhage = 5.5,
      kick = 5.5, premeditation = 5.5, vanish = 5.5, garrote = 4.5, riposte = 4.5, cloak_of_shadows = 4,
      mutilate = 3.5, exsanguinate = 3, shadow_dance = 3, venomous_wounds = 3,
    },
    upgrade = { sinister_strike = 2.5, feint = 2, backstab = 2.5, eviscerate = 3 },
    remove = { feint = 1.5, sinister_strike = 1 },
  },
}

-- Bots et cartes épiques : note de chaque épique (offre, marchand ; l'épique du deck vaut EPIC_KEEP de plus :
-- le deck est déjà construit autour, en changer est un pari) et conseils du build qu'elle pilote
-- (bot.byEpic, lus par Sim/expedition.lua : notes des cartes, améliorations, retraits ; fiche « Deck piloté »).
do
  local bot = ns.Classes.rogue.bot
  local EPIC_RATING = { deflection = 9, doomblade = 9, atrophic_poison = 9, echoing_reprimand = 9,
    subterfuge = 9, kidney_shot = 9, danse_macabre = 9 }
  local EPIC_KEEP = 2
  bot.epic = function(exp, id)
    local v = EPIC_RATING[id]
    if not v then return nil end
    for _, cd in ipairs(exp.deck) do if cd.id == id then return v + EPIC_KEEP end end
    return v
  end
  local function copies(exp, id)
    local n = 0
    for _, cd in ipairs(exp.deck) do if cd.id == id then n = n + 1 end end
    return n
  end
  bot.byEpic = {
    -- les Feint et toutes les cartes de Parry deviennent offensives ; Sinister Strike part
    deflection = {
      rating = { riposte = 9, evasion = 10, shadowstep = 9, cloak_of_shadows = 8.5, hemorrhage = 7.5,
        pistol_shot = 8, sprint = 8.5, cheat_death = 7, smoke_bomb = 6.5, between_the_eyes = 5, envenom = 9,
        rupture = 9, killing_spree = 4.5 },
      upgrade = { feint = 4, deflection = 4.5, evasion = 3.5, riposte = 3, sinister_strike = 1.5 },
      remove = { sinister_strike = 0.5, feint = 9 },
    },
    -- les coups de grâce posent du DoT, Envenom et Exsanguinate l'encaissent
    doomblade = {
      rating = { nightblade = 11, secret_technique = 10, between_the_eyes = 9, envenom = 13, exsanguinate = 10,
        garrote = 7, mutilate = 7.5, venomous_wounds = 8, deadly_poison = 12, ambush = 6, killing_spree = 4 },
      upgrade = { eviscerate = 5, doomblade = 4.5, exsanguinate = 4, envenom = 3.5 },
      remove = { sinister_strike = 1 },
    },
    -- tous les ennemis sous DoT, donc Demoralized ; la défense en double part
    atrophic_poison = {
      rating = { fan_of_knives = 12, garrote = 8.5, crippling_poison = 9, deadly_poison = 13, rupture = 12.5,
        mutilate = 6, venomous_wounds = 7, evasion = 4, smoke_bomb = 5, exsanguinate = 2, cloak_of_shadows = 3 },
      upgrade = { fan_of_knives = 5, atrophic_poison = 4.5, garrote = 3.5, sinister_strike = 2.5 },
      remove = { feint = 0.5, sinister_strike = 1.2 },
    },
    -- finir à 2 ou 3 Combo, deux coups de grâce par tour
    echoing_reprimand = {
      rating = { ambush = 9.5, cheap_shot = 9.5, premeditation = 8.5, mutilate = 7, kick = 7.5, rupture = 13,
        envenom = 13, between_the_eyes = 8.5, nightblade = 11, secret_technique = 8.5, exsanguinate = 7,
        slice_and_dice = 8 },
      upgrade = { eviscerate = 5, echoing_reprimand = 4.5, sinister_strike = 2 },
      remove = { sinister_strike = 0.8 },
    },
    -- plusieurs ouvertures par tour sous Stealth
    subterfuge = {
      rating = { ambush = 12, secret_technique = 10, cheap_shot = 9, premeditation = 8.5, vanish = 9,
        shadowstep = 9.5, smoke_bomb = 9, shadow_dance = 9, nightblade = 10, killing_spree = 5 },
      upgrade = { backstab = 5, subterfuge = 4.5, sinister_strike = 2 },
      remove = { sinister_strike = 0.6, feint = 1.2 },
    },
    -- monter à 5 chaque tour, le coup de grâce étourdit
    kidney_shot = {
      rating = { ambush = 9.5, cheap_shot = 10, premeditation = 8.5, mutilate = 7, kick = 7.5,
        between_the_eyes = 9.5, rupture = 12, envenom = 12, nightblade = 10, secret_technique = 4,
        fan_of_knives = 5 },
      upgrade = { cheap_shot = 5, kidney_shot = 4.5, eviscerate = 4 },
      remove = { feint = 0.6, sinister_strike = 1.2 },
    },
    -- que des cartes différentes : un doublon vaut peu, le dernier exemplaire reste
    danse_macabre = {
      rating = function(exp, id)
        local base = ns.Run and ns.Run.RATING and ns.Run.RATING[id] or 5
        local bonus = { killing_spree = 4, pistol_shot = 2, kick = 2.5, sprint = 2, vanish = 2, premeditation = 2,
          adrenaline_rush = 2, ambush = 1.5, hemorrhage = 2 }
        if copies(exp, id) > 0 then return math.min(base, 4) end
        return base + 1 + (bonus[id] or 0)
      end,
      upgrade = { killing_spree = 5, danse_macabre = 4.5 },
      remove = function(exp, id)
        if copies(exp, id) <= 1 then return nil end
        if id == "sinister_strike" then return 0.5 end
        if id == "feint" then return 0.8 end
        return 1.4
      end,
    },
  }
end
