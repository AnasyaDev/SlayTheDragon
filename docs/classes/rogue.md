# Rogue — fiche de conception

Fiche prête à implémenter. Elle développe la section « Rogue » du GDD des classes (Claude Docs) sans la
contredire ; les chiffres sont des points de départ calés sur le Priest (`Data/Priest.lua`) et seront
réglés par simulation. Textes de jeu en anglais, tels qu'affichés. « DoT » est l'état de dégâts sur la
durée (`pain` / « Pain » dans le code actuel, à renommer).

## 0. Identité

| | |
|---|---|
| Fantasme | Beaucoup de cartes peu chères, puis un coup de grâce qui les encaisse toutes. Il ne bloque pas : il pare un coup à la fois et tue avant le suivant. |
| Ressource | Combo Points, 0 à 5, gardés d'un tour à l'autre. |
| Mécaniques propres | Parry (état empilable, une charge annule un coup jusqu'à 8 dégâts) et Stealth (première carte Attack renforcée). |
| Style de survie | Tuer vite, et Parry. Aucun soin. |
| Difficulté | Moyenne. |
| PV de départ | 65 (comme le Priest : pas de soin, mais Parry ne se perd pas d'un tour à l'autre). À régler. |
| Deck de départ | 4 Sinister Strike, 4 Feint, 1 Backstab, 1 Eviscerate. |
| Interrupt | Kick (0 mana, voie Combat, niveau 1). |
| Last Breath | Cheat Death (Power rare, voie Subtlety). |
| Bibelot de départ | Thieves' Tools : pioche 1 carte de plus au premier tour. |

Ce qu'il est seul à faire : enchaîner des cartes à 0 mana avant un Surge, et parer (Parry). Le DoT est
partagé avec le Priest Shadow et le Warlock ; chez le Rogue il **éclate** (il se déclenche tout de suite,
« ticks »), il ne monte pas avec l'Insanity et n'est jamais figé ni drainé.

## 1. Règles propres

### 1.1 Combo Points

1. Compteur du joueur `combo`, de 0 à 5, affiché dans la pastille de classe. Il vaut 0 au début de
   chaque combat (Shadowfang : 2) et disparaît à la fin du combat.
2. **Gain** : la clause `+N Combo Point(s).` se résout à sa place dans la carte, de haut en bas. Le gain
   a lieu même si la cible est morte plus tôt dans la carte (effet sur soi).
3. **Plafond** : tout point au-delà de 5 est perdu. Le journal note le gain plafonné (`capped`) ;
   l'interface fait clignoter la pastille pleine.
4. **Conservation** : les points restent d'un tour à l'autre, sans baisse.
5. **Dépense** : seulement par `Surge:`. La clause Surge dépense **tous** les points au moment où elle se
   résout ; le nombre dépensé fixe l'effet. Une carte Rogue qui porte une ligne `Surge:` **ne se joue pas
   à 0 point** (raison affichée : « No Combo Points. »), comme Void Eruption et Devouring Plague.
6. Deux Surge dans le même tour : possible si des points ont été regagnés entre les deux.
7. Interactions : aucune avec l'Absorb, le mana ni Stunned. Aucune carte du Rogue n'a Cast ; une carte
   neutre en Cast qui contiendrait un Surge dépenserait les points à sa résolution (début du tour
   suivant), pas au moment où elle est jouée. Contre un boss, Between the Eyes et Cheap Shot perdent leur
   Stunned (immunité) mais gardent dégâts et points.

### 1.2 Parry

1. État du joueur `parry`, compté en **charges**. Plafond : **3** (les charges au-delà sont perdues).
2. **Durée** : aucune. Les charges restent jusqu'à ce qu'un coup les consomme ; elles **ne disparaissent
   pas** au début du tour, contrairement à l'Absorb. Elles disparaissent à la fin du combat.
3. **Ce qui est un coup** : chaque répétition d'une action `attack` d'un ennemi (`times = 3` = trois
   coups), et tout dégât qui a un ennemi pour source. Ne sont **pas** des coups : le DoT, les dégâts sans
   source, les dégâts que le joueur s'inflige.
4. **Ordre de résolution d'un coup** : dégâts calculés (Strength et Demoralized de l'ennemi, Sundered et
   réduction de moitié sur le joueur) → **Parry** → Absorb → PV.
5. Si le coup vaut 1 ou plus et que Parry ≥ 1 : une charge part et le coup perd **8 dégâts** au plus.
   Un coup de 0 (après modificateurs) ne consomme rien.
