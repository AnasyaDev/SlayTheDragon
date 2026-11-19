# Druid — fiche de conception

Fiche de conception, réécrite le 18/11/2026 d'après la conception décidée avec le joueur. Elle remplace la
version du 12/11/2026 (formes à effet permanent, cartes `Shift` dédiées, lignes `Bear:` / `Cat:` / `Moonkin:`
sur les cartes, Idol of the Wild à +1 mana par Shift) : de cette version restent les trois voies, l'Interrupt
(Skull Bash), le Last Breath (Rebirth), une partie des bibelots et des noms de cartes. Codé le 18/11/2026
(règles, 34 cartes, 6 bibelots, progression : `Core/Classes/druid.lua`, `Data/Druid.lua`, tests
`Sim/tests_druid.lua`) ; restent les sept épiques (§ 5), l'interface (`UI/Art/druid.lua`, pastille par forme) et
le réglage des bots et des chiffres (§ 8, « Ce qui reste »). Première mesure et premier réglage le 18/11/2026
(§ 10, « Réglage du 18/11/2026 ») : levier A actif (taxe dès le deuxième changement d'un tour), PV 65 → 58,
Regen de fin de tour en Tree of Life 1 → 2. Réglé ensuite au bot `human` (§ 10, « Réglage au bot human ») : PV
58 → 65. Répartition des niveaux de déblocage revue pour le compte neuf (§ 7 ; § 10, « Compte neuf ») : 1,3 → 36,2 %
au bot `human` au niveau 1. Voies seules remises dans l'ordre le 19/11/2026 (§ 10, « Absorb en Tree, Cat/Bear hors
taxe ») : fin de tour en Tree of Life = 2 Absorb au lieu de la Regen, passage entre Cat et Bear hors taxe, cartes
offensives relevées (Mangle, Leader of the Pack, Nature's Grace, Starfire, Starsurge, Hurricane), Absorb sur
Insect Swarm et Faerie Fire (défense de Balance), PV 65 → 59.

Corrigée le même jour après relecture du joueur : chaque forme a un effet de fin de tour ; la forme Caster
devient **Tree of Life** (quatrième forme, portée par les cartes de soin) ; le combat commence **sans forme** ;
PV de départ 65 ; Maul et Rake gardent leurs noms ; la réserve hors forme s'appelle « Reserve » ; les quatre
mots de forme comptent pour un seul mot-clé. L'épique de Swamp of Sorrows, qui s'appelait Tree of Life, devient
Lifebloom.

Règles communes (tour, Cast, Interrupt, Cooldown, Exhaust, Retain, Innate, Surge, Spend N, Last Breath, états
communs) : `docs/gdd-classes.md` et `docs/classes.md`. Langage des cartes : `docs/interface.md`, « Langage des
cartes ». Textes de jeu en anglais. Chiffres : points de départ copiés des cartes des classes empruntées
(`Data/Rogue.lua`, `Data/Hunter.lua`, `Data/Mage.lua`), à régler par simulation.

## Résumé

Le Druid **emprunte** les mécaniques des autres classes. Chacune de ses cartes porte une **forme** (Cat, Bear,
Moonkin, Tree of Life) ; la jouer fait entrer dans cette forme, sans coût. Il a **une seule réserve** de 0 à 5
points, gardée d'un tour à l'autre et au changement de forme, dont le sens dépend de la forme active. La forme
où l'on termine le tour décide de l'**effet de fin de tour** :

| Forme | La réserve vaut | Pendant le tour | Fin de tour |
|---|---|---|---|
| sans forme (départ du combat) | rien (« Reserve ») | rien | rien |
| Cat | des **Combo** du Rogue | les cartes Cat montent la réserve (« +1 Combo. ») et la vident (« Surge: ») | **Clearcasting** : la première Attack (hors Cast) du tour suivant coûte 0 |
| Bear | du **Frenzy** du Hunter | `Spend N:` des cartes Bear | le Druid frappe seul la dernière cible pour 1 + réserve, puis +1 ; −1 à la fin du round |
| Moonkin | des **Charges** du Mage | +1 dégât par point sur chaque coup des cartes Attack ; un Cast se résout avec ce bonus si l'on a fini le tour en Moonkin | 1 dégât à tous les ennemis par 2 Charges, arrondi au supérieur, 3 au plus |
| Tree of Life | rien (« Reserve », ne baisse pas) | forme des soins et de la Regen | gagne **2 Absorb** pour le tour ennemi |

Les chiffres des effets de fin de tour sont des points de départ, à régler par la simulation. Changer de forme
plus d'une fois dans un tour coûte 1 mana au tour suivant par changement de plus ; un passage entre Cat et Bear ne
compte pas (levier A, § 1.6).

Le rythme : monter la réserve avec les cartes d'une forme, la dépenser avec celles d'une autre, et finir le tour
dans la forme dont on veut l'effet (Bear pour frapper et tenir, Cat pour une Attack gratuite au tour suivant,
Moonkin pour toucher tous les ennemis et qu'un Cast se résolve avec le bonus, Tree of Life pour un peu
d'Absorb). Survie : Absorb en Bear (et d'Insect Swarm, Faerie Fire en Moonkin), soins et Regen en Tree of Life.
Difficulté : difficile.

## 0. Identité

