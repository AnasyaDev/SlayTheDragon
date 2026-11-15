-- Tests des sept cartes épiques du Mage (docs/zones/cartes-de-zone.md, « Mage ») : cas nominaux et cas
-- limites de la fiche. L'épique est posée dans le deck du combat : ses crochets (deckHooks) sont actifs quelle
-- que soit sa pile, les tests ne dépendent pas de l'endroit où elle se trouve.
-- Usage : lua5.1 Sim/tests_epic_mage.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Save, Combat, Card = ns.Expedition, ns.Save, ns.Combat, ns.Card

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

-- Ennemis de test (retirés à la fin)
local E = ns.Enemies
E.tm_dummy = { name = "Mannequin", hp = 100, moves = { idle = { name = "Rien", intent = "buff", actions = {} } },
  pattern = { "idle" } }
E.tm_hitter = { name = "Cogneur", hp = 100,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }
E.tm_double = { name = "Double", hp = 100,
  moves = { hit = { name = "Deux coups", intent = "attack", actions = { { "attack", 4, times = 2 } } } }, pattern = { "hit" } }
E.tm_boss = { name = "Chef", hp = 200, boss = true,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }

local FILLER = { "mana_shield", "mana_shield", "mana_shield", "mana_shield", "mana_shield", "mana_shield" }

