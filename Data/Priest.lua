-- Cartes du Prêtre. Chiffres = points de départ, à corriger par la simulation.
-- Champs : name, cost, type (attack|skill|power), school (holy|shadow), rarity
-- (basic|common|uncommon|rare), path (discipline|shadow|holy|start), target ("enemy" ou nil),
-- effects, text, et up = champs remplacés par l'amélioration (dont text).
-- rep = palier de réputation de classe qui débloque la carte (0 Neutre, 1 Amical, 2 Honoré) ;
-- absent sur les cartes de départ.
-- Mots-clés : cast (incantation), cooldown = N, exhaust (Consumée), retain (Conservée),
-- power (Pouvoir, avec hooks).
-- Écriture de `text` (docs/interface.md, « Langage des cartes », textes affichés en anglais) : une
-- clause par ligne, séparées par « \n » ; « Status: effect » = si l'état est présent (sur soi pour un
-- bienfait, sur la cible pour un affaiblissement) ; conditions nommées : Execute, Surge, Last Breath,
-- Shadow ; chaque état posé par les effets a sa ligne, en dernier, sans point : « Gain » (sur soi,
-- suivi du nom de l'état) ou « Apply » (sur un ennemi, « to all » pour tous), nom, nombre, et « ⌛ »
-- si le nombre est une durée en tours (état `duration` ou `turns`, Core/Statuses.lua). Les mots de la
-- plaque du bas (« Power. », « Cast. » en tête, « Cooldown N. », « Exhaust. », « Retain. » en fin)
-- restent dans le texte et sont retirés à l'affichage.
local _, ns = ...

local Combat = ns.Combat
local C = ns.Cards

local function card(id, t)
  t.id = id
  t.class = "priest"
  C[id] = t
end

-- Départ -------------------------------------------------------------------

card("smite", {
  name = "Smite", cost = 1, type = "attack", school = "holy", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 6 } },
  text = "Deal 6.",
  up = { effects = { { "damage", 9 } }, text = "Deal 9." },
})

card("inner_fire", {
  name = "Inner Fire", cost = 1, type = "skill", school = "holy", rarity = "basic", path = "start",
  effects = { { "absorb", 5 } },
  text = "Gain 5 Absorb.",
  up = { effects = { { "absorb", 8 } }, text = "Gain 8 Absorb." },
})

card("pw_shield", {
  name = "PW: Shield", cost = 1, type = "skill", school = "holy", rarity = "basic", path = "start",
  cooldown = 2, effects = { { "absorb", 8 } },
  text = "Gain 8 Absorb.\nCooldown 2.",
  up = { effects = { { "absorb", 11 } }, text = "Gain 11 Absorb.\nCooldown 2." },
})

card("sw_pain", {
  name = "SW: Pain", cost = 1, type = "skill", school = "shadow", rarity = "basic", path = "start",
  target = "enemy", effects = { { "apply", "pain", 5 }, { "res", 1 } },
  text = "+1 Insanity.\nApply DoT 5",
  up = { effects = { { "apply", "pain", 7 }, { "res", 1 } }, text = "+1 Insanity.\nApply DoT 7" },
})

-- Discipline ----------------------------------------------------------------

card("radiance", {
  rep = 0, name = "PW: Radiance", cost = 1, type = "skill", school = "holy", rarity = "common", path = "discipline",
  effects = { { "apply", "atonement", 1, self = true }, { "absorb", 4 } },
  text = "Gain 4 Absorb.\nGain Atonement 1 ⌛",
  up = { effects = { { "apply", "atonement", 2, self = true }, { "absorb", 6 } },
    text = "Gain 6 Absorb.\nGain Atonement 2 ⌛" },
})

local function penanceHit(c, ctx, t)
  if (c.player.st.atonement or 0) > 0 then Combat.gainBlock(c, c.player, 2) end
end

card("penance", {
  rep = 0, name = "Penance", cost = 2, type = "attack", school = "holy", rarity = "uncommon", path = "discipline",
  target = "enemy", effects = { { "damage", 6, times = 3, onHit = penanceHit } },
  text = "Deal 6 three times.\nAtonement: +2 Absorb per hit.",
  up = { effects = { { "damage", 8, times = 3, onHit = penanceHit } },
    text = "Deal 8 three times.\nAtonement: +2 Absorb per hit." },
})

