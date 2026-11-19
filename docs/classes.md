# Ajouter une classe (contrat du socle multi-classes)

État au 12/11/2026. Le socle est en place, le Priest y est migré (résultats de simulation identiques à
graine égale), le Warrior en est la preuve, le Rogue suit (fiche `docs/classes/rogue.md`). Ce document est le contrat des classes suivantes : une
classe s'ajoute sans toucher au moteur, à l'interface ni au harnais, sauf besoin nouveau (à signaler).
GDD : `docs/gdd-classes.md` (copie du Claude Doc) ; fiches de conception : `docs/classes/<classe>.md`.

## Fichiers d'une classe

| Fichier | Contenu | Obligatoire |
|---|---|---|
| `Data/<Classe>.lua` | cartes (`class = "<id>"`), bibelots de classe (`class = "<id>"`), définition `ns.Classes.<id>` | oui |
| `Core/Classes/<id>.lua` | règles propres : `ns.ClassRules.<id>` (crochets, état de classe), conditions, effets, états, mots du langage | si la classe a une mécanique |
| `UI/Art/<id>.lua` | icônes des cartes et bibelots, voies, icône de classe, pastille de ressource, `ns.ClassViews.<id>` | oui |
| TOC | `Data\<Classe>.lua`, `Core\Classes\<id>.lua` (après les Data de la classe), `UI\Art\<id>.lua` (après `UI\Art.lua`) | oui |
| `Media/Icons/*.tga` + `UI/SkinData.lua` | `build/venv/bin/python -I tools/build_media.py --icons-only` (ajoute seulement les icônes nommées par `UI/Art.lua` et `UI/Art/*.lua`) | oui |

