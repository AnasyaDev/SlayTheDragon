# Paladin — fiche de conception

Fiche prête à implémenter. Elle développe la section « Paladin » du GDD des classes (Claude Docs) sans la
contredire ; les chiffres sont des points de départ calés sur le Priest (`Data/Priest.lua`) et seront
réglés par simulation. Textes de jeu en anglais, tels qu'affichés. « DoT » est l'état de dégâts sur la
durée (`pain` dans le code actuel) ; le Paladin n'en pose pas.

## 0. Identité

| | |
|---|---|
| Fantasme | Il porte un Seal qui change ce que fait son Judgement, et lance un gros effet tous les trois points de Holy Power. Classe régulière et robuste. |
| Ressource | Holy Power, 0 à 3, gardée d'un tour à l'autre. Les cartes de base en donnent 1, les cartes fortes demandent `Spend 3`. |
| Mécanique propre | Les Seals (un seul actif) et leur ligne `Judgement:`, déclenchée par les cartes qui jugent. |
| Style de survie | Encaisser (Absorb) et se soigner. |
| Difficulté | Facile. |
| PV de départ | 75 (classe robuste ; le Priest en a 65). À régler. |
| Deck de départ | 4 Crusader Strike, 4 Holy Shield, 1 Judgement, 1 Seal of Righteousness. |
| Interrupt | Rebuke (0 mana, voie Protection, niveau 1) ; Avenger's Shield (rare) interrompt tous les ennemis. |
| Last Breath | Lay on Hands (Power rare, voie Holy). |
| Bibelot de départ | Libram : +1 Holy Power au début de chaque combat. |

Ce qu'il est seul à faire : porter un Seal et le juger. Ce qui le sépare des voisins nommés par le GDD :

- du **Priest Holy** : aucune carte en Cast, aucun Regen ; ses soins passent par le Seal, le Judgement et
  `Spend 3`, et ses cartes « Deal X or heal X » font choisir à chaque fois ;
- du **Warrior Protection** : il ne transforme jamais l'Absorb en dégâts et ne gagne rien à être touché ;
  sa zone vient de Consecration et des Judgements, sa riposte (Retribution Aura) frappe même un coup
  absorbé.

## 1. Règles propres

### 1.1 Holy Power

1. Compteur du joueur `holy`, de 0 à 3, affiché dans la pastille de classe (trois crans). Il vaut 0 au
   début du combat (Libram : 1) et disparaît à la fin du combat.
2. **Gain** : la clause `+N Holy Power.` se résout à sa place dans la carte, même si la cible est morte
   plus tôt dans la carte.
3. **Plafond** : un point gagné au-delà de 3 est perdu (événement `capped` ; Medallion of Faith le change
   en 3 Absorb).
4. **Conservation** : la Holy Power reste d'un tour à l'autre, sans baisse.
5. **Dépense** : seulement par `Spend 3:` (règle commune `Spend N`). Le Paladin n'a que des `Spend 3` : le
   rythme est fixe, trois cartes puis une récompense.
   - La ligne se lit **à sa résolution**. À 3 points : les trois sont dépensés et l'effet s'ajoute. À
     moins de 3 : rien n'est dépensé, la ligne est sautée, le reste de la carte s'applique.
   - Dépense **automatique** : une carte `Spend 3` jouée à 3 points dépense toujours. Choisir quelle carte
     jouer à 3 points est la décision (Templar's Verdict pour frapper, Shield of the Righteous pour
     tenir, Word of Glory pour se soigner).
   - Aucune carte du Paladin ne donne et ne dépense de la Holy Power à la fois.
6. Interactions : aucune avec l'Absorb (sauf Medallion of Faith), le mana ou les attaques multiples. Le
   Paladin n'a pas de Cast ; une carte neutre en Cast portant `Spend N` lirait les points à sa résolution
   (début du tour suivant). Contre un boss, Hammer of Justice perd son Stunned (immunité) mais donne
   toujours son point.

### 1.2 Seals

1. Un **Seal** est une carte Power marquée `Seal` sur la plaque (au lieu de `Power`). Elle compte comme
   un Power pour tout le reste.
2. **Un seul Seal actif.** Jouer un Seal quand un autre est actif : l'ancien quitte la rangée des Powers et
   va dans la **défausse** (on pourra le repiocher et le rejouer) ; le nouveau prend sa place. L'effet
   permanent de l'ancien cesse aussitôt.
3. Jouer un Seal identique à l'actif (deuxième exemplaire) : même règle, l'ancien exemplaire part à la
   défausse. Aucun gain.
