# Hunter — fiche de conception

Développe la section « Hunter » du GDD des classes (Claude Docs) sans la contredire. Prête à implémenter :
règles au cas limite près, 34 cartes, bibelots, progression, besoins moteur et interface. Les chiffres sont
des points de départ calés sur le Priest (`Data/Priest.lua`) ; la simulation les réglera.

| | |
|---|---|
| Fantasme | Le Hunter ne combat jamais seul : son familier attaque à chaque fin de tour, et le joueur le commande. |
| Ce qu'il est seul à faire | Un familier qui attaque sans carte ni mana ; des Traps qui agissent pendant le tour ennemi. |
| Ressource | Frenzy (0 à 5), dans la pastille violette. |
| Style de survie | Contrôle (Stunned, Demoralized, Interrupt, Traps), un peu d'Absorb. Aucun soin. |
| Difficulté | Facile. |
| PV proposés | 65 (comme le Priest : pas de soin, mais le contrôle remplace le soin ; à mesurer). |
| Deck de départ | 4 Arcane Shot, 4 Disengage, 1 Serpent Sting, 1 Freezing Trap. |
| Interrupt | Counter Shot (et Wailing Arrow, rare). |
| Last Breath | Feign Death. |
| Bibelot de départ | Pet Whistle. |

## État de l'implémentation (12/11/2026)

Codé : `Data/Hunter.lua`, `Core/Classes/hunter.lua`, `UI/Art/hunter.lua`, tests (`Sim/tests.lua`, bloc
« Hunter » ; harnais, section UH). Écarts par rapport à cette fiche :

- **Familier : 1 + Frenzy** (fiche : 3 + Frenzy ; `ns.Hunter.PET_BASE`). À 3, la simulation de fumée donnait
  99 % de victoires à la clé 0 et le deck de départ seul en gagnait 95 % (Warrior : 0 %) ; à 1, 87 %.
- **PV 56** (fiche et décisions : 65, « à régler par simulation » ; 55 à la simulation de fumée, 41 puis 50 à
  la passe 3, 56 le 18/11/2026 au bot human : 47,7 → 59,3 % ; `docs/equilibrage.md`, « Hunter : réglage au bot
  human (18/11/2026) »).
- **Bestial Wrath coûte 2** (amélioré : 1), le levier prévu au risque 3.
- **Baisse du Frenzy** posée en fin de round (crochet `onRoundEnd`), donc au début de chaque tour sauf le
  premier mais avant la résolution des Cast (même effet que « avec le DoT et la Regen »).
- **Careful Aim d'une carte** : verdict pris au début de sa résolution (toutes les lignes de la carte voient
  la même cible : la pioche de Steady Shot ne dépend pas des 10 dégâts de la ligne d'avant) ; Trueshot Aura
  reste coup par coup.
- **Forme du socle** : « Pet attacks. » (jamais « Your pet »), mots de plaque dans le texte (« Trap. »,
  « Power. »…), Spend = champ `spend`, ressource = `c.player.res`, cible = `c.player.lastTarget`, bibelot
  de départ en rareté `common` + `noPool` (pas de rareté « Départ »), Entrapment : « Traps: also apply
  Demoralized 1. » (sans sablier hors d'une ligne d'état), Feign Death : virgule au lieu du point-virgule.
- **Niveaux** : champ `level` (1 à 7, § 5) sur chaque carte et bibelot, pas encore appliqué ; `rep` (20/5/5)
  et `tier` dérivés de l'ordre des niveaux.
- **Interface** : familier en modèle 3D (Young Wolf, repli en médaillon), marqueur rond sur sa cible, Traps en
  cases sous le héros ; pas encore de crans autour de la pastille, de teinte rouge, de prévision de Trap sur
  l'intention ni de griffe en pointillé au survol.

## Paliers d'amélioration +2 et +3 (15/11/2026)

Décision du joueur (`docs/zones/decisions.md`, « Améliorer une carte plusieurs fois ») ; forme et règles :
`docs/ameliorations.md`. Les 50 cartes du Hunter (34 de classe, 7 épiques, 9 variantes de Lone Wolf) ont leurs
paliers 2 et 3, écrits carte par carte ; palier 0 et palier 1 inchangés. Principes suivis :

- **Nature du gain variée** : d'ordinaire un nombre au +2, puis un effet de l'identité de la carte au +3 (Frenzy,
  Retain, Innate, Careful Aim, un état de plus), ou l'inverse. **Coût réduit une seule fois** : Kill Command (+2 :
  0), Trueshot Aura (+2 : 0), Kill Shot (+2 : 0) ; aucune carte ne descend sous 0, aucune carte à 0 ne gagne de
  pioche (Readiness piochait déjà : Draw 2 au +3, elle reste Exhaust).
- **Cartes qui étourdissent** (Freezing Trap, Intimidation, Wyvern Sting, Scatter Shot) : Stun Resistant (élites)
  et Indomitable (élites de Blackrock Mountain, boss) bornent Stunned ; leurs paliers 2 et 3 n'y touchent pas et
  donnent ce qui vaut contre un ennemi qui résiste : Sundered et Demoralized (Freezing Trap), deux attaques du
  familier et Demoralized (Intimidation), DoT 7 et Demoralized (Wyvern Sting), Deal 7 et Frenzy (Scatter Shot).
- **Familier** : une carte qui ne nomme pas le familier ne le nomme pas plus à +3 (sinon il lui faudrait une
  variante de Lone Wolf) ; Hunter's Mark et Raptor Strike gagnent du Frenzy à la place.
- **Variantes de Lone Wolf** : même nature de gain que la carte d'origine, le familier devenant du Frenzy (Kill
  Command coûte 0 au +2, Kill Shot aussi ; Dire Beast gagne Retain au +3, Double Tap aussi).
- **Épiques** : nombres en tables `{ base, +1, +2, +3 }` (`ns.HunterEpic`) lus par `Card.level(src) + 1` dans les
  crochets et dans la ligne d'épique de l'interface (`UI/Art/hunter.lua`) ; texte en deux lignes à **chaque**
  palier (contrôle du harnais sur tous les paliers, 15/11/2026). Mots de règle des paliers 2 et 3, la règle en
  à-côté : « Hunt N » (Call of the Wild : N Frenzy, puis le familier attaque), « Trample +N » (Beast Cleave : les
  autres ennemis en plein, N Frenzy de plus par attaque), « Prey N » (Black Arrow : le familier attaque l'ennemi
  qui tique, puis N Frenzy) ; « Launch N » (l'à-côté amélioré dit « N times »). Lone Wolf : Ferocity 4 puis 5 (le
  Frenzy au début du tour prévu au +3 ne tenait pas en deux lignes) ; depuis le 19/11/2026, Ferocity 3 de base puis
  4, 5, 6, et Beast Cleave ne frappe que la cible tant qu'un ennemi dort (`docs/equilibrage.md`, « Épiques : mesure une
  par une »).
- **Bots** : notes d'amélioration par défaut (× 0,8 puis × 0,6) ; valeur en combat des Powers dont le palier change
  la valeur (`Sim/bots.lua` : Spirit Bond, Trueshot Aura, Entrapment, Lock and Load, Resourcefulness, Feign Death).

