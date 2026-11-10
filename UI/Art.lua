-- Table d'art : tout le visuel lié au contenu vit ici, jamais dans Data/.
-- Chaque icône est décrite par { spell = idSort, icon = FileDataID ou chemin } : l'interface essaie
-- d'abord l'icône du sort (C_Spell.GetSpellTexture), puis l'icône, puis le point d'interrogation.
-- Les FileDataID d'icônes et de textures ci-dessous sont confirmés par le MCP « wow »
-- (wow_icon_search / wow_file_search, liste de fichiers du client 12.1.5). Les identifiants de
-- sorts, de créatures et d'animations ne sont PAS vérifiables hors jeu : `/slay art` liste en jeu
-- ce qui manque (voir docs/interface.md).
local _, ns = ...

local Art = {}
ns.Art = Art

Art.QUESTION = 134400 -- inv_misc_questionmark

---------------------------------------------------------------------------
-- Palette (couleurs des maquettes docs/maquette/*.dc.html)
---------------------------------------------------------------------------

local function hex(s)
  s = s:gsub("#", "")
  return { tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255 }
end
Art.hex = hex

Art.C = {
  frame = hex("#1c130d"), frameEdge = hex("#6b4a22"),
  band = hex("#2a1d14"), bandEdge = hex("#6b4a22"),
  gold = hex("#f0c75e"), goldDeep = hex("#c9a227"), cream = hex("#f3e6c8"), creamLight = hex("#fff3cf"),
  hpText = hex("#ff9d8a"), key = hex("#c58cf0"),
  board = hex("#3a2618"), boardEdge = hex("#6b4a22"),
  wood = hex("#6b4a22"), woodDark = hex("#4a3220"), woodLine = hex("#8a7350"),
  ink = hex("#2b1c10"), inkSoft = hex("#4a3220"),
  parchment = hex("#efe0bd"), parchmentLight = hex("#f6e9c9"), parchmentDim = hex("#b8ab8c"),
  edgeCommon = hex("#e8e2d0"), edgeUncommon = hex("#3fae4a"), edgeRare = hex("#3b82d6"),
  gem = hex("#2f6fc0"), gemEdge = hex("#cfe5ff"), gemBad = hex("#7a2a1e"), gemBadEdge = hex("#f0b3a6"),
  hp = hex("#b3402e"), ghost = hex("#ffe9a8"), barBg = hex("#2a1d14"), barEdge = hex("#1c130d"),
  absorb = hex("#7fb6e8"), absorbEdge = hex("#eaf4ff"), absorbText = hex("#10263b"),
  attack = hex("#e2634c"), attackText = hex("#ff9d8a"),
  watch = hex("#c58cf0"), watchText = hex("#dcb6ff"),
  defend = hex("#7fb6e8"), defendText = hex("#bcdcf7"),
  heal = hex("#7fd08a"), healText = hex("#a8e6b0"),
  red = hex("#7a2a1e"), redEdge = hex("#c98a6a"), green = hex("#1f6b2a"), numberInk = hex("#8a2a12"),
  shadow = hex("#3d2a12"),
  map = hex("#e8d5a6"), mapEdge = hex("#8a6a3a"), mapRoad = hex("#c9b27a"),
  nodeDone = hex("#7a2a1e"), nodeDoneEdge = hex("#4a160e"), nodeElite = hex("#5a2a6a"),
  nodeCombat = hex("#8a5f22"), nodeHalo = hex("#f0c75e"), nodeRing = hex("#b8860b"),
  nodeFuture = hex("#cdb783"), nodeFutureEdge = hex("#8a6a3a"),
  white = { 1, 1, 1 }, black = { 0, 0, 0 },
}

---------------------------------------------------------------------------
-- Textures de l'interface (FileDataID confirmés par wow_file_search)
---------------------------------------------------------------------------

Art.tex = {
  white = "Interface\\Buttons\\WHITE8X8",
  circle = 130924,      -- interface/characterframe/tempportraitalphamask (disque blanc à alpha)
  parchment = 516781,   -- interface/helpframe/tileable-parchment
  wood = 7149548,       -- interface/gamepad/woodtile
  check = 136814,       -- interface/raidframe/readycheck-ready
}

-- Décors : `texture` = illustration du jeu posée sur la bande du haut (recadrée par `crop` =
-- { gauche, droite, haut, bas } en fraction, teintée par `tint`) ; `paint` = décor de repli peint en
-- couches unies aux couleurs des maquettes, toujours dessiné dessous. Point d'extension : ajouter une
-- entrée ici (et `scene = "<clé>"` dans une rencontre) suffit ; `/slay decor` bascule illustration/peint.
Art.scenes = {
  road = { -- Marche de l'Ouest, route et combats
    texture = 7377860, -- glues/loadingscreens/expansion10/main/loadscreen_housing_elwynnforest
    crop = { 0, 1, 0.16, 0.86 }, tint = { 1, 0.93, 0.78 },
    paint = "fields",
  },
  farm = {
    texture = 7377860, crop = { 0, 1, 0.12, 0.82 }, tint = { 1, 0.95, 0.82 },
    paint = "farm",
  },
  mine = { -- Mortemines : boss
    texture = 131833, -- glues/loadingscreens/loadscreendeadmines
    crop = { 0, 1, 0.22, 0.72 }, tint = { 0.95, 0.85, 0.75 },
    paint = "cave",
  },
  night = { -- feu de camp
    texture = 7377860, crop = { 0, 1, 0.16, 0.86 }, tint = { 0.32, 0.34, 0.55 },
    paint = "night",
  },
  shop = {
    texture = 7377860, crop = { 0, 1, 0.2, 0.9 }, tint = { 1, 0.9, 0.75 },
    paint = "fields",
  },
}
Art.defaultScene = "road"

-- Personnages des rencontres : event.npc -> { creature = id } (Model:SetCreature). Identifiants de
-- mémoire, NON vérifiés (créatures non indexées par le MCP) ; sans modèle chargé, rien ne s'affiche.
Art.npcs = {
  salma_saldean = { creature = 235 },
  farmer_saldean = { creature = 233 },
  gryan_stoutmantle = { creature = 234 },
}

---------------------------------------------------------------------------
-- Sons : noms SOUNDKIT employés par l'interface Blizzard 12.1.5 (wow_ui_grep), joués par PlaySound
---------------------------------------------------------------------------

Art.sounds = {
  open = "IG_SPELLBOOK_OPEN", close = "IG_SPELLBOOK_CLOSE",
  click = "IG_MAINMENU_OPTION_CHECKBOX_ON",
  card = "IG_ABILITY_PAGE_TURN", play = "UI_ADVENTURES_ADVENTURER_SLOTTED",
  hit = "UI_ADVENTURES_DAMAGE_SWEETENER_MEDIUM", bigHit = "UI_ADVENTURES_DAMAGE_SWEETENER_LARGE",
  block = "UI_ADVENTURES_DEFENSIVE_SWEETENER", heal = "UI_ADVENTURES_HEAL_FOLLOWER",
  enemyDeath = "UI_ADVENTURES_DEATH_ENEMY", playerDeath = "UI_ADVENTURES_DEATH_FRIENDLY",
  victory = "UI_ADVENTURES_ADVENTURE_SUCCESS_COMPLETE", defeat = "UI_ADVENTURES_ADVENTURE_FAILURE_COMPLETE",
  endTurn = "UI_GARRISON_MISSION_ENCOUNTER_ANIMATION_GENERIC", interrupt = "UI_GARRISON_MISSION_THREAT_COUNTERED",
  coin = "LOOT_WINDOW_COIN_SOUND", pick = "UI_ADVENTURES_ADVENTURER_SELECTED",
}

---------------------------------------------------------------------------
-- Cartes (icônes : FileDataID vérifiés ; sorts : repli d'abord tenté par C_Spell)
---------------------------------------------------------------------------

Art.cards = {
  smite                = { spell = 585,    icon = 135924 },  -- spell_holy_holysmite
  inner_fire           = { spell = 588,    icon = 135926 },  -- spell_holy_innerfire
  pw_shield            = { spell = 17,     icon = 135940 },  -- spell_holy_powerwordshield
  sw_pain              = { spell = 589,    icon = 136207 },  -- spell_shadow_shadowwordpain
  radiance             = { spell = 194509, icon = 1386546 }, -- spell_priest_power word
  penance              = { spell = 47540,  icon = 237545 },  -- spell_holy_penance
  pain_suppression     = { spell = 33206,  icon = 135936 },  -- spell_holy_painsupression
  solace               = { spell = 129250, icon = 612968 },  -- ability_priest_flashoflight
  angelic_feather      = { spell = 121536, icon = 642580 },  -- ability_priest_angelicfeather
  luminous_barrier     = { spell = 271466, icon = 253400 },  -- spell_holy_powerwordbarrier
  schism               = { spell = 214621, icon = 463285 },  -- spell_warlock_focusshadow
  shadow_mend          = { spell = 186263, icon = 1386547 }, -- spell_priest_shadow mend
  evangelism           = { spell = 246287, icon = 458968 },  -- ability_priest_evangelism
  rapture              = { spell = 47536,  icon = 237548 },  -- spell_holy_rapture
  mind_flay            = { spell = 15407,  icon = 136208 },  -- spell_shadow_siphonmana
  mind_blast           = { spell = 8092,   icon = 136224 },  -- spell_shadow_unholyfrenzy
  devouring_plague     = { spell = 2944,   icon = 252997 },  -- spell_shadow_devouringplague
  shadowform           = { spell = 15473,  icon = 136200 },  -- spell_shadow_shadowform
  silence              = { spell = 15487,  icon = 458230 },  -- ability_priest_silence
  vampiric_touch       = { spell = 34914,  icon = 135978 },  -- spell_holy_stoicism
  mind_sear            = { spell = 48045,  icon = 237565 },  -- spell_shadow_mindshear
  sw_death             = { spell = 32379,  icon = 136149 },  -- spell_shadow_demonicfortitude
  psychic_scream       = { spell = 8122,   icon = 136184 },  -- spell_shadow_psychicscream
  void_eruption        = { spell = 228260, icon = 1386548 }, -- spell_priest_void blast
  holy_fire            = { spell = 14914,  icon = 135972 },  -- spell_holy_searinglight
  holy_nova            = { spell = 15237,  icon = 135922 },  -- spell_holy_holynova
  chastise             = { spell = 88625,  icon = 135886 },  -- spell_holy_chastise
  greater_heal         = { spell = 2060,   icon = 135913 },  -- spell_holy_greaterheal
  spirit_of_redemption = { spell = 20711,  icon = 1445240 }, -- ability_priest_spiritoftheredeemer
  renew                = { spell = 139,    icon = 135953 },  -- spell_holy_renew
  halo                 = { spell = 120517, icon = 632352 },  -- ability_priest_halo
  flash_heal           = { spell = 2061,   icon = 135907 },  -- spell_holy_flashheal
  empyreal_blaze       = { spell = 372616, icon = 4667419 }, -- ability_priest_empyrealblaze
  apotheosis           = { spell = 200183, icon = 1060983 }, -- ability_priest_ascension
}

-- Repli par école quand une carte n'a pas encore d'entrée.
Art.schools = {
  holy   = { icon = 135920 }, -- spell_holy_holybolt
  shadow = { icon = 136197 }, -- spell_shadow_shadowbolt
}

-- Liseré de rareté (maquette : blanc, vert, bleu).
Art.rarity = {
  basic = Art.C.edgeCommon, common = Art.C.edgeCommon, uncommon = Art.C.edgeUncommon,
  rare = Art.C.edgeRare, epic = hex("#a335ee"), boss = hex("#e2863b"),
}
-- Couleur du nom en infobulle (codes de WoW).
Art.rarityText = {
  basic = { 0.8, 0.8, 0.8 }, common = { 1, 1, 1 }, uncommon = { 0.12, 1, 0 }, rare = { 0.2, 0.55, 1 },
  epic = { 0.64, 0.21, 0.93 }, boss = { 1, 0.5, 0.1 },
}

-- Voies : couleur du cercle du médaillon, de la ligne de type, nom affiché.
Art.paths = {
  start      = { name = "Départ",     ring = hex("#8a6a3a"), ink = hex("#6b4a22") },
  discipline = { name = "Discipline", ring = hex("#7fb6e8"), ink = hex("#2f5f8a") },
  shadow     = { name = "Ombre",      ring = hex("#7b4bb3"), ink = hex("#4f2a82") },
  holy       = { name = "Sacré",      ring = hex("#e2b93b"), ink = hex("#8a4a12") },
}
Art.typeName = { attack = "Sort", skill = "Sort", power = "Pouvoir" }
Art.schoolName = { holy = "Sacré", shadow = "Ombre" }

---------------------------------------------------------------------------
-- Ennemis
---------------------------------------------------------------------------
-- creature = identifiant de créature (Model:SetCreature) ; display = identifiant d'affichage
-- (Model:SetDisplayInfo), essayé si le premier ne donne aucun modèle. NON vérifiés.
Art.enemies = {
  gnoll           = { creature = 117 },              -- Gnoll Rivepatte
  mystic          = { creature = 453 },              -- Mystique Rivepatte
  murloc          = { creature = 126 },              -- Murloc côtier (Coastrunner)
  bandit          = { creature = 116 },              -- Bandit défias
  sorcerer        = { creature = 619 },              -- Sorcier/Conjurateur défias
  harvest_golem   = { creature = 36, scale = 1.2 },  -- Golem moissonneur
  rhahkzor        = { creature = 644, scale = 1.2 }, -- Rhahk'Zor
  defias_henchman = { creature = 594 },              -- Sbire défias
  vancleef        = { creature = 639, display = 2029, scale = 1.15 }, -- Edwin VanCleef
}
Art.enemyIcon = Art.QUESTION

---------------------------------------------------------------------------
-- États (pastilles : couleur bonne/mauvaise ; icône pour les mini-affichages)
---------------------------------------------------------------------------
Art.statuses = {
  armor_broken = { icon = 132363 }, -- ability_warrior_sunder
  demoralized  = { icon = 132366 }, -- ability_warrior_warcry
  atonement    = { icon = 458720 }, -- ability_priest_atonement
  pain         = { icon = 136207 }, -- spell_shadow_shadowwordpain
  regen        = { icon = 135953 }, -- spell_holy_renew
  stunned      = { icon = 135963 }, -- spell_holy_sealofmight
  halved       = { icon = 135936 }, -- spell_holy_painsupression
  force        = { icon = 132333 }, -- ability_warrior_battleshout
  necrotic     = { icon = "Interface\\Icons\\spell_deathknight_necroticplague" },
}

-- Affixes mythiques (chemins vérifiés par wow_icon_search, piste D).
Art.keystone = { icon = "Interface\\Icons\\inv_relics_hourglass" }
Art.affixes = {
  fortified  = { icon = "Interface\\Icons\\ability_toughness" },
  tyrannical = { icon = "Interface\\Icons\\achievement_boss_archaedas" },
  bolstering = { icon = 132333 },
  necrotic   = { icon = "Interface\\Icons\\spell_deathknight_necroticplague" },
  famine     = { icon = "Interface\\Icons\\inv_misc_food_15" },
}

---------------------------------------------------------------------------
-- Bibelots et potions
---------------------------------------------------------------------------
Art.relics = {
  hearthstone      = { icon = 134414 },  -- inv_misc_rune_01
  defias_purse     = { icon = 133639 },  -- inv_misc_bag_10
  linen_bandage    = { icon = 133671 },  -- inv_misc_bandage_01
  stormwind_tabard = { icon = 135026 },  -- inv_shirt_guildtabard_01
  vancleef_bandana = { icon = 133694 },  -- inv_misc_bandana_03
  faction_insignia = { icon = 133452 },  -- inv_jewelry_trinketpvp_01
  sharpening_stone = { icon = 135248 },  -- inv_stone_sharpeningstone_01
  focus_talisman   = { icon = "Interface\\Icons\\inv_jewelry_talisman_07" },
  camp_kettle      = { icon = 133779 },  -- inv_misc_cauldron_fire
  mana_ruby        = { icon = 134128 },  -- inv_misc_gem_ruby_01
}
Art.relicFallback = { icon = "Interface\\Icons\\inv_jewelry_talisman_07" }
Art.potions = {
  healing_potion    = { icon = 134831, color = hex("#b3402e") }, -- inv_potion_51
  mana_potion       = { icon = 134856, color = hex("#3b82d6") }, -- inv_potion_76
  shadow_protection = { icon = 134803, color = hex("#7b4bb3") }, -- inv_potion_23
  liquid_fire       = { icon = 134805, color = hex("#e2863b") }, -- inv_potion_25
  wisdom_elixir     = { icon = 134721, color = hex("#3fae4a") }, -- inv_potion_10
}
Art.potionFallback = { icon = 134831, color = hex("#b3402e") }
Art.emptySlot = { icon = "Interface\\Buttons\\UI-EmptySlot" }

function Art.relic(id)
  return Art.relics[id] or Art.relicFallback
end

function Art.potion(id)
  return Art.potions[id] or Art.potionFallback
end

---------------------------------------------------------------------------
-- Intentions (bulle au-dessus de l'ennemi : icône + chiffre, liseré de couleur)
---------------------------------------------------------------------------
Art.intents = {
  attack = { icon = 132223, color = "attack" },  -- ability_meleedamage
  defend = { icon = 134952, color = "defend" },  -- inv_shield_06
  cast   = { icon = 135812, color = "attack" },  -- spell_fire_flamebolt
  watch  = { icon = 132219, color = "watch" },   -- ability_kick
  debuff = { icon = 136138, color = "watch" },   -- spell_shadow_curseofmannoroth
  buff   = { icon = 132333, color = "defend" },  -- ability_warrior_battleshout
  heal   = { icon = 135929, color = "heal" },    -- spell_holy_lesserheal
  summon = { icon = 136218, color = "watch" },   -- spell_shadow_summonimp
  stunned = { icon = 135963, color = "defend" }, -- spell_holy_sealofmight
  interrupted = { icon = 132219, color = "defend" },
}
Art.intentName = {
  attack = "Attaque", defend = "Défense", cast = "Incante", watch = "Guette",
  debuff = "Affaiblit", buff = "Renforce", heal = "Soigne", summon = "Invoque",
}

---------------------------------------------------------------------------
-- Interface
---------------------------------------------------------------------------
Art.ui = {
  minimap   = { icon = 133741 },  -- inv_misc_book_09
  mana      = { icon = 132841 },  -- inv_elemental_mote_mana
  demence   = { icon = 136223 },  -- spell_shadow_twilight
  gold      = { icon = 133784 },  -- inv_misc_coin_01
  bedroll   = { icon = 5545560 }, -- inv_misc_nightelfbedroll
  grimoire  = { icon = 133741 },  -- inv_misc_book_09
  chest     = { icon = 1542843 }, -- inv_misc_treasurechest01a
  remove    = { icon = 135805 },  -- spell_fire_fire
  map = {
    combat   = { icon = 132147 },  -- ability_dualwield
    elite    = { icon = 132352 },  -- ability_warrior_rampage
    boss     = { icon = 134153 },  -- inv_misc_head_dragon_01
    campfire = { icon = 135805 },  -- spell_fire_fire
    merchant = { icon = 133639 },  -- inv_misc_bag_10
    shop     = { icon = 133639 },
    event    = { icon = 134328 },  -- inv_misc_note_02
    chest    = { icon = 132595 },  -- inv_box_02
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
  spell = 53, spellOmni = 54, ready = 25, sit = 97 }
