# Mage — fiche de conception

Développe la section « Mage » du GDD des classes (Claude Docs) sans la contredire. Les règles communes
(tour, Cast, Interrupt, Cooldown, Exhaust, Retain, Execute, Surge, Last Breath, états communs) et le
langage des cartes (`docs/interface.md`, « Langage des cartes ») s'appliquent tels quels ; cette fiche
n'écrit que ce que le Mage ajoute. Tous les chiffres sont des points de départ, à régler par simulation
comme pour le Priest. L'état de dégâts sur la durée s'appelle **DoT** (encore `pain` / « Pain » dans le
code actuel) : « Apply DoT 3 » s'écrira `{ "apply", "pain", 3 }` tant que le renommage n'est pas fait.

## En bref

| Élément | Mage |
|---|---|
| Fantasme | Les sorts les plus forts du jeu, mais en Cast : il doit survivre un tour pour les voir partir. Il manipule le Cast : l'accélère, l'enchaîne. |
| Ce qu'il fait seul | Tenir **deux Cast** à la fois ; **Instant** fait partir la prochaine carte Cast tout de suite. |
| Ressource | **Arcane Charges**, 0 à 4 : chaque charge ajoute 1 dégât à chaque coup de ses cartes Attack ; un Surge les vide. |
| Voies | Fire (enchaîner les gros sorts), Frost (ne jamais être frappé), Arcane (un tour à 6 mana). |
| Survie | Contrôler (Stunned, Demoralized, Absorb). Aucun soin, sauf Ice Block une fois par combat. |
| PV de départ | **60** (Priest 65) : le Mage paie en PV son contrôle et ses gros sorts. |
| Deck de départ | Frostbolt ×3, Mana Shield ×4, Fireball ×2, Arcane Blast ×1. |
| Interrupt | Counterspell (Arcane, niveau 1). |
| Last Breath | Ice Block (Frost, niveau 4). |
| Bibelot de départ | Apprentice's Wand : la première carte Cast de chaque combat coûte 0. |
| Mots-clés propres | Instant, Frozen. |
| Difficulté | Moyenne. |

## 1. Règles propres

### 1.1 Arcane Charges

- Compteur de combat `arcane`, de 0 à 4, affiché dans la pastille violette près du mana (quatre pips).
  Il vaut 0 au début de chaque combat (1 avec Tome of Arcane Brilliance) et disparaît à la fin.
- **Gain** : uniquement par les clauses imprimées « +1 Arcane Charge. ». La charge est gagnée quand la
  clause se résout, dans l'ordre du texte : Arcane Blast et Arcane Missiles infligent leurs dégâts
  **avant** de gagner leur charge (la charge sert dès la carte suivante). Aucune carte Cast ne donne de
  charge dans ce jeu de cartes ; si une le faisait plus tard, la charge viendrait à la résolution.
- **Plafond 4** : un gain au-delà est perdu, sans autre effet (la pastille clignote, événement
  `arcane` avec `n = 0`). Ce n'est pas une punition : à 4, le joueur a intérêt à dépenser.
- **Effet passif** : chaque charge ajoute 1 aux dégâts **de chaque coup** des cartes **Attack** du Mage
  (« three times » : à chaque coup ; « to all » : sur chaque cible). Le bonus s'ajoute à la base comme
  Strength, avant Sundered, Demoralized et la réduction de dégâts subis. Il ne s'applique ni aux DoT,
  ni aux Skills, ni aux dégâts des bibelots et potions. Arcane Power le porte à 2 par charge.
- **Pas de baisse** : les charges se gardent d'un tour à l'autre et ne baissent jamais seules.
- **Dépense : Surge seulement.** Une carte Surge du Mage est injouable à 0 charge (raison affichée
  « No Arcane Charge. »), comme Void Eruption du Priest. À la résolution : on lit le nombre de charges,
  on le remet à 0, puis on applique l'effet avec ce nombre. Le bonus passif ne s'ajoute donc jamais à une
  carte Surge (pas de double comptage). Aucune carte Surge n'est en Cast (le nombre ne change pas entre
  le jeu et l'effet).
- **À 0** : rien de particulier ; les attaques font leurs dégâts imprimés.
- Le choix qui fait le rythme : à 4 charges, chaque attaque fait +4 ; vider d'un Surge rapporte un gros
  coup (24 à tous) mais rend les attaques suivantes plus faibles. On monte en jouant normalement, on
  dépense d'un coup.

### 1.2 Deux Cast à la fois

- Le Mage a **2 emplacements d'incantation** (les autres classes : 1). Une carte Cast jouée sans Instant
  prend un emplacement libre ; si les deux sont pris, toute carte Cast est injouable (raison affichée
  « Two casts in progress. »), sauf sous Instant (1.3).
- Le mana est payé au jeu. Les conditions de la carte (Execute, `DoT:`, Frozen) sont lues **à la
  résolution** (règle commune, inchangée).