Tests : `Sim/tests.lua`, section « Hunter : paliers 2 et 3 » (les 34 cartes aux paliers 2 et 3 jouables et
conformes à leur texte ; coût réduit ; Spend 1 ; Retain ; Innate ; cartes qui étourdissent contre un Indomitable ;
Powers) ; `Sim/tests_epic_hunter.lua`, section « Paliers 2 et 3 » (textes, chaque épique à +2 et +3, variantes au
palier de leur carte d'origine).

### Les trois paliers de chaque carte

Coût entre parenthèses ; « / » sépare les lignes de la carte.

**Départ**

| Carte | +1 | +2 | +3 |
|---|---|---|---|
| Arcane Shot | (1) Deal 6. / Pet attacks. | (1) Deal 8. / Pet attacks. | (1) Deal 8. / +1 Frenzy. / Pet attacks. |
| Disengage | (1) Gain 6 Absorb. | (1) Gain 8 Absorb. | (1) Gain 8 Absorb. / Retain. |
| Freezing Trap | (1) Trap. / Apply Stunned 1 ⌛ / Apply Demoralized 2 ⌛ | (1) Trap. / Apply Stunned 1 ⌛ / Apply Demoralized 2 ⌛ / Apply Sundered 2 ⌛ | (1) Trap. / Apply Stunned 1 ⌛ / Apply Demoralized 3 ⌛ / Apply Sundered 2 ⌛ |
| Serpent Sting | (1) Draw 1. / Apply DoT 5 | (1) Draw 1. / Apply DoT 7 | (1) Draw 1. / Apply DoT 7 / Apply Demoralized 1 ⌛ |

**Beast Mastery**

| Carte | +1 | +2 | +3 |
|---|---|---|---|
| Barbed Shot | (1) +2 Frenzy. / Apply DoT 5 | (1) +2 Frenzy. / Apply DoT 6 | (1) +3 Frenzy. / Apply DoT 6 |
| Bestial Wrath | (1) Surge: pet attacks once per Frenzy. | (1) Surge: pet attacks once per Frenzy. / +2 Frenzy. | (1) Surge: pet attacks once per Frenzy. / +2 Frenzy. / Retain. |
| Cobra Shot | (1) Deal 10. / +1 Frenzy. | (1) Deal 13. / +1 Frenzy. | (1) Deal 13. / +2 Frenzy. |
| Dire Beast | (0) Pet attacks three times. / Exhaust. | (0) +1 Frenzy. / Pet attacks three times. / Exhaust. | (0) +1 Frenzy. / Pet attacks three times. / Exhaust. / Retain. |
| Growl | (1) Gain 8 Absorb. / Spend 2: gain 8 more. | (1) Gain 10 Absorb. / Spend 2: gain 8 more. | (1) Gain 10 Absorb. / Spend 1: gain 8 more. |
| Intimidation | (1) Pet attacks. / Apply Stunned 1 ⌛ / Cooldown 3. | (1) Pet attacks twice. / Apply Stunned 1 ⌛ / Cooldown 3. | (1) Pet attacks twice. / Apply Stunned 1 ⌛ / Apply Demoralized 2 ⌛ / Cooldown 3. |
| Kill Command | (1) Pet attacks twice. / Cooldown 2. | (0) Pet attacks twice. / Cooldown 2. | (0) +1 Frenzy. / Pet attacks twice. / Cooldown 2. |
| Multi-Shot | (1) Deal 7 to all. / Pet attacks. | (1) Deal 8 to all. / Pet attacks. | (1) Deal 8 to all. / +1 Frenzy. / Pet attacks. |
| Spirit Bond | (1) Power. / Pet attacks: gain 2 Absorb. | (1) Power. / Pet attacks: gain 3 Absorb. | (1) Power. / Pet attacks: gain 3 Absorb. / Innate. |
| The Beast Within | (0) Power. / Attacks: pet attacks. | (0) Power. / Attacks: pet attacks. / Innate. | (0) Power. / +2 Frenzy. / Attacks: pet attacks. / Innate. |

**Marksmanship**

| Carte | +1 | +2 | +3 |
|---|---|---|---|
| Aimed Shot | (2) Cast. / Deal 30. / Careful Aim: deal 12 more. | (2) Cast. / Deal 34. / Careful Aim: deal 14 more. | (2) Cast. / Deal 34. / Careful Aim: deal 14 more. / Careful Aim: draw 1. |
| Concussive Shot | (1) Deal 7. / Apply Demoralized 2 ⌛ | (1) Deal 9. / Apply Demoralized 2 ⌛ | (1) Deal 9. / Apply Demoralized 3 ⌛ |
| Counter Shot | (0) Interrupt the target's cast. / Pet attacks. / Cooldown 2. | (0) Interrupt the target's cast. / Pet attacks twice. / Cooldown 2. | (0) Interrupt the target's cast. / Pet attacks twice. / Apply Demoralized 2 ⌛ / Cooldown 2. |
| Hunter's Mark | (0) Apply Sundered 5 ⌛ / Exhaust. | (0) Apply Sundered 6 ⌛ / Exhaust. | (0) +2 Frenzy. / Apply Sundered 6 ⌛ / Exhaust. |
| Rapid Fire | (1) Deal 4 four times. / Cooldown 2. | (1) Deal 4 four times. / +1 Frenzy. / Cooldown 2. | (1) Deal 5 four times. / +1 Frenzy. / Cooldown 2. |
| Readiness | (0) Return Cooldown cards to hand. / Draw 1. / Exhaust. | (0) Return Cooldown cards to hand. / Draw 1. / Exhaust. / Retain. | (0) Return Cooldown cards to hand. / Draw 2. / Exhaust. / Retain. |
| Steady Shot | (1) Cast. / Deal 17. / Careful Aim: draw 1. | (1) Cast. / Deal 20. / Careful Aim: draw 1. | (1) Cast. / Deal 20. / Draw 1. |
| Trueshot Aura | (1) Power. / Careful Aim: Attacks deal 7 more. | (0) Power. / Careful Aim: Attacks deal 7 more. | (0) Power. / Careful Aim: Attacks deal 8 more. |
| Volley | (2) Cast. / Deal 20 to all. | (2) Cast. / Deal 23 to all. | (2) Cast. / Deal 23 to all. / Careful Aim: deal 5 more. |
| Wailing Arrow | (1) Deal 12 to all. / Interrupt all casts. / Exhaust. | (1) Deal 12 to all. / Interrupt all casts. / Apply Demoralized 1 ⌛ to all / Exhaust. | (1) Deal 15 to all. / Interrupt all casts. / Apply Demoralized 1 ⌛ to all / Exhaust. |

**Survival**

| Carte | +1 | +2 | +3 |
|---|---|---|---|
| Counterattack | (1) Trap. / Deal 17. | (1) Trap. / Deal 20. | (1) Trap. / Deal 20. / Apply Demoralized 2 ⌛ |
| Entrapment | (0) Power. / Traps: also apply Demoralized 2. | (0) Power. / Traps: also apply Demoralized 2 and Sundered 1. | (0) Power. / Traps: also apply Demoralized 2 and Sundered 1. / Innate. |
| Explosive Trap | (1) Trap. / Deal 8 to all. / Apply DoT 4 to all | (1) Trap. / Deal 10 to all. / Apply DoT 4 to all | (1) Trap. / Deal 10 to all. / Apply DoT 4 to all / Apply Sundered 1 ⌛ to all |
| Feign Death | (0) Power. / Last Breath: stay at 1 HP, enemies skip a turn. | (0) Power. / Last Breath: stay at 5 HP, enemies skip a turn. | (0) Power. / Last Breath: stay at 5 HP, enemies skip a turn. / Innate. |
| Frost Trap | (1) Trap. / Apply Demoralized 2 ⌛ to all | (1) Trap. / Apply Demoralized 2 ⌛ to all / Apply Sundered 2 ⌛ to all | (1) Trap. / Apply Demoralized 3 ⌛ to all / Apply Sundered 2 ⌛ to all |
| Immolation Trap | (1) Trap. / Apply DoT 9 | (1) Trap. / Apply DoT 11 | (1) Trap. / Deal 6. / Apply DoT 11 |
| Lock and Load | (0) Power. / When a Trap triggers: draw 2. | (0) Power. / When a Trap triggers: draw 2, +1 Frenzy. | (0) Power. / When a Trap triggers: draw 2, +1 Frenzy. / Innate. |
| Raptor Strike | (1) Deal 8. / Gain 4 Absorb. | (1) Deal 10. / Gain 5 Absorb. | (1) Deal 10. / Gain 5 Absorb. / +1 Frenzy. |
| Resourcefulness | (0) Power. / Triggered Traps return to hand. | (0) Power. / Triggered Traps return to hand. / Innate. | (0) Power. / Triggered Traps return to hand. / When a Trap triggers: gain 3 Absorb. / Innate. |
| Wyvern Sting | (1) Apply Stunned 1 ⌛ / Apply DoT 4 / Cooldown 3. | (1) Apply Stunned 1 ⌛ / Apply DoT 7 / Cooldown 3. | (1) Apply Stunned 1 ⌛ / Apply DoT 7 / Apply Demoralized 2 ⌛ / Cooldown 3. |

**Épiques**

| Carte | +1 | +2 | +3 |
|---|---|---|---|
| Beast Cleave | Pet attacks: Stampede +1. | Pet attacks: Trample +1. | Pet attacks: Trample +2. |
| Black Arrow | Enemy DoT ticks: pet attacks it. | Enemy DoT ticks: Prey 1. | Enemy DoT ticks: Prey 2. |
| Call of the Wild | Start of turn: pet attacks. | Start of turn: Hunt 1. | Start of turn: Hunt 2. |
| Lone Wolf | Attack hits: Ferocity 4. | Attack hits: Ferocity 5. | Attack hits: Ferocity 6. |
| Master Marksman | Careful Aim: Deadeye 24. | Careful Aim: Deadeye 27. | Careful Aim: Deadeye 30. |
| Roar of Sacrifice | When hit: Intervene 4. | When hit: Intervene 5. | When hit: Intervene 6. |
| Trap Launcher | Traps: Launch 2. | Traps: +1 Frenzy, Launch 2. | Traps: +1 Frenzy, Launch 3. |

**Variantes de Lone Wolf**

| Carte | +1 | +2 | +3 |
|---|---|---|---|
| Aspect of the Turtle | (1) Power. / Each Attack hit: gain 1 Absorb. | (1) Power. / Each Attack hit: gain 1 Absorb. / Innate. | (1) Power. / Gain 5 Absorb. / Each Attack hit: gain 1 Absorb. / Innate. |
| Chimaera Shot | (1) Deal 8. / Deal 4 to another enemy. / +1 Frenzy. | (1) Deal 8. / Deal 6 to another enemy. / +1 Frenzy. | (1) Deal 8. / Deal 6 to another enemy. / +2 Frenzy. |
| Double Tap | (0) Draw 1. / +3 Frenzy. / Exhaust. | (0) Draw 1. / +4 Frenzy. / Exhaust. | (0) Draw 1. / +4 Frenzy. / Exhaust. / Retain. |
| Explosive Shot | (1) Surge: deal 6 per Frenzy. | (1) Surge: deal 6 per Frenzy. / +2 Frenzy. | (1) Surge: deal 6 per Frenzy. / +2 Frenzy. / Retain. |
| Kill Shot | (1) Deal 8. / Execute: deal 16. / +1 Frenzy. / Cooldown 2. | (0) Deal 8. / Execute: deal 16. / +1 Frenzy. / Cooldown 2. | (0) Deal 8. / Execute: deal 16. / +2 Frenzy. / Cooldown 2. |
| Salvo | (1) Deal 7 to all. / +1 Frenzy. | (1) Deal 8 to all. / +1 Frenzy. | (1) Deal 8 to all. / +2 Frenzy. |
| Scatter Shot | (1) Deal 3. / +1 Frenzy. / Apply Stunned 1 ⌛ / Cooldown 3. | (1) Deal 7. / +1 Frenzy. / Apply Stunned 1 ⌛ / Cooldown 3. | (1) Deal 7. / +2 Frenzy. / Apply Stunned 1 ⌛ / Cooldown 3. |
| Silencing Shot | (0) Interrupt the target's cast. / +1 Frenzy. / Cooldown 2. | (0) Interrupt the target's cast. / +2 Frenzy. / Cooldown 2. | (0) Interrupt the target's cast. / +2 Frenzy. / Apply Demoralized 2 ⌛ / Cooldown 2. |
| Trick Shots | (0) Power. / Attacks: +1 Frenzy. | (0) Power. / Attacks: +1 Frenzy. / Innate. | (0) Power. / +2 Frenzy. / Attacks: +1 Frenzy. / Innate. |

## 1. Règles propres

### Le familier

1. Le familier n'est pas une unité : il n'a ni PV, ni Absorb, ni états, ne peut être ni ciblé ni tué. Il
   s'affiche à côté du héros.
2. **Attaque du familier** : un coup unique de **3 + Frenzy** sur la *cible du familier*, puis **+1 Frenzy**
   (voir Frenzy). Les dégâts sont calculés au moment du coup, avec le Frenzy d'avant le gain.
3. **Attaque automatique** : à la fin de chaque tour du joueur, avant tout autre effet de fin de tour
   (Powers, bibelots) et avant la défausse de la main, le familier attaque une fois. Il attaque même si le
   joueur n'a joué aucune carte. S'il tue le dernier ennemi, le combat est gagné avant le tour ennemi.
4. **Attaque commandée** : « Your pet attacks. » sur une carte = une attaque du familier, tout de suite,
   pendant la résolution de la carte, dans l'ordre des lignes. « twice » = deux attaques à la suite, chacune
   recalculée (la seconde profite du Frenzy gagné par la première).
5. **Cible du familier** : le dernier ennemi visé par une carte du joueur. Toute carte jouée avec une cible
   (`target = "enemy"`, Attack ou Skill, Cast compris) déplace la cible du familier sur cet ennemi **au
   moment où la carte est jouée**, avant ses effets. Les cartes sans cible (« to all », Traps, Powers) et les
   potions ne la changent pas. Une carte Cast dont la cible meurt avant la résolution ne change rien de plus.
6. **Pas de cible** (début de combat, ou cible morte) : le familier attaque l'ennemi vivant le plus à gauche,
   comme une carte Cast dont la cible est morte. La cible n'est pas mémorisée : dès qu'une carte vise un
   ennemi, elle devient la cible. Une invocation ennemie ne change pas la cible.
7. **Modificateurs** : le coup du familier compte comme un coup du Hunter **sans carte**.
   - Strength du Hunter : s'ajoute (« par coup »). Demoralized sur le Hunter : s'applique.
   - Sundered sur la cible : s'applique. L'Absorb de la cible encaisse le coup.
   - Les effets qui visent les cartes Attack (« your Attacks », Coarse Sharpening Stone, Trueshot Aura,
     Light Quiver, Rhok'delar) **ne s'appliquent pas** au familier : il n'est pas une carte. Une carte Attack
     qui fait attaquer le familier (Kill Command) ne lui transmet pas ces bonus non plus.
   - Atonement et les autres effets « carte qui inflige des dégâts » : le coup n'est pas une carte, rien.
8. Le familier ne peut ni interrompre, ni étourdir, ni poser d'état ; seules les lignes de la carte le font.

### Frenzy

1. **Gain** : +1 à chaque attaque du familier (automatique ou commandée), après le coup. Quelques cartes
   donnent du Frenzy directement (« +1 Frenzy. »).
2. **Plafond** : 5. Le surplus est perdu.
3. **Effet** : chaque point ajoute 1 aux dégâts de chaque attaque du familier (3 à 8).
4. **Baisse** : −1 au début de chaque tour du joueur, **sauf le premier** (avec le DoT et la Regen).
   Conséquence voulue : le familier laissé seul gagne 1 en fin de tour et le perd au tour suivant ; il reste
   à 3 dégâts. Seuls les ordres (cartes qui le font attaquer ou donnent du Frenzy) font monter le Frenzy.
   C'est la réponse au risque du GDD (« un familier qui joue tout seul rend la classe passive »).
5. **Surge** (Bestial Wrath) : compte le Frenzy, joue l'effet, puis le Frenzy tombe à 0. Les attaques d'un
   Surge infligent 3 + le Frenzy compté et **ne donnent pas de Frenzy**. Injouable à 0 Frenzy (comme les
   Surge du Priest).
6. **Spend N** (Growl) : si Frenzy ≥ N, retire N et donne le bonus ; sinon la carte se joue sans bonus et
   sans rien retirer.
7. Le Frenzy dure le combat (reste d'un tour à l'autre, moins la baisse) et repart de 0 au combat suivant.

### Traps

1. Une carte **Trap** est toujours une Skill. Jouée (mana payé), elle **est posée** : elle quitte la main
   et va dans la zone des Traps, sous le héros, face visible. Elle ne résout rien au moment où elle est jouée.
2. **Trois Traps posées au plus.** Une quatrième carte Trap est injouable (raison : « 3 Traps already set »).
3. **Déclenchement** : pendant le tour ennemi, au début de chaque action `attack` d'un ennemi (un « coup »
   annoncé par une intention d'attaque, Cast compris s'il n'est pas interrompu), **la plus ancienne Trap
   posée** se déclenche, **avant le premier coup** de cette attaque. Une Trap par attaque : avec deux Traps
   et deux ennemis qui attaquent, chacun en reçoit une, dans l'ordre où ils agissent (de gauche à droite) ;
   avec deux Traps et un seul attaquant, la seconde attend le tour ennemi suivant.
4. **Cible** : l'attaquant. Les lignes « to all » visent tous les ennemis vivants. Les états posés sur
   l'attaquant l'affectent **dès l'attaque en cours** (Demoralized réduit tous ses coups de cette attaque).
5. **Attaque à plusieurs coups** : la Trap se déclenche une seule fois, avant le premier coup.
6. **L'attaquant meurt de la Trap** : son attaque est annulée (le moteur s'arrête déjà sur `e.dead`).
7. **Stunned posé par une Trap** (règle commune du 12/11/2026, `decisions.md`) : posé pendant le tour de
   l'attaquant, il **arrête ce tour tout de suite** : l'attaque qui a déclenché la Trap n'a pas lieu (aucun
   de ses coups), ni ses actions suivantes ; la charge est consommée par ce tour-là (il ne perd pas en plus
   le tour suivant ; « Stunned 2 » = ce tour et le suivant). Boss : immunisé, comme partout (Freezing Trap
   garde son Demoralized, voir plus bas). Avant cette règle, l'attaque partait et l'ennemi perdait son
   prochain tour.
