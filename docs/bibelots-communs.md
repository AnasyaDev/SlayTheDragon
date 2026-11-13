# Bibelots communs

> **13/11/2026** : la Ligue des explorateurs est supprimée (`docs/zones.md`). Le champ `tier` est gardé : le
> « palier de Ligue » N de ce document se lit maintenant « première victoire du compte dans la zone d'ordre N »
> (0 = d'emblée) ; le champ `act = 1` des rencontres est devenu `zone = "westfall"`.

Décision du GDD des classes (11 novembre 2026) : une grande table de bibelots, une trentaine de
**communs** (offerts à toutes les classes, débloqués par la Ligue des explorateurs) et **six par
classe** (débloqués par le niveau de classe : `docs/classes/priest-progression.md`,
`docs/classes/druid.md`). Ce document classe les 12 bibelots actuels (`Data/Relics.lua`) et en
propose 20 nouveaux, soit 32 communs.

« Commun » désigne ici le partage entre classes ; la **rareté** (common / uncommon / rare / boss) est
celle des tirages (`X.RELIC_WEIGHTS`, prix 90 / 120 / 160 / 220 po). Palier de Ligue : 0 Neutral,
1 Friendly, 2 Honored, 3 Revered (`Meta.LEVELS`).

Règle de tri : un bibelot commun ne suppose ni soin venant des cartes, ni ressource de classe, ni état
propre à une classe. Il peut s'appuyer sur ce que toutes les classes partagent : mana, pioche,
Absorb, DoT, Strength, Sundered, Demoralized, Stunned, potions, or, feu de camp, marchand, Cast,
Cooldown, Exhaust, Retain, Attack.

## 1. Les 12 bibelots actuels

| Id | Nom | Rareté | Palier | Effet | Classement | Remarque |
| --- | --- | --- | --- | --- | --- | --- |
| `hearthstone` | Cracked Hearthstone | uncommon | 0 | fuir un combat normal ou d'élite, une fois par expédition | commun | |
| `defias_purse` | Defias Purse | uncommon | 0 | +25 % d'or | commun | |
| `linen_bandage` | Linen Bandage | common | 0 | soigne 3 après chaque victoire | commun | le soin vient du bibelot, il n'en suppose aucun |
| `stormwind_tabard` | Stormwind Tabard | common | 0 | 5 Absorb au premier tour | commun | 7 en Bear (Druid) |
| `vancleef_bandana` | VanCleef's Red Bandana | boss | 0 | +1 mana par tour ; ennemis Strength 2 | commun | |
| `faction_insignia` | Insignia of the Alliance / Horde | rare | 1 | retire les états négatifs, une fois par combat | commun | |
| `sharpening_stone` | Coarse Sharpening Stone | uncommon | 1 | Attacks +1 par coup | commun | |
| `focus_talisman` | Talisman of Focus | uncommon | 2 | la 1re interruption subie par combat est sans effet | commun | Cast = mot-clé commun ; faible pour une classe sans Cast (Warrior, Rogue) |
| `camp_kettle` | Camp Kettle | common | 2 | repos +10 PV | commun | |
| `harvest_cog` | Harvest Golem Cog | rare | 0 | pioche 2 de plus au premier tour | commun (rencontre) | `noPool` : donné par le profiteur défias (`goblin_peddler`) |
| `tobin_knife` | Tobin's Pocketknife | rare | 0 | DoT 3 à tous au début du combat | commun (rencontre) | `noPool` ; le DoT est un état commun |
| `mana_ruby` | Mana Ruby | rare | 3 | +1 mana au premier tour | commun | |

**Aucun n'est propre au Priest** : aucun ne lit Insanity, Atonement, Surge ni Regen. Les deux qui
servent surtout le Priest aujourd'hui (Talisman of Focus, Tobin's Pocketknife) reposent sur des
mécaniques que le GDD rend communes (Cast, DoT). Les six bibelots du Priest sont donc tous nouveaux
(`docs/classes/priest-progression.md`).

## 2. Vingt nouveaux bibelots communs

« Nouveau point » = le moteur n'a pas encore le crochet nécessaire (voir section 3) ; sinon le
crochet existant est indiqué.

