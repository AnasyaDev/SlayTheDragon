# Décisions sur les zones et les cartes épiques

Elles priment sur les fiches de `docs/zones/` quand une fiche dit autre chose. Pour toute question ouverte d'une
fiche qui n'est pas tranchée ici, on prend la version que la fiche propose.

## Tranché par le joueur (13/11/2026)
- **Sept zones** : Westfall, Duskwood, Wetlands, Stranglethorn Vale, Swamp of Sorrows, Burning Steppes, Blackrock
  Mountain. La Ligue est supprimée. Clés par zone et par classe, +15 % d'expérience par niveau, pas de cote.
- **Cartes de zone = cartes épiques.** Une par classe et par zone, débloquée par la première victoire de la classe
  dans la zone.
- **Une seule épique par expédition.** Le deck ne peut contenir qu'une carte épique : en prendre une autre remplace
  la précédente. Une épique au moins est proposée à coup sûr dans chaque expédition (parmi celles que la classe a
  débloquées).
- **Une épique PILOTE le build.** Ce n'est ni une réponse à une zone ni une bonne carte de plus : elle change les
  règles de la classe pour l'expédition et fait naître un deck complètement différent. Exemple donné par le joueur
  (Rogue) : une carte où chaque Parry devient une riposte qui inflige X dégâts, X selon le nombre de ripostes déjà
  faites dans le tour. Comme on n'en a qu'une, une épique n'a pas besoin de bien se combiner avec les autres épiques.
- **Lone Wolf (Hunter)** : le familier s'en va et les cartes de familier se TRANSFORMENT en cartes nouvelles propres
  à ce mode (Kill Command devient un tir avec un petit effet en plus, etc.).
- **Trap Launcher (Hunter)** : toujours actif (les Traps partent tout de suite sur un ennemi choisi) et il AJOUTE des
  effets aux Traps.
- **Refusées** parce qu'elles ne pilotent pas un deck : Power Infusion (Priest), Defensive Stance (Warrior). Par
  extension, toute carte du même genre (pioche, mana, soin, dégâts en plus) est à remplacer.
- **Swamp of Sorrows** : la mécanique « Afflictions » est abandonnée (trop proche de Curse) ; remplacée par Slumber.
- **Westfall** : décor peint couleur blé, Defias Highwayman, personnages et noms de Westfall.
- **Équilibrage** : le Rogue est la référence ; 6 à 9 PV perdus par combat normal pour toutes les classes.

## Tranché par le concepteur pendant la nuit du 13 au 14/11/2026 (à revoir par le joueur)
- **Commun** : les anciens paliers 1, 2, 3 restent sur les zones 1, 2, 3 ; chaque zone y ajoute le commun de sa fiche.
- **Westfall** : Captain Sander's Treasure Map est gardée (4 cartes en récompense au lieu de 3).
- **Duskwood** : boss Morbent Fel, Stitches en élite ; tuer le lanceur retire ses malédictions ; la morsure du Vile
  Fang fait 9 ; les malédictions peuvent tuer ; « Remove negative effects. » retire celles de la main.
- **Wetlands** : la mort du Pack Leader disperse la meute SANS poser Demoralized (l'ordre des morts reste un choix) ;
  des morts simultanées ne donnent aucun bonus ; Modr est gardé ; l'armure de Ma'ruk Wyrmscale va au Dragonmaw
  Centurion (créature réelle trouvée) ; Cursed Eye of Paleth : soins hors combat divisés par deux.
- **Stranglethorn Vale** : Hex seul, pas d'Ambush ; boss Jin'do the Hexxer ; un Hex sur une main vide ne fait rien ;
  la carte Hexed coûte 1.
- **Swamp of Sorrows** : pas de plafond au bonus de réveil (on règle par les PV des dormeurs) ; le familier évite les
  dormeurs tant qu'un ennemi est éveillé ; Asleep 2 par défaut ; Dream Dust sans effet sur les élites et les boss ;
  les orcs de Stonard restent alliés.
- **Burning Steppes** : la brûlure monte de 2 par tour ; une mort retarde le feu d'un tour ; boss Grark Lorkrub ;
  Volchan n'a que « Wildfire 2 » (pas de soin par la brûlure).
- **Blackrock Mountain** : seuil des ennemis normaux à 50 % ; le boss ne peut pas sauter une phase (les dégâts
  au-delà d'un seuil de Nefarian sont perdus pour ce coup) ; autant de Bone Constructs que de drakônides tués ; Class
  Call : un état par classe ; « Dragonslayer » à la première victoire contre Nefarian avec la classe, le niveau 7
  donne « Veteran » ; Rallying Cry accepté.

## Cartes épiques : tranché par le concepteur (nuit du 13 au 14/11/2026, à revoir par le joueur)
La liste et les règles sont dans `docs/zones/cartes-de-zone.md` (version « épiques qui pilotent le build »).
- **Arrivée en jeu** : une épique est une règle active dès le début de chaque combat (posée comme un Power avant
  le premier tour, plaque « Epic », sans coût, jamais piochée ni jouée ; ni Hex ni Curse ne la touchent).
- **Offre** : à l'étape 1 de l'expédition, un choix parmi 3 épiques débloquées (ou « Skip ») ; chaque élite gagnée
  propose une épique de remplacement ; le marchand en vend une à 150 po. Remplace l'offre « première élite ».
- **Amélioration** : une épique peut être améliorée au feu de camp ; l'amélioration est perdue si on la remplace.
- **Riposte du Rogue** : l'épique s'appelle Deflection (« Riposte » est déjà une carte commune) ; chaque Parry
  GAGNÉ riposte (3, +3 par riposte précédente du tour), la charge de Parry reste pour parer.
- **Death Wish** reste la première épique du Warrior (Westfall).

## Difficulté et épiques (décision du joueur, 14/11/2026)
- **La difficulté croît de zone en zone**, réglée pour un deck fourni en rares et portant son épique. Un deck
  pauvre (peu de rares, pas d'épique) perd nettement plus souvent dans les zones 5 à 7 : c'est voulu, l'écart
  « sans épique » n'est pas une cible.
- **Le gain d'une épique n'est pas plafonné** (+22 dans une zone tardive est acceptable). La contrainte est la
  parité : dans une même zone, les cinq classes gagnent à peu près autant avec leur épique (écart de taux de
  victoire ≤ 10 points, épique en jeu).
- **L'épique se gagne, elle n'est plus donnée à l'étape 1** (joueur, 14/11/2026). Elle peut tomber sur un élite
  ou apparaître chez le marchand. Chance par élite proposée par le concepteur, à régler : 25 % à Westfall,
  +10 points par zone, 85 % à Blackrock Mountain. La part de rares dans les récompenses de cartes monte aussi
  de zone en zone.
- **PV perdus par combat normal : selon la classe, plus de cible uniforme** (joueur, 14/11/2026 ; remplace
  « 6 à 9 PV pour tous »). Le Priest ne prend presque rien, le Warrior encaisse. Cibles du concepteur, en part
  des PV max : Priest ≤ 10 %, Rogue ≈ 13 % (référence), Warrior jusqu'à 15 %, Mage et Hunter entre les deux.
- **Courbe de difficulté** (concepteur, à valider) : taux de victoire du bot de référence, clé 0, d'environ
  80 % à Westfall à environ 50 % à Blackrock Mountain, en descendant à chaque zone.
