# Druid — fiche de conception

Fiche de conception, réécrite le 18/11/2026 d'après la conception décidée avec le joueur. Elle remplace la
version du 12/11/2026 (formes à effet permanent, cartes `Shift` dédiées, lignes `Bear:` / `Cat:` / `Moonkin:`
sur les cartes, Idol of the Wild à +1 mana par Shift) : de cette version restent les trois voies, l'Interrupt
(Skull Bash), le Last Breath (Rebirth), une partie des bibelots et des noms de cartes. Rien n'est codé (le
Druid est un ajout futur, `docs/classes/decisions.md`, « Périmètre »).

Règles communes (tour, Cast, Interrupt, Cooldown, Exhaust, Retain, Innate, Surge, Spend N, Last Breath, états
communs) : `docs/gdd-classes.md` et `docs/classes.md`. Langage des cartes : `docs/interface.md`, « Langage des
cartes ». Textes de jeu en anglais. Chiffres : points de départ copiés des cartes des classes empruntées
(`Data/Rogue.lua`, `Data/Hunter.lua`, `Data/Mage.lua`), à régler par simulation.

## Résumé

Le Druid **emprunte** les mécaniques des autres classes. Chacune de ses cartes porte une **forme** (Cat, Bear,
Moonkin, Caster) ; la jouer fait entrer dans cette forme, sans coût. Il a **une seule réserve** de 0 à 5
points, gardée d'un tour à l'autre et au changement de forme, dont le sens dépend de la forme active :

| Forme | La réserve vaut | Effet de la forme |
|---|---|---|
| Caster (départ) | rien (réserve en attente) | aucun |
| Cat | des **Combo** du Rogue | aucun hors Surge : les cartes Cat montent la réserve (« +1 Combo. ») et la vident (« Surge: ») |
| Bear | du **Frenzy** du Hunter | fin de tour : le Druid frappe seul la dernière cible pour 1 + réserve, puis +1 ; −1 à la fin du round |
| Moonkin | des **Charges** du Mage | permanent : +1 dégât par point sur chaque coup des cartes Attack |

Le rythme : monter la réserve avec les cartes d'une forme, la dépenser avec celles d'une autre, et finir le tour
dans la forme dont on veut l'effet (Bear pour frapper en fin de tour, Moonkin pour qu'un Cast se résolve avec
le bonus). Survie : Absorb en Bear, soins et Regen en Caster. Difficulté : difficile.

## 0. Identité

| | |
|---|---|
| Fantasme | Le Druid change de forme à chaque carte et emprunte à chaque forme la façon de se battre d'une autre classe : le chat finit comme un Rogue, l'ours frappe seul comme le familier du Hunter, le sélénien charge ses sorts comme un Mage. |
| Ressource | Réserve unique, 0 à 5, gardée d'un tour à l'autre et au changement de forme. Son nom affiché est celui de la forme active (Combo, Frenzy, Charges). |
| PV de départ | **50** (comme le Hunter et le Rogue après réglage : frappe gratuite en fin de tour comme le Hunter, Absorb en Bear, soins Exhaust en Caster). À régler. `decisions.md` donnait 65 avant les réglages des autres classes. |
| Deck de départ | Wrath ×3 (Moonkin), Thick Hide ×4 (Bear), Maul ×2 (Bear), Ferocious Bite ×1 (Cat). |
| Bibelot de départ | Idol of the Wild : la première carte de chaque combat qui change de forme coûte 0. |
| Interrupt | Skull Bash (Feral, sans forme, niveau 1). |
| Last Breath | Rebirth (Restoration, rare, niveau 1). |
| Mots-clés propres | **Forme** (mot de plaque : `Cat`, `Bear`, `Moonkin`, `Caster`, une seule règle) et **Bear strikes**. Les mots de la réserve (Combo, Frenzy, Charge), `Surge:` et `Spend N:` sont des mots communs ou des noms de ressource, pas des mots-clés propres. |
| Style de survie | Encaisser (Absorb des cartes Bear) et se soigner (cartes Caster : soins directs tous Exhaust, Regen). `survival = "absorb"`. |
| Difficulté | Difficile : chaque carte change la forme, l'ordre des cartes compte. |

Deck de départ (gabarit du GDD : 10 cartes de 4 sortes, une attaque, une défense, deux cartes de mécanique) :
Wrath est l'attaque (et monte la réserve), Thick Hide la défense (et laisse en Bear pour la frappe de fin de
tour), Maul montre la frappe de l'ours et Ferocious Bite dépense en Cat ce que Wrath a monté en Moonkin.
Un tour type de départ : Wrath, Wrath (réserve 2, Moonkin), Thick Hide (Bear, 5 Absorb) ; fin de tour en Bear :
frappe de 1 + 2 = 3, réserve 3 ; fin du round : réserve 2. Au tour suivant, Ferocious Bite à 2 Combo : 12.

## 1. Règles propres (spécification)

### 1.1 Forme d'une carte

1. Champ de carte `form = "cat" | "bear" | "moonkin" | "caster"`, ou absent (carte **sans forme**). Toute carte
   du Druid a une forme, sauf la liste fermée du § 1.7.
2. **Jouer une carte dont la forme diffère de la forme active fait entrer dans sa forme.** Pas de carte Shift,
   pas de choix, pas de bouton, aucun coût. Jouer une carte de la forme active, ou une carte sans forme, ne
   change rien (aucun événement).
3. **Ordre exact** (`Combat.play`, `docs/classes.md`, « Ordre d'un coup joué ») :
   1. cible (crochet `target`) ; une carte à cible devient la dernière cible (`c.player.lastTarget`), celle de
      la frappe de l'ours ;
   2. coût calculé **dans la forme active avant le changement** (crochet `cost`), puis payé : mana, PV, `Spend N`
      (pris dans la réserve commune, donc indifférent à la forme) ;
   3. compteurs du tour ;
   4. **changement de forme** (crochet de classe `onCardCommitted`, qui passe avant ceux des Powers et des
      bibelots) : journal `{ t = "shift", from, to }`, événement propre `onShift(from, to)`, compteur de
      changements du tour (§ 1.6) ;
   5. incantation (Cast) ou résolution : toutes les lignes de la carte se résolvent dans sa forme.
   Raison du coût avant le changement : le coût affiché en main est celui qui sera payé, sans calcul ; aucune
   carte de la liste n'a de coût qui dépende de la forme (Idol of the Wild lit seulement si la carte changera la
   forme, ce qui se sait avant le jeu).
