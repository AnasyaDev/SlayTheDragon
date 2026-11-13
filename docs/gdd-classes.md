# Slay the Dragon — GDD des classes

> Copie fidèle du Claude Doc « Slay the Dragon — GDD des classes » (nœud b69dfa69-5ff0, révision 357, lue le 2026-11-12).
> Le document source fait foi ; cette copie sert de référence aux agents. Les lignes « => » de la fin sont les réponses du joueur, déjà intégrées dans « Décisions prises ».

2026-11-11

## Comment lire ce document

Chaque classe est un jeu de cartes à part, avec sa propre mécanique, comme l'Ironclad, la Silent, le Defect et la Watcher de Slay the Spire. Ce document fixe ce que toutes les classes partagent, puis ce qui rend chacune unique.

Il complète le [GDD général](docs/), qui décrit l'expédition, la méta-progression et l'interface. Il ne les répète pas.

- **Ce qui est fixé ici :** le fantasme de chaque classe, sa ressource, ses trois voies, ses mots-clés propres et quelques cartes phares qui montrent comment elle se joue.
- **Ce qui ne l'est pas :** la liste complète des cartes et les chiffres. Les valeurs données sont des ordres de grandeur, à régler par simulation comme pour le Priest.
- **Langue :** les textes du jeu sont en anglais. Les noms de cartes, d'états et de mots-clés sont donc écrits en anglais, tels qu'ils apparaîtront.
- **Hypothèse :** les neuf classes de l'ère classique. Le Priest est jouable ; les huit autres sont à produire.

## Mécaniques communes

Toutes les classes jouent le même tour, lisent les mêmes mots-clés et affrontent les mêmes ennemis. Une classe ajoute des règles ; elle n'en retire aucune.

### Le tour

1. Début du tour : l'Absorb restant disparaît, DoT et Regen se déclenchent, les cartes en Cast du tour précédent se résolvent.
2. On pioche 5 cartes (main de 10 au plus) et on reçoit 3 mana.
3. On joue ses cartes dans l'ordre voulu. Les intentions des ennemis sont visibles.
4. Fin du tour : la main est défaussée, sauf les cartes Retain. Les ennemis agissent.

### Types de cartes

| Type | Rôle |
|---|---|
| Attack | Inflige des dégâts. C'est ce que modifient Strength, Sundered et Demoralized. |
| Skill | Tout le reste : défense, soin, pioche, états. |
| Power | Reste actif jusqu'à la fin du combat et laisse une icône sous le personnage. |

### Mots-clés communs

| Mot-clé | Règle |
|---|---|
| Cast | La carte se résout au début du prochain tour. En échange, elle est plus forte que son coût. |
| Interrupt | Annule le sort qu'un ennemi incante. Chaque classe en a au moins une carte. |
| Cooldown N | La carte revient en main après N tours au lieu de passer par la défausse. |
| Exhaust | La carte quitte le combat une fois jouée. |
| Retain | La carte reste en main à la fin du tour. |
| Execute | Condition : la cible a la moitié de ses PV ou moins. |
| Surge | Condition : dépense toute la ressource de classe ; l'effet grandit avec le montant. |
| Last Breath | Une fois par combat, en tombant à 0 PV. |

Deux formes nouvelles sont nécessaires pour les autres classes :

- **Spend N :** dépense N points de la ressource de classe pour obtenir l'effet. Sans les points, la carte se joue quand même, sans ce bonus.
- **Trap :** la carte est posée maintenant et se déclenche à la prochaine attaque ennemie. C'est le seul effet du jeu qui agit pendant le tour adverse.

### États communs

| État | Effet | Compte |
|---|---|---|
| Absorb | Encaisse les dégâts jusqu'au prochain tour. | Points |
| DoT | X dégâts au début du tour du porteur, puis X baisse de 1. Ignore l'Absorb. | Intensité |
| Regen | Soigne X au début du tour, puis X baisse de 1. | Intensité |
| Sundered | Subit 25 % de dégâts en plus. | Tours |
| Demoralized | Inflige 25 % de dégâts en moins. | Tours |
| Stunned | Perd son prochain tour. Les boss y sont immunisés. | Tours |
| Strength | Inflige X de plus par coup, pour tout le combat. | Intensité |

### Langage des cartes

