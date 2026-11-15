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
-- ressource de combat générique) ; 4 : niveau de classe (meta.classes[id].xp, expédition version 4 :
-- unlock.level) ; 5 : campagne par zones (meta.zones, meta.classes[id].zones, Ligue retirée ; expédition
-- version 5 : exp.zone, unlock.common, unlock.won). Expéditions version 6 (cartes épiques) et 7 (l'épique se
-- gagne) sans changement de la méta : Save.VERSION reste 5, l'expédition en cours passe par EXP_MIGRATIONS[5]
-- puis [6]. 6 : une expédition traverse toute la campagne (clé par classe cs.keyMax / cs.bestKey, zone la plus
-- loin atteinte cs.farthest ; expédition version 8). 7 : paliers d'amélioration (une carte jusqu'à +3 ; up
-- d'une carte du journal : true devient 1 ; expédition version 9).
Save.VERSION = 7

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
  m.runs = tonumber(m.runs) or 0
  if type(m.zones) ~= "table" then m.zones = {} end
  for k, v in pairs(m.zones) do
    if v ~= true then m.zones[k] = v and true or nil end
  end
  if type(m.classes) ~= "table" then m.classes = {} end
  for _, cs in pairs(m.classes) do
    if type(cs) == "table" then
      cs.xp = tonumber(cs.xp) or 0
      cs.runs = tonumber(cs.runs) or 0
      cs.wins = tonumber(cs.wins) or 0
      -- clé et zone atteinte par classe (v6) ; avant la v6, cs.keyMax / cs.bestKey n'existaient plus (v5)
      -- ou étaient ceux de Westfall (v1 à v4, déplacés par la migration 4 -> 5)
      if (tonumber(db.version) or 0) >= 6 then
        cs.keyMax = tonumber(cs.keyMax) or 0
        cs.bestKey = tonumber(cs.bestKey) or -1
        cs.farthest = tonumber(cs.farthest) or 0
      end
      if type(cs.zones) ~= "table" then cs.zones = {} end
      for zone, zs in pairs(cs.zones) do
        if type(zs) ~= "table" then
          cs.zones[zone] = nil
        else
          zs.won = zs.won == true
          zs.keyMax = tonumber(zs.keyMax) or 0
          zs.bestKey = tonumber(zs.bestKey) or -1
        end
      end
    end
  end
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

-- 3 -> 4 : la réputation de classe (cs.rep, gardée) devient l'expérience de classe, au barème de
-- l'expérience de la version 4 sans le bonus de clé : xp = rep × 0,5 + victoires × 15 (même ordre de
-- grandeur que si les expéditions passées avaient déjà rapporté de l'expérience).
Save.MIGRATIONS[3] = function(db)
  Save.normalize(db)
  for _, cs in pairs(db.meta.classes) do
    if type(cs) == "table" and (cs.xp == nil or cs.xp == 0) and cs.rep then
      cs.xp = math.floor((tonumber(cs.rep) or 0) * 0.5 + (tonumber(cs.wins) or 0) * 15 + 0.5)
    end
  end
end

-- 4 -> 5 : campagne par zones. La seule zone jouable jusque-là était Westfall : une classe qui a au moins
-- une victoire l'a gagnée et y garde sa clé max et sa meilleure clé (cs.keyMax, cs.bestKey déplacés dans
-- cs.zones.westfall) ; le compte a gagné Westfall si une classe l'a gagnée. La réputation de la Ligue des
-- explorateurs (meta.league) est abandonnée.
Save.MIGRATIONS[4] = function(db)
  Save.normalize(db)
  local m = db.meta
  local first = ns.Zone.FIRST
  for _, cs in pairs(m.classes) do
    if type(cs) == "table" then
      local wins = tonumber(cs.wins) or 0
      local keyMax = tonumber(cs.keyMax) or 0
      local best = tonumber(cs.bestKey) or -1
      if wins > 0 or best >= 0 or keyMax > 0 then
        local zs = cs.zones[first] or {}
        zs.won = true
        zs.keyMax = math.max(tonumber(zs.keyMax) or 0, keyMax, 1)
        zs.bestKey = math.max(tonumber(zs.bestKey) or -1, best, 0)
        cs.zones[first] = zs
        m.zones[first] = true
      end
      cs.keyMax, cs.bestKey = nil, nil
    end
  end
  m.league = nil
end

