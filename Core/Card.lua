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
-- Déblocage : level (niveau de classe), zone (carte de zone), tier (neutres : palier commun), lus par
-- Expedition.unlocked (docs/zones.md).
function Card.inClass(d, class, neutral)
  if d.class == nil then return neutral and d.neutral == true end
  return d.class == class
end

-- Carte épique (rarity = "epic", au-dessus de rare) : une seule par expédition (docs/expedition.md, « Cartes
-- épiques »), jamais dans les récompenses ordinaires.
function Card.isEpic(d)
  return d ~= nil and d.rarity == "epic"
end

-- Carte collectionnable : proposable en récompense, chez le marchand, en rencontre, montrée par la
-- progression. Une variante (variant = true : carte transformée par une épique, champ transforms) ne
-- l'est jamais.
function Card.collectible(d)
  return d ~= nil and not d.variant
end

-- Transformations d'un deck { {id, up}, … } par son épique : la carte épique (la première du deck) peut
-- porter transforms = { [id_origine] = id_variante } (sur sa définition de base ou améliorée) ; tant
-- qu'elle est dans le deck, chaque carte d'origine est remplacée par sa variante, qui garde l'état
-- amélioré de l'originale (si la variante a une amélioration). Renvoie le deck lui-même s'il n'y a rien à
-- transformer (aucune copie : sans épique, rien ne change), sinon une copie alignée (même ordre, même
-- longueur ; champ from = id d'origine).
function Card.transformsOf(deck)
  for i = 1, #deck do
    local base = ns.Cards[deck[i].id]
    if base and base.rarity == "epic" then
      local d = Card.defById(deck[i].id, deck[i].up and base.up ~= nil)
      return d.transforms
    end
  end
  return nil
end

function Card.applyTransforms(deck)
  local map = Card.transformsOf(deck)
  if not map or next(map) == nil then return deck end
  local out = {}
  for i = 1, #deck do
    local card = deck[i]
    local v = map[card.id]
    local vd = v and ns.Cards[v]
    if vd then
      out[i] = { id = v, up = (card.up and vd.up ~= nil) and true or false, from = card.id }
    else
      out[i] = card
    end
  end
  return out
end

-- Cartes proposables en récompense pour une classe (hors cartes de base, épiques et variantes) ; neutral =
-- cartes neutres comprises (marchand, rencontres).
function Card.pool(class, neutral)
  local list = {}
  for id, d in pairs(ns.Cards) do
    if Card.inClass(d, class, neutral) and d.rarity ~= "basic" and d.rarity ~= "epic" and not d.noReward
        and not d.variant then
      list[#list + 1] = id
    end
  end
  table.sort(list)
  return list
end
