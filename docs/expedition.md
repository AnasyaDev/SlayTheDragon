# Expédition, méta-progression et sauvegarde

Couche « hors combat » de Slay the Dragon, en Lua 5.1 pur (aucune API WoW). L'interface (piste C)
et les bots de simulation passent par la même API.

| Fichier | Rôle |
| --- | --- |
| `Core/Map.lua` | Carte ramifiée d'une zone (8 étapes), générée par graine |
| `Core/Zones.lua` | Registre des sept zones de la campagne (`ns.Zones`, `ns.Zone`) : `docs/zones.md` |
| `Core/Meta.lua` | Niveau de classe (expérience), boss de zone battus (par classe et par le compte), zone la plus loin atteinte, clé par classe, affixes ; report au boss (`Meta.bank`) |
| `Core/Expedition.lua` | Machine à états d'une expédition (qui traverse les sept zones) |
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

-- Nouvelle expédition : toujours à Westfall (classe, clé 0..ns.Meta.keyMax(db.meta, classe))
local exp, why = ns.Save.start(db, { seed = graine, class = "priest", key = 0 })
-- why : "key locked", "running"

-- À chaque action du joueur
local ok, why = ns.Expedition.act(db.current, { "path", idNoeud })
ns.Save.settle(db) -- boss battu, zone atteinte : reportés tout de suite dans la méta (Meta.bank)
-- l'état est modifié sur place dans db.current, donc déjà « sauvegardé »
-- (WoW écrit les SavedVariables au /reload, à la déconnexion et à la fermeture).

