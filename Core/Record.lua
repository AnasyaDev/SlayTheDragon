-- Enregistrement rejouable des expéditions (docs/expedition.md, « Enregistrement des parties »).
-- Le moteur est déterministe (tout le hasard passe par ns.Rng à graine) : on n'enregistre pas des états, mais
-- les options de départ de Expedition.new et la liste ordonnée des actions passées à Expedition.act. Rejouer
-- ces actions depuis les mêmes options redonne la même partie ; des points de contrôle (fin de chaque combat,
-- fin de l'expédition) détectent une divergence (version différente des règles, état touché hors des actions).
--
-- db.records = { rec, … } (au plus Record.MAX, l'expédition en cours comprise, la plus ancienne retirée) :
--   rec = { fmt, addon (version de l'addon, fournie par l'interface), date (début, fournie par l'interface),
--           ev (Expedition.VERSION), live (true tant que c'est db.current), seed, class, key,
--           start = { options de Expedition.new : seed, class, zone, key, unlocks, flags },
--           a = { actions encodées }, cp = { points de contrôle }, result, ended (date de fin) }
-- Action encodée : chaîne « verbe arg arg » (nil = « _ »), préfixe « ! » si Expedition.act l'a refusée ; une
-- action qui ne s'écrit pas ainsi (chaîne avec espace…) est gardée telle quelle (copie de la table).
-- Note « @… » : marque hors action, rejouée avant l'action suivante (« @dev id id » : combat de test armé).
-- Point de contrôle : { n = actions jouées, hp, mhp, gold, deck, zone, floor }.
local _, ns = ...

local U = ns.Util
local floor = math.floor

local R = {}
ns.Record = R

R.FORMAT = 1
R.MAX = 20

---------------------------------------------------------------------------
-- Codage des actions
---------------------------------------------------------------------------

local function plainWord(s)
  if not s:match("^[%a][%w_%.:%-]*$") then return false end
  local l = s:lower()
  -- strtod lit « inf », « nan », « infinity » comme des nombres
  if l:sub(1, 3) == "inf" or l:sub(1, 3) == "nan" then return false end
  return true
end

-- Action (liste { verbe, arg… }, trous nil permis) -> chaîne, ou copie de la table si elle ne s'écrit pas.
function R.encode(a)
  local n = 0
  for i = 1, 8 do if a[i] ~= nil then n = i end end
  local parts = {}
  for i = 1, n do
    local v = a[i]
    local t = type(v)
    if v == nil then
      parts[i] = "_"
    elseif t == "number" then
      if v == floor(v) and v > -1e14 and v < 1e14 then
        parts[i] = tostring(v)
      else
        parts[i] = string.format("%.17g", v)
      end
    elseif t == "string" and plainWord(v) then
      parts[i] = v
    else
      return U.copy(a)
    end
  end
  return table.concat(parts, " ")
end

-- Entrée enregistrée -> action, acceptée (false : refusée à l'enregistrement), note (« @… ») ou nil.
function R.decode(s)
  if type(s) == "table" then return U.copy(s), true end
  if s:sub(1, 1) == "@" then return nil, true, s end
  local ok = true
  if s:sub(1, 1) == "!" then
    ok = false
    s = s:sub(2)
  end
  local a, i = {}, 0
  for tok in s:gmatch("%S+") do
    i = i + 1
    if tok ~= "_" then a[i] = tonumber(tok) or tok end
  end
  return a, ok
end

---------------------------------------------------------------------------
-- Pas commun à l'enregistrement et au rejeu
---------------------------------------------------------------------------

-- Empreinte de l'expédition (point de contrôle).
function R.mark(exp)
  return { hp = exp.hp, mhp = exp.maxHp, gold = exp.gold, deck = #exp.deck, zone = exp.zone, floor = exp.floor }
end

R.MARK_KEYS = { "hp", "mhp", "gold", "deck", "zone", "floor" }

-- Applique une action ; renvoie ok, raison, point de contrôle (combat conclu ou expédition finie) ou nil.
function R.step(exp, a)
  local c0 = exp.combat
  local ok, why = ns.Expedition.act(exp, a)
  local cp
  if (c0 ~= nil and exp.combat ~= c0) or (ok and exp.phase == "done") then cp = R.mark(exp) end
  return ok, why, cp
end

---------------------------------------------------------------------------
-- Enregistrement (Save.start, Save.act, Save.finish, Save.quarantine)
---------------------------------------------------------------------------

-- Enregistrement de l'expédition en cours (db.current), ou nil (expédition d'avant l'enregistrement…).
function R.live(db)
  local list = db and db.records
  local rec = type(list) == "table" and list[#list]
  local exp = db and db.current
  if type(rec) == "table" and rec.live and type(exp) == "table" and rec.seed == exp.seed
      and rec.class == exp.class and type(rec.a) == "table" then
    return rec
  end
  return nil
end

-- Ouvre l'enregistrement d'une expédition qui vient d'être créée avec les options xopts (copiées AVANT
-- Expedition.new). info = { date, addon } (interface ; absents hors jeu).
function R.begin(db, exp, xopts, info)
  if type(db.records) ~= "table" then db.records = {} end
  local list = db.records
  for i = 1, #list do if type(list[i]) == "table" then list[i].live = nil end end
  while #list >= R.MAX do table.remove(list, 1) end
  info = info or {}
  local start = {}
  for _, k in ipairs({ "seed", "class", "zone", "lastZone", "key", "unlocks", "flags", "epic" }) do
    if xopts[k] ~= nil then start[k] = U.copy(xopts[k]) end
  end
  local rec = { fmt = R.FORMAT, addon = info.addon, date = info.date, ev = ns.Expedition.VERSION, live = true,
    seed = exp.seed, class = exp.class, key = exp.key, start = start, a = {}, cp = {} }
  list[#list + 1] = rec
  return rec
end

-- Expedition.act sur db.current, enregistrée. Renvoie ok, raison.
function R.act(db, a)
  local exp = db.current
  if not exp then return false, "ended" end
  local rec = R.live(db)
  -- rien à rejouer : expédition finie, ou combat déjà tranché que n'importe quelle action conclut (état
  -- rechargé) ; le point de contrôle de la conclusion est gardé
  local skip = exp.phase == "done" or (exp.phase == "combat" and exp.combat ~= nil and exp.combat.result ~= nil)
  local ok, why, cp = R.step(exp, a)
  if rec then
    if not skip then rec.a[#rec.a + 1] = ok and R.encode(a) or ("!" .. R.encode(a)) end
    if cp then
      cp.n = #rec.a
      rec.cp[#rec.cp + 1] = cp
    end
    if exp.phase == "done" then rec.result = exp.result end
  end
  return ok, why
end

-- Note hors action (« @dev … ») rejouée avant l'action suivante.
function R.note(db, s)
  local rec = R.live(db)
  if rec then rec.a[#rec.a + 1] = "@" .. s end
end

-- Fin de l'expédition en cours (archivée, abandonnée ou mise en quarantaine).
function R.close(db, result, date)
  local rec = R.live(db)
  if not rec then return end
  rec.live = nil
  rec.result = rec.result or result
  rec.ended = date
end

-- Remet une liste d'enregistrements lue du fichier en forme (Save.normalize) : entrées illisibles retirées,
-- borne R.MAX, au plus une expédition « en cours » (la dernière, si db.current existe).
function R.normalize(db)
  if type(db.records) ~= "table" then db.records = {} end
  local out = {}
  for _, r in ipairs(db.records) do
    if type(r) == "table" and type(r.a) == "table" and type(r.start) == "table" then
      if type(r.cp) ~= "table" then r.cp = {} end
      out[#out + 1] = r
    end
  end
  while #out > R.MAX do table.remove(out, 1) end
  for i = 1, #out - 1 do out[i].live = nil end
  db.records = out
  if #out > 0 and out[#out].live and not R.live(db) then out[#out].live = nil end
end

---------------------------------------------------------------------------
-- Rejeu
---------------------------------------------------------------------------

-- Nouvelle expédition depuis les options de départ enregistrées (extra : quiet, stats).
function R.newExp(rec, extra)
  local o = U.copy(rec.start)
  extra = extra or {}
  o.quiet, o.stats = extra.quiet and true or false, extra.stats
  return ns.Expedition.new(o)
end

local function sameMark(a, b)
  for _, k in ipairs(R.MARK_KEYS) do
    if a[k] ~= b[k] then return false, k end
  end
  return true
end

-- Rejoue rec. opts : quiet, hooks = { start(exp), before(exp, a, i), after(exp, a, i, ok, why, cp),
-- note(exp, s, i) -> vrai si la note est prise en charge }, upto (dernière entrée rejouée).
-- Renvoie { exp, n (entrées rejouées), cps (points vérifiés), diverged = { i, why } ou nil,
-- versionMismatch (ev enregistrée ≠ Expedition.VERSION) }.
function R.replay(rec, opts)
  opts = opts or {}
  local hooks = opts.hooks or {}
  local out = { cps = 0, n = 0 }
  if rec.ev ~= ns.Expedition.VERSION then out.versionMismatch = true end
  local exp = R.newExp(rec, opts)
  out.exp = exp
  if hooks.start then hooks.start(exp) end
  local cpi = 1
  local last = math.min(#rec.a, opts.upto or #rec.a)
  for i = 1, last do
    local a, expect, note = R.decode(rec.a[i])
    if note then
      if not (hooks.note and hooks.note(exp, note, i)) then
        out.diverged = { i = i, why = "unreplayable note " .. note }
        return out
      end
    else
      if hooks.before then hooks.before(exp, a, i) end
      local ok, why, cp = R.step(exp, a)
      if hooks.after then hooks.after(exp, a, i, ok, why, cp) end
      if (ok and true or false) ~= expect then
        out.n = i
        out.diverged = { i = i, why = ok and "action accepted, refused when recorded"
          or ("action refused (" .. tostring(why) .. "), accepted when recorded") }
        return out
      end
      local want = rec.cp[cpi]
      if cp then
        if not want or want.n ~= i then
          out.n = i
          out.diverged = { i = i, why = "unexpected checkpoint", got = cp, want = want }
          return out
        end
        local same, k = sameMark(cp, want)
        if not same then
          out.n = i
          out.diverged = { i = i, why = "checkpoint " .. k .. " differs", got = cp, want = want }
          return out
        end
        cpi = cpi + 1
        out.cps = out.cps + 1
      elseif want and want.n == i then
        out.n = i
        out.diverged = { i = i, why = "checkpoint not reached", want = want }
        return out
      end
    end
    out.n = i
  end
  if last == #rec.a and rec.cp[cpi] then
    out.diverged = { i = last, why = "checkpoint not reached", want = rec.cp[cpi] }
  end
  return out
end

-- Zone la plus loin atteinte d'après les points de contrôle (liste des enregistrements), sinon la zone de départ.
function R.reached(rec)
  local cp = rec.cp and rec.cp[#rec.cp]
  return cp and cp.zone or (rec.start and rec.start.zone) or ns.Zone.FIRST
end