Une carte s'écrit en clauses courtes, une par ligne : `Deal 6.`, `Gain 5 Absorb.`, `Draw 1.`. Une condition s'écrit `Name: effect`, que ce soit un état (`Atonement: +1 mana.`), une forme (`Bear: +4 Absorb.`) ou une condition nommée (`Execute: deal 12.`). Les états posés vont en dernière ligne : `Gain Atonement 1 ⌛` sur soi, `Apply DoT 5` sur un ennemi. Le sablier marque une durée en tours.

## Gabarit d'une classe

Une classe se définit par sept choses, dans le même format que le Priest. Ce gabarit sert de liste de contrôle avant de produire une classe.

| Élément | Règle |
|---|---|
| Ressource de classe | Une seule, affichée dans la pastille violette près du mana. Elle vit le temps d'un combat. |
| Trois voies | Les trois spécialisations de WoW. 10 cartes chacune, chaque voie ayant son propre moteur. |
| Cartes de départ | 10 cartes faites de 4 cartes différentes : une attaque, une défense, et deux cartes qui montrent la mécanique de classe. |
| Raretés | 34 cartes : 4 de départ, 13 communes, 11 inhabituelles, 6 rares. |
| Interrupt | Au moins une carte, puisque les ennemis incantent. |
| Bibelot de classe | Un bibelot de départ qui amorce la mécanique dès le premier tour. |
| Mots-clés propres | Deux au plus. Au-delà, la classe devient illisible. |
| Style de survie | Un style dominant parmi quatre : tuer vite, contrôler, se soigner, encaisser (Absorb ou Parry). |

Trois règles de conception valent pour toutes :

- **Chaque voie se suffit, deux voies se combinent.** Un deck d'une seule voie doit gagner ; le meilleur deck en croise deux. Le Priest le fait déjà : Atonement (Discipline) rend rentables les attaques de Shadow.
- **La ressource récompense un rythme, pas un calcul.** On la monte en jouant normalement et on la dépense d'un coup. Le plafond se décide classe par classe : l'Insanity du Priest n'en a pas.
- **La survie change de forme, pas de niveau.** Toutes les classes n'ont pas de soin. Chacune a un style dominant : tuer vite, contrôler, se soigner ou encaisser, et les ennemis ne doivent jamais supposer un soigneur.

## Les neuf classes en un coup d'œil

Chaque classe a une chose qu'aucune autre ne fait. C'est elle qui décide si la classe mérite d'exister.

| Classe | Ressource | Ce qu'elle seule fait | Survie | Difficulté |
|---|---|---|---|---|
| Priest | Insanity (sans plafond) | Soigne en attaquant (Atonement) | Soin | Moyenne |
| Warrior | Rage (0 à 5) | Gagne sa ressource en prenant des coups | Absorb | Facile |
| Rogue | Combo Points (0 à 5) | Enchaîne des cartes à 0 mana avant un coup de grâce | Vitesse, Parry | Moyenne |
| Mage | Arcane Charges (0 à 4) | Maîtrise le Cast : l'accélère, l'enchaîne | Contrôle | Moyenne |
| Warlock | Soul Shards (0 à 5) | Paie ses cartes en PV | Drain de vie | Difficile |
| Hunter | Frenzy du familier (0 à 5) | A un familier qui attaque seul, et pose des Traps | Contrôle | Facile |
| Paladin | Holy Power (0 à 3) | Porte un Seal qui transforme son Judgement | Absorb, soin | Facile |
| Shaman | Maelstrom (0 à 5) | Pose des totems à durée limitée, un par élément | Soin, Absorb | Difficile |
| Druid | Forme active | Change de forme, et ses cartes changent avec | Selon la forme | Difficile |

## Priest (jouable)

Le Priest soigne en frappant et transforme la patience en un seul gros tour. C'est la classe de référence : ses 34 cartes existent et sont équilibrées par simulation.

**Ressource : Insanity.** Les cartes Shadow en donnent 1 ou 2. Les cartes Surge la dépensent entièrement.

**Mécanique propre : Atonement.** Tant que l'état dure, chaque carte qui inflige des dégâts rend 2 PV. Le Priest ne choisit donc pas entre attaquer et se soigner ; il choisit quand ouvrir sa fenêtre d'Atonement.