-- Quand db.current.phase == "done"
local summary, entry = ns.Save.finish(db, date("%Y-%m-%d %H:%M"))
-- summary = { xp, levelBefore, levelAfter, unlocked = { cards, relics }, zone, beaten, zones = { { zone,
--             zoneWon, zoneCards, keyRelics, accountZone, common } }, zoneCards, keyRelics, keyUnlocked, flags }
--           xp = expérience de toute l'expédition ; unlocked = ce que la montée de niveau vient de débloquer ;
--           zone = zone atteinte, beaten = boss battus, zones = déblocages de chaque boss (docs/zones.md) ;
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
| `reward` | `{"pickCard", i}`, `{"skipCards"}`, `{"pickEpic", i}`, `{"skipEpic"}` (choix « Epic », `r.epics`), `{"takePotion"}`, `{"leave"}` |
| `campfire` | `{"rest"}`, `{"upgrade", indexDeck}`, `{"leave"}` |
| `merchant` | `{"buyCard", i}`, `{"buyRelic", i}`, `{"buyPotion", i}`, `{"remove", indexDeck}`, `{"leave"}` |
| `event` | `{"choose", i}` puis `{"leave"}` (si le choix n'a pas de suite) ; une réponse indisponible n'est pas dans `choices` et `act` la refuse avec sa raison (texte) |
| `select` (suite de rencontre) | `{"select", indexDeck}`, `{"skipSelect"}` ; ensuite la récompense de la même réponse s'il y en a une, sinon la carte |
| `transit` (entre deux zones, après la récompense d'un boss) | `{"continue"}` : la carte de la zone suivante |
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
| `class`, `zone`, `seed`, `key`, `affixes` | classe (id de `ns.Classes`, choisie sur l'accueil), zone EN COURS (id de `ns.Zones`), graine, niveau de clé (toute l'expédition), ids d'affixes actifs (`ns.Affixes[id].name/.text`) |
| `startZone`, `lastZone` | zone de départ (Westfall) et zone dont le boss termine l'expédition (Blackrock Mountain) ; autres valeurs : tests et diagnostic de simulation |
| `beaten` | ids des zones dont le boss est battu, dans l'ordre (comptés tout de suite : `Meta.bank`) |
| `transit` | phase `transit` : `{ from, to, healed }` (zone quittée, zone suivante, PV rendus par le passage) |
| `banked` | ce que la méta a déjà reçu (`Meta.bank`) : `{ n, xp, levelBefore, zones, flags }` |
| `unlock` | `{ level = niveau de la classe 1..7, common = palier commun du compte 0..7, won = { [zone] = meilleure clé où la classe a battu ce boss } }`, figé au départ : un déblocage pendant l'expédition (boss battu en route) ne change rien avant la suivante |
| `act`, `acts` | rang de la zone en cours dans l'expédition (1 = Westfall) et nombre de zones à traverser (7) |
| `map` | carte de la zone en cours (voir plus bas) |
| `node`, `floor` | nœud courant (nil avant le premier choix), étape 1..8 de la zone en cours |
| `hp`, `maxHp`, `gold` | |
| `deck` | `{ {id, up}, ... }` (`ns.Card.defById(id, up)` pour l'affichage) |
| `relics` | ids de `ns.Relics` (le bibelot de départ de la classe, `startRelic`, en tête) |
| `potions` | 3 emplacements (4 avec Herb Pouch : `X.addPotionSlot`) : id ou `false` |
| `combat` | état du combat en cours (phase `combat`) |
| `fight` | `{ kind = combat/elite/boss, pool, encounter, seed, reward }` pendant le combat |
| `reward` | phase `reward` : `{ kind, gold, goldGained, cards = {ids}, cardsDone, picked, relic, relicTaken, potion, potionTaken }` |
| `shop` | phase `merchant` : `{ cards = { {id, price, sold, neutral?, up?, epic?} }, relics = {...}, potions = {...}, removed }` (6e carte `neutral = true` : emplacement « Neutral » ; `up` = palier de la carte vendue déjà améliorée (1 aujourd'hui, `X.SHOP_UP_TIER`), zones 2 à 7 ; `removed` = retraits de la visite) ; prix selon le rang de la zone (« Économie sur sept zones ») ; retrait : `Expedition.removePrice(exp)` (crochet `removePrice`) |
| `event` | phase `event` : `{ id (false = rien à signaler), chosen (false ou index), rolls, result, lucky }` ; texte dans `ns.Events[id]` ; `result` = texte après le choix (réponse + issue du pari) ; `lucky` = issue d'un pari (true/false, nil sans pari) |
| `select` | phase `select` : `{ kind = "upgrade" | "remove" | "dupe", reward? }` |
| `flags` | drapeaux de compte connus au départ (copie de `meta.flags`, sert aux conditions) |
| `newFlags` | drapeaux posés pendant l'expédition, reportés dans `meta.flags` à chaque boss battu et en fin d'expédition |
| `startRelics` | phase `start` : ids proposés |
| `lastRest` | PV rendus par le dernier repos |
| `stats` | `{ cleared, elites, bosses, combats, goldEarned, goldSpent, cardsAdded, removed, upgraded, visits = {type = n}, events = {id = réponse (0 = pas encore choisi)} }` |
| `result` | `won` (Nefarian battu), `lost`, `abandoned` (phase `done`) ; `killedBy` en cas de défaite |

Aides de lecture : `Expedition.currentNode(exp)`, `Expedition.actName(exp)` (nom de la zone en cours),
`Expedition.campaignPos(exp)` (rang, 7), `Expedition.campaignName(exp)` (« Duskwood · 2/7 »), `Expedition.nextZone(exp)`,
`Expedition.canUpgrade(exp, i)`, `Expedition.freeSlot(exp)`, `Expedition.eventChoiceOk(exp, i)`
(griser un choix de rencontre), `Expedition.eventOptions(exp)` (réponses prêtes à afficher, voir
plus bas), `Expedition.removePrice(exp)`.

### Carte

`exp.map = { act, floors = 8, start = {ids}, nodes = { [id] = { id, floor, x, kind, next = {ids} } } }`

- Une carte par zone : `floor` 1..7 puis 8 (boss) ; `x` dans ]0, 1[ = position horizontale (2 à 3 nœuds par étape).
  Graine : Westfall tire dans le flux `map` de l'état (cartes de Westfall inchangées) ; chaque zone suivante dans
  `Rng.stream(graine, "map:<zone>")` (reproductible, indépendante de ce qui s'est passé avant).
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
vont dans `exp.newFlags` et sont reportés dans la méta **à chaque boss battu** (`Meta.bank`) et **en fin
d'expédition** (`Meta.record`, appelé par `Save.finish` et `Save.abandon`), quel que soit le résultat. La copie
`exp.flags` ne change pas : une suite ne peut donc jamais apparaître dans l'expédition qui l'a débloquée. Un drapeau n'est jamais retiré.
`Meta.hasFlag(meta, nom)`.

## Méta-progression (`Core/Meta.lua`)

`db.meta = { runs, zones = { westfall = true }, classes = { priest = { xp, runs, wins, keyMax, bestKey,
farthest, zones = { westfall = { won, keyMax (plus lu), bestKey } } } }, flags = { [nom] = true } }`

`zones` = boss de zone battus (compte, par classe) ; `wins` = victoires complètes (Nefarian) ; `keyMax` /
`bestKey` = clé de la classe pour toute l'expédition ; `farthest` = rang de la zone la plus loin atteinte.

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
| 7 | 1 400 | une rare par voie et 2 bibelots (34 cartes, 6 bibelots) ; titre « Veteran » (`Meta.title`) |

- Titre : « Veteran » au niveau 7 (`Meta.title`) ; « Dragonslayer » à la première victoire contre Nefarian
  avec la classe (`ns.Blackrock.title`, qui retombe sur `Meta.title`), seul titre lu par l'interface (accueil,
  Progress, journal). Décision du concepteur (`docs/zones/decisions.md`, nuit du 13 au 14/11/2026, à revoir
  par le joueur) ; `docs/classes/decisions.md` (12/11/2026) dit encore « Dragonslayer » au niveau 7.
- `Meta.XP_LEVELS`, `Meta.classLevel(xp)`, `Meta.xpProgress(xp)` → niveau, expérience dans le niveau,
  taille du niveau (nil au 7) ; `Meta.levelOf(meta, classe)` ; `Meta.isMaxLevel` ;
  `Meta.classContent(classe[, niveau])` → `{ cards, relics }` (tout, ou ce qui se débloque à ce niveau),
  triés par niveau, rareté, coût, nom ; `Meta.unlockLevel(def)` (champ `level`, absent = 1).
- **Expérience gagnée** sur toute l'expédition (campagne continue, 14/11/2026) : celle des étapes franchies est
  acquise à chaque boss battu (`Meta.bank`, `Meta.xpFor(exp, true)` sans le bonus de victoire), le reste en fin
  d'expédition, gagnée, perdue ou abandonnée (`Meta.xpFor`, `Meta.XP`) ; même formule (13/11/2026), sur 56
  étapes et 7 boss au plus, +15 seulement pour Nefarian :
  `(5 × étapes franchies + 6 × élites + 15 × boss + 15 si gagnée) × (1 + 0,15 × clé)`, arrondi
  (`Meta.XP = { step = 5, elite = 6, boss = 15, win = 15, key = 0.15 }`). Mêmes gains qu'avant à la clé 0
  (c'était la moitié de la réputation 10 / 12 / 30, + 15) : victoire avec une élite 8 × 5 + 6 + 15 + 15 =
  **76** (deux élites : 82), défaite au boss avec une élite 7 × 5 + 6 = **41**, défaite à l'étape 4 sans élite
  **15–20**. Clé : +1 → 87, +3 → 110, +5 → 133 pour la victoire type. Avec ≈ 4 victoires pour 1 défaite
  (≈ 70 en moyenne) : niveau 2 à la 2e expédition, puis 2, 3, 3, 4 et 6 expéditions par niveau (niveaux 3 à
  7 aux 4e, 7e, 10e, 14e et 20e ; mesuré avant le changement : 72 à 75 par expédition au bot heuristique).
  **Campagne continue (14/11/2026)** : une expédition traverse jusqu'à 56 étapes et 7 boss ; ≈ 200 à 450
  d'expérience par expédition, niveau 7 en ≈ 6 expéditions (« Mesures de la campagne continue »).
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
- Clés mythiques **par classe, pour toute l'expédition** (concepteur, 14/11/2026) : `Meta.keyMax(meta, classe)`,
  `Meta.bestKey(meta, classe)` ; battre Nefarian à +N ouvre +N+1 pour cette classe (plafond `Meta.MAX_KEY` = 5) ;
  `Meta.bestKey(meta, classe, zone)` = meilleure clé où la classe a battu le boss de cette zone (bibelots de clé).
  `Meta.affixesFor(key)` ; `ns.Affixes[id] = { name, level, text }`.


| Clé | Affixe | Effet (réglé par simulation, `Meta.AFFIX`) |
| --- | --- | --- |
| +1 | Fortifié | Ennemis normaux : +12 % de PV |
| +2 | Tyrannique | Élites : +5 % de PV et de dégâts ; boss : +3 % de PV |
| +3 | Galvanisant | Quand un ennemi meurt, les autres (sauf boss) gagnent 1 Force |
| +4 | Nécrotique | Chaque coup qui fait perdre des PV réduit tes soins de 5 %, 30 % au plus (état `necrotic` affiché sur le héros) |
| +5 | Disette | Le feu de camp ne soigne plus que 20 % des PV |

## Cartes épiques (socle du 13/11/2026, règle finale du 14/11/2026)

Décision du joueur (`docs/zones/decisions.md`) : les cartes de zone sont des **cartes épiques**, une par
classe et par zone, débloquées par la première victoire de la classe dans la zone (`zone = "<id>"`,
`Expedition.unlocked`, `Meta.zoneCards`). Règle d'arrivée en jeu tranchée par le concepteur
(`docs/zones/decisions.md`, « Cartes épiques : tranché par le concepteur » ; `docs/zones/cartes-de-zone.md`, A et B) ;
obtention : l'épique se gagne (`docs/zones/decisions.md`, « Difficulté et épiques », 14/11/2026).

- **Rareté `epic`** (`rarity = "epic"`, au-dessus de `rare`, sous `boss` : `Meta.RARITY_ORDER`). Une épique
  n'est **jamais** dans les récompenses ordinaires, les choix de rencontre ni l'étal des cartes de classe
  (`Expedition.cardPool`, `Card.pool`, `Rewards.cardPool` l'excluent) : elle n'arrive que par la chute aux
  élites ci-dessous, l'emplacement épique du marchand, ou un effet de rencontre `{ "card", id }` explicite.
- **Une règle en jeu dès le début de chaque combat.** `Combat.new` pose l'épique du deck dans `c.epic =
  { id, up, uid }` (instance de données simples, sauvegardée et clonée avec le combat) au lieu de la pioche :
  elle n'entre dans **aucune pile** (pioche, main, défausse, consumées, recharges, pouvoirs joués) ; elle
  n'est ni piochée, ni jouée, ni copiée ; ni Hex, ni Curse, ni « Remove negative effects. », ni un retrait de
  Power ne la touche. Elle n'a pas de coût. La main de départ garde sa taille (5 cartes tirées du reste).
  Ses crochets sont actifs tout le combat : `whileInDeck(c, src)` au début du combat (après `init` de la
  classe, avant `onCombatStart`), `deckHooks` et `hooks` de sa définition (comme un Power posé d'office) dans
  `Combat.modify` / `Combat.fire`, **après** pouvoirs, bibelots et affixes (Shadow Covenant lit le coût
  final), et son crochet `allow` dans `Combat.canPlay`. `src` = `c.epic`. Les autres cartes à `deckHooks`
  (non épiques) restent dans `c.passives`, comme avant.
- **Carte du deck de l'expédition.** Elle compte dans le deck (affichée en tête), s'améliore au feu de camp
  (choix volontaire, ou rencontre « upgrade » ; `Expedition.upgradeRandom` l'évite), se retire chez le
  marchand ou en rencontre (le deck n'a alors plus d'épique).
- **Une seule épique par expédition.** `Expedition.addCard` d'une épique retire celle du deck (améliorée ou
  non ; la nouvelle arrive non améliorée, l'amélioration est perdue) : `exp.stats.epicReplaced`,
  `exp.epicReplaced = { old, oldUp, new }`. Récompense, marchand ou rencontre : même règle (c'est `addCard`).
  Une épique ne se copie pas (sélection « dupe » : absente des choix, refus `"epic"`).
  `Expedition.epicIndex(exp)` = index de l'épique du deck ou nil.
- **Transformations** : une épique peut porter `transforms = { [id_origine] = id_variante }` (sur sa définition
  de base ou améliorée) ; tant qu'elle est dans le deck, chaque carte d'origine se joue comme sa variante
  (`Card.applyTransforms(deck)`, appliqué par `Combat.new` et par l'affichage : `Expedition.shownDeck(exp)`,
  bandeau, panneau du deck, amélioration, retrait, sélection). Le deck de l'expédition n'est jamais réécrit :
  remplacer ou retirer l'épique défait tout. La variante garde l'état amélioré de l'originale si elle a une
  amélioration (`up`), sinon elle est de base ; elle porte `variant = true` (jamais collectionnable : ni
  récompense, ni marchand, ni progression, `Card.collectible`).
- **L'épique se gagne (décision du joueur, 14/11/2026).** Rien au départ : plus d'offre à l'étape 1 (ni phase
  de choix, ni tirage ; le départ ne propose que le bibelot au choix de la zone 3). Elle tombe sur un élite ou
  s'achète chez le marchand.
- **Chute par élite, selon la zone.** Après **chaque** victoire d'élite (combat d'élite de rencontre compris),
  `Expedition.rollEpicDrop(exp, r, genre)` tire une chance qui dépend du rang de la zone EN COURS (`ns.Zone.order`) :
  `EPIC.drop.elite[rang]`, 25 % à Westfall, +10 points par zone, 85 % à Blackrock Mountain
  (`Expedition.epicDropChance(exp, genre)` ; une table plus courte que la campagne garde sa dernière valeur ;
  un genre absent de `EPIC.drop` ne fait jamais rien tomber : combats normaux et boss). Quand elle tombe :
  `EPIC.choices` (1) épique débloquée autre que celle du deck s'ajoute à la récompense normale (`r.epics`,
  `r.epicDone`, `r.epicPicked` ; actions `pickEpic` / `skipEpic`) : la prendre (elle remplace l'actuelle), ou
  garder l'actuelle (refus ; partir sans choisir = refuser). Seules les épiques débloquées par la classe sont
  proposables ; s'il n'y en a aucune, rien ne tombe et rien n'est tiré.
- **Marchand** : à partir de la moitié du parcours, une chance qu'il vende une épique (à la suite des cartes,
  `shop.cards[i].epic = true`), 150 po × le multiplicateur de prix de la zone (`PRICE_BY_ZONE` : 150 à Westfall,
  330 à Blackrock Mountain ; ± 10 %, crochet `price` genre `"card"` ; « Économie sur sept zones ») ; achat = `addCard`.
- **Hasard** : flux `exp.rng.epic` (créé au premier usage : premier tirage de chute, puis l'épique proposée ;
  marchand) ; les autres flux ne bougent pas. Sans épique débloquée : ni tirage, ni flux ; une expédition se
  déroule exactement comme sans épiques.

Paramètres (`Expedition.EPIC`, à changer en un endroit) :

| Clé | Défaut | Règle |
| --- | --- | --- |
| `drop` | `{ elite = { 0,25, 0,35, 0,45, 0,55, 0,65, 0,75, 0,85 } }` | par genre de combat, chance par rang de zone (1 = Westfall … 7 = Blackrock Mountain) qu'une victoire propose une épique |
| `choices` | 1 | épiques proposées quand elle tombe |
| `shop` | 0,5 | chance qu'un marchand vende une épique (0 = jamais) |
| `shopFloor` | 4 | étape à partir de laquelle le marchand peut en vendre (étapes 1 à 7, boss en 8) |
| `price` | 150 | prix de base d'une épique chez le marchand |

**Part de rares par zone** (`Expedition.RARE_BY_ZONE`, même décision : un deck fourni en rares est la cible
des zones tardives) : dans les récompenses de cartes de combat et d'élite (le marchand a sa propre progression
depuis le 15/11/2026, `SHOP_RARE_BY_ZONE` : « Économie sur sept zones »), le poids `rare` de `CARD_WEIGHTS` est multiplié par le facteur du rang de la zone et
pris sur le poids `common` (total inchangé : la part de rares est multipliée d'autant) ;
`Expedition.cardWeights(exp, genre)`. Le boss n'offre que des rares (inchangé) ; les choix de cartes des
rencontres gardent leurs poids. Facteurs proposés, à régler par simulation :

| Rang | 1 Westfall | 2 | 3 | 4 | 5 | 6 | 7 Blackrock |
| --- | --- | --- | --- | --- | --- | --- | --- |
| facteur | 1 | 1,15 | 1,3 | 1,5 | 1,65 | 1,8 | 2 |
| rares, combat (base 7 %) | 7 % | 8,1 % | 9,1 % | 10,5 % | 11,6 % | 12,6 % | 14 % |
| rares, élite (base 15 %) | 15 % | 17,3 % | 19,5 % | 22,5 % | 24,8 % | 27 % | 30 % |
| rares, marchand (base 13 %) | 13 % | 16,9 % | 20,8 % | 24,7 % | 28,6 % | 32,5 % | 36,4 % |

(Ligne du marchand : `SHOP_RARE_BY_ZONE`, 1 / 1,3 / 1,6 / 1,9 / 2,2 / 2,5 / 2,8, depuis le 15/11/2026 ; avant : ce tableau.)

Zone 1 : poids d'origine, tirages identiques à avant.

Sauvegarde : expédition version 7 (aujourd'hui 8, `Expedition.VERSION`, voir « Sauvegarde ») ; `c.epic` facultatif (absent =
rien à faire). Un combat sauvegardé par l'ancien socle (épique dans la pioche) se termine tel quel ; le combat
suivant pose l'épique comme une règle (test dans `Sim/tests_epic.lua`).
Dans le combat : mot-clé `Innate` (champ `innate`, pour les cartes ordinaires), effets passifs du deck
(`deckHooks`, `whileInDeck`) et points d'accroche de classe : `docs/classes.md`, « Cartes épiques ».
Simulation : sans option, le bot suit la règle (l'épique se gagne aux élites et chez le marchand) ;
`epic=<id>` (épique imposée au départ, jamais remplacée par le bot : mesure d'une épique), `epic=none` (aucune
épique : le bot refuse toutes les offres) ; `sweep=cards` mesure aussi les épiques de la classe, chacune
imposée, contre une ligne « (sans) » et des cartes mesurées avec `epic=none`. Le bot choisit aux élites et
chez le marchand par note (`Sim/expedition.lua`, `SE.epicRating` : `classDef.bot.epic(exp, id)` si la classe le
définit, sinon `classDef.bot.rating[id]`, sinon `SE.EPIC_RATING` = 7 ; remplacement si la nouvelle vaut mieux
que l'actuelle de `SE.EPIC_MARGIN`). Au feu de camp, tant que l'épique est à améliorer, il choisit entre elle et
les cartes que sa table `classDef.bot.byEpic[id].upgrade` classe au moins aussi haut, dans l'ordre de la table
(avant le 14/11/2026, une carte absente de la table prenait sa note de choix, d'une autre échelle, et passait
devant : l'épique n'était presque jamais améliorée). Tests : `Sim/tests_epic.lua` ; interface :
`docs/interface.md`, « Cartes épiques ».

## Sauvegarde (`Core/Save.lua`)

`SlayTheDragonDB = { version = 6, meta, current = <expédition ou nil>, journal = {...}, quarantine = {...} }`

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
- Expédition version 6 (13/11/2026, cartes épiques ; `Save.VERSION` reste 5, la méta ne change pas) :
  `exp.epicOffered`, `exp.rng.epic` (créé au premier usage), `reward.epics` / `epicDone` / `epicPicked`,
  `shop.cards[i].epic`, `exp.epicReplaced`, `stats.epicReplaced` ; puis `exp.startEpics`, `exp.startEpicPicked`
  (offre de départ, règle du 14/11/2026 au matin). Migration 5 → 6 : rien à poser (`epicOffered` n'est plus lu
  depuis la v7) ; un combat en cours garde ses cartes telles quelles. Combat : `c.passives` (cartes à
  `deckHooks`, entrées `{ id, up, uid }` séparées des piles : données simples).
- Expédition version 7 (14/11/2026, l'épique se gagne ; `Save.VERSION` reste 5) : plus d'offre de départ.
  Migration 6 → 7 (`Save.EXP_MIGRATIONS[6]`) : `exp.startEpics`, `exp.startEpicPicked` et `exp.epicOffered` sont
  retirés ; une expédition arrêtée sur l'offre d'épique de l'étape 1 (phase `"start"`) passe au bibelot de
  départ s'il reste à choisir, sinon à la carte (l'offre est perdue, rien n'est effacé) ; une épique déjà prise
  reste dans le deck. Tests « sauvegarde : expédition v5 en cours migrée en v7 » et « v6 arrêtée sur l'offre
  d'épique de l'étape 1 rechargée en v7 sans erreur » (`Sim/tests_epic.lua`), harnais UZ.
- Version 6 (14/11/2026, une expédition traverse la campagne ; expédition version 8). Méta 5 → 6
  (`Save.MIGRATIONS[5]`) : rien n'est retiré (`cs.zones[zone].won` et `.bestKey` gardés : épiques et bibelots de
  clé acquis) ; clé de la classe `cs.keyMax` = la plus haute clé ouverte dans une zone (toute clé jouable avant le
  reste) ; `cs.bestKey` = celle de Blackrock Mountain si la classe l'a gagnée, sinon -1 ; `cs.farthest` = rang de
  la plus avancée des zones gagnées par la classe ou jouées par elle (journal). Expédition 7 → 8
  (`Save.EXP_MIGRATIONS[7]`) : une expédition d'une seule zone en cours **continue dans sa zone** puis enchaîne
  normalement jusqu'à Blackrock Mountain (`startZone` = sa zone, `lastZone` = Blackrock Mountain, `act` = 1,
  `acts` = zones restantes, `beaten` = {}) ; arrêtée sur la récompense de son boss, ce boss est déjà battu
  (`beaten` = { sa zone }) et compte tout de suite (`Save.migrate` appelle `Save.settle`). Tests « sauvegarde v7
  -> v8 » et « rechargement en plein milieu de la zone 3 et sur l'écran entre deux zones »
  (`Sim/tests_expedition.lua`), harnais U6 et UZ.
- Version 7 (15/11/2026, paliers d'amélioration +1 à +3 ; expédition version 9 ; `docs/ameliorations.md`). Le champ
  `up` d'une carte vaut `false` ou le palier 1..3 (`true` reste lu comme le palier 1). Méta 6 → 7
  (`Save.MIGRATIONS[6]`) : decks du journal, `up = true` → 1. Expédition 8 → 9 (`Save.EXP_MIGRATIONS[8]`) : toute
  table qui désigne une carte (deck, piles et Powers du combat en cours, épique du combat, marchand) passe de
  `true` à 1 (`Save.normalizeUp`), `epicReplaced.oldUp` aussi ; `stats.upTiers` (améliorations par palier
  atteint) = `{ stats.upgraded }`. Test « sauvegarde v6/expédition v8 -> v7/v9 » (`Sim/tests_expedition.lua`).
- Jamais d'effacement : une expédition illisible part dans `db.quarantine` avec la raison ; une
  sauvegarde d'une version plus récente de l'addon n'est pas touchée.
- Journal : une entrée par expédition `{ result, class, zone (zone atteinte), beaten (boss battus), key, seed, act,
  floor, cleared, elites, bosses, hp, maxHp, gold, goldEarned, deck, relics, killedBy, date, xp }` (les entrées
  d'avant la v5 gardent `rep`, sans `zone` ; celles d'avant la v6, sans `beaten`).

## Campagne continue (décision du joueur, 14/11/2026)

Une expédition commence toujours à Westfall avec le deck de départ et traverse les sept zones dans l'ordre
(`docs/zones/decisions.md`, dernière section ; règles détaillées : `docs/zones.md`, « Une expédition traverse la
campagne »).

- **Boss d'une zone battu** (`exp.beaten`) : récompense de boss, puis `{"leave"}` mène à la phase `transit`
  (`Expedition.enterZone`) : `exp.zone` devient la zone suivante, nouvelle carte, soin de `Expedition.ZONE_HEAL`
  (50 %) des PV max sans dépasser le maximum (crochet `healOut`), `exp.transit = { from, to, healed }` ;
  `{"continue"}` ouvre la carte. Deck, bibelots, or, potions, épique et PV max sont gardés ; règle de zone,
  ennemis, rencontres, décors, marchand, chute d'épique et part de rares suivent la zone en cours.
- **Nefarian battu** = `result = "won"` ; `Meta.record` ouvre alors la clé suivante de la classe.
- **Report immédiat** (`Meta.bank`, `Save.settle`) : à chaque boss battu, la méta reçoit l'épique de la classe
  liée à la zone, le commun du compte, les bibelots de clé, l'expérience des étapes franchies et les drapeaux ;
  rien n'attend la fin de l'expédition. `exp.unlock` et `exp.flags` restent figés au départ (un déblocage gagné
  en route ne sert qu'à l'expédition suivante, comme avant).
- **Sans épique, mur après la zone 4 (décision du joueur, 19/11/2026).** Sans carte épique dans le deck, la
  chance d'aller au-delà de Stranglethorn Vale tombe drastiquement : un compte neuf bute vers la zone 4 à sa
  première expédition, puis repart avec les épiques des zones gagnées et peut finir dès la suivante. Cible
  (battue / atteinte, bot `human`, clé 0) : zones 1 à 3 inchangées ; Stranglethorn 60 % sans épique / 90 % avec,
  Swamp of Sorrows 35 / 80, Burning Steppes 30 / 80, Blackrock Mountain 25 / 75. Levier : la **dureté des zones**
  (`ns.Zone.HARD`, `Core/Zones.lua` : facteur sur les PV et les coups de tous les ennemis de la zone, 1,45 / 1,8 /
  2,15 / 2,3 ; `docs/zones.md`, « Dureté des zones »). La colonne « sans épique » est atteinte ; la colonne « avec
  épique » ne l'est pas encore (une épique n'apporte que 0 à 10 points) : leviers mesurés et choix laissé au
  joueur dans `docs/equilibrage.md`, « Mur des zones 4 à 7 sans épique (19/11/2026) ».
- **Zone la plus loin atteinte** : `cs.farthest` (l'entrée en phase `transit` compte comme atteinte).
- **Diagnostic** (tests, simulation) : `Expedition.new{ zone = <départ>, lastZone = <arrêt> }` ; une zone hors
  de la campagne (zone factice des tests) est jouée seule.

Décisions de détail (concepteur, 14/11/2026, à revoir par le joueur) :
- le soin du passage passe par `healOut` (soin hors combat : Cursed Eye of Paleth le divise par deux) ;
- la zone suivante est « atteinte » dès l'écran entre deux zones (un abandon sur cet écran compte comme arrivé) ;
  le bilan dit alors « Turned back at the gates of Duskwood (2/7). » ;
- abandonner sur la récompense d'un boss ne retire rien : le boss est déjà battu ;
- les deux premiers combats de chaque zone sont « easy » (comme le premier acte), le prix du retrait de carte
  continue de monter sur toute l'expédition, une rencontre vue ne revient pas dans la même expédition ;
- le bilan regroupe les déblocages (une expédition peut battre sept boss d'un coup) ;
- `Expedition.enterZone` est public : les tests et le harnais d'interface s'en servent pour amener une expédition
  dans une zone plus loin.

## Économie sur sept zones (décision du joueur, 15/11/2026)

**Constat** (mesuré avant le changement, bot `human`, clé 0, 600 expéditions par classe) : l'économie datait d'une
zone par expédition. Gains ≈ 150 à 270 po par zone (`GOLD` : combat 12–18, élite 25–35, boss 75–85, coffre 20–30,
plus les rencontres ; 50 au départ), étal entier ≈ 700 à 950 po à prix fixes, marchand ≈ 0,43 visite par zone. Le
Warrior gagnait 1 088 po par campagne, en dépensait 602 et finissait avec 536 inutilisés (≈ 50 % du gagné ; 35 %
tout débloqué) ; à partir de Stranglethorn, tout l'étal était souvent achetable (jusqu'à 77 % des visites de
Blackrock Mountain au compte neuf). Le joueur avait pu acheter tout l'étal dès la zone 2.

**Décision du joueur** : « Équilibrer. Pour les marchands des zones plus hautes : augmenter les prix, MAIS augmenter
la chance d'y trouver des cartes déjà améliorées et plus rares. »

**Règles** (`Core/Expedition.lua`, tables par rang de la zone EN COURS, `ns.Zone.order` ; au-delà de la table, la
dernière valeur ; rang 1 = étal d'origine) :

| Rang | 1 WF | 2 DW | 3 WL | 4 STV | 5 SoS | 6 BS | 7 BRM |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `PRICE_BY_ZONE` (prix × ; `Expedition.priceFactor(exp)`) | 1 | 1,2 | 1,4 | 1,6 | 1,8 | 2,0 | 2,2 |
| `SHOP_UPGRADED` (chance qu'une carte soit vendue améliorée ; `Expedition.shopUpgradeChance(exp)`) | 0 | 10 % | 20 % | 30 % | 40 % | 50 % | 60 % |
| `SHOP_RARE_BY_ZONE` (part de rares des cartes de l'étal ×) | 1 | 1,3 | 1,6 | 1,9 | 2,2 | 2,5 | 2,8 |
| → cartes rares à l'étal (base 13 %) | 13 % | 16,9 % | 20,8 % | 24,7 % | 28,6 % | 32,5 % | 36,4 % |
| `SHOP_RELIC_RARE_BY_ZONE` (part de bibelots rares de l'étal ×) | 1 | 1,2 | 1,4 | 1,6 | 1,8 | 2,0 | 2,2 |
| → bibelots rares à l'étal (base 15 %) | 15 % | 18 % | 21 % | 24 % | 27 % | 30 % | 33 % |
| carte commune / peu commune / rare (po) | 35 / 55 / 90 | 42 / 66 / 108 | 49 / 77 / 126 | 56 / 88 / 144 | 63 / 99 / 162 | 70 / 110 / 180 | 77 / 121 / 198 |
| bibelot commun / peu commun / rare (po) | 90 / 120 / 160 | 108 / 144 / 192 | 126 / 168 / 224 | 144 / 192 / 256 | 162 / 216 / 288 | 180 / 240 / 320 | 198 / 264 / 352 |
| potion commune / peu commune / rare (po) | 30 / 45 / 60 | 36 / 54 / 72 | 42 / 63 / 84 | 48 / 72 / 96 | 54 / 81 / 108 | 60 / 90 / 120 | 66 / 99 / 132 |
| épique (po) | 150 | 180 | 210 | 240 | 270 | 300 | 330 |

- **Prix** : base (`PRICES`, `EPIC.price`) × `PRICE_BY_ZONE` × `UPGRADED_PRICE` (1,25, carte vendue améliorée)
  ± `PRICE_JITTER` (10 %), **puis** le crochet `price` des bibelots (une remise s'applique au prix de la zone) ;
  cartes de classe, emplacement « Neutral », bibelots, potions et épique.
- **Cartes vendues améliorées** : chaque carte de l'étal (classe ou neutre, qui a une amélioration ; jamais
  l'épique) est tirée améliorée avec la chance `SHOP_UPGRADED` (tirage du flux `merchant` avant son prix, **aucun
  tirage si la chance est nulle**) : `shop.cards[i].up` = palier vendu (`X.SHOP_UP_TIER`, 1 aujourd'hui ; `docs/ameliorations.md`), affichée améliorée par l'interface (`merchantStep`
  de `UI/Controller.lua` passe `up` à la carte de l'étal), ajoutée améliorée au deck par `buyCard`.
- **Rareté** : `Expedition.cardWeights(exp, "shop")` suit désormais `SHOP_RARE_BY_ZONE` (il suivait `RARE_BY_ZONE`,
  ×2 à Blackrock Mountain : trop faible pour « plus rares », et partagé avec les récompenses) ; les bibelots de l'étal
  tirent avec `Expedition.shopRelicWeights(exp)` (poids `rare` de `RELIC_WEIGHTS.normal` × `SHOP_RELIC_RARE_BY_ZONE`,
  pris sur `common`). Récompenses de combat, d'élite, coffres et rencontres : inchangés.
- **Épique** : suit le multiplicateur (150 → 330 po). Mesure : le bot n'achète jamais l'épique du marchand, ni à
  150 ni au nouveau prix (0,00 achat pour 0,2 à 0,4 épique en vente par visite, tout débloqué) : l'épique se gagne aux
  élites (99 % des decks en ont une à Blackrock Mountain, avant comme après). Décision par la cohérence des prix :
  à 150 fixes, l'épique coûterait à Blackrock Mountain moins qu'une rare (198 po) ou qu'une rare améliorée (248 po) ;
  elle reste ainsi, comme à Westfall, la carte la plus chère de l'étal.
- **Retrait de carte** : **ne suit pas** le multiplicateur. Il monte déjà de 25 po à chaque retrait sur toute
  l'expédition (le bot `human` en fait 1 à 2,2 par expédition : 100 à 130 po en fin de campagne) ; mesure : 0,2 à 0,5
  retrait par visite tout débloqué (0,2 à 0,7 avant), 1,2 à 1,5 au compte neuf dans les zones 5 à 7 (1,6 à 1,9 avant)
  — c'est le seul achat qui reste quand le deck a 40 cartes et l'étal plus de bibelots (compte neuf) ; le multiplier
  l'aurait mis à 300–500 po. Le crochet `removePrice` (Darkmoon Faire Prize Ticket) s'applique comme avant.
- **Westfall inchangée** : facteurs 1 et chance 0 au rang 1 : mêmes tirages et mêmes prix à la pièce près (60 étals des
  cinq classes identiques au code d'avant ; test « marchand de Westfall inchangé » : identiques, flux compris, à un
  marchand sans aucun effet de zone), mêmes taux de victoire à Westfall à graine égale.
- **Sauvegarde** : `shop.cards[i].up` est facultatif (absent = carte de base) : un étal ouvert avant le changement reste
  valide et s'achète tel quel ; pas de nouvelle version d'expédition (`Expedition.VERSION` reste 8 ; test « sauvegarde :
  étal ouvert d'une zone haute »).

**Bot** (`Sim/expedition.lua`, pour que l'or inutilisé mesure l'économie et non le bot) :
- une carte vendue améliorée vaut sa note + `SE.UPGRADED_BONUS`, plus `SE.SHOP_UP_VALUE` (0,5 unité, la moitié d'une
  amélioration de feu de camp) ;
- le coût d'un article est jugé au prix de la zone (`SE.priceCost` : 0,03 unité par pièce ÷ `priceFactor`) ; au-delà
  d'une réserve de `SE.RESERVE` (150) pièces de Westfall × `priceFactor`, l'or est un surplus dont chaque pièce ne
  vaut que `SE.SURPLUS_VALUE` (0,2) ; dans la dernière zone, la réserve est nulle (plus rien à garder). Avant, une
  carte ne valait presque rien dans un deck de 40 cartes face à son prix : au compte neuf, le bot repartait de Blackrock
  Mountain avec 0,6 article acheté pour 735 po en poche ;
- il va au marchand quand sa bourse est pleine : score de la case marchand 1,6 + 1 par `SE.RICH_STEP` (40) pièces au-delà
  de `SE.RICH_GOLD` (150) pièces de Westfall, au plus `SE.RICH_MAX` (5) de plus (visites ≈ 0,43 → 0,6 par zone à partir
  de Duskwood ; à Westfall, la bourse dépasse rarement 150 : routes inchangées, 0,32 visite).

**Mesures** (`luajit Sim/sim.lua runs=600 bot=human jobs=8 runner=expedition key=0 class=<c> zones=0 level=2`, puis
`zones=7 level=7` ; graine 1 ; rapport « Or et marchand par zone » ajouté au rapport de simulation, avec « Or gagné
après le dernier marchand ») :

**`zones=0 level=2`, par classe** (avant → après ; 600 expéditions, ± 4 points sur les victoires)

| Classe | victoires | or gagné | dépensé | inutilisé (% du gagné) | inutilisé, victoires | gagné après le dernier marchand | articles / visite (DW–BRM) | visites / zone |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Priest | 44,0 → 43,0 | 1083 → 1051 | 565 → 863 | 52,4 → **22,7 %** | 50,5 → 19,5 % | 17,8 % | 2,03 → 1,98 | 0,42 → 0,63 |
| Warrior | 61,7 → 63,7 | 1088 → 1097 | 602 → 897 | 49,3 → **22,8 %** | 46,4 → 19,6 % | 19,5 % | 2,47 → 2,10 | 0,44 → 0,61 |
| Mage | 31,2 → 35,3 | 754 → 787 | 408 → 635 | 52,5 → **25,7 %** | 47,6 → 19,2 % | 21,6 % | 2,24 → 2,13 | 0,45 → 0,61 |
| Rogue | 25,8 → 25,2 | 684 → 677 | 365 → 532 | 54,0 → **28,8 %** | 47,0 → 19,7 % | 24,9 % | 2,34 → 2,13 | 0,42 → 0,59 |
| Hunter | 27,0 → 24,5 | 742 → 705 | 403 → 553 | 52,4 → **28,7 %** | 45,7 → 21,5 % | 23,1 % | 2,05 → 1,99 | 0,44 → 0,61 |

**`zones=0 level=2`, par zone** (moyenne des cinq classes, avant → après) : or à l'entrée du marchand, prix de l'étal entier, part de l'étal achetable, visites où tout l'étal est achetable, articles abordables (or / prix moyen d'un article), articles achetés, retraits, battue / atteinte

| Zone | or au marchand | étal entier (po) | part achetable | étal entier achetable | abordables | achetés | retraits | battue / atteinte |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| WF | 93 → 93 | 698 → 698 | 13 → 13 % | 0,0 → 0,0 % | ≈ 1,6 → 1,60 | 0,97 → 0,97 | 0,22 → 0,22 | 70,3 → 70,3 |
| DW | 237 → 250 | 693 → 845 | 34 → 30 % | 0,0 → 0,0 % | ≈ 4,1 → 3,56 | 2,61 → 2,25 | 0,10 → 0,12 | 82,5 → 83,3 |
| WL | 320 → 304 | 686 → 990 | 47 → 31 % | 0,0 → 0,0 % | ≈ 5,6 → 3,69 | 3,52 → 2,37 | 0,30 → 0,19 | 87,5 → 86,6 |
| STV | 412 → 359 | 615 → 1061 | 65 → 34 % | 12,2 → 0,0 % | ≈ 7,7 → 3,90 | 3,67 → 2,48 | 0,74 → 0,33 | 87,7 → 88,1 |
| SoS | 500 → 392 | 460 → 896 | 87 → 45 % | 51,9 → 0,5 % | ≈ 10,3 → 4,24 | 1,95 → 1,88 | 1,62 → 1,18 | 94,2 → 93,8 |
| BS | 624 → 455 | 420 → 936 | 93 → 49 % | 75,6 → 0,0 % | ≈ 13,4 → 4,43 | 1,02 → 1,49 | 1,87 → 1,46 | 97,1 → 98,3 |
| BRM | 735 → 485 | 414 → 1060 | 94 → 46 % | 77,2 → 0,0 % | ≈ 16,0 → 4,17 | 0,60 → 1,93 | 1,87 → 1,42 | 89,4 → 88,6 |

**`zones=7 level=7`, par classe** (avant → après ; 600 expéditions, ± 4 points sur les victoires)

| Classe | victoires | or gagné | dépensé | inutilisé (% du gagné) | inutilisé, victoires | gagné après le dernier marchand | articles / visite (DW–BRM) | visites / zone |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Priest | 66,0 → 65,0 | 1032 → 1009 | 713 → 826 | 35,8 → **23,1 %** | 32,3 → 21,3 % | 20,0 % | 3,12 → 1,74 | 0,43 → 0,57 |
| Warrior | 85,8 → 86,2 | 1186 → 1172 | 820 → 957 | 35,0 → **22,6 %** | 33,5 → 21,3 % | 20,1 % | 3,25 → 1,81 | 0,43 → 0,56 |
| Mage | 76,0 → 74,8 | 1062 → 1034 | 724 → 838 | 36,5 → **23,8 %** | 34,3 → 21,8 % | 20,8 % | 3,10 → 1,74 | 0,43 → 0,55 |
| Rogue | 59,0 → 63,2 | 885 → 907 | 578 → 732 | 40,4 → **24,9 %** | 35,5 → 21,0 % | 21,6 % | 3,14 → 1,74 | 0,42 → 0,56 |
| Hunter | 70,3 → 70,7 | 1015 → 993 | 661 → 803 | 39,8 → **24,2 %** | 36,8 → 21,5 % | 21,0 % | 2,98 → 1,67 | 0,42 → 0,56 |

**`zones=7 level=7`, par zone** (moyenne des cinq classes, avant → après) : or à l'entrée du marchand, prix de l'étal entier, part de l'étal achetable, visites où tout l'étal est achetable, articles abordables (or / prix moyen d'un article), articles achetés, retraits, battue / atteinte

| Zone | or au marchand | étal entier (po) | part achetable | étal entier achetable | abordables | achetés | retraits | battue / atteinte |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| WF | 94 → 94 | 918 → 918 | 10 → 10 % | 0,0 → 0,0 % | ≈ 1,4 → 1,38 | 0,98 → 0,99 | 0,21 → 0,21 | 83,9 → 83,9 |
| DW | 236 → 249 | 920 → 1136 | 26 → 22 % | 0,0 → 0,0 % | ≈ 3,4 → 2,94 | 2,48 → 2,13 | 0,14 → 0,16 | 92,1 → 92,7 |
| WL | 314 → 298 | 924 → 1353 | 34 → 22 % | 0,0 → 0,0 % | ≈ 4,5 → 2,95 | 3,08 → 2,07 | 0,20 → 0,20 | 97,4 → 97,6 |
| STV | 362 → 310 | 937 → 1603 | 39 → 20 % | 0,0 → 0,0 % | ≈ 5,2 → 2,60 | 3,31 → 1,78 | 0,35 → 0,28 | 97,6 → 98,1 |
| SoS | 412 → 331 | 940 → 1866 | 44 → 18 % | 2,7 → 0,0 % | ≈ 5,8 → 2,38 | 3,30 → 1,58 | 0,52 → 0,33 | 98,5 → 97,9 |
| BS | 451 → 358 | 951 → 2141 | 47 → 17 % | 7,4 → 0,0 % | ≈ 6,3 → 2,24 | 3,29 → 1,42 | 0,55 → 0,38 | 99,8 → 99,9 |
| BRM | 490 → 375 | 954 → 2446 | 50 → 16 % | 9,1 → 0,0 % | ≈ 6,9 → 2,07 | 3,24 → 1,44 | 0,68 → 0,47 | 98,3 → 98,6 |

Lecture :
- **Or inutilisé** : ≈ 50 → 23–29 % au compte neuf, ≈ 36–40 → 23–25 % tout débloqué ; **19 à 22 % pour les expéditions
  victorieuses**. La cible de 20 % n'est pas atteinte sur l'ensemble : de 18 à 25 points du gagné sont gagnés **après le
  dernier marchand visité** (or des étapes qui suivent, dont les 75–85 po de Nefarian, jamais dépensables, et l'or en
  poche d'une expédition qui meurt avant le marchand suivant). Le bot dépense 75 à 95 % de sa bourse à chaque visite :
  ce reste ne dépend pas des prix, seulement de la fréquence des marchands.
- **Articles par visite** : 2 à 3 articles abordables tout débloqué (2,9 à Duskwood, 2,1 à Blackrock Mountain ; 3,4 à
  6,9 avant) ; 3,6 à 4,4 au compte neuf, dont l'étal se vide de bibelots (palier commun 0 : 9 articles par étal à
  partir des Swamp of Sorrows, sans bibelot, au lieu de 12–13). Le bot en achète 1,4 à 2,4 (plus les retraits).
  **L'étal entier n'est plus jamais achetable** (0 % des visites, 0,5 % aux Swamp of Sorrows au compte neuf ; jusqu'à
  77 % avant).
- **Taux de victoire** : aucun effet hors de l'erreur de mesure (± 4 points) : Westfall identique, zones 2 à 7 à
  ± 1,2 point par zone en moyenne ; victoires de campagne −2,5 à +4,2 selon la classe (Mage +4,1 et Hunter −2,5 au compte neuf,
  Rogue +4,2 tout débloqué). Le joueur achète moins d'articles, mais plus forts (rares, améliorés).

**Essais écartés et propositions** (hors du changement, à décider par le joueur) :
- *Plus de marchands sur les cartes des zones 2 à 7* (poids du marchand ×2,5, essai sur le Warrior, 300 expéditions) :
  visites 0,61 → 0,69 par zone, or inutilisé −0,1 à −0,9 point seulement (au plus un marchand par chemin, et le bot
  `human` ne voit que quelques étapes devant lui). Écarté.
- *Pas d'or sur la récompense de Nefarian* (inutilisable par construction) : ≈ −4 à −6 points pour les victoires
  (19–22 → ≈ 17–19 %), sans effet de jeu ; non fait (la récompense finale perdrait sa ligne d'or).
- *Un marchand sur l'écran entre deux zones* (proposition) : une visite assurée par zone ramènerait l'or gagné après le
  dernier marchand à celui de la fin de Blackrock Mountain (≈ 10–12 % du gagné) ; à voir avec l'écran entre deux zones.
- Baisser les gains d'or par zone ne change pas la part inutilisée (elle suit la part gagnée après le dernier marchand) :
  non proposé.

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
(±10 %), cartes neutres 45/65/100, prix de Westfall multipliés selon le rang de la zone (`PRICE_BY_ZONE`, ×1 à ×2,2) et
×1,25 pour une carte vendue améliorée (« Économie sur sept zones ») ; retrait 75 po puis +25 (sans multiplicateur de zone) ;
marchand 5 cartes + 1 neutre, 3 bibelots, 3 potions ; repos 30 % ;
2 premiers combats de l'acte dans le groupe `easy` ; rareté des cartes (commune/inhabituelle/rare, zone 1)
combat 60/33/7, élite 45/40/15, marchand 50/37/13, boss que des rares ; part de rares multipliée par zone
(`RARE_BY_ZONE`, « Cartes épiques »).

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
  l'expédition (75, 100, 125…) ; il ne suit pas le multiplicateur de prix des zones (15/11/2026, « Économie sur sept
  zones »).
- **Rencontres** : les PV perdus ne tuent jamais (plancher à 1 PV, PV max au moins 1) ; une
  rencontre déjà vue ne revient pas dans la même expédition ; si aucune n'est disponible, l'étape
  est « rien à signaler ». Familles, conditions, paris et histoires : `docs/rencontres.md`.
- **Ligue des explorateurs supprimée** (13/11/2026) : remplacée par la campagne par zones
  (`docs/zones.md`).
- **Niveau de classe** (12/11/2026, formule revue le 13/11/2026) : seuils 100 / 250 / 450 / 700 / 1 000 /
  1 400 ; expérience = 5 par étape, 6 par élite, 15 par boss, +15 pour une victoire, ×(1 + 0,15 × clé) :
  2 expéditions pour le niveau 2, ≈ 20 pour le 7 (voir « Niveau de classe »).
- **Clés** : une par classe pour toute l'expédition (`cs.keyMax`, 14/11/2026) ; jouer une clé inférieure reste
  possible.
- **Affixes** : intensités ajustées (voir tableau ; recalées le 12/11/2026 après l'équilibrage des cinq classes, `docs/equilibrage.md`) pour ≈ −5 points par niveau ; Galvanisant
  n'affecte pas les boss (sinon chaque sbire tué de VanCleef le rendait injouable), Nécrotique
  arrondit au plus proche (l'arrondi par défaut annulait les soins de 2 d'Expiation dès le 1er coup).
- **Bibelot au choix sans bibelot à proposer** : si la réserve est vide, la phase `start` est sautée.

## Mesures de la campagne continue (14/11/2026, clé 0, 1 000 expéditions, graine 1)

`luajit Sim/sim.lua runs=1000 bot=<bot> jobs=8 runner=expedition key=0 zones=<z> level=<l> class=<c>` ;
`zones=0 level=2` = compte presque neuf (aucune épique débloquée : colonne épique à 0), `zones=7 level=7` = tout
débloqué. Aucun nombre d'équilibrage changé : les zones 2 à 7 avaient été réglées pour un deck neuf ; un deck
qui a traversé les zones précédentes (15 à 45 cartes, PV max en hausse, épique) les passe presque toujours. Cellule
« a→b (c) » : a = % des expéditions qui atteignent la zone, b = % qui battent son boss, c = b / a. Tableau
« entrée de zone » : PV / PV max · taille du deck (· part avec une épique) à l'entrée, après le soin du passage.
Intervalle ≈ ±3 points.

**`bot=human`, `zones=0 level=2`** — battue / atteinte (taux conditionnel) par zone ; victoires = Nefarian

| Classe | WF | DW | WL | STV | SoS | BS | BRM | Victoires | XP / exp. | étapes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Priest | 100→74 (74) | 74→68 (93) | 68→61 (90) | 61→60 (98) | 60→55 (92) | 55→53 (95) | 53→42 (81) | 42.4 % | 286 | 36.9 |
| Warrior | 100→72 (72) | 72→66 (91) | 66→64 (96) | 64→62 (98) | 62→62 (100) | 62→62 (100) | 62→62 (100) | 61.8 % | 302 | 38.3 |
| Mage | 100→70 (70) | 70→54 (77) | 54→46 (85) | 46→39 (86) | 39→38 (98) | 38→37 (97) | 37→34 (92) | 33.9 % | 225 | 29.4 |
| Rogue | 100→68 (68) | 68→48 (71) | 48→39 (82) | 39→32 (81) | 32→30 (94) | 30→29 (97) | 29→25 (86) | 25.0 % | 197 | 26.1 |
| Hunter | 100→69 (69) | 69→56 (80) | 56→46 (82) | 46→36 (78) | 36→32 (90) | 32→31 (97) | 31→27 (87) | 27.2 % | 217 | 28.6 |

| Classe (entrée de zone) | WF | DW | WL | STV | SoS | BS | BRM |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Priest | 36/36 · 10 | 32/37 · 16 | 38/40 · 21 | 37/42 · 27 | 42/44 · 32 | 44/45 · 37 | 44/45 · 42 |
| Warrior | 74/74 · 10 | 54/75 · 16 | 65/77 · 21 | 68/79 · 27 | 70/82 · 32 | 78/82 · 38 | 80/82 · 43 |
| Mage | 42/42 · 10 | 33/43 · 16 | 38/46 · 21 | 40/48 · 27 | 40/50 · 33 | 45/50 · 38 | 47/50 · 43 |
| Rogue | 50/50 · 10 | 42/51 · 16 | 46/54 · 21 | 49/56 · 26 | 50/58 · 32 | 54/58 · 37 | 53/58 · 42 |
| Hunter | 50/50 · 10 | 37/51 · 15 | 43/53 · 20 | 44/56 · 26 | 43/58 · 30 | 48/58 · 35 | 53/59 · 39 |

**`bot=human`, `zones=7 level=7`** — battue / atteinte (taux conditionnel) par zone ; victoires = Nefarian

| Classe | WF | DW | WL | STV | SoS | BS | BRM | Victoires | XP / exp. | étapes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Priest | 100→83 (83) | 83→78 (94) | 78→76 (96) | 76→74 (98) | 74→71 (96) | 71→71 (99) | 71→67 (94) | 66.7 % | 344 | 43.5 |
| Warrior | 100→91 (91) | 91→88 (96) | 88→87 (99) | 87→86 (99) | 86→86 (100) | 86→86 (100) | 86→86 (100) | 86.4 % | 396 | 49.5 |
| Mage | 100→85 (85) | 85→79 (93) | 79→78 (98) | 78→76 (98) | 76→76 (100) | 76→76 (100) | 76→76 (100) | 76.0 % | 357 | 44.8 |
| Rogue | 100→78 (78) | 78→65 (83) | 65→62 (96) | 62→60 (96) | 60→59 (98) | 59→59 (100) | 59→59 (100) | 58.9 % | 296 | 37.7 |
| Hunter | 100→84 (84) | 84→77 (92) | 77→75 (98) | 75→72 (97) | 72→71 (98) | 71→71 (100) | 71→71 (100) | 71.1 % | 343 | 43.2 |

| Classe (entrée de zone) | WF | DW | WL | STV | SoS | BS | BRM |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Priest | 36/36 · 10 · 0 % | 32/36 · 16 · 29 % | 36/37 · 22 · 55 % | 36/38 · 28 · 77 % | 37/38 · 34 · 90 % | 38/39 · 39 · 97 % | 39/40 · 44 · 99 % |
| Warrior | 74/74 · 10 · 0 % | 60/74 · 16 · 28 % | 68/75 · 22 · 55 % | 72/75 · 28 · 77 % | 73/76 · 34 · 91 % | 76/76 · 40 · 96 % | 77/77 · 45 · 99 % |
| Mage | 42/42 · 10 · 0 % | 35/42 · 16 · 28 % | 38/43 · 22 · 55 % | 40/44 · 28 · 78 % | 39/44 · 34 · 90 % | 42/44 · 39 · 96 % | 44/45 · 45 · 99 % |
| Rogue | 50/50 · 10 · 0 % | 42/50 · 16 · 29 % | 44/51 · 22 · 54 % | 47/52 · 28 · 78 % | 48/52 · 33 · 91 % | 52/53 · 39 · 97 % | 53/53 · 44 · 98 % |
| Hunter | 50/50 · 10 · 0 % | 39/50 · 16 · 28 % | 44/51 · 22 · 56 % | 47/51 · 27 · 76 % | 45/52 · 33 · 90 % | 49/52 · 38 · 96 % | 52/53 · 44 · 99 % |

**`bot=heuristic`, `zones=0 level=2`** — battue / atteinte (taux conditionnel) par zone ; victoires = Nefarian

| Classe | WF | DW | WL | STV | SoS | BS | BRM | Victoires | XP / exp. | étapes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Priest | 100→97 (97) | 97→96 (99) | 96→96 (100) | 96→96 (100) | 96→94 (98) | 94→94 (100) | 94→90 (96) | 89.9 % | 433 | 53.7 |
| Warrior | 100→96 (96) | 96→96 (100) | 96→96 (100) | 96→96 (100) | 96→96 (100) | 96→96 (100) | 96→96 (100) | 95.8 % | 436 | 54.0 |
| Mage | 100→93 (93) | 93→88 (95) | 88→86 (97) | 86→83 (97) | 83→82 (99) | 82→81 (99) | 81→78 (96) | 77.7 % | 388 | 48.7 |
| Rogue | 100→96 (96) | 96→92 (96) | 92→86 (94) | 86→85 (98) | 85→83 (98) | 83→82 (99) | 82→78 (94) | 77.6 % | 395 | 49.5 |
| Hunter | 100→94 (94) | 94→93 (98) | 93→92 (100) | 92→89 (96) | 89→88 (99) | 88→88 (100) | 88→88 (100) | 87.9 % | 413 | 51.4 |

| Classe (entrée de zone) | WF | DW | WL | STV | SoS | BS | BRM |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Priest | 36/36 · 10 | 35/37 · 16 | 39/39 · 21 | 41/42 · 27 | 43/44 · 32 | 44/44 · 36 | 44/44 · 40 |
| Warrior | 74/74 · 10 | 66/75 · 16 | 74/77 · 21 | 77/80 · 27 | 77/82 · 32 | 81/82 · 36 | 82/82 · 41 |
| Mage | 42/42 · 10 | 38/43 · 16 | 41/45 · 21 | 44/48 · 27 | 42/50 · 32 | 47/50 · 36 | 48/50 · 40 |
| Rogue | 50/50 · 10 | 45/51 · 16 | 47/53 · 21 | 50/56 · 26 | 52/58 · 31 | 56/58 · 35 | 54/58 · 40 |
| Hunter | 50/50 · 10 | 43/51 · 14 | 50/53 · 17 | 52/56 · 21 | 49/58 · 24 | 54/58 · 26 | 57/58 · 29 |

**`bot=heuristic`, `zones=7 level=7`** — battue / atteinte (taux conditionnel) par zone ; victoires = Nefarian

| Classe | WF | DW | WL | STV | SoS | BS | BRM | Victoires | XP / exp. | étapes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Priest | 100→98 (98) | 98→97 (99) | 97→96 (99) | 96→95 (99) | 95→92 (96) | 92→91 (99) | 91→88 (97) | 88.3 % | 429 | 53.3 |
| Warrior | 100→99 (99) | 99→98 (100) | 98→98 (100) | 98→98 (100) | 98→98 (100) | 98→98 (100) | 98→98 (100) | 98.1 % | 446 | 55.1 |
| Mage | 100→98 (98) | 98→98 (99) | 98→97 (100) | 97→97 (100) | 97→97 (100) | 97→97 (100) | 97→97 (100) | 97.0 % | 442 | 54.7 |
| Rogue | 100→98 (98) | 98→95 (97) | 95→94 (99) | 94→94 (100) | 94→94 (100) | 94→94 (100) | 94→94 (100) | 93.7 % | 430 | 53.3 |
| Hunter | 100→97 (97) | 97→96 (99) | 96→96 (100) | 96→96 (99) | 96→95 (99) | 95→95 (100) | 95→95 (100) | 94.9 % | 435 | 54.0 |

| Classe (entrée de zone) | WF | DW | WL | STV | SoS | BS | BRM |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Priest | 36/36 · 10 · 0 % | 35/36 · 16 · 29 % | 37/37 · 22 · 56 % | 37/38 · 28 · 80 % | 37/38 · 33 · 92 % | 39/39 · 39 · 97 % | 39/40 · 44 · 99 % |
| Warrior | 74/74 · 10 · 0 % | 70/74 · 16 · 28 % | 73/75 · 22 · 55 % | 75/75 · 28 · 80 % | 75/76 · 34 · 92 % | 76/77 · 39 · 97 % | 77/77 · 45 · 99 % |
| Mage | 42/42 · 10 · 0 % | 39/42 · 16 · 28 % | 41/43 · 22 · 54 % | 42/43 · 28 · 78 % | 41/44 · 34 · 91 % | 44/44 · 39 · 97 % | 45/45 · 44 · 99 % |
| Rogue | 50/50 · 10 · 0 % | 46/50 · 16 · 29 % | 47/51 · 22 · 55 % | 49/51 · 27 · 78 % | 50/52 · 33 · 91 % | 52/52 · 38 · 96 % | 53/53 · 43 · 99 % |
| Hunter | 50/50 · 10 · 0 % | 43/50 · 15 · 29 % | 47/51 · 20 · 54 % | 49/51 · 26 · 78 % | 48/52 · 31 · 91 % | 51/52 · 36 · 97 % | 53/53 · 40 · 99 % |

Lecture :
- **Westfall et Duskwood font l'essentiel du tri** (bot `human`, compte neuf : 26 à 32 % des expéditions meurent
  à Westfall, surtout contre VanCleef ; Duskwood en retire encore 6 à 20 points) ; à partir des Swamp of Sorrows,
  le deck de campagne passe à 90–100 %. Blackrock Mountain retire encore 0 à 11 points (Nefarian ; 11 au Priest).
  Le Warrior ne perd plus rien après les Wetlands (PV à l'entrée ≈ 80/82).
- Le bot `heuristic` traverse presque tout (78 à 96 % au compte neuf, 88 à 98 % tout débloqué) : à régler zone par
  zone d'après ces lignes (lot d'équilibrage à venir, `docs/zones/decisions.md`, « Courbe de difficulté »).
- L'épique arrive en route : 28 % à l'entrée de Duskwood, 55 % aux Wetlands, 78 % à Stranglethorn, > 90 % ensuite
  (tout débloqué).

**Expérience et niveau 7** (seuils inchangés : 1 400 au niveau 7). Une expédition rapporte maintenant
≈ 7,7 à 8 d'expérience par étape franchie (contre ≈ 9,6 quand une zone faisait une expédition : moins de
bonus de victoire par étape) et beaucoup plus d'étapes : bot `human` au compte neuf 197 à 302 par expédition
(26 à 38 étapes), tout débloqué 297 à 396 ; bot `heuristic` 388 à 446. **Niveau 7 en ≈ 6 expéditions typiques**
pour un joueur humain qui commence (1 400 / 245 en moyenne des cinq classes : 4,6 Warrior à 7,1 Rogue ; 3,5 à 4,7
une fois tout débloqué ; 3,1 à 3,6 au bot heuristique), soit ≈ 180 étapes (≈ 150 avant, en ≈ 20 expéditions
d'une zone). Niveau 2 dès la première expédition.

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
