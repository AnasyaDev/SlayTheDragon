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
-- level = niveau de classe qui débloque la carte (fiche, § 5 Progression, 1 à 7 ; Core/Meta.lua).
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
  up2 = { effects = { { "damage", 8 }, { "pet", 1 } }, text = "Deal 8.\nPet attacks." },
  up3 = { effects = { { "damage", 8 }, { "res", 1 }, { "pet", 1 } }, text = "Deal 8.\n+1 Frenzy.\nPet attacks." },
})

card("disengage", {
  level = 1, name = "Disengage", cost = 1, type = "skill", rarity = "basic", path = "start",
  effects = { { "absorb", 3 } },
  text = "Gain 3 Absorb.",
  up = { effects = { { "absorb", 6 } }, text = "Gain 6 Absorb." },
  up2 = { effects = { { "absorb", 8 } }, text = "Gain 8 Absorb." },
  up3 = { retain = true, text = "Gain 8 Absorb.\nRetain." },
})

card("serpent_sting", {
  level = 1, name = "Serpent Sting", cost = 1, type = "skill", rarity = "basic", path = "start",
  target = "enemy", effects = { { "draw", 1 }, { "apply", "pain", 3, icon = "sting" } },
  text = "Draw 1.\nApply DoT 3",
  up = { effects = { { "draw", 1 }, { "apply", "pain", 5, icon = "sting" } }, text = "Draw 1.\nApply DoT 5" },
  up2 = { effects = { { "draw", 1 }, { "apply", "pain", 7, icon = "sting" } }, text = "Draw 1.\nApply DoT 7" },
  up3 = { effects = { { "draw", 1 }, { "apply", "pain", 7, icon = "sting" }, { "apply", "demoralized", 1 } },
    text = "Draw 1.\nApply DoT 7\nApply Demoralized 1 ⌛" },
})

card("freezing_trap", {
  level = 1, name = "Freezing Trap", cost = 1, type = "skill", rarity = "basic", path = "start",
  trap = true, effects = { { "apply", "stunned", 1 }, { "apply", "demoralized", 1 } },
  text = "Trap.\nApply Stunned 1 ⌛\nApply Demoralized 1 ⌛",
  up = { effects = { { "apply", "stunned", 1 }, { "apply", "demoralized", 2 } },
    text = "Trap.\nApply Stunned 1 ⌛\nApply Demoralized 2 ⌛" },
  -- contre un ennemi qui résiste à Stunned (élite Stun Resistant, Indomitable, boss) : Sundered puis Demoralized
  up2 = { effects = { { "apply", "stunned", 1 }, { "apply", "demoralized", 2 }, { "apply", "armor_broken", 2 } },
    text = "Trap.\nApply Stunned 1 ⌛\nApply Demoralized 2 ⌛\nApply Sundered 2 ⌛" },
  up3 = { effects = { { "apply", "stunned", 1 }, { "apply", "demoralized", 3 }, { "apply", "armor_broken", 2 } },
    text = "Trap.\nApply Stunned 1 ⌛\nApply Demoralized 3 ⌛\nApply Sundered 2 ⌛" },
})

-- Beast Mastery : chaque carte commande le familier ou lui donne du Frenzy -------------------------

card("kill_command", {
  level = 1, name = "Kill Command", cost = 1, type = "attack", rarity = "common", path = "beast_mastery",
  target = "enemy", cooldown = 3, effects = { { "pet", 2 } },
  text = "Pet attacks twice.\nCooldown 3.",
  up = { cooldown = 2, text = "Pet attacks twice.\nCooldown 2." },
  up2 = { cost = 0, text = "Pet attacks twice.\nCooldown 2." },
  up3 = { effects = { { "res", 1 }, { "pet", 2 } }, text = "+1 Frenzy.\nPet attacks twice.\nCooldown 2." },
})

card("cobra_shot", {
  level = 1, name = "Cobra Shot", cost = 1, type = "attack", rarity = "common", path = "beast_mastery",
  target = "enemy", effects = { { "damage", 7 }, { "res", 1 } },
  text = "Deal 7.\n+1 Frenzy.",
  up = { effects = { { "damage", 10 }, { "res", 1 } }, text = "Deal 10.\n+1 Frenzy." },
  up2 = { effects = { { "damage", 13 }, { "res", 1 } }, text = "Deal 13.\n+1 Frenzy." },
  up3 = { effects = { { "damage", 13 }, { "res", 2 } }, text = "Deal 13.\n+2 Frenzy." },
})

card("barbed_shot", {
  level = 1, name = "Barbed Shot", cost = 1, type = "skill", rarity = "common", path = "beast_mastery",
  target = "enemy", effects = { { "res", 2 }, { "apply", "pain", 3, icon = "bleed" } },
  text = "+2 Frenzy.\nApply DoT 3",
  up = { effects = { { "res", 2 }, { "apply", "pain", 5, icon = "bleed" } }, text = "+2 Frenzy.\nApply DoT 5" },
  up2 = { effects = { { "res", 2 }, { "apply", "pain", 6, icon = "bleed" } }, text = "+2 Frenzy.\nApply DoT 6" },
  up3 = { effects = { { "res", 3 }, { "apply", "pain", 6, icon = "bleed" } }, text = "+3 Frenzy.\nApply DoT 6" },
})

card("dire_beast", {
  level = 2, name = "Dire Beast", cost = 0, type = "skill", rarity = "common", path = "beast_mastery",
  target = "enemy", exhaust = true, effects = { { "pet", 2 } },
  text = "Pet attacks twice.\nExhaust.",
  up = { effects = { { "pet", 3 } }, text = "Pet attacks three times.\nExhaust." },
  up2 = { effects = { { "res", 1 }, { "pet", 3 } }, text = "+1 Frenzy.\nPet attacks three times.\nExhaust." },
  up3 = { retain = true, text = "+1 Frenzy.\nPet attacks three times.\nExhaust.\nRetain." },
})

-- Growl : Spend 2 retire 2 Frenzy (le familier frappera moins fort) contre de l'Absorb en plus.
card("growl", {
  level = 1, name = "Growl", cost = 1, type = "skill", rarity = "common", path = "beast_mastery",
  spend = 2, effects = { { "absorb", 6, more = { { 6, "spent" } } } },
  text = "Gain 6 Absorb.\nSpend 2: gain 6 more.",
  up = { effects = { { "absorb", 8, more = { { 8, "spent" } } } }, text = "Gain 8 Absorb.\nSpend 2: gain 8 more." },
  up2 = { effects = { { "absorb", 10, more = { { 8, "spent" } } } }, text = "Gain 10 Absorb.\nSpend 2: gain 8 more." },
  up3 = { spend = 1, text = "Gain 10 Absorb.\nSpend 1: gain 8 more." },
})

card("intimidation", {
  level = 1, name = "Intimidation", cost = 1, type = "skill", rarity = "uncommon", path = "beast_mastery",
  target = "enemy", cooldown = 4, effects = { { "pet", 1 }, { "apply", "stunned", 1 } },
  text = "Pet attacks.\nApply Stunned 1 ⌛\nCooldown 4.",
  up = { cooldown = 3, text = "Pet attacks.\nApply Stunned 1 ⌛\nCooldown 3." },
  -- contre un ennemi qui résiste à Stunned : le familier frappe deux fois, puis Demoralized
  up2 = { effects = { { "pet", 2 }, { "apply", "stunned", 1 } },
    text = "Pet attacks twice.\nApply Stunned 1 ⌛\nCooldown 3." },
  up3 = { effects = { { "pet", 2 }, { "apply", "stunned", 1 }, { "apply", "demoralized", 2 } },
    text = "Pet attacks twice.\nApply Stunned 1 ⌛\nApply Demoralized 2 ⌛\nCooldown 3." },
})

