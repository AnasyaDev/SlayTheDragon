# Swamp of Sorrows — fiche de zone (zone 5, id `swamp`)

Fiche de conception (13/11/2026, deuxième version), pas de code. Format et puissance de référence :
`Data/Act1.lua` (Westfall). Difficulté visée : **Westfall + 48 %** (PV et dégâts × 1,48). Les groupes qui
comptent des dormeurs ont jusqu'à 10 % de PV en plus que ce repère : un dormeur ne frappe pas pendant ses
tours de sommeil. Tous les chiffres sont des points de départ ; la simulation les réglera.

La première version (Afflictions : cartes nuisibles qui restaient dans le deck) est abandonnée, trop proche
de Curse (Duskwood). Disparaissent avec elle : les trois cartes Affliction, Lingering, l'action Treat au feu
de camp, le prix du retrait chez le marchand, la Strength de Somnus par Affliction et le type de rencontre
« marché ». La mécanique de la zone est désormais **Slumber**.

Sources : noms, identifiants de créature et niveaux lus dans la base de PNJ de Questie installée avec le
client Classic Era (`_classic_era_/Interface/AddOns/Questie/Database/Classic/classicNpcDB.lua`, zone 8 =
Swamp of Sorrows) ; affichages dans les caches de créatures des clients (§ 10).

## 1. La zone en trois lignes

- **Lieux** : route = la piste de Misty Valley entre les roseaux et l'eau ; camp = **Fallow Sanctuary**
  (huttes des Lost Ones) ; marchand = **Stonard** (avant-poste orc) ; élites = **Misty Reed Strand** (côte),
  les marches du **Temple of Atal'Hakkar**, le camp du chef des Lost Ones au-dessus de Fallow Sanctuary ;
  boss = la **Pool of Tears**, au pied du temple englouti.
- **Ambiance factuelle** : marais boisé, eau stagnante jusqu'aux genoux, crocolisks dans chaque mare,
  dragonkin verts qui dorment autour du temple et le gardent, Lost Ones (draeneï exilés) qui vivent en
  marge de Stonard. Niveaux 35 à 45 dans Classic.
- **Fonds de scène** : `swamp` (route), `sanctuary` (camp), `stonard` (marchand), `coast` (Misty Reed
  Strand, existe), `temple` (marches du temple), `pool` (boss).
- **Ce que la zone enseigne** : le premier coup compte. Un ennemi endormi ne frappe pas, mais il se
  réveille avec son plus gros coup ; le joueur choisit qui réveiller, quand et avec quelle carte.

## 2. La mécanique de la zone : Slumber

### Règle

1. **Asleep N.** Certains ennemis commencent le combat avec l'état **Asleep N** (N = 2 ou 3, écrit dans
   leur définition ou dans la composition du groupe). Un ennemi endormi ne fait rien à son tour : au lieu
   d'agir, son compteur Asleep baisse de 1. Quand il atteint 0, l'ennemi se réveille (journal « X wakes
   up. »), sans agir ce tour-là. Asleep N = N tours sans agir.
2. **Ouverture (Opener).** Chaque ennemi qui peut dormir a une **ouverture** : une intention plus forte que
   ses coups ordinaires. Elle est **annoncée dès le début du combat**, en gris sous l'icône de sommeil
   (« On waking: Death Roll 20 »). Dès que l'ennemi se réveille, l'ouverture devient son intention. Il la
   joue **à la première phase ennemie qui commence après son réveil**, puis reprend son motif au début.
   - réveillé pendant le tour du joueur : ouverture dans la phase ennemie de ce round ;
   - réveillé pendant la phase ennemie (son compteur à 0, un DoT au début de son tour, une Trap, une
     riposte, une Alarm) : il n'agit plus dans cette phase, ouverture au round suivant.
3. **Tout dégât réveille.** Un ennemi endormi qui subit des dégâts se réveille aussitôt, quelle que soit la
   source : carte, Cast résolu, dégâts à tous, tic de DoT, familier, Trap, riposte, bibelot. Un coup
   entièrement absorbé par l'Absorb de l'ennemi le réveille aussi. Un coup qui le tue ne le réveille pas :
   il meurt sans avoir agi.
4. **Rude Awakening (+50 %).** Le premier coup qui touche un ennemi endormi lui inflige **50 % de plus**
   (arrondi au supérieur), s'il vient d'un effet qui **ne vise qu'un ennemi** : carte à une cible,
   attaque du familier, Trap à une cible, bibelot à une cible, tir sur une cible au hasard (Killing
   Spree). Le bonus se calcule en dernier (après Strength, Charges, Frenzy, Stealth, Sundered), avant
   l'Absorb de l'ennemi. Une carte à plusieurs coups (Penance, Raging Blow) ne le donne qu'au premier.
   **Pas de bonus** pour un effet « to all » ni pour un tic de DoT : ils réveillent sans bonus.
5. **Ce qui ne réveille pas** : tout ce qui n'inflige pas de dégâts. Poser un DoT, Sundered, Demoralized,
   Stunned, Hunter's Mark ou une Trap ne réveille pas ; seul le dégât compte (le premier tic de DoT
   réveille donc, au début du tour de l'ennemi : règle 2, ouverture au round suivant).
6. **Stunned sur un dormeur.** Le tour perdu est son tour de sommeil : le compteur Asleep ne baisse pas ce
   tour-là. Polymorph (Stunned 2) sur un ennemi Asleep 2 le fait dormir quatre tours.
7. **Stunned sur un ennemi qui doit jouer son ouverture.** Il perd son tour comme d'habitude, mais
   l'ouverture **n'est pas consommée** : elle reste annoncée et part à son prochain tour joué. Même règle
   pour Freezing Trap, qui arrête le tour pendant l'ouverture (décision commune du 12/11/2026).
8. **Mort d'un allié.** Elle ne réveille personne (à l'inverse de Pack, la mort ne transmet rien). Seule
   l'action **Alarm** réveille un groupe.
9. **Victoire.** Il faut tuer tous les ennemis principaux, endormis compris. Aucun ennemi ne dort plus de
   3 tours sans Stunned (4 avec Egg of Hakkar, § 9) ; un même ennemi ne peut être rendormi (Lull) qu'une fois par combat.

### Actions ennemies liées

| Action | Type | Règle |
|---|---|---|
| **Lull** | Cast | À sa résolution : l'allié éveillé le plus blessé (pas le lanceur, pas un boss, pas un ennemi déjà rendormi dans ce combat, au moins 8 PV perdus) reçoit **Asleep 2** et se soigne de 8. Réveillé ensuite, il rejoue son ouverture (un ennemi sans ouverture reprend son motif). Interrompu, ou sans cible valable : rien. |
| **Alarm** | Cast | À sa résolution : tous les alliés endormis se réveillent (pendant la phase ennemie, donc ouvertures au round suivant, toutes ensemble). Interrompue : rien. |
| **Slumber N, mend X** | — | L'ennemi s'endort lui-même (Asleep N) ; à chacun de ses tours de sommeil, il se soigne de X. Un tour perdu par Stunned ne soigne pas. Utilisé par Wyrmak et Somnus. |
| Attaque `perAsleep` | attack | `{ "attack", 6, perAsleep = 3, cap = 9 }` : +3 par allié endormi, affiché à jour. Wyrmkin Dreamwalker. |

### Ce que voit le joueur

- Sur l'ennemi endormi : à la place de l'intention, l'icône `spell_nature_sleep` et « Asleep 2 » ; dessous,
  en gris, l'ouverture et ses chiffres (« On waking: Death Roll 20 »). Au réveil, l'ouverture passe en
  couleur et devient l'intention, avec une courte animation (≤ 0,3 s) et le journal.
- **Aperçu au survol d'une carte** : sur un dormeur visé par une carte à une cible, le chiffre de dégâts
  prévu inclut le bonus et porte le mot « Wake » (« 33 Wake ») ; sur une carte « to all » ou un DoT, chaque
  dormeur touché montre « Wakes » sans bonus.
- Les intentions Lull et Alarm montrent le nombre de dormeurs concernés (Alarm : « Wakes 2 »).

### Infobulles (≤ 60 caractères)