6. **Au-delà de 8** : le reste passe, d'abord sur l'Absorb puis sur les PV. Fracas 18 avec Parry 1 et
   5 Absorb : 8 parés, 5 absorbés, 5 PV perdus.
7. **Attaques à plusieurs coups** : une charge par coup, dans l'ordre. Moisson 8 × 3 avec Parry 2 :
   deux coups annulés, le troisième touche. C'est voulu : Parry est fort contre un gros coup, faible
   contre plusieurs petits.
8. **Plusieurs ennemis** : les charges partent dans l'ordre où les ennemis agissent.
9. **Coup qui ignore l'Absorb** (`pierce`) : Parry s'applique quand même (Parry n'est pas de l'Absorb).
10. **Coup qui interrompt** (`interrupts`) : il ne coupe le Cast du joueur que s'il fait perdre des PV ;
    un coup entièrement paré ne coupe donc rien (utile avec les cartes neutres en Cast).
11. **Ennemi Stunned, Cast ennemi interrompu** : pas de coup, aucune charge consommée.
12. Une charge gagnée pendant le tour ennemi (Cheat Death) protège dès le coup suivant du même tour.
13. Automatique : le joueur ne choisit pas quel coup parer.
14. Parry ne renvoie aucun dégât : les ripostes appartiennent au Warrior et au Paladin Protection.

### 1.3 Stealth

1. État binaire `stealth`, **sans nombre**. Le Rogue le reçoit au début de chaque combat, avant son premier
   tour (le jeton est visible dès la première main).
2. Sources en combat : Vanish, Shadowstep, Smoke Bomb, Shadow Dance, Cheat Death.
3. **Ne s'empile pas** : gagner Stealth en étant caché ne fait rien (et ne déclenche pas Flash Powder).
4. **Consommation** : la première carte **Attack** jouée le consomme, quelle qu'elle soit (même sans ligne
   `Stealth:`, même à 0 mana : Pistol Shot, Eviscerate, Envenom comprises). L'état est retiré au moment où
   la carte est jouée ; toute la carte se résout « cachée », sa ligne `Stealth:` s'applique. Une carte
   neutre en Cast le consomme quand elle est jouée et garde le bonus pour sa résolution.
5. **Skills et Powers** : leur ligne `Stealth:` lit l'état **sans le consommer** (Cheap Shot,
   Premeditation). On peut donc enchaîner Premeditation, Cheap Shot puis Ambush sous un seul Stealth.
6. Stealth ne disparaît ni en fin de tour, ni sous les coups, ni par Parry ; seulement en jouant une
   Attack, ou à la fin du combat. Une potion n'est pas une carte : elle ne le consomme pas.
7. Stealth n'a aucun effet sur les ennemis : ils attaquent normalement. C'est une promesse d'ouverture,
   pas une défense.

### 1.4 Effets propres au Rogue

- **`DoT:` (condition)** : la cible a au moins 1 de DoT au moment où la ligne se résout.
- **`Its DoT ticks now.`** : le DoT de la cible se déclenche tout de suite, exactement comme au début de
  son tour (dégâts égaux au DoT, ignore l'Absorb, puis le DoT baisse de 1). Sans DoT : rien. Un
  déclenchement n'est pas un coup d'Attack (ni Strength, ni Deadly Poison, ni Sundered).
- **`Surge: its DoT ticks once per Combo Point.`** (Exsanguinate) : autant de déclenchements que de points
  dépensés, l'un après l'autre ; s'arrête si la cible meurt ou si son DoT tombe à 0 (les points restent
  dépensés).
- **`Each Attack hit: apply DoT 1.`** (Deadly Poison) : après chaque coup d'un effet `damage` d'une carte
  Attack sur un ennemi vivant, même entièrement absorbé par son Absorb. Fan of Knives sur 3 ennemis = 3
  applications ; Killing Spree = 6.
- **`Each Attack: deal 2 to all.`** (Blade Flurry) : après la résolution de chaque carte Attack, 2 dégâts
  à chaque ennemi vivant. Dégâts du joueur sans carte : Strength et Sundered s'appliquent ; ce n'est pas
  un coup d'Attack (pas de Deadly Poison) et cela ne se redéclenche pas.
- **`First Attack each turn costs 0.`** (Slice and Dice) : tant qu'aucune Attack n'a été jouée ce tour-ci,
  les cartes Attack coûtent 0. Jouer n'importe quelle Attack (même une à 0) met fin à la remise. Deux
  Slice and Dice ne donnent pas deux Attack gratuites.
