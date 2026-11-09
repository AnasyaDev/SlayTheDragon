-- Sauvegarde dans SlayTheDragonDB (SavedVariables du compte).
-- Format provisoire, aligné sur celui prévu par Core/Save.lua (piste B) :
--   { version, meta = {}, current = état vivant | nil, journal = { ... }, options = { ... } }
-- « current » est une copie profonde de l'état du contrôleur (expédition + combat en cours),
-- réécrite après CHAQUE action du joueur. WoW n'écrit le fichier qu'au /reload, à la
-- déconnexion et à la fermeture normale du client.
local _, ns = ...

local U = ns.Util

local Persist = {}
ns.Persist = Persist

Persist.VERSION = 1
Persist.JOURNAL_MAX = 200

Persist.DEFAULT_OPTIONS = {
  autoOpen = true,     -- ouvrir au décollage
  autoClose = true,    -- fermer à l'atterrissage
  scale = 1.0,
  speed = 1.0,         -- multiplicateur de vitesse des animations
  fast = false,        -- mode rapide : animations quasi instantanées
  minimap = { hide = false, angle = 215 },
  facingPlayer = 0.6,  -- orientation des modèles (radians), réglable par /slay facing
  facingEnemy = -0.6,
  point = nil,         -- { point, relPoint, x, y } de la fenêtre
}

-- Migrations : MIGRATIONS[v] transforme une base de version v en version v + 1.
local MIGRATIONS = {
  -- [1] = function(db) ... end,
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

function Persist.fresh()
  return { version = Persist.VERSION, meta = {}, current = nil, journal = {},
    options = U.copy(Persist.DEFAULT_OPTIONS) }
end

-- Met une base au format courant. Une base illisible est remplacée (l'ancienne est gardée
-- dans meta.broken pour inspection), jamais une erreur Lua au chargement.
function Persist.migrate(db)
  if type(db) ~= "table" then return Persist.fresh() end
  local v = tonumber(db.version)
  if not v then
    -- Base sans version (premiers essais) : on garde seulement les options.
    local opts = type(db.options) == "table" and db.options or nil
    db = Persist.fresh()
    if opts then db.options = opts end
    v = Persist.VERSION
  end
  if v > Persist.VERSION then
    -- Sauvegarde d'une version plus récente de l'addon : on ne la casse pas, on la met de côté.
    local keep = db
    db = Persist.fresh()
    db.meta.future = keep
    v = Persist.VERSION
  end
  while v < Persist.VERSION do
    local m = MIGRATIONS[v]
    if m then m(db) end
    v = v + 1
  end
  db.version = Persist.VERSION
  if type(db.meta) ~= "table" then db.meta = {} end
  if type(db.journal) ~= "table" then db.journal = {} end
  if type(db.options) ~= "table" then db.options = {} end
  fillDefaults(db.options, Persist.DEFAULT_OPTIONS)
  return db
end

-- Lit (et normalise) la base globale ; à appeler à ADDON_LOADED.
function Persist.load()
  local db = Persist.migrate(_G.SlayTheDragonDB)
  _G.SlayTheDragonDB = db
  Persist.db = db
  return db
end

function Persist.options()
  return (Persist.db or Persist.load()).options
end

-- Copie l'état vivant dans la base. live = nil efface l'expédition en cours.
function Persist.store(live)
  local db = Persist.db or Persist.load()
  db.current = live and U.copy(live) or nil
  db.meta.saves = (db.meta.saves or 0) + 1
  if type(time) == "function" then db.meta.savedAt = time() end
end

-- Copie de l'état sauvegardé, à reprendre comme état vivant.
function Persist.restore()
  local db = Persist.db or Persist.load()
  if type(db.current) ~= "table" then return nil end
  return U.copy(db.current)
end

function Persist.archive(entry)
  local db = Persist.db or Persist.load()
  local j = db.journal
  j[#j + 1] = entry
  while #j > Persist.JOURNAL_MAX do table.remove(j, 1) end
end
