-- Méta-progression du compte : niveau de classe (expérience), campagne (boss de zone battus par classe et par
-- le compte, zone la plus loin atteinte par classe), clés mythiques par classe, affixes. Données simples :
-- meta = { runs = n, zones = { [zone] = true } (boss de zone battus par le compte, toutes classes),
--          classes = { [classe] = { xp, runs, wins (Nefarian battu), keyMax (clé la plus haute ouverte),
--                                   bestKey (meilleure clé d'une victoire complète, -1 : aucune),
--                                   farthest (rang de la zone la plus loin atteinte, 0 : aucune),
--                                   zones = { [zone] = { won (boss battu), keyMax (plus lu depuis la v6),
--                                                        bestKey (meilleure clé où ce boss est battu) } } } },
--          flags = { [nom] = true } }
-- Une expédition traverse toute la campagne (décision du joueur, 14/11/2026) : chaque boss battu compte tout de
-- suite (Meta.bank), la fin d'expédition ajoute le reste (Meta.record).
-- (cs.rep : ancienne réputation de classe des sauvegardes 1 à 3, gardée telle quelle, plus lue.)
-- Contrat des zones : docs/zones.md ; détails : docs/expedition.md.
local _, ns = ...

local floor, max, min = math.floor, math.max, math.min

local Meta = {}
ns.Meta = Meta

---------------------------------------------------------------------------
-- Niveau de classe (1 à 25) : expérience propre à chaque classe
---------------------------------------------------------------------------
-- Seuils cumulés : XP_LEVELS[n] = expérience pour atteindre le niveau n (docs/talents.md, § 1.2 : 100 par niveau
-- jusqu'au 6, 150 jusqu'au 16, 250 jusqu'au 21, 350 jusqu'au 25). Chaque niveau à partir du 2 donne un point de
-- talent (Meta.talentPoints : niveau − 1, 24 au niveau 25 = l'arbre entier). Au-delà du niveau 25, l'expérience
-- est comptée sans rien donner.
Meta.XP_LEVELS = { 0, 100, 200, 300, 400, 500, 650, 800, 950, 1100, 1250, 1400, 1550,
  1700, 1850, 2000, 2250, 2500, 2750, 3000, 3250, 3600, 3950, 4300, 4650 }
Meta.MAX_LEVEL = #Meta.XP_LEVELS

-- Paliers de contenu (champ level des cartes et bibelots de classe, 1 à 7, inchangé) : CONTENT_LEVELS[n] = niveau
-- de classe qui ouvre le palier n (docs/talents.md, § 1.3 : même seuil d'expérience qu'avant les 25 niveaux, ou
-- plus tôt). exp.unlock.level, Meta.allUnlocked(level) et le paramètre de simulation level= sont des paliers.
Meta.CONTENT_LEVELS = { 1, 2, 3, 5, 7, 9, 11 }
Meta.MAX_TIER = #Meta.CONTENT_LEVELS

-- Palier de contenu ouvert au niveau de classe lv (1 à Meta.MAX_TIER).
function Meta.contentTier(lv)
  local t = 1
  for i = 2, Meta.MAX_TIER do
    if (lv or 1) >= Meta.CONTENT_LEVELS[i] then t = i end
  end
  return t
end

-- Expérience d'une expédition terminée (gagnée, perdue ou abandonnée), tirée de son avancée :
-- step par étape franchie (boss compris), elite par élite, boss par boss, win si elle est gagnée, le tout
-- × (1 + key × clé), arrondi : ≈ 76 pour une Westfall gagnée à la clé 0 avec une élite, ≈ 440 pour une
-- campagne gagnée ; rythme des 25 niveaux : docs/talents.md, § 1.2. Clé : +15 % par niveau.
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

-- Palier de contenu d'une carte ou d'un bibelot de classe (champ level, absent = 1) ; niveau de classe qui
-- l'ouvre : Meta.CONTENT_LEVELS[palier].
function Meta.unlockLevel(def)
  return (def and def.level) or 1
end

-- Contenu d'une classe : { cards = { ids }, relics = { ids } } (cartes de départ comprises), triés par
-- palier, rareté, coût puis nom ; level = n : seulement ce qui se débloque au palier de contenu n (1 à 7).
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
    cs = { xp = 0, runs = 0, wins = 0, keyMax = 0, bestKey = -1, farthest = 0, zones = {}, talents = {} }
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

-- La classe a-t-elle battu le boss de la zone ?
function Meta.classWon(meta, class, zone)
  local zs = Meta.zoneInfo(meta, class, zone)
  return zs ~= nil and zs.won == true
end

-- Rang de la zone la plus loin atteinte par la classe (0 : aucune expédition) : une zone battue est atteinte.
function Meta.farthest(meta, class)
  local cs = meta.classes[class]
  local n = cs and tonumber(cs.farthest) or 0
  for zone, zs in pairs(cs and type(cs.zones) == "table" and cs.zones or {}) do
    local o = type(zs) == "table" and zs.won and ns.Zone.order(zone)
    if o and o > n then n = o end
  end
  return n
end

-- La classe a-t-elle déjà atteint la zone (au cours d'une expédition) ?
function Meta.zoneReached(meta, class, zone)
  local o = ns.Zone.order(zone)
  return o ~= nil and o <= Meta.farthest(meta, class)
end

-- Nombre de boss de zone battus par la classe.
function Meta.beatenCount(meta, class)
  local n = 0
  for _, zid in ipairs(ns.Zone.ORDER) do if Meta.classWon(meta, class, zid) then n = n + 1 end end
  return n
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

-- Clés ouvertes pour une classe : 0..keyMax. Une clé vaut pour toute l'expédition ; +N s'ouvre en battant le
-- dernier boss de la campagne (Nefarian) à +N−1 (décision du concepteur, 14/11/2026).
function Meta.keyMax(meta, class)
  local cs = meta.classes[class]
  return cs and tonumber(cs.keyMax) or 0
end

-- Meilleure clé : sans zone, celle d'une victoire complète de la classe (-1 : jamais) ; avec une zone, la
-- meilleure clé à laquelle la classe a battu le boss de cette zone (bibelots de clé, écran Progress).
function Meta.bestKey(meta, class, zone)
  if zone then
    local zs = Meta.zoneInfo(meta, class, zone)
    return zs and zs.bestKey or -1
  end
  local cs = meta.classes[class]
  return cs and tonumber(cs.bestKey) or -1
end

-- Déblocages d'une classe : { level = palier de contenu 1..7 (Meta.contentTier du niveau de classe), common =
--   palier commun 0..7, won = { [zone] = meilleure clé gagnée } (zones gagnées par la classe : cartes de zone,
--   bibelots de clé), talents = { [nœud] = rang } (copie de l'arbre de la classe, cs.talents), spec = voie du
--   nœud Specialization (cs.spec, nil sans) }.
function Meta.unlocks(meta, class)
  local won = {}
  local cs = meta.classes[class]
  for zone, zs in pairs(cs and type(cs.zones) == "table" and cs.zones or {}) do
    if type(zs) == "table" and zs.won then won[zone] = zs.bestKey or 0 end
  end
  local talents = {}
  for id, r in pairs(cs and type(cs.talents) == "table" and cs.talents or {}) do
    if type(r) == "number" and r > 0 then talents[id] = r end
  end
  return { level = Meta.contentTier(Meta.levelOf(meta, class)), common = Meta.commonTier(meta), won = won,
    talents = talents, spec = cs and cs.spec or nil }
end

-- Déblocages de simulation : le compte et la classe ont gagné les `zones` premières zones (défaut :
-- toutes), à toutes les clés ; level = palier de contenu (défaut Meta.MAX_TIER = 7 : tout le contenu) ; aucun
-- talent (la simulation les pose : tree=, talents=).
function Meta.allUnlocked(level, zones)
  zones = zones or ns.Zone.count()
  local won = {}
  for i = 1, zones do won[ns.Zone.ORDER[i]] = Meta.MAX_KEY end
  return { level = level or Meta.MAX_TIER, common = zones, won = won }
end

-- Classe au niveau maximal (liseré doré, titre).
function Meta.isMaxLevel(meta, class)
  return Meta.levelOf(meta, class) >= Meta.MAX_LEVEL
end

-- Titre cosmétique du niveau 25 (« Veteran », docs/talents.md, § 1.3) ; gardé acquis par un joueur qui l'avait
-- au niveau 7 avant les 25 niveaux (cs.veteran, posé par la migration 7 -> 8). « Dragonslayer » se gagne contre
-- Nefarian (ns.Blackrock.title, qui retombe sur celui-ci) : c'est ns.Blackrock.title que l'interface affiche
-- (accueil, Progress, journal).
function Meta.title(meta, class)
  local cs = meta.classes[class]
  if Meta.isMaxLevel(meta, class) or (cs and cs.veteran == true) then return "Veteran" end
  return nil
end

---------------------------------------------------------------------------
-- Points de talent (docs/talents.md ; règles de l'arbre : Core/Talents.lua)
---------------------------------------------------------------------------
-- cs.talents = { [nœud] = rang }, cs.spec = voie choisie au nœud Specialization. Dépenser (Meta.learn) et
-- rembourser (Meta.reset) se font hors expédition : Save.learnTalent / Save.resetTalents refusent ("running")
-- tant qu'une expédition est en cours (comme Save.start), l'expédition copie l'arbre à son départ (Meta.unlocks).

-- Points gagnés par la classe : niveau − 1 (0 au niveau 1, 24 au niveau 25).
function Meta.talentPoints(meta, class)
  return Meta.levelOf(meta, class) - 1
end

-- Points dépensés dans l'arbre de la classe.
function Meta.spent(meta, class)
  local cs = meta.classes[class]
  return ns.Talent.spentIn(cs and cs.talents)
end

-- Points restant à dépenser.
function Meta.pointsLeft(meta, class)
  return Meta.talentPoints(meta, class) - Meta.spent(meta, class)
end

-- Apprend un rang du nœud `node` (choice : voie du nœud Specialization ; un nœud Specialization déjà appris change
-- de voie sans coût). Renvoie true, ou nil et la raison (ns.Talent.canLearn : "unknown", "points", "row",
-- "max", "choice").
function Meta.learn(meta, class, node, choice)
  local cs = Meta.classState(meta, class)
  if type(cs.talents) ~= "table" then cs.talents = {} end
  local ok, why = ns.Talent.canLearn(class, cs.talents, node, choice, Meta.talentPoints(meta, class), cs.spec)
  if not ok then return nil, why end
  local n = ns.Talent.node(class, node)
  if n.choices and (cs.talents[node] or 0) >= 1 then
    cs.spec = choice
    return true
  end
  cs.talents[node] = (cs.talents[node] or 0) + 1
  if n.choices then cs.spec = choice end
  return true
end

-- Rembourse tout l'arbre de la classe (gratuit). Renvoie les points rendus.
function Meta.reset(meta, class)
  local cs = Meta.classState(meta, class)
  local n = ns.Talent.spentIn(cs.talents)
  cs.talents = {}
  cs.spec = nil
  return n
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

-- Expérience de classe d'une expédition (Meta.XP), sur toute la campagne : étapes franchies (56 au plus), élites,
-- boss (7 au plus), +win seulement pour une victoire complète (Nefarian). partial = vrai : sans le bonus de
-- victoire (expérience acquise à un boss, Meta.bank).
function Meta.xpFor(exp, partial)
  local P, s = Meta.XP, exp.stats
  local v = s.cleared * P.step + s.elites * P.elite + s.bosses * P.boss
    + ((not partial and exp.result == "won") and P.win or 0)
  return floor(v * (1 + P.key * (exp.key or 0)) + 0.5)
end

-- Crée une expédition pour ce compte : toujours à Westfall (première zone), clé ouverte pour la classe.
-- opts : seed, class, key ; renvoie exp ou nil, raison.
-- Options de Expedition.new pour ce compte (Meta.newExpedition ; Save.start les garde pour le rejeu,
-- Core/Record.lua), ou nil, raison.
function Meta.expeditionOpts(meta, opts)
  local class = opts.class or "priest"
  local zone = ns.Zone.FIRST
  local key = opts.key or 0
  if not ns.Zone.playable(zone) then return nil, "zone coming later" end
  if key < 0 or key > Meta.keyMax(meta, class) then return nil, "key locked" end
  return { seed = opts.seed, class = class, zone = zone, key = key,
    unlocks = Meta.unlocks(meta, class), flags = meta.flags, stats = opts.stats, quiet = opts.quiet }
end

function Meta.newExpedition(meta, opts)
  local xopts, why = Meta.expeditionOpts(meta, opts)
  if not xopts then return nil, why end
  return ns.Expedition.new(xopts)
end

-- Boss d'une zone battu par une classe à cette clé : boss de la zone battu par la classe (carte épique de la
-- classe liée à la zone), meilleure clé de la zone (bibelots de clé +1, +3, +5), boss battu par le compte
-- (commun de la zone). Renvoie { zone, zoneWon, keyRelics = {ids}, accountZone } (données simples).
function Meta.recordBoss(meta, class, zone, key)
  if type(meta.zones) ~= "table" then meta.zones = {} end
  local zs = Meta.zoneState(meta, class, zone)
  local part = { zone = zone, keyRelics = {} }
  key = key or 0
  local oldBest = zs.bestKey or -1
  if not zs.won then
    zs.won = true
    part.zoneWon = true
  end
  if key > oldBest then zs.bestKey = key end
  for _, e in ipairs(Meta.keyRelics(class, zone)) do
    if e.level > oldBest and e.level <= zs.bestKey then part.keyRelics[#part.keyRelics + 1] = e.id end
  end
  if not meta.zones[zone] then
    meta.zones[zone] = true
    part.accountZone = true
  end
  return part
end

-- Drapeaux posés par l'expédition et pas encore reportés : reportés dans la méta, noms ajoutés à into.
local function bankFlags(meta, exp, into)
  if type(meta.flags) ~= "table" then meta.flags = {} end
  local names = {}
  for name in pairs(exp.newFlags or {}) do
    if not meta.flags[name] then names[#names + 1] = name end
    meta.flags[name] = true
  end
  table.sort(names)
  for _, n in ipairs(names) do into[#into + 1] = n end
end

-- Ce que la méta a déjà reçu de l'expédition (exp.banked, données simples, créé au besoin) :
-- { n = boss reportés, xp = expérience reportée, levelBefore = niveau de la classe avant le premier report,
--   zones = { parts de Meta.recordBoss }, flags = { noms } }.
local function banked(exp)
  local b = exp.banked
  if type(b) ~= "table" then
    b = { n = 0, xp = 0, zones = {}, flags = {} }
    exp.banked = b
  end
  return b
end

-- Reporte tout de suite dans la méta ce que l'expédition a déjà acquis (Save.settle après chaque action,
-- Save.finish) : zone la plus loin atteinte, et pour chaque boss battu pas encore reporté : épique de la classe
-- liée à la zone, bibelots de clé, commun du compte (Meta.recordBoss), expérience des étapes franchies jusque-là
-- (sans le bonus de victoire) et drapeaux posés. Idempotent. Les déblocages figés au départ de l'expédition
-- (exp.unlock, exp.flags) ne changent pas : ils servent à l'expédition suivante. Renvoie la liste des parts
-- nouvellement reportées.
function Meta.bank(meta, exp)
  if type(exp) ~= "table" or not exp.class then return {} end
  local cs = Meta.classState(meta, exp.class)
  local o = ns.Zone.order(exp.zone)
  if o and o > (tonumber(cs.farthest) or 0) then cs.farthest = o end
  local b = banked(exp)
  local beaten = exp.beaten or {}
  local new = {}
  if b.n >= #beaten then return new end
  if b.levelBefore == nil then b.levelBefore = Meta.classLevel(cs.xp) end
  while b.n < #beaten do
    b.n = b.n + 1
    local part = Meta.recordBoss(meta, exp.class, beaten[b.n], exp.key)
    b.zones[#b.zones + 1] = part
    new[#new + 1] = part
  end
  local xp = Meta.xpFor(exp, true) - b.xp
  if xp > 0 then
    cs.xp = (cs.xp or 0) + xp
    b.xp = b.xp + xp
  end
  bankFlags(meta, exp, b.flags)
  return new
end

-- Applique le résultat d'une expédition terminée au compte (après Meta.bank : ce qu'elle a acquis à chaque boss
-- est déjà reporté). Renvoie un résumé de TOUTE l'expédition :
-- { xp (classe, total de l'expédition), levelBefore (avant l'expédition), levelAfter, pointsGained (points de
--   talent gagnés : un par niveau), unlocked = { cards = {ids}, relics = {ids} } (ce que la montée de niveau vient
--   de débloquer : paliers de contenu franchis), zone (zone atteinte), beaten = {zones},
--   zones = { { zone, zoneWon (premier boss de la zone battu par la classe), zoneCards = {ids} (épiques
--     débloquées), keyRelics = {ids}, accountZone, common = Meta.commonContent(ordre) (si accountZone) } }
--     (un par boss battu, dans l'ordre), zoneCards et keyRelics (toutes zones, à plat),
--   keyUnlocked (clé ouverte par une victoire complète, ou nil), flags (drapeaux nouvellement posés, triés) }
function Meta.record(meta, exp)
  Meta.bank(meta, exp)
  local cs = Meta.classState(meta, exp.class)
  local b = banked(exp)
  local before = b.levelBefore or Meta.classLevel(cs.xp)
  local total = Meta.xpFor(exp)
  local xp = max(0, total - b.xp)
  cs.xp = (cs.xp or 0) + xp
  b.xp = b.xp + xp
  cs.runs = (cs.runs or 0) + 1
  meta.runs = (meta.runs or 0) + 1
  local summary = { xp = b.xp, levelBefore = before, zone = exp.zone or ns.Zone.FIRST, result = exp.result,
    beaten = {}, zones = {}, zoneCards = {}, keyRelics = {} }
  for i, z in ipairs(exp.beaten or {}) do summary.beaten[i] = z end
  for _, p in ipairs(b.zones) do
    local part = { zone = p.zone, zoneWon = p.zoneWon, accountZone = p.accountZone, zoneCards = {},
      keyRelics = {} }
    if p.zoneWon then part.zoneCards = Meta.zoneCards(exp.class, p.zone) end
    for _, id in ipairs(p.keyRelics or {}) do part.keyRelics[#part.keyRelics + 1] = id end
    if p.accountZone then part.common = Meta.commonContent(ns.Zone.order(p.zone) or 0) end
    for _, id in ipairs(part.zoneCards) do summary.zoneCards[#summary.zoneCards + 1] = id end
    for _, id in ipairs(part.keyRelics) do summary.keyRelics[#summary.keyRelics + 1] = id end
    summary.zones[#summary.zones + 1] = part
  end
  if exp.result == "won" then
    cs.wins = (cs.wins or 0) + 1
    local key = exp.key or 0
    if key > (tonumber(cs.bestKey) or -1) then cs.bestKey = key end
    local open = min(key + 1, Meta.MAX_KEY)
    if open > (tonumber(cs.keyMax) or 0) then
      cs.keyMax = open
      summary.keyUnlocked = open
    end
  end
  summary.levelAfter = Meta.classLevel(cs.xp)
  -- un point de talent par niveau gagné ; le contenu suit les paliers (Meta.contentTier)
  summary.pointsGained = summary.levelAfter - before
  local unlocked = { cards = {}, relics = {} }
  for lv = Meta.contentTier(before) + 1, Meta.contentTier(summary.levelAfter) do
    local got = Meta.classContent(exp.class, lv)
    for _, id in ipairs(got.cards) do unlocked.cards[#unlocked.cards + 1] = id end
    for _, id in ipairs(got.relics) do unlocked.relics[#unlocked.relics + 1] = id end
  end
  summary.unlocked = unlocked
  -- Drapeaux de compte posés pendant l'expédition (quel que soit le résultat) : ceux déjà reportés à un boss
  -- et les autres.
  local names = {}
  for _, n in ipairs(b.flags) do names[#names + 1] = n end
  bankFlags(meta, exp, names)
  table.sort(names)
  summary.flags = names
  return summary
end
