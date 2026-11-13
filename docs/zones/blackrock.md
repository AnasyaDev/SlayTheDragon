# Zone 7 — Blackrock Mountain (`blackrock`)

Fiche de conception de la dernière zone de la campagne. Format et puissance de référence : `Data/Act1.lua`
(Westfall). Difficulté visée : **Westfall + 72 %** (PV et dégâts ennemis × 1,72 environ), compensée par les
cartes et bibelots débloqués dans les six zones précédentes ; tous les chiffres sont des points de départ à
régler par simulation. Noms et textes de jeu en anglais.

## 1. La zone en trois lignes

- **Lieux** : l'entrée de **Blackrock Depths** et le **Molten Span** (pont de pierre au-dessus de la lave, la
  route), la taverne **Grim Guzzler** (le marchand : la Confrérie du thorium), **Blackrock Spire** (Hordemar
  City, camp des orcs Blackhand ; fond des élites), **Blackwing Lair** (la salle du trône de Nefarian, le boss).
- **Ambiance** : la montagne est partagée entre les nains Sombrefer de l'empereur Thaurissan, en bas, et le
  clan Blackrock et les dragons noirs de Nefarian, en haut. Les élémentaires de feu gardent les forges.
- **Fonds de scène** proposés (nouveaux `scene`) : `span` (route, Molten Span), `tavern` (marchand et
  rencontres, Grim Guzzler), `prison` (Detention Block), `spire` (camp, élites), `lair` (boss).

Faune choisie dans les donjons (BRD, LBRS, UBRS, BWL) et non dans les Steppes ardentes, pour ne reprendre
aucune créature extérieure de la zone 6 (Blackrock Soldier, Black Broodling, Black Dragonspawn, etc.).

## 2. La mécanique de la zone : les phases (mot-clé **Phase**)

### Règle

1. **Qui.** Les ennemis marqués « Phase » ont 1 ou 2 **seuils** en fraction de leurs PV max (normaux : 50 % ;
   élites et boss : voir leur fiche). Chaque seuil ouvre une **phase** : un nom, des **effets d'entrée**
   (états, Absorb, règle propre) et une **intention d'ouverture**, puis un nouveau motif.
2. **Ce que voit le joueur, avant.** Un cran sur la barre de vie à chaque seuil (couleur distincte du trait
   à 50 % d'Execute / Careful Aim ; aux normaux les deux se confondent, le cran l'emporte). Au survol du cran
   ou de l'ennemi : `Below 50%: Enraged. Gains Strength 4. Opens with Whirlwind.` Le joueur connaît donc
   toujours l'intention qu'il va déclencher.
3. **Déclenchement.** Dès que les PV de l'ennemi passent **à ou sous** le seuil, quelle que soit la source
   (carte, DoT, familier, Trap, riposte, sort renvoyé). Une seule fois : un soin qui le remonte au-dessus ne
   le ramène pas à la phase d'avant. Un coup qui **tue** ne déclenche aucune phase. Les dégâts en trop
   **passent** (aucun plafond au seuil) : tuer d'un coup depuis le haut saute la phase.
4. **Effets d'entrée**, dans l'ordre : bandeau « Phase 2 : Enraged » au-dessus de l'ennemi, réplique
   (`say`), effets d'entrée appliqués tout de suite, motif remplacé par celui de la phase.
