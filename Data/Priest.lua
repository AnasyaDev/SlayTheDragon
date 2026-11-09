-- Cartes du Prêtre. Chiffres = points de départ, à corriger par la simulation.
-- Champs : name, cost, type (attack|skill|power), school (holy|shadow), rarity
-- (basic|common|uncommon|rare), path (discipline|shadow|holy|start), target ("enemy" ou nil),
-- effects, text, et up = champs remplacés par l'amélioration (dont text).
-- rep = palier de réputation de classe qui débloque la carte (0 Neutre, 1 Amical, 2 Honoré) ;
-- absent sur les cartes de départ.
-- Mots-clés : cast (incantation), cooldown = N, exhaust (Consumée), retain (Conservée),
-- power (Pouvoir, avec hooks).
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
  name = "Mot de pouvoir : Bouclier", cost = 1, type = "skill", school = "holy", rarity = "basic", path = "start",
  cooldown = 2, effects = { { "absorb", 8 } },
  text = "Gagne 8 Absorption. Recharge 2.",
  up = { effects = { { "absorb", 11 } }, text = "Gagne 11 Absorption. Recharge 2." },
})

card("sw_pain", {
  name = "Mot de l'ombre : Douleur", cost = 1, type = "skill", school = "shadow", rarity = "basic", path = "start",
  target = "enemy", effects = { { "apply", "pain", 5 }, { "demence", 1 } },
  text = "Douleur 5. +1 Démence.",
  up = { effects = { { "apply", "pain", 7 }, { "demence", 1 } }, text = "Douleur 7. +1 Démence." },
})

-- Discipline ----------------------------------------------------------------

card("radiance", {
  rep = 0, name = "Mot de pouvoir : Radiance", cost = 1, type = "skill", school = "holy", rarity = "common", path = "discipline",
  effects = { { "apply", "atonement", 2, self = true }, { "absorb", 4 } },
  text = "Expiation 2 tours. Gagne 4 Absorption.",
  up = { effects = { { "apply", "atonement", 3, self = true }, { "absorb", 6 } },
    text = "Expiation 3 tours. Gagne 6 Absorption." },
})

local function penanceHit(c, ctx, t)
  if (c.player.st.atonement or 0) > 0 then Combat.gainBlock(c, c.player, 2) end
end

card("penance", {
  rep = 0, name = "Pénitence", cost = 2, type = "attack", school = "holy", rarity = "uncommon", path = "discipline",
  target = "enemy", effects = { { "damage", 6, times = 3, onHit = penanceHit } },
  text = "Inflige 6 trois fois. Sous Expiation, chaque coup donne aussi 2 Absorption.",
  up = { effects = { { "damage", 8, times = 3, onHit = penanceHit } },
    text = "Inflige 8 trois fois. Sous Expiation, chaque coup donne aussi 2 Absorption." },
})

card("pain_suppression", {
  rep = 0, name = "Suppression de la douleur", cost = 1, type = "skill", school = "holy", rarity = "rare", path = "discipline",
  cooldown = 4, effects = { { "apply", "halved", 1, self = true } },
  text = "Dégâts subis divisés par deux jusqu'à ton prochain tour. Recharge 4.",
  up = { cooldown = 3, text = "Dégâts subis divisés par deux jusqu'à ton prochain tour. Recharge 3." },
})

local function solaceMana(c, ctx)
  if (c.player.st.atonement or 0) > 0 then
    c.player.mana = c.player.mana + 1
    Combat.log(c, { t = "mana", n = 1, total = c.player.mana })
  end
end

card("solace", {
  rep = 0, name = "Mot de pouvoir : Réconfort", cost = 1, type = "attack", school = "holy", rarity = "common", path = "discipline",
  target = "enemy", effects = { { "fn", solaceMana }, { "damage", 5 }, { "apply", "atonement", 1, self = true } },
  text = "Inflige 5. Sous Expiation : +1 mana. Expiation 1 tour.",
  up = { effects = { { "fn", solaceMana }, { "damage", 8 }, { "apply", "atonement", 1, self = true } },
    text = "Inflige 8. Sous Expiation : +1 mana. Expiation 1 tour." },
})