- **`Deal 5 to a random enemy six times.`** (Killing Spree) : chaque coup tire sa cible parmi les ennemis
  vivants (flux de hasard nommé, voir § 6) ; si tous meurent, les coups restants sont perdus.
- **`Stealth: hits twice.`** (Secret Technique) : les dégâts du Surge sont infligés deux fois à chaque
  ennemi (deux coups distincts).
- **`Turn start: …`** : au début du tour du joueur, au moment du crochet `onTurnStart` (après ses propres
  DoT et Regen, la pioche et le mana).
  Venomous Wounds compte les ennemis vivants qui portent du DoT à ce moment.
- **Last Breath** (règle commune) : Cheat Death se déclenche une fois par combat, en tombant à 0 PV ; le
  joueur reste à 1 PV, gagne Parry 3 (plafond) et Stealth. Pendant le tour ennemi, les coups suivants
  sont donc parés.

### 1.5 Mots-clés propres et infobulles

Deux mots-clés propres ; la ressource a sa ligne comme l'Insanity.

| Mot-clé | Infobulle (≤ 60 caractères) |
|---|---|
| Parry | `Each charge stops one hit, up to 8 damage. Max 3.` |
| Stealth | `Your next Attack consumes it for its Stealth: bonus.` |
| *(ressource)* Combo Points | `0 to 5, kept between turns. Surge spends them all.` |

Conditions utilisées, toutes déjà définies : `Stealth:` (état sur soi), `DoT:` (état sur la cible),
`Surge:`, `Last Breath:`. Mots de plaque : Cooldown N, Exhaust, Power.

## 2. Les 34 cartes

Colonnes : **Niv.** = niveau de classe qui débloque la carte (§ 5). **Plaque** = mots de la plaque du bas
(dans `text`, ils restent en fin de texte, « Power. » en tête, comme au Priest). Dans les textes, « / »
sépare les clauses (`\n`). « (coût 0) » = l'amélioration ne change que le coût. Les icônes sont les noms
de fichiers exacts de `~/Téléchargements/ICONS/<nom>.tga` (tous vérifiés).

### Départ (4)

| id | Nom | Rareté | Niv. | Coût | Type | Plaque | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|---|---|
| `sinister_strike` | Sinister Strike | basic | — | 1 | Attack | | Deal 6. / +1 Combo Point. | Deal 9. / +1 Combo Point. | Spell_Shadow_RitualOfSacrifice |
| `feint` | Feint | basic | — | 1 | Skill | | Gain Parry 1 | Draw 1. / Gain Parry 1 | Ability_Rogue_Feint |
| `backstab` | Backstab | basic | — | 0 | Attack | | Deal 4. / +1 Combo Point. / Stealth: deal 8 more. | Deal 6. / +1 Combo Point. / Stealth: deal 10 more. | Ability_BackStab |
| `eviscerate` | Eviscerate | basic | — | 1 | Attack | | Surge: deal 5 + 5 per Combo Point. | Surge: deal 8 + 6 per Combo Point. | Ability_Rogue_Eviscerate |

### Assassination (10 : 5 communes, 3 inhabituelles, 2 rares)

| id | Nom | Rareté | Niv. | Coût | Type | Plaque | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|---|---|
| `mutilate` | Mutilate | common | 1 | 1 | Attack | | Deal 3 twice. / +1 Combo Point. / DoT: +1 Combo Point. | Deal 5 twice. / +1 Combo Point. / DoT: +1 Combo Point. | Ability_Rogue_ShadowStrikes |
| `garrote` | Garrote | common | 1 | 1 | Attack | | Deal 3. / +1 Combo Point. / Apply DoT 4 | Deal 4. / +1 Combo Point. / Apply DoT 6 | Ability_Rogue_Garrote |
| `rupture` | Rupture | common | 1 | 1 | Skill | | Surge: apply DoT 3 per Combo Point. | Surge: apply DoT 4 per Combo Point. | Ability_Rogue_Rupture |
| `fan_of_knives` | Fan of Knives | common | 1 | 1 | Attack | | Deal 3 to all. / +1 Combo Point. / Apply DoT 2 to all | Deal 4 to all. / +1 Combo Point. / Apply DoT 3 to all | Ability_Rogue_FanofKnives |
| `envenom` | Envenom | uncommon | 1 | 1 | Attack | | Surge: apply DoT 2 per Combo Point. / Its DoT ticks now. | Surge: apply DoT 3 per Combo Point. / Its DoT ticks now. | Ability_Rogue_Disembowel |
| `cloak_of_shadows` | Cloak of Shadows | uncommon | 1 | 1 | Skill | Cooldown 2 | Remove your debuffs. / Gain Parry 1 | Remove your debuffs. / Gain Parry 2 | Spell_Shadow_NetherCloak |
| `crippling_poison` | Crippling Poison | common | 2 | 1 | Skill | | Apply DoT 3 / Apply Demoralized 2 ⌛ | Apply DoT 5 / Apply Demoralized 2 ⌛ | ABILITY_POISONSTING |
| `exsanguinate` | Exsanguinate | rare | 4 | 1 | Skill | | Surge: its DoT ticks once per Combo Point. | (coût 0) | ability_deathwing_bloodcorruption_death |
| `deadly_poison` | Deadly Poison | uncommon | 6 | 1 | Power | Power | Each Attack hit: apply DoT 1. | (coût 0) | Ability_Rogue_DualWeild |
| `venomous_wounds` | Venomous Wounds | rare | 7 | 1 | Power | Power | Turn start: +1 Combo Point per enemy with DoT. | (coût 0) | ability_rogue_venomouswounds |