| | |
|---|---|
| Fantasme | Le Druid change de forme à chaque carte et emprunte à chaque forme la façon de se battre d'une autre classe : le chat finit comme un Rogue, l'ours frappe seul comme le familier du Hunter, le sélénien charge ses sorts comme un Mage ; l'arbre de vie soigne. |
| Ressource | Réserve unique, 0 à 5, gardée d'un tour à l'autre et au changement de forme. Son nom affiché est celui de la forme active (Combo, Frenzy, Charges) ; sans forme et en Tree of Life, elle s'appelle **Reserve**. |
| PV de départ | **59** (65, le chiffre du joueur, 18/11/2026 ; baissés à 58 après la première mesure au bot heuristic, remis à 65 le même jour au bot `human`, la référence de la difficulté ressentie : § 10, « Réglage au bot human » ; 59 le 19/11/2026, avec l'Absorb de Tree of Life, Cat ↔ Bear hors taxe et les cartes relevées : § 10, « Absorb en Tree, Cat/Bear hors taxe » ; Hunter 56, Rogue 57, Warrior 70). |
| Deck de départ | Wrath ×3 (Moonkin), Thick Hide ×4 (Bear), Maul ×2 (Bear), Ferocious Bite ×1 (Cat). |
| Bibelot de départ | Idol of the Wild : la première carte de chaque combat qui change de forme coûte 0 (le combat commence sans forme : c'est la première carte de forme jouée). |
| Interrupt | Skull Bash (Feral, sans forme, niveau 1). |
| Last Breath | Rebirth (Restoration, rare, niveau 4 ; niveau 1 jusqu'au réglage du compte neuf, § 10). |
| Mots-clés propres | **Forme** (mots de plaque `Cat`, `Bear`, `Moonkin`, `Tree` : un seul mot-clé, une seule règle, décision du joueur) et **Bear strikes**. Les mots de la réserve (Combo, Frenzy, Charge, Reserve), `Surge:` et `Spend N:` sont des mots communs ou des noms de ressource ; Clearcasting est un état posé sur le héros, écrit sur aucune carte : ni l'un ni l'autre ne sont des mots-clés propres. |
| Style de survie | Encaisser (Absorb des cartes Bear) et se soigner (cartes Tree : soins directs tous Exhaust, Regen ; 2 Absorb en finissant le tour en Tree of Life) ; en Moonkin, l'Absorb d'Insect Swarm et de Faerie Fire. `survival = "absorb"`. |
| Difficulté | Difficile : chaque carte change la forme, l'ordre des cartes compte. |

Deck de départ (gabarit du GDD : 10 cartes de 4 sortes, une attaque, une défense, deux cartes de mécanique) :
Wrath est l'attaque (et monte la réserve), Thick Hide la défense (et laisse en Bear pour la frappe de fin de
tour), Maul montre la frappe de l'ours et Ferocious Bite dépense en Cat ce que Wrath a monté en Moonkin.
Premier tour type (sans forme, Idol of the Wild) : Wrath (0 mana, entre en Moonkin, réserve 1), Wrath (réserve 2),
Thick Hide (Bear, 5 Absorb), 1 mana pour une quatrième carte ; fin de tour en Bear : frappe de 1 + 2 = 3,
réserve 3 ; fin du round : réserve 2. Deux changements (sans forme → Moonkin → Bear) : 2 mana au tour suivant
(levier A, § 1.6). Au tour suivant, Ferocious Bite à 2 Combo : 12. Finir ce premier tour en Moonkin (sans Thick
Hide) aurait donné 1 dégât à tous (2 Charges), aucun Absorb, et gardé les 3 mana du tour suivant.

## 1. Règles propres (spécification)

### 1.1 Forme d'une carte

1. Champ de carte `form = "cat" | "bear" | "moonkin" | "tree"`, ou absent (carte **sans forme**). Toute carte
   du Druid a une forme, sauf la liste fermée du § 1.7.
2. **Jouer une carte dont la forme diffère de la forme active fait entrer dans sa forme.** Pas de carte Shift,
   pas de choix, pas de bouton, aucun coût. Jouer une carte de la forme active, ou une carte sans forme, ne
   change rien (aucun événement). Le Druid n'est « dans aucune forme » qu'au début du combat : la première carte
   de forme jouée y fait entrer (c'est un changement de forme, § 1.6), et aucune carte ne fait ensuite sortir de
   toute forme.
3. **Ordre exact** (`Combat.play`, `docs/classes.md`, « Ordre d'un coup joué ») :
   1. cible (crochet `target`) ; une carte à cible devient la dernière cible (`c.player.lastTarget`), celle de
      la frappe de l'ours ;
   2. coût calculé **dans la forme active avant le changement** (crochet `cost`), puis payé : mana, PV, `Spend N`
      (pris dans la réserve commune, donc indifférent à la forme) ;
   3. compteurs du tour ;
   4. **changement de forme** (crochet de classe `onCardCommitted`, qui passe avant ceux des Powers et des
      bibelots) : journal `{ t = "shift", from, to }`, événement propre `onShift(from, to)`, compteur de
      changements du tour (§ 1.6) ;
   5. incantation (Cast) ou résolution : toutes les lignes de la carte se résolvent dans sa forme.
   Raison du coût avant le changement : le coût affiché en main est celui qui sera payé, sans calcul ; aucune
   carte de la liste n'a de coût qui dépende de la forme (Idol of the Wild lit seulement si la carte changera la
   forme, ce qui se sait avant le jeu).
4. **Cartes Cast** : la forme change **au jeu** (étape 4), comme pour toute carte. La résolution, au début du tour
   suivant, ne change pas la forme : elle se fait dans la forme active à ce moment-là (celle où le tour précédent
   s'est terminé). Le bonus de Moonkin ne s'ajoute donc que si l'on a fini le tour en Moonkin. Exemple : Starfire
   (Moonkin, Cast) puis Thick Hide (Bear) : fin de tour en Bear (frappe, Absorb), Starfire se résout en Bear sans
   le bonus des Charges. Finir en Moonkin garde le bonus et touche tous les ennemis (§ 1.3), mais sans frappe ni
   Absorb : c'est le choix de la voie Balance. Sous Instant (Nature's Swiftness), la carte se résout tout de
   suite, dans sa forme.
5. **Cartes Surge** : la carte entre dans sa forme, puis son `Surge:` dépense **toute** la réserve à sa
   résolution (règle commune) ; le montant se lit avec le mot de la carte (« per Combo », « per Charge », « per
   Frenzy »). Les Charges sont lues puis remises à 0 avant le coup : le bonus de Moonkin ne s'ajoute pas à une
   carte Surge (comme chez le Mage). Après résolution, la carte suit sa plaque (défausse par défaut).
   Une carte dont toutes les clauses sont `Surge:` est injouable à 0 (`minRes = 1`, raison « resource »).
   Contrainte de conception : **aucune carte Surge n'est en Cast** (la réserve pourrait changer entre le jeu et la
   résolution).
6. **Retain, Innate, Cooldown** : une carte gardée en main (Retain, Traveler's Backpack), placée dans la main de
   départ (Innate) ou revenue de recharge (Cooldown) ne change pas la forme ; seule la jouer la change. La forme
   de fin de tour se lit sur la forme active, pas sur les cartes gardées.
7. **Copies** (crochet `replay`, `Combat.copyCard`) : une copie se résout sans changer la forme (elle ne passe pas
   par `Combat.play`). Potions, bibelots, déclencheurs de Powers, épique : ne changent jamais la forme.
8. **Début et fin de combat** : chaque combat commence **sans forme** (`c.cls.form = nil`), réserve à 0
   (l'épique Heart of the Wild améliorée +3 mise à part, § 5). Sans forme, la réserve ne vaut rien et aucun effet
   de fin de tour ne joue : un premier tour fini sans avoir joué de carte de forme ne donne rien. La forme et la
   réserve ne se gardent pas d'un combat à l'autre. Last Breath (Rebirth) ne change pas la forme ; une
   interruption de Cast non plus.
9. Cartes neutres (sans classe, `Data/Neutral.lua`) : sans forme.

### 1.2 La réserve

1. Ressource de classe `c.player.res`, `resource = { id = "wild", cap = 5, keep = true }` (id à confirmer), une
   seule valeur pour toutes les formes. **Les points sont gardés au changement de forme** : 3 Charges montées en
   Moonkin deviennent 3 Combo dès qu'une carte Cat est jouée.
2. **Gains** : clauses « +N Combo. » (cartes Cat), « +N Charge. » / « +N Charges. » (cartes Moonkin),
   « +N Frenzy. » (cartes Bear), et +1 après chaque frappe de l'ours (§ 1.4). Un mot de réserve n'apparaît que
   sur une carte de sa forme, ou sur un Power dont le déclencheur nomme cette forme (« Cat Attacks: +1 Combo. ») :
   la clause se résout alors toujours dans la forme qui porte ce mot. Les cartes Tree et les cartes sans forme
   ne gagnent ni ne dépensent rien.
3. **Plafond 5** ; le surplus est perdu (journal `capped`, pastille qui clignote, comme chez le Rogue).
4. **Dépense** : `Surge:` (toute la réserve, cartes Cat, Bear, Moonkin) et `Spend N:` (cartes Bear, au choix du
   joueur : clic droit ou Maj pour ne pas dépenser, `decisions.md`).
5. **Baisse** : −1 à la fin de chaque round **si la forme active est Bear** à ce moment (crochet `onRoundEnd`,
   après le tour ennemi ; c'est la baisse du Frenzy du Hunter, « sauf le premier tour » compris puisqu'elle a lieu
   après le tour ennemi). Dans les autres formes (Cat, Moonkin, Tree of Life) et sans forme, la réserve ne baisse
   pas (le Combo et les Charges ne baissent pas chez le Rogue et le Mage). Conséquence voulue : la frappe
   automatique de l'ours (+1) et la baisse (−1) s'annulent ; seules les cartes font monter la réserve.
6. **Lecture par forme** :

| Forme | Mot | Effet de la réserve |
|---|---|---|
| sans forme | Reserve | aucun : la réserve attend la première forme |
| Tree of Life | Reserve | aucun : la réserve attend la forme suivante, sans baisser |
| Cat | Combo | aucun effet passif ; les `Surge:` des cartes Cat la dépensent |
| Bear | Frenzy | dégâts de la frappe de l'ours : 1 + réserve ; `Spend N:` des cartes Bear |
| Moonkin | Charge(s) | +1 aux dégâts de **chaque coup** des cartes Attack tant que Moonkin est active, compté au coup, comme Strength, avant Demoralized et Sundered ; ni DoT, ni Skills, ni frappe de l'ours, ni coups de fin de tour, ni bibelots ; nombre des coups à tous de fin de tour (§ 1.3) |

### 1.3 Effet de fin de tour

La forme active au moment de la fin du tour (crochet de classe `onTurnEnd`, avant les Powers, les bibelots et la
défausse, comme le familier du Hunter) décide de l'effet. Chaque forme en a un ; sans forme, aucun. Les chiffres
sont des **points de départ à régler par la simulation** (§ 10).

| Forme de fin de tour | Effet |
|---|---|
| sans forme | aucun |
| Cat | pose **Clearcasting** sur le Druid : la première Attack jouée ensuite coûte 0, sauf les cartes Cast |
| Bear | **frappe de l'ours** : un coup de 1 + réserve sur la dernière cible, puis +1 (§ 1.4) ; puis, à la fin du round, −1 (§ 1.2) |
| Moonkin | **1 dégât à tous les ennemis par 2 Charges, arrondi au supérieur, 3 au plus** ; un Cast en attente se résoudra au début du tour suivant avec le bonus des Charges (§ 1.1, point 4) |
| Tree of Life | gagne **2 Absorb** pour le tour ennemi (Regen 1 au départ, puis Regen 2 jusqu'au 19/11/2026, § 10) |

**Cat : Clearcasting.**

1. État à drapeau sur le Druid (comme Stealth chez le Rogue), sans intensité ni durée : il ne s'empile pas
   (finir deux tours de suite en Cat sans jouer d'Attack ne donne toujours qu'une Attack gratuite) ; il reste
   jusqu'à ce qu'une Attack le consomme, et tombe à la fin du combat.
2. **Coût** : tant qu'il est posé, toute carte Attack **sans la plaque `Cast`** coûte 0 (crochet de classe
   `cost`, comme Slice and Dice, `Data/Rogue.lua`), quelle que soit sa forme. Le coût affiché en main est donc 0
   (`Combat.cost`), comme sous Slice and Dice.
3. **Consommation** : la première carte Attack sans `Cast` jouée le retire (crochet de classe `onCardCommitted`,
   comme Stealth), même si elle coûtait déjà 0. Une copie (`replay`), une carte Skill ou Power, une Attack Cast ne
   le consomment pas.
4. **Pourquoi hors Cast** : toutes les Attack du Druid hors Cast coûtent 1 (Wrath, Maul, Ferocious Bite, Shred,
   Rake, Swipe, Moonfire, Starsurge, Starfall), donc Clearcasting vaut toujours 1 mana. Les deux Attack Cast
   (Starfire, Hurricane) coûtent 2 : les rendre gratuites doublerait l'effet et ferait de « finir en Cat »
   l'amorce de la voie Balance (Cat puis Starfire à 0 au tour suivant) au lieu d'une récompense de la voie Feral.
   La plaque `Cast` se lit sur la carte : sous Instant (Nature's Swiftness), Starfire reste exclue, et le coût
   affiché en main ne change pas selon l'état Instant.
5. **Affichage** : icône de l'état sur le portrait du héros, à côté des autres états (`Spell_Shadow_ManaBurn`,
   l'icône de Clearcasting dans WoW) ; infobulle `Next Attack played costs 0, except Cast cards.` (sans
   parenthèse : règle des explications, harnais U25) ; journal
   `{ t = "clearcasting" }` à la pose et `{ t = "clearcasting_used", card }` à la consommation (léger éclat de
   l'icône, comme Stealth).

**Moonkin : coups à tous.**

1. Dégâts : `ceil(Charges / 2)`, 3 au plus : 0 Charge → rien, 1 ou 2 → 1, 3 ou 4 → 2, 5 → 3. Arrondi au
   supérieur parce que la réserve plafonne à 5 : à l'inférieur, le plafond de 3 ne serait jamais atteint (2 au
   plus) et une seule Charge ne donnerait rien. Le plafond de 3 vaut pour toute réserve plus haute à l'avenir.
2. Un coup sans carte par ennemi vivant, de gauche à droite, comme la frappe de l'ours : Strength et Demoralized
   du Druid, Sundered et Absorb de la cible s'appliquent ; le bonus des Charges ne s'y ajoute pas (ce n'est pas une
   carte Attack), ni Gift of Nature, ni les bibelots « Attacks ».
3. La réserve est lue, pas dépensée ; elle ne baisse pas en Moonkin.
4. Le bonus des Charges sur les coups des cartes Attack pendant le tour, et la résolution d'un Cast avec ce bonus
   au début du tour suivant, restent inchangés (§ 1.1, point 4 ; § 1.2, point 6).
5. Ordre : l'effet de forme passe dans le crochet de classe, avant les Powers et bibelots « End of turn in
   Moonkin: » (Moonkin Aura, Idol of the Moon) : les coups lisent les Charges d'avant le +1 de Moonkin Aura.

**Tree of Life : 2 Absorb** (`Druid.TREE_ABSORB` ; le repli prévu, appliqué le 19/11/2026 : § 10, « Absorb en
Tree, Cat/Bear hors taxe »).

1. Le Druid gagne 2 Absorb (`Combat.gainBlock`), qui tiennent le tour ennemi comme ceux de Thick Hide. Rien ne
   reste au tour suivant : l'Absorb protège sans soigner entre les combats.
2. L'effet **ne lit pas la réserve**, volontairement petit : la réserve ne vaut rien en Tree of Life (§ 4,
   « Pourquoi »), et la voie Restoration a déjà sa jauge, la Regen.
3. **Avant le 19/11/2026 : Regen** (1, puis 2 le 18/11/2026). La Regen de fin de tour s'empilait sur la Regen posée
   par les cartes (une Regen N soigne N(N+1)/2) : elle valait à elle seule 26 points de victoires à Restoration
   seule au bot `human`, et faisait de la voie de soin la meilleure stratégie de la classe (`docs/equilibrage.md`,
   « Druid : voies seules, diagnostic »). Mesuré à 3 Absorb puis 2 ; 2 retenu (§ 10).

La partie « tenir » de l'ours n'est pas qu'un effet de forme : ce sont aussi ses cartes (Thick Hide, Frenzied
Regeneration, Demoralizing Roar), qui donnent de l'Absorb ou réduisent les coups, et `Spend N:` qui échange des
points de Frenzy (frappe plus faible) contre de l'Absorb. Finir dans une forme demande de garder une carte de
cette forme pour la fin du tour (les cartes sans forme jouées ensuite ne changent rien).

### 1.4 La frappe de l'ours (« Bear strikes. »)

1. Un coup **sans carte** (comme le familier du Hunter, `Core/Classes/hunter.lua`) de **1 + réserve** sur la
   dernière cible du Druid ; morte ou absente : l'ennemi vivant le plus à gauche. Strength et Demoralized du Druid
   s'appliquent, Sundered et Absorb de la cible aussi ; les bonus des cartes Attack (Moonkin, Gift of Nature,
   bibelots « Attacks ») ne s'appliquent pas.
2. Puis **+1 Frenzy** (plafond 5).
3. Automatique à la fin de chaque tour fini en Bear ; commandée par la clause « Bear strikes. » / « Bear strikes
   twice. » d'une carte Bear, tout de suite, dans l'ordre des lignes, chaque frappe recalculée.
4. Frappes d'un Surge (Mangle : « Surge: Bear strikes once per Frenzy. ») : chacune à 1 + le montant compté,
   sans gain (comme Bestial Wrath).
5. La frappe n'interrompt, n'étourdit et ne pose rien ; si elle tue le dernier ennemi, le combat est gagné avant
   le tour ennemi.

### 1.5 Rage du Warrior en Bear : non

Étudié : la Rage (+1 par perte de PV, `Core/Classes/warrior.lua`, `onHpLost`) à la place du Frenzy, ou en plus.
Tranché : **non**, la réserve de l'ours est le Frenzy seul ; du Warrior, l'ours garde la forme `Spend N:` (déjà
commune : Growl du Hunter l'emploie).

- **L'Absorb tuerait la Rage** : les cartes Bear donnent de l'Absorb, et la Rage ne vient que des PV perdus. Un
  ours bien joué (tout absorbé) ne gagnerait rien ; la forme qui tient serait celle qui ne monte pas sa réserve.
  Le Warrior vit avec cette tension parce qu'elle fait son identité ; pour l'ours, elle contredit son rôle.
- **Gain passif et réserve partagée** : la réserve passe d'une forme à l'autre. Avec la Rage, finir en Bear et
  prendre trois coups donnerait 3 points gratuits, vidés au tour suivant par Ferocious Bite (16 dégâts) ou
  ajoutés à chaque coup de Moonkin, sans aucune carte de construction. Le Frenzy ne monte que par les frappes
  et les cartes, et la baisse en Bear compense la frappe automatique.
- **Lisibilité** : un quatrième mode de gain (coup reçu) s'ajouterait aux trois mots empruntés.
- La Rage reste possible comme règle d'épique, bornée à une forme : Owlkin Frenzy (§ 5) donne de la réserve
  quand le Druid perd des PV en Moonkin.

### 1.6 Changements de forme et réglage de secours

1. Un **changement de forme** = une carte jouée dont la forme diffère de la forme active (§ 1.1). Compteurs par
   tour dans `c.cls` (remis à 0 au début du tour) : `shifts` (tous les changements) et `taxed` (les changements
   **comptés** pour la taxe, point 3) ; le premier changement d'un tour est souvent la sortie de la forme de fin
   du tour précédent. L'entrée dans la première forme du combat (depuis « sans forme ») est un changement :
   Idol of the Wild, Wolfshead Helm et Furor la voient, et elle est comptée pour la taxe.
   Une carte de la forme active, une carte sans forme, une copie ne comptent pas (aucun changement).
2. Sans le levier, aucune limite ni coût. Un tour type en compte deux (sortir de Bear pour Cat ou Moonkin, revenir
   en Bear pour finir) ; un tour qui passe par trois formes en compte trois.
3. **Levier A (actif depuis le 18/11/2026) — mana du tour suivant.** À partir du **deuxième** changement compté
   d'un tour, chaque changement compté retire 1 mana au tour suivant (crochet `maxMana` de la classe, `c.cls.tax`
   posé à la fin du tour), −2 au plus (il reste 1 mana). **Un passage entre Cat et Bear (dans les deux sens) ne
   compte pas** (19/11/2026, `Druid.taxed(from, to)`) : ce sont les deux formes de Feral, dont le va-et-vient de
   chaque tour (monter en Cat, tenir en Bear) payait la taxe plus que toute autre voie. Tout autre changement
   compte, l'entrée dans la première forme du combat comprise. Un passage Cat ↔ Bear reste un changement de forme
   pour tout le reste : journal, `onShift` (Idol of the Wild, Wolfshead Helm, Furor), compteur `shifts`.
   Constantes : `Druid.TAX = 1` (mana par changement taxé, 0 = levier coupé), `Druid.TAX_FREE = 1` (changements
   comptés gratuits par tour), `Druid.TAX_MAX = 2`. Exemples, depuis la forme de fin du tour précédent : Bear →
   Cat → Bear (deux changements, aucun compté) : 3 mana ; Moonkin → Cat → Bear (deux changements, un compté :
   Moonkin → Cat) : 3 mana ; Bear → Moonkin → Bear (deux comptés) : 2 mana ; Bear → Tree → Moonkin → Bear (trois
   comptés) : 1 mana. Premier tour du combat : sans forme → Cat → Bear (l'entrée seule comptée) : 3 mana ; Wrath
   (Moonkin) puis Thick Hide (Bear) : 2 mana au tour 2.
   Infobulle de la pastille (changements comptés) : `Form changes this turn: N. Shifting between Cat and Bear is
   free.` suivi de `1 more free, then each costs 1 mana next turn.`, `Shifting again costs 1 mana next turn.` ou
   `Next turn: N mana less.`.
   Le bot heuristic (et le bot `human`, même évaluation) voit la taxe : sa fin de tour simulée pose `c.cls.tax`
   (lu sur les changements comptés), que `botValue` compte −22 par mana (`Druid.TAX_VALUE`, un mana comme
   Clearcasting), et `botKey` distingue les positions par le nombre de changements comptés du tour.
4. **Levier B (prévu, non actif) — réserve.** À partir du troisième changement d'un tour, chaque changement fait
   perdre 1 point de réserve, au changement, avant la résolution de la carte. Plus doux que A (il ne touche pas au
   mana) et plus ciblé : il ne vise que le transfert de réserve entre formes.
5. Quand les activer : si la mesure montre plus de 3 changements par tour en moyenne au bot heuristic, ou si les
   decks à trois formes gagnent plus de 10 points de plus que les decks à deux formes. A d'abord ; B si A rend la
   classe lente. Mesure du 18/11/2026 : 3,59 changements par tour, 99,7 % de victoires : A activé, B non.
6. **Seuil retenu : un changement gratuit (taxe dès le deuxième)**, la règle du joueur (« plus d'une fois »), et non
   les deux gratuits que proposait la fiche. Raison mesurée (§ 10) : taxe dès le troisième, 99,3 % de victoires
   (−0,4 point, 2,86 changements par tour) : le bot paie rarement le troisième changement et la classe ne change
   pas ; dès le deuxième, 95,7 % (−4,0 points, 2,69 changements par tour, 0,8 mana perdu par tour en moyenne) :
   la classe paie son va-et-vient de base, ce qui est le but.
7. **Entrée dans la première forme du combat : toujours comptée** (point 1), y compris depuis le 19/11/2026 : la
   règle Cat ↔ Bear ne vise qu'un passage entre deux formes de Feral, et « sans forme » n'en est pas une. Un
   premier tour Feral (sans forme → Cat → Bear) ne paie donc rien (un seul changement compté) ; un premier tour
   qui passe par Moonkin et Bear paie 1 mana.
8. **Balance et le deck de départ** : Balance n'a qu'une forme (Moonkin), mais le deck de départ en a trois (Wrath
   en Moonkin, Thick Hide et Maul en Bear, Ferocious Bite en Cat) : la voie seule paie encore la taxe à chaque
   aller-retour Moonkin ↔ Bear (0,62 mana par tour au bot `human`, 0,73 avant la règle ; Feral seule 0,54, 0,86
   avant ; Restoration seule 0,68, mélange 0,78 : § 10). La règle n'y change rien : c'est le prix de la défense
   de l'ours, que l'Absorb d'Insect Swarm et de Faerie Fire permet maintenant d'éviter en restant en Moonkin.

### 1.7 Cartes sans forme

Liste fermée : **Skull Bash** (l'Interrupt doit pouvoir partir dès qu'une incantation ennemie paraît, sans
casser la forme de fin de tour), **Nature's Swiftness** (prépare un Cast de n'importe quelle forme), et **tous les
Powers** (Thorns, Gift of Nature, Rebirth, Nature's Grace, Moonkin Aura, Leader of the Pack) : un Power se joue une
fois et reste ; lui faire changer la forme ferait d'une carte permanente un détour de forme. Un Power peut nommer
une forme dans son déclencheur (« Cat Attacks: », « End of turn in Moonkin: »). Les soins ne sont pas sans forme :
ils sont Tree, et les jouer fait quitter Bear (comme dans WoW, où l'on soigne hors des formes animales).

### 1.8 Marque de forme sur la carte et pastille de classe

- **Sur la carte** : la forme est le **premier mot de la plaque du bas**, en tête comme `Cast` (« Bear »,
  « Moonkin · Cast », « Cat », « Tree · Cast · Exhaust »), retiré du corps du texte : elle ne prend aucune ligne.
  Une petite icône de la forme (pastille ronde de la taille du coût) est posée dans le coin haut opposé au coût,
  et le liseré de la plaque prend la couleur de la forme (brun pour Bear, jaune pour Cat, bleu nuit pour Moonkin,
  vert pour Tree). Carte sans forme : ni icône ni mot.
- **Mot de plaque de Tree of Life : `Tree`.** Le nom complet ferait la plus longue plaque de la classe
  (« Tree of Life · Cast · Exhaust » pour Healing Touch, 29 caractères contre 21) et serait le seul mot de plaque
  en trois mots ; `Tree` est aussi court que `Bear`. Le nom complet « Tree of Life » est écrit dans l'infobulle
  et la pastille. Les textes qui nomment la forme (Idol of Rejuvenation) écrivent `Tree`.
- **En main, en combat** : l'icône de forme d'une carte qui changerait la forme est allumée (contour doré) ;
  celle d'une carte de la forme active reste éteinte. Sans forme (début du combat) : toutes allumées. Hors combat
  (récompenses, deck, marchand) : toutes éteintes.
- **Infobulles des mots de plaque** (60 caractères au plus ; effet de fin de tour compris) :
  `Cat` « Enters Cat (Combo). End of turn: next Attack costs 0. » ;
  `Bear` « Enters Bear (Frenzy). End of turn: Bear strikes. » ;
  `Moonkin` « Enters Moonkin (Charges). End of turn: 1 to all per 2. » ;
  `Tree` « Enters Tree of Life. End of turn: gain 2 Absorb. ».
- **Pastille de classe** : l'anneau près du mana montre l'icône de la forme active à la place de celle de la
  ressource (sans forme : l'icône de la classe, anneau gris ; Tree of Life : `Ability_Druid_TreeofLife`), et le
  nombre de la réserve (cinq crans, cachés à 0 comme ailleurs) ; la couleur de l'anneau suit la forme. Infobulle :
  nom de la forme, ce que vaut la réserve et l'effet de fin de tour (« 3 Frenzy: end-of-turn strike for 4. »,
  « 3 Charges: Attack hits +3, end of turn 2 to all. », « 3 Combo: spent by Surge. End of turn: free Attack. »,
  « Tree of Life: Reserve 3, unused. End of turn: gain 2 Absorb. », « No form: Reserve 3, unused. »), « n / 5 », puis
  la ligne du levier A (compteur des changements comptés du tour, « Shifting between Cat and Bear is free. » et
  malus à venir, § 1.6). Au changement de forme : l'icône tourne et change (événement
  `shift`).
- **Cible de la frappe** : en Bear, la marque d'ennemi (`enemyMarks`, comme la cible du familier du Hunter) montre
  la dernière cible et les dégâts de la prochaine frappe. En Moonkin, chaque ennemi montre les dégâts du coup de
  fin de tour (même marque, sans cible).
- **Clearcasting** : icône d'état sur le portrait du héros (§ 1.3).

### 1.9 Mots-clés et infobulles

| Mot | Infobulle (≤ 60 caractères) |
|---|---|
| Forme (plaque `Cat` / `Bear` / `Moonkin` / `Tree`, un seul mot-clé) | ci-dessus, § 1.8 |
| Bear strikes | `Hits the last target for 1 + Frenzy, then +1 Frenzy.` |
| *(ressource)* Combo, en Cat | `Kept between forms and turns. Surge spends it all. Max 5.` |
| *(ressource)* Frenzy, en Bear | `End-of-turn strike 1 + Frenzy. −1 each round in Bear.` |
| *(ressource)* Charges, en Moonkin | `+1 to Attack hits per Charge. End of turn: 1 to all per 2.` |
| *(ressource)* Reserve, sans forme et en Tree of Life | `Kept between forms. Unused outside Cat, Bear, Moonkin.` |
| *(état)* Clearcasting | `Next Attack played costs 0, except Cast cards.` |

Conditions et déclencheurs employés : `Surge:`, `Spend N:`, `Regen:` (état sur soi), `Last Breath:`, `When hit:`,
`Cast cards:` (existants) ; nouveaux : `Cat Attacks:`, `End of turn in Moonkin:` (Powers), et pour les épiques
`Form changes:`, `Bear strikes:`, `Forms:`, `Each Regen heal:` (existant, Priest), `Surge cards:` (existant,
Rogue).

## 2. Choix : cartes empruntées ou cartes propres

Deux façons d'emprunter :

- **(a) Vraies cartes des autres classes dans le pool du Druid, avec une marque de forme** (Sinister Strike en
  Cat, Arcane Blast en Moonkin, Arcane Shot en Bear).
- **(b) Cartes propres au Druid** (Rake, Shred, Ferocious Bite, Maul, Swipe, Wrath, Starfire…), qui reprennent les
  mêmes effets et les mêmes mots (« +1 Combo. », « Surge: », « Spend 2: », frappe comme « Pet attacks. »).

**Recommandation : (b).** Conséquences concrètes :

| | (a) cartes partagées | (b) cartes propres (retenue) |
|---|---|---|
| Équilibrage | couplé : Eviscerate est passée de 5 + 5 à 4 + 4 par Combo pendant les réglages du Rogue ; avec (a), chaque réglage du Rogue change le Druid, et inversement un Druid trop fort forcerait à affaiblir le Rogue | indépendant : les chiffres partent de la carte d'origine, puis le Druid se règle seul (`sweep=cards class=druid`) |
| Lignes mortes | beaucoup de cartes citent une mécanique que le Druid n'a pas : Backstab et Ambush (`Stealth:`), Feint et Riposte (Parry), Arcane Shot et Kill Command (« Pet attacks. » : pas de familier), Frostbolt et Ice Lance (Frozen), Fireball (Hot Streak, école Fire) ; il faudrait les exclure ou donner ces mécaniques au Druid | aucune : chaque carte est écrite pour les règles du Druid |
| Code | une carte n'a qu'un `class` ; il faudrait une liste de cartes étrangères par classe, une table de formes à part (les fiches sont immuables), des règles de pool, de niveau (le niveau est celui de la classe d'origine), de progression et d'amélioration qui lisent deux classes ; le harnais refuse aujourd'hui toute ressource d'une autre classe | un fichier `Data/Druid.lua` ordinaire ; seuls le mot de ressource par forme, la plaque de forme et la frappe de l'ours sont nouveaux (§ 8) |
| Lisibilité | le joueur qui connaît le Rogue reconnaît Sinister Strike, mais un chat qui joue « Sinister Strike » ou un ours qui lance « Arcane Shot » se lit mal ; une même carte dans deux collections, avec des paliers +2 / +3 écrits pour l'autre classe (Retain des ouvertures sous Stealth) | noms de sorts de druide, effets et mots identiques à ceux des autres classes : on reconnaît la mécanique sans confondre les cartes |
| Coût | aucun texte à écrire | 34 cartes à écrire et à régler |

Plusieurs cartes du Druid reprennent donc exactement une carte d'une autre classe (Ferocious Bite = Eviscerate,
Rake = Garrote, Frenzied Regeneration = Growl, Mangle = Bestial Wrath, Healing Touch = Greater Heal) : c'est
l'emprunt voulu, mais deux fiches indépendantes.

### Plafond de 5

Les trois mécaniques empruntées ont un plafond de 5 (Combo, Frenzy) ou de 4 (Charges du Mage). Avec **5**, les
cartes Cat et Bear reprennent telles quelles les chiffres du Rogue et du Hunter (Eviscerate à 5 Combo, frappe de
1 + 5 = 6, Bestial Wrath à cinq frappes) ; seules les cartes Moonkin changent par rapport au Mage, et elles sont
écrites pour le Druid de toute façon. Avec 4, les finisseurs Cat (Ferocious Bite : 20 au lieu de 24) et la frappe
de l'ours perdraient un cran, soit deux mécaniques sur trois à recalculer au lieu d'une. Contrepartie mesurée
dans les chiffres : Moonkin à 5 Charges donne +5 par coup ; les cartes Moonkin à plusieurs coups sont donc
évitées (aucune « twice » ni « three times » en Moonkin) et les cartes « to all » en Moonkin ont une base basse
(Hurricane 15 à tous).

## 3. Les 34 cartes

Colonnes : **Niv.** = niveau de classe qui débloque la carte (§ 7) ; **Forme** = mot de plaque (— = sans forme) ;
**Plaque** = autres mots de la plaque (dans `text`, en fin de texte, « Power. » / « Cast. » en tête) ; dans les
textes, « / » sépare les clauses (`\n`) ; **Amélioré** = palier +1 ; paliers +2 et +3 : § 3.5. Toutes les cartes
tiennent en quatre lignes au plus (retour glouton à 22 caractères, plaque non comptée) : trois lignes au plus en
base et au +1 (Skull Bash, Demoralizing Roar, Moonfire, Rake), quatre au +3 de Demoralizing Roar.

### 3.1 Départ (4, rareté basic)

| id | Nom | Forme | Coût | Type | Plaque | Texte | Amélioré | Icône | Calé sur |
|---|---|---|---|---|---|---|---|---|---|
| `wrath` | Wrath | Moonkin | 1 | Attack | | Deal 5. / +1 Charge. | Deal 8. / +1 Charge. | Spell_Nature_WrathV2 | Arcane Blast 6 / 9 (Mage) : −1 car le Druid en a trois |
| `thick_hide` | Thick Hide | Bear | 1 | Skill | | Gain 5 Absorb. | Gain 8 Absorb. | Ability_Druid_Ironfur | Mana Shield 5 / 8, Defend 5 |
| `maul` | Maul | Bear | 1 | Attack | | Deal 4. / Bear strikes. | Deal 7. / Bear strikes. | Ability_Druid_Maul | Arcane Shot 3 / 6 + Pet attacks |
| `ferocious_bite` | Ferocious Bite | Cat | 1 | Attack | | Surge: deal 4 + 4 per Combo. | Surge: deal 6 + 5 per Combo. | Ability_Druid_FerociousBite | Eviscerate (Rogue, `minRes = 1`) |

### 3.2 Feral (10 : Cat, Bear, Interrupt ; 4 communes, 4 inhabituelles, 2 rares)

| id | Nom | Rareté | Niv. | Forme | Coût | Type | Plaque | Texte | Amélioré | Icône | Calé sur |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `shred` | Shred | common | 1 | Cat | 1 | Attack | | Deal 7. / +1 Combo. | Deal 10. / +1 Combo. | Spell_Shadow_VampiricAura | Hemorrhage 7 + 1 Combo, sans Sundered |
| `rake` | Rake | common | 1 | Cat | 1 | Attack | | Deal 3. / +1 Combo. / Apply DoT 3 | Deal 4. / +1 Combo. / Apply DoT 5 | Ability_Druid_Rake | Garrote |
| `swipe` | Swipe | common | 1 | Bear | 1 | Attack | | Deal 4 to all. / Bear strikes. | Deal 6 to all. / Bear strikes. | Ability_Druid_Swipe | Multi-Shot 5 à tous + Pet attacks (inhabituelle) |
| `skull_bash` | Skull Bash | common | 1 | — | 0 | Skill | Cooldown 2 | Interrupt the target's cast. / Draw 1. | (Cooldown 1) | INV_Bone_Skull_04 | Silence (Priest) |
| `rip` | Rip | uncommon | 2 | Cat | 1 | Skill | | Surge: apply DoT 3 per Combo. | Surge: apply DoT 4 per Combo. | Ability_GhoulFrenzy | Rupture (`minRes = 1`) |
| `frenzied_regeneration` | Frenzied Regeneration | uncommon | 1 | Bear | 1 | Skill | | Gain 6 Absorb. / Spend 2: gain 6 more. | Gain 8 Absorb. / Spend 2: gain 8 more. | Ability_BullRush | Growl (Hunter) |
| `tigers_fury` | Tiger's Fury | uncommon | 1 | Cat | 0 | Skill | Cooldown 2 | +1 Combo. / Draw 1. | (Cooldown 1) | Ability_Mount_JungleTiger | Premeditation, Kick |
| `mangle` | Mangle | rare | 4 | Bear | 1 | Skill | | Surge: Bear strikes once per Frenzy. / +2 Frenzy. | … / +3 Frenzy. | Ability_Druid_Mangle2 | Bestial Wrath ; jouable à 0 (`minRes = 0`) ; coût 2 sans gain jusqu'au 19/11/2026 |
| `demoralizing_roar` | Demoralizing Roar | uncommon | 6 | Bear | 0 | Skill | Cooldown 4 | +1 Frenzy. / Apply Demoralized 2 ⌛ to all | (Cooldown 3) | ABILITY_DRUID_DEMORALIZINGROAR | Demoralizing Shout (Warrior) |
| `leader_of_the_pack` | Leader of the Pack | rare | 7 | — | 0 | Power | | Power. / Cat Attacks: +1 Combo. | Power. / Cat Attacks: +1 Combo, deal 2 more. | Spell_Nature_UnyeildingStamina | Venomous Wounds (rare, moteur de Combo) ; coût 1 jusqu'au 19/11/2026 |

### 3.3 Balance (10 : Moonkin ; 5 communes, 3 inhabituelles, 2 rares)

| id | Nom | Rareté | Niv. | Forme | Coût | Type | Plaque | Texte | Amélioré | Icône | Calé sur |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `starfire` | Starfire | common | 1 | Moonkin | 2 | Attack | Cast | Cast. / Deal 24. | Cast. / Deal 30. | Spell_Arcane_StarFire | Holy Fire 24 + DoT 3 ; +Charges si fin en Moonkin ; 20 jusqu'au 19/11/2026 |
| `moonfire` | Moonfire | common | 1 | Moonkin | 1 | Attack | | Deal 3. / +1 Charge. / Apply DoT 3 | Deal 5. / +1 Charge. / Apply DoT 4 | Spell_Nature_StarFall | Garrote, Fireball |
| `starsurge` | Starsurge | common | 1 | Moonkin | 1 | Attack | | Surge: deal 7 per Charge. | Surge: deal 8 per Charge. | Spell_Arcane_Arcane03 | Nightblade 6 par Combo (`minRes = 1`) ; 6 jusqu'au 19/11/2026 |
| `faerie_fire` | Faerie Fire | common | 1 | Moonkin | 0 | Skill | Cooldown 3 | +1 Charge. / Gain 3 Absorb. / Apply Sundered 2 ⌛ | (Cooldown 2) | Spell_Nature_FaerieFire | Hunter's Mark 3, Exhaust |
| `insect_swarm` | Insect Swarm | common | 1 | Moonkin | 1 | Skill | | Gain 5 Absorb. / Apply DoT 4 / Apply Demoralized 1 ⌛ | Gain 7 Absorb. / Apply DoT 6 / Apply Demoralized 1 ⌛ | Spell_Nature_InsectSwarm | Crippling Poison 2 + Demoralized 1 |
| `hurricane` | Hurricane | uncommon | 2 | Moonkin | 2 | Attack | Cast | Cast. / Deal 15 to all. | Cast. / Deal 18 to all. | Spell_Nature_Cyclone | Blizzard 12 à tous + Demoralized 2 ; 12 jusqu'au 19/11/2026 |
| `entangling_roots` | Entangling Roots | uncommon | 1 | Moonkin | 1 | Skill | Cooldown 4 | +1 Charge. / Apply Stunned 1 ⌛ | (Cooldown 3) | Spell_Nature_StrangleVines | Chastise, Wyvern Sting |
| `starfall` | Starfall | rare | 4 | Moonkin | 1 | Attack | | Surge: deal 6 per Charge to all. | Surge: deal 7 per Charge to all. | Ability_Druid_Starfall | Arcane Barrage (commune, plafond 4) : 30 à tous à 5 |
| `natures_grace` | Nature's Grace | uncommon | 6 | — | 1 | Power | | Power. / Cast cards: cost −1. | (coût 0) | Spell_Nature_NaturesBlessing | Apotheosis (rare, + 1 mana) |
| `moonkin_aura` | Moonkin Aura | rare | 7 | — | 1 | Power | | Power. / End of turn in Moonkin: +1 Charge. | (coût 0) | Spell_Nature_ForceOfNature | Shadow Dance (moteur rare) ; raison de finir en Moonkin |

### 3.4 Restoration (10 : Tree of Life et Powers ; 4 communes, 4 inhabituelles, 2 rares)

| id | Nom | Rareté | Niv. | Forme | Coût | Type | Plaque | Texte | Amélioré | Icône | Calé sur |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `rejuvenation` | Rejuvenation | common | 1 | Tree | 1 | Skill | Exhaust | Gain Regen 4 | Gain Regen 6 | Spell_Nature_Rejuvenation | Renew 3, Exhaust |
| `regrowth` | Regrowth | common | 1 | Tree | 1 | Skill | Exhaust | Heal 4. / Gain Regen 3 | Heal 6. / Gain Regen 4 | Spell_Nature_ResistNature | Flash Heal 7 + Draw 1, Exhaust |
| `mark_of_the_wild` | Mark of the Wild | common | 1 | Tree | 1 | Skill | | Gain 4 Absorb. / Gain Regen 2 | Gain 6 Absorb. / Gain Regen 3 | Spell_Nature_Regeneration | Radiance 4 + Atonement 1 |
| `thorns` | Thorns | common | 1 | — | 1 | Power | | Power. / When hit: deal 3 to the attacker. | (coût 0) | Spell_Nature_Thorns | Retaliation 4 (inhabituelle, niveau 6) |
| `swiftmend` | Swiftmend | uncommon | 1 | Tree | 0 | Skill | Exhaust | Heal 2 per Regen. | Heal 2 per Regen. / Draw 1. | INV_Relics_IdolofRejuvenation | soin immédiat sans retirer la Regen |
| `rebirth` | Rebirth | rare | 4 | — | 1 | Power | | Power. / Last Breath: stay at 1 HP, heal 12. | (coût 0) | Spell_Nature_Reincarnation | Last Stand 15, Ice Block 10 |
| `natures_swiftness` | Nature's Swiftness | uncommon | 2 | — | 0 | Skill | Exhaust | Draw 1. / Gain Instant 1 | Draw 2. / Gain Instant 1 | Spell_Nature_RavenForm | Combustion (Draw 2, Instant 2, rare) |
| `healing_touch` | Healing Touch | uncommon | 1 | Tree | 1 | Skill | Cast, Exhaust | Cast. / Heal 12. | Cast. / Heal 16. | SPELL_NATURE_HEALINGTOUCH | Greater Heal 10, Cast, Exhaust |
| `gift_of_nature` | Gift of Nature | uncommon | 6 | — | 1 | Power | | Power. / Regen: Attack hits deal 2 more. | (coût 0) | Spell_Nature_ProtectionformNature | Shatter (« Frozen: Attack hits deal 4 more. ») |
| `tranquility` | Tranquility | rare | 7 | Tree | 2 | Skill | Exhaust | Heal 6. / Gain Regen 5 | Heal 9. / Gain Regen 6 | Spell_Nature_Tranquility | rare de soin, une fois par combat |

Comptes : 4 de départ ; 13 communes (Feral 4, Balance 5, Restoration 4) ; 11 inhabituelles (4, 3, 4) ; 6 rares
(2 par voie) = 34. Par forme : Cat 5 (Ferocious Bite, Shred, Rake, Rip, Tiger's Fury), Bear 6 (Thick Hide, Maul,
Swipe, Frenzied Regeneration, Mangle, Demoralizing Roar), Moonkin 9 (Wrath et la voie Balance hors Powers),
Tree 6 (Rejuvenation, Regrowth, Mark of the Wild, Swiftmend, Healing Touch, Tranquility), sans forme 8 (Skull
Bash, Nature's Swiftness, six Powers). Attack hors Cast : toutes à 1 mana (Clearcasting vaut 1 mana) ; Attack
Cast : Starfire et Hurricane (2 mana, exclues de Clearcasting).

Notes :

- Icônes : noms exacts des fichiers de `~/Téléchargements/ICONS/` (vérifiés le 18/11/2026). Shred
  (`Spell_Shadow_VampiricAura`), Starsurge (`Spell_Arcane_Arcane03`), Frenzied Regeneration (`Ability_BullRush`),
  Leader of the Pack (`Spell_Nature_UnyeildingStamina`) : icônes de substitution, à vérifier au moment du code.
- Swiftmend : « Heal 2 per Regen. » soigne deux fois la Regen du Druid **sans la retirer** ; Exhaust (les PV se
  gardent d'un combat à l'autre, les soins répétables dominaient chez le Priest, `docs/equilibrage.md`).
- Healing Touch (Cast) entre en Tree of Life au jeu ; le soin se résout au tour suivant dans n'importe quelle
  forme (un soin ne dépend pas de la forme). Nature's Swiftness le rend immédiat.
- Gift of Nature : « Regen: » = le Druid a Regen au moment du coup ; vaut pour les cartes Attack de toutes les
  formes, pas pour la frappe de l'ours ni les coups de fin de tour de Moonkin (coups sans carte).
- Maul et Rake sont aussi des noms d'actions ennemies (`Data/Zones/Duskwood.lua`, `Wetlands.lua`,
  `Stranglethorn.lua`) : des intentions, pas des cartes. Décision du joueur (18/11/2026) : ils gardent leurs noms.
- Insect Swarm est la carte de contrôle de Balance, sans gain de réserve en base et au +1 (comme Hurricane) ; il
  reçoit « +1 Charge. » au palier +2.

### 3.5 Paliers d'amélioration +2 et +3

Règles suivies, celles du Rogue et du Hunter (`docs/ameliorations.md`) : Retain pour les cartes qu'on garde pour
le bon moment (finisseurs, Cast) ; un seul palier monte le « par point » d'un Surge ; coût d'un Power baissé une
seule fois ; aucun Stunned allongé (Stun Resistant des élites) ; pas de pioche ajoutée aux cartes à 0 qui n'en ont
pas. Chaque colonne ne dit que ce que le palier ajoute.

| Carte | +1 (tableau ci-dessus) | +2 | +3 |
|---|---|---|---|
| Wrath | Deal 8 | Deal 10 | Deal 12 |
| Thick Hide | 8 Absorb | 10 Absorb | Retain |
| Maul | Deal 7 | Deal 9 | `+1 Frenzy.` avant la frappe |
| Ferocious Bite | 6 + 5 par Combo | 9 + 5 par Combo | Retain |
| Shred | Deal 10 | Deal 12 | Deal 14 |
| Rake | Deal 4, DoT 5 | DoT 7 | Deal 6 |
| Swipe | 6 à tous | 7 à tous | `+1 Frenzy.` avant la frappe |
| Skull Bash | Cooldown 1 | Retain | `Interrupt all casts.` |
| Rip | DoT 4 par Combo | Retain | DoT 5 par Combo |
| Frenzied Regeneration | 8 / 8 | 10 / 8 | Spend 1 |
| Tiger's Fury | Cooldown 1 | Retain | +2 Combo |
| Mangle | `+3 Frenzy.` | Retain | coût 0 |
| Demoralizing Roar | Cooldown 3 | +2 Frenzy | `Gain 4 Absorb.` |
| Leader of the Pack | `Cat Attacks: +1 Combo, deal 2 more.` | Innate | deal 3 more |
| Starfire | Deal 30 | Deal 34 | Deal 38 |
| Moonfire | Deal 5, DoT 4 | DoT 6 | Deal 7 |
| Starsurge | 8 par Charge | Retain | 9 par Charge |
| Faerie Fire | Cooldown 2 | Sundered 3 | Retain |
| Insect Swarm | 7 Absorb, DoT 6 | `+1 Charge.` en tête | Demoralized 2 ⌛ |
| Hurricane | 18 à tous | Retain | 21 à tous |
| Entangling Roots | Cooldown 3 | `Apply DoT 4` | Retain |
| Starfall | 7 par Charge à tous | Retain | 8 par Charge à tous |
| Nature's Grace | coût 0 | Innate | au jeu : `Gain Instant 1` |
| Moonkin Aura | coût 0 | Innate | `+2 Charges.` par fin de tour |
| Rejuvenation | Regen 6 | Regen 7 | Retain |
| Regrowth | Heal 6, Regen 4 | Draw 1 | Heal 8 |
| Mark of the Wild | 6 Absorb, Regen 3 | 8 Absorb | Retain |
| Thorns | coût 0 | deal 4 | Innate |
| Swiftmend | Draw 1 | Retain | Heal 3 per Regen |
| Rebirth | coût 0 | heal 16 | Innate |
| Nature's Swiftness | Draw 2 | Retain | Instant 2 |
| Healing Touch | Heal 16 | Retain | sans Cast (se résout tout de suite) |
| Gift of Nature | coût 0 | Innate | deal 3 more |
| Tranquility | Heal 9, Regen 6 | coût 1 | Retain |

## 4. Les trois voies

### Feral — monter en Cat, finir en Bear

Moteur : les cartes Cat montent la réserve en Combo (Shred, Rake, Tiger's Fury) et la vident par un Surge (Ferocious
Bite, Rip) ; les cartes Bear donnent l'Absorb du tour ennemi (Thick Hide, Frenzied Regeneration) et font frapper
l'ours (Maul, Swipe), dont chaque frappe rend un point. Finir en Bear donne la frappe de fin de tour ; finir en
Cat, quand l'Absorb ne sert pas (ennemi qui se protège, s'invoque des renforts ou incante), rend la première
Attack du tour suivant gratuite (Clearcasting). Ce qu'elle cherche : alterner chaque tour entre construire (Cat)
et tenir (Bear).

Cartes : Shred, Rake, Swipe, Skull Bash, Rip, Frenzied Regeneration, Tiger's Fury, Mangle, Demoralizing Roar,
Leader of the Pack.

- Avec **Balance** : Wrath, Moonfire et Faerie Fire montent la réserve en Charges, Ferocious Bite la vide en
  Combo ; Mangle vide en Frenzy ce que Moonkin a monté.
- Avec **Restoration** : Thorns punit les coups que l'ours encaisse ; Gift of Nature (sous Regen) renforce chaque
  attaque Cat et Bear.
- Tour type (3 mana, réserve 2, fin du tour précédent en Bear, main : Tiger's Fury, Shred, Ferocious Bite,
  Frenzied Regeneration, Rake) : Tiger's Fury (0, Cat : 3 Combo, pioche Maul) ; Shred (1 : 7, 4 Combo) ;
  Ferocious Bite (1 : 4 + 16 = 20, réserve 0) ; Frenzied Regeneration (1, Bear : 6 Absorb, sans Spend). Fin en
  Bear : frappe de 1, réserve 1 ; fin du round : 0. Deux changements de forme (Bear → Cat → Bear), aucun compté
  (Cat ↔ Bear hors taxe, § 1.6) : 3 mana au tour suivant. Variante si
  l'ennemi annonce une défense : Rake (1, Cat) au lieu de Frenzied Regeneration, fin en Cat : ni frappe ni
  Absorb, Clearcasting posé, réserve 1 ; au tour suivant, la première Attack (Shred, Maul…) coûte 0 : quatre
  cartes à 1 mana pour 3 mana.

### Balance — Charges et gros Cast

Moteur : les cartes Moonkin montent les Charges (Wrath, Moonfire, Faerie Fire, Entangling Roots) et chaque coup
des Attack en Moonkin les ajoute à ses dégâts ; Starsurge et Starfall vident la réserve ; Starfire et Hurricane
sont des Cast qui ne profitent des Charges que si l'on finit le tour en Moonkin ; finir en Moonkin touche aussi
tous les ennemis (1 par 2 Charges, 3 à 5 Charges). Ce qu'elle cherche : le tour fini en Moonkin avec 5 Charges
et un Cast en attente.

Cartes : Starfire, Moonfire, Starsurge, Faerie Fire, Insect Swarm, Hurricane, Entangling Roots, Starfall,
Nature's Grace, Moonkin Aura.

- Avec **Feral** : finir en Bear protège le tour ennemi au prix du bonus sur le Cast et des coups à tous ;
  Ferocious Bite et Mangle dépensent autrement ce que Moonkin a monté.
- Avec **Restoration** : Nature's Swiftness fait partir Starfire tout de suite, en Moonkin ; Mark of the Wild et la
  Regen couvrent un tour fini en Moonkin, sans Absorb de l'ours. Seule, Balance tient le tour ennemi par l'Absorb
  d'Insect Swarm et de Faerie Fire (19/11/2026).
- Tour type (3 mana, réserve 3, Moonkin depuis le tour précédent, Starfire en attente) : début du tour, Starfire
  se résout en Moonkin : 24 + 3 = 27. Faerie Fire (0 : 4 Charges, 3 Absorb, Sundered 2) ; Wrath (1 : 5 + 4 = 9, ×1,25 sous
  Sundered = 11, 5 Charges) ; Starfire (2, Cast) ; on reste en Moonkin : aucune frappe, aucun Absorb ; fin de
  tour : 3 dégâts à chaque ennemi (5 Charges) ; Starfire vaudra 24 + 5 = 29 au tour suivant, 36 si la cible porte
  encore Sundered.

### Restoration — Regen, soins, et la réserve en attente

Moteur : la Regen empilée (Rejuvenation, Regrowth, Mark of the Wild) se convertit en soin immédiat (Swiftmend) ;
Gift of Nature fait de la Regen un bonus d'attaque pour toutes les formes, Thorns rend des dégâts à chaque coup
reçu. En Tree of Life, la réserve n'a pas d'effet et ne baisse pas : on soigne sans perdre ce qui a été monté ;
finir le tour en Tree of Life donne 2 Absorb. Ce qu'elle cherche : le combat long. Voie d'appoint : plus faible
seule que Feral et Balance seules depuis le 19/11/2026 (§ 10).

Cartes : Rejuvenation, Regrowth, Mark of the Wild, Thorns, Swiftmend, Rebirth, Nature's Swiftness, Healing Touch,
Gift of Nature, Tranquility.

- Avec **Feral** : les soins Tree se jouent au milieu du tour, puis une carte Bear ramène en Bear pour la
  frappe et l'Absorb ; Gift of Nature renforce Shred, Rake, Maul et Swipe sous Regen.
- Avec **Balance** : Nature's Swiftness fait partir un Cast tout de suite ; la Regen couvre les tours finis en
  Moonkin.
- Tour type (3 mana, Regen 0, réserve 3, fin du tour précédent en Bear) : Rejuvenation (1, Tree : Regen 4) ;
  Swiftmend (0 : soin 8) ; Wrath (1, Moonkin : 5 + 3 = 8, 4 Charges) ; Thick Hide (1, Bear : 5 Absorb). Fin en
  Bear : frappe de 5, réserve 5 ; fin du round : 4. Trois changements de forme (Bear → Tree → Moonkin → Bear) :
  levier A, −2 mana au tour suivant. Finir en Tree of Life (Thick Hide gardée) aurait donné 2 Absorb,
  sans frappe ni Absorb : à réserver aux tours sans menace.

### Pourquoi la réserve ne vaut rien en Tree of Life

Décision confirmée par le joueur (18/11/2026) : la réserve n'a pas de lecture en Tree of Life, et l'effet de fin
de tour de la forme ne la lit pas.

- La voie Restoration a déjà sa jauge : la **Regen**, qu'elle empile puis convertit (Swiftmend). Une seconde
  lecture en Tree of Life doublerait la jauge de la voie.
- Toute lecture en Tree of Life qui soignerait (« +1 soin par point », « Regen par point ») transformerait la réserve
  en PV, qui se gardent d'un combat à l'autre : c'est ce qui a obligé à rendre les soins du Priest Exhaust.
- Trois lectures empruntées (Combo, Frenzy, Charges) sont la limite de lisibilité de la pastille.
- Conséquence : Tree of Life est surtout une forme de passage, choisie pour ses cartes ; y finir le tour donne
  2 Absorb, volontairement petit (le repli prévu au § 1.3, appliqué le 19/11/2026 ; Regen 2 avant). L'épique
  Lifebloom (§ 5) donne à la Regen un
  rôle sur la réserve, pour un build.

## 5. Cartes épiques (une par zone)

Gabarit des épiques (`docs/zones/cartes-de-zone.md`) : règle en jeu dès le début du combat, deux lignes au plus,
« Déclencheur: Mot N. », l'à-côté (mot de règle, `L.rule`) donne la règle complète. Noms : sorts ou talents de
druide absents de `Data/` (vérifié ; « Berserk » et « Ravage » sont pris par Stranglethorn Vale et évités).

| Zone | Épique | Voie | Texte (base) | Mot de règle : à-côté | N (base / +1 / +2 / +3) | Icône | Ce qu'elle fait construire |
|---|---|---|---|---|---|---|---|
| 1 Westfall | Furor | Restoration | `Form changes: Primal 2.` | Primal : `The reserve gains 1 on each form change, at most N times per turn.` | 2 / 3 / 4 / 5 | Spell_Holy_BlessingOfStamina | un deck qui change de forme à chaque carte (simple, lisible en une fois) ; incompatible avec le levier A |
| 2 Duskwood | Mark of Ursol | Feral | `Bear strikes: Ironfur 50%.` | Ironfur : `Gain Absorb equal to N% of each Bear strike's damage, rounded down.` | 50 / 75 / 100 / 125 | Ability_Druid_MarkofUrsol | un ours qui frappe souvent et haut (Maul, Swipe, Mangle, Frenzy à 5) et tient par ses frappes |
| 3 Wetlands | Eclipse | Balance | `Cast cards: Eclipse 5.` | Eclipse : `With at least N in the reserve, Moonkin Cast cards resolve at once.` | 5 / 4 / 4 / 3 (+2 : `and deal 3 more`) | Ability_Druid_Eclipse | monter à 5, puis Starfire et Hurricane tout de suite, avec le bonus, et finir en Bear |
| 4 Stranglethorn Vale | King of the Jungle | Feral | `Surge cards: Predator 1.` | Predator : `The Surge counts the whole reserve, then N stays in it.` | 1 / 2 / 2 / 3 (+2 : `the first Surge each turn draws 1`) | Ability_Druid_KingoftheJungle | plusieurs Surge par combat (Ferocious Bite, Rip, Starsurge, Mangle) |
| 5 Swamp of Sorrows | Lifebloom | Restoration | `Each Regen heal: Bloom 1.` | Bloom : `The reserve gains N each time Regen heals, even at full HP.` | 1 / 1 / 2 / 2 (+1 et +3 : `Each combat starts with Regen 3`, puis 5) | INV_Misc_Herb_Felblossom | la Regen comme générateur : Rejuvenation et Regrowth nourrissent les Surge des autres formes |
| 6 Burning Steppes | Owlkin Frenzy | Balance | `When hit: Moonfury 1.` | Moonfury : `In Moonkin, a hit that costs HP gives N to the reserve, once per enemy attack.` | 1 / 2 / 2 / 3 (+2 : `End of turn in Moonkin: gain 3 Absorb.`) | Ability_Druid_OwlkinFrenzy | finir en Moonkin et encaisser (la Rage du Warrior, bornée à Moonkin) |
| 7 Blackrock Mountain | Heart of the Wild | Feral | `Forms: Kinship 3.` | Kinship : `Cat, Bear and Moonkin each keep their own reserve, up to N.` | 3 / 4 / 5 / 5 (+3 : `each starts at 1`) | Spell_Holy_BlessingOfAgility | trois réserves séparées : un deck à trois formes qui construit chacune pour elle (un Surge ne vide que la sienne) |

Par voie : Feral 3, Balance 2, Restoration 2. Textes : « Epic. » en tête, deux lignes, aucun « you / your ».
Nouveaux déclencheurs : `Form changes`, `Bear strikes`, `Forms`. Heart of the Wild change le contrat de la
ressource (trois valeurs dans `c.cls` au lieu de `c.player.res`) : c'est l'épique la plus chère à coder, placée à
Blackrock pour cette raison.

Lifebloom s'appelait Tree of Life, nom pris par la forme ; son icône (`Ability_Druid_TreeofLife`) passe à la
forme, et Lifebloom prend `INV_Misc_Herb_Felblossom` (icône du sort dans WoW, présente dans
`~/Téléchargements/ICONS/`). Jusqu'au 19/11/2026, avec la Regen 2 de fin de tour en Tree of Life, Lifebloom donnait N points de réserve
au début du tour suivant (le seul lien entre la forme et la réserve) ; depuis, la fin de tour en Tree of Life donne
de l'Absorb, et Lifebloom ne lit plus que la Regen des cartes.

**Codées le 18/11/2026** (`Data/Druid.lua`, `Core/Classes/druid.lua`, tests `Sim/tests_epic_druid.lua` ; détail :
`docs/classes.md`, « Épiques du Druid »). Nombres de la table ci-dessus, non mesurés. Écarts tranchés au codage :

- **Eclipse** : le mot de règle « Eclipse » est le nom de la carte (refusé par le harnais, nom unique) : **`Lunar`**
  (« Cast cards: Lunar 5. ») ; les paliers +2 et +3, qui ajoutent « and deal 3 more », prennent le mot
  **`Solar`** (« Solar 4. », « Solar 3. »). Le Cast part tout de suite dans Moonkin (la forme change au jeu,
  avant la question), avec le bonus des Charges ; l'état Instant n'est pas consommé.
- Un mot de règle n'a qu'un texte amélioré (`docs/zones/cartes-de-zone.md`) : la règle ajoutée aux paliers 2 et
  3 passe par un second mot, comme pour le Hunter. King of the Jungle +2 / +3 : **`Apex`** (« Surge cards: Apex
  2. », la pioche du premier Surge) ; Owlkin Frenzy +2 / +3 : **`Barkskin`** (3 Absorb en fin de tour en
  Moonkin) ; Heart of the Wild +3 : **`Kindred`** (« each starts at 1 ») ; Lifebloom +3 : **`Overgrowth`**
  (Regen 5 au départ ; +1 et +2 : « Bloom », Regen 3 dans l'à-côté). Lifebloom +1 garde le texte de base sur la
  carte (« Bloom 1. ») : seul l'à-côté change (Regen 3 au début du combat).
- **King of the Jungle** : la réserve laissée revient **à la fin de la carte** (pas pendant le Surge) : Starsurge
  et Starfall ne gagnent pas le bonus des Charges (§ 1.1, point 5) ; jamais plus que le montant dépensé.
- **Owlkin Frenzy** : « once per enemy attack » = une fois par action ennemie (une Rafale de 4 coups, ou deux
  coups dans le même move, donnent N une fois) ; deux ennemis qui frappent : deux fois.
- **Heart of the Wild** : sans forme et en Tree of Life, une quatrième réserve (« Reserve ») que rien ne
  remplit ; `minRes` et Spend lisent la réserve de la forme de la carte (Ferocious Bite en Bear se joue sur le
  Combo en attente) : seul ajout au moteur, `Combat.cardRes`.

## 6. Bibelots de classe (6)

| id | Nom | Rareté | Niv. | Effet | Icône |
|---|---|---|---|---|---|
| `idol_of_the_wild` | Idol of the Wild | départ | 1 | `The first card each combat that changes form costs 0.` | INV_Misc_Idol_02 |
| `idol_of_brutality` | Idol of Brutality | common | 1 | `Bear strikes deal 2 more.` | INV_Misc_Idol_03 |
| `idol_of_ferocity` | Idol of Ferocity | uncommon | 3 | `Each Surge in Cat: draw 1.` | INV_Relics_IdolofFerocity |
| `idol_of_the_moon` | Idol of the Moon | uncommon | 5 | `End of turn in Moonkin: gain 4 Absorb.` | INV_MISC_IDOL_05 |
| `idol_of_rejuvenation` | Idol of Rejuvenation | rare | 7 | `Each Tree card played: gain 3 Absorb.` | INV_Relics_IdolofHealth (l'icône de l'idole du même nom sert déjà à Swiftmend, comme dans WoW) |
| `wolfshead_helm` | Wolfshead Helm | rare | 7 | `The first form change each turn: draw 1.` | INV_Helmet_04 |

Idol of the Wild amorce la mécanique au premier tour, comme Apprentice's Wand pour le Mage : le combat commence
sans forme, donc la première carte de forme jouée (Wrath, Thick Hide, Maul, Ferocious Bite) est gratuite ; son
coût tombe à 0 avant le paiement (crochet `cost`, qui lit si la carte changerait la forme). Les cinq autres
couvrent chacune une forme (Bear, Cat, Moonkin, Tree of Life) et le changement de forme. Idol of the Moon ajoute
de l'Absorb à la fin de tour en Moonkin, qui n'en a pas ; Wolfshead Helm reprend l'ancienne Idol of the Wild
(+1 mana par Shift, trop fort quand chaque carte change la forme) en pioche, une fois par tour.

## 7. Progression (niveaux de classe 1 à 7)

| Niveau | Feral | Balance | Restoration | Bibelots |
|---|---|---|---|---|
| 1 | Shred, Rake, Swipe, Skull Bash, Tiger's Fury, Frenzied Regeneration | Starfire, Moonfire, Starsurge, Faerie Fire, Insect Swarm, Entangling Roots | Rejuvenation, Regrowth, Mark of the Wild, Thorns, Swiftmend, Healing Touch | Idol of the Wild, Idol of Brutality |
| 2 | Rip | Hurricane | Nature's Swiftness | |
| 3 | | | | Idol of Ferocity |
| 4 | Mangle (rare) | Starfall (rare) | Rebirth (rare) | |
| 5 | | | | Idol of the Moon |
| 6 | Demoralizing Roar | Nature's Grace | Gift of Nature | |
| 7 | Leader of the Pack (rare) | Moonkin Aura (rare) | Tranquility (rare) | Idol of Rejuvenation, Wolfshead Helm |

Plus les 4 cartes de départ au niveau 1 (22 cartes ; 34 au niveau 7). Le niveau 1 suffit pour gagner : chaque
voie y a un générateur, une dépense ou un gros coup, de la défense et du soin (Feral : Shred, Rake, Tiger's Fury,
Ferocious Bite, Swipe, Frenzied Regeneration ; Balance : Moonfire, Faerie Fire, Entangling Roots, Starsurge,
Starfire ; Restoration : Regen, Swiftmend, Healing Touch, Thorns), plus l'Interrupt (Skull Bash). Aucune rare au
niveau 1, comme le Mage et le Rogue : une seule rare au niveau 1 serait la seule carte de chaque récompense de
boss (tirage `boss = { rare = 1 }`) et s'empilerait dans le deck (§ 10, « Compte neuf »). Les déblocages ouvrent
une façon de jouer : au 2, la dépense en DoT (Rip), le Cast à tous (Hurricane) et l'Instant ; au 4, les grosses
dépenses (Mangle, Starfall) et le Last Breath (Rebirth, comme Ice Block et Cheat Death) ; au 6, Demoralized à
tous, Cast moins chers, la Regen offensive ; au 7, les moteurs (Leader of the Pack, Moonkin Aura) et Tranquility.
Répartition revue le 18/11/2026 pour le compte neuf (trois échanges dans une même voie, nombre de cartes par niveau
inchangé : Rip 1 → 2 et Tiger's Fury 2 → 1, Hurricane 1 → 2 et Entangling Roots 2 → 1, Rebirth 1 → 4 et Healing
Touch 4 → 1).

## 8. Points d'accroche dans le code

### Ce qui existe déjà (`docs/classes.md`)

| Besoin du Druid | Point d'accroche existant |
|---|---|
| Forme active | état de classe `c.cls.form` (données simples, cloné, sauvegardé), laissé à `nil` par `init` (combat sans forme) ; valeurs `"cat"`, `"bear"`, `"moonkin"`, `"tree"` |
| Changement de forme au jeu | crochet de classe `onCardCommitted` (inst, d, cible) : après tous les coûts, avant incantation ou résolution, et avant les Powers et bibelots (crochets de classe en premier) ; ne passe pas pour une copie (`replay`, `copyCard`) |
| Événement de changement | `Combat.fire(c, "onShift", from, to)` (trois arguments au plus) ; Powers, bibelots et épiques s'y abonnent |
| Réserve | ressource commune `c.player.res`, `resource.cap = 5`, `keep = true` ; `Combat.gainRes`, `Combat.surge`, `Combat.spendRes`, `minRes`, `spend` ; effet `res` (« +1 Combo. ») ; `per = { k, "surge" }` |
| Bonus de Moonkin | crochet de classe `damage` (v, cible, d) : `v + res` si `c.cls.form == "moonkin"` et `d.type == "attack"` (même code que `ns.ClassRules.mage`) ; lu au coup, donc à la résolution d'un Cast |
| Effet de fin de tour des quatre formes | crochet de classe `onTurnEnd` (avant Powers, bibelots et défausse), comme le familier ; rien si `c.cls.form == nil` |
| Tree of Life : 2 Absorb | `Combat.gainBlock(c, c.player, Druid.TREE_ABSORB)` (Regen `Druid.TREE_REGEN` par `Combat.applyStatus` jusqu'au 19/11/2026) |
| Cat : Clearcasting (coût 0 de la prochaine Attack) | même assemblage que deux mécaniques du Rogue : état à drapeau consommé par la première Attack dans le crochet de classe `onCardCommitted` (Stealth, `Core/Classes/rogue.lua` : `ns.Statuses.stealth = { flag = true }`) et crochet de coût qui rend une Attack gratuite (Slice and Dice, `Data/Rogue.lua` : `cost` → 0 si `d.type == "attack"`) ; crochet `cost` au niveau de la classe déjà employé (`ns.ClassRules.warrior`) ; coût en main par `Combat.cost` ; Cast lu sur `d.cast` ; icône et texte court de l'état déclarés par la classe (`Art.statuses`, `Art.statusShort`, comme `UI/Art/rogue.lua`) |
| Moonkin : coups à tous | coup sans carte (`Combat.calcDamage` avec `cardDef` nil, comme le familier) répété sur chaque ennemi vivant ; le familier sait déjà toucher tous les ennemis (crochet `petAll` des épiques du Hunter) |
| Baisse en Bear | crochet de classe `onRoundEnd` : −1 si `c.cls.form == "bear"` (même code que le Hunter) |
| Cible de la frappe | `c.player.lastTarget` (posée par `Combat.play`) |
| Levier A (actif) | crochet de classe `maxMana` (mana du tour suivant) |
| Idol of the Wild | crochet `cost` (d, inst) : 0 si la carte changerait la forme et que le bibelot n'a pas servi (`c.relicState`) |
| Instant (Nature's Swiftness) | état commun `instant` (`Combat.isInstant`) |
| `Regen:` (Gift of Nature) | condition d'état `status:regen` (bienfait sur soi) |
| Soins, Absorb, DoT, Stunned, Demoralized, Sundered | effets communs `heal`, `absorb`, `apply` |
| Cible de la frappe affichée, dégâts de fin de tour de Moonkin sur chaque ennemi | `ns.ClassViews.druid` avec `enemyMarks = true` (comme le Hunter) |
| Animation du changement | `ns.ClassViews.druid.event` sur `{ t = "shift" }` |

### Ajouté au socle et codé (18/11/2026)

Ce qui manquait au socle existe maintenant ; la classe est codée dessus.

1. **Langage** (`Core/Language.lua`, `docs/classes.md`, « Ressource à noms multiples » et « Plaque lue sur une
   valeur ») : champ de carte `form`, plaque de forme lue sur `d.form` (mots `Cat`, `Bear`, `Moonkin`, `Tree`, un
   seul mot-clé, en tête de la plaque, jamais dans `text`) ; ressource `wild` à noms par forme (Reserve, Combo,
   Frenzy, Charge(s)) : `L.cardResource(d)`, `L.combatResource(c)` (lit `c.cls.form`), `L.cardResourceKeys(d)`
   pour un Power dont le déclencheur nomme une forme ; mot « Bear strikes » ; harnais U27. Déclencheurs déclarés
   par la classe (`Core/Classes/druid.lua`) : `Cat Attacks`, `End of turn in Moonkin`. Montant `regen`
   (`per = { k, "regen" }` : Swiftmend).
2. **Coup sans carte commun** : `Combat.strike(c, why, base, target, log, event, opts)` (`Core/Companion.lua`,
   `docs/classes.md`, « Coup sans carte »), partagé avec le familier du Hunter. Le Druid s'en sert pour :
   - la frappe de l'ours, `ns.Druid.bearStrike(c, why, counted)` : base `Druid.STRIKE_BASE` (1) passée par le
     crochet de classe **`bearStrike`** (valeur, nouveau : Idol of Brutality +2), + réserve, puis +1 (Surge :
     au montant compté, sans gain) ; journal `{ t = "bear_strike", dst, dmg, why }`, événement `onBearStrike` ;
     effet de carte `{ "bearStrike", n, surge = bool, per = … }` ;
   - les coups à tous de fin de tour en Moonkin, `ns.Druid.moonkinPulse(c)` : `min(PULSE_MAX, ceil(res / 2))`,
     journal `{ t = "moonkin_pulse", dst, dmg, why, all = true }` (un par ennemi), événement `onMoonkinPulse`.
   Aucun des deux ne reçoit le bonus des Charges : le crochet `damage` de la classe ne l'ajoute que si
   `cardDef` est une carte Attack (`d = nil` pour un coup sans carte).
3. **Genre des coups et règle du Swamp** (dormeurs, `Core/ZoneRules/swamp.lua`) : la frappe de l'ours a le genre
   `"pet"` (coup sans carte à une cible, comme le familier : Rude Awakening s'applique) et sa cible passe par le
   crochet de zone `petTarget`, comme `Hunter.petTarget` enveloppé par `Core/ZoneRules.lua` : la frappe de fin
   de tour évite un dormeur tant qu'un ennemi est éveillé (et attend si tous dorment), la frappe commandée par
   une carte pendant le jeu frappe la dernière cible, dormeur compris. Les coups de Moonkin ont le genre
   `"other"` à tous (réveil doux).
4. **Classe** (`Core/Classes/druid.lua`, `ns.ClassRules.druid`, `ns.Druid`) : `init` (`c.cls.form = nil`,
   `shifts`, `taxed`, `tax`) ; `onCardCommitted` (Clearcasting consommé par une Attack hors Cast, puis changement
   de forme : `ns.Druid.shift`, journal `{ t = "shift", from, to }`, événement `onShift(from, to)`, `c.cls.shifts`,
   et `c.cls.taxed` si `Druid.taxed(from, to)` : tout sauf Cat ↔ Bear, 19/11/2026) ;
   `cost` (Clearcasting) ; `damage` (Moonkin) ; `onTurnEnd` (`ns.Druid.endOfTurn` : Bear, Cat, Moonkin, Tree) ;
   `onRoundEnd` (−1 en Bear) ; `maxMana` et `c.cls.tax` (levier A, `Druid.TAX = 1`, `TAX_FREE = 1` : actif ; compteur de simulation `druid_tax`, mana perdu) ;
   état `clearcasting` (drapeau, journal `{ t = "clearcasting" }` à la pose, `{ t = "clearcasting_used", card }`
   à la consommation) ; aides `Druid.wouldShift(c, d)` (marque en main, Idol of the Wild),
   `Druid.strikeTarget`, `Druid.strikeDamage`, `Druid.pulseBase`, `Druid.pendingTax` (affichage, bots) ;
   `botKey` (forme, Clearcasting, dernière cible, bibelots servis) et `botValue` (Clearcasting = 22, bonus des
   Charges d'un Cast Attack en attente en Moonkin, baisse à venir en Bear, mana du levier A).
5. **Mesure** : compteurs de simulation `druid_end_<forme>` (forme de fin de chaque tour, `none` compris),
   `druid_shifts`, `druid_bear_strikes`, `druid_pulses`, `druid_clearcasting_used` (`Combat.zstat`, tableau
   « Statistiques de zone » du rapport) ; ligne « Druid, forme de fin de tour » (part de chaque forme,
   changements par tour) dans `Sim/sim.lua`.

Écarts à la fiche tranchés au codage : infobulle de Clearcasting sans parenthèse (U25) ; Mangle +2 (« +2 Frenzy. »
après les frappes) jouable à 0 (`minRes = 0` : la carte n'est plus faite que de Surge) ; journal des coups de
Moonkin `moonkin_pulse` (et non `moonkin_hits`).

### Ce qui reste

1. **Interface** (autre lot) : `UI/Art/druid.lua` (icônes, voies, `ns.ClassViews.druid`), pastille par forme
   (`UI/CombatView.lua`, `L.combatResource`), marque de forme en main (`UI/Widgets.lua`, `ns.Druid.wouldShift`),
   icône et texte court de Clearcasting, animations `shift`, `bear_strike`, `moonkin_pulse`, `clearcasting`.
2. **Épiques** (§ 5) : codées le 18/11/2026 ; Heart of the Wild garde dans `c.player.res` la réserve de la forme
   active et les autres dans `c.cls.kin` (pastille, `gainRes`, `surge` inchangés ; `minRes` et Spend par
   `Combat.cardRes`). Restent la mesure (`epic=<id>`) et les notes des bots.
3. **Bots et chiffres** : notes des cartes (`bot.rating`) posées à la main, à remplacer par un balayage ; valeurs des
   Powers du Druid dans `Bots.POWER_VALUE` (estimations) ; réglage des effets de fin de tour et des cartes (§ 10).

## 9. Conseils pour les bots de simulation

- **Choisir la forme de fin de tour** avant de jouer, et garder une carte de cette forme pour la fin du tour
  (jouer les cartes sans forme après elle) :
  - **Bear** par défaut quand l'ennemi annonce une attaque : frappe et Absorb des cartes Bear ;
  - **Cat** quand l'ennemi n'attaque pas ce tour-ci (défense, invocation, incantation) et qu'une Attack hors Cast
    sera jouée au tour suivant : Clearcasting vaut 1 mana ; inutile s'il est déjà posé (il ne s'empile pas) ;
  - **Moonkin** avec un Cast Moonkin en attente qui vaut plus que la frappe et l'Absorb (Starfire avec 4 ou 5
    Charges), ou contre trois ennemis et plus à 3 Charges et plus (2 ou 3 à chacun) ;
  - **Tree of Life** seulement contre une petite attaque et sans autre choix utile (2 Absorb).
  Un tour qui tue tout n'a pas de fin de tour à choisir.
- **Monter avant de dépenser** : jouer les générateurs de toutes les formes avant le Surge du tour ; ne pas monter
  au-delà de 5 ; un Surge à 1 ou 2 points seulement s'il tue ou si le combat finit. Finir en Moonkin après un
  Surge (réserve à 0) ne touche personne.
- **Moonkin** : jouer les Attack Moonkin après les générateurs Moonkin (le bonus compte au coup) ; ne pas jouer
  Starsurge ou Starfall avant les autres Attack Moonkin du tour (ils remettent les Charges à 0).
- **Clearcasting** : jouer d'abord l'Attack hors Cast qui le consomme (elle coûte 0), avant de compter le mana du
  tour ; une Attack Cast ne le consomme pas.
- **Ordre des soins** : soins Tree au milieu du tour, rarement en dernier (finir en Tree of Life ne donne que
  2 Absorb).
- **Spend** (Frenzied Regeneration) : dépenser seulement si l'Absorb sert au tour ennemi et que la frappe perdue
  vaut moins (2 points ≈ 2 dégâts par frappe).
- `bot.resValue` ≈ 5 (entre Combo et Frenzy) ; `botValue` de la forme de fin de tour : Bear, valeur de la frappe ;
  Cat, 22 (un mana, `evoMana` du Mage : 22 par mana) si Clearcasting n'est pas déjà posé ; Moonkin, dégâts à tous
  (`ceil(Charges / 2)` × ennemis vivants), plus le bonus de Charges d'un Cast en attente ; Tree of Life, 1 PV ;
  levier A : −22 par mana perdu au tour suivant (`c.cls.tax` posé par la fin de tour simulée).
- Mesurer la part des tours finis dans chaque forme (et sans forme) : un bot qui finit toujours en Tree of Life,
  ou jamais en Cat, a mal lu la classe (voir Forme d'ombre, `docs/equilibrage.md`).

## 10. Risques d'équilibrage et mesures

Les quatre effets de fin de tour (Clearcasting, frappe de 1 + réserve, 1 à tous par 2 Charges et 3 au plus,
2 Absorb en Tree of Life depuis le 19/11/2026, Regen 2 avant) sont des points de départ : la simulation règle
leurs chiffres.

| Risque | Pourquoi | Mesure (`runner=expedition class=druid`, heuristic, clé 0) |
|---|---|---|
| Transfert de réserve trop fort | monter en Moonkin (+1 dégât par coup en passant), vider en Cat : chaque point sert deux fois | dégâts par point de réserve ; victoires des decks à deux et trois formes ; activer le levier A si l'écart dépasse 10 points |
| Finir en Bear sans coût | la frappe (+1) et la baisse (−1) s'annulent : finir en Bear est gratuit dès qu'on a une carte Bear | part des tours finis en Bear ; si > 85 %, baisse en Bear à −2 ou frappe sans gain |
| Moonkin à 5 | +5 par coup sur Wrath, Moonfire, Hurricane (à chaque cible), plus 3 à tous en fin de tour | dégâts moyens de Hurricane à 3 ennemis ; Wrath à 5 Charges ; dégâts de fin de tour par combat contre les groupes ; repli : 1 à tous par 3 Charges, ou 2 au plus |
| Cat trop faible ou trop fort en fin de tour | Clearcasting vaut 1 mana, mais sans frappe ni Absorb | part des tours finis en Cat ; trop rare : Clearcasting donne aussi +1 Combo ; trop fréquent : il ne vaut que pour une Attack Cat |
| Combats qui traînent en Tree of Life | finir en Tree of Life pour remonter les PV à 1 par tour | part des tours finis en Tree of Life, tours par combat, PV nets ; repli appliqué le 19/11/2026 : Absorb pour le tour ennemi au lieu de Regen (§ 1.3) |
| Soins entre combats | Swiftmend (sans retirer la Regen), Tranquility (Regen 2 de Tree of Life jusqu'au 19/11/2026) | PV soignés par combat ; repli : Swiftmend retire la Regen |
| Idol of the Wild | +1 mana au premier tour de chaque combat | `sweep=relics` ; comparer à Apprentice's Wand |
| PV perdus, PV de départ 59 (58 puis 65 le 18/11/2026, 59 le 19/11/2026) | cible commune 6 à 9 PV par combat normal (`decisions.md`) ; 65 est au-dessus des classes réglées (Hunter et Rogue 50) | PV perdus et PV nets par combat ; régler les PV comme pour les autres classes |

### Réglage du 18/11/2026

Mesure : `luajit Sim/sim.lua runs=300 bot=heuristic seed=1 jobs=8 runner=expedition key=0 class=<classe>` (niveau 7,
`zones=0`, ± 2 à 4 points) ; détail et autres classes : `docs/equilibrage.md`, « Druid : premier réglage ».

| Réglage | Victoires | Normal : PV perdus / tours | Élite : PV | Boss : PV / tours | Changements par tour | Fins de tour Bear / Cat / Moonkin / Tree |
|---|---|---|---|---|---|---|
| (a) sans taxe, PV 65, Regen 1 | 99,7 % | 3,1 / 2,27 | 8,1 | 17,7 / 4,45 | 3,59 | 43,7 / 16,5 / 37,2 / 2,5 % |
| (b) taxe dès le 2e changement | 95,7 % | 4,2 / 2,41 | 11,0 | 26,8 / 5,15 | 2,69 | 39,3 / 17,2 / 39,4 / 4,0 % |
| (c) taxe dès le 3e changement | 99,3 % | 3,5 / 2,32 | 9,2 | 21,5 / 4,76 | 2,86 | 39,9 / 17,5 / 39,4 / 3,2 % |
| **retenu : (b) + PV 58 + Regen 2** | **91,0 %** | 4,5 / 2,41 | 11,7 | 28,0 / 5,20 | 2,69 | 38,2 / 16,7 / 38,2 / 6,8 % |
| essai : (b) + PV 58 + Regen 3 | 92,7 % | 4,4 / 2,41 | 11,7 | 28,5 / 5,21 | 2,71 | 37,7 / 16,5 / 37,8 / 7,9 % |
| autres classes, même réglage | 81,7 (Hunter) à 96,7 % (Warrior) | 2,0 à 6,2 / 2,16 à 3,53 | | | | |

Constats :

- **La force ne vient d'aucune carte.** Balayage `sweep=cards` (300 par ligne) au réglage (b) : aucune carte
  imposée au départ ne gagne plus de 3 points sur la ligne « (sans) » (95,7 %) : Tranquility +3,0, Demoralizing
  Roar +2,7, Rejuvenation et Healing Touch +2,3 ; **Starfall −1,0**. Le « +33 points » de Starfall du rapport de
  fin d'expédition est un biais de survie (rare de niveau 4 trouvée tard, présente dans 297 decks sur 300 : les
  3 decks sans elle sont des expéditions mortes tôt). Les cartes chères à monter (Mangle, Hurricane, Nature's
  Grace, Moonkin Aura, Gift of Nature, Rip) coûtent 5 à 6 points imposées au deck de départ. La force est celle
  du socle : changer de forme sans coût, effets de fin de tour et 65 PV.
- **PV perdus et durée** : au niveau 7, les autres classes sont aussi sous la cible de 6 à 9 PV par combat normal
  (cible posée au niveau 1) : Priest 6,2, Warrior 4,9, Rogue 3,2, Hunter 2,9, Mage 2,0 ; combats normaux de 2,16
  à 3,53 tours. Le Druid réglé (4,5 PV, 2,41 tours) est dans cette fourchette ; seules les victoires en sortaient.
- **Tree of Life** : 2,5 % des fins de tour au départ, 6,8 % avec Regen 2, 7,9 % avec Regen 3 (+1,7 point de
  victoires pour +1,1 point de fins de tour : Regen 3 non retenue). Le plafond vient des decks : le deck de
  départ n'a aucune carte Tree et le bot en prend peu (Mark of the Wild dans 222 decks sur 300, Rejuvenation 6).
  Atteindre 10 % demanderait une carte Tree au départ ou le repli Absorb du § 1.3 (règle, pas un chiffre) : à
  décider par le joueur.
- Les défaites se font surtout aux boss de Westfall (13 sur 27) et des Wetlands (5), comme pour les autres
  classes : c'est le deck de départ qui décide.

### Réglage au bot human (18/11/2026)

Au bot `human` (référence de la difficulté ressentie ; `runs=600 bot=human seed=1 jobs=8 runner=expedition key=0`,
niveau 7, ± 4 points), le réglage ci-dessus laissait le Druid dernier des classes : 37,0 % (Warrior 80,0, Mage 60,7,
Priest 53,5, Hunter 47,7, Rogue 38,5), avec 58 % de Westfall battue. Cible : 50 à 60 %. Détail :
`docs/equilibrage.md`, « Druid : réglage au bot human ».

| Réglage | Victoires (human) | Westfall battue | Changements par tour | Fins de tour Bear / Cat / Moonkin / Tree |
|---|---|---|---|---|
| 58 PV (réglage du 18/11 au bot heuristic) | 37,0 % | 58,0 % | 2,28 | 38,0 / 17,1 / 33,0 / 11,9 % |
| **retenu : 65 PV** | **51,8 %** | **71,2 %** | 2,31 | 36,9 / 17,1 / 33,4 / 12,5 % |

Les PV (58 → 65, le chiffre du joueur) suffisent ; l'entrée dans la première forme reste taxée (§ 1.6, point 7)
et le deck de départ ne change pas. Bot heuristic au même réglage : 95,7 % (300 expéditions ; plafond fixé à
97 %), 2,70 changements par tour, fins de tour 38,5 / 16,6 / 38,2 / 6,7 %.

### Compte neuf (18/11/2026)

Au bot `human` en compte neuf (`zones=0 level=1`, 600 expéditions, graine 1), le Druid gagnait 1,3 % (autres
classes 34,0 à 43,3 %) : Westfall battue 62,3 %, puis Duskwood 61,0, Wetlands 27,2 % (battue / atteinte). Cible :
32 à 42 %, sans faire sortir le niveau 7 de 48 à 60 %. Détail : `docs/equilibrage.md`, « Druid : compte neuf ».

**Cause : le pool du niveau 1, pas un bug de carte.** Cartes et bibelot de départ, formes et notes du bot sont
tous en place au niveau 1. Mais **Rebirth était la seule rare du niveau 1** : une récompense de boss (tirage
`boss = { rare = 1 }`) n'offrait qu'elle, seule carte, et les rares des élites et du marchand aussi. Le bot la
prenait 2,7 fois par expédition (1 594 choix, 3,4 exemplaires par deck qui l'a) et jouait 83 % des exemplaires
piochés : Last Breath ne sert qu'une fois par combat, chaque copie en plus est 1 mana pour rien. Le Hunter a le
même gabarit (une rare au niveau 1), mais Bestial Wrath se rejoue. Ensuite, le pool du niveau 1 manquait de
cartes à 0 mana et de contrôle (Tiger's Fury, Entangling Roots au niveau 2) et gardait Hurricane (Cast à 2 mana,
gardée en main 54 % des fois où le bot `human` la pioche, 56 % une fois Rebirth retirée).

| Répartition (niveau 1, bot `human`) | Victoires | Westfall / Duskwood / Wetlands battues (quand atteinte) | Van Cleef / Morbent Fel / Nek'rosh | Changements par tour |
|---|---|---|---|---|
| départ | 1,3 % | 62,3 / 61,0 / 27,2 % | 67,3 / 74,0 / 41,3 % | 1,90 |
| Rebirth 1 → 4, Healing Touch 4 → 1 | 19,0 % | 56,8 / 75,1 / 60,5 % | 62,8 / 84,8 / 65,1 % | 2,15 |
| + Tiger's Fury 2 → 1, Rip 1 → 2 | 26,2 % | 58,5 / 78,6 / 71,0 % | 63,7 / 88,7 / 74,8 % | 2,45 |
| **+ Entangling Roots 2 → 1, Hurricane 1 → 2 (retenu)** | **36,2 %** | **64,2 / 86,0 / 75,5 %** | 66,7 / 89,2 / 76,5 % | 2,47 |
| essai : Demoralizing Roar 6 → 1, Rip 1 → 6 (au lieu de Tiger's Fury) | 53,7 % | 74,0 / 90,5 / 87,8 % | 77,4 / 95,7 / 89,8 % | 2,23 |
| essai : Starfall 4 → 1, Starsurge 1 → 4 (sur la 3e ligne) | 19,5 % | 58,3 / 80,0 / 64,3 % | 63,8 / 87,0 / 70,6 % | 2,49 |

- Niveau 7 inchangé par construction (tout y est débloqué) : 51,8 % au bot `human`, rapport identique ; bot
  heuristic 95,7 % (300 expéditions), identique.
- **Pas de rare au niveau 1** : remettre une rare seule (Starfall) refait le piège de Rebirth (2 670 choix, 4,5 par
  deck, gardée en main 49 % des fois) ; Demoralizing Roar au niveau 1 dépasse le niveau 7 (53,7 %) : la seule
  inhabituelle de défense à 0 mana d'un petit pool s'empile (2 405 choix). Elle reste au niveau 6.
- Aucun chiffre changé ; ni les règles, ni les PV, ni la taxe.

### Absorb en Tree, Cat/Bear hors taxe (19/11/2026)

Décision du joueur après le diagnostic des voies seules (`docs/equilibrage.md`, « Druid : voies seules,
diagnostic ») : Restoration seule était la meilleure stratégie, Feral et Balance seules loin derrière. Quatre étapes,
mesurées après chacune (bot `human`, clé 0, 600 expéditions, graine 1 ; cible lue sur les trois premières zones,
qui ne bougent pas : colonne « battue » de la ligne Wetlands). Détail : `docs/equilibrage.md`, « Druid : Absorb en
Tree, Cat/Bear hors taxe ».

| Étape | Mélange, niveau 7 | Restoration | Feral | Balance | Compte neuf (`zones=0 level=1`) | Fins de tour Bear / Cat / Moonkin / Tree | Taxe (mana / tour) |
|---|---|---|---|---|---|---|---|
| départ (65 PV) | 54,3 % | 70,5 | 31,2 | 24,7 | 41,7 | 36,9 / 17,1 / 33,4 / 12,5 % | 0,92 |
| 1. Tree of Life : 3 Absorb | 48,3 | 54,8 | 31,2 | 23,5 | | 37,8 / 17,6 / 34,3 / 10,1 % | 0,92 |
| 2. + Cat ↔ Bear hors taxe | 61,3 | 64,7 | 54,0 | 33,5 | | 35,8 / 17,8 / 35,7 / 10,6 % | 0,75 |
| 3. + cartes offensives, Insect Swarm | 69,0 | 66,0 | 58,8 | 53,3 | | 35,8 / 17,2 / 36,1 / 10,7 % | 0,78 |
| 3. + Faerie Fire 3 Absorb | 73,0 | | | 60,8 | 69,0 | 40,7 / 18,2 / 32,2 / 8,9 % ¹ | 0,70 ¹ |
| **4. retenu : 59 PV, Tree 2 Absorb, Mangle +2 Frenzy** | **63,5** | **50,0** | **53,5** | **46,5** | **55,2** | 37,7 / 17,4 / 36,0 / 8,7 % | 0,78 |

Wetlands battue, en % ; ¹ série arrêtée aux Wetlands (`maxzone=wetlands`). Campagne complète au réglage retenu :
niveau 7 60,2 %, compte neuf 44,7 % ; bot heuristic (300) 96,3 %, sous le plafond de 97 %.

- **Tree of Life** (§ 1.3) : 3 Absorb coûtent 16 points à Restoration seule (la Regen de fin de tour s'empilait sur
  celle des cartes) ; 2 Absorb retenus au réglage final (Restoration −4 de plus, mélange −2,5).
- **Taxe** (§ 1.6) : Feral seule +23 points, la taxe payée par tour baisse partout (mélange 0,92 → 0,75).
- **Cartes** (§ 3) : Mangle coût 1, puis jouable à 0 avec +2 Frenzy (jouée 27 → 69 % des fois où elle est piochée
  dans le mélange) ; Leader of the Pack coût 0 (47 → 90 %) ; Nature's Grace coût 1 (27 → 53 %) ; Starfire 24,
  Starsurge 7 par Charge, Hurricane 15 à tous (52, 52, 48 → 59, 60, 54 %) ; Insect Swarm 5 Absorb et Faerie
  Fire 3 Absorb, la défense de Balance (+27 points pour Balance seule avec les dégâts).
- **PV** 65 → 59 : le niveau 7 et le compte neuf montent ensemble ; à 60 PV, compte neuf 58,2 % (au bord haut de
  sa fourchette), à 59 sans le changement de Mangle, niveau 7 59,7 % (au bord bas) : Mangle (rare, niveau 4)
  relève le niveau 7 sans toucher au niveau 1.

## 11. Questions ouvertes pour le joueur

Tranchées le 18/11/2026 et retirées : nom de la réserve hors forme (« Reserve »), seuil du levier de secours
(levier A activé le 18/11/2026 au seuil du joueur : taxe dès le deuxième changement, § 1.6), fin de tour en Cat
(Clearcasting), réserve en Tree of Life (sans lecture), PV de départ (65 ; 58 après la mesure au bot heuristic, 65
de nouveau au bot human), mots-clés (un seul pour les quatre
formes), noms de Maul et Rake (gardés), ligne « Druid » de `docs/classes/decisions.md` (réécrite). Tranchées le
19/11/2026 : Tree of Life en fin de tour (repli Absorb, ancienne question 2) et voies seules (ancienne question 4 :
Absorb en Tree, Cat ↔ Bear hors taxe, cartes relevées, PV 59 ; § 10).

1. **Cartes sans forme** : Skull Bash, Nature's Swiftness et tous les Powers. Faut-il des Powers de forme (jouer
   Moonkin Aura ferait entrer en Moonkin) ?
2. **Furor** (épique de Westfall, § 5) était notée « incompatible avec le levier A », désormais actif : la garder
   (elle rend de la réserve à chaque changement, la taxe retire du mana) ou la revoir ? Depuis le 19/11/2026, un
   passage Cat ↔ Bear lui donne sa réserve sans coûter de mana.
3. **Deck de départ sur deux formes** (levier (3) du 18/11/2026, jamais essayé) : chaque voie y paie encore la
   taxe des allers-retours Moonkin ↔ Bear du départ (Balance seule 0,62 mana par tour, § 1.6, point 8).