4. **Effet à la pose** : aucun. Un Seal n'agit que par sa ligne permanente et sa ligne `Judgement:`.
   Seuls des bibelots réagissent à la pose (Symbol of Divinity, Libram of Fervor).
5. **Ligne permanente**, active tant que le Seal est posé :
   - `Attacks deal N more.` : chaque coup d'une carte Attack inflige N de plus (comme Strength, mais
     seulement pour les Attack), y compris le coup d'un Judgement venu d'une carte Attack ;
   - `Attacks give N Absorb.` et `Attacks heal N.` : une fois par carte Attack résolue, quels que soient
     ses coups.
6. Le Seal disparaît à la fin du combat, comme tout Power.

### 1.3 Judgement

1. La clause `Judge your Seal.` déclenche la ligne `Judgement:` du Seal actif, **à sa place** dans la
   carte.
2. **Cible** : celle de la carte qui juge. Si la carte n'a pas de cible (The Art of War après Word of
   Glory) ou si la cible est morte, le premier ennemi vivant (le plus à gauche), comme une incantation
   dont la cible est morte. Les effets sur soi (soin, Absorb) n'ont pas besoin de cible.
3. **Sans Seal** : la clause ne fait rien ; le reste de la carte s'applique. Un Judge sans Seal ne compte
   pas comme un Judge (Avenging Wrath, Light's Justice ne se déclenchent pas). L'interface grise la clause.
4. Les dégâts d'un Judgement sont un coup supplémentaire de la carte qui juge : Strength, Sundered et
   Demoralized s'appliquent, et `Attacks deal N more` si cette carte est une Attack. Contre plusieurs
   ennemis (`to all`), un coup par ennemi.
5. Pas de limite par tour : chaque clause `Judge` déclenche une fois (Judgement a Cooldown 1, Exorcism
   Cooldown 2).
6. Le Judgement n'a aucun lien avec la Holy Power, sauf par The Art of War et Divine Purpose.

### 1.4 Effets propres au Paladin

- **`Deal X or heal X.`** (Holy Shock, Holy Prism) : la carte se joue sur un ennemi (la partie dégâts) ou
  sur le héros (la partie soin). Avec `to all`, cliquer sur n'importe quel ennemi inflige les dégâts à
  tous. Dans les deux cas, le reste de la carte s'applique.
- **`Take no damage until next turn.`** (Divine Shield) : état `divine_shield` sur soi, retiré au début du
  tour du joueur (comme Pain Suppression). Chaque coup est ramené à 0 avant l'Absorb : rien n'est perdu,
  aucun Cast n'est coupé, Retribution Aura ne riposte pas (coup à 0). Le DoT sur soi se déclenche au
  début du tour, après le retrait : il n'est pas bloqué.
- **`Spend 3: keep your Absorb next turn.`** (Ardent Defender) : au début du prochain tour du joueur,
  l'Absorb n'est pas remis à 0 (une seule fois) ; il tient jusqu'au début du tour d'après.
- **`Each hit taken: deal 3 back.`** (Retribution Aura) : après chaque coup ennemi qui vaut 1 ou plus
  après modificateurs, **même entièrement absorbé** ; 3 dégâts à l'attaquant (dégâts du joueur sans carte :
  Strength et Sundered s'appliquent). Une attaque à 3 coups riposte 3 fois.
- **`Turn end: deal 3 to all.`** (Consecration) : à la fin du tour du joueur, avant le tour ennemi.
- **`Each heal: deal 3 to all.`** (Avenging Crusader) : après chaque soin qui rend au moins 1 PV au héros
  (Seal of Light compris ; pas à PV pleins).
- **`Each Spend 3: judge your Seal.`** (The Art of War) et **`After each Spend 3: +1 Holy Power.`** (Divine
  Purpose) : juste après une ligne `Spend 3` dont les points ont été dépensés, dans l'ordre où les Powers
  ont été posés.
- **`Interrupt all casts.`** (Avenger's Shield) : l'Interrupt commun appliqué à chaque ennemi vivant.
- **Last Breath** (règle commune) : Lay on Hands se déclenche une fois par combat ; le joueur reste à 1 PV
  puis se soigne de 20 (soin normal : Avenging Crusader réagit).

### 1.5 Mots-clés propres et infobulles

| Mot-clé | Infobulle (≤ 60 caractères) |
|---|---|
| Seal | `Power. One Seal at a time: a new one replaces it.` |
| Judgement | `Judge: trigger the Judgement: line of your Seal.` |
| *(ressource)* Holy Power | `0 to 3, kept between turns. Spend 3 uses all three.` |

Le mot-clé Judgement couvre la condition `Judgement:` des Seals et le verbe `Judge` des cartes ; les
deux s'affichent en or. Conditions communes utilisées : `Spend 3:`, `Last Breath:`. Mots de plaque :
Seal, Power, Cooldown N, Exhaust, Retain.

## 2. Les 34 cartes

Colonnes : **Niv.** = niveau de classe qui débloque la carte (§ 5). **Plaque** = mots de la plaque du bas
(dans `text`, « Power. » ou « Seal. » en tête, les autres en fin, comme au Priest). « / » sépare les
clauses (`\n`). « (coût 0) » = l'amélioration ne change que le coût. Les icônes sont les noms de fichiers
exacts de `~/Téléchargements/ICONS/<nom>.tga` (tous vérifiés).

### Départ (4)

| id | Nom | Rareté | Niv. | Coût | Type | Plaque | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|---|---|
| `crusader_strike` | Crusader Strike | basic | — | 1 | Attack | | Deal 6. / +1 Holy Power. | Deal 9. / +1 Holy Power. | Spell_Holy_CrusaderStrike |
| `holy_shield` | Holy Shield | basic | — | 1 | Skill | | Gain 5 Absorb. | Gain 8 Absorb. | Spell_Holy_BlessingOfProtection |
| `judgement` | Judgement | basic | — | 1 | Attack | Cooldown 1 | Deal 5. / Judge your Seal. | Deal 8. / Judge your Seal. | Spell_Holy_RighteousFury |
| `seal_of_righteousness` | Seal of Righteousness | basic | — | 1 | Power | Seal | Attacks deal 1 more. / Judgement: deal 6. | Attacks deal 1 more. / Judgement: deal 10. | Ability_ThunderBolt |

### Retribution (10 : 4 communes, 4 inhabituelles, 2 rares)

| id | Nom | Rareté | Niv. | Coût | Type | Plaque | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|---|---|
| `templars_verdict` | Templar's Verdict | common | 1 | 1 | Attack | | Deal 8. / Spend 3: deal 14 more. | Deal 10. / Spend 3: deal 18 more. | Spell_Paladin_templarsverdict |
| `exorcism` | Exorcism | common | 1 | 1 | Attack | Cooldown 2 | Deal 5. / Judge your Seal. | Deal 8. / Judge your Seal. | Spell_Holy_Excorcism_02 |
| `blade_of_justice` | Blade of Justice | common | 1 | 2 | Attack | | Deal 12. / +2 Holy Power. | Deal 16. / +2 Holy Power. | Ability_Paladin_BladeofJustice |
| `shield_of_vengeance` | Shield of Vengeance | common | 1 | 1 | Skill | | Gain 6 Absorb. / +1 Holy Power. | Gain 9 Absorb. / +1 Holy Power. | Ability_Paladin_ShieldofVengeance |
| `seal_of_command` | Seal of Command | uncommon | 1 | 1 | Power | Seal | Attacks deal 2 more. / Judgement: deal 8 to all. | Attacks deal 2 more. / Judgement: deal 12 to all. | Ability_Warrior_InnerRage |
| `divine_storm` | Divine Storm | uncommon | 1 | 1 | Attack | | Deal 5 to all. / Spend 3: deal 10 more to all. | Deal 7 to all. / Spend 3: deal 14 more to all. | ABILITY_PALADIN_DIVINESTORM |
| `blessing_of_might` | Blessing of Might | uncommon | 2 | 1 | Skill | Exhaust | Gain Strength 2 | Gain Strength 3 | Spell_Holy_FistOfJustice |
| `wake_of_ashes` | Wake of Ashes | rare | 4 | 1 | Attack | Cooldown 3 | Deal 8 to all. / +3 Holy Power. | Deal 12 to all. / +3 Holy Power. | INV_Sword_2H_ArtifactAshbringer_D_01 |
| `the_art_of_war` | The Art of War | uncommon | 6 | 1 | Power | Power | Each Spend 3: judge your Seal. | (coût 0) | Ability_Paladin_ArtofWar |
| `avenging_wrath` | Avenging Wrath | rare | 7 | 2 | Power | Power | Each Judge: gain Strength 1. | (coût 1) | SPELL_HOLY_AVENGINEWRATH |

### Protection (10 : 4 communes, 4 inhabituelles, 2 rares)

| id | Nom | Rareté | Niv. | Coût | Type | Plaque | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|---|---|
| `rebuke` | Rebuke | common | 1 | 0 | Skill | Cooldown 2 | Interrupt the target's cast. / +1 Holy Power. | Cooldown 1 | Spell_Holy_Rebuke |
| `shield_of_the_righteous` | Shield of the Righteous | common | 1 | 1 | Attack | | Deal 6. / Spend 3: gain 15 Absorb. | Deal 8. / Spend 3: gain 20 Absorb. | Ability_Paladin_ShieldoftheTemplar |
| `hammer_of_the_righteous` | Hammer of the Righteous | common | 1 | 1 | Attack | | Deal 4 to all. / +1 Holy Power. | Deal 6 to all. / +1 Holy Power. | Ability_Paladin_HammeroftheRighteous |
| `hammer_of_justice` | Hammer of Justice | common | 1 | 1 | Skill | Cooldown 3 | +1 Holy Power. / Apply Stunned 1 ⌛ | Cooldown 2 | Spell_Holy_SealOfMight |
| `consecration` | Consecration | uncommon | 1 | 2 | Power | Power | Turn end: deal 3 to all. | Turn end: deal 4 to all. | Spell_Holy_InnerFire |
| `seal_of_justice` | Seal of Justice | uncommon | 1 | 1 | Power | Seal | Attacks give 2 Absorb. / Judgement: apply Demoralized 2 ⌛. | Attacks give 3 Absorb. / Judgement: apply Demoralized 3 ⌛. | Spell_Holy_SealOfWrath |
| `retribution_aura` | Retribution Aura | uncommon | 2 | 1 | Power | Power | Each hit taken: deal 3 back. | Each hit taken: deal 5 back. | Spell_Holy_AuraOfLight |
| `divine_shield` | Divine Shield | rare | 4 | 2 | Skill | Retain, Exhaust | Take no damage until next turn. | (coût 1) | Spell_Holy_DivineIntervention |
| `ardent_defender` | Ardent Defender | uncommon | 6 | 1 | Skill | | Gain 6 Absorb. / Spend 3: keep your Absorb next turn. | Gain 9 Absorb. / Spend 3: keep your Absorb next turn. | Spell_Holy_ArdentDefender |
| `avengers_shield` | Avenger's Shield | rare | 7 | 2 | Attack | | Deal 8 to all. / Interrupt all casts. / +1 Holy Power. | Deal 12 to all. / Interrupt all casts. / +1 Holy Power. | Spell_Holy_AvengersShield |

### Holy (10 : 5 communes, 3 inhabituelles, 2 rares)

| id | Nom | Rareté | Niv. | Coût | Type | Plaque | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|---|---|
| `holy_shock` | Holy Shock | common | 1 | 1 | Skill | Cooldown 1 | Deal 8 or heal 8. / +1 Holy Power. | Deal 11 or heal 11. / +1 Holy Power. | Spell_Holy_SearingLight |
| `flash_of_light` | Flash of Light | common | 1 | 1 | Skill | Exhaust | Heal 8. / +1 Holy Power. | Heal 11. / +1 Holy Power. | Spell_Holy_FlashHeal |
| `word_of_glory` | Word of Glory | common | 1 | 1 | Skill | | Gain 5 Absorb. / Spend 3: heal 12. | Gain 7 Absorb. / Spend 3: heal 16. | INV_HELMET_96 |
| `seal_of_light` | Seal of Light | common | 1 | 1 | Power | Seal | Attacks heal 1. / Judgement: heal 6. | Attacks heal 1. / Judgement: heal 10. | Spell_Holy_HealingAura |
| `lights_hammer` | Light's Hammer | common | 1 | 1 | Attack | | Deal 4 to all. / Heal 3. | Deal 6 to all. / Heal 4. | spell_Paladin_LightsHammer |
| `light_of_dawn` | Light of Dawn | uncommon | 1 | 1 | Attack | | Deal 5 to all. / Spend 3: heal 10. | Deal 7 to all. / Spend 3: heal 14. | Spell_Paladin_Lightofdawn |
| `holy_prism` | Holy Prism | uncommon | 2 | 1 | Skill | Cooldown 2 | Deal 6 to all or heal 12. | Deal 8 to all or heal 16. | Spell_Paladin_HolyPrism |
| `lay_on_hands` | Lay on Hands | rare | 4 | 1 | Power | Power | Last Breath: stay at 1 HP, heal 20. | (coût 0) | Spell_Holy_LayOnHands |
| `divine_purpose` | Divine Purpose | uncommon | 6 | 1 | Power | Power | After each Spend 3: +1 Holy Power. | (coût 0) | Spell_Holy_DivinePurpose |
| `avenging_crusader` | Avenging Crusader | rare | 7 | 2 | Power | Power | Each heal: deal 3 to all. | (coût 1) | ability_Paladin_Veneration |

Comptes : 4 de départ, 13 communes (4 + 4 + 5), 11 inhabituelles (4 + 4 + 3), 6 rares (2 + 2 + 2) = 34.
Seals : quatre (Righteousness au départ, Command, Justice, Light : un par voie).

Notes d'écriture :

- Longueur vérifiée par un retour glouton à 22 caractères : aucune carte ne dépasse 3 lignes (les plus
  pleines : Seal of Justice, Divine Storm, Ardent Defender, Avenger's Shield, Shield of the Righteous).
- `Gain Strength 2` est une ligne d'état (intensité, sans sablier). Demoralized posé par un Judgement
  reste dans sa clause (état conditionnel).
- Icônes partagées avec l'existant (même sort dans WoW, autre classe) : Consecration et Inner Fire
  (`Spell_Holy_InnerFire`), Holy Shock et Holy Fire (`Spell_Holy_SearingLight`), Flash of Light et Flash
  Heal (`Spell_Holy_FlashHeal`) ; Hammer of Justice est l'icône du jeton Stunned (cohérent). Les decks ne
  se mélangent pas, mais le panneau de progression les montrera côte à côte. Icône de substitution :
  Avenging Crusader (`ability_Paladin_Veneration`).

## 3. Les trois voies

### Retribution — le Judgement à chaque tour

Moteur : Seal of Command et une carte qui juge presque à chaque tour (Judgement, Exorcism, The Art of
War) ; la Holy Power se monte vite (Blade of Justice, Wake of Ashes) et se dépense en dégâts (Templar's
Verdict, Divine Storm). Strength vient de Blessing of Might puis d'Avenging Wrath, qui grandit à chaque
Judge.

Cartes : Templar's Verdict, Exorcism, Blade of Justice, Shield of Vengeance, Seal of Command, Divine Storm,
Blessing of Might, Wake of Ashes, The Art of War, Avenging Wrath.

- Avec **Protection** : à 3 points, Templar's Verdict si l'intention est faible, Shield of the Righteous
  si elle est lourde ; Consecration et le Judgement de Command nettoient les groupes ; Strength renforce
  Retribution Aura.
- Avec **Holy** : changer de Seal selon les PV (Command pour finir, Light pour remonter) ; The Art of War
  juge Seal of Light après Word of Glory ; Divine Storm et Light of Dawn partagent leur base de zone.

Tour type (Seal of Command posé, 2 points, 3 mana ; main : Crusader Strike, Templar's Verdict,
Judgement, Holy Shield, Divine Storm) : Crusader Strike → 6 + 2, 3 points ; Templar's Verdict → 8 + 14 + 2
= 24, 0 point ; Judgement → 5 + 2, puis 8 + 2 à tous.

### Protection — l'usure

Moteur : de l'Absorb chaque tour (Holy Shield, Seal of Justice, Shield of the Righteous), des dégâts de
zone qui tournent seuls (Consecration) et une riposte à chaque coup reçu (Retribution Aura) ; la Holy
Power sert à encaisser le gros coup annoncé (Shield of the Righteous, Ardent Defender). Rebuke, Hammer of
Justice et Avenger's Shield coupent les menaces.

Cartes : Rebuke, Shield of the Righteous, Hammer of the Righteous, Hammer of Justice, Consecration, Seal
of Justice, Retribution Aura, Divine Shield, Ardent Defender, Avenger's Shield.

- Avec **Retribution** : la riposte et la zone profitent de Strength ; Seal of Command transforme chaque
  Judge en dégâts de zone pendant que Consecration use le reste.
- Avec **Holy** : Absorb et soin se relaient ; Ardent Defender garde l'Absorb pendant que Holy Shock
  soigne ; Lay on Hands rattrape l'erreur.

Tour type (Consecration et Seal of Justice posés, 3 points, intention : Fracas 19 ; main : Shield of the
Righteous, Hammer of the Righteous, Holy Shield, Rebuke, Crusader Strike) : Shield of the Righteous → 6,
15 Absorb + 2 ; Hammer of the Righteous → 4 à tous, 1 point, +2 Absorb ; Holy Shield → 24 Absorb ; fin du
tour : 3 à tous. Fracas est absorbé en entier.

### Holy — ne jamais descendre

Moteur : chaque carte frappe ou soigne au choix (Holy Shock, Holy Prism), Seal of Light soigne à chaque
Attack et à chaque Judgement, et les `Spend 3` rendent des PV (Word of Glory, Light of Dawn). Les dégâts
viennent des cartes de zone à soin (Light's Hammer, Light of Dawn), puis d'Avenging Crusader qui change
chaque soin en dégâts de zone.

Cartes : Holy Shock, Flash of Light, Word of Glory, Seal of Light, Light's Hammer, Light of Dawn, Holy
Prism, Lay on Hands, Divine Purpose, Avenging Crusader.

- Avec **Retribution** : Seal of Light quand on descend, Seal of Command pour finir ; Divine Purpose
  enchaîne Templar's Verdict et Word of Glory.
- Avec **Protection** : Seal of Justice et Holy Shield gardent les PV, Holy Shock frappe tant qu'on n'a
  pas besoin de soin.

Tour type (Seal of Light posé, 2 points, 40/75 PV ; main : Holy Shock, Light of Dawn, Judgement, Word of
Glory, Crusader Strike) : Holy Shock sur le héros → soin 8, 3 points ; Light of Dawn → 5 à tous, soin 10,
soin 1 (Attack) ; Judgement → 5, soin 6, soin 1. 26 PV rendus, 5 dégâts à tous et 5 à la cible.

## 4. Bibelots de classe

| id | Nom | Rareté | Niv. | Effet | Icône |
|---|---|---|---|---|---|
| `libram` | Libram | départ | 1 | At the start of each combat, gain 1 Holy Power. | INV_Relics_LibramofTruth |
| `symbol_of_divinity` | Symbol of Divinity | common | 1 | The first Seal you play each combat costs 0. | INV_Stone_WeightStone_05 |
| `libram_of_fervor` | Libram of Fervor | uncommon | 3 | Each time you play a Seal, draw 1 card. | INV_Relics_LibramofHope |
| `medallion_of_faith` | Medallion of Faith | uncommon | 5 | Each Holy Power gained above 3 gives 3 Absorb. | INV_Jewelry_Talisman_04 |
| `lights_justice` | Light's Justice | rare | 7 | The first Judge of each combat triggers your Seal twice. | INV_Mace_29 |
| `argent_dawn_tabard` | Tabard of the Argent Dawn | rare | 7 | After each Spend 3, heal 4 HP. | INV_Misc_TabardPVP_01 |

Libram est celui du GDD. Symbol of Divinity rend le premier tour moins lent (le Seal coûte un mana sur
trois) ; Libram of Fervor récompense le changement de Seal.

## 5. Progression

| Niveau | Retribution | Protection | Holy | Bibelots |
|---|---|---|---|---|
| 1 | Templar's Verdict, Exorcism, Blade of Justice, Shield of Vengeance, Seal of Command, Divine Storm | Rebuke, Shield of the Righteous, Hammer of the Righteous, Hammer of Justice, Consecration, Seal of Justice | Holy Shock, Flash of Light, Word of Glory, Seal of Light, Light's Hammer, Light of Dawn | Libram, Symbol of Divinity |
| 2 | Blessing of Might | Retribution Aura | Holy Prism | |
| 3 | | | | Libram of Fervor |
| 4 | Wake of Ashes (rare) | Divine Shield (rare) | Lay on Hands (rare) | |
| 5 | | | | Medallion of Faith |
| 6 | The Art of War | Ardent Defender | Divine Purpose | |
| 7 | Avenging Wrath (rare) | Avenger's Shield (rare) | Avenging Crusader (rare) | Light's Justice, Tabard of the Argent Dawn |

Plus les 4 cartes de départ au niveau 1 (22 cartes). Le niveau 1 suffit pour gagner : les trois Seals de
voie, deux `Spend 3` par voie (Templar's Verdict, Divine Storm ; Shield of the Righteous ; Word of Glory,
Light of Dawn), de la zone dans chaque voie, l'Interrupt (Rebuke) et de quoi tenir (Holy Shield, Shield of
Vengeance, Holy Shock). Les déblocages ouvrent des façons de jouer :

- niveau 2 : Strength (Blessing of Might), la riposte (Retribution Aura), le soin de zone au choix (Holy
  Prism) ;
- niveau 4 : la Holy Power d'un coup (Wake of Ashes), le tour sans dégâts (Divine Shield), le filet
  (Lay on Hands) ;
- niveau 6 : le Spend qui juge (The Art of War), l'Absorb qui reste (Ardent Defender), le Spend qui se
  recharge (Divine Purpose) ;
- niveau 7 : les moteurs (Avenging Wrath, Avenger's Shield, Avenging Crusader) et deux bibelots autour du
  Judgement et du Spend.

## 6. Besoins moteur et interface

Au-delà des règles communes (`Spend N`, Interrupt, Cooldown, Retain, Last Breath) :

**Données de classe**
- `ns.Classes.paladin = { name, hp = 75, deck, resource = { id = "holy", name = "Holy Power", max = 3 },
  starterRelic = "libram" }` ; champ `level` sur les cartes et bibelots de classe (comme au Rogue).

**Ressource**
- `c.player.holy` (cloné, sauvegardé) ; effet `{ "holy", n }` avec plafond, événement
  `{ t = "holy", n, total, capped }` et crochet `holyOverflow(c, src, lost)` (Medallion of Faith).
- `Spend N` commun : effet `{ "spend", 3, effects = { … } }` qui dépense et résout ses sous-effets si les
  points y sont, sinon rien ; crochet `onSpend(c, src, n, ctx)` après une dépense (The Art of War, Divine
  Purpose, Tabard of the Argent Dawn).

**Seal et Judgement**
- Champ de carte `seal = true` (implique `power`) et `judgement = { effets }` ; dans `afterPlay`, retrait
  du Seal actif de `c.player.powers` vers la défausse, événement `{ t = "seal", old, new }`, crochet
  `onSealPlayed` (Libram of Fervor) ; crochet `cost` pour Symbol of Divinity.
- Effet `{ "judge" }` : cherche le Seal actif, résout ses effets `judgement` avec le contexte de la carte
  (cible de repli = premier ennemi vivant), événement `{ t = "judge", seal }`, crochet `onJudge(c, src,
  seal, ctx)` (Avenging Wrath, Light's Justice).
- Lignes permanentes : `damage` (Attacks deal N more, pour `cardDef.type == "attack"`), `onCardPlayed`
  (Attacks give N Absorb, Attacks heal N).

**Cibles « or »**
- `target = "either"` : `legalPlays` propose le héros et chaque ennemi vivant ; `Combat.play(c, idx,
  "self")` résout la partie soin ; effet `{ "either", damage = { … }, heal = { … } }`.

**États et crochets**
- `divine_shield` : `{ name = "Divine Shield" }`, retiré au début du tour du joueur, dégâts ramenés à 0
  dans `calcDamage` ; texte court : `Takes no damage until your next turn.`
- Drapeau `c.player.flags.keepBlock` lu (puis effacé) au début du tour (Ardent Defender).
- Crochet `onEnemyHit(c, src, attacker, dmg)` pour chaque coup ennemi ≥ 1 **avant** l'Absorb (Retribution
  Aura) ; l'actuel `onPlayerHit` ne part qu'avec une perte de PV.
- Crochet `onPlayerHeal(c, src, amount)` dans `Combat.heal` quand le héros gagne au moins 1 PV (Avenging
  Crusader).
- `{ "interrupt", all = true }` (Avenger's Shield).

**Interface**
- Pastille de classe : trois crans de Holy Power ; un halo quand ils sont pleins (la prochaine carte
  `Spend 3` paie).
- Emplacement de Seal : le Seal actif a son propre jeton, à gauche des Powers, au liseré plus marqué ;
  infobulle = sa ligne permanente et sa ligne `Judgement:`.
- Carte : ligne `Spend 3:` en surbrillance à 3 points ; clause `Judge your Seal.` grisée sans Seal, et
  infobulle de la carte qui rappelle le Judgement du Seal actif ; Seal en main qui remplacerait l'actif :
  mention « Replaces Seal of … » dans l'infobulle.
- Cartes « or » : le héros devient une cible valide (anneau vert au survol), les ennemis en rouge ;
  aperçu du chiffre de soin ou de dégâts selon la cible survolée.
- Divine Shield : bulle dorée autour du héros, chiffres « 0 » sur les coups.

**Bots de simulation**
- Poser un Seal dès qu'il est en main s'il n'y en a pas ; changer de Seal selon les PV ; jouer une carte
  « or » en soin si les PV manquants couvrent le soin ; choisir le `Spend 3` selon l'intention (gros coup
  annoncé → Shield of the Righteous) ; ne pas jouer un générateur à 3 points s'il reste un `Spend 3` en
  main.

## 7. Risques d'équilibrage et mesures

Cibles de survie (style « encaisser + soin », 75 PV ; référence Priest : normal 15,4 PV et 4,5 tours,
élite 20, boss 51,6 PV et 6,9 tours) :

| Mesure | Cible Paladin |
|---|---|
| Combat normal : tours / PV perdus | 4–5 tours / 10–13 PV |
| Élite : tours / PV perdus | 5–6 tours / 14–18 PV |
| Boss : victoires / tours / PV perdus | 75–85 % / ≤ 8 tours / ≤ 45 PV |
| Holy Power perdue au plafond par combat | < 1,5 |
| Soins par combat, voie Holy (hors Lay on Hands) | ≤ 25 PV |
| Changements de Seal par combat (decks à deux Seals) | ≥ 0,5 |

Risques :

1. **Voisinage Priest Holy / Warrior Protection** (GDD) : l'identité tient au Seal unique et au rythme de
   trois. Vérifier dans les rapports que les victoires dépendent du Seal (écart avec et sans Seal posé)
   et des `Spend 3` (part des dégâts et soins venant des lignes `Spend`).
2. **Soin sans fin, combats qui traînent** : Holy Shock (Cooldown 1), Holy Prism, Light's Hammer et Seal of
   Light soignent à chaque cycle. Mesurer tours et soins par combat ; si les combats Holy dépassent
   6 tours en normal, passer Holy Shock en Cooldown 2 ou réduire Seal of Light.
3. **Dépense automatique** : `Spend 3` dépense même quand le joueur aurait voulu garder ses points pour une
   autre carte. Compter les `Spend 3` déclenchés puis suivis, dans le même tour, d'un autre `Spend 3` en
   main non jouable ; si c'est fréquent, envisager un choix explicite (règle commune, à voir avec le
   Warrior).
4. **Premier tour lent** : poser le Seal coûte un mana. Mesurer les PV perdus au tour 1 et la part de
   combats où le Seal n'est jamais posé ; Symbol of Divinity est la réponse prévue.
5. **Strength sans plafond** : Avenging Wrath avec Judgement, Exorcism et The Art of War peut donner +2 à
   +3 par tour sur un long combat (boss). Mesurer la Strength moyenne au tour 6 contre VanCleef.
6. **Riposte contre les attaques multiples** : Retribution Aura punit Moisson (8 × 3) et l'Enchaînement de
   VanCleef deux fois plus que les gros coups ; contre les murlocs elle rend la zone presque gratuite.
   Mesurer les dégâts de riposte par rencontre.
7. **Consecration contre les groupes** : 3 à tous chaque tour pour 2 mana efface les murlocs. Comparer
   ses dégâts à Holy Nova (Priest).
8. **Deck de départ sans `Spend 3`** : comme l'Insanity du Priest au départ, la Holy Power s'accumule sans
   servir jusqu'à la première récompense. Si les premiers combats en souffrent, voir le point 1 du
   § 9.

Commandes : `force=` sur chaque carte et `pick=random`, `sweep=relics loot=0`, série de référence
`bot=heuristic` une fois les bots adaptés (§ 6).

## 8. Choix faits là où le GDD laissait un doute

- Seal remplacé : il va à la défausse (pas épuisé), pour qu'on puisse y revenir.
- Seal : aucun effet à la pose ; ligne de dégâts par coup, lignes d'Absorb et de soin par carte Attack.
- Judgement sans Seal : sans effet, le reste de la carte joue ; cible de repli = premier ennemi vivant.
- Toutes les dépenses sont des `Spend 3` automatiques ; jamais de gain et de dépense sur la même carte.
- Pas de Cast ni de Regen (laissés au Priest), pas de conversion Absorb → dégâts (laissée au Warrior).
- Divine Shield et Avenger's Shield en rares de Protection ; Lay on Hands en rare de Holy.
- PV de départ 75.

## 9. Points à trancher

1. **Deck de départ sans `Spend 3`.** Le GDD fixe les quatre cartes ; aucune ne dépense. Option : Judgement
   amélioré en `Deal 8. / Judge your Seal. / Spend 3: judge again.`, ou un deuxième texte pour Holy Shield
   (`Gain 5 Absorb. / Spend 3: gain 8 more.`). À décider après une première simulation.
2. **`Spend 3` automatique ou au choix** : règle commune à fixer avec le Warrior (`Spend 2` de Heroic
   Strike). Le choix explicite ajoute un clic et une décision à chaque carte.
3. **Seal remplacé : défausse ou Exhaust.** La défausse rend le va-et-vient possible ; l'Exhaust ferait de
   chaque changement un engagement.
4. **PV de départ** : 75 proposé (Priest 65, Warrior probablement plus).
5. **Nom du bibelot de départ** : « Libram » tel quel (GDD) ou un vrai nom d'objet (« Libram of Truth »,
   dont il reprend l'icône).