| Id | Nom | Rareté | Palier | Effet (texte affiché) | Icône | Axe | Façon de jouer encouragée | Crochet |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `scroll_of_intellect` | Scroll of Intellect | common | 0 | `Whenever your draw pile is reshuffled, draw 1 card.` | `inv_scroll_01` | pioche | les petits decks, retirer des cartes chez le marchand | **nouveau point** `onReshuffle` |
| `bloodsail_admirals_hat` | Bloodsail Admiral's Hat | common | 0 | `Elite and boss combats give 20 more gold.` | `inv_helmet_66` | or, élites | prendre les chemins d'élites pour financer le marchand | `run.gold` (source) |
| `herb_pouch` | Herb Pouch | common | 0 | `+1 potion slot.` | `inv_misc_bag_herbpouch` | potions | garder une potion pour le boss sans renoncer aux autres | **nouveau point** (emplacements par expédition) |
| `lifegiving_gem` | Lifegiving Gem | common | 0 | `+8 max HP.` | `inv_misc_gem_pearl_05` | PV | jouer plus serré en combat, la marge est au-dessus | `run.onPickup` |
| `darkmoon_prize_ticket` | Darkmoon Faire Prize Ticket | common | 1 | `The first card removal at each merchant is free.` | `inv_misc_ticket_darkmoon_01` | marchand | affiner le deck, viser les marchands | **nouveau point** (prix du retrait) |
| `head_of_onyxia` | Head of Onyxia | common | 1 | `After each elite combat won, gain a potion.` | `inv_misc_head_dragon_01` | élites, potions | chercher les élites et boire plus librement | `run.onCombatWon` |
| `demonic_rune` | Demonic Rune | common | 1 | `Whenever you play an Exhaust card, gain 3 Absorb.` | `inv_misc_rune_04` | Exhaust | prendre les cartes Exhaust (soins, Black Lotus, grenades) | `onCardPlayed` |
| `brilliant_mana_oil` | Brilliant Mana Oil | uncommon | 1 | `Every third turn, +1 mana.` | `inv_potion_100` | mana | préparer un gros tour aux tours 3, 6, 9 | `onTurnStart` |
| `talisman_of_ephemeral_power` | Talisman of Ephemeral Power | uncommon | 1 | `Cast cards deal 3 more damage per hit.` | `inv_misc_stonetablet_11` | Cast | oser incanter et protéger le sort | `damage` |
| `philosophers_stone` | Philosopher's Stone | uncommon | 2 | `Whenever you drink a potion, gain 6 Absorb.` | `inv_misc_gem_bloodstone_01` | potions, Absorb | boire avant un gros coup plutôt qu'en urgence | `onPotion` |
| `mark_of_the_champion` | Mark of the Champion | uncommon | 2 | `Attacks deal 3 more damage per hit to elites and bosses.` | `inv_trinket_naxxramas02` | élites, boss | decks d'attaques, chemins d'élites | `damage` (cible élite ou boss) |
| `onyxia_scale_cloak` | Onyxia Scale Cloak | uncommon | 2 | `Bosses deal 2 less damage per hit.` | `inv_misc_cape_05` | boss | arriver au boss avec moins de PV en réserve | `enemyDamage` |
| `hourglass_sand` | Hourglass Sand | uncommon | 2 | `Cooldown cards come back 1 turn sooner (minimum 1).` | `inv_misc_dust_02` | Cooldown | decks à Cooldown (PW: Shield, Interrupts) | **nouveau point** (durée du Cooldown) |
| `bag_of_marbles` | Bag of Marbles | rare | 1 | `Start of each combat: apply Stunned 1 to a random enemy that can be Stunned.` | `inv_misc_bag_10_blue` | premier tour | ouvrir fort, tuer un ennemi avant son premier coup | `onCombatStart` |
| `flint_and_tinder` | Flint and Tinder | rare | 2 | `Resting at a campfire also upgrades a random card.` | `inv_tinderbox` | feu de camp | se reposer sans renoncer à l'amélioration | `run.onRest` |
| `force_reactive_disk` | Force Reactive Disk | rare | 2 | `At the start of your turn, keep up to 5 of your Absorb.` | `inv_shield_21` | Absorb | empiler l'Absorb sur deux tours avant un gros coup annoncé | **nouveau point** (remise à zéro de l'Absorb) |
| `travelers_backpack` | Traveler's Backpack | rare | 3 | `At the end of your turn, Retain 1 card of your choice.` | `inv_misc_bag_11` | Retain | garder la bonne carte pour le bon tour (Interrupt, Cast) | **nouveau point** (choix en fin de tour) |
| `hand_of_justice` | Hand of Justice | rare | 3 | `The first Attack you play each combat is played twice.` | `inv_jewelry_talisman_01` | premier tour, Attack | ouvrir par sa plus grosse Attack | **nouveau point** (rejouer une carte) |
| `royal_seal_of_eldre_thalas` | Royal Seal of Eldre'Thalas | boss | 1 | `+1 mana each turn. Campfires heal half as much.` | `inv_jewelry_ring_27` | boss, mana, feu de camp | tout miser sur le combat, renoncer au repos | `maxMana`, `run.restFraction` |
| `drake_fang_talisman` | Drake Fang Talisman | boss | 2 | `At the start of each combat, gain 2 Strength. Enemies gain 6 Absorb.` | `inv_misc_bone_09` | boss, Strength | decks à coups multiples, qui percent l'Absorb ennemi au premier tour | `onCombatStart` |

