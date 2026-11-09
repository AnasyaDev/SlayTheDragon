# Interface en jeu (pistes C et D)

État au 09/11/2026. Rien n'a encore tourné dans le client : tout ce qui suit est vérifié hors jeu
par `Sim/ui_harness.lua`. La section « Tests en vol » liste ce qu'il reste à voir en jeu.
La piste C a écrit l'interface sur une expédition de démonstration ; la piste D l'a branchée sur la
vraie couche expédition (`Core/Expedition.lua`, `Core/Meta.lua`, `Core/Save.lua`, voir
`docs/expedition.md`) et a supprimé la démonstration (`UI/DemoExpedition.lua`).

## Fichiers

| Fichier | Rôle | API WoW |
| --- | --- | --- |
| `UI/Art.lua` | Table d'art : carte → icône, ennemi → créature, état, intention, affixe, clé, bibelot, potion, mots-clés, animations | non |
| `UI/Persist.lua` | Chargement de `SlayTheDragonDB` par `Save.migrate`, options de l'interface (`db.options`) | non |
| `UI/Controller.lua` | Couche mince écrans ↔ `Core/Expedition` : étapes génériques, combat, potions, fin, validation | non |
| `UI/Widgets.lua` | Briques : icônes vérifiées, panneaux, cartes, barres de vie et de réputation, boutons d'objet, états, infobulles, textes flottants, modèles | oui |
| `UI/Main.lua` | Fenêtre 900 × 520, bandeau (PV, or, deck, clé, bibelots, potions), écrans, clavier, options, `/slay`, bouton de minimap | oui |
| `UI/CombatView.lua` | Écran de combat | oui |
| `UI/Screens.lua` | Accueil, choix, cartes, marchand, carte de parcours, bilan et méta | oui |
| `UI/Flight.lua` | Événements : chargement, vol en taxi, combat réel, déconnexion | oui |
| `Sim/ui_harness.lua` | Harnais hors jeu (faux client WoW) | — |

