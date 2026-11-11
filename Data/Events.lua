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
  text = "« Vous avez l'air affamé, voyageur. Entrez donc, il reste du ragoût ! Et si vous avez "
    .. "un moment, mon mari aurait besoin d'aide aux champs. »",
  choices = {
    { label = "Manger le ragoût", outcome = "+10 PV",
      result = "Salma vous sert un bol de ragoût. Vous repartez reposé.",
      effects = { { "heal", 10 } } },
    { label = "Apprendre sa recette", outcome = "Une carte commune parmi 3",
      result = "Salma vous recopie sa recette de ragoût au dos d'un vieux registre.",
      effects = { { "cardChoice", n = 3, rarity = "common" } } },
    { label = "Aider le fermier Saldean", outcome = "-5 PV, puis +5 PV max",
      result = "Vous désherbez les champs tout l'après-midi et en sortez endurci.",
      effects = { { "loseHp", 5 }, { "maxHp", 5 } } },
  },
})

event("defias_caravan", {
  name = "La carriole renversée", act = 1, tier = 0,
  speaker = "Le cocher", npc = "wagon_driver", scene = "road",
  text = "« À l'aide ! Des bandits défias ont renversé ma carriole sur la route de Ruisselune, et je "
    .. "suis coincé dessous. Ils pillent mes caisses ! »",
  choices = {
    { label = "Charger les bandits", outcome = "Combat : récompense habituelle + 20 po",
      result = "Vous attaquez les bandits défias.",
      effects = { { "fight", "normal", gold = 20 } } },
    { label = "Dégager le cocher", outcome = "-5 PV, une potion",
      result = "Vous soulevez la carriole et libérez le cocher. Il vous donne une potion en remerciement.",
      effects = { { "loseHp", 5 }, { "potion" } } },
    { label = "Passer son chemin", outcome = "Rien",
      result = "Vous laissez le cocher et reprenez la route.",
      effects = {} },
  },
})

event("sentinel_hill", {
  name = "La Colline des sentinelles", act = 1, tier = 0,
  speaker = "Gryan Fortmanteau", npc = "gryan_stoutmantle", scene = "hill",
  text = "« La milice du peuple défend la Marche de l'Ouest contre les Défias, et nous manquons de "
    .. "tout. Si vous voulez nous aider, vous êtes le bienvenu. »",
  choices = {
    { label = "S'entraîner avec la milice", outcome = "-6 PV, améliore 2 cartes au hasard",
      result = "Vous vous entraînez des heures avec les miliciens et progressez.",
      effects = { { "loseHp", 6 }, { "upgradeRandom", 2 } } },
    { label = "Donner à la milice", outcome = "Paie 40 po, retire une carte du deck",
      result = "« Merci. Laissez-nous aussi ce qui vous encombre, la milice en fera bon usage. »",
      effects = { { "pay", 40 }, { "remove" } } },
    { label = "Repartir", outcome = "Rien",
      result = "Vous saluez la garde et reprenez la route.",
      effects = {} },
    -- Réponse conditionnelle : le tabard de Hurlevent ouvre l'armurerie.
    { label = "Montrer son tabard de Hurlevent", outcome = "Une carte peu commune parmi 3",
      when = { { "relic", "stormwind_tabard" } },
      result = "Gryan reconnaît le tabard. « Un soldat de Hurlevent ? Servez-vous à l'armurerie. »",
      effects = { { "cardChoice", n = 3, rarity = "uncommon" } } },
  },
})

event("coast_murlocs", {
  name = "Les nasses du vieux Hank", act = 1, tier = 0,
  speaker = "Vieux Hank", npc = "old_fisherman", scene = "coast",
  text = "« Ces maudits murlocs ont pris mon ponton, et mes nasses avec ! Chassez-les de là, ou "
    .. "allez relever mes nasses vous-même. Moi, je suis trop vieux pour ça. »",
  choices = {
    { label = "Reprendre le ponton", outcome = "Combat contre 4 murlocs : récompense habituelle + 15 po",
      result = "Vous attaquez les murlocs du ponton.",
      effects = { { "fight", "event_murlocs", gold = 15 } } },
    { label = "Relever les nasses soi-même", outcome = "50 % : une potion et 20 po, sinon -7 PV",
      effects = { { "gamble", 0.5,
        win = { { "potion" }, { "gold", 20 } },
        winText = "Dans les nasses, vous trouvez une potion intacte et une bourse.",
        lose = { { "loseHp", 7 } },
        loseText = "Une nasse cachait un murloc. Il vous mord avant de filer." } } },
    { label = "Partager sa friture", outcome = "+8 PV",
      result = "Hank partage sa friture avec vous. « Mangez, ça vous remettra d'aplomb. »",
      effects = { { "heal", 8 } } },
  },
})

