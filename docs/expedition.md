# Expédition, méta-progression et sauvegarde

Couche « hors combat » de Slay the Dragon, en Lua 5.1 pur (aucune API WoW). L'interface (piste C)
et les bots de simulation passent par la même API.

| Fichier | Rôle |
| --- | --- |
| `Core/Map.lua` | Carte ramifiée d'un acte, générée par graine |
| `Core/Meta.lua` | Niveau de classe (expérience), Ligue des explorateurs (réputation), clés mythiques, affixes |
| `Core/Expedition.lua` | Machine à états d'une expédition |
| `Core/Save.lua` | Format de `SlayTheDragonDB`, migrations, validation, journal |
| `Data/Events.lua` | Rencontres de la Marche de l'Ouest (liste et intentions : `docs/rencontres.md`) |
| `Sim/expedition.lua` | Bot hors combat, `runner=expedition` dans `Sim/sim.lua` |
| `Sim/tests_expedition.lua` | Tests (`lua5.1` et `luajit`, `ALL PASS`) |

## Cycle de vie côté interface

```lua
-- ADDON_LOADED
SlayTheDragonDB = ns.Save.migrate(SlayTheDragonDB)   -- nil -> sauvegarde neuve ; jamais d'effacement
local db = SlayTheDragonDB

-- Nouvelle expédition (choix de classe et de clé : 0..ns.Meta.keyMax(db.meta, classe))
local exp, why = ns.Save.start(db, { seed = graine, class = "priest", key = 0 })

-- À chaque action du joueur
local ok, why = ns.Expedition.act(db.current, { "path", idNoeud })
-- rien d'autre à faire : l'état est modifié sur place dans db.current, donc déjà « sauvegardé »
-- (WoW écrit les SavedVariables au /reload, à la déconnexion et à la fermeture).

-- Quand db.current.phase == "done"
local summary, entry = ns.Save.finish(db, date("%Y-%m-%d %H:%M"))
-- summary = { rep, xp, levelBefore, levelAfter, unlocked = { cards, relics }, leagueBefore, leagueAfter,
--             keyUnlocked, flags }
--           xp = expérience de la classe jouée ; unlocked = ce que la montée de niveau vient de débloquer ;
--           flags = noms des drapeaux de compte nouvellement posés (histoires), triés
-- entry   = ligne ajoutée à db.journal

-- Abandon volontaire
ns.Save.abandon(db, date(...))
```

`seed` : la graine vient de l'interface (par exemple `time()`), le cœur n'appelle jamais
`math.random`. La même graine et les mêmes choix rejouent exactement la même expédition.

## Classes

L'expédition est celle d'une classe (`exp.class`, contrat complet : `docs/classes.md`) : PV et deck de
départ, bibelot de départ (`startRelic`, jamais tiré), combats (`c.class`, ressource `c.player.res`).
Récompenses, marchand et rencontres tirent dans le pool de la classe jouée : cartes de cette classe
(`Card.inClass`) et bibelots communs (sans champ `class`, utiles à la classe : champ `needs`) ou de cette
classe ; les cartes neutres (`Data/Neutral.lua`, palier de Ligue `tier`) seulement dans l'emplacement
« Neutral » du marchand (`X.neutralPool`) et dans les réponses de rencontres (`docs/cartes-neutres.md`) ; le choix de Révéré
propose les bibelots de la classe hors bibelot de départ. Les douze bibelots actuels sont communs
(rapport du socle multi-classes, docs/classes.md).
débloquées par son niveau (`Card.inClass`, `level` ≤ `exp.unlock.level` ; les cartes neutres prévues par le
GDD, `neutral = true`, seulement chez le marchand et dans les rencontres, suivent la Ligue par `tier`) et
bibelots communs (sans champ `class`, `tier` ≤ palier de Ligue) ou de cette classe (`level` ≤ niveau de
classe). `Expedition.unlocked(exp, def)` dit si une carte ou un bibelot est débloqué pour l'expédition.

## API d'expédition

- `Expedition.choices(exp)` → liste des actions possibles maintenant (« abandon » toujours possible,
  non listé).
