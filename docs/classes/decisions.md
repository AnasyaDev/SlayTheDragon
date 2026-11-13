# Décisions communes aux classes

Règles tranchées après relecture des fiches (12/11/2026). Elles priment sur les fiches de `docs/classes/`
quand une fiche dit autre chose. Les trois premières viennent du joueur, les autres du concepteur.

## Périmètre (décision du joueur, 12/11/2026)
Cinq classes à produire maintenant : **Priest, Mage, Warrior, Rogue, Hunter**. Paladin, Warlock, Shaman et
Druid sont des ajouts futurs : leurs fiches restent en référence, rien n'est codé pour elles.

## Tranché par le joueur
- **Spend N est au choix.** Un clic gauche joue la carte en dépensant si les points sont là ; un clic droit
  (ou une touche de modification, à choisir côté interface) la joue SANS dépenser. La carte montre clairement
  si le bonus sera payé (ligne `Spend N:` allumée ou éteinte). Les bots choisissent.
- **Parry reste d'un tour à l'autre, 3 charges au plus.** Ordre : Parry, puis Absorb, puis PV. Une charge par
  coup. Pas de Parry contre le DoT.
- **Aucun garde-fou sur Stunned.** Un ennemi peut être étourdi plusieurs tours de suite ; seuls les boss sont
  immunisés. Conséquence pour l'équilibrage : limiter les étourdissements par le Cooldown et le coût des
  cartes, pas par une règle.

## Tranché par le concepteur
- **Coût en PV : une seule formulation, `Pay N HP.`,** pour toutes les classes. Il compte comme une perte de
  PV (Rage, Enrage, Healthstone), n'est pas une attaque, ignore l'Absorb, et rend la carte injouable s'il
  ferait tomber à 0.
- **Surge à 0.** Une carte dont le seul effet est son `Surge:` est injouable à 0 point. Une carte qui a une
  autre clause reste jouable ; son Surge ne fait alors rien.
- **Moment des coûts.** Mana, PV et ressource se paient quand la carte est jouée ; les conditions se lisent
  à la résolution. Un Cast interrompu ne rend rien.
- **Stunned posé pendant le tour de l'ennemi** (12/11/2026, après une remarque du joueur sur Freezing Trap) :
  un Stunned posé sur un ennemi pendant SON propre tour (Trap, riposte, tout effet déclenché par son action)
  arrête ce tour immédiatement : ses actions restantes sont annulées, à commencer par l'attaque qui a
  déclenché l'effet (aucun de ses coups ne part), et la charge est consommée par ce tour-là (« Stunned 2 » =
  ce tour et le suivant). Posé pendant le tour du joueur, rien ne change : l'ennemi perd son prochain tour.
  Un Stunned posé sur un autre ennemi pendant ce tour suit la règle habituelle. Boss immunisés. Une
  incantation ennemie arrêtée ainsi est perdue, comme le tour d'un ennemi étourdi. Survol : « Loses its next
  turn, or the rest of this one. » ; journal `{ t = "stunned", stopped = true }` (moteur : drapeau
  `stopTurn` posé par `Combat.applyStatus`, appliqué par `executeMove`).
- **Instant est un état commun** (Mage, Shaman). Il se cumule, se garde d'un tour à l'autre, et la prochaine
  carte Cast le consomme : elle se résout tout de suite, sans prendre d'emplacement de Cast et sans pouvoir
  être interrompue. Le Shaman le reçoit en atteignant 5 de Maelstrom (le Maelstrom retombe à 0).
- **Deux Cast (Mage).** Résolus du plus ancien au plus récent ; une interruption annule le plus récent.
- **Power à emplacement** (mécanisme commun) : Seal du Paladin, démon du Warlock, totems du Shaman (un
  emplacement par élément). Un nouveau remplace l'ancien du même emplacement ; la carte remplacée ou éteinte
  va à la défausse. Durée facultative en tours, comptée comme le sablier des bienfaits.
- **Ripostes.** Les effets « quand il est frappé » (Warrior Protection, Retribution Aura, Earth Shield)
  existent. `Trap` reste la seule CARTE que l'on pose pour le tour adverse.
- **Druid.** Une carte de soin jouée hors de Caster ramène d'abord en Caster, et ce retour est un Shift.
  Entrer dans la forme déjà active n'est pas un Shift. Bear Form coûte 1.