### Combat (10 : 4 communes, 4 inhabituelles, 2 rares)

| id | Nom | Rareté | Niv. | Coût | Type | Plaque | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|---|---|
| `kick` | Kick | common | 1 | 0 | Skill | Cooldown 2 | Interrupt the target's cast. / +1 Combo Point. | Cooldown 1 | Ability_Kick |
| `pistol_shot` | Pistol Shot | common | 1 | 0 | Attack | | Deal 3. / Draw 1. | Deal 5. / Draw 1. | Ability_Rogue_PistolShot |
| `sprint` | Sprint | common | 1 | 0 | Skill | Cooldown 3 | Draw 2. | Cooldown 2 | Ability_Rogue_Sprint |
| `riposte` | Riposte | common | 1 | 1 | Attack | | Deal 4. / Gain Parry 1 | Deal 7. / Gain Parry 1 | Ability_Warrior_Challange |
| `evasion` | Evasion | uncommon | 1 | 1 | Skill | Cooldown 3 | Gain Parry 2 | Cooldown 2 | Spell_Shadow_ShadowWard |
| `blade_flurry` | Blade Flurry | uncommon | 1 | 1 | Power | Power | Each Attack: deal 2 to all. | Each Attack: deal 3 to all. | Ability_Warrior_PunishingBlow |
| `slice_and_dice` | Slice and Dice | uncommon | 2 | 1 | Power | Power | First Attack each turn costs 0. | (coût 0) | Ability_Rogue_SliceDice |
| `killing_spree` | Killing Spree | rare | 4 | 2 | Attack | | Deal 5 to a random enemy six times. | Deal 7 to a random enemy six times. | Ability_Rogue_MurderSpree |
| `between_the_eyes` | Between the Eyes | uncommon | 6 | 1 | Attack | Cooldown 2 | Surge: deal 4 per Combo Point. / Apply Stunned 1 ⌛ | Surge: deal 6 per Combo Point. / Apply Stunned 1 ⌛ | INV_Weapon_Rifle_01 |
| `adrenaline_rush` | Adrenaline Rush | rare | 7 | 1 | Skill | Exhaust | +3 mana. / Draw 2. | (coût 0) | Spell_Shadow_ShadowWordDominate |

### Subtlety (10 : 4 communes, 4 inhabituelles, 2 rares)

| id | Nom | Rareté | Niv. | Coût | Type | Plaque | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|---|---|
| `ambush` | Ambush | common | 1 | 2 | Attack | | Deal 9. / +2 Combo Points. / Stealth: deal 12 more. | Deal 12. / +2 Combo Points. / Stealth: deal 16 more. | Ability_Rogue_Ambush |
| `hemorrhage` | Hemorrhage | common | 1 | 1 | Attack | | Deal 5. / +1 Combo Point. / Apply Sundered 1 ⌛ | Deal 7. / +1 Combo Point. / Apply Sundered 2 ⌛ | Spell_Shadow_LifeDrain |
| `vanish` | Vanish | common | 1 | 1 | Skill | Exhaust | Draw 1. / Gain Stealth | (coût 0) | Ability_Vanish |
| `shadowstep` | Shadowstep | common | 1 | 1 | Skill | Cooldown 3 | Gain Parry 1 / Gain Stealth | Cooldown 2 | Ability_Rogue_Shadowstep |
| `cheap_shot` | Cheap Shot | uncommon | 1 | 1 | Skill | Cooldown 2 | +2 Combo Points. / Stealth: apply Stunned 1 ⌛. | (coût 0) | Ability_CheapShot |
| `secret_technique` | Secret Technique | uncommon | 1 | 1 | Attack | | Surge: deal 3 per Combo Point to all. / Stealth: hits twice. | Surge: deal 4 per Combo Point to all. / Stealth: hits twice. | Ability_Rogue_SinisterCalling |
| `premeditation` | Premeditation | uncommon | 2 | 0 | Skill | | Draw 1. / Stealth: +2 Combo Points. | Draw 2. / Stealth: +2 Combo Points. | Spell_Shadow_Possession |
| `cheat_death` | Cheat Death | rare | 4 | 1 | Power | Power | Last Breath: stay at 1 HP, gain Parry 3 and Stealth. | (coût 0) | Ability_Rogue_CheatDeath |
| `smoke_bomb` | Smoke Bomb | uncommon | 6 | 1 | Skill | Cooldown 3 | Apply Demoralized 2 ⌛ to all / Gain Stealth | Cooldown 2 | ability_rogue_smoke |
| `shadow_dance` | Shadow Dance | rare | 7 | 2 | Power | Power | Turn start: gain Stealth. | (coût 1) | Ability_Rogue_ShadowDance |