-- 5 -> 6 : une expédition traverse toute la campagne (décision du joueur, 14/11/2026). Rien n'est retiré :
-- cs.zones[zone].won (épique de la zone) et .bestKey (bibelots de clé) restent tels quels. Clé par classe : la
-- plus haute clé ouverte dans une zone (cs.keyMax = max des zs.keyMax : toute clé jouable avant le reste) ;
-- meilleure clé d'une victoire complète = celle de Blackrock Mountain si la classe l'a gagnée. Zone la plus loin
-- atteinte (cs.farthest) : la plus avancée des zones gagnées par la classe ou jouées par elle (journal).
Save.MIGRATIONS[5] = function(db)
  Save.normalize(db)
  local m = db.meta
  local last = ns.Zone.ORDER[#ns.Zone.ORDER]
  local played = {}
  for _, e in ipairs(db.journal) do
    local o = type(e) == "table" and e.class and ns.Zone.order(e.zone)
    if o and o > (played[e.class] or 0) then played[e.class] = o end
  end
  for class, cs in pairs(m.classes) do
    if type(cs) == "table" then
      local keyMax, far = 0, played[class] or 0
      for zone, zs in pairs(cs.zones) do
        keyMax = math.max(keyMax, tonumber(zs.keyMax) or 0)
        local o = zs.won and ns.Zone.order(zone)
        if o and o > far then far = o end
      end
      cs.keyMax = math.max(tonumber(cs.keyMax) or 0, keyMax)
      local br = cs.zones[last]
      cs.bestKey = math.max(tonumber(cs.bestKey) or -1, br and br.won and tonumber(br.bestKey) or -1)
      cs.farthest = math.max(tonumber(cs.farthest) or 0, far)
    end
  end
end

-- Palier d'amélioration des cartes (décision du joueur du 15/11/2026, docs/ameliorations.md) : le champ up
-- d'une carte valait true ou false, il vaut false ou le palier 1..3. Toute table qui désigne une carte connue
-- ({ id, up } : deck, piles et Powers d'un combat en cours, épique du combat, marchand, journal) passe de
-- up = true à up = 1 ; exp.epicReplaced.oldUp aussi. Idempotent ; true reste lu comme le palier 1 partout
-- (Card.level), la migration ne fait que rendre la forme canonique.
function Save.normalizeUp(t, seen)
  if type(t) ~= "table" then return end
  seen = seen or {}
  if seen[t] then return end
  seen[t] = true
  if t.up == true and type(t.id) == "string" and ns.Cards[t.id] then t.up = 1 end
  if t.oldUp == true then t.oldUp = 1 end
  for _, v in pairs(t) do
    if type(v) == "table" then Save.normalizeUp(v, seen) end
  end
end

-- 6 -> 7 : paliers d'amélioration : decks du journal (Save.normalizeUp).
Save.MIGRATIONS[6] = function(db)
  Save.normalize(db)
  for _, e in ipairs(db.journal) do
    if type(e) == "table" then Save.normalizeUp(e.deck) end
  end
end

-- Migrations de l'état d'une expédition en cours : EXP_MIGRATIONS[v](exp, db) de v à v + 1.
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

-- Expédition 3 -> 4 : déblocages par niveau de classe. Elle reçoit le niveau qu'a sa classe après la
-- migration de la méta (la réputation de classe, unlock.rep, n'est plus lue).
Save.EXP_MIGRATIONS[3] = function(exp, db)
  if type(exp.unlock) ~= "table" then exp.unlock = {} end
  if exp.unlock.level == nil then
    exp.unlock.level = (db and type(db.meta) == "table") and ns.Meta.levelOf(db.meta, exp.class or "priest") or 1
  end
  exp.unlock.league = tonumber(exp.unlock.league) or 0
  exp.unlock.rep = nil
end

-- Expédition 4 -> 5 : campagne par zones. L'expédition en cours se joue dans Westfall (seule zone
-- jusque-là) ; ses déblocages communs et de zone sont ceux du compte après la migration de la méta (le
-- palier de Ligue figé, unlock.league, est abandonné ; ce qui a déjà été tiré reste dans l'état).
Save.EXP_MIGRATIONS[4] = function(exp, db)
  if exp.zone == nil then exp.zone = ns.Zone.FIRST end
  if type(exp.unlock) ~= "table" then exp.unlock = { level = 1 } end
  local meta = db and type(db.meta) == "table" and db.meta
  local u = meta and ns.Meta.unlocks(meta, exp.class or "priest") or { common = 0, won = {} }
  exp.unlock.common = u.common
  exp.unlock.won = u.won
  exp.unlock.league = nil
  exp.acts = 1
end

-- Expédition 5 -> 6 : cartes épiques. Le flux de hasard « epic » est créé à son premier usage ; exp.epicOffered
-- (offre de départ faite, champ de la v6) n'est plus lu depuis la v7 : rien à poser.
Save.EXP_MIGRATIONS[5] = function() end

-- Expédition 6 -> 7 : l'épique se gagne (chute par élite, marchand), plus d'offre au départ. Une expédition
-- arrêtée sur l'offre de départ (exp.startEpics) la perd : elle passe au bibelot de départ s'il reste à
-- choisir, sinon à la carte. exp.startEpicPicked et exp.epicOffered sont retirés ; une épique déjà prise reste
-- dans le deck.
Save.EXP_MIGRATIONS[6] = function(exp)
  exp.startEpics, exp.startEpicPicked, exp.epicOffered = nil, nil, nil
  if exp.phase == "start" and type(exp.startRelics) ~= "table" then exp.phase = "map" end
end

-- Expédition 7 -> 8 : une expédition traverse toute la campagne. Une expédition d'une seule zone en cours continue
-- dans sa zone, puis enchaîne normalement sur la suivante jusqu'à Blackrock Mountain (exp.startZone = sa zone,
-- exp.act = 1, exp.acts = zones restantes). Arrêtée sur la récompense de son boss : ce boss est déjà battu
-- (exp.beaten), il compte tout de suite (Save.settle, appelé par Save.migrate).
Save.EXP_MIGRATIONS[7] = function(exp)
  local zone = exp.zone or ns.Zone.FIRST
  local last = ns.Zone.ORDER[#ns.Zone.ORDER]
  exp.startZone = exp.startZone or zone
  exp.lastZone = exp.lastZone or last
  exp.act = tonumber(exp.act) or 1
  exp.acts = (ns.Zone.order(last) or 1) - (ns.Zone.order(exp.startZone) or 1) + 1
  if type(exp.beaten) ~= "table" then
    exp.beaten = {}
    if exp.phase == "reward" and type(exp.reward) == "table" and exp.reward.kind == "boss" then
      exp.beaten[1] = zone
    end
  end
end

-- Expédition 8 -> 9 : paliers d'amélioration. Toute carte améliorée (deck, combat en cours, marchand,
-- récompense) passe de up = true à up = 1 (Save.normalizeUp) ; stats.upTiers[1] = améliorations déjà faites.
Save.EXP_MIGRATIONS[8] = function(exp)
  Save.normalizeUp(exp)
  if type(exp.stats) == "table" and type(exp.stats.upTiers) ~= "table" then
    local n = tonumber(exp.stats.upgraded) or 0
    exp.stats.upTiers = n > 0 and { n } or {}
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
        Save.EXP_MIGRATIONS[ev](exp, db)
        ev = ev + 1
        exp.version = ev
      end
      local ok, why = Save.validateExpedition(exp)
      if not ok then
        db.current = nil
        quarantine(db, exp, why)
        note = "expedition quarantined: " .. why
      else
        Save.settle(db)
      end
    end
  end
  return db, note
end

-- Reporte dans la méta ce que l'expédition en cours a déjà acquis (Meta.bank : boss battus, zone atteinte).
-- L'interface l'appelle après chaque action ; idempotent. Renvoie les parts nouvellement reportées.
function Save.settle(db)
  local exp = db and db.current
  if type(exp) ~= "table" or type(db.meta) ~= "table" then return {} end
  return ns.Meta.bank(db.meta, exp)
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
  if not ns.Zones[exp.zone] or not ns.Zone.playable(exp.zone) then return false, "zone " .. tostring(exp.zone) end
  for i = 1, #exp.deck do
    if not ns.Cards[exp.deck[i].id] then return false, "unknown card " .. tostring(exp.deck[i].id) end
  end
  if exp.phase == "combat" and type(exp.combat) ~= "table" then return false, "missing combat" end
  if exp.phase == "reward" and type(exp.reward) ~= "table" then return false, "missing reward" end
  if exp.phase == "merchant" and type(exp.shop) ~= "table" then return false, "missing merchant" end
  if exp.phase == "event" and type(exp.event) ~= "table" then return false, "missing encounter" end
  if exp.phase == "start" and type(exp.startRelics) ~= "table" then
    return false, "missing start choice"
  end
  if exp.phase == "transit" and type(exp.transit) ~= "table" then return false, "missing zone change" end
  if type(exp.beaten) ~= "table" then return false, "missing bosses" end
  return Save.isPlain(exp, "current")
end

-- Vérifie toute la sauvegarde. Renvoie true ou false, liste d'erreurs.
function Save.validate(db)
  local errs = {}
  local function err(s) errs[#errs + 1] = s end
  if type(db) ~= "table" then return false, { "no save" } end
  if db.version ~= Save.VERSION then err("version " .. tostring(db.version)) end
  local m = db.meta
  if type(m) ~= "table" or type(m.classes) ~= "table" or type(m.zones) ~= "table" then
    err("meta")
  else
    for class, cs in pairs(m.classes) do
      if type(cs) ~= "table" or type(cs.xp) ~= "number" or type(cs.zones) ~= "table" then
        err("meta." .. tostring(class))
      else
        for zone, zs in pairs(cs.zones) do
          if not ns.Zones[zone] or type(zs) ~= "table" or type(zs.keyMax) ~= "number" then
            err("meta." .. tostring(class) .. ".zones." .. tostring(zone))
          end
        end
      end
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

-- Démarre une expédition à Westfall (opts : seed, class, key). Renvoie exp ou nil, raison.
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
  entry.xp = summary.xp
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