- **Hunter.** Le Frenzy baisse de 1 au début de chaque tour, sauf le premier. Arcane Shot inflige 3.
  Trois Traps au plus, une par attaque ennemie, la plus ancienne d'abord.
- **Bibelots de classe.** Celui de départ est porté à chaque expédition ; les autres entrent dans la réserve
  de tirage de la classe une fois débloqués.
- **État `halved`.** Il prend un nom neutre à l'affichage, donné par la carte qui le pose.
- **PV de départ** (à régler par simulation) : Priest 65, Warrior à fixer par son agent, Rogue 65,
  Paladin 75, Mage 60, Warlock 70, Hunter 65, Shaman 60, Druid 65. Réglés le 12/11/2026 (`docs/equilibrage.md`) :
  Priest 52, Warrior 72, Mage 42, Rogue 49, Hunter 41 ; passe 2 (même jour) : Warrior 74, Rogue 50 ;
  passe 3 (13/11/2026) : Priest 36, Hunter 50.

## Fixé avec la progression par classe (12/11/2026)
- **Niveaux de classe** : seuils cumulés 100 / 250 / 450 / 700 / 1 000 / 1 400 ; expérience par expédition
  = (réputation × 0,5 + 15 si gagnée) × (1 + 0,1 × clé) : niveau 2 à la 2e expédition, niveau 7 vers la 20e
  (`docs/expedition.md`, « Niveau de classe ») ; formule revue le 13/11/2026 (voir « Campagne par zones »).
- **Réputation de classe supprimée** : la Ligue, commune au compte, ne débloque que le commun. Révéré de la
  Ligue : un bibelot au choix parmi 3 au départ, tiré dans la réserve de l'expédition (remplace « un bibelot
  de classe parmi 3 », sans objet) ; Exalté : un bibelot de plus chez le marchand (inchangé). Le titre
  « Dragonslayer » passe au niveau 7 de la classe.
- **Répartition** : Priest d'après `priest-progression.md` ; Warrior réparti dans `docs/classes.md`
  (« Progression par classe ») ; Mage, Rogue, Hunter d'après leur fiche.

## PV perdus par combat (décision du joueur, 13/11/2026)
- **6 à 9 PV perdus par combat normal pour toutes les classes**, combats normaux de 2,7 à 4 tours (bot
  heuristic, clé 0), quel que soit le style de survie. Le Rogue (≈ 6,3) sert de référence. Remplace les
  cibles par classe des fiches (Rogue 12–16, Priest ≈ 15, Mage ≤ 11, Hunter ≤ 13, Paladin 10–13, etc.).
  Mesures : `docs/equilibrage.md`, « Passe 3 ».
## Campagne par zones (décisions du joueur, 13/11/2026 ; remplace la Ligue)
Contrat et détails : `docs/zones.md`.
- **Sept zones dans l'ordre** : Westfall, Duskwood, Wetlands, Stranglethorn Vale, Swamp of Sorrows, Burning
  Steppes, Blackrock Mountain. Westfall (l'acte actuel) est la zone 1 ; les six autres sont déclarées,
  « Coming later ». Une expédition se joue dans une zone.
- **Gagner une zone avec une classe ouvre la zone suivante pour cette classe seulement.**
- **Trois sources de déblocage** : niveau de classe (cartes de la classe, inchangé) ; première victoire d'une
  classe dans une zone (une carte rare et forte de la classe, liée à la zone, introuvable autrement) ;
  première victoire du compte dans une zone (le commun : cartes neutres, bibelots communs, rencontres).
- **La Ligue des explorateurs est supprimée** (réputation, paliers, affichages, titre lié). Ses avantages :
  bibelot au choix parmi 3 au départ = première victoire du compte dans la zone 3 ; un bibelot de plus chez le
  marchand = zone 6. Les anciens paliers 1, 2, 3 tombent sur les zones 1, 2, 3 (choix du concepteur, le plus
  simple « dans l'ordre »).
- **Expérience** fondée sur l'avancée (étapes, élites, boss), mêmes gains qu'avant à la clé 0, **+15 % par
  niveau de clé**.
- **Clés par zone et par classe** (+1 à +5, affixes inchangés) ; **bibelots de clé** débloqués par la première
  victoire d'une classe à +1, +3 et +5 dans une zone. Pas de cote ni de classement.

## Encore ouvert
- Cibles de PV perdus par élite et par boss selon le style de survie (le Hunter perd 5 PV par élite, le
  Warrior 23).
