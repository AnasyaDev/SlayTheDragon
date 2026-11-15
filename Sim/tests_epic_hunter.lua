-- Tests des sept cartes épiques du Hunter (docs/zones/cartes-de-zone.md, « Hunter ») : cas nominaux et cas
-- limites de la fiche. L'épique est posée dans le deck du combat : ses règles (deckHooks) valent où que soit
-- la carte, les tests ne dépendent pas de la pile qui la porte.
-- Usage : lua5.1 Sim/tests_epic_hunter.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Meta, Save, Combat, Card, H = ns.Expedition, ns.Meta, ns.Save, ns.Combat, ns.Card, ns.Hunter

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
local EPICS = { "call_of_the_wild", "trap_launcher", "beast_cleave", "roar_of_sacrifice", "master_marksman",
  "black_arrow", "lone_wolf" }
local ZONES = { "westfall", "duskwood", "wetlands", "stranglethorn", "swamp", "steppes", "blackrock" }

-- Ennemis de test : passif, cogneur (10), rafale (3 × 4), coup nul, mourant.
ns.Enemies.th_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.th_hitter = { name = "Cogneur", hp = 100,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }
ns.Enemies.th_flurry = { name = "Rafale", hp = 100,
  moves = { hit = { name = "Rafale", intent = "attack", actions = { { "attack", 3, times = 4 } } } }, pattern = { "hit" } }
ns.Enemies.th_zero = { name = "Effleure", hp = 100,
  moves = { hit = { name = "Effleure", intent = "attack", actions = { { "attack", 0 } } } }, pattern = { "hit" } }

local function deckOf(list)
  local d = {}
  for i, id in ipairs(list) do
    if type(id) == "table" then d[i] = { id = id[1], up = id[2] } else d[i] = { id = id, up = false } end
  end
  return d
end

