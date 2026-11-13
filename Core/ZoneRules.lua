-- Socle des règles de zone. Chaque zone qui a une mécanique pose ns.ZoneRules[id] dans
-- Core/ZoneRules/<id>.lua (sur le modèle de ns.ClassRules) :
--
--   ns.ZoneRules.<id> = {
--     always = false,               -- vrai : crochets actifs dans TOUTES les zones (Asleep de Dream Dust)
--     init = function(c, z) end,    -- début du combat, après l'init de la classe, avant onCombatStart
--     hooks = { <nom> = function(c, z, ...) end },  -- mêmes noms que les classes, Pouvoirs, bibelots
--     run = { <nom> = function(exp, ...) end },     -- crochets d'expédition (comme relic.run)
--     campfire = { { id, label, text, can = f(exp), apply = f(exp) } }, -- actions du feu de camp
--     botKey = function(c) return "" end, botValue = function(c, W) return 0 end, -- bots (Sim/)
--   }
--
-- z = c.zs[id] : état de la zone dans le combat (données simples, copié en profondeur par Combat.clone,
-- sauvegardé). État propre à un ennemi : e.zs[id] (ZR.unitState). Liste des crochets et aides :
-- docs/zones.md. Ce fichier ne contient aucune règle de zone.
local _, ns = ...

local Combat = ns.Combat
local ZR = {}
ns.ZoneRule = ZR

-- Déclare les règles d'une zone (id de ns.Zones) ; renvoie la table.
function ZR.define(id, t)
  t = t or {}
  t.id = id
  t.hooks = t.hooks or {}
  ns.ZoneRules[id] = t
  return t
end

-- Règles de la zone id si elles sont actives dans ce combat (zone du combat ou always), sinon nil.
function ZR.active(c, id)
  return c.zs ~= nil and c.zs[id] ~= nil
end

-- État de zone propre à une unité (créé au besoin) : e.zs[id].
function ZR.unitState(e, id)
  e.zs = e.zs or {}
  local s = e.zs[id]
  if not s then
    s = {}
    e.zs[id] = s
  end
  return s
end

-- Texte flottant sur une unité (uid ou "player") : journal { t = "float", unit, text, color } lu par
-- l'interface (couleur : clé de Art.C, « watchText » par défaut).
function ZR.float(c, unit, text, color)
  Combat.log(c, { t = "float", unit = unit, text = text, color = color })
end

-- Compteur de combat affichable (Wildfire) : la valeur vit dans l'état de la zone ; ce journal
-- { t = "counter", zone, key, n, d } fait battre le jeton en haut de l'écran (ns.ZoneViews[zone].counter).
function ZR.counterChanged(c, zone, key, n, d)
  Combat.log(c, { t = "counter", zone = zone, key = key, n = n, d = d })
end

-- Genre du combat en cours (« combat », « elite », « boss » ; nil hors expédition).
function ZR.kind(c) return c.kind end

---------------------------------------------------------------------------
-- Familier du Hunter (Core/Classes/hunter.lua, non modifié) : ses coups portent la source « pet »
-- (à une cible), et sa cible passe par le crochet « petTarget » (c, src, cible) : une zone peut la
-- changer (Swamp of Sorrows : éviter les dormeurs tant qu'un ennemi est éveillé). Sans crochet, rien
-- ne change.
---------------------------------------------------------------------------
local H = ns.Hunter
if H and H.petAttack and not H.zoneAdapted then
  H.zoneAdapted = true
  local petAttack, petTarget = H.petAttack, H.petTarget
  H.petAttack = function(c, why, frenzy)
    local k0, a0 = c.hitKind, c.hitAll
    c.hitKind, c.hitAll = "pet", false
    local r = petAttack(c, why, frenzy)
    c.hitKind, c.hitAll = k0, a0
    return r
  end
  H.petTarget = function(c)
    local t = petTarget(c)
    return Combat.zmodify(c, "petTarget", t)
  end
end
