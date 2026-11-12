# Druid — fiche de conception

Développe la section Druid du GDD des classes (Claude Docs, « Slay the Dragon — GDD des classes »)
sans la contredire. Format des cartes, chiffres et raretés calés sur le Priest (`Data/Priest.lua`) ;
écriture des textes : `docs/interface.md`, « Langage des cartes ». L'état de dégâts sur la durée
s'appelle **DoT** (encore `pain` / « Pain » dans le code). Textes affichés en anglais.

Résumé : la ressource du Druid est sa **forme active** (Caster au départ, Bear, Cat, Moonkin),
affichée dans la pastille de classe. Les cartes **Shift** changent de forme ; beaucoup de cartes ont
une ou deux lignes `Bear:` / `Cat:` / `Moonkin:` ; les Powers à effet `Shift:` récompensent les
changements. Survie : selon la forme (Absorb en Bear, vitesse en Cat, Cast en Moonkin, soins en
Caster). Difficulté : difficile.

| Élément | Valeur |
| --- | --- |
| PV de départ | 65 (comme le Priest ; à mesurer) |
| Deck de départ | Wrath ×4, Bear Form ×4, Maul ×1, Rejuvenation ×1 |
| Bibelot de départ | Idol of the Wild |
| Interrupt | Skull Bash (Feral) |
| Last Breath | Rebirth (Restoration) |
| Mots-clés propres | `Shift`, `Caster` (deux, le maximum du gabarit) |

## 1. Règles propres (spécification)

### Formes

| Forme | Effet permanent | Infobulle (≤ 60 caractères) |
| --- | --- | --- |
| Caster | Aucun. Forme de départ ; les cartes `Caster` s'y jouent. | `Starting form. Heal cards are played in it.` |
| Bear | L'Absorb gagné augmente de moitié (arrondi à l'inférieur). | `Absorb you gain is increased by half.` |
| Cat | La première Attack hors Cast de chaque tour coûte 0. | `First Attack each turn costs 0 (not Cast).` |
| Moonkin | Les cartes Cast infligent 4 de plus par coup. | `Cast cards deal 4 more damage per hit.` |

Les formes sont affichées comme des états (pastille et infobulle), pas comme des mots-clés : le
Druid n'a que deux mots-clés propres.

### Mots-clés propres

| Mot-clé | Où | Infobulle (≤ 60 caractères) |
| --- | --- | --- |
| `Shift` | plaque des cartes qui changent de forme ; condition `Shift:` sur les Powers | `Enter a form. Shift: triggers each time your form changes.` |
| `Caster` | plaque des cartes de soin | `Heal card: returns you to Caster form before acting.` |

### Règles, au cas limite près

1. **Forme en début de combat.** Chaque combat commence en Caster. La forme ne se garde pas d'un
   combat à l'autre. Entrer dans la forme de départ (ou dans celle qu'impose un bibelot, comme Idol
   of the Moon) n'est pas un Shift : aucun effet `Shift:` ne se déclenche.
2. **Ordre de résolution.** Les clauses d'une carte se résolvent dans l'ordre du texte. `Enter Bear.`
   change la forme tout de suite : les clauses suivantes de la même carte voient la nouvelle forme
   (Bear Form : `Enter Bear.` puis `Gain 4 Absorb.` donne 6 Absorb).
3. **Shift.** Un Shift est un changement de forme effectif. Chaque Shift déclenche une fois les effets
   `Shift:` (Powers dans l'ordre où ils ont été joués, puis bibelots), juste après le changement et
   avant la clause suivante.
4. **Entrer dans la forme déjà active.** Rien ne change : pas de Shift, aucun effet `Shift:`, pas de
   mana d'Idol of the Wild. Le reste de la carte s'applique normalement (Bear Form en Bear : 6 Absorb).
   Raison : sinon une carte Shift à 0 mana rejouée dans la même forme déclencherait `Shift:` sans
   rien changer, ce qui récompenserait le contraire de ce que demande la classe.
5. **Soins seulement en Caster : ni carte injouable, ni effet ignoré.** Une carte `Caster` (toute carte
   dont les effets à la pose soignent ou donnent Regen à soi) jouée dans une autre forme ramène
   d'abord en Caster ; ce retour est un Shift (il déclenche `Shift:` et Idol of the Wild), puis la carte
   agit en Caster. Les soins restent donc joués en Caster, comme le veut le GDD, et comme dans WoW où
   lancer un soin fait quitter la forme.
   - Pourquoi pas « injouable » : le deck de départ entre en Bear et n'a aucun moyen d'en sortir ;
     Rejuvenation serait morte dès le premier Bear Form. Pourquoi pas « effet ignoré » : une carte qui
     se joue pour rien est un piège.
   - Le mot `Caster` est affiché sur la plaque de toute carte qui soigne, y compris une carte neutre
     (Heavy Silk Bandage) : la règle suit l'effet, pas la classe d'origine.
   - Ne sont pas des cartes `Caster` : les soins qui ne viennent pas de la pose d'une carte (tic de
     Regen, Last Breath d'un Power, bibelot, potion). Ils agissent dans toutes les formes.
   - Contrainte de conception : aucune carte `Caster` n'a Cast (pas de soin en attente qui se
     résoudrait dans une autre forme).
