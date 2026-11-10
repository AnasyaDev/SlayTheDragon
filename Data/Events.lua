-- Rencontres (étapes « Rencontre » de la carte). Liste commentée et intentions : docs/rencontres.md.
--
-- Une rencontre :
--   name      titre affiché
--   act       acte (nil = tous)           tier   palier de la Ligue des explorateurs (0..3)
--   rarity    "common" (ordinaire) | "rare" (poids faible) | "story" (une fois par compte)
--   weight    poids de tirage (défaut : Expedition.EVENT_WEIGHT selon rarity : 10 / 3 / 8)
--   once      true = une fois par compte (drapeau « event:<id> » posé à l'entrée) ; ou nom de drapeau
--   when      conditions de déclenchement (voir plus bas), toutes requises, évaluées à l'entrée du nœud
--   speaker   nom du personnage qui parle   npc   identifiant libre du personnage (modèle 3D)
--   scene     décor : farm | road | coast | mine | hill | camp | ruins
--   text      ce que dit ou voit le personnage (2 à 3 phrases)
--   choices   2 ou 3 réponses (plus une éventuelle réponse conditionnelle) :
--     label    bouton
--     outcome  ce que la réponse donne ou coûte, en clair (« +10 PV », « 50 % : 60 po, sinon -8 PV »)
--     hidden   true = l'interface affiche « ? » au lieu de outcome (rare : rencontres rares ou à histoire)
--     when     conditions : réponse affichée désactivée avec la raison si elles manquent
--     effects  liste d'effets (données)
--     result   texte affiché après le choix
--   (text et after sont recopiés de outcome et result pour l'interface d'origine.)
--
-- Conditions (Core/Expedition.lua, X.CONDITIONS) : { "hpBelow", 0.5 } PV < 50 % ;
--   { "hpAbove", 0.6 } PV >= 60 % ; { "gold", n } ; { "relic", id } ; { "noRelic", id } ;
--   { "potion" } une potion en poche ; { "card", id } ; { "key", n } clé mythique >= n ;
--   { "flag", nom } / { "noFlag", nom } drapeau de compte (connu au départ de l'expédition) ;
--   { "floor", n } étape >= n. Champ text = raison affichée à la place de celle par défaut.
--
-- Effets (données, interprétés par Core/Expedition.lua) :
--   { "heal", n }   { "healPct", f }   { "loseHp", n } (jamais sous 1 PV)
--   { "maxHp", n } +n PV max et +n PV      { "loseMaxHp", n } -n PV max (PV ramenés au max)
--   { "gold", n }   { "pay", n } (réponse désactivée sans l'or)   { "loseGold", n } (ce qu'on a)
--   { "card", id, up = b }   { "cardChoice", n = 3, rarity = "common" } (une parmi n, ou passer)
--   { "relic" } bibelot tiré   { "relic", id } bibelot précis (désactivé si déjà possédé)
--   { "potion" } potion tirée  { "potion", id } potion précise   { "losePotion" } (requiert une potion)
--   { "upgradeRandom", n }   { "upgrade" } / { "remove" } / { "dupe" } : carte au choix (sélection)
--   { "fight", groupe, kind = "combat"|"elite", gold = n } : combat (groupe de ns.Encounters de
--     l'acte, défaut selon kind), récompense habituelle du genre + n po
--   { "gamble", p, win = {effets}, lose = {effets}, winText, loseText } : pari tiré à l'entrée
--   { "flag", nom } : drapeau de compte, reporté dans la méta en fin d'expédition
-- Tout le hasard (cartes, bibelots, potions, récompense de combat, pari) est tiré à l'entrée
-- de la rencontre et stocké dans exp.event.rolls. Une réponse a au plus une suite interactive
-- (combat ou sélection de carte) ; une récompense de la même réponse s'ouvre après la sélection.
local _, ns = ...

ns.Events = ns.Events or {}
local E = ns.Events

local function event(id, t)
  t.rarity = t.rarity or "common"
  for _, ch in ipairs(t.choices) do
    ch.result = ch.result or ""
    ch.text = ch.hidden and "?" or ch.outcome
    ch.after = ch.result
  end
  E[id] = t
end

---------------------------------------------------------------------------
-- Ordinaires
---------------------------------------------------------------------------

event("saldean_farm", {
  name = "La ferme des Saldean", act = 1, tier = 0,
  speaker = "Salma Saldean", npc = "salma_saldean", scene = "farm",
  text = "« Vous avez l'air affamé, voyageur. Entrez donc, la marmite est encore chaude ! » "
    .. "Salma Saldean vous attend sur le seuil, une louche à la main.",
  choices = {
    { label = "Manger la soupe", outcome = "+10 PV",
      result = "Une soupe épaisse aux légumes du potager. Vous vous sentez revigoré.",
      effects = { { "heal", 10 } } },
    { label = "Apprendre sa recette", outcome = "Une carte commune parmi 3",
      result = "Salma vous confie le secret de son bouillon, griffonné au dos d'un vieux registre.",
      effects = { { "cardChoice", n = 3, rarity = "common" } } },
    { label = "Aider le fermier Saldean", outcome = "-5 PV, puis +5 PV max",
      result = "Une après-midi à arracher les mauvaises herbes. Dur, mais ça forge.",
      effects = { { "loseHp", 5 }, { "maxHp", 5 } } },
  },
})

event("defias_caravan", {
  name = "La carriole renversée", act = 1, tier = 0,
  speaker = "Le cocher", npc = "wagon_driver", scene = "road",
  text = "« À l'aide ! Ils prennent tout ! » Coincé sous sa carriole renversée sur la route de "
    .. "Ruisselune, le cocher vous supplie pendant que deux bandits défias éventrent ses caisses.",
  choices = {
    { label = "Charger les bandits", outcome = "Combat : récompense habituelle + 20 po",
      result = "Les bandits ne s'attendaient pas à vous.",
      effects = { { "fight", "normal", gold = 20 } } },
    { label = "Dégager le cocher", outcome = "-5 PV, une potion",
      result = "Vous soulevez la roue à la force des bras. Le cocher vous glisse une fiole en remerciement.",
      effects = { { "loseHp", 5 }, { "potion" } } },
    { label = "Passer son chemin", outcome = "Rien",
      result = "Ce n'est pas votre problème. Les cris s'éteignent derrière vous.",
      effects = {} },
  },
})

event("sentinel_hill", {
  name = "La Colline des sentinelles", act = 1, tier = 0,
  speaker = "Gryan Fortmanteau", npc = "gryan_stoutmantle", scene = "hill",
  text = "« On a besoin de bras. Et vous, vous avez besoin de quoi ? » Au pied de la tour, Gryan "
    .. "Fortmanteau vous jauge pendant que le Peuple de la Colline s'entraîne.",
  choices = {
    { label = "S'entraîner avec la milice", outcome = "-6 PV, améliore 2 cartes au hasard",
      result = "Des heures de passes d'armes avec les miliciens. Vos gestes sont plus sûrs.",
      effects = { { "loseHp", 6 }, { "upgradeRandom", 2 } } },
    { label = "Faire un don au Peuple", outcome = "Paie 40 po, retire une carte du deck",
      result = "Gryan hoche la tête. « Laissez-nous ce qui vous encombre, on en fera bon usage. »",
      effects = { { "pay", 40 }, { "remove" } } },
    { label = "Repartir", outcome = "Rien",
      result = "Vous saluez la garde et reprenez la route.",
      effects = {} },
    -- Réponse conditionnelle : le tabard de Hurlevent ouvre l'armurerie.
    { label = "Montrer son tabard de Hurlevent", outcome = "Une carte peu commune parmi 3",
      when = { { "relic", "stormwind_tabard" } },
      result = "Gryan reconnaît les couleurs du roi. « Un soldat de Hurlevent ? Prenez ce qu'il vous faut. »",
      effects = { { "cardChoice", n = 3, rarity = "uncommon" } } },
  },
})

event("coast_murlocs", {
  name = "Les nasses du vieux Hank", act = 1, tier = 0,
  speaker = "Vieux Hank", npc = "old_fisherman", scene = "coast",
  text = "« Ces maudits murlocs ont pris mon ponton, et mes nasses avec ! » Le vieux pêcheur "
    .. "brandit une gaffe tordue vers des silhouettes gluantes. « Mrglglgl », répond la plage.",
  choices = {
    { label = "Reprendre le ponton", outcome = "Combat contre 4 murlocs : récompense habituelle + 15 po",
      result = "Les murlocs détalent vers les vagues en gargouillant des injures.",
      effects = { { "fight", "event_murlocs", gold = 15 } } },
    { label = "Relever les nasses soi-même", outcome = "50 % : une potion et 20 po, sinon -7 PV",
      effects = { { "gamble", 0.5,
        win = { { "potion" }, { "gold", 20 } },
        winText = "Entre deux crabes, une fiole intacte et une bourse oubliée par un noyé.",
        lose = { { "loseHp", 7 } },
        loseText = "Une nasse cachait un murloc. Il vous mord avant de filer." } } },
    { label = "Partager sa friture", outcome = "+8 PV",
      result = "« Les murlocs, ça se mange pas. Le poisson, si. » Hank grommelle, mais il partage.",
      effects = { { "heal", 8 } } },
  },
})

event("jangolode_prospector", {
  name = "Le filon de la mine de Jango", act = 1, tier = 0,
  speaker = "Grenaille, chercheur d'or", npc = "gold_prospector", scene = "mine",
  text = "« Y a de l'or dans cette mine, je le sens dans mes genoux ! » Le vieux prospecteur vous "
    .. "tend une pioche émoussée. « Les Défias sont partis manger : c'est maintenant ou jamais. »",
  choices = {
    { label = "Piocher avec lui", outcome = "-8 PV, +45 po",
      result = "Des heures à genoux dans la poussière, mais la pépite est belle. Grenaille partage.",
      effects = { { "loseHp", 8 }, { "gold", 45 } } },
    { label = "Financer son filon", outcome = "Paie 30 po. 50 % : 80 po",
      effects = { { "pay", 30 }, { "gamble", 0.5,
        win = { { "gold", 80 } },
        winText = "Le filon tient ses promesses. Grenaille vous rembourse en riant.",
        lose = {},
        loseText = "Le filon s'arrête net contre la roche. « La prochaine fois, c'est sûr ! »" } } },
    { label = "Lui acheter sa flasque", outcome = "Paie 15 po, une potion",
      result = "« Un remontant de mineur. Ça réveille un mort, ou presque. »",
      effects = { { "pay", 15 }, { "potion" } } },
  },
})

event("moonbrook_refugees", {
  name = "Les réfugiés de Ruisselune", act = 1, tier = 1,
  speaker = "Mère Hanna", npc = "moonbrook_refugee", scene = "camp",
  text = "« Les Défias ont pris nos maisons, puis nos champs. » Autour d'un feu maigre, des "
    .. "familles de Ruisselune se serrent sous des couvertures trouées. « Si vous pouvez aider… »",
  choices = {
    { label = "Soigner les blessés", outcome = "-6 PV, améliore une carte au choix",
      result = "Vous soignez jusqu'à l'épuisement. Chaque prière vous apprend quelque chose.",
      effects = { { "loseHp", 6 }, { "upgrade" } } },
    { label = "Leur donner 35 po", outcome = "Paie 35 po, +6 PV max",
      result = "Mère Hanna vous bénit. Leurs prières vous accompagnent sur la route.",
      effects = { { "pay", 35 }, { "maxHp", 6 } } },
    { label = "Passer son chemin", outcome = "Rien",
      result = "Vous détournez les yeux et pressez le pas.",
      effects = {} },
    -- Réponse conditionnelle : il faut une potion à donner.
    { label = "Leur laisser une potion", outcome = "Perd une potion, améliore 2 cartes au hasard",
      when = { { "potion" } },
      result = "Un vieux prêtre de Ruisselune, guéri, prie avec vous jusqu'à l'aube.",
      effects = { { "losePotion" }, { "upgradeRandom", 2 } } },
  },
})

event("herbalist", {
  name = "La cueilleuse de pacifiques", act = 1, tier = 1,
  speaker = "Tante Mirelle", npc = "herbalist", scene = "road",
  -- N'apparaît que si l'on est mal en point.
  when = { { "hpBelow", 0.5 } },
  text = "« Par la Lumière, vous tenez à peine debout ! » Une herboriste pose son panier de "
    .. "pacifiques et de feuillargent. « Asseyez-vous. Mes remèdes ne sont pas gratuits, mais ils marchent. »",
  choices = {
    { label = "Payer ses remèdes", outcome = "Paie 25 po, soigne 35 % des PV max",
      result = "Le cataplasme brûle, puis apaise. Vous respirez mieux.",
      effects = { { "pay", 25 }, { "healPct", 0.35 } } },
    { label = "Cueillir avec elle", outcome = "+12 PV",
      result = "Une heure courbé dans les champs, à mâcher des feuilles amères. Ça aide.",
      effects = { { "heal", 12 } } },
  },
})

event("scarecrow_field", {
  name = "L'épouvantail qui grince", act = 1, tier = 2,
  speaker = "Fermier Molsen", npc = "farmer_molsen", scene = "farm",
  text = "« Il bouge la nuit, je vous dis ! Hier il était à l'autre bout du champ. » Le fermier "
    .. "Molsen montre un épouvantail aux coutures luisantes. « Brûlez-le, ou aidez-moi à déménager. »",
  choices = {
    { label = "Brûler l'épouvantail", outcome = "-5 PV, retire une carte du deck",
      result = "La paille s'embrase d'un coup. Vous y laissez quelques cheveux, et un vieux fardeau.",
      effects = { { "loseHp", 5 }, { "remove" } } },
    { label = "Fouiller sa paille", outcome = "-4 PV max, une carte rare parmi 3",
      result = "Sous la paille, un parchemin noirci par une magie qui vous mord les doigts.",
      effects = { { "loseMaxHp", 4 }, { "cardChoice", n = 3, rarity = "rare" } } },
    { label = "Le laisser grincer", outcome = "Rien",
      result = "Vous vous éloignez. Vous jureriez qu'il a tourné la tête.",
      effects = {} },
  },
})

event("lighthouse_keeper", {
  name = "Le gardien du phare", act = 1, tier = 2,
  speaker = "Gardien Alden", npc = "lighthouse_keeper", scene = "coast",
  -- Le phare est au bout de la côte : seulement après l'étape 4.
  when = { { "floor", 4 } },
  text = "« Le feu doit brûler toute la nuit, ou les navires s'éventreront sur les récifs. » "
    .. "Le gardien du phare tousse dans sa manche. « Et ces murlocs qui grattent à la porte… »",
  choices = {
    { label = "Garder le feu toute la nuit", outcome = "-10 PV, copie une carte du deck",
      result = "Toute la nuit à repousser les griffes sur l'escalier. À l'aube, vos gestes sont devenus des réflexes.",
      effects = { { "loseHp", 10 }, { "dupe" } } },
    { label = "Dormir dans la lanterne", outcome = "Soigne 30 % des PV max",
      result = "Bercé par le ressac et la chaleur du feu, vous dormez comme une pierre.",
      effects = { { "healPct", 0.30 } } },
  },
})

event("gnoll_raiders", {
  name = "Les maraudeurs Rivepatte", act = 1, tier = 3,
  speaker = "Grisgueule", npc = "riverpaw_gnoll", scene = "camp",
  -- Les meutes Rivepatte ne s'aventurent sur la route qu'à partir de la clé +2.
  when = { { "key", 2 } },
  text = "« Toi donner or. Ou toi donner sang. » Le chef de meute Rivepatte se gratte l'oreille "
    .. "avec un couteau rouillé, entouré de ses maraudeurs. « Grisgueule pas difficile. »",
  choices = {
    { label = "Affronter la meute", outcome = "Combat contre 3 gnolls : récompense habituelle + 30 po",
      result = "Grisgueule s'enfuit en glapissant, abandonnant son butin.",
      effects = { { "fight", "event_gnolls", gold = 30 } } },
    { label = "Payer le péage", outcome = "Paie 30 po",
      result = "Grisgueule mord la pièce, satisfait. « Toi passer. Toi revenir. »",
      effects = { { "pay", 30 } } },
    { label = "Fuir à travers champs", outcome = "-8 PV",
      result = "Les flèches sifflent. L'une d'elles trouve son chemin.",
      effects = { { "loseHp", 8 } } },
  },
})

---------------------------------------------------------------------------
-- Rares
---------------------------------------------------------------------------

event("goblin_peddler", {
  name = "La roulotte de Grisette", act = 1, tier = 1, rarity = "rare",
  speaker = "Grisette Vifcliquet", npc = "goblin_peddler", scene = "road",
  text = "« Pièces rares, prix uniques, aucun remboursement ! » Une gobeline vous fait signe depuis "
    .. "une roulotte bancale. « Cet engrenage sort d'un vrai moissonneur. Il ne demande qu'un peu… de vous. »",
  choices = {
    { label = "Prendre l'engrenage", outcome = "-8 PV max, Engrenage de moissonneur (bibelot)",
      result = "L'engrenage se loge contre votre cœur avec un déclic glacé. Grisette compte ses doigts, puis les vôtres.",
      effects = { { "loseMaxHp", 8 }, { "relic", "harvest_cog" } } },
    { label = "Jouer au bonneteau", outcome = "Paie 40 po. 50 % : 100 po",
      effects = { { "pay", 40 }, { "gamble", 0.5,
        win = { { "gold", 100 } },
        winText = "Vous suivez le gobelet sans ciller. Grisette grimace et paie.",
        lose = {},
        loseText = "Le gobelet était vide. Ils le sont toujours, à la réflexion." } } },
    { label = "Décliner poliment", outcome = "Rien",
      result = "« Votre cœur, votre choix ! » La roulotte repart en cahotant.",
      effects = {} },
  },
})

event("harvest_watcher", {
  name = "Le moissonneur endormi", act = 1, tier = 0, rarity = "rare",
  speaker = "Bricoleur Bertil", npc = "gnome_tinker", scene = "farm",
  -- Proposé seulement en bonne santé : la réponse principale est un combat d'élite.
  when = { { "hpAbove", 0.6 } },
  text = "« Pas un bruit ! » Un gnome caché dans le fenil vous fait signe. « Si le moissonneur se "
    .. "réveille, il nous fauche tous les deux. Mais le coffre qu'il garde… »",
  choices = {
    { label = "Réveiller le golem", outcome = "Combat d'élite : récompense d'élite + 40 po",
      result = "Les yeux du golem s'allument. Bertil plonge dans le foin.",
      effects = { { "fight", "event_golem", kind = "elite", gold = 40 } } },
    { label = "Crocheter le coffre en silence", outcome = "40 % : un bibelot, sinon -12 PV",
      effects = { { "gamble", 0.4,
        win = { { "relic" } },
        winText = "La serrure cède sans un bruit. Le golem ne bronche pas.",
        lose = { { "loseHp", 12 } },
        loseText = "Un ressort claque. Une faux vous frôle, puis ne vous frôle plus." } } },
    { label = "Ressortir sur la pointe des pieds", outcome = "Rien",
      result = "Bertil vous regarde partir, déçu.",
      effects = {} },
  },
})

---------------------------------------------------------------------------
-- À histoire : Tobin, en deux temps (une fois par compte chacun)
---------------------------------------------------------------------------

-- Premier temps : le choix fixe la suite (drapeau tobin_jailed ou tobin_spared).
event("tobin_thief", {
  name = "Le voleur de pain", act = 1, tier = 0, rarity = "story", once = true,
  speaker = "Tobin", npc = "tobin_young", scene = "farm",
  text = "Vous attrapez par le col un gamin maigre, les poches pleines de pain volé aux Saldean. "
    .. "« Lâchez-moi ! Les Défias disent qu'ils nourrissent ceux qui les rejoignent. Moi, j'ai juste faim. »",
  choices = {
    { label = "Le livrer à la milice", outcome = "+30 po. Il s'en souviendra.",
      result = "Gryan Fortmanteau vous compte la prime sans un regard pour le gamin. « Il apprendra. »",
      effects = { { "gold", 30 }, { "flag", "tobin_jailed" } } },
    { label = "Lui offrir un vrai repas", outcome = "Paie 20 po. Il s'en souviendra.",
      result = "Tobin dévore la miche, puis file vers la Colline des sentinelles. « Je vous revaudrai ça ! »",
      effects = { { "pay", 20 }, { "flag", "tobin_spared" } } },
    { label = "Le laisser filer", outcome = "Rien",
      result = "Il disparaît dans les blés. Vous ne saurez jamais ce qu'il est devenu.",
      effects = {} },
  },
})

-- Second temps, s'il a été nourri : retrouvé dans la milice. Débloque le Canif de Tobin.
event("tobin_scout", {
  name = "Le guetteur de la Colline", act = 1, tier = 0, rarity = "story", once = true,
  speaker = "Tobin, guetteur de la milice", npc = "tobin_scout", scene = "hill",
  when = { { "flag", "tobin_spared" } },
  text = "« Hé ! Vous vous souvenez de moi ? Le pain des Saldean ! » Tobin a grandi ; il porte le tabard "
    .. "de la milice et une arbalète trop grande pour lui. « J'ai gardé quelque chose pour vous. »",
  choices = {
    { label = "Accepter son canif", outcome = "Canif de Tobin (bibelot)",
      result = "« Je l'avais volé à un Défias. Il sera mieux chez vous. »",
      effects = { { "relic", "tobin_knife" } } },
    { label = "Lui demander ce qu'il sait des Défias", outcome = "Une carte rare parmi 3",
      result = "Tobin vous dessine dans la poussière les tunnels de la Confrérie, et leurs habitudes.",
      effects = { { "cardChoice", n = 3, rarity = "rare" } } },
  },
})

-- Second temps, s'il a été livré : il a rejoint la Confrérie.
event("tobin_defias", {
  name = "Le foulard rouge", act = 1, tier = 0, rarity = "story", once = true,
  speaker = "Tobin, coupe-jarret défias", npc = "tobin_defias", scene = "road",
  when = { { "flag", "tobin_jailed" } },
  text = "« La milice m'a gardé six mois au cachot. Les Défias, eux, m'ont ouvert la porte. » Le gamin "
    .. "que vous avez livré porte le foulard rouge, et deux sbires attendent son signal. « Votre bourse. »",
  choices = {
    { label = "Le combattre", outcome = "Combat contre Tobin et ses sbires : récompense habituelle + 25 po",
      result = "Tobin tire sa dague. Il a appris vite.",
      effects = { { "fight", "event_tobin", gold = 25 } } },
    { label = "Lui rendre la prime", outcome = "Paie 30 po",
      result = "Il soupèse la bourse, la vôtre d'abord, puis la sienne. « On est quittes. »",
      effects = { { "pay", 30 } } },
    -- La surprise fait l'intérêt : parler suffit, mais rien ne l'annonce.
    { label = "Lui parler du pain des Saldean", outcome = "Il baisse sa lame : rien à payer", hidden = true,
      result = "Il hésite, puis rengaine. « … Filez, avant que je change d'avis. »",
      effects = {} },
  },
})
