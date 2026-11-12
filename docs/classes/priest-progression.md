# Priest — progression par niveau de classe

Applique au Priest existant (34 cartes, `Data/Priest.lua`) la table « Progression par classe » du GDD
des classes : niveau 1 = 4 cartes de départ + 6 par voie et 2 bibelots de classe ; niveaux 2, 4, 6 :
une carte par voie ; niveau 7 : une rare par voie et 2 bibelots ; niveaux 3 et 5 : un bibelot.
Aucun chiffre de carte ne change ici.

## Point de départ

Aujourd'hui, le champ `rep` des cartes suit la réputation de classe (0 Neutre, 1 Amical, 2 Honoré) :
20 cartes à 0, 5 à 1 (Shadow Mend, Evangelism, Mind Sear, SW: Death, Flash Heal), 5 à 2 (Rapture,
Psychic Scream, Void Eruption, Empyreal Blaze, Apotheosis). Ces 10 cartes sont reprises telles
quelles dans les 12 déblocages ; il en faut deux de plus, une en Discipline et une en Holy
(Shadow a déjà ses 4).

Répartition par voie : Discipline 5 communes, 3 inhabituelles, 2 rares ; Shadow 4/4/2 ; Holy 4/4/2.
Chaque voie a deux rares : une reste au niveau 1, l'autre passe au niveau 7.

## 1. Les 12 cartes débloquées

| Niveau | Discipline | Shadow | Holy |
| --- | --- | --- | --- |
| 2 | Evangelism | Mind Sear | Flash Heal |
| 4 | Luminous Barrier | SW: Death | Halo |
| 6 | Shadow Mend | Psychic Scream | Empyreal Blaze |
| 7 (rare) | Rapture | Void Eruption | Apotheosis |

Justifications (une ligne chacune) :

- **Evangelism (2)** : ouvre la « fenêtre d'Atonement » en un coup (pioche 2, Atonement 2) ; la
  voie tourne déjà sans elle grâce à Radiance et Solace.
- **Luminous Barrier (4)** : seule carte Discipline à 2 mana et la plus faible mesurée (−2,0) ; son
  retrait rend le niveau 1 plus fluide, son arrivée ouvre le gros tour défensif.
- **Shadow Mend (6)** : le pont Discipline → Shadow (soin contre Insanity et DoT sur soi) ; c'est une
  carte de croisement, pas de base.
- **Rapture (7)** : moteur « tout Absorb » qui change le deck entier ; rare d'ensemble.
- **Mind Sear (2)** : le DoT de zone, première vraie réponse aux combats à 3-4 ennemis (murlocs).
- **SW: Death (4)** : la finition Execute ; utile mais pas nécessaire à la voie (−3,0).
- **Psychic Scream (6)** : contrôle de zone fort (+5,6) ; il arrive quand le joueur a appris à lire
  les intentions.
- **Void Eruption (7)** : le second Surge, celui des dégâts directs ; Devouring Plague montre le
  Surge dès le niveau 1.
- **Flash Heal (2)** : soin direct avec pioche, la première carte de soin « pure » après Renew et
  Greater Heal.
- **Halo (4)** : Cast de zone à 2 mana (la carte la moins jouée, 41 %) ; il élargit le Holy aux
  combats multiples quand Holy Fire est déjà maîtrisé.
- **Empyreal Blaze (6)** : le plus gros Cast du jeu ; il demande de savoir protéger un Cast des
  interruptions.
- **Apotheosis (7)** : moteur « Cast moins chers + 1 mana » qui transforme la voie ; rare d'ensemble.

### Le Priest de niveau 1 (22 cartes)

| Voie | 6 cartes de niveau 1 | Ce qu'elles montrent |
| --- | --- | --- |
| Discipline | PW: Radiance, PW: Solace, Angelic Feather, Penance, Schism, Pain Suppression (rare) | Atonement posé (Radiance, Solace, Schism), payé (Penance), défense d'urgence |
| Shadow | Mind Flay, Mind Blast, Vampiric Touch, Devouring Plague, Silence, Shadowform (rare) | DoT, Insanity, un Surge, l'Interrupt, le Power d'ombre |
| Holy | Holy Fire, Holy Nova, Renew, Holy Word: Chastise, Greater Heal, Spirit of Redemption (rare) | deux Cast, Regen, contrôle, Last Breath |

