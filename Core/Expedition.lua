-- Expédition : machine à états entre les combats. L'état est fait de données simples
-- (aucune fonction, aucune métatable) : il se sauvegarde tel quel dans SlayTheDragonDB,
-- combat en cours compris. L'interface et les bots passent par la même API :
--   Expedition.new(opts) -> exp
--   Expedition.choices(exp) -> { action, ... }       (ce qu'on peut faire maintenant)
--   Expedition.act(exp, action) -> true | false, raison
-- Une action est une liste : { "verbe", arg1, arg2 }. Voir docs/expedition.md.
--
-- Hasard : une graine par expédition, des flux séparés (carte, butin, marchand,
-- rencontres, combats). Les récompenses sont tirées dès qu'on entre dans l'étape et
-- stockées dans l'état : recharger ne change rien.
local _, ns = ...

local U, Rng, Card, Map, Combat = ns.Util, ns.Rng, ns.Card, ns.Map, ns.Combat
local floor, min, max = math.floor, math.min, math.max

local X = {}
ns.Expedition = X

-- 2 : drapeaux de compte (exp.flags, exp.newFlags) et journal des rencontres (stats.events).
-- 3 : classe générique (ressource de combat c.player.res au lieu de demence, état de classe c.cls).
-- 4 : déblocages par niveau de classe (unlock.level au lieu de unlock.rep).
-- 5 : campagne par zones (exp.zone ; unlock.common et unlock.won au lieu de unlock.league).
-- 6 : cartes épiques (exp.epicOffered, exp.rng.epic créé au besoin, reward.epics / epicDone, épique du
--     marchand : shop.cards[i].epic). Règle finale du 14/11/2026 sans changement de version : champ
--     facultatif exp.startEpics (offre de départ, phase « start »).
-- 7 : l'épique se gagne (décision du joueur, 14/11/2026) : plus d'offre de départ (exp.startEpics,
--     exp.startEpicPicked et exp.epicOffered retirés), chute d'épique par élite selon le rang de la zone.
-- 8 : une expédition traverse toute la campagne (décision du joueur, 14/11/2026) : exp.startZone, exp.lastZone,
--     exp.beaten (boss battus), phase « transit » entre deux zones (exp.transit), exp.banked (ce que la méta a
--     déjà reçu : Meta.bank) ; exp.act = rang de la zone dans l'expédition, exp.acts = nombre de zones.
-- 9 : paliers d'amélioration (décision du joueur, 15/11/2026) : up d'une carte = false ou palier 1..3 (true
--     devient 1), stats.upTiers[n] = améliorations qui ont atteint le palier n (docs/ameliorations.md).
X.VERSION = 9

-- Entre deux zones : soin de cette part des PV max (sans dépasser le maximum ; crochet healOut des soins hors
-- combat : Cursed Eye of Paleth le divise par deux). Lecture du concepteur de « soin partiel, 50 % des PV max ».
X.ZONE_HEAL = 0.5

-- Cartes épiques (rarity = "epic", docs/expedition.md, « Cartes épiques ») : jusqu'à X.EPIC.max dans le deck
-- (décision du joueur du 19/11/2026 : leur cumul fait passer les zones 4 à 7), chacune règle en jeu dès le début
-- de chaque combat (Combat.new : c.epic, puis c.moreEpics) ; au plafond, en prendre une autre remplace la plus
-- ancienne. Une épique déjà obtenue dans l'expédition ne retombe pas (exp.epicTaken).
-- L'épique se GAGNE : rien au départ. Plafond, chute et vente, réglables ici :
--   max       épiques au plus dans le deck (1 = la règle du 14/11/2026 ; 0 ou nil = sans plafond, retenu le
--             19/11/2026 : chaque épique obtenue reste ; docs/equilibrage.md, « Mur des zones 4 à 7 sans épique »)
--   drop      [genre de combat] = chances, par rang de zone (ns.Zone.order : 1 = Westfall … 7 = Blackrock
--             Mountain ; au-delà de la table, la dernière valeur), qu'une victoire de ce genre (combat de
--             rencontre compris) propose une épique en plus de la récompense normale (prendre, ou garder
--             l'actuelle ; refusable). Genres absents : jamais.
--   choices   épiques proposées quand elle tombe (distinctes, débloquées, hors celle du deck)
--   shop      chance qu'un marchand vende une épique (emplacement en plus des cartes), à partir de l'étape
--             shopFloor (la moitié du parcours : étapes 1 à 7, boss en 8) ; 0 = jamais
--   price     prix de base d'une épique chez le marchand (± X.PRICE_JITTER, crochet « price » genre "card")
-- Sans épique débloquée, aucun tirage n'est fait (l'expédition se déroule exactement comme sans épiques).
X.EPIC = {
  max = 0,
  drop = { elite = { 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.85 } },
  choices = 1,
  shop = 0.5,
  shopFloor = 4,
  price = 150,
}

