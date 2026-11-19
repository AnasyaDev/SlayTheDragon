# Arbres de talents — fiche de conception

Proposition du 19/11/2026, **à valider par le joueur avant tout code**. Aucun fichier de jeu n'est changé par cette
fiche. Elle s'appuie sur la méta d'aujourd'hui (`Core/Meta.lua`, `docs/expedition.md`, « Niveau de classe » et
« Campagne continue »), sur le mur des zones 4 à 7 (`docs/zones.md`, « Dureté des zones » ; `docs/equilibrage.md`,
« Mur des zones 4 à 7 sans épique ») et sur 30 séries de simulation faites pour elle (§ 4).

Ce que le joueur a décidé le 19/11/2026 :

- une méta-progression à talents, **un seul arbre par classe** ; sans talents, une expédition est presque
  impossible ; avec, elles deviennent de plus en plus faciles ;
- première victoire (Nefarian battu, clé 0) à portée d'un joueur correct en **une dizaine d'expéditions** ;
- **pas besoin de l'arbre entier : à 60 % de l'arbre, au moins 40 % de chances de finir** ;
- **les niveaux de classe donnent les points de talent** : pas de monnaie séparée ; une expédition donne de
  l'expérience de classe (comme aujourd'hui), un niveau donne un point ; une expédition perdue fait toujours avancer ;
- les talents donnent de la puissance et des options, mais **surtout renforcent les mécaniques propres de la
  classe** (Rage, familier et Frenzy, Combo / Stealth / Parry, Charges et double Cast, Insanity, formes, réserve et
  taxe) : arbre sur mesure par classe, quelques nœuds génériques seulement ;
- les expéditions débloquent aussi de nouvelles rencontres et de meilleurs points de passage ;
- sans épique, la zone 4 est un mur ; plusieurs épiques pourront être portées (en cours de code) ; **pas de
  difficulté artificielle** (« avoir une épique réduit la dureté de la zone » est refusé) : la force vient de ce que
  le joueur a débloqué ;
- les voies de soin et de tank sont de l'appoint, pas des voies à jouer seules.

## Résumé

1. L'expérience de classe ne change pas (`Meta.XP`) ; le niveau de classe passe de 7 à **25 niveaux** ; chaque
   niveau à partir du 2 donne **1 point de talent** : **24 points**, soit l'arbre entier.
2. Rythme visé (bot `human`) : 20 % de l'arbre vers la 4e expédition, 40 % vers la 7e, **60 % vers la 10e**, 100 %
   vers la 17e. Une défaite dans les Wetlands rapporte ≈ 130 à 150 d'expérience : plus d'un niveau au début.
3. Les cartes et bibelots restent attachés au niveau (mêmes seuils d'expérience qu'aujourd'hui ou jusqu'à 150 plus tôt) : l'arbre
   ne débloque pas de contenu, il donne de la force.
4. Arbre : 4 rangées ouvertes à 0 / 5 / 10 / 16 points dépensés, 13 à 14 nœuds de 1 à 3 rangs, un nœud à choix
   (Specialization : une des trois voies). Neuf ou dix nœuds sur treize ou quatorze touchent la mécanique de la
   classe ; quatre sont génériques (PV, or, soin du passage, épique au départ).
5. Remboursement gratuit entre deux expéditions ; l'arbre est figé au départ d'une expédition (comme `exp.unlock`).
6. Arbres complets du Warrior et du Druid (§ 6 et 7) ; nœuds propres des quatre autres classes (§ 8).
7. Mesures (§ 4) : au compte neuf, aucun levier seul ne fait gagner (0 %, même au bot `heuristic`) ; +20 PV, le
   niveau 7, +1 mana par tour ou la taxe du Druid retirée déplacent le mur sans le franchir. Le palier « 60 % »
   approché par les leviers mesurables donne 17 % au Warrior (26 % avec +1 mana par tour), 7 à 10 % au Druid.
