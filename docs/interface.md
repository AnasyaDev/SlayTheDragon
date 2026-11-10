# Interface en jeu (pistes C, D et E)

État au 10/11/2026. Rien n'a encore tourné dans le client : tout ce qui suit est vérifié hors jeu par
`Sim/ui_harness.lua` (logique, clics, animations en temps virtuel) et par des instantanés SVG des écrans
(`Sim/ui_render.lua`, rendu approximatif). La section « Tests en vol » liste ce qu'il reste à voir en jeu.

La piste C a écrit l'interface, la piste D l'a branchée sur la couche expédition, la **piste E** l'a
entièrement redessinée en « table de jeu illustrée » d'après les maquettes validées
(`docs/maquette/*.dc.html` : `Main`, `Cartes`, `Parcours`, `Recompense`, `Rencontre`).

## Piste E : ce qui a changé

- Fenêtre **1040 × 620** (au lieu de 900 × 520), déplaçable par le bandeau, échelle 60–150 %. Plus de
  cadre Blizzard ni de boutons gris : formes dessinées (rectangles arrondis, disques), parchemin, bois,
  polices Morpheus (titres, chiffres) et Friz Quadrata (texte), palette des maquettes (`Art.C`).
- **Scène commune** (`UI/Scene.lua`) : décor plein cadre en haut (y 44–424), plateau de bois en bas
  (y 424–614), personnages posés au sol avec ombre. Le décor est une illustration du jeu recadrée et
  teintée, avec dessous un décor **peint** en couches unies (champs, ferme, côte, mine, nuit) qui sert de
  repli ; `/slay decor` (ou Options → « Décor illustré ») bascule de l'un à l'autre.
