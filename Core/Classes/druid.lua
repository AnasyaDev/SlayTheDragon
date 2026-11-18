-- Règles propres du Druide (fiche : docs/classes/druid.md ; contrat : docs/classes.md).
--
-- Forme : état de classe c.cls.form = nil (sans forme, début de chaque combat) | "cat" | "bear" | "moonkin" |
--   "tree". Jouer une carte dont le champ `form` diffère de la forme active fait entrer dans sa forme
--   (crochet de classe onCardCommitted : après tous les coûts, payés dans la forme d'avant ; avant
--   l'incantation ou la résolution, avant les Powers et bibelots) : journal { t = "shift", from, to },
--   événement propre « onShift » (from, to), compteur du tour c.cls.shifts. Une carte sans forme, une copie
--   (replay), la résolution d'un Cast au tour suivant ne changent jamais la forme.
-- Réserve : ressource commune c.player.res (« wild », 0 à 5, gardée), une seule valeur pour toutes les formes ;
--   son nom suit la forme (Core/Language.lua). Lecture : Moonkin, +1 par point à chaque coup des cartes Attack
--   (crochet damage, cardDef non nil : jamais un coup sans carte) ; Bear, frappe de 1 + réserve et −1 à la fin
--   de chaque round passé en Bear (onRoundEnd) ; Cat et Tree, rien de passif.
-- Effet de fin de tour (onTurnEnd, avant Powers, bibelots et défausse), selon la forme active :
--   Bear : frappe de l'ours (Druid.bearStrike) ; Cat : état Clearcasting (drapeau, ne s'empile pas : la
--   prochaine Attack hors Cast coûte 0, consommé au jeu par cette Attack) ; Moonkin : coup sans carte à tous,
--   ceil(réserve / 2), PULSE_MAX au plus ; Tree : Regen TREE_REGEN ; sans forme : rien.
-- Levier de secours A (fiche § 1.6, inactif : TAX = 0) : à partir du (TAX_FREE + 1)-ième changement d'un tour,
--   TAX mana de moins au tour suivant par changement, TAX_MAX au plus (crochet maxMana, c.cls.tax).
local _, ns = ...

local Combat = ns.Combat
local L = ns.Language

local Druid = {}
ns.Druid = Druid

-- Réglages (points de départ de la fiche, à régler par la simulation : docs/classes/druid.md, § 10).
Druid.STRIKE_BASE = 1   -- frappe de l'ours : 1 + réserve
Druid.PULSE_MAX = 3     -- Moonkin, fin de tour : ceil(Charges / 2) à chaque ennemi, au plus
Druid.TREE_REGEN = 1    -- Tree of Life, fin de tour : Regen gagnée
Druid.TAX = 0           -- levier A : mana perdu au tour suivant par changement au-delà de TAX_FREE (0 = inactif)
Druid.TAX_FREE = 2      -- changements gratuits par tour
Druid.TAX_MAX = 2       -- mana perdu au plus (il reste 1 mana sur 3)
Druid.FORMS = { "cat", "bear", "moonkin", "tree" }

-- État du héros posé par la fin de tour en Cat (fiche § 1.3) : drapeau, sans nombre ni durée.
ns.Statuses.clearcasting = { name = "Clearcasting", flag = true,
  text = "Next Attack played costs 0, except Cast cards." }

-- Langage : déclencheurs des Powers (« Cat Attacks: », « End of turn in Moonkin: »). Le mot « Bear strikes »,
-- la plaque de forme et la ressource « wild » sont déclarés par Core/Language.lua.
L.trigger("Cat Attacks")
L.trigger("End of turn in Moonkin")

-- Montant « regen » (per = { k, "regen" }) : Regen du Druide (Swiftmend : « Heal 2 per Regen. »).
Combat.AMOUNTS.regen = function(c) return c.player.st.regen or 0 end

local function stat(c, key, n) Combat.zstat(c, key, n) end

-- Forme active (nil = sans forme).
function Druid.form(c) return c.cls and c.cls.form or nil end

-- La carte d changerait-elle la forme si on la jouait maintenant ? (Idol of the Wild, marque en main)
function Druid.wouldShift(c, d)
  return d.form ~= nil and d.form ~= Druid.form(c)
end

