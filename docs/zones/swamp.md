# Swamp of Sorrows — fiche de zone (zone 5, id `swamp`)

Fiche de conception, pas de code. Format et puissance de référence : `Data/Act1.lua` (Westfall). Difficulté
visée : **Westfall + 48 %** (PV et dégâts ×1,48), sauf les ennemis qui posent une Affliction : ×1,40 sur leurs
chiffres, l'Affliction comptant comme des dégâts différés. Tous les chiffres sont des points de départ ; la
simulation les réglera.

## 1. La zone en trois lignes

- **Lieux** : route = la piste de Misty Valley entre les roseaux et l'eau ; camp = **Fallow Sanctuary** (huttes
  des Lost Ones) ; marchand = **Stonard** (avant-poste orc) ; élites = **Misty Reed Strand** (côte), les marches
  du **Temple of Atal'Hakkar**, le camp du chef des Lost Ones au-dessus de Fallow Sanctuary ; boss = la **Pool of Tears**, au pied du
  temple englouti.
- **Ambiance** : marais boisé, eau stagnante jusqu'aux genoux, crocolisks dans chaque mare, dragonkin verts qui
  gardent le temple, draeneï exilés (Lost Ones) qui vivent en marge de Stonard.
- **Ce que la zone enseigne** : un coup reçu peut coûter plus que des PV ; ce qu'on ne soigne pas aujourd'hui,
  on le porte au combat suivant.

## 2. La mécanique : Afflictions (Lingering)

### Règle

