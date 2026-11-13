-- Conseils au bot pour les Wetlands (mécanique Pack, docs/zones/wetlands.md). Le bot rejoue chaque coup sur une
-- copie, tour ennemi compris : les primes réglées par la carte et le coup suivant des ennemis sont déjà dans
-- son évaluation. Ce fichier ajoute ce qu'il ne voit pas : la Strength des ennemis sur les tours d'après, les
-- primes encore à venir (une mort plus tard renforcera les survivants ; tuer le chef les annule toutes), les
-- Charges de Modr. Unités de Bots.W : 10 = 1 PV du joueur, 4 = 1 PV ennemi.
return function(ns, Bots, SE)
  local WL = ns.Wetlands

  -- Coups par tour d'un ennemi, en moyenne sur ses intentions d'attaque (cache par id : définition fixe).
  local HITS = {}
  local function hitsOf(id)
    local h = HITS[id]
    if h then return h end
    local d = ns.Enemies[id]
    local n, k = 0, 0
    for _, mv in pairs(d.moves) do
      k = k + 1
      for _, a in ipairs(mv.actions) do
        if a[1] == "attack" then n = n + (a.times or 1) end
      end
    end
    h = k > 0 and n / k or 0
    HITS[id] = h
    return h
  end

  -- Tours encore à jouer après le prochain tour ennemi (déjà simulé) : PV ennemis restants / 18.
  local function turnsAfter(c)
    local hp = 0
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      if not e.dead then hp = hp + (e.minion and 0.5 or 1) * (e.hp + e.block) end
    end
    local t = hp / 18 - 1
    if t < 0 then t = 0 elseif t > 3 then t = 3 end
    return t
  end

  ns.ZoneBots.wetlands = {
    value = function(c, W)
      local T = turnsAfter(c)
      local v = 0
      local members = WL.alive(c)
      local n = #members
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if not e.dead then
          -- Strength gagnée : chaque coup des tours suivants
          local f = e.st.force or 0
          if f > 0 then v = v - f * hitsOf(e.id) * T * W.hp * 0.7 end
          -- Charges de Modr : le prochain Seismic Slam
          local ch = e.st.earthen_charge or 0
          if ch > 0 then v = v - ch * 8 * W.hp * 0.5 end
          -- limon : sa mort en fait d'autres (sans cela, le bot refuse de l'achever)
          local d = ns.Enemies[e.id]
          if d.splits then v = v - d.splits * (6.5 * W.enemyHp + W.enemyAlive) end
        end
      end
      -- primes à venir des membres encore en vie (le chef vivant les menace toutes : le tuer les annule)
      if n > 1 then
        for i = 1, n do
          local b = WL.bonus(members[i])
          if b then
            local others = n - 1
            if b[1] == "force" then
              v = v - b[2] * others * 1.2 * math.max(T, 0.5) * W.hp * 0.45
            elseif b[1] == "heal" then
              local miss = 0
              for j = 1, n do
                local o = members[j]
                if o ~= members[i] then miss = miss + math.min(b[2], o.maxHp - o.hp) end
              end
              v = v - miss * W.enemyHp * 0.5
            elseif b[1] == "absorb" then
              v = v - b[2] * others * W.enemyHp * 0.25
            end
          end
        end
      end
      return v
    end,
    -- Strength, dispersion et Charges distinguent deux positions (le reste est dans la clé commune)
    key = function(c)
      local parts = {}
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        parts[i] = e.dead and "x" or ((e.st.force or 0) .. (WL.scattered(e) and "s" or "") .. (e.st.earthen_charge or "")
          .. (e.st.wyrmscale and "w" or ""))
      end
      return table.concat(parts, ",")
    end,
  }

  -- Gryphon Master : passer une étape quand on est bas (moins de combats) ; sinon une rencontre ordinaire.
  SE.KIND_SCORE.gryphon_master = function(exp, hpRatio, gold)
    if hpRatio < 0.5 then return 2.2 end
    return 1.2
  end
  -- Vol : une étape de moins vaut surtout quand les PV manquent (unités : 1 ≈ une potion).
  SE.EFFECT_VALUE.skipFloors = function(exp, e)
    local ratio = exp.hp / exp.maxHp
    return ratio < 0.5 and 1.5 or 0.2
  end
end
