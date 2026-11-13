-- Effets de cartes. Une carte liste ses effets : { "nom", valeur, option = ... }.
-- Chaque gestionnaire reçoit (c, ctx, e) ; ctx = { card, def, target, dealt, hits, spent, surge, cast }.
--
-- Options communes à tous les effets (lues par Combat.resolveCard et Combat.amount) :
--   cond = "nom"           l'effet ne s'applique que si la condition est vraie (Combat.CONDITIONS :
--                          execute, spent, surged, status:<id>, et celles des classes)
--   more = { { k, "cond" } } valeur + k si la condition est vraie (« Spend 2: deal 5 more. »)
--   per = { k, "montant" }  valeur + k × montant (Combat.AMOUNTS : surge, res, block…)
-- Une classe ajoute ses propres effets dans ns.Effects depuis Core/Classes/<classe>.lua.
local _, ns = ...

local Combat = ns.Combat
local Effects = {}
ns.Effects = Effects

local function targetsOf(c, ctx, e)
  if e.all then return Combat.aliveEnemies(c) end
  if e.self then return { c.player } end
  if ctx.target and not ctx.target.dead then return { ctx.target } end
  return {}
end
Effects.targetsOf = targetsOf

-- { "damage", n, times = k, all = bool, pierce = bool, onHit = function(c, ctx, cible),
--   bonus = function(c, ctx, cible) -> dégâts de base en plus, more = …, per = … }
-- Genre du coup pour les crochets de dégâts sur un ennemi (Combat.hitInfo) : potion, Trap, incantation
-- résolue, carte.
local function hitKindOf(c, ctx)
  if ctx.potion then return "potion" end
  if c.fxKind == "trap" then return "trap" end
  if ctx.cast then return "cast" end
  return "card"
end

Effects.damage = function(c, ctx, e)
  local k0, a0 = c.hitKind, c.hitAll
  c.hitKind, c.hitAll = hitKindOf(c, ctx), e.all and true or false
  for _ = 1, (e.times or 1) do
    local targets = targetsOf(c, ctx, e)
    if #targets == 0 then break end
    for i = 1, #targets do
      local t = targets[i]
      local base = e[2]
      if e.bonus then base = base + e.bonus(c, ctx, t) end
      if e.more or e.per then base = Combat.amount(c, ctx, e, base, t) end
      local dmg = Combat.calcDamage(c, c.player, t, base, ctx.def)
      -- crochet « convertHit » (c, src, dégâts, cible, ctx) : dégâts du coup, ou false = coup non porté (un
      -- crochet a posé autre chose à la place : Doomblade) ; ni dégâts, ni onHit, ni onAttackHit
      dmg = Combat.modify(c, "convertHit", dmg, t, ctx)
      if dmg then
        Combat.dealDamage(c, c.player, t, dmg, e.pierce, ctx)
        ctx.dealt = true
        ctx.hits = ctx.hits + 1
        if e.onHit then e.onHit(c, ctx, t) end
        -- chaque coup d'une carte Attack (poisons du Rogue, Ignite du Mage…)
        if ctx.def and ctx.def.type == "attack" and not c.result then Combat.fire(c, "onAttackHit", t, ctx) end
      end
      if c.result then break end
    end
    if c.result then break end
  end
  c.hitKind, c.hitAll = k0, a0
end

-- { "absorb", n }
Effects.absorb = function(c, ctx, e)
  local n = e[2]
  if e.more or e.per then n = Combat.amount(c, ctx, e, n, ctx.target) end
  if n > 0 then Combat.gainBlock(c, c.player, n) end
end

