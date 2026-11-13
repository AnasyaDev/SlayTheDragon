# Coder une zone (guide de l'agent de zone)

Une expédition se joue dans **une zone** ; la campagne en compte sept (décisions du joueur du 13/11/2026).
Ce document est le contrat d'une zone : ce qu'il faut écrire, où, avec quels crochets du moteur, et ce qu'il
ne faut pas toucher. Une zone se code **dans ses propres fichiers** : le moteur, l'interface, le bot et les
harnais savent déjà tout ce que les six fiches demandent (table « besoin → crochet » par zone, plus bas).
Fiches : `docs/zones/<zone>.md` ; `docs/zones/decisions.md` prime sur les fiches ; cartes de zone (épiques) :
`docs/zones/cartes-de-zone.md` (un autre lot, pas l'agent de zone).

| Ordre | Id (`ns.Zones`) | Nom affiché | Fichier de données | État |
| --- | --- | --- | --- | --- |
| 1 | `westfall` | Westfall | `Data/Zones/Westfall.lua` | jouable (boss Edwin VanCleef ; décors peints et personnages de la Marche depuis le 13/11/2026), sans règle de zone |
| 2 | `duskwood` | Duskwood | `Data/Zones/Duskwood.lua` | jouable (Curse, boss Morbent Fel ; décors peints forêt noire, cimetière, Darkshire ; 14/11/2026, docs/zones/duskwood.md « Implémentation ») |
| 3 | `wetlands` | Wetlands | `Data/Zones/Wetlands.lua` | jouable (14/11/2026 : mécanique Pack, élites Sarltooth / Modr / Dragonmaw Centurion, boss Chieftain Nek'rosh, 8 rencontres, commun du tier 3, bibelots de clé, Gryphon Master, huit décors peints ; détails : `docs/zones/wetlands.md`, « Implémentation ») |
| 4 | `stranglethorn` | Stranglethorn Vale | `Data/Zones/Stranglethorn.lua` | jouable (13-14/11/2026) : Hex (seul), boss Jin'do the Hexxer, six décors peints de la jungle, Gurubashi Arena ; détails et mesures : `docs/zones/stranglethorn.md`, « Implémentation » |
| 5 | `swamp` | Swamp of Sorrows | `Data/Zones/Swamp.lua` | jouable depuis le 14/11/2026 (Slumber : dormeurs, ouvertures, Rude Awakening ; boss Somnus ; sept décors peints) ; détails et mesures : `docs/zones/swamp.md`, « Implémentation » |
| 6 | `steppes` | Burning Steppes | `Data/Zones/Steppes.lua` | jouable (Wildfire, boss Grark Lorkrub ; décors peints roche brûlée et lave ; 14/11/2026, `docs/zones/steppes.md` « Implémentation ») |
| 7 | `blackrock` | Blackrock Mountain | `Data/Zones/Blackrock.lua` | jouable (14/11/2026) : phases (moteur commun) et règles propres (Invincible, Fire Shield, Shadow of the Throne, Class Call), boss Nefarian (3 phases), Grim Guzzler, titre « Dragonslayer » ; six décors peints (peintre `cavern`) ; implémentation : `docs/zones/blackrock.md` § 13 |

Le rang d'une zone (colonne « Ordre », `ns.Zone.order`, `Expedition.zoneRank`) règle aussi, hors des fichiers de
zone, la chance qu'une épique tombe sur un élite (`Expedition.EPIC.drop.elite`, 25 % à 85 %) et la part de rares
des récompenses de cartes (`Expedition.RARE_BY_ZONE`, ×1 à ×2) : `docs/expedition.md`, « Cartes épiques ».

## 1. Fichiers d'une zone

Déjà créés (vides) **et déjà au TOC** : ne pas toucher au TOC.

| Fichier | Contenu |
| --- | --- |
| `Data/Zones/<Zone>.lua` | ennemis (`ns.Enemies`), groupes (`ns.Encounters.<zone>`), rencontres (`ns.Declare.event`, `zone = "<zone>"`), commun débloqué par la zone (`ns.Declare.neutralCard`, `ns.Declare.relic`, `ns.Declare.potion`, rencontres et cases communes : `tier = <ordre>`), bibelots de clé (`key = { zone, level }`), cartes de combat (`token = true`), puis **en dernier** `ns.Zones.<zone>.encounters = "<zone>"` (la zone devient jouable) et `ns.Zones.<zone>.scenes` (décors). Chargé après `Data/Events.lua`. |
| `Core/ZoneRules/<zone>.lua` | la mécanique : `ns.ZoneRule.define("<zone>", { … })` (§ 3), états (`ns.Statuses`), effets de carte (`ns.Effects`), actions, conditions et montants d'ennemis (`Combat.ENEMY_ACTIONS`, `ENEMY_CONDITIONS`, `ENEMY_AMOUNTS`), effets de rencontre (`Expedition.EFFECTS`), cases de parcours (`Expedition.nodeKind`), mots du langage (`ns.Language.zoneKeyword`, `L.trigger`, `L.condition`). Lua 5.1 pur, aucune API WoW. |
| `UI/Art/Zones/<zone>.lua` | art et affichage : `Art.enemies`, `Art.npcs`, `Art.cards`, `Art.relics`, `Art.statuses`, `Art.statusShort`, `Art.intents` / `Art.intentName` (intention propre : `hex`, `curse`…), `Art.actionText`, `Art.intentParts`, `Art.ui.map[case]`, `Art.ui.mapBoss.<zone>` (icône du boss sur le parcours, repli : VanCleef), décors (`Art.scenes`, `Art.paintings`, `Art.palettes`), vue `ns.ZoneViews.<zone>` (§ 6). |

À créer par l'agent de zone (lus d'office s'ils existent, hors TOC) :

| Fichier | Contenu |
| --- | --- |
| `Sim/tests_zone_<zone>.lua` | `return function(T) … end` : tests de la zone, lancés par `Sim/tests_zones.lua` (§ 8). |
| `Sim/zones/<zone>.lua` | `return function(ns, Bots, SE) … end` : conseils au bot (`ns.ZoneBots.<zone>`, `SE.KIND_SCORE`, `SE.EFFECT_VALUE`, `SE.CAMP_ACTION`), chargé par `Sim/load.lua` (§ 9). |
| `Sim/ui_zone_<zone>.lua` | `return function(T) … end` : section du harnais d'interface (« UZ<lettre> »), lancée à la fin de `Sim/ui_harness.lua` (§ 8). |
| `Media/Icons/*.tga` + `UI/SkinData.lua` | `build/venv/bin/python -I tools/build_media.py --icons-only` (lit aussi `UI/Art/Zones/*.lua`). `UI/SkinData.lua` est le seul fichier commun que deux zones modifient (table triée : conflit trivial, ou relancer après la fusion). |

**Interdit** (fichiers partagés, sauf besoin nouveau signalé au rapport) : `Core/Combat.lua`, `Core/Effects.lua`,
`Core/Expedition.lua`, `Core/Map.lua`, `Core/Meta.lua`, `Core/Save.lua`, `Core/ZoneRules.lua`, `Core/Language.lua`,
`Data/<Classe>.lua`, `Core/Classes/`, `Data/Neutral.lua`, `Data/Relics.lua`, `Data/Events.lua`,
`Data/Zones/Westfall.lua`, `UI/*.lua` (CombatView, Widgets, Screens, Controller, Scene, ZoneView, Art), le TOC,
`Sim/tests.lua`, `Sim/tests_expedition.lua`, `Sim/ui_harness.lua`, `Sim/bots.lua`, `Sim/expedition.lua`,
`Sim/sim.lua`. Westfall doit rester identique à graine égale.

## 2. Format des ennemis (`Data/Zones/<Zone>.lua`)

```lua
ns.Enemies.vile_fang = {
  name = "Nightbane Vile Fang", hp = { 28, 31 },            -- nombre ou { min, max } (flux c.rng.ai)
  elite = false, boss = false, minion = false,               -- minion : fuit à la mort du dernier ennemi principal
  indomitable = false,                                       -- immunisé à Stunned comme un boss (Combat.stunImmune)
  moves = { bite = { name = "Vile Bite", intent = "attack", cast = false, text = "…",
                     actions = { { "attack", 9, curse = "rabies" } } }, … },
  pattern = { "bite", "maul", "howl" }, randomStart = true,  -- ou ai = function(c, e, rng) return "move" end
  open = "ravage",                                           -- intention du 1er tour (annoncée), puis le motif
  phases = { … },                                            -- seuils de PV (ci-dessous)
  init = f(c, e), onDamaged = f(c, e, perte), onDeath = f(c, e), onAllyDeath = f(c, e, mort),
  -- champs libres lus par les règles de la zone (asleep = 2, opener = "death_roll", pack = { "force", 2 },
  -- wildfire = 2…) : le moteur les ignore
}
```

`intent` (icône de la bulle) : `attack`, `defend`, `cast`, `watch`, `debuff`, `buff`, `heal`, `summon`, ou une
intention de zone déclarée par `Art.intents.<clé>` et `Art.intentName.<clé>`. `cast = true` : incantation
(interruptible : `Effects.interrupt`, perdue si interrompue) ; ses actions peuvent être n'importe quoi
(effet libre : action de zone, `fn`).

**Actions** (`moves[...].actions`, et `enter` d'une phase) :

| Action | Effet |
| --- | --- |
| `{ "attack", n, times = k, interrupts = bool }` | coups ; Trap déclenchée avant ; `more = { { k, "cond" } }`, `per = { k, "montant" }`, `bonus = f(c, e, a)`, `cap` (plafond du bonus) : base variable affichée par la bulle (`Combat.enemyBase`) |
| `{ "block", n }`, `{ "block_ally", n }` (au hasard), `{ "block_allies", n }` (tous, lui compris), `{ "block_boss", n }` (le boss, sinon lui) | Absorb |
| `{ "debuff", état, n }`, `{ "buff", état, n }`, `{ "buff_allies", état, n }` | états |
| `{ "heal_ally", n }` (le plus blessé), `{ "heal_allies", n }` (soin de groupe), `{ "heal_self", n }` | soins |
| `{ "summon", id, count = k, max = m, ambush = bool, st = { état = n } }` | invocation (max : tant qu'il en vit moins de m ; ambush : agit dès cette phase ennemie) |
| `{ "interrupt" }`, `{ "say", "texte" }`, `{ "die" }` (se détruit), `{ "fn", f(c, e) }` | divers |
| `{ "addCard", id, to = "discard" \| "draw" \| "drawRandom" \| "hand", n = 1, lift = true }` | carte de combat dans les piles du joueur, levée à la mort du lanceur |
| `{ "<action de zone>", … }` | `Combat.ENEMY_ACTIONS["<action>"] = function(c, e, a) … end` (Core/ZoneRules/<zone>.lua) |

Toute action peut porter **`cond = "nom"`** ou une fonction (action conditionnelle, sautée sans élan ni Trap) :
`Combat.ENEMY_CONDITIONS.nom = function(c, e, a) return bool end` ; communes : `allies` (un autre ennemi vit),
`casting` (le joueur incante). Montants : `Combat.ENEMY_AMOUNTS.nom = function(c, e, a) return n end` ;
commun : `allies`. Ex. : `{ "attack", 10, more = { { 5, "lit" } } }` (Wildfire), `{ "attack", 9, per = { 3, "hexed" } }`
(Headhunter), `{ "attack", 6, per = { 3, "asleepAllies" }, cap = 9 }` (Dreamwalker).

**Phases** (seuils de PV, moteur commun : marques sur la barre, déclenchement, intention d'ouverture) :

```lua
phases = {   -- du plus haut au plus bas
  { at = 0.5,                -- fraction des PV max (ou hp = N)
    name = "Enraged", text = "Gains Strength 4.", say = "…",   -- bandeau, infobulle du cran, réplique
    enter = { { "buff", "force", 4 } },                         -- actions d'entrée (mêmes actions)
    open = "whirlwind", label = "Next",                         -- intention d'ouverture
    pattern = { "strike", "whirlwind" }, ai = f, randomStart, startAt = 2, -- motif de la phase
    rename = "Nefarian", art = "nefarian",                      -- nom et modèle (Art.enemies[art])
    cap = true },                                               -- boss : dégâts au-delà du seuil perdus
}
```

Franchi à ou sous le seuil, une seule fois, quelle que soit la source ; un coup mortel n'en déclenche aucun ;
plusieurs seuils d'un coup : toutes les phases dans l'ordre. Ouverture : pendant le jeu du joueur
(`c.step == "play"`), elle remplace l'intention annoncée tout de suite (incantation comprise) ; sinon
(fin de tour, phase ennemie, DoT au début du tour) elle sera la prochaine intention. Les sbires n'ont pas de
phase. Notification `onEnemyPhase(e, k, phase)` ; `e.mem.phase` = phase en cours ; `Combat.phaseMarks(e)`.

**Groupes** : `ns.Encounters.<zone> = { easy, normal, elite, boss, event_* }` ; une entrée est un id ou une
spec `{ "sawtooth_crocolisk", st = { asleep = 3 }, hp = 40, hpMul = 1.15, ambush = true, zs = { … } }`.

## 3. Règles de zone (`Core/ZoneRules/<zone>.lua`)

```lua
local _, ns = ...
local Combat, ZR = ns.Combat, ns.ZoneRule
ZR.define("duskwood", {
  always = false,                -- vrai : crochets actifs dans TOUTES les zones ; ou function(opts) -> bool : actifs
                                 -- hors de leur zone pour un combat qui en a besoin (opts de Combat.new : deck,
                                 -- relics, encounter, mods ; nil hors combat) — Swamp : deck qui pose Asleep, Egg of Hakkar
  init = function(c, z) z.curses = 0 end,           -- z = c.zs.duskwood (après l'init de la classe)
  hooks = { … },                 -- crochets de combat (ci-dessous), src = z
  run = { … },                   -- crochets d'expédition (§ 5)
  campfire = { … },              -- actions du feu de camp (§ 5)
  newExpedition = function(exp) end,                -- appelé pour TOUTES les zones à chaque nouvelle expédition
})
```

Zones actives dans un combat : celle de l'expédition (`c.zone`) puis celles qui portent `always` (`c.zr`, liste
figée). Ordre des crochets : classe, zones, cartes du deck à effet passif (épiques, `deckHooks`), Pouvoirs, bibelots, affixes. `c.zs[id]` et
`e.zs[id]` (`ZR.unitState(e, id)`) : données simples, copiées en profondeur par `Combat.clone` (le bot clone
les combats), sauvegardées. **Jamais de fonction ni de référence à une unité dans l'état** (uid seulement).
Les mêmes noms de crochets servent aux bibelots (`relic.hooks`) et aux Pouvoirs : un bibelot de clé d'une zone
s'abonne aux mêmes événements. Moment du round : `c.step` = `turnStart`, `play`, `turnEnd`, `enemy`, `roundEnd` ;
genre du combat : `c.kind` (`combat`, `elite`, `boss`).

### Notifications (`hooks.nom = function(c, z, …)` ; renvoyer true arrête la chaîne)

| Nom | Arguments | Quand |
| --- | --- | --- |
| `onCombatStart` | — | après les init, avant le premier tour |
| `onCombatEnd` | résultat (`won`, `lost`, `fled`) | combat tranché |
| `onTurnStart` | — | début du tour du joueur (après pioche, avant les intentions) |
| `onIntents` | — | intentions annoncées (le joueur va jouer) |
| `onTurnEnd` | — | fin du tour du joueur (familier, Pouvoirs), puis lignes `End of turn` des cartes en main |
| `onHandEnd` | — | main encore entière, juste avant la défausse (verrouillage du Hex) |
| `onCardKept` / `onCardDiscarded` | instance, raison (`retain` / `pick` ; `turn` / `interrupted`) | défausse de fin de tour, incantation coupée |
| `onCardDrawn` | instance | chaque carte piochée |
| `onCardAdded` | instance, pile, src | `Combat.addCard` |
| `onCardRemoved` / `onExhaust` | instance, raison (`played`, `lifted`, `removed`…) | carte retirée / épuisée |
| `onCardTransformed` | originale, nouvelle, pile | `Combat.transformCard` |
| `onEnemyPhaseStart` / `onEnemyPhaseEnd` | — / skipped | phase ennemie (skipped : Feign Death) |
| `onEnemyStunned` | ennemi | tour perdu par Stunned |
| `afterEnemyMove` | ennemi, move | après l'action d'un ennemi |
| `afterEnemyAttack` | ennemi, action, PV perdus au total | fin d'une action d'attaque (tous ses coups) : Bite |
| `onEnemyCastStart` / `onEnemyCastResolved` / `onEnemyCastInterrupted` | ennemi, move (, `"player"`) | incantation annoncée / partie / coupée |
| `onEnemyDamaged` | ennemi, PV perdus, absorbés, source | coup porté à un ennemi qui survit (même entièrement absorbé) |
| `onEnemyBloodied` | ennemi | premier passage à ou sous la moitié des PV |
| `onEnemyPhase` | ennemi, k, phase | seuil franchi |
| `onEnemyDeath` | ennemi, info = { effect, fx, kind, single, minion } | mort ; même `info.effect` = morts du même effet (Pack) |
| `onEnemySpawn` | ennemi, invocateur | invocation en cours de combat |
| `onEffectEnd` | genre, numéro | fin d'un effet (carte, incantation, Trap, potion, DoT, action ennemie, début / fin de tour, fin de round) : régler les primes groupées |
| `onHpLost` | n, source (unité, `pay`, `effect`, why de `loseHp`, nil = DoT), PV d'avant | toute perte de PV du joueur |
| `onUnitHeal` | unité, PV rendus | soin réellement rendu (joueur ou ennemi ; `onHeal` (PV rendus, surplus) : soin tenté du joueur, socle épique) |
| `onRoundEnd` | skipped | fin du round, avant les durées (Wildfire) |
| `onStatusApplied`, `onDotTick`, `onPlayerHit`, `afterHit`, `onCardPlayed`, `onCardCommitted`, `beforeCard`, `onCastStart`, `onCastResolved`, `onTrapSet`, `onTrapTriggered`, `onAttackHit`, `preventDeath`… | | inchangés (`docs/classes.md`) |

### Valeurs modifiées (`hooks.nom = function(c, z, v, …) return v end`)

| Nom | Arguments après v | Quand |
| --- | --- | --- |
| `enemyDamageTaken` | ennemi, source | dégâts d'un coup sur un ennemi, avant son Absorb (Unholy Shield, Invincible, Wyrmscale Armor) |
| `enemyDamageLast` | ennemi, source | idem, après tous les `enemyDamageTaken` (multiplicateur « en dernier » : Rude Awakening) |
| `enemyMove` | ennemi | action d'un ennemi à son tour : un autre move la remplace, **false la saute** (dormeur) |
| `intent` | ennemi | intention choisie (remplacer) |
| `petTarget` | — (v = cible) | cible du familier du Hunter (éviter les dormeurs) |
| `hpLoss` | why | perte de PV hors coup (`loseHp`) : réduire, annuler |
| `cleanse` | unité | effets retirés par « Remove negative effects » : ajouter les Curses de la main épuisées |
| `damage`, `cost`, `drawPerTurn`, `beforeHit`, `enemyDamage`, `apply`, `applySelf`, `heal`, `block`, `maxMana`, `retainPicks`… | | inchangés (`docs/classes.md`) : Curses « In hand », Class Call, Veil of Shadow |

**Source d'un coup sur un ennemi** (table réutilisée, à copier si on la garde) : `kind` = `card`, `cast`,
`trap`, `potion`, `dot`, `pet`, `enemy` (sort renvoyé), `other` (bibelot) ; `single` = vrai pour un effet à une
cible (faux : « to all », DoT) ; `ctx` (carte en cours), `effect`, `src`.

### Aides du moteur

| Aide | Rôle |
| --- | --- |
| `Combat.addCard(c, id, to, { src = uid, lift = bool, up })` | carte de combat (`token = true`) dans `hand` (pleine : défausse), `draw` (dessus), `drawRandom`, `discard`, `exhaust` |
| `Combat.liftCards(c, uid)` | lève (épuise) les cartes `lift` posées par l'ennemi uid (fait d'office à sa mort) |
| `Combat.removeCard(c, inst, why, "exhaust" \| "vanish")`, `Combat.findCard(c, inst)`, `Combat.countCards(c, pred)` | piles |
| `Combat.transformCard(c, inst, id, { src })` / `Combat.restoreCard(c, inst)` | Hex : remplacée sur place (main, pioche, défausse), carte d'origine dans `inst.orig` ; rendue en main |
| effets `{ "restore" }`, `{ "restoreAll", id = "hexed" }`, `{ "addCard", id, to, n }` | idem, depuis une carte |
| champs de carte `token`, `vanish`, `endOfTurn = { effets }`, `unplayable`, `retain`, `exhaust`, `payHp` | cartes de combat (Curse : `token`, `exhaust`, `endOfTurn` ; Hexed : `token`, `vanish`, `{ "restore" }`) |
| `Combat.forceIntent(c, e, move, { now, label })` | intention imposée (tout de suite pendant le jeu, sinon la prochaine ; `label` = « On waking ») |
| `Combat.enterPhase(c, e, k)`, `Combat.phaseMarks(e)`, `Combat.enemyName(e)` | phases |
| `Combat.spawn(c, spec, by)`, `Combat.enemyAction(c, e, action)`, `Combat.enemyBase(c, e, a)`, `Combat.enemyTest` | ennemis |
| `Combat.loseHp(c, n, why)` | perte de PV sans Absorb ni Parry (terrain, Curse) ; effet `{ "loseHp", n, why = "curse" }` |
| `Combat.asEffect(c, genre, own, fn, …)` | faire d'une action de zone un effet à part |
| `Combat.zstat(c, clé, n)` | statistique de zone (affichée par `Sim/sim.lua`, par type de combat) |
| `ZR.unitState(e, id)`, `ZR.float(c, unité, texte, couleur)`, `ZR.counterChanged(c, zone, clé, n, d)`, `ZR.active(c, id)` | état d'unité, texte flottant, compteur affiché (journal) |
| condition `interrupted` | la carte a coupé une incantation (« Interrupted: … », à déclarer au langage) |

Le familier du Hunter n'est pas modifié : `Core/ZoneRules.lua` habille `Hunter.petAttack` (source `pet`) et
`Hunter.petTarget` (crochet `petTarget`).

## 4. Langage, états

- `ns.Language.zoneKeyword("<zone>", "curse", { name = "Curse", text = "Enemy card, for this combat only." })` :
  mot expliqué au survol des cartes qui le citent (60 caractères au plus). Libellés « Name: » : `L.trigger("In hand")`,
  `L.condition("interrupted", { name = "Interrupted", text = "…" })`. Le texte des cartes suit `docs/classes.md`
  (harnais U27, U22 : les cartes de combat `token` aussi).
- États (`ns.Statuses.asleep = { name, text, debuff, duration, max, flag, clearAtTurnStart }`) : jeton avec nombre
  sous l'unité d'office (« Asleep 2 ») ; icône `Art.statuses.asleep`, définition courte `Art.statusShort.asleep`.
  Boss immunisés à un état : crochet `apply` (renvoyer 0).

## 5. Expédition (cases, rencontres, feu de camp, compte)

| Besoin | Point d'accroche |
| --- | --- |
| crochets d'expédition | `run = { gold, goldBonus, price, removePrice, restFraction, restHeal, healOut (tout soin hors combat), rewardCards (v = 3, genre), onNodeEnter, onCombatWon (genre, fight), onRest, onRewardRolled (récompense, genre), onFightStart (fight, options du combat) }` ; mêmes noms dans `relic.run` (Flagongut's Fossil : `rewardCards` ; Cursed Eye : `healOut`) |
| état d'expédition | `Expedition.zoneState(exp, id)` → `exp.zs[id]` (affiche WANTED posée sur une élite…) |
| case de parcours | `Expedition.nodeKind("gryphon_master", { name = "Gryphon Master", tier = 3, zone = nil, event = "gryphon_master" \| enter = f(exp, node), replaces = { "event" }, minFloor = 3, maxFloor = 6, chance = 1, count = 1 })` ; la rencontre porte `node = true` (jamais tirée au hasard) ; placée sur un flux à part (aucun effet sur les cartes existantes) ; icône `Art.ui.map.gryphon_master` |
| effet de rencontre | `Expedition.EFFECTS.nom = { roll = f(exp, rng, e), check = f(exp, e) -> ok, raison, apply = f(exp, e, tirage, ctx) }` ; fournis : `nextCombat` (`{ "nextCombat", { effets } }` résolus au début du prochain combat, après la pioche), `skipFloors` (`{ "skipFloors", 1 }` : vol, `Expedition.nextNodes`), `chain` (`{ "chain", id }` : rencontre suivante, Grim Guzzler) |
| combat de rencontre | `{ "fight", groupe, kind = "elite", gold = n, group = true (groupe tiré à l'entrée, texte « %s » = 1er ennemi, « %g » = tout le groupe), st = { asleep = 3 } (hors boss), hpMul = 1.15, reward = { cards = 4, shift = 1 } }` |
| combat lancé par une case | `Expedition.startFight(exp, genre, groupe, récompense, { idx, mods })`, `Expedition.rollReward(exp, genre, { cards, shift })`, `Expedition.openReward`, `Expedition.leaveNode` |
| feu de camp | `campfire = { { id, label, text, can = f(exp) -> ok, raison, apply = f(exp) -> "stay" } }` : bouton au-dessus de « Back on the road », action `{ "campAction", id }` |
| drapeaux d'histoire, titres | `Expedition.setFlag(exp, "dragonslayer:priest")` (reporté dans la méta) dans `run.onCombatWon` ; `newExpedition(exp)` pour un effet de compte sur l'expédition suivante (Rallying Cry) |

## 6. Interface (`UI/Art/Zones/<zone>.lua`)

```lua
ns.ZoneViews.swamp = {
  counter = function(c) return { icon = …, text = "Wildfire in 2", tip = "…", hot = false } end, -- en haut au centre
  intent = function(c, e) return { icon = …, text = "Asleep 2", color = "defend", title = "Asleep", tip = "…", showMove } end,
  intentBadge = function(c, e) return { icon = …, tip = "Bite: …" } end,  -- petite icône à droite du chiffre
  enemyBadges = function(c, e) return { { icon, text = "+2 Str", tip, color, dim } } end,  -- sous l'intention (3 au plus)
  marks = function(c, e) return { { at = 0.5, name, text, color } } end,   -- crans en plus (les phases sont d'office)
  handMark = function(c, i, inst) return { rim = { r, g, b, a }, icon = …, tip = "…" } end, -- carte visée (Hex)
  build = function(host, view) end, render = function(host, c, view) end, event = function(host, ev, view) end,
}
Art.intentParts.stoke = function(c, e, a) return "+" .. a[2] end         -- chiffre de la bulle
Art.actionText.stoke = function(a, c, e) return "Wildfire " .. a[2] .. " rounds sooner." end -- infobulle
```

D'office (rien à déclarer) : crans des phases sur la barre de vie (infobulle « Below 50%: Enraged. … »),
intention suivante en gris (`Combat.forceIntent` avec `label`), nom et modèle d'une phase, bandeau de phase,
corps sobre des cartes `token`, nom de la carte d'origine au-dessus d'une carte transformée, textes flottants
du journal (`float`, `phase`, `counter`, `card_added`, `card_transformed`, `cards_lifted`), boutons du feu de
camp, texte des rencontres à groupe. Le calque `build` / `render` est sans souris, au-dessus du décor ;
`view.slotOf[uid]`, `view:UnitPos(uid)`, `view:Push(délai, fn)`, `view.playerHp` comme pour `ns.ClassViews`
(`docs/classes.md`). Rappels : un cadre rogneur dessine tout son sous-arbre à son niveau ; un modèle 3D
recouvre les régions des cadres de niveau inférieur ou égal (étage `f.ui`), ce qui passe dessus va sur
`UI.overlay` ; pièces d'habillage embarquées seulement ; aucun zoom au survol ; aucun raccourci clavier.
Vérifier toute API WoW avec le MCP wow (`wow_api_search`, `wow_ui_grep`) et passer `wow_lua_lint`.

**Décors.** Une zone remplace les décors communs choisis par les écrans (`road`, `hill`, `camp`, `shop`,
`night`, `mine`, `farm`, `ruins`, `coast`) par les siens : `ns.Zones.<zone>.scenes = { road = "duskwood_road", … }`
(valeur : clé d'`Art.scenes`, déclarée dans `UI/Art/Zones/<zone>.lua` ; `UI.setStage` passe par
`Controller.zoneScene`). Westfall le fait (`Data/Zones/Westfall.lua` : `road`, `hill`, `camp`, `shop`, `night` →
`westfall_*`, décors peints couleur blé) ; les décors communs `road`… `night` sont ceux de Westfall tant qu'une
zone n'a pas les siens. Décor peint (comme Westfall) :
`Art.scenes.duskwood_road = { paint = "duskwood_road" }`, `Art.paintings.duskwood_road = { pal = "duskwood",
horizon, field, sun | moon, clouds, hills, mound, trees, road, props, wheat }` (plans et accessoires de
`UI/Scene.lua`, `S.landscape`, `PROPS`) et `Art.palettes.duskwood = { sky, sun, cloud, hillsBack, hillsFront,
mound, trees, haze, patches, hedge, fieldsNear, road, far, mid, ground, … }` (mêmes clés que la palette
`westfall` d'`UI/Art.lua`, `night = true` pour une nuit). Plans propres à une zone (ajout des Burning
Steppes, générique) : `layers = { skyline = f, ground = f, front = f }` dans l'entrée d'`Art.paintings`, appelés
avec `(kit, cadre, g, entrée, palette)` après les collines lointaines, après la route et à la fin ;
`S.paintKit` donne les formes et niveaux du peintre (`box`, `vgrad`, `oval`, `blur`, `bar`, `diamond`, `tri`,
`hash`, `rgb`, `mix`, `LV`), `S.PROPS` le registre des accessoires ; `furrows = false` retire les rangs de champ
du sol proche (exemple complet : `UI/Art/Zones/steppes.lua`). Décor qui n'est pas un paysage à ciel ouvert (intérieur de montagne) : `painter = "<nom>"` dans l'entrée
d'`Art.paintings` et `Art.painters.<nom> = function(f, g, sp, K)` dans le fichier d'art de la zone (`K` =
`S.paintKit`), choisi par `S.paint` (Blackrock : peintre `cavern`). Fond embarqué : `tools/build_backgrounds.py` et
`Art.backgrounds` / `Art.illustrations`. Rencontre : `scene = "<clé>"`.
Paysage peint en entier par sa zone (ajout de Stranglethorn, générique) : `draw = function(kit, cadre, g, entrée,
palette) … end` dans l'entrée d'`Art.paintings` remplace tous les plans de `S.landscape` (ciel, champs, route) ;
mêmes formes et niveaux (`S.paintKit`), accessoires communs par `ns.Scene.PROPS` ; chaque région va dans `g`, sous
`BORDER 0` (exemple : `UI/Art/Zones/stranglethorn.lua`, fonction `jungle` : collines boisées, canopées, palmiers,
sous-bois, côte de Booty Bay, pyramides trolls).
Swamp of Sorrows (14/11/2026) : rien d'ajouté à `UI/Scene.lua` ; ses accessoires (arbres morts à mousse,
huttes, tour de guet, temple, roseaux) et ses mares sont peints par son plan `layers.ground` avec `S.paintKit`
(`UI/Art/Zones/swamp.lua` : `items`, `pools`, palette `water`, `waterEdge`, `moss`). Planches : il faut les aperçus
PNG de `Media/` dans `build/media_png` (`tools/build_media.py`, ou une conversion des TGA) ; sans eux, taches fondues
et disques sont dessinés en rectangles dans les SVG du harnais.

Accessoires génériques ajoutés par Duskwood (14/11/2026, `UI/Scene.lua`, `PROPS`) : `deadtree` (arbre mort tordu),
`oak` (feuillu sombre, liseré de lune `rim`), `pine` (sapin), `treeline` (lisière de x à x2 : `{ "treeline", x, y,
échelle, plan, x2 }`), `bush`, `tombstone` (variante `cross`), `crypt` (variante `lit` : porte éclairée, `pal.glow`),
`lamppost`, `web` (`pal.web`), `mist` (banc de brume de x à x2), `glow` (flaque de lumière : `pal.glow`, variante
`moon` : `rim` du plan) ; plan `back` (lisière derrière la brume de l'horizon, couleurs `pal.back`). Couleurs de
plan en plus : `light`, `rim = { couleur, alpha }`.

Les Wetlands (`UI/Art/Zones/wetlands.lua`) ajoutent leurs accessoires au registre `S.PROPS` sous le nom
`wl_<genre>` au premier décor de la zone peint (UI/Scene.lua est chargé après les fichiers d'art), utilisables
dans `props` par toute zone qui peint après eux : `wl_marsh_tree` (variante `dead`), `wl_rocks`, `wl_ship`
(`small`), `wl_pier` (variante = x de fin), `wl_keep`, `wl_banner`, `wl_ruin`, `wl_orc_tent`, `wl_scaffold`,
`wl_gate`, `wl_harbor_house`, `wl_cargo`.

**Commun déclaré par une zone** : poser `fromZone = "<zone>"` sur les cartes neutres et bibelots déclarés par
`ns.Declare.*` ; les tests du commun d'origine (`Sim/tests.lua`, `Sim/tests_expedition.lua`, harnais : paliers
0 à 3) ne comptent pas ces entrées (vérifiées par `Sim/tests_zone_<zone>.lua`). Nécessaire pour une zone dont le
commun est au palier 3 ou moins (Duskwood, Wetlands) ; les zones 4 à 7 sont déjà hors de ces comptes.

## 7. Tables par zone : besoin de la fiche → crochet

### Duskwood (Curse)

| Besoin (« ce que le moteur doit apprendre ») | Crochet / aide |
| --- | --- |
| 1. cartes de Curse (`curse`, unplayable, retain, payHp, End of turn, In hand, épuisées) | `token = true`, `exhaust = true`, `endOfTurn = { { "loseHp", 3, why = "curse" } }`, `unplayable`, `retain`, `payHp` ; « In hand » = crochets `damage` / `drawPerTurn` / `cost` de la zone qui lisent la main |
| 2. `addCurse` (plafond 6, main pleine → défausse, journal) | fonction de la zone autour de `Combat.addCard(c, id, to, { src, lift = true })` + `Combat.countCards` ; `curse_full` par `Combat.log` |
| 3. action `{ "curse", id, n, to }`, drapeau d'attaque `curse = id` | `Combat.ENEMY_ACTIONS.curse` ; `afterEnemyAttack(e, a, total)` (total > 0, une fois par action) |
| 4. fin de tour | `endOfTurn` (avant la défausse, de gauche à droite) |
| 5. effets en main | crochets `damage` (cardDef.type == "attack"), `drawPerTurn`, `cost` (`c.turn.played == 0`) |
| 6. levée à la mort du lanceur | `lift = true` (d'office dans `Combat.kill`) ; boss : levées à sa mort |
| 7. « Remove negative effects » | crochet `cleanse` : épuiser (`Combat.removeCard(c, inst, "cleansed")`) et compter |
| 8. intention « curse », mini-icône sous Bite | `Art.intents.curse` ; `ZoneViews.duskwood.intentBadge` |
| 9. boss : Unholy Shield, carte donnée, effet qui retire un état | état + `enemyDamageTaken` (moitié) ; `init`/`onCombatStart` → `Combat.addCard(c, "morbents_bane", "hand")` ; effet `ns.Effects` de la zone ; phase 2 : `phases` (`enter` summon, `open`) |
| 10. Reflect (cartes de zone, autre lot) | état `clearAtTurnStart` ; `beforeHit` (coup renvoyé : `Combat.dealDamage(c, e, e, …)`, source `enemy`), `applySelf` → 0 |
| 11. bots | `ns.ZoneBots.duskwood.value` (pénalité des Curses en main / en piles), `skip` |
| 12. statistiques | `Combat.zstat` |
| Wanted Poster, Ghoul Rib, Mor'Ladim's Skull, Morbent's Bane | case / rencontre + `zoneState` + `run.onRewardRolled` ; `applySelf` + crochet de zone appelé par l'ajout de Curse ; `onExhaust` (why `played`) ; `onIntents` |

### Wetlands (Pack)

| Besoin | Crochet / aide |
| --- | --- |
| 1. `pack`, `packLeader`, état `scattered` | champs libres de l'ennemi ; `ns.Statuses.scattered = { flag = true }` |
| 2. file des primes réglée à la fin de chaque effet | `onEnemyDeath(e, info)` → `z.queue` avec `info.effect` ; `onEffectEnd(kind, id)` règle la file (survivants vivants) ; victoire : rien (`onEffectEnd` ne part pas) |
| 3. `block_allies`, `block_boss` | actions communes |
| 4. Ma'ruk (premier coup annulé), Modr (PV perdus depuis son tour) | `enemyDamageTaken` (source ≠ dot) ; `onEnemyDamaged` cumule dans `e.zs`, `enemyMove` lit et remet à 0 (après son DoT) |
| 5. effets `strip`, `steal`, `unpack`, `marked`, Execute par cible | `ns.Effects` de la zone ; `more = { { k, "execute" } }` est évalué par cible ; familier dans l'effet : `Hunter.petAttack` depuis `onEnemyDeath` |
| 6. prime sous la barre, couronne, patte grisée, animation | `ZoneViews.wetlands.enemyBadges` (`dim`), `event` ; aperçu au survol : non fourni (voir limites) |
| 7–8. bots, statistiques | `ZoneBots.wetlands`, `Combat.zstat` |
| Gryphon Master, Flagongut's Fossil, Crude Flint, Cursed Eye, War Banner, Goaz Stone | `nodeKind` + rencontre (`skipFloors`, `healPct`) ; `relic.run.rewardCards` ; `onEnemyDeath` ; `relic.run.healOut` ; `onEnemyDeath` ; `onEnemyDeath` + `onTurnStart` |

### Stranglethorn Vale (Hex)

| Besoin | Crochet / aide |
| --- | --- |
| 1. action `{ "hex" }` (move `cast = true`), `{ "hex_now" }` | `Combat.ENEMY_ACTIONS.hex` / `hex_now` (Death Hex : `onEnemyDeath` avec `c.step == "play"`) |
| 2. `hexTarget` (la plus chère, égalité à gauche) | aide de la zone (`Combat.cost(c, inst)`) |
| 3. verrouillage avant la défausse | `onHandEnd` (lanceurs vivants, non interrompus, non étourdis) → `z.locks[uid] = uid de carte` |
| 4. résolution (main ou défausse), journal | `Combat.findCard` + `Combat.transformCard(c, inst, "hexed", { src })` ; `hex_fizzle` par `Combat.log` |
| 5. carte `hexed`, `unhex`, `unhex_all` | carte `token`, `vanish`, cost 1, `{ "restore" }` ; Jungle Remedy : `{ "restoreAll", id = "hexed" }` |
| 6. `hexedCount`, attaque `perHexed` | `Combat.countCards` ; `Combat.ENEMY_AMOUNTS.hexed` + `per = { 3, "hexed" }` |
| 7. condition `Interrupted:`, Trap sur un Cast | `Combat.CONDITIONS.interrupted` (commune) ; Snake Trap : `enemyMove` (move `cast`, non interrompu) → `Combat.triggerTrap(c, e)` |
| 8–9. statistiques, bots | `Combat.zstat`, `ZoneBots.stranglethorn` (`value`, `skip`) |
| liseré vert et icône sur la carte visée, grenouille | `ZoneViews.stranglethorn.handMark` ; nom d'origine sur la Hexed : d'office |
| Gurubashi Arena, Shrunken Head, Bag of Whammies, Nesingwary 4000, Hero Charm | case + rencontre `fight` (`group = true`, `hpMul = 1.15`, `reward = { shift = 1 }`, `gold = 25`, texte « %g ») ; `onEnemyCastStart` (`e.interrupted = true`) ; `onEnemyCastInterrupted` ; `onCombatStart` ; `retainPicks` |

### Swamp of Sorrows (Slumber)

| Besoin | Crochet / aide |
| --- | --- |
| 1. état `asleep` (définition ou groupe), `opener` | `ns.Statuses.asleep` ; spec `{ id, st = { asleep = 3 } }` ou `init` qui lit `def.asleep` ; `Combat.forceIntent(c, e, def.opener, { now = false, label = "On waking" })` |
| 2. tour d'un dormeur (Stunned : compteur gelé ; mend) | `enemyMove` → false + baisse ; Stunned : le moteur consomme le tour sans appeler `enemyMove` (`onEnemyStunned`) |
| 3. `wake` (ouverture, pas d'action dans la phase en cours) | aide de la zone : retirer l'état, `forceIntent` ; `enemyMove` → false si réveillé pendant cette phase |
| 4. Rude Awakening ×1,5 (une cible, pas le DoT), réveil même absorbé, pas sur un coup mortel | `enemyDamageLast` (`src.single`, `src.kind ~= "dot"`) ; `onEnemyDamaged` |
| 5. ouverture gardée si Stunned | `onEnemyStunned` → `forceIntent` à nouveau |
| 6. familier qui évite les dormeurs | `petTarget` |
| 7. `lull`, `alarm`, `slumber`, attaque `perAsleep` | `Combat.ENEMY_ACTIONS` ; `per = { 3, "asleepAllies" }, cap = 9` |
| 8. `{ "apply", "asleep", n }` (Dream Dust, Egg of Hakkar), boss immunisés | effet commun `apply` + crochet `apply` (0 sur un boss) ; `onStatusApplied` (perte de l'intention) ; `always = true` (Asleep hors du marais) |
| 9. `{ "fight", groupe, asleep = n }` | `{ "fight", groupe, st = { asleep = n } }` |
| 10. icône et compteur, ouverture grisée, animation | `ZoneViews.swamp.intent` ; intention suivante grise d'office ; `ZR.float` ; « Wake » dans l'aperçu : non fourni |
| 11–12. bots, statistiques | `ZoneBots.swamp`, `Combat.zstat` |
| Sleeping Camp, Green Dragonscale, Tender Crocolisk Meat, Chained Essence, Essence of Eranikus | rencontres `fight` avec `st` ; `beforeHit` + `c.relicState` ; `run.onCombatWon` ; `enemyDamageTaken` (avant le ×1,5) ; `onTurnStart` |

### Burning Steppes (Wildfire)

| Besoin | Crochet / aide |
| --- | --- |
| 1. état du champ `{ left, max, blaze }` selon le genre | `init` : `c.kind`, champ `wildfire` des ennemis ; état dans `z` |
| 2. pas de fin de round, sauté si tour ennemi sauté ; `onWildfire` | `onRoundEnd(skipped)` ; `Combat.loseHp(c, blaze, "wildfire")` ; `Combat.fire(c, "onWildfire", n)` (nom libre) et `def.onWildfire` appelé par la zone |
| 3. action `stoke`, prévision dans l'intention | `Combat.ENEMY_ACTIONS.stoke` ; `Art.intentParts.stoke`, `Art.actionText.stoke` |
| 4. mort (pas les serviteurs) | `onEnemyDeath` (`info.minion`) |
| 5. effet `douse` | `ns.Effects.douse` (rien hors de la zone : `ZR.active(c, "steppes")`) |
| 6. `{ "attack", 10, lit = 5 }` | `{ "attack", 10, more = { { 5, "lit" } } }` + `Combat.ENEMY_CONDITIONS.lit` |
| 7. action `ignite` | `Combat.ENEMY_ACTIONS.ignite` ; phases de Grark : `phases` |
| 9. épiques (autre lot, fait) | `onHeal`, `canGainBlock`, `attackMult`, `afterCast`, `resCap` (socle épique) ; `hpLoss` |
| 10. jeton de flamme, portion hachurée | `ZoneViews.steppes.counter` ; `ZR.counterChanged` (battement) ; hachure : `ZoneViews.steppes.render` sur `view.playerHp` |
| 11–12. statistiques, bots | `Combat.zstat`, `ZoneBots.steppes.value` (brûlure à venir) |
| WANTED, Libram of Resilience, Heart of the Mountain | rencontre `fight` `group = true`, texte « %s » ; `hpLoss` + `beforeHit` ; `onTurnStart` |

### Blackrock Mountain (phases)

| Besoin | Crochet / aide |
| --- | --- |
| 1–4. `phases`, `enterPhase`, intention d'ouverture pendant / après le tour | moteur commun (`def.phases`, § 2) |
| 5. crans et textes des phases | `Combat.phaseMarks` ; affichage d'office |
| 6. crans, infobulles, bandeau, nom et modèle | d'office (`rename`, `art`, journal `phase`) |
| 7. `onEnemyPhase`, `onEnemyBloodied` | notifications communes |
| 8. bots, statistiques | clone suffit ; `Combat.zstat` (`onEnemyPhase`, `onEnemyStunned`) |
| règle 7 (Stunned : ouverture perdue, reprise au 2e coup) | ouverture imposée perdue avec le tour ; `startAt = 2` |
| Invincible (6 au plus par coup, pas le DoT), Fire Shield, Throne | `enemyDamageTaken` (`e.mem.phase`, `src.kind`) ; `onEnemyDamaged` (carte Attack ou Trap) → `Combat.loseHp` ; `enemyDamageTaken` |
| Nefarian : plafond au seuil, Bone Constructs en embuscade, Class Call | `cap = true` ; `{ "summon", id, ambush = true }` ou `enter` + `Combat.spawn(c, { id, ambush = true }, e)` ; états de zone + `cost`, `damage`, `applySelf`, `onUnitHeal` |
| Grim Guzzler | `nodeKind` + rencontres `nextCombat` et `chain` (boisson achetée) |
| Dragonslayer, Rallying Cry | `run.onCombatWon` + `Expedition.setFlag` ; `newExpedition(exp)` (`exp.maxHp`) |
| Blood of the Mountain, Black Dragonscale, Draconic Infused Emblem, Neltharion's Tear | `onEnemyBloodied` ; `beforeHit` (move `cast`) ; `onEnemyPhase` + `onEnemyBloodied` ; `cost` |

## 8. Tester

- `lua5.1 Sim/tests_zones.lua` (et `luajit`) → `ALL PASS` : le socle (zone factice `testzone`), puis chaque
  `Sim/tests_zone_<zone>.lua` existant, dans l'ordre de la campagne. Forme :

```lua
return function(T)
  local ns, test, eq, combat, play = T.ns, T.test, T.eq, T.combat, T.play
  test("Duskwood : Bite pose Rabies si le coup fait perdre des PV", function()
    local c = combat({ zone = "duskwood", enemies = { "dark_runner" }, hand = { "smite" } })
    c.enemies[1].intent = "bite"
    ns.Combat.endTurn(c)
    eq(ns.Combat.countCards(c, function(i) return i.id == "rabies" end), 1)
  end)
end
```

  `T.combat({ hand, deck, enemies (ids ou specs), zone, kind, class, relics, hp, mods, start, seed })` : main
  exacte ; `T.play(c, id, cible)`, `T.handIndex`, `T.plainData(v)` (données sauvegardables), `T.root`.
- `lua5.1 Sim/ui_harness.lua 1 build/snap` → `ALL PASS` ; section du socle « UZG » ; `Sim/ui_zone_<zone>.lua`
  (`return function(T) … end`, section « UZ<lettre> ») reçoit `T = { H, ns, check, snap, root, SEED,
  zoneCombat(classe), UI, V, EXP, button, clickOption, option, currentKind, R }` ; `T.snap("zone-<zone>", true)`
  écrit `build/snap/zone-<zone>.svg` (puis `rsvg-convert`).
- Toujours aussi : `Sim/tests.lua`, `Sim/tests_expedition.lua` (`lua5.1` et `luajit`).

## 9. Simuler et régler

- `luajit Sim/sim.lua runs=300 bot=heuristic jobs=8 runner=expedition zone=<zone> zones=<N> level=1..7 key=0 class=<c>` :
  la zone jouée (`zone=`) ; `zones=N` : le compte et la classe ont gagné les N premières zones (commun et cartes
  de zone des N premières, bibelots de clé ; pour jouer la zone d'ordre N, `zones=N-1` est le cas « première
  fois »). « Statistiques de zone (par combat) » : les `Combat.zstat`.
- Bot (`Sim/zones/<zone>.lua`) :

```lua
return function(ns, Bots, SE)
  ns.ZoneBots.duskwood = {
    value = function(c, W) return 0 end,   -- ajouté à l'évaluation (10 = 1 PV du joueur, 4 = 1 PV ennemi)
    key = function(c) return "" end,       -- état de zone qui distingue deux positions
    skip = function(c, a) return false end, -- coup a = { main, cible, sansDépense } à ne pas essayer
  }
  SE.KIND_SCORE.gryphon_master = function(exp, hpRatio, gold) return 1.2 end -- case de parcours
  SE.EFFECT_VALUE.douse = function(exp, e) return 0 end                       -- effet de rencontre de zone
  SE.CAMP_ACTION.treat = function(exp) return 0 end                          -- action de feu de camp
end
```

  Le bot rejoue chaque coup sur une copie, tour ennemi compris (pas la fin de round : le Wildfire passe par
  `value`). Cible : 6 à 9 PV perdus par combat normal (`docs/zones/decisions.md`).

## 10. Ce qui n'est pas fourni (à signaler, pas à coder dans les fichiers partagés)

- Aperçu au survol d'une carte sur les ennemis (primes de Pack, « Wake » du marais) : aucun aperçu de dégâts
  n'existe dans l'écran de combat ; une vue de zone peut l'approcher par `render` (carte choisie :
  `view.selected`), sinon c'est un lot d'interface commun.
- Coffre « choice of 2 relics » (Shadowforge Key) : la récompense n'offre pas de choix de bibelot.
- Vol d'une carte de l'ennemi vers une pile : le texte flottant en tient lieu.

# Campagne (référence)

## Registre (`Core/Zones.lua`)

- `ns.Zones[id] = { id, order, name, encounters, scenes }` ; les sept entrées (id, ordre, nom) sont
  déclarées par `Core/Zones.lua` (`ns.Zone.ORDER`). Le fichier de données d'une zone pose `encounters`
  (et facultativement `scenes`) : sans `encounters`, la zone est déclarée mais pas jouable.
- `ns.Zone` : `ORDER`, `FIRST`, `get(id)`, `count()`, `byOrder(n)`, `order(id)`, `name(id)`, `next(id)`,
  `prev(id)`, `playable(id)` (vrai quand `ns.Encounters[zone.encounters].boss` existe).
- Une expédition porte sa zone (`exp.zone`) ; `Expedition.zoneDef(exp)` rend sa définition,
  `Expedition.actName(exp)` son nom (bandeau, carte). Une zone = un acte (`exp.acts = 1`).

## Ouverture des zones (par classe)

- La zone 1 est ouverte à toutes les classes. **Gagner une zone avec une classe ouvre la zone suivante
  pour cette classe seulement** (`Meta.zoneOpen(meta, classe, zone)`, `Meta.classWon`).
- Une zone se joue si elle est ouverte pour la classe ET jouable (`Meta.newExpedition` refuse sinon :
  `"zone locked"`, `"zone coming later"`).
- À l'accueil, chaque zone est un bouton : jouable (ouverte), « Locked » (zone précédente pas gagnée par la
  classe ; raison « Win <Zone> with the <Classe> to open it. ») ou « Coming later » (pas de données).

## Trois sources de déblocage

1. **Niveau de classe (1 à 7)** : cartes et bibelots de la classe (`level`), inchangé
   (`docs/expedition.md`, « Niveau de classe »).
2. **Première victoire d'une classe dans une zone** : une carte rare et forte de cette classe, liée à la
   zone, introuvable autrement. Champ de la carte : `zone = "westfall"` (avec `class` ; pas de `level`).
   `Expedition.unlocked` la refuse tant que la classe n'a pas gagné la zone (`exp.unlock.won[zone]`) ;
   ensuite elle entre dans la réserve de la classe (récompenses, marchand, rencontres). Elle est hors de la
   grille des niveaux (`Meta.classContent` l'exclut) ; `Meta.zoneCards(classe, zone)`. **Données réelles
   vides aujourd'hui** (un autre lot les écrira) ; l'écran Progress montre déjà l'emplacement.
3. **Première victoire du compte dans une zone, toutes classes confondues** : le commun (cartes neutres,
   bibelots communs, potions, rencontres), par le champ `tier` (réutilisé) : `tier = N` = débloqué par la
   première victoire du compte dans la zone d'ordre N ; `tier = 0` (ou absent) = disponible d'emblée.
   Palier commun du compte : `Meta.commonTier(meta)` (ordre de la zone la plus avancée gagnée par le compte),
   figé au départ dans `exp.unlock.common`. `Meta.commonContent(N)` liste ce que donne la zone N.

### Table de répartition du commun (anciens paliers de la Ligue)

| Ancien palier de Ligue | Zone dont la 1re victoire du compte le débloque | Contenu aujourd'hui |
| --- | --- | --- |
| 0 Neutre | d'emblée | 4 neutres, 9 bibelots communs tirables, 3 potions, 9 rencontres |
| 1 Amical | 1 Westfall | 2 neutres (Iron Grenade, Runecloth Bag), 9 bibelots (Darkmoon Faire Prize Ticket, Head of Onyxia…), 3 rencontres |
| 2 Honoré | 2 Duskwood | 2 neutres (Arcane Bomb, Elixir of Superior Defense), 9 bibelots, 2 potions (Liquid Fire, Elixir of Wisdom), 2 rencontres |
| 3 Révéré | 3 Wetlands | 2 neutres (Black Lotus, Goblin Sapper Charge), 2 bibelots (Mana Ruby, Ironfoe), 1 rencontre ; bibelot au choix au départ |
| — | 4, 5, 7 | rien aujourd'hui |
| (Exalté) | 6 Burning Steppes | un bibelot de plus chez le marchand |

(Comptes au 13/11/2026, sans les bibelots `noPool` : `Meta.commonContent(N)`.)
Le palier N a été posé sur la zone N : c'est la répartition la plus simple « dans l'ordre », sans changer
une seule donnée (champ `tier` gardé tel quel). Les avantages de la Ligue suivent la même logique
(`Meta.PERKS`) :

| Avantage | Avant | Maintenant |
| --- | --- | --- |
| Un bibelot au choix parmi 3 au départ (phase `start`) | Révéré | 1re victoire du compte dans la zone 3 (Wetlands) |
| Un bibelot de plus chez le marchand | Exalté | 1re victoire du compte dans la zone 6 (Burning Steppes) |

**Conséquence assumée** : tant que seule Westfall existe, le commun des zones 2 et 3 et les deux avantages
sont inaccessibles en jeu. La simulation garde `zones=7` (ou `meta=exalted`) pour tout débloquer.

## Clés mythiques : une par zone et par classe

- `cs.zones[zone] = { won, keyMax, bestKey }` ; `Meta.keyMax(meta, classe, zone)`,
  `Meta.bestKey(meta, classe, zone)`. Gagner Westfall +2 avec le Mage ouvre Westfall +3 pour le Mage,
  rien d'autre. Niveaux +1 à +5, affixes inchangés (`docs/expedition.md`).
- **Expérience : +15 % par niveau de clé** (`Meta.XP.key = 0.15`).
- **Bibelots de clé** : la première victoire d'une classe à +1, +3 et +5 dans une zone débloque un bibelot
  plus fort que les communs (`Meta.KEY_RELIC_LEVELS`). Champ du bibelot : `key = { zone = "westfall",
  level = 3 }` (sans `tier` ; `class` facultatif pour le réserver à une classe). `Expedition.unlocked` le
  refuse tant que la classe n'a pas gagné la zone à cette clé ou plus (`exp.unlock.won[zone] >= level`) ;
  ensuite il entre dans le tirage de la classe (récompenses, coffres, marchand, choix de départ).
  `Meta.keyRelics(classe, zone)`. **Données réelles vides aujourd'hui.**
- Pas de cote ni de classement.

## Fin d'expédition (`Meta.record`, `Save.finish`)

Le résumé annonce, en plus de l'expérience et de la montée de niveau : `zoneWon` (première victoire de la
classe dans la zone), `zoneOpened` (zone suivante, ouverte pour la classe), `zoneCards`, `keyRelics`,
`keyUnlocked` (clé suivante de la zone), `accountZone` et `common` (commun débloqué pour toutes les
classes, avantages compris). Le bilan les écrit (« Westfall won with the Priest: Duskwood is open to the
Priest (coming later). », « New Priest card: … », « New relic: … », « Mythic Keystone +2 unlocked in
Westfall. », « First Westfall victory on this account: 2 neutral cards, 9 relics, 3 encounters unlocked
for every class. ») et révèle cartes de zone et bibelots de clé à côté de ceux du niveau.

## Écran Progress, onglet « Zones »

Une colonne par zone : nom, état (Won / Open / Locked / Coming later), clés ouvertes et meilleure clé,
emplacement de la carte de zone (dos de carte grisé tant qu'elle est verrouillée ou pas encore écrite ;
infobulle = « Win <Zone> to unlock » seule), trois cases de bibelots de clé +1 / +3 / +5 (point
d'interrogation grisé ; infobulle « Win <Zone> +3 to unlock »). Détails : `docs/interface.md`.

## Simulation

`runner=expedition zones=0..7 [zone=westfall]` : le compte et la classe ont gagné les N premières zones, à
toutes les clés (commun, cartes de zone, bibelots de clé) ; drapeaux d'histoire d'un vétéran dès N ≥ 1.
`meta=start` = `zones=0`, `meta=exalted` = `zones=7` (mesures « exalté » antérieures).

## Sauvegarde

`Save.VERSION` 5, `Expedition.VERSION` 5 : voir `docs/expedition.md`, « Sauvegarde ».