Précisions :

- **Bloodsail Admiral's Hat** s'ajoute après les autres modificateurs d'or (Defias Purse multiplie
  d'abord) : ordre des bibelots dans `X.modify`, à fixer (fixe après pourcentages).
- **Head of Onyxia** ne donne rien si les emplacements de potion sont pleins (même règle que la
  récompense de combat).
- **Demonic Rune** : l'Absorb suit les règles habituelles (×1,5 en Bear pour le Druid).
- **Brilliant Mana Oil** compte les tours du combat (`c.round` 3, 6, 9…).
- **Bag of Marbles** tire l'ennemi par un flux nommé du combat (`ns.Rng`), jamais `math.random` ;
  Stunned posé avant le premier tour ennemi fait perdre ce tour.
- **Hourglass Sand** : Cooldown 1 reste 1 ; Cooldown 2 devient 1, Cooldown 4 devient 3.
- **Hand of Justice** : la copie se résout tout de suite après l'originale, sur la même cible, sans
  coût ; une Attack Cast est jouée deux fois à sa résolution.
- **Royal Seal** et **Drake Fang Talisman** donnent au tirage de boss trois choix au lieu d'un
  (aujourd'hui le seul bibelot de boss est le Bandeau de VanCleef ; une expédition à plusieurs actes
  n'aurait rien à offrir au deuxième boss).

## Récapitulatif (32 communs)

| | common | uncommon | rare | boss | Total |
| --- | --- | --- | --- | --- | --- |
| Actuels (12) | 3 | 4 | 4 (dont 2 de rencontre) | 1 | 12 |
| Nouveaux (20) | 7 | 6 | 5 | 2 | 20 |
| Total | 10 | 10 | 9 | 3 | 32 |

| Palier de Ligue | Actuels | Nouveaux | Total |
| --- | --- | --- | --- |
| 0 Neutral | 7 (dont 2 de rencontre) | 4 | 11 |
| 1 Friendly | 2 | 7 | 9 |
| 2 Honored | 2 | 7 | 9 |
| 3 Revered | 1 | 2 | 3 |

Axes couverts (bibelots actuels entre parenthèses) : mana (Mana Ruby, Bandana) Brilliant Mana Oil,
Royal Seal ; pioche (Harvest Cog) Scroll of Intellect ; Absorb (Tabard) Force Reactive Disk, Demonic
Rune, Philosopher's Stone ; or (Defias Purse) Admiral's Hat ; feu de camp (Camp Kettle) Flint and
Tinder ; marchand Prize Ticket ; premier tour (Tabard, Ruby, Cog) Bag of Marbles, Hand of Justice ;
élites Admiral's Hat, Head of Onyxia, Mark of the Champion ; boss Onyxia Scale Cloak, Mark of the
Champion, Royal Seal, Drake Fang ; potions Herb Pouch, Philosopher's Stone, Head of Onyxia ; Cast
(Talisman of Focus) Talisman of Ephemeral Power ; Cooldown Hourglass Sand ; Exhaust Demonic Rune ;
Retain Traveler's Backpack ; PV (Linen Bandage) Lifegiving Gem ; DoT (Tobin's Pocketknife).

## 3. Points d'extension nouveaux du moteur

| Point | Bibelot | Où |
| --- | --- | --- |
| `onReshuffle` (notification) | Scroll of Intellect | `Combat.drawCards`, au mélange de la défausse |
| Absorb gardée d'un tour à l'autre (`modify "blockKeep"`, défaut 0) | Force Reactive Disk | `Combat.startPlayerTurn` (`p.block = 0`) |
| Prix du retrait (`run.removePrice`) et compteur par visite | Darkmoon Faire Prize Ticket | `X.removePrice`, état de la visite du marchand |
| Nombre d'emplacements de potion par expédition (`exp.potionSlots`) | Herb Pouch | `X.POTION_SLOTS`, `Combat.new`, sauvegarde (migration) |
| Durée du Cooldown (`modify "cooldown"`) | Hourglass Sand | `afterPlay` dans `Core/Combat.lua` |
| Choix d'une carte à garder en fin de tour | Traveler's Backpack | `Combat.endPlayerTurn` + action d'interface (et choix du bot) |
| Rejouer une carte (copie résolue sans coût) | Hand of Justice | `Combat.resolveCard` ; utile aussi au Windfury Totem du Shaman (GDD) |

