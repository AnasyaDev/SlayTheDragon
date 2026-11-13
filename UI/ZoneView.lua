-- Affichage générique des règles de zone (docs/zones.md, « Interface ») : ce que l'écran de combat lit
-- pour une zone, déclaré par la zone dans UI/Art/Zones/<zone>.lua, sans toucher à UI/CombatView.lua :
--
--   ns.ZoneViews.<zone> = {
--     counter = function(c) return { icon, text, tip, value, hot } end,  -- jeton en haut au centre
--     intent = function(c, e) return { icon, text, color, tip } end,   -- remplace la bulle d'intention
--     intentBadge = function(c, e) return { icon, tip } end,          -- petite icône à droite de l'intention
--     enemyBadges = function(c, e) return { { icon, text, tip, color, dim } } end, -- sous l'intention (Pack)
--     marks = function(c, e) return { { at, text, color } } end,      -- crans en plus sur la barre de vie
--     handMark = function(c, i, inst) return { rim, icon, tip } end, -- carte de la main marquée (Hex visé)
--     build = function(host, view) end, render = function(host, c, view) end,       -- zone libre (calque)
--     event = function(host, ev, view) end,                           -- animations (view:Push(délai, fn))
--   }
--
-- Registres communs (toutes zones) : Art.actionText[action] = function(a, c, e) -> ligne d'infobulle ;
-- Art.intentParts[action] = function(c, e, a) -> chiffre de la bulle (« +1 ») ; Art.bodyTints.token
-- (corps des cartes de combat, token = true). Les zones actives sont celles du combat (c.zone, c.zr).
local _, ns = ...
local Art = ns.Art

ns.ZoneViews = ns.ZoneViews or {}
Art.actionText = Art.actionText or {}
Art.intentParts = Art.intentParts or {}

local ZV = {}
ns.ZoneView = ZV

-- Vues de zone actives pour un combat (sa zone, puis les zones dont les règles y sont actives).
function ZV.active(c)
  local list, seen = {}, {}
  local function add(id)
    if id and not seen[id] and ns.ZoneViews[id] then
      seen[id] = true
      list[#list + 1] = ns.ZoneViews[id]
    end
  end
  if c then
    add(c.zone)
    for _, id in ipairs(c.zr or {}) do add(id) end
  end
  return list
end

-- Première réponse non nulle de la fonction `name` des vues actives.
function ZV.first(c, name, a, b)
  for _, v in ipairs(ZV.active(c)) do
    local f = v[name]
    if f then
      local r = f(c, a, b)
      if r then return r end
    end
  end
  return nil
end

-- Réponses de toutes les vues actives, mises bout à bout (listes).
function ZV.all(c, name, a, b)
  local out = {}
  for _, v in ipairs(ZV.active(c)) do
    local f = v[name]
    local r = f and f(c, a, b)
    if r then for i = 1, #r do out[#out + 1] = r[i] end end
  end
  return out
end

-- Corps des cartes de combat (token = true : Curse, Hexed, carte donnée par un boss) : cadre sobre,
-- ivoire assombri et bleui ; Art.cards[id].tint reste prioritaire.
Art.bodyTints = Art.bodyTints or {}
Art.bodyTints.token = Art.bodyTints.token or { 0.62, 0.58, 0.7 }
local baseTint = Art.cardBodyTint
function Art.cardBodyTint(id, d)
  local e = Art.cards[id]
  if e and e.tint then return e.tint end
  if d and d.token then return Art.bodyTints.token end
  return baseTint(id, d)
end
