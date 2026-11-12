-- Méta-progression du compte : niveau de classe (expérience), Ligue des explorateurs (réputation
-- commune), clés mythiques et leurs affixes. L'état est fait de données simples :
-- meta = { league = points, runs = n, classes = { [classe] = { xp, runs, wins, keyMax, bestKey } },
--          flags = { [nom] = true } }
-- (cs.rep : ancienne réputation de classe des sauvegardes 1 à 3, gardée telle quelle, plus lue.)
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min

local Meta = {}
ns.Meta = Meta

---------------------------------------------------------------------------
-- Paliers de réputation
---------------------------------------------------------------------------
-- Ligue des explorateurs (commune au compte) : bibelots communs, potions, rencontres et cartes
-- neutres de tier <= palier (tier 0..3) ; Révéré : un bibelot au choix parmi 3 au départ (tiré dans la
-- réserve de l'expédition) ; Exalté : un emplacement de plus chez le marchand.
Meta.LEVELS = {
  { id = "neutral", name = "Neutral", at = 0 },
  { id = "friendly", name = "Friendly", at = 200 },
  { id = "honored", name = "Honored", at = 550 },
  { id = "revered", name = "Revered", at = 1100 },
  { id = "exalted", name = "Exalted", at = 1900 },
}
Meta.REVERED, Meta.EXALTED = 3, 4

-- Points gagnés en fin d'expédition (gagnée ou perdue), pour une expédition d'un acte.
-- Une expédition de N actes divise ces valeurs par N : la cadence ne dépend pas du
-- nombre d'actes disponibles.
Meta.REP = { step = 10, elite = 12, boss = 30 }

function Meta.level(points)
  local lv = 0
  for i = 1, #Meta.LEVELS do
    if (points or 0) >= Meta.LEVELS[i].at then lv = i - 1 end
  end
  return lv
end

function Meta.levelName(lv)
  return Meta.LEVELS[lv + 1].name
end

-- Progression dans le palier courant : niveau, points dans le palier, taille du palier (nil si max).
function Meta.progress(points)
  local lv = Meta.level(points)
  local cur = Meta.LEVELS[lv + 1].at
  local nxt = Meta.LEVELS[lv + 2]
  if not nxt then return lv, points - cur, nil end
  return lv, points - cur, nxt.at - cur
end

---------------------------------------------------------------------------
-- Niveau de classe (1 à 7) : expérience propre à chaque classe
---------------------------------------------------------------------------
-- Seuils cumulés : XP_LEVELS[n] = expérience pour atteindre le niveau n.
Meta.XP_LEVELS = { 0, 100, 250, 450, 700, 1000, 1400 }
Meta.MAX_LEVEL = #Meta.XP_LEVELS

-- Expérience d'une expédition terminée (gagnée, perdue ou abandonnée), à partir des points de
-- réputation (Meta.repFor) : rate × points, + win si elle est gagnée, le tout × (1 + key × clé).
-- Réglée par la simulation (docs/expedition.md) : ≈ 75 pour une victoire à la clé 0, ≈ 40 pour une
-- défaite au boss ; 2 à 3 expéditions par niveau au début, ≈ 20 pour le niveau 7.
Meta.XP = { rate = 0.5, win = 15, key = 0.10 }

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
local RARITY_ORDER = { basic = 0, common = 1, uncommon = 2, rare = 3, boss = 4 }
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

function Meta.classContent(class, level)
  local cards, relics = {}, {}
  for id, d in pairs(ns.Cards) do
    if d.class == class and (not level or Meta.unlockLevel(d) == level) then cards[#cards + 1] = id end
  end
  for id, r in pairs(ns.Relics) do
    if r.class == class and (not level or Meta.unlockLevel(r) == level) then relics[#relics + 1] = id end
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
function Meta.new()
  return { league = 0, runs = 0, classes = {}, flags = {} }
end

function Meta.hasFlag(meta, name)
  return type(meta.flags) == "table" and meta.flags[name] == true
end

function Meta.classState(meta, class)
  local cs = meta.classes[class]
  if not cs then
    cs = { xp = 0, runs = 0, wins = 0, keyMax = 0, bestKey = -1 }
    meta.classes[class] = cs
  end
  return cs
end

-- Déblocages d'une classe : { level = niveau de classe 1..7, league = palier de Ligue 0..4 }.
function Meta.unlocks(meta, class)
  return { level = Meta.levelOf(meta, class), league = Meta.level(meta.league) }
end

-- Déblocages complets (simulation « exalted ») ; level = niveau de classe (défaut 7).
function Meta.allUnlocked(level)
  return { level = level or Meta.MAX_LEVEL, league = Meta.EXALTED }
end

-- Classe au niveau maximal (liseré doré, titre).
function Meta.isMaxLevel(meta, class)
  return Meta.levelOf(meta, class) >= Meta.MAX_LEVEL
end

-- Titre cosmétique du niveau 7 (était celui d'Exalté de classe).
function Meta.title(meta, class)
  if Meta.isMaxLevel(meta, class) then return "Dragonslayer" end
  return nil
end

-- Niveaux de clé jouables pour une classe : 0..keyMax.
function Meta.keyMax(meta, class)
  local cs = meta.classes[class]
  return cs and cs.keyMax or 0
end

-- Réputation gagnée par une expédition terminée.
function Meta.repFor(exp)
  local s = exp.stats
  local acts = max(1, exp.acts or 1)
  local pts = s.cleared * Meta.REP.step + s.elites * Meta.REP.elite + s.bosses * Meta.REP.boss
  return floor(pts / acts + 0.5)
end

-- Expérience de classe gagnée par une expédition terminée (Meta.XP).
function Meta.xpFor(exp)
  local P = Meta.XP
  local v = Meta.repFor(exp) * P.rate + (exp.result == "won" and P.win or 0)
  return floor(v * (1 + P.key * (exp.key or 0)) + 0.5)
end

-- Crée une expédition pour ce compte (déblocages et clé vérifiés).
-- opts : seed, class, key ; renvoie exp ou nil, raison.
function Meta.newExpedition(meta, opts)
  local class = opts.class or "priest"
  local key = opts.key or 0
  if key < 0 or key > Meta.keyMax(meta, class) then return nil, "key locked" end
  return ns.Expedition.new({ seed = opts.seed, class = class, key = key,
    unlocks = Meta.unlocks(meta, class), flags = meta.flags, stats = opts.stats, quiet = opts.quiet })
end

-- Applique le résultat d'une expédition terminée au compte. Renvoie un résumé :
-- { rep (Ligue), xp (classe), levelBefore, levelAfter, unlocked = { cards = {ids}, relics = {ids} }
--   (ce que la montée de niveau vient de débloquer), leagueBefore, leagueAfter,
--   keyUnlocked (niveau ou nil), flags (noms des drapeaux de compte nouvellement posés, triés) }
function Meta.record(meta, exp)
  local cs = Meta.classState(meta, exp.class)
  local gained, xp = Meta.repFor(exp), Meta.xpFor(exp)
  local before = Meta.classLevel(cs.xp)
  local summary = { rep = gained, xp = xp, levelBefore = before, leagueBefore = Meta.level(meta.league) }
  cs.xp = (cs.xp or 0) + xp
  meta.league = meta.league + gained
  cs.runs = cs.runs + 1
  meta.runs = meta.runs + 1
  if exp.result == "won" then
    cs.wins = cs.wins + 1
    local key = exp.key or 0
    if key > cs.bestKey then cs.bestKey = key end
    local open = min(key + 1, Meta.MAX_KEY)
    if open > cs.keyMax then
      cs.keyMax = open
      summary.keyUnlocked = open
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
  summary.leagueAfter = Meta.level(meta.league)
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
