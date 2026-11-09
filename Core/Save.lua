-- Format de sauvegarde (SavedVariables SlayTheDragonDB), un seul compte :
--   db = { version, meta = <Meta>, current = <expédition en cours ou nil>,
--          journal = { archives d'expéditions terminées }, quarantine = { états illisibles } }
-- Pas d'API WoW ici : l'interface branche Save sur la variable globale et rappelle
-- simplement la sauvegarde après chaque action (l'état est modifié sur place).
-- Une mise à jour migre, n'efface jamais : un état d'expédition illisible part en quarantaine.
local _, ns = ...

local U = ns.Util

local Save = {}
ns.Save = Save

Save.VERSION = 1

function Save.new()
  return { version = Save.VERSION, meta = ns.Meta.new(), current = nil, journal = {}, quarantine = {} }
end

---------------------------------------------------------------------------
-- Migrations : MIGRATIONS[v](db) fait passer db de la version v à v + 1.
---------------------------------------------------------------------------
Save.MIGRATIONS = {}

-- 0 -> 1 : table sans numéro de version (SavedVariables vide, ou sauvegarde de développement
-- avec seulement une partie des champs). On complète sans rien retirer.
Save.MIGRATIONS[0] = function(db)
  if type(db.meta) ~= "table" then db.meta = ns.Meta.new() end
  local m = db.meta
  m.league = tonumber(m.league) or 0
  m.runs = tonumber(m.runs) or 0
  if type(m.classes) ~= "table" then m.classes = {} end
  if type(db.journal) ~= "table" then db.journal = {} end
  if type(db.quarantine) ~= "table" then db.quarantine = {} end
end

-- Migrations de l'état d'une expédition en cours : EXP_MIGRATIONS[v](exp) de v à v + 1.
Save.EXP_MIGRATIONS = {}

local function quarantine(db, state, reason)
  db.quarantine[#db.quarantine + 1] = { reason = reason, state = state }
end

-- Met la sauvegarde au format courant. Accepte nil (première connexion).
-- Renvoie db (éventuellement une nouvelle table) et une note (nil si rien à signaler).
function Save.migrate(db)
  if type(db) ~= "table" then return Save.new(), "nouvelle" end
  local v = tonumber(db.version) or 0
  if v > Save.VERSION then
    -- Sauvegarde d'une version plus récente de l'addon : on n'y touche pas.
    return db, "plus récente"
  end
  local note
  while v < Save.VERSION do
    Save.MIGRATIONS[v](db)
    v = v + 1
    db.version = v
    note = "migrée"
  end
  local exp = db.current
  if exp ~= nil then
    if type(exp) ~= "table" then
      db.current = nil
      quarantine(db, exp, "type")
    else
      local ev = tonumber(exp.version) or 0
      while ev < ns.Expedition.VERSION and Save.EXP_MIGRATIONS[ev] do
        Save.EXP_MIGRATIONS[ev](exp)
        ev = ev + 1
        exp.version = ev
      end
      local ok, why = Save.validateExpedition(exp)
      if not ok then
        db.current = nil
        quarantine(db, exp, why)
        note = "expédition en quarantaine : " .. why
      end
    end
  end
  return db, note
end

---------------------------------------------------------------------------
-- Validation
---------------------------------------------------------------------------

-- Données simples : nombres finis, chaînes, booléens, tables sans métatable,
-- clés nombre/chaîne/booléen, sans cycle. Renvoie true ou false, chemin.
function Save.isPlain(v, path, seen)
  path = path or "db"
  local t = type(v)
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return false, path .. " (nombre invalide)" end
    return true
  end
  if t == "string" or t == "boolean" or t == "nil" then return true end
  if t ~= "table" then return false, path .. " (" .. t .. ")" end
  seen = seen or {}
  if seen[v] then return false, path .. " (cycle ou table partagée)" end
  seen[v] = true
  if getmetatable(v) ~= nil then return false, path .. " (métatable)" end
  for k, x in pairs(v) do
    local kt = type(k)
    if kt ~= "string" and kt ~= "number" and kt ~= "boolean" then return false, path .. " (clé " .. kt .. ")" end
    local ok, where = Save.isPlain(x, path .. "." .. tostring(k), seen)
    if not ok then return false, where end
  end
  return true
end

function Save.validateExpedition(exp)
  if type(exp) ~= "table" then return false, "expédition absente" end
  if exp.version ~= ns.Expedition.VERSION then return false, "version d'expédition " .. tostring(exp.version) end
  if not ns.Expedition.PHASES[exp.phase] then return false, "phase " .. tostring(exp.phase) end
  if type(exp.deck) ~= "table" or type(exp.map) ~= "table" or type(exp.rng) ~= "table" then
    return false, "champs manquants"
  end
  if type(exp.hp) ~= "number" or type(exp.gold) ~= "number" then return false, "PV ou or" end
  if not ns.Classes[exp.class] then return false, "classe " .. tostring(exp.class) end
  for i = 1, #exp.deck do
    if not ns.Cards[exp.deck[i].id] then return false, "carte inconnue " .. tostring(exp.deck[i].id) end
  end
  if exp.phase == "combat" and type(exp.combat) ~= "table" then return false, "combat manquant" end
  if exp.phase == "reward" and type(exp.reward) ~= "table" then return false, "récompense manquante" end
  if exp.phase == "merchant" and type(exp.shop) ~= "table" then return false, "marchand manquant" end
  if exp.phase == "event" and type(exp.event) ~= "table" then return false, "rencontre manquante" end
  return Save.isPlain(exp, "current")
end

-- Vérifie toute la sauvegarde. Renvoie true ou false, liste d'erreurs.
function Save.validate(db)
  local errs = {}
  local function err(s) errs[#errs + 1] = s end
  if type(db) ~= "table" then return false, { "sauvegarde absente" } end
  if db.version ~= Save.VERSION then err("version " .. tostring(db.version)) end
  local m = db.meta
  if type(m) ~= "table" or type(m.classes) ~= "table" or type(m.league) ~= "number" then
    err("meta")
  else
    for class, cs in pairs(m.classes) do
      if type(cs) ~= "table" or type(cs.rep) ~= "number" or type(cs.keyMax) ~= "number" then err("meta." .. tostring(class)) end
    end
  end
  if type(db.journal) ~= "table" then err("journal") end
  if db.current ~= nil then
    local ok, why = Save.validateExpedition(db.current)
    if not ok then err(why) end
  end
  local ok, where = Save.isPlain(db)
  if not ok then err(where) end
  return #errs == 0, errs
end

---------------------------------------------------------------------------
-- Cycle de vie d'une expédition
---------------------------------------------------------------------------

-- Démarre une expédition (opts : seed, class, key). Renvoie exp ou nil, raison.
function Save.start(db, opts)
  if db.current then return nil, "expédition en cours" end
  local exp, why = ns.Meta.newExpedition(db.meta, opts)
  if not exp then return nil, why end
  db.current = exp
  return exp
end

-- Archive l'expédition terminée (phase « done ») et applique la méta-progression.
-- date : chaîne ou nombre fourni par l'interface (pas d'API WoW ici).
-- Renvoie le résumé de méta-progression (voir Meta.record) et l'entrée du journal.
function Save.finish(db, date)
  local exp = db.current
  if not exp then return nil, "aucune expédition" end
  if exp.phase ~= "done" then return nil, "expédition en cours" end
  local summary = ns.Meta.record(db.meta, exp)
  local entry = ns.Expedition.summary(exp)
  entry.date = date
  entry.rep = summary.rep
  db.journal[#db.journal + 1] = entry
  db.current = nil
  return summary, entry
end

-- Abandonne l'expédition en cours et l'archive.
function Save.abandon(db, date)
  local exp = db.current
  if not exp then return nil, "aucune expédition" end
  if exp.phase ~= "done" then ns.Expedition.act(exp, { "abandon" }) end
  return Save.finish(db, date)
end

-- Copie profonde (pour une sauvegarde « instantané » si l'interface en veut une).
Save.copy = U.copy
