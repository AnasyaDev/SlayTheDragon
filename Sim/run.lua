-- Expédition simulée (version 0 : acte 1 linéaire, sans marchand ni rencontres).
-- Run.play(opts) -> enregistrement { won, floor, hp, deck, combats = {...} }
-- opts : seed, bot ("random"|"greedy"|"heuristic"), class, pick ("rated"|"random"|"skip"),
--        force = { idCarte, ... } ajoutées au deck de départ, cap (nœuds de recherche),
--        sequence (liste d'étapes), maxRounds.
return function(ns)
  local Combat, Card, Rng, Rewards, Bots = ns.Combat, ns.Card, ns.Rng, ns.Rewards, ns.Bots
  local Run = {}

  Run.SEQUENCE_ACT1 = { "easy", "easy", "normal", "campfire", "elite", "normal", "campfire", "boss" }
  Run.REST_FRACTION = 0.30

  -- Valeur grossière des cartes pour la politique de choix « rated ».
  Run.RATING = {
    penance = 8, mind_blast = 7, chastise = 7, radiance = 6, holy_nova = 6, holy_fire = 6,
    pain_suppression = 6, shadowform = 5, mind_flay = 5, devouring_plague = 4, silence = 4,
    greater_heal = 5, spirit_of_redemption = 4,
  }

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

  local function upgradeTarget(deck)
    local best, bestR = nil, -1
    for i = 1, #deck do
      local card = deck[i]
      if not card.up then
        local r = card.id == "smite" and 2.5 or card.id == "inner_fire" and 2 or rating(card.id)
        if r > bestR then best, bestR = i, r end
      end
    end
    return best
  end

  local function fight(run, opts, encounter, kind, combatSeed)
    local c = Combat.new({ seed = combatSeed, hp = run.hp, maxHp = run.maxHp, deck = run.deck,
      encounter = encounter, relics = run.relics, stats = true, quiet = opts.quiet ~= false })
    local bot = Bots.new(opts.bot or "heuristic", Rng.stream(combatSeed, "bot"), { cap = opts.cap })
    local maxRounds = opts.maxRounds or 40
    local steps = 0
    while not c.result do
      if c.round > maxRounds then
        c.result = "lost"
        c.stalled = true
        break
      end
      local a = bot:act(c)
      steps = steps + 1
      if a[1] == "play" then
        local ok = Combat.play(c, a[2], a[3])
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
    }
    run.hp = math.max(c.player.hp, 0)
    return rec
  end

  function Run.play(opts)
    local seed = opts.seed or 1
    local class = ns.Classes[opts.class or "priest"]
    local run = { hp = class.hp, maxHp = class.hp, deck = {}, relics = {} }
    for i = 1, #class.deck do run.deck[#run.deck + 1] = { id = class.deck[i], up = false } end
    for i = 1, #(opts.force or {}) do run.deck[#run.deck + 1] = { id = opts.force[i], up = false } end
    local rngMap = Rng.stream(seed, "map")
    local rngLoot = Rng.stream(seed, "loot")
    local pools = ns.Encounters.act1
    local lastEnc = {}
    local record = { seed = seed, won = false, floor = 0, combats = {}, picks = {} }
    local sequence = opts.sequence or Run.SEQUENCE_ACT1
    for floor = 1, #sequence do
      local step = sequence[floor]
      record.floor = floor
      if step == "campfire" then
        if run.hp < run.maxHp * 0.5 then
          run.hp = math.min(run.maxHp, run.hp + math.floor(run.maxHp * Run.REST_FRACTION))
          record.picks[#record.picks + 1] = "rest"
        else
          local i = upgradeTarget(run.deck)
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
        local rec = fight(run, opts, enc, step, seed * 100 + floor)
        record.combats[#record.combats + 1] = rec
        if not rec.won then
          record.hp = 0
          record.deck = run.deck
          return record
        end
        if step ~= "boss" then
          local choices = Rewards.cardChoices(rngLoot, opts.class or "priest", 3)
          local pick = pickCard(opts, rngLoot, choices)
          if pick then
            run.deck[#run.deck + 1] = { id = pick, up = false }
            record.picks[#record.picks + 1] = pick
          end
        end
      end
    end
    record.won = true
    record.hp = run.hp
    record.deck = run.deck
    return record
  end

  return Run
end
