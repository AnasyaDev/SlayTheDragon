-- Tests de l'arbre de talents du Hunter (Data/Talents/hunter.lua ; docs/talents.md, § 8 et 17) : forme de l'arbre
-- (Talent.check), ordre du bot, un test par nœud, accord des épiques, simulation à même graine.
-- Usage : lua5.1 Sim/tests_talents_hunter.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
if jit and jit.opt then pcall(jit.opt.start, "maxtrace=65535", "maxmcode=262144") end
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Meta, Combat, Talent, U = ns.Expedition, ns.Meta, ns.Combat, ns.Talent, ns.Util
local H, HT = ns.Hunter, ns.HunterTalents
local HHP = ns.Classes.hunter.hp

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

ns.Enemies.th_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.th_hitter = { name = "Cogneur", hp = 100,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }

local function entries(map, spec) return Talent.entries("hunter", map, spec) end

-- Combat du Hunter avec ces talents (deck de départ, mannequin), sans bibelot.
local function hcombat(map, spec, o)
  o = o or {}
  local deck = {}
  for _, id in ipairs(o.deck or { "arcane_shot", "arcane_shot", "disengage", "disengage", "serpent_sting",
    "freezing_trap", "arcane_shot", "disengage" }) do
    deck[#deck + 1] = { id = id, up = false }
  end
  local ts = map and entries(map, spec) or nil
  return Combat.new({ seed = o.seed or 5, class = "hunter", hp = o.hp or 50, maxHp = 50, deck = deck,
    encounter = o.encounter or { "th_dummy" }, relics = o.relics, talents = ts and U.copy(ts) or nil,
    tstate = ts and (o.tstate or {}) or nil, quiet = true })
end

local function hexp(map, spec, o)
  o = o or {}
  local unlocks = Meta.allUnlocked(o.level or 1, o.zones or 0)
  unlocks.talents, unlocks.spec = map, spec
  return X.new({ seed = o.seed or 11, class = "hunter", unlocks = unlocks, quiet = true })
end

local function enter(exp, kind)
  local id = exp.map.start[1]
  exp.map.nodes[id].kind = kind or "combat"
  assert(X.act(exp, { "path", id }))
end
local function winCombat(exp)
  local c = exp.combat
  for _, e in ipairs(c.enemies) do
    if not e.dead then e.hp, e.block, e.st.pain = 1, 0, 5 end
  end
  assert(X.act(exp, { "endTurn" }))
  if exp.phase == "combat" then assert(X.act(exp, { "endTurn" })) end
end

local function idx(c, id)
  for i, x in ipairs(c.hand) do if x.id == id then return i end end
end

---------------------------------------------------------------------------
-- Forme de l'arbre, ordre du bot
---------------------------------------------------------------------------
test("arbre du Hunter : 14 nœuds, 24 points, 4 rangées, un Specialization, ordre du bot légal", function()
  local errs = Talent.check("hunter")
  assert(#errs == 0, table.concat(errs, " ; "))
  local t = ns.Talents.hunter
  eq(#t.nodes, 14)
  local rows = { 0, 0, 0, 0 }
  for _, n in ipairs(t.nodes) do rows[n.row] = rows[n.row] + n.ranks end
  eq(rows[1], 8); eq(rows[2], 5); eq(rows[3], 5); eq(rows[4], 6)
  eq(t.rows[1], 0); eq(t.rows[2], 5); eq(t.rows[3], 10); eq(t.rows[4], 16)
  for _, id in ipairs({ "toughness", "provisions", "field_medic", "veterans_arsenal" }) do assert(t.byId[id], id) end
  eq(t.byId.toughness.row, 1); eq(t.byId.provisions.row, 2); eq(t.byId.field_medic.row, 3)
  eq(t.byId.veterans_arsenal.row, 4)
  eq(t.byId.toughness.text[3], ("+%d max HP."):format(3 * HT.hp))
  eq(#t.byId.specialization.choices, 3)
  -- un nœud « une fois par expédition » en rangée 4
  eq(t.byId.deterrence.row, 4)
  assert(t.byId.deterrence.text[1]:find("^Once per expedition"))
  -- textes : anglais simple, une phrase qui finit par un point ; aucun nom de carte de la classe
  for _, n in ipairs(t.nodes) do
    local list = {}
    for _, s in ipairs(n.text or {}) do list[#list + 1] = s end
    for _, ch in ipairs(n.choices or {}) do list[#list + 1] = ch.text end
    for _, s in ipairs(list) do assert(s:find("%.$") and not s:find("[éèàç]"), n.id .. " : " .. s) end
    local card = ns.Cards[n.id]
    assert(not (card and card.class == "hunter"), n.id .. " : nom d'une carte")
  end
  -- icônes présentes
  for _, n in ipairs(t.nodes) do
    assert(n.icon, n.id .. " : icône")
    for _, ch in ipairs(n.choices or {}) do assert(ch.icon, ch.id .. " : icône") end
  end
end)

test("tree= : parts de l'arbre du Hunter dans l'ordre du bot (palier 60 % = rangées 1 et 2, voie, Natural Mending)", function()
  local map, spec, n = Talent.fromShare("hunter", 60)
  eq(n, 15); eq(Talent.spentIn(map), 15); eq(spec, "beast_mastery")
  local want = { toughness = 3, kindred_spirits = 2, unleashed_fury = 1, bestial_discipline = 2, thrill_of_the_hunt = 2,
    trap_mastery = 2, provisions = 1, specialization = 1, natural_mending = 1 }
  for id, r in pairs(want) do eq(map[id], r, id) end
  for id in pairs(map) do assert(want[id], "en trop : " .. id) end
  local twenty = Talent.fromShare("hunter", 20)
  eq(Talent.spentIn(twenty), 5)
  eq(Talent.spentIn((Talent.fromShare("hunter", 100, "survival"))), 24)
  eq(select(2, Talent.fromShare("hunter", 100, "survival")), "survival")
end)

---------------------------------------------------------------------------
-- Nœuds
---------------------------------------------------------------------------
test("Toughness : +3 PV max par rang au départ de l'expédition", function()
  local e = hexp({ toughness = 3, provisions = 1 })
  eq(e.maxHp, HHP + 3 * HT.hp); eq(e.hp, e.maxHp); eq(e.gold, X.START_GOLD + 100)
end)

test("Kindred Spirits : +1 Frenzy par rang au début du combat (avec Kibler's Bits)", function()
  eq(hcombat(nil).player.res, 0)
  eq(hcombat({ kindred_spirits = 1 }).player.res, HT.kindred)
  eq(hcombat({ kindred_spirits = 2 }).player.res, 2 * HT.kindred)
  eq(hcombat({ kindred_spirits = 2 }, nil, { relics = { "kiblers_bits" } }).player.res, 2 * HT.kindred + 1)
end)

test("Unleashed Fury : le familier frappe de 1 de plus (PET_BASE lu sur le combat, module intact)", function()
  for r = 0, 1 do
    local c = hcombat(r > 0 and { unleashed_fury = r } or nil)
    eq(H.petBase(c), H.PET_BASE + r * HT.fury)
    c.player.res = 2
    local e = c.enemies[1]
    local hp = e.hp
    H.petAttack(c, "card")
    eq(hp - e.hp, H.PET_BASE + r * HT.fury + 2, "rang " .. r)
    eq(c.player.res, 3, "+1 Frenzy")
  end
  eq(H.PET_BASE, 1, "module intact")
end)

test("Bestial Discipline : le Frenzy ne baisse qu'aux rounds pairs (rang 2 : un round sur trois)", function()
  local function after(map, rounds)
    local c = hcombat(map)
    c.player.res = 3
    for _ = 1, rounds do
      Combat.endPlayerTurn(c) -- (attaque du familier : +1)
      Combat.enemyPhase(c); Combat.endRound(c)
      Combat.startPlayerTurn(c)
    end
    return c.player.res
  end
  eq(after(nil, 1), 3, "sans talent : +1 puis -1")
  eq(after({ bestial_discipline = 1 }, 1), 4, "round 1 : pas de baisse")
  eq(after({ bestial_discipline = 1 }, 2), 4, "round 2 : baisse")
  eq(after(nil, 2), 3)
  eq(after({ bestial_discipline = 2 }, 2), 5, "rang 2 : rounds 1 et 2 sans baisse")
  eq(after({ bestial_discipline = 2 }, 3), 4, "rang 2 : baisse au round 3 (plafond 5)")
  eq(ns.Talents.hunter.byId.bestial_discipline.text[1], "Frenzy drops only every other round.")
  eq(ns.Talents.hunter.byId.bestial_discipline.text[2], "Frenzy drops only every third round.")
  eq(H.DECAY_EVERY, 1, "module intact")
end)

test("Animal Handler : plafond de Frenzy +1 par rang", function()
  eq(Combat.resCap(hcombat(nil)), 5)
  eq(Combat.resCap(hcombat({ animal_handler = 1 })), 6)
  local c = hcombat({ animal_handler = 2 })
  eq(Combat.resCap(c), 7)
  Combat.gainRes(c, 9); eq(c.player.res, 7)
end)

test("Trap Mastery : +1 Frenzy par rang à chaque Trap déclenchée", function()
  for _, tm in ipairs({ 0, 1, 2 }) do
    local c = hcombat(tm > 0 and { trap_mastery = tm } or nil, nil, { deck = { "freezing_trap", "freezing_trap",
      "freezing_trap", "freezing_trap", "freezing_trap" } })
    assert(Combat.play(c, idx(c, "freezing_trap")))
    eq(#c.traps, 1)
    Combat.triggerTrap(c, c.enemies[1])
    eq(c.player.res, tm * HT.trapFrenzy, "Trap Mastery " .. tm)
  end
end)

test("Specialization Beast Mastery : la première fois du combat que le Frenzy atteint 5, le familier attaque", function()
  local c = hcombat({ specialization = 1 }, "beast_mastery")
  local e = c.enemies[1]
  c.player.res = 3
  local hp = e.hp
  Combat.gainRes(c, 1); eq(e.hp, hp, "4 : rien")
  Combat.gainRes(c, 1)
  eq(hp - e.hp, H.PET_BASE + HT.bmAt, "5 : le familier frappe (1 + 5)")
  eq(c.player.res, 5, "plafond")
  hp = e.hp
  Combat.gainRes(c, 1); eq(e.hp, hp, "déjà à 5 : rien")
  local k = Combat.clone(c)
  Combat.gainRes(c, -1, "decay"); Combat.gainRes(c, 1)
  eq(e.hp, hp, "redescendu puis remonté : plus rien dans ce combat")
  eq(k.cls.bmDone, true, "état de classe copié par Combat.clone")
  -- de 3 à 6 d'un coup (plafond 7) : une attaque, son +1 ne relance rien
  local c2 = hcombat({ specialization = 1, animal_handler = 2 }, "beast_mastery")
  c2.player.res = 3
  local hp2 = c2.enemies[1].hp
  Combat.gainRes(c2, 3)
  eq(hp2 - c2.enemies[1].hp, H.PET_BASE + 6); eq(c2.player.res, 7)
end)

test("Specialization Marksmanship : +2 par coup des Attacks sur une cible au-dessus de la moitié", function()
  local c = hcombat({ specialization = 1 }, "marksmanship")
  local e = c.enemies[1]
  local shot = ns.Cards.arcane_shot
  eq(Combat.calcDamage(c, c.player, e, 6, shot), 6 + HT.mmBonus)
  eq(Combat.calcDamage(c, c.player, e, 6, ns.Cards.serpent_sting), 6, "Skill")
  eq(Combat.calcDamage(c, c.player, e, 6, nil), 6, "familier")
  e.hp = 50
  eq(Combat.calcDamage(c, c.player, e, 6, shot), 6, "moitié des PV : pas de Careful Aim")
end)

test("Specialization Survival : une Trap déclenchée inflige 4 à l'attaquant", function()
  for _, sv in ipairs({ false, true }) do
    local c = hcombat(sv and { specialization = 1 } or nil, sv and "survival" or nil,
      { deck = { "freezing_trap", "freezing_trap", "freezing_trap", "freezing_trap", "freezing_trap" } })
    local e = c.enemies[1]
    assert(Combat.play(c, idx(c, "freezing_trap")))
    Combat.triggerTrap(c, e)
    eq(e.hp, 100 - (sv and HT.svDamage or 0), "Survival " .. tostring(sv))
  end
end)

test("Natural Mending : soin de 1 à la première attaque du familier de chaque tour", function()
  local c = hcombat({ natural_mending = 1 })
  c.player.hp = 30
  for _ = 1, 3 do H.petAttack(c, "card") end
  eq(c.player.hp, 30 + HT.mend)
  Combat.endPlayerTurn(c) -- (attaque automatique : même tour)
  eq(c.player.hp, 30 + HT.mend)
  local k = Combat.clone(c)
  Combat.enemyPhase(c); Combat.endRound(c); Combat.startPlayerTurn(c)
  H.petAttack(c, "card")
  eq(c.player.hp, 30 + 2 * HT.mend, "tour suivant")
  eq(k.cls.mendRound, 1, "état de classe copié par Combat.clone")
  local c = hcombat(nil)
  c.player.hp = 30
  H.petAttack(c, "card"); eq(c.player.hp, 30)
end)

test("Thrill of the Hunt : +1 Frenzy par rang quand un ennemi meurt", function()
  for r = 0, 2 do
    local c = hcombat(r > 0 and { thrill_of_the_hunt = r } or nil, nil, { encounter = { "th_dummy", "th_dummy" } })
    Combat.dealDamage(c, c.player, c.enemies[1], 500)
    assert(c.enemies[1].dead)
    eq(c.player.res, r * HT.thrill, "rang " .. r)
  end
end)

test("Go for the Throat : au début du tour avec 4 Frenzy, +1 mana (rang 2 : et une carte)", function()
  local c = hcombat({ go_for_the_throat = 1 })
  c.player.res = HT.throatAt - 1
  eq(Combat.modify(c, "maxMana", 3), 3)
  c.player.res = HT.throatAt
  eq(Combat.modify(c, "maxMana", 3), 4); eq(Combat.modify(c, "drawPerTurn", 5), 5)
  local deck = {}
  for i = 1, 14 do deck[i] = "arcane_shot" end
  local c2 = hcombat({ go_for_the_throat = 2 }, nil, { deck = deck })
  c2.player.res = HT.throatAt -- (familier : +1, baisse : -1)
  Combat.endPlayerTurn(c2)
  Combat.enemyPhase(c2); Combat.endRound(c2)
  Combat.startPlayerTurn(c2)
  eq(c2.player.mana, 4); eq(#c2.hand, 6)
  -- bots : finir le tour à throatAt + 1 vaut le mana du tour suivant
  local part = Talent.part("hunter", c.talents[1])
  c.player.res = HT.throatAt
  eq(part.bot.value(c, c.talents[1]), 0)
  c.player.res = HT.throatAt + 1
  assert(part.bot.value(c, c.talents[1]) > 0)
end)

test("Deterrence : une fois par expédition, survivre à 1 PV (rang 2 : 10) et sauter le tour ennemi", function()
  local c = hcombat({ deterrence = 1 }, nil, { encounter = { "th_hitter", "th_hitter" } })
  c.player.hp, c.player.block = 5, 0
  Combat.endTurn(c) -- premier coup : mort évitée, second ennemi sauté
  eq(c.result, nil); eq(c.player.hp, 1); eq(c.tstate.deterrence, true)
  eq(c.player.flags.skipEnemyTurn, nil, "drapeau consommé")
  Combat.endTurn(c)
  eq(c.result, "lost", "une seule fois")
  local c2 = hcombat({ deterrence = 2 })
  c2.player.hp = 3
  Combat.loseHp(c2, 10, "test")
  eq(c2.player.hp, HT.deterHp2); eq(c2.player.flags.skipEnemyTurn, true)
  -- dans l'expédition : l'état revient à l'expédition et suit au combat suivant
  local e = hexp({ deterrence = 1 })
  enter(e, "combat")
  e.combat.player.hp = 2
  Combat.loseHp(e.combat, 10, "test")
  winCombat(e)
  eq(e.talentState.deterrence, true)
  assert(X.act(e, { "leave" }))
  local nx = X.nextNodes(e)[1]
  e.map.nodes[nx].kind = "combat"
  assert(X.act(e, { "path", nx }))
  eq(e.combat.tstate.deterrence, true, "pas une deuxième fois dans l'expédition")
end)

test("Feign Death (carte) avant Deterrence : le talent reste pour plus tard", function()
  local c = hcombat({ deterrence = 1 }, nil, { deck = { "feign_death", "feign_death", "feign_death",
    "feign_death", "feign_death" } })
  assert(Combat.play(c, idx(c, "feign_death")))
  c.player.hp = 3
  Combat.loseHp(c, 10, "test")
  eq(c.player.hp, 1); eq(c.tstate.deterrence, nil, "la carte d'abord")
  Combat.loseHp(c, 10, "test")
  eq(c.player.hp, 1); eq(c.tstate.deterrence, true)
end)

---------------------------------------------------------------------------
-- Bots, simulation
---------------------------------------------------------------------------
test("accord des épiques : Lone Wolf moins bien notée avec l'arbre", function()
  local with = hexp({ unleashed_fury = 1 })
  local without = hexp(nil)
  local SE = assert(ns.SimExpedition)
  assert(SE.epicRating)
  assert(ns.Talents.hunter.bot.epic.lone_wolf < 0)
  eq(SE.epicRating(with, "lone_wolf"), SE.epicRating(without, "lone_wolf") + ns.Talents.hunter.bot.epic.lone_wolf)
end)

test("simulation : arbre plein, même graine = mêmes décisions ; sans talents : aucun talent", function()
  local map, spec = Talent.fromShare("hunter", 100)
  local function run()
    return ns.SimExpedition.play({ seed = 12, bot = "human", class = "hunter", zones = 3, level = 7, key = 0,
      talents = map, spec = spec, maxZone = "duskwood" })
  end
  local a, ea = run()
  local b = run()
  eq(a.zones[1].maxHp, HHP + 3 * HT.hp)
  eq(a.hp, b.hp); eq(#a.combats, #b.combats)
  eq(ea.talents[1].id, "toughness")
  local taken = 0
  for _ in pairs(ea.epicTaken or {}) do taken = taken + 1 end
  assert(taken >= 2, "Veteran's Arsenal 2 : deux épiques au départ (" .. taken .. ")")
  local _, en = ns.SimExpedition.play({ seed = 12, bot = "human", class = "hunter", zones = 3, level = 7,
    maxZone = "westfall" })
  eq(en.talents, nil)
end)

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
