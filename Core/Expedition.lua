-- Expédition : machine à états entre les combats. L'état est fait de données simples
-- (aucune fonction, aucune métatable) : il se sauvegarde tel quel dans SlayTheDragonDB,
-- combat en cours compris. L'interface et les bots passent par la même API :
--   Expedition.new(opts) -> exp
--   Expedition.choices(exp) -> { action, ... }       (ce qu'on peut faire maintenant)
--   Expedition.act(exp, action) -> true | false, raison
-- Une action est une liste : { "verbe", arg1, arg2 }. Voir docs/expedition.md.
--
-- Hasard : une graine par expédition, des flux séparés (carte, butin, marchand,
-- rencontres, combats). Les récompenses sont tirées dès qu'on entre dans l'étape et
-- stockées dans l'état : recharger ne change rien.
local _, ns = ...

local U, Rng, Card, Map, Combat = ns.Util, ns.Rng, ns.Card, ns.Map, ns.Combat
local floor, min, max = math.floor, math.min, math.max

local X = {}
ns.Expedition = X

X.VERSION = 1

-- Paramètres de la couche expédition (réglés par la simulation).
X.START_GOLD = 50
X.POTION_SLOTS = 3
X.REST_FRACTION = 0.30
X.EASY_COMBATS = 2 -- premiers combats de chaque acte tirés dans le groupe « easy »
X.GOLD = { combat = { 12, 18 }, elite = { 25, 35 }, boss = { 75, 85 }, chest = { 20, 30 } }
X.CARD_WEIGHTS = {
  combat = { common = 60, uncommon = 33, rare = 7 },
  elite = { common = 45, uncommon = 40, rare = 15 },
  boss = { rare = 1 },
  shop = { common = 50, uncommon = 37, rare = 13 },
}
X.RELIC_WEIGHTS = {
  normal = { common = 50, uncommon = 35, rare = 15 },
  boss = { boss = 1 },
}
X.POTION_WEIGHTS = { common = 65, uncommon = 25, rare = 10 }
X.POTION_DROP = 0.35 -- chance de potion après un combat normal ou d'élite
X.PRICES = {
  card = { common = 35, uncommon = 55, rare = 90 },
  relic = { common = 90, uncommon = 120, rare = 160, boss = 220 },
  potion = { common = 30, uncommon = 45, rare = 60 },
}
X.PRICE_JITTER = 0.10
X.REMOVE_PRICE, X.REMOVE_STEP = 75, 25
X.SHOP = { cards = 5, relics = 3, potions = 3 }

X.PHASES = { start = true, map = true, combat = true, reward = true, campfire = true,
  merchant = true, event = true, select = true, done = true }

---------------------------------------------------------------------------
-- Crochets d'expédition des bibelots (relic.run) et des affixes (affix.run)
---------------------------------------------------------------------------

-- Valeur modifiée : chaque crochet reçoit (exp, v, a, b) et renvoie la nouvelle valeur.
-- Noms utilisés : gold (v, source), restFraction (v), restHeal (v), price (v, genre).
function X.modify(exp, name, v, a, b)
  local relics = exp.relics
  for i = 1, #relics do
    local r = ns.Relics[relics[i]]
    local h = r and r.run and r.run[name]
    if h then v = h(exp, v, a, b) end
  end
  local affixes = exp.affixes
  for i = 1, #affixes do
    local af = ns.Affixes[affixes[i]]
    local h = af and af.run and af.run[name]
    if h then v = h(exp, v, a, b) end
  end
  return v
end

-- Notification : chaque crochet reçoit (exp, a, b) ; true arrête la chaîne.
-- Noms utilisés : onNodeEnter (nœud), onCombatWon (genre), onRest.
function X.fire(exp, name, a, b)
  local relics = exp.relics
  for i = 1, #relics do
    local r = ns.Relics[relics[i]]
    local h = r and r.run and r.run[name]
    if h and h(exp, a, b) then return true end
  end
  local affixes = exp.affixes
  for i = 1, #affixes do
    local af = ns.Affixes[affixes[i]]
    local h = af and af.run and af.run[name]
    if h and h(exp, a, b) then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- Tirages filtrés par les déblocages
---------------------------------------------------------------------------

local function leagueTier(exp) return min(exp.unlock.league, 3) end

-- n ids distincts, rareté tirée selon weights parmi celles qui ont encore des candidats.
local function drawFrom(rng, ids, rarityOf, n, weights, taken)
  taken = taken or {}
  local out = {}
  while #out < n do
    local byR = {}
    for i = 1, #ids do
      local id = ids[i]
      if not taken[id] then
        local r = rarityOf(id)
        if (weights[r] or 0) > 0 then
          byR[r] = byR[r] or {}
          table.insert(byR[r], id)
        end
      end
    end
    local rs = {}
    for r in pairs(byR) do rs[#rs + 1] = r end
    if #rs == 0 then break end
    table.sort(rs)
    local r = Rng.weighted(rng, rs, function(x) return weights[x] end)
    local id = Rng.pick(rng, byR[r])
    taken[id] = true
    out[#out + 1] = id
  end
  return out
end

function X.cardPool(exp)
  local list = {}
  for id, d in pairs(ns.Cards) do
    if d.class == exp.class and d.rarity ~= "basic" and not d.noReward and (d.rep or 0) <= exp.unlock.rep then
      list[#list + 1] = id
    end
  end
  table.sort(list)
  return list
end

local function cardRarity(id) return ns.Cards[id].rarity end

local function drawCards(exp, rng, n, weights)
  local pool = X.cardPool(exp)
  local out = drawFrom(rng, pool, cardRarity, n, weights)
  if #out == 0 then out = drawFrom(rng, pool, cardRarity, n, X.CARD_WEIGHTS.combat) end
  return out
end

-- Bibelots proposables : tier débloqué, pas déjà possédés, hors bibelots de classe.
function X.relicPool(exp)
  local owned = {}
  for i = 1, #exp.relics do owned[exp.relics[i]] = true end
  local list = {}
  for id, r in pairs(ns.Relics) do
    if not owned[id] and not r.class and not r.noPool and (r.tier or 0) <= leagueTier(exp) then
      list[#list + 1] = id
    end
  end
  table.sort(list)
  return list
end

local function relicRarity(id) return ns.Relics[id].rarity or "common" end

local function drawRelics(exp, rng, n, weights, taken)
  return drawFrom(rng, X.relicPool(exp), relicRarity, n, weights, taken)
end

function X.potionPool(exp)
  local list = {}
  for id, p in pairs(ns.Potions) do
    if not p.noPool and (p.tier or 0) <= leagueTier(exp) then list[#list + 1] = id end
  end
  table.sort(list)
  return list
end

local function potionRarity(id) return ns.Potions[id].rarity or "common" end

local function drawPotions(exp, rng, n)
  return drawFrom(rng, X.potionPool(exp), potionRarity, n, X.POTION_WEIGHTS)
end

-- Bibelots de classe (Révéré) : relic.class == classe.
local function classRelics(exp)
  local list = {}
  for id, r in pairs(ns.Relics) do
    if r.class == exp.class and (r.tier or 0) <= leagueTier(exp) then list[#list + 1] = id end
  end
  table.sort(list)
  return list
end

---------------------------------------------------------------------------
-- Gains et pertes
---------------------------------------------------------------------------

function X.gainGold(exp, n, source)
  n = floor(X.modify(exp, "gold", n, source) + 0.5)
  if n < 0 then n = 0 end
  exp.gold = exp.gold + n
  exp.stats.goldEarned = exp.stats.goldEarned + n
  return n
end

local function spend(exp, n)
  exp.gold = exp.gold - n
  exp.stats.goldSpent = exp.stats.goldSpent + n
end

function X.gainRelic(exp, id)
  exp.relics[#exp.relics + 1] = id
  local r = ns.Relics[id]
  if r and r.run and r.run.onPickup then r.run.onPickup(exp) end
  if exp.hp > exp.maxHp then exp.hp = exp.maxHp end
end

function X.freeSlot(exp)
  for i = 1, #exp.potions do
    if not exp.potions[i] then return i end
  end
  return nil
end

function X.gainPotion(exp, id)
  local s = X.freeSlot(exp)
  if not s then return false end
  exp.potions[s] = id
  return true
end

function X.addCard(exp, id, up)
  exp.deck[#exp.deck + 1] = { id = id, up = up and true or false }
  exp.stats.cardsAdded = exp.stats.cardsAdded + 1
end

function X.canUpgrade(exp, i)
  local card = exp.deck[i]
  return card ~= nil and not card.up and ns.Cards[card.id] ~= nil and ns.Cards[card.id].up ~= nil
end

local function upgrade(exp, i)
  exp.deck[i].up = true
  exp.stats.upgraded = exp.stats.upgraded + 1
end

local function heal(exp, n)
  local before = exp.hp
  exp.hp = min(exp.maxHp, exp.hp + max(0, n))
  return exp.hp - before
end

function X.removePrice(exp)
  return X.REMOVE_PRICE + X.REMOVE_STEP * exp.removals
end

---------------------------------------------------------------------------
-- Déroulé
---------------------------------------------------------------------------

local function actDef(exp) return Map.ACTS[exp.act] end

local function finish(exp, result)
  exp.result = result
  exp.phase = "done"
  exp.combat, exp.fight, exp.reward, exp.shop, exp.event, exp.select = nil, nil, nil, nil, nil, nil
end

local function startAct(exp, act)
  exp.act = act
  exp.map = Map.generate(exp.rng.map, act)
  exp.node = nil
  exp.floor = 0
  exp.combatsInAct = 0
  exp.phase = "map"
end

local function clearNode(exp)
  if not exp.nodeCleared then
    exp.nodeCleared = true
    exp.stats.cleared = exp.stats.cleared + 1
  end
end

local function leaveNode(exp)
  clearNode(exp)
  exp.reward, exp.shop, exp.event, exp.select = nil, nil, nil, nil
  local node = exp.map.nodes[exp.node]
  if node.kind == "boss" then
    if exp.act < exp.acts then
      startAct(exp, exp.act + 1)
    else
      finish(exp, "won")
    end
  else
    exp.phase = "map"
  end
end

-- Récompense tirée à l'entrée de l'étape. genre : combat | elite | boss | chest.
local function rollReward(exp, kind)
  local rng = exp.rng.loot
  local r = { kind = kind }
  local g = X.GOLD[kind]
  if g and kind ~= "chest" then r.gold = Rng.int(rng, g[1], g[2]) end
  if kind ~= "chest" then r.cards = drawCards(exp, rng, 3, X.CARD_WEIGHTS[kind]) end
  if kind == "elite" or kind == "chest" then
    r.relic = drawRelics(exp, rng, 1, X.RELIC_WEIGHTS.normal)[1]
  elseif kind == "boss" then
    r.relic = drawRelics(exp, rng, 1, X.RELIC_WEIGHTS.boss)[1]
  end
  if kind == "chest" and not r.relic then r.gold = Rng.int(rng, g[1], g[2]) end
  if (kind == "combat" or kind == "elite") and Rng.float(rng) < X.POTION_DROP then
    r.potion = drawPotions(exp, rng, 1)[1]
  end
  return r
end

local function openReward(exp, r)
  if r.gold and r.gold > 0 then r.goldGained = X.gainGold(exp, r.gold, r.kind) end
  if r.relic then
    X.gainRelic(exp, r.relic)
    r.relicTaken = true
  end
  if r.potion then r.potionTaken = X.gainPotion(exp, r.potion) end
  r.cardsDone = not (r.cards and #r.cards > 0)
  exp.reward = r
  exp.phase = "reward"
end

local function endFight(exp)
  local c, f = exp.combat, exp.fight
  local p = c.player
  exp.hp = max(0, p.hp)
  exp.maxHp = p.maxHp
  if p.potions then exp.potions = U.copy(p.potions) end
  exp.combat, exp.fight = nil, nil
  if c.result == "won" then
    clearNode(exp)
    if f.kind == "elite" then exp.stats.elites = exp.stats.elites + 1 end
    if f.kind == "boss" then exp.stats.bosses = exp.stats.bosses + 1 end
    X.fire(exp, "onCombatWon", f.kind)
    openReward(exp, f.reward)
  else
    exp.killedBy = table.concat(f.encounter, "+")
    finish(exp, "lost")
  end
end

-- genre : combat | elite | boss ; pool : groupe de ns.Encounters (sinon déduit) ;
-- reward : récompense déjà tirée (sinon tirée maintenant).
local function startFight(exp, kind, pool, reward)
  local pools = ns.Encounters[actDef(exp).encounters]
  if not pool then
    if kind == "combat" then
      pool = exp.combatsInAct < X.EASY_COMBATS and "easy" or "normal"
    else
      pool = kind
    end
  end
  if kind == "combat" then exp.combatsInAct = exp.combatsInAct + 1 end
  local list = pools[pool]
  local rng = exp.rng.combat
  local idx
  for _ = 1, 5 do
    idx = Rng.int(rng, 1, #list)
    if idx ~= exp.lastEnc[pool] then break end
  end
  exp.lastEnc[pool] = idx
  local seed = Rng.int(rng, 1, 2147483646)
  exp.fight = { kind = kind, pool = pool, encounter = U.copyArr(list[idx]), seed = seed,
    reward = reward or rollReward(exp, kind) }
  exp.stats.combats = exp.stats.combats + 1
  exp.phase = "combat"
  exp.combat = Combat.new({ seed = seed, hp = exp.hp, maxHp = exp.maxHp, deck = exp.deck,
    encounter = list[idx], relics = exp.relics, potions = U.copy(exp.potions), affixes = exp.affixes,
    stats = exp.combatStats, quiet = exp.quiet })
  if exp.combat.result then endFight(exp) end
end

local function openShop(exp)
  local rng = exp.rng.merchant
  local function price(base, kind)
    local p = base * (1 - X.PRICE_JITTER + 2 * X.PRICE_JITTER * Rng.float(rng))
    p = X.modify(exp, "price", p, kind)
    return max(1, floor(p + 0.5))
  end
  local shop = { cards = {}, relics = {}, potions = {} }
  local cards = drawCards(exp, rng, X.SHOP.cards, X.CARD_WEIGHTS.shop)
  for i = 1, #cards do
    local base = X.PRICES.card[ns.Cards[cards[i]].rarity] or X.PRICES.card.uncommon
    shop.cards[i] = { id = cards[i], price = price(base, "card"), sold = false }
  end
  local nRelics = X.SHOP.relics + (exp.unlock.league >= ns.Meta.EXALTED and 1 or 0)
  local relics = drawRelics(exp, rng, nRelics, X.RELIC_WEIGHTS.normal)
  for i = 1, #relics do
    local base = X.PRICES.relic[relicRarity(relics[i])] or X.PRICES.relic.uncommon
    shop.relics[i] = { id = relics[i], price = price(base, "relic"), sold = false }
  end
  local potions = drawPotions(exp, rng, X.SHOP.potions)
  for i = 1, #potions do
    local base = X.PRICES.potion[potionRarity(potions[i])] or X.PRICES.potion.common
    shop.potions[i] = { id = potions[i], price = price(base, "potion"), sold = false }
  end
  exp.shop = shop
  exp.phase = "merchant"
end

-- Rencontres -------------------------------------------------------------------

function X.eventPool(exp)
  local list = {}
  for id, ev in pairs(ns.Events or {}) do
    if (ev.act == nil or ev.act == exp.act) and (ev.tier or 0) <= leagueTier(exp) and not exp.seenEvents[id] then
      list[#list + 1] = id
    end
  end
  table.sort(list)
  return list
end

local function openEvent(exp)
  local rng = exp.rng.events
  local pool = X.eventPool(exp)
  exp.phase = "event"
  if #pool == 0 then
    exp.event = { id = false, rolls = {}, chosen = false }
    return
  end
  local id = Rng.pick(rng, pool)
  exp.seenEvents[id] = true
  local ev = ns.Events[id]
  local rolls = {}
  for ci, ch in ipairs(ev.choices) do
    local r = {}
    for ei, e in ipairs(ch.effects) do
      local k = e[1]
      r[ei] = false
      if k == "cardChoice" then
        r[ei] = drawCards(exp, rng, e.n or 3, e.rarity and { [e.rarity] = 1 } or X.CARD_WEIGHTS.combat)
      elseif k == "relic" then
        r[ei] = drawRelics(exp, rng, 1, X.RELIC_WEIGHTS.normal)[1] or false
      elseif k == "potion" then
        r[ei] = drawPotions(exp, rng, 1)[1] or false
      elseif k == "fight" then
        r[ei] = rollReward(exp, "combat")
      end
    end
    rolls[ci] = r
  end
  exp.event = { id = id, rolls = rolls, chosen = false }
end

local function upgradable(exp)
  local list = {}
  for i = 1, #exp.deck do
    if X.canUpgrade(exp, i) then list[#list + 1] = i end
  end
  return list
end

-- Le choix ci de la rencontre est-il possible ? (true | false, raison)
function X.eventChoiceOk(exp, ci)
  local ev = exp.event and exp.event.id and ns.Events[exp.event.id]
  local ch = ev and ev.choices[ci]
  if not ch then return false, "choix" end
  for _, e in ipairs(ch.effects) do
    local k = e[1]
    if k == "pay" and exp.gold < e[2] then return false, "or" end
    if k == "remove" and #exp.deck <= 1 then return false, "deck" end
    if k == "upgrade" and #upgradable(exp) == 0 then return false, "amélioration" end
  end
  return true
end

local function applyEvent(exp, ci)
  local ev = ns.Events[exp.event.id]
  local ch = ev.choices[ci]
  local rolls = exp.event.rolls[ci]
  exp.event.chosen = ci
  local reward, follow
  local function rw()
    reward = reward or { kind = "event" }
    return reward
  end
  for ei, e in ipairs(ch.effects) do
    local k = e[1]
    if k == "heal" then
      heal(exp, e[2])
    elseif k == "healPct" then
      heal(exp, floor(exp.maxHp * e[2]))
    elseif k == "loseHp" then
      exp.hp = max(1, exp.hp - e[2])
    elseif k == "maxHp" then
      exp.maxHp = max(1, exp.maxHp + e[2])
      exp.hp = max(1, min(exp.maxHp, exp.hp + max(0, e[2])))
    elseif k == "gold" then
      rw().gold = (reward.gold or 0) + e[2]
    elseif k == "pay" then
      spend(exp, e[2])
    elseif k == "card" then
      X.addCard(exp, e[2], e.up)
    elseif k == "cardChoice" then
      rw().cards = U.copyArr(rolls[ei])
    elseif k == "relic" then
      if rolls[ei] then rw().relic = rolls[ei] end
    elseif k == "potion" then
      if rolls[ei] then rw().potion = rolls[ei] end
    elseif k == "upgradeRandom" then
      local list = Rng.shuffle(exp.rng.events, upgradable(exp))
      for i = 1, min(e[2], #list) do upgrade(exp, list[i]) end
    elseif k == "upgrade" or k == "remove" then
      follow = { kind = k }
    elseif k == "fight" then
      follow = { kind = "fight", pool = e[2], reward = U.copy(rolls[ei]), bonus = e.gold }
    else
      error("effet de rencontre inconnu : " .. tostring(k))
    end
  end
  if follow and follow.kind == "fight" then
    local r = follow.reward
    if follow.bonus then r.gold = (r.gold or 0) + follow.bonus end
    startFight(exp, "combat", follow.pool, r)
  elseif follow then
    exp.select = follow
    exp.phase = "select"
  elseif reward then
    openReward(exp, reward)
  end
end

-- Entrée dans un nœud ----------------------------------------------------------

local function enterNode(exp, id)
  local node = exp.map.nodes[id]
  exp.node = id
  exp.floor = node.floor
  exp.nodeCleared = false
  local v = exp.stats.visits
  v[node.kind] = (v[node.kind] or 0) + 1
  X.fire(exp, "onNodeEnter", node)
  local k = node.kind
  if k == "combat" or k == "elite" or k == "boss" then
    startFight(exp, k)
  elseif k == "campfire" then
    exp.phase = "campfire"
  elseif k == "merchant" then
    openShop(exp)
  elseif k == "event" then
    openEvent(exp)
  elseif k == "chest" then
    openReward(exp, rollReward(exp, "chest"))
  else
    error("type de nœud inconnu : " .. tostring(k))
  end
end

---------------------------------------------------------------------------
-- Création
---------------------------------------------------------------------------

-- opts : seed, class ("priest"), key (0..5), unlocks = { rep = 0..4, league = 0..4 },
--        acts (nombre d'actes, par défaut tous ceux de Map.ACTS),
--        stats (statistiques de combat, simulation), quiet (combat sans journal d'événements)
function X.new(opts)
  opts = opts or {}
  local seed = floor(opts.seed or 1)
  local class = opts.class or "priest"
  local cdef = ns.Classes[class]
  if not cdef then error("classe inconnue : " .. tostring(class)) end
  local unlock = opts.unlocks or {}
  local key = opts.key or 0
  local exp = {
    version = X.VERSION, seed = seed, class = class, key = key,
    affixes = ns.Meta.affixesFor(key),
    unlock = { rep = unlock.rep or 0, league = unlock.league or 0 },
    acts = min(opts.acts or #Map.ACTS, #Map.ACTS), act = 0, floor = 0,
    hp = cdef.hp, maxHp = cdef.hp, gold = X.START_GOLD,
    deck = {}, relics = {}, potions = {},
    removals = 0, combatsInAct = 0, lastEnc = {}, seenEvents = {}, relicState = {},
    nodeCleared = false,
    rng = {
      map = Rng.stream(seed, "map"),
      loot = Rng.stream(seed, "loot"),
      merchant = Rng.stream(seed, "merchant"),
      events = Rng.stream(seed, "events"),
      combat = Rng.stream(seed, "combat"),
    },
    stats = { cleared = 0, elites = 0, bosses = 0, combats = 0, goldEarned = 0, goldSpent = 0,
      cardsAdded = 0, removed = 0, upgraded = 0, visits = {} },
    combatStats = opts.stats and true or false,
    quiet = opts.quiet and true or false,
  }
  for i = 1, X.POTION_SLOTS do exp.potions[i] = false end
  for i = 1, #cdef.deck do exp.deck[i] = { id = cdef.deck[i], up = false } end
  startAct(exp, 1)
  if exp.unlock.rep >= ns.Meta.REVERED then
    local list = drawFrom(exp.rng.loot, classRelics(exp), relicRarity, 3,
      { common = 1, uncommon = 1, rare = 1, boss = 1 })
    if #list > 0 then
      exp.startRelics = list
      exp.phase = "start"
    end
  end
  return exp
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local H = {} -- H[phase][verbe] = function(exp, a) -> true | false, raison

H.start = {
  startRelic = function(exp, a)
    local id = exp.startRelics[a[2] or 0]
    if not id then return false, "index" end
    X.gainRelic(exp, id)
    exp.startRelics = nil
    exp.phase = "map"
    return true
  end,
  skipStartRelic = function(exp)
    exp.startRelics = nil
    exp.phase = "map"
    return true
  end,
}

H.map = {
  path = function(exp, a)
    local id = a[2]
    if not U.indexOf(Map.nextNodes(exp.map, exp.node), id) then return false, "chemin" end
    enterNode(exp, id)
    return true
  end,
}

local function afterCombatAction(exp, ok, why)
  if exp.combat and exp.combat.result then endFight(exp) end
  if ok then return true end
  return false, why
end

H.combat = {
  play = function(exp, a)
    return afterCombatAction(exp, Combat.play(exp.combat, a[2], a[3]))
  end,
  endTurn = function(exp)
    if not Combat.endTurn(exp.combat) then return false, "phase" end
    return afterCombatAction(exp, true)
  end,
  potion = function(exp, a)
    if not Combat.usePotion then return false, "potions" end
    return afterCombatAction(exp, Combat.usePotion(exp.combat, a[2], a[3]))
  end,
}

H.reward = {
  pickCard = function(exp, a)
    local r = exp.reward
    local id = not r.cardsDone and r.cards[a[2] or 0]
    if not id then return false, "carte" end
    X.addCard(exp, id)
    r.cardsDone = true
    r.picked = id
    return true
  end,
  skipCards = function(exp)
    if exp.reward.cardsDone then return false, "carte" end
    exp.reward.cardsDone = true
    return true
  end,
  takePotion = function(exp)
    local r = exp.reward
    if not r.potion or r.potionTaken then return false, "potion" end
    if not X.gainPotion(exp, r.potion) then return false, "emplacement" end
    r.potionTaken = true
    return true
  end,
  leave = function(exp)
    leaveNode(exp)
    return true
  end,
}

H.campfire = {
  rest = function(exp)
    local frac = X.modify(exp, "restFraction", X.REST_FRACTION)
    local n = floor(X.modify(exp, "restHeal", floor(exp.maxHp * frac)))
    exp.lastRest = heal(exp, n)
    X.fire(exp, "onRest")
    leaveNode(exp)
    return true
  end,
  upgrade = function(exp, a)
    if not X.canUpgrade(exp, a[2] or 0) then return false, "carte" end
    upgrade(exp, a[2])
    leaveNode(exp)
    return true
  end,
  leave = function(exp)
    leaveNode(exp)
    return true
  end,
}

local function buy(exp, list, i, give)
  local item = list[i or 0]
  if not item or item.sold then return false, "article" end
  if exp.gold < item.price then return false, "or" end
  local ok, why = give(item.id)
  if ok == false then return false, why end
  spend(exp, item.price)
  item.sold = true
  return true
end

H.merchant = {
  buyCard = function(exp, a)
    return buy(exp, exp.shop.cards, a[2], function(id) X.addCard(exp, id) end)
  end,
  buyRelic = function(exp, a)
    return buy(exp, exp.shop.relics, a[2], function(id) X.gainRelic(exp, id) end)
  end,
  buyPotion = function(exp, a)
    return buy(exp, exp.shop.potions, a[2], function(id)
      if not X.gainPotion(exp, id) then return false, "emplacement" end
    end)
  end,
  remove = function(exp, a)
    local i = a[2] or 0
    local price = X.removePrice(exp)
    if not exp.deck[i] or #exp.deck <= 1 then return false, "carte" end
    if exp.gold < price then return false, "or" end
    spend(exp, price)
    table.remove(exp.deck, i)
    exp.removals = exp.removals + 1
    exp.stats.removed = exp.stats.removed + 1
    return true
  end,
  leave = function(exp)
    leaveNode(exp)
    return true
  end,
}

H.event = {
  choose = function(exp, a)
    if exp.event.chosen then return false, "déjà choisi" end
    local ok, why = X.eventChoiceOk(exp, a[2] or 0)
    if not ok then return false, why end
    applyEvent(exp, a[2])
    return true
  end,
  leave = function(exp)
    if exp.event.id and not exp.event.chosen then return false, "choix" end
    leaveNode(exp)
    return true
  end,
}

H.select = {
  select = function(exp, a)
    local i = a[2] or 0
    local kind = exp.select.kind
    if kind == "upgrade" then
      if not X.canUpgrade(exp, i) then return false, "carte" end
      upgrade(exp, i)
    elseif kind == "remove" then
      if not exp.deck[i] or #exp.deck <= 1 then return false, "carte" end
      table.remove(exp.deck, i)
      exp.stats.removed = exp.stats.removed + 1
    end
    leaveNode(exp)
    return true
  end,
  skipSelect = function(exp)
    leaveNode(exp)
    return true
  end,
}

-- Actions possibles dans toutes les phases (sauf « done » ; jeter une potion : hors combat).
local COMMON = {
  discardPotion = function(exp, a)
    if exp.phase == "combat" then return false, "phase" end
    local s = a[2] or 0
    if not exp.potions[s] then return false, "emplacement" end
    exp.potions[s] = false
    return true
  end,
  abandon = function(exp)
    finish(exp, "abandoned")
    return true
  end,
}

function X.act(exp, a)
  if exp.phase == "done" then return false, "terminée" end
  -- Combat déjà tranché mais pas encore conclu (état rechargé, effet externe) : n'importe
  -- quelle action le conclut, et rien d'autre.
  if exp.phase == "combat" and exp.combat.result then
    endFight(exp)
    return true
  end
  local verb = a and a[1]
  local ph = H[exp.phase]
  local h = (ph and ph[verb]) or COMMON[verb]
  if not h then return false, "action" end
  return h(exp, a)
end

-- Liste des actions possibles maintenant (« abandon » est toujours possible et n'y figure pas).
function X.choices(exp)
  local list = {}
  local ph = exp.phase
  local function add(a) list[#list + 1] = a end
  if ph == "start" then
    for i = 1, #exp.startRelics do add({ "startRelic", i }) end
    add({ "skipStartRelic" })
  elseif ph == "map" then
    local nx = Map.nextNodes(exp.map, exp.node)
    for i = 1, #nx do add({ "path", nx[i] }) end
  elseif ph == "combat" then
    local c = exp.combat
    local plays = Combat.legalPlays(c)
    for i = 1, #plays do add({ "play", plays[i][1], plays[i][2] }) end
    local pots = c.player.potions
    if Combat.usePotion and pots then
      for s = 1, #pots do
        local p = pots[s] and ns.Potions[pots[s]]
        if p then
          if p.target then
            for j = 1, #c.enemies do
              if not c.enemies[j].dead then add({ "potion", s, j }) end
            end
          else
            add({ "potion", s })
          end
        end
      end
    end
    add({ "endTurn" })
  elseif ph == "reward" then
    local r = exp.reward
    if not r.cardsDone then
      for i = 1, #r.cards do add({ "pickCard", i }) end
      add({ "skipCards" })
    end
    if r.potion and not r.potionTaken and X.freeSlot(exp) then add({ "takePotion" }) end
    add({ "leave" })
  elseif ph == "campfire" then
    add({ "rest" })
    for i = 1, #exp.deck do
      if X.canUpgrade(exp, i) then add({ "upgrade", i }) end
    end
    add({ "leave" })
  elseif ph == "merchant" then
    local s = exp.shop
    local free = X.freeSlot(exp)
    for i, it in ipairs(s.cards) do
      if not it.sold and exp.gold >= it.price then add({ "buyCard", i }) end
    end
    for i, it in ipairs(s.relics) do
      if not it.sold and exp.gold >= it.price then add({ "buyRelic", i }) end
    end
    for i, it in ipairs(s.potions) do
      if free and not it.sold and exp.gold >= it.price then add({ "buyPotion", i }) end
    end
    if exp.gold >= X.removePrice(exp) and #exp.deck > 1 then
      for i = 1, #exp.deck do add({ "remove", i }) end
    end
    add({ "leave" })
  elseif ph == "event" then
    local ev = exp.event
    if ev.id and not ev.chosen then
      for i = 1, #ns.Events[ev.id].choices do
        if X.eventChoiceOk(exp, i) then add({ "choose", i }) end
      end
    else
      add({ "leave" })
    end
  elseif ph == "select" then
    for i = 1, #exp.deck do
      if exp.select.kind ~= "upgrade" or X.canUpgrade(exp, i) then add({ "select", i }) end
    end
    add({ "skipSelect" })
  end
  if ph ~= "done" and ph ~= "combat" then
    for s = 1, #exp.potions do
      if exp.potions[s] then add({ "discardPotion", s }) end
    end
  end
  return list
end

---------------------------------------------------------------------------
-- Lecture
---------------------------------------------------------------------------

function X.currentNode(exp)
  return exp.node and exp.map.nodes[exp.node] or nil
end

function X.actName(exp)
  local a = Map.ACTS[exp.act]
  return a and a.name or ""
end

-- Résumé archivable d'une expédition (journal).
function X.summary(exp)
  local s = exp.stats
  return {
    result = exp.result, class = exp.class, key = exp.key, seed = exp.seed,
    act = exp.act, floor = exp.floor, cleared = s.cleared, elites = s.elites, bosses = s.bosses,
    hp = exp.hp, maxHp = exp.maxHp, gold = exp.gold, goldEarned = s.goldEarned,
    deck = U.copy(exp.deck), relics = U.copyArr(exp.relics), killedBy = exp.killedBy,
  }
end