- **Ordre au début du tour** : Absorb à 0 → DoT et Regen du Mage → **mana remis à 3** → incantations
  résolues → retour des Cooldown → pioche. Le mana passe avant les incantations pour qu'Evocation
  (« +3 mana ») ne soit pas écrasée par le remplissage (voir Besoins moteur).
- **Ordre entre les deux** : dans l'ordre où elles ont été jouées, la plus ancienne d'abord. Chacune se
  résout entièrement (morts d'ennemis comprises) avant la suivante. Cible morte : premier ennemi vivant
  (règle actuelle). Si la première termine le combat, la seconde est perdue sans effet.
- **Interruption** : une interruption subie (coup marqué `interrupts` qui fait perdre des PV, action
  `interrupt`, Guette du Mystique) annule **une** incantation : **la plus récente**. La carte part à la
  défausse (règle actuelle, même si elle a Exhaust ou Cooldown), le mana est perdu. Une attaque en
  plusieurs coups qui interrompt peut annuler une incantation par coup qui fait perdre des PV.
  Talisman of Focus absorbe la première interruption du combat (donc protège la plus récente).
- Conséquence voulue : la deuxième incantation protège la première. Lancer un petit Cast (Fireball,
  Evocation) après un gros Pyroblast sert de leurre. C'est un savoir-faire du Mage, payé d'une carte et
  d'un emplacement ; la simulation dira s'il est trop fort.
- Absorb protège les incantations (on n'est interrompu que si l'on perd des PV) ; un ennemi Stunned ne
  joue pas, donc n'interrompt pas. C'est le lien entre le contrôle de Frost et les gros sorts de Fire.
- Fin de combat : les incantations en cours sont perdues.

### 1.3 Instant

- **Bienfait à intensité** sur le Mage : « Gain Instant 1 » ajoute 1. Jeton sous le personnage avec le
  nombre. Pas de durée : il ne baisse pas et survit à la fin du tour ; il disparaît en fin de combat.
  Pas de plafond (en pratique 0 à 2). Insignia of the Alliance ne le retire pas (ce n'est pas un état
  négatif).
- **Consommation** : quand une carte Cast est jouée avec Instant ≥ 1, Instant baisse de 1 et la carte
  se résout **tout de suite**, comme une carte ordinaire. Elle ne prend pas d'emplacement : elle est
  jouable même avec deux incantations en cours, et ne peut pas être interrompue.
- **Automatique** : la prochaine carte Cast jouée consomme Instant, quelle qu'elle soit (rythme, pas
  calcul). En main, une carte Cast qui partira tout de suite porte un liseré (voir Besoins moteur).
- **Non consommé** : Instant reste jusqu'à la prochaine carte Cast, même plusieurs tours plus tard.
- Instant ne fait pas partir les incantations déjà en cours.
- Une carte Cast jouée sous Instant reste une carte Cast : Apprentice's Wand, Robe of the Archmage et le
  compte de Hot Streak la voient. Après résolution, elle suit sa plaque (Exhaust, Cooldown, défausse).

### 1.4 Écoles et Hot Streak

- Chaque carte du Mage a une **école** affichée : `fire`, `frost` ou `arcane` (champ `school`, comme
  `holy` / `shadow` chez le Priest). « Fire card » = carte d'école `fire`, quelle que soit sa voie
  (Fireball, de départ, en est une).
- **Compte du tour** : nombre de cartes Fire **jouées** ce tour, compté au moment du jeu (une carte Cast
  compte le tour où elle est jouée, pas le tour où elle se résout ; une carte Cast jouée sous Instant
  compte aussi). Remis à 0 au début de chaque tour.
- **Hot Streak** (Power, « 2nd Fire card each turn: gain Instant 1. ») : quand la deuxième carte Fire du
  tour a fini d'être jouée (résolue, ou posée dans un emplacement), le Mage gagne Instant 1. Une fois par
  tour et par exemplaire en jeu ; deux Hot Streak donnent 2. La deuxième carte n'en profite pas
  elle-même : le rythme est « deux petites, puis la grosse ». Version améliorée : coût 0.
- **Ignite** (Power) : chaque coup d'une carte Fire pose aussi DoT 2 sur la cible touchée (Flamestrike :
  sur chaque cible ; Fireball : en plus de son propre DoT). Une condition `DoT:` lue plus loin dans la
  même carte (Phoenix Flames) voit donc ce DoT.

### 1.5 Frozen

- **Condition nommée** `Frozen:` : la cible est **Stunned ou Demoralized**. Pour une carte « to all »
  ou un Power, elle est testée cible par cible, au moment du coup. Ce n'est pas un état : rien à poser,
  rien de plus à afficher.
