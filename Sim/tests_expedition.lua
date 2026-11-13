-- Tests de l'expédition, de la méta-progression et de la sauvegarde.
-- Usage : lua5.1 Sim/tests_expedition.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Map, Meta, Save, Combat, Rng = ns.Expedition, ns.Map, ns.Meta, ns.Save, ns.Combat, ns.Rng
-- PV de départ du Prêtre (classe des expéditions de test), lus dans les données : ils changent avec l'équilibrage
local PHP = ns.Classes.priest.hp

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

-- Expédition de test ; la phase « start » (Révéré de la Ligue : bibelot au choix) est passée, sauf
-- keepStart = true.
local function newExp(opts)
  opts = opts or {}
  opts.seed = opts.seed or 11
  if opts.quiet == nil then opts.quiet = true end
  local exp = X.new(opts)
  if exp.phase == "start" and exp.startEpics and not opts.keepStart then assert(X.act(exp, { "skipEpic" })) end
  if exp.phase == "start" and not opts.keepStart then assert(X.act(exp, { "skipStartRelic" })) end
  return exp
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
    eq(exp.relics[#exp.relics], r.relic, "bibelot pris")
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
  eq(exp.hp, 20 + math.floor(PHP * 0.30))
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
  eq(d.hp, 20 + math.floor(PHP * 0.20), "Disette")
end)

test("marchand : achats, retrait au prix croissant, emplacements de potion", function()
  local exp = newExp()
  enter(exp, "merchant")
  eq(exp.phase, "merchant")
  local s = exp.shop
  eq(#s.cards, 6, "5 cartes de classe + l'emplacement « Neutral »")
  assert(s.cards[6].neutral and not s.cards[5].neutral, "carte neutre en dernier")
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

test("marchand : un bibelot de plus après la première victoire du compte dans la zone 6", function()
  eq(Meta.PERKS.merchantRelic, 6)
  local exp = newExp({ unlocks = { level = 1, common = Meta.PERKS.merchantRelic } })
  enter(exp, "merchant")
  eq(#exp.shop.relics, 4)
  local b = newExp({ unlocks = { level = 1, common = Meta.PERKS.merchantRelic - 1 } })
  enter(b, "merchant")
  eq(#b.shop.relics, 3, "zone 5 : pas encore")
end)

test("coffre : un bibelot", function()
  local exp = newExp()
  eq(exp.relics[1], "sacred_candle", "bibelot de départ du Prêtre")
  enter(exp, "chest")
  eq(exp.phase, "reward")
  eq(#exp.relics, 2)
  assert(ns.Relics[exp.relics[2]].rarity ~= "boss")
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
  exp.hp = exp.maxHp - 15
  assert(X.act(exp, { "choose", 1 }))
  eq(exp.hp, exp.maxHp - 5)
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
  eq(b.hp, PHP - 6)
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
  eq(b.hp, PHP - 5)
  assert(b.potions[1], "potion reçue")
end)

test("rencontres : filtre de palier commun et de zone, pas de doublon", function()
  ns.Events.test_league = { name = "Commun", zone = "westfall", tier = 2, text = "", choices = { { label = "Ok", effects = {} } } }
  ns.Events.test_elsewhere = { name = "Ailleurs", zone = "duskwood", tier = 0, text = "", choices = { { label = "Ok", effects = {} } } }
  ns.Events.test_anywhere = { name = "Partout", tier = 0, text = "", choices = { { label = "Ok", effects = {} } } }
  local exp = newExp()
  assert(not exp.seenEvents.test_league)
  local pool = X.eventPool(exp)
  eq(count(pool, "test_league"), 0, "tier 2 verrouillé")
  eq(count(pool, "test_elsewhere"), 0, "rencontre d'une autre zone")
  eq(count(pool, "test_anywhere"), 1, "rencontre sans zone : partout")
  local b = newExp({ unlocks = { common = 2 } })
  eq(count(X.eventPool(b), "test_league"), 1)
  ns.Events.test_league, ns.Events.test_elsewhere, ns.Events.test_anywhere = nil, nil, nil
  enterEvent(exp, "saldean_farm")
  eq(count(X.eventPool(exp), "saldean_farm"), 0, "déjà vue")
end)

test("bibelots : crochets d'expédition (or, repos, ramassage) et pool commun", function()
  local exp = newExp()
  X.gainRelic(exp, "test_purse")
  X.gainRelic(exp, "test_heart")
  X.gainRelic(exp, "test_pillow")
  eq(exp.maxHp, PHP + 10)
  eq(X.gainGold(exp, 10), 20)
  enter(exp, "campfire")
  exp.hp = 10
  X.act(exp, { "rest" })
  eq(exp.hp, 10 + math.floor((PHP + 10) * 0.3) + 5)
  eq(count(X.relicPool(exp), "test_purse"), 0, "déjà possédé")
  eq(count(X.relicPool(exp), "test_league"), 0, "tier 2 verrouillé")
  eq(count(X.relicPool(exp), "test_class"), 1, "bibelot de la classe jouée dans le pool")
  local b = newExp({ unlocks = { common = 2 } })
  eq(count(X.relicPool(b), "test_league"), 1)
end)

---------------------------------------------------------------------------
-- Méta-progression
---------------------------------------------------------------------------

test("expérience : avancée de l'expédition (étapes, élites, boss), plus de Ligue ni de réputation", function()
  local meta = Meta.new()
  local exp = newExp()
  exp.stats.cleared, exp.stats.elites, exp.stats.bosses = 5, 1, 0
  exp.result = "lost"
  local s = Meta.record(meta, exp)
  eq(s.rep, nil, "plus de réputation")
  eq(meta.league, nil, "plus de Ligue")
  eq(Meta.LEVELS, nil); eq(Meta.REP, nil); eq(Meta.repFor, nil)
  eq(meta.classes.priest.rep, nil, "plus de réputation de classe")
  eq(s.xp, 5 * Meta.XP.step + Meta.XP.elite, "défaite : expérience sans bonus de victoire")
  eq(meta.classes.priest.xp, s.xp)
  eq(Meta.keyMax(meta, "priest", "westfall"), 0, "pas de clé sur une défaite")
  eq(Meta.classWon(meta, "priest", "westfall"), false)
  eq(next(meta.zones), nil, "défaite : aucune zone gagnée par le compte")
end)

test("déblocages : cartes par niveau de classe, bibelot au choix (zone 3 du compte), titre au niveau 7", function()
  local lv0 = ns.Cards.radiance.level
  ns.Cards.radiance.level = 2
  local exp = newExp()
  eq(exp.unlock.level, 1, "niveau 1 par défaut")
  eq(count(X.cardPool(exp), "radiance"), 0, "verrouillée au départ")
  local b = newExp({ unlocks = { level = 2, common = 0 } })
  eq(count(X.cardPool(b), "radiance"), 1)
  ns.Cards.radiance.level = nil
  eq(count(X.cardPool(exp), "radiance"), 1, "level absent = 1")
  ns.Cards.radiance.level = lv0
  -- le palier commun ne débloque rien de la classe
  local rich = newExp({ unlocks = { level = 1, common = 7 } })
  eq(count(X.cardPool(rich), "rapture"), 0, "Rapture (niveau 7) verrouillée malgré le commun")
  eq(count(X.relicPool(rich), "anathema"), 0)
  -- première victoire du compte dans la zone 3 : un bibelot au choix parmi 3, tirés dans la réserve
  eq(Meta.PERKS.startRelic, 3)
  local meta = Meta.new()
  meta.zones.westfall, meta.zones.duskwood = true, true
  eq(Meta.newExpedition(meta, { seed = 3, class = "priest" }).phase, "map", "deux zones : pas encore")
  meta.zones.wetlands = true
  eq(Meta.commonTier(meta), 3)
  local r = Meta.newExpedition(meta, { seed = 3, class = "priest" })
  eq(r.phase, "start")
  eq(#r.startRelics, 3)
  local pool = X.relicPool(r)
  for _, id in ipairs(r.startRelics) do
    assert(count(pool, id) == 1, id .. " hors de la réserve")
    assert(ns.Relics[id].rarity ~= "boss", id)
  end
  local pick = r.startRelics[2]
  assert(X.act(r, { "startRelic", 2 }))
  eq(r.relics[1], "sacred_candle"); eq(r.relics[2], pick)
  eq(r.phase, "map")
  eq(Meta.title(meta, "priest"), nil)
  Meta.classState(meta, "priest").xp = Meta.XP_LEVELS[7] - 1
  eq(Meta.title(meta, "priest"), nil)
  Meta.classState(meta, "priest").xp = Meta.XP_LEVELS[7]
  eq(Meta.title(meta, "priest"), "Dragonslayer")
end)

test("niveau de classe : seuils, progression, expérience gagnée (victoire, défaite, clé)", function()
  eq(Meta.MAX_LEVEL, 7)
  local T = { 0, 100, 250, 450, 700, 1000, 1400 }
  for i = 1, 7 do eq(Meta.XP_LEVELS[i], T[i], "seuil " .. i) end
  eq(Meta.classLevel(0), 1); eq(Meta.classLevel(99), 1); eq(Meta.classLevel(100), 2)
  eq(Meta.classLevel(1399), 6); eq(Meta.classLevel(1400), 7); eq(Meta.classLevel(99999), 7)
  local lv, cur, size = Meta.xpProgress(120)
  eq(lv, 2); eq(cur, 20); eq(size, 150)
  lv, cur, size = Meta.xpProgress(1500)
  eq(lv, 7); eq(cur, 100); eq(size, nil)
  local function xpOf(result, key, cleared, elites, bosses)
    local e = newExp({ key = key })
    e.stats.cleared, e.stats.elites, e.stats.bosses, e.result = cleared, elites, bosses, result
    return Meta.xpFor(e)
  end
  local won, lost = xpOf("won", 0, 8, 1, 1), xpOf("lost", 0, 7, 1, 0)
  eq(won, 8 * Meta.XP.step + Meta.XP.elite + Meta.XP.boss + Meta.XP.win)
  eq(won, 76, "victoire à la clé 0 avec une élite : 76 (comme l'ancienne formule)")
  eq(lost, 41, "défaite au boss avec une élite : 41")
  eq(xpOf("lost", 0, 3, 0, 0), 15, "défaite précoce : moins")
  assert(won > lost, "une victoire rapporte plus")
  -- +15 % par niveau de clé
  eq(Meta.XP.key, 0.15)
  eq(xpOf("won", 1, 8, 1, 1), math.floor(76 * 1.15 + 0.5))
  eq(xpOf("won", 3, 8, 1, 1), math.floor(76 * 1.45 + 0.5))
  eq(xpOf("won", 5, 8, 1, 1), math.floor(76 * 1.75 + 0.5))
  eq(xpOf("abandoned", 0, 0, 0, 0), 0, "abandon immédiat : rien")
  -- cadence visée : 2 à 3 expéditions pour le niveau 2, de l'ordre de 20 pour le niveau 7
  -- (≈ 4 victoires pour 1 défaite au boss)
  local avg = (4 * won + lost) / 5
  assert(100 / avg >= 1.2 and 100 / avg <= 3, ("niveau 2 en %.1f expéditions"):format(100 / avg))
  assert(1400 / avg >= 17 and 1400 / avg <= 24, ("niveau 7 en %.1f expéditions"):format(1400 / avg))
end)

test("montée de niveau : résumé, ce qui vient d'être débloqué, expédition en cours figée", function()
  local db = Save.new()
  local exp = assert(Save.start(db, { seed = 4, class = "priest" }))
  eq(exp.unlock.level, 1)
  local before = X.cardPool(exp)
  eq(#before, 18)
  -- le compte gagne des niveaux pendant l'expédition : elle garde ses déblocages de départ
  Meta.classState(db.meta, "priest").xp = Meta.XP_LEVELS[4] - 5
  eq(exp.unlock.level, 1)
  eq(#X.cardPool(exp), 18, "expédition figée")
  exp.stats.cleared, exp.stats.elites, exp.stats.bosses = 8, 1, 1
  exp.result, exp.phase = "won", "done"
  local s = Save.finish(db, "x")
  eq(s.levelBefore, 3); eq(s.levelAfter, 4)
  eq(db.journal[1].xp, s.xp)
  table.sort(s.unlocked.cards)
  eq(table.concat(s.unlocked.cards, ","), "halo,luminous_barrier,sw_death")
  eq(#s.unlocked.relics, 0)
  -- deux niveaux d'un coup : cartes du 6 et bibelot du 5
  Meta.classState(db.meta, "priest").xp = Meta.XP_LEVELS[5] - 1
  local e2 = assert(Save.start(db, { seed = 5, class = "priest" }))
  eq(e2.unlock.level, 4)
  Meta.classState(db.meta, "priest").xp = Meta.XP_LEVELS[6] - 2
  e2.stats.cleared, e2.stats.bosses = 8, 1
  e2.result, e2.phase = "won", "done"
  local s2 = Save.finish(db, "y")
  eq(s2.levelBefore, 5); eq(s2.levelAfter, 6)
  table.sort(s2.unlocked.cards)
  eq(table.concat(s2.unlocked.cards, ","), "empyreal_blaze,psychic_scream,shadow_mend")
  -- sans montée : rien de débloqué
  local e3 = assert(Save.start(db, { seed = 6, class = "priest" }))
  e3.result, e3.phase = "lost", "done"
  local s3 = Save.finish(db, "z")
  eq(s3.levelBefore, s3.levelAfter); eq(#s3.unlocked.cards, 0); eq(#s3.unlocked.relics, 0)
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
  eq(Meta.keyMax(meta, "priest", "westfall"), 2)
  for k = 2, 6 do finish(math.min(k, 5), "won") end
  eq(Meta.keyMax(meta, "priest", "westfall"), 5)
  eq(meta.classes.priest.zones.westfall.bestKey, 5)
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
  -- intensités lues dans Meta.AFFIX (réglées par la simulation)
  local A = Meta.AFFIX
  local function sc(v, f) return math.floor(v * (1 + f) + 0.5) end
  local c = fightWith({ "fortified" }, { "test_dummy", "test_elite" })
  eq(c.enemies[1].maxHp, sc(100, A.fortified.hp))
  eq(c.enemies[2].maxHp, 100)
  local t = fightWith({ "tyrannical" }, { "test_dummy", "test_elite" })
  eq(t.enemies[1].maxHp, 100)
  eq(t.enemies[2].maxHp, sc(100, A.tyrannical.eliteHp))
  eq(Combat.intentInfo(t, t.enemies[2]).damage, sc(10, A.tyrannical.eliteDamage))
  Combat.endTurn(t)
  eq(t.player.hp, 60 - sc(10, A.tyrannical.eliteDamage))
end)

test("Galvanisant : la mort d'un ennemi renforce les autres", function()
  local c = fightWith({ "bolstering" }, { "test_dummy", "test_dummy", "vancleef" })
  c.enemies[1].hp = 1
  Combat.dealDamage(c, c.player, c.enemies[1], 5)
  eq(c.enemies[2].st.force, Meta.AFFIX.bolstering.force)
  eq(c.enemies[3].st.force, nil, "les boss ne sont pas galvanisés")
end)

test("Nécrotique : chaque coup reçu réduit les soins (Meta.AFFIX.necrotic.step), plafond", function()
  local A = Meta.AFFIX.necrotic
  local c = fightWith({ "necrotic" }, { "test_hitter" })
  Combat.endTurn(c)
  eq(c.player.hp, 50)
  eq(c.player.st.necrotic, 1)
  c.player.hp = 20
  Combat.heal(c, c.player, 20)
  eq(c.player.hp, 20 + math.floor(20 * (1 - A.step) + 0.5))
  for _ = 1, A.cap + 2 do Combat.fire(c, "onPlayerHit", c.enemies[1], 1) end
  eq(c.player.st.necrotic, A.cap, "plafond")
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
  eq(m.meta.league, nil)
  eq(type(m.meta.zones), "table")
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
  eq(db.meta.classes.priest.xp, s.xp)
  eq(entry.xp, s.xp)
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

-- décors communs (docs/zones.md, « Décors » : une zone les remplace par les siens)
local SCENES = { farm = true, road = true, coast = true, mine = true, hill = true, camp = true, ruins = true,
  shop = true, night = true }
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
        assert(ns.Encounters[ns.Zones[ns.Events[id].zone or "westfall"].encounters][pool], id .. " : groupe " .. tostring(pool))
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
    assert(ev.tier >= 0 and ev.tier <= ns.Zone.count(), id .. " : tier")
    if ev.zone == "westfall" then fam[ev.rarity] = fam[ev.rarity] + 1 end
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
  local exp = newExp({ unlocks = { level = 1, common = 3 } })
  exp.floor = 1
  local pool = X.eventPool(exp)
  eq(count(pool, "herbalist"), 0, "PV pleins : pas d'herboriste")
  eq(count(pool, "lighthouse_keeper"), 0, "étape 1 : pas de phare")
  eq(count(pool, "gnoll_raiders"), 0, "clé +0 : pas de maraudeurs")
  eq(count(pool, "harvest_watcher"), 1, "PV pleins : moissonneur")
  eq(count(pool, "tobin_scout"), 0, "sans drapeau : pas de suite")
  eq(count(pool, "tobin_thief"), 1, "compte neuf : premier temps")
  exp.hp, exp.floor, exp.key = math.floor(exp.maxHp * 0.4), 5, 2
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
    local e = newExp({ seed = s, unlocks = { level = 1, common = 3 } })
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
      eq(exp.hp, PHP - 7); eq(exp.phase, "event")
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
    local exp = newExp({ seed = s, unlocks = { level = 1, common = 3 } })
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
  local exp = newExp({ unlocks = { level = 1, common = 3 } })
  enter(exp, "event")
  ns.Events.goblin_peddler.weight = nil
  eq(exp.event.id, "goblin_peddler")
end)

test("rencontre rare : marché (bibelot contre PV max) et combat d'élite optionnel", function()
  local exp = newExp()
  forceEvent(exp, "goblin_peddler")
  assert(X.act(exp, { "choose", 1 }))
  eq(exp.maxHp, PHP - 8); eq(exp.hp, PHP - 8)
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
  eq(exp.hp, PHP - 10)
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
        local exp = newExp({ zone = ev.zone }) -- rencontre d'une zone : dans sa zone
        forceEvent(exp, id)
        exp.hp, exp.maxHp, exp.gold = 1, 6, 500
        exp.unlock.common = ns.Zone.count() -- réponses à carte neutre débloquée (condition « unlocked », hide)
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
  eq(db.meta.league, nil, "réputation de Ligue abandonnée (v5)")
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
    local exp = newExp({ seed = s, key = s % 6, unlocks = { level = s % 7 + 1, common = s % 5 }, keepStart = true })
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

test("classes : expédition du Guerrier (deck, PV, bibelot de départ), du Prêtre (Sacred Candle)", function()
  local w = newExp({ class = "warrior" })
  local cd = ns.Classes.warrior
  eq(w.class, "warrior"); eq(w.hp, cd.hp); eq(w.maxHp, cd.hp); eq(#w.deck, 10)
  eq(w.relics[1], "battle_standard"); eq(#w.relics, 1)
  for _, card in ipairs(w.deck) do eq(ns.Cards[card.id].class, "warrior", card.id) end
  local p = newExp({ class = "priest" })
  eq(p.relics[1], "sacred_candle"); eq(#p.relics, 1); eq(p.deck[1].id, "smite")
  assert(not pcall(X.new, { class = "nope" }), "classe inconnue refusée")
end)

test("classes : récompenses, marchand et rencontres tirés dans le pool de la classe jouée", function()
  for _, class in ipairs({ "priest", "warrior" }) do
    local exp = newExp({ class = class, unlocks = { level = 7, common = 3 } })
    for _, id in ipairs(X.cardPool(exp)) do eq(ns.Cards[id].class, class, id) end
    eq(#X.cardPool(exp), 30)
    for _, id in ipairs(X.relicPool(exp)) do
      local r = ns.Relics[id]
      assert(r.class == nil or r.class == class, class .. " : " .. id)
    end
    enter(exp, "merchant")
    for _, it in ipairs(exp.shop.cards) do
      -- emplacement « Neutral » : une carte neutre (sans classe), sinon une carte de la classe
      if it.neutral then assert(ns.Cards[it.id].class == nil and ns.Cards[it.id].neutral, it.id)
      else eq(ns.Cards[it.id].class, class, it.id) end
    end
    for _, it in ipairs(exp.shop.relics) do
      assert(ns.Relics[it.id].class == nil or ns.Relics[it.id].class == class, it.id)
    end
  end
  local w = newExp({ class = "warrior", unlocks = { level = 1, common = 3 } })
  eq(count(X.relicPool(w), "battle_standard"), 0, "bibelot de départ jamais tiré (déjà possédé, noPool)")
  eq(count(X.relicPool(w), "hand_of_justice"), 1, "bibelot du Guerrier (niveau 1) dans son pool")
  eq(count(X.relicPool(newExp({ class = "priest", unlocks = { level = 7, common = 3 } })), "hand_of_justice"), 0,
    "pas dans celui du Prêtre")
  local c = Combat.new({ class = "warrior", hp = 50, deck = {}, encounter = { "test_hitter" } })
  eq(c.class, "warrior")
end)

test("classes : bibelot au départ (zone 3 du compte) tiré dans la réserve de la classe, hors bibelot de départ", function()
  for s = 1, 30 do
    local w = newExp({ seed = s, class = "warrior", unlocks = { level = 7, common = Meta.PERKS.startRelic }, keepStart = true })
    eq(w.phase, "start")
    for _, id in ipairs(w.startRelics) do
      local r = ns.Relics[id]
      assert(r.class == nil or r.class == "warrior", id)
      assert(id ~= "battle_standard" and not r.noPool and r.rarity ~= "boss", id)
    end
  end
  eq(newExp({ class = "warrior", unlocks = { level = 7, common = 2 }, keepStart = true }).phase, "map", "zone 2 : rien")
end)

test("classes : réserves par niveau de classe (cartes et bibelots), sans effet du palier commun", function()
  local CARDS = { 18, 21, 21, 24, 24, 27, 30 }
  local RELICS = { 1, 1, 2, 2, 3, 3, 5 } -- bibelots de classe tirables (hors bibelot de départ)
  for _, class in ipairs({ "priest", "warrior", "mage", "rogue", "hunter" }) do
    for lv = 1, 7 do
      for _, league in ipairs({ 0, 3 }) do
        local e = newExp({ class = class, unlocks = { level = lv, common = league } })
        -- Rogue : Nightblade (Subtlety, niveau 3) en plus de la grille commune
        local extra = (class == "rogue" and lv >= 3) and 1 or 0
        eq(#X.cardPool(e), CARDS[lv] + extra, class .. " niveau " .. lv .. " : cartes")
        local n = 0
        for _, id in ipairs(X.relicPool(e)) do
          local r = ns.Relics[id]
          if r.class and not id:find("^test_") then
            eq(r.class, class, id)
            assert((r.level or 1) <= lv, id .. " au-dessus du niveau")
            n = n + 1
          end
        end
        eq(n, RELICS[lv], class .. " niveau " .. lv .. " : bibelots de classe")
      end
    end
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

test("sauvegarde v2 -> v4 : Démence du combat en cours devenue ressource de classe, classe du combat", function()
  local cur = newExp({ seed = 8, class = "priest" })
  enter(cur, "combat")
  local c = cur.combat
  -- état d'une sauvegarde v2 : Démence, ni classe ni état de classe dans le combat
  c.player.demence, c.player.res, c.class, c.cls, c.turn = 3, nil, nil, nil, nil
  cur.version = 2
  cur.zone, cur.unlock = nil, { rep = 0, league = 0 }
  local v2 = { version = 2, meta = { league = 10, runs = 1, classes = { priest = { rep = 10, runs = 1, wins = 0,
    keyMax = 0, bestKey = -1 } }, flags = {} }, current = cur, journal = {} }
  local db, note = Save.migrate(reload(v2))
  eq(note, "migrated"); eq(db.version, 5); eq(Save.VERSION, 5); eq(X.VERSION, 6)
  local m = db.current
  assert(m, "expédition gardée")
  eq(m.version, 6); eq(m.zone, "westfall"); eq(m.combat.player.res, 3); eq(m.combat.player.demence, nil)
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
  -- cartes de la classe, ou neutres (marchand, rencontres)
  for _, card in ipairs(a.deck) do
    local d = ns.Cards[card.id]
    assert(d.class == "warrior" or (d.class == nil and d.neutral), card.id)
  end
end)

test("sauvegarde v3 -> v5 : réputation de classe convertie en expérience, expédition au niveau de sa classe", function()
  local cur = newExp({ seed = 8, class = "warrior", unlocks = { level = 1, common = 2 } })
  enter(cur, "combat")
  cur.version = 3
  cur.zone = nil
  cur.unlock = { rep = 2, league = 2 }
  local v3 = { version = 3, meta = { league = 900, runs = 9, flags = {}, classes = {
    priest = { rep = 300, runs = 3, wins = 2, keyMax = 2, bestKey = 1 },
    warrior = { rep = 800, runs = 6, wins = 4, keyMax = 1, bestKey = 0 } } },
    current = cur, journal = { { result = "won", class = "priest", rep = 110 } } }
  local db, note = Save.migrate(reload(v3))
  eq(note, "migrated"); eq(db.version, 5)
  local w, p = db.meta.classes.warrior, db.meta.classes.priest
  eq(w.xp, math.floor(800 * 0.5 + 4 * 15 + 0.5))
  eq(p.xp, math.floor(300 * 0.5 + 2 * 15 + 0.5))
  eq(w.rep, 800, "ancienne réputation gardée"); eq(w.zones.westfall.keyMax, 1); eq(db.meta.league, nil)
  local m = db.current
  assert(m, "expédition gardée")
  eq(m.version, 6); eq(m.unlock.rep, nil); eq(m.unlock.league, nil); eq(m.unlock.common, 1)
  eq(m.unlock.level, Meta.classLevel(w.xp), "niveau de sa classe après migration")
  eq(Meta.classLevel(w.xp), 4)
  assert(Save.validate(db))
  assert(X.act(m, { "endTurn" }))
  -- migration idempotente ; une méta sans réputation reste à 0
  local again = reload(db)
  Save.migrate(again)
  eq(serialize(again), serialize(db))
  local fresh = Save.migrate({ version = 3, meta = { league = 0, runs = 0, flags = {}, classes = {
    mage = { runs = 0, wins = 0, keyMax = 0, bestKey = -1 } } }, journal = {} })
  eq(fresh.meta.classes.mage.xp, 0)
  assert(Save.validate(fresh))
end)

-- Chasseur ------------------------------------------------------------------

test("Chasseur : expédition (deck, PV, Pet Whistle), pools de sa classe, expédition simulée reproductible", function()
  local h = newExp({ class = "hunter", unlocks = { level = 7, common = 3 } })
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
  -- cartes de la classe, ou neutres (marchand, rencontres)
  for _, card in ipairs(a.deck) do
    local d = ns.Cards[card.id]
    assert(d.class == "hunter" or (d.class == nil and d.neutral), card.id)
  end
end)

---------------------------------------------------------------------------
-- Cartes neutres (docs/cartes-neutres.md) : marchand et rencontres seulement, palier de Ligue
---------------------------------------------------------------------------

local NEUTRAL_CLASSES = { "priest", "warrior", "mage", "rogue", "hunter" }
local function isNeutral(id) local d = ns.Cards[id] return d and d.class == nil and d.neutral == true end

test("neutres : jamais en récompense de combat (pool des cinq classes, 40 combats et élites tirés)", function()
  for _, cl in ipairs(NEUTRAL_CLASSES) do
    local exp = newExp({ class = cl, unlocks = { rep = 2, common = 3 } })
    for _, id in ipairs(X.cardPool(exp)) do assert(not isNeutral(id), cl .. " : " .. id) end
    for _, id in ipairs(X.cardPool(exp, true)) do assert(not isNeutral(id), cl .. " (neutral) : " .. id) end
    for s = 1, 8 do
      for _, kind in ipairs({ "combat", "elite" }) do
        local e = newExp({ class = cl, seed = 100 + s, unlocks = { rep = 2, common = 3 } })
        enter(e, kind)
        for _, id in ipairs(e.fight.reward.cards) do assert(not isNeutral(id), cl .. " " .. kind .. " : " .. id) end
      end
    end
  end
end)

test("neutres : déblocage par palier de Ligue (4 / 6 / 8 / 10 cartes), condition « unlocked »", function()
  local want = { [0] = 4, 6, 8, 10 }
  for lv = 0, 3 do
    local exp = newExp({ unlocks = { rep = 0, common = lv } })
    local pool = X.neutralPool(exp)
    eq(#pool, want[lv], "palier " .. lv)
    for _, id in ipairs(pool) do
      assert(isNeutral(id) and ns.Cards[id].tier <= lv, id)
      assert(X.cardUnlocked(exp, id), id)
    end
    eq(X.cardUnlocked(exp, "black_lotus"), lv >= 3, "Black Lotus au palier " .. lv)
    eq(X.check(exp, { { "unlocked", "elixir_of_superior_defense" } }), lv >= 2, "condition unlocked " .. lv)
  end
  -- Exalté (4) : comme Révéré
  eq(#X.neutralPool(newExp({ unlocks = { rep = 0, common = 4 } })), 10)
end)

test("neutres : emplacement « Neutral » du marchand (6e carte, prix 45 / 65 / 100 ±10 %), pour chaque classe", function()
  local base = { common = 45, uncommon = 65, rare = 100 }
  local seen = {}
  for _, cl in ipairs(NEUTRAL_CLASSES) do
    for s = 1, 12 do
      local lv = s % 4
      local exp = newExp({ class = cl, seed = 200 + s, unlocks = { rep = 0, common = lv } })
      enter(exp, "merchant")
      local cards = exp.shop.cards
      eq(#cards, 6, cl .. " : 5 + 1")
      local nNeutral = 0
      for i, it in ipairs(cards) do
        if it.neutral then
          nNeutral = nNeutral + 1
          eq(i, 6, "en dernier")
          local d = ns.Cards[it.id]
          assert(isNeutral(it.id) and d.tier <= lv, it.id .. " palier " .. lv)
          local b = base[d.rarity]
          assert(it.price >= math.floor(b * 0.9) and it.price <= math.ceil(b * 1.1), it.id .. " prix " .. it.price)
          seen[it.id] = true
        else
          eq(ns.Cards[it.id].class, cl, it.id)
        end
      end
      eq(nNeutral, 1, cl .. " : une carte neutre")
      -- achat : la carte neutre entre dans le deck
      exp.gold = 500
      assert(X.act(exp, { "buyCard", 6 }))
      eq(exp.deck[#exp.deck].id, cards[6].id)
    end
  end
  local n = 0
  for _ in pairs(seen) do n = n + 1 end
  assert(n >= 6, "variété des cartes neutres proposées : " .. n)
  -- sans carte neutre débloquée (registre vidé le temps du test) : 5 cartes, comme avant
  local saved = {}
  for id, d in pairs(ns.Cards) do if d.neutral then saved[id] = d ns.Cards[id] = nil end end
  local e = newExp()
  enter(e, "merchant")
  for id, d in pairs(saved) do ns.Cards[id] = d end
  eq(#e.shop.cards, 5, "sans neutre")
end)

-- Choisit la réponse (label) d'une rencontre forcée ; renvoie l'expédition.
local function neutralAnswer(evId, label, league, opts)
  local exp = newExp({ unlocks = { rep = 0, common = league or 3 } })
  local ev = ns.Events[evId]
  local id = exp.map.start[1]
  exp.map.nodes[id].kind = "event"
  exp.gold, exp.hp = 200, exp.maxHp
  if opts and opts.floor then exp.floor = opts.floor end
  -- rencontre forcée : comme forceEvent (tirages à l'entrée)
  local pool = X.eventPool
  X.eventPool = function() return { evId } end
  assert(X.act(exp, { "path", id }))
  X.eventPool = pool
  eq(exp.event.id, evId)
  local ci
  for i, ch in ipairs(ev.choices) do if ch.label == label then ci = i end end
  assert(ci, evId .. " : réponse " .. label)
  return exp, ci
end

test("neutres : réponses de rencontres (carte donnée, coût payé, palier respecté)", function()
  local cases = {
    { "defias_caravan", "Search the wagon", "rough_dynamite", hp = 3 },
    { "jangolode_prospector", "Buy his dynamite", "rough_dynamite", gold = 20 },
    { "saldean_farm", "Ask for her dumplings", "smoked_desert_dumplings" },
    { "moonbrook_refugees", "Roll bandages with her", "heavy_silk_bandage", hp = 4 },
    { "goblin_peddler", "Buy an iron grenade", "iron_grenade", gold = 35 },
    { "herbalist", "Buy one of her elixirs", "elixir_of_superior_defense", gold = 30 },
    { "lighthouse_keeper", "Search the lighthouse stores", "arcane_bomb", hp = 6 },
  }
  for _, k in ipairs(cases) do
    local exp, ci = neutralAnswer(k[1], k[2])
    local ev = ns.Events[k[1]]
    -- palier de la carte <= palier de la rencontre, sauf réponse cachée tant que non débloquée
    local hidden = X.choiceHidden(newExp({ unlocks = { rep = 0, common = ev.tier } }), ev.choices[ci])
    assert(ns.Cards[k[3]].tier <= ev.tier or ev.choices[ci].when, k[1] .. " : palier")
    assert(not hidden or ns.Cards[k[3]].tier > ev.tier, k[1])
    local n, gold, hp = #exp.deck, exp.gold, exp.hp
    assert(X.act(exp, { "choose", ci }))
    eq(#exp.deck, n + 1, k[1]); eq(exp.deck[#exp.deck].id, k[3], k[1])
    eq(gold - exp.gold, k.gold or 0, k[1] .. " or"); eq(hp - exp.hp, k.hp or 0, k[1] .. " PV")
    -- toujours une issue sans condition, quatre réponses au plus
    assert(#ev.choices <= 4, k[1] .. " : quatre réponses au plus")
  end
end)

test("neutres : la cueilleuse ne propose l'élixir qu'une fois débloqué (réponse absente, pas grisée)", function()
  for _, lv in ipairs({ 1, 2 }) do
    local exp = neutralAnswer("herbalist", "Buy one of her elixirs", lv)
    local labels = {}
    for _, o in ipairs(X.eventOptions(exp)) do labels[#labels + 1] = o.label end
    local shown = table.concat(labels, "|"):find("elixirs", 1, true) ~= nil
    eq(shown, lv >= 2, "palier " .. lv)
    local listed = false
    for _, a in ipairs(X.choices(exp)) do if a[1] == "choose" and a[2] == 3 then listed = true end end
    eq(listed, lv >= 2, "choix possible au palier " .. lv)
    if lv < 2 then eq(X.act(exp, { "choose", 3 }), false, "refusée") end
  end
end)

test("neutres : choix de rencontre parmi les cartes neutres (cardChoice neutral = true)", function()
  ns.Events.test_neutral = { name = "x", act = 1, tier = 0, text = "", speaker = "x", npc = "x", scene = "road",
    choices = { { label = "x", outcome = "x", effects = { { "cardChoice", n = 3, neutral = true } } } } }
  local exp, ci = neutralAnswer("test_neutral", "x", 1)
  local ok = X.act(exp, { "choose", ci })
  ns.Events.test_neutral = nil
  assert(ok)
  eq(exp.phase, "reward")
  eq(#exp.reward.cards, 3)
  for _, id in ipairs(exp.reward.cards) do assert(isNeutral(id) and ns.Cards[id].tier <= 1, id) end
end)

---------------------------------------------------------------------------
-- Bibelots communs de la fiche (docs/bibelots-communs.md) : crochets d'expédition, paliers, utilité
---------------------------------------------------------------------------

local NEW_RELICS = {
  [0] = { "scroll_of_intellect", "bloodsail_admirals_hat", "herb_pouch", "lifegiving_gem" },
  { "darkmoon_prize_ticket", "head_of_onyxia", "demonic_rune", "brilliant_mana_oil", "talisman_of_ephemeral_power",
    "bag_of_marbles", "royal_seal_of_eldre_thalas" },
  { "philosophers_stone", "mark_of_the_champion", "onyxia_scale_cloak", "hourglass_sand", "flint_and_tinder",
    "harm_prevention_belt", "drake_fang_talisman" },
  { "ironfoe", "travelers_backpack" },
}

test("bibelots communs : débloqués par palier de Ligue, jamais avant", function()
  for lv = 0, 3 do
    local exp = newExp({ unlocks = { rep = 0, common = lv } })
    local pool = {}
    for _, id in ipairs(X.relicPool(exp)) do pool[id] = true end
    for t = 0, 3 do
      for _, id in ipairs(NEW_RELICS[t]) do eq(pool[id] == true, t <= lv, id .. " au palier " .. lv) end
    end
  end
end)

test("bibelots communs : utiles à la classe (Rogue sans Cast ni Absorb : trois exclus), aucun ailleurs", function()
  local excluded = { focus_talisman = true, talisman_of_ephemeral_power = true, harm_prevention_belt = true }
  for _, cl in ipairs(NEUTRAL_CLASSES) do
    local exp = newExp({ class = cl, unlocks = { rep = 2, common = 3 } })
    local pool = {}
    for _, id in ipairs(X.relicPool(exp)) do pool[id] = true end
    for t = 0, 3 do
      for _, id in ipairs(NEW_RELICS[t]) do
        local want = not (cl == "rogue" and excluded[id])
        eq(pool[id] == true, want, cl .. " : " .. id)
      end
    end
    eq(pool.focus_talisman == true, cl ~= "rogue", cl .. " : Talisman of Focus")
    -- les tirages passent par le même filtre
    for _, id in ipairs(ns.Rewards.relicPool({ class = cl, maxTier = 3 })) do
      assert(cl ~= "rogue" or not excluded[id], cl .. " Rewards : " .. id)
    end
  end
  assert(X.classHas("mage", "cast") and not X.classHas("rogue", "cast") and X.classHas("warrior", "castDamage"))
  assert(not X.classHas("rogue", "absorb") and X.classHas("hunter", "absorb"))
end)

test("Bloodsail Admiral's Hat : +20 po aux élites et boss, après les pourcentages, quel que soit l'ordre", function()
  for _, order in ipairs({ { "defias_purse", "bloodsail_admirals_hat" }, { "bloodsail_admirals_hat", "defias_purse" } }) do
    local exp = newExp()
    for _, id in ipairs(order) do X.gainRelic(exp, id) end
    eq(X.gainGold(exp, 30, "elite"), math.floor(30 * 1.25 + 0.5) + 20, order[1])
    eq(X.gainGold(exp, 80, "boss"), 100 + 20)
    eq(X.gainGold(exp, 16, "combat"), 20, "combat normal : pourcentage seul")
  end
  local e = newExp()
  X.gainRelic(e, "bloodsail_admirals_hat")
  enter(e, "elite")
  local g = e.gold
  winCombat(e)
  eq(e.gold - g, e.reward.gold + 20, "récompense d'élite")
end)

test("Herb Pouch : un emplacement de potion de plus, en combat et à la sauvegarde", function()
  local exp = newExp()
  X.gainRelic(exp, "herb_pouch")
  eq(#exp.potions, 4)
  exp.potions = { "test_potion", "test_potion", "test_potion", false }
  assert(X.gainPotion(exp, "test_potion"))
  eq(X.gainPotion(exp, "test_potion"), false, "quatre pleins")
  exp.potions[4] = "healing_potion"
  enter(exp, "combat")
  eq(#exp.combat.player.potions, 4)
  assert(X.act(exp, { "potion", 4 }), "potion du 4e emplacement bue")
  exp.fight.reward.potion = nil
  winCombat(exp)
  eq(#exp.potions, 4); eq(exp.potions[4], false)
  assert(Save.isPlain(exp))
  local r = reload(exp)
  eq(#r.potions, 4, "sauvegarde relue")
end)

test("Lifegiving Gem : +8 PV max et +8 PV au ramassage", function()
  local exp = newExp()
  local mx = exp.maxHp
  exp.hp = mx - 20
  X.gainRelic(exp, "lifegiving_gem")
  eq(exp.maxHp, mx + 8); eq(exp.hp, mx - 12)
end)

test("Darkmoon Faire Prize Ticket : premier retrait gratuit à chaque marchand, prix normal ensuite", function()
  local exp = newExp()
  X.gainRelic(exp, "darkmoon_prize_ticket")
  eq(X.removePrice(exp), 75, "hors du marchand : prix normal")
  enter(exp, "merchant")
  exp.gold = 0
  eq(X.removePrice(exp), 0)
  assert(X.act(exp, { "remove", 1 }), "gratuit même sans or")
  eq(exp.gold, 0)
  eq(X.removePrice(exp), X.REMOVE_PRICE + X.REMOVE_STEP, "deuxième retrait payant (le premier compte)")
  eq(X.act(exp, { "remove", 1 }), false, "pas assez d'or")
  assert(X.act(exp, { "leave" }))
  -- marchand suivant : de nouveau gratuit
  exp.phase = "map"
  local nx = ns.Map.nextNodes(exp.map, exp.node)[1]
  exp.map.nodes[nx].kind = "merchant"
  assert(X.act(exp, { "path", nx }))
  eq(X.removePrice(exp), 0, "nouvelle visite")
end)

test("Head of Onyxia : une potion après chaque élite gagnée, rien si les emplacements sont pleins ni après un combat", function()
  local exp = newExp()
  X.gainRelic(exp, "head_of_onyxia")
  enter(exp, "elite")
  exp.fight.reward.potion = nil
  winCombat(exp)
  local n = 0
  for _, p in ipairs(exp.potions) do if p then n = n + 1 end end
  eq(n, 1, "élite : une potion")
  local full = newExp({ seed = 12 })
  X.gainRelic(full, "head_of_onyxia")
  full.potions = { "test_potion", "test_potion", "test_potion" }
  enter(full, "elite")
  winCombat(full)
  eq(full.potions[1], "test_potion"); eq(#full.potions, 3, "pleins : rien")
  local c = newExp({ seed = 13 })
  X.gainRelic(c, "head_of_onyxia")
  enter(c, "combat")
  c.fight.reward.potion = nil
  winCombat(c)
  eq(c.potions[1], false, "combat normal : rien")
end)

test("Flint and Tinder : le repos améliore aussi une carte ; Royal Seal : repos à moitié", function()
  local exp = newExp()
  X.gainRelic(exp, "flint_and_tinder")
  enter(exp, "campfire")
  exp.hp = 20
  local up = exp.stats.upgraded
  assert(X.act(exp, { "rest" }))
  eq(exp.stats.upgraded, up + 1); eq(exp.hp, 20 + math.floor(exp.maxHp * 0.30))
  -- deck entièrement amélioré : rien, sans erreur
  local full = newExp({ seed = 14 })
  X.gainRelic(full, "flint_and_tinder")
  for _, card in ipairs(full.deck) do card.up = true end
  enter(full, "campfire")
  assert(X.act(full, { "rest" }))
  local s = newExp({ seed = 15 })
  X.gainRelic(s, "royal_seal_of_eldre_thalas")
  enter(s, "campfire")
  s.hp = 20
  X.act(s, { "rest" })
  eq(s.hp, 20 + math.floor(s.maxHp * 0.15))
  enter(newExp(), "combat")
  local m = newExp({ seed = 16 })
  X.gainRelic(m, "royal_seal_of_eldre_thalas")
  enter(m, "combat")
  eq(m.combat.player.mana, 4, "+1 mana")
end)

---------------------------------------------------------------------------
-- Campagne par zones (13/11/2026)
---------------------------------------------------------------------------

-- Fin d'expédition simulée : la classe gagne (ou perd) la zone à cette clé.
local function finishIn(db, class, zone, key, result)
  local e = assert(Save.start(db, { seed = 30 + (key or 0), class = class, zone = zone, key = key or 0 }))
  e.stats.cleared, e.stats.elites, e.stats.bosses = 8, 1, (result or "won") == "won" and 1 or 0
  e.result, e.phase = result or "won", "done"
  return (Save.finish(db, "t"))
end

test("zones : registre (sept zones dans l'ordre), Westfall seule jouable, données de zone cohérentes", function()
  local names = {}
  for i, id in ipairs(ns.Zone.ORDER) do
    eq(ns.Zones[id].order, i, id)
    names[i] = ns.Zones[id].name
  end
  eq(table.concat(names, ", "), "Westfall, Duskwood, Wetlands, Stranglethorn Vale, Swamp of Sorrows, Burning Steppes, Blackrock Mountain")
  eq(ns.Zone.FIRST, "westfall")
  assert(ns.Zone.playable("westfall"))
  -- une zone est jouable dès que son fichier de données pose ses groupes (docs/zones.md), Coming later sinon
  for i = 2, 7 do
    local id = ns.Zone.ORDER[i]
    eq(ns.Zone.playable(id), ns.Zones[id].encounters ~= nil, id .. " : Coming later")
  end
  eq(ns.Zone.next("westfall"), "duskwood"); eq(ns.Zone.next("blackrock"), nil); eq(ns.Zone.prev("westfall"), nil)
  local exp = newExp()
  eq(exp.zone, "westfall"); eq(X.actName(exp), "Westfall"); eq(X.zoneDef(exp).encounters, "westfall")
  -- données réelles : champs zone et key valides (cartes de zone et bibelots de clé à venir)
  for id, d in pairs(ns.Cards) do
    if d.zone then assert(ns.Zones[d.zone] and d.class, id .. " : carte de zone (zone connue, de classe)") end
  end
  for id, r in pairs(ns.Relics) do
    if r.key then
      assert(type(r.key) == "table" and ns.Zones[r.key.zone], id .. " : zone du bibelot de clé")
      assert(r.key.level == 1 or r.key.level == 3 or r.key.level == 5, id .. " : clé +1, +3 ou +5")
    end
  end
  for id, ev in pairs(ns.Events) do
    assert(ev.zone == nil or ns.Zones[ev.zone], id .. " : zone de la rencontre")
    eq(ev.act, nil, id .. " : plus de champ act")
  end
end)

test("zones : gagner une zone avec une classe ouvre la suivante pour elle seule", function()
  local db = Save.new()
  local m = db.meta
  assert(Meta.zoneOpen(m, "mage", "westfall")); eq(Meta.zoneOpen(m, "mage", "duskwood"), false)
  local e, why = Save.start(db, { seed = 1, class = "mage", zone = "duskwood" })
  eq(e, nil); eq(why, "zone coming later", "Duskwood : déclarée, pas jouable")
  finishIn(db, "mage", "westfall", 0, "lost")
  eq(Meta.zoneOpen(m, "mage", "duskwood"), false, "défaite : rien")
  local s = finishIn(db, "mage", "westfall", 0)
  eq(s.zoneWon, true); eq(s.zoneOpened, "duskwood"); eq(s.zone, "westfall")
  assert(Meta.zoneOpen(m, "mage", "duskwood"), "Duskwood ouverte pour le Mage")
  eq(Meta.zoneOpen(m, "mage", "wetlands"), false)
  eq(Meta.zoneOpen(m, "priest", "duskwood"), false, "pas pour le Prêtre")
  eq(Meta.classWon(m, "mage", "westfall"), true); eq(Meta.classWon(m, "priest", "westfall"), false)
  local again = finishIn(db, "mage", "westfall", 0)
  eq(again.zoneWon, nil, "deuxième victoire : plus une première"); eq(again.zoneOpened, nil)
  -- zone fermée pour la classe : refusée même si elle devenait jouable
  ns.Zones.wetlands.encounters = "westfall"
  local x, w2 = Save.start(db, { seed = 2, class = "mage", zone = "wetlands" })
  eq(x, nil); eq(w2, "zone locked")
  ns.Zones.wetlands.encounters = nil
  assert(Save.validate(db))
end)

test("zones : carte de zone introuvable avant la première victoire de la classe dans la zone", function()
  ns.Cards.test_zone_card = { id = "test_zone_card", name = "Carte de zone", class = "priest", path = "discipline",
    zone = "westfall", rarity = "rare", cost = 1, type = "skill", text = "", effects = {} }
  local exp = newExp()
  eq(X.unlocked(exp, ns.Cards.test_zone_card), false)
  eq(count(X.cardPool(exp), "test_zone_card"), 0, "verrouillée")
  eq(count(X.cardPool(newExp({ unlocks = { level = 7, common = 7, won = { duskwood = 5 } } })), "test_zone_card"), 0,
    "une autre zone gagnée ne l'ouvre pas")
  eq(count(Meta.classContent("priest").cards, "test_zone_card"), 0, "hors de la grille des niveaux")
  local db = Save.new()
  local s = finishIn(db, "priest", "westfall", 0)
  -- (avec les cartes épiques réelles de la classe dans cette zone : Prayer of Mending)
  eq(count(s.zoneCards, "test_zone_card"), 1, "annoncée en fin d'expédition")
  eq(table.concat(s.zoneCards, ","), table.concat(Meta.zoneCards("priest", "westfall"), ","), "toutes celles de la zone")
  local e = assert(Save.start(db, { seed = 3, class = "priest" }))
  assert(X.unlocked(e, ns.Cards.test_zone_card))
  eq(count(X.cardPool(e), "test_zone_card"), 1, "dans la réserve de la classe")
  eq(count(X.cardPool(newExp({ class = "mage", unlocks = { level = 7, won = { westfall = 0 } } })), "test_zone_card"), 0,
    "jamais pour une autre classe")
  db.current = nil
  eq(#finishIn(db, "priest", "westfall", 0).zoneCards, 0, "une seule fois")
  ns.Cards.test_zone_card = nil
end)

test("zones : commun débloqué par la première victoire du compte dans une zone (toutes classes)", function()
  -- table de répartition : tier N = zone d'ordre N
  local c1 = Meta.commonContent(1)
  local function has(list, id) return count(list, id) == 1 end
  assert(has(c1.cards, "runecloth_bag") and has(c1.cards, "iron_grenade"), "neutres de l'ancien palier Amical")
  assert(has(c1.relics, "darkmoon_prize_ticket") and has(c1.events, "moonbrook_refugees"))
  eq(#c1.perks, 0)
  eq(table.concat(Meta.commonContent(3).perks, ","), "startRelic")
  eq(table.concat(Meta.commonContent(6).perks, ","), "merchantRelic")
  eq(#Meta.commonContent(7).cards + #Meta.commonContent(7).relics, 0, "rien au-delà de l'ancien palier 3 aujourd'hui")
  local db = Save.new()
  eq(Meta.commonTier(db.meta), 0)
  local fresh = assert(Save.start(db, { seed = 4, class = "warrior" }))
  eq(fresh.unlock.common, 0)
  eq(count(X.neutralPool(fresh), "runecloth_bag"), 0, "compte neuf : palier 0 seulement")
  eq(count(X.relicPool(fresh), "darkmoon_prize_ticket"), 0)
  db.current = nil
  local s = finishIn(db, "warrior", "westfall", 0)
  eq(s.accountZone, true); assert(s.common and has(s.common.cards, "runecloth_bag"), "annoncé en fin d'expédition")
  eq(Meta.commonTier(db.meta), 1); eq(db.meta.zones.westfall, true)
  -- une autre classe en profite tout de suite, sans avoir gagné la zone
  local h = assert(Save.start(db, { seed = 5, class = "hunter" }))
  eq(h.unlock.common, 1)
  eq(count(X.neutralPool(h), "runecloth_bag"), 1)
  eq(count(X.relicPool(h), "darkmoon_prize_ticket"), 1)
  eq(Meta.zoneOpen(db.meta, "hunter", "duskwood"), false, "mais pas la zone suivante")
  db.current = nil
  local s2 = finishIn(db, "hunter", "westfall", 0)
  eq(s2.zoneWon, true); eq(s2.accountZone, nil, "le compte avait déjà gagné Westfall"); eq(s2.common, nil)
end)

test("clés : une par zone et par classe, +N ouvre +N+1 dans cette zone pour cette classe", function()
  local db = Save.new()
  local m = db.meta
  for k = 0, 2 do finishIn(db, "mage", "westfall", k) end
  eq(Meta.keyMax(m, "mage", "westfall"), 3, "Mage : Westfall +3 ouverte")
  eq(Meta.bestKey(m, "mage", "westfall"), 2)
  eq(Meta.keyMax(m, "priest", "westfall"), 0, "rien pour le Prêtre")
  eq(Meta.keyMax(m, "mage", "duskwood"), 0, "rien dans une autre zone")
  local e, why = Save.start(db, { seed = 6, class = "priest", key = 1 })
  eq(e, nil); eq(why, "key locked")
  assert(Save.start(db, { seed = 7, class = "mage", key = 3 }))
  db.current = nil
  local s = finishIn(db, "mage", "westfall", 3)
  eq(s.keyUnlocked, 4)
  eq(m.classes.mage.zones.westfall.keyMax, 4)
  eq(m.classes.mage.keyMax, nil, "plus de clé au niveau de la classe")
  -- affixes inchangés
  eq(#Meta.affixesFor(5), 5); eq(Meta.MAX_KEY, 5)
end)

test("clés : bibelot de clé débloqué par la première victoire de la classe à +1, +3, +5 dans la zone", function()
  ns.Relics.test_key3 = { id = "test_key3", name = "Bibelot de clé", text = "", rarity = "rare",
    key = { zone = "westfall", level = 3 } }
  ns.Relics.test_key5_mage = { id = "test_key5_mage", name = "Bibelot de clé du Mage", text = "", rarity = "rare",
    class = "mage", key = { zone = "westfall", level = 5 } }
  eq(table.concat(Meta.KEY_RELIC_LEVELS, ","), "1,3,5")
  local exp = newExp({ unlocks = { level = 7, common = 7, won = { westfall = 2 } } })
  eq(X.unlocked(exp, ns.Relics.test_key3), false, "Westfall gagnée à +2 seulement")
  eq(count(X.relicPool(exp), "test_key3"), 0)
  local db = Save.new()
  for k = 0, 2 do eq(#finishIn(db, "priest", "westfall", k).keyRelics, 0) end
  local s = finishIn(db, "priest", "westfall", 3)
  eq(table.concat(s.keyRelics, ","), "test_key3", "annoncé en fin d'expédition")
  eq(#finishIn(db, "priest", "westfall", 3).keyRelics, 0, "une seule fois")
  local p = assert(Save.start(db, { seed = 8, class = "priest", key = 4 }))
  eq(count(X.relicPool(p), "test_key3"), 1, "dans le tirage du Prêtre")
  eq(count(X.relicPool(p), "test_key5_mage"), 0, "bibelot réservé au Mage")
  db.current = nil
  local w = assert(Save.start(db, { seed = 9, class = "warrior" }))
  eq(count(X.relicPool(w), "test_key3"), 0, "le Guerrier n'a pas gagné Westfall +3")
  db.current = nil
  eq(count(Meta.classContent("mage").relics, "test_key5_mage"), 0, "hors de la grille des niveaux")
  -- simulation : zones=7 débloque tout
  local all = newExp({ class = "mage", unlocks = Meta.allUnlocked(7) })
  eq(count(X.relicPool(all), "test_key3"), 1); eq(count(X.relicPool(all), "test_key5_mage"), 1)
  ns.Relics.test_key3, ns.Relics.test_key5_mage = nil, nil
end)

test("sauvegarde v4 -> v5 : zones par classe et du compte, Ligue abandonnée, expédition en cours jouable", function()
  local cur = newExp({ seed = 12, class = "priest", unlocks = { level = 2, common = 3 } })
  enter(cur, "combat")
  -- état d'une sauvegarde v4 : ni zone ni déblocages de zone, palier de Ligue figé
  cur.version, cur.zone, cur.unlock = 4, nil, { level = 2, league = 3 }
  local v4 = { version = 4, meta = { league = 1500, runs = 9, flags = { tobin_spared = true }, classes = {
      priest = { xp = 180, runs = 5, wins = 3, keyMax = 2, bestKey = 1 },
      mage = { xp = 40, runs = 2, wins = 0, keyMax = 0, bestKey = -1 },
    } }, current = cur, journal = { { result = "won", class = "priest", rep = 110, xp = 70 } },
    options = { scale = 1.1 } }
  local db, note = Save.migrate(reload(v4))
  eq(note, "migrated"); eq(db.version, 5)
  local m = db.meta
  eq(m.league, nil, "réputation de Ligue abandonnée")
  eq(m.zones.westfall, true, "le compte a gagné Westfall")
  local pz = m.classes.priest.zones.westfall
  eq(pz.won, true); eq(pz.keyMax, 2); eq(pz.bestKey, 1)
  eq(m.classes.priest.keyMax, nil); eq(m.classes.priest.xp, 180, "expérience gardée")
  eq(m.classes.mage.zones.westfall, nil, "Mage sans victoire : Westfall pas gagnée")
  assert(Meta.zoneOpen(m, "priest", "duskwood")); eq(Meta.zoneOpen(m, "mage", "duskwood"), false)
  eq(m.flags.tobin_spared, true); eq(db.options.scale, 1.1); eq(db.journal[1].rep, 110, "journal intact")
  local x = db.current
  assert(x, "expédition gardée")
  eq(x.version, 6); eq(x.zone, "westfall")
  eq(x.unlock.level, 2); eq(x.unlock.league, nil); eq(x.unlock.common, 1); eq(x.unlock.won.westfall, 1)
  assert(Save.validate(db))
  -- l'expédition continue : combat, puis fin et méta
  assert(X.act(x, { "endTurn" }))
  winCombat(x)
  if x.phase == "reward" then assert(X.act(x, { "leave" })) end
  eq(x.phase, "map")
  assert(X.act(x, { "abandon" }))
  local s = Save.finish(db, "z")
  assert(s and s.xp >= 0)
  eq(m.classes.priest.runs, 6)
  -- idempotente ; sauvegarde v4 sans victoire : le compte n'a rien gagné
  local again = reload(db)
  Save.migrate(again)
  eq(serialize(again), serialize(db))
  local none = Save.migrate({ version = 4, meta = { league = 50, runs = 1, flags = {}, classes = {
    rogue = { xp = 20, runs = 1, wins = 0, keyMax = 0, bestKey = -1 } } }, journal = {} })
  eq(next(none.meta.zones), nil); eq(next(none.meta.classes.rogue.zones), nil)
  assert(Save.validate(none))
end)

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
