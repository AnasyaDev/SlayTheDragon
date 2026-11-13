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
`res`, `block`. Une classe enregistre les siens (`Combat.CONDITIONS.frozen = function(c, ctx, t) … end`).

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
| `instantCast` | d, inst, commit | une carte Cast part tout de suite (autre source que l'état Instant) ; ne rien consommer si commit est faux |
| `trapSlots` | — | nombre de Traps posées au plus (3) |
| `castSlots` | — | nombre d'incantations tenues à la fois (1 ; Mage : 2) |
| `powerLasts` | d, inst | durée d'un Power à durée |
| `dotDecay` | unité | baisse du DoT après son tick (1 ; Agony : 0) |
| `blockKeep` | — | Absorb gardée au début du tour (0 : remise à 0 ; Gnomish Harm Prevention Belt : +5) |
| `cooldown` | d, inst | durée d'une recharge posée (`d.cooldown` ; 1 au moins : Hourglass Sand) |
| `replay` | inst, ctx | copies de la carte résolues tout de suite après elle, même cible (premier ennemi vivant si elle est morte), sans coût, la carte ne part qu'une fois ; `ctx.copy` vrai pour une copie, journal `replay` (Ironfoe ; Windfury Totem du Shaman) |
| `applySelf` | état | valeur d'un état posé sur le héros, toutes sources (Benediction : Regen +1) |
| `resCap` | — | plafond de la ressource (`resource.cap` ; Avatar : 10) ; `Combat.resCap(c)` (l'affichage des crans ne le lit pas encore) |
| `attackMult` | cible, d | multiplicateur des coups d'une carte Attack (1 ; Death Wish : 1,5), après `damage` (Strength et ajouts), avant Demoralized / Sundered, arrondi à l'inférieur |
| `canGainBlock` | — | vrai par défaut ; faux = aucun Absorb gagné (Death Wish), avant le crochet `block` ; un gain ≤ 0 après `block` ne fait rien |
| `trapLaunch` | d, inst | faux par défaut ; vrai = la Trap demande une cible (`Combat.targetOf`, `Combat.needsTarget(inst, c)`) et se déclenche aussitôt sur elle (`Combat.launchTrap` : mêmes effets, `onTrapTriggered` avec why = `"launch"`), sans emplacement (jouable zone pleine) |
| `stealthBreak` | inst, d | Rogue : vrai par défaut ; faux = la première Attack profite de Stealth (lignes « Stealth: ») sans le retirer (Subterfuge ; la carte dit quand il tombe) |
| `petAbsent` | — | Hunter : faux par défaut ; vrai = plus d'attaque du familier (automatique, effet `pet`), pas de Frenzy gagné ; `Hunter.petPresent(c)` |
| `petAll` | — | Hunter : faux par défaut ; vrai = chaque attaque du familier frappe tous les ennemis vivants (+1 Frenzy une fois) ; `Hunter.petAll(c)` |
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

## Langage des cartes (`Core/Language.lua`)

Registre partagé par le moteur, l'interface (couleurs, coupures, explications au survol) et le harnais.
Déjà déclarés : les ressources des neuf classes (Insanity, Rage, Combo Point(s), Arcane Charge(s), Soul
Shard(s), Frenzy, Holy Power, Maelstrom), les conditions Execute, Surge, Spend N, Last Breath, Shadow,
Frozen, Demon, Judgement, Shift, Caster, Bear, Cat, Moonkin, le mot « Pay N HP », les mots de plaque
Power, Trap, Seal, Demon, Totem N, Shift, Cast, Cooldown N, Exhaust, Retain, et les déclencheurs de Power
(« When hit », « HP lost », « Attacks », « Start of turn », « End of turn », « Each Absorb gain »,
« Cast cards »). Une classe en ajoute depuis ses fichiers :

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
classe de la carte, « N » = nombre.

Forme des textes (vérifiée par le harnais U27 pour toute carte de `ns.Cards`) : une clause par ligne ;
« Pay N HP. » en première ligne ; « +N Rage. » (singulier / pluriel du registre) pour chaque effet `res`
sans condition ; « Spend N: … » ⇔ `spend = N` ; « Surge: … » ⇔ effet `surge` (« deal B + K per Rage. » ou
« Deal B. » puis « …: deal K per Rage. ») ; « Execute: … » ⇔ condition `execute` ; états posés en dernier
(« Gain » / « Apply », sablier pour une durée) ; aucun « you / your » ; libellé « Name: » connu du
registre ; aucune ressource d'une autre classe. Le texte doit tenir dans le panneau (U22, toutes les cartes).

## Interface (`UI/Art/<id>.lua`)

```lua
Art.cards.<carte> = { tga = "Ability_Warrior_Cleave", spell = 845, icon = "Interface\\Icons\\ability_warrior_cleave" }
Art.paths.<voie> = { name = "Arms", ring = hex("#b0743a"), ink = hex("#6b3f12") }
Art.relics.<bibelot> = { tga = "INV_Banner_02", … }
Art.classes.<id> = { tga = "ClassIcon_Warrior", wow = "WARRIOR",           -- wow = UnitClass("player")
  resource = { tga = "Ability_Warrior_FocusedRage", color = "attackText" } } -- pastille, chiffres flottants
Art.statusIcons.<clé> = { tga = … }        -- icône d'un état selon sa source (apply … icon = "bleed")
ns.ClassViews.<id> = { build = function(hôte, vue) end, render = function(hôte, combat, vue) end,
  event = function(hôte, ev, vue) end }    -- facultatif : animations propres (vue:Push(délai, fn))
```

- **Pastille de ressource** (générique, `UI/CombatView.lua`) : petit anneau doré près du mana, icône de la
  ressource de la classe jouée, nombre, cachée à 0 ; infobulle = explication du registre et « n / plafond ».
- **Zone libre de classe** : cadre de 300 × 40 sous les états du héros ; `build` une fois par classe,
  `render` à chaque rendu du combat (formes du Druid, totems du Shaman, Seal du Paladin, familier du
  Hunter). Pas de cadre enfant dans un visuel survolable (docs/interface.md) ; ne lire que `c`.
  La vue peut aussi poser des éléments dans la scène (cadres ancrés au parent de l'écran, `vue.parent`,
  personnage par `Scene.figure` : le familier du Hunter) et viser les ennemis par `vue.slotOf[uid]` ; ce qui
  n'est pas enfant de l'hôte se cache avec lui (`OnHide` de l'hôte).
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
seuils et règles : `docs/expedition.md`, « Niveau de classe ». Mage, Rogue, Hunter : niveaux de leur fiche
(`docs/classes/<classe>.md`, § Progression). Priest : `docs/classes/priest-progression.md`.

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
| Familier (Hunter) | `ns.Hunter.petAttack(c, why, frenzy)` (Core/Classes/hunter.lua) : coup « sans carte » (`calcDamage` avec cardDef nil) sur `c.player.lastTarget` ou le premier ennemi vivant, journal `pet_attack`, événement propre `onPetAttack` ; attaque automatique dans le crochet de classe `onTurnEnd` ; effet `{ "pet", n }` (`surge = true` : Bestial Wrath) ; Frenzy = ressource, -1 dans `onRoundEnd` ; condition `careful` (Careful Aim, verdict pris dans `beforeCard`) ; affichage et animation dans `ns.ClassViews.hunter` (`build`, `render`, `event`) |
| Traps (Hunter) | commun : `trap = true`, zone `c.traps`, déclenchement avant les coups de l'attaque (`Combat.triggerTrap`), `onTrapTriggered` |
| Stunned pendant le tour ennemi (Trap, riposte) | commun : `Combat.applyStatus` pose `e.stopTurn` si l'ennemi est celui qui agit (`c.acting`) ; `executeMove` arrête le tour avant le coup suivant (aucun coup de l'attaque qui a déclenché l'effet), consomme une charge, journal `{ t = "stunned", stopped = true }` ; « act » n'est journalisé qu'à la première action qui part (`decisions.md`) |
| Totems à durée et emplacements (Shaman) | Power `slot = "fire"…`, `lasts = N` (+ `totem = N` pour la plaque), `powerLasts` (Totemic Relic), `onPowerEnd` ; affichage des quatre emplacements dans `ns.ClassViews.shaman` |
| Maelstrom à 5 : Cast instantané | `onResource` + `instantCast` |
| Formes et lignes « Forme: » (Druid) | état de classe `c.cls.form` ; conditions `bear`, `cat`, `moonkin`, `caster` (registre prêt) dans `Combat.CONDITIONS` ; `cond = "bear"` sur les effets ; événement propre `onShift` ; pastille : `resource = nil`, la forme dans `ns.ClassViews.druid` |
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

### Épiques du Voleur (14/11/2026)

Données et nombres (`EPIC_N`, seule source : textes et règles) dans `Data/Rogue.lua` ; règles (`deckHooks`,
`ns.Rogue`) dans `Core/Classes/rogue.lua` ; vue (ligne de l'épique sous les états du héros, marques
d'Atrophic Poison) dans `UI/Art/rogue.lua` ; tests `Sim/tests_epic_rogue.lua`, harnais UER.
- **Deflection** : `onStatusApplied` (Parry sur le héros, `n` demandé avant le plafond de 3) ; compteur
  `c.cls.ripostes` du tour (`c.cls.riposteRound`, le début du combat compte pour le tour 1, le tour ennemi
  continue le compte) ; coup sans carte (`calcDamage` avec `cardDef` nil) sur `c.player.lastTarget` ou l'ennemi
  vivant le plus à gauche ; journal `{ t = "riposte", dst, n, base }`. `ns.Rogue.ripostes(c)`, `nextRiposte(c)`.
- **Doomblade** : crochet moteur `convertHit` (ci-dessus), Attacks à effet `surge` seulement ; DoT par le crochet
  `apply` (Crystal Vial), icône poison.
- **Atrophic Poison** : `enemyDamage` (×0,75 si l'ennemi garde du DoT après son tick : hors du tour ennemi, on
  retire la baisse `dotDecay`, l'intention affichée est juste ; pas de cumul avec un vrai Demoralized),
  amélioré `damage` (×1,25, pas de cumul avec Sundered). `ns.Rogue.countsDemoralized(c, e)`.
- **Echoing Reprimand** : `surge` (2 ou 3 -> N) ; aucune autre source du Voleur ne modifie `surge` avant.
- **Subterfuge** : `stealthBreak` faux ; durée `c.cls.stealthUntil` (posée à chaque Stealth reçu, et par
  `whileInDeck` pour celui du départ), retrait dans `onTurnEnd` ; Combo par Stealth gagné (`c.cls.stealthGained`).
- **Kidney Shot** : `onSurge` (dépense réelle, carte à cible) marque le `ctx`, `onCardPlayed` étourdit la cible
  vivante (boss : Demoralized 2).
- **Danse Macabre** : `onCardCommitted` tient les ids joués du tour (`c.cls.dmNames`, `dmCount`, `dmRound`) ;
  `damage` ajoute N par autre id, au plus le plafond.

## Sauvegarde

`Save.VERSION` 5, `Expedition.VERSION` 6 (version 6 : cartes épiques, `docs/expedition.md` ; épique en jeu : `c.epic`, champ facultatif) : version 3, migration de la Démence du combat en cours
(`c.player.demence` → `c.player.res`, `c.class`, `c.cls`) ; version 4, niveau de classe (`cs.xp` tiré de
l'ancienne réputation de classe, `exp.unlock.level`, docs/expedition.md) ; version 5, campagne par zones
(`cs.zones`, `meta.zones`, `exp.zone`, `exp.unlock.common` et `won`, Ligue abandonnée, `docs/zones.md`). Une classe qui ajoute un état de combat le
range dans `c.cls` (données simples) : rien à migrer tant que les champs absents ont une valeur par
défaut. Une expédition d'une classe inconnue (fichier retiré) part en quarantaine (`Save.validateExpedition`).
