# Interface en jeu (pistes C, D, E, survols et peau « Mechanized Magic »)

État au 10/11/2026. Premier essai en jeu fait par le joueur (disposition validée) ; les retours de cet
essai sont traités dans « Retours du premier essai » ci-dessous. Depuis, l'habillage « bois et
parchemin » dessiné en code est remplacé par les pièces du pack CC0 « Mechanized Magic » (Dumivid),
d'après les planches validées (`docs/maquette/combat_pack.jpg`, `ecran_*.jpg`, `psd.jpg`) : voir « Peau ».
Vérifié hors jeu par `Sim/ui_harness.lua` (logique, clics, animations en temps virtuel, cohérence de la
peau) et par des instantanés des écrans (`Sim/ui_render.lua`, qui dessine désormais les textures de
`Media/`). La section « Tests en vol » liste ce qu'il reste à voir en jeu.

## Peau « Mechanized Magic »

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
  texte, aplatie puis rendue raccordable par fondu avec sa copie décalée : pas de symétrie visible) et
  ivoire (intérieur du corps ivoire), coins de remplissage arrondis (ardoise, ivoire, pilule), liseré
  d'argent à neuf tranches (filet sombre, argent en dégradé, filet sombre), lueurs (halo de carte =
  silhouette du corps floutée, halo rond, halo de plaque), pilule dorée du bouton principal (trois
  tranches), pointes de bulle, masques (disque, carré arrondi).
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
  textures ancrées, coins de N unités, suivent la taille de l'hôte), `W.plaque` (coins de matière +
  deux bandes de matière carrelée à l'échelle + reflet + liseré d'argent ; `SetFill`, `SetRim`,
  `SetGlow`), `W.goldPill`, `W.hex` / `W.setHex`, `W.medallion`, `W.tokenRow` (jetons d'état),
  `W.cardBack`, `W.panel` (ardoise ou ivoire). Polices : `W.label(parent, "body" | "bold" | "heavy", …)`,
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

### Écrans (d'après les planches)

- Fenêtre : ardoise sombre, liseré d'argent par-dessus, **contenu rogné à la fenêtre**
  (`SetClipsChildren`) : rien ne peut déborder. Bandeau d'ardoise : classe ; PV (hexagone rouge,
  « /max ») ; or (pièce) ; deck (dos de carte + nombre, clic = panneau du deck) ; zone et points de
  progression sur un filet (boss = hexagone rouge) ; clé (hexagone violet « +N »), bibelots, fioles
  (cases d'ardoise), ≡, × (rond rougi). Plateau d'ardoise carrelée sous un filet sombre / argent / sombre.
- Combat : barre d'incantation (plaque, médaillon du sort, jauge dorée), jauges de vie à hexagone rouge,
  Absorption en hexagone d'acier, jetons d'état en médaillons, bulles d'intention (pilule au liseré
  rouge / bleu / violet / vert, pointe), mana en grand hexagone bleu « 2/3 » + un petit hexagone par
  point, Démence en hexagone violet (cachée à 0), pioche / défausse / consumées en dos de carte (bas à
  y 595 < 614), recharges en cases d'ardoise (icône grisée, tours), « Fin du tour » doré. La main
  remonte de 10 (haut des cartes à 418) pour que la plaque du bas reste dans la fenêtre.
- Récompense : cartes ×1,08 (x 407 / 552 / 697), butin en cases d'ardoise (bourse avec son montant),
  « Une carte au choix, ou aucune. », « Reprendre la route » doré. Rencontre : bulle ivoire à pointe,
  plaques de réponse 320 × 118 (gain en vert), survol = liseré doré + halo. Parcours : feuille ivoire,
  médaillons argentés (halo blanc = accessible, doré = position, rouge = boss), franchies estompées avec
  un petit hexagone vert, pointillés (parcouru brun doré, départs possibles sombres). Marchand : rangée
  de cartes ×0,92 à prix en pastille, « Bibelots », « Potions », « Service » (plaque « Retirer une
  carte » et son prix), or au centre du plateau. Feu de camp : couchage et grimoire en médaillons au sol,
  leurs plaques « Se reposer / +N PV » et « S'entraîner / Améliore une carte » sur le plateau (la plaque
  et le médaillon s'allument ensemble). Accueil, bilan, méta, grilles, panneau du deck, options : panneaux
  d'ardoise, clés en hexagones violets (verrouillées : hexagones vides), boutons d'ardoise, action
  principale dorée.

