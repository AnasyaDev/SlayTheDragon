# Interface en jeu (pistes C, D, E, survols, peau « Mechanized Magic » des cartes, habillage WoW)

État au 10/11/2026. Premier essai en jeu fait par le joueur (disposition validée) ; les retours de cet
essai sont traités dans « Retours du premier essai » ci-dessous. Depuis, l'habillage « bois et
parchemin » dessiné en code est remplacé par les pièces du pack CC0 « Mechanized Magic » (Dumivid),
d'après les planches validées (`docs/maquette/combat_pack.jpg`, `ecran_*.jpg`, `psd.jpg`) : voir « Peau ».
Vérifié hors jeu par `Sim/ui_harness.lua` (logique, clics, animations en temps virtuel, cohérence de la
peau) et par des instantanés des écrans (`Sim/ui_render.lua`, qui dessine désormais les textures de
`Media/`). La section « Tests en vol » liste ce qu'il reste à voir en jeu.
Le 11/11/2026, l'habillage de la fenêtre et des écrans (hors cartes) est passé aux pièces de l'interface
du jeu : voir « Habillage WoW » ci-dessous ; la peau « Mechanized Magic » ne vêt plus que les cartes.

## Classes (socle multi-classes, 12/11/2026)

Contrat complet : `docs/classes.md`. Ce qui change à l'écran :

- **Accueil** (demande du joueur, 12/11/2026 : « juste l'icône de classe ») : une icône par classe
  jouable (`ns.Classes`, ordre `order`), sans texte, en une rangée centrée et régulière : icône de la
  classe (`Art.class(id)`, celle du portrait de repli : `ClassIcon_*` du pack d'icônes, `Media/Icons`)
  dans le grand anneau doré, 64 unités, pas de 92 (réduits au-delà de cinq classes pour tenir dans
  520 unités). Choisie : halo doré tenu, icône et anneau pleins, son nom seul en or sous son icône ;
  les autres assombries, éclairées au survol (`W.hoverable`, halo créé d'avance). Nom, PV et cartes,
  niveau de classe dans l'infobulle (« Click: play this class. » si elle n'est pas choisie). Un clic choisit
  la classe ; le départ reste le bouton « Start expedition » (Entrée). Harnais : U4, U35 (2, 5, 9 classes).
- **Bandeau, cadre du héros** : nom de la classe jouée. Portrait : visage du personnage (`SetPortraitTexture`)
  si sa classe de jeu (`UnitClass("player")`, champ `wow` de `Art.classes`) est celle de l'expédition,
  sinon l'icône de la classe (Guerrier joué par un prêtre : icône du Guerrier).
- **Pastille de ressource** (anciennement Démence) : petit anneau doré près du mana, icône de la
  ressource de la classe (`Art.classes[id].resource`), nombre, cachée à 0 ; infobulle = explication du
  registre du langage et « n / plafond » ; chiffres flottants « +2 Rage » à la couleur de la ressource.
- **Zone libre de classe** : cadre de 300 × 40 sous les états du héros, rempli par `ns.ClassViews[id]`
  (`build` une fois, `render` à chaque rendu) ; vide pour le Priest et le Warrior.
- **Spend N au choix** (décision du joueur) : clic ou glisser = la carte se joue en dépensant si
  la ressource suffit ; **Maj enfoncée en jouant** = sans dépenser. Le clic droit n'est pas employé : il
  désélectionne partout dans le combat. La ligne « Spend N: » de la carte en main est éteinte (gris)
  quand le bonus ne sera pas payé (ressource insuffisante, ou Maj enfoncée : la main se redessine sur
  `MODIFIER_STATE_CHANGED`) ; l'infobulle d'une carte Spend dit « Shift: play it without spending. ».
- **Langage des cartes** : les mots de la plaque, les conditions nommées (Execute, Surge, Spend N, Last
  Breath, Shadow…), les ressources et les déclencheurs de Power viennent de `Core/Language.lua` ; une
  classe y ajoute les siens sans toucher à `UI/Widgets.lua` (W.CONDITIONS = registre, plaque et
  explications dérivées). « Pay N HP. » en première ligne a son explication.
- **État `pain`** affiché « DoT » ; l'icône d'un DoT peut dépendre de sa source (`Art.statusIcons`,
  saignement du Guerrier).
- Raisons nouvelles : « Not enough HP to pay. », « Not enough Rage. » (ressource de la classe),
  « Not enough HP. » (carte `minHp`).
- **Cartes neutres et bibelots communs** (12/11/2026, `UI/Art/neutral.lua`) : corps ivoire teinté vert
  sauge (`Art.cardBodyTint`, couleur de sommet multipliée par l'assombrissement d'une carte injouable),
  mot-clé « Neutral » en infobulle ; bandeau : 3 cases de potion, 4 avec Herb Pouch (calées à droite,
  séparateur et bibelots décalés, `UI.refreshInfo`). Harnais : section UN, planche `cartes_neutres.svg`.

## Progression par classe (12/11/2026)

- **Accès** : le bouton rouge de l'accueil (bas gauche, ex-« Reputation and log ») devient « Progress » et
  ouvre l'écran de progression de la classe choisie ; le bilan y mène aussi (classe de l'expédition finie).
  L'écran porte « Reputation and log » (ancien écran méta : barre de niveau de la classe, Ligue, journal,
  dont « Back » revient à la progression) et « Back ». Un seul bouton de plus en tout.