| Voie | Moteur | Carte phare |
|---|---|---|
| Discipline | Atonement et Absorb : on se protège, puis on attaque pour se soigner. | Penance : `Deal 6 three times.` / `Atonement: +2 Absorb per hit.` |
| Shadow | DoT sur les ennemis, Insanity qui monte, puis Surge. | Void Eruption : `Surge: deal 4 + 4 per Insanity.` |
| Holy | Regen, soins directs et gros sorts en Cast. | Halo (Cast) : `Deal 15 to all.` / `Gain Regen 3` |

- **Deck de départ :** Smite, Inner Fire, PW: Shield, SW: Pain.
- **Interrupt :** Silence.
- **Last Breath :** Spirit of Redemption.
- **Ce qu'il enseigne :** les durées en tours, le Cast et la lecture des intentions. C'est pourquoi il reste la première classe proposée.

## Warrior

Le Warrior devient plus dangereux à mesure qu'on le frappe. C'est la classe la plus simple à lire, l'équivalent de l'Ironclad, et la deuxième à produire.

**Ressource : Rage (0 à 5).** +1 chaque fois qu'il perd des PV sur une attaque, +1 par carte Attack jouée. Elle se garde d'un tour à l'autre. Les cartes la dépensent par `Spend N` ou par `Surge`.

**Mécanique propre : encaisser paie.** Bloquer tout avec de l'Absorb prive de Rage. Le joueur décide donc, à chaque tour, combien de dégâts il accepte de prendre. Aucune autre classe n'a intérêt à être touchée.

| Voie | Moteur | Ce qu'elle cherche |
|---|---|---|
| Arms | Sundered, puis un seul gros coup. Execute sur les cibles entamées. | Un tour de mise à mort |
| Fury | Beaucoup de petites attaques, Strength qui monte, cartes payées en PV. | Le nombre de coups |
| Protection | Absorb converti en dégâts, ripostes quand il est frappé. | Tenir, puis rendre |

| Carte | Coût | Type | Texte |
|---|---|---|---|
| Heroic Strike | 1 | Attack | `Deal 7.` / `Spend 2: deal 5 more.` |
| Mortal Strike | 2 | Attack | `Deal 12.` / `Apply Sundered 2 ⌛` |
| Execute | 1 | Attack | `Deal 5.` / `Execute: Surge: deal 6 per Rage.` |
| Bloodthirst | 1 | Attack | `Deal 6.` / `Heal 2.` / `Gain Strength 1` (Cooldown 2) |
| Shield Slam | 1 | Attack | `Deal damage equal to your Absorb.` |
| Revenge | 0 | Attack | `Deal 4.` / `Retain.` Coûte 0 seulement si on a perdu des PV au tour précédent. |
| Enrage | 1 | Power | `Whenever you lose HP: gain Strength 1 this turn.` |

- **Deck de départ :** Strike, Defend (Absorb), Heroic Strike, Bloodrage (`Lose 3 HP. Gain 2 Rage. Draw 1.`).
- **Interrupt :** Pummel.
- **Last Breath :** Last Stand.
- **Bibelot de classe :** Battle Standard, +1 Rage au début de chaque combat.
- **Risque :** sans soin, une expédition longue l'use. Bloodthirst et le feu de camp doivent suffire ; à mesurer en simulation avant tout autre réglage.

## Rogue

Le Rogue joue beaucoup de cartes peu chères, puis un coup de grâce qui les encaisse toutes. Il ne bloque pas : il pare un coup à la fois et tue avant le suivant.

**Ressource : Combo Points (0 à 5).** Les cartes d'ouverture en donnent 1. Les coups de grâce sont des cartes `Surge`. Les points se gardent d'un tour à l'autre.

**Mécanique propre : Parry et Stealth.** Parry est un état empilable : chaque charge annule la prochaine attaque subie, jusqu'à 8 dégâts. Il est fort contre un gros coup et faible contre plusieurs petits, à l'inverse de l'Absorb. Stealth est un second état, qu'il a au début de chaque combat : sa première carte Attack le consomme pour un effet `Stealth:` plus fort. Certaines cartes le rendent en cours de combat.

