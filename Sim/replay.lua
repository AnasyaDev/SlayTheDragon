-- Rejeu d'une expédition enregistrée (Core/Record.lua) hors du jeu, avec récit texte.
-- Usage : lua5.1 Sim/replay.lua <fichier SavedVariables> [n=<numéro, défaut : la dernière>] [list=1]
--                               [bot=human|heuristic] [skill=0..1]
--   list=1 : liste des expéditions enregistrées (date, classe, clé, zone atteinte, résultat).
--   bot=   : à chaque tour de combat, ce que ce bot aurait joué depuis le même état (Sim/bots.lua).
-- Le fichier n'est que lu. Chargé par dofile depuis un autre script, il renvoie le module (tests).
local root = (arg and arg[0] or ""):match("^(.*)/Sim/[^/]*$") or "."
local isMain = arg and arg[0] and (arg[0]:match("[/\\]replay%.lua$") ~= nil or arg[0] == "replay.lua") or false

local M = {}

---------------------------------------------------------------------------
-- Fichier SavedVariables
---------------------------------------------------------------------------

-- Charge un fichier SavedVariables (Lua qui affecte des globales) dans un environnement isolé ; renvoie la table
-- de SlayTheDragonDB, ou nil, erreur.
function M.loadSaved(path)
  local chunk, err = loadfile(path)
  if not chunk then return nil, err end
  local env = {}
  setfenv(chunk, env)
  local ok, e = pcall(chunk)
  if not ok then return nil, e end
  if type(env.SlayTheDragonDB) ~= "table" then return nil, "no SlayTheDragonDB in " .. path end
  return env.SlayTheDragonDB
end

-- Écriture façon WoW (clés entre crochets, une entrée par ligne, « -- [n] » après chaque élément de liste,
-- tabulations) : sert aux tests (aller-retour) et à mesurer la taille réelle d'un enregistrement.
local function key(k)
  if type(k) == "string" then return string.format("[%q]", k) end
  return "[" .. tostring(k) .. "]"
end
local function scalar(v)
  if type(v) == "string" then return string.format("%q", v) end
  if type(v) == "number" then
    if v == math.floor(v) and v > -1e15 and v < 1e15 then return tostring(v) end
    return string.format("%.17g", v) -- WoW garde la précision des doubles
  end
  return tostring(v)
end
local function sortKeys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b)
    if type(a) ~= type(b) then return type(a) < type(b) end
    if type(a) == "boolean" then return (a and 1 or 0) < (b and 1 or 0) end
    return a < b
  end)
  return ks
