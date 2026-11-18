-- Coups « sans carte » du joueur, communs aux classes (contrat : docs/classes.md, « Coup sans carte ») :
-- familier du Hunter (Core/Classes/hunter.lua), et, pour le Druid (docs/classes/druid.md, § 1.3 et § 1.4),
-- frappe de l'ours et coups à tous de fin de tour de Moonkin.
--
-- Un coup sans carte se calcule comme un coup du joueur SANS carte (Combat.calcDamage avec cardDef nil :
-- Strength et Demoralized du joueur, Sundered et Absorb de la cible ; les bonus « Attacks » des cartes,
-- Powers et bibelots ne s'appliquent pas). Ce fichier ne lit aucune règle de classe : base, cible, gain de
-- ressource, journal, événement et compteurs sont passés par l'appelant.
local _, ns = ...

local Combat = ns.Combat

-- Cible habituelle d'un coup sans carte : la dernière cible visée (c.player.lastTarget, posée par
-- Combat.play) si elle vit, sinon l'ennemi vivant le plus à gauche ; nil s'il n'y en a pas.
function Combat.strikeTarget(c)
  local uid = c.player.lastTarget
  if uid then
    local e = Combat.enemyByUid(c, uid)
    if e and not e.dead then return e end
  end
  for i = 1, #c.enemies do
    if not c.enemies[i].dead then return c.enemies[i] end
  end
  return nil
end

-- Dégâts d'un coup sans carte sur t (affichage, bots) : base (+ la ressource actuelle si addRes).
function Combat.strikeDamage(c, t, base, addRes)
  if addRes then base = base + (c.player.res or 0) end
  return Combat.calcDamage(c, c.player, t, base, nil)
end

local function stat(c, key, n)
  local s = c.stats
  if s and key then s[key] = (s[key] or 0) + (n or 1) end
end

-- Un coup sans carte. Renvoie les dégâts calculés sur la première cible (0 : aucun coup).
--   why    : raison, écrite au journal et passée à l'événement ("auto", "card", "surge", "relic"…).
--   base   : dégâts de base avant Combat.calcDamage ; opts.res : + c.player.res, relu à chaque coup.
--   target : unité ennemie (déjà choisie par l'appelant ; morte ou nil : aucun coup), "last"
--            (Combat.strikeTarget) ou "all" (chaque ennemi vivant, de gauche à droite).
--   log    : type de l'entrée de journal, une par ennemi touché, juste avant le coup :
--            { t = log, dst, dmg, why } (plus all = true quand le coup touche tous les ennemis).
--   event  : événement émis une fois après les coups, Combat.fire(c, event, première cible, dégâts, why),
--            sauf si le combat est fini ; nil = aucun.
--   opts   : table facultative, jamais modifiée (une table constante peut servir à chaque appel) :
--     res     = vrai : la ressource actuelle s'ajoute à base (lue au calcul de chaque coup) ;
--     all     = vrai : après la cible, chaque autre ennemi vivant (de gauche à droite) ;
--     less    = n : avec all ou "all", les ennemis autres que le premier prennent n de moins (jamais < 0) ;
--     gain    = n : ressource gagnée après les coups (Combat.gainRes(c, n, gainWhy)), avant l'événement ;
--     gainWhy = raison du gain (crochet « onResource ») ;
--     count, total = clés de c.stats : nombre de coups et dégâts portés (rapports de simulation) ;
--     kind    = genre du coup pour les crochets de dégâts (c.hitKind, Combat.hitInfo : "pet", "other"…),
--               posé le temps des coups, avec hitAll vrai pour "all" ou all ; nil = celui de l'appelant
--               (le familier du Hunter : "pet", posé par Core/ZoneRules.lua autour de Hunter.petAttack).
-- Le combat fini (c.result) : rien ; fini pendant les coups : les coups suivants, le gain et l'événement
-- sont sautés.
-- Exemples : familier du Hunter : Combat.strike(c, "card", Hunter.PET_BASE, Hunter.petTarget(c),
--   "pet_attack", "onPetAttack", { res = true, gain = 1, gainWhy = "pet" }) ;
--   frappe de l'ours : Combat.strike(c, "auto", 1, "last", "bear_strike", "onBearStrike",
--   { res = true, gain = 1, gainWhy = "strike" }) ;
--   coups à tous de Moonkin : Combat.strike(c, "auto", math.min(3, math.ceil(res / 2)), "all",
--   "moonkin_pulse", "onMoonkinPulse").
local NONE = {}
function Combat.strike(c, why, base, target, log, event, opts)
  if c.result then return 0 end
  opts = opts or NONE
  local all = opts.all
  local t = target
  if target == "last" then
    t = Combat.strikeTarget(c)
  elseif target == "all" then
    t, all = nil, true
    for i = 1, #c.enemies do
      if not c.enemies[i].dead then t = c.enemies[i] break end
    end
  end
  if not t or t.dead then return 0 end
  local res = opts.res
  local k0, a0 = c.hitKind, c.hitAll
  if opts.kind then c.hitKind, c.hitAll = opts.kind, all and true or false end
  local dmg = Combat.strikeDamage(c, t, base, res)
  if all then
    -- tous les ennemis vivants, la première cible d'abord ; dmg rendu = celui de la première cible ; les
    -- autres opts.less de moins
    local list = { t }
    for i = 1, #c.enemies do
      local o = c.enemies[i]
      if o ~= t and not o.dead then list[#list + 1] = o end
    end
    local less = opts.less or 0
    for i = 1, #list do
      local o = list[i]
      if not o.dead and not c.result then
        local d = Combat.strikeDamage(c, o, base, res)
        if i > 1 then d = math.max(0, d - less) end
        Combat.log(c, { t = log, dst = o.uid, dmg = d, why = why, all = true })
        stat(c, opts.count)
        stat(c, opts.total, d)
        Combat.dealDamage(c, c.player, o, d)
      end
    end
  else
    Combat.log(c, { t = log, dst = t.uid, dmg = dmg, why = why })
    stat(c, opts.count)
    stat(c, opts.total, dmg)
    Combat.dealDamage(c, c.player, t, dmg)
  end
  if opts.kind then c.hitKind, c.hitAll = k0, a0 end
  if c.result then return dmg end
  if (opts.gain or 0) ~= 0 then Combat.gainRes(c, opts.gain, opts.gainWhy) end
  if event then Combat.fire(c, event, t, dmg, why) end
  return dmg
end
