-- Arbre de talents du Priest (docs/talents.md, § 8 ; contrat : docs/talents.md, « Contrat du socle des talents »),
-- sur le modèle de Data/Talents/warrior.lua. 14 nœuds, 24 points ; 10 nœuds de mécanique (Atonement, Insanity,
-- Regen, Absorb, Cast), 4 génériques (ns.TalentCommon). Nombres réglables dans PT (lus à chaque usage :
-- tune=PriestTalents.CLE=n) ; les textes les disent (vérifié par Sim/tests_talents_priest.lua).
local _, ns = ...

local Combat = ns.Combat
local TC = ns.TalentCommon
local max = math.max

local PT = {
  hp = 2,              -- Toughness : PV max par rang (36 PV de classe)
  borrowed = 2,        -- Borrowed Time : Atonement au début de chaque combat, par rang (avec Sacred Candle)
  spike = 2,           -- Mind Spike : Insanity au début de chaque combat, par rang
  twin = 2,            -- Twin Disciplines : soin d'Atonement en plus, par rang (Combat.ATONEMENT_HEAL = 2)
  weaving = 1,         -- Shadow Weaving : Insanity à la deuxième carte Shadow de chaque tour
  inspiration = 4,     -- Inspiration : Regen au début de chaque combat
  torrent = 1,         -- Void Torrent : Insanity comptée en plus par les Surge, par rang (comme Anathema)
  barrier = 2,         -- Power Word: Barrier : Absorb en plus par carte qui en donne, par rang
  discAbsorb = 2,      -- Specialization Discipline : Absorb à chaque soin d'Atonement
  shadowHit = 5,       -- Specialization Shadow : dégâts en plus par coup des cartes Shadow
  shadowDot = 5,       --   … et DoT en plus posé par elles
  holyHit = 8,         -- Specialization Holy : dégâts en plus par coup des cartes Holy
  guidance = { 3, 5 }, -- Spiritual Guidance : Absorb quand une carte Cast se résout, par rang
  guardAtone = 3,      -- Guardian Spirit : Atonement donnée en évitant la mort
  guardRegen = 6,      --   rang 2 : Regen donnée
}
ns.PriestTalents = PT

local function atoned(c) return (c.player.st.atonement or 0) > 0 end
-- « +1 » / « +2 » selon le rang (textes).
local function per(n, r) return n * r end

