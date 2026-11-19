-- Tests des sept cartes épiques du Druide (docs/classes/druid.md, § 5) : cas nominaux, cas limites, paliers +1
-- à +3, mots de règle et leur à-côté. L'épique est posée dans le deck du combat (règle en jeu, c.epic).
-- Usage : lua5.1 Sim/tests_epic_druid.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
if jit and jit.opt then pcall(jit.opt.start, "maxtrace=65535", "maxmcode=262144") end
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Meta, Save, Combat, Card, D, L = ns.Expedition, ns.Meta, ns.Save, ns.Combat, ns.Card, ns.Druid, ns.Language

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

local Cards = ns.Cards
local E = ns.DruidEpic
local EPICS = { "furor", "mark_of_ursol", "eclipse", "king_of_the_jungle", "lifebloom", "owlkin_frenzy",
  "heart_of_the_wild" }
local ZONES = { "westfall", "duskwood", "wetlands", "stranglethorn", "swamp", "steppes", "blackrock" }

ns.Enemies.de_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.de_hitter = { name = "Cogneur", hp = 100,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }
ns.Enemies.de_flurry = { name = "Rafale", hp = 100,
  moves = { hit = { name = "Rafale", intent = "attack", actions = { { "attack", 3, times = 4 } } } }, pattern = { "hit" } }
ns.Enemies.de_double = { name = "Doublé", hp = 100,
  moves = { hit = { name = "Doublé", intent = "attack", actions = { { "attack", 3 }, { "attack", 3 } } } },
  pattern = { "hit" } }

local function deckOf(list)
  local d = {}
  for i, id in ipairs(list) do
    if type(id) == "table" then d[i] = { id = id[1], up = id[2] } else d[i] = { id = id, up = false } end
  end
  return d
end

