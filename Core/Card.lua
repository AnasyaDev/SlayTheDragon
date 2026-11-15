-- Cartes : une instance est { uid, id, up } et ne change jamais pendant un combat
-- (les clones de simulation la partagent). La définition vient de ns.Cards[id],
-- fusionnée avec ses paliers d'amélioration (docs/ameliorations.md).
--
-- Paliers (décision du joueur du 15/11/2026 : jusqu'à trois améliorations, écrites à la main) : la fiche
-- porte up (palier 1), up2, up3 ; chaque palier ne donne que les champs qui changent PAR RAPPORT AU PALIER
-- PRÉCÉDENT (cumul : fiche effective au palier n = base ⊕ up ⊕ … ⊕ up_n, tables remplacées en bloc). Un palier
-- n'existe que si les précédents existent (Card.tiers).
-- Instance : up = false (palier 0) ou le palier 1..3 (nombre). up = true (forme d'avant les paliers, encore
-- écrite par du code ou des données plus anciennes) vaut le palier 1 partout : lire le palier par Card.level,
-- tester « améliorée » par la vérité de up (vrai dès le palier 1).
local _, ns = ...

local Card = {}
ns.Card = Card

-- Palier maximal d'une carte, et champs de la fiche qui portent les paliers 1, 2, 3.
Card.MAX_UP = 3
Card.UP_KEYS = { "up", "up2", "up3" }

local cache = {}

-- Palier 0..3 d'une instance ou d'une valeur du champ up (false / nil = 0, true = 1, n = n).
function Card.level(x)
  if type(x) == "table" then x = x.up end
  if x == true then return 1 end
  if type(x) == "number" and x >= 1 then
    x = math.floor(x)
    return x < Card.MAX_UP and x or Card.MAX_UP
  end
  return 0
end

-- Valeur du champ up d'une instance pour un palier (ou une valeur up) : false au palier 0, sinon le nombre.
function Card.upValue(x)
  local n = Card.level(x)
  return n > 0 and n or false
end

-- Suffixe du nom au palier n : "", "+", "+2", "+3".
function Card.suffix(x)
  local n = Card.level(x)
  if n == 0 then return "" end
  return n == 1 and "+" or ("+" .. n)
end

-- Nombre de paliers écrits d'une carte (0..3) : up, puis up2, puis up3, sans trou.
function Card.tiers(id)
  local base = ns.Cards[id]
  if not base then return 0 end
  local n = 0
  while n < Card.MAX_UP and base[Card.UP_KEYS[n + 1]] ~= nil do n = n + 1 end
  return n
end

-- Une carte à ce palier (instance ou valeur up) peut-elle monter d'un palier ? (palier suivant écrit, < 3)
function Card.canUp(id, up)
  return Card.level(up) < Card.tiers(id)
end

-- Fiche effective d'une carte à un palier (valeur up : false, true, 1..3). Champs ajoutés : plus = palier
-- (0..3), isUp = true dès le palier 1 ; nom suivi de Card.suffix. Un palier non écrit est une erreur.
-- Cache par palier puis par id (aucune chaîne construite à chaque appel : appelé des millions de fois par
-- les crochets en simulation).
function Card.defById(id, up)
  local n
  if not up then n = 0 elseif up == true then n = 1 else n = Card.level(up) end
  local byId = cache[n]
  local d = byId[id]
  if d then return d end
  local base = ns.Cards[id]
  if not base then error("unknown card: " .. tostring(id)) end
  d = {}
  for k, v in pairs(base) do
    if k ~= "up" and k ~= "up2" and k ~= "up3" then d[k] = v end
  end
  d.plus = n
  if n > 0 then
    for i = 1, n do
      local t = base[Card.UP_KEYS[i]]
      if not t then error("card without upgrade " .. i .. ": " .. id) end
      for k, v in pairs(t) do d[k] = v end
    end
    d.name = base.name .. Card.suffix(n)
    d.isUp = true
  end
  byId[id] = d
  return d
end

-- Oublie les fiches effectives calculées (tests et harnais qui posent ou retirent des paliers en cours de route).
function Card.clearCache()
  cache = { [0] = {}, {}, {}, {} }
end
Card.clearCache()

function Card.def(inst)
  return Card.defById(inst.id, inst.up)
end

function Card.new(id, up, uid)
  return { id = id, up = Card.upValue(up), uid = uid }
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
      local d = Card.defById(deck[i].id, math.min(Card.level(deck[i]), Card.tiers(deck[i].id)))
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
      -- la variante garde le palier de l'originale, borné à ses propres paliers écrits
      out[i] = { id = v, up = Card.upValue(math.min(Card.level(card), Card.tiers(v))), from = card.id }
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