| Terme | Infobulle |
|---|---|
| Asleep N | `Skips its next N turns. Damage wakes it up.` |
| Opener (« On waking: ») | `Its first move after it wakes up.` |
| Rude Awakening | `First single-target hit on a sleeper: +50% damage.` |
| Lull (intention) | `Cast. Puts a wounded ally to sleep and heals it 8.` |
| Alarm (intention) | `Cast. Wakes up all sleeping allies.` |

### Interactions

| Avec | Règle |
|---|---|
| Absorb du joueur | Normale. L'ouverture est annoncée : le joueur pose son Absorb avant de réveiller. |
| Absorb de l'ennemi | Un dormeur peut en recevoir (Bog Shield). Un coup entièrement absorbé le réveille ; le bonus s'applique avant l'Absorb. Il perd son Absorb au début de son tour, endormi ou non. |
| Parry (Rogue) | Normale : une charge annule un coup jusqu'à 8. Les ouvertures (20 à 26) passent au-dessus : le Rogue préfère tuer avant l'ouverture. |
| Stunned | Règles 6 et 7 : sur un dormeur, le compteur ne baisse pas ; sur une ouverture, elle est retardée, pas perdue. Boss immunisés : rien de cela contre Somnus. |
| Cast du joueur | Le Cast se résout au début du tour suivant : si la cible dort encore, il a le bonus et la réveille (ouverture dans ce round) ; si son compteur l'a réveillée entre-temps, pas de bonus. Le compteur visible dit si le pari tient. |
| Cast ennemi (Lull, Alarm) | Interruptibles comme tout Cast. Un lanceur étourdi ou tué avant sa résolution ne lance rien. |
| Traps (Hunter) | Un dormeur n'attaque pas : il ne déclenche aucune Trap. Explosive Trap (à tous) déclenchée par un ennemi éveillé réveille les dormeurs sans bonus, ouvertures au round suivant. Freezing Trap sur une ouverture : règle 7. |
| DoT | Poser un DoT ne réveille pas ; le premier tic, au début du tour du dormeur, le réveille sans bonus et sans qu'il agisse (ouverture au round suivant). C'est le réveil « doux » : pas de bonus, un round de répit. |
| Familier du Hunter | L'attaque automatique de fin de tour vise la dernière cible **éveillée** du joueur ; elle ne vise un dormeur que si aucun ennemi n'est éveillé. Elle a alors le bonus. Les attaques commandées (« Pet attacks. ») frappent la cible de la carte, dormeur compris, avec le bonus au premier coup. |
| Dégâts à tous | Holy Nova, Halo, Cleave, Whirlwind, Thunder Clap, Arcane Explosion, Flamestrike, Blizzard, Fan of Knives, Multi-Shot, Volley, Rough Dynamite, Crude Flint, Mor'Ladim's Skull : réveillent tous les dormeurs touchés, sans bonus. Blade Flurry : la cible principale a le bonus, les autres se réveillent sans. |
| Mind Sear, Living Bomb, Fire Oil | DoT à tous : chaque dormeur se réveille à son tour, sans bonus, ouvertures au round suivant. |
| Execute, Careful Aim | Aucune règle propre. Un dormeur est à pleins PV (Careful Aim vrai, Execute faux), sauf un ennemi rendormi par Lull après avoir été blessé. |
| Frozen (Mage) | Asleep n'est pas Frozen (Frozen = Stunned ou Demoralized). |
| Stealth (Rogue) | Se cumule : Ambush sur un dormeur = (6 + 12) × 1,5 = 27. |
| Bibelots de début de combat | Nesingwary 4000 (10 au plus gros) : coup à une cible, bonus, réveil avant le tour 1, ouverture au round 1. |
| Fuite (Hearthstone) | Inchangée. |

### Les décisions qu'elle crée

- **Qui réveiller et avec quoi.** Réveiller le Swampwalker avec Mortal Strike rapporte 11 dégâts de plus
  mais lance Bog Crush (22) ce round ; le laisser dormir 3 tours coûte le bonus mais donne le temps de
  tuer les éveillés.
- **Tuer avant qu'il agisse.** Un dormeur tué dans le tour de son réveil ne joue jamais son ouverture :
  garder son plus gros coup pour la fin du tour, après les coups qui l'ont réveillé.
- **Éviter les dégâts à tous.** Avec deux dormeurs dans le groupe, Cleave ou Holy Nova lance deux
  ouvertures sans bonus. Pack (Wetlands) récompensait les morts groupées ; ici, la zone pousse au coup
  ciblé.
- **Réveil doux ou réveil fort.** Un DoT réveille sans bonus et sans ouverture ce round ; un coup direct
  donne le bonus et l'ouverture tout de suite. Stunned après un réveil retarde l'ouverture d'un round.
- **Lanceurs.** Interrompre Lull (sinon un ennemi soigné rejoue son ouverture) ou Alarm (sinon toutes les
  ouvertures arrivent ensemble au round suivant), ou tuer le lanceur.

### Écarts avec l'idée de départ

1. **Le bonus ne vaut que pour un coup à une cible.** Sinon les cartes à tous étaient récompensées
   (Halo 22 → 33 tuait tous les dormeurs de 30 PV), à l'inverse de ce qui était voulu.
2. **Pas de bonus sur un tic de DoT.** Mind Sear aurait donné le bonus à tous ; le DoT devient le réveil
   doux (ouverture retardée d'un round, sans bonus).
3. **Compteur visible (Asleep 2 ou 3).** Un dormeur se réveille seul : impossible d'attendre sans fin, et le
   combat reste borné.
4. **Moment de l'ouverture fixé par une seule règle** (première phase ennemie après le réveil) : un réveil
   pendant la phase ennemie (Trap, DoT, Alarm) la repousse au round suivant.
5. **Stunned retarde l'ouverture sans l'annuler** ; sur un dormeur, il gèle le compteur. Sinon Freezing
   Trap et Frost Nova effaçaient la menace de la zone.
6. **Le familier ne réveille pas seul** tant qu'un ennemi est éveillé ; sinon le Hunter réveillait sans le
   vouloir à chaque fin de tour.
7. **Lull** soigne une fois (8) au lieu de soigner pendant le sommeil, une fois par ennemi et par combat ;
   le soin pendant le sommeil est réservé aux deux ennemis qui s'endorment eux-mêmes (Wyrmak, Somnus).
8. **La mort d'un allié ne réveille personne** (seule Alarm le fait), pour ne pas refaire Pack.

### Aucune classe sans réponse

| Classe | Réponse |
|---|---|
| Priest (36 PV) | SW: Pain réveille en douceur, Smite (12) et Holy Fire (36 en Cast) réveillent fort, Holy Word: Chastise réveille et retarde l'ouverture, Silence coupe Lull et Alarm ; Holy Nova et Halo sont à garder pour les groupes sans dormeur. |
| Warrior (74 PV) | Mortal Strike réveille pour 33 et l'ouverture reçue donne de la Rage ; Rend réveille en douceur, Pummel coupe les lanceurs ; Cleave, Whirlwind, Thunder Clap et Bladestorm réveillent tout le groupe. |
| Mage (42 PV) | Pyroblast (45) ou Glacial Spike (39) tuent un dormeur moyen avant qu'il agisse ; Polymorph le laisse dormir ou retarde son ouverture, Frost Nova gèle tous les compteurs ; Flamestrike, Blizzard et Arcane Explosion sont punis. |
| Rogue (50 PV) | Stealth et bonus se cumulent (Ambush 27, Backstab 15) ; Garrote réveille en douceur, Cheap Shot retarde l'ouverture, Kick à 0 mana ; Parry pare mal les ouvertures, donc tuer avant qu'elles partent. |
| Hunter (50 PV) | Aimed Shot avec Careful Aim (34 → 51) sur une cible intacte ; le familier n'éveille personne seul, Serpent Sting réveille en douceur, Freezing Trap retarde l'ouverture ; Multi-Shot, Volley et Explosive Trap réveillent tout le groupe. |

Aucune ne trivialise la zone : les coups qui tuent un dormeur d'un coup coûtent 2 mana ou un Cast (pari sur
le compteur), Polymorph est Exhaust, Frost Nova a Cooldown 4, et Somnus, immunisé à Stunned, dort et se
réveille sur ses propres règles.

