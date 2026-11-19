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

## Westfall réglée sur le bot human (14/11/2026)

Cible du joueur : 70 % de victoires avec `bot=human` à Westfall clé 0 (niveau 2, Priest niveau 3). Le mur était
l'appel de VanCleef à 50 % : deux sbires sans préavis, qui frappaient dès le tour ennemi en plus de lui. Devenu
une phase annoncée (cran sur la barre de vie, intention « To me, Brotherhood! » qui remplace son coup), il
suffisait à faire passer le boss d'environ 30 % à plus de 80 % avec les nombres d'origine. Watch du Riverpaw
Mystic est devenue un coup affiché (3, interrompt si le coup porte, pas deux fois de suite). Nombres : VanCleef
98 PV, Combo 10 × 2, Mortal Strike 22, sbires 10–12 PV ; Reap 7 × 3, Slam 17, Punch 11 ; Bite 7, Rend 4 ; Mystic
14–16 PV, Heal 5, Shock 4 ; Fireball 12. Résultat (3 000 expéditions, graine 1) : Rogue 67,2 ; Priest 75,0 ;
Warrior 73,8 ; Mage 70,4 ; Hunter 69,5 ; moyenne **71,2** (24,8 avant), écart **7,8** ; graine 2 : 71,9 ;
niveau 1 : 69,9 ; niveau 7 : 77,4. `heuristic` : 95,4 de moyenne (écart 4,2). Part des défaites au boss : 59 à
92 % selon la classe (67 à 88 % avant) : le Priest et le Hunter arrivent presque entiers au boss. Détail :
`docs/zones/westfall.md`, « Réglage sur le bot human ».

## Burning Steppes : réglage sur le bot human (14/11/2026)

