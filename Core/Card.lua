-- Cartes : une instance est { uid, id, up } et ne change jamais pendant un combat
-- (les clones de simulation la partagent). La définition vient de ns.Cards[id],
-- fusionnée avec def.up quand la carte est améliorée.
local _, ns = ...

local Card = {}
ns.Card = Card

local cache = {}

function Card.defById(id, up)
  local key = up and (id .. "+") or id
  local d = cache[key]
  if d then return d end
  local base = ns.Cards[id]
  if not base then error("unknown card: " .. tostring(id)) end
  d = {}
  for k, v in pairs(base) do
    if k ~= "up" then d[k] = v end
  end
  if up then
    if not base.up then error("card without upgrade: " .. id) end
    for k, v in pairs(base.up) do d[k] = v end
    d.name = base.name .. "+"
    d.isUp = true
  end
  cache[key] = d
  return d
end

function Card.def(inst)
  return Card.defById(inst.id, inst.up)
end

function Card.new(id, up, uid)
  return { id = id, up = up and true or false, uid = uid }
end

-- Une carte appartient à une classe (champ class) ou est commune (class absent : cartes neutres,
-- prévues par le GDD, proposées seulement chez le marchand et dans les rencontres : neutral = true).
-- Pas de champ de niveau de déblocage aujourd'hui en dehors de rep (palier de réputation) ; un champ
-- `level` pourra s'y ajouter (progression par classe), lu par les mêmes filtres.
function Card.inClass(d, class, neutral)
  if d.class == nil then return neutral and d.neutral == true end
  return d.class == class
end

-- Cartes proposables en récompense pour une classe (hors cartes de base) ; neutral = cartes neutres
-- comprises (marchand, rencontres).
function Card.pool(class, neutral)
  local list = {}
  for id, d in pairs(ns.Cards) do
    if Card.inClass(d, class, neutral) and d.rarity ~= "basic" and not d.noReward then
      list[#list + 1] = id
    end
  end
  table.sort(list)
  return list
end