-- Combat de test du Hunter : main imposée (le reste en pioche), épique (id ou { id, up }) dans le deck.
local function setup(hand, opts)
  opts = opts or {}
  local list = {}
  for _, id in ipairs(hand) do list[#list + 1] = id end
  for _, id in ipairs(opts.extra or { "disengage", "disengage", "disengage", "disengage", "disengage" }) do
    list[#list + 1] = id
  end
  if opts.epic then list[#list + 1] = opts.epic end
  local c = Combat.new({ seed = 7, class = "hunter", hp = opts.hp or 60, maxHp = 60, deck = deckOf(list),
    encounter = opts.encounter or { "th_dummy" }, relics = opts.relics, stats = true })
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

local function handIndex(c, id)
  for i, x in ipairs(c.hand) do if x.id == id then return i end end
end
local function inPiles(c, id)
  for _, pile in ipairs({ c.hand, c.draw, c.discard, c.exhaust }) do
    for _, x in ipairs(pile) do if x.id == id then return true end end
  end
  return false
end
local function dealt(e) return e.maxHp - e.hp end
-- nombres réglés des épiques (Data/Hunter.lua, table EPIC) : { base, amélioré }
local E = ns.HunterEpic
-- dégâts de n attaques du familier de suite, à partir du Frenzy f (+1 par attaque, plafond 5)
local function petSeries(n, f)
  local t = 0
  for k = 0, n - 1 do t = t + H.PET_BASE + math.min(5, f + k) end
  return t
end

---------------------------------------------------------------------------
-- Les sept cartes
---------------------------------------------------------------------------
test("sept épiques : une par zone, rareté epic, Power sans coût, textes « Epic. » en tête, base et améliorée", function()
  for i, id in ipairs(EPICS) do
    local d = Cards[id]
    assert(d, id)
    eq(d.class, "hunter", id); eq(d.zone, ZONES[i], id); eq(d.rarity, "epic", id); eq(d.epic, true, id)
    eq(d.type, "power", id); eq(d.cost, 0, id .. " : coût 0, jamais payé"); eq(d.level, nil, id)
    assert(Card.isEpic(d) and Card.collectible(d))
    assert(d.text:find("^Epic%.\n") and d.up and d.up.text:find("^Epic%.\n"), id .. " : texte")
    assert(d.deckHooks and d.whileInDeck, id .. " : règle en jeu")
    eq(Meta.zoneCards("hunter", ZONES[i])[1], id)
    eq(#Meta.zoneCards("hunter", ZONES[i]), 1, id)
  end
  for _, id in ipairs(Card.pool("hunter", true)) do
    assert(Cards[id].rarity ~= "epic" and not Cards[id].variant, "réserve : " .. id)
  end
end)

test("épique : ni piochée, ni en main, même seule dans un petit deck ; combat sauvegardable et clonable", function()
  for _, id in ipairs(EPICS) do
    for seed = 1, 5 do
      local c = Combat.new({ seed = seed, class = "hunter", hp = 50, deck = deckOf({ "arcane_shot", "disengage", id }),
        encounter = { "th_dummy" } })
      assert(not inPiles(c, id), id .. " dans les piles")
      eq(H.epic(c), id)
      assert(Save.isPlain(c), id .. " : sauvegardable")
      local cl = Combat.clone(c)
      Combat.endTurn(cl)
      Combat.endTurn(c)
      assert(not inPiles(c, id), id .. " piochée au tour 2")
    end
  end
end)

---------------------------------------------------------------------------
-- Westfall — Call of the Wild
---------------------------------------------------------------------------
-- Call of the Wild : coût en Frenzy de l'attaque du début du tour (base, amélioré)
local K1, K2 = E.cotwCost[1], E.cotwCost[2]
test("Call of the Wild : au début de chaque tour, N Frenzy dépensés pour une attaque du familier ; sans Frenzy : rien", function()
  assert(K1 > 0 and K2 == 0, "base payée, améliorée gratuite")
  local c = setup({ "disengage" }, { epic = "call_of_the_wild" })
  local e = c.enemies[1]
  eq(dealt(e), 0, "tour 1 : Frenzy 0, pas d'attaque")
  eq(c.player.res, 0)
  Combat.endTurn(c)
  -- fin du tour 1 : attaque automatique (1 + 0, Frenzy 1), baisse (0) : rien au début du tour 2
  eq(dealt(e), H.PET_BASE)
  c.player.res = 3
  Combat.endTurn(c)
  -- fin du tour 2 : auto 1 + 3 (F 4), baisse (3) ; début du tour 3 : -K1, attaque à 1 + (3 - K1), +1
  eq(dealt(e), H.PET_BASE + (H.PET_BASE + 3) + (H.PET_BASE + 3 - K1))
  eq(c.player.res, 3 - K1 + 1)
end)

test("Call of the Wild amélioré : attaque gratuite au début de chaque tour, premier compris", function()
  local c = setup({ "disengage" }, { epic = { "call_of_the_wild", true } })
  eq(dealt(c.enemies[1]), H.PET_BASE, "tour 1 : 1 + Frenzy 0")
  eq(c.player.res, 1)
  Combat.endTurn(c)
  -- fin du tour 1 : auto (1 + 1), baisse (2 -> 1), début du tour 2 : 1 + 1
  eq(dealt(c.enemies[1]), H.PET_BASE + (H.PET_BASE + 1) + (H.PET_BASE + 1))
  eq(c.player.res, 2)
end)

test("Call of the Wild + Pet Whistle : le sifflet donne le Frenzy, deux attaques au premier tour", function()
  local c = setup({ "disengage" }, { epic = "call_of_the_wild", relics = { "pet_whistle" } })
  -- sifflet : 1 + 0 (F 1) ; épique : -K1 puis 1 + (1 - K1) (+1)
  eq(dealt(c.enemies[1]), H.PET_BASE + (H.PET_BASE + 1 - K1))
  eq(c.player.res, 1 - K1 + 1)
end)

---------------------------------------------------------------------------
-- Duskwood — Trap Launcher
---------------------------------------------------------------------------
test("Trap Launcher : la Trap demande une cible, se déclenche tout de suite, le familier attaque cet ennemi", function()
  local c = setup({ "freezing_trap", "counterattack" }, { epic = "trap_launcher", encounter = { "th_dummy", "th_hitter" } })
  assert(Combat.needsTarget(c.hand[1], c), "cible demandée")
  assert(not Combat.play(c, 1, nil), "sans cible : refusée")
  local e2 = c.enemies[2]
  assert(Combat.play(c, 1, 2))
  eq(e2.st.stunned, 1, "Freezing Trap sur la cible")
  eq(#c.traps, 0, "aucune Trap posée")
  local n = E.launcher[1]
  eq(dealt(e2), petSeries(n, 0), "le familier attaque la cible")
  eq(dealt(c.enemies[1]), 0)
  eq(c.player.lastTarget, e2.uid, "devient la cible du familier")
  eq(c.player.res, n)
  -- Counterattack : 13 puis le familier
  assert(Combat.play(c, 1, 1))
  eq(dealt(c.enemies[1]), 13 + petSeries(n, n))
  -- tour ennemi : l'ennemi étourdi par la Trap lancée perd son tour
  local hp = c.player.hp
  Combat.endTurn(c)
  eq(c.player.hp, hp, "Freezing Trap : le cogneur ne frappe pas")
end)

test("Trap Launcher amélioré : attaques en plus ; zone pleine : jouable ; Explosive Trap : tous, familier sur la cible", function()
  local c = setup({ "explosive_trap", "counterattack" }, { epic = { "trap_launcher", true },
    encounter = { "th_dummy", "th_dummy", "th_dummy" } })
  c.traps = { { card = Card.new("frost_trap", false, 700) }, { card = Card.new("frost_trap", false, 701) },
    { card = Card.new("frost_trap", false, 702) } }
  assert(Combat.canPlay(c, 1), "zone des pièges pleine : lancée quand même")
  assert(Combat.play(c, 1, 3))
  eq(dealt(c.enemies[1]), 6); eq(dealt(c.enemies[2]), 6)
  eq(dealt(c.enemies[3]), 6 + petSeries(E.launcher[2], 0), "attaques du familier sur la cible choisie")
  eq(c.enemies[1].st.pain, 3)
  eq(#c.traps, 3, "zone inchangée")
end)

test("Trap Launcher : Entrapment et Lock and Load s'appliquent (onTrapTriggered, why = launch)", function()
  local c = setup({ "entrapment", "lock_and_load", "counterattack" }, { epic = "trap_launcher" })
  assert(Combat.play(c, 1)); assert(Combat.play(c, 1))
  local n = #c.hand
  assert(Combat.play(c, 1, 1))
  eq(c.enemies[1].st.demoralized, 1, "Entrapment")
  eq(#c.hand, n - 1 + 1, "Lock and Load : une pioche")
end)

test("Trap Launcher + Resourcefulness : la Trap lancée revient en main à la fin du round, pas tout de suite", function()
  local c = setup({ "resourcefulness", "freezing_trap" }, { epic = "trap_launcher", encounter = { "th_hitter" } })
  assert(Combat.play(c, 1))
  local uid = c.hand[1].uid
  assert(Combat.play(c, 1, 1))
  assert(not handIndex(c, "freezing_trap"), "pas tout de suite")
  Combat.endTurn(c)
  local back = false
  for _, x in ipairs(c.hand) do if x.uid == uid then back = true end end
  assert(back, "revenue au tour suivant")
  -- sans Trap Launcher : la Trap déclenchée par une attaque revient tout de suite (règle de la carte)
  local c2 = setup({ "resourcefulness", "counterattack" }, { encounter = { "th_hitter" } })
  assert(Combat.play(c2, 1)); assert(Combat.play(c2, 1))
  eq(#c2.traps, 1)
  Combat.endTurn(c2)
  assert(handIndex(c2, "counterattack"), "Resourcefulness inchangée sans l'épique")
end)

test("Trap Launcher : sans l'épique, les Traps restent posées", function()
  local c = setup({ "freezing_trap" })
  assert(not Combat.needsTarget(c.hand[1], c))
  assert(Combat.play(c, 1))
  eq(#c.traps, 1)
end)

---------------------------------------------------------------------------
-- Wetlands — Beast Cleave
---------------------------------------------------------------------------
-- Beast Cleave : les autres ennemis prennent S dégâts de moins du familier (jamais sous 0)
local S1, S2 = E.cleaveLess[1], E.cleaveLess[2]
local function share(d, s) return math.max(0, d - s) end
test("Beast Cleave : chaque attaque du familier frappe tous les ennemis (les autres moins fort), +1 Frenzy une fois", function()
  local c = setup({ "kill_command" }, { epic = "beast_cleave", encounter = { "th_dummy", "th_dummy", "th_dummy" } })
  c.player.res = 3
  assert(Combat.play(c, 1, 2))
  -- deux attaques : 1 + 3 puis 1 + 4 ; la cible en plein, les autres divisés par S1
  eq(dealt(c.enemies[2]), (H.PET_BASE + 3) + (H.PET_BASE + 4), "cible")
  for _, i in ipairs({ 1, 3 }) do
    eq(dealt(c.enemies[i]), share(H.PET_BASE + 3, S1) + share(H.PET_BASE + 4, S1), "ennemi " .. i)
  end
  eq(c.player.res, 5)
  eq(H.petLess(setup({ "disengage" })), 0, "sans l'épique : en plein")
  -- coup nul : jamais de dégâts négatifs (Frenzy 0 : 1 - S1)
  local z = setup({ "disengage" }, { epic = "beast_cleave", encounter = { "th_dummy", "th_dummy" } })
  Combat.endTurn(z)
  eq(dealt(z.enemies[2]), share(H.PET_BASE, S1), "autre ennemi au Frenzy 0")
end)

test("Beast Cleave amélioré : +2 Frenzy par attaque ; Surge (Bestial Wrath) : à tous, sans Frenzy", function()
  local c = setup({ "kill_command" }, { epic = { "beast_cleave", true }, encounter = { "th_dummy", "th_dummy" } })
  assert(Combat.play(c, 1, 1))
  eq(c.player.res, 4)
  local c2 = setup({ "bestial_wrath" }, { epic = { "beast_cleave", true }, encounter = { "th_dummy", "th_dummy" } })
  c2.player.res = 3
  assert(Combat.play(c2, 1, 1))
  eq(dealt(c2.enemies[1]), 3 * (H.PET_BASE + 3), "Surge : la cible")
  eq(dealt(c2.enemies[2]), 3 * share(H.PET_BASE + 3, S2), "Surge : les autres")
  eq(c2.player.res, 0, "Surge : ni Frenzy du familier ni bonus de l'épique")
end)

---------------------------------------------------------------------------
-- Stranglethorn Vale — Roar of Sacrifice
---------------------------------------------------------------------------
test("Roar of Sacrifice : chaque coup coûte 1 Frenzy et perd jusqu'à N dégâts, avant l'Absorb", function()
  local c = setup({ "disengage" }, { epic = "roar_of_sacrifice", encounter = { "th_hitter" } })
  c.player.res = 2
  c.player.block = 3
  local hp = c.player.hp
  -- le familier attaque à la fin du tour (+1 Frenzy : 3), le coup de 10 en perd R (Frenzy 2), 3 absorbés
  local R = E.roar[1]
  Combat.endTurn(c)
  eq(c.player.hp, hp - math.max(0, 10 - R - 3))
  eq(c.stats.roarPrevented, math.min(10, R))
  eq(c.player.res, 1, "3, -1 pour le coup, -1 à la fin du round")
end)

test("Roar of Sacrifice amélioré ; rafale : coup par coup ; sans Frenzy : rien ; coup de 0 : gratuit", function()
  local c = setup({ "disengage" }, { epic = { "roar_of_sacrifice", true }, encounter = { "th_hitter" } })
  c.player.res = 1
  local hp = c.player.hp
  Combat.endTurn(c) -- Frenzy 1 + 1 (familier) = 2 au coup
  eq(c.player.hp, hp - math.max(0, 10 - E.roar[2]))
  local f = setup({ "disengage" }, { epic = "roar_of_sacrifice", encounter = { "th_flurry" } })
  f.player.res = 1 -- 2 après l'attaque du familier : deux coups de 3 réduits, deux en plein
  hp = f.player.hp
  Combat.endTurn(f)
  eq(f.player.hp, hp - (12 - 2 * math.min(3, E.roar[1])))
  eq(f.player.res, 0, "Frenzy dépensé puis baisse à 0")
  local z = setup({ "disengage" }, { epic = "roar_of_sacrifice", encounter = { "th_zero" } })
  Combat.endTurn(z)
  eq(z.stats.roarPrevented, nil, "coup de 0 : rien dépensé")
  -- DoT sur le héros : pas un coup
  local d = setup({ "disengage" }, { epic = "roar_of_sacrifice" })
  d.player.res = 3
  Combat.applyStatus(d, d.player, "pain", 4)
  Combat.endTurn(d)
  eq(d.stats.roarPrevented, nil, "DoT : rien")
end)

---------------------------------------------------------------------------
-- Swamp of Sorrows — Master Marksman
---------------------------------------------------------------------------
test("Master Marksman : Attack Cast sur une cible intacte = résolue tout de suite (Careful Aim vrai)", function()
  local c = setup({ "aimed_shot", "steady_shot" }, { epic = "master_marksman" })
  local e = c.enemies[1]
  local hand = #c.hand
  local m = E.marksman[1]
  assert(Combat.play(c, 1, 1))
  eq(c.player.cast, nil, "aucune incantation")
  eq(dealt(e), 24 + 10 + m, "Careful Aim : 10 de plus, et le bonus de l'épique")
  eq(c.player.mana, 9 - 2)
  -- Steady Shot sur une cible intacte : part et pioche
  e.hp = e.maxHp
  assert(Combat.play(c, 1, 1))
  eq(c.player.cast, nil)
  eq(dealt(e), 13 + m)
  eq(#c.hand, hand - 2 + 1, "Careful Aim : draw 1")
end)

test("Master Marksman : sous la moitié = Cast normal ; Volley reste un Cast ; amélioré : bonus par coup", function()
  local c = setup({ "aimed_shot", "volley" }, { epic = "master_marksman" })
  c.enemies[1].hp = 40
  assert(Combat.play(c, 1, 1))
  assert(c.player.cast, "incantation posée")
  local c2 = setup({ "volley" }, { epic = "master_marksman" })
  assert(Combat.play(c2, 1))
  assert(c2.player.cast, "Volley : Cast")
  local c3 = setup({ "aimed_shot", "rapid_fire" }, { epic = { "master_marksman", true } })
  assert(Combat.play(c3, 1, 1))
  local m2 = 24 + 10 + E.marksman[2]
  eq(dealt(c3.enemies[1]), m2)
  eq(c3.cls.marksman, nil, "bonus retiré après la carte")
  assert(Combat.play(c3, 1, 1))
  eq(dealt(c3.enemies[1]), m2 + 12, "Rapid Fire (pas une Cast) : sans bonus")
  -- incantation normale (cible sous la moitié) : sans bonus à la résolution
  local c4 = setup({ "aimed_shot" }, { epic = { "master_marksman", true } })
  c4.enemies[1].hp = 40
  assert(Combat.play(c4, 1, 1))
  Combat.endTurn(c4)
  eq(c4.enemies[1].hp, 40 - 24 - (H.PET_BASE + 0), "Aimed Shot incantée : 24, sans bonus ; familier 1")
end)

test("Master Marksman : jouable pendant une incantation tant qu'une cible intacte existe", function()
  local c = setup({ "steady_shot", "aimed_shot" }, { epic = "master_marksman" })
  c.enemies[1].hp = 40
  assert(Combat.play(c, 1, 1))
  assert(c.player.cast)
  c.enemies[1].hp = 40
  local ok = Combat.canPlay(c, 1)
  assert(not ok, "aucune cible intacte : emplacement pris")
  c.enemies[1].hp = 90
  assert(Combat.canPlay(c, 1), "cible intacte : jouable")
  assert(Combat.play(c, 1, 1))
  eq(c.player.castMore, nil, "partie tout de suite, pas de seconde incantation")
end)

---------------------------------------------------------------------------
-- Burning Steppes — Black Arrow
---------------------------------------------------------------------------
-- Black Arrow : coût en Frenzy de l'attaque sur l'ennemi qui tique (base, amélioré)
local B1, B2 = E.blackCost[1], E.blackCost[2]
test("Black Arrow : chaque tic de DoT sur un ennemi vivant : N Frenzy pour une attaque du familier sur lui", function()
  assert(B1 > 0 and B2 == 0, "base payée, améliorée gratuite")
  local c = setup({ "serpent_sting" }, { epic = "black_arrow", encounter = { "th_dummy", "th_dummy" } })
  assert(Combat.play(c, 1, 2))
  local e1, e2 = c.enemies[1], c.enemies[2]
  c.player.lastTarget = e1.uid -- la cible du familier n'est pas l'ennemi qui tique
  c.player.res = 2
  Combat.endTurn(c)
  -- fin du tour : familier sur e1 (1 + 2, F 3) ; tour ennemi : tic 3 sur e2, -B1, familier sur e2 (1 + 3 - B1)
  eq(dealt(e1), H.PET_BASE + 2)
  eq(dealt(e2), 3 + H.PET_BASE + 3 - B1)
  eq(c.player.lastTarget, e1.uid, "cible inchangée")
  -- sans Frenzy au tic : pas d'attaque
  local z = setup({ "disengage" }, { epic = "black_arrow", extra = { "disengage" } })
  Combat.applyStatus(z, z.enemies[1], "pain", 3)
  local before = z.stats.petAttacks or 0
  z.player.res = 0
  ns.Combat.fire(z, "onDotTick", z.enemies[1], 3)
  eq((z.stats.petAttacks or 0) - before, B1 > 0 and 0 or 1, "Frenzy 0 : rien")
end)

test("Black Arrow : le familier tue avant que l'ennemi agisse ; mort par le DoT : rien ; amélioré : gratuit", function()
  local c = setup({ "disengage" }, { epic = "black_arrow", encounter = { "th_hitter", "th_dummy" } })
  local e = c.enemies[1]
  e.hp = 5
  Combat.applyStatus(c, e, "pain", 3)
  c.player.lastTarget = c.enemies[2].uid
  c.player.res = 3
  local hp = c.player.hp
  Combat.endTurn(c)
  assert(e.dead, "tué par le familier après le tic")
  eq(c.player.hp, hp, "il n'a pas agi")
  local d = setup({ "disengage" }, { epic = "black_arrow", encounter = { "th_dummy", "th_dummy" } })
  d.enemies[1].hp = 2
  Combat.applyStatus(d, d.enemies[1], "pain", 3)
  d.player.lastTarget = d.enemies[2].uid
  d.player.res = 3
  Combat.endTurn(d)
  assert(d.enemies[1].dead)
  eq(dealt(d.enemies[2]), H.PET_BASE + 3, "seule l'attaque automatique")
  local u = setup({ "disengage" }, { epic = { "black_arrow", true } })
  Combat.applyStatus(u, u.enemies[1], "pain", 3)
  Combat.endTurn(u)
  -- auto : 1 + 0 (F 1) ; tic 3, familier 1 + 1 (F 2) ; baisse de round : 1
  eq(dealt(u.enemies[1]), H.PET_BASE + 3 + H.PET_BASE + 1)
  eq(u.player.res, 1)
end)

test("Black Arrow : DoT à tous (Explosive Trap) = une attaque par ennemi tant que le Frenzy suit", function()
  local c = setup({ "disengage" }, { epic = "black_arrow", encounter = { "th_dummy", "th_dummy", "th_dummy" } })
  for i = 1, 3 do Combat.applyStatus(c, c.enemies[i], "pain", 3) end
  c.player.lastTarget = c.enemies[1].uid
  c.player.res = 2
  local before = c.stats.petAttacks or 0
  Combat.endTurn(c)
  -- auto : F 3 ; chaque tic coûte B1 et l'attaque en rend 1
  eq((c.stats.petAttacks or 0) - before, 1 + 3)
end)

---------------------------------------------------------------------------
-- Blackrock Mountain — Lone Wolf
---------------------------------------------------------------------------
local LW = {
  arcane_shot = "chimaera_shot", kill_command = "kill_shot", dire_beast = "double_tap", intimidation = "scatter_shot",
  multi_shot = "salvo", counter_shot = "silencing_shot", bestial_wrath = "explosive_shot",
  the_beast_within = "trick_shots", spirit_bond = "aspect_of_the_turtle",
}

test("Lone Wolf : table des variantes complète (toute carte de familier), variantes non collectionnables", function()
  local tr = Cards.lone_wolf.transforms
  for from, to in pairs(LW) do eq(tr[from], to, from) end
  for id, d in pairs(Cards) do
    if d.class == "hunter" and not d.variant and not d.zone then
      local pet = d.hooks ~= nil and (d.hooks.onPetAttack ~= nil or id == "the_beast_within")
      for _, e in ipairs(d.effects) do if e[1] == "pet" then pet = true end end
      eq(pet, tr[id] ~= nil, id .. " : carte de familier <-> transformée")
    end
  end
  eq(tr.growl, nil, "Growl ne nomme pas le familier")
  for from, to in pairs(LW) do
    local o, v = Cards[from], Cards[to]
    eq(v.variant, true, to); assert(not Card.collectible(v), to)
    eq(v.cost, o.cost, to); eq(v.type, o.type, to); eq(v.rarity, o.rarity, to); eq(v.path, o.path, to)
    eq(v.up ~= nil, o.up ~= nil, to .. " : amélioration")
    eq(v.class, "hunter")
  end
end)

test("Lone Wolf : variantes jouables (base et paliers 1 à 3), textes conformes aux effets", function()
  local bad = {}
  local function has(t, s) return t:find(s, 1, true) ~= nil end
  for _, vid in pairs(LW) do
    for _, up in ipairs({ false, 1, 2, 3 }) do -- tous les paliers (paliers 2 et 3 : 15/11/2026)
      local d = Card.defById(vid, up)
      local t, lab = d.text, vid .. Card.suffix(up)
      for _, e in ipairs(d.effects) do
        if e[1] == "damage" and e[2] > 0 and not has(t, "eal " .. e[2] .. (e.all and " to all" or ".")) then bad[#bad + 1] = lab .. " : damage" end
        if e[1] == "damageOther" and not has(t, "eal " .. e[2] .. " to another enemy.") then bad[#bad + 1] = lab .. " : other" end
        if e[1] == "res" and not has(t, "+" .. e[2] .. " Frenzy.") then bad[#bad + 1] = lab .. " : res" end
        if e[1] == "draw" and not has(t, "raw " .. e[2] .. ".") then bad[#bad + 1] = lab .. " : draw" end
        if e[1] == "pet" then bad[#bad + 1] = lab .. " : familier" end
      end
      if d.cooldown and not has(t, "Cooldown " .. d.cooldown .. ".") then bad[#bad + 1] = lab .. " : Cooldown" end
      if (d.power == true) ~= (t:find("^Power%.\n") ~= nil) then bad[#bad + 1] = lab .. " : Power" end
      if (d.exhaust == true) ~= has(t, "Exhaust.") then bad[#bad + 1] = lab .. " : Exhaust" end
      if t:lower():find("pet") then bad[#bad + 1] = lab .. " : nomme le familier" end
      local c = setup({ "disengage" }, { epic = "lone_wolf", encounter = { "th_dummy", "th_hitter" } })
      c.player.res = 5
      c.hand[1] = Card.new(vid, up, 999)
      c.enemies[1].hp = 40
      local ok, why = Combat.play(c, 1, 1)
      if not ok then bad[#bad + 1] = lab .. " : injouable (" .. tostring(why) .. ")" end
      Combat.endTurn(c)
      Combat.endTurn(c)
    end
  end
  assert(#bad == 0, table.concat(bad, " ; "))
end)

test("Lone Wolf : plus de familier ; cartes de familier jouées sous leur variante ; Pet Whistle : +1 Frenzy", function()
  local deck = deckOf({ "arcane_shot", "arcane_shot", "kill_command", "growl", { "spirit_bond", true }, "lone_wolf" })
  local c = Combat.new({ seed = 3, class = "hunter", hp = 50, deck = deck, encounter = { "th_dummy" },
    relics = { "pet_whistle" } })
  assert(not H.petPresent(c))
  local ids = {}
  for _, pile in ipairs({ c.hand, c.draw }) do
    for _, x in ipairs(pile) do ids[x.id] = (ids[x.id] or 0) + 1 ; if x.id == "aspect_of_the_turtle" then assert(x.up) end end
  end
  eq(ids.chimaera_shot, 2); eq(ids.kill_shot, 1); eq(ids.growl, 1); eq(ids.aspect_of_the_turtle, 1)
  eq(ids.arcane_shot, nil); eq(ids.kill_command, nil)
  eq(c.player.res, 1 + E.loneStart[1], "Pet Whistle : +1 Frenzy au lieu d'une attaque")
  eq(dealt(c.enemies[1]), 0, "pas d'attaque du familier")
  Combat.endTurn(c)
  eq(dealt(c.enemies[1]), 0, "pas d'attaque automatique")
  -- sans Lone Wolf : Pet Whistle fait attaquer
  local c2 = Combat.new({ seed = 3, class = "hunter", hp = 50, deck = deckOf({ "arcane_shot" }), encounter = { "th_dummy" },
    relics = { "pet_whistle" } })
  eq(dealt(c2.enemies[1]), H.PET_BASE)
end)

test("Lone Wolf : chaque coup d'Attack inflige le Frenzy de plus ; pas les Skills ; Chimaera Shot touche un autre ennemi", function()
  local c = setup({ "chimaera_shot", "rapid_fire", "scatter_shot" }, { epic = "lone_wolf",
    extra = { "arcane_shot", "intimidation", "disengage", "disengage", "disengage" },
    encounter = { "th_dummy", "th_dummy", "th_dummy" } })
  local P = E.lonePer[1]
  c.player.res = 2
  assert(Combat.play(c, 1, 2))
  local C1, C2 = E.chimaera[1], E.chimaera[2]
  eq(dealt(c.enemies[2]), C1 + 2 * P); eq(dealt(c.enemies[1]), C2 + 2 * P, "un autre ennemi : le plus à gauche")
  eq(dealt(c.enemies[3]), 0); eq(c.player.res, 3)
  assert(Combat.play(c, 1, 3))
  eq(dealt(c.enemies[3]), 4 * (3 + 3 * P), "Rapid Fire : quatre coups, Frenzy à chacun")
  local before = dealt(c.enemies[1])
  assert(Combat.play(c, 1, 1))
  eq(dealt(c.enemies[1]) - before, 3, "Scatter Shot (Skill) : sans bonus")
  eq(c.enemies[1].st.stunned, 1)
  -- seul ennemi : Chimaera Shot ne touche que la cible
  local s = setup({ "chimaera_shot" }, { epic = "lone_wolf", extra = { "arcane_shot" } })
  local f0 = s.player.res
  assert(Combat.play(s, 1, 1))
  eq(dealt(s.enemies[1]), C1 + P * f0)
end)

test("Lone Wolf : Cast lit le Frenzy à la résolution ; Frenzy au début du tour ; Trick Shots, Turtle", function()
  local c = setup({ "aimed_shot" }, { epic = "lone_wolf", extra = { "disengage", "disengage", "disengage", "disengage", "disengage" } })
  c.player.res = 1
  assert(Combat.play(c, 1, 1))
  c.player.res = 4 -- 4 au moment de jouer ; baisse de round : 3 à la résolution
  Combat.endTurn(c)
  eq(dealt(c.enemies[1]), 24 + 10 + E.lonePer[1] * 3, "Frenzy lu à la résolution (avant le gain du début du tour)")
  local S2 = E.loneStart[2]
  local u = setup({ "disengage" }, { epic = { "lone_wolf", true } })
  eq(u.player.res, S2, "tour 1")
  Combat.endTurn(u)
  eq(u.player.res, math.min(5, math.max(0, S2 - 1) + S2), "baisse de 1, puis le gain du début du tour")
  local t = setup({ "trick_shots", "aspect_of_the_turtle", "rapid_fire" }, { epic = "lone_wolf",
    extra = { "the_beast_within", "spirit_bond", "disengage", "disengage" } })
  local f1 = t.player.res
  assert(Combat.play(t, 1)); assert(Combat.play(t, 1))
  assert(Combat.play(t, 1, 1))
  eq(t.player.res, f1 + 1, "Trick Shots : +1 par Attack")
  eq(t.player.block, 4, "Aspect of the Turtle : 1 Absorb par coup")
end)

test("Lone Wolf : deck de l'expédition montré transformé (amélioration gardée), défait sans l'épique", function()
  local exp = X.new({ seed = 3, class = "hunter", unlocks = Meta.allUnlocked(7, 7), epic = "lone_wolf" })
  exp.deck[1].up = true
  local shown = X.shownDeck(exp)
  eq(exp.deck[1].id, "arcane_shot")
  eq(shown[1].id, "chimaera_shot"); eq(shown[1].up, 1); eq(shown[1].from, "arcane_shot")
  for i, cd in ipairs(shown) do
    if exp.deck[i].id == "disengage" then eq(cd.id, "disengage") end
  end
  table.remove(exp.deck, X.epicIndex(exp))
  eq(X.shownDeck(exp)[1].id, "arcane_shot")
end)

---------------------------------------------------------------------------
-- Paliers 2 et 3 (15/11/2026, docs/ameliorations.md) : nombres lus par Card.level(src) dans ns.HunterEpic
---------------------------------------------------------------------------
test("paliers : sept épiques et neuf variantes à +2 / +3 ; textes en deux lignes, mots de règle avec leur nombre", function()
  local Lg = ns.Language
  for _, id in ipairs(EPICS) do
    eq(Card.tiers(id), 3, id)
    local prev = Card.defById(id, 1).text
    for n = 2, 3 do
      local d = Card.defById(id, n)
      assert(d.text:find("^Epic%.\n[^\n]+$"), id .. "+" .. n .. " : deux lignes")
      assert(d.text ~= prev, id .. "+" .. n .. " : le texte change")
      prev = d.text
      for _, r in ipairs(Lg.ruleWords(d)) do
        local t = Lg.ruleText(r.kw, r.n, true)
        assert(not t:find("%f[%w]N%f[%W]"), id .. "+" .. n .. " : N remplacé (" .. t .. ")")
      end
    end
  end
  for _, vid in pairs({ "chimaera_shot", "kill_shot", "double_tap", "scatter_shot", "salvo", "silencing_shot",
      "explosive_shot", "trick_shots", "aspect_of_the_turtle" }) do
    eq(Card.tiers(vid), 3, vid)
  end
  eq(Card.defById("trap_launcher", 2).text, "Epic.\nTraps: +1 Frenzy, Launch 2.")
  eq(Card.defById("beast_cleave", 3).text, "Epic.\nPet attacks: Trample +2.")
  eq(Card.defById("call_of_the_wild", 2).text, "Epic.\nStart of turn: Hunt 1.")
  eq(Card.defById("black_arrow", 3).text, "Epic.\nEnemy DoT ticks: Prey 2.")
  eq(Card.defById("lone_wolf", 3).text, "Epic.\nAttack hits: Ferocity 5.")
  local tr = Lg.ruleWords(Card.defById("beast_cleave", 2))[1]
  eq(tr.key, "trample"); eq(Lg.ruleText(tr.kw, tr.n, true), "Pet attacks also hit every other enemy, in full. Each one gives 1 more Frenzy.")
  local launch = Lg.ruleWords(Card.defById("trap_launcher", 3))[1]
  eq(Lg.ruleText(launch.kw, launch.n, true), "The Trap triggers at once on a target, then the pet attacks it 3 times.")
end)

test("paliers : Call of the Wild +2 / +3 (Frenzy avant l'attaque), Trap Launcher +2 / +3", function()
  for n = 2, 3 do
    local r = E.cotwRes[n + 1]
    local c = setup({ "disengage" }, { epic = { "call_of_the_wild", n } })
    -- tour 1 : +r Frenzy, attaque à 1 + r, +1
    eq(dealt(c.enemies[1]), H.PET_BASE + r, "Call of the Wild+" .. n)
    eq(c.player.res, r + 1)
    local t = setup({ "counterattack" }, { epic = { "trap_launcher", n } })
    t.player.res = 0
    assert(Combat.play(t, 1, 1))
    local k, lr = E.launcher[n + 1], E.launchRes[n + 1]
    eq(dealt(t.enemies[1]), 13 + petSeries(k, lr), "Trap Launcher+" .. n)
    eq(t.player.res, math.min(5, lr + k))
  end
end)

test("paliers : Beast Cleave +2 (en plein) / +3 (+2 Frenzy) ; Roar +2 / +3 ; Black Arrow +2 (+1 Frenzy)", function()
  local c = setup({ "kill_command" }, { epic = { "beast_cleave", 2 }, encounter = { "th_dummy", "th_dummy" } })
  c.player.res = 0
  assert(Combat.play(c, 1, 1))
  -- 1 + 0 (F 2), puis 1 + 2 (F 4) : les deux ennemis en plein
  eq(dealt(c.enemies[1]), 2 * H.PET_BASE + 2); eq(dealt(c.enemies[2]), 2 * H.PET_BASE + 2, "en plein")
  eq(c.player.res, 4)
  local c3 = setup({ "kill_command" }, { epic = { "beast_cleave", 3 }, encounter = { "th_dummy", "th_dummy" } })
  c3.player.res = 0
  assert(Combat.play(c3, 1, 1))
  eq(dealt(c3.enemies[2]), 2 * H.PET_BASE + 3, "+3 : Frenzy 3 à la seconde attaque"); eq(c3.player.res, 5)
  for n = 2, 3 do
    local r = setup({ "disengage" }, { epic = { "roar_of_sacrifice", n }, encounter = { "th_hitter" } })
    r.player.res = 1
    local hp = r.player.hp
    Combat.endTurn(r)
    eq(r.player.hp, hp - (10 - E.roar[n + 1]), "Roar of Sacrifice+" .. n)
  end
  local u = setup({ "disengage" }, { epic = { "black_arrow", 2 } })
  Combat.applyStatus(u, u.enemies[1], "pain", 3)
  Combat.endTurn(u)
  -- auto : 1 + 0 (F 1) ; tic 3, familier 1 + 1 (F 2), +1 (F 3) ; baisse de round : 2
  eq(dealt(u.enemies[1]), H.PET_BASE + 3 + H.PET_BASE + 1)
  eq(u.player.res, 2)
end)

test("paliers : Master Marksman +3, Lone Wolf +2 (Ferocity 4) / +3 (Ferocity 5), variantes au palier", function()
  local m = setup({ "aimed_shot" }, { epic = { "master_marksman", 3 } })
  assert(Combat.play(m, 1, 1))
  eq(dealt(m.enemies[1]), 24 + 10 + E.marksman[4])
  local l = setup({ "chimaera_shot" }, { epic = { "lone_wolf", 2 }, extra = { "arcane_shot" } })
  l.player.res = 2
  assert(Combat.play(l, 1, 1))
  eq(dealt(l.enemies[1]), E.chimaera[1] + 2 * E.lonePer[3])
  local s = setup({ "chimaera_shot" }, { epic = { "lone_wolf", 3 }, extra = { "arcane_shot" } })
  s.player.res = 2
  assert(Combat.play(s, 1, 1))
  eq(dealt(s.enemies[1]), E.chimaera[1] + 2 * E.lonePer[4], "Ferocity 5")
  eq(E.lonePer[4], 5); eq(E.loneStart[4], 0, "pas de Frenzy au début du tour")
  -- variantes : palier de la carte d'origine (Chimaera Shot+3 : 8, 6 à un autre, +2 Frenzy ; Kill Shot+2 : coût 0)
  local deck = deckOf({ { "arcane_shot", 3 }, { "kill_command", 2 }, "lone_wolf", "disengage", "disengage", "disengage" })
  local c = Combat.new({ seed = 3, class = "hunter", hp = 50, deck = deck, encounter = { "th_dummy", "th_dummy" } })
  local ch, ks
  for _, pile in ipairs({ c.hand, c.draw }) do
    for _, x in ipairs(pile) do
      if x.id == "chimaera_shot" then ch = x elseif x.id == "kill_shot" then ks = x end
    end
  end
  eq(ch.up, 3); eq(ks.up, 2)
  eq(Combat.cost(c, ks), 0)
  local d = Card.def(ch)
  eq(d.effects[1][2], E.chimaera[3]); eq(d.effects[2][2], E.chimaera[4]); eq(d.effects[3][2], 2)
end)

---------------------------------------------------------------------------
-- Bots et simulation
---------------------------------------------------------------------------
test("bot : chaque épique imposée se joue sans erreur ; build piloté par l'épique (notes du deck)", function()
  local SE = ns.SimExpedition
  for _, id in ipairs(EPICS) do
    for seed = 1, 2 do
      local rec, exp = SE.play({ seed = seed, class = "hunter", epic = id, zones = 7 })
      assert(rec.floor >= 1, id)
      local i = X.epicIndex(exp)
      if i then eq(exp.deck[i].id, id, "épique imposée gardée (jamais remplacée par l'offre)") end
    end
    local b = ns.Classes.hunter.bot.byEpic[id]
    assert(b and b.rating, id .. " : build")
    assert(ns.Classes.hunter.bot.epic(nil, id), id .. " : note")
  end
  -- l'épique du deck vaut plus pour le bot (elle n'est remplacée que par bien mieux)
  local exp = X.new({ seed = 1, class = "hunter", unlocks = Meta.allUnlocked(7, 7), epic = "master_marksman" })
  local bot = ns.Classes.hunter.bot
  assert(bot.epic(exp, "master_marksman") > bot.epic(exp, "call_of_the_wild"), "attachement à l'épique du deck")
end)

ns.Enemies.th_dummy, ns.Enemies.th_hitter, ns.Enemies.th_flurry, ns.Enemies.th_zero = nil, nil, nil, nil

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
