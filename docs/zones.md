# Campagne par zones (contrat d'une zone)

Décisions du joueur du 13/11/2026. Une expédition se joue dans **une zone** ; la campagne en compte sept,
dans cet ordre :

| Ordre | Id (`ns.Zones`) | Nom affiché | État |
| --- | --- | --- | --- |
| 1 | `westfall` | Westfall | jouable (`Data/Zones/Westfall.lua`, boss Edwin VanCleef ; décors et personnages de la Marche depuis le 13/11/2026) |
| 2 | `duskwood` | Duskwood | déclarée, « Coming later » |
| 3 | `wetlands` | Wetlands | déclarée, « Coming later » |
| 4 | `stranglethorn` | Stranglethorn Vale | déclarée, « Coming later » |
| 5 | `swamp` | Swamp of Sorrows | déclarée, « Coming later » |
| 6 | `steppes` | Burning Steppes | déclarée, « Coming later » |
| 7 | `blackrock` | Blackrock Mountain | déclarée, « Coming later » |

## Registre (`Core/Zones.lua`)

- `ns.Zones[id] = { id, order, name, encounters, scenes }` ; les sept entrées (id, ordre, nom) sont
  déclarées par `Core/Zones.lua` (`ns.Zone.ORDER`). Le fichier de données d'une zone pose `encounters`
  (et facultativement `scenes`) : sans `encounters`, la zone est déclarée mais pas jouable.
- `ns.Zone` : `ORDER`, `FIRST`, `get(id)`, `count()`, `byOrder(n)`, `order(id)`, `name(id)`, `next(id)`,
  `prev(id)`, `playable(id)` (vrai quand `ns.Encounters[zone.encounters].boss` existe).
- Une expédition porte sa zone (`exp.zone`) ; `Expedition.zoneDef(exp)` rend sa définition,
  `Expedition.actName(exp)` son nom (bandeau, carte). Une zone = un acte (`exp.acts = 1`).

## Ajouter une zone (Duskwood par exemple)

1. **Un fichier `Data/Zones/Duskwood.lua`** (Lua 5.1 pur, aucune API WoW), sur le modèle de
   `Data/Zones/Westfall.lua` :
   - ennemis dans `ns.Enemies` (même format que Westfall : `name`, `hp`, `moves`, `pattern` ou `ai`,
     `elite`, `boss`, crochets) ;
   - groupes de combats `ns.Encounters.duskwood = { easy, normal, elite, boss, event_* }` (les deux premiers
     combats de la zone sont tirés dans `easy`) ;
   - rencontres de la zone dans `ns.Events` avec `zone = "duskwood"` (format : `docs/rencontres.md` ; une
     rencontre sans champ `zone` peut sortir dans toutes les zones) ; un combat de rencontre vise un
     groupe `event_*` de la zone ;
   - en dernier, `ns.Zones.duskwood.encounters = "duskwood"` (la zone devient jouable).
2. **Une ligne au TOC**, après `Data\Zones\Westfall.lua` (le TOC fait foi ; `Sim/load.lua` le relit) :
   un nouveau fichier demande de relancer le client, `/reload` ne suffit pas.
3. **L'art** (`UI/Art.lua` ou un `UI/Art/<zone>.lua` ajouté au TOC) : modèles des ennemis
   (`Art.enemies[id]`), personnages des rencontres (`Art.npcs[npc]`), décors (`Art.scenes`, fonds
   embarqués par `tools/build_backgrounds.py`, ou paysages peints `Art.paintings` avec leur palette
   `Art.palettes`). Pour remplacer un décor commun par celui de la zone :
   `ns.Zones.duskwood.scenes = { road = "duskwood_road", mine = "duskwood_crypt" }` (clé : décor commun
   demandé par un écran ou `Controller.scene()`, valeur : clé de `Art.scenes` qui doit exister ;
   `UI.setStage` passe par `Controller.zoneScene`). Westfall le fait depuis le 13/11/2026
   (`Data/Zones/Westfall.lua` : `road`, `hill`, `camp`, `shop`, `night` → `westfall_*`, décors peints
   couleur blé) ; les décors communs `road`… `night` sont ceux de Westfall tant qu'une zone n'a pas les
   siens. Un paysage peint d'une autre zone reprend les plans et accessoires d'`Art.paintings` avec sa
   propre palette (ciel, collines, champs, silhouettes) ou ses propres accessoires (`UI/Scene.lua`, `PROPS`).
4. Facultatif : les **cartes de zone** des classes et les **bibelots de clé** de la zone (ci-dessous).
5. Tests : `Sim/tests_expedition.lua` vérifie que chaque zone référencée par une carte, un bibelot ou une
   rencontre existe ; ajouter au moins une expédition simulée de la zone (`… runner=expedition zone=duskwood`).

Rien d'autre ne change : l'accueil, l'écran Progress et le bilan lisent le registre.

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
