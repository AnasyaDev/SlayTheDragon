# Ajouter une classe (contrat du socle multi-classes)

État au 12/11/2026. Le socle est en place, le Priest y est migré (résultats de simulation identiques à
graine égale) et le Warrior en est la preuve. Ce document est le contrat des classes suivantes : une
classe s'ajoute sans toucher au moteur, à l'interface ni au harnais, sauf besoin nouveau (à signaler).
GDD : `docs/gdd-classes.md` (copie du Claude Doc) ; fiches de conception : `docs/classes/<classe>.md`.

## Fichiers d'une classe

| Fichier | Contenu | Obligatoire |
|---|---|---|
| `Data/<Classe>.lua` | cartes (`class = "<id>"`), bibelots de classe (`class = "<id>"`), définition `ns.Classes.<id>` | oui |
| `Core/Classes/<id>.lua` | règles propres : `ns.ClassRules.<id>` (crochets, état de classe), conditions, effets, états, mots du langage | si la classe a une mécanique |
| `UI/Art/<id>.lua` | icônes des cartes et bibelots, voies, icône de classe, pastille de ressource, `ns.ClassViews.<id>` | oui |
| TOC | `Data\<Classe>.lua`, `Core\Classes\<id>.lua` (après les Data de la classe), `UI\Art\<id>.lua` (après `UI\Art.lua`) | oui |
| `Media/Icons/*.tga` + `UI/SkinData.lua` | `build/venv/bin/python -I tools/build_media.py --icons-only` (ajoute seulement les icônes nommées par `UI/Art.lua` et `UI/Art/*.lua`) | oui |

