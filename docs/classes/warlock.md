# Warlock — fiche de conception

Développe la section « Warlock » du GDD des classes (Claude Docs) sans la contredire. Les règles communes
(tour, Cast, Interrupt, Cooldown, Exhaust, Retain, Execute, Surge, Spend N, Last Breath, états communs)
et le langage des cartes (`docs/interface.md`, « Langage des cartes ») s'appliquent tels quels ; cette
fiche n'écrit que ce que le Warlock ajoute. Tous les chiffres sont des points de départ, à régler par
simulation comme pour le Priest. L'état de dégâts sur la durée s'appelle **DoT** (encore `pain` /
« Pain » dans le code actuel) : « Apply DoT 6 » s'écrira `{ "apply", "pain", 6 }` tant que le renommage
n'est pas fait.

## En bref

| Élément | Warlock |
|---|---|
| Fantasme | Il paie ses meilleures cartes avec ses propres PV et les récupère en drainant ses ennemis. Sa barre de vie est une deuxième réserve de mana. |
| Ce qu'il fait seul | **Pay N HP** : un coût en PV, en plus du mana. Et lui seul empêche le DoT de baisser et se soigne dessus. |
| Ressource | **Soul Shards**, 0 à 5 : +1 à la mort d'un ennemi, +1 par carte de drain ; les grosses cartes en demandent par Spend N. |
| Voies | Affliction (le combat long), Demonology (un moteur permanent), Destruction (le coup unique). |
| Survie | Drain de vie : soins sur ses attaques et sur ses DoT, Absorb payé en PV. |
| PV de départ | **70** (Priest 65) : les PV sont aussi une ressource. |
| Deck de départ | Shadow Bolt ×4, Demon Skin ×4, Corruption ×1, Life Tap ×1. |
| Interrupt | Spell Lock (Demonology, niveau 1). |
| Last Breath | Soulstone (Demonology, niveau 4). |
| Bibelot de départ | Healthstone : une fois par combat, rend 8 PV quand les PV passent sous la moitié. |
| Mots-clés propres | Pay N HP, Demon. |
| Difficulté | Difficile. |

## 1. Règles propres

### 1.1 Pay N HP

- **Coût**, écrit en première ligne de la carte : « Pay 4 HP. ». Il s'ajoute au mana. Une carte qui
  demande N PV n'est jouable que si les PV actuels sont **strictement supérieurs** à N (après réductions,
  par exemple Demonic Rune) ; sinon elle est injouable (raison affichée « Not enough HP. »). Le paiement
  ne peut donc **jamais tuer**, ni déclencher un Last Breath.
- **Moment** : au jeu, après le mana, avant tout effet. Pour une carte Cast, au jeu aussi : si
  l'incantation est interrompue, les PV sont perdus comme le mana.
- **Ce n'est pas un coup** : le paiement ignore l'Absorb (il ne le consomme pas), la réduction de dégâts
  subis (Pain Suppression) et toute immunité ; il n'interrompt pas l'incantation du Warlock ; il ne compte
  pas comme « touché par une attaque ». Il compte comme **PV perdus** pour ce qui regarde les PV : seuil
  de Healthstone, Dark Harvest, statistiques (`hpPaid`, séparé de `hpLost`).
- Un tour gratuit (coût en mana 0) ne supprime pas le coût en PV.
- Les PV max ne changent pas ; les soins rendent les PV payés.

### 1.2 Soul Shards

- Compteur de combat `shards`, de 0 à 5, affiché dans la pastille violette près du mana (cinq éclats).
  0 au début de chaque combat (1 avec Felcloth Bag), perdu à la fin.
- **Gains** :
  - **+1 à la mort de chaque ennemi**, quelle qu'en soit la cause (carte, DoT, démon, bibelot), sbires
    compris. Plusieurs morts d'un coup : +1 chacune. Les sbires qui s'enfuient à la mort de leur chef ne
    meurent pas : rien. La mort qui termine le combat ne sert à rien (la ressource disparaît).
  - **+1 par carte de drain** : la clause imprimée « +1 Soul Shard. » (Drain Life, Drain Soul).
  - Clauses conditionnelles et Powers : Conflagrate (`DoT: +1 Soul Shard.`), Shadowburn
    (`Execute: +2 Soul Shards.`, Execute lu avant les dégâts, comme SW: Death), Dark Soul: Instability
    (+1 au début de chaque tour).
- **Plafond 5** : un gain au-delà est perdu (la pastille clignote). Les éclats se gardent d'un tour à
  l'autre et ne baissent jamais seuls.
