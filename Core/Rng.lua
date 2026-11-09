-- Générateur pseudo-aléatoire déterministe (Park-Miller, multiplicateur 48271).
-- Arithmétique en doubles uniquement : exact en Lua 5.1, LuaJIT et dans WoW.
-- L'état est une table de données simple, donc copiable et sauvegardable.
local _, ns = ...

local Rng = {}
ns.Rng = Rng

local M = 2147483647
local A = 48271
local floor = math.floor

function Rng.next(r)
  r.s = (r.s * A) % M
  return r.s
end

function Rng.new(seed)
  local s = floor(seed or 1) % M
  if s <= 0 then s = s + M - 1 end
  local r = { s = s }
  for _ = 1, 4 do Rng.next(r) end
  return r
end

local function hash(str)
  local h = 5381
  for i = 1, #str do h = (h * 33 + str:byte(i)) % M end
  return h
end

-- Flux indépendant nommé, dérivé d'une graine : chaque usage (pioche, IA, butin...)
-- a le sien, pour qu'un choix dans l'un ne décale pas les tirages de l'autre.
function Rng.stream(seed, name)
  return Rng.new((floor(seed) % M) * 7919 % M + hash(name))
end

-- Flottant dans [0, 1[.
function Rng.float(r)
  return (Rng.next(r) - 1) / (M - 1)
end

-- Entier dans [lo, hi].
function Rng.int(r, lo, hi)
  return lo + floor(Rng.float(r) * (hi - lo + 1))
end

function Rng.shuffle(r, t)
  for i = #t, 2, -1 do
    local j = Rng.int(r, 1, i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

function Rng.pick(r, t)
  return t[Rng.int(r, 1, #t)]
end

-- items : liste ; weightOf(item) -> poids positif.
function Rng.weighted(r, items, weightOf)
  local total = 0
  for i = 1, #items do total = total + weightOf(items[i]) end
  local x = Rng.float(r) * total
  for i = 1, #items do
    x = x - weightOf(items[i])
    if x < 0 then return items[i] end
  end
  return items[#items]
end