-- Multi-Shot : sans cible, le familier reste sur la sienne.
card("multi_shot", {
  level = 4, name = "Multi-Shot", cost = 1, type = "attack", rarity = "uncommon", path = "beast_mastery",
  effects = { { "damage", 5, all = true }, { "pet", 1 } },
  text = "Deal 5 to all.\nPet attacks.",
  up = { effects = { { "damage", 7, all = true }, { "pet", 1 } }, text = "Deal 7 to all.\nPet attacks." },
  up2 = { effects = { { "damage", 8, all = true }, { "pet", 1 } }, text = "Deal 8 to all.\nPet attacks." },
  up3 = { effects = { { "damage", 8, all = true }, { "res", 1 }, { "pet", 1 } },
    text = "Deal 8 to all.\n+1 Frenzy.\nPet attacks." },
})

-- Spirit Bond : chaque attaque du familier (automatique, commandée ou de Surge) donne de l'Absorb.
local function spiritBondHooks(n)
  return { onPetAttack = function(c) Combat.gainBlock(c, c.player, n) end }
end

card("spirit_bond", {
  level = 6, name = "Spirit Bond", cost = 2, type = "power", rarity = "uncommon", path = "beast_mastery",
  power = true, effects = {}, hooks = spiritBondHooks(2),
  text = "Power.\nPet attacks: gain 2 Absorb.",
  up = { cost = 1, text = "Power.\nPet attacks: gain 2 Absorb." },
  up2 = { hooks = spiritBondHooks(3), text = "Power.\nPet attacks: gain 3 Absorb." },
  up3 = { innate = true, text = "Power.\nPet attacks: gain 3 Absorb.\nInnate." },
})

-- Bestial Wrath : une attaque par point de Frenzy, chacune à 1 + le Frenzy compté, sans en redonner ;
-- coût 2 (fiche : 1, levier prévu par la fiche, risque 3).
card("bestial_wrath", {
  level = 1, name = "Bestial Wrath", cost = 2, type = "skill", rarity = "rare", path = "beast_mastery",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "pet", 0, per = { 1, "surge" }, surge = true } },
  text = "Surge: pet attacks once per Frenzy.",
  up = { cost = 1, text = "Surge: pet attacks once per Frenzy." },
  up2 = { effects = { { "surge" }, { "pet", 0, per = { 1, "surge" }, surge = true }, { "res", 2 } },
    text = "Surge: pet attacks once per Frenzy.\n+2 Frenzy." },
  up3 = { retain = true, text = "Surge: pet attacks once per Frenzy.\n+2 Frenzy.\nRetain." },
})

-- The Beast Within : après la résolution de chaque carte Attack (une carte Cast : à sa résolution).
local beastWithinHooks = {
  onCardPlayed = function(c, power, inst, ctx)
    if ctx.def.type == "attack" and not c.result then H().petAttack(c, "card") end
  end,
}

card("the_beast_within", {
  level = 7, name = "The Beast Within", cost = 1, type = "power", rarity = "rare", path = "beast_mastery",
  power = true, effects = {}, hooks = beastWithinHooks,
  text = "Power.\nAttacks: pet attacks.",
  up = { cost = 0, text = "Power.\nAttacks: pet attacks." },
  up2 = { innate = true, text = "Power.\nAttacks: pet attacks.\nInnate." },
  up3 = { effects = { { "res", 2 } }, text = "Power.\n+2 Frenzy.\nAttacks: pet attacks.\nInnate." },
})

-- Marksmanship : Careful Aim (cible au-dessus de la moitié de ses PV), tirs en Cast ----------------

card("aimed_shot", {
  level = 1, name = "Aimed Shot", cost = 2, type = "attack", rarity = "common", path = "marksmanship",
  target = "enemy", cast = true, effects = { { "damage", 24, more = { { 10, "careful" } } } },
  text = "Cast.\nDeal 24.\nCareful Aim: deal 10 more.",
  up = { effects = { { "damage", 30, more = { { 12, "careful" } } } }, text = "Cast.\nDeal 30.\nCareful Aim: deal 12 more." },
  up2 = { effects = { { "damage", 34, more = { { 14, "careful" } } } }, text = "Cast.\nDeal 34.\nCareful Aim: deal 14 more." },
  up3 = { effects = { { "damage", 34, more = { { 14, "careful" } } }, { "draw", 1, cond = "careful" } },
    text = "Cast.\nDeal 34.\nCareful Aim: deal 14 more.\nCareful Aim: draw 1." },
})

card("steady_shot", {
  level = 1, name = "Steady Shot", cost = 1, type = "attack", rarity = "common", path = "marksmanship",
  target = "enemy", cast = true, effects = { { "damage", 13 }, { "draw", 1, cond = "careful" } },
  text = "Cast.\nDeal 13.\nCareful Aim: draw 1.",
  up = { effects = { { "damage", 17 }, { "draw", 1, cond = "careful" } }, text = "Cast.\nDeal 17.\nCareful Aim: draw 1." },
  up2 = { effects = { { "damage", 20 }, { "draw", 1, cond = "careful" } }, text = "Cast.\nDeal 20.\nCareful Aim: draw 1." },
  up3 = { effects = { { "damage", 20 }, { "draw", 1 } }, text = "Cast.\nDeal 20.\nDraw 1." },
})

card("hunters_mark", {
  level = 1, name = "Hunter's Mark", cost = 0, type = "skill", rarity = "common", path = "marksmanship",
  target = "enemy", exhaust = true, effects = { { "apply", "armor_broken", 3 } },
  text = "Apply Sundered 3 ⌛\nExhaust.",
  up = { effects = { { "apply", "armor_broken", 5 } }, text = "Apply Sundered 5 ⌛\nExhaust." },
  up2 = { effects = { { "apply", "armor_broken", 6 } }, text = "Apply Sundered 6 ⌛\nExhaust." },
  -- (pas « Pet attacks. » : une carte qui nomme le familier a une variante de Lone Wolf)
  up3 = { effects = { { "res", 2 }, { "apply", "armor_broken", 6 } }, text = "+2 Frenzy.\nApply Sundered 6 ⌛\nExhaust." },
})

card("concussive_shot", {
  level = 1, name = "Concussive Shot", cost = 1, type = "attack", rarity = "common", path = "marksmanship",
  target = "enemy", effects = { { "damage", 4 }, { "apply", "demoralized", 2 } },
  text = "Deal 4.\nApply Demoralized 2 ⌛",
  up = { effects = { { "damage", 7 }, { "apply", "demoralized", 2 } }, text = "Deal 7.\nApply Demoralized 2 ⌛" },
  up2 = { effects = { { "damage", 9 }, { "apply", "demoralized", 2 } }, text = "Deal 9.\nApply Demoralized 2 ⌛" },
  up3 = { effects = { { "damage", 9 }, { "apply", "demoralized", 3 } }, text = "Deal 9.\nApply Demoralized 3 ⌛" },
})

card("rapid_fire", {
  level = 1, name = "Rapid Fire", cost = 1, type = "attack", rarity = "uncommon", path = "marksmanship",
  target = "enemy", cooldown = 2, effects = { { "damage", 3, times = 4 } },
  text = "Deal 3 four times.\nCooldown 2.",
  up = { effects = { { "damage", 4, times = 4 } }, text = "Deal 4 four times.\nCooldown 2." },
  up2 = { effects = { { "damage", 4, times = 4 }, { "res", 1 } }, text = "Deal 4 four times.\n+1 Frenzy.\nCooldown 2." },
  up3 = { effects = { { "damage", 5, times = 4 }, { "res", 1 } }, text = "Deal 5 four times.\n+1 Frenzy.\nCooldown 2." },
})

