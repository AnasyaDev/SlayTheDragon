# Paliers d'amélioration (+1, +2, +3)

Décision du joueur du 15/11/2026 (`docs/zones/decisions.md`, « Améliorer une carte plusieurs fois ») : une carte
s'améliore **jusqu'à trois fois**, chaque palier **écrit à la main** carte par carte. Une carte dont le palier
suivant n'est pas écrit ne s'améliore pas plus loin. Le socle est en place depuis le 15/11/2026 ; aucune carte
réelle n'a encore de palier 2 ou 3 (ils s'écrivent classe par classe).

## Forme des données

La fiche garde `up` (palier 1, inchangé) et gagne `up2`, `up3`. **Chaque palier ne donne que ce qui change par
rapport au palier précédent** : la fiche effective au palier n est `base ⊕ up ⊕ … ⊕ up_n` (`Card.defById(id, n)`),
champ par champ, une table (`effects`, `hooks`…) remplacée en bloc. Le coût baissé au palier 2 reste donc au
palier 3 sans le répéter.

```lua
card("backstab", {
  level = 1, name = "Backstab", cost = 0, type = "attack", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 3, more = { { 7, "stealth" } } }, { "res", 1 } },
  text = "Deal 3.\n+1 Combo.\nStealth: deal 7 more.",
  up = { effects = { { "damage", 5, more = { { 9, "stealth" } } }, { "res", 1 } },
    text = "Deal 5.\n+1 Combo.\nStealth: deal 9 more." },
  -- exemple : à écrire par la classe, pas encore dans les données
  up2 = { effects = { { "damage", 6, more = { { 11, "stealth" } } }, { "res", 1 } },
    text = "Deal 6.\n+1 Combo.\nStealth: deal 11 more." },
  up3 = { effects = { { "damage", 6, more = { { 11, "stealth" } } }, { "res", 2 } },
    text = "Deal 6.\n+2 Combo.\nStealth: deal 11 more." },
})
```

Règles de forme (contrôlées par `Sim/upgrades.lua`, test « paliers : contrôle des fiches » de `Sim/tests.lua`) :
- **`text` dans chaque palier**, texte complet de la carte à ce palier (même si seul le coût change).
- Pas de palier 3 sans palier 2, ni de palier 2 sans palier 1.
- Champs interdits dans un palier (identité de la carte) : `id`, `name`, `class`, `rarity`, `type`, `path`,
  `level`, `zone`, `tier`, `neutral`, `noReward`, `variant`, `fromZone`, `school`, et les champs posés par le
  socle (`plus`, `isUp`). Tout le reste se remplace (`cost`, `effects`, `cooldown`, `exhaust`, `retain`, `spend`,
  `minRes`, `payHp`, `hooks`, `deckHooks`, `whileInDeck`, nombres propres aux épiques `epicN`…).
- Un palier ne coûte jamais plus que le précédent ; un palier 2 ou 3 change quelque chose.
- Une variante d'épique (`variant = true`) prend le palier de sa carte d'origine, borné à ses propres paliers :
  écrire ses `up2` / `up3` en même temps que ceux de l'originale.

## Instance et socle (`Core/Card.lua`)

