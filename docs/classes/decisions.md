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
  Paladin 75, Mage 60, Warlock 70, Hunter 65, Shaman 60, Druid 65.

## Encore ouvert
- Seuils d'expérience des niveaux de classe (proposition : 100 / 250 / 450 / 700 / 1 000 / 1 400) et ce
  que deviennent les récompenses Révéré et Exalté de la Ligue.
- Cible de PV perdus par combat pour chaque style de survie : à mesurer classe par classe.
