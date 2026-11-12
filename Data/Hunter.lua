-- Cartes et bibelots du Chasseur (fiche : docs/classes/hunter.md ; décisions : docs/classes/decisions.md).
-- Mêmes champs que Data/Warrior.lua ; règles propres (familier, Frenzy, Careful Aim, effets « pet » et
-- « readiness ») : Core/Classes/hunter.lua ; art et vue de classe : UI/Art/hunter.lua.
--
-- Familier : attaque seul à la fin de chaque tour (ns.Hunter.PET_BASE + Frenzy, soit 1 + Frenzy, sur la dernière cible visée), puis +1 Frenzy.
-- « Pet attacks. » = effet { "pet", n } (n attaques tout de suite). Frenzy (0 à 5, ressource de classe)
-- baisse de 1 à chaque tour sauf le premier. Traps : champ trap (mécanisme commun, Core/Combat.lua).
-- Voies : Beast Mastery (Frenzy et ordres au familier), Marksmanship (gros tirs sur cible intacte, Careful
-- Aim), Survival (Traps, DoT).
--
-- level = niveau de classe qui débloquera la carte (fiche, § 5 Progression, 1 à 7) : posé, PAS encore
-- appliqué (la progression par classe viendra dans un autre lot). rep = palier de réputation lu par le
-- socle aujourd'hui (20/5/5) : les 30 cartes triées par level, les 20 premières à 0, les 5 suivantes à 1,
-- les 5 dernières à 2 (à égalité de level, la carte la plus simple d'abord).
local _, ns = ...

local Combat = ns.Combat
local C = ns.Cards

local function card(id, t)
  t.id = id
  t.class = "hunter"
  C[id] = t
end

local function H() return ns.Hunter end -- règles (Core/Classes/hunter.lua, chargé après ce fichier)

-- Départ -------------------------------------------------------------------

card("arcane_shot", {
  level = 1, name = "Arcane Shot", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 3 }, { "pet", 1 } },
  text = "Deal 3.\nPet attacks.",
  up = { effects = { { "damage", 6 }, { "pet", 1 } }, text = "Deal 6.\nPet attacks." },
})

card("disengage", {
  level = 1, name = "Disengage", cost = 1, type = "skill", rarity = "basic", path = "start",
  effects = { { "absorb", 5 } },
  text = "Gain 5 Absorb.",
  up = { effects = { { "absorb", 8 } }, text = "Gain 8 Absorb." },
})

card("serpent_sting", {
  level = 1, name = "Serpent Sting", cost = 1, type = "skill", rarity = "basic", path = "start",
  target = "enemy", effects = { { "draw", 1 }, { "apply", "pain", 5, icon = "sting" } },
  text = "Draw 1.\nApply DoT 5",
  up = { effects = { { "draw", 1 }, { "apply", "pain", 7, icon = "sting" } }, text = "Draw 1.\nApply DoT 7" },
})

card("freezing_trap", {
  level = 1, name = "Freezing Trap", cost = 1, type = "skill", rarity = "basic", path = "start",
  trap = true, effects = { { "apply", "stunned", 1 }, { "apply", "demoralized", 1 } },
  text = "Trap.\nApply Stunned 1 ⌛\nApply Demoralized 1 ⌛",
  up = { effects = { { "apply", "stunned", 1 }, { "apply", "demoralized", 2 } },
    text = "Trap.\nApply Stunned 1 ⌛\nApply Demoralized 2 ⌛" },
})

-- Beast Mastery : chaque carte commande le familier ou lui donne du Frenzy -------------------------

card("kill_command", {
  level = 1, rep = 0, name = "Kill Command", cost = 1, type = "attack", rarity = "common", path = "beast_mastery",
  target = "enemy", cooldown = 2, effects = { { "pet", 2 } },
  text = "Pet attacks twice.\nCooldown 2.",
  up = { cooldown = 1, text = "Pet attacks twice.\nCooldown 1." },
})

