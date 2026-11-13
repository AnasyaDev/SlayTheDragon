-- Conseils au bot pour les Burning Steppes (Wildfire) : docs/zones.md, § 9.
-- Le bot joue chaque suite de coups sur une copie, tour ennemi compris, mais PAS la fin du round : la
-- brûlure de ce round et celles des rounds suivants passent par `value`. Une mort (compte + 1) et un
-- Stoke interrompu ou étourdi se lisent dans l'état après le tour ennemi (compte plus haut, Blaze plus bas).
return function(ns, Bots, SE)
  local Wildfire = ns.Wildfire

  -- Dégâts par round que le joueur met aux ennemis, à la louche (durée restante du combat).
  local PACE = 13

  -- Brûlure attendue d'ici la fin du combat : round en cours (certain), puis rounds suivants pondérés.
  local function expectedBurn(c, z)
    local hp = 0
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      if not e.dead and not e.minion then hp = hp + e.hp + e.block * 0.5 end
    end
    if hp <= 0 then return 0 end
    local rounds = math.max(1, math.ceil(hp / PACE))
    local left, blaze, total = z.left, z.blaze, 0
    for r = 1, rounds do
      local w = r == 1 and 1 or 0.7
      if left == 0 then
        total = total + blaze * w
        blaze = blaze + z.step
      else
        left = left - 1
      end
    end
    return total
  end

  ns.ZoneBots.steppes = {
    value = function(c, W)
      local z = Wildfire.state(c)
      if not z or c.result then return 0 end
      return -expectedBurn(c, z) * W.hp
    end,
    key = function(c)
      local z = Wildfire.state(c)
      return z and (z.left .. ":" .. z.blaze) or ""
    end,
  }

  -- Cartes neutres de la zone (notes du bot : 5 + écart / 2, à mesurer ; points de départ).
  local R = ns.Run.RATING
  R.greater_fire_protection_potion = R.greater_fire_protection_potion or 5
  R.thorium_grenade = R.thorium_grenade or 5
end
