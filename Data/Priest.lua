-- Cartes du Prêtre. Chiffres = points de départ, à corriger par la simulation.
-- Champs : name, cost, type (attack|skill|power), school (holy|shadow), rarity
-- (basic|common|uncommon|rare), path (discipline|shadow|holy|start), target ("enemy" ou nil),
-- effects, text, et up = champs remplacés par l'amélioration (dont text).
-- level = niveau de classe qui débloque la carte (1 à 7, docs/classes/priest-progression.md ;
-- Core/Meta.lua).
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
  level = 1, name = "Smite", cost = 1, type = "attack", school = "holy", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 8 } },
  text = "Deal 8.",
  up = { effects = { { "damage", 11 } }, text = "Deal 11." },
})

card("inner_fire", {
  level = 1, name = "Inner Fire", cost = 1, type = "skill", school = "holy", rarity = "basic", path = "start",
  effects = { { "absorb", 6 } },
  text = "Gain 6 Absorb.",
  up = { effects = { { "absorb", 9 } }, text = "Gain 9 Absorb." },
})

card("pw_shield", {
  level = 1, name = "PW: Shield", cost = 1, type = "skill", school = "holy", rarity = "basic", path = "start",
  cooldown = 2, effects = { { "absorb", 8 } },
  text = "Gain 8 Absorb.\nCooldown 2.",
  up = { effects = { { "absorb", 11 } }, text = "Gain 11 Absorb.\nCooldown 2." },
})

card("sw_pain", {
  level = 1, name = "SW: Pain", cost = 1, type = "skill", school = "shadow", rarity = "basic", path = "start",
  target = "enemy", effects = { { "apply", "pain", 5 }, { "res", 1 } },
  text = "+1 Insanity.\nApply DoT 5",
  up = { effects = { { "apply", "pain", 7 }, { "res", 1 } }, text = "+1 Insanity.\nApply DoT 7" },
})

-- Discipline ----------------------------------------------------------------

card("radiance", {
  level = 1, name = "PW: Radiance", cost = 1, type = "skill", school = "holy", rarity = "common", path = "discipline",
  effects = { { "apply", "atonement", 1, self = true }, { "absorb", 4 } },
  text = "Gain 4 Absorb.\nGain Atonement 1 ⌛",
  up = { effects = { { "apply", "atonement", 2, self = true }, { "absorb", 6 } },
    text = "Gain 6 Absorb.\nGain Atonement 2 ⌛" },
})

local function penanceHit(c, ctx, t)
  if (c.player.st.atonement or 0) > 0 then Combat.gainBlock(c, c.player, 2) end
end

card("penance", {
  level = 1, name = "Penance", cost = 2, type = "attack", school = "holy", rarity = "uncommon", path = "discipline",
  target = "enemy", effects = { { "damage", 5, times = 3, onHit = penanceHit } },
  text = "Deal 5 three times.\nAtonement: +2 Absorb per hit.",
  up = { effects = { { "damage", 7, times = 3, onHit = penanceHit } },
    text = "Deal 7 three times.\nAtonement: +2 Absorb per hit." },
})

card("pain_suppression", {
  level = 1, name = "Pain Suppression", cost = 1, type = "skill", school = "holy", rarity = "rare", path = "discipline",
  cooldown = 5, effects = { { "apply", "halved", 1, self = true } },
  text = "Damage taken halved until next turn.\nCooldown 5.",
  up = { cooldown = 4, text = "Damage taken halved until next turn.\nCooldown 4." },
})

local function solaceMana(c, ctx)
  if (c.player.st.atonement or 0) > 0 then
    c.player.mana = c.player.mana + 1
    Combat.log(c, { t = "mana", n = 1, total = c.player.mana })
  end
end

card("solace", {
  level = 1, name = "PW: Solace", cost = 1, type = "attack", school = "holy", rarity = "common", path = "discipline",
  target = "enemy", effects = { { "fn", solaceMana }, { "damage", 4 }, { "apply", "atonement", 1, self = true } },
  text = "Deal 4.\nAtonement: +1 mana.\nGain Atonement 1 ⌛",
  up = { effects = { { "fn", solaceMana }, { "damage", 6 }, { "apply", "atonement", 1, self = true } },
    text = "Deal 6.\nAtonement: +1 mana.\nGain Atonement 1 ⌛" },
})

