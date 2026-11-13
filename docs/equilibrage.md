# Équilibrage des cinq classes (12 et 13/11/2026)

> **Note (13/11/2026, campagne par zones, `docs/zones.md`)** : la Ligue des explorateurs est supprimée. Les
> mesures « Ligue exaltée » / `meta=exalted` ci-dessous correspondent à `zones=7` (tout le commun et les
> deux avantages débloqués) et `meta=start` à `zones=0` ; les deux alias restent acceptés par `Sim/sim.lua`.
> Les anciens `league=N` correspondent à `zones=N` (N ≤ 3 ; Exalté = `zones=6`), aux drapeaux d'histoire près
> (vétéran dès `zones=1`). L'expérience gagne maintenant +15 % par niveau de clé (au lieu de 10 %).
> L'équilibrage est à refaire avec la nouvelle structure.

Priest, Warrior, Mage, Rogue, Hunter, clé 0 puis clés 1 à 5, bot `heuristic`, `runner=expedition`, graine 1.
Rapports bruts dans `reports/` (non versionnés).

## Cibles

| Mesure (clé 0, bot heuristic) | Cible |
|---|---|
| Compte neuf, classe au niveau 1 (`meta=start level=1`) | 62–72 % pour chaque classe, écart max − min ≤ 6 points |
| Niveau 7, Ligue exaltée (`meta=exalted level=7`) | 72–82 %, écart ≤ 6 points ; niveau 7 ≥ niveau 1 à Ligue égale (`meta=exalted level=1`) |
| PV perdus par combat normal | **6–9 pour toutes les classes** (passe 3, 13/11/2026 : le Rogue sert de référence) ; avant : Priest ≈ 15, Warrior 11–16, Rogue 12–16, Mage ≤ 11, Hunter ≤ 13 |
| Durée | combat normal 2,7–4 tours (passe 3 ; avant 3–5), boss 5–8 |
| Voies | chaque voie seule (`path=<voie>`, niveau 7) ≥ 50 % |

## Instrument : corrections du bot (étape 0)

1. **Cartes offertes hors combat** (`Sim/expedition.lua`). Une carte ajoutée vaut
   `2 × (note − 5) × 10 / taille du deck / 3` unités de rencontre (1 unité ≈ une potion ≈ 33 po ≈ 8 PV à
   pleine vie ; `SE.POINTS_PER_UNIT = 3` points de victoire par unité). La note vaut 5 + écart / 2 (écart =
   points gagnés en ajoutant la carte au deck de départ de 10 cartes) : 5 = carte neutre, dessous elle nuit ;
   l'effet se dilue avec la taille du deck. « Une parmi n, ou passer » vaut la meilleure note espérée parmi
   n tirées sans remise dans la réserve de cette rareté, jamais moins que 0. Récompense : la mieux notée,
   ou rien si sa valeur est négative (`pick=always` : toujours prendre). Marchand : la carte dont la valeur
   dépasse le plus son prix × 0,03. Aucun code propre à une carte.
2. **Pouvoirs** (`Sim/bots.lua`, `Bots.POWER_VALUE`) : une estimation par Pouvoir tirée de son texte, avec les
   mêmes repères (tours restants du combat = PV max de ses ennemis / 15 − tours joués, entre 0,5 et 5 ;
   3,5 cartes jouées par tour ; part du deck qui en profite). Un Pouvoir inconnu vaut `W.power × (1 + coût)`.
   Les tours restants ne dépendent pas des PV actuels des ennemis : tuer plus vite ne fait jamais perdre de
   valeur au Pouvoir.
3. **Notes des cartes** (`classDef.bot.rating`, `ns.NeutralBot.rating`), méthode reproductible :
   1. `luajit Sim/sim.lua runner=expedition sweep=cards class=<c> meta=start level=7 runs=500 jobs=8 save=reports/sw-<c>.lua`
      (une classe à la fois ; chaque carte ajoutée de force au deck de départ, mêmes graines que la série sans elle) ;
   2. note = 5 + écart / 2, bornée à [3, 14], au demi-point (script : écart de la colonne « écart ») ;
   3. cartes neutres : `only=<les 10 neutres>` pour chacune des cinq classes, moyenne des écarts ;
   4. vérifier en expédition complète (L1 neuf et L7 exalté, 1 000 expéditions) que les nouvelles notes font au
      moins aussi bien que les anciennes ; sinon chercher la carte surcotée (balayage `only=`) ;
   5. refaire le balayage d'une classe après un changement de ses cartes (les notes des cartes modifiées
      deviennent fausses). Le balayage sature près de 95 % : le faire avec des PV ou un réglage où la classe
      gagne 75–90 %.
   Limite : le balayage surévalue ce qui aide un deck de départ faible (soins, Absorb) et sous-évalue les cartes
   à construire ; il ne voit pas les synergies entre deux cartes ajoutées.
4. **Goblin Sapper Charge** : « Pay 5 HP. » en première ligne (coût `payHp`, décision commune), plus de
   « Lose N HP » ni de `minHp`.

## Outils ajoutés à la simulation

- `pick=always` (toujours prendre une carte en récompense), `hp=N` (PV de départ essayés sans toucher aux
  données), `path=<voie>` (voie jouée seule : les cartes des autres voies et les neutres valent 0, donc ne
  sont jamais prises), `oldstun=1` (ancienne règle de Stunned), `only=` accepte les cartes hors réserve
  (neutres).
