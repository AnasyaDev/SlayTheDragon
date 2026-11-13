# Zone 6 — Burning Steppes (`steppes`)

Fiche de conception (13/11/2026). Rien n'est codé. Format et puissance de référence : `Data/Act1.lua`
(Westfall). Difficulté visée : Westfall + 60 % (PV ennemis × 1,6 ; dégâts directs × 1,45, le reste de
la pression venant de la mécanique de zone, environ 2 à 4 PV par combat normal). Tous les chiffres sont
des points de départ pour la simulation.

Sources des noms et identifiants : base de PNJ et de quêtes de Questie installée avec le client Classic Era
(`_classic_era_/Interface/AddOns/Questie/Database/Classic/`), zone 46 = Burning Steppes. Le MCP wow ne
trouve aucune créature par son nom (voir § 10).

## 1. La zone en trois lignes

- **Lieux** : la route de cendres entre Blackrock Pass et Morgan's Vigil (route) ; Morgan's Vigil, camp de
  l'Alliance au sud-est (camp, repos) ; Flame Crest, comptoir des gobelins et de la Horde au nord-est
  (marchand) ; Dreadmaul Rock, repaire des ogres Firegut, et les Ruins of Thaurissan, tenues par les Dark
  Iron (élites) ; Blackrock Stronghold, au pied de la montagne (boss).
- **Ambiance factuelle** : sol de cendres, coulées de lave, herbes sèches qui prennent feu. Orcs Blackrock
  et dragonkin noirs tiennent le nord, ogres Firegut l'est, Dark Iron et élémentaires de feu les ruines
  et les coulées. Niveaux 50 à 58 dans Classic.
- **Fonds de scène proposés** : `steppes_road` (route), `morgans_vigil` (camp), `flame_crest` (marchand),
  `dreadmaul_rock` et `ruins_of_thaurissan` (élites), `blackrock_stronghold` (boss). Repli sur les décors
  existants : road, camp, mine (grottes de Dreadmaul), ruins, hill (Slither Rock).

## 2. La mécanique de la zone : Wildfire

L'idée proposée (« Burn », terrain qui brûle, durée comptée) est gardée. Le nom affiché devient
**Wildfire** pour ne pas se confondre avec l'icône de brûlure du DoT (décision du 11/11 : un seul état de
dégâts sur la durée, nommé DoT). Wildfire n'est pas un état porté par une unité : c'est un compteur du
champ de bataille.

### Règle

