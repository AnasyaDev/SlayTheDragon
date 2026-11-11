-- Cartes du Prêtre. Chiffres = points de départ, à corriger par la simulation.
-- Champs : name, cost, type (attack|skill|power), school (holy|shadow), rarity
-- (basic|common|uncommon|rare), path (discipline|shadow|holy|start), target ("enemy" ou nil),
-- effects, text, et up = champs remplacés par l'amélioration (dont text).
-- rep = palier de réputation de classe qui débloque la carte (0 Neutre, 1 Amical, 2 Honoré) ;
-- absent sur les cartes de départ.
-- Mots-clés : cast (incantation), cooldown = N, exhaust (Consumée), retain (Conservée),
-- power (Pouvoir, avec hooks).
-- Écriture de `text` (docs/interface.md, « Langage des cartes ») : une clause par ligne, séparées par
-- « \n » ; « Nom d'état : effet » = si l'état est présent (sur soi pour un bienfait, sur la cible pour
-- un affaiblissement) ; conditions nommées : Exécution, Déferlement, Dernier souffle, Ombre ; chaque
-- état posé par les effets a sa ligne, en dernier, sans point : « Donne » (sur soi) ou « Applique »
-- (sur un ennemi, « à tous » pour tous), nom, nombre, et « ⌛ » si le nombre est une durée en tours
-- (état `duration` ou `turns`, Core/Statuses.lua). Les mots de la plaque du bas (« Pouvoir. »,
-- « Incantation. » en tête, « Recharge N. », « Consumée. », « Conservée. » en fin) restent dans le
-- texte et sont retirés à l'affichage.
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
  name = "Châtiment", cost = 1, type = "attack", school = "holy", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 6 } },
  text = "Inflige 6.",
  up = { effects = { { "damage", 9 } }, text = "Inflige 9." },
})

card("inner_fire", {
  name = "Feu intérieur", cost = 1, type = "skill", school = "holy", rarity = "basic", path = "start",
  effects = { { "absorb", 5 } },
  text = "Gagne 5 Absorption.",
  up = { effects = { { "absorb", 8 } }, text = "Gagne 8 Absorption." },
})

card("pw_shield", {
  name = "MdP : Bouclier", cost = 1, type = "skill", school = "holy", rarity = "basic", path = "start",
  cooldown = 2, effects = { { "absorb", 8 } },
  text = "Gagne 8 Absorption.\nRecharge 2.",
  up = { effects = { { "absorb", 11 } }, text = "Gagne 11 Absorption.\nRecharge 2." },
})

card("sw_pain", {
  name = "MdlO : Douleur", cost = 1, type = "skill", school = "shadow", rarity = "basic", path = "start",
  target = "enemy", effects = { { "apply", "pain", 5 }, { "demence", 1 } },
  text = "+1 Démence.\nApplique Douleur 5",
  up = { effects = { { "apply", "pain", 7 }, { "demence", 1 } }, text = "+1 Démence.\nApplique Douleur 7" },
})

-- Discipline ----------------------------------------------------------------

card("radiance", {
  rep = 0, name = "MdP : Radiance", cost = 1, type = "skill", school = "holy", rarity = "common", path = "discipline",
  effects = { { "apply", "atonement", 1, self = true }, { "absorb", 4 } },
  text = "Gagne 4 Absorption.\nDonne Expiation 1 ⌛",
  up = { effects = { { "apply", "atonement", 2, self = true }, { "absorb", 6 } },
    text = "Gagne 6 Absorption.\nDonne Expiation 2 ⌛" },
})

local function penanceHit(c, ctx, t)
  if (c.player.st.atonement or 0) > 0 then Combat.gainBlock(c, c.player, 2) end
end

card("penance", {
  rep = 0, name = "Pénitence", cost = 2, type = "attack", school = "holy", rarity = "uncommon", path = "discipline",
  target = "enemy", effects = { { "damage", 6, times = 3, onHit = penanceHit } },
  text = "Inflige 6 trois fois.\nExpiation : +2 Absorption par coup.",
  up = { effects = { { "damage", 8, times = 3, onHit = penanceHit } },
    text = "Inflige 8 trois fois.\nExpiation : +2 Absorption par coup." },
})