Les treize autres utilisent des crochets existants (`docs/expedition.md`, « Contrat avec les bibelots
et potions », et `Core/Combat.lua`).

## 4. À mesurer

- Balayage `sweep=relics loot=0` des 20 nouveaux pour le Priest (référence : Stormwind Tabard +28,1,
  Mana Ruby +26,1, Talisman of Focus +2,3) ; cible : aucun commun au-dessus de +25, aucun au-dessous
  de 0 (Talisman of Focus mis à part, voulu pour les decks de Cast).
- Effet de la dilution : passer de 10 à 30 bibelots tirables change la valeur moyenne d'un bibelot
  d'élite ou de coffre ; remesurer la victoire à la clé 0 (`runner=expedition`) avant et après.
- Or restant en fin d'expédition avec Admiral's Hat et Prize Ticket (aujourd'hui 185 po dorment).
- Bag of Marbles et Hand of Justice : écart sur les combats normaux et sur le boss (immunisé au
  Stunned, mais pas à la double Attack).

## 5. État de l'implémentation (12/11/2026)

Bloc à part en fin de `Data/Relics.lua`, art dans `UI/Art/neutral.lua`, icônes de la fiche embarquées.
**19 bibelots sur 20** : la table commune passe à 31 (12 d'origine + 19), 29 tirables ; 20 sur 20
(32, 30 tirables) avec Traveler's Backpack le 13/11/2026.

- **Ids renommés** : `hand_of_justice` et `force_reactive_disk` sont des bibelots du Guerrier (autres
  effets). Les équivalents communs : `ironfoe` « Ironfoe » (`inv_mace_15`, masse qui donne des attaques
  en plus) et `harm_prevention_belt` « Gnomish Harm Prevention Belt » (`inv_belt_29`, ingénierie).
- **Traveler's Backpack, ajouté le 13/11/2026** (20 sur 20 : 32 communs, 30 tirables) : rare, palier 3,
  « At the end of each turn, 1 chosen card stays in hand. », icône `inv_misc_bag_11`. Crochet
  `retainPicks` (0 par défaut) ; le choix est posé avant la fin du tour par `Combat.markRetain(c, uid)`
  (refusé sans le bibelot, hors du tour du joueur, pour une carte absente ou déjà Retain), lu et effacé
  par `Combat.endPlayerTurn` (journal `retained`) ; sans choix posé, rien n'est gardé. Interface :
  « End Turn » ouvre le choix (`docs/interface.md`, « Écran de combat ») ; bots : `Bots.retainPick` (la
  carte la mieux notée par la classe, +1 améliorée, +0,5 par point de coût), posé par les deux
  simulateurs avant chaque fin de tour. L'action « endTurn » de l'expédition ne porte pas le choix
  (`Core/Expedition.lua` intouché) : à y ajouter (`{ "endTurn", uid }`) si l'on veut la rejouer.
  Les six autres points d'extension sont faits (`docs/classes.md`).
- **Textes impersonnels** (règle du langage) : « Whenever the draw pile is reshuffled… », « Whenever an
  Exhaust card is played… », « Whenever a potion is drunk… », « Up to 5 Absorb carries over to the next
  turn. », « The first Attack played in each combat is played twice. ».
- **Utiles à la classe** (`needs`) : Demonic Rune (exhaust), Talisman of Ephemeral Power (castDamage),
  Mark of the Champion et Ironfoe (attack), Hourglass Sand (cooldown), Harm Prevention Belt (absorb),
  et Talisman of Focus (cast, posé depuis le bloc). Le Rogue n'en reçoit pas trois.
- Précisions de règle : Bloodsail Hat par le crochet `goldBonus` (après Defias Purse, quel que soit
  l'ordre) ; Prize Ticket : le retrait gratuit compte dans la hausse du prix (75 → 100 au suivant) ;
  Head of Onyxia : potion tirée au flux `loot` de l'expédition ; Bag of Marbles : flux `misc` du combat ;
  Flint and Tinder : carte tirée au flux `loot` ; Ironfoe : la première Attack JOUÉE (marquée au jeu,
  même Cast ou Trap) est résolue deux fois, la copie ne déclenche pas Demonic Rune ; Herb Pouch : la
  4e case apparaît au bandeau (cases calées à droite).
- Demonic Rune : la fiche du Warlock (`docs/classes/warlock.md`) prévoit un bibelot de classe du même
  id ; à renommer quand le Warlock sera codé.