Un nouveau fichier dans le TOC impose de **relancer le client** (`/reload` ne suffit pas).
Ordre de chargement actuel : `Core\*` (dont `Core\Language.lua`), `Data\Priest.lua`, `Data\Warrior.lua`,
`Core\Classes\warrior.lua`, `Data\Rogue.lua`, `Core\Classes\rogue.lua`, `Data\Act1.lua`… puis `UI\Art.lua`,
`UI\Art\warrior.lua`, `UI\Art\rogue.lua`, le reste de `UI\`.
`Core\Classes\warrior.lua`, `Data\Hunter.lua`, `Core\Classes\hunter.lua`, `Data\Act1.lua`… puis `UI\Art.lua`,
`UI\Art\warrior.lua`, `UI\Art\hunter.lua`, le reste de `UI\`.
Contenu commun : `Data\Neutral.lua` (cartes neutres) après les fichiers des classes, `UI\Art\neutral.lua`
(cartes neutres, bibelots communs ajoutés) après les arts des classes ; une classe nouvelle se place avant.
Fichiers communs que deux classes ajoutées en parallèle modifient toutes deux : le TOC et `UI/SkinData.lua`
(table `icons`, triée : conflit de fusion trivial, ou relancer `--icons-only` après la fusion).

## Définition de classe (`Data/<Classe>.lua`)

```lua
ns.Classes.warrior = {
  id = "warrior", name = "Warrior", order = 2, hp = 80,   -- order : place sur l'accueil
  resource = { id = "rage", cap = 5, keep = true },        -- id du registre du langage ; cap nil = sans
                                                           -- plafond ; keep = false : remise à 0 au début du tour
  deck = { "strike", "strike", ... },                      -- 10 cartes de départ
  startRelic = "battle_standard",                          -- bibelot de départ (noPool), ou nil
  paths = { { id = "arms", name = "Arms" }, ... },         -- les trois voies (champ path des cartes)
  survival = "absorb",                                     -- kill | control | heal | absorb (GDD)
  playable = true,                                         -- false : cachée sur l'accueil
  bot = {                                                  -- conseils aux bots de simulation (Sim/)
    resValue = 6,                                          -- valeur d'un point de ressource (10 = 1 PV)
    rating = { mortal_strike = 6, ... },                   -- note des cartes pour les choix (≈ 5 + écart/2)
    upgrade = { strike = 2.5, ... },                       -- valeur d'amélioration des cartes de départ
    remove = { defend = 1, strike = 1.5 },                 -- cartes à retirer d'abord
  },
}
```

L'expédition enregistre la classe (`exp.class`), le combat aussi (`c.class`) ; la méta est déjà par classe
(`meta.classes[id]`). Les visuels (icônes, couleurs) ne sont jamais dans `Data/` : voir `UI/Art/<id>.lua`.

## Cartes

Champs de `Data/Priest.lua` (name, cost, type attack|skill|power, rarity basic|common|uncommon|rare, path,
target, effects, text, up, cast, cooldown, exhaust, retain, power, hooks, level) plus :

| Champ | Règle |
|---|---|
| `up`, `up2`, `up3` | paliers d'amélioration (+1, +2, +3), chacun ne donne que ce qui change par rapport au précédent, `text` toujours redonné : `docs/ameliorations.md` (contrôle : `lua5.1 Sim/upgrades.lua`) |
| `class` | id de la classe ; absent = carte neutre (avec `neutral = true` : marchand et rencontres seulement, GDD ; `Data/Neutral.lua`) |
| `neutral`, `tier` | carte neutre : `neutral = true`, `path = "neutral"`, `noReward = true`, `tier` = palier commun qui la débloque (0 d'emblée, N = première victoire du compte dans la zone N, `docs/zones.md`) ; tirée par `Expedition.neutralPool` (emplacement « Neutral » du marchand, `{ "cardChoice", neutral = true }`), jamais par `cardPool` (récompenses) |
| `school` | champ libre (holy, shadow, fire, frost, arcane, nature…) : condition `school:<x>`, compteurs du tour, couleur |
| `payHp = N` | « Pay N HP. » en première ligne ; payé au jeu (crochet `payHp` pour le modifier), injouable s'il ferait tomber à 0 (raison `hp`) ; compte comme une perte de PV (`onHpLost`), n'est pas une attaque, ignore l'Absorb |
| `spend = N` | « Spend N: … » ; **au choix du joueur** : payé AU JEU si la ressource suffit (et si `spendNeed(c, inst)` le permet), sauf `Combat.play(c, i, t, { spend = false })` (action `{ "play", i, t, "nospend" }`, Maj enfoncée dans l'interface) ; `ctx.spent` à la résolution, gardé dans l'incantation ou la Trap |
| `minRes = N` | injouable sous N points de ressource (raison `resource`). Règle (décisions communes) : une carte dont TOUTES les clauses sont « Surge: … » porte `minRes = 1` ; une carte qui a une autre clause reste jouable à 0 et son Surge ne fait rien (Execute). Vérifié par le harnais |
| `trap = true` | « Trap. » en tête : posée dans `c.traps` (3 au plus, crochet `trapSlots`, raison `traps`), résolue à la prochaine attaque ennemie avec l'attaquant pour cible (`Combat.triggerTrap`), la plus ancienne d'abord, puis suit sa plaque |
| `slot = "nom"` | Power unique par emplacement (Seal, Demon, totem d'un élément) : en jouer un autre remplace l'ancien |
| `lasts = N` | Power à durée : retiré à la fin du N-ième round (crochet `powerLasts`) ; `c.player.powerTurns[uid]` |
| `replacedTo = "exhaust"` | un Power remplacé ou expiré part aux consumées (défausse par défaut) |
| `level` | niveau de classe (1 à 7) qui débloque la carte ou le bibelot (table du GDD, « Progression par classe » ci-dessous) ; lu par `Expedition.cardPool` / `relicPool` (`Expedition.unlocked`) et l'écran de progression. Plus de `rep` ni de Ligue |
| `zone = "<id>"` | carte de zone (avec `class`, sans `level`) = **carte épique** (`rarity = "epic"`), débloquée par la première victoire de la classe dans cette zone, introuvable autrement ; hors de la grille des niveaux (`Meta.classContent`), montrée par l'onglet « Zones » de l'écran Progress (`docs/zones.md`) ; une seule par expédition (`docs/expedition.md`, « Cartes épiques ») |
| `transforms = { [id] = id_variante }` | épique : tant qu'elle est dans le deck, ces cartes se jouent comme leur variante (`Card.applyTransforms`), avec l'état amélioré de l'originale |
| `variant = true` | variante d'une épique : jamais collectionnable (récompenses, marchand, rencontres, progression) ; donner une amélioration (`up`) si l'originale en a une |
| `innate = true` | « Innate. » (mot de plaque, en fin de texte) : la carte est dans la main de départ de chaque combat, **à la place** d'une carte piochée (main de 5 inchangée ; au-delà de 5 cartes Innate, les suivantes restent sur le dessus de la pioche) ; `Combat.placeInnate` |
| `deckHooks = { nom = f(c, src, …) }` | effet passif **tant que la carte est dans le deck** : crochets actifs tout le combat, quelle que soit sa pile (même contrat que les Powers, `src = { id, up, uid }`, passent après les Powers et avant les bibelots ; `c.passives`) |
| `whileInDeck = f(c, src)` | appelé une fois par exemplaire au début du combat (après `init` de la classe, avant `onCombatStart`) |

Raretés et voies : 34 cartes = 4 de départ (`rarity = "basic"`, `path = "start"`, `level = 1`) + 13 communes,
11 inhabituelles, 6 rares ; 10 par voie ; niveaux : voir « Progression par classe » (test « progression :
répartition exacte »). Ajouts hors grille décidés par le joueur, déclarés dans la table `EXTRA` de ce test :
Rogue, Nightblade (Subtlety, commune, niveau 3), soit 35 cartes.

### Effets (`Core/Effects.lua`) et options communes

Effets : `damage` (times, all, pierce, onHit, bonus), `absorb`, `apply` (état, n, all, self, `icon` = clé
d'art de la source), `heal`, `draw`, `mana`, `res` (« +N Rage. »), `surge` (« Surge: », toute la ressource,
`ctx.surge`), `tickDot` (déclenche tout de suite le DoT de la cible, ou de tous avec `all`), `loseHp`,
`interrupt` (`all = true` : tous les ennemis), `cleanse`, `fn` ; `loseHp` prend `safe = true` (laisse au moins 1 PV). Une classe ajoute les siens dans `ns.Effects`.
Options lues sur tous les effets :

- `cond = "nom"` : l'effet ne s'applique que si la condition est vraie, **lue à la résolution** ;
- `more = { { k, "cond" } }` : valeur + k si la condition est vraie (« Spend 2: deal 5 more. ») ;
- `per = { k, "montant" }` : valeur + k × montant (« deal 4 + 4 per Insanity », Shield Slam).

Conditions (`Combat.CONDITIONS[nom](c, ctx, cible)`) : `execute`, `spent`, `surged`, `status:<id>` (la cible
porte l'affaiblissement, ou le joueur le bienfait), `school:<x>`. Montants (`Combat.AMOUNTS`) : `surge`,
`res`, `block`, `regen` (Regen du héros, déclaré par le Druid : Swiftmend). Une classe enregistre les siens (`Combat.CONDITIONS.frozen = function(c, ctx, t) … end`).

Ressource lue par une carte (`minRes`, Spend) : `Combat.cardRes(c, d, commit)` = `c.player.res`, sauf si la
règle de classe déclare `cardRes(c, d, commit)` (Druid, Heart of the Wild : une réserve par forme ; « Épiques du
Druid » ci-dessous).
Fonctions utiles : `Combat.gainRes(c, n, why)` (bornée, événement `resource`), `Combat.spendRes`,
`Combat.surge`, `Combat.loseHp(c, n, why)`, `Combat.lastBreath(c, clé)` (vrai une fois par combat),
`Combat.removePower`, `Combat.castCount`, `Combat.castSlots`, `Combat.payHpOf`.

## Règles de classe et événements (`Core/Classes/<id>.lua`)

```lua
ns.ClassRules.warrior = {
  init = function(c, cls) cls.hurt = false end,       -- au début du combat, avant onCombatStart
  hooks = { onHpLost = function(c, cls, n, src, hpBefore) ... end, cost = function(c, cls, v, d, inst) ... end },
  botKey = function(c) return "..." end,              -- état qui distingue deux positions (bots)
  botValue = function(c, W) return 0 end,             -- valeur propre ajoutée à l'évaluation (bots)
}
```

Les crochets de la classe passent **avant** ceux des Powers, bibelots et affixes, avec `src = c.cls`.
Les mêmes noms servent aux Powers (`def.hooks`, src = instance) et aux bibelots (`relic.hooks`, src = id).
`c.cls` est l'**état de classe** : table de données simples (nombres, chaînes, booléens, tables), copiée en
profondeur par `Combat.clone`, sauvegardée avec le combat. Ressource : `c.player.res`.

Valeurs modifiées (`Combat.modify`, le crochet renvoie la nouvelle valeur) :

| Nom | Arguments après la valeur | Quand |
|---|---|---|
| `cost` | d, inst | coût d'une carte |
| `payHp` | d, inst | coût en PV d'une carte |
| `damage` | cible, d | dégâts d'un coup du joueur (avant Demoralized / Sundered) |
| `enemyDamage` | ennemi, joueur | dégâts d'un coup ennemi (aussi pour l'affichage des intentions) |
| `beforeHit` | ennemi, action | coup ennemi réellement porté, avant Absorb (Parry, Traps) : 0 = coup annulé |
| `apply` | état, cible, d | valeur d'un état posé sur un ennemi |
| `block`, `heal` | — | Absorb gagné, soin reçu |
| `target` | d, inst | cible d'une carte (rediriger) ; la cible retenue va dans `c.player.lastTarget` |
| `instantCast` | d, inst, commit | une carte Cast part tout de suite (autre source que l'état Instant) ; ne rien consommer si commit est faux. Interrogé **avant** l'état Instant (qui n'est alors pas consommé) ; cible visée dans `c.aim` (uid, nil = inconnue : `canPlay`) ; `Combat.castFits(c, d, inst, cible)` : emplacements pleins, la carte n'est légale (`legalPlays`) et jouable (`play`, raison `casting`) que sur une cible où elle part tout de suite (Fingers of Frost) |
| `trapSlots` | — | nombre de Traps posées au plus (3) |
| `castSlots` | — | nombre d'incantations tenues à la fois (1 ; Mage : 2) |
| `powerLasts` | d, inst | durée d'un Power à durée |
| `dotDecay` | unité | baisse du DoT après son tick (1 ; Agony : 0) |
| `blockKeep` | — | Absorb gardée au début du tour (0 : remise à 0 ; Gnomish Harm Prevention Belt : +5) |
| `cooldown` | d, inst | durée d'une recharge posée (`d.cooldown` ; 1 au moins : Hourglass Sand) |
| `replay` | inst, ctx | copies de la carte résolues tout de suite après elle, même cible (premier ennemi vivant si elle est morte), sans coût, la carte ne part qu'une fois ; `ctx.copy` vrai pour une copie, journal `replay` (Ironfoe ; Windfury Totem du Shaman) |
| `applySelf` | état | valeur d'un état posé sur le héros, toutes sources (Benediction : Regen +1) |
| `resCap` | — | plafond de la ressource (`resource.cap` ; Avatar : 10) ; `Combat.resCap(c)`, lu aussi par les crans et l'infobulle de la pastille (`UI/CombatView.lua` : au-delà de 5 crans, second arc) |
| `attackMult` | cible, d | multiplicateur des coups d'une carte Attack (1 ; Death Wish : 1,5), après `damage` (Strength et ajouts), avant Demoralized / Sundered, arrondi à l'inférieur |
| `canPlay` | d, inst | vrai par défaut ; une chaîne = la carte est injouable, la chaîne est la raison affichée (Titan's Grip : `"Only 1 Attack per turn."`) ; après `allow`, avant `d.canPlay` |
| `canGainBlock` | — | vrai par défaut ; faux = aucun Absorb gagné (Death Wish), avant le crochet `block` ; un gain ≤ 0 après `block` ne fait rien |
| `trapLaunch` | d, inst | faux par défaut ; vrai = la Trap demande une cible (`Combat.targetOf`, `Combat.needsTarget(inst, c)`) et se déclenche aussitôt sur elle (`Combat.launchTrap` : mêmes effets, `onTrapTriggered` avec why = `"launch"`), sans emplacement (jouable zone pleine) |
| `stealthBreak` | inst, d | Rogue : vrai par défaut ; faux = la première Attack profite de Stealth (lignes « Stealth: ») sans le retirer (Subterfuge ; la carte dit quand il tombe) |
| `petAbsent` | — | Hunter : faux par défaut ; vrai = plus d'attaque du familier (automatique, effet `pet`), pas de Frenzy gagné ; `Hunter.petPresent(c)` |
| `petAll` | — | Hunter : faux par défaut ; vrai = chaque attaque du familier frappe tous les ennemis vivants (+1 Frenzy une fois) ; `Hunter.petAll(c)` |
| `bearStrike` | — | Druid : base de la frappe de l'ours (`ns.Druid.STRIKE_BASE`, 1), avant la réserve ou le montant d'un Surge (Idol of Brutality : +2) ; `Druid.strikeBase(c)` |
| `blockKeep` | Absorb actuelle | (rappel) la valeur gardée ; fraction et plafond se calculent sur le 2e argument (`max(v, min(15, floor(block / 2)))`) |
| `retainPicks` | — | cartes gardées au choix en fin de tour (0 ; Traveler's Backpack : 1, une seule gérée) ; le choix est posé par `Combat.markRetain(c, uid)` avant la fin du tour (interface, `Bots.markRetain`), `Combat.retainCandidates(c)` = index proposés |
| `surge` | ctx | montant compté par les effets d'un Surge qui a dépensé quelque chose (Anathema : +2) ; la dépense ne change pas |
| `canPlay` | d, inst | vrai par défaut ; une chaîne rend la carte injouable avec cette raison (affichée telle quelle : Voidform), après les autres raisons de `Combat.canPlay` |
| `castAs` | d, inst | faux par défaut ; vrai = une carte Attack ou Skill qui n'est pas Cast part en incantation (`c.player.cast`, résolue au début du tour suivant, interruptible ; Inner Focus) |
| `regenHeal` | — | valeur soignée par le tic de Regen du joueur (la Regen elle-même ; 0 = ne soigne pas : Echo of Light) ; la Regen baisse ensuite de 1 comme d'habitude |
| `convertHit` | cible, ctx | dégâts d'un coup de l'effet `damage` après `calcDamage` (`Core/Effects.lua`) ; `false` = coup non porté, le crochet a posé autre chose à la place (Doomblade : un DoT) : ni dégâts, ni `onHit`, ni `onAttackHit` |
| `maxMana`, `drawPerTurn`, `enemyHp`, `canFlee` | — | inchangés |

Notifications (`Combat.fire`, un crochet qui renvoie true arrête la chaîne) :

| Nom | Arguments | Quand |
|---|---|---|
| `onCombatStart` | — | après `init`, avant le premier tour |
| `onReshuffle` | nombre de cartes | défausse remélangée dans la pioche pendant une pioche (Scroll of Intellect : un crochet peut piocher) |
| `onTurnStart` / `onTurnEnd` | — | début du tour joueur (après pioche et mana) / fin (avant la défausse) : Powers de fin de tour, familier, démon |
| `onRoundEnd` | — | après le tour ennemi, avant la baisse des durées |
| `onCardCommitted` | inst, d, cible | carte jouée, tous ses coûts payés, avant incantation ou résolution (Hot Streak, baguette) |
| `beforeCard` | inst, ctx | début de la résolution |
| `onCardPlayed` | inst, ctx | fin de la résolution (Rage par Attack, Deep Wounds) |
| `onCastStart` / `onCastResolved` | inst | incantation posée / résolue (incantation tenue seulement) |
| `afterCast` | inst, ctx, instantanée | toute carte Cast résolue, incantée ou sous Instant (Mirror Image) |
| `onHeal` | PV rendus, surplus | soin tenté du joueur (n > 0), toutes sources : PV réellement rendus et part au-delà du maximum (Prayer of Mending, Spirit Shell) |
| `onDamageDealt` | cible, PV perdus, ctx\|nil | coup du joueur qui fait perdre des PV à un ennemi (ctx de la carte, nil pour un coup sans carte : familier, riposte ; le DoT n'en est pas un). Un crochet qui inflige des dégâts doit filtrer sur ctx pour ne pas boucler |
| `onParry` | attaquant, dégâts annulés, charges restantes | Rogue : une charge de Parry consommée |
| `onTrapSet` / `onTrapTriggered` | inst (, attaquant) | Trap posée / déclenchée |
| `onAttackHit` | cible, ctx | chaque coup d'une carte Attack (poisons, Ignite) |
| `onSurge` | montant, ctx | Surge qui a dépensé quelque chose |
| `onPayHp` | n, inst | paiement « Pay N HP » (avant la perte) |
| `onSpend` | n, inst | Spend payé |
| `onResource` | variation, raison | ressource changée |
| `onHpLost` | n, source, PV d'avant | toute perte de PV du joueur (coup : l'ennemi ; « pay » ; « effect » ; nil = DoT) |
| `onPlayerHit` | ennemi, n | coup ennemi qui fait perdre des PV |
| `afterHit` | ennemi, PV perdus, absorbés | après chaque coup ennemi, même absorbé (ripostes, Traps) |
| `onStatusApplied` | unité, état, n | état posé |
| `onDotTick` | unité, n | après le tick d'un DoT |
| `onRegenTick` | n | tic de Regen du joueur (valeur avant la baisse), après le soin éventuel (`regenHeal`) : Echo of Light |
| `onEnemyDeath` | ennemi | mort d'un ennemi (Soul Shards) |
| `onPowerEnd` | inst, raison | Power remplacé (`replaced`) ou expiré (`expired`) |
| `onShift` | forme d'avant (nil au premier), forme nouvelle | Druid : changement de forme au jeu d'une carte, après les coûts, avant la résolution (Idol of the Wild, Wolfshead Helm) |
| `onBearStrike` / `onMoonkinPulse` | première cible, dégâts, raison | Druid : frappe de l'ours / coups à tous de fin de tour en Moonkin (`Combat.strike`) |
| `preventDeath` | — | le joueur tombe à 0 : true = sauvé (Last Breath) ; l'événement `saved` porte la source |
| `onVictory`, `onPotion`, `onFlee`, `preventInterrupt` | | inchangés |

États communs et règles d'état : `instant` (« Instant », commun au Mage et au Shaman : se cumule, se
garde ; la prochaine carte Cast en consomme 1 et se résout tout de suite, sans emplacement ni
interruption : `Combat.isInstant`) ; un état peut porter `max = N` (plafond : Parry 3), `flag = true`
(présent ou non, valeur 1, sans nombre affiché : Stealth), `clearAtTurnStart = true`. Drapeau
`c.player.flags.skipEnemyTurn` : le prochain tour ennemi est sauté (Feign Death). Hasard des cartes :
flux `c.rng.cards` (jamais `c.rng.ai`). `Combat.tickDot(c, unité)` déclenche un DoT hors du début de tour.

Affichage d'un état à drapeau (`flag = true`, Stealth) : jeton sans nombre sous le personnage, infobulle
sans nombre (`W.unitStatuses`, `W.addStatusLines`) ; sur une carte, la ligne d'état s'écrit sans nombre
(« Gain Stealth »), vérifié par le harnais U27. Un état posé sous condition d'état reste dans sa clause :
`{ "apply", "stunned", 1, cond = "stealth" }` ⇔ « Stealth: apply Stunned 1 ⌛ » (ligne d'état, en dernier,
sans point final ; U27 la reconnaît par le libellé, nom d'un état). Raison « resource » au pluriel
(« Not enough Combo Points. »).

Une classe peut émettre ses propres événements (`Combat.fire(c, "onShift", forme)`) : Powers et bibelots
de la classe s'y abonnent par le même mécanisme. Les règles de zone (`ns.ZoneRules`, `docs/zones.md`) passent
après la classe et ajoutent leurs événements (`onEffectEnd`, `onEnemyDamaged`, `enemyMove`, `onHeal`…),
auxquels Powers et bibelots peuvent aussi s'abonner.

Ordre d'un coup joué (`Combat.play`) : cible (crochet `target`), coûts payés **maintenant** (mana, PV,
Spend si la ressource suffit ; une carte Cast interrompue ne rend rien), compteurs du tour
(`c.turn.played`, `c.turn.byType[type]`, `c.turn.bySchool[école]`, remis à 0 au début du tour),
`onCardCommitted`, puis incantation ou résolution (conditions lues là).

Début du tour : Absorb à 0, états `clearAtTurnStart` retirés, DoT et Regen, ressource remise à 0 si
`keep = false`, **mana remis à son maximum**, incantations résolues (de la plus ancienne à la plus
récente : `c.player.cast` puis `c.player.castMore`), recharges, pioche, `onTurnStart`, intentions.
Une interruption ennemie coupe l'incantation **la plus récente**.

### Coup sans carte (`Combat.strike`, `Core/Companion.lua`, 18/11/2026)

Un coup du joueur porté sans carte (familier du Hunter ; Druid : frappe de l'ours, coups à tous de fin de tour de
Moonkin) passe par une seule fonction, qui ne lit aucune règle de classe :

`Combat.strike(c, why, base, target, log, event, opts)` → dégâts calculés sur la première cible (0 : aucun coup).

- Calcul : `Combat.calcDamage(c, c.player, cible, base [+ c.player.res], nil)` (cardDef nil : Strength et
  Demoralized du joueur, Sundered et Absorb de la cible ; ni bonus « Attacks » des cartes, Powers et bibelots, ni
  crochet `attackMult`). Le crochet `damage` de la classe est appelé avec `d = nil` : il doit le vérifier.
- `target` : une unité ennemie déjà choisie (morte ou nil : rien), `"last"` (`Combat.strikeTarget(c)` : la
  dernière cible visée vivante, sinon l'ennemi vivant le plus à gauche) ou `"all"` (chaque ennemi vivant, de gauche
  à droite).
- `log` : type du journal, une entrée par ennemi touché juste avant le coup, `{ t = log, dst, dmg, why }` (plus
  `all = true` quand le coup touche tous les ennemis) ; la vue de la classe l'anime (`event`).
- `event` : émis **une fois** après les coups (`Combat.fire(c, event, première cible, dégâts, why)`), sauf si le
  combat est fini ; `nil` = aucun.
- `opts` (facultatif, jamais modifié : une table constante peut resservir) : `res` (la ressource s'ajoute à
  `base`, relue à chaque coup), `all` (après la cible, chaque autre ennemi vivant), `less` (les ennemis autres que
  le premier prennent n de moins, jamais sous 0), `gain` / `gainWhy` (`Combat.gainRes` après les coups, avant
  l'événement), `count` / `total` (clés de `c.stats` : nombre de coups et dégâts), `kind` (genre du coup pour les
  crochets de zone, `c.hitKind`, posé le temps des coups puis remis ; `hitAll` vrai avec `"all"` ou `all`).
- Combat fini pendant les coups : les coups suivants, le gain et l'événement sont sautés.
- `Combat.strikeDamage(c, cible, base, addRes)` : dégâts du prochain coup (affichage, bots).

Exemples (Druid, à coder par la classe ; noms de journal et d'événement à elle) :

```lua
-- frappe de l'ours (fin de tour en Bear, « Bear strikes. ») : 1 + Frenzy sur la dernière cible, puis +1
Combat.strike(c, "auto", 1, "last", "bear_strike", "onBearStrike", BEAR) -- BEAR = { res = true, gain = 1, gainWhy = "strike" }
-- Surge (« Bear strikes once per Frenzy. ») : au montant compté, sans gain
Combat.strike(c, "surge", 1 + ctx.surge, "last", "bear_strike", "onBearStrike")
-- coups à tous de fin de tour en Moonkin : ceil(Charges / 2), 3 au plus, réserve lue sans gain
local n = math.min(3, math.ceil((c.player.res or 0) / 2))
if n > 0 then Combat.strike(c, "auto", n, "all", "moonkin_pulse", "onMoonkinPulse") end
```

## Langage des cartes (`Core/Language.lua`)

Registre partagé par le moteur, l'interface (couleurs, coupures, explications au survol) et le harnais.
Déjà déclarés : les ressources des classes (Insanity, Rage, Combo, Charge(s), Soul Shard(s), Frenzy, Holy
Power, Maelstrom, et la réserve du Druid `wild` : Reserve, Combo, Frenzy, Charge(s) selon la forme), les
conditions Execute, Surge, Spend N, Last Breath, Shadow, Frozen, Demon, Judgement, les mots « Pay N HP » et
« Bear strikes », les mots de plaque Epic, Power, Trap, Seal, Demon, Totem N, forme (Cat, Bear, Moonkin,
Tree), Cast, Cooldown N, Exhaust, Retain, Innate, et les déclencheurs de Power (« When hit », « HP lost »,
« Attacks », « Start of turn », « End of turn », « Each Absorb gain », « Cast cards », « Bear strikes » ; le
Druid ajoute « Cat Attacks » et « End of turn in Moonkin », et pour ses épiques « Form changes » et « Forms »).
Les conditions Shift, Caster, Bear, Cat, Moonkin et la plaque Shift (ancienne conception du Druid) sont
retirées (18/11/2026). Une classe en ajoute depuis ses fichiers :

```lua
local L = ns.Language
L.condition("stealth", { name = "Stealth", text = "bonus effect while in Stealth." })
L.trigger("Each enemy DoT tick")
L.plate("trap", { word = "Trap", head = true, text = "triggers on the next enemy attack." })
L.keyword("drain", { name = "Drain", text = "…" })
```

Les **états** (`ns.Statuses`) sont des mots-clés d'office (couleur, insécable, « Name: » = condition sur
l'état, explication) : un état propre se déclare dans `Core/Classes/<id>.lua` (`ns.Statuses.parry = {…}`,
`Art.statusShort.parry` pour la définition courte). Un état `clearAtTurnStart = true` est retiré au début
du tour du joueur. Explications : une phrase de 60 caractères au plus, « %s » = nom de la ressource de la
classe de la carte (dans la forme de la carte, voir ci-dessous), « N » = nombre.

### Ressource à noms multiples (Druid, 18/11/2026)

Une classe dont la ressource change de nom selon un état (le Druid : une seule réserve `c.player.res`, nommée
Combo en Cat, Frenzy en Bear, Charges en Moonkin, Reserve sans forme et en Tree of Life) la déclare **une
fois** dans le registre, avec une table `forms` ; la valeur reste unique (gains, Surge, Spend, `minRes`,
plafond inchangés), seul le nom change.

```lua
L.resource("wild", { name = "Reserve", text = "kept between forms, used by Cat, Bear and Moonkin.",
  forms = { cat = { name = "Combo", text = "…" }, bear = { name = "Frenzy", text = "…" },
    moonkin = { name = "Charge", plural = "Charges", text = "…" } } })