| Voie | Moteur | Ce qu'elle cherche |
|---|---|---|
| Assassination | DoT (poisons) qui s'empile, puis un Surge qui le fait exploser. | La durée |
| Combat | Cartes à 0 mana, pioche, dégâts de zone. | Jouer huit cartes par tour |
| Subtlety | Retrouver Stealth plusieurs fois, ouvertures très fortes. | Le premier coup |

| Carte | Coût | Type | Texte |
|---|---|---|---|
| Sinister Strike | 1 | Attack | `Deal 6.` / `+1 Combo Point.` |
| Backstab | 0 | Attack | `Deal 4.` / `+1 Combo Point.` / `Stealth: deal 8 more.` |
| Eviscerate | 1 | Attack | `Surge: deal 5 + 5 per Combo Point.` |
| Envenom | 1 | Attack | `Surge: apply DoT 2 per Combo Point, then trigger the target's DoT.` |
| Slice and Dice | 1 | Power | `The first Attack each turn costs 0.` |
| Vanish | 1 | Skill | `Gain Stealth.` / `Draw 1.` (Exhaust) |
| Evasion | 1 | Skill | `Gain Parry 2` (Cooldown 3) |

- **Deck de départ :** Sinister Strike, Feint (Parry), Backstab, Eviscerate.
- **Interrupt :** Kick, à 0 mana.
- **Last Breath :** Cheat Death.
- **Bibelot de classe :** Thieves' Tools, pioche 1 carte de plus au premier tour.
- **Risque :** les tours à huit cartes sont longs à jouer en vol. La voie Combat doit rester lisible : pioche plafonnée par la main de 10.

## Mage

Le Mage a les sorts les plus forts du jeu, mais ils sont en Cast : il doit survivre un tour pour les voir partir. Sa classe est celle qui manipule le Cast.

**Ressource : Arcane Charges (0 à 4).** Les cartes Arcane en donnent 1. Chaque charge ajoute 1 dégât à toutes ses cartes Attack. Un `Surge` les vide.

**Mécanique propre : accélérer le Cast.** Certaines cartes donnent `Instant` : la prochaine carte Cast se résout tout de suite. Le Mage est aussi la seule classe à pouvoir tenir deux Cast à la fois.

| Voie | Moteur | Ce qu'elle cherche |
|---|---|---|
| Fire | Deux cartes Fire dans le tour donnent `Instant` (Hot Streak). DoT sous forme de brûlure. | Enchaîner les gros sorts |
| Frost | Stunned et Demoralized, Absorb, bonus contre les cibles contrôlées. | Ne jamais être frappé |
| Arcane | Charges qui montent, mana en plus, puis Surge. | Un tour à 6 mana |

| Carte | Coût | Type | Texte |
|---|---|---|---|
| Fireball | 1 | Attack | `Deal 8.` / `Apply DoT 2` |
| Pyroblast | 2 | Attack (Cast) | `Deal 30.` |
| Hot Streak | 1 | Power | `After 2 Fire cards in a turn: gain Instant.` |
| Frost Nova | 1 | Skill | `Apply Stunned 1 ⌛ to all` (Cooldown 4) |
| Ice Lance | 0 | Attack | `Deal 4.` / `Stunned: deal 8 more.` |
| Arcane Blast | 1 | Attack | `Deal 6.` / `+1 Arcane Charge.` |
| Arcane Barrage | 1 | Attack | `Surge: deal 6 per Arcane Charge to all.` |
| Evocation | 0 | Skill (Cast) | `+3 mana.` (Exhaust) |

- **Deck de départ :** Frostbolt (`Deal 6.` / `Apply Demoralized 1 ⌛`), Mana Shield (Absorb), Fireball, Arcane Blast.
- **Interrupt :** Counterspell.
- **Last Breath :** Ice Block.
- **Bibelot de classe :** Apprentice's Wand, la première carte Cast de chaque combat coûte 0.
- **Risque :** les boss sont immunisés à Stunned. La voie Frost doit pouvoir les ralentir autrement (Demoralized, Absorb), sinon elle s'effondre au dernier combat.

## Warlock

Le Warlock paie ses meilleures cartes avec ses propres PV et les récupère en drainant ses ennemis. Sa barre de vie est une deuxième réserve de mana.

**Ressource : Soul Shards (0 à 5).** +1 à la mort d'un ennemi, +1 par carte de drain. Les grosses cartes en demandent par `Spend N`.

