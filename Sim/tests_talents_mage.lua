-- Tests de l'arbre de talents du Mage (Data/Talents/mage.lua ; docs/talents.md, § 8) : forme de l'arbre (Talent.check),
-- ordre du bot, un test par nœud, simulation (tree=). Modèle : partie Warrior de Sim/tests_talents.lua.
-- Usage : lua5.1 Sim/tests_talents_mage.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
if jit and jit.opt then pcall(jit.opt.start, "maxtrace=65535", "maxmcode=262144") end
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Meta, Combat, Talent, U = ns.Expedition, ns.Meta, ns.Combat, ns.Talent, ns.Util
local MT = ns.MageTalents
local MHP = ns.Classes.mage.hp

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

ns.Enemies.tmt_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.tmt_hitter = { name = "Cogneur", hp = 100,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }

local function entries(map, spec) return Talent.entries("mage", map, spec) end

-- Combat du Mage avec ces talents (deck de départ par défaut, mannequin), sans bibelot.
local function mcombat(map, spec, o)
  o = o or {}
  local deck = {}
  for _, id in ipairs(o.deck or { "frostbolt", "frostbolt", "frostbolt", "mana_shield", "mana_shield",
    "mana_shield", "mana_shield", "fireball", "fireball", "arcane_blast" }) do
    deck[#deck + 1] = { id = id, up = false }
  end
  local ts = map and entries(map, spec) or nil
  return Combat.new({ seed = o.seed or 5, class = "mage", hp = o.hp or 40, maxHp = 40, deck = deck, kind = o.kind,
    encounter = o.encounter or { "tmt_dummy" }, relics = o.relics, talents = ts and U.copy(ts) or nil,
    tstate = ts and (o.tstate or {}) or nil, quiet = true })
end

local function mexp(map, spec, o)
  o = o or {}
  local unlocks = Meta.allUnlocked(o.level or 1, o.zones or 0)
  unlocks.talents, unlocks.spec = map, spec
  return X.new({ seed = o.seed or 11, class = "mage", unlocks = unlocks, quiet = true })
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
local function nextTurn(c)
  Combat.endPlayerTurn(c)
  Combat.enemyPhase(c); Combat.endRound(c)
  Combat.startPlayerTurn(c)
end

---------------------------------------------------------------------------
-- Forme de l'arbre, ordre du bot
---------------------------------------------------------------------------
test("arbre du Mage : 14 nœuds, 24 points, 4 rangées, un Specialization, ordre du bot légal", function()
  local errs = Talent.check("mage")
  assert(#errs == 0, table.concat(errs, " ; "))
  local t = ns.Talents.mage
  eq(#t.nodes, 14)
  local rows = { 0, 0, 0, 0 }
  for _, n in ipairs(t.nodes) do rows[n.row] = rows[n.row] + n.ranks end
  eq(rows[1], 7); eq(rows[2], 3); eq(rows[3], 6); eq(rows[4], 8)
  eq(t.rows[1], 0); eq(t.rows[2], 5); eq(t.rows[3], 10); eq(t.rows[4], 16)
  for _, id in ipairs({ "toughness", "provisions", "field_medic", "veterans_arsenal" }) do assert(t.byId[id], id) end
  eq(t.byId.toughness.text[3], ("+%d max HP."):format(3 * MT.hp))
  eq(t.byId.arcane_focus.text[1], "Start of combat against elites and bosses: +1 Charge.")
  eq(t.byId.firestarter.text[1], "Start of combat against elites and bosses: gain Instant 1.")
  eq(t.byId.arcane_concentration.text[1], "After each Surge: +1 Charge.")
  eq(t.byId.arcane_concentration.text[2], "After each Surge: +2 Charges.")
  eq(t.byId.arcane_concentration.ranks, 2); eq(t.byId.winters_chill.ranks, 1); eq(t.byId.frost_warding.row, 1)
  eq(t.byId.prismatic_cloak.text[2], ("When a Cast card resolves, gain %d Absorb."):format(2 * MT.cloak))
  eq(t.byId.arcane_mind.text[2], ("Charge cap +%d."):format(2 * MT.mind))
  eq(t.byId.cauterize.text[1], "Once per expedition, a hit that would kill you leaves you at 1 HP.")
  eq(t.byId.cauterize.text[3], ("Once per expedition, a hit that would kill you leaves you at %d HP."):format(MT.saveHp[3]))
  eq(#t.byId.specialization.choices, 3)
  -- textes : anglais simple, une phrase qui finit par un point ; icônes présentes
  for _, n in ipairs(t.nodes) do
    local list = n.choices and {} or n.text
    for _, ch in ipairs(n.choices or {}) do list[#list + 1] = ch.text end
    for _, s in ipairs(list) do assert(s:find("%.$") and not s:find("[éèàç]"), n.id .. " : " .. s) end
    local icons = { n.icon }
    for _, ch in ipairs(n.choices or {}) do icons[#icons + 1] = ch.icon end
    for _, ic in ipairs(icons) do
      local f = io.open(root .. "/Media/Icons/" .. ic .. ".tga", "rb")
      assert(f, n.id .. " : icône absente " .. tostring(ic))
      f:close()
    end
  end
end)

test("tree= : paliers 20 / 40 / 60 % de l'ordre du bot", function()
  local m20 = Talent.fromShare("mage", 20)
  eq(m20.toughness, 3); eq(m20.frost_warding, 1); eq(m20.arcane_mind, 1); eq(Talent.spentIn(m20), 5)
  local m40 = Talent.fromShare("mage", 40)
  eq(m40.arcane_mind, 3); eq(m40.arcane_concentration, 2); eq(m40.provisions, 1); eq(Talent.spentIn(m40), 10)
  eq(m40.arcane_focus, nil, "Arcane Focus : rangée 3")
  local map, spec, n = Talent.fromShare("mage", 60)
  eq(n, 15); eq(spec, "arcane"); eq(spec, ns.Talents.mage.bot.spec)
  local want = { toughness = 3, frost_warding = 1, arcane_mind = 3, arcane_concentration = 2, provisions = 1,
    specialization = 1, winters_chill = 1, prismatic_cloak = 2, field_medic = 1 }
  for id, r in pairs(want) do eq(map[id], r, id) end
  for id in pairs(map) do assert(want[id], "en trop : " .. id) end
  eq(Talent.spentIn((Talent.fromShare("mage", 100, "arcane"))), 24)
  eq(select(2, Talent.fromShare("mage", 100, "fire")), "fire")
end)

---------------------------------------------------------------------------
-- Génériques (nombres du Mage)
---------------------------------------------------------------------------
test("Toughness, Provisions, Field Medic : PV max, or de départ, passage de zone", function()
  local e = mexp({ toughness = 3, provisions = 1 })
  eq(e.maxHp, MHP + 3 * MT.hp); eq(e.hp, e.maxHp); eq(e.gold, X.START_GOLD + ns.TalentCommon.PROVISIONS_GOLD)
  local z = mexp({ field_medic = 1 })
  z.hp = 1
  X.enterZone(z, "duskwood")
  eq(z.transit.healed, math.floor(z.maxHp * ns.TalentCommon.FIELD_MEDIC_HEAL))
end)

test("Veteran's Arsenal : une épique du Mage au choix au départ", function()
  local e = mexp({ veterans_arsenal = 1 }, nil, { zones = 2 })
  eq(e.phase, "start"); eq(e.talentEpicsLeft, 1)
  for _, id in ipairs(e.talentEpics) do eq(ns.Cards[id].class, "mage", id) end
  assert(X.act(e, { "talentEpic", 1 }))
  eq(X.epicCount(e), 1)
end)

---------------------------------------------------------------------------
-- Nœuds du Mage
---------------------------------------------------------------------------
test("Arcane Focus : +1 Charge au début d'un combat d'élite ou de boss (avec Tome of Arcane Brilliance)", function()
  eq(mcombat(nil).player.res or 0, 0)
  eq(mcombat({ arcane_focus = 1 }).player.res or 0, 0, "combat normal : rien")
  eq(mcombat({ arcane_focus = 1 }, nil, { kind = "elite" }).player.res, MT.focus)
  eq(mcombat({ arcane_focus = 1 }, nil, { kind = "boss" }).player.res, MT.focus)
  eq(mcombat({ arcane_focus = 1 }, nil, { relics = { "tome_arcane_brilliance" }, kind = "elite" }).player.res,
    MT.focus + 1)
end)

test("Arcane Concentration : +1 Charge par rang après chaque Surge (après la remise à 0)", function()
  local barrage = ns.Cards.arcane_barrage
  for r = 1, ns.Talents.mage.byId.arcane_concentration.ranks do
    local c = mcombat({ arcane_concentration = r, arcane_mind = 2 }, nil, { deck = { "arcane_barrage",
      "arcane_barrage", "arcane_barrage", "arcane_barrage", "arcane_barrage" } })
    c.player.res = 4
    assert(Combat.play(c, idx(c, "arcane_barrage"), 1))
    eq(c.player.res, MT.conc * r, "rang " .. r)
    -- les dégâts du Surge comptent les 4 Charges dépensées (6 par Charge), plus le bonus des Charges regagnées
    eq(c.enemies[1].hp, 100 - (4 * barrage.effects[2].per[1] + MT.conc * r), "dégâts, rang " .. r)
  end
  local plain = mcombat(nil, nil, { deck = { "arcane_barrage", "arcane_barrage", "arcane_barrage",
    "arcane_barrage", "arcane_barrage" } })
  plain.player.res = 4
  assert(Combat.play(plain, idx(plain, "arcane_barrage"), 1))
  eq(plain.player.res, 0)
  -- Surge sans Charge : injouable, rien gagné
  local z = mcombat({ arcane_concentration = 2 }, nil, { deck = { "arcane_barrage", "arcane_barrage",
    "arcane_barrage", "arcane_barrage", "arcane_barrage" } })
  assert(not Combat.play(z, idx(z, "arcane_barrage"), 1))
  eq(z.player.res or 0, 0)
end)

test("Frost Warding : +1 Absorb aux cartes qui en donnent, une fois par carte", function()
  do
    local c = mcombat({ frost_warding = 1 }, nil, { deck = { "mana_shield", "mana_shield", "mana_shield",
      "mana_shield", "mana_shield" } })
    assert(Combat.play(c, idx(c, "mana_shield")))
    eq(c.player.block, 5 + MT.ward)
    Combat.gainBlock(c, c.player, 3)
    eq(c.player.block, 5 + MT.ward + 3, "Absorb sans carte : rien de plus")
  end
  local plain = mcombat(nil, nil, { deck = { "mana_shield", "mana_shield", "mana_shield", "mana_shield",
    "mana_shield" } })
  assert(Combat.play(plain, idx(plain, "mana_shield")))
  eq(plain.player.block, 5)
end)

test("Winter's Chill : +1 par rang à chaque coup d'Attack sur un ennemi Frozen", function()
  local bolt, shield = ns.Cards.frostbolt, ns.Cards.mana_shield
  for r = 1, 1 do
    local c = mcombat({ winters_chill = r })
    local e = c.enemies[1]
    eq(Combat.calcDamage(c, c.player, e, 6, bolt), 6, "pas Frozen")
    e.st.demoralized = 1
    eq(Combat.calcDamage(c, c.player, e, 6, bolt), 6 + MT.chill * r, "Demoralized, rang " .. r)
    e.st.demoralized = nil; e.st.stunned = 1
    eq(Combat.calcDamage(c, c.player, e, 6, bolt), 6 + MT.chill * r, "Stunned")
    eq(Combat.calcDamage(c, c.player, e, 6, shield), 6, "Skill")
    eq(Combat.calcDamage(c, c.player, e, 6, nil), 6, "coup sans carte")
  end
  -- Frostbolt joué : le coup lui-même ne profite pas du Demoralized qu'il pose
  local c = mcombat({ winters_chill = 1 }, nil, { deck = { "frostbolt", "frostbolt", "frostbolt", "frostbolt",
    "frostbolt" } })
  assert(Combat.play(c, idx(c, "frostbolt"), 1))
  eq(c.enemies[1].hp, 100 - 6)
  assert(Combat.play(c, idx(c, "frostbolt"), 1))
  eq(c.enemies[1].hp, 100 - 6 - (6 + MT.chill))
end)

test("Arcane Mind : plafond de Charges +1 par rang", function()
  eq(Combat.resCap(mcombat(nil)), 4)
  local R = ns.Talents.mage.byId.arcane_mind.ranks
  for r = 1, R do eq(Combat.resCap(mcombat({ arcane_mind = r })), 4 + r * MT.mind, "rang " .. r) end
  local c = mcombat({ arcane_mind = R })
  Combat.gainRes(c, 20); eq(c.player.res, 4 + R * MT.mind)
end)

test("Specialization : Fire (DoT par coup Fire), Frost (Demoralized au premier ennemi), Arcane (+1 par coup à 4 Charges)", function()
  -- Fire : Scorch (Attack Fire) pose DoT 1 ; Frostbolt non
  local fire = mcombat({ specialization = 1 }, "fire", { deck = { "scorch", "scorch", "frostbolt", "frostbolt",
    "frostbolt" } })
  assert(Combat.play(fire, idx(fire, "scorch"), 1))
  eq(fire.enemies[1].st.pain, MT.fireDot)
  local f2 = mcombat({ specialization = 1 }, "fire", { deck = { "frostbolt", "frostbolt", "frostbolt",
    "frostbolt", "frostbolt" } })
  assert(Combat.play(f2, idx(f2, "frostbolt"), 1))
  eq(f2.enemies[1].st.pain, nil, "Frost : pas de DoT")
  -- Frost : Demoralized 1 sur chaque ennemi au début du combat
  local frost = mcombat({ specialization = 1 }, "frost", { encounter = { "tmt_dummy", "tmt_dummy" } })
  eq(frost.enemies[1].st.demoralized, MT.frostChill); assert(Combat.isFrozen(frost.enemies[1]))
  eq(frost.enemies[2].st.demoralized, nil, "le premier ennemi seulement")
  eq(mcombat(nil).enemies[1].st.demoralized, nil)
  -- Arcane : à 4 Charges, +1 par coup d'Attack (en plus des Charges)
  local arc = mcombat({ specialization = 1 }, "arcane")
  local bolt = ns.Cards.frostbolt
  arc.player.res = MT.arcaneAt - 1
  eq(Combat.calcDamage(arc, arc.player, arc.enemies[1], 6, bolt), 6 + MT.arcaneAt - 1)
  arc.player.res = MT.arcaneAt
  eq(Combat.calcDamage(arc, arc.player, arc.enemies[1], 6, bolt), 6 + MT.arcaneAt + MT.arcaneBonus)
  eq(Combat.calcDamage(arc, arc.player, arc.enemies[1], 6, ns.Cards.mana_shield), 6, "Skill")
end)

test("Prismatic Cloak : Absorb à chaque carte Cast résolue (incantée ou partie tout de suite)", function()
  -- sous Instant : la Fireball part tout de suite
  local i = mcombat({ prismatic_cloak = 1 }, nil, { deck = { "fireball", "fireball", "fireball", "fireball",
    "fireball" } })
  Combat.applyStatus(i, i.player, "instant", 1)
  assert(Combat.play(i, idx(i, "fireball"), 1))
  eq(i.player.block, MT.cloak, "Instant")
  -- incantée : l'Absorb vient à la résolution, au début du tour suivant
  local c = mcombat({ prismatic_cloak = 2 }, nil, { deck = { "fireball", "fireball", "fireball", "fireball",
    "fireball", "fireball", "fireball", "fireball", "fireball", "fireball" } })
  assert(Combat.play(c, idx(c, "fireball"), 1))
  eq(c.player.block, 0)
  local part = Talent.part("mage", c.talents[1])
  eq(part.bot.value(c, c.talents[1], { hp = 10 }), MT.cloak * 10 * 0.5, "bots : incantation tenue")
  nextTurn(c)
  eq(c.player.block, 2 * MT.cloak, "résolue au début du tour, rang 2")
  -- une carte qui n'est pas Cast : rien
  local m = mcombat({ prismatic_cloak = 1 }, nil, { deck = { "frostbolt", "frostbolt", "frostbolt", "frostbolt",
    "frostbolt" } })
  assert(Combat.play(m, idx(m, "frostbolt"), 1))
  eq(m.player.block, 0)
end)

test("Firestarter : Instant 1 au début d'un combat d'élite ou de boss", function()
  eq(mcombat(nil).player.st.instant, nil)
  eq(mcombat({ firestarter = 1 }).player.st.instant, nil, "combat normal : rien")
  local c = mcombat({ firestarter = 1 }, nil, { kind = "boss", deck = { "fireball", "fireball", "fireball",
    "fireball", "fireball" } })
  eq(c.player.st.instant, MT.instant)
  assert(Combat.play(c, idx(c, "fireball"), 1))
  eq(c.enemies[1].hp, 100 - ns.Cards.fireball.effects[1][2], "Fireball partie tout de suite")
  eq(c.player.cast, nil, "aucune incantation tenue")
  eq(c.player.st.instant, MT.instant > 1 and MT.instant - 1 or nil)
end)

test("Arcane Potency : à potencyAt (5) Charges au début du tour, +1 mana (rang 2 : et une carte)", function()
  eq(MT.potencyAt, 5)
  local c = mcombat({ arcane_potency = 1, arcane_mind = 1 })
  c.player.res = MT.potencyAt - 1
  eq(Combat.modify(c, "maxMana", 3), 3)
  c.player.res = MT.potencyAt
  eq(Combat.modify(c, "maxMana", 3), 4); eq(Combat.modify(c, "drawPerTurn", 5), 5)
  local deck = {}
  for i = 1, 14 do deck[i] = "frostbolt" end
  local c2 = mcombat({ arcane_potency = 2, arcane_mind = 1 }, nil, { deck = deck })
  c2.player.res = MT.potencyAt
  nextTurn(c2)
  eq(c2.player.mana, 4); eq(#c2.hand, 6)
  local p = Talent.part("mage", c2.talents[#c2.talents])
  eq(p.bot.value(c2, c2.talents[#c2.talents], {}), 40)
  c2.player.res = 0
  eq(p.bot.value(c2, c2.talents[#c2.talents], {}), 0)
end)

test("Cauterize : une fois par expédition, 1 / 3 / 5 PV selon le rang, sans Ice Block, gardé d'un combat à l'autre", function()
  for r = 1, 3 do
    local c = mcombat({ cauterize = r }, nil, { encounter = { "tmt_hitter" } })
    c.player.hp = 3
    Combat.dealDamage(c, c.enemies[1], c.player, 50)
    eq(c.result, nil); eq(c.player.hp, MT.saveHp[r], "rang " .. r); eq(c.player.st.ice_block, nil)
    eq(c.tstate.cauterize, true)
    Combat.dealDamage(c, c.enemies[1], c.player, 50)
    eq(c.result, "lost", "une seule fois")
  end
  -- dans l'expédition : l'état revient à l'expédition et suit au combat suivant
  local e = mexp({ cauterize = 1 })
  enter(e, "combat")
  e.combat.player.hp = 2
  Combat.loseHp(e.combat, 10, "test")
  winCombat(e)
  eq(e.talentState.cauterize, true)
  assert(X.act(e, { "leave" }))
  local nx = X.nextNodes(e)[1]
  e.map.nodes[nx].kind = "combat"
  assert(X.act(e, { "path", nx }))
  eq(e.combat.tstate.cauterize, true, "pas une deuxième fois dans l'expédition")
end)

test("Cauterize après Ice Block : le Power (une fois par combat) passe d'abord", function()
  local c = mcombat({ cauterize = 1 })
  local ib = { uid = 999, id = "ice_block", up = false }
  c.player.powers[#c.player.powers + 1] = ib
  c.player.hp = 2
  Combat.loseHp(c, 10, "test")
  eq(c.player.hp, 10, "Ice Block : soin 10"); eq(c.tstate.cauterize, nil)
  c.player.hp = 2
  Combat.loseHp(c, 10, "test")
  eq(c.tstate.cauterize, true); eq(c.result, nil)
end)

---------------------------------------------------------------------------
-- Simulation
---------------------------------------------------------------------------
test("simulation : arbre plein du Mage, même graine = mêmes décisions", function()
  local map, spec = Talent.fromShare("mage", 100)
  local function run()
    return ns.SimExpedition.play({ seed = 12, bot = "human", class = "mage", zones = 3, level = 7, key = 0,
      talents = map, spec = spec, maxZone = "duskwood" })
  end
  local a, ea = run()
  local b = run()
  eq(a.zones[1].maxHp, MHP + 3 * MT.hp)
  eq(#a.combats, #b.combats); eq(a.hp, b.hp)
  eq(ea.talents[1].id, "toughness")
  local taken = 0
  for _ in pairs(ea.epicTaken or {}) do taken = taken + 1 end
  assert(taken >= 1, "Veteran's Arsenal 2 : une épique au départ (" .. taken .. ")")
end)

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
