# Expédition, méta-progression et sauvegarde

Couche « hors combat » de Slay the Dragon, en Lua 5.1 pur (aucune API WoW). L'interface (piste C)
et les bots de simulation passent par la même API.

| Fichier | Rôle |
| --- | --- |
| `Core/Map.lua` | Carte ramifiée d'une zone, générée par graine |
| `Core/Zones.lua` | Registre des sept zones de la campagne (`ns.Zones`, `ns.Zone`) : `docs/zones.md` |
| `Core/Meta.lua` | Niveau de classe (expérience), zones gagnées (par classe et par le compte), clés par zone et par classe, affixes |
| `Core/Expedition.lua` | Machine à états d'une expédition |
| `Core/Save.lua` | Format de `SlayTheDragonDB`, migrations, validation, journal |
| `Data/Zones/Westfall.lua` | Zone 1 : ennemis et groupes de combats de la Marche de l'Ouest (ex-`Data/Act1.lua`) |
| `Data/Events.lua` | Rencontres de la Marche de l'Ouest (`zone = "westfall"` ; liste et intentions : `docs/rencontres.md`) |
| `Sim/expedition.lua` | Bot hors combat, `runner=expedition` dans `Sim/sim.lua` |
| `Sim/tests_expedition.lua` | Tests (`lua5.1` et `luajit`, `ALL PASS`) |

## Cycle de vie côté interface

