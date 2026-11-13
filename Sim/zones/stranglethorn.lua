-- Conseils au bot pour Stranglethorn Vale (le Hex). Chargé par Sim/load.lua (docs/zones.md, § 9).
-- Le bot rejoue chaque fin de tour sur une copie, phase ennemie comprise : le verrouillage et la résolution
-- des Hex y ont lieu. Il lui manque la valeur de ce qu'un Hex retire : une carte Hexed coûte un mana pour
-- revenir (ou reste perdue), d'autant plus que la carte d'origine est chère, et chaque Hexed renforce Take a
-- Trophy tant qu'un Headhunter vit. Cette pénalité suffit à lui faire interrompre ou tuer les lanceurs,
-- jouer sa carte chère, garder une carte faible en main ou payer la grenouille.
return function(ns, Bots, SE)
  local Card = ns.Card

  local B = {
    hexed = 14,      -- une carte Hexed dans les piles (unités de Bots.W : 10 = 1 PV)
    perCost = 7,     -- + par point de coût de la carte d'origine (3 au plus)
    trophy = 14,     -- + par Headhunter vivant (Take a Trophy : +3 par coup)
  }
  ns.StranglethornBot = B

  local function headhunters(c)
    local n = 0
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      if not e.dead and e.id == "bloodscalp_headhunter" then n = n + 1 end
    end
    return n
  end

  ns.ZoneBots.stranglethorn = {
    value = function(c, W)
      local v = 0
      local hh
      for _, key in ipairs({ "hand", "draw", "discard" }) do
        local list = c[key]
        for i = 1, #list do
          local inst = list[i]
          if inst.id == "hexed" then
            hh = hh or headhunters(c)
            local cost = inst.orig and (Card.def(inst.orig).cost or 0) or 1
            if cost > 3 then cost = 3 end
            v = v - B.hexed - B.perCost * cost - B.trophy * hh
          end
        end
      end
      return v
    end,
  }

  -- Gurubashi Arena : un combat de plus, choisi (la rencontre décide ensuite : Fight ou Leave)
  SE.KIND_SCORE.gurubashi_arena = function(exp, hpRatio)
    if hpRatio > 0.65 then return 1.4 end
    return 0.6
  end
end
