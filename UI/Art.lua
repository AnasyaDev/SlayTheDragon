-- Table d'art : tout le visuel lié au contenu vit ici, jamais dans Data/.
-- Chaque icône est décrite par { spell = idSort, icon = "chemin" } : l'interface essaie
-- d'abord l'icône du sort (C_Spell.GetSpellTexture), puis le chemin, puis le point
-- d'interrogation. Les identifiants n'ont PAS pu être vérifiés par le MCP « wow »
-- (index des fichiers et des créatures non synchronisés) : `/slay art` liste en jeu
-- ce qui manque (voir docs/interface.md).
local _, ns = ...

local Art = {}
ns.Art = Art

local I = "Interface\\Icons\\"
Art.QUESTION = I .. "INV_Misc_QuestionMark"

-- Cartes ---------------------------------------------------------------------
Art.cards = {
  smite                = { spell = 585,    icon = I .. "Spell_Holy_HolySmite" },
  inner_fire           = { spell = 588,    icon = I .. "Spell_Holy_InnerFire" },
  pw_shield            = { spell = 17,     icon = I .. "Spell_Holy_PowerWordShield" },
  sw_pain              = { spell = 589,    icon = I .. "Spell_Shadow_ShadowWordPain" },
  radiance             = { spell = 194509, icon = I .. "Spell_Priest_Power-Word" },
  penance              = { spell = 47540,  icon = I .. "Spell_Holy_Penance" },
  pain_suppression     = { spell = 33206,  icon = I .. "Spell_Holy_PainSupression" },
  mind_flay            = { spell = 15407,  icon = I .. "Spell_Shadow_SiphonMana" },
  mind_blast           = { spell = 8092,   icon = I .. "Spell_Shadow_UnholyFrenzy" },
  devouring_plague     = { spell = 2944,   icon = I .. "Spell_Shadow_BlackPlague" },
  shadowform           = { spell = 15473,  icon = I .. "Spell_Shadow_Shadowform" },
  silence              = { spell = 15487,  icon = I .. "Spell_Shadow_ImpPhaseShift" },
  holy_fire            = { spell = 14914,  icon = I .. "Spell_Holy_SearingLight" },
  holy_nova            = { spell = 15237,  icon = I .. "Spell_Holy_HolyNova" },
  chastise             = { spell = 88625,  icon = I .. "Spell_Holy_Chastise" },
  greater_heal         = { spell = 2060,   icon = I .. "Spell_Holy_GreaterHeal" },
  spirit_of_redemption = { spell = 20711,  icon = I .. "INV_Enchant_EssenceEternalLarge" },
}

-- Repli par école quand une carte (ajoutée par la piste A) n'a pas encore d'entrée.
Art.schools = {
  holy   = { spell = 585, icon = I .. "Spell_Holy_HolyBolt" },
  shadow = { spell = 686, icon = I .. "Spell_Shadow_ShadowBolt" },
}

-- Couleurs de rareté (codes couleur de WoW).
Art.rarity = {
  basic    = { 0.62, 0.62, 0.62 },
  common   = { 1.00, 1.00, 1.00 },
  uncommon = { 0.12, 1.00, 0.00 },
  rare     = { 0.00, 0.44, 0.87 },
  epic     = { 0.64, 0.21, 0.93 },
}

Art.typeName = { attack = "Attaque", skill = "Technique", power = "Pouvoir" }
Art.schoolName = { holy = "Sacré", shadow = "Ombre" }

-- Ennemis --------------------------------------------------------------------
-- creature = identifiant de créature (Model:SetCreature) ; display = identifiant
-- d'affichage (Model:SetDisplayInfo), essayé si le premier ne donne aucun modèle.
-- scale/facing : réglages de cadrage, à ajuster après essai en jeu.
Art.enemies = {
  gnoll           = { creature = 117 },              -- Gnoll Rivepatte
  mystic          = { creature = 453 },              -- Mystique Rivepatte
  murloc          = { creature = 126 },              -- Murloc côtier (Coastrunner)
  bandit          = { creature = 116 },              -- Bandit défias
  sorcerer        = { creature = 619 },              -- Sorcier/Conjurateur défias
  harvest_golem   = { creature = 36 },               -- Golem moissonneur
  rhahkzor        = { creature = 644 },              -- Rhahk'Zor
  defias_henchman = { creature = 594 },              -- Sbire défias
  vancleef        = { creature = 639, display = 2029 }, -- Edwin VanCleef
}
Art.enemyIcon = I .. "INV_Misc_QuestionMark"

