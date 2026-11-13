-- Campagne : les sept zones, dans l'ordre. Une expédition se joue dans une zone ; une zone est un jeu de
-- données (ennemis, élites, boss, rencontres, décors) fourni par son fichier Data/Zones/<Zone>.lua.
-- Contrat complet (ajouter une zone) : docs/zones.md.
--
-- ns.Zones[id] = { id, order (1..7), name, encounters (clé de ns.Encounters, posée par le fichier de
--                  la zone : sans elle la zone est déclarée mais pas jouable, « Coming later »),
--                  scenes = { [décor] = décor propre à la zone } (facultatif, interface) }
-- ns.Zone : lecture du registre (ordre, zone suivante, zone jouable).
local _, ns = ...

ns.Zones = ns.Zones or {}
local Z = {}
ns.Zone = Z

-- Ordre de la campagne (décision du joueur, 13/11/2026).
Z.ORDER = { "westfall", "duskwood", "wetlands", "stranglethorn", "swamp", "steppes", "blackrock" }
Z.FIRST = Z.ORDER[1]

local NAMES = {
  westfall = "Westfall",
  duskwood = "Duskwood",
  wetlands = "Wetlands",
  stranglethorn = "Stranglethorn Vale",
  swamp = "Swamp of Sorrows",
  steppes = "Burning Steppes",
  blackrock = "Blackrock Mountain",
}

for i, id in ipairs(Z.ORDER) do
  local z = ns.Zones[id] or {}
  z.id, z.order, z.name = id, i, NAMES[id]
  ns.Zones[id] = z
end

function Z.get(id)
  return id and ns.Zones[id] or nil
end

function Z.count()
  return #Z.ORDER
end

function Z.byOrder(n)
  return ns.Zones[Z.ORDER[n] or ""]
end

function Z.order(id)
  local z = ns.Zones[id]
  return z and z.order or nil
end

function Z.name(id)
  local z = ns.Zones[id]
  return z and z.name or tostring(id)
end

-- Zone suivante dans la campagne (nil après la dernière).
function Z.next(id)
  local n = Z.order(id)
  return n and Z.ORDER[n + 1] or nil
end

-- Zone précédente (nil pour la première).
function Z.prev(id)
  local n = Z.order(id)
  return n and n > 1 and Z.ORDER[n - 1] or nil
end

-- Jouable : ses données sont chargées (groupes de combats avec au moins un boss).
function Z.playable(id)
  local z = ns.Zones[id]
  local pools = z and z.encounters and ns.Encounters[z.encounters]
  return type(pools) == "table" and type(pools.boss) == "table" and #pools.boss > 0
end
