# Westfall — fiche de zone (zone 1, id `westfall`)

Cas particulier : la zone existe déjà (`Data/Act1.lua`, `Data/Events.lua`, boss Edwin VanCleef). Cette fiche
ne change aucun chiffre. Elle fait l'état des lieux, relève ce qui n'est pas de la Marche de l'Ouest et
propose un remplaçant, puis définit les récompenses de la zone : 5 cartes de zone (une par classe), le commun
de la première victoire du compte, 3 bibelots de clé, et les fonds de scène possibles.

Sources des identifiants : `wow_creature_search` et `wow_texture_export` répondent « No World of Warcraft
install found » (aucune installation lisible par le MCP, synchronisation non lancée, consigne). Les
identifiants de créature et d'affichage viennent donc du cache du client Forever
(`Cache/WDB/enUS|frFR/creaturecache.wdb`, lu par `tools/wdb_creatures.py`, lecture seule) : il ne contient que
les créatures déjà croisées en jeu. Une créature absente du cache est notée « non trouvé », sans identifiant.
Icônes et fichiers : `wow_icon_search` / `wow_file_search` (liste de fichiers retail 12.1.5, interface seule).

## 1. État des lieux

### Ennemis (tirés de `Data/Act1.lua`)

| id | Nom | PV | Intentions (actions) | Motif | Rôle | De la Marche ? |
|---|---|---|---|---|---|---|
| `gnoll` | Riverpaw Gnoll | 19–22 | Bite : 8 · Rend : 5 + Sundered 1 sur le joueur | Bite, Rend en alternance, départ au hasard | frappeur de base | oui |
| `mystic` | Riverpaw Mystic | 15–17 | Watch : interrompt l'incantation du joueur, sinon 3 · Heal : soigne 6 un allié · Shock : 5 | IA : Watch si le joueur a une carte Cast en main ; sinon Heal si un allié a perdu 6 PV ou plus (pas deux fois de suite) ; sinon Shock | soigneur, punit le Cast | oui |
| `murloc` | Murloc Coastrunner | 10–12 | Claw : 4 | Claw ; +1 Strength quand un autre murloc meurt | meute (2 à 4) | oui |
| `bandit` | Defias Bandit | 25–28 | Kick : 5, interrompt · Guard : Absorb 8 · Flurry : 5 × 2 | Kick, Guard, Flurry, départ au hasard | tank léger, coupe le Cast | **non (Elwynn)** |
| `sorcerer` | Defias Conjurer | 18–21 | Fireball : Cast, 16 · Frost Shards : 4, interrompt | Fireball, Frost Shards, départ au hasard | lanceur à interrompre | oui |
| `defias_henchman` | Defias Henchman | 11–13 | Stab : 5 | Stab | sbire invoqué par le boss | oui |

| Élite | PV | Intentions | Motif | De la Marche ? |
|---|---|---|---|---|
| Harvest Golem | 72 | Harden : Absorb 12 · Smash : 19, interrompt · Reap : 8 × 3 | Harden, Smash, Reap | oui |
| Rhahk'Zor | 75 | Roar : 7 + Demoralized 2 sur le joueur · Slam : 18, interrompt · Punch : 12 | Roar, Slam, Punch, Slam | oui (Mortemines) |

| Boss | PV | Intentions | Motif | Phase |
|---|---|---|---|---|
| Edwin VanCleef | 92 | Combo : 11 × 2 + Sundered 1 · Kick : 9, interrompt · Mortal Strike : 23 · Parry : Absorb 12 + Strength 3 | Combo, Kick, Mortal Strike, Parry | à 50 % des PV (46) : « To me, Brotherhood! », 2 Defias Henchman |

Groupes (`ns.Encounters.act1`) :

| Genre | Compositions |
|---|---|
| easy | 2 Gnolls · 3 Murlocs · 1 Bandit · Conjurer + Murloc |
| normal | 2 Gnolls + Mystic · 4 Murlocs · Bandit + Conjurer · Bandit + Gnoll · Gnoll + Conjurer + Mystic |
| elite | Harvest Golem · Rhahk'Zor |
| boss | Edwin VanCleef |
| rencontres | `event_murlocs` 4 Murlocs · `event_gnolls` 2 Gnolls + Mystic · `event_golem` Harvest Golem · `event_tobin` Bandit + 2 Henchmen |