5. **L'intention d'ouverture** :
   - **pendant ton tour** (carte jouée, Cast résolu au début du tour, DoT déclenché par Envenom ou
     Exsanguinate, attaque commandée du familier) : l'intention affichée est **remplacée tout de suite** par
     l'ouverture, qui part à ce tour ennemi. L'intention remplacée est perdue, **incantation comprise** ; une
     incantation déjà interrompue est remplacée par une ouverture **non** interrompue.
   - **après ton tour** (attaque automatique du familier en fin de tour, Trap, riposte, DoT au début du tour
     de l'ennemi, sort renvoyé) : l'intention annoncée **part quand même** (ce qui est annoncé a lieu) ;
     l'ouverture sera son intention suivante, affichée au début de ton tour.
6. **Plusieurs seuils d'un coup** : toutes les phases franchies s'appliquent dans l'ordre (effets cumulés) ;
   l'intention est l'ouverture de la dernière.
7. **Stunned** : un ennemi étourdi qui change de phase garde son Stunned ; son ouverture devient son intention
   et **se perd avec le tour sauté** ; il reprend ensuite au 2e coup du motif de la phase. Boss immunisés,
   comme partout (leurs ouvertures sont des Cast ou des cris, voir le boss).
8. Les sbires (`minion`) n'ont jamais de phase. Une règle de phase (Invincible, Throne) n'est pas un état :
   aucune carte ne la retire. Strength et Absorb gagnés à l'entrée sont des états ordinaires.

### Infobulles (anglais)

| Terme | Texte (≤ 60 caractères) |
|---|---|
| Phase (mot-clé) | `At each HP mark: new phase, new intent at once.` |
| Cran de seuil | `Below 50%: <phase>. <effects>. Opens with <move>.` |
| Ouverture différée (badge sur l'intention) | `Opening move of its new phase.` |

### Les décisions qu'elle crée

1. **Quand franchir.** Franchir pendant son tour remplace l'intention annoncée : bon si elle est pire que
   l'ouverture (un Cleave 17 remplacé par un cri sans dégâts), mauvais sinon. Franchir par le DoT ou par le
   familier en fin de tour laisse partir l'intention annoncée et montre l'ouverture un tour à l'avance.
2. **Préparer la réponse** avant de franchir : garder son Interrupt pour l'ouverture en Cast (franchir
   **puis** interrompre, jamais l'inverse), étourdir juste après le seuil pour faire perdre l'ouverture,
   garder de l'Absorb pour la grosse ouverture.
3. **Passer à travers** : tuer depuis le haut du seuil en un tour (burst) supprime la phase.
4. **Ordre des cibles** dans un groupe : quel ennemi pousser en phase 2 d'abord.

### Interactions

| Règle | Comportement |
|---|---|
| Absorb | L'Absorb ennemi protège ses PV comme d'habitude ; le seuil se lit sur les PV. L'Absorb gagné à l'entrée (Shield Wall) se perd au début du tour de l'ennemi suivant, comme tout Absorb ennemi. |
| Stunned | Voir règle 7 : étourdir après le seuil fait perdre l'ouverture. Posé pendant le tour ennemi (Freezing Trap), il arrête l'intention annoncée, et l'ouverture vient au tour suivant. |
| Cast / Interrupt | Une incantation ennemie remplacée par une ouverture est perdue. Une ouverture en Cast s'interrompt normalement. |
| Traps | Une Trap qui fait franchir le seuil suit la règle « après ton tour » : l'attaque en cours continue (sauf Stunned), l'ouverture vient au tour suivant. |
| Parry | Inchangé. Les ouvertures alternent un gros coup (Parry faible) et plusieurs petits (Parry fort). |
| DoT | Le tic au début du tour de l'ennemi franchit « après ton tour » : c'est l'outil pour retarder l'ouverture. Envenom / Exsanguinate (tics pendant ton tour) franchissent « pendant ton tour ». |
| Familier du Hunter | Attaques commandées : pendant ton tour. Attaque automatique de fin de tour : après ton tour. Le Hunter choisit donc le moment avec ses ordres. |
| Execute / Careful Aim | Aux normaux, le seuil est le même trait : l'ennemi change de phase au moment où Execute s'allume et où Careful Aim s'éteint. |

### Aucune classe sans réponse

| Phase type (ennemi) | Priest | Warrior | Mage | Rogue | Hunter |
|---|---|---|---|---|---|
| Ouverture en Cast (Pyromancer, Nefarian) | Silence | Pummel | Counterspell | Kick | Counter Shot, Wailing Arrow |
| Gros coup d'ouverture | PW: Shield, Pain Suppression | Absorb (Rage gagnée) | Frost Nova, Polymorph | Parry, Cheap Shot | Freezing Trap, Intimidation |
| Strength à l'entrée (Veteran, Rend, Nefarian) | Psychic Scream (Demoralized) | Demoralizing Shout | Frostbolt, Cone of Cold | Smoke Bomb, Crippling Poison | Concussive Shot, Frost Trap |
| Soin à l'ouverture (Medic) | DoT (franchir en fin de tour) | Execute | Pyroblast, Scorch | Eviscerate | familier en fin de tour |
| Absorb à l'entrée (Guardsman) | DoT (ignore l'Absorb) | Rend, Colossus Smash | Fireball DoT | poisons | Serpent Sting, Immolation Trap |
| Riposte (Fireguard) | DoT, Skills | Absorb | Living Bomb, DoT | poisons | familier (pas une carte) |
| Invocation (Hatcher) | Holy Nova, Mind Sear | Cleave, Whirlwind | Arcane Explosion, Blizzard | Fan of Knives | Multi-Shot, Explosive Trap |

### Ce que le moteur doit apprendre

`Data/Act1.lua` sait déjà : crochet `onDamaged` (VanCleef invoque à 50 %), `Combat.spawn`, `ai` et `pattern`,
`e.mem`, intentions `cast`, `fn`. Il manque :

1. Champ `phases = { { at = 0.5, name, say, enter = { actions… }, open = "move", pattern = {…} | ai } }` et
   `e.mem.phase` (index courant).
2. Contrôle dans `Combat.dealDamage` (branche ennemie, `loss > 0`, pas mort) — seul passage de toute perte de
   PV ennemie, DoT compris — → `Combat.enterPhase(c, e, k)` pour chaque seuil franchi.
3. `enterPhase` : journal `{ t = "phase", unit, n, name }`, `say`, actions d'entrée (réutiliser les actions de
   `executeMove` : `buff`, `block`, `summon`, `fn`), changement de motif (`e.mem.idx = nil`).
