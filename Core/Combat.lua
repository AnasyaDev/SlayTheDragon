-- Moteur de combat. État = données simples (copiable, sauvegardable) ;
-- les définitions (cartes, ennemis, bibelots) sont référencées par id.
--
-- Déroulé d'un round :
--   début du tour joueur : Absorption à 0, Suppression retirée, Douleur/Récupération,
--     résolution de l'incantation, retour des recharges, pioche, mana, intentions ennemies
--   le joueur joue (Combat.play)
--   Combat.endTurn : fin du tour joueur (défausse), tour ennemi, fin du round (durées)
local _, ns = ...

local U, Rng, Card = ns.Util, ns.Rng, ns.Card
local floor, min, max = math.floor, math.min, math.max

local Combat = {}
ns.Combat = Combat

Combat.HAND_MAX = 10
Combat.DRAW_PER_TURN = 5
Combat.BASE_MANA = 3
Combat.MAX_ENEMIES = 5
Combat.ATONEMENT_HEAL = 2
Combat.POTION_SLOTS = 3

---------------------------------------------------------------------------
-- Journal d'événements (animations de l'interface, métriques)
---------------------------------------------------------------------------

local function uref(unit)
  if unit == nil then return nil end
  if unit.side == "player" then return "player" end
  return unit.uid
end
Combat.uref = uref

