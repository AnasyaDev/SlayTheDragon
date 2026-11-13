-- Tests du socle des cartes épiques (rareté epic, une seule par expédition, transformations, règle en jeu
-- dès le début du combat, chute par élite selon la zone et marchand, Innate, effets passifs du deck) et des points
-- d'accroche de classe qu'elles demandent.
-- Aucune carte réelle : des cartes factices (préfixe te_), retirées à la fin.
-- Usage : lua5.1 Sim/tests_epic.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Meta, Save, Combat, Card, Rng, U = ns.Expedition, ns.Meta, ns.Save, ns.Combat, ns.Card, ns.Rng, ns.Util

local passed, failed = 0, 0
local function test(name, f)
  local ok, err = pcall(f)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("ÉCHEC  " .. name .. "\n       " .. tostring(err))
  end
end
local function eq(a, b, msg)
  if a ~= b then error((msg or "") .. " attendu " .. tostring(b) .. ", obtenu " .. tostring(a), 2) end
end

-- Sérialisation façon SavedVariables (aller-retour d'un état).
local function ser(v, out)
  local t = type(v)
  if t == "number" then out[#out + 1] = string.format("%.17g", v)
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "boolean" then out[#out + 1] = tostring(v)
  elseif t == "table" then
    out[#out + 1] = "{"
    for k, x in pairs(v) do
      out[#out + 1] = "["
      ser(k, out)
      out[#out + 1] = "]="
      ser(x, out)
      out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  else error("valeur non sauvegardable : " .. t) end
end
local function reload(v) local o = {}; ser(v, o); return assert(loadstring("return " .. table.concat(o)))() end

---------------------------------------------------------------------------
-- Données factices
---------------------------------------------------------------------------
local Cards = ns.Cards
local added = {}
-- épiques réelles du Rogue mises de côté le temps de ces tests (les épiques factices du Rogue les
-- remplacent ; règles réelles : Sim/tests_epic_rogue.lua), remises à la fin
local realRogue = {}
for id, d in pairs(Cards) do if d.class == "rogue" and d.rarity == "epic" then realRogue[id] = d end end
-- de même pour celles du Guerrier (règles réelles : Sim/tests_epic_warrior.lua), remises avec elles
for id, d in pairs(Cards) do if d.class == "warrior" and d.rarity == "epic" then realRogue[id] = d end end
for id in pairs(realRogue) do Cards[id] = nil end
-- de même pour celles du Hunter (règles réelles : Sim/tests_epic_hunter.lua)
local realHunter = {}
for id, d in pairs(Cards) do if d.class == "hunter" and d.rarity == "epic" then realHunter[id] = d end end
for id in pairs(realHunter) do Cards[id] = nil end
local function card(id, t)
  t.id = id
  Cards[id] = t
  added[#added + 1] = id
end

-- épiques du Rogue (zones 1 à 4), une transforme Sinister Strike et Feint
card("te_epic_a", { class = "rogue", zone = "westfall", rarity = "epic", name = "Test Epic A", cost = 1,
  type = "power", path = "combat", power = true, effects = {}, text = "Power.\nTest.",
  transforms = { sinister_strike = "te_variant_ss", feint = "te_variant_feint" },
  up = { cost = 0 } })
card("te_epic_b", { class = "rogue", zone = "duskwood", rarity = "epic", name = "Test Epic B", cost = 1,
  type = "skill", path = "subtlety", effects = { { "draw", 1 } }, text = "Draw 1.", up = { cost = 0 } })
card("te_epic_c", { class = "rogue", zone = "wetlands", rarity = "epic", name = "Test Epic C", cost = 1,
  type = "skill", path = "assassination", effects = { { "draw", 1 } }, text = "Draw 1.", up = { cost = 0 } })
card("te_epic_d", { class = "rogue", zone = "stranglethorn", rarity = "epic", name = "Test Epic D", cost = 1,
  type = "skill", path = "assassination", effects = { { "draw", 1 } }, text = "Draw 1.", up = { cost = 0 } })
-- variantes (non collectionnables) ; la seconde sans amélioration
card("te_variant_ss", { class = "rogue", variant = true, rarity = "basic", name = "Test Variant", cost = 1,
  type = "attack", path = "start", target = "enemy", effects = { { "damage", 9 } }, text = "Deal 9.",
  up = { effects = { { "damage", 12 } }, text = "Deal 12." } })
card("te_variant_feint", { class = "rogue", variant = true, rarity = "basic", name = "Test Variant Feint",
  cost = 0, type = "skill", path = "start", effects = { { "draw", 1 } }, text = "Draw 1." })
-- une carte Innate, une carte à effet passif (deckHooks + whileInDeck)
card("te_innate", { class = "rogue", rarity = "common", name = "Test Innate", cost = 0, type = "skill",
  path = "combat", innate = true, effects = { { "draw", 0 } }, text = "Draw 0.\nInnate.", noReward = true })
card("te_passive", { class = "rogue", rarity = "epic", zone = "swamp", name = "Test Passive", cost = 1,
  type = "skill", path = "combat", effects = {}, text = "Epic.\nTest.",
  whileInDeck = function(c, src) c.cls.teStart = (c.cls.teStart or 0) + 1 end,
  deckHooks = { maxMana = function(c, src, v) return v + 1 end },
  hooks = { allow = function(c, src, d) return d.id ~= "backstab" end }, up = { text = "Epic.\nTest+." } })
-- carte ordinaire à effet passif du deck (deckHooks hors épique : chaque exemplaire compte)
card("te_deckpassive", { class = "rogue", rarity = "common", name = "Test Deck Passive", cost = 1, noReward = true,
  type = "skill", path = "combat", effects = {}, text = "Test.",
  whileInDeck = function(c, src) c.cls.teStart = (c.cls.teStart or 0) + 1 end,
  deckHooks = { maxMana = function(c, src, v) return v + 1 end } })

ns.Enemies.te_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.te_hitter = { name = "Cogneur", hp = 100,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }

local function deckOf(...)
  local d = {}
  for i, id in ipairs({ ... }) do d[i] = { id = id, up = false } end
  return d
end

-- Combat de test : main imposée (le reste en pioche), comme Sim/tests.lua.
local function setup(hand, opts)
  opts = opts or {}
  local deck = deckOf(unpack(hand))
  for _, id in ipairs(opts.extra or {}) do deck[#deck + 1] = { id = id, up = false } end
  local c = Combat.new({ seed = 7, class = opts.class or "rogue", hp = opts.hp or 60, maxHp = 60, deck = deck,
    encounter = opts.encounter or { "te_dummy" } })
  local all = {}
  for _, x in ipairs(c.hand) do all[#all + 1] = x end
  for _, x in ipairs(c.draw) do all[#all + 1] = x end
  c.hand, c.draw = {}, {}
  local byId = {}
  for _, x in ipairs(all) do byId[x.id] = byId[x.id] or {}; table.insert(byId[x.id], x) end
  for _, id in ipairs(hand) do c.hand[#c.hand + 1] = table.remove(byId[id]) end
  for _, list in pairs(byId) do for _, x in ipairs(list) do c.draw[#c.draw + 1] = x end end
  return c
end

local function power(c, def)
  local id = "te_pow_" .. tostring(#added + 1)
  card(id, def)
  c.player.powers[#c.player.powers + 1] = Card.new(id, false, 900 + #c.player.powers)
  return id
end

local function handIndex(c, id)
  for i, x in ipairs(c.hand) do if x.id == id then return i end end
end

-- Expédition du Rogue avec les zones débloquées (zones = N premières zones gagnées).
local function newExp(zones, seed, extra)
  local o = { seed = seed or 3, class = "rogue", unlocks = Meta.allUnlocked(7, zones or 0) }
  for k, v in pairs(extra or {}) do o[k] = v end
  return X.new(o)
end

-- Passe le choix de départ (bibelot).
local function skipStart(exp)
  if exp.phase == "start" then assert(X.act(exp, { "skipStartRelic" })) end
end

-- Entre dans un nœud de départ transformé en `kind` (étape `floor`) ; le combat est gagné aussitôt.
local function enter(exp, kind, floor)
  skipStart(exp)
  local id = X.choices(exp)[1][2]
  local node = exp.map.nodes[id]
  node.kind = kind
  if floor then node.floor = floor end
  assert(X.act(exp, { "path", id }))
end
local function winFight(exp)
  assert(exp.phase == "combat", "en combat")
  exp.combat.result = "won"
  assert(X.act(exp, { "endTurn" }))
  eq(exp.phase, "reward")
end

local function has(list, verb, arg)
  for _, a in ipairs(list) do if a[1] == verb and (arg == nil or a[2] == arg) then return true end end
  return false
end

---------------------------------------------------------------------------
-- 1. Rareté epic
---------------------------------------------------------------------------
test("rareté epic : au-dessus de rare, jamais dans les réserves ordinaires ni la progression", function()
  assert(Card.isEpic(Cards.te_epic_a) and not Card.isEpic(Cards.sinister_strike))
  eq(Meta.RARITY_ORDER.epic, Meta.RARITY_ORDER.rare + 1)
  assert(Meta.RARITY_ORDER.boss > Meta.RARITY_ORDER.epic)
  local exp = newExp(7)
  for _, id in ipairs(X.cardPool(exp)) do
    assert(Cards[id].rarity ~= "epic" and not Cards[id].variant, "réserve des récompenses : " .. id)
  end
  for _, id in ipairs(Card.pool("rogue")) do
    assert(Cards[id].rarity ~= "epic" and not Cards[id].variant, "Card.pool : " .. id)
  end
  for _, id in ipairs(Meta.classContent("rogue").cards) do
    assert(not Cards[id].zone and not Cards[id].variant, "progression : " .. id)
  end
  eq(Meta.zoneCards("rogue", "westfall")[1], "te_epic_a")
  eq(#Meta.zoneCards("rogue", "westfall"), 1)
  assert(not Card.collectible(Cards.te_variant_ss) and Card.collectible(Cards.te_epic_a))
end)

test("rareté epic : réserve des épiques = débloquées par zone, hors celle du deck", function()
  eq(#X.epicPool(newExp(0)), 0, "aucune zone gagnée")
  local p = X.epicPool(newExp(1))
  eq(#p, 1); eq(p[1], "te_epic_a")
  eq(#X.epicPool(newExp(5)), 5, "zones 1 à 5 : A, B, C, D, passive")
  local exp = newExp(2)
  X.addCard(exp, "te_epic_a")
  p = X.epicPool(exp)
  eq(#p, 1); eq(p[1], "te_epic_b", "l'épique du deck n'est pas reproposée")
end)

---------------------------------------------------------------------------
-- 2. Une seule épique ; 3. transformations
---------------------------------------------------------------------------
test("une seule épique : en prendre une autre remplace la précédente (améliorée ou non)", function()
  local exp = newExp(7)
  local n = #exp.deck
  X.addCard(exp, "te_epic_a")
  eq(#exp.deck, n + 1)
  exp.deck[#exp.deck].up = true
  X.addCard(exp, "te_epic_b")
  eq(#exp.deck, n + 1, "remplacée, pas ajoutée")
  local i = X.epicIndex(exp)
  eq(exp.deck[i].id, "te_epic_b"); eq(exp.deck[i].up, false, "la nouvelle arrive non améliorée")
  eq(exp.stats.epicReplaced, 1)
  eq(exp.epicReplaced.old, "te_epic_a"); eq(exp.epicReplaced.oldUp, true); eq(exp.epicReplaced.new, "te_epic_b")
  local count = 0
  for _, cd in ipairs(exp.deck) do if Card.isEpic(Cards[cd.id]) then count = count + 1 end end
  eq(count, 1)
end)

test("une seule épique : la copie de rencontre (dupe) refuse l'épique", function()
  local exp = newExp(7)
  X.addCard(exp, "te_epic_a")
  exp.select = { kind = "dupe" }
  exp.phase = "select"
  local i = X.epicIndex(exp)
  assert(not has(X.choices(exp), "select", i), "épique absente des choix")
  local ok, why = X.act(exp, { "select", i })
  assert(not ok); eq(why, "epic")
  assert(X.EVENT_REASONS.epic)
end)

test("transformations : appliquées à l'affichage et en combat, défaites quand l'épique part", function()
  local exp = newExp(7)
  eq(X.shownDeck(exp), exp.deck, "sans épique : le deck lui-même")
  exp.deck[1].up = true -- un Sinister Strike amélioré
  X.addCard(exp, "te_epic_a")
  local shown = X.shownDeck(exp)
  eq(#shown, #exp.deck)
  eq(shown[1].id, "te_variant_ss"); eq(shown[1].up, true, "hérite de l'amélioration"); eq(shown[1].from, "sinister_strike")
  eq(exp.deck[1].id, "sinister_strike", "le deck lui-même ne change pas")
  local feint
  for i, cd in ipairs(exp.deck) do if cd.id == "feint" then feint = i end end
  eq(shown[feint].id, "te_variant_feint")
  exp.deck[feint].up = true
  eq(X.shownDeck(exp)[feint].up, false, "variante sans amélioration : non améliorée")
  local c = Combat.new({ seed = 1, class = "rogue", hp = 50, deck = exp.deck, encounter = { "te_dummy" } })
  local ids = {}
  for _, pile in ipairs({ c.hand, c.draw }) do for _, inst in ipairs(pile) do ids[inst.id] = (ids[inst.id] or 0) + 1 end end
  eq(ids.sinister_strike, nil); eq(ids.te_variant_ss, 5); eq(ids.te_variant_feint, 3)
  -- l'épique remplacée (sans transformations) : tout revient
  X.addCard(exp, "te_epic_b")
  eq(X.shownDeck(exp)[1].id, "sinister_strike")
  -- retirée (marchand, rencontre) : tout revient
  X.addCard(exp, "te_epic_a")
  table.remove(exp.deck, X.epicIndex(exp))
  eq(X.shownDeck(exp), exp.deck)
end)

---------------------------------------------------------------------------
-- 4. L'épique se gagne : chute par élite selon la zone, marchand
---------------------------------------------------------------------------
-- Chance de chute imposée le temps de f (X.EPIC.drop.elite), remise ensuite même en cas d'échec.
local function withDrop(chances, f)
  local old = X.EPIC.drop.elite
  X.EPIC.drop.elite = chances
  local ok, err = pcall(f)
  X.EPIC.drop.elite = old
  if not ok then error(err, 0) end
end

test("départ : aucune épique offerte (elle se gagne) ; seul le bibelot de départ, puis la carte", function()
  local exp = newExp(7, 5)
  eq(exp.phase, "start")
  assert(exp.startRelics, "bibelot au départ (zones=7)")
  eq(exp.startEpics, nil); eq(exp.epicOffered, nil); eq(X.EPIC.start, nil); eq(X.EPIC.offerOn, nil)
  eq(X.epicIndex(exp), nil, "aucune épique dans le deck")
  eq(exp.rng.epic, nil, "aucun tirage d'épique au départ")
  local ch = X.choices(exp)
  assert(has(ch, "startRelic", 1) and has(ch, "skipStartRelic") and not has(ch, "pickEpic"))
  assert(not X.act(exp, { "pickEpic", 1 }), "pas d'épique au départ")
  assert(X.act(exp, { "startRelic", 1 }))
  eq(exp.phase, "map")
  -- sans bibelot de départ (zones=1) : la carte tout de suite
  eq(newExp(1, 6).phase, "map")
  -- épique imposée (simulation : epic=) : dans le deck dès le départ
  local ef = newExp(7, 6, { epic = "te_epic_c" })
  eq(ef.deck[X.epicIndex(ef)].id, "te_epic_c")
end)

test("chute par élite : table par rang de zone, 25 % à Westfall, +10 points par zone, 85 % à Blackrock", function()
  local t = X.EPIC.drop.elite
  eq(#t, 7)
  for rank = 1, 7 do
    assert(math.abs(t[rank] - (0.25 + 0.10 * (rank - 1))) < 1e-9, "rang " .. rank)
    local exp = newExp(0, 1, { zone = ns.Zone.ORDER[rank] })
    eq(X.zoneRank(exp), rank)
    eq(X.epicDropChance(exp, "elite"), t[rank])
    eq(X.epicDropChance(exp, "combat"), 0, "combat normal : jamais")
    eq(X.epicDropChance(exp, "boss"), 0, "boss : jamais")
  end
  -- table plus courte que la campagne : la dernière valeur au-delà
  withDrop({ 0.5 }, function()
    eq(X.epicDropChance(newExp(0, 1, { zone = "blackrock" }), "elite"), 0.5)
  end)
end)

-- n élites gagnées (une par graine, graines 1..n) dans la zone : nombre d'épiques tombées ; chaque chute est
-- vérifiée contre le premier tirage du flux « epic » de la graine.
local function dropsIn(zone, n, zones)
  local drops = 0
  for seed = 1, n do
    local exp = newExp(zones, seed, { zone = zone })
    local p = X.epicDropChance(exp, "elite")
    enter(exp, "elite")
    winFight(exp)
    local expected = Rng.float(Rng.stream(seed, "epic")) < p
    eq(exp.reward.epics ~= nil, expected, zone .. " graine " .. seed)
    if exp.reward.epics then
      drops = drops + 1
      eq(#exp.reward.epics, X.EPIC.choices)
      assert(exp.reward.cards and #exp.reward.cards > 0, "la récompense normale reste")
    end
  end
  return drops
end

test("chute par élite : graines fixées, zone 1 (Westfall) et zone 7 (Blackrock Mountain)", function()
  local n = 200
  local w = dropsIn("westfall", n, 7)
  local b = dropsIn("blackrock", n, 7)
  assert(w >= 0.15 * n and w <= 0.35 * n, "Westfall ≈ 25 % : " .. w .. " / " .. n)
  assert(b >= 0.75 * n and b <= 0.95 * n, "Blackrock ≈ 85 % : " .. b .. " / " .. n)
  -- mêmes graines, même résultat (tirage par le flux « epic » seul)
  eq(dropsIn("westfall", 40, 7), dropsIn("westfall", 40, 7))
end)

test("chute par élite : aucune épique débloquée = rien ne tombe, aucun tirage (zone 1 et zone 7)", function()
  for _, zone in ipairs({ "westfall", "blackrock" }) do
    for seed = 1, 20 do
      local exp = newExp(0, seed, { zone = zone })
      eq(#X.epicPool(exp), 0)
      enter(exp, "elite")
      winFight(exp)
      eq(exp.reward.epics, nil, zone)
      eq(exp.rng.epic, nil, "flux « epic » jamais créé")
    end
  end
  -- chance 100 % : rien non plus
  withDrop({ 1 }, function()
    local exp = newExp(0, 3)
    enter(exp, "elite")
    winFight(exp)
    eq(exp.reward.epics, nil)
  end)
end)

test("chute par élite : prendre (remplace celle du deck) ou garder l'actuelle ; combat normal : rien", function()
  withDrop({ 1 }, function()
    local exp = newExp(7, 5)
    skipStart(exp)
    enter(exp, "combat")
    winFight(exp)
    eq(exp.reward.epics, nil, "combat normal : rien")
    assert(X.act(exp, { "leave" }))
    -- sans épique dans le deck : l'élite en propose une
    enter(exp, "elite")
    winFight(exp)
    assert(exp.reward.epics, "élite : offre")
    assert(X.act(exp, { "pickEpic", 1 }))
    local mine = exp.deck[X.epicIndex(exp)].id
    eq(mine, exp.reward.epics[1])
    assert(X.act(exp, { "leave" }))
    for k = 1, 2 do
      enter(exp, "elite")
      winFight(exp)
      local r = exp.reward
      assert(r.epics, "élite " .. k .. " : offre")
      eq(#r.epics, X.EPIC.choices); eq(X.EPIC.choices, 1)
      assert(r.epics[1] ~= exp.deck[X.epicIndex(exp)].id, "pas celle du deck")
      assert(r.cards and #r.cards > 0, "la récompense normale reste")
      local ch = X.choices(exp)
      assert(has(ch, "pickEpic", 1) and has(ch, "skipEpic") and has(ch, "pickCard", 1))
      if k == 1 then
        assert(X.act(exp, { "skipEpic" }))
        eq(exp.deck[X.epicIndex(exp)].id, mine, "refusée : on garde l'actuelle")
      else
        exp.deck[X.epicIndex(exp)].up = true
        assert(X.act(exp, { "pickEpic", 1 }))
        eq(exp.deck[X.epicIndex(exp)].id, r.epics[1]); eq(exp.deck[X.epicIndex(exp)].up, false, "arrive non améliorée")
        eq(exp.epicReplaced.oldUp, true)
      end
      assert(not has(X.choices(exp), "pickEpic"))
      assert(X.act(exp, { "leave" }))
    end
    -- une seule épique débloquée, déjà dans le deck : rien à proposer
    local e1 = newExp(1, 6)
    X.addCard(e1, "te_epic_a")
    enter(e1, "elite")
    winFight(e1)
    eq(e1.reward.epics, nil)
  end)
end)

test("feu de camp : l'épique s'améliore au choix ; les améliorations au hasard l'évitent", function()
  local exp = newExp(7, 5)
  X.addCard(exp, "te_epic_a")
  local i = X.epicIndex(exp)
  assert(X.canUpgrade(exp, i))
  -- au hasard : toutes les autres cartes d'abord, jamais l'épique
  local n = X.upgradeRandom(exp, 99, Rng.stream(1, "t"))
  eq(n, #exp.deck - 1); eq(exp.deck[i].up, false)
  for _, cd in ipairs(exp.deck) do cd.up = false end
  skipStart(exp)
  local id = X.choices(exp)[1][2]
  exp.map.nodes[id].kind = "campfire"
  assert(X.act(exp, { "path", id }))
  assert(has(X.choices(exp), "upgrade", i), "épique proposée au feu de camp")
  assert(X.act(exp, { "upgrade", i }))
  eq(exp.deck[i].up, true)
end)

test("chute : un combat d'élite de rencontre compte aussi", function()
  local function hasFight()
    for _, ev in pairs(ns.Events) do
      for _, ch in ipairs(ev.choices) do
        for _, e in ipairs(ch.effects) do if e[1] == "fight" and e.kind == "elite" then return true end end
      end
    end
  end
  if not hasFight() then return end
  withDrop({ 1 }, function()
    local exp = newExp(7, 8)
    -- simulé : la récompense d'un combat d'élite de rencontre a le genre « elite »
    enter(exp, "elite")
    eq(exp.fight.kind, "elite")
    winFight(exp)
    assert(exp.reward.epics)
  end)
end)

test("marchand : une épique (prix élevé) à partir de la moitié du parcours, achat = remplacement", function()
  local old = X.EPIC.shop
  X.EPIC.shop = 1
  local exp = newExp(7, 9)
  enter(exp, "merchant", X.EPIC.shopFloor - 1)
  for _, it in ipairs(exp.shop.cards) do assert(not it.epic, "avant la moitié : aucune") end
  assert(X.act(exp, { "leave" }))
  local exp2 = newExp(7, 9)
  X.addCard(exp2, "te_epic_b")
  enter(exp2, "merchant", X.EPIC.shopFloor)
  local last = exp2.shop.cards[#exp2.shop.cards]
  assert(last.epic, "épique en vente"); eq(Cards[last.id].rarity, "epic")
  assert(last.id ~= "te_epic_b", "pas celle du deck")
  assert(last.price >= X.EPIC.price * (1 - X.PRICE_JITTER) - 1, "prix élevé")
  exp2.gold = 999
  assert(X.act(exp2, { "buyCard", #exp2.shop.cards }))
  eq(exp2.deck[X.epicIndex(exp2)].id, last.id)
  eq(exp2.stats.epicReplaced, 1)
  X.EPIC.shop = old
end)

---------------------------------------------------------------------------
-- 5. Innate, effets passifs du deck
---------------------------------------------------------------------------
test("Innate : dans la main de départ à la place d'une pioche (main de 5), toujours", function()
  for seed = 1, 30 do
    local deck = deckOf("sinister_strike", "sinister_strike", "sinister_strike", "sinister_strike", "feint",
      "feint", "feint", "backstab", "eviscerate", "te_innate", "sinister_strike", "feint")
    local c = Combat.new({ seed = seed, class = "rogue", hp = 50, deck = deck, encounter = { "te_dummy" } })
    eq(#c.hand, 5)
    assert(handIndex(c, "te_innate"), "Innate en main (graine " .. seed .. ")")
  end
  -- six Innate : cinq en main, la sixième sur le dessus de la pioche
  local deck = deckOf("te_innate", "te_innate", "te_innate", "te_innate", "te_innate", "te_innate", "feint", "feint")
  local c = Combat.new({ seed = 1, class = "rogue", hp = 50, deck = deck, encounter = { "te_dummy" } })
  eq(#c.hand, 5)
  for _, inst in ipairs(c.hand) do eq(inst.id, "te_innate") end
  eq(c.draw[#c.draw].id, "te_innate")
  eq(ns.Language.plateByKey("innate").word, "Innate")
  -- plaque « Epic » (en tête) à la place de « Power » sur une épique
  local Lg = ns.Language
  eq(Lg.plates[1].key, "epic")
  eq(Lg.plateWord(Lg.plateByKey("epic"), Cards.te_epic_a), "Epic")
  eq(Lg.plateWord(Lg.plateByKey("power"), Cards.te_epic_a), nil, "une épique ne dit pas « Power »")
  eq(Lg.plateWord(Lg.plateByKey("epic"), Cards.feint), nil)
  eq(ns.Language.plateWord(ns.Language.plateByKey("innate"), Cards.te_innate), "Innate")
end)

test("Innate : sans carte Innate, la pioche ne change pas", function()
  local deck = ns.Classes.rogue.deck
  local d = {}
  for i, id in ipairs(deck) do d[i] = { id = id, up = false } end
  local a = Combat.new({ seed = 4, class = "rogue", hp = 50, deck = d, encounter = { "te_dummy" } })
  local draw = {}
  for i = 1, #d do draw[i] = U.copyMap(d[i]) end
  local rng = Rng.stream(4, "draw")
  local list = {}
  for i = 1, #draw do list[i] = draw[i].id end
  Rng.shuffle(rng, list)
  -- main = les 5 dernières du mélange, dans l'ordre de tirage
  for k = 1, 5 do eq(a.hand[k].id, list[#list - k + 1]) end
end)

test("effet passif du deck : whileInDeck au début du combat, deckHooks actifs où que soit la carte", function()
  local deck = deckOf("feint", "feint", "feint", "feint", "feint", "feint", "te_deckpassive", "te_deckpassive")
  local c = Combat.new({ seed = 2, class = "rogue", hp = 50, deck = deck, encounter = { "te_dummy" } })
  eq(c.cls.teStart, 2, "une fois par exemplaire")
  eq(c.player.mana, Combat.BASE_MANA + 2, "deux exemplaires : +2 mana, même en pioche")
  assert(Save.isPlain(c), "combat sauvegardable avec ses passifs")
  local cl = Combat.clone(c)
  eq(#cl.passives, 2)
  local r = reload(c)
  Combat.endTurn(r)
  eq(r.player.mana, Combat.BASE_MANA + 2, "après rechargement")
  local c2 = Combat.new({ seed = 2, class = "rogue", hp = 50, deck = deckOf("feint", "feint"), encounter = { "te_dummy" } })
  eq(c2.passives, nil, "sans carte passive : rien")
  eq(c2.epic, nil, "sans épique : rien")
end)

-- Toutes les instances des piles d'un combat (pioche, main, défausse, consumées, recharges, pouvoirs).
local function allPiles(c)
  local out = {}
  for _, pile in ipairs({ c.draw, c.hand, c.discard, c.exhaust, c.player.powers }) do
    for _, inst in ipairs(pile) do out[#out + 1] = inst end
  end
  for _, cd in ipairs(c.cooldown) do out[#out + 1] = cd.card end
  return out
end

test("épique en combat : posée avant le premier tour, dans aucune pile, main de 5, une seule fois", function()
  for seed = 1, 20 do
    local deck = deckOf("sinister_strike", "sinister_strike", "sinister_strike", "feint", "feint", "te_passive",
      "backstab", "eviscerate")
    deck[6].up = true
    local c = Combat.new({ seed = seed, class = "rogue", hp = 50, deck = deck, encounter = { "te_dummy" } })
    assert(c.epic, "c.epic")
    eq(c.epic.id, "te_passive"); eq(c.epic.up, true, "amélioration gardée")
    eq(#c.hand, 5, "la main de départ ne change pas")
    eq(#c.hand + #c.draw, #deck - 1, "l'épique n'est pas piochée")
    for _, inst in ipairs(allPiles(c)) do assert(inst.id ~= "te_passive", "épique dans une pile") end
    eq(c.cls.teStart, 1, "whileInDeck une fois")
    eq(c.player.mana, Combat.BASE_MANA + 1, "deckHooks actifs dès le premier tour")
    eq(c.passives, nil, "l'épique n'est pas un passif ordinaire")
  end
  -- toute la partie : jamais piochée, même en vidant la pioche plusieurs fois
  local c = Combat.new({ seed = 3, class = "rogue", hp = 50, deck = deckOf("feint", "feint", "te_passive"),
    encounter = { "te_dummy" } })
  for _ = 1, 6 do
    Combat.endTurn(c)
    for _, inst in ipairs(allPiles(c)) do assert(inst.id ~= "te_passive") end
  end
  eq(c.player.mana, Combat.BASE_MANA + 1)
end)

test("épique en combat : ses crochets (deckHooks puis hooks) passent après pouvoirs, bibelots et affixes", function()
  local order = {}
  card("te_epic_order", { class = "rogue", zone = "steppes", rarity = "epic", name = "Order", effects = {},
    text = "Epic.\nTest.", type = "power",
    deckHooks = { teV = function(c, src, v) order[#order + 1] = "deck" return v + 1 end,
      teN = function(c, src) order[#order + 1] = "deckN" end },
    hooks = { teV = function(c, src, v) order[#order + 1] = "hooks" return v * 10 end } })
  local c = Combat.new({ seed = 1, class = "rogue", hp = 50, deck = deckOf("feint", "feint", "te_epic_order"),
    encounter = { "te_dummy" } })
  power(c, { name = "P", type = "power", effects = {}, hooks = {
    teV = function(c, src, v) order[#order + 1] = "power" return v * 2 end,
    teN = function(c, src) order[#order + 1] = "powerN" end } })
  ns.Relics.te_relic = { name = "R", hooks = { teV = function(c, src, v) order[#order + 1] = "relic" return v + 100 end } }
  c.relics[#c.relics + 1] = "te_relic"
  -- (3 × 2 + 100 + 1) × 10
  eq(Combat.modify(c, "teV", 3), 1070)
  eq(table.concat(order, ","), "power,relic,deck,hooks")
  order = {}
  local stop, src = Combat.fire(c, "teN")
  eq(stop, false); eq(table.concat(order, ","), "powerN,deckN")
  ns.Relics.te_relic = nil
  -- src = c.epic ; clone et sauvegarde gardent l'épique
  local cl = Combat.clone(c)
  eq(cl.epic.id, "te_epic_order")
  local r = reload(c)
  eq(r.epic.id, "te_epic_order"); eq(Combat.modify(r, "teV", 3), 70, "(3 × 2 + 1) × 10 sans le bibelot retiré")
end)

test("épique en combat : son crochet « allow » interdit des cartes ; Hex, défausse et retraits ne la touchent pas", function()
  local c = setup({ "backstab", "feint" }, { extra = { "te_passive" } })
  -- setup refait la main : l'épique n'est pas dans les piles
  for _, inst in ipairs(allPiles(c)) do assert(inst.id ~= "te_passive") end
  local ok, why = Combat.canPlay(c, 1)
  assert(not ok); eq(why, "forbidden")
  assert(Combat.canPlay(c, 2))
  -- défausse de toute la main, fin de tour, retrait des pouvoirs : l'épique reste
  Combat.endTurn(c)
  for i = #c.player.powers, 1, -1 do Combat.removePower(c, i, "test") end
  eq(c.epic.id, "te_passive")
  for _, inst in ipairs(allPiles(c)) do assert(inst.id ~= "te_passive") end
end)

---------------------------------------------------------------------------
-- 6. Points d'accroche de classe
---------------------------------------------------------------------------
test("onHeal : soin effectif et surplus", function()
  local c = setup({ "feint" }, { hp = 55 })
  local got
  power(c, { name = "P", type = "power", effects = {}, hooks = {
    onHeal = function(c, src, n, surplus) got = { n, surplus } end } })
  Combat.heal(c, c.player, 8)
  eq(got[1], 5); eq(got[2], 3)
  got = nil
  Combat.heal(c, c.player, 4)
  eq(got[1], 0, "à pleine vie"); eq(got[2], 4)
end)

test("onDamageDealt : PV réellement perdus, contexte de la carte (nil sans carte)", function()
  local c = setup({ "sinister_strike" })
  local got = {}
  power(c, { name = "P", type = "power", effects = {}, hooks = {
    onDamageDealt = function(c, src, t, loss, ctx) got[#got + 1] = { t, loss, ctx } end } })
  c.enemies[1].block = 2
  assert(Combat.play(c, 1, 1))
  eq(#got, 1); eq(got[1][1], c.enemies[1]); eq(got[1][2], 3, "absorbés non comptés"); eq(got[1][3].card.id, "sinister_strike")
  Combat.dealDamage(c, c.player, c.enemies[1], 4)
  eq(got[2][2], 4); eq(got[2][3], nil, "coup sans carte")
  Combat.dealDamage(c, nil, c.enemies[1], 4)
  eq(#got, 2, "DoT : pas un coup du joueur")
end)

test("onParry : une charge consommée, avec l'attaquant", function()
  local c = setup({ "feint" }, { encounter = { "te_hitter" } })
  local got
  power(c, { name = "P", type = "power", effects = {}, hooks = {
    onParry = function(c, src, enemy, prevented, left) got = { enemy, prevented, left } end } })
  assert(Combat.play(c, 1))
  Combat.endTurn(c)
  eq(got[1], c.enemies[1]); eq(got[2], 8); eq(got[3], 0)
end)

test("trapLaunch : la Trap demande une cible, part tout de suite, sans emplacement", function()
  local c = setup({ "counterattack", "freezing_trap" }, { class = "hunter", extra = { "arcane_shot", "arcane_shot",
    "arcane_shot" } })
  eq(Combat.needsTarget(c.hand[1], c), false, "sans le crochet : posée")
  local trig
  power(c, { name = "P", type = "power", effects = {}, hooks = {
    trapLaunch = function(c, src, v, d) return true end,
    onTrapTriggered = function(c, src, inst, e, why) trig = { inst.id, e, why } end } })
  eq(Combat.needsTarget(c.hand[1], c), true)
  eq(Combat.needsTarget(c.hand[1]), false, "sans combat : la définition seule")
  local plays = Combat.legalPlays(c)
  local targeted = false
  for _, p in ipairs(plays) do if p[1] == 1 and p[2] == 1 then targeted = true end end
  assert(targeted, "coup légal avec cible")
  assert(not Combat.play(c, 1, nil), "cible exigée")
  local hp = c.enemies[1].hp
  -- zone des pièges pleine : la Trap lancée reste jouable
  c.traps = { { card = Card.new("counterattack", false, 500) }, { card = Card.new("counterattack", false, 501) },
    { card = Card.new("counterattack", false, 502) } }
  assert(Combat.canPlay(c, 1))
  assert(Combat.play(c, 1, 1))
  eq(c.enemies[1].hp, hp - 13, "déclenchée tout de suite")
  eq(#c.traps, 3, "aucun emplacement pris")
  eq(trig[1], "counterattack"); eq(trig[2], c.enemies[1]); eq(trig[3], "launch")
end)

test("resCap : plafond de la ressource modifiable", function()
  local c = setup({ "feint" })
  eq(Combat.resCap(c), 5)
  Combat.gainRes(c, 9)
  eq(c.player.res, 5)
  power(c, { name = "P", type = "power", effects = {}, hooks = { resCap = function(c, src, v) return 10 end } })
  eq(Combat.resCap(c), 10)
  Combat.gainRes(c, 9)
  eq(c.player.res, 10)
end)

test("stealthBreak : faux = la première Attack profite de Stealth sans le retirer", function()
  local c = setup({ "backstab", "backstab" })
  power(c, { name = "P", type = "power", effects = {}, hooks = { stealthBreak = function() return false end } })
  local hp = c.enemies[1].hp
  assert(Combat.play(c, 1, 1))
  eq(c.enemies[1].hp, hp - 10, "Stealth: deal 7 more")
  eq(c.player.st.stealth, 1, "Stealth gardé")
  assert(Combat.play(c, 1, 1))
  eq(c.enemies[1].hp, hp - 20, "deuxième ouverture")
  -- sans le crochet : consommé (règle du Rogue)
  local c2 = setup({ "backstab", "backstab" })
  assert(Combat.play(c2, 1, 1))
  eq(c2.player.st.stealth, nil)
end)

test("familier : petAll frappe tous les ennemis, petAbsent supprime ses attaques", function()
  local c = setup({ "arcane_shot" }, { class = "hunter", encounter = { "te_dummy", "te_dummy" } })
  power(c, { name = "P", type = "power", effects = {}, hooks = { petAll = function() return true end } })
  local h1, h2 = c.enemies[1].hp, c.enemies[2].hp
  ns.Hunter.petAttack(c, "card")
  eq(c.enemies[1].hp, h1 - ns.Hunter.PET_BASE); eq(c.enemies[2].hp, h2 - ns.Hunter.PET_BASE)
  eq(c.player.res, 1, "+1 Frenzy une seule fois")
  local c2 = setup({ "arcane_shot" }, { class = "hunter" })
  power(c2, { name = "P", type = "power", effects = {}, hooks = { petAbsent = function() return true end } })
  assert(not ns.Hunter.petPresent(c2))
  local h = c2.enemies[1].hp
  assert(Combat.play(c2, 1, 1))
  eq(c2.enemies[1].hp, h - 3, "Pet attacks : rien")
  Combat.endTurn(c2)
  eq(c2.enemies[1].hp, h - 3, "pas d'attaque automatique")
  eq(c2.player.res, 0)
end)

test("afterCast : carte Cast résolue, incantée ou instantanée ; onCastResolved inchangé", function()
  local c = setup({ "fireball", "fireball" }, { class = "mage" })
  local after, resolved = {}, 0
  power(c, { name = "P", type = "power", effects = {}, hooks = {
    afterCast = function(c, src, inst, ctx, instant) after[#after + 1] = { inst.id, ctx.def.cast, instant } end,
    onCastResolved = function() resolved = resolved + 1 end } })
  c.player.st.instant = 1
  assert(Combat.play(c, 1, 1))
  eq(#after, 1); eq(after[1][3], true, "instantanée"); eq(resolved, 0)
  assert(Combat.play(c, 1, 1))
  eq(#after, 1, "incantation tenue")
  Combat.endTurn(c)
  eq(#after, 2); eq(after[2][3], false); eq(resolved, 1)
end)

test("onDotTick : chaque tick de DoT", function()
  local c = setup({ "feint" })
  local got
  power(c, { name = "P", type = "power", effects = {}, hooks = { onDotTick = function(c, src, u, n) got = { u, n } end } })
  Combat.applyStatus(c, c.enemies[1], "pain", 4)
  Combat.tickDot(c, c.enemies[1])
  eq(got[1], c.enemies[1]); eq(got[2], 4)
end)

test("rejouer / copier : crochet replay et Combat.copyCard", function()
  local c = setup({ "sinister_strike", "sinister_strike" })
  power(c, { name = "P", type = "power", effects = {}, hooks = {
    replay = function(c, src, v, inst) return inst.id == "sinister_strike" and v + 1 or v end } })
  local hp = c.enemies[1].hp
  assert(Combat.play(c, 1, 1))
  eq(c.enemies[1].hp, hp - 10, "jouée deux fois")
  eq(c.player.res, 2)
  local ctx = Combat.copyCard(c, c.hand[1], c.enemies[1])
  assert(ctx.copy)
  eq(c.enemies[1].hp, hp - 15); eq(#c.hand, 1, "la carte copiée ne bouge pas")
end)

test("blockKeep : fraction et plafond de l'Absorb gardée", function()
  local c = setup({ "feint" })
  power(c, { name = "P", type = "power", effects = {}, hooks = {
    blockKeep = function(c, src, v, block) return math.max(v, math.min(15, math.floor(block / 2))) end } })
  c.player.block = 20
  Combat.endTurn(c)
  eq(c.player.block, 10, "la moitié")
  c.player.block = 40
  Combat.endTurn(c)
  eq(c.player.block, 15, "plafond")
end)

test("canGainBlock : faux = aucun Absorb gagné", function()
  local c = setup({ "defend" }, { class = "warrior" })
  power(c, { name = "P", type = "power", effects = {}, hooks = { canGainBlock = function() return false end } })
  assert(Combat.play(c, 1))
  eq(c.player.block, 0)
end)

test("attackMult : multiplicateur des coups des Attacks seulement, arrondi à l'inférieur", function()
  local c = setup({ "strike", "strike" }, { class = "warrior" })
  power(c, { name = "P", type = "power", effects = {}, hooks = { attackMult = function(c, src, v) return v * 1.5 end } })
  local hp = c.enemies[1].hp
  assert(Combat.play(c, 1, 1))
  eq(c.enemies[1].hp, hp - 9)
  Combat.applyStatus(c, c.player, "force", 1)
  assert(Combat.play(c, 1, 1))
  eq(c.enemies[1].hp, hp - 9 - 10, "(6 + 1) × 1,5 = 10")
  eq(Combat.calcDamage(c, c.player, c.enemies[1], 6, nil), 7, "coup sans carte : inchangé")
end)

---------------------------------------------------------------------------
-- 7. Sauvegarde, simulation
---------------------------------------------------------------------------
test("sauvegarde : expédition v5 en cours migrée en v8, puis jouable (chute d'épique aux élites)", function()
  local exp = newExp(7, 11)
  skipStart(exp)
  exp.version = 5
  local db = Save.new()
  db.current = reload(exp)
  local out = Save.migrate(db)
  local m = out.current
  assert(m, "gardée")
  eq(m.version, X.VERSION); eq(X.VERSION, 8); eq(m.epicOffered, nil); eq(m.startEpics, nil)
  assert(Save.validate(out))
  withDrop({ 1 }, function()
    enter(m, "elite")
    winFight(m)
  end)
  assert(m.reward.epics, "offre")
  local again = reload(m)
  assert(Save.validateExpedition(again))
  assert(X.act(again, { "pickEpic", 1 }))
  eq(again.deck[X.epicIndex(again)].id, again.reward.epics[1])
end)

-- État v6 arrêté sur l'offre d'épique de l'ancienne règle (étape 1, phase « start »), avec ou sans bibelot de
-- départ à choisir ensuite.
local function oldStartState(seed, zones)
  local exp = newExp(zones, seed)
  exp.version = 6
  exp.phase = "start"
  exp.startEpics = { "te_epic_a", "te_epic_b", "te_epic_c" }
  exp.epicOffered = true
  return exp
end

test("sauvegarde : v6 arrêtée sur l'offre d'épique de l'étape 1 rechargée en v7 sans erreur", function()
  -- sans bibelot de départ : l'offre disparaît, la carte tout de suite
  local db = Save.new()
  db.current = reload(oldStartState(13, 1))
  eq(db.current.startRelics, nil)
  local out, note = Save.migrate(db)
  local m = out.current
  assert(m, "gardée, pas en quarantaine : " .. tostring(note))
  eq(#out.quarantine, 0)
  eq(m.version, X.VERSION); eq(m.phase, "map")
  eq(m.startEpics, nil); eq(m.startEpicPicked, nil); eq(m.epicOffered, nil); eq(X.epicIndex(m), nil)
  assert(Save.validate(out))
  assert(has(X.choices(m), "path"))
  enter(m, "combat")
  eq(m.phase, "combat")
  -- avec le bibelot de départ encore à choisir : il reste, l'épique part
  db = Save.new()
  db.current = reload(oldStartState(13, 7))
  assert(db.current.startRelics)
  out = Save.migrate(db)
  m = out.current
  assert(m, "gardée")
  eq(m.phase, "start"); eq(m.startEpics, nil)
  assert(Save.validate(out))
  local ch = X.choices(m)
  assert(has(ch, "startRelic", 1) and not has(ch, "pickEpic"))
  assert(X.act(m, { "startRelic", 1 }))
  eq(m.phase, "map")
  -- une épique déjà prise au départ (v6) reste dans le deck
  local taken = newExp(7, 14)
  skipStart(taken)
  X.addCard(taken, "te_epic_b")
  taken.version, taken.startEpicPicked, taken.epicOffered = 6, "te_epic_b", true
  db = Save.new()
  db.current = reload(taken)
  m = Save.migrate(db).current
  eq(m.deck[X.epicIndex(m)].id, "te_epic_b"); eq(m.startEpicPicked, nil); eq(m.epicOffered, nil)
end)

test("sauvegarde : v6 de l'ancienne règle (épique dans la pioche d'un combat en cours) reste jouable", function()
  -- combat sauvegardé par l'ancien socle : l'épique est une carte de la pioche ; il se termine tel quel
  local exp = newExp(7, 12)
  skipStart(exp)
  X.addCard(exp, "te_epic_b")
  enter(exp, "combat")
  local c = exp.combat
  assert(c.epic and c.epic.id == "te_epic_b")
  c.draw[#c.draw + 1] = Card.new("te_epic_b", false, 777)
  c.epic = nil
  local r = reload(exp)
  assert(Save.validateExpedition(r))
  for _ = 1, 3 do assert(X.act(r, { "endTurn" })) if r.phase ~= "combat" then break end end
  -- le combat suivant pose l'épique comme une règle
  r.combat.result = "won"
  X.act(r, { "endTurn" })
  assert(X.act(r, { "leave" }))
  enter(r, "combat")
  eq(r.combat.epic.id, "te_epic_b")
  for _, inst in ipairs(allPiles(r.combat)) do assert(inst.id ~= "te_epic_b") end
end)

test("simulation : epic=<id> imposée et jamais remplacée ; sans option, l'épique se gagne ; epic=none", function()
  local rec, exp = ns.SimExpedition.play({ seed = 3, class = "rogue", epic = "te_epic_a", zones = 7 })
  eq(exp.deck[X.epicIndex(exp)].id, "te_epic_a")
  for _, p in ipairs(rec.picks) do assert(not (Cards[p] and Cards[p].rarity == "epic"), "aucune autre épique prise") end
  -- sans option, sans marchand d'épiques : une épique si et seulement si une élite est gagnée (chance 100 %)
  local oldShop = X.EPIC.shop
  X.EPIC.shop = 0
  local ok, err = pcall(withDrop, { 1 }, function()
    local got = 0
    for seed = 1, 6 do
      local _, e = ns.SimExpedition.play({ seed = seed, class = "rogue", zones = 4 })
      eq(X.epicIndex(e) ~= nil, e.stats.elites > 0, "graine " .. seed)
      if X.epicIndex(e) then got = got + 1 end
    end
    assert(got > 0, "des épiques gagnées")
  end)
  -- chance nulle : aucune épique
  if ok then
    ok, err = pcall(withDrop, { 0 }, function()
      local _, e = ns.SimExpedition.play({ seed = 2, class = "rogue", zones = 7 })
      eq(X.epicIndex(e), nil)
    end)
  end
  X.EPIC.shop = oldShop
  if not ok then error(err, 0) end
  local _, en = ns.SimExpedition.play({ seed = 4, class = "rogue", zones = 7, epic = "none" })
  eq(X.epicIndex(en), nil, "epic=none : aucune épique")
  eq(ns.SimExpedition.epicRating({ class = "rogue", deck = {} }, "te_epic_a"), ns.SimExpedition.EPIC_RATING)
end)

for _, id in ipairs(added) do Cards[id] = nil end
for id, d in pairs(realRogue) do Cards[id] = d end
for id, d in pairs(realHunter) do Cards[id] = d end
ns.Enemies.te_dummy, ns.Enemies.te_hitter = nil, nil

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