- **Écran** (`ClassProgress`, étape `classProgress` du contrôleur) : boîte DiamondMetal sur la scène ; en
  haut les icônes de classe de l'accueil (44 unités, la classe affichée au halo d'or ; infobulle = nom et
  « Level N » ; un clic change de classe, option `pclass:<id>`), la barre d'expérience (`W.repBar` :
  libellé = classe, « Level 3 · 20 / 150 »), puis les deux boutons. Dessous, quatre rangées (départ, puis
  les trois voies, nom de la voie à gauche, réduit s'il ne tient pas) de vraies cartes `W.card` à 0,6, dans
  l'ordre de leur niveau, et les 6 bibelots en cases à droite des cartes de départ. Tout tient dans
  1040 × 620 sans défilement (34 cartes, pas de 84, rangées de 122).
- **Débloqué** : la carte telle qu'en jeu, infobulle habituelle, agrandie ×1,65 au survol (levée pour rester
  dans la fenêtre) ; le bibelot dans sa case, infobulle du bibelot. **Verrouillé** : dos de carte du pack
  assombri et désaturé (rien d'autre : ni nom, ni texte, ni icône, ni rareté) ; case de bibelot au point
  d'interrogation grisé, liseré éteint. Infobulle = la condition seule, en rouge (« Priest level 4 »).
- **Bilan** : « +76 Priest experience, +122 reputation (Explorers' League). », « Priest reaches level 2! » ;
  barres niveau de classe et Ligue ; en cas de montée, les cartes et bibelots débloqués révélés sous les
  barres (vraies cartes à 0,5, agrandies au survol ; cases des bibelots), le panneau monte et grandit sans
  toucher aux boutons. Les barres se placent sous le texte (il chevauchait la première barre à 6 lignes).
- **Accueil** : l'infobulle d'une classe dit « Level N » au lieu de la réputation.
- Harnais UP (5 classes aux niveaux 1, 4, 7 : nombre de cartes et bibelots ouverts, silhouettes sans texte
  ni icône, infobulle = condition seule, tout dans la fenêtre, rien de tronqué, carte de la dernière rangée
  survolée dans la fenêtre ; bilan au niveau 2 et au niveau 3 ; accueil). Aperçus :
  `progression-priest-1`, `progression-warrior-4`, `bilan-montee-de-niveau`.
- Non vérifiable hors jeu : rendu du dos de carte désaturé (`SetDesaturated` sur une texture du pack), lisibilité
  des cartes à 0,6 au repos sur l'ardoise, zoom ×1,65 en mode net, nouvelles icônes des bibelots du Priest
  (`Media/Icons`, nouveaux fichiers : relancer le client).

## Habillage WoW (direction B, mana et parcours façon C)

État au 11/11/2026, choisi par le joueur sur maquettes (`build/wowui/direction_*.jpg`, générateurs
`docs/maquette/gen_wowui.py` et `docs/maquette/wowui_kit.py`) : tout l'habillage en **direction B**
(moderne Dragonflight / Midnight) ; l'indicateur de mana et l'écran de parcours repris de la
**direction C** (carte de vol). Les **cartes** (pack « Mechanized Magic ») et la police (Baloo Chettan 2)
ne changent pas (voir « Peau « Mechanized Magic » »). Pas encore vu en jeu.

### Règle : embarqué, jamais d'atlas

Toutes les pièces sont des **textures de Blizzard extraites du jeu** (CASC retail 12.1.5, téléchargées par
FileDataID depuis `https://wago.tools/api/casc/<id>?download`), découpées et **livrées avec l'addon**
(`Media/WowUI/*.tga`). L'interface ne les appelle **jamais** par `SetAtlas`, par un chemin `Interface\…`
du client ni par un FileDataID : sur WoW Forever, une texture absente s'affiche en aplat vert et rien ne
permet de le savoir. Restent des fichiers du client, comme avant : les icônes (mécanisme actuel : icône
améliorée de `Media/Icons`, sinon icône du sort ou FileDataID), la texture blanche `WHITE8X8` (aplats,
dégradés), le bouton de minicarte (hors de la fenêtre) et, en repli seulement, les écrans de chargement
candidats du décor. Le disque des ronds teintés (`W.disc`) est maintenant `Media/mask_disc.tga`.
**À réévaluer avant toute publication de l'addon** (droits de Blizzard, comme les fonds des scènes).

### Fabrication (`tools/build_wowui.py`, hors TOC, rejouable)

```
build/venv/bin/python -I tools/build_wowui.py [planche] [doc]
```

- Liste des sources en tête du script (FileDataID → fichier du client), retéléchargées si absentes dans
  `build/wowui_src/` (User-Agent générique ; BLP lus par Pillow, encodage 3 décodé à la main).
- Découpes : coordonnées d'atlas (table UiTextureAtlasMember, build 12.1.5) **vérifiées à l'œil** sur
  les fichiers servis (planche `build/wowui_planche.png`, assemblages `build/wowui_assemblages.png`).
  Plusieurs feuilles ne correspondent plus à l'atlas connu : cadre d'unité compact et barres de la feuille
  des boss (4703662), cadre doré des cases (4615764), barre de mana du joueur (4642466) — rectangles
  mesurés à la main ou resserrés sur l'alpha. Retouches : cadre compact ordinaire = moitié gauche du cadre
  de boss et son miroir (le fichier servi n'a que la version au dragon) ; grand anneau doré isolé du coin
  « PortraitMetal » (anneau masqué, restes gris du cadre effacés) ; bouton rouge et or = bouts gauche et
  droit accolés ; trait de taxi couché.
- Sorties : `Media/WowUI/atlas.tga` (1024 × 512, 42 pièces, 3 pixels d'écart aux bords répétés) et 13
  fichiers répétés (bords du cadre métal et des dialogues, roche 256, table 256, parchemins), TGA 32 bits
  non compressés, origine en bas à gauche, toiles en puissances de deux (même écriture que
  `tools/build_media.py`) ; `UI/WowSkin.lua` (GÉNÉRÉ : par pièce, fichier, toile, taille stockée,
  coordonnées de texture, bouts des trois tranches, axe répété ou étiré, FileDataID ; mesures des filets et
  logements dans `meta`) ; aperçus `build/media_png/WowUI/*.png` (rendu hors jeu) ; `doc` : la table
  ci-dessous.
- Poids : `Media/WowUI` = 3,98 Mo ; l'ancienne peau en a rendu 1,3 Mo (17 textures retirées : hexagones,
  ardoise et ivoire en neuf tranches, liseré, pilule dorée, pointes de bulle, petit anneau, carré arrondi ;
  `tools/build_media.py` ne les fabrique plus ; icône de classe ajoutée, 64 Ko). `Media/` = 23,3 Mo avant,
  26,0 Mo après.
- Netteté : à l'échelle 115 % d'un écran où une unité vaut un pixel, une pièce reste nette affichée à au
  plus (pixels stockés ÷ 1,15) unités. Les pièces -2x sont stockées à 0,5 (dialogues), 0,75 (cadres
  d'unité, barres, cases) ou 1 (cadre de la fenêtre, anneaux) selon leur taille d'affichage ; le harnais
  (U30) vérifie qu'aucune pièce entière n'est agrandie au-delà. Exceptions voulues : milieux étirés des
  trois tranches, du rail de curseur, des barres et des parchemins (dégradés sans détail).

| Pièce | FileDataID | Stockée (px) | Usage |
|---|---|---|---|
| `arrow_l` | 4567914 | 11×19 | flèche gauche (Minimal_SliderBar_Button_Left) |
| `arrow_r` | 4567914 | 9×18 | flèche droite (Minimal_SliderBar_Button_Right) |
| `bar_absorb` | 4642466 | 180×14 | barre d'Absorption (…-Bar-Mana-2x, mesurée à la main) |
| `bar_enemy` | 4703662 | 127×15 | barre de vie compacte (…-Boss-Small-PortraitOff-Bar-Health-2x) |
| `bar_hp` | 4642466 | 186×30 | barre de vie (…-Player-PortraitOn-Bar-Health-2x) |
| `bar_yellow` | 4703662 | 127×11 | barre jaune : incantation, réputation (…-Boss-Small-PortraitOff-Bar-Energy-2x) |
| `boot` | 1455734 | 72×73 | botte ailée : position (taxi_frame_yellow) |
| `btn_close` | 4698972 | 34×37 | bouton de fermeture (RedButton-Exit-2x) |
| `btn_goldred` | 3856481 | 203×64 | bouton rouge et or (128-GoldRedButton-Left + Right) |
| `btn_red` | 6794983 | 233×62 | bouton rouge (128-RedButton-Up, 9-sliced) |
| `check_box` | 4614134 | 28×27 | case à cocher (checkbox-minimal) |
| `check_mark` | 4614134 | 22×19 | coche (checkbox-minimal, coche jaune) |
| `diamond_bl` | 3056750 | 64×64 | boîte de dialogue (UI-Frame-DiamondMetal-Corner*-2x) |
| `diamond_bottom` | 3056750 | 64×64 (répétée) | bord bas (_UI-Frame-DiamondMetal-EdgeBottom-2x) |
| `diamond_br` | 3056750 | 64×64 | boîte de dialogue (UI-Frame-DiamondMetal-Corner*-2x) |
| `diamond_left` | 3056755 | 64×64 (répétée) | bord gauche (!UI-Frame-DiamondMetal-EdgeLeft-2x) |
| `diamond_right` | 3056755 | 64×64 (répétée) | bord droit (!UI-Frame-DiamondMetal-EdgeRight-2x) |
| `diamond_tl` | 3056750 | 64×64 | boîte de dialogue (UI-Frame-DiamondMetal-Corner*-2x) |
| `diamond_top` | 3056750 | 64×64 (répétée) | bord haut (_UI-Frame-DiamondMetal-EdgeTop-2x) |
| `diamond_tr` | 3056750 | 64×64 | boîte de dialogue (UI-Frame-DiamondMetal-Corner*-2x) |
| `elite_dragon` | 1300837 | 80×80 | dragon d'or des élites et boss (nameplates-icon-elite-gold) |
| `elite_node` | 1121272 | 62×62 | étape d'élite (VignetteKillElite) |
| `header_l` | 3058483 | 64×78 | en-tête de titre (UI-Frame-DiamondMetal-Header-CornerLeft-2x) |
| `header_m` | 3058483 | 64×78 (répétée) | en-tête de titre (_UI-Frame-DiamondMetal-Header-Tile-2x) |
| `header_r` | 3058483 | 64×78 | en-tête de titre (UI-Frame-DiamondMetal-Header-CornerRight-2x) |
| `metal_bl` | 2406979 | 64×64 | cadre de la fenêtre (UI-Frame-Metal-Corner*-2x) |
| `metal_bottom` | 2406987 | 32×64 (répétée) | bord bas, filet du plateau (_UI-Frame-Metal-EdgeBottom-2x) |
| `metal_br` | 2406979 | 64×64 | cadre de la fenêtre (UI-Frame-Metal-Corner*-2x) |
| `metal_left` | 2406984 | 150×32 (répétée) | bord gauche (!UI-Frame-Metal-EdgeLeft-2x) |
| `metal_right` | 2406984 | 150×32 (répétée) | bord droit (!UI-Frame-Metal-EdgeRight-2x) |
| `metal_tl` | 2406979 | 150×150 | cadre de la fenêtre (UI-Frame-Metal-Corner*-2x) |
| `metal_top` | 2406987 | 64×150 (répétée) | barre de titre (_UI-Frame-Metal-EdgeTop-2x) |
| `metal_tr` | 2406979 | 150×150 | cadre de la fenêtre (UI-Frame-Metal-Corner*-2x) |
| `parch_map` | 2142239 | 512×435 | parchemin du parcours (UI-Frame-Neutral-CardParchmentWider) |
| `parch_text` | 4699152 | 256×218 | parchemin des textes (UI-Frame-DragonFlight-CardParchmentWider) |
| `pip_gray` | 137032 | 16×16 | pastille de progression (ui-taxi-icon-gray) |
| `pip_green` | 137033 | 16×16 | pastille de progression (ui-taxi-icon-green) |
| `pip_red` | 137035 | 16×16 | pastille de progression (ui-taxi-icon-red) |
| `pip_yellow` | 137037 | 16×16 | pastille de progression (ui-taxi-icon-yellow) |
| `ribbon` | 2142239 | 281×84 | ruban du nom du boss (UI-Frame-Neutral-Ribbon) |
| `ring_large` | 2406979 | 126×124 | grand anneau doré : mana, objets ronds, boss (anneau de UI-Frame-PortraitMetal-CornerTopLeft-2x, isolé) |
| `ring_small` | 4691255 | 59×60 | petit anneau doré : étapes du parcours, Démence (bag-border-2x) |
| `rock` | 374155 | 256×256 (répétée) | fond des fenêtres (UI-Background-Rock), réduit à 256 |
| `slider_l` | 4567914 | 11×17 | curseur, bout gauche (Minimal_SliderBar_Left) |
| `slider_m` | 4567914 | 1×17 | curseur, milieu (_Minimal_SliderBar_Middle) |
| `slider_r` | 4567914 | 11×17 | curseur, bout droit (Minimal_SliderBar_Right) |
| `slider_thumb` | 4567914 | 20×19 | poignée (Minimal_SliderBar_Button) |
| `slot_bg` | 4615764 | 96×93 | fond de case (UI-HUD-ActionBar-IconFrame-Slot-2x) |
| `slot_frame` | 4615764 | 69×68 | cadre de case (UI-HUD-ActionBar-IconFrame-2x) |
| `slot_hover` | 4615764 | 68×68 | cadre doré de survol (UI-HUD-ActionBar-IconFrame-Mouseover-2x, mesuré) |
| `table` | 4699279 | 256×256 (répétée) | table du bas (UI-Frame-DragonFlight-BackgroundTile) |
| `taxi_line` | 1455735 | 32×32 | trait de trajet, couché (!UI-Taxi-Line) |
| `unit_boss` | 4703662 | 172×84 | cadre compact d'élite / boss, dragon d'or (…-Boss-Small-PortraitOff-2x) |
| `unit_enemy` | 4703662 | 135×57 | cadre compact d'ennemi (moitié gauche du cadre de boss et son miroir, sans le dragon) |
| `unit_player` | 4642466 | 297×106 | cadre du héros (UI-HUD-UnitFrame-Player-PortraitOn-2x) |

### Briques (`UI/Widgets.lua`)

- `W.setWow` / `W.wow` / `W.wowSize` (pièce de `UI/WowSkin.lua`), `W.tileTo` (coordonnées répétées, période
  = pièce × k), `W.fillTile` (matière répétée qui suit la taille de l'hôte), `W.frameSlices` (cadre à pièces
  séparées : coins de l'atlas, bords répétés, débords réglables, rangée du haut sur un autre porteur),
  `W.threeSlice` (bouts à l'échelle de la hauteur), `W.nineStretch` (parchemins), `W.hoverLayer` (calque de
  survol, contrôlé comme un halo par U23). Échelles : `W.K_METAL` = 0,87, `W.K_DIAMOND` = 0,5.
- `W.dialog(parent, titre)` : boîte DiamondMetal (filet sur le bord du cadre, fond roche, en-tête du titre
  en or, `SetTitle`) — options, accueil, grille du deck, panneau des cartes, bilan et méta, fin de combat,
  galerie des modèles. `W.parchment(parent[, "map"])` : parchemin Dragonflight (textes) ou Neutral (parcours).
- `W.button` : bouton rouge (128-RedButton) ou, style `"gold"`, rouge et or (128-GoldRedButton, action
  principale) ; libellé doré (NORMAL_FONT_COLOR) ; survol : s'éclaircit, le liseré d'or apparaît en fondu
  (bouton rouge et or par-dessus) ; `SetSelected` tient le liseré (classe choisie). `W.roundButton("×")` /
  `W.closeButton` : bouton de fermeture rouge ; autre glyphe : petit bouton rouge (pages de la grille).
- `W.check` (checkbox-minimal, coche jaune), `W.slider` (Minimal_SliderBar : rail, poignée, flèches = un
  cran, clic ou glisser sur le rail), `W.slotOn` (case de barre d'action : fond, icône, cadre, cadre doré au
  survol ; cadre teint à la qualité d'un bibelot), `W.iconButton` (case, ou icône dans le grand anneau),
  `W.medallion` (grand anneau doré), `W.tokenRow` (auras : icône dans le cadre de case, rouge pour un
  affaiblissement, nombre en bas à droite), `W.hpBar` (barre du jeu rognée à la fraction, portion perdue
  claire, « PV / max »), `W.shieldBadge` (Absorption : barre bleue dans le logement bas du cadre d'unité,
  fraction des PV max, nombre), `W.repBar` (barre jaune assombrie dans un rail).
- Inchangés : survols (`W.hoverable`, modes de zoom, aucun cadre enfant dessiné dans un visuel — les cadres
  d'ancrage des boutons de réponse et de leurs cases ne portent aucune région), halos créés d'avance,
  infobulles (`GameTooltip`, bordure du jeu), `W.fitText` (descend maintenant jusqu'à ce que ça tienne).
  `W.plaque` ne sert plus qu'aux plaques posées sous une carte (raison d'un refus, prix).

### Écrans

- **Fenêtre** : fond roche ; cadre métal (UI-Frame-Metal) à k = 0,87 : filets gauche, droit et bas sur le
  bord de la fenêtre, par-dessus tout le contenu ; barre de titre (y 0–34) sous les éléments du bandeau.
  Contenu rentré de 2,5 (gauche, haut) et 3,5 (droite, bas) dans la fenêtre : ses bords tombent sur la partie
  opaque des filets et ses coins dans la silhouette des coins biseautés ; le fond de roche a son rectangle
  (voir « Ordre de dessin et silhouette »).
  Le décor commence maintenant à y 34 (`Scene.TOP`, 380 → 390 de haut ; les positions des écrans, en
  coordonnées absolues, ne bougent pas). Table du bas : pierre Dragonflight répétée, filet du cadre métal
  en séparation.
- **Bandeau** (barre de titre) : classe, « HP 52/65 », pièce et or, deck (dos de carte et nombre) ; au
  centre la zone puis, sur la même ligne, les pastilles de la carte de vol (franchies vertes, en cours
  jaune, à venir grises, boss rouge) — nom tronqué à la place laissée ; à droite clé (case à l'icône de la
  clé, « +N »), bibelots et fioles en cases de barre d'action (25), bouton rouge « Menu » (ouvre les
  options, comme ≡), bouton de fermeture rouge.
- **Combat** : cadre d'unité du héros en haut à gauche (UI-HUD-UnitFrame-Player : portrait par
  `SetPortraitTexture(…, "player")`, icône de classe en repli ; nom ; vie ; Absorption dans le logement
  bas) ; auras dessous ; incantation à droite du cadre (case du sort, nom, barre jaune dans un rail).
  Ennemis : cadre compact au-dessus de la tête (nom, vie, Absorption dans le logement bas), version d'élite
  et de boss au dragon d'or, largeur réduite à l'écart entre ennemis, jamais sur le bandeau ; intention
  dessous (case à l'icône, chiffres en couleur) ; états sous les pieds. Mana (C) : orbe de mana dans le
  grand anneau doré, « 2/3 », libellé « Mana » ; Démence : petit anneau. Pioche, défausse, consumées :
  cases (livre, bourse, flamme) avec nombre et libellé doré. Recharges : cases à l'icône grisée et tours.
  « End Turn » rouge et or ; fin de combat : boîte de dialogue.
- **Parcours** (C, dans la fenêtre au cadre B) : parchemin Neutral ; étapes en icônes rondes dans le petit
  anneau doré (élites : vignette d'élite), accessibles en couleur avec une lueur, franchies grisées, hors de
  portée grisées et estompées ; position : botte ailée au-dessus de l'étape ; boss : portrait dans le grand
  anneau, dragon d'or, ruban à son nom ; traits de trajet de taxi (parcouru et départs possibles pleins, le
  reste estompé).
- **Rencontre** (B) : texte sur parchemin Dragonflight, à l'encre (titre or sombre pour une rencontre rare,
  violet sombre pour une histoire), sans pointe ; nom du personnage en or ; réponses en gros boutons rouges,
  icône de l'objet dans une case à gauche du libellé, et **sous le bouton ce que la réponse donne ou coûte**
  (vert pour un gain « + », rouge pour une perte « - » ou la raison d'un refus, blanc sinon).
- **Options** : boîte DiamondMetal « Options », bouton de fermeture, cases à cocher et curseurs (échelle,
  vitesse ; flèches = un cran), boutons rouges.
- **Autres écrans** (mêmes briques) : récompense (texte après coup sur parchemin, butin en cases, coffre
  dans le grand anneau), marchand (cases, étiquettes de prix dans un rail sombre, service en bouton rouge à
  case), feu de camp (couchage et grimoire dans le grand anneau, réponses en boutons), grille du deck,
  panneau des cartes, accueil (classes en icônes dans le grand anneau, la choisie au halo d'or ; clés en cases), bilan
  et méta (dialogues, barres de réputation). Messages passagers : texte rouge des erreurs du jeu sur un
  voile sombre léger.

### Écarts aux maquettes (et pourquoi)

- **Bandeau** : la classe et les PV restent dans le bandeau (la maquette B les ôte hors combat : on les
  perdrait sur le parcours et les rencontres) ; bibelots et fioles dans le bandeau plutôt que sous lui, dans
  le décor. « Menu » ouvre les options existantes : pas de « Game Menu » (Reprendre, Comment jouer, durée
  du vol…) ni d'option nouvelle — aucune information ajoutée. Pastilles : celles de la carte de vol (C) au
  lieu des gemmes d'essence de la maquette B (qui se ressemblaient toutes).
- **Combat** : pas de barre de mana dans le cadre du héros (le mana est l'anneau C) : son logement porte
  l'Absorption ; les auras des ennemis restent sous leurs pieds ; libellés « Draw », « Discard »,
  « Exhaust » sous les cases (comme la maquette ; le tas des consumées n'existe que s'il y en a).
- **Parcours** : pas de légende « Flight path : … 3 of 9 stops » (information nouvelle) ; traits plus fins
  que la maquette C (trait de taxi 1x, pas agrandi : netteté) ; lueur dorée sous les étapes accessibles.
- **Rencontre** : pas de pointe de bulle (B) ; couleur du titre au lieu du liseré pour la rareté.
- **Infobulles** : celles du jeu (`GameTooltip`), inchangées ; la maquette C (parchemin) n'est pas reprise.

### Ordre de dessin et silhouette (retours du 11/11/2026 en jeu)

- **Bandeau invisible en jeu** (barre de titre vide, l'aperçu les montrait) : le bandeau était un enfant du
  contenu (rogné, `SetClipsChildren`) au niveau contenu + 40, la barre de titre un frère du contenu au niveau
  contenu + 39. Règle retenue (hypothèse cohérente avec la capture, non documentée par Blizzard) : un cadre
  rogneur dessine tout son sous-arbre dans sa propre passe, à **son** niveau ; ses descendants ne se
  comparent qu'entre eux. La barre (contenu + 39) passait donc sur tout le contenu (niveau L), bandeau compris.
- **Solution** : plus rien qui doive passer au-dessus du cadre n'est descendant du contenu. Frères, enfants de
  la fenêtre : contenu (rogné, L) < `frameTop` (L + 300 : barre de titre, puis le **bandeau, son enfant**,
  placé en coordonnées du contenu) < `UI.overlay` (L + 600, rogné au contenu : message passager, butin en vol)
  < `rimHost` (L + 900 : filets gauche, droit, bas). Les écarts tiennent aussi si le client comparait tous les
  niveaux (sous-arbre du contenu < L + 200). Le butin qui vole vers le bandeau (`Reward:Collect`) passe sur
  `UI.overlay` le temps du vol (`W.lift` : parent et niveaux rendus à l'arrivée), toujours ancré à l'écran.
  Le message passager est sur `UI.overlay` : au-dessus des options et du panneau du deck (il passait sous ce
  dernier). Revue des autres cas : options, panneau du deck, fin de combat, aperçu des modèles, cartes en vol,
  textes flottants, halos restent dans le contenu et ne recouvrent ni la barre ni les filets (rien à changer).
- **Coins** : le fond de roche couvrait toute la fenêtre, donc les coins biseautés transparents du cadre
  (jusqu'à 36 u² par coin), et le contenu (rentré de 3) dépassait de 1,4 u² au coin bas droit (biseau plus
  large, ombre portée à droite et en bas). Maintenant : contenu rentré de 2,5 / 3,5, fond = rectangle du
  contenu ; vérifié au pixel (U31 : pièces lues dans `Media/WowUI`, pixels d'alpha < 0,5 reliés au bord
  extérieur = hors silhouette ; aucun pixel du contenu, du fond, du bandeau n'y tombe ; bords du contenu sur
  la partie opaque des filets). Boîtes DiamondMetal (options, deck, fin de combat) et parchemins (parcours,
  rencontre) vérifiés de même : déjà justes (ornements opaques aux coins, rien sous les parchemins).
- **Cases d'icônes** (gros pourtour noir) : l'icône était à 80 % de la case, centrée sur la pièce du cadre
  (ombre portée comprise), et le fond de case (`slot_bg`) à 132 % : sa partie sombre débordait de 2 à 5
  unités hors du cadre. Mesures des pièces : liseré opaque de 4 px, ouverture [4, 62)² du cadre 69 × 68,
  carré visible [0, 66)² ; fond plein sur [7, 89)². Maintenant (`W.slotFit`, toutes les cases : bandeau,
  pioche, défausse, récompense, marchand, bibelots, fioles, états, intentions, incantation, réponses) :
  ouverture centrée sur l'hôte, icône = ouverture, partie pleine du fond = ouverture (son bord adouci sous
  le liseré) ; U31 vérifie sur les pixels l'icône à ±1 unité de l'ouverture et le fond dans le cadre.

### Coutures des pièces en tranches (retour du 12/11/2026 en jeu)

- **Vu** (capture, zoom net, fenêtre à 115 %, bouton de classe survolé) : deux traits verticaux qui
  traversent le bouton aux jonctions bouts / milieu. Mesuré sur la capture : un **jour de 3 pixels** où le
  fond se voit (ombre du bouton comprise, d'où le trait qui dépasse en haut et en bas), aux deux
  jonctions, sur le bouton rouge ET le liseré d'or par-dessus.
- **Établi** : ce n'est ni un arrondi ni le filtrage. Les trois tranches étaient ancrées bord à bord sur
  les mêmes points (mêmes expressions), sans accrochage au pixel ; une jonction fractionnaire ou un texel
  voisin donnent au plus un pixel de liseré, pas 3 pixels de vide ; l'intérieur de la pièce est continu.
- **Hypothèse** (non vérifiable hors jeu) : l'animation `Scale` du visuel transforme ses régions une à une
  (autour de leur propre centre, ou une partie seulement) plutôt que le visuel d'un bloc ; pendant la
  réduction (sortie du survol en mode net : facteur 1 → 1 / échelle), les tranches s'écartent
  (jour ≈ (1 − facteur) × (largeur − bout) / 2, soit 3 à 4 pixels sur ce bouton). Cohérent avec la capture
  d'avant (ruban et plaque des cartes qui ne suivaient pas l'animation).
- **Correction, indépendante de cette hypothèse** : chaque pièce en tranches est **une seule texture
  découpée par le client** (`SetTextureSliceMargins` + `SetTextureSliceMode(Stretched)`, présents sur WoW
  Forever d'après le MCP ; « préféré aux neuf textures séparées ») : boutons rouges, rouge et or, liseré
  de survol, plaques de réponse, bouton « < » / « > », cadre compact d'ennemi (`W.threeSlice`),
  parchemins (`W.nineStretch`), plaque du bas des cartes. Plus aucune jointure entre régions, ni au repos
  ni pendant l'animation, à toute échelle. Marges en pixels de la texture ; pour qu'un pixel de marge
  vaille d unités (d = hauteur / hauteur de la pièce pour un trois tranches), la texture prend l'**échelle
  propre d** (`Region:SetScale`) et couvre son hôte par deux points sans décalage (`W.sliceFit` ; plaque des
  cartes : région d'ancrage sans texture). Repli sans l'API (`W.CLIENT_SLICE = false` ou autre client) :
  tranches séparées bord à bord, comme avant.
- **Gardes de l'atlas** (trouvé en vérifiant) : `tools/build_wowui.py` répétait les colonnes gauche et
  droite AVANT d'avoir posé la pièce : gardes latérales noires sous l'alpha du bord (2 514 pixels, 30
  pièces : barres, cases, en-têtes, cadre compact…), liseré sombre possible au filtrage sur les bords
  gauche et droit. Script corrigé ; `Media/WowUI/atlas.tga` réparé en place (gardes recopiées du bord,
  rien d'autre ne change). Harnais UB : gardes de 2 pixels au moins, bord répété, aucune voisine.
- Restent les coins à pièces séparées (cadre métal de la fenêtre, boîtes DiamondMetal, en-tête, rail du
  curseur, plaques d'ardoise des cartes) : fichiers différents, hors des visuels animés, bord à bord.

### Non vérifiable hors jeu (à voir)

- Découpe par le client (`SetTextureSliceMargins` sur une pièce de l'atlas posée par `SetTexCoord`, région
  à échelle propre) : bouts des boutons à la même taille qu'avant (hauteur × 24 / 62), coins des
  parchemins inchangés, plus aucun trait aux jonctions pendant les survols. Si les bouts paraissent trop
  larges ou trop étroits, le client ne suit pas l'échelle propre de la région pour les marges : repli en
  posant `W.CLIENT_SLICE = false` (tranches séparées).

- Règle de dessin des cadres rogneurs (ci-dessus) : bandeau, pastilles, cases, Menu et fermeture visibles
  sur la barre de titre ; butin qui vole jusqu'au bandeau par-dessus la barre ; message passager devant les
  options.

- Chargement des TGA de `Media/WowUI` (aplat vert = fichier absent ou mal lu) ; nouveau fichier du TOC
  `UI\WowSkin.lua` : **relancer le client**.
- Répétition des bords (`SetTexture(…, "REPEAT", "REPEAT")` + coordonnées > 1) sans couture ; neuf tranches
  du parchemin sans ligne aux limites (le rendu hors jeu en montre, artefact de l'aperçu SVG).
- Rotation des traits de taxi (`Texture:SetRotation`, quad pivoté autour de son centre).
- `SetPortraitTexture(texture, "player")` dans le cadre du héros (rond, sans débord de l'anneau).
- Filtrage de l'atlas (`TRILINEAR`) : aucun liseré d'une pièce voisine aux bords des tranches.
- Contraste des textes : or sur métal, encre sur parchemin, blanc sur les barres (vie verte, réputation).

## Peau « Mechanized Magic » (cartes)

### Fabrication des textures (`tools/build_media.py`, hors TOC, rejouable)

```
python3 -m venv build/venv && build/venv/bin/pip install pillow fonttools numpy
build/venv/bin/python tools/build_media.py   # options : --psd, --icons, --font
```

- **PSD** (`~/Téléchargements/1_Free Pack/PSD Card Constructor.psd`, lecture seule) piloté par
  `photocraft-cli run` : chaque pièce est rendue **seule** (tous les calques masqués sauf elle, ses
  ancêtres et ses descendants à leur visibilité d'origine), matière « métal 1 » (calque 296) pour les
  pièces de carte, puis rognée, mise à l'échelle et posée en haut à gauche d'une toile en puissances de
  deux. Rendus mis en cache dans `build/media_cache` (clé = commandes envoyées). Identifiants : corps 226
  + couleur 229 (`layer.fill.solidColor.set`), ruban 246, coût 244, panneau 242, plaque du bas 224,
  anneau 235, verre 239 (opacité 0,66 cuite), ouverture du médaillon = calque 237 rempli de blanc,
  gemmes 276 / 274 / 272 / 266, hexagones 232 (rouge et vert ; bleu, acier, violet, vide reteints comme
  dans `gen_combat_pack.py`), dos 222 (cristal 197, sans l'emblème 215).
- **Dessinées par le script** (même vocabulaire que les planches) : ardoise (intérieur du panneau de
  texte, aplatie puis rendue raccordable par fondu avec sa copie décalée : pas de symétrie visible), pilule
  d'ardoise et son liseré d'argent (plaques posées sous une carte : raison d'un refus, prix), lueurs (halo
  de carte = silhouette du corps floutée, halo rond, halo de plaque), masque rond. Depuis l'habillage WoW,
  le script ne fabrique plus les hexagones, l'ivoire, les neuf tranches d'ardoise et leur liseré, la pilule
  dorée, les pointes de bulle, le petit anneau ni le carré arrondi (il les efface de `Media/` s'il les
  trouve) ; les pièces des cartes sont identiques au bit près.
- **Police** : instances statiques de Baloo Chettan 2 (wght 500 / 700 / 800, `fontTools.varLib.instancer`),
  réduites au latin (accents, « ’ », « « » », « … », « × », « − » vérifiés par le script).
- **Icônes** : seules celles que nomme `UI/Art.lua` (champ `tga = "Nom"`, 81 aujourd'hui), copiées de
  `~/Téléchargements/ICONS` (déjà en TGA 32 bits 128 px). Une icône introuvable est signalée par le
  script et l'interface garde l'icône du jeu.
- **Sorties** : `Media/*.tga`, `Media/Icons/*.tga`, `Media/Fonts/*.ttf`, `UI/SkinData.lua` (fichier GÉNÉRÉ :
  nom → fichier, toile, zone utile, coordonnées de texture, coin et liseré des neuf tranches, géométrie
  de la carte en fractions de la largeur du corps, centre et longueur utile du nom), aperçus PNG dans
  `build/media_png` ; `Sim/baloo_metrics.lua` (GÉNÉRÉ : avances des glyphes des trois graisses et hauteur
  de ligne, pour le faux client du harnais).

**Format** : TGA 32 bits non compressé, origine en bas à gauche, 8 bits d'alpha (le format des icônes
améliorées et des addons ; BLP impossible à produire ici), toiles en puissances de deux (requis pour la
répétition des matières), couleur des pixels transparents « saignée » depuis les voisins (pas de liseré
sombre au filtrage). **Tailles** : corps de carte 372 × 512 dans 512² (une carte de 124 unités vaut
~232 px à 1440p, ~320 px agrandie ×1,37 : nette au survol), ruban 512 × 166, panneau 256 × 185, coût
256 × 124, anneau 243 × 256 (et 61 × 64 pour les jetons), hexagones 128 (mana 256), gemmes 64, matières
256 (répétées tous les 128 unités pour l'ardoise, 420 pour l'ivoire). `Media/` = 13,8 Mo (textures
8,4 Mo dont 4 Mo pour les quatre corps, icônes 5,2 Mo, polices 0,15 Mo).

### Briques (`UI/Widgets.lua`)

- `W.setSkin` / `W.skin` (texture de `Media/`, zone utile), `W.nine` (neuf tranches faites main : neuf
  textures ancrées, coins de N unités, suivent la taille de l'hôte), `W.plaque` (pilule d'ardoise au
  liseré d'argent, seulement sous les cartes ; `SetFill`, `SetRim`, `SetGlow`), `W.cardBack`. Les autres
  briques sont celles de l'habillage WoW (voir plus haut). Polices : `W.label(parent, "body" | "bold" | "heavy", …)`,
  blanc à ombre portée par défaut, repli Friz Quadrata si la police ne se charge pas ; préchargement des
  trois polices au chargement (cadre à l'écran, presque transparent) et `W.refreshFonts` à l'ouverture
  (police et texte reposés partout, voir « Texte des cartes et zoom »).
- **Carte** (`W.card`) : halo, plaque du bas (mots-clés : Pouvoir, Incantation, Recharge N, Consumée,
  Conservée), corps à la couleur de la carte (`Art.cardBody` : violet = Ombre, bleu = protection
  — Absorption ou Suppression d'abord —, or = cartes de départ, ivoire = le reste), médaillon (anneau,
  icône masquée par l'ouverture exacte du PSD, verre), panneau de texte (centré dans la zone utile,
  taille par paliers, chiffres blancs — verts s'ils changent à l'amélioration ; une chaîne WoW ne mêle pas deux
  graisses, d'où la couleur au lieu du gras), languette de coût, ruban du nom, gemme de rareté (aucune =
  base ou commune, triangle vert, losange bleu, pentagone violet, carré orange). Injouable : pièces
  désaturées et assombries, raison dans une plaque rouge au bas de la carte. Prix : pastille (pièce +
  nombre, rouge si trop cher) sous la carte.
- **Ruban horizontal** : redessiné à plat dans le PSD par le joueur (calque 246) ; une seule pièce
  `card_ribbon`, nom horizontal (plus de `SetRotation`, plus de ruban « redressé » ni de `/slay ruban` ;
  l'ancienne option `flatRibbon` d'une sauvegarde est effacée sans erreur). Le script place le nom à
  l'aplomb du centre du corps, à la hauteur du calque de texte « Name » (280), et mesure sa longueur
  utile : la largeur, symétrique autour du centre, où la bande couvre toute la hauteur de ce calque
  (0,735 de la largeur du corps).

### Écrans et écarts aux planches (avant l'habillage WoW)

La description des écrans en ardoise et hexagones (bandeau d'ardoise, hexagones de PV, de mana, de
Démence et des clés, bulles ivoire, plaques de réponse d'ardoise, médaillons argentés du parcours) est
remplacée par « Habillage WoW » ; restent valables : la main remonte de 10 (plaque du bas dans la
fenêtre), grilles et panneau du deck à ×0,75 / ×0,72 aux rangées espacées, couleur (et non gras) des
valeurs, bouton « Back on the road » du feu de camp.

## Texte des cartes et zoom (retours du deuxième essai)

- **Zone utile du texte** (`W.CARD_TEXT`, `UI/Widgets.lua`) : intérieur sombre du panneau d'ardoise
  (mesuré sur `Media/card_panel.tga`) moins les marges : 5,5 unités sur les côtés (de 124), 5 unités au
  bas, et sous la plus grande gemme de rareté en haut ; le bas biseauté rétrécit la zone (demi-largeur
  0,308 − 0,56 × (y − 1,0754), marge ×1,15 en biais). Les lignes sont posées une à une : remplissage
  glouton, chaque ligne limitée à la largeur de la zone à son bas, bloc centré verticalement ; puis le
  texte est posé avec des retours explicites dans une **boîte posée** (`W.looseBox`, voir « Textes
  tronqués au survol » plus bas). Mesures par le client : `GetStringWidth` / `GetStringHeight` d'un texte
  de mesure (même police), avec une marge `W.TEXT_SAFE` (une ligne mesurée × 1,02 doit tenir dans sa
  largeur), puis vérification sur la carte (`GetNumLines`, `IsTruncated`, `GetStringHeight`) — un échec
  fait descendre d'un palier. Mises en page gardées en cache (texte, taille, bas de zone).
- **Textes tronqués au survol** (retour en jeu du 12/11/2026, fenêtre à 115 %, zoom net) : « PW: Radiance »
  survolée en main affichait « Gain 4 Absorb.... » sur une ligne au lieu de ses deux lignes
  (« Gain 4 Absorb. » / « Gain Atonement 1 ⌛ »). **Établi** : c'est la troncature verticale du client (la
  première ligne entière, suivie de « … », la seconde absente : une ligne trop large aurait été coupée en
  son milieu ou recoupée en une ligne de plus) ; le texte avait une largeur posée mais une hauteur
  **automatique** (aucune `SetHeight`), et le harnais, dont le faux client ne bornait jamais une hauteur
  automatique, ne pouvait pas le voir. **Hypothèse** (non vérifiable hors jeu, aucun code de Blizzard
  n'emploie `SetSmoothScaling`) : à l'échelle survolée, la hauteur automatique est calculée avec la police
  arrondie au pixel le plus proche, le rendu avec une hauteur plus grande (`SetSmoothScaling` : non
  arrondie, ou arrondie au-dessus) ; 10 × 1,15 × 1,16 = 13,34 px → boîte pour 13 px, lignes de 13,34 px
  ou plus : deux lignes n'y tiennent plus. Au repos (10 × 1,15 = 11,5 px → 12 px) la boîte suffisait.
  **Correction** : tout texte dont nos mises en page choisissent les lignes est posé dans une boîte de
  taille posée, largeur = zone × 1,3 + 8, hauteur = lignes × hauteur de ligne × 1,3 + 8, `SetMaxLines(0)`
  (`W.looseBox`, `W.TEXT_ROOM`, `W.TEXT_PAD`), centrée sur le bloc (ancrage par le centre et `JustifyV`
  « MIDDLE », ou par le haut et « TOP » pour le texte sous les plaques de réponse) : le client n'a plus
  jamais à recouper ni tronquer, à aucune échelle, et rien ne bouge (le texte reste centré au même point).
  Concernés : texte, nom (ruban), plaque du bas et raison des cartes ; libellé et texte des plaques de
  réponse (`setLines` de `UI/Screens.lua`). Les textes d'une ligne à largeur libre (libellés de boutons,
  coût, prix) ne sont jamais tronqués (vérifié, U33). Marge `W.TEXT_SAFE` (1,02) dans le choix des paliers :
  15 cartes perdent un demi-palier (texte ou nom ; Schisme 8 → 7,5, Évangélisation 8,5 → 8…).
  **Garde-fou en jeu** (`W.checkCardTexts`) : une image après la pose d'une carte et après chaque survol
  (`onAnimSettled`, donc après la bascule du zoom), un texte que le client tronque malgré tout
  (`IsTruncated`) fait descendre son palier (texte ou nom, `card.textCap`, propre à la carte) et reposer la
  carte ; tout texte tronqué est relevé (40 derniers) : **`/slay text`** les liste (avec taille, échelle
  effective et mode de zoom), ainsi que les textes visibles tronqués en ce moment ; `/slay art` en donne le
  nombre. **Harnais U33** : faux client défavorable (`H.strictText` : police rendue arrondie au pixel
  supérieur à l'échelle effective, hauteur automatique au plus proche) ; toutes les cartes base et
  améliorées, jouables et injouables, fenêtre 1 / 1,15 / 1,5 / 0,6, écrans main (×1,16), récompense,
  grille et marchand, posées au repos ou à l'échelle survolée (mode fluide), vues au repos et survolées ;
  « PW: Radiance » en main par le vrai survol dans les trois modes ; toutes les réponses des
  rencontres ; tous les textes des visuels survolables. Sur l'ancien code : 2 127 cas tronqués, dont
  PW: Radiance en net à 1 et 1,15 survolée (« 1/2 lignes »), et 24 réponses.
- **Paliers** (retour du troisième essai : « texte trop petit ») : chaque carte prend le plus grand
  palier qui tient dans la zone utile (inchangée, marges comprises) : texte 10 / 9,5 / 9 / 8,5 / 8 / 7,5 / 7
  (plancher lisible), secours 6,5 / 6 signalé (`card.bodyFit.under`) ; nom 11 / 10 / 9 / 8 / 7, secours
  6,5 / 6 (`card.nameFit`), une ligne dans la bande du ruban moins 4 unités de chaque côté. Coupure : le
  moins de lignes possible, chaque ligne remplie de haut en bas tant que la suite tient dans les lignes
  restantes (le glouton d'avant finissait parfois en moins de lignes que prévu, puis le bloc recentré
  sortait du biseau : Embrasement empyréen restait à 8) ; mots insécables (`W.cardWords`) : « : » avec le
  mot d'avant, un nombre qui finit la phrase (« Pioche 1. ») avec le mot d'avant, un nombre seul avec le
  mot d'après (« 12 Absorption », « +1 Démence »). Répartition depuis le langage en mots-clés (voir
  « Langage des cartes », harnais U22, métriques de Baloo Chettan 2, 68 cartes base et améliorées) :
  depuis la marge `W.TEXT_SAFE` (12/11/2026, texte des cartes en anglais) : texte 10 → 39, 9,5 → 11, 9 → 2,
  8,5 → 5, 8 → 5, 7,5 → 6, soit 57 à 8,5 ou plus (60 avant la marge) ; nom 11 → 54, 10 → 7, 9 → 4, 8 → 3 ;
  plus ancien (textes en français) : texte 10 → 28, 9,5 → 6, 9 → 6, 8,5 → 6, 8 → 19, 7,5 → 1, 7 → 2 (Schisme et +), soit 46 à 8,5 ou plus ;
  avant les mots-clés : 10 → 34, 9,5 → 2, 9 → 10, 8,5 → 3, 8 → 17, 7 → 2 (49 à 8,5 ou plus). Nom 11 → 44, 10 → 8, 9 → 6, 8 → 4, 7 → 5, sous le plancher : Suppression de la douleur+
  (6,5). La largeur de Baloo et le biseau limitent la troisième ligne : un texte de trois lignes dont la
  dernière dépasse ~59 unités reste à 8 ; textes raccourcis dans `Data/Priest.lua` (règles et chiffres
  inchangés). Noms abrégés : « MdP : » (Mot de pouvoir) et « MdlO : » (Mot de l'ombre).
- **Plaque du bas** (mots-clés) : `Media/card_plate.tga` en trois tranches (bords à l'échelle de la
  hauteur, milieu étiré : élargie sans déformer ses coins), **devant** le corps (derrière, l'ombre portée
  du corps la masquait : on n'en voyait qu'un liseré), à la place du PSD (liseré du haut à cheval sur le
  bas opaque du corps). Zone utile mesurée sur la texture (`W.CARD_PLATE` : intérieur sombre x 20 à 234,
  y 20 à 70 sur 256 × 89 px) moins 3 unités de chaque côté. Paliers 9 / 8,5 / 8 (plancher) à la largeur
  de repos ; sinon plaque élargie au plancher, jusqu'à la largeur du corps ; au-delà, secours 7,5 / 7,
  puis mots-clés abrégés (`W.PLATE_SHORT`), puis les premiers suivis de « … ». Seule combinaison réelle
  élargie : « Incantation · Consumée » (Soins supérieurs, plaque de 102 unités, taille 8) ; aucune n'est
  abrégée. Mesure par le client (`GetUnboundedStringWidth`), vérification `IsTruncated`.
- **Plaque de raison** (carte injouable) : centre à 1,225 de la largeur du corps, son bas au-dessus du
  texte des mots-clés. Raison aux paliers 11 à 8 dans 0,84 du corps (6 unités de marge) ; au plancher,
  plaque élargie jusqu'à la largeur du corps ; au-delà, deux lignes équilibrées, la plaque grandit vers le
  haut et la zone du texte de la carte remonte d'autant (« Une incantation / est déjà en cours. »).
- **Zoom** (`W.faceApply`, trois modes, `/slay zoom` : net → fluide → lisse ; `/slay zoom net|fluide|lisse` ;
  `/slay zoom lent` : survols au ralenti ×8, diagnostic en jeu). Commun : mise en page indépendante de
  l'échelle (retours à la ligne explicites, largeurs et ancrages en unités du visuel, **tous les textes en
  `SetSmoothScaling`** : hauteur de police non arrondie, taille rendue exactement proportionnelle), position
  (levée, écart des voisines) pilotée par l'`OnUpdate` partagé, décalages divisés par l'échelle réelle,
  zone de survol immobile ; textures sans accrochage au pixel (`W.noSnap` : `SetSnapToPixelGrid(false)`,
  `SetTexelSnappingBias(0)`, comme les neuf tranches de Blizzard, aux points de création : `W.skin`,
  `W.nine`, `W.plaque`, `W.goldPill`, `W.hex`, `W.medallionOn`, pièces de `W.card` ; les FontString n'ont
  pas ces méthodes — `SimpleTextureBaseAPI` —, d'où le test d'existence).
  - **net** (défaut, préféré par le joueur pour la fluidité) : pendant le mouvement (0,12 s), animation
    `Scale` d'un `AnimationGroup` sur le visuel `face`, textes en `SetScaleAnimationMode(Vertex)` ; à
    l'arrivée, dans le même pas, échelle d'arrivée posée comme échelle **réelle** (`SetScale`) et
    animation coupée (`Stop`) : texte redessiné net. L'animation part du facteur 1 et tient son état
    d'arrivée (délai de fin) jusqu'à la bascule ; cible changée en route : relance depuis le facteur
    courant. Retour du joueur : « fluide mais les éléments sautent à l'arrivée ». Causes possibles d'un
    saut à la bascule, et ce qui est fait : (1) **cadres enfants du visuel** — si une animation `Scale` ne
    porte que sur les régions du cadre animé (non vérifiable hors jeu ; cohérent avec la capture d'avant
    où ruban et plaque ne suivaient pas), un cadre enfant ne grossit qu'à la bascule, d'un coup : la plaque
    de raison et l'étiquette de prix des cartes (`p`, cadre d'ancrage seulement) et le médaillon des jetons
    d'état (`W.medallionOn` sur le visuel) sont maintenant des **régions du visuel** ; le harnais (U26)
    vérifie qu'aucun visuel survolable n'a de cadre enfant dessiné et, sous cette hypothèse prudente,
    qu'image par image (4 ms) le pas de la bascule n'ajoute aucun déplacement au mouvement ; (2)
    **accrochage au pixel** des textures (recalées sur la grille de pixels à la nouvelle échelle réelle,
    alors que l'animation ne l'est pas) : coupé (`W.noSnap`) ; (3) **polices redessinées** à la nouvelle
    taille (crénage et lissage d'une autre taille de pixels) : inhérent au mode net, aucune animation ne
    peut le lisser ; c'est ce que supprime le mode fluide. Ce qui saute encore se verra au ralenti
    (`/slay zoom lent`).
  - **fluide** (option de comparaison) : l'échelle **réelle** du visuel vaut en permanence l'échelle
    survolée (`hoverScale`) : polices rasterisées une fois, à la taille qu'on lit ; au repos, une animation
    `Scale` tenue (délai de fin de 24 h) réduit le visuel d'un facteur 1 / `hoverScale` ; le survol anime ce
    facteur vers 1, la sortie le ramène à 1 / `hoverScale` ; ni `SetScale` ni `Stop` pendant un survol.
    Repos identique au mode net (harnais : mêmes rectangles affichés à ±0,01 ; carte agrandie : mêmes
    rectangles qu'en net à l'arrivée). Armement à l'image suivant `W.hoverable` (après la construction du
    widget : une région créée sous un visuel dont l'animation joue est mal dessinée, voir « Écran doré ») ;
    avant, repos sans animation à l'échelle réelle 1, identique à l'œil ; créations tardives sous un
    visuel armé (plaques de raison et de prix) par `W.faceBuild` (animation coupée le temps de la
    création puis relancée au même facteur, dans le même appel). Un cadre caché arrête ses animations :
    l'`OnShow` du visuel repose l'état avant la première image. `W.setHover` change échelle et levée de
    survol (récompense, grilles, marchand, deck, plaques de réponse, étapes du parcours) et repose
    l'échelle réelle tout de suite plutôt qu'au survol suivant. Vols (`W.fly`) : échelle réelle du cadre
    fixée à max(départ, arrivée) pendant tout le vol (polices à la plus grande taille, jamais étirées),
    taille animée par le facteur tenu du visuel ; pioche (0,3 → 1) : arrivée exactement dans l'état de
    repos, rien ne change à l'atterrissage. Coûts à surveiller en jeu : une animation tenue sur chaque
    visuel survolable affiché (cartes, boutons, jetons…), et un texte au repos rendu réduit (×0,86 en main)
    — à comparer en netteté avec le mode net.
  - **lisse** : échelle réelle à chaque image (15 images/s en jeu : re-rasterisation des polices).
  - Persistance : `options.zoom` (`net` par défaut ; `fluide` ou `lisse` enregistrés gardés ; ancienne
    valeur `anim` ou inconnue → `net`), `options.zoomSlow`.
- **Carte d'un seul bloc** : le visuel d'une carte (`face`) est agrandi de 0,3 de la largeur de chaque
  côté (`W.CARD_MARGIN`) pour contenir halo, languette de coût, ruban, plaques et étiquette de prix ;
  toutes les pièces et tous les textes sont posés par rapport au corps (`b.bg`, centré sur le visuel).
  Capture en jeu (mode `anim`) : ruban et plaque du bas restés à leur taille de repos pendant que corps,
  médaillon et textes grossissaient — les pièces qui débordaient du cadre animé ne suivaient pas
  l'animation `Scale` (hypothèse : seul cas commun aux pièces fautives) ; à l'arrivée, l'échelle réelle
  (mode `net`) vaut de toute façon pour tout le visuel.
- **Écran doré au premier survol** : le halo d'une plaque (`Plaque:SetGlow`) était créé au premier
  survol, donc pendant l'animation `Scale` du visuel ; le client dessinait ces textures nées en cours
  d'animation démesurées (aplat doré sur la scène et le plateau, seulement la première fois). Le halo est
  maintenant créé avec la plaque (caché, alpha 0) ; le halo des cartes part aussi de 0. Le faux client
  relève toute région créée sous un cadre dont une animation d'échelle joue (U23).
- **Plaques de réponse** (`plaque` de `UI/Screens.lua`) : zone utile = plaque moins 16 unités sur les côtés
  et 10 en haut et en bas ; libellé sur une ligne (paliers 20 / 18 / 16) ; texte sur une ligne aux deux
  premiers paliers (15,5 / 14,5), sinon en lignes équilibrées (coupure au mot le plus près du milieu,
  paliers 15,5 à 12,5) ; bloc (icône, libellé, texte) centré verticalement ; mesures par le client.
  « Combat : récompense habituelle + 20 po » : « Combat : récompense / habituelle + 20 po », loin des bords.
- **Textes vides jusqu'au survol** : une police d'addon chargée de façon asynchrone ne dessine rien pour
  un texte posé avant son arrivée, jusqu'à la prochaine mise en page — que provoquait justement le
  `SetScale` du survol. Le préchargement était sur un cadre transparent hors écran (sans doute jamais
  dessiné, donc rien chargé) : il est maintenant à l'écran, presque transparent ; et à chaque ouverture
  de la fenêtre (0,1 s après, et 1 s après la première), `W.refreshFonts` repose police et texte de tous
  les textes créés par `W.label` / `W.text` puis refait la mise en page des cartes.

## Langage des cartes (mots-clés, validé par le joueur)

Façon Hearthstone : les tournures deviennent des mots-clés visibles, en couleur, expliqués au survol.

### Écriture de `text` (`Data/Priest.lua`, Lua pur, la simulation ne lit pas `text`)

- **Une clause par ligne** : les clauses sont séparées par `\n` dans `text` ; une phrase par clause,
  terminée par un point (sauf les lignes d'état). Textes impersonnels, sans « tu » ni « vous ».
- **Condition sur un état** : « Nom : effet » = si l'état est présent ; sur soi pour un bienfait
  (« Expiation : +1 mana. »), sur la cible pour un affaiblissement (« Douleur : +2 Démence, pioche 1. »).
- **Conditions nommées** : « Exécution : » (la cible a la moitié de ses PV ou moins), « Déferlement : »
  (dépense toute la Démence), « Dernier souffle : » (une fois par combat, en tombant à 0 PV), « Ombre : »
  (s'applique aux cartes d'ombre). Une clause conditionnelle commence toujours une ligne, et la clause
  qui la suit aussi (« +1 Démence. » sous « Exécution : inflige 12. » ne doit pas paraître conditionnel).
- **États posés** : chaque état posé par les effets de la carte (`{ "apply", id, n }`) a sa ligne, à la fin
  du texte, sans point : « Donne » pour un état posé sur soi, « Applique » sur un ennemi (« à tous » si
  `all`), nom, nombre, puis « ⌛ » si le nombre est une durée en tours (état `duration` de
  `Core/Statuses.lua` : Expiation, Armure fracassée, Démoralisé ; et Étourdi, marqué `turns = true` pour
  l'affichage seulement : son nombre compte des tours perdus). Les états à intensité (Douleur,
  Récupération) n'ont pas de sablier. « Inflige » reste réservé aux dégâts. Ordre : « Applique » d'abord,
  puis « Donne ». Exceptions : un état posé sous condition (Récupération de Dernier souffle, Douleur de
  Déferlement) reste dans sa clause (« Déferlement : applique Douleur 2 par Démence. ») ; un état qui porte
  le nom de la carte (Suppression de la douleur) est décrit, pas nommé.
- **Mots de la plaque du bas** : « Pouvoir. » et « Incantation. » en tête, « Recharge N. », « Consumée. »,
  « Conservée. » en dernier, chacun sur sa clause ; retirés à l'affichage (`KEYWORD_STRIP`).

### Affichage (`UI/Widgets.lua`)

- `W.cardBody` : mots de la plaque retirés ; nom d'état collé à son nombre par une espace insécable
  (« Douleur 5 », « fracassée 2 ⌛ » ne se coupent pas), « à tous » insécable ; chiffres blancs (verts
  s'ils changent à l'amélioration) ; **noms d'états et conditions nommées en or** (`W.KEYWORD_COLOR` =
  `C.goldText` #ffd660, seule couleur d'accent : la police ne mêle pas deux graisses). Les verbes
  « Donne » / « Applique », l'Absorption et la Démence (ressources) restent dans la couleur du texte.
- **Sablier** : « ⌛ » (et l'espace qui le précède) devient à la mise en page une séquence
  `|TInterface\AddOns\SlayTheDragon\Media\hourglass.tga:h:l:0:0:32:32:0:28:0:32:255:255:255|t`
  (`W.hourglass(taille)`) : forme de `CreateTextureMarkup` (Blizzard_SharedXMLBase/TextureUtil.lua :
  hauteur, largeur, décalages, taille du fichier, coordonnées en pixels) plus la couleur de sommet r:g:b
  (0–255), forme qu'emploie Blizzard pour l'icône de l'armurerie dans la discussion
  (ChatFrameUtil.lua) ; champs entiers (`%d` partout chez Blizzard). Hauteur = taille × 0,68 arrondie
  (5 à 7 unités : les chiffres de Baloo Chettan 2 font 0,62 cadratin), largeur rognée à 28/32 (la marge
  gauche du dessin tient lieu d'espace après le nombre). La mesure par le client (`GetStringWidth`) et
  celle du faux client (`H.textWidth`) comptent la largeur de l'icône. Texture : `tools/build_glyphs.py`
  (Pillow, suréchantillonné ×8 puis réduit ; TGA 32 bits, 32 × 32, blanc à alpha, même écriture que
  `tools/build_media.py`, aperçu `build/media_png/hourglass.png`, `planche` = rendus à 8–16 px).
- **Lignes** (`W.cardTries`, `W.cardParagraphs`) : essais dans l'ordre, au premier qui tient : une clause
  par ligne (une clause peut tenir sur plusieurs lignes, elle commence toujours une ligne) aux paliers
  10 à 8,5 ; puis, palier par palier de 10 à 6 : une clause par ligne, texte coulé (les clauses simples
  qui se suivent partagent une ligne, chaque ligne d'état reste seule), états groupés en une dernière
  ligne (« Applique Douleur 3. Donne Récupération 1 », le verbe du second état collé à son nom). La ligne
  d'état commence toujours une ligne et finit le texte. Le bloc est centré verticalement ; s'il ne tient
  pas, il remonte par paliers (`W.BODY_LIFT` : 0,5 / 0,33 / 0,17 / 0 du jeu vertical) pour que le biseau
  du bas laisse plus de largeur à la dernière ligne ; zone utile `TZ` inchangée. Une couleur coupée par
  un retour est fermée et rouverte (`W.balanceColors`).
- **Infobulles** (`W.cardKeywords`, `W.keywordText`) : mots de la plaque, puis conditions nommées
  (`Art.keywords` : execute, surge, lastBreath, shadow), conditions sur un état (`Art.conditionLine` :
  « Expiation : effet en plus sous Expiation. », « Douleur : effet en plus si la cible a Douleur. »), états
  posés ou cités avec leur définition courte (`Art.statusShort`, ≤ 60 caractères ; le texte complet de
  `Core/Statuses.lua` reste celui des jetons), le sablier (« ⌛ : le nombre compte des tours. »), puis
  Absorption, Démence, Interruption. Le texte de la carte dans une infobulle (jeton de Pouvoir, aperçu
  d'amélioration) passe par `W.cardTextLines` : une ligne par clause, couleurs et sablier comme sur la
  carte (12 unités).
- **Pouvoirs joués** : déjà présents avant ce travail : `CombatView:RenderPlayer` ajoute à la rangée de
  jetons du héros un jeton par carte de `c.player.powers` (icône de la carte, liseré doré), infobulle =
  nom, texte et mots-clés (`W.fillCardTooltip(…, { full = true })`). Aucun changement de règle ni de
  sauvegarde ; le harnais (U27) le vérifie pour Forme d'ombre, Extase+, Esprit de rédemption, Apothéose.

### Textes (avant → après)

Planche de toutes les cartes : `lua5.1 Sim/ui_harness.lua 1 build/snap` puis
`rsvg-convert build/snap/cartes_mots_cles.svg -o build/cartes_mots_cles.png`.

| Carte | Avant | Après (`/` = retour de clause) |
|---|---|---|
| MdlO : Douleur | Douleur 5. +1 Démence. | +1 Démence. / Applique Douleur 5 |
| MdP : Radiance | Expiation 1 tour. Gagne 4 Absorption. | Gagne 4 Absorption. / Donne Expiation 1 ⌛ |
| Pénitence | Inflige 6 trois fois. Chaque coup sous Expiation : +2 Absorption. | Inflige 6 trois fois. / Expiation : +2 Absorption par coup. |
| MdP : Réconfort | Inflige 5. Sous Expiation : +1 mana. Expiation 1 tour. | Inflige 5. / Expiation : +1 mana. / Donne Expiation 1 ⌛ |
| Barrière lumineuse | Expiation 1 tour. Gagne 12 Absorption. | Gagne 12 Absorption. / Donne Expiation 1 ⌛ |
| Schisme | Inflige 3. La cible a Armure fracassée 2 tours. Expiation 1 tour. | Inflige 3. / Applique Armure fracassée 2 ⌛ / Donne Expiation 1 ⌛ |
| Guérison de l'ombre | Soigne 10. Douleur 2 sur soi. +1 Démence. | Soigne 10. / +1 Démence. / Donne Douleur 2 |
| Évangélisme | Expiation 2 tours. Pioche 2. | Pioche 2. / Donne Expiation 2 ⌛ |
| Fouet mental | Inflige 8. Si la cible a Douleur : +2 Démence et pioche 1. | Inflige 8. / Douleur : +2 Démence, pioche 1. |
| Peste dévorante | Dépense toute la Démence : Douleur égale au double. | Déferlement : applique Douleur 2 par Démence. |
| Forme d'ombre | +2 Démence. Cartes d'ombre : dégâts et Douleur +3. | +2 Démence. / Ombre : dégâts et Douleur +3. |
| Toucher vampirique | Douleur 3. Récupération 1. +1 Démence. | +1 Démence. / Applique Douleur 3 / Donne Récupération 1 |
| Incandescence mentale | Douleur 4 à tous les ennemis. +1 Démence. | +1 Démence. / Applique Douleur 4 à tous |
| MdlO : Mort | Inflige 6, ou 12 si la cible a la moitié de ses PV ou moins. +1 Démence. | Inflige 6. / Exécution : inflige 12. / +1 Démence. |
| Cri psychique | Tous les ennemis sont Démoralisés 2 tours. +1 Démence. | +1 Démence. / Applique Démoralisé 2 ⌛ à tous |
| Éruption du Vide | Dépense toute la Démence : inflige 4 + 4 par point. | Déferlement : inflige 4 + 4 par Démence. |
| Flammes sacrées | Inflige 24 et Douleur 3. | Inflige 24. / Applique Douleur 3 |
| Nova sacrée | Récupération 2. Inflige 4 à tous les ennemis. | Inflige 4 à tous. / Donne Récupération 2 |
| Mot sacré : Châtier | Inflige 7. Étourdi 1. | Inflige 7. / Applique Étourdi 1 ⌛ |
| Esprit de rédemption | Une fois par combat, à 0 PV : reste à 1 PV, Récupération 6, tour suivant gratuit. | Dernier souffle : reste à 1 PV, Récupération 6, tour gratuit. |
| Rénovation | Récupération 3. | Donne Récupération 3 |
| Halo | Récupération 3. Inflige 15 à tous les ennemis. | Inflige 15 à tous. / Donne Récupération 3 |
| Embrasement empyréen | Inflige 28. Armure fracassée 2 tours. | Inflige 28. / Applique Armure fracassée 2 ⌛ |

Les autres cartes ne changent que par leurs retours de clause (mots de la plaque omis ci-dessus).

## Retours du premier essai (survols, deck, paysages, bandeau, vouvoiement)

- **Survols animés partout** (`W.hoverable`, `UI/Widgets.lua`). Règle : le cadre qui reçoit la souris
  ne bouge jamais (zone de survol fixe, invisible) ; tout le visuel vit dans son enfant `face`, seul
  animé (échelle par animation Scale, position par `SetPoint`, couleurs ; voir « Texte des cartes et
  zoom »). Pas de clignotement entrée/sortie
  possible. Canaux animés `W.animTo(obj, clé, cible, durée)` : la valeur file vers sa cible en
  0,12 s (entrée) / 0,15 s (sortie), courbe amortie (cubique), et repart de sa valeur courante si la
  souris ressort en route (réversible). Un seul `OnUpdate` partagé (`W.driver`) pour ces canaux et pour
  les interpolations `W.tween` ; il se coupe (`SetScript("OnUpdate", nil)`) dès que plus rien ne bouge.
  Minuteur de secours par animation (images sautées). Les durées de survol ne dépendent pas de la
  vitesse des animations de combat.
  - Main : la carte survolée (ou sélectionnée) se lève jusqu'à y 372, grossit ×1,16, passe devant ;
    les voisines s'écartent (26 px puis 12 px, visuel seulement) ; sa zone de survol est prolongée vers
    le haut tant qu'elle est levée (`SetHitRectInsets`), pour pouvoir « monter » sur la carte.
  - Cartes de récompense, du marchand, des grilles et du panneau du deck : levée + agrandissement +
    halo en fondu, passage au premier plan (`W.placeCard` / `W.cardFront` : niveau levé, puis juste
    au-dessus des voisines tant qu'elle rétrécit, puis niveau de repos).
  - Boutons (fond qui glisse vers la couleur de survol, ×1,04–1,06), boutons ronds ≡ ×, butin au sol
    et objets du feu de camp (se soulèvent, halo en fondu, l'ombre reste au sol), étapes du parcours
    (×1,18 si accessible, ×1,06 sinon), plaques de réponse (levée, halo, parchemin plus clair ; une
    réponse impossible bouge à peine), fioles et bibelots du bandeau, clé, gemmes de clé de l'accueil,
    tas du deck, pioche, défausse, consumées.
  - Ennemis : quand une carte à cible (ou une potion à cible) est armée, l'ennemi survolé — ou la
    ennemi retenu — grandit ×1,07 depuis ses pieds et son anneau s'allume ; la zone de clic (emplacement)
    ne bouge pas.
  - Infobulles conservées (le survol animé est ajouté dans `W.tooltip`).
- **Consulter ses cartes** (`UI.deckView`, fin de `UI/Screens.lua`) : panneau de bois par-dessus
  l'écran (sous le bandeau), titre court « Deck · 18 cartes » / « Pioche · … » / « Défausse · … » /
  « Consumées · … », grille de vraies cartes (`W.card`, 8 par rangée, 3 rangées visibles, ×0,72),
  triées par type (Sort offensif, Sort, Pouvoir), coût, nom (puis non améliorée avant améliorée) ;
  améliorées en vert comme ailleurs. Molette : une rangée par cran (indicateur à droite si ça déborde).
  Fermeture : clic hors du panneau (voile), clic droit sur une carte, « Fermer », nouveau clic sur ce
  qui l'a ouvert, ou `Échap` qui ferme la fenêtre entière. Accès : tas du deck du plateau (récompense, feu de camp, marchand,
  grilles) et deck du bandeau (dos de carte et nombre), désormais **aussi en combat** (deck complet) ; en combat,
  clic sur la pioche (**toujours triée**, jamais l'ordre de tirage), la défausse, et le nouveau tas
  violet des **consumées** (x 151–187, affiché dès qu'il y en a une).
- **Paysages** : voir « Fonds embarqués » plus bas. Chaque décor affiche **par défaut, sans
  validation**, une illustration embarquée dans l'addon (`Media/Backgrounds/*.tga`) ; le décor peint
  reste dessous en repli et `/slay decor peint` y revient. Les anciens candidats du client (FileDataID,
  « Diagnostic des paysages ») restent en repli dans `Art.illustrations`, derrière le fond embarqué, et
  ne servent plus.
- **Bandeau** : le nom de zone est sur la ligne du haut, les points de progression centrés sur la ligne
  du bas ; le cadre central va de l'or au premier élément de droite (bouton Deck) et un nom trop long
  est tronqué. Plus aucun chevauchement possible.
- **Vouvoiement** : plus de « tu / te / ton / ta / tes / toi / t' » ni d'impératif familier dans les
  chaînes de `UI/` (raisons, bilan, étapes, infobulles, mots-clés) : tournures impersonnelles, « votre »
  si la phrase s'adresse au joueur (« Ce n'est pas votre tour. »). Les textes de `Core/` et `Data/`
  (cartes, rencontres, raisons du moteur) relèvent de l'autre piste.

### Fonds embarqués

Un fichier de l'addon existe forcément (comme `Media/Icons/*.tga`, qui s'affichent en jeu) : les fonds
des scènes sont donc des TGA livrés avec l'addon, affichés sans essai ni validation.

- **Source** : des **illustrations de Blizzard extraites du jeu** (écrans de chargement), téléchargées
  par FileDataID depuis `https://wago.tools/api/casc/<id>?download` (BLP lu par Pillow) dans
  `build/decors_src/`. **À réévaluer avant toute publication de l'addon** (droits de Blizzard).
- **Fabrication** : `build/venv/bin/python -I tools/build_backgrounds.py [planche] [scenes]` (venv de
  `tools/build_media.py`). Le script retélécharge les sources manquantes (liste en tête : FileDataID,
  chemin, proportions réelles, zone gardée), écrit `Media/Backgrounds/<clé>.tga` (TGA 32 bits non
  compressé, même écriture que `build_media.py`) et les aperçus `build/media_png/Backgrounds/<clé>.png`
  (rendu hors jeu), puis affiche le `ratio` de chaque fond à recopier dans `Art.backgrounds`.
  `planche` : `build/decors_planche.jpg` (candidats examinés, bande 2,72:1, retenus encadrés) ;
  `scenes` : `build/decors_scenes.jpg` (les 9 scènes cadrées et teintées comme en jeu, d'après `UI/Art.lua`).
- **Format** : la source est ramenée à ses vraies proportions (écrans classiques 2048 × 2048 = 4:3
  étirés), la zone gardée (sans logo ni cadre) est **étirée sur toute la texture 1024 × 512** ; son
  rapport réel (`ratio`, 2,0 à 2,6) est rétabli à l'affichage : `Scene.bandCoords` n'en montre qu'une
  bande au format du décor (1034 × 380 ≈ 2,72:1), placée en hauteur par le `focus` de la scène
  (0 = haut, 1 = bas). Une image sert ainsi plusieurs scènes avec des cadrages et teintes différents.
  5 fonds × 2 Mo = 10,5 Mo.
- **Affichage** : le fond embarqué est en tête de la liste de chaque illustration (`Art.illustrations`) ;
  `Scene.chosen` prend le premier candidat qui est embarqué ou validé. Teinte par scène (`tint`), voile
  sombre léger sur les 170 px du bas (sol des personnages, `Scene.ground`, 38 % au bas), décor peint
  dessous. `/slay decor` (ou Options → « Décor illustré ») bascule illustré / peint ; `/slay art` liste
  les fonds embarqués, leur FileDataID et leurs scènes.

| Fond (`Media/Backgrounds`) | FileDataID | Illustration | Scènes (`focus`) |
|---|---|---|---|
| `elwynn.tga` | 7377860 | Forêt d'Elwynn (logement, Midnight) | road 0,62 · hill 0,15 · camp 0,9 · shop 0,78 · night 0,55 (teinte nuit bleutée) |
| `farm.tga` | 407226 | Pics-Jumeaux : chaumière, chemin, charrette | farm 0,55 |
| `deadmines.tga` | 131833 | Mortemines (écran classique, navire dans la grotte) | mine 0,5 |
| `ruins.tga` | 7963782 | Ruines de Lordaeron (écran Forever) | ruins 0,5 |
| `coast.tga` | 427941 | Gilnéas : phare sur la côte | coast 0,45 |

Écartés (planche) : Excavation 7963777 (sépia, sans ferme), Bassin d'Arathi 2820825 et les autres
écrans larges BfA (logo en haut), mine gobeline 2016712 (trop sombre, logo), cité en ruine 131866,
Gilnéas la ville 405445 et Manoir Malvoie 1984118 (nuit : Elwynn assombri suffit), carte des royaumes
de l'Est 7963776 (carte, pas paysage), Goulet des Chanteguerres 2827086 (personnages au premier plan).
Limites : les cinq cadrages d'Elwynn diffèrent peu (zone de rapport 2,0) ; les Mortemines sont un
croquis au trait, d'un autre style que les autres ; la côte est celle de Gilnéas (pins, gris-bleu), pas
la Marche de l'Ouest dorée.

### Diagnostic des paysages

- Le décor de tous les écrans de route, de ferme, de colline, de camp, du marchand et du feu de camp
  utilisait **un seul fichier** : `7377860` = `interface/glues/loadingscreens/expansion10/main/
  loadscreen_housing_elwynnforest` (écran de chargement du **logement de Midnight**). Il figure dans la
  liste de fichiers **retail 12.1.5** du MCP, mais WoW Forever est un client « Camelot » (1.16) bâti sur
  le contenu classique : ce fichier n'y est très probablement pas. `SetTexture` échouait (ou ne
  chargeait rien), l'ancien code masquait l'illustration et laissait le décor peint — d'où « les
  paysages ne s'affichent pas ».
- La liste de fichiers contient en revanche des écrans de chargement **propres à Forever**
  (`interface/glues/loadingscreens/camelot160/main/…` : `easternkingdom` 7963776, `excavation`
  7963777, `ruinsoflordaeron` 7963782, `kalimdor`, `dalaran`, `oldironforge`, `zephrasisle`) et les
  écrans classiques (`loadscreeneasternkingdom` 131839, `loadscreendeadmines` 131833).
- Limites : le MCP ne trouve aucune installation sur cette machine (`wow_install_info`) et le code de
  l'interface Blizzard de Forever n'est pas synchronisé (`wow_ui_grep` flavor forever refusé ; la
  synchronisation n'a pas été lancée, consigne). Impossible donc de lister les fichiers réellement
  présents dans le client Forever ni de voir comment son écran de chargement recadre ces images.
- Candidats listés (ordre) : Elwynn → 7377860, 7963776 (Forever, royaumes de l'Est), 131839 puis son
  chemin `Interface\Glues\LoadingScreens\LoadScreenEasternKingdom` ; Mortemines → 131833, son chemin,
  7963777 (Forever, excavation) ; ruines → 7963782 (Forever, ruines de Lordaeron) puis la liste
  d'Elwynn. Les recadrages des nouveaux candidats sont estimés (16:9 → 65 % de la hauteur, 4:3 → 50 %).
- Détection automatique **supprimée** : en jeu, `SetTexture`, `GetTextureFileID` et `IsObjectLoaded`
  ont déclaré « retenus » 7377860, 131833 et 7963782 alors que l'écran était vert (fichier absent).
  Aucune API documentée pour Forever (`GetFileIDFromPath`, `C_Texture.GetFilenameFromFileDataID`,
  `GetTextureFilePath`, `IsObjectLoaded`) ne promet de distinguer un fichier absent (`wow_api_search` ;
  le code Blizzard de Forever n'est pas synchronisé, celui de retail n'en montre aucun usage en ce sens) :
  aucune n'est employée. Le décor peint est la règle ; seul le joueur valide un candidat.

### Essai des décors

Facultatif depuis les fonds embarqués (les candidats du client ne servent qu'en repli, derrière eux).
`/slay decor essai` (fenêtre ouverte au besoin ; l'accueil montre un décor, le parcours non) affiche sur le
décor courant, sans teinte ni voile, le candidat n° k des 8 candidats connus (toutes listes, dédoublonnés),
en commençant au premier pas encore jugé ; la discussion annonce « k/8 : fichier — nom [verdict] ».
`suivant` / `precedent` changent de candidat ; `ok` (image visible) ou `non` (aplat vert, noir, vide) jugent
celui affiché (`options.artChecks`, sauvegardé) ; `peint` finit l'essai et fixe le décor peint (`illustre` l'inverse).

La piste C a écrit l'interface, la piste D l'a branchée sur la couche expédition, la **piste E** l'a
entièrement redessinée en « table de jeu illustrée » d'après les maquettes validées
(`docs/maquette/*.dc.html` : `Main`, `Cartes`, `Parcours`, `Recompense`, `Rencontre`).

## Piste E : ce qui a changé

- Fenêtre **1040 × 620** (au lieu de 900 × 520), déplaçable par le bandeau, échelle 60–150 %. Plus de
  cadre Blizzard ni de boutons gris : formes dessinées (rectangles arrondis, disques), parchemin, bois,
  polices Morpheus (titres, chiffres) et Friz Quadrata (texte), palette des maquettes (`Art.C`).
- **Scène commune** (`UI/Scene.lua`) : décor plein cadre en haut (y 44–424), plateau de bois en bas
  (y 424–614), personnages posés au sol avec ombre. Le décor est une illustration embarquée dans l'addon
  (`Media/Backgrounds`, « Fonds embarqués ») recadrée et teintée, avec dessous un décor **peint** en
  couches unies (champs, ferme, côte, mine, nuit) en repli ; `/slay decor` (ou Options → « Décor
  illustré ») bascule de l'un à l'autre.
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
  d'elle-même. Un mot-clé = une ligne « Nom : effet. » (`Art.keywordLine`), 60 caractères au plus, l'effet
  principal seulement (« Incantation : se lance au début du prochain tour. ») ; plusieurs mots-clés =
  une ligne chacun, en bloc. Les aides (potion, réputation) : une idée par ligne. Les états cités par une carte ont une
  définition courte (`Art.statusShort`, voir « Langage des cartes ») ; leurs jetons gardent le texte de
  `Core/Statuses.lua`.
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
| `UI/SkinData.lua` | GÉNÉRÉ par `tools/build_media.py` : textures de `Media/` (fichier, toile, zone utile, coordonnées), géométrie de la carte, icônes copiées, polices | non |
| `UI/WowSkin.lua` | GÉNÉRÉ par `tools/build_wowui.py` : pièces de l'interface du jeu embarquées dans `Media/WowUI` (fichier, toile, taille, coordonnées, bouts, axe répété, FileDataID), mesures des filets et logements | non |
| `UI/Art.lua` | Palette, textures, décors (`Art.scenes`), personnages de rencontre (`Art.npcs`), sons, icônes (cartes, états, intentions, affixes, bibelots, potions, parcours ; champ `tga` = icône améliorée), couleur du corps des cartes, gemmes, teintes des liserés, mots-clés, animations | non |
| `UI/Persist.lua` | Chargement de `SlayTheDragonDB` par `Save.migrate`, options de l'interface (`db.options`, dont `decor` et `artChecks`) | non |
| `UI/Controller.lua` | Couche mince écrans ↔ `Core/Expedition` (étapes génériques, combat, potions, fin, validation, décor de l'étape, mana max, nom du boss) | non |
| `UI/Widgets.lua` | Habillage WoW (pièces de `Media/WowUI` : cadres à pièces, trois et neuf tranches, dialogues, parchemins, boutons rouges, cases, curseurs, barres d'unité), peau des cartes (textures de `Media/`), polices, sons, pilote d'animations (interpolations, canaux animés), survols (zone fixe + visuel `face`), icônes (améliorées d'abord), carte unique composée, jauges de vie, hexagone d'Absorption, jetons d'état, boutons, infobulles, textes flottants, modèles | oui |
| `UI/Scene.lua` | Décor (fond embarqué cadré et teinté, voile du bas, décor peint dessous ; repli : candidat du client validé par l'essai manuel ; rapport `/slay art`), plateau, personnages (modèle, ombre, anneau de cible) | oui |
| `UI/Main.lua` | Fenêtre, bandeau, écrans, options, `/slay`, bouton de minimap | oui |
| `UI/CombatView.lua` | Écran de combat et ses animations | oui |
| `UI/Screens.lua` | Accueil, rencontre, feu de camp, récompense (et coffre), grille du deck, marchand, parcours, bilan et méta, panneau de consultation des cartes (`UI.deckView`) | oui |
| `UI/Flight.lua` | Événements : chargement, vol en taxi, combat réel, déconnexion | oui |
| `Sim/ui_harness.lua` | Harnais hors jeu (faux client WoW) | — |
| `Sim/ui_render.lua` | Rendu SVG des cadres du faux client (instantanés d'écrans, textures de `Media/` comprises) | — |
| `tools/build_media.py` | Fabrication des pièces des cartes, de la police, des icônes (`Media/`) et de `UI/SkinData.lua` (hors TOC, non déployé) | — |
| `tools/build_wowui.py` | Fabrication de l'habillage WoW : `Media/WowUI` et `UI/WowSkin.lua` (sources par FileDataID, planches de contrôle ; hors TOC, non déployé) | — |
| `tools/build_glyphs.py` | Icônes en ligne du texte des cartes : `Media/hourglass.tga` (sablier, Pillow ; hors TOC, non déployé) | — |

`UI\Scene.lua` a été ajouté au TOC par la piste E (client relancé depuis) ; la peau ajoute
**`UI\SkinData.lua`** (avant `UI\Art.lua`) et le dossier `Media/` ; l'habillage WoW ajoute
**`UI\WowSkin.lua`** (après `UI\SkinData.lua`) et `Media/WowUI` : **relancer le client** au prochain essai.
Les fichiers qui touchent l'API WoW commencent par `if not CreateFrame then return end` ; `Sim/load.lua`
saute de toute façon les lignes `UI\` du TOC. **Aucune règle de jeu dans `UI/`**.

## Écrans

Coordonnées : celles des maquettes, depuis le coin haut gauche de la zone intérieure (1034 × 614).

**Bandeau** (y 0–31, sur la barre de titre du cadre métal, sur tous les écrans ; on le saisit pour déplacer
la fenêtre) : à gauche la classe, « HP 52/65 », l'or (pièce), le deck (dos de carte et nombre ; partout,
combat compris ; infobulle = contenu du deck ; clic = panneau du deck) ; au centre la zone (« Act 1 ·
Westfall » sur la carte) puis, ailleurs, les pastilles de progression de la carte de vol sur la même ligne ;
à droite la clé mythique (case à l'icône de la clé, « +N », infobulle = affixes), les bibelots (cases au
cadre teint à la rareté), 3 fioles (potions), « Menu » (options), fermeture. Détail : « Habillage WoW ».

| Phase / vue | Écran | Contenu |
| --- | --- | --- |
| aucune expédition | **Accueil** (`start`) | décor voilé, héros ; parchemin : titre, classes (plaques), clé +0…+5 en gemmes (verrouillées sombres ; infobulle = affixes et raison), icônes d'affixes de la clé choisie ; plateau : « Réputation et journal », dernière expédition et avertissements de sauvegarde, « Partir en expédition » |
| `start` | **Rencontre** (`choice`) | bibelot de classe (Révéré) : bulle, une plaque par bibelot (icône, nom, effet), « Partir sans bibelot » |
| `map` | **Parcours** | parchemin sans décor ; étapes en symboles (icône du type dans un disque, « ? » pour une rencontre) ; accessibles : halo doré, couleur du type ; franchies : disque rouge coché ; position actuelle : plus grande, bord doré, anneau crème ; à venir : disque beige, icône ternie (élite : bord violet) ; boss : losange rouge « Boss » et nom du boss ; chemin parcouru en trait rouge plein, départs possibles en pointillés dorés, le reste en pointillés bruns. Aucune légende ; infobulle = nom du type |
| `combat` | **Combat** | voir plus bas |
| `reward` | **Récompense** | décor du combat, héros ; 3 cartes en grand (survol : plus grandes) ; butin au sol à droite : bourse avec montant, bibelot, fiole (« Pas de place » si les emplacements sont pleins) ; plateau : tas du deck, « Reprendre la route ». Coffre (`chest`) : un coffre à ouvrir d'abord (clic). Rencontre : bulle du texte après coup |
| `campfire` | **Feu de camp** | décor de nuit, feu qui vacille, couchage (« +N PV » calculés par le moteur) = repos, grimoire (« Améliorer une carte ») = grille d'amélioration, « Reprendre la route » |
| `merchant` | **Marchand** | étal (tenture, comptoir) : 5 cartes de classe + la carte neutre en 6e (corps vert sauge, ligne « Neutral » en infobulle) avec étiquette de prix (rouge si trop cher, « Vendu »), bibelots puis fioles à droite avec prix ; plateau : tas du deck, plaque « Retirer une carte » avec son prix, « Partir » |
| `event` | **Rencontre** | décor `scene`, héros à gauche, personnage à droite (modèle si `npc` est dans `Art.npcs`, sinon rien), nom (`speaker`), bulle (titre + texte ; bord doré si `rare`, violet si `story`) ; plaques de réponses à la place de la main : libellé et l'issue sur une ligne (verte si elle commence par « + », « ? » si cachée), réponses impossibles grisées avec leur raison ; après coup : `exp.event.result` et « Continuer » |
| `select`, amélioration, retrait | **Grille du deck** (`deck`) | panneau de bois sur le décor voilé, titre court, cartes à 80 % (16 par page, flèches) ; amélioration : la carte survolée montre sa version améliorée ; plateau : « Retour » / « Passer » |
| `done` | **Bilan** (`end`) | parchemin : titre (vert ou rouge), bilan, barres de réputation ; « Nouvelle expédition », « Réputation et journal » |
| vue méta | **Méta** | parchemin : barres par classe et Ligue, 8 dernières expéditions ; « Retour » |

**Potions** : en combat, clic = boire ; potion à cible : clic, puis clic sur un ennemi ; clic droit
annule. Hors combat : « Les potions se boivent en combat » ; deux clics droits
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
  affaiblissement, vert = soin), modèle 3D avec ombre, anneau doré aux pieds de la cible (survol, ou ennemi
  retenu pendant une visée) ; sous les pieds, dans un cadre d'infos au-dessus du personnage (aucun
  modèle ni repli ne peut les recouvrir) : nom sur une pilule d'ardoise (élite violet, boss orangé ;
  réduit s'il est trop long), barre de vie (+ écusson d'Absorption), états en pastilles. Les pieds sont
  sur la même ligne quelle que soit la taille du personnage (`art.scale` : l'emplacement remonte), de
  sorte que nom et états restent au-dessus du plateau (vérifié par le harnais pour 1 à 6 ennemis).
  Sans modèle : médaillon argenté à l'icône de l'ennemi (`Art.enemies[id].icon`), ou disque sombre.
- Plateau : orbe de mana « 2/3 » (mana max lu par `Combat.modify(c, "maxMana", …)`), pastille Démence
  (cachée à 0), pioche, défausse et consumées (tas avec nombre ; infobulles : contenu trié ; clic =
  panneau des cartes, pioche triée), main en arc au centre (cartes droites ; la survolée monte, grossit
  ×1,16, passe devant, les voisines s'écartent — animé), mini-cartes des recharges (tours restants),
  « Fin du tour » doré.
- Fin de combat : « Victoire ! » / « Défaite » en grand, bouton « Continuer » / « Voir le bilan »,
  affichés quand la file d'animations est vide.

### Contrôles

- **Tout à la souris.** Clic sur une carte (elle se lève), puis clic sur l'ennemi ; une carte sans cible
  se joue par un second clic ou un clic dans le décor. Une carte à cible cliquée deux fois se joue sur
  l'ennemi retenu (le dernier ennemi cliqué, sinon le premier vivant ; anneau allumé pendant la visée).
  Glisser-déposer : sur l'ennemi, ou n'importe où dans le décor pour une carte sans cible. Clic droit :
  désélectionner. « Fin du tour », « Continuer » / « Voir le bilan », et ailleurs un bouton ou un clic par
  action.
- **Aucun raccourci clavier** (demande du joueur, 12/11/2026 : en vol, `Entrée` sert au chat, `Espace` au
  saut, les chiffres aux barres d'action). Aucun cadre de l'addon n'appelle `EnableKeyboard` ni n'a de
  script `OnKeyDown`/`OnKeyUp` : toutes les touches vont au jeu comme si la fenêtre n'était pas là. Les
  anciens raccourcis (`1`…`0` cartes et choix, `Entrée`, `Espace` fin du tour et action par défaut, `Tab`
  changement de cible) sont retirés ; le changement de cible se fait au clic sur l'ennemi.
- Deux exceptions, qui ne captent rien : `Échap` ferme la fenêtre par le mécanisme standard du jeu
  (`UISpecialFrames`, nom `SlayTheDragonFrame`), et avec elle les options et le panneau des cartes (ils ne
  se ferment plus un par un ; leurs boutons de fermeture le font) ; **Maj tenue** au moment de jouer une
  carte « Spend N » la joue sans dépenser (modificateur lu par `IsShiftKeyDown`, la main redessinée sur
  `MODIFIER_STATE_CHANGED`).
- `/slay` : ouvrir/fermer ; `/slay options` ; `/slay art` (fonds embarqués avec FileDataID et scènes,
  puis décor par décor : fond embarqué, candidat validé ou « peint », puis candidats du client validés /
  refusés / pas encore jugés ; puis icônes et modèles introuvables) ;
  `/slay modeles` (galerie des ennemis et des personnages, puis au chat la liste des modèles absents
  avec les identifiants essayés) ; `/slay decor` (bascule illustré / peint ; sous-commandes
  `peint`, `illustre`, et, facultatives, `essai`, `suivant`, `precedent`, `ok`, `non` : « Essai des décors ») ;
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

Interpolations : un seul `OnUpdate` (`W.driver`, partagé avec les survols), coupé quand rien ne bouge ;
chaque animation a aussi un minuteur de secours qui la termine (images sautées ; le harnais n'a pas
d'`OnUpdate`, mais ses tests de survol font avancer le pilote image par image).

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
(`autoOpen, autoClose, scale, speed, fast, decor, artChecks, minimap = { hide, angle }, facingPlayer,
facingEnemy, point` ; `artChecks` = verdicts de l'essai des décors, `tostring(fichier) -> true | false`), que `Save.migrate` garde tel quel (il ne retire jamais un champ inconnu ; testé).

- Chargement (`ADDON_LOADED`) : `SlayTheDragonDB = Save.migrate(SlayTheDragonDB)`, puis options par défaut.
- Expédition illisible pour `Save` : quarantaine par `Save.migrate`. Illisible pour l'interface (bibelot,
  potion, ennemi, intention, article ou rencontre inconnus, combat abîmé) ou erreur Lua à la reprise :
  `Save.quarantine(db, raison)`. Un message le signale à l'accueil et dans la discussion ; rien n'est effacé.
- Sauvegarde d'une version **plus récente** de l'addon : `Save.migrate` n'y touche pas ; l'interface
  joue alors sur une base de session jamais écrite (`Persist.readOnly`, message dans la discussion).

## Art, textures, sons et API

### Confirmé par le MCP « wow »

- **Icônes** (FileDataID, `wow_icon_search`) : toutes celles de `UI/Art.lua` (cartes, états, intentions,
  bibelots, potions, parcours, couchage, grimoire, coffre, mana, or, point d'interrogation 134400 ;
  replis des ennemis sans modèle : têtes de gnoll 134163 et de murloc 134169, engrenage 134063), plus
  les chemins des affixes (piste D). Une carte essaie d'abord l'icône de son sort (`C_Spell.GetSpellTexture`),
  puis le FileDataID, puis le point d'interrogation.
- **Textures** (`wow_file_search`, liste de fichiers du client 12.1.5) : disque
  `interface/characterframe/tempportraitalphamask` (130924 : formes rondes et masques), parchemin
  `interface/helpframe/tileable-parchment` (516781), bois `interface/gamepad/woodtile` (7149548), coche
  `interface/raidframe/readycheck-ready` (136814) ; illustrations des décors : fonds embarqués (« Fonds
  embarqués » : sources par FileDataID, fichiers dans `Media/Backgrounds`), puis en repli les candidats
  du client (`Art.illustrations`, voir « Diagnostic des paysages »). Le MCP confirme la liste de fichiers **retail 12.1.5**, pas l'installation Forever (il ne
  trouve aucune installation ici).
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
  événements de vol, `SetCreature`, `SetDisplayInfo`, `SetUnit`,
  `SetAnimation`, `GetModelFileID`, `SetTexture -> success`, `SetDesaturated`, `CreateLine`,
  `IsMouseOver`, `C_Timer`, `C_Spell.GetSpellTexture`, `InCombatLockdown`, `GetCursorPosition`…
  Survols et panneau : `SetScale` (cadre), `SetHitRectInsets`, `EnableMouseWheel`, `GetChildren`,
  `SetFrameLevel` (et `SetFixedFrameLevel`, non employé), scripts `OnSizeChanged` et `OnMouseWheel`
  (employés par l'interface Blizzard 12.1.5). Les décors n'appellent plus `IsObjectLoaded`,
  `GetTextureFileID` ni `C_Texture.GetFilenameFromFileDataID` (détection supprimée).
- **Peau** (`wow_api_search`, Forever) : `SetTexture(fichier, enveloppeH, enveloppeV, filtre)` (filtre
  `"TRILINEAR"` comme la carte du monde Blizzard ; `"REPEAT"` + coordonnées > 1 pour les matières
  carrelées), `SetTexCoord`, `CreateMaskTexture` / `AddMaskTexture` (masques TGA de l'addon),
  `FontString:SetRotation` (nom des cartes), `SetSpacing`, `SetDrawLayer`, `SetClipsChildren` (fenêtre),
  `HookScript` (`OnSizeChanged` : plusieurs observateurs de taille). `SetTextureSliceMargins` existe mais
  n'est pas employé (neuf tranches faites main, comportement connu). Icônes de repli des nouvelles icônes
  (`wow_file_search`) : 134950 (inv_shield_04), 136155 (spell_shadow_evileye), 133730
  (inv_misc_bone_humanskull_01), 236409 (achievement_boss_edwinvancleef), 7808148
  (inv_camelot_camping_welcomingcampfire), 132594 (inv_box_01), 135813 (spell_fire_flameshock).
- `wow_lua_lint` (forever) sur tout `UI/` : aucune erreur ; un avertissement attendu sur `CreateColor`
  (fonction Lua de l'interface, pas de l'API C) ; notes « OnUpdate » sur le glisser-déposer, le bouton de
  minimap, le feu et le pilote des interpolations (voulues). `wow_toc_validate` : aucune erreur
  (avertissements habituels sur les barres obliques inverses).

### Non vérifié (à voir en jeu)

- Le **clavier laissé au jeu** (12/11/2026) : fenêtre ouverte, `Entrée` ouvre le chat, `Espace` saute,
  les chiffres lancent les barres d'action, et rien ne se passe dans l'addon ; `Échap` ferme la fenêtre
  (avec options et panneau des cartes) par `UISpecialFrames` sur Forever, une seule pression, sans ouvrir
  le menu du jeu ; Maj tenue au clic d'une carte « Spend N » la joue sans dépenser. Le harnais simule
  `CloseSpecialWindows` d'après l'interface de Blizzard (retail ; celle de Forever n'est pas indexée).
- Les **fonds embarqués** en jeu : chargement des TGA 1024 × 512 (même format que les autres TGA de
  `Media/`, qui s'affichent), netteté de la bande étirée, cadrage (`focus`), teinte (`tint`) et voile du
  bas derrière les vrais modèles ; à corriger dans `Art.scenes` ; repli immédiat : `/slay decor peint`.
  Le rendu hors jeu dessine les dégradés (voile du bas, fondu vers le plateau) en aplat : en jeu ce sont
  des dégradés. Quels candidats du client existent dans Forever : seul l'essai manuel le dit (facultatif).
- Les **survols** : fluidité, absence de clignotement, passage au premier plan (le visuel `face` et ses
  enfants sont re-nivelés explicitement par `W.setLevel`), zone prolongée vers le haut de la carte
  levée, molette sur les cartes du panneau.
- Les **modèles** (`/slay modeles`). Identifiants relevés dans le cache de créatures du client Forever
  (`Cache/WDB/enUS|frFR/creaturecache.wdb` : identifiant, nom, affichages ; `wow_creature_search` ne
  trouvait pas l'installation) : gnoll 117 / 175, mystique 453 / 502, murloc 126 / 983, bandit 116 /
  2357, 2358, sorcier 619 (Invocateur défias) / 2329, 2330, golem 36 / 367, Rhahk'Zor 644 / 14403,
  sbire 594 (Malfrat défias) / 2323, 2324, VanCleef 639 / 2029 ; rencontres : Salma Saldean 235 / 1691,
  Saldean le fermier 233 / 1943, Gryan Fortmanteau 234 / 1690. Chaque entrée essaie la créature
  (`SetCreature`), puis chaque affichage (`SetDisplayInfo`) ; un essai est réussi si `OnModelLoaded` a
  sonné pour lui ou si `GetModelFileID` rend un fichier 0,8 s plus tard (`W.MODEL_WAIT`) ; sinon repli
  (médaillon pour un ennemi, rien pour un personnage de rencontre), puis relance tardive de la créature
  à 3 s (`W.MODEL_LATE`) et effacement du repli si un `OnModelLoaded` arrive après coup. **Fiabilité** :
  aucun appel ne lève d'erreur pour un identifiant faux ; `GetModelFileID` peut rester vide le temps
  qu'une créature absente du cache soit demandée au serveur (d'où la relance), et ne dit rien d'un
  modèle chargé mais mal texturé ; `OnModelLoaded` n'est pas documenté pour ce client (posé par `pcall`).
  `/slay modeles` ouvre la galerie (ennemis puis personnages, identifiants essayés et état sous chacun)
  et écrit au chat, après les essais : « modèles : N/M chargés », une ligne par modèle absent
  (« sorcerer : créature 619, affichage 2329, affichage 2330 -> aucun modèle »), puis les modèles
  chargés seulement par un affichage de repli. Les autres `npc` des rencontres n'ont pas d'entrée et
  n'affichent rien : ajouter `Art.npcs.<npc> = { creature = id, display = id }` (cache du client).
- Les **animations** des modèles (0 attente, 1 mort, 6 à terre, 9 encaisser, 16 frapper, 25 prêt, 53/54
  sorts), l'orientation (`/slay facing`) et le cadrage des modèles dans leur cadre (pieds au sol ?).
- La **peau** : chargement des TGA de `Media/` (aplat vert = fichier absent ou mal lu), des masques TGA
  (icônes rondes, carrées arrondies, ouverture du médaillon), de la police Baloo Chettan 2 (sinon Friz
  Quadrata) ; netteté des cartes au survol ; matières répétées sans couture (`"REPEAT"`) ; rognage de la fenêtre (`SetClipsChildren`) sans effet de bord (la carte
  qu'on glisse hors de la fenêtre disparaît : voulu).
- Le zoom des survols (mode `net` : animation Scale + textes Vertex pendant le mouvement, échelle réelle
  posée à l'arrivée) : fluidité, textes immobiles pendant l'agrandissement, aucun sursaut ni clignotement à
  l'arrivée (moment de la bascule), texte net une fois agrandi ; `/slay zoom` pour comparer avec `lisse`. Le décalage des cartes de récompense (`SetScale` + `SetPoint` divisé par l'échelle) : calculé.
- Le **sablier** dans le texte des cartes (séquence |T à 14 champs) : affiché, blanc, net à 10 px, à
  la hauteur des chiffres et **centré verticalement** sur la ligne (supposé : aucune source ne dit où le
  client place une icône en ligne ; décalage y possible dans la séquence), non déformé par le rognage
  28/32, et sa largeur bien comptée par `GetStringWidth` (sinon une ligne recoupée par le client le
  montrerait). Avec la police de repli (Friz Quadrata), le texte reste juste mais plus large.
- La mise en page des textes de carte : mesurée par le client (`GetStringWidth`, `GetStringHeight`,
  `GetNumLines`, `IsTruncated`) ; hors jeu, seules les métriques du faux client (Baloo Chettan 2, ligne
  de 1,47 cadratin) la vérifient.

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
lua5.1 Sim/ui_harness.lua [graine] [dossier]   # ou luajit ; doit finir par ALL PASS (527 vérifications, graine 1)
lua5.1 Sim/ui_harness.lua 1 build/snap         # + instantanés SVG des écrans dans build/snap
                                               #   (aperçus de Media copiés dans build/snap/media)
for f in build/snap/*.svg; do rsvg-convert "$f" -o "${f%.svg}.png"; done
```

Il charge tous les fichiers du TOC avec un faux client (cadres enregistreurs, horloge virtuelle,
événements, infobulle, modèles, sons), refuse les modèles XML et événements inconnus et signale toute
méthode d'API inconnue. Scénario : accueil, options, clé verrouillée ; **expédition complète de l'acte 1
jouée par clics** (combats par le bot heuristique à travers l'interface, à la souris seulement : clics carte puis cible,
ennemi retenu puis double clic, clic dans le décor, glisser-déposer ; récompenses (coffre ouvert d'abord s'il se présente), amélioration, retrait, achats) ; la file d'animations est
vidée (`H.settle`) avant de vérifier le bandeau de fin ; aller-retour de sauvegarde en combat et sur une
récompense ; bilan, méta, nouvelle expédition à la clé +1 ; potions et bibelots ; marchand ; feu de camp ;
rencontre ; bibelot de classe ; abandon ; vol ; sauvegardes anciennes, abîmées ou futures ; art manquant
et `/slay art` ; modèles (essais créature puis affichages, médaillon de repli, relance tardive,
`OnModelLoaded`, lignes de `/slay modeles`) ; noms des ennemis (1 à 6 ennemis × échelles 0,6 / 1 / 1,5 :
visibles, dans le contenu, au-dessus du plateau, au-dessus du modèle et de la jauge, rien par-dessus) ; décors (fond embarqué par défaut pour chaque scène,
TGA présent sur disque en 32 bits et puissances de deux, bande au format du décor, teinte ; essai : suivant,
précédent, ok, non, peint, illustre ; repli sur le premier validé d'une liste sans fond embarqué ; verdicts
relus au rechargement ; rapport avec les fonds embarqués) ; survols (zone fixe, valeur
intermédiaire, sortie réversible depuis la valeur courante, état final par les minuteurs, pilote coupé
au repos, voisines, premier plan, ennemi visé) ; panneau des cartes (tri, compteur, molette, Échap
qui ferme la fenêtre avec lui, clic dehors, Fermer, pioche triée et ordre réel intact, défausse, consumées,
deck en combat, touches sans effet) ; **clavier laissé au jeu** (UK : sources de `UI/` sans capture
ni nom de touche, aucun cadre qui capte le clavier, 52 touches sans effet sur 11 vues, Échap par
`UISpecialFrames` avec options et panneau ouverts, aucun texte ni infobulle qui nomme une touche ou un
raccourci, Maj au jeu d'une carte Spend) ; **peau** (U20 : chaque texture de `SkinData` présente dans `Media/`, TGA 32 bits non
compressé à origine en bas, dimensions en puissances de deux identiques à `SkinData`, coordonnées de la
zone utile cohérentes ; pièces attendues présentes ; icônes de `SkinData` présentes et toutes celles que
nomme `Art.lua` copiées ; polices présentes ; carte composée : corps par couleur — ivoire, violet, bleu,
or —, ruban, coût, panneau, icône améliorée masquée, gemme, plaque du bas, nom horizontal, carte grisée
et sa raison, amélioration en vert, `/slay ruban` retiré ; repli sur l'icône du jeu quand le fichier manque ;
bulle d'intention ; mana) ; **textes des cartes** (U22 : les 34 cartes, de base et améliorées, jouables
et injouables avec leur plaque de raison : chaque ligne posée, marges comprises, sur les pixels sombres
de `Media/card_panel.tga` et hors de la gemme, au-dessus des plaques ; nom dans la bande opaque de
`Media/card_ribbon.tga` ; aucune recoupe par le client ; répartition par palier et cartes sous le
plancher affichées, au moins deux tiers à 8,5 ou plus, relevé carte par carte avec `SLAY_TIERS=fichier` ; textes d'une carte fraîche visibles ; polices reposées à l'ouverture) ; zoom net (U18 : animation Scale en route, échelle réelle 1 ; à l'arrivée échelle réelle = échelle de survol et aucune animation, bascule dans le même pas sans saut ; sortie depuis l'échelle réelle, facteur 1 au départ ; réversible en route et au pas de la bascule ; mise en page des textes identique au repos, pendant et après ; témoin : sans `SetSmoothScaling`, le faux client arrondit la hauteur de police à l'échelle réelle et les largeurs changent ; vol de carte posé net ; cycle `/slay zoom`, ancienne valeur `anim`) ; zoom fluide et saut du mode net (U26 : sauvegarde ; repos identique au net à ±0,01 sur 99 régions ; survol sans `SetScale`, arrivée identique au net ; sortie ; cible changée en route ; fenêtre cachée puis remontrée ; carte jamais montrée ; plaques créées après l'armement ; vols ; écrans construits en fluide sans région née sous une animation ; aucun cadre enfant dessiné sous un visuel ; bascule du mode net sans déplacement ajouté ; carte survolée de la main dans la fenêtre à toutes les places ; noms abrégés) ; premier survol (U23 : carte, carte injouable, bouton doré, bouton rond, objet et carte du marchand, service, couchage, plaque de réponse, étape du parcours — halo éteint avant, borné et parti de 0 à la première image, aucune région créée pendant une animation d'échelle sur tout le harnais, toutes les pièces dans le visuel animé avec la même échelle effective une fois arrivé) ; plaque du bas (U22 : zone utile vérifiée sur les pixels de `card_plate.tga`, toutes les cartes et combinaisons réelles plus un cas extrême, plaque visible devant le corps ; raisons d'une carte injouable dans leur plaque) ; plaques de réponse (U24 : toutes les réponses de `Data/Events.lua`, possibles et impossibles) ; mots-clés (U25 : une ligne de 60 caractères au plus) ; **langage des cartes** (U27 : chaque état posé
par les effets a sa ligne « Donne » (soi) / « Applique » (ennemi, « à tous ») avec nom et nombre exacts, en
dernier, sans point, sablier seulement pour une durée, jamais « N tour(s) » ni « Inflige » pour un état,
textes impersonnels, libellés « Nom : » connus ; Exécution, Déferlement, Dernier souffle et Ombre
exactement sur les cartes qui en ont la règle, chiffres d'Exécution et de Déferlement justes ; mise en
page : ligne d'état en début de ligne et en dernier, une clause par ligne en mode « clauses », essais
dans l'ordre, sablier posé en séquence |T autant de fois que dans la source et compté dans la mesure,
séquence à 14 champs entiers, `Media/hourglass.tga` 32 × 32 blanc ; couleurs : or pour les seuls noms
d'états et conditions, blanc / vert pour les chiffres ; infobulle de chaque carte : une explication par
mot-clé, état, condition et sablier employés, 60 caractères au plus ; jeton et infobulle des Pouvoirs
joués) ; **habillage WoW** (U30 : chaque pièce de `UI/WowSkin.lua` en TGA 32 bits non compressé à origine
en bas, puissances de deux, coordonnées = pièce / toile, pièce répétée qui remplit sa toile, aucun fichier
orphelin dans `Media/WowUI` ; pièces nommées dans `UI/` connues, aucune référence ni fichier des textures
retirées, aucun `SetAtlas`, chemins `Interface\` du client seulement dans la liste permise ; à l'exécution,
textures de la fenêtre = fichiers de l'addon présents sur disque, icônes ou texture blanche ; pièces entières
jamais agrandies au-delà de leurs pixels à l'échelle 115 % (combat, options, marchand, parcours, rencontre,
feu de camp) ; libellés des boutons entre leurs bouts, nom et PV du héros dans leurs logements, PV des
ennemis dans leur barre ; aucun cadre enfant dessiné sous un visuel survolable) ; **ordre de dessin et silhouette** (U31 : règle du faux client — un cadre rogneur dessine son sous-arbre à son niveau, `R.drawKey` dans `Sim/ui_render.lua`, que les aperçus SVG appliquent aussi, avec le rognage — ; chaque élément du bandeau au-dessus de la barre de titre et filets au-dessus du contenu (combat, récompense, parcours, rencontre) ; message passager devant les options et le panneau du deck ; butin en vol sur la couche du dessus puis rendu à son écran ; rien du contenu, du fond ni du bandeau sur un pixel extérieur des pièces du cadre métal, contenu bord à bord avec la partie opaque des filets ; dialogues et parchemins de même ; cases d'icônes : icône = ouverture du cadre mesurée sur les pixels à ±1, fond dans le cadre). U21 contrôle les cadres
compacts des ennemis (nom dans son logement, barre dans le cadre, jamais sur le bandeau ni sous le modèle,
sans chevauchement, 1 à 6 ennemis × 3 échelles), U24 les réponses (libellé d'une ligne dans le bouton, texte
dessous dans la place restante). Le faux client mesure les textes avec les
avances des glyphes de Baloo Chettan 2 (`Sim/baloo_metrics.lua`), une ligne de 1,47 cadratin (hhea),
retours explicites puis par mots, icônes |T comptées à leur largeur, et simule les animations Scale. Il gère aussi `OnSizeChanged`, `GetChildren`, `IsObjectLoaded`
(fichiers `H.unloaded` jamais chargés) et `C_Texture`. Graine 1 : ALL PASS sous lua5.1 et luajit.

`Sim/ui_render.lua` résout ancres, tailles, échelles, couleurs, disques, rotations et textes des cadres du
faux client et écrit un SVG par écran (accueil, parcours, parcours en route, combat, combat-survol, combat
avec élite et boss, options, récompense, marchand, feu de camp, amélioration, rencontre, bibelot de classe,
bilan, méta, panneau du deck, pioche en combat). Une pièce d'atlas (coordonnées dans l'image) est dessinée
par une vue recadrée de l'image, une matière répétée par un motif. Les
textures de `Media/` y sont dessinées (aperçus PNG : coordonnées de texture, couleur de sommet,
désaturation, masques approchés, rotation), les textes en Baloo Chettan 2 avec ombre et couleurs ; icônes
du jeu = carrés bleus, modèles = silhouettes en pointillés, illustrations = aplats ; textes mesurés comme
le faux client, icônes |T de `Media/` posées dans la ligne (centrées sur la hauteur de ligne : supposé) ;
planche `cartes.svg` (textes longs, injouable, mot-clé, noms longs) et `cartes_mots_cles.svg` (toutes les
cartes, base et améliorée). Comparé aux planches (`combat_pack.jpg`…) pour cette peau ; il ne remplace pas un essai.

## Tests en vol (pour toi)

Préparation : copier le dossier dans `/mnt/Games/World of Warcraft/_forever_/Interface/AddOns/SlayTheDragon`
(commande `rsync` dans `CLAUDE.md`). **Nouveau fichier dans le TOC (`UI\SkinData.lua`) et nouveau dossier
`Media/` : relancer le client** (`/reload` ne suffit pas). Activer les erreurs Lua
(`/console scriptErrors 1`) ou BugSack.

Avant tout (textes tronqués au survol, 12/11/2026 ; `/reload` suffit) : en zoom net (défaut), fenêtre à
115 % puis à 100 % et 150 %, survoler lentement chaque carte de la main (et en récompense, au marchand,
dans le deck) : **aucun texte ne finit par « … »** (texte du panneau, nom du ruban, plaque du bas, raison en
rouge) ; « PW: Radiance » montre ses deux lignes, au repos comme agrandie ; idem en `/slay zoom fluid` et
`/slay zoom smooth`. Réponses des rencontres : libellé et texte dessous entiers, texte toujours juste sous le
bouton (pas décalé vers le bas). Puis **`/slay text`** : « no truncated text found so far » attendu ; sinon
recopier la liste (chaque ligne donne la carte, le texte, la taille, l'échelle et le mode de zoom ; la carte
a déjà été reposée un palier plus bas). Dire si certaines cartes paraissent plus petites qu'avant (marge de
2 % : 15 cartes perdent un demi-palier).

En tout premier (habillage WoW, 11/11/2026 ; nouveau fichier `UI\WowSkin.lua` : relancer le client) :
1. **Chargement** : aucun aplat vert ni carré noir sur le cadre de la fenêtre (filets, barre de titre), le
   bandeau (cases, bouton Menu, fermeture), les boutons rouges, les cadres d'unité, les cases, le parchemin
   et les étapes du parcours, les dialogues (options, accueil, grille, panneau des cartes, bilan).
2. **Cadre** : barre de titre continue derrière le bandeau, filets gauche, droit et bas sur le bord de la
   fenêtre, sans couture entre coins et bords répétés ; table du bas sans couture.
3. **Combat** : portrait du personnage dans l'anneau du cadre du héros (sinon icône de classe) ; barres de
   vie vertes qui se vident, Absorption bleue dans le logement bas ; cadres des ennemis au-dessus des
   têtes, dragon d'or des élites et du boss ; anneau de mana ; cases de pioche et défausse ; « End Turn ».
4. **Parcours** : traits de taxi bien orientés d'une étape à l'autre (rotation), botte ailée sur la
   position, ruban du boss lisible.
5. **Lisibilité** : or sur métal, encre sur parchemin, PV blancs sur les barres, chiffres des intentions ;
   rien de flou (sinon dire quelle pièce).
6. **Survols** : liseré d'or des boutons rouges et des réponses, cadre doré des cases ; options : cases à
   cocher, curseurs (glisser la poignée, cliquer sur le rail, flèches).

Ensuite (peau « Mechanized Magic », cartes) :
1. **Chargement des textures** : aucun aplat vert ni carré noir sur les cartes, le bandeau, le plateau, les
   boutons, les hexagones (PV, Absorption, mana, Démence, clé), les médaillons et le parcours. Sinon dire
   lesquels (une capture suffit).
2. **Police** : Baloo Chettan 2 partout (lettres rondes, accents corrects) ; si tout est en Friz Quadrata,
   la police ne se charge pas.
3. **Cartes** : nettes au repos et au survol (×1,16 en main, ×1,17 en récompense) ; texte plus grand (le plus grand palier qui tient : 10 sur les textes courts) et noms « MdP : … » / « MdlO : … » ; icône ronde bien dans
   l'anneau ; nom horizontal centré sur le ruban, jamais hors de la bande ; texte du panneau centré, avec
   de l'air tout autour (côtés, haut sous la gemme, bas biseauté) même sur Forme d'ombre, Pénitence,
   Esprit de rédemption, chiffres blancs (verts une fois
   améliorés) ; gemme verte / bleue sur les peu communes / rares ; « Recharge N », « Incantation »,
   « Consumée », « Pouvoir » dans la plaque sous la carte, plaque bien visible (ardoise et liseré entiers
   sous le corps, comme « Recharge 1 » sur la planche), texte jamais plus large qu'elle (Soins supérieurs :
   « Incantation · Consumée » sur une plaque élargie) ; carte injouable grisée avec sa raison en rouge,
   toujours dans sa plaque (« Une incantation est déjà en cours. » sur deux lignes).
4. **Plaques** : ardoise sans couture visible (bandeau, plateau, plaques de réponse, bulles d'intention,
   options), liseré d'argent régulier aux coins ; bulles ivoire (rencontre, parcours) ; survol doré des
   plaques de réponse et du feu de camp ; pilule dorée « Fin du tour » / « Reprendre la route ».
5. **Bords** : rien ne dépasse de la fenêtre (piles en bas à gauche, plaque du bas des cartes de la main,
   tas du deck).

Ensuite (retours du premier essai) :
1. **Fonds embarqués** (rien à faire : relancer le client, nouveaux fichiers) : l'accueil montre-t-il la
   forêt d'Elwynn peinte (pas d'aplat vert ni noir) ? Recopier `/slay art` (fonds embarqués et scènes).
2. **Paysages** : sur la route, la ferme, le feu de camp, le marchand, la côte et le boss, l'illustration
   a-t-elle du sens derrière les personnages (bien cadrée, personnages lisibles) ? Sinon dire laquelle et
   ce qui cloche (trop haut / trop bas / trop clair) ; `/slay decor peint` revient au décor peint.
3. **Survols** : passer lentement puis vite sur les cartes de la main : la carte se lève et grossit en
   ~0,1 s **sans que le nom, le coût ni le texte tressautent ou changent de coupure**, **d'un seul bloc**
   (ruban, languette de coût, plaque du bas et halo grossissent avec le corps, pendant le mouvement comme
   à l'arrivée) ; **une fois agrandie, le texte est net** (aussi net qu'au repos, pas baveux) et **rien ne
   saute ni ne clignote au moment où elle arrive** (bascule vers la vraie taille) ; comparer avec
   `/slay zoom fluide` (taille animée sans redessiner les textes : rien ne doit sauter à l'arrivée ; texte
   au repos aussi net qu'en net ?), `/slay zoom lisse`, puis `/slay zoom net` ; en net, `/slay zoom lent`
   (ralenti ×8) et dire quels éléments sautent encore à l'arrivée (texte seul ? textures ? une pièce
   précise ?) et s'ils grossissent pendant le mouvement ; dire quel mode garder et si les images par
   seconde baissent en fluide (animation tenue sur chaque élément survolable) ; **premier survol** de chaque
   élément après un `/reload` (plaques de réponse d'une rencontre, boutons, butin) : aucun aplat doré
   sur l'écran ; les voisines s'écartent un peu, elle passe devant ; ressortir en cours de route la fait
   redescendre sans à-coup ; aucun clignotement en bord de carte ; on peut monter le curseur sur la
   partie levée sans la perdre. Idem : cartes de récompense / marchand / grilles, boutons (dont « Fin du
   tour », ≡, ×), butin au sol, couchage et grimoire, étapes du parcours, plaques de réponse, fioles et
   bibelots du bandeau, tas du deck, pioche, défausse.
4. **Visée** : armer une carte à cible (ou une potion à cible) puis survoler les ennemis : l'ennemi
   survolé grandit un peu depuis ses pieds, son anneau s'allume ; le clic vise toujours le bon ennemi.
5. **Panneau des cartes** : hors combat, clic sur le tas du deck (plateau) et sur le deck du bandeau ;
   en combat, clic sur la pioche (triée par type, coût, nom — pas l'ordre de tirage), la défausse, le tas
   violet des consumées (après une carte Consumée) et le deck du bandeau. Molette si le deck dépasse 24 cartes ;
   fermeture par clic hors du panneau, « Fermer » (Échap ferme toute la fenêtre). Cartes améliorées en vert.
6. **Bandeau** : en combat et sur la récompense, « Marche de l'Ouest » en haut au centre, points de
   progression en dessous, sans chevauchement, même avec 6 bibelots et une clé.
7. **Langage des cartes** : mots-clés en or (Expiation, Douleur, Exécution, Déferlement…), chiffres
   blancs, lignes « Donne … » / « Applique … » en dernier ; sablier ⌛ visible après le nombre des durées
   (Radiance, Schisme, Cri psychique, Châtier), aligné sur les chiffres ; Schisme lisible (palier 7) ;
   survol d'une carte : une ligne par mot-clé ; Forme d'ombre jouée : jeton sous le héros, effet au survol.
8. **Textes** : plus de tutoiement dans l'interface (bulles, raisons grisées, bilan, infobulles des
   intentions et des mots-clés). Les textes des cartes et des rencontres viennent de `Data/` (autre piste).

Ensuite, la liste habituelle : `/reload` en combat et sur une récompense (même état), potions (boire, à
cible, jeter), clavier fenêtre ouverte (Entrée ouvre le chat, Espace saute, les chiffres lancent les
barres d'action, Échap ferme la fenêtre ; rien ne se passe dans l'addon),
ouverture au décollage et fermeture à l'atterrissage, masquage en combat réel, `/slay modeles`
(recopier ses lignes du chat), `/slay facing`.

À me renvoyer : la sortie de `/slay art`, une capture du combat avec une carte survolée, du panneau de
la pioche, du bandeau, de chaque décor illustré, et toute erreur Lua (texte complet).