-- { "apply", état, n, all = bool, self = bool, icon = clé d'art (icône du DoT selon la source) }
-- Crochet modify "apply" (c, src, n, état, cible, défCarte) : ajuste la valeur posée sur un ennemi.
Effects.apply = function(c, ctx, e)
  local targets = targetsOf(c, ctx, e)
  for i = 1, #targets do
    local t = targets[i]
    local n = e[3]
    if e.more or e.per then n = Combat.amount(c, ctx, e, n, t) end
    if t.side == "enemy" then n = Combat.modify(c, "apply", n, e[2], t, ctx.def) end
    if n ~= 0 then Combat.applyStatus(c, t, e[2], n, e.icon) end
  end
end

-- { "heal", n }
Effects.heal = function(c, ctx, e)
  local n = e[2]
  if e.more or e.per then n = Combat.amount(c, ctx, e, n, ctx.target) end
  Combat.heal(c, c.player, n)
end

-- { "draw", n }
Effects.draw = function(c, ctx, e)
  local n = e[2]
  if e.more or e.per then n = Combat.amount(c, ctx, e, n, ctx.target) end
  Combat.drawCards(c, n)
end

-- { "mana", n }
Effects.mana = function(c, ctx, e)
  c.player.mana = c.player.mana + e[2]
end

-- { "res", n } : « +N Rage. » (ressource de la classe, bornée par son plafond).
Effects.res = function(c, ctx, e)
  local n = e[2]
  if e.more or e.per then n = Combat.amount(c, ctx, e, n, ctx.target) end
  Combat.gainRes(c, n, "card")
end
Effects.demence = Effects.res -- ancien nom (Démence du Prêtre)

-- { "surge" } : « Surge: … » dépense toute la ressource ; ctx.surge = montant (per = { k, "surge" }).
-- Crochet modify "surge" (c, src, n, ctx) : montant compté par les effets d'un Surge qui a dépensé
-- quelque chose (Anathema) ; la ressource réellement dépensée ne change pas.
Effects.surge = function(c, ctx, e)
  local n = Combat.surge(c)
  ctx.surge = (ctx.surge or 0) + (n > 0 and Combat.modify(c, "surge", n, ctx) or 0)
  if n > 0 then Combat.fire(c, "onSurge", n, ctx) end
end

-- « Spend N: … » n'est PAS un effet : c'est le champ de carte spend = N, payé au moment du jeu
-- (Combat.play, comme le mana) ; ctx.spent dit s'il a été payé (cond = "spent", more = { k, "spent" }).

-- { "loseHp", n, safe = bool } : perte de PV sans Absorption (effet ; le coût « Pay N HP » est le champ
-- payHp, seule formulation d'une perte de PV sur une carte). safe : jamais mortelle (laisse au moins 1 PV).
Effects.loseHp = function(c, ctx, e)
  local n = e[2]
  if e.safe then n = math.min(n, c.player.hp - 1) end
  Combat.loseHp(c, n, e.why or "effect") -- why : raison transmise à onHpLost (« curse »)
end

-- { "interrupt", all = bool } : annule le sort que la cible (ou chaque ennemi) s'apprête à lancer.
Effects.interrupt = function(c, ctx, e)
  local list = e.all and Combat.aliveEnemies(c) or { ctx.target }
  for i = 1, #list do
    local t = list[i]
    local mv = t and not t.dead and ns.Enemies[t.id].moves[t.intent]
    if mv and mv.cast and not t.interrupted then
      t.interrupted = true
      ctx.interrupted = (ctx.interrupted or 0) + 1 -- condition « interrupted »
      Combat.log(c, { t = "interrupt", src = "player", dst = t.uid, move = t.intent })
      Combat.zfire(c, "onEnemyCastInterrupted", t, t.intent, "player")
    end
  end
end

-- { "restore" } : la carte jouée est une carte transformée (Hexed) : sa carte d'origine revient en main
-- (Combat.restoreCard) ; la carte jouée porte vanish = true (elle disparaît).
Effects.restore = function(c, ctx, e)
  local inst = ctx.card
  if inst and inst.orig then Combat.restoreCard(c, inst, e.to) end
end

-- { "restoreAll", id = "hexed" } : toutes les cartes transformées (de cet id) de la main, de la pioche et
-- de la défausse rendent leur carte d'origine (en main ; pleine : défausse).
Effects.restoreAll = function(c, ctx, e)
  local list = {}
  for _, key in ipairs({ "hand", "draw", "discard" }) do
    for _, inst in ipairs(c[key]) do
      if inst.orig and (not e.id or inst.id == e.id) then list[#list + 1] = inst end
    end
  end
  for i = 1, #list do Combat.restoreCard(c, list[i]) end
end

-- { "addCard", id, to = "hand" | "draw" | "drawRandom" | "discard", n = 1, up = bool } : carte de combat
-- ajoutée aux piles du joueur (Combat.addCard).
Effects.addCard = function(c, ctx, e)
  for _ = 1, (e.n or 1) do
    Combat.addCard(c, e[2], e.to or "hand", { up = e.up })
    if c.result then return end
  end
end

-- { "tickDot", all = bool } : déclenche tout de suite le DoT de la cible (Envenom) ou de tous.
Effects.tickDot = function(c, ctx, e)
  local list = e.all and Combat.aliveEnemies(c) or { ctx.target }
  for i = 1, #list do
    if list[i] and not list[i].dead then Combat.tickDot(c, list[i]) end
    if c.result then return end
  end
end

-- { "cleanse" } : retire tous tes états négatifs.
Effects.cleanse = function(c, ctx, e)
  Combat.cleanse(c, c.player)
end

-- { "fn", function(c, ctx) } : effet sur mesure.
Effects.fn = function(c, ctx, e)
  e[2](c, ctx)
end