4. Intention : si `c.phase == "player"` et pas en fin de tour (nouveau drapeau `c.ending`, posé par
   `endPlayerTurn` avant l'attaque du familier) → `e.intent = open`, `e.interrupted = false`, journal
   `intent` ; sinon `e.mem.forced = open`, lu en premier par `Combat.chooseIntent`.
5. `Combat.intentInfo` / données d'affichage : liste des seuils restants (crans) et texte des phases.
6. Interface : crans, infobulles, bandeau de phase, changement de nom et de modèle (Nefarius → Nefarian).
7. Crochets communs `onEnemyPhase(e, k)` et `onEnemyBloodied(e)` (premier passage à ou sous 50 %), pour les
   bibelots des sections 8 et 9.
8. Bots : l'heuristique doit compter l'intention de remplacement (une copie par `Combat.clone` suffit) ;
   statistiques : phases atteintes, tours par phase, ouvertures perdues (Stunned), interrompues, subies.
9. Facultatif : VanCleef (`onDamaged` à 50 %) peut passer au même système.

## 3. Ennemis normaux (9)

Chiffres : analogue de Westfall × 1,72 environ. « Phase » = seuil à 50 %.

| id | Nom | PV | Intentions | Motif | Phase (≤ 50 %) | Rôle |
|---|---|---|---|---|---|---|
| `firebrand_grunt` | Firebrand Grunt | 33–38 | Hack : attack 14. Sunder Armor : attack 9, debuff Sundered 1. | hack, sunder (départ au hasard) | — | Front, analogue du Gnoll. |
| `rookery_whelp` | Rookery Whelp | 17–20 | Bite : attack 7. À la mort d'un autre Rookery Whelp : Strength 1. | bite | — | Nuée, analogue du Murloc. Version `minion` (10–12 PV, Bite 6) invoquée par le Hatcher. |
| `anvilrage_guardsman` | Anvilrage Guardsman | 43–48 | Shield Bash : attack 9 interrupts. Guard : block 14. Strike : attack 9 ×2. | bash, guard, strike (hasard) | **Shield Wall** — ouverture *Shield Wall* : block 20 ; motif ensuite : Shield Slam (attack 12, block 8), bash. | Mur ; franchir pendant son tour annule son attaque mais lui donne 20 Absorb. |
| `anvilrage_medic` | Anvilrage Medic | 26–29 | Heal : soigne de 10 l'allié le plus blessé (s'il lui manque ≥ 10 PV, pas deux fois de suite). Holy Smite : attack 9. | ia (comme le Mystic, sans Watch) | **Desperate Prayer** — ouverture *Desperate Prayer* : se soigne de 14. Même ia ensuite. | Soigneur ; à franchir en fin de tour (DoT, familier) pour voir la prière venir et le tuer avant. |
| `blazing_fireguard` | Blazing Fireguard | 34–38 | Flame Lash : attack 13. Fire Nova : attack 6, debuff DoT 3. | lash, nova (hasard) | **Fire Shield** — entrée : état Fire Shield 2 (chaque coup d'une de tes cartes Attack, Trap comprise, te fait perdre 2, Absorb d'abord ; le familier et le DoT ne déclenchent rien). Ouverture : Fire Nova. | Punit les coups multiples une fois entamé. |
| `firebrand_pyromancer` | Firebrand Pyromancer | 31–36 | Fireball (Cast) : attack 26. Scorch : attack 7 interrupts. | fireball, scorch (hasard) | **Combustion** — ouverture *Flamestrike* (Cast) : attack 18, debuff DoT 4. Motif ensuite : fireball, scorch. | Lanceur ; apprend « franchir puis interrompre ». |
| `blackhand_veteran` | Blackhand Veteran | 44–48 | Strike : attack 15. Shield Bash : attack 8 interrupts. Battle Shout : buff_allies Strength 1. | strike, bash, shout (hasard) | **Enraged** — entrée : Strength 4. Ouverture *Whirlwind* : attack 8 ×2 (12 ×2 avec Strength). Motif : strike, whirlwind. | Menace ; Demoralized, ou le tuer avant qu'il franchisse. |
| `rage_talon_dragonspawn` | Rage Talon Dragonspawn | 46–50 | Cleave : attack 17. Thunderclap : attack 8, debuff Demoralized 1. | cleave, thunderclap (hasard) | **Bellowing Roar** — ouverture *Bellowing Roar* : debuff Sundered 2 ⌛ et Demoralized 2 ⌛ sur toi, aucun dégât. Motif inchangé. | Franchir pendant son tour remplace un Cleave par deux tours d'affaiblissement (Cloak of Shadows, Berserker Rage, Insignia les retirent). |
| `rookery_hatcher` | Rookery Hatcher | 36–40 | Strike : attack 12. Tend Eggs : block 12. | strike, tend | **Hatch** — ouverture *Hatch the Eggs* : summon 2 Rookery Whelp (`minion`). Motif inchangé. | Invocateur ; le tuer d'un coup depuis le haut, ou franchir quand on a un sort de zone. |

7 sur 9 utilisent la mécanique.

**Groupes** (`ns.Encounters.blackrock`) :

- `easy` : { grunt, grunt } ; { whelp, whelp, whelp } ; { guardsman } ; { pyromancer, whelp }.
- `normal` : { grunt, grunt, medic } ; { guardsman, pyromancer } ; { veteran, medic } ; { hatcher, whelp } ;
  { fireguard, fireguard } ; { dragonspawn, grunt } ; { whelp, whelp, whelp, whelp }.
- Rencontres : `event_fineous` { guardsman, medic } ; `event_jail` { guardsman, guardsman } ;
  `event_rookery` { whelp ×4 } ; `event_core` (élite) { fireguard, fireguard } ; `event_nefarius`
  { veteran, veteran }.

## 4. Élites (3)

| id | Nom (réel) | PV | Idée de combat |
|---|---|---|---|
| `panzor` | **Panzor the Invincible** (golem rare de Blackrock Depths) | 130 | Deux decks à la suite : d'abord les coups nombreux, ensuite les gros coups. |
| `rend_gyth` | **Warchief Rend Blackhand** sur **Gyth** (Upper Blackrock Spire) | 150 | Deux ennemis dans une barre : les souffles de Gyth posent des états durables, puis Rend frappe à pied. |
| `vaelastrasz` | **Vaelastrasz the Corrupt** (Blackwing Lair) | 260 max, commence à 78 (30 %) | Course : mana gratuit et dégâts qui montent ; le seuil à 15 % retire le mana. |

### Panzor the Invincible — 130 PV, seuil 50 %

- **Phase 1, Invincible** (règle) : chaque coup lui inflige **au plus 6** (après Strength, Sundered ; avant
  son Absorb). Le DoT n'est pas un coup : il passe en entier.
  - Stomp : attack 8 ×2. Pulverize : attack 22 interrupts. Overheat : buff Strength 2 (cumulable).
  - Motif : stomp, pulverize, overheat.
- **Phase 2, Cracked Plating** (≤ 65) : perd Invincible ; entrée : Sundered permanent (état `armor_broken`
  sans durée) ; ouverture *Rampage* : attack 9 ×3. Motif : pulverize, stomp.
- Durée visée : 3 tours en phase 1 (DoT, coups multiples, familier), 2 en phase 2. Réponse de chaque classe en phase 1 : SW: Pain et Penance ; Rend, Raging Blow, Rampage ;
  Fireball (DoT), Arcane Missiles, Flurry ; poisons, Mutilate, Killing Spree ; familier, Rapid Fire, Traps de DoT.

### Warchief Rend Blackhand et Gyth — 150 PV, seuil 50 %

