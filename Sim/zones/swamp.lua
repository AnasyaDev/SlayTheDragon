-- Conseils de simulation de Swamp of Sorrows (Slumber). Le bot rejoue chaque coup sur une copie, phase
-- ennemie comprise : un réveil pendant son tour (Rude Awakening, ouverture dans ce round) est déjà compté.
--   * clé : les compteurs Asleep et les ouvertures en attente distinguent deux positions (Dream Dust, Lull…),
--     que la clé commune (PV, Absorb, états communs) confondait ;
--   * valeur : le soin de Slumber à venir (Wyrmak, Somnus : mend par tour de sommeil restant).
-- Essai écarté (mesuré le 14/11/2026, Rogue, 200 expéditions) : compter d'avance l'ouverture d'un dormeur
-- (0,6 × ses dégâts) faisait réveiller trop tôt et chuter la victoire de 91 % à 71 % : un dormeur ne frappe
-- pas, la vue courte (tuer d'abord les éveillés, puis tuer le dormeur réveillé par son compteur avant son
-- ouverture) est la bonne stratégie de base.
return function(ns, Bots, SE)
  local S = ns.Swamp

  local B = { MEND_WEIGHT = 0.7 }

  B.value = function(c, W)
    local v = 0
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      local s = e.zs and e.zs.swamp
      if s and (s.mend or 0) > 0 and S.asleep(e) then
        v = v - math.min(s.mend * e.st.asleep, e.maxHp - e.hp) * W.enemyHp * B.MEND_WEIGHT
      end
    end
    return v
  end

  B.key = function(c)
    local parts = {}
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      parts[i] = (e.st.asleep or 0) .. (S.pending(e) and "p" or "") .. (e.intent or "")
    end
    return table.concat(parts, ",")
  end

  ns.ZoneBots.swamp = B
end