Un nouveau fichier dans le TOC impose de **relancer le client** (`/reload` ne suffit pas).
Ordre de chargement actuel : `Core\*` (dont `Core\Language.lua`), `Data\Priest.lua`, `Data\Warrior.lua`,
`Core\Classes\warrior.lua`, `Data\Act1.lua`… puis `UI\Art.lua`, `UI\Art\warrior.lua`, le reste de `UI\`.
Fichiers communs que deux classes ajoutées en parallèle modifient toutes deux : le TOC et `UI/SkinData.lua`
(table `icons`, triée : conflit de fusion trivial, ou relancer `--icons-only` après la fusion).

## Définition de classe (`Data/<Classe>.lua`)

```lua
ns.Classes.warrior = {
  id = "warrior", name = "Warrior", order = 2, hp = 80,   -- order : place sur l'accueil
  resource = { id = "rage", cap = 5, keep = true },        -- id du registre du langage ; cap nil = sans
                                                           -- plafond ; keep = false : remise à 0 au début du tour
  deck = { "strike", "strike", ... },                      -- 10 cartes de départ
  startRelic = "battle_standard",                          -- bibelot de départ (noPool), ou nil
  paths = { { id = "arms", name = "Arms" }, ... },         -- les trois voies (champ path des cartes)
  survival = "absorb",                                     -- kill | control | heal | absorb (GDD)
  playable = true,                                         -- false : cachée sur l'accueil
  bot = {                                                  -- conseils aux bots de simulation (Sim/)
    resValue = 6,                                          -- valeur d'un point de ressource (10 = 1 PV)
    rating = { mortal_strike = 6, ... },                   -- note des cartes pour les choix (≈ 5 + écart/2)
    upgrade = { strike = 2.5, ... },                       -- valeur d'amélioration des cartes de départ
    remove = { defend = 1, strike = 1.5 },                 -- cartes à retirer d'abord
  },
}
```

L'expédition enregistre la classe (`exp.class`), le combat aussi (`c.class`) ; la méta est déjà par classe
(`meta.classes[id]`). Les visuels (icônes, couleurs) ne sont jamais dans `Data/` : voir `UI/Art/<id>.lua`.

## Cartes

Champs de `Data/Priest.lua` (name, cost, type attack|skill|power, rarity basic|common|uncommon|rare, path,
target, effects, text, up, cast, cooldown, exhaust, retain, power, hooks, rep) plus :

| Champ | Règle |
|---|---|
| `class` | id de la classe ; absent = carte neutre (avec `neutral = true` : marchand et rencontres seulement, GDD) |
| `school` | champ libre (holy, shadow, fire, frost, arcane, nature…) : condition `school:<x>`, compteurs du tour, couleur |
| `payHp = N` | « Pay N HP. » en première ligne ; payé au jeu (crochet `payHp` pour le modifier), injouable s'il ferait tomber à 0 (raison `hp`) ; compte comme une perte de PV (`onHpLost`), n'est pas une attaque, ignore l'Absorb |
| `spend = N` | « Spend N: … » ; payé AU JEU si la ressource suffit (et si `spendNeed(c, inst)` le permet) ; `ctx.spent` à la résolution, gardé dans l'incantation pour une carte Cast |
| `minRes = N` | injouable sous N points de ressource (raison `resource`) : cartes Surge qui n'ont de sens qu'avec de la ressource |
| `slot = "nom"` | Power unique par emplacement (Seal, Demon, totem d'un élément) : en jouer un autre remplace l'ancien |
| `lasts = N` | Power à durée : retiré à la fin du N-ième round (crochet `powerLasts`) ; `c.player.powerTurns[uid]` |
| `replacedTo = "exhaust"` | un Power remplacé ou expiré part aux consumées (défausse par défaut) |
| `rep` | palier de réputation qui débloque la carte (0, 1, 2) ; un champ `level` (progression par classe) prendra le relais, lu par les mêmes filtres (`Card.inClass`, `Expedition.cardPool`) |

Raretés et voies : 34 cartes = 4 de départ (`rarity = "basic"`, `path = "start"`, pas de `rep`) + 13 communes,
11 inhabituelles, 6 rares ; 10 par voie ; `rep` 0/1/2 = 20/5/5 (test « cartes : par classe »).

### Effets (`Core/Effects.lua`) et options communes

Effets : `damage` (times, all, pierce, onHit, bonus), `absorb`, `apply` (état, n, all, self, `icon` = clé
d'art de la source), `heal`, `draw`, `mana`, `res` (« +N Rage. »), `surge` (« Surge: », toute la ressource,
`ctx.surge`), `loseHp`, `interrupt`, `cleanse`, `fn`. Une classe ajoute les siens dans `ns.Effects`.
Options lues sur tous les effets :

- `cond = "nom"` : l'effet ne s'applique que si la condition est vraie, **lue à la résolution** ;
- `more = { { k, "cond" } }` : valeur + k si la condition est vraie (« Spend 2: deal 5 more. ») ;
- `per = { k, "montant" }` : valeur + k × montant (« deal 4 + 4 per Insanity », Shield Slam).

Conditions (`Combat.CONDITIONS[nom](c, ctx, cible)`) : `execute`, `spent`, `surged`, `status:<id>` (la cible
porte l'affaiblissement, ou le joueur le bienfait), `school:<x>`. Montants (`Combat.AMOUNTS`) : `surge`,
`res`, `block`. Une classe enregistre les siens (`Combat.CONDITIONS.frozen = function(c, ctx, t) … end`).

Fonctions utiles : `Combat.gainRes(c, n, why)` (bornée, événement `resource`), `Combat.spendRes`,
`Combat.surge`, `Combat.loseHp(c, n, why)`, `Combat.lastBreath(c, clé)` (vrai une fois par combat),
`Combat.removePower`, `Combat.castCount`, `Combat.castSlots`, `Combat.payHpOf`.

## Règles de classe et événements (`Core/Classes/<id>.lua`)

```lua
ns.ClassRules.warrior = {
  init = function(c, cls) cls.hurt = false end,       -- au début du combat, avant onCombatStart
  hooks = { onHpLost = function(c, cls, n, src, hpBefore) ... end, cost = function(c, cls, v, d, inst) ... end },
  botKey = function(c) return "..." end,              -- état qui distingue deux positions (bots)
  botValue = function(c, W) return 0 end,             -- valeur propre ajoutée à l'évaluation (bots)
}
```

Les crochets de la classe passent **avant** ceux des Powers, bibelots et affixes, avec `src = c.cls`.
Les mêmes noms servent aux Powers (`def.hooks`, src = instance) et aux bibelots (`relic.hooks`, src = id).
`c.cls` est l'**état de classe** : table de données simples (nombres, chaînes, booléens, tables), copiée en
profondeur par `Combat.clone`, sauvegardée avec le combat. Ressource : `c.player.res`.

Valeurs modifiées (`Combat.modify`, le crochet renvoie la nouvelle valeur) :

| Nom | Arguments après la valeur | Quand |
|---|---|---|
| `cost` | d, inst | coût d'une carte |
| `payHp` | d, inst | coût en PV d'une carte |
| `damage` | cible, d | dégâts d'un coup du joueur (avant Demoralized / Sundered) |
| `enemyDamage` | ennemi, joueur | dégâts d'un coup ennemi (aussi pour l'affichage des intentions) |
| `beforeHit` | ennemi, action | coup ennemi réellement porté, avant Absorb (Parry, Traps) : 0 = coup annulé |
| `apply` | état, cible, d | valeur d'un état posé sur un ennemi |
| `block`, `heal` | — | Absorb gagné, soin reçu |
| `target` | d, inst | cible d'une carte (rediriger) ; la cible retenue va dans `c.player.lastTarget` |
| `instantCast` | d, inst, commit | une carte Cast part tout de suite (Instant, Maelstrom) ; ne rien consommer si commit est faux |
| `castSlots` | — | nombre d'incantations tenues à la fois (1 ; Mage : 2) |
| `powerLasts` | d, inst | durée d'un Power à durée |
| `dotDecay` | unité | baisse du DoT après son tick (1 ; Agony : 0) |
| `maxMana`, `drawPerTurn`, `enemyHp`, `canFlee` | — | inchangés |

Notifications (`Combat.fire`, un crochet qui renvoie true arrête la chaîne) :

| Nom | Arguments | Quand |
|---|---|---|
| `onCombatStart` | — | après `init`, avant le premier tour |
| `onTurnStart` / `onTurnEnd` | — | début du tour joueur (après pioche et mana) / fin (avant la défausse) : Powers de fin de tour, familier, démon |
| `onRoundEnd` | — | après le tour ennemi, avant la baisse des durées |
| `onCardCommitted` | inst, d, cible | carte jouée, tous ses coûts payés, avant incantation ou résolution (Hot Streak, baguette) |
| `beforeCard` | inst, ctx | début de la résolution |
| `onCardPlayed` | inst, ctx | fin de la résolution (Rage par Attack, Deep Wounds) |
| `onCastStart` / `onCastResolved` | inst | incantation posée / résolue |
| `onPayHp` | n, inst | paiement « Pay N HP » (avant la perte) |
| `onSpend` | n, inst | Spend payé |
| `onResource` | variation, raison | ressource changée |
| `onHpLost` | n, source, PV d'avant | toute perte de PV du joueur (coup : l'ennemi ; « pay » ; « effect » ; nil = DoT) |
| `onPlayerHit` | ennemi, n | coup ennemi qui fait perdre des PV |
| `afterHit` | ennemi, PV perdus, absorbés | après chaque coup ennemi, même absorbé (ripostes, Traps) |
| `onStatusApplied` | unité, état, n | état posé |
| `onDotTick` | unité, n | après le tick d'un DoT |
| `onEnemyDeath` | ennemi | mort d'un ennemi (Soul Shards) |
| `onPowerEnd` | inst, raison | Power remplacé (`replaced`) ou expiré (`expired`) |
| `preventDeath` | — | le joueur tombe à 0 : true = sauvé (Last Breath) ; l'événement `saved` porte la source |
| `onVictory`, `onPotion`, `onFlee`, `preventInterrupt` | | inchangés |

Une classe peut émettre ses propres événements (`Combat.fire(c, "onShift", forme)`) : Powers et bibelots
de la classe s'y abonnent par le même mécanisme.

Ordre d'un coup joué (`Combat.play`) : cible (crochet `target`), coûts payés **maintenant** (mana, PV,
Spend si la ressource suffit ; une carte Cast interrompue ne rend rien), compteurs du tour
(`c.turn.played`, `c.turn.byType[type]`, `c.turn.bySchool[école]`, remis à 0 au début du tour),
`onCardCommitted`, puis incantation ou résolution (conditions lues là).

Début du tour : Absorb à 0, états `clearAtTurnStart` retirés, DoT et Regen, ressource remise à 0 si
`keep = false`, **mana remis à son maximum**, incantations résolues (de la plus ancienne à la plus
récente : `c.player.cast` puis `c.player.castMore`), recharges, pioche, `onTurnStart`, intentions.
Une interruption ennemie coupe l'incantation **la plus récente**.

## Langage des cartes (`Core/Language.lua`)

Registre partagé par le moteur, l'interface (couleurs, coupures, explications au survol) et le harnais.
Déjà déclarés : les ressources des neuf classes (Insanity, Rage, Combo Point(s), Arcane Charge(s), Soul
Shard(s), Frenzy, Holy Power, Maelstrom), les conditions Execute, Surge, Spend N, Last Breath, Shadow,
Frozen, Demon, Judgement, Shift, Caster, Bear, Cat, Moonkin, le mot « Pay N HP », les mots de plaque
Power, Trap, Seal, Demon, Totem N, Shift, Cast, Cooldown N, Exhaust, Retain, et les déclencheurs de Power
(« When hit », « HP lost », « Attacks », « Start of turn », « End of turn », « Each Absorb gain »,
« Cast cards »). Une classe en ajoute depuis ses fichiers :

```lua
local L = ns.Language
L.condition("stealth", { name = "Stealth", text = "bonus effect while in Stealth." })
L.trigger("Each enemy DoT tick")
L.plate("trap", { word = "Trap", head = true, text = "triggers on the next enemy attack." })
L.keyword("drain", { name = "Drain", text = "…" })
```

Les **états** (`ns.Statuses`) sont des mots-clés d'office (couleur, insécable, « Name: » = condition sur
l'état, explication) : un état propre se déclare dans `Core/Classes/<id>.lua` (`ns.Statuses.parry = {…}`,
`Art.statusShort.parry` pour la définition courte). Un état `clearAtTurnStart = true` est retiré au début
du tour du joueur. Explications : une phrase de 60 caractères au plus, « %s » = nom de la ressource de la
classe de la carte, « N » = nombre.

Forme des textes (vérifiée par le harnais U27 pour toute carte de `ns.Cards`) : une clause par ligne ;
« Pay N HP. » en première ligne ; « +N Rage. » (singulier / pluriel du registre) pour chaque effet `res`
sans condition ; « Spend N: … » ⇔ `spend = N` ; « Surge: … » ⇔ effet `surge` (« deal B + K per Rage. » ou
« Deal B. » puis « …: deal K per Rage. ») ; « Execute: … » ⇔ condition `execute` ; états posés en dernier
(« Gain » / « Apply », sablier pour une durée) ; aucun « you / your » ; libellé « Name: » connu du
registre ; aucune ressource d'une autre classe. Le texte doit tenir dans le panneau (U22, toutes les cartes).

## Interface (`UI/Art/<id>.lua`)

```lua
Art.cards.<carte> = { tga = "Ability_Warrior_Cleave", spell = 845, icon = "Interface\\Icons\\ability_warrior_cleave" }
Art.paths.<voie> = { name = "Arms", ring = hex("#b0743a"), ink = hex("#6b3f12") }
Art.relics.<bibelot> = { tga = "INV_Banner_02", … }
Art.classes.<id> = { tga = "ClassIcon_Warrior", wow = "WARRIOR",           -- wow = UnitClass("player")
  resource = { tga = "Ability_Warrior_FocusedRage", color = "attackText" } } -- pastille, chiffres flottants