- Instance `{ uid, id, up }` : `up = false` (palier 0) ou le palier **1, 2 ou 3** (nombre). `up = true` (forme
  d'avant les paliers, encore écrite par d'anciens tests ou d'autres branches) vaut le palier 1 partout.
- « Améliorée ? » = vérité de `inst.up` (vrai dès le palier 1). **Le palier** se lit par `Card.level(inst)` (ou
  `Card.level(up)`), jamais en comparant `up` à `true`.
- `Card.tiers(id)` (paliers écrits, 0..3), `Card.canUp(id, up)` (palier suivant écrit et < 3),
  `Card.defById(id, n)` (fiche effective : `plus` = palier, `isUp`, nom suivi de `Card.suffix(n)` = `+`, `+2`,
  `+3`), `Card.upValue(n)` (valeur du champ `up`), `Card.new(id, up, uid)`.
- Crochets d'épique (`src.up`) : vrai dès le palier 1. Une épique qui gagne un palier 2 lit
  `Card.level(src)` pour ses nombres (tables `{ base, +1, +2, +3 }` indexées par `Card.level(src) + 1`).

## Règles de l'expédition (`Core/Expedition.lua`)

- `X.canUpgrade(exp, i)` : palier suivant écrit et < 3 ; vaut pour le feu de camp, les rencontres `upgrade`
  (au choix) et `upgradeRandom`, les bibelots (Flint and Tinder : `onRest` → `upgradeRandom`).
- Améliorer monte **d'un palier** ; `stats.upgraded` (toutes) et `stats.upTiers[n]` (celles qui ont atteint n).
- Refus : `X.upgradeRefusal(exp, i)` → `"maxed"` (« Fully upgraded. »), `"noUpgrade"` (« Can't be upgraded. »).
- Tranché « palier 1 » : carte offerte améliorée par une rencontre (`{ "card", id, up = true }`), carte de combat
  donnée améliorée (`{ "addCard", id, up = true }`), conditions « améliorée » (vérité de `up`), carte vendue
  améliorée par le marchand (en cours dans une autre branche : `X.addCard(exp, id, true)` ou `{ id, up = true }`
  dans `shop.cards`, lus comme le palier 1 ; aujourd'hui `buyCard` ajoute la carte de base). Un nombre (`up = 2`) donne ce palier, borné aux
  paliers écrits (`X.addCard`).
- Copie (`dupe`) : même palier. Épique remplacée : ses améliorations sont perdues (`exp.epicReplaced.oldUp`).
- L'épique n'est jamais améliorée au hasard (inchangé).

## Concevoir un palier 2 ou 3

- **Visible et utile** : le joueur doit voir la différence sur la carte (chiffre vert, mot-clé, coût). Un
  palier qui ne change qu'un détail invisible en combat ne vaut pas une visite au feu de camp.
- **Ordre de grandeur** : un palier 2 vaut environ **la moitié à deux tiers du gain du palier 1** (le palier 1
  reste le meilleur achat) ; le palier 3 autant que le palier 2, ou un effet nouveau du même poids. Mesurer
  (ci-dessous) : le gain du palier 2 sur l'expédition ne dépasse pas celui du palier 1.
- **Coût réduit** quand la carte est bonne mais lourde (2 → 1 libère une carte par tour) ; à réserver aux cartes
  qui en ont l'usage, jamais deux fois sur la même carte (0 coût = problème de boucle).
- **Mot-clé** (Retain, Innate, Draw 1, retirer Exhaust) quand un nombre de plus ne change pas la façon de
  jouer la carte ; **un nombre** quand la carte fait déjà ce qu'il faut.
- Garder le texte en deux lignes au plus quand la carte l'est (harnais : textes dans la zone à tous les
  paliers écrits) ; le nom avec `+3` tient sur le ruban pour toutes les cartes (vérifié, harnais UUP).
- Pas de nouveau mot du langage sans le déclarer (`Core/Language.lua`, `docs/classes.md`).

## Mesurer

- `luajit Sim/sim.lua runner=expedition class=<classe> sweep=cards up=2 runs=300 bot=heuristic jobs=8` : chaque
  carte qui a un palier 2 ajoutée de force **à ce palier** (ligne `backstab+2`) ; comparer à `up=1` (même graine)
  donne le gain du palier. `force=backstab+2` force une carte à un palier dans une série ordinaire.
- Le rapport d'une série donne « Améliorations par palier » (+1, +2, +3 par expédition) et les cartes du deck
  final par palier.
- Bots (`Sim/expedition.lua`) : la note d'amélioration (`bot.upgrade[id]`, `byEpic[id].upgrade`) est celle du
  palier 1 ; aux paliers 2 et 3 elle vaut × `SE.UPGRADE_TIER` (0,8 puis 0,6), ou se donne par palier :
  `upgrade = { backstab = { 2.5, 2, 1.5 } }`. Valeur des Powers en combat (`Sim/bots.lua`, `Bots.POWER_VALUE`) :
  `up(inst, base, +1, +2, +3)` pour un Power dont le palier 2 ou 3 change la valeur.

## Tester

- `lua5.1 Sim/upgrades.lua [class=rogue] [list=1]` : paliers écrits par classe, cartes sans palier 2 / 3
  (`list=1`), erreurs de forme (sortie 1 s'il y en a).
- `Sim/tests.lua` (fiches de toutes les cartes ; carte de test `tu_triple` à trois paliers : combat, coût,
  pioche), `Sim/tests_expedition.lua` (feu de camp jusqu'au plafond, rencontres, copie, migration).
- Harnais : `lua5.1 Sim/ui_harness.lua 1 build/snap` (textes de toutes les cartes à tous les paliers écrits,
  section UUP : noms, aperçu du palier suivant, carte au plafond grisée).
- Pour une classe : un test de combat par carte dont un palier change une règle (pas seulement un nombre).

## Interface

- Nom suivi de `+`, `+2`, `+3`, en vert dès le palier 1 ; chiffres qui diffèrent de la carte de base en vert.
- Grille d'amélioration (feu de camp, rencontre) : **toutes** les cartes du deck ; celles qui ne peuvent pas
  monter sont grisées avec leur raison (« Fully upgraded. ») ; survol d'une carte améliorable : son palier
  suivant (chiffres qui changent en vert par rapport au palier actuel), infobulle « Upgraded: » / « Upgraded+2: ».
- Sauvegarde : `Save.VERSION` 7, expédition 9 (`docs/expedition.md`, « Sauvegarde »).