- Les boss sont immunisés à Stunned mais pas à Demoralized : **Frozen marche contre les boss**. C'est la
  réponse au risque noté par le GDD (la voie Frost ne s'effondre pas au dernier combat).
- Durées : un Stunned posé pendant le tour est consommé au tour ennemi ; un Demoralized 1 posé pendant
  le tour tombe en fin de round. Les deux rendent la cible Frozen **pour le tour en cours**. Demoralized 2
  tient jusqu'au tour suivant.
- Conditions lues à la résolution : une carte Cast à condition Frozen obligerait à compter les durées
  d'un tour sur l'autre. Choix : **aucune carte Cast du Mage n'a de condition Frozen** (Glacial Spike
  pose Demoralized au lieu de le demander).
- Ice Lance s'écrit `Frozen: deal 8 more.` au lieu de `Stunned: deal 8 more.` (GDD) pour la même raison.

### 1.6 Stunned, Cooldown, Absorb, attaques multiples

- Frost Nova, Polymorph et Deep Freeze ne font rien sur un boss (immunité journalisée) ; Frost Nova
  donne quand même son Absorb, Polymorph sa charge.
- Polymorph pose Stunned 2 : la cible perd ses deux prochains tours (le nombre compte des tours perdus).
- Cooldown : règle commune. Instant n'accélère pas un Cooldown.
- Absorb du Mage : règle commune. Ice Barrier est Retain : on la garde pour le tour du gros coup.
- Attaques multiples du Mage : charges et Shatter s'ajoutent à chaque coup.

### 1.7 Last Breath : Ice Block

- Power. Une fois par combat, quand les PV tomberaient à 0 : PV remis à 0 puis soignés de 10 (par
  `Combat.heal`, donc soumis aux modificateurs de soin), et le Mage gagne l'état **Ice Block** : tous les
  dégâts qu'il subit valent 0 jusqu'au début de son prochain tour. L'état est retiré au début du tour,
  avant les DoT du Mage (comme Pain Suppression). Les coups restants d'une attaque multiple font 0 ; sans
  PV perdus, ils n'interrompent pas.
- Version améliorée : coût 0.

### 1.8 Mots-clés propres (deux)

| Mot-clé | Infobulle (≤ 60 caractères) |
|---|---|
| Instant | Your next Cast card resolves at once. |
| Frozen | If the target is Stunned or Demoralized. |

La ressource a son infobulle, comme Insanity : **Arcane Charge** — « +1 damage per Attack hit, per charge. Max 4. ».
Hot Streak est un nom de carte, pas un mot-clé.

## 2. Les 34 cartes

Raretés : 4 de départ, 13 communes, 11 inhabituelles, 6 rares. Voies : 10 cartes chacune.
« Niv. » = niveau de classe qui la débloque (section 5). « Plaque » = mots de la plaque du bas ; dans
`text` ils restent écrits comme chez le Priest (« Power. » / « Cast. » en tête, « Cooldown N. »,
« Exhaust. », « Retain. » en fin). Icône = nom exact du fichier dans `~/Téléchargements/ICONS/` (champ
`tga` de `UI/Art.lua`), tous vérifiés. Texte « / » = retour de clause. Tous les textes tiennent en 3 lignes
de 22 caractères au plus (même découpe que le Priest, mots insécables compris).