Art.statusIcons.<clé> = { tga = … }        -- icône d'un état selon sa source (apply … icon = "bleed")
ns.ClassViews.<id> = { build = function(hôte, vue) end, render = function(hôte, combat, vue) end }
```

- **Pastille de ressource** (générique, `UI/CombatView.lua`) : petit anneau doré près du mana, icône de la
  ressource de la classe jouée, nombre, cachée à 0 ; infobulle = explication du registre et « n / plafond ».
- **Zone libre de classe** : cadre de 300 × 40 sous les états du héros ; `build` une fois par classe,
  `render` à chaque rendu du combat (formes du Druid, totems du Shaman, Seal du Paladin, familier du
  Hunter). Pas de cadre enfant dans un visuel survolable (docs/interface.md) ; ne lire que `c`.
- **Portrait** : visage du personnage si sa classe de jeu (`UnitClass`) est celle de l'expédition, sinon
  l'icône de classe. Nom de classe dans le bandeau et sur le cadre du héros.
- **Accueil** : une classe jouable apparaît d'office (ordre `order`) ; jusqu'à deux, grands boutons ; au-delà,
  grille de trois colonnes (PV, cartes et réputation en infobulle), le reste du panneau descend.
- Corps des cartes (`Art.cardBody`) : violet = école shadow, bleu = premier effet d'Absorb, or = départ,
  ivoire = le reste ; `Art.cards[id].body` force une couleur.

## Bibelots de classe

`class = "<id>"` : tirés seulement pour cette classe (récompenses, marchand, rencontres, choix de Révéré).
Le bibelot de départ porte `noPool = true` et `startRelic` dans la définition de classe. Six par classe
(GDD) : le bibelot de départ et cinq autres.

## Simulation et bots

`luajit Sim/sim.lua runs=2000 bot=heuristic jobs=8 runner=expedition key=0 class=<id>` ; balayage des
cartes : `… sweep=cards rep=2 runs=300` (chaque carte ajoutée de force au deck de départ). Une seule
simulation à la fois, `jobs=8` au plus. Les bots jouent les formes communes sans code de classe (ils
simulent chaque coup sur une copie) ; une classe les guide par `bot` (définition), `botKey` et `botValue`
(règles), et `Bots.POWER_VALUE[id]` pour un Power dont la valeur n'est pas la valeur par défaut. Cible :
60 à 80 % de victoires au bot heuristic, clé 0 (Priest ≈ 79 %, Warrior : voir son rapport).

## Exemple minimal

```lua
-- Data/Rogue.lua
local _, ns = ...
local function card(id, t) t.id, t.class = id, "rogue" ns.Cards[id] = t end
card("sinister_strike", { name = "Sinister Strike", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", effects = { { "damage", 6 }, { "res", 1 } }, text = "Deal 6.\n+1 Combo Point.",
  up = { effects = { { "damage", 9 }, { "res", 1 } }, text = "Deal 9.\n+1 Combo Point." } })