ns.Classes.druid = { …, resource = { id = "wild", cap = 5, keep = true } }   -- inchangé
L.resourceName("wild", 2, "moonkin")        --> "Charges"  (sans forme, ou "tree" : "Reserve")
L.cardResource(ns.Cards.shred)              --> "wild:cat" (carte form = "cat")
L.combatResource(c)                         --> "wild:bear" si c.cls.form == "bear"
```

- **Forme** = valeur du champ de carte `form` (`"cat"`, `"bear"`, `"moonkin"`, `"tree"`) et, en combat, de
  l'état de classe `c.cls.form` (`nil` = sans forme). Une forme sans entrée dans `forms` (Tree of Life) et
  l'absence de forme gardent le nom de base (`name`).
- **Clé de ressource** : `"wild"` ou `"wild:cat"` (`L.resourceKey(id, forme)`). `L.resources[clé]` rend
  l'entrée de la forme (`{ id, base, form, name, plural, text }`), si bien qu'une clé s'emploie partout où
  un id s'emploie : `L.resourceName(clé, n)`, `Art.keyword("res:" .. clé)`, `Art.keywordLine(clé de mot,
  label, n, clé de ressource)` (« Surge: spends all Combo for the effect. »). `pairs(L.resources)` ne parcourt
  que les ids de base ; `L.resourceKeys()` donne toutes les clés, formes comprises (triées).
- **Sur une carte**, le nom vient de la forme de la carte : `L.cardResource(d)` (clé de la ressource de sa
  classe dans `d.form`, `W.cardResource(d)` dans l'interface) ; une carte Cat écrit « +1 Combo. », « Surge:
  deal 4 + 4 per Combo. », une carte Bear « Spend 2: … » (expliqué « pays 2 Frenzy »). Une carte **sans
  forme** (Power) peut aussi nommer la ressource de la forme que nomme le libellé d'une clause (« Cat
  Attacks: +1 Combo. », « End of turn in Moonkin: +1 Charge and gain 4 Absorb. ») : `L.cardResourceKeys(d)`
  (sa clé d'abord, puis ces formes, d'après les mots de la plaque de forme, `L.formWord`). Le glossaire de la carte
  (`W.cardKeywords`) explique le nom par l'entrée de la forme, jamais par la ressource d'une autre classe qui
  porte le même nom (Combo du Rogue).
- **En combat** (pastille, chiffres flottants « +1 Frenzy », raison « Not enough … ») : `L.combatResource(c)`
  donne la clé dans la forme active ; branché dans `UI/CombatView.lua` et `UI/Controller.lua` (la raison d'une
  carte refusée nomme la ressource de la carte, `L.cardResource(d)`) ; sans effet pour les autres classes.
- **Harnais U27** : les noms d'un texte sont seulement ceux de `L.cardResourceKeys(d)` (`H.resourceWordErrors`) :
  une carte Cat qui écrit « Frenzy », une carte sans forme qui écrit « Combo » sans libellé « Cat … : », ou
  une carte d'une autre classe qui nomme une autre ressource (Frenzy sur un Rogue, Reserve) sont refusées.
  « +N <nom>. » de chaque effet `res`, accord singulier / pluriel et « per <nom> » des Surge se lisent dans
  la forme de la carte. Une classe à un seul nom ne déclare pas `forms` : rien ne change pour elle.

### Plaque lue sur une valeur (forme du Druid)

`L.plate(key, { field, values, head, name, text })` : un seul mot-clé pour plusieurs mots ; la carte porte le
mot de sa valeur (`d[field]`). Plaque de forme déclarée dans `Core/Language.lua` :

```lua
L.plate("form", { head = true, field = "form", name = "Form", text = "playing the card enters its form.",
  values = { cat = { word = "Cat", text = "Enters Cat (Combo). End of turn: next Attack costs 0." }, …,
    tree = { word = "Tree", name = "Tree of Life", text = "Enters Tree of Life. End of turn: gain Regen 1." } } })
L.plateWord(L.plateByKey("form"), ns.Cards.starfire)   --> "Moonkin" ; W.cardPills : « Moonkin · Cast »
L.plateKey(p, d)                                       --> "form:moonkin" (explication de cette forme)
```

- Premier mot de la plaque (avant Cast), jamais écrit dans `text` : la carte n'a qu'un champ `form` ; toléré en
  tête du texte (« Moonkin.\nCast.\n… »), retiré à l'affichage comme « Cast. » ; le harnais refuse un mot de
  forme ailleurs qu'en tête ou différent de `d.form`. Carte sans `form` : aucun mot.
- Explication : `L.plateByKey("form:cat")` = `{ word, name, text, inline = true }` ; `text` est la ligne
  entière de l'infobulle (textes de la fiche, § 1.8), le nom y est coloré (`W.inlineKeywordLine`) ; 60
  caractères, deux phrases et la ressource entre parenthèses permis pour ces seules lignes (harnais U27).
- `L.formWord(forme)` : mot d'une forme (`"tree"` → `"Tree"`), lu par `L.cardResourceKeys`.
- « Bear strikes » : mot `L.keyword("bearStrike", { name = "Bear strikes", pattern = "Bear strikes", … })`
  (« Bear strikes: hits the last target for 1 + Frenzy, then +1. », base 1 : la classe redéclare le mot si
  sa base change)
  et déclencheur `L.trigger("Bear strikes")`, pendant de « Pet attacks » (Hunter).

Forme des textes (vérifiée par le harnais U27 pour toute carte de `ns.Cards`) : une clause par ligne ;
« Pay N HP. » en première ligne ; « +N Rage. » (singulier / pluriel du registre) pour chaque effet `res`
sans condition ; « Spend N: … » ⇔ `spend = N` ; « Surge: … » ⇔ effet `surge` (« deal B + K per Rage. » ou
« Deal B. » puis « …: deal K per Rage. ») ; « Execute: … » ⇔ condition `execute` ; états posés en dernier
(« Gain » / « Apply », sablier pour une durée) ; aucun « you / your » ; libellé « Name: » connu du
registre ; aucune ressource d'une autre classe (ni d'une autre forme : `L.cardResourceKeys`) ; mot de forme
seulement en tête et égal à `d.form` (s'il est écrit). Le texte doit tenir dans le panneau (U22, toutes les
cartes). Le harnais examine aussi dix cartes factices d'une classe à formes (`H.installFormFakes`, U27).

## Interface (`UI/Art/<id>.lua`)

```lua
Art.cards.<carte> = { tga = "Ability_Warrior_Cleave", spell = 845, icon = "Interface\\Icons\\ability_warrior_cleave" }
Art.paths.<voie> = { name = "Arms", ring = hex("#b0743a"), ink = hex("#6b3f12") }
Art.relics.<bibelot> = { tga = "INV_Banner_02", … }
Art.classes.<id> = { tga = "ClassIcon_Warrior", wow = "WARRIOR",           -- wow = UnitClass("player")
  resource = { tga = "Ability_Warrior_FocusedRage", color = "attackText" } } -- pastille, chiffres flottants
Art.statusIcons.<clé> = { tga = … }        -- icône d'un état selon sa source (apply … icon = "bleed")
ns.ClassViews.<id> = { build = function(hôte, vue) end, render = function(hôte, combat, vue) end,
  tokens = function(combat, liste, vue) end, -- facultatif : notes sur les jetons des états du héros
  enemyMarks = true,                         -- facultatif : la vue marque des ennemis (place réservée)
  badge = function(combat) end,              -- facultatif : pastille propre (forme du Druid), voir ci-dessous
  badgeTooltip = function(tt, combat) end,   -- facultatif : infobulle de cette pastille
  event = function(hôte, ev, vue) end }    -- facultatif : animations propres (vue:Push(délai, fn))
