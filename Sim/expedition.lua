-- Expédition complète simulée : un bot hors combat (chemin, récompenses, feu de camp,
-- marchand, rencontres, potions) joue via Core/Expedition, les combats sont joués par
-- les bots de Sim/bots.lua. Même API que l'interface : Expedition.choices / act.
-- SimExpedition.play(opts) -> enregistrement compatible avec Sim/sim.lua
-- opts : seed, bot, class, pick ("rated"|"random"|"skip"), cap, maxRounds,
--        key (niveau de clé mythique) ; l'expédition traverse la campagne depuis Westfall (docs/expedition.md) :
--        startZone (diagnostic : départ dans cette zone avec le deck de départ), maxZone (diagnostic : arrêt après
--        le boss de cette zone), zone (alias : startZone = maxZone = zone, une zone seule),
--        zones (0..7 : zones gagnées par le compte et la classe, à toutes les clés),
--        meta ("start"|"exalted" : alias de zones=0 et zones=7), level (niveau de classe 1..7, défaut 7),
--        epic (id d'une carte épique imposée au deck de départ),
--        human (bot=human : { skill = …, width = … }, Bots.humanParams ; hors combat aussi, humanDecide),
--        fightBot (bot des combats à la place de bot : bot=human fightBot=heuristic isole le jeu hors combat)
return function(ns)
  local X, Rng, Bots, Meta, Card = ns.Expedition, ns.Rng, ns.Bots, ns.Meta, ns.Card
  local SE = {}
  -- Compte vétéran simulé (au moins une zone gagnée) : drapeaux toujours présents, et une branche
  -- d'histoire choisie par la graine.
  SE.VETERAN_FLAGS = { "event:tobin_thief" }
  SE.VETERAN_BRANCHES = { "tobin_spared", "tobin_jailed" }

  -- path=<voie> (SE.play, opts.path) : les cartes de classe d'une autre voie et les cartes neutres valent 0,
  -- donc ne sont jamais prises (voie jouée seule).
  local onlyPath
  -- Conseils propres à l'épique du deck (une épique pilote le build) : classDef.bot.byEpic[id] = { rating,
  -- upgrade, remove }, chacun une table { [carte] = note } ou une fonction (exp, carte) -> note|nil ; ils
  -- priment sur ceux de la classe tant que l'épique est dans le deck. Posés par decide (advice, adviceExp).
  local advice, adviceExp
  local function advised(key, id)
    local a = advice and advice[key]
    if type(a) == "function" then return a(adviceExp, id) end
    return a and a[id]
  end
  local function rating(id)
    if onlyPath then
      local d = ns.Cards[id]
      if d and d.path ~= onlyPath and d.path ~= "start" then return 0 end
    end
    return advised("rating", id) or ns.Run.RATING[id] or 3
  end

  -- Conseils de la classe jouée (classDef.bot : upgrade, remove).
  local function botOf(exp)
    local cd = ns.Classes[exp.class]
    return cd and cd.bot or {}
  end
  local function adviceOf(exp)
    local b = botOf(exp)
    local i = b.byEpic and X.epicIndex(exp)
    return i and b.byEpic[exp.deck[i].id] or nil
  end

  -- Amélioration vers le palier suivant (docs/ameliorations.md) : une note d'amélioration (tables upgrade de la
  -- classe ou de l'épique) est celle du palier 1 ; un nombre vaut × SE.UPGRADE_TIER[palier visé] pour les paliers
  -- 2 et 3 (un palier de plus rapporte d'ordinaire moins que le premier) ; une table { p1, p2, p3 } donne la
  -- note de chaque palier.
  SE.UPGRADE_TIER = { 1, 0.8, 0.6 }
  local function tierValue(v, card)
    local n = Card.level(card) + 1
    if type(v) == "table" then return v[n] or v[#v] or 0 end
    return v * (SE.UPGRADE_TIER[n] or SE.UPGRADE_TIER[#SE.UPGRADE_TIER])
  end
  SE.tierValue = tierValue

  -- Valeur d'une carte du deck pour l'amélioration (cartes de base comprises) vers son palier suivant.
  local function upgradeValue(exp, card)
    local up = botOf(exp).upgrade
    return tierValue(advised("upgrade", card.id) or up and up[card.id] or rating(card.id), card)
  end

  -- Meilleure amélioration. L'épique du deck : sa table byEpic[id].upgrade la classe parmi quelques cartes
  -- (le plus souvent celles du deck de départ), sur une échelle propre à chaque classe (Warrior et Priest ≈ 9
  -- à 14, les autres ≈ 0 à 5) ; une carte absente de la table prend la note de choix (rating, ≈ 5 à 14), qui
  -- passait devant l'épique dès qu'une bonne carte avait été prise : l'épique n'était presque jamais
  -- améliorée. Elle passe donc devant toute carte que sa table ne classe pas au-dessus d'elle (elle est en
  -- jeu à chaque combat, une carte du deck seulement quand elle est piochée) : tant qu'elle est à améliorer,
  -- le choix se fait d'abord entre elle et les cartes que sa table classe au moins aussi haut, dans l'ordre
  -- de la table ; ensuite, comme avant.
  local function bestUpgrade(exp)
    local tbl = advice and type(advice.upgrade) == "table" and advice.upgrade
    -- plusieurs épiques : la première du deck encore à améliorer que la table classe
    local ei, epicV
    if tbl then
      for _, k in ipairs(X.epicIndices(exp)) do
        if X.canUpgrade(exp, k) and tbl[exp.deck[k].id] then ei, epicV = k, tbl[exp.deck[k].id] break end
      end
    end
    local best, bestV = nil, -1
    if epicV then
      best, bestV = ei, tierValue(epicV, exp.deck[ei])
      for i = 1, #exp.deck do
        local v = i ~= ei and X.canUpgrade(exp, i) and tbl[exp.deck[i].id]
        if v then v = tierValue(v, exp.deck[i]) end
        if v and v > bestV then best, bestV = i, v end
      end
      return best
    end
    for i = 1, #exp.deck do
      if X.canUpgrade(exp, i) then
        local v = upgradeValue(exp, exp.deck[i])
        if v > bestV then best, bestV = i, v end
      end
    end
    return best
  end

  -- Carte à retirer : la plus faible (Priest : Inner Fire d'abord, puis Smite ; classDef.bot.remove).
  -- skip : index jamais choisi (l'épique du deck, politique decksize du bot human).
  local function worstCard(exp, skip)
    local worst, worstV = nil, math.huge
    local rm = botOf(exp).remove or {}
    for i = 1, #exp.deck do
      -- skip donné (index de l'épique) : aucune épique du deck n'est choisie (plusieurs épiques par expédition)
      if i ~= skip and not (skip and Card.isEpic(ns.Cards[exp.deck[i].id])) then
        local card = exp.deck[i]
        local v = advised("remove", card.id) or rm[card.id] or rating(card.id) + 2
        v = v + Card.level(card) -- carte améliorée : +1 par palier
        if v < worstV then worst, worstV = i, v end
      end
    end
    return worst, worstV
  end

  -- Valeur d'une carte ajoutée au deck, dans les unités des effets de rencontre (1 ≈ une potion,
  -- 0,03 par pièce d'or, 0,12 par PV à pleine vie). La note vaut ≈ 5 + écart / 2, l'écart étant les
  -- points de victoire gagnés en ajoutant la carte au deck de départ de 10 cartes (balayage sweep=cards,
  -- docs/equilibrage.md) : 5 = carte neutre, en dessous elle nuit. Son effet se dilue avec la taille du
  -- deck (elle est piochée moins souvent) : écart × 10 / taille. SE.POINTS_PER_UNIT = points de victoire
  -- que vaut une unité (≈ une potion, ≈ 8 PV).
  SE.POINTS_PER_UNIT = 3
  SE.UPGRADED_BONUS = 0.5 -- note d'une carte déjà améliorée
  local function cardValue(exp, r)
    return 2 * (r - 5) * 10 / math.max(#exp.deck, 10) / SE.POINTS_PER_UNIT
  end
  SE.cardValue = cardValue

  -- Politique de taille de deck du bot human (decksize=N, Bots.HUMAN_RANGE ; docs/equilibrage.md, « Bot human :
  -- deck serré ») : deckCap = N pendant l'expédition, nil sinon (bot de référence, decksize=0 : rien ne change).
  -- Deck à N cartes ou plus : une carte (récompense, marchand, rencontre) n'entre que si sa note perçue dépasse
  -- celle de la carte qu'il retirerait d'abord (worstCard, l'épique exceptée ; note de choix, carte de départ
  -- ≈ 3, + SE.UPGRADED_BONUS par palier) de SE.DECKSIZE_MARGIN, plus SE.DECKSIZE_STEP par carte au-delà de N :
  -- plus le deck déborde, plus la carte doit être bonne (note perçue des meilleures cartes ≈ 9 à 11 : rares
  -- au-delà de N + 2). Il retire au marchand dès qu'il le peut (avant les bibelots) tant que le deck dépasse N,
  -- ou qu'il est à N avec une carte à retirer (valeur de retrait ≤ 1,5 : cartes de départ) ; une rencontre
  -- qui retire vaut SE.DECKSIZE_REMOVE_VALUE, une copie (dupe) ne vaut rien, une carte imposée trop faible
  -- coûte SE.DECKSIZE_UNWANTED.
  local deckCap
  SE.DECKSIZE_MARGIN, SE.DECKSIZE_STEP = 1.5, 2.5
  SE.DECKSIZE_REMOVE_VALUE, SE.DECKSIZE_UNWANTED = 2.5, 0.5
  local function capFull(exp) return deckCap and #exp.deck >= deckCap end
  -- Note perçue qu'une carte doit atteindre pour entrer dans le deck plein, nil sous deckCap.
  local function capThreshold(exp)
    if not capFull(exp) then return nil end
    local w = worstCard(exp, X.epicIndex(exp))
    if not w then return nil end
    local card = exp.deck[w]
    return rating(card.id) + SE.UPGRADED_BONUS * Card.level(card) + SE.DECKSIZE_MARGIN
      + SE.DECKSIZE_STEP * (#exp.deck - deckCap)
  end

  -- Note espérée de la meilleure de n cartes tirées sans remise dans pool (choix « une parmi n, ou passer ») :
  -- la k-ième plus faible des N notes est la meilleure avec la probabilité C(k-1, n-1) / C(N, n).
  local function expectedBest(pool, n)
    local rs = {}
    for i = 1, #pool do rs[i] = rating(pool[i]) end
    table.sort(rs)
    local N = #rs
    if N == 0 then return 0 end
    if n >= N then return rs[N] end
    local function choose(a, b)
      if b < 0 or b > a then return 0 end
      local v = 1
      for i = 1, b do v = v * (a - b + i) / i end
      return v
    end
    local total, v = choose(N, n), 0
    for k = n, N do v = v + rs[k] * choose(k - 1, n - 1) / total end
    return v
  end

  -- Réserve d'un choix de cartes de rencontre (mêmes filtres que Core/Expedition : rareté, neutres).
  local function choicePool(exp, e)
    local pool = e.neutral and X.neutralPool(exp) or X.cardPool(exp)
    if not e.rarity then return pool end
    local out = {}
    for i = 1, #pool do
      if ns.Cards[pool[i]].rarity == e.rarity then out[#out + 1] = pool[i] end
    end
    return #out > 0 and out or pool
  end

  -- Choix d'une carte (récompense ou rencontre) : la mieux notée, ou aucune si l'ajouter nuirait au deck.
  local function pickCard(exp, opts, rng, cards)
    if opts.pick == "skip" or #cards == 0 then return nil end
    if opts.pick == "random" then return Rng.int(rng, 1, #cards) end
    local best, bestR, bestRaw = nil, -1, nil
    for i = 1, #cards do
      local r = rating(cards[i]) + Rng.float(rng) * 0.5
      if r > bestR then best, bestR, bestRaw = i, r, rating(cards[i]) end
    end
    if opts.pick ~= "always" and cardValue(exp, bestRaw) < 0 then return nil end
    return best
  end

  -- Cartes épiques (une seule dans le deck, docs/expedition.md) : note d'une épique dans ce deck. Extensible
  -- par classe : classDef.bot.epic = function(exp, id) -> note (nil : défaut), sinon la note de la carte
  -- (classDef.bot.rating), sinon SE.EPIC_RATING. Le bot prend la meilleure si elle vaut mieux que l'épique
  -- du deck de SE.EPIC_MARGIN (note de l'actuelle + SE.UPGRADED_BONUS si elle est améliorée).
  SE.EPIC_RATING = 7
  SE.EPIC_MARGIN = 0.5
  local function epicRating(exp, id)
    local b = botOf(exp)
    local v = b.epic and b.epic(exp, id)
    if v then return v end
    return ns.Run.RATING[id] or SE.EPIC_RATING
  end
  SE.epicRating = epicRating

  -- Gain (unités des rencontres) à prendre l'épique id : sa valeur, moins celle de l'épique remplacée (au
  -- plafond X.EPIC.max : la plus ancienne du deck, X.addCard).
  local function epicGain(exp, id)
    local i = X.epicFull(exp) and X.epicIndex(exp)
    local v = cardValue(exp, epicRating(exp, id))
    if i then
      local cur = exp.deck[i]
      v = v - cardValue(exp, epicRating(exp, cur.id) + (cur.up and SE.UPGRADED_BONUS or 0))
        - SE.EPIC_MARGIN * 2 * 10 / math.max(#exp.deck, 10) / SE.POINTS_PER_UNIT
    end
    return v
  end
  SE.epicGain = epicGain

  -- Choix « Epic » (épique tombée sur un élite) : index de l'épique à prendre, ou nil (refus). Épique imposée (epic=) :
  -- jamais remplacée, pour qu'elle soit mesurée sur toute l'expédition.
  local function pickEpic(exp, opts, rng, epics)
    if opts.pick == "skip" or opts.epic or #epics == 0 then return nil end
    if opts.pick == "random" then return Rng.int(rng, 1, #epics) end
    local best, bestV
    for i = 1, #epics do
      local v = epicGain(exp, epics[i])
      if not bestV or v > bestV then best, bestV = i, v end
    end
    if bestV < 0 then return nil end
    return best
  end

  -- Points d'extension des zones (Sim/zones/<zone>.lua) pour le bot hors combat :
  --   SE.KIND_SCORE[genre] = f(exp, hpRatio, gold) -> score d'une case de parcours de zone (X.NODE_KINDS ;
  --     repères : combat 1, rencontre 1,2, coffre 2 ; défaut : 1,2) ;
  --   SE.EFFECT_VALUE[nom] = f(exp, e) -> valeur d'un effet de rencontre ajouté (X.EFFECTS ; unités de
  --     effectsValue : 1 ≈ une potion) ;
  --   SE.CAMP_ACTION[id] = f(exp) -> valeur d'une action de feu de camp de zone, comparée au repos
  --     (≈ PV soignés × 0,15) et à l'amélioration (≈ 1) : prise si elle vaut plus.
  SE.KIND_SCORE, SE.EFFECT_VALUE, SE.CAMP_ACTION = {}, {}, {}
  -- Marchand sur le chemin : score 1,6, plus 1 par SE.RICH_STEP pièces au-delà de SE.RICH_GOLD (en or de Westfall :
  -- bourse divisée par X.priceFactor), au plus SE.RICH_MAX de plus. Un joueur qui a de quoi acheter cherche le
  -- marchand (à Westfall, la bourse dépasse rarement 150 avant le boss : routes presque inchangées).
  SE.RICH_GOLD, SE.RICH_STEP, SE.RICH_MAX = 150, 40, 5
  local kindExp -- expédition en cours de choix (cases de zone)

  -- Choix du chemin : meilleur score cumulé sur les chemins restants depuis chaque candidat.
  local function kindScore(kind, hpRatio, gold, removePrice)
    local ext = SE.KIND_SCORE[kind]
    if ext then return ext(kindExp, hpRatio, gold) end
    if ns.Expedition.NODE_KINDS[kind] then return 1.2 end
    if kind == "combat" then return 1.0 end
    if kind == "elite" then
      if hpRatio > 0.7 then return 2.0 end
      if hpRatio > 0.5 then return 0.3 end
      return -3.0
    end
    if kind == "campfire" then return hpRatio < 0.5 and 3.0 or 1.0 end
    if kind == "merchant" then
      if gold < math.min(removePrice, 60) then return 0.4 end
      -- bourse pleine (au prix de la zone : X.priceFactor) : il va chez le marchand plutôt que de la garder
      local rich = gold / (kindExp and X.priceFactor(kindExp) or 1)
      return 1.6 + math.max(0, math.min(SE.RICH_MAX, (rich - SE.RICH_GOLD) / SE.RICH_STEP))
    end
    if kind == "event" then return 1.2 end
    if kind == "chest" then return 2.0 end
    return 0
  end

  local function pathValue(exp, id, depth)
    local node = exp.map.nodes[id]
    local hpRatio = exp.hp / exp.maxHp
    local v = kindScore(node.kind, hpRatio, exp.gold, X.removePrice(exp)) * (0.85 ^ depth)
    local best = 0
    for i = 1, #node.next do
      local w = pathValue(exp, node.next[i], depth + 1)
      if i == 1 or w > best then best = w end
    end
    return v + best
  end

  local function choosePath(exp, choices)
    kindExp = exp
    local best, bestV
    for i = 1, #choices do
      local v = pathValue(exp, choices[i][2], 0)
      if not bestV or v > bestV then best, bestV = choices[i], v end
    end
    return best
  end

  -- Valeur estimée d'une liste d'effets de rencontre (le bot ne regarde pas les tirages
  -- figés : un pari vaut son espérance).
  local function effectsValue(exp, effects)
    local hpRatio = exp.hp / exp.maxHp
    local v = 0
    for _, e in ipairs(effects) do
      local k = e[1]
      if SE.EFFECT_VALUE[k] then v = v + SE.EFFECT_VALUE[k](exp, e)
      elseif k == "heal" then v = v + math.min(e[2], exp.maxHp - exp.hp) * 0.15
      elseif k == "healPct" then v = v + math.min(math.floor(exp.maxHp * e[2]), exp.maxHp - exp.hp) * 0.15
      elseif k == "loseHp" then v = v - math.min(e[2], exp.hp - 1) * 0.12 / math.max(hpRatio, 0.2)
      elseif k == "maxHp" then v = v + e[2] * 0.2
      elseif k == "loseMaxHp" then v = v - e[2] * 0.25
      elseif k == "gold" then v = v + e[2] * 0.03
      elseif k == "pay" or k == "loseGold" then v = v - e[2] * 0.03
      elseif k == "card" then
        -- carte imposée : sa valeur dans ce deck, négative si elle l'affaiblit (deck plein, decksize : en
        -- dessous du seuil d'entrée, elle coûte SE.DECKSIZE_UNWANTED)
        local r, th = rating(e[2]) + (e.up and SE.UPGRADED_BONUS or 0), capThreshold(exp)
        if th and r < th then v = v - SE.DECKSIZE_UNWANTED else v = v + cardValue(exp, r) end
      elseif k == "cardChoice" then
        -- une parmi n, ou passer : la meilleure espérée, jamais moins que rien (deck plein : rien sous le seuil)
        local r, th = expectedBest(choicePool(exp, e), e.n or 3), capThreshold(exp)
        if not th or r >= th then v = v + math.max(0, cardValue(exp, r)) end
      elseif k == "relic" then v = v + 3
      elseif k == "potion" then v = v + (X.freeSlot(exp) and 1 or 0)
      elseif k == "losePotion" then v = v - 1
      elseif k == "upgradeRandom" then v = v + 0.8 * e[2]
      elseif k == "upgrade" then v = v + 1
      elseif k == "remove" then v = v + (capFull(exp) and SE.DECKSIZE_REMOVE_VALUE or 1.2)
      elseif k == "dupe" then v = v + (capFull(exp) and 0 or 1.3)
      elseif k == "fight" then
        -- Récompense attendue contre PV perdus en moyenne (mesurés à clé +0 : normal ≈ 15,
        -- élite ≈ 20 ; à +3 : 20 et 35) ; un combat optionnel (surtout d'élite) devient un risque de mort
        -- avec la clé (Tyrannique).
        local elite = e.kind == "elite"
        local key = exp.key or 0
        local cost = elite and (20 + 5 * key) or (15 + 2 * key)
        local gain = (elite and 5.0 or 2.2) + (e.gold or 0) * 0.03
        if exp.hp - cost < 12 then
          v = v - 5
        else
          v = v + gain - cost * 0.12 / math.max(hpRatio, 0.2) - (elite and key or 0.3 * key)
        end
      elseif k == "gamble" then
        v = v + e[2] * effectsValue(exp, e.win or {}) + (1 - e[2]) * effectsValue(exp, e.lose or {})
      end
    end
    return v
  end

  local function eventValue(exp, ev, ci)
    return effectsValue(exp, ev.choices[ci].effects)
  end

  local function has(choices, verb)
    for i = 1, #choices do
      if choices[i][1] == verb then return choices[i] end
    end
    return nil
  end

  -- Marchand : coût d'un article en unités (0,03 par pièce, comme les rencontres), au prix de la zone : une pièce
  -- vaut moins là où tout coûte plus cher (X.priceFactor ; Westfall inchangée). Au-delà d'une réserve
  -- (SE.RESERVE pièces de Westfall, × X.priceFactor), l'or est un surplus qu'il ne saurait pas dépenser ailleurs :
  -- ses pièces ne valent que SE.SURPLUS_VALUE (un joueur qui a la bourse pleine achète) ; dans la dernière zone de
  -- l'expédition, il n'y a plus rien à garder pour plus tard (réserve nulle).
  SE.RESERVE, SE.SURPLUS_VALUE = 150, 0.2
  local function priceCost(exp, price)
    local f = X.priceFactor(exp)
    local reserve = X.nextZone(exp) and SE.RESERVE * f or 0
    local surplus = math.max(0, exp.gold - reserve)
    local cheap = math.min(price, surplus)
    return (cheap * SE.SURPLUS_VALUE + price - cheap) * 0.03 / f
  end
  SE.priceCost = priceCost
  -- Carte vendue déjà améliorée (shop.cards[i].up = palier) : note + SE.UPGRADED_BONUS, plus SE.SHOP_UP_VALUE unités
  -- (l'amélioration d'un feu de camp vaut ≈ 1 ; moitié, la carte n'étant piochée qu'une fois sur plusieurs), par palier.
  SE.SHOP_UP_VALUE = 0.5
  local function shopCardValue(exp, it, r)
    local n = Card.level(it.up)
    if n == 0 then return cardValue(exp, r) end
    return cardValue(exp, r + SE.UPGRADED_BONUS * n) + SE.SHOP_UP_VALUE * n
  end
  SE.shopCardValue = shopCardValue

  -- Action hors combat selon la phase.
  local function decide(exp, opts, rng)
    advice, adviceExp = adviceOf(exp), exp
    local ch = X.choices(exp)
    local ph = exp.phase
    if ph == "transit" then return { "continue" } end
    if ph == "start" then
      return has(ch, "startRelic") or { "skipStartRelic" }
    elseif ph == "map" then
      local paths = {}
      for i = 1, #ch do if ch[i][1] == "path" then paths[#paths + 1] = ch[i] end end
      return choosePath(exp, paths)
    elseif ph == "reward" then
      local r = exp.reward
      if r.epics and not r.epicDone then
        local i = pickEpic(exp, opts, rng, r.epics)
        if i then return { "pickEpic", i } end
        return { "skipEpic" }
      end
      if not r.cardsDone then
        local i = pickCard(exp, opts, rng, r.cards)
        if i then return { "pickCard", i } end
        return { "skipCards" }
      end
      if has(ch, "takePotion") then return { "takePotion" } end
      return { "leave" }
    elseif ph == "campfire" then
      local node = X.currentNode(exp)
      local nextBoss = false
      for _, nx in ipairs(node.next) do
        if exp.map.nodes[nx].kind == "boss" then nextBoss = true end
      end
      local ratio = exp.hp / exp.maxHp
      local up = bestUpgrade(exp)
      -- action de zone (SE.CAMP_ACTION) : prise si elle vaut plus que le repos et l'amélioration
      local bestA, bestAV
      for i = 1, #ch do
        local f = ch[i][1] == "campAction" and SE.CAMP_ACTION[ch[i][2]]
        if f then
          local v = f(exp)
          if not bestAV or v > bestAV then bestA, bestAV = ch[i], v end
        end
      end
      if bestA then
        local restV = math.min(math.floor(exp.maxHp * X.REST_FRACTION), exp.maxHp - exp.hp) * 0.15
        if bestAV > math.max(restV, up and 1 or 0) then return bestA end
      end
      if ratio < 0.5 or (nextBoss and ratio < 0.7) or not up then return { "rest" } end
      return { "upgrade", up }
    elseif ph == "merchant" then
      local s = exp.shop
      for i, it in ipairs(s.relics) do
        if not it.sold and exp.gold >= it.price then return { "buyRelic", i } end
      end
      local w, wv = worstCard(exp)
      if w and wv <= 1.5 and #exp.deck > 8 and exp.gold >= X.removePrice(exp) then return { "remove", w } end
      -- carte : celle dont la valeur dans le deck dépasse le plus son prix (0,03 par pièce, comme les
      -- rencontres)
      local best, bestR
      for i, it in ipairs(s.cards) do
        local v = (ns.Card.isEpic(ns.Cards[it.id]) and epicGain(exp, it.id) or shopCardValue(exp, it, rating(it.id)))
          - priceCost(exp, it.price)
        if not it.sold and exp.gold >= it.price and v > 0 and (not bestR or v > bestR) then
          best, bestR = i, v
        end
      end
      if best then return { "buyCard", best } end
      if X.freeSlot(exp) then
        for i, it in ipairs(s.potions) do
          if not it.sold and exp.gold >= it.price then return { "buyPotion", i } end
        end
      end
      return { "leave" }
    elseif ph == "event" then
      local ev = exp.event
      if not ev.id or ev.chosen then return { "leave" } end
      local def = ns.Events[ev.id]
      local best, bestV
      for i = 1, #ch do
        if ch[i][1] == "choose" then
          local v = eventValue(exp, def, ch[i][2])
          if not bestV or v > bestV then best, bestV = ch[i], v end
        end
      end
      return best or { "leave" }
    elseif ph == "select" then
      local i
      local kind = exp.select.kind
      if kind == "upgrade" then
        i = bestUpgrade(exp)
      elseif kind == "dupe" then
        -- Copie : la meilleure carte non basique, sinon on passe.
        local bestV = 0
        for j = 1, #exp.deck do
          local card = exp.deck[j]
          local r = ns.Cards[card.id].rarity
          local v = r ~= "basic" and r ~= "epic" and rating(card.id) + 0.5 * Card.level(card) or 0
          if v > bestV then i, bestV = j, v end
        end
      else
        i = worstCard(exp)
      end
      if i then return { "select", i } end
      return { "skipSelect" }
    end
    return ch[1]
  end

  ---------------------------------------------------------------------------
  -- Joueur humain hors combat (bot=human ; paramètres : Bots.humanParams, Sim/bots.lua). Mêmes repères que
  -- decide, avec un jugement approximatif : notes bruitées, goût des rares et des nouveautés, deck qui
  -- grossit, chemin vu de près, repos et amélioration au jugé, retrait rare. Hasard : flux « human ».
  local RARE_RANK = { common = 0, uncommon = 0.5, rare = 1, epic = 1 }
  local humanShop, humanRemove -- boutique en cours et décision de retrait tirée pour elle
  local humanRoute -- cases suivantes de la route qu'il s'est fixée (ids), ou nil

  -- Note perçue d'une carte offerte : note du bot de référence + bruit + goût des rares et des nouveautés.
  local function humanRating(exp, H, hrng, id)
    local d = ns.Cards[id]
    local r = rating(id) + H.pickNoise * Bots.gauss(hrng) + H.rareBonus * (RARE_RANK[d and d.rarity] or 0)
    local owned = false
    for i = 1, #exp.deck do if exp.deck[i].id == id then owned = true break end end
    if not owned then r = r + H.newBonus end
    return r
  end

  local function humanPickCard(exp, opts, H, hrng, cards)
    if opts.pick == "skip" or #cards == 0 then return nil end
    if opts.pick == "random" then return Rng.int(hrng, 1, #cards) end
    local best, bestR
    for i = 1, #cards do
      local r = humanRating(exp, H, hrng, cards[i])
      if not bestR or r > bestR then best, bestR = i, r end
    end
    if opts.pick ~= "always" and bestR < H.takeMin then return nil end
    -- deck plein (decksize) : seulement une carte nettement meilleure que celle qu'il retirerait d'abord
    local th = opts.pick ~= "always" and capThreshold(exp)
    if th and bestR < th then return nil end
    return best
  end

  -- Chemin : valeur des pathDepth étapes à venir (mêmes repères que pathValue) et la suite de cases qui la
  -- donne (sa route). Il se voit plus frais qu'il n'est (daring : part des PV max ajoutée à ses PV pour juger
  -- un élite) : il prend les élites plus tard dans la descente de ses PV.
  local function humanPathValue(exp, id, depth, H)
    local node = exp.map.nodes[id]
    local ratio = exp.hp / exp.maxHp
    if node.kind == "elite" then ratio = ratio + H.daring end
    local v = kindScore(node.kind, ratio, exp.gold, X.removePrice(exp)) * (0.85 ^ depth)
    if depth + 1 >= H.pathDepth then return v, { id } end
    local best, bestRoute = 0, nil
    for i = 1, #node.next do
      local w, r = humanPathValue(exp, node.next[i], depth + 1, H)
      if i == 1 or w > best then best, bestRoute = w, r end
    end
    local route = { id }
    for i = 1, #(bestRoute or {}) do route[i + 1] = bestRoute[i] end
    return v + best, route
  end

  -- Politique d'amélioration (H.upfocus, 0..1 ; Bots.HUMAN_RANGE) : 0 = il étale (note du palier visé, × 0,8
  -- puis × 0,6 : une carte neuve passe d'ordinaire devant) ; 1 = il concentre : il monte d'abord ses meilleures
  -- cartes jusqu'au plafond avant d'en améliorer d'autres (épique du deck en tête, puis la carte la plus montée,
  -- puis la meilleure note sans la décote des paliers) ; entre les deux, chaque choix concentre avec la chance
  -- upfocus et étale sinon (un tirage du flux « human » de plus, seulement quand 0 < upfocus < 1).
  -- SE.UPFOCUS_LEVEL : poids d'un palier déjà atteint (au-dessus de l'écart des notes, ≈ 0 à 14, et du bruit).
  SE.UPFOCUS_LEVEL = 20
  local function focusValue(exp, i, ei)
    local card = exp.deck[i]
    local up = botOf(exp).upgrade
    local v = advised("upgrade", card.id) or up and up[card.id] or rating(card.id)
    if type(v) == "table" then local n = Card.level(card) + 1 v = v[n] or v[#v] or 0 end
    local lvl = Card.level(card) + (i == ei and Card.MAX_UP + 1 or 0)
    return v + SE.UPFOCUS_LEVEL * lvl
  end

  local function humanUpgrade(exp, H, hrng)
    local best, bestV
    local f = H.upfocus or 0
    local focus = f >= 1 or (f > 0 and Rng.float(hrng) < f)
    local ei = focus and X.epicIndex(exp)
    for i = 1, #exp.deck do
      if X.canUpgrade(exp, i) then
        local v = focus and focusValue(exp, i, ei) or upgradeValue(exp, exp.deck[i])
        v = v + H.upNoise * Bots.gauss(hrng)
        if not bestV or v > bestV then best, bestV = i, v end
      end
    end
    return best
  end

  local function humanDecide(exp, opts, H, hrng)
    advice, adviceExp = adviceOf(exp), exp
    local ph = exp.phase
    if ph == "map" then
      kindExp = exp
      local ch = X.choices(exp)
      -- il suit la route choisie plus tôt, sans la revoir à chaque pas (replan : part des pas où il la revoit ;
      -- toujours sous la moitié de ses PV, moins daring)
      if humanRoute and Rng.float(hrng) >= H.replan and exp.hp >= exp.maxHp * (0.5 - H.daring) then
        local nextId = humanRoute[1]
        for i = 1, #ch do
          if ch[i][1] == "path" and ch[i][2] == nextId then
            table.remove(humanRoute, 1)
            if #humanRoute == 0 then humanRoute = nil end
            return ch[i]
          end
        end
      end
      local best, bestV, bestRoute
      for i = 1, #ch do
        if ch[i][1] == "path" then
          local v, route = humanPathValue(exp, ch[i][2], 0, H)
          v = v + H.pathNoise * Bots.gauss(hrng)
          if not bestV or v > bestV then best, bestV, bestRoute = ch[i], v, route end
        end
      end
      humanRoute = nil
      if bestRoute and #bestRoute > 1 then
        humanRoute = {}
        for i = 2, #bestRoute do humanRoute[i - 1] = bestRoute[i] end
      end
      return best
    elseif ph == "reward" then
      local r = exp.reward
      if r.epics and not r.epicDone then return nil end -- épique : comme le bot de référence
      if not r.cardsDone then
        local i = humanPickCard(exp, opts, H, hrng, r.cards)
        if i then return { "pickCard", i } end
        return { "skipCards" }
      end
      return nil
    elseif ph == "campfire" then
      local ch = X.choices(exp)
      for i = 1, #ch do
        if ch[i][1] == "campAction" then return nil end -- action de zone : jugée comme le bot de référence
      end
      local up = humanUpgrade(exp, H, hrng)
      local ratio = exp.hp / exp.maxHp
      -- seuil de repos au jugé ; le boss en vue, il se repose plus volontiers (+0,25)
      local at = H.restAt + 0.1 * Bots.gauss(hrng)
      for _, nx in ipairs(X.currentNode(exp).next) do
        if exp.map.nodes[nx].kind == "boss" then at = at + 0.25 end
      end
      if not up or ratio < at then return { "rest" } end
      return { "upgrade", up }
    elseif ph == "merchant" then
      local s = exp.shop
      -- deck plein (decksize) : retrait d'abord, autant de fois que l'or le permet, tant que le deck dépasse N
      -- ou qu'il est à N avec une carte de départ (valeur de retrait ≤ 1,5) ; jamais l'épique
      if capFull(exp) and #exp.deck > 8 and exp.gold >= X.removePrice(exp) then
        local w, wv = worstCard(exp, X.epicIndex(exp))
        if w and (#exp.deck > deckCap or wv <= 1.5) then return { "remove", w } end
      end
      for i, it in ipairs(s.relics) do
        if not it.sold and exp.gold >= it.price then return { "buyRelic", i } end
      end
      -- retrait : seulement s'il y pense (removeRate, tiré une fois par visite)
      if humanShop ~= s then
        humanShop = s
        humanRemove = Rng.float(hrng) < H.removeRate
      end
      local w, wv = worstCard(exp)
      if humanRemove and w and wv <= 1.5 and #exp.deck > 8 and exp.gold >= X.removePrice(exp) then
        return { "remove", w }
      end
      local best, bestR
      for i, it in ipairs(s.cards) do
        if not it.sold and exp.gold >= it.price then
          local v
          if ns.Card.isEpic(ns.Cards[it.id]) then
            v = epicGain(exp, it.id)
          else
            local r = humanRating(exp, H, hrng, it.id)
            local th = capThreshold(exp) -- deck plein (decksize) : seuil d'entrée
            v = r >= H.takeMin and (not th or r >= th) and shopCardValue(exp, it, math.max(r, 5.5)) or -1
          end
          v = v - priceCost(exp, it.price)
          if v > 0 and (not bestR or v > bestR) then best, bestR = i, v end
        end
      end
      if best then return { "buyCard", best } end
      if X.freeSlot(exp) then
        for i, it in ipairs(s.potions) do
          if not it.sold and exp.gold >= it.price then return { "buyPotion", i } end
        end
      end
      return { "leave" }
    elseif ph == "event" then
      local ev = exp.event
      if not ev.id or ev.chosen then return { "leave" } end
      local def = ns.Events[ev.id]
      local ch = X.choices(exp)
      local best, bestV
      for i = 1, #ch do
        if ch[i][1] == "choose" then
          local v = eventValue(exp, def, ch[i][2]) + H.eventNoise * Bots.gauss(hrng)
          if not bestV or v > bestV then best, bestV = ch[i], v end
        end
      end
      return best or { "leave" }
    elseif ph == "select" and exp.select.kind == "upgrade" then
      local i = humanUpgrade(exp, H, hrng)
      if i then return { "select", i } end
      return { "skipSelect" }
    elseif ph == "select" and exp.select.kind == "dupe" and capFull(exp) then
      return { "skipSelect" } -- deck plein (decksize) : pas de copie
    elseif ph == "select" and exp.select.kind == "remove" and deckCap then
      local i = worstCard(exp, X.epicIndex(exp)) -- decksize : jamais l'épique
      if i then return { "select", i } end
      return { "skipSelect" }
    end
    return nil -- le reste : comme le bot de référence
  end

  local function fight(exp, opts, record)
    local f, c = exp.fight, exp.combat
    local hpBefore, maxHpBefore = exp.hp, exp.maxHp -- PV à l'entrée (avant les effets de début de combat)
    local bot = Bots.new(opts.fightBot or opts.bot or "heuristic", Rng.stream(f.seed, "bot"),
      { cap = opts.cap, human = opts.humanH })
    local maxRounds = opts.maxRounds or 40
    local steps, stalled = 0, false
    while exp.phase == "combat" and exp.combat == c do
      if c.round > maxRounds or steps > 2000 then
        stalled = true
        X.act(exp, { "abandon" })
        break
      end
      local a = bot:act(c)
      steps = steps + 1
      if a[1] == "play" then
        if not X.act(exp, { "play", a[2], a[3], a[4] }) then Bots.markRetain(c) X.act(exp, { "endTurn" }) end
      elseif a[1] == "potion" then
        if not X.act(exp, a) then Bots.markRetain(c) X.act(exp, { "endTurn" }) end
      else
        Bots.markRetain(c) -- carte gardée au choix (Traveler's Backpack), posée avant la fin du tour
        X.act(exp, { "endTurn" })
      end
    end
    local st = c.stats
    record.combats[#record.combats + 1] = {
      kind = f.pool, encounter = table.concat(f.encounter, "+"), won = c.result == "won",
      turns = st.turns, hpBefore = hpBefore, hpAfter = math.max(c.player.hp, 0), maxHp = maxHpBefore,
      hpLost = st.hpLost, healed = st.healed, stalled = stalled,
      castsStarted = st.castsStarted, castsInterrupted = st.castsInterrupted,
      enemyCasts = st.enemyCasts, enemyCastsInterrupted = st.enemyCastsInterrupted,
      played = st.played, drawn = st.drawn, unplayed = st.unplayed, zoneStats = st.zone, potions = st.potions,
    }
  end

  function SE.play(opts)
    local seed = opts.seed or 1
    onlyPath = opts.path
    local level = opts.level or Meta.MAX_LEVEL
    -- zones=N : le compte et la classe ont gagné les N premières zones, à toutes les clés (commun, cartes
    -- de zone, bibelots de clé) ; meta=start = zones=0, meta=exalted = zones=7 (tout débloqué).
    local zones = opts.zones
    if zones == nil then zones = opts.meta == "exalted" and ns.Zone.count() or 0 end
    local unlocks = Meta.allUnlocked(level, zones)
    -- Drapeaux de compte : compte neuf sans zone gagnée (premier temps des histoires possible),
    -- compte vétéran dès une zone gagnée (premier temps vu, suite selon la parité de la graine).
    local flags = opts.flags
    if not flags then
      flags = {}
      if zones > 0 then
        for _, f in ipairs(SE.VETERAN_FLAGS) do flags[f] = true end
        local branch = SE.VETERAN_BRANCHES[seed % #SE.VETERAN_BRANCHES + 1]
        flags[branch] = true
      end
    end
    -- startZone / maxZone : diagnostic (départ ailleurs qu'à Westfall avec le deck de départ, arrêt après un
    -- boss) ; zone = une zone seule (les deux)
    local startZone = opts.startZone or opts.zone
    local maxZone = opts.maxZone or opts.zone
    local so, mo = ns.Zone.order(startZone), ns.Zone.order(maxZone)
    if so and mo and mo < so then maxZone = startZone end
    local exp = X.new({ seed = seed, class = opts.class or "priest", zone = startZone, lastZone = maxZone,
      key = opts.key or 0, unlocks = unlocks, flags = flags, stats = true, quiet = opts.quiet ~= false,
      epic = opts.epic ~= "none" and opts.epic or nil }) -- epic=none : aucune épique (le bot les refuse toutes)
    -- cartes ajoutées de force au deck de départ (sweep=cards, force=…)
    -- (force=id+2 : la carte au palier 2, SE.forced)
    for _, f in ipairs(opts.force or {}) do
      local id, n = SE.forced(f)
      exp.deck[#exp.deck + 1] = { id = id, up = Card.upValue(n) }
    end
    -- PV de départ essayés sans toucher aux données (hp=N : mesure de l'effet des PV de la classe)
    if opts.hp then exp.hp, exp.maxHp = opts.hp, opts.hp end
    local rng = Rng.stream(seed, "policy")
    -- bot=human : paramètres (opts.human = { skill = …, width = … }, Bots.humanParams) et flux de son jugement
    local H, hrng
    deckCap = nil
    if opts.bot == "human" then
      H = opts.humanH or Bots.humanParams(opts.human)
      opts.humanH = H
      hrng = Rng.stream(seed, "human")
      humanShop, humanRemove, humanRoute = nil, nil, nil
      if (H.decksize or 0) > 0 then deckCap = H.decksize end
    end
    -- flow : cartes entrées par source (récompense de combat ou de rencontre, épique, marchand, carte imposée par
    -- une rencontre, copie), récompenses de cartes offertes et refusées, retraits (marchand, rencontre), visites du
    -- marchand avec de quoi payer un retrait à l'entrée, rencontres offrant un retrait (rapport : « Cartes du deck »)
    local flow = { offered = 0, refused = 0, reward = 0, epic = 0, shop = 0, event = 0, dupe = 0, other = 0,
      removedShop = 0, removedEvent = 0, shopCanRemove = 0, eventCanRemove = 0 }
    local flowEvent -- dernière rencontre examinée (eventCanRemove)
    local record = { seed = seed, won = false, floor = 0, combats = {}, picks = {}, zones = {}, flow = flow }
    -- entrée dans chaque zone (après le soin du passage) : PV, PV max, taille du deck, épique au deck
    local function enterZone()
      record.zones[#record.zones + 1] = { zone = exp.zone, hp = exp.hp, maxHp = exp.maxHp, deck = #exp.deck,
        epic = X.epicCount(exp), gold = exp.gold, earned = exp.stats.goldEarned }
      humanRoute = nil -- route de l'ancienne carte
    end
    -- Visites du marchand (économie, docs/expedition.md) : or à l'entrée, prix de l'étal entier (cartes,
    -- bibelots, potions ; retrait non compris), articles achetés, retraits, or dépensé pendant la visite.
    record.shops = {}
    local visit, visitShop, spent0
    local function closeVisit()
      if not visit then return end
      local n, ep, up = 0, 0, 0
      for _, k in ipairs({ "cards", "relics", "potions" }) do
        for _, it in ipairs(visitShop[k] or {}) do
          if it.sold then
            n = n + 1
            if it.epic then ep = ep + 1 end
            if it.up then up = up + 1 end
          end
        end
      end
      visit.bought, visit.removed, visit.epicBought, visit.upBought = n, visitShop.removed or 0, ep, up
      visit.spent = exp.stats.goldSpent - spent0
      record.earnedAtLastShop = exp.stats.goldEarned
      visit, visitShop = nil, nil
    end
    local function watchShop()
      if visit and exp.phase ~= "merchant" then closeVisit() end
      if exp.phase == "merchant" and exp.shop ~= visitShop then
        closeVisit()
        visitShop, spent0 = exp.shop, exp.stats.goldSpent
        local total, items, up, epic = 0, 0, 0, 0
        for _, k in ipairs({ "cards", "relics", "potions" }) do
          for _, it in ipairs(exp.shop[k] or {}) do
            total, items = total + it.price, items + 1
            if it.up then up = up + 1 end
            if it.epic then epic = epic + 1 end
          end
        end
        visit = { zone = exp.zone, gold = exp.gold, total = total, items = items, up = up, epic = epic }
        record.shops[#record.shops + 1] = visit
        if exp.gold >= X.removePrice(exp) then flow.shopCanRemove = flow.shopCanRemove + 1 end
      end
    end
    enterZone()
    local guard = 0
    while exp.phase ~= "done" do
      if exp.zone ~= record.zones[#record.zones].zone then enterZone() end
      watchShop()
      guard = guard + 1
      if guard > 40000 then
        X.act(exp, { "abandon" })
        break
      end
      if exp.phase == "combat" then
        local a0 = exp.stats.cardsAdded
        fight(exp, opts, record)
        flow.other = flow.other + exp.stats.cardsAdded - a0
      else
        local before = exp.phase
        local a0, r0 = exp.stats.cardsAdded, exp.stats.removed
        local selKind = before == "select" and exp.select.kind
        if before == "event" and exp.event ~= flowEvent then
          -- rencontre qui propose un retrait (vue une fois)
          flowEvent = exp.event
          local def = exp.event.id and not exp.event.chosen and ns.Events[exp.event.id]
          for _, c in ipairs(def and def.choices or {}) do
            local found
            for _, e in ipairs(c.effects or {}) do if e[1] == "remove" then found = true end end
            if found then flow.eventCanRemove = flow.eventCanRemove + 1 break end
          end
        end
        local a = H and humanDecide(exp, opts, H, hrng) or decide(exp, opts, rng)
        if exp.phase == "reward" and a[1] == "pickCard" then
          record.picks[#record.picks + 1] = exp.reward.cards[a[2]]
        elseif exp.phase == "reward" and a[1] == "pickEpic" then
          record.picks[#record.picks + 1] = exp.reward.epics[a[2]]
        elseif a[1] == "upgrade" then
          record.picks[#record.picks + 1] = "up:" .. exp.deck[a[2]].id
        elseif a[1] == "rest" then
          record.picks[#record.picks + 1] = "rest"
        end
        local ok, why = X.act(exp, a)
        if not ok then error(("action refusée en phase %s : %s (%s)"):format(before, tostring(a[1]), tostring(why))) end
        if before == "reward" and (a[1] == "pickCard" or a[1] == "skipCards") then
          flow.offered = flow.offered + 1
          if a[1] == "skipCards" then flow.refused = flow.refused + 1 end
        end
        local src = before == "reward" and (a[1] == "pickEpic" and "epic" or "reward") or before == "merchant" and "shop"
          or before == "event" and "event" or selKind == "dupe" and "dupe" or "other"
        flow[src] = flow[src] + exp.stats.cardsAdded - a0
        local rk = before == "merchant" and "removedShop" or "removedEvent"
        flow[rk] = flow[rk] + exp.stats.removed - r0
      end
    end
    closeVisit()
    record.won = exp.result == "won"
    record.floor = exp.floor
    record.zone = exp.zone
    for i, z in ipairs(record.zones) do z.beaten = exp.beaten[i] == z.zone end
    record.hp = exp.hp
    record.deck = exp.deck
    record.gold = exp.gold
    record.goldEarned = exp.stats.goldEarned
    record.goldSpent = exp.stats.goldSpent
    record.relics = exp.relics
    record.visits = exp.stats.visits
    record.cleared = exp.stats.cleared
    record.xp = Meta.xpFor(exp)
    record.removed = exp.stats.removed
    record.upgraded = exp.stats.upgraded
    -- améliorations par palier atteint (stats.upTiers) et cartes du deck final par palier
    record.upTiers = { 0, 0, 0 }
    for n = 1, Card.MAX_UP do record.upTiers[n] = (exp.stats.upTiers or {})[n] or 0 end
    record.deckTiers = { 0, 0, 0 }
    for _, card in ipairs(exp.deck) do
      local n = Card.level(card)
      if n > 0 then record.deckTiers[n] = record.deckTiers[n] + 1 end
    end
    -- épique du deck en fin d'expédition (gagnée, achetée ou imposée) et son amélioration
    local ei = X.epicIndex(exp)
    record.epicEnd = ei and 1 or 0
    record.epicsEnd = X.epicCount(exp)
    record.epicUp = ei and exp.deck[ei].up and 1 or 0
    record.events = exp.stats.events -- { id = réponse choisie }
    return record, exp
  end

  -- Carte forcée au départ : "id" (palier 0), "id+" (palier 1) ou "id+N" (palier N, écrit) ; renvoie id, palier.
  function SE.forced(f)
    local id, plus = f:match("^(.-)%+(%d*)$")
    local n = 0
    if id then n = tonumber(plus) or 1 else id = f end
    assert(ns.Cards[id], "carte forcée inconnue : " .. id)
    assert(n <= Card.tiers(id), "palier " .. n .. " non écrit : " .. id)
    return id, n
  end

  return SE
end