card("angelic_feather", {
  level = 1, name = "Angelic Feather", cost = 0, type = "skill", school = "holy", rarity = "common", path = "discipline",
  cooldown = 3, effects = { { "absorb", 2 }, { "draw", 1 } },
  text = "Gain 2 Absorb.\nDraw 1.\nCooldown 3.",
  up = { effects = { { "absorb", 4 }, { "draw", 1 } }, text = "Gain 4 Absorb.\nDraw 1.\nCooldown 3." },
})

card("luminous_barrier", {
  level = 4, name = "Luminous Barrier", cost = 2, type = "skill", school = "holy", rarity = "common", path = "discipline",
  cooldown = 2, effects = { { "absorb", 14 }, { "apply", "atonement", 1, self = true } },
  text = "Gain 14 Absorb.\nGain Atonement 1 ⌛\nCooldown 2.",
  up = { effects = { { "absorb", 18 }, { "apply", "atonement", 1, self = true } },
    text = "Gain 18 Absorb.\nGain Atonement 1 ⌛\nCooldown 2." },
})

card("schism", {
  level = 1, name = "Schism", cost = 1, type = "attack", school = "shadow", rarity = "uncommon", path = "discipline",
  target = "enemy",
  effects = { { "damage", 3 }, { "apply", "armor_broken", 2 }, { "apply", "atonement", 1, self = true } },
  text = "Deal 3.\nApply Sundered 2 ⌛\nGain Atonement 1 ⌛",
  up = { effects = { { "damage", 6 }, { "apply", "armor_broken", 3 }, { "apply", "atonement", 1, self = true } },
    text = "Deal 6.\nApply Sundered 3 ⌛\nGain Atonement 1 ⌛" },
})

card("shadow_mend", {
  level = 6, name = "Shadow Mend", cost = 1, type = "skill", school = "shadow", rarity = "common", path = "discipline",
  exhaust = true, effects = { { "heal", 12 }, { "apply", "pain", 2, self = true }, { "res", 1 } },
  text = "Heal 12.\n+1 Insanity.\nGain DoT 2\nExhaust.",
  up = { effects = { { "heal", 16 }, { "apply", "pain", 2, self = true }, { "res", 1 } },
    text = "Heal 16.\n+1 Insanity.\nGain DoT 2\nExhaust." },
})

card("evangelism", {
  level = 2, name = "Evangelism", cost = 1, type = "skill", school = "holy", rarity = "uncommon", path = "discipline",
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
  level = 7, name = "Rapture", cost = 1, type = "power", school = "holy", rarity = "rare", path = "discipline",
  power = true, effects = {}, hooks = raptureHooks(2),
  text = "Power.\nEach Absorb gain: +2.",
  up = { hooks = raptureHooks(3), text = "Power.\nEach Absorb gain: +3." },
})

-- Ombre -----------------------------------------------------------------------

-- Condition sur l'état de la cible, lue AVANT le coup (comme à l'origine).
local FLAY = { { "res", 2, cond = "status:pain" }, { "draw", 1, cond = "status:pain" } }

card("mind_flay", {
  level = 1, name = "Mind Flay", cost = 1, type = "attack", school = "shadow", rarity = "common", path = "shadow",
  target = "enemy", effects = { FLAY[1], FLAY[2], { "damage", 8 } },
  text = "Deal 8.\nDoT: +2 Insanity, draw 1.",
  up = { effects = { FLAY[1], FLAY[2], { "damage", 11 } }, text = "Deal 11.\nDoT: +2 Insanity, draw 1." },
})

