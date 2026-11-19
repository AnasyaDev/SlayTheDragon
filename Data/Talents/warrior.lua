-- Arbre de talents du Warrior (docs/talents.md, § 6 ; contrat : docs/talents.md, « Contrat du socle des talents »).
-- Arbre de référence pour les cinq autres classes. 13 nœuds, 24 points ; 9 nœuds de mécanique (la Rage), 4
-- génériques (ns.TalentCommon). Nombres réglables dans WT (lus à chaque usage : tune=WarriorTalents.CLE=n) ; les
-- textes les disent (vérifié par Sim/tests_talents.lua).
local _, ns = ...

local Combat = ns.Combat
local TC = ns.TalentCommon
local floor, min, max = math.floor, math.min, math.max

local WT = {
  hp = TC.toughnessHp("warrior"), -- Toughness : PV max par rang (règle commune, ns.TalentCommon)
  ready = 1,           -- Battle Ready : Rage au début de chaque combat, par rang
  windDiv = { 5, 4, 3 }, -- Second Wind : soin de 1 par windDiv[rang] Rage restante après un combat gagné
  wrath = 1,           -- Unbridled Wrath : plafond de Rage, par rang
  shieldDiv = { 5, 4 }, -- Anger Shield : 1 Absorb par shieldDiv[rang] Rage à la fin du tour
  sunder = 0.25,       -- Specialization Arms : Sundered +25 % de plus (× 1,5 au lieu de × 1,25)
  furyAt = 5,          -- Specialization Fury : Rage à partir de laquelle les Attacks frappent plus fort
  furyBonus = 1,       --   … de tant par coup
  protBonus = 2,       -- Specialization Protection : Absorb de plus par carte qui en donne
  carry = 2,           -- Tactical Mastery : Rage gardée d'un combat au suivant, par rang
  drink = 1,           -- Blood Drinker : soin à chaque dépense de Rage (rang 1 : Spend payé ; rang 2 : Surge aussi)
  rampageAt = 6,       -- Rampage : Rage au début du tour pour +1 mana (5, et deux rangs, avant le recalage)
  saveRage = 5,        -- Unyielding : Rage donnée en évitant la mort
  saveAbsorb = 15,     --   rang 2 : Absorb donnée
}
ns.WarriorTalents = WT

-- Rage restante du héros.
local function rage(c) return c.player.res or 0 end
-- « per Rage » / « per 2 Rage » (textes).
local function perRage(n) return n == 1 and "per Rage" or ("per %d Rage"):format(n) end
-- Soin de Second Wind pour cette Rage restante, au rang r.
local function windHeal(res, r) return floor(res / WT.windDiv[r]) end