1. **Compte à rebours.** Chaque combat des Burning Steppes commence avec **Wildfire in T** :
   T = 3 en combat normal, 4 en élite, 4 au boss (une définition d'ennemi peut fixer sa valeur : Volchan 2).
   T est aussi le plafond du compte à rebours pour tout le combat.
2. **Fin de round.** À la fin de chaque round (après le tour ennemi, avant la baisse des durées) :
   - si le compte à rebours vaut 1 ou plus, il baisse de 1 ; s'il atteint 0, le sol **s'embrase** (journal
     « The ground ignites! »), sans dégâts ce round-là ;
   - s'il valait déjà 0 au début de la fin de round, le joueur **perd Blaze PV**, puis **Blaze augmente de 2**.
   Blaze vaut **2** au premier embrasement d'un combat et ne redescend jamais pendant ce combat.
3. **Mort d'un ennemi.** Quand un ennemi meurt (pas un serviteur, `minion = true`), le compte à rebours
   remonte de 1 (plafond T). S'il était à 0, il repasse à 1 : le round en cours ne brûle pas, Blaze garde sa
   valeur. La mort du dernier ennemi termine le combat avant la fin de round : rien ne brûle.
4. **Stoke N** (action ennemie). Retire N au compte à rebours (minimum 0). Chaque point qui ne peut pas
   être retiré, parce que le compte est déjà à 0, ajoute 2 à Blaze. Un Stoke qui amène le compte à 0
   pendant le tour ennemi fait donc brûler dès la fin de ce round.
5. **Douse N** (effet de carte du joueur). Ajoute N au compte à rebours (plafond T). Sur un sol embrasé,
   le compte repasse à N ; Blaze garde sa valeur. Hors des Burning Steppes, Douse ne fait rien.
6. **Perte de PV.** La brûlure est une perte de PV hors attaque, comme `Pay N HP` (`Combat.loseHp`,
   raison `"wildfire"`) : elle ignore l'Absorb, Parry et Pain Suppression, elle compte pour la Rage,
   Enrage et tout ce qui lit « HP lost », et elle peut tuer (les Last Breath s'appliquent).
7. **Tour ennemi sauté** (Feign Death) : la fin de ce round ne touche pas au Wildfire (ni baisse, ni
   brûlure).

Ce que donne la règle à T = 3 sans Stoke ni mort : le sol s'embrase à la fin du round 3, brûle 2 à la
fin du round 4, 4 au round 5, 6 au round 6. Un combat normal gagné au tour 4 ne coûte rien ; chaque
Stoke avance tout d'un round, chaque mort recule tout d'un round.

### Ce que voit le joueur

- Un jeton de flamme en haut, au centre du champ de bataille. Avant l'embrasement : flamme grise et
  chiffre du compte à rebours (« Wildfire in 2 »). Après : flamme rouge et chiffre de Blaze (« Wildfire 4 »),
  avec une portion hachurée sur sa barre de PV, comme les dégâts annoncés.
- **Prévision.** Les intentions ennemies qui contiennent un Stoke portent une petite flamme et « +1 » ;
  le jeton affiche la valeur après le tour ennemi (« 2 → 1 », ou « 4 → 6 » s'il brûle déjà).
- À chaque mort d'ennemi, le jeton remonte d'un cran avec une courte animation.

### Infobulles (≤ 60 caractères)

| Terme | Infobulle |
|---|---|
| Wildfire in N | `Ignites in N rounds. Each enemy death delays it by 1.` |
| Wildfire N | `End of round: you lose N HP, then N rises by 2.` |
| Stoke N (intention) | `Wildfire N rounds sooner; if lit, +2 per point.` |
| Douse N (carte) | `Delays Wildfire by N rounds (Burning Steppes).` |

### Décisions créées (pas une taxe)

- **Cible.** Tuer le petit (Flamekin Torcher, 13 PV) recule le feu d'un round ; frapper le gros
  (Firegut Brute) réduit les coups. Tuer celui qui attise (Stoke) arrête la course.
- **Défendre ou finir.** L'Absorb ne protège pas de la brûlure : une fois le sol embrasé, un tour de
  défense coûte Blaze PV de plus. Plus le combat dure, plus l'attaque vaut.
- **Contrôle sur les attiseurs.** Interrompre un Stoke en Cast (Flamestrike, Torch, Fan the Flames),
  étourdir un attiseur (son tour, Stoke compris, est perdu), ou payer le round de plus.
- **Garder un Douse.** Douse est plafonné à T : le jouer trop tôt ne sert à rien, le garder (Retain,
  main) pour le round qui brûlerait.
- **Boss.** Le joueur choisit quand faire passer Grark sous 60 % : c'est ce seuil qui embrase le sol (§ 5).

### Interactions

| Règle | Comportement |
|---|---|
| Absorb | N'arrête pas la brûlure. Arrête normalement les coups des attaques qui contiennent un Stoke. |
| Parry (Rogue) | Aucun effet sur la brûlure (comme le DoT). |
| Stunned | Un ennemi étourdi perd son tour, Stoke compris. Stunned posé par une Trap sur une attaque suivie d'un Stoke (Searing Roar, Kick Embers, Torch the Field) : le tour s'arrête, le Stoke ne part pas. |
| Cast / interruption | Un Stoke placé dans une intention Cast est annulé par l'interruption, avec le reste du sort. |
| Traps (Hunter) | Une intention qui ne contient aucune attaque (Fan the Flames, Firewalk) ne déclenche pas de Trap : les Traps attendent (c'est le point faible du Survival ici). Les attaques avec Stoke en déclenchent une, avant le premier coup. |
| DoT | Aucun lien. Le DoT du joueur se déclenche au début de son tour, le Wildfire en fin de round. Les morts par DoT comptent pour la règle 3. |
| Familier (Hunter) | Une mort causée par le familier compte (règle 3). Le familier n'est pas touché. |
| Rage, Enrage | La brûlure donne +1 Rage et déclenche Enrage, comme un `Pay N HP`. |
| Pain Suppression | Ne réduit pas la brûlure (perte hors attaque). |
| Fuite (Hearthstone) | Inchangée. |
| Serviteurs | Leur mort ne recule pas le feu (Ember Worg, Dark Iron Land Mine). |

### Aucune classe sans réponse

| Classe | Réponses de base | Carte de zone |
|---|---|---|
| Priest | Soins (Atonement, Renew, Flash Heal) qui rattrapent la brûlure ; Silence sur les Stoke en Cast. | Prayer of Mending : la brûlure soignée devient des dégâts |
| Warrior | La brûlure nourrit la Rage ; Execute pour achever et reculer le feu ; Pummel sur les Cast. | Death Wish : renoncer à l'Absorb, qui ne sert pas contre le feu, pour finir vite |
| Mage | Gros Cast et dégâts de zone (plusieurs morts = plusieurs rounds) ; Counterspell ; Frost Nova arrête tous les Stoke d'un tour. | Mirror Image : chaque Cast frappe une seconde cible, les petits meurent |
| Rogue | Vitesse (Combo, Surge), Kick à 0 mana sur les Stoke en Cast ; Fan of Knives sur les Torchers. Parry ne sert pas contre la brûlure : c'est sa zone difficile. | Relentless Strikes : deux ou trois Surge par tour |
| Hunter | Le familier achève les petits ; Counter Shot ; Freezing Trap stoppe les attaques avec Stoke. Les Traps attendent devant les attiseurs sans attaque. | Lone Wolf : toute la puissance dans le tour du joueur |

Douse n'existe que sur la carte neutre Greater Fire Protection Potion (§ 8) : la réponse directe au feu
reste commune, les cartes de classe changent la façon de jouer.

### Ce que le moteur doit apprendre

`Data/Act1.lua` sait déjà : intentions à actions multiples, Cast ennemi interrompu, `summon`, serviteurs,
`fn`, `onDamaged` / `onDeath` / `onAllyDeath`, crochets `onRoundEnd`, `onEnemyDeath`, `onHpLost`,
`Combat.loseHp`. Il manque :

1. **État du champ** `c.wildfire = { left, max, blaze }`, nil hors de la zone, posé par `Combat.new` selon
   le genre du combat (table de la zone : `ns.Encounters.steppes.wildfire = { normal = 3, elite = 4,
   boss = 4, blaze = 2, step = 2 }` ; surcharge `wildfire = 2` sur une définition d'ennemi). Données
   simples, clonées avec le combat.
2. **Pas de fin de round** dans `Combat.endRound`, avant `decayUnit` : baisse, embrasement, ou
   `Combat.loseHp(c, blaze, "wildfire")` puis `blaze + step` ; sauté si le tour ennemi l'a été.
   Crochet `Combat.fire(c, "onWildfire", n)` après la brûlure (Volchan).
3. **Action ennemie** `{ "stoke", n }` dans `executeMove`, et son affichage dans `Combat.intentInfo`
   (flamme + valeur prévue).
4. **Mort** : dans `Combat.kill`, `left + 1` (plafond `max`) si l'ennemi n'est pas un serviteur.
5. **Effet de carte** `{ "douse", n }` (aujourd'hui sur la seule Greater Fire Protection Potion, § 8).
6. **Bonus conditionnel sur une attaque ennemie** : `{ "attack", 10, lit = 5 }` (+5 si le sol brûle).
   Aujourd'hui `more` n'existe que pour les cartes.
7. **Action ennemie** `{ "ignite", bonus }` (compte à 0 ; s'il l'était déjà, Blaze + bonus), pour le boss.
8. **Crochet d'ennemi** `onWildfire(c, e, n)` (Volchan se soigne de n).
9. **Cartes épiques** (§ 7) : crochet `onHeal` avec le soin réellement rendu (Prayer of Mending) ;
   modificateur « can't gain Absorb » et multiplicateur de dégâts des Attack (Death Wish) ; crochet
   `onCastResolved` avec les dégâts infligés (Mirror Image, existe sans la valeur) ; crochet `onSurge`
   avec le nombre de Combo dépensés (Relentless Strikes) ; drapeau « familier absent » lu par
   l'attaque automatique et les effets `pet` (Lone Wolf). Rareté `epic`.
10. **Interface** : jeton de flamme, prévision dans les intentions, portion hachurée de la barre de PV,
    journal (`{ t = "wildfire", left, blaze, loss }`).
11. **Statistiques** (simulation) : PV perdus par Wildfire par combat, round du premier embrasement,
    Stoke subis / annulés (interruption, Stunned), rounds regagnés par les morts, Douse joués.
12. **Bots** : compter la valeur d'une mort (un round de brûlure évité ≈ Blaze PV) et d'une interruption
    de Stoke.

## 3. Ennemis normaux (9)

Notation de `Data/Act1.lua`. Sept sur neuf touchent au Wildfire (colonne « Wildfire »).
`lit = n` : +n dégâts si le sol brûle (point moteur 6).

| id | Nom (créature) | PV | Intentions | Motif | Wildfire | Rôle |
|---|---|---|---|---|---|---|
| `blackrock_soldier` | Blackrock Soldier (7025) | 38–42 | **Strike** attack : `{attack, 12}` · **Shield Bash** attack : `{attack, 7, interrupts}` · **Sunder Armor** debuff : `{attack, 6}`, `{debuff, armor_broken, 1}` | strike, bash, sunder ; départ au hasard | — | Le mur. Coupe les Cast du joueur et protège les attiseurs derrière lui. |
| `blackrock_sorcerer` | Blackrock Sorcerer (7026) | 26–29 | **Flamestrike** cast : `{attack, 10}`, `{stoke, 1}` · **Fireball** attack : `{attack, 11}` | flamestrike, fireball ; départ au hasard | Stoke en Cast | Cible d'interruption : un seul Interrupt annule les dégâts et le Stoke. |
| `blackrock_worg` | Blackrock Worg (7055) | 28–31 | **Bite** attack : `{attack, 10, lit = 5}` · **Rend Flesh** attack : `{attack, 5, times = 2}` | bite, rend ; départ au hasard | Plus fort sur sol embrasé | Punit les combats longs : 15 au lieu de 10 une fois le sol en feu. |
| `black_dragonspawn` | Black Dragonspawn (7040) | 50–54 | **Scale Guard** defend : `{block, 12}` · **Searing Roar** attack : `{attack, 7}`, `{stoke, 1}` · **Cleave** attack : `{attack, 16}` | guard, roar, cleave | Stoke sur une attaque | Gros PV : le tuer vite est difficile, l'étourdir avant Searing Roar est la parade. |
| `black_wyrmkin` | Black Wyrmkin (7041) | 32–36 | **Fan the Flames** cast : `{stoke, 2}` · **Flame Buffet** attack : `{attack, 9}` | fan, buffet ; départ au hasard | Stoke 2 en Cast, sans attaque | L'attiseur pur : ne frappe qu'un tour sur deux, mais vaut 2 rounds. Ne déclenche pas les Traps. |
| `firegut_brute` | Firegut Brute (7035) | 58–62 | **Bellow** buff : `{block, 10}`, `{buff, force, 2}` · **Smash** attack : `{attack, 22, interrupts}` · **Kick Embers** attack : `{attack, 8}`, `{stoke, 1}` | bellow, smash, embers | Stoke sur une attaque | Le gros coup qui interrompt ; Strength qui monte si le combat dure. |
| `firegut_ogre_mage` | Firegut Ogre Mage (7034) | 30–33 | **Bloodlust** buff : `{buff_allies, force, 2}` · **Fireball** attack : `{attack, 12}` | ia : Bloodlust si un autre ennemi vit et qu'il ne l'a pas lancé au tour précédent, deux fois par combat au plus ; sinon Fireball | — | Soutien : à tuer en premier pour que le Brute ne monte pas. |
| `flamekin_torcher` | Flamekin Torcher (9778) | 12–14 | **Torch** cast : `{attack, 4}`, `{stoke, 1}` · **Ember** attack : `{attack, 5}` | torch, ember ; départ au hasard | Stoke en Cast | Par trois : test des dégâts de zone. Chaque mort recule le feu. |
| `thaurissan_firewalker` | Thaurissan Firewalker (7037) | 40–44 | **Firewalk** defend : `{block, 10}`, `{stoke, 1}` · **Fire Nova** attack : `{attack, 8, lit = 8}` | firewalk, nova | Stoke sans attaque, plus fort sur sol embrasé | Le Dark Iron isolé, avec des élémentaires : il attise, puis frappe 16 sur sol en feu. |

### Groupes

PV totaux entre parenthèses (Westfall × 1,6 : facile ≈ 65, normal ≈ 90).

| Liste | Groupes |
|---|---|
| `easy` | {Blackrock Soldier, Blackrock Worg} (66–73) · {Flamekin Torcher ×3} (36–42) · {Black Dragonspawn} (50–54) · {Black Wyrmkin, Flamekin Torcher} (44–50) |
| `normal` | {Blackrock Soldier, Blackrock Sorcerer, Blackrock Worg} (92–102) · {Blackrock Worg ×2, Blackrock Sorcerer} (82–91) · {Black Dragonspawn, Black Wyrmkin} (82–90) · {Firegut Brute, Firegut Ogre Mage} (88–95) · {Thaurissan Firewalker, Flamekin Torcher ×2} (64–72) |
| `elite` | {Gruklash} · {Thauris Balgarr} · {Volchan} |
| `boss` | {Grark Lorkrub} |
| rencontres | `event_firegut` {Firegut Brute, Firegut Ogre Mage} · `event_dragonkin` {Black Dragonspawn, Black Wyrmkin} · `event_volchan` {Volchan} · `event_wanted` = un groupe d'élite tiré |

## 4. Élites (3)

| id | Nom (créature) | PV | Wildfire | Intentions et motif | Idée de combat |
|---|---|---|---|---|---|
| `gruklash` | Gruklash (8979), orc Blackrock rare, guerrier | 118 | 4 | **Pummel** attack : `{attack, 10, interrupts}` · **Backhand** debuff : `{attack, 13}`, `{debuff, demoralized, 2}` · **Mortal Strike** attack : `{attack, 24}` ; motif pummel, backhand, mortal. **Frenzy** (`onDamaged`, une fois) : à 59 PV ou moins, « Gruklash goes into a frenzy! », `force 4`. | **Le seuil.** Il coupe un Cast sur trois et devient bien plus dangereux sous la moitié. Le joueur garde ses gros coups pour passer de 60 à 0 en deux tours, avant que le feu et la Frenzy ne s'additionnent. |
| `thauris_balgarr` | Thauris Balgarr (8978), Dark Iron rare, fusilier | 96 | 4 | **Dark Iron Land Mine** summon : `{summon, dark_iron_land_mine}` (si moins de 2 mines, sinon Shoot) · **Shoot** attack : `{attack, 13}` · **Net** debuff : `{attack, 5}`, `{debuff, demoralized, 2}` ; motif mine, shoot, net, shoot. | **Les mines.** Chaque mine est un serviteur à désamorcer : 8 PV ou 14 dégâts et un Stoke. Le joueur partage ses coups entre Thauris et les mines. Les mines ne reculent pas le feu en mourant. |
| `dark_iron_land_mine` | Dark Iron Land Mine (8035), serviteur | 8 | — | **Arming** buff : aucune action · **Detonate** attack : `{attack, 14}`, `{stoke, 1}`, puis la mine se détruit (`fn`) ; motif arm, detonate. | Un tour pour la détruire. L'Absorb protège de l'explosion, pas du Stoke. |
| `volchan` | Volchan (10119), géant de lave rare élite | 125 | **2** | **Flamecrack** attack : `{attack, 8}`, `{stoke, 1}` · **Stomp** attack : `{attack, 18, interrupts}` · **Fire Nova** cast : `{attack, 22}` ; motif crack, stomp, nova. **Molten Body** (`onWildfire`) : chaque brûlure le soigne d'autant. | **La course perdue d'avance.** Seul, il ne donne aucune mort pour reculer le feu ; le sol brûle dès la fin du round 3 et le soigne. Les réponses : gros dégâts tôt, Douse, interruption de Fire Nova. Le combat qui rend Douse précieux. |

## 5. Boss : Grark Lorkrub

Grark Lorkrub (9520), orc Blackrock élite de Blackrock Stronghold, celui que la quête « Grark Lorkrub »
(Lexlort, Kargath) demande de capturer pour avoir livré les opérations de la Horde au clan Blackrock.
**150 PV, Wildfire 4.** Vise 6 tours (Edwin VanCleef : 92 PV).

| Phase | Déclencheur | Intentions et motif |
|---|---|---|
| 1 | début | **Call the Pack** summon : `{summon, ember_worg}` · **Cleave** attack : `{attack, 13}` · **Heroic Strike** attack : `{attack, 20}` · **Shield Block** buff : `{block, 14}`, `{buff, force, 1}` ; motif orders, cleave, strike, block. |
| 2 | 90 PV ou moins (`onDamaged`, une fois) | « Burn them out! Let the Steppes take them! » : `{ignite, 4}` (sol embrasé tout de suite ; déjà embrasé : Blaze + 4). Motif remplacé, en commençant par Torch : **Torch the Field** attack : `{attack, 8}`, `{stoke, 1}` · **Mortal Strike** attack : `{attack, 24, interrupts}` · **Rend** debuff : `{attack, 6}`, `{debuff, pain, 4}` · **Shield Block** (idem). |
| 3 | 37 PV ou moins (une fois) | « Blackrock, to me! » : invoque 2 Ember Worg et gagne 15 Absorb. Motif inchangé. |

Serviteur `ember_worg` : Ember Worg (9690), 14 PV, `minion = true`, **Bite** attack : `{attack, 7}`.

Lecture du combat :
- En phase 1, le feu suit son compte normal (embrasement à la fin du round 4) ; seul Douse le recule,
  les loups sont des serviteurs.
- Le seuil de 90 PV est la décision : franchi au tour 2, le joueur brûle 2, 4, 6, 8 sur les rounds 2 à 5
  (20 PV) ; franchi au tour 4 avec un gros tour en réserve, 2 et 4 (6 PV). Garder ses dégâts sous le
  coude en phase 1 coûte des coups de Grark ; tout lâcher tôt coûte du feu.
- Phase 3 : deux loups et 15 Absorb pour rallonger d'un tour au moment où Blaze est haut.

## 6. Rencontres (8)

Format de `Data/Events.lua`, `act = 6`. Les décors sont ceux du § 1 (repli entre parenthèses).
`npc` = identifiant libre ; créature au § 10.

```lua
event("oralius_firegut", {
  name = "Extinguish the Firegut", act = 6, tier = 0,
  speaker = "Oralius", npc = "oralius", scene = "morgans_vigil", -- (camp)
  text = "\"The Firegut ogres of Dreadmaul Rock raid our supply carts every night. Kill a few of them "
    .. "and the Vigil pays you. If you won't fight, I can sell you what is left in the carts.\"",
  choices = {
    { label = "Raid Dreadmaul Rock", outcome = "Fight 2 ogres: usual reward + 25g",
      result = "You attack the ogres at the foot of Dreadmaul Rock.",
      effects = { { "fight", "event_firegut", gold = 25 } } },
    { label = "Buy from the carts", outcome = "Pay 30g, a potion",
      result = "Oralius hands you a flask from the last cart that got through.",
      effects = { { "pay", 30 }, { "potion" } } },
    { label = "Move on", outcome = "Nothing",
      result = "You leave Oralius to his count of the carts.",
      effects = {} },
  },
})

event("marshal_maxwell", {
  name = "Morgan's Vigil", act = 6, tier = 0,
  speaker = "Marshal Maxwell", npc = "marshal_maxwell", scene = "morgans_vigil", -- (camp)
  text = "\"Marshal Windsor went into Blackrock Mountain a month ago and has not come back. I cannot "
    .. "spare a single soldier to look for him. If you are going that way, the Vigil will equip you.\"",
  choices = {
    { label = "Drill with the guard", outcome = "-7 HP, upgrade a card of your choice",
      result = "You spar with the Vigil's guards until dusk.",
      effects = { { "loseHp", 7 }, { "upgrade" } } },
    -- drapeau lu par la zone 7 (Blackrock Mountain) : Windsor retrouvé ou non
    { label = "Promise to find Windsor", outcome = "+30g. He will remember.",
      result = "Maxwell pays you in advance. \"Bring him back, or bring me news.\"",
      effects = { { "gold", 30 }, { "flag", "maxwell_windsor" } } },
    { label = "Leave", outcome = "Nothing",
      result = "You salute the marshal and take the road north.",
      effects = {} },
  },
})

event("ragged_john", {
  name = "Ragged John's Camp", act = 6, tier = 1,
  speaker = "Ragged John", npc = "ragged_john", scene = "steppes_road", -- (camp)
  text = "\"Sit down, friend, you look half cooked. I've lived on these steppes for twenty years "
    .. "without a single burn. Drink some of my milk, that's the secret.\"",
  choices = {
    { label = "Drink his milk", outcome = "50%: +7 max HP, else -9 HP",
      effects = { { "gamble", 0.5,
        win = { { "maxHp", 7 } },
        winText = "The milk tastes foul, but you feel tougher.",
        lose = { { "loseHp", 9 } },
        loseText = "The milk has turned. You spend the night sick." } } },
    { label = "Rest by his fire", outcome = "+12 HP",
      result = "Ragged John talks until dawn. You sleep through most of it.",
      effects = { { "heal", 12 } } },
    { label = "Buy his map of the Spire", outcome = "Pay 25g, one of 3 uncommon cards",
      result = "John draws the gates and patrols of Blackrock Spire on the back of a wanted poster.",
      effects = { { "pay", 25 }, { "cardChoice", n = 3, rarity = "uncommon" } } },
  },
})

event("mathredis_librams", {
  name = "The Libram Binder", act = 6, tier = 1,
  speaker = "Mathredis Firestar", npc = "mathredis_firestar", scene = "flame_crest", -- (camp)
  text = "\"I bind librams to armor and weapons. Bring me arcane components and the work is cheap. "
    .. "Without them, I charge in gold.\"",
  choices = {
    { label = "Pay for a binding", outcome = "Pay 45g, upgrade a card of your choice and a random card",
      result = "Mathredis reads the libram over your gear. The runes hold.",
      effects = { { "pay", 45 }, { "upgradeRandom", 1 }, { "upgrade" } } },
    { label = "Trade him a potion", outcome = "Lose a potion, upgrade 2 random cards",
      when = { { "potion" } },
      result = "Mathredis pours the potion into his ink and binds two runes.",
      effects = { { "losePotion" }, { "upgradeRandom", 2 } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Come back with components.\"",
      effects = {} },
  },
})

event("tinkee_incarcinatrix", {
  name = "The Draco-Incarcinatrix 900", act = 6, tier = 0,
  speaker = "Tinkee Steamboil", npc = "tinkee_steamboil", scene = "flame_crest", -- (road)
  text = "\"My Draco-Incarcinatrix 900 captures the essence of a dragonkin when it dies. I need field "
    .. "data! Wear it near the broodlings for a day, or fund my next prototype.\"",
  choices = {
    { label = "Wear the device", outcome = "-6 HP, +40g",
      result = "The broodlings attack whoever carries the device. Tinkee pays for the data.",
      effects = { { "loseHp", 6 }, { "gold", 40 } } },
    { label = "Fund the prototype", outcome = "Pay 30g. 50%: 75g",
      effects = { { "pay", 30 }, { "gamble", 0.5,
        win = { { "gold", 75 } },
        winText = "The prototype works. Tinkee sells it to Gadgetzan and pays you your share.",
        lose = {},
        loseText = "The prototype explodes. \"Version 901 will work!\"" } } },
    { label = "Leave", outcome = "Nothing",
      result = "Tinkee goes back to her soldering.",
      effects = {} },
  },
})

event("helendis_dragonkin", {
  name = "Dragonkin Menace", act = 6, tier = 1,
  speaker = "Helendis Riverhorn", npc = "helendis_riverhorn", scene = "morgans_vigil", -- (camp)
  text = "\"The black dragonkin on these slopes take orders from someone in Stormwind, and nobody there "
    .. "listens to me. Kill their dragonspawn and I will pay for the work. I can also treat your burns.\"",
  choices = {
    { label = "Clear the slopes", outcome = "Fight 2 dragonkin: usual reward + 20g",
      result = "You climb the slopes toward the dragonkin.",
      effects = { { "fight", "event_dragonkin", gold = 20 } } },
    { label = "Let him treat your burns", outcome = "Pay 20g, heal 30% of max HP",
      result = "Helendis covers your burns with a cold salve.",
      effects = { { "pay", 20 }, { "healPct", 0.30 } } },
    -- carte neutre débloquée par la première victoire du compte (§ 8)
    { label = "Buy his fire salve", outcome = "Pay 25g, Greater Fire Protection Potion (card)",
      when = { { "unlocked", "greater_fire_protection_potion", hide = true } },
      result = "\"One flask before you walk on the ash.\"",
      effects = { { "pay", 25 }, { "card", "greater_fire_protection_potion" } } },
  },
})

event("yuka_ribbly", {
  name = "Ribbly's Bounty", act = 6, tier = 2,
  speaker = "Yuka Screwspigot", npc = "yuka_screwspigot", scene = "flame_crest", -- (camp)
  text = "\"My brother Ribbly owes money to half the goblins in Kalimdor, and to me. Bring me his head "
    .. "and I split the bounty with you. Or buy something. Anyone who isn't Ribbly gets a discount.\"",
  choices = {
    { label = "Hunt Ribbly down", outcome = "60%: +55g, else -9 HP",
      effects = { { "gamble", 0.6,
        win = { { "gold", 55 } },
        winText = "You find Ribbly in a cave and bring back the proof. Yuka pays.",
        lose = { { "loseHp", 9 } },
        loseText = "Ribbly's hired guards were waiting. You fall back empty-handed." } } },
    { label = "Buy from her stock", outcome = "Pay 70g, a relic",
      result = "\"Good choice. It belonged to Ribbly.\"",
      effects = { { "pay", 70 }, { "relic" } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"If you see Ribbly, he owes me.\"",
      effects = {} },
  },
})

-- Rare : combat d'élite, proposé seulement en bonne santé.
event("cyrus_taste_of_flame", {
  name = "A Taste of Flame", act = 6, tier = 2, rarity = "rare",
  speaker = "Cyrus Therepentous", npc = "cyrus_therepentous", scene = "steppes_road", -- (hill)
  when = { { "hpAbove", 0.6 } },
  text = "\"You want to know what the Black Dragonflight is planning? Prove you are worth the answer. "
    .. "A molten giant named Volchan walks the lava under the bridge. Kill it.\"",
  choices = {
    { label = "Hunt Volchan", outcome = "Elite fight: elite reward + 40g",
      result = "You go down to the lava under the bridge.",
      effects = { { "fight", "event_volchan", kind = "elite", gold = 40 } } },
    { label = "Drink the essence he offers", outcome = "-5 max HP, one of 3 rare cards",
      result = "The essence of fire burns your throat. Cyrus watches you without a word.",
      effects = { { "loseMaxHp", 5 }, { "cardChoice", n = 3, rarity = "rare" } } },
    { label = "Refuse", outcome = "Nothing",
      result = "\"Then you will learn nothing.\"",
      effects = {} },
  },
})
```

Repères : Oralius, Marshal Maxwell, Helendis Riverhorn à Morgan's Vigil ; Mathredis Firestar, Tinkee
Steamboil, Yuka Screwspigot à Flame Crest ; Cyrus Therepentous à Slither Rock ; Ragged John sur la route.
Quêtes Classic d'origine : « Extinguish the Firegut », « The True Masters » et « Marshal Windsor »,
« Mother's Milk », librams de Mathredis, « Broodling Essence », « Dragonkin Menace », « Ribbly
Screwspigot », « A Taste of Flame ».

## 7. Cartes de zone (5, épiques, pivots)

Cartes définitives (épiques, pivots) : voir `docs/zones/cartes-de-zone.md`.

- Voidform (Priest)
- Anger Management (Warrior)
- Conflagration (Mage)
- Kidney Shot (Rogue)
- Black Arrow (Hunter)

## 8. Commun débloqué par la première victoire du compte

### Cartes neutres (2)

| id | Nom (métier) | Rareté | Coût | Type | Plaque | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|---|
| `greater_fire_protection_potion` | Greater Fire Protection Potion (Alchemy) | uncommon | 1 | Skill | Exhaust | Douse 3. / Gain 6 Absorb. | Douse 3. / Gain 9 Absorb. | `inv_potion_24` |
| `thorium_grenade` | Thorium Grenade (Engineering) | uncommon | 2 | Attack | Exhaust | Deal 10 to all. | Deal 13 to all. | `inv_misc_bomb_05` |

Repères : la potion vaut Rugged Armor Kit hors des Steppes (moins bien, pas de Retain) ; dans les Steppes,
c'est la réponse neutre au feu. La grenade est entre Rough Dynamite (1 : 6 à tous) et Goblin Sapper
Charge (2 : 5 PV, 14 à tous) ; dans les Steppes, chaque mort qu'elle cause recule le feu.

### Bibelots communs (3)

| id | Nom (objet réel) | Rareté | Effet | Icône |
|---|---|---|---|---|
| `blackrock_medallion` | Blackrock Medallion (quête « FIFTY! YEP! ») | common | `Whenever an enemy dies, gain 3 Absorb.` | `inv_jewelry_amulet_04` |
| `gortesh_head` | Gor'tesh's Lopped Off Head (quête « Gor'tesh the Brute Lord ») | uncommon | `At the start of each combat, apply Demoralized 1 to all enemies.` | `inv_misc_head_orc_02` |
| `draco_incarcinatrix` | Draco-Incarcinatrix 900 (quête « Broodling Essence ») | uncommon | `The first time an enemy dies in each combat, draw 2 cards.` | `inv_misc_enggizmos_19` |

Crochets existants : `onEnemyDeath`, `onCombatStart`. Demoralized posé avant le premier tour ennemi
réduit sa première attaque.

### Type de rencontre : WANTED

Une affiche de prime au camp de la zone, ajoutée au tirage de **toutes** les zones après la première
victoire du compte dans les Steppes (poids `common`, palier 0). Elle nomme une élite de la zone en cours.

```lua
event("wanted_poster", {
  name = "WANTED", act = nil, tier = 0,
  speaker = "Wanted poster", npc = "wanted_poster", scene = "camp",
  -- le texte cite le nom de l'élite tirée pour le combat (champ rempli à l'entrée)
  text = "WANTED: %s. Reward paid at the camp, on proof of death.",
  choices = {
    { label = "Take the bounty", outcome = "Elite fight: elite reward + 50g",
      result = "You follow the tracks given on the poster.",
      effects = { { "fight", "elite", kind = "elite", gold = 50 } } },
    { label = "Collect the small bounties", outcome = "-6 HP, +35g",
      result = "You bring in two lesser outlaws listed under the main notice.",
      effects = { { "loseHp", 6 }, { "gold", 35 } } },
    { label = "Leave", outcome = "Nothing",
      result = "You leave the poster on the board.",
      effects = {} },
  },
})
```

Point moteur : le nom de l'élite tirée doit être connu à l'entrée (tirage figé dans `exp.event.rolls`).
Icône : `inv_bountyhunting`.

## 9. Bibelots de clé (3)

Communs aux classes, plus forts que les communs, entrés dans la réserve après la première victoire à la clé
indiquée.

| Clé | id | Nom (objet réel) | Effet | Icône |
|---|---|---|---|---|
| +1 | `libram_of_resilience` | Libram of Resilience (Mathredis Firestar) | `The first time you would lose HP in each combat, lose none.` | `inv_relics_libramofhope` |
| +3 | `libram_of_voracity` | Libram of Voracity (Mathredis Firestar) | `Whenever an enemy dies, gain Strength 1 for this combat.` | `inv_relics_libramoftruth` |
| +5 | `heart_of_the_mountain` | Heart of the Mountain (quête de Maxwort Uberglint) | `At the start of your turn, if you have half your HP or less: +1 mana and draw 1.` | `inv_stone_15` |

- **Libram of Resilience** : annule le premier coup, la première brûlure ou le premier `Pay N HP`,
  tout entier. Contre un boss, c'est le Mortal Strike de 24.
- **Libram of Voracity** : les combats à plusieurs ennemis deviennent plus faciles à mesure qu'ils
  avancent ; dans les Steppes, chaque mort recule aussi le feu.
- **Heart of the Mountain** : la remontée. La brûlure fait passer sous la moitié ; le tour suivant
  donne 4 mana et 6 cartes. Mesurer qu'il ne pousse pas à rester bas exprès (Pay N HP).

## 10. Modèles et icônes

**Créatures.** `wow_creature_search` répond « No World of Warcraft install found » (le MCP ne connaît pas
`/mnt/Games/World of Warcraft`). Lancé hors MCP avec `WOW_INSTALL_PATH` (même code, lecture seule), il
trouve la base vide sur les clients Forever, Classic Era et Retail : aucune recherche par nom n'aboutit,
seule la recherche par identifiant d'affichage marche. Les identifiants de créature ci-dessous viennent
donc de la base Questie locale (fiable, ce sont ceux de Classic) ; **les identifiants d'affichage sont
non trouvés**. Pour les créatures non humanoïdes, le modèle probable (FileDataID, `wow_model_search`) est
indiqué ; il ne remplace pas l'affichage.

| Rôle | Nom | Créature | Affichage | Modèle probable |
|---|---|---|---|---|
| normal | Blackrock Soldier | 7025 | non trouvé | humanoïde (orc) |
| normal | Blackrock Sorcerer | 7026 | non trouvé | humanoïde (orc) |
| normal | Blackrock Worg | 7055 | non trouvé | `creature/worg/worg.m2` (1373320) |
| normal | Black Dragonspawn | 7040 | non trouvé | `creature/dragonspawn/dragonspawn.m2` (123543) |
| normal | Black Wyrmkin | 7041 | non trouvé | `creature/dragonspawncaster/dragonspawncaster.m2` (123577) |
| normal | Firegut Brute | 7035 | non trouvé | `creature/ogre/ogre.m2` (125263) |
| normal | Firegut Ogre Mage | 7034 | non trouvé | `creature/ogre/ogremage.m2` (125264) |
| normal | Flamekin Torcher | 9778 | non trouvé | `creature/fireelemental/fireelemental.m2` (123934), à confirmer |
| normal | Thaurissan Firewalker | 7037 | non trouvé | humanoïde (Dark Iron) |
| élite | Gruklash | 8979 | non trouvé | humanoïde (orc) |
| élite | Thauris Balgarr | 8978 | non trouvé | humanoïde (Dark Iron) |
| serviteur | Dark Iron Land Mine | 8035 | non trouvé | non trouvé |
| élite | Volchan | 10119 | non trouvé | `creature/moltengiant/moltengiant.m2` (524124) |
| boss | Grark Lorkrub | 9520 | non trouvé | humanoïde (orc) |
| serviteur | Ember Worg | 9690 | non trouvé | `creature/worg/worg.m2` (1373320) |
| rencontre | Oralius | 9177 | non trouvé | — |
| rencontre | Marshal Maxwell | 9560 | non trouvé | — |
| rencontre | Ragged John | 9563 | non trouvé | — |
| rencontre | Mathredis Firestar | 9836 | non trouvé | — |
| rencontre | Tinkee Steamboil | 10267 | non trouvé | — |
| rencontre | Helendis Riverhorn | 9562 | non trouvé | — |
| rencontre | Yuka Screwspigot | 9544 | non trouvé | — |
| rencontre | Cyrus Therepentous | 9459 | non trouvé | — |
| rencontre | WANTED (affiche) | — | — | icône seule |

**Icônes.** Toutes vérifiées présentes dans `~/Téléchargements/ICONS/` (source de `tools/build_media.py`) ;
`wow_icon_search` confirme aussi `spell_holy_prayerofmendingtga` et les familles `inv_relics_libram*`,
`inv_misc_bomb_*`.

| Usage | Icône |
|---|---|
| Wildfire (jeton, journal) | `spell_fire_burningspeed` |
| Stoke (intention) | `spell_fire_flameshock` |
| Douse (mot-clé) | `spell_frost_summonwaterelemental` |
| Cartes épiques (§ 7) | toutes présentes dans le pack ; `spell_holy_prayerofmendingtga` porte bien ce nom (avec « tga ») |
| Cartes de zone, neutres, bibelots | colonnes « Icône » des § 7, 8, 9 |

Choix approximatifs à revoir : `inv_misc_head_orc_02` pour une tête d'ogre (aucune icône de tête d'ogre
dans le pack), `inv_stone_15` pour Heart of the Mountain, `inv_jewelry_amulet_04` pour le médaillon
(icônes d'origine des objets non vérifiées).

## 11. Questions ouvertes

1. **Blaze qui monte de 2 par round.** Un combat de boss où le seuil de 90 PV tombe au tour 2 coûte
   20 PV de feu sur 4 rounds ; s'il tombe au tour 4, 6 PV. Avec +1 par round, ce serait 14 et 5 : le choix
   du seuil compte moins, le Mage (42 PV) et le Hunter (41 PV) souffrent moins. Garder +2 ?
2. **Une mort recule le feu d'un round.** Sans cette règle, trois Flamekin Torchers allument le sol au
   tour 2 quoi qu'on fasse et les classes de zone (Mage, Rogue Combat) perdent leur avantage ; avec elle,
   les combats à trois ennemis ne brûlent presque jamais si l'on tue dans l'ordre. Garder ?
3. **Lone Wolf retire le familier.** Pris en récompense, il rend injouables Kill Command et Bestial Wrath
   déjà dans le deck, et sans objet Arcane Shot (moitié de son texte) : un Hunter Beast Mastery ne doit
   jamais le prendre, un Hunter Marksmanship le prend toujours. Le garder aussi tranché, ou laisser le
   familier frapper encore une fois par tour (3, sans Frenzy) ?
4. **Le boss.** Grark Lorkrub est un orc élite réel de Blackrock Stronghold mais pas un chef de guerre
   connu ; Gruklash (rare, guerrier) pourrait prendre sa place et Grark devenir élite. Avec Grark, le boss a
   une histoire de quête (le traître de la Horde) ; avec Gruklash, il reste un rare sans histoire.
5. **Volchan qui se soigne du feu.** Sur un combat de 6 tours, il regagne environ 12 PV (125 → 137
   effectifs) et le joueur en perd 12 ; c'est l'élite la plus dure de la zone pour un deck sans Douse ni
   gros dégâts. Le garder ainsi, ou remplacer le soin par « Wildfire 2 » seul ?

## Implémentation (nuit du 13 au 14/11/2026)

Fichiers : `Data/Zones/Steppes.lua` (ennemis, groupes, rencontres, commun, bibelots de clé, décors de la zone),
`Core/ZoneRules/steppes.lua` (règle, actions `stoke` / `ignite`, condition `lit`, effet `douse`, mots du
langage, `ns.Wildfire` : état, prévision), `UI/Art/Zones/steppes.lua` (modèles, icônes, vue, décors peints),
`Sim/zones/steppes.lua` (bot), `Sim/tests_zone_steppes.lua` (33 tests), `Sim/ui_zone_steppes.lua` (UZS).

### La règle telle que codée

- État `c.zs.steppes = { left, max, blaze, step, lit }` posé à l'init : `left = max = T` selon le genre du combat
  (`ns.Encounters.steppes.wildfire = { normal = 3, elite = 4, boss = 4, blaze = 2, step = 2 }`), ou le plus petit
  champ `wildfire` des ennemis de départ (Volchan 2, Grark 4).
- `onRoundEnd` (rien si le tour ennemi a été sauté) : compte ≥ 1 → −1 (à 0 : « The ground ignites! », sans
  dégâts) ; compte déjà à 0 → `Combat.loseHp(c, blaze, "wildfire")`, puis Blaze + 2, puis `onWildfire` (n).
- `onEnemyDeath` : compte + 1 (plafond T), sauf serviteur et sauf mort du dernier ennemi principal.
- `{ "stoke", n }` : −n au compte, chaque point en trop + 2 à Blaze ; `{ "ignite", n }` : compte à 0, déjà à 0 :
  Blaze + n ; `{ "douse", n }` : compte + n (plafond T), rien hors des Steppes.
- Interface : jeton « Wildfire in 3 → 2 » (flamme grise) ou « Wildfire 4 → 6 » (rouge), infobulle qui dit ce
  qui arrive à la fin du round ; flamme à droite de toute intention avec Stoke et « +1 » dans la bulle ; brûlure
  de fin de round hachurée en rouge sur la barre de PV ; flamme grisée sous un serviteur (« its death does not
  delay Wildfire ») ; mots Wildfire, Douse, Stoke expliqués au survol.

### Ce qui diffère de la fiche, et pourquoi

- **Décisions du 13/11** appliquées : Blaze + 2, une mort recule d'un round, boss Grark Lorkrub, Volchan sans
  soin (« Wildfire 2 » seul ; le crochet d'ennemi `onWildfire` reste lu par la règle).
- **Nombres** : la fiche visait Westfall + 60 %. À l'arrivée dans la zone, le deck n'a que les cartes de la classe
  (cartes de zone pas encore écrites, `epic=none`) : la zone est réglée pour 55–70 % de victoires, ce qui ramène
  les PV et les dégâts près de ceux de Westfall (tableau plus bas).
- **Grark** : seuils à 50 % (phase 2, au lieu de 90/150 = 60 %) et 25 % (phase 3) ; à 60 %, la phase 2 tombait
  trop tôt pour les classes lentes (Priest : 18 PV de brûlure sur le boss). Phases 2 et 3 par `phases` du moteur
  (crans sur la barre, ouverture Torch the Field), motif de la phase 2 continué en phase 3 (IA `cycle`).
  Call the Pack : deux loups au plus.
- **Gruklash** : Frenzy en phase à 50 % (cran visible) plutôt qu'un `onDamaged` à 59 PV ; Strength 3.
- **Thauris Balgarr** : motif mine, shoot, net, shoot, mine remplacée par Shoot si deux mines vivent.
- **Blackrock Soldier** : Shield Bash gagne 6 Absorb (« le mur »).
- **Rencontres** : `zone = "steppes"`, `tier = 0` (la zone n'est ouverte qu'après les cinq premières : les paliers
  1–2 de la fiche ne servaient qu'à la Ligue, et compteraient dans le commun de Westfall et Duskwood). Décors :
  `camp` (Morgan's Vigil), `shop` (Flame Crest), `hill` (Slither Rock), `road`. « Half cooked » retiré du texte de
  Ragged John (figure de style).
- **Fire Protection Potion** : nom raccourci (« Greater Fire Protection Potion » sort du ruban de la carte).
- **WANTED** : rencontre commune (`zone = nil`, `tier = 6`), combat d'élite à groupe tiré à l'entrée ; le
  personnage est le crieur du camp (Town Crier) qui lit l'affiche (le harnais exige une créature).
- **Libram of Resilience** : `beforeHit` (coup qui passerait l'Absorb, après Parry) et `hpLoss` (brûlure, Pay N HP).

### Moteur, peintre, tests partagés (modifications génériques, à signaler)

- `UI/Scene.lua` : plans de zone `layers = { skyline, ground, front }` appelés par `S.landscape`, `S.paintKit`
  (formes et niveaux), `S.PROPS` (registre), `furrows = false` (sol sans rangs de champ). Westfall inchangée.
- `Core/Rewards.lua`, `Rewards.relicPool` : les bibelots de clé (champ `key`, sans `tier`) n'entrent plus dans
  l'ancien tirage (ils passaient pour des communs de palier 0).
- `Sim/tests.lua`, `Sim/tests_expedition.lua`, `Sim/ui_harness.lua` : les comptes de la fiche des neutres et des
  communs (paliers 0 à 3) ne comptent plus le commun des zones suivantes ; une zone jouable n'est plus « Coming
  later » mais « Locked » à l'accueil d'un compte neuf ; les rencontres d'une zone sont testées dans leur zone ;
  décors `shop` et `night` permis pour une rencontre.
