-- Règles de la zone Wetlands (`wetlands`) : mécanique Pack de la fiche docs/zones/wetlands.md, sur le socle
-- ns.ZoneRules (contrat et crochets : docs/zones.md). Lua 5.1 pur, aucune API WoW.
--
-- Pack. Un ennemi porte `pack = { "force" | "heal" | "absorb", n }` (membre qui donne cette prime à sa mort),
-- `pack = true` (membre sans prime) ou `packLeader = true` (chef). Les membres vivants d'un combat forment la
-- meute. À la mort d'un membre, sa prime (ou la dispersion, pour le chef) entre dans une file ; la file est
-- réglée à la FIN de l'effet en cours (onEffectEnd : carte, incantation, Trap, DoT, potion, action ennemie,
-- début ou fin de tour) : chaque membre encore vivant reçoit chaque prime, de gauche à droite (un membre tué
-- par le même effet ne reçoit rien). Chef tué dans l'effet : les primes de cet effet sont annulées et la
-- meute se disperse (Scattered : ne donne ni ne reçoit plus rien ; pas de Demoralized, décisions du
-- 13/11/2026) ; un membre invoqué ensuite arrive dispersé. Victoire : la file est perdue.
-- Élites : Modr (Earthen Charge), Dragonmaw Centurion (Wyrmscale Armor).
local _, ns = ...

local Combat, ZR = ns.Combat, ns.ZoneRule
local L = ns.Language
local ID = "wetlands"

local WL = {}
ns.Wetlands = WL

---------------------------------------------------------------------------
-- États
---------------------------------------------------------------------------

-- Charge de Modr : affichée comme un état empilé (3 au plus) ; la règle est dans les crochets plus bas.
ns.Statuses.earthen_charge = { name = "Earthen Charge", max = 3,
  text = "Seismic Slam deals 8 more per Charge." }
-- Armure du Dragonmaw Centurion, prête (jeton sans nombre) : le prochain coup subi perd 10 dégâts.
ns.Statuses.wyrmscale = { name = "Wyrmscale Armor", flag = true,
  text = "The next hit it takes deals 10 less damage. Ready again at the start of your turn. DoT ignores it." }