### Ce que le moteur doit apprendre

`Data/Act1.lua` sait déjà : intentions à actions multiples, Cast ennemi interruptible, `ai`, motifs,
`summon`, `minion`, `block_ally`, `heal_ally`, `onDamaged`, Stunned qui arrête un tour. Il manque :

1. **État d'ennemi `asleep`** (intensité, dans `e.st`, sauvegardable), posé par la définition
   (`asleep = 2`) ou par la composition (`{ "sawtooth_crocolisk", asleep = 3 }`) ; champ `opener =
   "<id de move>"`.
2. **`executeMove` d'un dormeur** : s'il est Stunned, le tour est perdu sans baisse ; sinon `asleep − 1`,
   à 0 appel de `Combat.wake`. Aucune action, aucune Trap déclenchée. Effet `mend` (Slumber) avant la
   baisse.
3. **`Combat.wake(c, e, cause)`** : retire `asleep`, met l'ouverture comme intention, note
   `e.mem.wokeInEnemyPhase` (pas d'action dans la phase en cours), journal `{ t = "wake", unit, by }`.
4. **`Combat.dealDamage`** : si la cible dort, multiplier par 1,5 (arrondi au supérieur) quand l'effet est
   marqué `single` et n'est pas un tic de DoT ; puis réveiller si la cible survit (même dégât absorbé).
   Les effets doivent porter le drapeau `single` (cible unique, familier, Trap à une cible, bibelot).
5. **Ouverture non consommée** quand l'ennemi est Stunned (l'intention ne passe pas au move suivant).
6. **Familier** : `Hunter.petTarget` saute les dormeurs tant qu'un ennemi est éveillé.
7. **Actions ennemies** `{ "lull", 2, heal = 8 }` (choix de la cible à la résolution, drapeau
   `e.mem.lulled`), `{ "alarm" }`, `{ "slumber", n, mend = x, opener = id }`, attaque
   `{ "attack", n, perAsleep = k, cap = m }` affichée par `Combat.intentInfo`.
8. **Effet de carte et de bibelot** `{ "apply", "asleep", n }` (Dream Dust, Egg of Hakkar ; boss
   immunisés) ; endormi en cours de combat, l'ennemi perd son intention annoncée.
9. **Combat de rencontre** : `{ "fight", groupe, asleep = n }` pose Asleep n à chaque ennemi non boss
   (type de rencontre du § 8).
10. **Interface** : icône et compteur de sommeil, ouverture grisée, mot « Wake » dans l'aperçu de dégâts,
    « Wakes » sur les dormeurs touchés par une carte à tous, animation de réveil.
11. **Bots** : valeur d'un réveil (bonus − ouverture subie, nulle si le dormeur meurt dans le tour) ;
    pénalité des cartes à tous selon les ouvertures déclenchées ; priorité aux lanceurs de Lull et Alarm.
12. **Statistiques** : réveils par cause (coup à une cible, à tous, DoT, compteur, Alarm), dormeurs tués
    avant d'agir, ouvertures subies et retardées, Lull et Alarm lancés et interrompus.

## 3. Ennemis normaux (9)