- Commande de référence d'une classe : `nice luajit Sim/sim.lua runner=expedition bot=heuristic jobs=8 key=0
  class=<c> meta=start level=1 runs=2000` puis `meta=exalted level=7` (et `meta=exalted level=1` pour
  comparer à Ligue égale).

## Effet mesuré des corrections du bot (clé 0, 1 000 expéditions, L1 compte neuf / L7 exalté)

| Étape | Priest | Warrior | Mage | Rogue | Hunter |
|---|---|---|---|---|---|
| Départ (code b145d9c) | 85,0 / 88,1 | 66,0 / 80,7 | 80,0 / 88,7 | 88,9 / 92,1 | 82,9 / 87,1 |
| + valeur des cartes offertes (`pick=always`) | 87,9 / 90,8 | 68,8 / 81,6 | 82,3 / 89,3 | 90,1 / 92,6 | 86,1 / 86,4 |
| + refus en récompense | 87,8 / 91,0 | 68,8 / 81,6 | 82,3 / 89,3 | 90,1 / 92,6 | 86,1 / 86,4 |
| + Pouvoirs (L7) | – / 91,0 | – / 82,3 | – / 88,9 | – / 93,5 | – / 87,7 |
| + notes tirées des balayages | 89,4 / 93,5 | 71,7 / 85,4 | 87,2 / 93,3 | 95,1 / 97,2 | 96,2 / 97,0 |

Aucune correction ne dégrade une classe ; les notes du balayage rendent le bot nettement plus fort (+1 à +9
points), ce qui fausse toutes les mesures faites avec les anciennes notes. Filon de Jango : Rough Dynamite
prise 87 à 91 % du temps avant, 0 % après (la flasque, une potion, est prise à 88-90 %).

## Règle de Stunned pendant le tour ennemi (décision du 12/11/2026)

Mesurée par `oldstun=1` (ancienne règle : l'attaque part, le tour suivant est perdu) contre la nouvelle, Hunter :
- avant l'équilibrage (PV 55, notes du balayage, plafonné vers 95 %) : 95,1 → 96,2 % au niveau 1 (compte neuf),
  95,2 → 97,0 % au niveau 7 ; PV perdus par élite 5,4 → 2,4 ;
- **à l'état final (1 000 expéditions) : 57,0 → 67,4 % au niveau 1 (+10,4), 74,4 → 82,0 % au niveau 7 (+7,6) ;
  PV perdus par élite 6,4 → 3,3** (les élites ne sont pas immunisés à Stunned). Les PV du Hunter (41) et ses
  cooldowns d'étourdissement (Wyvern Sting, Intimidation 3 → 4) ont été réglés avec la nouvelle règle en place.

## Tableau final (clé 0, bot heuristic, graine 1)

Warrior et Rogue ont changé depuis : voir « Passe 2 » plus bas.

Niveau 1 compte neuf et niveau 7 exalté : 2 000 expéditions (intervalle à 95 % ≈ ± 2 points) ;
niveau 1 exalté : 1 000 (± 2,6). Warrior : 1 000 expéditions après son dernier lot (± 2,9 / ± 2,4).

| Classe | PV | L1 neuf | L7 exalté | L1 exalté | L7 − L1 (Ligue égale) |
|---|---|---|---|---|---|
| Priest | 52 | 70,0 % | 81,0 % | 77,7 % | +3,3 |
| Warrior | 72 | 65,5 % | 80,8 % | 80,5 % | +0,3 |
| Mage | 42 | 65,2 % | 80,8 % | 76,2 % | +4,6 |
| Rogue | 49 | 70,0 % | 81,5 % | 78,8 % | +2,7 |
| Hunter | 41 | 67,4 % | 82,0 % | 71,6 % | +10,4 |
| écart max − min | | 4,8 | 1,2 | | |

Par type de combat (L1 neuf ; L7 exalté entre parenthèses) : victoires, tours moyens, PV perdus.

| Classe | Normal : tours / PV perdus | Élite : tours / PV perdus | Boss : victoires / tours / PV perdus |
|---|---|---|---|
| Priest | 4,35 / 13,6 (4,22 / 12,5) | 5,93 / 20,0 (5,83 / 18,1) | 71 % / 6,8 / 55,9 (82 % / 6,8 / 47,3) |
| Warrior | 3,28 / 9,7 (3,09 / 9,2) | 5,38 / 22,5 (5,07 / 21,3) | 68 % / 6,9 / 49,5 (82 % / 6,1 / 41,9) |
| Mage | 3,32 / 6,2 (3,03 / 5,3) | 4,55 / 9,4 (4,07 / 6,8) | 69 % / 5,1 / 25,9 (82 % / 4,9 / 24,9) |
| Rogue | 3,02 / 5,7 (2,95 / 5,3) | 4,61 / 15,9 (4,43 / 14,0) | 72 % / 5,0 / 30,7 (84 % / 5,0 / 27,9) |
| Hunter | 2,86 / 4,5 (2,67 / 4,8) | 4,01 / 3,3 (3,88 / 4,1) | 68 % / 5,6 / 32,4 (82 % / 4,9 / 28,2) |

Voies seules (`path=<voie>`, niveau 7 exalté, 500 expéditions, ± 4,4) : le bot ne prend que les cartes de
la voie (et passe les autres, neutres comprises), ce qui est plus dur qu'un vrai deck orienté.

| Classe | Voie 1 | Voie 2 | Voie 3 |
|---|---|---|---|
| Priest | Discipline 63,6 % | Shadow 61,2 % | Holy 57,4 % |
| Warrior | Arms 53,6 % | Fury 55,6 % | Protection 53,8 % (49,0 avant Devastate / Shield Slam) |
| Mage | Fire 56,6 % | Frost 67,4 % | Arcane 62,6 % |
| Rogue | Assassination 65,0 % | Combat 50,6 % | **Subtlety 21,4 %** (19,4 après ses renforts et les notes rebalayées) |
| Hunter | Beast Mastery 71,8 % | Marksmanship 57,6 % | Survival 55,2 % |

## Clés mythiques (niveau 7, Ligue exaltée, 500 expéditions par case, ± 4 points)

Cible : celle de `docs/expedition.md` (« ≈ −5 points par niveau de clé »), soit 81 → 76 → 71 → 66 → 61 → 56 %,
sans qu'une classe s'écarte de plus de 10 points des autres à une clé donnée. Avec les anciens affixes et
les classes équilibrées : clé 1 ≈ 73 % (−8), clé 2 ≈ 50 % (−23, Tyrannique : PV perdus par élite 18 → 33) ;
clé 4 : Priest 48 % contre 59 à 66 % pour les autres (Nécrotique annule ses soins).

Affixes recalés (`Meta.AFFIX`, avant → après) : Fortifié PV des normaux +20 % → +12 % ; Tyrannique élites
+20 % → +5 % de PV et de dégâts, boss +7 % → +3 % de PV ; Nécrotique −10 % → −5 % de soins par coup, plafond
10 → 6 piles (−30 % au plus, écrit sur l'affixe et l'état) ; Galvanisant et Disette inchangés.

| Clé | Priest | Warrior | Mage | Rogue | Hunter | Moyenne | Cible | Écart max − min |
|---|---|---|---|---|---|---|---|---|
| 0 (2 000) | 81,0 | 80,8 | 80,8 | 81,5 | 82,0 | 81,2 | 81 | 1,2 |
| +1 | 75,6 | 76,6 | 77,8 | 78,8 | 78,6 | 77,5 | 76 | 3,2 |
| +2 | 72,2 | 69,2 | 72,4 | 71,4 | 74,6 | 72,0 | 71 | 5,4 |
| +3 | 66,2 | 63,4 | 69,8 | 68,6 | 69,4 | 67,5 | 66 | 6,4 |
| +4 | 62,2 | 62,0 | 67,4 | 67,2 | 68,0 | 65,4 | 61 | 6,0 |
| +5 | 55,8 | 53,6 | 63,4 | 58,8 | 63,0 | 58,9 | 56 | 9,8 |

La clé 4 ne coûte que 2 points de plus que la clé 3 (Nécrotique adouci pour ne pas écraser le Priest) ; le
pas reste régulier en moyenne (−4,5 par clé). Le Warrior et le Priest, qui encaissent et se soignent,
souffrent le plus des clés hautes ; le Mage et le Hunter, qui contrôlent, le moins.

## Nombres changés (avant → après ; « a/b » = carte de base / améliorée)

Principe : d'abord les cartes hors norme repérées par balayage (les plus fortes du niveau 1 affaiblies, les
cartes débloquées aux niveaux 2 à 7 trop faibles renforcées, pour que le niveau 7 apporte quelque chose),
puis les PV de départ pour poser le niveau. Aucune règle de classe changée ; aucun ennemi touché.

**Priest**
- PV 65 → 52 (niveau : la courbe des PV vaut ≈ 1 à 2 points par PV).
- PW: Solace 5/8 → 4/6 dégâts ; Penance 6×3/8×3 → 5×3/7×3 ; Greater Heal 12/16 → 10/13 ; Holy Nova 4/6 → 3/5
  à tous (les cartes de niveau 1 qui dominaient le balayage, +8 à +12 points).
- Rapture +1/+2 → +2/+3 par gain d'Absorb ; Halo 15/19 → 18/22 ; Empyreal Blaze 28/36 → 32/40 (débloquées
  aux niveaux 4 à 7, négatives ou nulles au balayage).

**Warrior**
- PV 75 → 72.
- Bloodthirst Cooldown 3 → 4 (+24,8 au balayage : Strength permanente) ; Deep Wounds DoT 2/3 → 1/2 (+14 à
  +16) ; Thunder Clap 4/6 → 3/5 à tous ; Shield Wall 18/24 → 15/20 Absorb.
- Mortal Strike 16/21 → 18/23 ; Slam 14/18 → 16/20 ; Cleave 7/10 → 8/11 ; Onslaught 8/11 → 10/13 ;
  Recklessness « Pay 4 HP. » → « Pay 3 HP. » (cartes débloquées) ; Devastate 6/8 → 7/10 (voie Protection à
  49 % seule) ; Victory Rush 4/6 → 3/5 dégâts (soin 4/6 inchangé).
- Essayés puis annulés : Shield Slam 4/6 → 3/5 Absorb (Protection trop faible), Rend DoT 4 → 3 et Victory
  Rush soin 4 → 3 (−11 points au niveau 1 : Rend est le pilier du Warrior débutant). Sacred Candle (Priest)
  non touché : la baisse des PV et des cartes du niveau 1 suffisait.

**Mage**
- PV 52 → 42.
- Ice Lance 4 + 8/5 + 10 → 3 + 6/4 + 8 (Frozen ; correctif prévu par la fiche) ; Presence of Mind Cooldown
  3/2 → 4/3 ; Polymorph coût 1/0 → 2/1 ; Frost Nova Absorb 4/6 → 2/4 ; Prismatic Barrier 6/9 → 5/8.
- Ignite DoT 2/3 → 3/4 ; Shatter +3/+4 → +4/+5 ; Combustion coût 1 → 0, amélioration pioche 2 → 3 ;
  Phoenix Flames 7/10 → 8/11 ; Glacial Spike 24/30 → 26/32.

**Rogue**
- PV 60 → 49.
- Départ : Sinister Strike 6/9 → 5/8 ; Backstab 4 + 8/6 + 10 → 3 + 7/5 + 9 (Stealth) ; Eviscerate 5 + 5/8 + 6
  → 4 + 4/6 + 5 par point (piste de la fiche, risque 7).
- Garrote DoT 4/6 → 3/5 ; Crippling Poison DoT 3/5 → 2/4 et Demoralized 2 → 1 (+18,8) ; Killing Spree
  5×6/7×6 → 4×6/6×6 ; Adrenaline Rush +3 → +2 mana ; Smoke Bomb Cooldown 3/2 → 4/3.
- Subtlety : Ambush coût 2 → 1 et 9/12 → 6/8 (bonus de Stealth inchangé) ; Vanish coût 1 → 0, amélioration
  pioche 1 → 2 ; Hemorrhage 5/7 → 7/9 et Sundered 1/2 → 2/3 ; Secret Technique 3/4 → 4/5 par point ;
  Shadowstep Cooldown 3/2 → 2/1.
- Essayés puis annulés : Deadly Poison coût 1 → 2 et Shadow Dance coût 2 → 1 (le bot surjoue ces
  Pouvoirs : −16 au balayage) ; Exsanguinate coût 0 + pioche (le harnais refuse un Surge avec une autre
  clause et `minRes`).

**Hunter**
- PV 55 → 41.
- Serpent Sting DoT 5/7 → 3/5 ; Wyvern Sting DoT 6 → 4 et Cooldown 3/2 → 4/3 ; Intimidation Cooldown 3/2
  → 4/3 ; Kill Command Cooldown 2/1 → 3/2 ; Counter Shot Cooldown 2/1 → 3/2 ; Kibler's Bits +2 → +1
  Frenzy (étourdissements en chaîne sur les élites : 2,4 PV perdus par élite).
- Dire Beast 1/2 → 2/3 attaques du familier ; Multi-Shot 4/6 → 5/7 ; Volley 13/17 → 16/20 ; Trueshot Aura
  +4/+6 → +5/+7 ; The Beast Within coût 2/1 → 1/0 ; Resourcefulness coût 2/1 → 1/0 ; Entrapment coût 1 → 0,
  amélioration Demoralized 1 → 2 ; Lock and Load coût 1 → 0, amélioration pioche 1 → 2.
- Marksmanship et pièges : Aimed Shot 20/26 → 24/30 ; Steady Shot 10/14 → 13/17 ; Cobra Shot 5/8 → 7/10 ;
  Counterattack 10/14 → 13/17.
- Essayé puis annulé : Spirit Bond coût 2 → 1 (+16,5 au balayage).

**Neutre** : Goblin Sapper Charge « Deal 14 to all. / Lose 5 HP. » → « Pay 5 HP. / Deal 14 to all. »
(formulation seulement, même coût).

Notes du bot (`bot.rating`) : toutes remplacées par celles des balayages (méthode plus haut).

## Cibles : bilan

| Cible | Résultat |
|---|---|
| L1 compte neuf 62–72 %, écart ≤ 6 | **Atteinte** : 65,2 à 70,0 %, écart 4,8 |
| L7 exalté 72–82 %, écart ≤ 6 | **Atteinte** : 80,8 à 82,0 %, écart 1,2 (Hunter au bord : 82,0 ± 1,7) |
| L7 ≥ L1 à Ligue égale | Atteinte pour Priest (+3,3), Mage (+4,6), Rogue (+2,7), Hunter (+10,4) ; **Warrior à égalité** (+0,3 ± 3,5, non significatif) |
| PV perdus par combat normal (cibles de la passe 1, remplacées par 6–9 en passe 3) | Priest 13,6 (≈ 15) ✓, Mage 6,2 (≤ 11) ✓, Hunter 4,5 (≤ 13) ✓ ; **Warrior 9,7** (11–16) ✗ de peu ; **Rogue 5,7** (12–16) ✗ |
| Combat normal 3–5 tours, boss 5–8 | ✓ sauf **Hunter : combat normal 2,86 tours** (boss 5,6 ✓) |
| Chaque voie seule ≥ 50 % au niveau 7 | ✓ pour 14 voies sur 15 ; **Subtlety (Rogue) 19 à 26 %** ✗ |
| Clés : ≈ −5 points par clé, classes à 10 points au plus | ✓ (écart max 9,8 à la clé 5) |

Ce qui bloque, et ce que je recommande :

- **Rogue, PV perdus (5,7 au lieu de 12–16 ; cible abandonnée en passe 3, le Rogue devient la référence)** : Parry (4 Feint au départ, une charge annule un coup jusqu'à
  8 dégâts, gardée d'un tour à l'autre) pare presque tous les coups des normaux (4 à 8 dégâts). Les règles
  tranchées (Parry gardé, 3 charges) et le « jusqu'à 8 » du GDD rendent la cible inatteignable par les
  nombres des cartes sans casser la classe : il faudrait abaisser le plafond d'un coup paré (8 → 5) ou
  remplacer une Feint du deck de départ par un Sinister Strike, puis remonter les PV (49 → ≈ 60). Je n'ai
  pas touché à la règle (dernier recours, décision du joueur).
- **Subtlety seule** : ses cartes ajoutées au deck de départ sont négatives au balayage même après les
  renforts (Ambush, Vanish, Hemorrhage, Secret Technique, Shadowstep) ; le bot ne sait pas « préparer » un
  Stealth pour un gros coup sur plusieurs tours. Piste : un vrai coup de grâce mono-cible pour la voie
  (Secret Technique ne touche « à tous » qu'au même total), ou Shadow Dance à coût 1 une fois la valeur des
  Pouvoirs du bot corrigée.
- **Warrior, L7 = L1** : la Ligue lui apporte +15 points (bibelots communs d'Absorb et de Strength), ses
  cartes débloquées presque rien ; les renforts essayés (Mortal Strike, Slam, Cleave, Onslaught,
  Recklessness) sont restés neutres, et affaiblir ses piliers du niveau 1 (Rend) le faisait tomber à 54 %.
  Piste : une rare du niveau 7 plus forte (Shield Wall, Deep Wounds) avec −1 ou −2 PV.
- **Hunter, combats courts (2,86 tours)** : les dégâts viennent du familier (1 + Frenzy par coup, Frenzy qui
  monte de 1 à chaque attaque) ; Arcane Shot à 3 est tranché. Piste : PET_BASE 1 → 0 (règle de classe)
  avec +4 PV.

## Limites de la méthode (ce que le bot ne sait pas jouer)

- **Pouvoirs** : la valeur d'un Pouvoir est une estimation à la main (`Bots.POWER_VALUE`) ; plusieurs sont
  surjoués (Deadly Poison à coût 2 : −16 points au balayage contre +14 à coût 1, Shadow Dance, Cheat Death),
  ce qui les fait paraître mauvais. Leurs notes et leur équilibre sont les moins sûrs.
- **Notes du balayage** : une carte est mesurée seule dans le deck de départ ; les synergies (Subtlety,
  pièges du Survival) et les cartes à construire sont sous-évaluées, les soins et l'Absorb surévalués pour
  un deck faible. L'échelle dépend du taux de base (un balayage à 73 % comprime les écarts d'un tiers par
  rapport à un balayage à 68 %) : refaire toute la classe plutôt que quelques cartes. Plusieurs cartes
  changées après le dernier balayage complet ont gardé leur ancienne note (Hunter : Aimed Shot, Steady Shot,
  Cobra Shot, Counterattack, Entrapment, Lock and Load ; Warrior : Mortal Strike, Slam, Cleave, Onslaught,
  Recklessness) : un balayage complet de ces deux classes est la prochaine étape.
- **Visibilité parfaite** : le bot voit les intentions et simule le tour ennemi ; il ne se fait presque jamais
  interrompre ni piéger par une mauvaise lecture. Un joueur humain perdra plus, surtout au Mage (deux Cast)
  et au Hunter (Traps et cible du familier).
- **Hors combat** : choix de chemin, marchand et rencontres par règles simples (valeur d'unité arbitraire,
  1 unité ≈ une potion ≈ 3 points de victoire) ; le bot ne fuit jamais (Hearthstone) et achète peu.
- **Bruit** : ± 2 points à 2 000 expéditions, ± 4 à 500 ; les voies et les clés ont été réglées à 500.

## Passe 2 (12/11/2026) : Rogue, Subtlety, progression du Warrior

Trois décisions du joueur. Même méthode (clé 0, bot heuristic, graine 1) ; 2 000 expéditions pour les
mesures finales, 500 pour les voies et les essais. Priest, Mage et Hunter non touchés : rien de commun n'a
changé (l'option `league=` n'agit que si on la donne ; l'écran de progression n'est que de l'affichage).

### Tableau à jour (clé 0)

| Classe | PV | L1 neuf | L1 exalté | L7 exalté | L7 − L1 (Ligue égale) | PV perdus par combat normal (L1 neuf / L7 exalté) |
|---|---|---|---|---|---|---|
| Warrior | 72 → 74 | 65,5 → 65,2 | 80,5 → 79,5 | 80,8 → **85,7** | +0,3 → **+6,2** | 9,7 / 9,2 → 9,0 / 8,0 |
| Rogue | 49 → 50 | 70,0 → 70,0 | 78,8 → 79,2 | 81,5 → 81,7 | +2,7 → +2,5 | 5,7 / 5,3 → 6,3 / 5,8 |

Warrior par niveau (exalté, 2 000) : L1 79,5 → L2 82,8 → L4 84,0 → L6 84,2 → L7 85,7.
Voies seules (L7 exalté) : Subtlety 21,4 → **51,5 %** (2 000) ; Assassination 64,8, Combat 55,2 ; Arms 57,0,
Fury 55,2, Protection 61,2 (500).

### Rogue : une Feint de moins

- Deck de départ 4 Sinister Strike / 4 Feint → **5 / 3** (décision). À 60 PV comme demandé : 85,9 / 91,3 /
  92,3 % (L1 neuf / L1 exalté / L7 exalté) : le deck tue plus vite (combat normal 2,7 tours) et ne perd
  presque pas plus de PV, il est donc plus fort, pas plus fragile. **PV 49 → 50** remet les cibles (70,0 /
  79,2 / 81,7). Les PV n'ont pas pu monter vers 60.
- **PV perdus par combat normal : 6,3 au niveau 1 (5,7 avant), cible 12–16 non atteinte, à 6 à 10 PV
  près** (cible abandonnée en passe 3 : ce 6,3 devient la référence). Pourquoi : un combat normal dure 2,7 tours et ses coups (4 à 8) sont entièrement parés ; essai
  pour mesure (annulé) avec 2 Feint seulement : 7,1 PV par normal, mais 54 % au niveau 1 (−16 points). Le
  nombre de Feint pèse sur les élites et le boss, presque pas sur les normaux. Règle de Parry non touchée.

### Subtlety : Nightblade

- Nouvelle carte **Nightblade** (Subtlety, commune, **niveau 3** avec Flash Powder, coût 1, Attack) :
  `Surge: deal 6 per Combo.` / `Gain Stealth` ; améliorée 8 par point. Coup de grâce mono-cible qui rend
  Stealth pour l'ouverture suivante (Backstab, Ambush). Icône `Ability_Rogue_Nightblade`.
- Premier essai à 5 / 7 par point : 33,6 % (note 5) puis 38,2 % (note 9) seule. Le balayage la mesure
  neutre (−0,4 à −0,2 : un second Surge dans un deck de départ qui manque de points), comme Rupture et
  Envenom que la passe 1 avait notées 12 à la main : note 9.
- Notes de Subtlety relevées au-dessus de 5 (positives au balayage avec le nouveau deck, base 57 %) :
  Shadowstep 3 → 7, Secret Technique 3 → 6, Hemorrhage 3,5 → 5,5, Vanish 3 → 5,5. En voie seule, le bot ne
  prenait presque rien (2,3 cartes par expédition).
- Résultat : **51,5 % ± 2,2** (2 000) ; 42,2 % avec les mêmes notes sans Nightblade.
- Essais annulés : notes du Rogue entièrement rebalayées (base 86 % : L7 exalté 69,8 % ; base 57 % à
  42 PV : 52,4 / 59,6 %) : le balayage sous-cote les Surge et les moteurs (Rupture, Envenom, Blade Flurry) ;
  les anciennes notes sont gardées pour toutes les autres cartes.

### Warrior : progression par niveau

Diagnostic (balayage `sweep=cards`, L7 neuf, PV 72, base 74,6 %, ± 4) :
- les cartes débloquées valaient en moyenne +6,4 points ajoutées au deck de départ, contre +8,5 pour celles
  du niveau 1, qui comptait les deux meilleures de la classe (Bloodthirst +16,2, Enrage +10,6, Enrage prise
  plus d'une fois par expédition) : monter de niveau diluait la réserve ;
- le bot les joue (jouées/piochées 54 à 95 %, comme celles du niveau 1 ; Shield Wall et Demoralizing Shout
  sont conditionnelles) et les prend selon ses notes, mais ces notes étaient périmées (cartes changées
  après le balayage) ; les recaler seules : L1 exalté 81,3, L7 exalté 78,9 — le problème est dans les cartes ;
- la Ligue pèse 14 à 17 points pour le Warrior (4 à 11 pour les autres) : `league=1` +6 (bibelots et cartes
  neutres du palier 1, dont ceux qui demandent Absorb ou Attack), `league=3` +6 (bibelot de départ au choix
  de Révéré).

Changements (avant → après) :
- Niveaux : **Enrage 1 → 7** et Recklessness 7 → 1 (les deux rares de Fury) ; **Bloodthirst 1 → 2**,
  Battle Shout 4 → 1 ; Berserker Rage 2 → 4 (une carte par voie et par niveau gardée).
- Cartes débloquées : Mortal Strike 18/23 → 22/28 ; Demoralizing Shout coût 1/0 → 0/0 et Cooldown 3/3 →
  4/3 ; Berserker Rage +1/+2 → +2/+3 Rage ; Shield Wall 15/20 → 18/24 Absorb.
- PV 72 → 74.
- Notes du bot rebalayées (L7 neuf, base 76 à 80 %).

Balayage final (L7 neuf, PV 74, base 79,8 %, ± 4) par niveau de déblocage : niveau 2 Bloodthirst +13,4,
Thunder Clap +5,2, Cleave +3,6 ; niveau 4 Demoralizing Shout +11,0, Slam +5,0, Berserker Rage +4,8 ;
niveau 6 Mortal Strike +11,4, Onslaught +8,0, Retaliation +4,8 ; niveau 7 Shield Wall +9,0, Enrage +8,4,
Deep Wounds +6,0 (moyenne du niveau 1 : +6,7). Chaque niveau de carte en débloque au moins une positive.

Essais annulés : Enrage coût 2/1 (−0,6 au niveau 7 seulement, jouée deux fois moins) ; Bloodthirst sans
soin (+16 → +10 au balayage) ; Strike 6/9 → 5/8 (L1 neuf −11, L7 exalté −5 : creuse l'écart) ; notes
moyennées de deux balayages (L1 neuf 65,2 → 60,3 : le bot choisit moins bien, le niveau 1 dépend beaucoup
des notes) ; PV 71, 76, 77.

**Cible non atteinte : L7 exalté 85,7 % (cible 72–82, +3,7).** Écart L7 exalté − L1 neuf = gain de la Ligue
(≈ 14 pour le Warrior) + gain des niveaux (≥ 5) ≈ 20 : avec le niveau 1 neuf à 64 % au moins (Priest 70 − 6),
le niveau 7 exalté tombe vers 84–86 %. Baisser les PV creuse l'écart (PV 71 : 59,4 / 75,9 / 84,0 avant le
dernier réglage) ; affaiblir les cartes débloquées retire le gain demandé. Rester dans 72–82 demande de
réduire ce que la Ligue apporte au Warrior (bibelots communs d'Absorb et d'Attack, bibelot de Révéré), donc
de toucher au commun : décision du joueur. L'écart entre classes au niveau 7 reste dans les 6 points (80,8
à 85,7 : 4,9).

### Limites propres à cette passe

- Les notes du bot font bouger le niveau 1 de 5 à 6 points (Warrior : 64,2 → 70,4 % en ne changeant que les
  notes) ; un balayage de 500 expéditions donne des notes à ± 2 : garder le jeu de notes qui gagne le plus.
- La voie Subtlety seule est juste au-dessus de 50 % (51,5 ± 2,2).
- Écran de progression : 36 emplacements ; une rangée de plus de 10 cartes (Subtlety, 11) resserre son pas
  pour garder le même bord droit.


## Passe 3 (13/11/2026) : 6 à 9 PV perdus par combat normal, avec le Rogue comme référence

Décision du joueur : « Je trouve justement que le Rogue est le plus équilibré actuellement. On devrait
construire autour de cette cible, peut-être 7 ou 8 PV perdus par combat normal. » L'ancienne cible (12–16 PV
pour le Rogue, ≈ 15 pour le Priest…) est abandonnée. Nouvelle cible pour toutes les classes : **6 à 9 PV
perdus par combat normal** et des combats normaux de **2,7 à 4 tours** (bot heuristic, clé 0). Le Rogue ne
change pas.

Le périmètre a été réduit en cours de passe (décision du joueur : la Ligue des explorateurs va être
supprimée). Seuls comptent le niveau 1 compte neuf (`meta=start level=1`, 62–72 %, écart entre classes ≤ 6)
et une vérification du niveau 7 `meta=start` (chaque classe doit encore gagner en montant de niveau). Les
mesures `meta=exalted` et les clés 1 à 5 seront refaites après la suppression de la Ligue ; elles n'ont pas
servi de critère ici.

Même méthode (clé 0, graine 1) : 500 à 1 000 expéditions pour les essais, 2 000 pour les mesures finales.

### Remesure de départ (main, 2 000 expéditions)

Résultats identiques aux passes 1 et 2 (mêmes graines). PV perdus par combat normal au niveau 1 neuf :
Priest 13,6, Warrior 9,0, Mage 6,2, Rogue 6,3, Hunter 4,3 (combats de 2,83 tours). Warrior et Mage sont
déjà dans 6–9 : **non touchés**. Au niveau 7 exalté, le Mage (5,3) et le Rogue (5,8) sont un peu sous 6 ;
cette mesure est abandonnée avec la Ligue.

### Tableau final (clé 0, 2 000 expéditions, ± 2 points)

| Classe | PV | L1 neuf | L7 neuf | Gain L1 → L7 (neuf) | Normal : tours / PV perdus | Élite : tours / PV perdus | Boss : victoires / tours / PV perdus |
|---|---|---|---|---|---|---|---|
| Priest | 52 → **36** | 70,0 → **69,3** | 76,4 | +7,1 | 4,35 / 13,6 → **3,58 / 7,4** | 5,93 / 20,0 → 5,20 / 13,7 | 71 % / 6,8 / 55,9 → 70 % / 6,4 / 43,5 |
| Warrior | 74 | 65,2 | 77,8 | +12,6 | 3,15 / 9,0 | 5,24 / 22,8 | 68 % / 6,3 / 45,7 |
| Mage | 42 | 65,2 | 71,5 | +6,3 | 3,32 / 6,2 | 4,55 / 9,4 | 69 % / 5,1 / 25,9 |
| Rogue | 50 | 70,0 | 72,8 | +2,8 | 2,74 / 6,3 | 4,29 / 15,6 | 73 % / 4,6 / 31,2 |
| Hunter | 41 → **50** | 67,4 → **65,0** | 76,3 | +11,3 | 2,86 / 4,5 → **2,77 / 6,1** | 4,01 / 3,3 → 3,85 / 5,4 | 68 % / 5,6 / 32,4 → 65 % / 5,1 / 38,9 |
| écart max − min | | **5,0** | | | | | |

Les colonnes « tours / PV perdus » et « Boss » sont mesurées au niveau 1 neuf. PV perdus par combat normal
au niveau 7 neuf : Priest 7,9, Warrior 8,7, Mage 5,9, Rogue 6,6, Hunter 6,4.

### Priest : tuer plus vite et encaisser un peu mieux, avec beaucoup moins de PV

Changements (avant → après ; « a/b » = carte de base / améliorée) :
- Départ : **Smite 6/9 → 8/11** ; **Inner Fire 5/8 → 6/9 Absorb**.
- **PV 52 → 36**. Chaque PV vaut ≈ 1,5 point de victoire au niveau 1 neuf : 35 PV donnent 67,0 %, 36 PV
  69,3 %, 38 PV 74,1 %, 42 PV 80,2 %.
- Cartes du niveau 1 qui dominaient le balayage : Angelic Feather Cooldown 2 → 3 (écart +9,8 → +7,6) ; Pain
  Suppression Cooldown 4/3 → 5/4.
- Cartes débloquées aux niveaux 2 à 7, renforcées pour garder un gain en montant de niveau :
  - Mind Sear DoT 4/6 → 5/7 à tous ;
  - Luminous Barrier 12/16 → 14/18 Absorb ;
  - SW: Death 6 (Execute 12) / 8 (17) → 7 (14) / 9 (18) ;
  - Halo 18/22 → 22/26 à tous ;
  - Shadow Mend soin 10/14 → 12/16 ;
  - Empyreal Blaze 32/40 → 36/44 ;
  - Void Eruption 4 + 4/4 + 5 par point → 6 + 5/6 + 6.
- Notes du bot rebalayées avec ces nombres (`sweep=cards`, L7 neuf, PV 40, base 84,2 %, 500 expéditions).

Pourquoi ces deux cartes de départ : le Priest perdait 3,1 PV par tour de combat normal, sur 4,35 tours.
- Inner Fire 7 seul ramène la perte à 9,2 PV, mais les combats s'allongent (4,46 tours).
- Smite 8 seul la ramène à 9,4 PV en 3,61 tours, mais elle remonte à 10,0 au niveau 1 une fois les PV
  réglés pour retrouver le taux de victoire.
- Les deux ensemble, chacun moins renforcé (Smite 8, Inner Fire 6) : 7,4 PV en 3,58 tours.

Règles de classe (Atonement, Sacred Candle) non touchées.

Essais annulés :
- Inner Fire 7 seul : 91,4 % à 52 PV, combats plus longs.
- Smite 8 seul : 10,0 PV par normal une fois les PV réglés.
- Smite 7 + Inner Fire 6 : 9,2 PV par normal et 4,0 tours, au bord des deux cibles.
- Inner Fire 7 + Smite 7 : 7,2 PV, mais 93,6 % à 52 PV ; il aurait fallu ≈ 30 PV.
- Solace 4/6 → 3/5 : aucun effet au balayage (+9,4 dans les deux cas). Sa valeur vient du mana rendu, pas
  des dégâts.

Constat : un deck de départ plus fort réduit ce que tout le reste apporte.
- Avec le nouveau deck et les anciennes notes, le Priest gagnait moins au niveau 7 exalté qu'au niveau 1
  exalté (76,8 contre 79,4, 500 expéditions).
- Avec les notes rebalayées et les cartes débloquées renforcées, le gain de niveau revient : +7,1 à Ligue
  neuve.
- Mesure intermédiaire à 38 PV (notes du 2e balayage) : L1 exalté 79,5, L7 exalté 81,5. L'apport de la Ligue
  au Priest tombe de +7,3 à ≈ +5, et celui des niveaux à Ligue exaltée de +3,7 à ≈ +2.
- Explication probable : les combats ordinaires coûtant peu, le Priest arrive presque intact au boss, qui
  décide seul de l'expédition. Ce que la Ligue apporte entre les combats compte donc moins. À revoir sans la
  Ligue.

### Hunter : moins d'Absorb gratuit, plus de PV

Changements : **Disengage 5/8 → 3/6 Absorb** ; **PV 41 → 50** ; notes du bot rebalayées (L7 neuf, PV 50,
base 78,0 %). Les nouvelles notes font aussi bien que les anciennes : L1 neuf 65,0 contre 64,8, L7 neuf
76,3 contre 76,9.

Pourquoi l'Absorb plutôt que le contrôle : les combats normaux du Hunter sont déjà courts (2,8 tours), et
c'est l'étourdissement de Freezing Trap (qui annule l'attaque qui la déclenche) qui lui évite les coups.
Mais retoucher le contrôle coûte surtout contre le boss, immunisé à Stunned. Essais (1 000 expéditions,
41 PV) :

| Essai | L1 neuf | PV perdus par normal |
|---|---|---|
| départ | 67,1 | 4,3 |
| Freezing Trap sans Demoralized (amélioration : Demoralized 1) | 50,3 | 4,4 |
| Serpent Sting DoT 3/5 → 2/4 | 63,0 | 4,4 |
| Disengage 4/7 | 55,2 | 5,1 |
| Disengage 4/7 et Freezing Trap sans Demoralized | 37,1 | 5,1 |
| **Disengage 3/6** | 40,6 | **6,2** |
| **Disengage 3/6, 50 PV** | 66,7 | 6,2 |

Le Demoralized de Freezing Trap est son seul effet contre le boss (−17 points sans lui) et ne change presque
rien contre les normaux : il est gardé. Seul l'Absorb du deck de départ fait bouger les PV perdus par
combat normal.

### Cibles : bilan

| Cible | Résultat |
|---|---|
| 6–9 PV perdus par combat normal (L1 neuf) | **Atteinte** : Priest 7,4, Warrior 9,0, Mage 6,2, Rogue 6,3, Hunter 6,1 |
| Combat normal 2,7–4 tours | **Atteinte** : de 2,74 (Rogue) à 3,58 (Priest) |
| L1 neuf 62–72 %, écart ≤ 6 | **Atteinte** : de 65,0 à 70,0 %, écart 5,0 |
| Gain du niveau 1 au niveau 7 (Ligue neuve) | **Chaque classe gagne** : de +2,8 (Rogue) à +12,6 (Warrior) |
| L7 exalté, clés 1 à 5 | Non mesurés (Ligue supprimée, à refaire) |

### Limites propres à cette passe

- **Priest à 36 PV** : c'est la classe la plus fragile sur le papier.
  - Le boss lui coûte 43,5 PV en moyenne, plus que ses PV, car les défaites comptent tous les PV restants.
  - Un combat normal lui coûte 21 % de ses PV, contre 13 % pour le Rogue et 12 % pour le Hunter.
  - Un joueur qui lit moins bien les intentions que le bot le sentira davantage.
- **Hunter** : il perd toujours très peu de PV par élite (5,4, contre 9 à 23 pour les autres classes), car
  Freezing Trap arrête les gros coups des élites, qui ne sont pas immunisés. Ce point n'était pas visé par
  cette passe.
- **Mage** au niveau 7 neuf : 5,9 PV par combat normal, juste sous 6 (6,2 au niveau 1). Le Rogue de
  référence est lui-même à 5,8 au niveau 7 exalté.
- **Bruit du balayage** : à 500 expéditions, l'écart d'une carte bouge de ± 4 d'un balayage à l'autre sans
  que la carte elle-même change (Devouring Plague +3,8 puis +8,8 ; Void Eruption +8,0 puis +0,2). Les notes sont donc à
  ± 2.
- Les tests (`Sim/tests.lua`, `Sim/tests_expedition.lua`, `Sim/ui_harness.lua`) lisent désormais les nombres
  des cartes et les PV de départ dans les données au lieu de les recopier.


# Équilibrage de l'acte 1 (piste A, historique : Prêtre seul, runner linéaire)

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
| MdP : Radiance | Disc. | commune | 0 | 1 | Expiation 2, 4 Absorption | +1,2 | 65 % |
| MdP : Réconfort | Disc. | commune | 0 | 1 | Inflige 5 ; sous Expiation +1 mana ; Expiation 1 | +3,6 | 83 % |
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
| MdlO : Mort | Ombre | peu commune | 1 | 1 | Inflige 6 (12 sous la moitié des PV), +1 Démence | −3,0 | 62 % |
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
| Compensation (Radiance 1/2, Évangélisme 2, Schisme+ 1) | 78,8 % | 81,0 % | 98,5 % | 99,3 % | 53,2 | 7,21 |

+8,8 points, presque tout sur VanCleef. Réconfort (+12,7) profite le plus : il s'entretient
seul (son Expiation couvre le tour suivant, donc le Réconfort suivant rend toujours 1 mana).
Pistes de compensation, non mesurées : Expiation ramenée de 1 sur les cartes à 2 tours et plus
(Radiance 2/3 → 1/2, Évangélisme 3 → 2, Schisme+ 2 → 1) pour leur rendre leur durée effective
d'avant ; soin d'Expiation 2 → 1 PV (`Combat.ATONEMENT_HEAL`) ; Réconfort 5/8 → 4/6 dégâts ;
ou VanCleef +10 % de PV.
Compensation appliquée : Expiation −1 tour sur Radiance (2/3 → 1/2), Évangélisme (3 → 2) et Schisme+ (2 → 1) ; −1,0 point seulement (78,8 %), l'écart vient surtout de Réconfort (+13,3), non touché.

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

## Épiques du Rogue dans les zones dures (14/11/2026)

Mesure commune aux cinq classes (`runner=expedition level=7 key=0 bot=heuristic runs=600`, épique imposée par
`epic=<id>`) : Duskwood `zones=1`, Stranglethorn `zones=3`, Steppes `zones=5`. Sans épique : 60,0 / 61,2 / 74,3 %
(Westfall `zones=7` : 78,7 %). Gain moyen sur les trois zones, avant → après : Deflection 17,1 → 11,1 ; Doomblade
15,9 → 12,8 ; Atrophic Poison 18,5 → 11,4 ; Echoing Reprimand 18,9 → 8,0 ; Subterfuge 10,3 → 13,4 ; Kidney Shot
15,1 → 10,4 ; Danse Macabre 22,3 → 11,3. Moyenne de la classe : 16,9 → **11,2** ; aucune zone au-delà de +17,2
ni sous +6,0 ; PV perdus par combat normal 5,4 à 8,4. Textes, nombres, essais écartés et tableau par zone :
`docs/zones/cartes-de-zone.md`, section « Rogue ».

## Blackrock Mountain : passe de difficulté (14/11/2026)

Cible : 50 % de victoires au bot de référence (clé 0, `zone=blackrock zones=6 level=7`, épique gagnée en jeu),
écart entre classes ≤ 10 points, Nefarian combat le plus dur. Avant → après (1 500 expéditions) : Priest 69,0 →
49,0 ; Warrior 71,5 → 49,1 ; Mage 68,5 → 46,5 ; Rogue 78,9 → 54,3 ; Hunter 80,8 → 54,1 ; moyenne 73,7 → **50,6**,
écart 12,3 → **7,8**. PV perdus par combat normal : 10,0 / 10,2 / 6,8 / 7,4 / 7,1 → 12,3 / 12,8 / 8,4 / 9,0 / 8,2.
Leviers : PV des normaux (+10 %), Vaelastrasz (40 % au départ, Cleave 20), Gyth 104 PV, Panzor 96 PV avec un
plafond d'Invincible relevé à 10 (il punissait le Warrior), Nefarian 120 PV et ses gros coups +2 ; l'écart venait
du boss, réglé par le Class Call : Called Out (Rogue) empêche aussi de regagner la Parry, sur 1 tour ; Broken Bow
(Hunter) −5 sur 3 tours. Détail, essais écartés et ce qui reste (Hunter à 95 % contre les élites, qu'il
étourdit) : `docs/zones/blackrock.md`, « Passe de difficulté ».
## Passe de difficulté de Duskwood (14/11/2026)

Cible de la zone 2 : 72 % de victoires en moyenne, écart ≤ 10 points (`runner=expedition key=0 zone=duskwood
zones=1 level=7`, bot heuristique, épique gagnée sur les élites). Avant : 67,7 % (Priest 70,1, Warrior 70,5,
Mage 65,9, Rogue 63,6, Hunter 68,4 ; 800 expéditions), 85 % des défaites au boss. Seul Morbent Fel change :
Drain Life 14 / 16 → 12 / 14, Shadow Bolt 17 / 20 → 15 / 18 (Rogue et Mage n'interrompent presque rien),
PV 92 → 96. Après (1500 expéditions) : **72,3 %**, écart 7,5 (Priest 76,8, Warrior 73,7, Mage 69,3, Rogue 71,4,
Hunter 70,4) ; PV perdus par combat normal inchangés (6,6 à 10,5). Détail et essais écartés : `docs/zones/duskwood.md`,
« Passe de difficulté ».
## Swamp of Sorrows : passe de difficulté (14/11/2026)

Cible de la zone 5 : 60 % de victoires en moyenne, écart entre classes ≤ 10 points (`runner=expedition key=0
zone=swamp zones=4 level=7`, épique gagnée sur les élites). Avant (800 expéditions) : Priest 73,4, Warrior 64,2,
Mage 62,0, Rogue 52,5, Hunter 59,4 % (moyenne 62,3, écart 21). Après (1 500) : Priest 64,5, Warrior 60,3, Mage
60,3, Rogue 60,2, Hunter 57,1 % (moyenne **60,5**, écart **7,4**). Le Priest, qui se soigne en combat, atteignait
Somnus dans 95 % des expéditions contre 69 % au Rogue (élites Gilmorian et Chieftain à 80 %) et ne perdait qu'au
boss, où il est le plus lent. Changements, dans la zone seule : Death Roll 20 → 10 × 2 et Spear Thrust 13 → 7 × 2
(deux coups que Parry arrête) ; Gilmorian Lightning Bolt 20 → 16, Healing Wave 20 → 24 ; soin de Slumber de Wyrmak
6 → 9 ; Somnus 140 PV (135) et Wing Buffet donne Strength 3 (le boss coûte plus cher aux combats longs : Priest
et Warrior). Détails, essais écartés et mesures par rencontre : `docs/zones/swamp.md`, « Passe de difficulté ».

## Passe de difficulté de Stranglethorn Vale (14/11/2026)

Cible : 64 % de victoires en moyenne (`runner=expedition zone=stranglethorn zones=3 level=7 key=0 bot=heuristic`,
épiques gagnées en route), écart ≤ 10. Avant (800) : Priest 64,8, Warrior 71,2, Mage 74,2, Rogue 65,4, Hunter
76,0 (moyenne 70,3, écart 11,2). Après (1500) : **60,4 / 63,6 / 69,0 / 64,1 / 64,4** (moyenne 64,3, écart 8,6) ;
PV perdus par combat normal inchangés (9,8 / 11,4 / 7,2 / 7,6 / 7,8). Le Mage et le Hunter passaient les élites
presque sans perte (contrôle) : élites adoucis (Priest, Warrior, Rogue +4 à 5 points d'élites), difficulté portée
par Jin'do, plus robuste (134 → 176 PV : coûte plus au Warrior et au Mage) et moins pointu (le Priest à 36 PV
craint les gros coups) ; son Shadow Bolt coupe le Cast à travers l'Absorb ; Delusions frappe par un coup ordinaire
(Parry : Rogue +5,6). Reste : Mage 5 points devant, Priest 4 points derrière. Détail, essais écartés :
`docs/zones/stranglethorn.md`, « Passe de difficulté ».

## Wetlands : passe de difficulté (14/11/2026)

Cible : 68 % de victoires en moyenne (± 2), écart entre classes ≤ 10 points (`runner=expedition key=0
zone=wetlands zones=2 level=7 bot=heuristic`, épique gagnée en route). Avant (800 expéditions) : Priest 78,2,
Warrior 76,8, Mage 64,9, Rogue 72,4, Hunter 70,6 ; moyenne 72,6, écart 13,3. Après (1 500) : Priest 72,7,
Warrior 69,8, Mage 63,3, Rogue 65,5, Hunter 66,7 ; **moyenne 67,6, écart 9,4**. PV perdus par combat normal
inchangés (Priest 9,2, Warrior 11,2, Mage 7,6, Rogue 8,0, Hunter 7,7). Un relevé des PV perdus par ennemi et par
intention a montré que le Mage perdait d'abord aux sbires du boss (Bonewarders, Whelps, Shadow Bolt) et à la
meute de raptors, que le Priest profitait de la durée de ses combats de boss (6,9 tours contre 4,9 au Mage) et
que Modr usait les classes lentes (Warrior, Priest, Rogue). Sbires et raptors adoucis, Clan Command à
Strength 3, Mortal Wound de 3 tours chez Nek'rosh et le Raider, Modr 110 PV et Stone Fist 15, Nek'rosh 84 PV.
Nombres, essais écartés et tableau par classe : `docs/zones/wetlands.md`, « Passe de difficulté ».

## Burning Steppes : passe de difficulté (14/11/2026)

Cible de la zone 6 : 55 % de victoires en moyenne, écart entre classes ≤ 10 points (`runner=expedition key=0
zone=steppes zones=5 level=7 bot=heuristic`, épique gagnée en route). Avant (800 expéditions) : Priest 62,0,
Warrior 82,2, Mage 79,2, Rogue 78,1, Hunter 87,1 % (moyenne 77,7, écart 25). Après (1 500) : Priest 51,3, Warrior
58,5, Mage 60,1, Rogue 52,4, Hunter 59,8 % (moyenne **56,4**, écart **8,8**). PV perdus par combat normal : 8,7 /
8,9 / 5,6 / 6,2 / 4,9 → 9,2 / 9,8 / 6,6 / 7,1 / 6,2. Deux causes d'écart : la brûlure du Wildfire, perte fixe
qui pèse en part des 36 PV du Priest et grandit avec ses combats plus longs (compte à rebours + 1 partout, première
brûlure 1 au lieu de 2, Ignite de Grark sous 30 % au lieu de 50 % : Priest + 11 à lui seul) ; les élites seules,
que le Hunter étourdit (98–99 % contre 85–95 % aux autres). La difficulté est donc portée par le boss, qui est
immunisé contre l'étourdissement : Grark 123 PV (84), gros coups en phase 1 (Cleave 23, Heroic Strike 26),
Strength 1 par Shield Block (2), Ember Worgs 5 PV et Bite 3 (ils coûtaient 6 points de boss au Priest) ; élites
et normaux un peu plus robustes. 85 % des défaites ont lieu au boss. Reste : Hunter à 98,5 % contre les élites,
Priest à 9,2 PV par combat normal (26 % de ses PV). Nombres, essais écartés et tableau par classe :
`docs/zones/steppes.md`, « Passe de difficulté ».
### Blackrock Mountain : Indomitable sur les élites (14/11/2026)

Décision du joueur : les élites de Blackrock Mountain sont immunisés à Stunned (trait « Indomitable »,
`Combat.stunImmune`). Effet brut : Hunter 54,1 → 31,9 (Freezing Trap ne protège plus des élites), Mage 46,5 →
39,8 ; moyenne 44,3, écart 20,9. Réglage par les nombres de la zone seulement : dégâts des élites environ −35 %
avec plus de PV, normaux +1 ou +2 aux coups, Nefarian 138 PV, Broken Bow −2 sur 1 tour, Wild Polymorph 1 tour,
plafond d'Invincible 8. Résultat (1 500 expéditions) : Priest 48,1 ; Warrior 52,5 ; Mage 47,5 ; Rogue 52,9 ;
Hunter 47,5 ; moyenne **49,7**, écart **5,4**. PV perdus par combat normal : 14,7 / 14,7 / 9,3 / 10,8 / 8,8.
Détail : `docs/zones/blackrock.md`, « Indomitable sur les élites ».

## Bot human : la difficulté ressentie (13/11/2026)

Toute la difficulté était réglée sur `bot=heuristic`, qui explore toutes les suites de cartes du tour et joue le
tour ennemi au bout de chacune : il ne fait aucune erreur tactique (≈ 70 % à Westfall clé 0, niveau 2) quand le
joueur, qui joue correctement, en gagne à peine une sur quatre (journal de sa sauvegarde : Rogue 1/5, Priest 2/8,
1/3 chacun à la clé 0 ; défaites au boss VanCleef, aux élites Rhahk'Zor et Harvest Golem des étapes 3 à 6, et à
des combats normaux avec un Riverpaw Mystic). Le bot `human` (`Sim/bots.lua`, `Bots.humanParams` ; hors combat
`humanDecide` de `Sim/expedition.lua`) joue comme un humain correct : il ne regarde que les 3 meilleurs coups au
coup d'œil et les suit sur 3 cartes ; il lit les intentions affichées au lieu de jouer le tour ennemi (ni DoT, ni
états, ni « Watch » du Mystic, ni invocation de VanCleef à 50 %), sauf 7 tours sur 10 où il réfléchit à fond ; il
compte mal le Combo laissé ; un coup sur quatre il joue un autre bon coup (à 6 PV près du meilleur ; jamais une
fin de tour) ; il garde ses potions ; hors combat, notes de cartes bruitées, goût des rares et des nouveautés
(deck de 14,5 cartes en fin, comme les 12 à 17 du joueur), route fixée d'avance, repos et amélioration au jugé, retrait au marchand une visite
sur deux. `skill=0..1` règle le tout (0 débutant ≈ 3–5 %, 0,5 défaut, 1 expert ≈ 68 % au Rogue, presque
`heuristic`) ; chaque paramètre s'impose aussi par son nom (`Bots.HUMAN_RANGE`).

Westfall clé 0 (`runner=expedition zone=westfall zones=0`, niveau 2, Priest niveau 3 comme la sauvegarde,
600 expéditions, graine 1, ± 3,5 ; élites Stun Resistant compris) :

| Classe | `human` | `heuristic` | `greedy` | défaites de `human` : normal / élite / boss |
|---|---|---|---|---|
| Rogue | **25,8** | 72,3 | 8,3 | 10 / 21 / 68 % |
| Priest | **27,2** | 72,5 | 3,8 | 3 / 8 / 89 % |
| Warrior | **23,3** | 66,7 | 0,8 | 5 / 18 / 77 % |
| Mage | **26,7** | 61,0 | 10,3 | 10 / 19 / 70 % |
| Hunter | **21,2** | 57,2 | 6,5 | 4 / 10 / 86 % |

Graine 2 (1 200) : Rogue 28,4, Priest 28,5. Clé +1 : Rogue 19,3, Priest 23,8 (`heuristic` 69,3 et 70,5). Les six
autres zones tournent (règles de zone, épiques ; 200 expéditions chacune à `zones=N-1 level=7` : 16 à 31 %). Son
jeu hors combat seul coûte peu (`bot=human fightbot=heuristic` : Rogue 70,7 au lieu de 72,3) : la différence vient
des combats ; sans le repos d'avant boss (+0,25 au seuil), il coûtait 12 points.

Où il perd, comparé au joueur : comme lui au boss d'abord, puis aux élites des étapes 3 à 6 et aux combats
normaux avec un Mystic (son « Watch » n'affiche pas de dégâts : 87–94 % de victoires contre ces groupes, 97–100 %
contre les autres ; trois des quatre défaites du joueur en combat normal). Mais le joueur perd à peu près autant
avant le boss qu'au boss (5 défaites sur 14 au boss, toutes classes et clés), le bot `human` 10 à 30 % avant le
boss selon la classe : les classes qui se soignent ou étourdissent (Priest, Hunter) arrivent presque toujours
entières au boss. Le journal est minuscule et mêle plusieurs équilibrages (Priest à 65 PV max avant le 12/11) :
les défaites du joueur aux élites ne se reproduisent qu'en partie.

Usage : `bot=human` est désormais la référence de la difficulté ressentie (une zone ou une clé « trop dure » se
juge avec lui) ; `bot=heuristic` reste l'instrument des comparaisons fines entre cartes, classes et zones (il est
inchangé : mêmes résultats à graine égale avant et après l'ajout).