card("counter_shot", {
  level = 1, name = "Counter Shot", cost = 0, type = "skill", rarity = "uncommon", path = "marksmanship",
  target = "enemy", cooldown = 3, effects = { { "interrupt" }, { "pet", 1 } },
  text = "Interrupt the target's cast.\nPet attacks.\nCooldown 3.",
  up = { cooldown = 2, text = "Interrupt the target's cast.\nPet attacks.\nCooldown 2." },
  up2 = { effects = { { "interrupt" }, { "pet", 2 } }, text = "Interrupt the target's cast.\nPet attacks twice.\nCooldown 2." },
  up3 = { effects = { { "interrupt" }, { "pet", 2 }, { "apply", "demoralized", 2 } },
    text = "Interrupt the target's cast.\nPet attacks twice.\nApply Demoralized 2 ⌛\nCooldown 2." },
})

card("volley", {
  level = 2, name = "Volley", cost = 2, type = "attack", rarity = "uncommon", path = "marksmanship",
  cast = true, effects = { { "damage", 16, all = true } },
  text = "Cast.\nDeal 16 to all.",
  up = { effects = { { "damage", 20, all = true } }, text = "Cast.\nDeal 20 to all." },
  up2 = { effects = { { "damage", 23, all = true } }, text = "Cast.\nDeal 23 to all." },
  up3 = { effects = { { "damage", 23, all = true, more = { { 5, "careful" } } } },
    text = "Cast.\nDeal 23 to all.\nCareful Aim: deal 5 more." },
})

card("readiness", {
  level = 4, name = "Readiness", cost = 0, type = "skill", rarity = "uncommon", path = "marksmanship",
  exhaust = true, effects = { { "readiness" } },
  text = "Return Cooldown cards to hand.\nExhaust.",
  up = { effects = { { "readiness" }, { "draw", 1 } }, text = "Return Cooldown cards to hand.\nDraw 1.\nExhaust." },
  up2 = { retain = true, text = "Return Cooldown cards to hand.\nDraw 1.\nExhaust.\nRetain." },
  up3 = { effects = { { "readiness" }, { "draw", 2 } }, text = "Return Cooldown cards to hand.\nDraw 2.\nExhaust.\nRetain." },
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
  level = 6, name = "Trueshot Aura", cost = 1, type = "power", rarity = "rare", path = "marksmanship",
  power = true, effects = {}, hooks = trueshotHooks(5),
  text = "Power.\nCareful Aim: Attacks deal 5 more.",
  up = { hooks = trueshotHooks(7), text = "Power.\nCareful Aim: Attacks deal 7 more." },
  up2 = { cost = 0, text = "Power.\nCareful Aim: Attacks deal 7 more." },
  up3 = { hooks = trueshotHooks(8), text = "Power.\nCareful Aim: Attacks deal 8 more." },
})

card("wailing_arrow", {
  level = 7, name = "Wailing Arrow", cost = 1, type = "attack", rarity = "rare", path = "marksmanship",
  exhaust = true, effects = { { "damage", 8, all = true }, { "interrupt", all = true } },
  text = "Deal 8 to all.\nInterrupt all casts.\nExhaust.",
  up = { effects = { { "damage", 12, all = true }, { "interrupt", all = true } },
    text = "Deal 12 to all.\nInterrupt all casts.\nExhaust." },
  up2 = { effects = { { "damage", 12, all = true }, { "interrupt", all = true }, { "apply", "demoralized", 1, all = true } },
    text = "Deal 12 to all.\nInterrupt all casts.\nApply Demoralized 1 ⌛ to all\nExhaust." },
  up3 = { effects = { { "damage", 15, all = true }, { "interrupt", all = true }, { "apply", "demoralized", 1, all = true } },
    text = "Deal 15 to all.\nInterrupt all casts.\nApply Demoralized 1 ⌛ to all\nExhaust." },
})

-- Survival : Traps posées pendant le tour, déclenchées par les attaques ennemies ------------------

card("immolation_trap", {
  level = 1, name = "Immolation Trap", cost = 1, type = "skill", rarity = "common", path = "survival",
  trap = true, effects = { { "apply", "pain", 7, icon = "immolation" } },
  text = "Trap.\nApply DoT 7",
  up = { effects = { { "apply", "pain", 9, icon = "immolation" } }, text = "Trap.\nApply DoT 9" },
  up2 = { effects = { { "apply", "pain", 11, icon = "immolation" } }, text = "Trap.\nApply DoT 11" },
  up3 = { effects = { { "damage", 6 }, { "apply", "pain", 11, icon = "immolation" } }, text = "Trap.\nDeal 6.\nApply DoT 11" },
})

card("counterattack", {
  level = 1, name = "Counterattack", cost = 1, type = "skill", rarity = "common", path = "survival",
  trap = true, effects = { { "damage", 13 } },
  text = "Trap.\nDeal 13.",
  up = { effects = { { "damage", 17 } }, text = "Trap.\nDeal 17." },
  up2 = { effects = { { "damage", 20 } }, text = "Trap.\nDeal 20." },
  up3 = { effects = { { "damage", 20 }, { "apply", "demoralized", 2 } }, text = "Trap.\nDeal 20.\nApply Demoralized 2 ⌛" },
})

card("frost_trap", {
  level = 1, name = "Frost Trap", cost = 1, type = "skill", rarity = "common", path = "survival",
  trap = true, effects = { { "apply", "demoralized", 1, all = true } },
  text = "Trap.\nApply Demoralized 1 ⌛ to all",
  up = { effects = { { "apply", "demoralized", 2, all = true } }, text = "Trap.\nApply Demoralized 2 ⌛ to all" },
  up2 = { effects = { { "apply", "demoralized", 2, all = true }, { "apply", "armor_broken", 2, all = true } },
    text = "Trap.\nApply Demoralized 2 ⌛ to all\nApply Sundered 2 ⌛ to all" },
  up3 = { effects = { { "apply", "demoralized", 3, all = true }, { "apply", "armor_broken", 2, all = true } },
    text = "Trap.\nApply Demoralized 3 ⌛ to all\nApply Sundered 2 ⌛ to all" },
})

card("raptor_strike", {
  level = 1, name = "Raptor Strike", cost = 1, type = "attack", rarity = "common", path = "survival",
  target = "enemy", effects = { { "damage", 5 }, { "absorb", 3 } },
  text = "Deal 5.\nGain 3 Absorb.",
  up = { effects = { { "damage", 8 }, { "absorb", 4 } }, text = "Deal 8.\nGain 4 Absorb." },
  up2 = { effects = { { "damage", 10 }, { "absorb", 5 } }, text = "Deal 10.\nGain 5 Absorb." },
  up3 = { effects = { { "damage", 10 }, { "absorb", 5 }, { "res", 1 } }, text = "Deal 10.\nGain 5 Absorb.\n+1 Frenzy." },
})

card("explosive_trap", {
  level = 1, name = "Explosive Trap", cost = 1, type = "skill", rarity = "uncommon", path = "survival",
  trap = true,
  effects = { { "damage", 6, all = true }, { "apply", "pain", 3, all = true, icon = "immolation" } },
  text = "Trap.\nDeal 6 to all.\nApply DoT 3 to all",
  up = { effects = { { "damage", 8, all = true }, { "apply", "pain", 4, all = true, icon = "immolation" } },
    text = "Trap.\nDeal 8 to all.\nApply DoT 4 to all" },
  up2 = { effects = { { "damage", 10, all = true }, { "apply", "pain", 4, all = true, icon = "immolation" } },
    text = "Trap.\nDeal 10 to all.\nApply DoT 4 to all" },
  up3 = { effects = { { "damage", 10, all = true }, { "apply", "pain", 4, all = true, icon = "immolation" },
      { "apply", "armor_broken", 1, all = true } },
    text = "Trap.\nDeal 10 to all.\nApply DoT 4 to all\nApply Sundered 1 ⌛ to all" },
})