- `Expedition.act(exp, action)` → `true` ou `false, raison`. Une action refusée ne change rien.
- Une action est une liste `{ "verbe", arg1, arg2 }`.

| Phase (`exp.phase`) | Actions |
| --- | --- |
| `start` (Révéré de la Ligue : bibelot au choix) | `{"startRelic", i}` (i dans `exp.startRelics`), `{"skipStartRelic"}` |
| `map` | `{"path", idNoeud}` : un nœud de `Map.nextNodes(exp.map, exp.node)` |
| `combat` | `{"play", indexMain, indexEnnemi?, "nospend"?}` (« nospend » : carte « Spend N » jouée sans dépenser), `{"endTurn"}`, `{"potion", emplacement, indexEnnemi?}` |
| `reward` | `{"pickCard", i}`, `{"skipCards"}`, `{"takePotion"}`, `{"leave"}` |
| `campfire` | `{"rest"}`, `{"upgrade", indexDeck}`, `{"leave"}` |
| `merchant` | `{"buyCard", i}`, `{"buyRelic", i}`, `{"buyPotion", i}`, `{"remove", indexDeck}`, `{"leave"}` |
| `event` | `{"choose", i}` puis `{"leave"}` (si le choix n'a pas de suite) ; une réponse indisponible n'est pas dans `choices` et `act` la refuse avec sa raison (texte) |
| `select` (suite de rencontre) | `{"select", indexDeck}`, `{"skipSelect"}` ; ensuite la récompense de la même réponse s'il y en a une, sinon la carte |
| `done` | aucune |
| toutes sauf `done` | `{"abandon"}` ; hors combat : `{"discardPotion", emplacement}` |

Raisons de refus courantes : `"action"` (verbe inconnu dans cette phase), `"or"`, `"emplacement"`
(pas de place pour une potion), `"carte"`, `"chemin"`, `"mana"`, `"target"`…

En combat, **passer par `Expedition.act`** (et non `Combat.play` directement) : c'est lui qui
détecte la fin du combat, rapatrie PV et potions, ouvre la récompense ou termine l'expédition.
Pour lire le combat : `exp.combat` (état de `Core/Combat.lua`), `Combat.intentInfo`, etc.
`exp.combat.events` est le journal d'animations : l'interface le vide après l'avoir joué
(`exp.combat.events = {}`), sinon il grossit la sauvegarde.

## État lisible (`db.current`)

Données simples uniquement (pas de fonction ni de métatable : `Save.isPlain`).

| Champ | Contenu |
| --- | --- |
| `phase` | voir ci-dessus |
| `class`, `seed`, `key`, `affixes` | classe (id de `ns.Classes`, choisie sur l'accueil), graine, niveau de clé, ids d'affixes actifs (`ns.Affixes[id].name/.text`) |
| `unlock` | `{ level = niveau de la classe 1..7, league = palier de Ligue 0..4 }`, figé au départ : une montée de niveau pendant l'expédition ne change rien avant la suivante |
| `act`, `acts` | acte courant, nombre d'actes de l'expédition |
| `map` | carte de l'acte (voir plus bas) |
| `node`, `floor` | nœud courant (nil avant le premier choix), étape 1..8 |
| `hp`, `maxHp`, `gold` | |
| `deck` | `{ {id, up}, ... }` (`ns.Card.defById(id, up)` pour l'affichage) |
| `relics` | ids de `ns.Relics` (le bibelot de départ de la classe, `startRelic`, en tête) |
| `potions` | 3 emplacements (4 avec Herb Pouch : `X.addPotionSlot`) : id ou `false` |
| `combat` | état du combat en cours (phase `combat`) |
| `fight` | `{ kind = combat/elite/boss, pool, encounter, seed, reward }` pendant le combat |
| `reward` | phase `reward` : `{ kind, gold, goldGained, cards = {ids}, cardsDone, picked, relic, relicTaken, potion, potionTaken }` |
| `shop` | phase `merchant` : `{ cards = { {id, price, sold, neutral?} }, relics = {...}, potions = {...}, removed }` (6e carte `neutral = true` : emplacement « Neutral » ; `removed` = retraits de la visite) ; retrait : `Expedition.removePrice(exp)` (crochet `removePrice`) |
| `event` | phase `event` : `{ id (false = rien à signaler), chosen (false ou index), rolls, result, lucky }` ; texte dans `ns.Events[id]` ; `result` = texte après le choix (réponse + issue du pari) ; `lucky` = issue d'un pari (true/false, nil sans pari) |
| `select` | phase `select` : `{ kind = "upgrade" | "remove" | "dupe", reward? }` |
| `flags` | drapeaux de compte connus au départ (copie de `meta.flags`, sert aux conditions) |
| `newFlags` | drapeaux posés pendant l'expédition, reportés dans `meta.flags` par `Save.finish` |
| `startRelics` | phase `start` : ids proposés |
| `lastRest` | PV rendus par le dernier repos |
| `stats` | `{ cleared, elites, bosses, combats, goldEarned, goldSpent, cardsAdded, removed, upgraded, visits = {type = n}, events = {id = réponse (0 = pas encore choisi)} }` |
| `result` | `won`, `lost`, `abandoned` (phase `done`) ; `killedBy` en cas de défaite |

Aides de lecture : `Expedition.currentNode(exp)`, `Expedition.actName(exp)`,
`Expedition.canUpgrade(exp, i)`, `Expedition.freeSlot(exp)`, `Expedition.eventChoiceOk(exp, i)`
(griser un choix de rencontre), `Expedition.eventOptions(exp)` (réponses prêtes à afficher, voir
plus bas), `Expedition.removePrice(exp)`.

### Carte

`exp.map = { act, floors = 8, start = {ids}, nodes = { [id] = { id, floor, x, kind, next = {ids} } } }`

- `floor` 1..7 puis 8 (boss) ; `x` dans ]0, 1[ = position horizontale (2 à 3 nœuds par étape).
- `kind` : `combat`, `elite`, `campfire`, `merchant`, `event`, `chest`, `boss` (noms affichés :
  `ns.Map.KINDS`).
- Les traits ne se croisent pas : relier chaque nœud à ses `next` suffit pour dessiner.
- `Map.nextNodes(map, exp.node)` = nœuds cliquables ; `Map.floorNodes(map, f)` = une étape.

### Rencontres (`Data/Events.lua`)

Liste complète, familles et intentions de design : `docs/rencontres.md`. Format (détaillé en tête
de `Data/Events.lua`) :

```lua
ns.Events[id] = {
  name, act, tier,                 -- tier = palier de Ligue qui la débloque (0..3)
  rarity = "common" | "rare" | "story", weight, once, when,
  speaker, npc, scene,             -- personnage affiché, identifiant de modèle, décor
  text,
  choices = { { label, outcome, hidden, when, effects, result } },
}
```

- `outcome` : ce que la réponse donne ou coûte, toujours écrit (« -6 PV, améliore 2 cartes au
  hasard », « 50 % : une potion et 20 po, sinon -7 PV ») ; `hidden = true` → afficher « ? ».
  `result` : texte après le choix. Pour l'interface d'origine, `text` et `after` sont recopiés de
  `outcome` (« ? » si cachée) et `result`.
- `scene` ∈ `farm`, `road`, `coast`, `mine`, `hill`, `camp`, `ruins`.
- Familles : `common` (poids 10), `rare` (poids 3), `story` (poids 8, unique par compte) ;
  `Expedition.EVENT_WEIGHT`, `ev.weight` le remplace. Tirage pondéré parmi les rencontres possibles.
- `once` : une fois par compte. Drapeau `event:<id>` (ou le nom donné) posé **dès l'entrée** dans la
  rencontre, même si l'on abandonne ensuite.
- `when` : conditions, toutes requises, évaluées à l'entrée du nœud (rencontre) ou à l'affichage
  (réponse) : `hpBelow`, `hpAbove`, `gold`, `relic`, `noRelic`, `potion`, `card`, `key`, `flag`,
  `noFlag`, `floor`, `unlocked` (carte débloquée) (`Expedition.CONDITIONS`, `Expedition.check(exp, when)`
  → `ok, raison`) ; une condition `hide = true` rend la réponse absente (`X.choiceHidden`) au lieu de grisée.
- Effets (données) : `heal`, `healPct`, `loseHp`, `maxHp`, `loseMaxHp`, `gold`, `pay`, `loseGold`,
  `card`, `cardChoice` (`neutral = true` : parmi les cartes neutres), `relic` (tiré ou précis), `potion` (tirée ou précise), `losePotion`,
  `upgradeRandom`, `upgrade`, `remove`, `dupe`, `fight` (`kind = "elite"` possible, groupe
  `ns.Encounters.act1.event_*`), `gamble` (pari), `flag` (drapeau de compte).
- Tout le hasard est tiré à l'entrée (`exp.event.rolls`, une liste par réponse ; un pari y stocke
  `{ won, win = tirages, lose = tirages }`) : recharger ou choisir une autre réponse ne change rien.

Pour l'interface, `Expedition.eventOptions(exp)` renvoie une ligne par réponse :
`{ index, label, outcome (« ? » si cachée), hidden, disabled, reason (texte prêt à afficher), chosen }`.
`Expedition.eventChoiceOk(exp, i)` renvoie `false, raison` : texte de la condition (« Il te faut :
Tabard de Hurlevent. ») ou code d'effet (`"or"`, `"deck"`, `"amélioration"`, `"potion"`,
`"bibelot"`, traduits par `Expedition.EVENT_REASONS`).

### Drapeaux de compte

`db.meta.flags = { [nom] = true }`. Une expédition reçoit une copie figée au départ
(`exp.flags`, lue par les conditions `flag` / `noFlag`) ; les drapeaux posés pendant l'expédition
vont dans `exp.newFlags` et ne sont reportés dans la méta qu'**à la fin de l'expédition**
(`Meta.record`, appelé par `Save.finish` et `Save.abandon`), quel que soit le résultat. Une suite ne
peut donc jamais apparaître dans l'expédition qui l'a débloquée. Un drapeau n'est jamais retiré.
`Meta.hasFlag(meta, nom)`.

## Méta-progression (`Core/Meta.lua`)

`db.meta = { league, runs, classes = { priest = { xp, runs, wins, keyMax, bestKey } }, flags = { [nom] = true } }`

### Niveau de classe (progression par classe, 12/11/2026)

Toutes les classes sont jouables dès le départ ; chacune a son niveau, de 1 à 7, tiré de son expérience
(`cs.xp`). Il débloque ses cartes et ses bibelots (table du GDD, `docs/gdd-classes.md`) :

| Niveau | Expérience cumulée | Déblocage |
| --- | --- | --- |
| 1 | 0 | 4 cartes de départ + 6 par voie (22), 2 bibelots de classe dont celui de départ |
| 2 | 100 | une carte par voie |
| 3 | 250 | un bibelot de classe |
| 4 | 450 | une carte par voie |
| 5 | 700 | un bibelot de classe |
| 6 | 1 000 | une carte par voie |
| 7 | 1 400 | une rare par voie et 2 bibelots (34 cartes, 6 bibelots) ; titre « Dragonslayer » (`Meta.title`) |

- `Meta.XP_LEVELS`, `Meta.classLevel(xp)`, `Meta.xpProgress(xp)` → niveau, expérience dans le niveau,
  taille du niveau (nil au 7) ; `Meta.levelOf(meta, classe)` ; `Meta.isMaxLevel` ;
  `Meta.classContent(classe[, niveau])` → `{ cards, relics }` (tout, ou ce qui se débloque à ce niveau),
  triés par niveau, rareté, coût, nom ; `Meta.unlockLevel(def)` (champ `level`, absent = 1).
- **Expérience gagnée** en fin d'expédition, gagnée, perdue ou abandonnée (`Meta.xpFor`, `Meta.XP`) :
  `(réputation × 0,5 + 15 si gagnée) × (1 + 0,1 × clé)`, arrondi ; la réputation est celle de
  `Meta.repFor` ci-dessous. Clé 0 : ≈ 76 pour une victoire, ≈ 40 pour une défaite au boss, moins pour une
  défaite plus tôt (mesures plus bas). Avec ≈ 4 victoires pour 1 défaite (≈ 70 en moyenne) : niveau 2 à la
  2e expédition, puis 2, 3, 3, 4 et 6 expéditions par niveau (niveaux 3 à 7 aux 4e, 7e, 10e, 14e et
  20e ; mesuré : 72 à 75 par expédition au bot heuristique).
- Ce que débloque le niveau entre dans la réserve de la classe : récompenses, marchand, rencontres
  (cartes) et bibelots de récompense, de coffre et du marchand. Le bibelot de départ (`startRelic`,
  `noPool`) est porté à chaque expédition.
- Une expédition garde les déblocages de son départ (`exp.unlock.level`) ; `Meta.record` rend ce que la
  montée vient de débloquer (`summary.unlocked`), montré par le bilan.

### Ligue des explorateurs (réputation commune au compte)

- `Meta.level(points)` → 0 Neutre, 1 Amical, 2 Honoré, 3 Révéré, 4 Exalté ; `Meta.levelName(lv)` ;
  `Meta.progress(points)` → palier, points dans le palier, taille du palier (barre de progression).
- Seuils (`Meta.LEVELS`) : 200 / 550 / 1 100 / 1 900.
- Gain en fin d'expédition, gagnée ou perdue (`Meta.REP`) : 10 par étape franchie, +12 par élite,
  +30 par boss, divisé par le nombre d'actes de l'expédition (la cadence ne dépend pas du
  nombre d'actes). Une expédition d'acte 1 complète rapporte ≈ 110 à 120 points.
- Déblocages (`Meta.unlocks(meta, classe)` → `{ level, league }`), appliqués à tous les tirages
  (récompenses, marchand, rencontres, coffres). La Ligue ne débloque que ce qui est commun :
  bibelots communs, potions, rencontres (et les cartes neutres à venir) dont `tier` (0..3) ≤ palier ;
  Révéré : un bibelot au choix parmi 3 au départ, tirés dans la réserve de l'expédition (communs et de
  classe débloqués, hors boss) ; Exalté : un bibelot de plus chez le marchand.
- Ce que donnait l'ancienne réputation **de classe** (supprimée) : cartes par `rep` 0..2 → niveau de
  classe ; « un bibelot de classe parmi 3 au départ » (Révéré de classe), devenu sans objet puisque les
  bibelots de classe sont dans la réserve dès leur niveau → remplacé par l'équivalent commun le plus
  simple, « un bibelot au choix parmi 3 de la réserve » au Révéré de la Ligue ; le titre d'Exalté de
  classe → niveau 7.
- Clés mythiques : `Meta.keyMax(meta, classe)` ; une victoire à +N ouvre +N+1 (plafond
  `Meta.MAX_KEY` = 5). `Meta.affixesFor(key)` ; `ns.Affixes[id] = { name, level, text }`.

| Clé | Affixe | Effet (réglé par simulation, `Meta.AFFIX`) |
| --- | --- | --- |
| +1 | Fortifié | Ennemis normaux : +20 % de PV |
| +2 | Tyrannique | Élites : +20 % de PV et de dégâts ; boss : +7 % de PV |
| +3 | Galvanisant | Quand un ennemi meurt, les autres (sauf boss) gagnent 1 Force |
| +4 | Nécrotique | Chaque coup qui fait perdre des PV réduit tes soins de 10 % (état `necrotic` affiché sur le héros) |
| +5 | Disette | Le feu de camp ne soigne plus que 20 % des PV |

## Sauvegarde (`Core/Save.lua`)

`SlayTheDragonDB = { version = 4, meta, current = <expédition ou nil>, journal = {...}, quarantine = {...} }`

- `Save.new()`, `Save.migrate(db)` (une migration par version dans `Save.MIGRATIONS`, état
  d'expédition migré par `Save.EXP_MIGRATIONS`), `Save.validate(db)` → `ok, erreurs`.
- Versions : 1 = format initial ; 2 = `meta.flags` (drapeaux de compte). La migration 1 → 2 et
  `Save.normalize` créent `meta.flags` s'il manque et gardent tous les drapeaux existants (une
  valeur vraie non booléenne devient `true`, une valeur fausse est retirée). L'expédition en cours
  passe de la version 1 à 2 (`exp.flags = {}`, `exp.newFlags = {}`, `stats.events = {}`).
- Version 3 (12/11/2026, classes) : rien à changer dans la méta (déjà par classe) ; l'expédition passe
  de 2 à 3 : classe par défaut `priest`, et dans le combat en cours la Démence devient la ressource de
  classe (`player.demence` → `player.res`), le combat reçoit `class`, son état de classe `cls = {}`, ses
  compteurs du tour `turn`, sa zone de Traps `traps = {}` et le flux de hasard des cartes `rng.cards`
  (test « sauvegarde v2 -> v3 »).
- Version 4 (12/11/2026, progression par classe) : chaque classe reçoit son expérience, convertie de son
  ancienne réputation (gardée telle quelle dans `cs.rep`, plus lue) au barème de `Meta.XP` sans bonus de
  clé : `xp = rep × 0,5 + victoires × 15` ; l'expédition en cours passe de 3 à 4 (`unlock.rep` retiré,
  `unlock.level` = niveau de sa classe après la migration) (test « sauvegarde v3 -> v4 »).
