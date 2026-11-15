-- Bots joueurs pour la simulation.
--   random     : joue des cartes jouables au hasard jusqu'à ne plus pouvoir (et boit
--                parfois une potion au hasard).
--   greedy     : à chaque pas, la carte ou la potion dont le résultat (tour ennemi compris)
--                est le meilleur.
--   heuristic  : explore les suites de coups du tour (avec élimination des doublons),
--                simule le tour ennemi au bout de chacune, garde la meilleure ; essaie aussi
--                de commencer le tour par chaque potion disponible. Ne fait aucune erreur tactique.
--   human      : joueur humain correct (recherche courte, intentions lues, erreurs tirées au flux du bot) ;
--                la référence de la difficulté ressentie. Paramètres : Bots.humanParams (plus bas).
-- Interface : local bot = Bots.new(nom, rng, opts) ;
--   bot:act(c) -> { "play", idx, tIdx } | { "potion", emplacement, tIdx } | { "end" }
-- opts : cap (nœuds de recherche), potionKeep (multiplicateur de la valeur de garder une
--        potion : 1 par défaut, 0 au dernier combat de l'expédition), human (paramètres du bot human,
--        Bots.humanParams ; défaut : skill par défaut).
return function(ns)
  local Combat, Card, Rng = ns.Combat, ns.Card, ns.Rng
  local Bots = {}

  -- Conseils des zones (Sim/zones/<zone>.lua, chargés par Sim/load.lua) : ns.ZoneBots[id] = {
  --   value = f(c, W) -> nombre (ajouté à l'évaluation : Curse en main, dormeur, Wildfire…),
  --   key = f(c) -> chaîne (état de zone qui distingue deux positions),
  --   skip = f(c, a) -> vrai pour ne pas essayer le coup a = { indexMain, indexCible|nil, sansDépense }
  --          (cible à éviter, carte nuisible ; le bot peut encore finir son tour sans) }.
  -- Actifs pour un combat : sa zone (c.zone) et les zones dont les règles y sont actives (c.zr).
  ns.ZoneBots = ns.ZoneBots or {}
  local function zoneBots(c)
    local list
    local zr = c.zr
    if c.zone and ns.ZoneBots[c.zone] then list = { ns.ZoneBots[c.zone] } end
    if zr then
      for i = 1, #zr do
        local zb = ns.ZoneBots[zr[i]]
        if zb and zr[i] ~= c.zone then
          list = list or {}
          list[#list + 1] = zb
        end
      end
    end
    return list
  end
  Bots.zoneBots = zoneBots

  -- Évaluation d'un état après le tour ennemi. Poids grossiers, à régler.
  local W = { hp = 10, enemyHp = 4, enemyAlive = 30, res = 1.5, atonement = 4,
    regen = 0.5, power = 25, castRisk = 0.95, force = 25 }
  Bots.W = W

  -- Valeur de garder une potion pour plus tard (unités de W : 10 = 1 PV). Une potion n'est
  -- bue que si elle rapporte plus ce tour-ci : éviter la mort, débloquer un gros tour...
  Bots.POTION_KEEP = { healing_potion = 180, mana_potion = 60, shadow_protection = 100,
    liquid_fire = 60, wisdom_elixir = 50 }
  Bots.potionKeep = 1

  local function potionsValue(c)
    local v = 0
    local pots = c.player.potions
    for i = 1, #pots do
      if pots[i] then v = v + (Bots.POTION_KEEP[pots[i]] or 60) end
    end
    return v * Bots.potionKeep
  end

  -- Part des cartes du combat qui vérifient pred (main, pioche, défausse, recharges, consumées).
  -- (sans closure créée à chaque appel : LuaJIT ne compile pas FNEW)
  local function shareScan(list, pred, n, k)
    for i = 1, #list do
      n = n + 1
      if pred(Card.def(list[i])) then k = k + 1 end
    end
    return n, k
  end
  local function deckShare(c, pred)
    local n, k = shareScan(c.hand, pred, 0, 0)
    n, k = shareScan(c.draw, pred, n, k)
    n, k = shareScan(c.discard, pred, n, k)
    n, k = shareScan(c.exhaust, pred, n, k)
    for i = 1, #c.cooldown do
      n = n + 1
      if pred(Card.def(c.cooldown[i].card)) then k = k + 1 end
    end
    if n == 0 then return 0 end
    return k / n
  end

  -- Valeur d'un Pouvoir en jeu (unités de W : 10 = 1 PV, 4 = 1 PV ennemi). Chaque estimation suit le texte
  -- de la carte avec les mêmes repères : environ POWER_TURNS tours encore à jouer, POWER_PLAYS cartes jouées
  -- par tour, et la part du deck du combat qui profite du Pouvoir (deckShare). Fonction (c, inst) ; un
  -- Pouvoir absent de la table vaut W.power × (1 + coût), à défaut de mieux (classe à venir).
  -- Tours restants : la longueur attendue du combat (PV max de tous ses ennemis / POWER_DPT, constante
  -- pendant le combat : tuer plus vite ne fait pas perdre de valeur au Pouvoir) moins les tours déjà
  -- joués, entre 0,5 et POWER_TURNS. Un Pouvoir posé au dernier tour d'un combat court ne vaut presque rien.
  Bots.POWER_TURNS, Bots.POWER_PLAYS, Bots.POWER_DPT = 5, 3.5, 15
  local P = Bots.POWER_PLAYS
  local T -- tours restants du combat évalué (posé par powersValue)
  local function turnsLeft(c)
    local hp = 0
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      hp = hp + (e.minion and 0.5 or 1) * (e.maxHp or e.hp)
    end
    local t = hp / Bots.POWER_DPT - ((c.round or 1) - 1)
    if t < 0.5 then t = 0.5 elseif t > Bots.POWER_TURNS then t = Bots.POWER_TURNS end
    return t
  end
  local function anyEffect(d, pred)
    for i = 1, #d.effects do if pred(d.effects[i]) then return true end end
    return false
  end
  local function isAttack(d) return d.type == "attack" end
  -- prédicats sur les effets et les fiches : fonctions fixes (une closure créée à chaque appel arrête la
  -- compilation de LuaJIT, FNEW)
  local function effDamage(e) return e[1] == "damage" end
  local function effDot(e) return (e[1] == "apply" and e[2] == "pain") or e[1] == "dotPer" end
  local function effStealth(e)
    if e.cond == "stealth" then return true end
    for j = 1, #(e.more or {}) do if e.more[j][2] == "stealth" then return true end end
    return false
  end
  local function effPet(e) return e[1] == "pet" end
  local function dealsDamage(d) return anyEffect(d, effDamage) end
  local function appliesDot(d) return anyEffect(d, effDot) end
  local function readsStealth(d) return anyEffect(d, effStealth) end
  local function petCard(d) return anyEffect(d, effPet) end
  local function isTrap(d) return d.trap == true end
  local function isFire(d) return d.school == "fire" and dealsDamage(d) end
  local function isFireSchool(d) return d.school == "fire" end
  local function isDamagingAttack(d) return isAttack(d) and dealsDamage(d) end
  local function isShadow(d) return d.school == "shadow" end
  local function isCast(d) return d.cast end
  local function givesAbsorb(d)
    for i = 1, #d.effects do if d.effects[i][1] == "absorb" then return true end end
    return false
  end
  local function aliveCount(c)
    local n = 0
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      if not e.dead then n = n + (e.minion and 0.5 or 1) end
    end
    return n
  end
  -- cartes du genre jouées par tour, au plus une
  local function perTurn(c, pred) return math.min(1, P * deckShare(c, pred)) end
  -- cartes du genre jouées par tour
  local function playsOf(c, pred) return P * deckShare(c, pred) end
  -- Last Breath : vaut d'autant plus que les PV manquent (repris de Spirit of Redemption)
  local function lastBreath(c)
    local miss = 1 - c.player.hp / c.player.maxHp
    return 25 + 150 * miss * miss
  end
  -- DoT n ajouté à une pile : environ 2,5 tics de plus par point, à 0,8 (la cible meurt parfois avant)
  local function dotUnits(n) return n * 2.5 * 0.8 * W.enemyHp end
  local MANA = 6 * W.enemyHp -- un point de mana ≈ une carte de 6 dégâts
  -- valeur de base / améliorée d'un Power ; up(inst, a, b, c2, c3) : c2, c3 = paliers 2 et 3 (sinon b)
  -- (docs/ameliorations.md : un palier 2 ou 3 d'un Power qui change sa valeur se déclare ici)
  local function up(inst, a, b, c2, c3)
    local n = inst and Card.level(inst) or 0
    if n >= 3 and c3 then return c3 end
    if n >= 2 and c2 then return c2 end
    return n >= 1 and b or a
  end

  Bots.POWER_VALUE = {
    -- Rogue
    blade_flurry = function(c, inst)
      return T * playsOf(c, isAttack) * up(inst, 2, 3, 3, 4) * aliveCount(c) * W.enemyHp
    end,
    deadly_poison = function(c)
      return T * playsOf(c, isAttack) * 1.3 * dotUnits(1)
    end,
    venomous_wounds = function(c)
      return T * aliveCount(c) * math.min(1, 0.2 + 2 * deckShare(c, appliesDot)) * 1.5 * Bots.resValue(c)
    end,
    slice_and_dice = function(c) return T * perTurn(c, isAttack) * MANA end,
    shadow_dance = function(c, inst)
      return T * (perTurn(c, readsStealth) * 8 * W.enemyHp + up(inst, 0, 0, 0, 1) * Bots.resValue(c))
    end,
    cheat_death = lastBreath,
    -- Warrior
    deep_wounds = function(c, inst) return T * playsOf(c, isAttack) * dotUnits(up(inst, 2, 3)) end,
    enrage = function(c) return T * 0.7 * W.force end,
    retaliation = function(c, inst) return T * aliveCount(c) * 0.8 * up(inst, 4, 6) * W.enemyHp end,
    last_stand = lastBreath,
    -- Mage
    hot_streak = function(c) return T * math.min(1, playsOf(c, isFireSchool) / 2) * 20 end,
    ignite = function(c, inst) return T * playsOf(c, isFire) * dotUnits(up(inst, 2, 3)) end,
    shatter = function(c, inst) return T * playsOf(c, isAttack) * 0.5 * up(inst, 3, 4) * W.enemyHp end,
    arcane_power = function(c)
      return T * playsOf(c, isDamagingAttack) * 2 * W.enemyHp
    end,
    ice_block = lastBreath,
    -- Hunter
    spirit_bond = function(c) return T * (1 + playsOf(c, petCard)) * 2 * W.hp * 0.5 end,
    the_beast_within = function(c)
      local pet = ns.Hunter and ns.Hunter.petDamage(c) or 3
      return T * playsOf(c, isAttack) * (pet + 0.5) * W.enemyHp
    end,
    trueshot_aura = function(c, inst) return T * playsOf(c, isAttack) * 0.5 * up(inst, 4, 6) * W.enemyHp end,
    entrapment = function(c) return T * perTurn(c, isTrap) * 12 end,
    lock_and_load = function(c) return T * perTurn(c, isTrap) * 20 end,
    resourcefulness = function(c) return T * perTurn(c, isTrap) * 25 end,
    feign_death = lastBreath,
    -- Carte neutre
    elixir_of_superior_defense = function(c, inst) return T * up(inst, 3, 4) * W.hp * 0.8 end,
    -- Priest
    shadowform = function(c)
      local sh = deckShare(c, isShadow)
      return 10 + 9 * sh * 5 * W.enemyHp
    end,
    apotheosis = function(c)
      return 4 * 6 * W.enemyHp + 9 * deckShare(c, isCast) * 5 * W.enemyHp
    end,
    rapture = function(c)
      local share = deckShare(c, givesAbsorb)
      return 10 + 9 * share * 2 * W.hp
    end,
    spirit_of_redemption = function(c)
      local miss = 1 - c.player.hp / c.player.maxHp
      return 25 + 150 * miss * miss
    end,
  }

  local function powersValue(c)
    local v = 0
    local powers = c.player.powers
    if #powers > 0 then T = turnsLeft(c) end
    for i = 1, #powers do
      local f = Bots.POWER_VALUE[powers[i].id]
      if f then v = v + f(c, powers[i])
      else v = v + W.power * (1 + (Card.def(powers[i]).cost or 1)) end
    end
    return v
  end

  -- Valeur attendue d'une incantation en cours (résolue au prochain tour).
  function Bots.castValue(c)
    local p = c.player
    local d = Card.def(p.cast.card)
    local alive = 0
    for i = 1, #c.enemies do if not c.enemies[i].dead then alive = alive + 1 end end
    local v = 0
    for i = 1, #d.effects do
      local e = d.effects[i]
      if e[1] == "damage" then
        v = v + e[2] * (e.times or 1) * (e.all and alive or 1) * W.enemyHp
      elseif e[1] == "heal" then
        v = v + math.min(e[2], p.maxHp - p.hp) * W.hp
      elseif e[1] == "apply" and e[2] == "pain" then
        v = v + e[3] * (e[3] + 1) / 2 * 0.8 * W.enemyHp
      elseif e[1] == "apply" and e[2] == "regen" then
        v = v + math.min(e[3] * (e[3] + 1) / 2, p.maxHp - p.hp) * W.hp * W.regen
      elseif e[1] == "absorb" then
        v = v + e[2] * W.hp * 0.5
      end
    end
    return v * W.castRisk
  end

  -- Valeur d'un point de ressource de classe (conseil de la classe : classDef.bot.resValue).
  local function resValue(c)
    local cd = ns.Classes[c.class]
    return cd and cd.bot and cd.bot.resValue or W.res
  end
  Bots.resValue = resValue

  local function evaluate(c)
    if c.result == "lost" then return -1e9 end
    local p = c.player
    if c.result == "won" then return 1e6 + p.hp * 100 + potionsValue(c) * 10 end
    local s = p.hp * W.hp + potionsValue(c)
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      if not e.dead then
        local pain = e.st.pain or 0
        local painDmg = pain * (pain + 1) / 2
        local ehp = e.hp - painDmg * 0.8
        if ehp < 0 then ehp = 0 end
        if e.minion then
          -- Les sbires fuient à la mort du chef : les compter plein faisait refuser au bot
          -- de passer le seuil d'invocation (VanCleef à 50 %) pendant que le boss se renforçait.
          s = s - (ehp + e.block * 0.5) * W.enemyHp * 0.5 - W.enemyAlive * 0.3
        else
          s = s - (ehp + e.block * 0.5) * W.enemyHp - W.enemyAlive
        end
        if (e.st.stunned or 0) > 0 then s = s + 15 end
      end
    end
    local regen = p.st.regen or 0
    local selfPain = p.st.pain or 0
    s = s + (p.res or 0) * resValue(c) + (p.st.atonement or 0) * W.atonement
      + math.min(regen * (regen + 1) / 2, p.maxHp - p.hp) * W.hp * W.regen + powersValue(c)
      - selfPain * (selfPain + 1) / 2 * W.hp * 0.8
    if p.cast then s = s + Bots.castValue(c) end
    -- Strength du joueur (Guerrier) : environ six coups encore à porter dans le combat
    s = s + (p.st.force or 0) * W.force
    -- valeur propre à la classe (état de classe, familier, formes…) : ns.ClassRules[classe].botValue
    local cr = ns.ClassRules[c.class]
    if cr and cr.botValue then s = s + cr.botValue(c, W) end
    -- valeur propre aux zones (ns.ZoneBots[zone].value)
    local zb = zoneBots(c)
    if zb then
      for i = 1, #zb do if zb[i].value then s = s + zb[i].value(c, W) end end
    end
    return s
  end
  Bots.evaluate = evaluate

  -- Score d'une fin de tour : on joue le tour ennemi sur une copie (inPlace : s est une copie jetable,
  -- plus jamais lue ensuite, jouée sur place sans la recopier).
  local function leafScore(s, inPlace)
    if s.result then return evaluate(s) end
    local t = inPlace and s or Combat.clone(s)
    Combat.endPlayerTurn(t)
    if not t.result then Combat.enemyPhase(t) end
    return evaluate(t)
  end
  Bots.leafScore = leafScore

  local function stateKey(c)
    local p = c.player
    local parts = { p.mana, p.hp, p.block, p.res, p.cast and p.cast.card.id or "-",
      p.st.atonement or 0, p.st.halved or 0, p.st.regen or 0, #p.powers, #c.cooldown, #c.exhaust,
      p.st.pain or 0 }
    local ids = {}
    for i = 1, #c.hand do
      local h = c.hand[i]
      ids[i] = h.id .. Card.suffix(h.up) -- palier compris (+, +2, +3)
    end
    table.sort(ids)
    parts[#parts + 1] = table.concat(ids, ",")
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      parts[#parts + 1] = e.dead and "x" or (e.hp .. ":" .. e.block .. ":" .. (e.st.pain or 0) .. ":"
        .. (e.st.armor_broken or 0) .. ":" .. (e.st.stunned or 0) .. ":" .. (e.interrupted and 1 or 0)
        .. ":" .. (e.st.demoralized or 0))
    end
    parts[#parts + 1] = c.result or ""
    -- état propre à la classe qui distingue deux positions (ns.ClassRules[classe].botKey)
    local cr = ns.ClassRules[c.class]
    if cr and cr.botKey then parts[#parts + 1] = cr.botKey(c) end
    local zb = zoneBots(c)
    if zb then
      for i = 1, #zb do if zb[i].key then parts[#parts + 1] = zb[i].key(c) end end
    end
    return table.concat(parts, "|")
  end

  local function actionRef(c, a)
    local inst = c.hand[a[1]]
    return { uid = inst.uid, target = a[2] and c.enemies[a[2]].uid, nospend = a[3] or nil }
  end

  local function resolveRef(c, ref)
    if ref.potion then
      local slot
      for i = 1, #c.player.potions do
        if c.player.potions[i] == ref.potion then slot = i break end
      end
      if not slot then return nil end
      local tIdx
      if ref.target then
        local e, j = Combat.enemyByUid(c, ref.target)
        if not e or e.dead then return nil end
        tIdx = j
      end
      if not Combat.canUsePotion(c, slot, tIdx) then return nil end
      return { "potion", slot, tIdx }
    end
    local idx
    for i = 1, #c.hand do
      if c.hand[i].uid == ref.uid then idx = i break end
    end
    if not idx or not Combat.canPlay(c, idx) then return nil end
    local tIdx
    if ref.target then
      local e, j = Combat.enemyByUid(c, ref.target)
      if not e or e.dead then return nil end
      tIdx = j
    elseif Combat.needsTarget(c.hand[idx], c) then
      return nil
    end
    return { "play", idx, tIdx, ref.nospend and "nospend" or nil }
  end

  -- Recherche en profondeur des suites de coups du tour.
  function Bots.planTurn(c, cap)
    cap = cap or 400
    local best, bestSeq = -math.huge, {}
    local nodes = 0
    local seen = {}
    local seq = {}
    -- Score de fin de tour de s noté APRÈS ses suites : s n'est plus lu ensuite, son tour ennemi se joue sur
    -- place (sauf la position de départ). Le meilleur reste le premier dans l'ordre de visite (s avant ses
    -- suites) : s le prend s'il bat tout ce qui précède (bestBefore) et égale au moins ses suites.
    local function score(s, bestBefore)
      local sc = leafScore(s, s ~= c)
      if sc > bestBefore and sc >= best then
        best = sc
        bestSeq = {}
        for i = 1, #seq do bestSeq[i] = seq[i] end
      end
    end
    local function dfs(s)
      nodes = nodes + 1
      local bestBefore = best
      if s.result or nodes >= cap then return score(s, bestBefore) end
      local acts = Combat.legalPlays(s)
      local tried = {}
      local zb = zoneBots(s)
      for i = 1, #acts do
        local a = acts[i]
        local inst = s.hand[a[1]]
        local key = inst.id .. Card.suffix(inst.up) .. ":" .. (a[2] or 0) .. (a[3] and ":nospend" or "")
        if zb then
          for j = 1, #zb do
            if zb[j].skip and zb[j].skip(s, a) then tried[key] = true end
          end
        end
        if not tried[key] then
          tried[key] = true
          local t = Combat.clone(s)
          Combat.play(t, a[1], a[2], a[3] and { spend = false } or nil)
          local k = stateKey(t)
          if not seen[k] then
            seen[k] = true
            seq[#seq + 1] = actionRef(s, a)
            dfs(t)
            seq[#seq] = nil
          end
          if nodes >= cap then break end
        end
      end
      score(s, bestBefore)
    end
    dfs(c)
    return bestSeq, nodes, best
  end

  -- Plan du tour, en essayant aussi de boire d'abord chacune des potions disponibles.
  function Bots.planWithPotions(c, cap)
    local bestSeq, nodes, best = Bots.planTurn(c, cap)
    local pots = Combat.legalPotions(c)
    for i = 1, #pots do
      local a = pots[i]
      local t = Combat.clone(c)
      Combat.usePotion(t, a[1], a[2])
      local seq, n, sc = Bots.planTurn(t, cap)
      nodes = nodes + n
      if sc > best then
        best = sc
        bestSeq = { { potion = c.player.potions[a[1]], target = a[2] and c.enemies[a[2]].uid } }
        for j = 1, #seq do bestSeq[j + 1] = seq[j] end
      end
    end
    return bestSeq, nodes, best
  end

  -- Carte gardée au choix en fin de tour (Traveler's Backpack, Combat.retainPicks) : uid de la carte de la
  -- main (hors Retain) la mieux notée par la classe (bot.rating, 5 par défaut ; +1 améliorée, +0,5 par
  -- point de coût : une carte chère qui n'a pas pu partir), la première à égalité ; nil sans choix.
  -- Zandalarian Hero Charm porté (la carte gardée coûte 1 de moins au tour suivant) : +2 aux cartes de coût 1
  -- ou plus, pour que la réduction serve.
  function Bots.retainPick(c)
    local list = Combat.retainCandidates(c)
    if #list == 0 then return nil end
    local cd = ns.Classes[c.class]
    local rating = cd and cd.bot and cd.bot.rating or {}
    local charm = false
    for _, id in ipairs(c.relics) do if id == "zandalarian_hero_charm" then charm = true end end
    local best, bestUid
    for _, i in ipairs(list) do
      local inst = c.hand[i]
      local d = Card.def(inst)
      local v = (rating[inst.id] or 5) + Card.level(inst) + 0.5 * (d.cost or 0)
      if charm and (d.cost or 0) >= 1 then v = v + 2 end
      if not best or v > best then best, bestUid = v, inst.uid end
    end
    return bestUid
  end

  -- Fin du tour par un bot : pose d'abord son choix de carte gardée, s'il y en a un.
  function Bots.markRetain(c)
    local uid = Bots.retainPick(c)
    if uid then Combat.markRetain(c, uid) end
    return uid
  end

  ---------------------------------------------------------------------------
  -- Joueur humain correct (bot=human) : la référence de la difficulté ressentie (docs/equilibrage.md).
  -- Il ne voit pas toutes les suites du tour : à chaque carte, il regarde les `width` meilleurs coups (au
  -- coup d'œil), les suit sur `depth` cartes au plus, et joue le premier coup de la meilleure suite. Il lit
  -- les intentions affichées (dégâts × coups contre son Block, interruption) au lieu de jouer le tour ennemi :
  -- ni DoT, ni états, ni règles de zone, ni phases de boss, sauf aux tours où il réfléchit à fond (part
  -- `foresight`). Il ne compte qu'en partie (`combo`) le Combo ou la ressource laissés pour le tour suivant.
  -- Il se trompe parfois (`slip`) : un autre coup que le meilleur, tiré parmi ceux qui ne s'en écartent pas
  -- de plus de `tol` (unités de W : 10 = 1 PV). Il garde ses potions (`hoard` × leur valeur de réserve).
  -- Hors combat (Sim/expedition.lua) : notes des cartes bruitées (`pickNoise`), goût des rares (`rareBonus`)
  -- et des cartes nouvelles (`newBonus`), carte prise dès que sa note perçue atteint `takeMin` (deck qui
  -- grossit), chemin vu sur `pathDepth` étapes et bruité (`pathNoise`), route suivie sans la revoir sauf
  -- une fois sur `1 / replan` (ou sous la moitié des PV), élites jugés comme s'il avait `daring` PV max de
  -- plus, repos sous `restAt` des PV max (+0,25 avant le boss), amélioration bruitée (`upNoise`), retrait au
  -- marchand une visite sur `1 / removeRate`, rencontres bruitées (`eventNoise`).
  -- Tous se déduisent de `skill` (0 = débutant, 0,5 = joueur correct, 1 = expert ; HUMAN_RANGE : valeurs à
  -- 0, 0,5 et 1, interpolées par morceaux) et chacun peut être imposé (sim.lua : skill=0.3 width=2 …). Hasard :
  -- le flux du bot (combat) et le flux « human » de l'expédition, jamais math.random. Valeurs à 0,5 (défaut)
  -- calées le 13/11/2026 sur le journal du joueur (Westfall clé 0 : ≈ 20–25 % de victoires pour les cinq
  -- classes ; docs/equilibrage.md, « Bot human »).
  Bots.HUMAN_SKILL = 0.5
  Bots.HUMAN_RANGE = {
    width = { 2, 3, 4 }, depth = { 2, 3, 5 }, foresight = { 0.2, 0.7, 1 }, slip = { 0.4, 0.25, 0 },
    tol = { 80, 60, 20 }, combo = { 0.2, 0.6, 1 }, hoard = { 3, 1.75, 1 },
    pickNoise = { 3, 1.65, 0.3 }, rareBonus = { 2, 1, 0 }, newBonus = { 1.5, 0.75, 0 }, takeMin = { 2, 3.5, 5 },
    pathDepth = { 1, 5, 8 }, pathNoise = { 1.5, 0.8, 0.1 }, replan = { 0, 0.5, 1 }, daring = { 0.3, 0.15, 0 },
    restAt = { 0.3, 0.4, 0.5 }, upNoise = { 3, 1.65, 0.3 }, removeRate = { 0, 0.5, 1 }, eventNoise = { 2, 1.1, 0.2 },
  }
  Bots.HUMAN_INT = { width = true, depth = true, pathDepth = true }

  -- Paramètres du bot human : over = { skill = …, width = … } (nombres), le reste déduit de skill.
  function Bots.humanParams(over)
    over = over or {}
    local s = tonumber(over.skill) or Bots.HUMAN_SKILL
    if s < 0 then s = 0 elseif s > 1 then s = 1 end
    local H = { skill = s }
    for k, r in pairs(Bots.HUMAN_RANGE) do
      local v = tonumber(over[k])
      if not v then
        if s <= 0.5 then v = r[1] + (r[2] - r[1]) * s * 2 else v = r[2] + (r[3] - r[2]) * (s - 0.5) * 2 end
        if Bots.HUMAN_INT[k] then v = math.floor(v + 0.5) end
      end
      H[k] = v
    end
    return H
  end

  -- Tirage normal centré réduit (Box-Muller) sur un flux ns.Rng.
  function Bots.gauss(rng)
    local u = Rng.float(rng)
    if u < 1e-9 then u = 1e-9 end
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * Rng.float(rng))
  end

  -- Tour ennemi lu sur les intentions : chaque ennemi vivant et non étourdi frappe de ses dégâts affichés
  -- (Combat.intentInfo) contre le Block, coupe l'incantation s'il l'annonce ; le Block ennemi tombe.
  local function readIntents(t)
    local p = t.player
    local dmg = 0
    for i = 1, #t.enemies do
      local e = t.enemies[i]
      if not e.dead then
        e.block = 0
        local def = ns.Enemies[e.id]
        if (e.st.stunned or 0) == 0 and def and e.intent and def.moves[e.intent] then
          local info = Combat.intentInfo(t, e)
          dmg = dmg + info.damage * math.max(info.times, info.damage > 0 and 1 or 0)
          if info.interrupts and not info.interrupted and p.cast then p.cast, p.castMore = nil, nil end
        end
      end
    end
    local through = dmg - p.block
    if through > 0 then
      p.block = 0
      p.hp = p.hp - through
      if p.hp <= 0 then t.result = "lost" end
    else
      p.block = -through
    end
  end
  Bots.readIntents = readIntents

  -- Score d'une fin de tour pour le joueur humain : real = tour ennemi joué (réflexion à fond), sinon lu.
  -- inPlace : t est une copie jetable (plus jamais lue ensuite), jouée sur place sans la recopier.
  local function humanLeaf(s, H, real, inPlace)
    if s.result then return evaluate(s) end
    local t = inPlace and s or Combat.clone(s)
    Combat.endPlayerTurn(t)
    if not t.result then
      if real then Combat.enemyPhase(t) else readIntents(t) end
    end
    local v = evaluate(t)
    if not t.result and H.combo < 1 then v = v - (1 - H.combo) * (t.player.res or 0) * resValue(t) end
    return v
  end
  Bots.humanLeaf = humanLeaf

  -- Coups joués d'une position (doublons et conseils de zone écartés comme planTurn), dans l'ordre des coups
  -- légaux : rec = { acts = coups légaux { indexMain, indexCible|nil, sansDépense|nil }, v = score de fin de
  -- tour juste après chacun (coup d'œil), s = état après chacun (keep ; sinon fin de tour jouée sur place et
  -- état non gardé, refait par humanState s'il faut le développer) }.
  local function humanPlays(s, H, real, keep)
    local acts = Combat.legalPlays(s)
    local list, vs, ss = {}, {}, keep and {} or nil
    local tried = {}
    local zb = zoneBots(s)
    for i = 1, #acts do
      local a = acts[i]
      local inst = s.hand[a[1]]
      local key = inst.id .. Card.suffix(inst.up) .. ":" .. (a[2] or 0) .. (a[3] and ":nospend" or "")
      if zb then
        for j = 1, #zb do
          if zb[j].skip and zb[j].skip(s, a) then tried[key] = true end
        end
      end
      if not tried[key] then
        tried[key] = true
        local t = Combat.clone(s)
        Combat.play(t, a[1], a[2], a[3] and { spend = false } or nil)
        local n = #list + 1
        list[n] = a
        vs[n] = humanLeaf(t, H, real, not keep)
        if keep then ss[n] = t end
      end
    end
    return { acts = list, v = vs, s = ss }
  end

  -- État après le coup k de rec (position s) : gardé, sinon rejoué (même coup sur une copie de s : même état).
  local function humanState(s, rec, k)
    local ss = rec.s
    if ss and ss[k] then return ss[k] end
    local a = rec.acts[k]
    local t = Combat.clone(s)
    Combat.play(t, a[1], a[2], a[3] and { spend = false } or nil)
    if not ss then ss = {} rec.s = ss end
    ss[k] = t
    return t
  end

  local function byValue(x, y) return x.v > y.v end

  -- Coups de rec triés du meilleur au moins bon : { k = rang dans rec, v }. Même liste d'entrée, dans le
  -- même ordre, que l'ancien tri des coups : même ordre de sortie, égalités comprises.
  local function sortedPlays(rec)
    local out, vs = {}, rec.v
    for k = 1, #vs do out[k] = { k = k, v = vs[k] } end
    table.sort(out, byValue)
    return out
  end

  -- Meilleur score atteignable depuis s en d coups de plus, parmi les width meilleurs coups à chaque pas.
  -- memo : position → rec (humanPlays) déjà calculé, gardé d'un coup à l'autre du même tour (BotMT:act) : le
  -- coup joué arrive sur une position déjà explorée au coup précédent.
  -- Dernier pas (d = 1) : les coups suivis ne sont plus développés, la meilleure suite vaut le meilleur coup
  -- au coup d'œil (le premier des width meilleurs) : ni tri, ni état gardé, fin de tour jouée sur place.
  local function humanBest(s, v0, d, H, real, memo)
    if d <= 0 or s.result then return v0 end
    local rec = memo[s]
    if d == 1 then
      if H.width < 1 then return v0 end
      if not rec then
        rec = humanPlays(s, H, real, false)
        memo[s] = rec
      end
      local best, vs = v0, rec.v
      for k = 1, #vs do if vs[k] > best then best = vs[k] end end
      return best
    end
    if not rec then
      rec = humanPlays(s, H, real, true)
      memo[s] = rec
    end
    local best = v0
    local moves = sortedPlays(rec)
    for i = 1, math.min(H.width, #moves) do
      local m = moves[i]
      local w = humanBest(humanState(s, rec, m.k), m.v, d - 1, H, real, memo)
      if w > best then best = w end
    end
    return best
  end

  -- Prochain coup du joueur humain : { "play", … } | { "potion", … } | { "end" }, puis l'état prévu après
  -- ce coup (nil pour « end ») et son score au coup d'œil. memo (facultatif) : celui du coup précédent du
  -- même tour ; root : le rec déjà calculé d'une position identique à c, endV : son score au coup d'œil, qui
  -- est celui de finir le tour tout de suite (BotMT:act).
  function Bots.humanAct(c, H, rng, real, memo, root, endV)
    memo = memo or {}
    local cands = { { act = { "end" }, v = endV or humanLeaf(c, H, real) } }
    local rec = root or humanPlays(c, H, real, true)
    -- coups joués puis potions, dans l'ordre d'avant (tri identique, égalités comprises)
    local moves = {}
    for k = 1, #rec.acts do
      local a = rec.acts[k]
      moves[k] = { act = { "play", a[1], a[2], a[3] and "nospend" or nil }, k = k, v = rec.v[k] }
    end
    local pots = Combat.legalPotions(c)
    for i = 1, #pots do
      local t = Combat.clone(c)
      Combat.usePotion(t, pots[i][1], pots[i][2])
      moves[#moves + 1] = { act = { "potion", pots[i][1], pots[i][2] }, s = t, v = humanLeaf(t, H, real) }
    end
    table.sort(moves, byValue)
    -- les width meilleurs coups au coup d'œil, plus les potions qui n'y sont pas (il les a sous les yeux)
    for i = 1, #moves do
      local m = moves[i]
      if i <= H.width or m.act[1] == "potion" then
        local st = m.s or humanState(c, rec, m.k)
        cands[#cands + 1] = { act = m.act, s = st, glance = m.v,
          v = humanBest(st, m.v, H.depth - 1, H, real, memo) }
      end
    end
    table.sort(cands, byValue)
    local pick = cands[1]
    if #cands > 1 and H.slip > 0 and Rng.float(rng) < H.slip then
      local near = {}
      for i = 2, #cands do
        if cands[i].act[1] ~= "end" and cands[i].v >= cands[1].v - H.tol then near[#near + 1] = cands[i] end
      end
      if #near > 0 then pick = near[Rng.int(rng, 1, #near)] end
    end
    return pick.act, pick.s, pick.glance
  end

  -- Deux états de combat identiques (hors journal, quiet et statistiques, que les copies de recherche n'ont
  -- pas) : mêmes valeurs partout, tables comparées en profondeur (au-delà de 24 niveaux : réputées
  -- différentes, la recherche est alors refaite).
  local SKIP_TOP = { events = true, quiet = true, stats = true }
  local function sameValue(x, y, depth)
    if x == y then return true end
    if type(x) ~= "table" or type(y) ~= "table" or depth > 24 then return false end
    for k, v in pairs(x) do
      if not sameValue(v, y[k], depth + 1) then return false end
    end
    for k in pairs(y) do
      if x[k] == nil then return false end
    end
    return true
  end
  local function sameState(a, b)
    for k, v in pairs(a) do
      if not SKIP_TOP[k] and not sameValue(v, b[k], 1) then return false end
    end
    for k in pairs(b) do
      if not SKIP_TOP[k] and a[k] == nil then return false end
    end
    return true
  end
  Bots.sameState = sameState

  local BotMT = {}
  BotMT.__index = BotMT

  function Bots.new(kind, rng, opts)
    local b = setmetatable({ kind = kind, rng = rng, opts = opts or {}, plan = nil, planRound = -1 }, BotMT)
    if kind == "human" then b.H = b.opts.human or Bots.humanParams() end
    return b
  end

  function BotMT:act(c)
    Bots.potionKeep = self.opts.potionKeep or 1
    if self.kind == "human" then
      local H = self.H
      Bots.potionKeep = Bots.potionKeep * H.hoard
      -- réflexion à fond (tour ennemi joué) : tirée une fois par tour
      if self.thinkRound ~= c.round then
        self.thinkRound = c.round
        self.real = H.foresight > 0 and Rng.float(self.rng) < H.foresight
      end
      -- recherche du coup précédent reprise si le coup joué a mené là où elle l'avait prévu (même tour, même
      -- combat, même état) : ses positions déjà explorées ne sont pas recalculées
      local memo, root, endV
      local prev = self.prevState
      if prev and self.prevCombat == c and self.prevRound == c.round and self.prevReal == self.real
          and self.prevKeep == Bots.potionKeep and sameState(c, prev) then
        memo = self.memo
        root, endV = memo[prev], self.prevGlance
      else
        memo = {}
      end
      local a, st, glance = Bots.humanAct(c, H, self.rng, self.real, memo, root, endV)
      self.memo, self.prevState, self.prevCombat, self.prevRound, self.prevReal = memo, st, c, c.round, self.real
      self.prevKeep, self.prevGlance = Bots.potionKeep, glance
      if not st then self.memo = nil end
      Bots.potionKeep = 1
      return a
    elseif self.kind == "random" then
      local pots = Combat.legalPotions(c)
      if #pots > 0 and Rng.float(self.rng) < 0.1 then
        local a = Rng.pick(self.rng, pots)
        return { "potion", a[1], a[2] }
      end
      local acts = Combat.legalPlays(c)
      if #acts == 0 then return { "end" } end
      local a = Rng.pick(self.rng, acts)
      return { "play", a[1], a[2], a[3] and "nospend" or nil }
    elseif self.kind == "greedy" then
      local acts = Combat.legalPlays(c)
      local best, bestA = leafScore(c), nil
      for i = 1, #acts do
        local t = Combat.clone(c)
        Combat.play(t, acts[i][1], acts[i][2], acts[i][3] and { spend = false } or nil)
        local sc = leafScore(t, true)
        if sc > best then best, bestA = sc, { "play", acts[i][1], acts[i][2], acts[i][3] and "nospend" or nil } end
      end
      local pots = Combat.legalPotions(c)
      for i = 1, #pots do
        local t = Combat.clone(c)
        Combat.usePotion(t, pots[i][1], pots[i][2])
        local sc = leafScore(t, true)
        if sc > best then best, bestA = sc, { "potion", pots[i][1], pots[i][2] } end
      end
      if not bestA then return { "end" } end
      return bestA
    else
      for _ = 1, 2 do
        if self.planRound ~= c.round or not self.plan then
          self.plan = Bots.planWithPotions(c, self.opts.cap)
          self.planRound = c.round
          self.planPos = 1
        end
        local ref = self.plan[self.planPos]
        if not ref then return { "end" } end
        local a = resolveRef(c, ref)
        if a then
          self.planPos = self.planPos + 1
          return a
        end
        self.plan = nil -- le plan ne colle plus (pioche imprévue...) : on replanifie
      end
      return { "end" }
    end
  end

  return Bots
end