- **Peut gagner** : l'Interrupt (Silence) et le Last Breath (Spirit of Redemption) sont là ; les
  cartes les mieux mesurées restent au niveau 1 (Vampiric Touch +7,4, Shadowform +6,5, Holy Fire
  +5,3, Angelic Feather +5,1, Solace +12,7 depuis la règle d'Atonement).
- **Chaque voie jouable seule** : Discipline a trois sources d'Atonement et son paiement (Penance) ;
  Shadow monte l'Insanity et la dépense (Devouring Plague) ; Holy a deux Cast, Regen et soin.
- **Raretés au niveau 1** : 9 communes, 6 inhabituelles, 3 rares. Les récompenses de combat
  (60/33/7) tirent donc surtout dans une réserve resserrée : un même deck verra plus souvent les
  mêmes cartes.

## 2. Bibelots de classe du Priest (6)

Aucun des 12 bibelots actuels ne suppose le Priest : aucun ne parle d'Insanity, d'Atonement, de
Surge ou de Regen (classement complet : `docs/bibelots-communs.md`). Talisman of Focus (Cast) et
Tobin's Pocketknife (DoT) servent surtout le Priest aujourd'hui, mais le Cast et le DoT sont des
mécaniques communes : ils restent communs. Les six bibelots du Priest sont donc nouveaux.

| Id | Nom | Rareté | Effet | Icône | Niveau |
| --- | --- | --- | --- | --- | --- |
| `sacred_candle` | Sacred Candle | départ | `At the start of each combat, gain Atonement 1 ⌛.` | `inv_misc_candle_02` | 1 (porté au départ) |
| `mindtap_talisman` | Mindtap Talisman | common | `At the start of each combat, +2 Insanity.` | `inv_jewelry_talisman_04` | 1 |
| `benediction` | Benediction | uncommon | `Each Regen you gain is 1 higher.` | `inv_staff_30` | 3 |
| `robes_of_prophecy` | Robes of Prophecy | uncommon | `Atonement: each Absorb gain +2.` | `inv_chest_cloth_03` | 5 |
| `anathema` | Anathema | rare | `Surge cards count 2 more Insanity.` | `inv_staff_29` | 7 |
| `truefaith_vestments` | Truefaith Vestments | rare | `When a Cast card resolves, gain 4 Absorb.` | `inv_chest_cloth_11` | 7 |

- Sacred Candle amorce la mécanique propre (Atonement) dès le premier tour, comme le gabarit le
  demande : avec la règle actuelle, Atonement 1 posé au premier tour couvre ce tour et le suivant.
- Un bibelot par moteur : Atonement (Candle, Robes), Insanity (Talisman, Anathema), Regen (Benediction),
  Cast (Vestments).
- Fonctionnement voulu : le bibelot de départ est porté à chaque expédition (comme dans Slay the
  Spire) ; les cinq autres entrent dans la réserve de bibelots de **cette classe** (récompenses,
  coffres, marchand) une fois leur niveau atteint. Cela remplace le choix d'un bibelot de classe parmi
  trois au palier Révéré (`docs/expedition.md`, phase `start`).

## 3. Risque pour l'équilibrage actuel

Référence : ≈ 79 % de victoires (bot heuristique, clé 0, `runner=expedition`) avec les 34 cartes et
la Ligue complète (`docs/equilibrage.md`, compensation d'Atonement : 78,8 %).

- **Ce qui baisse** : le niveau 1 perd Mind Sear (+5,9) et Psychic Scream (+5,6), deux des cartes les
  mieux mesurées, et Evangelism, Flash Heal, Halo, Empyreal Blaze. La mesure ancienne « cartes
  Neutre seulement » (`rep=0 tier=0`, 20 cartes) donnait 75,5 % contre 75,3 % tout débloqué : la perte
  devrait rester de quelques points, puisque les 12 cartes retirées sont surtout des cartes
  d'appoint.
- **Ce qui monte** : Sacred Candle (Atonement au premier tour) est porté à chaque expédition. Solace
  profite déjà le plus d'Atonement (+12,7) : le bibelot peut rendre le Priest de niveau 1 plus fort
  que le Priest complet d'aujourd'hui.
- **Ce qui change de nature** : la réserve des récompenses passe de 30 à 18 cartes au niveau 1, puis
  21, 24, 27, 30. Moins de cartes = plus de doublons des meilleures communes (Solace, Vampiric Touch).
- **Bibelots communs** : la réserve de bibelots passe de 12 à une trentaine (`docs/bibelots-communs.md`),
  ce qui dilue Stormwind Tabard (+28,1) et Mana Ruby (+26,1).

À remesurer (2 000 à 3 000 expéditions, graine 1, clés 0 à 5) :

1. Priest niveau 1, sans puis avec Sacred Candle, et Priest niveau 7 : victoires, PV perdus contre
   le boss. Cible : niveau 1 entre 65 et 80 % à la clé 0, niveau 7 au moins aussi bon qu'aujourd'hui.
2. Chaque niveau (1 à 7) : la courbe doit monter sans saut de plus de 5 points d'un niveau au
   suivant.
3. Decks forcés par voie au niveau 1 (Discipline, Shadow, Holy seuls) : chaque voie doit gagner.
4. Balayage des six bibelots du Priest (`sweep=relics loot=0`) : Sacred Candle et Mindtap Talisman en
   priorité, Robes of Prophecy (Atonement + Absorb, cumulatif avec Rapture).
5. Recaler `Meta.AFFIX` si la victoire à la clé 0 bouge de plus de 3 points (les affixes visent
   ≈ −5 points par niveau de clé).

## Changements de données à prévoir (pour l'implémentation)

- Cartes : remplacer `rep` (0..2) par `level` (1..7, absent = 1) ; `X.cardPool` filtre sur le niveau
  de classe.
- Méta : niveau de classe 1..7 tiré de l'expérience de classe (aujourd'hui `cs.rep`) ; seuils à fixer
  (proposition : 100 / 250 / 450 / 700 / 1 000 / 1 400 points, soit le niveau 7 vers la 12e
  expédition à ≈ 115 points chacune). Le palier Exalté et son titre restent à rattacher (niveau 7 ou
  seuil à part).
- Bibelots : `class = "priest"` + `level` ; `starter = true` pour Sacred Candle (donné au départ, jamais
  tiré) ; `X.relicPool` inclut les bibelots de la classe jouée de niveau atteint.
- Écran de progression (GDD) : 34 cartes par voie et 6 bibelots, verrouillés = icône grisée et
  infobulle « Priest level N ».