card("pain_suppression", {
  rep = 0, name = "Suppression de la douleur", cost = 1, type = "skill", school = "holy", rarity = "rare", path = "discipline",
  cooldown = 4, effects = { { "apply", "halved", 1, self = true } },
  text = "Dégâts subis divisés par deux jusqu'au prochain tour.\nRecharge 4.",
  up = { cooldown = 3, text = "Dégâts subis divisés par deux jusqu'au prochain tour.\nRecharge 3." },
})

local function solaceMana(c, ctx)
  if (c.player.st.atonement or 0) > 0 then
    c.player.mana = c.player.mana + 1
    Combat.log(c, { t = "mana", n = 1, total = c.player.mana })
  end
end

card("solace", {
  rep = 0, name = "MdP : Réconfort", cost = 1, type = "attack", school = "holy", rarity = "common", path = "discipline",
  target = "enemy", effects = { { "fn", solaceMana }, { "damage", 5 }, { "apply", "atonement", 1, self = true } },
  text = "Inflige 5.\nExpiation : +1 mana.\nDonne Expiation 1 ⌛",
  up = { effects = { { "fn", solaceMana }, { "damage", 8 }, { "apply", "atonement", 1, self = true } },
    text = "Inflige 8.\nExpiation : +1 mana.\nDonne Expiation 1 ⌛" },
})

card("angelic_feather", {
  rep = 0, name = "Plume angélique", cost = 0, type = "skill", school = "holy", rarity = "common", path = "discipline",
  cooldown = 2, effects = { { "absorb", 2 }, { "draw", 1 } },
  text = "Gagne 2 Absorption.\nPioche 1.\nRecharge 2.",
  up = { effects = { { "absorb", 4 }, { "draw", 1 } }, text = "Gagne 4 Absorption.\nPioche 1.\nRecharge 2." },
})

card("luminous_barrier", {
  rep = 0, name = "Barrière lumineuse", cost = 2, type = "skill", school = "holy", rarity = "common", path = "discipline",
  cooldown = 2, effects = { { "absorb", 12 }, { "apply", "atonement", 1, self = true } },
  text = "Gagne 12 Absorption.\nDonne Expiation 1 ⌛\nRecharge 2.",
  up = { effects = { { "absorb", 16 }, { "apply", "atonement", 1, self = true } },
    text = "Gagne 16 Absorption.\nDonne Expiation 1 ⌛\nRecharge 2." },
})

card("schism", {
  rep = 0, name = "Schisme", cost = 1, type = "attack", school = "shadow", rarity = "uncommon", path = "discipline",
  target = "enemy",
  effects = { { "damage", 3 }, { "apply", "armor_broken", 2 }, { "apply", "atonement", 1, self = true } },
  text = "Inflige 3.\nApplique Armure fracassée 2 ⌛\nDonne Expiation 1 ⌛",
  up = { effects = { { "damage", 6 }, { "apply", "armor_broken", 3 }, { "apply", "atonement", 1, self = true } },
    text = "Inflige 6.\nApplique Armure fracassée 3 ⌛\nDonne Expiation 1 ⌛" },
})

card("shadow_mend", {
  rep = 1, name = "Guérison de l'ombre", cost = 1, type = "skill", school = "shadow", rarity = "common", path = "discipline",
  exhaust = true, effects = { { "heal", 10 }, { "apply", "pain", 2, self = true }, { "demence", 1 } },
  text = "Soigne 10.\n+1 Démence.\nDonne Douleur 2\nConsumée.",
  up = { effects = { { "heal", 14 }, { "apply", "pain", 2, self = true }, { "demence", 1 } },
    text = "Soigne 14.\n+1 Démence.\nDonne Douleur 2\nConsumée." },
})

card("evangelism", {
  rep = 1, name = "Évangélisme", cost = 1, type = "skill", school = "holy", rarity = "uncommon", path = "discipline",
  exhaust = true, effects = { { "apply", "atonement", 2, self = true }, { "draw", 2 } },
  text = "Pioche 2.\nDonne Expiation 2 ⌛\nConsumée.",
  up = { cost = 0, text = "Pioche 2.\nDonne Expiation 2 ⌛\nConsumée." },
})