8. **Durées** : un état à durée posé pendant le tour ennemi saute la baisse de fin de round (règle de
   `Core/Statuses.lua`). « Demoralized 1 ⌛ » posé par une Trap couvre donc l'attaque en cours **et** le tour
   ennemi suivant. C'est voulu : le chiffre sur la carte reste petit. Freezing Trap : l'attaquant est stoppé
   net, puis son attaque du tour suivant est réduite de 25 % ; sur un boss (immunisé à Stunned),
   Demoralized réduit l'attaque en cours et la suivante (vérifié par les tests, aucune valeur changée).
9. **Pas d'attaque ennemie ce tour** (ennemis étourdis, qui se renforcent, incantent, invoquent) : les
   Traps restent posées et attendent. Une action `interrupt`, `debuff`, `buff` ou `summon` ne déclenche rien.
   Le DoT d'un ennemi ne déclenche rien.
10. **Après le déclenchement** : la carte va dans la défausse (Exhaust : épuisée ; Resourcefulness : en
    main). Les dégâts d'une Trap sont des dégâts de carte (Strength, Sundered, Absorb comme une carte).
11. **Fin de combat** : les Traps non déclenchées sont perdues avec le combat (le deck est reconstitué).
12. **Feign Death** : un tour ennemi sauté ne déclenche aucune Trap.