card("wyvern_sting", {
  level = 1, name = "Wyvern Sting", cost = 1, type = "skill", rarity = "uncommon", path = "survival",
  target = "enemy", cooldown = 4,
  effects = { { "apply", "stunned", 1 }, { "apply", "pain", 4, icon = "sting" } },
  text = "Apply Stunned 1 ⌛\nApply DoT 4\nCooldown 4.",
  up = { cooldown = 3, text = "Apply Stunned 1 ⌛\nApply DoT 4\nCooldown 3." },
  -- contre un ennemi qui résiste à Stunned : DoT plus fort, puis Demoralized
  up2 = { effects = { { "apply", "stunned", 1 }, { "apply", "pain", 7, icon = "sting" } },
    text = "Apply Stunned 1 ⌛\nApply DoT 7\nCooldown 3." },
  up3 = { effects = { { "apply", "stunned", 1 }, { "apply", "pain", 7, icon = "sting" }, { "apply", "demoralized", 2 } },
    text = "Apply Stunned 1 ⌛\nApply DoT 7\nApply Demoralized 2 ⌛\nCooldown 3." },
})

-- Entrapment : chaque Trap déclenchée pose aussi Demoralized n sur l'attaquant (même une Trap « to all ») ;
-- palier 2 : Sundered s en plus.
local function entrapmentHooks(n, s)
  return {
    onTrapTriggered = function(c, power, inst, enemy)
      if enemy and not enemy.dead then Combat.applyStatus(c, enemy, "demoralized", n) end
      if s and enemy and not enemy.dead then Combat.applyStatus(c, enemy, "armor_broken", s) end
    end,
  }
end

card("entrapment", {
  level = 2, name = "Entrapment", cost = 0, type = "power", rarity = "uncommon", path = "survival",
  power = true, effects = {}, hooks = entrapmentHooks(1),
  text = "Power.\nTraps: also apply Demoralized 1.",
  up = { hooks = entrapmentHooks(2), text = "Power.\nTraps: also apply Demoralized 2." },
  up2 = { hooks = entrapmentHooks(2, 1), text = "Power.\nTraps: also apply Demoralized 2 and Sundered 1." },
  up3 = { innate = true, text = "Power.\nTraps: also apply Demoralized 2 and Sundered 1.\nInnate." },
})

-- Lock and Load : la carte piochée arrive pendant le tour ennemi (main de 10 au plus) ; palier 2 : +f Frenzy.
local function lockAndLoadHooks(n, f)
  return {
    onTrapTriggered = function(c)
      Combat.drawCards(c, n)
      if f and not c.result then Combat.gainRes(c, f, "card") end
    end,
  }
end

card("lock_and_load", {
  level = 4, name = "Lock and Load", cost = 0, type = "power", rarity = "uncommon", path = "survival",
  power = true, effects = {}, hooks = lockAndLoadHooks(1),
  text = "Power.\nWhen a Trap triggers: draw 1.",
  up = { hooks = lockAndLoadHooks(2), text = "Power.\nWhen a Trap triggers: draw 2." },
  up2 = { hooks = lockAndLoadHooks(2, 1), text = "Power.\nWhen a Trap triggers: draw 2, +1 Frenzy." },
  up3 = { innate = true, text = "Power.\nWhen a Trap triggers: draw 2, +1 Frenzy.\nInnate." },
})

-- Feign Death : Last Breath ; tombé pendant le tour ennemi, le reste de ce tour est annulé (coups restants
-- par beforeHit, ennemis suivants par le drapeau commun skipEnemyTurn) ; tombé pendant son propre tour
-- (DoT), le prochain tour ennemi est sauté. Vaut contre les boss.
-- hp : PV gardés (1 ; palier 2 : 5).
local function feignDeathHooks(hp)
  return {
    preventDeath = function(c, power)
      if not Combat.lastBreath(c, "feign_death") then return false end
      c.player.hp = math.min(hp, c.player.maxHp)
      c.player.flags.skipEnemyTurn = true
      return true
    end,
    beforeHit = function(c, power, dmg)
      if c.phase == "enemy" and c.player.flags.skipEnemyTurn then return 0 end
      return dmg
    end,
  }
end

card("feign_death", {
  level = 6, name = "Feign Death", cost = 1, type = "power", rarity = "rare", path = "survival",
  power = true, effects = {}, hooks = feignDeathHooks(1),
  text = "Power.\nLast Breath: stay at 1 HP, enemies skip a turn.",
  up = { cost = 0, text = "Power.\nLast Breath: stay at 1 HP, enemies skip a turn." },
  up2 = { hooks = feignDeathHooks(5), text = "Power.\nLast Breath: stay at 5 HP, enemies skip a turn." },
  up3 = { innate = true, text = "Power.\nLast Breath: stay at 5 HP, enemies skip a turn.\nInnate." },
})

