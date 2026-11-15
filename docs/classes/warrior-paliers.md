# Warrior — paliers d'amélioration +2 et +3 (15/11/2026)

Décision du joueur du 15/11/2026 (`docs/zones/decisions.md`, « Améliorer une carte plusieurs fois ») ; forme des
données et règles : `docs/ameliorations.md`. Données : `Data/Warrior.lua` (`up2`, `up3` de chaque carte) ; nombres des
épiques par palier : `ns.Warrior.EPIC` (tables `{ base, +1, +2, +3 }` lues par `Warrior.num(id, clé, src)`,
`Core/Classes/warrior.lua`). Tests : `Sim/tests_epic_warrior.lua` (épiques), `Sim/tests.lua` (section « Paliers du
Guerrier »).

Le Guerrier est déjà la classe la plus forte de la campagne : ses paliers 2 et 3 restent dans le bas de la fourchette
(la moitié du gain du +1 ou moins), surtout sur Strength, la Rage et les cartes à plusieurs coups. Un coût baisse au
plus une fois ; les Powers gagnent un coût à 0 puis Innate (rien de multiplié) ; Retain et Innate servent de gains
« sentis » sans nombre de plus.

## Cartes

| Carte | +1 | +2 | +3 |
|---|---|---|---|
| Strike | Deal 9 | Deal 11 | Sundered : 3 de plus |
| Defend | 8 Absorb | 10 Absorb | Retain |
| Heroic Strike | 9, Spend 2 : +7 | 10, Spend 2 : +9 | Spend 2 : pioche 1 aussi |
| Bloodrage | +3 Rage | Innate | Pay 1 HP |
| Rend | 4, DoT 6 | DoT 7 | Deal 7 |
| Overpower | 5, Sundered +5 | 6, Sundered +6 | Sundered +8 |
| Slam | Cast, 20 | Cast, 23 | Sundered : 6 de plus |
| Cleave | 11 à tous | 13 à tous | 15 à tous |
| Mortal Strike | 28, Sundered 3 | 32 | Sundered 4 |
| Execute | 7, 5 par Rage | Retain | Deal 10 |
| Colossus Smash | 8, Sundered 4 | Deal 11 | Draw 1 |
| Pummel | 5, Cooldown 1 | Deal 7 | Interrupt all casts |
| Bladestorm | 6 × 3 à tous | 7 × 3 | 8 × 3 |
| Deep Wounds | DoT 2 | coût 0 | Innate |
| Raging Blow | 7 × 2 | 8 × 2 | 9 × 2 |
| Whirlwind | 5 × 2 à tous | Retain | 6 × 2 à tous |
| Victory Rush | 5, soin 6 | soin 8 | Deal 8 |
| Berserker Rage | +3 Rage | Innate | +4 Rage |
| Bloodthirst | 8, soin 3 | Deal 10 | soin 5 |
| Rampage | 5 × 4 | Pay 2 HP | Pay 1 HP |
| Battle Shout | Strength 3 | Innate | coût 0 |
| Onslaught | Deal 13 | Deal 15 | Spend 1 : pioche 2 |
| Enrage | coût 0 | Innate | +2 Rage en jeu |
| Recklessness | Strength 4 | coût 0 | Pay 1 HP |
| Shield Block | 11 Absorb | 13 | 15 |
| Revenge | Deal 9 | Deal 11 | 11 à tous |
| Thunder Clap | 5 à tous, Demoralized 2 | 7 à tous | Demoralized 3 |
| Devastate | 10, 5 Absorb | 12, 6 Absorb | Sundered 1 |
| Demoralizing Shout | Cooldown 3 | Demoralized 3 | Innate |
| Shield Slam | 6 Absorb | 7 Absorb | Retain |
| Ignore Pain | 4 par Rage | + 3 Absorb fixes | Retain |
| Retaliation | 6 par coup | coût 0 | Innate |
| Shield Wall | 24 Absorb | 28 | Retain |
| Last Stand | coût 0 | soin 20 | Innate |

## Épiques

Une épique tient en deux lignes de texte : Death Wish (déjà deux lignes au +1) ne change que ses nombres ; les
autres gagnent au plus une ligne « Kills: » (déclencheur déjà employé par Death Wish). L'à-côté d'un mot de règle n'a
qu'un texte amélioré (`L.ruleText`) : les nombres qui changent aux paliers 2 et 3 passent par le nombre de la carte
(`N`) ; Haste dit désormais « return N turns sooner » une fois amélioré.

| Épique | +1 | +2 | +3 |
|---|---|---|---|
| Death Wish | Kills : soin 3 | soin 5 | Carnage 60 % |
| Thunderous Roar | Shockwave 4 (+ Demoralized 1) | Shockwave 5 | Shockwave 6 |
| Sweeping Strikes | Sweep 2 | Kills : +1 Rage | Kills : +2 Rage |
| Titan's Grip | 0-cost free | Kills : soin 4 | soin 6 |
| Shield Charge | Punish +4 | +6 | +8 |
| Anger Management | Haste 2 | Kills : +1 Rage | Haste 3 |
| Avatar | Juggernaut 3 | Juggernaut 4 | Kills : soin 3 |

## Mesures (15/11/2026)

**Les paliers n'ont pas été mesurés carte par carte** : les balayages `sweep=cards up=2` / `up=3` ont été abandonnés sur
consigne (≈ 25 000 campagnes par classe). Seuls repères partiels :
- balayage `up=1` au bot `heuristic`, Duskwood seule (300 par ligne, sans carte 77 %) : référence du palier 1 ;
- balayage `up=2` au bot `human`, campagne complète, interrompu après 23 cartes sur 34 (200 par ligne, ± 7 points,
  sans carte 80,5 %) : aucun palier 2 hors norme ; les plus faibles sont Berserker Rage+2 (+1,0, Innate) et Slam+2
  (+2,0), les plus forts Victory Rush+2 (+18,0), Devastate+2 (+17,0), Bloodthirst+2, Shield Block+2, Thunder Clap+2
  (+16,0), dans la fourchette des cartes au palier 1.

Campagne (bot `human`, clé 0, `zones=7 level=7`, 600 expéditions), avant → après : **86,2 → 85,8 %** (± 2,8, écart
nul) ; PV perdus par type de combat inchangés. Améliorations par palier : +1 4,60, **+2 0,08**, +3 0,00 par
expédition : le bot `human` améliore presque toujours une nouvelle carte (note du palier 2 × 0,8) et n'atteint
presque jamais le palier 2 ; l'effet des paliers 2 et 3 sur la campagne n'est donc pas mesurable ainsi. Écarts
« vict. avec / sans » du tableau des cartes : dans la norme du rapport d'avant (biais de survie), rien d'anormal.

À surveiller si le joueur monte souvent ses cartes : Revenge+3 (11 à tous pour 0 après un coup reçu), Battle Shout+3
(Strength 3 gratuite en main de départ), Deep Wounds+3 et Retaliation+3 (Power gratuit en main de départ),
Death Wish+3 (Carnage 60 %), Avatar+2 (+4 Rage par tour).