| id | Nom | Voie | École | Rareté | Niv. | Coût | Type | Plaque | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `fireball` | Fireball | départ | fire | départ | 1 | 1 | Attack | Cast | Deal 12. / Apply DoT 2 | Deal 16. / Apply DoT 3 | `Spell_Fire_FlameBolt` |
| `frostbolt` | Frostbolt | départ | frost | départ | 1 | 1 | Attack | — | Deal 6. / Apply Demoralized 1 ⌛ | Deal 9. / Apply Demoralized 1 ⌛ | `Spell_Frost_FrostBolt02` |
| `mana_shield` | Mana Shield | départ | arcane | départ | 1 | 1 | Skill | — | Gain 5 Absorb. | Gain 8 Absorb. | `Spell_Shadow_DetectLesserInvisibility` |
| `arcane_blast` | Arcane Blast | départ | arcane | départ | 1 | 1 | Attack | — | Deal 6. / +1 Arcane Charge. | Deal 9. / +1 Arcane Charge. | `Spell_Arcane_Blast` |
| `fire_blast` | Fire Blast | Fire | fire | commune | 1 | 1 | Attack | Cooldown 2 | Deal 5. / Gain Instant 1 | Deal 8. / Gain Instant 1 | `Spell_Fire_Fireball` |
| `scorch` | Scorch | Fire | fire | commune | 1 | 0 | Attack | — | Deal 3. / Execute: deal 4 more. | Deal 5. / Execute: deal 5 more. | `Spell_Fire_SoulBurn` |
| `flamestrike` | Flamestrike | Fire | fire | commune | 1 | 2 | Attack | Cast | Deal 12 to all. / Apply DoT 3 to all | Deal 16 to all. / Apply DoT 4 to all | `Spell_Fire_SelfDestruct` |
| `blazing_barrier` | Blazing Barrier | Fire | fire | commune | 1 | 1 | Skill | — | Gain 7 Absorb. | Gain 10 Absorb. | `ABILITY_MAGE_MOLTENARMOR` |
| `pyroblast` | Pyroblast | Fire | fire | inhabituelle | 1 | 2 | Attack | Cast | Deal 30. | Deal 38. | `Spell_Fire_Fireball02` |
| `hot_streak` | Hot Streak | Fire | fire | inhabituelle | 1 | 1 | Power | Power | 2nd Fire card each turn: gain Instant 1. | Coût 0, même texte | `Ability_Mage_HotStreak` |
| `living_bomb` | Living Bomb | Fire | fire | inhabituelle | 2 | 1 | Attack | — | Deal 3 to all. / Apply DoT 3 to all | Deal 4 to all. / Apply DoT 5 to all | `Ability_Mage_LivingBomb` |
| `phoenix_flames` | Phoenix Flames | Fire | fire | inhabituelle | 4 | 1 | Attack | Cooldown 1 | Deal 7. / DoT: gain Instant 1. | Deal 10. / DoT: gain Instant 1. | `artifactability_FireMage_PhoenixBolt` |
| `ignite` | Ignite | Fire | fire | rare | 6 | 1 | Power | Power | Your Fire hits also apply DoT 2. | Your Fire hits also apply DoT 3. | `SPELL_FIRE_INCINERATE` |
| `combustion` | Combustion | Fire | fire | rare | 7 | 1 | Skill | Exhaust | Draw 2. / Gain Instant 2 | Coût 0, même texte | `Spell_Fire_SealOfFire` |
| `ice_lance` | Ice Lance | Frost | frost | commune | 1 | 0 | Attack | — | Deal 4. / Frozen: deal 8 more. | Deal 5. / Frozen: deal 10 more. | `Spell_Frost_FrostBlast` |
| `frost_nova` | Frost Nova | Frost | frost | commune | 1 | 1 | Skill | Cooldown 4 | Gain 4 Absorb. / Apply Stunned 1 ⌛ to all | Gain 6 Absorb. / Apply Stunned 1 ⌛ to all (Cooldown 3) | `Spell_Frost_FrostNova` |
| `ice_barrier` | Ice Barrier | Frost | frost | commune | 1 | 1 | Skill | Retain | Gain 8 Absorb. | Gain 11 Absorb. | `Spell_Ice_Lament` |
| `cone_of_cold` | Cone of Cold | Frost | frost | commune | 1 | 1 | Attack | Cooldown 2 | Deal 4 to all. / Apply Demoralized 1 ⌛ to all | Deal 6 to all. / Apply Demoralized 1 ⌛ to all | `Spell_Frost_Glacier` |
| `flurry` | Flurry | Frost | frost | inhabituelle | 1 | 1 | Attack | — | Deal 3 three times. / Apply Demoralized 1 ⌛ | Deal 4 three times. / Apply Demoralized 1 ⌛ | `Ability_warlock_burningembersblue` |
| `blizzard` | Blizzard | Frost | frost | inhabituelle | 1 | 2 | Attack | Cast | Deal 12 to all. / Apply Demoralized 2 ⌛ to all | Deal 15 to all. / Apply Demoralized 2 ⌛ to all | `Spell_Frost_IceStorm` |
| `glacial_spike` | Glacial Spike | Frost | frost | inhabituelle | 2 | 2 | Attack | Cast | Deal 24. / Apply Demoralized 2 ⌛ | Deal 30. / Apply Demoralized 2 ⌛ | `Spell_Frost_Frostbolt` |
| `ice_block` | Ice Block | Frost | frost | rare | 4 | 1 | Power | Power | Last Breath: heal 10, take no damage until your turn. | Coût 0, même texte | `Spell_Frost_Frost` |
| `deep_freeze` | Deep Freeze | Frost | frost | inhabituelle | 6 | 1 | Attack | Cooldown 2 | Deal 8. / Frozen: apply Stunned 1 ⌛. | Deal 11. / Frozen: apply Stunned 1 ⌛. | `Ability_Mage_DeepFreeze` |
| `shatter` | Shatter | Frost | frost | rare | 7 | 1 | Power | Power | Frozen: Attack hits deal 3 more. | Frozen: Attack hits deal 4 more. | `Spell_Frost_WizardMark` |
| `arcane_missiles` | Arcane Missiles | Arcane | arcane | commune | 1 | 1 | Attack | — | Deal 3 three times. / +1 Arcane Charge. | Deal 4 three times. / +1 Arcane Charge. | `Spell_Nature_StarFall` |
| `arcane_explosion` | Arcane Explosion | Arcane | arcane | commune | 1 | 1 | Attack | — | Deal 4 to all. / +1 Arcane Charge. | Deal 6 to all. / +1 Arcane Charge. | `Spell_Nature_WispSplode` |
| `prismatic_barrier` | Prismatic Barrier | Arcane | arcane | commune | 1 | 1 | Skill | — | Gain 6 Absorb. / +1 Arcane Charge. | Gain 9 Absorb. / +1 Arcane Charge. | `Spell_MageArmor` |
| `arcane_barrage` | Arcane Barrage | Arcane | arcane | commune | 1 | 1 | Attack | — | Surge: deal 6 per Arcane Charge to all. | Surge: deal 8 per Arcane Charge to all. | `Ability_Mage_ArcaneBarrage` |
| `counterspell` | Counterspell | Arcane | arcane | inhabituelle | 1 | 0 | Skill | Cooldown 2 | Interrupt the target's cast. / +1 Arcane Charge. | Cooldown 1, même texte | `Spell_Frost_IceShock` |
| `evocation` | Evocation | Arcane | arcane | inhabituelle | 1 | 0 | Skill | Cast, Exhaust | +3 mana. | +4 mana. | `Spell_Nature_Purge` |
| `polymorph` | Polymorph | Arcane | arcane | commune | 2 | 1 | Skill | Exhaust | +1 Arcane Charge. / Apply Stunned 2 ⌛ | Coût 0, même texte | `Spell_Nature_Polymorph` |
| `presence_of_mind` | Presence of Mind | Arcane | arcane | inhabituelle | 4 | 0 | Skill | Cooldown 3 | Draw 1. / +1 Arcane Charge. / Gain Instant 1 | Cooldown 2, même texte | `Spell_Nature_EnchantArmor` |
| `arcane_power` | Arcane Power | Arcane | arcane | rare | 6 | 1 | Power | Power | Arcane Charges add 2 damage, not 1. | Coût 0, même texte | `Spell_Nature_Lightning` |
| `arcane_surge` | Arcane Surge | Arcane | arcane | rare | 7 | 1 | Skill | — | Surge: +1 mana, draw 1 per Arcane Charge. | Coût 0, même texte | `Ability_Mage_ArcaneSurge` |