Les fichiers qui touchent l'API WoW commencent par `if not CreateFrame then return end` ; `Sim/load.lua`
saute de toute façon les lignes `UI\` du TOC. **Aucune règle de jeu dans `UI/`** : ce qui est possible
vient de `Expedition.choices`, les refus et leur raison de `Expedition.act`, les prix et tirages de
l'état de l'expédition.

## Écrans

Une phase d'expédition = un écran (choisi par `step.kind`, `UI.register` dans `Screens.lua`) :

| Phase / vue | Écran | Contenu |
| --- | --- | --- |
| aucune expédition | **Accueil** (`start`) | classe (boutons, palier de réputation), clé mythique +0…+5 (verrouillées grisées avec la raison ; affixes de la clé choisie en icônes et en texte ; infobulle par clé), « Partir en expédition », « Réputation et journal », rappel de la dernière expédition |
| `start` | **Choix** | bibelot de classe (Révéré) : 3 bibelots avec icône et infobulle, ou « Partir sans bibelot » |
| `map` | **Carte de parcours** | toute la carte de l'acte, étapes de gauche à droite (8 colonnes, boss à droite), icône par type ; nœuds accessibles (`Map.nextNodes`) entourés d'or et cliquables, position actuelle en bleu, chemin parcouru coché et tracé en clair ; boutons 1…3 des étapes accessibles ; clé et affixes actifs en bas à gauche |
| `combat` | **Combat** | voir plus bas ; potions cliquables dans le bandeau |
| `reward` | **Cartes** | butin (or, bibelot, potion — grisée si non prise faute de place) en icônes avec infobulle, 3 cartes, « Passer les cartes », « Prendre la potion » si possible, « Continuer » ; titre selon combat, élite, boss, coffre ou rencontre (texte « après coup » de la rencontre) |
| `campfire` | **Choix** | « Se reposer » (PV rendus calculés par le moteur, bibelots et Disette compris), « Méditer » (grille d'amélioration avec infobulle « Après amélioration »), « Repartir » |
| `merchant` | **Marchand** | 5 cartes à prix, bibelots (1re rangée) et potions (2e rangée) avec icône, prix et infobulle, « Vendu », « Retirer une carte » (prix croissant, grille du deck), « Partir », or dans le texte ; article trop cher grisé avec « Pas assez d'or. » |
| `event` | **Choix** | nom, texte, un bouton par choix (conséquence en sous-titre, grisé si le moteur refuse) ; après coup : texte `after` et « Continuer » ; « rien à signaler » si aucune rencontre |
| `select` | **Cartes** | suite de rencontre : carte à améliorer (aperçu) ou à retirer, « Passer » |
| `done` | **Bilan** (`end`) | victoire / défaite / abandon, étape, adversaire fatal, étapes franchies, élites, boss, réputation gagnée, changements de palier (classe, Ligue), clé débloquée, barres de réputation ; « Nouvelle expédition », « Réputation et journal » |
| vue méta | **Méta** (`meta`) | barre par classe (palier, points, infobulle des déblocages, clés ouvertes, meilleure clé, titre d'Exalté) et Ligue des explorateurs ; 8 dernières expéditions du journal |

**Bandeau** (en haut, sur tous les écrans) : PV, or, taille du deck (infobulle : deck et bibelots),
étape ; à droite : clé mythique (+N, infobulle des affixes), 6 derniers bibelots (infobulle nom + `text`,
« +N » au-delà) et 3 emplacements de potions.

**Potions** : en combat, clic = boire (`act {"potion", emplacement}`) ; si `ns.Potions[id].target`, le
clic arme la potion et le clic suivant sur un ennemi (ou `Entrée` sur la cible clavier) la lance ; clic
droit annule. Hors combat : « Les potions se boivent en combat » ; deux clics droits en 3 s = jeter
(`discardPotion`), par exemple pour faire place à la potion d'une récompense.

**Affixes** : clé et icônes d'affixes sur la carte, à l'accueil et dans le bandeau ; l'état `necrotic`
s'affiche sur le héros comme les autres états (icône `spell_deathknight_necroticplague`, couleur
d'affaiblissement).

### Combat

- à gauche, le modèle 3D du personnage (`PlayerModel:SetUnit("player")`), PV + Absorption, états et
  Pouvoirs actifs, barre d'incantation ;
- à droite, 1 à 5 ennemis (6 emplacements pour les morts en cours d'animation), modèle 3D, nom (élite
  violet, boss orange), PV, états, intention chiffrée (`Combat.calcDamage`) et infobulle ;
- main en éventail, coût réel, raison d'injouabilité ; pioche / défausse / consumées, recharges,
  mana, Démence, Fin du tour, journal ;
- bandeau de fin de combat (Continuer / Voir le bilan) : le combat est déjà conclu par
  `Expedition.act` (récompense ouverte, ou expédition archivée), le contrôleur garde l'état du combat
  le temps du bandeau (`Controller.ended`).

**Options** : ouvrir au décollage, fermer à l'atterrissage, mode rapide, bouton de minimap, échelle
(60–150 %), vitesse des animations (×0,5 à ×3), abandon (double clic : `Save.abandon` puis bilan),
recentrer.

### Contrôles

- Souris : clic sur une carte (elle se lève), puis clic sur l'ennemi ; une carte sans cible se joue
  par un second clic ou un clic dans le champ de bataille. Glisser-déposer : sur l'ennemi, ou n'importe
  où au-dessus de la main pour une carte sans cible. Clic droit : désélectionner.
- Clavier (capté seulement fenêtre ouverte, `SetPropagateKeyboardInput`) : `1`…`0` choisit une carte
  (même touche ou `Entrée` pour la jouer), `Tab` change de cible (`Maj+Tab` à rebours), `Espace` finit
  le tour (et « Continuer » après un combat), `Échap` ferme (les options d'abord). Sur les autres écrans,
  `1`…`0` choisit une option (carte de parcours : étapes accessibles de gauche à droite ; accueil :
  clé +0…+5), `Entrée`/`Espace` l'action par défaut (Partir, Continuer, Partir de chez le marchand).
  Toute autre touche est rendue au jeu.
- `/slay` (ou `/slaythedragon`) : ouvrir/fermer ; `/slay options` ; `/slay art` (icônes et modèles
  introuvables repérés) ; `/slay modeles` (galerie des ennemis de l'acte) ; `/slay facing <j> <e>`
  (orientation des modèles en radians, enregistrée) ; `/slay centre`.
- Bouton de minimap : clic gauche ouvre/ferme, clic droit options, glisser pour le déplacer.
- La fenêtre se masque à l'entrée en combat réel (`PLAYER_REGEN_DISABLED`), refuse de s'ouvrir en
  combat, et se rouvre à la sortie du combat si l'on est toujours en vol.

### Animations

L'état affiché est toujours celui du moteur, mis à jour aussitôt. Les animations sont cosmétiques et
rejouent les événements `c.events` dans une file : frappe (`act` d'attaque), encaisser (dégâts),
mourir puis rester à terre, incantation, textes flottants (dégâts, Absorption, soins, états, Démence,
« Interrompu ! », répliques comme « À moi, la Confrérie ! »). Vitesse réglable, mode rapide (×0,15).

## Contrôleur

`UI/Controller.lua` ne contient aucune règle. L'expédition en cours **est** `SlayTheDragonDB.current` :
`Expedition.act` la modifie sur place, rien n'est recopié. État propre à l'interface (jamais sauvegardé) :

```lua
Controller.ended  = { c, result, title }   -- combat tranché, bandeau affiché
Controller.ending = { summary, entry }     -- expédition archivée par Save.finish, bilan affiché
Controller.ui     = { view, class, key }   -- sous-écran (upgrade, remove, meta), choix de départ
```

- `Controller.step()` traduit la phase en étape générique `{ kind, title, text, options, ... }`.
  Une option a un `id` « verbe » ou « verbe:argument » : une action d'expédition (`path:12`,
  `pickCard:2`, `buyRelic:1`, `remove:5`, `choose:1`, `select:3`, `leave`…), une navigation
  (`ui:upgrade`, `ui:remove`, `ui:meta`, `ui:back`, `ui:new`) ou un choix de départ
  (`class:priest`, `key:2`, `go`).
- Option grisée = action absente de `Expedition.choices` ; sa raison vient d'un essai de l'action sur
  une **copie** de l'expédition (`Controller.reasonFor`), traduite par `Controller.REASONS`. Même
  principe pour les PV rendus au repos (essai de `rest` sur une copie).
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
(`autoOpen, autoClose, scale, speed, fast, minimap = { hide, angle }, facingPlayer, facingEnemy, point`),
que `Save.migrate` garde tel quel (il ne retire jamais un champ inconnu ; testé). Plus aucun format de
sauvegarde côté interface.

- Chargement (`ADDON_LOADED`) : `SlayTheDragonDB = Save.migrate(SlayTheDragonDB)`, puis options par défaut.
- Expédition illisible pour `Save` (structure, carte inconnue…) : quarantaine par `Save.migrate`.
  Illisible pour l'interface (bibelot, potion, ennemi, intention, article ou rencontre inconnus, combat
  abîmé) ou erreur Lua à la reprise : `Save.quarantine(db, raison)`. Un message le signale à l'accueil
  et dans la discussion ; rien n'est effacé.
- Sauvegarde d'une version **plus récente** de l'addon : `Save.migrate` n'y touche pas ; l'interface
  joue alors sur une base de session jamais écrite (`Persist.readOnly`, message dans la discussion).
- Sauvegarde de développement de la piste C (version 1, `meta = { saves, savedAt }`, `current` du
  fournisseur « demo ») : options gardées, ancienne expédition en quarantaine, méta réparée.

### Changements dans `Core/` (piste D)

- `Core/Save.lua` : `Save.normalize(db)` (l'ancienne migration 0 → 1, idempotente) est rejouée à chaque
  `Save.migrate` pour réparer une méta incomplète ; `Save.quarantine(db, raison)` devient public. Test
  « migrate : options de l'interface gardées, méta incomplète réparée » dans `Sim/tests_expedition.lua`.
- `Core/Expedition.lua` : `exp.path` = nœuds visités dans l'acte (chemin parcouru sur la carte), remis
  à zéro à chaque acte. Test « chemin parcouru ».

## API WoW utilisées

Confirmé par le MCP « wow » (base API Forever 1.60 / 12.1.5) :
`UnitOnTaxi(unit)`, événements `PLAYER_CONTROL_LOST`, `PLAYER_CONTROL_GAINED`, `TAXIMAP_CLOSED`,
`TAXIMAP_OPENED`, `PLAYER_ENTERING_WORLD (isInitialLogin, isReloadingUi)`, `PLAYER_REGEN_DISABLED/ENABLED`,
`ADDON_LOADED (addOnName, containsBindings)`, `PLAYER_LOGOUT` ; méthodes `SetPropagateKeyboardInput`,
`SetCreature(creatureID, displayID)`, `SetDisplayInfo`, `SetUnit`, `SetAnimation(anim, variation)`,
`SetPortraitZoom`, `SetCamDistanceScale`, `GetModelFileID`, `SetTexture -> success`, `SetDesaturated`,
`CreateLine` + `SetStartPoint/SetEndPoint`, `IsMouseOver` ; `date()` (global « Legacy » présent sur
Forever, vérifié par la piste D ; repli sur `time()`).
Confirmé par la capture d'API Forever du kit `forever-addon-kit` (`data/forever_api.json`, build 69893) :
`C_Timer.After/NewTicker`, `C_Spell.GetSpellTexture`, `InCombatLockdown`, `GetCursorPosition`,
`PlaySound`, `UnitName`, `GetTime`, `time`, et les objets de police utilisés (`GameFontNormal`,
`GameFontHighlight(Small/Large)`, `GameFontNormal(Small/Large/Huge)`, `GameFontDisableSmall`,
`NumberFontNormal`).

Icônes ajoutées par la piste D (affixes, Nécrotique, clé mythique, repli des bibelots et potions) :
chemins vérifiés par `wow_icon_search` — l'index des icônes du MCP répond désormais, il servira à
vérifier aussi les icônes plus anciennes de `UI/Art.lua`.

**Non vérifié** (créatures et source de l'interface Blizzard non synchronisées ; la synchronisation
`npx -y hated-wow-mcp sync …` a été refusée) :

- les modèles XML `BackdropTemplate`, `UIPanelButtonTemplate`, `UIPanelCloseButton` (repli sans
  modèle sous `pcall` s'ils manquent) ;
- les chemins d'icônes de la piste C dans `UI/Art.lua` (repli : icône du sort par
  `C_Spell.GetSpellTexture`, puis le chemin, puis le point d'interrogation ; `/slay art` liste les manques) ;
- les identifiants de créatures (gnoll 117, mystique 453, murloc 126, bandit 116, sorcier 619,
  golem 36, Rhahk'Zor 644, sbire 594, VanCleef 639 + affichage 2029) : repli `SetDisplayInfo` puis icône ;
- les identifiants d'animation (0 attente, 1 mort, 6 mort au sol, 9 encaisser, 16 frapper, 25 prêt,
  53/54 sorts) et l'orientation des modèles (`/slay facing`) ;
- l'ordre exact des événements de taxi sur Forever. La détection ne dépend d'aucun d'eux : seule la
  transition de `UnitOnTaxi("player")` compte, vérifiée à chaque événement puis 0,3 s, 1 s et 2,5 s
  après, plus un sondage de secours toutes les 2 s (`C_Timer.NewTicker`).
- `SetPropagateKeyboardInput` : protégé en combat sur Retail récent ; jamais appelé en combat ici.

Aucune fonction protégée, aucun `hooksecurefunc` (cassés sur ce build), aucun `loadstring`.
Les événements sont enregistrés un par un sous `pcall` (un événement inconnu lève une erreur sur Forever).
`wow_lua_lint` (forever) : aucune erreur ni avertissement sur `UI/` ; `wow_toc_validate` : seulement
les avertissements habituels sur les `\` du TOC.

## Besoins côté moteur (notés, contournés côté interface)

- `Combat.intentInfo` ne donne que les dégâts : l'interface lit `ns.Enemies[id].moves[intent].actions`
  pour afficher Absorption, soins, états et invocations. Un champ `info.actions` normalisé serait plus sûr.
- Pas de prévisualisation des dégâts d'une carte sur une cible (Force, Armure fracassée, Forme d'ombre).
- **Potions (piste A)** : l'interface lit les emplacements dans `c.player.potions` en combat (sinon
  `exp.potions`) et boit par `act {"potion", emplacement, cible}`. Il faut `Combat.usePotion(c, slot, tIdx)
  -> true | false, raison` (raisons reconnues par `Controller.REASONS` : `potion`, `target`, `over`… ;
  une autre raison s'affiche telle quelle) et la copie de `opts.potions` dans `c.player.potions` par
  `Combat.new`. Champs lus : `name`, `text`, `target` (vrai = demande une cible), `rarity`. Tant que
  `Combat.usePotion` manque, boire répond « Les potions ne sont pas encore utilisables en combat. »
- **Bibelots (piste A)** : champs lus `name`, `text`, `rarity`, `class`. Icônes : une entrée par id dans
  `Art.relics` / `Art.potions` (sinon repli générique : talisman pour les bibelots, fiole pour les potions).

## Décisions

- Clé proposée par défaut à l'accueil : la plus haute ouverte pour la classe.
- La réputation est acquise dès la fin de l'expédition (`Save.finish` automatique), le bilan n'est
  qu'un affichage : après un `/reload` sur le bilan, on retombe sur l'accueil (dernière expédition
  rappelée, détail dans « Réputation et journal »).
- Le bandeau de fin de combat n'est pas sauvegardé : un `/reload` à ce moment reprend sur la
  récompense (ou l'accueil après une défaite).
- Récompense : « Continuer » est toujours possible (la carte est alors abandonnée), « Passer les
  cartes » n'est qu'un raccourci explicite. Clic sur une carte = prise immédiate.
- Feu de camp : « Repartir » sans rien faire est proposé (le moteur l'accepte).
- Marchand : plusieurs retraits par visite (règle de `Core/Expedition`), le prix affiché monte.
- Jeter une potion : deux clics droits en 3 s (pas de menu).
- Carte de parcours : étapes en colonnes de gauche à droite (la fenêtre est plus large que haute) ;
  `node.x` du moteur devient la position verticale.
- La graine d'une expédition vient de `time()` et `GetTime()` (ce n'est pas une règle).
- Fenêtre en strate `HIGH`, textes flottants en `DIALOG`. L'atterrissage ferme la fenêtre même ouverte
  à la main (option désactivable).

## Harnais hors jeu

```
lua5.1 Sim/ui_harness.lua [graine]   # ou luajit ; doit finir par ALL PASS (181 vérifications, graine 1)
```

Il charge tous les fichiers du TOC avec un faux client (cadres enregistreurs, horloge virtuelle,
événements, infobulle, modèles), refuse les modèles XML et événements inconnus et signale toute méthode
d'API inconnue. Il déclare des bibelots et potions de test (`ui_test_*`) et, tant que le moteur n'a pas
`Combat.usePotion`, une doublure minimale (soin, dégâts) pour exercer les potions.

Scénario : accueil, `/slay`, Échap, options ; clé verrouillée ; **expédition complète de l'acte 1
jouée par clics simulés** (chemin choisi pour passer par un marchand, une rencontre et un feu de camp ;
combats joués par le bot heuristique à travers l'interface : clics carte puis cible, touches 1–0/Tab/
Espace, glisser-déposer ; récompenses, amélioration, retrait, achats) ; aller-retour de sauvegarde en
plein combat (état identique, tirage suivant identique) et sur un écran de récompense (mêmes cartes) ;
bilan, `Save.finish`, réputation, méta, journal ; nouvelle expédition à la clé +1 (graine 1 = victoire ;
avec une graine perdante, le harnais vérifie qu'aucune clé ne s'ouvre) ; bandeau de potions et bibelots,
défausse, potions bues en combat (avec et sans cible) ; marchand complet ; feu de camp ; rencontre ;
bibelot de classe à Révéré ; abandon ; vol (décollage, atterrissage, combat réel, `/reload` en vol,
déconnexion) ; sauvegardes anciennes, abîmées ou futures ; art manquant et `/slay art`.

## Tests en vol (pour toi)

Préparation : copier le dossier dans `/mnt/Games/World of Warcraft/_forever_/Interface/AddOns/SlayTheDragon`
(le client Forever n'est plus dans `_classic_beta_`), sans `Sim/`, `docs/`, `build/`, `reports/`
(commande `rsync` dans `CLAUDE.md`). **Relancer le client** : un nouvel addon, ou un fichier ajouté ou
retiré du TOC (comme `UI\DemoExpedition.lua`, supprimé ici), n'est pris en compte qu'au lancement du
client ; `/reload` ne suffit pas. Activer les erreurs Lua (`/console scriptErrors 1`) ou BugSack.
Une ancienne sauvegarde de développement est reprise : options gardées, ancienne expédition mise de côté
(message dans la discussion).

Au sol :
1. `/slay` ouvre la fenêtre au centre ; on la déplace par le bord/titre ; `/reload` → même position.
2. Le bouton de minimap est là, se déplace en le glissant, clic gauche/droit OK, infobulle OK.
3. `/slay modeles` : les 9 ennemis ont-ils un modèle ? Noter ceux qui montrent un point d'interrogation.
   Les personnages regardent-ils vers le centre ? Sinon essayer `/slay facing -0.6 0.6` (ou d'autres valeurs).
4. Accueil : Prêtre sélectionné, clés +1…+5 grisées (infobulle : affixes ; clic : raison). « Partir » →
   carte de parcours : la carte entière est-elle lisible (8 colonnes, liens, icônes par type, libellés) ?
   Les étapes accessibles sont-elles entourées d'or et cliquables, les autres refusées ?
5. Combat : ton personnage est-il visible à gauche ? Les icônes des cartes, des intentions et des états
   sont-elles bonnes ? `/slay art` liste ce qui manque.
6. Jouer quelques cartes : clic carte + clic ennemi ; second clic pour une carte sans cible ; glisser
   sur un ennemi ; touches 1–0, Tab, Entrée, Espace. Une touche non gérée (Z, M…) doit encore agir sur le jeu.
7. Une carte trop chère est grisée et dit « Pas assez de mana. » ; les infobulles des mots-clés, états,
   intentions, pioche/défausse et recharges s'affichent.
8. Animations : l'ennemi frappe, tu encaisses, il meurt et reste à terre ; textes flottants lisibles.
   Tester Options → Mode rapide et la vitesse.
9. `/reload` en plein combat : même tour, même main, mêmes PV ennemis, même intention.
10. Gagner : bandeau, récompense (or et éventuelle potion en icônes) ; `/reload` sur la récompense →
    mêmes 3 cartes.
11. Continuer l'acte : sur la carte, le chemin parcouru est tracé et coché. Traverser si possible un
    marchand (achat de carte ; retrait : le prix monte de 25 po), une rencontre (texte, choix, résultat)
    et un feu de camp (PV rendus annoncés, « Méditer » avec aperçu). Infobulles des bibelots et potions
    du bandeau. Une potion se boit en combat d'un clic (à cible : clic puis ennemi) ; deux clics droits
    la jettent hors combat. (Bibelots et potions n'existent qu'après la fusion de la piste A.)
12. Fin d'expédition : bilan (réputation gagnée, paliers, barres) ; « Réputation et journal » ; après
    une victoire, la clé +1 est proposée à l'accueil, ses affixes apparaissent sur la carte et dans le
    bandeau. Options → Abandonner (deux clics) mène au bilan « abandonnée ».
13. Entrer en combat contre un vrai monstre fenêtre ouverte → elle se masque ; `/slay` refusé en combat.

En vol :
14. Prendre un griffon : la fenêtre s'ouvre seule au décollage (dans les 2–3 s), sur l'étape en cours.
15. Jouer pendant le vol ; les touches 1–0 ne lancent pas tes sorts, Échap ferme la fenêtre.
16. À l'atterrissage, la fenêtre se ferme ; au vol suivant, on reprend exactement au même point.
17. Désactiver « Ouvrir au décollage » : le vol suivant n'ouvre rien ; `/slay` marche toujours.
18. `/reload` pendant un vol : la fenêtre se rouvre seule.
19. Déconnexion puis reconnexion (autre personnage) : l'expédition reprend (sauvegarde par compte).

À me renvoyer : la sortie de `/slay art`, les modèles manquants, les valeurs de `/slay facing` qui
conviennent, des captures de l'accueil, de la carte de parcours, du marchand et du bilan (lisibilité,
chevauchements), et toute erreur Lua (texte complet).