card("angelic_feather", {
  rep = 0, name = "Plume angélique", cost = 0, type = "skill", school = "holy", rarity = "common", path = "discipline",
  cooldown = 2, effects = { { "absorb", 2 }, { "draw", 1 } },
  text = "Gagne 2 Absorption. Pioche 1. Recharge 2.",
  up = { effects = { { "absorb", 4 }, { "draw", 1 } }, text = "Gagne 4 Absorption. Pioche 1. Recharge 2." },
})

card("luminous_barrier", {
  rep = 0, name = "Barrière lumineuse", cost = 2, type = "skill", school = "holy", rarity = "common", path = "discipline",
  cooldown = 2, effects = { { "absorb", 12 }, { "apply", "atonement", 1, self = true } },
  text = "Gagne 12 Absorption. Expiation 1 tour. Recharge 2.",
  up = { effects = { { "absorb", 16 }, { "apply", "atonement", 1, self = true } },
    text = "Gagne 16 Absorption. Expiation 1 tour. Recharge 2." },
})

card("schism", {
  rep = 0, name = "Schisme", cost = 1, type = "attack", school = "shadow", rarity = "uncommon", path = "discipline",
  target = "enemy",
  effects = { { "damage", 3 }, { "apply", "armor_broken", 2 }, { "apply", "atonement", 1, self = true } },
  text = "Inflige 3. La cible a Armure fracassée 2 tours. Expiation 1 tour.",
  up = { effects = { { "damage", 6 }, { "apply", "armor_broken", 3 }, { "apply", "atonement", 2, self = true } },
    text = "Inflige 6. La cible a Armure fracassée 3 tours. Expiation 2 tours." },
})

card("shadow_mend", {
  rep = 1, name = "Guérison de l'ombre", cost = 1, type = "skill", school = "shadow", rarity = "common", path = "discipline",
  exhaust = true, effects = { { "heal", 10 }, { "apply", "pain", 2, self = true }, { "demence", 1 } },
  text = "Soigne 10. Douleur 2 sur toi. +1 Démence. Consumée.",
  up = { effects = { { "heal", 14 }, { "apply", "pain", 2, self = true }, { "demence", 1 } },
    text = "Soigne 14. Douleur 2 sur toi. +1 Démence. Consumée." },
})

card("evangelism", {
  rep = 1, name = "Évangélisme", cost = 1, type = "skill", school = "holy", rarity = "uncommon", path = "discipline",
  exhaust = true, effects = { { "apply", "atonement", 3, self = true }, { "draw", 2 } },
  text = "Expiation 3 tours. Pioche 2. Consumée.",
  up = { cost = 0, text = "Expiation 3 tours. Pioche 2. Consumée." },
})

local function raptureHooks(bonus)
  return {
    block = function(c, power, v) return v + bonus end,
  }
end

card("rapture", {
  rep = 2, name = "Extase", cost = 1, type = "power", school = "holy", rarity = "rare", path = "discipline",
  power = true, effects = {}, hooks = raptureHooks(1),
  text = "Pouvoir. Chaque gain d'Absorption te donne 1 de plus.",
  up = { hooks = raptureHooks(2), text = "Pouvoir. Chaque gain d'Absorption te donne 2 de plus." },
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
  text = "Inflige 8. Si la cible a Douleur : +2 Démence et pioche 1.",
  up = { effects = { { "fn", flayBonus }, { "damage", 11 } }, text = "Inflige 11. Si la cible a Douleur : +2 Démence et pioche 1." },
})