**Mécanique propre : `Pay N HP`.** Un coût en PV, écrit en première ligne de la carte. Il ne peut pas tuer : la carte est injouable si elle ferait tomber à 0. Les cartes à coût en PV sont nettement plus fortes que leur coût en mana.

| Voie | Moteur | Ce qu'elle cherche |
|---|---|---|
| Affliction | DoT sur tous les ennemis, empêché de baisser, puis drain proportionnel. | Le combat long |
| Demonology | Un démon invoqué (Power) agit à chaque fin de tour ; les cartes le renforcent. | Un moteur permanent |
| Destruction | Gros sorts en Cast payés en Soul Shards. | Le coup unique |

| Carte | Coût | Type | Texte |
|---|---|---|---|
| Life Tap | 0 | Skill | `Pay 4 HP.` / `Draw 2.` |
| Corruption | 1 | Skill | `Apply DoT 6` |
| Drain Life | 1 | Attack | `Deal 5.` / `Heal 5.` / `+1 Soul Shard.` |
| Agony | 1 | Power | `DoT on enemies no longer drops.` |
| Summon Imp | 1 | Power | `At the end of your turn: deal 3 to a random enemy.` |
| Chaos Bolt | 2 | Attack (Cast) | `Deal 20.` / `Spend 2: deal 12 more and ignore Absorb.` |
| Shadowburn | 1 | Attack | `Deal 8.` / `Execute: +2 Soul Shards.` |
| Dark Pact | 0 | Skill | `Pay 6 HP.` / `Gain 14 Absorb.` |

- **Deck de départ :** Shadow Bolt, Demon Skin (Absorb), Corruption, Life Tap.
- **Interrupt :** Spell Lock.
- **Last Breath :** Soulstone.
- **Bibelot de classe :** Healthstone, une fois par combat, rend 8 PV quand les PV passent sous la moitié.
- **Risque :** partage le DoT avec le Priest Shadow et le Rogue. Sa différence doit rester nette : lui seul empêche le DoT de baisser, et lui seul se soigne dessus.

## Hunter

Le Hunter ne combat jamais seul : son familier attaque à chaque fin de tour, sans carte ni mana. Le joueur joue autour de ce métronome.

**Ressource : Frenzy (0 à 5).** +1 à chaque attaque du familier. Chaque point ajoute 1 dégât à ses attaques. Un `Surge` la vide.

**Mécanique propre : le familier et les Traps.** Le familier inflige 3 à l'ennemi ciblé en dernier, à la fin de chaque tour. Il n'a pas de PV et ne peut pas mourir. Les cartes `Trap` se déclenchent pendant le tour ennemi, à la première attaque subie.

| Voie | Moteur | Ce qu'elle cherche |
|---|---|---|
| Beast Mastery | Faire attaquer le familier plus souvent et plus fort. | Le Frenzy à 5 |
| Marksmanship | Tirs en Cast, bonus contre une cible encore intacte. | Tuer avant le premier coup |
| Survival | Traps, DoT (piqûres), contrôle. | Punir chaque attaque ennemie |

| Carte | Coût | Type | Texte |
|---|---|---|---|
| Arcane Shot | 1 | Attack | `Deal 6.` / `Your pet attacks.` |
| Kill Command | 1 | Attack | `Your pet attacks twice.` (Cooldown 2) |
| Bestial Wrath | 1 | Skill | `Surge: your pet attacks once per Frenzy.` |
| Aimed Shot | 2 | Attack (Cast) | `Deal 22.` / `Target above half HP: deal 10 more.` |
| Hunter's Mark | 0 | Skill | `Apply Sundered 3 ⌛` (Exhaust) |
| Freezing Trap | 1 | Skill (Trap) | `Apply Stunned 1 ⌛ to the attacker.` |
| Explosive Trap | 1 | Skill (Trap) | `Deal 8 to all.` / `Apply DoT 3 to all` |
| Serpent Sting | 1 | Skill | `Apply DoT 5` / `Draw 1.` |

- **Deck de départ :** Arcane Shot, Disengage (Absorb), Serpent Sting, Freezing Trap.
- **Interrupt :** Counter Shot.
- **Last Breath :** Feign Death.
- **Bibelot de classe :** Pet Whistle, le familier attaque aussi au début du premier tour.
- **Risque :** un familier qui joue tout seul peut rendre la classe passive. Les meilleures cartes doivent le commander, pas l'ignorer.