Repères Westfall × 1,48 : Riverpaw Gnoll 19–22 PV / 8 → 28–33 / 12 ; Defias Conjurer, Fireball 16 → 24.
Six ennemis sur neuf utilisent Slumber (quatre dormeurs, un qui rendort, un qui donne l'alarme). Les
ouvertures valent 1,6 à 1,9 fois le coup ordinaire du même ennemi.

| id | Nom (créature) | PV | Asleep | Ouverture | Intentions | Motif | Rôle |
|---|---|---|---|---|---|---|---|
| `sawtooth_crocolisk` | Sawtooth Crocolisk (1082) | 40–44 | 2 | **Death Roll** (attack) : 20. | **Snap** (attack) : 12. **Submerge** (defend) : block 10. | snap, submerge | Le dormeur de base : apprendre à réveiller avec le bon coup. |
| `dreaming_whelp` | Dreaming Whelp (741) | 15–17 | 2 | **Dream Breath** (attack) : 10. | **Bite** (attack) : 6. | bite | Petit dormeur, par deux : une carte à tous les réveille ensemble sans les tuer. |
| `swampwalker` | Swampwalker (764) | 48–52 | 3 | **Bog Crush** (attack) : 22, interrompt. | **Vine Lash** (attack) : 10. **Bog Shield** (defend) : block 8, block_ally 8 (l'allié le plus blessé, dormeur compris). | lash, shield | Le gros dormeur : on le garde pour la fin, ou on le réveille tôt pour le bonus. |
| `green_scalebane` | Green Scalebane (744) | 44–48 | 2 | **Cleave** (attack) : 24. | **Strike** (attack) : 13. **Scale Guard** (defend) : block 12, Strength 1. | strike, guard | Dragonkin du temple : son ouverture est le plus gros coup des normaux. |
| `wyrmkin_dreamwalker` | Wyrmkin Dreamwalker (743) | 30–33 | — | — | **Lull** (cast) : Lull 2, soin 8. **Dream Bolt** (attack) : 6, +3 par allié endormi (+9 au plus). | ia : Lull si un allié éveillé valable a perdu ≥ 8 PV et que le tour d'avant n'était pas Lull ; sinon Dream Bolt | Lanceur : rendort ceux qu'on a entamés et frappe plus fort tant que d'autres dorment. Pousse à réveiller. |
| `marsh_oracle` | Marsh Oracle (752) | 24–27 | — | — | **Alarm Cry** (cast) : Alarm. **Lightning Bolt** (attack) : 10. | ia : Alarm Cry si un allié dort et que le tour d'avant n'était pas Alarm Cry ; sinon Lightning Bolt | Murloc qui réveille le groupe : l'interrompre, le tuer, ou réveiller soi-même avant lui. |
| `deathstrike_tarantula` | Deathstrike Tarantula (769) | 30–33 | — | — | **Venomous Bite** (attack) : 7, puis DoT 3 sur le joueur. **Web** (debuff) : 5, puis Demoralized 1 ⌛ sur le joueur. | bite, web ; départ au hasard | Éveillée, elle frappe pendant que les autres dorment. |
| `marsh_inkspewer` | Marsh Inkspewer (750) | 16–18 | — | — | **Claw** (attack) : 6. **Ink Spit** (debuff) : 4, puis Sundered 1 ⌛ sur le joueur. | ink, claw ; départ au hasard | Nuée éveillée ; son Sundered fait passer les ouvertures plus fort. |
| `lost_one_hunter` | Lost One Hunter (759) | 32–36 | — | — | **Spear Thrust** (attack) : 13. **Net** (debuff) : 6, puis Demoralized 1 ⌛ sur le joueur. | thrust, net ; départ au hasard | Combattant éveillé, sans mécanique. |

Retirés de la première version : Lost One Seer (son rôle de soutien passe au Dreamwalker), Nightmare Whelp
et Nightmare Wyrmkin (absents de la base de la zone : remplacés par Dreaming Whelp et Wyrmkin Dreamwalker,
créatures réelles du temple). Autres créatures de la zone non retenues : Adolescent Whelp (740), Green
Wyrmkin (742), Scalebane Captain (745), Elder Dragonkin (746), Marsh Murloc (747), Marsh Flesheater (751),
Lost One Mudlurker (755), Fisherman (757), Riftseeker (762), Swampwalker Elder (765), Tangled Horror (766),
Swamp Jaguar (767), Shadow Panther (768), Sorrow Spinner (858), Young Sawtooth Crocolisk (1084), Sawtooth
Snapper (1087), Mire Lord (1081).

### Groupes

| Liste | Composition (de gauche à droite) | PV totaux | Idée |
|---|---|---|---|
| easy | Sawtooth Crocolisk | 40–44 | Réveiller avec son meilleur coup, puis encaisser Death Roll. |
| easy | Marsh Inkspewer ×3 | 48–54 | Nuée sans dormeur : les cartes à tous servent. |
| easy | Dreaming Whelp ×2, Marsh Inkspewer | 46–52 | Ne pas tout réveiller pour tuer un murloc. |
| easy | Deathstrike Tarantula, Marsh Inkspewer | 46–51 | Sans dormeur. |
| normal | Deathstrike Tarantula, Sawtooth Crocolisk, Marsh Inkspewer | 86–95 | Tuer les éveillés en 2 tours avant Death Roll, ou réveiller le crocolisk pour le bonus. |
| normal | Wyrmkin Dreamwalker, Dreaming Whelp ×2, Marsh Inkspewer | 76–85 | Dream Bolt à 12 tant que les dragonnets dorment ; les réveiller d'un coup les fait souffler tous les deux. |
| normal | Marsh Oracle, Swampwalker, Marsh Inkspewer | 88–97 | Couper Alarm Cry ou subir Bog Crush au round 2. |
| normal | Green Scalebane, Wyrmkin Dreamwalker | 74–81 | Le Dreamwalker rendort le Scalebane entamé : Cleave deux fois. |
| normal | Lost One Hunter, Deathstrike Tarantula | 62–69 | Combat éveillé, court. |
| normal | Marsh Oracle, Sawtooth Crocolisk, Dreaming Whelp | 79–88 | Alarm réveille deux dormeurs : deux ouvertures au même round. |
| elite | Lost One Chieftain + Lost One Muckdweller · Lord Captain Wyrmak · Gilmorian | § 4 | |
| boss | Somnus | § 5 | |
| `event_crocs` | Sawtooth Crocolisk ×2 | 80–88 | Rencontre de Stonard. |
| `event_galen` | Marsh Inkspewer ×4 | 64–72 | Rencontre de Galen. |
| `event_dragonkin` | Green Scalebane, Dreaming Whelp ×2 (tous Asleep 3) | 74–82 | Rencontre des marches du temple (type « Sleeping Camp »). |
| `event_gilmorian` | Gilmorian | 104 | Rencontre de Misty Reed Strand. |

Cible : 6 à 9 PV perdus par combat normal, 2,7 à 4 tours. Repère de calcul : une ouverture subie par
combat normal en moyenne (20 à 24, en partie absorbée), le reste des coups venant des éveillés.

## 4. Élites (3)

| id | Nom (créature) | PV | Intentions et motif | Idée de combat |
|---|---|---|---|---|
| `lost_one_chieftain` | Lost One Chieftain (763), Lost One rare | 104, **Asleep 2** | Ouverture **Spear of the Lost** (attack) : 26, interrompt. Puis **Spear Thrust** (attack) : 15 · **Rally** (buff) : block 10, Strength 2 · **Crushing Blow** (debuff) : 9, puis Sundered 1 ⌛ sur le joueur ; motif thrust, rally, crush. | **La sentinelle.** Le chef dort dans sa hutte ; sa sentinelle sonne du cor dès le round 1. Le joueur l'interrompt ou la tue (20 PV), puis prépare son tour et réveille le chef avec son meilleur coup ; sinon le chef se réveille sans bonus et Spear of the Lost part au round 2. |
| `lost_one_muckdweller` | Lost One Muckdweller (760), serviteur (`minion = true`) | 20–22 | **Warning Horn** (cast) : Alarm. **Stab** (attack) : 7. ia : Warning Horn si un allié dort et que le tour d'avant n'était pas Warning Horn ; sinon Stab. | Sentinelle du chef. Sa mort ne termine pas le combat ; celle du chef, si. |
| `wyrmak` | Lord Captain Wyrmak (14445), dragonkin rare élite | 112 | **Cleave** (attack) : 18 · **Tail Sweep** (attack) : 9, interrompt ; block 10 · **Wing Buffet** (debuff) : 12, puis Demoralized 1 ⌛ sur le joueur ; motif cleave, sweep, buffet. **Dream** (`onDamaged`, une fois, après l'effet en cours) : à 56 PV ou moins, « Wyrmak falls into the Dream. » : Slumber 2, mend 12 ; ouverture **Dream Fury** (attack) : 14 deux fois ; puis le motif reprend à Cleave. | **Le dormeur qui se soigne.** À mi-vie il s'endort et regagne 12 PV par tour. Le réveiller tout de suite (bonus, Dream Fury 28 dans le round) ou le laisser regagner jusqu'à 24 PV et recevoir Dream Fury plus tard ; ou garder 56 dégâts pour le tuer dans son sommeil. Stunned sur lui endormi : compteur gelé, pas de soin. |
| `gilmorian` | Gilmorian (14447), naga rare de la côte | 104 | **Lightning Bolt** (cast) : 24 · **Frost Shock** (attack) : 8, interrompt ; Demoralized 1 ⌛ sur le joueur · **Healing Wave** (cast) : soigne 20 (elle-même, `heal_ally`) ; motif bolt, shock, wave. | **Le duel d'interruptions**, sans Slumber : deux incantations sur trois tours ; un seul Interrupt à Cooldown 2 ne suffit pas, il faut choisir entre bloquer 24 et empêcher 20 PV de soin. L'élite où les cartes à tous et les gros Cast reprennent leur valeur. |

Composition de l'élite du chef : {Lost One Muckdweller, Lost One Chieftain} (la sentinelle à gauche agit
d'abord : son cor sonne avant le tour du chef).

## 5. Boss : Somnus (dragon vert)

Somnus (12900), dragon vert élite qui garde la Pool of Tears devant le Temple of Atal'Hakkar.
**148 PV.** Immunisé à Stunned (règle des boss) et à tout effet qui endort (Dream Dust, Egg of Hakkar) ;
pas aux Interrupts. Vise 6 à 7 tours (Edwin VanCleef : 92 PV).

| Phase | Déclencheur | Intentions et motif |
|---|---|---|
| 1 — Sleeping | début du combat | **Asleep 2.** Ouverture **Bellowing Roar** (attack) : 22, puis Demoralized 1 ⌛ sur le joueur. |
| 2 — Awake | réveil (coup du joueur ou compteur) | Motif après l'ouverture : **Noxious Breath** (attack) : 8 deux fois, puis DoT 3 sur le joueur · **Claw** (attack) : 24 · **Wing Buffet** (attack) : 12, interrompt ; block 12 ; motif breath, claw, buffet. |
| 3 — The Dream | 74 PV ou moins (`onDamaged`, une fois, après l'effet en cours) | « Children of the Dream, defend me! » : invoque 2 **Dreaming Whelp** éveillés (serviteurs, 14 PV, **Bite** 6). Somnus : **Slumber 2, mend 10**. Ouverture **Deep Breath** (attack) : 14 deux fois. Motif ensuite : **Claw** 26 · **Noxious Breath** 9 deux fois, puis DoT 3 · **Wing Buffet** 12, interrompt ; block 12. |

Lecture du combat :
- **Phase 1** : deux tours de sommeil. Le joueur choisit entre réveiller Somnus au tour 1 avec son meilleur
  coup à une cible (bonus + 50 %, Bellowing Roar dans le round) et prendre deux tours pour poser Pouvoirs,
  Sundered et Absorb (Bellowing Roar au round 3, sans bonus).
- **Phase 2** : 148 → 74 PV en trois tours environ (≈ 24 dégâts par tour à ce stade).
- **Phase 3** : Somnus se rendort à 74 PV et regagne 10 par tour de sommeil, pendant que deux dragonnets
  mordent. Réveiller le dragon tout de suite (bonus, Deep Breath 28 dans le round, plus 12 des dragonnets)
  ou tuer d'abord les dragonnets (28 PV) en le laissant regagner jusqu'à 20 PV. Le joueur choisit aussi
  quelle carte fait franchir les 74 PV : le sommeil tombe après la carte entière, le coup suivant a le
  bonus.
- **Durée** : 1 à 2 tours de sommeil + 3 tours de phase 2 + 2 à 3 tours de phase 3 (74 PV, dragonnets,
  soin) = **6 à 7 tours**.

## 6. Rencontres (8)

Format de `Data/Events.lua`, `act = 5`. Les nouveaux décors sont ceux du § 1. Aucune rencontre ne dépend
plus des Afflictions ; `temple_steps` est l'exemple du type « Sleeping Camp » débloqué (§ 8).

```lua
event("stonard_outpost", {
  name = "Stonard", act = 5, tier = 0,
  speaker = "Dispatch Commander Ruag", npc = "dispatch_commander_ruag", scene = "stonard",
  text = "\"Stonard does not turn away travelers who can fight. Two Sawtooth crocolisks sleep on the "
    .. "riverbank south of the outpost, and my grunts need their hides. If you want a bed, the inn is open.\"",
  choices = {
    { label = "Hunt the crocolisks", outcome = "Fight 2 sleeping crocolisks: usual reward + 25g",
      result = "Ruag sends you to the riverbank south of the outpost.",
      effects = { { "fight", "event_crocs", gold = 25 } } },
    { label = "Pay the healer", outcome = "Pay 30g, +18 HP",
      result = "The healer cleans your wounds and gives you a bitter tea.",
      effects = { { "pay", 30 }, { "heal", 18 } } },
    { label = "Rest at the inn", outcome = "+10 HP",
      result = "The innkeeper gives you a bed for the afternoon.",
      effects = { { "heal", 10 } } },
    -- carte neutre débloquée par la zone (§ 8)
    { label = "Visit the alchemist", outcome = "Pay 25g, Dreamless Sleep Potion (card)",
      when = { { "unlocked", "dreamless_sleep_potion", hide = true } },
      result = "Rartar sells you a vial from his shelf.",
      effects = { { "pay", 25 }, { "card", "dreamless_sleep_potion" } } },
  },
})

event("pool_of_tears", {
  name = "The Pool of Tears", act = 5, tier = 0,
  speaker = "Fel'Zerul", npc = "fel_zerul", scene = "pool",
  text = "\"The Atal'ai threw their artifacts into the Pool of Tears when the temple sank. I want them "
    .. "back. The water is full of Sawtooth crocolisks, so I am not going in myself.\"",
  choices = {
    { label = "Dive into the pool", outcome = "50%: a relic, else -10 HP",
      effects = { { "gamble", 0.5,
        win = { { "relic" } },
        winText = "You find an Atal'ai idol in the mud at the bottom. Fel'Zerul lets you keep it.",
        lose = { { "loseHp", 10 } },
        loseText = "A crocolisk bites your leg before you reach the bottom." } } },
    { label = "Search the shallows", outcome = "+35g, -5 HP",
      result = "You pull two artifacts from the reeds and cut your hand on the second. Fel'Zerul pays you.",
      effects = { { "gold", 35 }, { "loseHp", 5 } } },
    { label = "Leave", outcome = "Nothing",
      result = "Fel'Zerul goes back to watching the water.",
      effects = {} },
  },
})

event("galen_escape", {
  name = "Galen's Escape", act = 5, tier = 0,
  speaker = "Galen Goodward", npc = "galen_goodward", scene = "swamp",
  text = "\"Marsh murlocs dragged me to their camp and took my strongbox. I got loose, but I can't get "
    .. "past them alone. Get me to the road and we split what's in the box.\"",
  choices = {
    { label = "Escort Galen", outcome = "Fight 4 murlocs: usual reward + 30g",
      result = "The murlocs see you coming and charge.",
      effects = { { "fight", "event_galen", gold = 30 } } },
    { label = "Take the strongbox back alone", outcome = "50%: 60g, else -9 HP",
      effects = { { "gamble", 0.5,
        win = { { "gold", 60 } },
        winText = "The murlocs are fishing. You carry the strongbox out of the camp and Galen pays you.",
        lose = { { "loseHp", 9 } },
        loseText = "A murloc spears you as you lift the strongbox. You drop it and run." } } },
    { label = "Show him the way to the road", outcome = "Nothing",
      result = "Galen thanks you and heads for the road on foot.",
      effects = {} },
  },
})

event("fallow_sanctuary", {
  name = "Fallow Sanctuary", act = 5, tier = 1,
  speaker = "Magtoor", npc = "magtoor", scene = "sanctuary",
  text = "\"We are the Lost Ones. We came here from Draenor, and the dragons of the temple hunt us. "
    .. "Share your food with us and our elders will teach you what they know.\"",
  choices = {
    { label = "Share your rations", outcome = "Pay 20g, remove a card from your deck",
      result = "The elders eat with you and show you what to leave behind.",
      effects = { { "pay", 20 }, { "remove" } } },
    { label = "Help them rebuild their huts", outcome = "-6 HP, upgrade a card of your choice",
      result = "You carry logs from the river all day and learn from the Lost Ones as you work.",
      effects = { { "loseHp", 6 }, { "upgrade" } } },
    { label = "Move on", outcome = "Nothing",
      result = "Magtoor goes back to his hut.",
      effects = {} },
    -- carte neutre débloquée par la zone (§ 8)
    { label = "Ask for their dust", outcome = "Pay 25g, Dream Dust (card)",
      when = { { "unlocked", "dream_dust", hide = true } },
      result = "Magtoor fills a pouch with green dust. The Lost Ones gather it where the dragonkin sleep.",
      effects = { { "pay", 25 }, { "card", "dream_dust" } } },
  },
})

event("lost_one_cook", {
  name = "The Lost One Cook", act = 5, tier = 1,
  speaker = "Lost One Cook", npc = "lost_one_cook", scene = "sanctuary",
  text = "\"I cook what the swamp gives me. Today it is crocolisk. Sit and eat, or catch me a fresh "
    .. "Sawtooth and I will show you my recipes.\"",
  choices = {
    { label = "Eat with him", outcome = "+10 HP",
      result = "He fills your bowl twice.",
      effects = { { "heal", 10 } } },
    { label = "Catch a crocolisk for him", outcome = "-7 HP, one of 3 common cards",
      result = "The crocolisk bites you before you drag it to the pot. The cook keeps his word.",
      effects = { { "loseHp", 7 }, { "cardChoice", n = 3, rarity = "common" } } },
    { label = "Buy smoked meat for the road", outcome = "Pay 20g, a potion",
      result = "He wraps the meat in leaves and adds a flask of his broth.",
      effects = { { "pay", 20 }, { "potion" } } },
  },
})

event("temple_steps", {
  name = "The Temple Steps", act = 5, tier = 2,
  speaker = "Temple of Atal'Hakkar", npc = nil, scene = "temple",
  text = "A Green Scalebane and two Dreaming Whelps sleep on the steps of the Temple of Atal'Hakkar. "
    .. "An Atal'ai offering chest stands open between them.",
  choices = {
    { label = "Take from the chest quietly", outcome = "50%: a relic, else -10 HP",
      effects = { { "gamble", 0.5,
        win = { { "relic" } },
        winText = "You take an idol from the chest and walk back down the steps. The dragonkin do not move.",
        lose = { { "loseHp", 10 } },
        loseText = "A whelp wakes up and breathes on you. You drop the idol and run." } } },
    { label = "Attack the sleepers", outcome = "Fight 3 sleeping dragonkin: usual reward + 30g",
      result = "You choose which one to strike first.",
      effects = { { "fight", "event_dragonkin", gold = 30 } } },
    { label = "Go around the temple", outcome = "Nothing",
      result = "You take the long way through the water.",
      effects = {} },
  },
})

event("cortello_riddle", {
  name = "Cortello's Riddle", act = 5, tier = 1, rarity = "rare",
  speaker = "Cortello's Riddle", npc = nil, scene = "swamp",
  text = "In a dead adventurer's pack, you find a sealed scroll signed by Cortello. The riddle points to a "
    .. "cave in the hills of the swamp. Deathstrike tarantulas nest in that cave.",
  choices = {
    { label = "Search the cave", outcome = "-10 HP, a relic and 40g",
      result = "You find Cortello's chest behind the webs. The tarantulas bite you twice on the way out.",
      effects = { { "loseHp", 10 }, { "relic" }, { "gold", 40 } } },
    { label = "Sell the scroll in Stonard", outcome = "+50g",
      result = "A goblin trader in Stonard buys the scroll without reading it.",
      effects = { { "gold", 50 } } },
    { label = "Leave the scroll", outcome = "Nothing",
      result = "You put the scroll back in the pack.",
      effects = {} },
  },
})

event("misty_reed_strand", {
  name = "Misty Reed Strand", act = 5, tier = 2, rarity = "rare",
  speaker = "Stonard fisherman", npc = "stonard_fisherman", scene = "coast",
  -- Proposée seulement en bonne santé : la réponse principale est un combat d'élite.
  when = { { "hpAbove", 0.6 } },
  text = "\"A naga called Gilmorian came up from the sea and took the Misty Reed Strand. She drowned two "
    .. "of our fishermen. Stonard pays for her head.\"",
  choices = {
    { label = "Hunt Gilmorian", outcome = "Elite fight: elite reward + 40g",
      result = "Gilmorian rises from the water as you reach the strand.",
      effects = { { "fight", "event_gilmorian", kind = "elite", gold = 40 } } },
    { label = "Fish the north end of the strand", outcome = "-4 HP, a potion",
      result = "You fish out of her sight until dark. A fisherman trades you a potion for your catch.",
      effects = { { "loseHp", 4 }, { "potion" } } },
    { label = "Leave the strand", outcome = "Nothing",
      result = "The fisherman goes back to Stonard.",
      effects = {} },
  },
})
```

Paliers : 3 au palier 0, 3 au palier 1 (dont la rare), 2 au palier 2 (dont la rare). Chaque rencontre garde
une réponse sans condition ni coût. `event_dragonkin` pose Asleep 3 dans sa composition (§ 3).

## 7. Cartes de zone

Cartes définitives (épiques, pivots) : voir `docs/zones/cartes-de-zone.md`.

- Reflective Shield (Priest)
- Shield Charge (Warrior)
- Arcane Meditation (Mage)
- Subterfuge (Rogue)
- Master Marksman (Hunter)

## 8. Commun débloqué par la première victoire du compte

### Cartes neutres (2)

| Id | Nom (objet WoW) | Rareté | Coût | Type | Base | Améliorée | Icône | Où |
|---|---|---|---|---|---|---|---|---|
| `dream_dust` | Dream Dust (réactif d'enchantement) | uncommon | 1 | Skill, cible un ennemi | `Apply Asleep 2` / `Exhaust.` | coût 0 | `inv_enchant_dustdream` (132855) | marchand, rencontre `fallow_sanctuary` |
| `dreamless_sleep_potion` | Dreamless Sleep Potion (Alchemy) | common | 0 | Skill | `Heal 10.` / `End your turn.` / `Exhaust.` | `Heal 14.` | `inv_potion_22` (134802), à vérifier dans le jeu | marchand, rencontre `stonard_outpost` |

- **Dream Dust** porte Slumber dans toutes les zones : l'ennemi visé perd son intention et dort 2 tours ;
  le premier coup à une cible a le bonus, et un ennemi sans ouverture reprend son motif au réveil. Boss
  immunisés. Plus faible que Polymorph (2 mana, Stunned 2) parce que le moindre dégât le réveille, y compris
  les cartes à tous du joueur.
- **Dreamless Sleep Potion** : le soin le moins cher du jeu en mana, payé par la fin du tour (les cartes
  restantes sont défaussées).

### Bibelots communs (3)

| Id | Nom (objet WoW) | Rareté | Palier | Texte | Icône |
|---|---|---|---|---|---|
| `green_dragonscale` | Green Dragonscale (cuir des dragonkin verts) | common | 1 | `The first attack each enemy makes against you deals 3 less.` | `inv_misc_monsterscales_*` : couleur à vérifier dans le jeu (134303 à 237405) |
| `tender_crocolisk_meat` | Tender Crocolisk Meat | common | 1 | `After each elite combat won, heal 8 HP.` | `inv_misc_food_*` : à choisir dans le jeu |
| `atalai_artifact` | Atal'ai Artifact (quête de Fel'Zerul) | uncommon | 2 | `At the start of each combat, apply Sundered 1 to all enemies.` | `inv_misc_idol_03` (134232) |

Green Dragonscale sert partout (le premier coup de chaque ennemi) et dans le marais sur chaque ouverture.

### Type de rencontre : Sleeping Camp

Une rencontre où un groupe ennemi dort sur le chemin. Trois réponses : prendre ce qu'il garde en silence
(pari : bibelot ou or, sinon perte de PV), attaquer les dormeurs (combat `{ "fight", groupe, asleep = n }`,
chaque ennemi non boss commence Asleep n), ou contourner. Une fois débloqué, le type entre dans les autres
zones (une rencontre par zone, à écrire dans chaque fiche) avec un groupe de la zone : hors du marais, les
ennemis n'ont pas d'ouverture et reprennent leur motif au réveil, mais Rude Awakening s'applique. Exemple
dans cette fiche : `temple_steps`. Exemple pour Westfall : le Harvest Golem endormi de la rencontre du
coffre (`Data/Events.lua`, « The golem is still asleep »).

## 9. Bibelots de clé (+1, +3, +5)

Communs aux classes, `rarity = "rare"`, `noPool` sauf déblocage ; plus forts que les communs.

| Clé | Id | Nom (objet WoW) | Texte | Icône | Note |
|---|---|---|---|---|---|
| +1 | `chained_essence_of_eranikus` | Chained Essence of Eranikus (bijou, quête du Temple of Atal'Hakkar) | `The first time each enemy takes damage, it takes 4 more.` | `spell_nature_corrosivebreath` (136016) | Se cumule avec Rude Awakening (4 ajoutés avant le × 1,5). Ailleurs : +4 par ennemi et par combat. |
| +3 | `egg_of_hakkar` | Egg of Hakkar (objet de quête du Temple) | `Start of each combat: the non-boss enemy with the most HP gains Asleep 1.` | `inv_misc_shadowegg` (134430) | Un tour de préparation ou un coup à + 50 % sur le plus gros ennemi, élites compris. Dans le marais, s'ajoute au sommeil d'un dormeur. |
| +5 | `essence_of_eranikus` | Essence of Eranikus (objet de quête du Temple) | `Start of your turn: if an enemy is Asleep or Stunned, +1 mana.` | `inv_misc_gem_emerald_01` (134104), à vérifier | Récompense le contrôle partout (Frost Nova, Freezing Trap, Cheap Shot), et le sommeil ici. |

Egg of Hakkar n'est plus « la première incantation échoue » : Shrunken Head (Stranglethorn) a déjà ce
texte. Fist of the Damned (provenance non vérifiée) est retiré.

## 10. Modèles et icônes

`wow_creature_search` ne trouve toujours aucune installation (« No World of Warcraft install found ») ;
aucune synchronisation lancée. Identifiants de créature : base Questie de Classic Era (zone 8).
Affichages : caches de créatures des clients `_classic_` (build 45613), `_classic_era_`, `_forever_`,
`_anniversary_`, `_retail_`, lus par `tools/wdb_creatures.py` ; seuls ceux du tableau y figurent. Modèles :
`wow_model_search` (première version de la fiche).

| Unité | Créature | Affichage | Fichier modèle (FileDataID) | Icône de repli |
|---|---|---|---|---|
| Sawtooth Crocolisk | 1082 | non trouvé | `creature/crocodile/crocodile.m2` (123324) | `ability_hunter_pet_crocolisk` (132187) |
| Dreaming Whelp | 741 | non trouvé | `creature/dragonwhelp/dragonwhelp.m2` (123610) | `inv_misc_head_dragon_green` (134157) |
| Swampwalker | 764 | non trouvé | `creature/bogbeast/bogbeast.m2` (123105) | `spell_nature_stranglevines` (136100) |
| Green Scalebane | 744 | non trouvé | `creature/dragonspawn/dragonspawn.m2` (123543) | `inv_misc_head_dragon_green` (134157) |
| Wyrmkin Dreamwalker | 743 | non trouvé | `creature/dragonspawn/dragonspawn.m2` (123543) | `spell_nature_sleep` (136090) |
| Marsh Oracle | 752 | non trouvé | `creature/murloc/murloc.m2` (125024) | `inv_misc_head_murloc_01` (134169) |
| Deathstrike Tarantula | 769 | non trouvé | `creature/tarantula/tarantula.m2` (126124) | `ability_hunter_pet_spider` (132196) |
| Marsh Inkspewer | 750 | non trouvé | `creature/murloc/murloc.m2` (125024) | `inv_misc_head_murloc_01` (134169) |
| Lost One Hunter | 759 | non trouvé | `creature/lostone/lostone.m2` (124809) | `inv_spear_04` (135127) |
| Lost One Chieftain | 763 | 10921 | — | `inv_spear_08` (135131) |
| Lost One Muckdweller | 760 | non trouvé | `creature/lostone/lostone.m2` (124809) | `inv_misc_horn_01` (134227) |
| Lord Captain Wyrmak | 14445 | 7976 | — | `inv_misc_head_dragon_green` (134157) |
| Gilmorian | 14447 | 4920 | `creature/nagamale/nagamale.m2` (125078) si besoin | `inv_misc_nagamale` (1391617) |
| Somnus | 12900 | non trouvé | `creature/dragon/dragon.m2` (123459) | `inv_misc_head_dragon_green_nightmare` (1354172) |
| Dispatch Commander Ruag | 7623 | non trouvé | — | — |
| Fel'Zerul | 1443 | non trouvé | — | — |
| Galen Goodward | 5391 | non trouvé | — | — |
| Magtoor | 1776 (amical aux deux factions) | non trouvé | `creature/lostone/lostone.m2` (124809) | — |
| Lost One Cook | 1106 (rare dans le jeu, ici PNJ de rencontre) | 152 (suspect : affichage générique) | — | — |
| Stonard fisherman | personnage plausible, pas de créature | — | — | — |

Icônes de l'état et des intentions : Asleep `spell_nature_sleep` (136090) ; Alarm `inv_misc_horn_01`
(134227) ; Lull `spell_nature_sleep` (136090). Icônes des cartes et bibelots : § 8 et 9 ; toutes
confirmées par `wow_icon_search` sauf celles marquées « à vérifier » ou « à choisir ». Autres créatures
rares de la zone vues dans les caches, non retenues : Jade (1063, affichage 7975, dragonnet vert),
Fingat (14446, affichage 441), Molt Thorn (14448, affichage 14497). Itharius (5353, dragon vert amical)
pourrait parler dans une rencontre future.

## 11. Questions ouvertes

1. **Le bonus contre les gros coups.** Pyroblast (45), Aimed Shot avec Careful Aim (51) et Empyreal Blaze
   (54) tuent un Swampwalker ou un Green Scalebane endormi d'un seul coup, sans subir l'ouverture. Garder
   + 50 % sans plafond rend le Mage et le Hunter Marksmanship très à l'aise ici ; plafonner le bonus à
   + 12 garde l'intérêt du réveil pour toutes les classes mais retire le « tuer dans son sommeil ».
2. **Le familier et les dormeurs.** Version proposée : il ne réveille personne seul tant qu'un ennemi est
   éveillé. Autre version : il suit la dernière cible, dormeur compris ; le Hunter qui pose Serpent Sting
   sur un dormeur le réveillerait alors à la fin du même tour, sans l'avoir voulu.
3. **Asleep 2 ou 3.** À 3, un joueur qui tue d'abord les éveillés finit souvent le combat avant la
   première ouverture ; à 2, il la subit presque toujours. Le Swampwalker est à 3, les autres à 2 :
   la simulation dira si 6 à 9 PV perdus tiennent.
4. **Dream Dust hors du marais.** Sur une élite (Harvest Golem, Gruklash), elle donne deux tours sans coup
   et un coup à + 50 % pour 1 mana. La garder « non boss » seulement, ou l'interdire aussi aux élites, ce
   qui en fait une carte de combats normaux.
5. **Les orcs de Stonard** restent alliés (marchand, Ruag, Rartar, le pêcheur) : un joueur Horde ne combat
   pas ses propres gardes, mais la faune de la zone ne compte aucun orc. En faire des ennemis demande une
   version Alliance et une version Horde des rencontres.

## 12. Implémentation (nuit du 13 au 14/11/2026)

Fichiers : `Data/Zones/Swamp.lua` (ennemis, groupes, rencontres, commun, bibelots de clé, décors de la zone),
`Core/ZoneRules/swamp.lua` (Slumber), `UI/Art/Zones/swamp.lua` (modèles, icônes, vue, sept décors peints),
`Sim/zones/swamp.lua` (bot), `Sim/tests_zone_swamp.lua` (27 tests), `Sim/ui_zone_swamp.lua` (section « UZS » du
harnais). Planches : `build/snap/zone-swamp*.svg`, `build/snap/decor-swamp_*.svg`.

### La règle telle que codée

- Asleep (état d'ennemi, `ns.Statuses.asleep`, 4 au plus) : l'intention d'un dormeur est le move « asleep »
  (ajouté à la définition de l'ennemi au besoin, aucune action) ; son ouverture (`opener`, ou celle de Slumber) est
  annoncée en gris (« On waking: »). À son tour (crochet `enemyMove`) : soin de Slumber, compteur -1, réveil à 0 sans
  agir. Stunned : le moteur consomme le tour sans passer par `enemyMove`, le compteur gèle.
- Réveil (`ns.Swamp.wake`) par tout dégât qui ne tue pas (`onEnemyDamaged`, Absorb compris), le compteur ou Alarm.
  Coup à une cible pendant le tour du joueur (jeu, fin de tour) : l'ouverture devient l'intention tout de suite ; effet à tous,
  DoT, compteur, Alarm, ou réveil hors du tour du joueur : elle sera la
  prochaine (l'ennemi n'agit plus dans la phase en cours). Stunned sur une ouverture (y compris Freezing Trap qui
  arrête le tour pendant l'ouverture) : elle est annoncée de nouveau.
- Rude Awakening : `enemyDamageLast` ×1,5 arrondi au supérieur, coup à une cible (`src.single`), jamais un tic de DoT,
  après les ajouts des bibelots (Chained Essence +4 avant), avant l'Absorb.
- Slumber de Wyrmak et Somnus : `phases` (seuil à 50 %, cran sur la barre) dont les actions `dream` partent APRÈS
  l'effet qui a franchi le seuil (`onEffectEnd`, ou après le tour de l'ennemi qui agit) : le sommeil tombe après la
  carte entière.
- Hors du marais, les règles ne sont actives que pour un combat qui peut endormir (deck avec une carte qui pose
  Asleep, Egg of Hakkar, groupe ou rencontre avec Asleep) : Westfall reste identique à graine égale.

### Ce qui diffère de la fiche, et pourquoi

1. **Réveil doux par un effet à tous** (`Swamp.SOFT_ALL`) : un effet « to all » réveille sans bonus ET l'ouverture
   part au round suivant, comme un tic de DoT (la fiche la faisait partir dans le round). Mesuré après la fusion
   des épiques : le Warrior (Cleave, Whirlwind, Thunder Clap) tombait à 64 % quand les autres classes étaient à
   78-87 % ; avec le réveil doux, 67-78 % pour toutes (écart 12 points au lieu de 22). Le choix de la zone reste :
   coup à une cible = bonus + ouverture tout de suite ; effet à tous ou DoT = pas de bonus, un round de répit.
2. **Soin de Slumber réduit** : Wyrmak 6 par tour de sommeil (fiche : 12), Somnus 5 (fiche : 10) ; le soin punissait
   surtout les classes lentes (Warrior, Priest).
3. **Nombres** réglés par la simulation (la fiche visait Westfall × 1,48, mais le deck repart de zéro à chaque
   expédition : à ces chiffres, 4 à 10 % de victoire) : normaux ≈ PV × 0,94, coups × 0,76 ; élites PV × 1,04, coups
   × 0,83 ; Somnus 135 PV, coups × 0,83, ouvertures × 0,7. Tableau ci-dessous.
4. **Le familier ne réveille jamais seul** : l'attaque automatique vise un éveillé, et attend quand tous dorment
   (décision : « évite les dormeurs tant qu'un ennemi est éveillé »). Sans cela, Somnus se réveillait à la fin du
   tour 1 contre le Hunter (−8 points de victoire au boss). Les attaques commandées frappent la cible de la carte.
5. **Dreamless Sleep Potion** : « Lose all mana. » au lieu de « End your turn. » (aucun effet ne termine le tour
   depuis une carte sans toucher au moteur et aux bots).
6. **Lull pendant la phase ennemie** : un ennemi rendormi avant son tour dans la même phase y passe déjà un tour de
   sommeil (« Skips its next 2 turns ») ; le soin de 8 est immédiat.
7. **Sleeping Camp** (`temple_steps`) : Asleep 3 posé par la rencontre (`{ "fight", "event_dragonkin", st =
   { asleep = 3 } }`), pas dans la composition du groupe (le test commun des groupes ne lit que des ids).
8. **Egg of Hakkar** : « the enemy with the most HP, bosses excepted » (le harnais U29 lit « non-boss » comme du
   français). **Scènes des rencontres** : noms communs (`road`, `camp`, `shop`, `hill`, `mine`, `coast`) remplacés
   par ceux de la zone.
9. **Rencontres sans personnage** : `temple_steps` montre le Green Scalebane endormi, `cortello_riddle` une
   Deathstrike Tarantula (le harnais demande trois candidats de modèle par rencontre).
10. **Bot** : la vue courte est la bonne stratégie de base (un dormeur ne frappe pas ; tuer les éveillés, puis tuer
    le dormeur réveillé par son compteur avant son ouverture). Compter d'avance les ouvertures (0,6 × leurs dégâts)
    faisait réveiller trop tôt : 91 % → 71 % (Rogue). Le bot garde la clé (compteurs, ouvertures en attente) et le
    soin de Slumber à venir.
11. Non fourni (lot d'interface commun) : l'aperçu « 33 Wake » / « Wakes » au survol d'une carte (aucun aperçu de
    dégâts dans l'écran de combat). À la place : infobulle du dormeur (tours, réveil fort ou doux, Rude Awakening,
    ouverture et ses chiffres), petite icône d'ouverture à droite d'une ouverture annoncée, pastilles « +6 » (soin de
    Slumber) et « Lulled » sous la bulle, bulles « Wakes 2 » (Alarm) et « +8 » (Lull, « - » sans cible), bulle
    « Waking » d'un ennemi réveillé qui n'agit pas ce round.

### Nombres finaux

| Ennemi | PV | Coups |
|---|---|---|
| Sawtooth Crocolisk | 37–42, Asleep 2 | Death Roll 20 · Snap 10 · Submerge block 7 |
| Dreaming Whelp | 15–16, Asleep 2 | Dream Breath 10 · Bite 4 |
| Swampwalker | 45–49, Asleep 3 | Bog Crush 22 (interrompt) · Vine Lash 7 · Bog Shield 6 + 6 au plus blessé |
| Green Scalebane | 42–45, Asleep 2 | Cleave 23 · Strike 10 · Scale Guard block 10, Strength 1 |
| Wyrmkin Dreamwalker | 28–31 | Lull (Asleep 2, soin 8) · Dream Bolt 4 +3 par dormeur (+9 au plus) |
| Marsh Oracle | 23–25 | Alarm Cry · Lightning Bolt 7 |
| Deathstrike Tarantula | 28–31 | Venomous Bite 5 + DoT 3 · Web 4 + Demoralized 1 |
| Marsh Inkspewer | 15–17 | Claw 4 · Ink Spit 3 + Sundered 1 |
| Lost One Hunter | 30–33 | Spear Thrust 10 · Net 4 + Demoralized 1 |
| Lost One Chieftain (élite) | 108, Asleep 2 | Spear of the Lost 24 · Thrust 13 · Rally block 8 + Strength 2 · Crushing Blow 7 + Sundered 1 |
| Lost One Muckdweller (serviteur) | 21–23 | Warning Horn (Alarm) · Stab 5 |
| Lord Captain Wyrmak (élite) | 116 | Cleave 15 · Tail Sweep 7 + block 8 · Wing Buffet 10 + Demoralized ; à 58 : Slumber 2, soin 6, Dream Fury 14 × 2 |
| Gilmorian (élite) | 108 | Lightning Bolt 20 (Cast) · Frost Shock 6 + Demoralized · Healing Wave 20 (Cast) |
| Somnus (boss) | 135, Asleep 2 | Bellowing Roar 16 + Demoralized ; Noxious Breath 6 × 2 + DoT 3 · Claw 20 · Wing Buffet 10 + block 10 ; à 67 : 2 dragonnets (14 PV, Bite 4), Slumber 2, soin 5, Deep Breath 10 × 2, puis Claw 21 · Breath 7 × 2 + DoT 3 · Buffet |

### Mesures (14/11/2026, après la fusion des épiques ; 400 expéditions par classe et par colonne,
`runner=expedition key=0 zone=swamp zones=4 level=7`, avec `epic=none` et sans `epic=` : le bot choisit une épique)

| Classe | Victoire sans épique | Victoire avec épique | PV perdus / normal (avec) | Tours / normal (avec) | Boss avec épique : victoire, tours, PV perdus |
|---|---|---|---|---|---|
| Priest | 75,0 % | 71,2 % | 13,9 | 4,21 | 78,7 %, 6,73, 35,9 |
| Warrior | 61,5 % | 67,5 % | 12,5 | 3,42 | 80,6 %, 6,18, 35,3 |
| Mage | 55,0 % | 78,0 % | 6,0 | 3,35 | 83,0 %, 5,03, 22,5 |
| Rogue | 52,5 % | 65,8 % | 10,1 | 3,49 | 87,1 %, 5,32, 18,3 |
| Hunter | 53,5 % | 74,5 % | 5,7 | 2,81 | 78,2 %, 5,86, 27,3 |

Écart : avec épique 65,8 à 78,0 % (12 points) ; sans épique 52,5 à 61,5 % pour quatre classes, Priest 75 % (il est
aussi le plus haut en Westfall sans épique : 81 % contre 70,5 % au Rogue). Combats normaux un peu chers pour Priest
et Warrior (12 à 14 PV, pour 36 et 74 PV max), un peu longs pour le Priest sans épique (4,9 tours).
Clés (Rogue avec épique) : +0 65,8 %, +1 58,8 %, +3 49,8 %, +5 43,0 % (−7, puis −4,5 et −3,4 par niveau ; affixes
communs). Statistiques de zone : `reports/final.txt` (avant la fusion : 0,55 ouverture subie par combat normal,
0,45 dormeur tué avant son ouverture, 0,44 Rude Awakening, 0,32 Alarm).

### Modèles en repli

Aucune créature du marais dans les caches des clients (Forever, Classic Era, Classic, Anniversary, Retail) sauf
Lost One Chieftain (10921), Wyrmak (7976), Gilmorian (4920), Lost One Cook (152) : chaque entrée garde la créature
de la fiche en tête, puis des affichages de la même famille (commentés dans `UI/Art/Zones/swamp.lua`) : crocolisks
des Wetlands et du Loch Modan, Jade (7975) pour les dragonnets, Timberling Mire Beast (863) pour le Swampwalker,
Wyrmak et Flamescale Wyrmkin pour les dragonkin, murlocs de la Marche, tarentules, Lost One Refugee, Sleeping Dragon
(8574) puis Veridian Netherwing Drake pour Somnus, Orc Refugee pour Ruag et le pêcheur, Witherbark Troll pour
Fel'Zerul, fermiers de la Marche pour Galen. À vérifier en jeu (`/slay models`).

### Décors

Sept décors peints (`swamp_road`, `swamp_night`, `swamp_camp` Fallow Sanctuary, `swamp_shop` Stonard,
`swamp_temple` marches du temple = « hill », `swamp_pool` boss, `swamp_strand` côte) : ciel gris-vert voilé,
lisière sombre de saules sur l'horizon, brume, mares à reflets, arbres morts à mousse pendante, roseaux et massettes
au premier plan, huttes des Lost Ones, huttes et tour de guet orques, temple englouti à gradins moussus.
Formes propres au marais peintes par le plan `layers.ground` de la zone (`S.paintKit`), sans rien ajouter à
`UI/Scene.lua` ; scènes des rencontres par les noms communs (`road`, `camp`, `shop`, `hill`, `mine`, `coast`), que
`ns.Zones.swamp.scenes` remplace.
