# Stranglethorn Vale — fiche de zone

Zone 4 de la campagne (id `stranglethorn`), après Wetlands, avant Swamp of Sorrows. Difficulté : Westfall + 36 %
(PV et dégâts des ennemis × 1,36 par rapport à `Data/Act1.lua`, arrondis ; la simulation réglera). Fiche de
conception ; codée le 14/11/2026 (§ 12, « Implémentation »). Textes affichés en anglais, explications en français.

Repères Westfall × 1,36 utilisés pour les chiffres :

| Westfall | PV / dégâts | × 1,36 |
|---|---|---|
| Riverpaw Gnoll | 19–22 PV, Bite 8 | 26–30 PV, 11 |
| Riverpaw Mystic | 15–17 PV, Heal 6, Shock 5 | 20–23 PV, 8, 7 |
| Defias Highwayman (ex-Defias Bandit) | 25–28 PV, Kick 5 | 34–38 PV, 7 |
| Harvest Golem / Rhahk'Zor | 72 / 75 PV, Smash 19 / Slam 18 | 98 / 102 PV, 26 / 24 |
| Edwin VanCleef | 92 PV, Mortal Strike 23 | 125 PV, 31 |

## 1. La zone en trois lignes

- **Lieux** : la route de la jungle entre Booty Bay et le nord (fond `road`) ; le camp de Nesingwary's Expedition
  (`camp`) ; Booty Bay, son port et le marchand (`coast`) ; les ruines trolls de Zul'Kunda et Zul'Mamwe, puis les
  portes de Zul'Gurub pour le boss (`ruins`) ; Gurubashi Arena pour la nouvelle case de parcours (§ 8).
- **Ennemis** : trolls Bloodscalp et Skullsplitter et leurs sorciers, bêtes de la jungle (panthères, raptors,
  gorilles, tigres), pirates Bloodsail sur la côte, nagas au service de Zanzil.
- **Ambiance factuelle** : chasseurs de Nesingwary qui collectionnent les trophées, gobelins de Booty Bay qui
  paient les têtes de pirates, trolls qui maudissent les intrus ; le prêtre Jin'do sert Hakkar à Zul'Gurub.

## 2. La mécanique de la zone : Hex

### Choix : Hex seul, Ambush abandonné

La proposition contenait deux mécaniques. Une seule est gardée, **Hex**, pour trois raisons :

1. **Ambush est une taxe sans réponse.** Un ennemi qui agit avant le premier tour frappe un joueur qui n'a encore
   rien pu jouer : ni Absorb, ni Parry, ni Trap, ni Interrupt. Aucune carte ne répond, seul un bibelot le
   pourrait. Cela coûte plus cher aux classes fragiles (Mage 42 PV, Hunter 41 PV) et rien ne se décide en combat.
2. **Le nom est pris** : `Ambush` est déjà une carte du Rogue (Subtlety, `Data/Rogue.lua`). Un mot-clé ennemi
   du même nom brouillerait les infobulles.
3. **Le brief demande une mécanique par zone.** Hex mobilise déjà l'Interrupt, le Stunned, le DoT, l'ordre de jeu
   et la gestion de la main. Ajouter Ambush ferait deux règles nouvelles à apprendre dans la même zone.

**L'idée d'Ambush est gardée sans règle nouvelle** : Shadowmaw Panther et King Bangalash ouvrent toujours le
combat par leur plus gros coup (motif sans `randomStart`, premier coup annoncé au tour 1 comme toute intention).
Le joueur voit l'attaque venir et peut s'y préparer dès son premier tour.

### Règle exacte

1. **Intention Hex.** Certains ennemis ont une intention `Hex`. C'est un **Cast** ennemi : annoncé au début du
   tour du joueur, il se résout pendant le tour de l'ennemi. Toute carte « Interrupt the target's cast. »
   l'annule.
2. **Carte visée.** Tant qu'un Hex est annoncé, la carte qu'il frappera est **la plus chère des cartes encore en
   main** (coût actuel, réductions comprises ; à égalité, la plus à gauche). L'interface l'entoure d'un liseré
   vert et la marque de l'icône du Hex. La marque se déplace en direct à mesure que le joueur joue ses cartes.
3. **Verrouillage en fin de tour.** À la fin du tour du joueur, après les effets de fin de tour (attaque du
   familier comprise) et **avant la défausse de la main**, chaque Hex encore valable verrouille sa carte. Un Hex
   n'est plus valable si son lanceur est mort, interrompu ou étourdi (Stunned). Deux Hex verrouillent deux cartes
   différentes : le premier ennemi dans l'ordre d'action prend la plus chère, le suivant la suivante.
4. **Main vide** : un Hex qui ne trouve aucune carte au verrouillage échoue. Journal : « The hex finds no card. »
5. **Résolution.** Quand le lanceur agit, si son Hex tient toujours (il n'est pas mort de son DoT au début de son
   tour, par exemple), la carte verrouillée est **remplacée sur place** (défausse, ou main si elle avait Retain)
   par une carte **Hexed**. Si la carte verrouillée n'est plus dans la défausse ni dans la main, le Hex échoue.