card("eviscerate", { name = "Eviscerate", cost = 1, type = "attack", rarity = "basic", path = "start",
  target = "enemy", minRes = 1, effects = { { "surge" }, { "damage", 5, per = { 5, "surge" } } },
  text = "Surge: deal 5 + 5 per Combo Point.", up = { … } })
ns.Classes.rogue = { id = "rogue", name = "Rogue", order = 3, hp = 70,
  resource = { id = "combo", cap = 5, keep = true }, deck = { … }, startRelic = "thieves_tools",
  paths = { … }, survival = "kill", bot = { resValue = 4, rating = { … } } }

-- Core/Classes/rogue.lua
local _, ns = ...
ns.Statuses.parry = { name = "Parry", text = "Cancels the next attack, up to 8 damage." }
ns.ClassRules.rogue = { hooks = {
  beforeHit = function(c, cls, dmg)
    local p = c.player
    if (p.st.parry or 0) > 0 and dmg <= 8 then ns.Combat.applyStatus(c, p, "parry", -1) return 0 end
    return dmg
  end } }
```

## Les mécaniques du GDD et leur point d'accroche

| Mécanique | Point d'extension |
|---|---|
| Rage (Warrior) | `onHpLost` + `onCardPlayed` de classe, `Combat.gainRes`, plafond `resource.cap` |
| Parry, Stealth (Rogue) | états de classe ; `beforeHit` (annuler un coup jusqu'à 8) ; condition « Stealth: » d'office (état), consommée dans `onCardPlayed` |
| Combo Points, coups de grâce | ressource `combo`, effet `surge` + `per`, `minRes` |
| Seals et Judgement (Paladin) | Power `slot = "seal"` ; condition `judgement` (registre prêt) à enregistrer dans `Combat.CONDITIONS` ; effet propre « déclenche le Judgement du Seal » dans `ns.Effects` |
| Holy Power, Spend 3 | ressource `holy` (cap 3), `spend = 3` |
| Instant, double Cast (Mage) | `instantCast` (commit), `castSlots` = 2, file `cast` + `castMore` (interruption : la plus récente), `onCastResolved`, `onCardCommitted` + `c.turn.bySchool` (Hot Streak), condition `school:fire` |
| Pay N HP, démon (Warlock) | `payHp` (crochet `payHp`, `onPayHp`), Power `slot = "demon"`, `replacedTo = "exhaust"`, `onTurnEnd`, `c.player.lastTarget`, `dotDecay`, `onDotTick`, `onEnemyDeath` |
| Powers de fin de tour | `onTurnEnd` sur le Power (avant la défausse) |
| Familier (Hunter) | état de classe `c.cls.pet`, attaque dans `onTurnEnd` sur `c.player.lastTarget`, Frenzy = ressource ; affichage dans `ns.ClassViews.hunter` |
| Traps (Hunter) | Power ou état de classe armé au jeu, déclenché dans `beforeHit` / `afterHit` (seul effet pendant le tour ennemi), puis retiré (`Combat.removePower`) |
| Totems à durée et emplacements (Shaman) | Power `slot = "fire"…`, `lasts = N` (+ `totem = N` pour la plaque), `powerLasts` (Totemic Relic), `onPowerEnd` ; affichage des quatre emplacements dans `ns.ClassViews.shaman` |
| Maelstrom à 5 : Cast instantané | `onResource` + `instantCast` |
| Formes et lignes « Forme: » (Druid) | état de classe `c.cls.form` ; conditions `bear`, `cat`, `moonkin`, `caster` (registre prêt) dans `Combat.CONDITIONS` ; `cond = "bear"` sur les effets ; événement propre `onShift` ; pastille : `resource = nil`, la forme dans `ns.ClassViews.druid` |
| DoT selon la source | `apply … icon = "poison"` → `unit.stIcon`, `Art.statusIcons.poison` |

## Sauvegarde

`Save.VERSION` 3, `Expedition.VERSION` 3 : migration de la Démence du combat en cours
(`c.player.demence` → `c.player.res`, `c.class`, `c.cls`). Une classe qui ajoute un état de combat le
range dans `c.cls` (données simples) : rien à migrer tant que les champs absents ont une valeur par
défaut. Une expédition d'une classe inconnue (fichier retiré) part en quarantaine (`Save.validateExpedition`).