## Paladin

Le Paladin choisit un Seal, qui change ce que fait son Judgement, et lance un gros effet tous les trois points de Holy Power. C'est une classe régulière et robuste, facile à prendre en main.

**Ressource : Holy Power (0 à 3).** Les cartes de base en donnent 1. Les cartes fortes demandent `Spend 3`. Le rythme est donc fixe : trois cartes, puis une récompense.

**Mécanique propre : les Seals.** Un Seal est un Power dont un seul peut être actif : en jouer un autre le remplace. Chaque Seal a un effet permanent et un effet `Judgement:`, déclenché par les cartes Judgement. Changer de Seal en cours de combat est une vraie décision.

| Voie | Moteur | Ce qu'elle cherche |
|---|---|---|
| Retribution | Seals offensifs, Judgement, Strength. | Le Judgement à chaque tour |
| Protection | Absorb, dégâts de zone permanents, ripostes. | L'usure |
| Holy | Soins, cartes qui frappent ou soignent au choix. | Ne jamais descendre |

| Carte | Coût | Type | Texte |
|---|---|---|---|
| Crusader Strike | 1 | Attack | `Deal 6.` / `+1 Holy Power.` |
| Judgement | 1 | Attack | `Deal 5.` / `Trigger your Seal's Judgement.` (Cooldown 1) |
| Seal of Command | 1 | Power (Seal) | `Your Attacks deal 2 more.` / `Judgement: deal 8 more.` |
| Seal of Light | 1 | Power (Seal) | `Your Attacks heal 1.` / `Judgement: heal 6.` |
| Templar's Verdict | 1 | Attack | `Deal 8.` / `Spend 3: deal 14 more.` |
| Consecration | 2 | Power | `At the end of your turn: deal 3 to all.` |
| Holy Shock | 1 | Skill | `Deal 8 or heal 8.` / `+1 Holy Power.` |
| Divine Shield | 2 | Skill | `Take no damage until your next turn.` (Exhaust, Retain) |

- **Deck de départ :** Crusader Strike, Holy Shield (Absorb), Judgement, Seal of Righteousness.
- **Interrupt :** Rebuke.
- **Last Breath :** Lay on Hands.
- **Bibelot de classe :** Libram, +1 Holy Power au début de chaque combat.
- **Risque :** proche du Priest Holy par le soin et du Warrior Protection par l'Absorb. Le Seal unique et le rythme de trois doivent porter toute son identité.

## Shaman

Le Shaman pose des totems qui travaillent pour lui pendant quelques tours, puis s'éteignent. Il gère quatre emplacements et leurs durées : c'est l'équivalent des orbes du Defect.

**Ressource : Maelstrom (0 à 5).** +1 par carte Attack jouée. À 5, la prochaine carte Cast se résout tout de suite et le Maelstrom retombe à 0.

**Mécanique propre : les totems.** Un totem est une carte `Totem N ⌛` : un Power qui dure N tours. Il occupe l'emplacement de son élément (Fire, Earth, Water, Air). Un nouveau totem du même élément remplace l'ancien. Quatre totems actifs au plus, un par élément.

| Voie | Moteur | Ce qu'elle cherche |
|---|---|---|
| Elemental | Sorts en Cast, totems de Fire, bonus contre les cibles sous DoT. | Les Cast instantanés |
| Enhancement | Attaques nombreuses qui chargent le Maelstrom, totems d'Air. | Le Maelstrom à 5 chaque tour |
| Restoration | Totems de Water (Regen), Absorb qui réagit aux coups. | Quatre totems en même temps |

| Carte | Coût | Type | Texte |
|---|---|---|---|
| Lightning Bolt | 1 | Attack (Cast) | `Deal 14.` |
| Flame Shock | 1 | Attack | `Deal 4.` / `Apply DoT 4` |
| Lava Burst | 2 | Attack (Cast) | `Deal 18.` / `DoT: deal 10 more.` |
| Stormstrike | 1 | Attack | `Deal 4 twice.` (Cooldown 1) |
| Searing Totem | 1 | Power (Totem 3 ⌛, Fire) | `At the end of your turn: deal 4 to a random enemy.` |
| Healing Stream Totem | 1 | Power (Totem 3 ⌛, Water) | `At the start of your turn: heal 3.` |
| Windfury Totem | 1 | Power (Totem 2 ⌛, Air) | `Your first Attack each turn is played twice.` |
| Stoneskin Totem | 1 | Power (Totem 3 ⌛, Earth) | `At the start of your turn: gain 4 Absorb.` |