- Jamais d'effacement : une expédition illisible part dans `db.quarantine` avec la raison ; une
  sauvegarde d'une version plus récente de l'addon n'est pas touchée.
- Journal : `{ result, class, key, seed, act, floor, cleared, elites, bosses, hp, maxHp, gold,
  goldEarned, deck, relics, killedBy, date, rep, xp }`.

## Contrat avec les bibelots et potions (piste A)

- `ns.Relics[id].run` : crochets d'expédition appelés par `Expedition.modify / fire` :
  `gold(exp, v, source)`, `goldBonus(exp, v, source)` (fixe, après `gold`), `restFraction(exp, v)`,
  `restHeal(exp, v)`, `price(exp, v, genre)`, `removePrice(exp, v)`
  (valeurs), `onPickup(exp)` (au ramassage), `onNodeEnter(exp, nœud)`, `onCombatWon(exp, genre)`,
  `onRest(exp)` (notifications). `exp.relicState` est libre pour un compteur d'expédition.
- `rarity` : `common`, `uncommon`, `rare` (récompenses, coffres, marchand), `boss` (boss
  uniquement) ; `tier` 0..3 (communs : palier de Ligue) ; `class = "priest"` + `level` 1..7 = bibelot de
  classe (dans la réserve de cette classe seulement, dès ce niveau ; pas de `tier`) ;
  `noPool = true` = jamais tiré (bibelot de départ, bibelots de rencontre).