### Interactions avec les règles communes

| Règle | Comportement Hunter |
|---|---|
| Absorb | L'Absorb ennemi encaisse les coups du familier et les dégâts des Traps ; le DoT l'ignore. Celui du Hunter disparaît au début de son tour, comme toujours (Spirit Bond donne de l'Absorb en fin de tour, juste avant le tour ennemi). |
| Cast | Aimed Shot, Steady Shot, Volley. La cible du familier change dès que la carte est jouée. Careful Aim se vérifie **à la résolution** (début du tour suivant), sur la cible à ce moment-là (l'ennemi le plus à gauche si la cible est morte). Une seule incantation à la fois. |
| Cooldown | Kill Command, Intimidation, Rapid Fire, Counter Shot, Wyvern Sting. Readiness les rend toutes en main (celles qui ne tiennent pas dans la main de 10 restent en recharge). |
| Stunned | Freezing Trap, Intimidation, Wyvern Sting. Sur un boss : rien (journal « immune »), les autres lignes de la carte s'appliquent. Aucune carte du Hunter ne compte uniquement sur Stunned. |
| Interrupt | Counter Shot et Wailing Arrow, pendant le tour du joueur, sur les intentions Cast. |
| Attaques multiples | Rapid Fire : 4 coups (Strength par coup). Le familier : toujours un coup par attaque. |
| Last Breath | Feign Death (Power) : une fois par combat. |

### Mots-clés propres (deux) et infobulles

| Mot-clé | Règle | Infobulle (≤ 60 caractères) |
|---|---|---|
| **Careful Aim** | Condition nommée, inverse d'Execute : la cible a **plus** de la moitié de ses PV. | `Condition: the target has more than half its HP.` |
| **Pet** (« Your pet attacks. ») | Une attaque du familier, définie plus haut. | `Your pet hits its target for 3 + Frenzy, then +1 Frenzy.` |

Infobulles des formes communes et de la ressource (ne comptent pas comme mots-clés propres) :

| Terme | Infobulle (≤ 60 caractères) |
|---|---|
| Trap | `Set now. Triggers on the next enemy attack, on the attacker.` |
| Frenzy | `Pet hits +1 per point. +1 per pet attack, −1 each turn.` |
| Cible du familier (marqueur) | `Your pet attacks the last enemy you targeted.` |

## 2. Les 34 cartes

Texte dans le langage des cartes : une clause par ligne, séparées ici par « / » ; états posés en dernière
ligne, sans point ; les mots de plaque (Cast, Cooldown N, Exhaust, Retain, Trap) sont dans la colonne
« Plaque » et pas dans le texte. « Trap » s'affiche sur la plaque comme les autres mots ; les états d'une
Trap visent l'attaquant sans le répéter (« to all » sinon). Coût et plaque améliorés : entre parenthèses
quand ils changent. Icônes vérifiées dans `~/Téléchargements/ICONS/` (recherche sans casse).

| id | Nom | Voie | Rareté | Coût | Type | Plaque | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|---|---|
| `arcane_shot` | Arcane Shot | Départ | Départ | 1 | Attack | — | Deal 3. / Your pet attacks. | Deal 6. / Your pet attacks. | `ability_impalingbolt` |
| `disengage` | Disengage | Départ | Départ | 1 | Skill | — | Gain 5 Absorb. | Gain 8 Absorb. | `ability_rogue_feint` |
| `serpent_sting` | Serpent Sting | Départ | Départ | 1 | Skill | — | Draw 1. / Apply DoT 5 | Draw 1. / Apply DoT 7 | `ability_hunter_quickshot` |
| `freezing_trap` | Freezing Trap | Départ | Départ | 1 | Skill | Trap | Apply Stunned 1 ⌛ / Apply Demoralized 1 ⌛ | Apply Stunned 1 ⌛ / Apply Demoralized 2 ⌛ | `spell_frost_chainsofice` |
| `kill_command` | Kill Command | Beast Mastery | Commune | 1 | Attack | Cooldown 2 | Your pet attacks twice. | Your pet attacks twice. (Cooldown 1) | `ability_hunter_killcommand` |
| `cobra_shot` | Cobra Shot | Beast Mastery | Commune | 1 | Attack | — | Deal 5. / +1 Frenzy. | Deal 8. / +1 Frenzy. | `ability_hunter_cobrashot` |
| `barbed_shot` | Barbed Shot | Beast Mastery | Commune | 1 | Skill | — | +2 Frenzy. / Apply DoT 3 | +2 Frenzy. / Apply DoT 5 | `ability_hunter_barbedshot` |
| `dire_beast` | Dire Beast | Beast Mastery | Commune | 0 | Skill | Exhaust | Your pet attacks. | Your pet attacks twice. | `ability_hunter_sickem` |
| `growl` | Growl | Beast Mastery | Commune | 1 | Skill | — | Gain 6 Absorb. / Spend 2: gain 6 more. | Gain 8 Absorb. / Spend 2: gain 8 more. | `ability_physical_taunt` |
| `intimidation` | Intimidation | Beast Mastery | Inhabituelle | 1 | Skill | Cooldown 3 | Your pet attacks. / Apply Stunned 1 ⌛ | Your pet attacks. / Apply Stunned 1 ⌛ (Cooldown 2) | `ability_devour` |
| `multi_shot` | Multi-Shot | Beast Mastery | Inhabituelle | 1 | Attack | — | Deal 4 to all. / Your pet attacks. | Deal 6 to all. / Your pet attacks. | `ability_upgrademoonglaive` |
| `spirit_bond` | Spirit Bond | Beast Mastery | Inhabituelle | 2 | Power | Power | When your pet attacks: gain 2 Absorb. | idem (coût 1) | `ability_druid_demoralizingroar` |
| `bestial_wrath` | Bestial Wrath | Beast Mastery | Rare | 1 | Skill | — | Surge: your pet attacks once per Frenzy. | idem (coût 0) | `ability_druid_ferociousbite` |
| `the_beast_within` | The Beast Within | Beast Mastery | Rare | 2 | Power | Power | After each Attack: your pet attacks. | idem (coût 1) | `ability_hunter_beastwithin` |
| `aimed_shot` | Aimed Shot | Marksmanship | Commune | 2 | Attack | Cast | Deal 20. / Careful Aim: deal 10 more. | Deal 26. / Careful Aim: deal 12 more. | `ability_hunter_aimedshot` |
| `steady_shot` | Steady Shot | Marksmanship | Commune | 1 | Attack | Cast | Deal 10. / Careful Aim: draw 1. | Deal 14. / Careful Aim: draw 1. | `ability_hunter_steadyshot` |
| `hunters_mark` | Hunter's Mark | Marksmanship | Commune | 0 | Skill | Exhaust | Apply Sundered 3 ⌛ | Apply Sundered 5 ⌛ | `ability_hunter_snipershot` |
| `concussive_shot` | Concussive Shot | Marksmanship | Commune | 1 | Attack | — | Deal 4. / Apply Demoralized 2 ⌛ | Deal 7. / Apply Demoralized 2 ⌛ | `spell_frost_stun` |
| `rapid_fire` | Rapid Fire | Marksmanship | Inhabituelle | 1 | Attack | Cooldown 2 | Deal 3 four times. | Deal 4 four times. | `ability_hunter_runningshot` |
| `counter_shot` | Counter Shot | Marksmanship | Inhabituelle | 0 | Skill | Cooldown 2 | Interrupt the target's cast. / Your pet attacks. | idem (Cooldown 1) | `inv_ammo_arrow_03` |
| `volley` | Volley | Marksmanship | Inhabituelle | 2 | Attack | Cast | Deal 13 to all. | Deal 17 to all. | `ability_marksmanship` |
| `readiness` | Readiness | Marksmanship | Inhabituelle | 0 | Skill | Exhaust | Return your Cooldown cards to hand. | Return your Cooldown cards to hand. / Draw 1. | `ability_hunter_readiness` |
| `trueshot_aura` | Trueshot Aura | Marksmanship | Rare | 1 | Power | Power | Careful Aim: Attacks deal 4 more. | Careful Aim: Attacks deal 6 more. | `ability_trueshot` |
| `wailing_arrow` | Wailing Arrow | Marksmanship | Rare | 1 | Attack | Exhaust | Deal 8 to all. / Interrupt all casts. | Deal 12 to all. / Interrupt all casts. | `inv_bow_1h_sylvanasshadowlands_d_01` |
| `immolation_trap` | Immolation Trap | Survival | Commune | 1 | Skill | Trap | Apply DoT 7 | Apply DoT 9 | `spell_fire_immolation` |
| `counterattack` | Counterattack | Survival | Commune | 1 | Skill | Trap | Deal 10. | Deal 14. | `ability_warrior_challange` |
| `frost_trap` | Frost Trap | Survival | Commune | 1 | Skill | Trap | Apply Demoralized 1 ⌛ to all | Apply Demoralized 2 ⌛ to all | `spell_frost_freezingbreath` |
| `raptor_strike` | Raptor Strike | Survival | Commune | 1 | Attack | — | Deal 5. / Gain 3 Absorb. | Deal 8. / Gain 4 Absorb. | `ability_meleedamage` |
| `explosive_trap` | Explosive Trap | Survival | Inhabituelle | 1 | Skill | Trap | Deal 6 to all. / Apply DoT 3 to all | Deal 8 to all. / Apply DoT 4 to all | `spell_fire_selfdestruct` |
| `wyvern_sting` | Wyvern Sting | Survival | Inhabituelle | 1 | Skill | Cooldown 3 | Apply Stunned 1 ⌛ / Apply DoT 6 | idem (Cooldown 2) | `inv_spear_02` |
| `entrapment` | Entrapment | Survival | Inhabituelle | 1 | Power | Power | Your Traps also apply Demoralized 1 ⌛ | idem (coût 0) | `spell_nature_stranglevines` |
| `lock_and_load` | Lock and Load | Survival | Inhabituelle | 1 | Power | Power | When a Trap triggers: draw 1. | idem (coût 0) | `ability_hunter_lockandload` |
| `feign_death` | Feign Death | Survival | Rare | 1 | Power | Power | Last Breath: stay at 1 HP; enemies skip a turn. | idem (coût 0) | `ability_rogue_feigndeath` |
| `resourcefulness` | Resourcefulness | Survival | Rare | 2 | Power | Power | Triggered Traps return to your hand. | idem (coût 1) | `ability_hunter_resourcefulness` |

Comptes : 4 de départ ; Beast Mastery 10 (5 communes, 3 inhabituelles, 2 rares) ; Marksmanship 10 (4/4/2) ;
Survival 10 (4/4/2) ; soit 13 communes, 11 inhabituelles, 6 rares. Ciblage : toutes les cartes qui font
attaquer le familier visent un ennemi (sauf Multi-Shot, qui frappe tout le monde et laisse le familier sur
sa cible) ; ce choix de cible est la commande.

Précisions de règle par carte :

- **Arcane Shot** : le GDD donnait « Deal 6 » + le familier ; ramené à 3 parce que quatre exemplaires font
  monter le Frenzy vite (6 de base au total à Frenzy 0, comme Smite, puis davantage).
- **Freezing Trap** : Stunned + Demoralized ; sur un boss, seul Demoralized porte (attaque en cours et
  attaque suivante). C'est la réponse au risque « Stunned inutile contre le boss ».
- **Kill Command, Intimidation, Counter Shot** : la cible jouée devient la cible du familier, puis il attaque.
- **Growl** : Spend 2 retire 2 Frenzy (le familier frappera moins fort) contre 6 Absorb de plus.
- **Spirit Bond** : chaque attaque du familier, automatique comprise (la dernière tombe juste avant le tour
  ennemi). Les attaques d'un Surge comptent.
- **Bestial Wrath** : à 5 Frenzy, 5 attaques de 8 = 40, puis Frenzy 0 (voir Frenzy, point 5).
- **The Beast Within** : après la résolution de chaque carte Attack (une carte Cast : à sa résolution).
  Une attaque de plus, pas un bonus de dégâts.
- **Steady Shot** : la pioche de Careful Aim arrive à la résolution, avant la pioche du tour.
- **Readiness** : rend en main toutes les cartes en recharge, dans l'ordre où elles y sont entrées.
- **Trueshot Aura** : +4 par coup des cartes Attack sur une cible au-dessus de la moitié de ses PV
  (vérifié coup par coup : Rapid Fire peut perdre le bonus en cours de route).
- **Wailing Arrow** : interrompt chaque ennemi dont l'intention est un Cast (pas seulement la cible).
- **Entrapment** : le Demoralized va sur l'attaquant seulement, même pour une Trap « to all ».
- **Lock and Load** : la carte est piochée tout de suite, pendant le tour ennemi ; elle sera dans la main au
  tour suivant (main de 10 au plus, sinon rien).
- **Feign Death** : si le Hunter tombe à 0 pendant le tour ennemi, il reste à 1 PV et le reste de ce tour
  ennemi est annulé (coups restants, ennemis suivants) ; s'il tombe pendant son propre tour (DoT), il
  reste à 1 PV et le prochain tour ennemi est sauté. Vaut contre les boss (ce n'est pas Stunned). Les
  intentions sautées sont perdues.
- **Resourcefulness** : la Trap revient en main au moment où elle se déclenche (main pleine : défausse).

## 3. Les trois voies

### Beast Mastery — « Le Frenzy à 5 »

**Moteur.** Chaque carte commande le familier ou lui donne du Frenzy, contre la baisse de 1 par tour ;
plus le joueur commande, plus chaque coup du familier fait mal. À 5, Bestial Wrath vide la jauge en une
rafale, ou Growl la convertit en Absorb.

**Cartes.** Kill Command, Cobra Shot, Barbed Shot, Dire Beast, Growl, Intimidation, Multi-Shot,
Spirit Bond, Bestial Wrath, The Beast Within.

**Avec Marksmanship.** Hunter's Mark (Sundered) et le familier : chaque coup du familier prend +25 % ;
Counter Shot commande aussi le familier. The Beast Within fait suivre chaque tir (Aimed Shot, Rapid Fire)
d'une attaque du familier ; Readiness relance Kill Command et Intimidation.
**Avec Survival.** Barbed Shot et Serpent Sting posent du DoT pendant que le familier frappe ; les Traps
couvrent le tour ennemi que Beast Mastery laisse ouvert. Spirit Bond + Traps : on tient sans carte de
défense.

**Tour type** (Frenzy 2 au début, 3 mana, un Gnoll et un Mystic) : Barbed Shot sur le Mystic (+2 →
Frenzy 4, DoT 3 ; le familier passe sur le Mystic), Kill Command (7 puis 8 → Frenzy 5), Disengage.
Fin du tour : le familier frappe 8 (Frenzy reste 5). Au tour suivant, Frenzy 4 : Bestial Wrath frappe
4 × 7 = 28.

### Marksmanship — « Tuer avant le premier coup »

**Moteur.** Les tirs frappent fort tant que la cible est intacte (Careful Aim) : on ouvre avec Hunter's Mark
et un gros tir en Cast, puis on achève avec le familier et les tirs rapides. Le contrôle (Concussive Shot,
Counter Shot) protège l'incantation.

**Cartes.** Aimed Shot, Steady Shot, Hunter's Mark, Concussive Shot, Rapid Fire, Counter Shot, Volley,
Readiness, Trueshot Aura, Wailing Arrow.

**Avec Beast Mastery.** Le familier finit les cibles passées sous la moitié, là où Careful Aim ne porte
plus ; Kill Command et Rapid Fire sous Readiness font un tour de rafale.
**Avec Survival.** Frost Trap et Freezing Trap gardent l'incantation d'Aimed Shot à l'abri des coups qui
interrompent ; Explosive Trap entame tout le groupe pendant que Volley se prépare.

**Tour type** (tour 1, un Defias Highwayman de 27 PV et un Conjurer) : Hunter's Mark sur le Highwayman (0 mana,
Sundered 3), Aimed Shot sur le Highwayman (Cast), Concussive Shot sur le Conjurer (Demoralized 2). Le familier
frappe le Conjurer (3). Au début du tour 2, Aimed Shot résout : (20 + 10) × 1,25 = 37, le Highwayman meurt.

### Survival — « Punir chaque attaque ennemie »

**Moteur.** On pose des Traps pendant son tour ; chaque attaque ennemie en déclenche une (dégâts, DoT,
Stunned, Demoralized). Entrapment, Lock and Load et Resourcefulness transforment chaque attaque subie
en contrôle, en pioche ou en Trap rendue.

**Cartes.** Immolation Trap, Counterattack, Frost Trap, Raptor Strike, Explosive Trap, Wyvern Sting,
Entrapment, Lock and Load, Feign Death, Resourcefulness.

**Avec Beast Mastery.** Les Traps tiennent le tour ennemi pendant que les cartes du tour servent à
commander le familier ; le DoT de Survival et Barbed Shot s'additionnent.
**Avec Marksmanship.** Les Traps réduisent ou annulent l'attaque qui interromprait Aimed Shot ; Readiness
relance Wyvern Sting.

**Tour type** (deux Gnolls qui annoncent une attaque) : Freezing Trap, Explosive Trap, Raptor Strike sur
le Gnoll de gauche (5 dégâts, 3 Absorb). Fin du tour : le familier frappe le même Gnoll. Tour ennemi :
le Gnoll de gauche attaque, Freezing Trap se déclenche avant son coup (Stunned : son tour s'arrête, le
coup ne part pas ; Demoralized : son attaque du tour suivant est réduite) ; le Gnoll de droite attaque, Explosive Trap (6 à tous, DoT 3).

## 4. Bibelots de classe

| id | Nom | Rareté | Effet (une ligne affichée) | Icône |
|---|---|---|---|---|
| `pet_whistle` | Pet Whistle | Départ | At the start of the first turn, your pet attacks. | `inv_misc_whistle_color1` |
| `kiblers_bits` | Kibler's Bits | Commun | Start each combat with 2 Frenzy. | `inv_misc_food_49` |
| `light_quiver` | Light Quiver | Commun | Your Cast Attacks deal 3 more. | `inv_misc_quiver_01` |
| `net_o_matic` | Net-o-Matic Projector | Inhabituel | Your first Trap each combat costs 0. | `inv_misc_net_01` |
| `devilsaur_eye` | Devilsaur Eye | Inhabituel | When an enemy dies: +2 Frenzy. | `inv_misc_eye_01` |
| `rhokdelar` | Rhok'delar | Rare | On the first turn, your Attacks deal 5 more. | `inv_weapon_bow_08` |

Pet Whistle amorce dès le premier tour : le familier frappe (3) et le Hunter commence son tour à
Frenzy 1 (pas de baisse au premier tour). Rareté « Départ » : nouvelle valeur à côté de
common/uncommon/rare/boss, jamais tirée.

## 5. Progression

| Niveau | Beast Mastery | Marksmanship | Survival | Bibelots |
|---|---|---|---|---|
| 1 | Kill Command, Cobra Shot, Barbed Shot, Growl, Intimidation, Bestial Wrath | Aimed Shot, Steady Shot, Hunter's Mark, Concussive Shot, Rapid Fire, Counter Shot | Immolation Trap, Counterattack, Frost Trap, Raptor Strike, Explosive Trap, Wyvern Sting | Pet Whistle, Kibler's Bits |
| 2 | Dire Beast | Volley | Entrapment | — |
| 3 | — | — | — | Light Quiver |
| 4 | Multi-Shot | Readiness | Lock and Load | — |
| 5 | — | — | — | Net-o-Matic Projector |
| 6 | Spirit Bond | Trueshot Aura | Feign Death | — |
| 7 | The Beast Within | Wailing Arrow | Resourcefulness | Devilsaur Eye, Rhok'delar |

Plus les 4 cartes de départ au niveau 1 (22 cartes). Pourquoi cet ordre :

- **Niveau 1 complet par voie** : chaque voie a une attaque, une défense ou du contrôle, et sa pièce
  maîtresse (Bestial Wrath pour le Frenzy à 5, Aimed Shot + Careful Aim, trois Traps). L'Interrupt
  (Counter Shot) est là dès le départ. Un joueur de niveau 1 gagne en jouant une voie.
- **Niveaux 2, 4, 6** : chaque carte ouvre une manière de jouer, pas un chiffre de plus. Dire Beast : des
  ordres gratuits (tours à quatre attaques du familier). Volley : le Marksmanship contre les groupes.
  Entrapment : un deck de Traps qui se défend sans Absorb. Multi-Shot : le familier dans les combats à
  plusieurs. Readiness : les boucles de recharge entre voies. Lock and Load : les Traps qui piochent.
  Spirit Bond : la défense par le familier. Trueshot Aura : le tir d'ouverture comme plan de jeu. Feign
  Death : jouer au bord de la mort.
- **Niveau 7** : les rares qui changent la règle — chaque Attack commande le familier, interrompre tout
  un groupe, des Traps qui reviennent.

## 6. Besoins moteur et interface

### Moteur (`Core/`, Lua pur)

1. **Ressource** `c.player.frenzy` (0..5), journal `{ t = "frenzy", n, total }` ; remise à 0 dans
   `Combat.new` ; baisse de 1 dans `Combat.startPlayerTurn` si `c.round > 1` (avant `tickPeriodic` ou juste
   après, sans effet visible sur l'ordre) ; plafond appliqué à chaque gain.
2. **Cible du familier** `c.player.petTarget` (uid ou nil) : posée dans `Combat.play` dès qu'une carte à
   cible est jouée (avant la mise en incantation pour les Cast). Résolution : uid vivant, sinon
   `firstAlive(c)`.
3. **Attaque du familier** `Combat.petAttack(c, opts)` : cible, `Combat.calcDamage(c, c.player, cible,
   3 + frenzy, nil)` (cardDef nil : pas de bonus de carte), `dealDamage`, puis +1 Frenzy sauf
   `opts.surge` ; journal `{ t = "pet_attack", dst, dmg }` ; crochet `Combat.fire(c, "onPetAttack")`
   (Spirit Bond). Effet de carte `{ "pet", n }` (n attaques) et `{ "pet_surge" }` (Bestial Wrath).
4. **Attaque automatique** : dans `Combat.endPlayerTurn`, avant `Combat.fire(c, "onTurnEnd")` ; arrêt si
   `c.result`. Bibelot Pet Whistle : crochet `onTurnStart` au round 1.
5. **Spend N** (partagé avec le Warrior) : effet `{ "spend", n, effects }` sur la ressource de classe.
6. **Condition Careful Aim** : `t.hp * 2 > t.maxHp`, symétrique de `executeBonus`.
7. **Traps** : zone `c.traps` (liste ordonnée d'instances, 3 au plus, données simples, clonables) ;
   `Combat.canPlay` refuse la 4e (raison `"traps"`) ; une carte `trap = true` va dans la zone au lieu de
   résoudre. Dans `executeMove`, au début de chaque action `attack` (avant la boucle des coups) : si
   `#c.traps > 0`, retirer la première, `Combat.resolveCard` avec `ctx.target = e` (l'attaquant), puis
   `afterTrap` (défausse, épuisement ou main) ; crochet `onTrapTriggered(inst, e)` (Lock and Load,
   Entrapment, Net-o-Matic) ; si `e.dead` ou `c.result`, arrêter l'attaque. Les états posés pendant
   `c.phase == "enemy"` ont déjà le report de durée (`fresh`).
8. **Saut de tour ennemi** (Feign Death) : drapeau `c.player.flags.skipEnemyTurn` lu par
   `Combat.enemyPhase` (arrêt immédiat si posé en cours de phase).
9. **Readiness** : effet qui vide `c.cooldown` vers la main (dans la limite de 10).
10. **Wailing Arrow** : effet `interrupt` avec `all = true`.
11. **Statistiques** (simulation) : dégâts du familier (automatiques / commandés / Surge), Frenzy moyen au
    début du tour, Frenzy perdu au plafond, Traps posées / déclenchées / perdues en fin de combat,
    Stunned réussis vs bloqués par un boss, tours ennemis sautés.
12. **Bots** : l'heuristique doit choisir la cible en sachant qu'elle déplace le familier, compter la
    valeur d'une Trap (attaques annoncées ce tour), et Careful Aim à la résolution.

### Interface (`UI/`)

1. **Familier** : un portrait rond (icône de bête, `ability_hunter_pet_wolf` par défaut) collé au héros,
   côté ennemis, un peu plus bas ; il « bondit » vers sa cible à chaque attaque (file d'animations de
   `CombatView`), chiffre de dégâts sur la cible.
2. **Frenzy** : dans la pastille violette, comme l'Insanity ; cinq crans autour de la pastille ; à 5,
   liseré qui pulse. Le portrait du familier prend une teinte rouge proportionnelle (repère d'un regard).
3. **Cible du familier** : une petite griffe au-dessus de la barre de vie de l'ennemi visé, toujours
   visible. Au survol d'une carte à cible, la griffe montre en pointillé où ira le familier.
4. **Traps posées** : jusqu'à trois jetons carrés en rang devant les pieds du héros (icône de la carte,
   liseré vert, numérotés par ordre de déclenchement par leur position, la plus ancienne à gauche),
   infobulle = texte de la carte. Prévision : le premier ennemi qui attaquera (ordre d'action, intention
   d'attaque, non étourdi) porte l'icône miniature de la Trap qu'il va déclencher à côté de son
   intention. Déclenchement : le jeton s'envole vers l'attaquant et s'ouvre, avant le premier coup.
5. **Careful Aim et Execute** : un trait à 50 % sur chaque barre de vie ennemie (partagé avec le Warrior).
6. **Plaque** : le mot « Trap » comme « Cast ».
7. Raisons d'injouabilité : « 3 Traps already set », « No Frenzy » (Surge).

## 7. Risques d'équilibrage et mesures

1. **Familier passif.** La baisse de 1 par tour garde le familier seul à 3. À mesurer : part des dégâts
   du familier (automatique vs commandé) ; victoires d'un bot qui ne joue que défense contre l'heuristique.
   Si la classe se joue seule, baisser la base à 2 ou la baisse à −2.
2. **Frenzy trop facile à garder à 5.** Une fois à 5, une commande par tour suffit à l'y garder. À mesurer :
   Frenzy moyen au début du tour, tours passés à 5. Leviers : Arcane Shot (dégât direct), plafond par tour.
3. **Bestial Wrath** : 40 dégâts pour 1 mana à 5 Frenzy. À mesurer avec `pick=random` ; levier : coût 2.
4. **Contrôle vs boss.** Stunned ne prend pas sur les boss ; le Hunter s'y rabat sur Demoralized
   (Freezing Trap, Frost Trap, Concussive Shot, Entrapment) et Feign Death. À mesurer : PV perdus contre
   Edwin VanCleef par rapport aux autres combats ; victoires par voie au boss.
5. **Freezing Trap au départ** : un Stunned par cycle de deck sur les normaux et élites. À mesurer
   (`pick=random` sur la carte, puis voir les élites).
6. **Traps perdues** : contre des ennemis qui incantent ou se renforcent, les Traps attendent. À mesurer :
   part des Traps non déclenchées en fin de combat, par rencontre.
7. **Survie sans soin.** Style « contrôle » : PV perdus cibles proposées (à comparer aux mesures du Priest,
   `docs/equilibrage.md` : normal 15,4 ; élite 20,0 ; boss 51,6) : **normal ≤ 13, élite ≤ 18, boss ≤ 50**,
   victoires de l'expédition à ± 5 points du Priest. Le contrôle doit faire perdre moins de PV dans les
   combats ordinaires, pas plus contre le boss.
   Cible remplacée le 13/11/2026 : 6 à 9 PV perdus par combat normal pour toutes les classes
   (`decisions.md`) ; le Hunter en perdait 4,5, d'où Disengage 3/6 et 50 PV (`docs/equilibrage.md`,
   « Passe 3 »). Au bot human (18/11/2026), ses défaites venaient presque toutes du boss de chaque zone
   (24 PV perdus, 39 % de ses PV, contre 5 par combat normal) : 50 → 56 PV, Disengage inchangé
   (`docs/equilibrage.md`, « Hunter : réglage au bot human (18/11/2026) »).
8. **Identité** : le DoT (Survival) est partagé avec Priest, Warlock, Rogue ; Hunter's Mark + gros tir
   rappelle le Warrior Arms (Sundered + gros coup). Ce qui doit rester propre : le familier, les Traps,
   Careful Aim (l'inverse d'Execute). Aucune carte Hunter ne dépend d'Execute.
9. **Longueur du tour en vol** : le familier et les Traps ajoutent des animations au tour ennemi ; garder
   ces animations courtes (≤ 0,3 s chacune).

## Points à faire trancher

- Baisse du Frenzy (−1 au début de chaque tour sauf le premier) : ajout à la règle du GDD.
- Arcane Shot ramené à « Deal 3 » + familier (GDD : 6).
- Une Trap par attaque, la plus ancienne d'abord ; trois Traps au plus.
- Les bonus « Attacks » ne s'appliquent pas au familier ; Strength et Demoralized du Hunter oui.
- PV 65 et rareté « Départ » des bibelots de départ.
