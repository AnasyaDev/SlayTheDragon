# Priest — progression par niveau de classe

Applique au Priest existant (34 cartes, `Data/Priest.lua`) la table « Progression par classe » du GDD
des classes : niveau 1 = 4 cartes de départ + 6 par voie et 2 bibelots de classe ; niveaux 2, 4, 6 :
une carte par voie ; niveau 7 : une rare par voie et 2 bibelots ; niveaux 3 et 5 : un bibelot.
Aucun chiffre de carte ne change ici.

**Appliqué le 12/11/2026** (`Data/Priest.lua` : champ `level`, six bibelots, Sacred Candle en bibelot de
départ ; mesures : `docs/expedition.md`, « Niveau de classe »). Écart à cette fiche : le texte de
Benediction devient « Each Regen gained: +1. » (pas de « you » dans les textes).

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

## Paliers +2 et +3 (15/11/2026)

Décision du joueur du 15/11/2026 (`docs/ameliorations.md`) : chaque carte s'améliore jusqu'à trois fois, chaque
palier écrit à la main. Les 41 cartes du Priest (34 cartes, 7 épiques) ont leurs paliers 2 et 3
(`Data/Priest.lua`, champs `up2` / `up3` ; épiques : tables `{ base, +1, +2, +3 }` de `Core/Classes/priest.lua`
lues par `Priest.tier(t, src)` = `t[Card.level(src) + 1]`). Paliers 0 et 1 inchangés.

Fil conducteur : **le Priest perd déjà très peu de PV** ; ses soins et boucliers ne grimpent donc presque plus
après le +1 (au plus + 2 sur un nombre, jamais un deuxième doublement). Ses paliers 2 et 3 vont d'abord au
tempo (coût, Retain, Innate, pioche), à l'Atonement (durée, effets conditionnels) et à l'Insanity.

| Carte | +1 (inchangé) | +2 | +3 |
|---|---|---|---|
| Smite | Deal 11 | Deal 13 | Atonement : 4 de plus |
| Inner Fire | 9 Absorb | 11 Absorb | Atonement : pioche 1 |
| PW: Shield | 11 Absorb | 13 Absorb | gagne Atonement 1 |
| SW: Pain | DoT 7 | DoT 9 | +2 Insanity |
| PW: Radiance | 6 Absorb, Atonement 2 | Atonement 3 | pioche 1 |
| Penance | 7 × 3 | 8 × 3 | Atonement : 3 Absorb par coup |
| Pain Suppression | Cooldown 4 | Retain | pioche 1 |
| PW: Solace | Deal 6 | Atonement 2 | Deal 8 |
| Angelic Feather | 4 Absorb | gagne Atonement 1 | 5 Absorb |
| Luminous Barrier | 18 Absorb | Atonement 2 | pioche 1 |
| Schism | Deal 6, Sundered 3 | Deal 8 | Atonement 2 |
| Shadow Mend | Heal 16 | +2 Insanity | plus de DoT sur soi |
| Evangelism | coût 0 | Atonement 3 | Retain |
| Rapture | +3 par gain d'Absorb | coût 0 | Innate |
| Mind Flay | Deal 11 | Deal 13 | DoT : +3 Insanity |
| Mind Blast | Deal 13 | +3 Insanity | Deal 16 |
| Devouring Plague | DoT 3 par Insanity | Retain | DoT 4 fixe en plus |
| Shadowform | +4 aux coups et DoT Shadow | +3 Insanity à la pose | coût 0 |
| Silence | Cooldown 1 | Retain | +1 Insanity |
| Vampiric Touch | DoT 5, Regen 2 | +2 Insanity | DoT 7 |
| Mind Sear | DoT 7 à tous | DoT 9 à tous | +2 Insanity |
| SW: Death | Deal 9 / Execute 18 | Deal 10 / Execute 20 | +2 Insanity |
| Psychic Scream | coût 0 | Demoralized 3 | +2 Insanity |
| Void Eruption | 6 + 6 par Insanity | 9 + 6 par Insanity | Retain |
| Holy Fire | Deal 31, DoT 4 | Deal 36 | DoT 6 |
| Holy Nova | Deal 5 à tous, Regen 3 | Deal 7 à tous | pioche 1 |
| Holy Word: Chastise | Deal 10, Cooldown 2 | Deal 13 | Retain |
| Greater Heal | Heal 13 | coût 0 | Heal 15 |
| Spirit of Redemption | coût 0 | Innate | pioche 2 au Last Breath |
| Renew | Regen 5 | coût 0 | Innate |
| Halo | Deal 26 à tous, Regen 4 | Deal 29 à tous | Sundered 2 à tous |
| Flash Heal | Heal 10 | pioche 2 | Heal 12 |
| Empyreal Blaze | Deal 44 | Deal 49 | Sundered 3 |
| Apotheosis | coût 1 | pioche 1 à la pose | Innate |
| Prayer of Mending (épique) | Divine Star +2 | +3 | +4 |
| Misery (épique) | Contagion +1 | +2 | +3 |
| Echo of Light (épique) | Sanctify +2 | +3 | +4 |
| Shadow Covenant (épique) | 1re carte Shadow du tour gratuite | Life Tap 1 (1 PV par mana) | 2 cartes Shadow gratuites par tour |
| Reflective Shield (épique) | renvoie la moitié | trois cinquièmes | deux tiers |
| Voidform (épique) | Madness 2 | + 2 fixes par coup Shadow | + 4 fixes |
| Inner Focus (épique) | Empower 100 % | 125 % | 150 % |

Épiques : leur texte tient en une clause (deux lignes au plus, harnais UEL, désormais vérifié à chaque palier
écrit) ; une deuxième clause (« Start of combat: +1 Insanity. », « It can't be interrupted. ») passait à quatre
lignes, d'où des paliers chiffrés. Mot de règle Life Tap amélioré : « The first ones each turn are free, as
stated. » (le nombre de cartes gratuites est sur la carte). Inner Focus : mot Empower lu « +N % » à tous les
paliers (plus « doubled »).

Bots : notes d'amélioration par défaut (× 0,8 puis × 0,6). Une table par palier pour les paliers « Retain »
changerait la note du palier 1 sous les épiques dont la table `byEpic.rating` diffère de la note de classe
(Pain Suppression, Evangelism, Devouring Plague, Void Eruption) : non posée. `Bots.POWER_VALUE` inchangé (les
paliers des Powers ne changent que coût, Innate ou effet de pose).
