-- Règles propres du Guerrier : la Rage (docs/gdd-classes.md, « Warrior » ; contrat : docs/classes.md).
--   +1 Rage à chaque perte de PV (coup ennemi, DoT, « Pay N HP » : un paiement compte comme une perte),
--   +1 Rage par carte Attack jouée (à sa résolution), plafond 5 (classDef.resource.cap), gardée d'un
--   tour à l'autre. Revenge (champ hurtCost) coûte moins si des PV ont été perdus au tour précédent.
-- État de classe c.cls : hurt (PV perdus depuis le début de ce tour), hurtLast (au tour précédent) ; états
-- des cartes épiques (plus bas) : titan, tgAttacks, tgSurge, tgHeld, amSpent.
local _, ns = ...

local Combat, Card, Rng = ns.Combat, ns.Card, ns.Rng
local L = ns.Language
local floor = math.floor

ns.Warrior = ns.Warrior or {}
local Warrior = ns.Warrior

ns.ClassRules.warrior = {
  init = function(c, cls)
    cls.hurt = false
    cls.hurtLast = false
  end,
  hooks = {
    onHpLost = function(c, cls, n)
      cls.hurt = true
      if not c.result then Combat.gainRes(c, 1, "hit") end
    end,
    onCardPlayed = function(c, cls, inst, ctx)
      -- Titan's Grip : la copie d'une Attack ne donne pas sa Rage (une fois par carte)
      if ctx.def.type == "attack" and not (ctx.copy and cls.titan) then Combat.gainRes(c, 1, "attack") end
    end,
    onTurnStart = function(c, cls)
      cls.hurtLast = cls.hurt
      cls.hurt = false
    end,
    cost = function(c, cls, v, d)
      if d.hurtCost and cls.hurtLast then return d.hurtCost end
      return v
    end,
  },
  -- Bots : état qui distingue deux positions (Strength du joueur, PV perdus ce tour ; Attacks du tour sous
  -- Titan's Grip, reste de Rage dépensée sous Anger Management).
  botKey = function(c)
    local cls = c.cls
    return (c.player.st.force or 0) .. ":" .. (cls.hurt and 1 or 0) .. ":" .. (cls.hurtLast and 1 or 0)
      .. ":" .. (cls.tgAttacks or 0) .. ":" .. (cls.amSpent or 0)
  end,
  -- Bots : valeur propre (unités de Bots.W, 10 = 1 PV). Anger Management : la Rage déjà dépensée vers le
  -- prochain cran de recharge vaut une part d'un cran.
  botValue = function(c, W)
    if Warrior.epicOf(c, "anger_management") then
      return (c.cls.amSpent or 0) / Warrior.EPIC.anger_management.per * 12
    end
    return 0
  end,
}

---------------------------------------------------------------------------
-- Cartes épiques du Guerrier (docs/zones/cartes-de-zone.md, « Warrior »)
---------------------------------------------------------------------------
-- Règle en jeu pendant tout le combat, dès son début (c.epic, hors de toute pile) : deckHooks (src = c.epic,
-- après classe, zones, Powers, bibelots et affixes) et whileInDeck (au début du combat). Nombres réglés par
-- la simulation dans les zones dures (14/11/2026 : Duskwood, Stranglethorn Vale, Burning Steppes ; docs/classes.md,
-- « Épiques du Guerrier ») : ce tableau seul ; les textes de Data/Warrior.lua les disent (vérifié par
-- Sim/tests_epic_warrior.lua). Écarts à la fiche : Thunderous Roar 3 sans Demoralized, amélioré 4 + Demoralized 1
-- (Demoralized de base : +15 à +22 points quel que soit le nombre) ; Titan's Grip deux Attacks par tour comme la
-- fiche, mais chacune coûte 1 de plus (extraCost ; sans ce coût, 100 % de victoires) ; Sweeping Strikes au tiers
-- (moitié : Duskwood +22) ; Shield Charge au quart ;
-- Anger Management chaque Rage, et les cartes qui dépensent partent en recharge 1 (give : débouché du deck de
-- départ) ; Avatar +2 / +3 et, à 10 Rage, Attacks +1 (over, bonus : débouché de la Rage gardée).
-- demoralized = 0 : pas d'état posé ; selfStates = faux (repli de la fiche, non retenu) : la copie de Titan's Grip
-- ne poserait rien sur le héros ; copies = copies de chaque Attack (0 : contrôle « à blanc »).
-- Paliers d'amélioration (15/11/2026, docs/ameliorations.md) : un nombre qui change avec le palier est une table
-- { base, +1, +2, +3 } lue par Warrior.tier (palier de l'épique : Card.level(src)) ; killRage / killHeal : « Kills: »
-- des paliers 2 et 3 (+N Rage, soin de N à chaque ennemi tué) ; anyAttack : « Attacks: » (Attacks à tous comprises).
Warrior.EPIC = {
  death_wish = { mult = { 1.5, 1.5, 1.5, 1.6 }, heal = { 0, 3, 5, 5 } },
  thunderous_roar = { at = 5, damage = { 3, 4, 5, 6 }, demoralized = { 0, 1, 1, 1 } },
  sweeping_strikes = { targets = { 1, 2, 2, 2 }, div = 3, anyAttack = { false, false, true, true }, killRage = { 0, 0, 0, 1 } },
  titans_grip = { limit = 2, extraCost = 1, copies = 1, selfStates = true, killHeal = { 0, 0, 4, 6 } },
  shield_charge = { div = 4, bonus = { 0, 4, 6, 8 } },
  anger_management = { per = 1, steps = { 1, 2, 3, 4 }, give = 1 },
  avatar = { cap = 10, gain = { 2, 3, 4, 5 }, over = 9, bonus = 1 },
}
local E = Warrior.EPIC

-- Nombre d'une épique à un palier : v (nombre, ou table { base, +1, +2, +3 }), up = instance (c.epic) ou valeur up.
function Warrior.tier(v, up)
  if type(v) ~= "table" then return v end
  local x = v[Card.level(up) + 1]
  if x == nil then return v[#v] end
  return x
end
-- Warrior.num("avatar", "gain", src) : nombre de Warrior.EPIC au palier de src.
function Warrior.num(id, key, up)
  return Warrior.tier(E[id][key], up)
end
local num = Warrior.num
Warrior.EPICS = { "death_wish", "thunderous_roar", "sweeping_strikes", "titans_grip", "shield_charge",
  "anger_management", "avatar" }
local IS_EPIC = {}
for _, id in ipairs(Warrior.EPICS) do IS_EPIC[id] = true end

-- Épique du Guerrier en jeu dans ce combat (c.epic, puis c.moreEpics : Combat.new) : id, amélioré ; nil sans
-- épique. want = id cherché (cette épique si elle est en jeu), sinon la première du Guerrier.
function Warrior.epicOf(c, want)
  local e, more, k = c.epic, c.moreEpics, 0
  while e do
    if IS_EPIC[e.id] and (not want or e.id == want) then return e.id, e.up end
    k = k + 1
    e = more and more[k]
  end
  return nil
end

-- Mots du langage (déclencheurs « Name: » des textes) et plaque « Epic » (si le socle ne l'a pas posée).
L.trigger("Kills")
L.trigger("At 5 Rage")
L.trigger("Targeted Attack hits")
L.trigger("Attacks") -- Sweeping Strikes, paliers 2 et 3 (mot déjà déclaré par le socle)
L.trigger("Each Rage spent")
L.trigger("At 10 Rage")
L.trigger("Spend and Surge cards")
-- Mots de règle des épiques (L.rule) : la carte dit « Déclencheur: Mot N. », l'à-côté la règle complète avec les
-- nombres de Warrior.EPIC (base, puis améliorée).
do
  local FRAC = { [2] = "half", [3] = "a third", [4] = "a quarter" }
  local function turns(n) return n .. " turn" .. (n > 1 and "s" or "") end
  L.rule("carnage", { name = "Carnage", text = "Attacks deal N% more damage. Absorb can't be gained." })
  local T = E.thunderous_roar
  local function roar(demo)
    if (demo or 0) <= 0 then return "Spend all Rage and deal N to all enemies." end
    return "Spend all Rage, deal N to all enemies and apply Demoralized " .. demo .. " ⌛ to all."
  end
  -- (Demoralized : même nombre aux paliers 1 à 3, l'à-côté n'a qu'un texte amélioré)
  L.rule("shockwave", { name = "Shockwave", text = roar(T.demoralized[1]), upText = roar(T.demoralized[2]) })
  local S = E.sweeping_strikes
  local function sweep(n)
    return "Also hit " .. (n == 1 and "another random enemy" or (n .. " other random enemies")) .. " for "
      .. (FRAC[S.div] or ("1/" .. S.div)) .. " of the HP the target lost, rounded down."
  end
  L.rule("sweep", { name = "Sweep", text = sweep(S.targets[1]), upText = sweep(S.targets[2]) })
  local TG = E.titans_grip
  L.rule("dualWield", { name = "Dual Wield",
    text = "Attacks cost " .. TG.extraCost .. " more and resolve twice, at most N per turn.",
    upText = "Attacks cost " .. TG.extraCost .. " more and resolve twice, at most N per turn. "
      .. "0-cost ones skip the cost and limit." })
  local SC = E.shield_charge
  L.rule("punish", { name = "Punish",
    text = "With Absorb, deal " .. FRAC[SC.div] .. " of it to the last target, rounded down. The Absorb stays.",
    upText = "With Absorb, deal " .. FRAC[SC.div] .. " of it +N to the last target, rounded down. The Absorb stays." })
  local A = E.anger_management
  -- amélioré : « N turns » (Haste 2 ou 3 selon le palier, nombre de la carte)
  local function haste(steps)
    return "Cards on Cooldown return " .. (steps and turns(steps) or "N turns") .. " sooner. Spend and Surge cards go on Cooldown "
      .. A.give .. ", not to the discard."
  end
  L.rule("haste", { name = "Haste", text = haste(A.steps[1]), upText = haste(nil) })
  local AV = E.avatar
  L.rule("juggernaut", { name = "Juggernaut", text = "Gain N Rage. Rage goes up to " .. AV.cap .. ", and at "
    .. (AV.over + 1) .. " Rage Attacks deal " .. AV.bonus .. " more." })
end
do
  local has = false
  for _, p in ipairs(L.plates) do if p.word == "Epic" then has = true end end
  if not has then
    L.plate("epic", { word = "Epic", head = true, text = "in play from the start of each combat." })
  end
end

-- Genre du coup sans carte d'une épique (Combat.hitInfo : règles de zone, Rude Awakening du Swamp) : posé le
-- temps du coup puis remis. all = vrai : coup « à tous » (onde, rebond), faux : à une cible (Shield Charge).
-- (sans vararg : coup de Combat.dealDamage, seul usage)
local function hitAs(c, all, src, dst, amount)
  local k0, a0 = c.hitKind, c.hitAll
  c.hitKind, c.hitAll = "other", all
  Combat.dealDamage(c, src, dst, amount)
  c.hitKind, c.hitAll = k0, a0
end

-- Crochets d'une épique (deckHooks, src = c.epic) et mise en place au début du combat (whileInDeck).
local function attach(id, hooks, upHooks, start)
  local d = ns.Cards[id]
  d.deckHooks = hooks
  d.whileInDeck = start
  d.up.deckHooks = upHooks or hooks
  d.up.whileInDeck = start
end

local function hasEffect(d, kind)
  for i = 1, #d.effects do if d.effects[i][1] == kind then return true end end
  return false
end

-- « Kills: » des paliers (Death Wish dès le palier 1, les autres aux paliers 2 et 3) : à chaque ennemi tué, soin
-- de E[id].killHeal (Death Wish : heal), +E[id].killRage Rage (pas après la fin du combat) ; 0 : rien.
local function onKill(id, healKey)
  return function(c, src)
    local h = healKey and num(id, healKey, src) or 0
    if h > 0 then Combat.heal(c, c.player, h) end
    local r = E[id].killRage and num(id, "killRage", src) or 0
    if r > 0 and not c.result then Combat.gainRes(c, r, "kill") end
  end
end

-- Westfall — Death Wish : aucun Absorb gagné ; les coups des cartes Attack +50 % (palier 3 : +60 % ; après
-- Strength, avant Sundered, arrondi à l'inférieur : crochet attackMult) ; amélioré : chaque ennemi tué soigne de 3
-- (palier 2 : 5).
do
  local hooks = {
    canGainBlock = function() return false end,
    attackMult = function(c, src, v) return v * num("death_wish", "mult", src) end,
    onEnemyDeath = onKill("death_wish", "heal"),
  }
  attach("death_wish", hooks)
end

-- Duskwood — Thunderous Roar : dès que la Rage atteint 5 (juste après le gain, quelle qu'en soit la source),
-- elle tombe à 0, le Guerrier inflige 3 (amélioré : 4) à chaque ennemi vivant, sans carte (Strength
-- comprise), coup « à tous ». Demoralized (E.demoralized : 0 ; amélioré 1) : posé ensuite sur chacun ; pendant le
-- tour ennemi, il ne dure que jusqu'à la fin du round (l'état posé n'est pas protégé de la baisse).
function Warrior.roar(c, up)
  local p = c.player
  Combat.gainRes(c, -(p.res or 0), "roar")
  Combat.log(c, { t = "epic_trigger", card = "thunderous_roar" })
  local n = num("thunderous_roar", "damage", up)
  local list = Combat.aliveEnemies(c)
  for i = 1, #list do
    local e = list[i]
    if not e.dead and not c.result then hitAs(c, true, p, e, Combat.calcDamage(c, p, e, n)) end
  end
  if c.result then return end
  local demo = num("thunderous_roar", "demoralized", up)
  if demo <= 0 then return end
  list = Combat.aliveEnemies(c)
  for i = 1, #list do
    local e = list[i]
    local fresh = e.fresh.demoralized
    Combat.applyStatus(c, e, "demoralized", demo)
    if c.phase == "enemy" then e.fresh.demoralized = fresh end
  end
end

do
  local hooks = {
    onResource = function(c, src, delta)
      if delta <= 0 or c.result or (c.player.res or 0) < E.thunderous_roar.at then return end
      Warrior.roar(c, src)
    end,
  }
  attach("thunderous_roar", hooks)
end

-- Wetlands — Sweeping Strikes : chaque coup d'une carte Attack à cible inflige aussi le tiers (E.div) des PV qu'il
-- a fait perdre (arrondi à l'inférieur) à un autre ennemi vivant tiré par c.rng.cards (amélioré : deux,
-- sans remise). Le rebond est un coup sans carte (ctx nil) : ni Rage, ni Deep Wounds, ni nouveau rebond.
-- Paliers 2 et 3 : « Attacks: Sweep 2. », les Attacks à tous rebondissent aussi (depuis chaque ennemi touché) ; palier 3 :
-- chaque ennemi tué donne +1 Rage.
attach("sweeping_strikes", {
  onDamageDealt = function(c, src, t, loss, ctx)
    if not ctx or not ctx.def or ctx.def.type ~= "attack" then return end
    -- paliers 2 et 3 (« Attacks: ») : chaque coup d'une carte Attack, à cible ou à tous ; sinon la cible seule
    if not num("sweeping_strikes", "anyAttack", src) and (ctx.def.target ~= "enemy" or t ~= ctx.target) then return end
    local n = floor(loss / E.sweeping_strikes.div)
    if n <= 0 then return end
    local others = {}
    for i = 1, #c.enemies do
      local e = c.enemies[i]
      if e ~= t and not e.dead then others[#others + 1] = e end
    end
    for _ = 1, num("sweeping_strikes", "targets", src) do
      if #others == 0 or c.result then return end
      local e = table.remove(others, Rng.int(c.rng.cards, 1, #others))
      Combat.log(c, { t = "epic_trigger", card = "sweeping_strikes", unit = e.uid })
      hitAs(c, true, c.player, e, n)
    end
  end,
  onEnemyDeath = onKill("sweeping_strikes"),
})

-- Stranglethorn Vale — Titan's Grip : chaque carte Attack se résout deux fois (crochet replay : la copie
-- suit, même cible ou premier ennemi vivant, sans coût, reprend le Spend payé et le montant du Surge de
-- l'original sans rien dépenser) ; la Rage « +1 par Attack » une fois par carte ; chaque carte Attack coûte
-- 1 de plus (E.extraCost, crochet cost) ; au plus deux cartes Attack par tour (E.limit, crochet canPlay) ;
-- amélioré : celles qui coûtent 0 au moment du jeu n'ont pas le surcoût et ne comptent pas.
Warrior.TITAN_REASON = ("Only %d Attack%s per turn."):format(E.titans_grip.limit, E.titans_grip.limit > 1 and "s" or "")

local function titanCounts(c, src, inst)
  return not (src.up and Combat.cost(c, inst) == 0)
end

local titanHooks = {
  replay = function(c, src, v, inst, ctx)
    if ctx.def.type ~= "attack" then return v end
    c.cls.tgSurge = hasEffect(ctx.def, "surge") and (ctx.surge or 0) or nil
    return v + E.titans_grip.copies
  end,
  canPlay = function(c, src, v, d, inst)
    if v ~= true or d.type ~= "attack" or not titanCounts(c, src, inst) then return v end
    if (c.cls.tgAttacks or 0) >= E.titans_grip.limit then return Warrior.TITAN_REASON end
    return v
  end,
  -- poids de l'arme à deux mains (E.extraCost) : chaque carte Attack coûte plus de mana ; amélioré : pas
  -- celles qui coûtent 0 (après les règles de classe : Revenge touché), qui ne comptent pas non plus
  cost = function(c, src, v, d)
    local x = E.titans_grip.extraCost
    if x > 0 and d.type == "attack" and not (src.up and v == 0) then return v + x end
    return v
  end,
  onCardCommitted = function(c, src, inst, d)
    if d.type == "attack" and titanCounts(c, src, inst) then c.cls.tgAttacks = (c.cls.tgAttacks or 0) + 1 end
  end,
  onTurnStart = function(c) c.cls.tgAttacks = 0 end,
  -- paliers 2 et 3 : chaque ennemi tué soigne de 4 (6)
  onEnemyDeath = onKill("titans_grip", "killHeal"),
  -- copie d'un Surge : la Rage de l'original est prêtée le temps de la copie, puis rendue telle quelle
  beforeCard = function(c, src, inst, ctx)
    local cls = c.cls
    cls.tgCopy = ctx.copy and true or nil
    if ctx.copy and cls.tgSurge then
      cls.tgHeld = c.player.res or 0
      c.player.res = cls.tgSurge
    end
  end,
  -- la copie ne pose pas d'état sur le héros (Strength de Bloodthirst) si selfStates est faux
  applySelf = function(c, src, n)
    if c.cls.tgCopy and not E.titans_grip.selfStates then return 0 end
    return n
  end,
  onCardPlayed = function(c, src, inst, ctx)
    local cls = c.cls
    cls.tgCopy = nil
    if ctx.copy and cls.tgHeld then
      c.player.res = cls.tgHeld
      cls.tgHeld, cls.tgSurge = nil, nil
    end
  end,
}
attach("titans_grip", titanHooks, nil, function(c) c.cls.titan = true c.cls.tgAttacks = 0 end)

-- Swamp of Sorrows — Shield Charge : à la fin du tour du Guerrier (avant la défausse), le quart de son
-- Absorb (arrondi à l'inférieur ; amélioré : 4 + le quart) frappe sa dernière cible, sans carte
-- (Strength comprise) ; dernière cible morte : l'ennemi vivant le plus à gauche ; un dormeur (état asleep,
-- Swamp) n'est visé que s'il ne reste aucun ennemi éveillé. L'Absorb reste entière. Sans Absorb : rien.
local function asleep(e) return (e.st.asleep or 0) > 0 end

function Warrior.chargeTarget(c)
  local last = c.player.lastTarget and Combat.enemyByUid(c, c.player.lastTarget)
  local awake, first
  for i = 1, #c.enemies do
    local e = c.enemies[i]
    if not e.dead then
      first = first or e
      if not awake and not asleep(e) then awake = e end
    end
  end
  local t = awake or first
  if last and not last.dead and (not asleep(last) or not awake) then t = last end
  -- même règle de cible que le familier : une zone peut la changer (crochet « petTarget »)
  return t and Combat.zmodify(c, "petTarget", t) or nil
end

function Warrior.chargeDamage(c, up)
  local b = c.player.block or 0
  if b <= 0 then return 0 end
  return floor(b / E.shield_charge.div) + num("shield_charge", "bonus", up)
end

do
  local hooks = {
    onTurnEnd = function(c, src)
      if c.result then return end
      local n = Warrior.chargeDamage(c, src)
      local t = n > 0 and Warrior.chargeTarget(c)
      if not t then return end
      Combat.log(c, { t = "epic_trigger", card = "shield_charge", unit = t.uid })
      hitAs(c, false, c.player, t, Combat.calcDamage(c, c.player, t, n))
    end,
  }
  attach("shield_charge", hooks)
end

-- Burning Steppes — Anger Management : la Rage dépensée (Spend payé, montant d'un Surge) s'ajoute à un
-- compteur du combat (c.cls.amSpent, reste gardé d'un tour à l'autre) ; à chaque tranche (E.per : 1), chaque
-- carte en recharge revient un tour plus tôt (amélioré : deux, Warrior.cooldownTick). Une carte dont la recharge
-- arrive à 0 revient en main aussitôt ; main pleine : au début du tour suivant. Débouché du deck de départ : une
-- carte qui dépense (Spend, Surge) part en recharge E.give (1) au lieu de la défausse (crochet moteur
-- giveCooldown), qu'elle ait dépensé ou non ; elle revient au tour suivant, ou aussitôt par la dépense suivante.
function Warrior.cooldownTick(c)
  local keep = {}
  for i = 1, #c.cooldown do
    local cd = c.cooldown[i]
    local turns = cd.turns - 1
    if turns <= 0 and #c.hand < Combat.HAND_MAX then
      c.hand[#c.hand + 1] = cd.card
      Combat.log(c, { t = "cooldown_back", card = cd.card.uid })
    else
      keep[#keep + 1] = { card = cd.card, turns = turns > 0 and turns or 0 }
    end
  end
  c.cooldown = keep
end

-- (nombres lus à chaque dépense : Warrior.EPIC reste réglable ; Haste 1, 2, 3, 4 selon le palier)
local function angerHooks()
  local function spent(c, src, n)
    local per, steps = E.anger_management.per, num("anger_management", "steps", src)
    local cls = c.cls
    cls.amSpent = (cls.amSpent or 0) + n
    while cls.amSpent >= per do
      cls.amSpent = cls.amSpent - per
      if #c.cooldown > 0 then Combat.log(c, { t = "epic_trigger", card = "anger_management" }) end
      for _ = 1, steps do Warrior.cooldownTick(c) end
    end
  end
  return {
    onSpend = function(c, src, n) spent(c, src, n) end,
    onSurge = function(c, src, n) spent(c, src, n) end,
      -- débouché de départ : les cartes qui dépensent (Spend, Surge : Heroic Strike dès le deck de départ) partent
    -- en recharge (E.give tours, 0 : à la défausse) au lieu de la défausse
    giveCooldown = function(c, src, v, d)
      local g = E.anger_management.give or 0
      if v == nil and g > 0 and Warrior.spends(d) then return g end
      return v
    end,
  }
end

-- Carte qui dépense la Rage (Spend N ou Surge).
function Warrior.spends(d)
  return d.spend ~= nil or hasEffect(d, "surge")
end
attach("anger_management", angerHooks(), nil, function(c) c.cls.amSpent = 0 end)

-- Blackrock Mountain — Avatar : plafond de Rage à 10 (crochet resCap) ; au début de chaque tour, +2 Rage
-- (amélioré : +3). Les cartes « per Rage » lisent la Rage réelle (Execute 5 + 4 × 10). Débouché de la Rage
-- gardée : à 10 Rage (E.over = 9 : chaque Rage au-delà de 9), chaque coup d'une carte Attack +1 (E.bonus), lu au
-- coup, après le Spend ou le Surge de la carte (crochet damage, avant Death Wish, Demoralized et Sundered).
function Warrior.avatarBonus(c)
  local A = E.avatar
  local over = (c.player.res or 0) - A.over
  return over > 0 and over * A.bonus or 0
end

-- Paliers : +2, +3, +4, +5 Rage par tour.
attach("avatar", {
  resCap = function(c, src, v) return math.max(v, E.avatar.cap) end,
  onTurnStart = function(c, src) Combat.gainRes(c, num("avatar", "gain", src), "avatar") end,
  -- débouché de la Rage gardée : les coups des cartes Attack +bonus par Rage au-delà de over (lue au coup)
  damage = function(c, src, v, dst, d)
    if d and d.type == "attack" then return v + Warrior.avatarBonus(c) end
    return v
  end,
})