Comptes : 4 de départ, 13 communes (5 + 4 + 4), 11 inhabituelles (3 + 4 + 4), 6 rares (2 + 2 + 2) = 34.

Notes d'écriture :

- Longueur vérifiée par un retour glouton à 22 caractères : aucune carte ne dépasse 3 lignes (les plus
  pleines : Envenom, Venomous Wounds, Cheat Death, Secret Technique, au niveau de Spirit of Redemption et
  Penance).
- `Gain Stealth` est une ligne d'état sans nombre (nouveau cas d'affichage, § 6). L'état Stunned posé sous
  `Stealth:` reste dans sa clause (règle des états conditionnels).
- Icônes partagées avec l'existant : `Ability_Kick` sert aussi au jeton « interrompu » (cohérent).
  Icônes de substitution (le sort réel a une autre icône, absente du dossier ou incertaine) : Secret
  Technique (`Ability_Rogue_SinisterCalling`) ; Between the Eyes prend l'icône classique du fusil.

## 3. Les trois voies

### Assassination — la durée

Moteur : poser du DoT tôt (Garrote, Fan of Knives, Crippling Poison) en montant les Combo Points, puis le
faire éclater par un Surge (Envenom, Exsanguinate) ou le prolonger (Rupture). Mutilate rapporte un point
de plus sur une cible empoisonnée : la voie récompense le fait de garder une cible sous DoT.

Cartes : Mutilate, Garrote, Rupture, Fan of Knives, Envenom, Cloak of Shadows, Crippling Poison,
Exsanguinate, Deadly Poison, Venomous Wounds.

- Avec **Combat** : Deadly Poison transforme chaque petite attaque à 0 mana en poison ; Fan of Knives et
  Blade Flurry couvrent les groupes ; Killing Spree répartit six applications.
- Avec **Subtlety** : les points gratuits sous Stealth (Premeditation, Cheap Shot) nourrissent Envenom et
  Rupture ; Smoke Bomb et Cheap Shot achètent les tours que le DoT met à tuer.

Tour type (3 mana, 2 points, cible à DoT 4) : Backstab (0) → 4 dégâts, 3 points ; Mutilate (1) → 3 + 3,
cible sous DoT : 5 points ; Envenom (1) → DoT 4 + 10 = 14, éclate : 14 dégâts, DoT 13 ; Feint (1) →
Parry 1.

### Combat — jouer huit cartes

Moteur : des cartes à 0 mana (Kick, Pistol Shot, Sprint, Backstab) et de la pioche remplissent les
Combo Points en un tour ; Slice and Dice rend la première Attack gratuite, Blade Flurry transforme chaque
Attack en dégâts de zone. Riposte et Evasion donnent Parry sans casser le rythme.

Cartes : Kick, Pistol Shot, Sprint, Riposte, Evasion, Blade Flurry, Slice and Dice, Killing Spree,
Between the Eyes, Adrenaline Rush.

- Avec **Assassination** : chaque coup empoisonne (Deadly Poison), Envenom éclate ce que la rafale a
  posé.
- Avec **Subtlety** : Slice and Dice rend Ambush gratuite ; Sprint et Pistol Shot vont chercher Vanish ;
  Blade Flurry double la zone de Secret Technique.

