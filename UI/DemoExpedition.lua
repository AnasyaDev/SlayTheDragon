-- Expédition de démonstration : la séquence linéaire de Sim/run.lua (acte 1),
-- réécrite pour l'interface, en attendant Core/Expedition.lua (piste B).
-- Lua 5.1 pur, sans API WoW : l'état est fait de données simples.
--
-- Contrat « fournisseur d'expédition » utilisé par UI/Controller.lua :
--   P.id                         identifiant enregistré dans la sauvegarde
--   P.new(seed, opts) -> run     nouvel état (opts.class)
--   P.choices(run) -> step       étape courante, décrite par une liste de choix génériques :
--     step.kind    "map" | "combat" | "reward" | "choice" | "deck" | "shop" | "end"
--     step.title, step.text
--     step.options { { id, label, text, card = {id, up}, price, disabled, reason, kind } }
--     step.combat  (kind "combat") { seed, hp, maxHp, deck, encounter, relics, elite, boss }
--     step.nodes   (kind "map") { { id, kind, label, x, y, links = {id...}, state } }
--       state : "done" | "current" | "available" | "locked"
--     step.won     (kind "end")
--   P.act(run, optionId, extra) -> ok, err
--     combat terminé : optionId = "combat:won" | "combat:lost", extra = { hp = n }
--   P.summary(run) -> entrée de journal { result, floor, deck, relics, hp, seed }
local _, ns = ...

local U, Rng, Rewards = ns.Util, ns.Rng, ns.Rewards
local floor, min, max = math.floor, math.min, math.max

local P = {}
ns.DemoExpedition = P
P.id = "demo"

P.SEQUENCE = { "easy", "easy", "normal", "campfire", "elite", "shop", "normal", "campfire", "boss" }
P.REST_FRACTION = 0.30
P.GOLD = { easy = 15, normal = 15, elite = 30, boss = 80 }
P.PRICE = { common = 50, uncommon = 75, rare = 150 }
P.REMOVE_PRICE = 75

local NODE_LABEL = {
  easy = "Combat", normal = "Combat", elite = "Élite", boss = "Boss",
  campfire = "Feu de camp", shop = "Marchand",
}
local NODE_KIND = {
  easy = "combat", normal = "combat", elite = "elite", boss = "boss",
  campfire = "campfire", shop = "shop",
}

function P.new(seed, opts)
  opts = opts or {}
  local classId = opts.class or "priest"
  local class = ns.Classes[classId]
  local run = {
    seed = seed, class = classId, hp = class.hp, maxHp = class.hp,
    deck = {}, relics = {}, gold = 0,
    floor = 0, sequence = U.copyArr(P.SEQUENCE),
    rng = { map = Rng.stream(seed, "map"), loot = Rng.stream(seed, "loot") },
    lastEnc = {}, phase = "map", node = nil, result = nil,
  }
  for i = 1, #class.deck do run.deck[#run.deck + 1] = { id = class.deck[i], up = false } end
  return run
end

local function cardOption(id, up, i, extra)
  local o = { id = "card:" .. i, card = { id = id, up = up or false } }
  if extra then for k, v in pairs(extra) do o[k] = v end end
  return o
end

local function mapStep(run)
  local nodes = {}
  local n = #run.sequence
  for i = 1, n do
    local kind = run.sequence[i]
    local state = "locked"
    if i <= run.floor then state = "done" elseif i == run.floor + 1 then state = "available" end
    nodes[i] = {
      id = "node:" .. i, kind = NODE_KIND[kind] or kind, label = NODE_LABEL[kind] or kind,
      x = (i - 0.5) / n, y = 0.5 + ((i % 2 == 0) and 0.12 or -0.12),
      links = i < n and { "node:" .. (i + 1) } or {}, state = state,
    }
  end
  return {
    kind = "map", title = "Marche de l'Ouest",
    text = "Étape " .. (run.floor + 1) .. " sur " .. n .. ". Choisis ta prochaine étape.",
    nodes = nodes,
    options = { { id = "node:" .. (run.floor + 1), label = "Continuer" } },
  }
end