6. **La carte Hexed** (id `hexed`, hors réserve, propre au combat) :
   - coût 1, Skill, sans cible ; texte : `Turn back into <name>, in your hand.` (le nom de la carte d'origine
     est écrit sur la carte, sous l'icône du Hex) ;
   - jouée : la carte d'origine (même instance, même amélioration) revient **dans la main** et peut être jouée
     tout de suite si le mana le permet ; la carte Hexed disparaît (ni défausse ni épuisement) ;
   - non jouée : elle suit le cycle normal (défausse, pioche) et reviendra plus tard ;
   - elle compte comme une Skill jouée (compteurs de cartes jouées), jamais comme une Attack ni un Cast ;
   - fin du combat : tous les Hex disparaissent ; le deck de l'expédition n'est jamais touché.
7. **Hex immédiat (Zanzil Naga).** Un effet « hex now » frappe tout de suite la plus chère des cartes en main,
   sans Cast ni verrouillage : il ne peut pas être interrompu. Main vide : rien.

### Interactions

| Règle | Comportement |
|---|---|
| Interrupt | Annule le Hex (c'est un Cast) ; la marque disparaît aussitôt. Arcane Bomb (neutre) aussi. |
| Stunned | Un lanceur étourdi pendant le tour du joueur perd son tour : son Hex ne verrouille rien. Boss immunisés : contre Jin'do, seul l'Interrupt arrête son Hex. |
| DoT | Le DoT se déclenche au début du tour du lanceur : s'il le tue, le Hex verrouillé est perdu. |
| Absorb, Parry | Aucun effet : le Hex n'est pas un coup. |
| Traps | Le Hex n'est pas une attaque : il ne déclenche pas les Traps (sauf Snake Trap, § 7). Les Traps posées ne sont pas en main : intouchables. |
| Familier (Hunter) | Il attaque avant le verrouillage : s'il tue le lanceur, rien n'est verrouillé. |
| Cast du joueur | Une carte en incantation n'est plus en main : intouchable. Le Mage protège ses gros sorts en les lançant. |
| Cooldown, Powers | Hors de la main : intouchables. |
| Retain | Une carte gardée reste en main, donc exposée ; sa version Hexed reste en main et se défausse normalement à la fin du tour suivant. |
| Pioche pendant le tour ennemi (Lock and Load) | La carte piochée n'est pas verrouillée (le verrouillage a eu lieu avant). |

### Ce que voit le joueur

- Intention : icône `spell_shaman_hex`, mot « Hex », pas de chiffre de dégâts.
- Dans la main : liseré vert et petite icône du Hex sur la carte qui sera frappée ; elle change en direct.
- Tour ennemi : la carte s'envole de la défausse vers le lanceur et revient en grenouille (animation ≤ 0,3 s).
- Infobulles (≤ 60 caractères) :
  - Hex : `Cast. Hexes the costliest card left in your hand.`
  - Hexed : `Costs 1. Play it to get your card back in hand.`

### Les décisions qu'elle crée

1. **Interrompre ou garder son Interrupt** pour un autre Cast (Fireball d'un mage, Pounce n'est pas un Cast).
2. **Tuer le lanceur d'abord** : les sorciers ont peu de PV.
3. **Vider sa main ou choisir sa victime** : jouer sa carte chère maintenant même si ce n'est pas le meilleur
   moment, ou garder exprès une carte faible pour qu'elle prenne le Hex à sa place.
4. **Payer pour récupérer** : 1 mana pour retrouver Pyroblast ou Mortal Strike plus tard, ou laisser la grenouille
   et jouer autre chose.

### Aucune classe sans réponse

| Classe | Interrupt (niveau 1) | Autres réponses |
|---|---|---|
| Priest | Silence (0, Cooldown 2) | DoT (SW: Pain) qui tue le lanceur ; Holy Word: Chastise (Stunned) |
| Warrior | Pummel (0, Cooldown 2) | Gros dégâts directs sur un lanceur de 21–27 PV ; peu de cartes chères en main |
| Mage | Counterspell (0, Cooldown 2) | Frost Nova, Polymorph (Stunned) ; ses Cast quittent la main |
| Rogue | Kick (0, Cooldown 2) | Beaucoup de cartes à 0 : main vide plus souvent ; Cheap Shot (Stunned) |
| Hunter | Counter Shot (0, Cooldown 2) | Intimidation, Wyvern Sting (Stunned) ; le familier finit les lanceurs. Ses Traps ordinaires ne servent pas contre le Hex (Snake Trap, § 7, oui). |

### Ce que le moteur doit apprendre

`Data/Act1.lua` sait déjà : intentions Cast (`cast = true`), interruption par le joueur (`e.interrupted`),
motifs fixes ou aléatoires, `ai`, crochets `onDamaged` / `onDeath`, invocations, Stunned qui arrête un tour.
Il manque :

1. Action ennemie `{ "hex" }` (dans un move `cast = true`), et action immédiate `{ "hex_now" }`.
2. `Combat.hexTarget(c, excluded)` : la plus chère des cartes en main (`Combat.cost`, égalité à gauche) ; sert à
   l'aperçu de l'interface, aux bots et au verrouillage.
3. Verrouillage dans `Combat.endPlayerTurn`, après `onTurnEnd` (et l'attaque du familier), avant la défausse :
   `c.hexLocks[uid de l'ennemi] = uid de la carte` pour chaque lanceur vivant, non interrompu, non étourdi.
4. Résolution dans `executeMove` : retrouver l'instance verrouillée (main ou défausse), la remplacer par
   `Card.new("hexed", false, uid neuf)` avec `orig = instance` (l'instance d'origine n'est pas modifiée :
   compatible avec `Combat.clone`) ; journal `{ t = "hex", unit, card }` ou `{ t = "hex_fizzle", unit }`.
5. Carte `hexed` (hors réserve, `noPool`) et effet `{ "unhex" }` : remet `orig` en main ; effet
   `{ "unhex_all" }` (Jungle Remedy).
6. Compteur `Combat.hexedCount(c)` (cartes Hexed en main, pioche, défausse) et attaque à bonus
   `{ "attack", 9, perHexed = 3 }` (Bloodscalp Headhunter), affichée dans `Combat.intentInfo`.
7. Condition nommée `Interrupted:` (vraie si la carte vient d'annuler un Cast) et « deal N to each enemy
   interrupted » (cartes du Mage et du Warrior, § 7) ; Trap qui se déclenche aussi sur un Cast (`onCast = true`).
8. Statistiques : Hex annoncés, interrompus, échoués (main vide, lanceur mort), posés ; cartes Hexed jouées ;
   cartes jamais récupérées ; PV perdus par combat avec et sans lanceur.
9. Bots : coût d'une carte laissée en main sous un Hex (valeur de la carte visée), choix de garder un
   paratonnerre, valeur de l'unhex (valeur de la carte − 1 mana), priorité de cible sur les lanceurs.

## 3. Ennemis normaux (8)

Intentions : `attack` = coup annoncé ; `cast` = résolu au tour de l'ennemi, interruptible. « Hex » renvoie au § 2.
Quatre sur huit utilisent la mécanique (Witch Doctor, Mystic, Headhunter, Zanzil Naga).

| id | Nom | PV | Intentions (actions chiffrées) | Motif | Rôle | Hex |
|---|---|---|---|---|---|---|
| `bloodscalp_witch_doctor` | Bloodscalp Witch Doctor | 21–24 | **Hex** (cast) : hex. **Shadow Bolt** : attack 8. | `hex`, `bolt` ; départ aléatoire | Lanceur fragile, cible prioritaire. | oui |
| `skullsplitter_mystic` | Skullsplitter Mystic | 24–27 | **Hex** (cast) : hex. **Healing Wave** : heal_ally 10. **Lightning Bolt** : attack 7. | `ai` : Hex si son dernier coup n'était pas Hex ; sinon Healing Wave si un allié a perdu ≥ 8 PV ; sinon Lightning Bolt | Hex un tour sur deux, soigne le reste du groupe. | oui |
| `bloodscalp_headhunter` | Bloodscalp Headhunter | 30–34 | **Throw Spear** : attack 5 × 2. **Take a Trophy** : attack 9, +3 par carte Hexed que tu possèdes (main, pioche, défausse). | `spear`, `trophy` ; départ aléatoire | Punit les Hex laissés en place : avec un sorcier, il faut récupérer ses cartes. | oui |
| `zanzil_naga` | Zanzil Naga | 30–34 | **Trident** : attack 11. **Coil** : block 8, attack 5. Passif **Death Hex** : à sa mort pendant ton tour, hex now. | `trident`, `coil` ; départ aléatoire | L'achever avec sa dernière carte (main vide), au DoT, par un Cast ou une Trap. | oui |
| `shadowmaw_panther` | Shadowmaw Panther | 26–29 | **Ravage** : attack 14. **Prowl** : block 10. **Claw** : attack 9. | `ravage`, `prowl`, `claw` ; **départ fixe** | L'embuscade visible : gros coup annoncé au tour 1. | non |
| `lashtail_raptor` | Lashtail Raptor | 21–24 | **Bite** : attack 9. **Lashing Tail** : attack 4 × 2. | `bite`, `tail` ; départ aléatoire | Bête de meute, en paire ou avec un lanceur. | non |
| `mistvale_gorilla` | Mistvale Gorilla | 36–40 | **Pound** : attack 13. **Beat Chest** : block 8, buff Strength 2. | `pound`, `beat_chest` | Brute qui monte si le combat traîne. | non |
| `bloodsail_swashbuckler` | Bloodsail Swashbuckler | 29–32 | **Cutlass** : attack 10. **Dirty Trick** : attack 5, debuff Demoralized 1. **Kick** : attack 7, interrupts. | `cutlass`, `trick`, `kick` ; départ aléatoire | Pirate de la côte, coupe les Cast du joueur. | non |

Précisions :
- **Death Hex** : tué pendant ton tour (carte, familier en fin de tour), il frappe la plus chère des cartes en main ;
  tué par un Cast résolu au début de ton tour (main encore vide), par une Trap ou par son DoT : rien. Passif
  affiché sous ses PV (icône `spell_shadow_curseofmannoroth`, infobulle `On death: hexes the costliest card in
  your hand.`).
- **Take a Trophy** : l'intention affiche le total (9 + 3 × cartes Hexed), recalculé quand tu en récupères une.

### Groupes types (PV totaux ; Westfall × 1,36 : facile ≈ 45, normal ≈ 69)

| Genre | Composition | PV | Ce qu'il teste |
|---|---|---|---|
| facile | Lashtail Raptor ×2 | 42–48 | dégâts réguliers |
| facile | Shadowmaw Panther | 26–29 | encaisser le Ravage du tour 1 |
| facile | Mistvale Gorilla | 36–40 | finir avant la Strength |
| facile | Bloodscalp Witch Doctor + Lashtail Raptor | 42–48 | premier Hex, sans punition |
| normal | Bloodscalp Headhunter + Bloodscalp Witch Doctor | 51–58 | Hex + punition : interrompre ou récupérer |
| normal | Skullsplitter Mystic + Lashtail Raptor ×2 | 66–75 | tuer le soigneur-lanceur sous la pression |
| normal | Zanzil Naga + Skullsplitter Mystic | 54–61 | ordre des morts et main vide |
| normal | Bloodsail Swashbuckler ×2 | 58–64 | Cast du joueur coupés (Kick) |
| normal | Mistvale Gorilla + Bloodscalp Witch Doctor | 57–64 | course contre la Strength, Hex en plus |
| normal | Shadowmaw Panther + Bloodscalp Headhunter | 56–63 | premier tour lourd |
| rencontre | `event_panthers` : Shadowmaw Panther ×2 | 52–58 | (Nesingwary) |
| rencontre | `event_bloodsail` : Bloodsail Swashbuckler ×2 | 58–64 | (Booty Bay) |
| rencontre | `event_hexers` : Skullsplitter Mystic + Bloodscalp Witch Doctor | 45–51 | deux Hex par tour possibles |
| rencontre | `event_mokk` : Mokk the Savage (élite) ; `event_bangalash` : King Bangalash (élite) | | |

## 4. Élites (3)

| id | Nom | PV | Intentions | Motif | Idée de combat |
|---|---|---|---|---|---|
| `king_bangalash` | King Bangalash | 100 | **Pounce** : attack 22, interrupts. **Rake** : attack 6 × 3. **Call the Pride** : summon `young_stranglethorn_tiger` × 2 (s'il en reste 2 vivants : **Roar**, buff_allies Strength 2). **Maul** : attack 18. | `pounce`, `rake`, `call`, `maul` ; départ fixe | Le coup d'ouverture annoncé (l'idée d'Ambush) puis des renforts : zone ou focalisation. |
| `young_stranglethorn_tiger` | Young Stranglethorn Tiger (serviteur) | 12–14 | **Bite** : attack 6. | `bite` | Serviteur (`minion`). |
| `mokk_the_savage` | Mokk the Savage | 98 | **Thrash** : attack 7 × 2. **Pound** : attack 17. **Beat Chest** : block 12, buff Strength 2. À ≤ 49 PV, une fois : « Mokk goes berserk! », buff Strength 4, motif `thrash`, `pound`. | `thrash`, `pound`, `beat_chest` | Le seuil : faire passer Mokk de 50 % à mort dans le même tour, ou subir sa rage. |
| `zanzil_the_outcast` | Zanzil the Outcast | 90 | **Hex** (cast) : hex ; si une carte est frappée, summon `zanzil_zombie`. **Shadow Bolt** : attack 16. **Zanzil's Mixture** : attack 8, buff_allies Strength 2. À sa mort, les zombies meurent. | `hex`, `bolt`, `hex`, `mixture` | Chaque Hex qui passe lève un zombie : le budget d'Interrupt décide du nombre d'adversaires. |
| `zanzil_zombie` | Zanzil Zombie (serviteur) | 13–15 | **Claw** : attack 6. | `claw` | Serviteur (`minion`). |

Repères : Harvest Golem 72 et Rhahk'Zor 75 → 98 et 102. Bangalash fait 22 au tour 1 (Smash × 1,36 = 26) mais
annoncé et seul ; Zanzil frappe peu lui-même (6 par tour en moyenne) et fait tout passer par les zombies : à
surveiller en simulation (PV perdus par élite, nombre de zombies levés).

## 5. Boss : Jin'do the Hexxer

**Pourquoi un boss troll plutôt que King Bangalash.** Le boss est l'examen de la mécanique. Bangalash ne lance pas
de Hex : le dernier combat de la zone n'aurait rien à voir avec la règle apprise. Jin'do est le Hexxer de
Zul'Gurub, dans Stranglethorn, et ses sorts de WoW (Hex, Powerful Healing Ward, Brain Wash Totem) donnent
directement les phases. Le précédent existe : Edwin VanCleef est un boss de donjon de Westfall. Bangalash reste
dans la zone comme élite (avec son ouverture) et dans une rencontre.

Combat aux portes de Zul'Gurub (fond `ruins`). Boss : immunisé à Stunned, donc seul l'Interrupt arrête ses Hex.

| id | Nom | PV | Intentions |
|---|---|---|---|
| `jindo` | Jin'do the Hexxer | 128 | **Hex** (cast) : hex. **Shadow Bolt** : attack 19. **Powerful Healing Ward** : summon `healing_ward` (si un Ward vit déjà : Shadow Bolt). **Shadow Volley** (phase 2) : attack 8 × 3. |
| `healing_ward` | Powerful Healing Ward (serviteur) | 16 | **Healing Ward** : heal_ally 12 (l'allié le plus entamé, donc Jin'do). N'attaque pas. |
| `brain_wash_totem` | Brain Wash Totem (serviteur) | 14 | **Brain Wash** (cast) : hex, à chaque tour. Peut être étourdi (pas un boss). |

**Phase 1 (128 → 65 PV)** : motif `hex`, `bolt`, `ward`, `bolt`. Le Ward soigne 12 par tour tant qu'il vit : le
tuer coûte 16 dégâts, l'ignorer coûte 12 par tour.
**Bascule (≤ 64 PV, une fois, `onDamaged`)** : « Your soul belongs to Hakkar! », summon `brain_wash_totem`.
**Phase 2** : motif `volley`, `hex`, `bolt`. Le totem ajoute un Hex par tour : deux Hex certains tours.

Durée visée : 5 à 7 tours. Estimation à 22 dégâts par tour du joueur : 128 PV + un ou deux Ward (16 chacun ou
12 de soin par tour) + le totem (14) ≈ 150 à 170 dégâts, soit 6 à 7 tours. Dégâts bruts : phase 1 ≈ 9,5 par
tour (38 sur 4 tours), phase 2 ≈ 14 par tour (8 × 3 + 19 sur 3 tours), plus le coût des Hex (≈ 1 mana chacun).
VanCleef × 1,36 ≈ 18 par tour en dégâts seuls : Jin'do frappe moins et taxe davantage la main ; à régler par
simulation sur les PV perdus contre le boss.

## 6. Rencontres (8)

Format de `Data/Events.lua` ; `act = 4` (zone 4). Décors existants : `camp`, `coast`, `ruins`, `road`. Six
ordinaires, deux rares (combat d'élite). Chaque rencontre garde une réponse sans prérequis.

```lua
event("nesingwary_expedition", {
  name = "Nesingwary's Expedition", act = 4, tier = 0,
  speaker = "Hemet Nesingwary Jr.", npc = "hemet_nesingwary", scene = "camp",
  text = "\"I'm writing the definitive book on big game in Stranglethorn, and chapter four needs a Shadowmaw "
    .. "panther. My hunters are out after King Bangalash. Bring me two pelts and I'll pay you.\"",
  choices = {
    { label = "Hunt the panthers", outcome = "Fight 2 Shadowmaw Panthers: usual reward + 25g",
      result = "You track the panthers to a clearing south of the camp.",
      effects = { { "fight", "event_panthers", gold = 25 } } },
    { label = "Shoot with his hunters", outcome = "-6 HP, upgrade a card of your choice",
      result = "Ajeck Rouack shows you how to lead a moving target. The rifle kicks hard.",
      effects = { { "loseHp", 6 }, { "upgrade" } } },
    { label = "Rest at the camp", outcome = "+12 HP",
      result = "Barnil Stonepot serves you a plate of tiger meat. You sleep by the fire.",
      effects = { { "heal", 12 } } },
  },
})

event("booty_bay_docks", {
  name = "The Booty Bay Docks", act = 4, tier = 0,
  speaker = "Baron Revilgaz", npc = "baron_revilgaz", scene = "coast",
  text = "\"The Bloodsail sank two of my ships this month. I pay for every pirate you put in the water. "
    .. "If you'd rather spend than fight, my warehouse is open.\"",
  choices = {
    { label = "Hunt the Bloodsail", outcome = "Fight 2 Bloodsail Swashbucklers: usual reward + 30g",
      result = "You find two Bloodsail pirates loading a rowboat at the end of the pier.",
      effects = { { "fight", "event_bloodsail", gold = 30 } } },
    { label = "Buy from the warehouse", outcome = "Pay 45g, a relic",
      result = "\"No refunds. This is Booty Bay.\"",
      effects = { { "pay", 45 }, { "relic" } } },
    { label = "Sell him a potion", outcome = "Lose a potion, +40g",
      when = { { "potion" } },
      result = "Revilgaz checks the seal on the bottle and counts out the coins.",
      effects = { { "losePotion" }, { "gold", 40 } } },
    { label = "Leave", outcome = "Nothing",
      result = "You leave the docks.",
      effects = {} },
  },
})

event("fishing_extravaganza", {
  name = "The Fishing Extravaganza", act = 4, tier = 1,
  speaker = "Riggle Bassbait", npc = "riggle_bassbait", scene = "coast",
  text = "\"The Stranglethorn Fishing Extravaganza starts in an hour. The first angler to bring me forty "
    .. "Speckled Tastyfish wins the prize. Enter, or buy a basket from someone who gave up.\"",
  choices = {
    { label = "Enter the contest", outcome = "35%: a relic, else -7 HP",
      effects = { { "gamble", 0.35,
        win = { { "relic" } },
        winText = "You bring in forty tastyfish first. Riggle hands you the prize.",
        lose = { { "loseHp", 7 } },
        loseText = "A shark takes your catch and bites your arm. You finish last." } } },
    { label = "Buy a basket of tastyfish", outcome = "Pay 20g, +15 HP",
      result = "You eat grilled tastyfish on the pier.",
      effects = { { "pay", 20 }, { "heal", 15 } } },
    { label = "Fish off the pier", outcome = "+7 HP",
      result = "You catch three small fish and cook them.",
      effects = { { "heal", 7 } } },
  },
})

event("hexed_partner", {
  name = "The Frog in the Satchel", act = 4, tier = 1,
  speaker = "Surveyor Brannock", npc = "explorer_dwarf", scene = "ruins",
  text = "\"A Skullsplitter witch doctor turned my partner into a frog at Zul'Mamwe. I have the cure, but "
    .. "the trolls are still in the ruins. Clear them out, or buy my copies of the tablets.\"",
  choices = {
    { label = "Clear the ruins", outcome = "Fight a Mystic and a Witch Doctor: usual reward + 20g",
      result = "Two troll casters are guarding the tablets.",
      effects = { { "fight", "event_hexers", gold = 20 } } },
    { label = "Buy his tablet copies", outcome = "Pay 30g, upgrade a card of your choice",
      result = "Brannock unrolls his rubbings and explains the troll glyphs.",
      effects = { { "pay", 30 }, { "upgrade" } } },
    { label = "Carry the frog to Booty Bay", outcome = "-5 HP, a potion",
      result = "The frog bites you twice on the road. Brannock pays you with a potion.",
      effects = { { "loseHp", 5 }, { "potion" } } },
  },
})

event("bloodsail_cache", {
  name = "The Bloodsail Powder Store", act = 4, tier = 2,
  speaker = "Fleet Master Seahorn", npc = "fleet_master_seahorn", scene = "coast",
  text = "\"The Bloodsail keep their powder in a cove south of Booty Bay. Blow it up and their ships stay in "
    .. "port for a month. Their captain's charts are in the same tent.\"",
  choices = {
    { label = "Blow up the powder", outcome = "-8 HP, +50g",
      result = "The store goes up while you are still on the beach. Seahorn pays in full.",
      effects = { { "loseHp", 8 }, { "gold", 50 } } },
    { label = "Steal the charts", outcome = "50%: a relic, else -12 HP",
      effects = { { "gamble", 0.5,
        win = { { "relic" } },
        winText = "You take the charts and a strongbox from the captain's tent.",
        lose = { { "loseHp", 12 } },
        loseText = "A guard sees you. You swim back to Booty Bay under fire." } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Then I'll find someone else.\"",
      effects = {} },
  },
})

event("zandalar_envoy", {
  name = "Yojamba Isle", act = 4, tier = 2,
  speaker = "Rin'wosho the Trader", npc = "rinwosho", scene = "coast",
  text = "\"The Zandalar watch Zul'Gurub from this island. Jin'do serves Hakkar now, and his hexes reach "
    .. "Booty Bay. Our mojo protects against them. It costs gold, or blood.\"",
  choices = {
    { label = "Buy a Zandalar charm", outcome = "Pay 50g, Shrunken Head (relic)",
      result = "\"Wear it where the witch doctors can see it.\"",
      effects = { { "pay", 50 }, { "relic", "shrunken_head" } } },
    { label = "Pay in blood", outcome = "-6 max HP, one of 3 rare cards",
      result = "Rin'wosho cuts your palm and mixes the blood into the paint of a tablet.",
      effects = { { "loseMaxHp", 6 }, { "cardChoice", n = 3, rarity = "rare" } } },
    -- carte neutre de la zone, absente tant qu'elle n'est pas débloquée
    { label = "Buy a jungle remedy", outcome = "Pay 25g, Jungle Remedy (card)",
      when = { { "unlocked", "jungle_remedy", hide = true } },
      result = "\"Drink it when the frog comes.\"",
      effects = { { "pay", 25 }, { "card", "jungle_remedy" } } },
    { label = "Leave", outcome = "Nothing",
      result = "You take the boat back to the mainland.",
      effects = {} },
  },
})

event("stranglethorn_fever", {
  name = "Stranglethorn Fever", act = 4, tier = 1, rarity = "rare",
  speaker = "Witch Doctor Unbagwa", npc = "witch_doctor_unbagwa", scene = "ruins",
  when = { { "hpAbove", 0.6 } },
  text = "\"Fin Fizracket has the fever, and only the heart of Mokk cures it. Give me the gorilla fangs and "
    .. "I call him. When he comes, you fight him, not me.\"",
  choices = {
    { label = "Call Mokk", outcome = "Elite fight: elite reward + 40g",
      result = "Unbagwa beats his drum. Mokk the Savage comes out of the trees.",
      effects = { { "fight", "event_mokk", kind = "elite", gold = 40 } } },
    { label = "Take his mojo", outcome = "-5 max HP, one of 3 rare cards",
      result = "Unbagwa paints a troll sign on your chest. You feel weaker.",
      effects = { { "loseMaxHp", 5 }, { "cardChoice", n = 3, rarity = "rare" } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Fin will wait. Or not.\"",
      effects = {} },
  },
})

event("bangalash_hunt", {
  name = "Big Game Hunter", act = 4, tier = 2, rarity = "rare",
  speaker = "Ajeck Rouack", npc = "ajeck_rouack", scene = "camp",
  when = { { "hpAbove", 0.6 } },
  text = "\"King Bangalash leads the tigers on the hill north of camp. Hemet wants his head for the trophy "
    .. "wall. Two of my hunters went up yesterday and came back on stretchers.\"",
  choices = {
    { label = "Hunt King Bangalash", outcome = "Elite fight: elite reward + 40g",
      result = "You climb the hill. Bangalash is waiting on the rocks above you.",
      effects = { { "fight", "event_bangalash", kind = "elite", gold = 40 } } },
    { label = "Tend the wounded hunters", outcome = "-5 HP, a potion",
      result = "You change their bandages all afternoon. Ajeck gives you a potion.",
      effects = { { "loseHp", 5 }, { "potion" } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Hemet will find someone else.\"",
      effects = {} },
  },
})
```

## 7. Cartes de zone (5, rares)

Cartes définitives (épiques, pivots) : voir `docs/zones/cartes-de-zone.md`.

- Shadow Covenant (Priest)
- Titan's Grip (Warrior)
- Fingers of Frost (Mage)
- Echoing Reprimand (Rogue)
- Roar of Sacrifice (Hunter)

## 8. Commun débloqué par la première victoire du compte

### Cartes neutres (2)

| id | Nom (objet) | Métier | Rareté | Coût | Type | Plaque | Texte | Amélioré | Icône | Repère |
|---|---|---|---|---|---|---|---|---|---|---|
| `jungle_remedy` | Jungle Remedy | First Aid | uncommon | 0 | Skill | Exhaust | Restore your Hexed cards to your hand. / Remove your negative effects. / Draw 1. | … / Draw 2. | `inv_potion_12` | Insignia of the Alliance (rare) retire les effets négatifs à chaque combat ; ici une fois. |
| `rumsey_rum_black_label` | Rumsey Rum Black Label | Cooking (boisson de Booty Bay) | common | 0 | Skill | Exhaust | Gain 6 Absorb. | Gain 9 Absorb. | `inv_drink_04` | Inner Fire : 5 Absorb pour 1 mana, à chaque cycle ; ici gratuit mais une fois. Carte à 0 qui aide à vider la main. |

Jungle Remedy : une carte Hexed dont l'original ne tient pas dans la main (10 cartes) va à la défausse sous sa
forme d'origine. Hors de Stranglethorn, elle reste un nettoyage (Sundered, Demoralized, DoT ennemi) avec pioche.

### Bibelots communs (3)

| id | Nom (objet) | Rareté | Effet | Icône |
|---|---|---|---|---|
| `green_hills_of_stranglethorn` | The Green Hills of Stranglethorn | common | On the first turn of each combat, draw 1 more card. | `inv_misc_book_09` |
| `shrunken_head` | Shrunken Head | uncommon | The first enemy cast of each combat fails. | `inv_misc_head_troll_01` |
| `gorilla_fang` | Gorilla Fang | common | On the first turn of each combat, Attacks deal 2 more per hit. | `inv_misc_monsterfang_01` |

Repères : Harvest Golem Cog (rare, +2 cartes au premier tour), Talisman of Focus (inhabituel, première
interruption subie sans effet), Rhok'delar (rare du Hunter, +5 au premier tour). Shrunken Head vaut contre un
Hex, un Fireball de Conjurer ou le premier Hex de Jin'do (il agit aussi sur un boss).

### Case de parcours : Gurubashi Arena

Nouvelle case de carte, commune à toutes les zones une fois débloquée (une au plus par expédition, à partir de
l'étape 3). Avant d'entrer, le joueur voit le groupe ennemi complet (un groupe normal de la zone, PV + 15 %).
- **Fight** : combat ; récompense habituelle + 25 po, et les 3 cartes offertes sont tirées une rareté au-dessus
  (commune → inhabituelle, inhabituelle → rare).
- **Leave** : rien, la case est passée.
PNJ : Short John Mithril (annonceur de l'arène dans WoW). Icône de la case : `achievement_arena_2v2_1`.
Décision : un combat choisi en connaissance de cause, contre de meilleures cartes.

## 9. Bibelots de clé (3)

Première victoire de la classe à la clé +1, +3, +5 ; communs aux cinq classes ; plus forts que les communs.

| Clé | id | Nom (objet) | Rareté | Effet | Icône |
|---|---|---|---|---|---|
| +1 | `nesingwary_4000` | Nesingwary 4000 | rare | At the start of each combat, deal 10 to the enemy with the most HP. | `inv_weapon_rifle_04` |
| +3 | `jindos_bag_of_whammies` | Jin'do's Bag of Whammies | rare | Whenever you interrupt an enemy cast: +1 mana, draw 1. | `inv_misc_bag_10` |
| +5 | `zandalarian_hero_charm` | Zandalarian Hero Charm | rare | At the end of your turn, you may keep 1 card in hand. It costs 1 less next turn. | `inv_zulgurubtrinket` |

- Nesingwary 4000 : dégâts hors carte (ni Strength ni Sundered), boss compris. Repère : Tobin's Pocketknife (DoT 3
  à tous, rare).
- Bag of Whammies : avec les Interrupt à 0 mana et Cooldown 2, environ +1 mana tous les deux tours contre des
  lanceurs ; rien contre un groupe sans Cast.
- Zandalarian Hero Charm (décision du joueur du 14/11/2026) : un Retain au choix par tour, et la carte gardée
  coûte 1 de moins (minimum 0) au tour suivant seulement (la carte gardée reste exposée au Hex : c'est voulu). Les
  bots choisissent la carte la mieux notée non jouable ce tour, de préférence de coût 1 ou plus.

## 10. Modèles et icônes

Le MCP `wow` ne trouve pas l'installation du jeu (`wow_creature_search` : « No World of Warcraft install found.
Set WOW_INSTALL_PATH. », pour les saveurs par défaut, `forever` et `classic`) : **aucun identifiant de créature ni
d'affichage n'a pu être obtenu par le MCP**. Aucune synchronisation lancée. Deux créatures figurent dans le cache
du client Forever (`tools/wdb_creatures.py`, lecture seule, comme `UI/Art.lua`) ; le reste est « non trouvé ».
`wow_model_search` donne des fichiers de modèle (FileDataID, utilisables par `Model:SetModel`, sans les peaux
propres à la créature) ; `wow_icon_search` et `~/Téléchargements/ICONS/` confirment les icônes.

| Unité | Créature | Affichage | Modèle de repli (m2, wow_model_search) | Icône du médaillon |
|---|---|---|---|---|
| Bloodscalp Witch Doctor | non trouvé | non trouvé | 126248 `creature/troll/trolljunglecaster.m2` | `inv_misc_head_troll_01` |
| Skullsplitter Mystic | non trouvé | non trouvé | 126248 `trolljunglecaster.m2` | `inv_misc_head_troll_01` |
| Bloodscalp Headhunter | non trouvé | non trouvé | 126244 `creature/troll/troll.m2` | `inv_spear_04` |
| Zanzil Naga | non trouvé | non trouvé | 125078 `creature/nagamale/nagamale.m2` | `achievement_boss_elitenagamale` |
| Shadowmaw Panther | non trouvé | non trouvé ; repli : Young Panther (683, affichage 2437, cache) | 126171 `creature/tiger/tiger.m2` | `ability_mount_blackpanther` |
| Lashtail Raptor | non trouvé | non trouvé | 125559 `creature/raptor/raptor.m2` | `ability_hunter_pet_raptor` |
| Mistvale Gorilla | non trouvé | non trouvé | 124263 `creature/gorilla/gorilla.m2` | `ability_hunter_pet_gorilla` |
| Bloodsail Swashbuckler | non trouvé | non trouvé | non trouvé (humain équipé) | `inv_misc_bandana_01` |
| King Bangalash | non trouvé | non trouvé | 126171 `tiger.m2` | `ability_mount_jungletiger` |
| Young Stranglethorn Tiger | **681** (cache Forever) | **138617** (cache Forever) | 126173 `creature/tiger/tigercub.m2` | `ability_mount_jungletiger` |
| Mokk the Savage | non trouvé | non trouvé | 124263 `gorilla.m2` | `ability_hunter_pet_gorilla` |
| Zanzil the Outcast | non trouvé | non trouvé | 126248 `trolljunglecaster.m2` | `achievement_zulgurub_zanzil` |
| Zanzil Zombie | non trouvé | non trouvé | 126570 `creature/zombie/zombie.m2` | `spell_shadow_raisedead` |
| Jin'do the Hexxer | non trouvé | non trouvé | 126247 `creature/troll/trolljungleboss.m2` | `achievement_zulgurub_jindo` (512828) |
| Powerful Healing Ward | non trouvé | non trouvé | 126018 `creature/spells/healingtotem.m2` | `spell_nature_healingwavegreater` |
| Brain Wash Totem | non trouvé | non trouvé | 967881 `creature/spells/orctotem_01.m2` | `spell_shadow_shadowworddominate` |
| PNJ des rencontres (Hemet Nesingwary Jr., Ajeck Rouack, Baron Revilgaz, Riggle Bassbait, Fleet Master Seahorn, Rin'wosho the Trader, Witch Doctor Unbagwa, Surveyor Brannock, Short John Mithril) | non trouvé | non trouvé | non trouvé | — |

Intentions et états : Hex `spell_shaman_hex` (237579), Death Hex `spell_shadow_curseofmannoroth`, Shadow Bolt
`spell_shadow_shadowbolt`, Healing Wave `spell_nature_healingwavegreater`, Ravage `ability_druid_supriseattack`,
Rake `ability_druid_rake`. Carte Hexed : `spell_shaman_hex`.

Icônes des cartes et bibelots (toutes présentes dans `~/Téléchargements/ICONS/` ; FileDataID par
wow_icon_search quand vérifié) : `spell_shadow_fingerofdeath` (136157), `ability_warrior_shieldreflection`
(132361), `spell_arcane_arcane02`, `spell_nature_nullifydisease` (136066), `ability_hunter_snaketrap` (132211),
`inv_potion_12`, `inv_drink_04`, `inv_misc_book_09`, `inv_misc_head_troll_01`, `inv_misc_monsterfang_01`,
`inv_weapon_rifle_04`, `inv_misc_bag_10`, `inv_zulgurubtrinket` (135723), `achievement_arena_2v2_1`.

Noms d'objets non vérifiables par le MCP (pas de recherche d'objets) et tirés de mémoire : Jungle Remedy,
Shrunken Head, Gorilla Fang, Rumsey Rum Black Label, Jin'do's Bag of Whammies, Zandalarian Hero Charm,
Nesingwary 4000, The Green Hills of Stranglethorn. « Surveyor Brannock » est un PNJ plausible, pas un PNJ réel.

## 11. Questions ouvertes

1. **Ambush abandonné.** Avec Hex seul, les panthères et Bangalash frappent fort au tour 1 mais tu vois le coup
   venir et tu joues avant. Avec Ambush en plus, tu commencerais certains combats déjà à −14 PV sans rien pouvoir
   y faire (le Mage à 42 PV le sentirait le plus). Garder Hex seul ?
2. **Boss : Jin'do plutôt que King Bangalash.** Avec Jin'do, le dernier combat se gagne en gardant ses Interrupt
   pour ses Hex pendant 6 tours, aux portes de Zul'Gurub. Avec Bangalash, c'est un tigre et ses petits, sans
   aucun Hex : la règle apprise dans la zone ne servirait pas au boss.
3. **Hex sur main vide = rien.** Le Rogue, qui vide souvent sa main avec ses cartes à 0, y échappera presque
   toujours. Autre choix : le Hex frappe la prochaine carte de ta pioche ; alors personne n'y échappe sans
   Interrupt, Stunned ou mort du lanceur, et garder une carte faible en main ne protège plus rien.
4. **Coût de la grenouille : 1 mana.** À 1, récupérer Pyroblast coûte 3 mana ce tour-là ; un Hex vaut environ un
   mana perdu. À 0, le Hex n'est plus qu'un retard d'une carte et la zone devient nettement plus facile.
5. **Cartes de zone toutes tournées vers l'Interrupt.** Les cinq coupent des sorts, chacune par le moteur de sa
   classe. Contre Edwin VanCleef ou
   un groupe de bêtes, Mind-numbing Poison et Snake Trap valent peu (Snake Trap reste un DoT 5 à tous). Accepter
   des rares situationnelles, ou en remplacer une par une carte forte partout (par exemple un Rogue qui gagne à
   vider sa main) ?

## 12. Implémentation (nuit du 13 au 14/11/2026)

Fichiers : `Data/Zones/Stranglethorn.lua` (ennemis, groupes, carte Hexed, commun, bibelots de clé, rencontres, décors
de la zone), `Core/ZoneRules/stranglethorn.lua` (règle, `ns.Stranglethorn`, case Gurubashi Arena, mots du langage),
`UI/Art/Zones/stranglethorn.lua` (modèles, icônes, vue de zone, six décors peints), `Sim/zones/stranglethorn.lua`
(bot), `Sim/tests_zone_stranglethorn.lua` (34 tests), `Sim/ui_zone_stranglethorn.lua` (harnais « UZS »).

### La règle telle que codée

1. Un Hex est une incantation ennemie (move `cast = true`, action `{ "hex" }`), annoncée au début du tour,
   résolue au tour du lanceur ; un Interrupt l'annule, un lanceur étourdi (Stunned) perd son tour.
2. Carte visée : `ns.Stranglethorn.hexTarget` = la plus chère des cartes en main (coût actuel, égalité : la plus à
   gauche) ; **jamais une carte Hexed** (ajout : hexer une grenouille ne ferait rien). Plusieurs lanceurs : cartes
   différentes, dans l'ordre d'action (`ns.Stranglethorn.plan`, lu aussi par l'interface et les bots).
3. Verrouillage au crochet `onHandEnd` (après le familier, avant la défausse) : `z.locks[uid de l'ennemi] = uid de
   la carte` ; main vide : « No card » (journal `hex_fizzle`).
4. Résolution : la carte verrouillée, retrouvée dans la main (Retain) ou la défausse, est transformée en Hexed
   (`Combat.transformCard`) ; sinon le Hex échoue. Verrous non résolus (lanceur mort de son DoT, tour sauté) effacés
   à la fin de la phase ennemie.
5. Hexed : coût 1, Skill, `token`, `vanish`, `{ "restore" }` ; Death Hex (champ `deathHex` du Zanzil Naga) : mort
   pendant le tour du joueur (étape `play` ou `turnEnd`, ni Trap ni DoT) → Hex immédiat (`hex_now`).

### Écarts à la fiche, et pourquoi

- **Rencontres** : `zone = "stranglethorn"` (plus de champ `act`) et `tier = 0` pour les huit : ce sont des
  rencontres de la zone, pas du commun (avec les paliers 1 et 2 de la fiche, `Meta.commonContent` les aurait
  annoncées comme débloquées par Westfall ou Duskwood).
- **Textes impersonnels** (langage des cartes : aucun « your ») : Hexed « Return the original card to hand. » (le
  nom de la carte d'origine est déjà écrit au-dessus par le socle) ; Jungle Remedy « Restore all Hexed cards to
  hand. ».
- **Mokk** : la rage à 49 PV est une phase du moteur commun (seuil à 50 %, cran sur la barre, bandeau « Berserk »),
  sans réplique (un gorille ne parle pas).
- **King Bangalash** : Call the Pride devient Roar quand les deux tigres vivent (IA à motif propre).
- **Jin'do** : la bascule à 50 % est une phase (`phases`, cran affiché, réplique « Your soul belongs to Hakkar! »).
  Ajouts d'équilibrage (voir plus bas) : Delusions of Jin'do (intention « watch » : coupe l'incantation en cours,
  sinon 12 dégâts) à la place du second Shadow Bolt de la phase 1, Shadow Bolt qui interrompt (s'il fait perdre des
  PV), Shadow Volley qui coupe l'incantation même à travers l'Absorb.
- **Interruptions directes** (Kick du Swashbuckler, Pounce de Bangalash, Shadow Volley) : `{ "interrupt" }` en tête
  de l'action, l'Absorb ne protège plus le Cast ; Shadow Bolt des sorciers, Lightning Bolt du Mystic, Shadow Bolt de
  Zanzil interrompent s'ils font perdre des PV. Raison : sans cela le Mage, dont les Cast échappent au Hex par
  construction, dominait la zone de 15 à 20 points.
- **Zandalarian Hero Charm** (+5, revu le 14/11/2026) : `retainPicks` comme le Traveler's Backpack (commun,
  palier 3), plus une réduction : la carte gardée par ce choix (`onCardKept`, `"pick"`) coûte 1 de moins pendant le
  tour suivant (crochet `cost`, minimum 0 par `Combat.cost`). Réduction portée par l'état du combat
  (`relicState.hero_charm_uid` et `hero_charm_round`, données simples : clone et sauvegarde), jamais par
  l'instance ; perdue au tour d'après, et effacée quand la carte est jouée, piochée de nouveau, transformée ou
  retirée. Avec le Traveler's Backpack : `retainPicks` = 2 mais un seul choix géré ; la carte gardée reçoit la
  réduction (−1, pas −2). Cas limites : carte gardée puis Hexed (verrouillée par le Hex au même tour) → la Hexed
  coûte 1 sans réduction et l'originale rendue revient à plein coût ; carte Hexed gardée → 0 ; carte à 0 → 0 ;
  aucune carte à coût X dans le jeu. Texte de 80 caractères (limite des bibelots du harnais). Bot : +2 à la note
  des cartes de coût 1 ou plus quand le Charm est porté.
- **Jin'do's Bag of Whammies** : seulement les interruptions faites par une carte pendant le tour du joueur (pas
  celle de la Shrunken Head). Icône `INV_Misc_Bag_10_Green` (la `INV_Misc_Bag_10` est déjà la Defias Purse).
- **Shrunken Head** : la première incantation ennemie est interrompue dès son annonce (« Interrupted » visible, la
  carte n'est jamais visée).
- **Gurubashi Arena** : case commune à toutes les zones (palier 4), à la place d'une rencontre, une par expédition
  dès l'étape 3 ; rencontre `node = true` à groupe tiré à l'entrée (texte « %g »), PV + 15 %, cartes d'un cran,
  + 25 po.
- **Animation** de la carte qui s'envole vers le lanceur : non faite ; texte flottant « Hexed: <carte> » sur le
  héros et « No card » / « Hex fails » sur le lanceur, compteur « N Hexed » en haut.

### Interface (ce qui se lit avant de jouer)

Bulle « Hex » à l'icône `spell_shaman_hex` ; infobulle « Target now: <carte>. It changes as you play cards. » ;
sous l'intention du lanceur, pastille au nom de la carte visée (« No card » grisée si la main est vide) ; dans la
main, liseré vert et icône du Hex sur la carte visée (mise à jour à chaque rendu), infobulle « Hex: <lanceur> turns
this card into a Hexed card at the end of your turn. Play it, or interrupt or stun the caster. » ; pastille
« Death Hex » sous le Zanzil Naga ; compteur « N Hexed » en haut (Take a Trophy en dépend, sa bulle est recalculée).
Mots expliqués : Hex, Hexed (`L.zoneKeyword`).

### Nombres finaux (après réglage)

| Unité | PV | Intentions |
|---|---|---|
| Bloodscalp Witch Doctor | 21–24 | Hex ; Shadow Bolt 9 (interrompt) |
| Skullsplitter Mystic | 24–27 | Hex ; Healing Wave 10 ; Lightning Bolt 8 (interrompt) |
| Bloodscalp Headhunter | 30–34 | Throw Spear 6 × 2 ; Take a Trophy 10 + 3 par Hexed |
| Zanzil Naga | 30–34 | Trident 12 ; Coil 8 Absorb + 6 ; Death Hex |
| Shadowmaw Panther | 26–29 | Ravage 15 ; Prowl 10 Absorb ; Claw 10 |
| Lashtail Raptor | 21–24 | Bite 10 ; Lashing Tail 4 × 2 |
| Mistvale Gorilla | 36–40 | Pound 14 ; Beat Chest 8 Absorb, Strength 2 |
| Bloodsail Swashbuckler | 29–32 | Cutlass 11 ; Dirty Trick 5 + Demoralized 1 ; Kick : coupe le Cast + 8 |
| King Bangalash (élite) | 94 | Pounce : coupe le Cast + 18 ; Rake 4 × 3 ; Call the Pride (2 tigres 10–12 PV, Bite 6) / Roar ; Maul 13 |
| Mokk the Savage (élite) | 98 | Thrash 6 × 2 ; Pound 15 ; Beat Chest 12 Absorb, Strength 2 ; à 49 PV Strength 3, Thrash / Pound |
| Zanzil the Outcast (élite) | 96 | Hex (+ zombie 13–15 PV, Claw 7) ; Shadow Bolt 16 (interrompt) ; Mixture 8 + Strength 2 aux alliés |
| Jin'do the Hexxer (boss) | 176 | Hex, Shadow Bolt (coupe le Cast même à travers l'Absorb + 26), Powerful Healing Ward (16 PV, soin 8), Delusions (coupe le Cast, sinon coup ordinaire de 13) ; à 88 PV Brain Wash Totem (10 PV, Hex à chaque tour), puis Shadow Volley (coupe le Cast + 10 × 3), Hex, Shadow Bolt |

Passe de difficulté du 14/11/2026 (cible de la zone : 64 %, écart ≤ 10 ; détail plus bas, « Passe de difficulté ») :
élites adoucis, Jin'do plus long (134 → 176 PV) et moins pointu (Shadow Bolt 27 → 26, Delusions 12 → 13 mais
devenue un coup ordinaire), Shadow Bolt de Jin'do qui coupe à travers l'Absorb. Les mesures ci-dessous sont
celles d'avant la passe.

### Mesures (`runner=expedition zone=stranglethorn zones=3 level=7 key=0`, 1000 expéditions par classe)

| Classe | Victoire sans épique | Victoire, épique au choix du bot | PV perdus / combat normal | Tours normal | Tours boss | Boss gagné (sans épique) |
|---|---|---|---|---|---|---|
| Priest | 61,6 % | 67,0 % | 10,0 | 4,2 | 8,1 | 72,6 % |
| Warrior | 66,2 % | 72,7 % | 11,1 | 3,6 | 6,8 | 79,1 % |
| Mage | 71,5 % | 76,4 % | 6,9 | 3,5 | 5,9 | 81,0 % |
| Rogue | 60,8 % | 83,5 % | 7,6 | 3,2 | 5,4 | 74,5 % |
| Hunter | 69,5 % | 88,6 % | 7,8 | 3,1 | 5,7 | 72,9 % |

Écart entre classes sans épique : 10,7 points (Rogue 60,8 – Mage 71,5). Avec épique : 21,6 points, porté par
les épiques du Rogue (+22,7) et du Hunter (+19,1) contre +5 pour le Priest : un écart des épiques, pas de la zone.
Clés (Rogue, sans épique) : +0 60,8 %, +1 54,3 %, +3 43,7 %, +5 35,5 % (≈ 5 points par niveau).

Hex (par combat normal / élite / boss, Priest) : annoncés 1,15 / 1,04 / 4,73, posés 0,74 / 0,75 / 2,90,
interrompus 0,10 / 0,09 / 0,48, Hexed rejouées 0,17 / 0,21 / 1,12 ; le Mage en subit moins (posés 0,55 / 0,44 /
2,27 : ses Cast quittent la main).

Réglage, dans l'ordre (600 à 1000 expéditions par classe) : chiffres de la fiche → Priest 65, Mage 84, Hunter 86
(Bangalash à 43 % pour le Priest, boss trop facile) ; Bangalash adouci, Jin'do et Zanzil plus durs → Mage et
Hunter toujours 15 points devant ; le levier qui a resserré l'écart est le boss **moins usant** (soin du Ward 8,
totem 10 PV : les classes lentes subissent moins de tours) avec des **interruptions directes** (le Mage perd enfin
des Cast), puis +1 aux coups des ennemis normaux et Shadow Bolt 27 pour redescendre tout le monde. Monter les
élites a fait l'inverse (Priest, Warrior, Rogue −10, Mage et Hunter −2) : rétabli.

### Passe de difficulté (14/11/2026)

Cible de la zone (`docs/zones/decisions.md`, « Difficulté et épiques ») : 64 % de victoires en moyenne au bot de
référence, clé 0, écart entre classes ≤ 10 points. Mesure : `runner=expedition zone=stranglethorn zones=3 level=7
key=0 bot=heuristic`, épiques gagnées en route (sans `epic=`).

| Classe | Avant (800) | Après (1500) | PV perdus / combat normal avant → après | Boss gagné après | Tours boss après |
|---|---|---|---|---|---|
| Priest | 64,8 % | 60,4 % | 9,9 → 9,8 | 64,8 % | 9,0 |
| Warrior | 71,2 % | 63,6 % | 11,1 → 11,4 | 68,4 % | 7,3 |
| Mage | 74,2 % | 69,0 % | 7,0 → 7,2 | 72,7 % | 6,9 |
| Rogue | 65,4 % | 64,1 % | 7,5 → 7,6 | 70,2 % | 6,7 |
| Hunter | 76,0 % | 64,4 % | 8,1 → 7,8 | 66,3 % | 6,3 |
| Moyenne / écart | 70,3 / 11,2 | **64,3 / 8,6** | | | |

Changements :
- **Élites adoucis** (Bangalash Pounce 20 → 18, Maul 14 → 13 ; Mokk Thrash 7 × 2 → 6 × 2, Pound 17 → 15, Berserk
  Strength 4 → 3 ; Zanzil Shadow Bolt 18 → 16). Le Mage et le Hunter les passaient déjà à 94–97 % pour 8 à 12 PV
  (contrôle : Stunned, Freezing Trap) ; Priest, Warrior et Rogue y perdaient 18 à 37 PV et 9 à 17 % des
  expéditions. Ils gagnent 4 à 5 points d'élites, le Hunter 1.
- **Jin'do plus long et moins pointu** : 134 → 176 PV (bascule à 88 PV), Shadow Bolt 27 → 26. Un boss plus
  robuste coûte plus au Warrior qu'au Priest (+12 PV : Warrior −8, Priest −6), un coup plus fort coûte surtout au
  Priest (36 PV max ; essai Bolt, Volley et Delusions +1 à +3 par coup : Priest −12, Warrior −9). D'où des PV
  en plus et des coups un peu plus faibles ; au-delà de 160 PV, le Rogue décroche deux fois plus vite que le Mage.
- **Shadow Bolt de Jin'do** : coupe le Cast même à travers l'Absorb (comme Volley), visible dans le texte.
- **Delusions de Jin'do** : la branche « sinon » est un coup ordinaire de 13 (`attack` à condition, puis
  `interrupt`) au lieu de dégâts directs : la Parry, les Traps et le crochet `beforeHit` s'y appliquent. Le Rogue
  y gagne 5,6 points (sa Parry annulait déjà tout le reste), les autres classes rien.

Essais écartés : DoT 4 sur le Shadow Bolt de Jin'do (Mage −11, mais Priest −14 : le DoT ignore son Absorb) ;
Volley 15 × 2 au lieu de 10 × 3 (Rogue −9 : la Parry n'annule que 8 par coup) ; interruptions directes chez les
lanceurs normaux et chez Mokk (Mage −1, dans le bruit : le bot n'incante pas sous la menace).

Reste : le Mage garde 5 points d'avance (élites à 97 %, boss à 73 %) : son contrôle (Frost Nova, Demoralized) et
ses Absorb couvrent la zone ; les leviers propres à la zone qui le visent (DoT, interruption) frappent plus fort le
Priest ou ne mordent pas. Le combat de boss est long pour le Priest (9 tours en moyenne, p95 13).

### Modèles en repli

Créatures de la version classique (identifiants de mémoire, absents des caches du client : le client les demande au
serveur) en tête, puis affichages du cache Forever de la même famille, puis le fichier de modèle de la fiche :
trolls (Witherbark 3986 / 3990, Frostmane 5608, Frostmane Headhunter 5626) pour les sorciers, le Headhunter,
Zanzil, Jin'do, Rin'wosho et Unbagwa ; Young Panther 2437 (panthère) ; Highland Lashtail 673, Mottled Raptor 960,
Highland Raptor 138620 ; Young Stranglethorn Tiger 681 / 138617 (créature et affichage du cache) et Tigre 5556 pour
Bangalash ; **Zanzil Naga** : créature inconnue, repli Daggerspine Shorehunter (2369, affichage 11255) puis Naga
Siren 11263 ; **gorilles** (Mistvale Gorilla, Mokk) : aucun singe en cache, affichage 837 de mémoire non vérifiable,
puis `gorilla.m2` ; Defias Pirate 2347 / 2348 et Bart Tidewater 4429 (pirates) ; goules 828 / 569 (zombie) ; totems
Healing Stream 4587 (Ward), Grounding 4590 et Stoneclaw 4588 (Brain Wash Totem) ; gobelins de Booty Bay (Capitaine
Vertepeau 7113, ingénieur 7109, artisan 7110, sculpteur 7111, constructeur naval 7112, cogneur 7102) ; nains
(Grif Wildheart 3558, Torren Squarejaw 1153 / 1656, Jern Hornhelm 1572) ; Surveyor Brannock (inventé) = Torren
Squarejaw. À vérifier en jeu : `/slay models`.

### Décors

Six paysages peints par la zone (fonction `jungle` d'`UI/Art/Zones/stranglethorn.lua`, `draw` de
`Art.paintings`, formes de `S.paintKit`) : route de la jungle (jour), nuit (lune, lucioles, torche), campement de
Nesingwary (tentes, foyer, charrette), ruines trolls (pyramide à degrés, colonnes, têtes de pierre ; décors `hill`
et `ruins`), Booty Bay (baie entre deux falaises, navires, maisons sur pilotis, quai ; `shop` et `coast`), portes
de Zul'Gurub sous un ciel rouge (boss, `mine`). 330 à 1000 régions chacun. Planches : `build/snap/decor-stranglethorn_*.svg`.

### Reste à faire ou à vérifier en jeu

- Modèles (surtout gorilles et Zanzil Naga) et icônes : relancer le client (fichiers ajoutés), `/slay models`.
- Écart des épiques (Rogue et Hunter à +20) : lot des épiques, pas de la zone.
- Animation du Hex (carte qui s'envole) non faite.
