-- Méta-progression du compte : réputation par classe, Ligue des explorateurs,
-- clés mythiques et leurs affixes. L'état est fait de données simples :
-- meta = { league = points, runs = n, classes = { [classe] = { rep, runs, wins, keyMax, bestKey } },
--          flags = { [nom] = true } }
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min

local Meta = {}
ns.Meta = Meta

---------------------------------------------------------------------------
-- Paliers de réputation
---------------------------------------------------------------------------
-- Les mêmes seuils servent à la classe et à la Ligue.
-- Classe : 0 Neutre (cartes rep 0), 1 Amical (rep 1), 2 Honoré (rep 2),
--          3 Révéré (bibelot de classe au départ), 4 Exalté (cosmétique).
-- Ligue  : bibelots, potions et rencontres de tier <= palier (tier 0..3) ;
--          Exalté : un emplacement de plus chez le marchand.
Meta.LEVELS = {
  { id = "neutral", name = "Neutre", at = 0 },
  { id = "friendly", name = "Amical", at = 200 },
  { id = "honored", name = "Honoré", at = 550 },
  { id = "revered", name = "Révéré", at = 1100 },
  { id = "exalted", name = "Exalté", at = 1900 },
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
  fortified = { hp = 0.20 },                      -- ennemis normaux : PV
  tyrannical = { eliteHp = 0.20, eliteDamage = 0.20, bossHp = 0.07, bossDamage = 0 },
  bolstering = { force = 1 },                      -- Force donnée aux survivants (hors boss)
  necrotic = { step = 0.10, cap = 10 },            -- soins −10 % par coup reçu
  famine = { rest = 0.20 },                        -- fraction soignée au feu de camp
}
local P = Meta.AFFIX

local function scale(v, f) return floor(v * (1 + f) + 0.5) end
local function pct(f) return floor(f * 100 + 0.5) end

A.fortified = {
  name = "Fortifié", level = 1,
  text = ("Ennemis normaux : +%d %% de PV."):format(pct(P.fortified.hp)),
  hooks = {
    enemyHp = function(c, src, v, def)
      if def.elite or def.boss then return v end
      return scale(v, P.fortified.hp)
    end,
  },
}

A.tyrannical = {
  name = "Tyrannique", level = 2,
  text = ("Élites : +%d %% de PV et de dégâts. Boss : +%d %% de PV%s.")
    :format(pct(P.tyrannical.eliteHp), pct(P.tyrannical.bossHp),
      P.tyrannical.bossDamage > 0 and (" et +%d %% de dégâts"):format(pct(P.tyrannical.bossDamage)) or ""),
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
  name = "Galvanisant", level = 3,
  text = ("Quand un ennemi meurt, les autres gagnent %d Force (sauf les boss)."):format(P.bolstering.force),
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

ns.Statuses.necrotic = { name = "Nécrotique", affix = true,
  text = ("Soins reçus réduits de %d %% par cumul, jusqu'à la fin du combat."):format(pct(P.necrotic.step)) }

A.necrotic = {
  name = "Nécrotique", level = 4,
  text = ("Chaque coup reçu réduit tes soins de %d %% jusqu'à la fin du combat."):format(pct(P.necrotic.step)),
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
  name = "Disette", level = 5,
  text = ("Le feu de camp ne soigne plus que %d %% des PV."):format(pct(P.famine.rest)),
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
    cs = { rep = 0, runs = 0, wins = 0, keyMax = 0, bestKey = -1 }
    meta.classes[class] = cs
  end
  return cs
end

-- Déblocages d'une classe : { rep = palier de classe, league = palier de Ligue }.
function Meta.unlocks(meta, class)
  local cs = meta.classes[class]
  return { rep = Meta.level(cs and cs.rep or 0), league = Meta.level(meta.league) }
end

-- Déblocages complets (simulation « exalted »).
function Meta.allUnlocked()
  return { rep = Meta.EXALTED, league = Meta.EXALTED }
end

function Meta.isExalted(meta, class)
  return Meta.unlocks(meta, class).rep >= Meta.EXALTED
end

-- Titre cosmétique d'Exalté.
function Meta.title(meta, class)
  if Meta.isExalted(meta, class) then return "Tueur de dragons" end
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

-- Crée une expédition pour ce compte (déblocages et clé vérifiés).
-- opts : seed, class, key ; renvoie exp ou nil, raison.
function Meta.newExpedition(meta, opts)
  local class = opts.class or "priest"
  local key = opts.key or 0
  if key < 0 or key > Meta.keyMax(meta, class) then return nil, "clé verrouillée" end
  return ns.Expedition.new({ seed = opts.seed, class = class, key = key,
    unlocks = Meta.unlocks(meta, class), flags = meta.flags, stats = opts.stats, quiet = opts.quiet })
end

-- Applique le résultat d'une expédition terminée au compte. Renvoie un résumé :
-- { rep, classBefore, classAfter, leagueBefore, leagueAfter, keyUnlocked (niveau ou nil),
--   flags (noms des drapeaux de compte nouvellement posés, triés) }
function Meta.record(meta, exp)
  local cs = Meta.classState(meta, exp.class)
  local gained = Meta.repFor(exp)
  local summary = { rep = gained, classBefore = Meta.level(cs.rep), leagueBefore = Meta.level(meta.league) }
  cs.rep = cs.rep + gained
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
  summary.classAfter = Meta.level(cs.rep)
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