end
local function write(v, out, depth)
  local pad = string.rep("\t", depth)
  out[#out + 1] = "{\n"
  local n = #v
  for i = 1, n do
    local x = v[i]
    out[#out + 1] = pad .. "\t"
    if type(x) == "table" then write(x, out, depth + 1) else out[#out + 1] = scalar(x) end
    out[#out + 1] = ", -- [" .. i .. "]\n"
  end
  for _, k in ipairs(sortKeys(v)) do
    if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
      local x = v[k]
      out[#out + 1] = pad .. "\t" .. key(k) .. " = "
      if type(x) == "table" then write(x, out, depth + 1) else out[#out + 1] = scalar(x) end
      out[#out + 1] = ",\n"
    end
  end
  out[#out + 1] = pad .. "}"
end
function M.savedText(name, v)
  local out = { "\n", name, " = " }
  write(v, out, 0)
  out[#out + 1] = "\n"
  return table.concat(out)
end

---------------------------------------------------------------------------
-- Noms
---------------------------------------------------------------------------

function M.init(ns)
  M.ns = ns
  return M
end

local function ns_() return M.ns end

local function cardName(inst)
  local ns = ns_()
  if type(inst) ~= "table" then
    local d = ns.Cards[inst]
    return d and d.name or tostring(inst)
  end
  local d = ns.Cards[inst.id]
  local n = ns.Card.level(inst)
  return (d and d.name or tostring(inst.id)) .. (n > 0 and ("+" .. n) or "")
end
M.cardName = cardName

local function relicName(id)
  local r = M.ns.Relics[id]
  return r and r.name or tostring(id)
end
local function potionName(id)
  local p = M.ns.Potions[id]
  return p and p.name or tostring(id)
end
local function statusName(id)
  local s = M.ns.Statuses[id]
  return s and s.name or tostring(id)
end
local function zoneName(id)
  local z = M.ns.Zones[id]
  return z and z.name or tostring(id)
end
M.zoneName = zoneName

local function unitName(c, ref)
  if ref == "player" then return "Vous" end
  if ref == nil then return "(effet)" end
  for _, e in ipairs(c.enemies) do
    if e.uid == ref then return M.ns.Combat.enemyName(e) end
  end
  return tostring(ref)
end

local function instByUid(c, uid)
  for _, pile in ipairs({ c.hand, c.draw, c.discard, c.exhaust, c.player.powers or {} }) do
    for _, x in ipairs(pile) do if x.uid == uid then return x end end
  end
  return nil
end

---------------------------------------------------------------------------
-- Récit d'un combat
---------------------------------------------------------------------------

local function statusLine(u)
  local ids = {}
  for id in pairs(u.st or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  local parts = {}
  for _, id in ipairs(ids) do parts[#parts + 1] = statusName(id) .. " " .. tostring(u.st[id]) end
  return table.concat(parts, ", ")
end

local function intentLine(c, e)
  local Combat = M.ns.Combat
  local ok, info = pcall(Combat.intentInfo, c, e)
  if not ok then return tostring(e.intent) end
  local s = info.name or tostring(e.intent)
  if info.stunned then s = s .. " (étourdi)" end
  if info.interrupted then s = s .. " (interrompu)" end
  if info.damage and info.times and info.times > 0 then
    s = s .. " : " .. info.damage .. (info.times > 1 and ("×" .. info.times) or "") .. " dégâts"
  elseif info.kind then
    s = s .. " [" .. tostring(info.kind) .. "]"
  end
  return s
end

local function maxMana(c)
  local ok, v = pcall(M.ns.Combat.modify, c, "maxMana", M.ns.Combat.BASE_MANA)
  return ok and v or "?"
end

local function resText(c)
  local rd = M.ns.Combat.resourceDef(c)
  if not rd then return "" end
  return ", " .. (rd.name or rd.id or "ressource") .. " " .. tostring(c.player.res or 0)
end

local function handLine(c)
  local parts = {}
  for i, inst in ipairs(c.hand) do
    local ok, cost = pcall(M.ns.Combat.cost, c, inst)
    parts[#parts + 1] = i .. ":" .. cardName(inst) .. " (" .. (ok and tostring(cost) or "?") .. ")"
  end
  return table.concat(parts, ", ")
end

-- Ligne d'un événement du journal de combat (Combat.log), ou nil (événement passé sous silence).
local function eventLine(c, ev, acc)
  local t = ev.t
  if t == "damage" then
    local s = unitName(c, ev.src) .. " → " .. unitName(c, ev.dst) .. " : " .. tostring(ev.amount) .. " dégâts"
    local more = {}
    if (ev.absorbed or 0) > 0 then more[#more + 1] = ev.absorbed .. " bloqués" end
    if ev.loss then more[#more + 1] = "PV −" .. ev.loss end
    if ev.why then more[#more + 1] = tostring(ev.why) end
    if #more > 0 then s = s .. " (" .. table.concat(more, ", ") .. ")" end
    if ev.dst == "player" then acc.taken = acc.taken + (ev.loss or 0); acc.absorbed = acc.absorbed + (ev.absorbed or 0) end
    return s
  elseif t == "block" then
    return unitName(c, ev.unit) .. " : +" .. tostring(ev.amount) .. " Block (" .. tostring(ev.total) .. ")"
  elseif t == "heal" then
    return unitName(c, ev.unit) .. " : soin +" .. tostring(ev.amount)
  elseif t == "status" then
    return unitName(c, ev.unit) .. " : " .. statusName(ev.id) .. " " .. ((ev.n or 0) >= 0 and "+" or "")
      .. tostring(ev.n) .. " (" .. tostring(ev.total) .. ")"
  elseif t == "death" then
    return unitName(c, ev.unit) .. " meurt"
  elseif t == "act" then
    local mv
    for _, e in ipairs(c.enemies) do
      if e.uid == ev.unit then mv = M.ns.Combat.moveOf(e.id, ev.move) end
    end
    return unitName(c, ev.unit) .. " : " .. (mv and mv.name or tostring(ev.move))
  elseif t == "intent" then
    return nil -- l'en-tête du tour donne les intentions
  elseif t == "draw" then
    local inst = instByUid(c, ev.card)
    acc.drawn[#acc.drawn + 1] = inst and cardName(inst) or tostring(ev.card)
    return nil
  elseif t == "play" or t == "turn" or t == "spawn" or t == "float" then
    return nil
  elseif t == "result" then
    return "Résultat : " .. tostring(ev.result)
  elseif t == "resource" then
    local rd = M.ns.Combat.resourceDef(c)
    return (rd and (rd.name or rd.id) or "ressource") .. " " .. ((ev.n or 0) >= 0 and "+" or "") .. tostring(ev.n)
      .. " (" .. tostring(ev.total) .. ")"
  elseif t == "potion" then
    return "Potion : " .. potionName(ev.id) .. (ev.target and (" → " .. unitName(c, ev.target)) or "")
  elseif t == "power" then
    return "Pouvoir en jeu : " .. cardName(ev.card)
  end
  -- autres événements : type et champs, références d'unité résolues
  local ks = sortKeys(ev)
  local parts = { t }
  for _, k in ipairs(ks) do
    if k ~= "t" then
      local v = ev[k]
      if k == "unit" or k == "src" or k == "dst" or k == "target" then v = unitName(c, v) end
      if type(v) ~= "table" then parts[#parts + 1] = k .. "=" .. tostring(v) end
    end
  end
  return table.concat(parts, " ")
end

local function flushEvents(c, out, indent)
  local acc = { taken = 0, absorbed = 0, drawn = {}, lines = 0 }
  for _, ev in ipairs(c.events or {}) do
    local s = eventLine(c, ev, acc)
    if s then
      out(indent .. s)
      acc.lines = acc.lines + 1
    end
  end
  c.events = {}
  return acc
end

---------------------------------------------------------------------------
-- Conseil d'un bot (bot=…) : ce qu'il jouerait ce tour depuis le même état, sur une copie du combat
---------------------------------------------------------------------------

local function botTurn(c, kind, human)
  local ns = M.ns
  local Combat, Bots, Rng = ns.Combat, ns.Bots, ns.Rng
  local cl = Combat.clone(c)
  cl.quiet, cl.events, cl.stats = true, {}, nil
  local bot = Bots.new(kind, Rng.stream((c.seed or 1) + c.round, "advice"), { human = human })
  local plays = {}
  for _ = 1, 40 do
    if cl.result or cl.phase ~= "player" or cl.round ~= c.round then break end
    local a = bot:act(cl)
    if a[1] == "play" then
      local inst = cl.hand[a[2]]
      local tgt = a[3] and cl.enemies[a[3]]
      local label = inst and cardName(inst) or "?"
      if tgt then label = label .. " → " .. Combat.enemyName(tgt) end
      if a[4] == "nospend" then label = label .. " (sans dépenser)" end
      if not Combat.play(cl, a[2], a[3], a[4] == "nospend" and { spend = false } or nil) then break end
      plays[#plays + 1] = label
    elseif a[1] == "potion" then
      if not Combat.usePotion(cl, a[2], a[3]) then break end
      plays[#plays + 1] = "potion " .. potionName(c.player.potions and c.player.potions[a[2]])
    else
      break
    end
  end
  if #plays == 0 then return "rien, fin du tour" end
  return table.concat(plays, ", ")
end

---------------------------------------------------------------------------
-- Récit complet
---------------------------------------------------------------------------

local KIND = { combat = "combat", elite = "élite", boss = "boss", campfire = "feu de camp", merchant = "marchand",
  event = "rencontre", chest = "coffre" }

local function deckNames(deck)
  local t = {}
  for _, x in ipairs(deck) do t[#t + 1] = cardName(x) end
  return table.concat(t, ", ")
end

local function snapshot(exp)
  local relics = {}
  for _, r in ipairs(exp.relics) do relics[r] = (relics[r] or 0) + 1 end
  local deck = {}
  for _, x in ipairs(exp.deck) do local k = cardName(x) deck[k] = (deck[k] or 0) + 1 end
  local pots = {}
  for _, p in ipairs(exp.potions) do if p then pots[p] = (pots[p] or 0) + 1 end end
  return { hp = exp.hp, maxHp = exp.maxHp, gold = exp.gold, relics = relics, deck = deck, pots = pots }
end

local function diffBag(a, b, name)
  local plus, minus = {}, {}
  local ks = {}
  for k in pairs(a) do ks[k] = true end
  for k in pairs(b) do ks[k] = true end
  local list = {}
  for k in pairs(ks) do list[#list + 1] = k end
  table.sort(list)
  for _, k in ipairs(list) do
    local d = (b[k] or 0) - (a[k] or 0)
    for _ = 1, math.max(0, d) do plus[#plus + 1] = name(k) end
    for _ = 1, math.max(0, -d) do minus[#minus + 1] = name(k) end
  end
  return plus, minus
end

local function changes(a, b)
  local parts = {}
  if a.hp ~= b.hp or a.maxHp ~= b.maxHp then parts[#parts + 1] = ("PV %d/%d → %d/%d"):format(a.hp, a.maxHp, b.hp, b.maxHp) end
  if a.gold ~= b.gold then parts[#parts + 1] = ("or %d → %d"):format(a.gold, b.gold) end
  local p, m = diffBag(a.deck, b.deck, function(k) return k end)
  if #p > 0 then parts[#parts + 1] = "deck + " .. table.concat(p, ", ") end
  if #m > 0 then parts[#parts + 1] = "deck − " .. table.concat(m, ", ") end
  p, m = diffBag(a.relics, b.relics, relicName)
  if #p > 0 then parts[#parts + 1] = "bibelot + " .. table.concat(p, ", ") end
  if #m > 0 then parts[#parts + 1] = "bibelot − " .. table.concat(m, ", ") end
  p, m = diffBag(a.pots, b.pots, potionName)
  if #p > 0 then parts[#parts + 1] = "potion + " .. table.concat(p, ", ") end
  if #m > 0 then parts[#parts + 1] = "potion − " .. table.concat(m, ", ") end
  return table.concat(parts, " ; ")
end

-- Rejoue rec et écrit le récit par out(ligne). opts : bot (nom d'un bot de Sim/bots.lua), human (paramètres).
-- Renvoie le résultat de Record.replay.
function M.narrate(rec, out, opts)
  local ns = M.ns
  local X, Combat, R = ns.Expedition, ns.Combat, ns.Record
  opts = opts or {}
  local st = { combat = nil, round = nil, reward = nil, shop = nil, event = nil, snap = nil, hpTurn = nil }

  local function fightHeader(exp, c)
    local f = exp.fight or {}
    local names = {}
    for _, e in ipairs(c.enemies) do names[#names + 1] = Combat.enemyName(e) .. " (" .. e.hp .. " PV)" end
    out("")
    out(("=== %s · étape %d · %s : %s ==="):format(zoneName(exp.zone), exp.floor or 0, KIND[f.kind] or tostring(f.kind),
      table.concat(names, ", ")))
    out(("    entrée : PV %d/%d, deck %d cartes"):format(exp.hp, exp.maxHp, #exp.deck))
    flushEvents(c, function() end, "")
  end

  local function turnHeader(c)
    local p = c.player
    out(("  -- Tour %d : PV %d/%d, Block %d, mana %s/%s%s%s"):format(c.round, p.hp, p.maxHp, p.block or 0,
      tostring(p.mana), tostring(maxMana(c)), resText(c),
      (statusLine(p) ~= "" and (", états : " .. statusLine(p)) or "")))
    for _, e in ipairs(c.enemies) do
      if not e.dead then
        local sl = statusLine(e)
        out(("     %s %d/%d PV%s%s — intention : %s"):format(Combat.enemyName(e), e.hp, e.maxHp,
          (e.block or 0) > 0 and (", Block " .. e.block) or "", sl ~= "" and (", " .. sl) or "", intentLine(c, e)))
      end
    end
    out("     main : " .. handLine(c))
    if opts.bot then
      local ok, s = pcall(botTurn, c, opts.bot, opts.human)
      out("     bot " .. opts.bot .. " jouerait : " .. (ok and s or ("(erreur : " .. tostring(s) .. ")")))
    end
  end

  local function before(exp, a, i)
    local ph = exp.phase
    st.snap = snapshot(exp)
    st.phase = ph
    if ph == "combat" then
      local c = exp.combat
      st.c = c
      if c ~= st.combat then
        st.combat, st.round = c, nil
        fightHeader(exp, c)
      end
      if c.round ~= st.round and c.phase == "player" then
        st.round = c.round
        turnHeader(c)
      end
      st.hpTurn = c.player.hp
      local v = a[1]
      if v == "play" then
        local inst = c.hand[a[2]]
        local tgt = a[3] and c.enemies[a[3]]
        local ok, cost = pcall(Combat.cost, c, inst)
        out(("   > %s%s (coût %s)%s"):format(inst and cardName(inst) or ("carte " .. tostring(a[2])),
          tgt and (" → " .. Combat.enemyName(tgt)) or "", ok and tostring(cost) or "?",
          a[4] == "nospend" and " sans dépenser" or ""))
      elseif v == "potion" then
        local pots = c.player.potions or exp.potions
        local tgt = a[3] and c.enemies[a[3]]
        out("   > potion " .. potionName(pots[a[2]]) .. (tgt and (" → " .. Combat.enemyName(tgt)) or ""))
      elseif v == "endTurn" then
        local keep = a[2] and instByUid(c, a[2])
        out("   > fin du tour" .. (keep and (" (garde " .. cardName(keep) .. ")") or ""))
      else
        out("   > " .. table.concat((function() local t = {} for k = 1, 4 do if a[k] ~= nil then t[#t + 1] = tostring(a[k]) end end return t end)(), " "))
      end
      return
    end
    -- hors combat : options proposées, une fois par étape
    if ph == "start" then
      if exp.talentEpics then
        local t = {}
        for k, id in ipairs(exp.talentEpics) do t[#t + 1] = k .. ":" .. cardName(id) end
        out("Épique de départ (talent) proposée : " .. table.concat(t, ", "))
      elseif exp.startRelics then
        local t = {}
        for k, id in ipairs(exp.startRelics) do t[#t + 1] = k .. ":" .. relicName(id) end
        out("Bibelot de départ proposé : " .. table.concat(t, ", "))
      end
    elseif ph == "map" and a[1] == "path" then
      local nx = X.nextNodes(exp)
      local t = {}
      for _, id in ipairs(nx) do
        local n = exp.map.nodes[id]
        t[#t + 1] = (KIND[n.kind] or n.kind) .. (id == a[2] and "*" or "")
      end
      local n = exp.map.nodes[a[2]]
      out("")
      out(("Carte (%s, étape %d → %d, PV %d/%d, or %d) : %s → %s"):format(zoneName(exp.zone), exp.floor or 0,
        n and n.floor or 0, exp.hp, exp.maxHp, exp.gold, table.concat(t, " / "), n and (KIND[n.kind] or n.kind) or "?"))
    elseif ph == "reward" and exp.reward ~= st.reward then
      st.reward = exp.reward
      local r = exp.reward
      local parts = {}
      if r.goldGained then parts[#parts + 1] = "or +" .. r.goldGained end
      if r.relic then parts[#parts + 1] = "bibelot " .. relicName(r.relic) end
      if r.potion then parts[#parts + 1] = "potion " .. potionName(r.potion) .. (r.potionTaken and "" or " (pas prise)") end
      out("Récompense (" .. tostring(r.kind) .. ") : " .. (#parts > 0 and table.concat(parts, ", ") or "—"))
      if r.cards and #r.cards > 0 then
        local t = {}
        for k, id in ipairs(r.cards) do t[#t + 1] = k .. ":" .. cardName(id) end
        out("  cartes proposées : " .. table.concat(t, ", "))
      end
      if r.epics then
        local t = {}
        for k, id in ipairs(r.epics) do t[#t + 1] = k .. ":" .. cardName(id) end
        out("  épique proposée : " .. table.concat(t, ", "))
      end
    elseif ph == "merchant" and exp.shop ~= st.shop then
      st.shop = exp.shop
      local s = exp.shop
      out(("Marchand (or %d, retrait %d) :"):format(exp.gold, X.removePrice(exp)))
      local t = {}
      for k, it in ipairs(s.cards) do
        t[#t + 1] = k .. ":" .. cardName({ id = it.id, up = it.up or false }) .. " " .. it.price .. (it.epic and " (épique)" or "")
      end
      out("  cartes : " .. table.concat(t, ", "))
      t = {}
      for k, it in ipairs(s.relics) do t[#t + 1] = k .. ":" .. relicName(it.id) .. " " .. it.price end
      out("  bibelots : " .. table.concat(t, ", "))
      t = {}
      for k, it in ipairs(s.potions) do t[#t + 1] = k .. ":" .. potionName(it.id) .. " " .. it.price end
      out("  potions : " .. table.concat(t, ", "))
    elseif ph == "event" and exp.event ~= st.event then
      st.event = exp.event
      local ev = exp.event.id and ns.Events[exp.event.id]
      out("Rencontre : " .. (ev and (ev.name or exp.event.id) or "aucune"))
      for _, o in ipairs(X.eventOptions(exp)) do
        out(("  %d: %s%s%s"):format(o.index, tostring(o.label), o.outcome and (" — " .. tostring(o.outcome)) or "",
          o.disabled and (" [impossible : " .. tostring(o.reason) .. "]") or ""))
      end
    elseif ph == "campfire" and a[1] ~= nil then
      out(("Feu de camp (PV %d/%d)"):format(exp.hp, exp.maxHp))
    elseif ph == "select" then
      out("Choix d'une carte du deck (" .. tostring(exp.select.kind) .. ") : " .. deckNames(exp.deck))
    elseif ph == "transit" and exp.transit then
      out(("Passage %s → %s (soin +%d)"):format(zoneName(exp.transit.from), zoneName(exp.transit.to),
        exp.transit.healed or 0))
    end
    -- l'action choisie
    local v = a[1]
    local s
    if v == "pickCard" then s = "prend " .. cardName(exp.reward.cards[a[2]])
    elseif v == "pickEpic" then s = "prend l'épique " .. cardName(exp.reward.epics[a[2]])
    elseif v == "skipCards" then s = "refuse les cartes"
    elseif v == "skipEpic" then s = "refuse l'épique"
    elseif v == "takePotion" then s = "prend la potion"
    elseif v == "buyCard" then local it = exp.shop.cards[a[2]] s = "achète " .. (it and cardName({ id = it.id, up = it.up or false }) or "?")
    elseif v == "buyRelic" then local it = exp.shop.relics[a[2]] s = "achète " .. (it and relicName(it.id) or "?")
    elseif v == "buyPotion" then local it = exp.shop.potions[a[2]] s = "achète " .. (it and potionName(it.id) or "?")
    elseif v == "remove" then s = "retire " .. (exp.deck[a[2]] and cardName(exp.deck[a[2]]) or "?")
    elseif v == "rest" then s = "se repose"
    elseif v == "upgrade" then s = "améliore " .. (exp.deck[a[2]] and cardName(exp.deck[a[2]]) or "?")
    elseif v == "campAction" then s = "action " .. tostring(a[2])
    elseif v == "choose" then
      local ev = exp.event and exp.event.id and ns.Events[exp.event.id]
      local ch = ev and ev.choices[a[2]]
      s = "répond " .. a[2] .. (ch and (" : " .. tostring(ch.label)) or "")
    elseif v == "select" then s = "choisit " .. (exp.deck[a[2]] and cardName(exp.deck[a[2]]) or "?")
    elseif v == "skipSelect" then s = "ne choisit rien"
    elseif v == "startRelic" then s = "prend " .. relicName(exp.startRelics[a[2]])
    elseif v == "talentEpic" then s = "prend " .. cardName(exp.talentEpics[a[2]])
    elseif v == "discardPotion" then s = "jette " .. potionName(exp.potions[a[2]])
    elseif v == "abandon" then s = "ABANDONNE l'expédition"
    elseif v == "leave" or v == "continue" or v == "path" or v == "skipStartRelic" or v == "skipTalentEpic" then s = nil
    else s = v end
    if s then out("  > " .. s) end
  end

  local function after(exp, a, i, ok, why, cp)
    if not ok then out("    (refusé : " .. tostring(why) .. ")") end
    if st.phase == "combat" then
      local c = st.c
      local acc = flushEvents(c, out, "     ")
      if a[1] == "endTurn" then
        if #acc.drawn > 0 and exp.combat == c and not c.result then
          out("     pioche : " .. table.concat(acc.drawn, ", "))
        end
        out(("     → tour ennemi : PV %d → %d (dégâts subis %d, absorbés par le Block %d)"):format(
          st.hpTurn or 0, math.max(0, c.player.hp), acc.taken, acc.absorbed))
      else
        if #acc.drawn > 0 then out("     pioche : " .. table.concat(acc.drawn, ", ")) end
        if acc.lines == 0 and #acc.drawn == 0 and ok then out("     (aucun effet visible)") end
      end
      if exp.combat ~= c then
        out(("  Fin du combat : %s, PV %d/%d, %d tours"):format(c.result == "won" and "victoire"
          or c.result == "lost" and "défaite" or tostring(c.result or "abandon"), exp.hp, exp.maxHp, c.round))
        st.combat = nil
      end
    else
      local d = changes(st.snap, snapshot(exp))
      if d ~= "" then out("    → " .. d) end
    end
    if exp.phase == "done" then
      out("")
      out(("=== Fin de l'expédition : %s (%s, étape %d), PV %d/%d, or %d, deck %d ==="):format(tostring(exp.result),
        zoneName(exp.zone), exp.floor or 0, exp.hp, exp.maxHp, exp.gold, #exp.deck))
    end
  end

  local devArmed
  local fire = X.fire
  local function note(exp, s)
    local ids = s:match("^@dev (.+)$")
    if not ids then return false end
    local list = {}
    for id in ids:gmatch("%S+") do list[#list + 1] = id end
    devArmed = list
    out("  (combat de test armé : " .. table.concat(list, ", ") .. ")")
    return true
  end
  -- combat de test (/slay dev fight) : même remplacement que l'interface (UI/Controller.lua)
  X.fire = function(exp, name, a, b, d)
    local r = fire(exp, name, a, b, d)
    if name == "onFightStart" and devArmed then
      b.encounter = ns.Util.copy(devArmed)
      a.encounter = ns.Util.copy(devArmed)
      a.test = true
      devArmed = nil
    end
    return r
  end
  local okRun, res = pcall(R.replay, rec, { hooks = { before = before, after = after, note = note } })
  X.fire = fire
  if not okRun then error(res, 0) end
  return res
end

-- En-tête : options de départ de l'expédition.
function M.header(rec, out, current)
  local ns = M.ns
  local s = rec.start or {}
  local u = s.unlocks or {}
  out(("Expédition du %s · %s · clé %s · graine %s"):format(tostring(rec.date or "?"), tostring(rec.class),
    tostring(rec.key), tostring(rec.seed)))
  out(("Version de l'addon : enregistrée %s, actuelle %s ; règles d'expédition v%s (actuelles v%s)"):format(
    tostring(rec.addon or "?"), tostring(current or "?"), tostring(rec.ev), tostring(ns.Expedition.VERSION)))
  if (rec.addon and current and rec.addon ~= current) or rec.ev ~= ns.Expedition.VERSION then
    out("ATTENTION : version différente de celle de l'enregistrement ; le rejeu s'arrête au premier écart.")
  end
  out(("Palier de contenu %s, palier commun %s, zones gagnées : %s"):format(tostring(u.level), tostring(u.common),
    (function()
      local t = {}
      for z, k in pairs(u.won or {}) do t[#t + 1] = zoneName(z) .. " (clé " .. tostring(k) .. ")" end
      table.sort(t)
      return #t > 0 and table.concat(t, ", ") or "aucune"
    end)()))
  local tl = {}
  for id, r in pairs(u.talents or {}) do
    local n = ns.Talent and ns.Talent.node and ns.Talent.node(rec.class, id)
    tl[#tl + 1] = (n and n.name or id) .. " " .. tostring(r)
  end
  table.sort(tl)
  out("Talents : " .. (#tl > 0 and table.concat(tl, ", ") or "aucun") .. (u.spec and (" ; voie " .. tostring(u.spec)) or ""))
end

-- Ligne de la liste (list=1).
function M.listLine(i, rec)
  local res = rec.result or (rec.live and "en cours" or "interrompue")
  return ("%2d. %-16s %-8s clé %s  zone %-20s %-11s %5d actions  (addon %s)"):format(i, tostring(rec.date or "?"),
    tostring(rec.class), tostring(rec.key), zoneName(M.ns.Record.reached(rec)), res, #rec.a, tostring(rec.addon or "?"))
end

-- Version du TOC (## Version:).
function M.tocVersion(dir)
  local f = io.open((dir or root) .. "/SlayTheDragon.toc", "r")
  if not f then return nil end
  for line in f:lines() do
    local v = line:match("^##%s*Version:%s*(%S+)")
    if v then f:close() return v end
  end
  f:close()
  return nil
end

-- Message de divergence (nil si le rejeu est allé au bout).
function M.divergence(rec, res)
  local d = res.diverged
  if not d then return nil end
  local function mark(m)
    if not m then return "—" end
    return ("PV %s/%s, or %s, deck %s, %s étape %s"):format(tostring(m.hp), tostring(m.mhp), tostring(m.gold),
      tostring(m.deck), tostring(m.zone), tostring(m.floor))
  end
  local s = ("DIVERGENCE à l'entrée %d/%d (%s) : %s"):format(d.i, #rec.a, tostring(rec.a[d.i]), d.why)
  if d.want or d.got then s = s .. "\n  enregistré : " .. mark(d.want) .. "\n  rejoué     : " .. mark(d.got) end
  return s .. "\n  Le récit s'arrête ici : la suite ne correspondrait plus à la partie jouée."
end

---------------------------------------------------------------------------
-- Ligne de commande
---------------------------------------------------------------------------

if isMain then
  local opts = {}
  local path
  for _, a in ipairs(arg) do
    local k, v = a:match("^(%w+)=(.*)$")
    if k then opts[k] = v else path = a end
  end
  if not path then
    io.stderr:write("usage : lua5.1 Sim/replay.lua <SavedVariables/SlayTheDragon.lua> [n=N] [list=1] [bot=human]\n")
    os.exit(2)
  end
  local ns = dofile(root .. "/Sim/load.lua")(root)
  M.init(ns)
  local db, err = M.loadSaved(path)
  if not db then io.stderr:write("lecture impossible : " .. tostring(err) .. "\n") os.exit(1) end
  local list = type(db.records) == "table" and db.records or {}
  if #list == 0 then print("Aucune expédition enregistrée dans ce fichier.") os.exit(0) end
  if opts.list then
    for i, rec in ipairs(list) do print(M.listLine(i, rec)) end
    os.exit(0)
  end
  local n = tonumber(opts.n) or #list
  local rec = list[n]
  if not rec then io.stderr:write("pas d'expédition n°" .. tostring(opts.n) .. " (1 à " .. #list .. ")\n") os.exit(1) end
  local human
  if opts.skill then human = ns.Bots.humanParams({ skill = tonumber(opts.skill) }) end
  M.header(rec, print, M.tocVersion())
  local res = M.narrate(rec, print, { bot = opts.bot, human = human })
  print("")
  local msg = M.divergence(rec, res)
  if msg then
    print(msg)
    os.exit(3)
  end
  print(("Rejeu complet : %d entrées, %d points de contrôle vérifiés%s."):format(res.n, res.cps,
    rec.result and "" or " (expédition non terminée : rejouée jusqu'à la dernière action)"))
end

return M