-- Blessure mortelle des Dragonmaw (Mortal Strike du Raider, Cleave de Nek'rosh) : soins reçus divisés par deux.
ns.Statuses.mortal_wound = { name = "Mortal Wound", debuff = true, duration = true,
  text = "Healing received is halved." }

L.zoneKeyword(ID, "pack", { name = "Pack", text = "When it dies, its packmates gain the bonus shown." })
L.zoneKeyword(ID, "pack_leader", { name = "Pack Leader", text = "When it dies, its pack scatters." })
L.zoneKeyword(ID, "scattered", { name = "Scattered", text = "No longer part of a pack." })

---------------------------------------------------------------------------
-- Meute
---------------------------------------------------------------------------

WL.BONUS_NAME = { force = "Strength", heal = "heal", absorb = "Absorb" }

local function ustate(e) return ZR.unitState(e, ID) end

-- Vrai si l'ennemi fait partie de la meute (Pack, chef ou membre sans prime, non dispersé).
function WL.member(e)
  local d = ns.Enemies[e.id]
  if not d or not (d.pack or d.packLeader) then return false end
  return not (e.zs and e.zs[ID] and e.zs[ID].scattered)
end

-- Prime de l'ennemi : { genre, n } ou nil (chef, membre sans prime, dispersé).
function WL.bonus(e)
  if not WL.member(e) then return nil end
  local p = ns.Enemies[e.id].pack
  return type(p) == "table" and p or nil
end

function WL.leader(e)
  return WL.member(e) and ns.Enemies[e.id].packLeader == true
end

function WL.scattered(e)
  return e.zs ~= nil and e.zs[ID] ~= nil and e.zs[ID].scattered == true
end

-- Membres vivants de la meute.
function WL.alive(c)
  local list = {}
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if not o.dead and WL.member(o) then list[#list + 1] = o end
  end
  return list
end

-- Applique une prime à un ennemi ; renvoie ce qui a été réellement donné (soin : PV rendus).
local function give(c, z, src, o, b)
  local kind, n = b[1], b[2]
  local got = n
  if kind == "force" then
    Combat.applyStatus(c, o, "force", n)
    ZR.float(c, o.uid, "+" .. n .. " Strength", "attackText")
    Combat.zstat(c, "packForce", n)
  elseif kind == "heal" then
    got = Combat.heal(c, o, n)
    if got > 0 then ZR.float(c, o.uid, "+" .. got .. " HP", "healText") end
    Combat.zstat(c, "packHeal", got)
    Combat.zstat(c, "packHealLost", n - got)
  elseif kind == "absorb" then
    Combat.gainBlock(c, o, n)
    ZR.float(c, o.uid, "+" .. n .. " Absorb", "defendText")
    Combat.zstat(c, "packAbsorb", n)
  end
  Combat.log(c, { t = "pack", src = src, dst = o.uid, bonus = kind, n = n, got = got })
end

-- Disperse la meute : chaque membre vivant devient Scattered ; les invocations suivantes aussi.
local function scatter(c, z, by)
  z.scattered = true
  local list = WL.alive(c)
  for i = 1, #list do
    ustate(list[i]).scattered = true
    ZR.float(c, list[i].uid, "Scattered", "watchText")
  end
  Combat.log(c, { t = "scatter", by = by })
  Combat.zstat(c, "scatters")
end

-- Règle les morts de l'effet id (nil : toutes les morts en attente).
local function settle(c, z, id)
  local q = z.queue
  if not q or #q == 0 or c.result then return end
  local now, rest = {}, {}
  for i = 1, #q do
    if id == nil or q[i].effect == id then now[#now + 1] = q[i] else rest[#rest + 1] = q[i] end
  end
  z.queue = rest
  if #now == 0 then return end
  if #now > 1 then Combat.zstat(c, "packGroupKills", #now) end
  -- de gauche à droite (place dans le combat)
  table.sort(now, function(a, b) return a.pos < b.pos end)
  for i = 1, #now do
    if now[i].leader then
      Combat.zstat(c, "packBonusesCancelled", #now - 1)
      scatter(c, z, now[i].src)
      return
    end
  end
  for i = 1, #now do
    local en = now[i]
    if en.bonus then
      local list = WL.alive(c)
      if #list == 0 then Combat.zstat(c, "packBonusesUnclaimed") end
      for j = 1, #list do give(c, z, en.src, list[j], en.bonus) end
    end
  end
end
WL.settle = settle

-- Mort d'un membre : prime (ou dispersion) en attente jusqu'à la fin de l'effet en cours.
local function onDeath(c, z, e, info)
  if not WL.member(e) then return end
  local d = ns.Enemies[e.id]
  local pos = 0
  for i = 1, #c.enemies do if c.enemies[i] == e then pos = i end end
  local b = type(d.pack) == "table" and d.pack or nil
  if d.packLeader then
    -- ordre de mort du chef : premier membre tué du combat ou non
    Combat.zstat(c, (z.deaths or 0) == 0 and "leaderFirst" or "leaderLater")
  end
  z.deaths = (z.deaths or 0) + 1
  if not b and not d.packLeader then return end
  z.queue = z.queue or {}
  z.queue[#z.queue + 1] = { effect = info and info.effect, src = e.uid, pos = pos,
    bonus = b and { b[1], b[2] } or nil, leader = d.packLeader or nil }
  -- hors de tout effet (appel direct) : réglée tout de suite
  if not (info and info.effect) then settle(c, z, nil) end
end

---------------------------------------------------------------------------
-- Modr : Earthen Charge
---------------------------------------------------------------------------

-- PV perdus depuis son tour précédent ; vrai si la Charge monte à son prochain tour (prévision : son DoT
-- compte, il part avant le test).
function WL.chargePending(c, e)
  local d = ns.Enemies[e.id]
  if not d.chargeAt or e.dead then return false end
  local s = ustate(e)
  if s.checked == c.round and c.step == "enemy" then return false end
  if (e.st.earthen_charge or 0) >= ns.Statuses.earthen_charge.max then return false end
  return (s.lost or 0) + (e.st.pain or 0) < d.chargeAt
end

function WL.lostSince(e) return (e.zs and e.zs[ID] and e.zs[ID].lost) or 0 end

local function chargeCheck(c, e)
  local d = ns.Enemies[e.id]
  if not d.chargeAt then return end
  local s = ustate(e)
  if (s.lost or 0) < d.chargeAt then
    if (e.st.earthen_charge or 0) < ns.Statuses.earthen_charge.max then
      Combat.applyStatus(c, e, "earthen_charge", 1)
      Combat.zstat(c, "modrCharges")
    end
  else
    Combat.zstat(c, "modrChargeDenied")
  end
  s.lost = 0
  s.checked = c.round
end

-- Charges comptées par Seismic Slam : celles qu'il porte, plus celle qu'il gagnera au début de son tour.
Combat.ENEMY_AMOUNTS.earthen_charge = function(c, e)
  return (e.st.earthen_charge or 0) + (WL.chargePending(c, e) and 1 or 0)
end

-- { "discharge" } : les Charges retombent à 0.
Combat.ENEMY_ACTIONS.discharge = function(c, e)
  if (e.st.earthen_charge or 0) > 0 then
    Combat.zstat(c, "modrSlamCharges", e.st.earthen_charge)
    e.st.earthen_charge = nil
    Combat.log(c, { t = "status", unit = e.uid, id = "earthen_charge", n = 0, total = 0 })
  end
end

---------------------------------------------------------------------------
-- Règle
---------------------------------------------------------------------------

ZR.define(ID, {
  init = function(c, z)
    z.queue = {}
  end,
  hooks = {
    onEnemyDeath = onDeath,
    onEffectEnd = function(c, z, kind, id) settle(c, z, id) end,
    -- filet de sécurité : rien ne reste en attente d'un tour à l'autre
    onEnemyPhaseStart = function(c, z) settle(c, z, nil) end,
    onTurnStart = function(c, z)
      settle(c, z, nil)
      -- Wyrmscale Armor prête à chaque début de tour du joueur
      for i = 1, #c.enemies do
        local o = c.enemies[i]
        if not o.dead and ns.Enemies[o.id].wyrmscale and not o.st.wyrmscale then
          Combat.applyStatus(c, o, "wyrmscale", 1)
        end
      end
    end,
    -- Mortal Wound : soins reçus par le joueur divisés par deux (arrondi en dessous)
    heal = function(c, z, v)
      if (c.player.st.mortal_wound or 0) > 0 and v > 0 then
        Combat.zstat(c, "mortalWoundHealLost", v - math.floor(v / 2))
        return math.floor(v / 2)
      end
      return v
    end,
    -- membre invoqué après la dispersion : dispersé d'office
    onEnemySpawn = function(c, z, e)
      if z.scattered and WL.member(e) then ustate(e).scattered = true end
    end,
    -- Wyrmscale Armor : le premier coup (pas le DoT) perd jusqu'à def.wyrmscale dégâts (10)
    enemyDamageTaken = function(c, z, v, e, src)
      if e.st.wyrmscale and src.kind ~= "dot" and v > 0 then
        local cut = math.min(v, ns.Enemies[e.id].wyrmscale or v)
        e.st.wyrmscale = nil
        Combat.log(c, { t = "status", unit = e.uid, id = "wyrmscale", n = -1, total = 0 })
        ZR.float(c, e.uid, "Wyrmscale Armor -" .. cut, "defendText")
        Combat.zstat(c, "wyrmscaleHits")
        Combat.zstat(c, "wyrmscaleSaved", cut)
        return v - cut
      end
      return v
    end,
    -- Modr : PV perdus depuis son tour (DoT compris)
    onEnemyDamaged = function(c, z, e, loss)
      if loss > 0 and ns.Enemies[e.id].chargeAt then
        local s = ustate(e)
        s.lost = (s.lost or 0) + loss
      end
    end,
    -- Modr : test de la Charge au début de son tour, après son DoT (aussi s'il est étourdi)
    enemyMove = function(c, z, mv, e)
      if ns.Enemies[e.id].chargeAt then chargeCheck(c, e) end
      return mv
    end,
    onEnemyStunned = function(c, z, e)
      if ns.Enemies[e.id].chargeAt then chargeCheck(c, e) end
    end,
  },
})
