# Duskwood — fiche de conception (zone 2)

Zone 2 de la campagne (`duskwood`), après Westfall, avant Wetlands. Fiche de conception, pas de code : les
chiffres sont ceux de Westfall (`Data/Act1.lua`) multipliés par 1,12 et arrondis, sauf les attaques qui
maudissent (×1,05 : la malédiction est déjà une taxe) ; la simulation les réglera. Textes de jeu en anglais,
dans le langage des cartes de `Data/<Classe>.lua` (mots de plaque dans le texte : `Cooldown 2.`, `Retain.`).

| | |
|---|---|
| Mécanique | **Curse** : des ennemis glissent des cartes nuisibles dans tes piles, pour ce combat seulement. |
| Ce que la zone enseigne | Choisir sa cible (tuer le lanceur lève ses malédictions) et payer tôt plutôt que souvent. |
| Boss | **Morbent Fel** (nécromancien, Tranquil Gardens Cemetery). Stitches passe élite. |
| Difficulté | Westfall + 12 % (PV et dégâts), plus la taxe des malédictions (estimée 1,5 à 2,5 PV par combat). |

## 1. La zone en trois lignes

- **Route** : la route de Raven Hill sous les arbres morts, de Darkshire au cimetière ; **camp** : le camp de
  Sven Yorgen au bord de la route, ou la taverne du Scarlet Raven à Darkshire ; **marchand** : la place de
  Darkshire, sous la tour de la Night Watch.