6. **Bear et Absorb.** Chaque gain d'Absorb sur soi est multiplié par 1,5 et arrondi à l'inférieur,
   **après** les bonus fixes (Heart of the Wild, Rapture, bibelots) : 3 → 4, 4 → 6, 5 → 7, 7 → 10.
   Chaque gain est arrondi à part (Barkskin : 7 → 10 puis 4 → 6). Vaut pour les cartes, Powers,
   bibelots et potions. L'Absorb déjà acquis ne change pas en entrant ou en sortant de Bear.
7. **Cat et coût.** Une fois par tour, la première Attack sans Cast jouée en Cat dont le coût serait
   supérieur à 0 coûte 0.
   - Le coût tombe à 0 quelles que soient les autres réductions (elles ne s'accumulent pas au-delà).
   - Une Attack qui coûte déjà 0 ne consomme pas la gratuité ; une Attack jouée dans une autre forme
     non plus.
   - Sortir de Cat puis y revenir dans le même tour ne rend pas la gratuité.
   - Les cartes Cast en sont exclues : sinon Cat Form + Starfire donnerait un Cast de 24 gratuit.
   - Les cartes en main affichent leur coût réel (0 pour les Attack concernées tant que la gratuité
     est disponible).
8. **Moonkin et attaques multiples.** +4 par coup, comme Strength : à chaque cible d'une carte de zone
   et à chaque coup d'une carte à plusieurs coups. Ajouté avant les multiplicateurs (Sundered,
   Demoralized). Ne s'applique qu'aux cartes Cast (pas aux dégâts d'un Power comme Starfall, pas au
   DoT).
9. **Shift et Cast en cours.** Changer de forme n'interrompt pas un Cast. Une carte Cast lit la forme
   **à sa résolution** (début du tour suivant, avant la pioche) : lignes de forme et bonus de Moonkin
   compris. Jouer Starfire en Moonkin puis passer en Bear pour encaisser fait perdre les +4 : c'est le
   choix de la voie Balance (gourmandise ou sécurité).
10. **Lignes de forme.** `Bear: effect.` ne s'applique que si la forme est active au moment où la
    clause se résout. Deux lignes de forme par carte au plus. Un état posé sous condition de forme
    reste dans sa clause (`Cat: apply DoT 3.`), comme les exceptions du langage des cartes.
11. **Fin de tour, fin de combat.** La forme reste d'un tour à l'autre jusqu'au prochain Shift. Elle
    revient à Caster à la fin du combat. Last Breath (Rebirth) ne change pas la forme.

## 2. Les 34 cartes

Colonnes : identifiant ; nom du sort ; voie ; rareté ; coût ; type ; mots de plaque ; texte de base et
amélioré (`/` = retour de clause ; mots de plaque omis, ils restent dans `text` comme pour le
Priest) ; icône (fichier `.tga` vérifié dans `~/Téléchargements/ICONS`, en minuscules). « Deck de
départ » et le niveau de déblocage : section 5.

### Départ (4, rareté basic)

| Id | Nom | Coût | Type | Plaque | Texte | Amélioré | Icône |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `wrath` | Wrath | 1 | Attack | — | Deal 6. / Moonkin: deal 3 more. | Deal 9. / Moonkin: deal 3 more. | `spell_nature_abolishmagic` |
| `bear_form` | Bear Form | 1 | Skill | Shift | Enter Bear. / Gain 4 Absorb. | Enter Bear. / Gain 6 Absorb. | `ability_racial_bearform` |
| `maul` | Maul | 1 | Attack | — | Deal 5. / Bear: gain 3 Absorb. / Cat: apply DoT 3. | Deal 7. / Bear: gain 4 Absorb. / Cat: apply DoT 4. | `ability_druid_maul` |
| `rejuvenation` | Rejuvenation | 1 | Skill | Caster, Exhaust | Gain Regen 4 | Gain Regen 6 | `spell_nature_rejuvenation` |