Bibelots déjà liés à la zone (à ne pas doubler) : Defias Purse, VanCleef's Red Bandana (boss), Harvest Golem Cog
et Tobin's Pocketknife (rencontres). Cartes neutres déjà liées : Rough Dynamite, Smoked Desert Dumplings, Heavy
Silk Bandage, Arcane Bomb, Iron Grenade (données par les rencontres).

### Rencontres (tirées de `Data/Events.lua`)

| id | Titre | Palier | Personnage | Modèle (`UI/Art.lua`) | Décor |
|---|---|---|---|---|---|
| `saldean_farm` | The Saldean Farm | 0 | Salma Saldean | Salma Saldean 235 | farm |
| `defias_caravan` | The Overturned Wagon | 0 | The wagon driver (inventé) | Brog Hamfist 151 | road |
| `sentinel_hill` | Sentinel Hill | 0 | Gryan Stoutmantle | Gryan Stoutmantle 234 | hill |
| `coast_murlocs` | Old Hank's Traps | 0 | Old Hank (inventé) | Lee Brown 1651 | coast |
| `jangolode_prospector` | The Jangolode Vein | 0 | Grit (inventé) | Prospector Stormpike 1356 | mine |
| `moonbrook_refugees` | The Moonbrook Refugees | 1 | Mother Hanna (inventée) | Ma Stonefield 244 | camp |
| `herbalist` | The Peacebloom Picker | 1 | Aunt Mirelle (inventée) | Alma Jainrose 812 | road |
| `scarecrow_field` | The Creaking Scarecrow | 2 | Farmer Molsen (d'après la ferme Molsen) | Farmer Ray 232 | farm |
| `lighthouse_keeper` | The Lighthouse Keeper | 2 | Keeper Alden (inventé) | Dockmaster Baren 381 | coast |
| `gnoll_raiders` | The Riverpaw Raiders | 3 | Graymaw (inventé) | Riverpaw Taskmaster 98 | camp |
| `goblin_peddler` | Grizzle's Wagon (rare) | 1 | Grizzle Quickclick (inventée) | Zixil 3537 | road |
| `harvest_watcher` | The Sleeping Harvester (rare) | 0 | Tinker Bertil (inventé) | Deek Fizzlebizz 3290 | farm |
| `tobin_thief` | The Bread Thief (histoire) | 0 | Tobin (inventé) | Tommy Joe Stonefield 252 | farm |
| `tobin_scout` | The Hill Lookout (histoire) | 0 | Tobin, militia lookout | Scout Riell 820 | hill |
| `tobin_defias` | The Red Kerchief (histoire) | 0 | Tobin, Defias cutthroat | Defias Cutpurse 94 | road |

Les lieux nommés dans les textes sont tous de la Marche (Moonbrook, Sentinel Hill, Jangolode, ferme des
Saldean, ferme Molsen, phare, les Mortemines). Le tabard de Hurlevent et la peacebloom ne sont pas propres à
Elwynn : rien à changer.

### Ce qui n'est pas de la Marche de l'Ouest, et le remplaçant proposé

Précision sur les gnolls : les Riverpaw du code (Riverpaw Gnoll 117, Riverpaw Mystic 453, Riverpaw Taskmaster
98 en modèle) sont des gnolls de la Marche. Ceux d'Elwynn sont Hogger, Riverpaw Runt et Riverpaw Outrunner ;
aucun n'est dans le code. Les chiffres ne changent pas : seuls le nom affiché et le modèle changent.

| Élément actuel | Origine | Remplaçant proposé (nom anglais exact) | Créature / affichage | Effet du changement |
|---|---|---|---|---|
| Ennemi Defias Bandit (116, aff. 2357 / 2358) | Elwynn | **Defias Highwayman** (bandit de grand chemin de la Marche, même rôle de voleur de route) | 122 / 2342, 2343 (cache frFR « Malandrin défias ») | nom affiché + modèle ; l'id interne `bandit` peut rester (sauvegardes) |
| Modèle de secours du Conjurer : Defias Rogue Wizard 474 (aff. 2359 / 2360) | Elwynn | retirer de la liste ; garder Defias Enchanter 910 en secours, ou **Defias Magician** (Mortemines) | 1726 / 2321, 2322 (cache frFR « Magicien défias ») | liste de secours seulement |
| Tobin coupe-jarret : Defias Cutpurse 94 (aff. 2361 / 2362) | Elwynn | **Defias Pathstalker** | 121 / 2336, 2337 (cache frFR « Éclaireur défias ») | modèle seulement |
| Cocher : Brog Hamfist 151 | Goldshire (Elwynn) | **Farmer Furlbrow** (les Furlbrow attendent près de leur chariot sur la route du nord de la Marche) ; le texte peut garder « the wagon driver » ou le nommer | non trouvé (absent du cache) | modèle ; nom du personnage à trancher |
| Mother Hanna : Ma Stonefield 244 | Elwynn | **Verna Furlbrow** (fermière chassée de sa terre, comme les réfugiés de Moonbrook) en modèle | non trouvé | modèle seulement |
| Old Hank : Lee Brown 1651 | lac de Cristal (Elwynn) | aucun pêcheur nommé de la Marche connu ; modèle d'un fermier de la Marche : **Farmer Saldean** | 233 / 1943 (cache) | modèle seulement |
| Grit : Prospector Stormpike 1356 | Forgefer | **Thor** (nain, maître des griffons de Sentinel Hill) en modèle | non trouvé | modèle seulement |
| Aunt Mirelle : Alma Jainrose 812 | Lakeshire (Redridge) | **Innkeeper Heather** (Sentinel Hill) en modèle | non trouvé | modèle seulement |
| Keeper Alden : Dockmaster Baren 381 | Lakeshire (Redridge) | **Captain Grayson**, fantôme du phare de la Marche (réel ; demande de réécrire « I'm sick » en « I'm dead ») ; sinon garder Alden avec **Scout Riell** en modèle | non trouvé (Grayson) ; Scout Riell non trouvé | texte ou modèle |
| Grizzle Quickclick : Zixil 3537 | Hillsbrad | **Defias Profiteer** `<Wandering Vendor>` (marchand défias neutre), zone à confirmer | 1669 / 4423 (cache frFR « Profiteur défias ») | personnage et texte (« Grizzle » devient un Défias qui vend une pièce de golem) |
| Tinker Bertil : Deek Fizzlebizz 3290 | Loch Modan | aucun gnome nommé de la Marche connu ; garder le gnome inventé, ou le remplacer par **Farmer Saldean** (ses champs sont gardés par les golems) | 233 / 1943 | personnage ou rien |
| Tobin enfant : Tommy Joe Stonefield 252 | Elwynn | aucun enfant nommé de la Marche connu ; garder | — | — |
| Farmer Molsen : Farmer Ray 232 | zone non vérifiable (le cache ne donne pas la zone) | si 232 n'est pas de la Marche : **Farmer Saldean** | 233 / 1943 | modèle seulement |
| Fond `elwynn.tga` (route, colline, camp, marchand, feu de camp) | Elwynn | voir section 5 | — | — |
| Fond `farm.tga` (Twin Peaks) et `coast.tga` (Gilnéas) | Hautes-terres du Crépuscule, Gilnéas | voir section 5 | — | — |

Hors zone mais à noter : le familier du Hunter est un Young Wolf d'Elwynn (classe, pas zone) ; un Coyote de la
Marche irait mieux (non trouvé dans le cache). Le feu de camp `elwynncampfire.m2` est le feu humain générique,
présent dans toute la Marche : rien à changer.

## 2. Pas de mécanique nouvelle : ce que Westfall enseigne déjà

- **Interrompre et protéger son Cast** : la Fireball du Conjurer (16) s'interrompt ; Kick, Frost Shards, Smash et Slam coupent l'incantation du joueur s'il perd des PV (l'Absorb la protège) ; le Mystic la punit dès qu'une carte Cast est en main.
- **Choisir sa cible** : le Mystic soigne 6, chaque murloc tué renforce les autres (+1 Strength), VanCleef appelle deux sbires à 50 % ; l'ordre de mise à mort décide des PV perdus.
- **Lire les gros coups et les états** : Smash 19, Slam 18, Mortal Strike 23 sont annoncés un tour à l'avance ; Rend, Combo et Roar posent Sundered et Demoralized sur le joueur.

