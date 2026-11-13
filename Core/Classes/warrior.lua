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
    local id, up = Warrior.epicOf(c)
    if id == "anger_management" then
      local per = up and Warrior.EPIC.anger_management.upPer or Warrior.EPIC.anger_management.per
      return (c.cls.amSpent or 0) / per * 12
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
Warrior.EPIC = {
  death_wish = { mult = 1.5, heal = 3 },
  thunderous_roar = { at = 5, damage = 3, upDamage = 4, demoralized = 0, upDemoralized = 1 },
  sweeping_strikes = { targets = 1, upTargets = 2, div = 3 },
  titans_grip = { limit = 2, extraCost = 1, copies = 1, selfStates = true },
  shield_charge = { div = 4, upBonus = 4 },
  anger_management = { per = 1, upPer = 1, steps = 1, upSteps = 2, give = 1 },
  avatar = { cap = 10, gain = 2, upGain = 3, over = 9, bonus = 1 },
}
local E = Warrior.EPIC
Warrior.EPICS = { "death_wish", "thunderous_roar", "sweeping_strikes", "titans_grip", "shield_charge",
  "anger_management", "avatar" }
local IS_EPIC = {}
for _, id in ipairs(Warrior.EPICS) do IS_EPIC[id] = true end

-- Épique du Guerrier en jeu dans ce combat (c.epic, posée par Combat.new) : id, amélioré ; nil sans épique.
function Warrior.epicOf(c)
  local e = c.epic
  if e and IS_EPIC[e.id] then return e.id, e.up end
  return nil
end