local function upgradable(run)
  local list = {}
  for i = 1, #run.deck do
    local c = run.deck[i]
    if not c.up and ns.Cards[c.id] and ns.Cards[c.id].up then list[#list + 1] = i end
  end
  return list
end

function P.choices(run)
  local phase = run.phase
  if phase == "map" then return mapStep(run) end
  local node = run.node
  if phase == "combat" then
    local title = node.type == "boss" and "Boss" or node.type == "elite" and "Élite" or "Combat"
    return {
      kind = "combat", title = title, options = {},
      combat = {
        seed = node.seed, hp = run.hp, maxHp = run.maxHp, deck = run.deck,
        encounter = node.encounter, relics = run.relics,
        elite = node.type == "elite", boss = node.type == "boss",
      },
    }
  elseif phase == "reward" then
    local opts = {}
    for i = 1, #node.choices do opts[#opts + 1] = cardOption(node.choices[i], false, i) end
    opts[#opts + 1] = { id = "skip", label = "Passer" }
    return { kind = "reward", title = "Victoire !",
      text = "Tu gagnes " .. node.gold .. " po. Choisis une carte à ajouter à ton deck.", options = opts }
  elseif phase == "campfire" then
    local heal = floor(run.maxHp * P.REST_FRACTION)
    local canUp = #upgradable(run) > 0
    return { kind = "choice", title = "Feu de camp",
      text = "Les braises crépitent. Tu as " .. run.hp .. " PV sur " .. run.maxHp .. ".",
      options = {
        { id = "rest", label = "Se reposer", text = "Soigne " .. heal .. " PV (30 % des PV max)." },
        { id = "upgrade", label = "Méditer", text = "Améliore une carte de ton deck.",
          disabled = not canUp, reason = not canUp and "Aucune carte à améliorer." or nil },
      } }
  elseif phase == "upgrade" or phase == "remove" then
    local opts = {}
    local list
    if phase == "upgrade" then
      list = upgradable(run)
    else
      list = {}
      for i = 1, #run.deck do list[i] = i end
    end
    for k = 1, #list do
      local i = list[k]
      opts[#opts + 1] = cardOption(run.deck[i].id, run.deck[i].up, i,
        { preview = phase == "upgrade" or nil })
    end
    opts[#opts + 1] = { id = "back", label = "Retour" }
    return { kind = "deck",
      title = phase == "upgrade" and "Méditer : choisis une carte à améliorer" or "Retirer une carte du deck",
      options = opts }
  elseif phase == "shop" then
    local opts = {}
    for i = 1, #node.offers do
      local o = node.offers[i]
      local poor = run.gold < o.price
      opts[#opts + 1] = cardOption(o.id, false, i, {
        price = o.price, disabled = o.sold or poor,
        reason = o.sold and "Vendu." or (poor and "Pas assez d'or." or nil), sold = o.sold })
    end
    local rp = node.removePrice
    opts[#opts + 1] = { id = "remove", label = "Retirer une carte", price = rp,
      text = "Le gobelin te débarrasse d'une carte.",
      disabled = node.removed or run.gold < rp or #run.deck <= 1,
      reason = node.removed and "Déjà fait chez ce marchand." or (run.gold < rp and "Pas assez d'or." or nil) }
    opts[#opts + 1] = { id = "leave", label = "Partir" }
    return { kind = "shop", title = "Marchand gobelin", gold = run.gold,
      text = "« Que des affaires, l'ami ! » Tu as " .. run.gold .. " po.", options = opts }
  elseif phase == "end" then
    local won = run.result == "won"
    return { kind = "end", won = won,
      title = won and "Expédition réussie !" or "Expédition terminée",
      text = won and ("Edwin VanCleef est tombé. Tu termines avec " .. run.hp .. " PV et "
          .. #run.deck .. " cartes.")
        or ("Tu tombes à l'étape " .. run.floor .. " sur " .. #run.sequence .. "."),
      options = { { id = "new", label = "Nouvelle expédition" } } }
  end
  error("phase inconnue : " .. tostring(phase))
end

local function enterNode(run, i)
  local kind = run.sequence[i]
  if kind == "campfire" then
    run.node = { type = kind }
    run.phase = "campfire"
  elseif kind == "shop" then
    local ids = Rewards.cardChoices(run.rng.loot, run.class, 3)
    local offers = {}
    for k = 1, #ids do
      local r = ns.Cards[ids[k]].rarity
      offers[k] = { id = ids[k], price = P.PRICE[r] or 60, sold = false }
    end
    run.node = { type = kind, offers = offers, removePrice = P.REMOVE_PRICE, removed = false }
    run.phase = "shop"
  else
    local pool = ns.Encounters.act1[kind]
    local enc
    for _ = 1, 5 do
      enc = Rng.pick(run.rng.map, pool)
      if enc ~= run.lastEnc[kind] then break end
    end
    run.lastEnc[kind] = enc
    run.node = { type = kind, encounter = U.copyArr(enc), seed = run.seed * 100 + i }
    run.phase = "combat"
  end
end

local function nextFloor(run)
  run.node = nil
  if run.floor >= #run.sequence then
    run.phase = "end"
    run.result = "won"
  else
    run.phase = "map"
  end
end

function P.act(run, id, extra)
  local phase = run.phase
  if phase == "map" then
    local i = tonumber(id and id:match("^node:(%d+)$"))
    if i ~= run.floor + 1 then return false, "node" end
    run.floor = i
    enterNode(run, i)
    return true
  elseif phase == "combat" then
    local node = run.node
    if id == "combat:won" then
      run.hp = max(0, (extra and extra.hp) or run.hp)
      local gold = P.GOLD[node.type] or 15
      run.gold = run.gold + gold
      if node.type == "boss" then
        run.phase = "end"
        run.result = "won"
        run.node = nil
      else
        node.gold = gold
        node.choices = Rewards.cardChoices(run.rng.loot, run.class, 3)
        run.phase = "reward"
      end
      return true
    elseif id == "combat:lost" then
      run.hp = 0
      run.phase = "end"
      run.result = "lost"
      return true
    end
    return false, "combat"
  elseif phase == "reward" then
    if id == "skip" then nextFloor(run) return true end
    local i = tonumber(id and id:match("^card:(%d+)$"))
    local cid = i and run.node.choices[i]
    if not cid then return false, "card" end
    run.deck[#run.deck + 1] = { id = cid, up = false }
    nextFloor(run)
    return true
  elseif phase == "campfire" then
    if id == "rest" then
      run.hp = min(run.maxHp, run.hp + floor(run.maxHp * P.REST_FRACTION))
      nextFloor(run)
      return true
    elseif id == "upgrade" then
      if #upgradable(run) == 0 then return false, "upgrade" end
      run.phase = "upgrade"
      return true
    end
    return false, "choice"
  elseif phase == "upgrade" then
    if id == "back" then run.phase = "campfire" return true end
    local i = tonumber(id and id:match("^card:(%d+)$"))
    local c = i and run.deck[i]
    if not c or c.up then return false, "card" end
    c.up = true
    nextFloor(run)
    return true
  elseif phase == "shop" then
    local node = run.node
    if id == "leave" then nextFloor(run) return true end
    if id == "remove" then
      if node.removed or run.gold < node.removePrice or #run.deck <= 1 then return false, "remove" end
      run.phase = "remove"
      return true
    end
    local i = tonumber(id and id:match("^card:(%d+)$"))
    local o = i and node.offers[i]
    if not o or o.sold or run.gold < o.price then return false, "buy" end
    o.sold = true
    run.gold = run.gold - o.price
    run.deck[#run.deck + 1] = { id = o.id, up = false }
    return true
  elseif phase == "remove" then
    if id == "back" then run.phase = "shop" return true end
    local i = tonumber(id and id:match("^card:(%d+)$"))
    if not i or not run.deck[i] then return false, "card" end
    table.remove(run.deck, i)
    run.gold = run.gold - run.node.removePrice
    run.node.removed = true
    run.phase = "shop"
    return true
  end
  return false, "phase"
end

function P.summary(run)
  return { result = run.result or "abandon", floor = run.floor, steps = #run.sequence,
    deck = U.copy(run.deck), relics = U.copy(run.relics), hp = run.hp, seed = run.seed, class = run.class }
end

-- Vérifie qu'un état restauré est utilisable avec le contenu actuel (cartes renommées, etc.).
function P.validate(run)
  if type(run) ~= "table" or type(run.deck) ~= "table" or type(run.sequence) ~= "table" then
    return false, "structure"
  end
  for i = 1, #run.deck do
    if not ns.Cards[run.deck[i].id] then return false, "carte inconnue " .. tostring(run.deck[i].id) end
  end
  if not (run.rng and run.rng.map and run.rng.loot) then return false, "rng" end
  return true
end
