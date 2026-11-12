-- Table d'art : tout le visuel lié au contenu vit ici, jamais dans Data/.
-- Chaque icône est décrite par { spell = idSort, icon = FileDataID ou chemin } : l'interface essaie
-- d'abord l'icône du sort (C_Spell.GetSpellTexture), puis l'icône, puis le point d'interrogation.
-- Les FileDataID d'icônes et de textures ci-dessous sont confirmés par le MCP « wow »
-- (wow_icon_search / wow_file_search, liste de fichiers du client 12.1.5). Les identifiants de
-- créatures viennent du cache du client Forever (voir Art.enemies) ; ceux des sorts et des animations
-- ne sont PAS vérifiables hors jeu : `/slay art` et `/slay models` listent en jeu ce qui manque
-- (voir docs/interface.md).
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
  -- peau « Mechanized Magic » (docs/maquette/gen_combat_pack.py, gen_screens_pack.py)
  slateDark = hex("#12161e"), text = hex("#f4f6fa"), textSoft = hex("#bec8d6"), textDim = hex("#8e98a8"),
  inkDark = hex("#28221a"), goldText = hex("#ffd660"), goldInk = hex("#342208"), hpRed = hex("#d6262c"),
  hpShine = hex("#ff8282"), ghostLight = hex("#ffeca9"), upGreen = hex("#7dff7d"), healGreen = hex("#78e682"),
  badText = hex("#ff8278"), costText = hex("#ffffff"), cool = hex("#3c5a96"), barTrack = hex("#0c1016"),
  rarityUncommon = hex("#43b24f"),
  -- habillage WoW (tools/build_wowui.py) : doré des libellés (NORMAL_FONT_COLOR), encre des parchemins
  wowGold = { 1, 0.82, 0 }, parchInk = hex("#2e1d0c"), parchGood = hex("#1d6b12"), parchBad = hex("#8c1a0c"),
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

