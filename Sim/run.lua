-- Expédition simulée (version 0 : acte 1 linéaire, sans marchand ni rencontres).
-- Run.play(opts) -> enregistrement { won, floor, hp, deck, relics, combats = {...} }
-- opts : seed, bot ("random"|"greedy"|"heuristic"), class, pick ("rated"|"random"|"skip"),
--        force = { idCarte, ... } ajoutées au deck de départ, relics = { idBibelot, ... } au départ,
--        rep (palier de réputation de classe : 0..2, nil = toutes les cartes),
--        tier (palier de la Ligue des explorateurs : 0..3, nil = tout), loot (false = ni
--        bibelot ni potion gagnés), cap (nœuds de recherche), sequence (liste d'étapes), maxRounds.
return function(ns)
  local Combat, Card, Rng, Rewards, Bots = ns.Combat, ns.Card, ns.Rng, ns.Rewards, ns.Bots
  local Run = {}

  Run.SEQUENCE_ACT1 = { "easy", "easy", "normal", "campfire", "elite", "normal", "campfire", "boss" }
  Run.REST_FRACTION = 0.30
  -- Chance qu'un combat gagné (hors boss) laisse une potion, si un emplacement est libre.
  Run.POTION_DROP = 0.4

  -- Valeur grossière des cartes pour la politique de choix « rated », tirée des balayages
  -- (sweep=cards) : à peu près 5 + écart de victoires / 2.
  -- Les notes vivent dans la définition de chaque classe (classDef.bot.rating) ; réunies ici.
  Run.RATING = {}
  for _, cd in pairs(ns.Classes) do
    for id, r in pairs(cd.bot and cd.bot.rating or {}) do Run.RATING[id] = r end
  end
  -- cartes neutres (Data/Neutral.lua) : marchand et rencontres
  for id, r in pairs(ns.NeutralBot and ns.NeutralBot.rating or {}) do Run.RATING[id] = r end

  local function rating(id) return Run.RATING[id] or 3 end

  local function pickCard(opts, rng, choices)
    if opts.pick == "skip" or #choices == 0 then return nil end
    if opts.pick == "random" then return Rng.pick(rng, choices) end
    local best, bestR = nil, -1
    for i = 1, #choices do
      local r = rating(choices[i]) + Rng.float(rng) * 0.5
      if r > bestR then best, bestR = choices[i], r end
    end
    return best
  end

  local function upgradeTarget(deck, cd)
    local up = cd.bot and (cd.bot.upgradeRun or cd.bot.upgrade) or {}
    local best, bestR = nil, -1
    for i = 1, #deck do
      local card = deck[i]
      if not card.up then
        local r = up[card.id] or rating(card.id)
        if r > bestR then best, bestR = i, r end
      end
    end
    return best
  end

  -- Applique un crochet d'expédition des bibelots (gold, restHeal...).
  local function runHook(run, name, v)
    for i = 1, #run.relics do
      local r = ns.Relics[run.relics[i]]
      local h = r and r.run and r.run[name]
      if h then v = h(run, v) end
    end
    return v
  end
  Run.runHook = runHook

  -- Un ennemi annonce-t-il une interruption (Guette, ou coup qui interrompt) ?
  -- Renvoie "watch" (coupe à coup sûr), "push" (coup qui coupe s'il passe l'Absorption) ou nil.
  local function castThreat(c)
    local push = false
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      if not e.dead and (e.st.stunned or 0) == 0 then
        local info = Combat.intentInfo(c, e)
        if info.kind == "watch" then return "watch" end
        if info.interrupts then push = true end
      end
    end
    return push and "push" or nil
  end

  local function canCast(c)
    if c.player.cast then return false end
    for i = 1, #c.hand do
      if Card.def(c.hand[i]).cast and Combat.canPlay(c, i) then return true end
    end
    return false
  end

  local function fight(run, opts, encounter, kind, combatSeed, last)
    local c = Combat.new({ seed = combatSeed, class = run.class, hp = run.hp, maxHp = run.maxHp, deck = run.deck,
      encounter = encounter, relics = run.relics, potions = run.potions, charges = run.charges,
      stats = true, quiet = opts.quiet ~= false })
    local bot = Bots.new(opts.bot or "heuristic", Rng.stream(combatSeed, "bot"),
      { cap = opts.cap, potionKeep = last and 0 or 1 })
    local maxRounds = opts.maxRounds or 40
    local steps = 0
    -- Tours où une incantation était jouable : sous menace d'interruption ou non,
    -- et combien de fois le bot a incanté quand même.
    local cs = { threatTurns = 0, threatCasts = 0, freeTurns = 0, freeCasts = 0,
      watchTurns = 0, watchCasts = 0, pushTurns = 0, pushCasts = 0 }
    local turnRound, turnCastable, turnThreat, turnCasts = -1, false, nil, 0
    local function closeTurn()
      if turnRound >= 0 and turnCastable then
        local casted = c.stats.castsStarted > turnCasts
        if turnThreat then
          cs.threatTurns = cs.threatTurns + 1
          if casted then cs.threatCasts = cs.threatCasts + 1 end
          local k = turnThreat
          cs[k .. "Turns"] = cs[k .. "Turns"] + 1
          if casted then cs[k .. "Casts"] = cs[k .. "Casts"] + 1 end
        else
          cs.freeTurns = cs.freeTurns + 1
          if casted then cs.freeCasts = cs.freeCasts + 1 end
        end
      end
      turnRound = -1
    end
    while not c.result do
      if c.round > maxRounds then
        c.result = "lost"
        c.stalled = true
        break
      end
      if turnRound ~= c.round then
        closeTurn()
        turnRound, turnCastable, turnThreat = c.round, canCast(c), castThreat(c)
        turnCasts = c.stats.castsStarted
      end
      local a = bot:act(c)
      if a[1] == "end" then closeTurn() end
      steps = steps + 1
      if a[1] == "play" then
        local ok = Combat.play(c, a[2], a[3], a[4] == "nospend" and { spend = false } or nil)
        if not ok then Combat.endTurn(c) end
      elseif a[1] == "potion" then
        local ok = Combat.usePotion(c, a[2], a[3])
        if not ok then Combat.endTurn(c) end
      else
        Combat.endTurn(c)
      end
      if steps > 2000 then c.result = "lost"; c.stalled = true end
    end
    local rec = {
      kind = kind, encounter = table.concat(encounter, "+"), won = c.result == "won",
      turns = c.stats.turns, hpBefore = run.hp, hpAfter = math.max(c.player.hp, 0),
      hpLost = c.stats.hpLost, healed = c.stats.healed, stalled = c.stalled or false,
      castsStarted = c.stats.castsStarted, castsInterrupted = c.stats.castsInterrupted,
      enemyCasts = c.stats.enemyCasts, enemyCastsInterrupted = c.stats.enemyCastsInterrupted,
      played = c.stats.played, drawn = c.stats.drawn, unplayed = c.stats.unplayed,
      potions = c.stats.potions, castStats = cs,
    }
    run.hp = math.max(c.player.hp, 0)
    run.potions = c.player.potions
    run.charges = c.charges
    return rec
  end

  local function freeSlot(run)
    for i = 1, Combat.POTION_SLOTS do
      if not run.potions[i] then return i end
    end
    return nil
  end

  function Run.play(opts)
    local seed = opts.seed or 1
    local classId = opts.class or "priest"
    local class = ns.Classes[classId]
    local run = { class = classId, hp = class.hp, maxHp = class.hp, deck = {}, relics = {}, potions = {}, charges = {} }
    for i = 1, Combat.POTION_SLOTS do run.potions[i] = false end
    for i = 1, #class.deck do run.deck[#run.deck + 1] = { id = class.deck[i], up = false } end
    for i = 1, #(opts.force or {}) do run.deck[#run.deck + 1] = { id = opts.force[i], up = false } end
    if class.startRelic then run.relics[#run.relics + 1] = class.startRelic end
    for i = 1, #(opts.relics or {}) do run.relics[#run.relics + 1] = opts.relics[i] end
    local rngMap = Rng.stream(seed, "map")
    local rngLoot = Rng.stream(seed, "loot")
    local rngTreasure = Rng.stream(seed, "treasure")
    local pools = ns.Encounters.act1
    local lastEnc = {}
    local record = { seed = seed, won = false, floor = 0, combats = {}, picks = {}, relicsGained = {} }
    local sequence = opts.sequence or Run.SEQUENCE_ACT1
    local loot = opts.loot ~= false
    for floor = 1, #sequence do
      local step = sequence[floor]
      record.floor = floor
      if step == "campfire" then
        if run.hp < run.maxHp * 0.5 then
          local heal = runHook(run, "restHeal", math.floor(run.maxHp * Run.REST_FRACTION))
          run.hp = math.min(run.maxHp, run.hp + heal)
          record.picks[#record.picks + 1] = "rest"
        else
          local i = upgradeTarget(run.deck, class)
          if i then
            run.deck[i].up = true
            record.picks[#record.picks + 1] = "up:" .. run.deck[i].id
          end
        end
      else
        local pool = pools[step]
        local enc
        for _ = 1, 5 do
          enc = Rng.pick(rngMap, pool)
          if enc ~= lastEnc[step] then break end
        end
        lastEnc[step] = enc
        local rec = fight(run, opts, enc, step, seed * 100 + floor, floor == #sequence)
        record.combats[#record.combats + 1] = rec
        if not rec.won then
          record.hp = 0
          record.deck = run.deck
          record.relics = run.relics
          return record
        end
        if step ~= "boss" then
          local choices = Rewards.cardChoices(rngLoot, classId, 3, nil, opts.rep)
          local pick = pickCard(opts, rngLoot, choices)
          if pick then
            run.deck[#run.deck + 1] = { id = pick, up = false }
            record.picks[#record.picks + 1] = pick
          end
          if loot then
            -- Tirages sur un flux à part : les choix de cartes restent identiques avec ou sans butin.
            if step == "elite" then
              local owned = {}
              for i = 1, #run.relics do owned[run.relics[i]] = true end
              local r = Rewards.relicChoices(rngTreasure, 1, { maxTier = opts.tier, exclude = owned, class = classId })[1]
              if r then
                run.relics[#run.relics + 1] = r
                record.relicsGained[#record.relicsGained + 1] = r
                if ns.Relics[r].run and ns.Relics[r].run.onPickup then ns.Relics[r].run.onPickup(run) end
              end
            end
            local roll = Rng.float(rngTreasure)
            local slot = freeSlot(run)
            if slot and roll < Run.POTION_DROP then
              run.potions[slot] = Rewards.randomPotion(rngTreasure, opts.tier)
            end
          end
        end
      end
    end
    record.won = true
    record.hp = run.hp
    record.deck = run.deck
    record.relics = run.relics
    return record
  end

  return Run
end
