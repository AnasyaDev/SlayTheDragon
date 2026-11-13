# Rencontres de l'acte 1 — la Marche de l'Ouest

> **13/11/2026** : la Ligue des explorateurs est supprimée (`docs/zones.md`). Le champ `tier` est gardé : le
> « palier de Ligue » N de ce document se lit maintenant « première victoire du compte dans la zone d'ordre N »
> (0 = d'emblée) ; le champ `act = 1` des rencontres est devenu `zone = "westfall"`.

Étapes « Rencontre » de la carte. Données : `Data/Events.lua` ; moteur : `Core/Expedition.lua`
(section Rencontres) ; format et API : `docs/expedition.md`. Contenu original, ancré dans la Marche
de l'Ouest (Défias, Rivepatte, murlocs, fermes, Colline des sentinelles, Ruisselune, phare,
moissonneurs, chercheurs d'or).

## Règles de conception

- **Ce qui relève du jeu est annoncé.** Le texte reste une voix de personnage (2 à 3 phrases),
  mais chaque réponse porte un `outcome` court qui dit ce qu'elle donne ou coûte. Un pari annonce
  sa chance et ses deux issues. `hidden = true` (« ? ») est réservé à une réponse de rencontre à
  histoire dont la surprise fait l'intérêt (une seule aujourd'hui).
- **Rien de gratuit.** Chaque réponse coûte (PV, PV max, or, potion, risque) ou s'arbitre contre
  les autres de la même rencontre. Les deux réponses sans coût direct (suite de Tobin) ont été
  payées dans le premier temps de l'histoire.
- **Toujours une issue.** Chaque rencontre a au moins une réponse sans condition ni prérequis
  (testé) : on n'est jamais bloqué.
- **Tirages figés.** Cartes, bibelots, potions, récompense d'un combat et issue d'un pari sont
  tirés à l'entrée de la rencontre (flux `events`) et stockés dans `exp.event.rolls`.
- **PV hors combat** : jamais sous 1 ; les PV max jamais sous 1, les PV ramenés au maximum.
- **Écriture : registre des textes de quête de la VF.** Le personnage parle au joueur (vouvoiement,
  sauf parlers établis : gnolls, gobelins, kobolds, murlocs) : qui il est, ce qui se passe, ce qu'il
  demande. Les résultats disent ce qui s'est passé, simplement. Ni métaphore, ni personnification,
  ni chute, ni points de suspension dramatiques ; une phrase qui n'apporte ni fait ni demande saute.

## Familles et tirage

| Famille | Poids | Particularité |
| --- | --- | --- |
| `common` (ordinaire) | 10 | peut revenir d'une expédition à l'autre |
| `rare` | 3 | ≈ 3 à 4 % des expéditions chacune ; enjeu plus fort |
| `story` (à histoire) | 8 | une fois par compte (`once`), drapeau `event:<id>` posé à l'entrée |

Tirage pondéré parmi les rencontres possibles : acte, palier de Ligue (`tier`), pas encore vue
dans l'expédition (ni sur le compte pour une rencontre unique) et conditions `when` remplies à
l'entrée du nœud.

## Conditions

`when = { { "nom", arg }, ... }`, toutes requises. Pour une rencontre : elle n'est pas tirée.
Pour une réponse : elle reste affichée mais désactivée, avec la raison (`Expedition.eventOptions`).

| Condition | Vraie si | Raison affichée |
| --- | --- | --- |
| `hpBelow f` | PV < f × PV max | « Seulement sous 50 % des PV. » |
| `hpAbove f` | PV ≥ f × PV max | « Il faut au moins 60 % des PV. » |
| `gold n` | or ≥ n | « Il faut 60 po. » |
| `relic id` / `noRelic id` | bibelot possédé / absent | « Il faut : Tabard de Hurlevent. » |
| `potion` | au moins une potion | « Il faut une potion. » |
| `card id` | carte dans le deck | « Il faut la carte Pénitence. » |
| `key n` | clé mythique ≥ n | « Clé mythique +2 ou plus. » |
| `flag nom` / `noFlag nom` | drapeau de compte présent / absent | « Pas encore. » / « Plus maintenant. » |
| `floor n` | étape ≥ n | « À partir de l'étape 4. » |

`text = "..."` dans la condition remplace la raison. Les effets ont aussi leurs prérequis : `pay`
(or), `remove`/`dupe` (deck de 2 cartes ou plus), `upgrade` (une carte améliorable),
`losePotion` (une potion), `relic id` (pas déjà possédé).

## Liste

Notation : `-` perte, `+` gain ; « récompense habituelle » = celle d'un combat (or, 3 cartes,
35 % de potion ; élite : bibelot en plus).

