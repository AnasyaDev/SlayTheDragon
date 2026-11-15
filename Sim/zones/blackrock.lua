-- Conseils au bot pour Blackrock Mountain (phases) : chargé par Sim/load.lua. Le bot rejoue déjà chaque
-- coup sur une copie, tour ennemi compris : l'ouverture qui remplace l'intention pendant le tour, l'Absorb
-- de Shield Wall, le Fire Shield et la moitié du Throne sont vus. Ce qui ne l'est pas, et que value ajoute :
--   * la Strength gagnée par un ennemi (Enraged, Overheat, Frenzy) : environ un coup et demi par tour, sur
--     les tours qui restent ;
--   * l'ouverture différée (franchie après le tour : intention suivante imposée) : ses dégâts au prochain tour ;
--   * le Fire Shield encore actif : les prochains coups multiples coûteront des PV ;
--   * Burning Adrenaline : 15 PV à sa fin (sauf si le combat finit avant) ; Shadowflame Fury sur le point
--     de finir (Strength 8).
return function(ns, Bots, SE)
  local Combat = ns.Combat
  local BR = ns.Blackrock

  local function forcedDamage(c, e)
    local mv = e.mem.forced and ns.Combat.moveOf(e.id, e.mem.forced)
    if not mv then return 0 end
    local n = 0
    for _, a in ipairs(mv.actions) do
      if a[1] == "attack" then n = n + Combat.calcDamage(c, e, c.player, Combat.enemyBase(c, e, a)) * (a.times or 1) end
    end
    return n
  end

  ns.ZoneBots.blackrock = {
    value = function(c, W)
      local v = 0
      local p = c.player
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if not e.dead then
          local hits = e.minion and 1 or 1.5
          v = v - (e.st.force or 0) * hits * 2 * W.hp * 0.5
          v = v - forcedDamage(c, e) * W.hp * 0.6
          v = v - (e.st.fire_shield or 0) * 2 * W.hp * 0.6
          local sf = e.st.shadowflame_fury
          if sf and sf <= 1 then v = v - BR.FURY_STRENGTH * 2 * W.hp * 0.5 end
        end
      end
      if (p.st.burning_adrenaline or 0) > 0 then v = v - BR.ADRENALINE_LOSS * W.hp * 0.8 end
      return v
    end,
    -- phase en cours et intention imposée de chaque ennemi (deux positions aux mêmes PV peuvent différer)
    key = function(c)
      local parts = {}
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        parts[i] = (e.mem.phase or 0) .. (e.mem.forced or "") .. (e.st.force or 0)
      end
      return table.concat(parts, ",")
    end,
  }

  -- Grim Guzzler : une boisson offerte, une seconde à 30 po (case de la zone 7)
  SE.KIND_SCORE.grim_guzzler = function(exp, hpRatio) return hpRatio < 0.6 and 1.8 or 1.4 end
  SE.EFFECT_VALUE.nextCombat = SE.EFFECT_VALUE.nextCombat or function() return 0.8 end
  SE.EFFECT_VALUE.chain = SE.EFFECT_VALUE.chain or function() return 0 end
end
