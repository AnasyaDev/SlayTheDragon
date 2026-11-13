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

-- Règles de zone (Core/ZoneRules/<zone>.lua) : ns.ZoneRules[id] = { hooks = {...}, init = f(c, z),
-- always = bool, run = {...}, campfire = {...}, botKey, botValue }. Actives dans un combat : la zone de
-- l'expédition (c.zone) et toutes celles qui portent always = true (mécanique sortie de sa zone : Asleep).
-- Liste figée à la création du combat dans c.zr (nil sans règle : aucun coût) ; état de chaque zone dans
-- c.zs[id] (données simples, copiées en profondeur par Combat.clone). Leurs crochets passent APRÈS ceux
-- de la classe et AVANT ceux des pouvoirs, bibelots et affixes, avec src = c.zs[id]. Contrat : docs/zones.md.
ns.ZoneRules = ns.ZoneRules or {}
local ZRules = ns.ZoneRules

-- Valeur modifiée : chaque crochet reçoit (c, src, v, ...) et renvoie la nouvelle valeur.
function Combat.modify(c, name, v, a, b, d, x)
  local cr = Rules[c.class]
  local ch = cr and cr.hooks and cr.hooks[name]
  if ch then v = ch(c, c.cls, v, a, b, d, x) end
  local zr = c.zr
  if zr then
    for i = 1, #zr do
      local r = ZRules[zr[i]]
      local h = r and r.hooks and r.hooks[name]
      if h then v = h(c, c.zs[zr[i]], v, a, b, d, x) end
    end
  end
  local powers = c.player.powers
  for i = 1, #powers do
    local h = Card.def(powers[i]).hooks
    h = h and h[name]
    if h then v = h(c, powers[i], v, a, b, d, x) end
  end
  local relics = c.relics
  for i = 1, #relics do
    local r = ns.Relics[relics[i]]
    local h = r and r.hooks and r.hooks[name]
    if h then v = h(c, relics[i], v, a, b, d, x) end
  end
  local affixes = c.affixes -- affixes mythiques (ns.Affixes), mêmes crochets
  if affixes then
    for i = 1, #affixes do
      local af = ns.Affixes[affixes[i]]
      local h = af and af.hooks and af.hooks[name]
      if h then v = h(c, affixes[i], v, a, b, d, x) end
    end
  end
  return v
end

-- Notification : chaque crochet reçoit (c, src, ...) ; s'il renvoie true, on s'arrête
-- et fire renvoie true (sert à « empêcher la mort », par exemple) et la source qui l'a arrêtée
-- (l'état de classe ou de zone, l'instance du pouvoir, l'id du bibelot ou de l'affixe).
function Combat.fire(c, name, a, b, d, x)
  local cr = Rules[c.class]
  local ch = cr and cr.hooks and cr.hooks[name]
  if ch and ch(c, c.cls, a, b, d, x) then return true, c.cls end
  local zr = c.zr
  if zr then
    for i = 1, #zr do
      local r = ZRules[zr[i]]
      local h = r and r.hooks and r.hooks[name]
      if h and h(c, c.zs[zr[i]], a, b, d, x) then return true, c.zs[zr[i]] end
    end
  end
  local powers = c.player.powers
  for i = 1, #powers do
    local h = Card.def(powers[i]).hooks
    h = h and h[name]
    if h and h(c, powers[i], a, b, d, x) then return true, powers[i] end
  end
  local relics = c.relics
  for i = 1, #relics do
    local r = ns.Relics[relics[i]]
    local h = r and r.hooks and r.hooks[name]
    if h and h(c, relics[i], a, b, d, x) then return true, relics[i] end
  end
  local affixes = c.affixes
  if affixes then
    for i = 1, #affixes do
      local af = ns.Affixes[affixes[i]]
      local h = af and af.hooks and af.hooks[name]
      if h and h(c, affixes[i], a, b, d, x) then return true, affixes[i] end
    end
  end
  return false
end

-- État d'une zone dans ce combat (nil si ses règles ne sont pas actives).
function Combat.zoneState(c, id)
  return c.zs and c.zs[id] or nil
end

-- Noms de crochets écoutés dans ce combat (c.hk, posé par Combat.new : classe, zones actives, bibelots,
-- affixes, toutes les cartes du deck ; complété par Combat.addCard). Les notifications ajoutées pour les
-- zones (onEffectEnd, onCardDiscarded, enemyMove…) ne parcourent les crochets que si leur nom y figure :
-- le moteur reste aussi rapide sans zone. c.hk absent (ancienne sauvegarde) = tout est écouté.
local function addHookNames(hk, hooks)
  if hooks then for k in pairs(hooks) do hk[k] = true end end
end

local function cardHookNames(hk, id)
  local d = ns.Cards[id]
  if not d then return end
  addHookNames(hk, d.hooks)
  if d.up then addHookNames(hk, d.up.hooks) end
end

function Combat.collectHooks(c, deck)
  local hk = {}
  local cr = Rules[c.class]
  addHookNames(hk, cr and cr.hooks)
  for _, id in ipairs(c.zr or {}) do addHookNames(hk, ZRules[id] and ZRules[id].hooks) end
  for _, id in ipairs(c.relics) do addHookNames(hk, ns.Relics[id] and ns.Relics[id].hooks) end
  for _, id in ipairs(c.affixes or {}) do addHookNames(hk, ns.Affixes[id] and ns.Affixes[id].hooks) end
  for _, card in ipairs(deck or {}) do cardHookNames(hk, card.id) end
  return hk
end

local function hooked(c, name)
  local hk = c.hk
  return hk == nil or hk[name] == true
end
Combat.hooked = hooked

-- Combat.fire / Combat.modify, seulement si le nom est écouté dans ce combat.
local function zfire(c, name, a, b, d, x)
  if not hooked(c, name) then return false end
  return Combat.fire(c, name, a, b, d, x)
end
local function zmodify(c, name, v, a, b, d, x)
  if not hooked(c, name) then return v end
  return Combat.modify(c, name, v, a, b, d, x)
end
Combat.zfire, Combat.zmodify = zfire, zmodify

---------------------------------------------------------------------------
-- Effets : unité de résolution (« même effet que »)
---------------------------------------------------------------------------
-- Un effet = la résolution d'une carte jouée (« card »), d'une incantation au début du tour (« cast »),
-- d'une Trap (« trap »), d'une potion (« potion »), d'un tic de DoT (« dot »), de l'action d'un ennemi
-- (« enemy »), du début du combat (« start »), du début ou de la fin du tour du joueur (« turnStart »,
-- « turnEnd » : familier automatique, Pouvoirs, cartes « End of turn »), de la fin du round
-- (« roundEnd »). Chaque effet a un numéro (c.fxId) et un genre (c.fxKind) ; Trap et DoT ouvrent toujours
-- un effet à eux, même pendant un autre ; le reste s'emboîte dans l'effet en cours. À la fin de chaque
-- effet : notification « onEffectEnd » (genre, numéro), si le combat continue (primes de Pack).
-- c.fxDepth, c.fxSeq : compteurs (données simples).
local function fxBegin(c, kind, own)
  local depth = c.fxDepth or 0
  c.fxDepth = depth + 1
  if depth == 0 or own then
    local outer = depth > 0 and { c.fxId, c.fxKind } or true
    c.fxSeq = (c.fxSeq or 0) + 1
    c.fxId, c.fxKind = c.fxSeq, kind
    return outer
  end
  return false
