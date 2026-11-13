-- Méta-progression du compte : niveau de classe (expérience), campagne par zones (zones gagnées par
-- classe et par le compte), clés mythiques par zone et par classe, affixes. Données simples :
-- meta = { runs = n, zones = { [zone] = true } (zones gagnées par le compte, toutes classes),
--          classes = { [classe] = { xp, runs, wins,
--                                   zones = { [zone] = { won, keyMax, bestKey } } } },
--          flags = { [nom] = true } }
-- (cs.rep : ancienne réputation de classe des sauvegardes 1 à 3, gardée telle quelle, plus lue.)
-- Contrat des zones : docs/zones.md ; détails : docs/expedition.md.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min

local Meta = {}
ns.Meta = Meta

---------------------------------------------------------------------------
-- Niveau de classe (1 à 7) : expérience propre à chaque classe
---------------------------------------------------------------------------
-- Seuils cumulés : XP_LEVELS[n] = expérience pour atteindre le niveau n.
Meta.XP_LEVELS = { 0, 100, 250, 450, 700, 1000, 1400 }
Meta.MAX_LEVEL = #Meta.XP_LEVELS

-- Expérience d'une expédition terminée (gagnée, perdue ou abandonnée), tirée de son avancée :
-- step par étape franchie (boss compris), elite par élite, boss par boss, win si elle est gagnée, le tout
-- × (1 + key × clé), arrondi. Mêmes gains qu'avec l'ancienne réputation de Ligue (la moitié de 10 / 12 / 30
-- par étape / élite / boss, + 15) : ≈ 76 pour une victoire à la clé 0, ≈ 40 pour une défaite au boss ;
-- niveau 2 vers la 2e expédition, niveau 7 vers la 20e (docs/expedition.md). Clé : +15 % par niveau.
Meta.XP = { step = 5, elite = 6, boss = 15, win = 15, key = 0.15 }

function Meta.classLevel(xp)
  local lv = 1
  for i = 2, Meta.MAX_LEVEL do
    if (xp or 0) >= Meta.XP_LEVELS[i] then lv = i end
  end
  return lv
end

-- Progression dans le niveau : niveau, expérience dans le niveau, taille du niveau (nil au maximum).
function Meta.xpProgress(xp)
  xp = xp or 0
  local lv = Meta.classLevel(xp)
  local cur = Meta.XP_LEVELS[lv]
  local nxt = Meta.XP_LEVELS[lv + 1]
  if not nxt then return lv, xp - cur, nil end
  return lv, xp - cur, nxt - cur
end

-- Niveau d'une classe sur ce compte.
function Meta.levelOf(meta, class)
  local cs = meta.classes[class]
  return Meta.classLevel(cs and cs.xp or 0)
end

-- Niveau qui débloque une carte ou un bibelot de classe (absent = 1).
function Meta.unlockLevel(def)
  return (def and def.level) or 1
end

-- Contenu d'une classe : { cards = { ids }, relics = { ids } } (cartes de départ comprises), triés par
-- niveau, rareté, coût puis nom ; level = n : seulement ce qui se débloque au niveau n.
local RARITY_ORDER = { basic = 0, common = 1, uncommon = 2, rare = 3, epic = 4, boss = 5 }
Meta.RARITY_ORDER = RARITY_ORDER
local function contentSort(reg)
  return function(a, b)
    local da, db = reg[a], reg[b]
    local la, lb = Meta.unlockLevel(da), Meta.unlockLevel(db)
    if la ~= lb then return la < lb end
    local ra, rb = RARITY_ORDER[da.rarity] or 9, RARITY_ORDER[db.rarity] or 9
    if ra ~= rb then return ra < rb end
    if (da.cost or 0) ~= (db.cost or 0) then return (da.cost or 0) < (db.cost or 0) end
    if da.name ~= db.name then return tostring(da.name) < tostring(db.name) end
    return a < b
  end
end