## 3. Cartes de zone (une par classe)

Cartes définitives (épiques, pivots) : voir `docs/zones/cartes-de-zone.md`.

- Prayer of Mending (Priest)
- Death Wish (Warrior)
- Mirror Image (Mage)
- Deflection (Rogue)
- Call of the Wild (Hunter)

## 4. Commun de la première victoire du compte et bibelots de clé

### Deux cartes neutres

Mêmes règles que `docs/cartes-neutres.md` : ni ressource ni état de classe, jamais meilleures qu'une carte de
classe de même coût, Exhaust.

| id | Nom | Origine | Rareté | Coût | Type | Texte | Amélioré | Icône | Repère |
|---|---|---|---|---|---|---|---|---|---|
| `westfall_stew` | Westfall Stew | Cooking (la recette de Salma Saldean) | common | 1 | Skill | Heal 3. / Gain Regen 2 / Exhaust. | Heal 4. / Gain Regen 3 / Exhaust. | `inv_drink_17` (132804) | 6 PV en tout comme Heavy Silk Bandage (6 tout de suite) et Renew (Regen 3 = 6 étalés) ; moitié tout de suite, moitié au tour suivant. |
| `cookies_tenderizer` | Cookie's Tenderizer | arme de Cookie (Mortemines) | uncommon | 1 | Attack | Deal 5. / Apply Sundered 2 ⌛ / Exhaust. | Deal 7. / Apply Sundered 3 ⌛ / Exhaust. | `inv_mace_01` (133476) | Colossus Smash 6 + Sundered 3 et Schism 3 + Sundered 2 + Atonement, sans Exhaust : plus faible. |

