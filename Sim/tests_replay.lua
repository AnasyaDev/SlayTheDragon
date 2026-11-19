-- Tests de l'enregistrement rejouable des expéditions (Core/Record.lua, Sim/replay.lua).
-- Usage : lua5.1 Sim/tests_replay.lua   (ou luajit) — doit finir par ALL PASS.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
if jit and jit.opt then pcall(jit.opt.start, "maxtrace=65535", "maxmcode=262144") end
local ns = dofile(root .. "/Sim/load.lua")(root)
local X, Save, Meta, R, Rng, U = ns.Expedition, ns.Save, ns.Meta, ns.Record, ns.Rng, ns.Util
local RP = dofile(root .. "/Sim/replay.lua").init(ns)
local SE = ns.SimExpedition
local BUILD = root .. "/build"
os.execute("mkdir -p '" .. BUILD .. "'")

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
  if a ~= b then
    a, b = tostring(a), tostring(b)
    if #a > 200 or #b > 200 then
      -- longs textes (états sérialisés) : autour du premier écart
      local i = 1
      while i <= #a and a:sub(i, i) == b:sub(i, i) do i = i + 1 end
      a, b = "…" .. a:sub(math.max(1, i - 120), i + 80), "…" .. b:sub(math.max(1, i - 120), i + 80)
    end
    error((msg or "") .. " attendu " .. b .. ", obtenu " .. a, 2)
  end
end

