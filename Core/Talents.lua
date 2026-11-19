-- Arbres de talents : règles communes (docs/talents.md ; contrat pour écrire un arbre : docs/talents.md,
-- « Contrat du socle des talents »). Données : ns.Talents[classe] (Data/Talents/<classe>.lua, posé par
-- ns.Talent.define) ; nœuds génériques : ns.TalentCommon (Data/Talents/common.lua). API : ns.Talent (comme
-- ns.Zone pour ns.Zones). Pas d'API WoW ; les arbres sont immuables après le chargement.
--
-- Arbre : { rows = { 0, 5, 10, 16 } (points dépensés qui ouvrent chaque rangée), nodes = { nœud, … } (ordre
-- d'affichage, rangée par rangée), bot = { order = { id, … } (un id par point, 24 : ordre de dépense du bot
-- de simulation, tree=), spec = voie du nœud Specialization du bot } }.
-- Nœud : { id, row (1 à 4), ranks (1 à 3), name, icon, text = { texte du rang 1, …, du rang max } (anglais,
--   une phrase), hooks (crochets de combat), run (crochets d'expédition), const (constantes de classe),
--   bot = { won = f(c, src) -> PV équivalents d'un combat gagné dans cet état, value = f(c, src, W) -> unités
--   de Bots.W } } ; nœud à choix (Specialization) : choices = { { id, name, icon, text, hooks, run, const,
--   bot }, … } à la place de text / hooks / run / const / bot (une voie active, ranks = 1).
-- Entrée d'un talent appris (src des crochets ; données simples) : { id, rank, spec } (spec : voie choisie, nœud à
-- choix seulement). L'expédition en garde la liste dans l'ordre de l'arbre (exp.talents), le combat une copie
-- (c.talents) ; leurs crochets passent par Combat.modify / Combat.fire et Expedition.modify / Expedition.fire
-- juste après ceux des bibelots.
local _, ns = ...

ns.Talents = ns.Talents or {}
local Trees = ns.Talents
local Talent = {}
ns.Talent = Talent

Talent.ROWS = { 0, 5, 10, 16 }
Talent.POINTS = 24 -- points d'un arbre entier (niveau 25 : Meta.MAX_LEVEL − 1)

-- Enregistre l'arbre d'une classe (fichier Data/Talents/<classe>.lua) : index par id, voies du nœud à choix.
function Talent.define(class, tree)
  tree.class = class
  tree.rows = tree.rows or Talent.ROWS
  tree.byId = {}
  for i, n in ipairs(tree.nodes) do
    n.index = i
    tree.byId[n.id] = n
    if n.choices then
      n.byChoice = {}
      for _, ch in ipairs(n.choices) do n.byChoice[ch.id] = ch end
    end
  end
  Trees[class] = tree
  return tree
end

function Talent.tree(class) return Trees[class] end

function Talent.node(class, id)
  local t = Trees[class]
  return t and t.byId[id] or nil
end

-- Partie active d'un talent appris : le nœud, ou la voie choisie d'un nœud à choix (nil : voie inconnue).
function Talent.part(class, entry)
  local n = Talent.node(class, entry.id)
  if not n then return nil end
  if n.choices then return n.byChoice[entry.spec or ""] end
  return n
end

-- Crochets de combat d'un talent appris (nil sans) ; crochets d'expédition (run) ; constantes (const).
function Talent.hooks(class, entry)
  local p = Talent.part(class, entry)
  return p and p.hooks
end
function Talent.run(class, entry)
  local p = Talent.part(class, entry)
  return p and p.run
end

-- Points dépensés dans une table { [nœud] = rang }.
function Talent.spentIn(map)
  local n = 0
  for _, r in pairs(type(map) == "table" and map or {}) do
    if type(r) == "number" and r > 0 then n = n + r end
  end
  return n
end

-- Points à dépenser pour ouvrir la rangée row de la classe.
function Talent.rowNeed(class, row)
  local t = Trees[class]
  return (t and t.rows or Talent.ROWS)[row] or math.huge
end

