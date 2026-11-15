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
- Raisons nouvelles : « Not enough HP to pay. », « Not enough Rage. » (ressource de la classe).
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
- **Débloqué** : la carte telle qu'en jeu, infobulle habituelle ; au survol, halo et aperçu à taille réelle
  à côté (voir « Survols ») ; le bibelot dans sa case, infobulle du bibelot. **Verrouillé** : dos de carte du pack
  assombri et désaturé (rien d'autre : ni nom, ni texte, ni icône, ni rareté) ; case de bibelot au point
  d'interrogation grisé, liseré éteint. Infobulle = la condition seule, en rouge (« Priest level 4 »).
- **Bilan** : « +76 Priest experience, +122 reputation (Explorers' League). », « Priest reaches level 2! » ;
  barres niveau de classe et Ligue ; en cas de montée, les cartes et bibelots débloqués révélés sous les
  barres (vraies cartes à 0,5, aperçu à taille réelle au survol ; cases des bibelots), le panneau monte et grandit sans
  toucher aux boutons. Les barres se placent sous le texte (il chevauchait la première barre à 6 lignes).
- **Accueil** : l'infobulle d'une classe dit « Level N » au lieu de la réputation.
- Harnais UP (5 classes aux niveaux 1, 4, 7 : nombre de cartes et bibelots ouverts, silhouettes sans texte
  ni icône, infobulle = condition seule, tout dans la fenêtre, rien de tronqué, carte de la dernière rangée
  survolée immobile, son aperçu à taille réelle dans la fenêtre ; bilan au niveau 2 et au niveau 3 ; accueil). Aperçus :
  `progression-priest-1`, `progression-warrior-4`, `bilan-montee-de-niveau`.
- Non vérifiable hors jeu : rendu du dos de carte désaturé (`SetDesaturated` sur une texture du pack), lisibilité
  des cartes à 0,6 au repos sur l'ardoise, aperçu à côté de la carte survolée, nouvelles icônes des bibelots du Priest
  (`Media/Icons`, nouveaux fichiers : relancer le client).

## Écran de combat : crans, annulations, Instant, Traveler's Backpack (13/11/2026)

- **Crans de la ressource** : petites gemmes en losange (12 unités) en arc autour de l'anneau de mana
  (rayon 49 depuis son centre, de -5° sous la pastille vers le bas, un cran tous les 14°), une par point
  du plafond : Rage 5, Combo 5, Charge 4, Frenzy 5 ; aucune pour l'Insanity (sans plafond). Alvéole =
  gemme désaturée assombrie, cran plein = la même gemme désaturée puis teinte à la couleur de la
  ressource (`Art.classes[id].resource.color`). Style des points de combo du jeu (alvéole sombre, gemme
  pleine) ; pièce : `Media/gem_rare.tga` du pack, déjà embarquée (aucune texture ni fichier du TOC
  ajouté ; les pièces `uf-roguecp-*` du jeu ne sont pas extraites). Visibles même à 0 (les alvéoles
  disent le plafond) ; la pastille et son nombre restent cachés à 0. Un cran qui se remplit passe en
  fondu (0,22 s) avec un éclat doux (`glow_round` en ADD, 0,45 s) ; un cran qui se vide passe en fondu,
  sans éclat ; aucune échelle. Cadre sans souris (il couvre l'anneau de mana) : l'infobulle de la
  ressource reste celle de la pastille. `V:RenderPips` dans `UI/CombatView.lua`.
- **Textes flottants des annulations** (journal du moteur) : `parry` → « Parry » (or) part du héros, à
  gauche du chiffre des PV perdus s'il en reste ; `trap` → nom de la Trap (« Freezing Trap! ») sur
  l'ennemi qui l'a déclenchée, avant ses effets (l'événement porte maintenant `id`) ;
  `interrupt_prevented` → nom de ce qui l'a empêchée (« Talisman of Focus! », champ `by` ajouté au
  journal ; « Not interrupted » sinon) ; `enemy_turn_skipped` (Feign Death) → « Skips its turn » sur
  chaque ennemi vivant. Existaient déjà : Absorb (chiffre bleu « -N », aussi pour un coup entièrement
  absorbé), Stunned qui arrête le tour (« Stunned »), Cast interrompu (« Interrupted! » sur le héros ou
  l'ennemi, « Spell lost » pour l'incantation ennemie perdue).
- **Instant** : sous l'état Instant (ou le crochet `instantCast`), chaque carte Cast de la main porte un
  liseré bleu arcane tenu (`b.rim` : le halo des cartes resserré à 85 % de sa marge, sous le halo doré du
  survol qui reste visible autour) et sa plaque dit « Cast · Instant » (« Instant » en bleu) ; infobulle
  « Instant: this Cast resolves at once. ». Lu par `Controller.handInfo` (`Combat.isInstant` sans rien
  consommer). Plaque vérifiée pour toutes les cartes Cast, base et améliorée.
- **Spend N** : déjà fait (ligne « Spend N: » au mot-clé doré si les points sont là, grise sinon ou Maj
  tenue) ; `handInfo` lit aussi `spendNeed` comme `Combat.play`.
- **Traveler's Backpack** : « End Turn » ouvre le choix s'il y a une carte à garder (hors Retain) :
  message « Choose a card to keep in hand. », cartes proposées au liseré d'or pâle, infobulle « Click:
  keep this card in hand for the next turn. », bouton devenu « Keep none ». Un clic sur une carte finit
  le tour en la gardant ; « Keep none » finit sans rien garder ; un clic droit annule le choix. Le choix
  est posé par `Combat.markRetain` juste avant l'action « endTurn » (`Controller.endTurn(uid)`), l'action
  de l'expédition ne portant pas d'argument.
- Harnais : section UG. Planches : `ug-crans-<classe>`, `ug-parry-rogue`, `ug-trap-hunter`,
  `ug-instant-mage`, `ug-spend-warrior`, `ug-spend-off-warrior`, `ug-backpack-choix-<classe>`.
- Non vérifiable hors jeu : teinte réelle des gemmes désaturées (`SetDesaturated` puis `SetVertexColor`
  sur une texture du pack), éclat en ADD, lisibilité des crans à 12 unités, intensité du liseré Instant
  sur la table sombre, nouvelle icône `Media/Icons/inv_misc_bag_11.tga` (nouveau fichier : relancer le
  client).
## Campagne continue : une expédition traverse les sept zones (14/11/2026)

Règles : `docs/zones.md` et `docs/expedition.md` (« Campagne continue »). Remplace le choix de la zone à
l'accueil (13/11/2026). La Ligue des explorateurs a disparu de tous les écrans ; ce qui en parle plus haut est
historique.

- **Accueil** (`Start`) : panneau monté à y 44 et allongé à 392. Sous la rangée des classes, libellé
  « Campaign » et sept plaques rouges (`W.button`, 126 × 34, 4 puis 3 par rangée, centrées) dans l'ordre de la
  campagne, **affichées, jamais choisies** (toute expédition part de Westfall) : nom de la zone, dessous en
  petit « Beaten » (vert : boss battu par la classe), « Reached » (atteinte) ou « Not reached » (plaque
  éteinte : pièce désaturée, libellé gris) ; la plus loin atteinte au liseré d'or (`SetSelected`) ; aucune
  plaque ne s'allume au survol ni ne réagit au clic (`active = false`, pas de `OnClick`) ; infobulle = nom et
  état (« Boss defeated by the Priest, best key +1. », « Reached by the Priest, boss not yet defeated. »,
  « Not yet reached by the Priest. »). Puis « Mythic Keystone » : les clés de la classe (une clé vaut pour
  toute l'expédition ; raison « Defeat Nefarian at +1 to unlock key +2. »). Sous le panneau, la note : la
  campagne de la classe (« Farthest: Duskwood (2/7) · bosses defeated: 1 of 7 », ou « From Westfall to
  Blackrock Mountain. ») puis la dernière expédition. « Start expedition » (option `go`, texte « Westfall »).
  Options `zone:<id>` (`info = true`, `status` = `won` / `reached` / `ahead` / `later`, `farthest`) ;
  contrôleur : `C.startInfo()` → `{ class, zone = Westfall, key, keyMax }`, `C.zoneStatus`, `step.campaign`.
- **Entre deux zones** (écran `Transit`, étape `transit`, phase `transit` de l'expédition) : après la récompense
  du boss. Décor de la zone suivante (la zone de l'expédition est déjà la nouvelle : `Controller.scene()`),
  héros, panneau d'ardoise (`W.dialog`, x 280, y 70, 560 × 250) : nom de la zone en grand (28, or), sept
  pastilles de carte de vol (zones franchies vertes, la suivante jaune et plus grande, à venir grises : mêmes
  pièces que le bandeau), texte « Westfall is behind you. Zone 2 of 7. », « You recover 12 HP (36/36). »
  (vert) et, si le boss vaincu a débloqué quelque chose, la vitrine des déblocages (cartes et bibelots montrés :
  voir « Déblocages montrés, plus décrits » ; avant le 15/11/2026, une phrase). Bouton doré « Continue » (790, 494 ;
  option `continue`) ; l'abandon reste au menu. Le bandeau montre « Duskwood · 2/7 », sans pastilles d'étape.
- **Carte et bandeau** : la zone en cours et sa place dans la campagne, « Duskwood · 2/7 »
  (`Expedition.campaignName`, `runInfo().act`, titre de l'étape `map`).
- **Écran Progress** : onglet « Zones » : sept colonnes (nom en or, état « Beaten » vert / « Reached » /
  « Not reached » / « Coming later » gris, « Best key +1 » = meilleure clé où la classe a battu ce boss), la
  carte de zone de la classe à 0,9 (vraie carte débloquée, sinon dos de carte grisé, infobulle « Win Duskwood
  to unlock » seule), trois cases de bibelots de clé +1 / +3 / +5 (infobulle « Win Westfall +3 to unlock »
  seule : battre le boss de Westfall à +3). Contrôleur : `step.tab`, `step.zones` (`C.zoneRows`).
- **Journal** (« Log ») : une barre (niveau de la classe ; détail « Bosses defeated: 1 of 7 · farthest:
  Duskwood · 3 expedition(s), 0 victory(ies) », puis le titre) ; lignes « date · Priest +0 · defeat ·
  Duskwood (2/7) stage 3 · 1 boss · +70 experience » (zone atteinte, boss battus ; les entrées d'avant la
  campagne continue gardent leur zone seule).
- **Bilan** : jusqu'où le joueur est allé : « Nefarian has fallen: the 7 zones are crossed. … » (victoire), sinon
  « Fell in Duskwood (2/7) at stage 3 against … » / « Turned back in … » (« Turned back at the gates of
  Duskwood (2/7). » avant sa première étape), puis « Zones beaten: Westfall (1 of 7). » (ou « No zone
  beaten. ») ; étapes, élites, boss ; expérience de toute l'expédition, montée de niveau ; déblocages des boss
  battus, **regroupés** (une expédition peut en battre sept) : « First bosses defeated with the Priest:
  Duskwood, Wetlands. », « Mythic Keystone +2 unlocked. » (Nefarian) ; les épiques, cartes, bibelots et le
  commun du compte sont montrés dans la vitrine (15/11/2026 : plus de « New epic card(s) », « New relic(s) »,
  « First … bosses on this account: 16 neutral cards… » en texte ; voir « Déblocages montrés, plus décrits »).
- Harnais : U6 (le boss de Westfall mène à l'écran entre deux zones : textes, soin, épique débloquée tout de
  suite dans la méta, bandeau, décor de Duskwood, rechargement sur cet écran, « Continue », carte de Duskwood,
  puis abandon), U7 (bilan : jusqu'où, Westfall battue, déblocages ; journal), section **UZ** réécrite
  (accueil : sept plaques non cliquables, états, infobulles, la plus loin ; écran entre deux zones ; bilans :
  chute à Duskwood, +1 avec bibelot de clé, victoire complète regroupée et clé +2 ; onglet Zones ; Mage sans
  rien ; reprise v4) ; les sections de zone amènent l'expédition dans leur zone par `T.toZone(zone)`
  (`Expedition.enterZone`, écran entre deux zones, « Continue »). Aperçus : `accueil-zones`,
  `accueil-campagne`, `entre-zones`, `entre-zones-campagne`, `parcours-duskwood`, `bilan`, `bilan-campagne`,
  `bilan-bibelot-de-cle`, `bilan-victoire-complete`, `progression-zones`.
- Non vérifiable hors jeu : rendu des plaques éteintes (`SetDesaturated`), lisibilité du petit état (10) sur
  la plaque, pastilles du panneau entre deux zones sur l'ardoise.

## Déblocages montrés, plus décrits (15/11/2026)

Demande du joueur : après chaque boss, voir les cartes et les bibelots obtenus plutôt qu'une phrase (« Unlocked
for your next expeditions (Rogue): epic card X, relic Y, new common content for every class. »).
- **Vitrine partagée** (`Shelf`, haut de `UI/Screens.lua`, après `RowScroll`) : écran entre deux zones et bilan.
  Titre « Unlocked for your next expeditions » (or, 15), puis un groupe par destinataire : la classe (« Rogue » :
  épiques d'abord, cartes de zone, cartes et bibelots de la montée de niveau au bilan, bibelots de clé) et
  « All classes » (le commun que le compte vient d'ouvrir : `Meta.commonContent` de chaque zone dont le compte bat
  le boss pour la première fois — cartes neutres, bibelots, potions). Vraies cartes `W.card` (survol : halo et
  aperçu à taille réelle, comme toute petite carte), bibelots et potions en cases `W.iconButton` (infobulle de
  l'objet). Nom du groupe dans une colonne à gauche (96) de sa première rangée visible.
- **Reste en texte** : une ligne courte par groupe sous les rangées pour ce qui n'est ni carte ni objet :
  « All classes: 15 new encounters. Choose a relic at the start of each expedition. One more relic at the
  merchant. » (rencontres, avantages du compte). Les drapeaux d'histoire ne sont pas montrés entre deux zones
  (rien à en savoir) ; au bilan restent en texte « First boss(es) defeated with the Priest: … », « Mythic
  Keystone +N unlocked. », le titre Dragonslayer et Rallying Cry.
- **Mise en page** : la densité la plus aérée qui tient dans la hauteur offerte (`SH_DENSITY` : cartes 0,5 et
  épique 0,72, cases 44 seules ; puis cases 44 par deux ; épique 0,5 ; cases 32 par trois ; cartes 0,42 et cases
  28 par trois), groupes empilés, sinon côte à côte sur une seule rangée (chaque nom à sa largeur) ; si rien ne
  tient, la plus serrée, empilée, et les rangées défilent à la molette (`RowScroll`, une rangée par cran,
  rangées entières, indicateur au bord droit de la vitrine ; fenêtre = la plus haute des positions).
  Contrôleur : `step.unlocks = { { label, cards, relics, potions, notes } }` (nil : rien) pour `transit` et `end` ;
  `step.unlocked` (bilan) retiré.
- **Entre deux zones** : avec des déblocages, le panneau monte (y 44), s'élargit vers la droite de 560 à 700 selon
  la vitrine (le héros est à gauche), grandit vers le bas jusqu'à y 486 au plus (« Continue » à y 494) ; nom,
  pastilles et texte resserrés en haut. Rien de débloqué : panneau (280, 70, 560 × 250) et textes comme avant,
  sans la phrase. Cas réels, compte neuf à +5, chaque zone : tout tient sans défilement (après Duskwood, le plus
  chargé : épique et 3 bibelots de clé, puis 4 cartes, 12 bibelots et 2 potions du commun, en cases 32 par trois).
- **Bilan** : la vitrine sous la barre de niveau (panneau monté à y 40, bas à y 488 au plus). Bilan d'un compte
  neuf qui a battu Westfall : les deux groupes côte à côte sur une rangée ; victoire complète d'un compte neuf
  (commun de six zones) : défilement.
- Harnais : `shelfReport` / `shelfHovers` / `transitAvoid` (après `snap`) : cartes et cases visibles, chaque
  élément dans le panneau (12 sous ses bords), sans chevauchement entre éléments, ni du visuel d'une carte
  (languette, plaque) sur un texte de la vitrine ou de l'écran (nom de la zone, pastilles, soin, Continue,
  barres, boutons) ; aperçu à taille réelle de chaque carte, infobulle de chaque case. U6 (compte neuf, Westfall :
  épique en tête au cadre violet, commun, note, survols, rien ne chevauche, sans défilement), U7 (bilan côte à
  côte), UP, UZ (bilans : commun de six zones regroupé, rencontres et avantages en note, toutes les positions du
  défilement propres, tout vu une fois), **UT** (pour chaque zone suivie d'une autre, compte neuf, Voleur à +5 :
  groupes, chaque carte et case une fois, l'épique d'abord, survols, rien ne chevauche, sans défilement, rien de
  tronqué ; épique seule à 0,72 dans un panneau de largeur ordinaire ; rien de débloqué : pas de vitrine,
  panneau à sa place d'origine), UE (l'épique en tête, une fois). Aperçus : `entre-zones`, `entre-zones-compte-neuf`,
  `entre-zones-maximal`, `entre-zones-epique`, `entre-zones-sans-deblocage`, `bilan`, `bilan-victoire-complete`,
  `bilan-victoire-complete-defile`.
- Non vérifiable hors jeu : lisibilité des cartes à 0,5 et des cases 32 sur l'ardoise, rendu de l'aura violette
  de l'épique à côté des cases, molette sur la vitrine du bilan (cadres survolés rejoués), largeur réelle des noms
  mesurée par le client (côte à côte).

## Westfall réelle (13/11/2026)

Décisions du joueur (`docs/zones/westfall.md`, fin) : la zone 1 empruntait décors et personnages à Elwynn
et ailleurs. Aucun chiffre ne change.
- **Décors** : route, colline, camp, marchand et feu de camp en décors peints couleur blé, portés par la
  zone (« Décors peints de Westfall », plus bas) ; `Media/Backgrounds/elwynn.tga` supprimé.
- **Defias Highwayman** (créature 122, affichages 2342 / 2343) remplace le Defias Bandit (116) : même id
  `bandit`, mêmes chiffres, aucune migration de sauvegarde.
- **Personnages des rencontres** : gens de la Marche (« Personnages (`Art.npcs`) », plus bas ; textes dans
  `docs/rencontres.md`). Clés d'`Art.npcs` renommées (`farmer_furlbrow`, `verna_furlbrow`, `scout_galiaan`,
  `thor`, `innkeeper_heather`, `captain_grayson`, `defias_profiteer` ; `farmer_saldean` sert au moissonneur) :
  les gagnants mémorisés sous les anciennes clés (`options.modelWins`) ne servent simplement plus.
- Harnais : U17 adapté (fonds embarqués des scènes illustrées, paysage peint des autres, essai à 4
  candidats), U21 (listes de candidats), faux client avec `CreateColor` et rendu des dégradés ; section
  **UW** (zone porteuse des cinq décors, palette, couches, Elwynn retirée, Highwayman, empreintes des
  chiffres des ennemis et des règles des rencontres d'avant le changement, plus aucun personnage ni lieu
  d'ailleurs dans les textes, décor de la zone en combat, au feu de camp, chez le marchand et en rencontre).
  Aperçus : `decor-westfall_road|hill|camp|shop|night`, `rencontre-furlbrow`, `rencontre-sentinel-hill`.
- Non vérifiable hors jeu : rendu réel des rectangles tournés (`SetRotation` des ailes, des toits, des
  rangs de blé) et des dégradés ; chargement des créatures 237, 238, 392 (absentes des caches) ; allure des
  affichages de secours.
## Cartes épiques (13/11/2026, règle finale du 14/11/2026)

Règles : `docs/expedition.md`, « Cartes épiques » (une épique est une règle en jeu dès le début de chaque combat,
hors de toute pile, sans coût).

- **Cadre** (`W.card`, `SetCard`) : une carte `rarity = "epic"` prend le ruban et la languette de coût violets
  (`Media/card_ribbon_epic.tga`, `Media/card_cost_epic.tga`, même géométrie que les pièces de base), une aura
  violette tenue derrière la carte (`b.epicGlow` : `card_glow` teinté `W.EPIC_COLOR` #a335ee, alpha
  `W.EPIC_GLOW_ALPHA`, créée avec la carte) et la gemme épique (pentagone violet, `gem_epic`). Les pièces violettes
  sont générées par `tools/build_media.py` à partir des pièces du pack (teinte HSV fixe, saturation qui baisse
  avec la clarté) ; `build/venv/bin/python -I tools/build_media.py --epic-only` les refait seules depuis
  `Media/card_ribbon.tga` et `Media/card_cost.tga` (Pillow + numpy, sans le PSD) et ajoute leurs entrées à
  `UI/SkinData.lua`. **Nouvelles textures : relancer le client** (pas un nouveau fichier du TOC).
- **Sans coût** : le chiffre du coût est caché ; la languette violette porte le mot « Epic » (`b.epicMark`, gras
  10, `W.EPIC_MARK_COLOR`, créé avec la carte, au centre de la languette). Plaque du bas : « Epic » (mot du
  registre du langage, `L.plate("epic")`, en tête ; une épique ne dit jamais « Power », un « Epic. » ou
  « Power. » de tête est retiré du texte affiché).
- **Texte : deux lignes au plus** (règle du 14/11/2026) : la carte dit le déclencheur et un mot de règle avec
  son nombre (« Each Parry gained: Riposte 1. ») ; la règle complète est l'à-côté du mot dans l'infobulle
  (« Riposte: Deal 1 damage to the last target, +2 per earlier Riposte this turn. »). Mise en page :
  `W.cardMaxLines(d)` = `W.EPIC_LINES` (2) pour une épique ; `fitBody` essaie d'abord les paliers, du plus
  grand jusqu'à `W.EPIC_FLOOR` (8,5), en deux lignes au plus (`layoutBody(…, maxLines)`), puis la règle
  commune en secours (signalé par le harnais). Le texte de Deflection prend trois lignes à 10 : il est posé
  à 9 en deux lignes. Mot de règle : `L.rule` (`Core/Language.lua`, voir « Langage des cartes ») ; textes
  finaux et à-côtés des 35 : `docs/zones/cartes-de-zone.md`, « Textes en deux lignes et mots de règle ».
  Harnais : section **UEL** et planche `epiques_mots_cles.svg` (cartes et à-côtés repliés à ~44 caractères,
  base en gris, améliorée en vert).
- **Infobulle** : « Epic: in play from the start of each combat. » (mot de plaque), « One epic card per
  expedition: a new one replaces it. » (`W.EPIC_HINT`) et une ligne par transformation (« While in the deck:
  Smite becomes … », `W.transformLines`) ; une variante montrée hors combat ajoute « Transformed Smite. » (option
  de carte `from`).
- **Rien au départ** (règle du 14/11/2026 : l'épique se gagne) : l'écran de choix d'épique au départ (étape
  `startEpic`) est retiré ; le départ ne propose que le bibelot au choix (zone 3 gagnée, étape `startRelic`).
- **Récompense d'élite** (une épique tombée, `Expedition.rollEpicDrop`) : montrée AVANT les cartes ordinaires (étape `epicMode`) :
  titre violet « Epic card », la carte centrée, consigne « Replace your epic card, or skip it. » (« Take this
  epic card, or skip it. » sans épique dans le deck) décalée à gauche, « Skip » à gauche de « Back on the
  road ». Après le choix (ou « Skip ») : les cartes ordinaires, comme avant.
- **Remplacement** (`UI.epicConfirm`, construit au premier usage) : `UI.choose(id)` demande d'abord
  `Controller.epicSwap(id)` (l'action rejouée sur une copie de l'expédition : vrai si elle ferait partir
  l'épique du deck pour une autre ; récompense, marchand, rencontre). Si oui, panneau modal sur un voile : titre
  « Epic card », question « Replace A with B? », note « Only one epic card per expedition: the current one leaves
  the deck. », les deux cartes à 0,9 côte à côte (ancienne à gauche, telle qu'elle est ; nouvelle à droite), un
  « > » entre elles, « Leaves the deck » (rouge) / « Joins the deck » (vert) dessous ; si l'ancienne est
  améliorée, une ligne « The upgrade is lost. » sous « Leaves the deck » (`EC.lost`). Boutons « Replace » (or) et
  « Keep A » (rouge). Clic hors du panneau = « Keep ». Survol des cartes : halo seulement, ni levée ni aperçu.
- **En combat** : l'épique (`c.epic`) est le premier des Powers en jeu sous le héros (après les états) : jeton à
  l'icône de la carte, liseré violet (`Art.rarityRim.epic`) et aura violette tenue derrière le jeton (champ
  `glow` des jetons de `W.tokenRow` : `glow_round` teinté `W.EPIC_COLOR`, créé éteint avec le jeton) ; infobulle
  complète (nom, texte, Epic, une par expédition, cartes transformées). Elle n'est ni dans la main ni dans les
  piles.
- **Crans de la ressource** (`V:RenderPips`) : le plafond lu est celui du combat, `Combat.resCap(c)` (une épique
  peut porter la Rage à 10), sinon celui de la classe. Jusqu'à 6 crans : un arc (comme avant). Au-delà : deux
  arcs concentriques, l'intérieur (rayon 49) prend la moitié haute des crans, l'extérieur (rayon 63) le reste,
  décalé d'un demi-cran ; remplis dans l'ordre, l'arc intérieur d'abord ; 12 crans au plus (`PIPS_MAX`).
  `V.layoutPips(pips, cap)` les repose quand le plafond change.
- **Marchand** : l'épique en vente se range à la suite des cartes (7 cartes au plus), cadre violet, prix sur sa
  plaque ; l'achat passe par la même confirmation.
- **Deck** : l'épique en tête du panneau du deck (`DV.sorted`) et des grilles d'amélioration et de retrait
  (`epicFirst` du contrôleur) ; bandeau, panneau, amélioration, retrait et sélection montrent le deck transformé
  (`Expedition.shownDeck`).
- **Progress, onglet Zones** : l'emplacement verrouillé d'une carte de zone est un dos de carte teinté de violet
  avec l'aura épique (`lockedCard`, `SetEpic`) ; débloquée, la vraie carte (cadre violet) à 0,85 : son survol
  montre l'aperçu à taille réelle (sous `W.PREVIEW_BELOW`).
- **Bilan** : (remplacé le 15/11/2026 par la vitrine, « Déblocages montrés, plus décrits » : l'épique en tête
  du groupe de la classe, à 0,72 si la place le permet, sans libellé « New epic card » ni ligne de texte.)
- Harnais : section **UE** (avant U16 ; départ sans épique, puis l'épique posée dans le deck comme gagnée, chute
  imposée à 100 % pour l'élite) ; planches `ue-combat-epique`
  (l'épique parmi les Powers), `ue-carte-epique` (panneau du deck : carte sans coût, en tête), `ue-choix-epic`
  (épique tombée après une élite, infobulle), `ue-remplacement` (confirmation, « The upgrade is lost. »),
  `ue-crans-rage-10` (deux arcs), `ue-progression-zones`, `ue-bilan-epique`. Les aperçus PNG des textures
  (`build/media_png`, copiés par le harnais) doivent contenir `card_cost_epic.png` et `card_ribbon_epic.png`.
- Non vérifiable hors jeu : rendu réel du violet des pièces et des auras sur les décors, lisibilité de « Epic »
  sur la languette violette et du nom blanc sur le ruban violet, le panneau de confirmation au-dessus des modèles
  3D, la lecture des deux arcs de crans à côté de l'anneau de mana.

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
  principale) ; libellé doré (NORMAL_FONT_COLOR) ; survol : surbrillance sans échelle (voir « Survols ») ;
  `SetSelected` tient le liseré (classe choisie). `W.roundButton("×")` / `W.closeButton` : bouton de
  fermeture rouge ; autre glyphe : petit bouton rouge (plus employé depuis la grille du deck défilante).
- `W.check` (checkbox-minimal, coche jaune), `W.slider` (Minimal_SliderBar : rail, poignée, flèches = un
  cran, clic ou glisser sur le rail), `W.slotOn` (case de barre d'action : fond, icône, cadre, cadre doré au
  survol ; cadre teint à la qualité d'un bibelot), `W.iconButton` (case, ou icône dans le grand anneau),
  `W.medallion` (grand anneau doré), `W.tokenRow` (auras : icône dans le cadre de case, rouge pour un
  affaiblissement, nombre en bas à droite), `W.hpBar` (barre du jeu rognée à la fraction, portion perdue
  claire, « PV / max »), `W.shieldBadge` (Absorption : barre bleue dans le logement bas du cadre d'unité,
  fraction des PV max, nombre), `W.repBar` (barre jaune assombrie dans un rail).
- Survols : `W.hoverable` (voir « Survols (sans agrandissement) » ; aucun cadre enfant dessiné dans un
  visuel — les cadres d'ancrage des boutons de réponse et de leurs cases ne portent aucune région), halos
  créés d'avance,
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
  et journal (dialogues, barre de niveau). Messages passagers : texte rouge des erreurs du jeu sur un
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

## Feu de camp, personnages des rencontres, préchargement (12/11/2026)

Retours en jeu : « le feu de camp n'est pas bon » (dessin en ellipses) ; « certains modèles de PNJ des
rencontres ne chargent pas du tout » ; « on ne peut pas forcer le chargement et attendre sa fin ? ».

### Constat

- 12 des 16 personnages des rencontres n'avaient **aucune** entrée dans `Art.npcs` (seuls Salma, Saldean
  et Gryan) : rien ne pouvait s'afficher. Les 3 autres n'avaient qu'un affichage de secours.
- Délai d'essai `W.MODEL_WAIT` = 0,8 s : un premier chargement plus lent (humanoïde équipé, créature
  absente du cache) était abandonné (`ClearModel`) juste avant d'arriver ; la relance tardive ne
  retentait que la créature.
- Invocateur défias (619) : 2329 / 2330 sont bien ce que le serveur annonce (deux caches), mais rien ne
  s'affichait : affichages peut-être absents de ce client, ou lenteur. Candidats ajoutés : 2359 / 2360
  (Sorcier-voleur défias, Elwynn), 4281 / 4282 (Enchanteur défias). Le 13/11/2026, 2359 / 2360 sont
  remplacés par 2321 / 2322 (Magicien défias, Mortemines).

### Cache de créatures (`tools/wdb_creatures.py`, lecture seule)

`python3 -I tools/wdb_creatures.py [--id N] [--display N] [mot …]` lit
`_forever_/Cache/WDB/enUS|frFR/creaturecache.wdb` (en-tête « BOMW » de 24 octets, puis des
enregistrements { identifiant, taille, données } ; bloc des affichages { nombre, probabilité totale,
nombre × { affichage, échelle, probabilité } } repéré par sa forme). 12/11/2026 : enUS (build 70888)
998 créatures, frFR (build 70862) 1 853 créatures, toutes lues avec leurs affichages sauf une. Le client
Forever a remodelé certaines créatures (Nervi défias 38 → 129962 / 129963, Vermine kobold 6 → 127670) :
le cache dit l'affichage que CE serveur annonce.

### Personnages (`Art.npcs`)

Chaque personnage : la créature citée (`SetCreature`), puis deux affichages ou plus (`SetDisplayInfo`),
lus dans le cache : le sien, puis ceux de créatures du même genre ; une icône embarquée évoquant le
personnage pour le médaillon. Détail et provenance dans les commentaires de `UI/Art.lua`.

**Depuis le 13/11/2026, uniquement des gens de la Marche de l'Ouest** (décision 3 de
`docs/zones/westfall.md`) :

| Rencontre | Avant (modèle) | Maintenant | Créature / affichages | Provenance |
|---|---|---|---|---|
| `defias_caravan` | le cocher (Brog Hamfist 151) | Farmer Furlbrow | 237 / 1943, 3614 | 237 absent des caches (id classique) ; affichages : Saldean, Ray (repli) |
| `moonbrook_refugees` | Mother Hanna (Ma Stonefield 244) | Verna Furlbrow | 238 / 1691, 8185 | 238 absent des caches ; affichages : Salma Saldean, Heather (repli) |
| `coast_murlocs` | Old Hank (Lee Brown 1651) | Scout Galiaan | 878 / 2373, 2374, 2368 | cache frFR (milice du peuple) |
| `jangolode_prospector` | Grit (Prospector Stormpike 1356) | Thor | 523 / 3263, 3594 | cache frFR ; 3594 (nain de Forgefer) = repli d'apparence |
| `herbalist` | Aunt Mirelle (Alma Jainrose 812) | Innkeeper Heather | 8931 / 8185, 1691 | cache frFR |
| `lighthouse_keeper` | Keeper Alden (Dockmaster Baren 381) | Captain Grayson | 392 / 2372, 2367 | 392 absent des caches ; affichages : Capitaine Danuvin, Protecteur Gariel (repli) |
| `goblin_peddler` | Grizzle Quickclick (Zixil 3537) | Defias Profiteer | 1669 / 4423, 2342 | cache frFR |
| `harvest_watcher` | Tinker Bertil (Deek Fizzlebizz 3290) | Farmer Saldean | 233 / 1943, 3614 | caches |
| `tobin_defias` | modèle Defias Cutpurse 94 | (Tobin) | 121 / 2336, 2337, 2342, 2343 | Defias Pathstalker, caches |
| `scarecrow_field` | Farmer Molsen (Farmer Ray 232) | inchangé | 232 / 3614, 3667, 1943 | zone de 232 non vérifiable |

Gardés : Salma Saldean, Gryan Stoutmantle, Graymaw (Riverpaw Taskmaster 98), Tobin enfant (Tommy Joe
Stonefield 252, Elwynn : aucun enfant nommé de la Marche connu) et Tobin guetteur (Scout Riell 820).

### Mécanisme (`UI/Scene.lua`)

- `S.loadModel(model, art, clé, h)` : essais créature, affichages, fichiers (`SetModel`), dans l'ordre ;
  succès = `OnModelLoaded` pour cet essai, ou (créature, affichage) `GetModelFileID` non nul après
  `S.MODEL_WAIT` = **2 s** ; fichier : `OnModelLoaded` seulement (si le client a ce script : un fichier
  absent pourrait être « vu » par `GetModelFileID`). Après l'échec de tous : repli, puis 2 tours de
  relance de **tous** les candidats (4 s entre deux), puis le premier reste posé (un `OnModelLoaded`
  tardif le valide).
- Pourquoi 2 s : 0,8 s abandonnait des premiers chargements de plus d'une seconde ; le délai ne coûte
  rien quand le modèle charge (validé à l'`OnModelLoaded`) ni quand le gagnant est connu ; il ne retarde
  que l'abandon d'un candidat qui échoue vraiment.
- **Mémoire** : gagnant par clé (session `S.won`, et `options.modelWins` d'une session à l'autre : un
  affichage ou un fichier qui a chargé chargera encore ; oublié dès qu'il échoue), essayé en premier ;
  candidats en échec essayés en dernier (`S.failed`) ; clé dont tout a échoué (`S.lost`) : médaillon
  aussitôt pendant les nouveaux essais.
- **Attendre** (`S.showModel`) : le modèle est posé invisible (alpha 0 : le client le charge quand même,
  comme les cadres de préchargement de Blizzard, `MissionCompletePreloadModelTemplate` à `alpha="0"`),
  ombre cachée ; au chargement, fondu de 0,3 s du modèle et de son ombre. Le médaillon (icône de
  `art.icon`, au-dessus du modèle) n'apparaît qu'après l'échec de **tous** les candidats et s'efface si
  un modèle arrive. Texte, réponses, cartes et boutons ne l'attendent jamais. Pour les ennemis
  (`S.enemyFigure`, `UI/CombatView.lua`), les PNJ (`S.npcFigure`), le familier (`UI/Art/hunter.lua`), le
  feu. Les cadres gardent leur modèle cachés (`SetKeepModelOnHide(true)`). `W.setCreatureArt` et
  `W.MODEL_WAIT` (`UI/Widgets.lua`) ne servent plus.
- **Préchargement** (`S.preload`, `S.nextNeeds`) : à chaque affichage du parcours (étapes accessibles
  connues ; au départ de l'expédition c'est le premier écran), cadres de modèle créés une fois et
  réutilisés, enfants d'`UIParent`, **montrés à alpha 0** dans l'écran (un `PlayerModel` caché libère
  son modèle), qui font les essais : feu de camp, familier du Chasseur, ennemis des groupes du genre de
  chaque étape accessible (combat : `easy` / `normal` selon `EASY_COMBATS`, élite, boss), personnages des
  rencontres possibles (`X.eventPool`). À l'ouverture d'une rencontre : ennemis des combats que ses
  réponses peuvent lancer. Un cadre chargé est caché (plus rien à dessiner) en gardant son modèle
  (`SetKeepModelOnHide(true)`). Le gagnant mémorisé est posé en premier par la scène ; le modèle, déjà en
  mémoire du client, arrive aussitôt. Le héros (`SetUnit("player")`) n'a pas besoin de préchargement.
- **Limite** : attendre règle le modèle lent ; pas l'identifiant que le client ne connaît pas
  (créature jamais envoyée par le serveur, affichage ou fichier absent de ce client), qui ne se chargera
  jamais : d'où plusieurs affichages par personnage (`SetDisplayInfo` lit les données du client, sans
  serveur ni cache de créatures ; `SetCreature` dépend des données de la créature, cache ou serveur ;
  `SetModel` ne dépend que du fichier) et le médaillon.

### Feu de camp

- `Art.campfire.files` (FileDataID ou chemin, `wow_model_search`) : 189705 `elwynncampfire.m2` (Elwynn,
  classique), 198193 `undeadcampfire.m2` (feu humain générique, classique), 199156 `smallfirepit01.m2`
  (petit foyer orc, classique), le premier par chemin, 987238 `6fx_campfire01.m2` (Draenor), 195041
  `northrendelwynncampfire.m2`. Flammes = émetteurs de particules : un cadre de modèle les dessine
  (l'interface de Blizzard affiche ainsi un effet de sort, 1601381, dans `RecruitAFriendFrame`, cadre
  `Model` + `SetModel` + `OnModelLoaded`). Repli : médaillon de 74 à l'icône
  `inv_camelot_camping_welcomingcampfire` (embarquée).
- `S.campfire` : cadre 140 × 130 au sol (x 517, pieds y 346 comme le héros), lueur = texture fondue de
  l'ombre (`shadow_soft.tga`) teintée orange en mode additif, deux couches qui vacillent, au pied du
  feu, sous le modèle ; pas d'ombre de contact. Couchage et grimoire au-dessus du feu (niveaux) ; 140 de
  large : leur halo de survol s'arrête avant.
- Cadrage (non vérifiable hors jeu) : orientation `Art.campfire.facing` = 0,5 ; caméra par défaut du
  cadre (`SetPortraitZoom` ne vaut que pour les créatures). `/slay fire <échelle> <hauteur>
  <orientation>` (`SetModelScale`, `SetPosition(0, 0, h)`, `SetFacing`) règle le feu affiché et le garde
  (`options.fireCam`) ; `/slay fire reset`.

### `/slay models`

Galerie (ennemis, chaque `npc` des rencontres, familier, feu de camp) puis, quand plus rien n'est en
cours (au plus 60 s), au chat : « models: N/M loaded, K on fallback: » et **une ligne par modèle** :
`clé (nom): display 1691` (candidat chargé, « (declared first: creature 235) » si d'autres ont échoué
avant), `clé (nom): fallback (no model: creature 619, display 2329, …)`, ou `loading (…)`.

### Harnais (UF, et U15, U21, U28 adaptés)

Faux client : `OnModelLoaded` sonne `H.modelDelay` = 0,2 s après la pose d'un modèle connu
(`H.slowModels` : délai propre) ; `H.noModels` : aucun modèle ; `SetModel` : seuls les fichiers de
`H.goodFiles` existent (aperçus du feu en repli). UF : données (chaque rencontre a un personnage déclaré,
3 candidats ou plus, icône embarquée ; feu : 3 fichiers ou plus) ; plus de trace de l'ancien dessin ;
feu invisible puis médaillon après tous les fichiers, lueur orange additive au pied et sous le modèle,
place et échelle par rapport au héros, rien d'interface sous le modèle, fichier arrivé à la relance qui
remplace le médaillon ; rencontre sans modèle : texte et réponses tout de suite, personnage invisible,
pas de médaillon tant qu'il reste des candidats, puis médaillon à son icône avec son nom au-dessus,
remplacé par un modèle tardif ; chargement lent (1,5 s) attendu sans médaillon ; préchargement au
parcours (feu, PNJ des rencontres possibles, ennemis des combats possibles, cadres montrés à alpha 0
hors de la fenêtre), gagnant mémorisé, scène qui le pose en premier et l'affiche en moins d'une seconde,
ennemis des combats d'une rencontre préchargés. Aperçus : `feu-de-camp-repli`, `rencontre-repli`.
Nouvelles icônes embarquées (13, `tools/build_media.py --icons-only`) : **relancer le client**.

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
  bas, et sous la plus grande gemme de rareté en haut ; le bas biseauté rétrécit la zone (forme exacte
  depuis le 12/11/2026 : voir « Texte centré et sablier à la hauteur des chiffres »). Les lignes sont posées une à une (voir « Retours à
  la ligne plutôt que des paliers plus petits » plus bas : clauses repliées, coupures choisies, écart
  entre clauses), chaque ligne limitée à la largeur de la zone à son bas, bloc centré verticalement ;
  puis le texte est posé avec des retours explicites dans une **boîte posée** (`W.looseBox`, voir
  « Textes tronqués au survol » plus bas). Mesures par le client : `GetStringWidth` / `GetStringHeight` d'un texte
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
  **Garde-fou en jeu** (`W.checkCardTexts`) : une image après la pose d'une carte, un texte que le client
  tronque malgré tout (`IsTruncated`) fait descendre son palier (texte ou nom, `card.textCap`, propre à la carte) et reposer la
  carte ; tout texte tronqué est relevé (40 derniers) : **`/slay text`** les liste (avec taille, échelle
  effective), ainsi que les textes visibles tronqués en ce moment ; `/slay art` en donne le
  nombre. **Harnais U33** : faux client défavorable (`H.strictText` : police rendue arrondie au pixel
  supérieur à l'échelle effective, hauteur automatique au plus proche) ; toutes les cartes base et
  améliorées, jouables et injouables, fenêtre 1 / 1,15 / 1,5 / 0,6, aux sept échelles d'écran (main et
  aperçu 1, récompense 1,08, marchand 0,92, grille 0,75, panneau du deck 0,72, progression 0,6, bilan 0,5 ;
  plus d'échelle de survol depuis le 12/11/2026) ; « PW: Radiance » en main levée et au repos ; toutes les
  réponses des rencontres ; tous les textes des visuels survolables. Sur l'ancien code : 2 127 cas tronqués, dont
  PW: Radiance en net à 1 et 1,15 survolée (« 1/2 lignes »), et 24 réponses.
- **Paliers** (retour du troisième essai : « texte trop petit » ; règle de coupure d'avant le retour du
  12/11/2026, remplacée par « Retours à la ligne plutôt que des paliers plus petits » ci-dessous) :
  chaque carte prend le plus grand
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
- **Retours à la ligne plutôt que des paliers plus petits** (retour du joueur du 12/11/2026, capture de
  Freezing Trap survolée : « Apply Stunned 1 ⌛ » / « Apply Demoralized 1 ⌛ » en tout petit au milieu d'un
  panneau vide : « il faut s'autoriser à revenir à la ligne au lieu de réduire le texte »). L'ancienne
  règle collait le verbe à l'état et gardait chaque clause sur une ligne : elle descendait de palier
  plutôt que de couper, alors que le panneau avait de la hauteur libre.
  - **Hauteur de ligne** (constat) : le faux client comptait une ligne de 1,47 cadratin (ascendante +
    descendante de Baloo, hhea) ; la capture montre deux lignes de texte de 7,5 unités à 9 px l'une de
    l'autre pour des glyphes à ~1,25–1,35 px par unité, soit ~0,9–1 cadratin : le client règle
    l'interligne sur la taille de police. En jeu, la mise en page mesure la ligne (`GetStringHeight`) et
    n'a pas changé ; le faux client suit maintenant le client (`H.LINE_EM` = 1, `Sim/ui_harness.lua`).
    La zone (47,5 unités de haut, garde de 0,5 au bas : `W.TEXT_BOTTOM_GUARD`, le bas de l'intérieur
    sombre est mesuré à y ≈ 146,3 et non 147,6) contient donc, palier par palier : 10 → 4 lignes,
    9,5 → 4, 9 → 5, 8,5 → 5, 8 → 5, 7,5 → 6, 7 → 6 (affiché par la section UT du harnais) — et non
    3 lignes comme le laissait croire l'ancien interligne.
  - **Règle** (`layoutBody`, `UI/Widgets.lua`) : pour chaque carte, le plus GRAND palier où le texte tient
    dans la zone (TZ, marges et biseau inchangés), chaque clause commençant une ligne et pouvant se
    replier sur plusieurs ; à ce palier, la mise en page la moins coûteuse. Essais (`W.cardTries`) : les
    clauses repliées à tous les paliers d'abord ; le texte coulé (clauses simples sur une même ligne)
    n'est plus qu'un dernier secours, jamais employé aujourd'hui.
  - **Coupures** (`W.clauseGroups`) : chaque clause est découpée en groupes insécables, chaque espace
    entre deux groupes a un coût (`W.BREAK`) dans l'ordre de préférence : entre deux clauses (0) ; après
    une condition « Name: » (10) ; après une virgule (12) ; entre le verbe et le nom d'état (« Apply » /
    « Demoralized 1 ⌛ », 14) ; avant « to all », « to … », « per … », « once per », « three times »,
    « twice » (18) ; ailleurs (40, dernier recours). Plus : ligne d'un seul mot de trois lettres ou moins
    (60, sauf une condition « DoT: »), ligne finie par un petit mot (« the », « to », « per », 12), lignes
    inégales dans une clause (jusqu'à 10), bloc remonté plutôt que centré (2 à 6). **Jamais coupés** :
    un nombre et ce qu'il compte (« 5 Absorb », « +2 Insanity », « 1 HP », « 2 damage », « 6 more »), un
    verbe et son nombre (« Deal 6 », « Draw 1. », « Pay 3 HP. », « Cooldown 2 »), un nombre et le mot
    d'avant quand rien ne suit qu'il compte (« deal 4 + 4 »), « N times », « once per », un nom d'état et
    son nombre (« Stunned 1 ⌛ », insécable de `W.cardBody`), le sablier et son nombre (icône collée),
    « to all », les noms en plusieurs mots (états, conditions nommées, ressources : « Combo Points »,
    « Arcane Charge », « Last Breath: », « Careful Aim: »). `W.cardBody` ne colle plus le verbe à l'état.
  - **Écart entre clauses** : un tiers de ligne (`W.CLAUSE_GAP`) quand la hauteur et le biseau le
    permettent (sinon l'interligne seul, coût `W.NOGAP_COST` = 3 : préféré à une coupure de plus, pas à
    un bloc remonté de deux crans). Maquette regardée (`build/texte_ecart_clauses.png`) : une clause
    repliée (« Apply » / « Sundered 3 ⌛ ») se lit nettement comme UNE clause, la suivante se détache.
    Une police ne règle pas l'écart d'une seule ligne : avec écart, la carte pose un texte par clause
    (`card.bodyParts`, `W.BODY_PARTS` = 6 textes créés avec la carte, jamais pendant un survol ; sans
    écart, tout dans `card.body` comme avant) ; `W.cardBodyText(card)` rend le texte complet affiché,
    le garde-fou `W.checkCardTexts` vérifie chaque bloc. 168 textes sur 360 ont l'écart.
  - **Répartition** (180 cartes × base / améliorée ; « avant » au même interligne que le client) :

    | Classe | 10 | 9,5 | 9 | 8,5 | 8 | 7,5 |
    |---|---|---|---|---|---|---|
    | Prêtre, avant → après | 50 → 62 | 4 → 0 | 0 → 2 | 7 → 4 | 5 → 0 | 2 → 0 |
    | Guerrier | 58 → 66 | 2 → 2 | 0 | 4 → 0 | 0 | 4 → 0 |
    | Mage | 54 → 52 | 2 → 0 | 2 → 16 | 0 | 0 | 10 → 0 |
    | Voleur | 54 → 54 | 8 → 2 | 0 → 12 | 2 → 0 | 0 | 4 → 0 |
    | Chasseur | 56 → 66 | 4 → 0 | 0 → 2 | 2 → 0 | 0 | 6 → 0 |
    | Neutres | 18 → 20 | 2 → 0 | 0 | 0 | 0 | 0 |
    | Toutes | 290 → 320 | 22 → 4 | 2 → 32 | 15 → 4 | 5 → 0 | 26 → 0 |

    (Avec l'ancien interligne du faux client : 232 / 35 / 13 / 23 / 26 / 31.) Toutes les cartes à 8,5 ou
    plus, 324 sur 360 à 9,5–10 ; plus gros gains (7,5 → 10) : Psychic Scream, Thunder Clap, Blizzard,
    Cone of Cold, Demoralizing Shout, Frost Trap, Frostbolt, Glacial Spike, Concussive Shot, Crippling
    Poison, Smoke Bomb ; Evangelism 8 → 10 ; Freezing Trap 7,5 → 9. **Sous 9,5, et pourquoi** (palier
    maximal vérifié par UT) : Schism et PW: Solace (8,5 : à 9, « Gain » / « Atonement 1 ⌛ » ne tient pas
    contre le biseau du bas, et « Apply Sundered 2 ⌛ » / « Atonement: +1 mana. » pas sur une ligne) ; les
    textes à « +1 Arcane Charge. », « +2 Combo Points. », « Deal 3 three times. » (9 : le nom en deux mots
    et « N times » ne se coupent plus ; l'ancienne mise en page écrivait « +1 Arcane » / « Charge. ») ;
    Penance, Envenom, Secret Technique (9 : cinq lignes, la garde du bas ne les laisse pas à 9,5) ;
    Freezing Trap (9 : « Apply Stunned 1 ⌛ » ne tient pas à 9,5, et quatre lignes butent sur le biseau).
    26 textes perdent ainsi un demi-palier ou un palier par rapport à l'ancienne mise en page, qui coupait
    un nom en deux ou laissait « times. » / « twice. » seul. Aucun texte n'appelle de réécriture.
  - **Biseau** (noté ici, corrigé ensuite) : `W.cardTextHalf` prolongeait la pente du biseau au-dessus de
    son début (y 124 à 133 : jusqu'à 10 unités de moins que l'intérieur sombre, mesuré plein jusqu'à
    y ≈ 133) ; c'est ce qui remontait les blocs en haut de la zone. Remplacé par la forme exacte le
    12/11/2026 (« Texte centré et sablier à la hauteur des chiffres » ci-dessous).
  - **Petites cartes** (grilles 0,75, panneau du deck 0,72, progression 0,6) : la mise en page est en
    unités de la carte, la même à toute échelle : le texte y grandit avec son palier (ou perd le
    demi-palier ci-dessus).
- **Texte centré et sablier à la hauteur des chiffres** (retour en jeu du 12/11/2026, main du Mage,
  fenêtre à 115 % : Frostbolt « Deal 6. » / « Apply » / « Demoralized 1 ⌛ » collé en haut du panneau, vide
  dessous, « le texte est remonté, il ne devrait pas » ; Fireball « Deal 10. » / « Apply DoT 2 » ; le
  sablier à peu près deux fois plus petit que le chiffre voisin, lu comme un « z »).
  - **Cause du bloc remonté (établie)** : la mise en page essayait le bloc centré, puis remonté de
    0,33 / 0,17 / 0 du jeu vertical (`W.BODY_LIFT`), et gardait le premier où chaque ligne tenait dans
    `W.cardTextHalf` jugée au bas de la BOÎTE de la ligne. Ce modèle prolongeait la pente du biseau
    au-dessus de son début : à y 125–133, où l'intérieur est plein, il retirait jusqu'à 10 unités de
    largeur. « Demoralized 1 ⌛ » (67 à 71 unités selon la largeur comptée au sablier) ne tenait donc pas centré et Frostbolt remontait tout en
    haut (y0 = 95, le haut de la zone) : centre de l'encre 7,4 unités au-dessus du centre du panneau.
    Le faux client montrait déjà ce bloc remonté (planche `cartes_mage.svg`) : aucune vérification ne
    regardait la position verticale.
  - **Forme réelle du biseau** (pixels de `Media/card_panel.tga`, critère de U22) : intérieur plein
    (x 14 à 240 sur 256 px, demi-largeur 0,3444) jusqu'à y 1,0735 (133,1 unités) ; là, un
    **décrochement** (le bord gauche passe de x 14 à 25 px d'une ligne à la suivante, demi-largeur 0,3110
    du côté gauche, le plus étroit), puis une pente de 0,557 jusqu'au bas (146,3 unités).
  - **Règle** (`layoutBody`, `W.cardTextHalf`, `UI/Widgets.lua`) : le bloc est **centré sur le centre
    optique** du panneau (`TZ.optY`, milieu de l'intérieur sombre dans la colonne du milieu, 87,1 à 146,3
    unités, mesuré par UC) : haut des capitales de la première ligne et ligne de base de la dernière à
    égale distance des bords (ligne de base aux 1,078 / 1,47 de la ligne, capitales de 0,602 cadratin :
    `W.TEXT_BASE`, `W.TEXT_CAP`, Baloo Chettan 2 ; si une plaque relève le bas de la zone, le centre
    remonte de moitié). Il ne se décale que si une ligne sortirait de la forme (biseau, gemme, bas de
    la zone), du minimum nécessaire, pas à pas de 0,25 et d'**une unité au plus** (`W.BODY_SHIFT`,
    `W.SHIFT_COST` = 2 par unité) ; sinon une autre coupure ou le palier inférieur. Le biseau est jugé
    sur la **forme exacte**, 2 unités sous l'**encre** de la ligne (ligne de base, plus 0,2 cadratin si
    elle a des jambages : `W.lineInkBottom`, `W.DESC_CHARS`), marge latérale de 5,5 unités. U22 vérifie
    de même sur les pixels : rectangle de la ligne (4 unités sur les côtés, 1 en haut) jusqu'à 2 unités
    sous l'encre, et 4 unités sous la boîte de la ligne au milieu (le bas de l'intérieur).
  - **Cause du sablier trop petit (établie par élimination)** : le dessin remplissait 60/64 de la
    texture et la séquence demandait 7 unités pour un texte de 10, plus que les chiffres (6,2) : ni le
    dessin ni le calcul ne le rapetissaient. C'est donc la **hauteur explicite** de la séquence |T que le
    client ne rend pas dans les unités du texte. Le rapport vu (≈ 0,5) correspond à une hauteur prise en
    pixels d'écran : 7 px à côté de chiffres de 6,2 × 1,875 × 1,15 ≈ 13 px (écran de 1440 px de haut,
    échelle d'interface 1, fenêtre à 115 %) ; c'est le modèle du faux client désormais (`H.ICON_PX`),
    qui reproduit la capture (témoin de UC : 51 %). Le mécanisme exact du client reste non documenté.
  - **Correction du sablier** (texture changée : relancer le client) : séquence à **hauteur et largeur
    nulles** (`|T…hourglass.tga:0:0:0:0:64:64:0:64:0:64:r:g:b|t`, `W.hourglass`) : le client donne à
    l'icône la hauteur de la police qu'il rend, carrée, comme les icônes de Blizzard à la taille du
    texte (« |T…:0:0:0:0|t » après un prix, `Blizzard_GarrisonBuildingUI.lua` ; « |T…:0|t » des marques
    du journal de combat). La texture 64 × 64 est la boîte d'une ligne (`tools/build_glyphs.py`) : même
    silhouette, de la ligne de base (y 47) au haut des chiffres (y 7 : 41 texels, 0,64 cadratin, 106 %
    de la hauteur de capitale), x 12 à 41 : la marge de gauche (0,19 cadratin) fait la petite espace
    après le nombre. Planche `build/sablier_planche.png` (`… build_glyphs.py planche`).
  - **Prix en largeur** : la boîte de l'icône fait maintenant un cadratin (0,70 avant), soit 3 unités de
    plus à la taille 10 sur chaque ligne à sablier ; « Demoralized 2 ⌛ » (75,7 unités, marge comprise)
    ne tient plus dans la pleine largeur (74,5) à 10. Une largeur plus étroite que la hauteur
    demanderait un champ largeur explicite, donc soumis au même défaut. Répartition (360 textes) :
    10 / 9,5 / 9 / 8,5 = 330 / 4 / 22 / 4 avant → 316 / 18 / 18 / 8 après ; **334 textes à 9,5–10 avant
    comme après**, aucun sous 8,5. Perdent un demi-palier : Blizzard, Concussive Shot, Demoralizing
    Shout, Glacial Spike, Psychic Scream, Smoke Bomb (et leurs +), Frost Trap+, Thunder Clap+ (10 → 9,5) ;
    Flurry et Freezing Trap (et +) (9 → 8,5). Mises en page changées au même palier : Polymorph (« Apply »
    / « Stunned 2 ⌛ » sur deux lignes), Schism (cinq lignes, « Gain » / « Atonement 1 ⌛ »).
  - **Harnais UC** : voir « Harnais hors jeu ». Planche avant / après :
    `build/planche_texte_centre.png` (Frostbolt, Fireball, Shadowform à quatre lignes, Smite à une
    ligne ; fenêtre 1,15, rendu ×3 ; « avant » = code d'avant, faux client corrigé).
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
- **Zoom** (historique) : de la deuxième à la quatrième version, la carte survolée grossissait (×1,12 à
  ×1,8) selon trois techniques au choix (`/slay zoom` net / fluide / lisse) ; aucune ne gardait un texte
  stable (recalage au pixel à chaque taille). Retiré le 12/11/2026 : voir « Survols (sans agrandissement) ».
- **Carte d'un seul bloc** : le visuel d'une carte (`face`) est agrandi de 0,3 de la largeur de chaque
  côté (`W.CARD_MARGIN`) pour contenir halo, languette de coût, ruban, plaques et étiquette de prix ;
  toutes les pièces et tous les textes sont posés par rapport au corps (`b.bg`, centré sur le visuel).
  (Historique : en zoom animé, ruban et plaque du bas restaient à leur taille de repos pendant que le
  corps grossissait ; d'où ce visuel d'un seul bloc, toujours utile aux vols de cartes.)
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
- **Mots de règle des épiques** (`L.rule(key, { name, text, upText, pattern })`, 14/11/2026) : un nom court
  (vocabulaire de WoW quand il existe ; ni état, ni condition, ni autre mot-clé, ni carte) suivi de son
  nombre, après le déclencheur (« Surge Attacks: Bleed 90%. »). Coloré comme un mot-clé, insécable s'il est
  en plusieurs mots ; à-côté = « Nom: règle complète », une ou deux phrases courtes, 110 caractères au plus,
  majuscule en tête, « N » remplacé par le nombre de la carte, `upText` pour la carte améliorée, `pattern`
  quand deux épiques emploient le même nom (Wild Call). Les autres explications gardent 60 caractères.
- **Mots de la plaque du bas** : « Pouvoir. » et « Incantation. » en tête, « Recharge N. », « Consumée. »,
  « Conservée. » en dernier, chacun sur sa clause ; retirés à l'affichage (`KEYWORD_STRIP`).

### Affichage (`UI/Widgets.lua`)

- `W.cardBody` : mots de la plaque retirés ; nom d'état collé à son nombre par une espace insécable
  (« Douleur 5 », « fracassée 2 ⌛ » ne se coupent pas), « à tous » insécable ; chiffres blancs (verts
  s'ils changent à l'amélioration) ; **noms d'états et conditions nommées en or** (`W.KEYWORD_COLOR` =
  `C.goldText` #ffd660, seule couleur d'accent : la police ne mêle pas deux graisses). Les verbes
  « Donne » / « Applique », l'Absorption et la Démence (ressources) restent dans la couleur du texte.
  Le verbe d'une ligne d'état n'est plus collé à l'état (12/11/2026) : la mise en page peut couper
  « Apply » / « Demoralized 1 ⌛ » (coupure de second choix, voir « Retours à la ligne »).
- **Sablier** (historique : depuis le second retour du 12/11/2026, hauteur et largeur nulles et texture
  boîte de ligne, voir « Texte centré et sablier à la hauteur des chiffres » ; ce qui suit décrit l'état
  d'avant) : « ⌛ » (et l'espace qui le précède) devient à la mise en page une séquence
  `|TInterface\AddOns\SlayTheDragon\Media\hourglass.tga:h:h:0:0:64:64:0:64:0:64:255:255:255|t`
  (`W.hourglass(taille)`) : forme de `CreateTextureMarkup` (Blizzard_SharedXMLBase/TextureUtil.lua, relu
  le 12/11/2026 : chemin, **hauteur**, **largeur**, décalages x et y, largeur et hauteur du fichier,
  gauche, droite, haut, bas en pixels du fichier) plus la couleur de sommet r:g:b (0–255), forme
  qu'emploie Blizzard pour l'icône de l'armurerie dans la discussion (ChatFrameUtil.lua) ; champs entiers
  (`%d` partout chez Blizzard). Chaque champ était bien employé ; la tache floue et rognée vue en jeu
  (capture de Freezing Trap, retour du 12/11/2026) venait du **dessin** : verre en contour de 3 texels
  sur 32 et sable intérieur, réduits à 5–8 pixels (traits d'un demi-pixel, flous) et rognés à 28/32 à
  droite. **Nouveau sablier** (`tools/build_glyphs.py`, texture changée : relancer le client) : toile
  64 × 64, silhouette PLEINE (deux traverses de 8,5 texels, deux triangles opposés pointe contre pointe,
  sans détail intérieur), marges transparentes symétriques (x 11 à 53, y 2 à 62), affichée **entière et
  carrée** (largeur = hauteur, coordonnées 0:64:0:64 : rien n'est rogné ni déformé) ; les marges du
  dessin font la petite espace insécable avant l'icône (elle ne touche plus le chiffre) et après.
  Hauteur = taille × 0,70 arrondie (`W.HOURGLASS_K` ; 6 unités à 8,5–9, 7 à 9,5–10) : le dessin (60/64)
  a au moins la hauteur des chiffres de Baloo Chettan 2 (0,62 cadratin). Planche de contrôle
  `build/sablier_planche.png` (`… build_glyphs.py planche`) : avant / après à 6, 7, 8, 10 et 12 px sur
  l'ardoise, après le chiffre « 1 » de Baloo à la même taille, réduit sans mipmap (le pire cas) et avec ;
  à 7 px et plus le nouveau se lit comme un sablier, à 6 px il reste un « I » à traverses (trop peu de
  pixels). Centrage vertical : sur la ligne (supposé, décalage y nul ; à voir en jeu). La mesure par le
  client (`GetStringWidth`) et celle du faux client (`H.textWidth`) comptent la largeur de l'icône. Les
  infobulles emploient la même icône (`W.inlineIcons(…, 12)` : 8 unités) pour « ⌛: status duration, in
  turns. » et le texte des cartes qu'elles citent.
- **Lignes** (`W.cardTries`, `W.cardParagraphs`, `W.clauseGroups`, `layoutBody`) : depuis le 12/11/2026,
  chaque clause commence une ligne et se replie au besoin, au plus grand palier où le texte tient (voir
  « Retours à la ligne plutôt que des paliers plus petits ») ; texte coulé et états groupés ne sont plus
  qu'un secours après tous les paliers. La ligne d'état commence toujours une ligne et finit le texte.
  Le bloc est centré sur le centre optique du panneau, décalé d'une unité au plus si une ligne sortirait
  de la forme (depuis le 12/11/2026 ; avant, il remontait jusqu'en haut de la zone, `W.BODY_LIFT`) ;
  zone utile `TZ` inchangée. Une couleur coupée par un retour est fermée et rouverte (`W.balanceColors`).
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

## Survols (sans agrandissement, retour du 12/11/2026)

- **Vu** (vidéo du joueur, image par image) : au survol, « Back on the road » grossissait d'environ 4 % ;
  pendant l'animation le texte était étiré, puis redessiné à la nouvelle taille réelle avec d'autres
  largeurs de glyphes : espacement des lettres qui change, texte décalé d'un ou deux pixels. À ces
  échelles, le client recale la police au pixel à chaque taille : aucun réglage ne rend un texte stable.
- **Règle** : plus **aucun agrandissement au survol**, nulle part (boutons, plaques, cases, icônes, étapes,
  cartes, ennemis visés). Le survol se signale comme sur les boutons du jeu, par une **surbrillance**, et
  pour une carte lisible par une **levée**. Aucune `SetScale` ni animation `Scale` au survol : le texte
  survolé est exactement celui du repos (même rectangle, au pixel près ; harnais UX).
- **Mécanique** (`W.hoverable`, `W.faceApply`, `UI/Widgets.lua`) : le cadre qui reçoit la souris ne bouge
  jamais (zone fixe) ; le visuel `face` reçoit la surbrillance (`paint(f, h)`, canal « hover » de 0 à 1) et,
  pour une carte, la levée (`f.hoverLift` × h, `W.setLift`). Canaux `W.animTo` : 0,12 s à l'entrée, 0,15 s à
  la sortie, courbe amortie, réversibles en route ; un seul `OnUpdate` partagé (`W.driver`), coupé quand
  rien ne bouge ; minuteur de secours. Le visuel n'est réancré que si sa position change : un bouton ne
  fait que s'allumer. Levée et écart d'arrivée ramenés à un **nombre entier de pixels** (`W.pixelSnap` :
  unités × échelle effective × hauteur physique ÷ 768, `GetPhysicalScreenSize`) : le texte levé est
  redessiné aux mêmes positions dans le pixel qu'au repos.
- **Boutons** (`W.button`, `W.roundButton` / fermeture, « < » « > », plaques de réponse, service du
  marchand) : comme `SharedButtonTemplate` de Blizzard (`ThreeSliceButtonTemplate` :
  `SetHighlightAtlas("128-RedButton-Highlight")`, mélange ADD ; `HighlightFont` blanche ; fermeture :
  `RedButton-Highlight` en ADD — vu par le MCP, en recherche) : la pièce s'éclaircit (0,86 → 1), sa
  **copie en mélange additif** (`W.lightLayer` : la pièce embarquée elle-même, `SetBlendMode("ADD")`, alpha
  0 → `W.LIGHT_ADD` = 0,32) en garde la forme, le **liseré d'or** s'allume (bouton rouge : le rouge et or
  par-dessus, déjà embarqué) et le libellé passe de l'or au blanc. Aucune texture nouvelle (la pièce
  « 128-RedButton-Highlight » n'est pas embarquée : la copie additive de la pièce du bouton en tient lieu).
  **Clic maintenu** (`W.pressable`) : bouton assombri (×0,8), rien ne bouge. **Inactif** (`SetActive(false)`,
  réponse impossible, clé verrouillée, service trop cher) : rien ne s'allume.
- **Éléments sans texte ou à nombre** : cases de bibelots, de potions, de clé, pioche / défausse /
  consumées, jetons d'état, butin et objets du marchand : cadre doré de case (`slot_hover`, créé d'avance) ;
  médaillons (affixes, coffre, couchage) et icônes de classe : halo doré ; étapes du parcours : lueur dorée
  (plus vive si accessible) ; dos de carte (bandeau, tas du deck) : copie additive du dos ; carte verrouillée :
  dos éclairci. Rien ne grossit ni ne se soulève.
- **Cartes lisibles** (échelle de base ≥ `W.PREVIEW_BELOW` = 0,9 : main 1, récompense 1,08, marchand 0,92) :
  **levée** de `W.CARD_LIFT` = 12 unités de la scène (nombre entier de pixels à l'arrivée), **halo doré**,
  passage **devant** les voisines (`W.cardFront`) ; carte sélectionnée ou glissée : même état. Main : zone
  de survol prolongée vers le haut de la levée (`SetHitRectInsets`) ; les voisines ne s'écartent plus.
- **Petites cartes** (grille d'amélioration / de retrait 0,75, panneau du deck 0,72, progression 0,6,
  bilan 0,5) : halo, carte immobile, et **aperçu à taille réelle** (`W.cardPreviewShow`) : une vraie carte à
  l'échelle 1, **une seule instance** pour la fenêtre (`W.buildCardPreview`, construite avec la fenêtre,
  jamais pendant un survol), sur `UI.overlay` (au-dessus du contenu rogné, des modèles 3D, du bandeau et
  de la barre de titre ; à 8 unités des bords, sous les filets sans les toucher), à côté de la carte du
  côté où il y a la place, en fondu (canal « show », alpha du visuel). Elle montre la carte telle qu'elle
  est affichée (aperçu « Upgraded » de la grille d'amélioration compris). L'infobulle des mots-clés se
  place à côté de l'aperçu, du côté opposé à la carte (`tooltipSpot` de `W.tooltip`). Carte verrouillée de
  la progression : pas d'aperçu (infobulle de condition seule).
- **Ennemi visé** : son anneau s'allume ; il ne grandit plus.
- **Ce qui change encore d'échelle** : les vols de cartes seulement (`W.fly` : pioche → main, main → cible
  ou défausse, échelle réelle de départ pendant le vol, animation `Scale` du cadre, textes en mode Vertex ;
  à l'arrivée, animation coupée et échelle réelle d'arrivée posée une fois : texte net), le coffre qui
  s'ouvre et les badges qui « sautent » (animations ponctuelles hors survol).
- **Retiré** : `/slay zoom` (net / fluid / smooth / slow) et ses options (`options.zoom`, `options.zoomSlow` :
  une valeur enregistrée est ignorée et effacée) ; `W.zoomMode`, `W.setZoomMode`, `W.zoomSlow`,
  `ZOOM_MODES` ; les animations `Scale` de survol (`zoomTo`, `stopZoom`, `holdTo`, `applyFluid`, armement
  `face._armed`, repose à l'`OnShow`) ; `W.faceBuild` ; `W.setHover` (échelle) remplacé par `W.setLift` ;
  `hoverScale` partout (`HOVER_SCALE` de la main, `PG_ZOOM`, `CP_ZOOM`) ; l'écart des voisines (`V:Spread`) ;
  l'agrandissement de l'ennemi visé (`AIM_SCALE`) ; la vérification des textes après la bascule du zoom.
  Gardés : `W.noSnap` (rien ne tressaute pendant une levée ou un vol), `SetSmoothScaling` et le mode
  Vertex des textes (vols, fenêtre à l'échelle), `W.looseBox`, le garde-fou de troncature.
- **Harnais** : UX (12 écrans, 245 éléments survolés : aucune échelle changée dans tout le sous-arbre, ni
  pendant ni après ; éléments à texte immobiles, texte au même rectangle au pixel près, surbrillance
  allumée puis éteinte, inactif éteint ; éléments sans texte allumés ; cartes lisibles levées, halo,
  devant ; petites cartes immobiles avec aperçu à taille réelle dans la fenêtre, texte entier, infobulle à
  côté ; cartes verrouillées sans aperçu ; une seule instance ; clic maintenu assombri) ; U18 (levée
  entière en pixels aux fenêtres 0,85 à 1,5, vol posé une fois, `/slay zoom` retiré) ; U26 (vols, carte
  levée dans la fenêtre) ; U34 (textes aux sept échelles d'écran) ; UP (aperçu sur l'écran de
  progression). Aperçus : `survol-boutons` (repos / survolé), `survol-apercu-progression`, `combat-survol`.
- **À voir en jeu** : intensité de la surbrillance additive (`W.LIGHT_ADD`) — le rendu hors jeu l'approche
  par un mélange « screen », plus doux que l'ADD du client ; texte parfaitement immobile au survol des
  boutons ; levée des cartes nette ; aperçu des petites cartes à côté (grille, panneau du deck,
  progression), jamais coupé par le bord ni sous un modèle 3D.

## Retours du premier essai (survols, deck, paysages, bandeau, vouvoiement)

- **Survols animés partout** (`W.hoverable`) : zone de survol fixe, visuel `face` animé, canaux réversibles
  et pilote partagé. (Agrandissements d'alors — main ×1,16, boutons ×1,04–1,06, étapes ×1,18, ennemi visé
  ×1,07 — retirés le 12/11/2026 : voir « Survols (sans agrandissement) ».)
- **Consulter ses cartes** (`UI.deckView`, fin de `UI/Screens.lua`) : panneau de bois par-dessus
  l'écran (sous le bandeau), titre court « Deck · 18 cartes » / « Pioche · … » / « Défausse · … » /
  « Consumées · … », grille de vraies cartes (`W.card`, 8 par rangée, 3 rangées visibles, ×0,72),
  triées par type (Sort offensif, Sort, Pouvoir), coût, nom (puis non améliorée avant améliorée) ;
  améliorées en vert comme ailleurs. Molette : une rangée par cran (indicateur à droite si ça déborde) ;
  défilement partagé avec la grille du deck (`RowScroll`, voir « Grille du deck défilante »).
  Fermeture : clic hors du panneau (voile), clic droit sur une carte, « Fermer », nouveau clic sur ce
  qui l'a ouvert, ou `Échap` qui ferme la fenêtre entière. Accès : tas du deck du plateau (récompense, feu de camp, marchand,
  grilles) et deck du bandeau (dos de carte et nombre), désormais **aussi en combat** (deck complet) ; en combat,
  clic sur la pioche (**toujours triée**, jamais l'ordre de tirage), la défausse, et le nouveau tas
  violet des **consumées** (x 151–187, affiché dès qu'il y en a une).
- **Grille du deck défilante** (écran `deck` de `UI/Screens.lua` : amélioration ou copie d'une rencontre,
  méditation au feu de camp, retrait chez le marchand ; 14/11/2026, remplace les pages à flèches « < » « > ») :
  8 cartes par rangée à ×0,75, 2 rangées visibles dans le panneau ; au-delà de 16 cartes, la molette (sur
  l'écran, le panneau ou une carte) avance d'une rangée par cran. Mécanisme commun avec le panneau des cartes :
  `RowScroll` (haut de `UI/Screens.lua` : `new(panel, parRangée, rangées, réserve, layout)`, `Hook`, `SetCount`,
  `First`, `Scroll`, `PlaceBar`). Défilement **par rangées entières** : les cartes hors de la fenêtre sont
  cachées, aucune n'est rognée, donc aucune moitié de carte ne capte la souris hors du panneau, et le halo, la
  carte au premier plan et l'aperçu à taille réelle restent entiers. Indicateur commun aux deux écrans : rail
  sombre et curseur doré au bord droit du panneau, seulement si tout ne tient pas (16 cartes ou moins : rien ne
  change à l'œil). Carte survolée pendant un cran : sa sortie puis son entrée sont rejouées, l'aperçu de
  l'amélioration (`Deck:Preview`), l'aperçu à taille réelle et l'infobulle suivent la nouvelle carte. Position
  gardée tant que l'étape est la même (rafraîchissement, fenêtre fermée puis rouverte) ; en haut pour une
  nouvelle étape (autre titre ou sorte, ou écran quitté entre-temps : `Deck:OnHide`). Harnais : section UDP
  (deck de 28 cartes : molette, carte de la 3e rangée choisie au clic souris réel `H.mouseClick`, feu de camp
  et marchand jusqu'à la dernière rangée, aucune carte hors du panneau, position gardée après `UI.refresh()`,
  retour en haut après « Back » ; aperçus `grille-deck-defilante-haut` / `-bas`) ; U19 pour le panneau des cartes.
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
  4 fonds × 2 Mo ≈ 8,4 Mo (5 avant le retrait d'Elwynn, 13/11/2026).
- **Affichage** : le fond embarqué est en tête de la liste de chaque illustration (`Art.illustrations`) ;
  `Scene.chosen` prend le premier candidat qui est embarqué ou validé. Teinte par scène (`tint`), voile
  sombre léger sur les 170 px du bas (sol des personnages, `Scene.ground`, 38 % au bas), décor peint
  dessous. `/slay decor` (ou Options → « Décor illustré ») bascule illustré / peint ; `/slay art` liste
  les fonds embarqués, leur FileDataID et leurs scènes.

| Fond (`Media/Backgrounds`) | FileDataID | Illustration | Scènes (`focus`) |
|---|---|---|---|
| `farm.tga` | 407226 | Pics-Jumeaux : chaumière, chemin, charrette | farm 0,55 |
| `deadmines.tga` | 131833 | Mortemines (écran classique, navire dans la grotte) | mine 0,5 |
| `ruins.tga` | 7963782 | Ruines de Lordaeron (écran Forever) | ruins 0,5 |
| `coast.tga` | 427941 | Gilnéas : phare sur la côte | coast 0,45 |

**13/11/2026 : `elwynn.tga` (7377860, forêt d'Elwynn) est supprimé** (fichier, entrée d'`Art.backgrounds`,
liste d'`Art.illustrations` avec ses candidats du client 7377860, 7963776, 131839, et fabrication dans
`tools/build_backgrounds.py`, où il ne reste qu'en « écarté » sur la planche). La route, la colline, le
camp, le marchand et le feu de camp de Westfall sont des **décors peints** (ci-dessous). La liste d'essai
`/slay scenery test` passe de 8 à 4 candidats (Mortemines, ruines). Les fonds embarqués passent à 4
(≈ 8,4 Mo).

Écartés (planche) : Excavation 7963777 (sépia, sans ferme), Bassin d'Arathi 2820825 et les autres
écrans larges BfA (logo en haut), mine gobeline 2016712 (trop sombre, logo), cité en ruine 131866,
Gilnéas la ville 405445 et Manoir Malvoie 1984118, carte des royaumes de l'Est 7963776 (carte, pas
paysage), Goulet des Chanteguerres 2827086 (personnages au premier plan), Elwynn 7377860 (pas Westfall).
Limites : les Mortemines sont un croquis au trait, d'un autre style que les autres ; la ferme (Pics-Jumeaux)
et la côte (Gilnéas, pins, gris-bleu) ne sont pas de la Marche de l'Ouest (hors de la décision du
13/11/2026, qui ne visait que la route, la colline, le camp, le marchand et la nuit).

### Décors peints de Westfall (13/11/2026)

Décision du joueur : pas d'illustration de la Marche dans les fichiers du jeu, donc un décor peint couleur
blé, soigné. `Art.paintings` (UI/Art.lua) décrit cinq paysages, `Art.palettes` leurs couleurs (jour :
blé jaune-ocre, ciel bleu pâle chaud, horizon plat et doré ; nuit : la même composition assombrie, ciel
bleu nuit, étoiles, lune, fenêtres éclairées). `S.landscape` (UI/Scene.lua) les peint par plans, chacun
à sa couche et son sous-niveau (`S.LANDSCAPE_LEVELS` ; BACKGROUND -8 à 7 puis BORDER -8 à -3, sous
l'illustration) :

1. ciel en deux dégradés ; soleil (disque, double halo fondu) ou lune et étoiles ; nuages en taches
   fondues (texture de l'ombre de contact, `Media/shadow_soft`) ;
2. deux rangées de collines basses, brumeuses ; la colline de Sentinel Hill (scène `westfall_hill`) avec
   flanc à l'ombre et sentier en lacet ; bosquets sur l'horizon ;
3. champs lointains en damier (rangées plus hautes vers l'avant, dégradés qui se raccordent, haies
   légères) et brume de l'horizon ;
4. silhouettes lointaines posées sur la ligne des champs proches : moulin (tour qui s'affine, ailes à
   claire-voie tournées), ferme et grange (toit en losange caché à moitié par le mur), tour de Sentinel
   Hill avec bannière ;
5. champs proches : dégradé, rangs du blé qui fuient vers l'horizon (plus épais devant), ombres de nuages,
   ondulations ; route en perspective (tranches fines, largeur proportionnelle à la distance) ;
6. plan moyen : épouvantail, barrière, tentes (triangles en tranches), charrette (chargée de caisses chez le
   marchand), foyer et fumée ; ombre fondue au pied ;
7. voile sombre du bas (sol des personnages) ; épis à contre-jour dans les coins.

Rien n'est tiré au hasard (suite fixe). Chaque paysage est construit à son premier affichage (300 à 700
régions). Les scènes sont **portées par la zone** : `ns.Zones.westfall.scenes = { road = "westfall_road",
hill = …, camp = …, shop = …, night = "westfall_night" }` (Data/Zones/Westfall.lua) ; `UI.setStage` et
`Controller.scene()` passent par `Controller.zoneScene` ; les décors communs `road`, `hill`, `camp`,
`shop`, `night` sont ceux de Westfall (accueil, zone sans décor propre). `/slay scenery` est sans effet sur
ces décors (rien à illustrer). Planche : `lua5.1 Sim/ui_harness.lua 1 build/snap` écrit
`build/snap/decor-westfall_*.svg` (section UW), puis `rsvg-convert` ; la planche assemblée du 13/11/2026
est `build/decors_westfall.png` (hors dépôt). Le faux client du harnais connaît désormais `CreateColor` et
le rendu SVG dessine les dégradés (`SetGradient`), comme le jeu.

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
| `UI/Art.lua` | Palette, textures, décors (`Art.scenes`, paysages peints `Art.paintings` et leurs palettes `Art.palettes`), personnages de rencontre (`Art.npcs`), sons, icônes (cartes, états, intentions, affixes, bibelots, potions, parcours ; champ `tga` = icône améliorée), couleur du corps des cartes, gemmes, teintes des liserés, mots-clés, animations | non |
| `UI/Persist.lua` | Chargement de `SlayTheDragonDB` par `Save.migrate`, options de l'interface (`db.options`, dont `decor` et `artChecks`) | non |
| `UI/Controller.lua` | Couche mince écrans ↔ `Core/Expedition` (étapes génériques, combat, potions, fin, validation, décor de l'étape, mana max, nom du boss) | non |
| `UI/Widgets.lua` | Habillage WoW (pièces de `Media/WowUI` : cadres à pièces, trois et neuf tranches, dialogues, parchemins, boutons rouges, cases, curseurs, barres d'unité), peau des cartes (textures de `Media/`), polices, sons, pilote d'animations (interpolations, canaux animés), survols (zone fixe + visuel `face`), icônes (améliorées d'abord), carte unique composée, jauges de vie, hexagone d'Absorption, jetons d'état, boutons, infobulles, textes flottants, modèles | oui |
| `UI/Scene.lua` | Décor (fond embarqué cadré et teinté, voile du bas, décor peint dessous ; paysages peints par plans, `S.landscape` ; repli : candidat du client validé par l'essai manuel ; rapport `/slay art`), plateau, personnages (modèle, ombre, anneau de cible) | oui |
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
combat compris ; infobulle = contenu du deck ; clic = panneau du deck) ; au centre la zone et sa place dans
la campagne (« Duskwood · 2/7 ») puis, ailleurs, les pastilles de progression de la carte de vol sur la même ligne ;
à droite la clé mythique (case à l'icône de la clé, « +N », infobulle = affixes), les bibelots (cases au
cadre teint à la rareté), 3 fioles (potions), « Menu » (options), fermeture. Détail : « Habillage WoW ».

| Phase / vue | Écran | Contenu |
| --- | --- | --- |
| aucune expédition | **Accueil** (`start`) | décor voilé, héros ; parchemin : titre, classes (icônes), la campagne (sept plaques non cliquables : boss battu, atteinte, pas atteinte ; « Campagne continue »), clé +0…+5 de la classe (verrouillées sombres ; infobulle = affixes et raison), icônes d'affixes de la clé choisie ; plateau : « Progress », dernière expédition et avertissements de sauvegarde, « Partir en expédition » |
| `start` | **Rencontre** (`choice`) | bibelot au choix (zone 3 gagnée par le compte) : bulle, une plaque par bibelot (icône, nom, effet), « Partir sans bibelot » |
| `map` | **Parcours** | parchemin sans décor ; étapes en symboles (icône du type dans un disque, « ? » pour une rencontre) ; accessibles : halo doré, couleur du type ; franchies : disque rouge coché ; position actuelle : plus grande, bord doré, anneau crème ; à venir : disque beige, icône ternie (élite : bord violet) ; boss : losange rouge « Boss », icône du boss de la zone (`Art.ui.mapBoss.<zone>`, repli VanCleef) et nom du boss ; chemin parcouru en trait rouge plein, départs possibles en pointillés dorés, le reste en pointillés bruns. Aucune légende ; infobulle = nom du type |
| `combat` | **Combat** | voir plus bas |
| `reward` | **Récompense** | décor du combat, héros ; 3 cartes en grand (survol : plus grandes) ; butin au sol à droite : bourse avec montant, bibelot, fiole (« Pas de place » si les emplacements sont pleins) ; plateau : tas du deck, « Reprendre la route ». Coffre (`chest`) : un coffre à ouvrir d'abord (clic). Rencontre : bulle du texte après coup |
| `campfire` | **Feu de camp** | décor de nuit, modèle 3D d'un feu de camp du jeu (`Art.campfire`, lueur orange au sol, médaillon du feu de camp en repli), couchage (« +N PV » calculés par le moteur) = repos, grimoire (« Améliorer une carte ») = grille d'amélioration, « Reprendre la route » |
| `merchant` | **Marchand** | étal (tenture, comptoir) : 5 cartes de classe + la carte neutre en 6e (corps vert sauge, ligne « Neutral » en infobulle) avec étiquette de prix (rouge si trop cher, « Vendu »), bibelots puis fioles à droite avec prix ; plateau : tas du deck, plaque « Retirer une carte » avec son prix, « Partir » |
| `event` | **Rencontre** | décor `scene`, héros à gauche, personnage à droite (modèle d'`Art.npcs[npc]` en fondu dès qu'il est chargé, médaillon à son icône si aucun candidat ne charge), nom (`speaker`), bulle (titre + texte ; bord doré si `rare`, violet si `story`) ; plaques de réponses à la place de la main : libellé et l'issue sur une ligne (verte si elle commence par « + », « ? » si cachée), réponses impossibles grisées avec leur raison ; après coup : `exp.event.result` et « Continuer » |
| `select`, amélioration, retrait | **Grille du deck** (`deck`) | panneau de bois sur le décor voilé, titre court, cartes à 75 % (8 par rangée, 2 rangées visibles, défilement à la molette au-delà de 16 : « Grille du deck défilante ») ; amélioration : la carte survolée montre sa version améliorée ; plateau : « Retour » / « Passer » |
| `transit` | **Entre deux zones** (`transit`) | décor de la zone suivante, héros ; panneau : nom de la zone, pastilles de la campagne, soin du passage, déblocages du boss vaincu montrés (vitrine `Shelf` : cartes, cases) ; « Continue » |
| `done` | **Bilan** (`end`) | parchemin : titre (vert ou rouge), jusqu'où (zone atteinte, zones battues), premiers boss de la classe (victoire contre Nefarian : titre Dragonslayer de la classe, Rallying Cry du compte), barre du niveau de la classe, déblocages des boss battus regroupés et montrés (vitrine `Shelf`) ; « Nouvelle expédition », « Progress » |
| vue méta | **Journal** (« Log ») | barre du niveau de la classe, boss battus, zone la plus loin, 8 dernières expéditions (zone atteinte, boss battus) ; « Retour » |

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
  Quadrupède long (`art.wide`, crocilisques 1,6) : `Scene.setWide` élargit cadre et modèle en largeur seulement
  (centrés, même hauteur) et pose `SetViewInsets` de l'excédent : vue projetée = cadre de base, taille apparente
  inchangée (raison et sources dans le commentaire de `Scene.setWide` ; harnais U28W).
  Sans modèle : médaillon argenté à l'icône de l'ennemi (`Art.enemies[id].icon`), ou disque sombre.
- Plateau : orbe de mana « 2/3 » (mana max lu par `Combat.modify(c, "maxMana", …)`), pastille Démence
  (cachée à 0), pioche, défausse et consumées (tas avec nombre ; infobulles : contenu trié ; clic =
  panneau des cartes, pioche triée), main en arc au centre (cartes droites ; la survolée se lève de 12,
  halo allumé, passe devant — animé, sans échelle), mini-cartes des recharges (tours restants),
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
| `parry` | « Parry » au héros | `block` |
| `trap` | nom de la Trap sur l'ennemi qui l'a déclenchée | `interrupt` |
| `interrupt_prevented` | nom du bibelot qui l'a empêchée, au héros | `block` |
| `enemy_turn_skipped` | « Skips its turn » sur chaque ennemi vivant | — |
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
  **Remplacé le 12/11/2026** : voir « Feu de camp, personnages des rencontres, préchargement » (délai
  de 2 s, repli après tous les candidats, gagnant mémorisé, `/slay models` ligne par ligne).
- Les **animations** des modèles (0 attente, 1 mort, 6 à terre, 9 encaisser, 16 frapper, 25 prêt, 53/54
  sorts), l'orientation (`/slay facing`) et le cadrage des modèles dans leur cadre (pieds au sol ?).
- La **peau** : chargement des TGA de `Media/` (aplat vert = fichier absent ou mal lu), des masques TGA
  (icônes rondes, carrées arrondies, ouverture du médaillon), de la police Baloo Chettan 2 (sinon Friz
  Quadrata) ; netteté des cartes au survol ; matières répétées sans couture (`"REPEAT"`) ; rognage de la fenêtre (`SetClipsChildren`) sans effet de bord (la carte
  qu'on glisse hors de la fenêtre disparaît : voulu).
- Survols sans agrandissement (voir « Survols (sans agrandissement) ») : texte des boutons immobile,
  surbrillance additive assez visible, levée des cartes nette, aperçu des petites cartes. Le décalage des
  cartes de récompense (`SetScale` + `SetPoint` divisé par l'échelle) : calculé.
- Le zoom des survols (mode `net` : animation Scale + textes Vertex pendant le mouvement, échelle réelle
  posée à l'arrivée) : fluidité, textes immobiles pendant l'agrandissement, aucun sursaut ni clignotement à
  l'arrivée (moment de la bascule), texte net une fois agrandi ; `/slay zoom` pour comparer avec `lisse`. Le décalage des cartes de récompense (`SetScale` + `SetPoint` divisé par l'échelle) : calculé.
- Le **sablier** dans le texte des cartes (séquence |T à 14 champs, **hauteur et largeur nulles** depuis
  le second retour du 12/11/2026, texture = boîte d'une ligne) : à la hauteur des chiffres (et non plus
  la moitié), **posé sur la ligne de base** (supposé : le client donne à l'icône la hauteur du texte et
  la pose sur la boîte de la ligne, ligne de base aux 1,078 / 1,47 de la ligne comme le faux client ;
  si le dessin flotte au-dessus ou plonge sous les lettres, déplacer le dessin dans
  `tools/build_glyphs.py`, `Y0`/`Y1`), une petite espace avant lui, et la forme 14 champs acceptée avec
  une hauteur nulle (Blizzard n'emploie la hauteur nulle qu'en 2 ou 5 champs). Voir « Texte centré et
  sablier à la hauteur des chiffres ».
- Le **centrage** du texte des cartes (même section) : bloc centré à l'œil dans le panneau ; dépend de la
  position de la ligne de base dans la ligne chez le client (modèle 1,078 / 1,47, non vérifié).
- La mise en page des textes de carte : mesurée par le client (`GetStringWidth`, `GetStringHeight`,
  `GetNumLines`, `IsTruncated`) ; hors jeu, seules les métriques du faux client (Baloo Chettan 2, ligne
  d'un cadratin depuis le 12/11/2026, d'après la capture) la vérifient. À voir : l'interligne réel
  (`/slay text` ne le dit pas ; quatre lignes de texte 10 doivent tenir dans le panneau, centrées), les
  coupures (« Apply » / « Demoralized 1 ⌛ » / « to all ») et l'écart d'un tiers de ligne entre clauses.

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
et `/slay art` ; modèles (essais créature puis affichages, médaillon de repli après tous les candidats, relance tardive,
`OnModelLoaded`, attente invisible puis fondu, gagnant mémorisé, préchargement, feu de camp, lignes de `/slay models`) ; noms des ennemis (1 à 6 ennemis × échelles 0,6 / 1 / 1,5 :
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
plancher affichées, au moins deux tiers à 8,5 ou plus, relevé carte par carte avec `SLAY_TIERS=fichier` ; textes d'une carte fraîche visibles ; polices reposées à l'ouverture) ; survols sans échelle (U18 : visuel levé sans échelle, réversible, levée entière en pixels aux fenêtres 0,85 à 1,5, carte devant, voisines immobiles, boutons allumés sans bouger, `/slay zoom` retiré, vol posé une fois, ennemi visé sans échelle ; U26 : plus de modes de zoom, aucun cadre enfant dessiné sous un visuel, vols, carte levée de la main dans la fenêtre à toutes les places, noms abrégés ; UX : voir « Survols (sans agrandissement) ») ; premier survol (U23 : carte, carte injouable, bouton doré, bouton rond, objet et carte du marchand, service, couchage, plaque de réponse, étape du parcours — halo éteint avant, borné et parti de 0 à la première image, aucune région créée pendant une animation d'échelle sur tout le harnais, toutes les pièces dans le visuel animé avec la même échelle effective une fois arrivé) ; plaque du bas (U22 : zone utile vérifiée sur les pixels de `card_plate.tga`, toutes les cartes et combinaisons réelles plus un cas extrême, plaque visible devant le corps ; raisons d'une carte injouable dans leur plaque) ; plaques de réponse (U24 : toutes les réponses de `Data/Events.lua`, possibles et impossibles) ; mots-clés (U25 : une ligne de 60 caractères au plus) ; **langage des cartes** (U27 : chaque état posé
plancher affichées, au moins deux tiers à 8,5 ou plus, relevé carte par carte avec `SLAY_TIERS=fichier` ; textes d'une carte fraîche visibles ; polices reposées à l'ouverture ; chaque bloc du texte, s'il y a un écart entre clauses, vérifié de même, dans l'ordre, à l'écart prévu) ; **texte replié** (UT : lignes que la zone contient à chaque palier ; pour chaque carte de chaque classe et les neutres, base et améliorée : palier ≥ 8,5 (exceptions justifiées : aucune), palier maximal effectivement choisi (aucun palier plus grand ne tient, quelle que soit la coupure permise), coupures permises seulement — jamais un nombre séparé de ce qu'il compte, un verbe de son nombre, un nom en deux mots coupé, un sablier ou un petit mot seul —, nature des coupures comptée et coupures de dernier recours listées ; ordre des coûts ; groupes insécables de clauses types ; planche `cartes_priest.svg` et gros plan `texte_gros_plan.svg`) ; zoom net (U18 : animation Scale en route, échelle réelle 1 ; à l'arrivée échelle réelle = échelle de survol et aucune animation, bascule dans le même pas sans saut ; sortie depuis l'échelle réelle, facteur 1 au départ ; réversible en route et au pas de la bascule ; mise en page des textes identique au repos, pendant et après ; témoin : sans `SetSmoothScaling`, le faux client arrondit la hauteur de police à l'échelle réelle et les largeurs changent ; vol de carte posé net ; cycle `/slay zoom`, ancienne valeur `anim`) ; zoom fluide et saut du mode net (U26 : sauvegarde ; repos identique au net à ±0,01 sur 99 régions ; survol sans `SetScale`, arrivée identique au net ; sortie ; cible changée en route ; fenêtre cachée puis remontrée ; carte jamais montrée ; plaques créées après l'armement ; vols ; écrans construits en fluide sans région née sous une animation ; aucun cadre enfant dessiné sous un visuel ; bascule du mode net sans déplacement ajouté ; carte survolée de la main dans la fenêtre à toutes les places ; noms abrégés) ; premier survol (U23 : carte, carte injouable, bouton doré, bouton rond, objet et carte du marchand, service, couchage, plaque de réponse, étape du parcours — halo éteint avant, borné et parti de 0 à la première image, aucune région créée pendant une animation d'échelle sur tout le harnais, toutes les pièces dans le visuel animé avec la même échelle effective une fois arrivé) ; plaque du bas (U22 : zone utile vérifiée sur les pixels de `card_plate.tga`, toutes les cartes et combinaisons réelles plus un cas extrême, plaque visible devant le corps ; raisons d'une carte injouable dans leur plaque) ; plaques de réponse (U24 : toutes les réponses de `Data/Events.lua`, possibles et impossibles) ; mots-clés (U25 : une ligne de 60 caractères au plus) ; **langage des cartes** (U27 : chaque état posé
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
avances des glyphes de Baloo Chettan 2 (`Sim/baloo_metrics.lua`), une ligne d'un cadratin (`H.LINE_EM` :
l'interligne du client, mesuré sur une capture ; le fichier généré donne 1,47, la hauteur hhea),
retours explicites puis par mots, icônes |T comptées à leur largeur (hauteur nulle : la taille du texte ;
hauteur explicite : en **pixels d'écran**, `H.ICON_PX`, modèle qui reproduit le sablier deux fois trop
petit vu en jeu le 12/11/2026), et simule les animations Scale. Il gère aussi `OnSizeChanged`, `GetChildren`, `IsObjectLoaded`
(fichiers `H.unloaded` jamais chargés) et `C_Texture`. Graine 1 : ALL PASS sous lua5.1 et luajit.
**UC** (avant U16) : centre optique mesuré sur les pixels du panneau ; bloc du texte centré à ±1 unité
(haut des capitales de la première ligne, ligne de base de la dernière) sur toutes les cartes de 1 à 4
lignes, base et améliorées, avec un témoin (l'ancienne position de Frostbolt, refusée) ; chaque sablier
posé (fenêtre 1, 1,15 et 0,6) d'au moins 90 % de la hauteur de capitale, posé sur la ligne de base, avec
un témoin (l'ancienne séquence à 1,15 : 51 %) ; planche `texte_centre.svg`.
**UG** (avant U16) : crans de la ressource pour les cinq classes (aucun pour le Priest, alvéoles = plafond,
visibles à 0, remplissage et vidage en fondu avec valeur intermédiaire au pilote, éclat au remplissage
seulement, aucune échelle, gemme embarquée teinte de la ressource, à gauche de la main) ; textes
flottants (Parry par le vrai tour ennemi du Rogue, nom de la Freezing Trap posée par l'interface,
interruption sans effet, tour sauté, retours existants) ; liseré Instant et « Cast · Instant » (toutes
les cartes Cast sans coupure de plaque, carte jouée résolue tout de suite) ; « Spend 2: » allumée,
éteinte, éteinte sous Maj ; Traveler's Backpack (Warrior et Priest : choix ouvert, liserés, infobulle,
clic droit, carte gardée, « Keep none », sans bibelot pas de choix). Le jeu par clics du harnais
choisit la carte gardée du bot quand le choix s'ouvre.

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

Westfall réelle (13/11/2026 ; `Media/Backgrounds/elwynn.tga` supprimé : relancer le client pour que
l'ancien fichier ne serve plus) : accueil, route, Sentinel Hill, camp, marchand et feu de camp en champs de
blé peints (voir « Décors peints de Westfall ») ; l'ennemi « Defias Highwayman » à la place du Defias
Bandit ; dans les rencontres, Farmer Furlbrow, Verna Furlbrow, Scout Galiaan, Thor, Innkeeper Heather,
Captain Grayson, Defias Profiteer, Farmer Saldean. Puis `/slay models` : recopier les lignes `npc:` en
« fallback » ou chargées par un affichage de secours (Furlbrow 237, Verna 238, Grayson 392 ne sont dans
aucun cache : ils dépendent du serveur).

Avant tout (survols sans agrandissement, 12/11/2026 ; `/reload` suffit) : fenêtre à 115 % puis à 100 % et
150 %, survoler lentement les boutons (« Back on the road », « End Turn », « Menu », ×, réponses des
rencontres, service du marchand) : **le texte ne bouge plus d'un pixel ni ne change d'espacement**, le
bouton s'éclaircit, son liseré d'or s'allume, le libellé blanchit ; clic maintenu : bouton assombri ; bouton
inactif : rien. Cartes de la main, de la récompense et du marchand : la carte se soulève et son halo
s'allume, texte net ; grille d'amélioration, panneau du deck, progression : la petite carte ne bouge pas,
un aperçu à taille réelle apparaît à côté (entier dans la fenêtre, au-dessus des modèles), l'infobulle des
mots-clés à côté de lui. **Aucun texte ne finit par « … »** (texte du panneau, nom du ruban, plaque du bas,
raison en rouge) ; « PW: Radiance » montre ses deux lignes. Dire si la surbrillance est trop faible ou trop
forte (`W.LIGHT_ADD`). Réponses des rencontres : libellé et texte dessous entiers, texte toujours juste sous le
bouton (pas décalé vers le bas). Puis **`/slay text`** : « no truncated text found so far » attendu ; sinon
recopier la liste (chaque ligne donne la carte, le texte, la taille et l'échelle ; la carte
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
3. **Cartes** : nettes au repos et au survol (levées, sans agrandissement) ; texte plus grand (le plus grand palier qui tient : 10 sur les textes courts) et noms « MdP : … » / « MdlO : … » ; icône ronde bien dans
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
1. **Décors de Westfall** (13/11/2026 : `elwynn.tga` supprimé, relancer le client) : l'accueil, la route,
   la colline (Sentinel Hill), le camp, le marchand et le feu de camp montrent-ils les champs de blé peints
   (ailes du moulin et toits bien tournés, dégradés du ciel, pas de rectangle noir ni de forme à plat) ?
   La ferme, la côte et le boss gardent leur illustration. Recopier `/slay art` en cas de doute.
2. **Paysages** : la ferme, la côte et le boss : l'illustration a-t-elle du sens derrière les personnages
   (bien cadrée, personnages lisibles) ? Sinon dire laquelle et ce qui cloche (trop haut / trop bas / trop
   clair) ; `/slay decor peint` revient au décor peint.
3. **Survols** : passer lentement puis vite sur les cartes de la main : la carte se soulève et s'allume en
   ~0,1 s **sans que le nom, le coût ni le texte changent**, passe devant ; ressortir en cours de route la
   fait redescendre sans à-coup ; on peut monter le curseur sur la partie levée sans la perdre. Boutons,
   butin, cases, étapes, plaques de réponse : s'allument sans grossir ; **premier survol** après un
   `/reload` : aucun aplat doré sur l'écran.
4. **Visée** : armer une carte à cible (ou une potion à cible) puis survoler les ennemis : l'anneau de
   l'ennemi survolé s'allume (il ne grandit plus) ; le clic vise toujours le bon ennemi.
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