8. **La cible 60 % → 40 % n'est pas tenue avec le mur actuel** : il manque ≈ 15 points au Warrior. Burning Steppes
   et Blackrock Mountain abaissées à 1,9 (pour tous, sans condition d'épique) : Warrior 45 %, Druid 31 %. Le Druid a
   en plus un défaut propre dans les zones 6 et 7 (Blackrock 30 % même arbre plein), à régler à part (§ 5).
9. Les clés 1 à 5 prennent le relais après la première victoire ; à recaler une fois l'arbre codé (§ 9).
10. Rencontres et points de passage : sept déblocages par hauts faits du compte, hors de l'arbre (§ 10).

## 1. Points de talent : les niveaux de classe

### 1.1 Aujourd'hui (`Core/Meta.lua`)

- Expérience par classe (`cs.xp`), gagnée à chaque boss battu (`Meta.bank`, étapes franchies) et en fin
  d'expédition, gagnée, perdue ou abandonnée (`Meta.record`) : `(5 × étapes franchies + 6 × élites + 15 × boss + 15
  si Nefarian battu) × (1 + 0,15 × clé)` (`Meta.XP`).
- Sept niveaux, seuils `Meta.XP_LEVELS = { 0, 100, 250, 450, 700, 1000, 1400 }` ; le niveau débloque les cartes
  (champ `level` 1 à 7 : 22 cartes au niveau 1, une par voie aux niveaux 2, 4, 6, une rare par voie au 7) et les
  bibelots de classe (2 au niveau 1, un au 3, un au 5, deux au 7) ; titre « Veteran » au 7.
- Une expédition garde le niveau de son départ (`exp.unlock.level`, `Expedition.unlocked`).
- Mesuré (bot `human`, clé 0, compte neuf, mur actuel) : **135 d'expérience par expédition au Warrior, 156 au Druid**
  (défaites entre Westfall et Stranglethorn Vale) ; 317 à 344 au palier « 60 % » (§ 4) ; une victoire ≈ 440.

### 1.2 Proposé : 25 niveaux, un point par niveau

La formule d'expérience ne change pas. Seule la table des seuils s'allonge (`Meta.XP_LEVELS`, `Meta.MAX_LEVEL` = 25) :

| Niveau | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Expérience cumulée | 0 | 100 | 200 | 300 | 400 | 500 | 650 | 800 | 950 | 1 100 | 1 250 | 1 400 | 1 550 |
| Points de talent | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |

| Niveau | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Expérience cumulée | 1 700 | 1 850 | 2 000 | 2 250 | 2 500 | 2 750 | 3 000 | 3 250 | 3 600 | 3 950 | 4 300 | 4 650 |
| Points de talent | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 |

Écarts : 100 jusqu'au niveau 6, 150 jusqu'au 16, 250 jusqu'au 21, 350 jusqu'au 25.

**Rythme attendu** (bot `human`, clé 0) : l'expérience par expédition monte avec l'arbre, de 135–156 (compte neuf)
à ≈ 320–345 (palier 60 %), puis ≈ 400 quand la moitié des expéditions finissent. Estimation : 135, 150, 165, 185,
210, 230, 250, 270, 290, 310, puis ≈ 330 à 450.

| Après l'expédition n° | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 13 | 17 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Expérience cumulée (≈) | 135 | 285 | 450 | 635 | 845 | 1 075 | 1 325 | 1 595 | 1 885 | 2 195 | 3 245 | 4 925 |
| Niveau | 2 | 3 | 5 | 6 | 8 | 9 | 11 | 12 | 15 | 16 | 21 | 25 |
| Part de l'arbre | 4 % | 8 % | 17 % | 21 % | 29 % | 33 % | 42 % | 46 % | 58 % | **63 %** | 83 % | 100 % |

- **Une expédition perdue fait toujours avancer** : mourir à l'étape 5 de Westfall rapporte ≈ 25 à 30 d'expérience
  (un quart de niveau au début) ; mourir dans les Wetlands ≈ 130 à 150 (plus d'un niveau jusqu'au niveau 6) ; mourir à
  Stranglethorn Vale ≈ 180 à 210.
- Le bot `heuristic` gagne ≈ 430 d'expérience par expédition une fois lancé : 60 % de l'arbre vers la 5e ou 6e
  expédition.
- **Par classe** (tranché, comme l'expérience d'aujourd'hui) : chaque arbre est propre à sa classe, une monnaie
  partagée n'aurait pas de sens. Alternative : un petit bonus de compte (≈ +25 % d'expérience pour une classe dont
  le compte a déjà battu Nefarian avec une autre classe) pour ne pas refaire 17 expéditions par classe ; à décider
  (§ 16).
- Au-delà du niveau 25, l'expérience continue d'être comptée sans rien donner (§ 9 et § 16).

### 1.3 Cartes et bibelots : restent attachés au niveau (tranché)

Le niveau garde ses déblocages de contenu, aux mêmes seuils d'expérience qu'aujourd'hui (au plus 150 plus tôt) :

| Palier de contenu (champ `level` des cartes et bibelots, inchangé) | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Seuil d'aujourd'hui | 0 | 100 | 250 | 450 | 700 | 1 000 | 1 400 |
| Niveau de classe proposé (seuil) | 1 (0) | 2 (100) | 3 (200) | 5 (400) | 7 (650) | 9 (950) | 11 (1 250) |
| Contenu | 22 cartes, 2 bibelots | 1 carte par voie | 1 bibelot | 1 carte par voie | 1 bibelot | 1 carte par voie | 1 rare par voie, 2 bibelots |

Pourquoi :

- **Le contenu est la plus grosse source de force mesurée** : passer du niveau 1 au niveau 7 fait passer la part des
  Warriors qui battent le boss de Stranglethorn Vale de 4,3 à 38,8 % (§ 4) ; aucun autre levier seul n'en fait
  autant. Le mettre dans l'arbre obligerait à dépenser des points en cartes avant de pouvoir renforcer la mécanique ;
  un joueur qui les sauterait aurait une réserve de cartes plus petite (récompenses de boss réduites à une rare, le
  piège déjà vu sur le Druid le 18/11/2026).
- Un seul système d'état à équilibrer en plus (l'arbre), pas deux (l'arbre et les cartes qu'il ouvre).
- L'onglet « Cards » de l'écran Progress, le test « progression : répartition exacte » et les fiches de classe
  (§ Progression) restent vrais ; la migration ne retire aucune carte (§ 13).
- Le joueur l'a dit : niveau et arbre sont jumeaux. Le niveau 11 (≈ 7e expédition) donne la dernière carte, les
  niveaux 12 à 25 ne donnent plus que des points.

Alternative : les cartes de voie au-delà du niveau 1 deviennent des nœuds de l'arbre (une rangée « Arsenal » par
voie). Avantage : le joueur choisit quelle voie il ouvre d'abord. Inconvénients : 12 cartes et 4 bibelots à placer
dans chaque arbre (24 points ne suffisent plus), N états de réserve à mesurer, migration plus lourde (rembourser des
cartes déjà débloquées en points). Non retenue.

Titre « Veteran » : au niveau 25 (au lieu du 7).

## 2. Forme de l'arbre

### 2.1 Règles communes

- **Rangées** : 4, ouvertes quand le joueur a dépensé au moins 0 / 5 / 10 / 16 points dans l'arbre de la classe.
- **Nœuds** : 13 à 14 par classe, de 1 à 3 rangs ; un rang coûte 1 point ; un rang demande le précédent.
- **Arbre entier = 24 points** = niveau 25. « 60 % » = 15 points (niveau 16) : les rangées 1 et 2 pleines
  (12 points) et 3 points de la rangée 3 ; la rangée 4 n'est pas ouverte.
- **Pas de prérequis entre nœuds** hors des rangées (lisibilité) ; **un nœud à choix** en rangée 3,
  **Specialization** (1 point) : une option par voie (Arms / Fury / Protection…), une seule active, changeable avec
  le remboursement. Pas d'autres choix exclusifs : à 24 points tout est pris ; le choix porte sur l'ordre (quoi
  d'abord) et sur la voie de Specialization.
- **Nœuds génériques** (mêmes noms et mêmes effets dans les six arbres, 9 points sur 24) : **Toughness** (PV),
  **Provisions** (or de départ), **Field Medic** (soin du passage entre deux zones), **Veteran's Arsenal**
  (épique au départ, puis une épique de plus). Tous les autres nœuds touchent une règle propre à la classe.
- **Remboursement** : gratuit, à volonté, **hors expédition** (accueil ou écran Progress). Un roguelike à méta
  doit laisser essayer ; un remboursement payant n'aurait pas de monnaie (pas d'or hors expédition).
- **Figé au départ** : l'expédition copie l'arbre de sa classe (`exp.unlock.talents`) ; dépenser ou rembourser
  pendant une expédition ne change rien avant la suivante, comme les cartes débloquées en route.
- **Pas de difficulté artificielle** : aucun nœud ne touche la dureté des zones, les PV ou les coups des ennemis
  d'une zone, ni les affixes. Un nœud agit sur le héros, son deck, sa ressource, son or ou ses soins.

### 2.2 Ce que vaut chaque genre de nœud (ordre de grandeur, § 4)

| Genre | Exemple | Mesure | Valeur |
|---|---|---|---|
| PV de départ | Toughness 3 rangs (+12 PV Warrior, +9 Druid) | `hp=` | +5 PV : Westfall battue +7 points ; +10 : +18 ; +20 : +30 ; le mur de la zone 4 bouge peu (passage 9 → 26 % au mieux) |
| Or de départ | Provisions (+100) | `tune=Expedition.START_GOLD=150` | +5 points à Westfall, zone moyenne +0,2 |
| Soin du passage | Field Medic (75 %) | `tune=Expedition.ZONE_HEAL=1` (100 %, borne haute) | zone moyenne +0,2 au compte neuf (peu de passages) ; pèse plus quand on traverse 4 zones ou plus |
| Moteur de la classe (mana, ressource, Absorb par tour) | Rampage, Natural Shapeshifter | `tune=Combat.BASE_MANA=4` (borne haute : +1 mana chaque tour) ; `tune=Druid.TAX=0` | +1 mana : Westfall battue 61 → 97 %, zone moyenne +1,45 ; Druid sans taxe : 70 → 96 %, +1,24 ; c'est l'ordre de grandeur de tous les nœuds de mécanique des rangées 1 à 3 réunis |
| Épique au départ | Veteran's Arsenal | `epic=<id>` | Death Wish +0,4 zone ; Titan's Grip +0,75 (Warrior) ; Furor +1,1 (Druid) ; compte neuf |
| Contenu (niveau, hors arbre) | niveau 1 → 7 | `level=7` | zone moyenne +1,1 (Warrior), +0,4 (Druid) ; passage de Stranglethorn 9 → 57 % et 8 → 38 % |

## 3. Courbe cible

Cible au bot `human` (joueur correct), clé 0, **état complet du compte au moment où il atteint ce palier** (cartes
du niveau, épiques des zones gagnées, commun du compte, arbre). « Zone moyenne » = rang moyen de la zone la plus
loin atteinte (1 = Westfall ; 7 = Blackrock Mountain atteinte ou Nefarian battu).

| Part de l'arbre (points) | Niveau | Atteint vers l'expédition n° | Contenu à ce moment (≈) | Victoires cible | Zone moyenne cible | Mesuré aujourd'hui (Warrior / Druid) |
|---|---|---|---|---|---|---|
| 0 % (0) | 1 | 1 | niveau 1, aucune zone | 0 % | 2,7–2,9 | 0 / 0 % ; 2,67 / 2,93 |
| 20 % (5) | 6 | 4 | paliers de contenu 1–4, zones 1–2 | ≈ 1 % | 3,4 | — |
| 40 % (10) | 11 | 7 | tout le contenu, zones 1–3 | ≈ 15 % | 4,5 | — |
| **60 % (15)** | 16 | **10** | tout, zones 1–4 | **≥ 40 %** | 5,6 | proxy 17 / 7 % ; avec +1 mana 26 / 10 % (§ 4.3) |
| 80 % (19–20) | 20–21 | 13 | tout, zones 1–5 ou 6 | ≈ 55 % | 6,1 | — |
| 100 % (24) | 25 | 17 | tout | ≈ 65–70 % | 6,4 | proxy 72 / 12 % (§ 4.3) |

Joueur parfait (bot `heuristic`) aux mêmes paliers : 0 % → 0 % (mesuré, compte neuf : zone moyenne 4,1 au Warrior
comme au Druid) ; 60 % → cible ≈ 80 % (proxy s60m mesuré avec le mur actuel : Warrior 55 %, Druid 43 % : même sans
erreur, le mur des zones 6 et 7 arrête la moitié des expéditions) ; 100 % → ≈ 95–98 %. Il atteint 60 % de l'arbre
vers la 5e ou 6e expédition (≈ 430 d'expérience par expédition).

Les deux bornes de la courbe sont tenues aujourd'hui (0 % : 0 victoire, ce que le joueur a demandé : « sans ces
talents, les runs sont quasiment impossibles ») ; le milieu dépend des nœuds de mécanique (§ 5).

## 4. Mesures

Commande : `flock build/sim-b.lock luajit Sim/sim.lua runner=expedition bot=human key=0 seed=1 jobs=8 runs=600
class=<warrior|druid> zones=0 level=1 [levier]` (compte neuf, mur actuel 1,45 / 1,8 / 2,15 / 2,3) ; ± 4 points.
Rapports bruts : `reports/talents/` du worktree (non versionnés), résumés par `reports/talents/sum.sh`.

### 4.1 Leviers seuls, compte neuf (bot `human`, 600)

Colonnes : victoires ; zone moyenne ; part des expéditions qui battent le boss de Westfall / Wetlands /
Stranglethorn Vale / Swamp of Sorrows ; expérience par expédition.

| Warrior (70 PV) | Victoires | Zone moy. | Westfall | Wetlands | Stranglethorn | Swamp | XP / exp. |
|---|---|---|---|---|---|---|---|
| compte neuf | 0,0 % | 2,67 | 61,0 | 48,7 | 4,3 | 0,5 | 135 |
| +5 PV (`hp=75`) | 0,0 % | 2,89 | 67,8 | 55,8 | 4,5 | 0,7 | 149 |
| +10 PV | 0,0 % | 3,34 | 78,8 | 71,7 | 10,0 | 0,2 | 176 |
| +20 PV | 0,0 % | 3,89 | 90,5 | 86,7 | 22,3 | 1,5 | 210 |
| niveau 7 (`level=7`) | 0,2 % | 3,75 | 77,5 | 68,7 | 38,8 | 16,7 | 200 |
| épique Death Wish au départ | 0,0 % | 3,09 | 71,5 | 57,8 | 14,0 | 3,2 | 159 |
| épique Titan's Grip au départ | 0,0 % | 3,42 | 74,2 | 70,7 | 22,5 | 3,2 | 182 |
| soin du passage 100 % (`ZONE_HEAL=1`) | 0,0 % | 2,84 | 61,0 | 56,5 | 8,3 | 0,3 | 148 |
| or de départ 150 (`START_GOLD=150`) | 0,0 % | 2,90 | 66,2 | 56,7 | 7,2 | 0,3 | 149 |
| +1 mana par tour (`Combat.BASE_MANA=4`) | 0,0 % | 4,12 | 97,3 | 92,7 | 24,2 | 3,7 | 225 |

| Druid (59 PV) | Victoires | Zone moy. | Westfall | Wetlands | Stranglethorn | Swamp | XP / exp. |
|---|---|---|---|---|---|---|---|
| compte neuf | 0,0 % | 2,93 | 70,3 | 55,2 | 4,3 | 0,0 | 156 |
| +5 PV (`hp=64`) | 0,0 % | 3,23 | 78,7 | 66,3 | 6,5 | 0,2 | 175 |
| +10 PV | 0,0 % | 3,48 | 86,3 | 73,5 | 8,0 | 0,0 | 191 |
| +20 PV | 0,0 % | 3,84 | 91,3 | 86,7 | 16,0 | 0,3 | 212 |
| niveau 7 | 0,0 % | 3,35 | 75,0 | 63,5 | 23,8 | 3,5 | 177 |
| épique Furor au départ | 0,0 % | 4,06 | 98,2 | 93,2 | 17,2 | 0,3 | 227 |
| sans taxe (`tune=Druid.TAX=0`) | 0,0 % | 4,17 | 95,8 | 92,2 | 31,7 | 3,8 | 232 |
| soin du passage 100 % | 0,0 % | 3,05 | 70,3 | 60,7 | 6,0 | 0,0 | 165 |

Bot `heuristic` (joueur parfait, 300 expéditions, ± 5), compte neuf : Warrior 0,0 % (zone moyenne 4,10 ; Westfall
94,7, Stranglethorn 29,7, Swamp 2,3) ; Druid 0,0 % (4,17 ; 99,3, 21,0, 0,3).

### 4.2 Lecture

- **Au compte neuf, rien ne fait gagner** : aucun levier seul ne dépasse 0,2 % de victoires, ni au bot `human` ni
  au bot `heuristic`. Le mur est à Stranglethorn Vale (8 à 9 % de passage au compte neuf) et à Swamp of Sorrows
  (aucun levier n'y fait passer plus de 4 % des expéditions). C'est l'état « 0 % de l'arbre » voulu.
- **PV** : chaque +5 PV vaut ≈ +0,2 à +0,3 de zone moyenne et +7 à +10 points de Westfall battue ; +20 PV : Westfall
  61 → 90 % (Warrior), 70 → 91 % (Druid). Le passage de Stranglethorn monte peu (Warrior 8,9 → 25,8 % à +20 PV) :
  les PV règlent le début de campagne, pas le mur.
- **Contenu du niveau 7** : le meilleur levier contre le mur (passage de Stranglethorn Warrior 8,9 → 56,6 %, Druid
  7,9 → 37,5 %), alors qu'il pèse moins que +10 PV à Westfall. D'où le choix de garder le contenu au niveau (§ 1.3) :
  il arrive vers la 7e expédition quoi qu'il arrive.
- **Moteur de classe** : +1 mana par tour (Warrior) ou la taxe retirée (Druid) sont les plus gros leviers seuls (zone
  moyenne +1,45 et +1,24 ; Westfall 96 à 97 %). Un nœud qui touche la ressource ou le mana de la classe vaut donc
  beaucoup plus qu'un nœud générique : c'est là qu'il faut doser (§ 15).
- **Épique au départ** : Titan's Grip ≈ +12 PV, Death Wish ≈ +6 PV en zone moyenne ; Furor (Druid) vaut au début
  autant que la taxe retirée (Westfall 98 %) mais ne passe pas le mur (Stranglethorn 17 %) : la valeur d'une épique au
  départ dépend de l'épique, d'où un seul nœud (Veteran's Arsenal) en rangée 4.
- **Or et soin du passage** : ≈ +5 PV chacun au compte neuf (ils comptent davantage quand on traverse plus de zones) :
  nœuds d'un point.
- **Expérience** : le compte neuf rapporte 135 à 156 par expédition, 165 à 232 avec un levier ; en moyenne, une
  expédition du compte neuf rapporte plus d'un niveau au début de la table proposée (100 par niveau jusqu'au 6).

### 4.3 Paliers de l'arbre approchés par les leviers mesurables

Les nœuds de mécanique du Warrior (Rage au départ, plafond, Absorb par Rage, soin par Rage dépensée) ne se mesurent
pas sans code ; le Druid en a quatre réglables par `tune=` (`Druid.TAX_FREE`, `TAX_MAX`, `TAX`, `STRIKE_BASE`,
`TREE_ABSORB`). Proxies :

- **s60** (15 points, 10e expédition) : `zones=4 level=7` (tout le contenu, épiques des zones 1 à 4) + Toughness 3
  (Warrior `hp=82`, Druid `hp=68`) + Provisions (`START_GOLD=150`) + Field Medic (`ZONE_HEAL=0.75`) ; Druid en plus
  Natural Shapeshifter 2 (`TAX_FREE=2, TAX_MAX=1`), Feral Instinct 2 (`STRIKE_BASE=3`), Living Seed
  (`TREE_ABSORB=4`).
- **s60m** : s60 + `Combat.BASE_MANA=4` (+1 mana chaque tour), borne haute de ce qu'apportent les autres nœuds de
  mécanique des rangées 1 à 3.
- Field Medic est compté dans s60 alors que l'ordre conseillé le prend au 18e point (effet mesuré ≈ +5 PV au compte
  neuf) : s60 surestime un peu le palier.
- **s100** : `zones=7 level=7`, s60m, une épique au départ (Warrior Titan's Grip), Druid sans taxe (`TAX=0`).

Bot `human`, 600 ; battue / atteinte (%) des quatre zones durcies :

| Proxy | Victoires | Zone moy. | Stranglethorn | Swamp | Steppes | Blackrock | XP / exp. |
|---|---|---|---|---|---|---|---|
| Warrior s60 | 17,2 % | 5,50 | 78,3 | 69,5 | 65,0 | 50,6 | 317 |
| Warrior s60m (+1 mana) | 25,7 % | 5,86 | 80,2 | 77,6 | 70,7 | 58,4 | 344 |
| Warrior s100 | 72,2 % | 6,82 | 98,0 | 97,1 | 92,8 | 81,8 | 424 |
| Druid s60 | 6,7 % | 5,63 | 81,3 | 70,1 | 50,7 | 23,5 | 320 |
| Druid s60m (+1 mana) | 9,7 % | 5,72 | 82,7 | 69,9 | 57,0 | 29,6 | 327 |
| Druid s100 (sans taxe, +1 mana) | 11,8 % | 5,87 | 86,0 | 72,0 | 63,6 | 30,0 | 337 |
| Warrior s60m, Steppes et Blackrock à 1,9 | **45,3 %** | 5,98 | 80,2 | 77,6 | 89,7 | 81,2 | 360 |
| Druid s60m, Steppes et Blackrock à 1,9 | 30,7 % | 5,86 | 82,7 | 69,9 | 82,6 | 64,6 | 347 |

Pour mémoire (`docs/equilibrage.md`, « Mur des zones 4 à 7 », sans talents) : vétéran tout débloqué (`zones=7
level=7`) Warrior 7,2 %, Druid 0,5 % ; deuxième expédition (`zones=3 level=2`) Warrior 2,7 %, Druid 0,0 %.

Bot `heuristic` (300, ± 5), proxy s60m : Warrior **55,3 %** (zone moyenne 6,39 ; Stranglethorn 90,0, Swamp 88,6,
Steppes 87,5, Blackrock 79,3), Druid **43,3 %** (6,21 ; 91,0, 81,6, 75,4, 77,3). Le joueur parfait ne gagne qu'une
expédition sur deux au palier 60 % : l'écart avec le bot `human` (26 et 10 %) est attendu, la hauteur du mur ne l'est
pas.

## 5. La courbe est-elle atteignable avec le mur actuel ?

**Les deux bouts de la courbe tiennent** : 0 % de l'arbre = 0 victoire (même au bot `heuristic`) ; l'arbre plein
approché (Warrior s100) = 72 % pour une cible de 65–70 %.

**Le milieu ne tient pas avec le mur actuel** :

- **Warrior** : au palier 60 %, les nœuds mesurables (PV, or, soin du passage) donnent 17 % ; même en comptant les
  nœuds de mécanique des rangées 1 à 3 pour +1 mana à chaque tour (s60m, borne haute : Battle Ready, Anger Shield,
  Blood Drinker et Specialization ensemble valent sans doute moins), 26 %. Il manque ≈ 15 points. La perte se fait à
  Burning Steppes (71 %) et surtout contre Blackrock Mountain (58 %) : il faut ≈ 80 % dans chacune des quatre zones
  durcies pour 40 % de victoires de campagne (0,8 × 0,8 × 0,8 × 0,8 ≈ 0,41), quand les zones 1 à 3 passent presque
  toujours.
- **Druid** : 7 à 10 % au palier 60 %, et seulement 12 % avec tout (s100 : sans taxe, +1 mana, 68 PV, toutes les
  épiques). Blackrock Mountain ne passe qu'à 30 % quoi qu'on ajoute : c'est un défaut de la classe dans les zones 6 et
  7 (déjà vu le 19/11 : sans épique 10,5 % à Blackrock, Eclipse 0 %), pas un manque de talents. L'arbre ne peut pas
  le combler sans devenir le seul moteur de la classe.

**Ce qu'il faut bouger** (deux leviers, à trancher, § 16) :

1. **Le mur des zones 6 et 7** : Burning Steppes 2,15 → 1,9 et Blackrock Mountain 2,3 → 1,9 (Stranglethorn 1,45 et
   Swamp 1,8 inchangés). Mesuré au palier s60m : Warrior 26 → **45 %**, Druid 10 → 31 %. Ce n'est pas une difficulté
   conditionnelle (elle vaut pour tous, épique ou non) : le compte neuf bute toujours à la zone 4 (Stranglethorn
   inchangée : 8 à 9 % de passage au niveau 1). Effet de bord : la cible « vétéran sans épique » des zones 6 et 7
   (30 et 25 %, `docs/expedition.md`) monte ; non mesuré ici. Avec ce mur, les nœuds de mécanique des rangées 1 à 3
   doivent valoir ensemble ≈ +1 mana par tour (cible de réglage du lot 3).
2. **Sans toucher au mur** : des nœuds de mécanique plus forts (≈ deux fois s60m). Risque : l'arbre plein dépasse
   alors largement 70 % et la clé 0 devient triviale ; les clés devront absorber l'écart (§ 9).

**Druid à part** : quel que soit le choix, un lot de réglage des zones 5 à 7 du Druid (épiques Eclipse et Owlkin
Frenzy, défense de Balance, boss) avant de régler son arbre ; cible : Druid s60m à moins de 10 points du Warrior.

## 6. Arbre du Warrior (complet)

Mécanique : Rage de 0 à 5 (`resource.cap`), gardée d'un tour à l'autre, +1 à chaque perte de PV (`onHpLost`) et à
chaque Attack jouée (`onCardPlayed`) ; dépensée par `Spend N:` et `Surge:` ; Battle Standard (départ) : +1 Rage au
début de chaque combat ; Revenge moins chère après un tour blessé (`hurtCost`). 70 PV. Voies : Arms (Sundered, gros
coup, Execute), Fury (petites Attacks, Strength, PV payés), Protection (Absorb, Revenge, Shield Slam).

| Rangée (ouverte à) | Nœud | Rangs | Effet (texte de jeu, par rang) | Point d'accroche |
|---|---|---|---|---|
| 1 (0) | **Toughness** (générique) | 3 | `+4 max HP.` | PV de départ de l'expédition (`Expedition.new`) |
| 1 | **Battle Ready** | 2 | `Start of combat: +1 Rage.` | `onCombatStart` → `Combat.gainRes` (s'ajoute à Battle Standard : 3 Rage au tour 1, Heroic Strike payé tout de suite) |
| 1 | **Second Wind** | 2 | 1 : `After a combat won: heal 1 per 5 Rage you have.` 2 : `… heal 1 per 4 Rage you have.` (réglé le 19/11/2026 ; fiche : 1 et 2 par Rage) | fin de combat gagné (`Expedition` lit `c.player.res` avant de rendre les PV) |
| 2 (5) | **Unbridled Wrath** | 2 | `Rage cap +1.` | crochet `resCap` (5 → 7) |
| 2 | **Anger Shield** | 2 | 1 : `End of turn: gain 1 Absorb per 5 Rage.` 2 : `End of turn: gain 1 Absorb per 4 Rage.` (réglé ; fiche : par 2 Rage, par Rage) | `onTurnEnd` → `Combat.gainBlock` (Skullflame Shield, rare du niveau 7 : 2 Absorb par Rage au début du tour) |
| 2 | **Provisions** (générique) | 1 | `Start each expedition with 100 more gold.` | or de départ (`X.START_GOLD`) |
| 3 (10) | **Specialization** (choix) | 1 | Arms : `Sundered enemies take 50% more damage instead of 25%.` Fury : `While you have 5 Rage or more, Attacks deal 1 more per hit.` (réglé ; fiche : 3 Rage) Protection : `Cards that give Absorb give 2 more.` | Arms : multiplicateur de Sundered (crochet `damage` sur la cible) ; Fury : `damage` ; Protection : `block` |
| 3 | **Tactical Mastery** | 2 | 1 : `Up to 2 Rage carries over to the next combat.` 2 : `Up to 4 Rage carries over to the next combat.` | état d'expédition (`exp.talentState.rage`), posé en fin de combat, rendu par `onCombatStart` |
| 3 | **Blood Drinker** | 2 | 1 : `Each time you pay a Spend cost: heal 1.` 2 : `Each time you spend Rage: heal 1.` (Surge compris ; réglé ; fiche : 1 puis 2) | `onResource` (variation négative) → `Combat.heal` |
| 3 | **Field Medic** (générique) | 1 | `Moving to the next zone heals 75% of max HP instead of 50%.` | `X.ZONE_HEAL` lu par `Expedition.enterZone` |
| 4 (16) | **Rampage** | 2 | 1 : `Start of turn with 5 Rage or more: +1 mana.` 2 : `Start of turn with 5 Rage or more: +1 mana and draw 1.` | `onTurnStart` + crochet `maxMana` (celui de la taxe du Druid) |
| 4 | **Veteran's Arsenal** (générique) | 2 | 1 : `Start each expedition with one Epic card of a zone you have beaten.` 2 : `You can carry one more Epic card.` | phase `start` (choix parmi les épiques débloquées) ; 2 : plafond d'épiques (code en cours) |
| 4 | **Unyielding** | 2 | 1 : `Once per expedition, a hit that would kill you leaves you at 1 HP and gives 5 Rage.` 2 : `… at 1 HP with 15 Absorb and 5 Rage.` | `preventDeath` + drapeau d'expédition |

Total 24 points (3 + 2 + 2 / 2 + 2 + 1 / 1 + 2 + 2 + 1 / 2 + 2 + 2). Nœuds de mécanique : 9 sur 13 (15 points sur
24).

Ordre conseillé (et ordre du bot de simulation) : Toughness, Battle Ready, Second Wind (rangée 1, 7 points), puis
Anger Shield, Unbridled Wrath, Provisions (12), Specialization, Blood Drinker, Tactical Mastery (17), Field Medic, puis
la rangée 4. Le palier 60 % (15 points) = Toughness 3, Battle Ready 2, Second Wind 2, Unbridled Wrath 2, Anger Shield
2, Provisions 1, Specialization, Blood Drinker 2.

Ce que chaque nœud change en jeu, concrètement (chiffres de la fiche ; ceux du code, réglés le 19/11/2026 : tableau
ci-dessus, `Data/Talents/warrior.lua` et `docs/equilibrage.md`, « Talents du Warrior : courbe par palier ») :

- Battle Ready 2 : le premier tour de chaque combat commence à 3 Rage ; Heroic Strike fait 12 au lieu de 7 dès le
  tour 1.
- Second Wind 2 : un combat fini à 5 Rage rend 10 PV ; sur 8 combats par zone, ≈ 30 à 50 PV rendus par zone.
- Unbridled Wrath 2 : la Rage gagnée au-delà de 5 n'est plus perdue (un tour blessé de 3 coups + 3 Attacks donne 6) ;
  les cartes `Surge:` (Execute, Ignore Pain) comptent jusqu'à 7 : Ignore Pain fait 21 Absorb au lieu de 15.
- Anger Shield 2 : finir le tour à 5 Rage donne 5 Absorb avant le tour ennemi (un Defend gratuit par tour).
- Blood Drinker 2 : Heroic Strike payé (Spend 2) rend 2 PV ; un Surge rend 2 PV.
- Tactical Mastery 2 : un combat fini à 4 Rage ou plus commence le suivant à 4 + Battle Standard + Battle Ready.
- Rampage : à 5 Rage au début du tour, 4 mana au lieu de 3.

## 7. Arbre du Druid (complet)

Mécanique : forme (Cat, Bear, Moonkin, Tree of Life ; sans forme au début du combat) prise en jouant une carte de
cette forme ; réserve commune de 0 à 5 (`wild`), nommée Combo / Frenzy / Charge selon la forme ; effet de fin de
tour selon la forme (Bear : frappe de `STRIKE_BASE` + réserve puis +1 ; Cat : Clearcasting ; Moonkin : ceil(réserve
/ 2) à tous, `PULSE_MAX` 3 au plus ; Tree : `TREE_ABSORB` 2 Absorb) ; taxe : au-delà de `TAX_FREE` (1) changement
compté par tour, `TAX` (1) mana de moins au tour suivant, `TAX_MAX` (2) au plus, Cat ↔ Bear hors taxe ; Idol of the
Wild (départ) : la première carte qui change de forme dans un combat coûte 0. 59 PV.

| Rangée (ouverte à) | Nœud | Rangs | Effet (texte de jeu, par rang) | Point d'accroche |
|---|---|---|---|---|
| 1 (0) | **Toughness** (générique) | 3 | `+3 max HP.` | PV de départ de l'expédition |
| 1 | **Primal Instinct** | 2 | `Start of combat: +1 Reserve.` | `onCombatStart` → `Combat.gainRes` (lu comme Combo, Frenzy ou Charge à la première forme) |
| 1 | **Natural Shapeshifter** | 2 | 1 : `One more form change each turn is free of the shift tax.` 2 : `The shift tax costs at most 1 mana.` | `Druid.TAX_FREE` 1 → 2 ; `Druid.TAX_MAX` 2 → 1 (lus par l'état du combat, pas par la constante globale) |
| 2 (5) | **Feral Instinct** | 2 | `Bear strikes deal 1 more.` | crochet `bearStrike` (celui d'Idol of Brutality) ; `STRIKE_BASE` 1 → 3 |
| 2 | **Moonglow** | 1 | `End of turn in Moonkin: gain 2 Absorb.` | `onTurnEnd` selon la forme (Idol of the Moon, inhabituel du niveau 5, en donne 4) : la défense qui manque à Balance |
| 2 | **Living Seed** | 1 | `End of turn in Tree of Life: gain 2 more Absorb.` | `TREE_ABSORB` 2 → 4 |
| 2 | **Provisions** (générique) | 1 | `Start each expedition with 100 more gold.` | or de départ |
| 3 (10) | **Specialization** (choix) | 1 | Feral : `Clearcasting also gives +1 Combo.` Balance : `End of turn in Moonkin: deal 1 more to each enemy.` Restoration : `Regen you gain is 1 higher.` | Feral : `onTurnEnd` en Cat ; Balance : `PULSE_MAX` + 1 et +1 au coup ; Restoration : `applySelf` (comme Benediction du Priest) |
| 3 | **Wild Reserve** | 2 | `Reserve cap +1.` | crochet `resCap` (5 → 7 ; avec Heart of the Wild, +1 au plafond de chaque réserve) |
| 3 | **Shapeshifter's Ward** | 2 | 1 : `Each form change: gain 1 Absorb.` 2 : `Each form change: gain 2 Absorb.` | `onShift` (Idol of the Wild, Wolfshead Helm, Furor) ; Cat ↔ Bear compris |
| 3 | **Field Medic** (générique) | 1 | `Moving to the next zone heals 75% of max HP instead of 50%.` | `X.ZONE_HEAL` |
| 4 (16) | **Master Shapeshifter** | 2 | 1 : `Two more form changes each turn are free of the shift tax.` 2 : `Form changes no longer cost mana.` | `TAX_FREE` 2 → 4, puis `TAX` 0 |
| 4 | **Veteran's Arsenal** (générique) | 2 | comme le Warrior | phase `start`, plafond d'épiques |
| 4 | **Survival Instincts** | 2 | 1 : `Once per expedition, a hit that would kill you leaves you at 1 HP in Bear.` 2 : `… at 1 HP in Bear with 10 Absorb.` | `preventDeath` + drapeau d'expédition (Rebirth reste le Last Breath de combat) |

Total 24 points (3 + 2 + 2 / 2 + 1 + 1 + 1 / 1 + 2 + 2 + 1 / 2 + 2 + 2). Nœuds de mécanique : 10 sur 14 (15 points).

Ordre conseillé : Natural Shapeshifter, Toughness, Primal Instinct (7), Feral Instinct, Moonglow, Living Seed,
Provisions (12), Specialization, Shapeshifter's Ward, Wild Reserve (17), Field Medic, puis la rangée 4. Palier 60 % (15
points) : rangées 1 et 2 pleines, Specialization, Shapeshifter's Ward 2.

Concrètement :

- Natural Shapeshifter 2 : Moonkin → Bear → Tree dans un même tour coûte 0 mana au tour suivant (aujourd'hui 1) ;
  quatre formes dans un tour coûtent 1 (aujourd'hui 2). La taxe coûtait 35 points au bot `human` (`docs/equilibrage.md`,
  « Druid : voies seules ») ; elle reste un choix (Master Shapeshifter la retire en rangée 4).
- Feral Instinct 2 : la frappe de fin de tour en Bear fait 3 + réserve au lieu de 1 + réserve.
- Moonglow : finir en Moonkin protège de 2 (Balance seule n'a aujourd'hui de défense qu'Insect Swarm et Faerie Fire).
- Shapeshifter's Ward 2 : trois changements dans un tour donnent 6 Absorb.
- Voies de soin et de tank : Living Seed et Specialization Restoration renforcent Tree of Life sans le rendre jouable
  seul (Absorb, pas de soin entre les combats) ; Feral Instinct sert Bear comme frappe, pas comme mur.

## 8. Nœuds propres des quatre autres classes

Même gabarit : les quatre nœuds génériques (Toughness, Provisions, Field Medic, Veteran's Arsenal ; 9 points), un
Specialization, un nœud « une fois par expédition » en rangée 4, et 7 à 8 nœuds de mécanique pour les 13 à 14 points
restants. Effets en une ligne ; chiffres à régler à la mesure.

**Priest** (36 PV ; Insanity sans plafond ni baisse, gagnée par les cartes Shadow, dépensée par `Surge:` ; Atonement :
chaque carte qui inflige des dégâts soigne `Combat.ATONEMENT_HEAL` = 2 ; Sacred Candle : Atonement 1 au début du
combat ; Regen, Absorb, Cast)

**Arbre codé et réglé le 19/11/2026** (`Data/Talents/priest.lua`, nombres dans `ns.PriestTalents` ; tests :
`Sim/tests_talents_priest.lua` ; mesures : `docs/equilibrage.md`, « Talents du Priest : courbe par palier »). 14
nœuds, 24 points (3 + 2 + 2 / 2 + 1 + 1 + 1 / 1 + 2 + 2 + 1 / 2 + 2 + 2) ; 10 nœuds de mécanique (15 points).

| Rangée (ouverte à) | Nœud | Rangs | Effet (texte de jeu, par rang) | Point d'accroche |
|---|---|---|---|---|
| 1 (0) | **Toughness** (générique) | 3 | `+2 max HP.` (+6 au rang 3) | PV de départ de l'expédition |
| 1 | **Twin Disciplines** | 2 | `Atonement heals 4 instead of 2.` / `… 6 instead of 2.` | constante `ATONEMENT_HEAL` (`Combat.const`) |
| 1 | **Borrowed Time** | 2 | `Start of combat: gain Atonement 2.` / `… Atonement 4.` | `onCombatStart` → `applyStatus` (s'ajoute à Sacred Candle) |
| 2 (5) | **Mind Spike** | 2 | `Start of combat: +2 Insanity.` / `… +4 Insanity.` | `onCombatStart` → `Combat.gainRes` |
| 2 | **Shadow Weaving** | 1 | `The second Shadow card each turn: +1 Insanity.` | `onCardCommitted` (`c.turn.bySchool.shadow`) |
| 2 | **Inspiration** | 1 | `Start of combat: gain Regen 4.` | `onCombatStart` (premier tic au début du premier tour ; Benediction s'y ajoute) |
| 2 | **Provisions** (générique) | 1 | `Start each expedition with 100 more gold.` | or de départ |
| 3 (10) | **Specialization** (choix) | 1 | Discipline : `Each Atonement heal also gives 2 Absorb.` Shadow : `Shadow cards deal 5 more per hit and apply 5 more DoT.` Holy : `Holy cards deal 8 more per hit.` | Discipline : `onCardPlayed` (carte qui a infligé des dégâts sous Atonement) ; Shadow : `damage` et `apply` ; Holy : `damage` |
| 3 | **Void Torrent** | 2 | `Surge cards count 1 more Insanity.` / `… 2 more Insanity.` | crochet `surge` (comme Anathema) |
| 3 | **Power Word: Barrier** | 2 | `Cards that give Absorb give 2 more.` / `… 4 more.` | `block`, une fois par carte (`c.cardCtx`) ; ni sur l'Absorb de Discipline ni sur l'Absorb sans carte |
| 3 | **Field Medic** (générique) | 1 | `Moving to the next zone heals 75% of max HP instead of 50%.` | `zoneHeal` |
| 4 (16) | **Spiritual Guidance** | 2 | `When a Cast card resolves: gain 3 Absorb.` / `… 5 Absorb.` | `onCastResolved` (comme Truefaith Vestments) |
| 4 | **Veteran's Arsenal** (générique) | 2 | comme le Warrior | phase `start` |
| 4 | **Guardian Spirit** | 2 | `Once per expedition, a hit that would kill you leaves you at 1 HP with Atonement 3.` / `… with Atonement 3 and Regen 6.` | `preventDeath` + `c.tstate.guardian` |

Ordre du bot : Toughness 3, Twin Disciplines 2 (5 points), Borrowed Time 2, Mind Spike 2, Shadow Weaving (10),
Inspiration, Provisions, Specialization (Discipline), Power Word: Barrier 2 (15), Void Torrent 2, Field Medic (18),
Spiritual Guidance 2 (20), Veteran's Arsenal 2, Guardian Spirit 2. Palier 60 % : rangées 1 et 2 pleines,
Specialization, Power Word: Barrier 2. Pas de `bot.value`, `bot.won` ni `bot.epic` (essayés, sans gain :
`docs/equilibrage.md`).

Écarts avec la proposition d'origine (chiffres réglés à la mesure) : Twin Disciplines passe en rangée 1 et rend +2 par
rang (proposé : 3 au lieu de 2, un rang) ; Borrowed Time devient un Atonement de début de combat (2 par rang ;
proposé : Sacred Candle à 2) ; Mind Spike passe en rangée 2, +2 par rang ; Inspiration donne Regen 4 au début du
combat (proposé : `Regen you gain is 1 higher.`, ≈ 0 point seul) ; Power Word: Barrier 2 rangs de +2 ;
Specialization Discipline 2 Absorb par soin (proposé : 1), Shadow « +5 par coup et +5 DoT » (proposé : DoT +1,
≈ 0 point seul), Holy « +8 par coup des cartes Holy » (proposé : soin des cartes Cast, ≈ 0 point seul : 0,3 à 0,9
incantation par combat) ; Spiritual Guidance 2 rangs (3 / 5) ; Guardian Spirit rang 2 : Regen 6 en plus.

**Mage** (42 PV ; Charges 0 à 4, +1 dégât par Charge sur chaque coup des Attacks, dépensées par `Surge:` ; deux Casts
en même temps (`castSlots` + 1) ; Frozen = Stunned ou Demoralized ; Hot Streak, Instant, Ignite ; Apprentice Wand : le
premier Cast de chaque combat coûte 0). **Arbre codé le 19/11/2026** (`Data/Talents/mage.lua`, nombres dans
`ns.MageTalents` ; tests : `Sim/tests_talents_mage.lua` ; mesures : `docs/equilibrage.md`, « Talents du Mage ») :

| Rangée (ouverte à) | Nœud | Rangs | Effet (texte de jeu, par rang) | Point d'accroche |
|---|---|---|---|---|
| 1 (0) | **Toughness** (générique) | 3 | `+2 max HP.` (+2 / +4 / +6) | PV de départ de l'expédition |
| 1 | **Arcane Mind** | 3 | `Charge cap +1.` / `+2` / `+3` | crochet `resCap` (4 → 7) |
| 2 (5) | **Arcane Concentration** | 3 | `After each Surge: +1 Charge.` / `+2 Charges.` / `+3 Charges.` | `onSurge` (après la remise à 0, avant les effets suivants de la carte) |
| 2 | **Provisions** (générique) | 1 | `Start each expedition with 100 more gold.` | or de départ |
| 3 (10) | **Specialization** (choix) | 1 | Fire : `Fire Attack hits also apply DoT 1.` Frost : `Start of combat: apply Demoralized 1 to the first enemy.` Arcane : `While you have 4 Charges or more, Attacks deal 1 more per hit.` | Fire : `onAttackHit` (comme Ignite) ; Frost : `onCombatStart` (premier ennemi vivant) ; Arcane : `damage` |
| 3 | **Winter's Chill** | 2 | `Attack hits on Frozen enemies deal 1 more.` / `2 more.` | `damage` + `Combat.isFrozen` (comme la carte Shatter) |
| 3 | **Prismatic Cloak** | 1 | `When a Cast card resolves, gain 2 Absorb.` | `afterCast` (incantée ou partie tout de suite) |
| 3 | **Arcane Focus** | 1 | `Start of combat: +1 Charge.` | `onCombatStart` → `Combat.gainRes` |
| 3 | **Frost Warding** | 1 | `Cards that give Absorb give 1 more.` | `block` une fois par carte (`c.cardCtx`, comme Protection du Warrior) |
| 3 | **Field Medic** (générique) | 1 | `Moving to the next zone heals 75% of max HP instead of 50%.` | `zoneHeal` |
| 4 (16) | **Firestarter** | 1 | `Start of combat: gain Instant 1.` | `onCombatStart` (comme Fire Ruby) |
| 4 | **Arcane Potency** | 2 | `Start of turn with 4 Charges or more: +1 mana.` / `… +1 mana and draw 1.` | `maxMana`, `drawPerTurn` (comme Rampage ; Mind Quickening Gem s'y ajoute) |
| 4 | **Veteran's Arsenal** (générique) | 2 | comme le Warrior | phase `start` |
| 4 | **Cauterize** | 2 | `Once per expedition, a hit that would kill you leaves you at 1 HP with Ice Block.` / `… at 10 HP with Ice Block.` | `preventDeath` + `exp.talentState.cauterize` ; après la carte Ice Block (les Powers passent avant les talents) |

Total 24 points (3 + 3 / 3 + 1 / 1 + 2 + 1 + 1 + 1 + 1 / 1 + 2 + 2 + 2), 14 nœuds ; nœuds de mécanique : 10 sur 14 (15
points). Ordre du bot (`bot.order`) : Toughness 3, Arcane Mind 2, Arcane Concentration 3, Provisions, Arcane Mind 3
(10), Specialization, Winter's Chill 2, Prismatic Cloak, Arcane Focus (15), Frost Warding, Field Medic, Firestarter,
Arcane Potency 2 (20), Veteran's Arsenal 2, Cauterize 2 ; voie du bot : **Arcane** (`bot.spec`). Bots : `bot.value`
de Prismatic Cloak (incantation tenue = son Absorb à venir) et d'Arcane Potency (finir le tour à 4 Charges = un mana).
Pas de `bot.epic` : à l'arbre plein, le bot ne prend aucune épique qui contredise l'arbre (palier 100 % au-dessus du
palier 80 %).

Écarts avec la proposition ci-dessus (réglés à la mesure, `docs/equilibrage.md`) : Arcane Focus et un Absorb par carte
dans les rangées 1 et 2 faisaient gagner 56 à 61 % au palier 40 % (cible ≈ 23) : les nœuds forts (Charges au départ,
Absorb, Instant) passent en rangées 3 et 4, à un rang, et les rangées 1 et 2 ne gardent que le plafond de Charges et
Arcane Concentration (nouveau, Surge). Presence of Mind (carte), Shatter (carte) et Ice Barrier (carte) deviennent
Firestarter, Winter's Chill et Frost Warding (noms de talents de WoW, pas de nom de carte en double) ; Arcane Shielding
devient Prismatic Cloak (2 Absorb) ; Improved Ignite (une carte rare seulement) et Triple Cast (pas un talent de WoW)
retirés. Specialization Fire : DoT sur chaque coup Fire au lieu de Hot Streak (rarement pris par le bot) ; Frost : le
premier ennemi au lieu de tous (69,5 % contre 60 % aux deux autres voies).

**Rogue** (57 PV ; Combo 0 à 5, dépensé par `Surge:` ; Stealth au début de chaque combat, consommé par la première
Attack ; Parry : 3 charges au plus, chacune arrête 8 dégâts d'un coup (`PARRY_MAX`, `PARRY_STOP`) ; Thieves' Tools :
+1 carte au premier tour)

Arbre codé le 19/11/2026 (`Data/Talents/rogue.lua`, nombres dans `ns.RogueTalents` ; tests :
`Sim/tests_talents_rogue.lua` ; mesure : `docs/equilibrage.md`, « Talents du Rogue »). Tableau de l'arbre tel que codé :

| Rangée (ouverte à) | Nœud | Rangs | Effet (texte de jeu, par rang) | Point d'accroche |
|---|---|---|---|---|
| 1 (0) | **Toughness** (générique) | 3 | `+2 max HP.` (+2 par rang) | PV de départ |
| 1 | **Opportunity** | 2 | `Attacks played in Stealth deal 1 more per hit.` / `… 2 more per hit.` | `damage` : la carte en cours (`c.cardCtx`) est dans `c.cls.openers` (Stealth consommé, ou gardé sous Subterfuge) ; bot : Stealth gardé vaut le bonus (`bot.value`) |
| 1 | **Deeper Stratagem** | 2 | `Combo cap +1.` / `Combo cap +2.` | `resCap` (5 → 7) |
| 2 (5) | **Vile Poisons** | 1 | `Each time DoT is applied to an enemy, apply 1 more.` | `apply` (comme Crystal Vial, qui s'ajoute) |
| 2 | **Combat Readiness** | 3 | `Each Parry stops up to 9 damage.` / `… 10 …` / `… 11 …` | `const.PARRY_STOP` (8 → 11) |
| 2 | **Provisions** (générique) | 1 | `Start each expedition with 100 more gold.` | or de départ |
| 3 (10) | **Specialization** (choix) | 1 | Assassination : `Each Surge applies DoT 1 per Combo spent to its target.` Combat : `Each Parry: +1 Combo.` Subtlety : `Each time a card grants Stealth, draw 1.` | Assassination : `onSurge` (crochet `apply` compris) ; Combat : `onParry` ; Subtlety : `onStatusApplied` + `c.cls.stealthGained` (pas le Stealth du début de combat ; s'ajoute à Flash Powder) |
| 3 | **Elusiveness** | 1 | `Start of combat: gain Parry 1.` | `onCombatStart` (comme Blinding Powder) |
| 3 | **Initiative** | 2 | `Start of combat: +1 Combo.` / `Start of combat: +1 Combo, +2 against elites and bosses.` | `onCombatStart` ; rang 2 : `c.kind` = `elite` ou `boss` |
| 3 | **Lightning Reflexes** | 1 | `Parry can hold 1 more charge.` | `const.PARRY_MAX` (3 → 4 ; `maxKey` de l'état Parry) |
| 3 | **Field Medic** (générique) | 1 | `Moving to the next zone heals 75% of max HP instead of 50%.` | `zoneHeal` |
| 4 (16) | **Relentless Strikes** | 2 | `After a Surge of 5 Combo or more: +1 Combo.` / `After each Surge: +1 Combo.` | `onSurge` (montant dépensé) |
| 4 | **Veteran's Arsenal** (générique) | 2 | comme le Warrior | phase `start` |
| 4 | **Cheat Fate** | 2 | `Once per expedition, a hit that would kill you leaves you at 1 HP with Parry 2.` / `… with Parry 3 and Stealth.` | `preventDeath` + `c.tstate.cheatFate` ; Cheat Death (Power, Last Breath de combat) passe avant |

Total 24 points (3 + 2 + 2 / 1 + 3 + 1 / 1 + 1 + 2 + 1 + 1 / 2 + 2 + 2), 14 nœuds ; nœuds de mécanique : 8 (+
Specialization et Cheat Fate). Ordre du bot (`bot.order`) : Toughness 3, Opportunity 2 (5 points), Deeper Stratagem
2, Provisions, Combat Readiness 2 (10), Specialization, Elusiveness, Initiative 2, Lightning Reflexes (15), Vile
Poisons, Combat Readiness 3, Field Medic, Relentless Strikes 2 (20), Veteran's Arsenal 2, Cheat Fate 2 ; voie du bot :
Combat. Pas d'accord d'épiques (`bot.epic`) : Veteran's Arsenal ne fait pas prendre de mauvaise épique au bot (arbre
plein 98,3 % avec, 92,5 % sans).

Écarts avec la proposition d'origine (ci-dessous pour mémoire), tous pour la mesure : noms de WoW sans doublon avec
une carte ou une épique (Premeditation → **Initiative**, carte du même nom ; Deflection → **Lightning Reflexes**,
épique du même nom ; Riposte Training → **Combat Readiness**) ; les nœuds les plus forts (Elusiveness, Initiative)
passent en rangée 3 et Relentless Strikes en rangée 4, les rangées 1 et 2 gardent les plus faibles ; chiffres
abaissés (Opportunity 4 → 1 par rang et par coup, Combat Readiness 3 dégâts → 1 par rang, Elusiveness et Lightning
Reflexes à un rang, Initiative rang 2 seulement contre élites et boss, Relentless Strikes rang 1 seulement après un
Surge de 5 Combo, Toughness +2 PV par rang).

Proposition d'origine : Premeditation `Start of combat: +1 Combo.` (2 rangs) ; Deeper Stratagem `Combo cap +1.` ;
Relentless Strikes `After each Surge: +1 Combo.` ; Opportunity `Attacks that consume Stealth deal 4 more.` ;
Deflection `Parry can hold 4 charges.` ; Riposte Training `Each Parry stops up to 11 damage.` ; Elusiveness `Start of
combat: Parry 1.` ; Vile Poisons `DoT you apply: +1.` ; Specialization Assassination `Each Surge: apply DoT 1 per Combo
spent.` / Combat `Each Parry: +1 Combo.` / Subtlety `When you gain Stealth: draw 1.` ; rangée 4 : Cheat Fate `Once per
expedition, a hit that would kill you leaves you at 1 HP with Stealth and Parry 2.`

**Hunter** (56 PV ; Frenzy 0 à 5, +1 à chaque attaque du familier, −1 à la fin de chaque round ; familier : coup de
`Hunter.PET_BASE` (1) + Frenzy à la fin du tour ; Traps : 3 emplacements (`TRAP_SLOTS`) ; Careful Aim : cible
au-dessus de la moitié de ses PV ; Pet Whistle : le familier attaque au début du premier tour)

- **Ferocity** : `Pet attacks deal 1 more.` (2 rangs ; `PET_BASE` 1 → 3)
- **Spirit Bond** : `Each pet attack: heal 1.` (`onPetAttack`)
- **Bestial Discipline** : `Frenzy drops only every other round.` (`onRoundEnd` de la classe)
- **Kindred Spirits** : `Start of combat: +1 Frenzy.` (comme Kibler's Bits)
- **Frenzy Mastery** : `Frenzy cap +1.` (`resCap`, 5 → 6)
- **Trap Mastery** : `+1 Trap slot.` (`trapSlots`)
- **Lock and Load** : `The first Trap each combat costs 0.` (comme Net-o-Matic ; fusionnable avec Trap Mastery)
- **Hawk Eye** : `Careful Aim: targets above 40% HP.` (verdict du `beforeCard` de la classe)
- Specialization : Beast Mastery `When Frenzy reaches 5: the pet attacks.` / Marksmanship `Careful Aim Attacks deal 2
  more per hit.` / Survival `Traps also deal 4 to the attacker.` ; rangée 4 : **Feign Death** (talent) `Once per
  expedition, a hit that would kill you leaves you at 1 HP and skips the enemy turn.`

## 9. Clés 1 à 5

- **Rôle** (proposé) : l'arbre sert à finir la clé 0 ; les clés prennent le relais après la première victoire. Elles
  s'ouvrent quand le joueur a ≈ 60 à 80 % de l'arbre ; l'arbre plein arrive pendant les clés 1 à 3.
- **Ce que vaut un arbre plein à la clé 0** : cible 65–70 % au bot `human` (§ 3), ≈ 97–98 % au bot `heuristic` : la
  clé 0 est résolue pour un joueur parfait, comme aujourd'hui avec tout débloqué avant le mur.
- **Recalage nécessaire** : les affixes (`Meta.AFFIX`) ont été réglés à « ≈ −5 points par clé » sur Westfall seule
  (12/11/2026). Depuis le mur, Fortified et Tyrannical s'ajoutent à des facteurs de 1,45 à 2,3 (non mesuré,
  `docs/equilibrage.md`) : la clé +1 coûtera bien plus que 5 points dans les zones 4 à 7. À recaler **une fois
  l'arbre codé**, avec l'arbre plein (`tree=100 key=N`, § 12), pour ≈ −8 à −10 points par clé au bot `human` (70 % à
  la clé 0 → ≈ 25 % à la +5).
- L'expérience garde son bonus de clé (+15 % par clé) ; au niveau 25 elle ne donne plus rien. Options : la laisser
  sans effet (défaut) ; ou un rang de plus à certains nœuds par victoire à une nouvelle clé (« Keystone ranks »),
  ce qui ferait des clés une source de force et rendrait leur recalage plus difficile. Question au joueur (§ 16).

## 10. Rencontres et points de passage débloqués par les expéditions

### 10.1 Ce qui existe

- **Commun du compte par zone gagnée** (`tier` = première victoire du compte dans la zone N) : rencontres, cartes
  neutres, bibelots communs, potions ; avantages `Meta.PERKS` (bibelot au choix au départ : zone 3 ; un bibelot de plus
  chez le marchand : zone 6). Zones 4, 5 et 7 ne donnent rien aujourd'hui.
- **Drapeaux de compte** (`meta.flags`) : rencontres à histoire (`once`, suites par `when = { flag }`), reportés à chaque
  boss battu et en fin d'expédition, jamais retirés ; copie figée au départ (`exp.flags`).
- Simulation : `zones=N` pose le commun des N premières zones et les drapeaux d'un vétéran dès N ≥ 1.
- Écran entre deux zones (phase `transit`) : soin de 50 %, aucun choix.

### 10.2 Propositions (hauts faits du compte, hors de l'arbre)

Les déblocages de contenu passent par des **hauts faits du compte** (drapeaux `ach:<id>` posés par `Meta.bank` /
`Meta.record` d'après `exp.stats`), pas par l'arbre : l'arbre reste aux mécaniques de classe, et un haut fait profite
à toutes les classes. Chaque haut fait se voit dans l'écran Progress (condition affichée tant qu'il manque).

| Déblocage | Ce que c'est | Haut fait qui l'ouvre |
|---|---|---|
| **Forward Camp** (point de passage) | l'écran entre deux zones propose : `Rest: heal 50% of max HP.` ou `Train: upgrade a card, heal 25% of max HP.` | atteindre Stranglethorn Vale (toute classe) |
| **Quartermaster** (point de passage) | un marchand réduit (3 cartes, 2 potions, retrait de carte) sur l'écran entre deux zones, une fois par expédition, aux zones 4 à 7 | dépenser 500 po dans une expédition |
| **Scout's Report** (rencontre, une par zone) | dans une zone où le compte a perdu 3 fois : `Learn the threat: gain a potion suited to <zone>.` (potions à créer, par exemple Smelling Salts contre Slumber, Fire Resistance Potion contre Wildfire) | perdre 3 fois dans cette zone (aide à passer le mur par l'expérience du joueur, pas par une baisse de difficulté) |
| **Bounty Board** (rencontre, zones 2 à 7) | `Fight an elite. Win: choose one of 2 Epic cards.` (combat d'élite `event_*` de la zone) | obtenir une première carte épique |
| **Trainer** (rencontre, zones 3 à 7) | `Pay 60 gold: upgrade a card twice.` | monter une carte à +2 |
| **Shrine** (genre de case, zones 4 à 7, à la place d'une rencontre sur deux chemins) | `Remove a card.` ou `+4 max HP.` | battre le boss de Stranglethorn Vale (toute classe) |
| **Forge** (feu de camp) | au feu de camp, `Upgrade a card that is already upgraded.` compte pour une seule action | battre 20 élites (compte) |

- Les trois premiers changent ce qui se passe entre deux zones, là où le mur se joue (PV à l'entrée de Stranglethorn
  ≈ 60/75 au Warrior compte neuf).
- Les rencontres utilisent le format existant (`Data/Events.lua`, `when = { flag = "ach:…" }`) ; Forward Camp,
  Quartermaster, Shrine et Forge demandent du code d'expédition (phase `transit`, `X.NODE_KINDS`, feu de camp).
- Alternative : les rattacher aux zones 4, 5 et 7, qui ne donnent rien au compte aujourd'hui (même mécanisme que
  `tier`). Plus simple à coder, mais tout arrive à la première victoire de la zone, pas à l'usage.

## 11. Interface (en mots ; maquettes avant tout changement de disposition)

- **Où l'arbre s'ouvre** : écran Progress de la classe, troisième onglet **Talents** (à côté de Cards et Zones) ; un
  bouton « Talents » sur l'accueil quand des points sont à dépenser (pastille avec le nombre).
- **L'arbre** : quatre rangées horizontales, nœuds en icônes rondes avec leurs rangs (`2/3`) ; rangée verrouillée
  grisée avec sa condition (`Spend 10 points to unlock.`) ; infobulle = nom, texte du rang actuel et du suivant ;
  clic = un rang ; bouton `Reset talents` (gratuit hors expédition) ; points restants en haut.
- **Specialization** : un nœud à trois faces (icônes des trois voies), clic = choix, infobulle des trois textes.
- **Fin d'expédition** (bilan) : la barre d'expérience avance, une ligne par niveau gagné (`Warrior reaches level 9!
  +1 talent point.`), un bouton `Spend talent points` vers l'onglet Talents ; les déblocages de cartes restent
  dans la vitrine actuelle.
- **Pendant l'expédition** : les talents actifs dans le panneau du deck (liste courte, en lecture seule), et sur la
  pastille de classe quand un talent change un chiffre de la ressource (`Rage cap 7`).
- **Hauts faits** : quatrième onglet ou section de l'onglet Zones ; un nouveau haut fait dans le bilan (`New:
  Forward Camp.`).

Écrans à maquetter : (1) onglet Talents de l'écran Progress, arbre plein et arbre neuf ; (2) infobulle de nœud et
nœud Specialization ; (3) bilan de fin d'expédition avec niveau et points gagnés ; (4) accueil avec la pastille
« points à dépenser » ; (5) panneau du deck avec les talents actifs ; (6) écran entre deux zones avec Forward Camp et
Quartermaster ; (7) liste des hauts faits.

## 12. Points d'accroche dans le code

- **Méta** (`Core/Meta.lua`) : `Meta.XP_LEVELS` (25 seuils), `Meta.MAX_LEVEL` ; nouveau `Meta.CONTENT_LEVELS = { 1, 2,
  3, 5, 7, 9, 11 }` (niveau de classe auquel s'ouvre le palier de contenu n) et `Meta.contentTier(niveau)` ;
  `Meta.unlocks` rend `level = contentTier(levelOf)` (le champ `level` des cartes ne bouge pas) et `talents` ;
  `Meta.talentPoints(meta, classe)` (= niveau − 1), `Meta.spent`, `Meta.learn(meta, classe, nœud)`, `Meta.reset` ;
  `Meta.record` rend aussi `pointsGained`. Titre « Veteran » au niveau 25.
- **Données** : `Data/Talents/<classe>.lua` (ou une section du fichier de classe) : `ns.Talents[classe] = { rows = {
  0, 5, 10, 16 }, nodes = { { id, row, ranks, name, text = { … }, hooks / run / start / onExpStart } } }` ; génériques
  dans `Data/Talents/common.lua`.
- **Sauvegarde** : `cs.talents = { [nœud] = rang }`, `cs.spec = "<voie>"` ; `exp.unlock.talents` (copie figée) ;
  `exp.talentState` (Rage gardée, « une fois par expédition »).
- **Départ d'expédition** (`Expedition.new`) : PV max (Toughness), or (Provisions), épique au départ (Veteran's
  Arsenal : phase `start`, comme le bibelot au choix).
- **Combat** (`Combat.new`) : `opts.talents` → `c.talents` (données simples) ; leurs crochets passent par `Combat.modify`
  / `Combat.fire` **comme des bibelots** (après la classe, avant les Powers ou avec les bibelots : à trancher au code ;
  `src` = l'entrée du talent avec son rang) ; enregistrés dans `c.hk` (optimisation de la simulation,
  `Combat.listenCard`). Crochets existants suffisants : `onCombatStart`, `onTurnStart`, `onTurnEnd`, `resCap`, `block`,
  `damage`, `heal`, `applySelf`, `onResource`, `onSurge`, `onParry`, `onPetAttack`, `onShift`, `trapSlots`,
  `castSlots`, `maxMana`, `preventDeath`. À ajouter : constantes de classe lues sur l'état (`TAX_FREE`, `TAX_MAX`,
  `STRIKE_BASE`, `TREE_ABSORB`, `PARRY_MAX`, `PARRY_STOP`, `PET_BASE`, `ATONEMENT_HEAL`) au lieu des constantes
  globales, pour qu'un talent les change sans toucher l'addon chargé ; Rage restante passée au crochet de fin de combat
  (Second Wind, Tactical Mastery).
- **Expédition** : `X.ZONE_HEAL` lu via un crochet `zoneHeal` (Field Medic) ; `onCombatWon(exp, genre, c)`.
- **Simulation** : `tree=<0..100>` (part de l'arbre, dépensée dans l'ordre `classDef.bot.talents` de la classe),
  `talents=<nœud:rang,…>` (arbre imposé), `spec=<voie>` ; rapport : ligne « Talents » ; série `progress=N` qui joue N
  expéditions d'affilée avec l'expérience réelle (courbe en fonction du numéro d'expédition, § 3).
- **Interface** : `UI/Controller.lua` (`progressStep` : onglet Talents ; bilan : points gagnés), `UI/Screens.lua`.
- **Tests** : arbre de chaque classe (24 points, rangées, un seul Specialization), `Meta.contentTier` (aucune carte
  plus tard qu'aujourd'hui), remboursement, figé au départ, migration (§ 13).

## 13. Migration d'une sauvegarde existante

`Save.VERSION` 7 → 8 (méta) ; l'expédition en cours ne change pas de version.

- `cs.xp` est gardée telle quelle ; le nouveau niveau en découle (`Meta.classLevel`, table du § 1.2). Exemples : 1 400
  d'expérience (niveau 7 aujourd'hui) → niveau 12, 11 points ; 450 (niveau 4) → niveau 5, 4 points.
- **Aucune carte ni aucun bibelot perdu** : chaque palier de contenu s'ouvre au même seuil d'expérience ou plus tôt
  (tableau § 1.3) ; test « migration : contenu débloqué identique ou plus large ».
- `cs.talents = {}`, `cs.spec = nil` : tous les points sont à dépenser ; le premier écran après le chargement le dit
  (`You have 11 talent points to spend.`).
- **Expédition en cours** : `exp.unlock.level` reste le palier de contenu 1 à 7 (le sens du champ ne change pas, grâce
  à `Meta.CONTENT_LEVELS`) ; `exp.unlock.talents` absent = aucun talent : elle finit telle quelle, sans talents.
- Titre : un joueur « Veteran » au niveau 7 aujourd'hui le perd jusqu'au niveau 25 ; à décider (le garder acquis
  par un drapeau est simple).

## 14. Découpage en lots

1. **Méta et sauvegarde** : 25 niveaux, paliers de contenu, points, `cs.talents`, migration v8, tests (aucun effet de
   jeu ; la simulation à `level=` inchangé redonne les mêmes rapports).
2. **Socle des talents** : format `ns.Talents`, crochets de combat et d'expédition, constantes de classe lues sur
   l'état, génériques (Toughness, Provisions, Field Medic, Veteran's Arsenal 1), simulation `tree=` / `talents=`.
3. **Arbre du Warrior**, puis **arbre du Druid** (mesure : courbe § 3 au bot `human` et `heuristic`, `tree=0, 20,
   40, 60, 80, 100`, avec le contenu de chaque palier).
4. **Quatre autres arbres** (un agent par classe, en parallèle, sur le modèle des deux premiers).
5. **Interface** : maquettes (§ 11), puis onglet Talents, bilan, accueil.
6. **Recalage** : mur des zones 6 et 7 si la courbe n'est pas tenue (§ 5), puis clés 1 à 5 (§ 9).
7. **Hauts faits et points de passage** (§ 10), indépendants de 2 à 6.
8. Veteran's Arsenal 2 (« one more Epic ») quand le plafond d'épiques réglable est livré.

## 15. Risques

- **Grind** : 17 expéditions pour l'arbre plein, ≈ 25 à 35 minutes chacune en vol ; six classes = ≈ 100 expéditions.
  Garde-fous : 60 % vers la 10e ; bonus d'expérience de compte possible (§ 1.2) ; une défaite rapporte toujours.
- **Équilibrage à N états** : 24 points × ordre × Specialization. Mesurer seulement les états de l'ordre du bot à 0,
  20, 40, 60, 80, 100 % et les trois Specialization au palier 60 % ; un nœud qui vaut plus de 10 points seul est
  trop fort (comparer chaque nœud plein seul à l'état de son palier).
- **Mur trop raide** : un facteur de dureté de 2,3 laisse peu de marge ; un petit écart de force du deck fait passer
  Blackrock de 20 à 60 % (`docs/equilibrage.md`, « la réponse est très raide »). Un nœud mal réglé peut donc décider
  seul d'une victoire. Régler les nœuds par paliers, pas un par un.
- **Écart entre classes** : les leviers ne valent pas la même chose selon la classe (Druid : la taxe vaut 35 points ;
  Warrior : la Rage n'a pas de levier mesurable) ; régler chaque arbre pour la même courbe, pas les mêmes nœuds.
- **Lisibilité** : 13 à 14 nœuds, textes d'une ligne ; les chiffres modifiés doivent se voir sur la pastille de classe
  et dans les infobulles des cartes (plafond de Rage, coût de la taxe), sinon le joueur ne sait pas ce qu'il a acheté.
- **Bots** : les bots doivent voir les talents (valeur de la Rage gardée, de l'Absorb de fin de tour) ; sinon les
  mesures sous-estiment les nœuds.

## 16. Questions ouvertes pour le joueur

1. **Mur ou talents** (§ 5) : pour tenir 40 % à 60 % de l'arbre, accepte-t-on d'abaisser le mur des zones 6 et 7
   (Burning Steppes et Blackrock Mountain de 2,15 / 2,3 à ≈ 1,9), ou préfère-t-on des nœuds de mécanique plus forts
   (au risque que la clé 0 devienne triviale à 100 %) ?
2. 25 niveaux et un point par niveau, ou 13 niveaux à deux points (moins de lignes « level up », moins de petites
   victoires) ?
3. Cartes et bibelots au niveau (défaut) ou dans l'arbre ?
4. Remboursement gratuit hors expédition : d'accord ?
5. Un bonus d'expérience pour une deuxième classe une fois Nefarian battu sur le compte ?
6. Au-delà du niveau 25 : rien, ou des rangs de plus gagnés aux clés ?
7. Les déblocages de rencontres et de points de passage par hauts faits (défaut) ou par zones gagnées ?
8. Veteran's Arsenal (épique au départ) : nœud générique de l'arbre, ou haut fait du compte (« avoir battu la zone »
   suffit) ?
9. Le titre « Veteran » d'un joueur déjà au niveau 7 : gardé à la migration ?

## 17. Contrat du socle des talents (codé le 19/11/2026)

Lots 1 et 2 du § 14 et arbre du Warrior codés ; réponses du joueur aux questions du § 16 : (1) mur des zones 6 et 7
déjà à 1,9 ; (2) 25 niveaux, un point par niveau ; (3) cartes et bibelots au niveau (`Meta.CONTENT_LEVELS`) ; (4)
remboursement gratuit hors expédition ; (5) pas de bonus de compte ; (6) rien au-delà du niveau 25 ; (8) Veteran's
Arsenal nœud générique ; (9) titre « Veteran » gardé (`cs.veteran`). Ce qui suit est le contrat que lisent les agents
qui écrivent un arbre (un par classe, en parallèle) et l'agent d'interface.

### 17.1 Où sont les choses

| Fichier | Contenu |
|---|---|
| `Core/Meta.lua` | 25 niveaux (`Meta.XP_LEVELS`, `MAX_LEVEL`), paliers de contenu (`CONTENT_LEVELS`, `MAX_TIER`, `contentTier`), points (`talentPoints`, `spent`, `pointsLeft`, `learn`, `reset`), `Meta.record(...).pointsGained` |
| `Core/Save.lua` | `Save.VERSION` 8 (migration 7 → 8), `Save.learnTalent`, `Save.resetTalents` (refusés `"running"` pendant une expédition) |
| `Core/Talents.lua` | `ns.Talent` : règles communes (définir un arbre, apprendre, entrées, textes, vue de l'interface, constantes) |
| `Data/Talents/common.lua` | `ns.TalentCommon` : les quatre nœuds génériques (Toughness, Provisions, Field Medic, Veteran's Arsenal) |
| `Data/Talents/<classe>.lua` | l'arbre d'une classe (`ns.Talent.define`) ; les six fichiers sont **déjà au TOC** (vides sauf le Warrior) : un agent de classe n'édite que le sien |
| `Sim/tests_talents.lua` | suite des talents (méta, socle, génériques, chaque nœud du Warrior) |

### 17.2 Format exact d'un arbre et d'un nœud

```lua
local _, ns = ...
local Combat, TC = ns.Combat, ns.TalentCommon
local XT = { ... }            -- nombres réglables (ns.<Classe>Talents = XT), lus à chaque usage ; les textes les disent
ns.<Classe>Talents = XT
ns.Talent.define("<classe>", {
  rows = { 0, 5, 10, 16 },     -- points dépensés qui ouvrent les rangées 1 à 4
  nodes = {                    -- ordre d'affichage, rangée par rangée
    TC.toughness({ row = 1, ranks = 3, hp = 3 }),
    { id = "primal_instinct", row = 1, ranks = 2, name = "Primal Instinct", icon = "ability_druid_…",
      text = { "Start of combat: +1 Reserve.", "Start of combat: +2 Reserve." }, -- texte COMPLET de chaque rang
      hooks = { onCombatStart = function(c, src) Combat.gainRes(c, src.rank, "talent") end },  -- combat
      run = { … },             -- expédition (facultatif)
      const = { … },           -- constantes de classe (facultatif, § 17.4)
      bot = { won = f, value = f } },  -- conseils aux bots (facultatif, § 17.5)
    TC.provisions({ row = 2 }),
    { id = "specialization", row = 3, ranks = 1, name = "Specialization", icon = "…",
      choices = {              -- nœud à choix : une voie active ; chaque voie a ses champs
        { id = "feral", name = "Feral", icon = "…", text = "Clearcasting also gives +1 Combo.", hooks = { … } },
        { id = "balance", … }, { id = "restoration", … } } },
    TC.fieldMedic({ row = 3 }),
    TC.veteransArsenal({ row = 4 }),
    …
  },
  bot = { order = { "natural_shapeshifter", "natural_shapeshifter", "toughness", … }, -- un id par point, 24, légal
          spec = "feral",      -- voie du bot
          epic = { … } },      -- accord des épiques avec l'arbre (facultatif, § 17.5)
})
```

- `id` : minuscules et `_`, unique dans l'arbre ; les génériques gardent leur id (`toughness`, `provisions`,
  `field_medic`, `veterans_arsenal`) et leur rangée du § 2.1 ; le nœud à choix s'appelle `specialization`.
- `ranks` : 1 à 3 ; un rang coûte un point et demande le précédent (on apprend toujours le rang suivant).
- `text[r]` : texte du rang r tel qu'il s'affiche (anglais factuel, une phrase, point final, pas d'imagerie) ;
  nœud à choix : `text` de chaque voie (une chaîne).
- Arbre complet : **24 points exactement**, quatre rangées, **un seul** nœud à `choices`. `ns.Talent.check(classe)`
  renvoie la liste des écarts (vide si l'arbre est bon) : 24 points, rangs 1 à 3, textes de chaque rang, un nœud à
  choix, ordre du bot de 24 points **légal** (rejoué par `ns.Talent.build` : rangées ouvertes à temps).
- **Ordre du bot** (`bot.order`, ce que la fiche appelle `bot.talents`) : un id par point, dans l'ordre de dépense
  (la simulation `tree=N` en prend les `ceil(24 × N / 100)` premiers : 5, 10, 15, 20, 24 points) ; `bot.spec` = voie
  du bot (`spec=` la remplace).
- Fiches immuables : rien n'écrit dans un nœud après le chargement. L'état vit sur le combat (`c.tstate`,
  `c.cls`) ou sur l'expédition (`exp.talentState`).

### 17.3 Crochets disponibles

`src` = l'entrée du talent appris `{ id, rank, spec }` (données simples) ; `src.rank` donne le rang.

- **Combat** (`hooks`) : tous les crochets de `Combat.modify` / `Combat.fire` (ceux des bibelots, `docs/classes.md`),
  signature `(c, src, …)` comme un bibelot ; ils passent **juste après les bibelots, avant les affixes et les
  épiques**, et leurs noms sont ajoutés à `c.hk` (aucune autre déclaration). Utiles : `onCombatStart`,
  `onTurnStart`, `onTurnEnd`, `resCap`, `block`, `damage`, `attackMult`, `heal`, `applySelf`, `onResource` (delta,
  why : `"spend"`, `"surge"`…), `onSurge`, `onSpend`, `onParry`, `onPetAttack`, `onShift`, `trapSlots`, `castSlots`,
  `maxMana`, `drawPerTurn`, `preventDeath`, `bearStrike`. Pendant la résolution d'une carte, `c.cardCtx` est son
  contexte (« les cartes qui donnent de l'Absorb » : `block` avec `c.cardCtx`, une fois par carte : voir Protection).
- **État d'expédition dans le combat** : `c.tstate` (copie de `exp.talentState`, reprise par l'expédition à la fin
  du combat, copiée en profondeur par `Combat.clone`) : « une fois par expédition » (Unyielding :
  `c.tstate.unyielding`), valeur posée en fin de combat et lue au suivant (Tactical Mastery : `c.tstate.rage`).
- **Expédition** (`run`) : `Expedition.modify` / `Expedition.fire`, signature `(exp, src, v, …)` (modify) et
  `(exp, src, …)` (fire), après les bibelots : `startMaxHp` (v = PV de la classe), `startGold` (v = 50),
  `startEpics` (v = 0 : épiques choisies au départ), `zoneHeal` (v = 0,5), `onCombatWon` (`kind, fight, c` : `c` =
  le combat terminé, `c.player.res`, PV déjà repris par l'expédition), et tous les crochets `run` des bibelots
  (`gold`, `restHeal`, `price`…). Soin hors combat : `ns.Expedition.healOut(exp, n)`.

### 17.4 Changer une constante de classe

Un talent ne modifie **jamais** le module (`ns.Druid.TAX_FREE = …` est interdit : l'addon chargé doit rester intact,
test « fiches immuables »). Le code de classe lit la constante sur l'état du combat :

```lua
Combat.const(c, "TAX_FREE", Druid.TAX_FREE)   -- valeur du module, puis les talents qui déclarent const.TAX_FREE
```

et le talent la déclare : `const = { TAX_FREE = function(v, src) return v + src.rank end }` (pour fixer une valeur :
`return 0`). Sans talent, `Combat.const` rend la valeur du module (un test de champ ; `tune=Druid.TAX_FREE=2` reste
valable). Déjà branchées : `TAX_FREE`, `TAX`, `TAX_MAX` (`Druid.taxOf(n, c)`), `STRIKE_BASE`, `PULSE_MAX`,
`TREE_ABSORB` (Druid), `PET_BASE` (`Hunter.petBase(c)`), `PARRY_STOP` et `PARRY_MAX` (Rogue : `maxKey` de l'état
Parry, lu par `Combat.applyStatus`), `ATONEMENT_HEAL` (Priest), `SUNDER_MULT` (Sundered). Une autre constante :
remplacer sa lecture par `Combat.const(c, "NOM", Module.NOM)` dans le code de la classe (et `maxKey = "NOM"` pour le
plafond d'un état). `TRAP_SLOTS`, le mana (`maxMana`) et le plafond de ressource (`resCap`) ont déjà leur crochet.
Les textes des cartes et des mots-clés qui citent une constante (« Max 3. » de Parry, « 1 + Frenzy » du familier)
gardent la valeur du module : le nœud dit le changement.

### 17.5 Bots

- Le bot de combat joue la fin du tour et le tour ennemi sur une copie (feuilles) : l'Absorb de fin de tour, la Rage
  dépensée qui soigne, les PV en plus se voient sans rien faire.
- `bot.won(c, src)` → PV équivalents d'un combat **gagné** dans cet état (Rage gardée, soin d'après-combat : le bot
  préfère finir avec de la Rage) ; `bot.value(c, src, W)` → unités de `Bots.W` (10 = 1 PV) d'un état en cours
  (Rampage : finir le tour à 5 Rage vaut un mana au tour suivant). Les deux sont facultatifs.
- Hors combat : l'épique au départ (Veteran's Arsenal) est prise par `decide` (`Sim/expedition.lua`), la mieux notée
  (`classDef.bot.epic`). Avec des talents, l'arbre ajoute son accord à chaque épique : `bot.epic = { [id] = écart de
  note }` dans l'arbre (Warrior : `thunderous_roar = -4`, la Rage vidée à 5 contredit tout l'arbre ; sans cet écart,
  le bot prenait Thunderous Roar et Anger Management au départ et l'arbre plein gagnait 72 % contre 86 % sans
  Veteran's Arsenal). À régler pour chaque classe : `talents=veterans_arsenal:2` au palier 100 %.

### 17.6 Tester et mesurer

- Tests : ajouter une suite `Sim/tests_talents_<classe>.lua` sur le modèle de `Sim/tests_talents.lua` (un test par
  nœud, avec `wcombat` / `wexp` : combat ou expédition avec `Talent.entries(classe, { nœud = rang }, voie)`) et
  `ns.Talent.check("<classe>")` vide ; le test « arbre du Warrior » de `Sim/tests_talents.lua` vérifie que les cinq
  autres classes n'ont **pas encore** d'arbre : l'agent qui écrit un arbre retire sa classe de cette liste. Toutes
  les suites en `lua5.1` et `luajit`.
- Mesure : `… runner=expedition bot=human class=<classe> key=0 seed=1 runs=600 jobs=8 tree=<0..100>` avec le contenu
  du palier (§ 3 : `tree=0 zones=0 level=1`, `tree=20 zones=2 level=4`, `tree=40 zones=3 level=7`, `tree=60 zones=4
  level=7`, `tree=80 zones=6 level=7`, `tree=100 zones=7 level=7`) ; un nœud seul : `talents=<nœud>:<rang>` ; une
  voie : `spec=<voie>`. Le rapport porte une ligne « Talents ». Sans `tree=` ni `talents=` : aucun talent (rapports
  d'avant inchangés à graine égale, vérifié sur six classes). `level=` reste le palier de contenu 1 à 7.
- Mesurer chaque nœud **seul** au contenu du palier 60 % **et** l'arbre au palier : près du mur, les gains
  s'additionnent mal (Warrior : les nœuds de mécanique de la fiche, +2 à +26 points seuls, donnaient 86 % ensemble
  au palier 60 % ; `docs/equilibrage.md`, « Talents du Warrior : courbe par palier »).

### 17.7 API de lecture pour l'interface

- `ns.Talent.view(meta, classe, running)` → `{ class, points, spent, left, spec, rows = { { row, need, open, nodes = {
  { id, name, icon, ranks, rank, text (rang actuel, nil à 0), nextText (rang suivant, nil au maximum), canLearn, why
  ("row", "points", "max", "running"…), choices = { { id, name, icon, text, active } } } } } } }` ; `running` = une
  expédition est en cours (`db.current ~= nil`) : rien ne s'apprend.
- `ns.Talent.rankText(classe, id, rang, voie)`, `ns.Talent.node(classe, id)`, `ns.Talent.rowNeed(classe, rangée)`.
- Actions : `ns.Save.learnTalent(db, classe, id, voie)` (true, ou nil + raison ; une voie déjà apprise se change
  sans coût), `ns.Save.resetTalents(db, classe)` (points rendus). Points : `Meta.talentPoints`, `Meta.spent`,
  `Meta.pointsLeft`. Bilan de fin d'expédition : `summary.pointsGained` (`Meta.record`, `Save.finish`).
- Pendant l'expédition : `exp.talents` (liste `{ id, rank, spec }` figée au départ) ; phase `start` avec
  `exp.talentEpics` (choix `{ "talentEpic", i }` / `{ "skipTalentEpic" }` ; `exp.talentEpicsLeft` choix restants),
  avant le bibelot au choix ; écran : `talentEpicStep` (`UI/Controller.lua`, sorte `talentEpic` de la grille du
  deck ; `docs/interface.md`, « Arbres de talents »).
- Écran Progress : le champ `level` d'une carte reste le palier de contenu ; la condition affichée est le niveau de
  classe `Meta.CONTENT_LEVELS[palier]` (corrigé dans `progressStep`).
- Icônes des nœuds (`icon`) : noms de fichiers de `Media/Icons/` (sans extension), toutes présentes pour le Warrior et
  les génériques ; une nouvelle icône s'ajoute par `tools/build_media.py --icons-only`.
