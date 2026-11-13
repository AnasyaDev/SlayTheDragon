# Wetlands — fiche de conception de zone (zone 3)

Zone 3 de la campagne (`wetlands`), après Duskwood, avant Stranglethorn Vale. Difficulté visée :
Westfall + 24 % (PV et dégâts des ennemis), à régler par simulation. Référence de puissance :
`Data/Act1.lua` (Westfall). Fiche de conception seulement : rien n'est codé.

Sources des noms : quêtes et créatures lues dans le cache du client Forever
(`_forever_/Cache/WDB/enUS/creaturecache.wdb` par `tools/wdb_creatures.py`, `questcache.wdb`), le MCP wow
n'ayant pas trouvé d'installation (`wow_creature_search` : « No World of Warcraft install found »).
Identifiants notés « créature / affichage » ; « non trouvé » quand le cache ne connaît pas la créature.

## 1. La zone en trois lignes

- **Lieux (fonds de scène)** : route : la chaussée des marais entre Menethil Harbor et Dun Modr ;
  camp : Angerfang Encampment (Dragonmaw) ; marchand et feu de camp : Menethil Harbor, la Deepwater
  Tavern ; élites : Whelgar's Excavation Site (raptors), les ruines de Dun Modr ; boss : les Dragonmaw
  Gates, devant Grim Batol.
- **Ambiance factuelle** : marais, pluie, eau jusqu'aux genoux ; les nains de Menethil tiennent le port,
  les Dragonmaw ont repris leur camp au nord-est, les fouilles de Whelgar sont envahies par les raptors.
- **Ce qui change pour le joueur** : les ennemis viennent en meutes qui se renforcent quand l'une des leurs
  tombe ; l'ordre des morts compte.

Décors à prévoir (`scene`) : `coast` (port de Menethil), `road` (chaussée), `camp` (Angerfang), `mine`
(fouilles de Whelgar), `ruins` (Dun Modr). Les cinq existent déjà comme valeurs ; il faut leurs fonds
propres aux Wetlands.

## 2. La mécanique de la zone : Pack

### Règle

1. **Pack.** Certains ennemis portent le mot-clé Pack et une **prime de meute** écrite sous leur barre de
   vie : `Pack: +2 Strength`, `Pack: heal 8` ou `Pack: +4 Absorb`. Les ennemis Pack d'un même combat
   forment une meute. Les autres ennemis (crocolisk, limon) n'en font jamais partie.
2. **Mort d'un ennemi Pack.** Quand il meurt, chaque autre ennemi Pack **vivant** reçoit sa prime :
   - `+N Strength` : Strength N, permanente pour le combat ;
   - `heal N` : soigne N PV (sans dépasser le maximum : un ennemi intact ne gagne rien) ;
   - `+N Absorb` : N Absorb, qui suit la règle habituelle des ennemis (perdue au début de son prochain tour).
3. **Primes groupées par effet.** Les primes ne se donnent qu'**une fois l'effet en cours terminé**. Un
   effet = la résolution d'une carte (toutes ses lignes, Cast compris quand il se résout), le déclenchement
   d'une Trap, une attaque du familier hors carte (celle de fin de tour), le DoT d'une unité, une potion,
   un bibelot. Tout ce qui se déclenche **pendant** cet effet (Aspect of the Pack, Crude Flint, une
   riposte) en fait partie. Un ennemi tué par le même effet ne reçoit rien ; sa prime va aux survivants.
   Si plusieurs ennemis Pack meurent du même effet, toutes leurs primes sont données, de gauche à droite.
4. **Chef de meute (Pack Leader).** Un ennemi Pack peut être chef. Il n'a pas de prime. Quand il meurt,
   la meute **se disperse** : les primes de cet effet sont annulées, chaque survivant devient `Scattered`
   (il perd Pack : ne donne ni ne reçoit plus de prime) et prend `Demoralized 1 ⌛`. Un ennemi Pack
   invoqué après la dispersion arrive `Scattered`.
5. **Invocations.** Un ennemi Pack invoqué en cours de combat rejoint la meute (il reçoit les primes
   suivantes et donnera la sienne).

### Ce que voit le joueur

- Sous chaque ennemi Pack : une patte et sa prime (`+2 Str`, `+8 HP`, `+4 Abs`) ; le chef porte une
  couronne à la place de la prime ; un ennemi `Scattered` a la patte grisée.
- Au survol d'une carte qui tuerait un ou plusieurs ennemis (dégâts prévus ≥ PV + Absorb), les survivants
  montrent en aperçu les primes qu'ils recevraient (ou « Scatter » si le chef tombe).
- Journal : `{ t = "pack", src = uid du mort, dst = uid, bonus = … }`, `{ t = "scatter", by = uid }`.

### Infobulles (anglais)

| Terme | Infobulle |
|---|---|
| Pack | `When it dies, the rest of its pack gains this. Packmates killed by the same card gain nothing.` |
| Pack Leader | `When it dies, its pack scatters: no more Pack bonuses, and the others are Demoralized.` |
| Scattered | `No longer part of a pack.` |

### Interactions

| Règle | Comportement |
|---|---|
| Absorb (joueur) | Aucune. L'Absorb donnée par une prime aux ennemis encaisse les coups jusqu'au début du prochain tour de cet ennemi : reçue pendant le tour du joueur, elle protège le reste de ce tour ; reçue pendant la phase ennemie par un ennemi qui n'a pas encore agi, elle est perdue à son tour. |
| Stunned | Un ennemi étourdi reçoit les primes. Étourdir ne retarde pas une prime. Le chef étourdi qui meurt disperse la meute. |
| Cast / interruption | Une prime n'interrompt rien et ne change pas l'intention. Un Cast du joueur qui se résout au début du tour est un seul effet : un Cast de zone (Halo, Volley, Flamestrike…) tue « en même temps ». Une incantation ennemie (Lightning Bolt du Mosshide Mystic) partira avec la Strength reçue entre-temps. |
| Traps | Une Trap qui tue pendant la phase ennemie est un effet : les primes tombent tout de suite, et les ennemis qui n'ont pas encore agi frappent avec la Strength reçue. Explosive Trap qui tue deux ennemis : ils ne s'en donnent rien entre eux. |
| Parry | Une charge de Parry annule un coup jusqu'à 8. Les primes de Strength font passer des coups au-dessus de 8 : le Rogue a intérêt à tuer les donneurs de Strength en dernier ou ensemble. |
| DoT | Chaque DoT se déclenche au début du tour de son porteur : une mort par DoT est toujours un effet isolé, jamais « en même temps » qu'une autre. Le DoT ignore l'Absorb reçue en prime. |
| Execute / Careful Aim | Une prime `heal` peut faire repasser une cible au-dessus de la moitié de ses PV (Execute perdu, Careful Aim regagné). |
| Familier du Hunter | Une attaque commandée par une carte fait partie de l'effet de la carte ; l'attaque automatique de fin de tour est un effet à part, résolu avant la phase ennemie (les primes tombent avant que les ennemis agissent). |
| Victoire | Quand le dernier ennemi principal meurt, le combat s'arrête ; les primes en attente sont perdues. |