-- Mots du langage (déclencheurs « Name: » des textes) et plaque « Epic » (si le socle ne l'a pas posée).
L.trigger("Kills")
L.trigger("At 5 Rage")
L.trigger("Targeted Attack hits")
L.trigger("Each Rage spent")
L.trigger("At 10 Rage")
L.trigger("Spend and Surge cards")
do
  local has = false
  for _, p in ipairs(L.plates) do if p.word == "Epic" then has = true end end
  if not has then
    L.plate("epic", { word = "Epic", head = true, text = "in play from the start of each combat." })
  end
end

-- Genre du coup sans carte d'une épique (Combat.hitInfo : règles de zone, Rude Awakening du Swamp) : posé le
-- temps du coup puis remis. all = vrai : coup « à tous » (onde, rebond), faux : à une cible (Shield Charge).
local function hitAs(c, all, f, ...)
  local k0, a0 = c.hitKind, c.hitAll
  c.hitKind, c.hitAll = "other", all
  f(...)
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

-- Westfall — Death Wish : aucun Absorb gagné ; les coups des cartes Attack +50 % (après Strength, avant
-- Sundered, arrondi à l'inférieur : crochet attackMult) ; amélioré : chaque ennemi tué soigne de 3.
do
  local base = {
    canGainBlock = function() return false end,
    attackMult = function(c, src, v) return v * E.death_wish.mult end,
  }
  local up = {
    canGainBlock = base.canGainBlock,
    attackMult = base.attackMult,
    onEnemyDeath = function(c) Combat.heal(c, c.player, E.death_wish.heal) end,
  }
  attach("death_wish", base, up)
end

-- Duskwood — Thunderous Roar : dès que la Rage atteint 5 (juste après le gain, quelle qu'en soit la source),
-- elle tombe à 0, le Guerrier inflige 3 (amélioré : 4) à chaque ennemi vivant, sans carte (Strength
-- comprise), coup « à tous ». Demoralized (E.demoralized, 0 ; amélioré E.upDemoralized, 1) : posé ensuite sur chacun ; pendant le
-- tour ennemi, il ne dure que jusqu'à la fin du round (l'état posé n'est pas protégé de la baisse).
function Warrior.roar(c, up)
  local p = c.player
  Combat.gainRes(c, -(p.res or 0), "roar")
  Combat.log(c, { t = "epic_trigger", card = "thunderous_roar" })
  local n = up and E.thunderous_roar.upDamage or E.thunderous_roar.damage
  local list = Combat.aliveEnemies(c)
  for i = 1, #list do
    local e = list[i]
    if not e.dead and not c.result then hitAs(c, true, Combat.dealDamage, c, p, e, Combat.calcDamage(c, p, e, n)) end
  end
  if c.result then return end
  local T = E.thunderous_roar
  local demo = up and (T.upDemoralized or T.demoralized) or T.demoralized
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
      Warrior.roar(c, src.up)
    end,
  }
  attach("thunderous_roar", hooks)
end

-- Wetlands — Sweeping Strikes : chaque coup d'une carte Attack à cible inflige aussi le tiers (E.div) des PV qu'il
-- a fait perdre (arrondi à l'inférieur) à un autre ennemi vivant tiré par c.rng.cards (amélioré : deux,
-- sans remise). Le rebond est un coup sans carte (ctx nil) : ni Rage, ni Deep Wounds, ni nouveau rebond.
local function sweepHooks(count)
  return {
    onDamageDealt = function(c, src, t, loss, ctx)
      if not ctx or not ctx.def or ctx.def.type ~= "attack" or ctx.def.target ~= "enemy" then return end
      if t ~= ctx.target then return end
      local n = floor(loss / E.sweeping_strikes.div)
      if n <= 0 then return end
      local others = {}
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        if e ~= t and not e.dead then others[#others + 1] = e end
      end
      for _ = 1, count do
        if #others == 0 or c.result then return end
        local e = table.remove(others, Rng.int(c.rng.cards, 1, #others))
        Combat.log(c, { t = "epic_trigger", card = "sweeping_strikes", unit = e.uid })
        hitAs(c, true, Combat.dealDamage, c, c.player, e, n)
      end
    end,
  }
end
attach("sweeping_strikes", sweepHooks(E.sweeping_strikes.targets), sweepHooks(E.sweeping_strikes.upTargets))

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
  return floor(b / E.shield_charge.div) + (up and E.shield_charge.upBonus or 0)
end

do
  local hooks = {
    onTurnEnd = function(c, src)
      if c.result then return end
      local n = Warrior.chargeDamage(c, src.up)
      local t = n > 0 and Warrior.chargeTarget(c)
      if not t then return end
      Combat.log(c, { t = "epic_trigger", card = "shield_charge", unit = t.uid })
      hitAs(c, false, Combat.dealDamage, c, c.player, t, Combat.calcDamage(c, c.player, t, n))
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

-- (nombres lus à chaque dépense : Warrior.EPIC reste réglable)
local function angerHooks(up)
  local function spent(c, n)
    local A = E.anger_management
    local per, steps = up and A.upPer or A.per, up and A.upSteps or A.steps
    local cls = c.cls
    cls.amSpent = (cls.amSpent or 0) + n
    while cls.amSpent >= per do
      cls.amSpent = cls.amSpent - per
      if #c.cooldown > 0 then Combat.log(c, { t = "epic_trigger", card = "anger_management" }) end
      for _ = 1, steps do Warrior.cooldownTick(c) end
    end
  end
  return {
    onSpend = function(c, src, n) spent(c, n) end,
    onSurge = function(c, src, n) spent(c, n) end,
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
attach("anger_management", angerHooks(false), angerHooks(true),
  function(c) c.cls.amSpent = 0 end)

-- Blackrock Mountain — Avatar : plafond de Rage à 10 (crochet resCap) ; au début de chaque tour, +2 Rage
-- (amélioré : +3). Les cartes « per Rage » lisent la Rage réelle (Execute 5 + 4 × 10). Débouché de la Rage
-- gardée : à 10 Rage (E.over = 9 : chaque Rage au-delà de 9), chaque coup d'une carte Attack +1 (E.bonus), lu au
-- coup, après le Spend ou le Surge de la carte (crochet damage, avant Death Wish, Demoralized et Sundered).
function Warrior.avatarBonus(c)
  local A = E.avatar
  local over = (c.player.res or 0) - A.over
  return over > 0 and over * A.bonus or 0
end

local function avatarHooks(up)
  return {
    resCap = function(c, src, v) return math.max(v, E.avatar.cap) end,
    onTurnStart = function(c) Combat.gainRes(c, up and E.avatar.upGain or E.avatar.gain, "avatar") end,
    -- débouché de la Rage gardée : les coups des cartes Attack +bonus par Rage au-delà de over (lue au coup)
    damage = function(c, src, v, dst, d)
      if d and d.type == "attack" then return v + Warrior.avatarBonus(c) end
      return v
    end,
  }
end
attach("avatar", avatarHooks(false), avatarHooks(true))
