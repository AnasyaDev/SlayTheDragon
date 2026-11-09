# Interface en jeu (piste C)

État au 09/11/2026. Rien n'a encore tourné dans le client : tout ce qui suit est vérifié hors jeu
par `Sim/ui_harness.lua`. La section « Tests en vol » liste ce qu'il reste à voir en jeu.

## Fichiers

| Fichier | Rôle | API WoW |
| --- | --- | --- |
| `UI/Art.lua` | Table d'art : carte → icône, ennemi → créature/affichage, état → icône, intention → icône, mots-clés, animations | non |
| `UI/DemoExpedition.lua` | Expédition de démonstration (séquence de `Sim/run.lua` + carte linéaire + marchand), en attendant `Core/Expedition.lua` | non |
| `UI/Persist.lua` | `SlayTheDragonDB` : format versionné, migration, copie après chaque action | non (lit `time`) |
| `UI/Controller.lua` | Couche mince écrans ↔ moteur : étapes génériques, combat, reprise, validation | non |
| `UI/Widgets.lua` | Briques : icônes vérifiées, panneaux, cartes, barres, états, infobulles, textes flottants, modèles | oui |
| `UI/Main.lua` | Fenêtre 900 × 520, écrans, clavier, options, `/slay`, bouton de minimap | oui |
| `UI/CombatView.lua` | Écran de combat | oui |
| `UI/Screens.lua` | Écrans génériques : choix, cartes, marchand, carte de parcours | oui |
| `UI/Flight.lua` | Événements : chargement, vol en taxi, combat réel, déconnexion | oui |
| `Sim/ui_harness.lua` | Harnais hors jeu (faux client WoW) | — |

Les fichiers qui touchent l'API WoW commencent par `if not CreateFrame then return end` : `Sim/load.lua`
relit le TOC et charge donc aussi `UI\*.lua` ; sans cette garde, `Sim/tests.lua` et `Sim/sim.lua`
planteraient. Les quatre fichiers « non » se chargent normalement hors jeu.
**Suggestion pour le responsable de `Sim/load.lua`** : sauter les lignes `UI\` du TOC.

## Écrans

- **Accueil** (`start`) : nouvelle expédition, rappel de la dernière.
- **Carte de parcours** (`map`) : nœuds reliés (icône par type, franchis cochés, accessible entouré),
  clic sur le nœud accessible ou bouton « Continuer ». Générique : `x`, `y` dans [0, 1] et `links`.
- **Combat** (`combat`) :
  - à gauche, le modèle 3D du personnage (`PlayerModel:SetUnit("player")`), PV + Absorption (barre
    bleue superposée et `+N`), états et Pouvoirs actifs (icônes avec compteur et infobulle),
    barre d'incantation (carte, cible, infobulle) ;
  - à droite, 1 à 5 ennemis (jusqu'à 6 emplacements pour les morts en cours d'animation), modèle 3D,
    nom (élite violet, boss orange), PV + Absorption, états, intention (icône + chiffres exacts calculés
    par `Combat.calcDamage`, `Incante`, `Guette`, `Interrompu`, `Étourdi`) et infobulle détaillée ;
  - main en éventail (arc sans rotation : les cadres WoW ne tournent pas), icône du sort, nom, coût
    (coût réel via `Combat.cost`), texte, liseré de rareté, touche 1–0, grisée si injouable avec la
    raison de `Combat.canPlay` en infobulle et en message ;
  - compteurs Pioche / Défausse / Consumées (infobulle : liste triée), recharges (icônes, tours restants),
    mana, Démence, bouton Fin du tour ; numéro de tour ; journal discret (défile à la molette) ;
  - bandeau de fin de combat (Continuer / Voir le bilan).
- **Cartes** (`reward`, `deck`) : récompense (3 cartes, Passer), amélioration au feu de camp (infobulle
  « Après amélioration »), retrait chez le marchand ; grille paginée (18 par page).
- **Choix** (`choice`, `event`) : feu de camp, rencontres futures ; texte + boutons avec détail, prix, raison.
- **Marchand** (`shop`) : cartes avec prix (rouge si trop cher, « Vendu »), services à prix, Partir.
- **Bilan** (`end`) : victoire/défaite, Nouvelle expédition (l'ancienne part au journal).
- **Options** : ouvrir au décollage, fermer à l'atterrissage, mode rapide, bouton de minimap, échelle
  (60–150 %), vitesse des animations (×0,5 à ×3), abandon (double clic de confirmation), recentrer.

### Contrôles

- Souris : clic sur une carte (elle se lève), puis clic sur l'ennemi ; une carte sans cible se joue
  par un second clic ou un clic dans le champ de bataille. Glisser-déposer : sur l'ennemi, ou n'importe
  où au-dessus de la main pour une carte sans cible. Clic droit : désélectionner.
- Clavier (capté seulement fenêtre ouverte, `SetPropagateKeyboardInput`) : `1`…`0` choisit une carte
  (même touche ou `Entrée` pour la jouer), `Tab` change de cible (`Maj+Tab` à rebours), `Espace` finit
  le tour (et « Continuer » après un combat), `Échap` ferme (les options d'abord). Sur les autres écrans,
  `1`…`0` choisit une option. Toute autre touche est rendue au jeu.
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

## Contrôleur et fournisseurs d'expédition

`UI/Controller.lua` ne contient aucune règle. Il tient l'état vivant :

```lua
live = { provider = "demo", seed = n, run = <état du fournisseur>,
         combat = <état ns.Combat> | nil, over = nil | "won" | "lost" }
