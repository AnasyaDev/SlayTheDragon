-- Tests du socle des règles de zone (ns.ZoneRules, crochets du moteur, actions d'ennemis génériques,
-- cases et effets d'expédition, bots) avec une zone factice « testzone », puis les tests propres à
-- chaque zone : Sim/tests_zone_<zone>.lua (return function(T) … end, T décrit plus bas), lancés dans
-- l'ordre de la campagne s'ils existent.
-- Usage : lua5.1 Sim/tests_zones.lua (ou luajit) -> ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local ns = dofile(root .. "/Sim/load.lua")(root)
local Combat, Card, X, ZR, Rng = ns.Combat, ns.Card, ns.Expedition, ns.ZoneRule, ns.Rng

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

-- Une sauvegarde ne contient que des données simples (clés chaîne ou nombre, aucune fonction).
local function plainData(v, seen, path)
  local t = type(v)
  path = path or "racine"
  if t == "function" or t == "userdata" or t == "thread" then return false, path .. " : " .. t end
  if t ~= "table" then return true end
  seen = seen or {}
  if seen[v] then return true end -- instances de cartes partagées (orig) : permis
  seen[v] = true
  for k, x in pairs(v) do
    if type(k) ~= "string" and type(k) ~= "number" then return false, path .. " : clé " .. type(k) end
    local ok, why = plainData(x, seen, path .. "." .. tostring(k))
    if not ok then return false, why end
  end
  return true
end

-- Combat de test. o = { hand = { ids } (main de départ exacte, dans l'ordre), deck = { ids en plus, en
-- pioche }, enemies = { ids | specs }, zone, kind, class, relics, hp, mods, start, seed }.
local function combat(o)
  o = o or {}
  local deck = {}
  for _, id in ipairs(o.hand or {}) do deck[#deck + 1] = { id = id, up = false } end
  for _, id in ipairs(o.deck or {}) do deck[#deck + 1] = { id = id, up = false } end
  local c = Combat.new({ seed = o.seed or 7, class = o.class or "priest", hp = o.hp or 60, maxHp = o.hp or 60,
    deck = deck, encounter = o.enemies or { "zt_dummy" }, zone = o.zone, kind = o.kind or "combat",
    relics = o.relics, mods = o.mods, start = o.start })
  -- main exactement o.hand (dans l'ordre), le reste en pioche
  local all = {}
  for _, x in ipairs(c.hand) do all[#all + 1] = x end
  for _, x in ipairs(c.draw) do all[#all + 1] = x end
  local byId = {}
  for _, x in ipairs(all) do byId[x.id] = byId[x.id] or {}; table.insert(byId[x.id], x) end
  c.hand, c.draw = {}, {}
  for _, id in ipairs(o.hand or {}) do c.hand[#c.hand + 1] = table.remove(byId[id]) end
  local rest = {}
  for id in pairs(byId) do rest[#rest + 1] = id end
  table.sort(rest)
  for _, id in ipairs(rest) do for _, x in ipairs(byId[id]) do c.draw[#c.draw + 1] = x end end
  return c
end

local function handIndex(c, id)
  for i, x in ipairs(c.hand) do if x.id == id then return i end end
end

-- Joue la carte id (sur l'ennemi n° t) ; échoue si refusée.
local function play(c, id, t)
  local i = handIndex(c, id)
  assert(i, "carte absente de la main : " .. id)
  local ok, why = Combat.play(c, i, t)
  assert(ok, "jeu refusé : " .. id .. " (" .. tostring(why) .. ")")
end

-- Règles de la zone factice (remplacées à chaque test).
local function zone(t)
  return ZR.define("testzone", t or {})
end

local function noZone()
  ns.ZoneRules.testzone = nil
end

-- T : ce que reçoit chaque fichier Sim/tests_zone_<zone>.lua.
local T = { ns = ns, root = root, test = test, eq = eq, combat = combat, play = play, handIndex = handIndex,
  plainData = plainData }

---------------------------------------------------------------------------
-- Données de test (zone factice)
---------------------------------------------------------------------------

local E = ns.Enemies
E.zt_dummy = { name = "Dummy", hp = 50, moves = { idle = { name = "Idle", intent = "buff", actions = {} } }, pattern = { "idle" } }
E.zt_hitter = { name = "Hitter", hp = 50,
  moves = { hit = { name = "Hit", intent = "attack", actions = { { "attack", 5, times = 2 } } } }, pattern = { "hit" } }
E.zt_caster = { name = "Caster", hp = 50,
  moves = { bolt = { name = "Bolt", intent = "cast", cast = true, actions = { { "attack", 9 } } } }, pattern = { "bolt" } }
E.zt_phaser = { name = "Phaser", hp = 100,
  moves = { idle = { name = "Idle", intent = "buff", actions = {} },
    poke = { name = "Poke", intent = "attack", actions = { { "attack", 3 } } },
    slam = { name = "Slam", intent = "attack", actions = { { "attack", 10 } } } },
  pattern = { "idle" },
  phases = {
    { at = 0.5, name = "Enraged", say = "Rage!", enter = { { "buff", "force", 2 } }, open = "slam",
      pattern = { "slam", "poke" }, startAt = 2, text = "Gains Strength 2." },
    { at = 0.25, name = "Last Stand", open = "poke", rename = "Phaser Prime" },
  } }
E.zt_boss = { name = "Capped Boss", hp = 100, boss = true,
  moves = { idle = { name = "Idle", intent = "buff", actions = {} }, poke = { name = "Poke", intent = "attack", actions = { { "attack", 3 } } } },
  pattern = { "idle" }, phases = { { at = 0.5, name = "Half", cap = true, open = "poke" } } }
E.zt_opener = { name = "Opener", hp = 50, open = "big",
  moves = { big = { name = "Big", intent = "attack", actions = { { "attack", 12 } } },
    poke = { name = "Poke", intent = "attack", actions = { { "attack", 3 } } } }, pattern = { "poke" } }
E.zt_support = { name = "Support", hp = 50,
  moves = {
    heal = { name = "Heal", intent = "heal", actions = { { "heal_allies", 5 } } },
    ward = { name = "Ward", intent = "defend", actions = { { "block_allies", 3 }, { "block_boss", 4 } } },
    call = { name = "Call", intent = "summon", actions = { { "say", "Come!" }, { "summon", "zt_hitter", count = 3, max = 2, ambush = true } } },
    curse = { name = "Curse", intent = "debuff", actions = { { "addCard", "zt_curse", to = "hand" } } },
    pop = { name = "Pop", intent = "attack", actions = { { "attack", 4 }, { "die" } } },
    stoke = { name = "Stoke", intent = "buff", actions = { { "zt_stoke", 2 } } },
    maybe = { name = "Maybe", intent = "attack", actions = { { "attack", 7, cond = "zt_flag" }, { "block", 2 } } },
    bonus = { name = "Bonus", intent = "attack", actions = { { "attack", 4, more = { { 3, "zt_flag" } }, per = { 2, "allies" }, cap = 4 } } },
  },
  pattern = { "heal" } }
E.zt_bigboss = { name = "Big Boss", hp = 80, boss = true,
  moves = { idle = { name = "Idle", intent = "buff", actions = {} } }, pattern = { "idle" } }

ns.Statuses.zt_mark = { name = "Test Mark", debuff = true, text = "Test status." }

local C = ns.Cards
C.zt_strike = { id = "zt_strike", name = "Test Strike", cost = 1, type = "attack", target = "enemy",
  effects = { { "damage", 6 } }, text = "Deal 6." }
C.zt_nova = { id = "zt_nova", name = "Test Nova", cost = 1, type = "attack",
  effects = { { "damage", 60, all = true } }, text = "Deal 60 to all." }
C.zt_trap = { id = "zt_trap", name = "Test Trap", cost = 0, type = "skill", trap = true,
  effects = { { "damage", 5 } }, text = "Trap.\nDeal 5." }
C.zt_curse = { id = "zt_curse", name = "Test Curse", cost = 1, type = "skill", token = true, exhaust = true,
  effects = {}, endOfTurn = { { "loseHp", 2 } }, text = "Curse.\nEnd of turn: lose 2 HP.\nExhaust." }
C.zt_hexed = { id = "zt_hexed", name = "Test Hexed", cost = 1, type = "skill", token = true, vanish = true,
  effects = { { "restore" } }, text = "Turn back into the hexed card, in your hand." }
C.zt_interrupt = { id = "zt_interrupt", name = "Test Kick", cost = 0, type = "skill", target = "enemy",
  effects = { { "interrupt" }, { "damage", 4, cond = "interrupted" } }, text = "Interrupt the target's cast.\nInterrupted: deal 4." }
C.zt_cleanse = { id = "zt_cleanse", name = "Test Cleanse", cost = 0, type = "skill",
  effects = { { "cleanse" } }, text = "Remove negative effects." }
C.zt_keep = { id = "zt_keep", name = "Test Keep", cost = 1, type = "skill", retain = true,
  effects = { { "absorb", 1 } }, text = "Gain 1 Absorb.\nRetain." }

Combat.ENEMY_CONDITIONS.zt_flag = function(c) return c.zs ~= nil and c.zs.testzone ~= nil and c.zs.testzone.flag == true end
Combat.ENEMY_ACTIONS.zt_stoke = function(c, e, a)
  local z = c.zs.testzone
  z.counter = (z.counter or 3) - a[2]
  ZR.counterChanged(c, "testzone", "counter", z.counter, -a[2])
end

---------------------------------------------------------------------------
-- 1. Règles actives, état, clone, sauvegarde
---------------------------------------------------------------------------

test("sans règle de zone : c.zr et c.zs absents (Westfall ne change pas)", function()
  noZone()
  local c = combat({ zone = "westfall" })
  eq(c.zr, nil); eq(c.zs, nil); eq(c.zone, "westfall"); eq(c.kind, "combat")
  eq(Combat.zoneRulesFor("westfall"), nil)
end)

test("règles actives dans leur zone seulement ; always = true partout ; init après la classe", function()
  local order = {}
  zone({ init = function(c, z) z.ready = true order[#order + 1] = "init" end,
    hooks = { onCombatStart = function(c, z) order[#order + 1] = "start:" .. tostring(z.ready) end } })
  local c = combat({ zone = "testzone" })
  eq(c.zr[1], "testzone"); eq(c.zs.testzone.ready, true); eq(table.concat(order, ","), "init,start:true")
  local w = combat({ zone = "westfall" })
  eq(w.zr, nil, "zone d'une autre zone")
  zone({ always = true, hooks = {} })
  local w2 = combat({ zone = "westfall" })
  eq(w2.zr[1], "testzone", "always = true : active dans Westfall")
  noZone()
end)

test("état de zone : copie profonde par Combat.clone (combat et unité) ; données simples", function()
  zone({ init = function(c, z) z.list = { 1, 2 } ZR.unitState(c.enemies[1], "testzone").marks = { 3 } end })
  local c = combat({ zone = "testzone" })
  local t = Combat.clone(c)
  t.zs.testzone.list[1] = 9
  t.enemies[1].zs.testzone.marks[1] = 9
  eq(c.zs.testzone.list[1], 1); eq(c.enemies[1].zs.testzone.marks[1], 3)
  local ok, why = plainData(c.zs); assert(ok, why)
  noZone()
end)

---------------------------------------------------------------------------
-- 2. Déroulé du combat : début, tours, phase ennemie, fin
---------------------------------------------------------------------------

test("ordre des crochets d'un round (début et fin de tour, phase ennemie, fin de round, intentions)", function()
  local log = {}
  local function mark(name) return function(c, z, a) log[#log + 1] = name .. (a ~= nil and (":" .. tostring(a)) or "") end end
  zone({ hooks = { onTurnStart = mark("turnStart"), onIntents = mark("intents"), onTurnEnd = mark("turnEnd"),
    onHandEnd = mark("handEnd"), onEnemyPhaseStart = mark("phaseStart"), afterEnemyMove = function(c, z, e, mv) log[#log + 1] = "after:" .. mv end,
    onEnemyPhaseEnd = mark("phaseEnd"), onRoundEnd = mark("roundEnd") } })
  local c = combat({ zone = "testzone", enemies = { "zt_hitter" } })
  log = {}
  Combat.endTurn(c)
  eq(table.concat(log, ","), "turnEnd,handEnd,phaseStart,after:hit,phaseEnd:false,roundEnd:false,turnStart,intents")
  eq(c.step, "play")
  noZone()
end)

test("hpLoss (perte hors coup annulée), onHeal (soin rendu), zstat (statistiques de zone)", function()
  local healed = 0
  zone({ hooks = { hpLoss = function(c, z, n, why) if why == "wildfire" and not z.used then z.used = true return 0 end return n end,
    onHeal = function(c, z, unit, n) healed = healed + n end } })
  local c = Combat.new({ seed = 1, class = "priest", hp = 60, maxHp = 60, deck = {}, encounter = { "zt_dummy" },
    zone = "testzone", stats = true })
  Combat.loseHp(c, 5, "wildfire")
  eq(c.player.hp, 60, "première annulée")
  Combat.loseHp(c, 5, "wildfire")
  eq(c.player.hp, 55)
  Combat.heal(c, c.player, 10)
  eq(healed, 5, "soin réellement rendu")
  Combat.zstat(c, "burns", 2)
  eq(c.stats.zone.burns, 2)
  noZone()
end)

test("enemyDamageLast : après enemyDamageTaken des zones et des bibelots (Rude Awakening après +4)", function()
  zone({ hooks = { enemyDamageLast = function(c, z, v) return math.ceil(v * 1.5) end } })
  ns.Relics.zt_relic = { id = "zt_relic", name = "Test", text = "", rarity = "common", noPool = true,
    hooks = { enemyDamageTaken = function(c, src, v) return v + 4 end } }
  local c = combat({ zone = "testzone", hand = { "zt_strike" }, relics = { "zt_relic" } })
  play(c, "zt_strike", 1)
  eq(c.enemies[1].hp, 50 - 15, "(6 + 4) × 1,5")
  ns.Relics.zt_relic = nil
  noZone()
end)

test("onCombatEnd : victoire, défaite", function()
  local got
  zone({ hooks = { onCombatEnd = function(c, z, r) got = r end } })
  local c = combat({ zone = "testzone", hand = { "zt_nova" } })
  play(c, "zt_nova")
  eq(got, "won")
  local d = combat({ zone = "testzone", hp = 3 })
  Combat.loseHp(d, 5, "wildfire")
  eq(got, "lost")
  noZone()
end)

test("perte de PV de terrain : ignore l'Absorb, why transmis à onHpLost, peut tuer en fin de round", function()
  local why
  zone({ hooks = { onHpLost = function(c, z, n, src) why = src end,
    onRoundEnd = function(c, z) Combat.loseHp(c, 100, "wildfire") end } })
  local c = combat({ zone = "testzone" })
  c.player.block = 20
  Combat.loseHp(c, 4, "wildfire")
  eq(c.player.hp, 56); eq(c.player.block, 20); eq(why, "wildfire")
  Combat.endTurn(c)
  eq(c.result, "lost", "fin de round mortelle : le tour suivant ne commence pas")
  noZone()
end)

---------------------------------------------------------------------------
-- 3. Actions ennemies : remplacer, sauter, Stunned, incantations
---------------------------------------------------------------------------

test("enemyMove : false saute l'action (dormeur), un autre move la remplace", function()
  zone({ hooks = { enemyMove = function(c, z, mv, e) if z.sleep then return false end if z.swap then return "idle" end return mv end } })
  local c = combat({ zone = "testzone", enemies = { "zt_hitter" } })
  c.zs.testzone.sleep = true
  Combat.endTurn(c)
  eq(c.player.hp, 60, "sauté")
  c.zs.testzone.sleep = nil
  E.zt_hitter.moves.idle = { name = "Idle", intent = "buff", actions = {} }
  c.zs.testzone.swap = true
  Combat.endTurn(c)
  eq(c.player.hp, 60, "remplacé")
  c.zs.testzone.swap = nil
  Combat.endTurn(c)
  eq(c.player.hp, 50, "normal")
  E.zt_hitter.moves.idle = nil
  noZone()
end)

test("onEnemyStunned : le tour perdu est notifié, l'action ne part pas", function()
  local n = 0
  zone({ hooks = { onEnemyStunned = function() n = n + 1 end } })
  local c = combat({ zone = "testzone", enemies = { "zt_hitter" } })
  Combat.applyStatus(c, c.enemies[1], "stunned", 1)
  Combat.endTurn(c)
  eq(n, 1); eq(c.player.hp, 60)
  noZone()
end)

test("incantations ennemies : commencée, interrompue (condition interrupted), résolue", function()
  local log = {}
  zone({ hooks = {
    onEnemyCastStart = function(c, z, e, mv) log[#log + 1] = "start:" .. mv end,
    onEnemyCastInterrupted = function(c, z, e, mv, by) log[#log + 1] = "cut:" .. by end,
    onEnemyCastResolved = function(c, z, e, mv) log[#log + 1] = "done:" .. mv end } })
  local c = combat({ zone = "testzone", enemies = { "zt_caster" }, hand = { "zt_interrupt" } })
  eq(log[1], "start:bolt")
  play(c, "zt_interrupt", 1)
  eq(log[2], "cut:player"); eq(c.enemies[1].hp, 46, "Interrupted: deal 4")
  Combat.endTurn(c)
  eq(c.player.hp, 60, "sort perdu"); eq(#log, 3); eq(log[3], "start:bolt")
  Combat.endTurn(c)
  eq(log[4], "done:bolt"); eq(c.player.hp, 51)
  noZone()
end)

test("afterEnemyAttack : PV perdus au total d'une attaque à plusieurs coups (une fois par action)", function()
  local calls = {}
  zone({ hooks = { afterEnemyAttack = function(c, z, e, a, total) calls[#calls + 1] = total end } })
  local c = combat({ zone = "testzone", enemies = { "zt_hitter" } })
  c.player.block = 7
  Combat.endTurn(c)
  eq(#calls, 1); eq(calls[1], 3)
  noZone()
end)

---------------------------------------------------------------------------
-- 4. Dégâts aux ennemis : source, avant / après, morts du même effet
---------------------------------------------------------------------------

test("enemyDamageTaken : source du coup (card à une cible, card à tous, dot, trap, potion) et plafond", function()
  local seen = {}
  zone({ hooks = { enemyDamageTaken = function(c, z, v, e, src)
    seen[#seen + 1] = src.kind .. (src.single and "1" or "*")
    if z.cap then return math.min(v, z.cap) end
    return v
  end } })
  local c = combat({ zone = "testzone", enemies = { "zt_dummy", "zt_dummy" }, hand = { "zt_strike", "sw_pain", "zt_trap" } })
  play(c, "zt_strike", 1)
  eq(seen[1], "card1")
  play(c, "sw_pain", 1)
  c.zs.testzone.cap = 2
  Combat.tickDot(c, c.enemies[1])
  eq(seen[2], "dot*"); eq(c.enemies[1].hp, 50 - 6 - 2, "plafonné à 2")
  c.zs.testzone.cap = nil
  local d = combat({ zone = "testzone", enemies = { "zt_dummy", "zt_dummy" }, hand = { "zt_nova" } })
  E.zt_dummy.hp = 100
  d = combat({ zone = "testzone", enemies = { "zt_dummy", "zt_dummy" }, hand = { "zt_nova" } })
  seen = {}
  play(d, "zt_nova")
  eq(seen[1], "card*"); eq(seen[2], "card*")
  E.zt_dummy.hp = 50
  -- Trap déclenchée par une attaque ennemie
  local t = combat({ zone = "testzone", enemies = { "zt_hitter" }, hand = { "zt_trap" } })
  seen = {}
  play(t, "zt_trap")
  Combat.endTurn(t)
  eq(seen[1], "trap1")
  -- potion à cible
  local p = combat({ zone = "testzone" })
  p.player.potions[1] = "liquid_fire"
  seen = {}
  assert(Combat.usePotion(p, 1, 1))
  eq(seen[1], "potion1")
  noZone()
end)

test("onEnemyDamaged : après le coup (PV perdus, absorbés), même entièrement absorbé ; pas sur un coup mortel", function()
  local got = {}
  zone({ hooks = { onEnemyDamaged = function(c, z, e, loss, absorbed, src) got[#got + 1] = loss .. "/" .. absorbed .. ":" .. src.kind end } })
  local c = combat({ zone = "testzone", hand = { "zt_strike", "zt_nova" } })
  c.enemies[1].block = 10
  play(c, "zt_strike", 1)
  eq(got[1], "0/6:card")
  play(c, "zt_nova")
  eq(#got, 1, "coup mortel : rien")
  noZone()
end)

test("onEnemyDeath : info.effect identique pour des morts du même effet, différent sinon ; onEffectEnd", function()
  local deaths, ends = {}, {}
  zone({ hooks = {
    onEnemyDeath = function(c, z, e, info) deaths[#deaths + 1] = info.effect .. ":" .. info.kind end,
    onEffectEnd = function(c, z, kind, id) ends[#ends + 1] = kind .. ":" .. id end } })
  local c = combat({ zone = "testzone", enemies = { "zt_dummy", "zt_dummy", "zt_bigboss" }, hand = { "zt_nova", "zt_strike" } })
  play(c, "zt_nova")
  eq(#deaths, 2)
  eq(deaths[1], deaths[2], "même effet")
  local id = tonumber(deaths[1]:match("^(%d+)"))
  eq(ends[#ends], "card:" .. id, "fin de l'effet de la carte")
  -- un DoT est toujours un effet à part
  local d = combat({ zone = "testzone", enemies = { "zt_dummy", "zt_bigboss" } })
  deaths = {}
  d.enemies[1].hp = 2
  Combat.applyStatus(d, d.enemies[1], "pain", 3)
  Combat.endTurn(d)
  eq(#deaths, 1); assert(deaths[1]:find(":dot$"), deaths[1])
  noZone()
end)

---------------------------------------------------------------------------
-- 5. Cartes : piochées, défaussées, gardées, cartes de combat, transformation
---------------------------------------------------------------------------

test("cartes piochées, gardées (Retain), défaussées en fin de tour ; main entière dans onHandEnd", function()
  local drawn, kept, disc, handN = 0, {}, {}, nil
  zone({ hooks = {
    onCardDrawn = function() drawn = drawn + 1 end,
    onCardKept = function(c, z, inst, why) kept[#kept + 1] = inst.id .. ":" .. why end,
    onCardDiscarded = function(c, z, inst, why) disc[#disc + 1] = why end,
    onHandEnd = function(c) handN = #c.hand end } })
  local c = combat({ zone = "testzone", hand = { "zt_keep", "zt_strike" }, deck = { "smite", "smite", "smite", "smite", "smite" } })
  eq(drawn, 5, "pioche de départ")
  drawn = 0
  Combat.endTurn(c)
  eq(handN, 2); eq(kept[1], "zt_keep:retain"); eq(disc[1], "turn"); eq(drawn, 5)
  noZone()
end)

test("Combat.addCard : main, dessus de la pioche, défausse ; main pleine vers la défausse ; journal", function()
  local added = {}
  zone({ hooks = { onCardAdded = function(c, z, inst, to, src) added[#added + 1] = to .. ":" .. tostring(src) end } })
  local c = combat({ zone = "testzone", hand = { "zt_strike" } })
  local a = Combat.addCard(c, "zt_curse", "hand", { src = 1, lift = true })
  eq(c.hand[#c.hand], a); eq(a.src, 1); eq(a.lift, true); eq(a.id, "zt_curse")
  Combat.addCard(c, "zt_curse", "draw")
  eq(c.draw[#c.draw].id, "zt_curse", "dessus de la pioche")
  Combat.addCard(c, "zt_curse", "discard")
  eq(c.discard[#c.discard].id, "zt_curse")
  for _ = #c.hand + 1, Combat.HAND_MAX do Combat.addCard(c, "zt_strike", "hand") end
  local full = Combat.addCard(c, "zt_curse", "hand")
  eq(Combat.findCard(c, full), "discard")
  eq(added[1], "hand:1"); eq(added[#added], "discard:nil")
  noZone()
end)

test("cartes levées à la mort de leur source (lift) : épuisées, onExhaust ; carte de combat jouée : Exhaust", function()
  local ex = {}
  zone({ hooks = { onExhaust = function(c, z, inst, why) ex[#ex + 1] = inst.id .. ":" .. why end } })
  local c = combat({ zone = "testzone", enemies = { "zt_dummy", "zt_bigboss" }, hand = { "zt_nova" } })
  E.zt_dummy.hp = 50
  Combat.addCard(c, "zt_curse", "hand", { src = c.enemies[1].uid, lift = true })
  Combat.addCard(c, "zt_curse", "discard", { src = c.enemies[1].uid, lift = true })
  Combat.addCard(c, "zt_curse", "discard", { src = c.enemies[2].uid, lift = true })
  play(c, "zt_nova")
  eq(#ex, 2); eq(ex[1], "zt_curse:lifted")
  eq(Combat.countCards(c, function(inst) return inst.id == "zt_curse" end), 1, "celle du boss reste")
  local d = combat({ zone = "testzone", hand = {} })
  Combat.addCard(d, "zt_curse", "hand")
  ex = {}
  play(d, "zt_curse")
  eq(ex[1], "zt_curse:played"); eq(d.exhaust[#d.exhaust].id, "zt_curse")
  noZone()
end)

test("carte « End of turn » en main : ses effets partent avant la défausse", function()
  local c = combat({ hand = { "zt_strike" } })
  Combat.addCard(c, "zt_curse", "hand")
  Combat.endTurn(c)
  eq(c.player.hp, 58)
end)

test("transformation (Hexed) : remplacée sur place, jouée elle rend l'originale en main et disparaît", function()
  local c = combat({ hand = { "zt_strike", "zt_keep" } })
  local orig = c.hand[1]
  local h = Combat.transformCard(c, orig, "zt_hexed", { src = 1 })
  eq(c.hand[1], h); eq(h.orig, orig); eq(h.id, "zt_hexed")
  local t = Combat.clone(c)
  eq(t.hand[1].orig, orig, "le clone partage l'instance d'origine")
  play(c, "zt_hexed")
  eq(c.hand[#c.hand], orig, "originale en main")
  eq(Combat.findCard(c, h), nil, "la carte transformée a disparu")
  eq(#c.exhaust, 0); eq(#c.discard, 0)
  -- restoreAll
  local d = combat({ hand = { "zt_strike" }, deck = { "smite" } })
  local s = d.draw[1]
  Combat.transformCard(d, s, "zt_hexed")
  ns.Effects.restoreAll(d, {}, { "restoreAll" })
  eq(d.hand[#d.hand], s)
  local ok, why = plainData(c.hand); assert(ok, why)
end)

test("cleanse : le crochet ajoute ses effets retirés (Curses de la main)", function()
  zone({ hooks = { cleanse = function(c, z, n) return n + 2 end } })
  local c = combat({ zone = "testzone", hand = { "zt_cleanse" } })
  Combat.applyStatus(c, c.player, "armor_broken", 2)
  eq(Combat.cleanse(c, c.player), 3)
  noZone()
end)

---------------------------------------------------------------------------
-- 6. Seuils de PV (phases), intention imposée, ouverture
---------------------------------------------------------------------------

test("phases : seuil franchi pendant le tour -> entrée (réplique, actions, nom), ouverture tout de suite", function()
  local phases = {}
  zone({ hooks = { onEnemyPhase = function(c, z, e, k) phases[#phases + 1] = k end } })
  local c = combat({ zone = "testzone", enemies = { "zt_phaser" }, hand = { "zt_strike" } })
  local e = c.enemies[1]
  e.hp = 55
  play(c, "zt_strike", 1)
  eq(e.mem.phase, 1); eq(e.st.force, 2); eq(e.intent, "slam"); eq(phases[1], 1)
  Combat.endTurn(c)
  eq(c.player.hp, 48, "Slam 10 + Strength 2")
  eq(e.intent, "poke", "startAt = 2 : reprend au 2e coup du motif")
  local marks = Combat.phaseMarks(e)
  eq(#marks, 2); eq(marks[1].passed, true); eq(marks[2].passed, false); eq(marks[1].at, 0.5)
  noZone()
end)

test("phases : franchies après le tour (DoT) -> intention annoncée maintenue, ouverture au tour suivant", function()
  local c = combat({ enemies = { "zt_phaser" } })
  local e = c.enemies[1]
  e.hp = 52
  Combat.applyStatus(c, e, "pain", 5)
  local before = e.intent
  Combat.endTurn(c)
  eq(e.mem.phase, 1); eq(before, "idle"); eq(c.player.hp, 60, "l'intention annoncée part (rien)")
  eq(e.intent, "slam", "ouverture au tour suivant")
end)

test("phases : deux seuils d'un coup, le dernier donne l'ouverture ; coup mortel : aucune phase ; nom changé", function()
  local c = combat({ enemies = { "zt_phaser", "zt_bigboss" }, hand = { "zt_strike", "zt_nova" } })
  local e = c.enemies[1]
  e.hp = 30
  play(c, "zt_strike", 1)
  eq(e.mem.phase, 2); eq(e.intent, "poke"); eq(Combat.enemyName(e), "Phaser Prime")
  local d = combat({ enemies = { "zt_phaser", "zt_bigboss" }, hand = { "zt_nova" } })
  d.enemies[1].hp = 55
  play(d, "zt_nova")
  eq(d.enemies[1].dead, true); eq(d.enemies[1].mem.phase, nil)
end)

test("phases : plafond au seuil (cap) pour un boss, dégâts au-delà perdus", function()
  local c = combat({ enemies = { "zt_boss" }, hand = { "zt_nova" } })
  local e = c.enemies[1]
  play(c, "zt_nova")
  eq(e.hp, 50); eq(e.mem.phase, 1); eq(e.dead, false)
end)

test("onEnemyBloodied : une fois, au premier passage à la moitié des PV", function()
  local n = 0
  zone({ hooks = { onEnemyBloodied = function() n = n + 1 end } })
  local c = combat({ zone = "testzone", hand = { "zt_strike" } })
  c.enemies[1].hp = 30
  play(c, "zt_strike", 1)
  Combat.dealDamage(c, c.player, c.enemies[1], 3)
  eq(n, 1)
  noZone()
end)

test("intention d'ouverture (def.open) puis motif ; forceIntent différé avec libellé", function()
  local c = combat({ enemies = { "zt_opener" } })
  local e = c.enemies[1]
  eq(e.intent, "big")
  Combat.endTurn(c)
  eq(e.intent, "poke")
  Combat.forceIntent(c, e, "big", { now = false, label = "On waking" })
  eq(e.intent, "poke"); eq(e.mem.forced, "big")
  local info = Combat.intentInfo(c, e)
  eq(info.forced, "big"); eq(info.forcedLabel, "On waking")
  Combat.endTurn(c)
  eq(e.intent, "big"); eq(e.mem.forced, nil)
  Combat.forceIntent(c, e, "poke")
  eq(e.intent, "poke", "pendant le jeu : tout de suite")
end)

test("crochet intent : remplacer l'intention choisie", function()
  zone({ hooks = { intent = function(c, z, mv, e) if e.id == "zt_opener" then return "poke" end return mv end } })
  local c = combat({ zone = "testzone", enemies = { "zt_opener" } })
  eq(c.enemies[1].intent, "poke")
  noZone()
end)

---------------------------------------------------------------------------
-- 7. Actions et motifs d'ennemis génériques
---------------------------------------------------------------------------

local function supportDoing(move, extra)
  local c = combat({ zone = "testzone", enemies = extra or { "zt_support", "zt_dummy" } })
  c.enemies[1].intent = move
  return c
end

test("heal_allies, block_allies, block_boss", function()
  zone({})
  local c = supportDoing("heal", { "zt_support", "zt_dummy" })
  c.enemies[1].hp, c.enemies[2].hp = 40, 30
  Combat.endTurn(c)
  eq(c.enemies[1].hp, 45); eq(c.enemies[2].hp, 35)
  local d = supportDoing("ward", { "zt_support", "zt_bigboss" })
  for _, a in ipairs(E.zt_support.moves.ward.actions) do Combat.enemyAction(d, d.enemies[1], a) end
  eq(d.enemies[1].block, 3); eq(d.enemies[2].block, 7, "3 à tous + 4 au boss")
  noZone()
end)

test("summon : max par id, ambush agit dans la même phase, réplique ; onEnemySpawn", function()
  local spawned = 0
  zone({ hooks = { onEnemySpawn = function(c, z, e, by) if by then spawned = spawned + 1 end end } })
  local c = supportDoing("call", { "zt_support" })
  Combat.endTurn(c)
  eq(#c.enemies, 3, "max = 2 : deux sur trois"); eq(spawned, 2)
  eq(c.player.hp, 60 - 2 * 10, "les deux invoqués frappent dans la même phase (5 × 2 chacun)")
  noZone()
end)

test("die, addCard (lift), action de zone (Combat.ENEMY_ACTIONS), compteur journalisé", function()
  zone({ init = function(c, z) z.counter = 3 end })
  local c = supportDoing("pop", { "zt_support", "zt_bigboss" })
  Combat.endTurn(c)
  eq(c.enemies[1].dead, true); eq(c.player.hp, 56)
  local d = supportDoing("curse", { "zt_support", "zt_bigboss" })
  Combat.endTurn(d)
  local inst
  for _, x in ipairs(d.hand) do if x.id == "zt_curse" then inst = x end end
  assert(inst and inst.lift and inst.src == d.enemies[1].uid, "Curse en main, levée à la mort du lanceur")
  local s = supportDoing("stoke", { "zt_support" })
  Combat.endTurn(s)
  eq(s.zs.testzone.counter, 1)
  local found
  for _, ev in ipairs(s.events) do if ev.t == "counter" and ev.key == "counter" then found = ev end end
  assert(found and found.n == 1 and found.d == -2, "journal counter")
  noZone()
end)

test("action conditionnelle (cond) et bonus d'attaque (more, per, cap) affichés par intentInfo", function()
  zone({})
  local c = supportDoing("maybe", { "zt_support", "zt_dummy" })
  Combat.endTurn(c)
  eq(c.player.hp, 60, "cond fausse : pas d'attaque"); eq(c.enemies[1].block, 2)
  local d = supportDoing("bonus", { "zt_support", "zt_dummy", "zt_dummy" })
  -- 4 + per 2 × 2 alliés = 8, plafonné à +4 -> 8 ; avec zt_flag : +3 de plus, plafonné à +4 -> 8
  eq(Combat.intentInfo(d, d.enemies[1]).damage, 8)
  d.zs.testzone.flag = true
  eq(Combat.intentInfo(d, d.enemies[1]).damage, 8, "bonus plafonné")
  d.zs.testzone.flag = nil
  d.enemies[2].dead, d.enemies[3].dead = true, true
  eq(Combat.intentInfo(d, d.enemies[1]).damage, 4)
  noZone()
end)

test("groupe : specs (états posés, PV), mods du combat (hors boss), effets de départ", function()
  local c = combat({ enemies = { { "zt_dummy", st = { zt_mark = 2 }, hp = 33 }, "zt_bigboss" },
    mods = { st = { zt_mark = 1 }, hpMul = 2 }, start = { { "apply", "force", 2, self = true }, { "damage", 5, all = true } } })
  local a, b = c.enemies[1], c.enemies[2]
  eq(a.st.zt_mark, 3); eq(a.maxHp, 66); eq(b.st.zt_mark, nil, "boss épargné"); eq(b.maxHp, 80)
  eq(c.player.st.force, 2); eq(a.hp, 66 - 7, "5 + Strength 2"); eq(b.hp, 80 - 7)
end)

test("familier du Hunter : source « pet » à une cible, cible choisie par le crochet petTarget", function()
  local kinds = {}
  zone({ hooks = {
    petTarget = function(c, z, t) return c.enemies[2] end,
    enemyDamageTaken = function(c, z, v, e, src) kinds[#kinds + 1] = src.kind .. (src.single and "1" or "*") .. ":" .. e.uid return v end } })
  local c = combat({ zone = "testzone", class = "hunter", enemies = { "zt_dummy", "zt_dummy" } })
  ns.Hunter.petAttack(c, "card")
  eq(kinds[1], "pet1:" .. c.enemies[2].uid)
  noZone()
end)

---------------------------------------------------------------------------
-- 8. Expédition : crochets run, cases de parcours, effets de rencontre, feu de camp
---------------------------------------------------------------------------

ns.Zones.testzone = { id = "testzone", name = "Test Zone", encounters = "testzone" }
ns.Encounters.testzone = {
  easy = { { "zt_dummy" } }, normal = { { "zt_dummy", "zt_dummy" } },
  elite = { { { "zt_hitter", st = { zt_mark = 1 } } }, { "zt_caster" } }, boss = { { "zt_bigboss" } },
}
ns.Events.zt_node_event = { name = "Test Poster", zone = "testzone", node = true, text = "WANTED: %s.",
  choices = {
    { label = "Hunt", effects = { { "fight", "elite", kind = "elite", group = true, gold = 50,
      reward = { cards = 4, shift = 1 }, st = { zt_mark = 1 } } } },
    { label = "Fly", effects = { { "skipFloors", 1 } } },
    { label = "Drink", effects = { { "nextCombat", { { "apply", "force", 3, self = true } } } } },
    { label = "Custom", effects = { { "zt_effect", 3 } } },
  } }
X.EFFECTS.zt_effect = {
  roll = function(exp, rng, e) return Rng.int(rng, 1, 100) end,
  check = function(exp, e) if exp.gold < e[2] then return false, "gold" end return true end,
  apply = function(exp, e, roll, ctx) exp.zt_roll = roll exp.gold = exp.gold - e[2] ctx.texts[#ctx.texts + 1] = "Paid." end,
}

local function newExp(seed)
  return X.new({ seed = seed or 3, class = "priest", zone = "testzone", unlocks = { level = 7, common = 7 } })
end

-- Entre dans le nœud id (depuis un de ses parents).
local function enter(exp, id)
  for _, node in ipairs(exp.map.nodes) do
    for _, nx in ipairs(node.next) do
      if nx == id then
        exp.node, exp.phase = node.id, "map"
        assert(X.act(exp, { "path", id }))
        return
      end
    end
  end
  exp.node, exp.phase = nil, "map"
  assert(X.act(exp, { "path", id }))
end

test("crochets run de la zone (gold, rewardCards, onRewardRolled) avant les bibelots ; état d'expédition", function()
  zone({ run = { gold = function(exp, v) return v * 2 end, rewardCards = function(exp, v, kind) return kind == "elite" and 5 or v end,
    onRewardRolled = function(exp, r, kind) X.zoneState(exp).rolled = (X.zoneState(exp).rolled or 0) + 1 end } })
  local exp = newExp()
  eq(X.gainGold(exp, 10, "combat"), 20)
  local r = X.rollReward(exp, "elite")
  eq(#r.cards, 5); eq(exp.zs.testzone.rolled, 1)
  local ok, why = plainData(exp); assert(ok, why)
  noZone()
end)

test("case de parcours de zone : placée (flux à part), ouvre sa rencontre ; rencontre node jamais tirée", function()
  X.nodeKind("zt_node", { name = "Test Node", event = "zt_node_event", zone = "testzone", replaces = { "event", "combat" }, minFloor = 2 })
  local exp = newExp()
  local id
  for _, n in ipairs(exp.map.nodes) do if n.kind == "zt_node" then id = n.id end end
  assert(id, "case placée")
  eq(ns.Map.KINDS.zt_node, "Test Node")
  for _, ev in ipairs(X.eventPool(exp)) do assert(ev ~= "zt_node_event", "jamais tirée") end
  enter(exp, id)
  eq(exp.phase, "event"); eq(exp.event.id, "zt_node_event")
  -- groupe tiré à l'entrée, nom dans le texte
  local g = exp.event.rolls[1][1].group
  assert(g and g.pool == "elite", "groupe tiré")
  eq(X.eventText(exp), "WANTED: " .. g.names[1] .. ".")
  -- combat : groupe tiré, états posés (hors boss), récompense de 4 cartes d'une rareté au-dessus, +50 po
  assert(X.act(exp, { "choose", 1 }))
  eq(exp.phase, "combat"); eq(exp.fight.kind, "elite")
  eq(exp.fight.encounter[1], ns.Encounters.testzone.elite[g.idx][1][1] or ns.Encounters.testzone.elite[g.idx][1])
  assert((exp.combat.enemies[1].st.zt_mark or 0) >= 1, "st posé")
  eq(#exp.fight.reward.cards, 4)
  for _, id2 in ipairs(exp.fight.reward.cards) do assert(ns.Cards[id2].rarity ~= "common", "rareté décalée") end
  assert(exp.fight.reward.gold >= 50)
  eq(exp.combat.zone, "testzone"); eq(exp.combat.kind, "elite")
  -- une autre zone n'a pas cette case
  local w = X.new({ seed = 3, class = "priest", zone = "westfall", unlocks = { level = 7, common = 7 } })
  for _, n in ipairs(w.map.nodes) do assert(n.kind ~= "zt_node") end
  X.NODE_KINDS.zt_node, ns.Map.KINDS.zt_node = nil, nil
end)

test("effets de rencontre : skipFloors (X.nextNodes), nextCombat (consommé par le combat), effet de zone (roll/check/apply)", function()
  local exp = newExp(5)
  local start = exp.map.start[1]
  exp.node, exp.phase = start, "map"
  X.openEvent(exp, "zt_node_event")
  assert(X.act(exp, { "choose", 2 }))
  assert(X.act(exp, { "leave" }))
  local nx = X.nextNodes(exp)
  for _, id in ipairs(nx) do eq(exp.map.nodes[id].floor, exp.map.nodes[start].floor + 2) end
  local ch = X.choices(exp)
  eq(ch[1][1], "path"); eq(exp.map.nodes[ch[1][2]].floor, 3)
  -- nextCombat
  local e2 = newExp(6)
  e2.node, e2.phase = e2.map.start[1], "map"
  X.openEvent(e2, "zt_node_event")
  assert(X.act(e2, { "choose", 3 }))
  eq(#e2.nextCombat, 1)
  X.startFight(e2, "combat")
  eq(e2.combat.player.st.force, 3); eq(e2.nextCombat, nil)
  -- effet de zone
  local e3 = newExp(7)
  e3.node, e3.phase = e3.map.start[1], "map"
  X.openEvent(e3, "zt_node_event")
  local roll = e3.event.rolls[4][1]
  assert(type(roll) == "number")
  e3.gold = 2
  eq(select(2, X.eventChoiceOk(e3, 4)), "gold")
  e3.gold = 10
  assert(X.act(e3, { "choose", 4 }))
  eq(e3.zt_roll, roll); eq(e3.gold, 7); assert(e3.event.result:find("Paid.", 1, true))
end)

test("feu de camp : action de zone proposée (can), appliquée, puis départ", function()
  zone({ campfire = { { id = "zt_treat", label = "Treat", text = "Pay 10g: +1 max HP.",
    can = function(exp) if exp.gold < 10 then return false, "gold" end return true end,
    apply = function(exp) exp.gold = exp.gold - 10 exp.maxHp = exp.maxHp + 1 end } } })
  local exp = newExp()
  exp.node, exp.phase = exp.map.start[1], "campfire"
  local has
  for _, a in ipairs(X.choices(exp)) do if a[1] == "campAction" and a[2] == "zt_treat" then has = true end end
  assert(has, "proposée")
  local hp = exp.maxHp
  assert(X.act(exp, { "campAction", "zt_treat" }))
  eq(exp.maxHp, hp + 1); eq(exp.phase, "map")
  exp.phase, exp.gold = "campfire", 0
  for _, a in ipairs(X.choices(exp)) do assert(a[1] ~= "campAction", "refusée sans or") end
  noZone()
end)

test("rencontre enchaînée (chain), soin hors combat (healOut), texte %g, newExpedition (toutes zones)", function()
  ns.Events.zt_bar = { name = "Bar", zone = "testzone", node = true, text = "Free drink.",
    choices = { { label = "Ale", effects = { { "nextCombat", { { "absorb", 5 } } }, { "chain", "zt_bar2" } } } } }
  ns.Events.zt_bar2 = { name = "Bar 2", zone = "testzone", node = true, text = "Against %g.",
    choices = { { label = "Pay", effects = { { "heal", 10 }, { "fight", "normal", group = true } } } } }
  zone({ run = { healOut = function(exp, v) return v / 2 end },
    newExpedition = function(exp) exp.maxHp = exp.maxHp + 6 end })
  local exp = newExp()
  local cd = ns.Classes.priest
  eq(exp.maxHp, cd.hp + 6, "newExpedition")
  exp.node, exp.phase = exp.map.start[1], "map"
  X.openEvent(exp, "zt_bar")
  assert(X.act(exp, { "choose", 1 }))
  eq(exp.phase, "event"); eq(exp.event.id, "zt_bar2"); eq(#exp.nextCombat, 1)
  eq(X.eventText(exp), "Against Dummy and Dummy.")
  exp.hp = 20
  assert(X.act(exp, { "choose", 1 }))
  eq(exp.hp, 25, "soin divisé par deux")
  eq(exp.phase, "combat"); eq(exp.combat.player.block, 5)
  ns.Events.zt_bar, ns.Events.zt_bar2 = nil, nil
  noZone()
end)

test("défaite contre un groupe de specs : killedBy lisible", function()
  local exp = newExp()
  exp.node, exp.phase = exp.map.start[1], "map"
  X.startFight(exp, "elite", "elite", nil, { idx = 1 })
  exp.combat.player.hp = 1
  Combat.loseHp(exp.combat, 5, "test")
  X.act(exp, { "endTurn" })
  eq(exp.killedBy, "zt_hitter")
end)

---------------------------------------------------------------------------
-- 9. Langage, bots
---------------------------------------------------------------------------

test("mot-clé de zone : registre du langage (L.zoneKeyword), liste par zone", function()
  local L = ns.Language
  L.zoneKeyword("testzone", "zt_word", { name = "Testword", text = "a test zone keyword." })
  eq(L.keywords.zt_word.zone, "testzone"); eq(L.zoneWords.testzone[1], "zt_word")
  L.keywords.zt_word, L.zoneWords.testzone = nil, nil
end)

test("bots : valeur, clé et coups écartés de la zone (ns.ZoneBots)", function()
  local Bots = ns.Bots
  zone({})
  local calls = { value = 0, key = 0, skip = 0 }
  ns.ZoneBots.testzone = {
    value = function(c, W) calls.value = calls.value + 1 return 0 end,
    key = function(c) calls.key = calls.key + 1 return "z" end,
    skip = function(c, a) calls.skip = calls.skip + 1 return c.hand[a[1]].id == "zt_strike" end,
  }
  local c = combat({ zone = "testzone", hand = { "zt_strike", "inner_fire" } })
  local seq = Bots.planTurn(c, 50)
  assert(calls.value > 0 and calls.key > 0 and calls.skip > 0)
  for _, ref in ipairs(seq) do
    for _, x in ipairs(c.hand) do if x.uid == ref.uid then assert(x.id ~= "zt_strike", "coup écarté") end end
  end
  ns.ZoneBots.testzone = nil
  noZone()
end)

test("simulation : une expédition complète dans la zone factice (bot, case de zone, SE.KIND_SCORE)", function()
  X.nodeKind("zt_node", { name = "Test Node", event = "zt_node_event", zone = "testzone", replaces = { "event", "combat" }, minFloor = 2 })
  local scored = 0
  ns.SimExpedition.KIND_SCORE.zt_node = function(exp, hp) scored = scored + 1 return 5 end
  ns.SimExpedition.EFFECT_VALUE.zt_effect = function() return -5 end
  local rec, exp = ns.SimExpedition.play({ seed = 2, class = "priest", zone = "testzone", zones = 0, level = 1, bot = "greedy" })
  assert(exp.phase == "done", "expédition finie")
  assert(scored > 0, "score de la case demandé")
  eq(exp.zone, "testzone")
  X.NODE_KINDS.zt_node, ns.Map.KINDS.zt_node = nil, nil
  ns.SimExpedition.KIND_SCORE.zt_node, ns.SimExpedition.EFFECT_VALUE.zt_effect = nil, nil
end)

---------------------------------------------------------------------------
-- Tests propres à chaque zone : Sim/tests_zone_<zone>.lua (return function(T) … end)
---------------------------------------------------------------------------

noZone()
for _, id in ipairs(ns.Zone.ORDER) do
  local path = root .. "/Sim/tests_zone_" .. id .. ".lua"
  local f = io.open(path, "r")
  if f then
    f:close()
    print("-- " .. id)
    dofile(path)(T)
  end
end

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
