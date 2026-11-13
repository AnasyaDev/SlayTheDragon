-- Expédition complète simulée : un bot hors combat (chemin, récompenses, feu de camp,
-- marchand, rencontres, potions) joue via Core/Expedition, les combats sont joués par
-- les bots de Sim/bots.lua. Même API que l'interface : Expedition.choices / act.
-- SimExpedition.play(opts) -> enregistrement compatible avec Sim/sim.lua
-- opts : seed, bot, class, pick ("rated"|"random"|"skip"), cap, maxRounds,
--        key (niveau de clé mythique), zone (zone jouée, défaut : la première),
--        zones (0..7 : zones gagnées par le compte et la classe, à toutes les clés),
--        meta ("start"|"exalted" : alias de zones=0 et zones=7), level (niveau de classe 1..7, défaut 7),
--        epic (id d'une carte épique imposée au deck de départ)
return function(ns)
  local X, Rng, Bots, Meta = ns.Expedition, ns.Rng, ns.Bots, ns.Meta
  local SE = {}
  -- Compte vétéran simulé (au moins une zone gagnée) : drapeaux toujours présents, et une branche
  -- d'histoire choisie par la graine.
  SE.VETERAN_FLAGS = { "event:tobin_thief" }
  SE.VETERAN_BRANCHES = { "tobin_spared", "tobin_jailed" }

  -- path=<voie> (SE.play, opts.path) : les cartes de classe d'une autre voie et les cartes neutres valent 0,
  -- donc ne sont jamais prises (voie jouée seule).
  local onlyPath
  -- Conseils de la classe jouée (classDef.bot : upgrade, remove).
  local function botOf(exp)
    local cd = ns.Classes[exp.class]
    return cd and cd.bot or {}
  end

  -- Conseils propres à l'épique du deck (classDef.bot.epics[id] = { rating, upgrade, remove } : notes qui
  -- remplacent celles de la classe tant que cette épique est dans le deck ; l'épique pilote le build).
  local curExp -- expédition dont le bot prend la décision en cours (decide)
  local function epicBot(exp)
    local eps = exp and botOf(exp).epics
    local i = eps and X.epicIndex(exp)
    return i and eps[exp.deck[i].id] or nil
  end

  local function rating(id)
    if onlyPath then
      local d = ns.Cards[id]
      if d and d.path ~= onlyPath and d.path ~= "start" then return 0 end
    end
    local eb = epicBot(curExp)
    if eb and eb.rating and eb.rating[id] then return eb.rating[id] end
    return ns.Run.RATING[id] or 3
  end

  -- Valeur d'une carte du deck pour l'amélioration (cartes de base comprises).
  local function upgradeValue(exp, card)
    local eb = epicBot(exp)
    if eb and eb.upgrade and eb.upgrade[card.id] then return eb.upgrade[card.id] end
    local up = botOf(exp).upgrade
    return up and up[card.id] or rating(card.id)
  end

  local function bestUpgrade(exp)
    local best, bestV = nil, -1
    for i = 1, #exp.deck do
      if X.canUpgrade(exp, i) then
        local v = upgradeValue(exp, exp.deck[i])
        if v > bestV then best, bestV = i, v end
      end
    end
    return best
  end

  -- Carte à retirer : la plus faible (Priest : Inner Fire d'abord, puis Smite ; classDef.bot.remove).
  local function worstCard(exp)
    local worst, worstV = nil, math.huge
    local rm = botOf(exp).remove or {}
    local eb = epicBot(exp)
    local erm = eb and eb.remove or {}
    for i = 1, #exp.deck do
      local card = exp.deck[i]
      local v = erm[card.id] or rm[card.id] or rating(card.id) + 2
      if card.up then v = v + 1 end
      if v < worstV then worst, worstV = i, v end
    end
    return worst, worstV
  end

  -- Valeur d'une carte ajoutée au deck, dans les unités des effets de rencontre (1 ≈ une potion,
  -- 0,03 par pièce d'or, 0,12 par PV à pleine vie). La note vaut ≈ 5 + écart / 2, l'écart étant les
  -- points de victoire gagnés en ajoutant la carte au deck de départ de 10 cartes (balayage sweep=cards,
  -- docs/equilibrage.md) : 5 = carte neutre, en dessous elle nuit. Son effet se dilue avec la taille du
  -- deck (elle est piochée moins souvent) : écart × 10 / taille. SE.POINTS_PER_UNIT = points de victoire
  -- que vaut une unité (≈ une potion, ≈ 8 PV).
  SE.POINTS_PER_UNIT = 3
  SE.UPGRADED_BONUS = 0.5 -- note d'une carte déjà améliorée
  local function cardValue(exp, r)
    return 2 * (r - 5) * 10 / math.max(#exp.deck, 10) / SE.POINTS_PER_UNIT
  end
  SE.cardValue = cardValue

  -- Note espérée de la meilleure de n cartes tirées sans remise dans pool (choix « une parmi n, ou passer ») :
  -- la k-ième plus faible des N notes est la meilleure avec la probabilité C(k-1, n-1) / C(N, n).
  local function expectedBest(pool, n)
    local rs = {}
    for i = 1, #pool do rs[i] = rating(pool[i]) end
    table.sort(rs)
    local N = #rs
    if N == 0 then return 0 end
    if n >= N then return rs[N] end
    local function choose(a, b)
      if b < 0 or b > a then return 0 end
      local v = 1
      for i = 1, b do v = v * (a - b + i) / i end
      return v
    end
    local total, v = choose(N, n), 0
    for k = n, N do v = v + rs[k] * choose(k - 1, n - 1) / total end
    return v
  end

  -- Réserve d'un choix de cartes de rencontre (mêmes filtres que Core/Expedition : rareté, neutres).
  local function choicePool(exp, e)
    local pool = e.neutral and X.neutralPool(exp) or X.cardPool(exp)
    if not e.rarity then return pool end
    local out = {}
    for i = 1, #pool do
      if ns.Cards[pool[i]].rarity == e.rarity then out[#out + 1] = pool[i] end
    end
    return #out > 0 and out or pool
  end

  -- Choix d'une carte (récompense ou rencontre) : la mieux notée, ou aucune si l'ajouter nuirait au deck.
  local function pickCard(exp, opts, rng, cards)
    if opts.pick == "skip" or #cards == 0 then return nil end
    if opts.pick == "random" then return Rng.int(rng, 1, #cards) end
    local best, bestR, bestRaw = nil, -1, nil
    for i = 1, #cards do
      local r = rating(cards[i]) + Rng.float(rng) * 0.5
      if r > bestR then best, bestR, bestRaw = i, r, rating(cards[i]) end
    end
    if opts.pick ~= "always" and cardValue(exp, bestRaw) < 0 then return nil end
    return best
  end

  -- Cartes épiques (une seule dans le deck, docs/expedition.md) : note d'une épique dans ce deck. Extensible
  -- par classe : classDef.bot.epic = function(exp, id) -> note (nil : défaut), sinon la note de la carte
  -- (classDef.bot.rating), sinon SE.EPIC_RATING. Le bot prend la meilleure si elle vaut mieux que l'épique
  -- du deck de SE.EPIC_MARGIN (note de l'actuelle + SE.UPGRADED_BONUS si elle est améliorée).
  SE.EPIC_RATING = 7
  SE.EPIC_MARGIN = 0.5
  local function epicRating(exp, id)
    local b = botOf(exp)
    local v = b.epic and b.epic(exp, id)
    if v then return v end
    return ns.Run.RATING[id] or SE.EPIC_RATING
  end
  SE.epicRating = epicRating

  -- Gain (unités des rencontres) à prendre l'épique id : sa valeur, moins celle de l'épique remplacée.
  local function epicGain(exp, id)
    local i = X.epicIndex(exp)
    local v = cardValue(exp, epicRating(exp, id))
    if i then
      local cur = exp.deck[i]
      v = v - cardValue(exp, epicRating(exp, cur.id) + (cur.up and SE.UPGRADED_BONUS or 0))
        - SE.EPIC_MARGIN * 2 * 10 / math.max(#exp.deck, 10) / SE.POINTS_PER_UNIT
    end
    return v
  end
  SE.epicGain = epicGain

  -- Choix « Epic » : index de l'épique à prendre, ou nil (refus).
  local function pickEpic(exp, opts, rng, epics)
    if opts.pick == "skip" or #epics == 0 then return nil end
    if opts.pick == "random" then return Rng.int(rng, 1, #epics) end
    local best, bestV
    for i = 1, #epics do
      local v = epicGain(exp, epics[i])
      if not bestV or v > bestV then best, bestV = i, v end
    end
    if bestV < 0 then return nil end
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

  -- Valeur estimée d'une liste d'effets de rencontre (le bot ne regarde pas les tirages
  -- figés : un pari vaut son espérance).
  local function effectsValue(exp, effects)
    local hpRatio = exp.hp / exp.maxHp
    local v = 0
    for _, e in ipairs(effects) do
      local k = e[1]
      if k == "heal" then v = v + math.min(e[2], exp.maxHp - exp.hp) * 0.15
      elseif k == "healPct" then v = v + math.min(math.floor(exp.maxHp * e[2]), exp.maxHp - exp.hp) * 0.15
      elseif k == "loseHp" then v = v - math.min(e[2], exp.hp - 1) * 0.12 / math.max(hpRatio, 0.2)
      elseif k == "maxHp" then v = v + e[2] * 0.2
      elseif k == "loseMaxHp" then v = v - e[2] * 0.25
      elseif k == "gold" then v = v + e[2] * 0.03
      elseif k == "pay" or k == "loseGold" then v = v - e[2] * 0.03
      elseif k == "card" then
        -- carte imposée : sa valeur dans ce deck, négative si elle l'affaiblit
        v = v + cardValue(exp, rating(e[2]) + (e.up and SE.UPGRADED_BONUS or 0))
      elseif k == "cardChoice" then
        -- une parmi n, ou passer : la meilleure espérée, jamais moins que rien
        v = v + math.max(0, cardValue(exp, expectedBest(choicePool(exp, e), e.n or 3)))
      elseif k == "relic" then v = v + 3
      elseif k == "potion" then v = v + (X.freeSlot(exp) and 1 or 0)
      elseif k == "losePotion" then v = v - 1
      elseif k == "upgradeRandom" then v = v + 0.8 * e[2]
      elseif k == "upgrade" then v = v + 1
      elseif k == "remove" then v = v + 1.2
      elseif k == "dupe" then v = v + 1.3
      elseif k == "fight" then
        -- Récompense attendue contre PV perdus en moyenne (mesurés à clé +0 : normal ≈ 15,
        -- élite ≈ 20 ; à +3 : 20 et 35) ; un combat optionnel (surtout d'élite) devient un risque de mort
        -- avec la clé (Tyrannique).
        local elite = e.kind == "elite"
        local key = exp.key or 0
        local cost = elite and (20 + 5 * key) or (15 + 2 * key)
        local gain = (elite and 5.0 or 2.2) + (e.gold or 0) * 0.03
        if exp.hp - cost < 12 then
          v = v - 5
        else
          v = v + gain - cost * 0.12 / math.max(hpRatio, 0.2) - (elite and key or 0.3 * key)
        end
      elseif k == "gamble" then
        v = v + e[2] * effectsValue(exp, e.win or {}) + (1 - e[2]) * effectsValue(exp, e.lose or {})
      end
    end
    return v
  end

  local function eventValue(exp, ev, ci)
    return effectsValue(exp, ev.choices[ci].effects)
  end

  local function has(choices, verb)
    for i = 1, #choices do
      if choices[i][1] == verb then return choices[i] end
    end
    return nil
  end

  -- Action hors combat selon la phase.
  local function decide(exp, opts, rng)
    curExp = exp
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
      if r.epics and not r.epicDone then
        local i = pickEpic(exp, opts, rng, r.epics)
        if i then return { "pickEpic", i } end
        return { "skipEpic" }
      end
      if not r.cardsDone then
        local i = pickCard(exp, opts, rng, r.cards)
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
      -- carte : celle dont la valeur dans le deck dépasse le plus son prix (0,03 par pièce, comme les
      -- rencontres)
      local best, bestR
      for i, it in ipairs(s.cards) do
        local v = (ns.Card.isEpic(ns.Cards[it.id]) and epicGain(exp, it.id) or cardValue(exp, rating(it.id)))
          - it.price * 0.03
        if not it.sold and exp.gold >= it.price and v > 0 and (not bestR or v > bestR) then
          best, bestR = i, v
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
      local kind = exp.select.kind
      if kind == "upgrade" then
        i = bestUpgrade(exp)
      elseif kind == "dupe" then
        -- Copie : la meilleure carte non basique, sinon on passe.
        local bestV = 0
        for j = 1, #exp.deck do
          local card = exp.deck[j]
          local r = ns.Cards[card.id].rarity
          local v = r ~= "basic" and r ~= "epic" and rating(card.id) + (card.up and 0.5 or 0) or 0
          if v > bestV then i, bestV = j, v end
        end
      else
        i = worstCard(exp)
      end
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
        if not X.act(exp, { "play", a[2], a[3], a[4] }) then Bots.markRetain(c) X.act(exp, { "endTurn" }) end
      elseif a[1] == "potion" then
        if not X.act(exp, a) then Bots.markRetain(c) X.act(exp, { "endTurn" }) end
      else
        Bots.markRetain(c) -- carte gardée au choix (Traveler's Backpack), posée avant la fin du tour
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
    onlyPath = opts.path
    local level = opts.level or Meta.MAX_LEVEL
    -- zones=N : le compte et la classe ont gagné les N premières zones, à toutes les clés (commun, cartes
    -- de zone, bibelots de clé) ; meta=start = zones=0, meta=exalted = zones=7 (tout débloqué).
    local zones = opts.zones
    if zones == nil then zones = opts.meta == "exalted" and ns.Zone.count() or 0 end
    local unlocks = Meta.allUnlocked(level, zones)
    -- Drapeaux de compte : compte neuf sans zone gagnée (premier temps des histoires possible),
    -- compte vétéran dès une zone gagnée (premier temps vu, suite selon la parité de la graine).
    local flags = opts.flags
    if not flags then
      flags = {}
      if zones > 0 then
        for _, f in ipairs(SE.VETERAN_FLAGS) do flags[f] = true end
        local branch = SE.VETERAN_BRANCHES[seed % #SE.VETERAN_BRANCHES + 1]
        flags[branch] = true
      end
    end
    local exp = X.new({ seed = seed, class = opts.class or "priest", zone = opts.zone, key = opts.key or 0,
      unlocks = unlocks, flags = flags, stats = true, quiet = opts.quiet ~= false, epic = opts.epic })
    -- cartes ajoutées de force au deck de départ (sweep=cards, force=…)
    for _, id in ipairs(opts.force or {}) do exp.deck[#exp.deck + 1] = { id = id, up = false } end
    -- PV de départ essayés sans toucher aux données (hp=N : mesure de l'effet des PV de la classe)
    if opts.hp then exp.hp, exp.maxHp = opts.hp, opts.hp end
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
        elseif exp.phase == "reward" and a[1] == "pickEpic" then
          record.picks[#record.picks + 1] = exp.reward.epics[a[2]]
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
    record.xp = Meta.xpFor(exp)
    record.removed = exp.stats.removed
    record.upgraded = exp.stats.upgraded
    record.events = exp.stats.events -- { id = réponse choisie }
    return record, exp
  end

  return SE
end