card("cobra_shot", {
  level = 1, rep = 0, name = "Cobra Shot", cost = 1, type = "attack", rarity = "common", path = "beast_mastery",
  target = "enemy", effects = { { "damage", 5 }, { "res", 1 } },
  text = "Deal 5.\n+1 Frenzy.",
  up = { effects = { { "damage", 8 }, { "res", 1 } }, text = "Deal 8.\n+1 Frenzy." },
})

card("barbed_shot", {
  level = 1, rep = 0, name = "Barbed Shot", cost = 1, type = "skill", rarity = "common", path = "beast_mastery",
  target = "enemy", effects = { { "res", 2 }, { "apply", "pain", 3, icon = "bleed" } },
  text = "+2 Frenzy.\nApply DoT 3",
  up = { effects = { { "res", 2 }, { "apply", "pain", 5, icon = "bleed" } }, text = "+2 Frenzy.\nApply DoT 5" },
})

card("dire_beast", {
  level = 2, rep = 0, name = "Dire Beast", cost = 0, type = "skill", rarity = "common", path = "beast_mastery",
  target = "enemy", exhaust = true, effects = { { "pet", 1 } },
  text = "Pet attacks.\nExhaust.",
  up = { effects = { { "pet", 2 } }, text = "Pet attacks twice.\nExhaust." },
})

-- Growl : Spend 2 retire 2 Frenzy (le familier frappera moins fort) contre de l'Absorb en plus.
card("growl", {
  level = 1, rep = 0, name = "Growl", cost = 1, type = "skill", rarity = "common", path = "beast_mastery",
  spend = 2, effects = { { "absorb", 6, more = { { 6, "spent" } } } },
  text = "Gain 6 Absorb.\nSpend 2: gain 6 more.",
  up = { effects = { { "absorb", 8, more = { { 8, "spent" } } } }, text = "Gain 8 Absorb.\nSpend 2: gain 8 more." },
})

card("intimidation", {
  level = 1, rep = 0, name = "Intimidation", cost = 1, type = "skill", rarity = "uncommon", path = "beast_mastery",
  target = "enemy", cooldown = 3, effects = { { "pet", 1 }, { "apply", "stunned", 1 } },
  text = "Pet attacks.\nApply Stunned 1 ⌛\nCooldown 3.",
  up = { cooldown = 2, text = "Pet attacks.\nApply Stunned 1 ⌛\nCooldown 2." },
})

-- Multi-Shot : sans cible, le familier reste sur la sienne.
card("multi_shot", {
  level = 4, rep = 1, name = "Multi-Shot", cost = 1, type = "attack", rarity = "uncommon", path = "beast_mastery",
  effects = { { "damage", 4, all = true }, { "pet", 1 } },
  text = "Deal 4 to all.\nPet attacks.",
  up = { effects = { { "damage", 6, all = true }, { "pet", 1 } }, text = "Deal 6 to all.\nPet attacks." },
})

-- Spirit Bond : chaque attaque du familier (automatique, commandée ou de Surge) donne de l'Absorb.
local spiritBondHooks = {
  onPetAttack = function(c) Combat.gainBlock(c, c.player, 2) end,
}

card("spirit_bond", {
  level = 6, rep = 1, name = "Spirit Bond", cost = 2, type = "power", rarity = "uncommon", path = "beast_mastery",
  power = true, effects = {}, hooks = spiritBondHooks,
  text = "Power.\nPet attacks: gain 2 Absorb.",
  up = { cost = 1, text = "Power.\nPet attacks: gain 2 Absorb." },
})

-- Bestial Wrath : une attaque par point de Frenzy, chacune à 1 + le Frenzy compté, sans en redonner ;
-- coût 2 (fiche : 1, levier prévu par la fiche, risque 3).
card("bestial_wrath", {
  level = 1, rep = 0, name = "Bestial Wrath", cost = 2, type = "skill", rarity = "rare", path = "beast_mastery",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "pet", 0, per = { 1, "surge" }, surge = true } },
  text = "Surge: pet attacks once per Frenzy.",
  up = { cost = 1, text = "Surge: pet attacks once per Frenzy." },
})