-- États ----------------------------------------------------------------------
Art.statuses = {
  armor_broken = { spell = 7386,  icon = I .. "Ability_Warrior_Sunder" },
  demoralized  = { spell = 1160,  icon = I .. "Ability_Warrior_WarCry" },
  atonement    = { spell = 81749, icon = I .. "Ability_Priest_Atonement" },
  pain         = { spell = 589,   icon = I .. "Spell_Shadow_ShadowWordPain" },
  regen        = { spell = 139,   icon = I .. "Spell_Holy_Renew" },
  stunned      = { spell = 853,   icon = I .. "Spell_Holy_SealOfMight" },
  halved       = { spell = 33206, icon = I .. "Spell_Holy_PainSupression" },
  force        = { spell = 6673,  icon = I .. "Ability_Warrior_BattleShout" },
}

-- Intentions -----------------------------------------------------------------
Art.intents = {
  attack = { spell = 6603,  icon = I .. "Ability_MeleeDamage" },
  defend = { spell = 2565,  icon = I .. "INV_Shield_06" },
  cast   = { spell = 133,   icon = I .. "Spell_Fire_FlameBolt" },
  watch  = { spell = 1766,  icon = I .. "Ability_Kick" },
  debuff = { spell = 702,   icon = I .. "Spell_Shadow_CurseOfMannoroth" },
  buff   = { spell = 6673,  icon = I .. "Ability_Warrior_BattleShout" },
  heal   = { spell = 2050,  icon = I .. "Spell_Holy_LesserHeal" },
  summon = { spell = 688,   icon = I .. "Spell_Shadow_SummonImp" },
  stunned = { spell = 853,  icon = I .. "Spell_Holy_SealOfMight" },
  interrupted = { spell = 1766, icon = I .. "Ability_Kick" },
}
Art.intentName = {
  attack = "Attaque", defend = "Défense", cast = "Incante", watch = "Guette",
  debuff = "Affaiblit", buff = "Renforce", heal = "Soigne", summon = "Invoque",
}

-- Interface ------------------------------------------------------------------
Art.ui = {
  minimap   = { spell = 585, icon = I .. "INV_Misc_Book_09" },
  mana      = { icon = I .. "INV_Elemental_Mote_Mana" },
  demence   = { spell = 589, icon = I .. "Spell_Shadow_Twilight" },
  draw      = { icon = I .. "INV_Misc_Book_11" },
  discard   = { icon = I .. "INV_Misc_Book_06" },
  exhaust   = { icon = I .. "Spell_Fire_Incinerate" },
  cooldown  = { icon = I .. "Spell_Nature_TimeStop" },
  gold      = { icon = I .. "INV_Misc_Coin_01" },
  map = {
    combat   = { icon = I .. "Ability_DualWield" },
    elite    = { icon = I .. "Ability_Warrior_Rampage" },
    boss     = { icon = I .. "INV_Misc_Head_Dragon_01" },
    campfire = { icon = I .. "Spell_Fire_Fire" },
    shop     = { icon = I .. "INV_Misc_Bag_10" },
    event    = { icon = I .. "INV_Misc_Note_02" },
    chest    = { icon = I .. "INV_Box_02" },
  },
}

-- Mots-clés (infobulles des cartes) ------------------------------------------
Art.keywords = {
  cast = { name = "Incantation", text = "Se paie maintenant, se résout au début de ton prochain tour. "
    .. "Une seule à la fois ; un ennemi qui Guette l'interrompt." },
  cooldown = { name = "Recharge", text = "Après usage, la carte quitte le cycle pendant N tours "
    .. "puis revient directement en main." },
  exhaust = { name = "Consumée", text = "La carte quitte le combat après usage." },
  retain = { name = "Conservée", text = "La carte reste en main à la fin du tour." },
  power = { name = "Pouvoir", text = "Reste actif tout le combat une fois joué." },
  absorb = { name = "Absorption", text = "Absorbe les dégâts. Tombe au début de ton tour." },
  demence = { name = "Démence", text = "Ressource de l'Ombre, gagnée par les cartes d'ombre ; "
    .. "certaines cartes la dépensent toute d'un coup." },
  interrupt = { name = "Interruption", text = "Annule le sort qu'un ennemi incante." },
}

-- Animations des modèles (identifiants AnimationData usuels ; à confirmer en jeu).
Art.anim = { stand = 0, death = 1, dead = 6, wound = 9, attack = 16, attack1h = 17,
  spell = 53, spellOmni = 54, ready = 25 }