card("pain_suppression", {
  rep = 0, name = "Pain Suppression", cost = 1, type = "skill", school = "holy", rarity = "rare", path = "discipline",
  cooldown = 4, effects = { { "apply", "halved", 1, self = true } },
  text = "Damage taken halved until next turn.\nCooldown 4.",
  up = { cooldown = 3, text = "Damage taken halved until next turn.\nCooldown 3." },
})

local function solaceMana(c, ctx)
  if (c.player.st.atonement or 0) > 0 then
    c.player.mana = c.player.mana + 1
    Combat.log(c, { t = "mana", n = 1, total = c.player.mana })
  end
end

card("solace", {
  rep = 0, name = "PW: Solace", cost = 1, type = "attack", school = "holy", rarity = "common", path = "discipline",
  target = "enemy", effects = { { "fn", solaceMana }, { "damage", 5 }, { "apply", "atonement", 1, self = true } },
  text = "Deal 5.\nAtonement: +1 mana.\nGain Atonement 1 ⌛",
  up = { effects = { { "fn", solaceMana }, { "damage", 8 }, { "apply", "atonement", 1, self = true } },
    text = "Deal 8.\nAtonement: +1 mana.\nGain Atonement 1 ⌛" },
})

card("angelic_feather", {
  rep = 0, name = "Angelic Feather", cost = 0, type = "skill", school = "holy", rarity = "common", path = "discipline",
  cooldown = 2, effects = { { "absorb", 2 }, { "draw", 1 } },
  text = "Gain 2 Absorb.\nDraw 1.\nCooldown 2.",
  up = { effects = { { "absorb", 4 }, { "draw", 1 } }, text = "Gain 4 Absorb.\nDraw 1.\nCooldown 2." },
})

card("luminous_barrier", {
  rep = 0, name = "Luminous Barrier", cost = 2, type = "skill", school = "holy", rarity = "common", path = "discipline",
  cooldown = 2, effects = { { "absorb", 12 }, { "apply", "atonement", 1, self = true } },
  text = "Gain 12 Absorb.\nGain Atonement 1 ⌛\nCooldown 2.",
  up = { effects = { { "absorb", 16 }, { "apply", "atonement", 1, self = true } },
    text = "Gain 16 Absorb.\nGain Atonement 1 ⌛\nCooldown 2." },
})

card("schism", {
  rep = 0, name = "Schism", cost = 1, type = "attack", school = "shadow", rarity = "uncommon", path = "discipline",
  target = "enemy",
  effects = { { "damage", 3 }, { "apply", "armor_broken", 2 }, { "apply", "atonement", 1, self = true } },
  text = "Deal 3.\nApply Sundered 2 ⌛\nGain Atonement 1 ⌛",
  up = { effects = { { "damage", 6 }, { "apply", "armor_broken", 3 }, { "apply", "atonement", 1, self = true } },
    text = "Deal 6.\nApply Sundered 3 ⌛\nGain Atonement 1 ⌛" },
})

card("shadow_mend", {
  rep = 1, name = "Shadow Mend", cost = 1, type = "skill", school = "shadow", rarity = "common", path = "discipline",
  exhaust = true, effects = { { "heal", 10 }, { "apply", "pain", 2, self = true }, { "res", 1 } },
  text = "Heal 10.\n+1 Insanity.\nGain DoT 2\nExhaust.",
  up = { effects = { { "heal", 14 }, { "apply", "pain", 2, self = true }, { "res", 1 } },
    text = "Heal 14.\n+1 Insanity.\nGain DoT 2\nExhaust." },
})

card("evangelism", {
  rep = 1, name = "Evangelism", cost = 1, type = "skill", school = "holy", rarity = "uncommon", path = "discipline",
  exhaust = true, effects = { { "apply", "atonement", 2, self = true }, { "draw", 2 } },
  text = "Draw 2.\nGain Atonement 2 ⌛\nExhaust.",
  up = { cost = 0, text = "Draw 2.\nGain Atonement 2 ⌛\nExhaust." },
})

local function raptureHooks(bonus)
  return {
    block = function(c, power, v) return v + bonus end,
  }
end

card("rapture", {
  rep = 2, name = "Rapture", cost = 1, type = "power", school = "holy", rarity = "rare", path = "discipline",
  power = true, effects = {}, hooks = raptureHooks(1),
  text = "Power.\nEach Absorb gain: +1.",
  up = { hooks = raptureHooks(2), text = "Power.\nEach Absorb gain: +2." },
})

-- Ombre -----------------------------------------------------------------------

-- Condition sur l'état de la cible, lue AVANT le coup (comme à l'origine).
local FLAY = { { "res", 2, cond = "status:pain" }, { "draw", 1, cond = "status:pain" } }