event("jangolode_prospector", {
  name = "Le filon de la mine de Jango", act = 1, tier = 0,
  speaker = "Grenaille, chercheur d'or", npc = "gold_prospector", scene = "mine",
  text = "« Il reste de l'or dans cette mine, j'en suis sûr ! Les Défias sont partis manger. "
    .. "Aidez-moi à creuser, ou financez mon filon, et on partage. »",
  choices = {
    { label = "Piocher avec lui", outcome = "-8 PV, +45 po",
      result = "Vous creusez des heures et trouvez une pépite. Grenaille partage avec vous.",
      effects = { { "loseHp", 8 }, { "gold", 45 } } },
    { label = "Financer son filon", outcome = "Paie 30 po. 50 % : 80 po",
      effects = { { "pay", 30 }, { "gamble", 0.5,
        win = { { "gold", 80 } },
        winText = "Grenaille trouve de l'or et vous rembourse largement.",
        lose = {},
        loseText = "Grenaille ne trouve rien. « La prochaine fois, c'est sûr ! »" } } },
    { label = "Lui acheter sa flasque", outcome = "Paie 15 po, une potion",
      result = "« Un remontant de mineur. Buvez-le quand ça va mal. »",
      effects = { { "pay", 15 }, { "potion" } } },
  },
})

event("moonbrook_refugees", {
  name = "Les réfugiés de Ruisselune", act = 1, tier = 1,
  speaker = "Mère Hanna", npc = "moonbrook_refugee", scene = "camp",
  text = "« Les Défias nous ont chassés de Ruisselune. Nous avons des blessés, et plus rien pour "
    .. "les soigner ni pour nous nourrir. Toute aide sera la bienvenue. »",
  choices = {
    { label = "Soigner les blessés", outcome = "-6 PV, améliore une carte au choix",
      result = "Vous passez la journée à soigner les blessés. Vous y gagnez en expérience.",
      effects = { { "loseHp", 6 }, { "upgrade" } } },
    { label = "Leur donner 35 po", outcome = "Paie 35 po, +6 PV max",
      result = "Mère Hanna vous remercie et prie la Lumière de vous protéger.",
      effects = { { "pay", 35 }, { "maxHp", 6 } } },
    { label = "Passer son chemin", outcome = "Rien",
      result = "Vous reprenez la route sans vous arrêter.",
      effects = {} },
    -- Réponse conditionnelle : il faut une potion à donner.
    { label = "Leur laisser une potion", outcome = "Perd une potion, améliore 2 cartes au hasard",
      when = { { "potion" } },
      result = "La potion guérit un vieux prêtre. Il vous apprend ses prières.",
      effects = { { "losePotion" }, { "upgradeRandom", 2 } } },
  },
})

event("herbalist", {
  name = "La cueilleuse de pacifiques", act = 1, tier = 1,
  speaker = "Tante Mirelle", npc = "herbalist", scene = "road",
  -- N'apparaît que si l'on est mal en point.
  when = { { "hpBelow", 0.5 } },
  text = "« Par la Lumière, vous tenez à peine debout ! Asseyez-vous. Mes remèdes ne sont pas gratuits, "
    .. "mais ils marchent. Sinon, aidez-moi à cueillir mes pacifiques. »",
  choices = {
    { label = "Payer ses remèdes", outcome = "Paie 25 po, soigne 35 % des PV max",
      result = "Tante Mirelle pose un cataplasme sur vos plaies.",
      effects = { { "pay", 25 }, { "healPct", 0.35 } } },
    { label = "Cueillir avec elle", outcome = "+12 PV",
      result = "Vous cueillez avec elle, en mâchant les feuilles qu'elle vous donne.",
      effects = { { "heal", 12 } } },
  },
})