local nodes = {
  -- Rangée 1 (ouverte d'emblée) ----------------------------------------------------------------------------------
  TC.toughness({ row = 1, ranks = 3, hp = WT.hp }),
  { id = "battle_ready", row = 1, ranks = 2, name = "Battle Ready", icon = "ability_warrior_battleshout",
    text = { ("Start of combat: +%d Rage."):format(WT.ready), ("Start of combat: +%d Rage."):format(2 * WT.ready) },
    hooks = {
      onCombatStart = function(c, src)
        if not c.result then Combat.gainRes(c, WT.ready * src.rank, "talent") end
      end,
    } },
  -- (soin hors combat, après que l'expédition a repris les PV du combat ; crochet healOut compris)
  { id = "second_wind", row = 1, ranks = 3, name = "Second Wind", icon = "ability_warrior_renewedvigor",
    text = { ("After a combat won: heal 1 %s you have."):format(perRage(WT.windDiv[1])),
      ("After a combat won: heal 1 %s you have."):format(perRage(WT.windDiv[2])),
      ("After a combat won: heal 1 %s you have."):format(perRage(WT.windDiv[3])) },
    run = {
      onCombatWon = function(exp, src, kind, fight, c)
        local n = c and windHeal(rage(c), src.rank) or 0
        if n > 0 then ns.Expedition.healOut(exp, n) end
      end,
    },
    bot = { won = function(c, src) return min(windHeal(rage(c), src.rank), c.player.maxHp - c.player.hp) end } },
  -- (rangée 2 avant le recalage du 19/11/2026 : seul, il ne vaut presque rien, il ouvre la rangée 2)
  { id = "unbridled_wrath", row = 1, ranks = 2, name = "Unbridled Wrath", icon = "ability_warrior_endlessrage",
    text = { ("Rage cap +%d."):format(WT.wrath), ("Rage cap +%d."):format(2 * WT.wrath) },
    hooks = { resCap = function(c, src, v) return v + WT.wrath * src.rank end } },

  -- Rangée 2 (5 points) -----------------------------------------------------------------------------------------
  { id = "anger_shield", row = 2, ranks = 2, name = "Anger Shield", icon = "ability_warrior_defensivestance",
    text = { ("End of turn: gain 1 Absorb %s."):format(perRage(WT.shieldDiv[1])),
      ("End of turn: gain 1 Absorb %s."):format(perRage(WT.shieldDiv[2])) },
    hooks = {
      onTurnEnd = function(c, src)
        local n = floor(rage(c) / WT.shieldDiv[src.rank])
        if n > 0 and not c.result then Combat.gainBlock(c, c.player, n) end
      end,
    } },
  TC.provisions({ row = 2 }),

  -- Rangée 3 (10 points) ----------------------------------------------------------------------------------------
  { id = "specialization", row = 3, ranks = 1, name = "Specialization", icon = "classicon_warrior",
    choices = {
      { id = "arms", name = "Arms", icon = "ability_warrior_sunder",
        text = ("Sundered enemies take %d%% more damage instead of %d%%."):format(
          floor((Combat.SUNDER_MULT - 1 + WT.sunder) * 100 + 0.5), floor((Combat.SUNDER_MULT - 1) * 100 + 0.5)),
        const = { SUNDER_MULT = function(v) return v + WT.sunder end } },
      { id = "fury", name = "Fury", icon = "ability_warrior_rampage",
        text = ("While you have %d Rage or more, Attacks deal %d more per hit."):format(WT.furyAt, WT.furyBonus),
        hooks = {
          damage = function(c, src, v, dst, d)
            if d and d.type == "attack" and rage(c) >= WT.furyAt then return v + WT.furyBonus end
            return v
          end,
        } },
      { id = "protection", name = "Protection", icon = "ability_warrior_shieldwall",
        text = ("Cards that give Absorb give %d more."):format(WT.protBonus),
        -- une fois par carte jouée (c.cardCtx : la carte en cours de résolution)
        hooks = {
          block = function(c, src, v)
            local ctx = c.cardCtx
            if v > 0 and ctx and not ctx.protTalent then
              ctx.protTalent = true
              return v + WT.protBonus
            end
            return v
          end,
        } },
    } },
  -- Rage gardée : posée en fin de combat gagné (exp.talentState.rage), rendue au début du combat suivant.
  { id = "tactical_mastery", row = 3, ranks = 2, name = "Tactical Mastery", icon = "ability_warrior_innerrage",
    text = { ("Up to %d Rage carries over to the next combat."):format(WT.carry),
      ("Up to %d Rage carries over to the next combat."):format(2 * WT.carry) },
    hooks = {
      onCombatStart = function(c, src)
        local r = c.tstate and c.tstate.rage
        if r then
          c.tstate.rage = nil
          if r > 0 and not c.result then Combat.gainRes(c, r, "talent") end
        end
      end,
    },
    run = {
      onCombatWon = function(exp, src, kind, fight, c)
        local r = c and min(rage(c), WT.carry * src.rank) or 0
        exp.talentState = exp.talentState or {}
        exp.talentState.rage = r > 0 and r or nil
      end,
    },
    bot = { won = function(c, src) return min(rage(c), WT.carry * src.rank) end } },
  { id = "blood_drinker", row = 3, ranks = 2, name = "Blood Drinker", icon = "ability_racial_bloodrage",
    text = { ("Each time you pay a Spend cost: heal %d."):format(WT.drink),
      ("Each time you spend Rage: heal %d."):format(WT.drink) },
    hooks = {
      onResource = function(c, src, delta, why)
        if delta < 0 and (why == "spend" or (why == "surge" and src.rank >= 2)) and not c.result then
          Combat.heal(c, c.player, WT.drink)
        end
      end,
    } },
  TC.fieldMedic({ row = 3 }),

  -- Rangée 4 (16 points) ----------------------------------------------------------------------------------------
  -- (deux rangs, à 5 Rage, et une carte au rang 2, avant le recalage du 19/11/2026)
  { id = "rampage", row = 4, ranks = 1, name = "Rampage", icon = "ability_warrior_unrelentingassault",
    text = { ("Start of turn with %d Rage or more: +1 mana."):format(WT.rampageAt) },
    hooks = {
      maxMana = function(c, src, v)
        if rage(c) >= WT.rampageAt then return v + 1 end
        return v
      end,
    },
    -- (bots : finir le tour à rampageAt Rage vaut un mana au tour suivant)
    bot = { value = function(c, src, W)
      if rage(c) >= WT.rampageAt then return 25 end
      return 0
    end } },
  TC.veteransArsenal({ row = 4 }),
  -- Une fois par expédition (exp.talentState.unyielding, repris du combat par l'expédition).
  { id = "unyielding", row = 4, ranks = 2, name = "Unyielding", icon = "ability_warrior_warcry",
    text = { ("Once per expedition, a hit that would kill you leaves you at 1 HP and gives %d Rage."):format(WT.saveRage),
      ("Once per expedition, a hit that would kill you leaves you at 1 HP with %d Absorb and %d Rage.")
        :format(WT.saveAbsorb, WT.saveRage) },
    hooks = {
      preventDeath = function(c, src)
        local st = c.tstate
        if not st or st.unyielding then return false end
        st.unyielding = true
        c.player.hp = max(c.player.hp, 1) -- (journal : « saved », by = "unyielding", posé par Combat.kill)
        Combat.gainRes(c, WT.saveRage, "talent")
        if src.rank >= 2 then Combat.gainBlock(c, c.player, WT.saveAbsorb) end
        return true
      end,
    } },
}

ns.Talent.define("warrior", {
  rows = { 0, 5, 10, 16 },
  nodes = nodes,
  -- Ordre de dépense du bot de simulation (tree=, un id par point ; docs/talents.md, § 6) et voie choisie.
  bot = {
    order = {
      "unbridled_wrath", "unbridled_wrath", "second_wind", "second_wind", "toughness",
      "toughness", "toughness", "anger_shield", "anger_shield", "provisions",
      "specialization", "blood_drinker", "blood_drinker", "tactical_mastery", "tactical_mastery",
      "field_medic", "battle_ready", "battle_ready", "second_wind", "rampage",
      "veterans_arsenal", "veterans_arsenal", "unyielding", "unyielding",
    },
    spec = "fury",
    -- accord des épiques avec l'arbre (note du bot, Sim/expedition.lua) : Thunderous Roar vide la Rage à 5 (que
    -- Unbridled Wrath, Anger Shield, Rampage et la Specialization Fury gardent) ; Death Wish interdit l'Absorb (Anger
    -- Shield) ; Avatar monte le plafond ; Titan's Grip et Shield Charge sont les plus fortes seules (docs/equilibrage.md,
    -- « Épiques : mesure une par une »). Sans ces écarts, le bot prenait Thunderous Roar au départ (Veteran's Arsenal)
    -- et l'arbre plein gagnait moins que l'arbre à 80 %.
    epic = { thunderous_roar = -4, death_wish = -2, avatar = 1, titans_grip = 2, shield_charge = 1 },
  },
})