### Écarts volontaires aux planches

- Feu de camp : un bouton d'ardoise « Reprendre la route » en plus (repartir sans rien faire reste
  possible, règle du moteur) ; la planche n'en montre pas.
- Main : 10 unités plus haut que sur la planche (la plaque du bas sortait de la fenêtre).
- Grilles et panneau du deck : cartes ×0,75 / ×0,72 et rangées plus espacées (la languette de coût et la
  plaque du bas débordent du corps).
- Rencontre : la pointe de la bulle part du bas à droite (vers le personnage) ; sans personnage, pas de
  pointe. Bulle d'un événement « rare » / « histoire » : liseré doré / violet.
- Valeurs en évidence par la couleur (blanc, vert à l'amélioration) et non en gras (une chaîne de texte
  WoW n'a qu'une police).

## Texte des cartes et zoom (retours du deuxième essai)

- **Zone utile du texte** (`W.CARD_TEXT`, `UI/Widgets.lua`) : intérieur sombre du panneau d'ardoise
  (mesuré sur `Media/card_panel.tga`) moins les marges : 5,5 unités sur les côtés (de 124), 5 unités au
  bas, et sous la plus grande gemme de rareté en haut ; le bas biseauté rétrécit la zone (demi-largeur
  0,308 − 0,56 × (y − 1,0754), marge ×1,15 en biais). Les lignes sont posées une à une : remplissage
  glouton, chaque ligne limitée à la largeur de la zone à son bas, bloc centré verticalement ; puis le
  texte est posé avec des retours explicites et une largeur un peu plus grande que la plus longue ligne
  possible (le client ne recoupe jamais autrement, ni à une autre échelle, ni pendant un zoom).
  Mesures par le client : `GetStringWidth` / `GetStringHeight` d'un texte de mesure (même police), puis
  vérification sur la carte (`GetNumLines`, `IsTruncated`, `GetStringHeight`) — un échec fait descendre
  d'un palier. Mises en page gardées en cache (texte, taille, bas de zone).
- **Paliers** : texte 8 / 7,5 / 7 (plancher lisible), secours 6,5 / 6 signalé (`card.bodyFit.under`) ;
  nom 10 / 8,5 / 7, secours 6,5 / 6 (`card.nameFit`), une ligne dans la bande du ruban moins 4 unités de
  chaque côté. Répartition (harnais U22, métriques de Baloo Chettan 2) : texte 8 → 55 cartes (base et
  améliorées comptées à part, 68 en tout), 7,5 → 5, 7 → 6, sous le plancher : Esprit de rédemption (et +)
  à 6 ; nom 10 → 42, 8,5 → 10, 7 → 12, sous le plancher (6,5) : Suppression de la douleur+, Mot de
  pouvoir : Radiance+, Mot de pouvoir : Réconfort et Réconfort+. Textes à raccourcir côté `Data/`.
- **Plaque de raison** (carte injouable) : descendue à cheval sur le bas du panneau (centre à 1,24 de la
  largeur du corps), sous la zone du texte ; la zone remonterait si elle y mordait.