local nodes = {
  -- Rangée 1 (ouverte d'emblée) ----------------------------------------------------------------------------------
  TC.toughness({ row = 1, ranks = 3, hp = PT.hp }),
  { id = "twin_disciplines", row = 1, ranks = 2, name = "Twin Disciplines", icon = "ability_priest_atonement",
    text = { ("Atonement heals %d instead of %d."):format(Combat.ATONEMENT_HEAL + PT.twin, Combat.ATONEMENT_HEAL),
      ("Atonement heals %d instead of %d."):format(Combat.ATONEMENT_HEAL + 2 * PT.twin, Combat.ATONEMENT_HEAL) },
    const = { ATONEMENT_HEAL = function(v, src) return v + PT.twin * src.rank end } },
  -- (s'ajoute à Sacred Candle : posé au début du combat, pendant le tour du joueur, il ne décompte pas ce tour)
  { id = "borrowed_time", row = 1, ranks = 2, name = "Borrowed Time", icon = "spell_holy_aspiration",
    text = { ("Start of combat: gain Atonement %d."):format(per(PT.borrowed, 1)),
      ("Start of combat: gain Atonement %d."):format(per(PT.borrowed, 2)) },
    hooks = {
      onCombatStart = function(c, src)
        if not c.result then Combat.applyStatus(c, c.player, "atonement", PT.borrowed * src.rank) end
      end,
    } },
  -- Rangée 2 (5 points) -----------------------------------------------------------------------------------------
  { id = "mind_spike", row = 2, ranks = 2, name = "Mind Spike", icon = "spell_shadow_painspike",
    text = { ("Start of combat: +%d Insanity."):format(per(PT.spike, 1)),
      ("Start of combat: +%d Insanity."):format(per(PT.spike, 2)) },
    hooks = {
      onCombatStart = function(c, src)
        if not c.result then Combat.gainRes(c, PT.spike * src.rank, "talent") end
      end,
    } },
  -- (compteur du tour c.turn.bySchool, compté au moment où la carte est engagée)
  { id = "shadow_weaving", row = 2, ranks = 1, name = "Shadow Weaving", icon = "spell_shadow_gathershadows",
    text = { ("The second Shadow card each turn: +%d Insanity."):format(PT.weaving) },
    hooks = {
      onCardCommitted = function(c, src, inst, d)
        if d and d.school == "shadow" and (c.turn.bySchool.shadow or 0) == 2 and not c.result then
          Combat.gainRes(c, PT.weaving, "talent")
        end
      end,
    } },
  -- (posée au début du combat : le premier tic part au début du premier tour ; Benediction s'y ajoute)
  { id = "inspiration", row = 2, ranks = 1, name = "Inspiration", icon = "spell_holy_lesserheal",
    text = { ("Start of combat: gain Regen %d."):format(PT.inspiration) },
    hooks = {
      onCombatStart = function(c, src)
        if not c.result then Combat.applyStatus(c, c.player, "regen", PT.inspiration) end
      end,
    } },
  TC.provisions({ row = 2 }),

  -- Rangée 3 (10 points) ----------------------------------------------------------------------------------------
  { id = "specialization", row = 3, ranks = 1, name = "Specialization", icon = "classicon_priest",
    choices = {
      -- après la carte (onCardPlayed passe après le soin d'Atonement) ; Power Word: Barrier ne s'y ajoute pas
      { id = "discipline", name = "Discipline", icon = "spell_holy_powerwordshield",
        text = ("Each Atonement heal also gives %d Absorb."):format(PT.discAbsorb),
        hooks = {
          onCardPlayed = function(c, src, inst, ctx)
            if ctx and ctx.dealt and not ctx.endOfTurn and atoned(c) and not c.result then
              ctx.barrierTalent = true
              Combat.gainBlock(c, c.player, PT.discAbsorb)
            end
          end,
        } },
      { id = "shadow", name = "Shadow", icon = "spell_shadow_shadowwordpain",
        text = ("Shadow cards deal %d more per hit and apply %d more DoT."):format(PT.shadowHit, PT.shadowDot),
        hooks = {
          damage = function(c, src, v, dst, d)
            if d and d.school == "shadow" then return v + PT.shadowHit end
            return v
          end,
          apply = function(c, src, n, id, target, d)
            if id == "pain" and d and d.school == "shadow" then return n + PT.shadowDot end
            return n
          end,
        } },
      { id = "holy", name = "Holy", icon = "spell_holy_holybolt",
        text = ("Holy cards deal %d more per hit."):format(PT.holyHit),
        hooks = {
          damage = function(c, src, v, dst, d)
            if d and d.school == "holy" then return v + PT.holyHit end
            return v
          end,
        } },
    } },
  { id = "void_torrent", row = 3, ranks = 2, name = "Void Torrent", icon = "spell_priest_void_blast",
    text = { ("Surge cards count %d more Insanity."):format(per(PT.torrent, 1)),
      ("Surge cards count %d more Insanity."):format(per(PT.torrent, 2)) },
    hooks = { surge = function(c, src, v) return v + PT.torrent * src.rank end } },
  -- une fois par carte jouée (c.cardCtx : la carte en cours de résolution), comme Protection du Warrior
  { id = "power_word_barrier", row = 3, ranks = 2, name = "Power Word: Barrier", icon = "spell_holy_powerwordbarrier",
    text = { ("Cards that give Absorb give %d more."):format(per(PT.barrier, 1)),
      ("Cards that give Absorb give %d more."):format(per(PT.barrier, 2)) },
    hooks = {
      block = function(c, src, v)
        local ctx = c.cardCtx
        if v > 0 and ctx and not ctx.barrierTalent then
          ctx.barrierTalent = true
          return v + PT.barrier * src.rank
        end
        return v
      end,
    } },
  TC.fieldMedic({ row = 3 }),

  -- Rangée 4 (16 points) ----------------------------------------------------------------------------------------
  { id = "spiritual_guidance", row = 4, ranks = 2, name = "Spiritual Guidance", icon = "spell_holy_searinglight",
    text = { ("When a Cast card resolves: gain %d Absorb."):format(PT.guidance[1]),
      ("When a Cast card resolves: gain %d Absorb."):format(PT.guidance[2]) },
    hooks = {
      onCastResolved = function(c, src)
        if not c.result then Combat.gainBlock(c, c.player, PT.guidance[src.rank]) end
      end,
    } },
  TC.veteransArsenal({ row = 4 }),
  -- Une fois par expédition (exp.talentState.guardian, repris du combat par l'expédition).
  { id = "guardian_spirit", row = 4, ranks = 2, name = "Guardian Spirit", icon = "ability_priest_spiritoftheredeemer",
    text = { ("Once per expedition, a hit that would kill you leaves you at 1 HP with Atonement %d."):format(PT.guardAtone),
      ("Once per expedition, a hit that would kill you leaves you at 1 HP with Atonement %d and Regen %d.")
        :format(PT.guardAtone, PT.guardRegen) },
    hooks = {
      preventDeath = function(c, src)
        local st = c.tstate
        if not st or st.guardian then return false end
        st.guardian = true
        c.player.hp = max(c.player.hp, 1) -- (journal : « saved », by = "guardian_spirit", posé par Combat.kill)
        Combat.applyStatus(c, c.player, "atonement", PT.guardAtone)
        if src.rank >= 2 then Combat.applyStatus(c, c.player, "regen", PT.guardRegen) end
        return true
      end,
    } },
}

ns.Talent.define("priest", {
  rows = { 0, 5, 10, 16 },
  nodes = nodes,
  -- Ordre de dépense du bot de simulation (tree=, un id par point ; docs/talents.md, § 8) et voie choisie.
  bot = {
    order = {
      "toughness", "toughness", "toughness", "twin_disciplines", "twin_disciplines", "borrowed_time", "borrowed_time",
      "mind_spike", "mind_spike", "shadow_weaving", "inspiration", "provisions",
      "specialization", "power_word_barrier", "power_word_barrier", "void_torrent", "void_torrent", "field_medic",
      "spiritual_guidance", "spiritual_guidance", "veterans_arsenal", "veterans_arsenal", "guardian_spirit",
      "guardian_spirit",
    },
    spec = "discipline",
    -- Pas d'accord des épiques (bot.epic) ni de valeurs de bot (bot.value, bot.won) : l'Absorb, les soins,
    -- l'Atonement, la Regen et l'Insanity des nœuds se voient dans l'évaluation commune (feuilles jouées
    -- jusqu'au tour ennemi). Mesuré le 19/11/2026 (docs/equilibrage.md, « Talents du Priest ») : la valeur
    -- d'Atonement relevée avec Twin Disciplines et Discipline (−2 points aux paliers 20 et 60) et
    -- { voidform = -1, reflective_shield = 1 } au palier 100 (79,0 → 76,7 %) n'aident pas ; Veteran's Arsenal 2 vaut
    -- +5 points dans l'arbre plein (77,8 % sans).
  },
})