-- Changement de forme (au jeu d'une carte de forme) : journal, compteur du tour, événement « onShift ».
function Druid.shift(c, to)
  local cls = c.cls
  local from = cls.form
  if from == to then return false end
  cls.form = to
  cls.shifts = (cls.shifts or 0) + 1
  Combat.log(c, { t = "shift", from = from, to = to })
  stat(c, "druid_shifts")
  Combat.fire(c, "onShift", from, to)
  return true
end

-- Mana perdu au tour suivant pour n changements de forme dans un tour (levier A ; 0 tant que TAX = 0).
function Druid.taxOf(n)
  local over = (n or 0) - Druid.TAX_FREE
  if Druid.TAX <= 0 or over <= 0 then return 0 end
  return math.min(Druid.TAX_MAX, over * Druid.TAX)
end

-- Malus de mana à venir si le tour finissait maintenant (pastille de la vue).
function Druid.pendingTax(c) return Druid.taxOf(c.cls and c.cls.shifts or 0) end

-- Clearcasting : une carte Attack sans la plaque Cast (lue sur la carte, Instant ou non).
local function clearcastable(d) return d.type == "attack" and not d.cast end
Druid.clearcastable = clearcastable

-- Frappe de l'ours ---------------------------------------------------------------------------------
-- Coup sans carte commun (Combat.strike, Core/Companion.lua) de STRIKE_BASE (+ crochet « bearStrike » :
-- Idol of Brutality) + réserve sur la dernière cible (morte : l'ennemi vivant le plus à gauche), puis +1.
-- Genre du coup : « pet » (comme le familier du Hunter : coup sans carte à une cible) ; sa cible passe par le
-- crochet de zone « petTarget » (Swamp of Sorrows : la frappe de fin de tour évite les dormeurs tant qu'un
-- ennemi est éveillé ; commandée par une carte pendant le jeu, elle frappe la dernière cible, dormeur compris).
-- why : "auto" (fin de tour), "card", "surge" (counted = montant compté par le Surge : 1 + counted, sans gain).
local AUTO = { res = true, gain = 1, gainWhy = "strike", kind = "pet" }
local SURGE = { kind = "pet" }

function Druid.strikeTarget(c)
  local t = Combat.strikeTarget(c)
  if not t then return nil end
  return Combat.zmodify(c, "petTarget", t)
end

function Druid.strikeBase(c)
  return Combat.modify(c, "bearStrike", Druid.STRIKE_BASE)
end

function Druid.bearStrike(c, why, counted)
  if c.result then return 0 end
  local t = Druid.strikeTarget(c)
  if not t then return 0 end
  stat(c, "druid_bear_strikes")
  if counted then
    return Combat.strike(c, why, Druid.strikeBase(c) + counted, t, "bear_strike", "onBearStrike", SURGE)
  end
  return Combat.strike(c, why, Druid.strikeBase(c), t, "bear_strike", "onBearStrike", AUTO)
end

-- Dégâts de la prochaine frappe sur sa cible (affichage, bots).
function Druid.strikeDamage(c, t)
  t = t or Druid.strikeTarget(c)
  if not t then return 0 end
  return Combat.strikeDamage(c, t, Druid.strikeBase(c), true)
end

-- { "bearStrike", n, surge = bool, per = … } : « Bear strikes. » / « twice » / « once per Frenzy » (Surge).
ns.Effects.bearStrike = function(c, ctx, e)
  local n = e[2] or 1
  if e.more or e.per then n = Combat.amount(c, ctx, e, n, ctx.target) end
  for _ = 1, n do
    if e.surge then Druid.bearStrike(c, "surge", ctx.surge or 0) else Druid.bearStrike(c, "card") end
    if c.result then return end
  end
end

-- Coups à tous de fin de tour en Moonkin ------------------------------------------------------------
-- ceil(réserve / 2), PULSE_MAX au plus ; coup sans carte (ni bonus des Charges, ni bonus « Attacks »), genre
-- « other » à tous (réveil doux des dormeurs).
local PULSE = { kind = "other" }

function Druid.pulseBase(c)
  return math.min(Druid.PULSE_MAX, math.ceil((c.player.res or 0) / 2))
end

function Druid.moonkinPulse(c)
  local n = Druid.pulseBase(c)
  if n <= 0 or c.result then return 0 end
  stat(c, "druid_pulses")
  return Combat.strike(c, "auto", n, "all", "moonkin_pulse", "onMoonkinPulse", PULSE)
end

-- Effet de fin de tour de la forme active.
function Druid.endOfTurn(c)
  local form = c.cls.form
  local p = c.player
  stat(c, "druid_end_" .. (form or "none"))
  if form == "bear" then
    Druid.bearStrike(c, "auto")
  elseif form == "cat" then
    if (p.st.clearcasting or 0) <= 0 then
      Combat.applyStatus(c, p, "clearcasting", 1)
      Combat.log(c, { t = "clearcasting" })
    end
  elseif form == "moonkin" then
    Druid.moonkinPulse(c)
  elseif form == "tree" then
    Combat.applyStatus(c, p, "regen", Druid.TREE_REGEN)
  end
end

-- Bots ----------------------------------------------------------------------------------------------
Druid.CLEARCAST_VALUE = 22 -- un mana (evoMana du Mage : 22 par mana)
Druid.TAX_VALUE = 22       -- un mana perdu au tour suivant (levier A)

ns.ClassRules.druid = {
  init = function(c, cls)
    cls.form = nil
    cls.shifts = 0
    cls.tax = 0
  end,
  hooks = {
    -- Clearcasting : une Attack hors Cast coûte 0 (coût affiché en main compris, Combat.cost)
    cost = function(c, cls, v, d)
      if (c.player.st.clearcasting or 0) > 0 and clearcastable(d) then return 0 end
      return v
    end,
    -- coût payé dans la forme d'avant : Clearcasting consommé, puis changement de forme, puis résolution
    onCardCommitted = function(c, cls, inst, d)
      local p = c.player
      if (p.st.clearcasting or 0) > 0 and clearcastable(d) then
        p.st.clearcasting = nil
        Combat.log(c, { t = "clearcasting_used", card = inst.uid })
        stat(c, "druid_clearcasting_used")
      end
      if d.form and d.form ~= cls.form then Druid.shift(c, d.form) end
    end,
    -- Moonkin : +1 par Charge à chaque coup d'une carte Attack (jamais un coup sans carte : cardDef nil)
    damage = function(c, cls, v, dst, cardDef)
      if cls.form == "moonkin" and cardDef and cardDef.type == "attack" then
        local n = c.player.res or 0
        if n > 0 then return v + n end
      end
      return v
    end,
    -- levier A : mana du tour qui commence (malus posé à la fin du tour précédent)
    maxMana = function(c, cls, v)
      local tax = cls.tax or 0
      if tax > 0 then return math.max(1, v - tax) end
      return v
    end,
    onTurnStart = function(c, cls)
      cls.shifts = 0
    end,
    onTurnEnd = function(c, cls)
      cls.tax = Druid.taxOf(cls.shifts)
      Druid.endOfTurn(c)
    end,
    -- Frenzy de l'ours : −1 à la fin de chaque round fini en Bear
    onRoundEnd = function(c, cls)
      if cls.form == "bear" and (c.player.res or 0) > 0 then Combat.gainRes(c, -1, "decay") end
    end,
  },
  -- Bots : forme (nil compris), Clearcasting, dernière cible (frappe de l'ours), bibelots de forme déjà servis,
  -- changements du tour (seulement si le levier A est actif).
  botKey = function(c)
    local cls, p, rs = c.cls, c.player, c.relicState
    local k = (cls.form or "-") .. ":" .. (p.st.clearcasting or 0) .. ":" .. tostring(p.lastTarget or 0) .. ":"
      .. (rs.idol_of_the_wild and 1 or 0) .. (rs.wolfshead_helm == c.round and 1 or 0)
    if Druid.TAX > 0 then k = k .. ":" .. (cls.shifts or 0) end
    return k
  end,
  -- Bots : Clearcasting posé (un mana au tour suivant), bonus des Charges d'un Cast Attack en attente qui se
  -- résoudra en Moonkin (Bots.castValue ne compte que la base), baisse du Frenzy à venir en Bear, mana perdu
  -- au tour suivant (levier A).
  botValue = function(c, W)
    local p, cls = c.player, c.cls
    local v = 0
    if (p.st.clearcasting or 0) > 0 then v = v + Druid.CLEARCAST_VALUE end
    local res = p.res or 0
    if cls.form == "moonkin" and res > 0 and p.cast then
      local d = ns.Card.def(p.cast.card)
      if d.type == "attack" then
        local alive = #Combat.aliveEnemies(c)
        for i = 1, #d.effects do
          local e = d.effects[i]
          if e[1] == "damage" then v = v + res * (e.times or 1) * (e.all and alive or 1) * W.enemyHp * W.castRisk end
        end
      end
    end
    if cls.form == "bear" and res > 0 then
      local cd = ns.Classes.druid
      v = v - (cd.bot and cd.bot.resValue or W.res)
    end
    v = v - (cls.tax or 0) * Druid.TAX_VALUE
    return v
  end,
}
