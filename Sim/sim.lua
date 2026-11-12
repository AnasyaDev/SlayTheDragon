-- Simulation d'expéditions en masse.
-- Usage : luajit Sim/sim.lua runs=2000 bot=heuristic seed=1 jobs=8 pick=rated cap=400 [class=priest|warrior]
--         [force=penance,mind_blast] [save=rapport.lua] [compare=ancien.lua]
--   bot  : random | greedy | heuristic        pick : rated | random | skip
--   save : écrit les agrégats bruts (pour une comparaison avant/après avec compare=)
--   runner=expedition : vraie expédition (Core/Expedition, carte, marchand, rencontres…)
--     avec key=N (clé mythique) et zones=0..7 (zones gagnées par le compte et la classe, à toutes les clés :
--     commun, cartes de zone, bibelots de clé ; drapeaux d'histoire d'un vétéran dès 1) ; meta=start et
--     meta=exalted restent des alias de zones=0 et zones=7 ; zone=<id> : zone jouée (défaut : la première)
--   level=1..7 : niveau de classe (cartes et bibelots de classe débloqués) ; défaut 7 avec
--     runner=expedition (tout débloqué, les mesures d'avant la progression par classe), toutes les cartes sinon
--   tier=0..7 : bibelots/potions communs débloqués (palier commun : zones gagnées par le compte ; défaut : tous)
--   relics=id,id : bibelots dès le départ        loot=0 : ni bibelot ni potion gagnés
--   nointerrupt=1 : monde témoin où les ennemis n'interrompent jamais
--   sweep=cards [only=id,id] : mesure chaque carte de la réserve, ajoutée de force au deck de départ,
--                 contre la même série sans elle (mêmes graines) ; sweep=relics de même ; only= accepte
--                 aussi des cartes hors réserve (neutres).
--   oldstun=1 : ancienne règle de Stunned pendant le tour ennemi (l'action part, le tour suivant est perdu)
--   hp=N : PV de départ de la classe remplacés (runner=expedition), pour mesurer l'effet des PV.
--   path=<voie> : récompenses de cartes limitées à une voie de la classe (runner=expedition), voie seule.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."

local opts = {}
for _, a in ipairs(arg or {}) do
  local k, v = a:match("^([%w_]+)=(.*)$")
  if k then opts[k] = v end
end
local runs = tonumber(opts.runs or 200)
local seed0 = tonumber(opts.seed or 1)
local jobs = tonumber(opts.jobs or 1)
local function idList(s)
  local list = {}
  if s and s ~= "" then
    for id in s:gmatch("[^,]+") do list[#list + 1] = id end
  end
  return list
end
local force = idList(opts.force)
local startRelics = idList(opts.relics)

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
    enc = {}, cards = {}, kinds = {}, potions = {}, relics = {},
    castsStarted = 0, castsInterrupted = 0, enemyCasts = 0, enemyCastsInterrupted = 0,
    goldEarned = 0, goldSpent = 0, goldEnd = 0, xp = 0, xpWin = 0, xpLoss = 0, cleared = 0, removed = 0, upgraded = 0,
    visits = {} }
end

local function addRecord(agg, rec)
  agg.runs = agg.runs + 1
  if rec.won then
    agg.wins = agg.wins + 1
    agg.hpEndWin = agg.hpEndWin + rec.hp
  end
  agg.floors[rec.floor] = (agg.floors[rec.floor] or 0) + (rec.won and 0 or 1)
  if rec.visits then
    agg.goldEarned = agg.goldEarned + rec.goldEarned
    agg.goldSpent = agg.goldSpent + rec.goldSpent
    agg.goldEnd = agg.goldEnd + rec.gold
    agg.xp = agg.xp + (rec.xp or 0)
    if rec.won then agg.xpWin = agg.xpWin + (rec.xp or 0) else agg.xpLoss = agg.xpLoss + (rec.xp or 0) end
    agg.cleared = agg.cleared + rec.cleared
    agg.removed = agg.removed + rec.removed
    agg.upgraded = agg.upgraded + rec.upgraded
    for k, n in pairs(rec.visits) do agg.visits[k] = (agg.visits[k] or 0) + n end
  end
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
    for key, n in pairs(cb.castStats or {}) do
      agg.castStats = agg.castStats or {}
      agg.castStats[key] = (agg.castStats[key] or 0) + n
    end
    k.castsStarted = (k.castsStarted or 0) + cb.castsStarted
    k.castsInterrupted = (k.castsInterrupted or 0) + cb.castsInterrupted
    for id, n in pairs(cb.potions or {}) do
      local ps = agg.potions[id] or {}
      agg.potions[id] = ps
      ps[cb.kind] = (ps[cb.kind] or 0) + n
    end
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
  for _, id in ipairs(rec.relics or {}) do
    local rs = agg.relics[id] or { n = 0, wins = 0 }
    agg.relics[id] = rs
    rs.n = rs.n + 1
    if rec.won then rs.wins = rs.wins + 1 end
  end
  -- Rencontres vues (runner=expedition) : fréquence, victoires, réponses choisies.
  for id, ci in pairs(rec.events or {}) do
    agg.events = agg.events or {}
    local es = agg.events[id] or { n = 0, wins = 0, choices = {} }
    agg.events[id] = es
    es.n = es.n + 1
    if rec.won then es.wins = es.wins + 1 end
    es.choices[ci] = (es.choices[ci] or 0) + 1
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
  if opts.oldstun == "1" then ns.Combat.STUN_STOPS_TURN = false end
  if opts.nointerrupt == "1" then
    -- Monde témoin sans interruption ennemie : mesure le poids des interruptions.
    for _, def in pairs(ns.Enemies) do
      for _, mv in pairs(def.moves) do
        for _, a in ipairs(mv.actions) do a.interrupts = nil end
      end
    end
    ns.Combat.interruptPlayer = function() end
  end
  local agg = newAgg()
  for i = from, to do
    local rec
    if opts.runner == "expedition" then
      rec = ns.SimExpedition.play({ seed = seed0 * 1000003 + i, bot = opts.bot or "heuristic",
        pick = opts.pick or "rated", cap = tonumber(opts.cap or 400), key = tonumber(opts.key or 0),
        meta = opts.meta or "start", class = opts.class, force = force, level = tonumber(opts.level),
        hp = tonumber(opts.hp), path = opts.path, zones = tonumber(opts.zones), zone = opts.zone })
    else
      rec = ns.Run.play({ seed = seed0 * 1000003 + i, bot = opts.bot or "heuristic",
        pick = opts.pick or "rated", force = force, cap = tonumber(opts.cap or 400),
        level = tonumber(opts.level), tier = tonumber(opts.tier), relics = startRelics,
        loot = opts.loot ~= "0", class = opts.class })
    end
    addRecord(agg, rec)
  end
  return agg
end

if opts.worker then
  io.write(serialize(runRange(tonumber(opts.from), tonumber(opts.to))))
  return
end

-- Lance la série complète ; over remplace des options (force=, relics=) le temps de la série.
local function runAll(over)
  over = over or {}
  if jobs <= 1 then
    local f0, r0 = force, startRelics
    if over.force then force = idList(over.force) end
    if over.relics then startRelics = idList(over.relics) end
    local a = runRange(1, runs)
    force, startRelics = f0, r0
    return a
  end
  local exe = opts.exe or "luajit"
  local pipes = {}
  local per = math.ceil(runs / jobs)
  local passthrough = {}
  for k, v in pairs(opts) do
    if k ~= "jobs" and k ~= "save" and k ~= "compare" and k ~= "runs" and k ~= "sweep"
        and over[k] == nil then
      passthrough[#passthrough + 1] = k .. "=" .. v
    end
  end
  for k, v in pairs(over) do passthrough[#passthrough + 1] = k .. "=" .. v end
  local extra = table.concat(passthrough, " ")
  for j = 1, jobs do
    local from, to = (j - 1) * per + 1, math.min(runs, j * per)
    if from <= to then
      local cmd = string.format("%s %s/Sim/sim.lua worker=1 from=%d to=%d %s", exe, root, from, to, extra)
      pipes[#pipes + 1] = assert(io.popen(cmd, "r"))
    end
  end
  local a = newAgg()
  for _, p in ipairs(pipes) do
    local out = p:read("*a")
    p:close()
    mergeInto(a, deserialize(out))
  end
  return a
end

local t0 = os.time()
local clock0 = os.clock()

if opts.sweep then
  -- Effet de chaque carte (ou bibelot) ajouté au départ, à graines identiques.
  local ns = dofile(root .. "/Sim/load.lua")(root)
  local list = {}
  if opts.sweep == "relics" then
    for id in pairs(ns.Relics) do list[#list + 1] = id end
  else
    list = ns.Rewards.cardPool(opts.class or "priest", tonumber(opts.level))
  end
  if opts.only then
    -- only=id,id : ne mesure que ces éléments, même hors de la réserve des récompenses (cartes neutres :
    -- only=rough_dynamite,heavy_silk_bandage…).
    local l2 = {}
    for _, id in ipairs(idList(opts.only)) do
      local def = opts.sweep == "relics" and ns.Relics[id] or ns.Cards[id]
      assert(def, "only= : élément inconnu " .. id)
      l2[#l2 + 1] = id
    end
    list = l2
  end
  table.sort(list, function(x, y)
    local dx = opts.sweep == "relics" and ns.Relics[x] or ns.Cards[x]
    local dy = opts.sweep == "relics" and ns.Relics[y] or ns.Cards[y]
    if dx.rarity ~= dy.rarity then return dx.rarity < dy.rarity end
    return x < y
  end)
  local base = runAll({})
  local function line(name, rarity, a)
    local parts = {}
    for _, k in ipairs({ "easy", "normal", "elite", "boss" }) do
      local s = a.kinds[k]
      parts[#parts + 1] = s and ("%5.1f/%4.1f"):format(s.turns / s.n, s.hpLost / s.n) or "     -    "
    end
    local cs = a.cards[name]
    local use = cs and cs.drawn > 0 and ("%5.1f %%"):format(100 * cs.played / cs.drawn) or "   -   "
    return ("  %-22s %-9s %5.1f %%  %+6.1f   %s   %s"):format(name, rarity, 100 * a.wins / a.runs,
      100 * (a.wins - base.wins) / a.runs, table.concat(parts, "  "), use)
  end
  print(("== Balayage %s : %d expéditions par ligne, bot %s, choix %s =="):format(opts.sweep, runs,
    opts.bot or "heuristic", opts.pick or "rated"))
  print("  élément                rareté    vict.   écart   facile t/PV  normal t/PV  élite t/PV   boss t/PV    jouée")
  print(line("(sans)", "-", base))
  local rows = {}
  for _, id in ipairs(list) do
    local over = {}
    if opts.sweep == "relics" then
      local rl = {}
      for _, r in ipairs(startRelics) do rl[#rl + 1] = r end
      rl[#rl + 1] = id
      over.relics = table.concat(rl, ",")
    else
      local fl = {}
      for _, f in ipairs(force) do fl[#fl + 1] = f end
      fl[#fl + 1] = id
      over.force = table.concat(fl, ",")
    end
    local a = runAll(over)
    local def = opts.sweep == "relics" and ns.Relics[id] or ns.Cards[id]
    print(line(id, def.rarity, a))
    io.stdout:flush()
    rows[id] = { wins = a.wins, runs = a.runs }
  end
  if opts.save then
    local f = assert(io.open(opts.save, "w"))
    f:write(serialize({ base = { wins = base.wins, runs = base.runs }, rows = rows }))
    f:close()
    print("Balayage enregistré dans " .. opts.save)
  end
  print(("Durée : %d s"):format(os.time() - t0))
  return
end

local agg = runAll({})
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
  out(("Expéditions : %d   classe : %s   bot : %s   choix : %s   graine : %d%s"):format(a.runs, opts.class or "priest", opts.bot or "heuristic",
    opts.pick or "rated", seed0, #force > 0 and ("   forcées : " .. table.concat(force, ",")) or ""))
  out(("Victoires   : %s (± %.1f)   PV moyens à la victoire : %.1f"):format(pct(a.wins, a.runs), 1.96 * se,
    a.wins > 0 and a.hpEndWin / a.wins or 0))
  local deaths = {}
  for f, n in pairs(a.floors) do if n > 0 then deaths[#deaths + 1] = ("étape %d : %d"):format(f, n) end end
  table.sort(deaths)
  out("Défaites    : " .. table.concat(deaths, ", "))
  out("")
  out("Par type de combat        n   victoires  tours moy  PV perdus moy  incant./combat  coupées")
  for _, k in ipairs({ "easy", "normal", "elite", "boss" }) do
    local s = a.kinds[k]
    if s then
      out(("  %-20s %6d   %s   %8.2f   %8.1f   %12.2f   %s"):format(k, s.n, pct(s.won, s.n), s.turns / s.n,
        s.hpLost / s.n, (s.castsStarted or 0) / s.n, pct(s.castsInterrupted or 0, s.castsStarted or 0)))
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
  out("Cartes                   rareté    choisie  dans deck  vict. avec  vict. sans  écart  jouées/piochées  gardées en main")
  local ids = {}
  for id in pairs(a.cards) do ids[#ids + 1] = id end
  local RANK = { basic = 0, common = 1, uncommon = 2, rare = 3 }
  local function rarityOf(id) return ns.Cards[id] and ns.Cards[id].rarity or "?" end
  table.sort(ids, function(x, y)
    local rx, ry = RANK[rarityOf(x)] or 9, RANK[rarityOf(y)] or 9
    if rx ~= ry then return rx < ry end
    return x < y
  end)
  for _, id in ipairs(ids) do
    local cs = a.cards[id]
    local without = a.runs - cs.inDeck
    local winsWithout = a.wins - cs.inDeckWins
    local gap = (cs.inDeck > 0 and without > 0)
      and ("%+5.1f"):format(100 * cs.inDeckWins / cs.inDeck - 100 * winsWithout / without) or "  -  "
    out(("  %-22s %-9s %7d  %9d  %s     %s    %s    %s          %s"):format(id, rarityOf(id), cs.picked, cs.inDeck,
      pct(cs.inDeckWins, cs.inDeck), pct(winsWithout, without), gap, pct(cs.played, cs.drawn), pct(cs.unplayed, cs.drawn)))
  end
  out("")
  out("Potions bues            facile  normal   élite    boss   (par 100 expéditions)")
  local pids = {}
  for id in pairs(a.potions or {}) do pids[#pids + 1] = id end
  table.sort(pids)
  for _, id in ipairs(pids) do
    local ps = a.potions[id]
    out(("  %-20s %7.1f %7.1f %7.1f %7.1f"):format(id, 100 * (ps.easy or 0) / a.runs, 100 * (ps.normal or 0) / a.runs,
      100 * (ps.elite or 0) / a.runs, 100 * (ps.boss or 0) / a.runs))
  end
  out("")
  out("Bibelots en fin d'expédition   présents   vict. avec  vict. sans")
  local rids = {}
  for id in pairs(a.relics or {}) do rids[#rids + 1] = id end
  table.sort(rids)
  for _, id in ipairs(rids) do
    local rs = a.relics[id]
    out(("  %-28s %8d   %s     %s"):format(id, rs.n, pct(rs.wins, rs.n), pct(a.wins - rs.wins, a.runs - rs.n)))
  end
  out("")
  if opts.runner == "expedition" then
    local zones = tonumber(opts.zones) or (opts.meta == "exalted" and 7 or 0)
    out(("Expédition : %s, clé +%d, zones gagnées %d, niveau de classe %d"):format(opts.zone or "westfall",
      tonumber(opts.key or 0), zones, tonumber(opts.level or 7)))
    out(("Expérience de classe : %.1f par expédition (victoire %.1f, défaite %.1f)"):format(a.xp / a.runs,
      a.wins > 0 and a.xpWin / a.wins or 0, a.runs > a.wins and a.xpLoss / (a.runs - a.wins) or 0))
    out(("Or moyen : gagné %.1f, dépensé %.1f, restant %.1f   Étapes franchies : %.2f")
      :format(a.goldEarned / a.runs, a.goldSpent / a.runs, a.goldEnd / a.runs, a.cleared / a.runs))
    out(("Cartes retirées : %.2f   améliorées : %.2f par expédition"):format(a.removed / a.runs, a.upgraded / a.runs))
    local vs = {}
    for _, k in ipairs({ "combat", "elite", "campfire", "merchant", "event", "chest", "boss" }) do
      vs[#vs + 1] = ("%s %.2f"):format(k, (a.visits[k] or 0) / a.runs)
    end
    out("Visites par expédition : " .. table.concat(vs, ", "))
    out("")
    out("Rencontres               famille  vues/100  vict. avec  vict. sans  écart   réponses choisies (%)")
    local eids = {}
    for id in pairs(a.events or {}) do eids[#eids + 1] = id end
    table.sort(eids)
    local evDefs = ns.Events or {}
    for _, id in ipairs(eids) do
      local es = a.events[id]
      local without, winsWithout = a.runs - es.n, a.wins - es.wins
      local gap = (es.n > 0 and without > 0)
        and ("%+5.1f"):format(100 * es.wins / es.n - 100 * winsWithout / without) or "  -  "
      local cs = {}
      local maxCi = 0
      for ci in pairs(es.choices) do if ci > maxCi then maxCi = ci end end
      for ci = 0, maxCi do
        if es.choices[ci] then cs[#cs + 1] = ("%d:%d"):format(ci, math.floor(100 * es.choices[ci] / es.n + 0.5)) end
      end
      local fam = evDefs[id] and (evDefs[id].rarity or "common") or "?"
      out(("  %-24s %-7s %7.1f    %s     %s    %s   %s"):format(id, fam, 100 * es.n / a.runs, pct(es.wins, es.n),
        pct(winsWithout, without), gap, table.concat(cs, " ")))
    end
    out("")
  end
  out(("Incantations du joueur : %d, interrompues : %s"):format(a.castsStarted, pct(a.castsInterrupted, a.castsStarted)))
  local cst = a.castStats or {}
  out(("Tours avec une incantation jouable : sous menace d'interruption %d (incanté quand même %s), "
    .. "sans menace %d (incanté %s)"):format(cst.threatTurns or 0, pct(cst.threatCasts or 0, cst.threatTurns or 0),
    cst.freeTurns or 0, pct(cst.freeCasts or 0, cst.freeTurns or 0)))
  out(("  dont Guette %d (incanté %s), coup qui interrompt %d (incanté %s)"):format(cst.watchTurns or 0,
    pct(cst.watchCasts or 0, cst.watchTurns or 0), cst.pushTurns or 0, pct(cst.pushCasts or 0, cst.pushTurns or 0)))
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