Cible de la zone 6 : 45 % de victoires en moyenne au bot `human` (`runner=expedition key=0 zone=steppes zones=5
level=7 bot=human`), écart ≤ 10. Avant (1 000 expéditions) : Priest 25,2, Warrior 27,8, Mage 31,1, Rogue 25,3,
Hunter 26,5 % (moyenne 27,2, écart 5,9 ; boss gagné 31 à 41 %). Après (3 000, graine 1) : 42,9 / 46,3 / 46,7 /
44,9 / 45,5 % (moyenne **45,3**, écart **3,8** ; graine 2 : 45,6 et 4,4). PV nets par combat normal : 3,1 / 11,0 /
6,9 / 8,4 / 6,9. Grark 116 PV (123), Cleave 20 (23), Heroic Strike 23 (26), phase 2 Torch 10, Mortal Strike 19,
Rend 6 + DoT 2 (DoT 3, que le joueur ne voit pas dans l'intention) ; Gruklash, élite piège du Warrior et du Rogue
(56–62 %), Pummel 11, Backhand 12, Mortal Strike 16 ; Worgs 19–21 PV, Bite 4 (+ 3 sur sol embrasé) et Sorcerer 6 /
6 (groupes de Worgs à 91–95 % pour le Rogue, le Mage et le Hunter) ; Volchan 94 PV ; Wildfire inchangé. Part des
défaites au boss : 57 à 59 % (Priest, Warrior, Rogue), mais 71 % (Mage) et 78 % (Hunter), qui passent les élites
par le contrôle ; durcir les élites coûtait deux à trois fois plus au Priest. Contrôle `heuristic` (800) : Priest 69,2, Warrior 77,4, Mage 74,5, Rogue 72,1, Hunter 66,0 % (moyenne 71,8, écart 11,4 ; élites 92 à 98 %, boss 68 à 83 %).
Détail et essais écartés : `docs/zones/steppes.md`, « Réglage sur le bot human ».

## Or et marchands sur sept zones (15/11/2026)

Une expédition traverse sept zones avec le même or, mais l'économie datait d'une zone par expédition : bot `human`, clé
0, 600 expéditions par classe, le Warrior gagnait 1 088 po par campagne et en laissait 536 (≈ 50 % du gagné au compte
neuf, 35–40 % tout débloqué), et l'étal entier devenait achetable à partir de Stranglethorn. Décision du joueur
(`docs/zones/decisions.md`) : prix plus hauts dans les zones hautes, avec plus de cartes déjà améliorées et plus rares.
Appliqué (`docs/expedition.md`, « Économie sur sept zones ») : prix × 1 à 2,2 selon le rang de la zone (épique comprise,
retrait non), 0 à 60 % de cartes vendues améliorées (× 1,25), part de cartes rares de l'étal × 1 à 2,8 et de bibelots
rares × 1 à 2,2 ; Westfall identique (tirages, prix, taux de victoire). Le bot hors combat juge les prix au niveau de la
zone, dépense le surplus et va au marchand quand sa bourse est pleine. Résultat (600 expéditions, avant → après) : or
inutilisé 49–54 → 23–29 % au compte neuf, 35–40 → 23–25 % tout débloqué, 19–22 % pour les victoires ; 2 à 3 articles
abordables par visite tout débloqué (3,6 à 4,4 au compte neuf, étals sans bibelots), l'étal entier jamais ; taux de
victoire inchangés à ± 4 points. Hors cible : 18 à 25 points du gagné tombent après le dernier marchand visité (≈ 0,6
marchand par zone), ce que les prix ne changent pas ; pistes (marchand entre deux zones, pas d'or sur Nefarian) dans
`docs/expedition.md`.

## Rogue : paliers +2 et +3 des cartes (15/11/2026)

Les 35 cartes du Voleur et ses 7 épiques ont un palier 2 et un palier 3 écrits à la main (tableau :
`docs/classes/rogue.md`, § 11). Paliers **non mesurés carte par carte** : les balayages `sweep=cards up=2/3` ont été
abandonnés (consigne du coordinateur : trop coûteux à six classes en parallèle). Campagne, bot `human`, clé 0,
`zones=7 level=7`, 600 expéditions, avant → après : victoires 63,2 → 62,8 % (± 3,9, inchangé) ; améliorations par
expédition +1 3,44 → 3,33, +2 0 → 0,14, +3 0 → 0 (le bot monte d'abord de nouvelles cartes au +1 : les paliers 2 et
3 comptent peu pour lui). Écart « vict. avec / sans » des cartes : aucun saut hors du bruit (Nightblade +8, Crippling
Poison +5, le reste à ± 4 points). Compte neuf avant (`zones=0 level=1`) : 21,3 %. À surveiller quand les paliers
seront mesurés : Killing Spree +2 (coût 2 → 1), Adrenaline Rush +3 (+3 mana, Draw 3), Echoing Reprimand +3
(Animacharge 6), Danse Macabre +3 (Flourish 5, multiplié par coup), Kidney Shot +2/+3 (Combo rendus), Shadow Dance
+3 (+1 Combo par tour), Premeditation +3 (carte à 0, +3 Combo sous Stealth).
## Paliers +2 et +3 du Guerrier (15/11/2026)

Décision du joueur (`docs/zones/decisions.md`, « Améliorer une carte plusieurs fois ») : paliers 2 et 3 écrits à la
main pour les 34 cartes et les sept épiques du Guerrier (tableau : `docs/classes/warrior-paliers.md`). Classe déjà la
plus forte : gains dans le bas de la fourchette, rien de multiplié sur Strength, la Rage ou les cartes à plusieurs
coups (Rampage paie moins de PV, Battle Shout et Recklessness passent à 0 ou Innate, Powers à 0 puis Innate) ; épiques :
nombres par palier dans `ns.Warrior.EPIC`, ou une ligne « Kills: ». Paliers non mesurés carte par carte (balayages
abandonnés sur consigne). Campagne bot `human`, clé 0, `zones=7 level=7`, 600 expéditions : 86,2 → 85,8 % ; le bot
n'atteint le palier 2 que 0,08 fois par expédition (le palier 3 jamais), l'effet en campagne reste donc nul à ce jour.
## Hunter : paliers +2 et +3 (15/11/2026)

Les 50 cartes du Hunter (34 de classe, 7 épiques, 9 variantes de Lone Wolf) ont leurs paliers 2 et 3, écrits carte
par carte (`docs/classes/hunter.md`, « Paliers d'amélioration +2 et +3 »). Les cartes qui étourdissent gagnent ce qui
vaut contre Stun Resistant et Indomitable (Sundered, Demoralized, DoT, attaques du familier), sans toucher à Stunned.
Campagne au bot `human` (600 expéditions, clé 0, `zones=7 level=7`) : 70,7 → **71,2 %** (± 3,6), combats par type
inchangés à 0,1 point près ; améliorations par expédition +1 3,83 → 3,70, **+2 0,13**, +3 0 : le bot préfère encore
le palier 1 d'une autre carte (notes × 0,8 puis × 0,6), les paliers 2 et 3 pèsent donc peu sur la campagne. Écarts
« vict. avec / sans » des cartes et parts jouées : identiques à ± 2 points. Compte neuf avant : 18,2 % (non remesuré).
**Paliers non mesurés carte par carte** : balayages `sweep=cards` abandonnés sur consigne (coût) ; un balayage
partiel `up=2` au bot `human` (200 par ligne, ± 7 points, carte forcée à +2 contre le deck sans elle, donc la valeur
de la carte plus que celle du palier) ne montrait aucun palier hors norme ; les Powers Survival forcées (Lock and
Load, Resourcefulness, Entrapment) y restent négatives, comme leur carte de base.
## Paliers +2 et +3 des cartes neutres et des cartes de zone (15/11/2026)

Les 22 cartes neutres (dix de `Data/Neutral.lua`, deux par zone) ont leurs paliers 2 et 3, écrits dans le bas de la
fourchette (tableau et règles : `docs/cartes-neutres.md`, « Paliers +2 et +3 ») : Retain, Innate, coût ou prix en PV
assoupli, ou un nombre ; jamais de pioche ni de mana en plus, jamais plus de Stunned, Exhaust toujours là. Les sept
cartes de combat posées par les zones (Curses, Hexed, Morbent's Bane) restent sans palier 2 : jamais dans le deck.

**Non mesurées carte par carte** : les balayages `sweep=cards up=1/2/3` ont été arrêtés sur consigne (coût en
campagnes, machine partagée). Seul repère : le balayage `up=1` du Warrior (bot `human`, 200 expéditions par ligne,
± 7 points, base 80,5 %) place déjà au palier 1 les soins en tête (Dreamless Sleep Potion +17,5, Crocolisk Gumbo +16,
Heavy Silk Bandage +13,5, Dark Iron Bomb +13,5, Black Lotus +12,5) et Goblin Sapper Charge, Arcane Bomb, Elixir à 0
ou dessous. Les paliers 2 et 3 des trois soins restent petits (Heal +2, puis Regen 2, Retain ou coût 0) ; à
surveiller pour le Warrior, qui n'a pas d'autre soin.

Campagne Mage (bot `human`, clé 0, `zones=7 level=7`, 600 expéditions, graine 1), avant → après : **74,8 → 74,8 %**,
rapport identique ligne pour ligne. « Améliorations par palier » : +1 4,06, +2 0,00, +3 0,00 avant et après : le bot
`human` du Mage n'a une carte neutre dans son deck final que dans 1 à 3 expéditions sur 600 et ne l'améliore jamais
deux fois ; les paliers neutres n'ont donc aucun effet mesurable sur la campagne tant que les cartes de classe n'ont
pas leurs propres paliers 2 et 3 (le bot répartit ses quatre améliorations sur des cartes différentes).

## Paliers +2 et +3 du Mage (15/11/2026)

Les 34 cartes et les 7 épiques du Mage ont leurs paliers 2 et 3 écrits à la main (tableau : `docs/classes/mage.md`, § 8 ;
règles : `docs/ameliorations.md`). Campagne complète, bot `human`, clé 0, tout débloqué, 600 expéditions : victoires
74,8 % → 74,8 % ; améliorations par expédition 4,06 → 4,04, dont +1 3,90, +2 0,14, +3 0,00 (le bot préfère presque
toujours une nouvelle carte au +1) ; aucun écart anormal dans le tableau des cartes (« vict. sans » à ± 6 points). Les
paliers **n'ont pas été mesurés carte par carte** (balayages arrêtés sur consigne) : un balayage partiel au bot
`human` (11 cartes, `up=1` à 300 expéditions contre `up=3` à 200, ± 9 points sur l'écart) a fait adoucir les paliers
3 nettement au-dessus du +1 : Glacial Spike et Blizzard (+16 / +18 points avec +2 chiffré puis sans Cast → +2 Retain,
+3 sans Cast), Arcane Explosion+3 à 0 mana (+18 → Retain), Mana Shield+3 +1 Charge (+14 → Retain), Arcane Blast+3
+2 Charge (→ Deal 13), Fireball+2 17 → 16. Après retouche, Arcane Blast+3 et Mana Shield+3 restaient hauts au
balayage (78 et 81 % contre 67 et 70 % au +1) : une carte imposée au +3 vaut deux améliorations gratuites ; à
surveiller quand le bot montera plus souvent au +2. Ice Block+3 (Innate), Combustion+3, Presence of Mind+3 et Fire
Blast+3 : écart sous le gain du +1.

## Priest : paliers +2 et +3 (15/11/2026)

Les 41 cartes du Priest ont leurs paliers 2 et 3 écrits à la main (tableau : `docs/classes/priest-progression.md`,
« Paliers +2 et +3 »). Soins et boucliers ne montent presque plus après le +1 (le Priest perd déjà peu de PV) ;
les paliers vont au tempo (coût, Retain, Innate, pioche), à l'Atonement et à l'Insanity ; épiques : tables
`{ base, +1, +2, +3 }` lues par `Card.level`. Campagne au bot human (`runs=600 key=0 zones=7 level=7`) :
**65,0 % → 64,2 %** (± 3,8, aucun écart), PV perdus par type de combat inchangés à 0,2 près ; améliorations par
expédition +1 4,96 → 4,87, **+2 0,14, +3 0,00** : le bot améliore d'abord les cartes neuves d'un deck de
≈ 41 cartes (≈ 5 améliorations par expédition), les paliers 2 et 3 ne pèsent presque pas sur la mesure. Écarts
« vict. avec / sans » du tableau des cartes identiques à ± 4 points à ceux d'avant. **Paliers non mesurés
carte par carte** : balayages `sweep=cards` abandonnés (coût ≈ 25 000 campagnes par classe ; décision du
coordinateur), seul un début de `up=1` au bot human a tourné (18 cartes, `reports/priest-sweep-up1.txt`).
À surveiller en jeu : Shadow Covenant+3 (deux cartes Shadow gratuites par tour, gain ≈ 1,5 fois celui du +1),
Inner Focus+2/+3 (multiplicateur), Misery+2/+3 (+ 1 par copie, autant que le +1), Rapture+3 et Renew+3
(Innate), les paliers « Retain » (le bot n'en tire presque rien).

## Bot human : améliorer plusieurs fois (16/11/2026)

Demande du joueur : faire monter ses cartes au bot `human` (il n'atteignait le +2 que 0,1 fois par expédition) et
voir ce que donnent les paliers +2 et +3. Paramètre `upfocus=0..1` (`Sim/expedition.lua`, `humanUpgrade`) :
**0** (défaut) étale comme avant (note du palier visé × 0,8 puis × 0,6 : une carte neuve passe devant) ; **1**
concentre : l'épique du deck d'abord (jouée à chaque combat), puis la carte déjà la plus montée, puis la meilleure note
sans la décote des paliers, donc ses meilleures cartes jusqu'à +3 avant d'en améliorer d'autres ; entre les deux,
chaque choix concentre avec la chance `upfocus` (un tirage de plus). Même règle au feu de camp et dans les rencontres
« Upgrade » ; aucune zone ne déclare encore d'action de feu de camp (le cas où le bot `human` s'en remet au bot de
référence). `upfocus=0` donne le rapport de main ligne pour ligne (hors lignes ajoutées ; 300 expéditions Warrior et
Priest, `jobs=8`, comparées à 15eea91 puis à bb9e071). Rapport : « Feu de camp » (repos / amélioration), « Cartes
montées le plus haut » (top 10 des cartes finies à +2/+3) et colonnes « palier moy », « vict. à +2/+3 » du tableau
des cartes. Rapports bruts : `reports/upfocus/` (`z7_*`, `z0_*`, `t_*` : 600 ; `c3k_*` : 3 000).

Tout débloqué (`key=0 zones=7 level=7`, 600 expéditions, ± 2,7 à 3,9 ; améliorations +1 / +2 / +3 par expédition ;
dernière colonne : 3 000 expéditions, ± 1,2 à 1,7, mêmes graines) :

| Classe | `upfocus=0` | | `0.5` | | `1` | | 3 000 : 0 → 1 |
|---|---|---|---|---|---|---|---|
| Warrior | 85,8 | 4,60 / 0,08 / 0 | 86,5 | 3,41 / 0,89 / 0,39 | 86,3 | 1,95 / 1,63 / 1,22 | 87,0 → 87,1 |
| Mage | 74,8 | 3,90 / 0,14 / 0 | 74,3 | 3,00 / 0,72 / 0,31 | 76,3 | 1,69 / 1,40 / 1,05 | 76,2 → 76,4 |
| Hunter | 71,2 | 3,69 / 0,14 / 0 | 70,5 | 2,80 / 0,64 / 0,29 | 72,5 | 1,67 / 1,31 / 0,95 | 73,6 → 74,6 |
| Priest | 64,2 | 4,87 / 0,14 / 0 | 67,8 | 3,53 / 1,03 / 0,49 | 67,5 | 2,10 / 1,65 / 1,28 | **64,6 → 68,2** |
| Rogue | 62,8 | 3,33 / 0,14 / 0 | 62,2 | 2,49 / 0,61 / 0,28 | 62,0 | 1,41 / 1,15 / 0,85 | 61,7 → 62,1 |

Compte neuf (`zones=0 level=2`, sans épique, 600) : Warrior 63,7 → 63,7 ; Priest 43,0 → 43,5 ; Mage 34,7 → 33,3 ;
Hunter 26,5 → 26,0 ; Rogue 25,3 → 24,7 % (`upfocus=0` → `1` ; améliorations +1/+2/+3 de 3,23/0,08/0 → 1,18/1,21/0,92
au Warrior, 1,81/0,05/0 → 0,83/0,61/0,39 au Rogue : moitié moins de feux choisis pour améliorer qu'avec tout débloqué).

Par zone (battue / atteinte), `0` → `1` : identique à ± 1,5 point partout, **Westfall comprise** (Warrior, Mage, Hunter, Priest, Rogue : 90,8 / 85,4 / 84,4 /
83,1 / 78,4 % tout débloqué, 3 000 ; 71,7 / 68,7 / 68,7 / 75,2 / 67,5 % au compte neuf), sauf le Priest à Blackrock
Mountain (92,4 → 95,2 %, 3 000) et Duskwood à Hunter Lone Wolf (89,9 → 91,6). C'est Westfall qui fait l'écart entre
classes (9 à 22 % de défaites sur 13 à 38 % au total), et on y arrive au boss avec 0 à 2 améliorations : la
politique ne peut rien y changer. Feu de camp : part des feux choisis pour améliorer identique dans les deux modes
(Warrior 69,7 / 70,5 %, Mage 65,1 / 65,2, Hunter 63,4 / 65,4, Priest 83,5 / 84,4, Rogue 64,0 / 64,4 ; compte neuf
39 à 80 %, ± 1) : le seuil de repos ne bouge pas ; il ne monte qu'avec les PV quand la politique rend le deck plus
fort (Lone Wolf imposée 59,5 → 67,3 %, Mage Arcane Blast+3 imposée 66,5 → 70,2 %).

Cartes montées le plus haut (`upfocus=1`, 3 000 ; expéditions finies à +2/+3) : les épiques d'abord (palier moyen
2,3 à 2,9 quand elles sont au deck), puis une carte de classe par deck : Warrior Bloodthirst (425 ; +2 Deal 10, +3
Heal 5), Mage Presence of Mind (589 ; +2 Retain, +3 +2 Charge), Priest Solace (482 ; +2 Atonement 2, +3 Deal 8) et
Angelic Feather (376 ; +2 Atonement 1), Rogue Blade Flurry (458 ; +2 coût 0, +3 4 à tous), Hunter The Beast Within
(549 ; +2 Innate, +3 +2 Frenzy) et Dire Beast (509 ; +2 +1 Frenzy, +3 Retain). Les colonnes « vict. à +2/+3 contre
+0/+1 » du rapport (+3 à +100 points) mesurent surtout la survie : une carte finit haut parce que l'expédition a duré.
Mesure moins biaisée, victoires des expéditions qui finissent avec l'épique, `0` → `1` (même graine, 300 à 770 par
épique, ± 5) : **Shadow Covenant 51,5 → 69,7** et Echo of Light 39,5 → 58,1 (62 expéditions) au Priest, **Lone Wolf
78,2 → 82,6** au Hunter, Echoing Reprimand +3,2 et Doomblade +2,0 au Rogue ; toutes les autres épiques des cinq
classes à ± 2 points (Warrior et Mage : aucune épique ne gagne à monter, alors qu'elles finissent à +2,4 à +2,9).

Mesures ciblées (tout débloqué ; 600 sauf mention) :
- Warrior, Sweeping Strikes imposée : 91,8 % (`upfocus=0`, épique améliorée dans 7 % des expéditions) → 91,5 %
  (`1`, 93 %) : ses +2/+3 (Sweep sur toutes les attaques, Rage au kill) ne rapportent rien de mesurable.
- Hunter, Lone Wolf imposée : 66,2 → 72,0 % (3 000 : **68,0 → 75,1**, épique améliorée 0,6 → 79 %) : le seul gain net
  de la politique ; Lone Wolf au +0 est sous les autres épiques du Hunter (87 à 93 % « avec ») et le reste au +3 (83 %).
- Mage, carte de départ en plus imposée, 3 000 (base 76,2) : Arcane Blast +0 76,4, +1 81,8, +2 85,1, **+3 88,2** ;
  Mana Shield +0 74,8, +1 84,3, +2 87,4, **+3 90,0**. Gain par palier : +5,4 / +3,3 / +3,1 et +9,5 / +3,1 / +2,6 :
  chaque palier rapporte moins que le +1, comme le veut la règle ; +3 contre +1 : +6,4 et +5,7, deux améliorations
  gratuites dès Westfall (où se joue l'expédition) ; la copie au +0 ne rapporte rien (Arcane Blast est la carte
  que le bot retire en premier : absente du deck final dans 29 % des expéditions de base).

Conclusions : concentrer ses améliorations ne vaut ni plus ni moins que les étaler pour le Warrior, le Mage et le
Rogue (± 0,5 à 3 000), un peu mieux pour le Hunter (+1,0), nettement mieux pour le Priest (+3,6, Shadow Covenant) et
pour Lone Wolf (+7,1). L'écart entre classes ne bouge presque pas (Warrior 87, Mage 76, Hunter 75, Priest 68, Rogue
62 % ; compte neuf inchangé) : il se fait à Westfall, avant toute amélioration. Paliers à revoir : aucun « trop
fort » en campagne ; les +2/+3 de Shadow Covenant et de Lone Wolf réparent une épique faible au +0 ; les épiques du
Warrior et du Mage montées à +3 ne changent rien (paliers inutiles pour ce bot, ou épiques déjà au plafond).

## Druid : premier réglage (18/11/2026)

Classe codée le 18/11/2026 (`docs/classes/druid.md`). Mesure : `luajit Sim/sim.lua runs=300 bot=heuristic seed=1
jobs=8 runner=expedition key=0 class=<classe>` (niveau 7, `zones=0`, sans épique imposée ; ± 2 à 4 points).
Aucun chiffre comparable récent n'existait pour les autres classes : elles ont été remesurées au même réglage
(une série chacune). Rapports bruts : `reports/druid-tax/`.

| Classe / réglage | Victoires | Normal : PV perdus / tours | Élite : PV / tours | Boss : PV / tours |
|---|---|---|---|---|
| Priest (36 PV) | 86,7 % | 6,2 / 3,53 | 9,6 / 4,97 | 18,8 / 6,46 |
| Warrior (74) | 96,7 % | 4,9 / 2,26 | 10,6 / 3,40 | 15,1 / 4,00 |
| Mage (42) | 93,0 % | 2,0 / 2,43 | 5,2 / 3,41 | 14,1 / 4,29 |
| Rogue (50) | 88,0 % | 3,2 / 2,20 | 7,5 / 3,15 | 12,8 / 3,82 |
| Hunter (50) | 81,7 % | 2,9 / 2,16 | 8,0 / 3,22 | 19,0 / 4,01 |
| Druid (a) : sans taxe, 65 PV, Regen 1 | 99,7 % | 3,1 / 2,27 | 8,1 / 3,48 | 17,7 / 4,45 |
| Druid (b) : taxe dès le 2e changement | 95,7 % | 4,2 / 2,41 | 11,0 / 3,86 | 26,8 / 5,15 |
| Druid (c) : taxe dès le 3e changement | 99,3 % | 3,5 / 2,32 | 9,2 / 3,64 | 21,5 / 4,76 |
| **Druid retenu : (b) + 58 PV + Regen 2 en Tree** | **91,0 %** | 4,5 / 2,41 | 11,7 / 3,92 | 28,0 / 5,20 |
| Druid, essai : (b) + 58 PV + Regen 3 | 92,7 % | 4,4 / 2,41 | 11,7 / 3,90 | 28,5 / 5,21 |

Druid, changements de forme par tour et fins de tour (Bear / Cat / Moonkin / Tree) : (a) 3,59, 43,7 / 16,5 / 37,2 /
2,5 % ; (b) 2,69, 39,3 / 17,2 / 39,4 / 4,0 % (0,8 mana perdu par tour) ; (c) 2,86, 39,9 / 17,5 / 39,4 / 3,2 % ;
retenu 2,69, 38,2 / 16,7 / 38,2 / 6,8 %.

- **Fourchette des cinq classes au niveau 7** : 81,7 à 96,7 % (moyenne 89,2), 2,0 à 6,2 PV perdus par combat normal
  (la cible de 6 à 9, posée au niveau 1 compte neuf, n'est tenue qu'au niveau 1), 2,16 à 3,53 tours. Le Druid de
  départ n'en sortait que par les victoires.
- **Levier A** (taxe des changements de forme, `Druid.TAX`, `Druid.TAX_FREE`) : dès le 3e changement il ne change
  rien (−0,4 point, le bot évite simplement le 3e) ; dès le 2e (« plus d'une fois », la règle du joueur) −4,0
  points. Seuil retenu : dès le 2e.
- **Balayage** (`sweep=cards class=druid runs=300` au réglage (b)) : aucune carte n'explique la force, de −6,3
  (Mangle, Hurricane) à +3,0 (Tranquility) ; Starfall −1,0 (le +33 du rapport d'expédition est un biais de survie).
  Le reste du réglage porte donc sur le socle : 65 → 58 PV (−4,7 points avec la Regen 2) ; Regen de fin de tour en
  Tree of Life 1 → 2 pour la forme la moins jouée (2,5 → 6,8 % des fins de tour, sous les 10 % visés : deck de
  départ sans carte Tree, question ouverte de la fiche, § 11).
- Non vérifié : bot `human`, niveau 1 (compte neuf), clés 1 à 5, épiques du Druid (pas encore codées).

## Druid : réglage au bot human (18/11/2026)

Le Druid réglé au bot `heuristic` (91,0 %, section précédente) était dernier au bot `human`, la référence de la
difficulté ressentie. Mesure : `luajit Sim/sim.lua runs=600 bot=human seed=1 jobs=8 runner=expedition key=0
class=druid` (clé 0, niveau 7, `zones=0`, ± 4 points) ; cible : 50 à 60 %. Autres classes au même réglage, avant
leurs propres réglages du jour : Warrior 80,0, Mage 60,7, Priest 53,5, Hunter 47,7, Rogue 38,5 %. Leviers prévus,
dans l'ordre et cumulés jusqu'à la cible : (1) PV 58 → 65, (2) entrée dans la première forme du combat hors taxe,
(3) deck de départ resserré sur deux formes. Rapports bruts : `reports/druid-human/`.

| Réglage | Victoires | Westfall battue | VanCleef | Normal : PV perdus / tours | Élite : PV / tours | Boss : PV / tours | Changements par tour | Fins de tour Bear / Cat / Moonkin / Tree |
|---|---|---|---|---|---|---|---|---|
| départ : 58 PV (référence rejouée, identique) | 37,0 % | 58,0 % | 64,7 % | 11,8 / 3,07 | 22,8 / 4,96 | 47,3 / 6,40 | 2,28 | 38,0 / 17,1 / 33,0 / 11,9 % |
| **(1) 65 PV, retenu** | **51,8 %** | **71,2 %** | 75,0 % | 11,9 / 3,08 | 22,6 / 4,95 | 48,7 / 6,54 | 2,31 | 36,9 / 17,1 / 33,4 / 12,5 % |
| vérification heuristic (300), 65 PV | 95,7 % (± 2,3) | 98,3 % | | 4,3 / 2,40 | 11,5 / 3,90 | 27,5 / 5,23 | 2,70 | 38,5 / 16,6 / 38,2 / 6,7 % |

- **Les PV seuls suffisent** : +14,8 points, presque tout à Westfall (défaites à Westfall 252 → 173 sur 600 ;
  VanCleef battu 64,7 → 75,0 % des fois). Les zones suivantes gagnent aussi 3 à 5 points (Duskwood battue/atteinte
  83,9 → 87,8 %, Wetlands 82,2 → 86,9 %). Leviers (2) et (3) non appliqués.
- **Bot heuristic** : 91,0 → 95,7 %, sous le plafond de 97 % ; il retrouve le niveau de la taxe seule à 65 PV
  (95,7 %, section précédente). La Regen 2 en Tree of Life et la taxe dès le deuxième changement restent.
- **Formes** : le bot human change 2,31 fois de forme par tour (heuristic 2,70) et finit plus souvent en Tree of
  Life (12,5 %, heuristic 6,7 %) : il soigne davantage.
- Non vérifié : niveau 1 (compte neuf), clés 1 à 5, épiques du Druid imposées.

## Hunter : réglage au bot human (18/11/2026)

Demande : monter le Hunter, dernier au bot `human` derrière Warrior, Mage et Priest. Cible : 55 à 62 %. Mesure :
`luajit Sim/sim.lua runs=600 bot=human seed=1 jobs=8 runner=expedition key=0 class=hunter` (niveau 7, `zones=0`,
sans épique imposée ; ± 4 points), contrôle `bot=heuristic runs=300` (plafond 95 %). Rapports bruts :
`reports/hunter-*.txt`.

**D'où venait l'usure.** Les combats ordinaires ne coûtent presque rien au Hunter (normal : 5,1 PV encaissés,
4,0 nets, 7 % de ses PV ; élite : 9,1 nets, 98,5 % de victoires) ; **ses défaites viennent du boss de chaque
zone** (241 des 314 défaites). Le boss lui coûte 24 PV encaissés, 21 nets, soit 39 % de ses PV à l'entrée, et il
y entre vers 78 % de ses PV : VanCleef 83,7 %, Somnus 88,5 %, Jin'do 90,4 %, Nek'rosh 92,4 %, Morbent Fel 93,7 %
de victoires. Les boss sont immunisés à Stunned : Freezing Trap n'y pose que Demoralized 1, et le reste de sa
défense est l'Absorb de Disengage (3, le plus faible des Absorb de départ : Defend et Mana Shield 5, Inner Fire 6).
Aucun soin. Le deck ne monte pas plus vite qu'ailleurs (2,8 améliorations par expédition, presque toutes +1). La
règle du Swamp ne pénalise pas le familier au-delà de ce qui est prévu : il évite les dormeurs tant qu'un ennemi
est éveillé et attend si tous dorment (`Swamp.PET_WAITS`, 14/11/2026) ; Somnus (140 PV) reste le boss le plus dur
pour le Hunter.

**Balayage** (`sweep=cards class=hunter runs=300 bot=human`, ligne « sans » 47,3 %, boss 24,0 PV encaissés) :
aucune carte de classe ne règle le boss (de 22,3 à 25,7 PV encaissés au boss ; au mieux Spirit Bond −1,7). Les
épiques montent beaucoup (Roar of Sacrifice +24,7, Master Marksman +23,0, Trap Launcher +22,3, Call of the Wild
+11,7), mais aucune n'est gagnée à la clé 0 avec `zones=0` (épique à l'entrée : 0 %). Cartes qui coûtent le plus au
bot human, imposées au départ : Resourcefulness −23,3, Feign Death −19,3, Immolation Trap −17,7, Lock and Load
−14,0, Volley −12,3 (Feign Death est pourtant la carte la plus choisie : 1 419 choix pour 600 expéditions) ; en
tête : Dire Beast +8,3, Growl +4,0, Kill Command +3,0. Non retouchées : hors du périmètre de ce lot.

**Changement retenu : PV 50 → 56**, seul. Le levier vise directement l'usure : 6 PV de plus à l'entrée de
Westfall, 3 de plus après chaque soin de 50 %, et une marge au boss. Disengage, `PET_BASE`, Pet Whistle et les
textes des cartes sont inchangés.

| Zone (battue / atteinte) | Avant, 50 PV (human) | **Après, 56 PV (human)** | Après, 56 PV (heuristic, 300) |
|---|---|---|---|
| Westfall | 79,3 % | **86,7 %** | 98,7 % |
| Duskwood | 87,6 % | **90,6 %** | 99,0 % |
| Wetlands | 90,9 % | **95,1 %** | 99,7 % |
| Stranglethorn Vale | 89,7 % | **94,0 %** | 100,0 % |
| Swamp of Sorrows | 88,2 % | **87,2 %** | 91,8 % |
| Burning Steppes | 99,7 % | **100,0 %** | 99,6 % |
| Blackrock Mountain | 95,7 % | **97,0 %** | 98,5 % |
| **Victoires** | **47,7 %** | **59,3 %** (± 3,9) | **87,7 %** (81,7 avant) |
| PV à l'entrée, Duskwood → Swamp | 37,1 / 42,3 / 42,7 / 41,4 | 42,5 / 48,8 / 49,4 / 48,5 | 49,1 / 54,9 / 54,9 / 50,8 |
| Boss : victoires / PV encaissés / nets | 91,2 % / 23,9 / 21,2 | 93,9 % / 24,4 / 22,1 | 98,3 % / 19,2 / 17,6 |
| Normal : PV encaissés / tours | 5,1 / 2,36 | 5,1 / 2,35 | 2,7 / 2,15 |

- **Cible atteinte** : 59,3 % au bot human (55 à 62 visés), 87,7 % au bot heuristic (sous les 95 %). Le Hunter
  passe devant le Priest (53,5) et reste derrière le Mage (60,7) et le Warrior (80,0) des mesures du 18/11/2026.
- **Ce qui reste** : Swamp of Sorrows ne bouge pas (88,2 → 87,2 %, 48 des 244 défaites au boss Somnus) ; c'est le
  seul mur du Hunter au bot heuristic (24 des 37 défaites). Un réglage de Somnus ou de la règle du sommeil est
  affaire de zone, hors de ce lot. VanCleef reste le boss qui coûte le plus d'expéditions (67 défaites).
- **Essai non fait** : Disengage 3 → 4 Absorb (le levier suivant si le Swamp doit monter) ; les PV seuls
  suffisaient.
- Non vérifié : niveau 1 (compte neuf), clés 1 à 5, cible de 6 à 9 PV par combat normal au niveau 1 (les PV
  encaissés par combat ne bougent pas avec les PV max ; leur part tombe de 7,4 à 6,6 % des PV à l'entrée).

## Rogue : réglage au bot human (18/11/2026)

Demande du joueur : monter le Rogue, le plus bas des classes au bot `human` avec le Druid. Cible : 52 à 60 % au bot
`human` (`luajit Sim/sim.lua runs=600 bot=human seed=1 jobs=8 runner=expedition key=0 class=rogue`, niveau 7,
`zones=0`, ± 4), le bot `heuristic` (300 expéditions, graine 1) sous 95 %. Rapports bruts : `reports/rogue-h-*`,
`reports/rogue-heur-57.*` (non versionnés).

**Où il perdait** (50 PV) : 197 défaites sur 600 à Westfall (121 contre VanCleef, 48 à l'étape 6, 20 à l'étape 5),
86 à Duskwood (38 contre Morbent Fel). Westfall seule (`zone=westfall`) : 8,6 PV perdus par combat normal (16,5 % des
PV max), 16,5 par élite (30 %), 23,1 au boss (40 %) ; VanCleef 76,7 %, Harvest Golem 89,4 %, Rhahk'Zor 94,3 % ; les
victoires finissent la zone à 16,8 PV. Le bot `human` ne rate pas une mécanique précise : il encaisse 1,5 à 1,8 fois
les PV du bot `heuristic` sur toute la campagne (normal 5,9 contre 3,2, élite 10,8 contre 7,5, boss 19,7 contre
12,8) et tue en 20 % de tours de plus (2,6 / 3,7 / 4,5 contre 2,2 / 3,15 / 3,8). Sans soin, cette usure s'additionne
d'un combat à l'autre jusqu'au boss. Le Combo compté à 60 % par le bot `human` coûte peu (≈ 0,3 PV par point laissé
au jugé) ; Eviscerate reste en main 31 % des fois où elle est piochée, Feint est jouée 62 % des fois.

**Balayage** (`sweep=cards class=rogue runs=300 bot=human`, carte ajoutée au deck de départ, 38,0 % sans) : gains
Adrenaline Rush +18,3, Ambush +17,0, Smoke Bomb +13,7, Cheap Shot +13,3, Between the Eyes +13,0, Evasion +12,3,
Killing Spree +12,3, Pistol Shot +9,3 ; pertes Shadow Dance −15,7, Cheat Death −14,3, Exsanguinate −8,3, Venomous
Wounds −7,3, Deadly Poison −6,0, Envenom −4,0, Nightblade −3,0, Rupture −2,7, Slice and Dice −2,7. Le joueur moyen
profite des cartes à 0 et des coups immédiats, perd du temps sur les Powers payants et les Surge de DoT, que ses
notes lui font pourtant prendre le plus (sur 600 expéditions : Rupture choisie 951 fois, Blade Flurry 916, Deadly
Poison 840, Envenom 828). Ni les cartes ni les notes ne sont touchées : à garder en tête pour un réglage des voies.

**Levier retenu : PV 50 → 57**, seul changement. Les PV sont le levier de tolérance : ils absorbent les erreurs
sans rien changer à la vitesse de tuer, là où un bonus de dégâts accélérerait d'abord le bot parfait. Effet (bot
`human`, `hp=N` puis valeur écrite) : environ 2,7 points par PV.

| Mesure (clé 0, niveau 7, graine 1) | 50 PV (avant) | 55 (`hp=`) | 56 | **57 (retenu)** | 58 (`hp=`) |
|---|---|---|---|---|---|
| `human`, 600 expéditions | 38,5 % | 53,0 % | 53,8 % | **57,2 %** | 60,0 % |
| Westfall battue (`human`) | 67,2 % | 77,8 % | 78,7 % | **80,7 %** | 83,0 % |
| Duskwood battue quand atteinte (`human`) | 78,7 % | 82,4 % | 82,2 % | **85,3 %** | 86,7 % |
| VanCleef / Morbent Fel (`human`) | 76,9 / 89,3 % | 85,1 / 90,0 % | 85,2 / 89,8 % | **86,3 / 92,0 %** | 88,0 / 93,3 % |
| `heuristic`, 300 expéditions | 88,0 % | – | – | **93,3 %** (± 2,8) | – |

À 57 PV, bot `human` : 5,7 PV perdus par combat normal, 10,3 par élite, 19,9 au boss (7,5 / 14,3 / 28,1 % des PV max
à l'entrée) ; bot `heuristic` : 3,1 / 7,3 / 12,8, Westfall battue 97,3 %. Parry, Stealth, cartes, deck et bibelot de
départ inchangés.

- Non vérifié : graine 2, niveau 1 (compte neuf), clés 1 à 5, voies seules, épiques dans les zones dures (mesurées
  à 50 PV le 14/11/2026, `docs/zones/cartes-de-zone.md`) ; le bot `human` des autres classes n'a pas été remesuré.

## Warrior : réglage au bot human (18/11/2026)

Demande du joueur : « nerfer un peu » le Warrior, le plus facile au bot `human`. Cible : 62 à 68 % au bot `human`
(`luajit Sim/sim.lua runs=600 bot=human seed=1 jobs=8 runner=expedition key=0 class=warrior`, niveau 7, `zones=0`,
± 3,7 points), sans faire passer Westfall battue sous celle du Mage. Rapports bruts : `reports/w-*.txt` du worktree.

**D'où venait l'avance.** Référence au même réglage : Warrior 80,0 % (Westfall battue 85,2 %), Mage 60,7 % (76,7),
Priest 53,5 % (77,5). Deux sources : Westfall (8 points de mieux que le Mage et le Priest) et une campagne presque
sans perte après Duskwood (battue / atteinte ≥ 99,4 % dans chaque zone dès Wetlands ; 94 % des Warriors qui battent
Van Cleef battent Nefarian, 79 % des Mages, 69 % des Priests). Par type de combat, le Warrior ne perd pas plus de PV
en proportion que les autres en combat normal et d'élite (5,6 / 12,8 % de ses PV max) mais un boss ne lui coûte
que 20 % de ses PV (Mage 33,5 %, Priest 21,8 %). Balayage `sweep=cards class=warrior runs=300 bot=human` (sans
carte 79,3 %) : aucune carte hors norme ; en tête Victory Rush +14,0, Mortal Strike +11,7, Bloodthirst +11,3,
Demoralizing Shout et Shield Wall +10,3, Shield Block et Execute +9,3 ; en queue Deep Wounds −7,0, Enrage −4,0,
Retaliation −3,3. Bibelot de départ (+1 Rage) : passer à +2 vaut à peu près +3 PV (essai 7), sans effet propre sur
Westfall. Conclusion : l'avance tient aux PV (74, le plus haut) et à la tenue des soins sur la durée.

| Essai (graine 1, 600) | Victoires | Westfall battue | battent Nefarian / battent Van Cleef |
|---|---|---|---|
| Référence (74 PV) | 80,0 % | 85,2 % | 93,9 % |
| 1. 66 PV | 65,0 % | 72,5 % | 89,7 % |
| 2. 69 PV | 70,2 % | 77,3 % | 90,8 % |
| 3. 69 PV, soins de Victory Rush et Bloodthirst −1 | 68,2 % | 76,3 % | 89,4 % |
| 4. 70 PV, soins −1, Demoralizing Shout Cooldown 5 | 70,3 % | 78,3 % | 89,8 % |
| 5. 70 PV, soins −1, Mortal Strike 19, Shield Wall 15 | 70,0 % | 78,0 % | 89,7 % |
| 6. 70 PV, soins −1, Bloodthirst Cooldown 5 | 70,2 % | 78,2 % | 89,8 % |
| 7. 68 PV, soins −1, Battle Standard +2 Rage | 71,2 % | 78,2 % | 91,0 % |
| **Retenu : 70 PV, soins −1, Diamond Flask Regen 3** | **68,5 %** | **77,5 %** | 88,4 % |

Retenu : PV 74 → 70 ; Victory Rush soin 4 / 6 / 8 / 8 → 3 / 5 / 6 / 6 (+0 à +3) ; Bloodthirst soin 2 / 3 / 3 / 5 →
1 / 2 / 2 / 4 ; Diamond Flask (bibelot du Warrior, niveau 3) Regen 5 → 3. Paliers : `docs/classes/warrior-paliers.md`.
Après : % des PV max perdus par combat normal / élite / boss 5,6 / 12,8 / 20,0 → 6,6 / 14,6 / 22,9. Contrôle
`heuristic` (300 expéditions, graine 1) : 96,7 → **95,0 %** (Westfall battue 96,3 %).

- **Les PV bougent Westfall et la campagne ensemble** (≈ 2 points par PV pour chacune, essais 1 à 3) : la limite
  « Westfall battue ≥ Mage (76,7) » arrête la baisse à 69-70 PV, soit ≈ 70 % de victoires. Le reste doit venir de
  ce qui pèse après Westfall : les soins (essai 3 contre 2 : −2,0 points de victoires pour −1,0 à Westfall ; Diamond
  Flask : −1,8 pour −0,8), gagnés en route et décisifs dans les combats longs.
- **Les cartes de dégâts ou de défense ne déplacent rien** à graines égales (Demoralizing Shout, Mortal Strike, Shield
  Wall, Bloodthirst Cooldown 5 : ± 0,3) : le Warrior perd à Westfall et à Duskwood avec un deck de 10 à 16 cartes,
  et ne perd plus ensuite quelle que soit la force de ses cartes tardives. Essais annulés.
- Résultat à 68,5 % : un demi-point au-dessus de la fourchette (± 3,7), Westfall à 0,8 point au-dessus du Mage ;
  69 PV avec les mêmes soins passerait sous le Mage à Westfall (essai 3). Le Warrior reste la classe la plus facile
  au bot `human` (Mage 60,7, Priest 53,5 avant les réglages des autres classes du même jour).
- Non vérifié : niveau 1 compte neuf (Victory Rush soin 4 → 3 avait été annulé en passe 1 pour −11 points au niveau 1,
  bot `heuristic` : à remesurer), clés 1 à 5, épiques du Warrior, autres graines.

## Druid : compte neuf (18/11/2026)

Mesure du 18/11/2026 (`luajit Sim/sim.lua runs=600 bot=human seed=1 jobs=8 runner=expedition key=0 class=<classe>`,
± 4 points) : au niveau 7, Warrior 68,5, Mage 60,7, Hunter 59,3, Rogue 57,2, Priest 53,5, Druid 51,8 % ; en compte
neuf (`zones=0 level=1`), Warrior 43,3, Rogue 41,5, Mage 37,0, Priest 34,3, Hunter 34,0, **Druid 1,3 %**. Cible :
Druid en compte neuf entre 32 et 42 %, niveau 7 entre 48 et 60 %, bot heuristic au niveau 7 sous 97 %. Leviers dans
l'ordre : répartition des niveaux de déblocage (échanges à nombre de cartes égal par niveau), puis chiffres ; règles,
PV (65) et taxe intouchés. Rapports bruts : `reports/l1-*.txt`, `reports/l7-F*.txt` du worktree (non versionnés).

**Diagnostic.** Rien de verrouillé à tort au niveau 1 : les 4 cartes de départ et Idol of the Wild sont au niveau 1,
les quatre formes sont jouables (Cat par Ferocious Bite, Shred, Rake ; Tree par les soins), chaque carte du niveau 1
a sa note de bot. Le deck de départ passe Westfall presque comme au niveau 7 (62,3 contre 71,2 %) ; la classe
s'effondre ensuite (Duskwood 61,0, Wetlands 27,2 % battues quand atteintes ; niveau 7 : 87,8 et 86,9 %). Combat
normal : 17,3 PV encaissés (niveau 7 : 11,9), boss 55,2 (48,7) ; Nek'rosh 41,3 % (88,3 au niveau 7), Morbent Fel
74,0 (92,6), Dragonmaw Raider et Centurion 60,7 (97,8). Fins de tour Bear / Cat / Moonkin / Tree 40,9 / 19,6 / 26,9 /
12,4 %, 1,90 changement par tour (niveau 7 : 2,31), taxe 2,3 mana par combat normal, 3,7 par boss. Deux causes :

- **Rebirth, seule rare du niveau 1** (Hunter et Druid ont une rare au niveau 1, Warrior et Priest trois, Mage et
  Rogue aucune). Une récompense de boss ne tire que des rares (`X.CARD_WEIGHTS.boss = { rare = 1 }`) : elle n'offrait
  que Rebirth, seule carte ; les rares des élites (15 %, plus dans les zones suivantes) et du marchand aussi. Le bot
  `human` l'a choisie 1 594 fois sur 600 expéditions (3,4 exemplaires dans les 465 decks qui l'ont) et joue 83 % des
  exemplaires piochés, alors que Last Breath ne vaut qu'une fois par combat : chaque copie en plus coûte 1 mana et une
  pioche. Le Bestial Wrath du Hunter, dans la même position, se rejoue. Le bot ne voit pas la copie inutile (note de
  choix sans malus de doublon ; `Bots.POWER_VALUE.rebirth` compté par exemplaire en jeu) : écart de bot commun à
  tous les Last Breath en Power, non corrigé ici.
- **Pool du niveau 1 sans carte à 0 mana ni contrôle** : Tiger's Fury et Entangling Roots étaient au niveau 2, alors
  que le niveau 1 gardait Hurricane (Cast à 2 mana, gardée en main 54 % des fois où le bot `human` la pioche) et Rip
  (Surge en DoT, gardée 43 %).

| Répartition (niveau 1) | Victoires | Westfall | Duskwood | Wetlands | Stranglethorn | Swamp | Steppes | Blackrock | Normal / élite / boss : PV encaissés | Changements par tour |
|---|---|---|---|---|---|---|---|---|---|---|
| départ | 1,3 % | 62,3 | 61,0 | 27,2 | 46,8 | 51,7 | 86,7 | 61,5 | 17,3 / 33,4 / 55,2 | 1,90 |
| (1) Rebirth 1 → 4, Healing Touch 4 → 1 | 19,0 % | 56,8 | 75,1 | 60,5 | 87,7 | 95,6 | 99,2 | 88,4 | 15,7 / 29,9 / 55,5 | 2,15 |
| (2) + Tiger's Fury 2 → 1, Rip 1 → 2 | 26,2 % | 58,5 | 78,6 | 71,0 | 92,9 | 96,7 | 99,4 | 89,7 | 14,2 / 27,7 / 53,8 | 2,45 |
| **(3) + Entangling Roots 2 → 1, Hurricane 1 → 2 : retenu** | **36,2 %** (± 3,8) | **64,2** | **86,0** | **75,5** | **95,2** | **100,0** | **99,6** | **91,6** | 10,5 / 21,9 / 56,3 | 2,47 |
| essai : (1) + Demoralizing Roar 6 → 1, Rip 1 → 6 | 53,7 % | 74,0 | 90,5 | 87,8 | 96,0 | 99,1 | 99,7 | 96,1 | 13,0 / 23,0 / 45,5 | 2,23 |
| essai : (2) + Starfall 4 → 1, Starsurge 1 → 4 | 19,5 % | 58,3 | 80,0 | 64,3 | 81,1 | 95,9 | 96,4 | 86,7 | 11,8 / 29,4 / 50,0 | 2,49 |
| niveau 7, pour mémoire (inchangé) | 51,8 % | 71,2 | 87,8 | 86,9 | 97,5 | 99,4 | 100,0 | 98,4 | 11,9 / 22,6 / 48,7 | 2,31 |

Zones : battue / atteinte, en %.

| Contrôle | Avant | Après |
|---|---|---|
| `human`, niveau 1 (`zones=0 level=1`, 600) | 1,3 % | **36,2 %** |
| `human`, niveau 7 (600) | 51,8 % | 51,8 % (rapport identique) |
| `heuristic`, niveau 7 (300) | 95,7 % | 95,7 % (identique) |

- **Retenu : trois échanges dans la même voie** (même nombre de cartes par voie et par niveau, test « progression :
  répartition exacte ») : Rebirth 1 → 4 et Healing Touch 4 → 1 (Restoration) ; Tiger's Fury 2 → 1 et Rip 1 → 2
  (Feral) ; Entangling Roots 2 → 1 et Hurricane 1 → 2 (Balance). Le niveau 1 n'a plus de rare, comme le Mage et le
  Rogue (une récompense de boss se rabat alors sur les poids d'un combat ordinaire) ; Rebirth rejoint Mangle et
  Starfall au niveau 4, comme Ice Block (Mage) et Cheat Death (Rogue). Aucun chiffre changé.
- **Le niveau 7 ne bouge pas** : tout y est débloqué, la répartition ne change ni le pool ni le tirage (rapport
  identique à la graine 1). L'écart niveau 1 / niveau 7 passe à 15,6 points (Hunter 25,3, Mage 23,7, Warrior 25,2).
- **Essais écartés** : Demoralizing Roar au niveau 1 dépasse le niveau 7 (53,7 %) : dans un pool de cinq
  inhabituelles, la seule défense à 0 mana s'empile (2 405 choix, 4 par expédition) ; Starfall au niveau 1 refait le
  piège de la rare seule (2 670 choix, 4,5 par expédition, gardée en main 49 %) et perd 6,7 points.
- **Wetlands reste la zone la plus dure du Druid en compte neuf** (75,5 % battue quand atteinte ; autres classes 84 à
  92 %) : Nek'rosh 76,5 %, sans dégâts de zone à 1 mana au niveau 1 hors Swipe et les coups de fin de tour en Moonkin
  (Hurricane passe au niveau 2).
- Non vérifié : niveaux 2 à 6 (Rebirth au 4 et Healing Touch au 1 changent les pools intermédiaires), autres graines,
  clés 1 à 5, bot heuristic au niveau 1, épiques du Druid imposées ; le malus de doublon des Last Breath dans les
  bots (Rebirth, Cheat Death, Last Stand, Ice Block, Feign Death) reste à traiter à part.

## Druid : voies seules, diagnostic (19/11/2026)

Constat du joueur : au bot `human` (`luajit Sim/sim.lua runs=600 bot=human seed=1 jobs=8 runner=expedition key=0
class=druid [path=<voie>]`, niveau 7, ± 4 points), Restoration seule gagne 67,3 %, Feral seule 22,3 %, Balance seule
15,5 %, le mélange 51,8 % : la classe récompense la voie de soin, pas le changement de forme et l'attaque. Mesures
faites sans toucher au code livré : `tune=Druid.TAX=0` (et autres constantes), `sources=1` (dégâts, soins, Regen et
Absorb par source ; `Sim/sim.lua`). 24 séries ; rapports bruts : `reports/dr/` du worktree (non versionnés). Aucun
chiffre ni règle changés.

**D'où viennent les dégâts de Restoration.** Du deck de départ : Wrath 26,7 %, Ferocious Bite 17,9 %, Maul 13,2 %,
frappes de l'ours 16,3 % (dont 8,8 commandées par Maul, 7,5 en fin de tour), coups de fin de tour de Moonkin 2,8 % ;
**Thorns** 15,0 % (11,5 dégâts par combat). Gift of Nature n'apparaît pas à part (bonus des coups de cartes). Ses
combats durent plus (5,02 tours, référence 3,79), elle encaisse le double (36,8 PV par combat, référence 18,0) et en
soigne 31,3 (référence 10,4) : **85 % des PV perdus reviennent**, aux deux tiers par les tics de Regen (68 %). La
Regen posée vient de Tranquility 25 %, Tree of Life en fin de tour 20 %, Mark of the Wild 20 %, Regrowth 18 %,
Rejuvenation 17 %. Les soins se gardent d'un combat à l'autre : au feu de camp, Restoration choisit l'amélioration
76 % des fois (5,1 améliorations par expédition), Feral et Balance 30 % (1,4 et 1,3). Cartes les plus prises :
Rebirth 3,6 par expédition (doublons de Last Breath, écart de bot connu), Tranquility 3,1, Mark of the Wild 2,2.

**Ce qui tue Feral et Balance.** Leurs cartes n'ajoutent presque rien au deck de départ : le deck de départ seul
(`path=start`, aucune carte prise) gagne 12,8 % (Westfall 45,8 %) ; Feral et Balance ajoutent 11 à 13 % de dégâts
par tour (17,8 → 19,8 et 20,2) et ne réduisent pas les PV nets d'un combat normal (6,8 → 6,8 et 7,4) ; Restoration
les divise par deux (3,4). Plusieurs cartes chères restent en main : Mangle jouée 27 à 33 % des fois où elle est
piochée, Nature's Grace 15 à 27 %, Leader of the Pack 47 à 52 %, Hurricane, Starfire et Starsurge ≈ 50 % ; Mangle et
Leader of the Pack sont pourtant les plus prises de Feral (1,5 par expédition). Balance n'a aucune carte de défense :
elle finit 49 % des tours en Moonkin (sans Absorb) et perd 31 PV nets par boss (Restoration 19, Feral 28).

| Série (bot `human`, niveau 7) | Victoires | Westfall | Tours / combat | PV perdus / soignés par combat | PV nets normal / boss | Taxe (mana / tour) | Changements / tour | Fins en Tree |
|---|---|---|---|---|---|---|---|---|
| référence | 51,8 % | 71,2 | 3,79 | 18,0 / 10,4 | 4,8 / 23,5 | 0,93 | 2,31 | 12,5 % |
| Restoration seule | 67,3 % | 81,7 | 5,02 | 36,8 / 31,3 | 3,4 / 19,3 | 0,77 | 1,98 | 27,9 % |
| Feral seule | 22,3 % | 59,8 | 3,47 | 13,5 / 2,9 | 6,8 / 28,2 | 0,91 | 2,25 | 1,9 % |
| Balance seule | 15,5 % | 58,0 | 3,29 | 14,1 / 2,9 | 7,4 / 31,0 | 0,69 | 1,85 | 2,4 % |
| deck de départ seul (`path=start`) | 12,8 % | 45,8 | 3,69 | 16,6 / 5,2 | 6,8 / 31,5 | 0,83 | 2,14 | 5,1 % |
| **sans taxe** (`Druid.TAX=0`) : référence | 87,2 % | 97,5 | 3,36 | 13,1 / 7,9 | 3,2 / 16,5 | 0 | 3,13 | 10,1 % |
| sans taxe : Restoration | 94,0 % | 98,2 | 4,55 | 28,2 / 24,7 | 2,0 / 12,5 | 0 | 2,64 | 25,7 % |
| sans taxe : Feral | 71,3 % | 95,8 | 3,08 | 10,0 / 2,5 | 4,5 / 20,7 | 0 | 3,07 | 1,7 % |
| sans taxe : Balance | 41,3 % | 92,7 | 3,09 | 12,2 / 2,9 | 5,8 / 27,6 | 0 | 2,35 | 2,2 % |
| Restoration, Tree sans Regen (`TREE_REGEN=0`) | 41,0 % | 59,3 | 4,91 | 34,5 / 27,2 | 4,2 / 24,2 | 0,78 | 2,01 | 23,2 % |

- **Hypothèse (b), la taxe, tient** : elle coûte au bot `human` 0,7 à 0,9 mana par tour (près d'un tiers de ses 3
  mana) et 35 points à la référence (heuristic : 4 points, section « Druid : premier réglage »). Feral la paie le
  plus cher (+49 points sans elle : le va-et-vient Cat / Bear de chaque tour), Restoration et Balance +26 à +27. Le
  deck de départ à trois formes (Wrath en Moonkin, Thick Hide et Maul en Bear, Ferocious Bite en Cat) la fait payer
  à toutes les voies.
- **Hypothèse (a), le soin, tient aussi** : sans taxe, Restoration seule reste devant Feral de 23 points (94,0
  contre 71,3) ; la Regen 2 de fin de tour en Tree of Life vaut à elle seule 26 points à Restoration (67,3 → 41,0),
  par empilement (une Regen N soigne N(N+1)/2 : Regen 2 posée sur Regen 4 rend 11 PV de plus, pas 3).
- **Troisième cause : les cartes offensives pèsent peu** face au deck de départ (ci-dessus), et Balance n'a pas de
  défense : même sans taxe, elle reste à 41,3 %.

**Pistes chiffrées, aucune appliquée** (bot `human`, niveau 7 sauf mention) :

| Piste | Référence | Restoration | Feral | Balance | Niveau 1 (compte neuf) |
|---|---|---|---|---|---|
| actuel | 51,8 % | 67,3 % | 22,3 % | 15,5 % | 36,2 % (18/11) |
| A : `TAX_MAX` 2 → 1, `TREE_REGEN` 2 → 0 (chiffres seuls) | 57,8 % | 62,7 % | 40,0 % | ≈ 23 % (C1) | **49,0 %** |
| C1 : `TAX_MAX` 2 → 1, `TREE_REGEN` 2 → 1 | 62,5 % | 69,7 % | 40,5 % | 23,2 % | – |
| B : sans taxe, `TREE_REGEN` 0, 55 PV (`hp=55`) | 70,7 % | 80,0 % | 48,5 % | 22,0 % | – |

- **Aucun jeu de chiffres essayé ne remet les voies dans l'ordre voulu** : Restoration seule reste devant le
  mélange et 20 à 30 points devant Feral, Balance reste dernière. La piste A, la seule faite de chiffres sans
  toucher aux décisions du joueur, resserre l'écart (Feral 22 → 40, mélange 52 → 58, Restoration 67 → 63) mais fait
  sortir le compte neuf de sa fourchette (49,0 % pour 32 à 42). Le reste demande des règles : options décrites
  dans `docs/classes/druid.md`, § 11, question 4.
- Non vérifié : bot heuristic, autres graines, clés 1 à 5, épiques du Druid ; Balance n'a été mesurée qu'en
  chiffres de socle (aucune carte retouchée).

## Bot human : deck serré (19/11/2026)

Constat (matrice du 19/11, bot `human`, clé 0, niveau 7, `zones=0`, 600 expéditions, graine 1) : « deck mince »
(`takeMin=5 removeRate=1`) et « deck épais » (`takeMin=1 removeRate=0`) finissaient avec le même deck (41 à 45 cartes à
l'entrée de Blackrock) et les mêmes victoires. Compteurs ajoutés au rapport (lignes « Cartes du deck, par
expédition / par victoire » : cartes entrées par source, récompenses offertes et refusées, retraits au marchand et en
rencontre, occasions de retrait), Warrior, par victoire (sept zones) :

| | référence | mince (`takeMin=5 removeRate=1`) | `decksize=20` |
|---|---|---|---|
| récompenses de cartes offertes / refusées | 38,1 / **0,0** | 38,1 / **0,0** | 38,1 / 19,4 |
| cartes entrées : récompenses / marchand / rencontres, copies, épiques | 38,1 / 2,0 / 0 | 38,1 / 0,9 / 0 | 18,6 / 1,5 / 0 |
| retraits : marchand / rencontre | 1,62 / 0,14 | 2,73 / 0,14 | 5,93 / 0,15 |
| visites du marchand avec l'or d'un retrait / rencontres qui en proposent un | 4,05 / 0,54 | 4,04 / 0,54 | 3,89 / 0,54 |
| deck en fin | 48,4 | 46,2 | 24,1 |

Pourquoi les anciens réglages ne mordaient pas : `takeMin` se compare à la note **perçue** de la meilleure des
trois cartes (note de choix ≈ 3,5 à 9, + bruit σ 1,65, + 0,5 à 1 pour une rare, + 0,75 pour une carte nouvelle) :
elle vaut ≈ 7 à 9, et même à `takeMin=5` le bot n'a refusé aucune des 38 récompenses d'une victoire. Les récompenses
de combat (et les choix de cartes des rencontres) font ≈ 95 % des entrées ; le marchand 1 à 2 cartes ; les cartes
imposées par une rencontre, les copies et les épiques (aucune à `zones=0`) rien. `removeRate` ne retire que les
cartes de départ (valeur de retrait ≤ 1,5), au marchand après les bibelots : 1,8 retrait par victoire à 0,5, 2,9 à 1.
Refuser est toujours possible (« Skip » à chaque récompense) : rien dans le jeu n'empêche un deck serré, c'était le
bot qui ne refusait jamais.

Politique `decksize=N` (`Sim/expedition.lua`, `deckCap` ; paramètre de `Bots.HUMAN_RANGE`, 0 = désactivée, absente
des paramètres et du rapport : rapport de référence identique ligne pour ligne, hors les deux lignes ajoutées,
Warrior 600 avant / après). Sous N, rien ne change. À N et au-delà, une carte offerte (récompense, marchand, choix
de rencontre) n'entre que si sa note perçue dépasse celle de la carte qu'il retirerait d'abord (l'épique exceptée ;
carte de départ ≈ 3) de 1,5, plus 2,5 par carte au-delà de N (`SE.DECKSIZE_MARGIN`, `SE.DECKSIZE_STEP`) ; au
marchand il retire avant tout achat, autant que l'or le permet, tant que le deck dépasse N (ou à N s'il reste une
carte de départ) ; une rencontre qui retire vaut plus (2,5), une copie rien, une carte imposée trop faible coûte 0,5.
Le feu de camp n'offre pas de retrait (aucune action de zone ne le fait) : marchand et rencontres seulement.

Mesures (bot `human`, clé 0, niveau 7, 600 expéditions, graine 1, ± 3,7 à 4,0 ; mêmes graines, donc comparaisons
appariées ; victoires % / deck à l'entrée de Blackrock / deck en fin des victoires) :

| Classe | référence | `decksize=20` | `decksize=25` | `decksize=30` | Westfall battue |
|---|---|---|---|---|---|
| Priest | 53,5 / 42,8 / 48,2 | 53,5 / 22,7 / 22,8 | 54,8 / 27,6 / 27,7 | 55,3 / 32,5 / 32,6 | 77,5 |
| Warrior | 68,5 / 43,0 / 48,4 | 65,8 / 24,0 / 24,1 | 67,3 / 28,9 / 29,0 | 68,5 / 33,8 / 33,9 | 77,5 |
| Mage | 60,7 / 42,9 / 48,6 | 60,0 / 23,7 / 23,8 | 60,5 / 28,6 / 28,7 | 60,0 / 33,4 / 33,6 | 76,7 |
| Rogue | 57,2 / 42,4 / 48,0 | **51,3** / 23,6 / 23,7 | 54,3 / 28,5 / 28,6 | 56,3 / 33,3 / 33,5 | 80,7 |
| Hunter | 59,3 / 41,8 / 47,2 | 59,7 / 23,1 / 23,2 | 59,3 / 28,0 / 28,1 | 62,5 / 32,8 / 33,0 | 86,7 |
| Druid | 51,8 / 42,2 / 47,6 | **46,7** / 22,7 / 22,7 | 49,7 / 27,6 / 27,6 | 52,0 / 32,5 / 32,5 | 71,2 |
| Moyenne | 58,5 | 56,2 | 57,7 | 59,1 | |

Deck à l'entrée de chaque zone (Westfall, Duskwood, Wetlands, Stranglethorn, Swamp, Steppes, Blackrock ; écart
entre classes) : référence 10 / 15,6 / 20,9 / 26,4 / 31,8 / 37,2 / 42,5 (± 0,6) ; `20` 10 / 15,6 / 20,8 / 22,4–23,5 /
22,6–23,8 / 22,6–24,0 / 22,7–24,0 ; `25` 10 / 15,6 / 20,9 / 25,9–26,4 / 27,4–28,5 / 27,5–28,8 / 27,6–28,9 ; `30` 10 /
15,6 / 20,9 / 26,1–26,6 / 31,0–31,7 / 32,3–33,4 / 32,5–33,8. Le deck tient à N + 3 environ : la marge croissante
laisse entrer les meilleures cartes, et les ≈ 4 visites payables du marchand par victoire suffisent à retirer ≈ 6
cartes (75 pièces, puis + 25 à chaque retrait). Westfall (deck de 10 à 16 cartes) n'est jamais touchée : la
politique n'agit qu'à partir de la fin de Duskwood à `20`, des Wetlands à `25`, de Stranglethorn à `30`.

Lecture :
- Un deck serré est possible sans changer le jeu : refuser une récompense sur deux suffit, les retraits ne servent
  qu'à sortir les cartes de départ. Tenir N pile (et non N + 3) ne demande que de refuser davantage ; descendre sous
  ≈ 15 cartes demanderait de retirer les cartes de départ de base (8 au Priest), soit ≈ 8 retraits (≈ 1 300 pièces au tarif croissant,
  plus que l'or gagné en moyenne sur une expédition, ≈ 1 000 à 1 100).
- Il n'est pas meilleur pour ce bot : à `30`, mêmes victoires que la référence (59,1 contre 58,5 de moyenne ; Hunter
  +3,2, Priest +1,8, les autres à ± 1) ; à `25` légèrement moins (− 0,8) ; à `20` moins (− 2,3), surtout le
  **Rogue (− 5,9)** et le **Druid (− 5,1)**, qui perdent aux Wetlands et à Stranglethorn (Rogue 89,3 → 88,3 et
  96,5 → 91,2 % battue/atteinte ; Druid 86,9 → 83,8 et 97,5 → 94,3), quand le deck vient d'être plafonné avec encore
  ses cartes de départ. Le Priest gagne à Blackrock (87,0 → 91,5) et finit à égalité ; Mage et Hunter n'y voient rien.
- La note de choix mesure l'effet d'une carte ajoutée au deck de départ de 10 cartes : elle ne dit rien de ce qu'une
  carte apporte dans un deck de 40 où elle est piochée quatre fois moins. Un deck épais ne coûtant rien ici, les
  cartes à combo ou à synergie (qui gagnent à être piochées souvent) ne sont pas récompensées par ce bot : c'est une
  limite de la mesure, pas une preuve qu'un deck serré ne vaut rien pour un joueur qui construit autour d'une idée.

Rapports bruts : `reports/decksize/` (`<classe>-ref|20|25|30.txt`, `warrior-thin.txt`). Non vérifié : autres graines,
clés 1 à 5, `zones=7` (épiques en jeu : une épique pèse plus dans un deck serré), `upfocus=1` combiné (moins de
cartes à améliorer), valeurs de `SE.DECKSIZE_MARGIN` / `SE.DECKSIZE_STEP`.

## Druid : Absorb en Tree, Cat/Bear hors taxe (19/11/2026)

Décision du joueur après le diagnostic des voies seules (section « Druid : voies seules, diagnostic ») : appliquer
quatre changements dans l'ordre, en mesurant après chacun. Mesure : `luajit Sim/sim.lua runs=600 bot=human seed=1
jobs=8 runner=expedition key=0 class=druid [path=<voie>] [zones=0 level=1]` (± 4 points). Un autre lot durcit les
zones 4 à 7 : la cible se lit sur les trois premières zones, colonne « battue » de la ligne Wetlands (= expéditions
qui ont battu Westfall, Duskwood et Wetlands ; les voies seules en `maxzone=wetlands`, qui donne le même chiffre à
0,2 point près). Cibles : niveau 7 entre 60 et 70 % (Rogue 61,5, Mage 65,2, Priest 66,3, Warrior 68,7, Hunter
74,7) ; compte neuf entre 46 et 58 % (Mage 48,3, Warrior 48,7, Hunter 54,3, Rogue 57,0, Priest 61,7) ; Feral seule
et Balance seule à moins de 8 points de Restoration seule, ou devant ; le mélange devant la meilleure voie
offensive seule ; aucune forme au-dessus de 45 % des fins de tour. 47 séries ; rapports bruts : `reports/dp/` du
worktree (non versionnés).

| Étape (bot `human`) | Mélange : Wetlands battue / campagne | Restoration | Feral | Balance | Compte neuf : Wetlands / campagne | Fins de tour Bear / Cat / Moonkin / Tree | Changements / tour | Taxe (mana / tour) |
|---|---|---|---|---|---|---|---|---|
| départ (65 PV) | 54,3 / 51,8 % | 70,5 | 31,2 | 24,7 | 41,7 / 36,2 (18/11) | 36,9 / 17,1 / 33,4 / 12,5 % | 2,31 | 0,92 |
| 1. Tree of Life : 3 Absorb au lieu de Regen 2 | 48,3 / 44,3 | 54,8 | 31,2 | 23,5 | | 37,8 / 17,6 / 34,3 / 10,1 % | 2,30 | 0,92 |
| 2. + Cat ↔ Bear hors taxe | 61,3 / 58,2 | 64,7 | 54,0 | 33,5 | | 35,8 / 17,8 / 35,7 / 10,6 % | 2,46 | 0,75 |
| 3a. + cartes offensives, Insect Swarm 5 Absorb | 69,0 / 67,2 | 66,0 | 58,8 | 53,3 | | 35,8 / 17,2 / 36,1 / 10,7 % | 2,51 | 0,78 |
| 3b. + Faerie Fire 3 Absorb (`maxzone=wetlands`) | 73,0 | | | 60,8 | 69,0 | 40,7 / 18,2 / 32,2 / 8,9 % | 2,43 | 0,70 |
| 4a. 59 PV, Tree 3 Absorb | 62,3 / 59,7 | 54,8 | 47,7 | 46,2 | 56,5 / 49,3 | 36,7 / 17,4 / 35,5 / 10,3 % | 2,52 | 0,77 |
| 4b. 60 PV, Tree 2 Absorb | 63,3 / 58,8 | 53,3 | 50,5 | 50,7 | 58,2 / 50,2 | 37,4 / 17,5 / 35,9 / 9,1 % | 2,51 | 0,77 |
| **4. retenu : 59 PV, Tree 2 Absorb, Mangle jouable à 0 (+2 Frenzy)** | **63,5 / 60,2** | **50,0** | **53,5** | **46,5** | **55,2 / 44,7** | 37,7 / 17,4 / 36,0 / 8,7 % | 2,54 | 0,78 |
| bot heuristic (300), retenu | 96,7 / 96,3 (± 2,1) | | | | | 36,7 / 17,1 / 42,9 / 3,2 % | 2,92 | 0,75 |

Voies seules : Wetlands battue, en %. Taxe des voies seules au réglage retenu : Restoration 0,68, Feral 0,54,
Balance 0,62 mana par tour (départ 0,81 / 0,86 / 0,73).

- **Étape 1, Tree of Life** : la fin de tour donne de l'Absorb pour le tour ennemi (`Druid.TREE_ABSORB`) au lieu de
  Regen 2. Restoration seule perd 16 points à 3 Absorb (70,5 → 54,8) : la Regen de fin de tour s'empilait sur celle
  des cartes. Le mélange perd 6 points, Feral et Balance ne bougent pas (1 % de leurs fins de tour en Tree). Infobulle
  de la plaque : `Enters Tree of Life. End of turn: gain 2 Absorb.` ; pastille : `End of turn: gain 2 Absorb.`.
- **Étape 2, taxe** : un passage entre Cat et Bear (dans les deux sens) ne compte pas pour la taxe
  (`Druid.taxed`, compteur `c.cls.taxed`) ; il reste un changement de forme pour `onShift` (Idol of the Wild,
  Wolfshead Helm, Furor), le journal et `c.cls.shifts`. L'entrée dans la première forme du combat compte toujours ;
  Moonkin → Cat → Bear : un seul changement compté. Les bots voient la règle (`botKey` par changements comptés,
  `c.cls.tax` de la fin de tour simulée lu sur eux). Feral seule +23 points, la taxe du mélange 0,92 → 0,75 mana par
  tour. Balance seule paie encore 0,61 mana par tour (0,73 avant) : son deck de départ a trois formes (Wrath en
  Moonkin, Thick Hide et Maul en Bear, Ferocious Bite en Cat) et chaque aller-retour Moonkin ↔ Bear compte. Ligne de
  la pastille : `Form changes this turn: N. Shifting between Cat and Bear is free.` puis le malus.
- **Étape 3, cartes** (jouée / piochée dans le mélange, avant → au réglage retenu) : Mangle coût 2 → 1, puis jouable
  à 0 avec « +2 Frenzy. » après les frappes (ancien palier 2 ; 27 → 69 %, 76 % en Feral seule) ; Leader of the Pack
  coût 1 → 0 (47 → 90 %) ; Nature's Grace coût 2 → 1 (27 → 53 %) ; Starfire 20 → 24 (52 → 59 %) ; Starsurge 6 → 7
  par Charge (52 → 60 %) ; Hurricane 12 → 15 à tous (48 → 54 %). Défense de Balance, sans carte nouvelle : Insect
  Swarm « Gain 5 Absorb. » en tête (+20 points pour Balance seule avec les dégâts, 33,5 → 53,3) et Faerie Fire
  « Gain 3 Absorb. » (+7,5, → 60,8) ; ils font chacun ≈ 1 à 3 Absorb par combat dans le mélange. Paliers revus
  (`docs/classes/druid.md`, § 3.5 ; `lua5.1 Sim/upgrades.lua class=druid` : aucune erreur).
- **Étape 4, PV** : 65 → 59. Le niveau 7 et le compte neuf montent et descendent ensemble (≈ 2,4 points par PV
  chacun) et le compte neuf n'est plus que 5 points sous le niveau 7 (12,6 avant ; les cartes renforcées sont des
  communes du niveau 1). À 60 PV, compte neuf 58,2 % (au bord haut) ; à 59, niveau 7 59,7 % (au bord bas). Deux
  retouches les séparent : Tree of Life 3 → 2 Absorb (Restoration −4,5, mélange −2,5 à 59 PV) et Mangle jouable à 0
  (rare du niveau 4, absente du compte neuf : niveau 7 +3,6, Feral +5,8). Plafond de taxe inchangé (2).
- **Cibles** : niveau 7 63,5 % (60 à 70) ; compte neuf 55,2 % (46 à 58) ; Feral seule 53,5 et Balance seule 46,5,
  devant ou à 3,5 points de Restoration seule (50,0) ; mélange 63,5, devant Feral seule ; fins de tour 37,7 / 17,4 /
  36,0 / 8,7 %, aucune au-dessus de 45 % ; bot heuristic 96,3 %, sous 97 %. Campagne complète, sur l'état des
  zones de ce worktree : niveau 7 60,2 %, compte neuf 44,7 %.
- Non vérifié : autres graines, clés 1 à 5, épiques du Druid imposées (Furor, Lifebloom lisent des règles changées :
  aucun chiffre d'épique touché), niveaux 2 à 6, les zones 4 à 7 durcies par l'autre lot ; `docs/classes.md` et
  `docs/interface.md` citent encore l'ancienne infobulle de Tree of Life (« gain Regen 1 »).

## Mur des zones 4 à 7 sans épique (19/11/2026)

Décision du joueur : sans carte épique dans le deck, la chance d'aller au-delà de la zone 4 doit tomber
drastiquement (un compte neuf bute vers la zone 4 à sa première expédition, puis repart avec les épiques des zones
gagnées et peut finir dès la suivante). Cible, battue / atteinte (tableau « Par zone »), bot `human`, clé 0 :

| Zone | Sans épique | Avec épique |
|---|---|---|
| 1 à 3 (Westfall, Duskwood, Wetlands) | inchangé | inchangé |
| 4 Stranglethorn Vale | 60 % | 90 % |
| 5 Swamp of Sorrows | 35 % | 80 % |
| 6 Burning Steppes | 30 % | 80 % |
| 7 Blackrock Mountain | 25 % | 75 % |

**Levier : dureté des zones** (`ns.Zone.HARD`, `Core/Zones.lua` ; `docs/zones.md`, « Dureté des zones ») : un
facteur sur les PV à l'apparition et un sur les coups de tous les ennemis de la zone, avant les clés ; les fiches ne
bougent pas, l'unité et les intentions portent les vrais chiffres. Retenu : **1,45 / 1,8 / 2,15 / 2,3** (PV et
coups) pour Stranglethorn / Swamp / Steppes / Blackrock ; zones 1 à 3 sans facteur. Mesure sans recoder :
`zonehp=… zonedmg=…`. Rapport : nouveau tableau « Par zone, épique à l'entrée » (battue / atteinte avec et sans
épique à l'entrée). Commande : `luajit Sim/sim.lua runner=expedition bot=human key=0 seed=1 jobs=8 runs=600
class=<c> zones=7 [epic=none]`.

Essais (`zones=7 epic=none`, moyenne des six classes sauf mention) : 1,3 partout (Warrior seul, 300) 83 / 96 /
100 / 98 ; 1,6 partout (Warrior, 300) 40 / 71 / 95 / 94 ; 1,42 / 1,85 / 2,5 / 2,4 (300) 67 / 30 / 13 / 33 ;
1,46 / 1,8 / 2,25 / 2,4 : 59,8 / 34,2 / 25,3 / 24,9 ; Stranglethorn en PV 1,65 et coups 1,3 : 68,3 (écart entre
classes non réduit, 53 à 81 : écarté). Les zones tardives demandent des facteurs plus forts parce que seuls les
meilleurs decks y arrivent ; la réponse est très raide (Swamp 1,6 → 71 %, 1,8 → 34 %, 2,0 → 18 % au Warrior).

### Par zone, moyenne des six classes (battue / atteinte, %)

| Zone | Sans épique avant | Sans épique après | Cible | Épiques gagnées avant | Épiques gagnées après (toutes / avec épique à l'entrée / sans) | Cible avec épique |
|---|---|---|---|---|---|---|
| Westfall | 83,8 | 83,8 | = | 84,7 | 84,7 | = |
| Duskwood | 93,5 | 93,5 | = | 94,4 | 94,4 | = |
| Wetlands | 96,7 | 96,7 | = | 97,5 | 97,5 | = |
| Stranglethorn Vale | 98,6 | **63,9** | 60 | 98,5 | 64,5 / **65,1** / 62,6 | 90 |
| Swamp of Sorrows | 98,8 | **33,9** | 35 | 98,9 | 40,5 / **40,9** / 36,8 | 80 |
| Burning Steppes | 99,8 | **34,9** | 30 | 99,6 | 41,6 / **41,0** / (n < 10) | 80 |
| Blackrock Mountain | 99,0 | **20,7** | 25 | 98,2 | 26,4 / **26,3** / (n < 10) | 75 |

Zones 1 à 3 : rapports identiques ligne à ligne à graine égale (avant : `reports/epic-gate` du dépôt principal).
Avant, une épique valait 0 à 5 points sous l'effet de plafond ; plafond levé, elle vaut **+1 / +7 / +6 / +5
points** en moyenne (Warrior +10 / +19 / +17 / +18, Priest −8 à Stranglethorn) : la colonne « avec épique » est
loin de la cible. (« Sans » dans une expédition aux épiques gagnées : le deck peut en gagner une en cours de zone.)

### Par classe, sans épique (`zones=7 epic=none`, 600)

| Classe | Victoires avant → après | Stranglethorn | Swamp | Steppes (n) | Blackrock (n) |
|---|---|---|---|---|---|
| Hunter | 79,7 → 1,8 | 66,6 | 32,4 | 33,0 (106) | 31,4 (35) |
| Rogue | 72,0 → 1,5 | 50,2 | 27,6 | 42,9 (63) | 33,3 (27) |
| Warrior | 74,5 → 1,5 | 63,4 | 44,8 | 41,9 (129) | 16,7 (54) |
| Mage | 75,3 → 1,2 | 64,9 | 36,7 | 35,5 (110) | 17,9 (39) |
| Druid | 67,3 → 0,3 | 65,0 | 30,2 | 23,5 (81) | 10,5 (19) |
| Priest | 68,7 → 0,8 | 73,4 | 31,4 | 32,4 (105) | 14,7 (34) |
| Moyenne (cible) | 72,9 → 1,2 | 63,9 (60) | 33,9 (35) | 34,9 (30) | 20,7 (25) |

Aucune classe à plus de 15 points de la cible (les plus loin : Druid à Blackrock 10,5, Priest à Stranglethorn
73,4) ; à Blackrock, 19 à 54 expéditions par classe y arrivent sans épique : ± 7 à 11 points par classe.

### Victoires de campagne par classe (Nefarian battu, %)

| Classe | Vétéran, épiques gagnées : avant → après | Vétéran sans épique : avant → après | Compte neuf `zones=0 level=1` : avant → après | 2e expédition `zones=3 level=2` | idem avec le levier A |
|---|---|---|---|---|---|
| Hunter | 81,8 → 2,5 | 79,7 → 1,8 | 34,0 → 0,0 | 0,0 | 14,3 |
| Rogue | 77,3 → 2,0 | 72,0 → 1,5 | 41,5 → 0,0 | 0,0 | 13,5 |
| Warrior | 76,7 → 7,2 | 74,5 → 1,5 | 43,3 → 0,0 | 2,7 | 39,5 |
| Mage | 74,8 → 3,8 | 75,3 → 1,2 | 37,0 → 0,0 | 0,0 | 10,3 |
| Druid | 70,8 → 0,5 | 67,3 → 0,3 | 36,2 → 0,0 | 0,0 | 12,0 |
| Priest | 64,2 → 0,5 | 68,7 → 0,8 | 34,3 → 0,0 | 0,3 | 14,3 |

Compte neuf (niveau 1, aucune épique) : Stranglethorn battue / atteinte **10,7 %** en moyenne (Hunter 1,5, Rogue
2,6, Druid 4,4, Warrior 8,9, Mage 9,3, Priest 37,6 ; avant 90,5), Swamp 2,1 % : le mur tombe bien à la zone 4,
plus dur que la cible du vétéran (le deck de niveau 1 est plus faible). 2e expédition (épiques des trois premières
zones, niveau 2) sans levier : Stranglethorn 42,2 %, victoires 0,5 % : « peut finir dès la suivante » n'est pas
tenu sans un levier d'épique.

### Épiques imposées (`epic=<id> zones=7`, 600) : battue / atteinte, Stranglethorn / Swamp / Steppes / Blackrock

| Épique | Avec | Sans épique (même classe) | Victoires |
|---|---|---|---|
| Hunter Call of the Wild (Westfall) | 75,3 / 45,9 / 31,1 / 33,9 | 66,6 / 32,4 / 33,0 / 31,4 | 3,3 |
| Hunter Beast Cleave | 71,9 / **21,8** / 41,7 / 37,1 | | 2,2 |
| Rogue Deflection (Westfall) | 59,7 / 28,3 / 36,7 / 36,4 | 50,2 / 27,6 / 42,9 / 33,3 | 2,0 |
| Rogue Kidney Shot | 60,4 / 34,5 / 46,0 / 41,3 | | 3,2 |
| Warrior Death Wish (Westfall) | 60,7 / 74,3 / 60,9 / 38,8 | 63,4 / 44,8 / 41,9 / 16,7 | 8,7 |
| Warrior Titan's Grip | **89,4 / 85,7 / 75,4 / 59,9** | | 30,3 |
| Mage Mirror Image (Westfall) | 79,0 / 68,6 / 69,9 / 36,5 | 64,9 / 36,7 / 35,5 / 17,9 | 12,2 |
| Mage Water Elemental | 65,8 / 42,2 / 60,0 / 31,0 | | 4,5 |
| Druid Furor (Westfall) | 71,6 / 52,3 / 39,0 / 4,7 | 65,0 / 30,2 / 23,5 / 10,5 | 0,7 |
| Druid Eclipse | **50,9 / 28,8 / 16,4 / 0,0** | | 0,0 |
| Priest Prayer of Mending (Westfall) | 61,9 / 18,3 / 25,9 / 6,7 | 73,4 / 31,4 / 32,4 / 14,7 | 0,2 |
| Priest Misery | 64,5 / 20,7 / 28,6 / 5,6 | | 0,2 |
| Priest Echo of Light | 62,2 / 13,6 / 37,2 / 37,5 | | 1,0 |
| Priest Shadow Covenant | **40,9 / 15,5 / 16,0 / 0,0** (Wetlands 81,2 contre 97,0) | | 0,0 |
| Priest Reflective Shield | 79,1 / 41,8 / 47,0 / 28,2 | | 3,7 |
| Priest Voidform | 68,9 / 34,2 / 37,2 / 21,4 | | 1,5 |
| Priest Inner Focus | 57,8 / 41,0 / 44,1 / 24,4 (Westfall 77,3 contre 82,7) | | 1,8 |

(Biais : une épique dès le départ fait survivre des decks plus faibles aux zones 1 à 3, ce qui baisse un peu les
taux conditionnels suivants ; Westfall passe par exemple de 82,7 à 89,2 avec Prayer of Mending.)

- **Épiques qui n'apportent rien ou font perdre** : **Shadow Covenant** (Priest) fait perdre partout dès les
  Wetlands : c'est elle qui tire le Priest vers le bas (« avec épique » sous « sans ») ; Prayer of Mending, Misery
  et Echo of Light perdent aussi 9 à 18 points à Stranglethorn et au Swamp ; seule Reflective Shield aide le Priest.
  **Eclipse** (Druid) fait perdre dès Westfall (77,0 contre 77,7 ; Stranglethorn 50,9 contre 65,0). Beast Cleave
  (Hunter) perd 10 points au Swamp ; Deflection et Kidney Shot (Rogue) n'apportent que 0 à 10 points ; Furor
  (Druid) aide jusqu'aux Steppes mais pas contre Nefarian.
- **Épiques fortes** : Titan's Grip (Warrior) touche déjà la cible « avec épique » ; Mirror Image (Mage) en est
  proche jusqu'aux Steppes.

### Leviers d'épique mesurés (A écarté par le joueur le 19/11/2026 : « Plusieurs épiques par expédition » plus bas)

**A. L'épique contre la dureté de la zone (écarté par le joueur : artificiel).** Quand le deck du combat a une épique,
les ennemis prennent un facteur plus faible : champs `epicHp` / `epicDmg` de `ns.Zone.HARD` (le code les lit
déjà ; ils sont absents aujourd'hui ; mesure : `zoneepichp=… zoneepicdmg=…`). Épiques gagnées normalement
(`zones=7`, 600), battue / atteinte avec épique à l'entrée :

| Facteurs avec épique (STV / SoS / BS / BRM) | Stranglethorn | Swamp | Steppes | Blackrock | Victoires (moyenne) |
|---|---|---|---|---|---|
| aucun (aujourd'hui : 1,45 / 1,8 / 2,15 / 2,3) | 65,1 | 40,9 | 41,0 | 26,3 | 2,8 |
| 1,2 / 1,5 / 1,8 / 1,85 | 92,4 | 72,6 | 71,4 | 57,1 | 20,7 |
| 1,25 / 1,4 / 1,6 / 1,55 | 86,9 | 82,4 | 86,5 | 79,2 | 36,4 |
| **1,2 / 1,4 / 1,7 / 1,6 (proposé)** | **92,4** | **81,2** | **78,6** | **79,1** | **34,4** |
| cible | 90 | 80 | 80 | 75 | |

Avec 1,2 / 1,4 / 1,7 / 1,6, par classe (STV / SoS / BS / BRM avec épique à l'entrée ; victoires) : Hunter 91,5 /
78,3 / 78,5 / 88,6 (39,0) ; Rogue 88,3 / 77,2 / 74,8 / 84,9 (31,0) ; Warrior 97,7 / 94,4 / 93,0 / 90,6 (54,8) ;
Mage 94,4 / 84,9 / 82,6 / 81,2 (37,3) ; Druid 90,9 / 85,5 / 72,9 / 67,6 (25,0) ; Priest 91,6 / 67,1 / 70,1 / 61,5
(19,2). La colonne « sans épique » (`epic=none`) ne bouge pas. 2e expédition d'un compte neuf (`zones=3
level=2`) : victoires 0,5 → **17,3 %** (Stranglethorn 75,2, Swamp 72,7, Steppes 64,4, Blackrock 60,3). Toutes les
épiques en profitent, les faibles comprises : c'est le seul levier mesuré qui sépare franchement les deux
colonnes. À l'écran, il faudrait le dire (bandeau de zone ou texte de l'épique) : à décider avec la règle.

**B. Épique plus forte (proxy : l'épique de Westfall imposée d'office au palier +3, `force=<id>+3 epic=none`).**
Stranglethorn / Swamp / Steppes / Blackrock (victoires) : Hunter 83,1 / 51,4 / 52,2 / 40,6 (9,0) ; Rogue 72,0 /
32,8 / 38,1 / 32,1 (2,8) ; Warrior 87,6 / 91,8 / 84,8 / 56,4 (38,2) ; Mage 91,4 / 86,5 / 88,2 / 49,5 (32,7) ;
Druid 74,2 / 53,6 / 41,9 / 9,1 (1,5) ; Priest 61,1 / 26,1 / 34,5 / 6,7 (0,3) ; moyenne 78,2 / 57,0 / 56,6 / 32,4.
Même au palier maximal, l'écart reste de 12 à 43 points sous la cible, très inégal (Warrior et Mage forts, Rogue,
Druid et Priest presque rien) et les zones 1 à 3 deviennent triviales (98 à 99,5 %). Des paliers plus forts ou un
relèvement général des chiffres des épiques ne suffisent donc pas : écarté.

**C. Épique dans la main de départ** : sans objet, l'épique est déjà une règle active dès le début de chaque combat
(`c.epic`, hors des piles).

- Non vérifié : clés 1 à 5 (Fortified et Tyrannical s'ajoutent par-dessus la dureté : les clés deviennent bien
  plus dures dans les zones 4 à 7, à re-mesurer), bot heuristic, autres graines, niveaux 2 à 6, les 25 épiques non
  imposées ; la dureté s'applique aussi aux boss et aux invoqués, pas aux dégâts d'état (DoT, Wildfire).

### Plusieurs épiques par expédition (décision du joueur, 19/11/2026)

Le joueur écarte le levier A (« l'épique réduit la dureté », jugé artificiel) : le deck peut porter **plusieurs
épiques**, et c'est leur cumul qui doit faire passer les zones 4 à 7 (un compte qui a débloqué plus d'épiques est
plus fort). Règle (`docs/expedition.md`, « Cartes épiques ») : plafond `Expedition.EPIC.max`, au plafond la
nouvelle remplace la plus ancienne ; une épique déjà obtenue dans l'expédition ne retombe pas ; acquisition
inchangée (chute aux élites 25 % → 85 % selon la zone, marchand 50 % dès l'étape 4, 150 po × prix de la zone ;
toute épique débloquée par la classe est proposable). Dureté inchangée (1,45 / 1,8 / 2,15 / 2,3). Cible
inchangée, la colonne « avec épique » se lisant « avec le nombre d'épiques qu'un vétéran porte à ce stade ».
Mesures : bot `human`, clé 0, `seed=1`, six classes, moyenne des six classes ; tableau « Par zone, nombre
d'épiques » (nouveau dans le rapport).

**Plafond** (`zones=7`, 300 expéditions par classe, `epicmax=N`) : battue / atteinte avec au moins une épique à
l'entrée (STV / SoS / BS / BRM), épiques portées à l'entrée (moyenne), victoires.

| Plafond | Avec épique(s) | Épiques à l'entrée STV / SoS / BS / BRM | Victoires |
|---|---|---|---|
| 1 (l'ancienne règle) | 64,3 / 42,4 / 42,7 / 28,7 | 0,76 / 0,91 / 0,98 / 1,00 | 3,2 |
| 2 | 64,7 / 45,7 / 51,3 / 25,7 | 1,07 / 1,48 / 1,81 / 1,93 | 3,7 |
| 3 | 64,7 / 45,1 / 52,9 / 26,8 | 1,12 / 1,68 / 2,33 / 2,71 | 4,2 |
| **sans plafond (retenu)** | 64,7 / 45,1 / 54,4 / 32,0 | 1,13 / 1,73 / 2,60 / 3,53 | 5,0 |
| sans plafond, acquisition rapide (élites 60 % → 100 %, marchand 100 %, 75 po) | 66,0 / 49,5 / 56,5 / 33,2 | 2,41 / 3,40 / 4,59 / 5,62 | 7,4 |
| borne haute : les 7 épiques imposées au départ (`epic=a+…+g`) | 67,0 / 60,1 / 74,4 / 38,5 | 7 | 21,2 |
| cible | 90 / 80 / 80 / 75 | | |

Le cumul aide peu : chaque épique de plus vaut quelques points (Swamp, battue / atteinte selon le nombre
d'épiques à l'entrée, sans plafond : 0 → 35,8, 1 → 43,0, 2 → 41,7, 3 ou plus → 57,1 ; Blackrock : 1 → 15,4,
2 → 35,3, 3+ → 40,6). Une acquisition deux fois plus rapide ajoute 1 à 4 points et rend les zones 1 à 3 plus
faciles : écartée. Même avec les sept épiques dès Westfall, la moyenne reste loin de la cible, parce que des
épiques se contrarient : **Hunter** 4,3 % à Westfall (Lone Wolf supprime le familier dont vivent Call of the
Wild, Beast Cleave et Roar of Sacrifice), **Priest** 37,6 % à Stranglethorn et 3,8 % au Swamp (Echo of Light
retire le soin de la Regen dont vit Prayer of Mending, Shadow Covenant paie en PV, Voidform interdit les cartes
à Surge), **Druid** 12 % à Blackrock (Heart of the Wild plafonne chaque réserve à 3 : Eclipse, King of the
Jungle et les autres en ont moins) ; Warrior (97 / 95 / 94 / 77) et Mage (91 / 82 / 88 / 62) atteignent ou
frôlent la cible, Rogue (95 / 66 / 74 / 41) à mi-chemin. Dans les expéditions normales, le Druid perd aussi à
Blackrock quand le plafond monte (23,3 → 15,4 → 8,1 → 8,8 %, plafond 1, 2, 3, aucun ; 30 à 60 expéditions).

**Retenu : sans plafond** (`EPIC.max = 0`), acquisition et dureté inchangées : c'est la règle la plus simple
(chaque épique obtenue reste) et la meilleure des mesures à rythme égal ; elle ne tient pas la cible « avec
épique ».

### Tableau final (600 expéditions par classe, sans plafond)

Par zone, battue / atteinte, moyenne des six classes (vétéran avec épiques : colonne « avec » = au moins une
épique à l'entrée ; vétéran sans épique : `epic=none`) :

| Zone | Sans épique (`zones=7 epic=none`) | Cible | Avec épique(s) (`zones=7`) | Épiques à l'entrée | Cible | Écart |
|---|---|---|---|---|---|---|
| Westfall | 84,0 | = | 84,7 (toutes) | 0 | = | |
| Duskwood | 93,4 | = | 94,1 (toutes) | 0,30 | = | |
| Wetlands | 97,6 | = | 97,5 (toutes) | 0,67 | = | |
| Stranglethorn Vale | **64,0** | 60 | **66,2** | 1,12 | 90 | −24 |
| Swamp of Sorrows | **35,2** | 35 | **45,0** | 1,73 | 80 | −35 |
| Burning Steppes | **36,4** | 30 | **53,2** | 2,57 | 80 | −27 |
| Blackrock Mountain | **20,8** | 25 | **31,7** | 3,45 | 75 | −43 |

Selon le nombre d'épiques à l'entrée (`zones=7`, battue / atteinte, toutes classes, n) : Stranglethorn 0 : 63,1
(726), 1 : 63,7 (1 199), 2 : 69,4 (707), 3+ : 68,5 (165) ; Swamp 38,2 / 42,3 / 42,6 / 55,1 ; Steppes 53,9 (26) /
46,3 / 59,3 / 57,6 ; Blackrock 33,3 (3) / 24,1 (29) / 36,5 (74) / 39,0 (354).

Par classe (STV / SoS / BS / BRM, battue / atteinte ; avec : au moins une épique à l'entrée, `zones=7`) :

| Classe | Sans épique (`epic=none`) | Avec épique(s) | Épiques à l'entrée de Blackrock |
|---|---|---|---|
| Hunter | 66,6 / 32,4 / 33,0 / 31,4 | 61,6 / 34,2 / 40,0 / 31,0 | 3,12 |
| Rogue | 50,2 / 27,6 / 42,9 / 33,3 | 57,8 / 40,2 / 58,3 / 36,1 | 3,81 |
| Warrior | 63,4 / 44,8 / 41,9 / 16,7 | 70,8 / 69,8 / 71,9 / 49,4 | 3,52 |
| Mage | 64,9 / 36,7 / 35,5 / 17,9 | 74,3 / 50,0 / 61,3 / 44,4 | 3,54 |
| Druid | 65,8 / 38,3 / 32,4 / 11,1 | 70,4 / 49,8 / 44,0 / 17,5 | 3,59 |
| Priest | 73,4 / 31,4 / 32,4 / 14,7 | 62,5 / 26,2 / 44,0 / 11,8 | 3,12 |
| Moyenne (cible) | 64,0 (60) / 35,2 (35) / 36,4 (30) / 20,8 (25) | 66,2 (90) / 45,0 (80) / 53,2 (80) / 31,7 (75) | 3,45 |

Colonne « sans épique » : moyenne dans ± 6 points sauf les Steppes (+6,4 : le Druid réglé le 19/11 y passe de
23,5 à 32,4) ; aucune classe à plus de 15 points de la cible (les plus loin : Druid à Blackrock 11,1, −13,9 ;
Priest à Stranglethorn 73,4, +13,4 ; n = 27 à 54 à Blackrock, ± 7 à 11 points par classe). Colonne « avec épique » :
toutes les classes à plus de 15 points sous la cible au Swamp et à Blackrock ; le Priest « avec » est sous son
« sans » à Stranglethorn et au Swamp (ses épiques font perdre), le Hunter n'y gagne presque rien.

### Victoires de campagne par classe (Nefarian battu, %, 600 expéditions)

| Classe | Vétéran, épiques gagnées (`zones=7`) | Vétéran sans épique (`epic=none`) | Compte neuf (`zones=0 level=1`) | 2e expédition (`zones=3 level=2`) |
|---|---|---|---|---|
| Hunter | 2,3 | 1,8 | 0,0 | 0,2 |
| Rogue | 3,7 | 1,5 | 0,0 | 0,2 |
| Warrior | 13,0 | 1,5 | 0,0 | 3,3 |
| Mage | 7,3 | 1,2 | 0,0 | 0,0 |
| Druid | 1,8 | 0,7 | 0,0 | 0,2 |
| Priest | 0,7 | 0,8 | 0,0 | 0,0 |
| Moyenne | 4,8 (plafond 1 : 3,2) | 1,2 | 0,0 | 0,7 (plafond 1 : 0,5) |

Compte neuf : aucune épique débloquée au départ (le plafond ne change rien) ; Stranglethorn 11,3 % battue /
atteinte (Priest 37,6, les autres 1,5 à 9,3), Swamp 2,1 % : le mur tombe bien à la zone 4. 2e expédition
(épiques des trois premières zones, niveau 2) : Stranglethorn 44,8 %, Swamp 28,5, Steppes 29,4, Blackrock 8,6 ;
1,16 épique à l'entrée de Stranglethorn, 2,5 à Blackrock ; « peut finir dès la suivante » n'est pas tenu (0,7 %).

Bot heuristic (vétéran, épiques gagnées, 300 expéditions par classe ; pas une cible : ce que fait un très bon
joueur) : battue / atteinte avec épique(s) à l'entrée 86,7 / 66,7 / 71,8 / 67,4 (STV / SoS / BS / BRM ; zones 1 à
3 : 98,8 / 99,4 / 99,2), victoires 28,6 % (Hunter 16,7, Rogue 33,3, Warrior 49,0, Mage 42,3, Druid 20,0, Priest
10,3). Même parfait au combat, le cumul reste sous la cible au Swamp et à Blackrock.

### Ce qu'il faudrait

Avec les épiques d'aujourd'hui, le cumul ne passe pas le mur : il manque 24 à 43 points à la colonne « avec
épique ». Repères : la cible était tenue (92 / 80 / 79 / 81, victoires 35 %, mesure du 19/11 sur le Druid
réglé) quand un deck avec épique voyait les ennemis à 1,2 / 1,4 / 1,7 / 1,6 au lieu de 1,45 / 1,8 / 2,15 / 2,3 :
ce que les épiques cumulées d'un vétéran devraient valoir, c'est l'équivalent de **−17 / −22 / −21 / −30 %** de
PV et de coups ennemis, soit pour chaque épique de l'ordre de +10 à +15 points au lieu de +3 à +6 aujourd'hui.
Pistes, hors de ce réglage : (1) épiques plus fortes, surtout celles qui se cumulent (un autre agent mesure et
corrige les 42 épiques ; Warrior et Mage montrent qu'un cumul fort suffit) ; (2) règles d'exclusion ou choix
assumé entre épiques qui se contrarient (Lone Wolf et le familier, Echo of Light et Prayer of Mending, Heart of
the Wild et les réserves) ; le bot les prend toutes, un joueur pourrait refuser ; (3) une acquisition plus
rapide n'apporte que 1 à 4 points (mesuré).

- Non vérifié : clés 1 à 5, autres graines, niveaux 2 à 6 hors `zones=3 level=2`, interactions des 42 épiques
  deux à deux (seules Heart of the Wild + Furor ont un test ; les autres cumuls passent par le chaînage des
  crochets, sans revue une à une), la lecture en jeu de plusieurs jetons d'épique (`docs/interface.md`).

## Épiques : mesure une par une (19/11/2026)

Les zones 4 à 7 durcies (`ns.Zone.HARD`, section précédente), chaque épique imposée au départ montre ce qu'elle vaut.
Mesure : `luajit Sim/sim.lua runner=expedition bot=human key=0 zones=7 seed=1 jobs=8 runs=300 class=<c>
epic=<id>|none` (état de `main` après « harden zones 4 to 7 », sans le bonus « l'épique réduit la dureté »).
Colonnes : victoires de campagne, puis battue / atteinte par zone (%) ; « moy 4-7 » = moyenne des zones 4 à 7 ;
« écart » = moy 4-7 − celle de `epic=none` de la classe ; **sous** = au moins deux zones à plus de 5 points sous
`epic=none` (le critère de correction). Rapports : `reports/eu/` (300), `reports/fin600/` (600), diagnostics dans
`build/alt/reports/d1` à `d19` et `r2` (copie de travail, hors dépôt).

Lecture : à 300 expéditions, ± 3 points par zone à Stranglethorn, ± 4 au Swamp, ± 7 à 17 aux Steppes et à Blackrock
(30 à 60 expéditions y arrivent sans épique, 10 à 30 pour le Rogue) ; la moyenne 4-7 bouge de ± 2 à 3 points. Biais
de survie : une épique imposée fait passer des decks plus faibles aux zones 1 à 3 (Westfall 80 → 95 à 99 % avec
Furor, Heart of the Wild corrigée, Subterfuge corrigée), ce qui baisse un peu les taux conditionnels suivants.

### Tableau initial (300 expéditions par ligne)

| Classe | Épique | Vict. | WF | DW | WL | STV | SoS | BS | BRM | moy 4-7 | écart |
|---|---|---|---|---|---|---|---|---|---|---|---|
| warrior | none | 1,7 | 83,0 | 93,6 | 97,9 | 65,8 | 43,3 | 41,5 | 18,5 | 42,3 | — |
| warrior | death_wish | 7,7 | 87,3 | 95,8 | 96,8 | 58,4 | 71,1 | 58,4 | 39,0 | 56,7 | +14,4 |
| warrior | thunderous_roar | 9,7 | 93,0 | 96,8 | 99,3 | 72,8 | 62,1 | 50,4 | 47,5 | 58,2 | +15,9 |
| warrior | sweeping_strikes | 2,3 | 92,0 | 96,7 | 99,6 | 59,4 | 36,7 | 39,7 | 30,4 | 41,5 | -0,7 **sous** |
| warrior | titans_grip | 27,3 | 91,3 | 96,4 | 100,0 | 88,6 | 84,6 | 74,2 | 55,8 | 75,8 | +33,5 |
| warrior | shield_charge | 14,3 | 93,7 | 98,2 | 100,0 | 90,6 | 74,0 | 60,0 | 38,7 | 65,8 | +23,6 |
| warrior | anger_management | 8,0 | 91,7 | 97,8 | 100,0 | 85,5 | 63,0 | 56,6 | 29,3 | 58,6 | +16,3 |
| warrior | avatar | 8,7 | 94,3 | 97,2 | 99,3 | 81,0 | 65,2 | 60,4 | 29,9 | 59,1 | +16,9 |
| priest | none | 0,3 | 80,0 | 92,5 | 97,7 | 73,7 | 33,1 | 34,0 | 5,6 | 36,6 | — |
| priest | prayer_of_mending | 0,0 | 87,7 | 97,0 | 97,6 | 63,9 | 17,0 | 22,2 | 0,0 | 25,8 | -10,8 **sous** |
| priest | misery | 0,3 | 83,3 | 97,2 | 97,5 | 62,4 | 20,3 | 36,7 | 9,1 | 32,1 | -4,5 **sous** |
| priest | echo_of_light | 0,7 | 90,3 | 96,3 | 99,6 | 58,5 | 13,2 | 30,0 | 33,3 | 33,8 | -2,9 **sous** |
| priest | shadow_covenant | 0,0 | 87,3 | 93,1 | 81,1 | 41,9 | 16,9 | 7,1 | 0,0 | 16,5 | -20,1 **sous** |
| priest | reflective_shield | 2,3 | 88,7 | 97,7 | 98,5 | 78,9 | 39,1 | 39,2 | 22,6 | 45,0 | +8,4 |
| priest | voidform | 2,0 | 83,3 | 95,6 | 96,7 | 68,8 | 32,7 | 34,6 | 33,3 | 42,4 | +5,8 |
| priest | inner_focus | 2,0 | 79,3 | 96,6 | 97,0 | 52,9 | 43,2 | 49,0 | 24,0 | 42,3 | +5,7 |
| druid | none | 0,7 | 80,0 | 94,6 | 99,1 | 64,9 | 36,3 | 28,3 | 13,3 | 35,7 | — |
| druid | furor | 2,0 | 99,7 | 99,7 | 99,7 | 66,3 | 54,3 | 43,0 | 13,0 | 44,1 | +8,4 |
| druid | mark_of_ursol | 6,7 | 93,3 | 98,2 | 99,3 | 85,3 | 66,5 | 51,0 | 25,3 | 57,0 | +21,3 |
| druid | eclipse | 0,0 | 80,7 | 94,2 | 94,3 | 55,3 | 37,8 | 15,6 | 0,0 | 27,2 | -8,5 **sous** |
| druid | king_of_the_jungle | 0,7 | 89,3 | 97,8 | 98,9 | 66,0 | 35,1 | 31,7 | 10,5 | 35,8 | +0,1 |
| druid | lifebloom | 2,7 | 84,7 | 99,2 | 99,2 | 88,4 | 58,8 | 45,4 | 13,6 | 51,5 | +15,8 |
| druid | owlkin_frenzy | 0,3 | 82,0 | 95,9 | 98,3 | 49,1 | 32,5 | 24,3 | 11,1 | 29,2 | -6,5 |
| druid | heart_of_the_wild | 0,0 | 40,3 | 86,0 | 90,4 | 44,7 | 35,7 | 20,0 | 0,0 | 25,1 | -10,6 **sous** |
| hunter | none | 1,7 | 88,7 | 93,2 | 98,4 | 65,6 | 32,5 | 23,1 | 41,7 | 40,7 | — |
| hunter | call_of_the_wild | 4,3 | 94,7 | 96,1 | 98,2 | 78,7 | 47,4 | 33,0 | 39,4 | 49,6 | +8,9 |
| hunter | trap_launcher | 1,3 | 96,3 | 98,3 | 98,9 | 73,0 | 36,6 | 32,0 | 16,7 | 39,6 | -1,1 |
| hunter | beast_cleave | 1,7 | 91,7 | 98,5 | 100,0 | 69,7 | 22,8 | 37,2 | 31,2 | 40,2 | -0,5 **sous** |
| hunter | roar_of_sacrifice | 5,0 | 97,0 | 99,0 | 99,3 | 78,3 | 41,5 | 26,9 | 60,0 | 51,7 | +10,9 |
| hunter | master_marksman | 5,7 | 94,3 | 96,5 | 99,3 | 73,8 | 51,0 | 49,0 | 34,0 | 52,0 | +11,2 |
| hunter | black_arrow | 1,7 | 94,3 | 98,6 | 98,2 | 64,2 | 35,8 | 23,8 | 33,3 | 39,3 | -1,5 |
| hunter | lone_wolf | 1,7 | 93,0 | 91,0 | 97,6 | 54,8 | 34,6 | 36,2 | 29,4 | 38,8 | -2,0 **sous** |
| rogue | none | 1,3 | 86,7 | 90,8 | 94,5 | 45,7 | 31,4 | 43,8 | 28,6 | 37,4 | — |
| rogue | deflection | 2,0 | 94,7 | 97,2 | 99,3 | 59,5 | 33,1 | 35,2 | 31,6 | 39,9 | +2,5 |
| rogue | doomblade | 0,7 | 89,0 | 86,9 | 93,5 | 47,5 | 31,1 | 34,4 | 18,2 | 32,8 | -4,6 **sous** |
| rogue | atrophic_poison | 3,0 | 93,7 | 93,2 | 96,9 | 70,1 | 38,8 | 39,1 | 33,3 | 45,3 | +7,9 |
| rogue | echoing_reprimand | 1,3 | 90,0 | 91,5 | 96,4 | 51,7 | 35,0 | 39,5 | 23,5 | 37,4 | +0,0 |
| rogue | subterfuge | 0,3 | 95,3 | 94,1 | 98,1 | 47,7 | 30,2 | 21,1 | 12,5 | 27,9 | -9,5 **sous** |
| rogue | kidney_shot | 4,7 | 88,3 | 94,0 | 97,6 | 60,1 | 33,6 | 57,1 | 50,0 | 50,2 | +12,8 |
| rogue | danse_macabre | 3,0 | 92,0 | 96,0 | 99,6 | 75,4 | 40,2 | 51,2 | 22,0 | 47,2 | +9,8 |
| mage | none | 0,7 | 83,7 | 92,8 | 99,1 | 67,5 | 33,3 | 28,8 | 13,3 | 35,7 | — |
| mage | mirror_image | 11,7 | 91,3 | 98,9 | 99,6 | 76,7 | 69,1 | 75,5 | 32,4 | 63,4 | +27,7 |
| mage | molten_armor | 0,0 | 91,0 | 92,7 | 97,6 | 60,3 | 26,2 | 28,2 | 0,0 | 28,7 | -7,1 **sous** |
| mage | water_elemental | 6,0 | 93,3 | 95,4 | 98,5 | 63,5 | 46,7 | 61,5 | 37,5 | 52,3 | +16,6 |
| mage | fingers_of_frost | 1,3 | 88,0 | 93,2 | 98,4 | 60,3 | 33,6 | 42,9 | 19,0 | 39,0 | +3,2 |
| mage | arcane_meditation | 3,0 | 90,3 | 94,8 | 96,9 | 70,7 | 42,0 | 45,9 | 26,5 | 46,3 | +10,5 |
| mage | conflagration | 3,0 | 84,3 | 93,3 | 98,3 | 68,5 | 43,4 | 39,1 | 33,3 | 46,1 | +10,4 |
| mage | rule_of_threes | 7,0 | 93,3 | 93,2 | 98,9 | 66,7 | 51,7 | 60,7 | 38,9 | 54,5 | +18,8 |

Douze épiques **sous** `epic=none` au critère : Sweeping Strikes, Prayer of Mending, Misery, Echo of Light, Shadow
Covenant, Eclipse, Heart of the Wild, Beast Cleave, Lone Wolf, Doomblade, Subterfuge, Molten Armor (Doomblade et
Subterfuge, dont l'écart tenait aux Steppes et à Blackrock peu peuplés, confirmées à 600 : moyenne 4-7 33,2 et 29,9
contre 38,5). Owlkin Frenzy (−6,5 de moyenne, une seule zone sous le seuil) a été traitée avec elles. Titan's Grip
(75,8) et Mirror Image (63,4) restent sous 97 % dans les zones 4 à 7 : non touchées.

### Diagnostic : le bot ou la carte

Contrôle « sans conseils » : la même épique avec `bot.byEpic[id]` vide (le bot construit comme sans épique). S'il
gagne nettement plus, les conseils sont en cause ; s'il ne gagne pas plus, la carte. (Le bot heuristic n'a pas été
employé : un contrôle sans conseils au bot human isole mieux la construction du deck, et le budget de simulations
ne permettait pas les deux.) Moyennes 4-7 à 300 expéditions :

| Épique | Initial | Sans conseils | Cause | Correction (essais intermédiaires) | Après (300) |
|---|---|---|---|---|---|
| Sweeping Strikes | 41,5 | 41,7 | carte | moitié 45,9 ; moitié vers tous 49,0 ; moitié, éveillés 46,6 ; **moitié vers 2 (3) éveillés** | 48,1 |
| Prayer of Mending | 25,8 | 37,3 | bot, puis carte | conseils modérés + dormeurs épargnés 39,4 ; **+ 2 dès la base** | 42,7 |
| Misery | 32,1 | 36,1 | bot, puis carte | conseils modérés + dormeurs 39,3 ; + 1 : 43,4 ; **+ 2** (600 : 42,7) | — |
| Echo of Light | 33,8 | 39,9 | bot et dormeurs | **conseils modérés + dormeurs épargnés** (Swamp 13,5 → 32,6) | 42,7 |
| Shadow Covenant | 16,5 | 18,1 | carte | 1re gratuite 26,3 ; 1 PV par mana 38,8 ; **mana d'abord, PV ensuite** | 43,3 |
| Eclipse | 27,2 | 37,1 | bot | **conseils modérés** 35,1 ; Lunar 3 / 2 et Solar sur toute carte Moonkin : 36,2 à 37,8 (écarté) | 35,1 |
| Owlkin Frenzy | 29,2 | 37,7 | bot, puis carte | Moonfury 2 : 39,0 ; + Barkskin 2 : 38,7 ; **Moonfury 3, Barkskin 3** | 42,2 |
| Heart of the Wild | 25,1 | — | carte | plafond 5, départ 2 : 37,4 ; **plafond 5, départ 3** (Westfall 40 → 98 %) | 41,9 |
| Beast Cleave | 40,2 | — | carte (dormeurs) | **pas de coup à tous tant qu'un ennemi dort** (Swamp 22,8 → 39,3) | 45,7 |
| Lone Wolf | 38,8 | 31,5 | carte | **Ferocity 3** | 49,7 |
| Doomblade | 32,8 | — | carte | hit + DoT 50 % : 35,9 ; **hit + DoT 100 %** | 44,0 |
| Subterfuge | 27,9 | — | bot, puis carte | **conseils modérés** 42,0 ; **+ Parry 1 dès la base** (600 : 46,5) | — |
| Molten Armor | 28,7 | — | bot | **conseils modérés** 35,2 ; **Burn 3** 41,0 (Burn 4 à 600 : pas mieux) | 41,0 |

Trois causes reviennent :
- **Les conseils de construction** (`bot.byEpic[id].rating`, notes absolues tirées du « Deck piloté » des fiches) :
  ils poussaient des cartes faibles au-dessus des meilleures de la classe (Exsanguinate, Shadow Dance de 3 à 9 ou
  10, soins du Prêtre à 8) et écartaient la défense ou le contrôle (Absorb du Prêtre, Frost Nova et Polymorph de 10
  à 6 sous Molten Armor). Dans les zones dures, c'est la défense qui tient : ces notes coûtaient 4 à 11 points.
  Remplacées, pour les épiques touchées, par des notes **modérées** : la note de la classe plus un petit bonus
  (0,5 à 2) pour les cartes que l'épique sert (fonction `lift`, ou fonction locale ; `bot.epic` du Prêtre lit une
  note fonction).
- **Les dormeurs du Swamp of Sorrows** (Asleep : tout dégât réveille, ouverture jouée au réveil) : un coup ou un DoT
  automatique d'épique qui vise au hasard ou tout le monde les réveillait tous (Echo of Light frappe au premier
  tic, Beast Cleave à chaque attaque du familier). Prayer of Mending, Misery, Echo of Light et Sweeping Strikes ne
  visent plus qu'un ennemi éveillé (comme Water Elemental et Shield Charge) ; Beast Cleave ne frappe que la cible
  tant qu'un ennemi dort.
- **Des cartes trop chères ou trop faibles** pour des zones aux ennemis 1,45 à 2,3 fois plus solides : Shadow Covenant
  (payer en PV à 36 PV), Heart of the Wild (plafond 3 et réserves vides : le deck de départ ne remplissait plus la
  réserve de Cat), Doomblade (le coup de grâce ne portait pas), Lone Wolf, Sweeping Strikes, Owlkin Frenzy, Molten
  Armor, Misery et Prayer of Mending (aucun nombre à la base).

### Changements (nom et idée gardés)

| Épique | Avant (base / +1 / +2 / +3) | Après | Nature |
|---|---|---|---|
| Sweeping Strikes | Sweep 1 / 2 / 2 / 2, un tiers | Sweep 2 / 3 / 3 / 3, la moitié, ennemis éveillés | chiffres |
| Prayer of Mending | Divine Star + 0 / 2 / 3 / 4 | + 2 / 3 / 4 / 5, ennemi éveillé ; conseils modérés | chiffres, bot |
| Misery | Contagion + 0 / 1 / 2 / 3 | + 2 / 3 / 4 / 5, ennemis éveillés ; conseils modérés | chiffres, bot |
| Echo of Light | tic sur tous | tic sur les éveillés ; conseils modérés | règle précisée, bot |
| Shadow Covenant | 2 PV par mana (+ 2 par carte Shadow du tour), gratuites 0 / 1 / 1 / 2 | gratuites 1 / 2 / 3 / 4, puis le mana tant qu'il suffit, puis 1 PV par mana (+ 1) ; conseils modérés | **règle réécrite**, bot |
| Eclipse | — | conseils modérés seulement | bot |
| Owlkin Frenzy | Moonfury 1 / 2 / 2 / 3, Barkskin 0 / 0 / 3 / 3 | Moonfury 3 / 4 / 4 / 5, Barkskin 3 / 3 / 5 / 5 ; conseils modérés | chiffres, bot |
| Heart of the Wild | plafond 3 / 4 / 5 / 5, départ 0 / 0 / 0 / 1 | plafond 5, départ 3 / 4 / 4 / 5 (+2 / +3 Kindred : la réserve sans forme aussi) | chiffres |
| Beast Cleave | le familier frappe tout le monde | pas tant qu'un ennemi dort | règle précisée |
| Lone Wolf | Ferocity 2 / 3 / 4 / 5 | 3 / 4 / 5 / 6 | chiffres |
| Doomblade | le coup devient un DoT de 90 / 100 / 105 / 110 % | le coup porte, plus un DoT de 100 / 110 / 120 / 130 % | **règle réécrite** |
| Subterfuge | Parry 0 / 0 / 1 / 2 après un Surge | 1 / 1 / 2 / 3 ; conseils modérés | chiffres, bot |
| Molten Armor | Burn 2 / 4 / 5 / 6 | 3 / 5 / 6 / 7 ; conseils modérés | chiffres, bot |

### Mesure finale (600 expéditions par ligne ; Misery et Subterfuge : série `r2` de la copie de travail, mêmes fichiers)

| Classe | Épique | Vict. | WF | DW | WL | STV | SoS | BS | BRM | moy 4-7 | écart |
|---|---|---|---|---|---|---|---|---|---|---|---|
| warrior | none | 1,5 | 82,7 | 93,1 | 98,3 | 63,4 | 44,8 | 41,9 | 16,7 | 41,7 | — |
| warrior | sweeping_strikes | 3,7 | 95,8 | 97,7 | 100,0 | 66,4 | 45,8 | 44,4 | 28,9 | 46,4 | +4,7 |
| priest | none | 0,8 | 82,7 | 94,6 | 97,0 | 73,4 | 31,4 | 32,4 | 14,7 | 38,0 | — |
| priest | prayer_of_mending | 2,0 | 94,2 | 98,9 | 99,3 | 71,5 | 34,5 | 40,9 | 21,4 | 42,1 | +4,1 |
| priest | misery | 1,7 | 87,8 | 98,7 | 98,5 | 74,6 | 31,7 | 47,1 | 17,5 | 42,7 | +4,7 |
| priest | echo_of_light | 2,2 | 90,8 | 96,9 | 99,2 | 70,4 | 30,4 | 39,3 | 29,5 | 42,4 | +4,4 |
| priest | shadow_covenant | 1,7 | 97,7 | 99,0 | 99,7 | 73,7 | 30,0 | 51,6 | 15,2 | 42,6 | +4,6 |
| druid | none | 0,7 | 79,2 | 93,7 | 99,1 | 65,8 | 38,3 | 32,4 | 11,1 | 36,9 | — |
| druid | eclipse | 0,5 | 80,2 | 94,2 | 98,0 | 61,0 | 41,3 | 32,1 | 8,3 | 35,7 | -1,2 |
| druid | owlkin_frenzy | 1,3 | 94,7 | 98,8 | 99,3 | 68,4 | 46,7 | 37,6 | 11,9 | 41,2 | +4,3 |
| druid | heart_of_the_wild | 1,5 | 98,7 | 99,3 | 99,5 | 70,6 | 45,5 | 39,9 | 12,0 | 42,0 | +5,1 |
| hunter | none | 1,8 | 88,5 | 94,7 | 97,6 | 66,6 | 32,4 | 33,0 | 31,4 | 40,8 | — |
| hunter | beast_cleave | 4,0 | 92,3 | 97,1 | 99,8 | 72,3 | 39,2 | 42,8 | 36,9 | 47,8 | +7,0 |
| hunter | lone_wolf | 6,3 | 97,8 | 97,6 | 98,8 | 69,4 | 48,9 | 48,4 | 40,9 | 51,9 | +11,1 |
| rogue | none | 1,5 | 87,3 | 91,0 | 95,2 | 50,2 | 27,6 | 42,9 | 33,3 | 38,5 | — |
| rogue | doomblade | 2,8 | 98,0 | 97,8 | 98,3 | 58,2 | 46,2 | 46,1 | 24,3 | 43,7 | +5,2 |
| rogue | subterfuge | 4,0 | 99,5 | 99,8 | 99,8 | 69,6 | 36,7 | 41,4 | 38,1 | 46,5 | +8,0 |
| mage | none | 1,2 | 83,8 | 93,2 | 98,5 | 64,9 | 36,7 | 35,5 | 17,9 | 38,8 | — |
| mage | molten_armor | 1,7 | 94,3 | 95,6 | 97,8 | 67,5 | 33,9 | 38,0 | 21,7 | 40,3 | +1,5 |

- **Plus aucune épique touchée sous `epic=none`** au critère (au pire une zone à plus de 5 points : Subterfuge à
  Blackrock −5,1, sur 30 expéditions). Eclipse reste au niveau de l'absence d'épique (−1,2, STV −4,8) : le seul
  défaut trouvé était le bot ; ni Lunar plus bas, ni un bonus de dégâts sur toutes les cartes Moonkin ne l'ont levée
  au-delà de +2 (le Druid gagne ses zones dures par la défense : Mark of Ursol +21, Lifebloom +16).
- **+ 5 points ou plus** : Lone Wolf +11,1, Subterfuge +8,0, Beast Cleave +7,0, Doomblade +5,2, Heart of the Wild +5,1.
  **Entre + 4 et + 5** (dans l'erreur de mesure de la cible) : Sweeping Strikes +4,7, Misery +4,7, Shadow Covenant
  +4,6, Echo of Light +4,4, Owlkin Frenzy +4,3, Prayer of Mending +4,1. **Sous la cible** : Molten Armor +1,5 (+5,3 à
  300 ; Burn 4 à 600 : +0,4, pas mieux), Eclipse −1,2.
- Non touchées et sous + 5 sans être « sous » au critère : King of the Jungle +0,1, Echoing Reprimand +0,0, Trap
  Launcher −1,1 (Blackrock −25 sur 12 expéditions), Black Arrow −1,5, Deflection +2,5, Fingers of Frost +3,2.

Non vérifié : bot heuristic, clés 1 à 5, autres graines, niveaux 2 à 6, épiques gagnées en cours d'expédition (sans
`epic=`), les paliers +1 à +3 (le bot human n'améliore presque jamais l'épique imposée) ; le bonus « l'épique réduit
la dureté » (autre agent) s'ajoutera à ces chiffres. La vue de classe du Guerrier (`UI/Art/warrior.lua`, jeton de
l'épique) écrit encore « splash N others for a third » en dur : à corriger en « for half » (une ligne ; l'interface
n'était pas dans le périmètre), le harnais le signale (1 échec sur 1505).

## Druid : Burning Steppes et Blackrock (19/11/2026)

Constat (`docs/talents.md`, § 4.3 et § 5) : au palier « 60 % de l'arbre » approché, le Druid perdait dans les zones 6
et 7 quand le Warrior passait (Blackrock ≈ 30 % battue / atteinte avec tout, mur à 2,15 / 2,3). Mur des deux zones
baissé à 1,9 (`ns.Zone.HARD`) juste avant ; mesure refaite d'abord. Commande (bot `human`, 600, ± 4) :
`luajit Sim/sim.lua runs=600 bot=human seed=1 jobs=8 runner=expedition key=0 class=druid zones=4 level=7 hp=68
tune=Expedition.START_GOLD=150,Expedition.ZONE_HEAL=0.75,Druid.TAX_FREE=2,Druid.TAX_MAX=1,Druid.STRIKE_BASE=3,Druid.TREE_ABSORB=4,Combat.BASE_MANA=4
[epic=none|<id>] [path=<voie>]` ; Warrior `class=warrior hp=82 tune=Expedition.START_GOLD=150,Expedition.ZONE_HEAL=0.75,Combat.BASE_MANA=4`
(clés de `tune=` vérifiées). Rapports bruts : `reports/db/` du worktree (non versionnés).

**Mesure refaite (état de `main`, mur à 1,9)** : la cible était déjà tenue avec les épiques gagnées (Druid 54,2 %,
Warrior 57,7 ; Blackrock 82,7 %) : les épiques cumulées (sans plafond) et Mark of Ursol suffisaient. Le défaut restait
entier sans épique (Druid 17,0 %, Warrior 29,5 ; Steppes 72,3 contre 86,0, Blackrock 48,8 contre 67,0), avec Eclipse
(17,7 %) et au bot heuristic (300 : Druid 33,3 %, Warrior 64,0).

### Diagnostic

Compteurs par zone ajoutés le temps du diagnostic (dégâts, Absorb, soins, coups reçus et tours par combat des Steppes
et de Blackrock ; retirés ensuite). Sans épique, au palier 60 % :

| Par combat (bot `human`) | Druid : tours / dégâts par tour / coups reçus | Warrior |
|---|---|---|
| Steppes, normal | 3,38 / 37 / 41 | 2,44 / 47 / 27 |
| Steppes, élite | 4,78 / 40 / 66 | 3,67 / 53 / 61 |
| Steppes, boss (Grark Lorkrub) | 5,38 / 44 / 104 | 3,89 / 59 / 67 |
| Blackrock, normal | 3,20 / 37 / 47 | 2,12 / 51 / 29 |
| Blackrock, élite | 4,17 / 41 / 63 | 3,71 / 55 / 54 |
| Blackrock, boss (Nefarian) | 7,20 / 43 / 124 | 4,86 / 64 / 85 |

- **Les combats durent 30 à 50 % de plus.** Les coups reçus par tour sont les mêmes (≈ 17 à 19 au boss) ; le Druid
  en reçoit plus parce qu'il reste plus longtemps. Ses dégâts par tour ne montent presque pas d'une zone à l'autre
  (39 au boss en moyenne de campagne, 44 dans les zones 6 et 7), ceux du Warrior de 45 à 60 : le Warrior empile
  Strength (Battle Shout, Recklessness, Enrage) et ses coups grandissent au fil d'un long combat ; le Druid n'a aucune
  source de Strength et ses dégâts plafonnent avec la réserve (5). Wrath, carte de départ, reste parmi ses cinq
  premières sources de dégâts contre Nefarian.
- **Pas de gros Absorb tardif.** Les coups de ces zones valent 35 à 45 PV (Grark : Heroic Strike 23 × 1,9 = 44,
  Cleave 38, Mortal Strike 36) ; le Druid encaisse avec des cartes à 5 ou 6 Absorb, le Warrior a Shield Wall (18,
  rare : + 28 points de victoires avec / sans, le plus gros écart de ses cartes) et Ignore Pain. Rencontres :
  Grark 76,6 % gagnés (Warrior 89,5), Nefarian 58,6 (73,1), Panzor 85,5 (97,6).
- **La classe gagne ses zones dures par la défense** : épiques imposées au palier 60 %, sans autre épique : Mark of
  Ursol (Absorb tiré des frappes de l'ours) **57,3 %**, Furor 28,8, King of the Jungle 25,7, **Eclipse 17,7** (= sans
  épique). Eclipse n'est plus sous `epic=none` mais n'ajoute rien (gagner un tour sur Starfire et Hurricane).
- **Balance seule s'effondre** : voies seules sans épique, Restoration 21,0 %, Feral 5,7, **Balance 0,3** (Stranglethorn
  31,3, Swamp 19,4, Steppes 36,1, Blackrock 15,4) : ses cartes tardives (Starfall, Nature's Grace, Moonkin Aura)
  n'apportent aucune défense, seulement Insect Swarm (5) et Faerie Fire (3).
- **Pas une règle de zone ni le bot** : Wildfire ne brûle que 3,5 PV par boss des Steppes (Warrior 2,3), Invincible
  de Panzor coupe moins le Druid que le Warrior (12 contre 26 dégâts par combat), le Class Call de Nefarian donne
  au Druid l'état de repli (Demoralized 2) ; le bot heuristic montre le même écart (31 points). Une note de bot
  fausse trouvée en passant : Leader of the Pack était estimé sans son « deal 2 more », passé au palier 1 le 19/11.
  Owlkin Frenzy (épique des Steppes) n'est pas proposable dans cet état (`zones=4`) : non mesurée.

### Essais (sans épique, palier 60 %, un changement à la fois)

| Essai | Victoires | Stranglethorn | Swamp | Steppes | Blackrock |
|---|---|---|---|---|---|
| aucun | 17,0 % | 80,5 | 60,2 | 72,3 | 48,8 |
| Leader of the Pack « deal 2 more » dès la base | 19,2 | 81,0 | 60,9 | 75,2 | 52,0 |
| Starfall 6 → 8 par Charge | 20,2 | 81,9 | 64,1 | 73,5 | 52,6 |
| Moonkin Aura +2 Charges dès la base | 18,0 | 80,7 | 62,0 | 73,2 | 49,5 |
| Moonkin Aura + 4 Absorb | 19,3 | 81,2 | 62,8 | 70,7 | 54,0 |
| Rebirth 12 → 20 | 21,5 | 85,1 | 64,9 | 76,0 | 51,6 |
| Demoralizing Roar + 6 Absorb | 24,7 | 83,4 | 67,8 | 77,4 | 56,7 |
| Demoralizing Roar + 6 Absorb, Cooldown 3 | 26,2 | 83,9 | 68,8 | 78,2 | 58,4 |
| Demoralizing Roar + 8 Absorb | 27,2 | 83,6 | 71,1 | 79,4 | 58,0 |
| + 10 PV (repère, `hp=78`) | 27,2 | 87,5 | 69,2 | 77,3 | 58,2 |
| Roar 8 + Rebirth 16 | 29,8 | 84,9 | 70,4 | 83,1 | 60,5 |
| Roar 8 + Moonkin Aura 4 Absorb (retenu, avant les notes de bot) | 33,2 | 85,4 | 71,9 | 81,4 | 66,8 |
| Roar 6 + Moonkin Aura 4 Absorb | 27,2 | 85,9 | 69,3 | 77,5 | 59,3 |

Les cartes offensives tardives rapportent 1 à 3 points chacune (diluées dans un deck de 40 cartes) ; l'Absorb d'une
carte jouée à chaque cycle en rapporte 8 à 10. Roar 6 au lieu de 8 ne ménage pas les trois premières zones (niveau 7
67,5 contre 68,0 ; heuristic identique) et laisse Blackrock à 59 : 8 retenu.

### Changements

- **Demoralizing Roar** (Bear, inhabituelle, niveau 6, 0 mana, Cooldown 4) : « +1 Frenzy. Gain 8 Absorb. Apply
  Demoralized 2 ⌛ to all » ; +1 Cooldown 3, +2 « +2 Frenzy. », +3 11 Absorb (avant : 4 Absorb au +3 seulement).
  La défense de l'ours contre les gros coups, à côté de Thick Hide et de Frenzied Regeneration.
- **Moonkin Aura** (Power rare, niveau 7) : « End of turn in Moonkin: +1 Charge and gain 4 Absorb. » (+3 : +2
  Charges, 4 Absorb) : la défense tardive de Balance, qui finit ses tours en Moonkin sans l'Absorb de l'ours.
  « gain 4 Absorb » et non « , gain 4 » : le harnais refuse un nombre séparé du mot d'avant au retour à la ligne.
- **Bots** (`Sim/bots.lua`, `POWER_VALUE`) : Moonkin Aura compte ses 4 Absorb (jouée / piochée 83 → 91 %, gardée en
  main 11,5 → 5,6 %) ; Leader of the Pack lit son « deal 2 more » dès le palier 1.
- Aucun chiffre de règle, de forme, d'épique ni de PV ; les deux cartes sont des niveaux 6 et 7 : le compte neuf est
  identique ligne pour ligne.

### Mesures avant / après (bot `human`, 600)

Palier 60 %, battue / atteinte (%) :

| Série | Victoires | Stranglethorn | Swamp | Steppes | Blackrock |
|---|---|---|---|---|---|
| Druid, épiques gagnées : avant | 54,2 % | 85,3 | 80,7 | 95,6 | 82,7 |
| Druid, épiques gagnées : **après** | **62,5 %** | 88,4 | 87,7 | 94,8 | **85,4** |
| Warrior, épiques gagnées | 57,7 % | 82,3 | 83,2 | 94,2 | 89,4 |
| Druid sans épique : avant | 17,0 % | 80,5 | 60,2 | 72,3 | 48,8 |
| Druid sans épique : **après** | **30,5 %** | 85,6 | 71,8 | 80,1 | 62,5 |
| Warrior sans épique | 29,5 % | 79,5 | 64,4 | 86,0 | 67,0 |
| Druid, Eclipse imposée : avant / après | 17,7 / 29,7 % | 76,3 / 82,7 | 62,0 / 68,5 | 69,7 / 80,9 | 53,5 / 64,7 |
| Druid, Balance seule sans épique : avant / après | 0,3 / 3,3 % | 31,3 / 45,0 | 19,4 / 35,8 | 36,1 / 54,2 | 15,4 / 38,5 |

Vétéran sans talents (`zones=7 level=7`, PV de départ, mur à 1,9) : épiques gagnées Druid 19,7 → **29,3 %** (Warrior
28,2) ; sans épique 5,0 → 12,7 % (Warrior 8,8), Stranglethorn / Swamp / Steppes / Blackrock 65,8 / 38,3 / 60,4 /
44,8 → 74,1 / 54,7 / 76,9 / 53,1 (Warrior 63,4 / 44,8 / 68,2 / 60,2).

Rencontres (sans épique, palier 60 %, victoires avant → après ; Warrior) : Grark Lorkrub 76,6 → 84,2 (89,5) ;
Nefarian 58,6 → 69,8 (73,1) ; Panzor 85,5 → 92,9 (97,6) ; Somnus 73,7 → 83,0 (77,7). Les combats ne raccourcissent
pas (Grark 5,1 → 5,2 tours, Nefarian 6,7 → 6,8) : le Druid tient plus longtemps, il ne frappe pas plus vite.

Trois premières zones (`maxzone=wetlands`, battues) : niveau 7 63,3 → **68,0 %** (cible 60–70) ; compte neuf
(`zones=0 level=1`) 54,8 → **54,8 %** (46–58). Bot heuristic, niveau 7 (300) : 97,0 → 98,0 % (± 2 ; plafond 97 %).

- **Cible tenue** : Druid 62,5 % contre 57,7 au Warrior (+ 4,8, à moins de 10 points), Blackrock 85,4 % ≥ 65.
- **Effets de bord** : le Druid passe maintenant devant le Warrior à Stranglethorn et au Swamp (sans épique, 85,6 et
  71,8 contre 79,5 et 64,4 ; vétéran sans talents, Swamp 54,7 pour une cible de mur à 35 sur la moyenne des six
  classes) et reste un peu derrière aux Steppes et à Blackrock : l'Absorb ajouté vaut dans toutes les zones dures,
  pas seulement les deux dernières. Le niveau 7 des trois premières zones monte de 4,7 points, près du haut de sa
  fourchette ; heuristic 1 point au-dessus du plafond, dans l'erreur de mesure.
- **Reste** : le Druid ne gagne toujours pas en vitesse dans les longs combats (aucune Strength, dégâts plafonnés par
  la réserve) ; Eclipse n'ajoute toujours rien (29,7 contre 30,5 sans épique) ; Balance seule reste loin derrière
  Restoration seule dans les zones dures (3,3 % contre 21,0 avant le changement ; Feral et Restoration seules non
  remesurées).
- Non vérifié : Owlkin Frenzy, Lifebloom et Heart of the Wild (zones 5 à 7, absentes de cet état), autres graines,
  clés 1 à 5, niveaux 2 à 6, paliers 30 % et 100 % de l'arbre, les cinq autres classes avec le mur à 1,9.

## Talents du Warrior : courbe par palier (19/11/2026)

Premier arbre codé (`Data/Talents/warrior.lua`, `docs/talents.md`, § 6 et 17), mur des zones 6 et 7 à 1,9 (main
du 19/11). Commande : `flock build/sim-a.lock luajit Sim/sim.lua runner=expedition bot=human class=warrior key=0
seed=1 jobs=8 runs=600 tree=<part> zones=<N> level=<palier>` avec le contenu de chaque palier (`docs/talents.md`,
§ 3) ; « contenu seul » = même commande sans `tree=` ; ± 2 à 4 points. Rapports : `reports/talents/` du worktree.

| Palier (points) | Contenu | Victoires (cible) | Contenu seul | Fiche d'origine | STV | SoS | BS | BRM | XP / exp. |
|---|---|---|---|---|---|---|---|---|---|
| 0 % (0) | `zones=0 level=1` | **0,0 %** (≈ 0) | 0,0 | 0,0 | 8,9 | 11,5 | — | — | 135 |
| 20 % (5) | `zones=2 level=4` | **25,5 %** (≈ 1) | 8,5 | 25,5 | 63,3 | 71,1 | 86,6 | 73,9 | 292 |
| 40 % (10) | `zones=3 level=7` | **23,0 %** (≈ 15) | 8,2 | 50,2 | 74,4 | 65,8 | 77,9 | 61,3 | 323 |
| 60 % (15) | `zones=4 level=7` | **61,2 %** (≥ 40) | 24,8 | 86,5 | 87,3 | 83,7 | 93,4 | 89,7 | 384 |
| 80 % (20) | `zones=6 level=7` | **82,3 %** (≈ 55) | 26,2 | 89,7 | 96,7 | 92,1 | 97,9 | 94,5 | 422 |
| 100 % (24) | `zones=7 level=7` | **94,3 %** (65–70) | 28,2 | 89,0 | 99,8 | 96,0 | 99,7 | 98,8 | 438 |

STV … BRM : battue / atteinte (%) de Stranglethorn Vale, Swamp of Sorrows, Burning Steppes, Blackrock Mountain.
« Fiche d'origine » : mêmes séries avec les chiffres du § 6 de la fiche, avant réglage.

**Nœuds seuls** au contenu du palier 60 % (600, contenu seul 24,8 %), chiffres de la fiche : Toughness 3 36,5 ;
Battle Ready 2 27,2 ; **Second Wind 2 50,7** ; Unbridled Wrath 2 24,7 ; **Anger Shield 2 38,0** ; Provisions 28,7 ;
Specialization Fury (3 Rage) 30,0 ; Blood Drinker 2 33,7 ; Tactical Mastery 2 25,7 ; Field Medic 27,2 ; Rampage 2
30,2 ; Unyielding 2 27,7. Deux nœuds dépassaient la règle « plus de 10 points seul = trop fort » (§ 15) : Second Wind
(+26) et Anger Shield (+13). Au palier 100 % : Veteran's Arsenal 1 seul **61,2 %** (+33 : Titan's Grip au départ).

**Génériques seuls** (Toughness 3 + Provisions) au palier 60 % : **43,0 %** ; avec +1 mana chaque tour
(`tune=Combat.BASE_MANA=4`, l'ordre de grandeur que la fiche donnait aux nœuds de mécanique des rangées 1 à 3) :
53,0 %. Au palier 100 % : Toughness 3 + Provisions + Field Medic 57,3 % ; avec Veteran's Arsenal 2 **91,0 %**.

**Chiffres changés** (nœuds de mécanique seulement ; ni le mur, ni les génériques) : Second Wind `1 / 2 PV par Rage`
→ `1 PV par 5 / 4 Rage` ; Anger Shield `1 Absorb par 2 Rage / par Rage` → `par 5 / 4 Rage` ; Specialization Fury
à **5** Rage au lieu de 3 ; Blood Drinker `soin 1 / 2 à chaque dépense` → rang 1 `soin 1 à chaque Spend payé`, rang 2
`soin 1 à chaque dépense` (Surge compris). Valeur ajoutée aux génériques au palier 60 % après réglage (400, ± 5) :
Battle Ready 2 +4,5, Second Wind 2 et Anger Shield 2 +3,5 chacun (mesurés à « par 5 / 3 Rage », un cran au-dessus des
chiffres retenus), Blood Drinker 2 +4,8, Fury +2,5, Unbridled Wrath 2 +0,8 ;
les trois voies au palier 60 % : Arms 62,8 %, Fury 61,2 %, Protection 61,7 %. Bot : accord des épiques avec l'arbre
(`bot.epic`, `thunderous_roar = -4`…) : sans lui, le bot prenait Thunderous Roar et Anger Management au départ
(Veteran's Arsenal) et l'arbre plein tombait à 72 % (86 % sans Veteran's Arsenal).

Lecture :

- **0 % et 60 % tenus** (0 victoire au compte neuf ; 61 % ≥ 40 %). Les autres paliers sont **au-dessus** de la cible,
  et ce n'est plus l'arbre : le **contenu seul** fait déjà 8,5 % au palier 20 % (cible 1 %) et 25 à 28 % aux paliers
  60 à 100 % (la fiche comptait 7,2 % pour un vétéran tout débloqué sans talents : depuis, mur des zones 6 et 7 à 1,9
  et réglage des épiques une par une).
- **Les génériques suffisent à passer les cibles hautes** : 43 % au palier 60 %, 91 % au palier 100 % sans aucun
  nœud de mécanique ; Veteran's Arsenal pèse le plus (une épique au départ = +33 points, deux = la clé 0 résolue).
  Aucun réglage des nœuds de mécanique ne ramène le palier 100 % vers 65–70 % : les nœuds de mécanique des rangées 1
  à 3 valent maintenant +1 à +5 points chacun (≈ +18 ensemble, la fiche visait +10), ceux des rangées 3 et 4
  (Tactical Mastery, Rampage, Unyielding) +1 à +5.
- **À trancher** (hors périmètre de ce lot) : Veteran's Arsenal plus faible (une épique au choix parmi deux tirées,
  rang 2 = une amélioration de l'épique au lieu d'une seconde épique) ou plus tard dans l'arbre ; Toughness à +3 par
  rang (+12 PV valent +12 points au palier 60 %) ; ou laisser la clé 0 facile à l'arbre plein et recaler les clés
  1 à 5 (§ 9 de la fiche) avec `tree=100 key=N`.
- **Rythme** : l'expérience par expédition monte plus vite que l'estimation du § 1.2 (292 dès 20 % de l'arbre au lieu
  de ≈ 185) : 60 % de l'arbre arrive vers la 7e ou 8e expédition plutôt que la 10e.

Non vérifié : bot heuristic ; autres graines ; clés 1 à 5 ; l'arbre du Druid (lot 3, à venir) ; le chiffre « Westfall,
épique à l'entrée » du tableau « Par zone » ne compte pas les épiques de Veteran's Arsenal (prises après l'entrée :
phase `start`).

## Talents du Rogue : courbe par palier (19/11/2026)

Arbre codé (`Data/Talents/rogue.lua`, `docs/talents.md`, § 8), mur des zones 6 et 7 à 1,9. Commande : `flock
build/sim-b.lock luajit Sim/sim.lua runner=expedition bot=human class=rogue key=0 seed=1 jobs=8 runs=600
tree=<part> zones=<N> level=<palier>` avec le contenu de chaque palier (`docs/talents.md`, § 3) ; « contenu seul » =
même commande sans `tree=` ; ± 2 à 4 points. Rapports : `reports/talents/rogue/` du worktree.

| Palier (points) | Contenu | Victoires (Warrior, cible ± 8) | Contenu seul | Fiche d'origine | STV | SoS | BS | BRM | XP / exp. |
|---|---|---|---|---|---|---|---|---|---|
| 0 % (0) | `zones=0 level=1` | **0,0 %** (0,0) | 0,0 | 0,0 | 2,6 | 0,0 | — | — | 157 |
| 20 % (5) | `zones=2 level=4` | **2,0 %** (25,5) | 0,3 | 6,0 | 53,1 | 20,7 | 56,1 | 37,5 | 233 |
| 40 % (10) | `zones=3 level=7` | **38,0 %** (23,0) | 12,8 | 68,5 | 84,3 | 69,2 | 86,8 | 77,0 | 345 |
| 60 % (15) | `zones=4 level=7` | **67,8 %** (61,2) | 8,7 | 91,7 | 94,8 | 81,5 | 95,3 | 92,1 | 398 |
| 80 % (20) | `zones=6 level=7` | **89,7 %** (82,3) | 17,2 | — | 99,0 | 94,1 | 99,1 | 97,1 | 432 |
| 100 % (24) | `zones=7 level=7` | **98,3 %** (94,3) | 18,3 | — | 100 | 99,3 | 100 | 99,0 | 445 |

STV … BRM : battue / atteinte (%). « Fiche d'origine » : premier arbre codé, chiffres et rangées du § 8 de la fiche
(Initiative et Elusiveness 2 rangs en rangée 1, Opportunity +2 / +4, Combat Readiness +2 / +4, Relentless Strikes
+1 / +2 Combo après chaque Surge, Toughness +3 PV par rang).

**Specialization** au palier 60 % : Combat (voie du bot) 67,8 %, Assassination 70,0 %, Subtlety 64,7 % (écart 5,3).

**Génériques seuls** (Toughness 3 + Provisions) : 23,0 % au palier 40 (contenu seul 12,8), 23,0 % au palier 60 (8,7).
**Veteran's Arsenal 2 seul** au palier 100 : 44,3 % (+26) ; arbre plein sans Veteran's Arsenal 92,5 % (avec : 98,3) :
pas d'accord d'épiques à poser (`bot.epic`).

**Nœuds de mécanique pleins, seuls**, au palier de leur rangée (rangées 1 et 2 : palier 20 ; rangée 3 : 40 ; rangée
4 : 80) ; entre parenthèses, l'écart au contenu seul :

| Nœud (rangée) | Palier | Seul | Avant réglage |
|---|---|---|---|
| Opportunity 2 (1) | 20 | 0,8 (+0,5) | 2,3 (+2,0) à +2 / +4 |
| Deeper Stratagem 2 (1) | 20 | 0,5 (+0,2) | — |
| Vile Poisons 1 (2) | 20 | 0,3 (0) | — |
| Combat Readiness 3 (2) | 20 | 1,3 (+1,0) | rang 2 à +4 : 29,2 au palier 40 (**+16,4**) |
| Elusiveness 1 (3) | 40 | 23,2 (+10,4) | 2 rangs : 31,2 (**+18,4**) |
| Initiative 2 (3) | 40 | 22,2 (+9,4) | +1 / +2 à chaque combat : 26,2 (**+13,4**) |
| Lightning Reflexes 1 (3) | 20 | 0,2 (−0,1) | — |
| Relentless Strikes 2 (4) | 80 | 27,3 (+10,1) | +1 / +2 après chaque Surge : 37,5 (**+20,3**) ; 27,7 au palier 40 (+14,9) |
| Cheat Fate 2 (4) | 80 | 19,7 (+2,5) | — |

Au palier 20, le contenu seul (0,3 %) est au plancher : les nœuds y bougent peu les victoires. Mesurés sur Toughness 3
(+3 PV par rang, 22,5 %) au palier 40 : Vile Poisons +8,5, Opportunity 2 (+1 / +2) +4,3, Provisions +4,7, Deeper
Stratagem 1 +1,0, Initiative 1 +7,2, Elusiveness 1 +12,2 ; Vile Poisons à +2 par pose, +18.

**Chiffres changés** par rapport à la fiche : Toughness +3 → **+2 PV par rang** (nombre propre à l'arbre du Rogue ;
`Data/Talents/common.lua` inchangé) ; Opportunity 4 → **1 par rang et par coup** ; Combat Readiness (Riposte Training)
`11 dégâts` → **+1 par rang, 3 rangs** (9 / 10 / 11) ; Elusiveness et Lightning Reflexes (Deflection) **un rang** ;
Initiative (Premeditation) rang 2 **+2 seulement contre élites et boss** ; Relentless Strikes rang 1 **après un Surge
de 5 Combo ou plus** ; Elusiveness et Initiative passent en rangée 3, Relentless Strikes en rangée 4, Deeper
Stratagem en rangée 1 (2 rangs), Cheat Fate rang 1 Parry 2, rang 2 Parry 3 et Stealth.

Lecture :

- **0 % et 60 % tenus** (0 victoire au compte neuf ; 67,8 % ≥ 40 %, dans la bande du Warrior, 61,2 ± 8) ; les trois
  voies se tiennent à 5 points ; aucun nœud de mécanique ne vaut plus de 12 points seul (Elusiveness +10,4 au plus).
- **20 % et 40 % hors de la bande, dans des sens opposés, et ce n'est pas l'arbre** : le contenu seul du Rogue vaut
  0,3 % au palier 20 (Warrior 8,5) mais 12,8 % au palier 40 (Warrior 8,2) et la classe réagit très fort au moindre
  gain près du mur. Les génériques seuls (Toughness 3 + Provisions) font déjà **23,0 %** au palier 40, la cible du
  Warrior ; tout point de mécanique la dépasse. Inversement, cinq points qui donnent 12,5 % au palier 20 (Elusiveness
  2, Initiative 2, Toughness 1) donnent 50 % au palier 40 : aucun ordre ne tient les deux bandes. Choix : tenir 40
  au plus près (38,0, +7 au-dessus de la bande) et 60, au prix du palier 20 (2,0 %).
- **80 et 100 %** au-dessus du Warrior (89,7 et 98,3 contre 82,3 et 94,3) : à recaler avec les génériques pour toutes
  les classes (Veteran's Arsenal pèse +26 seul).
- **Rythme** : 233 d'expérience par expédition au palier 20, 345 au palier 40 (Warrior 292 et 323).

Non vérifié : bot heuristic ; autres graines ; clés 1 à 5.

## Talents du Mage (19/11/2026)

Arbre codé (`Data/Talents/mage.lua`, `docs/talents.md`, § 8), mêmes séries que le Warrior : `flock build/sim-a.lock
luajit Sim/sim.lua runner=expedition bot=human class=mage key=0 seed=1 jobs=8 runs=600 tree=<part> zones=<N>
level=<palier>` ; « contenu seul » = sans `tree=` ; ± 2 à 4 points. Rapports : `reports/talents-mage/` du worktree
(v1 = fiche d'origine, v7 = arbre final).

| Palier (points) | Contenu | Victoires (cible Warrior ± 8) | Contenu seul | Warrior | Fiche d'origine | STV | SoS | BS | BRM | XP / exp. |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 % (0) | `zones=0 level=1` | **0,0 %** (0–2) | 0,0 | 0,0 | 0,0 | 9,3 | 0,0 | — | — | 144 |
| 20 % (5) | `zones=2 level=4` | **0,7 %** (17,5–33,5) | 0,0 | 25,5 | 1,0 | 43,0 | 15,4 | 37,0 | 40,0 | 196 |
| 40 % (10) | `zones=3 level=7` | **31,0 %** (15–31) | 10,0 | 23,0 | 61,2 | 84,9 | 62,2 | 86,1 | 73,5 | 323 |
| 60 % (15) | `zones=4 level=7` | **60,3 %** (53–69, ≥ 40) | 8,3 | 61,2 | 81,2 | 92,4 | 81,3 | 95,3 | 85,6 | 386 |
| 80 % (20) | `zones=6 level=7` | **87,7 %** (non réglé) | 12,7 | 82,3 | 94,5 | 98,0 | 94,2 | 99,1 | 96,0 | 429 |
| 100 % (24) | `zones=7 level=7` | **97,7 %** (non réglé) | 17,0 | 94,3 | 99,0 | 99,8 | 98,8 | 99,7 | 99,3 | 443 |

STV … BRM : battue / atteinte (%) de Stranglethorn Vale, Swamp of Sorrows, Burning Steppes, Blackrock Mountain.
« Fiche d'origine » : premier arbre codé d'après le § 8 de la fiche (Arcane Focus 2, Frost Warding 2 par carte, Winter's
Chill 2 et Arcane Mind 2 en rangée 2, Prismatic Cloak 2 / 4 Absorb, Firestarter 2, Toughness 3 PV par rang).

**Specialization au palier 60 %** (`spec=`) : Fire **60,0 %**, Frost **64,0 %** (Demoralized 1 au premier ennemi ;
69,5 % à tous les ennemis), Arcane **60,3 %** (voie du bot).

**Nœuds de mécanique seuls**, pleins, au contenu du palier de leur rangée (rangée 1 → 20 %, 2 → 40 %, 3 → 60 %, 4 →
80 %) :

| Nœud | Palier | Seul | Contenu seul | Écart |
|---|---|---|---|---|
| Arcane Mind 3 | 20 % | 0,0 % (STV 35,4, SoS 14,7) | 0,0 % (35,0, 12,3) | +0 |
| Arcane Concentration 3 | 40 % | 15,5 % | 10,0 % | +5,5 |
| Winter's Chill 2 | 60 % | 13,8 % | 8,3 % | +5,5 |
| Prismatic Cloak 1 | 60 % | 11,3 % | 8,3 % | +3,0 |
| Arcane Focus 1 | 60 % | 11,0 % | 8,3 % | +2,7 |
| Frost Warding 1 | 60 % | 12,5 % | 8,3 % | +4,2 |
| Firestarter 1 | 80 % | 17,3 % | 12,7 % | +4,6 |
| Arcane Potency 2 | 80 % | 13,8 % | 12,7 % | +1,1 |
| Cauterize 2 | 80 % | 21,5 % | 12,7 % | +8,8 |

Aucun au-dessus de 12 points. Générique : Veteran's Arsenal 2 seul au palier 100 % 29,3 % (+12,3). Génériques seuls
(Toughness 3 à 2 PV + Provisions) au palier 40 % : 18,0 %.

**Chiffres changés** par rapport au § 8 de la fiche (nœuds du Mage seulement) :

- Toughness : +2 PV par rang au lieu de +3 (+9 PV = 21 % des 42 PV du Mage ; Warrior +12 sur 70).
- Arcane Focus : un rang (+1 Charge), rangée 3 au lieu de la rangée 1 à deux rangs ; seul au palier 40 % à deux rangs,
  il valait +22 points dans l'arbre (56 % → 34 % sans lui).
- Frost Warding (proposé « Ice Barrier », +2) : un rang, +1, rangée 3 ; à deux rangs en rangée 1 : +20 points dans
  l'arbre au palier 40 %.
- Arcane Mind : trois rangs (plafond 7) en rangée 1 ; seul, il ne fait rien de mesurable.
- Arcane Concentration (nouveau) : `After each Surge: +1 / +2 / +3 Charges.`, rangée 2.
- Prismatic Cloak (proposé « Arcane Shielding », 3 Absorb) : un rang, 2 Absorb.
- Firestarter (proposé « Presence of Mind ») : un rang, rangée 4 (deux rangs en rangée 2 : +10 points dans l'arbre).
- Winter's Chill (proposé « Shatter », +3 par coup) : +1 par rang, rangée 3.
- Arcane Potency (nouveau, comme Rampage) en rangée 4 ; Improved Ignite et Triple Cast retirés.
- Specialization : Fire `Fire Attack hits also apply DoT 1.` (au lieu de Hot Streak +1 Charge) ; Frost au premier
  ennemi au lieu de tous ; voie du bot Arcane.

Étapes (t40 / t60, voie Frost sauf la dernière) : fiche 61,2 / 81,2 → Toughness 2, Cloak 1 et ordre changé 56,0 /
76,0 → Focus et Ward à un rang 48,3 / 69,8 → Firestarter en rangée 2, Winter's Chill en rangée 3 45,5 / 67,5 → Focus
et Ward en rangée 3, Arcane Concentration 38,2 / 76,0 → Arcane Mind 3, Cloak à un rang 31,0 / 69,5 → voie Arcane
60,3.

Lecture :

- **0, 40 et 60 % tenus** (60 % : 60,3 contre 61,2 au Warrior). Le palier 40 % est au bord haut de la fenêtre (31,0
  pour 31) : les nœuds des rangées 1 et 2 ne peuvent guère valoir moins (un rang = une Charge, un Absorb, un Instant).
- **Palier 20 % hors cible** (0,7 % pour 17,5 à 33,5) et ce n'est pas l'arbre : le **contenu du palier** (`zones=2
  level=4`) ne fait gagner aucun Mage (Swamp of Sorrows passée à 12 %, Warrior 8,5 % de victoires au même contenu).
  Aucun jeu de 5 points ne passe de 0 à ≈ 20 % sans faire exploser le palier 40 % (contenu 10 %, niveau 7) : avec
  Arcane Focus 2 et Toughness 3 dans les 5 premiers points (fiche), le palier 20 % ne donnait que 1,0 % et le palier
  40 % 61 %. Le contenu seul passe de 0 à 10 % entre ces deux paliers.
- **Le Mage est très sensible près du mur** : chaque nœud seul vaut +3 à +9 points, mais ensemble ils s'additionnent
  bien plus (+51 points pour les 10 points de la fiche au palier 40 %) ; le palier 80 % (87,7) et 100 % (97,7) passent
  le Warrior de 5 et 3 points, à recaler avec les génériques comme prévu.
- Bots : aucune épique ne contredit l'arbre plein (palier 100 % > 80 %) : pas de `bot.epic`.

Non vérifié : bot heuristic ; autres graines ; clés 1 à 5 ; chiffres d'interface (Arcane Mind et la pastille à quatre
pips : `docs/talents.md`, § 15, « Lisibilité »).

## Talents du Priest : courbe par palier (19/11/2026)

Arbre codé (`Data/Talents/priest.lua`, `docs/talents.md`, § 8 et 17), mur des zones 6 et 7 à 1,9. Commande :
`flock build/sim-b.lock luajit Sim/sim.lua runner=expedition bot=human class=priest key=0 seed=1 jobs=8 runs=600
tree=<part> zones=<N> level=<palier>` avec le contenu de chaque palier (`docs/talents.md`, § 3) ; « contenu seul » =
même commande sans `tree=` ; ± 2 à 4 points. Rapports : `reports/talents/priest/` du worktree.

| Palier (points) | Contenu | Victoires (Warrior) | Contenu seul | Fiche d'origine | STV | SoS | BS | BRM |
|---|---|---|---|---|---|---|---|---|
| 0 % (0) | `zones=0 level=1` | **0,0 %** (0,0) | 0,0 | 0,0 | 37,6 | 1,4 | — | — |
| 20 % (5) | `zones=2 level=4` | **24,5 %** (25,5) | 4,7 | 11,8 | 94,3 | 53,3 | 84,4 | 60,2 |
| 40 % (10) | `zones=3 level=7` | **29,7 %** (23,0) | 4,5 | 22,2 | 93,1 | 60,8 | 87,9 | 59,9 |
| 60 % (15) | `zones=4 level=7` | **55,7 %** (61,2) | 4,5 | 45,5 | 98,2 | 77,1 | 93,2 | 79,0 |
| 80 % (20) | `zones=6 level=7` | **67,0 %** (82,3) | 6,7 | — | 99,5 | 83,6 | 96,8 | 83,2 |
| 100 % (24) | `zones=7 level=7` | **79,0 %** (94,3) | 7,5 | — | 98,3 | 86,3 | 99,6 | 93,5 |

STV … BRM : battue / atteinte (%) de Stranglethorn Vale, Swamp of Sorrows, Burning Steppes, Blackrock Mountain.
« Fiche d'origine » : premier jet (nœuds et chiffres du § 8 de la fiche, Toughness +2 par rang), avant réglage.
Paliers 80 et 100 % mesurés, pas réglés (recalage des génériques à venir pour toutes les classes).

**Specialization au palier 60 %** : Discipline **55,7 %** (voie du bot), Shadow 51,5 %, Holy 52,0 % (écart 4,2
points). Premier jet : Discipline 45,5, Shadow 33,3, Holy 31,5 (Shadow « DoT +1 » et Holy « soin de 3 à chaque Cast »
ne valaient rien seuls).

**Nœuds de mécanique pleins seuls**, au contenu du palier de leur rangée (contenu seul : 4,7 % au palier 20, 4,5 %
aux paliers 40 et 60, 6,7 % au palier 80), chiffres retenus : rangée 1 (palier 20) Twin Disciplines 2 7,8 (+3,1),
Borrowed Time 2 5,0 (+0,3) ; rangée 2 (palier 40) Mind Spike 2 7,2 (+2,7), Shadow Weaving 6,8 (+2,3), Inspiration 7,2
(+2,7) ; rangée 3 (palier 60) Discipline 12,8 (+8,3), Shadow 9,7 (+5,2), Holy 13,0 (+8,5), Power Word: Barrier 2 12,2
(+7,7), Void Torrent 2 5,0 (+0,5) ; rangée 4 (palier 80) Spiritual Guidance 2 8,3 (+1,6), Guardian Spirit 2 7,7
(+1,0). Aucun au-dessus de 12 points ; deux l'étaient en cours de réglage et ont été baissés : Discipline à 3 Absorb
17,8 (+13,3) et Power Word: Barrier à +3 par rang 17,5 (+13,0). Veteran's Arsenal 2 seul au palier 100 : 10,2 %
(+2,7) ; arbre plein sans Veteran's Arsenal 77,8 % (avec : 79,0).

**Chiffres changés** par rapport à la fiche : Twin Disciplines `3 au lieu de 2` (1 rang) → **+2 par rang** (4 puis 6),
déplacé en rangée 1 ; Borrowed Time `Sacred Candle à Atonement 2` → **Atonement 2 par rang au début du combat** ;
Mind Spike `+1 Insanity` → **+2 par rang**, en rangée 2 ; Inspiration `Regen gagnée +1` → **Regen 4 au début du
combat** ; Power Word: Barrier `+2` (1 rang) → **+2 par rang** (2 rangs) ; Spiritual Guidance 2 rangs (3 / 5 Absorb) ;
Specialization Discipline `1 Absorb` → **2**, Shadow `DoT +1` → **+5 par coup et +5 DoT des cartes Shadow**, Holy `Cast
cards heal 3 more` → **+8 par coup des cartes Holy** ; Guardian Spirit rang 2 : Regen 6 en plus. Toughness : +2 PV par
rang (36 PV, même part que le Warrior et le Druid). Étapes (palier 60, Discipline) : 45,5 (premier jet) → 47,3 (Twin
+2 par rang) → 49,5 (Barrier +2, Holy +5) → 54,0 (Borrowed Time 2, Discipline 3, Shadow 4, Holy 6) → 53,7 (Barrier
+3, Shadow 5, Holy 8) → 56,2 (Inspiration Regen 3) → 55,7 retenu (Barrier +2, Discipline 2, Inspiration Regen 4 : les
deux nœuds trop forts seuls ramenés sous 12 points).

**Bots** : valeur d'Atonement relevée en combat (`bot.value` de Twin Disciplines et de Discipline : chaque tour
d'Atonement compté en proportion du soin) : 22,8 % au palier 20 et 53,8 % au palier 60 (sans : 24,5 et 55,7),
retirée ; accord des épiques `{ voidform = -1, reflective_shield = 1 }` au palier 100 : 76,7 % (sans : 79,0),
retiré. L'Absorb, la Regen, l'Insanity et l'Atonement des nœuds se voient déjà dans l'évaluation commune.

Lecture :

- **Paliers 0, 20, 40 et 60 tenus** : 0,0 % au compte neuf ; 24,5 % (Warrior 25,5) ; 29,7 % (23,0 ; + 6,7, dans les
  ± 8) ; 55,7 % (61,2 ; − 5,5, au-dessus de 40). Les trois voies se tiennent à 4,2 points.
- **Le contenu seul du Priest est très bas** (4,5 à 7,5 % des paliers 20 à 100, Warrior 8,5 à 28,2) : le mur du Priest
  est le Swamp of Sorrows (31 à 39 % battue / atteinte sans talents, Somnus ≈ 59 %). L'arbre en apporte presque tout
  (Swamp 77 % au palier 60) ; les nœuds qui pèsent sont ceux de survie (Atonement, Absorb, Regen), ceux de
  l'Insanity (Mind Spike, Shadow Weaving, Void Torrent) valent 0 à 3 points seuls.
- **Paliers 80 et 100 sous le Warrior** (67,0 et 79,0 % contre 82,3 et 94,3) mais au-dessus des cibles de la fiche
  (≈ 55 et 65–70 %) : Veteran's Arsenal vaut peu au Priest (+5 dans l'arbre plein ; épiques du Priest faibles au
  Swamp, « Épiques : mesure une par une »).

Non vérifié : bot heuristic ; autres graines ; clés 1 à 5 ; XP par expédition (non relevée) ; l'ordre du bot passe
Shadow Weaving avant Inspiration (palier 40 : 29,7 % ; avec Inspiration Regen 3 à la place, 32,0 %).