end

local function fxEnd(c, tok)
  c.fxDepth = (c.fxDepth or 1) - 1
  if not tok then return end
  if not c.result then Combat.zfire(c, "onEffectEnd", c.fxKind, c.fxId) end
  if tok == true then c.fxId, c.fxKind = nil, nil else c.fxId, c.fxKind = tok[1], tok[2] end
end
Combat.fxBegin, Combat.fxEnd = fxBegin, fxEnd

-- Exécute fn(...) comme un effet du genre kind (own : effet à part même s'il est emboîté).
function Combat.asEffect(c, kind, own, fn, ...)
  local tok = fxBegin(c, kind, own)
  local r1, r2 = fn(...)
  fxEnd(c, tok)
  return r1, r2
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

-- Ajoute n (négatif : retire) à la ressource, dans [0, plafond] ; renvoie la variation réelle.
-- why : raison facultative, passée au crochet « onResource ».
function Combat.gainRes(c, n, why)
  local p = c.player
  local r = Combat.resourceDef(c)
  local v = (p.res or 0) + n
  if r and r.cap and v > r.cap then v = r.cap end
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

-- Perte de PV hors attaque (coût « Pay N HP », effets, terrain d'une zone : why = "wildfire", "curse"…) :
-- ni Absorption, ni Parry (crochet beforeHit), ni crochet de coup reçu ; peut tuer (Last Breath).
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
  -- la carte a déjà interrompu au moins une incantation ennemie (effet « interrupt » plus haut)
  interrupted = function(c, ctx) return (ctx.interrupted or 0) > 0 end,
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

-- Retire tous les états négatifs de l'unité ; renvoie le nombre d'effets retirés : états, plus ce que
-- le crochet « cleanse » (c, src, n, unité) ajoute (Duskwood : Curses de la main épuisées, comptées).
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
  return Combat.zmodify(c, "cleanse", #ids, unit)
end

-- Déclenche le DoT de l'unité : dégâts égaux à sa valeur (sans Absorb), puis baisse (crochet
-- « dotDecay »). Appelé au début du tour du porteur, et tout de suite par une carte (Envenom :
-- « trigger the target's DoT »). Renvoie les dégâts. Toujours un effet à part (genre « dot »).
function Combat.tickDot(c, unit)
  local pain = unit.st.pain
  if not pain or pain <= 0 or unit.dead then return 0 end
  local tok = fxBegin(c, "dot", true)
  local k0, a0 = c.hitKind, c.hitAll
  c.hitKind, c.hitAll = "dot", true
  log(c, { t = "tick", unit = uref(unit), id = "pain", n = pain })
  Combat.dealDamage(c, nil, unit, pain, true)
  c.hitKind, c.hitAll = k0, a0
  local left = pain - Combat.modify(c, "dotDecay", 1, unit)
  if left > 0 then unit.st.pain = left else unit.st.pain = nil end
  if not c.result then Combat.fire(c, "onDotTick", unit, pain) end
  fxEnd(c, tok)
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

-- Source du coup porté à un ennemi (crochets « enemyDamageTaken », « onEnemyDamaged ») : table
-- RÉUTILISÉE d'un coup à l'autre (copier ce qu'on veut garder) :
--   kind   = "card" | "cast" (incantation résolue) | "trap" | "potion" | "dot" | "pet" (familier) |
--            "enemy" (coup d'un ennemi : sort renvoyé) | "other" (bibelot, effet sans carte)
--   single = vrai pour un effet qui ne vise qu'un ennemi (faux : « to all », DoT)
--   ctx    = contexte de la carte en cours (nil hors carte) ; effect = numéro de l'effet (c.fxId) ;
--   src    = unité à l'origine du coup (le joueur, un ennemi, nil pour un DoT)
-- Le genre vient de c.hitKind / c.hitAll, posés le temps d'un coup par Effects.damage, Combat.tickDot et
-- l'attaque du familier (Core/ZoneRules.lua), puis remis ; une carte qui appelle Combat.dealDamage
-- elle-même (fn) compte comme « card », à une cible.
local HIT = {}
local function hitInfo(c, src)
  local h = HIT
  if src and src.side == "enemy" then
    h.kind, h.single = "enemy", true
  elseif c.hitKind then
    h.kind, h.single = c.hitKind, not c.hitAll
  elseif src == nil then
    h.kind, h.single = "dot", false
  elseif c.cardCtx then
    h.kind, h.single = c.cardCtx.cast and "cast" or "card", true
  else
    h.kind, h.single = "other", true
  end
  h.ctx, h.effect, h.src = c.cardCtx, c.fxId, src
  return h
end
Combat.hitInfo = hitInfo

-- Seuils de PV d'un ennemi (def.phases, liste triée du plus haut au plus bas) : { at = fraction des PV
-- max (0.5) ou hp = PV, name, say, enter = { actions }, open = move, pattern = {...} | ai = f,
-- randomStart, startAt, rename, art, cap = bool, text }. PV du seuil k :
function Combat.phaseHp(e, ph)
  if ph.hp then return ph.hp end
  return floor(e.maxHp * ph.at)
end

-- Plafond au seuil (phase cap = true : boss qui ne peut pas sauter une phase) : les dégâts au-delà du
-- prochain seuil sont perdus pour ce coup.
local function capAtPhase(c, e, loss)
  local def = ns.Enemies[e.id]
  local phases = def.phases
  local nx = phases and phases[(e.mem.phase or 0) + 1]
  if nx and nx.cap then
    local floorHp = Combat.phaseHp(e, nx)
    if e.hp > floorHp and e.hp - loss < floorHp then
      log(c, { t = "capped", unit = e.uid, lost = loss - (e.hp - floorHp) })
      return e.hp - floorHp
    end
  end
  return loss
end

-- Seuils franchis par un ennemi encore vivant (une seule fois chacun, dans l'ordre).
local function checkPhases(c, e)
  local phases = ns.Enemies[e.id].phases
  if not phases or e.minion then return end
  local k = (e.mem.phase or 0) + 1
  while phases[k] and not e.dead and not c.result and e.hp <= Combat.phaseHp(e, phases[k]) do
    Combat.enterPhase(c, e, k)
    k = k + 1
  end
end

-- Applique des dégâts déjà calculés. pierce = ignore l'Absorption.
-- Renvoie (PV perdus, absorbés).
-- Ennemi touché : crochet « enemyDamageTaken » (c, src, v, ennemi, source du coup) avant l'Absorb
-- (modifier, plafonner : Unholy Shield, Rude Awakening, Invincible) ; plafond au seuil d'une phase
-- cap ; puis def.onDamaged, seuils franchis (def.phases), « onEnemyBloodied » (premier passage à ou
-- sous la moitié), « onEnemyDamaged » (ennemi, PV perdus, absorbés, source) s'il survit et que le coup
-- a porté (même entièrement absorbé).
function Combat.dealDamage(c, src, dst, amount, pierce)
  if dst.dead or c.result then return 0, 0 end
  local foe = dst.side == "enemy"
  local info
  if foe then
    info = hitInfo(c, src)
    amount = Combat.zmodify(c, "enemyDamageTaken", amount, dst, info)
    if amount < 0 then amount = 0 end
  end
  local absorbed = 0
  if not pierce then
    absorbed = min(dst.block, amount)
    dst.block = dst.block - absorbed
  end
  local loss = amount - absorbed
  if foe and loss > 0 then loss = capAtPhase(c, dst, loss) end
  if dst.side == "player" then stat(c, "hpLost", min(loss, max(dst.hp, 0))) end
  dst.hp = dst.hp - loss
  log(c, { t = "damage", src = uref(src), dst = uref(dst), amount = amount, absorbed = absorbed, loss = loss })
  if dst.hp <= 0 then
    Combat.kill(c, dst)
  elseif loss > 0 and foe then
    local def = ns.Enemies[dst.id]
    if def.onDamaged then def.onDamaged(c, dst, loss) end
    if def.phases then checkPhases(c, dst) end
    if not dst.mem.bloodied and dst.hp * 2 <= dst.maxHp and not dst.dead then
      dst.mem.bloodied = true
      if not c.result then Combat.zfire(c, "onEnemyBloodied", dst) end
    end
  elseif loss > 0 and dst.side == "player" then
    if src then Combat.fire(c, "onPlayerHit", src, loss) end
    Combat.fire(c, "onHpLost", loss, src, dst.hp + loss)
  end
  if foe and not dst.dead and not c.result and (loss > 0 or absorbed > 0) then
    Combat.zfire(c, "onEnemyDamaged", dst, loss, absorbed, hitInfo(c, src)) -- relue : la table est partagée
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
  Combat.zfire(c, "onCombatEnd", "won")
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
    Combat.zfire(c, "onCombatEnd", "lost")
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
  -- cartes de combat posées par cet ennemi et levées à sa mort (Curses : Combat.addCard, lift = true)
  if (c.lifts or 0) > 0 then Combat.liftCards(c, unit.uid) end
  -- info : effet en cours (c.fxId : deux morts du même numéro = « en même temps »), genre de l'effet,
  -- source du coup (kind, single)
  local kind = c.hitKind or (c.cardCtx and (c.cardCtx.cast and "cast" or "card")) or c.fxKind or "other"
  Combat.fire(c, "onEnemyDeath", unit, { effect = c.fxId, fx = c.fxKind, kind = kind,
    single = not (c.hitKind and c.hitAll), minion = unit.minion or false })
  checkVictory(c)
end

---------------------------------------------------------------------------
-- Ennemis
---------------------------------------------------------------------------

-- Id d'une entrée de groupe : "gnoll" ou { "gnoll", st = { asleep = 3 }, … } (spec, voir Combat.spawn).
function Combat.specId(spec)
  if type(spec) == "table" then return spec.id or spec[1] end
  return spec
end

-- Fait apparaître un ennemi. spec = id, ou table { id | [1], st = { état = n } (posés à l'arrivée),
-- hp = PV fixes, hpMul = facteur de PV, ambush = true (agit dès la phase ennemie en cours), zs = état de
-- zone propre à l'unité (copié) } ; by = ennemi qui l'invoque (nil : groupe de départ). Invocation en
-- cours de combat : notification « onEnemySpawn » (ennemi, by).
function Combat.spawn(c, spec, by)
  if #Combat.aliveEnemies(c) >= Combat.MAX_ENEMIES then return nil end
  local id = Combat.specId(spec)
  local opt = type(spec) == "table" and spec or nil
  local def = ns.Enemies[id]
  if not def then error("unknown enemy: " .. tostring(id)) end
  local hp = def.hp
  if type(hp) == "table" then hp = Rng.int(c.rng.ai, hp[1], hp[2]) end
  if opt and opt.hp then hp = opt.hp end
  if opt and opt.hpMul then hp = floor(hp * opt.hpMul + 0.5) end
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
  if opt then
    if opt.zs then e.zs = U.copy(opt.zs) end
    if opt.st then
      local ids = {}
      for k in pairs(opt.st) do ids[#ids + 1] = k end
      table.sort(ids)
      for i = 1, #ids do Combat.applyStatus(c, e, ids[i], opt.st[ids[i]]) end
    end
    if opt.ambush and c.phase == "enemy" then e.ambush = true end
  end
  log(c, { t = "spawn", unit = e.uid, id = id })
  if c.phase == "player" or e.ambush then Combat.chooseIntent(c, e) end
  if by ~= nil or c.phase ~= "start" then Combat.zfire(c, "onEnemySpawn", e, by) end
  return e
end

-- Nom affiché d'un ennemi (une phase peut le renommer : Nefarius -> Nefarian).
function Combat.enemyName(e)
  return e.name or ns.Enemies[e.id].name
end

-- Intention suivante imposée (ouverture d'une phase, ouverture d'un dormeur) : now = vrai (défaut :
-- pendant le jeu du joueur, c.step == "play") remplace l'intention annoncée tout de suite (incantation
-- comprise, interruption effacée) ; sinon elle sera la prochaine intention choisie (e.mem.forced),
-- annoncée en gris sous l'intention si label est donné (« On waking: »).
function Combat.forceIntent(c, e, move, opts)
  if e.dead then return end
  local def = ns.Enemies[e.id]
  if not def.moves[move] then error(e.id .. ": unknown move " .. tostring(move)) end
  local now = opts and opts.now
  if now == nil then now = c.step == "play" end
  if now then
    e.intent = move
    e.interrupted = false
    e.mem.forced, e.mem.forcedLabel = nil, nil
    log(c, { t = "intent", unit = e.uid, move = move, forced = true })
    if def.moves[move].cast then Combat.zfire(c, "onEnemyCastStart", e, move) end
  else
    e.mem.forced = move
    e.mem.forcedLabel = opts and opts.label or nil
  end
end

-- Choix de l'intention : intention imposée (e.mem.forced), sinon ouverture du combat (def.open, une
-- fois : annoncée au premier tour), sinon IA ou motif de la phase en cours (def.phases[k].ai / pattern),
-- sinon def.ai, sinon boucle sur def.pattern (départ au hasard si randomStart). Puis crochet « intent »
-- (c, src, move, ennemi) ; une incantation annoncée notifie « onEnemyCastStart » (ennemi, move).
function Combat.chooseIntent(c, e)
  local def = ns.Enemies[e.id]
  local move
  local mem = e.mem
  if mem.forced then
    move = mem.forced
    mem.forced, mem.forcedLabel = nil, nil
  elseif def.open and not mem.opened then
    move = def.open
    mem.opened = true
  else
    local ai, pat, rs = def.ai, def.pattern, def.randomStart
    local ph = mem.phase and def.phases and def.phases[mem.phase]
    if ph and (ph.ai or ph.pattern) then ai, pat, rs = ph.ai, ph.pattern, ph.randomStart end
    if ai then
      move = ai(c, e, c.rng.ai)
    else
      local idx = mem.idx
      if not idx then
        idx = rs and Rng.int(c.rng.ai, 1, #pat) or 1
      else
        idx = idx % #pat + 1
      end
      mem.idx = idx
      move = pat[idx]
    end
  end
  move = Combat.zmodify(c, "intent", move, e)
  if not def.moves[move] then error(e.id .. ": unknown move " .. tostring(move)) end
  e.intent = move
  e.interrupted = false
  log(c, { t = "intent", unit = e.uid, move = move })
  if def.moves[move].cast then Combat.zfire(c, "onEnemyCastStart", e, move) end
end

-- Entrée dans la phase k d'un ennemi (seuil franchi, Combat.dealDamage) : journal « phase », réplique,
-- nom et modèle (rename, art), actions d'entrée (mêmes actions que les intentions), motif de la phase
-- (startAt : premier coup joué du motif), intention d'ouverture (open) imposée — tout de suite pendant
-- le jeu du joueur, sinon à son prochain choix —, puis notification « onEnemyPhase » (ennemi, k, phase).
function Combat.enterPhase(c, e, k)
  local def = ns.Enemies[e.id]
  local ph = def.phases[k]
  e.mem.phase = k
  e.mem.idx = ph.startAt and ph.startAt > 1 and ph.startAt - 1 or nil
  if ph.rename then e.name = ph.rename end
  if ph.art then e.art = ph.art end
  log(c, { t = "phase", unit = e.uid, n = k, name = ph.name })
  if ph.say then log(c, { t = "say", unit = e.uid, text = ph.say }) end
  if ph.enter then
    for i = 1, #ph.enter do
      Combat.enemyAction(c, e, ph.enter[i])
      if c.result or e.dead then return end
    end
  end
  if ph.open then Combat.forceIntent(c, e, ph.open, { label = ph.label }) end
  Combat.zfire(c, "onEnemyPhase", e, k, ph)
end

-- Crans de vie d'un ennemi pour l'affichage : { { at = fraction, hp, name, text, passed } }.
function Combat.phaseMarks(e)
  local def = ns.Enemies[e.id]
  local list = {}
  if not def.phases or e.minion then return list end
  for k, ph in ipairs(def.phases) do
    local hp = Combat.phaseHp(e, ph)
    list[#list + 1] = { at = e.maxHp > 0 and hp / e.maxHp or 0, hp = hp, name = ph.name, text = ph.text,
      passed = (e.mem.phase or 0) >= k }
  end
  return list
end

-- Conditions et montants des actions ennemies (cond = "nom" | fonction ; more = { { k, "cond" } } ;
-- per = { k, "montant" }, cap = plafond du bonus) : une zone ajoute les siens
-- (Combat.ENEMY_CONDITIONS.lit = function(c, e, a) … end ; Combat.ENEMY_AMOUNTS.hexed = …).
Combat.ENEMY_CONDITIONS = {
  -- au moins un autre ennemi vivant
  allies = function(c, e)
    for i = 1, #c.enemies do
      local o = c.enemies[i]
      if o ~= e and not o.dead then return true end
    end
    return false
  end,
  -- le joueur incante
  casting = function(c) return c.player.cast ~= nil end,
}
Combat.ENEMY_AMOUNTS = {
  -- autres ennemis vivants
  allies = function(c, e)
    local n = 0
    for i = 1, #c.enemies do
      local o = c.enemies[i]
      if o ~= e and not o.dead then n = n + 1 end
    end
    return n
  end,
}

function Combat.enemyTest(c, e, cond, a)
  if type(cond) == "function" then return cond(c, e, a) and true or false end
  local f = Combat.ENEMY_CONDITIONS[cond]
  if not f then error("unknown enemy condition: " .. tostring(cond)) end
  return f(c, e, a) and true or false
end

-- Base d'une attaque ennemie : a[2] + more + per (+ bonus(c, e, a)), bonus plafonné par a.cap.
function Combat.enemyBase(c, e, a)
  local v = a[2]
  if a.more or a.per or a.bonus then
    local extra = 0
    if a.more then
      for i = 1, #a.more do
        if Combat.enemyTest(c, e, a.more[i][2], a) then extra = extra + a.more[i][1] end
      end
    end
    if a.per then
      local f = Combat.ENEMY_AMOUNTS[a.per[2]]
      if not f then error("unknown enemy amount: " .. tostring(a.per[2])) end
      extra = extra + a.per[1] * f(c, e, a)
    end
    if a.bonus then extra = extra + a.bonus(c, e, a) end
    if a.cap and extra > a.cap then extra = a.cap end
    v = v + extra
  end
  return v
end

-- Résumé d'intention pour l'affichage et les bots.
function Combat.intentInfo(c, e)
  local def = ns.Enemies[e.id]
  local mv = def.moves[e.intent]
  local info = { move = e.intent, name = mv.name, kind = mv.intent, cast = mv.cast or false,
    interrupted = e.interrupted, stunned = (e.st.stunned or 0) > 0, damage = 0, times = 0,
    forced = e.mem.forced, forcedLabel = e.mem.forcedLabel }
  for i = 1, #mv.actions do
    local a = mv.actions[i]
    if a[1] == "attack" then
      info.damage = Combat.calcDamage(c, e, c.player, Combat.enemyBase(c, e, a))
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
  Combat.zfire(c, "onCardDiscarded", cast.card, "interrupted")
end

Combat.interruptPlayer = interruptPlayer

-- Actions ennemies hors attaque. Une zone ajoute les siennes : Combat.ENEMY_ACTIONS.stoke =
-- function(c, e, a) … end (a = la table de l'action : { "stoke", 1 }).
Combat.ENEMY_ACTIONS = {}

local function aliveOf(c, id)
  local n = 0
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if not o.dead and o.id == id then n = n + 1 end
  end
  return n
end

local function actionBody(c, e, a)
  local k = a[1]
  local p = c.player
  if k == "attack" then
    -- hors d'une intention (entrée de phase) : coups simples, sans Trap ni interruption
    for _ = 1, (a.times or 1) do
      local dmg = Combat.modify(c, "beforeHit", Combat.calcDamage(c, e, p, Combat.enemyBase(c, e, a)), e, a)
      if c.result or e.dead then return end
      Combat.dealDamage(c, e, p, dmg)
      if c.result or e.dead then return end
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
  elseif k == "heal_allies" then -- soin de groupe : chaque ennemi vivant, lui compris
    for j = 1, #c.enemies do
      local o = c.enemies[j]
      if not o.dead then Combat.heal(c, o, a[2]) end
    end
  elseif k == "heal_self" then
    Combat.heal(c, e, a[2])
  elseif k == "block_ally" then
    local list = Combat.aliveEnemies(c)
    local o = list[Rng.int(c.rng.ai, 1, #list)]
    Combat.gainBlock(c, o, a[2])
  elseif k == "block_allies" then -- tous les ennemis vivants, lui compris
    for j = 1, #c.enemies do
      local o = c.enemies[j]
      if not o.dead then Combat.gainBlock(c, o, a[2]) end
    end
  elseif k == "block_boss" then -- le boss du combat (lui-même s'il n'y en a pas)
    local o = e
    for j = 1, #c.enemies do
      if c.enemies[j].boss and not c.enemies[j].dead then o = c.enemies[j] break end
    end
    Combat.gainBlock(c, o, a[2])
  elseif k == "interrupt" then
    interruptPlayer(c, e)
  elseif k == "summon" then
    -- count = nombre ; max = seulement tant qu'il en vit moins ; ambush = agit dès cette phase ennemie ;
    -- st = états posés à l'arrivée
    local n = a.count or 1
    if a.max then n = min(n, a.max - aliveOf(c, a[2])) end
    local spec = (a.ambush or a.st) and { a[2], ambush = a.ambush, st = a.st } or a[2]
    for _ = 1, n do Combat.spawn(c, spec, e) end
  elseif k == "say" then
    log(c, { t = "say", unit = e.uid, text = a[2] })
  elseif k == "die" then -- l'ennemi se détruit (mine qui explose) : mort ordinaire
    Combat.kill(c, e)
  elseif k == "addCard" then -- carte de combat dans les piles du joueur (Combat.addCard)
    for _ = 1, (a.n or 1) do
      Combat.addCard(c, a[2], a.to or "discard", { src = e.uid, lift = a.lift ~= false })
    end
  elseif k == "fn" then
    a[2](c, e)
  else
    local f = Combat.ENEMY_ACTIONS[k]
    if not f then error("unknown enemy action: " .. tostring(k)) end
    f(c, e, a)
  end
end

-- Une action (aussi : actions d'entrée d'une phase), sautée si sa condition cond est fausse.
function Combat.enemyAction(c, e, a)
  if a.cond and not Combat.enemyTest(c, e, a.cond, a) then return end
  actionBody(c, e, a)
end

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
    -- action conditionnelle (cond) : sautée, sans Trap ni élan, si la condition est fausse
    if not a.cond or Combat.enemyTest(c, e, a.cond, a) then
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
        local total = 0
        for _ = 1, (a.times or 1) do
          local dmg = Combat.calcDamage(c, e, p, Combat.enemyBase(c, e, a))
          -- coup subi avant réduction, coup par coup (Parry : avant l'Absorb) : le crochet peut réduire
          -- ou annuler le coup
          dmg = Combat.modify(c, "beforeHit", dmg, e, a)
          if c.result or e.dead then break end
          local loss, absorbed = Combat.dealDamage(c, e, p, dmg)
          total = total + loss
          if not c.result then Combat.fire(c, "afterHit", e, loss, absorbed) end
          if c.result or e.dead then break end
          -- Coup qui interrompt : coupe l'incantation s'il fait perdre des PV.
          if a.interrupts and loss > 0 then interruptPlayer(c, e) end
          if stopped() then halt = true break end
        end
        -- fin de l'action d'attaque (tous ses coups) : PV perdus au total (Bite de Duskwood : une Curse
        -- si total > 0)
        if not c.result then Combat.zfire(c, "afterEnemyAttack", e, a, total) end
        if halt then break end
      else
        actionBody(c, e, a)
      end
      if c.result or e.dead or stopped() then break end
    end
  end
  e.stopTurn = nil
  e.mem.last = e.intent
  if mv.cast and not c.result then Combat.zfire(c, "onEnemyCastResolved", e, e.intent) end
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
    Combat.zfire(c, "onCardDrawn", inst)
    hand, draw = c.hand, c.draw -- un crochet peut avoir remplacé une carte (transformation)
  end
end

---------------------------------------------------------------------------
-- Cartes de combat (cartes de zone non collectionnables : Curse, Hexed, carte donnée par un boss)
---------------------------------------------------------------------------
-- Une carte de combat est une instance neuve { uid, id, up, src = uid de l'ennemi qui l'a posée,
-- lift = vrai si elle part à la mort de src, orig = instance d'origine (carte transformée) } : jamais
-- modifiée ensuite (Combat.clone la partage), jamais dans le deck de l'expédition. Sa définition
-- (ns.Cards) porte token = true (hors de toute réserve : récompenses, marchand, rencontres), et peut
-- porter vanish = true (jouée, elle disparaît : ni défausse ni consumées) et endOfTurn = { effets }
-- (résolus si elle est en main à la fin du tour, avant la défausse, de gauche à droite).

local PILES = { "hand", "draw", "discard", "exhaust" }

-- Pile et index d'une instance (hand, draw, discard, exhaust, cooldown), ou nil.
function Combat.findCard(c, inst)
  for _, key in ipairs(PILES) do
    local list = c[key]
    for i = 1, #list do if list[i] == inst then return key, i end end
  end
  for i = 1, #c.cooldown do if c.cooldown[i].card == inst then return "cooldown", i end end
  return nil
end

-- Nombre de cartes du combat (main, pioche, défausse, recharges) qui vérifient pred(inst, def).
function Combat.countCards(c, pred)
  local n = 0
  for _, key in ipairs({ "hand", "draw", "discard" }) do
    local list = c[key]
    for i = 1, #list do if pred(list[i], Card.def(list[i])) then n = n + 1 end end
  end
  for i = 1, #c.cooldown do
    if pred(c.cooldown[i].card, Card.def(c.cooldown[i].card)) then n = n + 1 end
  end
  return n
end

-- Ajoute une carte de combat. to = "hand" (main pleine : défausse), "draw" (dessus de la pioche),
-- "drawRandom" (au hasard dans la pioche, flux c.rng.misc), "discard", "exhaust". opts = { src = uid
-- d'ennemi, lift = bool, up = bool }. Journal { t = "card_added", card, id, to, src } ; notification
-- « onCardAdded » (instance, pile, src). Renvoie l'instance.
function Combat.addCard(c, id, to, opts)
  if not ns.Cards[id] then error("unknown card: " .. tostring(id)) end
  local inst = Card.new(id, opts and opts.up, c.nextUid)
  c.nextUid = c.nextUid + 1
  if opts and opts.src then inst.src = opts.src end
  if opts and opts.lift then
    inst.lift = true
    c.lifts = (c.lifts or 0) + 1
  end
  -- crochets d'une carte nouvelle (Pouvoir donné en combat) : ajoutés aux noms écoutés (copie)
  local d = ns.Cards[id]
  if c.hk and (d.hooks or (d.up and d.up.hooks)) then
    local hk = U.copyMap(c.hk)
    cardHookNames(hk, id)
    c.hk = hk
  end
  to = to or "discard"
  if to == "hand" and #c.hand >= Combat.HAND_MAX then to = "discard" end
  if to == "hand" then
    c.hand[#c.hand + 1] = inst
  elseif to == "draw" then
    c.draw[#c.draw + 1] = inst -- le dessus de la pioche est la fin de la liste
  elseif to == "drawRandom" then
    table.insert(c.draw, Rng.int(c.rng.misc, 1, #c.draw + 1), inst)
  elseif to == "exhaust" then
    c.exhaust[#c.exhaust + 1] = inst
  else
    to = "discard"
    c.discard[#c.discard + 1] = inst
  end
  log(c, { t = "card_added", card = inst.uid, id = id, to = to, src = opts and opts.src })
  Combat.zfire(c, "onCardAdded", inst, to, opts and opts.src)
  return inst
end

-- Retire une instance de sa pile : to = "exhaust" (défaut : aux consumées, notification « onExhaust »
-- (instance, why)) ou "vanish" (disparaît). Journal { t = "card_removed", card, id, why, to }.
function Combat.removeCard(c, inst, why, to)
  local key, i = Combat.findCard(c, inst)
  if not key then return false end
  if key == "cooldown" then table.remove(c.cooldown, i) else table.remove(c[key], i) end
  to = to or "exhaust"
  if to == "exhaust" and key ~= "exhaust" then c.exhaust[#c.exhaust + 1] = inst end
  log(c, { t = "card_removed", card = inst.uid, id = inst.id, why = why, to = to, from = key })
  if to == "exhaust" then Combat.zfire(c, "onExhaust", inst, why or "removed") end
  Combat.zfire(c, "onCardRemoved", inst, why, to)
  return true
end

-- Lève les cartes de combat posées par l'ennemi uid (lift = true) : épuisées (Combat.kill le fait à la
-- mort de l'ennemi). Renvoie le nombre de cartes levées.
function Combat.liftCards(c, uid, why)
  local list = {}
  for _, key in ipairs({ "hand", "draw", "discard" }) do
    for _, inst in ipairs(c[key]) do
      if inst.lift and inst.src == uid then list[#list + 1] = inst end
    end
  end
  for i = 1, #c.cooldown do
    local inst = c.cooldown[i].card
    if inst.lift and inst.src == uid then list[#list + 1] = inst end
  end
  for i = 1, #list do Combat.removeCard(c, list[i], why or "lifted") end
  if #list > 0 then log(c, { t = "cards_lifted", unit = uid, n = #list }) end
  return #list
end

-- Transforme une carte du combat sur place (main, pioche, défausse) : nouvelle instance de newId qui
-- garde l'originale dans orig (Hex de Stranglethorn ; l'originale n'est pas modifiée). opts = { src }.
-- Journal { t = "card_transformed", card = uid de l'originale, into = uid, id }. Renvoie la nouvelle.
function Combat.transformCard(c, inst, newId, opts)
  local key, i = Combat.findCard(c, inst)
  if not key or key == "cooldown" or key == "exhaust" then return nil end
  local n = Card.new(newId, false, c.nextUid)
  c.nextUid = c.nextUid + 1
  n.orig = inst
  if opts and opts.src then n.src = opts.src end
  c[key][i] = n
  log(c, { t = "card_transformed", card = inst.uid, into = n.uid, id = newId, from = key })
  Combat.zfire(c, "onCardTransformed", inst, n, key)
  return n
end

-- Rend la carte d'origine d'une carte transformée : l'originale va en main (pleine : défausse), la
-- transformée disparaît. Journal { t = "card_restored", card = uid de l'originale, from = uid }.
function Combat.restoreCard(c, inst, to)
  local orig = inst.orig
  if not orig then return nil end
  local key, i = Combat.findCard(c, inst)
  if key then
    if key == "cooldown" then table.remove(c.cooldown, i) else table.remove(c[key], i) end
  end
  to = to or "hand"
  if to == "hand" and #c.hand >= Combat.HAND_MAX then to = "discard" end
  local list = to == "hand" and c.hand or c.discard
  list[#list + 1] = orig
  log(c, { t = "card_restored", card = orig.uid, from = inst.uid, to = to })
  return orig
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
  -- Trap : zone des pièges pleine (3 par défaut, crochet « trapSlots »)
  if d.trap and #c.traps >= Combat.modify(c, "trapSlots", Combat.TRAP_SLOTS) then return false, "traps" end
  if not allowed(c, d) then return false, "forbidden" end
  if d.canPlay and not d.canPlay(c, inst) then return false, "condition" end
  return true
end

function Combat.needsTarget(inst)
  return Card.def(inst).target == "enemy"
end

-- Coups légaux : liste de { indexMain, indexCible|nil, sansDépense|nil }. Une carte « Spend N » dont
-- la ressource suffit apparaît deux fois : en dépensant (défaut) et sans dépenser (troisième champ vrai).
function Combat.legalPlays(c)
  local list = {}
  for i = 1, #c.hand do
    if Combat.canPlay(c, i) then
      local d = Card.def(c.hand[i])
      local both = d.spend and (c.player.res or 0) >= d.spend
      if d.target == "enemy" then
        for j = 1, #c.enemies do
          if not c.enemies[j].dead then
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
  if d.vanish then
    -- carte de combat qui disparaît une fois jouée (Hexed : la carte d'origine est déjà rendue)
    log(c, { t = "card_removed", card = inst.uid, id = inst.id, why = "played", to = "vanish" })
  elseif d.power then
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
    Combat.zfire(c, "onExhaust", inst, "played")
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
  local outerCtx = c.cardCtx
  c.cardCtx = ctx -- carte en cours (source des coups portés par une carte « fn », Combat.hitInfo)
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
  c.cardCtx = outerCtx
  return ctx
end

-- Effets « End of turn » d'une carte en main (champ endOfTurn), ctx.endOfTurn = vrai.
local function resolveEndOfTurn(c, inst, d)
  local ctx = { card = inst, def = d, dealt = false, hits = 0, endOfTurn = true }
  local list = d.endOfTurn
  for i = 1, #list do
    local e = list[i]
    local h = ns.Effects[e[1]]
    if not h then error(inst.id .. ": unknown effect " .. tostring(e[1])) end
    if not e.cond or Combat.test(c, ctx, e.cond, nil) then h(c, ctx, e) end
    if c.result then break end
  end
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
end

-- Instant (état commun : Mage, Shaman) : la prochaine carte Cast se résout tout de suite, sans
-- emplacement, sans pouvoir être interrompue ; crochet « instantCast » pour une autre source.
-- commit = vrai au jeu (consomme une charge d'Instant), faux pour une simple question (canPlay).
function Combat.isInstant(c, d, inst, commit)
  if not d.cast then return false end
  local p = c.player
  if (p.st.instant or 0) > 0 then
    if commit then
      p.st.instant = p.st.instant > 1 and p.st.instant - 1 or nil
      log(c, { t = "cast_instant", card = inst.uid })
      stat(c, "castsInstant")
    end
    return true
  end
  return Combat.modify(c, "instantCast", false, d, inst, commit) and true or false
end

-- Joue la carte n° idx de la main sur l'ennemi n° tIdx (si elle vise).
-- opts.spend = false : « Spend N » n'est pas payé même si la ressource suffit (choix du joueur).
-- Ordre : cible, puis tous les coûts payés maintenant (mana, « Pay N HP », « Spend N » si la
-- ressource suffit et que le joueur le veut) — une carte Cast interrompue ne rend rien —, compteurs du
-- tour, événement « onCardCommitted », puis Trap posée, incantation ou résolution (conditions lues là).
local playBody
function Combat.play(c, idx, tIdx, opts)
  local ok, why = Combat.canPlay(c, idx)
  if not ok then return false, why end
  local tok = fxBegin(c, "card")
  local r1, r2 = playBody(c, idx, tIdx, opts)
  fxEnd(c, tok)
  return r1, r2
end

playBody = function(c, idx, tIdx, opts)
  local inst = c.hand[idx]
  local d = Card.def(inst)
  local target
  if d.target == "enemy" then
    target = c.enemies[tIdx or 0]
    if not target or target.dead then return false, "target" end
    -- ciblage : une classe peut rediriger la cible (crochet « target ») ; dernière cible retenue
    target = Combat.modify(c, "target", target, d, inst)
    if not target or target.dead then return false, "target" end
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
  -- Trap : posée dans la zone des pièges, résolue à la prochaine attaque ennemie (sur l'attaquant)
  if d.trap then
    c.traps[#c.traps + 1] = { card = inst, spent = spent or nil }
    log(c, { t = "trap_set", card = inst.uid })
    Combat.fire(c, "onTrapSet", inst)
    return true
  end
  if d.cast and not Combat.isInstant(c, d, inst, true) then
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
  local tok = fxBegin(c, "trap", true)
  log(c, { t = "trap", card = trap.card.uid, id = trap.card.id, dst = e.uid })
  stat(c, "trapsTriggered")
  Combat.resolveCard(c, trap.card, e, false, trap.spent)
  if not c.result then Combat.fire(c, "onTrapTriggered", trap.card, e) end
  fxEnd(c, tok)
end

local function resolveOne(c, cast)
  local target
  if Card.def(cast.card).target == "enemy" then
    target = cast.target and Combat.enemyByUid(c, cast.target)
    if not target or target.dead then target = firstAlive(c) end
  end
  local tok = fxBegin(c, "cast")
  log(c, { t = "cast_resolve", card = cast.card.uid })
  Combat.resolveCard(c, cast.card, target, true, cast.spent)
  if not c.result then Combat.fire(c, "onCastResolved", cast.card) end
  fxEnd(c, tok)
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

local potionBody
function Combat.usePotion(c, slot, tIdx)
  local ok, why = Combat.canUsePotion(c, slot, tIdx)
  if not ok then return false, why end
  local tok = fxBegin(c, "potion")
  local r1, r2 = potionBody(c, slot, tIdx)
  fxEnd(c, tok)
  return r1, r2
end

potionBody = function(c, slot, tIdx)
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
  Combat.zfire(c, "onCombatEnd", "fled")
  return true
end

---------------------------------------------------------------------------
-- Tours
---------------------------------------------------------------------------

-- Moment du round (c.step) : "turnStart" (début du tour du joueur, avant les intentions), "play" (le
-- joueur joue), "turnEnd" (fin de son tour), "enemy" (phase ennemie), "roundEnd" (fin du round).
function Combat.startPlayerTurn(c)
  c.round = c.round + 1
  c.phase = "player"
  c.step = "turnStart"
  stat(c, "turns")
  local p = c.player
  -- Absorb gardée d'un tour à l'autre (crochet « blockKeep », 0 par défaut : Absorb remise à 0)
  p.block = min(p.block, max(0, Combat.modify(c, "blockKeep", 0)))
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
  local tok = fxBegin(c, "turnStart")
  Combat.fire(c, "onTurnStart")
  fxEnd(c, tok)
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    if not e.dead then Combat.chooseIntent(c, e) end
  end
  c.step = "play"
  -- intentions annoncées (Morbent's Bane : +1 mana si un ennemi annonce une incantation)
  Combat.zfire(c, "onIntents")
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

-- Fin du tour du joueur : « onTurnEnd » (familier, Pouvoirs), lignes « End of turn » des cartes en main
-- (champ endOfTurn, de gauche à droite), « onHandEnd » (main encore entière : verrouillage du Hex), puis
-- la défausse : « onCardKept » (instance, "retain" | "pick") pour chaque carte gardée, « onCardDiscarded »
-- (instance, "turn") pour les autres. Le tout est un effet (« turnEnd »).
function Combat.endPlayerTurn(c)
  c.step = "turnEnd"
  local tok = fxBegin(c, "turnEnd")
  Combat.fire(c, "onTurnEnd")
  local eot
  for i = 1, #c.hand do
    if Card.def(c.hand[i]).endOfTurn then eot = true break end
  end
  if eot and not c.result then
    local list = {}
    for i = 1, #c.hand do list[i] = c.hand[i] end
    for i = 1, #list do
      local d = Card.def(list[i])
      if d.endOfTurn and Combat.findCard(c, list[i]) == "hand" then resolveEndOfTurn(c, list[i], d) end
      if c.result then break end
    end
  end
  if not c.result then Combat.zfire(c, "onHandEnd") end
  local pick = c.player.retainPick
  c.player.retainPick = nil
  if pick and Combat.retainPicks(c) <= 0 then pick = nil end
  local keep = {}
  local hand = c.hand
  for i = 1, #hand do
    local inst = hand[i]
    if Card.def(inst).retain then
      keep[#keep + 1] = inst
      Combat.zfire(c, "onCardKept", inst, "retain")
    elseif inst.uid == pick then
      keep[#keep + 1] = inst
      log(c, { t = "retained", card = inst.uid })
      stat(c, "retainPicked")
      Combat.zfire(c, "onCardKept", inst, "pick")
    else
      statById(c, "unplayed", inst.id)
      c.discard[#c.discard + 1] = inst
      Combat.zfire(c, "onCardDiscarded", inst, "turn")
    end
  end
  c.hand = keep
  c.player.flags.freeTurnActive = nil
  c.phase = "enemy"
  fxEnd(c, tok)
end

-- Tour d'un ennemi : Absorb à 0, DoT et Regen, puis Stunned (tour perdu : « onEnemyStunned ») ou son
-- action. Crochet « enemyMove » (c, src, move, ennemi) avant l'action : renvoyer un autre move le remplace,
-- false le saute (dormeur) ; après : « afterEnemyMove » (ennemi, move). L'action est un effet (« enemy »).
-- Renvoie vrai si le combat est tranché.
local function enemyTurn(c, e)
  e.block = 0
  tickPeriodic(c, e)
  if c.result then return true end
  if not e.dead then
    if (e.st.stunned or 0) > 0 then
      e.st.stunned = e.st.stunned > 1 and e.st.stunned - 1 or nil
      log(c, { t = "stunned", unit = e.uid })
      Combat.zfire(c, "onEnemyStunned", e)
    else
      local move = Combat.zmodify(c, "enemyMove", e.intent, e)
      if move then
        if move ~= e.intent then
          e.intent = move
          log(c, { t = "intent", unit = e.uid, move = move, replaced = true })
        end
        c.acting = e.uid -- ennemi dont c'est le tour (Stunned posé pendant ce tour : arrêt immédiat)
        local tok = fxBegin(c, "enemy")
        executeMove(c, e)
        fxEnd(c, tok)
        c.acting = nil
        if not c.result then Combat.zfire(c, "afterEnemyMove", e, move) end
      end
    end
  end
  return c.result ~= nil
end

-- Phase ennemie : « onEnemyPhaseStart », chaque ennemi présent au début de la phase (les invocations
-- n'agissent pas, sauf celles qui portent ambush), puis « onEnemyPhaseEnd » (skipped = tour ennemi
-- sauté : Feign Death).
function Combat.enemyPhase(c)
  c.step = "enemy"
  c.turnSkipped = nil
  Combat.zfire(c, "onEnemyPhaseStart")
  local n = #c.enemies -- les invocations de ce tour n'agissent pas
  local skipped = false
  for i = 1, n do
    local e = c.enemies[i]
    -- tour ennemi sauté (Feign Death) : drapeau posé avant ou pendant la phase
    if c.player.flags.skipEnemyTurn then
      c.player.flags.skipEnemyTurn = nil
      log(c, { t = "enemy_turn_skipped" })
      skipped = true
      break
    end
    if not e.dead then
      if enemyTurn(c, e) then return end
    end
  end
  -- invocations en embuscade (ambush) : agissent dès cette phase, après les autres
  if not skipped then
    local i = n + 1
    while i <= #c.enemies do
      local e = c.enemies[i]
      if e.ambush and not e.dead then
        e.ambush = nil
        if enemyTurn(c, e) then return end
      end
      i = i + 1
    end
  end
  c.turnSkipped = skipped or nil
  if not c.result then Combat.zfire(c, "onEnemyPhaseEnd", skipped) end
end

-- Fin du round : « onRoundEnd » (skipped : le tour ennemi a été sauté), durées des Pouvoirs et des états.
function Combat.endRound(c)
  c.step = "roundEnd"
  local tok = fxBegin(c, "roundEnd")
  Combat.fire(c, "onRoundEnd", c.turnSkipped or false)
  fxEnd(c, tok)
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
  if c.result then return true end -- perte de PV de fin de round (Wildfire)
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

-- Règles de zone actives pour un combat de la zone `zone` : la sienne, puis celles qui portent
-- always = true (ordre de la campagne, puis les autres par id). nil s'il n'y en a aucune.
local function byCampaign(a, b)
  local order = ns.Zone and ns.Zone.order
  local oa, ob = order and order(a) or 99, order and order(b) or 99
  if oa ~= ob then return oa < ob end
  return a < b
end

function Combat.zoneRulesFor(zone)
  if next(ZRules) == nil then return nil end -- aucune règle de zone chargée (cas courant : rapide)
  local list
  if zone and ZRules[zone] then list = { zone } end
  local others
  for id, r in pairs(ZRules) do
    if r.always and id ~= zone then
      others = others or {}
      others[#others + 1] = id
    end
  end
  if others then
    if #others > 1 then table.sort(others, byCampaign) end
    list = list or {}
    for i = 1, #others do list[#list + 1] = others[i] end
  end
  return list
end

-- opts : seed, class (id de ns.Classes, « priest » par défaut), hp, maxHp,
--        deck = { {id=, up=}, ... }, encounter = { idEnnemi | spec (Combat.spawn), ... },
--        relics = { id, ... }, potions = { id|false, ... } (POTION_SLOTS emplacements au moins),
--        charges = { clé = valeur } (état de bibelots propre à l'expédition, relu après le combat),
--        affixes = { id de ns.Affixes, ... } (clés mythiques), stats = bool, quiet = bool,
--        zone = id de ns.Zones (règles de zone), kind = "combat" | "elite" | "boss" (genre du combat),
--        mods = { st = { état = n }, hpMul } (posés sur chaque ennemi de départ hors boss : rencontre
--        « Sleeping Camp », Gurubashi Arena), start = { effets } (résolus au début du combat, après
--        « onCombatStart » : boissons du Grim Guzzler, exp.nextCombat)
-- État propre à la classe : c.cls (table de données simples, vide au départ, remplie par
-- ns.ClassRules[classe].init) ; ressource : c.player.res. États des zones : c.zs[id] (ZoneRules.init).
function Combat.new(opts)
  local seed = opts.seed or 1
  local class = opts.class or "priest"
  if not ns.Classes[class] then error("unknown class: " .. tostring(class)) end
  local c = {
    seed = seed, round = 0, phase = "start", result = nil, class = class, cls = {},
    zone = opts.zone, kind = opts.kind,
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
  for i = 1, #opts.deck do
    local card = opts.deck[i]
    c.draw[#c.draw + 1] = Card.new(card.id, card.up, c.nextUid)
    c.nextUid = c.nextUid + 1
  end
  Rng.shuffle(c.rng.draw, c.draw)
  -- règles de zone : liste et états posés avant l'arrivée des ennemis (leurs crochets peuvent déjà
  -- servir), init appelé après celui de la classe
  local zr = Combat.zoneRulesFor(opts.zone)
  if zr then
    c.zr, c.zs = zr, {}
    for i = 1, #zr do c.zs[zr[i]] = {} end
  end
  c.hk = Combat.collectHooks(c, opts.deck)
  local mods = opts.mods
  for i = 1, #opts.encounter do
    local spec = opts.encounter[i]
    if mods and not (ns.Enemies[Combat.specId(spec)] or {}).boss then
      local s = type(spec) == "table" and U.copy(spec) or { spec }
      if mods.hpMul then s.hpMul = (s.hpMul or 1) * mods.hpMul end
      if mods.st then
        s.st = s.st or {}
        for k, v in pairs(mods.st) do s.st[k] = (s.st[k] or 0) + v end
      end
      spec = s
    end
    Combat.spawn(c, spec)
  end
  local cr = Rules[class]
  if cr and cr.init then cr.init(c, c.cls) end
  if zr then
    for i = 1, #zr do
      local r = ZRules[zr[i]]
      if r.init then r.init(c, c.zs[zr[i]]) end
    end
  end
  local tok = fxBegin(c, "start")
  Combat.fire(c, "onCombatStart")
  if opts.start and not c.result then
    local ctx = { dealt = false, hits = 0, start = true }
    for i = 1, #opts.start do
      local e = opts.start[i]
      local h = ns.Effects[e[1]]
      if not h then error("start: unknown effect " .. tostring(e[1])) end
      h(c, ctx, e)
      if c.result then break end
    end
  end
  fxEnd(c, tok)
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
  if u.zs then r.zs = U.copy(u.zs) end -- état de zone propre à l'unité (copie profonde)
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
  if c.zs then n.zs = U.copy(c.zs) end -- états des zones : copie profonde (c.zr, liste figée, partagée)
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