-- The Beast Within : après la résolution de chaque carte Attack (une carte Cast : à sa résolution).
local beastWithinHooks = {
  onCardPlayed = function(c, power, inst, ctx)
    if ctx.def.type == "attack" and not c.result then H().petAttack(c, "card") end
  end,
}

card("the_beast_within", {
  level = 7, rep = 2, name = "The Beast Within", cost = 2, type = "power", rarity = "rare", path = "beast_mastery",
  power = true, effects = {}, hooks = beastWithinHooks,
  text = "Power.\nAttacks: pet attacks.",
  up = { cost = 1, text = "Power.\nAttacks: pet attacks." },
})

-- Marksmanship : Careful Aim (cible au-dessus de la moitié de ses PV), tirs en Cast ----------------

card("aimed_shot", {
  level = 1, rep = 0, name = "Aimed Shot", cost = 2, type = "attack", rarity = "common", path = "marksmanship",
  target = "enemy", cast = true, effects = { { "damage", 20, more = { { 10, "careful" } } } },
  text = "Cast.\nDeal 20.\nCareful Aim: deal 10 more.",
  up = { effects = { { "damage", 26, more = { { 12, "careful" } } } }, text = "Cast.\nDeal 26.\nCareful Aim: deal 12 more." },
})

card("steady_shot", {
  level = 1, rep = 0, name = "Steady Shot", cost = 1, type = "attack", rarity = "common", path = "marksmanship",
  target = "enemy", cast = true, effects = { { "damage", 10 }, { "draw", 1, cond = "careful" } },
  text = "Cast.\nDeal 10.\nCareful Aim: draw 1.",
  up = { effects = { { "damage", 14 }, { "draw", 1, cond = "careful" } }, text = "Cast.\nDeal 14.\nCareful Aim: draw 1." },
})

card("hunters_mark", {
  level = 1, rep = 0, name = "Hunter's Mark", cost = 0, type = "skill", rarity = "common", path = "marksmanship",
  target = "enemy", exhaust = true, effects = { { "apply", "armor_broken", 3 } },
  text = "Apply Sundered 3 ⌛\nExhaust.",
  up = { effects = { { "apply", "armor_broken", 5 } }, text = "Apply Sundered 5 ⌛\nExhaust." },
})

card("concussive_shot", {
  level = 1, rep = 0, name = "Concussive Shot", cost = 1, type = "attack", rarity = "common", path = "marksmanship",
  target = "enemy", effects = { { "damage", 4 }, { "apply", "demoralized", 2 } },
  text = "Deal 4.\nApply Demoralized 2 ⌛",
  up = { effects = { { "damage", 7 }, { "apply", "demoralized", 2 } }, text = "Deal 7.\nApply Demoralized 2 ⌛" },
})

card("rapid_fire", {
  level = 1, rep = 0, name = "Rapid Fire", cost = 1, type = "attack", rarity = "uncommon", path = "marksmanship",
  target = "enemy", cooldown = 2, effects = { { "damage", 3, times = 4 } },
  text = "Deal 3 four times.\nCooldown 2.",
  up = { effects = { { "damage", 4, times = 4 } }, text = "Deal 4 four times.\nCooldown 2." },
})

card("counter_shot", {
  level = 1, rep = 0, name = "Counter Shot", cost = 0, type = "skill", rarity = "uncommon", path = "marksmanship",
  target = "enemy", cooldown = 2, effects = { { "interrupt" }, { "pet", 1 } },
  text = "Interrupt the target's cast.\nPet attacks.\nCooldown 2.",
  up = { cooldown = 1, text = "Interrupt the target's cast.\nPet attacks.\nCooldown 1." },
})

card("volley", {
  level = 2, rep = 0, name = "Volley", cost = 2, type = "attack", rarity = "uncommon", path = "marksmanship",
  cast = true, effects = { { "damage", 13, all = true } },
  text = "Cast.\nDeal 13 to all.",
  up = { effects = { { "damage", 17, all = true } }, text = "Cast.\nDeal 17 to all." },
})

