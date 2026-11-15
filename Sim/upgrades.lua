-- Paliers d'amélioration des cartes (docs/ameliorations.md) : contrôle des fiches up / up2 / up3 et liste,
-- par classe, des cartes dont les paliers 2 et 3 restent à écrire.
-- Commande : lua5.1 Sim/upgrades.lua [class=rogue|neutral|all] [list=1]
--   sans list=1 : compte par classe (paliers écrits) puis erreurs ; list=1 : aussi les cartes sans palier 2 / 3.
--   Code de sortie 1 s'il y a une erreur.
-- Module (tests) : local Up = dofile(root .. "/Sim/upgrades.lua")  →  Up.check(ns, id), Up.checkAll(ns),
--   Up.missing(ns, class), Up.FORBIDDEN.
local Up = {}

-- Champs d'identité de la carte : jamais dans un palier (le palier change ce que fait la carte, pas ce qu'elle est).
Up.FORBIDDEN = {
  id = true, name = true, class = true, rarity = true, type = true, path = true, level = true, zone = true,
  tier = true, neutral = true, noReward = true, variant = true, fromZone = true, school = true,
  up = true, up2 = true, up3 = true, plus = true, isUp = true,
}

-- Erreurs de la fiche id (liste de chaînes, vide si tout va bien).
function Up.check(ns, id)
  local Card = ns.Card
  local errs = {}
  local function err(s) errs[#errs + 1] = id .. " : " .. s end
  local base = ns.Cards[id]
  if not base then err("carte inconnue") return errs end
  local keys = Card.UP_KEYS
  -- pas de trou : up3 sans up2, up2 sans up
  for i = 2, #keys do
    if base[keys[i]] ~= nil and base[keys[i - 1]] == nil then err(keys[i] .. " sans " .. keys[i - 1]) end
  end
  local prev = Card.defById(id, 0)
  for n = 1, Card.tiers(id) do
    local t = base[keys[n]]
    local label = keys[n]
    if type(t) ~= "table" then
      err(label .. " n'est pas une table")
    else
      for k in pairs(t) do
        if Up.FORBIDDEN[k] then err(label .. "." .. tostring(k) .. " : champ interdit dans un palier") end
      end
      if type(t.text) ~= "string" or t.text == "" then
        err(label .. " sans text (chaque palier redonne le texte complet de la carte)")
      end
      if t.effects ~= nil and type(t.effects) ~= "table" then err(label .. ".effects n'est pas une table") end
      local ok, d = pcall(Card.defById, id, n)
      if not ok then
        err(label .. " : " .. tostring(d))
      else
        if d.name ~= base.name .. Card.suffix(n) then err(label .. " : nom " .. tostring(d.name)) end
        -- un palier 2 ou 3 change quelque chose (texte, coût, effets, autre champ) par rapport au précédent
        local changed = false
        for k, v in pairs(t) do if prev[k] ~= v then changed = true end end
        if n >= 2 and not changed then err(label .. " : rien ne change par rapport au palier " .. (n - 1)) end
        if type(d.cost) == "number" and type(prev.cost) == "number" and d.cost > prev.cost then
          err(label .. " : coût " .. d.cost .. " au-dessus du palier " .. (n - 1) .. " (" .. prev.cost .. ")")
        end
        prev = d
      end
    end
  end
  return errs
end

-- Toutes les erreurs, toutes cartes confondues (triées).
function Up.checkAll(ns)
  local ids = {}
  for id in pairs(ns.Cards) do ids[#ids + 1] = id end
  table.sort(ids)
  local all = {}
  for _, id in ipairs(ids) do
    for _, e in ipairs(Up.check(ns, id)) do all[#all + 1] = e end
  end
  return all
end

-- Groupe d'une carte pour la liste : sa classe, « neutral » (cartes neutres), « other » (cartes de combat
-- posées par les zones, variantes…).
function Up.groupOf(d)
  if d.class then return d.class end
  if d.neutral then return "neutral" end
  return "other"
end

-- Cartes du groupe (classe, "neutral", "other") : écrites jusqu'au palier n (1..3), listes triées par palier
-- manquant. Les variantes d'épiques (variant = true) suivent leur épique : comptées à part.
-- Renvoie { total, tiers = { [1] = n, [2] = n, [3] = n }, no2 = { id… }, no3 = { id… } }.
function Up.missing(ns, group)
  local r = { total = 0, tiers = { 0, 0, 0 }, no2 = {}, no3 = {} }
  for id, d in pairs(ns.Cards) do
    if Up.groupOf(d) == group then
      r.total = r.total + 1
      local n = ns.Card.tiers(id)
      for i = 1, n do r.tiers[i] = r.tiers[i] + 1 end
      if n < 2 then r.no2[#r.no2 + 1] = id
      elseif n < 3 then r.no3[#r.no3 + 1] = id end
    end
  end
  table.sort(r.no2)
  table.sort(r.no3)
  return r
end

-- Commande
local script = arg and arg[0] and arg[0]:match("upgrades%.lua$")
if not script then return Up end

local root = arg[0]:match("^(.*)/Sim/[^/]*$") or "."
local opts = {}
for _, a in ipairs(arg) do
  local k, v = a:match("^([%w_]+)=(.*)$")
  if k then opts[k] = v end
end
local ns = dofile(root .. "/Sim/load.lua")(root)
local groups = {}
if opts.class and opts.class ~= "all" then
  groups[1] = opts.class
else
  local ids = {}
  for id in pairs(ns.Classes) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return (ns.Classes[a].order or 99) < (ns.Classes[b].order or 99) end)
  for _, id in ipairs(ids) do groups[#groups + 1] = id end
  groups[#groups + 1] = "neutral"
  groups[#groups + 1] = "other"
end
print("Paliers d'amélioration écrits (cartes avec +1 / +2 / +3 sur le total) :")
for _, g in ipairs(groups) do
  local r = Up.missing(ns, g)
  print(("  %-10s %3d cartes   +1 %3d   +2 %3d   +3 %3d"):format(g, r.total, r.tiers[1], r.tiers[2], r.tiers[3]))
  if opts.list == "1" then
    if #r.no2 > 0 then print("    sans palier 2 : " .. table.concat(r.no2, ", ")) end
    if #r.no3 > 0 then print("    palier 2 sans palier 3 : " .. table.concat(r.no3, ", ")) end
  end
end
local errs = Up.checkAll(ns)
if #errs == 0 then
  print("Fiches des paliers : aucune erreur.")
else
  print(("Fiches des paliers : %d erreur(s)"):format(#errs))
  for _, e in ipairs(errs) do print("  " .. e) end
  os.exit(1)
end
