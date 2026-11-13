-- Règles propres du Voleur (fiche : docs/classes/rogue.md ; contrat : docs/classes.md).
--   Parry : état à charges (plafond 3, gardé d'un tour à l'autre) ; chaque charge annule un coup ennemi
--     jusqu'à 8 dégâts, coup par coup, AVANT l'Absorb (crochet beforeHit) ; un coup de 0 ne consomme
--     rien ; jamais contre le DoT (ce n'est pas un coup).
--   Stealth : état à drapeau, posé au début de chaque combat ; la première carte Attack jouée le
--     consomme (crochet onCardCommitted, au jeu) et toute sa résolution se fait « cachée » (condition
--     stealth) ; une carte Skill ou Power lit l'état sans le consommer.
--   Effets propres : dotPer (« Surge: apply DoT K per Combo. »), tickDotPer (Exsanguinate),
--     randomHits (Killing Spree, flux c.rng.cards).
-- État de classe c.cls : hidden (miroir de Stealth, pour savoir si un gain est réel), stealthGained
-- (le dernier état Stealth posé l'a fait apparaître : Flash Powder), openers (uid des cartes Attack qui
-- ont consommé Stealth, clés en chaîne, jusqu'à la fin de leur résolution).
local _, ns = ...

local Combat, Rng = ns.Combat, ns.Rng
local L = ns.Language

local PARRY_MAX, PARRY_STOP = 3, 8

ns.Statuses.parry = { name = "Parry", max = PARRY_MAX,
  text = "Each charge stops one hit, up to 8 damage. Max 3." }
ns.Statuses.stealth = { name = "Stealth", flag = true,
  text = "The next Attack played consumes it for its Stealth: bonus." }

-- « Each Attack hit: apply DoT 1. » (Deadly Poison)
L.trigger("Each Attack hit")

-- Condition « Stealth: » : pour une carte Attack, elle a consommé Stealth en étant jouée ; pour une
-- autre carte, Stealth est posé (lu sans être consommé).
Combat.CONDITIONS.stealth = function(c, ctx)
  local d = ctx.def
  if d and d.type == "attack" then
    local o = c.cls.openers
    return ctx.card ~= nil and o ~= nil and o[tostring(ctx.card.uid)] == true
  end
  return (c.player.st.stealth or 0) > 0
end

-- { "dotPer", k, icon = clé } : DoT k par point dépensé par le Surge de la carte (ctx.surge) sur la cible.
ns.Effects.dotPer = function(c, ctx, e)
  local t = ctx.target
  local n = e[2] * (ctx.surge or 0)
  if not t or t.dead or n <= 0 then return end
  n = Combat.modify(c, "apply", n, "pain", t, ctx.def)
  if n > 0 then Combat.applyStatus(c, t, "pain", n, e.icon) end
end

-- { "tickDotPer" } : le DoT de la cible se déclenche une fois par point dépensé ; s'arrête si la cible
-- meurt ou si son DoT tombe à 0 (les points restent dépensés).
ns.Effects.tickDotPer = function(c, ctx)
  local t = ctx.target
  for _ = 1, (ctx.surge or 0) do
    if not t or t.dead or c.result or (t.st.pain or 0) <= 0 then return end
    Combat.tickDot(c, t)
  end
end

-- { "randomHits", n, times = k } : k coups de n, chacun sur un ennemi vivant tiré au hasard (flux des
-- cartes) ; ce sont des coups d'une carte Attack (onAttackHit : Deadly Poison).
ns.Effects.randomHits = function(c, ctx, e)
  for _ = 1, (e.times or 1) do
    local list = Combat.aliveEnemies(c)
    if #list == 0 or c.result then return end
    local t = list[Rng.int(c.rng.cards, 1, #list)]
    Combat.dealDamage(c, c.player, t, Combat.calcDamage(c, c.player, t, e[2], ctx.def), false, ctx)
    ctx.dealt = true
    ctx.hits = ctx.hits + 1
    if ctx.def and ctx.def.type == "attack" and not c.result then Combat.fire(c, "onAttackHit", t, ctx) end
  end
end

local function stat(c, key, n)
  local s = c.stats
  if s then s[key] = (s[key] or 0) + (n or 1) end
end

ns.ClassRules.rogue = {
  init = function(c, cls)
    cls.openers = {}
    cls.stealthGained = false
    -- Stealth du début de combat : visible dès la première main, ne compte pas comme un gain (Flash Powder)
    c.player.st.stealth = 1
    cls.hidden = true
  end,
  hooks = {
    -- Parry : une charge par coup ennemi de 1 ou plus, jusqu'à 8 dégâts annulés, avant l'Absorb.
    beforeHit = function(c, cls, dmg, enemy)
      local p = c.player
      local n = p.st.parry or 0
      if n <= 0 or dmg <= 0 then return dmg end
      local stop = dmg < PARRY_STOP and dmg or PARRY_STOP
      n = n - 1
      p.st.parry = n > 0 and n or nil
      Combat.log(c, { t = "parry", src = Combat.uref(enemy), prevented = stop, left = n })
      stat(c, "parried")
      stat(c, "parryPrevented", stop)
      -- une charge consommée (ripostes des épiques) : attaquant, dégâts annulés, charges restantes
      Combat.fire(c, "onParry", enemy, stop, n)
      return dmg - stop
    end,
    -- Stealth consommé au jeu par la première carte Attack (même à 0 mana, même sans ligne Stealth:).
    -- Crochet « stealthBreak » (v = vrai, inst, d) : faux = l'Attack profite de Stealth (lignes « Stealth: »)
    -- sans le retirer (Subterfuge ; la carte qui le pose dit quand il tombe).
    onCardCommitted = function(c, cls, inst, d)
      if d.type ~= "attack" or (c.player.st.stealth or 0) <= 0 then return end
      if not Combat.modify(c, "stealthBreak", true, inst, d) then
        cls.openers[tostring(inst.uid)] = true
        return
      end
      c.player.st.stealth = nil
      cls.hidden = false
      cls.openers[tostring(inst.uid)] = true
      Combat.log(c, { t = "stealth_used", card = inst.uid })
      stat(c, "stealthUsed")
    end,
    onCardPlayed = function(c, cls, inst)
      cls.openers[tostring(inst.uid)] = nil
    end,
    -- miroir de Stealth : un gain n'est réel que si l'état était absent (pas d'empilement)
    onStatusApplied = function(c, cls, unit, id)
      if id ~= "stealth" or unit ~= c.player then return end
      cls.stealthGained = not cls.hidden
      cls.hidden = true
    end,
  },
  -- Bots : charges de Parry et Stealth distinguent deux positions (absents de la clé commune).
  botKey = function(c)
    return (c.player.st.parry or 0) .. ":" .. (c.player.st.stealth or 0)
  end,
  -- Valeur des charges de Parry restantes après le tour ennemi (un coup paré plus tard, environ 5 PV)
  -- et de Stealth (bonus de la prochaine Attack, environ 8 dégâts).
  botValue = function(c, W)
    local p = c.player
    return (p.st.parry or 0) * 5 * W.hp * 0.8 + (p.st.stealth or 0) * 8 * W.enemyHp
  end,
}