1. **Affliction** est un nouveau type de carte (à côté d'Attack, Skill, Power). Les ennemis de la zone en
   ajoutent à tes piles pendant le combat. Une Affliction n'est jamais proposée en récompense, chez le
   marchand ni dans une rencontre à choix de carte ; elle ne peut être ni améliorée ni copiée.
2. Toutes les Afflictions ont le mot-clé **Lingering** (plaque du bas, comme Exhaust) : *si la carte est
   encore dans ton deck à la fin du combat (pioche, main ou défausse), elle reste dans ton deck d'expédition.*
3. Toutes les Afflictions ont **Exhaust** : la jouer la retire du combat **et du deck d'expédition**, pour de
   bon. Soigner une Affliction en combat = payer son coût en mana.
4. Il existe trois Afflictions :

| Id | Nom | Coût | Texte (plaque : Lingering, Exhaust) | Ce qu'elle demande | Icône |
|---|---|---|---|---|---|
| `festering_wound` | Festering Wound | 1 | `Draw 1.` | 1 mana pour la retirer ; elle se remplace en main. | `spell_deathknight_festering_strike` (879926) |
| `creeping_venom` | Creeping Venom | 1 | `In hand, end of turn: lose 2 HP.` | 1 mana tout de suite, ou 2 PV à chaque tour où elle reste en main. | `spell_nature_corrosivebreath` (136016) |
| `sleep` | Sleep | 2 | `Retain.` / `In hand, start of turn: lose 1 mana.` | 2 mana d'un coup, ou 1 mana à chaque tour suivant (elle reste en main). | `spell_nature_sleep` (136090) |

5. **Comment elles arrivent** (deux voies, toujours annoncées par l'intention) :
   - **Par un coup** : `{ "attack", n, afflict = id }` ; l'Affliction est mise dans ta **défausse** seulement si
     ce coup te fait perdre des PV (même règle que `interrupts`). Coup multiple : une par coup qui touche.
   - **Par une incantation** : `{ "afflict", id, n, pile = "discard" | "top" }`, sur une intention `cast` :
     interrompue, elle ne pose rien. `top` = sur le dessus de la pioche (Sleep : tu la pioches au tour suivant).
6. **Lose 2 HP** (Creeping Venom) : perte de PV qui n'est pas une attaque, ignore l'Absorb, compte comme une
   perte de PV (Enrage, Healthstone) mais ne donne pas de Rage (la Rage vient des attaques). Ne tue pas : le
   joueur reste à 1 PV au moins.
7. **Sleep** : au début de ton tour, compte les Sleep déjà en main (gardées du tour d'avant) ; après le gain
   de mana, retire 1 mana par Sleep (jamais sous 0). Une Sleep tout juste piochée ne coûte rien ce tour-là.
8. **Plafond** : 6 Afflictions **portées** au plus (deck d'expédition + piles du combat). Au-delà, la nouvelle
   n'entre pas (journal : « resisted »). Voir question 1.
9. **Portée** (« carried ») : une Affliction dans la pioche, la main ou la défausse du combat en cours. Les
   ennemis qui lisent ce nombre l'affichent sur leur intention, recalculé quand tu en joues une.
10. **Hors combat** :
    - **Feu de camp** : nouvelle action **Treat**, proposée dès qu'une Affliction est dans le deck : retire
      toutes les Afflictions et soigne 10 % des PV max. Elle remplace le repos ou l'amélioration (une action par
      feu, comme aujourd'hui). Camp Kettle et Flint and Tinder ne s'appliquent qu'au repos.
    - **Marchand** : retirer une Affliction coûte 25 po et ne fait pas monter le prix du retrait.
    - **Rencontres** : effets `treat` (toutes ou n) et `afflict` (prix d'une récompense), section 6.
    - Fuir avec Cracked Hearthstone = fin de combat : les Afflictions portées restent.

### Interactions

| Avec | Règle |
|---|---|
| Absorb | Un coup entièrement absorbé ne fait pas perdre de PV : pas d'Affliction. C'est la réponse principale du Priest et du Mage. |
| Parry | Le coup annulé ne touche pas : pas d'Affliction. Une charge par coup, donc Noxious Breath (2 coups) en demande deux. |
| Stunned | L'ennemi perd son tour, rien n'est posé. Posé pendant son tour (Freezing Trap), l'attaque ne part pas. |
| Cast / Interrupt | Les incantations qui posent une Affliction (Hex, Sleep, Lullaby) sont perdues si on les interrompt. Côté joueur, une Affliction n'est pas une carte Cast. |
| Traps | La Trap se déclenche avant les coups (moteur actuel) ; si elle tue l'attaquant ou l'étourdit, rien n'est posé. |
| DoT | Aucun lien de règle : Creeping Venom n'est pas un DoT (ni décroissance, ni Envenom). |
| Familier du Hunter | Aucun lien de règle : le familier ne joue pas de carte. Il tue les poseurs entre deux tours. |
| « Remove negative effects » | Étendu : exhauste aussi les Afflictions **en main** (Berserker Rage, Cloak of Shadows, Insignia of the Alliance, Elixir of Wisdom). Insignia agit au début du tour, avant la pioche : seulement les Sleep gardées. |
| Demonic Rune | Une Affliction jouée est une carte Exhaust jouée : +3 Absorb. |
| Slice and Dice, Ironfoe, Hand of Justice | Une Affliction n'est pas une Attack : rien. |

### Infobulles (anglais)

- **Affliction** : `Added by enemies. Lingering. Playing it removes it from your deck.`
- **Lingering** : `If this card is still in your deck when the combat ends, it stays in your deck.`
- **Treat** (feu de camp) : `Remove all Afflictions from your deck. Heal 10% of max HP.`
- Compteur sur le bandeau de la carte de parcours : icône de Festering Wound + nombre d'Afflictions portées.

### Les décisions qu'elle crée

- **Pendant le tour** : 1 ou 2 mana pour soigner maintenant, ou garder le tempo et porter l'Affliction.
  Creeping Venom (2 PV par tour) et Sleep (1 mana par tour) poussent à payer ; Festering Wound se rembourse
  par la pioche, donc la garder n'est jamais grave sauf contre ce qui compte les Afflictions portées.
- **Avant le tour ennemi** : absorber entièrement le coup qui pose (Absorb, Parry, Stunned), ou tuer d'abord
  l'ennemi qui pose. Le Warrior perd sa Rage s'il absorbe tout : il choisit entre Rage et Afflictions.
- **Entre deux combats** : le feu de camp de l'étape 7 oppose Rest (30 %) à Treat (10 % + nettoyage), juste
  avant Somnus qui gagne 1 Strength par Affliction portée.

### Réponses de chaque classe

| Classe | Prévenir | Soigner en combat | Carte de zone |
|---|---|---|---|
| Priest | Absorb (PW: Shield, Inner Fire), Silence sur Hex et Sleep | 1 mana par Affliction ; Atonement rend les PV du venin | Mass Dispel |
| Warrior | Absorb s'il renonce à la Rage, Pummel, 74 PV | Berserker Rage (exhauste la main) | Enraged Regeneration |
| Mage | Mana Shield, Ice Barrier, Counterspell, Frost Nova, Polymorph | 1 mana par Affliction | Alter Time |
| Rogue | Parry (Feint, Evasion, Riposte), Kick à 0 mana | Cloak of Shadows ; cartes à 0 mana qui laissent du mana | Shiv |
| Hunter | Freezing Trap, Wyvern Sting, Intimidation, Counter Shot, Disengage | 1 mana par Affliction | Exhilaration |

### Ce que le moteur doit apprendre

1. Type de carte `affliction`, drapeau `lingering`, exclusion des réserves (récompense, marchand, `cardChoice`,
   `upgrade`, `dupe`), cadre de carte propre et infobulles.
2. `Combat.addCard(c, id, pile)` : crée une instance `{uid, id, up = false}` en cours de combat (compteur d'uid
   dans l'état, sauvegardable), journal `{ t = "afflict", card, pile }` pour l'animation. Respecte le plafond.
3. Actions ennemies : option `afflict = id` sur `attack` (après `dealDamage`, si `loss > 0`) et action
   `{ "afflict", id, n, pile }`.
4. Crochets de carte en main : `endTurnInHand` (Creeping Venom, avant la défausse) et `startTurnInHand` après
   le gain de mana (Sleep).
5. Fin de combat : renvoyer les Afflictions portées (à ajouter à `exp.deck`) et les uid d'Afflictions du deck
   d'expédition exhaustées (à en retirer). Aujourd'hui le deck d'expédition ne change jamais pendant un combat.
6. `Combat.cleanse` sur le joueur : exhauste aussi les Afflictions en main.
7. Intention à valeur variable : `{ "attack", n, per = "afflictions", step = 3, cap = 9 }`, affichée à jour.
8. Feu de camp : action `{"treat"}` ; marchand : prix fixe 25 po pour une Affliction ; rencontres : effets
   `{"afflict", id}`, `{"treat", n}` (`n` absent = toutes), condition `{"afflictions", n}`.
9. Bot : jouer une Affliction quand le mana restant ne sert à rien d'autre, toujours Creeping Venom avant la
   fin du tour si 1 mana reste ; Treat au feu si 3 Afflictions ou plus, ou 2 avant le boss.
10. Nouveaux décors de rencontre : `swamp`, `stonard`, `sanctuary`, `pool`, `temple` (`coast` existe).

## 3. Ennemis normaux (8)

Notation des actions : celle de `Data/Act1.lua`. « Wound » = `afflict = "festering_wound"`, « Venom » =
`afflict = "creeping_venom"`, toujours conditionné à une perte de PV.

| Id | Nom (WoW) | PV | Intentions | Motif | Rôle | Mécanique |
|---|---|---|---|---|---|---|
| `sawtooth_crocolisk` | Sawtooth Crocolisk | 35–39 | **Snap** (attack) : 11. **Death Roll** (attack) : 8, Wound. **Submerge** (defend) : block 10. | snap, death_roll, submerge ; départ au hasard | Brute, tient la ligne | oui |
| `deathstrike_tarantula` | Deathstrike Tarantula | 21–24 | **Venomous Bite** (attack) : 6, Venom. **Web** (debuff) : 4, Demoralized 1 sur le joueur. | bite, web | Poseur fragile, à tuer en premier | oui |
| `marsh_inkspewer` | Marsh Inkspewer | 15–18 | **Claw** (attack) : 6. **Ink Spit** (debuff) : 4, Sundered 1 ⌛ sur le joueur. | ink, claw ; départ au hasard | Nuée ; le Sundered fait passer les coups des poseurs à travers l'Absorb | non |
| `lost_one_hunter` | Lost One Hunter | 29–33 | **Spear Thrust** (attack) : 11. **Hunt the Wounded** (attack) : 6 + 3 par Affliction portée (+9 au plus). | thrust, hunt ; départ au hasard | Punit les Afflictions laissées dans le deck | oui (lit) |
| `lost_one_seer` | Lost One Seer | 22–25 | **Mend** (heal) : soigne 9 l'allié le plus blessé. **Hex** (cast) : 2 Festering Wound dans la défausse. **Shadow Bolt** (attack) : 8. | ai : Mend si un allié a perdu 9 PV et que le dernier coup n'était pas Mend ; sinon Hex et Shadow Bolt en alternance | Soutien ; test d'Interrupt | oui |
| `swampwalker` | Swampwalker | 42–46 | **Vine Lash** (attack) : 9. **Bog Shield** (defend) : block 8, block_ally 8. **Choke** (attack) : 5 deux fois. | lash, shield, choke | Mur qui protège les poseurs | non |
| `nightmare_whelp` | Nightmare Whelp | 13–15 | **Bite** (attack) : 6. **Noxious Breath** (attack) : 4, Venom. | bite, breath ; départ au hasard | Petit poseur, par deux au plus | oui |
| `nightmare_wyrmkin` | Nightmare Wyrmkin | 34–38 | **Sleep** (cast) : 1 Sleep sur la pioche. **Wing Buffet** (attack) : 9, interrupts. **Claw** (attack) : 12. | sleep, buffet, claw | Lanceur ; Wing Buffet coupe les Cast du joueur | oui |

Six sur huit utilisent la mécanique (cinq posent, un lit). Les Lost Ones sont des draeneï exilés, Hunter et
Seer sont leurs noms de créature dans la zone ; Swampwalker tient la place des « limons » (créature de vase et
de lianes du marais). Nightmare Whelp et Nightmare Wyrmkin sont les dragonkin verts du Temple of Atal'Hakkar.

### Groupes

| Groupe | Composition | PV totaux | Idée |
|---|---|---|---|
| easy 1 | crocolisk | 35–39 | Apprendre Death Roll : absorber le coup annoncé. |
| easy 2 | inkspewer ×3 | 45–54 | Nuée sans mécanique. |
| easy 3 | tarantula, inkspewer | 36–42 | Premier venin. |
| easy 4 | whelp ×2 | 26–30 | Deux petits poseurs. |
| normal 1 | crocolisk, inkspewer ×3 | 80–93 | Le Sundered des murlocs fait passer Death Roll. |
| normal 2 | lost_one_hunter, lost_one_seer, tarantula | 72–82 | Hex et Venom nourrissent Hunt the Wounded. |
| normal 3 | swampwalker, tarantula, inkspewer | 78–88 | Le mur protège la tarentule. |
| normal 4 | nightmare_wyrmkin, nightmare_whelp ×2 | 60–68 | Interrompre Sleep ou payer 2 mana. |
| normal 5 | lost_one_hunter, sawtooth_crocolisk | 64–72 | Deux gros coups, dont un qui pose. |
| normal 6 | swampwalker, lost_one_seer | 64–71 | Long : soins et blocs ; Hex à interrompre. |
| event_crocs | crocolisk ×2 | 70–78 | Rencontre de Stonard. |
| event_galen | inkspewer ×4 | 60–72 | Rencontre de Galen. |
| event_dragonkin | nightmare_wyrmkin, nightmare_whelp ×2 | 60–68 | Rencontre des marches du temple. |
| event_gilmorian | gilmorian (élite) | 104 | Rencontre de Misty Reed Strand. |

Cible : 6 à 9 PV perdus par combat normal en comptant une Affliction emportée comme 3 PV ; 1 à 1,5 Affliction
gagnée par combat normal sans réponse, environ 0,5 emportée.

## 4. Élites (3)

| Id | Nom | PV | Intentions | Motif | Idée de combat |
|---|---|---|---|---|---|
| `wyrmak` | Lord Captain Wyrmak (rare, dragonkin) | 110 | **Lullaby** (cast) : 2 Sleep sur la pioche. **Cleave** (attack) : 17. **Wrath of the Dream** (attack) : 8 + 3 par Affliction portée (+12 au plus). **Tail Sweep** (attack) : 8, interrupts ; block 10. | lullaby, cleave, wrath, tail | Le maître du sommeil : chaque Lullaby non interrompue coûte 4 mana ou nourrit Wrath of the Dream deux tours plus tard. |
| `gilmorian` | Gilmorian (rare, naga de la côte) | 104 | **Lightning Bolt** (cast) : 24. **Frost Shock** (attack) : 8, interrupts ; Demoralized 1 sur le joueur. **Healing Wave** (cast) : soigne 20 (elle-même, `heal_ally`). | bolt, shock, wave | Le duel d'interruptions : deux incantations sur trois tours ; un seul Interrupt à Cooldown 2 ne suffit pas, il faut choisir entre bloquer 24 et empêcher 20 PV de soin. Aucune Affliction : l'élite repos de la zone. |
| `lost_one_chieftain` | Lost One Chieftain (chef des Lost Ones) | 96 | **Call the Lost** (summon) : 1 Lost One Refugee. **Brutal Strike** (attack) : 10, 2 Wound. **Spear of the Lost** (attack) : 15. | call, brutal, spear | La course : tuer le chef avant que les réfugiés s'accumulent, en absorbant Brutal Strike. |
| `lost_one_refugee` (sbire) | Lost One Refugee | 12–14 | **Stab** (attack) : 5. | stab | Sbire du chef (`minion = true`). |

## 5. Boss : Somnus (dragon vert)

Somnus survole la Pool of Tears, devant le Temple of Atal'Hakkar. **140 PV**, immunisé à Stunned (règle des
boss), pas aux Interrupts.

- **Passif, Nightmare** : au début du combat, Somnus gagne **1 Strength par Affliction portée** (5 au plus).
  Affiché dès l'écran de combat. C'est l'enjeu du feu de camp de l'étape 7.
- **Phase 1 (140 à 71 PV)** : motif fixe de 4 intentions.
  1. **Noxious Breath** (attack) : 10 deux fois, Venom à chaque coup qui fait perdre des PV.
  2. **Sleep** (cast) : 2 Sleep sur la pioche.
  3. **Claw** (attack) : 28.
  4. **Wing Buffet** (attack) : 12, interrupts ; block 12.
- **Transition (70 PV ou moins, une fois, `onDamaged`)** : « Children of the Dream, to me! » ; invoque
  2 **Nightmare Whelp** (sbires, 12 PV, **Bite** : 5 seulement). Le motif devient, à partir de l'intention suivante :
  1. **Noxious Breath** : 10 deux fois, Venom.
  2. **Dream Eater** (attack) : 6 + 4 par Affliction portée (+16 au plus).
  3. **Claw** : 28.
  4. **Sleep** (cast) : 2 Sleep sur la pioche.
- **Durée visée** : phase 1 en 3 tours (environ 23 dégâts par tour à ce stade), phase 2 en 3 à 4 tours
  (70 PV + 24 PV de dragonnets) : **6 à 7 tours**.
- **Lecture** : chaque Sleep non interrompue renforce Dream Eater ; chaque souffle absorbé est un venin de
  moins. Ce qu'on a soigné avant le combat compte deux fois (Strength au départ, Dream Eater en phase 2).

## 6. Rencontres (8)

Les nouveaux effets `afflict` et `treat` et la condition `afflictions` sont décrits en section 2. Les deux
premières du palier 0 et celle des marches du temple sont aussi des exemples du type « marché » débloqué
(section 8).

```lua
event("stonard_outpost", {
  name = "Stonard", act = 5, tier = 0,
  speaker = "Dispatch Commander Ruag", npc = "dispatch_commander_ruag", scene = "stonard",
  text = "\"Stonard does not turn away travelers who can fight. Our healer treats crocolisk bites and "
    .. "spider venom, for a price. If you have no gold, my grunts need Sawtooth hides.\"",
  choices = {
    { label = "Pay the healer", outcome = "Pay 30g, remove all Afflictions, +6 HP",
      result = "The healer cleans your wounds and gives you a bitter tea for the venom.",
      effects = { { "pay", 30 }, { "treat" }, { "heal", 6 } } },
    { label = "Hunt crocolisks for Ruag", outcome = "Fight 2 crocolisks: usual reward + 25g",
      result = "Ruag sends you to the riverbank south of the outpost.",
      effects = { { "fight", "event_crocs", gold = 25 } } },
    { label = "Rest at the inn", outcome = "+10 HP",
      result = "The innkeeper gives you a bed for the afternoon.",
      effects = { { "heal", 10 } } },
  },
})

event("pool_of_tears", {
  name = "The Pool of Tears", act = 5, tier = 0,
  speaker = "Fel'Zerul", npc = "fel_zerul", scene = "pool",
  text = "\"The Atal'ai threw their artifacts into the Pool of Tears when the temple sank. I want them "
    .. "back. The water is full of Sawtooth crocolisks, so I am not going in myself.\"",
  choices = {
    { label = "Dive into the pool", outcome = "50%: a relic, else -8 HP and a Festering Wound",
      effects = { { "gamble", 0.5,
        win = { { "relic" } },
        winText = "You find an Atal'ai idol in the mud at the bottom. Fel'Zerul lets you keep it.",
        lose = { { "loseHp", 8 }, { "afflict", "festering_wound" } },
        loseText = "A crocolisk bites your leg before you reach the bottom." } } },
    { label = "Search the shallows", outcome = "+35g, a Festering Wound",
      result = "You pull two artifacts from the reeds and cut your hand on the second. Fel'Zerul pays you.",
      effects = { { "gold", 35 }, { "afflict", "festering_wound" } } },
    { label = "Leave", outcome = "Nothing",
      result = "Fel'Zerul goes back to watching the water.",
      effects = {} },
  },
})

event("galen_escape", {
  name = "Galen's Escape", act = 5, tier = 0,
  speaker = "Galen Goodward", npc = "galen_goodward", scene = "swamp",
  text = "\"Marsh murlocs dragged me to their camp and took my strongbox. I got loose, but I can't get "
    .. "past them alone. Get me to the road and we split what's in the box.\"",
  choices = {
    { label = "Escort Galen", outcome = "Fight 4 murlocs: usual reward + 30g",
      result = "The murlocs see you coming and charge.",
      effects = { { "fight", "event_galen", gold = 30 } } },
    { label = "Take the strongbox back alone", outcome = "50%: 60g, else -6 HP and a Festering Wound",
      effects = { { "gamble", 0.5,
        win = { { "gold", 60 } },
        winText = "The murlocs are fishing. You carry the strongbox out of the camp and Galen pays you.",
        lose = { { "loseHp", 6 }, { "afflict", "festering_wound" } },
        loseText = "A murloc spears you as you lift the strongbox. You drop it and run." } } },
    { label = "Show him the way to the road", outcome = "Nothing",
      result = "Galen thanks you and heads for the road on foot.",
      effects = {} },
  },
})

event("fallow_sanctuary", {
  name = "Fallow Sanctuary", act = 5, tier = 1,
  speaker = "Lost One Refugee", npc = "lost_one_refugee", scene = "sanctuary",
  text = "\"We are the Lost Ones. We came here from Draenor, and the dragons hunt us. Our seer can draw "
    .. "venom out of a wound if you share your food with us.\"",
  choices = {
    { label = "Share your rations", outcome = "Pay 20g, remove all Afflictions",
      result = "The seer presses swamp moss on your wounds until the venom comes out.",
      effects = { { "pay", 20 }, { "treat" } } },
    { label = "Help them rebuild their huts", outcome = "-6 HP, upgrade a card of your choice",
      result = "You carry logs from the river all day and learn from the Lost Ones as you work.",
      effects = { { "loseHp", 6 }, { "upgrade" } } },
    { label = "Move on", outcome = "Nothing",
      result = "The refugee goes back to his hut.",
      effects = {} },
    -- carte neutre débloquée par la zone (section 8)
    { label = "Ask for their remedy", outcome = "Pay 25g, Powerful Anti-Venom (card)",
      when = { { "unlocked", "powerful_anti_venom", hide = true } },
      result = "The seer fills a vial from his own supply.",
      effects = { { "pay", 25 }, { "card", "powerful_anti_venom" } } },
  },
})

event("lost_one_cook", {
  name = "The Lost One Cook", act = 5, tier = 1,
  speaker = "Lost One Cook", npc = "lost_one_cook", scene = "sanctuary",
  text = "\"I cook what the swamp gives me. Today it is crocolisk. Sit and eat, or catch me a fresh "
    .. "Sawtooth and I will show you my recipes.\"",
  choices = {
    { label = "Eat with him", outcome = "+10 HP",
      result = "He fills your bowl twice.",
      effects = { { "heal", 10 } } },
    { label = "Catch a crocolisk for him", outcome = "-7 HP, one of 3 common cards",
      result = "The crocolisk bites you before you drag it to the pot. The cook keeps his word.",
      effects = { { "loseHp", 7 }, { "cardChoice", n = 3, rarity = "common" } } },
    { label = "Let him clean your bites", outcome = "Pay 10g, remove an Affliction",
      when = { { "afflictions", 1 } },
      result = "He washes the wound with boiled water and salt.",
      effects = { { "pay", 10 }, { "treat", 1 } } },
    { label = "Buy a pot of gumbo", outcome = "Pay 30g, Crocolisk Gumbo (card)",
      when = { { "unlocked", "crocolisk_gumbo", hide = true } },
      result = "He seals the pot with a lid and a strip of hide.",
      effects = { { "pay", 30 }, { "card", "crocolisk_gumbo" } } },
  },
})

event("temple_steps", {
  name = "The Temple Steps", act = 5, tier = 2,
  speaker = "Temple of Atal'Hakkar", npc = nil, scene = "temple",
  text = "Three Nightmare dragonkin sleep on the steps of the Temple of Atal'Hakkar. An Atal'ai offering "
    .. "chest stands open between them.",
  choices = {
    { label = "Take from the chest quietly", outcome = "A relic and a Sleep (Affliction)",
      result = "You take an idol from the chest. The wyrmkin wakes and breathes on you as you leave.",
      effects = { { "relic" }, { "afflict", "sleep" } } },
    { label = "Attack the sleepers", outcome = "Fight 3 dragonkin: usual reward + 30g",
      result = "You strike the wyrmkin first.",
      effects = { { "fight", "event_dragonkin", gold = 30 } } },
    { label = "Go around the temple", outcome = "Nothing",
      result = "You take the long way through the water.",
      effects = {} },
  },
})

event("cortello_riddle", {
  name = "Cortello's Riddle", act = 5, tier = 1, rarity = "rare",
  speaker = "Cortello's Riddle", npc = nil, scene = "swamp",
  text = "In a dead adventurer's pack, you find a sealed scroll signed by Cortello. The riddle points to a "
    .. "cave in the hills of the swamp. Deathstrike tarantulas nest in that cave.",
  choices = {
    { label = "Search the cave", outcome = "2 Creeping Venom, a relic and 40g",
      result = "You find Cortello's chest behind the webs. The tarantulas bite you twice on the way out.",
      effects = { { "afflict", "creeping_venom" }, { "afflict", "creeping_venom" },
        { "relic" }, { "gold", 40 } } },
    { label = "Sell the scroll in Stonard", outcome = "+50g",
      result = "A goblin trader in Stonard buys the scroll without reading it.",
      effects = { { "gold", 50 } } },
    { label = "Leave the scroll", outcome = "Nothing",
      result = "You put the scroll back in the pack.",
      effects = {} },
  },
})

event("misty_reed_strand", {
  name = "Misty Reed Strand", act = 5, tier = 2, rarity = "rare",
  speaker = "Stonard fisherman", npc = "stonard_fisherman", scene = "coast",
  -- Proposée seulement en bonne santé : la réponse principale est un combat d'élite.
  when = { { "hpAbove", 0.6 } },
  text = "\"A naga called Gilmorian came up from the sea and took the Misty Reed Strand. She drowned two "
    .. "of our fishermen. Stonard pays for her head.\"",
  choices = {
    { label = "Hunt Gilmorian", outcome = "Elite fight: elite reward + 40g",
      result = "Gilmorian rises from the water as you reach the strand.",
      effects = { { "fight", "event_gilmorian", kind = "elite", gold = 40 } } },
    { label = "Fish the north end of the strand", outcome = "-4 HP, a potion",
      result = "You fish out of her sight until dark. A fisherman trades you a potion for your catch.",
      effects = { { "loseHp", 4 }, { "potion" } } },
    { label = "Leave the strand", outcome = "Nothing",
      result = "The fisherman goes back to Stonard.",
      effects = {} },
  },
})
```

Paliers : 3 au palier 0, 3 au palier 1 (dont la rare), 2 au palier 2 (dont la rare). Chaque rencontre garde une
réponse sans condition ni coût.

## 7. Cartes de zone (une par classe, rares)

Cartes définitives (épiques, pivots) : voir `docs/zones/cartes-de-zone.md`.

- Reflective Shield (Priest)
- Defensive Stance (Warrior)
- Molten Armor (Mage)
- Leeching Poison (Rogue)
- Exhilaration (Hunter)

## 8. Commun débloqué par la première victoire du compte

### Cartes neutres (2)

| Id | Nom (objet WoW) | Rareté | Coût | Type | Base | Améliorée | Icône |
|---|---|---|---|---|---|---|---|
| `powerful_anti_venom` | Powerful Anti-Venom (Secourisme) | common | 0 | Skill | `Remove negative effects.` / `Exhaust Afflictions in your hand.` / `Draw 1.` / `Exhaust.` | `Draw 2.` | `spell_nature_nullifypoison` (136067) |
| `crocolisk_gumbo` | Crocolisk Gumbo (Cuisine) | uncommon | 1 | Skill | `Draw 1.` / `Gain Regen 4` / `Exhaust.` | `Gain Regen 6` | `inv_misc_food_*` : non choisie, la recherche par nom ne dit pas laquelle est un bol (à regarder dans le jeu) |

Ailleurs : l'Anti-Venom est un nettoyage à 0 mana (Sundered de VanCleef, DoT) ; le Gumbo est un soin étalé pour
les classes sans soin.

### Bibelots communs (3)

| Id | Nom (objet WoW) | Rareté | Palier | Texte | Icône |
|---|---|---|---|---|---|
| `green_dragonscale` | Green Dragonscale | common | 1 | `The first Affliction gained in each combat is not added.` | `inv_misc_monsterscales_*` : couleur à vérifier dans le jeu (20 icônes, 134303 à 237405) |
| `tender_crocolisk_meat` | Tender Crocolisk Meat | common | 1 | `After each elite combat won, heal 8 HP.` | idem, `inv_misc_food_*` à choisir |
| `atalai_artifact` | Atal'ai Artifact | uncommon | 2 | `At the start of each combat, apply Sundered 1 to all enemies.` | `inv_misc_idol_03` (134232) |

Green Dragonscale ne sert hors du marais qu'avec les marchés ci-dessous : c'est voulu, il donne au joueur une
raison de les accepter.

### Type de rencontre : le marché (bargain)

Une rencontre dont le prix d'une réponse est une **Affliction** ajoutée au deck (`{"afflict", id}`), en échange
d'une récompense au-dessus de la normale (bibelot, carte rare, or). Une fois débloqué, le type entre dans les
autres zones (une rencontre de ce type par zone, à écrire dans chaque fiche) et l'action Treat apparaît au feu
de camp dès qu'une Affliction est dans le deck. Exemples dans cette fiche : `pool_of_tears`, `temple_steps`,
`cortello_riddle`.

## 9. Bibelots de clé (+1, +3, +5)

Communs aux classes, `rarity = "rare"`, `noPool` sauf déblocage ; plus forts que les communs.

| Clé | Id | Nom (objet WoW) | Texte | Icône | Note |
|---|---|---|---|---|---|
| +1 | `chained_essence_of_eranikus` | Chained Essence of Eranikus | `At the start of each combat, apply DoT 4 to all enemies.` | `spell_nature_corrosivebreath` (136016) | Récompense de quête du Temple of Atal'Hakkar. Tobin's Pocketknife fait DoT 3. |
| +3 | `egg_of_hakkar` | Egg of Hakkar | `The first cast by an enemy in each combat is interrupted.` | `inv_misc_shadowegg` (134430) | Objet de quête du Temple. Utile partout (Conjurer, Seer, Wyrmkin, Gilmorian, Somnus). |
| +5 | `fist_of_the_damned` | Fist of the Damned | `Attack cards heal 1 HP per hit.` | `inv_mace_*` : non choisie (`inv_mace_15` est déjà Ironfoe) | Masse du Temple, provenance à vérifier. Fort sur les coups multiples (Penance, Killing Spree, Rapid Fire). |

## 10. Modèles et icônes

`wow_creature_search` n'a pas trouvé d'installation (« No World of Warcraft install found ») ; aucune
synchronisation lancée. Identifiants relevés comme pour Westfall dans un cache de créatures du client, ici
celui de `_classic_` (build 45613), par `tools/wdb_creatures.py`. Le cache de Forever ne contient aucune
créature de la zone. Modèles : `wow_model_search` (liste des fichiers), utiles pour choisir un affichage.

| Unité | Créature | Affichage | Fichier modèle (FileDataID) | Icône de repli |
|---|---|---|---|---|
| Sawtooth Crocolisk | non trouvé | non trouvé | `creature/crocodile/crocodile.m2` (123324) | `ability_hunter_pet_crocolisk` (132187) |
| Deathstrike Tarantula | non trouvé | non trouvé | `creature/tarantula/tarantula.m2` (126124) | `ability_hunter_pet_spider` (132196) |
| Marsh Inkspewer | non trouvé | non trouvé | `creature/murloc/murloc.m2` (125024) | `inv_misc_head_murloc_01` (134169) |
| Lost One Hunter | non trouvé | non trouvé | `creature/lostone/lostone.m2` (124809) | `inv_spear_04` (135127) |
| Lost One Seer | non trouvé | non trouvé | `creature/lostone/lostone.m2` (124809) | `spell_shadow_curse` (136136) |
| Swampwalker | non trouvé | non trouvé | `creature/bogbeast/bogbeast.m2` (123105) | `spell_nature_stranglevines` (136100) |
| Nightmare Whelp | non trouvé | non trouvé | `creature/dragonwhelp/dragonwhelp.m2` (123610) | `inv_misc_head_dragon_green` (134157) |
| Nightmare Wyrmkin | non trouvé | non trouvé | `creature/dragonspawn/dragonspawn.m2` (123543) | `spell_nature_sleep` (136090) |
| Lord Captain Wyrmak | 14445 | 7976 | — | `inv_misc_head_dragon_green` (134157) |
| Gilmorian | 14447 | 4920 | `creature/nagamale/nagamale.m2` (125078) si besoin | `inv_misc_nagamale` (1391617) |
| Lost One Chieftain | 763 | 10921 | — | `inv_spear_08` (135131) |
| Lost One Refugee | 19162 | 152, 11650 | — | `inv_spear_01` (135124) |
| Somnus | non trouvé | non trouvé | `creature/dragon/dragon.m2` (123459) | `inv_misc_head_dragon_green` (134157) |
| Dispatch Commander Ruag | non trouvé | non trouvé | — | — |
| Fel'Zerul | non trouvé | non trouvé | — | — |
| Galen Goodward | non trouvé | non trouvé | — | — |
| Lost One Cook | 1106 | 152 (suspect : même affichage que le réfugié) | — | — |
| Stonard fisherman | personnage plausible, pas de créature | — | — | — |

Autres créatures de la zone vues dans ce cache, non retenues : Jade (1063, affichage 7975, dragonnet vert rare,
candidat d'élite de rechange) et Fingat (14446, affichage 441). Icônes de cartes et bibelots : sections 2, 7, 8
et 9 ; toutes confirmées par `wow_icon_search` sauf celles marquées « à choisir ».

## 11. Questions ouvertes

1. **Plafond de 6 Afflictions portées.** Avec plafond, un joueur qui ne soigne rien arrive au 6e combat avec
   6 cartes mortes, et les coups suivants ne lui coûtent plus rien de durable. Sans plafond, il peut arriver à
   Somnus avec 10 Afflictions (Strength 5, Dream Eater à +16) et perdre l'expédition sur une seule négligence.
2. **Treat au feu de camp.** Version proposée : Treat remplace le repos (10 % de PV et tout nettoyer, ou 30 %
   de PV). Autre version : le repos retire aussi 2 Afflictions. La première fait du feu de l'étape 7 un vrai
   choix avant Somnus ; la seconde rend la zone plus douce et la décision disparaît la plupart du temps.
3. **Les orcs de Stonard.** Ici ils sont alliés (marchand, rencontres de Ruag et du pêcheur) et aucun
   n'est un ennemi : un joueur Horde ne combat pas ses propres gardes, mais la faune annoncée perd les orcs.
   En faire des ennemis demande une version Alliance et une version Horde des rencontres.
4. **Sleep et le Mage.** Sleep coûte 2 mana ou 1 par tour, et Wing Buffet coupe les Cast. Le Mage (42 PV,
   jeu de Cast) risque d'être la classe la plus gênée de la zone ; si la simulation le confirme, Sleep peut
   coûter 1 au lieu de 2 pour toutes les classes, ce qui retire aussi de la pression au boss.
5. **Les marchés dans les zones déjà gagnées.** Après une victoire dans le marais, une rencontre « marché »
   peut apparaître à Westfall (un bibelot contre une Festering Wound). Le joueur qui refait Westfall aux clés
   y gagne des bibelots plus tôt ; si on veut que Westfall reste la zone d'apprentissage, le type ne s'ouvre
   qu'à partir de la zone 5.