local function raptureHooks(bonus)
  return {
    block = function(c, power, v) return v + bonus end,
  }
end

card("rapture", {
  rep = 2, name = "Extase", cost = 1, type = "power", school = "holy", rarity = "rare", path = "discipline",
  power = true, effects = {}, hooks = raptureHooks(1),
  text = "Pouvoir.\nChaque gain d'Absorption : +1.",
  up = { hooks = raptureHooks(2), text = "Pouvoir.\nChaque gain d'Absorption : +2." },
})

-- Ombre -----------------------------------------------------------------------

local function flayBonus(c, ctx)
  local t = ctx.target
  if t and (t.st.pain or 0) > 0 then
    c.player.demence = c.player.demence + 2
    Combat.log(c, { t = "demence", n = 2, total = c.player.demence })
    Combat.drawCards(c, 1)
  end
end

card("mind_flay", {
  rep = 0, name = "Fouet mental", cost = 1, type = "attack", school = "shadow", rarity = "common", path = "shadow",
  target = "enemy", effects = { { "fn", flayBonus }, { "damage", 8 } },
  text = "Inflige 8.\nDouleur : +2 Démence, pioche 1.",
  up = { effects = { { "fn", flayBonus }, { "damage", 11 } }, text = "Inflige 11.\nDouleur : +2 Démence, pioche 1." },
})

card("mind_blast", {
  rep = 0, name = "Attaque mentale", cost = 1, type = "attack", school = "shadow", rarity = "common", path = "shadow",
  target = "enemy", cooldown = 1, effects = { { "damage", 10 }, { "demence", 2 } },
  text = "Inflige 10.\n+2 Démence.\nRecharge 1.",
  up = { effects = { { "damage", 13 }, { "demence", 2 } }, text = "Inflige 13.\n+2 Démence.\nRecharge 1." },
})

local function plague(c, ctx)
  local n = c.player.demence
  c.player.demence = 0
  Combat.log(c, { t = "demence", n = -n, total = 0 })
  if n > 0 and ctx.target and not ctx.target.dead then
    Combat.applyStatus(c, ctx.target, "pain", (ctx.def.plagueMult or 2) * n)
  end
end

card("devouring_plague", {
  rep = 0, name = "Peste dévorante", cost = 0, type = "skill", school = "shadow", rarity = "uncommon", path = "shadow",
  target = "enemy", plagueMult = 2, effects = { { "fn", plague } },
  canPlay = function(c) return c.player.demence > 0 end,
  text = "Déferlement : applique Douleur 2 par Démence.",
  up = { plagueMult = 3, text = "Déferlement : applique Douleur 3 par Démence." },
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
  rep = 0, name = "Forme d'ombre", cost = 1, type = "power", school = "shadow", rarity = "rare", path = "shadow",
  power = true, effects = { { "demence", 2 } }, hooks = shadowformHooks(3),
  text = "Pouvoir.\n+2 Démence.\nOmbre : dégâts et Douleur +3.",
  up = { hooks = shadowformHooks(4),
    text = "Pouvoir.\n+2 Démence.\nOmbre : dégâts et Douleur +4." },
})

card("silence", {
  rep = 0, name = "Silence", cost = 0, type = "skill", school = "shadow", rarity = "uncommon", path = "shadow",
  target = "enemy", cooldown = 2, effects = { { "interrupt" }, { "draw", 1 } },
  text = "Interrompt l'incantation de la cible.\nPioche 1.\nRecharge 2.",
  up = { cooldown = 1, text = "Interrompt l'incantation de la cible.\nPioche 1.\nRecharge 1." },
})