### Balance (10)

| Id | Nom | Rareté | Coût | Type | Plaque | Texte | Amélioré | Icône |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `moonkin_form` | Moonkin Form | common | 0 | Skill | Shift | Enter Moonkin. / Gain 2 Absorb. | Enter Moonkin. / Gain 4 Absorb. | `spell_nature_forceofnature` |
| `starfire` | Starfire | common | 2 | Attack | Cast | Deal 24. | Deal 31. | `spell_arcane_starfire` |
| `moonfire` | Moonfire | common | 1 | Attack | — | Deal 2 to all. / Apply DoT 3 to all | Deal 3 to all. / Apply DoT 4 to all | `spell_nature_starfall` |
| `faerie_fire` | Faerie Fire | common | 0 | Skill | Cooldown 2 | Draw 1. / Apply Sundered 1 ⌛ | Draw 1. / Apply Sundered 2 ⌛ | `spell_nature_faeriefire` |
| `hurricane` | Hurricane | uncommon | 2 | Attack | Cast | Deal 15 to all. | Deal 19 to all. | `spell_nature_cyclone` |
| `natures_grace` | Nature's Grace | uncommon | 1 | Power | — | Moonkin: Cast cards cost −1. | (coût 0) | `spell_nature_naturesblessing` |
| `innervate` | Innervate | uncommon | 0 | Skill | Exhaust | +2 mana. | +3 mana. | `spell_nature_lightning` |
| `entangling_roots` | Entangling Roots | uncommon | 1 | Attack | Cast, Cooldown 3 | Deal 9. / Apply Stunned 1 ⌛ | Deal 12. / Apply Stunned 1 ⌛ (Cooldown 2) | `spell_nature_stranglevines` |
| `starfall` | Starfall | rare | 2 | Power | — | Turn start: deal 3 to all. / Moonkin: deal 3 more. | (coût 1) | `ability_druid_starfall` |
| `eclipse` | Eclipse | rare | 1 | Power | — | Cast cards: apply DoT 3 to all. | Cast cards: apply DoT 4 to all. | `ability_druid_eclipse` |

### Feral (10)

| Id | Nom | Rareté | Coût | Type | Plaque | Texte | Amélioré | Icône |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `cat_form` | Cat Form | common | 0 | Skill | Shift | Enter Cat. / Draw 1. | Enter Cat. / Draw 2. | `ability_druid_catform` |
| `shred` | Shred | common | 1 | Attack | — | Deal 7. / Cat: deal 4 more. | Deal 9. / Cat: deal 6 more. | `spell_shadow_vampiricaura` |
| `swipe` | Swipe | common | 1 | Attack | — | Deal 4 to all. / Bear: gain 3 Absorb. | Deal 6 to all. / Bear: gain 4 Absorb. | `inv_misc_monsterclaw_03` |
| `rake` | Rake | common | 1 | Attack | — | Deal 4. / Apply DoT 5 | Deal 5. / Apply DoT 7 | `ability_druid_disembowel` |
| `demoralizing_roar` | Demoralizing Roar | common | 1 | Skill | Cooldown 2 | Bear: gain 4 Absorb. / Apply Demoralized 1 ⌛ to all | Bear: gain 6 Absorb. / Apply Demoralized 1 ⌛ to all | `ability_druid_demoralizingroar` |
| `skull_bash` | Skull Bash | uncommon | 0 | Attack | Cooldown 2 | Interrupt the target's cast. / Deal 3. | Interrupt the target's cast. / Deal 3. (Cooldown 1) | `inv_bone_skull_04` |
| `feral_instinct` | Feral Instinct | uncommon | 1 | Power | — | Shift: deal 3 to all. | Shift: deal 4 to all. | `ability_ambush` |
| `mangle` | Mangle | uncommon | 1 | Attack | — | Deal 6. / Bear: apply Sundered 2 ⌛. / Cat: apply DoT 5. | Deal 8. / Bear: apply Sundered 3 ⌛. / Cat: apply DoT 7. | `ability_druid_mangle2` |
| `heart_of_the_wild` | Heart of the Wild | rare | 1 | Power | — | Bear: Absorb gains +2. / Cat: Attacks deal 3 more. | (coût 0) | `spell_holy_blessingofagility` |
| `survival_instincts` | Survival Instincts | rare | 1 | Skill | Shift, Cooldown 4 | Enter Bear. / Damage taken halved until next turn. | (Cooldown 3) | `ability_druid_tigersroar` |