### Trois bibelots communs

| id | Nom | Origine | Rareté | Effet (texte affiché) | Icône | Crochet |
|---|---|---|---|---|---|---|
| `furlbrows_pocket_watch` | Furlbrow's Pocket Watch | quête des Furlbrow, montre perdue dans la mine de Jangolode | common | `At the start of your second turn each combat, draw 2 more cards.` | `inv_misc_pocketwatch_01` (134376) | `onTurnStart` au round 2 |
| `murloc_fin` | Murloc Fin | butin des murlocs de la côte | common | `Whenever an enemy dies, gain 3 Absorb.` | `item_aquaticfin_01` (1547459) | `onEnemyDeath` (déjà employé par Devilsaur Eye) |
| `captain_sanders_map` | Captain Sander's Treasure Map | objet de quête lâché par les Défias de la Marche | uncommon | `Card rewards after combat offer 1 more card.` | `inv_misc_map_01` (134269) | **nouveau point** : taille du choix de la récompense de combat (3 → 4) |

### Une case de parcours : Wanted Poster

- **Règle** : une case « Wanted » remplace une case de combat normal sur la carte de l'expédition. Le nom et les
  intentions de l'élite qui l'attend sont affichés dès la carte (choisi au hasard parmi les élites de la zone :
  à Westfall, Harvest Golem ou Rhahk'Zor). Combat d'élite, récompense d'élite + 40 po. Le joueur décide donc de
  son chemin en sachant quel élite il affrontera.
- Une case par expédition au plus, jamais à l'étape 1. Valable dans toutes les zones avec leurs élites.
- Icône : `inv_misc_note_06` (134332). Point de moteur : un nouveau genre de nœud qui tire et mémorise l'élite à
  la génération de la carte (aucun ennemi ni chiffre nouveau).
- Les rares nommés de la Marche (Foe Reaper 4000, Vultros, Old Murk-Eye, Leprithus) pourraient plus tard tenir ce
  rôle, mais demanderaient des ennemis chiffrés : hors de cette fiche.

### Bibelots de clé (+1, +3, +5)

Plus forts que les communs, communs aux classes, butin réel des Mortemines.

| Clé | id | Nom | Origine | Rareté | Effet (texte affiché) | Icône | Repère |
|---|---|---|---|---|---|---|---|
| +1 | `smites_mighty_hammer` | Smite's Mighty Hammer | Mr. Smite | uncommon | `Your first Attack each turn deals 5 more damage.` | `inv_hammer_04` (133041) | Coarse Sharpening Stone : +1 par coup de chaque Attack. |
| +3 | `blackened_defias_armor` | Blackened Defias Armor | Edwin VanCleef | rare | `At the start of each turn, gain 3 Absorb.` | `inv_chest_leather_03` (132718) | Elixir of Superior Defense : la même chose en carte Power à jouer. |
| +5 | `cruel_barb` | Cruel Barb | Edwin VanCleef | rare | `Attacks deal 2 more damage per hit.` | `inv_sword_23` (135324) | Le double de Coarse Sharpening Stone. Ne touche pas le familier du Hunter (pas une carte). |

## 5. Fonds de scène

Contraintes (`docs/interface.md`, « Fonds embarqués ») : illustration de Blizzard extraite par FileDataID, zone
gardée sans logo ni cadre, étirée sur un TGA 1024 × 512, rapport réel 2,0 à 2,6 rétabli à l'affichage ; la scène
en montre une bande 1034 × 380 (≈ 2,72:1). Recherche : `wow_file_search` (« westfall », « deadmines »,
« moonbrook », « lighthouse », « defias », « vancleef », « housing », « easternkingdom », sous
`interface/glues/loadingscreens/`, `interface/encounterjournal/`, `interface/lfgframe/`, `interface/garrison/`).
`wow_texture_export` n'a pas d'installation ; les tailles et contenus ont été vus en téléchargeant les BLP
depuis wago.tools, comme `tools/build_backgrounds.py`.

**Aucun écran de chargement ni illustration de paysage de la Marche de l'Ouest n'existe dans la liste de
fichiers** (index « interface seule »). Candidats trouvés :

| FileDataID | Fichier | Taille | Contenu | Verdict |
|---|---|---|---|---|
| 131833 | `loadingscreens/loadscreendeadmines` | 2048 × 2048 (4:3) | Mortemines, navire dans la grotte, croquis | déjà `deadmines.tga` (scène mine, boss) |
| 522336 | `encounterjournal/ui-ej-background-deadmines` | 512 × 512, image utile ≈ 395 × 425 | Mortemines (Cataclysm) : mât, cordages, lanterne, croquis teinté | trop petit et en hauteur : une bande 2,72:1 ferait ≈ 395 × 145, agrandie ×2,6 |
| 526404 | `encounterjournal/ui-ej-lorebg-deadmines` | 512 × 512 | la même image dans un cadre | écarté (cadre) |
| 337488 | `lfgframe/ui-lfg-background-deadmines` | 256 × 128 (2:1) | la même image, réduite | écarté (taille) |
| 4196606 | `garrison/_garrmissionlocation-townalliance-back` | 1024 × 256 (4:1) | panorama de Goldshire (Elwynn) | Elwynn : écarté ; format de bande idéal (4:1, plans back / mid / fore) |
| 4196549 | `garrison/_garrmissionlocation-arathihighlands-mid` | 1024 × 256 | collines vertes d'Arathi | pas la Marche |
| 273138… (12 tuiles) | `worldmap/westfall/westfall1..12` | 12 × 256², carte 1002 × 668 | carte peinte de la Marche (version classique) | pour un écran de carte de zone, pas pour une scène |
| 8067822… (12 tuiles) | `worldmap/westfall_c60/westfall_c601..12` | 12 × 256² | carte de la Marche propre à Forever (parchemin) | idem |
| 131839, 445506, 1035011, 1498773, 343001 | écrans des royaumes de l'Est | 2048² ou 2048 × 1024 | carte du continent, héros, logo | écartés |
| 7963777 | `camelot160/main/loadscreen_camelot_excavation` | 2992 × 1684 | fouille, sépia (Forever) | déjà écarté ; pourrait servir à la scène `mine` des rencontres (Jangolode) |

Conséquence : pour les scènes route, colline, camp et marchand, il n'y a pas d'illustration de la Marche à
embarquer. Choix possibles (question 1) : garder Elwynn ; passer ces scènes au décor peint (`paint = "fields"`)
recoloré en blé doré ; ou chercher dans l'index complet (modèles, cartes ; demande une synchronisation, non
lancée) un rendu de terrain de la Marche.