- Potions : `Combat.new` reçoit `opts.potions` (3 emplacements, `false` = vide) ; l'état final est lu
  dans `c.player.potions` ; l'action `{"potion", emplacement, cible}` appelle
  `Combat.usePotion(c, emplacement, indexEnnemi)` s'il existe.

## Points d'accroche ajoutés dans `Core/Combat.lua`

Petits ajouts, sans rien renommer :

- `Combat.new` : `opts.affixes` → `c.affixes` (copié) ; `Combat.modify` et `Combat.fire` parcourent
  aussi `ns.Affixes[id].hooks` après les bibelots.
- `Combat.spawn` : `hp = Combat.modify(c, "enemyHp", hp, def)`.
- `Combat.calcDamage` : coups ennemis → `Combat.modify(c, "enemyDamage", dmg, src, dst)`.
- `Combat.dealDamage` : coup qui fait perdre des PV au joueur → `Combat.fire(c, "onPlayerHit", src, perte)`.
- `Combat.kill` : mort d'un ennemi → `Combat.fire(c, "onEnemyDeath", unité)`.

Ces crochets sont aussi disponibles pour les bibelots et pouvoirs.

## Paramètres de la couche expédition

`Core/Expedition.lua` : or de départ 50 ; or par combat 12–18, élite 25–35, boss 75–85 ;
potion après combat 35 % ; cartes 35/55/90 po, bibelots 90/120/160 (boss 220), potions 30/45/60
(±10 %), cartes neutres 45/65/100 ; retrait 75 po puis +25 ; marchand 5 cartes + 1 neutre, 3 bibelots, 3 potions ; repos 30 % ;
2 premiers combats de l'acte dans le groupe `easy`.

