-- Règles propres du Voleur (fiche : docs/classes/rogue.md ; contrat : docs/classes.md).
--   Parry : état à charges (plafond 3, gardé d'un tour à l'autre) ; chaque charge annule un coup ennemi
--     jusqu'à 8 dégâts, coup par coup, AVANT l'Absorb (crochet beforeHit) ; un coup de 0 ne consomme
--     rien ; jamais contre le DoT (ce n'est pas un coup).
--   Stealth : état à drapeau, posé au début de chaque combat ; la première carte Attack jouée le
--     consomme (crochet onCardCommitted, au jeu) et toute sa résolution se fait « cachée » (condition
--     stealth) ; une carte Skill ou Power lit l'état sans le consommer.
--   Effets propres : dotPer (« Surge: apply DoT K per Combo. »), tickDotPer (Exsanguinate),
--     randomHits (Killing Spree, flux c.rng.cards).
-- État de classe c.cls : hidden (miroir de Stealth, pour savoir si un gain est réel), stealthGained
-- (le dernier état Stealth posé l'a fait apparaître : Flash Powder), openers (uid des cartes Attack qui
-- ont consommé Stealth, clés en chaîne, jusqu'à la fin de leur résolution).
local _, ns = ...

local Combat, Rng = ns.Combat, ns.Rng
local L = ns.Language

local PARRY_MAX, PARRY_STOP = 3, 8

ns.Statuses.parry = { name = "Parry", max = PARRY_MAX,
  text = "Each charge stops one hit, up to 8 damage. Max 3." }
ns.Statuses.stealth = { name = "Stealth", flag = true,
  text = "The next Attack played consumes it for its Stealth: bonus." }

-- « Each Attack hit: apply DoT 1. » (Deadly Poison)
L.trigger("Each Attack hit")

-- Condition « Stealth: » : pour une carte Attack, elle a consommé Stealth en étant jouée ; pour une
-- autre carte, Stealth est posé (lu sans être consommé).
Combat.CONDITIONS.stealth = function(c, ctx)
  local d = ctx.def
  if d and d.type == "attack" then
    local o = c.cls.openers
    return ctx.card ~= nil and o ~= nil and o[tostring(ctx.card.uid)] == true
  end
  return (c.player.st.stealth or 0) > 0
end

-- { "dotPer", k, icon = clé } : DoT k par point dépensé par le Surge de la carte (ctx.surge) sur la cible.
ns.Effects.dotPer = function(c, ctx, e)
  local t = ctx.target
  local n = e[2] * (ctx.surge or 0)
  if not t or t.dead or n <= 0 then return end
  n = Combat.modify(c, "apply", n, "pain", t, ctx.def)
  if n > 0 then Combat.applyStatus(c, t, "pain", n, e.icon) end
end

-- { "tickDotPer" } : le DoT de la cible se déclenche une fois par point dépensé ; s'arrête si la cible
-- meurt ou si son DoT tombe à 0 (les points restent dépensés).
ns.Effects.tickDotPer = function(c, ctx)
  local t = ctx.target
  for _ = 1, (ctx.surge or 0) do
    if not t or t.dead or c.result or (t.st.pain or 0) <= 0 then return end
    Combat.tickDot(c, t)
  end
end

-- { "randomHits", n, times = k } : k coups de n, chacun sur un ennemi vivant tiré au hasard (flux des
-- cartes) ; ce sont des coups d'une carte Attack (onAttackHit : Deadly Poison).
ns.Effects.randomHits = function(c, ctx, e)
  for _ = 1, (e.times or 1) do
    local list = Combat.aliveEnemies(c)
    if #list == 0 or c.result then return end
    local t = list[Rng.int(c.rng.cards, 1, #list)]
    Combat.dealDamage(c, c.player, t, Combat.calcDamage(c, c.player, t, e[2], ctx.def), false, ctx)
    ctx.dealt = true
    ctx.hits = ctx.hits + 1
    if ctx.def and ctx.def.type == "attack" and not c.result then Combat.fire(c, "onAttackHit", t, ctx) end
  end
end

local function stat(c, key, n)
  local s = c.stats
  if s then s[key] = (s[key] or 0) + (n or 1) end
end

ns.ClassRules.rogue = {
  init = function(c, cls)
    cls.openers = {}
    cls.stealthGained = false
    -- Stealth du début de combat : visible dès la première main, ne compte pas comme un gain (Flash Powder)
    c.player.st.stealth = 1
    cls.hidden = true
  end,
  hooks = {
    -- Parry : une charge par coup ennemi de 1 ou plus, jusqu'à 8 dégâts annulés, avant l'Absorb.
    beforeHit = function(c, cls, dmg, enemy)
      local p = c.player
      local n = p.st.parry or 0
      if n <= 0 or dmg <= 0 then return dmg end
      local stop = dmg < PARRY_STOP and dmg or PARRY_STOP
      n = n - 1
      p.st.parry = n > 0 and n or nil
      Combat.log(c, { t = "parry", src = Combat.uref(enemy), prevented = stop, left = n })
      stat(c, "parried")
      stat(c, "parryPrevented", stop)
      -- une charge consommée (ripostes des épiques) : attaquant, dégâts annulés, charges restantes
      Combat.fire(c, "onParry", enemy, stop, n)
      return dmg - stop
    end,
    -- Stealth consommé au jeu par la première carte Attack (même à 0 mana, même sans ligne Stealth:).
    -- Crochet « stealthBreak » (v = vrai, inst, d) : faux = l'Attack profite de Stealth (lignes « Stealth: »)
    -- sans le retirer (Subterfuge ; la carte qui le pose dit quand il tombe).
    onCardCommitted = function(c, cls, inst, d)
      if d.type ~= "attack" or (c.player.st.stealth or 0) <= 0 then return end
      if not Combat.modify(c, "stealthBreak", true, inst, d) then
        cls.openers[tostring(inst.uid)] = true
        return
      end
      c.player.st.stealth = nil
      cls.hidden = false
      cls.openers[tostring(inst.uid)] = true
      Combat.log(c, { t = "stealth_used", card = inst.uid })
      stat(c, "stealthUsed")
    end,
    onCardPlayed = function(c, cls, inst)
      cls.openers[tostring(inst.uid)] = nil
    end,
    -- miroir de Stealth : un gain n'est réel que si l'état était absent (pas d'empilement)
    onStatusApplied = function(c, cls, unit, id)
      if id ~= "stealth" or unit ~= c.player then return end
      cls.stealthGained = not cls.hidden
      cls.hidden = true
    end,
  },
  -- Bots : charges de Parry et Stealth distinguent deux positions (absents de la clé commune).
  botKey = function(c)
    return (c.player.st.parry or 0) .. ":" .. (c.player.st.stealth or 0)
  end,
  -- Valeur des charges de Parry restantes après le tour ennemi (un coup paré plus tard, environ 5 PV)
  -- et de Stealth (bonus de la prochaine Attack, environ 8 dégâts) ; correction propre à l'épique du deck
  -- (Rogue.epicBotValue, plus bas).
  botValue = function(c, W)
    local p = c.player
    return (p.st.parry or 0) * 5 * W.hp * 0.8 + (p.st.stealth or 0) * 8 * W.enemyHp
      + ns.Rogue.epicBotValue(c, W)
  end,
}

---------------------------------------------------------------------------
-- Cartes épiques (fiche : docs/zones/cartes-de-zone.md, « Rogue » ; données : Data/Rogue.lua)
---------------------------------------------------------------------------
-- Chaque épique est une règle active tout le combat, posée par Combat.new dans c.epic = { id, up, uid }
-- (hors de toute pile) : crochets « deckHooks », src = c.epic, passés après classe, zones, Powers, bibelots
-- et affixes (docs/classes.md, « Cartes épiques »). Leur état vit dans c.cls (copié par Combat.clone, sauvegardé), jamais
-- dans src (partagé entre les copies des bots). Nombres : Rogue.EPIC (base, +1, +2, +3), à garder
-- d'accord avec les textes de Data/Rogue.lua (vérifié par Sim/tests_epic_rogue.lua).
local Rogue = {}
ns.Rogue = Rogue
local C = ns.Cards

Rogue.EPIC = ns.RogueEpicNumbers -- nombres des épiques (Data/Rogue.lua)
-- Index des nombres d'une épique : Card.level + 1 (1 = base … 4 = +3) ; x = instance (src) ou valeur up.
function Rogue.tier(x) return ns.Card.level(x) + 1 end
local tier = Rogue.tier
local function num(id, src) return Rogue.EPIC[id][tier(src)] end

-- id (et amélioration) de l'épique du Voleur en jeu (c.epic), ou nil.
function Rogue.epicOf(c)
  local e = c.epic
  local d = e and C[e.id]
  if d and d.class == "rogue" and d.rarity == "epic" then return e.id, e.up end
  return nil
end

local function hasSurge(d)
  local es = d.effects
  for i = 1, #es do if es[i][1] == "surge" then return true end end
  return false
end

-- Cible des ripostes : la dernière cible du Voleur, sinon l'ennemi vivant le plus à gauche.
function Rogue.riposteTarget(c)
  local t = c.player.lastTarget and Combat.enemyByUid(c, c.player.lastTarget)
  if t and not t.dead then return t end
  return Combat.aliveEnemies(c)[1]
end

-- Ripostes du tour : remises à 0 au début de chaque tour du Voleur (le début du combat compte pour le
-- premier tour : Blinding Powder) ; le tour ennemi qui suit continue le compte.
local function turnKey(c) return c.round > 0 and c.round or 1 end
function Rogue.ripostes(c)
  local cls = c.cls
  if cls.riposteRound ~= turnKey(c) then return 0 end
  return cls.ripostes or 0
end
-- Dégâts de base de la k-ième riposte du tour : N + S × (k − 1) (Deflection ; up = palier, true = 1).
function Rogue.riposteDamage(k, up)
  local i = tier(up)
  return Rogue.EPIC.deflection[i] + Rogue.EPIC.deflectionStep[i] * (k - 1)
end
-- Dégâts de base de la prochaine riposte (nil sans Deflection).
function Rogue.nextRiposte(c)
  local id, up = Rogue.epicOf(c)
  if id ~= "deflection" then return nil end
  return Rogue.riposteDamage(Rogue.ripostes(c) + 1, up)
end

-- Noms de cartes joués ce tour (Danse Macabre) : c.cls.dmNames, compte c.cls.dmCount, tour c.cls.dmRound.
function Rogue.namesPlayed(c)
  local cls = c.cls
  if cls.dmRound ~= c.round then return 0 end
  return cls.dmCount or 0
end

local function bossOrStun(c, t, d)
  if Combat.stunImmune(t) then
    local n = Combat.modify(c, "apply", 2, "demoralized", t, d)
    if n > 0 then Combat.applyStatus(c, t, "demoralized", n) end
  else
    local n = Combat.modify(c, "apply", 1, "stunned", t, d)
    if n > 0 then Combat.applyStatus(c, t, "stunned", n) end
  end
end

local EH = {}

-- Deflection : chaque charge de Parry gagnée (n demandé, avant le plafond de 3) riposte : la k-ième du
-- tour inflige k × N (coup sans carte : Strength, Sundered comptent) à la dernière cible.
EH.deflection = {
  onStatusApplied = function(c, src, unit, id, n)
    if id ~= "parry" or unit ~= c.player or (n or 0) <= 0 or c.result then return end
    local cls = c.cls
    local key = turnKey(c)
    if cls.riposteRound ~= key then cls.riposteRound, cls.ripostes = key, 0 end
    for _ = 1, n do
      local t = Rogue.riposteTarget(c)
      if not t then return end
      cls.ripostes = cls.ripostes + 1
      local base = Rogue.riposteDamage(cls.ripostes, src.up)
      Combat.log(c, { t = "riposte", dst = t.uid, n = cls.ripostes, base = base })
      stat(c, "ripostes")
      Combat.dealDamage(c, c.player, t, Combat.calcDamage(c, c.player, t, base, nil))
      if c.result then return end
    end
  end,
}

-- Doomblade : un coup d'une carte Attack à clause Surge n'est pas porté ; sa cible reçoit un DoT égal aux
-- dégâts calculés (amélioré : +50 %, arrondi au-dessus) (Combo, Stealth, Sundered),
-- sans l'Absorb, par le crochet « apply ». Crochet moteur « convertHit » (Core/Effects.lua).
EH.doomblade = {
  convertHit = function(c, src, v, t, ctx)
    local d = ctx and ctx.def
    if not v or v <= 0 or not d or d.type ~= "attack" or not hasSurge(d) then return v end
    local n = math.ceil(v * num("doomblade", src) - 1e-9)
    n = Combat.modify(c, "apply", n, "pain", t, d)
    if n > 0 then Combat.applyStatus(c, t, "pain", n, "poison") end
    stat(c, "doombladeDot", n)
    return false
  end,
}

-- Atrophic Poison : un ennemi qui porte au moins T de DoT (le DoT montré pendant le tour du Voleur, avant
-- son tic) frappe comme sous Demoralized (sans se cumuler avec lui) ; amélioré, il subit les coups du Voleur
-- comme sous Sundered (même seuil). Pendant le tour ennemi, le DoT a déjà tiqué : on lui rend la baisse du
-- tic. Il faut aussi qu'il en reste après le tic (un DoT 1 tombe à 0 avant le coup).
local function dotAtHit(c, e, up)
  local pain = e.st.pain or 0
  if pain <= 0 then return false end
  local need = Rogue.EPIC.atrophic_poison[tier(up)]
  if c.phase == "enemy" then return pain + Combat.modify(c, "dotDecay", 1, e) >= need end
  return pain >= need and pain - Combat.modify(c, "dotDecay", 1, e) > 0
end
-- L'ennemi e compte-t-il comme Demoralized (porte assez de DoT, pas de vrai Demoralized) ? Lu aussi par
-- l'interface.
function Rogue.countsDemoralized(c, e)
  local _, up = Rogue.epicOf(c)
  return e ~= nil and e.side == "enemy" and not e.dead and (e.st.demoralized or 0) <= 0 and dotAtHit(c, e, up)
end
EH.atrophic_poison = {
  enemyDamage = function(c, src, v, e)
    if Rogue.countsDemoralized(c, e) then
      return math.floor(v * 0.75)
    end
    return v
  end,
  damage = function(c, src, v, t)
    if src.up and t and t.side == "enemy" and (t.st.armor_broken or 0) <= 0
      and (t.st.pain or 0) >= num("atrophic_poison", src) then
      return math.floor(v * 1.25)
    end
    return v
  end,
}

-- Echoing Reprimand : un Surge qui dépense 2 ou 3 Combo compte N pour ses effets (la dépense ne change pas).
-- Le crochet « surge » reçoit la dépense réelle : aucune autre source du Voleur ne le modifie avant.
EH.echoing_reprimand = {
  surge = function(c, src, v)
    if v >= 2 and v <= num("echoingMax", src) then return num("echoing_reprimand", src) end
    return v
  end,
}

-- Subterfuge : les Attacks profitent de Stealth sans le retirer ; il dure T tours (le tour où il est posé
-- compris : T = 1, il tombe à la fin de ce tour du Voleur ; réglage : T = 2), c.cls.stealthUntil = tour à la
-- fin duquel il tombe ; un Stealth posé de nouveau repart pour T tours. Chaque Stealth gagné (absent ->
-- présent, c.cls.stealthGained) donne N Combo (réglage : la fiche le réservait à l'amélioration, +1).
local function stealthTurns(src) return Rogue.EPIC.subterfugeTurns[tier(src)] end
EH.subterfuge = {
  stealthBreak = function() return false end,
  onTurnEnd = function(c)
    if (c.player.st.stealth or 0) > 0 and c.round >= (c.cls.stealthUntil or 0) then
      c.player.st.stealth = nil
      c.cls.hidden = false
      Combat.log(c, { t = "stealth_end" })
    end
  end,
  onStatusApplied = function(c, src, unit, id)
    if id ~= "stealth" or unit ~= c.player then return end
    c.cls.stealthUntil = turnKey(c) + stealthTurns(src) - 1
    local n = num("subterfuge", src)
    if c.cls.stealthGained and n > 0 then Combat.gainRes(c, n, "epic") end
  end,
  -- source de Stealth incluse : chaque Surge (dépense de 1 ou plus) rend Stealth, pour les cartes jouées après ;
  -- paliers 2 et 3 : et Parry (« Shroud 3, gain Parry 1. »)
  onSurge = function(c, src)
    if c.result then return end
    if Rogue.EPIC.subterfugeSurge[tier(src)] then Combat.applyStatus(c, c.player, "stealth", 1) end
    local p = num("subterfugeParry", src)
    if p > 0 then Combat.applyStatus(c, c.player, "parry", p) end
  end,
}
-- Stealth du début de combat (posé par la règle de classe, sans événement) : T tours dès le premier.
local function subterfugeStart(c, src)
  if (c.player.st.stealth or 0) > 0 then c.cls.stealthUntil = stealthTurns(src) end
end
-- Tours de Stealth restants, ce tour compris (0 sans Stealth ; nil sans Subterfuge). Lu par l'interface.
function Rogue.stealthLeft(c)
  if Rogue.epicOf(c) ~= "subterfuge" then return nil end
  if (c.player.st.stealth or 0) <= 0 then return 0 end
  return math.max(1, (c.cls.stealthUntil or 0) - turnKey(c) + 1)
end

-- Kidney Shot : une carte à cible dont le Surge dépense N Combo ou plus pose ensuite Stunned 1 ⌛ sur sa
-- cible si elle vit ; un ennemi qu'on ne peut pas étourdir (boss, Indomitable) reçoit Demoralized 2 ⌛.
-- Paliers 2 et 3 : ce Surge rend ensuite R Combo (« Gouge, +1 Combo. »), cible morte comprise.
EH.kidney_shot = {
  onSurge = function(c, src, n, ctx)
    if n >= num("kidney_shot", src) and ctx and ctx.target and ctx.def and ctx.def.target == "enemy" then
      ctx.kidney = true
    end
  end,
  onCardPlayed = function(c, src, inst, ctx)
    if not (ctx and ctx.kidney) or c.result then return end
    ctx.kidney = nil
    local t = ctx.target
    if t and not t.dead then
      bossOrStun(c, t, ctx.def)
      stat(c, "kidneyShots")
    end
    local r = num("kidneyCombo", src)
    if r > 0 then Combat.gainRes(c, r, "epic") end
  end,
}

-- Danse Macabre : chaque coup d'une carte Attack inflige N de plus par nom de carte différent joué dans
-- ce tour, le sien exclu, au-delà des F premiers (réglage : F = 2), au plus C si C > 0 (réglage : sans
-- plafond) ; compté à la résolution, comme Strength, avant Sundered.
-- Bonus d'un coup de la carte id (nil : un nom pas encore joué) ce tour-ci. Lu aussi par l'interface.
function Rogue.danseBonus(c, up, id)
  local cls, k = c.cls, tier(up)
  if cls.dmRound ~= c.round then return 0 end
  local n = (cls.dmCount or 0) - ((id and cls.dmNames[id]) and 1 or 0) - Rogue.EPIC.danseFree[k]
  if n <= 0 then return 0 end
  local cap, bonus = Rogue.EPIC.danseCap[k], Rogue.EPIC.danse_macabre[k] * n
  return (cap > 0 and bonus > cap) and cap or bonus
end
EH.danse_macabre = {
  onCardCommitted = function(c, src, inst)
    local cls = c.cls
    if cls.dmRound ~= c.round then cls.dmRound, cls.dmNames, cls.dmCount = c.round, {}, 0 end
    if not cls.dmNames[inst.id] then
      cls.dmNames[inst.id] = true
      cls.dmCount = cls.dmCount + 1
    end
  end,
  damage = function(c, src, v, t, d)
    if not d or d.type ~= "attack" then return v end
    return v + Rogue.danseBonus(c, src.up, d.id)
  end,
}

for id, hooks in pairs(EH) do C[id].deckHooks = hooks end
C.subterfuge.whileInDeck = subterfugeStart

-- Mots du langage des épiques (déclencheurs « Name: », plaque « Epic » : Core/Language.lua). Chaque épique dit
-- « Déclencheur: Mot N. » ; le mot de règle (L.rule) donne la règle complète dans l'à-côté, avec les nombres de
-- Rogue.EPIC (base, améliorée) : upText vaut pour les paliers 1 à 3 (seul N, lu sur la carte, change).
L.trigger("Each Parry gained")
L.trigger("Surge Attacks")
for _, t in ipairs(Rogue.EPIC.atrophic_poison) do L.trigger("DoT " .. t .. "+") end
L.trigger("Surge cards")
for _, k in ipairs(Rogue.EPIC.kidney_shot) do L.trigger(ns.RogueKidneyLabel(k)) end
L.trigger("Attack hits")
do
  local E = Rogue.EPIC
  local function both(f) return f(1), f(2) end
  -- Deflection : la k-ième riposte du tour inflige N + S × (k − 1)
  local t1, t2 = both(function(i)
    return "Deal N damage to the last target, +" .. E.deflectionStep[i] .. " per earlier Riposte this turn."
  end)
  L.rule("riposte", { name = "Riposte", text = t1, upText = t2 })
  L.rule("bleed", { name = "Bleed", text = "The hit deals no damage and applies N% of it as DoT, rounded up." })
  -- seuil écrit sur la carte (« DoT 5+: », 4 et 3 aux paliers 2 et 3), pas dans l'à-côté
  t1, t2 = both(function(i)
    return "Enemies with at least that much DoT count as Demoralized" .. (i == 2 and " and Sundered." or ".")
  end)
  L.rule("atrophy", { name = "Atrophy", text = t1, upText = t2 })
  t1, t2 = both(function(i)
    local m = E.echoingMax[i]
    return "A Surge of " .. (m == 2 and "2" or m == 3 and "2 or 3" or ("2 to " .. m)) .. " Combo counts as a Surge of N."
  end)
  L.rule("animacharge", { name = "Animacharge", text = t1, upText = t2 })
  t1, t2 = both(function(i)
    local s = E.subterfugeSurge[i] and "A Surge of 1+ Combo grants Stealth. " or ""
    s = s .. "Stealth lasts N turns, Attacks don't remove it"
    if E.subterfuge[i] > 0 then s = s .. ", each new one gives +" .. E.subterfuge[i] .. " Combo" end
    return s .. "."
  end)
  L.rule("shroud", { name = "Shroud", text = t1, upText = t2 })
  L.rule("gouge", { name = "Gouge",
    text = "Apply Stunned 1 ⌛ to the target if it lives. Can't be Stunned: Demoralized 2 ⌛ instead." })
  t1, t2 = both(function(i)
    local free = E.danseFree[i]
    return "+N damage per other card name played this turn"
      .. (free == 1 and ", after the first" or free > 1 and (", after the first " .. free) or "")
      .. (E.danseCap[i] > 0 and (", up to +" .. E.danseCap[i] .. ".") or ".")
  end)
  L.rule("flourish", { name = "Flourish", text = t1, upText = t2 })
end

-- Bots : correction de la valeur d'une position selon l'épique du combat (ajoutée à botValue).
--   Echoing Reprimand : 2 ou 3 Combo valent un Surge de 5 (monter à 4 est une perte).
function Rogue.epicBotValue(c, W)
  local id, up = Rogue.epicOf(c)
  if not id then return 0 end
  if id == "echoing_reprimand" then
    local r = c.player.res or 0
    if r >= 2 and r <= Rogue.EPIC.echoingMax[tier(up)] then
      local cd = ns.Classes.rogue
      return (Rogue.EPIC.echoing_reprimand[tier(up)] - r) * cd.bot.resValue * 0.8
    end
  end
  return 0
end