- **Phase 1, Gyth** (le dragon, Rend sur son dos ; nom affiché « Gyth ») :
  - Flame Breath : attack 12, debuff DoT 4. Corrosive Acid : attack 8, debuff Sundered 2 ⌛.
    Freeze : attack 6, debuff Demoralized 1 ⌛. Knock Away : attack 16 interrupts.
  - Motif : flame, knock, corrosive, freeze.
- **Phase 2, Rend dismounts** (≤ 75 ; réplique de Rend : `"I'll finish this myself!"`) : nom et modèle
  deviennent « Warchief Rend Blackhand » ; entrée : Strength 3 ; ouverture *Cleave* : attack 20.
  Motif : Whirlwind (attack 7 ×3), Mortal Strike (attack 24).
- Décision : les états de Gyth restent sur toi en phase 2 ; franchir quand Sundered est retombé. Whirlwind
  (3 coups) contre Mortal Strike (1 gros) : le Parry et l'Absorb ne valent pas la même chose d'un tour à
  l'autre. ≈ 5 tours.

### Vaelastrasz the Corrupt — 260 PV max, commence à 78, seuil 15 % (39)

- **Début du combat** : état **Essence of the Red** sur toi : +2 mana à chaque tour (texte : `+2 mana each
  turn.`).
- **Phase 1** :
  - Burning Adrenaline : debuff sur toi `Burning Adrenaline 2 ⌛` : tes Attacks infligent 50 % de plus ;
    quand l'état prend fin, tu perds 15 PV (ignore l'Absorb ; Last Breath possible).
  - Flame Breath : attack 14, debuff DoT 4. Cleave : attack 22.
  - Motif fixe : burning_adrenaline, flame, cleave.
- **Phase 2, Essence fades** (≤ 39) : Essence of the Red prend fin (le mana en plus cesse au tour suivant) ;
  ouverture *Fire Nova* : attack 10 ×2. Motif : cleave, flame.
- Décision : avec 5 mana, 78 PV tombent en 2 tours ; franchir 39 sans pouvoir finir le même tour coûte le
  mana en plus. Burning Adrenaline : profiter des +50 % et prévoir les 15 PV. Élite de 2 à 3 tours, le plus
  court et le plus violent.

## 5. Boss : Nefarian — combat final

**Pourquoi Nefarian et pas Onyxia** : Onyxia vit dans le marais d'Âprefange, hors de la montagne ; Nefarian
règne au sommet de Blackrock Spire (Blackwing Lair), dirige le clan Blackrock et les dragons noirs de toute la
zone, et son combat a trois phases dans le jeu (Nefarius sur le trône avec les drakônides, Nefarian qui se
pose et lance les appels de classe, les os des drakônides qui se relèvent à 20 %). Les trois phases existent
déjà ; on les chiffre.

**PV 165**, seuils **75 %** (124) et **25 %** (41). Une seule unité, dont le nom et le modèle changent :
« Lord Victor Nefarius » (humain) en phase 1, « Nefarian » (dragon) ensuite. Immunisé à Stunned.

### Phase 1 — Lord Victor Nefarius, sur le trône (165 → 124)

- Au départ : Nefarius + **Red Drakonid** + **Blue Drakonid** (`minion`, 24 PV chacun : la mort de Nefarian
  met fin au combat).
  - Red Drakonid : Claw (attack 8), Flame Breath (attack 4, debuff DoT 3). Motif alterné.
  - Blue Drakonid : Claw (attack 8), Frost Breath (attack 4, debuff Demoralized 1 ⌛). Motif alterné.
- Règle **Shadow of the Throne** : tant qu'un Drakonid vit, Nefarius subit la moitié des dégâts (arrondi
  bas, comme `halved`). Infobulle : `Takes half damage while a Drakonid lives.`
- Intentions de Nefarius :
  - Shadow Bolt (Cast) : attack 20.
  - Shadow Bolt Volley : attack 6 ×2.
  - Fear : attack 5, debuff Demoralized 2 ⌛.
  - Dark Mending : soigne de 10 l'allié le plus blessé (lui compris).
  - Call Drakonids : summon 1 Drakonid (rouge puis bleu, en alternance).
  - ia : moins de 2 Drakonids vivants et dernière intention ≠ Call → Call ; sinon un allié à qui il manque ≥ 10
    PV et dernière ≠ Dark Mending → Dark Mending ; sinon le motif shadow_bolt, volley, fear.
- Compteur `mem.fallen` : Drakonids tués pendant la phase 1.
- Ce qu'il éprouve : le groupe qui se soigne (Dark Mending) et le bouclier par les sbires (Throne) : tuer un
  Drakonid d'un coup avant qu'il soit soigné, ou frapper Nefarius à moitié.

### Phase 2 — Nefarian se pose (124 → 41)

- Réplique : `"Well done, my minions. The mortals' courage begins to wane! Now let's see how they contend
  with the true Lord of Blackrock Spire!"`
- Entrée : nom et modèle « Nefarian » ; Throne prend fin pour de bon ; plus d'appel ni de soin ; les
  Drakonids restants continuent.