-- Combat du Mage : main imposée, le reste du deck en pioche ; opts.epic (id), opts.up (épique améliorée),
-- opts.encounter, opts.hp.
local function setup(hand, opts)
  opts = opts or {}
  local deck = {}
  for _, id in ipairs(hand) do deck[#deck + 1] = { id = id, up = false } end
  for _, id in ipairs(opts.filler or FILLER) do deck[#deck + 1] = { id = id, up = false } end
  if opts.epic then deck[#deck + 1] = { id = opts.epic, up = opts.up or false } end
  local c = Combat.new({ seed = opts.seed or 7, class = "mage", hp = opts.hp or 60, maxHp = 60, deck = deck,
    encounter = opts.encounter or { "tm_dummy" }, relics = opts.relics })
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

local function idx(c, id)
  for i, x in ipairs(c.hand) do if x.id == id then return i end end
end
local function play(c, id, t)
  local i = assert(idx(c, id), id .. " en main")
  local ok, why = Combat.play(c, i, t)
  assert(ok, id .. " : " .. tostring(why))
end
local function hpLost(c, i) return c.enemies[i].maxHp - c.enemies[i].hp end
-- nombre d'une épique (epicN), base ou améliorée : les tests suivent le réglage
local function N(id, up) return Card.defById(id, up or false).epicN or 0 end
local function power(c, id, up)
  c.player.powers[#c.player.powers + 1] = Card.new(id, up or false, 800 + #c.player.powers)
end

local EPICS = { "mirror_image", "molten_armor", "water_elemental", "fingers_of_frost", "arcane_meditation",
  "conflagration", "rule_of_threes" }
local ZONES = { "westfall", "duskwood", "wetlands", "stranglethorn", "swamp", "steppes", "blackrock" }

---------------------------------------------------------------------------
-- Données communes
---------------------------------------------------------------------------
test("sept épiques : une par zone, epic, Power sans coût ni niveau, texte « Epic. » et nombres", function()
  for i, id in ipairs(EPICS) do
    local d = ns.Cards[id]
    assert(d, id)
    eq(d.class, "mage", id); eq(d.zone, ZONES[i], id); eq(d.rarity, "epic", id); eq(d.type, "power", id)
    assert(d.epic and d.power and d.deckHooks, id .. " : épique, Power, crochets du deck")
    eq(d.cost, 0, id .. " coût (jamais payé)"); eq(d.level, nil, id .. " niveau")
    assert(Card.isEpic(d) and not d.variant)
    for _, up in ipairs({ false, true }) do
      local u = Card.defById(id, up)
      eq(u.text:match("^[^\n]+"), "Epic.", id)
      assert(not u.text:lower():find("you"), id .. " : ni you ni your")
      if u.epicN and u.epicN > 0 then
        assert(u.text:find(tostring(u.epicN), 1, true), id .. (up and "+" or "") .. " : nombre " .. u.epicN .. " dans le texte")
      end
    end
    eq(ns.Meta.zoneCards("mage", ZONES[i])[1], id, id .. " : carte de zone")
  end
  -- jamais dans les récompenses ordinaires
  for _, id in ipairs(Card.pool("mage")) do assert(not ns.Cards[id].epic, "réserve : " .. id) end
end)

test("épique dans le deck : en jeu (c.epic), dans aucune pile, combat sauvegardable", function()
  for _, id in ipairs(EPICS) do
    for _, up in ipairs({ false, true }) do
      local c = setup({ "frostbolt" }, { epic = id, up = up })
      eq(c.epic.id, id); eq(c.epic.up, ns.Card.upValue(up))
      eq(Combat.mageEpic(c), id)
      eq(c.passives, nil, id .. " : pas un passif du deck")
      for _, pile in ipairs({ c.hand, c.draw, c.discard, c.exhaust }) do
        for _, x in ipairs(pile) do assert(x.id ~= id, id .. " : dans une pile") end
      end
      assert(Save.isPlain(c), id .. " : sauvegardable")
    end
  end
end)

---------------------------------------------------------------------------
-- Mirror Image (Westfall)
---------------------------------------------------------------------------
-- coup en plus : epicPct % (50 : la moitié, amélioré 100) des dégâts du premier coup, Charges comprises, arrondi bas
local function MI(full, up) return math.floor(full * Card.defById("mirror_image", up or false).epicPct / 100) end
test("Mirror Image : Cast sous Instant, le premier coup frappe encore (moitié, Charges comprises)", function()
  eq(Card.defById("mirror_image", false).epicPct, 50, "base : la moitié (texte « half »)")
  eq(Card.defById("mirror_image", true).epicPct, 100, "amélioré : tout (texte sans « half »)")
  local c = setup({ "fireball" }, { epic = "mirror_image" })
  c.player.st.instant = 1
  play(c, "fireball", 1)
  eq(hpLost(c, 1), 10 + MI(10), "10, puis la moitié"); eq(c.enemies[1].st.pain, 2)
  local c2 = setup({ "fireball" }, { epic = "mirror_image" })
  c2.player.st.instant, c2.player.res = 1, 3
  play(c2, "fireball", 1)
  eq(hpLost(c2, 1), 13 + MI(13), "3 Charges : 13, puis la moitié de 13")
  local z = setup({ "scorch" }, { epic = "mirror_image" })
  ns.Cards.tm_tiny = { id = "tm_tiny", name = "Tiny", cost = 0, type = "attack", cast = true, target = "enemy",
    effects = { { "damage", 1 } }, text = "Cast.\nDeal 1." }
  z.hand[1] = Card.new("tm_tiny", false, 970)
  z.player.st.instant = 1
  play(z, "tm_tiny", 1)
  eq(hpLost(z, 1), 1 + MI(1), "arrondi bas")
  ns.Cards.tm_tiny = nil
end)

test("Mirror Image : incantation tenue, le coup en plus part à sa résolution ; amélioré", function()
  local c = setup({ "pyroblast" }, { epic = "mirror_image" })
  play(c, "pyroblast", 1)
  eq(hpLost(c, 1), 0, "incantation")
  Combat.endTurn(c)
  eq(hpLost(c, 1), 30 + MI(30), "30, puis 15")
  local u = setup({ "fireball" }, { epic = "mirror_image", up = true })
  u.player.st.instant = 1
  play(u, "fireball", 1)
  eq(hpLost(u, 1), 10 + MI(10, true), "amélioré : 10 encore")
end)

test("Mirror Image : « to all » ne rejoue qu'un coup ; Cast sans dégâts ou interrompu : rien", function()
  local c = setup({ "flamestrike" }, { epic = "mirror_image", encounter = { "tm_dummy", "tm_dummy" } })
  c.player.st.instant = 1
  play(c, "flamestrike")
  eq(hpLost(c, 1) + hpLost(c, 2), 12 + 12 + MI(12), "12 + 12 + un coup de 6")
  local e = setup({ "evocation" }, { epic = "mirror_image" })
  e.player.st.instant = 1
  play(e, "evocation")
  eq(hpLost(e, 1), 0, "Evocation")
  local i = setup({ "fireball" }, { epic = "mirror_image" })
  play(i, "fireball", 1)
  Combat.interruptPlayer(i, i.enemies[1])
  Combat.endTurn(i)
  eq(hpLost(i, 1), 0, "interrompue")
end)

test("Mirror Image : coup de la même carte (Ignite) ; cible tirée au hasard parmi les vivants", function()
  local c = setup({ "fireball" }, { epic = "mirror_image" })
  power(c, "ignite")
  c.player.st.instant = 1
  play(c, "fireball", 1)
  eq(c.enemies[1].st.pain, 3 + 2 + 3, "Ignite sur le coup de la carte et sur le coup en plus")
  eq(hpLost(c, 1), 10 + MI(10))
  local seen = {}
  for seed = 1, 30 do
    local m = setup({ "fireball" }, { epic = "mirror_image", seed = seed, encounter = { "tm_dummy", "tm_dummy", "tm_dummy" } })
    m.player.st.instant = 1
    play(m, "fireball", 1)
    for j = 1, 3 do
      local extra = hpLost(m, j) - (j == 1 and 10 or 0)
      if extra == MI(10) then seen[j] = true end
    end
  end
  assert(seen[1] and seen[2] and seen[3], "chaque ennemi peut être tiré, la cible comprise")
end)

---------------------------------------------------------------------------
-- Molten Armor (Duskwood)
---------------------------------------------------------------------------
test("Molten Armor : chaque attaque ennemie, même absorbée, pose DoT N à son auteur ; un DoT par attaque", function()
  local n, nu = N("molten_armor"), N("molten_armor", true)
  assert(n > 0 and nu > n)
  local c = setup({ "frostbolt" }, { epic = "molten_armor", encounter = { "tm_hitter" } })
  c.player.block = 30
  Combat.endTurn(c)
  eq(c.player.hp, 60, "coup absorbé"); eq(c.enemies[1].st.pain, n, "brûle quand même")
  eq(c.enemies[1].stIcon.pain, "burn")
  c.player.block = 30
  Combat.endTurn(c)
  eq(c.enemies[1].st.pain, n - 1 + n, "attaque suivante : un DoT de plus (après le tic)")
  local d = setup({ "frostbolt" }, { epic = "molten_armor", encounter = { "tm_double" } })
  Combat.endTurn(d)
  eq(d.enemies[1].st.pain, n, "deux coups, une attaque : un DoT")
  local two = setup({ "frostbolt" }, { epic = "molten_armor", encounter = { "tm_hitter", "tm_double" } })
  Combat.endTurn(two)
  eq(two.enemies[1].st.pain, n); eq(two.enemies[2].st.pain, n, "chaque attaquant")
  local u = setup({ "frostbolt" }, { epic = "molten_armor", up = true, encounter = { "tm_hitter" } })
  Combat.endTurn(u)
  eq(u.enemies[1].st.pain, nu, "amélioré")
end)

test("Molten Armor : rien sur un ennemi qui n'attaque pas, Stunned, ou mort", function()
  local c = setup({ "frostbolt" }, { epic = "molten_armor", encounter = { "tm_dummy", "tm_hitter" } })
  c.enemies[2].st.stunned = 1
  Combat.endTurn(c)
  eq(c.enemies[1].st.pain, nil, "n'attaque pas"); eq(c.enemies[2].st.pain, nil, "Stunned")
  local hook = ns.Cards.molten_armor.deckHooks.afterHit
  c.enemies[2].dead = true
  hook(c, c.epic, c.enemies[2], 0, 10)
  eq(c.enemies[2].st.pain, nil, "auteur mort")
end)

---------------------------------------------------------------------------
-- Water Elemental (Wetlands)
---------------------------------------------------------------------------
test("Water Elemental : chaque tour, N à la dernière cible (sinon la plus à gauche) et Demoralized 1 jusqu'à la fin du tour", function()
  local n = N("water_elemental")
  assert(n > 0 and N("water_elemental", true) > n)
  eq(ns.Cards.water_elemental.epicPeriod, nil, "chaque tour")
  local c = setup({ "frostbolt" }, { epic = "water_elemental", encounter = { "tm_dummy", "tm_dummy" } })
  eq(hpLost(c, 1), n, "dès le premier tour ; sans dernière cible : la plus à gauche"); eq(hpLost(c, 2), 0)
  eq(c.enemies[1].st.demoralized, 1, "Frozen pendant le tour")
  assert(Combat.isFrozen(c.enemies[1]))
  Combat.endPlayerTurn(c)
  eq(c.enemies[1].st.demoralized, nil, "fin du tour : le gel de l'élémentaire s'en va")
  Combat.enemyPhase(c); Combat.endRound(c); Combat.startPlayerTurn(c)
  eq(hpLost(c, 1), 2 * n, "tour suivant : encore")
  c.hand[#c.hand + 1] = Card.new("frostbolt", false, 950)
  c.player.res, c.player.mana = 4, 3
  play(c, "frostbolt", 2)
  eq(hpLost(c, 2), 6 + 4)
  Combat.endTurn(c)
  eq(hpLost(c, 2), 6 + 4 + n, "dernière cible ; Charges sans effet sur l'élémentaire")
  eq(c.enemies[2].st.demoralized, 1, "Frostbolt (1, retombé en fin de round), puis élémentaire (1)")
end)

test("Water Elemental : le tour ennemi garde le Demoralized des cartes, pas celui de l'élémentaire ; boss ; amélioré", function()
  local c = setup({ "frostbolt" }, { epic = "water_elemental", encounter = { "tm_hitter" } })
  eq(c.enemies[1].st.demoralized, 1)
  local hp = c.player.hp
  Combat.endTurn(c)
  eq(hp - c.player.hp, 10, "coup de 10 : le gel de l'élémentaire est parti")
  c.hand[#c.hand + 1] = Card.new("frostbolt", false, 951)
  play(c, "frostbolt", 1)
  hp = c.player.hp
  Combat.endTurn(c)
  eq(hp - c.player.hp, 7, "Frostbolt : Demoralized tient le tour ennemi")
  local d = setup({ "frostbolt" }, { epic = "water_elemental", encounter = { "tm_dummy", "tm_dummy", "tm_dummy" } })
  d.player.lastTarget = d.enemies[2].uid
  d.enemies[2].dead = true
  d.enemies[1].dead = true
  eq(Combat.elementalTarget(d), d.enemies[3])
  local b = setup({ "frostbolt" }, { epic = "water_elemental", encounter = { "tm_boss" } })
  eq(b.enemies[1].st.demoralized, 1, "Demoralized prend sur un boss"); eq(hpLost(b, 1), N("water_elemental"))
  local u = setup({ "frostbolt" }, { epic = "water_elemental", up = true })
  eq(hpLost(u, 1), N("water_elemental", true), "amélioré")
end)

test("Water Elemental : un dormeur n'est visé que si tous dorment", function()
  local c = setup({ "frostbolt" }, { epic = "water_elemental", encounter = { "tm_dummy", "tm_dummy" } })
  c.enemies[1].st.asleep = 2
  eq(Combat.elementalTarget(c), c.enemies[2])
  c.player.lastTarget = c.enemies[1].uid
  eq(Combat.elementalTarget(c), c.enemies[2], "dernière cible endormie")
  c.enemies[2].st.asleep = 2
  eq(Combat.elementalTarget(c), c.enemies[1], "tous dorment")
end)

---------------------------------------------------------------------------
-- Fingers of Frost (Stranglethorn Vale)
---------------------------------------------------------------------------
test("Fingers of Frost : Cast sur un ennemi Frozen résolu tout de suite, sans Instant consommé", function()
  local c = setup({ "frostbolt", "fireball", "fireball" }, { epic = "fingers_of_frost", encounter = { "tm_dummy", "tm_dummy" } })
  c.player.st.instant = 1
  play(c, "frostbolt", 1)
  play(c, "fireball", 1)
  eq(hpLost(c, 1), 6 + 10, "Fireball partie"); eq(c.player.cast, nil, "aucune incantation tenue")
  eq(c.player.st.instant, 1, "Instant gardé")
  eq(c.enemies[1].st.demoralized, nil, "le gel employé s'en va"); assert(not Combat.isFrozen(c.enemies[1]))
  play(c, "fireball", 2)
  eq(c.player.st.instant, nil, "cible non Frozen : l'Instant sert")
  eq(hpLost(c, 2), 10)
end)

test("Fingers of Frost : cible non Frozen, incantation ; emplacements pleins : seulement sur une cible Frozen", function()
  local c = setup({ "fireball", "pyroblast", "fireball", "glacial_spike" },
    { epic = "fingers_of_frost", encounter = { "tm_dummy", "tm_dummy" } })
  c.player.mana = 9
  play(c, "fireball", 1)
  play(c, "pyroblast", 1)
  eq(Combat.castCount(c), 2, "deux incantations")
  -- ni l'une ni l'autre Frozen : injouable
  local ok, why = Combat.canPlay(c, idx(c, "fireball"))
  assert(not ok and why == "casting", "injouable sans ennemi Frozen")
  Combat.applyStatus(c, c.enemies[2], "demoralized", 1)
  assert(Combat.canPlay(c, idx(c, "fireball")), "jouable : un ennemi Frozen")
  local targets = {}
  for _, p in ipairs(Combat.legalPlays(c)) do if p[1] == idx(c, "fireball") then targets[#targets + 1] = p[2] end end
  eq(#targets, 1, "une seule cible légale"); eq(targets[1], 2)
  local last = c.player.lastTarget
  local ok2, why2 = Combat.play(c, idx(c, "fireball"), 1)
  assert(not ok2 and why2 == "casting", "refusée sur la cible non Frozen")
  eq(c.player.lastTarget, last, "dernière cible inchangée")
  eq(c.player.mana, 6, "rien payé")
  play(c, "fireball", 2)
  eq(hpLost(c, 2), 10); eq(Combat.castCount(c), 2)
end)

test("Fingers of Frost : Cast sans cible reste un Cast ; Stunned compte ; boss Demoralized ; amélioré + 4", function()
  local c = setup({ "flamestrike" }, { epic = "fingers_of_frost" })
  Combat.applyStatus(c, c.enemies[1], "stunned", 1)
  play(c, "flamestrike")
  eq(Combat.castCount(c), 1, "Flamestrike incantée")
  local s = setup({ "fireball" }, { epic = "fingers_of_frost" })
  Combat.applyStatus(s, s.enemies[1], "stunned", 1)
  play(s, "fireball", 1)
  eq(hpLost(s, 1), 10, "Stunned = Frozen"); eq(s.enemies[1].st.stunned, nil, "Stunned employé")
  local b = setup({ "glacial_spike" }, { epic = "fingers_of_frost", encounter = { "tm_boss" } })
  Combat.applyStatus(b, b.enemies[1], "demoralized", 1)
  play(b, "glacial_spike", 1)
  eq(hpLost(b, 1), 26, "boss Demoralized"); eq(b.enemies[1].st.demoralized, 2, "le gel employé part, celui de la carte reste")
  local u = setup({ "fireball", "frostbolt" }, { epic = "fingers_of_frost", up = true })
  Combat.applyStatus(u, u.enemies[1], "demoralized", 1)
  play(u, "fireball", 1)
  eq(hpLost(u, 1), 14, "amélioré : 4 de plus")
  play(u, "frostbolt", 1)
  eq(hpLost(u, 1), 20, "seulement la carte partie par Fingers")
end)

---------------------------------------------------------------------------
-- Arcane Meditation (Swamp of Sorrows)
---------------------------------------------------------------------------
local function AB(up) return Card.defById("arcane_meditation", up or false).epicBonus or 0 end
test("Arcane Meditation : le mana non dépensé (N au plus) s'ajoute au tour suivant, + B s'il en reste", function()
  local k, ku = N("arcane_meditation"), N("arcane_meditation", true)
  local b, bu = AB(), AB(true)
  assert(k >= 3 and ku > k and b > 0 and bu > b)
  for _, up in ipairs({ false, true }) do
    -- carte (« Conserve N ») et à-côté de son mot de règle (« … +B if any »)
    local d = Card.defById("arcane_meditation", up)
    local t = d.text
    for _, r in ipairs(ns.Language.ruleWords(d)) do t = t .. "\n" .. ns.Language.ruleText(r.kw, r.n, up) end
    -- améliorée (paliers 1 à 3) : « plus a third of N » (bonus = N / 3, tests des paliers plus bas)
    assert(t:find("Conserve " .. (up and ku or k), 1, true) and (up and t:find("plus a third of " .. ku .. " if any", 1, true)
      or not up and t:find("+" .. b .. " if any", 1, true)), "nombres dans le texte")
    if up then eq(bu * 3, ku, "bonus = tiers de N") end
  end
  local c = setup({ "frostbolt" }, { epic = "arcane_meditation" })
  Combat.endTurn(c)
  eq(c.player.mana, 3 + 3 + b, "3 gardés, + B")
  c.player.mana = 1
  Combat.endTurn(c)
  eq(c.player.mana, 3 + 1 + b, "1 gardé, + B")
  c.player.mana = k + 3
  Combat.endTurn(c)
  eq(c.player.mana, 3 + k + b, "plafond, aucun cumul sur deux tours")
  c.player.mana = 0
  Combat.endTurn(c)
  eq(c.player.mana, 3, "rien gardé : pas de bonus")
  local u = setup({ "frostbolt" }, { epic = "arcane_meditation", up = true })
  u.player.mana = ku + 2
  Combat.endTurn(u)
  eq(u.player.mana, 3 + ku + bu, "amélioré")
end)

test("Arcane Meditation : Evocation s'ajoute ; état sauvegardable entre deux tours", function()
  local c = setup({ "evocation" }, { epic = "arcane_meditation" })
  play(c, "evocation")
  Combat.endPlayerTurn(c)
  eq(c.cls.carry, 3 + AB())
  assert(Save.isPlain(c))
  Combat.enemyPhase(c)
  Combat.endRound(c)
  Combat.startPlayerTurn(c)
  eq(c.player.mana, 3 + 3 + 3 + AB(), "maximum + Evocation + report"); eq(c.cls.carry, nil)
end)

---------------------------------------------------------------------------
-- Conflagration (Burning Steppes)
---------------------------------------------------------------------------
test("Conflagration : un ennemi tué avec du DoT le donne à chaque autre ennemi", function()
  local c = setup({ "scorch" }, { epic = "conflagration", encounter = { "tm_dummy", "tm_dummy", "tm_dummy" } })
  c.enemies[1].hp, c.enemies[1].st.pain = 2, 4
  c.enemies[3].st.pain = 1
  play(c, "scorch", 1)
  assert(c.enemies[1].dead)
  local n = N("conflagration")
  eq(c.enemies[2].st.pain, 4 + n); eq(c.enemies[3].st.pain, 1 + 4 + n, "s'ajoute")
  local u = setup({ "scorch" }, { epic = "conflagration", up = true, encounter = { "tm_dummy", "tm_dummy" } })
  u.enemies[1].hp, u.enemies[1].st.pain = 2, 4
  play(u, "scorch", 1)
  assert(N("conflagration", true) > n)
  eq(u.enemies[2].st.pain, 4 + N("conflagration", true), "amélioré")
end)

test("Conflagration : mort par son tic = valeur du tic ; chaîne ; sans DoT ou seul : rien ; sans crochet apply", function()
  local c = setup({ "frostbolt" }, { epic = "conflagration", encounter = { "tm_dummy", "tm_dummy", "tm_dummy" } })
  c.enemies[1].hp, c.enemies[1].st.pain = 5, 5
  c.enemies[2].hp = 4
  -- Power de test : tout état posé par le crochet « apply » vaut dix fois plus ; la transmission l'ignore
  ns.Cards.tm_apply_x10 = { id = "tm_apply_x10", name = "x10", type = "power", power = true, effects = {}, text = "",
    hooks = { apply = function(_, _, v) return v * 10 end } }
  power(c, "tm_apply_x10")
  Combat.endTurn(c)
  assert(c.enemies[1].dead, "mort par son tic")
  -- l'ennemi 2 reçoit 5 + N, tique au même tour ennemi (il agit après) : mort, chaîne vers le 3
  local n = N("conflagration")
  assert(c.enemies[2].dead, "chaîne")
  eq(c.enemies[3].st.pain, (5 + n) + (5 + n + n) - 1, "deux transmissions, un tic")
  local s = setup({ "scorch" }, { epic = "conflagration", encounter = { "tm_dummy", "tm_dummy" } })
  s.enemies[1].hp = 2
  play(s, "scorch", 1)
  eq(s.enemies[2].st.pain, nil, "sans DoT")
  local a = setup({ "scorch" }, { epic = "conflagration" })
  a.enemies[1].hp, a.enemies[1].st.pain = 2, 3
  play(a, "scorch", 1)
  eq(a.result, "won", "seul : rien")
end)

---------------------------------------------------------------------------
-- Rule of Threes (Blackrock Mountain)
---------------------------------------------------------------------------
local K3 = ns.Cards.rule_of_threes.epicCharge -- Charges dépensées par la copie
test("Rule of Threes : la 3e carte de chaque tour se résout deux fois pour K Charges, sans coût en mana ; pas la 6e", function()
  assert(K3 and K3 > 0)
  eq(ns.Cards.rule_of_threes.epicPeriod, nil, "chaque tour")
  local c = setup({ "ice_lance", "ice_lance", "ice_lance", "scorch", "scorch", "scorch" }, { epic = "rule_of_threes" })
  c.player.res = K3 + 1
  play(c, "ice_lance", 1); play(c, "ice_lance", 1)
  eq(hpLost(c, 1), 2 * (3 + K3 + 1))
  play(c, "ice_lance", 1)
  eq(c.player.res, 1, "K Charges dépensées au jeu")
  eq(hpLost(c, 1), 2 * (3 + K3 + 1) + 2 * (3 + 1), "3e : deux fois (avec la Charge restante)"); eq(c.player.mana, 3, "sans coût")
  play(c, "scorch", 1); play(c, "scorch", 1); play(c, "scorch", 1)
  eq(hpLost(c, 1), 2 * (3 + K3 + 1) + 2 * 4 + 3 * 4, "6e : une fois (base)")
  local u = setup({ "ice_lance", "ice_lance", "ice_lance", "scorch", "scorch", "scorch" }, { epic = "rule_of_threes", up = true })
  u.player.res = 2 * K3
  for _ = 1, 3 do play(u, "ice_lance", 1) end
  for _ = 1, 3 do play(u, "scorch", 1) end
  eq(u.player.res, 0, "amélioré : la 3e et la 6e")
  local r = setup({ "ice_lance", "ice_lance" }, { epic = "rule_of_threes", filler = { "ice_lance", "ice_lance", "ice_lance",
    "ice_lance", "ice_lance", "ice_lance" } })
  local function three(c)
    c.hand = { Card.new("ice_lance", false, 960), Card.new("ice_lance", false, 961), Card.new("ice_lance", false, 962) }
    local before = hpLost(c, 1)
    for _ = 1, 3 do play(c, "ice_lance", 1) end
    return hpLost(c, 1) - before
  end
  play(r, "ice_lance", 1); play(r, "ice_lance", 1)
  Combat.endTurn(r)
  eq(three(r), 9, "sans Charge : une fois")
  Combat.endTurn(r)
  r.player.res = K3
  eq(three(r), 2 * (3 + K3) + 3 + 3, "tour suivant : compte remis à 0, la 3e deux fois (Charges dépensées avant elle)")
end)

test("Rule of Threes : Cast en 3e, deux résolutions à son départ", function()
  local c = setup({ "ice_lance", "ice_lance", "fireball" }, { epic = "rule_of_threes" })
  c.player.res = K3
  play(c, "ice_lance", 1); play(c, "ice_lance", 1); play(c, "fireball", 1)
  eq(c.player.res, 0)
  Combat.endTurn(c)
  eq(hpLost(c, 1), 2 * (3 + K3) + 20, "deux résolutions"); eq(c.enemies[1].st.pain, 2 + 2, "deux DoT")
end)

test("Rule of Threes : Arcane Barrage en 3e compte le même Surge (après les K Charges) ; Polymorph : Stunned 4, une Exhaust", function()
  local c = setup({ "ice_lance", "ice_lance", "arcane_barrage" }, { epic = "rule_of_threes", encounter = { "tm_dummy", "tm_dummy" } })
  c.player.res = K3 + 2
  play(c, "ice_lance", 1); play(c, "ice_lance", 1)
  local a, b = hpLost(c, 1), hpLost(c, 2)
  play(c, "arcane_barrage")
  eq(hpLost(c, 1) - a, 24, "2 × 12 sur la cible"); eq(hpLost(c, 2) - b, 24, "à tous"); eq(c.player.res, 0)
  local p = setup({ "ice_lance", "ice_lance", "polymorph", "scorch" }, { epic = "rule_of_threes", encounter = { "tm_dummy", "tm_dummy" } })
  p.player.mana, p.player.res = 5, K3
  play(p, "ice_lance", 1); play(p, "ice_lance", 1); play(p, "polymorph", 2)
  eq(p.enemies[2].st.stunned, 4, "Skill en 3e : deux fois"); eq(p.player.res, 2, "+1 Charge deux fois")
  local n = 0
  for _, x in ipairs(p.exhaust) do if x.id == "polymorph" then n = n + 1 end end
  eq(n, 1, "consumée une fois")
end)

test("Rule of Threes : sans assez de Charges, la 3e ne se résout qu'une fois mais compte ; PV jamais payés", function()
  local p = setup({ "ice_lance", "ice_lance", "polymorph", "scorch" }, { epic = "rule_of_threes", encounter = { "tm_dummy", "tm_dummy" } })
  p.player.mana, p.player.res = 5, K3 - 1
  local hp = p.player.hp
  play(p, "ice_lance", 1); play(p, "ice_lance", 1); play(p, "polymorph", 2)
  eq(p.enemies[2].st.stunned, 2, "une fois"); eq(p.player.res, K3, "Charges gardées, +1")
  eq(p.player.hp, hp, "aucun PV payé")
  local before = hpLost(p, 1)
  play(p, "scorch", 1)
  eq(hpLost(p, 1) - before, 3 + K3, "4e carte : une fois")
end)

---------------------------------------------------------------------------
-- Bots et simulation
---------------------------------------------------------------------------
test("bots : note des épiques, l'épique du deck vaut plus ; conseils de construction de chaque épique", function()
  local b = ns.Classes.mage.bot
  for _, id in ipairs(EPICS) do
    assert(b.epic({ deck = {} }, id), id .. " : note")
    assert(b.byEpic[id] and b.byEpic[id].rating and b.byEpic[id].upgrade and b.byEpic[id].remove, id .. " : conseils")
  end
  local exp = X.new({ seed = 2, class = "mage", unlocks = ns.Meta.allUnlocked(7, 7), epic = "rule_of_threes" })
  assert(b.epic(exp, "rule_of_threes") > b.epic(exp, "mirror_image"), "construit autour")
  local rec, e2 = ns.SimExpedition.play({ seed = 4, class = "mage", epic = "water_elemental", zones = 7 })
  assert(rec and e2.phase == "done")
end)

---------------------------------------------------------------------------
-- Paliers 2 et 3 des épiques (15/11/2026, docs/ameliorations.md ; tableau : docs/classes/mage.md) : les crochets
-- lisent leurs nombres dans Card.def(src), fiche effective au palier de src (Card.level).
---------------------------------------------------------------------------
test("paliers : sept épiques à trois paliers, nombres croissants lus au palier de la source", function()
  local field = { mirror_image = "epicPct", molten_armor = "epicN", water_elemental = "epicN", fingers_of_frost = "epicN",
    arcane_meditation = "epicBonus", conflagration = "epicN" }
  for _, id in ipairs(EPICS) do
    eq(Card.tiers(id), 3, id)
    local k = field[id]
    if k then
      for n = 1, 3 do
        local a, b = Card.defById(id, n - 1)[k] or 0, Card.defById(id, n)[k] or 0
        assert(b > a, id .. "+" .. n .. " : " .. k .. " " .. a .. " -> " .. b)
        eq(Card.def({ id = id, up = n, uid = 1 })[k], b, id .. " : lu au palier de l'instance")
      end
    end
  end
end)

test("paliers : Mirror Image +2 / +3 (125 %, 150 %), Molten Armor +3, Water Elemental +3, Conflagration +3", function()
  for n = 2, 3 do
    local c = setup({ "fireball" }, { epic = "mirror_image", up = n })
    c.player.st.instant = 1
    play(c, "fireball", 1)
    local pct = Card.defById("mirror_image", n).epicPct
    eq(hpLost(c, 1), 10 + math.floor(10 * pct / 100), "Mirror Image+" .. n)
  end
  local m = setup({ "frostbolt" }, { epic = "molten_armor", up = 3, encounter = { "tm_hitter" } })
  Combat.endTurn(m)
  eq(m.enemies[1].st.pain, N("molten_armor", 3))
  local w = setup({ "frostbolt" }, { epic = "water_elemental", up = 3 })
  eq(hpLost(w, 1), N("water_elemental", 3)); eq(w.enemies[1].st.demoralized, 1)
  local f = setup({ "scorch" }, { epic = "conflagration", up = 3, encounter = { "tm_dummy", "tm_dummy" } })
  f.enemies[1].hp, f.enemies[1].st.pain = 2, 4
  play(f, "scorch", 1)
  eq(f.enemies[2].st.pain, 4 + N("conflagration", 3))
end)

test("paliers : Fingers of Frost +3 (+8), Arcane Meditation +2 (Conserve 9, +3) et +3 (Conserve 12, +4)", function()
  local u = setup({ "fireball" }, { epic = "fingers_of_frost", up = 3 })
  Combat.applyStatus(u, u.enemies[1], "demoralized", 1)
  play(u, "fireball", 1)
  eq(hpLost(u, 1), 10 + N("fingers_of_frost", 3))
  for n = 2, 3 do
    local d = Card.defById("arcane_meditation", n)
    eq(d.epicBonus * 3, d.epicN, "bonus = tiers de N (texte amélioré)")
    local c = setup({ "frostbolt" }, { epic = "arcane_meditation", up = n })
    c.player.mana = d.epicN + 2
    Combat.endTurn(c)
    eq(c.player.mana, 3 + d.epicN + d.epicBonus, "Arcane Meditation+" .. n)
  end
end)

test("paliers : Rule of Threes +2 double la 2e carte du tour (pas la 4e), +3 chaque 2e (2e, 4e)", function()
  local function run(n)
    local c = setup({ "ice_lance", "ice_lance", "ice_lance", "ice_lance" }, { epic = "rule_of_threes", up = n })
    c.player.res = 4
    local res = {}
    for i = 1, 4 do
      play(c, "ice_lance", 1)
      res[i] = c.player.res
    end
    return res
  end
  local r2, r3 = run(2), run(3)
  eq(table.concat(r2, ","), "4,3,3,3", "+2 : la 2e seulement")
  eq(table.concat(r3, ","), "4,3,3,2", "+3 : la 2e et la 4e")
  local c = setup({ "ice_lance", "ice_lance" }, { epic = "rule_of_threes", up = 2 })
  c.player.res = 1
  play(c, "ice_lance", 1)
  local before = hpLost(c, 1)
  play(c, "ice_lance", 1)
  eq(hpLost(c, 1) - before, 2 * (3 + 0), "2e carte jouée deux fois (Charge dépensée avant)")
  local src = { id = "rule_of_threes", up = 3, uid = 1 }
  c.turn.played = 3
  assert(Combat.ruleOfThreesNext(c, src), "vue : la 4e sera doublée")
  c.turn.played = 2
  assert(not Combat.ruleOfThreesNext(c, src))
end)

ns.Cards.tm_apply_x10 = nil
for _, id in ipairs({ "tm_dummy", "tm_hitter", "tm_double", "tm_boss" }) do E[id] = nil end

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