- **Une seule carte** (`W.card`) partout : parchemin, liseré de rareté (blanc, vert, bleu), gemme de coût
  (rouge si le mana manque), nom (sur deux lignes s'il est long), médaillon rond cerclé à la couleur de la
  voie (Discipline bleu ciel, Ombre violet, Sacré or, Départ bronze), ligne de type (« Sort · Discipline »),
  texte avec chiffres en évidence, pastilles Incantation / Recharge N / Consumée / Conservée (retirées du
  texte). États : survolée (halo doré, plus claire, plus grande, devant), injouable (ternie, raison écrite
  en rouge à la place du texte, texte de retour au survol), améliorée (nom vert, chiffres changés en vert).
- **Pas de légende ni de panneau explicatif** : le journal de combat, les titres d'écran, l'intro de
  l'accueil, la légende et les libellés de la carte de parcours ont disparu. Restent annoncés : chiffres
  exacts des intentions, coût et texte des cartes, issue de chaque réponse d'une rencontre, prix chez le
  marchand, PV rendus au repos, raison d'une carte ou d'une action refusée. Les infobulles restent, à la
  demande (mots-clés, états, intentions, bibelots, potions, piles, recharges, deck). L'infobulle d'une
  carte n'explique plus que ses mots-clés (et l'amélioration, et la raison d'un refus) : la carte se lit
  d'elle-même.
- **Retour visuel** : carte jouée qui file vers sa cible (ou le héros), chiffres flottants (dégâts blancs,
  Absorption bleue, soins verts), portion de vie perdue qui reste claire puis se vide, secousse et éclair
  rouge de l'unité touchée, animation du modèle, mort en fondu, intention qui « s'exécute » (la bulle
  éclate, l'ennemi se jette vers le héros), pioche (les cartes arrivent du tas), main défaussée qui file à
  la défausse en fin de tour, bandeau de victoire en fondu, sons du jeu.
- Toutes les animations sont **cosmétiques et en file** : l'état du moteur est à jour avant elles ; pendant
  la file, barres, Absorption et intentions affichées suivent les événements, puis l'écran se resynchronise
  sur le moteur à la fin. Vitesse réglable (×0,5 à ×3), mode rapide (×0,15) ; une file en retard (clics
  rapides) se rattrape toute seule (délais ×0,6 au-delà de 5 événements en attente, ×0,35 au-delà de 10).
- **Rencontres** (piste F) : réponses lues par `Expedition.eventOptions` (désactivées comprises, grisées avec
  leur raison ; « ? » si `hidden`), texte après coup = `exp.event.result` (issue d'un pari comprise ;
  `rolls` n'est jamais affiché), champs `speaker`, `npc`, `scene`, `rarity` exploités s'ils sont présents ;
  sélection `dupe` (« choisis une carte à copier »).

## Fichiers

| Fichier | Rôle | API WoW |
| --- | --- | --- |
| `UI/Art.lua` | Palette, textures, décors (`Art.scenes`), personnages de rencontre (`Art.npcs`), sons, icônes (cartes, états, intentions, affixes, bibelots, potions, parcours), voies, mots-clés, animations | non |
| `UI/Persist.lua` | Chargement de `SlayTheDragonDB` par `Save.migrate`, options de l'interface (`db.options`, dont `decor`) | non |
| `UI/Controller.lua` | Couche mince écrans ↔ `Core/Expedition` (étapes génériques, combat, potions, fin, validation, décor de l'étape, mana max, nom du boss) | non |
| `UI/Widgets.lua` | Formes, polices, sons, interpolations, icônes, médaillon, carte unique, barre de vie, écusson d'Absorption, pastilles, boutons, infobulles, textes flottants, modèles | oui |
| `UI/Scene.lua` | Décor (illustration + décor peint), plateau, personnages (modèle, ombre, anneau de cible) | oui |
| `UI/Main.lua` | Fenêtre, bandeau, écrans, clavier, options, `/slay`, bouton de minimap | oui |
| `UI/CombatView.lua` | Écran de combat et ses animations | oui |
| `UI/Screens.lua` | Accueil, rencontre, feu de camp, récompense (et coffre), grille du deck, marchand, parcours, bilan et méta | oui |
| `UI/Flight.lua` | Événements : chargement, vol en taxi, combat réel, déconnexion | oui |
| `Sim/ui_harness.lua` | Harnais hors jeu (faux client WoW) | — |
| `Sim/ui_render.lua` | Rendu SVG approximatif des cadres du faux client (instantanés d'écrans) | — |

`UI\Scene.lua` est un **nouveau fichier du TOC** : il faut relancer le client (pas seulement `/reload`).
Les fichiers qui touchent l'API WoW commencent par `if not CreateFrame then return end` ; `Sim/load.lua`
saute de toute façon les lignes `UI\` du TOC. **Aucune règle de jeu dans `UI/`**.

## Écrans

Coordonnées : celles des maquettes, depuis le coin haut gauche de la zone intérieure (1034 × 614).

**Bandeau** (y 0–44, sur tous les écrans ; on le saisit pour déplacer la fenêtre) : à gauche la classe,
« PV », « po » ; au centre la zone (« Acte 1 · Marche de l'Ouest » sur la carte) et, ailleurs, la
progression de l'acte (points dorés franchis, point clair = étape en cours, losange rouge = boss) ; à
droite « Deck N » (hors combat, infobulle = contenu du deck), clé mythique (pastille violette « Clé +N »,
infobulle = affixes), bibelots (cases liserées à la rareté), séparateur, 3 fioles (potions), ≡ (options),
× (fermer).

| Phase / vue | Écran | Contenu |
| --- | --- | --- |
| aucune expédition | **Accueil** (`start`) | décor voilé, héros ; parchemin : titre, classes (plaques), clé +0…+5 en gemmes (verrouillées sombres ; infobulle = affixes et raison), icônes d'affixes de la clé choisie ; plateau : « Réputation et journal », dernière expédition et avertissements de sauvegarde, « Partir en expédition » |
| `start` | **Rencontre** (`choice`) | bibelot de classe (Révéré) : bulle, une plaque par bibelot (icône, nom, effet), « Partir sans bibelot » |
| `map` | **Parcours** | parchemin sans décor ; étapes en symboles (icône du type dans un disque, « ? » pour une rencontre) ; accessibles : halo doré, couleur du type ; franchies : disque rouge coché ; position actuelle : plus grande, bord doré, anneau crème ; à venir : disque beige, icône ternie (élite : bord violet) ; boss : losange rouge « Boss » et nom du boss ; chemin parcouru en trait rouge plein, départs possibles en pointillés dorés, le reste en pointillés bruns. Aucune légende ; infobulle = nom du type |
| `combat` | **Combat** | voir plus bas |
| `reward` | **Récompense** | décor du combat, héros ; 3 cartes en grand (survol : plus grandes) ; butin au sol à droite : bourse avec montant, bibelot, fiole (« Pas de place » si les emplacements sont pleins) ; plateau : tas du deck, « Reprendre la route ». Coffre (`chest`) : un coffre à ouvrir d'abord (clic, `Entrée` ou `1`). Rencontre : bulle du texte après coup |
| `campfire` | **Feu de camp** | décor de nuit, feu qui vacille, couchage (« +N PV » calculés par le moteur) = repos, grimoire (« Améliorer une carte ») = grille d'amélioration, « Reprendre la route » |
| `merchant` | **Marchand** | étal (tenture, comptoir) : 5 cartes avec étiquette de prix (rouge si trop cher, « Vendu »), bibelots puis fioles à droite avec prix ; plateau : tas du deck, plaque « Retirer une carte » avec son prix, « Partir » |
| `event` | **Rencontre** | décor `scene`, héros à gauche, personnage à droite (modèle si `npc` est dans `Art.npcs`, sinon rien), nom (`speaker`), bulle (titre + texte ; bord doré si `rare`, violet si `story`) ; plaques de réponses à la place de la main : libellé et l'issue sur une ligne (verte si elle commence par « + », « ? » si cachée), réponses impossibles grisées avec leur raison ; après coup : `exp.event.result` et « Continuer » |
| `select`, amélioration, retrait | **Grille du deck** (`deck`) | panneau de bois sur le décor voilé, titre court, cartes à 80 % (16 par page, flèches) ; amélioration : la carte survolée montre sa version améliorée ; plateau : « Retour » / « Passer » |
| `done` | **Bilan** (`end`) | parchemin : titre (vert ou rouge), bilan, barres de réputation ; « Nouvelle expédition », « Réputation et journal » |
| vue méta | **Méta** | parchemin : barres par classe et Ligue, 8 dernières expéditions ; « Retour » |

**Potions** : en combat, clic = boire ; potion à cible : clic, puis clic sur un ennemi (ou `Entrée` sur la
cible clavier) ; clic droit annule. Hors combat : « Les potions se boivent en combat » ; deux clics droits
en 3 s = jeter.

**Ramassage du butin** (récompense) : le moteur a déjà tout attribué ; l'interface retient à l'écran l'or,
le bibelot et la potion obtenus (`UI.hold`, soustraits du bandeau) tant qu'ils sont au sol. Clic sur un
objet : il file vers le bandeau. « Reprendre la route » fait partir le reste tout seul (0,5 s × vitesse)
puis quitte. Une fiole qui n'a pas trouvé de place (`potionTaken` faux) reste grise ; un clic la prend
(`takePotion`) si une place s'est libérée. « Passer les cartes » n'a plus de bouton : partir sans cliquer
de carte revient au même.

### Combat

- Décor plein cadre (Mortemines pour le boss, route sinon). Héros à gauche (x 96–296) : modèle 3D du
  joueur posé au sol, barre d'incantation au-dessus (nom du sort, cible, « au prochain tour »), écusson
  d'Absorption à gauche de la barre de vie, états et Pouvoirs actifs en pastilles dessous.
- Ennemis à droite (x 470–1022, 1 à 5, légèrement décalés en profondeur, réduits à 86 % à partir de 5) :
  bulle d'intention au-dessus (icône + chiffres exacts de `Combat.calcDamage`, « ×N » pour les coups
  multiples, « Guette », « Étourdi »… ; liseré rouge = attaque, bleu = défense / renfort, violet = guet /
  affaiblissement, vert = soin), modèle 3D avec ombre, anneau doré aux pieds de la cible (survol, ou cible
  clavier pendant une visée), barre de vie (+ écusson d'Absorption), nom (élite violet, boss orangé),
  états en pastilles.
- Plateau : orbe de mana « 2/3 » (mana max lu par `Combat.modify(c, "maxMana", …)`), pastille Démence
  (cachée à 0), pioche et défausse (tas avec nombre ; infobulles : contenu trié, consumées), main en arc
  au centre (cartes droites ; la survolée monte, grossit ×1,16, passe devant), mini-cartes des recharges
  (tours restants), « Fin du tour » doré.
- Fin de combat : « Victoire ! » / « Défaite » en grand, bouton « Continuer » / « Voir le bilan »,
  affichés quand la file d'animations est vide.

### Contrôles

- Souris : clic sur une carte (elle se lève), puis clic sur l'ennemi ; une carte sans cible se joue par un
  second clic ou un clic dans le décor. Glisser-déposer : sur l'ennemi, ou n'importe où dans le décor pour
  une carte sans cible. Clic droit : désélectionner.
- Clavier (capté seulement fenêtre ouverte, `SetPropagateKeyboardInput`) : `1`…`0` choisit une carte
  (même touche ou `Entrée` pour la jouer), `Tab` change de cible (`Maj+Tab` à rebours), `Espace` finit le
  tour (et « Continuer » après un combat), `Échap` ferme (les options d'abord). Ailleurs, `1`…`0` choisit
  (parcours : étapes accessibles de haut en bas ; accueil : clé +0…+5 ; feu de camp : 1 repos, 2 grimoire ;
  récompense : cartes, ou ouvrir le coffre), `Entrée`/`Espace` l'action par défaut. Toute autre touche est
  rendue au jeu.
- `/slay` : ouvrir/fermer ; `/slay options` ; `/slay art` (icônes, modèles et décors introuvables) ;
  `/slay modeles` (galerie des ennemis) ; `/slay decor` (décor illustré ou peint) ;
  `/slay facing <j> <e>` (orientation des modèles, radians) ; `/slay centre`.
- Bouton de minimap : clic gauche ouvre/ferme, clic droit options, glisser pour le déplacer.
- La fenêtre se masque à l'entrée en combat réel, refuse de s'ouvrir en combat, et se rouvre à la sortie
  du combat si l'on est toujours en vol.

### Animations (file de `CombatView`)

| Événement du moteur | Animation | Son (`Art.sounds`) |
| --- | --- | --- |
| `play` | la carte (fantôme) file de la main vers la cible ou le héros ; héros : sort | `play` |
| `draw`, `cooldown_back` | la carte arrive du tas (ou des recharges) à sa place | `card` |
| fin du tour (clic) | les cartes non gardées filent à la défausse | `endTurn` |
| `act` | la bulle d'intention éclate ; attaque : l'ennemi se jette vers le héros ; modèle : attaque / sort | — |
| `damage` | chiffre blanc « -N » (plus gros à 12+), portion de vie claire qui se vide, secousse, éclair rouge, modèle : encaisser ; Absorption : chiffre bleu, écusson qui baisse | `hit` / `bigHit`, `block` |
| `heal` / `block` | « +N » vert / bleu, barre ou écusson à jour | `heal` / `block` |
| `status`, `demence`, `mana` | petit texte flottant | — |
| `death` | modèle : mort, fondu de l'ennemi puis retrait ; héros : à terre | `enemyDeath` / `playerDeath` |
| `interrupt`, `cast_lost`, `stunned`, `say`… | texte flottant | `interrupt` |
| `turn` | « Tour N » en haut du décor | — |
| `result` | bandeau de fin en fondu (à la fin de la file) | `victory` / `defeat` |

Interpolations : un seul `OnUpdate` (`W.tween`) ; chaque interpolation a aussi un minuteur de secours qui
la termine (images sautées ; le harnais n'a pas d'`OnUpdate`).

## Contrôleur

`UI/Controller.lua` ne contient aucune règle. L'expédition en cours **est** `SlayTheDragonDB.current` :
`Expedition.act` la modifie sur place, rien n'est recopié. État propre à l'interface (jamais sauvegardé) :

```lua
Controller.ended  = { c, result, title, kind } -- combat tranché, bandeau affiché
Controller.ending = { summary, entry }         -- expédition archivée par Save.finish, bilan affiché
Controller.ui     = { view, class, key }       -- sous-écran (upgrade, remove, meta), choix de départ
```

- `Controller.step()` traduit la phase en étape générique `{ kind, title, text, options, ... }`.
  Une option a un `id` « verbe » ou « verbe:argument » : une action d'expédition (`path:12`,
  `pickCard:2`, `buyRelic:1`, `remove:5`, `choose:1`, `select:3`, `leave`…), une navigation
  (`ui:upgrade`, `ui:remove`, `ui:meta`, `ui:back`, `ui:new`) ou un choix de départ
  (`class:priest`, `key:2`, `go`).
- Option grisée = action absente de `Expedition.choices` ; sa raison vient d'un essai de l'action sur
  une **copie** de l'expédition (`Controller.reasonFor`), traduite par `Controller.REASONS`. Même
  principe pour les PV rendus au repos (essai de `rest` sur une copie). Rencontres : la raison vient de
  `Expedition.eventOptions`.
- Ajouts piste E (affichage seulement) : `Controller.scene()` (décor de l'étape : boss → `mine`, feu de
  camp → `night`, marchand → `shop`, rencontre → son champ `scene`, sinon `road`), `Controller.maxMana()`,
  `Controller.eventResult(exp)`, `step.bossName` (carte), `step.rewardKind` (récompense),
  `step.speaker/scene/npc/rarity` (rencontre).
- `Controller.choose(id)`, `play(main, cible)`, `endTurn()`, `usePotion(emplacement, cible)`,
  `discardPotion(emplacement)`, `finishCombat()`, `abandon()` : tout passe par `Expedition.act`
  (ou `Save.start` / `Save.finish` / `Save.abandon`).
- Après chaque action de combat, `exp.combat.events` est vidé (les événements partent à l'écran pour
  les animations) : la sauvegarde ne grossit pas. Les événements d'ouverture d'un combat ne sont pas
  rejoués. À la déconnexion, le journal du combat en cours est vidé par sécurité.
- Dès que la phase passe à `done`, le contrôleur appelle `Save.finish(db, date())` (journal,
  réputation, clés) : la méta-progression est acquise même si l'on ferme la fenêtre avant le bilan.

### Sauvegarde

Format : celui de `Core/Save.lua` (`docs/expedition.md`), plus un champ `options` propre à l'interface
(`autoOpen, autoClose, scale, speed, fast, decor, minimap = { hide, angle }, facingPlayer, facingEnemy,
point`), que `Save.migrate` garde tel quel (il ne retire jamais un champ inconnu ; testé).

- Chargement (`ADDON_LOADED`) : `SlayTheDragonDB = Save.migrate(SlayTheDragonDB)`, puis options par défaut.
- Expédition illisible pour `Save` : quarantaine par `Save.migrate`. Illisible pour l'interface (bibelot,
  potion, ennemi, intention, article ou rencontre inconnus, combat abîmé) ou erreur Lua à la reprise :
  `Save.quarantine(db, raison)`. Un message le signale à l'accueil et dans la discussion ; rien n'est effacé.
- Sauvegarde d'une version **plus récente** de l'addon : `Save.migrate` n'y touche pas ; l'interface
  joue alors sur une base de session jamais écrite (`Persist.readOnly`, message dans la discussion).

## Art, textures, sons et API

### Confirmé par le MCP « wow »

- **Icônes** (FileDataID, `wow_icon_search`) : toutes celles de `UI/Art.lua` (cartes, états, intentions,
  bibelots, potions, parcours, couchage, grimoire, coffre, mana, or, point d'interrogation 134400), plus
  les chemins des affixes (piste D). Une carte essaie d'abord l'icône de son sort (`C_Spell.GetSpellTexture`),
  puis le FileDataID, puis le point d'interrogation.
- **Textures** (`wow_file_search`, liste de fichiers du client 12.1.5) : disque
  `interface/characterframe/tempportraitalphamask` (130924 : formes rondes et masques), parchemin
  `interface/helpframe/tileable-parchment` (516781), bois `interface/gamepad/woodtile` (7149548), coche
  `interface/raidframe/readycheck-ready` (136814), illustrations
  `interface/glues/loadingscreens/expansion10/main/loadscreen_housing_elwynnforest` (7377860 : route, ferme,
  colline, camp, ruines, marchand, nuit teintée) et `interface/glues/loadingscreens/loadscreendeadmines`
  (131833 : boss, mine). Aucune illustration de côte trouvée : la côte est peinte. Le MCP confirme la liste
  de fichiers **retail 12.1.5**, pas l'installation Forever (il ne trouve aucune installation ici) : si un
  fichier manque, `GetTextureFileID` le signale, l'illustration est masquée (le décor peint reste) et
  `/slay art` le liste (`scene:<id>`).
- **Sons** : noms `SOUNDKIT` employés tels quels par l'interface Blizzard 12.1.5 (`wow_ui_grep`) :
  `IG_ABILITY_PAGE_TURN`, `IG_MAINMENU_OPTION_CHECKBOX_ON`, `IG_SPELLBOOK_OPEN/CLOSE`,
  `LOOT_WINDOW_COIN_SOUND`, `UI_ADVENTURES_*` (combats des Aventures de Shadowlands :
  `DAMAGE_SWEETENER_MEDIUM/LARGE`, `DEFENSIVE_SWEETENER`, `HEAL_FOLLOWER`, `DEATH_ENEMY/FRIENDLY`,
  `ADVENTURE_SUCCESS_COMPLETE`, `ADVENTURE_FAILURE_COMPLETE`, `ADVENTURER_SLOTTED/SELECTED`),
  `UI_GARRISON_MISSION_ENCOUNTER_ANIMATION_GENERIC`, `UI_GARRISON_MISSION_THREAT_COUNTERED`. Joués par
  `PlaySound(SOUNDKIT[nom])` sous `pcall`, ignorés si le nom manque.
- **API** (`wow_api_search`, Forever) : `CreateMaskTexture`, `AddMaskTexture`, `SetGradient`, `SetRotation`
  (texture), `SetVertexOffset`, `SetHorizTile`, `SetModelAlpha`, `SetFont -> success`, `SetShadowColor`,
  `SetShadowOffset`, `SetMaxLines`, `GetStringWidth`, `GetStringHeight`, `PlaySound` ; `CreateColor`
  (Lua de l'interface Blizzard, `Blizzard_SharedXMLBase/Color.lua`, appelé sous garde) ;
  `GameTooltip:NumLines` (employé par l'interface Blizzard). Plus celles de la piste D : `UnitOnTaxi`, les
  événements de vol, `SetPropagateKeyboardInput`, `SetCreature`, `SetDisplayInfo`, `SetUnit`,
  `SetAnimation`, `GetModelFileID`, `SetTexture -> success`, `SetDesaturated`, `CreateLine`,
  `IsMouseOver`, `C_Timer`, `C_Spell.GetSpellTexture`, `InCombatLockdown`, `GetCursorPosition`…
- `wow_lua_lint` (forever) sur tout `UI/` : aucune erreur ; un avertissement attendu sur `CreateColor`
  (fonction Lua de l'interface, pas de l'API C) ; notes « OnUpdate » sur le glisser-déposer, le bouton de
  minimap, le feu et le pilote des interpolations (voulues).

### Non vérifié (à voir en jeu)

- L'**allure** des illustrations recadrées (impossible de les voir hors jeu) : recadrage `crop` et teinte
  `tint` sont dans `Art.scenes`, à corriger après essai ; repli immédiat : `/slay decor`.
- Les identifiants de **créatures** (ennemis : gnoll 117, mystique 453, murloc 126, bandit 116, sorcier 619,
  golem 36, Rhahk'Zor 644, sbire 594, VanCleef 639 + affichage 2029 ; rencontres : Salma Saldean 235,
  Gryan Fortmanteau 234, de mémoire) : le MCP n'indexe pas les créatures. Sans modèle : icône (ennemi) ou
  rien (personnage de rencontre). Les autres `npc` des rencontres n'ont pas d'entrée et n'affichent rien :
  ajouter `Art.npcs.<npc> = { creature = id }` quand un identifiant est connu.
- Les **animations** des modèles (0 attente, 1 mort, 6 à terre, 9 encaisser, 16 frapper, 25 prêt, 53/54
  sorts), l'orientation (`/slay facing`) et le cadrage des modèles dans leur cadre (pieds au sol ?).
- La police **Morpheus** (`Fonts\MORPHEUS.ttf`) et ses accents ; repli sur la police de l'objet.
- Le décalage d'un cadre mis à l'échelle (`SetScale` + `SetPoint` divisé par l'échelle) pour les cartes
  survolées et la récompense : calculé, à confirmer à l'œil.

Aucune fonction protégée, aucun `hooksecurefunc`, aucun hook de méthode de frame, aucune rotation de
frame (seules des textures pivotent), aucun `loadstring`.

## Besoins côté moteur (notés, contournés côté interface)

- `Combat.intentInfo` ne donne que les dégâts : l'interface lit `ns.Enemies[id].moves[intent].actions`
  pour afficher Absorption, soins, états et invocations. Un champ `info.actions` normalisé serait plus sûr.
- Pas de prévisualisation des dégâts d'une carte sur une cible (Force, Armure fracassée, Forme d'ombre) :
  les chiffres en évidence sur les cartes sont ceux du texte, pas ceux du combat en cours.
- Le mana max s'obtient par `Combat.modify(c, "maxMana", Combat.BASE_MANA)` ; un `c.player.maxMana`
  explicite serait plus propre.

## Décisions

- Clé proposée par défaut à l'accueil : la plus haute ouverte pour la classe.
- La réputation est acquise dès la fin de l'expédition (`Save.finish` automatique), le bilan n'est
  qu'un affichage.
- Le bandeau de fin de combat n'est pas sauvegardé : un `/reload` à ce moment reprend sur la
  récompense (ou l'accueil après une défaite).
- Récompense : « Reprendre la route » est toujours possible (la carte est alors abandonnée) ; clic sur une
  carte = prise immédiate (elle file vers le tas du deck).
- Le ramassage du butin est purement visuel : `/reload` sur une récompense le pose à nouveau au sol.
- Le coffre « fermé » n'existe qu'à l'écran (le moteur a déjà tiré son contenu) ; `/reload` le referme.
- Feu de camp : repartir sans rien faire est proposé (le moteur l'accepte). Le couchage affiche « +N PV »,
  même 0 à PV pleins.
- Marchand : plusieurs retraits par visite (règle de `Core/Expedition`), le prix affiché monte.
- Carte de parcours : étapes en colonnes de gauche à droite ; `node.x` du moteur devient la hauteur ;
  infobulle d'une étape = nom de son type (une seule ligne), rien pour une rencontre (« ? »).
- Le journal de combat a été retiré (dégueuli d'informations) ; tout passe par les animations et les
  infobulles.
- Démence cachée à 0 ; pastilles d'état triées par identifiant (stable).
- Fenêtre en strate `HIGH`. L'atterrissage ferme la fenêtre même ouverte à la main (option désactivable).

## Harnais hors jeu

```
lua5.1 Sim/ui_harness.lua [graine] [dossier]   # ou luajit ; doit finir par ALL PASS (181 vérifications, graine 1)
lua5.1 Sim/ui_harness.lua 1 build/snap         # + instantanés SVG des écrans dans build/snap
for f in build/snap/*.svg; do rsvg-convert "$f" -o "${f%.svg}.png"; done
```

Il charge tous les fichiers du TOC avec un faux client (cadres enregistreurs, horloge virtuelle,
événements, infobulle, modèles, sons), refuse les modèles XML et événements inconnus et signale toute
méthode d'API inconnue. Scénario : accueil, options, clé verrouillée ; **expédition complète de l'acte 1
jouée par clics** (combats par le bot heuristique à travers l'interface : clics carte puis cible, touches,
glisser-déposer ; récompenses (coffre ouvert d'abord s'il se présente), amélioration, retrait, achats) ; la file d'animations est
vidée (`H.settle`) avant de vérifier le bandeau de fin ; aller-retour de sauvegarde en combat et sur une
récompense ; bilan, méta, nouvelle expédition à la clé +1 ; potions et bibelots ; marchand ; feu de camp ;
rencontre ; bibelot de classe ; abandon ; vol ; sauvegardes anciennes, abîmées ou futures ; art manquant
et `/slay art`. Graines 1 à 12 : ALL PASS (lua5.1), 1 à 3 sous luajit.

`Sim/ui_render.lua` résout ancres, tailles, échelles, couleurs, disques, rotations et textes des cadres du
faux client et écrit un SVG par écran (accueil, parcours, combat, combat-survol, récompense, marchand, feu
de camp, amélioration, rencontre, bibelot de classe, bilan, méta). Icônes = carrés bleus, modèles =
silhouettes en pointillés, illustrations = aplats ; largeurs de texte estimées. Il a servi à corriger la
mise en page (noms de cartes longs, pastilles trop larges, gemmes de clé) ; il ne remplace pas un essai.

## Tests en vol (pour toi)

Préparation : copier le dossier dans `/mnt/Games/World of Warcraft/_forever_/Interface/AddOns/SlayTheDragon`
(commande `rsync` dans `CLAUDE.md`). **Relancer le client** (nouveau fichier `UI\Scene.lua` dans le TOC).
Activer les erreurs Lua (`/console scriptErrors 1`) ou BugSack.

En priorité (ce que je n'ai pas pu voir) :
1. `/slay` : la fenêtre 1040 × 620 s'ouvre ; formes arrondies, parchemin, bois, police des titres
   (Morpheus) avec les accents. On la déplace par le bandeau ; Options → Échelle.
2. Décor : l'illustration (champs d'Elwynn teintés) a-t-elle du sens derrière les personnages, sans logo
   ni texte ? Sinon `/slay decor` (décor peint) et me dire lequel garder ; Mortemines pour le boss.
3. Combat : ton personnage est-il posé au sol à gauche (pieds sur l'ombre), les ennemis à droite, face à
   face ? `/slay facing` sinon. Bulles d'intention lisibles (icône ronde + chiffre) ; anneau doré à la cible.
4. Cartes : gemme, nom, médaillon rond avec l'icône du sort, ligne de type, texte, pastilles ; carte trop
   chère ternie avec « Pas assez de mana. » ; survol : la carte monte, grossit, passe devant.
5. Retour visuel : carte qui file vers l'ennemi, « -9 » qui saute, vie qui laisse une traînée claire,
   secousse, mort en fondu, intention qui éclate au tour ennemi, cartes qui arrivent du tas, sons.
   Tester la vitesse ×0,5 / ×3 et le mode rapide.
6. Récompense : 3 cartes en grand, bourse / fiole / bibelot au sol ; clic sur la bourse → elle vole vers
   l'or du bandeau ; « Reprendre la route » ramasse le reste. Coffre : il faut d'abord l'ouvrir.
7. Rencontre : bulle, nom du personnage, modèle de Salma Saldean (235) à droite si l'identifiant est bon,
   réponses en plaques avec leur issue ; réponse impossible grisée avec sa raison ; texte après coup.
8. Parcours : symboles, halo doré des étapes accessibles, trait rouge du chemin parcouru, pointillés.
9. Feu de camp (feu qui vacille, couchage « +N PV », grimoire), marchand (étal, prix, retrait), grille
   d'amélioration (survol = version améliorée), accueil, bilan, méta.

Ensuite, la liste habituelle : `/reload` en combat et sur une récompense (même état), potions (boire, à
cible, jeter), touches 1–0 / Tab / Espace / Entrée / Échap (une touche non gérée agit sur le jeu),
ouverture au décollage et fermeture à l'atterrissage, masquage en combat réel, `/slay modeles`.

À me renvoyer : captures de chaque écran (combat avec la main survolée, récompense, rencontre, parcours,
marchand, feu de camp), la sortie de `/slay art`, le choix décor illustré / peint, les valeurs de
`/slay facing` qui conviennent, et toute erreur Lua (texte complet).