## 6. Modèles et icônes

Ennemis, élites, boss : identifiants de `UI/Art.lua`, tous retrouvés dans le cache enUS du client Forever.

| Unité | Créature | Affichage (cache) | Icône de repli |
|---|---|---|---|
| Riverpaw Gnoll | 117 | 175 | `inv_misc_head_gnoll_01` (134163) |
| Riverpaw Mystic | 453 | 502 | idem |
| Murloc Coastrunner | 126 | 983 | `inv_misc_head_murloc_01` (134169) |
| Defias Bandit → Defias Highwayman | 116 → 122 | 2357 / 2358 → 2342 / 2343 | `inv_misc_bandana_03` (133694) |
| Defias Conjurer | 619 | 2329 / 2330 | `spell_fire_flamebolt` (135812) |
| Defias Henchman | 594 | 2323 / 2324 | `inv_misc_bandana_03` |
| Harvest Golem | 36 | 367 | `inv_misc_gear_01` (134063) |
| Rhahk'Zor | 644 | 14403 | `inv_misc_bone_humanskull_01` (133730) |
| Edwin VanCleef | 639 | 2029 | `achievement_boss_edwinvancleef` (236409) |

PNJ des rencontres : voir la table des remplaçants (section 1). Retrouvés dans le cache : Salma Saldean 235 /
1691, Farmer Saldean 233 / 1943, Gryan Stoutmantle 234 / 1690, Riverpaw Taskmaster 98 (via `UI/Art.lua`), Defias
Highwayman 122, Defias Pathstalker 121, Defias Magician 1726, Defias Profiteer 1669. Non trouvés (absents du
cache, `wow_creature_search` sans installation) : Farmer Furlbrow, Verna Furlbrow, Thor, Innkeeper Heather,
Captain Grayson, Scout Riell, Foe Reaper 4000, Vultros, Old Murk-Eye, Leprithus, Coyote.