-- Sérialisation à clés triées (deux états égaux donnent le même texte).
local function ser(v, out)
  local t = type(v)
  if t == "number" then out[#out + 1] = string.format("%.17g", v)
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "boolean" or t == "nil" then out[#out + 1] = tostring(v)
  else
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      if type(a) ~= type(b) then return type(a) < type(b) end
      if type(a) == "boolean" then return (a and 1 or 0) < (b and 1 or 0) end
      return a < b
    end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      out[#out + 1] = "["; ser(k, out); out[#out + 1] = "]="; ser(v[k], out); out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  end
end
local function serialize(v) local o = {}; ser(v, o); return table.concat(o) end

-- État de jeu comparable : sans ce qui ne sert qu'au journal et aux statistiques de simulation.
local function canon(exp)
  local e = U.copy(exp)
  -- banked : ce que la méta a reçu (Save.settle / Save.finish, hors du rejeu)
  e.quiet, e.combatStats, e.banked = nil, nil, nil
  if e.combat then e.combat.quiet, e.combat.events, e.combat.stats = nil, nil, nil end
  return serialize(e)
end

-- Aller-retour par le format SavedVariables (fichier écrit puis relu, comme au /reload).
local function roundTrip(db, name)
  local path = BUILD .. "/" .. name .. ".lua"
  local f = assert(io.open(path, "w"))
  f:write(RP.savedText("SlayTheDragonDB", db))
  f:close()
  return assert(RP.loadSaved(path)), path
end

-- Expédition jouée par un bot (Sim/expedition.lua) à travers Save.act : même chemin que l'interface.
local function botRun(o)
  local db = Save.new()
  o.act = function(_, a) return Save.act(db, a) end
  o.onNew = function(exp, xopts)
    db.current = exp
    R.begin(db, exp, xopts, { date = "2026-11-19 12:00", addon = "test" })
  end
  local _, exp = SE.play(o)
  return db, exp
end

---------------------------------------------------------------------------

test("codage des actions : aller-retour, trous nil, refus, notes", function()
  local cases = { { "play", 3, nil, "nospend" }, { "endTurn" }, { "endTurn", 17 }, { "path", 12 },
    { "campAction", "drink_rum" }, { "potion", 2, 1 }, { "play", 1, 2 } }
  for _, a in ipairs(cases) do
    local s = R.encode(a)
    eq(type(s), "string", "chaîne")
    local b, ok = R.decode(s)
    eq(ok, true)
    eq(serialize(b), serialize(a), s)
    local c, ok2 = R.decode("!" .. s)
    eq(ok2, false); eq(serialize(c), serialize(a))
  end
  eq(R.encode({ "play", 3, nil, "nospend" }), "play 3 _ nospend")
  -- chaîne qui ne s'écrit pas en mot : table gardée telle quelle
  local odd = { "campAction", "two words" }
  local t = R.encode(odd)
  eq(type(t), "table"); eq(serialize((R.decode(t))), serialize(odd))
  eq(type(R.encode({ "campAction", "inf" })), "table", "« inf » lu comme un nombre")
  local a, ok, note = R.decode("@dev gnoll gnoll")
  eq(a, nil); eq(ok, true); eq(note, "@dev gnoll gnoll")
end)

local runs = {
  { class = "warrior", seed = 3, bot = "human", zones = 2, tree = 100 },
  { class = "priest", seed = 5, bot = "human", zones = 0, level = 1 },
  { class = "rogue", seed = 8, bot = "human", zones = 4 },
}
local measured

for _, o in ipairs(runs) do
  test(("expédition d'un bot enregistrée puis rejouée depuis le fichier (%s, graine %d)"):format(o.class, o.seed), function()
    local opts = { class = o.class, seed = o.seed, bot = o.bot, zones = o.zones, level = o.level, key = 0 }
    if o.tree then opts.talents, opts.spec = ns.Talent.fromShare(o.class, o.tree) end
    local db, exp = botRun(opts)
    eq(exp.phase, "done")
    local rec = db.records[1]
    eq(#db.records, 1); eq(rec.live, true); eq(rec.result, exp.result)
    assert(#rec.a > 50, "actions enregistrées")
    assert(#rec.cp >= 2, "points de contrôle")
    if o.tree then assert(next(rec.start.unlocks.talents), "talents gardés au départ") end
    Save.finish(db, "2026-11-19 13:00")
    eq(rec.live, nil); eq(rec.ended, "2026-11-19 13:00")
    assert(Save.validate(db))
    local back, path = roundTrip(db, "replay_" .. o.class)
    assert(Save.validate(back))
    local res = R.replay(back.records[1])
    assert(not res.diverged, res.diverged and res.diverged.why)
    eq(res.cps, #rec.cp, "tous les points de contrôle vérifiés")
    eq(canon(res.exp), canon(exp), "même état final")
    -- le récit complet se construit sans erreur et finit par la fin de l'expédition
    local lines = {}
    local res2 = RP.narrate(back.records[1], function(s) lines[#lines + 1] = s end, { bot = o.class == "warrior" and "human" or nil })
    assert(not res2.diverged)
    assert(table.concat(lines, "\n"):find("Fin de l'expédition", 1, true), "fin racontée")
    assert(table.concat(lines, "\n"):find("intention", 1, true), "intentions racontées")
    if o.class == "warrior" then
      assert(table.concat(lines, "\n"):find("jouerait", 1, true), "conseil du bot")
      -- taille d'une expédition complète dans le fichier
      local one = RP.savedText("SlayTheDragonDB", { records = { rec } })
      measured = ("%d actions, %d points de contrôle, %d octets dans le fichier (%s, %s)"):format(#rec.a, #rec.cp,
        #one, exp.result, exp.zone)
    end
    -- rejeu dans l'autre interpréteur (ordre des tables de hachage différent) : même partie
    local other = jit and "lua5.1" or "luajit"
    local p = io.popen(other .. " " .. root .. "/Sim/replay.lua " .. path .. " 2>&1")
    local text = p and p:read("*a") or ""
    if p then p:close() end
    if text:find("not found", 1, true) or text == "" then
      print("  (" .. other .. " absent : rejeu croisé non vérifié)")
    else
      assert(text:find("Rejeu complet", 1, true), other .. " : " .. text:sub(-400))
    end
  end)
end

test("action altérée : le rejeu s'arrête au premier écart ; point de contrôle faux détecté", function()
  local db, exp = botRun({ class = "warrior", seed = 3, bot = "human", zones = 2 })
  local rec = db.records[1]
  -- une carte de récompense refusée au lieu de prise
  local k
  for i, s in ipairs(rec.a) do
    if type(s) == "string" and s:match("^pickCard ") then k = i break end
  end
  assert(k, "une carte prise")
  local bad = U.copy(rec)
  bad.a[k] = "skipCards"
  local res = R.replay(bad)
  assert(res.diverged, "divergence détectée")
  assert(res.diverged.i >= k, "pas avant l'action altérée")
  -- le point de contrôle qui suit ne correspond plus (deck d'une carte de moins), à moins qu'un coup soit
  -- refusé avant (main différente)
  local why = res.diverged.why
  assert(why:find("checkpoint", 1, true) or why:find("refused", 1, true), why)
  -- point de contrôle falsifié : signalé à son action
  local bad2 = U.copy(rec)
  bad2.cp[2].hp = bad2.cp[2].hp + 1
  local res2 = R.replay(bad2)
  assert(res2.diverged, "divergence")
  eq(res2.diverged.i, bad2.cp[2].n); eq(res2.diverged.why, "checkpoint hp differs")
  eq(res2.cps, 1)
  assert(RP.divergence(bad2, res2):find("DIVERGENCE", 1, true))
  -- action ajoutée en trop : refusée au rejeu, acceptée à l'enregistrement
  local bad3 = U.copy(rec)
  table.insert(bad3.a, 1, "path 9999")
  local res3 = R.replay(bad3)
  eq(res3.diverged and res3.diverged.i, 1)
  eq(canon(R.replay(rec).exp), canon(exp), "l'original rejoue toujours")
end)

-- Politique au hasard (flux à graine) sur Expedition.choices : couvre marchand, potions, rencontres…
local function randomStep(db, rng)
  local exp = db.current
  local ch = X.choices(exp)
  local a = ch[Rng.int(rng, 1, #ch)]
  -- évite de jeter les potions en boucle et d'errer au marchand
  if a[1] == "discardPotion" and Rng.float(rng) < 0.9 then a = ch[1] end
  return Save.act(db, a)
end

test("rechargements (/reload) pendant la partie : le rejeu redonne la même partie", function()
  local db = Save.new()
  local exp = assert(Save.start(db, { seed = 77, class = "mage" }, { date = "d", addon = "test" }))
  exp.quiet = false
  local rng = Rng.stream(77, "policy")
  local reloads = 0
  for step = 1, 4000 do
    if not db.current or db.current.phase == "done" then break end
    randomStep(db, rng)
    if step % 23 == 0 then
      db = roundTrip(db, "replay_reload")
      reloads = reloads + 1
    end
  end
  assert(reloads >= 2, "rechargé")
  local cur = db.current
  local rec = db.records[#db.records]
  assert(R.live(db) == rec, "enregistrement toujours lié à l'expédition après rechargement")
  local res = R.replay(rec)
  assert(not res.diverged, res.diverged and res.diverged.why)
  eq(canon(res.exp), canon(cur), "même état")
end)

test("expédition interrompue en plein combat : rejouable jusqu'au dernier coup, puis reprise", function()
  local db = Save.new()
  local exp = assert(Save.start(db, { seed = 41, class = "hunter" }, { date = "d", addon = "test" }))
  local rng = Rng.stream(41, "policy")
  local fights = 0
  local last
  for _ = 1, 4000 do
    exp = db.current
    if exp.phase == "combat" and exp.combat ~= last then
      last = exp.combat
      fights = fights + 1
    end
    if fights >= 3 and exp.phase == "combat" and exp.combat.round >= 2 and exp.combat.turn.played >= 1 then break end
    if exp.phase == "combat" then
      -- joue une carte si possible, sinon fin du tour
      local ch = X.choices(exp)
      local a = #ch > 1 and Rng.float(rng) < 0.8 and ch[1] or { "endTurn" }
      Save.act(db, a)
    else
      randomStep(db, rng)
    end
    assert(db.current and db.current.phase ~= "done", "expédition finie trop tôt")
  end
  eq(db.current.phase, "combat")
  local back = roundTrip(db, "replay_interrupted")
  local rec = back.records[#back.records]
  eq(rec.live, true); eq(rec.result, nil)
  local res = R.replay(rec)
  assert(not res.diverged, res.diverged and res.diverged.why)
  eq(canon(res.exp), canon(back.current), "même combat en cours")
  local lines = {}
  RP.narrate(rec, function(s) lines[#lines + 1] = s end)
  assert(lines[#lines]:find("^%s+") , "le récit va jusqu'au dernier coup")
  -- la partie reprend après le rechargement et l'enregistrement continue
  local n0 = #rec.a
  for _ = 1, 3000 do
    if back.current.phase == "done" then break end
    randomStep(back, rng)
  end
  Save.abandon(back, "fin")
  assert(#rec.a > n0)
  eq(rec.live, nil); assert(rec.result)
  local res2 = R.replay(rec)
  assert(not res2.diverged, res2.diverged and res2.diverged.why)
  eq(res2.exp.phase, "done")
end)

test("borne : 20 expéditions gardées, l'expédition en cours comprise, la plus ancienne retirée", function()
  local db = Save.new()
  for i = 1, 25 do
    assert(Save.start(db, { seed = 100 + i, class = "priest" }, { date = "d" .. i }))
    Save.act(db, X.choices(db.current)[1])
    if i < 25 then Save.abandon(db, "f" .. i) end
  end
  eq(#db.records, R.MAX); eq(R.MAX, 20)
  eq(db.records[1].seed, 106, "les 5 plus anciennes retirées")
  eq(db.records[20].seed, 125); eq(db.records[20].live, true)
  eq(db.records[19].live, nil); eq(db.records[19].result, "abandoned")
  for i = 1, 19 do eq(db.records[i].a[#db.records[i].a], "abandon") end
  assert(Save.validate(db))
  -- une liste trop longue lue du fichier est ramenée à la borne ; entrées illisibles retirées
  local back = roundTrip(db, "replay_bound")
  table.insert(back.records, 1, "bogus")
  table.insert(back.records, 1, { a = {}, cp = {}, start = { class = "priest" } })
  back.records[3].live = true
  Save.normalize(back)
  eq(#back.records, 20); eq(back.records[20].seed, 125)
  for i = 1, 19 do eq(back.records[i].live, nil) end
  eq(back.records[20].live, true)
  assert(Save.validate(back))
  local bad = U.copy(back)
  bad.records[21] = U.copy(bad.records[1])
  assert(not Save.validate(bad), "plus de 20 refusé")
end)

test("migration v8 -> v9 : db.records créé ; une expédition en cours d'avant n'est pas enregistrée", function()
  local db = Save.new()
  assert(Save.start(db, { seed = 9, class = "warrior" }))
  db.records = nil
  db.version = 8
  local m, note = Save.migrate(roundTrip(db, "replay_v8"))
  eq(note, "migrated"); eq(m.version, 9); eq(Save.VERSION, 9)
  eq(type(m.records), "table"); eq(#m.records, 0)
  assert(Save.validate(m))
  assert(m.current, "expédition gardée")
  eq(R.live(m), nil)
  assert(Save.act(m, X.choices(m.current)[1]), "on joue sans enregistrement")
  eq(#m.records, 0)
  Save.abandon(m, "f")
  eq(#m.records, 0)
  assert(Save.start(m, { seed = 10, class = "warrior" }, { date = "d" }))
  eq(#m.records, 1); eq(m.records[1].live, true)
  Save.settle(m)
  local again = U.copy(m)
  Save.migrate(again)
  eq(serialize(again), serialize(m), "migration idempotente")
  -- quarantaine : l'enregistrement est fermé
  Save.quarantine(m, "test")
  eq(m.records[1].live, nil); eq(m.records[1].result, "quarantined")
end)

test("fin de tour avec carte gardée : le choix fait partie de l'action", function()
  local exp = X.new({ seed = 4, class = "priest", quiet = true })
  if exp.phase == "start" then assert(X.act(exp, { "skipStartRelic" })) end
  local id = exp.map.start[1]
  exp.map.nodes[id].kind = "combat"
  assert(X.act(exp, { "path", id }))
  local ok, why = X.act(exp, { "endTurn", 999999 })
  eq(ok, false); eq(why, "keep", "sans Traveler's Backpack : refus")
  assert(X.act(exp, { "endTurn" }))
end)

if measured then print("Taille mesurée (expédition complète, warrior bot human) : " .. measured) end
print(("%d réussis, %d échoués"):format(passed, failed))
if failed == 0 then print("ALL PASS") else os.exit(1) end