### Restoration (10)

| Id | Nom | Rareté | Coût | Type | Plaque | Texte | Amélioré | Icône |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `regrowth` | Regrowth | common | 1 | Skill | Caster, Exhaust | Heal 4. / Gain Regen 3 | Heal 6. / Gain Regen 4 | `spell_nature_resistnature` |
| `insect_swarm` | Insect Swarm | common | 1 | Skill | — | Apply DoT 4 / Apply Demoralized 1 ⌛ | Apply DoT 6 / Apply Demoralized 2 ⌛ | `spell_nature_insectswarm` |
| `mark_of_the_wild` | Mark of the Wild | common | 1 | Skill | Caster | Gain 5 Absorb. / Gain Regen 2 | Gain 7 Absorb. / Gain Regen 3 | `spell_nature_regeneration` |
| `remove_curse` | Remove Curse | common | 0 | Skill | Cooldown 2 | Remove negative effects. / Draw 1. | Remove negative effects. / Draw 2. | `spell_holy_removecurse` |
| `swiftmend` | Swiftmend | uncommon | 0 | Skill | Caster, Cooldown 2 | Heal twice your Regen. | Heal twice your Regen. / Draw 1. | `inv_relics_idolofrejuvenation` |
| `healing_touch` | Healing Touch | uncommon | 1 | Skill | Caster, Exhaust | Heal 8. / Regen: heal 4 more. | Heal 11. / Regen: heal 5 more. | `spell_nature_healingtouch` |
| `barkskin` | Barkskin | uncommon | 1 | Skill | Cooldown 2 | Gain 7 Absorb. / Regen: gain 4 more. | Gain 9 Absorb. / Regen: gain 5 more. | `spell_nature_stoneclawtotem` |
| `gift_of_nature` | Gift of Nature | uncommon | 1 | Power | — | Regen: Attacks deal 2 more. | Regen: Attacks deal 3 more. | `spell_nature_protectionformnature` |
| `tranquility` | Tranquility | rare | 2 | Skill | Caster, Exhaust | Heal 6. / Gain Regen 5 | Heal 9. / Gain Regen 6 | `spell_nature_tranquility` |
| `rebirth` | Rebirth | rare | 1 | Power | — | Last Breath: stay at 15 HP. | (coût 0) | `spell_nature_reincarnation` |

Comptes : 4 de départ ; 13 communes (Balance 4, Feral 5, Restoration 4) ; 11 inhabituelles (4, 3,
4) ; 6 rares (2 par voie). Cartes Shift : Bear Form, Moonkin Form, Cat Form, Survival Instincts.
Cartes Caster : Rejuvenation, Regrowth, Mark of the Wild, Swiftmend, Healing Touch, Tranquility.
Cartes à deux lignes de forme : Maul, Mangle, Heart of the Wild.

### Calage sur le Priest (coût et rareté égaux)