- **Zoom sans tressautement** : avant, le survol changeait l'échelle réelle du visuel à chaque image ;
  le client recalculait la taille de police effective (arrondie) et les retours à la ligne à chaque pas.
  Désormais (mode `anim`, défaut) l'échelle passe par une animation `Scale` d'un `AnimationGroup` posé
  sur le visuel `face` (transformation purement visuelle), et chaque texte de l'interface est en
  `SetScaleAnimationMode(Enum.FontStringScaleAnimationMode.Vertex)` : sommets mis à l'échelle, mise en
  page figée — la technique de `Blizzard_EncounterWarnings` (`scaleAnimationMode="Vertex"` sous une
  animation Scale). L'échelle d'arrivée est tenue par un long délai de fin (`SetEndDelay`) : l'échelle
  réelle reste 1, aucune mise en page à l'arrivée ; une cible qui change en route (souris qui ressort)
  relance l'animation depuis l'échelle visuelle courante (`GetSmoothProgress`). La position (levée,
  écart des voisines) reste pilotée par l'`OnUpdate` partagé ; la zone de survol ne bouge pas. Vaut pour
  tout `W.hoverable` : main, récompense, marchand, grilles, plaques de réponse, boutons, objets ; et aux
  vols de cartes (`W.fly` : échelle réelle fixée au départ, animation Scale `IN_OUT`, échelle réelle
  d'arrivée posée une fois à la fin).
  Contrepartie : une fois agrandi, le texte est un rendu étiré (un peu moins net qu'un texte rendu à sa
  taille). `/slay zoom` bascule sur `lisse` (échelle réelle à chaque image, comme avant, mais textes en
  `SetSmoothScaling` : hauteur de police non arrondie, comme les barres d'info de Blizzard) ;
  `/slay zoom anim` revient au défaut ; option persistée `zoom`.
- **Textes vides jusqu'au survol** : une police d'addon chargée de façon asynchrone ne dessine rien pour
  un texte posé avant son arrivée, jusqu'à la prochaine mise en page — que provoquait justement le
  `SetScale` du survol. Le préchargement était sur un cadre transparent hors écran (sans doute jamais
  dessiné, donc rien chargé) : il est maintenant à l'écran, presque transparent ; et à chaque ouverture
  de la fenêtre (0,1 s après, et 1 s après la première), `W.refreshFonts` repose police et texte de tous
  les textes créés par `W.label` / `W.text` puis refait la mise en page des cartes.

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
    cible clavier — grandit ×1,07 depuis ses pieds et son anneau s'allume ; la zone de clic (emplacement)
    ne bouge pas.
  - Infobulles conservées (le survol animé est ajouté dans `W.tooltip`).
- **Consulter ses cartes** (`UI.deckView`, fin de `UI/Screens.lua`) : panneau de bois par-dessus
  l'écran (sous le bandeau), titre court « Deck · 18 cartes » / « Pioche · … » / « Défausse · … » /
  « Consumées · … », grille de vraies cartes (`W.card`, 8 par rangée, 3 rangées visibles, ×0,72),
  triées par type (Sort offensif, Sort, Pouvoir), coût, nom (puis non améliorée avant améliorée) ;
  améliorées en vert comme ailleurs. Molette : une rangée par cran (indicateur à droite si ça déborde).
  Fermeture : `Échap` (après les options), clic hors du panneau (voile), clic droit sur une carte,
  « Fermer », ou nouveau clic sur ce qui l'a ouvert. Panneau ouvert : les touches ne vont pas à
  l'écran dessous (rendues au jeu). Accès : tas du deck du plateau (récompense, feu de camp, marchand,
  grilles) et deck du bandeau (dos de carte et nombre), désormais **aussi en combat** (deck complet) ; en combat,
  clic sur la pioche (**toujours triée**, jamais l'ordre de tirage), la défausse, et le nouveau tas
  violet des **consumées** (x 151–187, affiché dès qu'il y en a une).
- **Paysages** : voir « Diagnostic des paysages » plus bas. Chaque décor a une liste ordonnée de
  candidats (`Art.illustrations`). Depuis le deuxième essai (aplat **vert** = fichier absent, que la
  détection automatique disait présent), le décor est **peint par défaut** ; un décor n'affiche que le
  premier candidat de sa liste **validé à l'œil** par le joueur (« Essai des décors » ci-dessous).
- **Bandeau** : le nom de zone est sur la ligne du haut, les points de progression centrés sur la ligne
  du bas ; le cadre central va de l'or au premier élément de droite (bouton Deck) et un nom trop long
  est tronqué. Plus aucun chevauchement possible.
- **Vouvoiement** : plus de « tu / te / ton / ta / tes / toi / t' » ni d'impératif familier dans les
  chaînes de `UI/` (raisons, bilan, étapes, infobulles, mots-clés) : tournures impersonnelles, « votre »
  si la phrase s'adresse au joueur (« Ce n'est pas votre tour. »). Les textes de `Core/` et `Data/`
  (cartes, rencontres, raisons du moteur) relèvent de l'autre piste.

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
  (y 424–614), personnages posés au sol avec ombre. Le décor est une illustration du jeu recadrée et
  teintée, avec dessous un décor **peint** en couches unies (champs, ferme, côte, mine, nuit), seul visible
  tant qu'aucun candidat n'est validé ; `/slay decor` (ou Options → « Décor illustré ») bascule de l'un à
  l'autre.
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
| `UI/SkinData.lua` | GÉNÉRÉ par `tools/build_media.py` : textures de `Media/` (fichier, toile, zone utile, coordonnées), géométrie de la carte, icônes copiées, polices | non |
| `UI/Art.lua` | Palette, textures, décors (`Art.scenes`), personnages de rencontre (`Art.npcs`), sons, icônes (cartes, états, intentions, affixes, bibelots, potions, parcours ; champ `tga` = icône améliorée), couleur du corps des cartes, gemmes, teintes des liserés, mots-clés, animations | non |
| `UI/Persist.lua` | Chargement de `SlayTheDragonDB` par `Save.migrate`, options de l'interface (`db.options`, dont `decor` et `artChecks`) | non |
| `UI/Controller.lua` | Couche mince écrans ↔ `Core/Expedition` (étapes génériques, combat, potions, fin, validation, décor de l'étape, mana max, nom du boss) | non |
| `UI/Widgets.lua` | Peau (textures de `Media/`, neuf tranches, plaques, hexagones, médaillons, pilule dorée), polices, sons, pilote d'animations (interpolations, canaux animés), survols (zone fixe + visuel `face`), icônes (améliorées d'abord), carte unique composée, jauges de vie, hexagone d'Absorption, jetons d'état, boutons, infobulles, textes flottants, modèles | oui |
| `UI/Scene.lua` | Décor (peint par défaut, illustration validée par l'essai manuel, mode essai, rapport `/slay art`), plateau, personnages (modèle, ombre, anneau de cible) | oui |
| `UI/Main.lua` | Fenêtre, bandeau, écrans, clavier, options, `/slay`, bouton de minimap | oui |
| `UI/CombatView.lua` | Écran de combat et ses animations | oui |
| `UI/Screens.lua` | Accueil, rencontre, feu de camp, récompense (et coffre), grille du deck, marchand, parcours, bilan et méta, panneau de consultation des cartes (`UI.deckView`) | oui |
| `UI/Flight.lua` | Événements : chargement, vol en taxi, combat réel, déconnexion | oui |
| `Sim/ui_harness.lua` | Harnais hors jeu (faux client WoW) | — |
| `Sim/ui_render.lua` | Rendu SVG des cadres du faux client (instantanés d'écrans, textures de `Media/` comprises) | — |
| `tools/build_media.py` | Fabrication de `Media/` et de `UI/SkinData.lua` (hors TOC, non déployé) | — |

`UI\Scene.lua` a été ajouté au TOC par la piste E (client relancé depuis) ; la peau ajoute
**`UI\SkinData.lua`** (avant `UI\Art.lua`) et le dossier `Media/` : **relancer le client** au prochain essai.
Les fichiers qui touchent l'API WoW commencent par `if not CreateFrame then return end` ; `Sim/load.lua`
saute de toute façon les lignes `UI\` du TOC. **Aucune règle de jeu dans `UI/`**.

## Écrans

Coordonnées : celles des maquettes, depuis le coin haut gauche de la zone intérieure (1034 × 614).

**Bandeau** (y 0–44, sur tous les écrans ; on le saisit pour déplacer la fenêtre) : à gauche la classe,
les PV (hexagone rouge, « /max »), l'or (pièce), le deck (dos de carte et nombre ; partout, combat
compris ; infobulle = contenu du deck ; clic = panneau du deck) ; au centre la zone (« Acte 1 · Marche de
l'Ouest » sur la carte), sur la ligne du haut, et ailleurs la progression de l'acte sur la ligne du bas
(points dorés franchis, point clair = étape en cours, hexagone rouge = boss) ; à droite la clé mythique
(hexagone violet « +N », infobulle = affixes), les bibelots (cases liserées à la rareté), séparateur,
3 fioles (potions), ≡ (options), × (fermer).

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
  clavier pendant une visée) ; sous les pieds, dans un cadre d'infos au-dessus du personnage (aucun
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

- Souris : clic sur une carte (elle se lève), puis clic sur l'ennemi ; une carte sans cible se joue par un
  second clic ou un clic dans le décor. Glisser-déposer : sur l'ennemi, ou n'importe où dans le décor pour
  une carte sans cible. Clic droit : désélectionner.
- Clavier (capté seulement fenêtre ouverte, `SetPropagateKeyboardInput`) : `1`…`0` choisit une carte
  (même touche ou `Entrée` pour la jouer), `Tab` change de cible (`Maj+Tab` à rebours), `Espace` finit le
  tour (et « Continuer » après un combat), `Échap` ferme (les options d'abord, puis le panneau des
  cartes, puis la fenêtre). Ailleurs, `1`…`0` choisit
  (parcours : étapes accessibles de haut en bas ; accueil : clé +0…+5 ; feu de camp : 1 repos, 2 grimoire ;
  récompense : cartes, ou ouvrir le coffre), `Entrée`/`Espace` l'action par défaut. Toute autre touche est
  rendue au jeu.
- `/slay` : ouvrir/fermer ; `/slay options` ; `/slay art` (décor par décor : « peint » ou candidat
  validé, puis candidats validés / refusés / pas encore jugés ; puis icônes et modèles introuvables) ;
  `/slay modeles` (galerie des ennemis et des personnages, puis au chat la liste des modèles absents
  avec les identifiants essayés) ; `/slay decor` (bascule illustré validé / peint ; sous-commandes
  `essai`, `suivant`, `precedent`, `ok`, `non`, `peint`, `illustre` : « Essai des décors ») ;
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
  `interface/raidframe/readycheck-ready` (136814) ; illustrations des décors : listes de candidats
  (`Art.illustrations`, voir « Diagnostic des paysages »). Aucune illustration de côte trouvée : la côte
  est peinte. Le MCP confirme la liste de fichiers **retail 12.1.5**, pas l'installation Forever (il ne
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
  événements de vol, `SetPropagateKeyboardInput`, `SetCreature`, `SetDisplayInfo`, `SetUnit`,
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

- Quels **candidats de décor** existent dans Forever : seul l'essai manuel le dit (`/slay decor essai`).
  L'**allure** des illustrations validées : `crop` par candidat (`Art.illustrations`), `shift` et `tint`
  par décor (`Art.scenes`), à corriger après essai ; repli immédiat : `/slay decor peint`.
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
- Le zoom des survols (animation Scale + textes Vertex, échelle tenue par le délai de fin) : fluidité,
  textes immobiles pendant l'agrandissement, netteté une fois agrandi ; `/slay zoom` pour comparer avec
  `lisse`. Le décalage des cartes de récompense (`SetScale` + `SetPoint` divisé par l'échelle) : calculé.
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
lua5.1 Sim/ui_harness.lua [graine] [dossier]   # ou luajit ; doit finir par ALL PASS (287 vérifications, graine 1)
lua5.1 Sim/ui_harness.lua 1 build/snap         # + instantanés SVG des écrans dans build/snap
                                               #   (aperçus de Media copiés dans build/snap/media)
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
et `/slay art` ; modèles (essais créature puis affichages, médaillon de repli, relance tardive,
`OnModelLoaded`, lignes de `/slay modeles`) ; noms des ennemis (1 à 6 ennemis × échelles 0,6 / 1 / 1,5 :
visibles, dans le contenu, au-dessus du plateau, au-dessus du modèle et de la jauge, rien par-dessus) ; décors (peints par défaut, essai : suivant, précédent, ok, non, peint, illustre ; premier
validé de chaque liste ; verdicts relus au rechargement ; rapport) ; survols (zone fixe, valeur
intermédiaire, sortie réversible depuis la valeur courante, état final par les minuteurs, pilote coupé
au repos, voisines, premier plan, ennemi visé) ; panneau des cartes (tri, compteur, molette, Échap,
clic dehors, Fermer, pioche triée et ordre réel intact, défausse, consumées, deck en combat, touches
bloquées) ; **peau** (U20 : chaque texture de `SkinData` présente dans `Media/`, TGA 32 bits non
compressé à origine en bas, dimensions en puissances de deux identiques à `SkinData`, coordonnées de la
zone utile cohérentes ; pièces attendues présentes ; icônes de `SkinData` présentes et toutes celles que
nomme `Art.lua` copiées ; polices présentes ; carte composée : corps par couleur — ivoire, violet, bleu,
or —, ruban, coût, panneau, icône améliorée masquée, gemme, plaque du bas, nom horizontal, carte grisée
et sa raison, amélioration en vert, `/slay ruban` retiré ; repli sur l'icône du jeu quand le fichier manque ;
bulle d'intention ; mana) ; **textes des cartes** (U22 : les 34 cartes, de base et améliorées, jouables
et injouables avec leur plaque de raison : chaque ligne posée, marges comprises, sur les pixels sombres
de `Media/card_panel.tga` et hors de la gemme, au-dessus des plaques ; nom dans la bande opaque de
`Media/card_ribbon.tga` ; aucune recoupe par le client ; répartition par palier et cartes sous le
plancher affichées ; textes d'une carte fraîche visibles ; polices reposées à l'ouverture) ; zoom (U18 :
animation Scale, échelle réelle intacte, textes Vertex, aucune nouvelle mise en page, reprise depuis
l'échelle visuelle courante, tenue à l'arrivée, `/slay zoom`). Le faux client mesure les textes avec les
avances des glyphes de Baloo Chettan 2 (`Sim/baloo_metrics.lua`), une ligne de 1,47 cadratin (hhea),
retours explicites puis par mots, et simule les animations Scale. Il gère aussi `OnSizeChanged`, `GetChildren`, `IsObjectLoaded`
(fichiers `H.unloaded` jamais chargés) et `C_Texture`. Graine 1 : ALL PASS sous lua5.1 et luajit.

`Sim/ui_render.lua` résout ancres, tailles, échelles, couleurs, disques, rotations et textes des cadres du
faux client et écrit un SVG par écran (accueil, parcours, combat, combat-survol, récompense, marchand, feu
de camp, amélioration, rencontre, bibelot de classe, bilan, méta, panneau du deck, pioche en combat). Les
textures de `Media/` y sont dessinées (aperçus PNG : coordonnées de texture, couleur de sommet,
désaturation, masques approchés, rotation), les textes en Baloo Chettan 2 avec ombre et couleurs ; icônes
du jeu = carrés bleus, modèles = silhouettes en pointillés, illustrations = aplats ; textes mesurés comme
le faux client ; planche `cartes.svg` (textes longs, injouable, mot-clé, noms longs). Comparé aux planches (`combat_pack.jpg`…) pour cette peau ; il ne remplace pas un essai.

## Tests en vol (pour toi)

Préparation : copier le dossier dans `/mnt/Games/World of Warcraft/_forever_/Interface/AddOns/SlayTheDragon`
(commande `rsync` dans `CLAUDE.md`). **Nouveau fichier dans le TOC (`UI\SkinData.lua`) et nouveau dossier
`Media/` : relancer le client** (`/reload` ne suffit pas). Activer les erreurs Lua
(`/console scriptErrors 1`) ou BugSack.

En tout premier (peau « Mechanized Magic ») :
1. **Chargement des textures** : aucun aplat vert ni carré noir sur les cartes, le bandeau, le plateau, les
   boutons, les hexagones (PV, Absorption, mana, Démence, clé), les médaillons et le parcours. Sinon dire
   lesquels (une capture suffit).
2. **Police** : Baloo Chettan 2 partout (lettres rondes, accents corrects) ; si tout est en Friz Quadrata,
   la police ne se charge pas.
3. **Cartes** : nettes au repos et au survol (×1,16 en main, ×1,17 en récompense) ; icône ronde bien dans
   l'anneau ; nom horizontal centré sur le ruban, jamais hors de la bande ; texte du panneau centré, avec
   de l'air tout autour (côtés, haut sous la gemme, bas biseauté) même sur Forme d'ombre, Pénitence,
   Esprit de rédemption, chiffres blancs (verts une fois
   améliorés) ; gemme verte / bleue sur les peu communes / rares ; « Recharge N », « Incantation »,
   « Consumée », « Pouvoir » dans la plaque sous la carte ; carte injouable grisée avec sa raison en rouge.
4. **Plaques** : ardoise sans couture visible (bandeau, plateau, plaques de réponse, bulles d'intention,
   options), liseré d'argent régulier aux coins ; bulles ivoire (rencontre, parcours) ; survol doré des
   plaques de réponse et du feu de camp ; pilule dorée « Fin du tour » / « Reprendre la route ».
5. **Bords** : rien ne dépasse de la fenêtre (piles en bas à gauche, plaque du bas des cartes de la main,
   tas du deck).

Ensuite (retours du premier essai) :
1. **Essai des décors** (accueil) : `/slay decor essai`, puis pour chacun des 8 candidats `ok` (image) ou
   `non` (aplat vert, noir ou vide) et `suivant` ; `peint` pour finir. Recopier ensuite `/slay art`
   (décor par décor : `peint` ou candidat validé ; listes des validés et refusés).
2. **Paysages** : sur la route, le feu de camp, le marchand et le boss, l'illustration validée a-t-elle du
   sens derrière les personnages (sans logo ni texte, bien cadrée) ? Sinon dire lequel et ce qui cloche
   (trop haut / trop bas / logo) ; `/slay decor peint` revient au décor peint.
3. **Survols** : passer lentement puis vite sur les cartes de la main : la carte se lève et grossit en
   ~0,1 s **sans que le nom, le coût ni le texte tressautent ou changent de coupure** (comparer avec
   `/slay zoom` → `lisse`, puis `/slay zoom anim` ; dire lequel garder et si le texte agrandi est assez
   net), les voisines s'écartent un peu, elle passe devant ; ressortir en cours de route la fait
   redescendre sans à-coup ; aucun clignotement en bord de carte ; on peut monter le curseur sur la
   partie levée sans la perdre. Idem : cartes de récompense / marchand / grilles, boutons (dont « Fin du
   tour », ≡, ×), butin au sol, couchage et grimoire, étapes du parcours, plaques de réponse, fioles et
   bibelots du bandeau, tas du deck, pioche, défausse.
4. **Visée** : armer une carte à cible (ou une potion à cible) puis survoler les ennemis : l'ennemi
   survolé grandit un peu depuis ses pieds, son anneau s'allume ; le clic vise toujours le bon ennemi.
5. **Panneau des cartes** : hors combat, clic sur le tas du deck (plateau) et sur le deck du bandeau ;
   en combat, clic sur la pioche (triée par type, coût, nom — pas l'ordre de tirage), la défausse, le tas
   violet des consumées (après une carte Consumée) et le deck du bandeau. Molette si le deck dépasse 24 cartes ;
   fermeture par Échap, clic hors du panneau, « Fermer ». Cartes améliorées en vert.
6. **Bandeau** : en combat et sur la récompense, « Marche de l'Ouest » en haut au centre, points de
   progression en dessous, sans chevauchement, même avec 6 bibelots et une clé.
7. **Textes** : plus de tutoiement dans l'interface (bulles, raisons grisées, bilan, infobulles des
   intentions et des mots-clés). Les textes des cartes et des rencontres viennent de `Data/` (autre piste).

Ensuite, la liste habituelle : `/reload` en combat et sur une récompense (même état), potions (boire, à
cible, jeter), touches 1–0 / Tab / Espace / Entrée / Échap (une touche non gérée agit sur le jeu),
ouverture au décollage et fermeture à l'atterrissage, masquage en combat réel, `/slay modeles`
(recopier ses lignes du chat), `/slay facing`.

À me renvoyer : la sortie de `/slay art`, une capture du combat avec une carte survolée, du panneau de
la pioche, du bandeau, de chaque décor illustré validé, et toute erreur Lua (texte complet).
