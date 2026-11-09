-- Cartes du Prêtre. Chiffres = points de départ, à corriger par la simulation.
-- Champs : name, cost, type (attack|skill|power), school (holy|shadow), rarity
-- (basic|common|uncommon|rare), path (discipline|shadow|holy|start), target ("enemy" ou nil),
-- effects, text, et up = champs remplacés par l'amélioration (dont text).
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
  name = "Mot de pouvoir : Radiance", cost = 1, type = "skill", school = "holy", rarity = "common", path = "discipline",
  effects = { { "apply", "atonement", 2, self = true }, { "absorb", 4 } },
  text = "Expiation 2 tours. Gagne 4 Absorption.",
  up = { effects = { { "apply", "atonement", 3, self = true }, { "absorb", 6 } },
    text = "Expiation 3 tours. Gagne 6 Absorption." },
})

local function penanceHit(c, ctx, t)
  if (c.player.st.atonement or 0) > 0 then Combat.gainBlock(c, c.player, 2) end
end

card("penance", {
  name = "Pénitence", cost = 2, type = "attack", school = "holy", rarity = "uncommon", path = "discipline",
  target = "enemy", effects = { { "damage", 4, times = 3, onHit = penanceHit } },
  text = "Inflige 4 trois fois. Sous Expiation, chaque coup donne aussi 2 Absorption.",
  up = { effects = { { "damage", 5, times = 3, onHit = penanceHit } },
    text = "Inflige 5 trois fois. Sous Expiation, chaque coup donne aussi 2 Absorption." },
})

card("pain_suppression", {
  name = "Suppression de la douleur", cost = 2, type = "skill", school = "holy", rarity = "rare", path = "discipline",
  cooldown = 3, effects = { { "apply", "halved", 1, self = true } },
  text = "Dégâts subis divisés par deux jusqu'à ton prochain tour. Recharge 3.",
  up = { cooldown = 2, text = "Dégâts subis divisés par deux jusqu'à ton prochain tour. Recharge 2." },
})

-- Ombre -----------------------------------------------------------------------

local function flayBonus(c, ctx)
  local t = ctx.target
  if t and (t.st.pain or 0) > 0 then
    c.player.demence = c.player.demence + 2
    Combat.log(c, { t = "demence", n = 2, total = c.player.demence })
  end
end

card("mind_flay", {
  name = "Fouet mental", cost = 1, type = "attack", school = "shadow", rarity = "common", path = "shadow",
  target = "enemy", effects = { { "fn", flayBonus }, { "damage", 4 } },
  text = "Inflige 4. Si la cible a Douleur : +2 Démence.",
  up = { effects = { { "fn", flayBonus }, { "damage", 6 } }, text = "Inflige 6. Si la cible a Douleur : +2 Démence." },
})

card("mind_blast", {
  name = "Attaque mentale", cost = 1, type = "attack", school = "shadow", rarity = "common", path = "shadow",
  target = "enemy", cooldown = 1, effects = { { "damage", 9 }, { "demence", 2 } },
  text = "Inflige 9. +2 Démence. Recharge 1.",
  up = { effects = { { "damage", 12 }, { "demence", 2 } }, text = "Inflige 12. +2 Démence. Recharge 1." },
})

local function plague(c, ctx)
  local n = c.player.demence
  c.player.demence = 0
  Combat.log(c, { t = "demence", n = -n, total = 0 })
  if n > 0 and ctx.target and not ctx.target.dead then
    Combat.applyStatus(c, ctx.target, "pain", 2 * n)
  end
end

card("devouring_plague", {
  name = "Peste dévorante", cost = 1, type = "skill", school = "shadow", rarity = "uncommon", path = "shadow",
  target = "enemy", effects = { { "fn", plague } },
  canPlay = function(c) return c.player.demence > 0 end,
  text = "Dépense toute ta Démence : Douleur égale au double.",
  up = { cost = 0, text = "Dépense toute ta Démence : Douleur égale au double." },
})

local function shadowformHooks(bonus)
  return {
    damage = function(c, power, v, dst, cardDef)
      if cardDef and cardDef.school == "shadow" then return v + bonus end
      return v
    end,
    allow = function(c, power, cardDef)
      return cardDef.school ~= "holy"
    end,
  }
end

card("shadowform", {
  name = "Forme d'ombre", cost = 2, type = "power", school = "shadow", rarity = "rare", path = "shadow",
  power = true, effects = {}, hooks = shadowformHooks(2),
  text = "Pouvoir. Tes cartes d'ombre infligent 2 de plus ; tu ne peux plus jouer de cartes sacrées.",
  up = { cost = 1, text = "Pouvoir. Tes cartes d'ombre infligent 2 de plus ; tu ne peux plus jouer de cartes sacrées." },
})

card("silence", {
  name = "Silence", cost = 0, type = "skill", school = "shadow", rarity = "uncommon", path = "shadow",
  target = "enemy", cooldown = 2, effects = { { "interrupt" } },
  text = "Interrompt le sort que la cible incante. Recharge 2.",
  up = { cooldown = 1, text = "Interrompt le sort que la cible incante. Recharge 1." },
})

-- Sacré -----------------------------------------------------------------------

card("holy_fire", {
  name = "Flammes sacrées", cost = 2, type = "attack", school = "holy", rarity = "common", path = "holy",
  target = "enemy", cast = true, effects = { { "damage", 16 }, { "apply", "pain", 3 } },
  text = "Incantation. Inflige 16 et Douleur 3.",
  up = { effects = { { "damage", 21 }, { "apply", "pain", 4 } }, text = "Incantation. Inflige 21 et Douleur 4." },
})

card("holy_nova", {
  name = "Nova sacrée", cost = 1, type = "attack", school = "holy", rarity = "common", path = "holy",
  effects = { { "damage", 3, all = true }, { "apply", "regen", 3, self = true } },
  text = "Inflige 3 à tous les ennemis. Récupération 3.",
  up = { effects = { { "damage", 5, all = true }, { "apply", "regen", 4, self = true } },
    text = "Inflige 5 à tous les ennemis. Récupération 4." },
})

card("chastise", {
  name = "Mot sacré : Châtier", cost = 1, type = "attack", school = "holy", rarity = "uncommon", path = "holy",
  target = "enemy", cooldown = 3, effects = { { "damage", 5 }, { "apply", "stunned", 1 } },
  text = "Inflige 5. Étourdi 1. Recharge 3.",
  up = { cooldown = 2, effects = { { "damage", 8 }, { "apply", "stunned", 1 } }, text = "Inflige 8. Étourdi 1. Recharge 2." },
})

card("greater_heal", {
  name = "Soins supérieurs", cost = 2, type = "skill", school = "holy", rarity = "uncommon", path = "holy",
  cast = true, exhaust = true, effects = { { "heal", 12 } },
  text = "Incantation. Soigne 12. Consumée.",
  up = { effects = { { "heal", 16 } }, text = "Incantation. Soigne 16. Consumée." },
})

card("spirit_of_redemption", {
  name = "Esprit de rédemption", cost = 3, type = "power", school = "holy", rarity = "rare", path = "holy",
  power = true, effects = {},
  hooks = {
    preventDeath = function(c, power)
      local f = c.player.flags
      if f.redeemed then return false end
      f.redeemed = true
      f.freeTurn = true
      c.player.hp = 1
      return true
    end,
  },
  text = "Pouvoir. Une fois par combat, à 0 PV, tu restes à 1 PV et ton tour suivant est gratuit.",
  up = { cost = 2, text = "Pouvoir. Une fois par combat, à 0 PV, tu restes à 1 PV et ton tour suivant est gratuit." },
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