- **Deck de départ :** Lightning Bolt, Lightning Shield (Absorb), Flame Shock, Searing Totem.
- **Interrupt :** Wind Shear, à 0 mana.
- **Last Breath :** Reincarnation.
- **Bibelot de classe :** Totemic Relic, le premier totem de chaque combat dure 1 tour de plus.
- **Risque :** c'est la classe la plus chargée à l'écran. Les quatre emplacements doivent se lire d'un regard, avec leur durée restante, sans texte.

## Druid

Le Druid a une forme active, et la même carte ne fait pas la même chose selon la forme. C'est l'équivalent des postures de la Watcher, et la classe la plus exigeante.

**Ressource : la forme active.** La pastille de classe affiche la forme, pas un nombre. Il y en a quatre : Caster (au départ), Bear, Cat, Moonkin. Une carte `Shift` fait entrer dans une forme et l'on y reste jusqu'au prochain Shift.

**Mécanique propre : `Forme: effet`.** Beaucoup de cartes ont une ligne par forme, écrite avec la condition habituelle. Changer de forme déclenche aussi les effets `Shift:` de certains Powers. Le Druid gagne donc à changer souvent, pas à rester.

| Forme | Effet permanent |
|---|---|
| Caster | Aucun. Seule forme où les soins sont jouables. |
| Bear | L'Absorb gagné augmente de moitié. |
| Cat | La première carte Attack de chaque tour coûte 0. |
| Moonkin | Les cartes Cast infligent 4 de plus. |

| Voie | Moteur | Ce qu'elle cherche |
|---|---|---|
| Balance | Moonkin, Cast, DoT sur tous les ennemis (Moonfire). | Les gros Cast |
| Feral | Bear pour tenir, Cat pour frapper, en alternant. | Le Shift à chaque tour |
| Restoration | Regen empilé, puis consommé pour un soin immédiat. | Le combat long |

| Carte | Coût | Type | Texte |
|---|---|---|---|
| Bear Form | 0 | Skill (Shift) | `Enter Bear.` / `Gain 4 Absorb.` |
| Cat Form | 0 | Skill (Shift) | `Enter Cat.` / `Draw 1.` |
| Maul | 1 | Attack | `Deal 7.` / `Bear: gain 5 Absorb.` / `Cat: apply DoT 4.` |
| Wrath | 1 | Attack | `Deal 7.` / `Moonkin: deal 4 more.` |
| Starfire | 2 | Attack (Cast) | `Deal 20.` |
| Rejuvenation | 1 | Skill | `Gain Regen 4` |
| Swiftmend | 0 | Skill | `Heal twice your Regen.` (Cooldown 2) |
| Feral Instinct | 1 | Power | `Shift: deal 3 to all.` |

- **Deck de départ :** Wrath, Bear Form, Maul, Rejuvenation.
- **Interrupt :** Skull Bash.
- **Last Breath :** Rebirth.
- **Bibelot de classe :** Idol of the Wild, le premier Shift de chaque tour donne 1 mana.
- **Risque :** trois lignes de forme sur une carte ne tiennent pas dans le panneau de texte. Limite à fixer : deux lignes de forme par carte au plus, et la ligne de la forme active mise en évidence.

## Progression par classe

Toutes les classes sont jouables dès le départ, mais chacune commence avec une partie seulement de ses cartes et de ses bibelots. Jouer une classe la fait monter en niveau et débloque le reste.

- **Niveau de classe :** de 1 à 7, propre à chaque classe. Chaque expédition donne de l'expérience à la classe jouée, gagnée ou perdue.
- **Réputation :** ~~celle de la Ligue des explorateurs reste commune au compte~~ — remplacée le 13/11/2026 par la campagne par zones (`docs/zones.md`) : la première victoire du compte dans une zone débloque le commun (bibelots communs, cartes neutres, rencontres) ; les clés sont comptées par zone et par classe.