```

et l'écrit dans `SlayTheDragonDB.current` (copie profonde) après **chaque** action : coup joué, fin de
tour, choix d'étape, fin de combat. Les écrans ne parlent qu'au contrôleur :
`Controller.step()`, `Controller.choose(id)`, `Controller.play(main, cible)`, `Controller.endTurn()`,
`Controller.finishCombat()`, `Controller.handInfo(i)`.

### Contrat attendu de `Core/Expedition.lua` (piste B)

Le contrôleur pilote un « fournisseur ». Pour remplacer la démo, il suffit que B expose (ou qu'un
adaptateur de quelques lignes traduise vers) :

- `P.id` : chaîne enregistrée dans la sauvegarde (`live.provider`).
- `P.new(seed, { class = "priest" }) -> run` : état en données simples.
- `P.choices(run) -> step` avec `step.kind` parmi `map | combat | reward | choice | event | deck | shop | end`,
  `step.title`, `step.text`, `step.options = { { id, label, text, card = { id, up }, price, disabled,
  reason, preview, sold } }` ; pour `combat`, `step.combat = { seed, hp, maxHp, deck, encounter,
  relics, elite, boss }` ; pour `map`, `step.nodes = { { id, kind, label, x, y, links, state } }` avec
  `state` ∈ `done | current | available | locked` et `kind` ∈ `combat | elite | boss | campfire | shop |
  event | chest` ; pour `end`, `step.won`.
- `P.act(run, id, extra) -> ok, raison` ; fin de combat : `id = "combat:won" | "combat:lost"`,
  `extra = { hp = PV restants }`. Un tirage (récompense, marchand) est fait dans `act` et stocké dans
  `run`, jamais dans `choices` : recharger l'interface ne retire rien.
- `P.summary(run)` (entrée de journal) et `P.validate(run) -> ok, raison` (reprise sûre).

Brancher : ajouter le fournisseur à `Controller.providers` et le choisir dans `Controller.newRun`.
Une sauvegarde d'un autre fournisseur reste lisible tant que les deux sont enregistrés.
Les écrans sont choisis par `step.kind` (`UI.register` dans `Main.lua`) : un nouveau type d'étape
(coffre, rencontre à cartes…) réutilise `choice`, `cards` ou `shop`, ou ajoute un écran.

### Format de sauvegarde (provisoire, en attendant `Core/Save.lua`)

```lua
SlayTheDragonDB = { version = 1, meta = { saves, savedAt, future?, broken? },
  current = live | nil, journal = { résumés }, options = { autoOpen, autoClose, scale, speed, fast,
  minimap = { hide, angle }, facingPlayer, facingEnemy, point } }
