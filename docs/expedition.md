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
| `shop` | phase `merchant` : `{ cards = { {id, price, sold, neutral?} }, relics = {...}, potions = {...}, removed }` (6e carte `neutral = true` : emplacement « Neutral » ; `removed` = retraits de la visite) ; retrait : `Expedition.removePrice(exp)` (crochet `removePrice`) |
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
  `shop.cards[i].epic = true`), 150 po (± 10 %, crochet `price` genre `"card"`) ; achat = `addCard`.
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
des zones tardives) : dans les récompenses de cartes de combat, d'élite et du marchand (cartes de classe et
emplacement « Neutral »), le poids `rare` de `CARD_WEIGHTS` est multiplié par le facteur du rang de la zone et
pris sur le poids `common` (total inchangé : la part de rares est multipliée d'autant) ;
`Expedition.cardWeights(exp, genre)`. Le boss n'offre que des rares (inchangé) ; les choix de cartes des
rencontres gardent leurs poids. Facteurs proposés, à régler par simulation :

| Rang | 1 Westfall | 2 | 3 | 4 | 5 | 6 | 7 Blackrock |
| --- | --- | --- | --- | --- | --- | --- | --- |
| facteur | 1 | 1,15 | 1,3 | 1,5 | 1,65 | 1,8 | 2 |
| rares, combat (base 7 %) | 7 % | 8,1 % | 9,1 % | 10,5 % | 11,6 % | 12,6 % | 14 % |
| rares, élite (base 15 %) | 15 % | 17,3 % | 19,5 % | 22,5 % | 24,8 % | 27 % | 30 % |
| rares, marchand (base 13 %) | 13 % | 15 % | 16,9 % | 19,5 % | 21,5 % | 23,4 % | 26 % |

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
  l'expédition (75, 100, 125…).
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