- **Spend N** (forme commune) : **au jeu de la carte**, si le Warlock a au moins N éclats **et** que la
  clause peut avoir lieu, il en dépense N et le bonus est acquis ; sinon il ne dépense rien et la carte se
  joue sans le bonus. Automatique, sans choix (rythme, pas calcul), tout ou rien (Spend 2 avec 1 éclat :
  rien). « Peut avoir lieu » : Hand of Gul'dan ne dépense rien sans démon. Pour une carte Cast, le bonus
  est fixé au jeu (gardé dans l'enregistrement de l'incantation) : une interruption fait perdre les
  éclats dépensés. En main, la clause Spend est allumée quand les éclats suffisent, éteinte sinon.
- **À 0** : les clauses Spend sont éteintes, les cartes restent jouables.

### 1.3 DoT du Warlock

- C'est le DoT commun : posé par « Apply DoT N », il inflige N au début du tour du porteur en ignorant
  l'Absorb, puis N baisse de 1.
- **Agony** (Power) : tant qu'il est en jeu, le DoT **des ennemis** ne baisse plus après son tick. Il
  continue de se déclencher et de s'additionner aux nouvelles applications. Deux Agony = une. Le DoT
  porté par le Warlock lui-même n'est pas concerné. Fin du combat : tout disparaît.
- **Siphon Life** (Power) : chaque fois qu'un ennemi subit son DoT (tick qui inflige au moins 1, même
  s'il le tue), le Warlock se soigne de 1 (2 amélioré). Par ennemi et par tick.
