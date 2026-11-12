# Cartes neutres

Décision du GDD des classes (11 novembre 2026) : une dizaine de cartes neutres, tirées des métiers et
des objets de WoW, offertes à toutes les classes, **chez le marchand et dans les rencontres
seulement**, jamais en récompense de combat. Elles se débloquent par la réputation de la Ligue des
explorateurs, commune au compte. Textes affichés en anglais, écrits dans le langage des cartes
(`docs/interface.md`) ; l'état de dégâts sur la durée s'appelle DoT.

## Règles de conception

- **Aucune ressource de classe** : ni Insanity, Rage, Combo Points, forme, Seal, etc. ; aucun état
  propre à une classe (Atonement, Parry, Stealth…). Seulement Absorb, DoT, Regen, Strength, Sundered,
  Demoralized, Stunned, mana, pioche et les mots de plaque communs.
- **Utiles aux neuf classes** : défense, pioche, mana, dégâts de zone, contrôle, Interrupt, un peu de
  soin (pour les classes qui n'en ont pas).
- **Jamais meilleures qu'une carte de classe de même coût** : chaque carte est comparée à son repère
  Priest (ou Druid) ; la plupart sont Exhaust, l'avantage d'une carte neutre est d'exister dans
  n'importe quel deck, pas d'être plus forte.
- **Druid** : une carte neutre qui soigne porte le mot `Caster` pour lui (règle suivant l'effet,
  `docs/classes/druid.md`, règle 5).

## Les dix cartes

| Id | Nom (objet ou sort) | Métier | Rareté | Coût | Type | Plaque | Texte | Amélioré | Icône | Palier de Ligue |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `rough_dynamite` | Rough Dynamite | Engineering | common | 1 | Attack | Exhaust | Deal 6 to all. | Deal 9 to all. | `inv_misc_bomb_06` | 0 Neutral |
| `heavy_silk_bandage` | Heavy Silk Bandage | First Aid | common | 1 | Skill | Exhaust | Heal 6. | Heal 9. | `inv_misc_bandage_02` | 0 Neutral |
| `rugged_armor_kit` | Rugged Armor Kit | Leatherworking | common | 1 | Skill | Retain | Gain 4 Absorb. | Gain 7 Absorb. | `inv_misc_armorkit_09` | 0 Neutral |
| `smoked_desert_dumplings` | Smoked Desert Dumplings | Cooking | uncommon | 1 | Skill | Exhaust | Gain Strength 1 | Gain Strength 2 | `inv_misc_food_64` | 0 Neutral |
| `runecloth_bag` | Runecloth Bag | Tailoring | common | 1 | Skill | Exhaust | Draw 2. | (coût 0) | `inv_misc_bag_13` | 1 Friendly |
| `iron_grenade` | Iron Grenade | Engineering | uncommon | 1 | Attack | Exhaust | Deal 5. / Apply Stunned 1 ⌛ | Deal 8. / Apply Stunned 1 ⌛ | `inv_misc_bomb_08` | 1 Friendly |
| `arcane_bomb` | Arcane Bomb | Engineering | uncommon | 0 | Skill | Exhaust | Interrupt the target's cast. | Interrupt the target's cast. / Draw 1. | `inv_misc_bomb_04` | 2 Honored |
| `elixir_of_superior_defense` | Elixir of Superior Defense | Alchemy | uncommon | 1 | Power | — | Turn start: gain 3 Absorb. | Turn start: gain 4 Absorb. | `inv_potion_86` | 2 Honored |
| `black_lotus` | Black Lotus | Herbalism | rare | 0 | Skill | Exhaust | +2 mana. | +2 mana. / Draw 1. | `inv_misc_herb_blacklotus` | 3 Revered |
| `goblin_sapper_charge` | Goblin Sapper Charge | Engineering | rare | 2 | Attack | Exhaust | Deal 14 to all. / Lose 5 HP. | Deal 18 to all. / Lose 5 HP. | `spell_fire_selfdestruct` | 3 Revered |

Comptes : 4 communes, 4 inhabituelles, 2 rares ; paliers 0 / 1 / 2 / 3 : 4 / 2 / 2 / 2. Cibles :
Rough Dynamite, Iron Grenade et Arcane Bomb visent un ennemi ou tous ; les autres se jouent sur soi.

### Repères (même coût)

| Carte neutre | Repère de classe | Pourquoi elle n'est pas meilleure |
| --- | --- | --- |
| Rough Dynamite 6 à tous, Exhaust | Holy Nova 4 à tous + Regen 2 (Priest, commune) | une fois par combat |
| Heavy Silk Bandage, soigne 6, Exhaust | Flash Heal, soigne 7 + Draw 1, Exhaust | moins de soin, pas de pioche |
| Rugged Armor Kit 4 Absorb, Retain | Inner Fire 5 Absorb (départ) | 1 Absorb de moins contre la souplesse du Retain |
| Smoked Desert Dumplings, Strength 1, Exhaust | Bloodthirst (Warrior, GDD) : 6 dégâts, soin 2, Strength 1 | pas de dégâts ni de soin |
| Runecloth Bag, Draw 2, Exhaust | Evangelism, Draw 2 + Atonement 2, Exhaust | sans état |
| Iron Grenade 5 + Stunned 1, Exhaust | Holy Word: Chastise 7 + Stunned 1, Cooldown 3 | moins de dégâts, une seule fois |
| Arcane Bomb, Interrupt, Exhaust | Silence, Interrupt + Draw 1, Cooldown 2 | une seule fois, sans pioche |
| Elixir of Superior Defense, Power | Rapture (rare) ; Powers inhabituels du Druid | 3 Absorb par tour, sans moteur |
| Black Lotus +2 mana, Exhaust | Innervate (Druid, inhabituelle) +2 / +3 | égale à la base, plus faible améliorée |
| Goblin Sapper Charge 14 à tous, -5 PV | Halo, Cast : 15 à tous + Regen 3 | immédiate mais Exhaust et 5 PV |

### Précisions de règle

- `Lose 5 HP.` : perte de PV sans source (ignore l'Absorb, ne déclenche pas les effets « quand tu es
  touché »), qui ne peut pas tuer : la carte est injouable à 5 PV ou moins (plaque de raison
  `Not enough HP.`). Ce n'est pas le `Pay N HP` du Warlock (coût, première ligne) : c'est un effet.
- `Turn start:` : au début de ton tour, après les tics de DoT et Regen (même tournure que Starfall,
  `docs/classes/druid.md`). L'Absorb gagné dure jusqu'au début du tour suivant.
- `Gain Strength 1` : Strength dure tout le combat (état commun, intensité, sans sablier).

## Où et comment elles apparaissent

### Marchand

- **Un emplacement « Neutral » en plus des 5 cartes de classe** (le marchand passe à 6 cartes), tiré
  parmi les cartes neutres de palier ≤ palier de Ligue (poids de rareté du marchand : 50 / 37 / 13).
  Un emplacement à part garantit qu'une carte neutre ne prend jamais la place d'une carte de classe.
- **Prix** : 45 / 65 / 100 po (commune / inhabituelle / rare, ±10 %), un peu au-dessus des cartes de
  classe (35 / 55 / 90) : elles sont rares à trouver et servent tous les decks ; l'or dort aujourd'hui
  (185 po restants en moyenne, `docs/expedition.md`), il faut des achats qui vaillent la peine.
- Pas de retrait spécial : une carte neutre se retire comme une autre.

### Rencontres existantes qui pourraient en donner

L'effet `{ "card", id }` existe déjà (`Data/Events.lua`) ; une réponse donne une carte neutre précise.

| Rencontre (palier) | Réponse proposée | Carte | Pourquoi là |
| --- | --- | --- | --- |
| `defias_caravan` La carriole renversée (0) | « Fouiller la carriole » : -3 PV, Rough Dynamite | `rough_dynamite` | les Défias font sauter les portes des Mortemines |
| `jangolode_prospector` Le filon de la mine de Jango (0) | « Lui acheter sa dynamite » : paie 20 po, Rough Dynamite (à la place de la flasque, ou en 4e réponse) | `rough_dynamite` | une mine |
| `saldean_farm` La ferme des Saldean (0) | « Apprendre sa recette » : Smoked Desert Dumplings, ou une carte commune parmi 3 (choix gardé) | `smoked_desert_dumplings` | la recette d'une fermière |
| `moonbrook_refugees` Les réfugiés de Ruisselune (1) | « Rouler des bandages avec Mère Hanna » : -4 PV, Heavy Silk Bandage | `heavy_silk_bandage` | les secours aux blessés |
| `goblin_peddler` La roulotte de Grisette (1, rare) | 4e réponse : paie 35 po, Iron Grenade | `iron_grenade` | une marchande gobeline |
| `herbalist` La cueilleuse de pacifiques (1) | « Lui acheter un élixir » : paie 30 po, Elixir of Superior Defense (si débloquée) | `elixir_of_superior_defense` | herboriste et alchimiste |
| `lighthouse_keeper` Le gardien du phare (2) | « Fouiller la réserve du phare » : -6 PV, Arcane Bomb | `arcane_bomb` | réserve de matériel avant le boss |

Une seule réponse (la cueilleuse) vise une carte de palier plus haut que sa rencontre : il faut une
condition nouvelle, `{ "unlocked", id }` (réponse absente tant que la carte n'est pas débloquée, pour
ne pas montrer une réponse grisée sans explication). Les autres respectent déjà « palier de la carte
≤ palier de la rencontre ». Black Lotus et Goblin Sapper Charge restent réservées au marchand.
Chaque réponse ajoutée respecte « rien de gratuit » (`docs/rencontres.md`) : PV, or ou renoncement à
une autre réponse.

## Besoins moteur

- Cartes : `class = "neutral"`, `path = "neutral"`, `tier` (palier de Ligue, comme les bibelots) au lieu
  de `rep`, `noReward = true` (le filtre existe déjà dans `X.cardPool`).
- `X.neutralPool(exp)` et l'emplacement « Neutral » du marchand (`X.SHOP.neutral = 1`, prix
  `X.PRICES.neutral`).
