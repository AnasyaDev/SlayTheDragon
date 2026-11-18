-- Simulation d'expéditions en masse.
-- Usage : luajit Sim/sim.lua runs=2000 bot=heuristic seed=1 jobs=8 pick=rated cap=400 [class=priest|warrior]
--         [force=penance,mind_blast] [save=rapport.lua] [compare=ancien.lua]
--   bot  : random | greedy | heuristic | human        pick : rated | random | skip
--   bot=human : skill=0..1 (défaut Bots.HUMAN_SKILL) et paramètres nommés de Bots.HUMAN_RANGE (width=, depth=,
--     foresight=, slip=, tol=, combo=, hoard=, pickNoise=, rareBonus=, newBonus=, takeMin=, pathDepth=,
--     pathNoise=, replan=, daring=, restAt=, upNoise=, removeRate=, eventNoise=, upfocus=0..1 : 0 étale ses
--     améliorations, 1 monte ses meilleures cartes jusqu'à +3 d'abord) ; fightbot=<bot> : bot des
--     combats seul remplacé (runner=expedition).
--   save : écrit les agrégats bruts (pour une comparaison avant/après avec compare=)
--   runner=expedition : vraie expédition (Core/Expedition, carte, marchand, rencontres…)
--     avec key=N (clé mythique) et zones=0..7 (zones gagnées par le compte et la classe, à toutes les clés :
--     commun, cartes de zone, bibelots de clé ; drapeaux d'histoire d'un vétéran dès 1) ; meta=start et
--     meta=exalted restent des alias de zones=0 et zones=7. L'expédition traverse la campagne depuis Westfall
--     (victoire = Nefarian battu ; tableau « Par zone »). Diagnostic : startzone=<id> (départ dans cette zone avec
--     le deck de départ), maxzone=<id> (arrêt après le boss de cette zone) ; zone=<id> = startzone=<id>
--     maxzone=<id> (une zone seule, comme avant le 14/11/2026)
--   level=1..7 : niveau de classe (cartes et bibelots de classe débloqués) ; défaut 7 avec
--     runner=expedition (tout débloqué, les mesures d'avant la progression par classe), toutes les cartes sinon
--   tier=0..7 : bibelots/potions communs débloqués (palier commun : zones gagnées par le compte ; défaut : tous)
--   relics=id,id : bibelots dès le départ        loot=0 : ni bibelot ni potion gagnés
--   nointerrupt=1 : monde témoin où les ennemis n'interrompent jamais
--   sweep=cards [only=id,id] : mesure chaque carte de la réserve, ajoutée de force au deck de départ,
--                 contre la même série sans elle (mêmes graines) ; sweep=relics de même ; only= accepte
--                 aussi des cartes hors réserve (neutres). up=N (sweep=cards) : chaque carte ajoutée à son
--                 palier N (seulement les cartes dont ce palier est écrit ; épiques exclues dès N >= 1 ;
--                 docs/ameliorations.md) : comparer up=1 et up=2 mesure le gain du palier 2.
--   force=id+2 : carte forcée au palier 2 (id+ : palier 1 ; runner=expedition).
--   oldstun=1 : ancienne règle de Stunned pendant le tour ennemi (l'action part, le tour suivant est perdu)
--   hp=N : PV de départ de la classe remplacés (runner=expedition), pour mesurer l'effet des PV.
--   path=<voie> : récompenses de cartes limitées à une voie de la classe (runner=expedition), voie seule.
--   tune=Module.CLE=n[,Module.CLE=n] : constante numérique de réglage d'un module (ns.Druid.TAX…) remplacée le
--     temps de la série, sans toucher au code (Druid.TAX=0 : sans taxe ; Druid.TREE_REGEN=0).
--   sources=1 : d'où viennent dégâts, soins, Regen et Absorb du joueur, par combat (« Statistiques de zone »,
--     clés src_dmg:, src_heal:, src_regen:, src_abs:) : carte qui les porte, frappe de l'ours (bear:auto ou
--     bear:<carte>), coups de fin de tour de Moonkin (pulse), DoT, Thorns, tic de Regen ; dégâts effectifs
--     (sans l'excédent au-delà des PV de la cible).
--   epic=<id> : carte épique imposée au deck de départ (runner=expedition ; comme une épique prise : une seule
--     dans le deck, ses transformations s'appliquent). sweep=cards mesure aussi les épiques de la classe, chacune
--     imposée ainsi (runner=expedition ; sinon ajoutée de force). epic=none : aucune épique (offres refusées) ;
--     sweep=cards mesure tout (la ligne « (sans) » comprise) avec epic=none, sauf l'épique imposée de sa ligne.
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."

-- LuaJIT : plus de traces et de code machine que les réglages par défaut (1000 traces, 512 Ko) ; le
-- moteur, les bots et les règles de zone en demandent plus, sinon le cache de traces se vide sans cesse
-- (environ deux fois plus lent). Une campagne crée ≈ 340 traces : 4 000 traces et 8 Mo se vidaient toutes
-- les 10 à 15 campagnes (tout recompiler, 15 à 35 % du temps dans le compilateur) ; un processus de 75
-- campagnes (runs=600 jobs=8) en crée ≈ 25 000. Plafond de LuaJIT (65 535 traces) et 256 Mo réservés : aucun
-- vidage avant ≈ 190 campagnes par processus, ≈ 110 Mo de mémoire par processus à 75 campagnes, ≈ 25 % de
-- CPU en moins (15/11/2026). Sans effet sur les résultats.
if jit and jit.opt then pcall(jit.opt.start, "maxtrace=65535", "maxmcode=262144") end
-- Ramasse-miettes moins fréquent (pause 400 : cycle suivant quand le tas a quadruplé, au lieu de doublé) : la
-- simulation alloue sans cesse des états de combat clonés ; ≈ 15 % de CPU en moins, ≈ 200 Mo par processus au
-- lieu de 110 (75 campagnes ; 15/11/2026). Sans effet sur les résultats.
collectgarbage("setpause", 400)
-- SIMJIT="opt=… opt=…" : réglages du compilateur essayés sans toucher au fichier (mesures)
if jit and jit.opt and os.getenv("SIMJIT") then
  local t = {}
  for o in os.getenv("SIMJIT"):gmatch("%S+") do t[#t + 1] = o end
  jit.opt.start(unpack(t))
end

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
  -- étape de la défaite (expédition : « zone étape », la campagne a 56 étapes)
  local fk = rec.zone and (rec.zone .. " " .. rec.floor) or rec.floor
  agg.floors[fk] = (agg.floors[fk] or 0) + (rec.won and 0 or 1)
  -- par zone (runner=expedition) : atteinte, battue, PV / PV max / deck / épique à l'entrée
  for zi, z in ipairs(rec.zones or {}) do
    agg.zones = agg.zones or {}
    local s = agg.zones[z.zone] or { reached = 0, beaten = 0, hp = 0, maxHp = 0, deck = 0, epic = 0 }
    agg.zones[z.zone] = s
    s.reached = s.reached + 1
    if z.beaten then s.beaten = s.beaten + 1 end
    s.hp, s.maxHp, s.deck, s.epic = s.hp + z.hp, s.maxHp + z.maxHp, s.deck + z.deck, s.epic + z.epic
    -- or à l'entrée de la zone, or gagné dans la zone (jusqu'à l'entrée de la suivante ou la fin)
    if z.gold then
      local nx = rec.zones[zi + 1]
      s.gold = (s.gold or 0) + z.gold
      s.earned = (s.earned or 0) + ((nx and nx.earned or rec.goldEarned or z.earned) - z.earned)
    end
  end
  -- visites du marchand, par zone (Sim/expedition.lua, record.shops)
  for _, v in ipairs(rec.shops or {}) do
    agg.shops = agg.shops or {}
    local s = agg.shops[v.zone] or { n = 0, gold = 0, total = 0, share = 0, full = 0, bought = 0, removed = 0,
      spent = 0, items = 0, up = 0, none = 0, afford = 0, epic = 0, epicBought = 0, upBought = 0 }
    agg.shops[v.zone] = s
    s.n = s.n + 1
    s.gold, s.total, s.items, s.up = s.gold + v.gold, s.total + v.total, s.items + v.items, s.up + v.up
    s.share = s.share + (v.total > 0 and math.min(1, v.gold / v.total) or 1)
    if v.gold >= v.total then s.full = s.full + 1 end
    s.bought, s.removed, s.spent = s.bought + (v.bought or 0), s.removed + (v.removed or 0), s.spent + (v.spent or 0)
    if (v.bought or 0) + (v.removed or 0) == 0 then s.none = s.none + 1 end
    -- articles abordables : or à l'entrée / prix moyen d'un article de l'étal
    if v.items > 0 and v.total > 0 then s.afford = s.afford + v.gold * v.items / v.total end
    s.epic, s.epicBought, s.upBought = s.epic + (v.epic or 0), s.epicBought + (v.epicBought or 0),
      s.upBought + (v.upBought or 0)
  end
  if rec.visits then
    agg.goldEarned = agg.goldEarned + rec.goldEarned
    agg.goldSpent = agg.goldSpent + rec.goldSpent
    agg.goldEnd = agg.goldEnd + rec.gold
    -- or gagné après la sortie du dernier marchand (aucun marchand : tout l'or gagné) : il ne pouvait plus servir
    agg.goldAfterShop = (agg.goldAfterShop or 0) + rec.goldEarned - (rec.earnedAtLastShop or 0)
    if rec.won then
      agg.goldAfterShopWin = (agg.goldAfterShopWin or 0) + rec.goldEarned - (rec.earnedAtLastShop or 0)
      agg.goldEndWin = (agg.goldEndWin or 0) + rec.gold
      agg.goldEarnedWin = (agg.goldEarnedWin or 0) + rec.goldEarned
    end
    agg.xp = agg.xp + (rec.xp or 0)
    if rec.won then agg.xpWin = agg.xpWin + (rec.xp or 0) else agg.xpLoss = agg.xpLoss + (rec.xp or 0) end
    agg.cleared = agg.cleared + rec.cleared
    agg.removed = agg.removed + rec.removed
    agg.upgraded = agg.upgraded + rec.upgraded
    agg.epicEnd = (agg.epicEnd or 0) + (rec.epicEnd or 0)
    agg.epicUp = (agg.epicUp or 0) + (rec.epicUp or 0)
    if rec.won and (rec.epicEnd or 0) > 0 then agg.epicWins = (agg.epicWins or 0) + 1 end
    for k, n in pairs(rec.visits) do agg.visits[k] = (agg.visits[k] or 0) + n end
  end
  for _, cb in ipairs(rec.combats) do
    -- PV nets : PV à l'entrée du combat moins PV à la sortie (soins, Last Breath et changements de PV max
    -- du combat compris ; négatif si le combat rend plus qu'il ne coûte). stats.healed ne compte pas le
    -- PV rendu par Last Breath (preventDeath) : la mesure directe fait foi.
    local net = cb.hpBefore - cb.hpAfter
    local e = agg.enc[cb.encounter]
    if not e then
      e = { kind = cb.kind, n = 0, won = 0, turns = 0, turnsHist = {}, hpLost = 0, stalled = 0 }
      agg.enc[cb.encounter] = e
    elseif cb.kind < e.kind then
      -- groupe partagé entre deux genres (rencontre « event_* » et combat normal) : le plus petit nom, comme
      -- mergeInto, pour un rapport indépendant de l'ordre des expéditions et du découpage en lots
      e.kind = cb.kind
    end
    e.n = e.n + 1
    if cb.won then e.won = e.won + 1 end
    e.turns = e.turns + cb.turns
    e.turnsHist[cb.turns] = (e.turnsHist[cb.turns] or 0) + 1
    e.hpLost = e.hpLost + cb.hpLost
    e.hpNet = (e.hpNet or 0) + net
    if cb.stalled then e.stalled = e.stalled + 1 end
    local k = agg.kinds[cb.kind] or { n = 0, won = 0, turns = 0, hpLost = 0 }
    agg.kinds[cb.kind] = k
    k.n = k.n + 1; k.turns = k.turns + cb.turns; k.hpLost = k.hpLost + cb.hpLost
    k.hpNet = (k.hpNet or 0) + net
    k.maxHp = (k.maxHp or 0) + (cb.maxHp or 0) -- PV max à l'entrée, sommés : « % PV max » = hpNet / maxHp
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
    -- statistiques des zones (Combat.zstat) : par type de combat
    for key, n in pairs(cb.zoneStats or {}) do
      agg.zoneStats = agg.zoneStats or {}
      local zs = agg.zoneStats[key] or {}
      agg.zoneStats[key] = zs
      zs[cb.kind] = (zs[cb.kind] or 0) + n
    end
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
  agg.deckSize = (agg.deckSize or 0) + #(rec.deck or {})
  -- améliorations par palier atteint, cartes du deck final par palier (runner=expedition)
  if rec.upTiers then
    agg.upTiers = agg.upTiers or { 0, 0, 0 }
    agg.deckTiers = agg.deckTiers or { 0, 0, 0 }
    for n = 1, 3 do
      agg.upTiers[n] = agg.upTiers[n] + (rec.upTiers[n] or 0)
      agg.deckTiers[n] = agg.deckTiers[n] + (rec.deckTiers[n] or 0)
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
  -- palier atteint en fin d'expédition par carte (la copie la plus montée) : somme des paliers, expéditions où
  -- elle finit à +2 ou +3 (hiN, hiWins) et à +3 (l3N)
  if rec.upTiers then
    local top = {}
    for _, card in ipairs(rec.deck or {}) do
      local n = card.up == true and 1 or tonumber(card.up) or 0
      if n > (top[card.id] or -1) then top[card.id] = n end
    end
    for id, n in pairs(top) do
      local cs = agg.cards[id]
      cs.lvlSum = (cs.lvlSum or 0) + n
      if n >= 2 then
        cs.hiN = (cs.hiN or 0) + 1
        if rec.won then cs.hiWins = (cs.hiWins or 0) + 1 end
      end
      if n >= 3 then cs.l3N = (cs.l3N or 0) + 1 end
    end
  end
  -- feu de camp : repos et améliorations choisis (rec.picks : "rest", "up:<carte>")
  for _, p in ipairs(rec.picks or {}) do
    if p == "rest" then agg.campRest = (agg.campRest or 0) + 1
    elseif p:sub(1, 3) == "up:" then agg.campUp = (agg.campUp or 0) + 1 end
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
    elseif type(v) == "string" and type(a[k]) == "string" then
      if v < a[k] then a[k] = v end -- indépendant de l'ordre des lots (genre d'une rencontre partagée)
    else
      a[k] = v
    end
  end
end

---------------------------------------------------------------------------
-- Exécution
---------------------------------------------------------------------------
-- tune= : constantes numériques remplacées (Module.CLE=n, séparées par des virgules).
local function applyTune(ns)
  for item in (opts.tune or ""):gmatch("[^,]+") do
    local mod, key, v = item:match("^([%w_]+)%.([%w_]+)=(.+)$")
    local m = mod and ns[mod]
    assert(m and type(m[key]) == "number" and tonumber(v), "tune= : réglage inconnu ou non numérique " .. item)
    m[key] = tonumber(v)
  end
end

-- sources=1 : compteurs par source (Combat.zstat) posés par des enveloppes de Combat.dealDamage, Combat.heal,
-- Combat.applyStatus (Regen du joueur) et Combat.gainBlock ; drapeaux posés le temps d'un appel sur le combat.
local function installSources(ns)
  local Combat = ns.Combat
  local function cardOf(c) return c.cardCtx and c.cardCtx.def and c.cardCtx.def.id end
  local deal = Combat.dealDamage
  Combat.dealDamage = function(c, src, dst, amount, pierce, ctx)
    if dst.side ~= "enemy" or dst.dead or c.result or not c.stats then return deal(c, src, dst, amount, pierce, ctx) end
    local before = math.max(dst.hp, 0)
    local label
    if src and src.side == "enemy" then label = "enemy"
    elseif c.hitKind == "dot" or src == nil then label = "dot"
    elseif c.hitKind == "pet" then label = "bear:" .. (cardOf(c) or "auto")
    elseif c.srcPulse then label = "pulse"
    elseif c.srcThorns then label = "thorns"
    else label = cardOf(c) or "other" end
    local loss, absorbed = deal(c, src, dst, amount, pierce, ctx)
    Combat.zstat(c, "src_dmg:" .. label, math.min(loss, before))
    return loss, absorbed
  end
  local modify = Combat.modify
  Combat.modify = function(c, name, v, a, b, d, x)
    if name == "regenHeal" then c.srcRegen = true end
    return modify(c, name, v, a, b, d, x)
  end
  local heal = Combat.heal
  Combat.heal = function(c, unit, n)
    local regen = c.srcRegen
    c.srcRegen = nil
    local got = heal(c, unit, n)
    if unit.side == "player" and c.stats and got > 0 then
      Combat.zstat(c, "src_heal:" .. (regen and "regen_tick" or cardOf(c) or "other"), got)
    end
    return got
  end
  local apply = Combat.applyStatus
  Combat.applyStatus = function(c, unit, id, n, icon)
    if id == "regen" and unit.side == "player" and c.stats then
      Combat.zstat(c, "src_regen:" .. (cardOf(c) or (c.srcTreeEnd and "tree_end" or "other")), n)
    end
    return apply(c, unit, id, n, icon)
  end
  local block = Combat.gainBlock
  Combat.gainBlock = function(c, unit, n)
    local b0 = unit.block
    block(c, unit, n)
    if unit.side == "player" and c.stats and unit.block > b0 then
      Combat.zstat(c, "src_abs:" .. (cardOf(c) or "other"), unit.block - b0)
    end
  end
  local D = ns.Druid
  if D then
    local pulse, eot = D.moonkinPulse, D.endOfTurn
    D.moonkinPulse = function(c)
      c.srcPulse = true
      local r = pulse(c)
      c.srcPulse = nil
      return r
    end
    D.endOfTurn = function(c)
      c.srcTreeEnd = true
      eot(c)
      c.srcTreeEnd = nil
    end
    local th = ns.Cards.thorns
    for _, t in ipairs({ th, th.up2 }) do
      local f = t.hooks.afterHit
      t.hooks.afterHit = function(c, ...)
        c.srcThorns = true
        f(c, ...)
        c.srcThorns = nil
      end
    end
  end
end

local function runRange(from, to)
  local ns = dofile(root .. "/Sim/load.lua")(root)
  applyTune(ns)
  if opts.sources == "1" then installSources(ns) end
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
  -- bot=human : skill= et paramètres nommés (Bots.HUMAN_RANGE) passés tels quels
  local human
  if opts.bot == "human" then
    human = { skill = opts.skill }
    for k in pairs(ns.Bots.HUMAN_RANGE) do human[k] = opts[k] end
  end
  for i = from, to do
    local rec
    if opts.runner == "expedition" then
      rec = ns.SimExpedition.play({ seed = seed0 * 1000003 + i, bot = opts.bot or "heuristic",
        pick = opts.pick or "rated", cap = tonumber(opts.cap or 400), key = tonumber(opts.key or 0),
        meta = opts.meta or "start", class = opts.class, force = force, level = tonumber(opts.level),
        hp = tonumber(opts.hp), path = opts.path, zones = tonumber(opts.zones), zone = opts.zone,
        startZone = opts.startzone, maxZone = opts.maxzone,
        epic = opts.epic ~= "" and opts.epic or nil, human = human, fightBot = opts.fightbot })
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

-- Lots fixes d'une série (jobs > 1) : { from, to } de ceil(runs / jobs) expéditions, un processus chacun.
-- Le découpage ne change rien : les fiches sont immuables après le chargement et une expédition ne laisse
-- aucune trace dans l'addon chargé (Sim/tests_expedition.lua, « fiches immuables »), donc jobs=1, 4 ou 8
-- donnent le même rapport (hors durée).
local function lots()
  local list, per = {}, math.ceil(runs / jobs)
  for j = 1, jobs do
    local from, to = (j - 1) * per + 1, math.min(runs, j * per)
    if from <= to then list[#list + 1] = { from, to } end
  end
  return list
end

-- Commande d'un lot ; over remplace des options (force=, relics=, epic=) le temps de la série.
local function lotCommand(over, lot)
  local passthrough = {}
  for k, v in pairs(opts) do
    if k ~= "jobs" and k ~= "save" and k ~= "compare" and k ~= "runs" and k ~= "sweep"
        and over[k] == nil then
      passthrough[#passthrough + 1] = k .. "=" .. v
    end
  end
  for k, v in pairs(over) do passthrough[#passthrough + 1] = k .. "=" .. v end
  return string.format("%s %s/Sim/sim.lua worker=1 from=%d to=%d %s", opts.exe or "luajit", root, lot[1],
    lot[2], table.concat(passthrough, " "))
end

-- Lance un lot dans un processus sans l'attendre. Renvoie une fonction qui attend la fin et rend ses agrégats.
local function launchLot(over, lot)
  local p = assert(io.popen(lotCommand(over, lot), "r"))
  return function()
    local out = p:read("*a")
    p:close()
    return deserialize(out)
  end
end

-- Lance la série complète ; over remplace des options (force=, relics=) le temps de la série.
local function runAll(over)
  over = over or {}
  if jobs <= 1 then
    local f0, r0, e0 = force, startRelics, opts.epic
    if over.force then force = idList(over.force) end
    if over.relics then startRelics = idList(over.relics) end
    if over.epic then opts.epic = over.epic end
    local a = runRange(1, runs)
    force, startRelics, opts.epic = f0, r0, e0
    return a
  end
  local pending = {}
  for i, lot in ipairs(lots()) do pending[i] = launchLot(over, lot) end
  local a = newAgg()
  for _, wait in ipairs(pending) do mergeInto(a, wait()) end
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
    -- épiques de la classe (hors réserve des récompenses), mesurées imposées au départ (epic=)
    for id, d in pairs(ns.Cards) do
      if d.rarity == "epic" and d.class == (opts.class or "priest") and not d.variant then list[#list + 1] = id end
    end
  end
  -- up=N : paliers mesurés (cartes dont le palier N est écrit, épiques exclues dès N >= 1)
  local upN = tonumber(opts.up or 0) or 0
  if opts.sweep == "cards" and upN > 0 then
    local l2 = {}
    for _, id in ipairs(list) do
      if ns.Cards[id].rarity ~= "epic" and ns.Card.tiers(id) >= upN then l2[#l2 + 1] = id end
    end
    list = l2
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
  -- runner=expedition : mesures sans épique (epic=none), sauf l'épique imposée de sa ligne
  local noEpic = opts.runner == "expedition" and "none" or nil
  -- Séries du balayage dans l'ordre du rapport : la référence (sans), puis une par élément.
  local series = { { over = { epic = noEpic } } }
  for _, id in ipairs(list) do
    local over = { epic = noEpic }
    if opts.sweep == "relics" then
      local rl = {}
      for _, r in ipairs(startRelics) do rl[#rl + 1] = r end
      rl[#rl + 1] = id
      over.relics = table.concat(rl, ",")
    elseif ns.Cards[id].rarity == "epic" and opts.runner == "expedition" then
      over.epic = id
    else
      local fl = {}
      for _, f in ipairs(force) do fl[#fl + 1] = f end
      fl[#fl + 1] = id .. ns.Card.suffix(upN)
      over.force = table.concat(fl, ",")
    end
    series[#series + 1] = { id = id, over = over }
  end
  -- jobs > 1 : les lots de toutes les séries forment une file que xargs -P fait tourner, jobs processus à la fois,
  -- chaque place libérée prise aussitôt par le lot suivant, même s'il est d'une ligne d'après : plus d'attente
  -- du lot le plus lent à chaque ligne (≈ 25 % du temps d'un balayage). Chaque lot écrit ses agrégats dans un
  -- fichier ; mêmes lots, mêmes processus et même ordre de fusion que runAll : mêmes chiffres.
  local result, closePool
  if jobs > 1 then
    local seriesLots = lots()
    local dir = os.tmpname()
    os.remove(dir)
    os.execute("mkdir -p '" .. dir .. "'")
    local lotsFile = assert(io.open(dir .. "/lots", "w"))
    local t = 0
    for s = 1, #series do
      for _, lot in ipairs(seriesLots) do
        t = t + 1
        local f = assert(io.open(("%s/%d.sh"):format(dir, t), "w"))
        f:write(lotCommand(series[s].over, lot), "\n")
        f:close()
        lotsFile:write(t, "\n")
      end
    end
    lotsFile:close()
    -- une ligne « n » par lot fini (dans l'ordre où ils finissent), ses agrégats dans <dir>/n.out
    local pool = assert(io.popen(("xargs -P %d -n 1 sh -c 'sh \"$0/$1.sh\" > \"$0/$1.out\"; echo \"$1\"' '%s' < '%s/lots'")
      :format(jobs, dir, dir), "r"))
    local done, readT = {}, 0
    local function lotResult(n)
      while not done[n] do
        local line = assert(pool:read("*l"), "balayage : file des lots interrompue")
        done[tonumber(line)] = true
      end
      local f = assert(io.open(("%s/%d.out"):format(dir, n), "r"))
      local out = f:read("*a")
      f:close()
      assert(out ~= "", "balayage : lot " .. n .. " en échec")
      os.remove(("%s/%d.out"):format(dir, n))
      os.remove(("%s/%d.sh"):format(dir, n))
      return deserialize(out)
    end
    result = function()
      local a = newAgg()
      for _ = 1, #seriesLots do
        readT = readT + 1
        mergeInto(a, lotResult(readT))
      end
      return a
    end
    closePool = function()
      pool:close()
      os.remove(dir .. "/lots")
      os.remove(dir)
    end
  else
    result = function(s) return runAll(series[s].over) end
  end
  local base = result(1)
  local function line(name, rarity, a)
    local parts = {}
    for _, k in ipairs({ "easy", "normal", "elite", "boss" }) do
      local s = a.kinds[k]
      parts[#parts + 1] = s and ("%5.1f/%4.1f"):format(s.turns / s.n, s.hpLost / s.n) or "     -    "
    end
    local cs = a.cards[(name:gsub("%+%d*$", ""))] -- ligne d'un palier (up=N) : statistiques de la carte
    local use = cs and cs.drawn > 0 and ("%5.1f %%"):format(100 * cs.played / cs.drawn) or "   -   "
    return ("  %-22s %-9s %5.1f %%  %+6.1f   %s   %s"):format(name, rarity, 100 * a.wins / a.runs,
      100 * (a.wins - base.wins) / a.runs, table.concat(parts, "  "), use)
  end
  print(("== Balayage %s : %d expéditions par ligne, bot %s, choix %s =="):format(opts.sweep, runs,
    opts.bot or "heuristic", opts.pick or "rated"))
  print("  élément                rareté    vict.   écart   facile t/PV  normal t/PV  élite t/PV   boss t/PV    jouée")
  print(line("(sans)", "-", base))
  local rows = {}
  for i = 2, #series do
    local id = series[i].id
    local a = result(i)
    local def = opts.sweep == "relics" and ns.Relics[id] or ns.Cards[id]
    print(line(id .. (opts.sweep == "cards" and ns.Card.suffix(upN) or ""), def.rarity, a))
    io.stdout:flush()
    rows[id] = { wins = a.wins, runs = a.runs }
  end
  if closePool then closePool() end
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
  if opts.tune then out("Réglages remplacés : " .. opts.tune) end
  if (opts.bot or "heuristic") == "human" then
    local over = { skill = opts.skill }
    for k in pairs(ns.Bots.HUMAN_RANGE) do over[k] = opts[k] end
    local H = ns.Bots.humanParams(over)
    local keys = {}
    for k in pairs(H) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = ("%s=%g"):format(k, H[k]) end
    out("Joueur humain : " .. table.concat(parts, " "))
  end
  -- runner=expedition : victoire = boss de la dernière zone de l'expédition battu (Nefarian, sauf maxzone=/zone=)
  local lastZone = opts.runner == "expedition" and (opts.maxzone or opts.zone or ns.Zone.ORDER[#ns.Zone.ORDER]) or nil
  out(("Victoires   : %s (± %.1f)   PV moyens à la victoire : %.1f%s"):format(pct(a.wins, a.runs), 1.96 * se,
    a.wins > 0 and a.hpEndWin / a.wins or 0, lastZone and ("   (boss de " .. ns.Zone.name(lastZone) .. " battu)") or ""))
  local deaths = {}
  for f, n in pairs(a.floors) do if n > 0 then deaths[#deaths + 1] = { key = f, n = n } end end
  local function deathOrder(k)
    if type(k) == "number" then return k end
    local z, fl = tostring(k):match("^(%S+) (%d+)$")
    return (ns.Zone.order(z) or 0) * 100 + (tonumber(fl) or 0)
  end
  table.sort(deaths, function(x, y) return deathOrder(x.key) < deathOrder(y.key) end)
  local dl = {}
  for _, d in ipairs(deaths) do
    if type(d.key) == "number" then dl[#dl + 1] = ("étape %d : %d"):format(d.key, d.n)
    else dl[#dl + 1] = ("%s : %d"):format(d.key, d.n) end
  end
  out("Défaites    : " .. table.concat(dl, ", "))
  -- Par zone : part des expéditions qui atteignent la zone, qui battent son boss, taux conditionnel (battue /
  -- atteinte), PV, PV max et taille du deck à l'entrée (après le soin du passage), part avec une épique à l'entrée
  if a.zones then
    out("")
    out("Par zone                atteinte   battue   battue/atteinte   PV entrée   PV max   deck   épique entrée")
    for _, zid in ipairs(ns.Zone.ORDER) do
      local s = a.zones[zid]
      if s and s.reached > 0 then
        out(("  %-20s %s  %s   %s         %6.1f   %6.1f  %5.1f   %s"):format(ns.Zone.name(zid), pct(s.reached, a.runs),
          pct(s.beaten, a.runs), pct(s.beaten, s.reached), s.hp / s.reached, s.maxHp / s.reached, s.deck / s.reached,
          pct(s.epic, s.reached)))
      end
    end
  end
  -- Économie par zone : or à l'entrée et gagné dans la zone ; visites du marchand (par expédition qui atteint la
  -- zone), or à l'entrée du marchand, prix de l'étal entier (cartes, bibelots, potions), part achetable (or /
  -- prix, plafonnée à 100 %), visites où tout l'étal est achetable, articles achetés et retraits par visite,
  -- visites sans rien acheter, or dépensé par visite, articles vendus améliorés par étal.
  if a.zones and a.shops then
    out("")
    out("Or et marchand par zone  or entrée  gagné  visites  or marchand  étal   achetable  étal entier"
      .. "  articles  retraits  rien   dépensé  améliorées  abordables  art./étal  amél. ach.  épique (vente/achat)")
    for _, zid in ipairs(ns.Zone.ORDER) do
      local z, s = a.zones[zid], a.shops[zid]
      if z and z.reached > 0 and z.gold then
        local cols = "        -"
        if s and s.n > 0 then
          cols = ("   %4.2f     %6.1f  %6.1f   %s    %s     %5.2f     %5.2f  %s  %6.1f    %5.2f"):format(
            s.n / z.reached, s.gold / s.n, s.total / s.n, pct(s.share, s.n), pct(s.full, s.n), s.bought / s.n,
            s.removed / s.n, pct(s.none, s.n), s.spent / s.n, s.up / s.n)
            .. ("       %5.2f      %5.2f      %5.2f       %4.2f / %4.2f"):format(s.afford / s.n, s.items / s.n,
              s.upBought / s.n, s.epic / s.n, s.epicBought / s.n)
        end
        out(("  %-20s %8.1f %6.1f%s"):format(ns.Zone.name(zid), z.gold / z.reached, (z.earned or 0) / z.reached, cols))
      end
    end
  end
  out("")
  -- PV nets (colonnes ajoutées en fin de ligne : des scripts lisent les autres par position) : PV à l'entrée
  -- moins PV à la sortie, soins du combat déduits ; % PV max = rapporté aux PV max à l'entrée du combat.
  local function netCols(s, withPct)
    if not s.hpNet then return withPct and "        -        -" or "        -" end
    local col = ("  %7.1f"):format(s.hpNet / s.n)
    if withPct then
      col = col .. ((s.maxHp or 0) > 0 and ("  %6.1f %%"):format(100 * s.hpNet / s.maxHp) or "      -  ")
    end
    return col
  end
  local classDef = ns.Classes and ns.Classes[opts.class or "priest"]
  local baseHp = tonumber(opts.hp) or (classDef and classDef.hp)
  out(("Par type de combat        n   victoires  tours moy  PV perdus moy  incant./combat  coupées   PV nets  %% PV max%s")
    :format(baseHp and ("   (PV max de départ : %d)"):format(baseHp) or ""))
  for _, k in ipairs({ "easy", "normal", "elite", "boss" }) do
    local s = a.kinds[k]
    if s then
      out(("  %-20s %6d   %s   %8.2f   %8.1f   %12.2f   %s%s"):format(k, s.n, pct(s.won, s.n), s.turns / s.n,
        s.hpLost / s.n, (s.castsStarted or 0) / s.n, pct(s.castsInterrupted or 0, s.castsStarted or 0),
        netCols(s, true)))
    end
  end
  out("")
  out("Par rencontre                                   n   victoires  tours moy  p95  PV perdus  bloqués  PV nets")
  local encs = {}
  for name, e in pairs(a.enc) do encs[#encs + 1] = { name = name, e = e } end
  table.sort(encs, function(x, y) if x.e.kind ~= y.e.kind then return x.e.kind < y.e.kind end return x.name < y.name end)
  for _, x in ipairs(encs) do
    local e = x.e
    out(("  %-7s %-35s %6d   %s   %8.2f  %3d  %9.1f  %5d%s"):format(e.kind, x.name, e.n, pct(e.won, e.n),
      e.turns / e.n, p95(e.turnsHist, e.n), e.hpLost / e.n, e.stalled, netCols(e)))
  end
  out("")
  -- colonnes ajoutées en fin de ligne (runner=expedition) : palier moyen en fin d'expédition (copie la plus
  -- montée, expéditions où la carte est au deck) et victoires quand elle finit à +2/+3
  out("Cartes                   rareté    choisie  dans deck  vict. avec  vict. sans  écart  jouées/piochées  gardées en main"
    .. (a.upTiers and "  palier moy  vict. à +2/+3" or ""))
  local ids = {}
  for id in pairs(a.cards) do ids[#ids + 1] = id end
  local RANK = { basic = 0, common = 1, uncommon = 2, rare = 3, epic = 4 }
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
    local tiers = ""
    if a.upTiers and cs.inDeck > 0 then
      tiers = ("        %4.2f  %s (%d)"):format((cs.lvlSum or 0) / cs.inDeck, pct(cs.hiWins or 0, cs.hiN or 0), cs.hiN or 0)
    end
    out(("  %-22s %-9s %7d  %9d  %s     %s    %s    %s          %s%s"):format(id, rarityOf(id), cs.picked, cs.inDeck,
      pct(cs.inDeckWins, cs.inDeck), pct(winsWithout, without), gap, pct(cs.played, cs.drawn), pct(cs.unplayed, cs.drawn),
      tiers))
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
    local from = opts.startzone or opts.zone or ns.Zone.FIRST
    out(("Expédition : %s -> %s, clé +%d, zones gagnées %d, niveau de classe %d"):format(from, lastZone,
      tonumber(opts.key or 0), zones, tonumber(opts.level or 7)))
    out(("Expérience de classe : %.1f par expédition (victoire %.1f, défaite %.1f)"):format(a.xp / a.runs,
      a.wins > 0 and a.xpWin / a.wins or 0, a.runs > a.wins and a.xpLoss / (a.runs - a.wins) or 0))
    out(("Or moyen : gagné %.1f, dépensé %.1f, restant %.1f   Étapes franchies : %.2f   or inutilisé : %s du gagné")
      :format(a.goldEarned / a.runs, a.goldSpent / a.runs, a.goldEnd / a.runs, a.cleared / a.runs,
        pct(a.goldEnd, a.goldEarned)))
    out(("Or gagné après le dernier marchand : %.1f (%s du gagné)"):format((a.goldAfterShop or 0) / a.runs,
      pct(a.goldAfterShop or 0, a.goldEarned)))
    if a.wins > 0 then
      out(("Or des victoires : gagné %.1f, restant %.1f (inutilisé : %s du gagné), gagné après le dernier marchand %.1f")
        :format((a.goldEarnedWin or 0) / a.wins, (a.goldEndWin or 0) / a.wins, pct(a.goldEndWin or 0, a.goldEarnedWin or 0),
          (a.goldAfterShopWin or 0) / a.wins))
    end
    out(("Cartes retirées : %.2f   améliorées : %.2f par expédition   deck en fin : %.1f cartes"):format(
      a.removed / a.runs, a.upgraded / a.runs, (a.deckSize or 0) / a.runs))
    -- paliers d'amélioration (docs/ameliorations.md) : améliorations faites vers chaque palier, et cartes du
    -- deck final à chaque palier, par expédition
    local ut, dt = a.upTiers or { 0, 0, 0 }, a.deckTiers or { 0, 0, 0 }
    out(("Améliorations par palier : +1 %.2f, +2 %.2f, +3 %.2f   deck en fin : +1 %.2f, +2 %.2f, +3 %.2f cartes")
      :format(ut[1] / a.runs, ut[2] / a.runs, ut[3] / a.runs, dt[1] / a.runs, dt[2] / a.runs, dt[3] / a.runs))
    out(("Feu de camp : repos %.2f, amélioration %.2f par expédition (%s des feux choisis)"):format(
      (a.campRest or 0) / a.runs, (a.campUp or 0) / a.runs, pct(a.campUp or 0, (a.campUp or 0) + (a.campRest or 0))))
    -- cartes montées le plus haut : expéditions où la carte finit à +2/+3 (copie la plus montée), palier moyen
    -- quand elle est au deck, victoires à +2/+3 contre à +0/+1 (expéditions où elle est au deck)
    local hi = {}
    for id, cs in pairs(a.cards) do if (cs.hiN or 0) > 0 then hi[#hi + 1] = id end end
    table.sort(hi, function(x, y)
      local hx, hy = a.cards[x].hiN, a.cards[y].hiN
      if hx ~= hy then return hx > hy end
      return x < y
    end)
    if #hi > 0 then
      out("Cartes montées le plus haut  à +2/+3  dont +3  dans deck  palier moy  vict. à +2/+3  vict. à +0/+1  écart")
      for k = 1, math.min(10, #hi) do
        local id = hi[k]
        local cs = a.cards[id]
        local lo, loW = cs.inDeck - cs.hiN, cs.inDeckWins - (cs.hiWins or 0)
        local gap = lo > 0 and ("%+5.1f"):format(100 * (cs.hiWins or 0) / cs.hiN - 100 * loW / lo) or "  -  "
        out(("  %-26s %7d  %7d  %9d      %4.2f      %s        %s    %s"):format(id, cs.hiN, cs.l3N or 0, cs.inDeck,
          (cs.lvlSum or 0) / cs.inDeck, pct(cs.hiWins or 0, cs.hiN), pct(loW, lo), gap))
      end
    end
    -- épique en fin d'expédition (gagnée sur un élite, achetée, ou imposée par epic=) ; victoires avec / sans
    local en, ew = a.epicEnd or 0, a.epicWins or 0
    out(("Épique en fin d'expédition : %s (améliorée : %s)   victoires avec épique %s, sans %s")
      :format(pct(en, a.runs), pct(a.epicUp or 0, a.runs), en > 0 and pct(ew, en) or "-",
        a.runs > en and pct(a.wins - ew, a.runs - en) or "-"))
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
  -- statistiques des zones (Combat.zstat) : moyenne par combat de chaque type
  if a.zoneStats then
    local keys = {}
    for key in pairs(a.zoneStats) do keys[#keys + 1] = key end
    table.sort(keys)
    out("Statistiques de zone (par combat)  easy    normal   elite    boss")
    for _, key in ipairs(keys) do
      local zs, cols = a.zoneStats[key], {}
      for _, kd in ipairs({ "easy", "normal", "elite", "boss" }) do
        local k = a.kinds[kd]
        cols[#cols + 1] = (k and k.n > 0) and ("%7.2f"):format((zs[kd] or 0) / k.n) or "     - "
      end
      out(("  %-30s %s"):format(key, table.concat(cols, "  ")))
    end
    -- Druid (docs/classes/druid.md, § 9 et § 10) : part des tours finis dans chaque forme (compteurs
    -- druid_end_<forme> de Core/Classes/druid.lua, tous combats), changements de forme par tour
    local function sum(key)
      local t = 0
      for _, n in pairs(a.zoneStats[key] or {}) do t = t + n end
      return t
    end
    local forms = { "bear", "cat", "moonkin", "tree", "none" }
    local ends = 0
    for _, f in ipairs(forms) do ends = ends + sum("druid_end_" .. f) end
    if ends > 0 then
      local cols = {}
      for _, f in ipairs(forms) do cols[#cols + 1] = ("%s %s"):format(f, pct(sum("druid_end_" .. f), ends)) end
      out(("Druid, forme de fin de tour (%d tours) : %s ; changements de forme par tour : %.2f"):format(ends,
        table.concat(cols, ", "), sum("druid_shifts") / ends))
    end
  end
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
      -- PV nets : absents des rapports enregistrés avant leur ajout (« - »)
      local function net(s) return s.hpNet and ("%.1f"):format(s.hpNet / s.n) or "-" end
      print(("  %-8s victoires %s -> %s   tours %.2f -> %.2f   PV perdus %.1f -> %.1f   PV nets %s -> %s"):format(k,
        pct(o.won, o.n), pct(n.won, n.n), o.turns / o.n, n.turns / n.n, o.hpLost / o.n, n.hpLost / n.n,
        net(o), net(n)))
    end
  end
end