Tour type (Slice and Dice et Blade Flurry posés, 1 point, 3 mana ; main : Sinister Strike, Pistol Shot,
Kick, Sprint, Eviscerate ; un lanceur en face) : Sinister Strike (gratuite) → 6, +2
à tous, 2 points ; Sprint (0) → pioche Backstab et Riposte ; Pistol Shot (0) → 3, pioche Feint, +2 à
tous ; Backstab (0) → 4, 3 points, +2 à tous ; Kick (0) sur le lanceur → interrompu, 4 points ; Riposte
(1) → 4, Parry 1, +2 à tous ; Eviscerate (1) → 25, +2 à tous ; Feint (1) → Parry 2. Huit cartes pour
3 mana.

### Subtlety — le premier coup

Moteur : ouvrir sous Stealth avec un gros coup (Ambush, Secret Technique), retrouver Stealth (Vanish,
Shadowstep, Smoke Bomb, Shadow Dance) et préparer l'ouverture avec des Skills qui lisent Stealth sans le
consommer (Premeditation, Cheap Shot). Hemorrhage pose Sundered juste avant le coup qui compte.

Cartes : Ambush, Hemorrhage, Vanish, Shadowstep, Cheap Shot, Secret Technique, Premeditation, Cheat
Death, Smoke Bomb, Shadow Dance.

- Avec **Assassination** : les points des ouvertures alimentent Envenom ; Smoke Bomb protège pendant que
  le DoT travaille.
- Avec **Combat** : la pioche trouve Vanish et Ambush ; Blade Flurry et Secret Technique nettoient les
  groupes.

Tour type (début de combat, Stealth, 3 mana) : Premeditation (0) → pioche 1, 2 points ; Cheap Shot (1) →
4 points, Stunned 1 ; Ambush (2) → 9 + 12 = 21, 5 points (1 perdu), Stealth consommé. Au tour suivant :
Shadowstep (1) → Parry 1 et Stealth, Secret Technique (1) → 15 à tous, deux fois.

## 4. Bibelots de classe

| id | Nom | Rareté | Niv. | Effet | Icône |
|---|---|---|---|---|---|
| `thieves_tools` | Thieves' Tools | départ | 1 | On the first turn of each combat, draw 1 more card. | INV_Misc_Gear_03 |
| `blinding_powder` | Blinding Powder | common | 1 | At the start of each combat, gain Parry 1. | INV_Misc_Powder_Purple |
| `flash_powder` | Flash Powder | uncommon | 3 | Each time a card gives you Stealth, draw 1 card. | INV_Misc_Powder_Black |
| `crystal_vial` | Crystal Vial | uncommon | 5 | Each time you apply DoT, apply 1 more. | INV_Alchemy_CrystalVial |
| `ravenholdt_signet` | Ravenholdt Signet | rare | 7 | After each Surge, gain Parry 1. | INV_Jewelry_Ring_03 |
| `shadowfang` | Shadowfang | rare | 7 | At the start of each combat, gain 2 Combo Points. | INV_Sword_07 |

Thieves' Tools est celui du GDD. Flash Powder ne compte que le Stealth donné par une carte (pas celui du
début de combat). Crystal Vial vaut aussi pour Deadly Poison (DoT 2 par coup).

## 5. Progression

| Niveau | Assassination | Combat | Subtlety | Bibelots |
|---|---|---|---|---|
| 1 | Mutilate, Garrote, Rupture, Fan of Knives, Envenom, Cloak of Shadows | Kick, Pistol Shot, Sprint, Riposte, Evasion, Blade Flurry | Ambush, Hemorrhage, Vanish, Shadowstep, Cheap Shot, Secret Technique | Thieves' Tools, Blinding Powder |
| 2 | Crippling Poison | Slice and Dice | Premeditation | |
| 3 | | | | Flash Powder |
| 4 | Exsanguinate (rare) | Killing Spree (rare) | Cheat Death (rare) | |
| 5 | | | | Crystal Vial |
| 6 | Deadly Poison | Between the Eyes | Smoke Bomb | |
| 7 | Venomous Wounds (rare) | Adrenaline Rush (rare) | Shadow Dance (rare) | Ravenholdt Signet, Shadowfang |

Plus les 4 cartes de départ au niveau 1 (22 cartes). Le niveau 1 suffit pour gagner : chaque voie y a un
Surge (Rupture ou Envenom, Secret Technique, plus Eviscerate), de la défense (Cloak of Shadows, Evasion,
Riposte, Shadowstep, Feint), des dégâts de zone (Fan of Knives, Blade Flurry, Secret Technique) et
l'Interrupt (Kick). Les déblocages ouvrent des façons de jouer :

- niveau 2 : contrôle par Demoralized (Crippling Poison), Attack gratuites (Slice and Dice), points sans
  attaquer (Premeditation) ;
