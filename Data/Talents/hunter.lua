-- Arbre de talents du Hunter (docs/talents.md, § 8 ; contrat : docs/talents.md, « Contrat du socle des talents »).
-- 14 nœuds, 24 points ; 10 nœuds de mécanique (familier, Frenzy, Traps), 4 génériques (ns.TalentCommon). Nombres
-- réglables dans HT (lus à chaque usage : tune=HunterTalents.CLE=n) ; les textes les disent (vérifié par
-- Sim/tests_talents_hunter.lua). Noms des nœuds : talents du Chasseur dans WoW, choisis pour ne pas répéter le nom
-- d'une carte de la classe (Spirit Bond, Lock and Load, Feign Death sont des cartes ; Ferocity, un mot de Lone Wolf).
local _, ns = ...

local Combat = ns.Combat
local TC = ns.TalentCommon
local max = math.max

local HT = {
  hp = 3,              -- Toughness : PV max par rang
  kindred = 1,         -- Kindred Spirits : Frenzy au début de chaque combat, par rang
  fury = 1,            -- Unleashed Fury : dégâts de plus par attaque du familier (Hunter.PET_BASE ; un rang :
                       --   deux rangs, +2, valaient +19,5 points seuls au palier 60 %)
  decayEvery = { 2, 3 }, -- Bestial Discipline : le Frenzy ne baisse qu'un round sur decayEvery[rang] (Hunter.DECAY_EVERY)
  handler = 1,         -- Animal Handler : plafond de Frenzy, par rang
  trapFrenzy = 1,      -- Trap Mastery : Frenzy à chaque Trap déclenchée
  bmAt = 5,            -- Specialization Beast Mastery : Frenzy qui fait attaquer le familier la première fois du
                       --   combat qu'il l'atteint
  mmBonus = 3,         -- Specialization Marksmanship : Careful Aim, dégâts de plus par coup des Attacks
  svDamage = 6,        -- Specialization Survival : dégâts d'une Trap déclenchée à l'attaquant
  mend = 1,            -- Natural Mending : soin à la première attaque du familier de chaque tour (un rang : deux
                       --   soins par tour valaient +21 points seuls au palier 60 %)
  thrill = 1,          -- Thrill of the Hunt : Frenzy quand un ennemi meurt, par rang
  throatAt = 4,        -- Go for the Throat : Frenzy au début du tour pour +1 mana (rang 2 : et une carte)
  deterHp = 1,         -- Deterrence : PV gardés (rang 1)
  deterHp2 = 10,       --   rang 2
}
ns.HunterTalents = HT

local function H() return ns.Hunter end
-- Frenzy du héros.
local function frenzy(c) return c.player.res or 0 end
-- Careful Aim sur ce coup (cible au-dessus de la moitié de ses PV), comme Trueshot Aura.
-- « every other round » / « every third round » (Bestial Discipline).
local function everyText(n)
  local word = ({ [2] = "other", [3] = "third", [4] = "fourth" })[n] or (n .. "th")
  return ("Frenzy drops only every %s round."):format(word)
end
local function careful(dst) return dst ~= nil and not dst.dead and dst.hp * 2 > dst.maxHp end