4. **Cartes Cast** : la forme change **au jeu** (étape 4), comme pour toute carte. La résolution, au début du tour
   suivant, ne change pas la forme : elle se fait dans la forme active à ce moment-là (celle où le tour précédent
   s'est terminé). Le bonus de Moonkin ne s'ajoute donc que si l'on a fini le tour en Moonkin. Exemple : Starfire
   (Moonkin, Cast) puis Thick Hide (Bear) : fin de tour en Bear (frappe, Absorb), Starfire se résout en Bear sans
   le bonus des Charges. Finir en Moonkin garde le bonus mais sans frappe ni Absorb : c'est le choix de la voie
   Balance. Sous Instant (Nature's Swiftness), la carte se résout tout de suite, dans sa forme.
5. **Cartes Surge** : la carte entre dans sa forme, puis son `Surge:` dépense **toute** la réserve à sa
   résolution (règle commune) ; le montant se lit avec le mot de la carte (« per Combo », « per Charge », « per
   Frenzy »). Les Charges sont lues puis remises à 0 avant le coup : le bonus de Moonkin ne s'ajoute pas à une
   carte Surge (comme chez le Mage). Après résolution, la carte suit sa plaque (défausse par défaut).
   Une carte dont toutes les clauses sont `Surge:` est injouable à 0 (`minRes = 1`, raison « resource »).
   Contrainte de conception : **aucune carte Surge n'est en Cast** (la réserve pourrait changer entre le jeu et la
   résolution).
6. **Retain, Innate, Cooldown** : une carte gardée en main (Retain, Traveler's Backpack), placée dans la main de
   départ (Innate) ou revenue de recharge (Cooldown) ne change pas la forme ; seule la jouer la change. La forme
   de fin de tour se lit sur la forme active, pas sur les cartes gardées.
7. **Copies** (crochet `replay`, `Combat.copyCard`) : une copie se résout sans changer la forme (elle ne passe pas
   par `Combat.play`). Potions, bibelots, déclencheurs de Powers, épique : ne changent jamais la forme.
8. **Début et fin de combat** : chaque combat commence en **Caster**, réserve à 0 (l'épique Heart of the Wild
   améliorée +3 mise à part, § 5). La forme et la réserve ne se gardent pas d'un combat à l'autre.
   Last Breath (Rebirth) ne change pas la forme ; une interruption de Cast non plus.
9. Cartes neutres (sans classe, `Data/Neutral.lua`) : sans forme.

### 1.2 La réserve

1. Ressource de classe `c.player.res`, `resource = { id = "wild", cap = 5, keep = true }` (id à confirmer), une
   seule valeur pour toutes les formes. **Les points sont gardés au changement de forme** : 3 Charges montées en
   Moonkin deviennent 3 Combo dès qu'une carte Cat est jouée.
2. **Gains** : clauses « +N Combo. » (cartes Cat), « +N Charge. » / « +N Charges. » (cartes Moonkin),
   « +N Frenzy. » (cartes Bear), et +1 après chaque frappe de l'ours (§ 1.4). Un mot de réserve n'apparaît que
   sur une carte de sa forme, ou sur un Power dont le déclencheur nomme cette forme (« Cat Attacks: +1 Combo. ») :
   la clause se résout alors toujours dans la forme qui porte ce mot. Les cartes Caster et les cartes sans forme
   ne gagnent ni ne dépensent rien.
3. **Plafond 5** ; le surplus est perdu (journal `capped`, pastille qui clignote, comme chez le Rogue).
4. **Dépense** : `Surge:` (toute la réserve, cartes Cat, Bear, Moonkin) et `Spend N:` (cartes Bear, au choix du
   joueur : clic droit ou Maj pour ne pas dépenser, `decisions.md`).
5. **Baisse** : −1 à la fin de chaque round **si la forme active est Bear** à ce moment (crochet `onRoundEnd`,
   après le tour ennemi ; c'est la baisse du Frenzy du Hunter, « sauf le premier tour » compris puisqu'elle a lieu
   après le tour ennemi). Dans les autres formes, la réserve ne baisse pas (le Combo et les Charges ne baissent
   pas chez le Rogue et le Mage). Conséquence voulue : la frappe automatique de l'ours (+1) et la baisse (−1)
   s'annulent ; seules les cartes font monter la réserve.
6. **Lecture par forme** :

| Forme | Mot | Effet de la réserve |
|---|---|---|
| Caster | aucun | aucun : la réserve attend la forme suivante |
| Cat | Combo | aucun effet passif ; les `Surge:` des cartes Cat la dépensent |
| Bear | Frenzy | dégâts de la frappe de l'ours : 1 + réserve ; `Spend N:` des cartes Bear |
| Moonkin | Charge(s) | +1 aux dégâts de **chaque coup** des cartes Attack tant que Moonkin est active, compté au coup, comme Strength, avant Demoralized et Sundered ; ni DoT, ni Skills, ni frappe de l'ours, ni bibelots |

### 1.3 Effet de fin de tour

La forme active au moment de la fin du tour (crochet de classe `onTurnEnd`, avant les Powers, les bibelots et la
défausse, comme le familier du Hunter) décide de l'effet :

| Forme de fin de tour | Effet |
|---|---|
| Caster | aucun |
| Cat | aucun |
| Bear | **frappe de l'ours** : un coup de 1 + réserve sur la dernière cible, puis +1 (§ 1.4) ; puis, à la fin du round, −1 (§ 1.2) |
| Moonkin | aucun en fin de tour ; un Cast en attente se résoudra au début du tour suivant avec le bonus des Charges (§ 1.1, point 4) |

La partie « tenir » de l'ours n'est pas un effet de forme : ce sont ses cartes (Thick Hide, Frenzied
Regeneration, Demoralizing Roar), qui donnent de l'Absorb ou réduisent les coups, et `Spend N:` qui échange des
points de Frenzy (frappe plus faible) contre de l'Absorb. Finir en Bear demande donc de garder une carte Bear
pour la fin du tour (les cartes sans forme jouées ensuite ne changent rien).

### 1.4 La frappe de l'ours (« Bear strikes. »)

1. Un coup **sans carte** (comme le familier du Hunter, `Core/Classes/hunter.lua`) de **1 + réserve** sur la
   dernière cible du Druid ; morte ou absente : l'ennemi vivant le plus à gauche. Strength et Demoralized du Druid
   s'appliquent, Sundered et Absorb de la cible aussi ; les bonus des cartes Attack (Moonkin, Gift of Nature,
   bibelots « Attacks ») ne s'appliquent pas.
2. Puis **+1 Frenzy** (plafond 5).
3. Automatique à la fin de chaque tour fini en Bear ; commandée par la clause « Bear strikes. » / « Bear strikes
   twice. » d'une carte Bear, tout de suite, dans l'ordre des lignes, chaque frappe recalculée.
4. Frappes d'un Surge (Mangle : « Surge: Bear strikes once per Frenzy. ») : chacune à 1 + le montant compté,
   sans gain (comme Bestial Wrath).
5. La frappe n'interrompt, n'étourdit et ne pose rien ; si elle tue le dernier ennemi, le combat est gagné avant
   le tour ennemi.

### 1.5 Rage du Warrior en Bear : non

Étudié : la Rage (+1 par perte de PV, `Core/Classes/warrior.lua`, `onHpLost`) à la place du Frenzy, ou en plus.
Tranché : **non**, la réserve de l'ours est le Frenzy seul ; du Warrior, l'ours garde la forme `Spend N:` (déjà
commune : Growl du Hunter l'emploie).

- **L'Absorb tuerait la Rage** : les cartes Bear donnent de l'Absorb, et la Rage ne vient que des PV perdus. Un
  ours bien joué (tout absorbé) ne gagnerait rien ; la forme qui tient serait celle qui ne monte pas sa réserve.
  Le Warrior vit avec cette tension parce qu'elle fait son identité ; pour l'ours, elle contredit son rôle.
- **Gain passif et réserve partagée** : la réserve passe d'une forme à l'autre. Avec la Rage, finir en Bear et
  prendre trois coups donnerait 3 points gratuits, vidés au tour suivant par Ferocious Bite (16 dégâts) ou
  ajoutés à chaque coup de Moonkin, sans aucune carte de construction. Le Frenzy ne monte que par les frappes
  et les cartes, et la baisse en Bear compense la frappe automatique.
- **Lisibilité** : un quatrième mode de gain (coup reçu) s'ajouterait aux trois mots empruntés.
- La Rage reste possible comme règle d'épique, bornée à une forme : Owlkin Frenzy (§ 5) donne de la réserve
  quand le Druid perd des PV en Moonkin.

### 1.6 Changements de forme et réglage de secours

1. Un **changement de forme** = une carte jouée dont la forme diffère de la forme active (§ 1.1). Compteur par
   tour dans `c.cls` (remis à 0 au début du tour) ; le premier changement d'un tour est souvent la sortie de la
   forme de fin du tour précédent.
2. **Aucune limite ni coût dans la règle de base.** Un tour type en compte deux (sortir de Bear pour Cat ou
   Moonkin, revenir en Bear pour finir) ; un tour qui passe par trois formes en compte trois.
3. **Levier A (prévu, non actif) — mana du tour suivant.** À partir du **troisième** changement d'un tour, chaque
   changement retire 1 mana au tour suivant (crochet `maxMana` de la classe), −2 au plus (il reste 1 mana).
   Pourquoi deux changements gratuits et non un : avec « au-delà du premier », le tour normal « Moonkin puis
   retour en Bear » (deux changements) coûterait déjà 1 mana sur 3 au tour suivant, et la classe paierait sa
   mécanique de base. Avec deux gratuits, le tour Moonkin → Cat → Bear (monter, dépenser, finir) coûte 1 mana au
   tour suivant ; Moonkin → Cat → Moonkin → Bear en coûte 2. La pastille montre le malus à venir (« −1 mana next
   turn »).
4. **Levier B (prévu, non actif) — réserve.** À partir du troisième changement d'un tour, chaque changement fait
   perdre 1 point de réserve, au changement, avant la résolution de la carte. Plus doux que A (il ne touche pas au
   mana) et plus ciblé : il ne vise que le transfert de réserve entre formes.
5. Quand les activer : si la mesure montre plus de 3 changements par tour en moyenne au bot heuristic, ou si les
   decks à trois formes gagnent plus de 10 points de plus que les decks à deux formes. A d'abord ; B si A rend la
   classe lente.

### 1.7 Cartes sans forme

Liste fermée : **Skull Bash** (l'Interrupt doit pouvoir partir dès qu'une incantation ennemie paraît, sans
casser la forme de fin de tour), **Nature's Swiftness** (prépare un Cast de n'importe quelle forme), et **tous les
Powers** (Thorns, Gift of Nature, Rebirth, Nature's Grace, Moonkin Aura, Leader of the Pack) : un Power se joue une
fois et reste ; lui faire changer la forme ferait d'une carte permanente un détour de forme. Un Power peut nommer
une forme dans son déclencheur (« Cat Attacks: », « End of turn in Moonkin: »). Les soins ne sont pas sans forme :
ils sont Caster, et les jouer fait quitter Bear (comme dans WoW).

### 1.8 Marque de forme sur la carte et pastille de classe

- **Sur la carte** : la forme est le **premier mot de la plaque du bas**, en tête comme `Cast` (« Bear »,
  « Moonkin · Cast », « Cat », « Caster · Exhaust »), retiré du corps du texte : elle ne prend aucune ligne. Une
  petite icône de la forme (pastille ronde de la taille du coût) est posée dans le coin haut opposé au coût, et le
  liseré de la plaque prend la couleur de la forme (brun pour Bear, jaune pour Cat, bleu nuit pour Moonkin, vert
  pour Caster). Carte sans forme : ni icône ni mot.
- **En main, en combat** : l'icône de forme d'une carte qui changerait la forme est allumée (contour doré) ;
  celle d'une carte de la forme active reste éteinte. Hors combat (récompenses, deck, marchand) : toutes éteintes.
- **Infobulles des mots de plaque** (60 caractères au plus) : `Cat` « Playing it enters Cat form. Reserve = Combo. » ;
  `Bear` « Playing it enters Bear form. Reserve = Frenzy. » ; `Moonkin` « Playing it enters Moonkin form.
  Reserve = Charges. » ; `Caster` « Playing it enters Caster form. Reserve unused. ».
- **Pastille de classe** : l'anneau près du mana montre l'icône de la forme active à la place de celle de la
  ressource, et le nombre de la réserve (cinq crans, cachés à 0 comme ailleurs) ; la couleur de l'anneau suit la
  forme. Infobulle : nom de la forme, ce que vaut la réserve (« 3 Frenzy: end-of-turn strike for 4. », « 3
  Charges: Attack hits +3. », « 3 Combo: spent by Surge. », « Caster: reserve kept, unused. »), « n / 5 », puis le
  malus de mana à venir si le levier A est actif. Au changement de forme : l'icône tourne et change (événement
  `shift`).
- **Cible de la frappe** : en Bear, la marque d'ennemi (`enemyMarks`, comme la cible du familier du Hunter) montre
  la dernière cible et les dégâts de la prochaine frappe.

### 1.9 Mots-clés et infobulles

| Mot | Infobulle (≤ 60 caractères) |
|---|---|
| Forme (plaque `Cat` / `Bear` / `Moonkin` / `Caster`) | ci-dessus, § 1.8 |
| Bear strikes | `Hits the last target for 1 + Frenzy, then +1 Frenzy.` |
| *(ressource)* Combo, en Cat | `Kept between forms and turns. Surge spends it all. Max 5.` |
| *(ressource)* Frenzy, en Bear | `End-of-turn strike 1 + Frenzy. −1 each round in Bear.` |
| *(ressource)* Charges, en Moonkin | `+1 damage to Attack hits per charge. Max 5.` |

Conditions et déclencheurs employés : `Surge:`, `Spend N:`, `Regen:` (état sur soi), `Last Breath:`, `When hit:`,
`Cast cards:` (existants) ; nouveaux : `Cat Attacks:`, `End of turn in Moonkin:` (Powers), et pour les épiques
`Form changes:`, `Bear strikes:`, `Forms:`, `Each Regen heal:` (existant, Priest), `Surge cards:` (existant,
Rogue).

## 2. Choix : cartes empruntées ou cartes propres

Deux façons d'emprunter :

- **(a) Vraies cartes des autres classes dans le pool du Druid, avec une marque de forme** (Sinister Strike en
  Cat, Arcane Blast en Moonkin, Arcane Shot en Bear).
- **(b) Cartes propres au Druid** (Rake, Shred, Ferocious Bite, Maul, Swipe, Wrath, Starfire…), qui reprennent les
  mêmes effets et les mêmes mots (« +1 Combo. », « Surge: », « Spend 2: », frappe comme « Pet attacks. »).

**Recommandation : (b).** Conséquences concrètes :

| | (a) cartes partagées | (b) cartes propres (retenue) |
|---|---|---|
| Équilibrage | couplé : Eviscerate est passée de 5 + 5 à 4 + 4 par Combo pendant les réglages du Rogue ; avec (a), chaque réglage du Rogue change le Druid, et inversement un Druid trop fort forcerait à affaiblir le Rogue | indépendant : les chiffres partent de la carte d'origine, puis le Druid se règle seul (`sweep=cards class=druid`) |
| Lignes mortes | beaucoup de cartes citent une mécanique que le Druid n'a pas : Backstab et Ambush (`Stealth:`), Feint et Riposte (Parry), Arcane Shot et Kill Command (« Pet attacks. » : pas de familier), Frostbolt et Ice Lance (Frozen), Fireball (Hot Streak, école Fire) ; il faudrait les exclure ou donner ces mécaniques au Druid | aucune : chaque carte est écrite pour les règles du Druid |
| Code | une carte n'a qu'un `class` ; il faudrait une liste de cartes étrangères par classe, une table de formes à part (les fiches sont immuables), des règles de pool, de niveau (le niveau est celui de la classe d'origine), de progression et d'amélioration qui lisent deux classes ; le harnais refuse aujourd'hui toute ressource d'une autre classe | un fichier `Data/Druid.lua` ordinaire ; seuls le mot de ressource par forme, la plaque de forme et la frappe de l'ours sont nouveaux (§ 8) |
| Lisibilité | le joueur qui connaît le Rogue reconnaît Sinister Strike, mais un chat qui joue « Sinister Strike » ou un ours qui lance « Arcane Shot » se lit mal ; une même carte dans deux collections, avec des paliers +2 / +3 écrits pour l'autre classe (Retain des ouvertures sous Stealth) | noms de sorts de druide, effets et mots identiques à ceux des autres classes : on reconnaît la mécanique sans confondre les cartes |
| Coût | aucun texte à écrire | 34 cartes à écrire et à régler |

Plusieurs cartes du Druid reprennent donc exactement une carte d'une autre classe (Ferocious Bite = Eviscerate,
Rake = Garrote, Frenzied Regeneration = Growl, Mangle = Bestial Wrath, Healing Touch = Greater Heal) : c'est
l'emprunt voulu, mais deux fiches indépendantes.

### Plafond de 5

Les trois mécaniques empruntées ont un plafond de 5 (Combo, Frenzy) ou de 4 (Charges du Mage). Avec **5**, les
cartes Cat et Bear reprennent telles quelles les chiffres du Rogue et du Hunter (Eviscerate à 5 Combo, frappe de
1 + 5 = 6, Bestial Wrath à cinq frappes) ; seules les cartes Moonkin changent par rapport au Mage, et elles sont
écrites pour le Druid de toute façon. Avec 4, les finisseurs Cat (Ferocious Bite : 20 au lieu de 24) et la frappe
de l'ours perdraient un cran, soit deux mécaniques sur trois à recalculer au lieu d'une. Contrepartie mesurée
dans les chiffres : Moonkin à 5 Charges donne +5 par coup ; les cartes Moonkin à plusieurs coups sont donc
évitées (aucune « twice » ni « three times » en Moonkin) et les cartes « to all » en Moonkin ont une base basse
(Hurricane 12 à tous).

## 3. Les 34 cartes

Colonnes : **Niv.** = niveau de classe qui débloque la carte (§ 7) ; **Forme** = mot de plaque (— = sans forme) ;
**Plaque** = autres mots de la plaque (dans `text`, en fin de texte, « Power. » / « Cast. » en tête) ; dans les
textes, « / » sépare les clauses (`\n`) ; **Amélioré** = palier +1 ; paliers +2 et +3 : § 3.5. Toutes les cartes
tiennent en quatre lignes au plus (retour glouton à 22 caractères, plaque non comptée) : trois lignes au plus en
base et au +1 (Skull Bash, Demoralizing Roar, Moonfire, Rake), quatre au +3 de Demoralizing Roar.

### 3.1 Départ (4, rareté basic)

| id | Nom | Forme | Coût | Type | Plaque | Texte | Amélioré | Icône | Calé sur |
|---|---|---|---|---|---|---|---|---|---|
| `wrath` | Wrath | Moonkin | 1 | Attack | | Deal 5. / +1 Charge. | Deal 8. / +1 Charge. | Spell_Nature_WrathV2 | Arcane Blast 6 / 9 (Mage) : −1 car le Druid en a trois |
| `thick_hide` | Thick Hide | Bear | 1 | Skill | | Gain 5 Absorb. | Gain 8 Absorb. | Ability_Druid_Ironfur | Mana Shield 5 / 8, Defend 5 |
| `maul` | Maul | Bear | 1 | Attack | | Deal 4. / Bear strikes. | Deal 7. / Bear strikes. | Ability_Druid_Maul | Arcane Shot 3 / 6 + Pet attacks |
| `ferocious_bite` | Ferocious Bite | Cat | 1 | Attack | | Surge: deal 4 + 4 per Combo. | Surge: deal 6 + 5 per Combo. | Ability_Druid_FerociousBite | Eviscerate (Rogue, `minRes = 1`) |

### 3.2 Feral (10 : Cat, Bear, Interrupt ; 4 communes, 4 inhabituelles, 2 rares)

| id | Nom | Rareté | Niv. | Forme | Coût | Type | Plaque | Texte | Amélioré | Icône | Calé sur |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `shred` | Shred | common | 1 | Cat | 1 | Attack | | Deal 7. / +1 Combo. | Deal 10. / +1 Combo. | Spell_Shadow_VampiricAura | Hemorrhage 7 + 1 Combo, sans Sundered |
| `rake` | Rake | common | 1 | Cat | 1 | Attack | | Deal 3. / +1 Combo. / Apply DoT 3 | Deal 4. / +1 Combo. / Apply DoT 5 | Ability_Druid_Rake | Garrote |
| `swipe` | Swipe | common | 1 | Bear | 1 | Attack | | Deal 4 to all. / Bear strikes. | Deal 6 to all. / Bear strikes. | Ability_Druid_Swipe | Multi-Shot 5 à tous + Pet attacks (inhabituelle) |
| `skull_bash` | Skull Bash | common | 1 | — | 0 | Skill | Cooldown 2 | Interrupt the target's cast. / Draw 1. | (Cooldown 1) | INV_Bone_Skull_04 | Silence (Priest) |
| `rip` | Rip | uncommon | 1 | Cat | 1 | Skill | | Surge: apply DoT 3 per Combo. | Surge: apply DoT 4 per Combo. | Ability_GhoulFrenzy | Rupture (`minRes = 1`) |
| `frenzied_regeneration` | Frenzied Regeneration | uncommon | 1 | Bear | 1 | Skill | | Gain 6 Absorb. / Spend 2: gain 6 more. | Gain 8 Absorb. / Spend 2: gain 8 more. | Ability_BullRush | Growl (Hunter) |
| `tigers_fury` | Tiger's Fury | uncommon | 2 | Cat | 0 | Skill | Cooldown 2 | +1 Combo. / Draw 1. | (Cooldown 1) | Ability_Mount_JungleTiger | Premeditation, Kick |
| `mangle` | Mangle | rare | 4 | Bear | 2 | Skill | | Surge: Bear strikes once per Frenzy. | (coût 1) | Ability_Druid_Mangle2 | Bestial Wrath (`minRes = 1`) |
| `demoralizing_roar` | Demoralizing Roar | uncommon | 6 | Bear | 0 | Skill | Cooldown 4 | +1 Frenzy. / Apply Demoralized 2 ⌛ to all | (Cooldown 3) | ABILITY_DRUID_DEMORALIZINGROAR | Demoralizing Shout (Warrior) |
| `leader_of_the_pack` | Leader of the Pack | rare | 7 | — | 1 | Power | | Power. / Cat Attacks: +1 Combo. | (coût 0) | Spell_Nature_UnyeildingStamina | Venomous Wounds (rare, moteur de Combo) |

### 3.3 Balance (10 : Moonkin ; 5 communes, 3 inhabituelles, 2 rares)

| id | Nom | Rareté | Niv. | Forme | Coût | Type | Plaque | Texte | Amélioré | Icône | Calé sur |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `starfire` | Starfire | common | 1 | Moonkin | 2 | Attack | Cast | Cast. / Deal 20. | Cast. / Deal 26. | Spell_Arcane_StarFire | Holy Fire 24 + DoT 3 ; +Charges si fin en Moonkin |
| `moonfire` | Moonfire | common | 1 | Moonkin | 1 | Attack | | Deal 3. / +1 Charge. / Apply DoT 3 | Deal 5. / +1 Charge. / Apply DoT 4 | Spell_Nature_StarFall | Garrote, Fireball |
| `starsurge` | Starsurge | common | 1 | Moonkin | 1 | Attack | | Surge: deal 6 per Charge. | Surge: deal 7 per Charge. | Spell_Arcane_Arcane03 | Nightblade 6 par Combo (`minRes = 1`) |
| `faerie_fire` | Faerie Fire | common | 1 | Moonkin | 0 | Skill | Cooldown 3 | +1 Charge. / Apply Sundered 2 ⌛ | (Cooldown 2) | Spell_Nature_FaerieFire | Hunter's Mark 3, Exhaust |
| `insect_swarm` | Insect Swarm | common | 1 | Moonkin | 1 | Skill | | Apply DoT 4 / Apply Demoralized 1 ⌛ | Apply DoT 6 / Apply Demoralized 1 ⌛ | Spell_Nature_InsectSwarm | Crippling Poison 2 + Demoralized 1 |
| `hurricane` | Hurricane | uncommon | 1 | Moonkin | 2 | Attack | Cast | Cast. / Deal 12 to all. | Cast. / Deal 15 to all. | Spell_Nature_Cyclone | Blizzard 12 à tous + Demoralized 2 |
| `entangling_roots` | Entangling Roots | uncommon | 2 | Moonkin | 1 | Skill | Cooldown 4 | +1 Charge. / Apply Stunned 1 ⌛ | (Cooldown 3) | Spell_Nature_StrangleVines | Chastise, Wyvern Sting |
| `starfall` | Starfall | rare | 4 | Moonkin | 1 | Attack | | Surge: deal 6 per Charge to all. | Surge: deal 7 per Charge to all. | Ability_Druid_Starfall | Arcane Barrage (commune, plafond 4) : 30 à tous à 5 |
| `natures_grace` | Nature's Grace | uncommon | 6 | — | 2 | Power | | Power. / Cast cards: cost −1. | (coût 1) | Spell_Nature_NaturesBlessing | Apotheosis (rare, + 1 mana) |
| `moonkin_aura` | Moonkin Aura | rare | 7 | — | 1 | Power | | Power. / End of turn in Moonkin: +1 Charge. | (coût 0) | Spell_Nature_ForceOfNature | Shadow Dance (moteur rare) ; raison de finir en Moonkin |

### 3.4 Restoration (10 : Caster et Powers ; 4 communes, 4 inhabituelles, 2 rares)

| id | Nom | Rareté | Niv. | Forme | Coût | Type | Plaque | Texte | Amélioré | Icône | Calé sur |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `rejuvenation` | Rejuvenation | common | 1 | Caster | 1 | Skill | Exhaust | Gain Regen 4 | Gain Regen 6 | Spell_Nature_Rejuvenation | Renew 3, Exhaust |
| `regrowth` | Regrowth | common | 1 | Caster | 1 | Skill | Exhaust | Heal 4. / Gain Regen 3 | Heal 6. / Gain Regen 4 | Spell_Nature_ResistNature | Flash Heal 7 + Draw 1, Exhaust |
| `mark_of_the_wild` | Mark of the Wild | common | 1 | Caster | 1 | Skill | | Gain 4 Absorb. / Gain Regen 2 | Gain 6 Absorb. / Gain Regen 3 | Spell_Nature_Regeneration | Radiance 4 + Atonement 1 |
| `thorns` | Thorns | common | 1 | — | 1 | Power | | Power. / When hit: deal 3 to the attacker. | (coût 0) | Spell_Nature_Thorns | Retaliation 4 (inhabituelle, niveau 6) |
| `swiftmend` | Swiftmend | uncommon | 1 | Caster | 0 | Skill | Exhaust | Heal 2 per Regen. | Heal 2 per Regen. / Draw 1. | INV_Relics_IdolofRejuvenation | soin immédiat sans retirer la Regen |
| `rebirth` | Rebirth | rare | 1 | — | 1 | Power | | Power. / Last Breath: stay at 1 HP, heal 12. | (coût 0) | Spell_Nature_Reincarnation | Last Stand 15, Ice Block 10 |
| `natures_swiftness` | Nature's Swiftness | uncommon | 2 | — | 0 | Skill | Exhaust | Draw 1. / Gain Instant 1 | Draw 2. / Gain Instant 1 | Spell_Nature_RavenForm | Combustion (Draw 2, Instant 2, rare) |
| `healing_touch` | Healing Touch | uncommon | 4 | Caster | 1 | Skill | Cast, Exhaust | Cast. / Heal 12. | Cast. / Heal 16. | SPELL_NATURE_HEALINGTOUCH | Greater Heal 10, Cast, Exhaust |
| `gift_of_nature` | Gift of Nature | uncommon | 6 | — | 1 | Power | | Power. / Regen: Attack hits deal 2 more. | (coût 0) | Spell_Nature_ProtectionformNature | Shatter (« Frozen: Attack hits deal 4 more. ») |
| `tranquility` | Tranquility | rare | 7 | Caster | 2 | Skill | Exhaust | Heal 6. / Gain Regen 5 | Heal 9. / Gain Regen 6 | Spell_Nature_Tranquility | rare de soin, une fois par combat |

Comptes : 4 de départ ; 13 communes (Feral 4, Balance 5, Restoration 4) ; 11 inhabituelles (4, 3, 4) ; 6 rares
(2 par voie) = 34. Par forme : Cat 5 (Ferocious Bite, Shred, Rake, Rip, Tiger's Fury), Bear 6 (Thick Hide, Maul,
Swipe, Frenzied Regeneration, Mangle, Demoralizing Roar), Moonkin 9 (Wrath et la voie Balance hors Powers),
Caster 6, sans forme 8 (Skull Bash, Nature's Swiftness, six Powers).

Notes :

- Icônes : noms exacts des fichiers de `~/Téléchargements/ICONS/` (vérifiés le 18/11/2026). Shred
  (`Spell_Shadow_VampiricAura`), Starsurge (`Spell_Arcane_Arcane03`), Frenzied Regeneration (`Ability_BullRush`),
  Leader of the Pack (`Spell_Nature_UnyeildingStamina`) : icônes de substitution, à vérifier au moment du code.
- Swiftmend : « Heal 2 per Regen. » soigne deux fois la Regen du Druid **sans la retirer** ; Exhaust (les PV se
  gardent d'un combat à l'autre, les soins répétables dominaient chez le Priest, `docs/equilibrage.md`).
- Healing Touch (Cast) entre en Caster au jeu ; le soin se résout au tour suivant dans n'importe quelle forme
  (un soin ne dépend pas de la forme). Nature's Swiftness le rend immédiat.
- Gift of Nature : « Regen: » = le Druid a Regen au moment du coup ; vaut pour les cartes Attack de toutes les
  formes, pas pour la frappe de l'ours (coup sans carte).
- Maul et Rake sont aussi des noms d'actions ennemies (`Data/Zones/Duskwood.lua`, `Wetlands.lua`,
  `Stranglethorn.lua`) : des intentions, pas des cartes ; à garder ou à renommer (question ouverte 8).
- Insect Swarm est la carte de contrôle de Balance, sans gain de réserve en base et au +1 (comme Hurricane) ; il
  reçoit « +1 Charge. » au palier +2.

### 3.5 Paliers d'amélioration +2 et +3

Règles suivies, celles du Rogue et du Hunter (`docs/ameliorations.md`) : Retain pour les cartes qu'on garde pour
le bon moment (finisseurs, Cast) ; un seul palier monte le « par point » d'un Surge ; coût d'un Power baissé une
seule fois ; aucun Stunned allongé (Stun Resistant des élites) ; pas de pioche ajoutée aux cartes à 0 qui n'en ont
pas. Chaque colonne ne dit que ce que le palier ajoute.

| Carte | +1 (tableau ci-dessus) | +2 | +3 |
|---|---|---|---|
| Wrath | Deal 8 | Deal 10 | Deal 12 |
| Thick Hide | 8 Absorb | 10 Absorb | Retain |
| Maul | Deal 7 | Deal 9 | `+1 Frenzy.` avant la frappe |
| Ferocious Bite | 6 + 5 par Combo | 9 + 5 par Combo | Retain |
| Shred | Deal 10 | Deal 12 | Deal 14 |
| Rake | Deal 4, DoT 5 | DoT 7 | Deal 6 |
| Swipe | 6 à tous | 7 à tous | `+1 Frenzy.` avant la frappe |
| Skull Bash | Cooldown 1 | Retain | `Interrupt all casts.` |
| Rip | DoT 4 par Combo | Retain | DoT 5 par Combo |
| Frenzied Regeneration | 8 / 8 | 10 / 8 | Spend 1 |
| Tiger's Fury | Cooldown 1 | Retain | +2 Combo |
| Mangle | coût 1 | `+2 Frenzy.` après les frappes | Retain |
| Demoralizing Roar | Cooldown 3 | +2 Frenzy | `Gain 4 Absorb.` |
| Leader of the Pack | coût 0 | Innate | `Cat Attacks: +1 Combo, deal 2 more.` |
| Starfire | Deal 26 | Deal 30 | Deal 34 |
| Moonfire | Deal 5, DoT 4 | DoT 6 | Deal 7 |
| Starsurge | 7 par Charge | Retain | 8 par Charge |
| Faerie Fire | Cooldown 2 | Sundered 3 | Retain |
| Insect Swarm | DoT 6 | `+1 Charge.` en tête | Demoralized 2 ⌛ |
| Hurricane | 15 à tous | Retain | 18 à tous |
| Entangling Roots | Cooldown 3 | `Apply DoT 4` | Retain |
| Starfall | 7 par Charge à tous | Retain | 8 par Charge à tous |
| Nature's Grace | coût 1 | Innate | au jeu : `Gain Instant 1` |
| Moonkin Aura | coût 0 | Innate | `+2 Charges.` par fin de tour |
| Rejuvenation | Regen 6 | Regen 7 | Retain |
| Regrowth | Heal 6, Regen 4 | Draw 1 | Heal 8 |
| Mark of the Wild | 6 Absorb, Regen 3 | 8 Absorb | Retain |
| Thorns | coût 0 | deal 4 | Innate |
| Swiftmend | Draw 1 | Retain | Heal 3 per Regen |
| Rebirth | coût 0 | heal 16 | Innate |
| Nature's Swiftness | Draw 2 | Retain | Instant 2 |
| Healing Touch | Heal 16 | Retain | sans Cast (se résout tout de suite) |
| Gift of Nature | coût 0 | Innate | deal 3 more |
| Tranquility | Heal 9, Regen 6 | coût 1 | Retain |

## 4. Les trois voies

### Feral — monter en Cat, finir en Bear

Moteur : les cartes Cat montent la réserve en Combo (Shred, Rake, Tiger's Fury) et la vident par un Surge (Ferocious
Bite, Rip) ; les cartes Bear donnent l'Absorb du tour ennemi (Thick Hide, Frenzied Regeneration) et font frapper
l'ours (Maul, Swipe), dont chaque frappe rend un point. Finir en Bear donne la frappe de fin de tour. Ce qu'elle
cherche : alterner chaque tour entre construire (Cat) et tenir (Bear).

Cartes : Shred, Rake, Swipe, Skull Bash, Rip, Frenzied Regeneration, Tiger's Fury, Mangle, Demoralizing Roar,
Leader of the Pack.

- Avec **Balance** : Wrath, Moonfire et Faerie Fire montent la réserve en Charges, Ferocious Bite la vide en
  Combo ; Mangle vide en Frenzy ce que Moonkin a monté.
- Avec **Restoration** : Thorns punit les coups que l'ours encaisse ; Gift of Nature (sous Regen) renforce chaque
  attaque Cat et Bear.
- Tour type (3 mana, réserve 2, fin du tour précédent en Bear, main : Tiger's Fury, Shred, Ferocious Bite,
  Frenzied Regeneration, Rake) : Tiger's Fury (0, Cat : 3 Combo, pioche Maul) ; Shred (1 : 7, 4 Combo) ;
  Ferocious Bite (1 : 4 + 16 = 20, réserve 0) ; Frenzied Regeneration (1, Bear : 6 Absorb, sans Spend). Fin en
  Bear : frappe de 1, réserve 1 ; fin du round : 0. Deux changements de forme (Bear → Cat → Bear).

### Balance — Charges et gros Cast

Moteur : les cartes Moonkin montent les Charges (Wrath, Moonfire, Faerie Fire, Entangling Roots) et chaque coup
des Attack en Moonkin les ajoute à ses dégâts ; Starsurge et Starfall vident la réserve ; Starfire et Hurricane
sont des Cast qui ne profitent des Charges que si l'on finit le tour en Moonkin. Ce qu'elle cherche : le tour fini
en Moonkin avec 5 Charges et un Cast en attente.

Cartes : Starfire, Moonfire, Starsurge, Faerie Fire, Insect Swarm, Hurricane, Entangling Roots, Starfall,
Nature's Grace, Moonkin Aura.

- Avec **Feral** : finir en Bear protège le tour ennemi au prix du bonus sur le Cast ; Ferocious Bite et Mangle
  dépensent autrement ce que Moonkin a monté.
- Avec **Restoration** : Nature's Swiftness fait partir Starfire tout de suite, en Moonkin ; Mark of the Wild et la
  Regen couvrent un tour fini en Moonkin, sans Absorb de l'ours.
- Tour type (3 mana, réserve 3, Moonkin depuis le tour précédent, Starfire en attente) : début du tour, Starfire
  se résout en Moonkin : 20 + 3 = 23. Faerie Fire (0 : 4 Charges, Sundered 2) ; Wrath (1 : 5 + 4 = 9, ×1,25 sous
  Sundered = 11, 5 Charges) ; Starfire (2, Cast) ; on reste en Moonkin : aucune frappe, aucun Absorb ; Starfire
  vaudra 20 + 5 = 25 au tour suivant, 31 si la cible porte encore Sundered.

### Restoration — Regen, soins, et la réserve en attente

Moteur : la Regen empilée (Rejuvenation, Regrowth, Mark of the Wild) se convertit en soin immédiat (Swiftmend) ;
Gift of Nature fait de la Regen un bonus d'attaque pour toutes les formes, Thorns rend des dégâts à chaque coup
reçu. En Caster, la réserve n'a pas d'effet et ne baisse pas : on soigne sans perdre ce qui a été monté. Ce
qu'elle cherche : le combat long.

Cartes : Rejuvenation, Regrowth, Mark of the Wild, Thorns, Swiftmend, Rebirth, Nature's Swiftness, Healing Touch,
Gift of Nature, Tranquility.

- Avec **Feral** : les soins Caster se jouent au milieu du tour, puis une carte Bear ramène en Bear pour la
  frappe et l'Absorb ; Gift of Nature renforce Shred, Rake, Maul et Swipe sous Regen.
- Avec **Balance** : Nature's Swiftness fait partir un Cast tout de suite ; la Regen couvre les tours finis en
  Moonkin.
- Tour type (3 mana, Regen 0, réserve 3, fin du tour précédent en Bear) : Rejuvenation (1, Caster : Regen 4) ;
  Swiftmend (0 : soin 8) ; Wrath (1, Moonkin : 5 + 3 = 8, 4 Charges) ; Thick Hide (1, Bear : 5 Absorb). Fin en
  Bear : frappe de 5, réserve 5 ; fin du round : 4. Trois changements de forme (Bear → Caster → Moonkin → Bear) :
  sous le levier A, −1 mana au tour suivant.

### Pourquoi la réserve ne vaut rien en Caster

- La voie Restoration a déjà sa jauge : la **Regen**, qu'elle empile puis convertit (Swiftmend). Une seconde
  lecture en Caster doublerait la jauge de la voie.
- Toute lecture en Caster qui soignerait (« +1 soin par point », « Regen par point ») transformerait la réserve
  en PV, qui se gardent d'un combat à l'autre : c'est ce qui a obligé à rendre les soins du Priest Exhaust.
- Trois lectures empruntées (Combo, Frenzy, Charges) sont la limite de lisibilité de la pastille.
- Conséquence : Caster est une forme de passage, choisie pour ses cartes ; y finir le tour ne donne rien. L'épique
  Tree of Life (§ 5) lui donne un rôle sur la réserve, pour un build.

## 5. Cartes épiques (une par zone)

Gabarit des épiques (`docs/zones/cartes-de-zone.md`) : règle en jeu dès le début du combat, deux lignes au plus,
« Déclencheur: Mot N. », l'à-côté (mot de règle, `L.rule`) donne la règle complète. Noms : sorts ou talents de
druide absents de `Data/` (vérifié ; « Berserk » et « Ravage » sont pris par Stranglethorn Vale et évités).

| Zone | Épique | Voie | Texte (base) | Mot de règle : à-côté | N (base / +1 / +2 / +3) | Icône | Ce qu'elle fait construire |
|---|---|---|---|---|---|---|---|
| 1 Westfall | Furor | Restoration | `Form changes: Primal 2.` | Primal : `The reserve gains 1 on each form change, at most N times per turn.` | 2 / 3 / 4 / 5 | Spell_Holy_BlessingOfStamina | un deck qui change de forme à chaque carte (simple, lisible en une fois) ; incompatible avec le levier A |
| 2 Duskwood | Mark of Ursol | Feral | `Bear strikes: Ironfur 50%.` | Ironfur : `Gain Absorb equal to N% of each Bear strike's damage, rounded down.` | 50 / 75 / 100 / 125 | Ability_Druid_MarkofUrsol | un ours qui frappe souvent et haut (Maul, Swipe, Mangle, Frenzy à 5) et tient par ses frappes |
| 3 Wetlands | Eclipse | Balance | `Cast cards: Eclipse 5.` | Eclipse : `With at least N in the reserve, Moonkin Cast cards resolve at once.` | 5 / 4 / 4 / 3 (+2 : `and deal 3 more`) | Ability_Druid_Eclipse | monter à 5, puis Starfire et Hurricane tout de suite, avec le bonus, et finir en Bear |
| 4 Stranglethorn Vale | King of the Jungle | Feral | `Surge cards: Predator 1.` | Predator : `The Surge counts the whole reserve, then N stays in it.` | 1 / 2 / 2 / 3 (+2 : `the first Surge each turn draws 1`) | Ability_Druid_KingoftheJungle | plusieurs Surge par combat (Ferocious Bite, Rip, Starsurge, Mangle) |
| 5 Swamp of Sorrows | Tree of Life | Restoration | `Each Regen heal: Bloom 1.` | Bloom : `The reserve gains N each time Regen heals, even at full HP.` | 1 / 1 / 2 / 2 (+1 et +3 : `Each combat starts with Regen 3`, puis 5) | Ability_Druid_TreeofLife | la Regen comme générateur : Rejuvenation et Regrowth nourrissent les Surge des autres formes |
| 6 Burning Steppes | Owlkin Frenzy | Balance | `When hit: Moonfury 1.` | Moonfury : `In Moonkin, a hit that costs HP gives N to the reserve, once per enemy attack.` | 1 / 2 / 2 / 3 (+2 : `End of turn in Moonkin: gain 3 Absorb.`) | Ability_Druid_OwlkinFrenzy | finir en Moonkin et encaisser (la Rage du Warrior, bornée à Moonkin) |
| 7 Blackrock Mountain | Heart of the Wild | Feral | `Forms: Kinship 3.` | Kinship : `Cat, Bear and Moonkin each keep their own reserve, up to N.` | 3 / 4 / 5 / 5 (+3 : `each starts at 1`) | Spell_Holy_BlessingOfAgility | trois réserves séparées : un deck à trois formes qui construit chacune pour elle (un Surge ne vide que la sienne) |

Par voie : Feral 3, Balance 2, Restoration 2. Textes : « Epic. » en tête, deux lignes, aucun « you / your ».
Nouveaux déclencheurs : `Form changes`, `Bear strikes`, `Forms`. Heart of the Wild change le contrat de la
ressource (trois valeurs dans `c.cls` au lieu de `c.player.res`) : c'est l'épique la plus chère à coder, placée à
Blackrock pour cette raison.

## 6. Bibelots de classe (6)

| id | Nom | Rareté | Niv. | Effet | Icône |
|---|---|---|---|---|---|
| `idol_of_the_wild` | Idol of the Wild | départ | 1 | `The first card each combat that changes form costs 0.` | INV_Misc_Idol_02 |
| `idol_of_brutality` | Idol of Brutality | common | 1 | `Bear strikes deal 2 more.` | INV_Misc_Idol_03 |
| `idol_of_ferocity` | Idol of Ferocity | uncommon | 3 | `Each Surge in Cat: draw 1.` | INV_Relics_IdolofFerocity |
| `idol_of_the_moon` | Idol of the Moon | uncommon | 5 | `End of turn in Moonkin: gain 4 Absorb.` | INV_MISC_IDOL_05 |
| `idol_of_rejuvenation` | Idol of Rejuvenation | rare | 7 | `Each Caster card played: gain 3 Absorb.` | INV_Relics_IdolofHealth (l'icône de l'idole du même nom sert déjà à Swiftmend, comme dans WoW) |
| `wolfshead_helm` | Wolfshead Helm | rare | 7 | `The first form change each turn: draw 1.` | INV_Helmet_04 |

Idol of the Wild amorce la mécanique au premier tour, comme Apprentice's Wand pour le Mage : le combat commence en
Caster, donc la première carte de forme jouée (Wrath, Thick Hide, Maul, Ferocious Bite) est gratuite ; son coût
tombe à 0 avant le paiement (crochet `cost`, qui lit si la carte changerait la forme). Les cinq autres couvrent
chacune une forme (Bear, Cat, Moonkin, Caster) et le changement de forme. Idol of the Moon donne une raison de finir
en Moonkin quand un Cast attend ; Wolfshead Helm reprend l'ancienne Idol of the Wild (+1 mana par Shift, trop fort
quand chaque carte change la forme) en pioche, une fois par tour.