-- Combat de test : main imposée (le reste en pioche : Skull Bash, sans forme), épique (id ou { id, palier }).
local FILL = { "skull_bash", "skull_bash", "skull_bash", "skull_bash", "skull_bash", "skull_bash" }
local function setup(hand, opts)
  opts = opts or {}
  local list = {}
  for _, id in ipairs(hand) do list[#list + 1] = id end
  for _, id in ipairs(opts.extra or FILL) do list[#list + 1] = id end
  if opts.epic then list[#list + 1] = opts.epic end
  local c = Combat.new({ seed = 7, class = "druid", hp = opts.hp or 60, maxHp = 60, deck = deckOf(list),
    encounter = opts.encounter or { "de_dummy" }, relics = opts.relics, stats = true })
  local all = {}
  for _, x in ipairs(c.hand) do all[#all + 1] = x end
  for _, x in ipairs(c.draw) do all[#all + 1] = x end
  c.hand, c.draw = {}, {}
  local byId = {}
  for _, x in ipairs(all) do byId[x.id] = byId[x.id] or {}; table.insert(byId[x.id], x) end
  for _, id in ipairs(hand) do
    local key = type(id) == "table" and id[1] or id
    c.hand[#c.hand + 1] = assert(table.remove(byId[key] or {}), "carte absente : " .. key)
  end
  for _, l in pairs(byId) do for _, x in ipairs(l) do c.draw[#c.draw + 1] = x end end
  c.player.mana = 9
  return c
end

local function idx(c, id)
  for i, x in ipairs(c.hand) do if x.id == id then return i end end
  error("pas en main : " .. id)
end
local function play(c, id, t, o)
  local ok, why = Combat.play(c, idx(c, id), t, o)
  assert(ok, "jeu refusé : " .. id .. " (" .. tostring(why) .. ")")
end
local function give(c, id, up)
  local inst = Card.new(id, up, c.nextUid)
  c.nextUid = c.nextUid + 1
  c.hand[#c.hand + 1] = inst
  Combat.listenCard(c, id)
  return inst
end
local function inPiles(c, id)
  for _, pile in ipairs({ c.hand, c.draw, c.discard, c.exhaust }) do
    for _, x in ipairs(pile) do if x.id == id then return true end end
  end
  return false
end
local function dealt(e) return e.maxHp - e.hp end
local function n(t, k) return t[k + 1] end -- nombre du palier k (0 à 3)

---------------------------------------------------------------------------
-- Les sept cartes
---------------------------------------------------------------------------
test("sept épiques : une par zone, rareté epic, Power sans coût, « Epic. » puis une clause, à chaque palier", function()
  local BASE = {
    furor = "Form changes: Primal 2.", mark_of_ursol = "Bear strikes: Ironfur 50%.",
    eclipse = "Cast cards: Lunar 5.", king_of_the_jungle = "Surge cards: Predator 1.",
    lifebloom = "Each Regen heal: Bloom 1.", owlkin_frenzy = "When hit: Moonfury 1.",
    heart_of_the_wild = "Forms: Kinship 3.",
  }
  for i, id in ipairs(EPICS) do
    local d = assert(Cards[id], id)
    eq(d.class, "druid", id); eq(d.zone, ZONES[i], id); eq(d.rarity, "epic", id); eq(d.epic, true, id)
    eq(d.type, "power", id); eq(d.cost, 0, id); eq(d.level, nil, id); eq(d.form, nil, id .. " : sans forme")
    assert(Card.isEpic(d) and Card.collectible(d), id)
    assert(d.deckHooks, id .. " : règle en jeu")
    eq(d.text, "Epic.\n" .. BASE[id], id)
    eq(Card.tiers(id), 3, id)
    for k = 1, 3 do
      local t = Card.defById(id, k).text
      assert(t:find("^Epic%.\n[^\n]+$"), id .. "+" .. k .. " : deux lignes (" .. t .. ")")
    end
    eq(Meta.zoneCards("druid", ZONES[i])[1], id)
    eq(#Meta.zoneCards("druid", ZONES[i]), 1, id)
  end
  for _, id in ipairs(Card.pool("druid", true)) do
    assert(Cards[id].rarity ~= "epic", "réserve : " .. id)
  end
end)

test("épique : ni piochée ni en main ; combat sauvegardable et clonable ; Druid.epic", function()
  for _, id in ipairs(EPICS) do
    for seed = 1, 3 do
      local c = Combat.new({ seed = seed, class = "druid", hp = 50, deck = deckOf({ "wrath", "thick_hide", id }),
        encounter = { "de_dummy" } })
      assert(not inPiles(c, id), id .. " dans les piles")
      eq(D.epic(c), id)
      assert(Save.isPlain(c), id .. " : sauvegardable")
      local cl = Combat.clone(c)
      Combat.endTurn(cl)
      Combat.endTurn(c)
      assert(not inPiles(c, id), id .. " piochée au tour 2")
    end
  end
end)

---------------------------------------------------------------------------
-- Westfall — Furor
---------------------------------------------------------------------------
test("Furor : +1 réserve par changement de forme, N fois par tour (entrée dans la première forme comprise)", function()
  local c = setup({ "wrath", "thick_hide", "shred", "maul", "wrath" }, { epic = "furor" })
  play(c, "wrath", 1)        -- sans forme -> Moonkin : +1 (épique), +1 (carte)
  eq(c.player.res, 2)
  play(c, "thick_hide")      -- Moonkin -> Bear : +1
  eq(c.player.res, 3)
  eq(n(E.primal, 0), 2)
  play(c, "shred", 1)        -- Bear -> Cat : 3e changement, rien ; +1 de la carte
  eq(c.player.res, 4)
  play(c, "wrath", 1)        -- Cat -> Moonkin : rien
  eq(c.player.res, 5)
  -- tour suivant : le compte repart
  Combat.endTurn(c)
  local r = c.player.res
  give(c, "maul")
  play(c, "maul", 1)         -- Moonkin -> Bear : +1 avant la frappe
  assert(c.player.res >= math.min(5, r + 1), "compte remis à zéro au tour suivant")
end)

test("Furor : une carte de la forme active ou sans forme ne change rien ; paliers 3 / 4 / 5 changements", function()
  local c = setup({ "thick_hide", "thick_hide", "skull_bash" }, { epic = "furor" })
  play(c, "thick_hide")
  eq(c.player.res, 1)
  play(c, "thick_hide")
  eq(c.player.res, 1, "même forme")
  play(c, "skull_bash", 1)
  eq(c.player.res, 1, "sans forme")
  for k = 1, 3 do
    local u = setup({ "wrath", "thick_hide", "rejuvenation", "tigers_fury", "thick_hide", "wrath" },
      { epic = { "furor", k } })
    u.player.mana = 20
    play(u, "rejuvenation")  -- Tree : +1
    play(u, "thick_hide")    -- Bear
    play(u, "tigers_fury")   -- Cat (+1 de la carte)
    play(u, "wrath", 1)      -- Moonkin (+1 de la carte)
    play(u, "thick_hide")    -- Bear
    eq(u.player.res, math.min(5, n(E.primal, k) + 2), "Furor+" .. k)
  end
end)

---------------------------------------------------------------------------
-- Duskwood — Mark of Ursol
---------------------------------------------------------------------------
test("Mark of Ursol : chaque frappe de l'ours donne N % de ses dégâts en Absorb, arrondi à l'inférieur", function()
  local c = setup({ "maul" }, { epic = "mark_of_ursol" })
  c.player.res = 2
  play(c, "maul", 1)         -- 4, puis frappe de 1 + 2 = 3 : 1 Absorb (50 %)
  eq(dealt(c.enemies[1]), 4 + D.STRIKE_BASE + 2)
  eq(c.player.block, math.floor((D.STRIKE_BASE + 2) * n(E.ironfur, 0) / 100))
  -- frappe de fin de tour (Bear) : 1 + 3
  local b = c.player.block
  Combat.endPlayerTurn(c)
  eq(c.player.block, b + math.floor((D.STRIKE_BASE + 3) * n(E.ironfur, 0) / 100), "frappe de fin de tour")
  for k = 1, 3 do
    local u = setup({ "maul" }, { epic = { "mark_of_ursol", k } })
    u.player.res = 3
    play(u, "maul", 1)
    eq(u.player.block, math.floor((D.STRIKE_BASE + 3) * n(E.ironfur, k) / 100), "Ironfur+" .. k)
  end
end)

test("Mark of Ursol : Mangle (une frappe par point) donne l'Absorb de chaque frappe", function()
  local c = setup({ "mangle" }, { epic = { "mark_of_ursol", 2 } })
  c.player.res = 3
  play(c, "mangle", 1)       -- trois frappes à 1 + 3 = 4 : 3 × 4 Absorb (100 %)
  eq(c.player.block, 3 * (D.STRIKE_BASE + 3))
end)

---------------------------------------------------------------------------
-- Wetlands — Eclipse
---------------------------------------------------------------------------
test("Eclipse : à N en réserve, un Cast Moonkin se résout tout de suite, en Moonkin, avec le bonus des Charges", function()
  local N = n(E.lunar, 0)
  local c = setup({ "thick_hide", "starfire" }, { epic = "eclipse" })
  play(c, "thick_hide")
  c.player.res = N
  play(c, "starfire", 1)
  eq(c.player.cast, nil, "pas d'incantation")
  eq(c.cls.form, "moonkin")
  eq(dealt(c.enemies[1]), 24 + N, "Starfire + Charges")
  -- sous N : incantation ordinaire
  local u = setup({ "starfire" }, { epic = "eclipse" })
  u.player.res = N - 1
  play(u, "starfire", 1)
  assert(u.player.cast, "incantation")
  eq(dealt(u.enemies[1]), 0)
end)

test("Eclipse : Instant non consommé ; un Cast Tree (Healing Touch) n'est pas concerné ; Hurricane à tous", function()
  local c = setup({ "healing_touch", "hurricane" }, { epic = "eclipse", encounter = { "de_dummy", "de_dummy" } })
  c.player.res = 5
  Combat.applyStatus(c, c.player, "instant", 1)
  play(c, "hurricane")
  eq(c.player.st.instant, 1, "Instant gardé")
  eq(dealt(c.enemies[1]), 15 + 5); eq(dealt(c.enemies[2]), 15 + 5)
  c.player.res = 5
  play(c, "healing_touch")   -- Tree : l'Instant le fait partir, pas l'épique
  eq(c.player.st.instant, nil, "Instant consommé par le Cast Tree")
end)

test("Eclipse : paliers (seuil 4, 4, 3 ; Solar : 3 de plus par coup)", function()
  for k = 1, 3 do
    local N, more = n(E.lunar, k), n(E.solar, k)
    local c = setup({ "starfire" }, { epic = { "eclipse", k } })
    c.player.res = N
    play(c, "starfire", 1)
    eq(c.player.cast, nil, "Eclipse+" .. k)
    eq(dealt(c.enemies[1]), 24 + N + more, "Eclipse+" .. k)
    eq(c.cls.eclipse, nil, "marque retirée")
  end
  eq(Card.defById("eclipse", 2).text, "Epic.\nCast cards: Solar 4.")
end)

---------------------------------------------------------------------------
-- Stranglethorn Vale — King of the Jungle
---------------------------------------------------------------------------
test("King of the Jungle : le Surge compte tout, puis N revient à la réserve après la carte", function()
  local c = setup({ "ferocious_bite", "starsurge" }, { epic = "king_of_the_jungle" })
  c.player.res = 3
  play(c, "ferocious_bite", 1)
  eq(dealt(c.enemies[1]), 4 + 4 * 3, "toute la réserve comptée")
  eq(c.player.res, n(E.predator, 0))
  -- Starsurge en Moonkin : la réserve rendue arrive après le coup (aucun bonus de Moonkin sur la carte)
  c.player.res = 2
  local before = dealt(c.enemies[1])
  play(c, "starsurge", 1)
  eq(dealt(c.enemies[1]) - before, 7 * 2, "pas de bonus des Charges")
  eq(c.player.res, n(E.predator, 0))
end)

test("King of the Jungle : jamais plus que le montant ; Apex (+2, +3) pioche au premier Surge du tour", function()
  local c = setup({ "ferocious_bite" }, { epic = { "king_of_the_jungle", 1 } })
  c.player.res = 1
  play(c, "ferocious_bite", 1)
  eq(c.player.res, 1, "1 dépensé : 1 revient (pas 2)")
  for k = 2, 3 do
    local u = setup({ "ferocious_bite", "rip" }, { epic = { "king_of_the_jungle", k } })
    u.player.res = 4
    local hand = #u.hand
    play(u, "ferocious_bite", 1)
    eq(#u.hand, hand - 1 + n(E.apex, k), "pioche au premier Surge")
    eq(u.player.res, n(E.predator, k))
    hand = #u.hand
    play(u, "rip", 1)
    eq(#u.hand, hand - 1, "rien au deuxième")
  end
end)

---------------------------------------------------------------------------
-- Swamp of Sorrows — Lifebloom
---------------------------------------------------------------------------
test("Lifebloom : chaque tic de Regen donne N à la réserve, même à PV pleins", function()
  local c = setup({ "rejuvenation" }, { epic = "lifebloom", hp = 60 })
  play(c, "rejuvenation")
  eq(c.player.res, 0)
  Combat.endTurn(c)            -- Tree : Regen 4 + 1 ; tic au début du tour
  eq(c.player.hp, 60)
  eq(c.player.res, n(E.bloom, 0), "à PV pleins")
  Combat.endTurn(c)
  eq(c.player.res, 2 * n(E.bloom, 0))
end)

test("Lifebloom : améliorée, Regen de départ qui tique dès le premier tour ; Overgrowth (+3)", function()
  for k = 1, 3 do
    local c = setup({ "skull_bash" }, { epic = { "lifebloom", k }, hp = 40 })
    local start = n(E.bloomStart, k)
    eq(c.player.hp, 40 + start, "Lifebloom+" .. k .. " : premier tic")
    eq(c.player.st.regen, start - 1)
    eq(c.player.res, n(E.bloom, k))
  end
  eq(Card.defById("lifebloom", 3).text, "Epic.\nEach Regen heal: Overgrowth 2.")
  local b = setup({ "skull_bash" }, { epic = "lifebloom" })
  eq(b.player.st.regen, nil, "base : pas de Regen de départ")
end)

---------------------------------------------------------------------------
-- Burning Steppes — Owlkin Frenzy
---------------------------------------------------------------------------
test("Owlkin Frenzy : en Moonkin, une attaque ennemie qui coûte des PV donne N, une fois par attaque", function()
  local c = setup({ "wrath" }, { epic = "owlkin_frenzy", encounter = { "de_flurry" } })
  play(c, "wrath", 1)        -- Moonkin, 1 Charge
  local r = c.player.res
  Combat.endTurn(c)          -- quatre coups de 3 : une seule attaque
  eq(c.player.res, math.min(5, r + n(E.moonfury, 0)))
  -- deux actions d'attaque dans le même tour ennemi : une seule fois aussi (même effet)
  local u = setup({ "wrath" }, { epic = "owlkin_frenzy", encounter = { "de_double" } })
  play(u, "wrath", 1)
  r = u.player.res
  Combat.endTurn(u)
  eq(u.player.res, math.min(5, r + n(E.moonfury, 0)))
end)

test("Owlkin Frenzy : rien hors Moonkin, rien si tout est absorbé ; deux ennemis : deux attaques", function()
  local c = setup({ "thick_hide" }, { epic = "owlkin_frenzy", encounter = { "de_hitter" } })
  play(c, "thick_hide")
  c.player.res = 1
  Combat.endPlayerTurn(c)    -- frappe de l'ours : 2
  local r = c.player.res
  Combat.enemyPhase(c)
  eq(c.player.res, r, "Bear")
  local u = setup({ "wrath" }, { epic = "owlkin_frenzy", encounter = { "de_hitter" } })
  play(u, "wrath", 1)
  u.player.block = 20
  r = u.player.res
  Combat.endPlayerTurn(u)
  Combat.enemyPhase(u)
  eq(u.player.res, r, "tout absorbé")
  local w = setup({ "wrath" }, { epic = { "owlkin_frenzy", 1 }, encounter = { "de_hitter", "de_hitter" } })
  play(w, "wrath", 1)
  w.player.res = 0
  Combat.endPlayerTurn(w)
  Combat.enemyPhase(w)
  eq(w.player.res, 2 * n(E.moonfury, 1), "un gain par ennemi")
end)

test("Owlkin Frenzy : Barkskin (+2, +3) : Absorb à la fin d'un tour fini en Moonkin", function()
  for k = 2, 3 do
    local c = setup({ "wrath" }, { epic = { "owlkin_frenzy", k } })
    play(c, "wrath", 1)
    Combat.endPlayerTurn(c)
    eq(c.player.block, n(E.barkskin, k), "Barkskin+" .. k)
  end
  local b = setup({ "thick_hide" }, { epic = { "owlkin_frenzy", 3 } })
  play(b, "thick_hide")
  Combat.endPlayerTurn(b)
  eq(b.player.block, 5, "Bear : rien de plus")
end)

---------------------------------------------------------------------------
-- Blackrock Mountain — Heart of the Wild
---------------------------------------------------------------------------
test("Heart of the Wild : Cat, Bear et Moonkin gardent chacune leur réserve ; la réserve active est c.player.res", function()
  local c = setup({ "shred", "wrath", "ferocious_bite", "thick_hide" }, { epic = "heart_of_the_wild" })
  eq(Combat.resCap(c), n(E.kinship, 0))
  play(c, "shred", 1)        -- Cat : 1 Combo
  eq(c.player.res, 1)
  play(c, "wrath", 1)        -- Moonkin : sa réserve (0), puis +1 ; coup sans bonus (0 Charge au coup)
  eq(c.player.res, 1)
  eq(dealt(c.enemies[1]), 7 + 5)
  eq(D.pool(c, "cat"), 1); eq(D.pool(c, "moonkin"), 1); eq(D.pool(c, "bear"), 0)
  eq(ns.Language.combatResource(c), "wild:moonkin", "nom de la réserve active")
  play(c, "ferocious_bite", 1) -- Cat : dépense ses 1 Combo, la réserve de Moonkin attend
  eq(dealt(c.enemies[1]), 7 + 5 + 4 + 4)
  eq(c.player.res, 0); eq(D.pool(c, "moonkin"), 1)
  play(c, "thick_hide")      -- Bear : 0
  eq(c.player.res, 0)
  assert(Save.isPlain(c)); Combat.clone(c)
end)

test("Heart of the Wild : minRes et Spend lisent la réserve de la forme de la carte ; plafond N", function()
  local c = setup({ "shred", "starsurge", "frenzied_regeneration", "shred" }, { epic = "heart_of_the_wild" })
  play(c, "shred", 1)
  c.player.res = 3           -- Cat 3
  assert(not Combat.canPlay(c, idx(c, "starsurge")), "Starsurge : Moonkin vide")
  c.cls.kin.bear = 2
  play(c, "frenzied_regeneration") -- Spend 2 pris en Bear : 6 + 6
  eq(c.player.block, 12)
  eq(c.player.res, 0, "Bear vidée"); eq(D.pool(c, "cat"), 3, "Cat intacte")
  c.cls.kin.moonkin = 2
  assert(Combat.canPlay(c, idx(c, "starsurge")), "Starsurge : 2 Charges en attente")
  play(c, "starsurge", 1)
  eq(dealt(c.enemies[1]), 7 + 14)
  play(c, "shred", 1)
  eq(c.player.res, 3, "Cat : plafond " .. n(E.kinship, 0))
end)

test("Heart of the Wild : fin de tour sur la réserve de la forme (frappe de l'ours) ; Kindred (+3) : chacune à 1", function()
  local c = setup({ "shred", "shred", "thick_hide" }, { epic = "heart_of_the_wild" })
  play(c, "shred", 1); play(c, "shred", 1)
  play(c, "thick_hide")
  local before = dealt(c.enemies[1])
  Combat.endPlayerTurn(c)
  eq(dealt(c.enemies[1]) - before, D.STRIKE_BASE + 0, "frappe sur la réserve de Bear (0)")
  eq(c.player.res, 1); eq(D.pool(c, "cat"), 2)
  for k = 1, 3 do
    local u = setup({ "skull_bash" }, { epic = { "heart_of_the_wild", k } })
    eq(Combat.resCap(u), n(E.kinship, k))
    for _, f in ipairs({ "cat", "bear", "moonkin" }) do eq(D.pool(u, f), n(E.kinStart, k), f .. "+" .. k) end
    eq(u.player.res, 0, "sans forme : 0")
  end
  eq(Card.defById("heart_of_the_wild", 3).text, "Epic.\nForms: Kindred 5.")
end)

test("sans Heart of the Wild : minRes et Spend lisent la réserve commune (Combat.cardRes)", function()
  local c = setup({ "starsurge" })
  c.player.res = 2
  eq(Combat.cardRes(c, Cards.starsurge), 2)
  assert(Combat.canPlay(c, 1))
end)

---------------------------------------------------------------------------
-- Mots de règle et à-côtés
---------------------------------------------------------------------------
test("mots de règle : un par palier, N remplacé, 110 caractères au plus, deux phrases au plus", function()
  local seen = {}
  for _, id in ipairs(EPICS) do
    for k = 0, 3 do
      local up = Card.upValue(k)
      local d = Card.defById(id, up)
      local words = L.ruleWords(d)
      eq(#words, 1, id .. "+" .. k)
      local r = words[1]
      seen[r.key] = true
      assert(r.n, id .. "+" .. k .. " : nombre")
      local line = r.kw.name .. ": " .. L.ruleText(r.kw, r.n, up)
      assert(not line:find("%f[%w]N%f[%W]"), line)
      assert(#line <= 110, line .. " (" .. #line .. ")")
      local sentences = select(2, line:gsub("[.!?]$", "")) + select(2, line:gsub("[.!?] ", ""))
      assert(sentences <= 2 and not line:find("[;()]"), line)
    end
  end
  for _, key in ipairs({ "primal", "ironfur", "lunar", "solar", "predator", "apex", "bloom", "overgrowth", "moonfury",
      "barkskin", "kinship", "kindred" }) do
    assert(seen[key], key .. " employé")
  end
  local bloom = L.ruleWords(Card.defById("lifebloom", 1))[1]
  eq(L.ruleText(bloom.kw, bloom.n, 1), "Each combat starts with Regen 3. The reserve gains 1 each time Regen heals.")
  local fur = L.ruleWords(Card.defById("mark_of_ursol", 2))[1]
  eq(L.ruleText(fur.kw, fur.n, 2), "Gain Absorb equal to 100% of each Bear strike's damage, rounded down.")
end)

---------------------------------------------------------------------------
-- Bots et simulation
---------------------------------------------------------------------------
test("bot : chaque épique imposée se joue sans erreur ; build piloté par l'épique ; note", function()
  local SE = ns.SimExpedition
  for _, id in ipairs(EPICS) do
    local rec, exp = SE.play({ seed = 1, bot = "greedy", class = "druid", epic = id, zones = 7 })
    assert(rec.floor >= 1, id)
    local i = X.epicIndex(exp)
    if i then eq(exp.deck[i].id, id, "épique imposée gardée") end
    local b = ns.Classes.druid.bot.byEpic[id]
    assert(b and b.rating, id .. " : build")
    assert(ns.Classes.druid.bot.epic(nil, id), id .. " : note")
  end
  local exp = X.new({ seed = 1, class = "druid", unlocks = Meta.allUnlocked(7, 7), epic = "eclipse" })
  local bot = ns.Classes.druid.bot
  assert(bot.epic(exp, "eclipse") > bot.epic(exp, "furor"), "attachement à l'épique du deck")
end)

-- Plusieurs épiques par expédition (19/11/2026) : Heart of the Wild et Furor cumulés, dans les deux ordres du deck
test("deux épiques : Heart of the Wild + Furor, le +1 de Furor va dans la réserve de la nouvelle forme", function()
  for _, order in ipairs({ { "heart_of_the_wild", "furor" }, { "furor", "heart_of_the_wild" } }) do
    local extra = { "skull_bash", "skull_bash", "skull_bash", "skull_bash", order[1], order[2] }
    local c = setup({ "shred", "wrath", "thick_hide" }, { extra = extra })
    eq(#Combat.epicList(c), 2, "deux épiques en jeu")
    eq(Combat.resCap(c), n(E.kinship, 0), "plafond de Heart of the Wild")
    play(c, "shred", 1)        -- sans forme -> Cat : +1 (Furor) +1 (carte), réserve de Cat
    eq(c.player.res, 2, order[1])
    play(c, "wrath", 1)        -- Cat -> Moonkin : réserve de Moonkin, +1 (Furor) +1 (carte)
    eq(c.player.res, 2, order[1]); eq(D.pool(c, "cat"), 2, order[1])
    play(c, "thick_hide")      -- Moonkin -> Bear : 3e changement du tour, Furor ne donne plus rien (Primal 2)
    eq(c.player.res, 0, order[1]); eq(D.pool(c, "moonkin"), 2, order[1])
    assert(Save.isPlain(c)); Combat.clone(c)
  end
end)

ns.Enemies.de_dummy, ns.Enemies.de_hitter, ns.Enemies.de_flurry, ns.Enemies.de_double = nil, nil, nil, nil

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