card("mind_blast", {
  level = 1, name = "Mind Blast", cost = 1, type = "attack", school = "shadow", rarity = "common", path = "shadow",
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
  level = 1, name = "Devouring Plague", cost = 0, type = "skill", school = "shadow", rarity = "uncommon", path = "shadow",
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
  level = 1, name = "Shadowform", cost = 1, type = "power", school = "shadow", rarity = "rare", path = "shadow",
  power = true, effects = { { "res", 2 } }, hooks = shadowformHooks(3),
  text = "Power.\n+2 Insanity.\nShadow: damage and DoT +3.",
  up = { hooks = shadowformHooks(4),
    text = "Power.\n+2 Insanity.\nShadow: damage and DoT +4." },
})

card("silence", {
  level = 1, name = "Silence", cost = 0, type = "skill", school = "shadow", rarity = "uncommon", path = "shadow",
  target = "enemy", cooldown = 2, effects = { { "interrupt" }, { "draw", 1 } },
  text = "Interrupt the target's cast.\nDraw 1.\nCooldown 2.",
  up = { cooldown = 1, text = "Interrupt the target's cast.\nDraw 1.\nCooldown 1." },
})

card("vampiric_touch", {
  level = 1, name = "Vampiric Touch", cost = 1, type = "skill", school = "shadow", rarity = "common", path = "shadow",
  target = "enemy", effects = { { "apply", "pain", 3 }, { "apply", "regen", 1, self = true }, { "res", 1 } },
  text = "+1 Insanity.\nApply DoT 3\nGain Regen 1",
  up = { effects = { { "apply", "pain", 5 }, { "apply", "regen", 2, self = true }, { "res", 1 } },
    text = "+1 Insanity.\nApply DoT 5\nGain Regen 2" },
})

card("mind_sear", {
  level = 2, name = "Mind Sear", cost = 1, type = "skill", school = "shadow", rarity = "common", path = "shadow",
  effects = { { "apply", "pain", 5, all = true }, { "res", 1 } },
  text = "+1 Insanity.\nApply DoT 5 to all",
  up = { effects = { { "apply", "pain", 7, all = true }, { "res", 1 } }, text = "+1 Insanity.\nApply DoT 7 to all" },
})

card("sw_death", {
  level = 4, name = "SW: Death", cost = 1, type = "attack", school = "shadow", rarity = "uncommon", path = "shadow",
  target = "enemy", effects = { { "damage", 7, more = { { 7, "execute" } } }, { "res", 1 } },
  text = "Deal 7.\nExecute: deal 14.\n+1 Insanity.",
  up = { effects = { { "damage", 9, more = { { 9, "execute" } } }, { "res", 1 } },
    text = "Deal 9.\nExecute: deal 18.\n+1 Insanity." },
})

card("psychic_scream", {
  level = 6, name = "Psychic Scream", cost = 1, type = "skill", school = "shadow", rarity = "uncommon", path = "shadow",
  cooldown = 3, effects = { { "apply", "demoralized", 2, all = true }, { "res", 1 } },
  text = "+1 Insanity.\nApply Demoralized 2 ⌛ to all\nCooldown 3.",
  up = { cost = 0, text = "+1 Insanity.\nApply Demoralized 2 ⌛ to all\nCooldown 3." },
})

card("void_eruption", {
  level = 7, name = "Void Eruption", cost = 1, type = "attack", school = "shadow", rarity = "rare", path = "shadow",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "damage", 6, per = { 5, "surge" } } },
  text = "Surge: deal 6 + 5 per Insanity.",
  up = { effects = { { "surge" }, { "damage", 6, per = { 6, "surge" } } }, text = "Surge: deal 6 + 6 per Insanity." },
})

-- Sacré -----------------------------------------------------------------------
-- Les incantations frappent fort : elles paient le risque d'être interrompues.

card("holy_fire", {
  level = 1, name = "Holy Fire", cost = 2, type = "attack", school = "holy", rarity = "common", path = "holy",
  target = "enemy", cast = true, effects = { { "damage", 24 }, { "apply", "pain", 3 } },
  text = "Cast.\nDeal 24.\nApply DoT 3",
  up = { effects = { { "damage", 31 }, { "apply", "pain", 4 } }, text = "Cast.\nDeal 31.\nApply DoT 4" },
})