```

- **Pastille propre à la classe** (`badge`, `badgeTooltip`, 18/11/2026, Druid) : `badge(c)` rend une table
  **fixe** (pas d'allocation à chaque rendu) `{ icon, key, ring, grey, color, always }` : `icon` = entrée
  d'icône de la pastille (`W.setIcon`), `key` = clé d'icône (changement d'icône quand elle change), `ring` =
  teinte `{ r, g, b }` multipliée sur l'anneau doré (`grey` : anneau désaturé), `color` = couleur `{ r, g, b }`
  des crans et des chiffres flottants « +1 … » (au lieu de `Art.classes[id].resource.color`), `always` =
  pastille visible même à 0 (le nombre reste caché à 0). `badgeTooltip(tt, c)` remplace l'infobulle générique.
  Sans ces champs, rien ne change (classes à un seul nom).
- **Nom de la ressource en combat** : la pastille générique, les chiffres flottants et la raison « Not enough … »
  lisent `L.combatResource(c)` (forme active) ; `Controller.reasonText(why, d)` prend la carte refusée quand elle
  est connue (main, sélection, jeu) et nomme alors la ressource **de la carte** (`L.cardResource(d)` : Ferocious
  Bite en Bear → « Not enough Combo. »). Pour une classe à un seul nom, l'id de base : inchangé.
- **Druid** (`UI/Art/druid.lua`) : `Art.druidForms[none|cat|bear|moonkin|tree]` (nom, icône, teinte, couleur,
  `badge`), `Art.druidForm(c)`, `Art.druidStrike(c)` (cible et dégâts de la frappe de l'ours),
  `Art.druidPulse(c, e)` (base et dégâts des coups à tous de Moonkin), `Art.druidLines(c)` (lignes de la
  pastille : réserve maintenant, « End of turn: … », Cast en attente) ; chiffres de la fiche sauf si la classe
  publie `ns.Druid.STRIKE_BASE`, `PULSE_PER`, `PULSE_MAX`. Détail : `docs/interface.md`, « Druid ».

- **Marque sur un ennemi** (`enemyMarks`, 16/11/2026 : cadre d'unité des ennemis refait, docs/interface.md,
  « Cadre d'unité des ennemis ») : une petite icône (13 au plus) posée par la vue au centre de
  `vue.slotOf[uid].markSpot`, au bout de la ligne du nom de l'ennemi, avant la case d'intention ; avec
  `enemyMarks = true`, `CombatView` y réserve la place (le nom se tronque avant). Cible du familier (Hunter),
  Atrophic Poison (Rogue). Plus rien à côté du cadre : les cadres voisins se touchent presque à 5 ennemis.

- **Pastille de ressource** (générique, `UI/CombatView.lua`) : petit anneau doré près du mana, icône de la
  ressource de la classe jouée, nombre, cachée à 0 ; infobulle = explication du registre et « n / plafond ».
- **Zone libre de classe** : cadre de 300 × 40 sous les états du héros ; `build` une fois par classe,
  `render` à chaque rendu du combat (formes du Druid, totems du Shaman, Seal du Paladin, familier du
  Hunter). Pas de cadre enfant dans un visuel survolable (docs/interface.md) ; ne lire que `c`.
  La vue peut aussi poser des éléments dans la scène (cadres ancrés au parent de l'écran, `vue.parent`,
  personnage par `Scene.figure` : le familier du Hunter) et viser les ennemis par `vue.slotOf[uid]` ; ce qui
  n'est pas enfant de l'hôte se cache avec lui (`OnHide` de l'hôte). **Aucun texte permanent** dans la zone
  (il passait sur le modèle du héros) : voir « Notes sur les jetons ».
- **Notes sur les jetons** (`tokens`, facultatif ; 16/11/2026) : appelé à chaque rendu complet des états du
  héros, avant l'affichage de la rangée (épique en jeu `epic = true`, puis les pouvoirs `card:<id>`). La vue y
  note ce qu'une épique ou un pouvoir fait maintenant par `W.noteToken(liste, "epic" | clé, ligne, n, inactive)` :
  `ligne` = texte (ou liste de lignes, `{ texte, r, g, b }`) de l'infobulle sous le nom de la carte, `n` =
  compteur court écrit sur l'icône comme le nombre d'un état (« 2/3 », « 4 », « +5 » ; seulement si le
  nombre change pendant le combat), `inactive` = icône désaturée et assombrie (« No Frozen enemy »). Une
  ligne purement descriptive (« Cast cards hit twice ») = icône seule. La vue peut ajouter un jeton (deuxième
  incantation du Mage : `{ icon, text, key, info = { card = instance, now = lignes } }`). Lignes et compteurs :
  `Art.<classe>EpicLine(c)` (Mage : `Art.mageEpicText`) → ligne, compteur, inactive, lus aussi par le harnais.
- **Événements de la classe** (`event`, facultatif) : `CombatView:QueueEvent` appelle
  `ns.ClassViews[classe].event(hôte, ev, vue)` pour CHAQUE événement du journal, avant le traitement commun ;
  la vue y met ses animations dans la file commune par `vue:Push(délai, fn)` (bond du familier sur
  `{ t = "pet_attack" }`, le chiffre de dégâts venant de l'événement « damage » qui suit).
- **Portrait** : visage du personnage si sa classe de jeu (`UnitClass`) est celle de l'expédition, sinon
  l'icône de classe. Nom de classe dans le bandeau et sur le cadre du héros.
- **Accueil** : une classe jouable apparaît d'office (ordre `order`) ; jusqu'à deux, grands boutons ; au-delà,
  grille de trois colonnes (PV, cartes et niveau de classe en infobulle), le reste du panneau descend.
- Corps des cartes (`Art.cardBody`) : violet = école shadow, bleu = premier effet d'Absorb, or = départ,
  ivoire = le reste ; `Art.cards[id].body` force une couleur. Carte neutre (sans classe) : ivoire teinté
  vert sauge, toujours (`Art.cardBodyTint`, `Art.bodyTints.neutral`, couleur de sommet ; aucune texture de plus).

## Bibelots de classe

`class = "<id>"` + `level` (1..7, pas de `tier`) : tirés seulement pour cette classe (récompenses, coffres,
marchand, rencontres, bibelot au choix du départ), dès que la classe a ce niveau. Bibelots de clé
(`key = { zone, level }`, `class` facultatif) : `docs/zones.md`. Le bibelot de départ
porte `noPool = true`, `level = 1` et `startRelic` dans la définition de classe : porté à chaque expédition.
Six par classe (GDD) : niveau 1 = le bibelot de départ et un autre ; 3 et 5 = un ; 7 = deux.

## Progression par classe

Table du GDD (`docs/gdd-classes.md`), vérifiée pour chaque classe jouable par le test « progression :
répartition exacte » : niveau 1 = 4 cartes de départ + 6 par voie (22) et 2 bibelots ; 2, 4 et 6 = une carte
par voie ; 3 et 5 = un bibelot ; 7 = une rare par voie et 2 bibelots (34 cartes, 6 bibelots). Expérience,
seuils et règles : `docs/expedition.md`, « Niveau de classe ». Mage, Rogue, Hunter, Druid : niveaux de leur
fiche (`docs/classes/<classe>.md`, § Progression). Priest : `docs/classes/priest-progression.md`.

Rares du niveau 1 : aucune, ou plusieurs, mais jamais une seule carte qui ne vaut qu'une fois par combat. Une
récompense de boss ne tire que des rares (`boss = { rare = 1 }`) : avec une seule rare débloquée, elle n'offre
que cette carte, que le joueur reprend à chaque boss. Le Druid avait Rebirth (Last Breath) seule au niveau 1 :
2,7 exemplaires par expédition au bot `human`, 1,3 % de victoires en compte neuf ; Rebirth passée au niveau 4
(18/11/2026, `docs/equilibrage.md`, « Druid : compte neuf »).

En plus du niveau (campagne par zones, 13/11/2026, `docs/zones.md`) : chaque classe a **une carte de zone
par zone** (`zone = "<id>"`, débloquée par sa première victoire dans la zone ; à écrire, aucune aujourd'hui),
et les bibelots de clé (+1, +3, +5 de chaque zone) entrent dans son tirage à sa première victoire à cette
clé. Gagner une zone avec une classe ouvre la zone suivante pour elle seule ; ses clés sont comptées par zone.

| Niveau | Priest : Discipline / Shadow / Holy | Warrior : Arms / Fury / Protection |
| --- | --- | --- |
| 1 | Radiance, Solace, Angelic Feather, Penance, Schism, Pain Suppression / Mind Flay, Mind Blast, Vampiric Touch, Devouring Plague, Silence, Shadowform / Holy Fire, Holy Nova, Renew, Chastise, Greater Heal, Spirit of Redemption | Rend, Overpower, Colossus Smash, Execute, Pummel, Bladestorm / Raging Blow, Whirlwind, Victory Rush, Battle Shout, Rampage, Recklessness / Shield Block, Revenge, Devastate, Shield Slam, Ignore Pain, Last Stand |
| 2 | Evangelism / Mind Sear / Flash Heal | Cleave / Bloodthirst / Thunder Clap |
| 4 | Luminous Barrier / SW: Death / Halo | Slam / Berserker Rage / Demoralizing Shout |
| 6 | Shadow Mend / Psychic Scream / Empyreal Blaze | Mortal Strike / Onslaught / Retaliation |
| 7 (rares) | Rapture / Void Eruption / Apotheosis | Deep Wounds / Enrage / Shield Wall |

| Niveau | Bibelots du Priest | Bibelots du Warrior |
| --- | --- | --- |
| 1 | Sacred Candle (départ), Mindtap Talisman | Battle Standard (départ), Hand of Justice |
| 3 | Benediction | Diamond Flask |
| 5 | Robes of Prophecy | Lionheart Helm |
| 7 | Anathema, Truefaith Vestments | Force Reactive Disk, Skullflame Shield |

Warrior (réparti le 12/11/2026, d'après l'esprit des fiches ; revu le même jour, `docs/equilibrage.md`,
« Passe 2 ») : au niveau 1, chaque voie garde son moteur avec ses 6 cartes — Arms : Sundered (Colossus Smash)
payé par Overpower, Rend, Execute par la Rage ; Fury : petites attaques, Strength (Battle Shout,
Recklessness), PV payés (Rampage, Recklessness) ; Protection : Absorb converti (Shield Slam), Ignore Pain,
Revenge — avec l'Interrupt (Pummel) et le Last Breath (Last Stand). Une rare par voie reste au niveau 1
(Bladestorm, Recklessness, Last Stand). Les cartes verrouillées ouvrent une façon de jouer et valent plus
que la moyenne du niveau 1 (sinon monter de niveau n'apporte rien : le niveau 7 faisait jeu égal avec le
niveau 1) : la zone (Cleave, Thunder Clap au 2), la Strength à chaque recharge (Bloodthirst au 2), le Cast
(Slam au 4), la Rage sans attaquer (Berserker Rage au 4), le Demoralized gratuit (Demoralizing Shout au 4), la pioche par la Rage (Onslaught au 6), le gros
coup (Mortal Strike au 6), les ripostes (Retaliation au 6) ; au 7, les moteurs rares (Deep Wounds, Enrage,
Shield Wall). Bibelots : la commune au 1, les inhabituelles au 3 et au 5, les rares au 7.

## Bibelots communs : utiles à la classe

Un bibelot commun (sans `class`) peut porter `needs` : genre de cartes que la classe doit avoir pour
qu'il lui soit proposé (`Expedition.usefulFor`, appliqué par `Expedition.relicPool` et
`Rewards.relicPool`) : `"cast"`, `"castDamage"` (Cast qui inflige des dégâts), `"cooldown"`, `"exhaust"`,
`"retain"`, `"attack"`, `"absorb"`, `"damage"` (`Expedition.classHas(classe, clé)`, cartes de la classe
seulement), une liste de clés (toutes requises) ou une fonction(classe). Aujourd'hui : le Rogue (ni Cast
ni Absorb) ne se voit proposer ni Talisman of Focus, ni Talisman of Ephemeral Power, ni Gnomish Harm
Prevention Belt. Une classe nouvelle n'a rien à déclarer : le filtre lit ses cartes.

Crochets d'expédition ajoutés pour les bibelots communs (`Expedition.modify` / `fire`) : `goldBonus`
(ajouts fixes, après les pourcentages de `gold`), `removePrice` (prix du retrait ; `exp.shop.removed` =
retraits de la visite), `Expedition.addPotionSlot(exp)` (emplacements = longueur de `exp.potions`,
transmise au combat), `Expedition.randomPotion(exp, rng)`, `Expedition.upgradeRandom(exp, n, rng)`.

## Simulation et bots

`luajit Sim/sim.lua runs=2000 bot=heuristic jobs=8 runner=expedition key=0 class=<id>` ; balayage des
cartes : `… sweep=cards runs=300` (chaque carte ajoutée de force au deck de départ ; `level=N` : cartes et
expédition au niveau N, 7 par défaut). Une seule
simulation à la fois, `jobs=8` au plus. Les bots jouent les formes communes sans code de classe (ils
simulent chaque coup sur une copie) ; une classe les guide par `bot` (définition), `botKey` et `botValue`
(règles), et `Bots.POWER_VALUE[id]` pour un Power dont la valeur n'est pas la valeur par défaut. Cibles
et mesures (12/11/2026 : 62–72 % au niveau 1 sur un compte neuf, 72–82 % au niveau 7 avec tout le
commun, `zones=7` (ex-« Ligue exaltée »), clé 0) : `docs/equilibrage.md` ; notes des cartes du bot tirées des balayages (méthode au même endroit).
Build piloté par l'épique du deck (`Sim/expedition.lua`) : `bot.byEpic[id] = { rating, upgrade, remove }`, chacun
une table `{ [carte] = note }` ou une fonction `(exp, carte) -> note|nil`, prime sur `bot.rating` / `upgrade` /
`remove` tant que l'épique est dans le deck (choix des récompenses, rencontres, marchand, feu de camp, retraits) ;
`bot.epic(exp, id)` note les épiques proposées (exemple complet : `Data/Rogue.lua`).

## Exemple minimal

```lua
-- Data/Rogue.lua
local _, ns = ...
local function card(id, t) t.id, t.class = id, "rogue" ns.Cards[id] = t end
card("sinister_strike", { name = "Sinister Strike", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 6 }, { "res", 1 } }, text = "Deal 6.\n+1 Combo Point.",
  up = { effects = { { "damage", 9 }, { "res", 1 } }, text = "Deal 9.\n+1 Combo Point." } })
card("eviscerate", { name = "Eviscerate", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "damage", 5, per = { 5, "surge" } } },
  text = "Surge: deal 5 + 5 per Combo Point.", up = { … } })