card("mind_flay", {
  rep = 0, name = "Mind Flay", cost = 1, type = "attack", school = "shadow", rarity = "common", path = "shadow",
  target = "enemy", effects = { FLAY[1], FLAY[2], { "damage", 8 } },
  text = "Deal 8.\nDoT: +2 Insanity, draw 1.",
  up = { effects = { FLAY[1], FLAY[2], { "damage", 11 } }, text = "Deal 11.\nDoT: +2 Insanity, draw 1." },
})

card("mind_blast", {
  rep = 0, name = "Mind Blast", cost = 1, type = "attack", school = "shadow", rarity = "common", path = "shadow",
  target = "enemy", cooldown = 1, effects = { { "damage", 10 }, { "res", 2 } },
  text = "Deal 10.\n+2 Insanity.\nCooldown 1.",
  up = { effects = { { "damage", 13 }, { "res", 2 } }, text = "Deal 13.\n+2 Insanity.\nCooldown 1." },
})

-- DoT posé directement (Combat.applyStatus) : le crochet « apply » de Forme d'ombre ne s'y ajoute pas.
local function plague(c, ctx)
  local n = ctx.surge or 0
  if n > 0 and ctx.target and not ctx.target.dead then
    Combat.applyStatus(c, ctx.target, "pain", (ctx.def.plagueMult or 2) * n)
  end
end

card("devouring_plague", {
  rep = 0, name = "Devouring Plague", cost = 0, type = "skill", school = "shadow", rarity = "uncommon", path = "shadow",
  target = "enemy", plagueMult = 2, minRes = 1, effects = { { "surge" }, { "fn", plague } },
  text = "Surge: apply DoT 2 per Insanity.",
  up = { plagueMult = 3, text = "Surge: apply DoT 3 per Insanity." },
})

-- Forme d'ombre : l'interdiction des cartes sacrées (version d'origine), puis un surcoût
-- d'1 mana, rendaient la carte injouable avec un deck de départ presque tout sacré
-- (voir docs/equilibrage.md). Elle ne fait plus que renforcer l'ombre.
local function shadowformHooks(bonus)
  return {
    damage = function(c, power, v, dst, cardDef)
      if cardDef and cardDef.school == "shadow" then return v + bonus end
      return v
    end,
    apply = function(c, power, n, id, target, cardDef)
      if id == "pain" and cardDef and cardDef.school == "shadow" then return n + bonus end
      return n
    end,
  }
end

card("shadowform", {
  rep = 0, name = "Shadowform", cost = 1, type = "power", school = "shadow", rarity = "rare", path = "shadow",
  power = true, effects = { { "res", 2 } }, hooks = shadowformHooks(3),
  text = "Power.\n+2 Insanity.\nShadow: damage and DoT +3.",
  up = { hooks = shadowformHooks(4),
    text = "Power.\n+2 Insanity.\nShadow: damage and DoT +4." },
})

card("silence", {
  rep = 0, name = "Silence", cost = 0, type = "skill", school = "shadow", rarity = "uncommon", path = "shadow",
  target = "enemy", cooldown = 2, effects = { { "interrupt" }, { "draw", 1 } },
  text = "Interrupt the target's cast.\nDraw 1.\nCooldown 2.",
  up = { cooldown = 1, text = "Interrupt the target's cast.\nDraw 1.\nCooldown 1." },
})

card("vampiric_touch", {
  rep = 0, name = "Vampiric Touch", cost = 1, type = "skill", school = "shadow", rarity = "common", path = "shadow",
  target = "enemy", effects = { { "apply", "pain", 3 }, { "apply", "regen", 1, self = true }, { "res", 1 } },
  text = "+1 Insanity.\nApply DoT 3\nGain Regen 1",
  up = { effects = { { "apply", "pain", 5 }, { "apply", "regen", 2, self = true }, { "res", 1 } },
    text = "+1 Insanity.\nApply DoT 5\nGain Regen 2" },
})

card("mind_sear", {
  rep = 1, name = "Mind Sear", cost = 1, type = "skill", school = "shadow", rarity = "common", path = "shadow",
  effects = { { "apply", "pain", 4, all = true }, { "res", 1 } },
  text = "+1 Insanity.\nApply DoT 4 to all",
  up = { effects = { { "apply", "pain", 6, all = true }, { "res", 1 } }, text = "+1 Insanity.\nApply DoT 6 to all" },
})

card("sw_death", {
  rep = 1, name = "SW: Death", cost = 1, type = "attack", school = "shadow", rarity = "uncommon", path = "shadow",
  target = "enemy", effects = { { "damage", 6, more = { { 6, "execute" } } }, { "res", 1 } },
  text = "Deal 6.\nExecute: deal 12.\n+1 Insanity.",
  up = { effects = { { "damage", 8, more = { { 9, "execute" } } }, { "res", 1 } },
    text = "Deal 8.\nExecute: deal 17.\n+1 Insanity." },
})

card("psychic_scream", {
  rep = 2, name = "Psychic Scream", cost = 1, type = "skill", school = "shadow", rarity = "uncommon", path = "shadow",
  cooldown = 3, effects = { { "apply", "demoralized", 2, all = true }, { "res", 1 } },
  text = "+1 Insanity.\nApply Demoralized 2 ⌛ to all\nCooldown 3.",
  up = { cost = 0, text = "+1 Insanity.\nApply Demoralized 2 ⌛ to all\nCooldown 3." },
})

card("void_eruption", {
  rep = 2, name = "Void Eruption", cost = 1, type = "attack", school = "shadow", rarity = "rare", path = "shadow",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "damage", 4, per = { 4, "surge" } } },
  text = "Surge: deal 4 + 4 per Insanity.",
  up = { effects = { { "surge" }, { "damage", 4, per = { 5, "surge" } } }, text = "Surge: deal 4 + 5 per Insanity." },
})