card("mind_blast", {
  rep = 0, name = "Attaque mentale", cost = 1, type = "attack", school = "shadow", rarity = "common", path = "shadow",
  target = "enemy", cooldown = 1, effects = { { "damage", 10 }, { "demence", 2 } },
  text = "Inflige 10. +2 Démence. Recharge 1.",
  up = { effects = { { "damage", 13 }, { "demence", 2 } }, text = "Inflige 13. +2 Démence. Recharge 1." },
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
  text = "Dépense toute ta Démence : Douleur égale au double.",
  up = { plagueMult = 3, text = "Dépense toute ta Démence : Douleur égale au triple." },
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
  text = "Pouvoir. +2 Démence. Tes cartes d'ombre infligent 3 de plus et posent 3 Douleur de plus.",
  up = { hooks = shadowformHooks(4),
    text = "Pouvoir. +2 Démence. Tes cartes d'ombre infligent 4 de plus et posent 4 Douleur de plus." },
})

card("silence", {
  rep = 0, name = "Silence", cost = 0, type = "skill", school = "shadow", rarity = "uncommon", path = "shadow",
  target = "enemy", cooldown = 2, effects = { { "interrupt" }, { "draw", 1 } },
  text = "Interrompt le sort que la cible incante. Pioche 1. Recharge 2.",
  up = { cooldown = 1, text = "Interrompt le sort que la cible incante. Pioche 1. Recharge 1." },
})

card("vampiric_touch", {
  rep = 0, name = "Toucher vampirique", cost = 1, type = "skill", school = "shadow", rarity = "common", path = "shadow",
  target = "enemy", effects = { { "apply", "pain", 3 }, { "apply", "regen", 1, self = true }, { "demence", 1 } },
  text = "Douleur 3. Récupération 1. +1 Démence.",
  up = { effects = { { "apply", "pain", 5 }, { "apply", "regen", 2, self = true }, { "demence", 1 } },
    text = "Douleur 5. Récupération 2. +1 Démence." },
})

card("mind_sear", {
  rep = 1, name = "Incandescence mentale", cost = 1, type = "skill", school = "shadow", rarity = "common", path = "shadow",
  effects = { { "apply", "pain", 4, all = true }, { "demence", 1 } },
  text = "Douleur 4 à tous les ennemis. +1 Démence.",
  up = { effects = { { "apply", "pain", 6, all = true }, { "demence", 1 } }, text = "Douleur 6 à tous les ennemis. +1 Démence." },
})

local function executeBonus(c, ctx, t)
  if t.hp * 2 <= t.maxHp then return ctx.def.executeBonus or 0 end
  return 0
end

card("sw_death", {
  rep = 1, name = "Mot de l'ombre : Mort", cost = 1, type = "attack", school = "shadow", rarity = "uncommon", path = "shadow",
  target = "enemy", executeBonus = 6, effects = { { "damage", 6, bonus = executeBonus }, { "demence", 1 } },
  text = "Inflige 6, ou 12 si la cible a la moitié de ses PV ou moins. +1 Démence.",
  up = { executeBonus = 9, effects = { { "damage", 8, bonus = executeBonus }, { "demence", 1 } },
    text = "Inflige 8, ou 17 si la cible a la moitié de ses PV ou moins. +1 Démence." },
})

card("psychic_scream", {
  rep = 2, name = "Cri psychique", cost = 1, type = "skill", school = "shadow", rarity = "uncommon", path = "shadow",
  cooldown = 3, effects = { { "apply", "demoralized", 2, all = true }, { "demence", 1 } },
  text = "Tous les ennemis sont Démoralisés 2 tours. +1 Démence. Recharge 3.",
  up = { cost = 0, text = "Tous les ennemis sont Démoralisés 2 tours. +1 Démence. Recharge 3." },
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
  text = "Dépense toute ta Démence : inflige 4, plus 4 par point dépensé.",
  up = { perDemence = 5, text = "Dépense toute ta Démence : inflige 4, plus 5 par point dépensé." },
})

-- Sacré -----------------------------------------------------------------------
-- Les incantations frappent fort : elles paient le risque d'être interrompues.

card("holy_fire", {
  rep = 0, name = "Flammes sacrées", cost = 2, type = "attack", school = "holy", rarity = "common", path = "holy",
  target = "enemy", cast = true, effects = { { "damage", 24 }, { "apply", "pain", 3 } },
  text = "Incantation. Inflige 24 et Douleur 3.",
  up = { effects = { { "damage", 31 }, { "apply", "pain", 4 } }, text = "Incantation. Inflige 31 et Douleur 4." },
})