- niveau 4 : faire éclater un gros DoT (Exsanguinate), frapper en rafale aléatoire (Killing Spree), jouer
  au bord de la mort (Cheat Death) ;
- niveau 6 : le poison sur toutes les attaques (Deadly Poison, pont vers Combat), le Surge de contrôle
  (Between the Eyes), le Stealth de groupe (Smoke Bomb) ;
- niveau 7 : les moteurs (Venomous Wounds, Adrenaline Rush, Shadow Dance) et deux bibelots qui lient
  ressource et défense.

## 6. Besoins moteur et interface

Au-delà des règles communes (Surge, Interrupt, Cooldown, Last Breath, DoT renommé) :

**Données de classe**
- `ns.Classes.rogue = { name, hp = 65, deck, resource = { id = "combo", name = "Combo Points", max = 5 },
  startStatuses = { stealth = 1 }, starterRelic = "thieves_tools" }`.
- Champ `level` (1 à 7) sur les cartes et les bibelots de classe, à la place de `rep` ; champ `class` sur
  les bibelots ; rareté de bibelot `starter`.

**Ressource**
- `c.player.combo` (cloné, sauvegardé) ; effet `{ "combo", n }` avec plafond et événement
  `{ t = "combo", n, total, capped }` ; aide commune « dépenser tout » (`ctx.spent`) pour les Surge ;
  `canPlay` qui refuse un Surge à 0 avec la raison « No Combo Points. ».

**États**
- `parry` : `{ name = "Parry", max = 3 }`, ni `duration` ni `debuff` ; plafond appliqué par
  `applyStatus` (nouveau champ `max`).
- `stealth` : `{ name = "Stealth", flag = true }` : valeur 0/1, aucun nombre affiché, ne s'empile pas.
- Textes courts (`Art.statusShort`) : ceux du § 1.5.

**Combat**
- Parry dans la résolution des coups ennemis : dans `executeMove` (et pour tout `dealDamage` dont la source
  est un ennemi), entre `calcDamage` et l'Absorb ; décrément, réduction de 8, événement
  `{ t = "parry", src, prevented }`, statistiques `parried` et `parryPrevented`. Le test d'interruption
  (`loss > 0`) reste après.
- Stealth dans `Combat.play` : si la carte est une Attack et que `stealth` est posé, `ctx.stealth = true`,
  état retiré, événement `{ t = "stealth_used" }` ; pour une Attack en Cast, le drapeau va dans
  `c.player.cast`. Les lignes `Stealth:` des Skills lisent `c.player.st.stealth`.
- `Combat.tickDot(c, unit)` exporté (même code que le déclenchement de début de tour), pour Envenom et
  Exsanguinate.
- Crochets : `onAttackHit(c, src, target, ctx)` dans `Effects.damage` pour les cartes Attack (Deadly
  Poison) ; `onSurge(c, src, spent)` (Ravenholdt Signet) ; `onStatusGained(c, src, unit, id)` ou équivalent
  pour Flash Powder ; Blade Flurry passe par `onCardPlayed` existant (type Attack).
- Slice and Dice : drapeau de tour `c.player.flags.attackPlayed`, remis à zéro au début du tour, lu par le
  crochet `cost`.
- Hasard des cartes : flux nommé `c.rng.cards` (Killing Spree) ; jamais `c.rng.ai`.
- `applyStatus` de Stealth et Parry pendant le tour ennemi (Cheat Death) doit marcher.

**Interface**
- Pastille de classe : cinq crans de Combo Points (plutôt qu'un nombre), clignotement quand un gain est
  perdu.
- Jetons sous le héros : Parry avec son nombre (pas de sablier), Stealth sans nombre ; le modèle du héros
  en semi-transparence tant que Stealth est posé (indice visuel immédiat).
- Carte : ligne `Stealth:` en surbrillance quand elle s'appliquerait (Attack quand Stealth est posé,
  Skill idem) ; ligne `DoT:` en surbrillance selon la cible survolée ; carte Surge grisée à 0 point.
- Chiffre flottant « Parry » (−8) sur le héros, distinct de l'Absorb bleu.
- Infobulles des intentions : inchangées (le joueur lit ses charges sur le jeton).

**Bots de simulation**
- Jouer l'Attack qui a une ligne `Stealth:` en premier ; garder les Surge pour 4–5 points ; préférer Feint
  quand l'intention est une grosse frappe unique ; ne pas gaspiller de point au-delà de 5.

## 7. Risques d'équilibrage et mesures