-- Part de rares des récompenses de cartes (combat, élite, marchand ; le boss n'offre que des rares), par rang
-- de zone (ns.Zone.order ; au-delà de la table, la dernière valeur) : le poids « rare » de X.CARD_WEIGHTS est
-- multiplié par ce facteur et pris sur le poids « common » (le total ne change pas : la part de rares est
-- multipliée d'autant). Zone 1 = 1 (poids d'origine, tirages inchangés) ; à régler par simulation.
X.RARE_BY_ZONE = { 1, 1.15, 1.3, 1.5, 1.65, 1.8, 2 }

-- Marchand selon le rang de la zone (décision du joueur du 15/11/2026 : « prix plus hauts dans les zones hautes,
-- mais plus de cartes déjà améliorées et plus rares » ; docs/expedition.md, « Économie sur sept zones »). Tables
-- par rang de zone (ns.Zone.order ; au-delà de la table, la dernière valeur) ; rang 1 (Westfall) = étal
-- d'origine, mêmes tirages et mêmes prix.
--   PRICE_BY_ZONE        multiplicateur des prix de l'étal (cartes, cartes neutres, bibelots, potions, épique),
--                        appliqué avant le crochet « price » des bibelots ; le retrait garde sa propre hausse
--   SHOP_UPGRADED        chance qu'une carte de l'étal (classe ou neutre, améliorable, pas l'épique) soit vendue
--                        déjà améliorée (tirage du flux « merchant », seulement si la chance dépasse 0)
--   UPGRADED_PRICE       facteur de prix d'une carte vendue améliorée (quel que soit son palier)
--   SHOP_UP_TIER         palier d'une carte vendue améliorée (docs/ameliorations.md) : nombre, ou table par rang de
--                        zone ; borné aux paliers écrits de la carte. 1 aujourd'hui (le marchand ne vend que le +1) :
--                        une table { 1, 1, 1, 2, 2, 2, 3 } suffira quand les paliers 2 et 3 seront écrits
--   SHOP_RARE_BY_ZONE    part de rares des cartes de l'étal (comme X.RARE_BY_ZONE, propre au marchand)
--   SHOP_RELIC_RARE_BY_ZONE  part de bibelots rares de l'étal (poids « rare » de X.RELIC_WEIGHTS.normal
--                        multiplié, pris sur « common » ; récompenses, coffres et rencontres inchangés)
X.PRICE_BY_ZONE = { 1, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2 }
X.SHOP_UPGRADED = { 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6 }
X.UPGRADED_PRICE = 1.25
X.SHOP_UP_TIER = 1
X.SHOP_RARE_BY_ZONE = { 1, 1.3, 1.6, 1.9, 2.2, 2.5, 2.8 }
X.SHOP_RELIC_RARE_BY_ZONE = { 1, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2 }

-- Paramètres de la couche expédition (réglés par la simulation).
X.START_GOLD = 50
X.POTION_SLOTS = 3
X.REST_FRACTION = 0.30
X.EASY_COMBATS = 2 -- premiers combats de chaque acte tirés dans le groupe « easy »
X.GOLD = { combat = { 12, 18 }, elite = { 25, 35 }, boss = { 75, 85 }, chest = { 20, 30 } }
X.CARD_WEIGHTS = {
  combat = { common = 60, uncommon = 33, rare = 7 },
  elite = { common = 45, uncommon = 40, rare = 15 },
  boss = { rare = 1 },
  shop = { common = 50, uncommon = 37, rare = 13 },
}
X.RELIC_WEIGHTS = {
  normal = { common = 50, uncommon = 35, rare = 15 },
  boss = { boss = 1 },
}
X.POTION_WEIGHTS = { common = 65, uncommon = 25, rare = 10 }
X.POTION_DROP = 0.35 -- chance de potion après un combat normal ou d'élite
X.PRICES = {
  card = { common = 35, uncommon = 55, rare = 90 },
  neutral = { common = 45, uncommon = 65, rare = 100 }, -- cartes neutres (docs/cartes-neutres.md)
  relic = { common = 90, uncommon = 120, rare = 160, boss = 220 },
  potion = { common = 30, uncommon = 45, rare = 60 },
}
X.PRICE_JITTER = 0.10
X.REMOVE_PRICE, X.REMOVE_STEP = 75, 25
-- neutral : emplacement « Neutral » en plus des cartes de classe (une carte neutre débloquée)
X.SHOP = { cards = 5, neutral = 1, relics = 3, potions = 3 }
-- Poids de tirage d'une rencontre selon sa famille (ev.weight le remplace).
X.EVENT_WEIGHT = { common = 10, rare = 3, story = 8 }

X.PHASES = { start = true, map = true, combat = true, reward = true, campfire = true,
  merchant = true, event = true, select = true, transit = true, done = true }

-- Rang de la zone EN COURS de l'expédition dans la campagne (1 = Westfall ; 1 si la zone est inconnue) : il
-- règle la chute d'épique et la part de rares (X.EPIC.drop, X.RARE_BY_ZONE).
function X.zoneRank(exp)
  return ns.Zone.order(exp.zone) or 1
end

-- Valeur d'une table par rang de zone (X.EPIC.drop, X.RARE_BY_ZONE) : au-delà de la table, la dernière.
local function byRank(t, exp)
  if type(t) ~= "table" then return t end
  return t[min(X.zoneRank(exp), #t)]
end

-- Poids « rare » multipliés par m, pris sur « common » (total inchangé) ; la table d'origine si m vaut 1.
local function moreRares(w, m)
  if m == 1 or not (w and w.rare and w.common) then return w end
  local extra = min(w.rare * (m - 1), w.common)
  local out = {}
  for k, v in pairs(w) do out[k] = v end
  out.common, out.rare = w.common - extra, w.rare + extra
  return out
end

-- Poids de rareté d'une récompense de cartes de ce genre (X.CARD_WEIGHTS[genre]) dans la zone de l'expédition :
-- part de rares multipliée par X.RARE_BY_ZONE (marchand, genre "shop" : X.SHOP_RARE_BY_ZONE), prise sur les
-- communes. Renvoie la table d'origine si le facteur vaut 1 (zone 1), sinon une copie.
function X.cardWeights(exp, kind)
  local m = byRank(kind == "shop" and X.SHOP_RARE_BY_ZONE or X.RARE_BY_ZONE, exp) or 1
  return moreRares(X.CARD_WEIGHTS[kind], m)
end

-- Poids de rareté des bibelots de l'étal (X.RELIC_WEIGHTS.normal, part de rares × X.SHOP_RELIC_RARE_BY_ZONE).
function X.shopRelicWeights(exp)
  return moreRares(X.RELIC_WEIGHTS.normal, byRank(X.SHOP_RELIC_RARE_BY_ZONE, exp) or 1)
end

-- Multiplicateur des prix de l'étal dans la zone de l'expédition (X.PRICE_BY_ZONE ; 1 à Westfall).
function X.priceFactor(exp)
  return byRank(X.PRICE_BY_ZONE, exp) or 1
end

-- Chance qu'une carte de l'étal soit vendue déjà améliorée dans la zone de l'expédition (X.SHOP_UPGRADED).
function X.shopUpgradeChance(exp)
  return byRank(X.SHOP_UPGRADED, exp) or 0
end

-- Palier d'une carte id vendue améliorée dans la zone de l'expédition (X.SHOP_UP_TIER, borné aux paliers écrits).
function X.shopUpgradeTier(exp, id)
  return min(byRank(X.SHOP_UP_TIER, exp) or 1, Card.tiers(id))
end

---------------------------------------------------------------------------
-- Crochets d'expédition des bibelots (relic.run) et des affixes (affix.run)
---------------------------------------------------------------------------

-- Règles de zone actives dans l'expédition (ns.ZoneRules : la zone de l'expédition, puis celles qui
-- portent always = true) : leurs crochets d'expédition `run` passent avant ceux des bibelots et affixes.
local function zoneRuns(exp)
  return ns.Combat.zoneRulesFor(exp.zone)
end

-- Talents appris de l'expédition (exp.talents, figés au départ : docs/talents.md) : leurs crochets d'expédition
-- (run) passent juste après ceux des bibelots, avec src = l'entrée du talent { id, rank, spec } en deuxième
-- argument : modify (exp, src, v, a, b, d), fire (exp, src, a, b, d).
local function talentModify(exp, name, v, a, b, d)
  local ts = exp.talents
  if not ts then return v end
  for i = 1, #ts do
    local r = ns.Talent.run(exp.class, ts[i])
    local h = r and r[name]
    if h then v = h(exp, ts[i], v, a, b, d) end
  end
  return v
end

local function talentFire(exp, name, a, b, d)
  local ts = exp.talents
  if not ts then return false end
  for i = 1, #ts do
    local r = ns.Talent.run(exp.class, ts[i])
    local h = r and r[name]
    if h and h(exp, ts[i], a, b, d) then return true end
  end
  return false
end

-- Valeur modifiée : chaque crochet reçoit (exp, v, a, b) et renvoie la nouvelle valeur.
-- Noms utilisés : gold (v, source), goldBonus (v, source : ajouts fixes, après tous les « gold »),
-- restFraction (v), restHeal (v), price (v, genre), removePrice (v : prix du retrait chez le marchand),
-- rewardCards (v = 3, genre : cartes offertes par une récompense de combat), zoneHeal (v = X.ZONE_HEAL : part des
-- PV max soignée au passage d'une zone), startMaxHp (v = PV de la classe), startGold (v = X.START_GOLD),
-- startEpics (v = 0 : épiques choisies au départ parmi celles des zones gagnées ; talents seulement, au départ),
-- startEpicOffer (v = 0 : toutes les épiques proposables ; k > 0 : k tirées au hasard parmi elles).
function X.modify(exp, name, v, a, b, d)
  local zr = zoneRuns(exp)
  if zr then
    for i = 1, #zr do
      local r = ns.ZoneRules[zr[i]]
      local h = r.run and r.run[name]
      if h then v = h(exp, v, a, b) end
    end
  end
  local relics = exp.relics
  for i = 1, #relics do
    local r = ns.Relics[relics[i]]
    local h = r and r.run and r.run[name]
    if h then v = h(exp, v, a, b) end
  end
  if exp.talents then v = talentModify(exp, name, v, a, b, d) end
  local affixes = exp.affixes
  for i = 1, #affixes do
    local af = ns.Affixes[affixes[i]]
    local h = af and af.run and af.run[name]
    if h then v = h(exp, v, a, b) end
  end
  return v
end

-- Notification : chaque crochet reçoit (exp, a, b) ; true arrête la chaîne.
-- Noms utilisés : onNodeEnter (nœud), onCombatWon (genre, exp.fight, état du combat terminé : c.player.res,
-- c.player.hp… ; les PV de l'expédition sont déjà ceux de la fin du combat), onRest, onRewardRolled (récompense,
-- genre : tirée à l'entrée de l'étape, modifiable), onFightStart (exp.fight, options du combat).
-- Bibelot « utile à cette classe » : champ `needs` (voir X.usefulFor), sinon toujours proposé.
function X.fire(exp, name, a, b, d)
  local zr = zoneRuns(exp)
  if zr then
    for i = 1, #zr do
      local r = ns.ZoneRules[zr[i]]
      local h = r.run and r.run[name]
      if h and h(exp, a, b) then return true end
    end
  end
  local relics = exp.relics
  for i = 1, #relics do
    local r = ns.Relics[relics[i]]
    local h = r and r.run and r.run[name]
    if h and h(exp, a, b) then return true end
  end
  if exp.talents and talentFire(exp, name, a, b, d) then return true end
  local affixes = exp.affixes
  for i = 1, #affixes do
    local af = ns.Affixes[affixes[i]]
    local h = af and af.run and af.run[name]
    if h and h(exp, a, b) then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- Tirages filtrés par les déblocages
---------------------------------------------------------------------------

-- Palier commun figé au départ : nombre de zones gagnées par le compte (ordre de la plus avancée).
local function commonTier(exp) return exp.unlock.common or 0 end

-- n ids distincts, rareté tirée selon weights parmi celles qui ont encore des candidats.
local function drawFrom(rng, ids, rarityOf, n, weights, taken)
  taken = taken or {}
  local out = {}
  while #out < n do
    local byR = {}
    for i = 1, #ids do
      local id = ids[i]
      if not taken[id] then
        local r = rarityOf(id)
        if (weights[r] or 0) > 0 then
          byR[r] = byR[r] or {}
          table.insert(byR[r], id)
        end
      end
    end
    local rs = {}
    for r in pairs(byR) do rs[#rs + 1] = r end
    if #rs == 0 then break end
    table.sort(rs)
    local r = Rng.weighted(rng, rs, function(x) return weights[x] end)
    local id = Rng.pick(rng, byR[r])
    taken[id] = true
    out[#out + 1] = id
  end
  return out
end

-- Déblocage d'une carte ou d'un bibelot pour cette expédition, d'après les déblocages figés au départ :
-- carte de zone (zone = id) : la classe a gagné cette zone ; bibelot de clé (key = { zone, level }) : la
-- classe a gagné cette zone à cette clé ou plus ; de classe : niveau de classe (level, absent = 1) ; le
-- reste (commun, neutre) : palier commun du compte (tier, absent = 0 ; docs/zones.md).
function X.unlocked(exp, def)
  local won = exp.unlock.won or {}
  if def.zone then return won[def.zone] ~= nil end
  if type(def.key) == "table" then return (won[def.key.zone] or -1) >= (def.key.level or 1) end
  if def.class then return (def.level or 1) <= exp.unlock.level end
  return (def.tier or 0) <= commonTier(exp)
end

-- Cartes de la classe jouée (neutral : cartes neutres comprises, réservées au marchand et aux
-- rencontres par le GDD). Jamais les épiques (X.epicPool) ni les variantes.
function X.cardPool(exp, neutral)
  local list = {}
  for id, d in pairs(ns.Cards) do
    if Card.inClass(d, exp.class, neutral) and d.rarity ~= "basic" and d.rarity ~= "epic" and not d.noReward
        and not d.variant and X.unlocked(exp, d) then
      list[#list + 1] = id
    end
  end
  table.sort(list)
  return list
end

-- Cartes neutres (sans classe, neutral = true) débloquées par le palier commun (champ tier) :
-- emplacement « Neutral » du marchand, choix de rencontre { "cardChoice", neutral = true }.
function X.neutralPool(exp)
  local list = {}
  for id, d in pairs(ns.Cards) do
    if d.class == nil and d.neutral and d.rarity ~= "basic" and d.rarity ~= "epic" and not d.variant
        and (d.tier or 0) <= commonTier(exp) then
      list[#list + 1] = id
    end
  end
  table.sort(list)
  return list
end

---------------------------------------------------------------------------
-- Cartes épiques
---------------------------------------------------------------------------

-- Index de la première carte épique du deck (la plus ancienne), ou nil.
function X.epicIndex(exp)
  local deck = exp.deck
  for i = 1, #deck do
    local d = ns.Cards[deck[i].id]
    if d and d.rarity == "epic" then return i end
  end
  return nil
end

-- Index des cartes épiques du deck, dans l'ordre du deck (la plus ancienne d'abord).
function X.epicIndices(exp)
  local list, deck = {}, exp.deck
  for i = 1, #deck do
    local d = ns.Cards[deck[i].id]
    if d and d.rarity == "epic" then list[#list + 1] = i end
  end
  return list
end

-- Nombre d'épiques du deck.
function X.epicCount(exp)
  local n, deck = 0, exp.deck
  for i = 1, #deck do
    local d = ns.Cards[deck[i].id]
    if d and d.rarity == "epic" then n = n + 1 end
  end
  return n
end

-- Plafond d'épiques dans le deck (X.EPIC.max ; nil ou 0 = sans plafond : math.huge).
function X.epicMax()
  local m = X.EPIC.max
  if not m or m <= 0 then return math.huge end
  return m
end

-- Le deck est-il au plafond (une épique de plus en remplacerait une) ?
function X.epicFull(exp)
  return X.epicCount(exp) >= X.epicMax()
end

-- Épiques proposables : de la classe jouée, débloquées (carte de zone : la classe a gagné la zone), hors
-- variantes, hors celles du deck et hors celles déjà obtenues dans l'expédition (exp.epicTaken : une épique
-- remplacée ou retirée ne retombe pas). Triées.
function X.epicPool(exp)
  local have = {}
  for _, i in ipairs(X.epicIndices(exp)) do have[exp.deck[i].id] = true end
  local taken = exp.epicTaken or {}
  local list = {}
  for id, d in pairs(ns.Cards) do
    if d.rarity == "epic" and d.class == exp.class and not d.variant and not have[id] and not taken[id]
        and X.unlocked(exp, d) then
      list[#list + 1] = id
    end
  end
  table.sort(list)
  return list
end

-- Flux de hasard des épiques (créé au besoin : une expédition d'avant les épiques n'en a pas).
local function epicRng(exp)
  local r = exp.rng.epic
  if not r then
    r = Rng.stream(exp.seed or 1, "epic")
    exp.rng.epic = r
  end
  return r
end

-- n épiques distinctes tirées dans pool (toutes si elles sont n ou moins), dans l'ordre du tirage.
local function drawEpics(rng, pool, n)
  local list = {}
  for i = 1, #pool do list[i] = pool[i] end
  if #list > n then
    Rng.shuffle(rng, list)
    for i = #list, n + 1, -1 do list[i] = nil end
  end
  return list
end

-- Deck tel qu'il se joue (transformations de l'épique appliquées, Card.applyTransforms) : affichage.
function X.shownDeck(exp)
  return Card.applyTransforms(exp.deck)
end

-- Une carte neutre est-elle débloquée pour cette expédition ? (condition de rencontre « unlocked »)
function X.cardUnlocked(exp, id)
  local d = ns.Cards[id]
  if not d then return false end
  return X.unlocked(exp, d)
end

local function cardRarity(id) return ns.Cards[id].rarity end

local function drawCards(exp, rng, n, weights, neutral)
  local pool = X.cardPool(exp, neutral)
  local out = drawFrom(rng, pool, cardRarity, n, weights)
  if #out == 0 then out = drawFrom(rng, pool, cardRarity, n, X.CARD_WEIGHTS.combat) end
  return out
end

local function drawNeutral(exp, rng, n, weights)
  local pool = X.neutralPool(exp)
  local out = drawFrom(rng, pool, cardRarity, n, weights)
  if #out == 0 then out = drawFrom(rng, pool, cardRarity, n, X.CARD_WEIGHTS.combat) end
  return out
end

-- La classe a-t-elle des cartes de ce genre ? key : "cast", "cooldown", "exhaust", "retain",
-- "attack" (type), "absorb", "damage", "castDamage" (effet ; Cast qui inflige des dégâts).
function X.classHas(class, key)
  local v = false
  for _, d in pairs(ns.Cards) do
    if d.class == class then
      if key == "attack" then
        if d.type == "attack" then v = true end
      elseif key == "absorb" or key == "damage" or key == "castDamage" then
        for _, e in ipairs(d.effects or {}) do
          if (key == "absorb" and e[1] == "absorb") or (key == "damage" and e[1] == "damage")
              or (key == "castDamage" and d.cast and e[1] == "damage") then v = true end
        end
      elseif d[key] then
        v = true
      end
    end
    if v then break end
  end
  return v
end

-- Bibelot utile à la classe jouée : champ `needs` absent, une clé de X.classHas (« cast »), une liste
-- de clés (toutes requises) ou une fonction(classe) -> booléen. Un bibelot inutile n'est jamais proposé.
function X.usefulFor(r, class)
  local n = r.needs
  if not n then return true end
  if type(n) == "function" then return n(class) and true or false end
  if type(n) == "string" then return X.classHas(class, n) end
  for i = 1, #n do
    if not X.classHas(class, n[i]) then return false end
  end
  return true
end

-- Bibelots proposables : tier débloqué, pas déjà possédés, communs (sans champ class) ou de la
-- classe jouée, utiles à cette classe (needs) ; jamais ceux marqués noPool (bibelot de départ,
-- bibelots de rencontre).
function X.relicPool(exp)
  local owned = {}
  for i = 1, #exp.relics do owned[exp.relics[i]] = true end
  local list = {}
  for id, r in pairs(ns.Relics) do
    if not owned[id] and (not r.class or r.class == exp.class) and not r.noPool and X.unlocked(exp, r)
        and X.usefulFor(r, exp.class) then
      list[#list + 1] = id
    end
  end
  table.sort(list)
  return list
end

local function relicRarity(id) return ns.Relics[id].rarity or "common" end

local function drawRelics(exp, rng, n, weights, taken)
  return drawFrom(rng, X.relicPool(exp), relicRarity, n, weights, taken)
end

function X.potionPool(exp)
  local list = {}
  for id, p in pairs(ns.Potions) do
    if not p.noPool and (p.tier or 0) <= commonTier(exp) then list[#list + 1] = id end
  end
  table.sort(list)
  return list
end

local function potionRarity(id) return ns.Potions[id].rarity or "common" end

local function drawPotions(exp, rng, n)
  return drawFrom(rng, X.potionPool(exp), potionRarity, n, X.POTION_WEIGHTS)
end

-- Une potion tirée (rng : flux de l'état, par défaut exp.rng.loot), ou nil.
function X.randomPotion(exp, rng)
  return drawPotions(exp, rng or exp.rng.loot, 1)[1]
end


---------------------------------------------------------------------------
-- Gains et pertes
---------------------------------------------------------------------------

function X.gainGold(exp, n, source)
  -- pourcentages d'abord (gold), puis ajouts fixes (goldBonus : Bloodsail Admiral's Hat)
  n = floor(X.modify(exp, "goldBonus", X.modify(exp, "gold", n, source), source) + 0.5)
  if n < 0 then n = 0 end
  exp.gold = exp.gold + n
  exp.stats.goldEarned = exp.stats.goldEarned + n
  return n
end

local function spend(exp, n)
  exp.gold = exp.gold - n
  exp.stats.goldSpent = exp.stats.goldSpent + n
end

function X.gainRelic(exp, id)
  exp.relics[#exp.relics + 1] = id
  local r = ns.Relics[id]
  if r and r.run and r.run.onPickup then r.run.onPickup(exp) end
  if exp.hp > exp.maxHp then exp.hp = exp.maxHp end
end

function X.freeSlot(exp)
  for i = 1, #exp.potions do
    if not exp.potions[i] then return i end
  end
  return nil
end

function X.gainPotion(exp, id)
  local s = X.freeSlot(exp)
  if not s then return false end
  exp.potions[s] = id
  return true
end

-- Un emplacement de potion de plus pour l'expédition (Herb Pouch) : le nombre d'emplacements est la
-- longueur de exp.potions (3 au départ, X.POTION_SLOTS), transmise au combat (Combat.new).
function X.addPotionSlot(exp)
  exp.potions[#exp.potions + 1] = false
end

-- Ajoute une carte au deck. Une épique au plafond (X.EPIC.max) remplace la plus ancienne du deck : elle part,
-- améliorée ou non (stats.epicReplaced, exp.epicReplaced = { old, new } pour l'affichage) ; l'épique ajoutée
-- est notée obtenue (exp.epicTaken[id] : elle ne retombera pas). noCap : sans plafond (épiques imposées).
function X.addCard(exp, id, up, noCap)
  local d = ns.Cards[id]
  if d and d.rarity == "epic" then
    while not noCap and X.epicFull(exp) do
      local old = table.remove(exp.deck, X.epicIndex(exp))
      exp.stats.epicReplaced = (exp.stats.epicReplaced or 0) + 1
      exp.epicReplaced = { old = old.id, oldUp = old.up, new = id }
    end
    exp.epicTaken = exp.epicTaken or {}
    exp.epicTaken[id] = true
  end
  -- up : palier gardé (copie d'une carte : dupe), true = palier 1 (carte offerte « améliorée » : rencontre
  -- { "card", id, up = true }, marchand), borné aux paliers écrits de la carte
  local n = math.min(Card.level(up), Card.tiers(id))
  exp.deck[#exp.deck + 1] = { id = id, up = Card.upValue(n) }
  exp.stats.cardsAdded = exp.stats.cardsAdded + 1
end

-- Une carte du deck peut monter d'un palier : son palier suivant est écrit (Card.tiers) et elle est sous
-- le palier 3 (docs/ameliorations.md).
function X.canUpgrade(exp, i)
  local card = exp.deck[i]
  return card ~= nil and ns.Cards[card.id] ~= nil and Card.canUp(card.id, card.up)
end

-- Raison du refus d'amélioration de la carte i : "maxed" (dernier palier écrit atteint), "noUpgrade" (carte
-- sans amélioration), sinon "badCard".
function X.upgradeRefusal(exp, i)
  local card = exp.deck[i]
  if not card or not ns.Cards[card.id] then return "badCard" end
  if Card.tiers(card.id) == 0 then return "noUpgrade" end
  if not Card.canUp(card.id, card.up) then return "maxed" end
  return "badCard"
end

-- Monte la carte i d'un palier (stats.upgraded : toutes les améliorations ; stats.upTiers[n] : celles qui
-- ont atteint le palier n).
local function upgrade(exp, i)
  local n = Card.level(exp.deck[i]) + 1
  exp.deck[i].up = n
  exp.stats.upgraded = exp.stats.upgraded + 1
  local t = exp.stats.upTiers or {}
  exp.stats.upTiers = t
  t[n] = (t[n] or 0) + 1
end

-- Soin hors combat (repos, rencontres, passage d'une zone à l'autre) : crochet healOut (v) des zones,
-- bibelots, affixes (Cursed Eye of Paleth : divisé par deux).
local function heal(exp, n)
  n = floor(X.modify(exp, "healOut", n))
  local before = exp.hp
  exp.hp = min(exp.maxHp, exp.hp + max(0, n))
  return exp.hp - before
end
-- Soin hors combat (crochet healOut compris) : talents de fin de combat (Second Wind). Renvoie les PV rendus.
X.healOut = heal

-- Prix du retrait (crochet removePrice : Darkmoon Faire Prize Ticket) ; exp.shop.removed = retraits
-- faits pendant la visite en cours du marchand.
function X.removePrice(exp)
  return max(0, floor(X.modify(exp, "removePrice", X.REMOVE_PRICE + X.REMOVE_STEP * exp.removals) + 0.5))
end

---------------------------------------------------------------------------
-- Déroulé
---------------------------------------------------------------------------

-- Zone de l'expédition (ns.Zones) : ses groupes de combats (encounters), son nom.
function X.zoneDef(exp) return ns.Zones[exp.zone or ns.Zone.FIRST] end
local actDef = X.zoneDef

-- État d'expédition propre à une zone (données simples, sauvegardées) : exp.zs[id], créé au besoin
-- (affiche WANTED posée sur une élite, boissons achetées…).
function X.zoneState(exp, id)
  exp.zs = exp.zs or {}
  local s = exp.zs[id or exp.zone]
  if not s then
    s = {}
    exp.zs[id or exp.zone] = s
  end
  return s
end

local function finish(exp, result)
  exp.result = result
  exp.phase = "done"
  exp.combat, exp.fight, exp.reward, exp.shop, exp.event, exp.select = nil, nil, nil, nil, nil, nil
end

-- Cases de parcours déclarées par les zones (Gryphon Master, Gurubashi Arena, Grim Guzzler…) :
-- X.NODE_KINDS[genre] = { name (affiché), tier = palier commun qui la débloque (0 : d'emblée),
--   zone = id (seulement dans cette zone ; nil : toutes les zones une fois débloquée),
--   event = id de rencontre ouverte à l'entrée (la rencontre porte node = true : jamais tirée au hasard),
--   enter = f(exp, nœud) (à la place d'event : doit poser exp.phase), replaces = { genres remplaçables }
--   (défaut { "event" }), minFloor (3), maxFloor (Map.FLOORS - 1), chance (1 : probabilité par carte),
--   count (1 : cases au plus par carte) }.
-- Placées après le tirage de la carte (flux à part, « nodes:<acte> » : la carte d'une zone sans case
-- nouvelle ne change pas), en remplaçant des nœuds existants ; ordre : par genre trié.
X.NODE_KINDS = {}

function X.nodeKind(kind, def)
  def.kind = kind
  X.NODE_KINDS[kind] = def
  Map.KINDS[kind] = def.name or kind
  return def
end

-- Cases débloquées pour cette expédition.
function X.nodeKindsFor(exp)
  local list = {}
  for kind, def in pairs(X.NODE_KINDS) do
    if (def.tier or 0) <= commonTier(exp) and (def.zone == nil or def.zone == exp.zone) then list[#list + 1] = kind end
  end
  table.sort(list)
  return list
end

local function placeNodeKinds(exp)
  local kinds = X.nodeKindsFor(exp)
  if #kinds == 0 then return end
  local rng = Rng.stream(exp.seed, "nodes:" .. tostring(exp.act))
  for _, kind in ipairs(kinds) do
    local def = X.NODE_KINDS[kind]
    if Rng.float(rng) < (def.chance or 1) then
      local repl = {}
      for _, k in ipairs(def.replaces or { "event" }) do repl[k] = true end
      for _ = 1, (def.count or 1) do
        local cands = {}
        for _, node in ipairs(exp.map.nodes) do
          if repl[node.kind] and node.floor >= (def.minFloor or 3) and node.floor <= (def.maxFloor or Map.FLOORS - 1) then
            cands[#cands + 1] = node
          end
        end
        if #cands == 0 then break end
        local node = cands[Rng.int(rng, 1, #cands)]
        node.base = node.kind
        node.kind = kind
      end
    end
  end
end
X.placeNodeKinds = placeNodeKinds

-- Carte de la zone en cours (exp.zone), act = rang de la zone dans l'expédition. Graine : la première zone tire
-- dans le flux « map » de l'état (cartes de Westfall inchangées) ; les suivantes dans un flux dérivé de la graine
-- de l'expédition et de la zone (« map:<zone> ») : la carte d'une zone ne dépend pas de ce qui s'est passé avant.
local function startAct(exp, act)
  exp.act = act
  local rng = act <= 1 and exp.rng.map or Rng.stream(exp.seed, "map:" .. tostring(exp.zone))
  exp.map = Map.generate(rng, act)
  placeNodeKinds(exp)
  exp.node = nil
  exp.path = {} -- nœuds visités dans l'acte, dans l'ordre (chemin parcouru, pour l'affichage)
  exp.floor = 0
  exp.combatsInAct = 0
  exp.lastEnc = {}
  exp.skip = nil
  exp.phase = "map"
end

-- Zone qui suit la zone en cours dans cette expédition (nil : la zone en cours est la dernière, ou la suivante
-- n'est pas jouable).
function X.nextZone(exp)
  if exp.zone == (exp.lastZone or ns.Zone.ORDER[#ns.Zone.ORDER]) then return nil end
  local nx = ns.Zone.next(exp.zone)
  if nx and ns.Zone.playable(nx) then return nx end
  return nil
end

-- Boss de la zone battu, récompense prise : passage à la zone suivante. Même deck, bibelots, or, potions,
-- épique, PV max ; soin de X.ZONE_HEAL des PV max (crochet healOut) ; nouvelle carte ; la règle de zone, les
-- ennemis, rencontres, décors et marchand deviennent ceux de la nouvelle zone (tout lit exp.zone). Phase
-- « transit » : l'écran annonce la zone et le soin, { "continue" } mène à la carte.
local function enterZone(exp, zone)
  local from = exp.zone
  exp.zone = zone
  startAct(exp, (exp.act or 1) + 1)
  local healed = heal(exp, floor(exp.maxHp * X.modify(exp, "zoneHeal", X.ZONE_HEAL)))
  exp.transit = { from = from, to = zone, healed = healed }
  exp.phase = "transit"
end
-- Passage à la zone `zone` (phase « transit ») : appelé à la sortie du boss ; les tests et le harnais
-- d'interface s'en servent pour amener une expédition dans une zone plus loin.
X.enterZone = enterZone

local function clearNode(exp)
  if not exp.nodeCleared then
    exp.nodeCleared = true
    exp.stats.cleared = exp.stats.cleared + 1
  end
end

local function leaveNode(exp)
  clearNode(exp)
  exp.reward, exp.shop, exp.event, exp.select = nil, nil, nil, nil
  local node = exp.map.nodes[exp.node]
  if node.kind == "boss" then
    local nx = X.nextZone(exp)
    if nx then
      enterZone(exp, nx)
    else
      finish(exp, "won")
    end
  else
    exp.phase = "map"
  end
end

-- Poids de rareté décalés d'un cran vers le haut (commune -> inhabituelle, inhabituelle -> rare) :
-- récompense « une rareté au-dessus » (Gurubashi Arena).
function X.shiftWeights(w, n)
  local out = { common = w.common or 0, uncommon = w.uncommon or 0, rare = w.rare or 0 }
  for _ = 1, (n or 1) do
    out = { common = 0, uncommon = out.common, rare = out.uncommon + out.rare }
  end
  return out
end

-- Récompense tirée à l'entrée de l'étape. genre : combat | elite | boss | chest.
-- opts (combats de rencontre, cases de zone) : cards = nombre de cartes offertes, shift = crans de rareté
-- en plus. Crochet rewardCards (v = 3, genre) ; notification onRewardRolled (récompense, genre).
local function rollReward(exp, kind, opts)
  local rng = exp.rng.loot
  local r = { kind = kind }
  local g = X.GOLD[kind]
  if g and kind ~= "chest" then r.gold = Rng.int(rng, g[1], g[2]) end
  if kind ~= "chest" then
    local n = X.modify(exp, "rewardCards", opts and opts.cards or 3, kind)
    local w = X.cardWeights(exp, kind)
    if opts and opts.shift then w = X.shiftWeights(w, opts.shift) end
    r.cards = drawCards(exp, rng, n, w)
  end
  if kind == "elite" or kind == "chest" then
    r.relic = drawRelics(exp, rng, 1, X.RELIC_WEIGHTS.normal)[1]
  elseif kind == "boss" then
    r.relic = drawRelics(exp, rng, 1, X.RELIC_WEIGHTS.boss)[1]
  end
  if kind == "chest" and not r.relic then r.gold = Rng.int(rng, g[1], g[2]) end
  if (kind == "combat" or kind == "elite") and Rng.float(rng) < X.POTION_DROP then
    r.potion = drawPotions(exp, rng, 1)[1]
  end
  X.fire(exp, "onRewardRolled", r, kind)
  return r
end
X.rollReward = rollReward

local function openReward(exp, r)
  if r.gold and r.gold > 0 then r.goldGained = X.gainGold(exp, r.gold, r.kind) end
  if r.relic then
    X.gainRelic(exp, r.relic)
    r.relicTaken = true
  end
  if r.potion then r.potionTaken = X.gainPotion(exp, r.potion) end
  r.cardsDone = not (r.cards and #r.cards > 0)
  exp.reward = r
  exp.phase = "reward"
end
X.openReward = openReward
X.leaveNode = function(exp) return leaveNode(exp) end

-- Ids d'un groupe (entrées « id » ou spec { id, st = … }, Combat.spawn).
local function groupIds(group)
  local ids = {}
  for i = 1, #group do ids[i] = Combat.specId(group[i]) end
  return ids
end
X.groupIds = groupIds

-- Offre d'épique : choix « Epic » ajouté à la récompense r (r.epics, r.epicDone) s'il reste une épique à
-- proposer (tirée par le flux « epic » ; n = X.EPIC.choices par défaut). Renvoie vrai si l'offre est faite.
function X.offerEpic(exp, r, n)
  local pool = X.epicPool(exp)
  if #pool == 0 or (n or X.EPIC.choices) <= 0 then return false end
  r.epics = drawEpics(epicRng(exp), pool, n or X.EPIC.choices)
  r.epicDone = false
  return true
end

-- Chance qu'une victoire de ce genre fasse tomber une épique dans la zone de l'expédition (X.EPIC.drop).
function X.epicDropChance(exp, kind)
  return byRank(X.EPIC.drop[kind], exp) or 0
end

-- Chute d'épique après une victoire de ce genre (X.EPIC.drop) : tirage par le flux « epic », puis l'offre
-- (X.offerEpic) dans la récompense r. Sans épique proposable ou à chance nulle : aucun tirage. Renvoie vrai
-- si une épique est proposée.
function X.rollEpicDrop(exp, r, kind)
  local p = X.epicDropChance(exp, kind)
  if p <= 0 or #X.epicPool(exp) == 0 then return false end
  if Rng.float(epicRng(exp)) >= p then return false end
  return X.offerEpic(exp, r)
end

local function endFight(exp)
  local c, f = exp.combat, exp.fight
  local p = c.player
  exp.hp = max(0, p.hp)
  exp.maxHp = p.maxHp
  if p.potions then exp.potions = U.copy(p.potions) end
  -- état d'expédition des talents (« une fois par expédition », Rage gardée) : repris du combat
  if c.tstate then exp.talentState = U.copy(c.tstate) end
  exp.combat, exp.fight = nil, nil
  if c.result == "won" then
    clearNode(exp)
    if f.kind == "elite" then exp.stats.elites = exp.stats.elites + 1 end
    if f.kind == "boss" then
      exp.stats.bosses = exp.stats.bosses + 1
      -- boss de la zone battu : compté tout de suite (Meta.bank : épique, commun, expérience, drapeaux),
      -- même si l'expédition échoue plus loin
      exp.beaten = exp.beaten or {}
      exp.beaten[#exp.beaten + 1] = exp.zone
    end
    X.fire(exp, "onCombatWon", f.kind, f, c)
    X.rollEpicDrop(exp, f.reward, f.kind)
    openReward(exp, f.reward)
  else
    exp.killedBy = table.concat(groupIds(f.encounter), "+")
    finish(exp, "lost")
  end
end

-- genre : combat | elite | boss ; pool : groupe de ns.Encounters (sinon déduit) ;
-- reward : récompense déjà tirée (sinon tirée maintenant) ; extra (rencontres, cases de zone) :
-- { idx = groupe déjà tiré, mods = { st, hpMul } (Combat.new) }. Le combat reçoit la zone et le genre
-- (règles de zone), et exp.nextCombat (effets de départ : boissons du Grim Guzzler), consommé.
local function startFight(exp, kind, pool, reward, extra)
  local pools = ns.Encounters[actDef(exp).encounters]
  if not pool then
    if kind == "combat" then
      pool = exp.combatsInAct < X.EASY_COMBATS and "easy" or "normal"
    else
      pool = kind
    end
  end
  if kind == "combat" then exp.combatsInAct = exp.combatsInAct + 1 end
  local list = pools[pool]
  local rng = exp.rng.combat
  local idx = extra and extra.idx
  if not idx then
    for _ = 1, 5 do
      idx = Rng.int(rng, 1, #list)
      if idx ~= exp.lastEnc[pool] then break end
    end
  end
  exp.lastEnc[pool] = idx
  local seed = Rng.int(rng, 1, 2147483646)
  exp.fight = { kind = kind, pool = pool, encounter = groupIds(list[idx]), seed = seed,
    reward = reward or rollReward(exp, kind) }
  exp.stats.combats = exp.stats.combats + 1
  exp.phase = "combat"
  local opts = { seed = seed, class = exp.class, hp = exp.hp, maxHp = exp.maxHp, deck = exp.deck,
    encounter = list[idx], relics = exp.relics, potions = U.copy(exp.potions), affixes = exp.affixes,
    stats = exp.combatStats, quiet = exp.quiet, zone = exp.zone, kind = kind,
    mods = extra and extra.mods or nil, start = exp.nextCombat,
    -- talents figés au départ (copies : l'état du combat est sauvegardé dans exp, sans table partagée)
    talents = exp.talents and U.copy(exp.talents) or nil,
    tstate = exp.talents and U.copy(exp.talentState or {}) or nil }
  exp.nextCombat = nil
  X.fire(exp, "onFightStart", exp.fight, opts)
  exp.combat = Combat.new(opts)
  if exp.combat.result then endFight(exp) end
end
-- Pour une case de zone qui lance un combat elle-même (X.NODE_KINDS[genre].enter) :
-- X.startFight(exp, genre, groupe, récompense|nil, { idx, mods }) ; X.rollReward(exp, genre, { cards, shift }).
X.startFight = startFight

local function openShop(exp)
  local rng = exp.rng.merchant
  -- prix : base × rang de zone (X.PRICE_BY_ZONE) × amélioration (X.UPGRADED_PRICE) ± X.PRICE_JITTER, puis le
  -- crochet « price » des bibelots ; à Westfall (facteur 1), le calcul d'origine
  local factor = X.priceFactor(exp)
  local function price(base, kind, up)
    local p = base * factor * (Card.level(up) > 0 and X.UPGRADED_PRICE or 1)
      * (1 - X.PRICE_JITTER + 2 * X.PRICE_JITTER * Rng.float(rng))
    p = X.modify(exp, "price", p, kind)
    return max(1, floor(p + 0.5))
  end
  -- carte vendue déjà améliorée (X.SHOP_UPGRADED) : tirée avant son prix, jamais si la chance est nulle ; renvoie
  -- son palier (X.shopUpgradeTier) ou false
  local upChance = X.shopUpgradeChance(exp)
  local function rollUp(id)
    if upChance > 0 and Card.tiers(id) > 0 and Rng.float(rng) < upChance then return X.shopUpgradeTier(exp, id) end
    return false
  end
  local shop = { cards = {}, relics = {}, potions = {}, removed = 0 }
  local shopWeights = X.cardWeights(exp, "shop")
  local cards = drawCards(exp, rng, X.SHOP.cards, shopWeights, false)
  for i = 1, #cards do
    local base = X.PRICES.card[ns.Cards[cards[i]].rarity] or X.PRICES.card.uncommon
    local up = rollUp(cards[i])
    shop.cards[i] = { id = cards[i], price = price(base, "card", up), sold = false, up = up or nil }
  end
  -- emplacement « Neutral » : en plus des cartes de classe, à la suite (neutral = true)
  local neutral = drawNeutral(exp, rng, X.SHOP.neutral, shopWeights)
  for i = 1, #neutral do
    local base = X.PRICES.neutral[ns.Cards[neutral[i]].rarity] or X.PRICES.neutral.uncommon
    local up = rollUp(neutral[i])
    shop.cards[#shop.cards + 1] = { id = neutral[i], price = price(base, "card", up), sold = false, neutral = true,
      up = up or nil }
  end
  local nRelics = X.SHOP.relics + (commonTier(exp) >= ns.Meta.PERKS.merchantRelic and 1 or 0)
  local relics = drawRelics(exp, rng, nRelics, X.shopRelicWeights(exp))
  for i = 1, #relics do
    local base = X.PRICES.relic[relicRarity(relics[i])] or X.PRICES.relic.uncommon
    shop.relics[i] = { id = relics[i], price = price(base, "relic"), sold = false }
  end
  local potions = drawPotions(exp, rng, X.SHOP.potions)
  for i = 1, #potions do
    local base = X.PRICES.potion[potionRarity(potions[i])] or X.PRICES.potion.common
    shop.potions[i] = { id = potions[i], price = price(base, "potion"), sold = false }
  end
  -- épique (X.EPIC) : à partir de la moitié du parcours, une chance, à la suite des cartes (epic = true) ;
  -- flux « epic » : les autres tirages du marchand ne changent pas
  local node = X.currentNode(exp)
  if X.EPIC.shop > 0 and node and node.floor >= X.EPIC.shopFloor then
    local pool = X.epicPool(exp)
    if #pool > 0 then
      local erng = epicRng(exp)
      if Rng.float(erng) < X.EPIC.shop then
        local id = Rng.pick(erng, pool)
        local p = X.EPIC.price * factor * (1 - X.PRICE_JITTER + 2 * X.PRICE_JITTER * Rng.float(erng))
        p = max(1, floor(X.modify(exp, "price", p, "card") + 0.5))
        shop.cards[#shop.cards + 1] = { id = id, price = p, sold = false, epic = true }
      end
    end
  end
  exp.shop = shop
  exp.phase = "merchant"
end

-- Rencontres -------------------------------------------------------------------
-- Familles : common (ordinaire), rare (poids faible), story (une fois par compte, drapeau
-- « event:<id> » posé à l'entrée). Conditions `when` (rencontre et réponse) : liste de
-- conditions toutes requises, voir X.CONDITIONS. Effets : voir Data/Events.lua.

local function pct(f) return floor(f * 100 + 0.5) end

local function hasRelic(exp, id)
  for i = 1, #exp.relics do
    if exp.relics[i] == id then return true end
  end
  return false
end

local function hasPotion(exp)
  for i = 1, #exp.potions do
    if exp.potions[i] then return true end
  end
  return false
end

local function relicLabel(id)
  local r = ns.Relics[id]
  return r and r.name or tostring(id)
end

-- Drapeaux de compte connus au départ de l'expédition (les nouveaux ne comptent qu'à la suivante).
function X.hasFlag(exp, name)
  return exp.flags ~= nil and exp.flags[name] == true
end

-- Pose un drapeau de compte : reporté dans la méta en fin d'expédition (Meta.record).
function X.setFlag(exp, name)
  exp.newFlags = exp.newFlags or {}
  exp.newFlags[name] = true
end

-- Conditions : CONDITIONS[nom] = { test(exp, arg, c) -> booléen, text(arg, c) -> raison affichée }.
-- Une condition s'écrit { "nom", arg } ; c.text remplace la raison par défaut.
X.CONDITIONS = {
  hpBelow = { -- PV strictement sous la fraction arg des PV max
    test = function(exp, f) return exp.hp < exp.maxHp * f end,
    text = function(f) return ("Only below %d%% HP."):format(pct(f)) end },
  hpAbove = { -- PV au moins égaux à la fraction arg des PV max
    test = function(exp, f) return exp.hp >= exp.maxHp * f end,
    text = function(f) return ("Requires at least %d%% HP."):format(pct(f)) end },
  gold = {
    test = function(exp, n) return exp.gold >= n end,
    text = function(n) return ("Requires %dg."):format(n) end },
  relic = {
    test = function(exp, id) return hasRelic(exp, id) end,
    text = function(id) return "Requires: " .. relicLabel(id) .. "." end },
  noRelic = {
    test = function(exp, id) return not hasRelic(exp, id) end,
    text = function(id) return "Already owned: " .. relicLabel(id) .. "." end },
  potion = {
    test = function(exp) return hasPotion(exp) end,
    text = function() return "Requires a potion." end },
  card = {
    test = function(exp, id)
      for i = 1, #exp.deck do
        if exp.deck[i].id == id then return true end
      end
      return false
    end,
    text = function(id)
      local d = ns.Cards[id]
      return "Requires the card " .. (d and d.name or tostring(id)) .. "."
    end },
  key = {
    test = function(exp, n) return (exp.key or 0) >= n end,
    text = function(n) return ("Mythic Keystone +%d or higher."):format(n) end },
  flag = {
    test = function(exp, name) return X.hasFlag(exp, name) end,
    text = function() return "Not yet." end },
  noFlag = {
    test = function(exp, name) return not X.hasFlag(exp, name) end,
    text = function() return "Not anymore." end },
  floor = { -- étape courante (celle du nœud) au moins égale à arg
    test = function(exp, n) return (exp.floor or 0) >= n end,
    text = function(n) return ("From stage %d onward."):format(n) end },
  unlocked = { -- carte débloquée (neutre : palier commun) ; avec hide = true, réponse absente sinon
    test = function(exp, id) return X.cardUnlocked(exp, id) end,
    text = function(id)
      local d = ns.Cards[id]
      return "Not yet unlocked: " .. (d and d.name or tostring(id)) .. "."
    end },
}

-- Réponse cachée tant qu'une de ses conditions marquées hide = true n'est pas remplie (au lieu d'être
-- grisée avec sa raison) : { "unlocked", id, hide = true }.
function X.choiceHidden(exp, ch)
  for _, c in ipairs(ch.when or {}) do
    if c.hide then
      local def = X.CONDITIONS[c[1]]
      if def and not def.test(exp, c[2], c) then return true end
    end
  end
  return false
end

-- Toutes les conditions de la liste sont-elles remplies ? (true | false, raison)
function X.check(exp, when)
  if not when then return true end
  for i = 1, #when do
    local c = when[i]
    local def = X.CONDITIONS[c[1]]
    if not def then error("unknown encounter condition: " .. tostring(c[1])) end
    if not def.test(exp, c[2], c) then return false, c.text or def.text(c[2], c) end
  end
  return true
end

function X.eventFamily(ev) return ev.rarity or "common" end

function X.eventWeight(ev)
  return ev.weight or X.EVENT_WEIGHT[X.eventFamily(ev)] or X.EVENT_WEIGHT.common
end

-- Drapeau « déjà vue » d'une rencontre unique par compte (nil si elle peut revenir).
function X.onceFlag(id)
  local ev = ns.Events[id]
  if not ev or not ev.once then return nil end
  if type(ev.once) == "string" then return ev.once end
  return "event:" .. id
end

-- Rencontres possibles maintenant : zone (champ zone, nil = toutes), palier commun, pas déjà vue (expédition ou
-- compte pour les uniques), conditions de déclenchement remplies.
function X.eventPool(exp)
  local list = {}
  for id, ev in pairs(ns.Events or {}) do
    -- node = vrai : rencontre ouverte seulement par sa case de parcours (X.NODE_KINDS), jamais tirée
    if not ev.node and (ev.zone == nil or ev.zone == exp.zone) and (ev.tier or 0) <= commonTier(exp)
        and not exp.seenEvents[id] then
      local once = X.onceFlag(id)
      if not (once and X.hasFlag(exp, once)) and X.check(exp, ev.when) then
        list[#list + 1] = id
      end
    end
  end
  table.sort(list)
  return list
end

-- Effets de rencontre ajoutés par une zone (ou un autre fichier) sans toucher à ce fichier :
-- X.EFFECTS[nom] = { roll = f(exp, rng, e) -> tirage figé à l'entrée (facultatif),
--                    check = f(exp, e) -> ok, raison (facultatif : réponse grisée sinon),
--                    apply = f(exp, e, tirage, ctx) (ctx.reward = récompense à ouvrir, ctx.texts) }.
-- Effets génériques fournis ici : nextCombat (effets du prochain combat), skipFloors (vol : sauter une étape).
X.EFFECTS = {}

-- { "nextCombat", { effets de carte } } : résolus au début du prochain combat (Combat.new, opts.start ;
-- « Next combat: start with Strength 2 » = { "apply", "force", 2, self = true }).
X.EFFECTS.nextCombat = {
  apply = function(exp, e)
    exp.nextCombat = exp.nextCombat or {}
    for _, fx in ipairs(e[2] or {}) do exp.nextCombat[#exp.nextCombat + 1] = U.copy(fx) end
  end,
}

-- { "skipFloors", n } : la prochaine étape choisie sur la carte est à n + 1 étapes (Gryphon Master :
-- « Fly ahead ») ; les nœuds atteignables sont ceux reliés aux nœuds sautés (X.nextNodes).
X.EFFECTS.skipFloors = {
  check = function(exp, e)
    local node = exp.node and exp.map.nodes[exp.node]
    if not node then return true end
    if node.floor + (e[2] or 1) + 1 >= exp.map.floors then return false, "Too close to the boss." end
    return true
  end,
  apply = function(exp, e) exp.skip = e[2] or 1 end,
}

-- { "chain", id } : après cette réponse, la rencontre id s'ouvre à la place (deuxième étape d'une même
-- case : la boisson achetée du Grim Guzzler après la boisson offerte).
X.EFFECTS.chain = {
  apply = function(exp, e, roll, ctx) ctx.follow = { kind = "event", id = e[2] } end,
}

-- Nœuds accessibles maintenant : successeurs du nœud courant ; après un vol (exp.skip = n), les
-- successeurs des nœuds sautés, n étapes plus loin.
function X.nextNodes(exp)
  local list = Map.nextNodes(exp.map, exp.node)
  local skip = exp.skip or 0
  for _ = 1, skip do
    local seen, nx = {}, {}
    for _, id in ipairs(list) do
      for _, n2 in ipairs(exp.map.nodes[id].next) do
        if not seen[n2] then seen[n2] = true nx[#nx + 1] = n2 end
      end
    end
    table.sort(nx)
    if #nx == 0 then break end
    list = nx
  end
  return list
end

-- Groupe d'un combat de rencontre tiré à l'entrée (fight avec group = true) : { pool, idx, names }.
local function rollGroup(exp, rng, e)
  local pools = ns.Encounters[actDef(exp).encounters]
  local pool = e[2] or (e.kind == "elite" and "elite" or "normal")
  local list = pools and pools[pool]
  if not list or #list == 0 then return nil end
  local idx = Rng.int(rng, 1, #list)
  local names = {}
  for i, spec in ipairs(list[idx]) do
    local d = ns.Enemies[Combat.specId(spec)]
    names[i] = d and d.name or tostring(Combat.specId(spec))
  end
  return { pool = pool, idx = idx, names = names }
end

-- Tirages d'une liste d'effets, faits à l'entrée de la rencontre (r[i] pour l'effet i).
local function rollEffects(exp, rng, effects)
  local r = {}
  for ei, e in ipairs(effects) do
    local k = e[1]
    r[ei] = false
    local ext = X.EFFECTS[k]
    if ext then
      if ext.roll then
        local v = ext.roll(exp, rng, e)
        if v ~= nil then r[ei] = v end
      end
    elseif k == "cardChoice" then
      -- neutral = true : choix parmi les cartes neutres débloquées ; sinon cartes de la classe
      local w = e.rarity and { [e.rarity] = 1 } or X.CARD_WEIGHTS.combat
      if e.neutral then r[ei] = drawNeutral(exp, rng, e.n or 3, w)
      else r[ei] = drawCards(exp, rng, e.n or 3, w, false) end
    elseif k == "relic" and not e[2] then
      r[ei] = drawRelics(exp, rng, 1, X.RELIC_WEIGHTS.normal)[1] or false
    elseif k == "potion" and not e[2] then
      r[ei] = drawPotions(exp, rng, 1)[1] or false
    elseif k == "fight" then
      r[ei] = rollReward(exp, e.kind == "elite" and "elite" or "combat", e.reward)
      -- group = true : groupe tiré dès l'entrée (nom de l'élite affiché : WANTED, Gurubashi Arena)
      if e.group then r[ei].group = rollGroup(exp, rng, e) end
    elseif k == "gamble" then
      r[ei] = { won = Rng.float(rng) < e[2], win = rollEffects(exp, rng, e.win or {}),
        lose = rollEffects(exp, rng, e.lose or {}) }
    end
  end
  return r
end

-- forced : id d'une rencontre imposée (case de parcours d'une zone, X.NODE_KINDS[genre].event).
local function openEvent(exp, forced)
  local rng = exp.rng.events
  exp.phase = "event"
  local id = forced
  if not id then
    local pool = X.eventPool(exp)
    if #pool == 0 then
      exp.event = { id = false, rolls = {}, chosen = false }
      return
    end
    id = Rng.weighted(rng, pool, function(x) return X.eventWeight(ns.Events[x]) end)
  end
  exp.seenEvents[id] = true
  local once = X.onceFlag(id)
  if once then X.setFlag(exp, once) end
  exp.stats.events = exp.stats.events or {}
  exp.stats.events[id] = 0
  local ev = ns.Events[id]
  local rolls = {}
  for ci, ch in ipairs(ev.choices) do rolls[ci] = rollEffects(exp, rng, ch.effects) end
  exp.event = { id = id, rolls = rolls, chosen = false }
end
X.openEvent = openEvent

-- Texte de la rencontre en cours : ev.text, où « %s » est remplacé par le nom du premier ennemi du
-- groupe tiré à l'entrée (fight avec group = true : « WANTED: %s. »).
function X.eventText(exp)
  local ev = exp.event and exp.event.id and ns.Events[exp.event.id]
  if not ev then return "" end
  local text = ev.text or ""
  if not text:find("%s", 1, true) and not text:find("%g", 1, true) then return text end
  local names
  for _, rolls in ipairs(exp.event.rolls or {}) do
    for _, r in ipairs(rolls) do
      if not names and type(r) == "table" and r.group and r.group.names then names = r.group.names end
    end
  end
  names = names or { "someone" }
  local all = names[1]
  if #names > 1 then all = table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names] end
  text = text:gsub("%%s", (names[1]:gsub("%%", "%%%%")))
  text = text:gsub("%%g", (all:gsub("%%", "%%%%")))
  return text
end

local function upgradable(exp)
  local list = {}
  for i = 1, #exp.deck do
    if X.canUpgrade(exp, i) then list[#list + 1] = i end
  end
  return list
end

-- Améliore n cartes au hasard parmi celles qui peuvent l'être (rng : flux de l'état) ; renvoie le nombre.
-- L'épique n'est jamais améliorée au hasard (choix volontaire au feu de camp ou en rencontre « upgrade »).
function X.upgradeRandom(exp, n, rng)
  local list = upgradable(exp)
  for k = #list, 1, -1 do
    if Card.isEpic(ns.Cards[exp.deck[list[k]].id]) then table.remove(list, k) end
  end
  list = Rng.shuffle(rng, list)
  local k = min(n, #list)
  for i = 1, k do upgrade(exp, list[i]) end
  return k
end

-- Codes de refus des effets et leur texte (l'interface traduit aussi les codes).
X.EVENT_REASONS = {
  gold = "Not enough gold.",
  deck = "Deck too small.",
  upgrade = "No card to upgrade.",
  potion = "Requires a potion.",
  relic = "Relic already owned.",
  epic = "An epic card can't be copied.",
}

-- Le choix ci de la rencontre est-il possible ? (true | false, raison)
-- Raison : texte de la condition `when` de la réponse, ou code d'un effet impossible
-- ("gold", "deck", "upgrade", "potion", "relic" ; X.EVENT_REASONS les traduit).
function X.eventChoiceOk(exp, ci)
  local ev = exp.event and exp.event.id and ns.Events[exp.event.id]
  local ch = ev and ev.choices[ci]
  if not ch then return false, "choice" end
  local ok, why = X.check(exp, ch.when)
  if not ok then return false, why end
  for _, e in ipairs(ch.effects) do
    local k = e[1]
    local ext = X.EFFECTS[k]
    if ext and ext.check then
      local okx, whyx = ext.check(exp, e)
      if not okx then return false, whyx end
    end
    if k == "pay" and exp.gold < e[2] then return false, "gold" end
    if (k == "remove" or k == "dupe") and #exp.deck <= 1 then return false, "deck" end
    if k == "upgrade" and #upgradable(exp) == 0 then return false, "upgrade" end
    if k == "losePotion" and not hasPotion(exp) then return false, "potion" end
    if k == "relic" and e[2] and hasRelic(exp, e[2]) then return false, "relic" end
  end
  return true
end

-- Vue des réponses pour l'interface : { index, label, outcome ("?" si cachée), hidden,
-- disabled, reason (texte), chosen }.
function X.eventOptions(exp)
  local ev = exp.event and exp.event.id and ns.Events[exp.event.id]
  if not ev then return {} end
  local list = {}
  for i, ch in ipairs(ev.choices) do
    -- réponse absente (pas grisée) tant qu'une condition « hide » manque (X.choiceHidden)
    if not X.choiceHidden(exp, ch) then
      local ok, why = X.eventChoiceOk(exp, i)
      list[#list + 1] = { index = i, label = ch.label, outcome = ch.hidden and "?" or ch.outcome,
        hidden = ch.hidden and true or false, disabled = not ok or nil,
        reason = not ok and (X.EVENT_REASONS[why] or why) or nil,
        chosen = exp.event.chosen == i or nil }
    end
  end
  return list
end

-- Applique une liste d'effets ; ctx = { reward, follow, texts } accumule la suite.
local function applyEffects(exp, effects, rolls, ctx)
  local function rw()
    ctx.reward = ctx.reward or { kind = "event" }
    return ctx.reward
  end
  for ei, e in ipairs(effects) do
    local k = e[1]
    local ext = X.EFFECTS[k]
    if ext then
      ext.apply(exp, e, rolls[ei], ctx)
    elseif k == "heal" then
      heal(exp, e[2])
    elseif k == "healPct" then
      heal(exp, floor(exp.maxHp * e[2]))
    elseif k == "loseHp" then
      exp.hp = max(1, exp.hp - e[2])
    elseif k == "maxHp" or k == "loseMaxHp" then
      local n = k == "maxHp" and e[2] or -e[2]
      exp.maxHp = max(1, exp.maxHp + n)
      exp.hp = max(1, min(exp.maxHp, exp.hp + max(0, n)))
    elseif k == "gold" then
      local r = rw()
      r.gold = (r.gold or 0) + e[2]
    elseif k == "pay" then
      spend(exp, e[2])
    elseif k == "loseGold" then
      spend(exp, min(exp.gold, e[2]))
    elseif k == "card" then
      X.addCard(exp, e[2], e.up)
    elseif k == "cardChoice" then
      rw().cards = U.copyArr(rolls[ei])
    elseif k == "relic" then
      local id = e[2] or rolls[ei]
      if id and not hasRelic(exp, id) then rw().relic = id end
    elseif k == "potion" then
      local id = e[2] or rolls[ei]
      if id then rw().potion = id end
    elseif k == "losePotion" then
      for s = #exp.potions, 1, -1 do
        if exp.potions[s] then
          exp.potions[s] = false
          break
        end
      end
    elseif k == "upgradeRandom" then
      X.upgradeRandom(exp, e[2], exp.rng.events)
    elseif k == "upgrade" or k == "remove" or k == "dupe" then
      ctx.follow = { kind = k }
    elseif k == "fight" then
      -- st = { asleep = 3 } (Sleeping Camp), hpMul (Gurubashi Arena) : posés sur les ennemis hors boss ;
      -- group : groupe tiré à l'entrée (rolls) ; reward = { cards, shift } : récompense déjà tirée ainsi
      local reward = U.copy(rolls[ei])
      local group = reward and reward.group
      if reward then reward.group = nil end
      local mods = (e.st or e.hpMul) and { st = e.st and U.copy(e.st) or nil, hpMul = e.hpMul } or nil
      ctx.follow = { kind = "fight", fight = e.kind == "elite" and "elite" or "combat",
        pool = group and group.pool or e[2], reward = reward, bonus = e.gold,
        extra = (group or mods) and { idx = group and group.idx or nil, mods = mods } or nil }
    elseif k == "gamble" then
      local r = rolls[ei]
      exp.event.lucky = r.won
      if r.won then
        applyEffects(exp, e.win or {}, r.win, ctx)
        if e.winText then ctx.texts[#ctx.texts + 1] = e.winText end
      else
        applyEffects(exp, e.lose or {}, r.lose, ctx)
        if e.loseText then ctx.texts[#ctx.texts + 1] = e.loseText end
      end
    elseif k == "flag" then
      X.setFlag(exp, e[2])
    else
      error("unknown encounter effect: " .. tostring(k))
    end
  end
end

local function applyEvent(exp, ci)
  local ev = ns.Events[exp.event.id]
  local ch = ev.choices[ci]
  exp.event.chosen = ci
  if exp.stats.events then exp.stats.events[exp.event.id] = ci end
  local ctx = { texts = {} }
  if ch.result and ch.result ~= "" then ctx.texts[1] = ch.result end
  applyEffects(exp, ch.effects, exp.event.rolls[ci], ctx)
  exp.event.result = table.concat(ctx.texts, " ")
  local follow, reward = ctx.follow, ctx.reward
  if follow and follow.kind == "event" then
    -- rencontre enchaînée : une réponse qui enchaîne ne donne pas de récompense (la mettre dans la suivante)
    openEvent(exp, follow.id)
  elseif follow and follow.kind == "fight" then
    -- Récompense du combat : tirée à l'entrée, plus le bonus et l'or de la réponse.
    local r = follow.reward
    local bonus = (follow.bonus or 0) + (reward and reward.gold or 0)
    if bonus > 0 then r.gold = (r.gold or 0) + bonus end
    startFight(exp, follow.fight, follow.pool, r, follow.extra)
  elseif follow then
    -- Sélection d'une carte ; une récompense de la même réponse s'ouvre après.
    follow.reward = reward
    exp.select = follow
    exp.phase = "select"
  elseif reward then
    openReward(exp, reward)
  end
end

-- Entrée dans un nœud ----------------------------------------------------------

local function enterNode(exp, id)
  local node = exp.map.nodes[id]
  exp.node = id
  exp.path = exp.path or {}
  exp.path[#exp.path + 1] = id
  exp.floor = node.floor
  exp.nodeCleared = false
  local v = exp.stats.visits
  v[node.kind] = (v[node.kind] or 0) + 1
  X.fire(exp, "onNodeEnter", node)
  local k = node.kind
  if k == "combat" or k == "elite" or k == "boss" then
    startFight(exp, k)
  elseif k == "campfire" then
    exp.phase = "campfire"
  elseif k == "merchant" then
    openShop(exp)
  elseif k == "event" then
    openEvent(exp)
  elseif k == "chest" then
    openReward(exp, rollReward(exp, "chest"))
  elseif X.NODE_KINDS[k] then
    local def = X.NODE_KINDS[k]
    if def.enter then def.enter(exp, node) else openEvent(exp, def.event) end
  else
    error("unknown node kind: " .. tostring(k))
  end
end

---------------------------------------------------------------------------
-- Création
---------------------------------------------------------------------------

-- Une expédition commence à Westfall et traverse les zones dans l'ordre de la campagne jusqu'à la dernière
-- (décision du joueur, 14/11/2026). zone et lastZone ne servent qu'aux tests et à la simulation (isoler une zone).
-- opts : seed, class ("priest"), zone (zone de départ, défaut : la première), lastZone (zone dont le boss
--        termine l'expédition, défaut : la dernière de la campagne), key (0..5),
--        unlocks = { level = 1..7 (palier de contenu de la classe), common = 0..7 (palier commun du compte),
--                    won = { [zone] = meilleure clé gagnée par la classe },
--                    talents = { [nœud] = rang }, spec = voie (arbre de la classe ; absent = aucun talent) }
--                  (Meta.unlocks),
--        flags = { nom = true } (drapeaux de compte, fournis par Meta.newExpedition),
--        stats (statistiques de combat, simulation), quiet (combat sans journal d'événements),
--        epic = id d'une carte épique ajoutée au deck de départ (simulation)
function X.new(opts)
  opts = opts or {}
  local seed = floor(opts.seed or 1)
  local class = opts.class or "priest"
  local cdef = ns.Classes[class]
  if not cdef then error("unknown class: " .. tostring(class)) end
  local unlock = opts.unlocks or {}
  local key = opts.key or 0
  local zone = opts.zone or ns.Zone.FIRST
  if not ns.Zones[zone] then error("unknown zone: " .. tostring(zone)) end
  -- zone hors de la campagne (zone factice des tests) : elle seule
  local zo = ns.Zone.order(zone)
  local lastZone = opts.lastZone or (zo and ns.Zone.ORDER[#ns.Zone.ORDER] or zone)
  local lo = ns.Zone.order(lastZone)
  if not ns.Zones[lastZone] or (zo and lo and lo < zo) then error("bad last zone: " .. tostring(lastZone)) end
  local exp = {
    version = X.VERSION, seed = seed, class = class, zone = zone, key = key,
    startZone = zone, lastZone = lastZone, beaten = {},
    affixes = ns.Meta.affixesFor(key),
    unlock = { level = unlock.level or 1, common = unlock.common or 0, won = U.copyMap(unlock.won or {}) },
    -- act : rang de la zone en cours dans l'expédition (1 = la zone de départ) ; acts : zones à traverser
    acts = (zo and lo) and (lo - zo + 1) or 1, act = 0, floor = 0,
    hp = cdef.hp, maxHp = cdef.hp, gold = X.START_GOLD,
    deck = {}, relics = {}, potions = {},
    removals = 0, combatsInAct = 0, lastEnc = {}, seenEvents = {}, relicState = {},
    -- Drapeaux de compte : copie figée au départ (conditions) et drapeaux posés pendant
    -- l'expédition, reportés dans la méta par Meta.record.
    flags = U.copyMap(opts.flags or {}), newFlags = {},
    nodeCleared = false,
    rng = {
      map = Rng.stream(seed, "map"),
      loot = Rng.stream(seed, "loot"),
      merchant = Rng.stream(seed, "merchant"),
      events = Rng.stream(seed, "events"),
      combat = Rng.stream(seed, "combat"),
    },
    stats = { cleared = 0, elites = 0, bosses = 0, combats = 0, goldEarned = 0, goldSpent = 0,
      cardsAdded = 0, removed = 0, upgraded = 0, upTiers = {}, visits = {}, events = {} },
    combatStats = opts.stats and true or false,
    quiet = opts.quiet and true or false,
  }
  -- talents figés au départ (docs/talents.md) : copie de l'arbre (exp.unlock.talents, exp.unlock.spec), liste dans
  -- l'ordre de l'arbre (exp.talents : crochets d'expédition et de combat), état propre (exp.talentState : « une
  -- fois par expédition », Rage gardée…). Sans talent : aucun de ces champs, l'expédition d'avant les talents.
  local tl = ns.Talent and ns.Talent.entries(class, unlock.talents, unlock.spec)
  if tl then
    exp.unlock.talents = U.copyMap(unlock.talents)
    exp.unlock.spec = unlock.spec
    exp.talents = tl
    exp.talentState = {}
    exp.maxHp = max(1, floor(X.modify(exp, "startMaxHp", exp.maxHp)))
    exp.hp = exp.maxHp
    exp.gold = max(0, floor(X.modify(exp, "startGold", exp.gold)))
  end
  for i = 1, X.POTION_SLOTS do exp.potions[i] = false end
  for i = 1, #cdef.deck do exp.deck[i] = { id = cdef.deck[i], up = false } end
  -- épiques imposées au départ (simulation : epic=<id> ou epic=a+b+c, ou une liste), comme des épiques prises,
  -- sans plafond
  if opts.epic then
    local ids = opts.epic
    if type(ids) == "string" then
      local l = {}
      for id in ids:gmatch("[^+]+") do l[#l + 1] = id end
      ids = l
    end
    for _, id in ipairs(ids) do
      local d = ns.Cards[id]
      if not (d and d.rarity == "epic") then error("not an epic card: " .. tostring(id)) end
      X.addCard(exp, id, nil, true)
      exp.stats.cardsAdded = exp.stats.cardsAdded - 1
    end
  end
  -- bibelot de classe de départ (Battle Standard…) : possédé dès le départ, jamais tiré
  if cdef.startRelic then X.gainRelic(exp, cdef.startRelic) end
  -- toutes les zones (quelle que soit celle jouée) : effets de compte sur la nouvelle expédition
  -- (Rallying Cry of the Dragonslayer : +6 PV max) ; ns.ZoneRules[id].newExpedition(exp), ordre des ids
  local zids = {}
  for zid, r in pairs(ns.ZoneRules) do if r.newExpedition then zids[#zids + 1] = zid end end
  table.sort(zids)
  for _, zid in ipairs(zids) do ns.ZoneRules[zid].newExpedition(exp) end
  startAct(exp, 1)
  -- Un bibelot au choix parmi 3 (première victoire du compte dans la zone d'ordre Meta.PERKS.startRelic,
  -- ex-Révéré de la Ligue), tirés dans la réserve de l'expédition (communs, de classe et de clé
  -- débloqués, hors boss).
  if commonTier(exp) >= ns.Meta.PERKS.startRelic then
    local list = drawFrom(exp.rng.loot, X.relicPool(exp), relicRarity, 3,
      { common = 1, uncommon = 1, rare = 1 })
    if #list > 0 then
      exp.startRelics = list
      exp.phase = "start"
    end
  end
  -- Épiques au départ (talent Veteran's Arsenal, crochet startEpics) : n choix successifs parmi les épiques de la
  -- classe proposables (zones gagnées par la classe, X.epicPool), avant le bibelot de départ ; crochet
  -- startEpicOffer (v = 0 : toutes) : seulement k d'entre elles, tirées au départ (flux « talentEpic »).
  if exp.talents then
    local n = floor(X.modify(exp, "startEpics", 0))
    local pool = X.epicPool(exp)
    if n > 0 and #pool > 0 then
      local k = floor(X.modify(exp, "startEpicOffer", 0))
      if k > 0 then pool = drawEpics(Rng.stream(seed, "talentEpic"), pool, k) end
      exp.talentEpics = pool
      exp.talentEpicsLeft = n
      exp.phase = "start"
    end
  end
  return exp
end

-- Phase « start » : épiques au départ d'abord (exp.talentEpics), puis le bibelot de départ, puis la carte.
local function nextStart(exp)
  if exp.talentEpics and (exp.talentEpicsLeft or 0) > 0 and #exp.talentEpics > 0 then return end
  exp.talentEpics, exp.talentEpicsLeft = nil, nil
  if exp.startRelics then return end
  exp.phase = "map"
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local H = {} -- H[phase][verbe] = function(exp, a) -> true | false, raison

-- Phase « start » : le bibelot de départ (exp.startRelics), puis la carte.
H.start = {
  -- épique au départ (Veteran's Arsenal) : l'épique a[2] de exp.talentEpics entre au deck (comme une épique prise)
  talentEpic = function(exp, a)
    local list = exp.talentEpics
    local id = list and list[a[2] or 0]
    if not id then return false, "index" end
    X.addCard(exp, id, nil, true) -- sans plafond, comme une épique imposée
    exp.stats.cardsAdded = exp.stats.cardsAdded - 1
    table.remove(list, a[2])
    exp.talentEpicsLeft = exp.talentEpicsLeft - 1
    nextStart(exp)
    return true
  end,
  skipTalentEpic = function(exp)
    if not exp.talentEpics then return false, "index" end
    exp.talentEpicsLeft = 0
    nextStart(exp)
    return true
  end,
  startRelic = function(exp, a)
    if exp.talentEpics or not exp.startRelics then return false, "index" end
    local id = exp.startRelics[a[2] or 0]
    if not id then return false, "index" end
    X.gainRelic(exp, id)
    exp.startRelics = nil
    exp.phase = "map"
    return true
  end,
  skipStartRelic = function(exp)
    if exp.talentEpics or not exp.startRelics then return false, "index" end
    exp.startRelics = nil
    exp.phase = "map"
    return true
  end,
}

H.map = {
  path = function(exp, a)
    local id = a[2]
    if not U.indexOf(X.nextNodes(exp), id) then return false, "path" end
    exp.skip = nil
    enterNode(exp, id)
    return true
  end,
}

local function afterCombatAction(exp, ok, why)
  if exp.combat and exp.combat.result then endFight(exp) end
  if ok then return true end
  return false, why
end

H.combat = {
  play = function(exp, a)
    local opts = a[4] == "nospend" and { spend = false } or nil
    return afterCombatAction(exp, Combat.play(exp.combat, a[2], a[3], opts))
  end,
  endTurn = function(exp)
    if not Combat.endTurn(exp.combat) then return false, "phase" end
    return afterCombatAction(exp, true)
  end,
  potion = function(exp, a)
    if not Combat.usePotion then return false, "potions" end
    return afterCombatAction(exp, Combat.usePotion(exp.combat, a[2], a[3]))
  end,
}

H.reward = {
  pickCard = function(exp, a)
    local r = exp.reward
    local id = not r.cardsDone and r.cards[a[2] or 0]
    if not id then return false, "badCard" end
    X.addCard(exp, id)
    r.cardsDone = true
    r.picked = id
    return true
  end,
  skipCards = function(exp)
    if exp.reward.cardsDone then return false, "badCard" end
    exp.reward.cardsDone = true
    return true
  end,
  -- choix « Epic » (X.offerEpic) : une épique parmi r.epics (remplace celle du deck), ou aucune
  pickEpic = function(exp, a)
    local r = exp.reward
    local id = r.epics and not r.epicDone and r.epics[a[2] or 0]
    if not id then return false, "badCard" end
    X.addCard(exp, id)
    r.epicDone = true
    r.epicPicked = id
    return true
  end,
  skipEpic = function(exp)
    local r = exp.reward
    if not r.epics or r.epicDone then return false, "badCard" end
    r.epicDone = true
    return true
  end,
  takePotion = function(exp)
    local r = exp.reward
    if not r.potion or r.potionTaken then return false, "potion" end
    if not X.gainPotion(exp, r.potion) then return false, "slot" end
    r.potionTaken = true
    return true
  end,
  leave = function(exp)
    leaveNode(exp)
    return true
  end,
}

-- Actions du feu de camp déclarées par les zones actives (ns.ZoneRules[id].campfire = { { id, label,
-- text, can = f(exp) -> ok, raison, apply = f(exp) -> "stay" pour rester au feu } }) : liste
-- { id, label, text, def }.
function X.campActions(exp)
  local list = {}
  local zr = zoneRuns(exp)
  for _, zid in ipairs(zr or {}) do
    for _, a in ipairs(ns.ZoneRules[zid].campfire or {}) do
      list[#list + 1] = { id = a.id, label = a.label, text = a.text, def = a }
    end
  end
  return list
end

local function campAction(exp, id)
  for _, a in ipairs(X.campActions(exp)) do
    if a.id == id then return a.def end
  end
  return nil
end

H.campfire = {
  campAction = function(exp, a)
    local def = campAction(exp, a[2])
    if not def then return false, "action" end
    if def.can then
      local ok, why = def.can(exp)
      if not ok then return false, why or "action" end
    end
    if def.apply(exp) ~= "stay" then leaveNode(exp) end
    return true
  end,
  rest = function(exp)
    local frac = X.modify(exp, "restFraction", X.REST_FRACTION)
    local n = floor(X.modify(exp, "restHeal", floor(exp.maxHp * frac)))
    exp.lastRest = heal(exp, n)
    X.fire(exp, "onRest")
    leaveNode(exp)
    return true
  end,
  upgrade = function(exp, a)
    if not X.canUpgrade(exp, a[2] or 0) then return false, X.upgradeRefusal(exp, a[2] or 0) end
    upgrade(exp, a[2])
    leaveNode(exp)
    return true
  end,
  leave = function(exp)
    leaveNode(exp)
    return true
  end,
}

local function buy(exp, list, i, give)
  local item = list[i or 0]
  if not item or item.sold then return false, "item" end
  if exp.gold < item.price then return false, "gold" end
  local ok, why = give(item.id)
  if ok == false then return false, why end
  spend(exp, item.price)
  item.sold = true
  return true
end

H.merchant = {
  buyCard = function(exp, a)
    local it = exp.shop.cards[a[2] or 0]
    -- carte vendue améliorée : ajoutée à son palier (it.up : nombre ; true d'avant les paliers = 1)
    return buy(exp, exp.shop.cards, a[2], function(id) X.addCard(exp, id, it and it.up) end)
  end,
  buyRelic = function(exp, a)
    return buy(exp, exp.shop.relics, a[2], function(id) X.gainRelic(exp, id) end)
  end,
  buyPotion = function(exp, a)
    return buy(exp, exp.shop.potions, a[2], function(id)
      if not X.gainPotion(exp, id) then return false, "slot" end
    end)
  end,
  remove = function(exp, a)
    local i = a[2] or 0
    local price = X.removePrice(exp)
    if not exp.deck[i] or #exp.deck <= 1 then return false, "badCard" end
    if exp.gold < price then return false, "gold" end
    spend(exp, price)
    table.remove(exp.deck, i)
    exp.removals = exp.removals + 1
    exp.shop.removed = (exp.shop.removed or 0) + 1
    exp.stats.removed = exp.stats.removed + 1
    return true
  end,
  leave = function(exp)
    leaveNode(exp)
    return true
  end,
}

H.event = {
  choose = function(exp, a)
    if exp.event.chosen then return false, "chosen" end
    local ok, why = X.eventChoiceOk(exp, a[2] or 0)
    if not ok then return false, why end
    applyEvent(exp, a[2])
    return true
  end,
  leave = function(exp)
    if exp.event.id and not exp.event.chosen then return false, "choice" end
    leaveNode(exp)
    return true
  end,
}

-- Fin d'une sélection : récompense en attente de la même réponse, sinon retour à la carte.
local function endSelect(exp)
  local r = exp.select.reward
  exp.select = nil
  if r then
    openReward(exp, r)
  else
    leaveNode(exp)
  end
end

H.select = {
  select = function(exp, a)
    local i = a[2] or 0
    local kind = exp.select.kind
    if kind == "upgrade" then
      if not X.canUpgrade(exp, i) then return false, X.upgradeRefusal(exp, i) end
      upgrade(exp, i)
    elseif kind == "remove" then
      if not exp.deck[i] or #exp.deck <= 1 then return false, "badCard" end
      table.remove(exp.deck, i)
      exp.stats.removed = exp.stats.removed + 1
    elseif kind == "dupe" then
      local card = exp.deck[i]
      if not card then return false, "badCard" end
      -- une épique ne se copie pas (une seule par expédition)
      if Card.isEpic(ns.Cards[card.id]) then return false, "epic" end
      X.addCard(exp, card.id, card.up)
    end
    endSelect(exp)
    return true
  end,
  skipSelect = function(exp)
    endSelect(exp)
    return true
  end,
}

-- Entre deux zones (exp.transit : zone quittée, zone suivante, PV rendus) : la carte de la zone suivante.
H.transit = {
  continue = function(exp)
    exp.transit = nil
    exp.phase = "map"
    return true
  end,
}

-- Actions possibles dans toutes les phases (sauf « done » ; jeter une potion : hors combat).
local COMMON = {
  discardPotion = function(exp, a)
    if exp.phase == "combat" then return false, "phase" end
    local s = a[2] or 0
    if not exp.potions[s] then return false, "slot" end
    exp.potions[s] = false
    return true
  end,
  abandon = function(exp)
    finish(exp, "abandoned")
    return true
  end,
}

function X.act(exp, a)
  if exp.phase == "done" then return false, "ended" end
  -- Combat déjà tranché mais pas encore conclu (état rechargé, effet externe) : n'importe
  -- quelle action le conclut, et rien d'autre.
  if exp.phase == "combat" and exp.combat.result then
    endFight(exp)
    return true
  end
  local verb = a and a[1]
  local ph = H[exp.phase]
  local h = (ph and ph[verb]) or COMMON[verb]
  if not h then return false, "action" end
  return h(exp, a)
end

-- Liste des actions possibles maintenant (« abandon » est toujours possible et n'y figure pas).
function X.choices(exp)
  local list = {}
  local ph = exp.phase
  local function add(a) list[#list + 1] = a end
  if ph == "start" then
    if exp.talentEpics then
      for i = 1, #exp.talentEpics do add({ "talentEpic", i }) end
      add({ "skipTalentEpic" })
    elseif exp.startRelics then
      for i = 1, #exp.startRelics do add({ "startRelic", i }) end
      add({ "skipStartRelic" })
    end
  elseif ph == "map" then
    local nx = X.nextNodes(exp)
    for i = 1, #nx do add({ "path", nx[i] }) end
  elseif ph == "combat" then
    local c = exp.combat
    local plays = Combat.legalPlays(c)
    -- quatrième champ "nospend" : carte « Spend N » jouée sans dépenser (choix du joueur)
    for i = 1, #plays do add({ "play", plays[i][1], plays[i][2], plays[i][3] and "nospend" or nil }) end
    local pots = c.player.potions
    if Combat.usePotion and pots then
      for s = 1, #pots do
        local p = pots[s] and ns.Potions[pots[s]]
        if p then
          if p.target then
            for j = 1, #c.enemies do
              if not c.enemies[j].dead then add({ "potion", s, j }) end
            end
          else
            add({ "potion", s })
          end
        end
      end
    end
    add({ "endTurn" })
  elseif ph == "reward" then
    local r = exp.reward
    if not r.cardsDone then
      for i = 1, #r.cards do add({ "pickCard", i }) end
      add({ "skipCards" })
    end
    if r.epics and not r.epicDone then
      for i = 1, #r.epics do add({ "pickEpic", i }) end
      add({ "skipEpic" })
    end
    if r.potion and not r.potionTaken and X.freeSlot(exp) then add({ "takePotion" }) end
    add({ "leave" })
  elseif ph == "campfire" then
    add({ "rest" })
    for i = 1, #exp.deck do
      if X.canUpgrade(exp, i) then add({ "upgrade", i }) end
    end
    for _, ca in ipairs(X.campActions(exp)) do
      if not ca.def.can or ca.def.can(exp) then add({ "campAction", ca.id }) end
    end
    add({ "leave" })
  elseif ph == "merchant" then
    local s = exp.shop
    local free = X.freeSlot(exp)
    for i, it in ipairs(s.cards) do
      if not it.sold and exp.gold >= it.price then add({ "buyCard", i }) end
    end
    for i, it in ipairs(s.relics) do
      if not it.sold and exp.gold >= it.price then add({ "buyRelic", i }) end
    end
    for i, it in ipairs(s.potions) do
      if free and not it.sold and exp.gold >= it.price then add({ "buyPotion", i }) end
    end
    if exp.gold >= X.removePrice(exp) and #exp.deck > 1 then
      for i = 1, #exp.deck do add({ "remove", i }) end
    end
    add({ "leave" })
  elseif ph == "event" then
    local ev = exp.event
    if ev.id and not ev.chosen then
      for i = 1, #ns.Events[ev.id].choices do
        if X.eventChoiceOk(exp, i) then add({ "choose", i }) end
      end
    else
      add({ "leave" })
    end
  elseif ph == "select" then
    local kind = exp.select.kind
    for i = 1, #exp.deck do
      if (kind ~= "upgrade" or X.canUpgrade(exp, i))
          and not (kind == "dupe" and Card.isEpic(ns.Cards[exp.deck[i].id])) then add({ "select", i }) end
    end
    add({ "skipSelect" })
  elseif ph == "transit" then
    add({ "continue" })
  end
  if ph ~= "done" and ph ~= "combat" then
    for s = 1, #exp.potions do
      if exp.potions[s] then add({ "discardPotion", s }) end
    end
  end
  return list
end

---------------------------------------------------------------------------
-- Lecture
---------------------------------------------------------------------------

function X.currentNode(exp)
  return exp.node and exp.map.nodes[exp.node] or nil
end

function X.actName(exp)
  local z = X.zoneDef(exp)
  return z and z.name or ""
end

-- Position de la zone en cours dans la campagne : rang, nombre de zones (« Duskwood · 2/7 »).
function X.campaignPos(exp)
  return ns.Zone.order(exp.zone) or 1, ns.Zone.count()
end

-- Nom de la zone en cours et sa place dans la campagne : « Duskwood · 2/7 » (bandeau, carte).
function X.campaignName(exp)
  local n, total = X.campaignPos(exp)
  return X.actName(exp) .. " · " .. n .. "/" .. total
end

-- Résumé archivable d'une expédition (journal) : zone atteinte (zone), boss battus (beaten, ids de zone).
function X.summary(exp)
  local s = exp.stats
  return {
    result = exp.result, class = exp.class, zone = exp.zone, key = exp.key, seed = exp.seed,
    act = exp.act, floor = exp.floor, cleared = s.cleared, elites = s.elites, bosses = s.bosses,
    beaten = U.copyArr(exp.beaten or {}),
    hp = exp.hp, maxHp = exp.maxHp, gold = exp.gold, goldEarned = s.goldEarned,
    deck = U.copy(exp.deck), relics = U.copyArr(exp.relics), killedBy = exp.killedBy,
  }
end