local nodes = {
  -- Rangée 1 (ouverte d'emblée) ----------------------------------------------------------------------------------
  TC.toughness({ row = 1, ranks = 3, hp = HT.hp }),
  { id = "kindred_spirits", row = 1, ranks = 2, name = "Kindred Spirits", icon = "ability_hunter_pet_wolf",
    text = { ("Start of combat: +%d Frenzy."):format(HT.kindred), ("Start of combat: +%d Frenzy."):format(2 * HT.kindred) },
    hooks = {
      onCombatStart = function(c, src)
        if not c.result then Combat.gainRes(c, HT.kindred * src.rank, "talent") end
      end,
    } },
  { id = "unleashed_fury", row = 1, ranks = 1, name = "Unleashed Fury", icon = "ability_hunter_ferociousinspiration",
    text = { ("Pet attacks deal %d more."):format(HT.fury) },
    const = { PET_BASE = function(v) return v + HT.fury end } },
  { id = "bestial_discipline", row = 1, ranks = 2, name = "Bestial Discipline", icon = "ability_hunter_fervor",
    text = { everyText(HT.decayEvery[1]), everyText(HT.decayEvery[2]) },
    const = { DECAY_EVERY = function(v, src) return max(v, HT.decayEvery[src.rank]) end } },

  -- Rangée 2 (5 points) -----------------------------------------------------------------------------------------
  { id = "thrill_of_the_hunt", row = 2, ranks = 2, name = "Thrill of the Hunt", icon = "ability_hunter_assassinate2",
    text = { ("When an enemy dies: +%d Frenzy."):format(HT.thrill), ("When an enemy dies: +%d Frenzy."):format(2 * HT.thrill) },
    hooks = {
      onEnemyDeath = function(c, src)
        if not c.result then Combat.gainRes(c, HT.thrill * src.rank, "talent") end
      end,
    } },
  { id = "trap_mastery", row = 2, ranks = 2, name = "Trap Mastery", icon = "spell_nature_earthbind",
    text = { ("When a Trap triggers: +%d Frenzy."):format(HT.trapFrenzy),
      ("When a Trap triggers: +%d Frenzy."):format(2 * HT.trapFrenzy) },
    hooks = {
      onTrapTriggered = function(c, src)
        if not c.result then Combat.gainRes(c, HT.trapFrenzy * src.rank, "talent") end
      end,
    } },
  TC.provisions({ row = 2 }),

  -- Rangée 3 (10 points) ----------------------------------------------------------------------------------------
  { id = "specialization", row = 3, ranks = 1, name = "Specialization", icon = "classicon_hunter",
    choices = {
      -- la première fois du combat que le Frenzy monte jusqu'à bmAt (d'en dessous), le familier attaque
      -- (c.cls.bmDone ; chaque fois : 70,7 % au palier 60 %, contre 61,8 et 60,3 % aux deux autres voies)
      { id = "beast_mastery", name = "Beast Mastery", icon = "ability_hunter_beastwithin",
        text = ("The first time each combat Frenzy reaches %d: the pet attacks."):format(HT.bmAt),
        hooks = {
          onResource = function(c, src, delta)
            if delta > 0 and not c.result and not c.cls.bmDone then
              local v = frenzy(c)
              if v >= HT.bmAt and v - delta < HT.bmAt then
                c.cls.bmDone = true
                H().petAttack(c, "talent")
              end
            end
          end,
        } },
      { id = "marksmanship", name = "Marksmanship", icon = "ability_hunter_focusedaim",
        text = ("Careful Aim: Attacks deal %d more per hit."):format(HT.mmBonus),
        hooks = {
          damage = function(c, src, v, dst, d)
            if d and d.type == "attack" and careful(dst) then return v + HT.mmBonus end
            return v
          end,
        } },
      { id = "survival", name = "Survival", icon = "ability_hunter_swiftstrike",
        text = ("Traps also deal %d to the attacker."):format(HT.svDamage),
        -- un coup de la carte Trap (Strength, Sundered, Absorb de la cible), après ses effets
        hooks = {
          onTrapTriggered = function(c, src, inst, e)
            if c.result or not e or e.dead then return end
            Combat.dealDamage(c, c.player, e, Combat.calcDamage(c, c.player, e, HT.svDamage, ns.Card.def(inst)))
          end,
        } },
    } },
  -- round du dernier soin dans l'état de classe (c.cls, copié par Combat.clone)
  { id = "natural_mending", row = 3, ranks = 1, name = "Natural Mending", icon = "spell_nature_healingwavegreater",
    text = { ("Pet attacks: heal %d, once per turn."):format(HT.mend) },
    hooks = {
      onPetAttack = function(c, src)
        if c.result or c.cls.mendRound == c.round then return end
        c.cls.mendRound = c.round
        Combat.heal(c, c.player, HT.mend)
      end,
    } },
  { id = "animal_handler", row = 3, ranks = 2, name = "Animal Handler", icon = "ability_hunter_pet_raptor",
    text = { ("Frenzy cap +%d."):format(HT.handler), ("Frenzy cap +%d."):format(2 * HT.handler) },
    hooks = { resCap = function(c, src, v) return v + HT.handler * src.rank end } },
  TC.fieldMedic({ row = 3 }),

  -- Rangée 4 (16 points) ----------------------------------------------------------------------------------------
  { id = "go_for_the_throat", row = 4, ranks = 2, name = "Go for the Throat", icon = "ability_hunter_carve",
    text = { ("Start of turn with %d Frenzy or more: +1 mana."):format(HT.throatAt),
      ("Start of turn with %d Frenzy or more: +1 mana and draw 1."):format(HT.throatAt) },
    hooks = {
      maxMana = function(c, src, v)
        if frenzy(c) >= HT.throatAt then return v + 1 end
        return v
      end,
      drawPerTurn = function(c, src, v)
        if src.rank >= 2 and frenzy(c) >= HT.throatAt then return v + 1 end
        return v
      end,
    },
    -- (bots : finir le tour avec throatAt Frenzy après la baisse vaut un mana au tour suivant, et une carte au rang 2)
    bot = { value = function(c, src)
      if frenzy(c) - 1 >= HT.throatAt then return 25 + (src.rank >= 2 and 15 or 0) end
      return 0
    end } },
  TC.veteransArsenal({ row = 4 }),
  -- Une fois par expédition (exp.talentState.deterrence) ; le tour ennemi sauté comme Feign Death (la carte) :
  -- coups restants annulés (beforeHit), ennemis suivants par le drapeau commun skipEnemyTurn.
  { id = "deterrence", row = 4, ranks = 2, name = "Deterrence", icon = "ability_hunter_pet_turtle",
    text = { ("Once per expedition, a hit that would kill you leaves you at %d HP and skips the enemy turn.")
        :format(HT.deterHp),
      ("Once per expedition, a hit that would kill you leaves you at %d HP and skips the enemy turn.")
        :format(HT.deterHp2) },
    hooks = {
      preventDeath = function(c, src)
        local st = c.tstate
        if not st or st.deterrence then return false end
        st.deterrence = true
        local p = c.player
        p.hp = math.min(p.maxHp, max(p.hp, src.rank >= 2 and HT.deterHp2 or HT.deterHp))
        p.flags.skipEnemyTurn = true
        return true
      end,
      beforeHit = function(c, src, dmg)
        if c.phase == "enemy" and c.player.flags.skipEnemyTurn then return 0 end
        return dmg
      end,
    } },
}

ns.Talent.define("hunter", {
  rows = { 0, 5, 10, 16 },
  nodes = nodes,
  -- Ordre de dépense du bot de simulation (tree=, un id par point ; docs/talents.md, § 8) et voie choisie.
  bot = {
    order = {
      "unleashed_fury", "kindred_spirits", "kindred_spirits", "bestial_discipline", "bestial_discipline",
      "trap_mastery", "trap_mastery", "thrill_of_the_hunt", "thrill_of_the_hunt", "provisions",
      "toughness", "toughness", "toughness", "specialization", "natural_mending",
      "animal_handler", "animal_handler", "field_medic", "go_for_the_throat", "go_for_the_throat",
      "veterans_arsenal", "veterans_arsenal", "deterrence", "deterrence",
    },
    spec = "beast_mastery",
    -- accord des épiques avec l'arbre (note du bot, Sim/expedition.lua) : Lone Wolf retire le familier, que
    -- presque tout l'arbre renforce ; épiques sans plafond, le bot la prenait en plus des autres (note positive)
    -- et l'arbre plein tombait à 43 % (Lone Wolf dans 80 % des expéditions : 30 % de victoires, 99 % sans).
    epic = { lone_wolf = -20 },
  },
})
