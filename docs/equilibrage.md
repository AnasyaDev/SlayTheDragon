# Équilibrage de l'acte 1 (piste A)

Contenu de combat du Prêtre et de la Marche de l'Ouest, réglé par simulation
(`Sim/sim.lua`, runner linéaire `Sim/run.lua` : facile, facile, normal, feu de camp, élite,
normal, feu de camp, VanCleef). Tous les chiffres viennent de séries à graines fixes
(graine 1). Rapports bruts dans `reports/` (non versionnés).

## Méthode et outils

- **Série de référence** : `luajit Sim/sim.lua runs=2000 bot=heuristic jobs=8 save=... compare=...`.
- **Effet d'une carte** : deux mesures complémentaires.
  - `pick=random` : colonne « écart » = victoires avec la carte − sans, dans une même série.
    Bruit : environ ± 5 points pour une commune (≈ 400 decks), ± 6 pour une peu commune,
    ± 9 pour une rare (≈ 120 decks).
  - `sweep=cards [only=a,b]` : chaque carte ajoutée de force au deck de départ, contre la même
    série sans elle (mêmes graines). Plus précis mais surévalue ce qui aide un deck faible
    (soins) et sous-évalue les cartes à construire (pouvoirs d'ombre, incantations).
  - `build/probe.lua` (outil jetable) compare graine par graine avec/sans une carte ; c'est lui
    qui a révélé le défaut du bot face aux sbires de VanCleef.
- **Bibelots** : `sweep=relics loot=0` (un bibelot au départ, aucun autre butin).
- **Poids des interruptions** : `nointerrupt=1` (monde témoin où les ennemis ne coupent jamais).
- **Réputation / Ligue** : `rep=0..2`, `tier=0..3` ; par défaut tout est débloqué (Exalté).
- **Butin du runner** : bibelot tiré (palier `tier`) après l'élite ; 40 % de chance de potion
  après chaque combat gagné hors boss si un emplacement est libre (flux `treasure` séparé :
  les choix de cartes ne changent pas avec ou sans butin). Le bot boit librement ses
  potions au dernier combat (valeur de conservation nulle).

## Résultats : avant / après

| Mesure | Avant (contenu d'origine) | Après | Cible |
|---|---|---|---|
| heuristic, pick=rated | 78,0 % | **75,3 %** | 65–80 % |
| heuristic, pick=random | 83,8 % | **66,6 %** | — |
| greedy | 36,5 % | 14,6 % (1 000 exp.) | — |
| random | 1,4 % | **0,0 %** (1 000 exp.) | < 5 % |
| heuristic rated, cartes Neutre + Ligue palier 0 (`rep=0 tier=0`) | — | 75,5 % (1 000 exp.) | gagnable |
| Combat facile : tours / PV perdus | 2,46 / 1,7 | 3,16 / 4,5 | — |
| Combat normal : tours / PV perdus | 3,10 / 4,7 | **4,46 / 15,4** | 4–6 tours, PV non négligeables |
| Élite : tours / PV perdus | 3,76 / 3,4 | **5,94 / 20,0** | nettement > normal |
| Boss : victoires / tours / PV perdus | 78 % / 9,17 / 45,1 | 76 % / **6,90** / 51,6 | ≤ 8 tours |

Les défaites restent concentrées sur VanCleef (468 sur 494) ; l'élite tue rarement (< 1 %)
mais coûte 20 PV en moyenne, soit 30 % des PV de départ, et pèse donc sur le boss.

### Par rencontre (heuristic, pick=rated, 2 000 expéditions)

| Rencontre | Type | Victoires | Tours (p95) | PV perdus |
|---|---|---|---|---|
| Bandit | facile | 100 % | 2,6 (3) | 0,5 |
| 2 gnolls | facile | 100 % | 4,2 (5) | 8,0 |
| 3 murlocs | facile | 100 % | 3,1 (4) | 3,5 |
| Sorcier + murloc | facile | 100 % | 2,7 (4) | 5,8 |
| Bandit + gnoll | normal | 99,9 % | 4,2 (6) | 7,9 |
| Bandit + sorcier | normal | 99,8 % | 4,1 (6) | 11,5 |
| 2 gnolls + mystique | normal | 99,1 % | 5,1 (7) | 18,9 |
| Gnoll + sorcier + mystique | normal | 98,2 % | 5,0 (7) | 26,8 |
| 4 murlocs | normal | 100 % | 3,9 (6) | 11,7 |
| Golem moissonneur | élite | 99,9 % | 5,8 (8) | 22,8 |
| Rhahk'Zor | élite | 100 % | 6,1 (8) | 17,3 |
| Edwin VanCleef | boss | 76,3 % | 6,9 (10) | 51,6 |

### Ennemis finaux

| Ennemi | PV | Intentions |
|---|---|---|
| Gnoll Rivepatte | 19–22 | Morsure 8 ; Lacération 5 + Armure fracassée 1 |
| Mystique Rivepatte | 15–17 | Guette si tu as une incantation en main (coupe, sinon 3 dégâts) ; Soins 6 ; Horion 5 |
| Murloc côtier | 10–12 | Griffe 4 ; +1 Force à la mort d'un murloc |
| Bandit défias | 25–28 | Coup de pied 5 **(interrompt)** ; Garde 8 ; Rafale 5 × 2 |
| Sorcier défias | 18–21 | Boule de feu 16 (incante) ; Éclats de givre 4 **(interrompt)** |
| Golem moissonneur | 72 | Blindage 12 ; Écrasement 19 **(interrompt)** ; Moisson 8 × 3 |
| Rhahk'Zor | 75 | Rugissement 7 + Démoralisé 2 ; Fracas 18 **(interrompt)** ; Coup de poing 12 |
| Edwin VanCleef | 92 | Enchaînement 11 × 2 + Armure fracassée ; Coup de pied 9 **(interrompt)** ; Frappe mortelle 23 ; Parade 12 Absorption + Force 3 ; 2 sbires à 50 % |
| Sbire défias | 11–13 | Coup de dague 5 |

## Interruptions : le choix « incanter ou pas »

Nouvelle règle moteur : une attaque marquée `interrupts = true` coupe ton incantation **si
elle te fait perdre des PV** (l'Absorption protège donc le sort). « Guette » coupe à coup sûr.

Le bot voit les intentions et simule le tour ennemi : il ne se fait presque jamais couper
(2 % des incantations), comme un joueur attentif. Le poids des interruptions se lit donc
dans ses décisions et dans le monde témoin `nointerrupt=1` :

| Mesure (finale) | Valeur |
|---|---|
| Incante quand une incantation est jouable et qu'aucune menace n'est annoncée | 74,7 % |
| … sous la menace d'un coup qui interrompt (en se protégeant ou en tuant le cogneur) | 31,6 % |
| … quand le Mystique guette (il faut le tuer ou l'étourdir avant) | 16,7 % |
| Victoires pick=random avec / sans interruptions | 64,5 % / 67,8 % (3,3 points) |
| Deck forcé Flammes sacrées + Halo + Soins supérieurs, avec / sans interruptions | 75,1 % / 88,7 % (13,6 points) |

Le choix n'est trivial dans aucun sens : sous menace le bot incante encore une fois sur trois
quand l'Absorption couvre le coup, et un deck Sacré perd 14 points à cause des interruptions,
compensés par des incantations plus fortes que les cartes immédiates.

## Cartes (30 hors départ)

Répartition : Discipline 10, Ombre 10, Sacré 10 ; 13 communes, 11 peu communes, 6 rares.
Réputation de classe (`rep`) : 20 cartes au palier 0 (Neutre), 5 au palier 1 (Amical),
5 au palier 2 (Honoré). Le GDD demandait « environ 14 » nouvelles cartes pour arriver à
≈ 30, mais aussi 20 + 5 + 5 cartes débloquables : j'ai suivi le second chiffre (17 nouvelles
cartes, 34 au total avec les 4 de départ).

Écart final = victoires avec − sans la carte, heuristic pick=random, 2 000 expéditions.

| Carte | Voie | Rareté | rep | Coût | Effet (version de base) | Écart | Jouée / piochée |
|---|---|---|---|---|---|---|---|
| Mot de pouvoir : Radiance | Disc. | commune | 0 | 1 | Expiation 2, 4 Absorption | +1,2 | 65 % |
| Mot de pouvoir : Réconfort | Disc. | commune | 0 | 1 | Inflige 5 ; sous Expiation +1 mana ; Expiation 1 | +3,6 | 83 % |
| Plume angélique | Disc. | commune | 0 | 0 | 2 Absorption, pioche 1, Recharge 2 | +5,1 | 95 % |
| Barrière lumineuse | Disc. | commune | 0 | 2 | 12 Absorption, Expiation 1, Recharge 2 | −2,0 | 65 % |
| Guérison de l'ombre | Disc. | commune | 1 | 1 | Soigne 10, Douleur 2 sur soi, +1 Démence, Consumée | −2,5 | 75 % |
| Pénitence | Disc. | peu commune | 0 | 2 | 6 × 3 ; sous Expiation 2 Absorption par coup | +2,6 | 53 % |
| Schisme | Disc. | peu commune | 0 | 1 | Inflige 3, Armure fracassée 2, Expiation 1 | −0,8 | 77 % |
| Évangélisme | Disc. | peu commune | 1 | 1 | Expiation 3, pioche 2, Consumée | −1,0 | 55 % |
| Suppression de la douleur | Disc. | rare | 0 | 1 | Dégâts subis ÷ 2 jusqu'au prochain tour, Recharge 4 | +0,7 | 72 % |
| Extase | Disc. | rare | 2 | 1 | Pouvoir : +1 à chaque gain d'Absorption | −3,7 | 96 % |
| Fouet mental | Ombre | commune | 0 | 1 | Inflige 8 ; si Douleur : +2 Démence et pioche 1 | +1,5 | 68 % |
| Attaque mentale | Ombre | commune | 0 | 1 | Inflige 10, +2 Démence, Recharge 1 | −0,8 | 72 % |
| Toucher vampirique | Ombre | commune | 0 | 1 | Douleur 3, Récupération 1, +1 Démence | +7,4 | 69 % |
| Incandescence mentale | Ombre | commune | 1 | 1 | Douleur 4 à tous, +1 Démence | +5,9 | 76 % |
| Peste dévorante | Ombre | peu commune | 0 | 0 | Dépense la Démence : Douleur × 2 | +2,0 | 59 % |
| Silence | Ombre | peu commune | 0 | 0 | Interrompt, pioche 1, Recharge 2 | +0,9 | 89 % |
| Mot de l'ombre : Mort | Ombre | peu commune | 1 | 1 | Inflige 6 (12 sous la moitié des PV), +1 Démence | −3,0 | 62 % |
| Cri psychique | Ombre | peu commune | 2 | 1 | Ennemis Démoralisés 2 tours, +1 Démence, Recharge 3 | +5,6 | 74 % |
| Forme d'ombre | Ombre | rare | 0 | 1 | Pouvoir : +2 Démence ; ombre +3 dégâts et +3 Douleur | +6,5 | 68 % |
| Éruption du Vide | Ombre | rare | 2 | 1 | Dépense la Démence : 4 + 4 par point | −3,6 | 46 % |
| Flammes sacrées | Sacré | commune | 0 | 2 | Incantation : 24 et Douleur 3 | +5,3 | 46 % |
| Nova sacrée | Sacré | commune | 0 | 1 | 4 à tous, Récupération 2 | +0,6 | 67 % |
| Rénovation | Sacré | commune | 0 | 1 | Récupération 3, Consumée | −6,7 | 50 % |
| Soins rapides | Sacré | commune | 1 | 1 | Soigne 7, pioche 1, Consumée | −1,1 | 87 % |
| Mot sacré : Châtier | Sacré | peu commune | 0 | 1 | Inflige 7, Étourdi 1, Recharge 3 | −2,1 | 77 % |
| Soins supérieurs | Sacré | peu commune | 0 | 1 | Incantation : soigne 12, Consumée | +3,2 | 65 % |
| Halo | Sacré | peu commune | 0 | 2 | Incantation : 15 à tous, Récupération 3 | −4,1 | 41 % |
| Embrasement empyréen | Sacré | peu commune | 2 | 2 | Incantation : 28, Armure fracassée 2 | −2,1 | 46 % |
| Esprit de rédemption | Sacré | rare | 0 | 1 | Pouvoir : à 0 PV, reste à 1, Récupération 6, tour gratuit | −2,5 | 80 % |
| Apothéose | Sacré | rare | 2 | 2 | Pouvoir : +1 mana par tour, incantations −1 | +1,8 | 66 % |

Écarts encore hors de ± 5 : Toucher vampirique (+7,4), Rénovation (−6,7), Forme d'ombre
(+6,5, rare : bruit ± 9), Incandescence mentale (+5,9), Cri psychique (+5,6),
Flammes sacrées (+5,3), Plume (+5,1). Tous restent dans l'intervalle de bruit ou juste au bord.
Aucune carte morte : la moins jouée est Halo (41 % des pioches, incantation à 2 mana).

### Pourquoi ces changements (dans l'ordre des itérations)

1. **Forme d'ombre** (−43 points) : « plus de cartes sacrées » bloquait un deck de départ
   presque tout sacré. Un surcoût d'1 mana a laissé la carte morte (0,5 % jouée). Elle ne fait
   plus que renforcer l'ombre (+3, +2 Démence, coût 1).
2. **Pouvoirs trop chers** (Esprit de rédemption joué 4 %, Apothéose, Extase) : coûts baissés,
   et le bot évalue maintenant chaque pouvoir selon le deck (`Bots.POWER_VALUE`) au lieu
   d'un forfait.
3. **Défaut du bot face à VanCleef** : les deux sbires apparus à 50 % comptaient comme des
   ennemis entiers ; le bot refusait de franchir le seuil pendant que le boss se renforçait
   (combats de 11 à 17 tours, cartes de gros dégâts faussement mauvaises). Les sbires
   comptent désormais à moitié (ils fuient à la mort du chef).
4. **Récupération sous-évaluée par le bot** (0,9 point par PV au lieu de 10) : corrigée.
   Les soins sont alors devenus dominants (+31 à +33 points pour Rénovation et Soins rapides)
   car les PV se gardent d'un combat à l'autre et le boss est un test de PV : les soins
   deviennent Consumés et plus petits.
5. **Incantations** : à visibilité parfaite, elles ne valent que si elles frappent bien plus
   fort qu'une carte immédiate (Flammes sacrées 16 → 24, Halo 8 → 15 à tous,
   Embrasement 26 pour 3 mana → 28 pour 2).
6. **Apothéose et Bandeau de VanCleef** : « +1 carte piochée » ne valait rien (3 mana pour
   5 cartes à 1 mana : la main déborde déjà). Les deux donnent désormais +1 mana par tour.
7. Ajustements fins : Fouet mental (4 → 8 et pioche), Schisme (inflige, puis réduit),
   Pénitence (4 → 6 × 3), Peste dévorante à 0 mana, Suppression de la douleur (coût 1,
   Recharge 4), Cri psychique (rendu à 2 tours après une baisse trop forte).

## Ennemis : pourquoi

- **Combats normaux trop courts et gratuits** (3 tours, < 7 PV) : PV des normaux +40 à +50 %,
  dégâts +1 à +2.
- **Élites pas plus dures que les normaux** : Golem 45 → 72 PV avec un troisième coup
  (Moisson 8 × 3) ; Rhahk'Zor 50 → 75 PV, son Rugissement frappe aussi.
- **VanCleef trop long** (9 tours) : 110 → 92 PV, plus mordant, et un cycle de 4 coups dont
  un seul interrompt (Coup de pied 9, qu'une Absorption suffit à couvrir). Avec la Frappe
  mortelle qui interrompait (20 dégâts), un deck Sacré perdait 30 points au boss.
- **Interruptions qui ne pesaient pas** : coups qui interrompent ajoutés au Bandit (Coup de
  pied, un roublard), au Sorcier (Éclats de givre), au Golem, à Rhahk'Zor et à VanCleef.
  La Morsure du gnoll a interrompu un temps : retirée, trop punitive pour le Sacré.
- **Guette** : coupe l'incantation, sinon inflige 3. Une version qui soignait un allié à la
  place rendait le Mystique trop fort, puisqu'il guette à chaque tour où une incantation est
  en main (champ `text` sur l'intention pour l'interface).

## Bibelots

Mesure : un bibelot au départ, sans autre butin (`sweep=relics loot=0`, base 24,4 %, ce qui
gonfle les écarts : quelques PV de plus suffisent à passer le boss).

| Bibelot | Rareté | Palier Ligue | Effet | Écart |
|---|---|---|---|---|
| Pierre de foyer fêlée | peu commune | 0 | Fuir un combat normal/élite une fois par expédition | (non mesuré : le bot ne fuit pas) |
| Bourse défias | peu commune | 0 | +25 % d'or (crochet `run.gold`) | (sans or dans le runner) |
| Bandage en lin | commune | 0 | Soigne 3 après chaque victoire | +16,7 |
| Tabard de Hurlevent | commune | 0 | 5 Absorption au 1er tour | +28,1 |
| Bandeau rouge de VanCleef | boss | 0 | +1 mana par tour ; ennemis Force 2 au début du combat | +27,7 |
| Insigne de l'Alliance / de la Horde | rare | 1 | Une fois par combat, retire les états négatifs au début du tour | +8,2 |
| Pierre à aiguiser grossière | peu commune | 1 | Attaques +1 par coup | +20,3 |
| Talisman de concentration | peu commune | 2 | Ignore la 1re interruption de chaque combat | +2,3 |
| Marmite de campagne | commune | 2 | Repos +10 PV (crochet `run.restHeal`) | +17,0 |
| Rubis de mana | rare | 3 | +1 mana au 1er tour | +26,1 |

Changements : Tabard 8 → 5 Absorption, Bandage 5 → 3, Rubis sans la pioche en plus (ils
dépassaient +23 à +36). Le premier Bandeau (pioche +1, ennemis Force 1) était négatif (−6),
le second (pioche +1, −1 mana au 1er tour) aussi (−4) : il donne désormais du mana, avec une
vraie contrepartie (combats normaux gagnés à 95 % au lieu de 99 %).
Le Talisman ne vaut que dans un deck d'incantations ; c'est voulu.

Paliers : le GDD prévoit + 3 bibelots par palier de Ligue ; avec 10 bibelots j'en mets 5 au
palier 0 (dont le bibelot de boss), 2 au palier 1, 2 au palier 2 et 1 au palier 3.

## Potions

| Potion | Rareté | Palier | Effet | Bues (pour 100 expéditions, surtout…) |
|---|---|---|---|---|
| Potion de soins | commune | 0 | Soigne 15 | 63, presque toutes contre VanCleef |
| Potion de mana | commune | 0 | +2 mana ce tour | 65, surtout en combat normal |
| Potion de protection contre l'ombre | peu commune | 0 | 12 Absorption | 24 |
| Feu liquide | peu commune | 2 | 10 à la cible et Douleur 3 (ciblée) | 24 |
| Élixir de sagesse | rare | 2 | Pioche 3, retire les états négatifs | 20 |

Le bot garde une valeur de conservation par potion (`Bots.POTION_KEEP`) : la potion de soins
n'est bue que pour éviter la mort ou au dernier combat ; la potion de mana quand elle débloque
un tour nettement meilleur. Le butin compte beaucoup : sans bibelot ni potion gagnés, la
victoire pick=random tombe à 24 %.

## Expiation : le tour où elle est posée ne compte plus (nov. 2026)

Retour de test en jeu : « Expiation 1 tour » ne durait que le tour où la carte était jouée,
ce qui rendait l'enchaînement Expiation puis Pénitence presque impossible (Barrière
lumineuse 2 + Pénitence 2 = 4 mana sur 3). Règle désormais : un bienfait à durée que le
joueur se pose pendant son tour saute la baisse de fin de ce round (« Expiation N » = le reste
du tour + les N tours suivants) ; les durées ré-empilées s'additionnent sans recompter le tour
en cours (détail dans l'en-tête de `Core/Statuses.lua`). Aucune compensation appliquée.

Mesure (`runner=expedition key=0`, heuristic, 2 000 expéditions, graine 1) :

| | Victoires | Boss | Élite | Normal | PV perdus boss | Tours boss |
|---|---|---|---|---|---|---|
| Avant | 71,0 % | 73,7 % | 98,0 % | 99,0 % | 53,1 | 7,23 |
| Après | 79,8 % | 81,9 % | 98,6 % | 99,3 % | 53,1 | 7,21 |

+8,8 points, presque tout sur VanCleef. Réconfort (+12,7) profite le plus : il s'entretient
seul (son Expiation couvre le tour suivant, donc le Réconfort suivant rend toujours 1 mana).
Pistes de compensation, non mesurées : Expiation ramenée de 1 sur les cartes à 2 tours et plus
(Radiance 2/3 → 1/2, Évangélisme 3 → 2, Schisme+ 2 → 1) pour leur rendre leur durée effective
d'avant ; soin d'Expiation 2 → 1 PV (`Combat.ATONEMENT_HEAL`) ; Réconfort 5/8 → 4/6 dégâts ;
ou VanCleef +10 % de PV.

## Écarts restants et suites

- Les élites tuent rarement (< 1 %) : elles usent (20 PV) mais le seul mur est VanCleef.
  À revoir avec l'expédition complète de la piste B (marchand, rencontres, clés mythiques).
- Les cibles valent pour l'acte 1 seul ; l'expédition de 3 actes (cible GDD 40–60 %) reste
  à mesurer avec `runner=expedition` après fusion.
- Le choix `rated` reste une table à la main (`Run.RATING`) : une table tirée des balayages
  a fait moins bien (61 %) que l'ancienne, plus favorable aux soins. Les balayages forcés au
  départ et les écarts pick=random ne mesurent pas la même chose.
- Le bot n'utilise pas la Pierre de foyer ; la Bourse et la Marmite n'agissent que dans la
  couche expédition.