### Les décisions que la règle crée

- **Qui tuer en premier** : la prime est visible avant le coup. Tuer d'abord le donneur de Strength (les
  autres en profitent longtemps) ou d'abord le soigneur (sa prime soigne les blessés) ?
- **Répartir ou concentrer** : une prime `heal` sur des ennemis intacts est perdue. Tuer le Mosshide Mystic
  avant d'avoir blessé les autres annule son soin ; l'achever après une carte de zone le rend plein.
- **Tuer ensemble** : amener deux ou trois ennemis sous le seuil, puis une carte de zone les tue dans le
  même effet, sans prime.
- **Le chef d'abord ou en dernier** : le Mosshide Alpha est le plus résistant et protège les autres ; le
  tuer d'abord disperse la meute (plus aucune prime, tout le monde Demoralized) ; le garder pour la fin
  le laisse ramasser les primes.

### Réponse de chaque classe

| Classe | Réponses déjà présentes | Carte de zone |
|---|---|---|
| Priest | Zone en un effet : Holy Nova, Halo (Cast) ; Psychic Scream (Demoralized à tous) contre une meute gonflée de Strength ; Penance pour finir une cible. Mind Sear pose du DoT, donc des morts isolées. | Mass Dispel |
| Warrior | Cleave, Thunder Clap, Whirlwind, Bladestorm ; Execute pour finir un blessé ; Demoralizing Shout. | Shockwave |
| Mage | Arcane Explosion, Cone of Cold, Blizzard et Flamestrike (Cast), Arcane Barrage ; Frost Nova (Stunned à tous). | Spellsteal |
| Rogue | Fan of Knives, Blade Flurry, Secret Technique (Surge à tous), Killing Spree ; Smoke Bomb (Demoralized à tous) ; gros coup de grâce sur le chef. | Marked for Death |
| Hunter | Multi-Shot, Volley (Cast), Explosive Trap, Wailing Arrow ; Frost Trap ; le familier choisit sa cible. | Aspect of the Pack |

Aucune classe n'est sans réponse : chacune a au moins trois cartes de zone en un seul effet, une carte
qui réduit les dégâts de toute la meute, et un coup fort sur une cible.

### Ce que le moteur doit apprendre

Ce que `Data/Act1.lua` sait déjà faire et qui sert ici : `onDeath`, `onAllyDeath`, `onDamaged` (phases),
`buff_allies`, `heal_ally`, `summon`, Cast ennemi interruptible, `minion`, `Combat.spawn`.

1. **Champs d'ennemi** : `pack = { "force"|"heal"|"absorb", n }`, `packLeader = true`. État d'unité
   `scattered` (drapeau dans `e.st`, sauvegardable).
2. **File des primes** : `Combat.kill` d'un ennemi Pack ajoute sa prime (ou la dispersion) à
   `c.packQueue` au lieu de l'appliquer ; une fonction `Combat.settlePack(c)` vide la file à la fin de
   chaque effet : après `resolveCard` (jeu d'une carte et Cast résolu), `triggerTrap`, l'attaque
   automatique du familier, `tickPeriodic` d'une unité, une potion, un crochet de bibelot hors carte.
   Dispersion dans la file : annule toutes les primes de la file.
3. **Actions ennemies** : `{ "block_allies", n }` (tous les ennemis vivants, soi compris) ;
   `{ "block_boss", n }` (Absorb sur le boss du combat). Note : un ennemi efface son Absorb au début de son
   tour ; les donneurs d'Absorb doivent agir **après** ceux qu'ils protègent (placés à droite dans les
   compositions ci-dessous).
4. **Crochets d'élite** : coup subi annulé (Ma'ruk : `beforeDamaged` d'ennemi, premier coup par tour) ;
   PV perdus depuis son dernier tour (Modr : `e.mem.lost`, remis à 0 au début de son tour).
5. **Effets de carte** : retirer Absorb et Strength (`strip`, `all = true`), voler (`steal` : retirer et
   gagner), retirer Pack (`unpack`), marque de mort du tour (`marked`, lue par `settlePack`), `Execute`
   évalué par cible sur une carte « to all », crochet `onEnemyDeath` qui fait attaquer le familier dans
   l'effet en cours.
6. **Interface** : ligne de prime sous la barre de vie, couronne, patte grisée, aperçu au survol, petite
   animation de prime (flèche du mort vers chaque survivant, ≤ 0,3 s).
7. **Bots** : la valeur d'une mort retranche la prime reçue par les survivants (Strength × tours restants
   × coups par tour ; soin utile seulement) ; bonus aux morts groupées ; chef d'abord si la meute compte
   ≥ 2 primes de Strength.
8. **Statistiques** : primes données par type, soins de prime perdus (cible pleine), morts groupées,
   dispersions, ordre de mort du chef.

## 3. Ennemis normaux (9)

Repères Westfall × 1,24 : Riverpaw Gnoll 19–22 PV / 8 → 24–27 / 10 ; murloc 10–12 / 4 → 12–15 / 5 ;
Defias Conjurer 18–21 / Cast 16 → 22–26 / 20. Les ennemis Pack ont environ 10 % de PV en moins que ce
repère : leur prime compte comme des PV en plus.