| Druid | Repère Priest | Écart voulu |
| --- | --- | --- |
| Wrath 6/9 | Smite 6/9 | +3 en Moonkin, absent du deck de départ |
| Bear Form 4/6 Absorb | Inner Fire 5/8 | 6/9 en Bear ; Rejuvenation fait sortir de Bear |
| Rejuvenation Regen 4/6, Exhaust | Renew 3/5 (commune) | le Druid n'a pas PW: Shield ni SW: Pain |
| Starfire 24/31, Cast | Holy Fire 24/31 + DoT 3/4 | pas de DoT ; +4 en Moonkin |
| Moonfire 2 + DoT 3 à tous | Mind Sear DoT 4 à tous, Holy Nova 4 à tous + Regen 2 | même total |
| Faerie Fire 0, Cooldown 2 | Angelic Feather 0, Cooldown 2 | Sundered au lieu d'Absorb |
| Shred 7 / Cat +4 | Mind Flay 8 / DoT: +2 Insanity, draw 1 | 11 gratuit en Cat |
| Swipe 4 à tous / Bear 3 | Holy Nova 4 à tous / Regen 2 | Absorb au lieu de Regen |
| Rake 4 + DoT 5 | Vampiric Touch DoT 3 + Regen 1 | pas de soin |
| Regrowth 4 + Regen 3, Exhaust | Flash Heal 7 + Draw 1, Exhaust | même total (10 PV) |
| Mark of the Wild 5 Absorb + Regen 2 | Radiance 4 Absorb + Atonement 1 | fait quitter la forme |
| Hurricane 15 à tous, Cast | Halo 15 à tous + Regen 3, Cast | +4 par cible en Moonkin |
| Entangling Roots 9 + Stunned 1, Cast, Cooldown 3 | Chastise 7 + Stunned 1, Cooldown 3 | +2 pour le Cast |
| Skull Bash : Interrupt + Deal 3, Cooldown 2 | Silence : Interrupt + Draw 1, Cooldown 2 | dégâts au lieu de pioche |
| Mangle 6 + une ligne de forme | Schism 3 + Sundered 2 + Atonement 1 | |
| Healing Touch 8 / Regen +4, Exhaust | Greater Heal 12, Cast, Exhaust | sans Cast, 12 seulement sous Regen |
| Barkskin 7 / Regen +4, Cooldown 2 | PW: Shield 8, Cooldown 2 (départ) | 11 sous Regen, 16 en Bear |
| Survival Instincts | Pain Suppression (même Cooldown 4/3) | entre en Bear en plus |
| Rebirth : 15 PV | Spirit of Redemption : 1 PV + Regen 6 + tour gratuit | soin immédiat, pas de tour gratuit |
| Innervate +2/+3 mana, Exhaust | Mana Potion +2 | une fois par combat |

Écarts aux ordres de grandeur du GDD : **Bear Form coûte 1** (0 dans le GDD) parce qu'elle est la
carte de défense du deck de départ, en quatre exemplaires : à 0 mana, ce seraient 24 Absorb gratuits
par passage du deck, contre 20 pour 4 mana chez le Priest. Cat Form et Moonkin Form restent à 0.
Wrath (6 / Moonkin +3 au lieu de 7 / +4) et Starfire (24 au lieu de 20) sont recalés sur Smite et Holy
Fire. Maul (5 / Bear 3 / Cat DoT 3 au lieu de 7 / 5 / 4) : en Bear, la version du GDD donnerait 7
dégâts et 7 Absorb pour 1 mana, soit Smite et Inner Fire réunis. Rejuvenation reçoit Exhaust : les
PV se gardent d'un combat à l'autre et les soins répétables dominaient chez le Priest
(`docs/equilibrage.md`, itération 4).

### Notes d'écriture

- `Turn start:` (Starfall) est une tournure nouvelle : « au début de ton tour ». À ajouter aux
  conditions nommées de l'infobulle (`Turn start: at the start of your turn.`).
- `Shift:` et `Regen:` suivent la forme `Name: effect` existante (`Regen:` = si tu as Regen).
- Clauses de plus de 22 caractères (chacune reste une seule clause, coupée en deux lignes à
  l'affichage, comme `Atonement: +2 Absorb per hit.` chez le Priest) : trois reprises telles quelles
  du Priest, `Interrupt the target's cast.` (28), `Apply Demoralized 1 ⌛ to all` (28),
  `Damage taken halved until next turn.` (36) ; et `Cast cards: apply DoT 3 to all.` (31),
  `Moonkin: Cast cards cost −1.` (28), `Regen: Attacks deal 2 more.` (27),
  `Last Breath: stay at 15 HP.` (27), `Turn start: deal 3 to all.` (26), `Bear: apply Sundered
  2 ⌛.` (25), `Cat: Attacks deal 3 more.` (25), `Remove negative effects.` (24). Aucune carte n'a
  plus de trois clauses hors plaque (Maul, Mangle : trois).

## 3. Les trois voies

### Balance — Moonkin, Cast, DoT sur tous

Moteur : on entre en Moonkin pour que les Cast frappent 4 de plus par coup, on pose du DoT sur tous
les ennemis entre deux gros sorts, puis on assume d'encaisser en Moonkin (ou de perdre le bonus en
passant en Bear). Ce qu'elle cherche : les gros Cast.

Cartes : Moonkin Form, Starfire, Moonfire, Faerie Fire, Hurricane, Nature's Grace, Innervate,
Entangling Roots, Starfall, Eclipse.

