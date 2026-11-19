-- Tests de l'arbre de talents du Druid (Data/Talents/druid.lua ; docs/talents.md, § 7) : forme de l'arbre, ordre
-- du bot, un test par nœud, constantes de classe lues sur l'état du combat (module intact), simulation (tree=).
-- Modèle : partie Warrior de Sim/tests_talents.lua.
-- Usage : lua5.1 Sim/tests_talents_druid.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
if jit and jit.opt then pcall(jit.opt.start, "maxtrace=65535", "maxmcode=262144") end
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Meta, Combat, Talent, U = ns.Expedition, ns.Meta, ns.Combat, ns.Talent, ns.Util
local D, DT = ns.Druid, ns.DruidTalents
local DHP = ns.Classes.druid.hp

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

ns.Enemies.tdt_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }

local function entries(map, spec) return Talent.entries("druid", map, spec) end

-- Combat du Druid avec ces talents (mannequin, sans bibelot) ; o.deck : ids de cartes.
local function dcombat(map, spec, o)
  o = o or {}
  local deck = {}
  for _, id in ipairs(o.deck or { "wrath", "wrath", "thick_hide", "thick_hide", "maul", "wrath", "thick_hide" }) do
    deck[#deck + 1] = { id = id, up = false }
  end
  local ts = map and entries(map, spec) or nil
  return Combat.new({ seed = o.seed or 5, class = "druid", hp = o.hp or 50, maxHp = 50, deck = deck,
    encounter = o.encounter or { "tdt_dummy" }, relics = o.relics, talents = ts and U.copy(ts) or nil,
    tstate = ts and (o.tstate or {}) or nil, quiet = true })
end

local function dexp(map, spec, o)
  o = o or {}
  local unlocks = Meta.allUnlocked(o.level or 1, o.zones or 0)
  unlocks.talents, unlocks.spec = map, spec
  return X.new({ seed = o.seed or 11, class = "druid", unlocks = unlocks, quiet = true })
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

local function node(id) return ns.Talents.druid.byId[id] end

---------------------------------------------------------------------------
-- Forme de l'arbre
---------------------------------------------------------------------------
test("arbre du Druid : 14 nœuds, 24 points, 4 rangées, un Specialization, ordre du bot légal", function()
  local errs = Talent.check("druid")
  assert(#errs == 0, table.concat(errs, " ; "))
  local t = ns.Talents.druid
  eq(#t.nodes, 14)
  local rows = { 0, 0, 0, 0 }
  for _, n in ipairs(t.nodes) do rows[n.row] = rows[n.row] + n.ranks end
  eq(rows[1], 6); eq(rows[2], 6); eq(rows[3], 6); eq(rows[4], 6)
  eq(t.rows[1], 0); eq(t.rows[2], 5); eq(t.rows[3], 10); eq(t.rows[4], 16)
  for _, id in ipairs({ "toughness", "provisions", "field_medic", "veterans_arsenal" }) do assert(t.byId[id], id) end
  eq(t.byId.toughness.row, 1); eq(t.byId.provisions.row, 2); eq(t.byId.field_medic.row, 3)
  eq(t.byId.veterans_arsenal.row, 4); eq(t.byId.survival_instincts.row, 4)
  -- textes : anglais simple, une phrase qui finit par un point ; icônes présentes dans Media/Icons
  local icons = {}
  for _, n in ipairs(t.nodes) do
    local list = {}
    for _, s in ipairs(n.text or {}) do list[#list + 1] = s end
    icons[#icons + 1] = n.icon
    for _, ch in ipairs(n.choices or {}) do list[#list + 1] = ch.text; icons[#icons + 1] = ch.icon end
    for _, s in ipairs(list) do
      assert(s:find("%.$") and not s:find("[éèàç]") and not s:find("\n"), n.id .. " : " .. s)
    end
  end
  for _, ic in ipairs(icons) do
    local f = io.open(root .. "/Media/Icons/" .. ic .. ".tga", "rb")
    assert(f, "icône absente : " .. tostring(ic))
    f:close()
  end
  eq(t.byId.toughness.text[3], ("+%d max HP."):format(3 * DT.hp))
  eq(t.byId.specialization.byChoice.balance.text,
    ("End of turn in Moonkin: deal %d more to each enemy."):format(DT.pulse))
  eq(#t.byId.specialization.choices, 3)
end)

test("tree= : paliers 40, 60 et 80 % dans l'ordre du bot, voie du bot", function()
  local map, spec, n = Talent.fromShare("druid", 60)
  eq(n, 15); eq(spec, ns.Talents.druid.bot.spec)
  local want = { natural_shapeshifter = 2, toughness = 3, primal_instinct = 1, moonglow = 2, living_seed = 2,
    provisions = 1, specialization = 1, wild_reserve = 2, field_medic = 1 }
  local m40 = Talent.fromShare("druid", 40)
  eq(m40.provisions, nil, "palier 40 % : Provisions pas encore pris")
  local m80 = Talent.fromShare("druid", 80)
  eq(m80.shapeshifters_ward, 2, "palier 80 % : Shapeshifter's Ward"); eq(m80.feral_instinct, 1)
  eq(m80.master_shapeshifter, 1); eq(m80.veterans_arsenal, 1)
  for id, r in pairs(want) do eq(map[id], r, id) end
  for id in pairs(map) do assert(want[id], "en trop : " .. id) end
  eq(Talent.spentIn((Talent.fromShare("druid", 100, "balance"))), 24)
  eq(select(2, Talent.fromShare("druid", 100, "restoration")), "restoration")
end)

---------------------------------------------------------------------------
-- Génériques (nombres du Druid)
---------------------------------------------------------------------------
test("Toughness, Provisions, Field Medic, Veteran's Arsenal : PV, or, passage de zone, épique au départ", function()
  local e = dexp({ toughness = 3, provisions = 1 })
  eq(e.maxHp, DHP + 3 * DT.hp); eq(e.hp, e.maxHp); eq(e.gold, X.START_GOLD + 100)
  local fm = dexp({ field_medic = 1 })
  fm.hp = 1
  X.enterZone(fm, "duskwood")
  eq(fm.transit.healed, math.floor(fm.maxHp * 0.75))
  local va = dexp({ veterans_arsenal = 1 }, nil, { zones = 2 })
  eq(va.phase, "start"); eq(va.talentEpicsLeft, 1)
  for _, id in ipairs(va.talentEpics) do eq(ns.Cards[id].class, "druid", id) end
end)

---------------------------------------------------------------------------
-- Nœuds du Druid
---------------------------------------------------------------------------
test("Primal Instinct : +1 réserve au début du combat", function()
  eq(dcombat(nil).player.res, 0)
  eq(dcombat({ primal_instinct = 1 }).player.res, DT.primal)
  eq(node("primal_instinct").ranks, 1)
  eq(node("primal_instinct").text[1], ("Start of combat: +%d Reserve."):format(DT.primal))
end)

test("Natural Shapeshifter : taxe de 1 mana au plus, puis l'entrée dans la première forme hors taxe ; module intact", function()
  local plain = dcombat(nil)
  eq(D.taxOf(2, plain), 1); eq(D.taxOf(3, plain), 2); eq(D.taxOf(4, plain), 2)
  local c1 = dcombat({ natural_shapeshifter = 1 })
  eq(D.taxOf(2, c1), 1); eq(D.taxOf(3, c1), DT.taxMax); eq(D.taxOf(5, c1), DT.taxMax)
  eq(D.TAX_FREE, 1); eq(D.TAX_MAX, 2); eq(D.TAX, 1)
  -- en combat : sans forme, Moonkin, Bear, Moonkin (trois changements comptés ; rang 2 : deux)
  for _, case in ipairs({ { nil, 3, 2 }, { { natural_shapeshifter = 1 }, 3, 1 }, { { natural_shapeshifter = 2 }, 2, 1 } }) do
    local c = dcombat(case[1], nil, { deck = { "wrath", "thick_hide", "wrath", "thick_hide", "wrath" } })
    c.player.mana = 9
    assert(Combat.play(c, idx(c, "wrath"), 1)); assert(Combat.play(c, idx(c, "thick_hide")))
    assert(Combat.play(c, idx(c, "wrath"), 1))
    eq(c.cls.taxed, case[2], "changements comptés")
    Combat.endPlayerTurn(c)
    eq(c.cls.tax, case[3], "taxe posée")
  end
  -- rang 2 : sans forme, Moonkin, Bear = aucune taxe (un seul changement compté)
  local c = dcombat({ natural_shapeshifter = 2 }, nil, { deck = { "wrath", "thick_hide", "wrath", "thick_hide", "wrath" } })
  assert(Combat.play(c, idx(c, "wrath"), 1)); assert(Combat.play(c, idx(c, "thick_hide")))
  Combat.endPlayerTurn(c)
  eq(c.cls.tax, 0)
end)

test("Feral Instinct : frappe de l'ours +1 (STRIKE_BASE lu sur le combat)", function()
  for r = 0, 1 do
    local c = dcombat(r > 0 and { feral_instinct = r } or nil)
    eq(D.strikeBase(c), D.STRIKE_BASE + r * DT.strike)
    c.cls.form, c.player.res = "bear", 2
    local hp = c.enemies[1].hp
    Combat.endPlayerTurn(c)
    eq(hp - c.enemies[1].hp, D.STRIKE_BASE + r * DT.strike + 2, "frappe de fin de tour, rang " .. r)
  end
  eq(D.STRIKE_BASE, 1, "module intact")
end)

test("Moonglow : Absorb (2 par rang) à la fin d'un tour fini en Moonkin, rien dans une autre forme", function()
  for r = 1, 2 do
    for _, f in ipairs({ "moonkin", "cat", "tree" }) do
      local c = dcombat({ moonglow = r })
      local ref = dcombat(nil)
      c.cls.form, ref.cls.form = f, f
      Combat.endPlayerTurn(c); Combat.endPlayerTurn(ref)
      eq(c.player.block - ref.player.block, f == "moonkin" and DT.moonglow * r or 0, f .. " rang " .. r)
    end
  end
end)

test("Living Seed : fin de tour en Tree of Life, Absorb de TREE_ABSORB + 2 par rang", function()
  for r = 1, 2 do
    local c = dcombat({ living_seed = r })
    c.cls.form = "tree"
    Combat.endPlayerTurn(c)
    eq(c.player.block, D.TREE_ABSORB + DT.seed * r)
  end
  local m = dcombat({ living_seed = 2 })
  m.cls.form = "moonkin"
  Combat.endPlayerTurn(m)
  eq(m.player.block, 0)
  eq(D.TREE_ABSORB, 2, "module intact")
end)

test("Specialization : Feral (+1 Combo à la pose de Clearcasting), Balance (+1 au coup à tous), Restoration (Regen +1)", function()
  -- Feral : Clearcasting posé en Cat -> +1 ; déjà posé : rien de plus
  local f = dcombat({ specialization = 1 }, "feral")
  f.cls.form, f.player.res = "cat", 2
  Combat.endPlayerTurn(f)
  assert((f.player.st.clearcasting or 0) > 0)
  eq(f.player.res, 2 + DT.combo)
  Combat.endPlayerTurn(f)
  eq(f.player.res, 2 + DT.combo, "Clearcasting déjà posé : pas de Combo")
  local nf = dcombat(nil)
  nf.cls.form, nf.player.res = "cat", 2
  Combat.endPlayerTurn(nf)
  eq(nf.player.res, 2)
  -- Balance : coup à tous de fin de tour en Moonkin + 1, même à 0 Charge
  for _, res in ipairs({ 0, 3, 5 }) do
    local b = dcombat({ specialization = 1 }, "balance")
    b.cls.form, b.player.res = "moonkin", res
    local hp = b.enemies[1].hp
    Combat.endPlayerTurn(b)
    eq(hp - b.enemies[1].hp, math.min(D.PULSE_MAX, math.ceil(res / 2)) + DT.pulse, res .. " Charges")
  end
  eq(D.PULSE_BONUS, 0, "module intact")
  local nb = dcombat(nil)
  nb.cls.form, nb.player.res = "moonkin", 0
  local hp0 = nb.enemies[1].hp
  Combat.endPlayerTurn(nb)
  eq(nb.enemies[1].hp, hp0, "sans talent : aucun coup à 0 Charge")
  -- Restoration : chaque Regen gagnée +1 (pas un autre état)
  local r = dcombat({ specialization = 1 }, "restoration")
  Combat.applyStatus(r, r.player, "regen", 3)
  eq(r.player.st.regen, 3 + DT.regen)
  local nr = dcombat(nil)
  Combat.applyStatus(nr, nr.player, "regen", 3)
  eq(nr.player.st.regen, 3)
end)

test("Wild Reserve : plafond de la réserve +1 par rang", function()
  eq(Combat.resCap(dcombat(nil)), 5)
  eq(Combat.resCap(dcombat({ wild_reserve = 1 })), 5 + DT.cap)
  local c = dcombat({ wild_reserve = 2 })
  eq(Combat.resCap(c), 5 + 2 * DT.cap)
  Combat.gainRes(c, 9); eq(c.player.res, 5 + 2 * DT.cap)
end)

test("Shapeshifter's Ward : Absorb au premier changement de forme de chaque tour, pas aux suivants", function()
  for r = 1, 2 do
    local c = dcombat({ shapeshifters_ward = r }, nil, { deck = { "wrath", "wrath", "thick_hide", "ferocious_bite",
      "thick_hide" } })
    c.player.mana = 9
    assert(Combat.play(c, idx(c, "wrath"), 1)); eq(c.player.block, DT.ward[r], "entrée en Moonkin")
    assert(Combat.play(c, idx(c, "wrath"), 1)); eq(c.player.block, DT.ward[r], "même forme : rien")
    assert(Combat.play(c, idx(c, "thick_hide"))); eq(c.player.block, DT.ward[r] + 5, "deuxième changement : rien")
    -- tour suivant : Bear -> Cat (hors taxe) est le premier changement du tour
    Combat.endPlayerTurn(c); Combat.enemyPhase(c); Combat.endRound(c); Combat.startPlayerTurn(c)
    c.player.block, c.player.mana, c.player.res = 0, 9, 1
    local i = idx(c, "ferocious_bite")
    if i then
      assert(Combat.play(c, i, 1)); eq(c.player.block, DT.ward[r], "Bear -> Cat, premier du tour")
    end
  end
  eq(node("shapeshifters_ward").text[2], ("The first form change each turn: gain %d Absorb."):format(DT.ward[2]))
end)

test("Master Shapeshifter : un changement compté gratuit de plus ; avec Natural Shapeshifter", function()
  local c1 = dcombat({ master_shapeshifter = 1 })
  eq(Combat.const(c1, "TAX_FREE", D.TAX_FREE), D.TAX_FREE + DT.masterFree)
  eq(D.taxOf(2, c1), 0); eq(D.taxOf(3, c1), 1); eq(Combat.const(c1, "TAX", D.TAX), D.TAX)
  local both = dcombat({ natural_shapeshifter = 1, master_shapeshifter = 1 })
  eq(Combat.const(both, "TAX_FREE", D.TAX_FREE), D.TAX_FREE + DT.masterFree)
  eq(D.taxOf(3, both), 1); eq(D.taxOf(9, both), DT.taxMax)
  eq(node("master_shapeshifter").ranks, 1)
  eq(D.TAX_FREE, 1, "module intact")
end)

test("Survival Instincts : une fois par expédition, 1 PV en Bear (rangs 2 et 3 : 10 et 20 Absorb), gardé d'un combat à l'autre", function()
  local c3 = dcombat({ survival_instincts = 3 })
  c3.player.hp = 1
  Combat.loseHp(c3, 10, "test")
  eq(c3.player.hp, 1); eq(c3.player.block, 2 * DT.saveAbsorb)
  local c = dcombat({ survival_instincts = 2 })
  c.cls.form = "moonkin"
  c.player.hp = 3
  Combat.dealDamage(c, c.enemies[1], c.player, 50)
  eq(c.result, nil); eq(c.player.hp, 1); eq(c.cls.form, "bear"); eq(c.player.block, DT.saveAbsorb)
  eq(c.tstate.survival, true)
  c.player.block = 0
  Combat.dealDamage(c, c.enemies[1], c.player, 50)
  eq(c.result, "lost", "une seule fois")
  local c1 = dcombat({ survival_instincts = 1 })
  c1.player.hp = 2
  Combat.loseHp(c1, 10, "test")
  eq(c1.player.hp, 1); eq(c1.player.block, 0); eq(c1.cls.form, "bear")
  -- dans l'expédition : l'état revient à l'expédition et suit au combat suivant
  local e = dexp({ survival_instincts = 1 })
  enter(e, "combat")
  e.combat.player.hp = 2
  Combat.loseHp(e.combat, 10, "test")
  winCombat(e)
  eq(e.talentState.survival, true)
  assert(X.act(e, { "leave" }))
  local nx = X.nextNodes(e)[1]
  e.map.nodes[nx].kind = "combat"
  assert(X.act(e, { "path", nx }))
  eq(e.combat.tstate.survival, true, "pas une deuxième fois dans l'expédition")
end)

---------------------------------------------------------------------------
-- Simulation
---------------------------------------------------------------------------
test("simulation : arbre plein du Druid, même graine = mêmes décisions, module intact", function()
  local map, spec = Talent.fromShare("druid", 100)
  local function run()
    return ns.SimExpedition.play({ seed = 12, bot = "human", class = "druid", zones = 3, level = 7, key = 0,
      talents = map, spec = spec, maxZone = "duskwood" })
  end
  local a, ea = run()
  local b = run()
  eq(a.zones[1].maxHp, DHP + 3 * DT.hp)
  eq(a.hp, b.hp); eq(#a.combats, #b.combats)
  eq(ea.talents[1].id, "toughness")
  eq(D.TAX_FREE, 1); eq(D.TAX, 1); eq(D.TAX_MAX, 2); eq(D.STRIKE_BASE, 1); eq(D.TREE_ABSORB, 2)
  eq(D.PULSE_BONUS, 0)
end)

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