`Core/Map.lua` : étape 1 = combat, étape 7 = feu de camp, 8 = boss ; chaque chemin compte
3–4 combats, 1–2 élites, 1–2 feux de camp, 0–1 marchand, 1–2 rencontres, 0–1 coffre ; pas d'élite
avant l'étape 3 ni deux de suite, pas de feu de camp avant l'étape 4 ni à l'étape 6 ; au moins un
marchand par carte ; deux successeurs d'un même nœud évitent autant que possible le même type.

## Décisions prises

- **Fréquences par chemin.** Avec 7 étapes, les minimums demandés (3 combats, 1 élite, 1 feu,
  1 marchand, 1 rencontre) remplissent déjà tout : impossible d'avoir à la fois un marchand sur
  chaque chemin, des coffres et des variantes. Le marchand est donc 0–1 par chemin (au moins un par
  carte, ≈ 40 % des chemins) ; les autres bornes sont respectées sur chaque chemin.
- **Feu de camp avant le boss** sur toute l'étape 7 (comme le genre le veut) ; l'étape 1 est
  toujours un combat facile.
- **Tirages figés.** La récompense d'un combat (or, 3 cartes, bibelot, potion) est tirée en
  entrant dans le nœud, avant le combat ; celles d'une rencontre en entrant dans la rencontre ;
  le marchand en entrant chez lui. Les flux `map`, `loot`, `merchant`, `events`, `combat` sont dans
  l'état ; la graine de chaque combat est tirée du flux `combat`.
