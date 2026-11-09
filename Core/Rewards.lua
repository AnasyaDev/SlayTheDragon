-- Tirages de récompenses.
local _, ns = ...

local Rng, Card = ns.Rng, ns.Card
local Rewards = {}
ns.Rewards = Rewards

Rewards.RARITY_WEIGHT = { common = 60, uncommon = 33, rare = 7 }

-- n cartes distinctes de la classe, tirées par rareté.
function Rewards.cardChoices(rng, class, n, weights)
  weights = weights or Rewards.RARITY_WEIGHT
  local pool = Card.pool(class)
  local byRarity = {}
  for i = 1, #pool do
    local r = ns.Cards[pool[i]].rarity
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