event("scarecrow_field", {
  name = "L'épouvantail qui grince", act = 1, tier = 2,
  speaker = "Fermier Molsen", npc = "farmer_molsen", scene = "farm",
  text = "« Cet épouvantail bouge la nuit, je vous dis ! Hier, il était à l'autre bout du champ. "
    .. "C'est sûrement un sortilège des Défias. Brûlez-le, s'il vous plaît. »",
  choices = {
    { label = "Brûler l'épouvantail", outcome = "-5 PV, retire une carte du deck",
      result = "La paille s'enflamme d'un coup et vous brûle les mains. Molsen vous remercie.",
      effects = { { "loseHp", 5 }, { "remove" } } },
    { label = "Fouiller sa paille", outcome = "-4 PV max, une carte rare parmi 3",
      result = "Vous trouvez dans la paille un parchemin défias. Sa magie vous affaiblit.",
      effects = { { "loseMaxHp", 4 }, { "cardChoice", n = 3, rarity = "rare" } } },
    { label = "Ne pas y toucher", outcome = "Rien",
      result = "Vous laissez le fermier Molsen à son épouvantail.",
      effects = {} },
  },
})

event("lighthouse_keeper", {
  name = "Le gardien du phare", act = 1, tier = 2,
  speaker = "Gardien Alden", npc = "lighthouse_keeper", scene = "coast",
  -- Le phare est au bout de la côte : seulement après l'étape 4.
  when = { { "floor", 4 } },
  text = "« Le feu doit rester allumé toute la nuit, ou les navires s'échoueront sur les récifs. "
    .. "Je suis malade et les murlocs rôdent. Pouvez-vous veiller à ma place ? »",
  choices = {
    { label = "Garder le feu toute la nuit", outcome = "-10 PV, copie une carte du deck",
      result = "Vous repoussez les murlocs dans l'escalier du phare jusqu'à l'aube. Le feu reste allumé.",
      effects = { { "loseHp", 10 }, { "dupe" } } },
    { label = "Dormir au phare", outcome = "Soigne 30 % des PV max",
      result = "Alden vous laisse un lit près du feu. Vous dormez jusqu'au matin.",
      effects = { { "healPct", 0.30 } } },
  },
})

event("gnoll_raiders", {
  name = "Les maraudeurs Rivepatte", act = 1, tier = 3,
  speaker = "Grisgueule", npc = "riverpaw_gnoll", scene = "camp",
  -- Les meutes Rivepatte ne s'aventurent sur la route qu'à partir de la clé +2.
  when = { { "key", 2 } },
  text = "« Toi donner or. Ou toi donner sang. » Grisgueule et ses maraudeurs Rivepatte vous "
    .. "barrent la route. « Grisgueule pas difficile. »",
  choices = {
    { label = "Affronter la meute", outcome = "Combat contre 3 gnolls : récompense habituelle + 30 po",
      result = "Vous attaquez la meute de Grisgueule.",
      effects = { { "fight", "event_gnolls", gold = 30 } } },
    { label = "Payer le péage", outcome = "Paie 30 po",
      result = "Grisgueule mord la pièce, satisfait. « Toi passer. Toi revenir. »",
      effects = { { "pay", 30 } } },
    { label = "Fuir à travers champs", outcome = "-8 PV",
      result = "Vous fuyez à travers champs. Une flèche vous touche.",
      effects = { { "loseHp", 8 } } },
  },
})

---------------------------------------------------------------------------
-- Rares
---------------------------------------------------------------------------

event("goblin_peddler", {
  name = "La roulotte de Grisette", act = 1, tier = 1, rarity = "rare",
  speaker = "Grisette Vifcliquet", npc = "goblin_peddler", scene = "road",
  text = "« Pièces rares, prix uniques, aucun remboursement ! Cet engrenage vient d'un vrai golem "
    .. "moissonneur. Il marche à merveille, mais il prend un peu de votre santé, l'ami. »",
  choices = {
    { label = "Prendre l'engrenage", outcome = "-8 PV max, Engrenage de moissonneur (bibelot)",
      result = "Grisette vous fixe l'engrenage sur la poitrine. Vous vous sentez aussitôt affaibli.",
      effects = { { "loseMaxHp", 8 }, { "relic", "harvest_cog" } } },
    { label = "Jouer au bonneteau", outcome = "Paie 40 po. 50 % : 100 po",
      effects = { { "pay", 40 }, { "gamble", 0.5,
        win = { { "gold", 100 } },
        winText = "Vous trouvez le bon gobelet. Grisette grimace et paie.",
        lose = {},
        loseText = "Le gobelet est vide. Grisette empoche votre or." } } },
    { label = "Décliner poliment", outcome = "Rien",
      result = "« Tant pis pour vous ! » Grisette repart avec sa roulotte.",
      effects = {} },
  },
})