card("holy_nova", {
  level = 1, name = "Holy Nova", cost = 1, type = "attack", school = "holy", rarity = "common", path = "holy",
  effects = { { "damage", 3, all = true }, { "apply", "regen", 2, self = true } },
  text = "Deal 3 to all.\nGain Regen 2",
  up = { effects = { { "damage", 5, all = true }, { "apply", "regen", 3, self = true } },
    text = "Deal 5 to all.\nGain Regen 3" },
})

card("chastise", {
  level = 1, name = "Holy Word: Chastise", cost = 1, type = "attack", school = "holy", rarity = "uncommon", path = "holy",
  target = "enemy", cooldown = 3, effects = { { "damage", 7 }, { "apply", "stunned", 1 } },
  text = "Deal 7.\nApply Stunned 1 ⌛\nCooldown 3.",
  up = { cooldown = 2, effects = { { "damage", 10 }, { "apply", "stunned", 1 } }, text = "Deal 10.\nApply Stunned 1 ⌛\nCooldown 2." },
})

card("greater_heal", {
  level = 1, name = "Greater Heal", cost = 1, type = "skill", school = "holy", rarity = "uncommon", path = "holy",
  cast = true, exhaust = true, effects = { { "heal", 10 } },
  text = "Cast.\nHeal 10.\nExhaust.",
  up = { effects = { { "heal", 13 } }, text = "Cast.\nHeal 13.\nExhaust." },
})

card("spirit_of_redemption", {
  level = 1, name = "Spirit of Redemption", cost = 1, type = "power", school = "holy", rarity = "rare", path = "holy",
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
  level = 1, name = "Renew", cost = 1, type = "skill", school = "holy", rarity = "common", path = "holy",
  exhaust = true, effects = { { "apply", "regen", 3, self = true } },
  text = "Gain Regen 3\nExhaust.",
  up = { effects = { { "apply", "regen", 5, self = true } }, text = "Gain Regen 5\nExhaust." },
})

card("halo", {
  level = 4, name = "Halo", cost = 2, type = "attack", school = "holy", rarity = "uncommon", path = "holy",
  cast = true, effects = { { "damage", 22, all = true }, { "apply", "regen", 3, self = true } },
  text = "Cast.\nDeal 22 to all.\nGain Regen 3",
  up = { effects = { { "damage", 26, all = true }, { "apply", "regen", 4, self = true } },
    text = "Cast.\nDeal 26 to all.\nGain Regen 4" },
})

card("flash_heal", {
  level = 2, name = "Flash Heal", cost = 1, type = "skill", school = "holy", rarity = "common", path = "holy",
  exhaust = true, effects = { { "heal", 7 }, { "draw", 1 } },
  text = "Heal 7.\nDraw 1.\nExhaust.",
  up = { effects = { { "heal", 10 }, { "draw", 1 } }, text = "Heal 10.\nDraw 1.\nExhaust." },
})

card("empyreal_blaze", {
  level = 6, name = "Empyreal Blaze", cost = 2, type = "attack", school = "holy", rarity = "uncommon", path = "holy",
  target = "enemy", cast = true, effects = { { "damage", 36 }, { "apply", "armor_broken", 2 } },
  text = "Cast.\nDeal 36.\nApply Sundered 2 ⌛",
  up = { effects = { { "damage", 44 }, { "apply", "armor_broken", 2 } }, text = "Cast.\nDeal 44.\nApply Sundered 2 ⌛" },
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
  level = 7, name = "Apotheosis", cost = 2, type = "power", school = "holy", rarity = "rare", path = "holy",
  power = true, effects = {}, hooks = apotheosisHooks,
  text = "Power.\n+1 mana per turn.\nCast cards: cost −1.",
  up = { cost = 1, text = "Power.\n+1 mana per turn.\nCast cards: cost −1." },
})

-- Cartes épiques (une par zone, docs/zones/cartes-de-zone.md, « Priest ») ------------------------------
-- Règles en jeu dès le début de chaque combat : ni piochées, ni jouées, sans coût. Leurs crochets
-- (deckHooks) et leurs règles sont dans Core/Classes/priest.lua ; le texte dit l'essentiel, l'infobulle
-- le détail (mots-clés du langage déclarés au même endroit).

