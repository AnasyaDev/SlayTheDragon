-- Tests de l'arbre de talents du Priest (Data/Talents/priest.lua ; docs/talents.md, § 8) : forme de l'arbre,
-- un test par nœud, ordre du bot, simulation (tree=). Modèle : partie Warrior de Sim/tests_talents.lua.
-- Usage : lua5.1 Sim/tests_talents_priest.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
if jit and jit.opt then pcall(jit.opt.start, "maxtrace=65535", "maxmcode=262144") end
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Meta, Combat, Talent, U = ns.Expedition, ns.Meta, ns.Combat, ns.Talent, ns.Util
local PT = ns.PriestTalents
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

ns.Enemies.tp_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }

local function entries(map, spec) return Talent.entries("priest", map, spec) end

-- Combat du Priest avec ces talents (deck d'une seule carte par défaut : Smite), mannequin, sans bibelot.
local function pcombat(map, spec, o)
  o = o or {}
  local deck = {}
  for _, id in ipairs(o.deck or { "smite", "smite", "smite", "smite", "smite", "smite", "smite" }) do
    deck[#deck + 1] = { id = id, up = false }
  end
  local ts = map and entries(map, spec) or nil
  return Combat.new({ seed = o.seed or 5, class = "priest", hp = o.hp or 60, maxHp = 60, deck = deck,
    encounter = { "tp_dummy" }, relics = o.relics, talents = ts and U.copy(ts) or nil,
    tstate = ts and (o.tstate or {}) or nil, quiet = true })
end

local function pexp(map, spec, o)
  o = o or {}
  local unlocks = Meta.allUnlocked(o.level or 1, o.zones or 0)
  unlocks.talents, unlocks.spec = map, spec
  return X.new({ seed = o.seed or 11, class = "priest", unlocks = unlocks, quiet = true })
end

local function enter(exp)
  if exp.phase == "start" then assert(X.act(exp, { "skipStartRelic" })) end
  local id = exp.map.start[1]
  exp.map.nodes[id].kind = "combat"
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
local function play(c, id) assert(Combat.play(c, assert(idx(c, id), id .. " en main"), 1)) end
-- Tour suivant (fin du tour, tour ennemi, fin du round, début du tour : incantation résolue).
local function nextTurn(c)
  Combat.endPlayerTurn(c)
  Combat.enemyPhase(c); Combat.endRound(c)
  Combat.startPlayerTurn(c)
end

---------------------------------------------------------------------------
-- Forme de l'arbre
---------------------------------------------------------------------------
test("arbre du Priest : 14 nœuds, 24 points, 4 rangées, un Specialization, ordre du bot légal", function()
  local errs = Talent.check("priest")
  assert(#errs == 0, table.concat(errs, " ; "))
  local t = ns.Talents.priest
  eq(#t.nodes, 14)
  local rows = { 0, 0, 0, 0 }
  for _, n in ipairs(t.nodes) do rows[n.row] = rows[n.row] + n.ranks end
  eq(rows[1], 7); eq(rows[2], 5); eq(rows[3], 6); eq(rows[4], 6)
  eq(t.rows[1], 0); eq(t.rows[2], 5); eq(t.rows[3], 10); eq(t.rows[4], 16)
  for _, id in ipairs({ "toughness", "provisions", "field_medic", "veterans_arsenal" }) do assert(t.byId[id], id) end
  eq(t.byId.toughness.row, 1); eq(t.byId.provisions.row, 2); eq(t.byId.field_medic.row, 3)
  eq(t.byId.veterans_arsenal.row, 4)
  eq(t.byId.toughness.text[3], ("+%d max HP."):format(3 * PT.hp))
  eq(t.byId.twin_disciplines.text[1], ("Atonement heals %d instead of %d."):format(Combat.ATONEMENT_HEAL + PT.twin,
    Combat.ATONEMENT_HEAL))
  eq(#t.byId.specialization.choices, 3)
  for _, ch in ipairs({ "discipline", "shadow", "holy" }) do assert(t.byId.specialization.byChoice[ch], ch) end
  -- nœud « une fois par expédition » en rangée 4
  eq(t.byId.guardian_spirit.row, 4)
  assert(t.byId.guardian_spirit.text[1]:find("^Once per expedition"))
  -- textes : anglais simple, une phrase qui finit par un point, une ligne
  for _, n in ipairs(t.nodes) do
    local list = n.choices and {} or n.text
    for _, ch in ipairs(n.choices or {}) do list[#list + 1] = ch.text end
    for _, s in ipairs(list) do
      assert(s:find("%.$") and not s:find("[éèàç\n]"), n.id .. " : " .. s)
    end
    assert(n.icon and n.icon ~= "", n.id .. " : icône")
  end
end)

test("icônes des nœuds présentes dans Media/Icons", function()
  local function exists(name)
    local f = io.open(root .. "/Media/Icons/" .. name .. ".tga", "rb")
    if f then f:close() return true end
    return false
  end
  for _, n in ipairs(ns.Talents.priest.nodes) do
    assert(exists(n.icon), n.id .. " : " .. n.icon)
    for _, ch in ipairs(n.choices or {}) do assert(exists(ch.icon), ch.id .. " : " .. ch.icon) end
  end
end)

test("tree= : paliers 20 / 60 % de l'ordre du bot", function()
  local m20 = Talent.fromShare("priest", 20)
  eq(Talent.spentIn(m20), 5)
  local map, spec, n = Talent.fromShare("priest", 60)
  eq(n, 15); eq(Talent.spentIn(map), 15); eq(spec, ns.Talents.priest.bot.spec)
  eq(map.specialization, 1, "Specialization dans le palier 60 %")
  for id in pairs(map) do
    local node = Talent.node("priest", id)
    assert(node.row <= 3, "rangée 4 au palier 60 % : " .. id)
  end
  eq(Talent.spentIn((Talent.fromShare("priest", 100))), 24)
  for _, sp in ipairs({ "discipline", "shadow", "holy" }) do
    eq(select(2, Talent.fromShare("priest", 100, sp)), sp)
  end
end)

---------------------------------------------------------------------------
-- Génériques au Priest
---------------------------------------------------------------------------
test("Toughness et Provisions : PV max et or de départ du Priest", function()
  local e = pexp({ toughness = 3, provisions = 1 })
  eq(e.maxHp, PHP + 3 * PT.hp); eq(e.hp, e.maxHp); eq(e.gold, X.START_GOLD + 100)
end)

---------------------------------------------------------------------------
-- Nœuds du Priest
---------------------------------------------------------------------------
test("Borrowed Time : Atonement au début du combat (s'ajoute à Sacred Candle)", function()
  for r = 1, 2 do
    eq(pcombat({ borrowed_time = r }).player.st.atonement, PT.borrowed * r, "rang " .. r)
    eq(pcombat({ borrowed_time = r }, nil, { relics = { "sacred_candle" } }).player.st.atonement,
      1 + PT.borrowed * r, "rang " .. r .. " + Sacred Candle")
  end
  eq(pcombat(nil).player.st.atonement, nil)
  -- posée au début du combat, comme celle de Sacred Candle : le premier round ne décompte pas, puis 1 par round
  local c = pcombat({ borrowed_time = 2 }, nil, { relics = { "sacred_candle" } })
  nextTurn(c)
  eq(c.player.st.atonement, 1 + 2 * PT.borrowed, "premier round : pas de baisse")
  nextTurn(c)
  eq(c.player.st.atonement, 2 * PT.borrowed, "un tour de moins")
end)

test("Mind Spike : Insanity au début du combat", function()
  eq(pcombat({ mind_spike = 1 }).player.res, PT.spike)
  eq(pcombat({ mind_spike = 2 }).player.res, 2 * PT.spike)
  eq(pcombat(nil).player.res or 0, 0)
end)

test("Twin Disciplines : le soin d'Atonement monte de 1 par rang (constante lue sur le combat)", function()
  for r = 0, 2 do
    local c = pcombat(r > 0 and { twin_disciplines = r } or nil, nil, { hp = 20 })
    eq(Combat.const(c, "ATONEMENT_HEAL", Combat.ATONEMENT_HEAL), Combat.ATONEMENT_HEAL + PT.twin * r)
    c.player.st.atonement = 2
    play(c, "smite")
    eq(c.player.hp, 20 + Combat.ATONEMENT_HEAL + PT.twin * r, "rang " .. r)
  end
  eq(Combat.ATONEMENT_HEAL, 2, "module intact")
  -- sans Atonement : aucun soin
  local c = pcombat({ twin_disciplines = 2 }, nil, { hp = 20 })
  play(c, "smite"); eq(c.player.hp, 20)
end)

test("Shadow Weaving : la deuxième carte Shadow du tour donne 1 Insanity de plus", function()
  local deck = { "sw_pain", "sw_pain", "sw_pain", "sw_pain", "sw_pain", "sw_pain" }
  local c = pcombat({ shadow_weaving = 1 }, nil, { deck = deck })
  play(c, "sw_pain"); eq(c.player.res, 1)
  play(c, "sw_pain"); eq(c.player.res, 2 + PT.weaving, "deuxième")
  play(c, "sw_pain"); eq(c.player.res, 3 + PT.weaving, "troisième : rien de plus")
  nextTurn(c)
  local r = c.player.res
  play(c, "sw_pain"); play(c, "sw_pain"); eq(c.player.res, r + 2 + PT.weaving, "chaque tour")
  local h = pcombat({ shadow_weaving = 1 }, nil, { deck = { "smite", "smite", "smite", "smite", "smite" } })
  play(h, "smite"); play(h, "smite"); eq(h.player.res or 0, 0, "cartes Holy : rien")
end)

test("Inspiration : Regen au début du combat (Benediction s'y ajoute)", function()
  -- premier tic au début du premier tour (déjà passé à la fin de Combat.new)
  local c = pcombat({ inspiration = 1 }, nil, { hp = 30 })
  eq(c.player.hp, 30 + PT.inspiration); eq(c.player.st.regen, PT.inspiration - 1)
  local b = pcombat({ inspiration = 1 }, nil, { hp = 30, relics = { "benediction" } })
  eq(b.player.hp, 30 + PT.inspiration + 1, "Benediction +1"); eq(b.player.st.regen, PT.inspiration)
  local p = pcombat(nil, nil, { hp = 30 })
  eq(p.player.hp, 30); eq(p.player.st.regen, nil)
end)

test("Specialization Discipline : chaque soin d'Atonement donne 2 Absorb (sans Power Word: Barrier)", function()
  local c = pcombat({ specialization = 1 }, "discipline")
  c.player.st.atonement = 2
  play(c, "smite"); eq(c.player.block, PT.discAbsorb)
  play(c, "smite"); eq(c.player.block, 2 * PT.discAbsorb)
  local n = pcombat({ specialization = 1 }, "discipline")
  play(n, "smite"); eq(n.player.block, 0, "sans Atonement")
  local s = pcombat({ specialization = 1 }, "discipline", { deck = { "inner_fire", "inner_fire", "inner_fire",
    "inner_fire", "inner_fire" } })
  s.player.st.atonement = 2
  play(s, "inner_fire"); eq(s.player.block, 6, "carte sans dégâts : pas de soin d'Atonement")
  local b = pcombat({ specialization = 1, power_word_barrier = 2 }, "discipline")
  b.player.st.atonement = 2
  play(b, "smite"); eq(b.player.block, PT.discAbsorb, "Power Word: Barrier ne s'y ajoute pas")
end)

test("Specialization Shadow : les cartes Shadow frappent plus fort et posent plus de DoT", function()
  local c = pcombat({ specialization = 1 }, "shadow", { deck = { "sw_pain", "sw_pain", "sw_pain", "sw_pain",
    "sw_pain" } })
  play(c, "sw_pain"); eq(c.enemies[1].st.pain, 5 + PT.shadowDot)
  Combat.applyStatus(c, c.enemies[1], "pain", 2)
  eq(c.enemies[1].st.pain, 7 + PT.shadowDot, "DoT sans carte : rien de plus")
  local e = c.enemies[1]
  eq(Combat.calcDamage(c, c.player, e, 10, ns.Cards.mind_blast), 10 + PT.shadowHit)
  eq(Combat.calcDamage(c, c.player, e, 8, ns.Cards.smite), 8, "carte Holy")
  eq(Combat.calcDamage(c, c.player, e, 8, nil), 8, "coup sans carte")
  local d = pcombat({ specialization = 1 }, "discipline", { deck = { "sw_pain", "sw_pain", "sw_pain", "sw_pain",
    "sw_pain" } })
  play(d, "sw_pain"); eq(d.enemies[1].st.pain, 5, "autre voie")
end)

test("Specialization Holy : les cartes Holy frappent plus fort", function()
  local c = pcombat({ specialization = 1 }, "holy")
  local e = c.enemies[1]
  eq(Combat.calcDamage(c, c.player, e, 8, ns.Cards.smite), 8 + PT.holyHit)
  eq(Combat.calcDamage(c, c.player, e, 10, ns.Cards.mind_blast), 10, "carte Shadow")
  eq(Combat.calcDamage(c, c.player, e, 8, nil), 8, "coup sans carte")
  play(c, "smite"); eq(e.hp, 100 - 8 - PT.holyHit)
end)

test("Void Torrent : les Surge comptent 1 Insanity de plus par rang (la dépense ne change pas)", function()
  local deck = { "devouring_plague", "devouring_plague", "devouring_plague", "devouring_plague", "devouring_plague" }
  for r = 0, 2 do
    local c = pcombat(r > 0 and { void_torrent = r } or nil, nil, { deck = deck })
    c.player.res = 3
    play(c, "devouring_plague")
    eq(c.enemies[1].st.pain, 2 * (3 + PT.torrent * r), "rang " .. r)
    eq(c.player.res, 0)
  end
end)

test("Power Word: Barrier : les cartes qui donnent de l'Absorb en donnent 1 de plus par rang", function()
  local deck = { "inner_fire", "inner_fire", "inner_fire", "inner_fire", "inner_fire" }
  for r = 1, 2 do
    local c = pcombat({ power_word_barrier = r }, nil, { deck = deck })
    play(c, "inner_fire"); eq(c.player.block, 6 + PT.barrier * r, "rang " .. r)
    Combat.gainBlock(c, c.player, 3)
    eq(c.player.block, 9 + PT.barrier * r, "Absorb sans carte : rien de plus")
  end
end)

test("Spiritual Guidance : Absorb quand une carte Cast se résout", function()
  local deck = { "greater_heal", "greater_heal", "greater_heal", "greater_heal", "greater_heal" }
  for r = 1, 2 do
    local c = pcombat({ spiritual_guidance = r }, nil, { deck = deck, hp = 30 })
    play(c, "greater_heal")
    eq(c.player.block, 0)
    nextTurn(c)
    eq(c.player.block, PT.guidance[r], "rang " .. r)
  end
end)

test("Guardian Spirit : une fois par expédition, 1 PV et Atonement 3 (rang 2 : et Regen 6)", function()
  local c = pcombat({ guardian_spirit = 2 })
  c.player.hp = 3
  Combat.dealDamage(c, c.enemies[1], c.player, 50)
  eq(c.result, nil); eq(c.player.hp, 1)
  eq(c.player.st.atonement, PT.guardAtone); eq(c.player.st.regen, PT.guardRegen)
  eq(c.tstate.guardian, true)
  Combat.dealDamage(c, c.enemies[1], c.player, 50)
  eq(c.result, "lost", "une seule fois")
  local c1 = pcombat({ guardian_spirit = 1 })
  c1.player.hp = 2
  Combat.loseHp(c1, 10, "test")
  eq(c1.player.hp, 1); eq(c1.player.st.regen, nil)
  -- dans l'expédition : l'état revient à l'expédition et suit au combat suivant
  local e = pexp({ guardian_spirit = 1 })
  enter(e)
  e.combat.player.hp = 2
  Combat.loseHp(e.combat, 10, "test")
  winCombat(e)
  eq(e.talentState.guardian, true)
  assert(X.act(e, { "leave" }))
  local nx = X.nextNodes(e)[1]
  e.map.nodes[nx].kind = "combat"
  assert(X.act(e, { "path", nx }))
  eq(e.combat.tstate.guardian, true, "pas une deuxième fois dans l'expédition")
end)

---------------------------------------------------------------------------
-- Simulation
---------------------------------------------------------------------------
test("simulation : arbre plein du Priest, épiques au départ, même graine = mêmes décisions", function()
  local map, spec = Talent.fromShare("priest", 100)
  local function run()
    return ns.SimExpedition.play({ seed = 12, bot = "human", class = "priest", zones = 3, level = 7, key = 0,
      talents = map, spec = spec, maxZone = "westfall" })
  end
  local a, ea = run()
  local b = run()
  eq(a.zones[1].maxHp, PHP + 3 * PT.hp)
  local taken = 0
  for _ in pairs(ea.epicTaken or {}) do taken = taken + 1 end
  assert(taken >= 2, "Veteran's Arsenal 2 : deux épiques au départ (" .. taken .. ")")
  local function ser(t) local o = {} for i, v in ipairs(t) do o[i] = tostring(v.id or v) end return table.concat(o, ",") end
  eq(ser(a.picks or {}), ser(b.picks or {})); eq(a.hp, b.hp); eq(#a.combats, #b.combats)
  eq(ea.talents[1].id, "toughness")
end)

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
