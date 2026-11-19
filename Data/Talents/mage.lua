-- Arbre de talents du Mage (docs/talents.md, § 8 ; contrat : docs/talents.md, « Contrat du socle des talents »).
-- 14 nœuds, 24 points ; 10 nœuds de mécanique (Charges, incantations, Instant, Frozen, Absorb), 4 génériques
-- (ns.TalentCommon). Nombres réglables dans MT (lus à chaque usage : tune=MageTalents.CLE=n) ; les textes les
-- disent (vérifié par Sim/tests_talents_mage.lua). Réglé au bot human le 19/11/2026 (docs/equilibrage.md,
-- « Talents du Mage ») : les nœuds forts (Charges au départ, Absorb, Instant) passent après les 10 premiers points.
local _, ns = ...

local Combat = ns.Combat
local TC = ns.TalentCommon
local min, max = math.min, math.max

local MT = {
  hp = TC.toughnessHp("mage"), -- Toughness : PV max par rang (règle commune, ns.TalentCommon)
  mind = 1,            -- Arcane Mind : plafond de Charges, par rang
  focus = 1,           -- Arcane Focus : Charges au début de chaque combat
  conc = 1,            -- Arcane Concentration : Charges gagnées après chaque Surge, par rang
  fireDot = 1,         -- Specialization Fire : DoT posé par chaque coup d'une Attack Fire
  frostChill = 1,      -- Specialization Frost : Demoralized posé sur le premier ennemi au début du combat
  arcaneAt = 4,        -- Specialization Arcane : Charges à partir desquelles les Attacks frappent plus fort
  arcaneBonus = 1,     --   … de tant par coup
  ward = 1,            -- Frost Warding : Absorb de plus par carte qui en donne
  chill = 1,           -- Winter's Chill : dégâts de plus par coup d'Attack sur un ennemi Frozen, par rang
  cloak = 1,           -- Prismatic Cloak : Absorb à chaque carte Cast résolue, par rang (un rang de 2 avant le recalage)
  instant = 1,         -- Firestarter : Instant au début de chaque combat
  potencyAt = 5,       -- Arcane Potency : Charges au début du tour pour +1 mana, rang 2 : et une carte (4 avant le recalage)
  saveHp = { 1, 3, 5 }, -- Cauterize : PV laissés en évitant la mort, par rang (deux rangs, 1 et 10 PV avec Ice
                       --   Block, avant le recalage du 19/11/2026 : +9 points dans l'arbre plein)
}
ns.MageTalents = MT

-- Charges du héros.
local function charges(c) return c.player.res or 0 end
local function plural(n, word) return n == 1 and word or word .. "s" end
-- Combat d'élite ou de boss (Arcane Focus, Firestarter ; recalage du 19/11/2026 : à chaque combat, Arcane Focus valait
-- +13 points dans l'arbre au palier 60 %).
local function bigFight(c) return c.kind == "elite" or c.kind == "boss" end
-- Textes des rangs 1 à ranks : f(rang) -> texte.
local function texts(ranks, f)
  local t = {}
  for r = 1, ranks do t[r] = f(r) end
  return t
end

local nodes = {
  -- Rangée 1 (ouverte d'emblée) ----------------------------------------------------------------------------------
  TC.toughness({ row = 1, ranks = 3, hp = MT.hp }),
  { id = "arcane_mind", row = 1, ranks = 3, name = "Arcane Mind", icon = "spell_arcane_arcane03",
    text = texts(3, function(r) return ("Charge cap +%d."):format(MT.mind * r) end),
    hooks = { resCap = function(c, src, v) return v + MT.mind * src.rank end } },

  -- (rangée 3 avant le recalage du 19/11/2026) une fois par carte jouée (c.cardCtx : la carte en cours de résolution), comme Protection du Warrior
  { id = "frost_warding", row = 1, ranks = 1, name = "Frost Warding", icon = "spell_frost_windwalkon",
    text = { ("Cards that give Absorb give %d more."):format(MT.ward) },
    hooks = {
      block = function(c, src, v)
        local ctx = c.cardCtx
        if v > 0 and ctx and not ctx.wardTalent then
          ctx.wardTalent = true
          return v + MT.ward
        end
        return v
      end,
    } },


  -- Rangée 2 (5 points) -----------------------------------------------------------------------------------------
  -- (après la remise à 0 du Surge, avant les effets qui suivent sur la carte)
  { id = "arcane_concentration", row = 2, ranks = 2, name = "Arcane Concentration", icon = "spell_arcane_starfire",
    text = texts(2, function(r) return ("After each Surge: +%d %s."):format(MT.conc * r, plural(MT.conc * r, "Charge")) end),
    hooks = {
      onSurge = function(c, src)
        if not c.result then Combat.gainRes(c, MT.conc * src.rank, "talent") end
      end,
    } },
  TC.provisions({ row = 2 }),
  -- Rangée 3 (10 points) ----------------------------------------------------------------------------------------
  { id = "specialization", row = 3, ranks = 1, name = "Specialization", icon = "classicon_mage",
    choices = {
      { id = "fire", name = "Fire", icon = "spell_fire_flamebolt",
        text = ("Fire Attack hits also apply DoT %d."):format(MT.fireDot),
        hooks = {
          onAttackHit = function(c, src, t, ctx)
            if ctx and ctx.def and ctx.def.school == "fire" and t and not t.dead and not c.result then
              Combat.applyStatus(c, t, "pain", MT.fireDot, "burn")
            end
          end,
        } },
      { id = "frost", name = "Frost", icon = "spell_frost_frostbolt02",
        text = ("Start of combat: apply Demoralized %d to the first enemy."):format(MT.frostChill),
        -- (le premier ennemi vivant, le plus à gauche ; à tous : 69,5 % au palier 60, 9 points de plus que Fire)
        hooks = {
          onCombatStart = function(c)
            if c.result then return end
            local e = Combat.aliveEnemies(c)[1]
            if e then Combat.applyStatus(c, e, "demoralized", MT.frostChill) end
          end,
        } },
      { id = "arcane", name = "Arcane", icon = "spell_arcane_blast",
        text = ("While you have %d Charges or more, Attacks deal %d more per hit."):format(MT.arcaneAt,
          MT.arcaneBonus),
        hooks = {
          damage = function(c, src, v, dst, d)
            if d and d.type == "attack" and charges(c) >= MT.arcaneAt then return v + MT.arcaneBonus end
            return v
          end,
        } },
    } },
  -- (deux rangs avant le recalage du 19/11/2026 : +7,6 points dans l'arbre plein)
  { id = "winters_chill", row = 3, ranks = 1, name = "Winter's Chill", icon = "spell_frost_chainsofice",
    text = texts(1, function(r) return ("Attack hits on Frozen enemies deal %d more."):format(MT.chill * r) end),
    hooks = {
      damage = function(c, src, v, dst, d)
        if d and d.type == "attack" and dst and dst.side == "enemy" and Combat.isFrozen(dst) then
          return v + MT.chill * src.rank
        end
        return v
      end,
    } },
  -- carte Cast résolue, incantée ou partie tout de suite (crochet afterCast du socle)
  { id = "prismatic_cloak", row = 3, ranks = 2, name = "Prismatic Cloak", icon = "spell_magearmor",
    text = texts(2, function(r) return ("When a Cast card resolves, gain %d Absorb."):format(MT.cloak * r) end),
    hooks = {
      afterCast = function(c, src)
        if not c.result then Combat.gainBlock(c, c.player, MT.cloak * src.rank) end
      end,
    },
    -- (bots : une incantation tenue donnera son Absorb à la résolution, au début du tour suivant)
    bot = { value = function(c, src, W)
      local p = c.player
      local n = (p.cast and 1 or 0) + (p.castMore and #p.castMore or 0)
      return n * MT.cloak * W.hp * 0.5
    end } },
  { id = "arcane_focus", row = 3, ranks = 1, name = "Arcane Focus", icon = "spell_arcane_arcane01",
    text = { ("Start of combat against elites and bosses: +%d %s."):format(MT.focus, plural(MT.focus, "Charge")) },
    hooks = {
      onCombatStart = function(c, src)
        if not c.result and bigFight(c) then Combat.gainRes(c, MT.focus, "talent") end
      end,
    } },
  TC.fieldMedic({ row = 3 }),

  -- Rangée 4 (16 points) ----------------------------------------------------------------------------------------
  { id = "firestarter", row = 4, ranks = 1, name = "Firestarter", icon = "spell_fire_burningspeed",
    text = { ("Start of combat against elites and bosses: gain Instant %d."):format(MT.instant) },
    hooks = {
      onCombatStart = function(c, src)
        if not c.result and bigFight(c) then Combat.applyStatus(c, c.player, "instant", MT.instant) end
      end,
    } },
  { id = "arcane_potency", row = 4, ranks = 2, name = "Arcane Potency", icon = "spell_arcane_arcanepotency",
    text = { ("Start of turn with %d Charges or more: +1 mana."):format(MT.potencyAt),
      ("Start of turn with %d Charges or more: +1 mana and draw 1."):format(MT.potencyAt) },
    hooks = {
      maxMana = function(c, src, v)
        if charges(c) >= MT.potencyAt then return v + 1 end
        return v
      end,
      drawPerTurn = function(c, src, v)
        if src.rank >= 2 and charges(c) >= MT.potencyAt then return v + 1 end
        return v
      end,
    },
    -- (bots : finir le tour à 4 Charges vaut un mana au tour suivant, et une carte au rang 2)
    bot = { value = function(c, src, W)
      if charges(c) >= MT.potencyAt then return 25 + (src.rank >= 2 and 15 or 0) end
      return 0
    end } },
  TC.veteransArsenal({ row = 4 }),
  -- Une fois par expédition (exp.talentState.cauterize, repris du combat par l'expédition). Après Ice Block (Power,
  -- une fois par combat) : les pouvoirs passent avant les talents.
  { id = "cauterize", row = 4, ranks = 3, name = "Cauterize", icon = "spell_fire_immolation",
    text = texts(3, function(r)
      return ("Once per expedition, a hit that would kill you leaves you at %d HP."):format(MT.saveHp[r])
    end),
    hooks = {
      preventDeath = function(c, src)
        local st = c.tstate
        if not st or st.cauterize then return false end
        st.cauterize = true
        local p = c.player
        p.hp = max(p.hp, min(p.maxHp, MT.saveHp[src.rank])) -- (journal : « saved », posé par Combat.kill)
        return true
      end,
    } },
}

ns.Talent.define("mage", {
  rows = { 0, 5, 10, 16 },
  nodes = nodes,
  -- Ordre de dépense du bot de simulation (tree=, un id par point ; docs/talents.md, § 8) et voie choisie.
  bot = {
    order = {
      "toughness", "toughness", "toughness", "frost_warding", "arcane_mind",
      "arcane_mind", "arcane_mind", "arcane_concentration", "arcane_concentration", "provisions",
      "specialization", "winters_chill", "prismatic_cloak", "prismatic_cloak", "field_medic",
      "arcane_focus", "firestarter", "arcane_potency", "arcane_potency", "cauterize",
      "veterans_arsenal", "veterans_arsenal", "cauterize", "cauterize",
    },
    spec = "arcane",
  },
})