### Ordinaires (10)

| Rencontre | Palier | Condition | Décor / personnage |
| --- | --- | --- | --- |
| `saldean_farm` La ferme des Saldean | 0 | — | farm, Salma Saldean |
| `defias_caravan` La carriole renversée | 0 | — | road, le cocher |
| `sentinel_hill` La Colline des sentinelles | 0 | réponse 4 : Tabard de Hurlevent | hill, Gryan Fortmanteau |
| `coast_murlocs` Les nasses du vieux Hank | 0 | — | coast, vieux Hank |
| `jangolode_prospector` Le filon de la mine de Jango | 0 | — | mine, Grenaille |
| `moonbrook_refugees` Les réfugiés de Ruisselune | 1 | réponse 4 : une potion | camp, Mère Hanna |
| `herbalist` La cueilleuse de pacifiques | 1 | PV < 50 % | road, Tante Mirelle |
| `scarecrow_field` L'épouvantail qui grince | 2 | — | farm, fermier Molsen |
| `lighthouse_keeper` Le gardien du phare | 2 | étape ≥ 4 | coast, gardien Alden |
| `gnoll_raiders` Les maraudeurs Rivepatte | 3 | clé ≥ +2 | camp, Grisgueule |

**La ferme des Saldean** — la halte réconfortante du début.
1. Manger le ragoût : +10 PV.
2. Apprendre sa recette : une carte commune parmi 3.
3. Aider le fermier : -5 PV puis +5 PV max.

**La carriole renversée** — le combat facultatif classique.
1. Charger les bandits : combat normal, récompense habituelle + 20 po.
2. Dégager le cocher : -5 PV, une potion.
3. Passer son chemin : rien.

**La Colline des sentinelles** — l'entraînement et le retrait payant ; le tabard ouvre l'armurerie.
1. S'entraîner : -6 PV, 2 cartes améliorées au hasard.
2. Donner à la milice : paie 40 po, retire une carte.
3. Repartir : rien.
4. *(Tabard de Hurlevent)* Montrer son tabard : une carte peu commune parmi 3.
Intention : récompenser un bibelot commun sans le rendre obligatoire.

**Les nasses du vieux Hank** — combat de murlocs, pari ou repas.
1. Reprendre le ponton : combat contre 4 murlocs, récompense habituelle + 15 po.
2. Relever les nasses : 50 % : une potion et 20 po, sinon -7 PV.
3. Partager sa friture : +8 PV.
Intention : le pari d'une rencontre ordinaire, petit et lisible.

**Le filon de la mine de Jango** — l'or, pour qui sait le dépenser.
1. Piocher avec lui : -8 PV, +45 po.
2. Financer son filon : paie 30 po ; 50 % : 80 po (espérance +10 po, variance forte).
3. Lui acheter sa flasque : paie 15 po, une potion.
Intention : convertir PV ou or ; la flasque est la potion la moins chère du jeu, mais on en a 3
emplacements.

**Les réfugiés de Ruisselune** — le prêtre qui donne de lui-même.
1. Soigner les blessés : -6 PV, améliore une carte au choix.
2. Leur donner 35 po : +6 PV max.
3. Passer son chemin : rien.
4. *(une potion)* Leur laisser une potion : perds une potion (le dernier emplacement occupé),
   2 cartes améliorées au hasard.

**La cueilleuse de pacifiques** *(PV < 50 %)* — une main tendue quand ça va mal.
1. Payer ses remèdes : paie 25 po, soigne 35 % des PV max.
2. Cueillir avec elle : +12 PV.
Intention : rattraper une expédition mal engagée sans effacer l'erreur (les deux soins restent
inférieurs à un feu de camp, sauf à payer).

**L'épouvantail qui grince** — purge ou savoir interdit.
1. Brûler l'épouvantail : -5 PV, retire une carte.
2. Fouiller sa paille : -4 PV max, une carte rare parmi 3.
3. Ne pas y toucher : rien.

**Le gardien du phare** *(étape ≥ 4)* — veille ou repos, avant le boss.
1. Garder le feu toute la nuit : -10 PV, copie une carte du deck.
2. Dormir au phare : soigne 30 % des PV max.
Intention : le choix « renforcer le deck ou arriver en forme » juste avant VanCleef.

**Les maraudeurs Rivepatte** *(clé ≥ +2)* — un péage, en clé mythique.
1. Affronter la meute : combat contre 2 gnolls et une mystique, récompense habituelle + 30 po.
2. Payer le péage : paie 30 po.
3. Fuir à travers champs : -8 PV.
Intention : une rencontre qui coûte, propre aux clés hautes (le combat reste rentable en forme).