- **Drain Soul** : soigne autant que le DoT de la cible au moment où la carte se résout (0 sans DoT ;
  l'éclat est quand même gagné).
- **Dark Harvest** (Power) : après chaque paiement de N PV (N > 0), pose DoT N sur un ennemi vivant au
  hasard.
- Un ennemi tué par son DoT donne son Soul Shard.
- La différence avec le Priest Shadow et le Rogue tient à ces trois cartes : le Warlock fige le DoT
  (Agony) et se soigne dessus (Siphon Life, Drain Soul). Aucune carte du Warlock ne **déclenche** le DoT
  d'un coup (c'est l'Envenom du Rogue).

### 1.4 Démons

- Un démon est une carte **Power** dont la plaque dit **Demon**. **Un seul démon à la fois** : en jouer
  un autre renvoie l'ancien (il quitte le combat, pile des cartes consumées) et le remplace. Rejouer le
  même démon le remplace aussi (pas de cumul).
- **Action** : le démon agit **à la fin de chaque tour du Warlock**, après sa dernière carte et avant la
  défausse de la main, au rang où il a été joué parmi les Powers. Le tour où il est invoqué, il agit
  déjà.
- Le démon n'a pas de PV : il ne peut être ni ciblé, ni tué, ni Stunned, ni interrompu. Ses dégâts ne sont
  pas ceux d'une carte Attack : Strength et Demoralized du Warlock ne les changent pas ; ceux de la cible
  (Sundered, Absorb) s'appliquent.
- **Cibles** : « a random enemy » = ennemi vivant tiré au hasard (flux `misc`). « your last target » =
  dernier ennemi visé par une carte du Warlock dans ce combat ; s'il est mort ou s'il n'y en a pas,
  un ennemi au hasard (même suivi que le familier du Hunter).
- **Agir maintenant** : « Your demon acts twice now. » (Health Funnel) et « Spend 1: your demon acts. »
  (Hand of Gul'dan) déclenchent son action de fin de tour tout de suite, en plus de celle de fin de tour.
  Health Funnel est injouable sans démon (raison « No demon. »).
- **Condition `Demon:`** : vraie si un démon est en jeu (Demonbolt, Soul Link, Spell Lock).
- **Summon Felhunter** : à son action, il interrompt le premier ennemi (de gauche à droite) qui annonce
  une incantation pas encore interrompue ; s'il n'y en a aucun, rien.
- **Summon Infernal** : « Deal 8 to all. » est l'effet de la carte quand elle est jouée ; l'action de
  fin de tour est la seconde ligne.
- **Summon Darkglare** (Affliction) est aussi un démon : il prend la place.

### 1.5 Absorb, Cast, Cooldown, Stunned, boss, attaques multiples

- Le Warlock a un seul emplacement d'incantation (règle commune ; deux, c'est le Mage). Chaos Bolt, Rain
  of Fire et Soul Fire sont en Cast : coûts payés au jeu (mana, PV, éclats), conditions lues à la
  résolution.
- « ignore Absorb » (Chaos Bolt dépensé) : tout le coup de la carte traverse l'Absorb de la cible.
- L'Absorb gagné en fin de tour (Voidwalker) dure pendant le tour ennemi et disparaît au début du tour
  suivant (règle commune).
- Le Warlock ne pose pas Stunned : les boss n'échappent à rien de son jeu. Son contrôle est Demoralized
  (Curse of Weakness) et Spell Lock.
- Attaque ennemie en plusieurs coups : Healthstone peut se déclencher entre deux coups.

### 1.6 Last Breath : Soulstone

- Power. Une fois par combat, quand les PV tomberaient à 0 : PV remis à 0 puis soignés de 20 (par
  `Combat.heal`). Version améliorée : coût 0. Le paiement de PV ne peut pas le déclencher (1.1).

### 1.7 Mots-clés propres (deux)

| Mot-clé | Infobulle (≤ 60 caractères) |
|---|---|
| Pay N HP | Costs N HP. Unplayable if it would drop you to 0. |
| Demon | Acts at the end of your turn. One at a time. |

La ressource a son infobulle, comme Insanity : **Soul Shard** — « Gained on kills and drains. Max 5. ».
Spend N, Execute, Last Breath, Interrupt sont communs.

## 2. Les 34 cartes

Raretés : 4 de départ, 13 communes, 11 inhabituelles, 6 rares. Voies : 10 cartes chacune.
« Niv. » = niveau de classe qui la débloque (section 5). « Plaque » = mots de la plaque du bas ; dans
`text` ils restent écrits comme chez le Priest (« Power. » / « Demon. » / « Cast. » en tête,
« Cooldown N. », « Exhaust. », « Retain. » en fin). École : `shadow` ou `fire` (voir Besoins moteur).
Icône = nom exact du fichier dans `~/Téléchargements/ICONS/` (champ `tga` de `UI/Art.lua`), tous vérifiés.
Texte « / » = retour de clause. Tous les textes tiennent en 3 lignes de 22 caractères au plus.

| id | Nom | Voie | École | Rareté | Niv. | Coût | Type | Plaque | Texte | Amélioré | Icône |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `shadow_bolt` | Shadow Bolt | départ | shadow | départ | 1 | 1 | Attack | — | Deal 6. | Deal 9. | `Spell_Shadow_ShadowBolt` |
| `demon_skin` | Demon Skin | départ | shadow | départ | 1 | 1 | Skill | — | Gain 5 Absorb. | Gain 8 Absorb. | `Spell_Shadow_RagingScream` |
| `corruption` | Corruption | départ | shadow | départ | 1 | 1 | Skill | — | Apply DoT 6 | Apply DoT 8 | `Spell_Shadow_AbominationExplosion` |
| `life_tap` | Life Tap | départ | shadow | départ | 1 | 0 | Skill | — | Pay 4 HP. / Draw 2. | Pay 2 HP. / Draw 2. | `Spell_Shadow_BurningSpirit` |
| `drain_life` | Drain Life | Affliction | shadow | commune | 1 | 1 | Attack | — | Deal 5. / Heal 5. / +1 Soul Shard. | Deal 7. / Heal 7. / +1 Soul Shard. | `Spell_Shadow_LifeDrain02` |
| `seed_of_corruption` | Seed of Corruption | Affliction | shadow | commune | 1 | 1 | Skill | — | Pay 3 HP. / Apply DoT 6 to all | Pay 3 HP. / Apply DoT 8 to all | `Spell_Shadow_SeedOfDestruction` |
| `unstable_affliction` | Unstable Affliction | Affliction | shadow | commune | 1 | 0 | Skill | — | Pay 4 HP. / Apply DoT 7 | Pay 4 HP. / Apply DoT 10 | `Spell_Shadow_UnstableAffliction_3` |
| `dark_pact` | Dark Pact | Affliction | shadow | commune | 1 | 0 | Skill | — | Pay 6 HP. / Gain 14 Absorb. | Pay 6 HP. / Gain 18 Absorb. | `Spell_Shadow_DarkRitual` |
| `agony` | Agony | Affliction | shadow | inhabituelle | 1 | 1 | Power | Power | DoT on enemies no longer drops. | Coût 0, même texte | `Spell_Shadow_CurseOfSargeras` |
| `siphon_life` | Siphon Life | Affliction | shadow | inhabituelle | 1 | 1 | Power | Power | Each enemy DoT tick: heal 1. | Each enemy DoT tick: heal 2. | `Spell_Shadow_Requiem` |
| `drain_soul` | Drain Soul | Affliction | shadow | inhabituelle | 2 | 1 | Skill | Cooldown 1 | Heal 1 per DoT on the target. / +1 Soul Shard. | Coût 0, même texte | `Spell_Shadow_Haunting` |
| `curse_of_weakness` | Curse of Weakness | Affliction | shadow | commune | 4 | 0 | Skill | Cooldown 3 | Apply Demoralized 2 ⌛ | Cooldown 2, même texte | `Spell_Shadow_CurseOfMannoroth` |
| `dark_harvest` | Dark Harvest | Affliction | shadow | rare | 6 | 1 | Power | Power | Pay HP: apply as much DoT to a random enemy. | Coût 0, même texte | `Spell_Warlock_HarvestofLife` |
| `summon_darkglare` | Summon Darkglare | Affliction | shadow | rare | 7 | 2 | Power | Demon | End of turn: apply DoT 3 to all. | End of turn: apply DoT 4 to all. | `INV_BeholderWarlock` |
| `summon_imp` | Summon Imp | Demonology | shadow | commune | 1 | 1 | Power | Demon | End of turn: deal 3 to a random enemy. | End of turn: deal 4 to a random enemy. | `Spell_Shadow_SummonImp` |
| `summon_voidwalker` | Summon Voidwalker | Demonology | shadow | commune | 1 | 1 | Power | Demon | End of turn: gain 4 Absorb. | End of turn: gain 6 Absorb. | `Spell_Shadow_SummonVoidWalker` |
| `demonbolt` | Demonbolt | Demonology | shadow | commune | 1 | 1 | Attack | — | Deal 7. / Demon: deal 4 more. | Deal 9. / Demon: deal 5 more. | `INV_DemonBolt` |
| `soul_link` | Soul Link | Demonology | shadow | commune | 1 | 1 | Skill | — | Gain 5 Absorb. / Demon: gain 4 more. | Gain 7 Absorb. / Demon: gain 5 more. | `Spell_Shadow_GatherShadows` |
| `spell_lock` | Spell Lock | Demonology | shadow | inhabituelle | 1 | 0 | Skill | Cooldown 2 | Interrupt the target's cast. / Demon: draw 1. | Cooldown 1, même texte | `Spell_Shadow_MindRot` |
| `health_funnel` | Health Funnel | Demonology | shadow | inhabituelle | 1 | 0 | Skill | Cooldown 1 | Pay 5 HP. / Your demon acts twice now. | Pay 3 HP. / Your demon acts twice now. | `Spell_Shadow_LifeDrain` |
| `hand_of_guldan` | Hand of Gul'dan | Demonology | shadow | inhabituelle | 2 | 1 | Attack | — | Deal 5 to all. / Spend 1: your demon acts. | Deal 7 to all. / Spend 1: your demon acts. | `ability_warlock_handofguldan` |
| `soulstone` | Soulstone | Demonology | shadow | rare | 4 | 1 | Power | Power | Last Breath: heal 20. | Coût 0, même texte | `Spell_Shadow_SoulGem` |
| `summon_felhunter` | Summon Felhunter | Demonology | shadow | inhabituelle | 6 | 1 | Power | Demon | End of turn: interrupt a casting enemy. | Coût 0, même texte | `Spell_Shadow_SummonFelHunter` |
| `summon_felguard` | Summon Felguard | Demonology | shadow | rare | 7 | 2 | Power | Demon | End of turn: deal 8 to your last target. | End of turn: deal 11 to your last target. | `Spell_Shadow_SummonFelGuard` |
| `immolate` | Immolate | Destruction | fire | commune | 1 | 1 | Attack | — | Deal 3. / Apply DoT 4 | Deal 5. / Apply DoT 5 | `Spell_Fire_Immolation` |
| `conflagrate` | Conflagrate | Destruction | fire | commune | 1 | 1 | Attack | Cooldown 1 | Deal 7. / DoT: +1 Soul Shard. | Deal 10. / DoT: +1 Soul Shard. | `Ability_Warlock_Backdraft` |
| `shadowburn` | Shadowburn | Destruction | shadow | commune | 1 | 1 | Attack | — | Deal 8. / Execute: +2 Soul Shards. | Deal 11. / Execute: +2 Soul Shards. | `Spell_Shadow_ScourgeBuild` |
| `shadow_ward` | Shadow Ward | Destruction | shadow | commune | 1 | 1 | Skill | — | Gain 6 Absorb. / Spend 1: gain 6 more. | Gain 8 Absorb. / Spend 1: gain 8 more. | `Spell_Shadow_AntiShadow` |
| `chaos_bolt` | Chaos Bolt | Destruction | fire | inhabituelle | 1 | 2 | Attack | Cast | Deal 20. / Spend 2: deal 12 more, ignore Absorb. | Deal 26. / Spend 2: deal 14 more, ignore Absorb. | `Ability_Warlock_ChaosBolt` |
| `rain_of_fire` | Rain of Fire | Destruction | fire | inhabituelle | 1 | 2 | Attack | Cast | Deal 10 to all. / Spend 2: deal 8 more to all. | Deal 13 to all. / Spend 2: deal 10 more to all. | `Spell_Shadow_RainOfFire` |
| `soul_fire` | Soul Fire | Destruction | fire | inhabituelle | 2 | 1 | Attack | Cast | Pay 6 HP. / Deal 24. | Pay 6 HP. / Deal 30. | `Spell_Fire_Fireball02` |
| `hellfire` | Hellfire | Destruction | fire | inhabituelle | 4 | 1 | Attack | — | Pay 5 HP. / Deal 9 to all. | Pay 5 HP. / Deal 12 to all. | `Spell_Fire_FelFlameRing` |
| `dark_soul` | Dark Soul: Instability | Destruction | fire | rare | 6 | 1 | Power | Power | Start of turn: +1 Soul Shard. | Coût 0, même texte | `spell_Warlock_Soulburn` |
| `summon_infernal` | Summon Infernal | Destruction | fire | rare | 7 | 2 | Power | Demon | Deal 8 to all. / End of turn: deal 6 to a random enemy. | Deal 10 to all. / End of turn: deal 8 to a random enemy. | `Spell_Shadow_SummonInfernal` |

Deck de départ (10 cartes) : Shadow Bolt ×4 (l'attaque), Demon Skin ×4 (la défense), Corruption ×1 (le
DoT) et Life Tap ×1 (le coût en PV).

Notes de calage (référence : Priest à coût et rareté égaux ; une carte à coût en PV vaut nettement plus
que son mana, comme le veut le GDD) :
- Départ : Shadow Bolt = Smite, Demon Skin = Inner Fire, Corruption (DoT 6) ≈ SW: Pain, Life Tap
  « Pay 4 HP. / Draw 2. » (GDD).
- PV contre puissance : Unstable Affliction (0 mana + 4 PV : DoT 7) contre Corruption (1 mana : DoT 6) ;
  Seed of Corruption (1 mana + 3 PV : DoT 6 à tous) contre Mind Sear (DoT 4 à tous) ; Soul Fire (1 mana
  + 6 PV : 24 en Cast) contre Holy Fire (2 mana : 24) ; Dark Pact (0 mana + 6 PV : 14 Absorb, GDD).
- Démons : 1 mana pour un effet de 3 à 4 par tour (Imp, Voidwalker) ; Consecration du Paladin fait 3 à
  tous pour 2 mana. Les démons rares coûtent 2.
- Chaos Bolt reprend le GDD (20, Spend 2 : +12 et ignore l'Absorb).

## 3. Les trois voies

### Affliction — le combat long

**Moteur.** Le DoT se pose sur un ennemi ou sur tous (Corruption, Unstable Affliction, Seed of
Corruption), Agony l'empêche de baisser, et chaque tick soigne le Warlock par Siphon Life ; Drain Life et
Drain Soul soignent et donnent des Soul Shards. Plus le combat dure, plus il est fort : les PV payés pour
poser le DoT reviennent par les ticks.

**Cartes.** Drain Life, Seed of Corruption, Unstable Affliction, Dark Pact, Agony, Siphon Life (niveau 1) ;
Drain Soul (2), Curse of Weakness (4), Dark Harvest (6), Summon Darkglare (7). Plus Corruption et Life
Tap au départ.

**Avec Demonology.** Le Voidwalker et Soul Link tiennent pendant que le DoT travaille ; Health Funnel
paie des PV qui, sous Dark Harvest, deviennent du DoT ; Summon Darkglare (niveau 7) est un démon
d'Affliction qui remplace l'Imp.

**Avec Destruction.** Les drains remplissent les Soul Shards que Chaos Bolt et Rain of Fire dépensent ;
Immolate et Conflagrate ajoutent du DoT que Agony fige ; sous Dark Harvest, Hellfire et Soul Fire posent
du DoT en plus de leurs dégâts.

**Tour type.** Agony en jeu, deux ennemis à DoT 6, 3 mana. Seed of Corruption (1 mana, 3 PV : DoT 6 à
tous, soit 12 chacun) → Drain Life (1 mana : 5 dégâts, soin 5, +1 éclat) → Dark Pact (0 mana, 6 PV :
14 Absorb) → Shadow Bolt (1 mana, 6). Au tour ennemi, chacun subit 12 avant d'agir, et Siphon Life rend
1 PV par tick.

### Demonology — un moteur permanent

**Moteur.** Un démon (Imp, Voidwalker, puis Felhunter et Felguard) agit seul à chaque fin de tour ; les
cartes `Demon:` (Demonbolt, Soul Link, Spell Lock) valent plus tant qu'il est là, et Health Funnel et
Hand of Gul'dan le font agir hors de son tour. La décision est de choisir le démon, puis d'en changer
quand le combat change (Voidwalker contre un gros cogneur, Felhunter contre des lanceurs de sorts).

**Cartes.** Summon Imp, Summon Voidwalker, Demonbolt, Soul Link, Spell Lock, Health Funnel (niveau 1) ;
Hand of Gul'dan (2), Soulstone (4), Summon Felhunter (6), Summon Felguard (7).

**Avec Affliction.** Voir Affliction : le démon défend ou frappe pendant que le DoT monte ; Darkglare
fait du démon un moteur de DoT.

**Avec Destruction.** Hand of Gul'dan dépense les éclats de Shadowburn et Conflagrate pour faire agir le
démon ; Summon Infernal (niveau 7) est un démon de Destruction ; le Felguard frappe la dernière cible de
Chaos Bolt.

**Tour type.** Imp en jeu, 3 mana. Health Funnel (0 mana, 5 PV : l'Imp agit deux fois, 2 × 3) →
Demonbolt (1 mana : 7 + 4 = 11) → Soul Link (1 mana : 5 + 4 = 9 Absorb) → Shadow Bolt (1 mana, 6). Fin
du tour : l'Imp frappe encore 3.

### Destruction — le coup unique

**Moteur.** Les attaques à 1 mana (Immolate, Conflagrate, Shadowburn) remplissent les Soul Shards, que
Chaos Bolt et Rain of Fire dépensent en Cast pour des coups énormes qui ignorent l'Absorb ; Soul Fire et
Hellfire paient en PV ce que le mana ne suffit pas à payer. Il frappe rarement, mais très fort.

**Cartes.** Immolate, Conflagrate, Shadowburn, Shadow Ward, Chaos Bolt, Rain of Fire (niveau 1) ; Soul
Fire (2), Hellfire (4), Dark Soul: Instability (6), Summon Infernal (7).

**Avec Affliction.** Voir Affliction : Affliction fournit les éclats (drains) et le soin, Destruction
les dépense.

**Avec Demonology.** Voir Demonology : le démon frappe entre deux gros sorts et Hand of Gul'dan dépense
les éclats en trop.

**Tour type.** 2 éclats, l'ennemi a le DoT d'Immolate, 3 mana. Conflagrate (1 mana : 7, DoT : +1 éclat,
3 éclats) → Chaos Bolt (2 mana, Spend 2 : au début du tour suivant, 32 qui ignorent l'Absorb du
VanCleef en Parade). Il reste 1 éclat pour Shadow Ward au tour suivant ; Demon Skin en main couvre le
Coup de pied qui interromprait.

## 4. Bibelots de classe (6)

| id | Nom | Rareté | Niv. | Effet (affiché) | Icône |
|---|---|---|---|---|---|
| `healthstone` | Healthstone | départ | 1 | Once per combat, when you drop below half HP, heal 8. | `INV_Stone_04` |
| `felcloth_bag` | Felcloth Bag | commune | 1 | Start each combat with 1 Soul Shard. | `INV_Misc_Bag_FelclothBag` |
| `demonic_rune` | Demonic Rune | inhabituelle | 3 | Your first Pay HP card each turn costs 2 HP less. | `INV_Misc_Rune_04` |
| `black_book` | The Black Book | inhabituelle | 5 | Your first Demon card each combat costs 0. | `INV_Misc_Book_06` |
| `soul_harvester_charm` | Soul Harvester's Charm | rare | 7 | When an enemy dies, its DoT moves to a random enemy. | `INV_Misc_Gem_Amethyst_02` |
| `infernal_stone` | Infernal Stone | rare | 7 | Each Soul Shard you spend heals 2 HP. | `INV_Stone_05` |

Précisions : Healthstone se déclenche après toute perte de PV (coup, DoT, paiement) qui fait passer de la
moitié ou plus à moins de la moitié des PV max, si le Warlock est encore en vie ; elle ne sauve pas d'un
coup mortel (Soulstone le fait). Demonic Rune ne descend pas sous 0 PV de coût (Life Tap amélioré, 2 PV,
devient gratuit). The Black Book compte mana seulement, pas les PV. Soul Harvester's Charm : le DoT
déplacé s'ajoute à celui de l'ennemi tiré (flux `misc`) ; rien si plus aucun ennemi.

## 5. Progression (niveaux de classe 1 à 7)

| Niveau | Affliction | Demonology | Destruction | Bibelots |
|---|---|---|---|---|
| 1 | Drain Life, Seed of Corruption, Unstable Affliction, Dark Pact, Agony, Siphon Life | Summon Imp, Summon Voidwalker, Demonbolt, Soul Link, Spell Lock, Health Funnel | Immolate, Conflagrate, Shadowburn, Shadow Ward, Chaos Bolt, Rain of Fire | Healthstone, Felcloth Bag |
| 2 | Drain Soul | Hand of Gul'dan | Soul Fire | — |
| 3 | — | — | — | Demonic Rune |
| 4 | Curse of Weakness | Soulstone | Hellfire | — |
| 5 | — | — | — | The Black Book |
| 6 | Dark Harvest | Summon Felhunter | Dark Soul: Instability | — |
| 7 | Summon Darkglare (rare) | Summon Felguard (rare) | Summon Infernal (rare) | Soul Harvester's Charm, Infernal Stone |

Plus les 4 cartes de départ au niveau 1 (22 cartes).

**Un Warlock de niveau 1 peut gagner** : Affliction a déjà Agony, Siphon Life et Drain Life (le DoT figé
qui soigne), Demonology ses deux démons de base et ses cartes `Demon:`, Destruction ses générateurs
d'éclats et ses deux gros Cast. L'Interrupt (Spell Lock) est là dès le départ, avec Healthstone. La seule
sécurité absente est Soulstone.

**Ce que débloquent les niveaux suivants** (des façons de jouer, pas des versions plus fortes) :
- Niveau 2 : Drain Soul (le drain proportionnel au DoT), Hand of Gul'dan (les éclats dépensés pour le
  démon : Demonology + Destruction), Soul Fire (le gros coup payé en PV plutôt qu'en éclats).
- Niveau 4 : Curse of Weakness (une défense qui marche contre les boss), Soulstone (le droit à
  l'erreur), Hellfire (Destruction contre les groupes).
- Niveau 6 : Dark Harvest (les PV payés deviennent du DoT : Affliction qui joue Life Tap et Hellfire),
  Summon Felhunter (le démon qui coupe les sorts), Dark Soul: Instability (un éclat par tour : un Chaos
  Bolt dépensé tous les deux tours).
- Niveau 7 : Summon Darkglare (DoT qui monte tout seul), Summon Felguard (le démon qui tue), Summon
  Infernal (un démon pour Destruction).

## 6. Besoins moteur et interface

Au-delà des règles communes et de ce qu'apportent les classes précédentes (Spend N générique, ressource de
classe générique, `onCardCommitted` du Mage, `level` sur les cartes à la place de `rep`) :

1. **Coût en PV** : champ de carte `payHp = N` (avec `up.payHp`), crochet `modify "payHp"` (Demonic
   Rune). `Combat.canPlay` : `hp > N`, sinon raison `"hp"` (« Not enough HP. »). `Combat.payHp(c, n)`
   appelé dans `Combat.play` après le mana et avant la mise en emplacement ou la résolution : `hp -= n`,
   sans Absorb, sans `calcDamage`, sans `onPlayerHit`, sans `interruptPlayer` ; événement
   `{ t = "pay_hp", n }`, statistique `hpPaid`, puis `fire("onPayHp", n)` (Dark Harvest) et
   `fire("onHpLost", n)`.
2. **Événement `onHpLost`** après toute perte de PV du joueur (coup ennemi, DoT, paiement) avec les PV
   d'avant, pour Healthstone (seuil de la moitié).
3. **Soul Shards** : ressource générique `{ id = "shards", max = 5 }` ; effet `{ "shard", n }` plafonné ;
   gain dans `Combat.kill` pour un ennemi (pas pour `fled`) ; événement `{ t = "shards", n, total }`.
4. **Spend N** au jeu : effet `{ "spend", n, effects = {...}, need = fonction|nil }`, résolu dans
   `Combat.play` pour décider, avec le drapeau gardé dans `ctx` (carte immédiate) ou dans l'enregistrement
   de l'incantation (Cast, l'instance de carte restant immuable). `need` : condition « la clause peut
   avoir lieu » (démon présent). Événement `{ t = "spend", n }`, `fire("onSpend", n)` (Infernal Stone).
5. **Agony** : crochet `modify "dotDecay"` lu dans `tickPeriodic` pour les ennemis (décrément 1 → 0).
6. **Tick ennemi** : `fire("onEnemyTick", unit, n)` après les dégâts du DoT d'un ennemi (Siphon Life).
7. **Démons** : champ `demon = true` sur une carte `power` ; dans `afterPlay`, retrait de l'ancien démon
   de `c.player.powers` vers `c.exhaust` ; crochet de Power `demonAct(c, power)` appelé par `onTurnEnd`
   (déjà tiré avant la défausse) et par `Combat.demonAct(c, times)` pour les cartes « acts now » ;
   `Combat.hasDemon(c)` pour `Demon:` et pour `canPlay` de Health Funnel (raison « No demon. »).
   Dégâts des démons : `calcDamage` sans source joueur (ni Strength ni Demoralized du joueur, mais
   Sundered et Absorb de la cible), source `"demon"` dans les événements pour l'animation.
8. **Dernière cible** : `c.player.lastTarget` (uid) mis à jour à chaque carte jouée sur un ennemi
   (partagé avec le familier du Hunter). Cible au hasard : `Rng.int(c.rng.misc, ...)`.
9. **Felhunter** : réutilise l'effet `interrupt` sur le premier ennemi dont l'intention est une
   incantation non interrompue.
10. **« ignore Absorb »** pour un effet `damage` (option `pierce = true`, déjà prévue par
    `Combat.dealDamage`).
11. **Last Breath** Soulstone : `preventDeath` qui met `hp = 0` puis `Combat.heal(c, p, 20)`.
12. **Écoles** : le Warlock emploie `shadow` et `fire` (Art.schools a déjà `shadow`) ; aucune règle ne
    les lit pour l'instant, c'est de l'affichage.
13. **Interface** : pastille violette à cinq éclats ; coût en PV visible sans lire le texte (gouttelette
    rouge et nombre sous la languette de mana, en plus de la première ligne) ; raison « Not enough HP. » ;
    jeton du démon distinct des autres Powers (cadre de démon, action de fin de tour en aperçu comme une
    intention : « 3 → random », « +4 Absorb », « interrupt ») ; animation de l'action du démon en fin
    de tour et de la perte de PV payée (chiffre rouge sans éclat d'Absorb) ; clause Spend allumée ou
    éteinte selon les éclats ; plaque « Demon » ; mots-clés Pay N HP et Demon dans `Art.keywords`,
    infobulle de la ressource.
14. **Bots** (`Sim/`) : valeur des PV comme ressource (ne pas payer sous un seuil de PV dépendant de
    la suite de l'expédition), choix du démon selon les intentions, Spend automatique (savoir garder
    une carte Spend pour quand les éclats sont là).

## 7. Risques d'équilibrage et mesures

**Style de survie : drain de vie.** Le Warlock perd plus de PV que les autres (coups + paiements) et en
regagne davantage. Cibles en proportion de ses 70 PV : PV perdus **bruts** (coups + paiements) jusqu'à
1,4 fois ceux du Priest (≈ 22 en combat normal) ; PV perdus **nets** (bruts − soins pendant le combat) au
niveau du Priest : ≈ 16 en normal, ≈ 21 en élite, ≤ 55 au boss ; victoires heuristic 65–80 %.

Risques :
- **Spirale de PV** : payer tôt dans l'expédition coûte au boss. Mesurer `hpPaid` par combat et par
  acte, et les PV à l'entrée du boss comparés au Priest ; si le Warlock arrive plus bas de plus de
  10 PV, baisser les coûts en PV avant de toucher aux soins.
- **Agony + Darkglare** : DoT qui monte sans limite dans les longs combats (boss). Mesurer les tours et
  le DoT moyen au boss ; si le boss tombe en moins de 5 tours avec Darkglare, Darkglare passe à
  « apply DoT 2 to all ».
- **Siphon Life + Seed sous Agony** : soin par tour égal au nombre d'ennemis, sans fin. Mesurer les PV
  soignés par combat ; plafonner à « heal 1 » même amélioré si les soins dépassent les pertes.
- **Felhunter** : coupe tous les sorts ennemis à chaque tour. Mesurer `enemyCastsInterrupted` et la
  victoire contre Sorcier et Mystique avec et sans lui.
- **Éclats** : rares contre un ennemi seul (boss : seuls les deux sbires de VanCleef en donnent).
  Mesurer les Spend réussis / ratés par carte et les éclats perdus au plafond ; si Chaos Bolt part sans
  Spend plus d'une fois sur deux, Destruction n'a pas assez de générateurs.
- **Recoupements** : DoT avec le Priest Shadow et le Rogue (tenu par Agony, Siphon Life, Drain Soul et
  l'absence de déclenchement du DoT) ; démon avec le familier du Hunter (tenu par le choix et le
  changement de démon, et par le démon qui ne frappe pas toujours : Voidwalker, Felhunter) ; « cartes
  payées en PV » de la voie Fury du Warrior (à trancher, voir rapport).
- **Difficulté** : la classe la plus exigeante après le Druid. Mesurer l'écart entre bots `heuristic`
  et `greedy` : s'il est bien plus grand que chez le Priest, la classe demande trop de calcul.

Mesures à ajouter aux rapports : PV perdus bruts et nets, `hpPaid`, soins par source (Drain Life, Drain
Soul, Siphon Life, Healthstone), éclats gagnés par source, perdus au plafond et dépensés par carte,
uptime du démon et démon choisi, DoT moyen sur les ennemis par tour, tours par combat, victoires par deck
forcé d'une seule voie et par paire de voies.