card("holy_nova", {
  rep = 0, name = "Nova sacrée", cost = 1, type = "attack", school = "holy", rarity = "common", path = "holy",
  effects = { { "damage", 4, all = true }, { "apply", "regen", 2, self = true } },
  text = "Inflige 4 à tous les ennemis. Récupération 2.",
  up = { effects = { { "damage", 6, all = true }, { "apply", "regen", 3, self = true } },
    text = "Inflige 6 à tous les ennemis. Récupération 3." },
})

card("chastise", {
  rep = 0, name = "Mot sacré : Châtier", cost = 1, type = "attack", school = "holy", rarity = "uncommon", path = "holy",
  target = "enemy", cooldown = 3, effects = { { "damage", 7 }, { "apply", "stunned", 1 } },
  text = "Inflige 7. Étourdi 1. Recharge 3.",
  up = { cooldown = 2, effects = { { "damage", 10 }, { "apply", "stunned", 1 } }, text = "Inflige 10. Étourdi 1. Recharge 2." },
})

card("greater_heal", {
  rep = 0, name = "Soins supérieurs", cost = 1, type = "skill", school = "holy", rarity = "uncommon", path = "holy",
  cast = true, exhaust = true, effects = { { "heal", 12 } },
  text = "Incantation. Soigne 12. Consumée.",
  up = { effects = { { "heal", 16 } }, text = "Incantation. Soigne 16. Consumée." },
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
  text = "Pouvoir. Une fois par combat, à 0 PV, tu restes à 1 PV, gagnes Récupération 6 et ton tour suivant est gratuit.",
  up = { cost = 0,
    text = "Pouvoir. Une fois par combat, à 0 PV, tu restes à 1 PV, gagnes Récupération 6 et ton tour suivant est gratuit." },
})

card("renew", {
  rep = 0, name = "Rénovation", cost = 1, type = "skill", school = "holy", rarity = "common", path = "holy",
  exhaust = true, effects = { { "apply", "regen", 3, self = true } },
  text = "Récupération 3. Consumée.",
  up = { effects = { { "apply", "regen", 5, self = true } }, text = "Récupération 5. Consumée." },
})

card("halo", {
  rep = 0, name = "Halo", cost = 2, type = "attack", school = "holy", rarity = "uncommon", path = "holy",
  cast = true, effects = { { "damage", 15, all = true }, { "apply", "regen", 3, self = true } },
  text = "Incantation. Inflige 15 à tous les ennemis. Récupération 3.",
  up = { effects = { { "damage", 19, all = true }, { "apply", "regen", 4, self = true } },
    text = "Incantation. Inflige 19 à tous les ennemis. Récupération 4." },
})

card("flash_heal", {
  rep = 1, name = "Soins rapides", cost = 1, type = "skill", school = "holy", rarity = "common", path = "holy",
  exhaust = true, effects = { { "heal", 7 }, { "draw", 1 } },
  text = "Soigne 7. Pioche 1. Consumée.",
  up = { effects = { { "heal", 10 }, { "draw", 1 } }, text = "Soigne 10. Pioche 1. Consumée." },
})

card("empyreal_blaze", {
  rep = 2, name = "Embrasement empyréen", cost = 2, type = "attack", school = "holy", rarity = "uncommon", path = "holy",
  target = "enemy", cast = true, effects = { { "damage", 28 }, { "apply", "armor_broken", 2 } },
  text = "Incantation. Inflige 28. Armure fracassée 2 tours.",
  up = { effects = { { "damage", 36 }, { "apply", "armor_broken", 2 } }, text = "Incantation. Inflige 36. Armure fracassée 2 tours." },
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
  text = "Pouvoir. +1 mana à chacun de tes tours. Tes incantations coûtent 1 mana de moins.",
  up = { cost = 1, text = "Pouvoir. +1 mana à chacun de tes tours. Tes incantations coûtent 1 mana de moins." },
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
