-- Tests des règles. Usage : lua5.1 Sim/tests.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local ns = dofile(root .. "/Sim/load.lua")(root)
local Combat, Card, Rng = ns.Combat, ns.Card, ns.Rng

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

-- Données de test : un ennemi passif et un ennemi qui frappe.
ns.Enemies.test_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.test_hitter = { name = "Cogneur", hp = 100,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }
ns.Enemies.test_caster = { name = "Lanceur", hp = 100,
  moves = { bolt = { name = "Trait", intent = "cast", cast = true, actions = { { "attack", 20 } } } }, pattern = { "bolt" } }
ns.Enemies.test_watcher = { name = "Guetteur", hp = 100,
  moves = { watch = { name = "Guette", intent = "watch", actions = { { "interrupt" } } } }, pattern = { "watch" } }
ns.Enemies.test_boss = { name = "Boss", hp = 100, boss = true,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }

local function deckOf(...)
  local d = {}
  for i, id in ipairs({ ... }) do d[i] = { id = id, up = false } end
  return d
end

-- Combat dont la main de départ est exactement `hand` (le reste en pioche).
local function setup(hand, encounter, extra)
  local deck = deckOf(unpack(hand))
  for _, id in ipairs(extra or {}) do deck[#deck + 1] = { id = id, up = false } end
  local c = Combat.new({ seed = 7, hp = 60, maxHp = 60, deck = deck, encounter = encounter or { "test_dummy" } })
  -- remet la main dans l'ordre demandé
  local all = {}
  for _, x in ipairs(c.hand) do all[#all + 1] = x end
  for _, x in ipairs(c.draw) do all[#all + 1] = x end
  c.hand, c.draw = {}, {}
  for i = 1, #all do
    if i <= #hand then c.hand[#c.hand + 1] = nil end
  end
  local byId = {}
  for _, x in ipairs(all) do byId[x.id] = byId[x.id] or {}; table.insert(byId[x.id], x) end
  for _, id in ipairs(hand) do c.hand[#c.hand + 1] = table.remove(byId[id]) end
  for _, list in pairs(byId) do for _, x in ipairs(list) do c.draw[#c.draw + 1] = x end end
  return c
end

local function handIndex(c, id)
  for i, x in ipairs(c.hand) do if x.id == id then return i end end
end

test("rng déterministe et dans les bornes", function()
  local a, b = Rng.new(42), Rng.new(42)
  for _ = 1, 1000 do
    local x = Rng.int(a, 1, 6)
    eq(x, Rng.int(b, 1, 6))
    assert(x >= 1 and x <= 6)
  end
  local s1, s2 = Rng.stream(1, "draw"), Rng.stream(1, "ai")
  assert(Rng.next(s1) ~= Rng.next(s2), "flux distincts")
end)

test("toutes les cartes ont nom, coût, effets, texte et amélioration", function()
  for id, d in pairs(ns.Cards) do
    assert(d.name and d.cost and d.effects and d.text and d.type and d.rarity, id)
    assert(d.up and d.up.text, id .. " : amélioration manquante")
    local u = Card.defById(id, true)
    assert(u.name:sub(-1) == "+", id)
  end
end)

test("tous les ennemis des rencontres existent et ont des intentions valides", function()
  for _, pools in pairs(ns.Encounters) do
    for _, list in pairs(pools) do
      for _, enc in ipairs(list) do
        for _, id in ipairs(enc) do
          local d = ns.Enemies[id]
          assert(d, "ennemi " .. id)
          for _, mv in ipairs(d.pattern or {}) do assert(d.moves[mv], id .. " : " .. mv) end
        end
      end
    end
  end
end)

test("dégâts, mana, défausse", function()
  local c = setup({ "smite", "smite", "smite", "smite" })
  local e = c.enemies[1]
  assert(Combat.play(c, 1, 1))
  eq(e.hp, 94, "PV ennemi")
  eq(c.player.mana, 2, "mana")
  eq(#c.discard, 1, "défausse")
end)

test("l'Absorption encaisse puis tombe au début du tour", function()
  local c = setup({ "inner_fire" }, { "test_hitter" })
  assert(Combat.play(c, 1))
  eq(c.player.block, 5)
  Combat.endTurn(c)
  eq(c.player.hp, 55, "10 - 5 absorbés")
  eq(c.player.block, 0, "Absorption retombée")
end)

test("Armure fracassée : +25 % de dégâts subis", function()
  local c = setup({ "smite" })
  local e = c.enemies[1]
  Combat.applyStatus(c, e, "armor_broken", 1)
  Combat.play(c, 1, 1)
  eq(e.hp, 100 - 7)
end)

test("Démoralisé posé par l'ennemi dure le tour du joueur suivant", function()
  local c = setup({}, { "test_dummy" })
  c.phase = "enemy"
  Combat.applyStatus(c, c.player, "demoralized", 1)
  Combat.endRound(c)
  eq(c.player.st.demoralized, 1, "survit à la fin du round où il est posé")
  Combat.endRound(c)
  eq(c.player.st.demoralized, nil, "expire au round suivant")
end)

test("Douleur : dégâts en début de tour, ignore l'Absorption, puis baisse", function()
  local c = setup({ "sw_pain" })
  local e = c.enemies[1]
  e.block = 50
  Combat.play(c, 1, 1)
  eq(e.st.pain, 5)
  eq(c.player.demence, 1)
  Combat.endTurn(c)
  eq(e.hp, 95)
  eq(e.st.pain, 4)
end)

test("Recharge : absente N tours, puis revient en main", function()
  local c = setup({ "pw_shield" }, { "test_dummy" }, { "smite", "smite", "smite", "smite", "smite",
    "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite", "smite" })
  Combat.play(c, 1)
  eq(#c.cooldown, 1)
  Combat.endTurn(c) -- tour 2
  assert(not handIndex(c, "pw_shield"), "pas au tour 2")
  Combat.endTurn(c) -- tour 3
  assert(not handIndex(c, "pw_shield"), "pas au tour 3")
  Combat.endTurn(c) -- tour 4
  assert(handIndex(c, "pw_shield"), "revenue au tour 4")
end)

test("Incantation : payée maintenant, résolue au début du tour suivant", function()
  local c = setup({ "holy_fire" })
  local e = c.enemies[1]
  Combat.play(c, 1, 1)
  eq(c.player.mana, 1)
  eq(e.hp, 100, "pas encore")
  assert(c.player.cast)
  Combat.endTurn(c)
  eq(e.hp, 84, "16 au tour suivant")
  eq(e.st.pain, 3)
end)

test("une seule incantation à la fois", function()
  local c = setup({ "holy_fire", "greater_heal" })
  c.player.mana = 5
  Combat.play(c, 1, 1)
  local ok, why = Combat.canPlay(c, 1)
  eq(ok, false)
  eq(why, "casting")
end)

test("Guette coupe l'incantation du joueur", function()
  local c = setup({ "holy_fire" }, { "test_watcher" })
  local e = c.enemies[1]
  Combat.play(c, 1, 1)
  Combat.endTurn(c)
  eq(e.hp, 100, "sort perdu")
  eq(c.player.cast, nil)
end)

test("Silence annule le sort ennemi", function()
  local c = setup({ "silence" }, { "test_caster" })
  Combat.play(c, 1, 1)
  Combat.endTurn(c)
  eq(c.player.hp, 60, "Trait annulé")
  Combat.endTurn(c)
  eq(c.player.hp, 40, "le suivant passe")
end)

test("Expiation : une carte de dégâts rend 2 PV", function()
  local c = setup({ "radiance", "smite" })
  c.player.hp = 50
  Combat.play(c, 1)
  Combat.play(c, 1, 1)
  eq(c.player.hp, 52)
end)

test("Pénitence sous Expiation : 2 Absorption par coup", function()
  local c = setup({ "radiance", "penance" })
  Combat.play(c, 1)
  Combat.play(c, 1, 1)
  eq(c.player.block, 4 + 6)
  eq(c.enemies[1].hp, 88)
end)

test("Étourdi : l'ennemi perd son tour ; les boss y sont immunisés", function()
  local c = setup({ "chastise" }, { "test_hitter" })
  Combat.play(c, 1, 1)
  Combat.endTurn(c)
  eq(c.player.hp, 60, "pas de coup")
  local b = setup({ "chastise" }, { "test_boss" })
  Combat.play(b, 1, 1)
  eq(b.enemies[1].st.stunned, nil)
end)

test("Forme d'ombre : +2 aux cartes d'ombre, cartes sacrées interdites", function()
  local c = setup({ "shadowform", "mind_flay", "smite" })
  Combat.play(c, 1)
  local ok, why = Combat.canPlay(c, handIndex(c, "smite"))
  eq(ok, false); eq(why, "forbidden")
  Combat.play(c, handIndex(c, "mind_flay"), 1)
  eq(c.enemies[1].hp, 94)
end)

test("Esprit de rédemption : reste à 1 PV, tour suivant gratuit", function()
  local c = setup({ "spirit_of_redemption" }, { "test_hitter" }, { "smite" })
  Combat.play(c, 1)
  c.player.hp = 5
  Combat.endTurn(c)
  eq(c.result, nil)
  eq(c.player.hp, 1)
  eq(Combat.cost(c, c.hand[1]), 0)
end)

test("Peste dévorante : dépense la Démence", function()
  local c = setup({ "devouring_plague" })
  eq(Combat.canPlay(c, 1), false, "sans Démence")
  c.player.demence = 3
  Combat.play(c, 1, 1)
  eq(c.player.demence, 0)
  eq(c.enemies[1].st.pain, 6)
end)

test("murlocs : la mort d'un murloc renforce les autres", function()
  local c = setup({ "smite" }, { "murloc", "murloc" })
  c.enemies[1].hp = 3
  Combat.play(c, 1, 1)
  eq(c.enemies[2].st.force, 1)
end)

test("VanCleef appelle deux sbires à 50 % ; sa mort termine le combat", function()
  local c = setup({ "smite" }, { "vancleef" })
  local v = c.enemies[1]
  v.hp = 58
  Combat.play(c, 1, 1)
  eq(#c.enemies, 3)
  v.hp = 1
  Combat.dealDamage(c, c.player, v, 5)
  eq(c.result, "won")
end)

test("clone indépendant de l'original", function()
  local c = setup({ "smite", "smite" })
  local t = Combat.clone(c)
  Combat.play(t, 1, 1)
  eq(c.enemies[1].hp, 100)
  eq(#c.hand, 2)
end)

test("une expédition simulée est reproductible", function()
  local a = ns.Run.play({ seed = 3, bot = "greedy" })
  local b = ns.Run.play({ seed = 3, bot = "greedy" })
  eq(a.floor, b.floor); eq(a.hp, b.hp); eq(a.won, b.won)
end)

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