ns.Classes.rogue = { id = "rogue", name = "Rogue", order = 3, hp = 70,
  resource = { id = "combo", cap = 5, keep = true }, deck = { … }, startRelic = "thieves_tools",
  paths = { … }, survival = "kill", bot = { resValue = 4, rating = { … } } }

-- Core/Classes/rogue.lua
local _, ns = ...
ns.Statuses.parry = { name = "Parry", text = "Cancels the next attack, up to 8 damage." }
ns.ClassRules.rogue = { hooks = {
  beforeHit = function(c, cls, dmg)
    local p = c.player
    if (p.st.parry or 0) > 0 and dmg <= 8 then ns.Combat.applyStatus(c, p, "parry", -1) return 0 end
    return dmg
  end } }
```

## Les mécaniques du GDD et leur point d'accroche

| Mécanique | Point d'extension |
|---|---|
| Rage (Warrior) | `onHpLost` + `onCardPlayed` de classe, `Combat.gainRes`, plafond `resource.cap` |
| Parry, Stealth (Rogue, fait) | états de classe (`max = 3`, `flag = true`) ; `beforeHit` coup par coup, avant l'Absorb (annuler jusqu'à 8) ; Stealth consommé dans `onCardCommitted` (au jeu, aussi pour une Attack en Cast), l'uid de la carte gardé dans `c.cls.openers` jusqu'à sa résolution ; condition `stealth` (`Combat.CONDITIONS`) : Attack = elle l'a consommé, autre carte = état posé ; miroir `c.cls.hidden` pour Flash Powder (gain réel seulement) |
| Envenom, Exsanguinate | effet `tickDot`, `Combat.tickDot` ; effets propres `dotPer` (« Surge: apply DoT K per Combo Point. »), `tickDotPer`, `randomHits` (Killing Spree, flux `c.rng.cards`) dans `Core/Classes/rogue.lua` |
| Combo Points, coups de grâce | ressource `combo`, effet `surge` + `per`, `minRes` |
| Seals et Judgement (Paladin) | Power `slot = "seal"` ; condition `judgement` (registre prêt) à enregistrer dans `Combat.CONDITIONS` ; effet propre « déclenche le Judgement du Seal » dans `ns.Effects` |
| Holy Power, Spend 3 | ressource `holy` (cap 3), `spend = 3` |
| Instant, double Cast (Mage) | état commun `instant`, `castSlots` = 2, file `cast` + `castMore` (interruption : la plus récente), `onCastResolved`, `onCardCommitted` + `c.turn.bySchool` (Hot Streak), condition `school:fire` |
| Pay N HP, démon (Warlock) | `payHp` (crochet `payHp`, `onPayHp`), Power `slot = "demon"`, `replacedTo = "exhaust"`, `onTurnEnd`, `c.player.lastTarget`, `dotDecay`, `onDotTick`, `onEnemyDeath` |
| Powers de fin de tour | `onTurnEnd` sur le Power (avant la défausse) |
| Familier (Hunter) | `ns.Hunter.petAttack(c, why, frenzy)` (Core/Classes/hunter.lua ; `Hunter.petAttackOn(c, why, ennemi)` : cible imposée le temps d'une attaque, Trap Launcher, Black Arrow) : coup sans carte commun `Combat.strike` (Core/Companion.lua, « Coup sans carte » ci-dessus ; le Hunter y ajoute `PET_BASE`, `petAbsent`, `petAll` / `petLess`) sur `c.player.lastTarget` ou le premier ennemi vivant, journal `pet_attack`, événement propre `onPetAttack` ; attaque automatique dans le crochet de classe `onTurnEnd` ; effet `{ "pet", n }` (`surge = true` : Bestial Wrath) ; Frenzy = ressource, -1 dans `onRoundEnd` ; condition `careful` (Careful Aim, verdict pris dans `beforeCard`) ; affichage et animation dans `ns.ClassViews.hunter` (`build`, `render`, `event`) |
| Traps (Hunter) | commun : `trap = true`, zone `c.traps`, déclenchement avant les coups de l'attaque (`Combat.triggerTrap`), `onTrapTriggered` |
| Stunned pendant le tour ennemi (Trap, riposte) | commun : `Combat.applyStatus` pose `e.stopTurn` si l'ennemi est celui qui agit (`c.acting`) ; `executeMove` arrête le tour avant le coup suivant (aucun coup de l'attaque qui a déclenché l'effet), consomme une charge, journal `{ t = "stunned", stopped = true }` ; « act » n'est journalisé qu'à la première action qui part (`decisions.md`) |
| Totems à durée et emplacements (Shaman) | Power `slot = "fire"…`, `lasts = N` (+ `totem = N` pour la plaque), `powerLasts` (Totemic Relic), `onPowerEnd` ; affichage des quatre emplacements dans `ns.ClassViews.shaman` |
| Maelstrom à 5 : Cast instantané | `onResource` + `instantCast` |
| Formes portées par les cartes, réserve lue selon la forme (Druid, fiche `docs/classes/druid.md`, 18/11/2026) | champ de carte `form` (`"cat"`, `"bear"`, `"moonkin"`, `"tree"`) ; état de classe `c.cls.form` (`nil` au début du combat : sans forme) ; changement au jeu dans le crochet de classe `onCardCommitted` (après les coûts, avant incantation ou résolution), événement propre `onShift(from, to)` ; réserve = ressource commune (`cap = 5`, `keep = true`), Surge, Spend, `minRes` inchangés ; Moonkin : crochet `damage` (comme le Mage) ; effet de fin de tour de la forme active dans `onTurnEnd` : Bear, frappe (comme le familier) et −1 dans `onRoundEnd` ; Cat, état à drapeau Clearcasting (comme Stealth, consommé dans `onCardCommitted`) et crochet de classe `cost` à 0 pour une Attack sans `cast` (comme Slice and Dice) ; Moonkin, coups sans carte à tous (`ceil(res / 2)`, 3 au plus) ; Tree of Life, `Combat.applyStatus(c, c.player, "regen", 1)` ; langage en place (18/11/2026) : plaque de forme lue sur `d.form`, ressource `wild` à noms par forme (`L.cardResource`, `L.combatResource`, « Ressource à noms multiples » ci-dessus), mot « Bear strikes », harnais U27 ; ancienne conception (conditions `shift`, `caster`, `bear`, `cat`, `moonkin`, plaque `shift`) retirée ; frappe de l'ours et coups de Moonkin par `Combat.strike` (genre `"pet"` et crochet de zone `petTarget` pour la frappe, `"other"` à tous pour Moonkin), crochet `bearStrike` ; codé le 18/11/2026 (`Core/Classes/druid.lua`, `Data/Druid.lua`, `Sim/tests_druid.lua`, fiche § 8) ; reste à l'interface : pastille par forme, marque de forme en main |
| DoT selon la source | `apply … icon = "poison"` → `unit.stIcon`, `Art.statusIcons.poison` |

## Cartes épiques : points d'accroche (13/11/2026)

Socle posé pour les 35 épiques (`docs/zones/cartes-de-zone.md`), sans carte réelle ; chaque point a son test
avec une carte factice dans `Sim/tests_epic.lua`. Existants et vérifiés : `onDotTick` (« quand un DoT tique »),
`replay` et la nouvelle `Combat.copyCard(c, inst, cible)` (rejouer / copier un effet : résolution d'une copie,
`ctx.copy`, la carte ne bouge pas), `blockKeep` (Absorb conservé, fraction et plafond), `onTrapTriggered`.
Nouveaux : `onHeal`, `onDamageDealt`, `onParry`, `afterCast` (notifications) ; `resCap`, `attackMult`,
`canGainBlock`, `trapLaunch`, `stealthBreak`, `petAbsent`, `petAll` (valeurs) ; champs de carte `innate`,
`deckHooks`, `whileInDeck`, `transforms`, `variant` (tableau « Cartes » ci-dessus). `Combat.dealDamage` prend un
6e argument `ctx` (passé par l'effet `damage` et par `randomHits`). `Combat.fire` ne passe que trois arguments :
un événement nouveau en a trois au plus.

**Règle finale (14/11/2026) : une épique est une règle en jeu dès le début de chaque combat**
(`docs/expedition.md`, « Cartes épiques »). `Combat.new` la pose dans `c.epic = { id, up, uid }`, hors de toute
pile ; elle n'a pas de coût et ne se joue jamais. Contrat pour écrire une épique :
- **Crochets** : `deckHooks` (même nom, même signature qu'avant : `(c, src, ...)`) et/ou `hooks` (comme un
  Power) ; les deux sont actifs tout le combat, `src = c.epic`, et passent **après** les pouvoirs, les bibelots et
  les affixes (`Combat.modify`, `Combat.fire`) ; `hooks.allow` / `deckHooks.allow` comptent dans
  `Combat.canPlay` (raison `"forbidden"`). `whileInDeck(c, src)` : une fois au début du combat, après `init` de la
  classe, avant `onCombatStart`. Les crochets de classe (`ns.ClassRules`) passent toujours en premier.
- **Champs** : `rarity = "epic"`, `class`, `zone`, `name`, `type` (libre, `"power"` conseillé), `effects = {}`
  (jamais résolus), `text` (commence par « Epic. », retiré à l'affichage et montré sur la plaque du bas ; jamais
  « Power. »), `up` (amélioration au feu de camp : texte et valeurs lus par les crochets via `src.up` ou
  `Card.def(src)`), `transforms` / variantes (`variant = true`) inchangés. `cost` facultatif (jamais payé ni affiché).
- **Plafond de ressource** : le crochet `resCap` (Avatar : 10) est lu par les crans de l'interface
  (`Combat.resCap(c)`, deux arcs au-delà de 6).
- Pas d'`innate` ni de logique de pioche ou de main pour une épique : elle n'est jamais dans une pile. Le mot
  `Innate` reste pour les cartes ordinaires.

### Épiques du Prêtre (14/11/2026)

Les sept épiques sont écrites (`Data/Priest.lua`, règles et crochets dans
`Core/Classes/priest.lua` : `ns.Priest`, deckHooks posés sur les définitions, src = `c.epic`, nombres réglables `ns.Priest.*`,
`ns.ClassRules.priest` = `botValue` / `botKey` seulement ; vue `ns.ClassViews.priest` dans `UI/Art/priest.lua` ;
tests `Sim/tests_epic_priest.lua`, harnais UEP). Points ajoutés au moteur : valeurs `canPlay`, `castAs`, `regenHeal`,
notification `onRegenTick` ; le crochet `payHp` est interrogé aussi pour une carte sans `payHp` (base 0 : Shadow
Covenant). Inner Focus multiplie
dégâts, Absorb, soin, DoT et Regen pendant la résolution de la carte incantée par ses propres crochets (`beforeCard`
/ `onCardPlayed` + `damage`, `block`, `heal`, `apply`, `applySelf`) : le soin d'Atonement de cette carte est
multiplié aussi. Bots : `classDef.bot.byEpic[id]` (cartes centrales, améliorations, retraits de chaque build),
`classDef.bot.epic(exp, id)` note l'épique selon les cartes centrales déjà prises.

**Réglage par zones (14/11/2026, brief `build/brief-epiques-reglage.md`).** Mesure de référence : `runner=expedition
class=priest level=7 key=0 bot=heuristic runs=600`, `zone=duskwood zones=1`, `zone=stranglethorn zones=3`,
`zone=steppes zones=5` ; gain = victoires avec l'épique imposée (`epic=<id>`) − victoires `epic=none`
(66,5 / 62,5 / 52,3 %). Outils : `build/prs_measure.sh`, `build/prs_table.py`, `build/prs_tune.lua` (réglages
essayés par `PRS_TUNE`, sans toucher au code ; non versionnés). Rapports `reports/prs-*.txt`.

| Épique | Règle (base / améliorée) | Duskwood | Stranglethorn | Steppes | Moyenne | PV perdus / combat normal | Changement |
|---|---|---|---|---|---|---|---|
| Prayer of Mending | PV rendus à un ennemi (+ 2) | +10,2 | +7,8 | +19,7 | +12,6 | 8,4–10,4 | aucun |
| Misery | DoT copié sur les autres (+ 1) | +5,8 | +8,8 | +18,0 | +10,9 | 6,4–9,0 | aucun |
| Echo of Light | Regen 4 au départ ; tic = sa valeur à tous (+ 2), sans soin | +8,7 | +3,8 | +23,9 | +12,1 | 3,8–6,3 | + 7 fixe par tic → Regen 4 de départ (règle de la fiche) |
| Shadow Covenant | 2, 4, 6… PV par carte Shadow du tour (0, 4, 6…) | +11,8 | +5,8 | +22,9 | +13,5 | 11,5–12,5 | 3 PV par mana → 2 PV + 2 par carte Shadow déjà jouée |
| Reflective Shield | le tiers (la moitié) de l'Absorb perdue renvoyé | +5,2 | +12,2 | +20,9 | +12,8 | 6,4–7,9 | plafond 2 (4) par coup retiré, part renvoyée |
| Voidform | + 1 (+ 2) par Insanity aux coups Shadow | +6,2 | +8,2 | +20,0 | +11,5 | 8,1–9,8 | aucun |
| Inner Focus | première carte en Cast, × 1,5 (× 2) | +10,3 | +2,8 | +24,4 | +12,5 | 10,5–12,5 | + 75 % → + 50 % (fiche) |

Moyenne des sept : **+12,3** (départ : +12,2, mais Inner Focus à +21,9 et Echo of Light à +6,8 ; la cible
+10 à +12 est dépassée de 0,3, dans le bruit de mesure). Westfall (`zone=westfall zones=7`, pour information,
sans épique 78,2 %) : Prayer of Mending +7,3, Misery +3,5, Echo of Light +9,5, Shadow Covenant +7,0,
Reflective Shield +8,0, Voidform +5,6, Inner Focus +1,5.

Mesures qui ont guidé les nombres (moyenne des trois zones) :
- Reflective Shield : tout renvoyer +33,9, la moitié +22,0, le tiers (amélioré + 3) +15,3, le tiers / la
  moitié +12,8, le tiers / le tiers +10,6, le quart / le tiers +7,2. Contrôle « à blanc » (rien renvoyé, mêmes
  conseils de bot) : −4,5, les conseils seuls ne rapportent rien. « Absorb − 2 par gain » en contrepartie :
  −3,8 (Duskwood −16), écarté.
- Shadow Covenant : 3 PV par mana +9,3 (Stranglethorn +0,7, 13 PV perdus), 2 PV +25,3, 2 PV et −1 mana par tour
  −38, 2 PV + 1 par carte du tour +20,1, 2 PV + 2 par carte du tour +13,5, 2 PV + 3 par carte du tour +10,4
(Stranglethorn +1,8, 12–13 PV perdus : écarté). L'amélioration (première gratuite)
  ne change presque rien (3 PV : 74,2 / 63,2 / 70,2 sans elle).
- Echo of Light : sans Regen de départ, + 7 par tic +6,8 ; Regen 3 et + 0 / + 2 / + 4 : +4,7 / +15,1 / +21,3 ;
  Regen 4 et + 0 / + 1 : +12,1 / +17,5.
- Inner Focus : × 1,75 +21,9 (Steppes +34,7) ; × 1,5 +12,5 ; × 1,5 sans interruption possible +20,0
  (Stranglethorn +15,0, Steppes +34,2) ; × 1,5 plafonné à + 10 par valeur +8,3 ; × 1,25 sans interruption +7,6
  (Duskwood −4,5) ; « à blanc » × 1 : −25,6 (Duskwood −34, Steppes −17).

Hors cible et pourquoi :
- **Steppes au-delà de +18** pour cinq épiques sur sept (+19,7 à +24,4) : le Priest n'y gagne que 52 % sans
  épique, et la zone se joue sur Grark Lorkrub (61 % au boss sans épique, 77 à 92 % avec) ; tout ce qui
  tue plus vite ou garde des PV pour le boss y rapporte le double des autres zones. Baisser les nombres pour
  passer sous +18 à Steppes ferait tomber Duskwood et Stranglethorn sous +3.
- **Inner Focus** reste la plus dépendante des zones, quel que soit le nombre : le retard d'un tour coûte cher
  contre Morbent Fel (Duskwood, à blanc 39 % au boss contre 72 %) et rien contre Grark ; à Stranglethorn les
  interruptions coupent la carte incantée (15 % des incantations en combat normal) : +2,8. La variante « ne peut
  pas être interrompue » remonte Stranglethorn (+15) mais pousse Steppes à +34 ; non retenue. PV perdus 10,5–12,5
  (le premier Absorb du tour arrive un tour plus tard).
- **Shadow Covenant** : 11,5–12,5 PV perdus par combat normal (c'est le prix de la règle) ; Stranglethorn +5,8
  (cause probable, non vérifiée : le Hex vise la carte la plus chère, donc les cartes que le mana paie encore).
- **Echo of Light** : 3,8 PV perdus à Steppes (sous 5 : l'épique tue les groupes avant qu'ils ne frappent).

Bot : non modifié. Le contrôle à blanc de Reflective Shield montre que ses conseils (`byEpic`) ne rapportent
rien seuls. Pistes non vérifiées : sous Inner Focus le bot perd des combats normaux (95 % contre 98,5 % sans
épique, 12 PV perdus contre 9,6), signe probable d'un mauvais choix de la première carte (Absorb retardée) ;
`botValue` ne donne aucune valeur propre à Shadow Covenant (la hausse dans le tour n'est vue que coup par coup).

**Paliers +2 et +3 (15/11/2026).** Les nombres réglables sont des tables `{ base, +1, +2, +3 }` lues par
`ns.Priest.tier(t, src)` (`Card.level(src)`) ; nouveaux réglages `COVENANT_FREE` (cartes Shadow gratuites par
tour : 0 / 1 / 1 / 2) et `VOID_FLAT` (dégâts fixes par coup Shadow : 0 / 0 / 2 / 4). Tableau des paliers :
`docs/classes/priest-progression.md`, « Paliers +2 et +3 ».

**Mesure une par une (19/11/2026, bot human, zones dures ; `docs/equilibrage.md`, « Épiques : mesure une par
une »).** Quatre épiques faisaient perdre le Prêtre. Causes et changements :
- **Conseils du bot** (Prayer of Mending, Misery, Echo of Light, Shadow Covenant) : les notes absolues de `byEpic`
  (soins à 8, Absorb et contrôle baissés) coûtaient 4 à 11 points dans les zones 4 à 7 ; remplacées par `lift` (note
  de la classe + un petit bonus pour les cartes que l'épique sert ; `bot.epic` lit une note fonction).
- **Dormeurs du Swamp of Sorrows** : le coup au hasard de Prayer of Mending, la copie de Misery et le tic d'Echo of
  Light réveillaient les ennemis endormis (Echo : 13 % au Swamp contre 33 % sans épique). Ils ne visent plus qu'un
  ennemi éveillé (`Priest.awake`, à-côtés « awake »).
- **Chiffres** : Prayer of Mending + 2 dès la base (`MENDING_UP` 2 / 3 / 4 / 5), Misery + 2 (`MISERY_UP` 2 / 3 / 4 / 5).
- **Shadow Covenant, règle réécrite** (nom et idée gardés : payer en PV au lieu du mana) : les premières cartes
  Shadow du tour sont gratuites (`COVENANT_FREE` 1 / 2 / 3 / 4), les autres se paient en mana tant qu'il suffit,
  puis 1 PV par mana + 1 par carte Shadow déjà jouée (`COVENANT_HP` 1, `COVENANT_STEP` 1). Payer toujours en PV
  coûtait trop à 36 PV dans les zones dures (Wetlands 81 % contre 97 %), même allégé.
### Hunter : les sept épiques (14/11/2026)

Données et règles dans `Data/Hunter.lua` (bloc « Cartes épiques », nombres réglés dans la table `EPIC`,
exposée en `ns.HunterEpic`), tests `Sim/tests_epic_hunter.lua`, harnais « UEH ». Aucun crochet ajouté au
moteur : tout passe par les crochets existants, en `deckHooks` de l'épique (`src` = `c.epic`, posée hors des
piles par le socle, crochets en dernier) ; `whileInDeck` = `ns.Hunter.epicStart(c, src)` retient l'épique en
jeu (`c.cls.epic = { id, up }`, lu par la vue et les bots : `ns.Hunter.epic(c)`). Nombres réglés par la
simulation (fiche → réglé) : Roar of Sacrifice 5 / 8 → 2 / 4 ; Master Marksman 0 / 4 → 20 / 24 dégâts en
plus ; Lone Wolf +1 → +2 par Frenzy (amélioré +3 au lieu de « Start of turn: +1 Frenzy. », trop long pour
la carte) ; Chimaera Shot 3 / 3 (6) → 5 / 4 (8) ; Trap Launcher 1 / 2 (fiche). Réglage des zones dures
(14/11/2026) : Call of the Wild et Black Arrow coûtent 1 Frenzy par attaque (`cotwCost`, `blackCost` ; améliorées :
gratuites), Beast Cleave frappe les autres ennemis pour 2 de moins (`cleaveLess`).

| Épique | Crochets | Remarques |
|---|---|---|
| Call of the Wild | `onTurnStart` | Frenzy ≥ `cotwCost` : −`cotwCost`, puis `Hunter.petAttack(c, "epic")`, après la pioche et la baisse du Frenzy |
| Trap Launcher | `trapLaunch`, `onTrapTriggered` (why = `"launch"`) | familier sur la cible de la Trap ; Resourcefulness : une Trap lancée revient en main à la fin du round (`c.cls.trapBack`, `onRoundEnd` du Power), pas tout de suite |
| Beast Cleave | `petAll`, `petLess` (valeur de classe, lue par `Hunter.petLess`), `onPetAttack` (amélioré) | la cible du familier en plein, les autres `cleaveLess` de moins (jamais sous 0) |
| Roar of Sacrifice | `beforeHit` | journal `{ t = "roar", prevented }` (« Roar » flottant de la vue), `c.stats.roarPrevented` |
| Master Marksman | `instantCast` (cible = `c.player.lastTarget`), `damage`, `afterCast` | question de `canPlay` (commit faux) : vraie si un ennemi vivant est intact ; journal `cast_instant` |
| Black Arrow | `onDotTick` | Frenzy ≥ `blackCost` : −`blackCost`, puis familier sur l'ennemi qui tique, sans changer sa cible |
| Lone Wolf | `petAbsent`, `damage`, `onTurnStart` ; `transforms` (9 variantes `variant = true`) | Pet Whistle : +1 Frenzy au lieu d'une attaque (règle du bibelot ; texte `loneText` montré par `UI/Art/hunter.lua`) |

Mesures des zones dures (14/11/2026, `luajit Sim/sim.lua runs=600 bot=heuristic jobs=3 runner=expedition
class=hunter level=7 key=0 zone=<zone> zones=<N> epic=<id>`, Duskwood `zones=1`, Stranglethorn `zones=3`,
Steppes `zones=5` ; sans épique : 64,7 / 70,8 / 83,0 % ; ± 3,5 points par zone) : gain en points de victoire
contre `epic=none`, PV perdus par combat normal (moyenne des trois zones), Westfall (`zones=7`, sans épique
77,8 %) pour information.

| Épique | Duskwood | Stranglethorn | Steppes | Moyenne | PV normal | Westfall | Avant (moyenne) |
|---|---|---|---|---|---|---|---|
| Call of the Wild | +11,5 | +5,7 | +10,2 | +9,1 | 6,0 | +13,9 | +19,1 (gratuite) |
| Trap Launcher | +17,3 | +7,2 | +9,0 | +11,2 | 5,3 | +12,4 | inchangée |
| Beast Cleave | +16,0 | +7,9 | +8,0 | +10,6 | 5,5 | +13,7 | +15,5 (en plein) |
| Roar of Sacrifice | +8,5 | +14,4 | +11,0 | +11,3 | 4,9 | +12,9 | inchangée |
| Master Marksman | +17,6 | +7,0 | +3,7 | +9,4 | 5,6 | +10,9 | +6,1 (+12) |
| Black Arrow | +17,0 | +7,7 | +12,7 | +12,5 | 6,1 | +13,4 | +16,9 (gratuite) |
| Lone Wolf | +15,0 | +10,4 | +12,2 | +12,5 | 4,9 | +15,5 | +7,8 (Chimaera 4) |

Moyenne de la classe : +10,9 (avant : +12,6, de +6,1 à +19,1). Essais : Beast Cleave « moitié aux autres »
+7,5, « 1 de moins » +13,1 ; Master Marksman +16 : +8,2 ; Lone Wolf +3 par Frenzy : +21,2, Chimaera Shot 6 / 4 :
+16,6. Les épiques imposées ne sont jamais améliorées par le bot (notes d'amélioration de `byEpic` ≈ 4, sous
les notes des cartes ≈ 9 à 11) : les versions améliorées ne sont pas mesurées.

Ajouts de la classe : `Hunter.petAttackOn(c, why, ennemi)` (cible imposée par `c.cls.petForce`, lue par
`Hunter.petTarget` : la signature de `petAttack` / `petTarget`, enveloppées par Core/ZoneRules.lua, ne change pas) ;
effet `{ "damageOther", n }` (« Deal N to another enemy. », Chimaera Shot : l'ennemi vivant le plus à gauche
autre que la cible) ; déclencheurs « Each enemy DoT tick », « Attack hits », « Each Attack hit ». Vue
(`ns.ClassViews.hunter`) : figure et marqueur du familier cachés sans familier, « Roar » flottant, note de l'épique sur son jeton des états du héros (compteur sur l'icône, infobulle = la carte et ce qu'elle change maintenant : `Art.hunterEpicLine(c)`, lue par le harnais).
Interface commune touchée au minimum : `UI/Controller.lua` montre une carte proposée en récompense ou chez le
marchand sous sa variante quand l'épique du deck la transforme (`shownCard`, `from` = l'originale ; la carte
prise entre au deck sous son id d'origine). Bots : `classDef.bot.epic(exp, id)` (note d'offre) et
`classDef.bot.byEpic[id]` = `{ rating, upgrade, remove }` (point d'accroche partagé de `Sim/expedition.lua`),
notes qui priment tant que l'épique est dans le deck ; en combat,
`Hunter.EPIC_RES[id]` ajoute de la valeur au Frenzy gardé (Roar of Sacrifice, Lone Wolf) dans `botValue` ;
l'épique du deck vaut 5 de plus pour le bot (`EPIC_KEEP`) : il ne la remplace que pour bien mieux, et une
épique imposée (`epic=<id>`) reste mesurée seule.

**Mesure une par une (19/11/2026, bot human ; `docs/equilibrage.md`, « Épiques : mesure une par une »).** Beast
Cleave : tant qu'un ennemi vivant dort (Asleep), `petAll` reste faux et le familier ne frappe que sa cible (« unless
one sleeps » dans l'à-côté de Stampede et Trample) ; le familier réveillait tous les dormeurs du Swamp of Sorrows
(−10 points dans la zone). Lone Wolf : Ferocity 2 / 3 / 4 / 5 → 3 / 4 / 5 / 6 (`lonePer`) ; sans ses conseils de
deck, l'épique perdait encore plus : la carte était en cause.

### Épiques du Voleur (14/11/2026)


Données et nombres (`EPIC_N`, seule source : textes et règles) dans `Data/Rogue.lua` ; règles (`deckHooks`,
`ns.Rogue`) dans `Core/Classes/rogue.lua` ; vue (note de l'épique sur son jeton des états du héros, marques
d'Atrophic Poison) dans `UI/Art/rogue.lua` ; tests `Sim/tests_epic_rogue.lua`, harnais UER.
- **Deflection** : `onStatusApplied` (Parry sur le héros, `n` demandé avant le plafond de 3) ; compteur
  `c.cls.ripostes` du tour (`c.cls.riposteRound`, le début du combat compte pour le tour 1, le tour ennemi
  continue le compte) ; coup sans carte (`calcDamage` avec `cardDef` nil) sur `c.player.lastTarget` ou l'ennemi
  vivant le plus à gauche ; journal `{ t = "riposte", dst, n, base }`. `ns.Rogue.ripostes(c)`, `nextRiposte(c)`,
  `riposteDamage(k, up)` = N + S × (k − 1) (`EPIC_N.deflection`, `deflectionStep`).
- **Doomblade** : crochet moteur `convertHit` (ci-dessus), Attacks à effet `surge` seulement ; DoT par le crochet
  `apply` (Crystal Vial), icône poison.
- **Atrophic Poison** : `enemyDamage` (×0,75 si l'ennemi montre au moins le seuil de DoT `EPIC_N.atrophic_poison`
  pendant le tour du Voleur et en garde après son tic ; pendant le tour ennemi, on lui rend la baisse `dotDecay` ;
  l'intention affichée est juste ; pas de cumul avec un vrai Demoralized), amélioré `damage` (×1,25 au même seuil,
  pas de cumul avec Sundered). `ns.Rogue.countsDemoralized(c, e)`.
- **Echoing Reprimand** : `surge` (2 à M -> N, `EPIC_N.echoingMax`) ; aucune autre source du Voleur ne modifie
  `surge` avant.
- **Subterfuge** : `stealthBreak` faux ; durée `c.cls.stealthUntil` (posée à chaque Stealth reçu, et par
  `whileInDeck` pour celui du départ), retrait dans `onTurnEnd` ; source incluse : `onSurge` (dépense de 1 ou
  plus) pose Stealth (`EPIC_N.subterfugeSurge`) ; Combo par Stealth gagné (`c.cls.stealthGained`, 0 depuis le
  réglage). Mot de règle « Shroud » (`L.rule("shroud")`, 14/11/2026 : textes en deux lignes, `docs/zones/cartes-de-zone.md`).
- **Kidney Shot** : `onSurge` (dépense réelle, carte à cible) marque le `ctx`, `onCardPlayed` étourdit la cible
  vivante (boss : Demoralized 2).
- **Danse Macabre** : `onCardCommitted` tient les ids joués du tour (`c.cls.dmNames`, `dmCount`, `dmRound`) ;
  `damage` ajoute `ns.Rogue.danseBonus(c, up, id)` = N par autre id au-delà des F premiers (`EPIC_N.danseFree`),
  plafond facultatif (`danseCap`, 0 = aucun).
- **Réglage (14/11/2026, zones dures)** : tableau et essais dans `docs/zones/cartes-de-zone.md` (« Rogue »).
  Contrôle « à blanc » (nombre nul, mêmes conseils du bot) : Deflection −3,1, Echoing −1,2, Kidney +0,9,
  Atrophic −2,9, Danse +3,4 (les retraits de doublons conseillés par `bot.byEpic.danse_macabre` rapportent
  un peu seuls, surtout à Duskwood).

- **Mesure une par une (19/11/2026, bot human ; `docs/equilibrage.md`, « Épiques : mesure une par une »)** :
  Doomblade, règle réécrite (nom et idée gardés) : le coup de grâce **porte** et pose en plus un DoT de 100 % (110 /
  120 / 130 %) de ses dégâts ; convertir le coup en DoT de 90 % faisait perdre 5 à 11 points dans les zones 4 à 7.
  Subterfuge : conseils du bot modérés (`lift` : Shadow Dance, Secret Technique et Nightblade n'y sont plus poussées)
  et Parry 1 dès la base (`subterfugeParry` 1 / 1 / 2 / 3, « Shroud 2, Parry 1. »).

### Épiques du Guerrier (14/11/2026, réglées pour les zones dures le 14/11/2026)

Sept épiques (`Data/Warrior.lua`, une par zone), règles et nombres dans `Core/Classes/warrior.lua`
(`ns.Warrior.EPIC`, crochets `deckHooks`, `whileInDeck`), tests `Sim/tests_epic_warrior.lua`, harnais « UEW ».
`ns.Warrior.epicOf(c)` = épique en jeu (`c.epic`) : id, amélioré. Crochets employés : `canGainBlock`,
`attackMult`, `onEnemyDeath` (Death Wish) ; `onResource` (Thunderous Roar) ; `onDamageDealt` (Sweeping Strikes,
rebond sans ctx) ; `replay`, `canPlay` (nouveau), `cost`, `onCardCommitted`, `beforeCard` / `onCardPlayed` (Titan's
Grip : la copie d'un Surge reprend le montant de l'original, Rage prêtée puis rendue ; la règle de classe ne donne
la Rage d'une Attack qu'une fois quand `c.cls.titan`) ; `onTurnEnd` (Shield Charge) ; `onSpend` / `onSurge`,
`giveCooldown` et `ns.Warrior.cooldownTick(c)` (Anger Management : une recharge qui arrive à 0 revient en main
aussitôt) ; `resCap`, `onTurnStart`, `damage` (Avatar, `ns.Warrior.avatarBonus(c)`). Événement de journal
`epic_trigger` (card, unit) : sans animation propre. Vue de classe : compteur de l'épique (Titan's Grip, Shield
Charge ; Anger Management si une tranche dépasse 1 ; Avatar : « Rage 10: Attacks +1 » quand le bonus joue).
Coups sans carte des épiques : genre « other » (`Combat.hitInfo`), à tous pour l'onde et le rebond, à une cible
pour Shield Charge, dont la cible passe aussi par le crochet de zone `petTarget` (dormeurs du Swamp).

**Point d'accroche ajouté au moteur (14/11/2026)** : `giveCooldown` (`Core/Combat.lua`, fin du jeu d'une carte),
valeur `(c, src, nil, d, inst)` → nombre de tours de recharge posé sur une carte qui n'en a pas (`nil` : défausse
comme avant). Anger Management y met les cartes qui dépensent la Rage.

Réglage des zones dures (14/11/2026, `luajit Sim/sim.lua runs=600 bot=heuristic jobs=3 runner=expedition key=0
level=7 class=warrior epic=<id>` avec `zone=duskwood zones=1`, `zone=stranglethorn zones=3`, `zone=steppes
zones=5` ; Westfall `zones=7` pour information ; mêmes graines, ± 3 à 4 points par mesure). Sans épique
(`epic=none`) : Duskwood 66,2 %, Stranglethorn Vale 70,8 %, Burning Steppes 80,2 %, Westfall 86,0 %.
Moyenne des sept épiques : +11,6 (départ : +12,0, de +6,1 à +23,8).

| Épique | Duskwood | Stranglethorn | Steppes | Moyenne | Westfall | PV perdus (combat normal, D / S / B) | Changement |
|---|---|---|---|---|---|---|---|
| Death Wish | +22,0 | +3,5 | +13,1 | +12,9 | +7,5 | 10,3 / 11,3 / 7,7 | — |
| Thunderous Roar | +16,6 | +3,5 | +7,3 | +9,1 | +8,0 | 8,9 / 10,9 / 8,4 | Demoralized 1 rendu sur l'amélioré (4 + Demoralized) |
| Sweeping Strikes | +15,1 | +8,0 | +7,1 | +10,1 | +7,3 | 8,5 / 10,2 / 7,3 | moitié → tiers |
| Titan's Grip | +14,6 | +9,2 | +6,8 | +10,2 | +2,3 | 10,2 / 11,2 / 9,0 | 2 Attacks par tour rendues, chacune coûte 1 de plus |
| Shield Charge | +16,3 | +12,9 | +7,8 | +12,3 | +10,2 | 8,2 / 9,5 / 7,4 | — (quart) |
| Anger Management | +17,0 | +14,2 | +8,1 | +13,1 | +7,0 | 9,3 / 10,3 / 8,4 | Spend et Surge en recharge 1 (débouché) |
| Avatar | +16,8 | +15,0 | +8,6 | +13,5 | +6,7 | 9,6 / 11,1 / 8,8 | à 10 Rage, Attacks +1 (débouché) |

Essais écartés (moyenne des trois zones) : Titan's Grip de la fiche (deux Attacks, sans coût) 100 % partout ;
copie à moitié 97–100 % ; « Pay 2 HP » par Attack 94–99 %. Thunderous Roar avec Demoralized de base : 3 dégâts
+22,5, 1 dégât +15,3 (Duskwood +21) ; 4 dégâts sans Demoralized +15,8 (Duskwood +25). Avatar : +1 par Rage
au-delà de 5 : 98–100 % ; au-delà de 7 (+1 / tour) +20,7 ; au-delà de 8 : +16,3 (+1 / tour), +19,4 (+2 / tour).
Anger Management sans débouché, conseils corrigés : +7,2 (Steppes +1) ; recharge −2 / −3 par Rage : +6,5.

Hors cible : Death Wish (Duskwood +22 au-delà de +18, Stranglethorn +3,5) et Thunderous Roar (Stranglethorn
+3,5) : écart de zone, pas de moyenne ; un nombre plus bas les ferait passer sous +3 à Stranglethorn. Les
gains de Duskwood sont hauts pour toutes les épiques (sans épique, le Guerrier y gagne 66 %).

Bots : `classDef.bot.byEpic[id]` (tables de notes, d'amélioration et de retrait tirées du « Deck piloté » de la
fiche) ; `classDef.bot.epic(exp, id)` note une épique proposée (accord avec le deck, attachement à l'épique du
deck : une épique de même note n'en remplace jamais une autre). Corrigés le 14/11/2026 : Titan's Grip (Attacks à
0 et Skills relevées sous le surcoût), Anger Management (Deep Wounds, Enrage, Bladestorm gardent leur rang ;
Battle Shout, Recklessness, Victory Rush ne sont plus écartées). Contrôles « à blanc » avec les mêmes conseils
(`copies = 0, limit = 99, extraCost = 0` ; `steps = 0, give = 0`) : Titan's Grip −0,3, Anger Management −5,0 :
les conseils seuls ne rapportent rien.

**Mesure une par une (19/11/2026, bot human ; `docs/equilibrage.md`, « Épiques : mesure une par une »).** Sweeping
Strikes : Sweep 1 / 2 / 2 / 2 au tiers → 2 / 3 / 3 / 3 à la moitié (`targets`, `div = 2`), et le rebond ne tire
jamais un dormeur (état Asleep du Swamp of Sorrows : le rebond le réveillait). Au tiers vers un seul ennemi,
l'épique ne gagnait rien dans les zones 4 à 7 ; sans ses conseils de deck (Cleave, Whirlwind écartées), pas mieux :
la carte était en cause, pas le bot. La vue de classe (`UI/Art/warrior.lua`) écrit encore « for a third » en dur.

### Épiques du Mage (14/11/2026)

Données et nombres (`epicN`, `epicM`, `epicPct`, `epicBonus`, `epicCharge`, `epicEvery`, base et `up`, lus par les
crochets) dans `Data/Mage.lua` (`epic(...)` : `cost = 0`, jamais payé) ; règles (`deckHooks`, src = `c.epic`) dans
`Core/Classes/mage.lua` ; vue dans `UI/Art/mage.lua` ; tests `Sim/tests_epic_mage.lua`, harnais UEM ; bot :
`bot.byEpic` (conseils de construction de chaque épique) et `bot.epic` (note ≈ 5 + gain / 2 ; l'épique du deck vaut 3
de plus : le deck est construit autour). Toutes les règles agissent à chaque tour (plus de « Every 3rd turn » ni de
`Combat.epicTurn`). État de combat dans `c.cls` (`carry`, `molten`, `weChill`, `fof`, `fofOn`, `fofThaw`, `r3`,
`r3surge`). Aucun point d'accroche ajouté au moteur ; déclencheur nouveau « When attacked » (`L.trigger`).
- **Mirror Image** : `afterCast` (`Combat.mirrorHit` : premier coup de la carte Cast, dégâts calculés sur une cible
  tirée par `c.rng.cards`, × `epicPct` / 100 arrondi bas ; coup de la même carte : Shatter, Ignite, `onAttackHit`).
- **Molten Armor** : `afterHit`, une fois par attaque (`c.cls.molten[uid] = round`), DoT N même absorbé, par `apply`.
- **Water Elemental** : `onTurnStart` à chaque tour (`Combat.elementalTarget` : dernière cible, sinon la plus à
  gauche ; un dormeur `asleep` seulement si tous dorment), coup sans carte, Demoralized `epicM` ; `onTurnEnd` retire
  ce Demoralized (`c.cls.weChill`) : Frozen pour les cartes du Mage, pas pour le tour ennemi.
- **Fingers of Frost** : crochet moteur `instantCast` lu avec la cible (`c.aim`, `Combat.castFits` ci-dessus), qui
  retient le gel de la cible (`fofThaw`) ; `onCardPlayed` retire ce Stunned et ce Demoralized après la résolution
  (ceux que la carte pose restent) ; amélioré : `damage` + N pendant la résolution de la carte partie ainsi.
- **Arcane Meditation** : `onTurnEnd` garde `min(mana, N)`, + `epicBonus` s'il en reste, dans `c.cls.carry` ;
  `onTurnStart` l'ajoute (au-delà du maximum, affiché « 8/3 »).
- **Conflagration** : `onEnemyDeath` (DoT du mort, lu avant tout nettoyage ; + N à chaque autre ennemi vivant, sans
  `apply`).
- **Rule of Threes** : `onCardCommitted` marque la 3e carte du tour (améliorée : chaque 3e), de tout type, si
  `Combat.spendRes(c, epicCharge)` passe ; `replay` la double ; `beforeCard` donne à la copie le Surge de l'original.
- Vue : ligne violette de l'épique (`Art.mageEpicText` : mana gardé et bonus, rang de la carte et sa Charge, cible de
  l'élémentaire, Frozen) ; nom flottant sur l'événement `{ t = "epic", id, dst|src|card }`.

**Réglage des zones dures (14/11/2026).** Mesure de référence commune aux cinq classes : `luajit Sim/sim.lua
runs=600 bot=heuristic jobs=3 runner=expedition class=mage level=7 key=0 epic=<id>` avec `zone=duskwood zones=1`,
`zone=stranglethorn zones=3`, `zone=steppes zones=5` (et `zones=7` à Westfall pour information) ; gain = victoires
avec l'épique − victoires sans (`epic=none` : Duskwood 59,8 %, Stranglethorn 70,8 %, Steppes 70,8 %, Westfall 80,8 % ;
combat normal 6,5 / 6,7 / 5,4 / 5,0 PV perdus) ; ± 3,9 points par mesure.

| Épique | Texte (base / amélioré) | Duskwood | Stranglethorn | Steppes | Moyenne | Westfall | PV perdus (normal, D / S / B) | Changé |
|---|---|---|---|---|---|---|---|---|
| Mirror Image | half their damage again / their damage again | +18,5 | +5,4 | +16,5 | +13,5 | +5,4 | 6,5 / 7,0 / 5,5 | « damage − 6 / − 2 » → la moitié / tout (la fiche, tout : +20 à Duskwood) |
| Molten Armor | When attacked: DoT 2 / 4 | +18,7 | +4,7 | +11,2 | +11,5 | +12,0 | 7,1 / 7,4 / 6,3 | DoT 1 / 3 par coup (+5,0) → DoT 2 / 4 par attaque (DoT 2 par coup : +15, +25 à Duskwood) |
| Water Elemental | Start of turn: 2 / 4 and Demoralized 1 for this turn | +16,4 | +8,4 | +14,4 | +13,1 | +8,5 | 6,7 / 6,9 / 5,5 | 5 / 8 un tour sur trois (+10,6) → chaque tour, gel du seul tour du Mage (Demoralized tenu au tour ennemi : +25 à 3, +21 à 1) |
| Fingers of Frost | resolve at once and thaw it / + 4 more | +9,5 | +12,5 | +10,0 | +10,7 | +7,4 | 5,0 / 4,8 / 3,7 | dégel ajouté (sans : +18,3 ; « once per turn » : +16,6) |
| Arcane Meditation | Up to 4 unspent mana carries over, +1 / 6, +2 | +12,2 | +10,2 | +13,5 | +12,0 | +7,2 | 6,5 / 7,2 / 5,2 | 4 / 6 sans bonus (+4,4) → « +1 / +2 » ; conseils de deck modérés |
| Conflagration | DoT + 16 / + 20 to each other enemy | +14,7 | +8,4 | +6,0 | +9,7 | +6,2 | 5,2 / 5,5 / 4,2 | + 8 / + 11 (+6,7) → + 16 / + 20 ; conseils de deck modérés |
| Rule of Threes | 3rd card each turn spends 1 Charge to resolve twice / every 3rd | +17,2 | +13,5 | +11,5 | +14,1 | +11,0 | 5,3 / 5,2 / 3,9 | une Attack un tour sur trois (+13,6) → toute carte chaque tour pour 1 Charge (sans coût : +31,9, 99 % ; « Pay 2 HP » : +22,3) |

Moyenne des sept : **+12,1** (départ : +10,4, de +4,4 à +18,3). Hors cible de peu : Mirror Image et Molten Armor à
Duskwood (+18,5, +18,7 pour +18 au plus, dans l'erreur de mesure), Rule of Threes (+14,1 pour +14). PV perdus sous 5 à
Burning Steppes (Fingers of Frost, Conflagration, Rule of Threes : combats normaux courts) et pour Fingers of Frost
partout (le gel tient l'ennemi).

Bot (Arcane Meditation, Conflagration) : la valeur du mana gardé (`Combat.MAGE_CARRY_VALUE`) reste à 5 (8 : −5 points,
12 : −30 : le bot garde trop) ; une valeur d'avance au DoT d'un ennemi près de mourir (Conflagration) n'apportait rien
(−1 à −2) et a été retirée. Le vrai défaut était dans les conseils de construction (`bot.byEpic`) : à blanc (Arcane
Meditation N = 0, Conflagration N = −99), les anciens conseils coûtaient −3,7 et −3,2 points ; modérés (gros sorts et
cartes Fire moins poussés), le contrôle à blanc donne −1,7 et −1,4 (rien), et l'épique +12,0 et +9,7. Le bot ne sait
toujours pas préparer sur deux tours (garder son mana pour un tour à deux gros sorts, poser le DoT sur la cible qu'il
achèvera au tour suivant) : il ne regarde qu'un tour.

**Mesure une par une (19/11/2026, bot human ; `docs/equilibrage.md`, « Épiques : mesure une par une »).** Molten
Armor : conseils modérés (`lift` ; les anciens écartaient Frost Nova et Polymorph, −7 points dans les zones 4 à 7) et
Burn 3 / 5 / 6 / 7 (2 / 4 / 5 / 6 avant).

### Épiques du Druid (18/11/2026)


Données, crochets et nombres dans `Data/Druid.lua` (bloc « Cartes épiques » : table `EPIC` exposée en
`ns.DruidEpic`, tables `{ base, +1, +2, +3 }`, seule source des textes, des règles et des à-côtés ; `deckHooks`,
src = `c.epic`) ; déclencheurs, mots de règle, réserves de Heart of the Wild et compléments des bots dans
`Core/Classes/druid.lua` (`ns.Druid.epic(c)`, `kinStart`, `pool`, `usePool`, `ClassRules.druid.cardRes`) ; vue
(`Art.druidEpicLine(c)`, note du jeton de l'épique par `W.noteToken` dans `ns.ClassViews.druid.tokens`) dans
`UI/Art/druid.lua` ; tests `Sim/tests_epic_druid.lua`, harnais UEDR et UEL (42 épiques). Nombres = points de
départ de la fiche (§ 5), **non mesurés** : notes des bots à 10 (`bot.epic`), builds `bot.byEpic` tirés de « Ce
qu'elle fait construire ». Déclencheurs ajoutés : « Form changes », « Forms » (« Each Regen heal » et « Surge
cards » existaient).

| Épique (zone) | Texte de base | Crochets | Remarques |
|---|---|---|---|
| Furor (Westfall) | `Form changes: Primal 2.` | `onShift` | +1 réserve par changement, N par tour (`c.cls.furor`, `furorRound`) ; l'entrée dans la première forme compte |
| Mark of Ursol (Duskwood) | `Bear strikes: Ironfur 50%.` | `onBearStrike` | Absorb = N % des dégâts de chaque frappe (fin de tour, carte, chaque frappe d'un Surge), arrondi bas |
| Eclipse (Wetlands) | `Cast cards: Lunar 5.` | `instantCast`, `damage`, `afterCast` | Cast Moonkin tout de suite à N en réserve (lu après le changement de forme : en Moonkin, avec le bonus des Charges) ; l'état Instant n'est pas consommé ; +2 / +3 « Solar » : + 3 par coup (`c.cls.eclipse`) |
| King of the Jungle (Stranglethorn Vale) | `Surge cards: Predator 1.` | `onSurge`, `onCardPlayed` | le Surge compte tout, min(N, montant) revient **après** la carte (aucun bonus de Moonkin sur Starsurge / Starfall) ; +2 / +3 « Apex » : le premier Surge du tour pioche 1 |
| Lifebloom (Swamp of Sorrows) | `Each Regen heal: Bloom 1.` | `onRegenTick`, `whileInDeck` | +N par tic de Regen, PV pleins compris ; améliorée : Regen 3 au début du combat (+3 « Overgrowth » : 5), qui tique dès le premier tour |
| Owlkin Frenzy (Burning Steppes) | `When hit: Moonfury 3.` | `onPlayerHit`, `onTurnEnd` | en Moonkin, une fois par action ennemie (`c.fxId`, `c.cls.owlFx`) qui coûte des PV ; 3 Absorb en fin de tour en Moonkin (+2 / +3 « Barkskin » : 5) |
| Heart of the Wild (Blackrock Mountain) | `Forms: Kinship 3.` | `resCap`, `onShift`, `whileInDeck` ; règle de classe `cardRes` | trois réserves au plafond de la classe (5), chacune à N au début du combat ; +2 / +3 « Kindred » : la réserve sans forme aussi |

**Heart of the Wild : trois réserves sans changer le contrat de la ressource.** `c.player.res` reste la réserve
**de la forme active** (pastille, nom par `L.combatResource`, `gainRes`, `surge`, `spendRes`, frappe de l'ours,
bonus de Moonkin, baisse en Bear : inchangés) ; les autres attendent dans `c.cls.kin = { cur, cat, bear, moonkin,
rest }` (`rest` : sans forme et Tree of Life, que rien ne remplit ; la valeur de `cur` dans la table est périmée).
`Druid.usePool(c, forme)` échange les valeurs (au changement de forme, `onShift`). Le plafond de chaque réserve
est N (`resCap`, crans de la pastille). Seul point du moteur touché : **`Combat.cardRes(c, d, commit)`**
(`Core/Combat.lua`), ressource que lisent `minRes` (`canPlay`), Spend (`legalPlays`, `play`, « Spend N: »
éteint de `Controller.handInfo`) : `c.player.res`, sauf règle de classe `ClassRules.<id>.cardRes(c, d, commit)` ;
au jeu (`commit`, juste avant le Spend), le Druid place la réserve de la forme de la carte dans `c.player.res`
(le changement de forme qui suit ne déplace plus rien). Ferocious Bite en Bear se joue donc sur le Combo en
attente, Frenzied Regeneration en Cat paie son Spend en Frenzy. Bots : `botKey` et `botValue` de la classe
enveloppés (réserves en attente dans la clé, valant `bot.resValue` chacune ; compteurs de Furor et d'Apex).

**Mesure une par une (19/11/2026, bot human, zones dures ; `docs/equilibrage.md`, « Épiques : mesure une par une »).**
Owlkin Frenzy : Moonfury 1 / 2 / 2 / 3 → 3 / 4 / 4 / 5, Barkskin 3 dès la base (5 aux paliers 2 et 3). Heart of
the Wild : plafond 3 / 4 / 5 / 5 → 5 partout (celui de la classe) et chaque réserve de forme au départ à 3 / 4 / 4 /
5 (nombre de la carte : `Kinship 3`) ; « Kindred » passe aux paliers 2 et 3 (la réserve sans forme part aussi de N) ;
`Druid.kinStart(c, n, rest)` prend la valeur de la réserve sans forme. Eclipse : nombres inchangés, conseils du bot
modérés (`lift` : note de la classe + un petit bonus, comme Owlkin Frenzy) ; les anciennes notes absolues (Starfire
et Hurricane à 9) coûtaient 8 points dans les zones 4 à 7.

## Sauvegarde


`Save.VERSION` 5, `Expedition.VERSION` 6 (version 6 : cartes épiques, `docs/expedition.md` ; épique en jeu : `c.epic`, champ facultatif) : version 3, migration de la Démence du combat en cours
(`c.player.demence` → `c.player.res`, `c.class`, `c.cls`) ; version 4, niveau de classe (`cs.xp` tiré de
l'ancienne réputation de classe, `exp.unlock.level`, docs/expedition.md) ; version 5, campagne par zones
(`cs.zones`, `meta.zones`, `exp.zone`, `exp.unlock.common` et `won`, Ligue abandonnée, `docs/zones.md`). Une classe qui ajoute un état de combat le
range dans `c.cls` (données simples) : rien à migrer tant que les champs absents ont une valeur par
défaut. Une expédition d'une classe inconnue (fichier retiré) part en quarantaine (`Save.validateExpedition`).