card("readiness", {
  level = 4, rep = 1, name = "Readiness", cost = 0, type = "skill", rarity = "uncommon", path = "marksmanship",
  exhaust = true, effects = { { "readiness" } },
  text = "Return Cooldown cards to hand.\nExhaust.",
  up = { effects = { { "readiness" }, { "draw", 1 } }, text = "Return Cooldown cards to hand.\nDraw 1.\nExhaust." },
})

-- Trueshot Aura : +N par coup des cartes Attack sur une cible au-dessus de la moitié de ses PV, vérifié
-- coup par coup (le familier n'est pas une carte : rien).
local function trueshotHooks(n)
  return {
    damage = function(c, power, v, dst, cardDef)
      if cardDef and cardDef.type == "attack" and dst and dst.hp * 2 > dst.maxHp then return v + n end
      return v
    end,
  }
end

card("trueshot_aura", {
  level = 6, rep = 2, name = "Trueshot Aura", cost = 1, type = "power", rarity = "rare", path = "marksmanship",
  power = true, effects = {}, hooks = trueshotHooks(4),
  text = "Power.\nCareful Aim: Attacks deal 4 more.",
  up = { hooks = trueshotHooks(6), text = "Power.\nCareful Aim: Attacks deal 6 more." },
})

card("wailing_arrow", {
  level = 7, rep = 2, name = "Wailing Arrow", cost = 1, type = "attack", rarity = "rare", path = "marksmanship",
  exhaust = true, effects = { { "damage", 8, all = true }, { "interrupt", all = true } },
  text = "Deal 8 to all.\nInterrupt all casts.\nExhaust.",
  up = { effects = { { "damage", 12, all = true }, { "interrupt", all = true } },
    text = "Deal 12 to all.\nInterrupt all casts.\nExhaust." },
})

-- Survival : Traps posées pendant le tour, déclenchées par les attaques ennemies ------------------

card("immolation_trap", {
  level = 1, rep = 0, name = "Immolation Trap", cost = 1, type = "skill", rarity = "common", path = "survival",
  trap = true, effects = { { "apply", "pain", 7, icon = "immolation" } },
  text = "Trap.\nApply DoT 7",
  up = { effects = { { "apply", "pain", 9, icon = "immolation" } }, text = "Trap.\nApply DoT 9" },
})

card("counterattack", {
  level = 1, rep = 0, name = "Counterattack", cost = 1, type = "skill", rarity = "common", path = "survival",
  trap = true, effects = { { "damage", 10 } },
  text = "Trap.\nDeal 10.",
  up = { effects = { { "damage", 14 } }, text = "Trap.\nDeal 14." },
})

card("frost_trap", {
  level = 1, rep = 0, name = "Frost Trap", cost = 1, type = "skill", rarity = "common", path = "survival",
  trap = true, effects = { { "apply", "demoralized", 1, all = true } },
  text = "Trap.\nApply Demoralized 1 ⌛ to all",
  up = { effects = { { "apply", "demoralized", 2, all = true } }, text = "Trap.\nApply Demoralized 2 ⌛ to all" },
})

card("raptor_strike", {
  level = 1, rep = 0, name = "Raptor Strike", cost = 1, type = "attack", rarity = "common", path = "survival",
  target = "enemy", effects = { { "damage", 5 }, { "absorb", 3 } },
  text = "Deal 5.\nGain 3 Absorb.",
  up = { effects = { { "damage", 8 }, { "absorb", 4 } }, text = "Deal 8.\nGain 4 Absorb." },
})

card("explosive_trap", {
  level = 1, rep = 0, name = "Explosive Trap", cost = 1, type = "skill", rarity = "uncommon", path = "survival",
  trap = true,
  effects = { { "damage", 6, all = true }, { "apply", "pain", 3, all = true, icon = "immolation" } },
  text = "Trap.\nDeal 6 to all.\nApply DoT 3 to all",
  up = { effects = { { "damage", 8, all = true }, { "apply", "pain", 4, all = true, icon = "immolation" } },
    text = "Trap.\nDeal 8 to all.\nApply DoT 4 to all" },
})

card("wyvern_sting", {
  level = 1, rep = 0, name = "Wyvern Sting", cost = 1, type = "skill", rarity = "uncommon", path = "survival",
  target = "enemy", cooldown = 3,
  effects = { { "apply", "stunned", 1 }, { "apply", "pain", 6, icon = "sting" } },
  text = "Apply Stunned 1 ⌛\nApply DoT 6\nCooldown 3.",
  up = { cooldown = 2, text = "Apply Stunned 1 ⌛\nApply DoT 6\nCooldown 2." },
})

-- Entrapment : chaque Trap déclenchée pose aussi Demoralized 1 sur l'attaquant (même une Trap « to all »).
local entrapmentHooks = {
  onTrapTriggered = function(c, power, inst, enemy)
    if enemy and not enemy.dead then Combat.applyStatus(c, enemy, "demoralized", 1) end
  end,
}

card("entrapment", {
  level = 2, rep = 1, name = "Entrapment", cost = 1, type = "power", rarity = "uncommon", path = "survival",
  power = true, effects = {}, hooks = entrapmentHooks,
  text = "Power.\nTraps: also apply Demoralized 1.",
  up = { cost = 0, text = "Power.\nTraps: also apply Demoralized 1." },
})

-- Lock and Load : la carte piochée arrive pendant le tour ennemi (main de 10 au plus).
local lockAndLoadHooks = {
  onTrapTriggered = function(c) Combat.drawCards(c, 1) end,
}

card("lock_and_load", {
  level = 4, rep = 1, name = "Lock and Load", cost = 1, type = "power", rarity = "uncommon", path = "survival",
  power = true, effects = {}, hooks = lockAndLoadHooks,
  text = "Power.\nWhen a Trap triggers: draw 1.",
  up = { cost = 0, text = "Power.\nWhen a Trap triggers: draw 1." },
})

-- Feign Death : Last Breath ; tombé pendant le tour ennemi, le reste de ce tour est annulé (coups restants
-- par beforeHit, ennemis suivants par le drapeau commun skipEnemyTurn) ; tombé pendant son propre tour
-- (DoT), le prochain tour ennemi est sauté. Vaut contre les boss.
local feignDeathHooks = {
  preventDeath = function(c, power)
    if not Combat.lastBreath(c, "feign_death") then return false end
    c.player.hp = 1
    c.player.flags.skipEnemyTurn = true
    return true
  end,
  beforeHit = function(c, power, dmg)
    if c.phase == "enemy" and c.player.flags.skipEnemyTurn then return 0 end
    return dmg
  end,
}

card("feign_death", {
  level = 6, rep = 2, name = "Feign Death", cost = 1, type = "power", rarity = "rare", path = "survival",
  power = true, effects = {}, hooks = feignDeathHooks,
  text = "Power.\nLast Breath: stay at 1 HP, enemies skip a turn.",
  up = { cost = 0, text = "Power.\nLast Breath: stay at 1 HP, enemies skip a turn." },
})

-- Resourcefulness : la Trap déclenchée revient en main tout de suite (main pleine : reste en défausse).
local resourcefulnessHooks = {
  onTrapTriggered = function(c, power, inst)
    if #c.hand >= Combat.HAND_MAX then return end
    for i = #c.discard, 1, -1 do
      if c.discard[i].uid == inst.uid then
        table.remove(c.discard, i)
        c.hand[#c.hand + 1] = inst
        Combat.log(c, { t = "cooldown_back", card = inst.uid })
        return
      end
    end
  end,
}

card("resourcefulness", {
  level = 7, rep = 2, name = "Resourcefulness", cost = 2, type = "power", rarity = "rare", path = "survival",
  power = true, effects = {}, hooks = resourcefulnessHooks,
  text = "Power.\nTriggered Traps return to hand.",
  up = { cost = 1, text = "Power.\nTriggered Traps return to hand." },
})

-- Bibelots du Chasseur (class = "hunter" : tirés seulement pour lui) -------------------------------
-- tier = palier de la Ligue (socle) ; level = niveau de classe prévu par la fiche, posé sans être appliqué.

local R = ns.Relics
local function relic(id, t)
  t.id = id
  t.class = "hunter"
  t.hooks = t.hooks or {}
  R[id] = t
end

-- Bibelot de départ : le familier frappe dès le début du premier tour (Frenzy 1 au premier tour).
relic("pet_whistle", {
  level = 1, name = "Pet Whistle", rarity = "common", tier = 0, noPool = true,
  text = "At the start of the first turn, the pet attacks.",
  hooks = {
    onTurnStart = function(c) if c.round == 1 then H().petAttack(c, "relic") end end,
  },
})

relic("kiblers_bits", {
  level = 1, name = "Kibler's Bits", rarity = "common", tier = 0,
  text = "At the start of each combat, +2 Frenzy.",
  hooks = {
    onCombatStart = function(c) Combat.gainRes(c, 2, "relic") end,
  },
})

relic("light_quiver", {
  level = 3, name = "Light Quiver", rarity = "common", tier = 0,
  text = "Cast Attacks deal 3 more per hit.",
  hooks = {
    damage = function(c, src, v, dst, cardDef)
      if cardDef and cardDef.type == "attack" and cardDef.cast then return v + 3 end
      return v
    end,
  },
})

-- Net-o-Matic : la première Trap du combat coûte 0 (consommé à la pose).
relic("net_o_matic", {
  level = 5, name = "Net-o-Matic Projector", rarity = "uncommon", tier = 1,
  text = "The first Trap played each combat costs 0.",
  hooks = {
    cost = function(c, src, v, d)
      if d.trap and not c.relicState.net_o_matic then return 0 end
      return v
    end,
    onTrapSet = function(c) c.relicState.net_o_matic = true end,
  },
})

relic("devilsaur_eye", {
  level = 7, name = "Devilsaur Eye", rarity = "uncommon", tier = 1,
  text = "When an enemy dies, +2 Frenzy.",
  hooks = {
    onEnemyDeath = function(c) if not c.result then Combat.gainRes(c, 2, "relic") end end,
  },
})

relic("rhokdelar", {
  level = 7, name = "Rhok'delar", rarity = "rare", tier = 2,
  text = "On the first turn, Attacks deal 5 more per hit.",
  hooks = {
    damage = function(c, src, v, dst, cardDef)
      if c.round == 1 and cardDef and cardDef.type == "attack" then return v + 5 end
      return v
    end,
  },
})

-- Classe ------------------------------------------------------------------------

ns.Classes.hunter = {
  -- PV : 65 dans la fiche et les décisions (« à régler par simulation ») ; 55 après la simulation de fumée
  id = "hunter", name = "Hunter", order = 5, hp = 55,
  resource = { id = "frenzy", cap = 5, keep = true },
  deck = {
    "arcane_shot", "arcane_shot", "arcane_shot", "arcane_shot",
    "disengage", "disengage", "disengage", "disengage",
    "serpent_sting", "freezing_trap",
  },
  startRelic = "pet_whistle",
  paths = { { id = "beast_mastery", name = "Beast Mastery" }, { id = "marksmanship", name = "Marksmanship" },
    { id = "survival", name = "Survival" } },
  survival = "control",
  bot = {
    -- un point de Frenzy : +1 à chaque attaque du familier à venir, moins la baisse de 1 par tour
    resValue = 6,
    rating = {
      kill_command = 6, bestial_wrath = 6, dire_beast = 6, barbed_shot = 6, cobra_shot = 5.5, growl = 5.5,
      intimidation = 6, multi_shot = 6, spirit_bond = 6, the_beast_within = 6.5,
      aimed_shot = 6, steady_shot = 5.5, hunters_mark = 6, concussive_shot = 6, rapid_fire = 6, counter_shot = 6,
      volley = 6, readiness = 5, trueshot_aura = 5.5, wailing_arrow = 6.5,
      immolation_trap = 6, counterattack = 6, frost_trap = 6, raptor_strike = 5.5, explosive_trap = 6.5,
      wyvern_sting = 6, entrapment = 5, lock_and_load = 5, feign_death = 6, resourcefulness = 5,
    },
    upgrade = { arcane_shot = 2.5, disengage = 2, serpent_sting = 1.5, freezing_trap = 1.5 },
    remove = { disengage = 1, arcane_shot = 1.5 },
  },
}
