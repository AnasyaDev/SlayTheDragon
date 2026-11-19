-- Tests de l'arbre de talents du Rogue (Data/Talents/rogue.lua ; docs/talents.md, § 8) : forme de l'arbre, ordre
-- du bot, chaque nœud, simulation (tree=). Modèle : partie Warrior de Sim/tests_talents.lua.
-- Usage : lua5.1 Sim/tests_talents_rogue.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
if jit and jit.opt then pcall(jit.opt.start, "maxtrace=65535", "maxmcode=262144") end
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Meta, Combat, Talent, U = ns.Expedition, ns.Meta, ns.Combat, ns.Talent, ns.Util
local RT = ns.RogueTalents
local RHP = ns.Classes.rogue.hp
local Rogue = ns.Rogue

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

ns.Enemies.tr_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.tr_big = { name = "Fracas", hp = 100,
  moves = { smash = { name = "Fracas", intent = "attack", actions = { { "attack", 18 } } } }, pattern = { "smash" } }

local function entries(map, spec) return Talent.entries("rogue", map, spec) end

-- Combat du Rogue avec ces talents (deck donné, mannequin), sans bibelot.
local function rcombat(map, spec, o)
  o = o or {}
  local deck = {}
  for _, id in ipairs(o.deck or { "sinister_strike", "sinister_strike", "feint", "feint", "eviscerate" }) do
    deck[#deck + 1] = { id = id, up = false }
  end
  local ts = map and entries(map, spec) or nil
  return Combat.new({ seed = o.seed or 5, class = "rogue", hp = o.hp or 50, maxHp = 50, deck = deck,
    encounter = o.encounter or { "tr_dummy" }, relics = o.relics, talents = ts and U.copy(ts) or nil,
    tstate = ts and (o.tstate or {}) or nil, quiet = true })
end

local function rexp(map, spec, o)
  o = o or {}
  local unlocks = Meta.allUnlocked(o.level or 1, o.zones or 0)
  unlocks.talents, unlocks.spec = map, spec
  return X.new({ seed = o.seed or 11, class = "rogue", unlocks = unlocks, quiet = true })
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
-- Dégâts d'Eviscerate (non amélioré) pour n Combo dépensés.
local function evisc(n)
  local e = ns.Cards.eviscerate.effects[2]
  return e[2] + e.per[1] * n
end
-- Met une carte id de la pioche en main (échange avec la dernière carte de la main) si elle n'y est pas.
local function toHand(c, id)
  if idx(c, id) then return end
  for i, x in ipairs(c.draw) do
    if x.id == id then
      c.draw[i], c.hand[#c.hand] = c.hand[#c.hand], x
      return
    end
  end
end
local function play(c, id)
  toHand(c, id)
  assert(Combat.play(c, assert(idx(c, id), id), 1))
end

---------------------------------------------------------------------------
-- Forme de l'arbre
---------------------------------------------------------------------------
test("arbre du Rogue : 14 nœuds, 24 points, 4 rangées, un Specialization, ordre du bot légal", function()
  local errs = Talent.check("rogue")
  assert(#errs == 0, table.concat(errs, " ; "))
  local t = ns.Talents.rogue
  eq(#t.nodes, 14)
  local rows = { 0, 0, 0, 0 }
  for _, n in ipairs(t.nodes) do rows[n.row] = rows[n.row] + n.ranks end
  eq(rows[1], 7); eq(rows[2], 5); eq(rows[3], 6); eq(rows[4], 6)
  eq(t.rows[1], 0); eq(t.rows[2], 5); eq(t.rows[3], 10); eq(t.rows[4], 16)
  for _, id in ipairs({ "toughness", "provisions", "field_medic", "veterans_arsenal" }) do assert(t.byId[id], id) end
  eq(t.byId.toughness.row, 1); eq(t.byId.provisions.row, 2); eq(t.byId.field_medic.row, 3)
  eq(t.byId.veterans_arsenal.row, 4); eq(t.byId.cheat_fate.row, 4)
  eq(t.byId.toughness.text[3], ("+%d max HP."):format(3 * RT.hp))
  eq(t.byId.initiative.text[2], ("Start of combat: +%d Combo."):format(2 * RT.initiative))
  eq(t.byId.combat_readiness.text[1], ("Each Parry stops up to %d damage."):format(Rogue.PARRY_STOP + RT.readiness))
  eq(#t.byId.specialization.choices, 3)
  for _, ch in ipairs({ "assassination", "combat", "subtlety" }) do assert(t.byId.specialization.byChoice[ch], ch) end
  -- textes : anglais simple, une phrase qui finit par un point, une ligne
  for _, n in ipairs(t.nodes) do
    local list = {}
    for _, s in ipairs(n.text or {}) do list[#list + 1] = s end
    for _, ch in ipairs(n.choices or {}) do list[#list + 1] = ch.text end
    for _, s in ipairs(list) do
      assert(s:find("%.$") and not s:find("[éèàç\n]"), n.id .. " : " .. s)
    end
  end
  -- icônes présentes
  for _, n in ipairs(t.nodes) do
    local icons = { n.icon }
    for _, ch in ipairs(n.choices or {}) do icons[#icons + 1] = ch.icon end
    for _, ic in ipairs(icons) do
      local f = io.open(root .. "/Media/Icons/" .. ic .. ".tga", "rb")
      assert(f, n.id .. " : icône " .. tostring(ic))
      f:close()
    end
  end
end)

test("tree= : palier 60 % du Rogue dans l'ordre du bot", function()
  local map, spec, n = Talent.fromShare("rogue", 60)
  eq(n, 15); eq(Talent.spentIn(map), 15); eq(spec, ns.Talents.rogue.bot.spec)
  local want = { toughness = 3, initiative = 2, elusiveness = 2, opportunity = 2, lightning_reflexes = 1,
    vile_poisons = 1, provisions = 1, specialization = 1, combat_readiness = 2 }
  for id, r in pairs(want) do eq(map[id], r, id) end
  for id in pairs(map) do assert(want[id], "en trop : " .. id) end
  eq(Talent.spentIn((Talent.fromShare("rogue", 100, "subtlety"))), 24)
  eq(select(2, Talent.fromShare("rogue", 100, "subtlety")), "subtlety")
end)

---------------------------------------------------------------------------
-- Nœuds
---------------------------------------------------------------------------
test("Toughness : +hp PV max par rang au départ", function()
  local e = rexp({ toughness = 3, provisions = 1 })
  eq(e.maxHp, RHP + 3 * RT.hp); eq(e.hp, e.maxHp); eq(e.gold, X.START_GOLD + 100)
end)

test("Initiative : +1 Combo par rang au début du combat (avec Shadowfang)", function()
  eq(rcombat(nil).player.res, 0)
  eq(rcombat({ initiative = 1 }).player.res, RT.initiative)
  eq(rcombat({ initiative = 2 }).player.res, 2 * RT.initiative)
  eq(rcombat({ initiative = 2 }, nil, { relics = { "shadowfang" } }).player.res, 2 + 2 * RT.initiative)
end)

test("Elusiveness : Parry 1 par rang au début du combat, plafond de Parry respecté", function()
  eq(rcombat(nil).player.st.parry, nil)
  eq(rcombat({ elusiveness = 1 }).player.st.parry, RT.elusive)
  eq(rcombat({ elusiveness = 2 }).player.st.parry, 2 * RT.elusive)
  eq(rcombat({ elusiveness = 2 }, nil, { relics = { "blinding_powder" } }).player.st.parry, 3, "plafond 3")
end)

test("Opportunity : les Attacks jouées sous Stealth frappent plus fort, par coup ; ni après, ni les Skills", function()
  local bs = ns.Cards.backstab.effects[1]
  local hidden = bs[2] + bs.more[1][1] -- Backstab sous Stealth
  local ss = ns.Cards.sinister_strike.effects[1][2]
  for r = 0, 2 do
    local c = rcombat(r > 0 and { opportunity = r } or nil, nil, { deck = { "backstab", "sinister_strike" } })
    play(c, "backstab")
    eq(c.enemies[1].hp, 100 - hidden - RT.opportunity * r, "Backstab, rang " .. r)
    play(c, "sinister_strike") -- Stealth consommé : rien de plus
    eq(c.enemies[1].hp, 100 - hidden - RT.opportunity * r - ss, "Sinister Strike, rang " .. r)
  end
  -- deux coups (Mutilate : 3 deux fois) : le bonus vaut pour chaque coup
  local m = rcombat({ opportunity = 2 }, nil, { deck = { "mutilate" } })
  play(m, "mutilate")
  eq(m.enemies[1].hp, 100 - 2 * (ns.Cards.mutilate.effects[1][2] + 2 * RT.opportunity))
  -- coup sans carte et Skill : rien
  local k = rcombat({ opportunity = 2 })
  eq(Combat.calcDamage(k, k.player, k.enemies[1], 6, nil), 6)
  eq(Combat.calcDamage(k, k.player, k.enemies[1], 6, ns.Cards.sinister_strike), 6, "hors résolution d'une carte")
  -- bots : Stealth gardé vaut le bonus
  local src = k.talents[1]
  local W = { enemyHp = 4 }
  eq(Talent.part("rogue", src).bot.value(k, src, W), 2 * RT.opportunity * 4)
  k.player.st.stealth = nil
  eq(Talent.part("rogue", src).bot.value(k, src, W), 0)
end)

test("Vile Poisons : chaque DoT posé sur un ennemi +1 (avec Crystal Vial)", function()
  local c = rcombat({ vile_poisons = 1 }, nil, { deck = { "garrote" } })
  local g = ns.Cards.garrote.effects[3][3]
  play(c, "garrote")
  eq(c.enemies[1].st.pain, g + RT.vile)
  local v = rcombat({ vile_poisons = 1 }, nil, { deck = { "garrote" }, relics = { "crystal_vial" } })
  play(v, "garrote")
  eq(v.enemies[1].st.pain, g + RT.vile + 1)
  eq(Combat.modify(v, "apply", 2, "demoralized", v.enemies[1]), 2, "autre état : rien")
end)

test("Lightning Reflexes : Parry tient une charge de plus, le module reste intact", function()
  local c = rcombat({ lightning_reflexes = 1 }, nil, { deck = { "evasion", "evasion", "evasion" } })
  Combat.applyStatus(c, c.player, "parry", 9)
  eq(c.player.st.parry, 3 + RT.reflexes)
  eq(Rogue.PARRY_MAX, 3); eq(ns.Statuses.parry.max, 3)
  local p = rcombat(nil)
  Combat.applyStatus(p, p.player, "parry", 9)
  eq(p.player.st.parry, 3)
end)

test("Combat Readiness : chaque Parry arrête 2 dégâts de plus par rang", function()
  for r = 0, 2 do
    local c = rcombat(r > 0 and { combat_readiness = r } or nil, nil, { encounter = { "tr_big" } })
    Combat.applyStatus(c, c.player, "parry", 1)
    local hp = c.player.hp
    Combat.endPlayerTurn(c); Combat.enemyPhase(c)
    eq(hp - c.player.hp, 18 - (Rogue.PARRY_STOP + RT.readiness * r), "rang " .. r)
  end
  eq(Rogue.PARRY_STOP, 8, "module intact")
end)

test("Relentless Strikes : +1 Combo par rang après chaque Surge, pas sans Surge", function()
  for r = 1, 2 do
    local c = rcombat({ relentless_strikes = r }, nil, { deck = { "eviscerate", "sinister_strike" } })
    Combat.gainRes(c, 3)
    play(c, "eviscerate")
    eq(c.player.res, RT.relentless * r, "rang " .. r)
    play(c, "sinister_strike")
    eq(c.player.res, RT.relentless * r + 1)
  end
end)

test("Specialization : Assassination (DoT par Combo), Combat (Combo par Parry), Subtlety (pioche au Stealth)", function()
  -- Assassination : Eviscerate à 3 Combo pose DoT 3 sur sa cible
  local a = rcombat({ specialization = 1 }, "assassination", { deck = { "eviscerate" } })
  Combat.gainRes(a, 3)
  play(a, "eviscerate")
  eq(a.enemies[1].st.pain, 3 * RT.assassinDot)
  eq(a.enemies[1].hp, 100 - evisc(3))
  -- Combat : chaque charge de Parry consommée donne du Combo
  local cb = rcombat({ specialization = 1 }, "combat", { encounter = { "tr_big" } })
  Combat.applyStatus(cb, cb.player, "parry", 1)
  Combat.endPlayerTurn(cb); Combat.enemyPhase(cb)
  eq(cb.player.res, RT.combatCombo)
  -- Subtlety : une carte qui donne Stealth (absent avant) pioche ; pas déjà caché
  local s = rcombat({ specialization = 1 }, "subtlety", { deck = { "sinister_strike", "vanish", "sinister_strike",
    "sinister_strike", "sinister_strike", "feint", "feint", "feint" } })
  s.player.mana = 5
  play(s, "sinister_strike") -- consomme Stealth
  local hand = #s.hand
  play(s, "vanish") -- Draw 1, Gain Stealth : 1 + 1 pioche
  eq(#s.hand, hand - 1 + 1 + RT.subtletyDraw)
  local s2 = rcombat({ specialization = 1 }, "subtlety", { deck = { "vanish", "feint", "feint", "feint", "feint",
    "feint", "feint" } })
  hand = #s2.hand
  play(s2, "vanish") -- déjà caché : pas de gain
  eq(#s2.hand, hand - 1 + 1)
end)

test("Deeper Stratagem : plafond de Combo +1 par rang, Eviscerate compte le Combo en plus", function()
  eq(Combat.resCap(rcombat(nil)), 5)
  eq(Combat.resCap(rcombat({ deeper_stratagem = 1 })), 5 + RT.stratagem)
  local c = rcombat({ deeper_stratagem = 2 }, nil, { deck = { "eviscerate" } })
  eq(Combat.resCap(c), 5 + 2 * RT.stratagem)
  Combat.gainRes(c, 9); eq(c.player.res, 5 + 2 * RT.stratagem)
  play(c, "eviscerate")
  eq(c.enemies[1].hp, 100 - evisc(5 + 2 * RT.stratagem))
end)

test("Cheat Fate : une fois par expédition, 1 PV et Parry (rang 2 : et Stealth), gardé d'un combat à l'autre", function()
  local c = rcombat({ cheat_fate = 2 })
  play(c, "sinister_strike") -- Stealth consommé
  c.player.hp = 3
  Combat.dealDamage(c, c.enemies[1], c.player, 50)
  eq(c.result, nil); eq(c.player.hp, 1); eq(c.player.st.parry, RT.fateParry[2]); eq(c.player.st.stealth, 1)
  eq(c.tstate.cheatFate, true)
  c.player.st.parry = nil
  Combat.dealDamage(c, c.enemies[1], c.player, 50)
  eq(c.result, "lost", "une seule fois")
  local c1 = rcombat({ cheat_fate = 1 })
  c1.player.hp = 2
  Combat.loseHp(c1, 10, "test")
  eq(c1.player.hp, 1); eq(c1.player.st.parry, RT.fateParry[1])
  -- Cheat Death (Last Breath de combat, Power) passe avant le talent
  local cd = rcombat({ cheat_fate = 1 }, nil, { deck = { "cheat_death" } })
  play(cd, "cheat_death")
  cd.player.hp = 2
  Combat.loseHp(cd, 10, "test")
  eq(cd.player.hp, 1); eq(cd.tstate.cheatFate, nil, "talent gardé pour plus tard")
  -- dans l'expédition : l'état revient à l'expédition et suit au combat suivant
  local e = rexp({ cheat_fate = 1 })
  enter(e, "combat")
  e.combat.player.hp = 2
  Combat.loseHp(e.combat, 10, "test")
  winCombat(e)
  eq(e.talentState.cheatFate, true)
  assert(X.act(e, { "leave" }))
  local nx = X.nextNodes(e)[1]
  e.map.nodes[nx].kind = "combat"
  assert(X.act(e, { "path", nx }))
  eq(e.combat.tstate.cheatFate, true, "pas une deuxième fois dans l'expédition")
end)

---------------------------------------------------------------------------
-- Simulation
---------------------------------------------------------------------------
test("simulation : arbre plein du Rogue, même graine = mêmes décisions", function()
  local map, spec = Talent.fromShare("rogue", 100)
  local function run()
    return ns.SimExpedition.play({ seed = 12, bot = "human", class = "rogue", zones = 3, level = 7, key = 0,
      talents = map, spec = spec, maxZone = "duskwood" })
  end
  local a, ea = run()
  local b = run()
  eq(a.zones[1].maxHp, RHP + 3 * RT.hp)
  eq(a.hp, b.hp); eq(#a.combats, #b.combats)
  eq(ea.talents[1].id, "toughness")
  local taken = 0
  for _ in pairs(ea.epicTaken or {}) do taken = taken + 1 end
  assert(taken >= 2, "Veteran's Arsenal 2 : deux épiques au départ (" .. taken .. ")")
end)

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