- **Élites** : Raven Hill Cemetery (Mor'Ladim), le nid d'araignées de Twilight Grove (Naraxis), la route de
  Darkshire où Stitches marche depuis la cabane d'Abercrombie ; Roland's Doom et le tertre de Vul'Gol pour
  les combats de Défias et d'ogres.
- **Boss** : Tranquil Gardens Cemetery, de nuit. Morbent Fel y garde un bouclier impie que seule la
  préparation de Madame Eva (Morbent's Bane) retire.

Décors à ajouter au champ `scene` des rencontres : `town` (Darkshire), `graveyard` (Raven Hill), `woods`
(forêt de nuit, Twilight Grove) ; `camp` et `road` existent.

## 2. La mécanique : Curse

### Règle

1. **Une Curse est une carte ennemie.** Un ennemi l'ajoute à tes piles pendant son tour. Elle n'appartient à
   aucune classe, n'entre jamais dans ton deck d'expédition et disparaît à la fin du combat. Elle garde le nom
   de l'ennemi qui l'a posée (son *lanceur*).
2. **Deux façons d'en recevoir.**
   - **Bite** (attaque marquée) : si un coup de cette attaque te fait perdre des PV, la Curse va dans ta
     **défausse** (une seule Curse par attaque, même à plusieurs coups). Absorb, Parry, Stunned ou un ennemi
     tué avant son tour l'empêchent. L'intention affiche l'attaque et, dessous, la petite icône de la Curse.
   - **Hex** (action propre, intention « Curse ») : la Curse arrive où l'action le dit, **sans condition** :
     défausse, **dessus de la pioche** (tu la piocheras au prochain tour) ou **main** (tu l'as au prochain tour).
     Un Hex porté par une intention Cast peut être interrompu.
3. **S'en débarrasser.** Trois façons, toutes visibles :
   - **La jouer** : payer son coût en mana (ou en PV) ; elle n'a aucun effet et elle est **épuisée**
     (Exhaust). Une Curse « Unplayable » ne se joue pas.
   - **Tuer son lanceur** : à sa mort, toutes les Curses qu'il a posées (main, pioche, défausse) sont
     épuisées. Les Curses du boss durent jusqu'à sa mort, donc tout le combat.
   - **« Remove negative effects. »** (Berserker Rage, Cloak of Shadows, Insignia of the Alliance, les cartes
     de zone) : épuise aussi **les Curses de ta main**. Une carte qui compte « per effect removed » compte
     chaque Curse épuisée ainsi comme un effet.
4. **Effet d'une Curse.** Chacune a une ligne `End of turn:` (se déclenche si elle est dans ta main à la fin
   de ton tour, avant la défausse) ou une ligne `In hand:` (vraie tant qu'elle est dans ta main). Sans
   `Retain.`, elle est défaussée avec la main et reviendra au prochain mélange.
5. **Plafond** : 6 Curses au plus dans tes piles et ta main réunies. Au-delà, l'action d'ajout ne fait rien
   (journal `curse_full`).
6. **Fin du combat** : toutes les Curses disparaissent ; rien n'est reporté.

### Les cinq Curses

| id | Nom | Coût | Texte | Posée par | Où | Icône |
|---|---|---|---|---|---|---|
| `rabies` | Rabies | 1 | Curse. / End of turn: lose 3 HP. | Bite des worgens Nightbane | défausse | `ability_creature_disease_02` |
| `curse_of_weakness` | Curse of Weakness | 1 | Curse. / In hand: Attacks deal 3 less per hit. | Hex (Cast) de Shadow Weaver, Mor'Ladim | dessus de la pioche | `warlock_curse_weakness` |
| `web` | Web | 0 | Pay 2 HP. / Curse. / In hand: draw 1 less each turn. / Retain. | Hex des araignées, Naraxis | main | `spell_nature_web` |
| `fevered_plague` | Fevered Plague | — | Curse. / Unplayable. / End of turn: lose 2 HP. | Hex de Plague Spreader, Bite de Fetid Corpse, Stitches | défausse | `spell_shadow_plaguecloud` |
| `curse_of_tongues` | Curse of Tongues | 2 | Curse. / In hand: your first card each turn costs 1 more. / Retain. | Morbent Fel (boss) | main | `spell_shadow_curseoftounges` |

Ce que chaque Curse demande de décider :
- **Rabies** : 1 mana maintenant pour qu'elle ne revienne jamais, ou 3 PV chaque fois qu'elle est piochée.
  Dans un combat court, la laisser en défausse peut suffire.
- **Curse of Weakness** : la payer **avant** d'attaquer (1 mana sur 3), ou jouer ce tour-là ses Skills et
  garder les Attacks. Les Casts résolus au début du tour partent avant la pioche : la Curse ne les touche pas.
- **Web** : 2 PV contre une carte de moins à chaque tour où elle reste. Gardée (Retain), elle s'accumule.
- **Fevered Plague** : impossible à payer ; la seule réponse rapide est de tuer le Plague Spreader (fragile)
  ou de nettoyer sa main.
- **Curse of Tongues** : 2 mana d'un coup, ou +1 sur la première carte de chaque tour jusqu'à la fin du combat.

### Infobulles (anglais)

| Terme | Infobulle |
|---|---|
| Curse | `Enemy card, for this combat only. Play it to exhaust it.` |
| Lanceur (bas de la carte) | `Lifted when Nightbane Vile Fang dies.` (nom du lanceur) |
| Bite (sous l'intention) | `If this hit costs you HP, adds Rabies to your discard.` |
| Hex (intention Curse) | `Adds Curse of Weakness on top of your draw pile.` |
| End of turn | `Triggers if this card is in your hand when your turn ends.` |
| In hand | `Active while this card is in your hand.` |

### Ce que voit le joueur

- La carte vole de l'ennemi vers la pile visée (défausse, pioche ou main) ; cadre noir et violet, nom du
  lanceur en bas.
- Sous le portrait de chaque ennemi, un compteur `Curse N` : le nombre de ses Curses encore en jeu. À sa
  mort, ces cartes partent en fumée et le compteur disparaît.
- Les piles affichent le nombre de Curses qu'elles contiennent (pastille violette sur l'icône de pile).

### Interactions

| Règle | Comportement |
|---|---|
| Absorb | Un coup entièrement absorbé ne fait pas perdre de PV : pas de Rabies. Les pertes de PV des Curses (`End of turn`) ignorent l'Absorb, comme `Pay N HP`. |
| Parry | Un coup paré (≤ 8) ne fait pas perdre de PV : pas de Curse. Au-dessus de 8, le reste passe et la Curse aussi (Vile Bite 9 : voir questions ouvertes). |
| Stunned | Un ennemi étourdi ne pose rien. Un Stunned posé par une Trap avant le coup (Freezing Trap) arrête le Bite. Les Curses déjà posées restent. |
| Cast / Interrupt | Un Hex en Cast s'interrompt (Silence, Pummel, Counterspell, Kick, Counter Shot). Les pertes de PV d'une Curse ne sont pas une attaque : elles n'interrompent pas ton incantation. |
| Traps | Un Bite est une attaque : la Trap se déclenche avant le coup. Un Hex n'est pas une attaque : il ne déclenche aucune Trap. |
| DoT | Les pertes de PV d'une Curse ne sont pas du DoT. Un ennemi tué par son DoT au début de son tour lève ses Curses avant d'agir. |
| Familier (Hunter) | Curse of Weakness ne touche que les cartes Attack : le familier et les dégâts des Traps (Skills) n'en souffrent pas. Un lanceur tué par le familier lève ses Curses. |
| Rage (Warrior) | Toute perte de PV donne de la Rage : Rabies, Fevered Plague et le `Pay 2 HP` de Web en donnent. Enrage aussi. |
| Last Breath | Une Curse peut tuer : Last Breath se déclenche normalement. `Pay 2 HP` reste injouable s'il ferait tomber à 0. |
| Exhaust | Jouer une Curse compte comme jouer une carte Exhaust (Demonic Rune, Mor'Ladim's Skull) ; une Curse levée ou nettoyée non. Elle n'a pas de type : ni Attack ni Skill (pas de Rage d'Attack, pas de Combo). |
| Main de 10 | Une Curse ajoutée à une main pleine va dans la défausse. |
| Feign Death | Un tour ennemi sauté ne pose aucune Curse. |

### Aucune classe sans réponse

| Classe | Empêcher | Retirer | En tirer parti |
|---|---|---|---|
| Priest | Absorb (PW: Shield, Inner Fire) contre les Bites ; Silence contre les Hex ; Chastise (Stunned) | soins contre les pertes de PV ; **Mass Dispel** | Atonement compense Rabies |
| Warrior | Absorb (Defend, Shield Block), Pummel | Berserker Rage | Rage à chaque perte de PV ; **Spell Reflection** renvoie le Hex |
| Mage | Counterspell, Frost Nova, Polymorph, Mana Shield | **Remove Curse** | Casts résolus avant la pioche (Weakness) ; Charges par Curse retirée |
| Rogue | Parry contre les Bites (≤ 8), Kick | Cloak of Shadows ; cartes à 0 laissent du mana pour payer | tuer vite le lanceur ; **Ghostly Strike** |
| Hunter | Freezing Trap avant le Bite, Counter Shot, Intimidation | **Master's Call** | familier et Traps insensibles à Weakness |

### Ce que le moteur doit apprendre

`Data/Act1.lua` sait déjà : attaques à plusieurs coups, `interrupts`, `block`, `debuff`, `buff`,
`buff_allies`, `heal_ally`, `block_ally`, `summon`, `fn`, crochets `onDamaged` / `onDeath` / `onAllyDeath`,
`ai`. `Combat.canPlay` lit déjà `d.unplayable` ; `Effects.cleanse` existe.

1. **Cartes de Curse** : définitions `curse = true` (sans classe, jamais tirées), avec `unplayable`, `retain`,
   `payHp`, `endOfTurn = { effets }` et des crochets `inHand` (dégâts, pioche, coût). Jouées : toujours
   épuisées (`afterPlay`).
2. **`Combat.addCurse(c, id, src, to)`** : crée l'instance `{ uid, id, up = false, src = uid du lanceur }`
   (créée neuve, jamais modifiée : compatible avec `Combat.clone`), plafond 6, main pleine vers la défausse,
   journal `{ t = "curse", id, src, to }`.
3. **Action ennemie** `{ "curse", id, n = 1, to = "discard" | "draw" | "hand" }` et **drapeau d'attaque**
   `curse = id` (lu dans `executeMove` après `dealDamage`, comme `interrupts` : seulement si `loss > 0`,
   une fois par action).
4. **Fin de tour** : dans `Combat.endPlayerTurn`, avant la défausse, les lignes `End of turn` des Curses en
   main, de gauche à droite (`Combat.loseHp(c, n, "curse")`).
5. **Effets « en main »** : `modify "damage"` (Curse of Weakness, cartes Attack seulement, minimum 0 par
   coup), `modify "drawPerTurn"` (Web, lu avant la pioche du tour), `modify "cost"` (Curse of Tongues : si
   `c.turn.played == 0`, pas sur elle-même).
6. **Levée** : dans `Combat.kill` d'un ennemi, épuiser les Curses dont `src` vaut son uid, dans les trois piles
   et la main (journal `curse_lifted`).
7. **`Combat.cleanse`** sur le joueur : épuise aussi les Curses de la main ; renvoie le total (états + Curses)
   pour les cartes « per effect removed ».
8. **Intention « curse »** (icône `spell_shadow_curse`) et mini-icône de Curse sous une intention d'attaque à
   Bite.
9. **Boss** : état ennemi `unholy_shield` (dégâts subis divisés par 2, sans durée) ; carte donnée en main au
   début du combat (champ d'ennemi `gift = "morbents_bane"`, crochet `onCombatStart`) ; effet de carte qui
   retire un état ennemi.
10. **Cartes de zone** : état joueur `reflect` (retiré au début du tour, consommé par le premier Cast ennemi :
    ses attaques frappent le lanceur, ses Curses et `debuff` sont perdus) ; effet « tous les ennemis perdent
    Absorb et Strength ».
11. **Bots** : valeur d'une Curse en main = pénalité attendue × fois où elle sera encore piochée, contre son
    coût ; priorité de cible bonus pour un lanceur qui a des Curses en jeu.
12. **Statistiques** : Curses posées / jouées / levées / nettoyées, PV perdus par les Curses, mana dépensé à
    les payer.

## 3. Ennemis normaux (9)

Identifiants relevés dans le cache de créatures du client Forever (`tools/wdb_creatures.py`, lecture seule) :
`wow_creature_search` répond « No World of Warcraft install found » (pas de `WOW_INSTALL_PATH`). Format
d'intention de `Data/Act1.lua` ; « Bite: X » = drapeau `curse = X` sur l'attaque.

| id | Nom | PV | Intentions | Motif | Rôle | Curse | Créature / affichage | Repli icône |
|---|---|---|---|---|---|---|---|---|
| `dark_runner` | Nightbane Dark Runner | 21–24 | **Bite** (attack) : 7, Bite: Rabies ; **Pounce** (attack) : 4 ×2 | bite, pounce (départ au hasard) | source de Rabies, peu de PV | oui | 205 / 736 | `ability_hunter_pet_wolf` |
| `vile_fang` | Nightbane Vile Fang | 28–31 | **Vile Bite** (attack) : 9, Bite: Rabies ; **Maul** (attack) : 12 ; **Howl** (buff) : Strength 1 à tous les ennemis | vile_bite, maul, howl | chef de meute, fait monter le groupe | oui | 206 / 522 | `ability_hunter_pet_wolf` |
| `shadow_weaver` | Nightbane Shadow Weaver | 18–21 | **Curse of Weakness** (cast, Hex) : Curse of Weakness sur la pioche ; **Shadow Bolt** (cast) : attack 15 | hex, bolt (départ au hasard) | lanceur fragile : quelle incantation interrompre ? | oui | 533 / 203 | `spell_shadow_shadowbolt` |
| `plague_spreader` | Plague Spreader | 15–17 | **Plague Cloud** (curse, Hex) : Fevered Plague en défausse ; **Claw** (attack) : 6 | cloud, claw | cible à tuer d'abord : sa Curse ne se paie pas | oui | 604 / 519 | `spell_shadow_plaguecloud` |
| `venom_spider` | Venom Web Spider | 19–22 | **Web** (curse, Hex) : Web en main ; **Venom Bite** (attack) : 6, puis DoT 2 sur le joueur | web, venom_bite (départ au hasard) | vole des cartes, DoT léger | oui | 217 / 955 | `ability_hunter_pet_spider` |
| `pygmy_spider` | Pygmy Venom Web Spider | 9–11 | **Nip** (attack) : 3, puis DoT 1 sur le joueur | nip | essaim : le DoT s'additionne | non | 539 / 958 | `ability_hunter_pet_spider` |
| `rotted_one` | Rotted One | 34–38 | **Putrid Claw** (attack) : 10 ; **Shamble** (defend) : Absorb 9 à un allié au hasard | claw, shamble | mur qui protège les lanceurs | non | 948 / 137 | `inv_misc_head_undead_01` |
| `splinter_fist` | Splinter Fist Warrior | 36–40 | **Club** (attack) : 9 ; **Bellow** (buff) : Absorb 8, Strength 2 ; **Smash** (attack) : 15, interrompt | club, bellow, smash | ogre qui grossit : à tuer avant le 2e Bellow | non | 212 / 610 | `inv_misc_monsterhead_02` |
| `night_runner` | Defias Night Runner | 21–24 | **Ambush** (attack) : 13, au 1er tour seulement ; **Stab** (attack) : 7 ; **Kick** (attack) : 6, interrompt | ai : ambush au round 1, puis stab, kick en alternance | ouverture violente : demande l'Absorb au 1er tour | non | 215 / 4276, 4278 | `ability_rogue_ambush` |

Cinq sur neuf maudissent (Dark Runner, Vile Fang, Shadow Weaver, Plague Spreader, Venom Web Spider).

### Groupes

| Liste | Groupes | PV totaux |
|---|---|---|
| easy | `{ dark_runner, dark_runner }` · `{ pygmy_spider ×3 }` · `{ night_runner }` · `{ venom_spider, pygmy_spider }` | 30–45 |
| normal | `{ dark_runner, dark_runner, shadow_weaver }` · `{ vile_fang, dark_runner }` · `{ vile_fang, shadow_weaver }` · `{ rotted_one, plague_spreader }` · `{ venom_spider, venom_spider }` · `{ pygmy_spider ×4 }` · `{ splinter_fist }` · `{ night_runner, night_runner }` | 38–66 |
| elite | `{ stitches }` · `{ naraxis }` · `{ morladim }` | |
| boss | `{ morbent_fel }` | |
| rencontres | `event_worgen = { vile_fang, dark_runner }` · `event_ghouls = { rotted_one, plague_spreader }` · `event_ogres = { splinter_fist, splinter_fist }` · `event_morladim = { morladim }` · `event_naraxis = { naraxis }` | |

Repères Westfall : normaux de 44 à 57 PV ; Duskwood 38 à 66, plus le temps perdu à payer les Curses.

## 4. Élites (3)

| id | Nom | PV | Intentions | Motif | Idée de combat | Créature / affichage |
|---|---|---|---|---|---|---|
| `stitches` | Stitches | 86 | **Spew** (curse) : attack 6, puis 2 Fevered Plague en défausse ; **Slam** (attack) : 17, interrompt ; **Gorge** (buff) : Absorb 10, puis Strength +1 par Fevered Plague (de lui) dans tes piles et ta main | spew, slam, gorge | **L'horloge** : chaque Plague laissée en jeu le rend plus fort à chaque Gorge. Nettoyer sa main (ou le tuer en 4 tours) est la seule parade. | 412 / 1693 |
| `naraxis` | Naraxis | 78 | **Web Spray** (curse) : 2 Web en main ; **Poison Fangs** (attack) : 8 ×2, puis DoT 3 sur le joueur ; **Brood** (summon) : 2 Pygmy Venom Web Spider (minion) | web_spray, poison_fangs, brood, poison_fangs | **La main étouffée** : moins de cartes chaque tour, des petits à tuer en plus. Payer les Webs en PV ou jouer à 4 cartes. 4 ennemis vivants au plus. | non trouvée dans le cache ; repli affichage 955 (Venom Web Spider), échelle 1,4 |
| `morladim` | Mor'Ladim | 84 | **Bone Armor** (defend) : Absorb 14, attack 7 ; **Curse of Weakness** (cast, Hex) : 2 Curse of Weakness sur la pioche ; **Crushing Blow** (attack) : 21, interrompt | bone_armor, hex, crushing_blow | **L'armure contre la faiblesse** : son Absorb tient face à des Attacks à -3 par coup. Interrompre le Hex, ou payer 2 mana pour frapper à plein. | 522 / 612 |

Repères Westfall : Harvest Golem 72, Rhahk'Zor 75 ; ×1,12 ≈ 81–84.

## 5. Boss : Morbent Fel

Nécromancien de Tranquil Gardens Cemetery. **Choisi plutôt que Stitches** : c'est un lanceur de sorts, donc
le combat met en jeu toute la mécanique (Hex en Cast, interruption, Curses qui durent jusqu'à sa mort), et sa
quête de WoW lui donne une seconde règle lisible (le bouclier impie et Morbent's Bane de Madame Eva).
Stitches, une brute de mêlée, fait une meilleure élite. Créature 1200, affichage 4272 ; repli icône
`spell_shadow_raisedead`.

**Unholy Shield** (état ennemi) : `Takes half damage. Morbent's Bane removes it.` Morbent l'a au début du combat.

**Morbent's Bane** (carte donnée dans ta main au début du combat, propre au combat) : coût 1, Skill, vise un
ennemi : `Remove Unholy Shield.` / `Deal 6.` / `Retain.` / `Cooldown 3.` (icône `inv_misc_powder_purple`).
Décision : la jouer au tour 1 (1 mana sur 3) ou se défendre d'abord et frapper à moitié.

| Phase | PV | Motif | Intentions |
|---|---|---|---|
| 1 | 104 → 53 | shadow_bolt, tongues, drain_life | **Shadow Bolt** (cast) : attack 20 · **Curse of Tongues** (curse) : attack 6, puis Curse of Tongues en main · **Drain Life** (attack) : 9, soigne Morbent de 9 |
| Bascule | ≤ 52 (une fois) | — | Il dit « Rise, and serve your master! », invoque 2 **Fetid Corpse** ; sa prochaine intention est Unholy Shield. |
| 2 | 52 → 0 | unholy_shield, shadow_bolt, tongues, drain_life | **Unholy Shield** (cast) : Absorb 10 et Unholy Shield (interrompu : ni l'un ni l'autre) · **Shadow Bolt** (cast) : attack 24 · **Curse of Tongues** : comme en phase 1 · **Drain Life** : 11, soigne 11 |

**Fetid Corpse** (`fetid_corpse`, minion, créature 1270 / affichage 559) : 12–14 PV ; **Rotting Claw**
(attack) : 5, Bite: Fevered Plague. Tuer un Corpse lève ses Plagues.

À sa mort : toutes les Curses du combat sont levées (le combat est gagné).

Durée visée : phase 1 en 3 tours (Bane au tour 1, ≈ 18 dégâts par tour), phase 2 en 3 à 4 tours (2 Corpses
de 13 PV puis 52 PV, bouclier à retirer une seconde fois : Bane revient de recharge au bon moment si elle a
été jouée au tour 1). Total 6 à 7 tours. Dégâts par cycle : phase 1 ≈ 35 sur 3 tours (VanCleef ≈ 54 sur 4)
plus la taxe de Tongues ; phase 2 ≈ 41 sur 4 tours plus les Corpses.

## 6. Rencontres (8)

Format de `Data/Events.lua`. `act = 2` (Duskwood). Personnages : créature / affichage du cache du client.

| id | Personnage | Créature / affichage | Décor | Rareté, palier, condition |
|---|---|---|---|---|
| `scarlet_raven_tavern` | Tavernkeep Smitts | 273 / 1731 | town | common, 0 |
| `night_watch_wall` | Commander Althea Ebonlocke | 264 / 4322 | town | common, 0 |
| `sven_camp` | Sven Yorgen | 311 / 4327 | camp | common, 0 |
| `madame_eva` | Madame Eva | 265 / 4323 | town | common, 1 |
| `abercrombie_shack` | Abercrombie | 289 / 4328 | woods | common, 1 |
| `viktori_monocle` | Viktori Prism'Antras | 276 / 4326 | town | common, 2 |
| `weathered_grave` | Jonathan Carevin | 661 / 4338 | graveyard | rare, 1, PV ≥ 60 % |
| `webbed_watcher` | Watcher Dodds | 888 / 2384 | woods | rare, 2 |

```lua
event("scarlet_raven_tavern", {
  name = "The Scarlet Raven", act = 2, tier = 0,
  speaker = "Tavernkeep Smitts", npc = "tavernkeep_smitts", scene = "town",
  text = "\"Welcome to the Scarlet Raven. Nobody takes the Raven Hill road after dark, so a room is "
    .. "20 gold tonight. I also sell Zombie Juice, if you can stand the taste.\"",
  choices = {
    { label = "Rent a room", outcome = "Pay 20g, heal 40% of max HP",
      result = "You sleep behind a barred door until morning.",
      effects = { { "pay", 20 }, { "healPct", 0.40 } } },
    { label = "Eat at the bar", outcome = "+7 HP",
      result = "Smitts serves you a bowl of stew and bread.",
      effects = { { "heal", 7 } } },
    { label = "Buy a bottle of Zombie Juice", outcome = "Pay 25g, Zombie Juice (card)",
      when = { { "unlocked", "zombie_juice", hide = true } },
      result = "Smitts corks a green bottle. \"Drink it fast.\"",
      effects = { { "pay", 25 }, { "card", "zombie_juice" } } },
  },
})

event("night_watch_wall", {
  name = "The Night Watch", act = 2, tier = 0,
  speaker = "Commander Althea Ebonlocke", npc = "althea_ebonlocke", scene = "town",
  text = "\"The Nightbane have attacked three farms this week and the Night Watch is short of men. "
    .. "Take a shift on the wall tonight, or give us gold for arrows.\"",
  choices = {
    { label = "Take a shift on the wall", outcome = "-8 HP, upgrade 2 random cards",
      result = "You hold the wall with the watchers until dawn.",
      effects = { { "loseHp", 8 }, { "upgradeRandom", 2 } } },
    { label = "Pay for arrows", outcome = "Pay 40g, remove a card from the deck",
      result = "\"Thank you. Leave what you don't need at the armory.\"",
      effects = { { "pay", 40 }, { "remove" } } },
    { label = "Leave", outcome = "Nothing",
      result = "You leave Darkshire by the south road.",
      effects = {} },
  },
})

event("sven_camp", {
  name = "Sven's Camp", act = 2, tier = 0,
  speaker = "Sven Yorgen", npc = "sven_yorgen", scene = "camp",
  text = "\"The Nightbane killed my family and burned my farm. A pack of them sleeps by the road. "
    .. "Help me hunt them, or sit by my fire and rest.\"",
  choices = {
    { label = "Hunt the pack with Sven", outcome = "Fight 2 worgen: usual reward + 20g",
      result = "You and Sven attack the Nightbane.",
      effects = { { "fight", "event_worgen", gold = 20 } } },
    { label = "Rest by his fire", outcome = "+10 HP",
      result = "Sven keeps watch while you sleep.",
      effects = { { "heal", 10 } } },
    { label = "Give him a potion", outcome = "Lose a potion, +6 max HP",
      when = { { "potion" } },
      result = "Sven drinks it and shows you how he fights the worgen.",
      effects = { { "losePotion" }, { "maxHp", 6 } } },
  },
})

event("madame_eva", {
  name = "Madame Eva's Cards", act = 2, tier = 1,
  speaker = "Madame Eva", npc = "madame_eva", scene = "town",
  text = "\"Sit down. For 15 gold I will read your cards. Or draw one from my deck yourself, "
    .. "but what you draw, you keep.\"",
  choices = {
    { label = "Have your cards read", outcome = "Pay 15g, one of 3 uncommon cards",
      result = "Madame Eva lays out three cards and tells you which one to take.",
      effects = { { "pay", 15 }, { "cardChoice", n = 3, rarity = "uncommon" } } },
    { label = "Draw from her deck", outcome = "50%: one of 3 rare cards, else -5 max HP",
      effects = { { "gamble", 0.5,
        win = { { "cardChoice", n = 3, rarity = "rare" } },
        winText = "You draw a gold card. Madame Eva nods.",
        lose = { { "loseMaxHp", 5 } },
        loseText = "You draw a black card. You feel weaker at once." } } },
    { label = "Leave", outcome = "Nothing",
      result = "You leave her house.",
      effects = {} },
  },
})

event("abercrombie_shack", {
  name = "The Hermit", act = 2, tier = 1,
  speaker = "Abercrombie", npc = "abercrombie", scene = "woods",
  text = "\"A visitor! I need ghoul ribs for my work. The cemetery on Raven Hill is full of ghouls. "
    .. "Bring me some and I'll pay you, or have some of my soup.\"",
  choices = {
    { label = "Hunt ghouls on Raven Hill", outcome = "Fight 2 undead: usual reward + 25g",
      result = "You attack the undead in the cemetery.",
      effects = { { "fight", "event_ghouls", gold = 25 } } },
    { label = "Eat his soup", outcome = "50%: +6 max HP, else -6 HP",
      effects = { { "gamble", 0.5,
        win = { { "maxHp", 6 } },
        winText = "The soup is thick and hot. You feel stronger.",
        lose = { { "loseHp", 6 } },
        loseText = "There is a finger bone in the soup. You are sick for an hour." } } },
    { label = "Leave", outcome = "Nothing",
      result = "Abercrombie closes his door.",
      effects = {} },
  },
})

event("viktori_monocle", {
  name = "Look to the Stars", act = 2, tier = 2,
  speaker = "Viktori Prism'Antras", npc = "viktori", scene = "town",
  text = "\"I need an ogre's monocle for my telescope. The Splinter Fist ogres at Vul'Gol have one. "
    .. "Bring it to me, or pay me to teach you what I know.\"",
  choices = {
    { label = "Raid the ogre mound", outcome = "Fight 2 ogres: usual reward + 30g",
      result = "You attack the Splinter Fist ogres.",
      effects = { { "fight", "event_ogres", gold = 30 } } },
    { label = "Take a lesson", outcome = "Pay 35g, upgrade a card of your choice",
      result = "Viktori teaches you for an hour.",
      effects = { { "pay", 35 }, { "upgrade" } } },
    { label = "Leave", outcome = "Nothing",
      result = "Viktori goes back to his books.",
      effects = {} },
  },
})

-- Rare : combat d'élite facultatif, proposé en bonne santé.
event("weathered_grave", {
  name = "The Weathered Grave", act = 2, tier = 1, rarity = "rare",
  speaker = "Jonathan Carevin", npc = "jonathan_carevin", scene = "graveyard",
  when = { { "hpAbove", 0.6 } },
  text = "\"Mor'Ladim walks Raven Hill Cemetery every night. He was Morgan Ladimore of the Night "
    .. "Watch before he died. I pay 40 gold to whoever puts him down.\"",
  choices = {
    { label = "Hunt Mor'Ladim", outcome = "Elite fight: elite reward + 40g",
      result = "You wait for Mor'Ladim at the cemetery gate.",
      effects = { { "fight", "event_morladim", kind = "elite", gold = 40 } } },
    { label = "Read the Ladimore records", outcome = "-4 max HP, one of 3 rare cards",
      result = "You spend the night reading Clerk Daltry's records by candlelight.",
      effects = { { "loseMaxHp", 4 }, { "cardChoice", n = 3, rarity = "rare" } } },
    { label = "Leave", outcome = "Nothing",
      result = "Jonathan goes back inside.",
      effects = {} },
  },
})

-- Rare : sauver le guetteur ou attaquer le nid.
event("webbed_watcher", {
  name = "The Webbed Watcher", act = 2, tier = 2, rarity = "rare",
  speaker = "Watcher Dodds", npc = "watcher_dodds", scene = "woods",
  text = "Watcher Dodds hangs wrapped in webs at the edge of a spider nest. \"Cut me loose! Naraxis "
    .. "is in there, and she'll be back soon.\"",
  choices = {
    { label = "Cut him loose", outcome = "-6 HP, a potion and 20g",
      result = "You cut the webs. A spider bites you before you get him out. He pays you from his purse.",
      effects = { { "loseHp", 6 }, { "potion" }, { "gold", 20 } } },
    { label = "Burn the nest", outcome = "Elite fight: elite reward + 40g",
      result = "You set fire to the webs. Naraxis comes out of the nest.",
      effects = { { "fight", "event_naraxis", kind = "elite", gold = 40 } } },
    { label = "Leave him", outcome = "Nothing",
      result = "You go back to the road.",
      effects = {} },
  },
})
```

## 7. Cartes de zone (une par classe)

Cartes définitives (épiques, pivots) : voir `docs/zones/cartes-de-zone.md`.

- Misery (Priest)
- Thunderous Roar (Warrior)
- Molten Armor (Mage)
- Doomblade (Rogue)
- Trap Launcher (Hunter)

## 8. Commun débloqué par la première victoire du compte

### Cartes neutres (2)

| id | Nom (objet) | Métier | Rareté | Coût | Type | Texte | Amélioré | Icône | Palier de Ligue |
|---|---|---|---|---|---|---|---|---|---|
| `anti_venom` | Anti-Venom | First Aid | common | 0 | Skill | Remove negative effects. / Draw 1. / Exhaust. | Remove negative effects. / Draw 2. / Exhaust. | `inv_alchemy_90_antivenom` | 1 Friendly |
| `zombie_juice` | Zombie Juice | Cooking (boisson de Tavernkeep Smitts) | uncommon | 0 | Skill | +1 mana. / Draw 1. / Exhaust. | +1 mana. / Draw 2. / Exhaust. | `inv_drink_08` | 2 Honored |

Anti-Venom est la réponse neutre aux Curses (et aux Sundered, Demoralized, DoT ailleurs) ; Zombie Juice paie
une Curse sans perdre le tour. Repères : Runecloth Bag (Draw 2, coût 1), Black Lotus (+2 mana, rare).

### Bibelots communs (3)

| id | Nom | Rareté | Palier | Effet (texte affiché) | Icône | Crochet |
|---|---|---|---|---|---|---|
| `ogres_monocle` | Ogre's Monocle | common | 1 | `Card rewards offer 4 cards instead of 3.` | `inv_misc_spyglass_02` | récompense de combat (nombre de cartes) |
| `night_watch_shortsword` | Night Watch Shortsword | uncommon | 1 | `The first Attack played each turn deals 2 more per hit.` | `inv_sword_04` | `damage` + compteur du tour |
| `mistmantle_family_ring` | Mistmantle Family Ring | uncommon | 2 | `Whenever an enemy dies, gain 4 Absorb.` | `inv_jewelry_ring_03` | `onEnemyDeath` |

Objets de WoW : le monocle de la quête « Look to the Stars » (Viktori Prism'Antras, porté par Zzarc' Vul),
l'épée courte de la Night Watch de Darkshire, la chevalière de la saga de Stalvan Mistmantle. Noms à vérifier
dans une base d'objets (aucune base d'objets dans le MCP).

### Type de rencontre : Wanted Poster

Nouvelle famille de rencontres (toutes zones, palier 1) : une affiche de la Night Watch au bord du chemin.
`"WANTED: Mor'Ladim. The Night Watch pays 50 gold for proof of the kill."` (le nom est celui de la prochaine élite du chemin).
1. **Take the poster** : la prochaine élite du chemin devient « Wanted » ; la battre donne +50 po et une
   carte améliorée au hasard.
2. **Leave it** : rien.
Moteur : drapeau d'expédition sur un nœud d'élite (le premier atteignable), lu par la récompense de combat ;
icône `inv_misc_note_01`. Intérêt : rendre le chemin des élites rentable sans en ajouter.

## 9. Bibelots de clé (+1, +3, +5)

Communs aux classes, plus forts que les communs, débloqués par la première victoire à la clé +1, +3, +5 de
Duskwood (quelle que soit la classe) ; rareté `rare`, dans la réserve de tirage une fois débloqués.

| Clé | id | Nom | Effet (texte affiché) | Icône | Crochet |
|---|---|---|---|---|---|
| +1 | `ghoul_rib` | Ghoul Rib | `The first negative effect or Curse put on you each turn is prevented.` | `inv_misc_bone_02` | `onStatusApplied` (annulation) + `addCurse` |
| +3 | `morladims_skull` | Mor'Ladim's Skull | `Whenever a card is exhausted, deal 3 to all enemies.` | `inv_misc_bone_humanskull_01` | crochet d'épuisement (nouveau point, commun à `afterPlay` et aux levées) |
| +5 | `morbents_bane_relic` | Morbent's Bane | `+1 mana on turns when an enemy announces a Cast.` | `inv_misc_powder_purple` | `onTurnStart`, après le choix des intentions |

Objets : les côtes de goule de la quête d'Abercrombie, le crâne de Mor'Ladim (quête de Jonathan Carevin), la
préparation de Madame Eva contre Morbent Fel. Noms à vérifier. Mor'Ladim's Skull compte aussi les Curses
jouées (épuisées) mais pas les Curses levées ou nettoyées ; à Duskwood, chaque Curse payée devient 3 dégâts à
tous. Morbent's Bane récompense les combats contre lanceurs (Shadow Weaver, Mor'Ladim, Defias Conjurer,
boss) : +1 mana par tour d'incantation ennemie.

## 10. Modèles et icônes

Créatures et affichages : cache de créatures du client Forever (`Cache/WDB/enUS/creaturecache.wdb`, build
70888), lu par `python3 -I tools/wdb_creatures.py <noms>` ; c'est la même source que `UI/Art.lua`. Le MCP
`wow_creature_search` n'a pas d'installation déclarée (`WOW_INSTALL_PATH`) ; aucune synchronisation lancée.
Icônes : `wow_icon_search` et présence vérifiée dans `~/Téléchargements/ICONS/`.

| Entité | Créature | Affichage | Icône de repli |
|---|---|---|---|
| Nightbane Dark Runner | 205 | 736 | `ability_hunter_pet_wolf` |
| Nightbane Vile Fang | 206 | 522 | `ability_hunter_pet_wolf` |
| Nightbane Shadow Weaver | 533 | 203 | `spell_shadow_shadowbolt` |
| Plague Spreader | 604 | 519 | `spell_shadow_plaguecloud` |
| Venom Web Spider | 217 | 955 | `ability_hunter_pet_spider` |
| Pygmy Venom Web Spider | 539 | 958 | `ability_hunter_pet_spider` |
| Rotted One | 948 | 137 | `inv_misc_head_undead_01` |
| Splinter Fist Warrior | 212 | 610 | `inv_misc_monsterhead_02` |
| Defias Night Runner | 215 | 4276, 4278 | `ability_rogue_ambush` |
| Stitches (élite) | 412 | 1693 | `inv_misc_head_undead_02` |
| Naraxis (élite) | **non trouvé** | repli 955, échelle 1,4 | `inv_misc_monsterspidercarapace_01` |
| Mor'Ladim (élite) | 522 | 612 | `inv_misc_bone_humanskull_02` |
| Morbent Fel (boss) | 1200 | 4272 | `spell_shadow_raisedead` |
| Fetid Corpse (sbire) | 1270 | 559 | `inv_misc_head_undead_01` |
| Tavernkeep Smitts | 273 | 1731 | `inv_drink_08` |
| Commander Althea Ebonlocke | 264 | 4322 | `inv_misc_lantern_01` |
| Sven Yorgen | 311 | 4327 | `inv_misc_head_human_01` |
| Madame Eva | 265 | 4323 | `inv_misc_orb_04` |
| Abercrombie | 289 | 4328 | `inv_misc_bone_02` |
| Viktori Prism'Antras | 276 | 4326 | `inv_misc_spyglass_02` |
| Jonathan Carevin | 661 | 4338 | `inv_misc_bone_humanskull_01` |
| Watcher Dodds | 888 | 2384 | `inv_misc_web_01` |

Modèles M2 de secours (`wow_model_search`, FileDataID) si un affichage ne charge pas : worgen 126511
(`creature/worgen/worgen.m2`), araignée 3095173, goule 124160, squelette 125942, ogre 125263, zombie 126570,
humain 119940. Abomination classique (Stitches) : **non trouvée** dans le listfile, seuls
`abominationsmall` 3186502 et `abominationlord` 3166670.

Autres icônes : intention Curse `spell_shadow_curse` ; Unholy Shield `spell_shadow_antimagicshell` ; Reflect
`ability_warrior_shieldreflection` ; Wanted Poster `inv_misc_note_01` ; Curses, cartes et bibelots : dans
leurs tableaux.

## 11. Questions ouvertes

1. **Boss : Morbent Fel ou Stitches ?** Avec Morbent Fel, le dernier combat se joue sur l'interruption et le
   bouclier à retirer (6 à 7 tours, Curses jusqu'à la fin). Avec Stitches, c'est une course contre sa Strength
   qui monte, plus simple à lire mais sans incantation à couper ; Morbent passerait alors élite.
2. **Lever les Curses à la mort du lanceur.** Oui (proposé) : tu choisis ta cible pour te libérer, le Plague
   Spreader meurt toujours en premier. Non : une règle de moins, mais Fevered Plague devient une taxe sans
   réponse pour les decks sans nettoyage.
3. **Vile Bite à 9 contre la Parry du Rogue (8).** À 9, une Parry laisse passer 1 PV et donc Rabies : le
   Rogue doit ajouter de l'Absorb ou tuer le Vile Fang. À 8, la Parry suffit et le Rogue devient la classe la
   plus à l'aise à Duskwood.
4. **Les Curses peuvent-elles tuer ?** Oui (proposé, comme le DoT) : finir un tour avec 2 PV et Rabies en main
   est une défaite. Non : les pertes s'arrêtent à 1 PV, Duskwood devient plus clément pour Mage (42 PV) et
   Hunter (41 PV).
5. **« Remove negative effects » épuise les Curses en main.** Oui (proposé) : Berserker Rage, Cloak of
   Shadows et Insignia of the Alliance prennent de la valeur ici et Anti-Venom a un rôle. Non : seules les
   cartes de zone nettoient, et ces trois cartes restent ce qu'elles sont.
