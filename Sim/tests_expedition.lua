-- Tests de l'expédition, de la méta-progression et de la sauvegarde.
-- Usage : lua5.1 Sim/tests_expedition.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Map, Meta, Save, Combat, Rng = ns.Expedition, ns.Map, ns.Meta, ns.Save, ns.Combat, ns.Rng

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

---------------------------------------------------------------------------
-- Sérialisation façon SavedVariables (clés triées : deux états égaux donnent le même texte)
---------------------------------------------------------------------------
local function ser(v, out)
  local t = type(v)
  if t == "number" then out[#out + 1] = string.format("%.17g", v)
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "boolean" then out[#out + 1] = tostring(v)
  elseif t == "table" then
    assert(getmetatable(v) == nil, "métatable")
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      if type(a) ~= type(b) then return type(a) < type(b) end
      if type(a) == "boolean" then return (a and 1 or 0) < (b and 1 or 0) end
      return a < b
    end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      out[#out + 1] = "["
      ser(k, out)
      out[#out + 1] = "]="
      ser(v[k], out)
      out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  else
    error("valeur non sauvegardable : " .. t)
  end
end
local function serialize(v) local o = {}; ser(v, o); return table.concat(o) end
local function reload(v) return assert(loadstring("return " .. serialize(v)))() end

---------------------------------------------------------------------------
-- Données de test
---------------------------------------------------------------------------
ns.Enemies.test_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.test_elite = { name = "Élite", hp = 100, elite = true,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }
ns.Enemies.test_hitter = { name = "Cogneur", hp = 100,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }

ns.Relics.test_purse = { name = "Bourse", text = "Or ×2.", rarity = "common", tier = 0,
  run = { gold = function(run, v) return v * 2 end } }
ns.Relics.test_heart = { name = "Cœur", text = "+10 PV max.", rarity = "uncommon", tier = 0,
  run = { onPickup = function(run) run.maxHp = run.maxHp + 10; run.hp = run.hp + 10 end } }
ns.Relics.test_pillow = { name = "Oreiller", text = "Repos +5.", rarity = "rare", tier = 0,
  run = { restHeal = function(run, v) return v + 5 end } }
ns.Relics.test_charm = { name = "Breloque", text = "Rien.", rarity = "common", tier = 0 }
ns.Relics.test_boss ={ name = "Trophée", text = "Boss.", rarity = "boss", tier = 0 }
ns.Relics.test_league = { name = "Carte de la Ligue", text = "Tier 2.", rarity = "common", tier = 2 }
ns.Relics.test_class = { name = "Symbole sacré", text = "Prêtre.", rarity = "rare", tier = 0, class = "priest" }
ns.Potions.test_potion = { name = "Potion", text = "Soigne 15.", rarity = "common", tier = 0, effects = {} }
ns.Potions.test_potion2 = { name = "Potion bis", text = "+2 mana.", rarity = "uncommon", tier = 0, effects = {} }

-- Les relics de test qui touchent à l'or et au repos faussent certains tests : on les
-- retire du tirage le temps d'un test.
local RUN_RELICS = { "test_purse", "test_heart", "test_pillow" }
local function withoutRunRelics(f)
  for _, id in ipairs(RUN_RELICS) do ns.Relics[id].noPool = true end
  local ok, err = pcall(f)
  for _, id in ipairs(RUN_RELICS) do ns.Relics[id].noPool = nil end
  if not ok then error(err, 0) end
end

local function newExp(opts)
  opts = opts or {}
  opts.seed = opts.seed or 11
  if opts.quiet == nil then opts.quiet = true end
  return X.new(opts)
end

-- Force le type du premier nœud de départ et y entre.
local function enter(exp, kind)
  local id = exp.map.start[1]
  exp.map.nodes[id].kind = kind
  assert(X.act(exp, { "path", id }))
  return id
end

-- Gagne le combat en cours : Douleur mortelle sur chaque ennemi, puis fin de tour.
local function winCombat(exp)
  local c = exp.combat
  for _, e in ipairs(c.enemies) do
    if not e.dead then
      e.hp = 1
      e.block = 0
      e.st.pain = 5
    end
  end
  assert(X.act(exp, { "endTurn" }))
  if exp.phase == "combat" then assert(X.act(exp, { "endTurn" })) end
end

local function count(t, v)
  local n = 0
  for _, x in ipairs(t) do if x == v then n = n + 1 end end
  return n
end

---------------------------------------------------------------------------
-- Carte
---------------------------------------------------------------------------

test("carte valide pour 300 graines, 2 à 3 nœuds par étape, boss unique", function()
  local fallbacks = 0
  for s = 1, 300 do
    local m = Map.generate(Rng.stream(s, "map"), 1)
    local ok, why = Map.validate(m)
    assert(ok, "graine " .. s .. " : " .. tostring(why))
    if m.fallback then fallbacks = fallbacks + 1 end
    for f = 1, Map.FLOORS do
      local n = #Map.floorNodes(m, f)
      assert(n >= 2 and n <= 3, "largeur")
    end
    local b = Map.floorNodes(m, Map.FLOORS + 1)
    eq(#b, 1, "boss")
    eq(b[1].kind, "boss")
    for _, node in ipairs(Map.floorNodes(m, 1)) do eq(node.kind, "combat", "étape 1") end
    for _, node in ipairs(Map.floorNodes(m, Map.FLOORS)) do eq(node.kind, "campfire", "étape 7") end
  end
  assert(fallbacks < 10, "trop de cartes de secours : " .. fallbacks)
end)

test("carte reproductible et chemins qui se croisent", function()
  local a = Map.generate(Rng.stream(5, "map"), 1)
  local b = Map.generate(Rng.stream(5, "map"), 1)
  eq(serialize(a), serialize(b))
  local merges = 0
  for s = 1, 50 do
    local m = Map.generate(Rng.stream(s, "map"), 1)
    local parents = {}
    for _, node in ipairs(m.nodes) do
      for _, nx in ipairs(node.next) do parents[nx] = (parents[nx] or 0) + 1 end
    end
    for id, n in pairs(parents) do
      if n > 1 and m.nodes[id].kind ~= "boss" then merges = merges + 1 end
    end
  end
  assert(merges > 50, "les chemins doivent se rejoindre")
end)

---------------------------------------------------------------------------
-- Expédition
---------------------------------------------------------------------------

test("nouvelle expédition : carte, deck de départ, 3 emplacements de potion", function()
  local exp = newExp()
  eq(exp.phase, "map")
  eq(#exp.deck, 10)
  eq(#exp.potions, 3)
  eq(exp.potions[1], false)
  eq(exp.gold, X.START_GOLD)
  local ch = X.choices(exp)
  eq(#ch, #exp.map.start)
  eq(ch[1][1], "path")
  assert(Save.isPlain(exp))
  local ok, why = X.act(exp, { "path", 999 })
  eq(ok, false, "chemin hors carte")
end)

test("combat : récompense tirée à l'entrée, identique après rechargement", function()
  withoutRunRelics(function()
    local exp = newExp()
    enter(exp, "elite")
    eq(exp.phase, "combat")
    local pending = serialize(exp.fight.reward)
    assert(exp.fight.reward.relic, "bibelot d'élite tiré à l'entrée")
    local copy = reload(exp)
    winCombat(exp)
    winCombat(copy)
    eq(exp.phase, "reward")
    eq(serialize(exp.reward), serialize(copy.reward), "même récompense après rechargement")
    eq(serialize(exp.fight == nil and copy.fight == nil), "true")
    local r = exp.reward
    assert(r.goldGained >= 25 and r.goldGained <= 35, "or d'élite")
    eq(exp.relics[1], r.relic, "bibelot pris")
    eq(#r.cards, 3)
    -- le tirage stocké avant le combat est bien celui qu'on reçoit
    local before = assert(loadstring("return " .. pending))()
    eq(serialize(before.cards), serialize(r.cards))
    eq(exp.stats.elites, 1)
    -- rechargement en pleine récompense : rien ne change, on peut toujours choisir
    local again = reload(exp)
    assert(X.act(again, { "pickCard", 2 }))
    eq(again.deck[#again.deck].id, r.cards[2])
    assert(X.act(again, { "leave" }))
    eq(again.phase, "map")
    eq(again.stats.cleared, 1)
  end)
end)

test("récompense : passer la carte, potion en emplacement libre", function()
  local exp = newExp()
  enter(exp, "combat")
  exp.fight.reward.potion = "test_potion"
  exp.fight.reward.gold = 15
  winCombat(exp)
  eq(exp.gold, X.START_GOLD + 15)
  eq(exp.potions[1], "test_potion")
  assert(X.act(exp, { "skipCards" }))
  eq(X.act(exp, { "pickCard", 1 }), false, "plus de carte après avoir passé")
  assert(X.act(exp, { "leave" }))
  eq(#exp.deck, 10)
end)

test("défaite : l'expédition se termine", function()
  local exp = newExp()
  enter(exp, "combat")
  exp.combat.player.hp = 1
  exp.combat.enemies[1].st.force = 99
  -- frappe jusqu'à la mort (au plus quelques tours)
  for _ = 1, 10 do
    if exp.phase ~= "combat" then break end
    X.act(exp, { "endTurn" })
  end
  eq(exp.phase, "done")
  eq(exp.result, "lost")
  assert(exp.killedBy)
  eq(X.act(exp, { "path", 1 }), false)
end)

test("feu de camp : repos 30 %, amélioration, Disette 20 %", function()
  local exp = newExp()
  enter(exp, "campfire")
  exp.hp = 20
  assert(X.act(exp, { "rest" }))
  eq(exp.hp, 20 + math.floor(65 * 0.30))
  eq(exp.phase, "map")
  local b = newExp()
  enter(b, "campfire")
  eq(X.act(b, { "upgrade", 1 }), true)
  eq(b.deck[1].up, true)
  local c = newExp()
  enter(c, "campfire")
  assert(not X.act(c, { "upgrade", 99 }))
  local d = newExp({ key = 5 })
  enter(d, "campfire")
  d.hp = 20
  X.act(d, { "rest" })
  eq(d.hp, 20 + math.floor(65 * 0.20), "Disette")
end)

test("marchand : achats, retrait au prix croissant, emplacements de potion", function()
  local exp = newExp()
  enter(exp, "merchant")
  eq(exp.phase, "merchant")
  local s = exp.shop
  eq(#s.cards, 5)
  eq(#s.relics, 3)
  eq(#s.potions, 3, "trois potions (registre réel + potions de test)")
  exp.gold = 1000
  local price = s.cards[1].price
  assert(X.act(exp, { "buyCard", 1 }))
  eq(exp.gold, 1000 - price)
  eq(#exp.deck, 11)
  eq(X.act(exp, { "buyCard", 1 }), false, "déjà vendue")
  local g = exp.gold
  assert(X.act(exp, { "remove", 1 }))
  eq(exp.gold, g - 75)
  assert(X.act(exp, { "remove", 1 }))
  eq(exp.gold, g - 75 - 100)
  eq(X.removePrice(exp), 125)
  eq(#exp.deck, 9)
  exp.potions = { "test_potion", "test_potion", false }
  assert(X.act(exp, { "buyPotion", 1 }))
  eq(X.act(exp, { "buyPotion", 2 }), false, "plus d'emplacement")
  assert(X.act(exp, { "discardPotion", 1 }))
  assert(X.act(exp, { "buyPotion", 2 }))
  local n = #exp.relics
  assert(X.act(exp, { "buyRelic", 1 }))
  eq(#exp.relics, n + 1)
  exp.gold = 0
  eq(X.act(exp, { "buyRelic", 2 }), false, "pas assez d'or")
  assert(X.act(exp, { "leave" }))
  eq(exp.phase, "map")
end)

test("marchand : Ligue exaltée = un bibelot de plus", function()
  local exp = newExp({ unlocks = { rep = 0, league = Meta.EXALTED } })
  enter(exp, "merchant")
  eq(#exp.shop.relics, 4)
end)

test("coffre : un bibelot", function()
  local exp = newExp()
  enter(exp, "chest")
  eq(exp.phase, "reward")
  eq(#exp.relics, 1)
  assert(ns.Relics[exp.relics[1]].rarity ~= "boss")
  X.act(exp, { "leave" })
  eq(exp.phase, "map")
end)

local function enterEvent(exp, id)
  for other in pairs(ns.Events) do
    if other ~= id then exp.seenEvents[other] = true end
  end
  enter(exp, "event")
  eq(exp.event.id, id)
end

test("rencontre : ferme des Saldean (soupe, recette)", function()
  local exp = newExp()
  enterEvent(exp, "saldean_farm")
  exp.hp = 30
  assert(X.act(exp, { "choose", 1 }))
  eq(exp.hp, 40)
  eq(X.act(exp, { "choose", 2 }), false, "un seul choix")
  assert(X.act(exp, { "leave" }))
  eq(exp.phase, "map")
  local b = newExp()
  enterEvent(b, "saldean_farm")
  local rolled = serialize(b.event.rolls[2][1])
  assert(X.act(b, { "choose", 2 }))
  eq(b.phase, "reward")
  eq(serialize(b.reward.cards), rolled, "recette tirée à l'entrée")
  for _, id in ipairs(b.reward.cards) do eq(ns.Cards[id].rarity, "common") end
  assert(X.act(b, { "pickCard", 1 }))
  eq(#b.deck, 11)
end)

test("rencontre : Colline des sentinelles (don conditionné à l'or, retrait)", function()
  local exp = newExp()
  enterEvent(exp, "sentinel_hill")
  exp.gold = 10
  eq(X.eventChoiceOk(exp, 2), false)
  eq(X.act(exp, { "choose", 2 }), false, "pas assez d'or")
  exp.gold = 100
  assert(X.act(exp, { "choose", 2 }))
  eq(exp.phase, "select")
  eq(exp.gold, 60)
  assert(X.act(exp, { "select", 1 }))
  eq(#exp.deck, 9)
  eq(exp.phase, "map")
  local b = newExp()
  enterEvent(b, "sentinel_hill")
  assert(X.act(b, { "choose", 1 }))
  local ups = 0
  for _, card in ipairs(b.deck) do if card.up then ups = ups + 1 end end
  eq(ups, 2)
  eq(b.hp, 65 - 6)
end)

test("rencontre : carriole (combat avec bonus d'or, potion)", function()
  local exp = newExp()
  enterEvent(exp, "defias_caravan")
  assert(X.act(exp, { "choose", 1 }))
  eq(exp.phase, "combat")
  eq(exp.fight.pool, "normal")
  local gold = exp.fight.reward.gold
  assert(gold >= 12 + 20)
  winCombat(exp)
  eq(exp.phase, "reward")
  eq(exp.gold, X.START_GOLD + gold)
  assert(X.act(exp, { "leave" }))
  eq(exp.phase, "map")
  local b = newExp()
  enterEvent(b, "defias_caravan")
  assert(X.act(b, { "choose", 2 }))
  eq(b.hp, 60)
  assert(b.potions[1], "potion reçue")
end)

test("rencontres : filtre de tier et pas de doublon", function()
  ns.Events.test_league = { name = "Ligue", act = 1, tier = 2, text = "", choices = { { label = "Ok", effects = {} } } }
  local exp = newExp()
  assert(not exp.seenEvents.test_league)
  local pool = X.eventPool(exp)
  eq(count(pool, "test_league"), 0, "tier 2 verrouillé")
  local b = newExp({ unlocks = { rep = 0, league = 2 } })
  eq(count(X.eventPool(b), "test_league"), 1)
  ns.Events.test_league = nil
  enterEvent(exp, "saldean_farm")
  eq(count(X.eventPool(exp), "saldean_farm"), 0, "déjà vue")
end)

test("bibelots : crochets d'expédition (or, repos, ramassage) et pool de Ligue", function()
  local exp = newExp()
  X.gainRelic(exp, "test_purse")
  X.gainRelic(exp, "test_heart")
  X.gainRelic(exp, "test_pillow")
  eq(exp.maxHp, 75)
  eq(X.gainGold(exp, 10), 20)
  enter(exp, "campfire")
  exp.hp = 10
  X.act(exp, { "rest" })
  eq(exp.hp, 10 + math.floor(75 * 0.3) + 5)
  eq(count(X.relicPool(exp), "test_purse"), 0, "déjà possédé")
  eq(count(X.relicPool(exp), "test_league"), 0, "tier 2 verrouillé")
  eq(count(X.relicPool(exp), "test_class"), 1, "bibelot de la classe jouée dans le pool")
  local b = newExp({ unlocks = { rep = 0, league = 2 } })
  eq(count(X.relicPool(b), "test_league"), 1)
end)

---------------------------------------------------------------------------
-- Méta-progression
---------------------------------------------------------------------------

test("réputation : points par étape, élite et boss, paliers", function()
  local meta = Meta.new()
  local exp = newExp()
  exp.stats.cleared, exp.stats.elites, exp.stats.bosses = 5, 1, 0
  exp.result = "lost"
  local s = Meta.record(meta, exp)
  eq(s.rep, 5 * Meta.REP.step + Meta.REP.elite)
  eq(meta.classes.priest.rep, s.rep)
  eq(meta.league, s.rep)
  eq(meta.classes.priest.keyMax, 0, "pas de clé sur une défaite")
  eq(Meta.level(0), 0)
  eq(Meta.level(Meta.LEVELS[2].at), 1)
  eq(Meta.level(Meta.LEVELS[5].at + 1), 4)
  eq(Meta.levelName(4), "Exalted")
  local lv, inLv, size = Meta.progress(Meta.LEVELS[2].at + 3)
  eq(lv, 1); eq(inLv, 3); eq(size, Meta.LEVELS[3].at - Meta.LEVELS[2].at)
end)

test("déblocages : cartes par champ rep, bibelot de classe à Révéré", function()
  ns.Cards.radiance.rep = 1
  local exp = newExp()
  eq(count(X.cardPool(exp), "radiance"), 0, "verrouillée au départ")
  local b = newExp({ unlocks = { rep = 1, league = 0 } })
  eq(count(X.cardPool(b), "radiance"), 1)
  ns.Cards.radiance.rep = nil
  eq(count(X.cardPool(exp), "penance"), 1, "rep absent = 0")
  local meta = Meta.new()
  Meta.classState(meta, "priest").rep = Meta.LEVELS[4].at
  local r = Meta.newExpedition(meta, { seed = 3, class = "priest" })
  eq(r.phase, "start")
  eq(r.startRelics[1], "test_class")
  assert(X.act(r, { "startRelic", 1 }))
  eq(r.relics[1], "test_class")
  eq(r.phase, "map")
  eq(Meta.title(meta, "priest"), nil)
  Meta.classState(meta, "priest").rep = Meta.LEVELS[5].at
  eq(Meta.title(meta, "priest"), "Dragonslayer")
end)

test("clés mythiques : +1 à la 1re victoire, +N ouvre +N+1, plafond +5", function()
  local meta = Meta.new()
  local function finish(key, result)
    local exp = newExp({ key = key })
    exp.result = result
    return Meta.record(meta, exp)
  end
  eq(Meta.newExpedition(meta, { key = 1 }), nil, "clé verrouillée")
  eq(finish(0, "won").keyUnlocked, 1)
  eq(finish(0, "won").keyUnlocked, nil, "rien de neuf")
  eq(finish(1, "won").keyUnlocked, 2)
  eq(finish(2, "lost").keyUnlocked, nil)
  eq(Meta.keyMax(meta, "priest"), 2)
  for k = 2, 6 do finish(math.min(k, 5), "won") end
  eq(Meta.keyMax(meta, "priest"), 5)
  eq(meta.classes.priest.bestKey, 5)
  assert(Meta.newExpedition(meta, { key = 5 }))
end)

test("affixes : cumul et transmission au combat", function()
  local list = Meta.affixesFor(3)
  eq(table.concat(list, ","), "fortified,tyrannical,bolstering")
  local exp = newExp({ key = 2 })
  enter(exp, "combat")
  eq(table.concat(exp.combat.affixes, ","), "fortified,tyrannical")
end)

local function fightWith(affixes, encounter)
  return Combat.new({ seed = 3, hp = 60, maxHp = 60, deck = { { id = "smite" } },
    encounter = encounter, affixes = affixes, quiet = true })
end

test("Fortifié et Tyrannique : PV et dégâts", function()
  local c = fightWith({ "fortified" }, { "test_dummy", "test_elite" })
  eq(c.enemies[1].maxHp, 120)
  eq(c.enemies[2].maxHp, 100)
  local t = fightWith({ "tyrannical" }, { "test_dummy", "test_elite" })
  eq(t.enemies[1].maxHp, 100)
  eq(t.enemies[2].maxHp, 120)
  eq(Combat.intentInfo(t, t.enemies[2]).damage, 12)
  Combat.endTurn(t)
  eq(t.player.hp, 48)
end)

test("Galvanisant : la mort d'un ennemi renforce les autres", function()
  local c = fightWith({ "bolstering" }, { "test_dummy", "test_dummy", "vancleef" })
  c.enemies[1].hp = 1
  Combat.dealDamage(c, c.player, c.enemies[1], 5)
  eq(c.enemies[2].st.force, Meta.AFFIX.bolstering.force)
  eq(c.enemies[3].st.force, nil, "les boss ne sont pas galvanisés")
end)

test("Nécrotique : chaque coup reçu réduit les soins de 10 %", function()
  local c = fightWith({ "necrotic" }, { "test_hitter" })
  Combat.endTurn(c)
  eq(c.player.hp, 50)
  eq(c.player.st.necrotic, 1)
  Combat.heal(c, c.player, 10)
  eq(c.player.hp, 59)
  local d = fightWith({}, { "test_hitter" })
  Combat.endTurn(d)
  eq(d.player.st.necrotic, nil, "sans l'affixe")
end)

---------------------------------------------------------------------------
-- Sauvegarde
---------------------------------------------------------------------------

-- Politique déterministe : la première action proposée (le marchand finit par « leave »).
local PREF = { merchant = "leave", select = "skipSelect", start = "skipStartRelic" }
local function step(exp)
  local a = PREF[exp.phase] and { PREF[exp.phase] } or X.choices(exp)[1]
  local ok, why = X.act(exp, a)
  assert(ok, ("action %s refusée en %s : %s"):format(tostring(a[1]), exp.phase, tostring(why)))
end

test("aller-retour de sauvegarde : l'expédition continue à l'identique, combat en cours compris", function()
  local db = Save.new()
  local exp = assert(Save.start(db, { seed = 21 }))
  exp.quiet = false
  local reloadedOnce = false
  for _ = 1, 400 do
    if exp.phase == "done" then break end
    if exp.phase == "combat" and exp.combat.round >= 2 and not reloadedOnce then
      reloadedOnce = true
      local ok, errs = Save.validate(db)
      assert(ok, table.concat(errs or {}, "; "))
      local db2 = reload(db)
      local ok2 = Save.validate(db2)
      assert(ok2)
      eq(serialize(db2), serialize(db))
      -- les deux copies jouent la même suite d'actions
      for _ = 1, 300 do
        if db.current.phase == "done" then break end
        step(db.current)
        step(db2.current)
        eq(serialize(db2.current), serialize(db.current), "divergence après rechargement")
      end
      break
    end
    step(exp)
  end
  assert(reloadedOnce, "aucun combat atteint")
end)

test("Save.new / validate / migrate (nil, table vide, champs inconnus gardés)", function()
  local db = Save.new()
  assert(Save.validate(db))
  local fresh = Save.migrate(nil)
  eq(fresh.version, Save.VERSION)
  local old = { custom = 5, journal = { { result = "won" } } }
  local m, note = Save.migrate(old)
  eq(m, old, "migration sur place")
  eq(note, "migrated")
  eq(m.version, Save.VERSION)
  eq(m.custom, 5, "rien n'est effacé")
  eq(#m.journal, 1)
  assert(Save.validate(m))
  local newer = { version = Save.VERSION + 1, foo = 1 }
  local n, why = Save.migrate(newer)
  eq(why, "newer")
  eq(n.version, Save.VERSION + 1)
end)

test("migrate : options de l'interface gardées, méta incomplète réparée", function()
  -- Sauvegarde de développement de l'interface (piste C) : version 1, méta sans réputation,
  -- état d'expédition d'un ancien format, options de l'interface.
  local dev = { version = 1, meta = { saves = 12, savedAt = 99 },
    current = { provider = "demo", seed = 3, run = {} }, journal = { { result = "abandon", floor = 2 } },
    options = { scale = 1.2, autoOpen = false, minimap = { hide = true, angle = 90 }, point = { "CENTER", "CENTER", 4, 5 } } }
  local m = Save.migrate(dev)
  eq(m.options.scale, 1.2)
  eq(m.options.autoOpen, false)
  eq(m.options.minimap.angle, 90)
  eq(m.options.point[3], 4)
  eq(m.meta.league, 0)
  eq(type(m.meta.classes), "table")
  eq(m.meta.saves, 12, "champs inconnus de la méta gardés")
  eq(m.current, nil)
  eq(#m.quarantine, 1)
  eq(m.quarantine[1].state.provider, "demo")
  eq(#m.journal, 1)
  assert(Save.validate(m))
  local again = reload(m)
  Save.migrate(again)
  eq(serialize(again), serialize(m), "migration idempotente")
  -- quarantaine demandée par l'interface
  local db = Save.new()
  db.options = { speed = 2 }
  assert(Save.start(db, { seed = 3 }))
  assert(Save.quarantine(db, "combat illisible"))
  eq(db.current, nil)
  eq(db.quarantine[1].reason, "combat illisible")
  eq(Save.quarantine(db, "x"), false)
  eq(db.options.speed, 2)
end)

test("chemin parcouru : exp.path suit les nœuds visités de l'acte", function()
  local exp = newExp({ seed = 8 })
  eq(#exp.path, 0)
  local id = exp.map.start[1]
  exp.map.nodes[id].kind = "campfire"
  assert(X.act(exp, { "path", id }))
  eq(exp.path[1], id)
  assert(X.act(exp, { "leave" }))
  local nx = Map.nextNodes(exp.map, exp.node)[1]
  exp.map.nodes[nx].kind = "campfire"
  assert(X.act(exp, { "path", nx }))
  eq(#exp.path, 2)
  eq(exp.path[2], nx)
  assert(Save.isPlain(exp))
end)

test("migration : expédition illisible mise en quarantaine, pas effacée", function()
  local db = Save.new()
  db.current = { version = X.VERSION, phase = "bogus" }
  local m, note = Save.migrate(db)
  eq(m.current, nil)
  eq(#m.quarantine, 1)
  eq(m.quarantine[1].state.phase, "bogus")
  assert(note:find("quarantined"))
  assert(Save.validate(m))
  local bad = Save.new()
  bad.current = newExp()
  bad.current.fn = function() end
  eq(Save.validate(bad), false, "fonction refusée")
end)

test("fin d'expédition : journal, méta, clé", function()
  local db = Save.new()
  local exp = assert(Save.start(db, { seed = 4 }))
  eq(Save.start(db, { seed = 5 }), nil, "une seule expédition à la fois")
  eq(Save.finish(db, "x"), nil, "pas encore terminée")
  exp.stats.cleared, exp.stats.bosses = 8, 1
  exp.result, exp.phase = "won", "done"
  local s, entry = Save.finish(db, "2026-11-09")
  eq(db.current, nil)
  eq(#db.journal, 1)
  eq(entry.date, "2026-11-09")
  eq(entry.result, "won")
  eq(entry.seed, 4)
  eq(#entry.deck, 10)
  eq(s.keyUnlocked, 1)
  eq(db.meta.classes.priest.rep, s.rep)
  assert(Save.validate(db))
  local e2 = assert(Save.start(db, { seed = 6, key = 1 }))
  eq(e2.key, 1)
  Save.abandon(db, 2)
  eq(db.journal[2].result, "abandoned")
end)

---------------------------------------------------------------------------
-- Rencontres : familles, conditions, paris, histoires (piste F)
---------------------------------------------------------------------------

-- Entre dans la rencontre id en ignorant ses conditions et son caractère unique
-- (restaurés ensuite) : sert aux tests des réponses.
local function forceEvent(exp, id)
  local ev = ns.Events[id]
  local when, once, tier = ev.when, ev.once, ev.tier
  ev.when, ev.once, ev.tier = nil, nil, 0
  local ok, err = pcall(enterEvent, exp, id)
  ev.when, ev.once, ev.tier = when, once, tier
  if not ok then error(err, 0) end
end

local SCENES = { farm = true, road = true, coast = true, mine = true, hill = true, camp = true, ruins = true }
local EFFECTS = { heal = true, healPct = true, loseHp = true, maxHp = true, loseMaxHp = true, gold = true,
  pay = true, loseGold = true, card = true, cardChoice = true, relic = true, potion = true, losePotion = true,
  upgradeRandom = true, upgrade = true, remove = true, dupe = true, fight = true, gamble = true, flag = true }
local REQUIRES = { pay = true, remove = true, upgrade = true, dupe = true, losePotion = true }

test("rencontres : données complètes (familles, décor, réponses, effets, conditions)", function()
  local fam, tier0, withWhen = { common = 0, rare = 0, story = 0 }, 0, 0
  local function checkEffects(id, effects)
    for _, e in ipairs(effects) do
      assert(EFFECTS[e[1]], id .. " : effet " .. tostring(e[1]))
      if e[1] == "fight" then
        local pool = e[2] or (e.kind == "elite" and "elite" or "normal")
        assert(ns.Encounters.act1[pool], id .. " : groupe " .. tostring(pool))
      elseif e[1] == "relic" and e[2] then
        assert(ns.Relics[e[2]] and ns.Relics[e[2]].noPool, id .. " : bibelot propre " .. e[2])
      elseif e[1] == "potion" and e[2] then
        assert(ns.Potions[e[2]], id .. " : potion " .. e[2])
      elseif e[1] == "gamble" then
        assert(e[2] > 0 and e[2] < 1, id .. " : chance")
        checkEffects(id, e.win or {})
        checkEffects(id, e.lose or {})
      end
    end
  end
  for id, ev in pairs(ns.Events) do
    assert(ev.name and ev.text and ev.speaker and ev.npc, id .. " : name/text/speaker/npc")
    assert(SCENES[ev.scene], id .. " : décor " .. tostring(ev.scene))
    assert(fam[ev.rarity] ~= nil, id .. " : famille " .. tostring(ev.rarity))
    assert(ev.tier >= 0 and ev.tier <= 3, id .. " : tier")
    if ev.act == 1 then fam[ev.rarity] = fam[ev.rarity] + 1 end
    if ev.rarity == "common" and ev.tier == 0 then tier0 = tier0 + 1 end
    if ev.rarity == "story" then assert(ev.once, id .. " : histoire unique") end
    if ev.when then
      withWhen = withWhen + 1
      assert(X.check(newExp(), ev.when) ~= nil)
    end
    local free = false
    assert(#ev.choices >= 2, id .. " : au moins 2 réponses")
    for ci, ch in ipairs(ev.choices) do
      assert(ch.label and ch.outcome and ch.outcome ~= "", id .. " : réponse " .. ci .. " sans label/outcome")
      checkEffects(id, ch.effects)
      local needs = ch.when ~= nil
      for _, e in ipairs(ch.effects) do if REQUIRES[e[1]] then needs = true end end
      if not needs then free = true end
    end
    assert(free, id .. " : aucune réponse toujours possible")
  end
  assert(fam.common >= 8 and fam.common <= 10, "ordinaires : " .. fam.common)
  eq(fam.rare, 2, "rares")
  assert(fam.story >= 1, "histoires")
  assert(tier0 >= 5, "ordinaires au palier 0 : " .. tier0)
  assert(withWhen >= 3, "rencontres conditionnelles : " .. withWhen)
end)

test("conditions : chaque condition et sa raison", function()
  local exp = newExp({ key = 2, flags = { seen = true } })
  exp.hp, exp.maxHp, exp.gold, exp.floor = 20, 60, 40, 3
  local function ok(c) return (X.check(exp, { c })) end
  assert(ok({ "hpBelow", 0.5 }) and not ok({ "hpBelow", 0.3 }))
  assert(ok({ "hpAbove", 0.3 }) and not ok({ "hpAbove", 0.5 }))
  assert(ok({ "gold", 40 }) and not ok({ "gold", 41 }))
  assert(ok({ "key", 2 }) and not ok({ "key", 3 }))
  assert(ok({ "floor", 3 }) and not ok({ "floor", 4 }))
  assert(ok({ "flag", "seen" }) and not ok({ "flag", "other" }))
  assert(ok({ "noFlag", "other" }) and not ok({ "noFlag", "seen" }))
  assert(ok({ "card", "smite" }) and not ok({ "card", "penance" }))
  assert(not ok({ "potion" }))
  exp.potions[2] = "healing_potion"
  assert(ok({ "potion" }))
  assert(not ok({ "relic", "stormwind_tabard" }) and ok({ "noRelic", "stormwind_tabard" }))
  local _, why = X.check(exp, { { "relic", "stormwind_tabard" } })
  assert(why:find(ns.Relics.stormwind_tabard.name, 1, true), why)
  _, why = X.check(exp, { { "gold", 60 } })
  eq(why, "Requires 60g.")
  _, why = X.check(exp, { { "gold", 60, text = "Trop pauvre." } })
  eq(why, "Trop pauvre.", "raison personnalisée")
  assert(not pcall(X.check, exp, { { "inconnue" } }), "condition inconnue refusée")
end)

test("rencontres : conditions de déclenchement (PV, étape, clé, drapeau)", function()
  local exp = newExp({ unlocks = { rep = 0, league = 3 } })
  exp.floor = 1
  local pool = X.eventPool(exp)
  eq(count(pool, "herbalist"), 0, "PV pleins : pas d'herboriste")
  eq(count(pool, "lighthouse_keeper"), 0, "étape 1 : pas de phare")
  eq(count(pool, "gnoll_raiders"), 0, "clé +0 : pas de maraudeurs")
  eq(count(pool, "harvest_watcher"), 1, "PV pleins : moissonneur")
  eq(count(pool, "tobin_scout"), 0, "sans drapeau : pas de suite")
  eq(count(pool, "tobin_thief"), 1, "compte neuf : premier temps")
  exp.hp, exp.floor, exp.key = 20, 5, 2
  exp.flags.tobin_spared = true
  pool = X.eventPool(exp)
  eq(count(pool, "herbalist"), 1)
  eq(count(pool, "lighthouse_keeper"), 1)
  eq(count(pool, "gnoll_raiders"), 1)
  eq(count(pool, "harvest_watcher"), 0, "PV bas : pas de combat d'élite optionnel")
  eq(count(pool, "tobin_scout"), 1)
  eq(count(pool, "tobin_defias"), 0, "branche exclusive")
  -- Le premier nœud d'une carte est à l'étape 1 : la rencontre tirée respecte les conditions.
  for s = 1, 40 do
    local e = newExp({ seed = s, unlocks = { rep = 0, league = 3 } })
    enter(e, "event")
    if e.event.id then
      local ev = ns.Events[e.event.id]
      assert(X.check(e, ev.when), e.event.id)
      assert(e.event.id ~= "lighthouse_keeper" and e.event.id ~= "herbalist")
    end
  end
end)

test("réponse conditionnelle : désactivée avec la raison, puis possible", function()
  local exp = newExp()
  forceEvent(exp, "sentinel_hill")
  local ok, why = X.eventChoiceOk(exp, 4)
  eq(ok, false)
  assert(why:find(ns.Relics.stormwind_tabard.name, 1, true), why)
  local ok2, why2 = X.act(exp, { "choose", 4 })
  eq(ok2, false); eq(why2, why, "act renvoie la même raison")
  for _, a in ipairs(X.choices(exp)) do assert(not (a[1] == "choose" and a[2] == 4), "absente de choices") end
  local opts = X.eventOptions(exp)
  eq(#opts, 4)
  eq(opts[4].disabled, true); eq(opts[4].reason, why)
  eq(opts[1].disabled, nil)
  exp.gold = 0
  eq(X.eventOptions(exp)[2].reason, "Not enough gold.", "code traduit")
  exp.relics[#exp.relics + 1] = "stormwind_tabard"
  assert(X.eventChoiceOk(exp, 4))
  assert(X.act(exp, { "choose", 4 }))
  eq(exp.phase, "reward")
  for _, id in ipairs(exp.reward.cards) do eq(ns.Cards[id].rarity, "uncommon") end
  -- Réfugiés : la potion donnée disparaît, 2 cartes améliorées.
  local b = newExp()
  forceEvent(b, "moonbrook_refugees")
  eq(X.eventChoiceOk(b, 4), false)
  b.potions[1], b.potions[3] = "healing_potion", "mana_potion"
  assert(X.act(b, { "choose", 4 }))
  eq(b.potions[3], false); eq(b.potions[1], "healing_potion")
  local ups = 0
  for _, card in ipairs(b.deck) do if card.up then ups = ups + 1 end end
  eq(ups, 2)
end)

test("pari : tiré à l'entrée, figé au rechargement, issues annoncées", function()
  local wins, losses = 0, 0
  for s = 1, 40 do
    local exp = newExp({ seed = s })
    forceEvent(exp, "coast_murlocs")
    local roll = exp.event.rolls[2][1]
    assert(type(roll.won) == "boolean")
    local copy = reload(exp)
    assert(X.act(exp, { "choose", 2 }))
    assert(X.act(copy, { "choose", 2 }))
    eq(serialize(copy), serialize(exp), "même issue après rechargement")
    eq(exp.event.lucky, roll.won)
    if roll.won then
      wins = wins + 1
      eq(exp.phase, "reward"); eq(exp.reward.goldGained, 20)
      eq(exp.reward.potion, roll.win[1])
      assert(exp.event.result:find("potion", 1, true))
    else
      losses = losses + 1
      eq(exp.hp, 65 - 7); eq(exp.phase, "event")
      assert(exp.event.result:find("murloc", 1, true))
    end
  end
  assert(wins > 5 and losses > 5, ("pari équilibré : %d / %d"):format(wins, losses))
  -- Pari payant : le prix est dû même en cas de perte.
  local exp = newExp()
  forceEvent(exp, "jangolode_prospector")
  exp.event.rolls[2][2].won = false
  assert(X.act(exp, { "choose", 2 }))
  eq(exp.gold, X.START_GOLD - 30)
end)

test("rencontre rare : poids faible, tirée rarement", function()
  eq(X.eventWeight(ns.Events.goblin_peddler), X.EVENT_WEIGHT.rare)
  eq(X.eventWeight(ns.Events.saldean_farm), X.EVENT_WEIGHT.common)
  assert(X.EVENT_WEIGHT.rare * 3 <= X.EVENT_WEIGHT.common)
  local n, seen = 0, {}
  for s = 1, 1500 do
    local exp = newExp({ seed = s, unlocks = { rep = 0, league = 3 } })
    enter(exp, "event")
    if exp.event.id then
      n = n + 1
      seen[exp.event.id] = (seen[exp.event.id] or 0) + 1
    end
  end
  local rare = (seen.goblin_peddler or 0) + (seen.harvest_watcher or 0)
  local common = seen.saldean_farm + seen.defias_caravan + seen.sentinel_hill
  assert(rare > 0, "rares jamais tirées")
  assert(rare / 2 < common / 3 / 2, ("rares %d contre ordinaires %d"):format(rare, common))
  -- Poids explicite : remplace celui de la famille.
  ns.Events.goblin_peddler.weight = 1000
  local exp = newExp({ unlocks = { rep = 0, league = 3 } })
  enter(exp, "event")
  ns.Events.goblin_peddler.weight = nil
  eq(exp.event.id, "goblin_peddler")
end)

test("rencontre rare : marché (bibelot contre PV max) et combat d'élite optionnel", function()
  local exp = newExp()
  forceEvent(exp, "goblin_peddler")
  assert(X.act(exp, { "choose", 1 }))
  eq(exp.maxHp, 65 - 8); eq(exp.hp, 65 - 8)
  eq(exp.relics[#exp.relics], "harvest_cog")
  local b = newExp()
  forceEvent(b, "goblin_peddler")
  b.relics[#b.relics + 1] = "harvest_cog"
  eq(select(2, X.eventChoiceOk(b, 1)), "relic", "bibelot unique déjà possédé")
  local c = newExp()
  forceEvent(c, "harvest_watcher")
  assert(X.act(c, { "choose", 1 }))
  eq(c.phase, "combat")
  eq(c.fight.kind, "elite"); eq(c.fight.pool, "event_golem")
  eq(c.fight.encounter[1], "harvest_golem")
  assert(c.fight.reward.relic, "récompense d'élite : bibelot")
  assert(c.fight.reward.gold >= 25 + 40)
  winCombat(c)
  eq(c.phase, "reward"); eq(c.stats.elites, 1)
end)

test("histoire : une seule fois par compte, suite débloquée à l'expédition suivante", function()
  local db = Save.new()
  local exp = assert(Save.start(db, { seed = 21 }))
  enterEvent(exp, "tobin_thief")
  assert(exp.newFlags["event:tobin_thief"], "vue = drapeau posé à l'entrée")
  assert(X.act(exp, { "choose", 2 }))
  eq(exp.gold, X.START_GOLD - 20)
  assert(exp.newFlags.tobin_spared)
  eq(X.hasFlag(exp, "tobin_spared"), false, "pas dans cette expédition")
  eq(count(X.eventPool(exp), "tobin_scout"), 0)
  local s = Save.abandon(db, "x")
  eq(table.concat(s.flags, ","), "event:tobin_thief,tobin_spared")
  assert(Meta.hasFlag(db.meta, "tobin_spared"))
  assert(Save.validate(db))
  -- Expédition suivante : le premier temps ne revient plus, la suite est possible.
  local e2 = assert(Save.start(db, { seed = 22 }))
  local pool = X.eventPool(e2)
  eq(count(pool, "tobin_thief"), 0, "déjà vue sur ce compte")
  eq(count(pool, "tobin_scout"), 1)
  eq(count(pool, "tobin_defias"), 0)
  for other in pairs(ns.Events) do
    if other ~= "tobin_scout" then e2.seenEvents[other] = true end
  end
  enter(e2, "event")
  eq(e2.event.id, "tobin_scout")
  assert(X.act(e2, { "choose", 1 }))
  eq(e2.relics[#e2.relics], "tobin_knife")
  Save.abandon(db, "y")
  local e3 = assert(Save.start(db, { seed = 23 }))
  eq(count(X.eventPool(e3), "tobin_scout"), 0, "suite vue une fois aussi")
  -- Autre branche : livré à la milice -> foulard rouge, réponse cachée.
  local m = Meta.new()
  m.flags["event:tobin_thief"], m.flags.tobin_jailed = true, true
  local e4 = Meta.newExpedition(m, { seed = 5 })
  eq(count(X.eventPool(e4), "tobin_defias"), 1)
  forceEvent(e4, "tobin_defias")
  local o = X.eventOptions(e4)
  eq(o[3].hidden, true); eq(o[3].outcome, "?")
  eq(ns.Events.tobin_defias.choices[3].text, "?", "interface d'origine : « ? » aussi")
  assert(X.act(e4, { "choose", 1 }))
  eq(e4.fight.pool, "event_tobin")
end)

test("carte copiée (phare) puis récompense en attente après une sélection", function()
  local exp = newExp()
  forceEvent(exp, "lighthouse_keeper")
  assert(X.act(exp, { "choose", 1 }))
  eq(exp.phase, "select"); eq(exp.select.kind, "dupe")
  eq(exp.hp, 55)
  local id = exp.deck[3].id
  assert(X.act(exp, { "select", 3 }))
  eq(#exp.deck, 11); eq(exp.deck[11].id, id)
  eq(exp.phase, "map")
  -- Sélection et récompense dans la même réponse : la récompense s'ouvre après.
  ns.Events.test_combo = { name = "x", act = 1, tier = 0, text = "", speaker = "x", npc = "x", scene = "road",
    choices = { { label = "x", outcome = "x", effects = { { "remove" }, { "gold", 10 } } },
      { label = "y", outcome = "y", effects = {} } } }
  local b = newExp()
  forceEvent(b, "test_combo")
  assert(X.act(b, { "choose", 1 }))
  eq(b.phase, "select")
  assert(X.act(b, { "skipSelect" }))
  ns.Events.test_combo = nil
  eq(b.phase, "reward"); eq(b.reward.goldGained, 10)
end)

test("rencontres : PV jamais sous 1 hors combat, PV max cohérents", function()
  for id, ev in pairs(ns.Events) do
    for ci = 1, #ev.choices do
      for _, lucky in ipairs({ true, false }) do
        local exp = newExp()
        forceEvent(exp, id)
        exp.hp, exp.maxHp, exp.gold = 1, 6, 500
        exp.potions[1] = "healing_potion"
        exp.relics[#exp.relics + 1] = "stormwind_tabard"
        for _, r in ipairs(exp.event.rolls[ci]) do
          if type(r) == "table" and r.won ~= nil then r.won = lucky end
        end
        local ok, why = X.act(exp, { "choose", ci })
        assert(ok or why == "relic", id .. " " .. ci .. " : " .. tostring(why))
        if exp.phase ~= "combat" then
          assert(exp.hp >= 1 and exp.hp <= exp.maxHp and exp.maxHp >= 1,
            ("%s %d : PV %d / %d"):format(id, ci, exp.hp, exp.maxHp))
        end
        assert(Save.isPlain(exp))
      end
    end
  end
end)

test("sauvegarde v1 -> v2 : drapeaux créés, gardés, expédition en cours migrée", function()
  -- Sauvegarde v1 (avant les drapeaux), avec une expédition v1 en cours.
  local cur = newExp({ seed = 8 })
  cur.version, cur.flags, cur.newFlags, cur.stats.events = 1, nil, nil, nil
  local v1 = { version = 1, meta = { league = 300, runs = 3, classes = {} }, current = cur, journal = {} }
  local db, note = Save.migrate(reload(v1))
  eq(note, "migrated"); eq(db.version, Save.VERSION); assert(Save.VERSION >= 2)
  eq(type(db.meta.flags), "table")
  eq(db.meta.league, 300)
  assert(db.current, "expédition gardée")
  eq(db.current.version, X.VERSION)
  eq(type(db.current.flags), "table"); eq(type(db.current.newFlags), "table")
  assert(Save.validate(db))
  -- Drapeaux déjà présents (sauvegarde de développement v1 ou v2) : jamais perdus.
  local dev = { version = 1, meta = { league = 0, runs = 0, classes = {}, flags = { tobin_spared = true, odd = 1, no = false } } }
  local m = Save.migrate(dev)
  eq(m.meta.flags.tobin_spared, true); eq(m.meta.flags.odd, true); eq(m.meta.flags.no, nil)
  local v2 = reload(m)
  Save.migrate(v2)
  eq(serialize(v2), serialize(m), "migration idempotente, drapeaux gardés")
  -- La méta reporte les drapeaux d'une expédition terminée, même perdue.
  local db2 = Save.migrate(nil)
  local e = assert(Save.start(db2, { seed = 3 }))
  X.setFlag(e, "test_flag")
  e.result, e.phase = "lost", "done"
  Save.finish(db2, "z")
  eq(db2.meta.flags.test_flag, true)
  local back = Save.migrate(reload(db2))
  eq(back.meta.flags.test_flag, true, "après rechargement")
end)

---------------------------------------------------------------------------
-- Robustesse et simulation
---------------------------------------------------------------------------

test("toutes les actions proposées sont acceptées (marche aléatoire)", function()
  for s = 1, 25 do
    local exp = newExp({ seed = s, key = s % 6, unlocks = { rep = s % 5, league = s % 5 } })
    local rng = Rng.new(s)
    for _ = 1, 3000 do
      if exp.phase == "done" then break end
      local ch = X.choices(exp)
      assert(#ch > 0, "aucune action en " .. exp.phase)
      local a = Rng.pick(rng, ch)
      local ok, why = X.act(exp, a)
      assert(ok, ("graine %d : %s refusée en %s (%s)"):format(s, a[1], exp.phase, tostring(why)))
    end
    assert(Save.isPlain(exp))
  end
end)

test("expédition simulée reproductible", function()
  local a = ns.SimExpedition.play({ seed = 9, bot = "greedy" })
  local b = ns.SimExpedition.play({ seed = 9, bot = "greedy" })
  eq(a.won, b.won); eq(a.floor, b.floor); eq(a.hp, b.hp); eq(a.gold, b.gold); eq(#a.deck, #b.deck)
  assert(a.visits.combat and a.visits.combat >= 1)
end)

---------------------------------------------------------------------------
-- Classes : choix au départ, pools par classe, bibelot de départ, sauvegarde v3
---------------------------------------------------------------------------

test("classes : expédition du Guerrier (deck, PV, bibelot de départ), du Prêtre sans bibelot", function()
  local w = newExp({ class = "warrior" })
  local cd = ns.Classes.warrior
  eq(w.class, "warrior"); eq(w.hp, cd.hp); eq(w.maxHp, cd.hp); eq(#w.deck, 10)
  eq(w.relics[1], "battle_standard"); eq(#w.relics, 1)
  for _, card in ipairs(w.deck) do eq(ns.Cards[card.id].class, "warrior", card.id) end
  local p = newExp({ class = "priest" })
  eq(#p.relics, 0); eq(p.deck[1].id, "smite")
  assert(not pcall(X.new, { class = "nope" }), "classe inconnue refusée")
end)

test("classes : récompenses, marchand et rencontres tirés dans le pool de la classe jouée", function()
  for _, class in ipairs({ "priest", "warrior" }) do
    local exp = newExp({ class = class, unlocks = { rep = 2, league = 3 } })
    for _, id in ipairs(X.cardPool(exp)) do eq(ns.Cards[id].class, class, id) end
    eq(#X.cardPool(exp), 30)
    for _, id in ipairs(X.relicPool(exp)) do
      local r = ns.Relics[id]
      assert(r.class == nil or r.class == class, class .. " : " .. id)
    end
    enter(exp, "merchant")
    for _, it in ipairs(exp.shop.cards) do eq(ns.Cards[it.id].class, class, it.id) end
    for _, it in ipairs(exp.shop.relics) do
      assert(ns.Relics[it.id].class == nil or ns.Relics[it.id].class == class, it.id)
    end
  end
  local w = newExp({ class = "warrior", unlocks = { rep = 0, league = 3 } })
  eq(count(X.relicPool(w), "battle_standard"), 0, "bibelot de départ jamais tiré (déjà possédé, noPool)")
  eq(count(X.relicPool(w), "diamond_flask"), 1, "bibelot du Guerrier dans son pool")
  eq(count(X.relicPool(newExp({ class = "priest", unlocks = { rep = 0, league = 3 } })), "diamond_flask"), 0,
    "pas dans celui du Prêtre")
  local c = Combat.new({ class = "warrior", hp = 50, deck = {}, encounter = { "test_hitter" } })
  eq(c.class, "warrior")
end)

test("classes : bibelots de classe au départ (Révéré) parmi ceux de la classe, hors bibelot de départ", function()
  local w = newExp({ class = "warrior", unlocks = { rep = Meta.REVERED, league = 3 } })
  eq(w.phase, "start")
  for _, id in ipairs(w.startRelics) do
    eq(ns.Relics[id].class, "warrior", id)
    assert(id ~= "battle_standard")
  end
end)

test("classes : le combat de l'expédition est celui de la classe (Rage, bibelot de départ)", function()
  local w = newExp({ class = "warrior" })
  enter(w, "combat")
  eq(w.combat.class, "warrior"); eq(w.combat.player.res, 1, "Battle Standard")
  assert(Save.isPlain(w))
end)

test("classes : choix de la classe par Save.start, méta par classe", function()
  local db = Save.migrate(nil)
  local e = assert(Save.start(db, { seed = 5, class = "warrior" }))
  eq(e.class, "warrior")
  e.result, e.phase = "lost", "done"
  Save.finish(db, "z")
  assert(db.meta.classes.warrior and db.meta.classes.warrior.runs == 1)
  eq(db.meta.classes.priest, nil)
  eq(db.journal[1].class, "warrior")
end)

test("sauvegarde v2 -> v3 : Démence du combat en cours devenue ressource de classe, classe du combat", function()
  local cur = newExp({ seed = 8, class = "priest" })
  enter(cur, "combat")
  local c = cur.combat
  -- état d'une sauvegarde v2 : Démence, ni classe ni état de classe dans le combat
  c.player.demence, c.player.res, c.class, c.cls, c.turn = 3, nil, nil, nil, nil
  cur.version = 2
  local v2 = { version = 2, meta = { league = 10, runs = 1, classes = { priest = { rep = 10, runs = 1, wins = 0,
    keyMax = 0, bestKey = -1 } }, flags = {} }, current = cur, journal = {} }
  local db, note = Save.migrate(reload(v2))
  eq(note, "migrated"); eq(db.version, 3); eq(Save.VERSION, 3); eq(X.VERSION, 3)
  local m = db.current
  assert(m, "expédition gardée")
  eq(m.version, 3); eq(m.combat.player.res, 3); eq(m.combat.player.demence, nil)
  eq(m.combat.class, "priest"); eq(type(m.combat.cls), "table")
  assert(Save.validate(db))
  -- le combat migré se joue tout de suite (compteurs du tour recréés), puis au tour suivant
  eq(m.combat.turn.played, 0)
  local plays = {}
  for _, a in ipairs(X.choices(m)) do if a[1] == "play" then plays[#plays + 1] = a end end
  if plays[1] then assert(X.act(m, plays[1])) end
  assert(X.act(m, { "endTurn" }))
  -- migration idempotente
  local again = reload(db)
  Save.migrate(again)
  eq(serialize(again), serialize(db))
end)

test("Guerrier : expédition simulée complète, reproductible", function()
  local a = ns.SimExpedition.play({ seed = 9, bot = "greedy", class = "warrior" })
  local b = ns.SimExpedition.play({ seed = 9, bot = "greedy", class = "warrior" })
  eq(a.won, b.won); eq(a.floor, b.floor); eq(a.hp, b.hp)
  for _, card in ipairs(a.deck) do eq(ns.Cards[card.id].class, "warrior", card.id) end
end)

-- Chasseur ------------------------------------------------------------------

test("Chasseur : expédition (deck, PV, Pet Whistle), pools de sa classe, expédition simulée reproductible", function()
  local h = newExp({ class = "hunter", unlocks = { rep = 2, league = 3 } })
  local cd = ns.Classes.hunter
  eq(h.class, "hunter"); eq(h.hp, cd.hp); eq(#h.deck, 10); eq(h.relics[1], "pet_whistle")
  eq(#X.cardPool(h), 30)
  for _, id in ipairs(X.cardPool(h)) do eq(ns.Cards[id].class, "hunter", id) end
  for _, id in ipairs(X.relicPool(h)) do
    local r = ns.Relics[id]
    assert(r.class == nil or r.class == "hunter", id)
  end
  eq(count(X.relicPool(h), "pet_whistle"), 0, "bibelot de départ jamais tiré")
  local a = ns.SimExpedition.play({ seed = 9, bot = "greedy", class = "hunter" })
  local b = ns.SimExpedition.play({ seed = 9, bot = "greedy", class = "hunter" })
  eq(a.won, b.won); eq(a.floor, b.floor); eq(a.hp, b.hp)
  for _, card in ipairs(a.deck) do eq(ns.Cards[card.id].class, "hunter", card.id) end
end)

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
