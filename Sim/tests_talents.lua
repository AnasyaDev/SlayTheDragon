-- Tests des arbres de talents (docs/talents.md) : méta (25 niveaux, paliers de contenu, points), rangées,
-- remboursement, arbre figé au départ, migration v7 -> v8, crochets du socle, génériques, chaque nœud du Warrior,
-- constantes de classe lues sur l'état du combat, simulation (tree=).
-- Usage : lua5.1 Sim/tests_talents.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
if jit and jit.opt then pcall(jit.opt.start, "maxtrace=65535", "maxmcode=262144") end
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Meta, Save, Combat, Talent, U = ns.Expedition, ns.Meta, ns.Save, ns.Combat, ns.Talent, ns.Util
local WT = ns.WarriorTalents
local WHP = ns.Classes.warrior.hp

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

-- Sérialisation façon SavedVariables (clés triées).
local function ser(v, out)
  local t = type(v)
  if t == "number" then out[#out + 1] = string.format("%.17g", v)
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "boolean" then out[#out + 1] = tostring(v)
  elseif t == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      if type(a) ~= type(b) then return type(a) < type(b) end
      return tostring(a) < tostring(b)
    end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      out[#out + 1] = "["; ser(k, out); out[#out + 1] = "]="; ser(v[k], out); out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  else
    error("valeur non sauvegardable : " .. t)
  end
end
local function serialize(v) local o = {}; ser(v, o); return table.concat(o) end
local function reload(v) return assert(loadstring("return " .. serialize(v)))() end

ns.Enemies.tt_dummy = { name = "Mannequin", hp = 100,
  moves = { idle = { name = "Rien", intent = "buff", actions = {} } }, pattern = { "idle" } }
ns.Enemies.tt_hitter = { name = "Cogneur", hp = 100,
  moves = { hit = { name = "Coup", intent = "attack", actions = { { "attack", 10 } } } }, pattern = { "hit" } }

-- Talents d'une table { [nœud] = rang } (et voie) pour Combat.new / Expedition.new.
local function entries(map, spec, class) return Talent.entries(class or "warrior", map, spec) end

-- Combat du Warrior avec ces talents (deck de Strike et Defend, mannequin), sans bibelot.
local function wcombat(map, spec, o)
  o = o or {}
  local deck = {}
  for _, id in ipairs(o.deck or { "strike", "strike", "defend", "defend", "strike", "defend", "strike" }) do
    deck[#deck + 1] = { id = id, up = false }
  end
  local ts = map and entries(map, spec) or nil
  return Combat.new({ seed = o.seed or 5, class = o.class or "warrior", hp = o.hp or 60, maxHp = 60, deck = deck,
    encounter = o.encounter or { "tt_dummy" }, relics = o.relics, talents = ts and U.copy(ts) or nil,
    tstate = ts and (o.tstate or {}) or nil, quiet = true })
end

local function wexp(map, spec, o)
  o = o or {}
  local unlocks = Meta.allUnlocked(o.level or 1, o.zones or 0)
  unlocks.talents, unlocks.spec = map, spec
  local exp = X.new({ seed = o.seed or 11, class = o.class or "warrior", unlocks = unlocks, quiet = true })
  return exp
end

-- Entre dans un combat (premier nœud de départ forcé en combat) ; gagne le combat en cours.
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
-- Méta : niveaux, paliers de contenu, points
---------------------------------------------------------------------------
test("niveaux : 25 seuils de la fiche (§ 1.2), un point par niveau à partir du 2", function()
  local T = { 0, 100, 200, 300, 400, 500, 650, 800, 950, 1100, 1250, 1400, 1550, 1700, 1850, 2000, 2250, 2500,
    2750, 3000, 3250, 3600, 3950, 4300, 4650 }
  eq(Meta.MAX_LEVEL, 25); eq(#Meta.XP_LEVELS, 25)
  for i = 1, 25 do eq(Meta.XP_LEVELS[i], T[i], "seuil " .. i) end
  local meta = Meta.new()
  for lv = 1, 25 do
    Meta.classState(meta, "warrior").xp = T[lv]
    eq(Meta.levelOf(meta, "warrior"), lv)
    eq(Meta.talentPoints(meta, "warrior"), lv - 1, "points au niveau " .. lv)
  end
  Meta.classState(meta, "warrior").xp = 99999
  eq(Meta.levelOf(meta, "warrior"), 25, "rien au-delà du niveau 25")
  eq(Meta.talentPoints(meta, "warrior"), Talent.POINTS)
  eq(Talent.POINTS, 24)
end)

test("contentTier : aucune carte ni aucun bibelot plus tard qu'avant les 25 niveaux (au plus 150 plus tôt)", function()
  local OLD = { 0, 100, 250, 450, 700, 1000, 1400 } -- seuils des 7 niveaux d'avant le 19/11/2026
  eq(Meta.MAX_TIER, 7)
  for t = 1, 7 do
    local lv = Meta.CONTENT_LEVELS[t]
    local now = Meta.XP_LEVELS[lv]
    assert(now <= OLD[t], ("palier %d : %d d'expérience au lieu de %d"):format(t, now, OLD[t]))
    assert(OLD[t] - now <= 150, ("palier %d : %d plus tôt"):format(t, OLD[t] - now))
    eq(Meta.contentTier(lv), t); if lv > 1 then eq(Meta.contentTier(lv - 1), t - 1) end
  end
  eq(Meta.contentTier(25), 7); eq(Meta.contentTier(1), 1)
  -- pour toute expérience, le palier ouvert est au moins celui d'avant (cartes et bibelots de classe)
  local function oldLevel(xp)
    local lv = 1
    for i = 2, 7 do if xp >= OLD[i] then lv = i end end
    return lv
  end
  for xp = 0, 5000, 10 do
    local t = Meta.contentTier(Meta.classLevel(xp))
    assert(t >= oldLevel(xp), "xp " .. xp)
  end
  -- répartition des contenus inchangée : le champ level des cartes reste 1 à 7
  for _, d in pairs(ns.Cards) do
    if d.class and d.level then assert(d.level >= 1 and d.level <= 7, tostring(d.name)) end
  end
  -- Meta.unlocks donne le palier, pas le niveau ; un compte à 1 250 d'expérience a tout le contenu
  local meta = Meta.new()
  Meta.classState(meta, "warrior").xp = 1250
  eq(Meta.levelOf(meta, "warrior"), 11); eq(Meta.unlocks(meta, "warrior").level, 7)
  Meta.classState(meta, "warrior").xp = 650
  eq(Meta.unlocks(meta, "warrior").level, 5)
end)

test("fin d'expédition : points gagnés et contenu des paliers franchis", function()
  local db = Save.new()
  Meta.classState(db.meta, "warrior").xp = 1240 -- niveau 10 (palier 6)
  local exp = assert(Save.start(db, { seed = 3, class = "warrior" }))
  if exp.phase == "start" then assert(X.act(exp, { "skipStartRelic" })) end
  exp.stats.cleared, exp.stats.elites, exp.stats.bosses = 8, 1, 1
  exp.result, exp.phase = "lost", "done"
  local s = Save.finish(db, "x")
  eq(s.levelBefore, 10); eq(s.levelAfter, 11); eq(s.pointsGained, 1)
  local got = Meta.classContent("warrior", 7)
  eq(#s.unlocked.cards, #got.cards, "cartes du palier 7"); eq(#s.unlocked.relics, #got.relics)
end)

---------------------------------------------------------------------------
-- Rangées, rangs, Specialization, remboursement
---------------------------------------------------------------------------
test("rangées ouvertes à 0 / 5 / 10 / 16 points, un rang demande le précédent, points comptés", function()
  local meta = Meta.new()
  local cs = Meta.classState(meta, "warrior")
  cs.xp = Meta.XP_LEVELS[25]
  local function learn(id, ch) return Meta.learn(meta, "warrior", id, ch) end
  eq(select(2, learn("unbridled_wrath")), "row", "rangée 2 fermée à 0 point")
  eq(select(2, learn("nope")), "unknown")
  assert(learn("toughness")); assert(learn("toughness")); assert(learn("toughness"))
  eq(select(2, learn("toughness")), "max", "Toughness : 3 rangs")
  assert(learn("battle_ready"))
  eq(Meta.spent(meta, "warrior"), 4)
  eq(select(2, learn("anger_shield")), "row", "4 points : rangée 2 fermée")
  assert(learn("battle_ready"))
  assert(learn("anger_shield"), "5 points : rangée 2 ouverte")
  for _ = 1, 3 do assert(learn("second_wind") or learn("unbridled_wrath")) end
  eq(Meta.spent(meta, "warrior"), 10 - 1)
  eq(select(2, learn("specialization", "arms")), "row", "9 points : rangée 3 fermée")
  assert(learn("provisions"))
  eq(select(2, learn("specialization")), "choice", "voie obligatoire")
  eq(select(2, learn("specialization", "bogus")), "choice")
  assert(learn("specialization", "arms")); eq(cs.spec, "arms"); eq(cs.talents.specialization, 1)
  -- une seule voie : apprendre une autre voie change la voie active sans coût
  assert(learn("specialization", "protection")); eq(cs.spec, "protection"); eq(cs.talents.specialization, 1)
  eq(Meta.spent(meta, "warrior"), 11)
  eq(select(2, learn("specialization", "protection")), "choice", "déjà la voie active")
  local ts = Talent.entries("warrior", cs.talents, cs.spec)
  local specs = 0
  for _, e in ipairs(ts) do if e.spec then specs = specs + 1; eq(e.spec, "protection") end end
  eq(specs, 1)
  eq(select(2, learn("rampage")), "row", "rangée 4 fermée sous 16 points")
  -- points épuisés
  local m2 = Meta.new()
  Meta.classState(m2, "warrior").xp = Meta.XP_LEVELS[3] -- niveau 3 : 2 points
  assert(Meta.learn(m2, "warrior", "toughness")); assert(Meta.learn(m2, "warrior", "toughness"))
  eq(select(2, Meta.learn(m2, "warrior", "toughness")), "points")
  eq(Meta.pointsLeft(m2, "warrior"), 0)
  -- classe sans arbre
  eq(select(2, Meta.learn(m2, "priest", "toughness")), "unknown")
end)

test("remboursement gratuit hors expédition ; dépenser et rembourser refusés pendant une expédition", function()
  local db = Save.new()
  Meta.classState(db.meta, "warrior").xp = Meta.XP_LEVELS[8] -- 7 points
  assert(Save.learnTalent(db, "warrior", "toughness"))
  assert(Save.learnTalent(db, "warrior", "battle_ready"))
  eq(Meta.spent(db.meta, "warrior"), 2)
  assert(Save.start(db, { seed = 2, class = "warrior" }))
  eq(select(2, Save.learnTalent(db, "warrior", "toughness")), "running")
  eq(select(2, Save.resetTalents(db, "warrior")), "running")
  eq(Meta.spent(db.meta, "warrior"), 2)
  assert(Save.abandon(db, "x"))
  eq(Save.resetTalents(db, "warrior"), 2, "points rendus")
  eq(Meta.spent(db.meta, "warrior"), 0); eq(Meta.pointsLeft(db.meta, "warrior"), 7)
  eq(next(db.meta.classes.warrior.talents), nil); eq(db.meta.classes.warrior.spec, nil)
  assert(Save.learnTalent(db, "warrior", "toughness"))
  assert(Save.validate(db))
end)

test("arbre figé au départ : dépenser ou rembourser après le départ ne change pas l'expédition", function()
  local db = Save.new()
  Meta.classState(db.meta, "warrior").xp = Meta.XP_LEVELS[25]
  for _ = 1, 3 do assert(Save.learnTalent(db, "warrior", "toughness")) end
  local exp = assert(Save.start(db, { seed = 4, class = "warrior" }))
  eq(exp.unlock.talents.toughness, 3); eq(exp.maxHp, WHP + 3 * WT.hp)
  local snap = serialize(exp.talents)
  Meta.reset(db.meta, "warrior") -- (méta modifiée directement : Save le refuse)
  Meta.learn(db.meta, "warrior", "battle_ready")
  eq(exp.unlock.talents.toughness, 3); eq(exp.unlock.talents.battle_ready, nil)
  eq(serialize(exp.talents), snap)
  if exp.phase == "start" then assert(X.act(exp, { "skipStartRelic" })) end
  enter(exp, "combat")
  eq(exp.combat.player.res, 1, "Battle Standard seul : Battle Ready appris après le départ")
  eq(exp.combat.player.maxHp, WHP + 3 * WT.hp)
end)

test("expédition sans talent : aucun champ de talent (état d'avant les talents)", function()
  local exp = X.new({ seed = 3, class = "warrior", unlocks = Meta.allUnlocked(1, 0), quiet = true })
  eq(exp.talents, nil); eq(exp.talentState, nil); eq(exp.unlock.talents, nil)
  enter(exp, "combat")
  eq(exp.combat.talents, nil); eq(exp.combat.tstate, nil)
  local db = Save.new()
  local e2 = assert(Save.start(db, { seed = 3, class = "warrior" }))
  eq(e2.talents, nil, "compte sans talent appris")
end)

---------------------------------------------------------------------------
-- Migration
---------------------------------------------------------------------------
test("migration v7 -> v8 : expérience gardée, contenu identique ou plus large, titre gardé, expédition intacte", function()
  local cur = X.new({ seed = 8, class = "warrior", unlocks = { level = 7, common = 2, won = { westfall = 0 } },
    quiet = true })
  if cur.phase == "start" then assert(X.act(cur, { "skipStartRelic" })) end
  enter(cur, "combat")
  local v7 = { version = 7, meta = { runs = 9, flags = {}, zones = { westfall = true }, classes = {
      warrior = { xp = 1400, runs = 6, wins = 0, keyMax = 0, bestKey = -1, farthest = 3, zones = {} },
      priest = { xp = 450, runs = 3, wins = 0, keyMax = 0, bestKey = -1, farthest = 1, zones = {} } } },
    current = cur, journal = {} }
  local db, note = Save.migrate(reload(v7))
  eq(note, "migrated"); eq(db.version, 8); eq(Save.VERSION, 8)
  local w, p = db.meta.classes.warrior, db.meta.classes.priest
  eq(w.xp, 1400); eq(Meta.levelOf(db.meta, "warrior"), 12); eq(Meta.talentPoints(db.meta, "warrior"), 11)
  eq(Meta.levelOf(db.meta, "priest"), 5); eq(Meta.talentPoints(db.meta, "priest"), 4)
  eq(Meta.unlocks(db.meta, "warrior").level, 7, "tout le contenu (niveau 7 d'avant)")
  eq(Meta.unlocks(db.meta, "priest").level, 4, "palier 4 (niveau 4 d'avant)")
  eq(type(w.talents), "table"); eq(next(w.talents), nil); eq(w.spec, nil)
  eq(w.veteran, true); eq(p.veteran, nil)
  eq(Meta.title(db.meta, "warrior"), "Veteran"); eq(Meta.title(db.meta, "priest"), nil)
  local m = db.current
  assert(m, "expédition gardée")
  eq(m.unlock.level, 7, "palier de contenu inchangé"); eq(m.unlock.talents, nil); eq(m.talents, nil)
  assert(Save.validate(db))
  assert(X.act(m, { "endTurn" }))
  -- idempotente
  local again = Save.migrate(reload(db))
  eq(serialize(again.meta), serialize(db.meta))
  -- aucune carte perdue : chaque palier débloqué avant l'est encore (toutes les expériences d'avant)
  for _, xp in ipairs({ 0, 99, 100, 249, 250, 449, 450, 699, 700, 999, 1000, 1399, 1400, 3000 }) do
    local before = 1
    for i, s in ipairs({ 0, 100, 250, 450, 700, 1000, 1400 }) do if xp >= s then before = i end end
    local d = Save.migrate({ version = 7, meta = { classes = { mage = { xp = xp, zones = {} } } }, journal = {} })
    assert(Meta.unlocks(d.meta, "mage").level >= before, "xp " .. xp)
  end
end)

---------------------------------------------------------------------------
-- Forme de l'arbre du Warrior, API de lecture, simulation
---------------------------------------------------------------------------
test("arbre du Warrior : 13 nœuds, 24 points, 4 rangées, un Specialization, ordre du bot légal", function()
  local errs = Talent.check("warrior")
  assert(#errs == 0, table.concat(errs, " ; "))
  local t = ns.Talents.warrior
  eq(#t.nodes, 13)
  local rows = { 0, 0, 0, 0 }
  for _, n in ipairs(t.nodes) do rows[n.row] = rows[n.row] + n.ranks end
  eq(rows[1], 7); eq(rows[2], 5); eq(rows[3], 6); eq(rows[4], 6)
  eq(t.rows[1], 0); eq(t.rows[2], 5); eq(t.rows[3], 10); eq(t.rows[4], 16)
  -- génériques : mêmes noms
  for _, id in ipairs({ "toughness", "provisions", "field_medic", "veterans_arsenal" }) do assert(t.byId[id], id) end
  eq(t.byId.toughness.text[3], ("+%d max HP."):format(3 * WT.hp))
  eq(t.byId.battle_ready.text[2], "Start of combat: +2 Rage.")
  eq(t.byId.specialization.byChoice.arms.text, "Sundered enemies take 50% more damage instead of 25%.")
  eq(t.byId.field_medic.text[1], "Moving to the next zone heals 75% of max HP instead of 50%.")
  -- textes : anglais simple, une phrase qui finit par un point
  for _, n in ipairs(t.nodes) do
    local list = n.choices and {} or n.text
    for _, ch in ipairs(n.choices or {}) do list[#list + 1] = ch.text end
    for _, s in ipairs(list) do assert(s:find("%.$") and not s:find("[éèàç]"), n.id .. " : " .. s) end
  end
  -- classes sans arbre (fichiers vides au TOC)
  for _, cl in ipairs({ "priest", "rogue", "mage", "hunter", "druid" }) do
    eq(ns.Talents[cl], nil, cl .. " : arbre à écrire")
  end
end)

test("tree= : parts de l'arbre (5 / 10 / 15 / 20 / 24 points) dans l'ordre du bot", function()
  eq(Talent.pointsOf(0), 0); eq(Talent.pointsOf(20), 5); eq(Talent.pointsOf(40), 10)
  eq(Talent.pointsOf(60), 15); eq(Talent.pointsOf(80), 20); eq(Talent.pointsOf(100), 24)
  local map, spec, n = Talent.fromShare("warrior", 60)
  eq(n, 15); eq(Talent.spentIn(map), 15); eq(spec, "fury")
  -- palier 60 % de la fiche (§ 6)
  local want = { toughness = 3, battle_ready = 2, second_wind = 2, unbridled_wrath = 2, anger_shield = 2,
    provisions = 1, specialization = 1, blood_drinker = 2 }
  for id, r in pairs(want) do eq(map[id], r, id) end
  for id in pairs(map) do assert(want[id], "en trop : " .. id) end
  local full = Talent.fromShare("warrior", 100, "arms")
  eq(Talent.spentIn(full), 24)
  eq(select(2, Talent.fromShare("warrior", 100, "arms")), "arms")
  eq(Talent.spentIn((Talent.fromShare("warrior", 0))), 0)
end)

test("API de lecture : rangées, rangs, textes, voies, points restants, expédition en cours", function()
  local meta = Meta.new()
  Meta.classState(meta, "warrior").xp = Meta.XP_LEVELS[7] -- 6 points
  local v = Talent.view(meta, "warrior")
  eq(v.points, 6); eq(v.spent, 0); eq(v.left, 6); eq(#v.rows, 4)
  eq(v.rows[1].open, true); eq(v.rows[2].open, false); eq(v.rows[2].need, 5)
  local tough = v.rows[1].nodes[1]
  eq(tough.id, "toughness"); eq(tough.rank, 0); eq(tough.text, nil); eq(tough.nextText, "+4 max HP.")
  eq(tough.canLearn, true)
  eq(v.rows[2].nodes[1].canLearn, false); eq(v.rows[2].nodes[1].why, "row")
  for _ = 1, 3 do Meta.learn(meta, "warrior", "toughness") end
  Meta.learn(meta, "warrior", "battle_ready"); Meta.learn(meta, "warrior", "battle_ready")
  v = Talent.view(meta, "warrior")
  eq(v.left, 1); eq(v.rows[2].open, true)
  tough = v.rows[1].nodes[1]
  eq(tough.rank, 3); eq(tough.text, "+12 max HP."); eq(tough.nextText, nil); eq(tough.why, "max")
  local spec = v.rows[3].nodes[1]
  eq(spec.id, "specialization"); eq(#spec.choices, 3); eq(spec.choices[1].active, false); eq(spec.why, "row")
  eq(Talent.view(meta, "warrior", true).rows[2].nodes[1].why, "running")
  eq(Talent.rankText("warrior", "anger_shield", 2), ("End of turn: gain 1 Absorb per %d Rage."):format(WT.shieldDiv[2]))
  eq(Talent.rankText("warrior", "specialization", 1, "fury"),
    ("While you have %d Rage or more, Attacks deal %d more per hit."):format(WT.furyAt, WT.furyBonus))
  eq(#Talent.view(meta, "priest").rows, 0, "classe sans arbre : vue vide")
end)

---------------------------------------------------------------------------
-- Socle : combat, expédition, sauvegarde
---------------------------------------------------------------------------
test("combat : talents copiés dans c.talents, crochets écoutés (c.hk), état cloné en profondeur", function()
  local c = wcombat({ battle_ready = 2, unyielding = 1 })
  eq(#c.talents, 2); eq(c.talents[1].id, "battle_ready")
  assert(c.hk.onCombatStart and c.hk.preventDeath)
  local k = Combat.clone(c)
  k.tstate.unyielding = true
  eq(c.tstate.unyielding, nil, "clone : état d'expédition copié")
  eq(k.talents, c.talents)
end)

test("constantes de classe : Combat.const lit le module, un talent la change sans toucher à l'addon", function()
  local c = wcombat(nil)
  eq(Combat.const(c, "SUNDER_MULT", Combat.SUNDER_MULT), 1.25)
  -- arbre factice du Druid (aucun arbre réel encore) : TAX_FREE +1 lu sur l'état du combat
  local D = ns.Druid
  ns.Talent.define("druid", { rows = { 0, 5, 10, 16 }, nodes = {
    { id = "tt_shift", row = 1, ranks = 2, name = "Test", text = { "x.", "y." },
      const = { TAX_FREE = function(v, src) return v + src.rank end } } } })
  local dc = Combat.new({ seed = 1, class = "druid", hp = 50, deck = { { id = "wrath", up = false } },
    encounter = { "tt_dummy" }, talents = Talent.entries("druid", { tt_shift = 2 }), quiet = true })
  eq(D.TAX_FREE, 1, "module intact")
  eq(Combat.const(dc, "TAX_FREE", D.TAX_FREE), 3)
  eq(D.taxOf(3, dc), 0, "3 changements : gratuits avec le talent"); eq(D.taxOf(3), D.TAX * 2 > D.TAX_MAX and D.TAX_MAX or D.TAX * 2)
  ns.Talents.druid = nil
  -- Parry : plafond de l'état lu par Combat.const (maxKey)
  eq(ns.Statuses.parry.maxKey, "PARRY_MAX")
  eq(ns.Hunter.petBase(c), ns.Hunter.PET_BASE)
end)

test("sauvegarde : expédition en combat avec talents, données simples, rechargée et rejouée", function()
  local db = Save.new()
  Meta.classState(db.meta, "warrior").xp = Meta.XP_LEVELS[25]
  for _, id in ipairs(ns.Talents.warrior.bot.order) do
    assert(Save.learnTalent(db, "warrior", id, ns.Talents.warrior.bot.spec))
  end
  local exp = assert(Save.start(db, { seed = 6, class = "warrior" }))
  eq(exp.phase, "map", "aucune zone gagnée : pas d'épique au départ")
  enter(exp, "combat")
  assert(Save.validate(db))
  Save.settle(db)
  local db2 = Save.migrate(reload(db))
  assert(Save.validate(db2))
  eq(serialize(db2.current), serialize(db.current))
  assert(X.act(db2.current, { "endTurn" }))
  assert(Save.validate(db2))
end)

---------------------------------------------------------------------------
-- Génériques
---------------------------------------------------------------------------
test("Toughness et Provisions : PV max et or de départ", function()
  local e = wexp({ toughness = 2, provisions = 1 })
  eq(e.maxHp, WHP + 2 * WT.hp); eq(e.hp, e.maxHp); eq(e.gold, X.START_GOLD + 100)
  local z = wexp({ toughness = 3 })
  eq(z.maxHp, WHP + 12); eq(z.gold, X.START_GOLD)
end)

test("Field Medic : passage de zone à 75 % des PV max au lieu de 50 %", function()
  for _, fm in ipairs({ 0, 1 }) do
    local e = wexp(fm > 0 and { field_medic = 1 } or { toughness = 1 })
    e.hp = 1
    X.enterZone(e, "duskwood")
    eq(e.transit.healed, math.floor(e.maxHp * (fm > 0 and 0.75 or 0.5)), "Field Medic " .. fm)
  end
end)

test("Veteran's Arsenal : une puis deux épiques au choix au départ, parmi les zones battues", function()
  local none = wexp({ veterans_arsenal = 1 })
  eq(none.phase, "map", "aucune zone battue : pas de choix")
  eq(none.talentEpics, nil)
  local e = wexp({ veterans_arsenal = 1 }, nil, { zones = 2 })
  eq(e.phase, "start"); eq(#e.talentEpics, 2); eq(e.talentEpicsLeft, 1)
  local ch = X.choices(e)
  eq(ch[1][1], "talentEpic"); eq(ch[#ch][1], "skipTalentEpic")
  eq(select(2, X.act(e, { "startRelic", 1 })), "index", "épique d'abord")
  local id = e.talentEpics[2]
  assert(X.act(e, { "talentEpic", 2 }))
  eq(e.phase, "map"); eq(e.talentEpics, nil); eq(X.epicCount(e), 1); eq(e.deck[#e.deck].id, id)
  eq(e.stats.cardsAdded, 0); assert(e.epicTaken[id])
  -- rang 2 : deux choix successifs ; puis le bibelot au départ (zone 3 du compte)
  local two = wexp({ veterans_arsenal = 2 }, nil, { zones = 3 })
  eq(two.talentEpicsLeft, 2); eq(#two.talentEpics, 3); assert(two.startRelics)
  assert(X.act(two, { "talentEpic", 1 }))
  eq(two.phase, "start"); eq(#two.talentEpics, 2)
  assert(X.act(two, { "talentEpic", 1 }))
  eq(two.phase, "start", "bibelot de départ ensuite"); eq(two.talentEpics, nil); eq(X.epicCount(two), 2)
  assert(X.act(two, { "skipStartRelic" })); eq(two.phase, "map")
  -- refus
  local sk = wexp({ veterans_arsenal = 2 }, nil, { zones = 1 })
  eq(sk.talentEpicsLeft, 2); eq(#sk.talentEpics, 1)
  assert(X.act(sk, { "talentEpic", 1 })); eq(sk.phase, "map", "plus d'épique proposable")
  local sk2 = wexp({ veterans_arsenal = 1 }, nil, { zones = 4 })
  assert(X.act(sk2, { "skipTalentEpic" })); eq(X.epicCount(sk2), 0)
  eq(sk2.phase, "start", "zone 3 du compte : le bibelot au choix suit"); assert(sk2.startRelics)
end)

---------------------------------------------------------------------------
-- Nœuds du Warrior
---------------------------------------------------------------------------
test("Battle Ready : +1 Rage par rang au début du combat (avec Battle Standard)", function()
  eq(wcombat({ battle_ready = 1 }).player.res, 1)
  eq(wcombat({ battle_ready = 2 }).player.res, 2)
  eq(wcombat({ battle_ready = 2 }, nil, { relics = { "battle_standard" } }).player.res, 3)
  eq(wcombat(nil).player.res, 0)
end)

test("Second Wind : soin de 1 par windDiv[rang] Rage restante après un combat gagné", function()
  for r = 1, 2 do
    for _, res in ipairs({ 3, 5 }) do
      local e = wexp({ second_wind = r })
      enter(e, "combat")
      e.combat.player.hp, e.combat.player.res = 30, res
      winCombat(e)
      eq(e.phase, "reward")
      eq(e.hp, 30 + math.floor(res / WT.windDiv[r]), "rang " .. r .. ", " .. res .. " Rage")
    end
  end
  eq(ns.Talents.warrior.byId.second_wind.text[1], ("After a combat won: heal 1 per %d Rage you have."):format(WT.windDiv[1]))
  local c = wcombat({ second_wind = 2 })
  c.player.hp, c.player.res, c.result = 40, 8, "won"
  -- bots : un combat gagné avec de la Rage vaut le soin, borné aux PV manquants
  eq(ns.Talent.part("warrior", c.talents[1]).bot.won(c, c.talents[1]), math.floor(8 / WT.windDiv[2]))
  c.player.hp = 60
  eq(ns.Talent.part("warrior", c.talents[1]).bot.won(c, c.talents[1]), 0)
end)

test("Unbridled Wrath : plafond de Rage +1 par rang (Avatar garde 10)", function()
  eq(Combat.resCap(wcombat({ unbridled_wrath = 1 })), 6)
  local c = wcombat({ unbridled_wrath = 2 })
  eq(Combat.resCap(c), 7)
  Combat.gainRes(c, 9); eq(c.player.res, 7)
  local av = Combat.new({ seed = 1, class = "warrior", hp = 60, deck = { { id = "strike", up = false },
    { id = "avatar", up = false } }, encounter = { "tt_dummy" }, talents = entries({ unbridled_wrath = 2 }),
    quiet = true })
  eq(Combat.resCap(av), 10)
end)

test("Anger Shield : fin du tour, 1 Absorb par shieldDiv[rang] Rage", function()
  for r = 1, 2 do
    for _, res in ipairs({ 3, 5, 7 }) do
      local c = wcombat({ anger_shield = r, unbridled_wrath = 2 })
      c.player.res = res
      Combat.endPlayerTurn(c)
      eq(c.player.block, math.floor(res / WT.shieldDiv[r]), "rang " .. r .. ", " .. res .. " Rage")
    end
  end
  local c = wcombat({ anger_shield = 2, unbridled_wrath = 2 }, nil, { encounter = { "tt_hitter" } })
  c.player.res = 7
  local hp = c.player.hp
  Combat.endTurn(c)
  eq(hp - c.player.hp, 10 - math.floor(7 / WT.shieldDiv[2]), "l'Absorb tient pendant le tour ennemi")
end)

test("Specialization : Arms (Sundered × 1,5), Fury (+1 par coup à 5 Rage), Protection (+2 Absorb par carte)", function()
  local strike = ns.Cards.strike
  local arms = wcombat({ specialization = 1 }, "arms")
  local e = arms.enemies[1]
  e.st.armor_broken = 2
  eq(Combat.calcDamage(arms, arms.player, e, 10, strike), 15)
  local plain = wcombat(nil)
  plain.enemies[1].st.armor_broken = 2
  eq(Combat.calcDamage(plain, plain.player, plain.enemies[1], 10, strike), 12)
  local fury = wcombat({ specialization = 1 }, "fury")
  local fe = fury.enemies[1]
  fury.player.res = WT.furyAt - 1
  eq(Combat.calcDamage(fury, fury.player, fe, 6, strike), 6)
  fury.player.res = WT.furyAt
  eq(Combat.calcDamage(fury, fury.player, fe, 6, strike), 6 + WT.furyBonus)
  eq(Combat.calcDamage(fury, fury.player, fe, 6, nil), 6, "coup sans carte")
  eq(Combat.calcDamage(fury, fury.player, fe, 6, ns.Cards.defend), 6, "Skill")
  local prot = wcombat({ specialization = 1 }, "protection", { deck = { "defend", "defend", "defend", "defend",
    "defend" } })
  assert(Combat.play(prot, idx(prot, "defend")))
  eq(prot.player.block, 5 + WT.protBonus)
  Combat.gainBlock(prot, prot.player, 3)
  eq(prot.player.block, 5 + WT.protBonus + 3, "Absorb sans carte : rien de plus")
end)

test("Tactical Mastery : Rage gardée (2 par rang) d'un combat gagné au suivant", function()
  local e = wexp({ tactical_mastery = 1 })
  enter(e, "combat")
  e.combat.player.res = 5
  winCombat(e)
  eq(e.talentState.rage, 2 * WT.carry / 2)
  assert(X.act(e, { "leave" }))
  local nx = X.nextNodes(e)[1]
  e.map.nodes[nx].kind = "combat"
  assert(X.act(e, { "path", nx }))
  eq(e.combat.player.res, 1 + WT.carry, "Battle Standard + Rage gardée")
  eq(e.combat.tstate.rage, nil, "rendue une fois")
  winCombat(e)
  eq(e.talentState.rage, math.min(e.talentState.rage or 0, 2), "Rage du combat suivant")
  -- rang 2 : jusqu'à 4
  local e2 = wexp({ tactical_mastery = 2 })
  enter(e2, "combat")
  e2.combat.player.res = 5
  winCombat(e2)
  eq(e2.talentState.rage, 2 * WT.carry)
end)

test("Blood Drinker : soin de 1 à chaque Spend payé (rang 2 : et à chaque Surge), pas au gain", function()
  local c1 = wcombat({ blood_drinker = 1 })
  c1.player.hp, c1.player.res = 30, 5
  assert(Combat.spendRes(c1, 2)); eq(c1.player.hp, 30 + WT.drink)
  Combat.surge(c1); eq(c1.player.hp, 30 + WT.drink, "rang 1 : pas au Surge")
  local c = wcombat({ blood_drinker = 2 })
  c.player.hp, c.player.res = 30, 5
  assert(Combat.spendRes(c, 2)); eq(c.player.hp, 30 + WT.drink)
  Combat.surge(c); eq(c.player.hp, 30 + 2 * WT.drink)
  Combat.gainRes(c, 3); eq(c.player.hp, 30 + 2 * WT.drink)
  Combat.gainRes(c, -1, "decay"); eq(c.player.hp, 30 + 2 * WT.drink, "autre perte de Rage : rien")
end)

test("Rampage : à 5 Rage au début du tour, +1 mana (rang 2 : et une carte)", function()
  local c = wcombat({ rampage = 1 })
  c.player.res = 4
  eq(Combat.modify(c, "maxMana", 3), 3)
  c.player.res = 5
  eq(Combat.modify(c, "maxMana", 3), 4); eq(Combat.modify(c, "drawPerTurn", 5), 5)
  local c2 = wcombat({ rampage = 2 }, nil, { deck = { "strike", "strike", "strike", "strike", "strike", "strike",
    "strike", "strike", "strike", "strike", "strike", "strike", "strike" } })
  c2.player.res = 5
  Combat.endPlayerTurn(c2)
  Combat.enemyPhase(c2); Combat.endRound(c2)
  Combat.startPlayerTurn(c2)
  eq(c2.player.mana, 4); eq(#c2.hand, 6)
end)

test("Unyielding : une fois par expédition, 1 PV et 5 Rage (rang 2 : et 15 Absorb), gardé d'un combat à l'autre", function()
  local c = wcombat({ unyielding = 2 })
  c.player.hp = 3
  Combat.dealDamage(c, c.enemies[1], c.player, 50)
  eq(c.result, nil); eq(c.player.hp, 1); eq(c.player.res, WT.saveRage); eq(c.player.block, WT.saveAbsorb)
  eq(c.tstate.unyielding, true)
  c.player.block = 0
  Combat.dealDamage(c, c.enemies[1], c.player, 50)
  eq(c.result, "lost", "une seule fois")
  local c1 = wcombat({ unyielding = 1 })
  c1.player.hp = 2
  Combat.loseHp(c1, 10, "test")
  eq(c1.player.hp, 1); eq(c1.player.block, 0)
  -- dans l'expédition : l'état revient à l'expédition et suit au combat suivant
  local e = wexp({ unyielding = 1 })
  enter(e, "combat")
  e.combat.player.hp = 2
  Combat.loseHp(e.combat, 10, "test")
  winCombat(e)
  eq(e.talentState.unyielding, true)
  assert(X.act(e, { "leave" }))
  local nx = X.nextNodes(e)[1]
  e.map.nodes[nx].kind = "combat"
  assert(X.act(e, { "path", nx }))
  eq(e.combat.tstate.unyielding, true, "pas une deuxième fois dans l'expédition")
end)

---------------------------------------------------------------------------
-- Simulation
---------------------------------------------------------------------------
test("simulation : arbre plein, épiques au départ prises par le bot, même graine = mêmes décisions", function()
  local map, spec = Talent.fromShare("warrior", 100)
  local function run()
    return ns.SimExpedition.play({ seed = 12, bot = "human", class = "warrior", zones = 3, level = 7, key = 0,
      talents = map, spec = spec, maxZone = "duskwood" })
  end
  local a, ea = run()
  local b = run()
  eq(a.zones[1].maxHp, WHP + 3 * WT.hp)
  local taken = 0
  for _ in pairs(ea.epicTaken or {}) do taken = taken + 1 end
  assert(taken >= 2, "Veteran's Arsenal 2 : deux épiques au départ (" .. taken .. ")")
  eq(serialize(a.picks), serialize(b.picks)); eq(a.hp, b.hp); eq(#a.combats, #b.combats)
  eq(ea.talents[1].id, "toughness")
  -- sans talents : aucun talent dans l'expédition
  local _, en = ns.SimExpedition.play({ seed = 12, bot = "human", class = "warrior", zones = 3, level = 7,
    maxZone = "westfall" })
  eq(en.talents, nil)
end)

print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