-- Fonds embarqués (Media/Backgrounds/*.tga, fabriqués par tools/build_backgrounds.py) : illustrations
-- de Blizzard extraites du jeu (écrans de chargement, FileDataID `source`), recadrées sans logo ni cadre
-- et étirées sur une texture 1024 × 512. `ratio` = rapport largeur / hauteur réel de la zone gardée
-- (affiché par le script) : UI/Scene.lua en montre une bande au format du décor (≈ 2,72:1), placée en
-- hauteur par le `focus` de la scène. Un fichier de l'addon existe forcément : affichés sans validation.
-- À RÉÉVALUER avant toute publication de l'addon (droits de Blizzard).
local BG = "Interface\\AddOns\\SlayTheDragon\\Media\\Backgrounds\\"
Art.backgrounds = {
  elwynn = { file = BG .. "elwynn.tga", embedded = true, key = "elwynn", ratio = 2.019, source = 7377860,
    name = "Elwynn Forest (housing, Midnight)" },
  farm = { file = BG .. "farm.tga", embedded = true, key = "farm", ratio = 2.241, source = 407226,
    name = "Twin Peaks (farm and path)" },
  deadmines = { file = BG .. "deadmines.tga", embedded = true, key = "deadmines", ratio = 2.359, source = 131833,
    name = "The Deadmines (classic screen)" },
  ruins = { file = BG .. "ruins.tga", embedded = true, key = "ruins", ratio = 2.629, source = 7963782,
    name = "Ruins of Lordaeron (Forever screen)" },
  coast = { file = BG .. "coast.tga", embedded = true, key = "coast", ratio = 2.221, source = 427941,
    name = "Gilneas (lighthouse and coast)" },
}
local B = Art.backgrounds

-- Illustrations : pour chacune, une liste ORDONNÉE de candidats ; le fond embarqué est en tête et
-- s'affiche toujours. Repli (plus nécessaire) : les candidats par FileDataID ou chemin du client.
-- Aucun test fiable ne dit, sur ce client, si un tel fichier existe : un fichier absent est dessiné en
-- aplat vert, et SetTexture / GetTextureFileID / IsObjectLoaded le disent pourtant présent. Ils ne
-- s'affichent donc que VALIDÉS par le joueur (`/slay scenery test`, puis `ok` / `no` ; verdicts dans
-- options.artChecks), et seulement si le fond embarqué manquait à la liste.
-- `file` = FileDataID ou chemin ; `name` = nom annoncé pendant l'essai ; `crop` = { gauche, droite,
-- haut, bas } en fraction de l'image, pour la bande 1034 × 380 (≈ 2,7:1) : ≈ 0,65 de la hauteur pour
-- une image 16:9, ≈ 0,5 pour une image 4:3 (cadrages à confirmer en jeu). Une entrée chaîne renvoie à
-- la liste d'une autre illustration (à la suite).
-- FileDataID confirmés dans la liste de fichiers retail 12.1.5 (wow_file_search) ; leur présence
-- dans le client Forever (« Camelot », 1.16) n'est PAS vérifiable hors jeu :
--   * 7377860 (logement d'Elwynn, Midnight) : très probablement absent de Forever ;
--   * camelot160/main/* (7963776, 7963777, 7963782) : écrans de chargement propres à Forever ;
--   * 131833, 131839 (Mortemines, royaumes de l'Est) : écrans de la version classique.
Art.illustrations = {
  elwynn = {
    B.elwynn,
    { file = 7377860, crop = { 0, 1, 0.16, 0.86 }, name = "Elwynn housing (Midnight)" },
    { file = 7963776, crop = { 0, 1, 0.18, 0.83 }, name = "Eastern Kingdoms (Forever screen)" },
    { file = 131839, crop = { 0, 1, 0.14, 0.64 }, name = "Eastern Kingdoms (classic screen)" },
    { file = "Interface\\Glues\\LoadingScreens\\LoadScreenEasternKingdom", crop = { 0, 1, 0.14, 0.64 },
      name = "Eastern Kingdoms (classic screen, by path)" },
  },
  deadmines = {
    B.deadmines,
    { file = 131833, crop = { 0, 1, 0.22, 0.72 }, name = "The Deadmines (classic screen)" },
    { file = "Interface\\Glues\\LoadingScreens\\LoadScreenDeadmines", crop = { 0, 1, 0.22, 0.72 },
      name = "The Deadmines (classic screen, by path)" },
    { file = 7963777, crop = { 0, 1, 0.18, 0.83 }, name = "Excavation (Forever screen)" },
  },
  ruins = {
    B.ruins,
    { file = 7963782, crop = { 0, 1, 0.18, 0.83 }, name = "Ruins of Lordaeron (Forever screen)" },
    "elwynn",
  },
  farm = { B.farm, "elwynn" },
  coast = { B.coast },
}

-- Décors : `art` = illustration (ci-dessus) posée sur la bande du haut, teintée par `tint` ; fond
-- embarqué cadré par `focus` (hauteur de la bande montrée : 0 = haut de l'image, 1 = bas), candidat du
-- client décalé verticalement de `shift` (fraction) ; `paint` = décor peint en couches unies aux
-- couleurs des maquettes, toujours dessiné dessous (repli). Point d'extension : ajouter une entrée ici
-- (et `scene = "<clé>"` dans une rencontre) suffit ; `/slay scenery` bascule illustré / peint.
Art.scenes = {
  road = { art = "elwynn", focus = 0.62, tint = { 1, 0.96, 0.88 }, paint = "fields" },   -- route et combats
  farm = { art = "farm", focus = 0.55, shift = -0.04, tint = { 1, 0.95, 0.82 }, paint = "farm" },
  mine = { art = "deadmines", focus = 0.5, tint = { 0.9, 0.9, 0.86 }, paint = "cave" },    -- boss
  night = { art = "elwynn", focus = 0.55, tint = { 0.32, 0.34, 0.55 }, paint = "night" }, -- feu de camp
  hill = { art = "elwynn", focus = 0.15, shift = -0.1, tint = { 1, 0.95, 0.85 }, paint = "fields" }, -- Colline
  camp = { art = "elwynn", focus = 0.9, shift = 0.04, tint = { 0.95, 0.87, 0.74 }, paint = "fields" },
  ruins = { art = "ruins", focus = 0.5, shift = 0.04, tint = { 0.85, 0.82, 0.78 }, paint = "cave" },
  coast = { art = "coast", focus = 0.45, tint = { 1, 0.97, 0.9 }, paint = "coast" }, -- côte de la Marche
  shop = { art = "elwynn", focus = 0.78, shift = 0.04, tint = { 1, 0.92, 0.8 }, paint = "fields" },
}
Art.defaultScene = "road"

-- Personnages des rencontres : event.npc -> { creature = id, display = id } (voir Art.enemies pour
-- l'ordre des essais et la source des identifiants) ; sans modèle chargé, rien ne s'affiche.
Art.npcs = {
  salma_saldean = { creature = 235, display = 1691 },     -- Salma Saldean
  farmer_saldean = { creature = 233, display = 1943 },    -- Saldean le fermier
  gryan_stoutmantle = { creature = 234, display = 1690 }, -- Gryan Fortmanteau
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
  smite                = { spell = 585,    icon = 135924, tga = "Spell_Holy_HolySmite" },  -- spell_holy_holysmite
  inner_fire           = { spell = 588,    icon = 135926, tga = "Spell_Holy_InnerFire" },  -- spell_holy_innerfire
  pw_shield            = { spell = 17,     icon = 135940, tga = "Spell_Holy_PowerWordShield" },  -- spell_holy_powerwordshield
  sw_pain              = { spell = 589,    icon = 136207, tga = "Spell_Shadow_ShadowWordPain" },  -- spell_shadow_shadowwordpain
  radiance             = { spell = 194509, icon = 1386546, tga = "Spell_Priest_Power Word" }, -- spell_priest_power word
  penance              = { spell = 47540,  icon = 237545, tga = "Spell_Holy_Penance" },  -- spell_holy_penance
  pain_suppression     = { spell = 33206,  icon = 135936, tga = "Spell_Holy_PainSupression" },  -- spell_holy_painsupression
  solace               = { spell = 129250, icon = 612968, tga = "Ability_Priest_Flashoflight" },  -- ability_priest_flashoflight
  angelic_feather      = { spell = 121536, icon = 642580, tga = "Ability_Priest_AngelicFeather" },  -- ability_priest_angelicfeather
  luminous_barrier     = { spell = 271466, icon = 253400, tga = "Spell_Holy_PowerWordBarrier" },  -- spell_holy_powerwordbarrier
  schism               = { spell = 214621, icon = 463285, tga = "spell_Warlock_Focusshadow" },  -- spell_warlock_focusshadow
  shadow_mend          = { spell = 186263, icon = 1386547, tga = "Spell_Priest_Shadow Mend" }, -- spell_priest_shadow mend
  evangelism           = { spell = 246287, icon = 458968, tga = "Ability_Priest_Evangelism" },  -- ability_priest_evangelism
  rapture              = { spell = 47536,  icon = 237548, tga = "Spell_Holy_Rapture" },  -- spell_holy_rapture
  mind_flay            = { spell = 15407,  icon = 136208, tga = "Spell_Shadow_SiphonMana" },  -- spell_shadow_siphonmana
  mind_blast           = { spell = 8092,   icon = 136224, tga = "Spell_Shadow_UnholyFrenzy" },  -- spell_shadow_unholyfrenzy
  devouring_plague     = { spell = 2944,   icon = 252997, tga = "Spell_Shadow_DevouringPlague" },  -- spell_shadow_devouringplague
  shadowform           = { spell = 15473,  icon = 136200, tga = "Spell_Shadow_Shadowform" },  -- spell_shadow_shadowform
  silence              = { spell = 15487,  icon = 458230, tga = "Ability_Priest_Silence" },  -- ability_priest_silence
  vampiric_touch       = { spell = 34914,  icon = 135978, tga = "Spell_Holy_Stoicism" },  -- spell_holy_stoicism
  mind_sear            = { spell = 48045,  icon = 237565, tga = "Spell_Shadow_MindShear" },  -- spell_shadow_mindshear
  sw_death             = { spell = 32379,  icon = 136149, tga = "Spell_Shadow_DemonicFortitude" },  -- spell_shadow_demonicfortitude
  psychic_scream       = { spell = 8122,   icon = 136184, tga = "Spell_Shadow_PsychicScream" },  -- spell_shadow_psychicscream
  void_eruption        = { spell = 228260, icon = 1386548, tga = "Spell_Priest_Void Blast" }, -- spell_priest_void blast
  holy_fire            = { spell = 14914,  icon = 135972, tga = "Spell_Holy_SearingLight" },  -- spell_holy_searinglight
  holy_nova            = { spell = 15237,  icon = 135922, tga = "Spell_Holy_HolyNova" },  -- spell_holy_holynova
  chastise             = { spell = 88625,  icon = 135886, tga = "Spell_Holy_Chastise" },  -- spell_holy_chastise
  greater_heal         = { spell = 2060,   icon = 135913, tga = "Spell_Holy_GreaterHeal" },  -- spell_holy_greaterheal
  spirit_of_redemption = { spell = 20711,  icon = 1445240, tga = "Ability_Priest_SpiritOfTheRedeemer" }, -- ability_priest_spiritoftheredeemer
  renew                = { spell = 139,    icon = 135953, tga = "Spell_Holy_Renew" },  -- spell_holy_renew
  halo                 = { spell = 120517, icon = 632352, tga = "Ability_Priest_Halo" },  -- ability_priest_halo
  flash_heal           = { spell = 2061,   icon = 135907, tga = "Spell_Holy_FlashHeal" },  -- spell_holy_flashheal
  empyreal_blaze       = { spell = 372616, icon = 4667419, tga = "Ability_Priest_EmpyrealBlaze" }, -- ability_priest_empyrealblaze
  apotheosis           = { spell = 200183, icon = 1060983, tga = "Ability_Priest_Ascension" }, -- ability_priest_ascension
}

-- Repli par école quand une carte n'a pas encore d'entrée.
Art.schools = {
  holy   = { icon = 135920, tga = "Spell_Holy_HolyBolt" }, -- spell_holy_holybolt
  shadow = { icon = 136197, tga = "Spell_Shadow_ShadowBolt" }, -- spell_shadow_shadowbolt
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
  start      = { name = "Starter",     ring = hex("#8a6a3a"), ink = hex("#6b4a22") },
  discipline = { name = "Discipline", ring = hex("#7fb6e8"), ink = hex("#2f5f8a") },
  shadow     = { name = "Shadow",      ring = hex("#7b4bb3"), ink = hex("#4f2a82") },
  holy       = { name = "Holy",      ring = hex("#e2b93b"), ink = hex("#8a4a12") },
}
Art.typeName = { attack = "Spell", skill = "Spell", power = "Power" }
Art.schoolName = { holy = "Holy", shadow = "Shadow" }

---------------------------------------------------------------------------
-- Ennemis
---------------------------------------------------------------------------
-- creature = identifiant de créature (Model:SetCreature) ; display = identifiant d'affichage, ou liste
-- (Model:SetDisplayInfo), essayés dans l'ordre si le précédent ne donne aucun modèle (W.setCreatureArt).
-- Identifiants relevés le 10/11/2026 dans le cache de créatures du client Forever lui-même
-- (Cache/WDB/enUS et frFR/creaturecache.wdb : identifiant, nom, affichages), wow_creature_search
-- n'ayant pas accès à l'installation. Les créatures à deux affichages (homme / femme) sont des
-- humanoïdes équipés : leur chargement est le plus fragile, d'où les affichages en repli.
-- icon = repli dans le médaillon quand aucun modèle ne se charge (icônes de Media/Icons ou icônes
-- classiques du jeu, FileDataID confirmés par wow_icon_search) ; sans icône : disque sombre.
local HEAD_GNOLL = { icon = 134163 }  -- inv_misc_head_gnoll_01
local HEAD_MURLOC = { icon = 134169 } -- inv_misc_head_murloc_01
local BANDANA = { icon = 133694, tga = "INV_Misc_Bandana_03" } -- inv_misc_bandana_03
Art.enemies = {
  gnoll           = { creature = 117, display = 175, icon = HEAD_GNOLL },   -- Riverpaw Gnoll
  mystic          = { creature = 453, display = 502, icon = HEAD_GNOLL },   -- Riverpaw Mystic
  murloc          = { creature = 126, display = 983, icon = HEAD_MURLOC },  -- Murloc Coastrunner
  bandit          = { creature = 116, display = { 2357, 2358 }, icon = BANDANA }, -- Defias Bandit
  -- Invocateur défias (Defias Conjurer, Marche de l'Ouest) ; « Sorcier défias » du client = 4418
  -- (Mortemines, affichages 2447 / 2448, cache frFR seulement).
  sorcerer        = { creature = 619, display = { 2329, 2330 },
                      icon = { icon = 135812, tga = "Spell_Fire_FlameBolt" } }, -- spell_fire_flamebolt
  harvest_golem   = { creature = 36, display = 367, scale = 1.2, icon = { icon = 134063 } }, -- inv_misc_gear_01
  rhahkzor        = { creature = 644, display = 14403, scale = 1.2,
                      icon = { icon = 133730, tga = "INV_Misc_Bone_HumanSkull_01" } }, -- inv_misc_bone_humanskull_01
  defias_henchman = { creature = 594, display = { 2323, 2324 }, icon = BANDANA }, -- Malfrat défias (Defias Henchman)
  vancleef        = { creature = 639, display = 2029, scale = 1.15,
                      icon = { icon = 236409, tga = "Achievement_Boss_EdwinVancleef" } }, -- Edwin VanCleef
}

---------------------------------------------------------------------------
-- États (pastilles : couleur bonne/mauvaise ; icône pour les mini-affichages)
---------------------------------------------------------------------------
Art.statuses = {
  armor_broken = { icon = 132363, tga = "Ability_Warrior_Sunder" }, -- ability_warrior_sunder
  demoralized  = { icon = 132366, tga = "Ability_Warrior_WarCry" }, -- ability_warrior_warcry
  atonement    = { icon = 458720, tga = "Ability_Priest_Atonement" }, -- ability_priest_atonement
  pain         = { icon = 136207, tga = "Spell_Shadow_ShadowWordPain" }, -- spell_shadow_shadowwordpain
  regen        = { icon = 135953, tga = "Spell_Holy_Renew" }, -- spell_holy_renew
  stunned      = { icon = 135963, tga = "Spell_Holy_SealOfMight" }, -- spell_holy_sealofmight
  halved       = { icon = 135936, tga = "Spell_Holy_PainSupression" }, -- spell_holy_painsupression
  force        = { icon = 132333, tga = "Ability_Warrior_BattleShout" }, -- ability_warrior_battleshout
  necrotic     = { icon = "Interface\\Icons\\spell_deathknight_necroticplague", tga = "Spell_Deathknight_Necroticplague" },
  instant      = { icon = "Interface\\Icons\\spell_nature_lightning", tga = "Spell_Nature_Lightning" },
}

-- Icône d'un état selon sa source (Combat.applyStatus(c, unité, id, n, clé) → unit.stIcon[id] = clé) :
-- Art.statusIcons[clé] remplace l'icône de l'état (DoT de poison, de saignement, de brûlure…).
Art.statusIcons = Art.statusIcons or {}

-- Affixes mythiques (chemins vérifiés par wow_icon_search, piste D).
Art.keystone = { icon = "Interface\\Icons\\inv_relics_hourglass", tga = "INV_Relics_Hourglass" }
-- Classes : icône de classe (portrait du cadre du héros quand le personnage n'est pas de cette classe,
-- bouton de l'accueil), pastille de la ressource (`resource` : icône, couleur des chiffres flottants),
-- `wow` = nom de classe du jeu (UnitClass) pour reprendre le portrait du personnage.
-- Une classe ajoute son entrée depuis UI/Art/<classe>.lua (Art.classes.<id> = { … }).
Art.classes = {
  priest = { icon = 626004, tga = "ClassIcon_Priest", wow = "PRIEST", -- classicon_priest
    resource = { icon = 136223, tga = "Spell_Shadow_Twilight", color = "watchText" } }, -- spell_shadow_twilight
}

-- Affichage propre d'une classe dans la zone libre du combat (UI/CombatView.lua) :
-- ns.ClassViews[id] = { build = f(hôte, vue), render = f(hôte, combat, vue) } (docs/classes.md).
ns.ClassViews = ns.ClassViews or {}

-- Entrée d'art d'une classe (repli : Priest) et de sa ressource.
function Art.class(id)
  return Art.classes[id] or Art.classes.priest
end
function Art.classResource(id)
  local e = Art.classes[id]
  return (e and e.resource) or Art.classes.priest.resource
end
Art.affixes = {
  fortified  = { icon = "Interface\\Icons\\ability_toughness", tga = "ability_toughness" },
  tyrannical = { icon = "Interface\\Icons\\achievement_boss_archaedas", tga = "Achievement_Boss_Archaedas" },
  bolstering = { icon = 132333, tga = "Ability_Warrior_BattleShout" }, -- ability_warrior_battleshout
  necrotic   = { icon = "Interface\\Icons\\spell_deathknight_necroticplague", tga = "Spell_Deathknight_Necroticplague" },
  famine     = { icon = "Interface\\Icons\\inv_misc_food_15", tga = "INV_Misc_Food_15" },
}

---------------------------------------------------------------------------
-- Bibelots et potions
---------------------------------------------------------------------------
Art.relics = {
  hearthstone      = { icon = 134414, tga = "INV_MISC_RUNE_01" },  -- inv_misc_rune_01
  defias_purse     = { icon = 133639, tga = "INV_Misc_Bag_10" },  -- inv_misc_bag_10
  linen_bandage    = { icon = 133671, tga = "INV_Misc_Bandage_01" },  -- inv_misc_bandage_01
  stormwind_tabard = { icon = 135026, tga = "INV_Shirt_GuildTabard_01" },  -- inv_shirt_guildtabard_01
  vancleef_bandana = { icon = 133694, tga = "INV_Misc_Bandana_03" },  -- inv_misc_bandana_03
  faction_insignia = { icon = 133452, tga = "INV_Jewelry_TrinketPVP_01" },  -- inv_jewelry_trinketpvp_01
  sharpening_stone = { icon = 135248, tga = "INV_Stone_SharpeningStone_01" },  -- inv_stone_sharpeningstone_01
  focus_talisman   = { icon = "Interface\\Icons\\inv_jewelry_talisman_07", tga = "INV_Jewelry_Talisman_07" },
  camp_kettle      = { icon = 133779, tga = "INV_Misc_Cauldron_Fire" },  -- inv_misc_cauldron_fire
  mana_ruby        = { icon = 134128, tga = "INV_Misc_Gem_Ruby_01" },  -- inv_misc_gem_ruby_01
}
Art.relicFallback = { icon = "Interface\\Icons\\inv_jewelry_talisman_07" }
Art.potions = {
  healing_potion    = { icon = 134831, color = hex("#b3402e"), tga = "INV_Potion_51" }, -- inv_potion_51
  mana_potion       = { icon = 134856, color = hex("#3b82d6"), tga = "INV_Potion_76" }, -- inv_potion_76
  shadow_protection = { icon = 134803, color = hex("#7b4bb3"), tga = "INV_Potion_23" }, -- inv_potion_23
  liquid_fire       = { icon = 134805, color = hex("#e2863b"), tga = "INV_Potion_25" }, -- inv_potion_25
  wisdom_elixir     = { icon = 134721, color = hex("#3fae4a"), tga = "INV_Potion_10" }, -- inv_potion_10
}
Art.potionFallback = { icon = 134831, color = hex("#b3402e") }

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
  attack = { icon = 132223, color = "attack", tga = "Ability_MeleeDamage" },  -- ability_meleedamage
  defend = { icon = 134950, color = "defend", tga = "INV_Shield_04" },  -- inv_shield_04 (planche)
  cast   = { icon = 135812, color = "attack", tga = "Spell_Fire_FlameBolt" },  -- spell_fire_flamebolt
  watch  = { icon = 136155, color = "watch", tga = "Spell_Shadow_EvilEye" },   -- spell_shadow_evileye (planche)
  debuff = { icon = 136138, color = "watch", tga = "Spell_Shadow_CurseOfMannoroth" },   -- spell_shadow_curseofmannoroth
  buff   = { icon = 132333, color = "defend", tga = "Ability_Warrior_BattleShout" },  -- ability_warrior_battleshout
  heal   = { icon = 135929, color = "heal", tga = "Spell_Holy_LesserHeal" },    -- spell_holy_lesserheal
  summon = { icon = 136218, color = "watch", tga = "Spell_Shadow_SummonImp" },   -- spell_shadow_summonimp
  stunned = { icon = 135963, color = "defend", tga = "Spell_Holy_SealOfMight" }, -- spell_holy_sealofmight
  interrupted = { icon = 132219, color = "defend", tga = "Ability_Kick" }, -- ability_kick
}
Art.intentName = {
  attack = "Attack", defend = "Defend", cast = "Casting", watch = "Watch",
  debuff = "Debuff", buff = "Buff", heal = "Heal", summon = "Summon",
}

---------------------------------------------------------------------------
-- Interface
---------------------------------------------------------------------------
Art.ui = {
  minimap   = { icon = 133741, tga = "INV_Misc_Book_09" },  -- inv_misc_book_09
  mana      = { icon = 132841, tga = "INV_Elemental_Mote_Mana" },  -- inv_elemental_mote_mana
  gold     = { icon = 133784, tga = "INV_Misc_Coin_01" },  -- inv_misc_coin_01
  bedroll   = { icon = 5545560, tga = "INV_MISC_NightelfBedroll" }, -- inv_misc_nightelfbedroll
  grimoire  = { icon = 133741, tga = "INV_Misc_Book_09" },  -- inv_misc_book_09
  chest     = { icon = 1542843, tga = "inv_misc_treasurechest01a" }, -- inv_misc_treasurechest01a
  remove    = { icon = 135813, tga = "Spell_Fire_FlameShock" },  -- spell_fire_flameshock (planche)
  bag       = { icon = 133639, tga = "INV_Misc_Bag_10" },  -- inv_misc_bag_10 (bourse du butin)
  -- Étapes du parcours (icônes des planches docs/maquette/ecran_parcours.jpg)
  map = {
    combat   = { icon = 132223, tga = "Ability_MeleeDamage" },  -- ability_meleedamage
    elite    = { icon = 133730, tga = "INV_Misc_Bone_HumanSkull_01" },  -- inv_misc_bone_humanskull_01
    boss     = { icon = 236409, tga = "Achievement_Boss_EdwinVancleef" },  -- achievement_boss_edwinvancleef
    campfire = { icon = 7808148, tga = "INV_Camelot_Camping_WelcomingCampfire" }, -- inv_camelot_camping_welcomingcampfire
    merchant = { icon = 133639, tga = "INV_Misc_Bag_10" },  -- inv_misc_bag_10
    shop     = { icon = 133639, tga = "INV_Misc_Bag_10" },
    event    = { icon = 134400, tga = "INV_Misc_QuestionMark" },  -- inv_misc_questionmark
    chest    = { icon = 132594, tga = "INV_Box_01" },  -- inv_box_01
  },
}

---------------------------------------------------------------------------
-- Peau (pack Mechanized Magic) : couleur du corps des cartes, gemmes, teintes des liserés
---------------------------------------------------------------------------

-- Corps de carte : violet = Ombre, bleu = protections (Absorption d'abord), or = cartes de départ,
-- ivoire = Sacré (le reste) ; carte neutre (sans classe) : ivoire teinté (Art.cardBodyTint), toujours.
-- Art.cards[id].body force une couleur.
function Art.cardBody(id, d)
  local e = Art.cards[id]
  if e and e.body then return e.body end
  if d.neutral and not d.class then return "ivory" end
  if d.school == "shadow" then return "violet" end
  local first = d.effects and d.effects[1]
  if first and (first[1] == "absorb" or (first[1] == "apply" and first[2] == "halved")) then return "blue" end
  if d.path == "start" then return "gold" end
  return "ivory"
end

-- Teinte multiplicative du corps (couleur de sommet) ou nil : cartes neutres (Art.bodyTints.neutral,
-- UI/Art/neutral.lua). Art.cards[id].tint force une teinte.
Art.bodyTints = Art.bodyTints or {}
function Art.cardBodyTint(id, d)
  local e = Art.cards[id]
  if e and e.tint then return e.tint end
  if d.neutral and not d.class then return Art.bodyTints.neutral end
  return nil
end

-- Liseré d'une case de bibelot selon sa rareté.
Art.rarityRim = {
  basic = { 1, 1, 1 }, common = { 1, 1, 1 }, uncommon = { 0.55, 1, 0.55 }, rare = { 0.6, 0.8, 1 },
  epic = { 0.85, 0.6, 1 }, boss = { 1, 0.7, 0.35 },
}

-- Gemme de rareté (aucune pour une carte de base ou commune).
Art.gems = { uncommon = "uncommon", rare = "rare", epic = "epic", boss = "legendary", legendary = "legendary" }

-- Teintes multiplicatives du liseré d'argent (couleur de sommet) et de l'ardoise.
Art.rim = {
  silver = { 1, 1, 1 }, gold = { 1, 0.86, 0.42 }, red = { 1, 0.55, 0.5 }, debuff = { 1, 0.3, 0.25 }, attack = { 1, 0.55, 0.5 },
  defend = { 0.7, 0.86, 1 }, watch = { 0.9, 0.7, 1 }, heal = { 0.62, 1, 0.62 }, dim = { 0.6, 0.63, 0.68 },
  violet = { 0.85, 0.6, 1 }, green = { 0.55, 1, 0.55 },
}

-- Mots-clés (infobulles) : une ligne « Nom : effet. » par mot-clé, 60 caractères au plus, l'effet
-- principal et rien d'autre (le reste se découvre en jouant). N = nombre de tours (Recharge).
-- Les mots de la plaque, les conditions nommées (Execute, Surge, Spend…), les ressources des classes
-- et « Pay N HP » viennent du registre du langage des cartes (Core/Language.lua) : une classe y
-- ajoute les siens sans toucher à ce fichier.
Art.keywords = {
  absorb = { name = "Absorb", text = "absorbs damage until the next turn." },
  interrupt = { name = "Interrupt", text = "cancels the spell an enemy is casting." },
  -- sablier du texte des cartes (« Donne Expiation 1 ⌛ »)
  turns = { name = "⌛", text = "status duration, in turns." },
}

-- Mot-clé : Art.keywords, puis le registre du langage (plaque, condition, mot, ressource « res:<id> »).
function Art.keyword(key)
  local kw = Art.keywords[key]
  if kw then return kw end
  local L = ns.Language
  local rid = key:match("^res:(.+)$")
  if rid then return L.resources[rid] end
  return L.plateByKey(key) or L.conditionByKey(key) or L.keywords[key]
end

-- Définition courte d'un état pour l'infobulle d'une carte (« Nom : effet. », 60 caractères au plus ;
-- le texte complet de Core/Statuses.lua reste celui des jetons d'état).
Art.statusShort = {
  atonement = "each card that deals damage restores 2 HP.",
  pain = "N damage per turn, then N drops by 1.",
  regen = "heals N per turn, then N drops by 1.",
  armor_broken = "takes 25% more damage.",
  demoralized = "deals 25% less damage.",
  stunned = "loses its next turn.",
  halved = "damage taken is halved.",
  force = "N more damage per hit.",
  instant = "the next Cast card resolves at once.",
}

-- Ligne d'un état cité par une carte : nom en or, définition courte.
function Art.statusLine(id)
  local s = ns.Statuses[id]
  local name = s and s.name or id
  local text = Art.statusShort[id] or (s and s.text and s.text:gsub("^%u", string.lower)) or ""
  return "|cffffd100" .. name .. "|r: " .. text
end

-- Ligne d'une condition sur un état (« Expiation : … ») : sur soi pour un bienfait, sur la cible
-- pour un affaiblissement.
function Art.conditionLine(id)
  local s = ns.Statuses[id]
  local name = s and s.name or id
  if s and s.debuff then return "|cffffd100" .. name .. ":|r bonus effect if the target has " .. name .. "." end
  return "|cffffd100" .. name .. ":|r bonus effect while under " .. name .. "."
end

-- Ligne d'un mot-clé : nom en or, effet ; n = nombre de tours d'une Recharge ; res = id de la ressource
-- de la classe de la carte (« %s » de l'explication : « Surge: spends all Rage for the effect. »).
function Art.keywordLine(key, label, n, res)
  local kw = Art.keyword(key)
  if not kw then return label or key end
  local text = kw.text or ""
  if text:find("%s", 1, true) then
    local L = ns.Language
    local rname = res and L.resources[res] and L.resources[res].name or "resource"
    text = text:gsub("%%s", rname)
  end
  if n and text:find("%f[%w]N%f[%W]") then
    local rep = (kw.n or key == "cooldown") and (n .. " turn" .. (n > 1 and "s" or "")) or tostring(n)
    text = text:gsub("%f[%w]N%f[%W]", rep)
  end
  return "|cffffd100" .. (label or kw.name) .. "|r: " .. text
end

-- Animations des modèles (identifiants AnimationData usuels ; à confirmer en jeu).
Art.anim = { stand = 0, death = 1, dead = 6, wound = 9, attack = 16, attack1h = 17,
  spell = 53, spellOmni = 54, ready = 25, sit = 97 }