local function epic(id, t)
  -- cost = 0 : convention commune (jamais payé ni affiché, Sim/tests.lua exige un coût)
  t.type, t.rarity, t.epic, t.power, t.effects, t.cost = "power", "epic", true, true, {}, 0
  card(id, t)
end

epic("prayer_of_mending", {
  name = "Prayer of Mending", school = "holy", path = "holy", zone = "westfall",
  text = "Epic.\nEach heal: deal the HP restored to a random enemy.",
  up = { text = "Epic.\nEach heal: deal the HP restored + 2 to a random enemy." },
})

epic("misery", {
  name = "Misery", school = "shadow", path = "shadow", zone = "duskwood",
  text = "Epic.\nDoT applied to an enemy also goes to every other enemy.",
  up = { text = "Epic.\nDoT applied to an enemy also goes to every other enemy, +1." },
})

epic("echo_of_light", {
  name = "Echo of Light", school = "holy", path = "holy", zone = "wetlands",
  text = "Epic.\nRegen no longer heals.\nEach Regen tick: deal that much + 7 to all.",
  up = { text = "Epic.\nRegen no longer heals.\nEach Regen tick: deal that much + 9 to all." },
})

epic("shadow_covenant", {
  name = "Shadow Covenant", school = "shadow", path = "discipline", zone = "stranglethorn",
  text = "Epic.\nShadow cards: pay 3 HP per mana, not mana.",
  up = { text = "Epic.\nShadow cards: pay 3 HP per mana, not mana.\nThe first each turn is free." },
})

epic("reflective_shield", {
  name = "Reflective Shield", school = "holy", path = "discipline", zone = "swamp",
  text = "Epic.\nWhen hit: deal the damage absorbed to the attacker, up to 2.",
  up = { text = "Epic.\nWhen hit: deal the damage absorbed to the attacker, up to 4." },
})

epic("voidform", {
  name = "Voidform", school = "shadow", path = "shadow", zone = "steppes",
  text = "Epic.\nSurge cards can't be played.\nPer Insanity: Shadow hits +1.",
  up = { text = "Epic.\nSurge cards can't be played.\nPer Insanity: Shadow hits +2." },
})

epic("inner_focus", {
  name = "Inner Focus", school = "holy", path = "discipline", zone = "blackrock",
  text = "Epic.\nFirst card each turn: Cast, values +75%.",
  up = { text = "Epic.\nFirst card each turn: Cast, values doubled." },
})

-- Bibelots du Prêtre (class = "priest" : tirés seulement pour lui) --------------------------------
-- docs/classes/priest-progression.md, § 2 : un bibelot par moteur (Atonement, Insanity, Regen, Cast).
-- level = niveau de classe qui les débloque (dans la réserve de la classe ; la Ligue ne compte pas).

local R = ns.Relics
local function relic(id, t)
  t.id = id
  t.class = "priest"
  t.hooks = t.hooks or {}
  R[id] = t
end

-- Bibelot de départ : amorce l'Atonement dès le premier tour (posé au début du combat, il couvre le
-- premier tour et le suivant).
relic("sacred_candle", {
  level = 1, name = "Sacred Candle", rarity = "common", noPool = true,
  text = "At the start of each combat, gain Atonement 1 ⌛.",
  hooks = {
    onCombatStart = function(c) Combat.applyStatus(c, c.player, "atonement", 1) end,
  },
})

relic("mindtap_talisman", {
  level = 1, name = "Mindtap Talisman", rarity = "common",
  text = "At the start of each combat, +2 Insanity.",
  hooks = {
    onCombatStart = function(c) Combat.gainRes(c, 2, "relic") end,
  },
})

-- Crochet applySelf : état posé sur le héros (Renew, Holy Nova…), toutes sources.
relic("benediction", {
  level = 3, name = "Benediction", rarity = "uncommon",
  text = "Each Regen gained: +1.",
  hooks = {
    applySelf = function(c, src, v, id)
      if id == "regen" then return v + 1 end
      return v
    end,
  },
})