- **Or et bibelot pris automatiquement**, potion aussi s'il reste un emplacement (sinon
  `takePotion` après `discardPotion`) ; la carte reste un choix (ou passer).
- **Potions** : 3 emplacements ; 35 % de chance d'une potion après un combat normal ou d'élite (non
  précisé par le GDD).
- **Retrait de carte** : plusieurs retraits par visite autorisés, prix croissant sur toute
  l'expédition (75, 100, 125…).
- **Rencontres** : les PV perdus ne tuent jamais (plancher à 1 PV, PV max au moins 1) ; une
  rencontre déjà vue ne revient pas dans la même expédition ; si aucune n'est disponible, l'étape
  est « rien à signaler ». Familles, conditions, paris et histoires : `docs/rencontres.md`.
- **Réputation** : celle de la Ligue seulement, commune au compte ; seuils calés pour Exalté vers la
  16e–19e expédition (≈ 100–120 points par expédition d'un acte).
- **Niveau de classe** (12/11/2026) : seuils 100 / 250 / 450 / 700 / 1 000 / 1 400 ; expérience =
  la moitié de la réputation, +15 pour une victoire, ×(1 + 0,1 × clé) : 2 expéditions pour le niveau 2,
  ≈ 20 pour le 7 (voir « Niveau de classe »).
- **Clés** : `keyMax` par classe ; jouer une clé inférieure reste possible.
- **Affixes** : intensités ajustées (voir tableau) pour ≈ −5 points par niveau ; Galvanisant
  n'affecte pas les boss (sinon chaque sbire tué de VanCleef le rendait injouable), Nécrotique
  arrondit au plus proche (l'arrondi par défaut annulait les soins de 2 d'Expiation dès le 1er coup).
- **Révéré sans bibelot à proposer** : si la réserve est vide, la phase `start` est sautée.

## Mesures de la progression par classe (12/11/2026, bot heuristique, clé 0, 1 000 expéditions, graine 1)

`luajit Sim/sim.lua runs=1000 bot=heuristic jobs=8 runner=expedition key=0 class=<c> meta=<m> level=<n>`
(intervalle ≈ ±2 points). « Avant » : code d'avant la progression (aae54aa), `meta=exalted`.

| Classe | Avant (exalted) | Niveau 7, Ligue exaltée | Niveau 1, Ligue exaltée | Niveau 1, compte neuf (`meta=start`) |
| --- | --- | --- | --- | --- |
| Priest | 77,5 % | 90,0 % | 91,4 % | 87,8 % |
| Warrior | 88,6 % | 85,7 % | 82,7 % | 68,3 % |
| Mage | 93,4 % | 91,4 % | 91,9 % | 85,2 % |
| Rogue | 93,0 % | 93,4 % | 92,4 % | 89,7 % |
| Hunter | 89,6 % | 87,1 % | 91,1 % | 86,2 % |

- **Expérience** : 72 à 75 par expédition à la clé 0 (victoire ≈ 77, défaite ≈ 41 ; compte neuf du
  Warrior : 66), soit le niveau 2 à la 2e expédition et le niveau 7 vers la 19e–20e.
- **Non-régression** : avec l'ancien choix de Révéré (bibelots de la classe seulement), le nouveau code
  redonne exactement les chiffres d'avant : Warrior 88,6, Mage 93,4, Rogue 93,0, Hunter 89,6, et Priest sans
  ses nouveaux bibelots 77,5. Les écarts du tableau viennent donc seulement du contenu : (1) le choix de
  Révéré tire maintenant dans toute la réserve (communs compris) au lieu des seuls bibelots de classe :
  −3 à +0,5 point (le bot prend le premier proposé) ; (2) le Priest a ses six bibelots : Sacred Candle seule
  (portée à chaque expédition) +8,7 (86,2 %), les cinq autres dans la réserve +3,3 (89,5 %), le nouveau choix
  de Révéré +0,5 (90,0 %).
- **Niveau 1** : aucune classe sous 45 %, aucun échange de cartes entre niveaux. Le niveau 1 est parfois au
  niveau du 7 ou au-dessus (Priest, Mage, Hunter) : moins de cartes, donc des récompenses plus souvent
  parmi les meilleures communes ; à reprendre par le lot d'équilibrage (le Warrior perd 17 points du
  niveau 7 en Ligue exaltée au compte neuf, dont 14 dus à la Ligue ; les autres 1 à 6).