## 7. Progression (niveaux de classe 1 à 7)

| Niveau | Feral | Balance | Restoration | Bibelots |
|---|---|---|---|---|
| 1 | Shred, Rake, Swipe, Skull Bash, Rip, Frenzied Regeneration | Starfire, Moonfire, Starsurge, Faerie Fire, Insect Swarm, Hurricane | Rejuvenation, Regrowth, Mark of the Wild, Thorns, Swiftmend, Rebirth (rare) | Idol of the Wild, Idol of Brutality |
| 2 | Tiger's Fury | Entangling Roots | Nature's Swiftness | |
| 3 | | | | Idol of Ferocity |
| 4 | Mangle (rare) | Starfall (rare) | Healing Touch | |
| 5 | | | | Idol of the Moon |
| 6 | Demoralizing Roar | Nature's Grace | Gift of Nature | |
| 7 | Leader of the Pack (rare) | Moonkin Aura (rare) | Tranquility (rare) | Idol of Rejuvenation, Wolfshead Helm |

Plus les 4 cartes de départ au niveau 1 (22 cartes ; 34 au niveau 7). Le niveau 1 suffit pour gagner : chaque
voie y a un générateur, une dépense ou un gros coup, de la défense et du soin (Feral : Shred, Rake, Rip, Swipe,
Frenzied Regeneration ; Balance : Moonfire, Starsurge, Starfire, Hurricane ; Restoration : Regen, Swiftmend,
Thorns, Rebirth), plus l'Interrupt (Skull Bash) et le Last Breath (Rebirth). Les déblocages ouvrent une façon de
jouer : au 2, une carte à 0 ou le contrôle (Tiger's Fury, Entangling Roots, Instant) ; au 4, les grosses dépenses
(Mangle, Starfall) et le soin en Cast ; au 6, Demoralized à tous, Cast moins chers, la Regen offensive ; au 7, les
moteurs (Leader of the Pack, Moonkin Aura) et Tranquility.

## 8. Points d'accroche dans le code

### Ce qui existe déjà (`docs/classes.md`)

| Besoin du Druid | Point d'accroche existant |
|---|---|
| Forme active | état de classe `c.cls.form` (données simples, cloné, sauvegardé), posé à `"caster"` par `init` |
| Changement de forme au jeu | crochet de classe `onCardCommitted` (inst, d, cible) : après tous les coûts, avant incantation ou résolution, et avant les Powers et bibelots (crochets de classe en premier) ; ne passe pas pour une copie (`replay`, `copyCard`) |
| Événement de changement | `Combat.fire(c, "onShift", from, to)` (trois arguments au plus) ; Powers, bibelots et épiques s'y abonnent |
| Réserve | ressource commune `c.player.res`, `resource.cap = 5`, `keep = true` ; `Combat.gainRes`, `Combat.surge`, `Combat.spendRes`, `minRes`, `spend` ; effet `res` (« +1 Combo. ») ; `per = { k, "surge" }` |
| Bonus de Moonkin | crochet de classe `damage` (v, cible, d) : `v + res` si `c.cls.form == "moonkin"` et `d.type == "attack"` (même code que `ns.ClassRules.mage`) ; lu au coup, donc à la résolution d'un Cast |
| Frappe de fin de tour | crochet de classe `onTurnEnd` (avant Powers, bibelots et défausse), comme le familier |
| Baisse en Bear | crochet de classe `onRoundEnd` : −1 si `c.cls.form == "bear"` (même code que le Hunter) |
| Cible de la frappe | `c.player.lastTarget` (posée par `Combat.play`) |
| Levier A | crochet de classe `maxMana` (mana du tour suivant) |
| Idol of the Wild | crochet `cost` (d, inst) : 0 si la carte changerait la forme et que le bibelot n'a pas servi (`c.relicState`) |
| Instant (Nature's Swiftness) | état commun `instant` (`Combat.isInstant`) |
| `Regen:` (Gift of Nature) | condition d'état `status:regen` (bienfait sur soi) |
| Soins, Absorb, DoT, Stunned, Demoralized, Sundered | effets communs `heal`, `absorb`, `apply` |
| Cible de la frappe affichée | `ns.ClassViews.druid` avec `enemyMarks = true` (comme le Hunter) |
| Animation du changement | `ns.ClassViews.druid.event` sur `{ t = "shift" }` |

### Ce qui manque dans le socle

1. **Champ `form` et mots de plaque de forme.** `Core/Language.lua` déclare encore l'ancienne conception : conditions
   `shift`, `caster`, `bear`, `cat`, `moonkin` et plaque `shift`. À remplacer par quatre plaques de tête (`Cat`,
   `Bear`, `Moonkin`, `Caster`) lues sur `d.form` ; `L.plateWord` ne sait aujourd'hui que lire un champ vrai
   (`d[p.flag]`) : il faut une plaque qui compare une valeur (`d.form == "bear"`). Le harnais U27 et `W.cardBody`
   retirent alors le mot du corps comme `Cast`.
2. **Nom de la ressource selon la forme.** `L.resourceName(id, n)` et l'explication « %s » (`Surge`, `Spend`)
   lisent un nom fixe par classe. Il faut un nom par forme (Combo, Frenzy, Charge/Charges) : registre
   `L.resource("wild", { forms = { cat = "combo", bear = "frenzy", moonkin = "arcane" } })` ou crochet de classe. Le
   harnais U27 refuse aujourd'hui toute ressource d'une autre classe (« ressource d'une autre classe ») et exige
   la clause « +N <ressource de la classe>. » pour chaque effet `res` : pour le Druid, le mot permis est celui de
   la forme de la carte, ou de la forme nommée par le déclencheur d'un Power.
3. **Pastille par forme.** La pastille générique (`UI/CombatView.lua`) montre l'icône fixe de la ressource
   (`Art.classes[id].resource`) : il faut que l'icône, la couleur et l'infobulle suivent `c.cls.form`.
4. **Frappe de l'ours.** `ns.Hunter.petAttack` fait déjà le bon coup (sans carte, dernière cible, +1, Surge sans
   gain), mais il lit `Hunter.PET_BASE` (couplage d'équilibrage), les crochets `petAbsent` / `petAll` des épiques du
   Hunter, et journalise `pet_attack` (animé par la vue du Hunter). À faire : soit une fonction commune
   `Combat.companionStrike(c, why, base, n)` dont le Hunter et le Druid se servent, soit une copie
   `Druid.strike` (base `Druid.STRIKE_BASE = 1`, journal `bear_strike`, événement `onBearStrike`) ; effet de carte
   `{ "strike", n, surge = bool }` (« Bear strikes. », « Surge: Bear strikes once per Frenzy. ») et mot du langage
   `Bear strikes` (`L.keyword`, comme `pet`).
5. **Marque de forme en main** (icône allumée si la carte changerait la forme) : lecture de `c.cls.form` par le
   rendu des cartes en main (`UI/Widgets.lua`), nouveau.
6. **Clé des bots** : `botKey` doit contenir `c.cls.form` (deux positions de même main et même réserve mais de
   formes différentes ne se valent pas : la frappe, la baisse, le bonus de Moonkin en dépendent).
7. **Épique Heart of the Wild** : trois réserves dans `c.cls` ; la pastille et `Combat.gainRes` / `surge` /
   `spendRes` doivent lire la réserve de la forme active (crochet sur la ressource, nouveau).

## 9. Conseils pour les bots de simulation

- **Finir en Bear** sauf raison contraire : garder une carte Bear (Thick Hide, Maul, Frenzied Regeneration) pour la
  fin du tour ; jouer les cartes sans forme après elle. Exceptions : un Cast Moonkin en attente qui vaut plus que
  la frappe et l'Absorb (Starfire avec 4 ou 5 Charges), ou un tour qui tue tout.
- **Monter avant de dépenser** : jouer les générateurs de toutes les formes avant le Surge du tour ; ne pas monter
  au-delà de 5 ; un Surge à 1 ou 2 points seulement s'il tue ou si le combat finit.
- **Moonkin** : jouer les Attack Moonkin après les générateurs Moonkin (le bonus compte au coup) ; ne pas jouer
  Starsurge ou Starfall avant les autres Attack Moonkin du tour (ils remettent les Charges à 0).
- **Ordre des soins** : soins Caster au milieu du tour, jamais en dernier (ils feraient finir en Caster).
- **Spend** (Frenzied Regeneration) : dépenser seulement si l'Absorb sert au tour ennemi et que la frappe perdue
  vaut moins (2 points ≈ 2 dégâts par frappe).
- `bot.resValue` ≈ 5 (entre Combo et Frenzy) ; `botValue` : en Bear, valeur de la frappe de fin de tour ; un Cast en
  attente vaut son bonus de Charges seulement si la forme est Moonkin ; levier A actif : −22 par mana perdu
  (`evoMana` du Mage : 22 par mana).
- Mesurer la part des tours finis dans chaque forme : un bot qui finit toujours en Caster a mal lu la classe (voir
  Forme d'ombre, `docs/equilibrage.md`).

## 10. Risques d'équilibrage et mesures

| Risque | Pourquoi | Mesure (`runner=expedition class=druid`, heuristic, clé 0) |
|---|---|---|
| Transfert de réserve trop fort | monter en Moonkin (+1 dégât par coup en passant), vider en Cat : chaque point sert deux fois | dégâts par point de réserve ; victoires des decks à deux et trois formes ; activer le levier A si l'écart dépasse 10 points |
| Finir en Bear sans coût | la frappe (+1) et la baisse (−1) s'annulent : finir en Bear est gratuit dès qu'on a une carte Bear | part des tours finis en Bear ; si > 85 %, baisse en Bear à −2 ou frappe sans gain |
| Moonkin à 5 | +5 par coup sur Wrath, Moonfire, Hurricane (à chaque cible) | dégâts moyens de Hurricane à 3 ennemis ; Wrath à 5 Charges |
| Soins entre combats | Swiftmend (sans retirer la Regen), Tranquility | PV soignés par combat ; repli : Swiftmend retire la Regen |
| Cat sans raison de finir là | aucun effet de fin de tour en Cat | part des tours finis en Cat ; repli (question 3) |
| Idol of the Wild | +1 mana au premier tour de chaque combat | `sweep=relics` ; comparer à Apprentice's Wand |
| PV perdus | cible commune 6 à 9 PV par combat normal (`decisions.md`) | PV perdus et PV nets par combat |

## 11. Questions ouvertes pour le joueur

1. **Nom de la réserve hors forme.** Sur les cartes, le mot est celui de la forme (Combo, Frenzy, Charges). En
   Caster, la pastille ne montre que le nombre. Faut-il un nom propre à la réserve (proposition : « Reserve ») pour
   l'infobulle et les textes de bibelots ?
2. **Leviers de secours** (§ 1.6) : deux changements gratuits par tour, puis −1 mana au tour suivant (A) ou −1 point
   de réserve (B) : d'accord sur le seuil de deux plutôt qu'un ?
3. **Cat en fin de tour** : rien dans cette fiche. Si la simulation montre qu'on ne finit jamais en Cat, piste :
   finir en Cat donne Parry 1 (emprunt au Rogue ; un état de plus à afficher).
4. **Caster** : la réserve n'y vaut rien (§ 4, « Pourquoi »). D'accord, ou faut-il une lecture (par exemple
   Atonement du Priest : les cartes Caster qui infligent des dégâts soignent) ?
5. **Cartes sans forme** : Skull Bash, Nature's Swiftness et tous les Powers. Faut-il des Powers de forme (jouer
   Moonkin Aura ferait entrer en Moonkin) ?
6. **PV de départ** : 50 proposé.
7. **Mots-clés** : la marque de forme (quatre mots de plaque, une règle) et `Bear strikes` comptent pour deux
   mots-clés propres. D'accord pour compter les quatre formes comme un seul mot ?
8. **Noms** : Maul et Rake sont aussi des actions ennemies (Duskwood, Wetlands, Stranglethorn Vale). Garder ?
9. **`docs/classes/decisions.md`**, ligne « Druid » (« Une carte de soin jouée hors de Caster ramène d'abord en
   Caster, et ce retour est un Shift. […] Bear Form coûte 1. ») : elle décrit l'ancienne conception et prime sur
   les fiches ; à remplacer par la règle de cette fiche (« Chaque carte porte sa forme ; la jouer y fait entrer,
   sans coût ; la réserve est gardée au changement »).
