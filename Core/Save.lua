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

-- 1 : format initial ; 2 : drapeaux de compte (meta.flags) ; 3 : classes (expédition version 3 :
-- ressource de combat générique).
Save.VERSION = 3

function Save.new()
  return { version = Save.VERSION, meta = ns.Meta.new(), current = nil, journal = {}, quarantine = {} }
end

---------------------------------------------------------------------------
-- Migrations : MIGRATIONS[v](db) fait passer db de la version v à v + 1.
---------------------------------------------------------------------------
Save.MIGRATIONS = {}

-- Complète les champs indispensables sans rien retirer (idempotent). Sert de migration
-- 0 -> 1 et répare aussi une sauvegarde déjà numérotée dont la méta est incomplète
-- (sauvegarde de développement de l'interface, par exemple). Les champs inconnus,
-- comme db.options (réglages de l'interface), sont gardés tels quels.
function Save.normalize(db)
  if type(db.meta) ~= "table" then db.meta = ns.Meta.new() end
  local m = db.meta
  m.league = tonumber(m.league) or 0
  m.runs = tonumber(m.runs) or 0
  if type(m.classes) ~= "table" then m.classes = {} end
  -- Drapeaux de compte : on ne garde que les entrées vraies, on n'en retire jamais une.
  if type(m.flags) ~= "table" then m.flags = {} end
  for k, v in pairs(m.flags) do
    if v ~= true then m.flags[k] = v and true or nil end
  end
  if type(db.journal) ~= "table" then db.journal = {} end
  if type(db.quarantine) ~= "table" then db.quarantine = {} end
end

-- 0 -> 1 : table sans numéro de version (SavedVariables vide, ou sauvegarde de développement
-- avec seulement une partie des champs).
Save.MIGRATIONS[0] = Save.normalize

-- 1 -> 2 : drapeaux de compte (meta.flags, vide au départ ; normalize le crée).
Save.MIGRATIONS[1] = Save.normalize

-- 2 -> 3 : rien à changer dans la méta (meta.classes est déjà indexé par classe) ; l'expédition en
-- cours passe par EXP_MIGRATIONS[2].
Save.MIGRATIONS[2] = Save.normalize

-- Migrations de l'état d'une expédition en cours : EXP_MIGRATIONS[v](exp) de v à v + 1.
Save.EXP_MIGRATIONS = {}

-- Expédition 1 -> 2 : drapeaux de compte (aucun connu : l'expédition a commencé avant) et
-- journal des rencontres.
Save.EXP_MIGRATIONS[1] = function(exp)
  if type(exp.flags) ~= "table" then exp.flags = {} end
  if type(exp.newFlags) ~= "table" then exp.newFlags = {} end
  if type(exp.stats) == "table" and type(exp.stats.events) ~= "table" then exp.stats.events = {} end
end

-- Expédition 2 -> 3 : classe générique. La Démence du combat en cours (c.player.demence) devient la
-- ressource de classe (c.player.res) ; le combat connaît sa classe (c.class) et son état (c.cls).
Save.EXP_MIGRATIONS[2] = function(exp)
  if exp.class == nil then exp.class = "priest" end
  local c = exp.combat
  if type(c) == "table" then
    if c.class == nil then c.class = exp.class end
    if type(c.cls) ~= "table" then c.cls = {} end
    if type(c.turn) ~= "table" then c.turn = { played = 0, byType = {}, bySchool = {} } end
    if type(c.traps) ~= "table" then c.traps = {} end
    if type(c.rng) == "table" and c.rng.cards == nil then c.rng.cards = ns.Rng.stream(c.seed or 1, "cards") end
    local p = c.player
    if type(p) == "table" then
      if p.res == nil then p.res = tonumber(p.demence) or 0 end
      p.demence = nil
    end
  end
end

local function quarantine(db, state, reason)
  db.quarantine[#db.quarantine + 1] = { reason = reason, state = state }
end

-- Met l'expédition en cours de côté (illisible pour l'interface, erreur à la reprise…).
function Save.quarantine(db, reason)
  local exp = db.current
  if exp == nil then return false end
  db.current = nil
  quarantine(db, exp, reason)
  return true
end

-- Met la sauvegarde au format courant. Accepte nil (première connexion).
-- Renvoie db (éventuellement une nouvelle table) et une note (nil si rien à signaler).
function Save.migrate(db)
  if type(db) ~= "table" then return Save.new(), "new" end
  local v = tonumber(db.version) or 0
  if v > Save.VERSION then
    -- Sauvegarde d'une version plus récente de l'addon : on n'y touche pas.
    return db, "newer"
  end
  local note
  while v < Save.VERSION do
    Save.MIGRATIONS[v](db)
    v = v + 1
    db.version = v
    note = "migrated"
  end
  Save.normalize(db)
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
        note = "expedition quarantined: " .. why
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
    if v ~= v or v == math.huge or v == -math.huge then return false, path .. " (invalid number)" end
    return true
  end
  if t == "string" or t == "boolean" or t == "nil" then return true end
  if t ~= "table" then return false, path .. " (" .. t .. ")" end
  seen = seen or {}
  if seen[v] then return false, path .. " (cycle or shared table)" end
  seen[v] = true
  if getmetatable(v) ~= nil then return false, path .. " (metatable)" end
  for k, x in pairs(v) do
    local kt = type(k)
    if kt ~= "string" and kt ~= "number" and kt ~= "boolean" then return false, path .. " (key " .. kt .. ")" end
    local ok, where = Save.isPlain(x, path .. "." .. tostring(k), seen)
    if not ok then return false, where end
  end
  return true
end

function Save.validateExpedition(exp)
  if type(exp) ~= "table" then return false, "no expedition" end
  if exp.version ~= ns.Expedition.VERSION then return false, "expedition version " .. tostring(exp.version) end
  if not ns.Expedition.PHASES[exp.phase] then return false, "phase " .. tostring(exp.phase) end
  if type(exp.deck) ~= "table" or type(exp.map) ~= "table" or type(exp.rng) ~= "table" then
    return false, "missing fields"
  end
  if type(exp.hp) ~= "number" or type(exp.gold) ~= "number" then return false, "HP or gold" end
  if not ns.Classes[exp.class] then return false, "class " .. tostring(exp.class) end
  for i = 1, #exp.deck do
    if not ns.Cards[exp.deck[i].id] then return false, "unknown card " .. tostring(exp.deck[i].id) end
  end
  if exp.phase == "combat" and type(exp.combat) ~= "table" then return false, "missing combat" end
  if exp.phase == "reward" and type(exp.reward) ~= "table" then return false, "missing reward" end
  if exp.phase == "merchant" and type(exp.shop) ~= "table" then return false, "missing merchant" end
  if exp.phase == "event" and type(exp.event) ~= "table" then return false, "missing encounter" end
  return Save.isPlain(exp, "current")
end

-- Vérifie toute la sauvegarde. Renvoie true ou false, liste d'erreurs.
function Save.validate(db)
  local errs = {}
  local function err(s) errs[#errs + 1] = s end
  if type(db) ~= "table" then return false, { "no save" } end
  if db.version ~= Save.VERSION then err("version " .. tostring(db.version)) end
  local m = db.meta
  if type(m) ~= "table" or type(m.classes) ~= "table" or type(m.league) ~= "number" then
    err("meta")
  else
    for class, cs in pairs(m.classes) do
      if type(cs) ~= "table" or type(cs.rep) ~= "number" or type(cs.keyMax) ~= "number" then err("meta." .. tostring(class)) end
    end
    if type(m.flags) ~= "table" then err("meta.flags") end
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
  if db.current then return nil, "running" end
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
  if not exp then return nil, "no expedition" end
  if exp.phase ~= "done" then return nil, "running" end
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
  if not exp then return nil, "no expedition" end
  if exp.phase ~= "done" then ns.Expedition.act(exp, { "abandon" }) end
  return Save.finish(db, date)
end

-- Copie profonde (pour une sauvegarde « instantané » si l'interface en veut une).
Save.copy = U.copy