```lua
-- ADDON_LOADED
SlayTheDragonDB = ns.Save.migrate(SlayTheDragonDB)   -- nil -> sauvegarde neuve ; jamais d'effacement
local db = SlayTheDragonDB

-- Nouvelle expédition (classe, zone ouverte et jouable pour elle, clé 0..ns.Meta.keyMax(db.meta, classe, zone))
local exp, why = ns.Save.start(db, { seed = graine, class = "priest", zone = "westfall", key = 0 })
-- why : "zone locked", "zone coming later", "key locked", "running"

-- À chaque action du joueur
local ok, why = ns.Expedition.act(db.current, { "path", idNoeud })
-- rien d'autre à faire : l'état est modifié sur place dans db.current, donc déjà « sauvegardé »
-- (WoW écrit les SavedVariables au /reload, à la déconnexion et à la fermeture).

-- Quand db.current.phase == "done"
local summary, entry = ns.Save.finish(db, date("%Y-%m-%d %H:%M"))
-- summary = { xp, levelBefore, levelAfter, unlocked = { cards, relics }, zone, zoneWon, zoneOpened,
--             zoneCards, keyRelics, keyUnlocked, accountZone, common, flags }
--           xp = expérience de la classe jouée ; unlocked = ce que la montée de niveau vient de débloquer ;
--           zone… = déblocages de la campagne (docs/zones.md) ; flags = noms des drapeaux de compte
--           nouvellement posés (histoires), triés
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
classe ; les cartes neutres (`Data/Neutral.lua`, palier commun `tier`) seulement dans l'emplacement
« Neutral » du marchand (`X.neutralPool`) et dans les réponses de rencontres (`docs/cartes-neutres.md`) ; le
bibelot au choix du départ (zone 3 gagnée par le compte) tire dans la réserve hors bibelot de départ.
Déblocages (`Expedition.unlocked(exp, def)`, figés au départ dans `exp.unlock`) : cartes et bibelots de
classe par niveau (`level` ≤ `exp.unlock.level`) ; cartes de zone (`zone`) et bibelots de clé (`key`) par
les zones gagnées par la classe (`exp.unlock.won`) ; commun (cartes neutres, bibelots communs, potions,
rencontres) par le palier commun du compte (`tier` ≤ `exp.unlock.common`). Détails : `docs/zones.md`.

## API d'expédition

- `Expedition.choices(exp)` → liste des actions possibles maintenant (« abandon » toujours possible,
  non listé).
- `Expedition.act(exp, action)` → `true` ou `false, raison`. Une action refusée ne change rien.
- Une action est une liste `{ "verbe", arg1, arg2 }`.

| Phase (`exp.phase`) | Actions |
| --- | --- |
| `start` (bibelot au choix : zone 3 gagnée par le compte) | `{"startRelic", i}` (i dans `exp.startRelics`), `{"skipStartRelic"}` |
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
| `class`, `zone`, `seed`, `key`, `affixes` | classe (id de `ns.Classes`, choisie sur l'accueil), zone (id de `ns.Zones`), graine, niveau de clé, ids d'affixes actifs (`ns.Affixes[id].name/.text`) |
| `unlock` | `{ level = niveau de la classe 1..7, common = palier commun du compte 0..7, won = { [zone] = meilleure clé gagnée par la classe } }`, figé au départ : un déblocage pendant l'expédition ne change rien avant la suivante |
| `act`, `acts` | 1 et 1 (une zone = un acte ; gardés pour la carte et l'affichage) |
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
  name, zone, tier,                -- zone (nil = toutes) ; tier = palier commun qui la débloque (docs/zones.md)
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
  `event_*` des combats de la zone, `ns.Encounters.westfall.event_*`), `gamble` (pari), `flag` (drapeau de compte).
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

`db.meta = { runs, zones = { westfall = true }, classes = { priest = { xp, runs, wins,
zones = { westfall = { won, keyMax, bestKey } } } }, flags = { [nom] = true } }`

Campagne par zones (13/11/2026, remplace la Ligue des explorateurs) : contrat et règles dans
`docs/zones.md`. Trois sources de déblocage : niveau de classe (ci-dessous), première victoire d'une classe
dans une zone (carte de zone, zone suivante pour cette classe), première victoire du compte dans une zone
(commun, avantages) ; plus les bibelots de clé (première victoire d'une classe à +1, +3, +5 dans une zone).

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
- **Expérience gagnée** en fin d'expédition, gagnée, perdue ou abandonnée (`Meta.xpFor`, `Meta.XP`),
  tirée de l'avancée de l'expédition (13/11/2026, plus de réputation) :
  `(5 × étapes franchies + 6 × élites + 15 × boss + 15 si gagnée) × (1 + 0,15 × clé)`, arrondi
  (`Meta.XP = { step = 5, elite = 6, boss = 15, win = 15, key = 0.15 }`). Mêmes gains qu'avant à la clé 0
  (c'était la moitié de la réputation 10 / 12 / 30, + 15) : victoire avec une élite 8 × 5 + 6 + 15 + 15 =
  **76** (deux élites : 82), défaite au boss avec une élite 7 × 5 + 6 = **41**, défaite à l'étape 4 sans élite
  **15–20**. Clé : +1 → 87, +3 → 110, +5 → 133 pour la victoire type. Avec ≈ 4 victoires pour 1 défaite
  (≈ 70 en moyenne) : niveau 2 à la 2e expédition, puis 2, 3, 3, 4 et 6 expéditions par niveau (niveaux 3 à
  7 aux 4e, 7e, 10e, 14e et 20e ; mesuré avant le changement : 72 à 75 par expédition au bot heuristique).
- Ce que débloque le niveau entre dans la réserve de la classe : récompenses, marchand, rencontres
  (cartes) et bibelots de récompense, de coffre et du marchand. Le bibelot de départ (`startRelic`,
  `noPool`) est porté à chaque expédition.
- Une expédition garde les déblocages de son départ (`exp.unlock.level`) ; `Meta.record` rend ce que la
  montée vient de débloquer (`summary.unlocked`), montré par le bilan.

### Zones, commun du compte et clés (13/11/2026 ; la Ligue des explorateurs est supprimée)

- `Meta.unlocks(meta, classe)` → `{ level, common = Meta.commonTier(meta), won = { [zone] = meilleure clé } }`,
  appliqués à tous les tirages (récompenses, marchand, rencontres, coffres) ; `Meta.allUnlocked(niveau,
  zones)` pour la simulation.
- Commun (cartes neutres, bibelots communs, potions, rencontres) : `tier = N` = débloqué par la première
  victoire du compte dans la zone d'ordre N (0 = d'emblée). Les anciens paliers de Ligue 1, 2, 3 tombent sur
  les zones 1, 2, 3 ; « un bibelot au choix parmi 3 au départ » (ex-Révéré, tiré dans la réserve de
  l'expédition, hors boss) = zone 3 ; « un bibelot de plus chez le marchand » (ex-Exalté) = zone 6
  (`Meta.PERKS`). Table complète : `docs/zones.md`.
- Ouverture des zones par classe (`Meta.zoneOpen`), cartes de zone (`zone`), bibelots de clé (`key`) :
  `docs/zones.md`.
- Ce que donnait l'ancienne réputation **de classe** (supprimée le 12/11/2026) : cartes par `rep` 0..2 →
  niveau de classe ; « un bibelot de classe parmi 3 au départ » → le bibelot au choix commun ; le titre
  d'Exalté de classe → niveau 7. La réputation de Ligue (`meta.league`) est abandonnée par la migration v5.
- Clés mythiques **par zone et par classe** : `Meta.keyMax(meta, classe, zone)`, `Meta.bestKey(…)` ; une
  victoire à +N dans une zone ouvre +N+1 dans cette zone pour cette classe (plafond `Meta.MAX_KEY` = 5).
  `Meta.affixesFor(key)` ; `ns.Affixes[id] = { name, level, text }`.


| Clé | Affixe | Effet (réglé par simulation, `Meta.AFFIX`) |
| --- | --- | --- |
| +1 | Fortifié | Ennemis normaux : +12 % de PV |
| +2 | Tyrannique | Élites : +5 % de PV et de dégâts ; boss : +3 % de PV |
| +3 | Galvanisant | Quand un ennemi meurt, les autres (sauf boss) gagnent 1 Force |
| +4 | Nécrotique | Chaque coup qui fait perdre des PV réduit tes soins de 5 %, 30 % au plus (état `necrotic` affiché sur le héros) |
| +5 | Disette | Le feu de camp ne soigne plus que 20 % des PV |

## Sauvegarde (`Core/Save.lua`)

`SlayTheDragonDB = { version = 5, meta, current = <expédition ou nil>, journal = {...}, quarantine = {...} }`

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
  ancienne réputation (gardée telle quelle dans `cs.rep`, plus lue) au barème de l'expérience de la v4 sans bonus de
  clé : `xp = rep × 0,5 + victoires × 15` ; l'expédition en cours passe de 3 à 4 (`unlock.rep` retiré,
  `unlock.level` = niveau de sa classe après la migration) (test « sauvegarde v3 -> v5 »).
- Version 5 (13/11/2026, campagne par zones) : par classe `cs.zones = { westfall = { won, keyMax,
  bestKey } }`, au compte `meta.zones = { westfall = true }`. Migration 4 → 5 : une classe qui a au moins
  une victoire (ou une clé au-delà de +0) a gagné Westfall et y garde sa clé max et sa meilleure clé
  (`cs.keyMax`, `cs.bestKey` déplacés ; clé max au moins +1) ; le compte a gagné Westfall si une classe l'a
  gagnée ; la réputation de Ligue (`meta.league`) est abandonnée. L'expédition en cours passe de 4 à 5 :
  `zone = "westfall"`, `unlock.common` et `unlock.won` = ceux de sa classe après la migration de la méta
  (`unlock.league` retiré ; ce qui était déjà tiré reste dans l'état), `acts = 1` ; elle reste jouable,
  combat en cours compris (test « sauvegarde v4 -> v5 », harnais UZ). Une expédition d'une zone inconnue ou
  plus jouable part en quarantaine.
- Jamais d'effacement : une expédition illisible part dans `db.quarantine` avec la raison ; une
  sauvegarde d'une version plus récente de l'addon n'est pas touchée.
- Journal : `{ result, class, zone, key, seed, act, floor, cleared, elites, bosses, hp, maxHp, gold,
  goldEarned, deck, relics, killedBy, date, xp }` (les entrées d'avant la v5 gardent `rep`, sans `zone`).

## Contrat avec les bibelots et potions (piste A)

- `ns.Relics[id].run` : crochets d'expédition appelés par `Expedition.modify / fire` :
  `gold(exp, v, source)`, `goldBonus(exp, v, source)` (fixe, après `gold`), `restFraction(exp, v)`,
  `restHeal(exp, v)`, `price(exp, v, genre)`, `removePrice(exp, v)`
  (valeurs), `onPickup(exp)` (au ramassage), `onNodeEnter(exp, nœud)`, `onCombatWon(exp, genre)`,
  `onRest(exp)` (notifications). `exp.relicState` est libre pour un compteur d'expédition.
- `rarity` : `common`, `uncommon`, `rare` (récompenses, coffres, marchand), `boss` (boss
  uniquement) ; `tier` 0..7 (communs : palier commun, zone dont la 1re victoire du compte le débloque) ;
  `class = "priest"` + `level` 1..7 = bibelot de classe (dans la réserve de cette classe seulement, dès ce
  niveau ; pas de `tier`) ; `key = { zone, level }` = bibelot de clé (`docs/zones.md`) ;
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
- **Ligue des explorateurs supprimée** (13/11/2026) : remplacée par la campagne par zones
  (`docs/zones.md`).
- **Niveau de classe** (12/11/2026, formule revue le 13/11/2026) : seuils 100 / 250 / 450 / 700 / 1 000 /
  1 400 ; expérience = 5 par étape, 6 par élite, 15 par boss, +15 pour une victoire, ×(1 + 0,15 × clé) :
  2 expéditions pour le niveau 2, ≈ 20 pour le 7 (voir « Niveau de classe »).
- **Clés** : une par zone et par classe (`cs.zones[zone].keyMax`) ; jouer une clé inférieure reste possible.
- **Affixes** : intensités ajustées (voir tableau ; recalées le 12/11/2026 après l'équilibrage des cinq classes, `docs/equilibrage.md`) pour ≈ −5 points par niveau ; Galvanisant
  n'affecte pas les boss (sinon chaque sbire tué de VanCleef le rendait injouable), Nécrotique
  arrondit au plus proche (l'arrondi par défaut annulait les soins de 2 d'Expiation dès le 1er coup).
- **Bibelot au choix sans bibelot à proposer** : si la réserve est vide, la phase `start` est sautée.

## Mesures de la progression par classe (12/11/2026, bot heuristique, clé 0, 1 000 expéditions, graine 1)

`luajit Sim/sim.lua runs=1000 bot=heuristic jobs=8 runner=expedition key=0 class=<c> meta=<m> level=<n>`
(intervalle ≈ ±2 points). « Avant » : code d'avant la progression (aae54aa), `meta=exalted`.
Mesures d'avant la campagne par zones : « Ligue exaltée » = `zones=7` aujourd'hui, « compte neuf » =
`zones=0` (`docs/zones.md`, « Simulation »).

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
