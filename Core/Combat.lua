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
-- Stunned posé sur un ennemi pendant son propre tour l'arrête tout de suite (décisions communes,
-- 12/11/2026) ; false = ancienne règle (l'action en cours part, il perd son prochain tour), pour la
-- simulation seulement (oldstun=1).
Combat.STUN_STOPS_TURN = true
Combat.TRAP_SLOTS = 3 -- Traps posées au plus (crochet « trapSlots »)

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

-- Règles de classe (Core/Classes/<classe>.lua) : ns.ClassRules[id] = { hooks = {...}, init = f(c, cls),
-- botKey = f(c) }. Leurs crochets passent AVANT ceux des pouvoirs, bibelots et affixes, avec
-- src = c.cls (état de la classe : table de données simples, sauvegardée et clonée avec le combat).
-- Liste des événements et contrat : docs/classes.md.
ns.ClassRules = ns.ClassRules or {}
local Rules = ns.ClassRules

-- Valeur modifiée : chaque crochet reçoit (c, src, v, ...) et renvoie la nouvelle valeur.
function Combat.modify(c, name, v, a, b, d)
  local cr = Rules[c.class]
  local ch = cr and cr.hooks and cr.hooks[name]
  if ch then v = ch(c, c.cls, v, a, b, d) end
  local powers = c.player.powers
  for i = 1, #powers do
    local h = Card.def(powers[i]).hooks
    h = h and h[name]
    if h then v = h(c, powers[i], v, a, b, d) end
  end
  local ps = c.passives -- cartes du deck à effet passif (def.deckHooks, Combat.new), src = l'instance
  if ps then
    for i = 1, #ps do
      local h = Card.def(ps[i]).deckHooks[name]
      if h then v = h(c, ps[i], v, a, b, d) end
    end
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
-- et fire renvoie true (sert à « empêcher la mort », par exemple) et la source qui l'a arrêtée
-- (l'état de classe, l'instance du pouvoir, l'id du bibelot ou de l'affixe).
function Combat.fire(c, name, a, b, d)
  local cr = Rules[c.class]
  local ch = cr and cr.hooks and cr.hooks[name]
  if ch and ch(c, c.cls, a, b, d) then return true, c.cls end
  local powers = c.player.powers
  for i = 1, #powers do
    local h = Card.def(powers[i]).hooks
    h = h and h[name]
    if h and h(c, powers[i], a, b, d) then return true, powers[i] end
  end
  local ps = c.passives
  if ps then
    for i = 1, #ps do
      local h = Card.def(ps[i]).deckHooks[name]
      if h and h(c, ps[i], a, b, d) then return true, ps[i] end
    end
  end
  local relics = c.relics
  for i = 1, #relics do
    local r = ns.Relics[relics[i]]
    local h = r and r.hooks and r.hooks[name]
    if h and h(c, relics[i], a, b, d) then return true, relics[i] end
  end
  local affixes = c.affixes
  if affixes then
    for i = 1, #affixes do
      local af = ns.Affixes[affixes[i]]
      local h = af and af.hooks and af.hooks[name]
      if h and h(c, affixes[i], a, b, d) then return true, affixes[i] end
    end
  end
  return false
end

---------------------------------------------------------------------------
-- Classe et ressource de classe
---------------------------------------------------------------------------
-- La ressource vit dans c.player.res (nombre, 0 au départ), bornée par classDef.resource.cap
-- (nil = sans plafond), remise à 0 au début du tour si resource.keep est faux.

function Combat.classDef(c)
  return ns.Classes[c.class]
end

function Combat.resourceDef(c)
  local cd = ns.Classes[c.class]
  return cd and cd.resource or nil
end

-- Plafond de la ressource : resource.cap, modifiable par le crochet « resCap » (Avatar : 10) ; nil = sans.
function Combat.resCap(c)
  local r = Combat.resourceDef(c)
  if not (r and r.cap) then return nil end
  return Combat.modify(c, "resCap", r.cap)
end

-- Ajoute n (négatif : retire) à la ressource, dans [0, plafond] ; renvoie la variation réelle.
-- why : raison facultative, passée au crochet « onResource ».
function Combat.gainRes(c, n, why)
  local p = c.player
  local v = (p.res or 0) + n
  local cap = Combat.resCap(c)
  if cap and v > cap then v = cap end
  if v < 0 then v = 0 end
  local delta = v - (p.res or 0)
  p.res = v
  if delta ~= 0 then
    log(c, { t = "resource", n = delta, total = v })
    Combat.fire(c, "onResource", delta, why)
  end
  return delta
end

-- Spend N : paie n si la ressource suffit (true), sinon rien (false).
function Combat.spendRes(c, n)
  if (c.player.res or 0) < n then return false end
  Combat.gainRes(c, -n, "spend")
  return true
end

-- Surge : dépense toute la ressource ; renvoie le montant dépensé.
function Combat.surge(c)
  local n = c.player.res or 0
  if n > 0 then Combat.gainRes(c, -n, "surge") end
  return n
end

-- Perte de PV hors attaque (coût « Pay N HP », effets) : ni Absorption, ni crochet de coup reçu.
function Combat.loseHp(c, n, why)
  local p = c.player
  if n <= 0 or p.dead or c.result then return 0 end
  stat(c, "hpLost", min(n, max(p.hp, 0)))
  p.hp = p.hp - n
  log(c, { t = "damage", dst = "player", amount = n, absorbed = 0, loss = n, why = why })
  if p.hp <= 0 then
    Combat.kill(c, p)
  else
    Combat.fire(c, "onHpLost", n, why, p.hp + n)
  end
  return n
end

-- Dernier souffle : vrai la première fois seulement pour cette clé, dans ce combat.
function Combat.lastBreath(c, key)
  local f = c.player.flags
  if f["lastBreath:" .. key] then return false end
  f["lastBreath:" .. key] = true
  return true
end

---------------------------------------------------------------------------
-- Conditions nommées des effets (« cond = nom ») et montants variables (« per = { k, nom } »)
---------------------------------------------------------------------------
-- CONDITIONS[nom](c, ctx, cible) -> booléen ; « status:<id> » : la cible porte l'état (affaiblissement)
-- ou le joueur le porte (bienfait). Une classe ajoute les siennes (Combat.CONDITIONS.bear = …).
Combat.CONDITIONS = {
  execute = function(c, ctx, t) return t ~= nil and not t.dead and t.hp * 2 <= t.maxHp end,
  spent = function(c, ctx) return ctx.spent == true end,
  surged = function(c, ctx) return (ctx.surge or 0) > 0 end,
}
-- AMOUNTS[nom](c, ctx, cible) -> nombre ; « per = { k, nom } » ajoute k × ce nombre à la valeur.
Combat.AMOUNTS = {
  surge = function(c, ctx) return ctx.surge or 0 end,
  res = function(c) return c.player.res or 0 end,
  block = function(c) return c.player.block end,
}

function Combat.test(c, ctx, name, t)
  -- « school:fire » : la carte est de cette école (champ libre `school` : holy, shadow, fire…)
  local sc = name:match("^school:(.+)$")
  if sc then return ctx.def ~= nil and ctx.def.school == sc end
  local st = name:match("^status:(.+)$")
  if st then
    local s = ns.Statuses[st]
    local unit = (s and s.debuff) and t or c.player
    return unit ~= nil and (unit.st[st] or 0) > 0
  end
  local f = Combat.CONDITIONS[name]
  if not f then error("unknown condition: " .. tostring(name)) end
  return f(c, ctx, t) and true or false
end

-- Valeur d'un effet : base + « more » (liste de { k, condition }) + « per » ({ k, montant }).
function Combat.amount(c, ctx, e, base, t)
  local v = base
  local more = e.more
  if more then
    for i = 1, #more do
      if Combat.test(c, ctx, more[i][2], t) then v = v + more[i][1] end
    end
  end
  local per = e.per
  if per then
    local f = Combat.AMOUNTS[per[2]]
    if not f then error("unknown amount: " .. tostring(per[2])) end
    v = v + per[1] * f(c, ctx, t)
  end
  return v
end

---------------------------------------------------------------------------
-- États
---------------------------------------------------------------------------

function Combat.status(unit, id)
  return unit.st[id] or 0
end

-- icon : clé d'art facultative de la source (l'icône d'un DoT peut varier : poison, saignement…),
-- gardée dans unit.stIcon[id] pour l'affichage seulement ; la règle ne change pas.
function Combat.applyStatus(c, unit, id, n, icon)
  if unit.dead then return end
  if icon then
    unit.stIcon = unit.stIcon or {}
    unit.stIcon[id] = icon
  end
  local def = ns.Statuses[id]
  if not def then error("unknown status: " .. tostring(id)) end
  -- crochet applySelf (c, src, n, état) : valeur d'un état posé sur le héros, toutes sources (Benediction)
  if unit.side == "player" and n > 0 then
    n = Combat.modify(c, "applySelf", n, id)
    if n <= 0 then return end
  end
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
    Combat.fire(c, "onStatusApplied", unit, id, n)
    return
  end
  local v = old + n
  -- plafond de l'état (def.max : Parry 3 ; def.flag : présent ou non, valeur 1)
  local cap = def.max or (def.flag and 1) or nil
  if cap and v > cap then v = cap end
  if v <= 0 then v = nil end
  unit.st[id] = v
  if def.duration and c.phase == "enemy" and v then unit.fresh[id] = true end
  -- Stunned posé sur un ennemi pendant SON tour (Trap, riposte, effet déclenché par son action) : son tour
  -- s'arrête tout de suite (executeMove lit le drapeau et consomme la charge) ; décisions communes.
  if id == "stunned" and v and c.phase == "enemy" and c.acting == unit.uid and Combat.STUN_STOPS_TURN then
    unit.stopTurn = true
  end
  log(c, { t = "status", unit = uref(unit), id = id, n = n, total = v or 0 })
  Combat.fire(c, "onStatusApplied", unit, id, n)
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

-- Déclenche le DoT de l'unité : dégâts égaux à sa valeur (sans Absorb), puis baisse (crochet
-- « dotDecay »). Appelé au début du tour du porteur, et tout de suite par une carte (Envenom :
-- « trigger the target's DoT »). Renvoie les dégâts.
function Combat.tickDot(c, unit)
  local pain = unit.st.pain
  if not pain or pain <= 0 or unit.dead then return 0 end
  log(c, { t = "tick", unit = uref(unit), id = "pain", n = pain })
  Combat.dealDamage(c, nil, unit, pain, true)
  local left = pain - Combat.modify(c, "dotDecay", 1, unit)
  if left > 0 then unit.st.pain = left else unit.st.pain = nil end
  if not c.result then Combat.fire(c, "onDotTick", unit, pain) end
  return pain
end

local function tickPeriodic(c, unit)
  local pain = unit.st.pain
  if pain and pain > 0 then
    Combat.tickDot(c, unit)
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
    if src.side == "player" then
      dmg = Combat.modify(c, "damage", dmg, dst, cardDef)
      -- multiplicateur des coups d'une carte Attack (crochet « attackMult », 1 par défaut ; Death Wish : 1,5),
      -- après Strength et les ajouts, avant Demoralized et Sundered, arrondi à l'inférieur
      if cardDef and cardDef.type == "attack" then
        local m = Combat.modify(c, "attackMult", 1, dst, cardDef)
        if m ~= 1 then dmg = floor(dmg * m) end
      end
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

-- Applique des dégâts déjà calculés. pierce = ignore l'Absorption. ctx : contexte de la carte à l'origine
-- du coup (Effects.damage), nil pour un coup sans carte (familier, riposte, bibelot).
-- Renvoie (PV perdus, absorbés). Un coup du joueur qui fait perdre des PV à un ennemi émet
-- « onDamageDealt » (cible, PV perdus, ctx|nil), le combat pas encore tranché.
function Combat.dealDamage(c, src, dst, amount, pierce, ctx)
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
  elseif loss > 0 and dst.side == "player" then
    if src then Combat.fire(c, "onPlayerHit", src, loss) end
    Combat.fire(c, "onHpLost", loss, src, dst.hp + loss)
  end
  if loss > 0 and src and src.side == "player" and dst.side == "enemy" and not c.result then
    Combat.fire(c, "onDamageDealt", dst, loss, ctx)
  end
  return loss, absorbed
end

-- Soin. Pour le joueur, un soin tenté (n > 0) émet « onHeal » (PV rendus, surplus au-delà du maximum).
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
  if unit.side == "player" and n > 0 and not c.result then Combat.fire(c, "onHeal", got, n - got) end
  return got
end

-- Absorb gagné. Le joueur n'en gagne pas si le crochet « canGainBlock » (vrai par défaut) dit faux
-- (Death Wish) ; un gain nul ou négatif après le crochet « block » ne fait rien.
function Combat.gainBlock(c, unit, n)
  if unit.side == "player" then
    if not Combat.modify(c, "canGainBlock", true) then return end
    n = Combat.modify(c, "block", n)
    if n <= 0 then return end
  end
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
    local saved, by = Combat.fire(c, "preventDeath")
    if saved then
      unit.hp = max(unit.hp, 1)
      log(c, { t = "saved", unit = "player", by = type(by) == "table" and by.id or by })
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
  local p = c.player
  local cast = p.cast
  if not cast then return end
  -- file d'incantations (crochet « castSlots ») : l'interruption coupe la plus récente
  local more = p.castMore
  if more and #more > 0 then cast = more[#more] end
  local prevented, pby = Combat.fire(c, "preventInterrupt", by)
  if prevented then
    -- by : ce qui a empêché l'interruption (id du bibelot ou de la carte de Power), pour l'affichage
    log(c, { t = "interrupt_prevented", src = uref(by), dst = "player", card = cast.card.id,
      by = type(pby) == "table" and pby.id or pby })
    return
  end
  if cast == p.cast then
    p.cast = nil
  else
    more[#more] = nil
    if #more == 0 then p.castMore = nil end
  end
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
  local p = c.player
  -- Étourdi pendant son propre tour : le reste du tour est annulé (aucun coup de l'attaque qui a
  -- déclenché l'effet), la charge de Stunned est consommée par ce tour-là.
  local function stopped()
    if not e.stopTurn then return false end
    e.stopTurn = nil
    e.st.stunned = (e.st.stunned or 0) > 1 and e.st.stunned - 1 or nil
    log(c, { t = "stunned", unit = e.uid, stopped = true, move = e.intent })
    stat(c, "enemyTurnsStopped")
    return true
  end
  -- « act » (élan de l'attaque à l'écran) seulement quand la première action part vraiment
  local acted = #mv.actions == 0
  if acted then log(c, { t = "act", unit = e.uid, move = e.intent }) end
  for i = 1, #mv.actions do
    local a = mv.actions[i]
    local k = a[1]
    if k == "attack" and #c.traps > 0 then
      -- Trap : la plus ancienne se déclenche avant les coups de cette attaque, sur l'attaquant
      Combat.triggerTrap(c, e)
    end
    if c.result or e.dead or stopped() then break end
    if not acted then
      acted = true
      log(c, { t = "act", unit = e.uid, move = e.intent })
    end
    local halt = false
    if k == "attack" then
      for _ = 1, (a.times or 1) do
        local dmg = Combat.calcDamage(c, e, p, a[2])
        -- coup subi avant réduction, coup par coup (Parry : avant l'Absorb) : le crochet peut réduire
        -- ou annuler le coup
        dmg = Combat.modify(c, "beforeHit", dmg, e, a)
        if c.result or e.dead then break end
        local loss, absorbed = Combat.dealDamage(c, e, p, dmg)
        if not c.result then Combat.fire(c, "afterHit", e, loss, absorbed) end
        if c.result or e.dead then break end
        -- Coup qui interrompt : coupe l'incantation s'il fait perdre des PV.
        if a.interrupts and loss > 0 then interruptPlayer(c, e) end
        if stopped() then halt = true break end
      end
      if halt then break end
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
    if c.result or e.dead or stopped() then break end
  end
  e.stopTurn = nil
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
      -- défausse remélangée dans la pioche (Scroll of Intellect) ; un crochet peut piocher à son tour
      Combat.fire(c, "onReshuffle", #draw)
      draw = c.draw
      if #draw == 0 or #hand >= Combat.HAND_MAX then return end
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
  return max(0, Combat.modify(c, "cost", d.cost, d, inst))
end

-- Nombre de sorts en cours et nombre de sorts tenus à la fois (crochet « castSlots », 1 par défaut).
function Combat.castCount(c)
  local p = c.player
  return (p.cast and 1 or 0) + (p.castMore and #p.castMore or 0)
end

function Combat.castSlots(c)
  return Combat.modify(c, "castSlots", 1)
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
  -- « Pay N HP » : jamais mortel, la carte est injouable s'il ferait tomber à 0
  local pay = Combat.payHpOf(c, d, inst)
  if pay > 0 and c.player.hp <= pay then return false, "hp" end
  -- ressource requise (Surge qui n'a de sens qu'avec de la ressource)
  if d.minRes and (c.player.res or 0) < d.minRes then return false, "resource" end
  -- incantation : emplacements pleins, sauf si elle partira tout de suite (« instantCast » interrogé
  -- sans rien consommer : commit = false)
  if d.cast and Combat.castCount(c) >= Combat.castSlots(c) and not Combat.isInstant(c, d, inst, false) then
    return false, "casting"
  end
  -- Trap : zone des pièges pleine (3 par défaut, crochet « trapSlots »), sauf Trap lancée tout de suite
  if d.trap and #c.traps >= Combat.modify(c, "trapSlots", Combat.TRAP_SLOTS)
      and not Combat.trapLaunch(c, d, inst) then return false, "traps" end
  if not allowed(c, d) then return false, "forbidden" end
  if d.canPlay and not d.canPlay(c, inst) then return false, "condition" end
  return true
end

-- Trap lancée au jeu (crochet « trapLaunch », faux par défaut ; Trap Launcher) : elle demande une cible
-- et se déclenche aussitôt sur elle, sans prendre de place dans la zone des pièges (Combat.launchTrap).
function Combat.trapLaunch(c, d, inst)
  if not d.trap then return false end
  return Combat.modify(c, "trapLaunch", false, d, inst) and true or false
end

-- Cible demandée par une carte : « enemy » (champ target, ou Trap lancée au jeu) ou nil.
function Combat.targetOf(c, d, inst)
  if d.target == "enemy" then return "enemy" end
  if c and d.trap and Combat.trapLaunch(c, d, inst) then return "enemy" end
  return d.target
end

-- c facultatif (sans lui, seule la définition compte : pas de Trap lancée).
function Combat.needsTarget(inst, c)
  return Combat.targetOf(c, Card.def(inst), inst) == "enemy"
end

-- Coups légaux : liste de { indexMain, indexCible|nil, sansDépense|nil }. Une carte « Spend N » dont
-- la ressource suffit apparaît deux fois : en dépensant (défaut) et sans dépenser (troisième champ vrai).
function Combat.legalPlays(c)
  local list = {}
  for i = 1, #c.hand do
    if Combat.canPlay(c, i) then
      local d = Card.def(c.hand[i])
      local both = d.spend and (c.player.res or 0) >= d.spend
      if Combat.targetOf(c, d, c.hand[i]) == "enemy" then
        for j = 1, #c.enemies do
          if not c.enemies[j].dead and Combat.castFits(c, d, c.hand[i], c.enemies[j]) then
            list[#list + 1] = { i, j }
            if both then list[#list + 1] = { i, j, true } end
          end
        end
      else
        list[#list + 1] = { i }
        if both then list[#list + 1] = { i, nil, true } end
      end
    end
  end
  return list
end

-- Coût en PV d'une carte (champ payHp, crochet « payHp » : Demonic Rune…), 0 sans coût.
function Combat.payHpOf(c, d, inst)
  if not d.payHp then return 0 end
  return max(0, Combat.modify(c, "payHp", d.payHp, d, inst))
end

-- Retire le pouvoir n° i (fin de durée, remplacé dans son emplacement) : il part à la défausse, ou
-- aux consumées si la carte porte replacedTo = "exhaust" (démon du Warlock).
function Combat.removePower(c, i, why)
  local p = c.player
  local inst = table.remove(p.powers, i)
  if not inst then return end
  if p.powerTurns then p.powerTurns[inst.uid] = nil end
  local pile = Card.def(inst).replacedTo == "exhaust" and c.exhaust or c.discard
  pile[#pile + 1] = inst
  log(c, { t = "power_end", card = inst.id, why = why })
  Combat.fire(c, "onPowerEnd", inst, why)
end

local function afterPlay(c, inst, d)
  if d.power then
    local powers = c.player.powers
    -- emplacement unique (Seal, totem d'un élément) : le pouvoir du même emplacement est remplacé
    if d.slot then
      for i = #powers, 1, -1 do
        if Card.def(powers[i]).slot == d.slot then Combat.removePower(c, i, "replaced") end
      end
    end
    powers[#powers + 1] = inst
    -- pouvoir à durée (« lasts = N ») : retiré à la fin du N-ième round
    if d.lasts then
      local pt = c.player.powerTurns or {}
      c.player.powerTurns = pt
      pt[inst.uid] = Combat.modify(c, "powerLasts", d.lasts, d, inst)
    end
    log(c, { t = "power", card = inst.id })
  elseif d.exhaust then
    c.exhaust[#c.exhaust + 1] = inst
  elseif d.cooldown then
    -- durée de la recharge (crochet « cooldown » : Hourglass Sand), 1 au moins
    local turns = max(1, Combat.modify(c, "cooldown", d.cooldown, d, inst))
    c.cooldown[#c.cooldown + 1] = { card = inst, turns = turns }
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

-- Résolution des effets d'une carte. ctx = { card, def, target, dealt, hits, spent, surge, cast } ;
-- un effet qui porte cond = "nom" ne s'applique que si la condition est vraie (Combat.test).
-- spent : la dépense « Spend N » a été payée au moment du jeu (Combat.play).
-- copy = vrai pour une copie (crochet « replay ») : ctx.copy, aucun coût, la carte ne bouge pas.
local function resolveEffects(c, inst, d, target, cast, spent, copy)
  local ctx = { card = inst, def = d, target = target, dealt = false, hits = 0, cast = cast or false,
    spent = spent or false, copy = copy or nil }
  Combat.fire(c, "beforeCard", inst, ctx)
  local effects = d.effects
  for i = 1, #effects do
    local e = effects[i]
    local h = ns.Effects[e[1]]
    if not h then error(inst.id .. ": unknown effect " .. tostring(e[1])) end
    if not e.cond or Combat.test(c, ctx, e.cond, ctx.target) then h(c, ctx, e) end
    if c.result then break end
  end
  if ctx.dealt and not c.result and (c.player.st.atonement or 0) > 0 then
    Combat.heal(c, c.player, Combat.ATONEMENT_HEAL)
  end
  if not c.result then Combat.fire(c, "onCardPlayed", inst, ctx) end
  return ctx
end

function Combat.resolveCard(c, inst, target, cast, spent)
  local d = Card.def(inst)
  local ctx = resolveEffects(c, inst, d, target, cast, spent)
  -- copies (crochet « replay », Ironfoe) : résolues tout de suite après, sur la même cible (ou le
  -- premier ennemi vivant si elle est morte), sans coût ; la carte ne part qu'une fois
  if not c.result then
    local n = Combat.modify(c, "replay", 0, inst, ctx)
    for _ = 1, n do
      if c.result then break end
      local t = target
      if d.target == "enemy" and (not t or t.dead) then t = firstAlive(c) end
      log(c, { t = "replay", card = inst.uid })
      resolveEffects(c, inst, d, t, cast, spent, true)
    end
  end
  afterPlay(c, inst, d)
  -- carte Cast résolue, incantée ou instantanée (onCastResolved ne vaut que pour une incantation tenue)
  if d.cast and not c.result then Combat.fire(c, "afterCast", inst, ctx, not cast) end
  return ctx
end

-- Copie d'une carte (rejouer ou copier un effet) : ses effets se résolvent tout de suite sur target (ou le
-- premier ennemi vivant si elle doit viser et que la cible manque), sans coût, sans bouger la carte ;
-- ctx.copy est vrai. Renvoie le contexte de la copie.
function Combat.copyCard(c, inst, target)
  if c.result then return nil end
  local d = Card.def(inst)
  local t = target
  if d.target == "enemy" and (not t or t.dead) then t = firstAlive(c) end
  log(c, { t = "replay", card = inst.uid })
  return resolveEffects(c, inst, d, t, false, false, true)
end

-- Instant (état commun : Mage, Shaman) : la prochaine carte Cast se résout tout de suite, sans
-- emplacement, sans pouvoir être interrompue ; crochet « instantCast » pour une autre source.
-- commit = vrai au jeu (consomme une charge d'Instant), faux pour une simple question (canPlay).
-- target (facultatif) : l'ennemi visé, lu par le crochet dans c.aim (uid ; nil = cible encore inconnue).
-- Le crochet passe AVANT l'état Instant, qui n'est pas consommé quand une règle fait partir la carte
-- (Fingers of Frost).
function Combat.isInstant(c, d, inst, commit, target)
  if not d.cast then return false end
  c.aim = target and target.uid or nil
  local rule = Combat.modify(c, "instantCast", false, d, inst, commit)
  c.aim = nil
  if rule then return true end
  local p = c.player
  if (p.st.instant or 0) > 0 then
    if commit then
      p.st.instant = p.st.instant > 1 and p.st.instant - 1 or nil
      log(c, { t = "cast_instant", card = inst.uid })
      stat(c, "castsInstant")
    end
    return true
  end
  return false
end

-- Une carte Cast tient-elle sur cette cible ? Emplacements libres, ou départ immédiat sur elle.
function Combat.castFits(c, d, inst, target)
  return not d.cast or Combat.castCount(c) < Combat.castSlots(c) or Combat.isInstant(c, d, inst, false, target)
end

-- Joue la carte n° idx de la main sur l'ennemi n° tIdx (si elle vise).
-- opts.spend = false : « Spend N » n'est pas payé même si la ressource suffit (choix du joueur).
-- Ordre : cible, puis tous les coûts payés maintenant (mana, « Pay N HP », « Spend N » si la
-- ressource suffit et que le joueur le veut) — une carte Cast interrompue ne rend rien —, compteurs du
-- tour, événement « onCardCommitted », puis Trap posée, incantation ou résolution (conditions lues là).
function Combat.play(c, idx, tIdx, opts)
  local ok, why = Combat.canPlay(c, idx)
  if not ok then return false, why end
  local inst = c.hand[idx]
  local d = Card.def(inst)
  local target
  local launch = d.trap and Combat.trapLaunch(c, d, inst)
  if d.target == "enemy" or launch then
    target = c.enemies[tIdx or 0]
    if not target or target.dead then return false, "target" end
    -- ciblage : une classe peut rediriger la cible (crochet « target ») ; dernière cible retenue
    target = Combat.modify(c, "target", target, d, inst)
    if not target or target.dead then return false, "target" end
    -- emplacements pleins : la carte Cast doit partir tout de suite sur CETTE cible
    if not Combat.castFits(c, d, inst, target) then return false, "casting" end
    c.player.lastTarget = target.uid
  end
  local cost = Combat.cost(c, inst)
  local pay = Combat.payHpOf(c, d, inst)
  table.remove(c.hand, idx)
  c.player.mana = c.player.mana - cost
  statById(c, "played", inst.id)
  log(c, { t = "play", card = inst.uid, id = inst.id, target = target and target.uid, cost = cost })
  if pay > 0 then
    stat(c, "hpPaid", pay)
    Combat.fire(c, "onPayHp", pay, inst)
    Combat.loseHp(c, pay, "pay")
  end
  if c.result then return true end
  -- Spend N : payé au jeu si la ressource suffit (et si spendNeed(c, inst) le permet)
  local spent = false
  if d.spend and not (opts and opts.spend == false) and (not d.spendNeed or d.spendNeed(c, inst)) then
    spent = Combat.spendRes(c, d.spend)
    if spent then Combat.fire(c, "onSpend", d.spend, inst) end
  end
  -- compteurs du tour (cartes jouées, par type et par école), remis à 0 au début du tour
  local tu = c.turn
  tu.played = tu.played + 1
  tu.byType[d.type or "skill"] = (tu.byType[d.type or "skill"] or 0) + 1
  if d.school then tu.bySchool[d.school] = (tu.bySchool[d.school] or 0) + 1 end
  Combat.fire(c, "onCardCommitted", inst, d, target)
  if c.result then return true end
  -- Trap lancée (crochet « trapLaunch ») : déclenchée tout de suite sur la cible choisie
  if launch then
    Combat.launchTrap(c, inst, target, spent)
    return true
  end
  -- Trap : posée dans la zone des pièges, résolue à la prochaine attaque ennemie (sur l'attaquant)
  if d.trap then
    c.traps[#c.traps + 1] = { card = inst, spent = spent or nil }
    log(c, { t = "trap_set", card = inst.uid })
    Combat.fire(c, "onTrapSet", inst)
    return true
  end
  if d.cast and not Combat.isInstant(c, d, inst, true, target) then
    local entry = { card = inst, target = target and target.uid, spent = spent or nil }
    if c.player.cast then
      local more = c.player.castMore or {}
      c.player.castMore = more
      more[#more + 1] = entry
    else
      c.player.cast = entry
    end
    stat(c, "castsStarted")
    log(c, { t = "cast_start", card = inst.uid })
    Combat.fire(c, "onCastStart", inst)
    return true
  end
  Combat.resolveCard(c, inst, target, false, spent)
  return true
end

-- Déclenche la plus ancienne Trap posée contre l'ennemi e (pendant son tour, avant ses coups) :
-- ses effets se résolvent avec l'attaquant pour cible, puis la carte suit sa plaque.
function Combat.triggerTrap(c, e)
  local trap = table.remove(c.traps, 1)
  if not trap then return end
  log(c, { t = "trap", card = trap.card.uid, id = trap.card.id, dst = e.uid })
  stat(c, "trapsTriggered")
  Combat.resolveCard(c, trap.card, e, false, trap.spent)
  if not c.result then Combat.fire(c, "onTrapTriggered", trap.card, e) end
end

-- Trap lancée au jeu (crochet « trapLaunch ») : se déclenche aussitôt sur la cible choisie, comme si elle
-- attaquait (mêmes effets, même « onTrapTriggered » avec why = "launch"), sans place dans la zone des pièges.
function Combat.launchTrap(c, inst, e, spent)
  log(c, { t = "trap", card = inst.uid, id = inst.id, dst = e.uid, launched = true })
  stat(c, "trapsTriggered")
  Combat.resolveCard(c, inst, e, false, spent)
  if not c.result then Combat.fire(c, "onTrapTriggered", inst, e, "launch") end
end

local function resolveOne(c, cast)
  local target
  if Card.def(cast.card).target == "enemy" then
    target = cast.target and Combat.enemyByUid(c, cast.target)
    if not target or target.dead then target = firstAlive(c) end
  end
  log(c, { t = "cast_resolve", card = cast.card.uid })
  Combat.resolveCard(c, cast.card, target, true, cast.spent)
  if not c.result then Combat.fire(c, "onCastResolved", cast.card) end
end

local function resolveCast(c)
  local cast = c.player.cast
  local more = c.player.castMore
  c.player.cast, c.player.castMore = nil, nil
  resolveOne(c, cast)
  if more then
    for i = 1, #more do
      if c.result then
        c.discard[#c.discard + 1] = more[i].card
      else
        resolveOne(c, more[i])
      end
    end
  end
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
  -- Absorb gardée d'un tour à l'autre (crochet « blockKeep » (v, Absorb actuelle), 0 par défaut : Absorb
  -- remise à 0 ; une fraction se calcule sur le second argument, un plafond avec max/min)
  p.block = min(p.block, max(0, Combat.modify(c, "blockKeep", 0, p.block)))
  p.st.halved = nil
  -- états retirés au début du tour (clearAtTurnStart : Pain Suppression, Ice Block…)
  for id in pairs(p.st) do
    if ns.Statuses[id] and ns.Statuses[id].clearAtTurnStart then p.st[id] = nil end
  end
  c.turn = { played = 0, byType = {}, bySchool = {} }
  log(c, { t = "turn", round = c.round })
  tickPeriodic(c, p)
  if c.result then return end
  local rd = Combat.resourceDef(c)
  if rd and rd.keep == false and (p.res or 0) ~= 0 then Combat.gainRes(c, -p.res, "turn") end
  -- mana remis AVANT la résolution des incantations : un sort qui rend du mana (Evocation) compte
  p.mana = Combat.modify(c, "maxMana", Combat.BASE_MANA)
  if p.cast then resolveCast(c) end
  if c.result then return end
  returnCooldowns(c)
  Combat.drawCards(c, Combat.modify(c, "drawPerTurn", Combat.DRAW_PER_TURN))
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

-- Carte gardée au choix en fin de tour (Traveler's Backpack) : crochet « retainPicks » (nombre de cartes
-- que le joueur peut garder en plus des cartes Retain, 0 par défaut ; une seule est gérée). Le choix est
-- posé AVANT la fin du tour par Combat.markRetain (interface : clic sur la carte après « End Turn » ;
-- bots : Sim), lu et effacé par Combat.endPlayerTurn. Sans choix posé, rien n'est gardé.
function Combat.retainPicks(c)
  return Combat.modify(c, "retainPicks", 0)
end

-- Index des cartes de la main que le choix peut garder (celles qui ne sont pas déjà Retain).
function Combat.retainCandidates(c)
  local list = {}
  if Combat.retainPicks(c) <= 0 then return list end
  for i = 1, #c.hand do
    if not Card.def(c.hand[i]).retain then list[#list + 1] = i end
  end
  return list
end

-- Pose (uid) ou retire (nil) le choix ; false si le choix n'est pas permis (pas de crochet, pas le tour
-- du joueur, carte absente de la main ou déjà Retain).
function Combat.markRetain(c, uid)
  if uid == nil then c.player.retainPick = nil return true end
  if c.phase ~= "player" or c.result or Combat.retainPicks(c) <= 0 then return false end
  for i = 1, #c.hand do
    local inst = c.hand[i]
    if inst.uid == uid then
      if Card.def(inst).retain then return false end
      c.player.retainPick = uid
      return true
    end
  end
  return false
end

function Combat.endPlayerTurn(c)
  Combat.fire(c, "onTurnEnd")
  local pick = c.player.retainPick
  c.player.retainPick = nil
  if pick and Combat.retainPicks(c) <= 0 then pick = nil end
  local keep = {}
  for i = 1, #c.hand do
    local inst = c.hand[i]
    if Card.def(inst).retain then
      keep[#keep + 1] = inst
    elseif inst.uid == pick then
      keep[#keep + 1] = inst
      log(c, { t = "retained", card = inst.uid })
      stat(c, "retainPicked")
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
    -- tour ennemi sauté (Feign Death) : drapeau posé avant ou pendant la phase
    if c.player.flags.skipEnemyTurn then
      c.player.flags.skipEnemyTurn = nil
      log(c, { t = "enemy_turn_skipped" })
      return
    end
    if not e.dead then
      e.block = 0
      tickPeriodic(c, e)
      if c.result then return end
      if not e.dead then
        if (e.st.stunned or 0) > 0 then
          e.st.stunned = e.st.stunned > 1 and e.st.stunned - 1 or nil
          log(c, { t = "stunned", unit = e.uid })
        else
          c.acting = e.uid -- ennemi dont c'est le tour (Stunned posé pendant ce tour : arrêt immédiat)
          executeMove(c, e)
          c.acting = nil
        end
      end
      if c.result then return end
    end
  end
end

function Combat.endRound(c)
  Combat.fire(c, "onRoundEnd")
  -- pouvoirs à durée : un round de moins, retirés à 0 (dans l'ordre de la liste)
  local pt = c.player.powerTurns
  if pt then
    local powers = c.player.powers
    for i = #powers, 1, -1 do
      local uid = powers[i].uid
      if pt[uid] then
        pt[uid] = pt[uid] - 1
        if pt[uid] <= 0 then Combat.removePower(c, i, "expired") end
      end
    end
  end
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

-- Innate (champ innate) : après le mélange, les cartes Innate passent sur le dessus de la pioche, dans
-- leur ordre ; la première pioche les prend À LA PLACE d'autant de cartes (main de 5 inchangée ; au-delà
-- de 5 Innate, les suivantes restent sur le dessus pour la pioche suivante). Sans Innate, rien ne bouge.
function Combat.placeInnate(c)
  local draw = c.draw
  local innate
  for i = 1, #draw do
    if Card.def(draw[i]).innate then innate = true break end
  end
  if not innate then return end
  local rest, top = {}, {}
  for i = 1, #draw do
    if Card.def(draw[i]).innate then top[#top + 1] = draw[i] else rest[#rest + 1] = draw[i] end
  end
  -- la pioche prend la fin de la liste : la première Innate doit être la dernière
  for i = #top, 1, -1 do rest[#rest + 1] = top[i] end
  c.draw = rest
end

function Combat.newStats()
  return { turns = 0, hpLost = 0, healed = 0, castsStarted = 0, castsInterrupted = 0,
    enemyCasts = 0, enemyCastsInterrupted = 0, played = {}, drawn = {}, unplayed = {}, potions = {} }
end

-- opts : seed, class (id de ns.Classes, « priest » par défaut), hp, maxHp,
--        deck = { {id=, up=}, ... }, encounter = { idEnnemi, ... },
--        relics = { id, ... }, potions = { id|false, ... } (POTION_SLOTS emplacements au moins),
--        charges = { clé = valeur } (état de bibelots propre à l'expédition, relu après le combat),
--        affixes = { id de ns.Affixes, ... } (clés mythiques), stats = bool, quiet = bool
-- État propre à la classe : c.cls (table de données simples, vide au départ, remplie par
-- ns.ClassRules[classe].init) ; ressource : c.player.res.
function Combat.new(opts)
  local seed = opts.seed or 1
  local class = opts.class or "priest"
  if not ns.Classes[class] then error("unknown class: " .. tostring(class)) end
  local c = {
    seed = seed, round = 0, phase = "start", result = nil, class = class, cls = {},
    turn = { played = 0, byType = {}, bySchool = {} }, -- compteurs du tour (Combat.play)
    events = {}, quiet = opts.quiet or false, nextUid = 1,
    rng = {
      draw = Rng.stream(seed, "draw"),
      ai = Rng.stream(seed, "ai"),
      misc = Rng.stream(seed, "misc"),
      cards = Rng.stream(seed, "cards"), -- hasard des cartes (jamais celui de l IA)
    },
    player = {
      side = "player", hp = opts.hp, maxHp = opts.maxHp or opts.hp, block = 0,
      st = {}, fresh = {}, mana = 0, res = 0, powers = {}, cast = nil, flags = {},
      potions = {},
    },
    draw = {}, hand = {}, discard = {}, exhaust = {}, cooldown = {}, traps = {},
    enemies = {}, relics = U.copyArr(opts.relics or {}), relicState = {},
    affixes = U.copyArr(opts.affixes or {}),
    charges = U.copyMap(opts.charges or {}),
    stats = opts.stats and Combat.newStats() or nil,
  }
  local potions = opts.potions or {}
  -- emplacements : 3, ou plus si l'expédition en a gagné (Herb Pouch : #exp.potions)
  for i = 1, max(Combat.POTION_SLOTS, #potions) do c.player.potions[i] = potions[i] or false end
  -- deck transformé par son épique (Card.applyTransforms : le deck lui-même sans transformation)
  local deck = Card.applyTransforms(opts.deck)
  local starters
  for i = 1, #deck do
    local card = deck[i]
    local inst = Card.new(card.id, card.up, c.nextUid)
    c.draw[#c.draw + 1] = inst
    c.nextUid = c.nextUid + 1
    -- effet passif tant que la carte est dans le deck (docs/classes.md, « Cartes épiques ») : deckHooks
    -- (crochets actifs tout le combat, src = { id, up, uid }), whileInDeck(c, src) appelé au début du combat
    local d = Card.def(inst)
    if d.deckHooks or d.whileInDeck then
      local src = { id = inst.id, up = inst.up, uid = inst.uid }
      if d.deckHooks then
        c.passives = c.passives or {}
        c.passives[#c.passives + 1] = src
      end
      if d.whileInDeck then
        starters = starters or {}
        starters[#starters + 1] = src
      end
    end
  end
  Rng.shuffle(c.rng.draw, c.draw)
  Combat.placeInnate(c)
  for i = 1, #opts.encounter do Combat.spawn(c, opts.encounter[i]) end
  local cr = Rules[class]
  if cr and cr.init then cr.init(c, c.cls) end
  if starters then
    for i = 1, #starters do Card.def(starters[i]).whileInDeck(c, starters[i]) end
  end
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
  if u.castMore then r.castMore = copyArr(u.castMore) end
  if u.powerTurns then r.powerTurns = copyMap(u.powerTurns) end
  if u.stIcon then r.stIcon = copyMap(u.stIcon) end
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
  n.cls = U.copy(c.cls) -- état de classe : copie profonde (totems, familier… peuvent être des tables)
  n.turn = { played = c.turn.played, byType = copyMap(c.turn.byType), bySchool = copyMap(c.turn.bySchool) }
  n.charges = copyMap(c.charges)
  n.rng = { draw = copyMap(c.rng.draw), ai = copyMap(c.rng.ai), misc = copyMap(c.rng.misc),
    cards = c.rng.cards and copyMap(c.rng.cards) or nil }
  n.player = copyUnit(c.player)
  n.hand = copyArr(c.hand)
  n.draw = copyArr(c.draw)
  n.discard = copyArr(c.discard)
  n.exhaust = copyArr(c.exhaust)
  n.traps = copyArr(c.traps or {})
  if c.passives then n.passives = copyArr(c.passives) end
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