relic("robes_of_prophecy", {
  level = 5, name = "Robes of Prophecy", rarity = "uncommon",
  text = "Atonement: each Absorb gain +2.",
  hooks = {
    block = function(c, src, v)
      if (c.player.st.atonement or 0) > 0 then return v + 2 end
      return v
    end,
  },
})

-- Crochet surge : montant compté par les effets « … per Insanity » d'un Surge qui a dépensé quelque
-- chose (la ressource dépensée ne change pas).
relic("anathema", {
  level = 7, name = "Anathema", rarity = "rare",
  text = "Surge cards count 2 more Insanity.",
  hooks = {
    surge = function(c, src, v) return v + 2 end,
  },
})

relic("truefaith_vestments", {
  level = 7, name = "Truefaith Vestments", rarity = "rare",
  text = "When a Cast card resolves, gain 4 Absorb.",
  hooks = {
    onCastResolved = function(c) Combat.gainBlock(c, c.player, 4) end,
  },
})

-- Classe ------------------------------------------------------------------------

-- Définition de classe (contrat : docs/classes.md).
ns.Classes.priest = {
  id = "priest", name = "Priest", order = 1, hp = 36,
  -- Insanity : sans plafond, gardée d'un tour à l'autre (GDD, décision du 11/11/2026)
  resource = { id = "insanity", cap = nil, keep = true },
  deck = {
    "smite", "smite", "smite", "smite",
    "inner_fire", "inner_fire", "inner_fire", "inner_fire",
    "pw_shield", "sw_pain",
  },
  startRelic = "sacred_candle",
  paths = { { id = "discipline", name = "Discipline" }, { id = "shadow", name = "Shadow" }, { id = "holy", name = "Holy" } },
  survival = "heal",
  -- Conseils aux bots de simulation (Sim/) : valeur d'un point de ressource (unités de Bots.W, 10 = 1 PV),
  -- note des cartes pour les choix (≈ 5 + écart de victoires / 2, balayages sweep=cards), valeur des
  -- cartes de départ pour l'amélioration (upgrade) et pour le retrait (remove ; les autres : note + 2).
  bot = {
    resValue = 1.5,
    rating = {
      angelic_feather = 9, solace = 9, psychic_scream = 8, mind_blast = 7.5, mind_sear = 7.5,
      pain_suppression = 7.5, silence = 7.5, chastise = 7, greater_heal = 7, rapture = 7, flash_heal = 6.5,
      luminous_barrier = 6.5, schism = 6.5, shadow_mend = 6, spirit_of_redemption = 6, apotheosis = 5.5,
      devouring_plague = 5.5, mind_flay = 5.5, penance = 5.5, radiance = 5.5, vampiric_touch = 5.5,
      empyreal_blaze = 5, shadowform = 5, sw_death = 5, void_eruption = 5, evangelism = 4.5, halo = 4.5,
      holy_fire = 4, holy_nova = 4, renew = 3.5,
    },
    upgrade = { smite = 2.5, inner_fire = 2, pw_shield = 1.5, sw_pain = 1.5 },
    upgradeRun = { smite = 2.5, inner_fire = 2 }, -- ancien coureur (Sim/run.lua)
    remove = { inner_fire = 1, smite = 1.5 },
    -- Cartes épiques : chaque épique pilote le build (docs/zones/cartes-de-zone.md, « Deck piloté ») ; tant
    -- qu'elle est dans le deck, ces notes priment sur celles de la classe (byEpic, Sim/expedition.lua) : cartes
    -- centrales, mauvaises, à retirer d'abord (remove : plus bas = retirée d'abord), améliorations du feu
    -- de camp (upgrade, l'épique comprise).
    byEpic = {
      prayer_of_mending = {
        rating = { renew = 8, flash_heal = 8, greater_heal = 8, shadow_mend = 8, holy_nova = 7.5, halo = 7,
          vampiric_touch = 7.5, radiance = 6.5, solace = 9, evangelism = 6, luminous_barrier = 4.5,
          rapture = 4.5, pain_suppression = 6, holy_fire = 4, mind_blast = 5.5 },
        upgrade = { renew = 10, prayer_of_mending = 9.5, smite = 2, inner_fire = 0.5 },
        remove = { inner_fire = 0.5, smite = 1.5 },
      },
      misery = {
        rating = { vampiric_touch = 8.5, devouring_plague = 8.5, holy_fire = 7, mind_flay = 7.5, void_eruption = 7,
          shadowform = 8.5, silence = 7.5, mind_sear = 4, holy_nova = 3.5, psychic_scream = 7.5 },
        upgrade = { sw_pain = 9.5, misery = 9, smite = 1.5 },
        remove = { smite = 1, inner_fire = 1.5 },
      },
      echo_of_light = {
        rating = { renew = 6.5, holy_nova = 7, halo = 7, vampiric_touch = 6.5, luminous_barrier = 7,
          mind_blast = 5, flash_heal = 4.5, greater_heal = 4.5, shadow_mend = 4 },
        upgrade = { renew = 10, holy_nova = 9.5, echo_of_light = 9, inner_fire = 3, pw_shield = 2.5 },
        remove = { smite = 0.5, inner_fire = 3 },
      },
      shadow_covenant = {
        rating = { mind_blast = 8.5, mind_flay = 8, sw_death = 7.5, schism = 8, vampiric_touch = 7, mind_sear = 8,
          shadowform = 8, solace = 9.5, radiance = 7, penance = 7, evangelism = 6.5, shadow_mend = 8,
          holy_fire = 3, empyreal_blaze = 3.5, psychic_scream = 8.5 },
        upgrade = { mind_blast = 9.5, solace = 9.5, shadow_covenant = 9, sw_pain = 3 },
        remove = { smite = 0.5, inner_fire = 1.5 },
      },
      reflective_shield = {
        rating = { luminous_barrier = 8, radiance = 7, penance = 7, rapture = 7.5,
          renew = 3, flash_heal = 3.5, greater_heal = 4, holy_nova = 3.5, evangelism = 6 },
        upgrade = { inner_fire = 8, pw_shield = 7, reflective_shield = 9, smite = 1 },
        remove = { smite = 0.5, inner_fire = 4 },
      },
      voidform = {
        rating = { mind_blast = 9, mind_flay = 8.5, vampiric_touch = 7, shadowform = 9, schism = 7, sw_death = 8.5,
          psychic_scream = 8, mind_sear = 7, devouring_plague = 0, void_eruption = 0, holy_fire = 3.5,
          empyreal_blaze = 3.5, halo = 3.5 },
        upgrade = { mind_blast = 9.5, voidform = 9, sw_pain = 3, smite = 1 },
        remove = { devouring_plague = 0.2, void_eruption = 0.2, smite = 1, inner_fire = 1.5 },
      },
      inner_focus = {
        rating = { holy_fire = 8.5, empyreal_blaze = 8.5, halo = 8.5, penance = 7.5, luminous_barrier = 7.5,
          greater_heal = 7, apotheosis = 8, mind_blast = 7 },
        upgrade = { holy_fire = 9, empyreal_blaze = 9, inner_focus = 9.5, halo = 8.5 },
        remove = { smite = 1, inner_fire = 1.5 },
      },
    },
  },
}

-- Note d'une épique pour le bot (Sim/expedition.lua, prise et remplacement) : 7, plus un peu par carte
-- centrale de son build déjà dans le deck (note ≥ 7,5) : l'épique du deck construit vaut plus, un
-- remplacement n'arrive que si le deck a déjà pris la forme d'une autre.
ns.Classes.priest.bot.epic = function(exp, id)
  local eb = ns.Classes.priest.bot.byEpic[id]
  if not eb then return nil end
  local n = 0
  for _, cd in ipairs(exp.deck) do
    local r = eb.rating[cd.id]
    if r and r >= 7.5 then n = n + 1 end
  end
  return 7 + math.min(1.5, 0.25 * n)
end