```

- Base sans version : on garde seulement les options. Version plus récente que l'addon : mise de côté
  dans `meta.future`, pas écrasée. Migration par paliers (`MIGRATIONS[v]`).
- À la reprise, l'état est validé (cartes, ennemis, intentions, bibelots encore connus) ; s'il ne
  l'est plus (carte renommée par A, par exemple), il est archivé au journal (« abandon ») au lieu de
  provoquer une erreur Lua.
- Quand `Core/Save.lua` arrive : remplacer `Persist.migrate` par `Save.migrate`, garder `options`
  (propre à l'interface) et `current = live`.

## API WoW utilisées

Confirmé par le MCP « wow » (base API Forever 1.60 / 12.1.5) :
`UnitOnTaxi(unit)`, événements `PLAYER_CONTROL_LOST`, `PLAYER_CONTROL_GAINED`, `TAXIMAP_CLOSED`,
`TAXIMAP_OPENED`, `PLAYER_ENTERING_WORLD (isInitialLogin, isReloadingUi)`, `PLAYER_REGEN_DISABLED/ENABLED`,
`ADDON_LOADED (addOnName, containsBindings)`, `PLAYER_LOGOUT` ; méthodes `SetPropagateKeyboardInput`,
`SetCreature(creatureID, displayID)`, `SetDisplayInfo`, `SetUnit`, `SetAnimation(anim, variation)`,
`SetPortraitZoom`, `SetCamDistanceScale`, `GetModelFileID`, `SetTexture -> success`, `SetDesaturated`,
`CreateLine` + `SetStartPoint/SetEndPoint`, `IsMouseOver`.
Confirmé par la capture d'API Forever du kit `forever-addon-kit` (`data/forever_api.json`, build 69893) :
`C_Timer.After/NewTicker`, `C_Spell.GetSpellTexture`, `InCombatLockdown`, `GetCursorPosition`,
`PlaySound`, `UnitName`, `GetTime`, `time`, et les objets de police utilisés (`GameFontNormal`,
`GameFontHighlight(Small/Large)`, `GameFontNormal(Small/Large/Huge)`, `GameFontDisableSmall`,
`NumberFontNormal`).

**Non vérifié** (le MCP n'a pas ses jeux de données : index des fichiers/icônes, créatures et source
de l'interface Blizzard ne sont pas synchronisés ; la synchronisation `npx -y hated-wow-mcp sync …`
m'a été refusée) :

- les modèles XML `BackdropTemplate`, `UIPanelButtonTemplate`, `UIPanelCloseButton` (repli sans
  modèle sous `pcall` s'ils manquent) ;
- les chemins d'icônes de `UI/Art.lua` (repli : icône du sort par `C_Spell.GetSpellTexture`, puis le
  chemin, puis le point d'interrogation ; `/slay art` liste les manques) ;
- les identifiants de créatures (gnoll 117, mystique 453, murloc 126, bandit 116, sorcier 619,
  golem 36, Rhahk'Zor 644, sbire 594, VanCleef 639 + affichage 2029) : repli `SetDisplayInfo` puis icône ;
- les identifiants d'animation (0 attente, 1 mort, 6 mort au sol, 9 encaisser, 16 frapper, 25 prêt,
  53/54 sorts) et l'orientation des modèles (`/slay facing`) ;
- l'ordre exact des événements de taxi sur Forever. La détection ne dépend d'aucun d'eux : seule la
  transition de `UnitOnTaxi("player")` compte, vérifiée à chaque événement puis 0,3 s, 1 s et 2,5 s
  après, plus un sondage de secours toutes les 2 s (`C_Timer.NewTicker`).
- `SetPropagateKeyboardInput` : protégé en combat sur Retail récent ; jamais appelé en combat ici.

Pour compléter l'art proprement, lancer dans un terminal :
`npx -y hated-wow-mcp sync game-data`, `npx -y hated-wow-mcp sync model-data` et
`npx -y hated-wow-mcp sync ui-source`, puis vérifier `UI/Art.lua` avec `wow_icon_search`,
`wow_creature_search` et `wow_ui_template_search`.

Aucune fonction protégée, aucun `hooksecurefunc` (cassés sur ce build), aucun `loadstring`.
Les événements sont enregistrés un par un sous `pcall` (un événement inconnu lève une erreur sur Forever).

## Besoins côté moteur (notés, contournés côté interface)

- `Combat.intentInfo` ne donne que les dégâts : l'interface lit `ns.Enemies[id].moves[intent].actions`
  pour afficher Absorption, soins, états et invocations. Un champ `info.actions` normalisé serait plus sûr.
- Pas de prévisualisation des dégâts d'une carte sur une cible (Force, Armure fracassée, Forme d'ombre) :
  le texte de la carte reste le texte de base.
- Potions : aucune API de combat (`Combat.usePotion`) ni emplacement dans l'état ; l'écran n'a pas encore
  d'emplacements de potions.
- Bibelots : affichés seulement dans l'infobulle du bandeau (nom + `text`) ; un champ `text` sur
  `ns.Relics[id]` est attendu. Pas d'icônes de bibelots dans `UI/Art.lua` tant que la liste n'existe pas.
- `Sim/load.lua` pourrait sauter les lignes `UI\` du TOC (voir plus haut).

## Décisions

- La démo ajoute un marchand après l'élite (séquence `easy, easy, normal, feu, élite, marchand, normal,
  feu, boss`) et une carte de parcours linéaire, pour que chaque écran générique soit visible en jeu.
  Or : 15 / 30 / 80 po ; prix 50 / 75 / 150 ; retrait 75 po. Ces chiffres disparaissent avec `Core/Expedition.lua`.
- La graine d'une expédition vient de `time()` et `GetTime()` (ce n'est pas une règle) ; tout le reste du
  hasard passe par `ns.Rng` dans le moteur ou le fournisseur.
- Clic sur une carte de récompense = prise immédiate (pas de confirmation).
- L'atterrissage ferme la fenêtre même si on l'avait ouverte à la main (option désactivable).
- Fenêtre en strate `HIGH`, textes flottants en `DIALOG`.

## Harnais hors jeu

```
lua5.1 Sim/ui_harness.lua [graine]   # ou luajit ; doit finir par ALL PASS (88 vérifications)
```

Il charge tous les fichiers du TOC avec un faux client (cadres enregistreurs, horloge virtuelle,
événements, infobulle, modèles), refuse les modèles XML et événements inconnus et signale toute méthode
d'API inconnue (faute de frappe). Scénario : accueil, `/slay`, Échap, options ; nouvelle expédition ;
combat complet joué par un bot heuristique **à travers l'interface** (clics carte puis cible, touches
1–0/Tab/Espace, glisser-déposer) ; récompense fixée par la sauvegarde ; aller-retour de sauvegarde en
plein combat (état identique, tirage suivant identique) ; décollage/atterrissage par événements et par
sondage, masquage en combat réel, `/reload` en vol ; expédition menée jusqu'au bilan ; marchand et
retrait ; sauvegardes abîmées ; art manquant et `/slay art`.

## Tests en vol (pour toi)

Préparation : copier le dossier dans `/mnt/Games/World of Warcraft/_classic_beta_/Interface/AddOns/SlayTheDragon`
(sans `Sim/`, `docs/`, `build/`), relancer le client (nouveau TOC), activer les erreurs Lua
(`/console scriptErrors 1`) ou BugSack.

Au sol :
1. `/slay` ouvre la fenêtre au centre ; on la déplace par le bord/titre ; `/reload` → même position.
2. Le bouton de minimap est là, se déplace en le glissant, clic gauche/droit OK, infobulle OK.
3. `/slay modeles` : les 9 ennemis ont-ils un modèle ? Noter ceux qui montrent un point d'interrogation.
   Les personnages regardent-ils vers le centre ? Sinon essayer `/slay facing -0.6 0.6` (ou d'autres valeurs).
4. Nouvelle expédition → carte → combat : ton personnage est-il visible à gauche ? Les icônes des cartes,
   des intentions et des états sont-elles bonnes ? `/slay art` liste ce qui manque.
5. Jouer quelques cartes : clic carte + clic ennemi ; second clic pour une carte sans cible ; glisser
   sur un ennemi ; touches 1–0, Tab, Entrée, Espace. Une touche non gérée (Z, M…) doit encore agir sur le jeu.
6. Une carte trop chère est grisée et dit « Pas assez de mana. » ; les infobulles des mots-clés, états,
   intentions, pioche/défausse et recharges s'affichent.
7. Animations : l'ennemi frappe, tu encaisses, il meurt et reste à terre ; textes flottants lisibles.
   Tester Options → Mode rapide et la vitesse.
8. `/reload` en plein combat : même tour, même main, mêmes PV ennemis, même intention.
9. Gagner : bandeau, récompense ; `/reload` sur la récompense → mêmes 3 cartes.
10. Entrer en combat contre un vrai monstre fenêtre ouverte → elle se masque ; `/slay` refusé en combat.

En vol :
11. Prendre un griffon : la fenêtre s'ouvre seule au décollage (dans les 2–3 s), sur l'étape en cours.
12. Jouer pendant le vol ; les touches 1–0 ne lancent pas tes sorts, Échap ferme la fenêtre.
13. À l'atterrissage, la fenêtre se ferme ; au vol suivant, on reprend exactement au même point.
14. Désactiver « Ouvrir au décollage » : le vol suivant n'ouvre rien ; `/slay` marche toujours.
15. `/reload` pendant un vol : la fenêtre se rouvre seule.
16. Déconnexion puis reconnexion (autre personnage) : l'expédition reprend (sauvegarde par compte).

À me renvoyer : la sortie de `/slay art`, les modèles manquants, les valeurs de `/slay facing` qui
conviennent, et toute erreur Lua (texte complet).