-- Sacré -----------------------------------------------------------------------
-- Les incantations frappent fort : elles paient le risque d'être interrompues.

card("holy_fire", {
  rep = 0, name = "Holy Fire", cost = 2, type = "attack", school = "holy", rarity = "common", path = "holy",
  target = "enemy", cast = true, effects = { { "damage", 24 }, { "apply", "pain", 3 } },
  text = "Cast.\nDeal 24.\nApply DoT 3",
  up = { effects = { { "damage", 31 }, { "apply", "pain", 4 } }, text = "Cast.\nDeal 31.\nApply DoT 4" },
})

card("holy_nova", {
  rep = 0, name = "Holy Nova", cost = 1, type = "attack", school = "holy", rarity = "common", path = "holy",
  effects = { { "damage", 4, all = true }, { "apply", "regen", 2, self = true } },
  text = "Deal 4 to all.\nGain Regen 2",
  up = { effects = { { "damage", 6, all = true }, { "apply", "regen", 3, self = true } },
    text = "Deal 6 to all.\nGain Regen 3" },
})

card("chastise", {
  rep = 0, name = "Holy Word: Chastise", cost = 1, type = "attack", school = "holy", rarity = "uncommon", path = "holy",
  target = "enemy", cooldown = 3, effects = { { "damage", 7 }, { "apply", "stunned", 1 } },
  text = "Deal 7.\nApply Stunned 1 ⌛\nCooldown 3.",
  up = { cooldown = 2, effects = { { "damage", 10 }, { "apply", "stunned", 1 } }, text = "Deal 10.\nApply Stunned 1 ⌛\nCooldown 2." },
})

card("greater_heal", {
  rep = 0, name = "Greater Heal", cost = 1, type = "skill", school = "holy", rarity = "uncommon", path = "holy",
  cast = true, exhaust = true, effects = { { "heal", 12 } },
  text = "Cast.\nHeal 12.\nExhaust.",
  up = { effects = { { "heal", 16 } }, text = "Cast.\nHeal 16.\nExhaust." },
})

card("spirit_of_redemption", {
  rep = 0, name = "Spirit of Redemption", cost = 1, type = "power", school = "holy", rarity = "rare", path = "holy",
  power = true, effects = {},
  hooks = {
    preventDeath = function(c, power)
      local f = c.player.flags
      if f.redeemed then return false end
      f.redeemed = true
      f.freeTurn = true
      c.player.hp = 1
      Combat.applyStatus(c, c.player, "regen", 6)
      return true
    end,
  },
  text = "Power.\nLast Breath: stay at 1 HP, Regen 6, free turn.",
  up = { cost = 0,
    text = "Power.\nLast Breath: stay at 1 HP, Regen 6, free turn." },
})

card("renew", {
  rep = 0, name = "Renew", cost = 1, type = "skill", school = "holy", rarity = "common", path = "holy",
  exhaust = true, effects = { { "apply", "regen", 3, self = true } },
  text = "Gain Regen 3\nExhaust.",
  up = { effects = { { "apply", "regen", 5, self = true } }, text = "Gain Regen 5\nExhaust." },
})

