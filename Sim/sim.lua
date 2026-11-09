-- Simulation d'expéditions en masse.
-- Usage : luajit Sim/sim.lua runs=2000 bot=heuristic seed=1 jobs=16 pick=rated cap=400
--         [force=penance,mind_blast] [save=rapport.lua] [compare=ancien.lua]
--   bot  : random | greedy | heuristic        pick : rated | random | skip
--   save : écrit les agrégats bruts (pour une comparaison avant/après avec compare=)
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."

local opts = {}
for _, a in ipairs(arg or {}) do
  local k, v = a:match("^([%w_]+)=(.*)$")
  if k then opts[k] = v end
end
local runs = tonumber(opts.runs or 200)
local seed0 = tonumber(opts.seed or 1)
local jobs = tonumber(opts.jobs or 1)
local force = {}
if opts.force and opts.force ~= "" then
  for id in opts.force:gmatch("[^,]+") do force[#force + 1] = id end
end

---------------------------------------------------------------------------
-- Sérialisation (échange entre processus et fichiers save=)
---------------------------------------------------------------------------
local function ser(v, out)
  local t = type(v)
  if t == "number" then out[#out + 1] = string.format("%.17g", v)
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "boolean" then out[#out + 1] = tostring(v)
  elseif t == "table" then
    out[#out + 1] = "{"
    for k, x in pairs(v) do
      out[#out + 1] = "["
      ser(k, out)
      out[#out + 1] = "]="
      ser(x, out)
      out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  else out[#out + 1] = "nil" end
end
local function serialize(v) local o = {}; ser(v, o); return table.concat(o) end
local function deserialize(s) return assert(loadstring("return " .. s))() end

---------------------------------------------------------------------------
-- Agrégats
---------------------------------------------------------------------------
local function newAgg()
  return { runs = 0, wins = 0, floors = {}, hpEndWin = 0, elapsed = 0,
    enc = {}, cards = {}, kinds = {},
    castsStarted = 0, castsInterrupted = 0, enemyCasts = 0, enemyCastsInterrupted = 0 }
end

local function addRecord(agg, rec)
  agg.runs = agg.runs + 1
  if rec.won then
    agg.wins = agg.wins + 1
    agg.hpEndWin = agg.hpEndWin + rec.hp
  end
  agg.floors[rec.floor] = (agg.floors[rec.floor] or 0) + (rec.won and 0 or 1)
  for _, cb in ipairs(rec.combats) do
    local e = agg.enc[cb.encounter]
    if not e then
      e = { kind = cb.kind, n = 0, won = 0, turns = 0, turnsHist = {}, hpLost = 0, stalled = 0 }
      agg.enc[cb.encounter] = e
    end
    e.n = e.n + 1
    if cb.won then e.won = e.won + 1 end
    e.turns = e.turns + cb.turns
    e.turnsHist[cb.turns] = (e.turnsHist[cb.turns] or 0) + 1
    e.hpLost = e.hpLost + cb.hpLost
    if cb.stalled then e.stalled = e.stalled + 1 end
    local k = agg.kinds[cb.kind] or { n = 0, won = 0, turns = 0, hpLost = 0 }
    agg.kinds[cb.kind] = k
    k.n = k.n + 1; k.turns = k.turns + cb.turns; k.hpLost = k.hpLost + cb.hpLost
    if cb.won then k.won = k.won + 1 end
    agg.castsStarted = agg.castsStarted + cb.castsStarted
    agg.castsInterrupted = agg.castsInterrupted + cb.castsInterrupted
    agg.enemyCasts = agg.enemyCasts + cb.enemyCasts
    agg.enemyCastsInterrupted = agg.enemyCastsInterrupted + cb.enemyCastsInterrupted
    for id, n in pairs(cb.played) do
      local cs = agg.cards[id] or { played = 0, drawn = 0, unplayed = 0, inDeck = 0, inDeckWins = 0, picked = 0 }
      agg.cards[id] = cs
      cs.played = cs.played + n
    end
    for id, n in pairs(cb.drawn) do
      local cs = agg.cards[id] or { played = 0, drawn = 0, unplayed = 0, inDeck = 0, inDeckWins = 0, picked = 0 }
      agg.cards[id] = cs
      cs.drawn = cs.drawn + n
    end
    for id, n in pairs(cb.unplayed) do
      local cs = agg.cards[id] or { played = 0, drawn = 0, unplayed = 0, inDeck = 0, inDeckWins = 0, picked = 0 }
      agg.cards[id] = cs
      cs.unplayed = cs.unplayed + n
    end
  end
  local seen = {}
  for _, card in ipairs(rec.deck or {}) do
    if not seen[card.id] then
      seen[card.id] = true
      local cs = agg.cards[card.id] or { played = 0, drawn = 0, unplayed = 0, inDeck = 0, inDeckWins = 0, picked = 0 }
      agg.cards[card.id] = cs
      cs.inDeck = cs.inDeck + 1
      if rec.won then cs.inDeckWins = cs.inDeckWins + 1 end
    end
  end
  for _, p in ipairs(rec.picks or {}) do
    local cs = agg.cards[p]
    if cs then cs.picked = cs.picked + 1 end
  end
end

local function mergeInto(a, b)
  for k, v in pairs(b) do
    if type(v) == "number" then
      a[k] = (a[k] or 0) + v
    elseif type(v) == "table" then
      a[k] = a[k] or {}
      mergeInto(a[k], v)
    else
      a[k] = v
    end
  end
end

---------------------------------------------------------------------------
-- Exécution
---------------------------------------------------------------------------
local function runRange(from, to)
  local ns = dofile(root .. "/Sim/load.lua")(root)
  local agg = newAgg()
  for i = from, to do
    local rec = ns.Run.play({ seed = seed0 * 1000003 + i, bot = opts.bot or "heuristic",
      pick = opts.pick or "rated", force = force, cap = tonumber(opts.cap or 400) })
    addRecord(agg, rec)
  end
  return agg
end

if opts.worker then
  io.write(serialize(runRange(tonumber(opts.from), tonumber(opts.to))))
  return
end

local t0 = os.time()
local clock0 = os.clock()
local agg
if jobs <= 1 then
  agg = runRange(1, runs)
else
  local exe = opts.exe or "luajit"
  local pipes = {}
  local per = math.ceil(runs / jobs)
  local passthrough = {}
  for k, v in pairs(opts) do
    if k ~= "jobs" and k ~= "save" and k ~= "compare" and k ~= "runs" then
      passthrough[#passthrough + 1] = k .. "=" .. v
    end
  end
  local extra = table.concat(passthrough, " ")
  for j = 1, jobs do
    local from, to = (j - 1) * per + 1, math.min(runs, j * per)
    if from <= to then
      local cmd = string.format("%s %s/Sim/sim.lua worker=1 from=%d to=%d %s", exe, root, from, to, extra)
      pipes[#pipes + 1] = assert(io.popen(cmd, "r"))
    end
  end
  agg = newAgg()
  for _, p in ipairs(pipes) do
    local out = p:read("*a")
    p:close()
    mergeInto(agg, deserialize(out))
  end
end
local elapsed = os.time() - t0

---------------------------------------------------------------------------
-- Rapport
---------------------------------------------------------------------------
local ns = dofile(root .. "/Sim/load.lua")(root)
local function pct(a, b) if b == 0 then return "  -  " end return string.format("%5.1f %%", 100 * a / b) end
local function p95(hist, n)
  local keys = {}
  for k in pairs(hist) do keys[#keys + 1] = k end
  table.sort(keys)
  local acc = 0
  for _, k in ipairs(keys) do
    acc = acc + hist[k]
    if acc >= 0.95 * n then return k end
  end
  return keys[#keys] or 0
end

local function report(a, title)
  local lines = {}
  local function out(s) lines[#lines + 1] = s end
  local se = math.sqrt(math.max(a.wins * (a.runs - a.wins), 1) / a.runs) / a.runs * 100
  out(("== %s =="):format(title))
  out(("Expéditions : %d   bot : %s   choix : %s   graine : %d%s"):format(a.runs, opts.bot or "heuristic",
    opts.pick or "rated", seed0, #force > 0 and ("   forcées : " .. table.concat(force, ",")) or ""))
  out(("Victoires   : %s (± %.1f)   PV moyens à la victoire : %.1f"):format(pct(a.wins, a.runs), 1.96 * se,
    a.wins > 0 and a.hpEndWin / a.wins or 0))
  local deaths = {}
  for f, n in pairs(a.floors) do if n > 0 then deaths[#deaths + 1] = ("étape %d : %d"):format(f, n) end end
  table.sort(deaths)
  out("Défaites    : " .. table.concat(deaths, ", "))
  out("")
  out("Par type de combat        n   victoires  tours moy  PV perdus moy")
  for _, k in ipairs({ "easy", "normal", "elite", "boss" }) do
    local s = a.kinds[k]
    if s then
      out(("  %-20s %6d   %s   %8.2f   %8.1f"):format(k, s.n, pct(s.won, s.n), s.turns / s.n, s.hpLost / s.n))
    end
  end
  out("")
  out("Par rencontre                                   n   victoires  tours moy  p95  PV perdus  bloqués")
  local encs = {}
  for name, e in pairs(a.enc) do encs[#encs + 1] = { name = name, e = e } end
  table.sort(encs, function(x, y) if x.e.kind ~= y.e.kind then return x.e.kind < y.e.kind end return x.name < y.name end)
  for _, x in ipairs(encs) do
    local e = x.e
    out(("  %-7s %-35s %6d   %s   %8.2f  %3d  %9.1f  %5d"):format(e.kind, x.name, e.n, pct(e.won, e.n),
      e.turns / e.n, p95(e.turnsHist, e.n), e.hpLost / e.n, e.stalled))
  end
  out("")
  out("Cartes                      choisie  dans deck  vict. avec  vict. sans  jouées/piochées  gardées en main")
  local ids = {}
  for id in pairs(a.cards) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local cs = a.cards[id]
    local without = a.runs - cs.inDeck
    local winsWithout = a.wins - cs.inDeckWins
    out(("  %-26s %7d  %9d  %s     %s     %s          %s"):format(id, cs.picked, cs.inDeck,
      pct(cs.inDeckWins, cs.inDeck), pct(winsWithout, without), pct(cs.played, cs.drawn), pct(cs.unplayed, cs.drawn)))
  end
  out("")
  out(("Incantations du joueur : %d, interrompues : %s"):format(a.castsStarted, pct(a.castsInterrupted, a.castsStarted)))
  out(("Sorts ennemis : %d, interrompus par le joueur : %s"):format(a.enemyCasts, pct(a.enemyCastsInterrupted, a.enemyCasts)))
  out(("Durée : %d s (CPU du parent %.1f s)"):format(elapsed, os.clock() - clock0))
  return table.concat(lines, "\n")
end

print(report(agg, "Slay the Dragon — simulation"))

if opts.save then
  local f = assert(io.open(opts.save, "w"))
  f:write(serialize(agg))
  f:close()
  print("Agrégats enregistrés dans " .. opts.save)
end

if opts.compare then
  local f = assert(io.open(opts.compare, "r"))
  local old = deserialize(f:read("*a"))
  f:close()
  print("")
  print("== Comparaison avec " .. opts.compare .. " ==")
  print(("Victoires : %s -> %s"):format(pct(old.wins, old.runs), pct(agg.wins, agg.runs)))
  for _, k in ipairs({ "easy", "normal", "elite", "boss" }) do
    local o, n = old.kinds[k], agg.kinds[k]
    if o and n then
      print(("  %-8s victoires %s -> %s   tours %.2f -> %.2f   PV perdus %.1f -> %.1f"):format(k,
        pct(o.won, o.n), pct(n.won, n.n), o.turns / o.n, n.turns / n.n, o.hpLost / o.n, n.hpLost / n.n))
    end
  end
end
