-- Carte ramifiée d'un acte : 7 étapes puis le boss, 2 à 3 nœuds par étape,
-- reliés sans croisement de traits (les chemins se séparent et se rejoignent).
-- La carte est faite de données simples : { act, floors, nodes = { [id] = nœud }, start = { ids } }
-- nœud = { id, floor, x (0..1, position horizontale), kind, next = { ids de l'étape suivante } }
local _, ns = ...

local Rng = ns.Rng

local Map = {}
ns.Map = Map

Map.FLOORS = 7 -- étapes avant le boss

-- Les groupes de combats et le nom viennent de la zone de l'expédition (Core/Zones.lua, docs/zones.md).

Map.KINDS = {
  combat = "Combat", elite = "Elite", campfire = "Campfire", merchant = "Goblin Merchant",
  event = "Encounter", chest = "Chest", boss = "Boss",
}

-- Poids des types de nœuds pour les étapes libres (2 à 6) ; l'étape 1 est un combat,
-- l'étape 7 un feu de camp (avant le boss).
Map.WEIGHTS = { combat = 40, elite = 18, campfire = 6, merchant = 14, event = 18, chest = 10 }
Map.MIN_FLOOR = { combat = 1, event = 2, elite = 3, merchant = 3, chest = 3, campfire = 4 }
Map.MAX_FLOOR = { campfire = 5 }
Map.KIND_ORDER = { "combat", "elite", "campfire", "merchant", "event", "chest" }

-- Composition de chaque chemin complet (7 étapes, boss non compté).
Map.PATH_RANGE = {
  combat = { 3, 4 }, elite = { 1, 2 }, campfire = { 1, 2 },
  merchant = { 0, 1 }, event = { 1, 2 }, chest = { 0, 1 },
}

-- Carte de secours, toujours valide, si le tirage échoue trop souvent.
Map.FALLBACK = { "combat", "event", "combat", "elite", "merchant", "combat", "campfire" }
Map.ATTEMPTS = 60

local function width(rng, f)
  if f == Map.FLOORS + 1 then return 1 end
  return Rng.int(rng, 2, 3)
end

-- Relie deux étapes ordonnées de gauche à droite par un escalier : aucun trait ne se
-- croise, chaque nœud a au moins un prédécesseur et un successeur.
local function connect(rng, nodes, a, b)
  local i, j = 1, 1
  local function link()
    local nx = nodes[a[i]].next
    nx[#nx + 1] = b[j]
  end
  link()
  while i < #a or j < #b do
    if i == #a then
      j = j + 1
    elseif j == #b then
      i = i + 1
    else
      local r = Rng.int(rng, 1, 3)
      if r == 1 then
        i = i + 1
      elseif r == 2 then
        j = j + 1
      else
        i, j = i + 1, j + 1
      end
    end
    link()
  end
end

local function buildShape(rng, act)
  local map = { act = act, floors = Map.FLOORS + 1, nodes = {}, start = {} }
  local byFloor = {}
  local id = 0
  for f = 1, Map.FLOORS + 1 do
    local n = width(rng, f)
    local row = {}
    for k = 1, n do
      id = id + 1
      map.nodes[id] = { id = id, floor = f, x = (k - 0.5) / n, kind = "combat", next = {} }
      row[k] = id
    end
    byFloor[f] = row
  end
  for f = 1, Map.FLOORS do connect(rng, map.nodes, byFloor[f], byFloor[f + 1]) end
  for k = 1, #byFloor[1] do map.start[k] = byFloor[1][k] end
  return map, byFloor
end

-- Appelle visit(liste de nœuds) pour chaque chemin complet (étape 1 → boss).
function Map.eachPath(map, visit)
  local path = {}
  local function dfs(id)
    local node = map.nodes[id]
    path[#path + 1] = node
    if #node.next == 0 then
      visit(path)
    else
      for i = 1, #node.next do dfs(node.next[i]) end
    end
    path[#path] = nil
  end
  for i = 1, #map.start do dfs(map.start[i]) end
end

-- Vérifie les règles de placement. Renvoie true ou false, raison.
function Map.validate(map)
  local err
  local merchants = 0
  for _, node in ipairs(map.nodes) do
    if node.kind == "merchant" then merchants = merchants + 1 end
    if node.floor < (Map.MIN_FLOOR[node.kind] or 1) then return false, node.kind .. " too early" end
  end
  if merchants == 0 then return false, "no merchant" end
  Map.eachPath(map, function(path)
    if err then return end
    local count = {}
    for i = 1, #path do
      local k = path[i].kind
      count[k] = (count[k] or 0) + 1
      if i > 1 and k == "elite" and path[i - 1].kind == "elite" then err = "consecutive elites" end
    end
    if path[#path].kind ~= "boss" or #path ~= Map.FLOORS + 1 then err = "path without boss" end
    if path[#path - 1].kind ~= "campfire" then err = "no campfire before the boss" end
    for k, r in pairs(Map.PATH_RANGE) do
      local n = count[k] or 0
      if n < r[1] or n > r[2] then err = ("path: %s × %d"):format(k, n) end
    end
  end)
  if err then return false, err end
  return true
end

---------------------------------------------------------------------------
-- Attribution des types : étape par étape, chaque nœud connaît les compositions
-- possibles des chemins qui l'atteignent et ne prend qu'un type qui laisse
-- chacun de ces chemins complétable.
---------------------------------------------------------------------------

local function vecKey(v)
  local parts = {}
  for i, k in ipairs(Map.KIND_ORDER) do parts[i] = v[k] or 0 end
  parts[#parts + 1] = v.lastElite and 1 or 0
  return table.concat(parts, ",")
end

-- Peut-on encore compléter ce chemin avec `slots` étapes libres ?
local function completable(v, slots)
  local need = 0
  for k, r in pairs(Map.PATH_RANGE) do
    local n = v[k] or 0
    if k == "campfire" then n = n + 1 end -- l'étape 7
    if n > r[2] then return false end
    if n < r[1] then need = need + r[1] - n end
  end
  return need <= slots
end

local function withKind(v, k)
  local n = {}
  for key, x in pairs(v) do n[key] = x end
  n[k] = (n[k] or 0) + 1
  n.lastElite = k == "elite"
  return n
end

local function assignKinds(rng, map, byFloor)
  local last = Map.FLOORS + 1
  local incoming = {} -- id -> { clé -> vecteur }
  for _, id in ipairs(byFloor[1]) do
    map.nodes[id].kind = "combat"
    incoming[id] = { [vecKey({})] = {} }
  end
  local parents = {}
  for _, node in ipairs(map.nodes) do
    for _, nx in ipairs(node.next) do
      parents[nx] = parents[nx] or {}
      table.insert(parents[nx], node.id)
    end
  end
  local outgoing = {}
  local hasMerchant = false
  local function propagate(node)
    local out = {}
    local ins = incoming[node.id] or {}
    local keys = {}
    for key in pairs(ins) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
      local v = withKind(ins[key], node.kind)
      out[vecKey(v)] = v
    end
    outgoing[node.id] = out
    for _, nx in ipairs(node.next) do
      incoming[nx] = incoming[nx] or {}
      for key, v in pairs(out) do incoming[nx][key] = v end
    end
  end
  for _, id in ipairs(byFloor[1]) do propagate(map.nodes[id]) end
  for f = 2, last do
    for _, id in ipairs(byFloor[f]) do
      local node = map.nodes[id]
      if f == last then
        node.kind = "boss"
      elseif f == Map.FLOORS then
        node.kind = "campfire"
      else
        local slots = Map.FLOORS - 1 - f -- étapes libres restantes après celle-ci
        -- Types déjà pris par les nœuds frères (mêmes parents) : on évite les doublons.
        local sibling = {}
        for _, p in ipairs(parents[id] or {}) do
          for _, s in ipairs(map.nodes[p].next) do
            if s < id then sibling[map.nodes[s].kind] = true end
          end
        end
        local cands = {}
        for _, k in ipairs(Map.KIND_ORDER) do
          if f >= (Map.MIN_FLOOR[k] or 1) and f <= (Map.MAX_FLOOR[k] or 99) then
            local ok = true
            for _, v in pairs(incoming[id]) do
              if (k == "elite" and v.lastElite) or not completable(withKind(v, k), slots) then
                ok = false
                break
              end
            end
            if ok then cands[#cands + 1] = k end
          end
        end
        if #cands == 0 then return false end
        node.kind = Rng.weighted(rng, cands, function(k)
          local w = Map.WEIGHTS[k]
          if sibling[k] and k ~= "combat" then w = w * 0.1 end
          -- Au moins un marchand par carte : on le pousse si aucun n'est encore placé.
          if k == "merchant" and not hasMerchant and f >= 4 then w = w * 8 end
          return w
        end)
        if node.kind == "merchant" then hasMerchant = true end
      end
      propagate(node)
    end
  end
  return true
end

-- Génère la carte de l'acte `act` depuis le flux `rng` (état d'un ns.Rng).
function Map.generate(rng, act)
  local map, byFloor
  for attempt = 0, Map.ATTEMPTS - 1 do
    -- Certaines formes se prêtent mal aux règles : on en change toutes les 10 tentatives.
    if attempt % 10 == 0 then map, byFloor = buildShape(rng, act) end
    if assignKinds(rng, map, byFloor) and Map.validate(map) then return map end
  end
  local last = Map.FLOORS + 1
  for _, node in ipairs(map.nodes) do
    node.kind = node.floor == last and "boss" or Map.FALLBACK[node.floor]
  end
  map.fallback = true
  return map
end

-- Liste des nœuds d'une étape, de gauche à droite.
function Map.floorNodes(map, f)
  local list = {}
  for i = 1, #map.nodes do
    if map.nodes[i].floor == f then list[#list + 1] = map.nodes[i] end
  end
  return list
end

-- Nœuds accessibles maintenant : départ de l'acte, ou successeurs du nœud courant.
function Map.nextNodes(map, nodeId)
  if not nodeId then return map.start end
  return map.nodes[nodeId].next
end