-- Cartes de zone (champ zone) et bibelots de clé (champ key) : hors de la grille des niveaux.
function Meta.classContent(class, level)
  local cards, relics = {}, {}
  for id, d in pairs(ns.Cards) do
    if d.class == class and not d.zone and not d.variant and (not level or Meta.unlockLevel(d) == level) then
      cards[#cards + 1] = id
    end
  end
  for id, r in pairs(ns.Relics) do
    if r.class == class and not r.key and (not level or Meta.unlockLevel(r) == level) then relics[#relics + 1] = id end
  end
  table.sort(cards, contentSort(ns.Cards))
  table.sort(relics, contentSort(ns.Relics))
  return { cards = cards, relics = relics }
end

---------------------------------------------------------------------------
-- Affixes mythiques (cumulatifs : la clé +N active les affixes 1..N)
---------------------------------------------------------------------------
-- hooks : crochets de combat (même forme que ceux des bibelots, src = id de l'affixe).
-- run   : crochets d'expédition (même forme que relic.run).
ns.Affixes = ns.Affixes or {}
local A = ns.Affixes
Meta.MAX_KEY = 5
Meta.AFFIX_ORDER = { "fortified", "tyrannical", "bolstering", "necrotic", "famine" }

-- Intensité des affixes, réglée par la simulation (bot heuristique, acte 1, 2 000 à
-- 3 000 expéditions) pour perdre environ 5 points de victoire par niveau. Le boss est le
-- seul vrai verrou de l'acte 1 : +20 % sur VanCleef coûtait 57 points, d'où un bonus de
-- boss plus faible et des boss exclus de Galvanisant (comme en jeu). À re-mesurer quand
-- l'équilibrage des combats change (Sim/sim.lua runner=expedition key=N, docs/expedition.md).
Meta.AFFIX = {
  fortified = { hp = 0.12 },                      -- ennemis normaux : PV
  tyrannical = { eliteHp = 0.05, eliteDamage = 0.05, bossHp = 0.03, bossDamage = 0 },
  bolstering = { force = 1 },                      -- Force donnée aux survivants (hors boss)
  necrotic = { step = 0.05, cap = 6 },             -- soins −5 % par coup reçu, −30 % au plus
  famine = { rest = 0.20 },                        -- fraction soignée au feu de camp
}
local P = Meta.AFFIX

local function scale(v, f) return floor(v * (1 + f) + 0.5) end
local function pct(f) return floor(f * 100 + 0.5) end

A.fortified = {
  name = "Fortified", level = 1,
  text = ("Normal enemies: +%d%% HP."):format(pct(P.fortified.hp)),
  hooks = {
    enemyHp = function(c, src, v, def)
      if def.elite or def.boss then return v end
      return scale(v, P.fortified.hp)
    end,
  },
}

A.tyrannical = {
  name = "Tyrannical", level = 2,
  text = ("Elites: +%d%% HP and damage. Bosses: +%d%% HP%s.")
    :format(pct(P.tyrannical.eliteHp), pct(P.tyrannical.bossHp),
      P.tyrannical.bossDamage > 0 and (" and +%d%% damage"):format(pct(P.tyrannical.bossDamage)) or ""),
  hooks = {
    enemyHp = function(c, src, v, def)
      if def.boss then return scale(v, P.tyrannical.bossHp) end
      if def.elite then return scale(v, P.tyrannical.eliteHp) end
      return v
    end,
    enemyDamage = function(c, src, v, enemy)
      local def = ns.Enemies[enemy.id]
      if def.boss then return scale(v, P.tyrannical.bossDamage) end
      if def.elite then return scale(v, P.tyrannical.eliteDamage) end
      return v
    end,
  },
}

A.bolstering = {
  name = "Bolstering", level = 3,
  text = ("When an enemy dies, the others gain %d Strength (except bosses)."):format(P.bolstering.force),
  hooks = {
    onEnemyDeath = function(c, src, dead)
      for i = 1, #c.enemies do
        local o = c.enemies[i]
        if o ~= dead and not o.dead and not o.boss then
          ns.Combat.applyStatus(c, o, "force", P.bolstering.force)
        end
      end
    end,
  },
}

ns.Statuses.necrotic = { name = "Necrotic", affix = true,
  text = ("Healing received reduced by %d%% per stack (max %d), until the end of combat.")
    :format(pct(P.necrotic.step), P.necrotic.cap) }

A.necrotic = {
  name = "Necrotic", level = 4,
  text = ("Each hit taken reduces healing by %d%% (up to %d%%) until the end of combat.")
    :format(pct(P.necrotic.step), pct(P.necrotic.step * P.necrotic.cap)),
  hooks = {
    onPlayerHit = function(c, src, enemy, loss)
      if (c.player.st.necrotic or 0) < P.necrotic.cap then ns.Combat.applyStatus(c, c.player, "necrotic", 1) end
    end,
    heal = function(c, src, v)
      local n = c.player.st.necrotic or 0
      if n <= 0 then return v end
      return floor(v * max(0, 1 - P.necrotic.step * n) + 0.5)
    end,
  },
}

A.famine = {
  name = "Famine", level = 5,
  text = ("Campfires only heal %d%% of HP."):format(pct(P.famine.rest)),
  run = {
    restFraction = function(exp, v) return min(v, P.famine.rest) end,
  },
}

function Meta.affixesFor(key)
  local list = {}
  for i = 1, min(key or 0, #Meta.AFFIX_ORDER) do list[i] = Meta.AFFIX_ORDER[i] end
  return list
end

---------------------------------------------------------------------------
-- État du compte
---------------------------------------------------------------------------

-- flags : drapeaux de compte { nom = true } posés par les rencontres (rencontres à histoire
-- vues une fois, suites débloquées). Reportés en fin d'expédition (Meta.record), jamais retirés.
-- zones : zones gagnées par le compte (toutes classes) : elles débloquent le commun (Meta.commonTier).
function Meta.new()
  return { runs = 0, zones = {}, classes = {}, flags = {} }
end

function Meta.hasFlag(meta, name)
  return type(meta.flags) == "table" and meta.flags[name] == true
end

function Meta.classState(meta, class)
  local cs = meta.classes[class]
  if not cs then
    cs = { xp = 0, runs = 0, wins = 0, zones = {} }
    meta.classes[class] = cs
  end
  if type(cs.zones) ~= "table" then cs.zones = {} end
  return cs
end

-- État d'une classe dans une zone (créé au besoin) : { won, keyMax (clé la plus haute ouverte),
-- bestKey (meilleure clé gagnée, -1 = jamais gagnée) }.
function Meta.zoneState(meta, class, zone)
  local cs = Meta.classState(meta, class)
  local zs = cs.zones[zone]
  if type(zs) ~= "table" then
    zs = { won = false, keyMax = 0, bestKey = -1 }
    cs.zones[zone] = zs
  end
  return zs
end

-- Lecture sans création (nil si la classe n'a jamais gagné ni ouvert de clé dans la zone).
function Meta.zoneInfo(meta, class, zone)
  local cs = meta.classes[class]
  local zs = cs and type(cs.zones) == "table" and cs.zones[zone]
  return type(zs) == "table" and zs or nil
end

-- La classe a-t-elle gagné la zone ?
function Meta.classWon(meta, class, zone)
  local zs = Meta.zoneInfo(meta, class, zone)
  return zs ~= nil and zs.won == true
end

-- Zone ouverte pour une classe : la première toujours, les suivantes quand la classe a gagné la
-- précédente (gagner une zone avec une classe n'ouvre la suivante que pour elle).
function Meta.zoneOpen(meta, class, zone)
  if not ns.Zones[zone] then return false end
  local prev = ns.Zone.prev(zone)
  return prev == nil or Meta.classWon(meta, class, prev)
end

-- Le compte a-t-il gagné la zone (avec n'importe quelle classe) ?
function Meta.accountWon(meta, zone)
  return type(meta.zones) == "table" and meta.zones[zone] == true
end

-- Palier commun du compte : ordre de la zone la plus avancée gagnée par le compte (0 = aucune). Le
-- commun (cartes neutres, bibelots communs, potions, rencontres) de champ tier <= ce palier est débloqué :
-- tier N = première victoire du compte dans la zone d'ordre N (docs/zones.md, table de répartition).
function Meta.commonTier(meta)
  local t = 0
  for zone, won in pairs(type(meta.zones) == "table" and meta.zones or {}) do
    local n = won == true and ns.Zone.order(zone)
    if n and n > t then t = n end
  end
  return t
end

-- Avantages communs rattachés aux zones (ordre de la zone dont la première victoire du compte les
-- donne) : un bibelot au choix parmi 3 au départ (ex-Révéré de la Ligue) ; un bibelot de plus chez le
-- marchand (ex-Exalté).
Meta.PERKS = { startRelic = 3, merchantRelic = 6 }
Meta.PERK_ORDER = { "startRelic", "merchantRelic" }

-- Clés ouvertes pour une classe dans une zone : 0..keyMax.
function Meta.keyMax(meta, class, zone)
  local zs = Meta.zoneInfo(meta, class, zone or ns.Zone.FIRST)
  return zs and zs.keyMax or 0
end

-- Meilleure clé gagnée par une classe dans une zone (-1 : jamais gagnée).
function Meta.bestKey(meta, class, zone)
  local zs = Meta.zoneInfo(meta, class, zone or ns.Zone.FIRST)
  return zs and zs.bestKey or -1
end

-- Déblocages d'une classe : { level = niveau de classe 1..7, common = palier commun 0..7,
--   won = { [zone] = meilleure clé gagnée } (zones gagnées par la classe : cartes de zone, bibelots de clé) }.
function Meta.unlocks(meta, class)
  local won = {}
  local cs = meta.classes[class]
  for zone, zs in pairs(cs and type(cs.zones) == "table" and cs.zones or {}) do
    if type(zs) == "table" and zs.won then won[zone] = zs.bestKey or 0 end
  end
  return { level = Meta.levelOf(meta, class), common = Meta.commonTier(meta), won = won }
end

-- Déblocages de simulation : le compte et la classe ont gagné les `zones` premières zones (défaut :
-- toutes), à toutes les clés ; level = niveau de classe (défaut 7).
function Meta.allUnlocked(level, zones)
  zones = zones or ns.Zone.count()
  local won = {}
  for i = 1, zones do won[ns.Zone.ORDER[i]] = Meta.MAX_KEY end
  return { level = level or Meta.MAX_LEVEL, common = zones, won = won }
end

-- Classe au niveau maximal (liseré doré, titre).
function Meta.isMaxLevel(meta, class)
  return Meta.levelOf(meta, class) >= Meta.MAX_LEVEL
end

-- Titre cosmétique du niveau 7.
function Meta.title(meta, class)
  if Meta.isMaxLevel(meta, class) then return "Dragonslayer" end
  return nil
end

---------------------------------------------------------------------------
-- Contenu lié aux zones
---------------------------------------------------------------------------

local function byName(reg)
  return function(a, b)
    local na, nb = tostring(reg[a].name), tostring(reg[b].name)
    if na ~= nb then return na < nb end
    return a < b
  end
end

-- Cartes de zone d'une classe (champ zone) : débloquées par la première victoire de la classe dans la zone.
function Meta.zoneCards(class, zone)
  local list = {}
  for id, d in pairs(ns.Cards) do
    if d.class == class and d.zone == zone and not d.variant then list[#list + 1] = id end
  end
  table.sort(list, byName(ns.Cards))
  return list
end

-- Niveaux de clé qui débloquent un bibelot (première victoire de la classe à ce niveau dans la zone).
Meta.KEY_RELIC_LEVELS = { 1, 3, 5 }

-- Bibelots de clé d'une zone pour une classe (champ key = { zone, level } ; class facultatif) :
-- { { level, id } } triés par niveau.
function Meta.keyRelics(class, zone)
  local list = {}
  for id, r in pairs(ns.Relics) do
    local k = r.key
    if type(k) == "table" and k.zone == zone and (not r.class or r.class == class) then
      list[#list + 1] = { level = k.level or 1, id = id }
    end
  end
  table.sort(list, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    return a.id < b.id
  end)
  return list
end

-- Commun débloqué par la première victoire du compte dans la zone d'ordre `tier` :
-- { cards (neutres), relics (communs), potions, events, perks (ids de Meta.PERKS) }, triés par nom.
function Meta.commonContent(tier)
  local out = { cards = {}, relics = {}, potions = {}, events = {}, perks = {} }
  for id, d in pairs(ns.Cards) do
    if d.class == nil and d.neutral and d.rarity ~= "basic" and (d.tier or 0) == tier then out.cards[#out.cards + 1] = id end
  end
  for id, r in pairs(ns.Relics) do
    if not r.class and not r.key and not r.noPool and (r.tier or 0) == tier then out.relics[#out.relics + 1] = id end
  end
  for id, p in pairs(ns.Potions) do
    if not p.noPool and (p.tier or 0) == tier then out.potions[#out.potions + 1] = id end
  end
  for id, ev in pairs(ns.Events or {}) do
    if (ev.tier or 0) == tier then out.events[#out.events + 1] = id end
  end
  table.sort(out.cards, byName(ns.Cards))
  table.sort(out.relics, byName(ns.Relics))
  table.sort(out.potions, byName(ns.Potions))
  table.sort(out.events, byName(ns.Events or {}))
  for _, k in ipairs(Meta.PERK_ORDER) do
    if Meta.PERKS[k] == tier then out.perks[#out.perks + 1] = k end
  end
  return out
end

---------------------------------------------------------------------------
-- Fin d'expédition
---------------------------------------------------------------------------

-- Expérience de classe gagnée par une expédition terminée (Meta.XP).
function Meta.xpFor(exp)
  local P, s = Meta.XP, exp.stats
  local v = s.cleared * P.step + s.elites * P.elite + s.bosses * P.boss + (exp.result == "won" and P.win or 0)
  return floor(v * (1 + P.key * (exp.key or 0)) + 0.5)
end

-- Crée une expédition pour ce compte (zone ouverte et jouable, clé ouverte dans cette zone).
-- opts : seed, class, zone (défaut : la première), key ; renvoie exp ou nil, raison.
function Meta.newExpedition(meta, opts)
  local class = opts.class or "priest"
  local zone = opts.zone or ns.Zone.FIRST
  local key = opts.key or 0
  if not ns.Zones[zone] then return nil, "zone" end
  if not ns.Zone.playable(zone) then return nil, "zone coming later" end
  if not Meta.zoneOpen(meta, class, zone) then return nil, "zone locked" end
  if key < 0 or key > Meta.keyMax(meta, class, zone) then return nil, "key locked" end
  return ns.Expedition.new({ seed = opts.seed, class = class, zone = zone, key = key,
    unlocks = Meta.unlocks(meta, class), flags = meta.flags, stats = opts.stats, quiet = opts.quiet })
end

-- Applique le résultat d'une expédition terminée au compte. Renvoie un résumé :
-- { xp (classe), levelBefore, levelAfter, unlocked = { cards = {ids}, relics = {ids} } (ce que la montée de
--   niveau vient de débloquer), zone,
--   zoneWon (première victoire de la classe dans la zone), zoneOpened (zone suivante, ouverte pour la classe),
--   zoneCards = {ids} (cartes de zone débloquées), keyRelics = {ids} (bibelots de clé débloqués),
--   keyUnlocked (niveau de clé ouvert dans la zone, ou nil),
--   accountZone (première victoire du compte dans la zone), common = Meta.commonContent(ordre) (commun
--   débloqué pour toutes les classes, avantages compris), flags (drapeaux de compte nouvellement posés, triés) }
function Meta.record(meta, exp)
  local cs = Meta.classState(meta, exp.class)
  if type(meta.zones) ~= "table" then meta.zones = {} end
  local zone = exp.zone or ns.Zone.FIRST
  local xp = Meta.xpFor(exp)
  local before = Meta.classLevel(cs.xp)
  local summary = { xp = xp, levelBefore = before, zone = zone, zoneCards = {}, keyRelics = {} }
  cs.xp = (cs.xp or 0) + xp
  cs.runs = (cs.runs or 0) + 1
  meta.runs = (meta.runs or 0) + 1
  if exp.result == "won" then
    cs.wins = (cs.wins or 0) + 1
    local zs = Meta.zoneState(meta, exp.class, zone)
    local key = exp.key or 0
    local oldBest = zs.bestKey or -1
    if not zs.won then
      zs.won = true
      summary.zoneWon = true
      summary.zoneCards = Meta.zoneCards(exp.class, zone)
      summary.zoneOpened = ns.Zone.next(zone)
    end
    if key > oldBest then zs.bestKey = key end
    for _, e in ipairs(Meta.keyRelics(exp.class, zone)) do
      if e.level > oldBest and e.level <= zs.bestKey then summary.keyRelics[#summary.keyRelics + 1] = e.id end
    end
    local open = min(key + 1, Meta.MAX_KEY)
    if open > (zs.keyMax or 0) then
      zs.keyMax = open
      summary.keyUnlocked = open
    end
    if not meta.zones[zone] then
      meta.zones[zone] = true
      summary.accountZone = true
      summary.common = Meta.commonContent(ns.Zone.order(zone) or 0)
    end
  end
  summary.levelAfter = Meta.classLevel(cs.xp)
  local unlocked = { cards = {}, relics = {} }
  for lv = before + 1, summary.levelAfter do
    local got = Meta.classContent(exp.class, lv)
    for _, id in ipairs(got.cards) do unlocked.cards[#unlocked.cards + 1] = id end
    for _, id in ipairs(got.relics) do unlocked.relics[#unlocked.relics + 1] = id end
  end
  summary.unlocked = unlocked
  -- Drapeaux de compte posés pendant l'expédition (quel que soit le résultat).
  if type(meta.flags) ~= "table" then meta.flags = {} end
  local names = {}
  for name in pairs(exp.newFlags or {}) do
    if not meta.flags[name] then names[#names + 1] = name end
    meta.flags[name] = true
  end
  table.sort(names)
  summary.flags = names
  return summary
end