Deck de départ (10 cartes) : Frostbolt ×3 (l'attaque), Mana Shield ×4 (la défense), Fireball ×2 et
Arcane Blast ×1 (la mécanique : un Cast, une charge).

Notes de calage (référence : Priest à coût et rareté égaux) :
- **Fireball** est en Cast (le GDD l'écrit en attaque immédiate « Deal 8. / Apply DoT 2 ») : le deck de
  départ doit montrer le Cast dès le premier combat, et Apprentice's Wand n'aurait rien à faire sinon.
  Cast à 1 mana : 12 + DoT 2 (Lightning Bolt du Shaman : 14 ; Greater Heal : 12).
- **Frostbolt** reprend le GDD (6 + Demoralized 1) : un peu plus fort que Smite, compensé par 5 PV de
  moins.
- **Frost Nova** gagne « Gain 4 Absorb. » : sans lui, la carte ne fait rien contre un boss.
- **Glacial Spike** pose Demoralized 2 au lieu d'une condition Frozen (1.5) ; 24 pour 2 mana en Cast,
  comme Holy Fire, et le Demoralized marche contre les boss.
- **Ice Lance** garde les chiffres du GDD (4, Frozen +8 à 0 mana), à surveiller (section 7).
- **Evocation** à 0 mana en Cast : +3 mana au tour suivant, soit 6 mana ; sous Instant, +3 tout de suite.
- **Arcane Surge** à 4 charges : +4 mana et 4 cartes pour 1 mana.

## 3. Les trois voies

### Fire — enchaîner les gros sorts

**Moteur.** Les petites cartes Fire (Scorch à 0, Fire Blast, Blazing Barrier, Living Bomb) remplissent
le compte du tour, et Hot Streak, Fire Blast et Phoenix Flames transforment ce rythme en Instant, qui
fait partir Pyroblast ou Flamestrike sans attendre ni risquer l'interruption. La brûlure (DoT) achève
les ennemis entre deux gros sorts ; la survie, c'est de tuer avant d'être tué.

**Cartes.** Fire Blast, Scorch, Flamestrike, Blazing Barrier, Pyroblast, Hot Streak (niveau 1) ; Living
Bomb (2), Phoenix Flames (4), Ignite (6), Combustion (7). Plus Fireball au départ.

**Avec Frost.** Le contrôle de Frost protège les Cast de Fire qui ne partent pas tout de suite (ennemis
Stunned qui n'interrompent pas, Ice Barrier gardée pour couvrir le coup qui interrompt), et l'Instant de
Fire fait partir Blizzard ou Glacial Spike au tour même. Deck attendu : Frostbolt / Cone of Cold pour
tenir, Pyroblast sous Instant pour finir.

**Avec Arcane.** Les charges ajoutent leurs dégâts à chaque coup des attaques Fire (Flamestrike +4 sur
chaque cible à 4 charges) ; Evocation et Arcane Surge donnent le mana de deux Pyroblast dans le même
tour ; Presence of Mind est une source d'Instant de plus.

**Tour type.** Hot Streak en jeu, 3 mana, main : Scorch, Fire Blast, Pyroblast, Mana Shield, Frostbolt.
Scorch (0 mana, 3, Fire n° 1) → Fire Blast (1 mana, 5, Instant 1 ; Fire n° 2 : Hot Streak donne Instant 1
de plus) → Pyroblast (2 mana, Instant consommé : 30 tout de suite, sans risque). 38 dégâts, et il reste
Instant 1 pour la Fireball du tour suivant.

### Frost — ne jamais être frappé

**Moteur.** Demoralized et Stunned posés à chaque tour (Frostbolt, Cone of Cold, Flurry, Frost Nova,
Blizzard) réduisent ou suppriment les coups ennemis et rendent les cibles Frozen. Ice Lance, Deep Freeze
et Shatter font payer ce contrôle, et l'Absorb gardé en main (Ice Barrier, Retain) couvre le seul coup
qui passe.

**Cartes.** Ice Lance, Frost Nova, Ice Barrier, Cone of Cold, Flurry, Blizzard (niveau 1) ; Glacial Spike
(2), Ice Block (4), Deep Freeze (6), Shatter (7). Plus Frostbolt au départ.

**Avec Fire.** Voir Fire : Frost fournit le temps, Fire les dégâts. Blizzard et Glacial Spike deviennent
instantanés avec l'Instant de Fire.

**Avec Arcane.** Polymorph (Stunned 2) rend une cible Frozen deux tours et donne une charge ; Flurry et
Arcane Missiles (trois coups) prennent charges et Shatter à chaque coup ; Arcane Barrage nettoie un
groupe déjà Demoralized par Cone of Cold.

**Tour type.** Deux ennemis, le plus gros annonce 14. Frostbolt sur lui (6, Demoralized 1 : il frappera
pour 10, et il est Frozen) → Ice Lance (0 mana, 4 + 8 = 12) → Cone of Cold (4 à tous, Demoralized 1 à
tous). Ice Barrier reste en main (Retain) pour le tour où Frost Nova sera en Cooldown.

### Arcane — un tour à 6 mana

**Moteur.** Chaque carte Arcane monte d'une charge et chaque charge renforce toutes les attaques ; à 4,
le Mage choisit entre garder le bonus ou tout vider d'un Surge (Arcane Barrage, Arcane Surge).
Evocation, Cast à 0 mana, prépare le tour suivant à 6 mana, où l'on joue tout d'un coup ; Prismatic
Barrier, Polymorph et Counterspell font le contrôle léger.

**Cartes.** Arcane Missiles, Arcane Explosion, Prismatic Barrier, Arcane Barrage, Counterspell, Evocation
(niveau 1) ; Polymorph (2), Presence of Mind (4), Arcane Power (6), Arcane Surge (7). Plus Arcane Blast
et Mana Shield au départ.

**Avec Fire.** Voir Fire : Arcane apporte mana et dégâts par coup, Fire les gros sorts à dépenser.

**Avec Frost.** Voir Frost : Arcane apporte charges et coups multiples, Frost la condition Frozen et le
temps de monter à 4.

**Tour type.** Tour N, 3 charges, 3 mana : Evocation (0, Cast) → Arcane Missiles (1 mana, 3 coups de
3 + 3 = 18, charge 4) → Prismatic Barrier (1 mana, 6 Absorb ; charge perdue, déjà à 4) → Arcane Blast
(1 mana, 6 + 4 = 10). Tour N+1 : Evocation se résout, 6 mana : Arcane Barrage (Surge, 24 à tous), puis
cinq mana pour reconstruire et frapper.

## 4. Bibelots de classe (6)

| id | Nom | Rareté | Niv. | Effet (affiché) | Icône |
|---|---|---|---|---|---|
| `apprentice_wand` | Apprentice's Wand | départ | 1 | Your first Cast card each combat costs 0. | `INV_Wand_01` |
| `tome_arcane_brilliance` | Tome of Arcane Brilliance | commune | 1 | Start each combat with 1 Arcane Charge. | `INV_Misc_Book_09` |
| `robe_archmage` | Robe of the Archmage | inhabituelle | 3 | When one of your Cast cards resolves, gain 4 Absorb. | `INV_Chest_Cloth_25` |
| `glacial_cloak` | Glacial Cloak | inhabituelle | 5 | At the start of each combat, apply Demoralized 1 ⌛ to all enemies. | `INV_Misc_Cape_18` |
| `fire_ruby` | Fire Ruby | rare | 7 | Start each combat with Instant 1. | `INV_Misc_Gem_Ruby_02` |
| `mind_quickening_gem` | Mind Quickening Gem | rare | 7 | If you start a turn at 4 Arcane Charges, gain 1 mana. | `INV_Misc_Gem_Sapphire_01` |

Précisions : la baguette est consommée par la **première** carte Cast jouée, même si elle coûtait déjà 0
(Evocation) — rythme, pas calcul. Robe of the Archmage compte aussi les Cast résolues sous Instant ; au
début du tour, son Absorb arrive après la remise à 0 et tient pendant le tour ennemi suivant. Glacial
Cloak rend tous les ennemis Frozen au premier tour, boss compris. Fire Ruby n'utilise pas
`INV_Misc_Gem_Ruby_01`, déjà pris par Mana Ruby.

## 5. Progression (niveaux de classe 1 à 7)

| Niveau | Fire | Frost | Arcane | Bibelots |
|---|---|---|---|---|
| 1 | Fire Blast, Scorch, Flamestrike, Blazing Barrier, Pyroblast, Hot Streak | Ice Lance, Frost Nova, Ice Barrier, Cone of Cold, Flurry, Blizzard | Arcane Missiles, Arcane Explosion, Prismatic Barrier, Arcane Barrage, Counterspell, Evocation | Apprentice's Wand, Tome of Arcane Brilliance |
| 2 | Living Bomb | Glacial Spike | Polymorph | — |
| 3 | — | — | — | Robe of the Archmage |
| 4 | Phoenix Flames | Ice Block | Presence of Mind | — |
| 5 | — | — | — | Glacial Cloak |
| 6 | Ignite | Deep Freeze | Arcane Power | — |
| 7 | Combustion (rare) | Shatter (rare) | Arcane Surge (rare) | Fire Ruby, Mind Quickening Gem |

Plus les 4 cartes de départ au niveau 1 (22 cartes).

**Un Mage de niveau 1 peut gagner** : chaque voie a déjà son moteur complet. Fire a deux sources
d'Instant (Fire Blast, Hot Streak) et deux gros Cast ; Frost a son contrôle (Frost Nova, Cone of Cold,
Blizzard, Flurry), sa défense (Ice Barrier) et sa récompense (Ice Lance) ; Arcane monte et dépense ses
charges (Missiles, Explosion, Barrage) et a son tour à 6 mana (Evocation). L'Interrupt (Counterspell)
est là dès le départ. La seule sécurité absente est Ice Block.

**Ce que débloquent les niveaux suivants** (des façons de jouer, pas des versions plus fortes) :
- Niveau 2 : Living Bomb (Fire contre les groupes), Glacial Spike (gros Cast Frost, donc Frost + Fire
  sous Instant), Polymorph (contrôle dur en Arcane, qui ouvre Arcane + Frost).
- Niveau 4 : Phoenix Flames (Instant venu de la brûlure : Fire sans Hot Streak), Ice Block (le droit à
  l'erreur), Presence of Mind (Instant en Arcane : Arcane + Fire).
- Niveau 6 : Ignite (Fire qui gagne par la brûlure), Deep Freeze (enchaîner les Stunned sur les
  combats ordinaires), Arcane Power (garder ses charges plutôt que les dépenser).
- Niveau 7 : Combustion (le tour à deux Pyroblast instantanés), Shatter (Frost qui tue par le
  contrôle), Arcane Surge (convertir les charges en mana et en cartes).

## 6. Besoins moteur et interface

Au-delà des règles communes et de ce qu'apportent les classes précédentes (Spend N, Surge générique,
`level` sur les cartes à la place de `rep`) :

1. **Emplacements d'incantation** : `c.player.cast` (une table) devient `c.player.casts` (liste, plus
   ancienne en tête) ; `ns.Classes.mage.castSlots = 2`, 1 par défaut. `Combat.canPlay` : raison
   `"casting"` seulement si la liste est pleine et qu'Instant vaut 0. `resolveCast` : boucle dans
   l'ordre, arrêt si `c.result`. `interruptPlayer` : retire la **dernière** de la liste. `Combat.clone`,
   `Save.lua` et les bots suivent la liste. Texte de raison : « Two casts in progress. ».
2. **Ordre du début de tour** : `p.mana = maxMana` avant la résolution des incantations (pour
   Evocation). Neutre pour le Priest (aucune de ses incantations ne touche au mana) : à confirmer par
   `Sim/tests.lua`.
3. **État `instant`** dans `Core/Statuses.lua` (bienfait sans durée, intensité ; nom « Instant », texte
   « Your next Cast card resolves at once. »). Dans `Combat.play` : si `d.cast` et `st.instant > 0`,
   décompte puis `resolveCard` immédiat, événement `{ t = "cast_instant", card }`, statistique
   `castsInstant`.
4. **Ressource de classe générique** : `c.player.res` (valeur) et `ns.Classes[x].resource = { id =
   "arcane", max = 4 }` ; effet `{ "charge", n }` plafonné, événement `{ t = "arcane", n, total }` ;
   crochet `damage` de classe : `+ charges × perCharge` pour les cartes `type == "attack"` du joueur
   (`perCharge` modifiable par Arcane Power). Effet Surge : lit, remet à 0, puis applique (comme
   `spendDemence`) ; `canPlay` d'une carte Surge : ressource > 0, raison « No Arcane Charge. ».
5. **Événement au jeu** : `Combat.fire(c, "onCardCommitted", inst)` dans `Combat.play`, avant la mise en
   emplacement ou la résolution (l'actuel `onCardPlayed` part à la résolution, trop tard pour Hot
   Streak et la baguette). Compteur `c.turn.schools[school]`, remis à 0 dans `startPlayerTurn`.
6. **Écoles** `fire`, `frost`, `arcane` (champ `school`) : nom affiché, repli d'icône par école dans
   `Art.schools`.
7. **Condition Frozen** : `Combat.isFrozen(unit)` = `stunned > 0 or demoralized > 0`, évaluée par coup
   (crochet `bonus` des effets et crochet `damage` de Shatter, qui reçoit déjà la cible).
8. **État `ice_block`** (immunité, retiré au début du tour comme `halved`) : `calcDamage` renvoie 0 si la
   cible le porte. `preventDeath` d'Ice Block : `hp = 0`, `heal 10`, pose l'état.
9. **Bibelots** : crochet `cost` avec drapeau `c.relicState` consommé à `onCardCommitted` (baguette) ;
   événement `onCastResolved` (Robe) ; `onCombatStart` (Cloak, Ruby, Tome) ; `onTurnStart` lisant la
   ressource (Gem).
10. **Interface** : pastille violette à quatre pips (pip qui clignote quand un gain est perdu) ; deux
    barres d'incantation sous le héros, la plus récente marquée comme celle qu'une interruption
    couperait ; jeton Instant avec nombre ; liseré « partira tout de suite » sur les cartes Cast en main
    quand Instant ≥ 1 ; compteur discret « Fire 1/2 » près du jeton Hot Streak quand il est en jeu ;
    mots-clés Instant et Frozen dans `Art.keywords` (or), infobulle de la ressource ; cartes Surge
    grisées à 0 charge ; aperçu des dégâts en main avec le bonus de charges (comme Strength).
11. **Bots** (`Sim/`) : valeur d'Instant (ne pas jouer une petite Cast juste avant Pyroblast), choix de
    l'ordre des deux Cast face à un coup qui interrompt, moment du Surge (garder 4 charges ou vider),
    Retain d'Ice Barrier.

## 7. Risques d'équilibrage et mesures

**Style de survie : contrôler.** Cible : moins de PV perdus que le Priest, sans soin. Avec 60 PV :
combat normal ≤ 11 PV perdus (Priest 15,4), élite ≤ 15 (Priest 20), boss ≤ 42 (Priest 51,6 sur 65),
victoires heuristic 65–80 %, combats normaux de 4 à 6 tours (le contrôle ne doit pas les allonger
au-delà).

Risques :
- **Ice Lance** (0 mana, 12 sur Frozen) avec trois Frostbolt au départ : la cible est presque toujours
  Frozen. Mesurer son écart `pick=random` ; si > +8, passer à « Deal 3. / Frozen: deal 6 more. ».
- **Instant en boucle** : Hot Streak amélioré (0 mana) + Scorch + Fire Blast + Combustion → plusieurs
  Pyroblast instantanés par combat. Mesurer les Pyroblast par combat et le nombre de tours contre
  VanCleef (cible ≤ 8 ; s'il tombe sous 4, Pyroblast perd 4 dégâts).
- **Leurre de la deuxième incantation** (1.2) : mesurer le taux d'incantations interrompues avec et sans
  la règle « la plus récente » (variante : l'interruption coupe tout).
- **Frost contre le boss** : deck Frost seul forcé (`force=` sur les 10 cartes Frost) contre VanCleef,
  qui est immunisé à Stunned ; si l'écart avec un deck Fire seul dépasse 10 points, renforcer
  Demoralized (Cone of Cold à Demoralized 2) plutôt que les dégâts.
- **Arcane Barrage** (24 à tous à 4 charges, commune) et **Arcane Power** (+8 par coup à 4 charges ;
  Arcane Missiles = +24) : mesurer les dégâts par carte et la répartition des charges au moment du Surge
  (cible : la moitié des Surge à 3 ou 4 charges, sinon le Surge est un calcul raté ou trop facile).
- **Mana** : Evocation + Arcane Surge + Mind Quickening Gem peuvent dépasser ce que la main de 10 permet
  de jouer ; mesurer le mana perdu en fin de tour.
- **Recoupement avec le Shaman** (Maelstrom à 5 rend la prochaine Cast instantanée) : le Mage doit rester
  le seul à tenir deux Cast et à avoir plusieurs sources d'Instant ; le Shaman n'en a qu'une.

Mesures à ajouter aux rapports : PV perdus par combat (par type de rencontre), incantations commencées /
interrompues / instantanées, tours avec deux incantations, Instant perdu en fin de combat, charges au
moment de chaque Surge, part des tours à 4 charges, part des coups ennemis contre une cible Frozen, mana
inutilisé, victoires par deck forcé d'une seule voie et par paire de voies.