-- Resourcefulness : la Trap déclenchée revient en main tout de suite (main pleine : reste en défausse).
-- Trap lancée au jeu (Trap Launcher, why = "launch") : elle revient à la fin du round, après le tour
-- ennemi (sinon une Freezing Trap étourdirait toute la salle à chaque tour) ; uid gardés dans
-- c.cls.trapBack.
local function trapToHand(c, uid)
  if #c.hand >= Combat.HAND_MAX then return end
  for i = #c.discard, 1, -1 do
    local inst = c.discard[i]
    if inst.uid == uid then
      table.remove(c.discard, i)
      c.hand[#c.hand + 1] = inst
      Combat.log(c, { t = "cooldown_back", card = inst.uid })
      return
    end
  end
end

-- absorb : Absorb gagné à chaque Trap déclenchée (palier 3 : 3 ; sinon 0).
local function resourcefulnessHooks(absorb)
  return {
    onTrapTriggered = function(c, power, inst, enemy, why)
      if absorb > 0 and not c.result then Combat.gainBlock(c, c.player, absorb) end
      if why == "launch" then
        local back = c.cls.trapBack or {}
        c.cls.trapBack = back
        back[#back + 1] = inst.uid
        return
      end
      trapToHand(c, inst.uid)
    end,
    onRoundEnd = function(c)
      local back = c.cls.trapBack
      if not back then return end
      c.cls.trapBack = nil
      for i = 1, #back do trapToHand(c, back[i]) end
    end,
  }
end

card("resourcefulness", {
  level = 7, name = "Resourcefulness", cost = 1, type = "power", rarity = "rare", path = "survival",
  power = true, effects = {}, hooks = resourcefulnessHooks(0),
  text = "Power.\nTriggered Traps return to hand.",
  up = { cost = 0, text = "Power.\nTriggered Traps return to hand." },
  up2 = { innate = true, text = "Power.\nTriggered Traps return to hand.\nInnate." },
  up3 = { hooks = resourcefulnessHooks(3), text = "Power.\nTriggered Traps return to hand.\nWhen a Trap triggers: gain 3 Absorb.\nInnate." },
})

-- Cartes épiques (cartes de zone, docs/zones/cartes-de-zone.md, « Hunter ») ------------------------
-- Une épique est une règle en jeu dès le début de chaque combat : jamais piochée ni jouée, sans coût.
-- Ses crochets sont des deckHooks (actifs où que soit la carte, src = { id, up, uid } : src.up = améliorée) ;
-- whileInDeck = ns.Hunter.epicStart (Core/Classes/hunter.lua). Les nombres réglés par la simulation sont
-- en tête de chaque bloc (EPIC).

-- Nombres des épiques, { base, amélioré } (fiche : roar 5 / 8, marksman 0 / 4, launcher 1 / 2, lonePer 1 / 1,
-- loneStart 0 / 1, chimaera 3, 3, 6 ; Call of the Wild, Beast Cleave, Black Arrow sans nombre) ; réglés par la
-- simulation dans les zones dures (14/11/2026 : gain moyen sur Duskwood, Stranglethorn, Steppes, clé 0,
-- niveau 7 ; docs/classes.md, « Hunter : les sept épiques »). Lone Wolf amélioré : +3 par Frenzy au lieu de
-- « Start of turn: +1 Frenzy. » (la ligne de plus faisait passer le texte sous le plancher de 8,5).
-- Paliers 2 et 3 (15/11/2026, docs/ameliorations.md) : tables { base, +1, +2, +3 }, lues par Card.level(src) + 1.
local EPIC = {
  cotwCost = { 1, 0, 0, 0 },      -- Call of the Wild : Frenzy dépensé pour l'attaque du début du tour (0 : gratuite)
  cotwRes = { 0, 0, 1, 2 },       -- Call of the Wild : Frenzy gagné au début du tour, avant l'attaque
  cleaveLess = { 2, 2, 0, 0 },    -- Beast Cleave : dégâts en moins du familier sur les ennemis autres que sa cible
  cleaveRes = { 0, 1, 1, 2 },     -- Beast Cleave : Frenzy de plus par attaque du familier (hors Surge)
  blackCost = { 1, 0, 0, 0 },     -- Black Arrow : Frenzy dépensé pour l'attaque sur l'ennemi qui tique (0 : gratuite)
  blackRes = { 0, 0, 1, 2 },      -- Black Arrow : Frenzy de plus après cette attaque
  roar = { 2, 4, 5, 6 },          -- Roar of Sacrifice : dégâts arrêtés par point de Frenzy dépensé
  marksman = { 20, 24, 27, 30 },  -- Master Marksman : dégâts en plus par coup d'une Cast résolue tout de suite
  launcher = { 1, 2, 2, 3 },      -- Trap Launcher : attaques du familier par Trap lancée
  launchRes = { 0, 0, 1, 1 },     -- Trap Launcher : Frenzy gagné par Trap lancée, avant les attaques
  lonePer = { 2, 3, 4, 5 },       -- Lone Wolf : dégâts en plus par coup d'Attack et par point de Frenzy
  loneStart = { 0, 0, 0, 0 },     -- Lone Wolf : Frenzy gagné au début de chaque tour
  chimaera = { 5, 4, 8, 6 },      -- Chimaera Shot (variante) : cible, autre ennemi, cible améliorée, autre ennemi
                                  -- au palier 2 (fiche : 3, 3, 6)
}
ns.HunterEpic = EPIC

-- Note des épiques pour les bots (classDef.bot.epic) : ≈ 5 + gain mesuré / 2 (gain moyen des zones dures,
-- 14/11/2026).
local EPIC_KEEP = 5
local EPIC_BOT = {
  call_of_the_wild = 9.6, trap_launcher = 10.6, beast_cleave = 10.3, roar_of_sacrifice = 10.7, master_marksman = 9.7,
  black_arrow = 11.3, lone_wolf = 11.3,
}

local function epic(id, t)
  t.type, t.rarity, t.epic, t.cost = "power", "epic", true, 0 -- coût jamais payé ni affiché
  t.effects = t.effects or {}
  t.whileInDeck = function(c, src) H().epicStart(c, src) end
  card(id, t)
end

-- Nombre d'une épique à son palier : t[palier + 1] (tables { base, +1, +2, +3 } ; plus courte : dernière valeur).
local function nt(t, src) return t[math.min(#t, ns.Card.level(src) + 1)] end

-- Attaque du familier payée en Frenzy (Call of the Wild, Black Arrow) : rien sans assez de Frenzy ; cost 0 :
-- gratuite. Texte : « Wild Call N » (mot de règle, Core/Classes/hunter.lua), sinon « pet attacks ».
local function paidPet(c, cost)
  if cost > 0 then
    if (c.player.res or 0) < cost then return false end
    Combat.gainRes(c, -cost, "epic")
  end
  return true
end

-- Westfall — Call of the Wild : au début de chaque tour (après la pioche et la baisse du Frenzy), si le
-- Frenzy vaut EPIC.cotwCost ou plus, il baisse d'autant et le familier attaque (+1 Frenzy comme toute
-- attaque : la dépense de 1 est rendue) ; amélioré : sans dépense ; paliers 2 et 3 : EPIC.cotwRes Frenzy
-- gagné juste avant l'attaque (« Hunt N », mot de règle : la carte tient en deux lignes).
local function cotwText(cost, res)
  if cost > 0 then return "Epic.\nStart of turn: Wild Call " .. cost .. "." end
  if res > 0 then return "Epic.\nStart of turn: Hunt " .. res .. "." end -- mot de règle (Frenzy, puis attaque)
  return "Epic.\nStart of turn: pet attacks."
end
epic("call_of_the_wild", {
  zone = "westfall", path = "beast_mastery", name = "Call of the Wild",
  text = cotwText(EPIC.cotwCost[1], EPIC.cotwRes[1]),
  up = { text = cotwText(EPIC.cotwCost[2], EPIC.cotwRes[2]) },
  up2 = { text = cotwText(EPIC.cotwCost[3], EPIC.cotwRes[3]) },
  up3 = { text = cotwText(EPIC.cotwCost[4], EPIC.cotwRes[4]) },
  deckHooks = {
    onTurnStart = function(c, src)
      if c.result or not H().petPresent(c) or not H().petTarget(c) then return end
      if paidPet(c, nt(EPIC.cotwCost, src)) then
        local res = nt(EPIC.cotwRes, src)
        if res > 0 then Combat.gainRes(c, res, "epic") end
        H().petAttack(c, "epic")
      end
    end,
  },
})

-- Duskwood — Trap Launcher : une Trap demande une cible et s'y déclenche aussitôt (trapLaunch), puis le
-- familier attaque cet ennemi EPIC.launcher fois (fiche : 1, amélioré 2), qui devient sa cible ; paliers 2 et
-- 3 : EPIC.launchRes Frenzy avant les attaques.
local function launcherText(n, res)
  return "Epic.\nTraps: " .. (res > 0 and ("+" .. res .. " Frenzy, ") or "") .. "Launch " .. n .. "."
end
epic("trap_launcher", {
  zone = "duskwood", path = "survival", name = "Trap Launcher",
  text = launcherText(EPIC.launcher[1], EPIC.launchRes[1]),
  up = { text = launcherText(EPIC.launcher[2], EPIC.launchRes[2]) },
  up2 = { text = launcherText(EPIC.launcher[3], EPIC.launchRes[3]) },
  up3 = { text = launcherText(EPIC.launcher[4], EPIC.launchRes[4]) },
  deckHooks = {
    trapLaunch = function(c, src, v) return true end,
    onTrapTriggered = function(c, src, inst, enemy, why)
      if why ~= "launch" or not enemy then return end
      local res = nt(EPIC.launchRes, src)
      if res > 0 and not c.result then Combat.gainRes(c, res, "epic") end
      for _ = 1, nt(EPIC.launcher, src) do
        if c.result or enemy.dead then return end
        H().petAttackOn(c, "launch", enemy)
      end
    end,
  },
})

-- Wetlands — Beast Cleave : chaque attaque du familier frappe tous les ennemis vivants (petAll) : sa cible
-- en plein, les autres pour EPIC.cleaveLess de moins (crochet petLess) ; amélioré : +1 Frenzy de plus par
-- attaque (pas pour les attaques de Surge, qui n'en donnent pas) ; palier 2 : les autres en plein (« in
-- full ») ; palier 3 : +2 Frenzy de plus par attaque (EPIC.cleaveRes).
-- (dégâts en moins : à-côté du mot Stampede, Core/Classes/hunter.lua)
-- (paliers 2 et 3 : « Trample +N », mot de règle à part : les autres en plein ; la carte tient en deux lignes)
local function cleaveText(less, res)
  if less == 0 then return "Epic.\nPet attacks: Trample +" .. res .. "." end
  return "Epic.\nPet attacks: Stampede" .. (res > 0 and (" +" .. res) or "") .. "."
end
epic("beast_cleave", {
  zone = "wetlands", path = "beast_mastery", name = "Beast Cleave",
  text = cleaveText(EPIC.cleaveLess[1], EPIC.cleaveRes[1]),
  up = { text = cleaveText(EPIC.cleaveLess[2], EPIC.cleaveRes[2]) },
  up2 = { text = cleaveText(EPIC.cleaveLess[3], EPIC.cleaveRes[3]) },
  up3 = { text = cleaveText(EPIC.cleaveLess[4], EPIC.cleaveRes[4]) },
  deckHooks = {
    petAll = function(c, src, v) return true end,
    petLess = function(c, src, v) return v + nt(EPIC.cleaveLess, src) end,
    onPetAttack = function(c, src, t, dmg, why)
      local res = nt(EPIC.cleaveRes, src)
      if res > 0 and why ~= "surge" and not c.result then Combat.gainRes(c, res, "epic") end
    end,
  },
})

-- Stranglethorn Vale — Roar of Sacrifice : à chaque coup ennemi (avant l'Absorb), si le Frenzy vaut 1 ou
-- plus, il baisse de 1 et le coup perd jusqu'à EPIC.roar dégâts (fiche : 5, amélioré 8). Un coup de 0 ne
-- coûte rien.
epic("roar_of_sacrifice", {
  zone = "stranglethorn", path = "beast_mastery", name = "Roar of Sacrifice",
  text = "Epic.\nWhen hit: Intervene " .. EPIC.roar[1] .. ".",
  up = { text = "Epic.\nWhen hit: Intervene " .. EPIC.roar[2] .. "." },
  up2 = { text = "Epic.\nWhen hit: Intervene " .. EPIC.roar[3] .. "." },
  up3 = { text = "Epic.\nWhen hit: Intervene " .. EPIC.roar[4] .. "." },
  deckHooks = {
    beforeHit = function(c, src, dmg, enemy)
      if dmg <= 0 or (c.player.res or 0) < 1 or c.result then return dmg end
      local stop = math.min(dmg, nt(EPIC.roar, src))
      Combat.gainRes(c, -1, "roar")
      Combat.log(c, { t = "roar", src = enemy and Combat.uref(enemy), prevented = stop })
      if c.stats then c.stats.roarPrevented = (c.stats.roarPrevented or 0) + stop end
      return dmg - stop
    end,
  },
})

-- Swamp of Sorrows — Master Marksman : une carte Attack Cast à cible jouée sur un ennemi au-dessus de la
-- moitié de ses PV (Careful Aim, lu au jeu) se résout tout de suite, sans emplacement ni interruption
-- (crochet instantCast, cible = c.player.lastTarget posée par Combat.play) ; ses coups infligent EPIC.marksman
-- de plus (fiche : 0, amélioré 4 ; c.cls.marksman = uid de la carte en cours). Sans cible connue (question de
-- canPlay) : vrai si un ennemi vivant est intact.
local function marksmanText(n)
  return "Epic.\nCareful Aim: Deadeye" .. (n > 0 and (" " .. n) or "") .. "."
end
local function carefulTarget(t) return t ~= nil and not t.dead and t.hp * 2 > t.maxHp end
epic("master_marksman", {
  zone = "swamp", path = "marksmanship", name = "Master Marksman",
  text = marksmanText(EPIC.marksman[1]),
  up = { text = marksmanText(EPIC.marksman[2]) },
  up2 = { text = marksmanText(EPIC.marksman[3]) },
  up3 = { text = marksmanText(EPIC.marksman[4]) },
  deckHooks = {
    instantCast = function(c, src, v, d, inst, commit)
      if v or d.type ~= "attack" or not d.cast or d.target ~= "enemy" then return v end
      if commit then
        local uid = c.player.lastTarget
        if not carefulTarget(uid and Combat.enemyByUid(c, uid)) then return v end
        Combat.log(c, { t = "cast_instant", card = inst.uid, by = "master_marksman" })
        if c.stats then c.stats.castsInstant = (c.stats.castsInstant or 0) + 1 end
        if nt(EPIC.marksman, src) > 0 then c.cls.marksman = inst.uid end
        return true
      end
      for i = 1, #c.enemies do
        if carefulTarget(c.enemies[i]) then return true end
      end
      return v
    end,
    damage = function(c, src, v, dst, cardDef)
      if c.cls.marksman and cardDef and cardDef.type == "attack" and cardDef.cast then
        return v + nt(EPIC.marksman, src)
      end
      return v
    end,
    afterCast = function(c, src, inst)
      if c.cls.marksman == inst.uid then c.cls.marksman = nil end
    end,
  },
})

-- Burning Steppes — Black Arrow : après chaque tic de DoT sur un ennemi qui survit, si le Frenzy vaut
-- EPIC.blackCost ou plus, il baisse d'autant et le familier attaque cet ennemi (+1 Frenzy comme d'habitude),
-- sans changer sa cible ; amélioré : sans dépense ; paliers 2 et 3 : EPIC.blackRes Frenzy de plus après
-- l'attaque.
local function blackText(cost, res)
  if cost > 0 then return "Epic.\nEnemy DoT ticks: Wild Call " .. cost .. "." end
  if res > 0 then return "Epic.\nEnemy DoT ticks: Prey " .. res .. "." end -- mot de règle (attaque, puis Frenzy)
  return "Epic.\nEnemy DoT ticks: pet attacks it."
end
epic("black_arrow", {
  zone = "steppes", path = "survival", name = "Black Arrow",
  text = blackText(EPIC.blackCost[1], EPIC.blackRes[1]),
  up = { text = blackText(EPIC.blackCost[2], EPIC.blackRes[2]) },
  up2 = { text = blackText(EPIC.blackCost[3], EPIC.blackRes[3]) },
  up3 = { text = blackText(EPIC.blackCost[4], EPIC.blackRes[4]) },
  deckHooks = {
    onDotTick = function(c, src, unit)
      if c.result or unit.side ~= "enemy" or unit.dead or not H().petPresent(c) then return end
      if paidPet(c, nt(EPIC.blackCost, src)) then
        H().petAttackOn(c, "dot", unit)
        local res = nt(EPIC.blackRes, src)
        if res > 0 and not c.result then Combat.gainRes(c, res, "epic") end
      end
    end,
  },
})

-- Blackrock Mountain — Lone Wolf : plus de familier (petAbsent) ; les cartes qui le nomment se jouent et
-- s'affichent sous leur variante (transforms, variantes ci-dessous) ; chaque coup d'une carte Attack inflige
-- EPIC.lonePer par point de Frenzy de plus (fiche : 1 ; crochet damage, lu coup par coup ; une Cast le lit à
-- sa résolution) ; EPIC.loneStart Frenzy au début de chaque tour (fiche : 0, amélioré 1 ; la baisse de 1 par
-- round reste).
local function loneText(per, start)
  -- (cartes de familier changées et Frenzy du début du tour : à-côté du mot Ferocity, Core/Classes/hunter.lua)
  return "Epic.\nAttack hits: Ferocity " .. per .. "."
end
epic("lone_wolf", {
  zone = "blackrock", path = "marksmanship", name = "Lone Wolf",
  text = loneText(EPIC.lonePer[1], EPIC.loneStart[1]),
  up = { text = loneText(EPIC.lonePer[2], EPIC.loneStart[2]) },
  up2 = { text = loneText(EPIC.lonePer[3], EPIC.loneStart[3]) },
  up3 = { text = loneText(EPIC.lonePer[4], EPIC.loneStart[4]) },
  transforms = {
    arcane_shot = "chimaera_shot", kill_command = "kill_shot", dire_beast = "double_tap",
    intimidation = "scatter_shot", multi_shot = "salvo", counter_shot = "silencing_shot",
    bestial_wrath = "explosive_shot", the_beast_within = "trick_shots", spirit_bond = "aspect_of_the_turtle",
  },
  deckHooks = {
    petAbsent = function(c, src, v) return true end,
    damage = function(c, src, v, dst, cardDef)
      if cardDef and cardDef.type == "attack" then return v + nt(EPIC.lonePer, src) * (c.player.res or 0) end
      return v
    end,
    onTurnStart = function(c, src)
      local n = nt(EPIC.loneStart, src)
      if n > 0 and not c.result then Combat.gainRes(c, n, "epic") end
    end,
  },
})

-- Variantes de Lone Wolf (variant = true : jamais collectionnables) : coût, type, rareté, voie et
-- amélioration de la carte d'origine gardés.
local function variant(id, t)
  t.variant = true
  card(id, t)
end

variant("chimaera_shot", {
  name = "Chimaera Shot", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", EPIC.chimaera[1] }, { "damageOther", EPIC.chimaera[2] }, { "res", 1 } },
  text = "Deal " .. EPIC.chimaera[1] .. ".\nDeal " .. EPIC.chimaera[2] .. " to another enemy.\n+1 Frenzy.",
  up = { effects = { { "damage", EPIC.chimaera[3] }, { "damageOther", EPIC.chimaera[2] }, { "res", 1 } },
    text = "Deal " .. EPIC.chimaera[3] .. ".\nDeal " .. EPIC.chimaera[2] .. " to another enemy.\n+1 Frenzy." },
  up2 = { effects = { { "damage", EPIC.chimaera[3] }, { "damageOther", EPIC.chimaera[4] }, { "res", 1 } },
    text = "Deal " .. EPIC.chimaera[3] .. ".\nDeal " .. EPIC.chimaera[4] .. " to another enemy.\n+1 Frenzy." },
  up3 = { effects = { { "damage", EPIC.chimaera[3] }, { "damageOther", EPIC.chimaera[4] }, { "res", 2 } },
    text = "Deal " .. EPIC.chimaera[3] .. ".\nDeal " .. EPIC.chimaera[4] .. " to another enemy.\n+2 Frenzy." },
})

variant("kill_shot", {
  name = "Kill Shot", cost = 1, type = "attack", rarity = "common", path = "beast_mastery",
  target = "enemy", cooldown = 3, effects = { { "damage", 8, more = { { 8, "execute" } } }, { "res", 1 } },
  text = "Deal 8.\nExecute: deal 16.\n+1 Frenzy.\nCooldown 3.",
  up = { cooldown = 2, text = "Deal 8.\nExecute: deal 16.\n+1 Frenzy.\nCooldown 2." },
  up2 = { cost = 0, text = "Deal 8.\nExecute: deal 16.\n+1 Frenzy.\nCooldown 2." },
  up3 = { effects = { { "damage", 8, more = { { 8, "execute" } } }, { "res", 2 } },
    text = "Deal 8.\nExecute: deal 16.\n+2 Frenzy.\nCooldown 2." },
})

variant("double_tap", {
  name = "Double Tap", cost = 0, type = "skill", rarity = "common", path = "beast_mastery",
  exhaust = true, effects = { { "draw", 1 }, { "res", 2 } },
  text = "Draw 1.\n+2 Frenzy.\nExhaust.",
  up = { effects = { { "draw", 1 }, { "res", 3 } }, text = "Draw 1.\n+3 Frenzy.\nExhaust." },
  up2 = { effects = { { "draw", 1 }, { "res", 4 } }, text = "Draw 1.\n+4 Frenzy.\nExhaust." },
  up3 = { retain = true, text = "Draw 1.\n+4 Frenzy.\nExhaust.\nRetain." },
})

variant("scatter_shot", {
  name = "Scatter Shot", cost = 1, type = "skill", rarity = "uncommon", path = "beast_mastery",
  target = "enemy", cooldown = 4, effects = { { "damage", 3 }, { "res", 1 }, { "apply", "stunned", 1 } },
  text = "Deal 3.\n+1 Frenzy.\nApply Stunned 1 ⌛\nCooldown 4.",
  up = { cooldown = 3, text = "Deal 3.\n+1 Frenzy.\nApply Stunned 1 ⌛\nCooldown 3." },
  up2 = { effects = { { "damage", 7 }, { "res", 1 }, { "apply", "stunned", 1 } },
    text = "Deal 7.\n+1 Frenzy.\nApply Stunned 1 ⌛\nCooldown 3." },
  up3 = { effects = { { "damage", 7 }, { "res", 2 }, { "apply", "stunned", 1 } },
    text = "Deal 7.\n+2 Frenzy.\nApply Stunned 1 ⌛\nCooldown 3." },
})

variant("salvo", {
  name = "Salvo", cost = 1, type = "attack", rarity = "uncommon", path = "beast_mastery",
  effects = { { "damage", 5, all = true }, { "res", 1 } },
  text = "Deal 5 to all.\n+1 Frenzy.",
  up = { effects = { { "damage", 7, all = true }, { "res", 1 } }, text = "Deal 7 to all.\n+1 Frenzy." },
  up2 = { effects = { { "damage", 8, all = true }, { "res", 1 } }, text = "Deal 8 to all.\n+1 Frenzy." },
  up3 = { effects = { { "damage", 8, all = true }, { "res", 2 } }, text = "Deal 8 to all.\n+2 Frenzy." },
})

variant("silencing_shot", {
  name = "Silencing Shot", cost = 0, type = "skill", rarity = "uncommon", path = "marksmanship",
  target = "enemy", cooldown = 3, effects = { { "interrupt" }, { "res", 1 } },
  text = "Interrupt the target's cast.\n+1 Frenzy.\nCooldown 3.",
  up = { cooldown = 2, text = "Interrupt the target's cast.\n+1 Frenzy.\nCooldown 2." },
  up2 = { effects = { { "interrupt" }, { "res", 2 } }, text = "Interrupt the target's cast.\n+2 Frenzy.\nCooldown 2." },
  up3 = { effects = { { "interrupt" }, { "res", 2 }, { "apply", "demoralized", 2 } },
    text = "Interrupt the target's cast.\n+2 Frenzy.\nApply Demoralized 2 ⌛\nCooldown 2." },
})

variant("explosive_shot", {
  name = "Explosive Shot", cost = 2, type = "skill", rarity = "rare", path = "beast_mastery",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "damage", 0, per = { 6, "surge" } } },
  text = "Surge: deal 6 per Frenzy.",
  up = { cost = 1, text = "Surge: deal 6 per Frenzy." },
  up2 = { effects = { { "surge" }, { "damage", 0, per = { 6, "surge" } }, { "res", 2 } },
    text = "Surge: deal 6 per Frenzy.\n+2 Frenzy." },
  up3 = { retain = true, text = "Surge: deal 6 per Frenzy.\n+2 Frenzy.\nRetain." },
})

-- Trick Shots : après la résolution de chaque carte Attack, +1 Frenzy (comme The Beast Within).
local trickShotsHooks = {
  onCardPlayed = function(c, power, inst, ctx)
    if ctx.def.type == "attack" and not c.result then Combat.gainRes(c, 1, "card") end
  end,
}

variant("trick_shots", {
  name = "Trick Shots", cost = 1, type = "power", rarity = "rare", path = "beast_mastery",
  power = true, effects = {}, hooks = trickShotsHooks,
  text = "Power.\nAttacks: +1 Frenzy.",
  up = { cost = 0, text = "Power.\nAttacks: +1 Frenzy." },
  up2 = { innate = true, text = "Power.\nAttacks: +1 Frenzy.\nInnate." },
  up3 = { effects = { { "res", 2 } }, text = "Power.\n+2 Frenzy.\nAttacks: +1 Frenzy.\nInnate." },
})

-- Aspect of the Turtle : chaque coup d'une carte Attack donne 1 Absorb (onAttackHit).
local turtleHooks = {
  onAttackHit = function(c) if not c.result then Combat.gainBlock(c, c.player, 1) end end,
}

variant("aspect_of_the_turtle", {
  name = "Aspect of the Turtle", cost = 2, type = "power", rarity = "uncommon", path = "beast_mastery",
  power = true, effects = {}, hooks = turtleHooks,
  text = "Power.\nEach Attack hit: gain 1 Absorb.",
  up = { cost = 1, text = "Power.\nEach Attack hit: gain 1 Absorb." },
  up2 = { innate = true, text = "Power.\nEach Attack hit: gain 1 Absorb.\nInnate." },
  up3 = { effects = { { "absorb", 5 } }, text = "Power.\nGain 5 Absorb.\nEach Attack hit: gain 1 Absorb.\nInnate." },
})

-- Bibelots du Chasseur (class = "hunter" : tirés seulement pour lui) -------------------------------
-- level = niveau de classe qui les débloque (dans la réserve de la classe ; la Ligue ne compte pas).

local R = ns.Relics
local function relic(id, t)
  t.id = id
  t.class = "hunter"
  t.hooks = t.hooks or {}
  R[id] = t
end

-- Bibelot de départ : le familier frappe dès le début du premier tour (Frenzy 1 au premier tour).
-- Sans familier (Lone Wolf) : +1 Frenzy à la place (loneText, montré par UI/Art/hunter.lua).
relic("pet_whistle", {
  level = 1, name = "Pet Whistle", rarity = "common", noPool = true,
  text = "At the start of the first turn, the pet attacks.",
  loneText = "At the start of each combat, +1 Frenzy.",
  hooks = {
    onTurnStart = function(c)
      if c.round ~= 1 then return end
      if H().petPresent(c) then H().petAttack(c, "relic") else Combat.gainRes(c, 1, "relic") end
    end,
  },
})

relic("kiblers_bits", {
  level = 1, name = "Kibler's Bits", rarity = "common",
  text = "At the start of each combat, +1 Frenzy.",
  hooks = {
    onCombatStart = function(c) Combat.gainRes(c, 1, "relic") end,
  },
})

relic("light_quiver", {
  level = 3, name = "Light Quiver", rarity = "common",
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
  level = 5, name = "Net-o-Matic Projector", rarity = "uncommon",
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
  level = 7, name = "Devilsaur Eye", rarity = "uncommon",
  text = "When an enemy dies, +2 Frenzy.",
  hooks = {
    onEnemyDeath = function(c) if not c.result then Combat.gainRes(c, 2, "relic") end end,
  },
})

relic("rhokdelar", {
  level = 7, name = "Rhok'delar", rarity = "rare",
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
  id = "hunter", name = "Hunter", order = 5, hp = 50,
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
      dire_beast = 10.5, the_beast_within = 10.5, feign_death = 8.5, wyvern_sting = 8.5, counter_shot = 8,
      growl = 8, multi_shot = 7.5, intimidation = 7, kill_command = 7, spirit_bond = 7, rapid_fire = 6.5,
      explosive_trap = 5.5, counterattack = 5, wailing_arrow = 5, concussive_shot = 4.5, raptor_strike = 4.5,
      cobra_shot = 4, trueshot_aura = 4, barbed_shot = 3.5, bestial_wrath = 3.5, aimed_shot = 3,
      entrapment = 3, frost_trap = 3, hunters_mark = 3, immolation_trap = 3, lock_and_load = 3,
      readiness = 3, resourcefulness = 3, steady_shot = 3, volley = 3,
    },
    upgrade = { arcane_shot = 2.5, disengage = 2, serpent_sting = 1.5, freezing_trap = 1.5 },
    remove = { disengage = 1, arcane_shot = 1.5 },
    -- note d'une épique pour l'offre et le remplacement (Sim/expedition.lua, SE.epicRating) : ≈ 5 + gain / 2
    -- mesuré (epic=<id> contre sans, Westfall, clé 0, zones=7)
    -- l'épique du deck vaut EPIC_KEEP de plus : le deck est construit autour, la remplacer est un pari (et
    -- une épique imposée par epic=<id> reste mesurée seule)
    epic = function(exp, id)
      local v = EPIC_BOT[id]
      local i = v and exp and ns.Expedition.epicIndex(exp)
      if i and exp.deck[i].id == id then v = v + EPIC_KEEP end
      return v
    end,
    -- builds pilotés par l'épique du deck (Sim/expedition.lua, byEpic) : notes qui priment tant que
    -- l'épique est dans le deck (« Deck piloté » de la fiche) ; variantes de Lone Wolf notées sous l'id
    -- d'origine (c'est lui que proposent les récompenses).
    byEpic = {
      call_of_the_wild = {
        rating = { kill_command = 8.5, dire_beast = 11, bestial_wrath = 6.5, spirit_bond = 8.5, the_beast_within = 11,
          barbed_shot = 6, intimidation = 7.5, cobra_shot = 5.5, aimed_shot = 1.5, steady_shot = 1.5, volley = 1.5 },
        upgrade = { call_of_the_wild = 4, kill_command = 3.5 },
        remove = { disengage = 0.5 },
      },
      trap_launcher = {
        rating = { immolation_trap = 6.5, counterattack = 8, explosive_trap = 8, frost_trap = 4, entrapment = 4,
          lock_and_load = 3, resourcefulness = 4.5, spirit_bond = 8, raptor_strike = 3 },
        upgrade = { trap_launcher = 4, counterattack = 3.5, freezing_trap = 3.5 },
        remove = { disengage = 0.5 },
      },
      beast_cleave = {
        rating = { kill_command = 8.5, dire_beast = 11.5, bestial_wrath = 7, barbed_shot = 5.5, cobra_shot = 5.5,
          intimidation = 7.5, the_beast_within = 11, spirit_bond = 8, multi_shot = 4, volley = 2, explosive_trap = 4 },
        upgrade = { beast_cleave = 4, dire_beast = 3.5 },
        remove = { disengage = 0.5 },
      },
      roar_of_sacrifice = {
        rating = { barbed_shot = 7.5, cobra_shot = 7, kill_command = 8, dire_beast = 11, the_beast_within = 11,
          intimidation = 7.5, spirit_bond = 8, bestial_wrath = 1.5, growl = 4 },
        upgrade = { roar_of_sacrifice = 4, barbed_shot = 3.5 },
        remove = { disengage = 0.3 },
      },
      master_marksman = {
        rating = { aimed_shot = 10.5, trueshot_aura = 8.5, steady_shot = 8, volley = 2 },
        upgrade = { master_marksman = 4, aimed_shot = 3.5 },
        remove = { arcane_shot = 0.8, disengage = 1 },
      },
      black_arrow = {
        rating = { barbed_shot = 7.5, immolation_trap = 7.5, explosive_trap = 7.5, wyvern_sting = 9, spirit_bond = 8,
          kill_command = 7.5, bestial_wrath = 6, aimed_shot = 1.5, steady_shot = 1.5, volley = 1.5 },
        upgrade = { black_arrow = 4, serpent_sting = 3.5 },
        remove = { disengage = 0.5 },
      },
      lone_wolf = {
        rating = { rapid_fire = 10, kill_command = 8.5, multi_shot = 7.5, the_beast_within = 10, cobra_shot = 6,
          barbed_shot = 7.5, concussive_shot = 5, raptor_strike = 4, dire_beast = 9, bestial_wrath = 8.5,
          spirit_bond = 3, intimidation = 4.5, counter_shot = 4, growl = 3, counterattack = 3, explosive_trap = 3,
          wyvern_sting = 5, aimed_shot = 2, steady_shot = 2, volley = 2 },
        upgrade = { lone_wolf = 4, rapid_fire = 3.5, arcane_shot = 3 },
        remove = { disengage = 0.5 },
      },
    },
  },
}