- Effet `{ "loseHp", n }` en combat (perte sans source, non mortelle) avec `canPlay` sur les PV.
- Condition de rencontre `{ "unlocked", id }` ; option `neutral = true` de `cardChoice` si une
  rencontre doit proposer un choix parmi les cartes neutres.
- Interface : voie « Neutral » (médaillon gris), école absente (repli d'icône `Art.schools`), écran de
  progression de la Ligue : les 10 cartes, verrouillées = icône grisée et « Explorers' League:
  Honored ».
- Bot : valeur des cartes Exhaust et de la carte Power neutre ; décision d'achat de l'emplacement
  neutre.

## À mesurer

- Taux d'achat de l'emplacement neutre et or restant en fin d'expédition (cible : l'or dort moins).
- Écart de victoire de chaque carte neutre ajoutée de force au deck de départ (`sweep=cards`), pour
  le Priest puis pour chaque nouvelle classe : aucune ne doit dépasser l'écart de sa carte repère.
- Heavy Silk Bandage pour le Warrior (sans soin) : c'est la carte qui doit le plus compter pour lui.

## État de l'implémentation (12/11/2026)

Faites : `Data/Neutral.lua` (les dix cartes, version améliorée, `ns.NeutralBot.rating` pour les bots),
art et icônes dans `UI/Art/neutral.lua` (icônes de la fiche, embarquées), TOC (`Data\Neutral.lua` après
`Core\Classes\hunter.lua`, `UI\Art\neutral.lua` après `UI\Art\hunter.lua` : relancer le client).

