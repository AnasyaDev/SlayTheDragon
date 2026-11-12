-- Bots joueurs pour la simulation.
--   random     : joue des cartes jouables au hasard jusqu'à ne plus pouvoir (et boit
--                parfois une potion au hasard).
--   greedy     : à chaque pas, la carte ou la potion dont le résultat (tour ennemi compris)
--                est le meilleur.
--   heuristic  : explore les suites de coups du tour (avec élimination des doublons),
--                simule le tour ennemi au bout de chacune, garde la meilleure ; essaie aussi
--                de commencer le tour par chaque potion disponible.
-- Interface : local bot = Bots.new(nom, rng, opts) ;
--   bot:act(c) -> { "play", idx, tIdx } | { "potion", emplacement, tIdx } | { "end" }
-- opts : cap (nœuds de recherche), potionKeep (multiplicateur de la valeur de garder une
--        potion : 1 par défaut, 0 au dernier combat de l'expédition).
return function(ns)
  local Combat, Card, Rng = ns.Combat, ns.Card, ns.Rng
  local Bots = {}

  -- Évaluation d'un état après le tour ennemi. Poids grossiers, à régler.
  local W = { hp = 10, enemyHp = 4, enemyAlive = 30, res = 1.5, atonement = 4,
    regen = 0.5, power = 25, castRisk = 0.95 }
  Bots.W = W

  -- Valeur de garder une potion pour plus tard (unités de W : 10 = 1 PV). Une potion n'est
  -- bue que si elle rapporte plus ce tour-ci : éviter la mort, débloquer un gros tour...
  Bots.POTION_KEEP = { healing_potion = 180, mana_potion = 60, shadow_protection = 100,
    liquid_fire = 60, wisdom_elixir = 50 }
  Bots.potionKeep = 1

  local function potionsValue(c)
    local v = 0
    local pots = c.player.potions
    for i = 1, #pots do
      if pots[i] then v = v + (Bots.POTION_KEEP[pots[i]] or 60) end
    end
    return v * Bots.potionKeep
  end

  -- Part des cartes du combat qui vérifient pred (main, pioche, défausse, recharges, consumées).
  local function deckShare(c, pred)
    local n, k = 0, 0
    local function scan(list)
      for i = 1, #list do
        n = n + 1
        if pred(Card.def(list[i])) then k = k + 1 end
      end
    end
    scan(c.hand); scan(c.draw); scan(c.discard); scan(c.exhaust)
    for i = 1, #c.cooldown do
      n = n + 1
      if pred(Card.def(c.cooldown[i].card)) then k = k + 1 end
    end
    if n == 0 then return 0 end
    return k / n
  end

  -- Valeur d'un pouvoir en jeu (défaut W.power) : environ 3 tours restants × 3 cartes par tour.
  Bots.POWER_VALUE = {
    shadowform = function(c)
      local sh = deckShare(c, function(d) return d.school == "shadow" end)
      return 10 + 9 * sh * 5 * W.enemyHp
    end,
    apotheosis = function(c)
      return 4 * 6 * W.enemyHp + 9 * deckShare(c, function(d) return d.cast end) * 5 * W.enemyHp
    end,
    rapture = function(c)
      local share = deckShare(c, function(d)
        for i = 1, #d.effects do if d.effects[i][1] == "absorb" then return true end end
        return false
      end)
      return 10 + 9 * share * 2 * W.hp
    end,
    spirit_of_redemption = function(c)
      local miss = 1 - c.player.hp / c.player.maxHp
      return 25 + 150 * miss * miss
    end,
  }

  local function powersValue(c)
    local v = 0
    local powers = c.player.powers
    for i = 1, #powers do
      local f = Bots.POWER_VALUE[powers[i].id]
      v = v + (f and f(c) or W.power)
    end
    return v
  end

  -- Valeur attendue d'une incantation en cours (résolue au prochain tour).
  function Bots.castValue(c)
    local p = c.player
    local d = Card.def(p.cast.card)
    local alive = 0
    for i = 1, #c.enemies do if not c.enemies[i].dead then alive = alive + 1 end end
    local v = 0
    for i = 1, #d.effects do
      local e = d.effects[i]
      if e[1] == "damage" then
        v = v + e[2] * (e.times or 1) * (e.all and alive or 1) * W.enemyHp
      elseif e[1] == "heal" then
        v = v + math.min(e[2], p.maxHp - p.hp) * W.hp
      elseif e[1] == "apply" and e[2] == "pain" then
        v = v + e[3] * (e[3] + 1) / 2 * 0.8 * W.enemyHp
      elseif e[1] == "apply" and e[2] == "regen" then
        v = v + math.min(e[3] * (e[3] + 1) / 2, p.maxHp - p.hp) * W.hp * W.regen
      elseif e[1] == "absorb" then
        v = v + e[2] * W.hp * 0.5
      end
    end
    return v * W.castRisk
  end

  -- Valeur d'un point de ressource de classe (conseil de la classe : classDef.bot.resValue).
  local function resValue(c)
    local cd = ns.Classes[c.class]
    return cd and cd.bot and cd.bot.resValue or W.res
  end
  Bots.resValue = resValue

  local function evaluate(c)
    if c.result == "lost" then return -1e9 end
    local p = c.player
    if c.result == "won" then return 1e6 + p.hp * 100 + potionsValue(c) * 10 end
    local s = p.hp * W.hp + potionsValue(c)
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      if not e.dead then
        local pain = e.st.pain or 0
        local painDmg = pain * (pain + 1) / 2
        local ehp = e.hp - painDmg * 0.8
        if ehp < 0 then ehp = 0 end
        if e.minion then
          -- Les sbires fuient à la mort du chef : les compter plein faisait refuser au bot
          -- de passer le seuil d'invocation (VanCleef à 50 %) pendant que le boss se renforçait.
          s = s - (ehp + e.block * 0.5) * W.enemyHp * 0.5 - W.enemyAlive * 0.3
        else
          s = s - (ehp + e.block * 0.5) * W.enemyHp - W.enemyAlive
        end
        if (e.st.stunned or 0) > 0 then s = s + 15 end
      end
    end
    local regen = p.st.regen or 0
    local selfPain = p.st.pain or 0
    s = s + (p.res or 0) * resValue(c) + (p.st.atonement or 0) * W.atonement
      + math.min(regen * (regen + 1) / 2, p.maxHp - p.hp) * W.hp * W.regen + powersValue(c)
      - selfPain * (selfPain + 1) / 2 * W.hp * 0.8
    if p.cast then s = s + Bots.castValue(c) end
    -- valeur propre à la classe (état de classe, familier, formes…) : ns.ClassRules[classe].botValue
    local cr = ns.ClassRules[c.class]
    if cr and cr.botValue then s = s + cr.botValue(c, W) end
    return s
  end
  Bots.evaluate = evaluate

  -- Score d'une fin de tour : on joue le tour ennemi sur une copie.
  local function leafScore(s)
    if s.result then return evaluate(s) end
    local t = Combat.clone(s)
    Combat.endPlayerTurn(t)
    if not t.result then Combat.enemyPhase(t) end
    return evaluate(t)
  end
  Bots.leafScore = leafScore

  local function stateKey(c)
    local p = c.player
    local parts = { p.mana, p.hp, p.block, p.res, p.cast and p.cast.card.id or "-",
      p.st.atonement or 0, p.st.halved or 0, p.st.regen or 0, #p.powers, #c.cooldown, #c.exhaust,
      p.st.pain or 0 }
    local ids = {}
    for i = 1, #c.hand do
      local h = c.hand[i]
      ids[i] = h.up and (h.id .. "+") or h.id
    end
    table.sort(ids)
    parts[#parts + 1] = table.concat(ids, ",")
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      parts[#parts + 1] = e.dead and "x" or (e.hp .. ":" .. e.block .. ":" .. (e.st.pain or 0) .. ":"
        .. (e.st.armor_broken or 0) .. ":" .. (e.st.stunned or 0) .. ":" .. (e.interrupted and 1 or 0)
        .. ":" .. (e.st.demoralized or 0))
    end
    parts[#parts + 1] = c.result or ""
    -- état propre à la classe qui distingue deux positions (ns.ClassRules[classe].botKey)
    local cr = ns.ClassRules[c.class]
    if cr and cr.botKey then parts[#parts + 1] = cr.botKey(c) end
    return table.concat(parts, "|")
  end

  local function actionRef(c, a)
    local inst = c.hand[a[1]]
    return { uid = inst.uid, target = a[2] and c.enemies[a[2]].uid }
  end

  local function resolveRef(c, ref)
    if ref.potion then
      local slot
      for i = 1, #c.player.potions do
        if c.player.potions[i] == ref.potion then slot = i break end
      end
      if not slot then return nil end
      local tIdx
      if ref.target then
        local e, j = Combat.enemyByUid(c, ref.target)
        if not e or e.dead then return nil end
        tIdx = j
      end
      if not Combat.canUsePotion(c, slot, tIdx) then return nil end
      return { "potion", slot, tIdx }
    end
    local idx
    for i = 1, #c.hand do
      if c.hand[i].uid == ref.uid then idx = i break end
    end
    if not idx or not Combat.canPlay(c, idx) then return nil end
    local tIdx
    if ref.target then
      local e, j = Combat.enemyByUid(c, ref.target)
      if not e or e.dead then return nil end
      tIdx = j
    elseif Combat.needsTarget(c.hand[idx]) then
      return nil
    end
    return { "play", idx, tIdx }
  end

  -- Recherche en profondeur des suites de coups du tour.
  function Bots.planTurn(c, cap)
    cap = cap or 400
    local best, bestSeq = -math.huge, {}
    local nodes = 0
    local seen = {}
    local seq = {}
    local function dfs(s)
      nodes = nodes + 1
      local sc = leafScore(s)
      if sc > best then
        best = sc
        bestSeq = {}
        for i = 1, #seq do bestSeq[i] = seq[i] end
      end
      if s.result or nodes >= cap then return end
      local acts = Combat.legalPlays(s)
      local tried = {}
      for i = 1, #acts do
        local a = acts[i]
        local inst = s.hand[a[1]]
        local key = inst.id .. (inst.up and "+" or "") .. ":" .. (a[2] or 0)
        if not tried[key] then
          tried[key] = true
          local t = Combat.clone(s)
          Combat.play(t, a[1], a[2])
          local k = stateKey(t)
          if not seen[k] then
            seen[k] = true
            seq[#seq + 1] = actionRef(s, a)
            dfs(t)
            seq[#seq] = nil
          end
          if nodes >= cap then return end
        end
      end
    end
    dfs(c)
    return bestSeq, nodes, best
  end

  -- Plan du tour, en essayant aussi de boire d'abord chacune des potions disponibles.
  function Bots.planWithPotions(c, cap)
    local bestSeq, nodes, best = Bots.planTurn(c, cap)
    local pots = Combat.legalPotions(c)
    for i = 1, #pots do
      local a = pots[i]
      local t = Combat.clone(c)
      Combat.usePotion(t, a[1], a[2])
      local seq, n, sc = Bots.planTurn(t, cap)
      nodes = nodes + n
      if sc > best then
        best = sc
        bestSeq = { { potion = c.player.potions[a[1]], target = a[2] and c.enemies[a[2]].uid } }
        for j = 1, #seq do bestSeq[j + 1] = seq[j] end
      end
    end
    return bestSeq, nodes, best
  end

  local BotMT = {}
  BotMT.__index = BotMT

  function Bots.new(kind, rng, opts)
    return setmetatable({ kind = kind, rng = rng, opts = opts or {}, plan = nil, planRound = -1 }, BotMT)
  end

  function BotMT:act(c)
    Bots.potionKeep = self.opts.potionKeep or 1
    if self.kind == "random" then
      local pots = Combat.legalPotions(c)
      if #pots > 0 and Rng.float(self.rng) < 0.1 then
        local a = Rng.pick(self.rng, pots)
        return { "potion", a[1], a[2] }
      end
      local acts = Combat.legalPlays(c)
      if #acts == 0 then return { "end" } end
      local a = Rng.pick(self.rng, acts)
      return { "play", a[1], a[2] }
    elseif self.kind == "greedy" then
      local acts = Combat.legalPlays(c)
      local best, bestA = leafScore(c), nil
      for i = 1, #acts do
        local t = Combat.clone(c)
        Combat.play(t, acts[i][1], acts[i][2])
        local sc = leafScore(t)
        if sc > best then best, bestA = sc, { "play", acts[i][1], acts[i][2] } end
      end
      local pots = Combat.legalPotions(c)
      for i = 1, #pots do
        local t = Combat.clone(c)
        Combat.usePotion(t, pots[i][1], pots[i][2])
        local sc = leafScore(t)
        if sc > best then best, bestA = sc, { "potion", pots[i][1], pots[i][2] } end
      end
      if not bestA then return { "end" } end
      return bestA
    else
      for _ = 1, 2 do
        if self.planRound ~= c.round or not self.plan then
          self.plan = Bots.planWithPotions(c, self.opts.cap)
          self.planRound = c.round
          self.planPos = 1
        end
        local ref = self.plan[self.planPos]
        if not ref then return { "end" } end
        local a = resolveRef(c, ref)
        if a then
          self.planPos = self.planPos + 1
          return a
        end
        self.plan = nil -- le plan ne colle plus (pioche imprévue...) : on replanifie
      end
      return { "end" }
    end
  end

  return Bots
end