event("harvest_watcher", {
  name = "Le moissonneur endormi", act = 1, tier = 0, rarity = "rare",
  speaker = "Bricoleur Bertil", npc = "gnome_tinker", scene = "farm",
  -- Proposé seulement en bonne santé : la réponse principale est un combat d'élite.
  when = { { "hpAbove", 0.6 } },
  text = "« Pas un bruit ! Ce golem moissonneur garde un coffre. S'il se réveille, il nous "
    .. "attaquera tous les deux. Vous savez crocheter une serrure ? »",
  choices = {
    { label = "Réveiller le golem", outcome = "Combat d'élite : récompense d'élite + 40 po",
      result = "Les yeux du golem s'allument. Bertil plonge dans le foin.",
      effects = { { "fight", "event_golem", kind = "elite", gold = 40 } } },
    { label = "Crocheter le coffre en silence", outcome = "40 % : un bibelot, sinon -12 PV",
      effects = { { "gamble", 0.4,
        win = { { "relic" } },
        winText = "Le coffre s'ouvre sans bruit. Le golem dort toujours.",
        lose = { { "loseHp", 12 } },
        loseText = "La serrure claque. Le golem se réveille et vous frappe." } } },
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
      result = "Tobin s'enfuit dans les champs de blé.",
      effects = {} },
  },
})

-- Second temps, s'il a été nourri : retrouvé dans la milice. Débloque le Canif de Tobin.
event("tobin_scout", {
  name = "Le guetteur de la Colline", act = 1, tier = 0, rarity = "story", once = true,
  speaker = "Tobin, guetteur de la milice", npc = "tobin_scout", scene = "hill",
  when = { { "flag", "tobin_spared" } },
  text = "« Hé ! Vous vous souvenez de moi ? Le pain des Saldean ! Je suis guetteur dans la milice "
    .. "du peuple, maintenant. J'ai gardé quelque chose pour vous. »",
  choices = {
    { label = "Accepter son canif", outcome = "Canif de Tobin (bibelot)",
      result = "« Je l'avais volé à un Défias. Il sera mieux chez vous. »",
      effects = { { "relic", "tobin_knife" } } },
    { label = "Lui demander ce qu'il sait des Défias", outcome = "Une carte rare parmi 3",
      result = "Tobin vous dessine le plan des tunnels défias et vous explique leurs habitudes.",
      effects = { { "cardChoice", n = 3, rarity = "rare" } } },
  },
})

-- Second temps, s'il a été livré : il a rejoint la Confrérie.
event("tobin_defias", {
  name = "Le foulard rouge", act = 1, tier = 0, rarity = "story", once = true,
  speaker = "Tobin, coupe-jarret défias", npc = "tobin_defias", scene = "road",
  when = { { "flag", "tobin_jailed" } },
  text = "« Vous vous souvenez de moi ? La milice m'a gardé six mois au cachot. Ce sont les Défias "
    .. "qui m'en ont sorti. Maintenant, donnez-moi votre bourse. »",
  choices = {
    { label = "Le combattre", outcome = "Combat contre Tobin et ses sbires : récompense habituelle + 25 po",
      result = "Tobin et ses sbires vous attaquent.",
      effects = { { "fight", "event_tobin", gold = 25 } } },
    { label = "Lui rendre la prime", outcome = "Paie 30 po",
      result = "Tobin prend la bourse. « On est quittes. »",
      effects = { { "pay", 30 } } },
    -- La surprise fait l'intérêt : parler suffit, mais rien ne l'annonce.
    { label = "Lui parler du pain des Saldean", outcome = "Il baisse sa lame : rien à payer", hidden = true,
      result = "Tobin range sa dague. « Filez, avant que je change d'avis. »",
      effects = {} },
  },
})
