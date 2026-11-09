-- Expédition complète simulée : un bot hors combat (chemin, récompenses, feu de camp,
-- marchand, rencontres, potions) joue via Core/Expedition, les combats sont joués par
-- les bots de Sim/bots.lua. Même API que l'interface : Expedition.choices / act.
-- SimExpedition.play(opts) -> enregistrement compatible avec Sim/sim.lua
-- opts : seed, bot, class, pick ("rated"|"random"|"skip"), cap, maxRounds,
--        key (niveau de clé mythique), meta ("start"|"exalted")
return function(ns)
  local X, Rng, Bots, Meta = ns.Expedition, ns.Rng, ns.Bots, ns.Meta
  local SE = {}

  local function rating(id) return ns.Run.RATING[id] or 3 end

  -- Valeur d'une carte du deck pour l'amélioration (cartes de base comprises).
  local function upgradeValue(card)
    if card.id == "smite" then return 2.5 end
    if card.id == "inner_fire" then return 2 end
    if card.id == "pw_shield" or card.id == "sw_pain" then return 1.5 end
    return rating(card.id)
  end

  local function bestUpgrade(exp)
    local best, bestV = nil, -1
    for i = 1, #exp.deck do
      if X.canUpgrade(exp, i) then
        local v = upgradeValue(exp.deck[i])
        if v > bestV then best, bestV = i, v end
      end
    end
    return best
  end

  -- Carte à retirer : la plus faible (Feu intérieur d'abord, puis Châtiment).
  local function worstCard(exp)
    local worst, worstV = nil, math.huge
    for i = 1, #exp.deck do
      local card = exp.deck[i]
      local v = card.id == "inner_fire" and 1 or card.id == "smite" and 1.5 or rating(card.id) + 2
      if card.up then v = v + 1 end
      if v < worstV then worst, worstV = i, v end
    end
    return worst, worstV
  end

  local function pickCard(opts, rng, cards)
    if opts.pick == "skip" or #cards == 0 then return nil end
    if opts.pick == "random" then return Rng.int(rng, 1, #cards) end
    local best, bestR = nil, -1
    for i = 1, #cards do
      local r = rating(cards[i]) + Rng.float(rng) * 0.5
      if r > bestR then best, bestR = i, r end
    end
    return best
  end

  -- Choix du chemin : meilleur score cumulé sur les chemins restants depuis chaque candidat.
  local function kindScore(kind, hpRatio, gold, removePrice)
    if kind == "combat" then return 1.0 end
    if kind == "elite" then
      if hpRatio > 0.7 then return 2.0 end
      if hpRatio > 0.5 then return 0.3 end
      return -3.0
    end
    if kind == "campfire" then return hpRatio < 0.5 and 3.0 or 1.0 end
    if kind == "merchant" then return gold >= math.min(removePrice, 60) and 1.6 or 0.4 end
    if kind == "event" then return 1.2 end
    if kind == "chest" then return 2.0 end
    return 0
  end

  local function pathValue(exp, id, depth)
    local node = exp.map.nodes[id]
    local hpRatio = exp.hp / exp.maxHp
    local v = kindScore(node.kind, hpRatio, exp.gold, X.removePrice(exp)) * (0.85 ^ depth)
    local best = 0
    for i = 1, #node.next do
      local w = pathValue(exp, node.next[i], depth + 1)
      if i == 1 or w > best then best = w end
    end
    return v + best
  end

  local function choosePath(exp, choices)
    local best, bestV
    for i = 1, #choices do
      local v = pathValue(exp, choices[i][2], 0)
      if not bestV or v > bestV then best, bestV = choices[i], v end
    end
    return best
  end

  local function eventValue(exp, ev, ci)
    local hpRatio = exp.hp / exp.maxHp
    local v = 0
    for _, e in ipairs(ev.choices[ci].effects) do
      local k = e[1]
      if k == "heal" then v = v + math.min(e[2], exp.maxHp - exp.hp) * 0.15
      elseif k == "healPct" then v = v + math.min(math.floor(exp.maxHp * e[2]), exp.maxHp - exp.hp) * 0.15
      elseif k == "loseHp" then v = v - e[2] * 0.12 / math.max(hpRatio, 0.2)
      elseif k == "maxHp" then v = v + e[2] * 0.2
      elseif k == "gold" then v = v + e[2] * 0.03
      elseif k == "pay" then v = v - e[2] * 0.03
      elseif k == "cardChoice" or k == "card" then v = v + 1.2
      elseif k == "relic" then v = v + 3
      elseif k == "potion" then v = v + (X.freeSlot(exp) and 1 or 0)
      elseif k == "upgradeRandom" then v = v + 0.8 * e[2]
      elseif k == "upgrade" then v = v + 1
      elseif k == "remove" then v = v + 1.2
      elseif k == "fight" then v = v + (hpRatio > 0.6 and 1.5 or -1.5)
      end
    end
    return v
  end

  local function has(choices, verb)
    for i = 1, #choices do
      if choices[i][1] == verb then return choices[i] end
    end
    return nil
  end

  -- Action hors combat selon la phase.
  local function decide(exp, opts, rng)
    local ch = X.choices(exp)
    local ph = exp.phase
    if ph == "start" then
      return has(ch, "startRelic") or { "skipStartRelic" }
    elseif ph == "map" then
      local paths = {}
      for i = 1, #ch do if ch[i][1] == "path" then paths[#paths + 1] = ch[i] end end
      return choosePath(exp, paths)
    elseif ph == "reward" then
      local r = exp.reward
      if not r.cardsDone then
        local i = pickCard(opts, rng, r.cards)
        if i then return { "pickCard", i } end
        return { "skipCards" }
      end
      if has(ch, "takePotion") then return { "takePotion" } end
      return { "leave" }
    elseif ph == "campfire" then
      local node = X.currentNode(exp)
      local nextBoss = false
      for _, nx in ipairs(node.next) do
        if exp.map.nodes[nx].kind == "boss" then nextBoss = true end
      end
      local ratio = exp.hp / exp.maxHp
      local up = bestUpgrade(exp)
      if ratio < 0.5 or (nextBoss and ratio < 0.7) or not up then return { "rest" } end
      return { "upgrade", up }
    elseif ph == "merchant" then
      local s = exp.shop
      for i, it in ipairs(s.relics) do
        if not it.sold and exp.gold >= it.price then return { "buyRelic", i } end
      end
      local w, wv = worstCard(exp)
      if w and wv <= 1.5 and #exp.deck > 8 and exp.gold >= X.removePrice(exp) then return { "remove", w } end
      local best, bestR
      for i, it in ipairs(s.cards) do
        if not it.sold and exp.gold >= it.price and rating(it.id) >= 6 and (not bestR or rating(it.id) > bestR) then
          best, bestR = i, rating(it.id)
        end
      end
      if best then return { "buyCard", best } end
      if X.freeSlot(exp) then
        for i, it in ipairs(s.potions) do
          if not it.sold and exp.gold >= it.price then return { "buyPotion", i } end
        end
      end
      return { "leave" }
    elseif ph == "event" then
      local ev = exp.event
      if not ev.id or ev.chosen then return { "leave" } end
      local def = ns.Events[ev.id]
      local best, bestV
      for i = 1, #ch do
        if ch[i][1] == "choose" then
          local v = eventValue(exp, def, ch[i][2])
          if not bestV or v > bestV then best, bestV = ch[i], v end
        end
      end
      return best or { "leave" }
    elseif ph == "select" then
      local i
      if exp.select.kind == "upgrade" then i = bestUpgrade(exp) else i = worstCard(exp) end
      if i then return { "select", i } end
      return { "skipSelect" }
    end
    return ch[1]
  end

  local function fight(exp, opts, record)
    local f, c = exp.fight, exp.combat
    local hpBefore = exp.hp
    local bot = Bots.new(opts.bot or "heuristic", Rng.stream(f.seed, "bot"), { cap = opts.cap })
    local maxRounds = opts.maxRounds or 40
    local steps, stalled = 0, false
    while exp.phase == "combat" and exp.combat == c do
      if c.round > maxRounds or steps > 2000 then
        stalled = true
        X.act(exp, { "abandon" })
        break
      end
      local a = bot:act(c)
      steps = steps + 1
      if a[1] == "play" then
        if not X.act(exp, { "play", a[2], a[3] }) then X.act(exp, { "endTurn" }) end
      elseif a[1] == "potion" then
        if not X.act(exp, a) then X.act(exp, { "endTurn" }) end
      else
        X.act(exp, { "endTurn" })
      end
    end
    local st = c.stats
    record.combats[#record.combats + 1] = {
      kind = f.pool, encounter = table.concat(f.encounter, "+"), won = c.result == "won",
      turns = st.turns, hpBefore = hpBefore, hpAfter = math.max(c.player.hp, 0),
      hpLost = st.hpLost, healed = st.healed, stalled = stalled,
      castsStarted = st.castsStarted, castsInterrupted = st.castsInterrupted,
      enemyCasts = st.enemyCasts, enemyCastsInterrupted = st.enemyCastsInterrupted,
      played = st.played, drawn = st.drawn, unplayed = st.unplayed,
    }
  end

  function SE.play(opts)
    local seed = opts.seed or 1
    local unlocks = opts.meta == "exalted" and Meta.allUnlocked() or { rep = 0, league = 0 }
    local exp = X.new({ seed = seed, class = opts.class or "priest", key = opts.key or 0,
      unlocks = unlocks, stats = true, quiet = opts.quiet ~= false })
    local rng = Rng.stream(seed, "policy")
    local record = { seed = seed, won = false, floor = 0, combats = {}, picks = {} }
    local guard = 0
    while exp.phase ~= "done" do
      guard = guard + 1
      if guard > 5000 then
        X.act(exp, { "abandon" })
        break
      end
      if exp.phase == "combat" then
        fight(exp, opts, record)
      else
        local before = exp.phase
        local a = decide(exp, opts, rng)
        if exp.phase == "reward" and a[1] == "pickCard" then
          record.picks[#record.picks + 1] = exp.reward.cards[a[2]]
        elseif a[1] == "upgrade" then
          record.picks[#record.picks + 1] = "up:" .. exp.deck[a[2]].id
        elseif a[1] == "rest" then
          record.picks[#record.picks + 1] = "rest"
        end
        local ok, why = X.act(exp, a)
        if not ok then error(("action refusée en phase %s : %s (%s)"):format(before, tostring(a[1]), tostring(why))) end
      end
    end
    record.won = exp.result == "won"
    record.floor = exp.floor
    record.hp = exp.hp
    record.deck = exp.deck
    record.gold = exp.gold
    record.goldEarned = exp.stats.goldEarned
    record.goldSpent = exp.stats.goldSpent
    record.relics = exp.relics
    record.visits = exp.stats.visits
    record.cleared = exp.stats.cleared
    record.rep = Meta.repFor(exp)
    record.removed = exp.stats.removed
    record.upgraded = exp.stats.upgraded
    return record, exp
  end

  return SE
end