-- Peut-on apprendre un rang de plus du nœud id ? talents = { [nœud] = rang } actuels, choice = voie (nœud à
-- choix), points = points gagnés par la classe, spec = voie actuelle. Un nœud à choix déjà appris change de voie
-- sans coût (une autre voie que l'actuelle). Renvoie true, ou nil et la raison : "unknown" (nœud ou classe sans
-- arbre), "choice" (voie absente ou inconnue, ou déjà la voie actuelle), "max" (rang maximal), "points" (aucun
-- point libre), "row" (rangée pas encore ouverte).
function Talent.canLearn(class, talents, id, choice, points, spec)
  local n = Talent.node(class, id)
  if not n then return nil, "unknown" end
  local cur = (talents or {})[id] or 0
  if n.choices then
    if not (choice and n.byChoice[choice]) then return nil, "choice" end
    if cur >= 1 then
      if choice == spec then return nil, "choice" end
      return true
    end
  end
  if cur >= n.ranks then return nil, "max" end
  local spent = Talent.spentIn(talents)
  if spent >= (points or 0) then return nil, "points" end
  if spent < Talent.rowNeed(class, n.row) then return nil, "row" end
  return true
end

-- Arbre construit en apprenant les ids de list dans l'ordre (un id par rang ; spec = voie du nœud à choix) :
-- renvoie { [nœud] = rang }, voie. Erreur si un pas est refusé (ordre de bot illégal, nœud inconnu).
function Talent.build(class, list, spec)
  local map, cur = {}, nil
  for i, id in ipairs(list or {}) do
    local n = Talent.node(class, id)
    local choice = n and n.choices and (spec or (Trees[class].bot or {}).spec) or nil
    local ok, why = Talent.canLearn(class, map, id, choice, #list, cur)
    if not ok then error(("talents %s: step %d (%s) refused: %s"):format(class, i, tostring(id), why)) end
    map[id] = (map[id] or 0) + 1
    if n.choices then cur = choice end
  end
  return map, cur
end

-- Points d'une part de l'arbre (0 à 100 %) : arrondi au point supérieur (20 % = 5, 60 % = 15, 80 % = 20).
function Talent.pointsOf(share)
  return math.min(Talent.POINTS, math.max(0, math.ceil(Talent.POINTS * (share or 0) / 100 - 1e-9)))
end

-- Arbre du bot de simulation à share % (tree=) : les premiers points de bot.order. Renvoie map, voie, points.
function Talent.fromShare(class, share, spec)
  local t = Trees[class]
  if not t then return {}, nil, 0 end
  local order = t.bot and t.bot.order or {}
  local n = math.min(Talent.pointsOf(share), #order)
  local list = {}
  for i = 1, n do list[i] = order[i] end
  local map, sp = Talent.build(class, list, spec)
  return map, sp, n
end

-- Liste des talents appris dans l'ordre de l'arbre (données simples, une table neuve) : { { id, rank, spec }, … }
-- ; nil si aucun. Rangs au-delà du maximum ramenés au maximum ; nœuds inconnus ignorés.
function Talent.entries(class, map, spec)
  local t = Trees[class]
  if not t or type(map) ~= "table" then return nil end
  local list
  for _, n in ipairs(t.nodes) do
    local r = map[n.id]
    if type(r) == "number" and r > 0 and (not n.choices or n.byChoice[spec or ""]) then
      list = list or {}
      list[#list + 1] = { id = n.id, rank = math.min(r, n.ranks), spec = n.choices and spec or nil }
    end
  end
  return list
end

-- Texte d'un nœud à un rang (1 à ranks ; nœud à choix : texte de la voie). nil hors bornes.
function Talent.rankText(class, id, rank, spec)
  local n = Talent.node(class, id)
  if not n or not rank or rank < 1 then return nil end
  if n.choices then
    local ch = n.byChoice[spec or ""]
    return ch and ch.text or nil
  end
  return n.text[rank]
end

-- Rang d'un talent dans une liste d'entrées (exp.talents, c.talents), 0 sans.
function Talent.rankIn(list, id)
  for _, e in ipairs(list or {}) do if e.id == id then return e.rank end end
  return 0
end

-- Vue de l'arbre d'une classe pour l'interface (données neuves, lecture seule) :
-- { class, points (gagnés), spent, left, spec, rows = { { row, need (points à dépenser pour l'ouvrir), open,
--   nodes = { { id, name, icon, ranks, rank (actuel), text (rang actuel, nil à 0), nextText (rang suivant, nil
--   au maximum), canLearn, why (raison du refus), choices = { { id, name, icon, text, active } } (nœud à
--   choix) } } } } }. running = vrai : une expédition est en cours (rien ne s'apprend : why = "running").
function Talent.view(meta, class, running)
  local t = Trees[class]
  local cs = meta.classes[class]
  local map = cs and type(cs.talents) == "table" and cs.talents or {}
  local spec = cs and cs.spec
  local points = ns.Meta.talentPoints(meta, class)
  local spent = Talent.spentIn(map)
  local v = { class = class, points = points, spent = spent, left = points - spent, spec = spec, rows = {} }
  if not t then return v end
  for r, need in ipairs(t.rows) do
    v.rows[r] = { row = r, need = need, open = spent >= need, nodes = {} }
  end
  for _, n in ipairs(t.nodes) do
    local rank = map[n.id] or 0
    local e = { id = n.id, name = n.name, icon = n.icon, ranks = n.ranks, rank = rank }
    if n.choices then
      e.choices = {}
      for _, ch in ipairs(n.choices) do
        e.choices[#e.choices + 1] = { id = ch.id, name = ch.name, icon = ch.icon, text = ch.text,
          active = rank > 0 and spec == ch.id }
      end
      e.text = rank > 0 and Talent.rankText(class, n.id, 1, spec) or nil
      local ok, why = Talent.canLearn(class, map, n.id, n.choices[1].id, points, spec)
      if rank > 0 then ok, why = true, nil end -- changer de voie : toujours possible hors expédition
      e.canLearn, e.why = ok == true, why
    else
      e.text = rank > 0 and n.text[rank] or nil
      e.nextText = rank < n.ranks and n.text[rank + 1] or nil
      local ok, why = Talent.canLearn(class, map, n.id, nil, points, spec)
      e.canLearn, e.why = ok == true, why
    end
    if running then e.canLearn, e.why = false, "running" end
    local row = v.rows[n.row]
    row.nodes[#row.nodes + 1] = e
  end
  return v
end

-- Vérifie la forme d'un arbre (tests) : renvoie la liste des erreurs (vide si l'arbre est bon ; messages en
-- anglais comme toute chaîne de l'addon chargé).
function Talent.check(class)
  local errs = {}
  local function err(s) errs[#errs + 1] = class .. ": " .. s end
  local t = Trees[class]
  if not t then err("no tree") return errs end
  if #t.rows ~= 4 then err("4 rows expected") end
  local total, specs, seen = 0, 0, {}
  for _, n in ipairs(t.nodes) do
    if seen[n.id] then err("duplicate id " .. n.id) end
    seen[n.id] = true
    if type(n.name) ~= "string" or n.name == "" then err(n.id .. ": name") end
    if not (n.row and t.rows[n.row]) then err(n.id .. ": row") end
    if not (n.ranks and n.ranks >= 1 and n.ranks <= 3) then err(n.id .. ": ranks 1 to 3") end
    total = total + (n.ranks or 0)
    if n.choices then
      specs = specs + 1
      if n.ranks ~= 1 then err(n.id .. ": a choice node has one rank") end
      for _, ch in ipairs(n.choices) do
        if type(ch.text) ~= "string" or ch.text == "" then err(n.id .. "/" .. tostring(ch.id) .. ": text") end
      end
    else
      for r = 1, n.ranks or 0 do
        if type(n.text) ~= "table" or type(n.text[r]) ~= "string" or n.text[r] == "" then
          err(n.id .. ": text of rank " .. r)
        end
      end
    end
  end
  if total ~= Talent.POINTS then err(("%d points instead of %d"):format(total, Talent.POINTS)) end
  if specs ~= 1 then err(specs .. " choice nodes instead of 1") end
  local order = t.bot and t.bot.order
  if type(order) ~= "table" or #order ~= Talent.POINTS then
    err("bot.order: one id per point (" .. Talent.POINTS .. ")")
  else
    local ok, e = pcall(Talent.build, class, order, t.bot.spec)
    if not ok then err("bot.order not legal: " .. tostring(e)) end
  end
  return errs
end

-- Constante de classe changée par les talents du combat (docs/talents.md, « Contrat ») : v = valeur du module
-- (ns.Druid.TAX_FREE…, lue à chaque appel : tune= de la simulation reste valable), puis chaque talent appris qui
-- déclare const[name] = f(v, src) -> nouvelle valeur, dans l'ordre de l'arbre. Sans talent : v tel quel.
-- Appelée par Combat.const (le code de classe lit Combat.const(c, "TAX_FREE", Druid.TAX_FREE)).
function Talent.const(class, list, name, v)
  for i = 1, #list do
    local p = Talent.part(class, list[i])
    local f = p and p.const and p.const[name]
    if f then v = f(v, list[i]) end
  end
  return v
end
