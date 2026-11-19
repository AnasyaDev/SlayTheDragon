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

-- Dureté des zones (décision du joueur, 19/11/2026 : sans carte épique, la campagne bute après la zone 4 ;
-- docs/expedition.md, « Campagne continue », et docs/equilibrage.md, « Mur des zones 4 à 7 sans épique »).
-- Facteurs appliqués à TOUS les ennemis d'un combat de la zone (normaux, élites, boss, invoqués) :
--   hp  : PV à l'apparition (Combat.spawn, après hpMul, avant le crochet « enemyHp » des clés) ;
--   dmg : dégâts de leurs coups (Combat.calcDamage, après la Force, avant le crochet « enemyDamage » des clés).
-- Arrondi au plus proche. Zone absente = 1 et 1 (les fiches ne changent pas : les vrais chiffres sont sur
-- l'unité et dans les intentions, lus tels quels par l'interface et les bots ; Combat.zoneHard). Réglés au bot
-- human, clé 0, compte vétéran sans épique (`zones=7 epic=none`) : battue/atteinte ≈ 60 / 35 / 30 / 25 %.
-- epicHp / epicDmg (facultatifs, ABSENTS) : facteurs à la place de hp / dmg quand le deck du combat a une épique
-- (c.epic) ; levier « l'épique contre la dureté de la zone » mesuré le 19/11/2026 et écarté par le joueur
-- (artificiel) : c'est le cumul de plusieurs épiques qui doit passer le mur (Expedition.EPIC.max ;
-- docs/equilibrage.md). Code de lecture gardé, inerte. Seul endroit à régler ; la simulation les remplace sans
-- recoder : `zonehp=stranglethorn:1.3,swamp:1.4 zonedmg=… zoneepichp=… zoneepicdmg=…` (Sim/sim.lua).
Z.HARD = {
  stranglethorn = { hp = 1.45, dmg = 1.45 },
  swamp = { hp = 1.8, dmg = 1.8 },
  steppes = { hp = 2.15, dmg = 2.15 },
  blackrock = { hp = 2.3, dmg = 2.3 },
}

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