Cartes et bibelots : icônes vérifiées par `wow_icon_search` (FileDataID entre parenthèses dans les tables des
sections 3 et 4). Remarque : `item_aquaticfin_01` et `ability_hunter_callofthewild` sont des icônes récentes ;
le pack d'icônes de `~/Téléchargements` peut ne pas les avoir (repli : `inv_misc_monsterscales_01` 134303 et
`ability_hunter_beastwithin`).

## 7. Questions ouvertes

1. **Fond de la route** : aucune illustration de la Marche n'existe. Garder Elwynn (forêt verte sous un nom de
   Marche dorée), ou passer route, colline, camp et marchand au décor peint couleur blé (moins beau, mais juste) ?
2. **Defias Bandit → Defias Highwayman** : mêmes chiffres, nouveau nom et modèle. Le joueur verra un autre nom
   sur un ennemi qu'il connaît ; les journaux et rapports qui citent « Defias Bandit » changent.
3. **Personnages des rencontres** : changer seulement les modèles (rien à relire), ou aussi les noms (Farmer
   Furlbrow pour le cocher, Captain Grayson fantôme pour le gardien du phare, un Défias à la place de la
   gobeline) ? Le second choix réécrit 3 textes de rencontre.
4. **Puissance des cartes de zone** : Call of the Wild (familier deux fois par tour pour 1 mana) et Shockwave
   (tout un groupe étourdi tous les 3 tours) peuvent devenir le premier choix de chaque deck de leur classe.
   Les garder fortes, puisque c'est la récompense de la première victoire, ou les tenir au niveau des rares
   actuelles ?
5. **Captain Sander's Treasure Map** demande de toucher la récompense de combat (4 cartes au lieu de 3) ; si ce
   point de moteur gêne, l'échanger contre `Whenever you interrupt a cast, draw 1 card.`, plus lié à la leçon
   de la zone, mais qui demande lui aussi un crochet nouveau (`onInterrupt` n'existe pas : seuls `onCastStart`,
   `onCastResolved`, `onTurnStart`, `onEnemyDeath`… sont tirés par `Core/Combat.lua`).