Cibles de survie (style « tuer vite + Parry », référence Priest : normal 15,4 PV et 4,5 tours, élite 20,
boss 51,6 PV et 6,9 tours) :

| Mesure | Cible Rogue |
|---|---|
| Combat normal : tours / PV perdus | ≤ 4 tours / 12–16 PV |
| Élite : tours / PV perdus | ≤ 5 tours / 18–22 PV |
| Boss : victoires / tours / PV perdus | 70–80 % / ≤ 6 tours / ≤ 50 PV |
| Part des dégâts entrants évités par Parry | 25–40 % |
| Cartes jouées par tour (moyenne / p95) | ≤ 6 / ≤ 9 |
| Points perdus au plafond par combat | < 1 |

Risques :

1. **Parry qui ne se perd pas** : il peut s'accumuler contre des ennemis qui se protègent ou se
   renforcent. Le plafond de 3 le borne ; mesurer la valeur moyenne d'une charge (dégâts évités) et la
   comparer à 5 Absorb. Si Parry domine, passer le plafond à 2 ou le faire tomber au début du tour.
2. **Verrou de contrôle sur les élites** : Golem et Rhahk'Zor ne sont pas des boss. Shadow Dance + Cheap
   Shot (Cooldown 2) + Between the Eyes (Cooldown 2) peuvent les étourdir souvent. Mesurer les tours
   d'élite perdus ; parade possible : immunité d'un tour après un Stunned (règle commune).
3. **Longueur des tours en vol** (risque du GDD) : mesurer les cartes par tour et le temps de jeu estimé ;
   la main de 10 plafonne la pioche, Sprint a Cooldown 3.
4. **Pas de soin** : l'usure sur une expédition longue. Comparer les PV à l'arrivée au boss avec le
   Priest ; si l'écart dépasse 10 PV, monter les PV de départ avant de toucher aux cartes.
5. **Explosion du DoT contre le boss** : Rupture puis Exsanguinate, ou Venomous Wounds avec Envenom,
   peuvent écraser VanCleef. Mesurer tours de boss et part des dégâts venant du DoT.
6. **Ouverture du premier tour** : tout le monde commence sous Stealth ; Premeditation + Cheap Shot +
   Ambush peut finir les combats faciles au tour 1. Mesurer les dégâts du premier tour.
7. **Eviscerate au départ** : 30 dégâts pour 1 mana à 5 points ; le deck de départ (4 + 1 générateurs pour
   1 finisseur sur 10 cartes) tombe juste sur le rythme d'un Surge par cycle. Essayer 2 Eviscerate et
   3 Sinister Strike si les Surge manquent, 4 + 5 par point si les combats faciles sont trop courts.

Commandes : `force=` sur chaque carte et `pick=random` (écart de victoires), `sweep=relics loot=0` pour
les bibelots, série de référence `bot=heuristic` une fois les bots adaptés (§ 6).

## 8. Choix faits là où le GDD laissait un doute

- Parry : plafond 3 et charges conservées d'un tour à l'autre ; ordre Parry puis Absorb ; un coup
  entièrement paré ne coupe pas un Cast.
- Stealth : binaire, consommé par toute Attack jouée, lu sans être consommé par les Skills, jamais perdu
  sous les coups.
- Toute carte avec `Surge:` est injouable à 0 point (comme au Priest).
- Envenom reste une Attack (GDD) bien qu'elle n'inflige ses dégâts que par le DoT ; Rupture et
  Exsanguinate sont des Skills.
- Pas de soin dans la classe, pas de Cast, un seul Interrupt (Kick).
- PV de départ 65.

## 9. Points à trancher

1. **Durée de Parry** : charges gardées d'un tour à l'autre avec plafond 3 (proposé), ou remises à 0 au
   début du tour comme l'Absorb (plus simple à équilibrer, moins distinct).
2. **Surge à 0 point** : ici, toute carte avec une ligne `Surge:` est injouable à 0 (comme au Priest).
   L'Execute du Warrior (GDD : `Deal 5. / Execute: Surge: …`) suppose l'inverse : règle commune à fixer
   (proposition : injouable seulement si la carte n'a rien d'autre qu'un Surge).
3. **Immunité aux Stunned répétés** pour les élites (risque 2), règle commune possible.
4. **Envenom en Attack** (GDD) : elle consomme Stealth et déclenche Blade Flurry sans infliger de coup ;
   la passer en Skill la rendrait plus lisible.
5. **Deck de départ** : 4 / 4 / 1 / 1 comme le Priest, ou 3 Sinister Strike et 2 Eviscerate.
6. **PV de départ** : 65 proposé.
