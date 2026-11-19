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