- **Ouverture : Class Call** (intention « debuff », pas un Cast : ne s'interrompt pas). Pose sur toi un
  **état propre à ta classe, 2 ⌛**, qui vise son moteur (tableau plus bas). Réplique selon la classe.
- Motif : shadow_flame, tail_sweep, veil, class_call.
  - **Shadow Flame** (Cast) : attack 28, debuff DoT 4. Avec le bibelot Onyxia Scale Cloak : pas de DoT (le
    clin d'œil au raid, en plus des −2 par coup du bibelot).
  - **Tail Sweep** : attack 11 ×2.
  - **Veil of Shadow** : attack 7, debuff **Veil of Shadow 3 ⌛** : tes soins et ta Regen sont réduits de
    moitié (nouvel état ; infobulle `Heals and Regen are halved.`).
  - **Class Call** : à nouveau (l'état est reposé pour 2 ⌛).

| Classe | Réplique (cri du jeu) | État posé, 2 ⌛ | Texte de l'état (anglais) | Icône |
|---|---|---|---|---|
| Priest | `"Priests! If you're going to keep healing like that, we might as well make it a little more interesting!"` | Corrupted Healing | `Each heal also applies DoT 2 to you.` | `spell_shadow_shadowmend` |
| Warrior | `"Warriors, I know you can hit harder than that! Let's see it!"` | Berserker Stance | `You are Sundered. Your Attacks deal 2 more.` | `ability_warrior_innerrage` |
| Mage | `"Mages too? You should be more careful when you play with magic..."` | Wild Polymorph | `Your Cast cards cost 1 more.` | `spell_nature_polymorph` |
| Rogue | `"Rogues? Stop hiding and face me!"` | Called Out | `Lose all Parry and Stealth. You can't gain Stealth.` | `spell_nature_earthbind` |
| Hunter | `"Hunters and your annoying pea-shooters!"` | Broken Bow | `Your Attack cards deal 3 less. Your pet is unaffected.` | `inv_weapon_bow_05` |

Ce sont des affaiblissements ordinaires : Berserker Rage, Cloak of Shadows et l'Insignia les retirent.
Berserker Stance est le seul à double tranchant (Sundered contre +2 par coup) : le Warrior peut vouloir le
garder. Décision du joueur : aucune carte nuisible n'est ajoutée au deck à Blackrock (trois zones le font
déjà) ; l'appel de classe passe donc par un état.

### Phase 3 — « Impossible! Rise, my minions! » (41 → 0)

- Réplique : `"Impossible! Rise, my minions! Serve your master once more!"`
- Entrée :
  - **Bone Constructs** : autant que de Drakonids tués en phase 1 (`mem.fallen`), 3 au plus. `minion`, 9 PV,
    Bone Strike (attack 6). Ils **agissent dès ce tour ennemi**, même s'ils se relèvent pendant le tour
    ennemi (embuscade : drapeau `ambush` sur l'invocation, la boucle de `Combat.enemyPhase` les inclut).
  - Strength 3 (Frenzy).
  - Compte à rebours **Shadowflame Fury 4 ⌛** (état sur Nefarian, baisse à chaque fin de round). À 0 :
    Strength 8 de plus. Infobulle : `When this runs out: Nefarian gains Strength 8.`
- Ouverture : **Bellowing Roar** : attack 6 ×2, debuff Demoralized 1 ⌛.
- Motif : shadow_flame, cleave (attack 20), tail_sweep.
- Mort : `"This cannot be! I am the master here! You mortals are nothing to my kind! Do you hear me?
  Nothing!"`

### Durée et ce que le combat éprouve

Déroulé visé (dégâts du joueur ≈ 27 par tour sur une cible) : **phase 1 en 3 tours** (2 Drakonids = 48, puis
Nefarius 41), **phase 2 en 3 tours** (83), **phase 3 en 2 tours** (41 + 0 à 27 de Bone Constructs) :
**8 tours** (7 à 9 selon le deck). Dégâts subis par tour ≈ VanCleef × 1,72 (≈ 16 à 25 selon la phase).

| Ce que les zones ont appris | Où Nefarian l'éprouve |
|---|---|
| Le deck construit (cartes ajoutées, moteur de classe) | Class Call (phase 2), deux fois au moins : un état qui vise le moteur de la classe pendant 2 tours ; un deck qui ne repose que sur ce moteur doit tenir ces tours-là. |
| Groupe qui se soigne | Dark Mending de Nefarius sur ses Drakonids (phase 1). |
| Embuscade | Bone Constructs qui frappent dès leur arrivée (phase 3). |
| Effets durables | Veil of Shadow, DoT de Shadow Flame, Fear (Demoralized 2 ⌛). |
| Durée comptée | Shadowflame Fury 4 ⌛ (phase 3). |
| Phases (Blackrock) | Le combat entier ; ouvertures en Cast ou en cri, boss immunisé à Stunned. |

Tension voulue : tuer les Drakonids lève le Throne mais nourrit la phase 3 (un Bone Construct par Drakonid
tué) ; passer en phase 3 par le DoT laisse partir l'intention annoncée.

## 6. Rencontres (8)

Au format de `Data/Events.lua` (`act = 7`). Nouveaux décors : `span`, `tavern`, `prison`, `spire`.

```lua
event("dark_iron_legacy", {
  name = "The Dark Iron Legacy", act = 7, tier = 0,
  speaker = "Franclorn Forgewright", npc = "franclorn_forgewright", scene = "span",
  text = "\"I built this city for the Dark Iron, and Fineous Darkvire took my hammer, Ironfel, when I died. "
    .. "Kill him and bring Ironfel to the Shrine of Thaurissan.\"",
  choices = {
    { label = "Hunt down Darkvire", outcome = "Fight 2 Dark Iron: usual reward + 25g",
      result = "You find Fineous Darkvire in the Halls of Crafting, with his guards.",
      effects = { { "fight", "event_fineous", gold = 25 } } },
    { label = "Rest at his statue", outcome = "Heal 25% of max HP",
      result = "You sleep at the foot of Franclorn's statue. The Dark Iron patrols do not come here.",
      effects = { { "healPct", 0.25 } } },
    { label = "Ask for the Shadowforge Key", outcome = "Pay 60g, Shadowforge Key (relic)",
      when = { { "unlocked", "shadowforge_key", hide = true } },
      result = "\"Darkvire sold a copy of the key to a goblin. I know which one.\" You buy it back.",
      effects = { { "pay", 60 }, { "relic", "shadowforge_key" } } },
    { label = "Leave", outcome = "Nothing",
      result = "You leave the ghost on the bridge.", effects = {} },
  },
})

event("thorium_brotherhood", {
  name = "The Thorium Brotherhood", act = 7, tier = 0,
  speaker = "Lokhtos Darkbargainer", npc = "lokhtos_darkbargainer", scene = "tavern",
  text = "\"The Thorium Brotherhood trades with anyone who pays. I have smithing plans, "
    .. "and a Dark Iron recipe that costs more than gold.\"",
  choices = {
    { label = "Buy smithing plans", outcome = "Pay 45g, upgrade a card, then 1 random card",
      result = "You work at the Black Anvil with the Brotherhood's smiths.",
      effects = { { "pay", 45 }, { "upgrade" }, { "upgradeRandom", 1 } } },
    { label = "Pay in blood", outcome = "-6 max HP, one of 3 rare cards",
      result = "Lokhtos fills a vial with your blood and hands you the recipe.",
      effects = { { "loseMaxHp", 6 }, { "cardChoice", n = 3, rarity = "rare" } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Come back with gold.\"", effects = {} },
  },
})

event("kharan_mighthammer", {
  name = "The Prisoner of Ironforge", act = 7, tier = 1,
  speaker = "Kharan Mighthammer", npc = "kharan_mighthammer", scene = "prison",
  text = "\"I'm Kharan Mighthammer, of Ironforge. Thaurissan has kept me in this cell for years. "
    .. "Give me a weapon and I'll break out on my own, or listen to what I know about this place.\"",
  choices = {
    { label = "Give him a weapon", outcome = "Remove a card from the deck, +20g",
      result = "Kharan takes the weapon and gives you the coins hidden in his boot.",
      effects = { { "remove" }, { "gold", 20 } } },
    { label = "Listen to him", outcome = "-5 HP, one of 3 uncommon cards",
      result = "The guards hear you talking and you have to fight one at the door. Kharan's advice was worth it.",
      effects = { { "loseHp", 5 }, { "cardChoice", n = 3, rarity = "uncommon" } } },
    { label = "Leave", outcome = "Nothing",
      result = "You leave the Detention Block.", effects = {} },
  },
})

event("jail_break", {
  name = "Jail Break!", act = 7, tier = 1,
  speaker = "Marshal Windsor", npc = "marshal_windsor", scene = "prison",
  text = "\"Get me out of here. The Anvilrage guards carry the cell keys. Help me break out "
    .. "and Stormwind will pay you.\"",
  choices = {
    { label = "Break him out", outcome = "Fight 2 guards: usual reward, upgrade 1 random card",
      result = "You attack the two guards in front of the cells.",
      effects = { { "fight", "event_jail" }, { "upgradeRandom", 1 } } },
    { label = "Pick the lock", outcome = "40%: a relic, else -10 HP",
      effects = { { "gamble", 0.4,
        win = { { "relic" } },
        winText = "The lock opens. Windsor gives you what he hid in the cell.",
        lose = { { "loseHp", 10 } },
        loseText = "A guard catches you at the door and hits you before you escape." } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Then tell Stormwind where I am.\"", effects = {} },
  },
})

event("egg_collection", {
  name = "Egg Collection", act = 7, tier = 2,
  speaker = "Tinkee Steamboil", npc = "tinkee_steamboil", scene = "span",
  text = "\"I need Rookery eggs from the Spire for my research. The whelps guard the nests. "
    .. "Bring me some and I'll pay you, or buy one of my potions and go around.\"",
  choices = {
    { label = "Raid the Rookery", outcome = "Fight 4 whelps: usual reward + 30g",
      result = "You climb into the Rookery. The whelps attack.",
      effects = { { "fight", "event_rookery", gold = 30 } } },
    { label = "Buy a potion", outcome = "Pay 25g, a potion",
      result = "\"Fire resistance. Mostly.\"",
      effects = { { "pay", 25 }, { "potion" } } },
    { label = "Buy a Dark Iron Bomb", outcome = "Pay 40g, Dark Iron Bomb (card)",
      when = { { "unlocked", "dark_iron_bomb", hide = true } },
      result = "Tinkee hands you a bomb from under her table.",
      effects = { { "pay", 40 }, { "card", "dark_iron_bomb" } } },
    { label = "Decline", outcome = "Nothing",
      result = "Tinkee goes back to her notes.", effects = {} },
  },
})

event("molten_core", {
  name = "The Molten Core", act = 7, tier = 2, rarity = "rare",
  speaker = "Lothos Riftwaker", npc = "lothos_riftwaker", scene = "span",
  when = { { "hpAbove", 0.6 } },
  text = "\"I send those who are attuned down to the Molten Core. The fire elementals there are "
    .. "stronger than the ones in the Depths, and they guard Ragnaros's treasure.\"",
  choices = {
    { label = "Go down", outcome = "Elite fight (2 Blazing Fireguards): elite reward + 40g",
      result = "Lothos opens the portal. Two Fireguards wait on the other side.",
      effects = { { "fight", "event_core", kind = "elite", gold = 40 } } },
    { label = "Take a Core Fragment", outcome = "-8 HP, one of 3 rare cards",
      result = "You pick up a fragment of the Core at the edge of the lava. It burns your hand.",
      effects = { { "loseHp", 8 }, { "cardChoice", n = 3, rarity = "rare" } } },
    { label = "Leave", outcome = "Nothing",
      result = "\"Come back when you're ready.\"", effects = {} },
  },
})

event("bodley", {
  name = "Bodley's Ghost", act = 7, tier = 1, rarity = "rare",
  speaker = "Bodley", npc = "bodley", scene = "span",
  text = "You turn on the Extra-Dimensional Ghost Revealer and a gnome ghost appears. \"Finally! "
    .. "I'm Bodley. I died before I finished the Seal of Ascension. The gems I need are in the Spire.\"",
  choices = {
    { label = "Search the Spire for the gems", outcome = "50%: a relic, else -10 HP",
      effects = { { "gamble", 0.5,
        win = { { "relic" } },
        winText = "You find the gem in a chest of the Spire. Bodley gives you his reward.",
        lose = { { "loseHp", 10 } },
        loseText = "Orcs of the Blackhand find you first." } } },
    { label = "Buy his notes", outcome = "Pay 50g, upgrade 2 random cards",
      result = "Bodley dictates his notes on the Spire's defenders.",
      effects = { { "pay", 50 }, { "upgradeRandom", 2 } } },
    { label = "Turn the device off", outcome = "Nothing",
      result = "The ghost disappears.", effects = {} },
  },
})

event("lord_victor_nefarius", {
  name = "Lord Victor Nefarius", act = 7, tier = 0, rarity = "story", once = true,
  speaker = "Lord Victor Nefarius", npc = "lord_victor_nefarius", scene = "spire",
  when = { { "floor", 5 } },
  text = "A tall man in black and red waits at the top of the stairs. \"I am Lord Victor Nefarius. "
    .. "You have killed many of my servants. Serve me instead, and I will make you stronger.\"",
  choices = {
    { label = "Accept his gift", outcome = "-6 max HP, a relic",
      result = "Nefarius hands you a relic from his vault. You feel weaker as soon as you take it.",
      effects = { { "loseMaxHp", 6 }, { "relic" } } },
    { label = "Refuse", outcome = "Fight 2 Blackhand Veterans: usual reward + 30g",
      result = "\"Then die.\" Two of his guards step forward.",
      effects = { { "fight", "event_nefarius", gold = 30 } } },
    { label = "Walk past him", outcome = "Nothing",
      result = "Nefarius lets you pass. \"We will meet again, upstairs.\"", effects = {} },
  },
})
```

Paliers : deux au palier 0, deux au 1 (plus Bodley, rare), deux au 2 (dont Lothos, rare) ; une à histoire.
Chacune a une réponse sans condition.

## 7. Cartes de zone (5, une par classe, épiques)

Cartes définitives (épiques, pivots) : voir `docs/zones/cartes-de-zone.md`.

- Spirit Shell (Priest)
- Avatar (Warrior)
- Fingers of Frost (Mage)
- Cold Blood (Rogue)
- Lone Wolf (Hunter)

## 8. Commun débloqué par la première victoire du compte

### Cartes neutres (2)

| id | Nom (objet réel) | Rareté | Coût | Type | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|
| `dark_iron_bomb` | Dark Iron Bomb (ingénierie, plans de Blackrock Depths) | rare | 2 | Attack | Deal 4 to all. / Apply Stunned 1 ⌛ to all / Exhaust. | Deal 8 to all. … | `inv_misc_bomb_05` |
| `dark_iron_ale_mug` | Dark Iron Ale Mug (Grim Guzzler) | uncommon | 0 | Skill | Pay 3 HP. / Gain Strength 2 / Exhaust. | Pay 2 HP. … | `inv_drink_05` |

### Bibelots communs (3)

| id | Nom (objet réel) | Rareté | Effet (anglais) | Crochet | Icône |
|---|---|---|---|---|---|
| `blood_of_the_mountain` | Blood of the Mountain (réactif de Blackrock Depths) | common | `The first time each enemy drops to half HP, gain 4 Absorb.` | `onEnemyBloodied` | `inv_misc_gem_bloodstone_02` |
| `black_dragonscale` | Black Dragonscale (cuir des dragons noirs) | uncommon | `Enemy Cast attacks deal 4 less damage.` | `beforeHit` + drapeau Cast de l'intention | `inv_misc_monsterscales_03` |
| `shadowforge_key` | Shadowforge Key (clé de Blackrock Depths) | uncommon | `Treasure chests offer a choice of 2 relics.` | coffre (`Core/Expedition.lua`) | `inv_misc_key_08` |

Tous trois servent dans les autres zones (seuil à 50 %, ennemis qui incantent, coffres).

### Nouveau type de case : la Taverne (Grim Guzzler)

- Case de parcours, une au plus par carte, jamais avant l'étape 3. Hôte à Blackrock : **Plugger Spazzring**.
  Ailleurs, une auberge de la zone (à fixer par zone ; sinon la case n'apparaît qu'à Blackrock).
- On choisit **une boisson gratuite**, puis on peut en acheter **une seconde** (30 po). Effet pour **le
  prochain combat seulement** (nouvel état d'expédition `exp.nextCombat`, consommé par `Combat.new`).

| Boisson (objet réel) | Effet |
|---|---|
| Dark Iron Ale | `Next combat: start with Strength 2.` |
| Dragonbreath Chili | `Next combat: deal 6 to all enemies at the start.` |
| Thunderbrew Lager | `Heal 12 now.` |
| Rumsey Rum Black Label | `Next combat: start with 10 Absorb.` |

## 9. Bibelots de clé (+1, +3, +5)

| Clé | id | Nom (objet réel) | Origine | Effet (anglais) | Icône |
|---|---|---|---|---|---|
| +1 | `blackhands_breadth` | Blackhand's Breadth | Upper Blackrock Spire | `Attacks deal 4 more damage per hit to enemies at half HP or less.` | `inv_misc_gem_ruby_01` |
| +3 | `draconic_infused_emblem` | Draconic Infused Emblem | Upper Blackrock Spire | `Whenever an enemy changes phase or first drops to half HP, draw 1.` | `inv_misc_head_dragon_black` |
| +5 | `neltharions_tear` | Neltharion's Tear | Blackwing Lair (Nefarian) | `The first card played each turn costs 1 less.` | `inv_stone_15` |

Plus forts que les communs : Blackhand's Breadth est le double de Mark of the Champion sur la moitié basse de
chaque ennemi ; l'Emblem pioche 2 à 4 cartes par combat de groupe ; la Tear vaut presque +1 mana par tour.

## 10. Fin de campagne et titre « Dragonslayer »

Proposition :

- **Première victoire contre Nefarian avec une classe** (toute clé) : titre **« Dragonslayer »** pour cette
  classe (affiché sur l'accueil et l'écran de progression : « Priest — Dragonslayer »), trophée **Head of
  Nefarian** (`inv_misc_head_dragon_black`) sur l'écran de la classe, et la carte de zone de la classe (§ 7).
  C'est le titre que le nom du jeu promet : il récompense la campagne, pas l'expérience accumulée.
- **Niveau 7** : garde un titre, renommé (proposition : « Veteran »), puisqu'on peut l'atteindre sans finir.
- **Première victoire du compte** : le commun du § 8 et, en clin d'œil au jeu, **Rallying Cry of the
  Dragonslayer** : la prochaine expédition (toute classe, toute zone) commence avec +6 PV max.
- **Cinq classes Dragonslayer** : titre de compte « Grand Dragonslayer » (cosmétique).

## 11. Modèles et icônes

**Créatures** : `wow_creature_search` ne trouve rien pour ces noms. Le serveur MCP ne voyait d'abord aucune
installation (`WOW_INSTALL_PATH` non défini) ; relancé à part avec ce chemin, il ne trouve même pas Edwin
VanCleef (639, déjà utilisé dans `UI/Art.lua`) sur forever, vanilla ou mainline : sa recherche ne lit que les
créatures du cache du client. **Identifiants de créature et d'affichage : non trouvés** pour tous les PNJ
ci-dessous ; à relever sur une base externe. Les fichiers de modèle (`wow_model_search`) sont donnés comme
piste pour l'affichage.

| Unité | Modèle trouvé (FileDataID, chemin) | Icône (repli en médaillon) |
|---|---|---|
| Firebrand Grunt, Pyromancer, Blackhand Veteran, Rend | 121287 `character/orc/male/orcmale.m2` (personnage : affichage à trouver) | `inv_misc_head_orc_01` |
| Anvilrage Guardsman, Medic | 1890765 `character/darkirondwarf/male/darkirondwarfmale.m2` (moderne) ; personnage nain classique 118355 | `inv_misc_head_dwarf_01`, `inv_misc_head_dwarf_02` |
| Blazing Fireguard | 123934 `creature/fireelemental/fireelemental.m2` | `spell_fire_fire` |
| Rookery Whelp | 123610 `creature/dragonwhelp/dragonwhelp.m2` | `ability_hunter_pet_dragonhawk` |
| Rage Talon Dragonspawn, Rookery Hatcher | 123543 `creature/dragonspawn/dragonspawn.m2`, 123544 `dragonspawnarmored.m2` | `inv_misc_head_dragon_black` |
| Red / Blue Drakonid | non trouvé (pas de `drakonid` d'époque ; piste 123553 `dragonspawngreater.m2`) | `inv_misc_head_dragon_red`, `inv_misc_head_dragon_blue` |
| Bone Construct | 125942 `creature/skeleton/skeleton.m2` (piste) | `spell_shadow_raisedead` |
| Panzor the Invincible | non trouvé (pistes : 124248 `creature/golemstone/golemstone.m2`, 234650 `golemiron.m2`) | `inv_gizmo_02` |
| Gyth | 123459 `creature/dragon/dragon.m2` (piste) | `inv_misc_head_dragon_bronze` |
| Vaelastrasz the Corrupt | non trouvé (piste 123459 `creature/dragon/dragon.m2`) | `inv_misc_head_dragon_red` |
| Lord Victor Nefarius | personnage humain, non trouvé | `achievement_boss_nefarion` |
| Nefarian | 123461 `creature/dragon/dragonnefarian.m2` | `achievement_boss_nefarion` (254649) |
| PNJ des rencontres (Franclorn, Lokhtos, Kharan, Windsor, Tinkee, Lothos, Bodley, Plugger) | non trouvés | `inv_misc_head_dwarf_01` (nains), `inv_misc_head_human_01` (Windsor), `inv_misc_head_gnome_01` (Bodley) |

**Icônes des cartes, bibelots et états** : toutes vérifiées par `wow_icon_search` et présentes dans
`~/Téléchargements/ICONS/` (§ 5 et 7 à 9). Taverne : `inv_drink_09`. Fonds : `achievement_zone_blackrock_01`,
`achievement_dungeon_upperblackrockspire`.

## 12. Questions ouvertes

1. **Seuil des normaux à 50 %, sur le trait d'Execute.** Tel quel, un ennemi s'énerve au moment exact où
   Execute s'allume et où Careful Aim du Hunter s'éteint : le Warrior est récompensé, le Hunter perd son bonus
   au pire moment (sauf avec Lone Wolf). À 60 %, les deux traits se séparent mais la barre porte deux marques.
2. **Passer à travers un seuil.** Sans plafond, un Rogue avec Cold Blood peut faire 41 → 0 et ne jamais voir
   la phase 3 de Nefarian. Avec un plafond pour le boss (« les dégâts s'arrêtent au seuil »), chaque
   joueur voit les trois phases, mais un gros coup peut être en partie perdu.
3. **Bone Constructs = Drakonids tués.** Tuer les Drakonids en phase 1 lève le Throne mais en ajoute autant en
   phase 3. Ou toujours 2 Bone Constructs : plus lisible, mais le choix de la phase 1 ne compte plus.
4. **Class Call : un état par classe** (5 états à coder et à mesurer ; chacun gêne le moteur de la classe
   pendant 2 tours, et le Warrior peut choisir de garder le sien) ou un seul état commun (Demoralized 2 ⌛),
   plus simple mais sans le clin d'œil au raid ni l'épreuve du deck construit.
5. **Titre « Dragonslayer »** : à la première victoire contre Nefarian avec la classe (proposé), ou rester au
   niveau 7 ? Dans le premier cas, quel titre pour le niveau 7, et Rallying Cry (+6 PV max à l'expédition
   suivante) est-il un cadeau acceptable ou un avantage à retirer ?
