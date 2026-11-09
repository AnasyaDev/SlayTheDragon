-- Slay the Dragon : espace de noms partagé et utilitaires.
-- Tout ce qui est dans Core/ et Data/ doit rester du Lua 5.1 pur, sans API WoW,
-- pour tourner aussi hors du jeu (simulation).
local _, ns = ...

ns.Cards = ns.Cards or {}
ns.Enemies = ns.Enemies or {}
ns.Encounters = ns.Encounters or {}
ns.Relics = ns.Relics or {}
ns.Potions = ns.Potions or {}
ns.Statuses = ns.Statuses or {}

local U = {}
ns.Util = U

-- Copie profonde de données simples (pas de cycles, pas de fonctions à copier).
function U.copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = U.copy(x) end
  return t
end

function U.copyArr(t)
  local r = {}
  for i = 1, #t do r[i] = t[i] end
  return r
end

function U.copyMap(t)
  local r = {}
  for k, v in pairs(t) do r[k] = v end
  return r
end

function U.indexOf(t, v)
  for i = 1, #t do if t[i] == v then return i end end
  return nil
end