| Niveau | Déblocage |
|---|---|
| 1 | 22 cartes (les 4 de départ et 6 par voie), 2 bibelots de classe |
| 2 | 3 cartes, une par voie |
| 3 | 1 bibelot de classe |
| 4 | 3 cartes, une par voie |
| 5 | 1 bibelot de classe |
| 6 | 3 cartes, une par voie |
| 7 | 3 cartes rares, une par voie, et 2 bibelots de classe |

### Écran de progression

Un écran par classe montre tout ce qu'elle contient, débloqué ou non : ses 34 cartes rangées par voie, ses 6 bibelots, son niveau et sa barre d'expérience.

- **Débloqué :** la carte ou le bibelot s'affiche normalement, avec son infobulle.
- **Verrouillé :** icône grisée, ni nom ni texte. L'infobulle ne dit que la condition, par exemple `Priest level 4`. Le joueur sait quoi viser sans savoir ce qu'il obtiendra.

Les premières cartes débloquées doivent ouvrir des façons de jouer, pas seulement être plus fortes : un joueur de niveau 1 doit pouvoir gagner.

## Ordre de production et questions ouvertes

Le Warrior vient en premier : il ne demande que `Spend N` et la Rage, et il éprouve le jeu sans soin. Chaque classe suivante ajoute une seule nouveauté au moteur.

| Ordre | Classe | Ce qu'il faut ajouter au moteur |
|---|---|---|
| 1 | Warrior | `Spend N`, ressource gagnée en perdant des PV |
| 2 | Rogue | États Parry et Stealth |
| 3 | Paladin | Emplacement unique de Seal, effet `Judgement:` |
| 4 | Mage | `Instant`, deux Cast simultanés |
| 5 | Warlock | Coût `Pay N HP`, Power qui agit en fin de tour |
| 6 | Hunter | Familier, cartes `Trap` pendant le tour ennemi |
| 7 | Shaman | Powers à durée (`Totem N`), quatre emplacements |
| 8 | Druid | Formes, cartes à plusieurs lignes conditionnelles |

Décisions prises le 11 novembre 2026 :

- **Un seul état de dégâts sur la durée, nommé DoT.** Une règle, un compteur, un nom que tout joueur de WoW connaît. L'icône peut changer selon la source (poison, brûlure, saignement), pas la règle.
- **Cartes neutres : oui.** Une dizaine, tirées des métiers et des objets, chez le marchand et dans les rencontres seulement.
- **L'Insanity reste sans plafond.** La laisser monter pour tout dépenser est l'identité du Priest Shadow. Le plafond se décide classe par classe.
- **Une grande table de bibelots, communs et spécifiques.** Ordre de grandeur : une trentaine de communs et six par classe. Premier pas : classer les douze actuels.
- **Un style de survie par classe.** Tuer vite, contrôler, se soigner ou encaisser. Le Rogue pare (Parry) au lieu d'absorber.
- **Toutes les classes dès le départ, avec une progression propre à chacune.** Voir « Progression par classe ».

 => "DoT" comme nom ? C'est con nu des joueurs de WoW.

 OUI ! Très bonne idée

 => Non, je pense que laisser buildup l'insanité pour tout dépenser peut être marrant.

 => Il faut une table assez grande de bibelots, certains communs ,d'autres spécifiques.

 => Chaque classe doit avoir un moyen de soit tuer très vite les ennemis, soit les controler, soit se soigner, soit parer/esquiver/bloquer/absorber, etc... Il y a plei nde styles différents de jeu, et certaines classes correspondent plus à un style que d'autres (par exemple ,le rogue peut avoir des cartes de parades empilables qui parent la prochaine attaque pour maximum 8 dégâts (un exemple))

 => Dès le départ, tout disponible, mais il faut que chaque classe ait de la meta progression sur ses cartes, débloquer de novuelles, de nouveaux bibelots, et cela impliqueu n écran de "progression" où on voit ce qu'o na débloqué et ce qui manque, masqué par des icones grisées et des infobulles vides

Reste ouvert :

- Quels bibelots actuels restent communs, lesquels deviennent propres au Priest ?
- Quelle cible de PV perdus par combat pour chaque style de survie ? À mesurer en simulation, classe par classe.
- Quelles 12 cartes du Priest passent en déblocage ? Le choix change son équilibrage actuel.
