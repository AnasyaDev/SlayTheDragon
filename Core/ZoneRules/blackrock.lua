-- Règles de la zone Blackrock Mountain (`blackrock`) : fiche docs/zones/blackrock.md, socle ns.ZoneRules
-- (contrat et crochets : docs/zones.md). La mécanique de la zone, les phases, est celle du moteur commun
-- (def.phases : seuils, entrée, ouverture imposée, plafond au seuil du boss). Ce fichier ajoute :
--   * les règles de phase qui ne sont pas des états (Invincible de Panzor : 8 au plus par coup hors DoT,
--     champ maxHit ; Shadow of the Throne de Nefarius : moitié des dégâts tant qu'un Drakonid vit) ;
--   * les états de la zone (Fire Shield, Cracked Plating, Essence of the Red, Burning Adrenaline,
--     Shadowflame Fury, Veil of Shadow) et les cinq états du Class Call de Nefarian (un par classe) ;
--   * les actions de Nefarius et Nefarian (call_drakonid, class_call, raise_bones) et « clear » ;
--   * le suivi des ouvertures de phase (badge, statistiques) ;
--   * le titre « Dragonslayer » (drapeau de compte dragonslayer:<classe>) et Rallying Cry of the
--     Dragonslayer (+6 PV max à l'expédition suivante, une fois).
-- Lua 5.1 pur, aucune API WoW.
local _, ns = ...

local Combat, ZR, X = ns.Combat, ns.ZoneRule, ns.Expedition
local L = ns.Language
local S = ns.Statuses
local floor, min = math.floor, math.min

local BR = {}
ns.Blackrock = BR

BR.ADRENALINE_LOSS = 15   -- PV perdus à la fin de Burning Adrenaline
BR.FURY_STRENGTH = 10     -- Strength de Nefarian à la fin de Shadowflame Fury
BR.ESSENCE_MANA = 2       -- mana en plus par tour sous Essence of the Red
BR.CORRUPTED_DOT = 4      -- DoT posé par chaque soin sous Corrupted Healing
BR.BONES_MAX = 3          -- Bone Constructs relevés au plus
BR.RALLY_HP = 6           -- Rallying Cry of the Dragonslayer
BR.CALL_TURNS = 2         -- durée des états du Class Call
BR.BERSERKER_BONUS = 1    -- Berserker Stance : dégâts en plus par coup des Attacks
BR.BROKEN_BOW = 2         -- Broken Bow : dégâts en moins par coup des cartes Attack (pas le familier)

---------------------------------------------------------------------------
-- États
---------------------------------------------------------------------------

S.fire_shield = { name = "Fire Shield",
  text = "Each hit of your Attack cards or Traps on it: you lose X." }
S.cracked = { name = "Cracked Plating", debuff = true, flag = true, text = "Takes 25% more damage." }
S.essence_of_red = { name = "Essence of the Red", flag = true, text = "+2 mana each turn." }
S.burning_adrenaline = { name = "Burning Adrenaline", debuff = true, duration = true,
  text = "Your Attacks deal 50% more. When it ends, you lose 15 HP." }
S.shadowflame_fury = { name = "Shadowflame Fury", duration = true,
  text = "When this runs out: Nefarian gains Strength 10." }
S.veil_of_shadow = { name = "Veil of Shadow", debuff = true, duration = true, text = "Heals and Regen are halved." }
-- Class Call : un état par classe, 2 tours (décisions du 13/11/2026)
S.corrupted_healing = { name = "Corrupted Healing", debuff = true, duration = true,
  text = "Each heal also applies DoT 4 to you." }
S.berserker_stance = { name = "Berserker Stance", debuff = true, duration = true,
  text = "You are Sundered. Your Attacks deal 1 more." }
S.wild_polymorph = { name = "Wild Polymorph", debuff = true, duration = true,
  text = "Your first Cast card each turn costs 1 more." }
S.called_out = { name = "Called Out", debuff = true, duration = true,
  text = "Lose all Parry and Stealth. You can't gain them." }
S.broken_bow = { name = "Broken Bow", debuff = true, duration = true,
  text = "Your Attack cards deal " .. BR.BROKEN_BOW .. " less. Your pet is unaffected." }

-- Class Call de Nefarian : état et réplique (cris du raid) par classe ; une classe à venir reçoit
-- Demoralized (repli).
BR.CLASS_CALL = {
  priest = { status = "corrupted_healing",
    say = "Priests! If you're going to keep healing like that, we might as well make it a little more interesting!" },
  warrior = { status = "berserker_stance", say = "Warriors, I know you can hit harder than that! Let's see it!" },
  mage = { status = "wild_polymorph", turns = 1, say = "Mages too? You should be more careful when you play with magic..." },
  rogue = { status = "called_out", turns = 1, say = "Rogues? Stop hiding and face me!" },
  hunter = { status = "broken_bow", turns = 1, say = "Hunters and your annoying pea-shooters!" },
}
BR.CLASS_CALL_DEFAULT = { status = "demoralized", say = "Let's see how you fare without your tricks!" }
function BR.classCall(class) return BR.CLASS_CALL[class] or BR.CLASS_CALL_DEFAULT end

L.zoneKeyword("blackrock", "phase", { name = "Phase",
  text = "At each HP mark: new phase, new intent at once." })

---------------------------------------------------------------------------
-- Aides
---------------------------------------------------------------------------

local function stat(c, key, n) Combat.zstat(c, key, n) end

local function drakonidAlive(c)
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if not o.dead and ns.Enemies[o.id].drakonid then return true end
  end
  return false
end
BR.drakonidAlive = drakonidAlive

-- Plafond par coup en vigueur (Invincible) : def.maxHit, remplacé par celui de la phase en cours.
function BR.maxHit(e)
  local def = ns.Enemies[e.id]
  local cap = def.maxHit
  local ph = e.mem.phase and def.phases and def.phases[e.mem.phase]
  if ph and ph.maxHit ~= nil then cap = ph.maxHit end
  return cap or nil
end

-- Shadow of the Throne en vigueur sur e (Nefarius en phase 1, un Drakonid en vie).
function BR.throne(c, e)
  return ns.Enemies[e.id].throne and (e.mem.phase or 0) == 0 and drakonidAlive(c)
end

-- Ouverture de phase en attente sur e (move), nil sinon.
function BR.opening(e)
  local us = e.zs and e.zs.blackrock
  return us and us.opening or nil
end

---------------------------------------------------------------------------
-- Actions, conditions (ennemis, rencontres)
---------------------------------------------------------------------------

-- { "class_call", tours } : l'état de la classe du joueur, et la réplique.
Combat.ENEMY_ACTIONS.class_call = function(c, e, a)
  local cc = BR.classCall(c.class)
  Combat.log(c, { t = "say", unit = e.uid, text = cc.say })
  Combat.applyStatus(c, c.player, cc.status, cc.turns or a[2] or BR.CALL_TURNS)
  stat(c, "classCalls")
end

-- { "call_drakonid" } : un Drakonid de la couleur absente (rouge d'abord), sinon en alternance.
Combat.ENEMY_ACTIONS.call_drakonid = function(c, e)
  local red, blue = false, false
  for i = 1, #c.enemies do
    local o = c.enemies[i]
    if not o.dead and o.id == "red_drakonid" then red = true end
    if not o.dead and o.id == "blue_drakonid" then blue = true end
  end
  local id
  if not red then id = "red_drakonid" elseif not blue then id = "blue_drakonid"
  else id = ((e.mem.calls or 0) % 2 == 0) and "red_drakonid" or "blue_drakonid" end
  e.mem.calls = (e.mem.calls or 0) + 1
  Combat.spawn(c, id, e)
  stat(c, "drakonidsCalled")
end

-- { "raise_bones" } : un Bone Construct par Drakonid tué en phase 1 (mem.fallen), BONES_MAX au plus ; ils
-- agissent dès cette phase ennemie (embuscade).
Combat.ENEMY_ACTIONS.raise_bones = function(c, e)
  local n = min(BR.BONES_MAX, e.mem.fallen or 0)
  for _ = 1, n do Combat.spawn(c, { "bone_construct", ambush = true }, e) end
  stat(c, "boneConstructs", n)
end

-- { "clear_status", état } : retire l'état du joueur (Essence of the Red prend fin).
Combat.ENEMY_ACTIONS.clear_status = function(c, e, a)
  local p = c.player
  if p.st[a[2]] then
    p.st[a[2]] = nil
    p.fresh[a[2]] = nil
    Combat.log(c, { t = "status", unit = "player", id = a[2], n = 0, total = 0 })
  end
end

-- Shadow Flame : pas de DoT avec Onyxia Scale Cloak (clin d'œil au raid).
Combat.ENEMY_CONDITIONS.noOnyxiaCloak = function(c)
  for i = 1, #c.relics do if c.relics[i] == "onyxia_scale_cloak" then return false end end
  return true
end

---------------------------------------------------------------------------
-- Règle de la zone
---------------------------------------------------------------------------

ZR.define("blackrock", {
  hooks = {
    -- Essence of the Red (Vaelastrasz) : posée sur le joueur au début du combat
    onCombatStart = function(c, z)
      for i = 1, #c.enemies do
        if ns.Enemies[c.enemies[i].id].essence then
          Combat.applyStatus(c, c.player, "essence_of_red", 1)
          break
        end
      end
    end,
    maxMana = function(c, z, v)
      if (c.player.st.essence_of_red or 0) > 0 then return v + BR.ESSENCE_MANA end
      return v
    end,

    -- Invincible (plafond par coup, pas le DoT), Shadow of the Throne (moitié), Cracked Plating (+25 %)
    enemyDamageTaken = function(c, z, v, e, src)
      local cap = BR.maxHit(e)
      if cap and src.kind ~= "dot" and v > cap then
        stat(c, "invincibleStopped", v - cap)
        v = cap
      end
      if BR.throne(c, e) and v > 0 then
        local h = floor(v / 2)
        stat(c, "throneStopped", v - h)
        v = h
      end
      if (e.st.cracked or 0) > 0 then v = floor(v * 1.25) end
      return v
    end,

    -- Fire Shield : chaque coup d'une carte Attack (incantation résolue comprise) ou d'une Trap sur
    -- l'ennemi fait perdre X au joueur, Absorb d'abord ; ni le familier ni le DoT ne déclenchent rien.
    onEnemyDamaged = function(c, z, e, loss, absorbed, src)
      local us = e.zs and e.zs.blackrock
      if us and us.entered then -- le coup qui fait entrer dans la phase ne déclenche pas le bouclier qu'elle pose
        us.entered = nil
        return
      end
      local fs = e.st.fire_shield or 0
      if fs <= 0 or c.result then return end
      local k, d = src.kind, src.ctx and src.ctx.def
      local hit = k == "trap" or ((k == "card" or k == "cast") and d ~= nil and (d.type == "attack" or d.trap))
      if not hit then return end
      stat(c, "fireShieldHits")
      ZR.float(c, "player", "Fire Shield " .. fs, "attackText")
      Combat.dealDamage(c, nil, c.player, fs)
    end,

    -- Ouvertures de phase : badge et statistiques (subies, perdues par Stunned, interrompues)
    onEnemyPhase = function(c, z, e, k, ph)
      stat(c, "phases")
      local us = ZR.unitState(e, "blackrock")
      us.opening = ph.open
      us.entered = true -- lu (et effacé) par onEnemyDamaged du même coup
      if ph.open and c.step == "play" then stat(c, "openingsNow") elseif ph.open then stat(c, "openingsLater") end
    end,
    afterEnemyMove = function(c, z, e, move)
      local us = e.zs and e.zs.blackrock
      if us and us.opening and us.opening == move then
        us.opening = nil
        if e.interrupted then stat(c, "openingsInterrupted") else stat(c, "openingsSuffered") end
      end
    end,
    onEnemyStunned = function(c, z, e)
      local us = e.zs and e.zs.blackrock
      if us and us.opening and e.intent == us.opening then
        us.opening = nil
        stat(c, "openingsLost")
      end
    end,

    -- Fin du round : Burning Adrenaline qui prend fin (15 PV), Shadowflame Fury qui prend fin (Strength 8)
    onRoundEnd = function(c, z)
      local p = c.player
      local ba = p.st.burning_adrenaline
      if ba and ba <= 1 and not p.fresh.burning_adrenaline then
        stat(c, "adrenalineBurns")
        Combat.loseHp(c, BR.ADRENALINE_LOSS, "burning_adrenaline")
        if c.result then return end
      end
      for i = 1, #c.enemies do
        local e = c.enemies[i]
        local sf = e.st.shadowflame_fury
        if not e.dead and sf and sf <= 1 and not e.fresh.shadowflame_fury then
          Combat.applyStatus(c, e, "force", BR.FURY_STRENGTH)
          ZR.float(c, e.uid, "Shadowflame Fury!", "attackText")
          stat(c, "furyReached")
        end
      end
    end,
    attackMult = function(c, z, v)
      if (c.player.st.burning_adrenaline or 0) > 0 then return v + 0.5 end
      return v
    end,

    -- Veil of Shadow : soins et Regen du joueur réduits de moitié
    heal = function(c, z, v)
      if (c.player.st.veil_of_shadow or 0) > 0 and v > 0 then return floor(v / 2) end
      return v
    end,

    -- Class Call
    onUnitHeal = function(c, z, unit, got) -- Corrupted Healing (Priest)
      if unit == c.player and (unit.st.corrupted_healing or 0) > 0 and got > 0 then
        Combat.applyStatus(c, unit, "pain", BR.CORRUPTED_DOT)
      end
    end,
    damage = function(c, z, v, dst, cardDef) -- Berserker Stance (Warrior), Broken Bow (Hunter)
      if cardDef and cardDef.type == "attack" then
        local st = c.player.st
        if (st.berserker_stance or 0) > 0 then v = v + BR.BERSERKER_BONUS end
        if (st.broken_bow or 0) > 0 then v = v - BR.BROKEN_BOW end
      end
      return v
    end,
    enemyDamage = function(c, z, v, src, dst) -- Berserker Stance : Sundered (sans cumul avec Sundered)
      if dst == c.player and (dst.st.berserker_stance or 0) > 0 and (dst.st.armor_broken or 0) <= 0 then
        return floor(v * 1.25)
      end
      return v
    end,
    cost = function(c, z, v, d) -- Wild Polymorph (Mage) : la première carte Cast du tour coûte 1 de plus
      if d.cast and (c.player.st.wild_polymorph or 0) > 0 and z.castRound ~= c.round then return v + 1 end
      return v
    end,
    onCardCommitted = function(c, z, inst, d)
      if d.cast then z.castRound = c.round end
    end,
    applySelf = function(c, z, n, id) -- Called Out (Rogue) : ni Parry ni Stealth
      if (id == "stealth" or id == "parry") and (c.player.st.called_out or 0) > 0 then return 0 end
      return n
    end,
    onStatusApplied = function(c, z, unit, id)
      if id == "called_out" and unit == c.player then
        local had = (unit.st.parry or 0) + (unit.st.stealth or 0)
        unit.st.parry, unit.st.stealth = nil, nil
        if c.class == "rogue" and c.cls then c.cls.hidden = false end
        if had > 0 then ZR.float(c, "player", "Called Out", "attackText") end
      end
    end,

    onCombatEnd = function(c, z, result)
      if c.kind == "boss" and result == "won" then stat(c, "nefarianSlain") end
    end,
  },

  run = {
    -- Première victoire contre Nefarian avec la classe : titre « Dragonslayer » (drapeau de compte) ;
    -- première victoire du compte : Rallying Cry of the Dragonslayer pour l'expédition suivante.
    onCombatWon = function(exp, kind)
      if kind ~= "boss" then return end
      X.setFlag(exp, "dragonslayer:" .. tostring(exp.class))
      if not X.hasFlag(exp, "rallying_cry") then X.setFlag(exp, "rallying_cry") end
    end,
  },

  -- Rallying Cry of the Dragonslayer : la première expédition qui suit la victoire (toute classe, toute
  -- zone) commence avec +6 PV max ; drapeau rallying_cry_used posé (reporté en fin d'expédition).
  newExpedition = function(exp)
    if X.hasFlag(exp, "rallying_cry") and not X.hasFlag(exp, "rallying_cry_used") then
      exp.maxHp = exp.maxHp + BR.RALLY_HP
      exp.hp = exp.hp + BR.RALLY_HP
      X.setFlag(exp, "rallying_cry_used")
    end
  end,
})

-- Titre d'une classe pour l'accueil et l'écran Progress : « Dragonslayer » (Nefarian vaincu avec la
-- classe), sinon le titre du niveau (Meta.title : « Veteran » au niveau 7), sinon nil. meta = compte (Meta).
function BR.title(meta, class)
  if not meta then return nil end
  if ns.Meta.hasFlag(meta, "dragonslayer:" .. tostring(class)) then return "Dragonslayer" end
  return ns.Meta.title(meta, class)
end