local function log(c, ev)
  if c.quiet then return end
  local evs = c.events
  evs[#evs + 1] = ev
end
Combat.log = log

local function stat(c, key, n)
  local s = c.stats
  if s then s[key] = (s[key] or 0) + (n or 1) end
end

local function statById(c, key, id, n)
  local s = c.stats
  if s then
    local t = s[key]
    t[id] = (t[id] or 0) + (n or 1)
  end
end

---------------------------------------------------------------------------
-- Crochets : pouvoirs joués et bibelots
---------------------------------------------------------------------------
-- Un pouvoir (carte power) ou un bibelot déclare def.hooks[nom] = function(c, src, ...)
-- où src est l'instance du pouvoir ou l'id du bibelot.

-- Valeur modifiée : chaque crochet reçoit (c, src, v, ...) et renvoie la nouvelle valeur.
function Combat.modify(c, name, v, a, b, d)
  local powers = c.player.powers
  for i = 1, #powers do
    local h = Card.def(powers[i]).hooks
    h = h and h[name]
    if h then v = h(c, powers[i], v, a, b, d) end
  end
  local relics = c.relics
  for i = 1, #relics do
    local r = ns.Relics[relics[i]]
    local h = r and r.hooks and r.hooks[name]
    if h then v = h(c, relics[i], v, a, b, d) end
  end
  local affixes = c.affixes -- affixes mythiques (ns.Affixes), mêmes crochets
  if affixes then
    for i = 1, #affixes do
      local af = ns.Affixes[affixes[i]]
      local h = af and af.hooks and af.hooks[name]
      if h then v = h(c, affixes[i], v, a, b, d) end
    end
  end
  return v
end

-- Notification : chaque crochet reçoit (c, src, ...) ; s'il renvoie true, on s'arrête
-- et fire renvoie true (sert à « empêcher la mort », par exemple).
function Combat.fire(c, name, a, b, d)
  local powers = c.player.powers
  for i = 1, #powers do
    local h = Card.def(powers[i]).hooks
    h = h and h[name]
    if h and h(c, powers[i], a, b, d) then return true end
  end
  local relics = c.relics
  for i = 1, #relics do
    local r = ns.Relics[relics[i]]
    local h = r and r.hooks and r.hooks[name]
    if h and h(c, relics[i], a, b, d) then return true end
  end
  local affixes = c.affixes
  if affixes then
    for i = 1, #affixes do
      local af = ns.Affixes[affixes[i]]
      local h = af and af.hooks and af.hooks[name]
      if h and h(c, affixes[i], a, b, d) then return true end
    end
  end
  return false
end

---------------------------------------------------------------------------
-- États
---------------------------------------------------------------------------

function Combat.status(unit, id)
  return unit.st[id] or 0
end

function Combat.applyStatus(c, unit, id, n)
  if unit.dead then return end
  local def = ns.Statuses[id]
  if not def then error("unknown status: " .. tostring(id)) end
  if id == "stunned" and unit.boss then
    log(c, { t = "immune", unit = uref(unit), id = id })
    return
  end
  local old = unit.st[id] or 0
  if def.duration and not def.debuff and unit.side == "player" and c.phase ~= "enemy" and n > 0 then
    -- Bienfait que le joueur se pose pendant son tour : ne décompte pas ce tour
    -- (voir Statuses.lua). Un reste non protégé couvrait déjà le tour en cours :
    -- on le compte une fois de moins avant d'ajouter n.
    if old > 0 and not unit.fresh[id] then old = old - 1 end
    unit.st[id] = old + n
    unit.fresh[id] = true
    log(c, { t = "status", unit = uref(unit), id = id, n = n, total = old + n })
    return
  end
  local v = old + n
  if v <= 0 then v = nil end
  unit.st[id] = v
  if def.duration and c.phase == "enemy" and v then unit.fresh[id] = true end
  log(c, { t = "status", unit = uref(unit), id = id, n = n, total = v or 0 })
end

-- Vrai si l'unité porte au moins un état négatif.
function Combat.hasDebuff(unit)
  for id in pairs(unit.st) do
    if ns.Statuses[id].debuff then return true end
  end
  return false
end

-- Retire tous les états négatifs de l'unité ; renvoie le nombre d'états retirés.
function Combat.cleanse(c, unit)
  local ids = {}
  for id in pairs(unit.st) do
    if ns.Statuses[id].debuff then ids[#ids + 1] = id end
  end
  table.sort(ids)
  for i = 1, #ids do
    unit.st[ids[i]] = nil
    unit.fresh[ids[i]] = nil
  end
  if #ids > 0 then log(c, { t = "cleanse", unit = uref(unit), n = #ids }) end
  return #ids
end

local function tickPeriodic(c, unit)
  local pain = unit.st.pain
  if pain and pain > 0 then
    log(c, { t = "tick", unit = uref(unit), id = "pain", n = pain })
    Combat.dealDamage(c, nil, unit, pain, true)
    if pain - 1 > 0 then unit.st.pain = pain - 1 else unit.st.pain = nil end
    if unit.dead or c.result then return end
  end
  local regen = unit.st.regen
  if regen and regen > 0 then
    Combat.heal(c, unit, regen)
    if regen - 1 > 0 then unit.st.regen = regen - 1 else unit.st.regen = nil end
  end
end

local function decayUnit(unit)
  local st, fresh = unit.st, unit.fresh
  for id, v in pairs(st) do
    if ns.Statuses[id].duration then
      if fresh[id] then
        fresh[id] = nil
      elseif v <= 1 then
        st[id] = nil
      else
        st[id] = v - 1
      end
    end
  end
end

---------------------------------------------------------------------------
-- Dégâts, soins, Absorption
---------------------------------------------------------------------------

-- Dégâts d'un coup de src sur dst (src nil = dégâts sans source, ex. Douleur).
-- cardDef : définition de la carte à l'origine du coup, s'il y en a une.
function Combat.calcDamage(c, src, dst, base, cardDef)
  local dmg = base
  if src then
    dmg = dmg + (src.st.force or 0)
    if src.side == "player" then dmg = Combat.modify(c, "damage", dmg, dst, cardDef)
    else dmg = Combat.modify(c, "enemyDamage", dmg, src, dst) end
    if (src.st.demoralized or 0) > 0 then dmg = floor(dmg * 0.75) end
  end
  if dst then
    if (dst.st.armor_broken or 0) > 0 then dmg = floor(dmg * 1.25) end
    if (dst.st.halved or 0) > 0 then dmg = floor(dmg / 2) end
  end
  if dmg < 0 then dmg = 0 end
  return dmg
end

-- Applique des dégâts déjà calculés. pierce = ignore l'Absorption.
-- Renvoie (PV perdus, absorbés).
function Combat.dealDamage(c, src, dst, amount, pierce)
  if dst.dead or c.result then return 0, 0 end
  local absorbed = 0
  if not pierce then
    absorbed = min(dst.block, amount)
    dst.block = dst.block - absorbed
  end
  local loss = amount - absorbed
  if dst.side == "player" then stat(c, "hpLost", min(loss, max(dst.hp, 0))) end
  dst.hp = dst.hp - loss
  log(c, { t = "damage", src = uref(src), dst = uref(dst), amount = amount, absorbed = absorbed, loss = loss })
  if dst.hp <= 0 then
    Combat.kill(c, dst)
  elseif loss > 0 and dst.side == "enemy" then
    local def = ns.Enemies[dst.id]
    if def.onDamaged then def.onDamaged(c, dst, loss) end
  elseif loss > 0 and src and dst.side == "player" then
    Combat.fire(c, "onPlayerHit", src, loss)
  end
  return loss, absorbed
end

function Combat.heal(c, unit, n)
  if unit.dead then return 0 end
  if unit.side == "player" then n = Combat.modify(c, "heal", n) end
  local before = unit.hp
  unit.hp = min(unit.maxHp, unit.hp + n)
  local got = unit.hp - before
  if got > 0 then
    log(c, { t = "heal", unit = uref(unit), amount = got })
    if unit.side == "player" then stat(c, "healed", got) end
  end
  return got
end

function Combat.gainBlock(c, unit, n)
  if unit.side == "player" then n = Combat.modify(c, "block", n) end
  unit.block = unit.block + n
  log(c, { t = "block", unit = uref(unit), amount = n, total = unit.block })
end

function Combat.aliveEnemies(c)
  local list = {}
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    if not e.dead then list[#list + 1] = e end
  end
  return list
end

function Combat.enemyByUid(c, uid)
  for i = 1, #c.enemies do
    if c.enemies[i].uid == uid then return c.enemies[i], i end
  end
  return nil
end

local function checkVictory(c)
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    if not e.dead and not e.minion then return end
  end
  -- Plus d'ennemi principal : les sbires restants s'enfuient.
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    if not e.dead then
      e.dead = true
      e.fled = true
      log(c, { t = "flee", unit = e.uid })
    end
  end
  c.result = "won"
  Combat.fire(c, "onVictory")
  log(c, { t = "result", result = "won" })
end

function Combat.kill(c, unit)
  if unit.side == "player" then
    if Combat.fire(c, "preventDeath") then
      unit.hp = max(unit.hp, 1)
      log(c, { t = "saved", unit = "player" })
      return
    end
    unit.hp = 0
    unit.dead = true
    c.result = "lost"
    log(c, { t = "death", unit = "player" })
    log(c, { t = "result", result = "lost" })
    return
  end
  unit.hp = 0
  unit.block = 0
  unit.dead = true
  log(c, { t = "death", unit = unit.uid })
  local def = ns.Enemies[unit.id]
  if def.onDeath then def.onDeath(c, unit) end
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if o ~= unit and not o.dead then
      local od = ns.Enemies[o.id]
      if od.onAllyDeath then od.onAllyDeath(c, o, unit) end
    end
  end
  Combat.fire(c, "onEnemyDeath", unit)
  checkVictory(c)
end

---------------------------------------------------------------------------
-- Ennemis
---------------------------------------------------------------------------

function Combat.spawn(c, id)
  if #Combat.aliveEnemies(c) >= Combat.MAX_ENEMIES then return nil end
  local def = ns.Enemies[id]
  if not def then error("unknown enemy: " .. tostring(id)) end
  local hp = def.hp
  if type(hp) == "table" then hp = Rng.int(c.rng.ai, hp[1], hp[2]) end
  hp = Combat.modify(c, "enemyHp", hp, def)
  local e = {
    side = "enemy", uid = c.nextUid, id = id,
    hp = hp, maxHp = hp, block = 0, st = {}, fresh = {}, mem = {},
    boss = def.boss or false, minion = def.minion or false,
    dead = false, intent = nil, interrupted = false,
  }
  c.nextUid = c.nextUid + 1
  c.enemies[#c.enemies + 1] = e
  if def.init then def.init(c, e) end
  log(c, { t = "spawn", unit = e.uid, id = id })
  if c.phase == "player" then Combat.chooseIntent(c, e) end
  return e
end

-- IA par défaut : boucle sur def.pattern (départ au hasard si def.randomStart).
function Combat.chooseIntent(c, e)
  local def = ns.Enemies[e.id]
  local move
  if def.ai then
    move = def.ai(c, e, c.rng.ai)
  else
    local pat = def.pattern
    local idx = e.mem.idx
    if not idx then
      idx = def.randomStart and Rng.int(c.rng.ai, 1, #pat) or 1
    else
      idx = idx % #pat + 1
    end
    e.mem.idx = idx
    move = pat[idx]
  end
  if not def.moves[move] then error(e.id .. ": unknown move " .. tostring(move)) end
  e.intent = move
  e.interrupted = false
  log(c, { t = "intent", unit = e.uid, move = move })
end

-- Résumé d'intention pour l'affichage et les bots.
function Combat.intentInfo(c, e)
  local def = ns.Enemies[e.id]
  local mv = def.moves[e.intent]
  local info = { move = e.intent, name = mv.name, kind = mv.intent, cast = mv.cast or false,
    interrupted = e.interrupted, stunned = (e.st.stunned or 0) > 0, damage = 0, times = 0 }
  for i = 1, #mv.actions do
    local a = mv.actions[i]
    if a[1] == "attack" then
      info.damage = Combat.calcDamage(c, e, c.player, a[2])
      info.times = a.times or 1
      if a.interrupts then info.interrupts = true end
    end
  end
  return info
end

local function mostDamagedAlly(c)
  local best, gap = nil, 0
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if not o.dead and o.maxHp - o.hp > gap then best, gap = o, o.maxHp - o.hp end
  end
  return best
end

local function interruptPlayer(c, by)
  local cast = c.player.cast
  if not cast then return end
  if Combat.fire(c, "preventInterrupt", by) then
    log(c, { t = "interrupt_prevented", src = uref(by), dst = "player", card = cast.card.id })
    return
  end
  c.player.cast = nil
  c.discard[#c.discard + 1] = cast.card
  stat(c, "castsInterrupted")
  log(c, { t = "interrupt", src = uref(by), dst = "player", card = cast.card.id })
end

Combat.interruptPlayer = interruptPlayer

local function executeMove(c, e)
  local def = ns.Enemies[e.id]
  local mv = def.moves[e.intent]
  if mv.cast then
    stat(c, "enemyCasts")
    if e.interrupted then
      stat(c, "enemyCastsInterrupted")
      log(c, { t = "cast_lost", unit = e.uid, move = e.intent })
      e.mem.last = e.intent
      return
    end
  end
  log(c, { t = "act", unit = e.uid, move = e.intent })
  local p = c.player
  for i = 1, #mv.actions do
    local a = mv.actions[i]
    local k = a[1]
    if k == "attack" then
      for _ = 1, (a.times or 1) do
        local dmg = Combat.calcDamage(c, e, p, a[2])
        local loss = Combat.dealDamage(c, e, p, dmg)
        if c.result or e.dead then break end
        -- Coup qui interrompt : coupe l'incantation s'il fait perdre des PV.
        if a.interrupts and loss > 0 then interruptPlayer(c, e) end
      end
    elseif k == "block" then
      Combat.gainBlock(c, e, a[2])
    elseif k == "debuff" then
      Combat.applyStatus(c, p, a[2], a[3])
    elseif k == "buff" then
      Combat.applyStatus(c, e, a[2], a[3])
    elseif k == "buff_allies" then
      for j = 1, #c.enemies do
        local o = c.enemies[j]
        if not o.dead then Combat.applyStatus(c, o, a[2], a[3]) end
      end
    elseif k == "heal_ally" then
      local o = mostDamagedAlly(c)
      if o then Combat.heal(c, o, a[2]) end
    elseif k == "block_ally" then
      local list = Combat.aliveEnemies(c)
      local o = list[Rng.int(c.rng.ai, 1, #list)]
      Combat.gainBlock(c, o, a[2])
    elseif k == "interrupt" then
      interruptPlayer(c, e)
    elseif k == "summon" then
      for _ = 1, (a.count or 1) do Combat.spawn(c, a[2]) end
    elseif k == "fn" then
      a[2](c, e)
    else
      error("unknown enemy action: " .. tostring(k))
    end
    if c.result or e.dead then break end
  end
  e.mem.last = e.intent
end

---------------------------------------------------------------------------
-- Pioche
---------------------------------------------------------------------------

function Combat.drawCards(c, n)
  local hand, draw = c.hand, c.draw
  for _ = 1, n do
    if #hand >= Combat.HAND_MAX then return end
    if #draw == 0 then
      if #c.discard == 0 then return end
      c.draw = c.discard
      c.discard = {}
      draw = c.draw
      Rng.shuffle(c.rng.draw, draw)
      log(c, { t = "reshuffle", n = #draw })
    end
    local inst = draw[#draw]
    draw[#draw] = nil
    hand[#hand + 1] = inst
    statById(c, "drawn", inst.id)
    log(c, { t = "draw", card = inst.uid })
  end
end

local function returnCooldowns(c)
  local keep = {}
  local cds = c.cooldown
  for i = 1, #cds do
    local cd = cds[i]
    if cd.turns <= 0 then
      if #c.hand < Combat.HAND_MAX then
        c.hand[#c.hand + 1] = cd.card
        statById(c, "drawn", cd.card.id)
        log(c, { t = "cooldown_back", card = cd.card.uid })
      else
        c.discard[#c.discard + 1] = cd.card
      end
    else
      keep[#keep + 1] = { card = cd.card, turns = cd.turns - 1 }
    end
  end
  c.cooldown = keep
end

---------------------------------------------------------------------------
-- Cartes du joueur
---------------------------------------------------------------------------

function Combat.cost(c, inst)
  if c.player.flags.freeTurnActive then return 0 end
  local d = Card.def(inst)
  return max(0, Combat.modify(c, "cost", d.cost, d))
end

local function allowed(c, d)
  local powers = c.player.powers
  for i = 1, #powers do
    local h = Card.def(powers[i]).hooks
    h = h and h.allow
    if h and not h(c, powers[i], d) then return false end
  end
  return true
end

function Combat.canPlay(c, idx)
  if c.phase ~= "player" or c.result then return false, "phase" end
  local inst = c.hand[idx]
  if not inst then return false, "card" end
  local d = Card.def(inst)
  if d.unplayable then return false, "unplayable" end
  if Combat.cost(c, inst) > c.player.mana then return false, "mana" end
  if d.cast and c.player.cast then return false, "casting" end
  if not allowed(c, d) then return false, "forbidden" end
  if d.canPlay and not d.canPlay(c, inst) then return false, "condition" end
  return true
end

function Combat.needsTarget(inst)
  return Card.def(inst).target == "enemy"
end

-- Coups légaux : liste de { indexMain, indexCible|nil }.
function Combat.legalPlays(c)
  local list = {}
  for i = 1, #c.hand do
    if Combat.canPlay(c, i) then
      if Card.def(c.hand[i]).target == "enemy" then
        for j = 1, #c.enemies do
          if not c.enemies[j].dead then list[#list + 1] = { i, j } end
        end
      else
        list[#list + 1] = { i }
      end
    end
  end
  return list
end

local function afterPlay(c, inst, d)
  if d.power then
    local powers = c.player.powers
    powers[#powers + 1] = inst
    log(c, { t = "power", card = inst.id })
  elseif d.exhaust then
    c.exhaust[#c.exhaust + 1] = inst
  elseif d.cooldown then
    c.cooldown[#c.cooldown + 1] = { card = inst, turns = d.cooldown }
  else
    c.discard[#c.discard + 1] = inst
  end
end

local function firstAlive(c)
  for i = 1, #c.enemies do
    if not c.enemies[i].dead then return c.enemies[i] end
  end
  return nil
end

function Combat.resolveCard(c, inst, target)
  local d = Card.def(inst)
  local ctx = { card = inst, def = d, target = target, dealt = false, hits = 0 }
  local effects = d.effects
  for i = 1, #effects do
    local e = effects[i]
    local h = ns.Effects[e[1]]
    if not h then error(inst.id .. ": unknown effect " .. tostring(e[1])) end
    h(c, ctx, e)
    if c.result then break end
  end
  if ctx.dealt and not c.result and (c.player.st.atonement or 0) > 0 then
    Combat.heal(c, c.player, Combat.ATONEMENT_HEAL)
  end
  if not c.result then Combat.fire(c, "onCardPlayed", inst, ctx) end
  afterPlay(c, inst, d)
end

-- Joue la carte n° idx de la main sur l'ennemi n° tIdx (si elle vise).
function Combat.play(c, idx, tIdx)
  local ok, why = Combat.canPlay(c, idx)
  if not ok then return false, why end
  local inst = c.hand[idx]
  local d = Card.def(inst)
  local target
  if d.target == "enemy" then
    target = c.enemies[tIdx or 0]
    if not target or target.dead then return false, "target" end
  end
  local cost = Combat.cost(c, inst)
  table.remove(c.hand, idx)
  c.player.mana = c.player.mana - cost
  statById(c, "played", inst.id)
  log(c, { t = "play", card = inst.uid, id = inst.id, target = target and target.uid, cost = cost })
  if d.cast then
    c.player.cast = { card = inst, target = target and target.uid }
    stat(c, "castsStarted")
    log(c, { t = "cast_start", card = inst.uid })
    return true
  end
  Combat.resolveCard(c, inst, target)
  return true
end

local function resolveCast(c)
  local cast = c.player.cast
  c.player.cast = nil
  local target
  if Card.def(cast.card).target == "enemy" then
    target = cast.target and Combat.enemyByUid(c, cast.target)
    if not target or target.dead then target = firstAlive(c) end
  end
  log(c, { t = "cast_resolve", card = cast.card.uid })
  Combat.resolveCard(c, cast.card, target)
end

---------------------------------------------------------------------------
-- Potions et fuite
---------------------------------------------------------------------------
-- Une potion se boit pendant son tour, sans mana. c.player.potions[slot] = id | false.
-- Échecs : false, "over" (pas ton tour / combat fini), "potion" (emplacement vide ou
-- potion inconnue), "target" (cible absente ou morte).

function Combat.canUsePotion(c, slot, tIdx)
  if c.phase ~= "player" or c.result then return false, "over" end
  local id = c.player.potions[slot]
  if not id then return false, "potion" end
  local def = ns.Potions[id]
  if not def then return false, "potion" end
  if def.target then
    local t = c.enemies[tIdx or 0]
    if not t or t.dead then return false, "target" end
  end
  return true
end

-- Potions buvables : liste de { emplacement, indexCible|nil }, une seule entrée
-- par potion distincte (deux potions identiques donnent le même résultat).
function Combat.legalPotions(c)
  local list, seen = {}, {}
  if c.phase ~= "player" or c.result then return list end
  local pots = c.player.potions
  for slot = 1, #pots do
    local id = pots[slot]
    local def = id and ns.Potions[id]
    if def and not seen[id] then
      seen[id] = true
      if def.target then
        for j = 1, #c.enemies do
          if not c.enemies[j].dead then list[#list + 1] = { slot, j } end
        end
      else
        list[#list + 1] = { slot }
      end
    end
  end
  return list
end

function Combat.usePotion(c, slot, tIdx)
  local ok, why = Combat.canUsePotion(c, slot, tIdx)
  if not ok then return false, why end
  local id = c.player.potions[slot]
  local def = ns.Potions[id]
  local target = def.target and c.enemies[tIdx] or nil
  c.player.potions[slot] = false
  statById(c, "potions", id)
  log(c, { t = "potion", id = id, slot = slot, target = target and target.uid })
  local ctx = { potion = id, def = def, target = target, dealt = false, hits = 0 }
  for i = 1, #def.effects do
    local e = def.effects[i]
    local h = ns.Effects[e[1]]
    if not h then error(id .. ": unknown effect " .. tostring(e[1])) end
    h(c, ctx, e)
    if c.result then break end
  end
  if not c.result then Combat.fire(c, "onPotion", id, ctx) end
  return true
end

-- Fuite (Pierre de foyer...) : jamais contre un boss ; un bibelot doit l'autoriser
-- (crochet modify "canFlee"). Résultat "fled" : ni victoire ni défaite, sans récompense.
function Combat.canFlee(c)
  if c.phase ~= "player" or c.result then return false end
  for i = 1, #c.enemies do
    if c.enemies[i].boss and not c.enemies[i].dead then return false end
  end
  return Combat.modify(c, "canFlee", false) and true or false
end

function Combat.flee(c)
  if not Combat.canFlee(c) then return false end
  Combat.fire(c, "onFlee")
  c.result = "fled"
  log(c, { t = "result", result = "fled" })
  return true
end

---------------------------------------------------------------------------
-- Tours
---------------------------------------------------------------------------

function Combat.startPlayerTurn(c)
  c.round = c.round + 1
  c.phase = "player"
  stat(c, "turns")
  local p = c.player
  p.block = 0
  p.st.halved = nil
  log(c, { t = "turn", round = c.round })
  tickPeriodic(c, p)
  if c.result then return end
  if p.cast then resolveCast(c) end
  if c.result then return end
  returnCooldowns(c)
  Combat.drawCards(c, Combat.modify(c, "drawPerTurn", Combat.DRAW_PER_TURN))
  p.mana = Combat.modify(c, "maxMana", Combat.BASE_MANA)
  if p.flags.freeTurn then
    p.flags.freeTurn = nil
    p.flags.freeTurnActive = true
  end
  Combat.fire(c, "onTurnStart")
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    if not e.dead then Combat.chooseIntent(c, e) end
  end
end

function Combat.endPlayerTurn(c)
  Combat.fire(c, "onTurnEnd")
  local keep = {}
  for i = 1, #c.hand do
    local inst = c.hand[i]
    if Card.def(inst).retain then
      keep[#keep + 1] = inst
    else
      statById(c, "unplayed", inst.id)
      c.discard[#c.discard + 1] = inst
    end
  end
  c.hand = keep
  c.player.flags.freeTurnActive = nil
  c.phase = "enemy"
end

function Combat.enemyPhase(c)
  local n = #c.enemies -- les invocations de ce tour n'agissent pas
  for i = 1, n do
    local e = c.enemies[i]
    if not e.dead then
      e.block = 0
      tickPeriodic(c, e)
      if c.result then return end
      if not e.dead then
        if (e.st.stunned or 0) > 0 then
          e.st.stunned = e.st.stunned > 1 and e.st.stunned - 1 or nil
          log(c, { t = "stunned", unit = e.uid })
        else
          executeMove(c, e)
        end
      end
      if c.result then return end
    end
  end
end

function Combat.endRound(c)
  decayUnit(c.player)
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    if not e.dead then decayUnit(e) end
  end
end

function Combat.endTurn(c)
  if c.phase ~= "player" or c.result then return false end
  Combat.endPlayerTurn(c)
  if c.result then return true end
  Combat.enemyPhase(c)
  if c.result then return true end
  Combat.endRound(c)
  Combat.startPlayerTurn(c)
  return true
end

---------------------------------------------------------------------------
-- Création et copie
---------------------------------------------------------------------------

function Combat.newStats()
  return { turns = 0, hpLost = 0, healed = 0, castsStarted = 0, castsInterrupted = 0,
    enemyCasts = 0, enemyCastsInterrupted = 0, played = {}, drawn = {}, unplayed = {}, potions = {} }
end

-- opts : seed, hp, maxHp, deck = { {id=, up=}, ... }, encounter = { idEnnemi, ... },
--        relics = { id, ... }, potions = { id|false, ... } (POTION_SLOTS emplacements),
--        charges = { clé = valeur } (état de bibelots propre à l'expédition, relu après le combat),
--        affixes = { id de ns.Affixes, ... } (clés mythiques), stats = bool, quiet = bool
function Combat.new(opts)
  local seed = opts.seed or 1
  local c = {
    seed = seed, round = 0, phase = "start", result = nil,
    events = {}, quiet = opts.quiet or false, nextUid = 1,
    rng = {
      draw = Rng.stream(seed, "draw"),
      ai = Rng.stream(seed, "ai"),
      misc = Rng.stream(seed, "misc"),
    },
    player = {
      side = "player", hp = opts.hp, maxHp = opts.maxHp or opts.hp, block = 0,
      st = {}, fresh = {}, mana = 0, demence = 0, powers = {}, cast = nil, flags = {},
      potions = {},
    },
    draw = {}, hand = {}, discard = {}, exhaust = {}, cooldown = {},
    enemies = {}, relics = U.copyArr(opts.relics or {}), relicState = {},
    affixes = U.copyArr(opts.affixes or {}),
    charges = U.copyMap(opts.charges or {}),
    stats = opts.stats and Combat.newStats() or nil,
  }
  local potions = opts.potions or {}
  for i = 1, Combat.POTION_SLOTS do c.player.potions[i] = potions[i] or false end
  for i = 1, #opts.deck do
    local card = opts.deck[i]
    c.draw[#c.draw + 1] = Card.new(card.id, card.up, c.nextUid)
    c.nextUid = c.nextUid + 1
  end
  Rng.shuffle(c.rng.draw, c.draw)
  for i = 1, #opts.encounter do Combat.spawn(c, opts.encounter[i]) end
  Combat.fire(c, "onCombatStart")
  Combat.startPlayerTurn(c)
  return c
end

local copyArr, copyMap = U.copyArr, U.copyMap

local function copyUnit(u)
  local r = copyMap(u)
  r.st = copyMap(u.st)
  r.fresh = copyMap(u.fresh)
  if u.mem then r.mem = copyMap(u.mem) end
  if u.flags then r.flags = copyMap(u.flags) end
  if u.powers then r.powers = copyArr(u.powers) end
  if u.potions then r.potions = copyArr(u.potions) end
  return r
end

-- Copie rapide pour la recherche des bots : les instances de cartes sont partagées
-- (jamais modifiées), le journal et les statistiques ne sont pas copiés.
function Combat.clone(c)
  local n = copyMap(c)
  n.events = {}
  n.quiet = true
  n.stats = nil
  n.relicState = copyMap(c.relicState)
  n.charges = copyMap(c.charges)
  n.rng = { draw = copyMap(c.rng.draw), ai = copyMap(c.rng.ai), misc = copyMap(c.rng.misc) }
  n.player = copyUnit(c.player)
  n.hand = copyArr(c.hand)
  n.draw = copyArr(c.draw)
  n.discard = copyArr(c.discard)
  n.exhaust = copyArr(c.exhaust)
  local cds = {}
  for i = 1, #c.cooldown do
    cds[i] = { card = c.cooldown[i].card, turns = c.cooldown[i].turns }
  end
  n.cooldown = cds
  local es = {}
  for i = 1, #c.enemies do es[i] = copyUnit(c.enemies[i]) end
  n.enemies = es
  return n
end
