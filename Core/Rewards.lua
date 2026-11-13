-- Tirages de récompenses.
local _, ns = ...

local Rng, Card = ns.Rng, ns.Card
local Rewards = {}
ns.Rewards = Rewards

Rewards.RARITY_WEIGHT = { common = 60, uncommon = 33, rare = 7 }
Rewards.RELIC_WEIGHT = { common = 50, uncommon = 35, rare = 15 }
Rewards.POTION_WEIGHT = { common = 65, uncommon = 25, rare = 10 }

-- Cartes de la classe débloquées au niveau de classe maxLevel (1..7 ; nil = toutes).
function Rewards.cardPool(class, maxLevel)
  local pool = Card.pool(class)
  if maxLevel == nil then return pool end
  local list = {}
  for i = 1, #pool do
    if (ns.Cards[pool[i]].level or 1) <= maxLevel then list[#list + 1] = pool[i] end
  end
  return list
end

-- n éléments distincts de pool (liste d'ids), tirés d'abord par rareté.
local function pickByRarity(rng, pool, n, rarityOf, weights)
  local byRarity = {}
  for i = 1, #pool do
    local r = rarityOf(pool[i])
    byRarity[r] = byRarity[r] or {}
    table.insert(byRarity[r], pool[i])
  end
  local picked, seen = {}, {}
  local guard = 0
  while #picked < n and guard < 200 do
    guard = guard + 1
    local rarities = {}
    for r, list in pairs(byRarity) do
      if #list > 0 and (weights[r] or 0) > 0 then rarities[#rarities + 1] = r end
    end
    if #rarities == 0 then break end
    table.sort(rarities)
    local rarity = Rng.weighted(rng, rarities, function(r) return weights[r] end)
    local id = Rng.pick(rng, byRarity[rarity])
    if not seen[id] then
      seen[id] = true
      picked[#picked + 1] = id
    end
  end
  return picked
end

-- n cartes distinctes de la classe, tirées par rareté. maxLevel : niveau de classe atteint
-- (1..7 ; nil = toutes les cartes).
function Rewards.cardChoices(rng, class, n, weights, maxLevel)
  return pickByRarity(rng, Rewards.cardPool(class, maxLevel), n,
    function(id) return ns.Cards[id].rarity end, weights or Rewards.RARITY_WEIGHT)
end

-- Ids triés des bibelots débloqués au palier commun maxTier (zones gagnées par le compte).
-- opts : { maxTier = n (nil = tous), boss = bool (bibelots de boss seulement, sinon exclus),
--          exclude = { [id] = true } (déjà possédés), class = classe jouée, level = niveau de classe (nil = tous) }
-- Bibelots communs (sans champ class, filtrés par maxTier) et ceux de la classe jouée (filtrés par
-- level) ; jamais ceux marqués noPool.
function Rewards.relicPool(opts)
  opts = opts or {}
  local list = {}
  for id, r in pairs(ns.Relics) do
    local isBoss = r.rarity == "boss"
    local open
    if r.class then open = opts.level == nil or (r.level or 1) <= opts.level
    else open = opts.maxTier == nil or (r.tier or 0) <= opts.maxTier end
    -- bibelots de clé (champ key, sans tier) : tirés par l'expédition seule, une fois débloqués (X.relicPool)
    if open and (isBoss == (opts.boss or false)) and not r.key
        and not r.noPool and (not r.class or r.class == opts.class)
        and not (opts.class and ns.Expedition and not ns.Expedition.usefulFor(r, opts.class))
        and not (opts.exclude and opts.exclude[id]) then
      list[#list + 1] = id
    end
  end
  table.sort(list)
  return list
end

-- n bibelots distincts (moins si la réserve est épuisée).
function Rewards.relicChoices(rng, n, opts)
  local pool = Rewards.relicPool(opts)
  if opts and opts.boss then
    local picked = {}
    Rng.shuffle(rng, pool)
    for i = 1, math.min(n, #pool) do picked[i] = pool[i] end
    return picked
  end
  return pickByRarity(rng, pool, n, function(id) return ns.Relics[id].rarity end, Rewards.RELIC_WEIGHT)
end

-- Ids triés des potions débloquées au palier maxTier (nil = toutes).
function Rewards.potionPool(maxTier)
  local list = {}
  for id, p in pairs(ns.Potions) do
    if maxTier == nil or (p.tier or 0) <= maxTier then list[#list + 1] = id end
  end
  table.sort(list)
  return list
end

-- Une potion au hasard, pondérée par rareté.
function Rewards.randomPotion(rng, maxTier)
  local pool = Rewards.potionPool(maxTier)
  if #pool == 0 then return nil end
  return pickByRarity(rng, pool, 1, function(id) return ns.Potions[id].rarity end, Rewards.POTION_WEIGHT)[1]
end