card("vampiric_touch", {
  rep = 0, name = "Toucher vampirique", cost = 1, type = "skill", school = "shadow", rarity = "common", path = "shadow",
  target = "enemy", effects = { { "apply", "pain", 3 }, { "apply", "regen", 1, self = true }, { "demence", 1 } },
  text = "+1 Démence.\nApplique Douleur 3\nDonne Récupération 1",
  up = { effects = { { "apply", "pain", 5 }, { "apply", "regen", 2, self = true }, { "demence", 1 } },
    text = "+1 Démence.\nApplique Douleur 5\nDonne Récupération 2" },
})

card("mind_sear", {
  rep = 1, name = "Incandescence mentale", cost = 1, type = "skill", school = "shadow", rarity = "common", path = "shadow",
  effects = { { "apply", "pain", 4, all = true }, { "demence", 1 } },
  text = "+1 Démence.\nApplique Douleur 4 à tous",
  up = { effects = { { "apply", "pain", 6, all = true }, { "demence", 1 } }, text = "+1 Démence.\nApplique Douleur 6 à tous" },
})

local function executeBonus(c, ctx, t)
  if t.hp * 2 <= t.maxHp then return ctx.def.executeBonus or 0 end
  return 0
end

card("sw_death", {
  rep = 1, name = "MdlO : Mort", cost = 1, type = "attack", school = "shadow", rarity = "uncommon", path = "shadow",
  target = "enemy", executeBonus = 6, effects = { { "damage", 6, bonus = executeBonus }, { "demence", 1 } },
  text = "Inflige 6.\nExécution : inflige 12.\n+1 Démence.",
  up = { executeBonus = 9, effects = { { "damage", 8, bonus = executeBonus }, { "demence", 1 } },
    text = "Inflige 8.\nExécution : inflige 17.\n+1 Démence." },
})

card("psychic_scream", {
  rep = 2, name = "Cri psychique", cost = 1, type = "skill", school = "shadow", rarity = "uncommon", path = "shadow",
  cooldown = 3, effects = { { "apply", "demoralized", 2, all = true }, { "demence", 1 } },
  text = "+1 Démence.\nApplique Démoralisé 2 ⌛ à tous\nRecharge 3.",
  up = { cost = 0, text = "+1 Démence.\nApplique Démoralisé 2 ⌛ à tous\nRecharge 3." },
})

local function spendDemence(c, ctx)
  local n = c.player.demence
  ctx.spent = n
  c.player.demence = 0
  Combat.log(c, { t = "demence", n = -n, total = 0 })
end

local function eruptionBonus(c, ctx, t)
  return (ctx.spent or 0) * (ctx.def.perDemence or 0)
end

card("void_eruption", {
  rep = 2, name = "Éruption du Vide", cost = 1, type = "attack", school = "shadow", rarity = "rare", path = "shadow",
  target = "enemy", perDemence = 4, effects = { { "fn", spendDemence }, { "damage", 4, bonus = eruptionBonus } },
  canPlay = function(c) return c.player.demence > 0 end,
  text = "Déferlement : inflige 4 + 4 par Démence.",
  up = { perDemence = 5, text = "Déferlement : inflige 4 + 5 par Démence." },
})

-- Sacré -----------------------------------------------------------------------
-- Les incantations frappent fort : elles paient le risque d'être interrompues.

card("holy_fire", {
  rep = 0, name = "Flammes sacrées", cost = 2, type = "attack", school = "holy", rarity = "common", path = "holy",
  target = "enemy", cast = true, effects = { { "damage", 24 }, { "apply", "pain", 3 } },
  text = "Incantation.\nInflige 24.\nApplique Douleur 3",
  up = { effects = { { "damage", 31 }, { "apply", "pain", 4 } }, text = "Incantation.\nInflige 31.\nApplique Douleur 4" },
})

card("holy_nova", {
  rep = 0, name = "Nova sacrée", cost = 1, type = "attack", school = "holy", rarity = "common", path = "holy",
  effects = { { "damage", 4, all = true }, { "apply", "regen", 2, self = true } },
  text = "Inflige 4 à tous.\nDonne Récupération 2",
  up = { effects = { { "damage", 6, all = true }, { "apply", "regen", 3, self = true } },
    text = "Inflige 6 à tous.\nDonne Récupération 3" },
})