### Rares (2)

**La roulotte de Grisette** (`goblin_peddler`, palier 1, road, Grisette Vifcliquet) — marché risqué.
1. Prendre l'engrenage : -8 PV max, **Engrenage de moissonneur** (bibelot propre : au premier
   tour de chaque combat, pioche 2 cartes de plus).
2. Jouer au bonneteau : paie 40 po ; 50 % : 100 po.
3. Décliner poliment : rien.
Intention : un bibelot fort hors du pool, payé en PV max ; un vrai pari d'or.

**Le moissonneur endormi** (`harvest_watcher`, palier 0, farm, Bricoleur Bertil, *PV ≥ 60 %*) —
combat d'élite optionnel.
1. Réveiller le golem : combat d'élite contre le Golem moissonneur, récompense d'élite + 40 po.
2. Crocheter le coffre : 40 % : un bibelot (tiré), sinon -12 PV.
3. Ressortir sur la pointe des pieds : rien.
Intention : proposée seulement en bonne santé ; en clé haute (Tyrannique) le combat devient un
vrai risque de mort, le crochetage prend le relais.

### À histoire : Tobin (une fois par compte, deux temps)

**Premier temps — Le voleur de pain** (`tobin_thief`, palier 0, farm, Tobin).
1. Le livrer à la milice : +30 po, drapeau `tobin_jailed`. « Il s'en souviendra. »
2. Lui offrir un vrai repas : paie 20 po, drapeau `tobin_spared`. « Il s'en souviendra. »
3. Le laisser filer : rien (pas de suite).

**Second temps (expédition suivante ou plus tard)**, selon le drapeau :

*Le guetteur de la Colline* (`tobin_scout`, *drapeau `tobin_spared`*, hill) — Tobin a rejoint la
milice.
1. Accepter son canif : **Canif de Tobin** (bibelot propre : au début de chaque combat, Douleur 3
   à tous les ennemis).
2. Lui demander ce qu'il sait des Défias : une carte rare parmi 3.
Débloque un bibelot qu'on ne trouve nulle part ailleurs.

*Le foulard rouge* (`tobin_defias`, *drapeau `tobin_jailed`*, road) — Tobin a rejoint les Défias.
1. Le combattre : combat contre un bandit et deux sbires, récompense habituelle + 25 po.
2. Lui rendre la prime : paie 30 po.
3. Lui parler du pain des Saldean : **cachée** (« ? ») — il baisse sa lame, rien à payer.
La réponse cachée récompense l'empathie ; comme la rencontre n'arrive qu'une fois, la surprise
ne s'use pas.

Chaque temps est unique sur le compte (drapeaux `event:tobin_thief`, `event:tobin_scout`,
`event:tobin_defias`). Le premier temps « vu » compte même si l'on abandonne l'expédition.

## Décisions

- **Drapeaux posés en fin d'expédition** (`Meta.record`), pas immédiatement : le cœur ne touche pas
  à la méta pendant l'expédition, et une suite n'apparaît jamais dans l'expédition qui l'a
  débloquée. Abandon et défaite reportent aussi les drapeaux. Une expédition mise en quarantaine
  (illisible) perd les siens, comme sa réputation.
