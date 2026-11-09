-- Effets de cartes. Une carte liste ses effets : { "nom", valeur, option = ... }.
-- Chaque gestionnaire reçoit (c, ctx, e) ; ctx = { card, def, target, dealt, hits }.
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

-- { "damage", n, times = k, all = bool, onHit = function(c, ctx, cible),
--   bonus = function(c, ctx, cible) -> dégâts de base en plus }
Effects.damage = function(c, ctx, e)
  for _ = 1, (e.times or 1) do
    local targets = targetsOf(c, ctx, e)
    if #targets == 0 then return end
    for i = 1, #targets do
      local t = targets[i]
      local base = e[2]
      if e.bonus then base = base + e.bonus(c, ctx, t) end
      local dmg = Combat.calcDamage(c, c.player, t, base, ctx.def)
      Combat.dealDamage(c, c.player, t, dmg)
      ctx.dealt = true
      ctx.hits = ctx.hits + 1
      if e.onHit then e.onHit(c, ctx, t) end
      if c.result then return end
    end
  end
end

-- { "absorb", n }
Effects.absorb = function(c, ctx, e)
  Combat.gainBlock(c, c.player, e[2])
end

-- { "apply", état, n, all = bool, self = bool }
Effects.apply = function(c, ctx, e)
  local targets = targetsOf(c, ctx, e)
  for i = 1, #targets do Combat.applyStatus(c, targets[i], e[2], e[3]) end
end

-- { "heal", n }
Effects.heal = function(c, ctx, e)
  Combat.heal(c, c.player, e[2])
end

-- { "draw", n }
Effects.draw = function(c, ctx, e)
  Combat.drawCards(c, e[2])
end

-- { "mana", n }
Effects.mana = function(c, ctx, e)
  c.player.mana = c.player.mana + e[2]
end

-- { "demence", n }
Effects.demence = function(c, ctx, e)
  c.player.demence = c.player.demence + e[2]
  Combat.log(c, { t = "demence", n = e[2], total = c.player.demence })
end

-- { "interrupt" } : annule le sort que la cible s'apprête à lancer.
Effects.interrupt = function(c, ctx, e)
  local t = ctx.target
  if not t or t.dead then return end
  local mv = ns.Enemies[t.id].moves[t.intent]
  if mv and mv.cast and not t.interrupted then
    t.interrupted = true
    Combat.log(c, { t = "interrupt", src = "player", dst = t.uid, move = t.intent })
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