card("halo", {
  rep = 0, name = "Halo", cost = 2, type = "attack", school = "holy", rarity = "uncommon", path = "holy",
  cast = true, effects = { { "damage", 15, all = true }, { "apply", "regen", 3, self = true } },
  text = "Cast.\nDeal 15 to all.\nGain Regen 3",
  up = { effects = { { "damage", 19, all = true }, { "apply", "regen", 4, self = true } },
    text = "Cast.\nDeal 19 to all.\nGain Regen 4" },
})

card("flash_heal", {
  rep = 1, name = "Flash Heal", cost = 1, type = "skill", school = "holy", rarity = "common", path = "holy",
  exhaust = true, effects = { { "heal", 7 }, { "draw", 1 } },
  text = "Heal 7.\nDraw 1.\nExhaust.",
  up = { effects = { { "heal", 10 }, { "draw", 1 } }, text = "Heal 10.\nDraw 1.\nExhaust." },
})

card("empyreal_blaze", {
  rep = 2, name = "Empyreal Blaze", cost = 2, type = "attack", school = "holy", rarity = "uncommon", path = "holy",
  target = "enemy", cast = true, effects = { { "damage", 28 }, { "apply", "armor_broken", 2 } },
  text = "Cast.\nDeal 28.\nApply Sundered 2 ⌛",
  up = { effects = { { "damage", 36 }, { "apply", "armor_broken", 2 } }, text = "Cast.\nDeal 36.\nApply Sundered 2 ⌛" },
})

-- Apothéose : une pioche en plus ne valait rien (3 mana pour 5 cartes à 1 mana : la main
-- déborde déjà) ; elle donne du mana.
local apotheosisHooks = {
  cost = function(c, power, v, cardDef)
    if cardDef.cast then return v - 1 end
    return v
  end,
  maxMana = function(c, power, v) return v + 1 end,
}

card("apotheosis", {
  rep = 2, name = "Apotheosis", cost = 2, type = "power", school = "holy", rarity = "rare", path = "holy",
  power = true, effects = {}, hooks = apotheosisHooks,
  text = "Power.\n+1 mana per turn.\nCast cards: cost −1.",
  up = { cost = 1, text = "Power.\n+1 mana per turn.\nCast cards: cost −1." },
})

-- Classe ------------------------------------------------------------------------

-- Définition de classe (contrat : docs/classes.md).
ns.Classes.priest = {
  id = "priest", name = "Priest", order = 1, hp = 65,
  -- Insanity : sans plafond, gardée d'un tour à l'autre (GDD, décision du 11/11/2026)
  resource = { id = "insanity", cap = nil, keep = true },
  deck = {
    "smite", "smite", "smite", "smite",
    "inner_fire", "inner_fire", "inner_fire", "inner_fire",
    "pw_shield", "sw_pain",
  },
  startRelic = nil,
  paths = { { id = "discipline", name = "Discipline" }, { id = "shadow", name = "Shadow" }, { id = "holy", name = "Holy" } },
  survival = "heal",
  -- Conseils aux bots de simulation (Sim/) : valeur d'un point de ressource (unités de Bots.W, 10 = 1 PV),
  -- note des cartes pour les choix (≈ 5 + écart de victoires / 2, balayages sweep=cards), valeur des
  -- cartes de départ pour l'amélioration (upgrade) et pour le retrait (remove ; les autres : note + 2).
  bot = {
    resValue = 1.5,
    rating = {
      vampiric_touch = 7, angelic_feather = 6, flash_heal = 6, solace = 6, luminous_barrier = 6,
      mind_sear = 6, radiance = 5, holy_nova = 5, shadow_mend = 5, renew = 5, mind_blast = 5,
      holy_fire = 5, mind_flay = 4,
      schism = 6, psychic_scream = 6, silence = 5, evangelism = 5, greater_heal = 5, chastise = 5,
      penance = 5, devouring_plague = 4, sw_death = 4, halo = 4, empyreal_blaze = 4,
      rapture = 7, pain_suppression = 7, shadowform = 5, apotheosis = 5, void_eruption = 4,
      spirit_of_redemption = 4,
    },
    upgrade = { smite = 2.5, inner_fire = 2, pw_shield = 1.5, sw_pain = 1.5 },
    upgradeRun = { smite = 2.5, inner_fire = 2 }, -- ancien coureur (Sim/run.lua)
    remove = { inner_fire = 1, smite = 1.5 },
  },
}
