# Expédition, méta-progression et sauvegarde

Couche « hors combat » de Slay the Dragon, en Lua 5.1 pur (aucune API WoW). L'interface (piste C)
et les bots de simulation passent par la même API.

| Fichier | Rôle |
| --- | --- |
| `Core/Map.lua` | Carte ramifiée d'un acte, générée par graine |
| `Core/Meta.lua` | Réputation de classe, Ligue des explorateurs, clés mythiques, affixes |
| `Core/Expedition.lua` | Machine à états d'une expédition |
| `Core/Save.lua` | Format de `SlayTheDragonDB`, migrations, validation, journal |
| `Data/Events.lua` | Rencontres (3 pour la Marche de l'Ouest) |
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
-- summary = { rep, classBefore, classAfter, leagueBefore, leagueAfter, keyUnlocked }
-- entry   = ligne ajoutée à db.journal

-- Abandon volontaire
ns.Save.abandon(db, date(...))
```

`seed` : la graine vient de l'interface (par exemple `time()`), le cœur n'appelle jamais
`math.random`. La même graine et les mêmes choix rejouent exactement la même expédition.

## API d'expédition

- `Expedition.choices(exp)` → liste des actions possibles maintenant (« abandon » toujours possible,
  non listé).
- `Expedition.act(exp, action)` → `true` ou `false, raison`. Une action refusée ne change rien.
- Une action est une liste `{ "verbe", arg1, arg2 }`.

| Phase (`exp.phase`) | Actions |
| --- | --- |
| `start` (Révéré : bibelot de classe) | `{"startRelic", i}` (i dans `exp.startRelics`), `{"skipStartRelic"}` |
| `map` | `{"path", idNoeud}` : un nœud de `Map.nextNodes(exp.map, exp.node)` |
| `combat` | `{"play", indexMain, indexEnnemi?}`, `{"endTurn"}`, `{"potion", emplacement, indexEnnemi?}` |
| `reward` | `{"pickCard", i}`, `{"skipCards"}`, `{"takePotion"}`, `{"leave"}` |
| `campfire` | `{"rest"}`, `{"upgrade", indexDeck}`, `{"leave"}` |
| `merchant` | `{"buyCard", i}`, `{"buyRelic", i}`, `{"buyPotion", i}`, `{"remove", indexDeck}`, `{"leave"}` |
| `event` | `{"choose", i}` puis `{"leave"}` (si le choix n'a pas de suite) |
| `select` (suite de rencontre) | `{"select", indexDeck}`, `{"skipSelect"}` |
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
| `class`, `seed`, `key`, `affixes` | classe, graine, niveau de clé, ids d'affixes actifs (`ns.Affixes[id].name/.text`) |
| `unlock` | `{ rep = palier de classe 0..4, league = palier de Ligue 0..4 }`, figé au départ |
| `act`, `acts` | acte courant, nombre d'actes de l'expédition |
| `map` | carte de l'acte (voir plus bas) |
| `node`, `floor` | nœud courant (nil avant le premier choix), étape 1..8 |
| `hp`, `maxHp`, `gold` | |
| `deck` | `{ {id, up}, ... }` (`ns.Card.defById(id, up)` pour l'affichage) |
| `relics` | ids de `ns.Relics` |
| `potions` | 3 emplacements : id ou `false` |
| `combat` | état du combat en cours (phase `combat`) |
| `fight` | `{ kind = combat/elite/boss, pool, encounter, seed, reward }` pendant le combat |
| `reward` | phase `reward` : `{ kind, gold, goldGained, cards = {ids}, cardsDone, picked, relic, relicTaken, potion, potionTaken }` |
| `shop` | phase `merchant` : `{ cards = { {id, price, sold} }, relics = {...}, potions = {...} }` ; retrait : `Expedition.removePrice(exp)` |
| `event` | phase `event` : `{ id (false = rien à signaler), chosen (false ou index), rolls }` ; texte dans `ns.Events[id]` |
| `select` | phase `select` : `{ kind = "upgrade" | "remove" }` |
| `startRelics` | phase `start` : ids proposés |
| `lastRest` | PV rendus par le dernier repos |
| `stats` | `{ cleared, elites, bosses, combats, goldEarned, goldSpent, cardsAdded, removed, upgraded, visits = {type = n} }` |
| `result` | `won`, `lost`, `abandoned` (phase `done`) ; `killedBy` en cas de défaite |

Aides de lecture : `Expedition.currentNode(exp)`, `Expedition.actName(exp)`,
`Expedition.canUpgrade(exp, i)`, `Expedition.freeSlot(exp)`, `Expedition.eventChoiceOk(exp, i)`
(griser un choix de rencontre), `Expedition.removePrice(exp)`.

### Carte

`exp.map = { act, floors = 8, start = {ids}, nodes = { [id] = { id, floor, x, kind, next = {ids} } } }`

- `floor` 1..7 puis 8 (boss) ; `x` dans ]0, 1[ = position horizontale (2 à 3 nœuds par étape).
- `kind` : `combat`, `elite`, `campfire`, `merchant`, `event`, `chest`, `boss` (noms affichés :
  `ns.Map.KINDS`).
- Les traits ne se croisent pas : relier chaque nœud à ses `next` suffit pour dessiner.
- `Map.nextNodes(map, exp.node)` = nœuds cliquables ; `Map.floorNodes(map, f)` = une étape.

### Rencontres (`Data/Events.lua`)

`ns.Events[id] = { name, act, tier, text, choices = { { label, text, after, effects } } }` :
`label` = bouton, `text` = conséquence affichée, `after` = texte après coup. Les effets sont des
données (`heal`, `loseHp`, `maxHp`, `gold`, `pay`, `card`, `cardChoice`, `relic`, `potion`,
`upgradeRandom`, `upgrade`, `remove`, `fight`), décrits en tête du fichier.

## Méta-progression (`Core/Meta.lua`)

`db.meta = { league, runs, classes = { priest = { rep, runs, wins, keyMax, bestKey } } }`

- `Meta.level(points)` → 0 Neutre, 1 Amical, 2 Honoré, 3 Révéré, 4 Exalté ; `Meta.levelName(lv)` ;
  `Meta.progress(points)` → palier, points dans le palier, taille du palier (barre de progression).
- Seuils (`Meta.LEVELS`, communs à la classe et à la Ligue) : 200 / 550 / 1 100 / 1 900.
- Gain en fin d'expédition, gagnée ou perdue (`Meta.REP`) : 10 par étape franchie, +12 par élite,
  +30 par boss, divisé par le nombre d'actes de l'expédition (la cadence ne dépend pas du
  nombre d'actes). Une expédition d'acte 1 complète rapporte ≈ 110 à 120 points.
- Déblocages (`Meta.unlocks(meta, classe)`), appliqués à tous les tirages (récompenses, marchand,
  rencontres, coffres) :
  - classe : cartes dont `rep` (0..2, absent = 0) ≤ palier ; Révéré : choix d'un bibelot de classe
    parmi 3 au départ (bibelots avec `class = "priest"`) ; Exalté : `Meta.title` = « Tueur de dragons »,
    `Meta.isExalted` pour le liseré doré ;
  - Ligue : bibelots, potions et rencontres dont `tier` (0..3) ≤ palier ; Exalté : un bibelot de
    plus chez le marchand.
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

`SlayTheDragonDB = { version = 1, meta, current = <expédition ou nil>, journal = {...}, quarantine = {...} }`

- `Save.new()`, `Save.migrate(db)` (une migration par version dans `Save.MIGRATIONS`, état
  d'expédition migré par `Save.EXP_MIGRATIONS`), `Save.validate(db)` → `ok, erreurs`.
- Jamais d'effacement : une expédition illisible part dans `db.quarantine` avec la raison ; une
  sauvegarde d'une version plus récente de l'addon n'est pas touchée.
- Journal : `{ result, class, key, seed, act, floor, cleared, elites, bosses, hp, maxHp, gold,
  goldEarned, deck, relics, killedBy, date, rep }`.

## Contrat avec les bibelots et potions (piste A)

- `ns.Relics[id].run` : crochets d'expédition appelés par `Expedition.modify / fire` :
  `gold(exp, v, source)`, `restFraction(exp, v)`, `restHeal(exp, v)`, `price(exp, v, genre)`
  (valeurs), `onPickup(exp)` (au ramassage), `onNodeEnter(exp, nœud)`, `onCombatWon(exp, genre)`,
  `onRest(exp)` (notifications). `exp.relicState` est libre pour un compteur d'expédition.
- `rarity` : `common`, `uncommon`, `rare` (récompenses, coffres, marchand), `boss` (boss
  uniquement) ; `tier` 0..3 ; `class = "priest"` = bibelot de classe (Révéré, hors pool normal) ;
  `noPool = true` = jamais tiré.
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
(±10 %) ; retrait 75 po puis +25 ; marchand 5 cartes, 3 bibelots, 3 potions ; repos 30 % ;
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
- **Rencontres** : les PV perdus ne tuent jamais (plancher à 1 PV) ; une rencontre déjà vue ne
  revient pas dans la même expédition ; si aucune n'est disponible, l'étape est « rien à signaler ».
- **Réputation** : cumulée par classe et pour la Ligue avec les mêmes points ; seuils calés pour
  Exalté vers la 16e–19e expédition (≈ 100–120 points par expédition d'un acte).
- **Clés** : `keyMax` par classe ; jouer une clé inférieure reste possible.
- **Affixes** : intensités ajustées (voir tableau) pour ≈ −5 points par niveau ; Galvanisant
  n'affecte pas les boss (sinon chaque sbire tué de VanCleef le rendait injouable), Nécrotique
  arrondit au plus proche (l'arrondi par défaut annulait les soins de 2 d'Expiation dès le 1er coup).
- **Révéré sans bibelot de classe** : si aucun `ns.Relics[...].class` n'existe, la phase `start` est
  sautée.

## Mesures (bot heuristique, acte 1, 3 000 expéditions, graine 1)

`luajit Sim/sim.lua runs=3000 jobs=16 runner=expedition key=N meta=start|exalted`

MESURES

Aujourd'hui, `meta=start` et `meta=exalted` donnent les mêmes chiffres : aucune carte n'a encore de
champ `rep` et aucun bibelot ou potion n'existe. À re-mesurer après la fusion de la piste A
(`bash build/sweep.sh` dans un worktree, ou les commandes ci-dessus), puis recaler `Meta.AFFIX`.