| id | Nom | Créature / affichage | PV | Pack | Intentions | Motif | Rôle |
|---|---|---|---|---|---|---|---|
| `bluegill_raider` | Bluegill Raider | 1418 / 391 | 13–15 | +4 Absorb | **Spear Jab** (attack) : 6. **Muck Toss** (debuff) : 3, puis Demoralized 1 ⌛ sur le joueur. | jab, muck ; départ au hasard | Nombre. Chaque mort protège les autres pour le reste du tour : pousse à les tuer ensemble. |
| `mosshide_brute` | Mosshide Brute | 1012 / 3196 | 23–26 | +1 Strength | **Club** (attack) : 10. **Knockdown** (attack) : 6, interrompt. | club, knockdown ; départ au hasard | Frappeur de base des gnolls Mosshide. |
| `mosshide_mystic` | Mosshide Mystic | 1013 / 714 | 18–20 | heal 8 | **Healing Wave** (heal) : soigne 9 l'allié le plus blessé. **Lightning Bolt** (cast) : 12. | IA : Healing Wave si un allié a perdu ≥ 9 PV et que le tour d'avant n'était pas un soin ; sinon Lightning Bolt | Soigneur qui incante (le Riverpaw Mystic guettait les incantations du joueur ; celui-ci incante lui-même). Sa prime rend le tuer en dernier coûteux. |
| `mosshide_alpha` | Mosshide Alpha | 1014 / 543 | 28–31 | **Pack Leader** | **Rally** (defend) : 5 Absorb à tous les ennemis. **Maul** (attack) : 12. **Savage Howl** (buff) : Strength 1 à tous les ennemis. | rally, maul, howl (dans l'ordre) | Chef. Le tuer d'abord disperse la meute ; le laisser grossir coûte cher au 3e tour. Toujours à droite du groupe (son Rally doit tenir). |
| `mottled_screecher` | Mottled Screecher | 1021 / 677 | 15–17 | +1 Strength | **Screech** (cast, summon) : appelle un Mottled Raptor. **Claw** (attack) : 4 deux fois. | screech, claw, claw (dans l'ordre) | Invocateur : l'interrompre au tour 1 ou le tuer, sachant que sa mort renforce les raptors. |
| `mottled_raptor` | Mottled Raptor | 1020 / 960 | 16–18 | +1 Strength | **Rake** (attack) : 4 deux fois. **Lunge** (attack) : 9. | rake, lunge ; départ au hasard | Meute de raptors ; arrive aussi par Screech. |
| `dragonmaw_raider` | Dragonmaw Raider | 1034 / 4916 | 27–30 | +2 Strength | **Shield Bash** (attack) : 6, interrompt. **Heavy Strike** (attack) : 14. | bash, strike ; départ au hasard | Orc lourd : sa prime est la plus forte ; deux Raiders = le premier tué rend l'autre dangereux. |
| `wetlands_crocolisk` | Wetlands Crocolisk | 1400 / 1036 | 36–40 | — (seul) | **Snap** (attack) : 11. **Submerge** (defend) : 14 Absorb. **Death Roll** (attack) : 6 trois fois. | snap, submerge, roll ; départ au hasard | Le solitaire : ne donne ni ne reçoit de prime. Avec des Bluegills, il les laisse se renforcer sans en profiter. |
| `black_ooze` | Black Ooze | 1032 / 767 | 24–27 | — (seul) | **Corrosive Acid** (debuff) : 6, puis Sundered 1 ⌛ sur le joueur. **Ooze Slam** (attack) : 10. À sa mort : invoque 2 Black Slime. | acid, slam | Limon : le tuer en fait deux petits ; une carte de zone garde sa valeur après la mort. |

Invocation hors compte (comme le Defias Henchman) : `black_slime` **Black Slime** (1030 / 360), 7–8 PV,
pas Pack, pas minion : **Slime Bolt** (attack) : 4.

Élémentaires : le Fen Creeper (1040 / 2023, quête « Blisters on the Land ») n'a pas de place dans les
neuf ; la faune élémentaire est portée par l'élite Modr. Autres créatures vues dans le cache et non
retenues : Mosshide Gnoll, Mongrel, Trapper, Mistweaver, Fenrunner ; Bluegill Murloc, Puddlejumper,
Forager, Muckdweller ; Young et Giant Wetlands Crocolisk ; Crimson Ooze, Monstrous Ooze ; Dragonmaw
Swamprunner, Centurion, Shadowwarder.

Différences avec Westfall : les Bluegills donnent de l'Absorb à toute la meute (le Murloc Coastrunner se
donnait de la Strength à lui-même, seulement à la mort d'un murloc) et affaiblissent le joueur ; les
Mosshide ont un chef et un soigneur qui incante, les Riverpaw n'ont ni l'un ni l'autre.

### Groupes types

| Liste | Composition (de gauche à droite) | PV totaux (moy.) | Idée |
|---|---|---|---|
| easy | Bluegill Raider ×3 | 42 | Tuer ensemble ou subir 4 Absorb par mort |
| easy | Mottled Screecher, Mottled Raptor | 33 + invocations | Interrompre Screech |
| easy | Wetlands Crocolisk | 38 | Combat sans meute |
| easy | Black Ooze | 26 + 15 | Garder une carte de zone pour les slimes |
| normal | Mosshide Brute, Mosshide Mystic, Mosshide Alpha | 74 | Le chef d'abord ? |
| normal | Mosshide Brute ×2, Mosshide Mystic | 69 | Le soigneur sans chef : le tuer avant de blesser les autres |
| normal | Bluegill Raider ×2, Wetlands Crocolisk | 66 | Le solitaire au milieu de la meute |
| normal | Mottled Screecher, Mottled Raptor ×2 | 50 + invocations | Les raptors se renforcent à chaque mort |
| normal | Dragonmaw Raider ×2 | 57 | +2 Strength : les tuer ensemble |
| normal | Dragonmaw Raider, Black Ooze | 54 + 15 | Une meute de un : pas de prime, le limon d'abord |

Combats de rencontre : `event_crocolisk` (Wetlands Crocolisk, Bluegill Raider), `event_raptors`
(Mottled Screecher, Mottled Raptor ×2), `event_mosshide` (Mosshide Brute, Mosshide Mystic, Mosshide
Alpha), `event_dragonmaw` (Dragonmaw Raider ×2), `event_ooze` (Black Ooze ×2).

## 4. Élites (3)

Repère Westfall : 72–75 PV, coups de 18–19 et 8 × 3 ; × 1,24 ≈ 90 PV, coups de 23.

| id | Nom | Créature / affichage | PV | Idée de combat |
|---|---|---|---|---|
| `sarltooth` | Sarltooth | non trouvé (cible de la quête « Ormer's Revenge », Whelgar Excavation Site, lue dans le cache des quêtes) | 80 | **L'alpha qui grossit.** Il appelle des raptors ; chacun qui meurt le renforce. |
| `modr` | Modr | 271460 / 473 (échelle 2) — golem de Dun Modr, contenu Forever (quête « Gleaning Our Future ») | 90 | **Le test de rafale.** S'il ne perd pas assez de PV dans un tour, il charge un coup énorme. |
| `maruk_wyrmscale` | Ma'ruk Wyrmscale | non trouvé (rare Dragonmaw de Classic, nom de mémoire, absent des caches) | 74 + escorte | **L'armure qui avale le premier coup.** Ouvrir avec un petit coup, puis frapper fort. |

**Sarltooth** (Pack sans prime ; commence avec 1 Mottled Scytheclaw).
- **Call the Pack** (summon) : appelle 1 Mottled Scytheclaw.
- **Rend** (attack) : 8, puis DoT 4 sur le joueur.
- **Leap** (attack) : 20, interrompt.
- Motif : call, rend, leap.
- Escorte `mottled_scytheclaw` **Mottled Scytheclaw** (1022 / 648) : minion, Pack +2 Strength, 14–16 PV,
  **Slash** (attack) : 7. Quand Sarltooth meurt, les Scytheclaws s'enfuient (minions).
- Décision : chaque Scytheclaw tué donne +2 Strength à Sarltooth (Leap à 22, puis 24…). Les ignorer coûte
  7 par Scytheclaw et par tour ; les tuer le renforce. Le tuer vite, ou tuer un Scytheclaw en même temps
  que le coup qui l'achève.

**Modr** (pas Pack).
- **Earthen Charge** (passif, affiché comme un état empilé, 3 au plus) : au début de son tour, après son
  DoT, s'il a perdu moins de 15 PV depuis son tour précédent, il gagne 1 Charge.
- **Stone Fist** (attack) : 12.
- **Seismic Slam** (attack) : 6 + 8 par Charge, interrompt ; les Charges retombent à 0.
- Motif : fist, fist, slam. Slam à 0 Charge : 6 ; à 3 : 30.
- Décision : chaque tour, mettre 15 dégâts dans Modr ou se préparer à encaisser 30. Le DoT compte (il est
  pris en compte avant le test) : une voie DoT l'empêche de charger sans tout jouer en attaque.

**Ma'ruk Wyrmscale** (Pack ; combat avec 1 Dragonmaw Raider, à gauche).
- **Wyrmscale Armor** (passif) : le premier coup qu'il subit après le début de chaque tour du joueur
  n'inflige aucun dégât (icône d'écaille quand elle est prête). Le DoT n'est pas un coup ; un coup de Trap
  ou du familier en est un.
- **Shield Bash** (attack) : 7, interrompt.
- **Cleave** (attack) : 9 deux fois.
- **Demoralizing Shout** (debuff) : 5, puis Demoralized 2 ⌛ sur le joueur.
- Motif : bash, cleave, shout.
- Décision : quel coup « gâcher » (une attaque à 0 mana, le familier, un coup d'une attaque multiple)
  avant le gros coup ; tuer le Raider lui donne +2 Strength.

## 5. Boss : Chieftain Nek'rosh

`nekrosh`, **Chieftain Nek'rosh**, 2091 / 4915 — chef Dragonmaw de la quête « Defeat Nek'rosh » (Captain
Stoutfist, Menethil Keep), lue dans le cache des quêtes. Boss, Pack (sans prime), 98 PV.
Composition : Nek'rosh, Dragonmaw Bonewarder, Dragonmaw Bonewarder (les Bonewarders à droite : leur
Absorb doit tenir après le tour du boss).

**Escorte** : `dragonmaw_bonewarder` **Dragonmaw Bonewarder** (1057 / 4918), minion, Pack **heal 10**,
15–17 PV. **Bone Ward** (defend) : 8 Absorb sur Nek'rosh. **Shadow Bolt** (attack) : 7. Motif : ward,
bolt ; départ au hasard (les deux ne protègent pas le même tour).

**Phase 1 (98 → 50 PV).**
- **Cleave** (attack) : 11 deux fois.
- **Clan Command** (buff) : Strength 1 à tous les ennemis ; Nek'rosh gagne 10 Absorb.
- **Sunder Armor** (attack) : 16, puis Sundered 2 ⌛ sur le joueur.
- Motif : cleave, command, sunder.
- Décision : chaque Bonewarder tué soigne Nek'rosh de 10. Les tuer au tour 1–2, quand Nek'rosh est
  intact, rend leur prime nulle ; plus tard, elle lui rend 10 PV. Les ignorer laisse 8 Absorb par tour
  sur le boss.

**Phase 2 (sous 50 %, une fois, déclenchée par `onDamaged`).** Il crie `"Whelps! Burn them!"`, invoque
2 `crimson_whelp` **Crimson Whelp** (1069 / 505 ; minions, pas Pack, 12–14 PV, **Fire Breath** (attack) :
6) et change de motif : shadow_bolt, cleave, sunder.
- **Shadow Bolt** (cast) : 28. Les sorts du Shadow Council (quête Forever « Old Habits » : le livre de
  sorts brûlé de Nek'rosh).
- Les Interrupts de chaque classe y répondent ; un Shadow Bolt qui passe, plus les whelps, est la menace
  de la phase.

**Durée visée** : dégâts du joueur ≈ 22 par tour. Phase 1 : 49 PV + ≈ 16 d'Absorb (Bone Ward, Clan
Command) ≈ 3 tours ; phase 2 : 49 PV + 10 d'Absorb ≈ 2,5 tours, plus les whelps : **5,5 à 6,5 tours**.
Dégâts subis ≈ 18 par tour (Westfall × 1,24 ≈ 17).

## 6. Rencontres (8)

Format de `Data/Events.lua`, `act = 3`. Combats : groupes `event_*` de la section 3.

```lua
event("halloran_skins", {
  name = "The Tanner's Order", act = 3, tier = 0,
  speaker = "James Halloran", npc = "james_halloran", scene = "coast",
  text = "\"I'm James Halloran, the tanner. My apprentice went out for giant crocolisk skins and the "
    .. "crocolisks got him first. Bring me a skin and I'll pay you for it.\"",
  choices = {
    { label = "Hunt a crocolisk", outcome = "Fight: usual reward + 25g",
      result = "You wade into the marsh after a crocolisk.",
      effects = { { "fight", "event_crocolisk", gold = 25 } } },
    { label = "Scrape hides for him", outcome = "-4 HP, +20g",
      result = "You scrape hides until evening. Halloran pays you for the day.",
      effects = { { "loseHp", 4 }, { "gold", 20 } } },
    { label = "Leave", outcome = "Nothing",
      result = "Halloran goes back to his hides.",
      effects = {} },
    -- carte neutre débloquée par la zone
    { label = "Buy his crocolisk gumbo", outcome = "Pay 25g, Crocolisk Gumbo (card)",
      when = { { "unlocked", "crocolisk_gumbo", hide = true } },
      result = "\"My wife makes it with the tail meat. Eat it hot.\"",
      effects = { { "pay", 25 }, { "card", "crocolisk_gumbo" } } },
  },
})

event("ormers_revenge", {
  name = "Ormer's Revenge", act = 3, tier = 0,
  speaker = "Ormer Ironbraid", npc = "ormer_ironbraid", scene = "mine",
  text = "\"The raptors killed my brethren and trapped me, Merrin and the Prospector up here. "
    .. "Clear them out of the dig, or help me get the others down to the road.\"",
  choices = {
    { label = "Clear the dig site", outcome = "Fight 3 raptors: usual reward + 20g",
      result = "You go down into the dig site.",
      effects = { { "fight", "event_raptors", gold = 20 } } },
    { label = "Lead the survivors out", outcome = "-6 HP, upgrade a card of your choice",
      result = "You carry the Prospector down to the road. Ormer shows you how the diggers fight.",
      effects = { { "loseHp", 6 }, { "upgrade" } } },
    { label = "Leave", outcome = "Nothing",
      result = "Ormer stays behind the barricade.",
      effects = {} },
  },
})

event("greenwarden", {
  name = "The Greenwarden", act = 3, tier = 0,
  speaker = "Rethiel the Greenwarden", npc = "rethiel", scene = "road",
  text = "\"The Mosshide gnolls cut the trees of the Wetlands to feed their fires. Take their "
    .. "flints from them. If you are only passing through, I can tend your wounds.\"",
  choices = {
    { label = "Raid the Mosshide camp", outcome = "Fight 3 gnolls: usual reward + 30g",
      result = "You attack the Mosshide camp.",
      effects = { { "fight", "event_mosshide", gold = 30 } } },
    { label = "Let him tend your wounds", outcome = "+10 HP",
      result = "Rethiel presses wet moss on your wounds.",
      effects = { { "heal", 10 } } },
    { label = "Steal the flints at night", outcome = "50%: a potion and 25g, else -8 HP",
      effects = { { "gamble", 0.5,
        win = { { "potion" }, { "gold", 25 } },
        winText = "The gnolls are asleep. You take the flints and a potion from their supplies.",
        lose = { { "loseHp", 8 } },
        loseText = "A Mosshide Mongrel wakes up and bites you before you get away." } } },
  },
})

event("dun_modr_camp", {
  name = "Longbraid's Camp", act = 3, tier = 1,
  speaker = "Longbraid the Grim", npc = "longbraid", scene = "ruins",
  text = "\"Many of my soldiers died in the battle of Dun Modr. We hold this camp with what we "
    .. "have left. Fight with my men for a day, or share our rations.\"",
  choices = {
    { label = "Train with the soldiers", outcome = "-6 HP, upgrade 2 random cards",
      result = "You spar with the dwarves until dark.",
      effects = { { "loseHp", 6 }, { "upgradeRandom", 2 } } },
    { label = "Share their rations", outcome = "+8 HP",
      result = "You eat hard bread and salted fish with the soldiers.",
      effects = { { "heal", 8 } } },
    { label = "Buy from their quartermaster", outcome = "Pay 40g, one of 3 uncommon cards",
      result = "\"We need gold more than spare gear.\"",
      effects = { { "pay", 40 }, { "cardChoice", n = 3, rarity = "uncommon" } } },
  },
})

event("deepwater_tavern", {
  name = "The Deepwater Tavern", act = 3, tier = 0,
  speaker = "Mikhail", npc = "mikhail", scene = "coast",
  text = "\"Welcome to the Deepwater Tavern. A room is 20 gold. First Mate Fitzsimmons will tell "
    .. "you about the Third Fleet if you buy him a drink.\"",
  choices = {
    { label = "Rent a room", outcome = "Pay 20g, heal 30% of max HP",
      result = "You sleep until morning.",
      effects = { { "pay", 20 }, { "healPct", 0.30 } } },
    { label = "Buy Fitzsimmons a drink", outcome = "Pay 15g, upgrade a random card",
      result = "Fitzsimmons tells you how the Dragonmaw boarded the Third Fleet. You note how they fight.",
      effects = { { "pay", 15 }, { "upgradeRandom", 1 } } },
    { label = "Leave", outcome = "Nothing",
      result = "Mikhail wipes the counter.",
      effects = {} },
    -- carte neutre débloquée par la zone : l'huile des pêcheurs de Menethil
    { label = "Buy fire oil from the fishermen", outcome = "Pay 20g, Fire Oil (card)",
      when = { { "unlocked", "fire_oil", hide = true } },
      result = "\"Firefin snapper oil. Keep it away from the fire, unless you mean it.\"",
      effects = { { "pay", 20 }, { "card", "fire_oil" } } },
  },
})

event("sida_bag", {
  name = "Sida's Bag", act = 3, tier = 1,
  speaker = "Sida", npc = "sida", scene = "road",
  text = "\"On my weekly visit to Ironbeard's Tomb, an ooze swallowed my bag. I don't know which one. "
    .. "Can you get it back for me?\"",
  choices = {
    { label = "Fight the oozes", outcome = "Fight 2 oozes: usual reward + 25g",
      result = "You walk up to the oozes at the tomb.",
      effects = { { "fight", "event_ooze", gold = 25 } } },
    { label = "Reach into the oozes", outcome = "-8 HP, +40g",
      result = "The acid burns your arms. The third ooze has the bag; Sida pays you.",
      effects = { { "loseHp", 8 }, { "gold", 40 } } },
    { label = "Leave", outcome = "Nothing",
      result = "Sida sits down on the road.",
      effects = {} },
  },
})

event("flagongut_fossil", {
  name = "The Absent-Minded Archaeologist", act = 3, tier = 1, rarity = "rare",
  speaker = "Archaeologist Flagongut", npc = "flagongut", scene = "coast",
  text = "\"Raptors attacked me on the road to Whelgar's site and I lost the Stone of Relu. Without "
    .. "it, the fossil cannot be read. Find it, or fund a second dig.\"",
  choices = {
    { label = "Search the raptor nests", outcome = "-10 HP, a relic",
      result = "You find the Stone of Relu under a nest. Flagongut gives you a find from his crates.",
      effects = { { "loseHp", 10 }, { "relic" } } },
    { label = "Fund a second dig", outcome = "Pay 40g. 50%: 100g",
      effects = { { "pay", 40 }, { "gamble", 0.5,
        win = { { "gold", 100 } },
        winText = "The diggers find a second fossil. Flagongut sells it in Ironforge and pays you back.",
        lose = {},
        loseText = "The diggers find nothing." } } },
    { label = "Decline", outcome = "Nothing",
      result = "Flagongut goes back to his notes.",
      effects = {} },
  },
})

event("stoutfist_banners", {
  name = "War Banners", act = 3, tier = 3,
  speaker = "Captain Stoutfist", npc = "stoutfist", scene = "camp",
  -- comme les maraudeurs Rivepatte : réservé aux clés hautes
  when = { { "key", 2 } },
  text = "\"The Dragonmaw are stockpiling weapons at the Angerfang Encampment. Burn their war "
    .. "banners, and Menethil Keep will pay for every one.\"",
  choices = {
    { label = "Raid the encampment", outcome = "Fight 2 Dragonmaw: usual reward + 35g",
      result = "You attack the Dragonmaw guarding the banners.",
      effects = { { "fight", "event_dragonmaw", gold = 35 } } },
    { label = "Take the armaments at night", outcome = "40%: a relic, else -10 HP",
      effects = { { "gamble", 0.4,
        win = { { "relic" } },
        winText = "You carry a crate out of the camp without being seen.",
        lose = { { "loseHp", 10 } },
        loseText = "A Dragonmaw Raider sees you and throws an axe." } } },
    { label = "Refuse", outcome = "Nothing",
      result = "\"Then don't get in the way of those who will.\"",
      effects = {} },
  },
})
```

| Rencontre | PNJ | Créature / affichage | Lieu (source) |
|---|---|---|---|
| `halloran_skins` | James Halloran | 2094 / 1408 | Menethil Harbor (« Apprentice's Duties ») |
| `ormers_revenge` | Ormer Ironbraid | non trouvé | Whelgar Excavation Site (« Ormer's Revenge ») |
| `greenwarden` | Rethiel the Greenwarden | 1244 / 480 | Wetlands (« Fire Taboo », « Tramping Paws ») |
| `dun_modr_camp` | Longbraid the Grim | 1071 / 1671 | devant Dun Modr (« A Grim Task », « Fall of Dun Modr ») |
| `deepwater_tavern` | Mikhail | 4963 / 2964 | Menethil Harbor ; First Mate Fitzsimmons 1239 / 1699 (« The Cursed Crew ») |
| `sida_bag` | Sida | 2111 / 1407 | Menethil Harbor (« Digging Through the Ooze ») |
| `flagongut_fossil` | Archaeologist Flagongut | 2911 / 1650 | Menethil Harbor (« The Absent Minded Prospector ») |
| `stoutfist_banners` | Captain Stoutfist | 2104 / 5409 | Menethil Keep (« War Banners », « Forced Disarmament ») |

Paliers : 4 au palier 0, 3 au palier 1 (dont la rare), 1 au palier 3 (clé ≥ +2), comme Westfall.
Chaque rencontre a une réponse sans condition.

## 7. Cartes de zone (5, une par classe)

Cartes définitives (épiques, pivots) : voir `docs/zones/cartes-de-zone.md`.

- Echo of Light (Priest)
- Sweeping Strikes (Warrior)
- Water Elemental (Mage)
- Atrophic Poison (Rogue)
- Beast Cleave (Hunter)

## 8. Commun débloqué par la première victoire du compte

**Cartes neutres (2)**

| id | Nom | Rareté | Coût | Type | Texte | Amélioré | Icône | Où |
|---|---|---|---|---|---|---|---|---|
| `crocolisk_gumbo` | Crocolisk Gumbo | uncommon | 1 | Skill | Heal 5.<br>Gain Strength 1<br>Exhaust. | Heal 8.<br>Gain Strength 1<br>Exhaust. | `inv_misc_food_64` | marchand, rencontre `halloran_skins` |
| `fire_oil` | Fire Oil | common | 1 | Skill | Apply DoT 4 to all<br>Exhaust. | Apply DoT 6 to all<br>Exhaust. | `inv_potion_38` | marchand, rencontre `deepwater_tavern` |

**Bibelots communs (3)**

| id | Nom | Rareté | Effet (texte affiché) | Icône | Crochet |
|---|---|---|---|---|---|
| `crude_flint` | Crude Flint | uncommon | `Whenever an enemy dies, deal 2 to all enemies.` | `inv_stone_04` | `onEnemyDeath` (dans l'effet en cours : peut grouper des morts) |
| `young_crocolisk_skin` | Young Crocolisk Skin | common | `At the start of each combat, gain 3 Absorb per enemy.` | `inv_misc_leatherscrap_02` | `onCombatStart` |
| `flagonguts_fossil` | Flagongut's Fossil | common | `Card rewards after elite combats offer 4 cards, not 3.` | `inv_misc_bone_04` | récompense d'élite (nouveau point) |

**Type de case de parcours : Gryphon Master** (Shellei Brondir, 1571 / 5130, maître des griffons de
Menethil Harbor). Une case qui propose : `Fly ahead` (paie 30 po : passe l'étape suivante, on choisit la
case d'arrivée parmi celles reliées à l'étape d'après) ; `Rest at the roost` (soigne 15 % des PV max) ;
`Leave`. Utile pour éviter une élite ou un combat quand on est bas, au prix d'une récompense perdue.

## 9. Bibelots de clé (+1, +3, +5)

| Clé | id | Nom | Effet (texte affiché) | Icône | Origine |
|---|---|---|---|---|---|
| +1 | `dragonmaw_war_banner` | Dragonmaw War Banner | `The first two enemies to die each combat give you Strength 1.` | `inv_banner_02` | quête « War Banners » |
| +3 | `cursed_eye_of_paleth` | Cursed Eye of Paleth | `+1 mana per turn. Healing outside combat is halved.` | `inv_misc_eye_02` | quête « The Eye of Paleth » (coffre de la Third Fleet) |
| +5 | `goaz_stone` | Goaz Stone | `At the start of your turn, if an enemy died since your last turn: +1 mana and draw 1.` | `inv_misc_stonetablet_05` | quête « Uncovering the Past » (Prospector Whelgar) |

La bannière renverse la règle de la zone au profit du joueur ; l'œil est un bibelot de boss à défaut
(soins du feu de camp et des rencontres divisés par deux) ; la pierre récompense les combats à plusieurs
ennemis, toutes zones confondues.

## 10. Modèles et icônes : récapitulatif

| Unité | Créature / affichage | Icône de repli proposée |
|---|---|---|
| Bluegill Raider | 1418 / 391 | `inv_misc_head_murloc_01` |
| Mosshide Brute, Mystic, Alpha | 1012 / 3196, 1013 / 714, 1014 / 543 | `inv_misc_head_gnoll_01` |
| Mottled Screecher, Raptor, Scytheclaw | 1021 / 677, 1020 / 960, 1022 / 648 | `ability_hunter_pet_raptor` |
| Dragonmaw Raider, Bonewarder | 1034 / 4916, 1057 / 4918 | `inv_misc_head_orc_01` |
| Wetlands Crocolisk | 1400 / 1036 | `ability_hunter_pet_crocolisk` |
| Black Ooze, Black Slime | 1032 / 767, 1030 / 360 | non cherchée |
| Crimson Whelp | 1069 / 505 | non cherchée |
| Sarltooth | non trouvé | `ability_hunter_pet_raptor` |
| Modr | 271460 / 473 (échelle 2) | non cherchée |
| Ma'ruk Wyrmscale | non trouvé | `inv_misc_head_orc_01` |
| Chieftain Nek'rosh | 2091 / 4915 | `inv_misc_head_orc_01` |
| PNJ des rencontres | voir section 6 ; Ormer Ironbraid non trouvé | — |

Icônes des cartes et bibelots : toutes présentes dans `~/Téléchargements/ICONS/` (vérifié) ; celles des
cartes de classe sont les icônes des sorts (`wow_icon_search` : `spell_arcane_massdispel` 135739,
`ability_warrior_shockwave` 236312, `ability_mount_whitetiger` 132267) ; celles des objets sont proposées
(icône existante du bon thème), pas celle de l'objet en jeu, sauf `inv_potion_38` (Fire Oil) et
`inv_misc_food_64` (Crocolisk Gumbo), de mémoire.

## 11. Questions ouvertes

1. **Dispersion : Demoralized ou rien ?** Avec `Demoralized 1 ⌛`, tuer le Mosshide Alpha en premier
   fait aussi frapper les deux autres gnolls 25 % moins fort au tour suivant (≈ 5 PV de moins sur le
   combat) : le chef devient presque toujours la première cible. Sans, la dispersion ne fait qu'arrêter
   les primes, et le choix « chef d'abord ou en dernier » reste ouvert plus souvent.
2. **Morts groupées sans prime.** La règle récompense les cartes de zone : un deck Warrior Cleave ou Mage
   Blizzard traversera les Wetlands plus facilement qu'un Rogue Subtlety à cible unique. Si l'écart est
   trop grand, autre réglage : les morts groupées donnent leurs primes, mais divisées par deux.
3. **Modr est un golem de WoW Forever**, absent de Classic. Le garder (identifiants trouvés) ou le
   remplacer par un rare de Classic cité de mémoire (Sludginn, un limon ; Gnawbone) dont le cache du
   client ne connaît pas l'identifiant.
4. **Ma'ruk Wyrmscale** est cité de mémoire (rare Dragonmaw de Classic) : ni son nom ni son modèle ne sont
   dans les caches. Le garder, ou donner son armure à un Dragonmaw vérifié (Dragonmaw Centurion, 1036 /
   4919, sans nom propre).
5. **Cursed Eye of Paleth** : +1 mana par tour contre des soins hors combat divisés par deux. Un joueur
   qui comptait sur le feu de camp arrive au boss avec ≈ 15 PV de moins ; un deck qui se soigne en
   combat (Priest) n'y perd presque rien. Garder ce prix, ou le remplacer par « Draw 1 less each turn »
   (même coût pour toutes les classes).

## Implémentation (nuit du 13 au 14/11/2026)

Fichiers : `Data/Zones/Wetlands.lua` (ennemis, groupes, rencontres, commun, bibelots de clé, décors),
`Core/ZoneRules/wetlands.lua` (règle), `UI/Art/Zones/wetlands.lua` (modèles, icônes, vue de zone, huit décors
peints), `Sim/zones/wetlands.lua` (bot), `Sim/tests_zone_wetlands.lua` (32 tests),
`Sim/ui_zone_wetlands.lua` (section « UZW » du harnais).

### La règle telle que codée

- Champs d'ennemi : `pack = { "force" | "heal" | "absorb", n }` (membre qui donne), `pack = true` (membre sans
  prime : Sarltooth, Dragonmaw Centurion, Nek'rosh), `packLeader = true` (Mosshide Alpha).
- Mort d'un membre (`onEnemyDeath`) : sa prime entre dans une file avec le numéro de l'effet en cours ; la file
  est réglée à la fin de cet effet (`onEffectEnd` : carte, incantation, Trap, DoT, potion, action ennemie,
  début / fin de tour, donc l'attaque automatique du familier) : chaque membre encore vivant reçoit chaque
  prime, de gauche à droite. Les morts du même effet ne reçoivent rien (la règle de la fiche, gardée).
- Chef tué dans l'effet : primes de cet effet annulées, la meute se disperse (`e.zs.wetlands.scattered`) ; plus
  rien n'est donné ni reçu ; un membre invoqué ensuite arrive dispersé. Pas de Demoralized (décisions).
- Victoire : le combat s'arrête, la file est perdue. Filet : la file est aussi vidée au début de la phase ennemie
  et du tour du joueur.
- Journal `{ t = "pack", src, dst, bonus, n, got }` et `{ t = "scatter", by }`, textes flottants
  (« +2 Strength », « +6 HP », « +3 Absorb », « Scattered »), statistiques `Combat.zstat`.

### Ce qui diffère de la fiche, et pourquoi

- **Ma'ruk Wyrmscale → Dragonmaw Centurion** (décisions : créature réelle 1036). Wyrmscale Armor retire **10**
  dégâts au premier coup de chaque tour du joueur au lieu de l'annuler : annulé en entier, l'armure mangeait le
  gros sort du Mage chaque tour (élite la plus meurtrière pour lui).
- **Mortal Wound** (ajout) : état « soins reçus divisés par deux » (crochet `heal` de la zone), posé par le
  Mortal Strike du Dragonmaw Raider (2 tours), le Cleave du Centurion et le Cleave et le Sunder Armor de
  Nek'rosh. Seule réponse trouvée à l'écart entre les classes qui se soignent (Priest) et les autres : sans
  elle, le Priest gagnait 87 % contre 57 % au Mage.
- **Nek'rosh** : 80 PV (fiche 98) ; Sunder Armor pose **Sundered 1** (2 dans la fiche : +25 % de dégâts sur deux
  tours faisait tomber le Mage de 16 points) ; Clan Command donne **Strength 2** à tous et 8 Absorb, en 3e
  position (Cleave, Sunder, Command) ; phase 2 : Shadow Bolt **16** (fiche 28), motif Shadow Bolt, Cleave,
  **Call Whelps** (ajout : 2 Crimson Whelps, 4 au plus), Sunder. Bonewarders : prime heal **6** (fiche 10).
- **Sarltooth** : Scytheclaws à +1 Strength (fiche +2), 2 au plus en vie : une carte de zone qui tue l'escorte
  renforçait trop Sarltooth (les classes à zone, le Mage d'abord, étaient punies de jouer leur force).
- **Rencontres** : Ormer Ironbraid se tient sur la colline (`scene = "hill"`, les fouilles de Whelgar), le décor
  « mine » étant celui du boss ; soins fixes plutôt qu'en pour-cent (Deepwater Tavern : +16 PV au lieu de 30 %,
  Greenwarden +15, rations de Longbraid +12) : un soin fixe profite davantage aux classes à peu de PV.
- **Gryphon Master** : rencontre de case (`node = true`) et case `gryphon_master` déclarées par la zone, tier 3,
  posées dans toutes les zones une fois débloquées.
- **Non codé** : effets `strip`, `steal`, `unpack`, `marked` (destinés aux cartes de zone, autre lot) ; aperçu
  des primes au survol d'une carte (aucun aperçu de dégâts dans l'écran de combat : lot d'interface commun).
  La prime est écrite sous chaque ennemi (« Pack: +2 Str », couronne « Pack Leader », patte grisée
  « Scattered ») et la bulle d'intention montre la Strength reçue.
- Libellés : bibelots de clé reformulés sans « you » (convention des bibelots communs).

### Moteur, peintre, tests partagés

- Aucun crochet nouveau : la file passe par `onEnemyDeath` / `onEffectEnd`, Modr par `onEnemyDamaged`,
  `enemyMove`, `onEnemyStunned` et un montant `ENEMY_AMOUNTS.earthen_charge` (Charges + celle qui viendra au
  début de son tour : la bulle de Seismic Slam annonce le vrai coup et baisse quand on le frappe assez).
- Décors : plans propres `layers` et registre `S.PROPS` de `UI/Scene.lua` (apportés par Steppes) ; les
  accessoires des Wetlands y entrent sous `wl_<genre>` (voir `docs/zones.md`, « Décors »).
- Tests partagés : `fromZone = "wetlands"` sur le commun déclaré par la zone ; `Sim/tests.lua`,
  `Sim/tests_expedition.lua` (comptes des paliers 0 à 3 sans `fromZone`, effets de `X.EFFECTS` admis, rencontre de
  case ouverte par sa case) et `Sim/ui_harness.lua` (onglet Zones : Wetlands « Locked » une fois jouable).

### Nombres finaux (`Data/Zones/Wetlands.lua`)

| Ennemi | PV | Prime | Intentions |
|---|---|---|---|
| Bluegill Raider | 11–13 | +3 Absorb | Spear Jab 5 ; Muck Toss 3 + Demoralized 1 |
| Mosshide Brute | 19–22 | +2 Strength | Club 8 ; Knockdown 5 (interrompt) |
| Mosshide Mystic | 15–17 | heal 6 | Healing Wave 6 (allié à −6 PV ou plus) ; Lightning Bolt 10 (Cast) |
| Mosshide Alpha | 24–27 | chef | Rally 4 Absorb à tous ; Maul 11 ; Savage Howl Strength 1 à tous |
| Mottled Screecher | 13–15 | +1 Strength | Screech (Cast : un raptor, 3 au plus) ; Claw 3 × 2 |
| Mottled Raptor | 13–15 | +2 Strength | Rake 3 × 2 ; Lunge 7 |
| Dragonmaw Raider | 24–27 | +2 Strength | Shield Bash 5 (interrompt) ; Mortal Strike 11 + Mortal Wound 2 |
| Wetlands Crocolisk | 32–36 | — | Snap 10 ; Submerge 12 Absorb ; Death Roll 4 × 3 |
| Black Ooze / Black Slime | 22–25 / 6–7 | — | Corrosive Acid 5 + Sundered 1 ; Ooze Slam 8 ; 2 Slimes à sa mort / Slime Bolt 3 |
| Sarltooth (élite) + Scytheclaw | 66 + 12–14 | — / +1 Strength | Call the Pack (2 au plus) ; Rend 7 + DoT 3 ; Leap 16 (interrompt) / Slash 5 |
| Modr (élite) | 90 | — | Stone Fist 12 ; Seismic Slam 6 + 8 par Charge (interrompt) ; Charge si < 15 PV perdus |
| Dragonmaw Centurion (élite) | 56 | membre | Shield Bash 6 ; Cleave 8 × 2 + Mortal Wound 2 ; Demoralizing Shout 4 + Demoralized 2 ; armure −10 |
| Chieftain Nek'rosh (boss) | 80 | membre | Cleave 9 × 2 + MW 2 ; Sunder 12 + Sundered 1 + MW 2 ; Clan Command ; phase 2 : Shadow Bolt 16 (Cast), Call Whelps |
| Dragonmaw Bonewarder / Crimson Whelp | 13–15 / 8–10 | heal 6 / — | Bone Ward 6 sur le boss ; Shadow Bolt 6 / Fire Breath 4 |

### Mesures (heuristic, `runner=expedition zone=wetlands zones=2 level=7`, clé 0)

Sans épique (`epic=none`, 1 000 expéditions) et avec épique (sans `epic=` : le bot en choisit une, 500) :

| Classe | Victoire sans épique | avec épique | PV perdus / combat normal | Tours (normal) | Boss : victoire, tours |
|---|---|---|---|---|---|
| Priest | 73,8 % | 86,6 % | 9,6 | 3,93 | 75,8 %, 7,17 |
| Warrior | 74,5 % | 92,2 % | 11,1 | 3,49 | 79,1 %, 6,98 |
| Mage | 58,6 % | 66,4 % | 7,6 | 3,38 | 65,0 %, 5,31 |
| Rogue | 67,7 % | 90,8 % | 8,4 | 3,19 | 74,7 %, 5,40 |
| Hunter | 67,7 % | 88,0 % | 7,8 | 2,96 | 70,3 %, 5,49 |

Clés (Rogue, sans épique, 1 000) : +0 67,7 % ; +1 55,3 % ; +3 41,8 % ; +5 34,1 % (−6,7 points par niveau en
moyenne ; le saut de +1 vient des affixes communs). Repères Westfall (même bot, `zones=0`, 300) : Priest 82 %,
Warrior 81 %, Mage 71 %, Rogue 71 %, Hunter 74 %.

**Écart entre classes : 16 points sans épique (Warrior 74,5 – Mage 58,6), au-dessus des 10 visés.** Il suit
celui de Westfall (11 points, même ordre) et vient des réserves de PV : la zone coûte à chaque classe à peu près
la même chose en PV (7,6 à 11 par combat normal), ce qui pèse plus sur le Mage (42 PV) que sur le Warrior (74) ou
le Priest (36 PV mais soins en combat). Essayé sans effet ou à contre-sens : Strength des commandements plus
tôt, montée de Strength par les primes, Mortal Strike en un seul coup (Warrior +6), invocations plus
nombreuses. Ce qui a resserré : Mortal Wound (Priest −12), armure du Centurion plafonnée, Sundered 1, Scytheclaws
moins forts, soins fixes des rencontres (Mage +2 à +6). Avec épique, le Mage reste à 66 % quand les autres
dépassent 86 % : écart propre aux épiques (autre lot). Statistiques de zone (par combat normal, Hunter) : primes
de Strength 1,9, soin de meute perdu sur un ennemi intact 2,6, chef tué en premier 0,01 contre 0,17 en dernier.

### Modèles en repli

Toutes les créatures de la fiche sont dans le cache du client (`tools/wdb_creatures.py`, 13/11/2026), sauf :
**Sarltooth** → Mottled Scytheclaw (1022, affichage 648) agrandi ×1,3 ; **Ormer Ironbraid** → Longbraid the Grim
(1071, 1671), puis Prospector Stormpike (3594). Chaque personnage a deux affichages voisins de secours
(commentaires de `UI/Art/Zones/wetlands.lua`) ; Modr (271460, contenu Forever) a pour secours son affichage 473
puis le Fen Creeper (2023).

### Décors

Huit décors peints (`Art.paintings.wetlands_*`) : route des marais (`road`), fouilles de Whelgar (`hill`),
Angerfang (`camp`), marché de Menethil (`shop`), route de nuit (`night`), portes de Grim Batol (`mine` : boss),
quais de Menethil (`coast`), Dun Modr (`ruins`). Ciel couvert gris-bleu, pluie fine, brume basse, mares,
roseaux à massettes au premier plan ; accessoires propres (arbre des marais, bateau, ponton, donjon, ruine, tente
orque, échafaudage, porte, bannière). Planches : `build/snap/decor-wetlands_*.svg` du harnais.