card("chastise", {
  rep = 0, name = "Mot sacré : Châtier", cost = 1, type = "attack", school = "holy", rarity = "uncommon", path = "holy",
  target = "enemy", cooldown = 3, effects = { { "damage", 7 }, { "apply", "stunned", 1 } },
  text = "Inflige 7.\nApplique Étourdi 1 ⌛\nRecharge 3.",
  up = { cooldown = 2, effects = { { "damage", 10 }, { "apply", "stunned", 1 } }, text = "Inflige 10.\nApplique Étourdi 1 ⌛\nRecharge 2." },
})

card("greater_heal", {
  rep = 0, name = "Soins supérieurs", cost = 1, type = "skill", school = "holy", rarity = "uncommon", path = "holy",
  cast = true, exhaust = true, effects = { { "heal", 12 } },
  text = "Incantation.\nSoigne 12.\nConsumée.",
  up = { effects = { { "heal", 16 } }, text = "Incantation.\nSoigne 16.\nConsumée." },
})

card("spirit_of_redemption", {
  rep = 0, name = "Esprit de rédemption", cost = 1, type = "power", school = "holy", rarity = "rare", path = "holy",
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
  text = "Pouvoir.\nDernier souffle : reste à 1 PV, Récupération 6, tour gratuit.",
  up = { cost = 0,
    text = "Pouvoir.\nDernier souffle : reste à 1 PV, Récupération 6, tour gratuit." },
})

card("renew", {
  rep = 0, name = "Rénovation", cost = 1, type = "skill", school = "holy", rarity = "common", path = "holy",
  exhaust = true, effects = { { "apply", "regen", 3, self = true } },
  text = "Donne Récupération 3\nConsumée.",
  up = { effects = { { "apply", "regen", 5, self = true } }, text = "Donne Récupération 5\nConsumée." },
})

card("halo", {
  rep = 0, name = "Halo", cost = 2, type = "attack", school = "holy", rarity = "uncommon", path = "holy",
  cast = true, effects = { { "damage", 15, all = true }, { "apply", "regen", 3, self = true } },
  text = "Incantation.\nInflige 15 à tous.\nDonne Récupération 3",
  up = { effects = { { "damage", 19, all = true }, { "apply", "regen", 4, self = true } },
    text = "Incantation.\nInflige 19 à tous.\nDonne Récupération 4" },
})

card("flash_heal", {
  rep = 1, name = "Soins rapides", cost = 1, type = "skill", school = "holy", rarity = "common", path = "holy",
  exhaust = true, effects = { { "heal", 7 }, { "draw", 1 } },
  text = "Soigne 7.\nPioche 1.\nConsumée.",
  up = { effects = { { "heal", 10 }, { "draw", 1 } }, text = "Soigne 10.\nPioche 1.\nConsumée." },
})

card("empyreal_blaze", {
  rep = 2, name = "Embrasement empyréen", cost = 2, type = "attack", school = "holy", rarity = "uncommon", path = "holy",
  target = "enemy", cast = true, effects = { { "damage", 28 }, { "apply", "armor_broken", 2 } },
  text = "Incantation.\nInflige 28.\nApplique Armure fracassée 2 ⌛",
  up = { effects = { { "damage", 36 }, { "apply", "armor_broken", 2 } }, text = "Incantation.\nInflige 36.\nApplique Armure fracassée 2 ⌛" },
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
  rep = 2, name = "Apothéose", cost = 2, type = "power", school = "holy", rarity = "rare", path = "holy",
  power = true, effects = {}, hooks = apotheosisHooks,
  text = "Pouvoir.\n+1 mana par tour.\nIncantations : coût −1.",
  up = { cost = 1, text = "Pouvoir.\n+1 mana par tour.\nIncantations : coût −1." },
})

-- Classe ------------------------------------------------------------------------

ns.Classes = ns.Classes or {}
ns.Classes.priest = {
  name = "Prêtre",
  hp = 65,
  deck = {
    "smite", "smite", "smite", "smite",
    "inner_fire", "inner_fire", "inner_fire", "inner_fire",
    "pw_shield", "sw_pain",
  },
}