## Décisions du joueur (13/11/2026)
1. **Fonds de scène** : décor peint couleur blé pour la route, la colline, le camp et le marchand ; l'illustration d'Elwynn est retirée.
2. **Defias Bandit → Defias Highwayman** : nouveau nom et nouveau modèle, mêmes chiffres.
3. **Personnages des rencontres** : remplacés par des gens de Westfall, noms et modèles (les textes concernés sont réécrits).
4. **Cartes de zone : rareté « épique », cartes pivot.** Elles ne sont pas ramenées au niveau des rares : chacune doit pouvoir servir de pivot à un deck (on construit autour d'elle). Vaut pour les sept zones.
5. Captain Sander's Treasure Map : non tranché.

## Appliqué le 13/11/2026 (décisions 1 à 3)

Aucun chiffre de combat, d'ennemi, de carte ni de récompense ne change (empreintes vérifiées par le
harnais, section UW).

1. **Fonds** : route, colline (Sentinel Hill), camp, marchand et feu de camp sont des décors peints
   couleur blé (`Art.paintings` / `Art.palettes`, peints par `S.landscape`), portés par la zone
   (`ns.Zones.westfall.scenes`) ; `Media/Backgrounds/elwynn.tga` est supprimé, ainsi que sa fabrication.
   Mine (Mortemines) gardée ; ferme (Pics-Jumeaux) et côte (Gilnéas) inchangées (hors décision).
   Détail : `docs/interface.md`, « Décors peints de Westfall ».
2. **Defias Highwayman** : `Data/Zones/Westfall.lua`, id `bandit` gardé ; modèle 122 / 2342, 2343.
   Secours de l'Invocateur : le Sorcier-voleur défias d'Elwynn (2359 / 2360) laisse la place au Magicien
   défias (2321 / 2322).
3. **Personnages** (noms, modèles, textes ; ids des rencontres gardés) :

| Rencontre | Avant | Maintenant | Créature / affichages |
|---|---|---|---|
| `defias_caravan` | The wagon driver (Brog Hamfist 151) | Farmer Furlbrow | 237 (hors caches) / 1943, 3614 (repli) |
| `moonbrook_refugees` | Mother Hanna (Ma Stonefield 244) | Verna Furlbrow | 238 (hors caches) / 1691, 8185 (repli) |
| `coast_murlocs` | Old Hank (Lee Brown 1651) | Scout Galiaan (milice) | 878 / 2373, 2374, 2368 |
| `jangolode_prospector` | Grit (Prospector Stormpike 1356) | Thor, gryphon master | 523 / 3263, 3594 (repli d'apparence) |
| `herbalist` | Aunt Mirelle (Alma Jainrose 812), route | Innkeeper Heather, colline | 8931 / 8185, 1691 |
| `lighthouse_keeper` | Keeper Alden (Dockmaster Baren 381) | Captain Grayson (fantôme) | 392 (hors caches) / 2372, 2367 (repli) |
| `goblin_peddler` | Grizzle Quickclick (Zixil 3537) | Defias Profiteer | 1669 / 4423, 2342 |
| `harvest_watcher` | Tinker Bertil (Deek Fizzlebizz 3290) | Farmer Saldean | 233 / 1943, 3614 |
| `tobin_defias` | modèle Defias Cutpurse 94 | Tobin (modèle Defias Pathstalker) | 121 / 2336, 2337, 2342, 2343 |

Thor, Innkeeper Heather, Scout Galiaan et Defias Profiteer, « non trouvés » dans la fiche, sont dans le
cache frFR (`tools/wdb_creatures.py`). Gardés : Salma Saldean, Gryan Stoutmantle, Farmer Molsen (nom tiré de
la ferme Molsen ; modèle 232, zone non vérifiable), Graymaw, Tobin enfant (aucun enfant nommé de la Marche)
et guetteur. Textes réécrits : `docs/rencontres.md` (en tête) et `Data/Events.lua`.
