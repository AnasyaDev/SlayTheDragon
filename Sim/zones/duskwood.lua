-- Conseils au bot pour Duskwood (Curse) : docs/zones.md § 9. Chargé par Sim/load.lua.
-- Le bot rejoue déjà chaque coup avec le tour ennemi (pertes « End of turn » de la main, Bite, Hex) ; il lui
-- manque ce qui vient APRÈS ce tour : les Curses encore dans les piles reviendront (Rabies, Fevered Plague,
-- Curse of Weakness), celles gardées en main (Web, Curse of Tongues) taxent chaque tour, Unholy Shield double
-- les PV restants de Morbent, les Fevered Plague de Stitches nourrissent sa Gorge. Tuer un lanceur lève ses
-- Curses : la pénalité disparaît de l'évaluation, d'où la priorité de cible sans règle de plus.
return function(ns, Bots, SE)
  local Card = ns.Card
  local DW = ns.Duskwood

  -- Coût d'une Curse quand elle revient en main (unités de W : 10 = 1 PV, 4 = 1 PV ennemi) : la payer
  -- (1 mana ≈ 6 dégâts) ou subir son effet, le moins cher des deux.
  local MANA = 6 * 4
  local DRAWN = {
    rabies = function(W) return math.min(MANA, 3 * W.hp) end,
    fevered_plague = function(W) return 2 * W.hp end,
    curse_of_weakness = function(W) return math.min(MANA, 2 * 3 * W.enemyHp) end,
    web = function(W) return math.min(2 * W.hp, 5 * W.enemyHp) end,
    curse_of_tongues = function(W) return 2 * MANA * 0.8 end,
  }
  -- Taxe par tour d'une Curse gardée en main (Retain) : une carte de moins, un mana de moins.
  local HELD = {
    web = function(W) return 5 * W.enemyHp end,
    curse_of_tongues = function(W) return MANA * 0.9 end,
  }

  -- Tours encore à jouer (même estimation que la valeur des Pouvoirs de Sim/bots.lua) : PV ennemis / 15.
  local function turnsLeft(c)
    local hp = 0
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      if not e.dead then
        local mul = (e.st.unholy_shield or 0) > 0 and 2 or 1
        hp = hp + (e.minion and 0.5 or 1) * (e.hp + e.block) * mul
      end
    end
    local t = hp / 15
    if t < 0.5 then t = 0.5 elseif t > 5 then t = 5 end
    return t
  end

  ns.ZoneBots.duskwood = {
    value = function(c, W)
      if c.result then return 0 end
      local v = 0
      local T = turnsLeft(c)
      -- cartes du cycle : une Curse de la pioche ou de la défausse revient environ T × 5 / taille du cycle fois
      local cycle = #c.draw + #c.discard + #c.hand
      local back = cycle > 0 and math.min(1.5, T * 5 / cycle) or 0
      local function pile(list, held)
        for i = 1, #list do
          local inst = list[i]
          local d = Card.def(inst)
          if d.curse then
            if held and HELD[inst.id] then
              v = v - HELD[inst.id](W) * T
            elseif DRAWN[inst.id] then
              v = v - DRAWN[inst.id](W) * (held and 1 or back)
            end
          end
        end
      end
      pile(c.draw, false)
      pile(c.discard, false)
      pile(c.hand, true)
      for i = 1, #c.cooldown do
        local inst = c.cooldown[i].card
        if Card.def(inst).curse and DRAWN[inst.id] then v = v - DRAWN[inst.id](W) * back end
      end
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if not e.dead then
          -- Unholy Shield : les PV restants comptent double tant qu'il tient (au-delà de ce tour)
          if (e.st.unholy_shield or 0) > 0 then v = v - e.hp * W.enemyHp * 0.35 end
          -- Stitches : chaque Fevered Plague de lui en jeu = Strength 1 à sa prochaine Gorge
          if ns.Enemies[e.id].moves.gorge then
            v = v - DW.count(c, e.uid, "fevered_plague") * W.force * 0.6
          end
        end
      end
      return v
    end,
  }

  -- Affiche WANTED : un peu mieux qu'une rencontre si l'on compte affronter une élite ; la prendre si les
  -- PV le permettent (50 po et une amélioration contre une élite qu'on aurait de toute façon).
  SE.KIND_SCORE.night_watch_poster = function(exp, hpRatio, gold) return 1.3 end
  SE.EFFECT_VALUE.wanted = function(exp, e)
    if exp.hp / exp.maxHp < 0.45 then return 0.2 end
    return 1.5 + 0.8
  end

  -- Notes des cartes neutres de la zone (même échelle que ns.NeutralBot.rating, Data/Neutral.lua).
  local rating = ns.NeutralBot and ns.NeutralBot.rating
  if rating then
    rating.anti_venom = rating.anti_venom or 4.5
    rating.zombie_juice = rating.zombie_juice or 5
  end
end