- **« Vue » = entrée dans la rencontre** pour les uniques : impossible de la refuser pour la revoir.
- **Pari tiré à l'entrée, issue cachée** dans l'état (`rolls`) : l'interface ne doit pas l'afficher
  avant le choix. Le bot de simulation ne la lit pas non plus (il joue l'espérance).
- **Une suite interactive par réponse** (combat ou sélection) ; l'or d'une réponse à combat
  s'ajoute à la récompense du combat, une récompense d'une réponse à sélection s'ouvre après.
- **Combats de rencontre** : groupes `event_*` dans `ns.Encounters.act1` (`Data/Act1.lua`) ;
  récompense tirée à l'entrée de la rencontre comme un combat de la carte. Le combat optionnel
  d'élite compte comme une élite (réputation, statistiques).
- **`losePotion`** retire la potion du dernier emplacement occupé (pas de hasard caché).
- **Texte** : les chiffres sont écrits avec un tiret ASCII (« -6 PV ») ; le signe moins Unicode
  n'est pas garanti dans les polices du client.
- **Paliers** : 5 ordinaires et 4 rencontres spéciales au palier 0 (les deux temps de Tobin et le
  moissonneur), puis 2 ordinaires + 1 rare au palier 1, 2 au palier 2, 1 au palier 3.
- **Simulation** : `meta=start` = compte neuf (premier temps de Tobin possible à chaque
  expédition, ce qui le surreprésente) ; `meta=exalted` = compte vétéran (premier temps vu, branche
  `tobin_spared` ou `tobin_jailed` selon la parité de la graine, `Sim/expedition.lua`
  `SE.VETERAN_*`).

## Mesures

`luajit Sim/sim.lua runs=2000 jobs=8 runner=expedition bot=heuristic key=N meta=M` (graine 1,
intervalle ≈ ±2 points). « Avant » = 3 rencontres et l'ancien bot (commit 8f8ce26) ; « après » =
15 rencontres et le bot hors combat mis à jour.

| Clé | Méta | Victoires avant | Victoires après | Écart |
| --- | --- | --- | --- | --- |
| +0 | start | 72,3 % | 71,0 % | −1,3 |
| +0 | exalted | 71,8 % | 74,5 % | +2,7 |
| +3 | start | 24,1 % | 23,4 % | −0,7 |
| +3 | exalted | 24,8 % | 25,1 % | +0,3 |

Fréquence (vues pour 100 expéditions) et écart de victoire avec / sans la rencontre. L'écart
n'est **pas** un effet causal : il mélange l'effet de la rencontre et celui du chemin qui y mène (une
expédition qui croise l'herboriste est par construction en difficulté, une qui atteint le phare a
passé l'étape 4). Il sert à repérer les extrêmes.

| Rencontre | +0 start | +0 exalted | +3 start | +3 exalted |
| --- | --- | --- | --- | --- |
| saldean_farm | 17,9 / +7,8 | 12,0 / +4,9 | 15,9 / +8,0 | 9,3 / +2,9 |
| defias_caravan | 17,9 / −7,9 | 11,8 / −13,0 | 16,2 / +4,1 | 9,2 / −3,0 |
| sentinel_hill | 18,9 / +5,0 | 12,3 / +12,1 | 16,4 / +5,0 | 10,2 / +16,2 |
| coast_murlocs | 18,2 / +0,5 | 11,4 / +1,2 | 16,9 / +5,0 | 9,9 / +5,7 |
| jangolode_prospector | 17,9 / +1,6 | 12,0 / +3,5 | 15,8 / +3,2 | 10,0 / +0,4 |
| moonbrook_refugees | — | 12,2 / −3,4 | — | 9,8 / +2,2 |
| herbalist | — | 2,4 / +2,7 | — | 3,2 / +16,9 |
| scarecrow_field | — | 12,1 / −1,1 | — | 9,9 / +2,9 |
| lighthouse_keeper | — | 7,6 / +4,9 | — | 5,0 / +23,5 |
| gnoll_raiders | — | — | — | 8,9 / −12,2 |
| goblin_peddler (rare) | — | 3,2 / −4,3 | — | 3,3 / −2,5 |
| harvest_watcher (rare) | 3,9 / −4,6 | 2,5 / −18,0 | 3,0 / −6,6 | 1,8 / −11,5 |
| tobin_thief (histoire) | 14,7 / −3,5 | — | 13,9 / +0,8 | — |
| tobin_scout (histoire) | — | 4,7 / +15,6 | — | 4,0 / +23,3 |
| tobin_defias (histoire) | — | 4,9 / +5,4 | — | 4,1 / −2,1 |

Réglages faits pendant la mesure :
- Première version : −4,3 points à +0 start et −4,7 à +3 start. Cause : les nouvelles rencontres
  du palier 0 donnaient surtout de l'or, qui dort (≈ 165 po restants en fin d'expédition faute de
  marchand sur 60 % des chemins), et diluaient la Colline (2 améliorations) et la soupe des
  Saldean. Correctifs : « Partager sa friture » (+8 PV) remplace « rien » chez Hank, « Lui
  acheter sa flasque » (15 po, une potion) remplace « rien » chez Grenaille, poids des histoires
  12 → 8.
- Bot : un combat de rencontre vaut sa récompense moins les PV perdus mesurés (15 / 20 à +0,
  20 / 35 à +3) et un risque croissant avec la clé ; sans cela il réveillait le golem à +3 (3 %
  de victoires avec) et affrontait les gnolls à chaque fois.
- À surveiller : le combat d'élite optionnel du moissonneur reste défavorable au bot à +0 (écart
  −5 à −18, 50 à 80 expéditions) : les bibelots tirables au palier 0 sont faibles. Si le pool de
  bibelots grandit, re-mesurer avant de toucher la récompense.

Chiffres annexes à +0 start : or gagné 156 (avant 152), améliorations 0,55 par expédition (avant
0,92 : la Colline est moins fréquente), réputation 111,9 (111,8).