## Mesures (bot heuristique, acte 1, 3 000 expéditions, graine 1)

`luajit Sim/sim.lua runs=3000 jobs=16 runner=expedition key=N meta=start|exalted` (mesures d'avant la progression
par classe ; `level=` vaut 7 par défaut, ce qui les garde comparables)

Le rapport liste aussi chaque rencontre vue (fréquence, victoires avec / sans, réponses choisies) ;
mesures des rencontres : `docs/rencontres.md`. `meta=exalted` simule un compte vétéran (drapeaux
d'histoire posés), `meta=start` un compte neuf.

| Clé | Victoires | Écart | PV perdus contre le boss | Réputation moyenne |
| --- | --- | --- | --- | --- |
| +0 | 82,1 % | | 46,3 | 117,9 |
| +1 | 77,9 % | −4,2 | 49,0 | 116,2 |
| +2 | 73,0 % | −4,9 | 51,3 | 114,2 |
| +3 | 70,0 % | −3,0 | 51,7 | 112,8 |
| +4 | 65,7 % | −4,3 | 50,6 | 111,1 |
| +5 | 60,3 % | −5,4 | 49,4 | 108,9 |

Intervalle de confiance ≈ ±1,5 point. Avec les +20 % du GDD appliqués aussi au boss et
Galvanisant +2 sur tout le monde, la clé +2 tombait à 22 % et la +3 à 9 % : un palier infranchissable.

Clé +0 : or gagné 167 par expédition (départ 50 compris), dépensé 32, restant 185 ; 0,38 carte
retirée, 1,6 améliorée. Visites par expédition : combat 3,03, élite 1,26, feu de camp 1,00,
marchand 0,41, rencontre 1,08, coffre 0,22, boss 1. L'or dort faute de bibelots et de potions à
acheter (registres encore vides) et parce que le marchand n'est que sur ≈ 40 % des chemins.

Aujourd'hui, `meta=start` et `meta=exalted` donnent les mêmes chiffres : aucune carte n'a encore de
champ `rep` et aucun bibelot ou potion n'existe. Le combat reste l'affaire du boss (normaux et
élites ≈ 100 %) : le taux global (82 %) dépasse la cible de 40 à 60 %, c'est l'équilibrage des
combats (piste A). À re-mesurer après la fusion de la piste A avec les commandes ci-dessus, puis
recaler `Meta.AFFIX` (et `Meta.LEVELS` si la réputation moyenne change beaucoup).