- Champs : pas de `class`, `neutral = true`, `path = "neutral"`, `tier`, `noReward = true` (la fiche
  proposait `class = "neutral"` ; le socle traite déjà « sans classe + neutral » comme carte commune,
  `Card.inClass`). Jamais dans `Expedition.cardPool` ni `Card.pool` (récompenses de combat).
- Marchand : `X.SHOP.neutral = 1`, `X.PRICES.neutral` 45 / 65 / 100 (±10 %), carte neutre en 6e position
  de `exp.shop.cards` (`neutral = true` sur l'article), tirée par `X.neutralPool` (palier de Ligue,
  poids du marchand) ; sans carte neutre débloquée, le marchand garde 5 cartes. Les 5 cartes de classe
  ne tirent plus jamais de neutre.
- Rencontres : les sept réponses de la fiche. Écarts : Saldean = 4e réponse « Ask for her dumplings »
  (la recette « une commune parmi 3 » reste telle quelle) ; Grenaille = 4e réponse (la flasque reste) ;
  Ruisselune : « Roll bandages with her » remplace « Move on » (quatre réponses au plus à l'écran ; une
  issue sans condition reste : la réponse elle-même) ; la cueilleuse : condition `{ "unlocked", id,
  hide = true }` (réponse absente tant que la carte n'est pas débloquée, `X.choiceHidden`).
  `{ "cardChoice", neutral = true }` existe, aucune rencontre ne l'emploie encore.
- Moteur : `minHp = 5` + `{ "loseHp", 5, safe = true }` pour Goblin Sapper Charge (raison `lowHp`,
  « Not enough HP. ») ; mot « Lose N HP » au registre du langage (explication au survol) ; le harnais
  (U27) accepte « Lose N HP. » seulement comme effet (`loseHp` = `minHp`), le coût reste « Pay N HP. ».
- Elixir of Superior Defense : « Start of turn: » (déclencheur du registre) au lieu de « Turn start: ».
- Druid : la carte de soin n'a pas le mot `Caster` (classe non codée).
- Corps : ivoire teinté vert sauge (`Art.cardBodyTint`), quel que soit le premier effet (Rugged Armor
  Kit n'est pas bleue) ; infobulle : ligne « Neutral: a card that every class can use. ».
- Pas faits : écran de progression de la Ligue avec les cartes verrouillées (l'écran méta est refondu
  en parallèle) ; balayage `sweep=cards` des neutres (le balayage ne force que les cartes de la classe).
- Bot : achète une carte neutre notée 6 ou plus (Heavy Silk Bandage, Iron Grenade, Elixir, Black Lotus,
  Sapper) ; une réponse `card` vaut 1,2.
