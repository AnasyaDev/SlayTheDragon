-- Chargement de SlayTheDragonDB et options de l'interface.
-- Le format de la sauvegarde appartient à Core/Save.lua (migrations, validation, quarantaine,
-- journal) ; l'interface n'y ajoute qu'un champ `options`, que Save garde tel quel.
-- L'expédition en cours (db.current) est modifiée sur place par Core/Expedition.lua :
-- rien à recopier après une action. WoW écrit le fichier au /reload, à la déconnexion
-- et à la fermeture normale du client.
local _, ns = ...

local U, Save = ns.Util, ns.Save

local Persist = {}
ns.Persist = Persist

Persist.DEFAULT_OPTIONS = {
  autoOpen = true,     -- ouvrir au décollage
  autoClose = true,    -- fermer à l'atterrissage
  scale = 1.0,
  speed = 1.0,         -- multiplicateur de vitesse des animations
  fast = false,        -- mode rapide : animations quasi instantanées
  decor = true,        -- décor illustré (illustrations validées seulement) ; faux = toujours peint
  artChecks = {},      -- verdicts de /slay decor essai : tostring(fichier) -> true (validé) | false (refusé)
  minimap = { hide = false, angle = 215 },
  facingPlayer = 0.6,  -- orientation des modèles (radians), réglable par /slay facing
  facingEnemy = -0.6,
  point = nil,         -- { point, relPoint, x, y } de la fenêtre
}

local function fillDefaults(dst, defaults)
  for k, v in pairs(defaults) do
    if dst[k] == nil then
      dst[k] = U.copy(v)
    elseif type(v) == "table" and type(dst[k]) == "table" then
      fillDefaults(dst[k], v)
    end
  end
end

-- Lit (et met au format courant) la base globale ; à appeler à ADDON_LOADED.
-- Une sauvegarde d'une version plus récente de l'addon n'est pas touchée : on joue alors
-- sur une base de session, jamais écrite (Persist.readOnly).
function Persist.init()
  local db, note = Save.migrate(_G.SlayTheDragonDB)
  Persist.note = note
  if note == "plus récente" then
    Persist.readOnly = true
    db = Save.new()
  else
    Persist.readOnly = false
    _G.SlayTheDragonDB = db
  end
  if type(db.options) ~= "table" then db.options = {} end
  fillDefaults(db.options, Persist.DEFAULT_OPTIONS)
  Persist.db = db
  return db, note
end

function Persist.options()
  return (Persist.db or Persist.init()).options
end
