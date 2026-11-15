# Cartes neutres

> **13/11/2026** : la Ligue des explorateurs est supprimée (`docs/zones.md`). Le champ `tier` est gardé : le
> « palier de Ligue » N de ce document se lit maintenant « première victoire du compte dans la zone d'ordre N »
> (0 = d'emblée) ; le champ `act = 1` des rencontres est devenu `zone = "westfall"`.

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
| `goblin_sapper_charge` | Goblin Sapper Charge | Engineering | rare | 2 | Attack | Exhaust | Pay 5 HP. / Deal 14 to all. | Pay 5 HP. / Deal 18 to all. | `spell_fire_selfdestruct` | 3 Revered |

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

- `Pay 5 HP.` (Goblin Sapper Charge, décision commune du 12/11/2026 : une seule formulation pour une perte
  de PV sur une carte) : coût en première ligne, payé au jeu (champ `payHp`), ignore l'Absorb, n'est pas une
  attaque ; la carte est injouable s'il ferait tomber à 0 (raison « Not enough HP to pay. »). La première
  version écrivait « Lose 5 HP. » comme un effet (`minHp`, `loseHp`), retiré.
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
| `moonbrook_refugees` Les réfugiés de Ruisselune (1) | « Rouler des bandages avec Verna Furlbrow » : -4 PV, Heavy Silk Bandage | `heavy_silk_bandage` | les secours aux blessés |
| `goblin_peddler` Le profiteur défias (1, rare) | 4e réponse : paie 35 po, Iron Grenade | `iron_grenade` | un marchand défias (le matériel des mines) |
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
- Coût `payHp` (« Pay N HP. ») porté par une carte neutre.
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
- Moteur : Goblin Sapper Charge porte `payHp = 5` (« Pay 5 HP. », coût commun) ; `minHp`, la raison `lowHp`
  et le mot « Lose N HP » sont retirés ; le harnais (U27) refuse toute clause « Lose N HP ».
- Elixir of Superior Defense : « Start of turn: » (déclencheur du registre) au lieu de « Turn start: ».
- Druid : la carte de soin n'a pas le mot `Caster` (classe non codée).
- Corps : ivoire teinté vert sauge (`Art.cardBodyTint`), quel que soit le premier effet (Rugged Armor
  Kit n'est pas bleue) ; infobulle : ligne « Neutral: a card that every class can use. ».
- Pas faits : écran de progression de la Ligue avec les cartes verrouillées (l'écran méta est refondu
  en parallèle) ; balayage `sweep=cards` des neutres (le balayage ne force que les cartes de la classe).
- Bot : achète une carte neutre notée 6 ou plus (Heavy Silk Bandage, Iron Grenade, Elixir, Black Lotus,
  Sapper) ; une réponse `card` vaut 1,2.

## Paliers +2 et +3 (15/11/2026)

Décision du joueur du 15/11/2026 (`docs/ameliorations.md`) : une carte s'améliore jusqu'à trois fois, paliers 2 et
3 écrits à la main. Les 22 cartes neutres (les dix de `Data/Neutral.lua` et les deux de chaque zone, déclarées
dans `Data/Zones/<Zone>.lua`) ont leurs paliers 2 et 3. Base et palier 1 inchangés.

Règles suivies, propres aux neutres :
- **Bas de la fourchette** : chaque palier 2 ou 3 vaut environ la moitié du gain du palier 1 ; une neutre +3 reste
  sous la carte de classe repère à son palier 1 (Battle Shout, Recklessness, Flash Heal, Adrenaline Rush, Silence,
  Wailing Arrow, Ice Barrier…).
- **Consommables** : la plupart des neutres sont Exhaust. Aucun palier ne retire Exhaust ; les paliers donnent
  plutôt **Retain** (garder la bombe ou la potion pour le bon tour), **Innate** (la nourriture, l'élixir, l'huile
  préparés avant le combat), un coût ou un prix en PV assoupli, ou un nombre.
- **Cartes à 0 et pioche** (Arcane Bomb, Black Lotus, Anti-Venom, Zombie Juice, Jungle Remedy, Runecloth Bag+) :
  jamais de pioche ni de mana en plus ; seulement des mots de plaque ou un petit effet sans pioche.
- **Étourdissements** (Iron Grenade, Dark Iron Bomb) : jamais plus de Stunned ; Retain et dégâts seulement.
- Elixir of Superior Defense (seul Power) : sa valeur par tour ne change pas (4 Absorb) ; coût 0 puis Innate ;
  `Bots.POWER_VALUE` inchangé.
- Textes : les mots de plaque (Exhaust, Retain, Innate) ne prennent pas de place dans le corps de la carte ; seul
  Jungle Remedy reste à 5 lignes de corps (taille 9, comme à la base).

| Carte | Base | +1 | +2 | +3 |
| --- | --- | --- | --- | --- |
| Rough Dynamite (1) | Deal 6 to all. Exhaust | Deal 9 to all | Deal 11 to all | + Retain |
| Heavy Silk Bandage (1) | Heal 6. Exhaust | Heal 9 | Heal 11 | + Gain Regen 2 |
| Rugged Armor Kit (1) | Gain 4 Absorb. Retain | 7 Absorb | 9 Absorb | + Innate |
| Smoked Desert Dumplings (1) | Gain Strength 1. Exhaust | Strength 2 | + Gain Regen 2 | + Innate |
| Runecloth Bag (1) | Draw 2. Exhaust | coût 0 | + Innate | + Retain |
| Iron Grenade (1) | Deal 5, Stunned 1. Exhaust | Deal 8 | + Retain | Deal 10 |
| Arcane Bomb (0) | Interrupt the target. Exhaust | + Draw 1 | + Retain | Interrupt all casts |
| Elixir of Superior Defense (1, Power) | 3 Absorb par tour | 4 Absorb | coût 0 | + Innate |
| Black Lotus (0) | +2 mana. Exhaust | + Draw 1 | + Retain | + Innate |
| Goblin Sapper Charge (2) | Pay 5 HP, 14 to all. Exhaust | 18 to all | Pay 3 HP | 20 to all |
| Anti-Venom (0, Duskwood) | Remove negative effects, Draw 1. Exhaust | Draw 2 | + Retain | + Heal 4 |
| Zombie Juice (0, Duskwood) | +1 mana, Draw 1. Exhaust | Draw 2 | + Retain | + Innate |
| Crocolisk Gumbo (1, Wetlands) | Heal 5, Strength 1. Exhaust | Heal 8 | Heal 10 | coût 0 |
| Fire Oil (1, Wetlands) | DoT 4 to all. Exhaust | DoT 6 | DoT 7 | + Innate |
| Jungle Remedy (0, Stranglethorn) | Restore Hexed, remove negative effects, Draw 1. Exhaust | Draw 2 | + Retain | + Innate |
| Rumsey Rum Black Label (0, Stranglethorn) | Gain 6 Absorb. Exhaust | 9 Absorb | + Retain | 11 Absorb |
| Dream Dust (1, Swamp) | Asleep 2. Exhaust | coût 0 | Asleep 3 | + Retain |
| Dreamless Sleep Potion (0, Swamp) | Heal 10, lose all mana. Exhaust | Heal 14 | Heal 16 | + Retain |
| Fire Protection Potion (1, Steppes) | Douse 3, 6 Absorb. Exhaust | 9 Absorb | 11 Absorb | + Retain |
| Thorium Grenade (2, Steppes) | Deal 10 to all. Exhaust | 13 to all | 15 to all | + Sundered 1 to all |
| Dark Iron Bomb (2, Blackrock) | Deal 4 to all, Stunned 1 to all. Exhaust | 8 to all | 10 to all | + Retain |
| Dark Iron Ale Mug (0, Blackrock) | Pay 3 HP, Strength 2. Exhaust | Pay 2 HP | Pay 1 HP | + Innate |

« + » = ajouté au palier précédent ; (n) = coût de base.

**Cartes de combat sans palier 2 / 3** : les cinq Curses de Duskwood (`rabies`, `curse_of_weakness`, `web`,
`fevered_plague`, `curse_of_tongues`), `morbents_bane` et `hexed` (Stranglethorn) ont un `up` factice (même texte,
« jamais améliorée : hors du deck ») ; elles n'entrent jamais dans le deck de l'expédition et un palier 2 identique
serait refusé par `Sim/upgrades.lua` (« rien ne change »). `lua5.1 Sim/upgrades.lua list=1` les liste dans le
groupe « other » : c'est attendu.

Mesure : non faite carte par carte (balayages arrêtés sur consigne) ; campagne Mage inchangée (74,8 %), aucun palier 2
atteint par le bot (`docs/equilibrage.md`, « Paliers +2 et +3 des cartes neutres »).

Tests : `Sim/tests_zone_<zone>.lua` (« paliers neutres : … ») ; les neutres de `Data/Neutral.lua` sont testées dans
`Sim/tests_zone_duskwood.lua` (coût 0, Innate, Retain, Interrupt all casts, Regen, prix en PV).