- Avec Feral : Feral Instinct paie chaque aller-retour Moonkin ↔ Bear ; Moonkin Form à 0 mana remet
  le bonus juste avant de lancer, Bear Form couvre le tour ennemi (au prix des +4 sur le Cast en
  attente, règle 9).
- Avec Restoration : DoT et Regen font un combat long ; Insect Swarm et Eclipse empilent le DoT, et
  chaque soin qui ramène en Caster suivi de Moonkin Form fait deux Shift (mana d'Idol of the Wild).
- Tour type (en Moonkin depuis le tour précédent, Nature's Grace en jeu, 3 mana) : le Starfire lancé
  au tour précédent se résout d'abord (24 + 4 = 28) ; Faerie Fire (0, pioche 1) ; Moonfire (1, 2 à
  tous et DoT 3 à tous) ; Starfire (2 − 1 = 1, pour le tour suivant) ; Wrath (1, 6 + 3). Le tour
  ennemi se passe en Moonkin, sans défense : c'est le prix des +4.

### Feral — Bear pour tenir, Cat pour frapper

Moteur : on alterne Cat (première Attack gratuite, saignements) et Bear (Absorb ×1,5) selon les
intentions ennemies ; chaque changement de forme rapporte grâce aux effets `Shift:`. Ce qu'elle
cherche : le Shift à chaque tour.

Cartes : Cat Form, Shred, Swipe, Rake, Demoralizing Roar, Skull Bash, Feral Instinct, Mangle, Heart
of the Wild, Survival Instincts.

- Avec Balance : Moonkin Form est un Shift de plus à 0 mana pour Feral Instinct ; Wrath et Maul ont
  déjà leurs lignes de forme.
- Avec Restoration : chaque carte Caster est un Shift gratuit (retour en Caster) ; Barkskin en Bear
  donne 16 Absorb sous Regen ; Swiftmend à 0 mana sert de Shift et de soin.
- Tour type (Caster → Cat → Bear, Feral Instinct en jeu, Idol of the Wild, 3 mana) : Cat Form (0,
  premier Shift : +1 mana, 3 à tous, pioche 1) ; Shred (gratuit en Cat : 11) ; Rake (1 : 4 et DoT 5) ;
  Bear Form (1, Shift : 3 à tous, 6 Absorb) ; Swipe (1 : 4 à tous, 4 Absorb). Bilan : 3 mana dépensés
  sur 4, 10 à tous plus 15 et DoT 5 sur une cible, 10 Absorb pour le tour ennemi.

### Restoration — Regen empilé, puis converti en soin

Moteur : on empile Regen en Caster, puis Swiftmend et Healing Touch le transforment en soin
immédiat ; le DoT d'Insect Swarm et Gift of Nature (Attacks +2 sous Regen) font les dégâts d'un
combat long. Ce qu'elle cherche : le combat long.

Cartes : Regrowth, Insect Swarm, Mark of the Wild, Remove Curse, Swiftmend, Healing Touch, Barkskin,
Gift of Nature, Tranquility, Rebirth.

« Consommé pour un soin immédiat » (GDD) est lu comme « converti » : Swiftmend soigne deux fois la
Regen **sans la retirer**, comme sa carte phare du GDD l'écrit. La retirer rendrait la carte
perdante dès Regen 4 (soin de 8 contre 10 PV de tics restants).

- Avec Balance : DoT de Moonfire, Insect Swarm et Eclipse sur des combats longs ; on soigne en Caster
  puis on remonte en Moonkin (0 mana).
- Avec Feral : les soins deviennent des Shift ; Barkskin et Heart of the Wild en Bear.
- Tour type (Caster) : Rejuvenation (1, Regen 4) ; Swiftmend (0, soigne 8) ; Insect Swarm (1) ;
  Wrath (1, +2 avec Gift of Nature). Puis Bear Form au tour suivant si l'intention ennemie est forte.

## 4. Bibelots de classe (6)

| Id | Nom | Rareté | Effet | Icône | Niveau |
| --- | --- | --- | --- | --- | --- |
| `idol_of_the_wild` | Idol of the Wild | départ | `The first Shift each turn: +1 mana.` | `inv_misc_idol_02` | 1 (porté au départ) |
| `idol_of_brutality` | Idol of Brutality | common | `Bear: gain 3 Absorb at the start of your turn.` | `inv_misc_idol_03` | 1 |
| `idol_of_the_moon` | Idol of the Moon | uncommon | `Each combat starts in Moonkin.` | `inv_misc_idol_05` | 3 |
| `idol_of_health` | Idol of Health | uncommon | `Caster cards also give 3 Absorb.` | `inv_relics_idolofhealth` | 5 |
| `idol_of_ferocity` | Idol of Ferocity | uncommon | `Cat: your first Attack each turn deals 4 more.` | `inv_relics_idolofferocity` | 7 |
| `wolfshead_helm` | Wolfshead Helm | rare | `Shift: gain 3 Absorb.` | `inv_helmet_04` | 7 |

Idol of the Wild est le bibelot de départ voulu par le GDD : il amorce la mécanique dès le premier
tour (un Shift par tour rend un mana ; entrer en Bear avec Bear Form revient à 0). Les cinq autres
couvrent Bear, Moonkin, Caster (les soins, qui laissent sans défense), Cat et le Shift. Idol of
Health donne son Absorb après le retour en Caster : il n'est jamais augmenté par Bear.

## 5. Progression (niveaux de classe 1 à 7)

| Niveau | Balance | Feral | Restoration | Bibelots |
| --- | --- | --- | --- | --- |
| 1 | Moonkin Form, Starfire, Moonfire, Faerie Fire, Entangling Roots, Starfall | Cat Form, Shred, Swipe, Rake, Skull Bash, Survival Instincts | Regrowth, Insect Swarm, Mark of the Wild, Swiftmend, Gift of Nature, Rebirth | Idol of the Wild, Idol of Brutality |
| 2 | Nature's Grace | Feral Instinct | Barkskin | |
| 3 | | | | Idol of the Moon |
| 4 | Hurricane | Mangle | Healing Touch | |
| 5 | | | | Idol of Health |
| 6 | Innervate | Demoralizing Roar | Remove Curse | |
| 7 | Eclipse (rare) | Heart of the Wild (rare) | Tranquility (rare) | Idol of Ferocity, Wolfshead Helm |

Niveau 1 : 4 de départ + 18 cartes, dont une rare par voie, l'Interrupt (Skull Bash) et le Last
Breath (Rebirth). Chaque voie y a sa forme ou son moteur : Moonkin Form et deux Cast pour Balance,
Cat Form et Survival Instincts (Shift en Bear) pour Feral, Regen, Swiftmend et Gift of Nature pour
Restoration. Les déblocages ouvrent une façon de jouer plutôt qu'un chiffre : Nature's Grace (Cast
moins chers en Moonkin), Feral Instinct (payer le Shift), Barkskin (Regen qui protège, aussi en Bear),
puis les cartes de zone et de soin, puis les rares d'ensemble.

## 6. Besoins moteur et interface

### Moteur (`Core/`, `Data/Druid.lua`)

- `c.player.form` (`"caster"` au départ de chaque combat, donnée simple : sauvegardable, clonable).
- Effet `{ "shift", "bear" }` : change la forme si elle diffère, journalise
  `{ t = "shift", from, to }`, puis `Combat.fire(c, "onShift", from, to)` (Powers et bibelots).
- Option d'effet `form = "bear"` : l'effet ne s'applique que dans cette forme (lignes `Bear:` etc.),
  évaluée au moment de l'effet. Même mécanisme pour `Regen:` (`self status = "regen"`), utile à
  d'autres classes.
- Carte `Caster` dérivée des effets (`Card.heals(def)` : `heal`, ou `apply regen self`) : dans
  `Combat.resolveCard`, si la classe est druid et la forme n'est pas `caster`, Shift vers `caster`
  avant les effets. Le champ peut être forcé (`caster = true`) pour l'affichage.
- Bear : multiplicateur appliqué dans `Combat.gainBlock` **après** `Combat.modify(c, "block", …)`
  (les crochets actuels ne garantissent pas l'ordre).
- Cat : drapeau de tour `c.player.flags.catFree` remis au début du tour ; `Combat.cost` renvoie 0
  pour la première Attack sans `cast` de coût > 0 en Cat ; `Combat.play` consomme le drapeau quand la
  gratuité a servi (au paiement, pas à la résolution).
- Moonkin : crochet `damage` (+4 si `cardDef.cast`), lu à la résolution.
- Starfall : Power avec le crochet `onTurnStart` existant (appelé après les tics, la résolution du
  Cast, la pioche et le mana) ; la ligne `Moonkin:` y est lue dans la forme du moment.
- `halved` (Survival Instincts) : l'état s'affiche « Pain Suppression » ; lui donner un nom neutre
  (`Damage Halved`) ou un nom par source.
- Idol of the Wild : compteur de tour `c.relicState`, remis à zéro dans `onTurnStart`.
- Idol of the Moon : forme posée dans `onCombatStart`, sans `onShift`.
- Bot de simulation : évaluer les lignes de forme dans la forme courante et la valeur d'un Shift
  (sinon la classe sera mesurée comme injouable, voir Forme d'ombre dans `docs/equilibrage.md`).

### Interface

- **Pastille de classe** : icône et nom de la forme active à la place du nombre (Caster
  `spell_nature_wispsplode`, Bear `ability_racial_bearform`, Cat
  `ability_druid_catform`, Moonkin `spell_nature_forceofnature`), infobulle de la forme (table de la
  section 1), courte animation au Shift.
- **Ligne de la forme active** : sur les cartes en main, la ligne `Bear:` / `Cat:` / `Moonkin:` de la
  forme active est mise en évidence (nom de forme en or comme aujourd'hui, texte de la ligne en blanc
  plein) ; les autres lignes de forme sont atténuées (gris, alpha ≈ 0,55). Hors combat (récompense,
  deck, marchand), aucune ligne n'est atténuée. Une carte Cast en attente garde la mise en évidence
  de la forme courante, puisqu'elle lira la forme à sa résolution.
- **Coût en Cat** : le coût affiché est déjà `Combat.cost` ; la gratuité de Cat s'y voit sans
  travail de plus.
- **Plaque** : `Shift` et `Caster` en tête, comme `Cast` ; plus longue combinaison :
  « Caster · Cooldown 2 » (Swiftmend), « Shift · Cooldown 4 » (Survival Instincts),
  « Cast · Cooldown 3 » (Entangling Roots).
- **Indice de retour en Caster** : une carte `Caster` en main hors Caster peut porter un petit
  marqueur (icône de la forme Caster) pour annoncer le Shift qu'elle provoquera.
- **Infobulles** : `Shift`, `Caster`, les quatre formes, `Turn start:` (section 1).
- Journal d'animations : événement `shift` (changement de pastille, éventuel effet sur le modèle).

## 7. Risques d'équilibrage et mesures

| Risque | Pourquoi | Mesure (`Sim/sim.lua`, heuristic, 2 000 expéditions) |
| --- | --- | --- |
| Idol of the Wild trop fort | +1 mana par tour dès qu'on change de forme : c'est presque le Bandeau de VanCleef sans contrepartie | mana gagné par tour ; victoires avec / sans Idol (`sweep=relics`) ; cible : ≤ +15 points |
| Shift en boucle | Cat Form et Moonkin Form à 0 mana + Feral Instinct + Wolfshead Helm | Shift par tour (moyenne, p95) ; dégâts de Feral Instinct par combat |
| Bear trop sûr | ×1,5 sur tout l'Absorb, Barkskin 16, Heart of the Wild | PV perdus par combat en Bear vs Priest Discipline |
| Soins entre combats | les PV se gardent ; le Priest a dû rendre ses soins Consumés (`docs/equilibrage.md`) | PV soignés par combat ; écart de Swiftmend (non consommant) et Tranquility |
| Swiftmend sans consommation | 0 mana, Cooldown 2, double la Regen | écart `pick=random` ; repli : Cooldown 3 ou retrait de la Regen |
| Balance trop fragile | Moonkin n'a aucune défense et les Cast se font couper | taux d'interruption des Cast ; victoires du deck forcé Balance |
| Hurricane en Moonkin | +4 par cible | dégâts moyens d'Hurricane en Moonkin à 3 ennemis |
| Starfire gratuit | exclu de Cat par la règle 7 ; vérifier qu'aucun bibelot ne le contourne | test de règle |
| Classe illisible pour le bot | lignes de forme et valeur d'un Shift | part des tours dans chaque forme ; cartes jouées / piochées (aucune < 40 %) |
| Voie seule | chaque voie doit gagner avec ses 6 cartes de niveau 1 | victoires par deck forcé (Balance, Feral, Restoration) au niveau 1 et au niveau 7 |

Mesures à faire dans l'ordre : deck de départ seul (référence Priest de départ) ; niveau 1 par voie ;
niveau 7 ; balayage des cartes (`sweep=cards`) et des bibelots (`sweep=relics loot=0`) ; part des
tours par forme ; PV perdus par combat, à comparer au style de survie visé (question ouverte du GDD).
