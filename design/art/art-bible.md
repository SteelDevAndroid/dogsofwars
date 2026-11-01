# Art Bible: La Meute Orpheline

> **Status**: Draft
> **Owned By**: art-director
> **Last Updated**: 2026-10-30
> **Art Director Sign-Off (AD-ART-BIBLE)**: REVISED 2026-10-30 — CONCERNS du 2026-10-30 corrigées (11 points ; point 7, traits des Gardiens, en attente du GDD unités ; tritanopie à confirmer au simulateur)

`/art-bible` writes these nine sections in this order and replaces each
section's `[To be designed]` line as that section is approved. A section still
holding its placeholder is incomplete; a later run fills only those.

## 1. Visual Identity Statement

### Le Réveil des couleurs

**Règle visuelle : le monde est gris jusqu'à ce que la meute le touche. Une couleur
saturée signifie donc toujours l'une de trois choses : une possession, une menace ou une
mémoire.**

#### Principes

**1. La couleur est un état de jeu** *(piliers 1 et 4)*
On ne met de la saturation que là où elle porte une information de jeu. Le terrain non
revendiqué reste en gris-bleu. Une tuile conquise prend **la teinte de sa faction, et
elle seule** (décision du 2026-10-30) : le terrain s'y lit par sa forme, pas par sa
couleur. L'orange-rouge hachuré est réservé aux intentions ennemies.
*Test : quand la couleur d'un élément est ambiguë, choisir le gris, sauf si l'élément
signale une possession, une menace ou une mémoire.*

**2. La forme avant la teinte** *(pilier 3)*
Les quatre terrains (plaine, forêt, montagne, eau) se distinguent par leur silhouette et
leur valeur, et restent lisibles en gris. Les drones de la meute sont hexagonaux, les
unités ennemies en losange. Tout doit se lire sur une tuile de 31 pt.
*Test : quand on hésite entre distinguer deux éléments par la couleur ou par la forme,
choisir la forme. Le daltonisme et le gris par défaut l'exigent.*

**3. La mémoire est chaude et peinte** *(piliers 2 et 5)*
L'ocre et le sépia appartiennent aux humains. Les ruines sont les seuls éléments ocre/sépia
de la carte, et on les voit à travers le brouillard. Les illustrations peintes (écran
titre, chronique, cartes de présentation des cartes) sont le registre du souvenir.
*Test : quand on hésite sur l'endroit où mettre du détail ou de la chaleur, choisir la
ruine ou l'illustration, jamais le terrain ordinaire.*

#### Production hybride (décision du 2026-10-30)

- **En jeu** : tuiles 3D low-poly en aplats, couleurs par sommet sans textures,
  assemblées depuis le fichier de carte (`design/gdd/carte-tuiles-terrain.md`), avec un
  shader de saturation par tuile (gris → teinte de faction) et le brouillard.
- **Hors jeu** : illustrations peintes pour l'écran titre, la chronique et la carte de
  présentation de chaque carte fixe. Elles ne sont jamais produites tuile par tuile.

#### Réconciliation avec la référence d'ambiance

La référence (`design/art/references/ambiance-carte-grille-carree.png`) montre le monde
**tel qu'on s'en souvient, pleinement éveillé**. Sa palette chaude va donc aux
illustrations peintes, qui relèvent de la mémoire humaine. En jeu, elle ne fournit pas de
teintes : elle fournit une structure de valeurs, des silhouettes (mesas, canyons,
crêtes) et une composition où les ruines monumentales sur des plateaux servent de points
focaux. Une tuile conquise ne revient pas à l'ocre de la référence : elle prend la
teinte de sa faction, sinon les ruines perdraient leur rôle de seul canal ocre/sépia.

**Conséquence** : les palettes de faction excluent l'orange-rouge (menaces) **et** l'ocre
et le sépia (mémoire). Les canyons rouges de la référence ne passent pas tels quels en
jeu.

*Rédigé par l'art-director.*

## 2. Mood & Atmosphere

**Règle d'éclairage (mobile).** Une seule lumière cuite et fixe, venue d'en haut à
gauche (45°). Les ombres et l'occlusion sont intégrées aux couleurs par sommet. **Aucun
état ne rééclaire la scène** : un état ne change que la teinte globale, la saturation et
le cadre de l'interface. Cela reste peu coûteux sur le renderer Mobile et garde la carte
toujours lisible.

| État | Émotion | Lumière | Adjectifs | Énergie | Élément porteur |
|---|---|---|---|---|---|
| Tour du joueur | Curiosité, maîtrise calme | Neutre-froide (~6 500 K), contraste moyen | calme, ouvert, attentif, silencieux | Basse à moyenne | La lisière saturée du territoire contre le gris |
| Menace annoncée | Vigilance | **Inchangée** : seule la menace change (pilier 4) | tendu, précis, suspendu | Moyenne, montante | Hachures orange-rouge à 135° |
| Tour ennemi | Dépossession contrôlée | Voile violet de 8 % au plus, sur la carte seulement (pas sur le HUD), plus froid (~8 000 K), contraste du terrain réduit | froid, mécanique, méthodique, étranger | Moyenne, rythmée | Cadre violet et numéro sous l'unité qui agit |
| Ruine lue | Révélation mélancolique | Chaleur locale (~3 000 K) : lueur ocre radiale, seule source chaude | chaud, intime, nostalgique, lumineux | Basse, puis pic doux | L'onde de recoloration qui part de la ruine, avant le panneau papier |
| Victoire | Fierté apaisée | Saturation des factions relevée, contraste haut ; **jamais d'ocre** hors des ruines | ample, lumineux, fier | Haute, puis retombée | La carte possédée vue en entier |
| Défaite | Perte digne, pas punitive | La teinte de faction se retire en fondu vers le gris | silencieux, gris, digne | Basse | **Les ruines lues restent chaudes** (fragments conservés) |
| Nul | Inachevé | Neutre et plate, sans désaturation | suspendu, équilibré, inachevé | Basse | Frontière nette entre les territoires |
| Menu, chronique | Souvenir | Peinte : lumière rasante de fin de jour (~3 200 K), contraste fort, palette chaude de la référence | nostalgique, chaud, texturé, lent | Basse | Illustration peinte sur grain de papier |
| Première partie | Sécurité, découverte | Celle du tour du joueur ; le reste du HUD en retrait | accueillant, clair, dépouillé | Basse | Un seul élément mis en avant à la fois, par un halo blanc neutre (aucune nouvelle teinte) |

*Rédigé par l'art-director. La vue d'ensemble de la carte en victoire (dézoom) est une
suggestion pour l'ux-designer.*

## 3. Shape Language

**Trois géométries, trois origines.** Les drones de la meute sont propres, symétriques,
à facettes planes. Les Gardiens ennemis sont en losange aigu. Ce que les humains ont
laissé est fait de **courbes brisées** : arches, dômes et colonnes, cassés en arêtes vives
et asymétriques (décision du 2026-10-30, section 6).

**Unités.** Socle hexagonal facetté (meute) ou en losange (ennemis), corps compact et
bas, silhouette occupant 70 à 80 % de la tuile. Chaque type ajoute **un seul trait** sur
le haut de la silhouette, d'au moins 6 pt sur une tuile de 31 pt ; ces traits seront
fixés avec la liste des quelque 6 types d'unités (`design/ux/hud.md` § 13).
*Test : la silhouette pleine en noir se reconnaît à 31 pt.* Un drone endormi garde la
même silhouette, avec un contour en pointillés gris.

**Motif de faction** (doublure pour les daltoniens, sur le dessus du socle et sur les
nœuds) : **chevron** pour la faction 1, **deux barres** pour la faction 2, **deux hexagones concentriques**
pour la faction 3. Les Gardiens portent une barre horizontale dans le losange.

**Terrain** (lisible en gris) :
- eau : plane et en retrait, la plus basse ;
- plaine : plate ;
- forêt : 3 à 5 prismes dentés, de hauteur moyenne ;
- montagne : pyramide facettée à crête, la plus haute des terrains, sans masquer l'unité
  placée devant elle.

Les mesas et les canyons de la référence sont une **composition à l'échelle de la
carte** (falaises striées au bord de groupes de tuiles), sans règle de jeu impliquée.

**Ruines.** Verticales brisées : monolithes, dômes fendus, arches. Ce sont les seules
formes plus hautes que les montagnes, donc les points focaux de la carte.

**Interface.** Les cadres restent neutres (feuilles sombres aux coins arrondis) pour
s'effacer. Le monde revient par les icônes : hexagone = joueur, losange = ennemi, glyphe
en arche brisée = ruine, hachure = menace, trois hexagones concentriques = nœud. Seul le panneau de
fragment a un bord irrégulier, le registre de la mémoire.

**Héros et soutien.** Les unités, les nœuds et les ruines sont les héros ; le terrain
est le soutien, avec peu de contraste interne.

*Rédigé par l'art-director.*

## 4. Color System

*Les luminances et les ratios de contraste ci-dessous sont calculés à la main : à
confirmer avec un analyseur de contraste et le simulateur Coblis avant la production.*

### Palette principale

| Couleur | Hex | Rôle | Par rapport au HUD actuel |
|---|---|---|---|
| Brouillard | #1E2329 | Inconnu | Gardée |
| Gris-bleu | #4E5862 | Non revendiqué, abandon | **Assombrie** (de #56606B ; décision du 2026-10-30) |
| Teal | #1FA38F | Faction 1 | Gardée |
| Violet | #B07CE0 | Ennemi : contours, cadre du tour ennemi | Gardée |
| Orange-rouge | #FF6A3D | Menace, rien d'autre | Gardée |
| Ocre | #C8955A | Mémoire, ruines | Gardée |
| Papier | #EADFC8 | Fragments, chronique | Gardée |

### Factions et ennemi

Teintes et valeurs distinctes (L = luminance relative approchée) :

| Faction | Hex | Teinte | L | Motif (section 3) |
|---|---|---|---|---|
| F1 | #1FA38F teal | 171° | 0,29 | Chevron |
| F2 | #8FD460 vert tendre | 96° | 0,54 | Deux barres |
| F3 | #3A6FE0 cobalt (décision du 2026-10-30) | 221° | 0,18 | Deux hexagones concentriques |
| Ennemi (territoire) | #C49BEA violet clair | 271° | 0,41 | Barre dans le losange |

Couleurs **interdites aux factions** : orange-rouge (menace), ocre et sépia (mémoire),
violet (ennemi). F2 est un vert franc, pas un jaune, pour rester hors du registre chaud.
Le violet #B07CE0 reste pour les contours et le cadre ; le territoire ennemi prend
#C49BEA, car #B07CE0 a la même valeur que le teal. Texte ennemi sur fond sombre : #D2B4F2.

### Vocabulaire des couleurs

- **Possession** : teinte et saturation de faction.
- **Menace** : orange-rouge, hachure à 135°, « ! ».
- **Mémoire** : ocre, sépia, lueur, papier.
- **Gris** : abandon, perte, désactivé.
- **Sélection et portée** : blanc.
- **Interface** : neutre sombre ; la couleur n'y entre que si elle porte un sens.
- **PV bas** : jauge **blanche**, plus courte (décision du 2026-10-30) ; l'alerte passe
  par la longueur et un clignotement lent (fixe en mode animations réduites), jamais par
  un élément chaud sur la carte.

### Écarts à reporter dans `design/ux/hud.md`

1. Gris non revendiqué assombri en #4E5862.
2. Territoire ennemi en #C49BEA.
3. Jauge de PV bas en blanc, plus d'ambre.
4. Recommandation : coche « attaque esquivée » en blanc plutôt qu'en vert (le vert se
   confond avec F1 et F2).
5. Recommandation : aucune nouvelle teinte pour « énergie insuffisante » — coût en gris
   clair et bouton désactivé.
6. Palette daltonienne (§ 10.5) : elle remplace les teintes de faction, d'ennemi et du
   gris non revendiqué ; **menace et ruines restent inchangées** (hachure et « ! »,
   arche brisée et lueur ocre portent la distinction).

### Contraste

- Bouton en cobalt : texte blanc (un texte sombre reste sous 4,5:1).
- Segment ocre sur le papier : environ 2:1, sous le seuil de 3:1 ; contour sombre
  obligatoire.
- Voile du tour ennemi : 8 % au plus, HUD hors du voile, pour garder les hachures à 3:1
  et le texte à 4,5:1.

### Daltonisme (protanopie, deutéranopie)

| Paire | Risque | Doublure |
|---|---|---|
| **Menace / ruine** | Teinte et valeur confondues (L 0,32 contre 0,35) : **la pire paire** | Hachure et « ! » contre arche brisée et lueur |
| Teal / gris non revendiqué | La valeur tient | Saturation et motif |
| F2 / ocre | Proches | Valeur et motif |
| Cobalt / violet ennemi | Proches en teinte | Valeur (0,18 contre 0,41) et forme hexagone / losange |
| Jaune de l'icône d'énergie / F2 | Proches en deutéranopie | L'icône n'est que dans l'interface, jamais sur la carte |

**Palette alternative** (réglage « Palette daltonienne », `design/accessibility-requirements.md`) :
- au lancement : joueur azur #3A8EE6, ennemi jaune pâle #F0DC6E, non revendiqué gris
  neutre #5F6266 ; menace et ruines inchangées. Dans ce mode seulement, le jaune sur la
  carte signifie « ennemi » ;
- à trois factions, un seul axe bleu-jaune ne suffit plus : le **motif** devient le
  repère principal et la valeur le secondaire (F1 #3A8EE6, F2 #A9D6F5, F3 #24408F), à
  valider au simulateur.

### Tritanopie

*Vérifiée à la main, à confirmer au simulateur Coblis.*

| Paire | Résultat | Doublure ; repli si la paire échoue au simulateur |
|---|---|---|
| F1 teal / F3 cobalt | **Risque** : les deux virent au bleu-vert ; seule la valeur les sépare (L 0,29 contre 0,18) | Motif : chevron contre deux hexagones. Repli : la lisière du territoire de F3 passe en trait double, dans tous les modes |
| Menace / ruine | Risque, comme en protanopie : rose-rouge | Hachure et « ! » contre arche brisée et lueur |
| Violet ennemi / menace | Proches (rose) | Valeur (0,41 contre 0,32) ; losange contre hachure |
| Ocre / jaune de l'énergie | Proches | L'énergie reste dans l'interface ; plus d'ambre pour les PV bas |
| F2 / gris non revendiqué | La valeur tient (0,54 contre 0,10) | Saturation et motif |

Pas de palette dédiée : les doublures de forme suffisent.

### Écarts à reporter dans `design/accessibility-requirements.md`

1. Tritanopie : retirer « l'ambre des PV bas » (jauge blanche) et reporter le résultat ci-dessus.
2. Derniers tours : « Compteur en ambre » devient le compteur de la section 7.
3. Palette daltonienne : menace et ruines inchangées ; coche « attaque esquivée » en blanc.

*Rédigé par l'art-director. Point ouvert : si plusieurs factions peuvent être rivales
(IA contre IA), revérifier les paires faction contre faction en mode daltonien.*

## 5. Character Design Direction

*Pas de personnage humain à l'écran : les « personnages » sont les drones de la meute,
les Gardiens ennemis et les drones endormis. L'IA du joueur n'a pas d'avatar.*

### Archétype : la machine qui attend un ordre

À 31 pt, aucun détail ne raconte l'abandon : ce sont la pose et l'environnement qui le
disent. Chaque drone de la meute garde à l'arrière une **niche de commande vide**
(décision du 2026-10-30) : une encoche sombre et rectangulaire, la seule rupture de sa
symétrie, là où se branchait l'opérateur humain. Son capteur reste orienté vers le
dernier ordre reçu. Le reste est propre, entretenu, fonctionnel : une machine en bon
état, sans personne pour la commander. Le récit explicite appartient aux illustrations
peintes.

### Volumes et traits

Trois volumes au plus — socle (hexagone ou losange), corps compact, trait de type — et un
seul point lumineux, l'« œil », à la teinte de la faction.

**Meute : quatre familles de traits** (un trait par type, sur le haut de la silhouette,
d'au moins 6 pt) :
- **Mât** : tige verticale fine (repérage, vision).
- **Lame** : barre horizontale pointée vers l'avant (assaut).
- **Carapace** : plaque large et plate qui déborde du corps (tenue, défense) ;
  volontairement plate, pour ne pas rappeler les dômes des ruines.
- **Fourche** : deux pointes parallèles (soutien, travail).

*Test : les quatre types se reconnaissent en silhouette noire, côte à côte, à 31 pt.*

**Gardiens : familles de traits propres** (décision du 2026-10-30). Les Gardiens ont un
socle en losange, des angles aigus, un contour violet #B07CE0, une barre horizontale
comme motif, et un corps environ 10 % plus haut et plus étroit : gardés par personne, ils
se tiennent droits. Leurs traits forment un **vocabulaire distinct** de celui de la
meute, pour qu'ils paraissent étrangers. Contraintes : un trait par type, d'au moins
6 pt ; aucune ressemblance avec mât, lame, carapace ou fourche en silhouette noire ;
angles aigus, jamais de courbe (la courbe est humaine, section 6). Les familles exactes
seront fixées avec le GDD des unités (6).

### Endormi et réveil

Un drone endormi garde la même silhouette, avec un contour en pointillés gris : il est
entièrement gris-bleu, son socle est enfoncé d'environ 2 pt dans la tuile, son trait
replié à mi-course, son œil éteint. **Le réveil** dure environ 0,6 s, en une seule
passe : le socle se lève, la teinte de faction monte du socle vers le trait, l'œil
s'allume en dernier. Il passe par le shader de saturation existant, sans nouvelle
lumière. Avec les animations réduites, l'état éveillé s'affiche directement.

### Dégâts et destruction

Aucun dégât sur le modèle : les PV ne passent que par la jauge blanche du HUD. Raisons :
la lisibilité (pas de bruit sur la silhouette), le coût (aucune variante de modèle) et la
cohérence (la machine reste intacte, c'est le monde qui est cassé). À la destruction,
l'unité perd sa teinte vers le gris puis s'affaisse : le gris, c'est la perte.

### Pose et mouvement

Raides et mécaniques, sans mouvement organique. Rotation par paliers de 45° (les huit
directions de la carte), déplacement glissé à vitesse constante, sans balancement. En
attente, une seule pulsation lente de l'œil (environ 3 s), désactivée avec les
animations réduites.

### Détail

Un détail de moins de 3 pt à l'écran n'est pas modélisé. Budget proposé : 150 à 400
triangles par unité, un seul niveau de détail (section 8). Le motif de faction sur le
dessus du socle fait au moins 5 pt. **Mêmes silhouettes pour toutes les factions** de la
meute : seuls la palette et le motif changent.

### Lecture contre le terrain

Chaque unité a un contour de 1 pt : sombre #1E2329 pour la meute et les factions, violet #B07CE0 pour les Gardiens (fixe, y compris en palette daltonienne : les familles de traits doublent la couleur). Dans une forêt occupée, les prismes se rangent
dans les coins et laissent le centre libre ; sur une montagne, l'unité se pose sur un
sommet aplati et son trait dépasse la crête.

*Rédigé par l'art-director. Chiffres à confirmer sur un modèle de test : seuil de 3 pt,
150 à 400 triangles, réveil de 0,6 s.*

## 6. Environment Design Language

### Deux architectures, deux auteurs

- **Ruines humaines** : monumentales et civiques, faites de **courbes brisées** — arches,
  dômes, colonnes, cassés en arêtes vives et asymétriques (décision du 2026-10-30). Elles
  sont ocre, et ce sont les seules formes plus hautes que les montagnes.
- **Nœuds** : **bâtis par les drones après le départ des humains** (décision du
  2026-10-30, à confirmer par la narration). Plateformes hexagonales basses aux hexagones
  concentriques, à angles droits, modulaires, alignées sur la grille, intactes ; grises
  tant qu'aucune faction ne les tient.

**Règle : l'humain courbe, la machine droite.** Une courbe sur la carte est toujours un
souvenir.

### Textures

Aucune texture en jeu : des couleurs par sommet en aplats. Quatre raisons : la lisibilité
à 31 pt, un shader de saturation qui reste simple, le coût sur le renderer Mobile, et une
production tenable par une seule personne. Le grain et la touche peinte sont **réservés
au registre de la mémoire** (illustrations, panneau papier) : le contraste entre texture
et aplat porte lui-même du sens — ce qui est texturé appartient aux humains.

### Densité des décors

| Terrain | Décor permis |
|---|---|
| Plaine | Au plus un élément plat (sillon, cratère), en gris |
| Forêt | Seulement ses 3 à 5 prismes |
| Montagne | Aucun |
| Eau | Une seule ligne de ride, statique |

Aucun décor ne dépasse 30 % de la hauteur de la tuile, n'est chaud ou ne ressemble à un
point d'intérêt. Pourquoi si peu : le pilier 3, le point d'intérêt unique par tuile qui
doit dominer, et le budget.

### Raconter sans texte : l'ordre machine sur le désordre humain

- Des **sillons droits** de passage de drones coupent d'anciennes routes courbes.
- Des **cratères alignés en grille** montrent un bombardement méthodique, qui n'a jamais
  cessé.
- Les nœuds sont impeccables, à côté de villes effondrées.
- Les cratères ont des bords nets (récents), les ruines des pans tombés et des vides (anciennes) :
  la guerre a duré plus longtemps que ceux qui l'ont commencée.

### Illustrations et carte

Chaque carte de présentation reprend la **composition du fichier de carte** : mêmes
reliefs, mêmes masses d'eau, même caméra de trois-quarts, lumière en haut à gauche,
palette chaude de la référence. C'est le lieu tel qu'on s'en souvient. Les ruines étant
tirées (3 parmi 9 emplacements), l'illustration ne montre **ni les emplacements candidats
ni les ruines tirées** : les ruines y forment une ligne d'horizon lointaine et générique,
sinon le pilier 5 s'use.

### Brouillard

Un **aplat sombre #1E2329**, sans brume animée (décision du 2026-10-30). Une brume
gris-bleu se confondrait avec #4E5862, qui veut dire « abandon », et effacerait l'écart
de valeur dont la lueur des ruines a besoin pour se voir à travers. La lisière est un
fondu d'une demi-tuile. Les ruines restent visibles par leur glyphe et leur lueur ocre au
dessus du brouillard. L'état « exploré mais hors de vue » appartient au GDD du brouillard
(5) ; proposition : terrain gris-bleu assombri, sans les unités.

### Crêtes et points d'intérêt

La hauteur maximale d'une montagne est fixée pour qu'un point d'intérêt sur la tuile
située derrière elle (vers le haut de l'écran) reste visible à au moins 50 %
(`design/gdd/carte-tuiles-terrain.md`, règle 16). Une unité peut y être partiellement
masquée.

*Rédigé par l'art-director. Chiffres à confirmer sur un modèle de test : décors à 30 % de
la hauteur au plus, 50 % du point d'intérêt visible derrière une crête.*

## 7. UI/HUD Visual Direction

*Rédigé par l'art-director, vérifié par l'ux-designer. Les ratios de contraste sont
calculés à la main, à confirmer à l'analyseur.*

### Écran et monde

Aucun élément diégétique. Deux couches :
- **Écran** : bandeau, puces et panneaux forment le cadre de la carte. Ils ne passent
  jamais au-dessus des tuiles jouables et restent hors du voile violet du tour ennemi.
  **Seule exception** (décision du 2026-10-30, `design/gdd/controles-tactiles-camera.md`,
  règle 15) : la grappe des boutons de carte (+, −, recentrer), colonne de 48 dp dans un coin
  bas du rectangle de carte, en aplats sombres à contour de 1 pt. Elle ne porte aucune
  teinte de faction, et la marge de défilement de deux tuiles permet toujours de sortir une
  tuile de dessous.
- **Monde** : hachures, hexagones de sélection, crochets, jauges et débris sont posés sur les tuiles et
  suivent le zoom. Ils obéissent aux règles de la carte : aplats, aucune texture, contour
  sombre de 1 pt.

### Typographie

Trois polices, une par registre :

| Police | Registre | Graisses | Tailles (à l'échelle 100 %) |
|---|---|---|---|
| Space Grotesk | La machine : interface, libellés | 500, 700 | 12 libellés, 14 corps, 17 titres |
| JetBrains Mono | Les chiffres : chasse fixe, les compteurs ne sautent pas | 700 | 12 stats, 14 dégâts, 15 et plus pour le tour et l'énergie |
| Spectral | La voix humaine : citations et chronique seulement | 400 | 16 (15 minimum) |

- Les citations sont en **Spectral romain** (décision du 2026-10-30), plus lisible pour
  les lecteurs dyslexiques ; la voix humaine se distingue par la serif et le papier.
  L'italique reste possible pour une courte mention (la source d'un fragment).
- Minimums : 12 pt dans le HUD, 14 pt dans les menus (12 pour les libellés
  secondaires), échelle de texte de 100 à 150 %. Jamais de graisse Light ; Medium au
  moins pour un texte clair sur fond sombre ; hauteur d'x d'au moins 0,5 em.
- Aucune hauteur fixe de conteneur : à 150 %, un panneau grandit ou défile.
- Les capitales gardent leurs accents (DÉF, RETROUVÉ, À vous) et l'interligne leur
  laisse la place ; guillemets « » ; les capitales grises (« TOUR ») sont espacées de
  +6 % et jamais sous 12 pt.
- Vérifier que « − » (U+2212), « × », « ✓ », « · » et les lettres accentuées existent
  dans Space Grotesk et JetBrains Mono ; sinon, les remplacer par des icônes.
- **Licences** : les trois polices sont annoncées sous SIL Open Font License 1.1.
  Avant la première version publiée, vérifier le fichier de licence de chacune dans son
  dépôt source, l'inclure dans la build et le citer dans les crédits.

### Icônes

- Grille de 24 pt, zone utile de 20 pt, trait de 2 pt (au moins 1,5 pt sur la carte, avec
  un contour sombre de 1 pt), angles vifs et extrémités carrées : la machine est droite. Seule exception : l'arche brisée de la ruine, la seule courbe de l'interface.
  Taille affichée minimale : 20 pt.
- **Grammaire des états** : contour = disponible ; plein = actif ou possédé ; pointillés
  = inactif. Chaque état garde un signe de forme en plus de la couleur.
- Chaque icône reprend une forme du monde : hexagone (meute), losange barré (Gardiens),
  arche brisée (ruine), carré hachuré à 135° (menace), trois hexagones concentriques (nœud).
- **Pointillés** : courts pour un drone endormi, longs pour une tuile perdue — les deux ne
  se confondent jamais.

### Le blanc et les contrastes de l'interface

- Le blanc porte plusieurs sens (sélection, portée, cible, PV, halo, dégâts) : c'est
  **toujours la forme** qui les distingue (hexagone, point, crochets, jauge, halo,
  chiffre).
- Tout marqueur blanc posé sur le vert F2 (environ 1,8:1) ou sur le territoire ennemi
  #C49BEA (environ 2,3:1) reçoit un contour ou un fond sombre.
- **Texte des boutons de faction, choisi par faction** pour atteindre 4,5:1 : texte
  sombre sur teal et sur vert, texte blanc sur cobalt.
- **Jauge de PV** : un repère fixe à 50 %, pour que les PV bas se lisent sans
  animation.
- **Bouton désactivé** : il dit pourquoi (« manque 3 » avec l'icône d'énergie, à 4,5:1
  au moins), sans nouvelle teinte.

### Animation

Mécanique : de 150 à 300 ms, ralentie en fin de course, sans rebond ni dépassement,
glissements en ligne droite. Une seule chose bouge à la fois dans le HUD ; jamais de texte
lettre par lettre. Avec les animations réduites, tout apparaît directement
(`design/ux/hud.md`, § 10.3) et les pulsations deviennent des états fixes.

### Registre papier

Le panneau de fragment et la chronique sont les **seules surfaces texturées** : papier
#EADFC8, grain fin, bord irrégulier sur le contour extérieur seulement. Texte en sépia
foncé #3B2F22 (environ 9:1). Le grain ne fait pas varier la valeur de plus de 3 % et
s'efface sous le texte ; le contraste se mesure sur la zone la plus sombre du grain. Les
segments « à venir » de la chronique reçoivent un contour sombre (le beige sur papier
reste sous 3:1).

### Écrans peints

L'écran titre et les menus posent l'illustration peinte en plein cadre (lumière rasante,
section 2). Les menus sont des feuilles sombres de l'interface, opaques à 90 % au moins,
posées par-dessus : **aucun texte directement sur la peinture**. Seul le titre du jeu
peut être peint ; tout le reste est du vrai texte, que l'échelle de texte et le lecteur
d'écran peuvent traiter.

### Écarts à reporter dans `design/ux/hud.md`

- Texte du bouton « Fin du tour » choisi par faction (aujourd'hui sombre partout).
- Retirer l'ambre (derniers tours, PV, riposte dangereuse), le vert (revenu « +n », coche
  du journal) et le rouge-orangé (énergie insuffisante) ; les remplacer par la forme, le
  blanc contourné ou le gris clair.
- **Derniers tours** (à la place de l'ambre) : le chiffre du compteur passe en blanc plein,
  graisse 700 ; la barre de tours prend un contour blanc de 2 pt ; une puce « DERNIERS
  TOURS » s'ajoute. Aucun clignotement, donc rien ne change avec les animations réduites.
- **Sélection** : l'anneau blanc de sélection devient un hexagone blanc (décision du
  2026-10-30 : la machine est droite).
- Vérifier la puce de menace (fond brun) au 3:1 non textuel.
- Citations des fragments en Spectral romain.

## 8. Asset Standards

*Rédigé par l'art-director et le technical-artist. La référence du moteur
(`docs/engine-reference/godot/`) ne couvre ni MultiMesh, ni les données par instance, ni
l'importeur glTF, ni la compression des images sur Android : ces points sont NOT
SOURCEABLE et se vérifient au prototype de rendu. La version installée de Godot n'est pas
déterminée.*

### Formats

| Catégorie | Source | Export |
|---|---|---|
| Modèles 3D | `.blend` | `.glb` (glTF 2.0 binaire), un asset par fichier |
| Illustrations | `.kra` ou `.psd`, calques gardés | `.webp` sRGB |
| Icônes | `.svg` | `.svg`, importé par Godot |
| Nuancier | `palette_lmo.gpl` + `palette_lmo.png` | — |

- **Illustrations** : une image maîtresse carrée de 2 560 × 2 560, sujet dans un carré
  central de 1 440 × 1 440 (zone sûre commune aux deux orientations), d'où l'on tire un
  recadrage paysage 2 560 × 1 440 et un portrait 1 440 × 2 560. Pas de 4K. Format de
  compression sur Android et mémoire occupée : NOT SOURCEABLE, à mesurer.
- **Icônes** : `viewBox` 24 × 24, trait de 2, extrémités carrées, une seule couleur
  (blanc) ; la teinte s'applique dans Godot.

### Nommage

`[catégorie]_[nom]_[variante]_[taille].[ext]`, en minuscules, sans accents. Préfixes :
`unit_`, `terrain_`, `ruin_`, `node_`, `prop_`, `cliff_`, `ui_icon_`, `illus_`. Exemples :
`unit_lame.glb`, `terrain_foret_02.glb`, `cliff_angle_rentrant.glb`, `ruin_arche_brisee.glb`,
`ui_icon_noeud_plein.svg`, `illus_carte03_portrait.webp`. La taille n'apparaît que si
plusieurs tailles existent.

### Le gris d'abord

- Unités, terrains et nœuds sont modélisés **en valeurs de gris seulement** ; la lumière
  à 45° venue d'en haut à gauche et l'occlusion sont cuites dans les couleurs par sommet.
- Le **masque de faction** est dans l'alpha de la couleur par sommet : 1 = prend la
  teinte de la faction, 0 = reste gris (niche de commande). Le contour est hors du masque : sa couleur est fixe, #1E2329 pour la meute et les factions, #B07CE0 pour les Gardiens (sur la coque inversée, ou, en repli, sur les faces du maillage). L'œil vaut 1. Le
  passage de cet alpha jusqu'au shader est à vérifier sur l'appareil.
- La teinte d'une faction n'est **jamais peinte** : le shader l'applique, à partir des
  teintes partagées (un seul jeu à changer pour la palette daltonienne).
- Les ruines sont peintes directement en ocre, avec un masque à 0.
- **Nuancier** : les seules couleurs de sommet permises — les couleurs de la section 4
  qui ne sont pas des teintes de faction, une rampe de 6 gris froids et une rampe de 4
  ocres :
  - gris G1 à G6 : #2B323A, #3B444E, **#4E5862**, #66717C, #808B96, #A3ACB5 ;
  - ocres O1 à O4 : #6E4E2C, #9A6E3F, **#C8955A**, #E2B983.
  #4E5862 est le palier G3 : la valeur du dessus d'une tuile de plaine sous la lumière
  cuite, donc la couleur qui signifie « non revendiqué ». G1 et G2 sont les faces d'ombre
  et l'eau ; G4 à G6 sont les dessus plus hauts (forêt, crête) et les héros. #C8955A (O3)
  est la face éclairée d'une ruine.

### Géométrie et export

- 1 tuile = 1 m × 1 m ; origine au centre de la tuile, au sol (y = 0) ; pour une unité,
  au centre du socle.
- Échelle et rotations appliquées, +Y vers le haut, normales séparées par face (rendu en
  aplats).
- Un seul niveau de détail, un seul matériau par asset, aucune texture.
- **Falaises striées** (section 3) : des segments modulaires de 1 m posés sur le bord d'une
  tuile et assemblés depuis le fichier de carte. Leur hauteur égale le dénivelé. Ils ont
  2 à 4 strates horizontales droites, sans courbe : G1 et G2 sur les faces, G4 sur
  l'arête. Un segment appartient à la tuile haute et prend son masque. Trois types :
  droit, angle saillant, angle rentrant.

### Budgets (à valider au prototype de rendu)

| Catégorie | Triangles | Note |
|---|---|---|
| Tuile de terrain | 30 à **200 au plus** (décision du 2026-10-30) | La forêt, avec ses prismes, en haut de la fourchette |
| Unité | 150 à 400 | Contour non compris (voir ci-dessous) |
| Nœud | 150 à 400 | — |
| Ruine | 400 à 1 000 | Les courbes brisées coûtent des triangles |
| Décor | 10 à 60 | — |
| Falaise striée | 20 à 80 par segment | Un segment par bord exposé ; un MultiMesh par type ; à ajouter au pire cas |
| **Total visible** | **moins de 100 000** | Pire cas estimé : environ 85 000 sur une carte de 16 × 16, plus les contours |

- **Appels de dessin** : moins de 100. Les unités sont **obligatoirement instanciées** (un MultiMesh par type d'unité, coques comprises) : 60 unités et leurs coques dessinées une à une dépasseraient à elles seules ce budget. Un MultiMesh par type de terrain, un matériau
  partagé (couleurs par sommet + saturation) pour les tuiles, les unités et les nœuds ;
  un matériau à part pour les ruines, non désaturable.
- **Saturation par tuile** : chaque tuile porte une quantité de saturation (0 à 1) et un
  indice de faction ; le shader mélange le gris et la teinte de faction selon le masque.
  Le moyen exact (données par instance d'un MultiMesh, ou uniform par instance) est NOT
  SOURCEABLE et se compare au prototype.

### Arbitrages entre l'art et le moteur

| Sujet | Préférence artistique | Contrainte technique | Choix |
|---|---|---|---|
| Budget d'une tuile | 300 triangles | 30 à 200 | **200 au plus** (décision du 2026-10-30) |
| Contour sombre des unités (section 5) | Contour régulier et automatique | Une coque inversée double les triangles ou les appels de dessin des unités | **Coque inversée** (décision du 2026-10-30), **à mesurer** ; repli si le budget ne tient pas : contour modélisé dans le maillage, compté dans les 150 à 400 triangles |
| Lisière du brouillard (section 6) | Fondu doux d'une demi-tuile | La transparence crée du surdessin sur le renderer Mobile | **Fondu transparent** (décision du 2026-10-30), **à mesurer** ; repli : assombrissement progressif dans le shader des tuiles, qui restent opaques |
| Contour en pointillés des drones endormis | Pointillés réguliers | Shader ou maillage dédié | À mesurer ; repli : contour plein gris plus clair, l'enfoncement du socle et l'œil éteint suffisant à dire « endormi » |
| Voile du tour ennemi (8 %) | Teinte de toute la carte | Une passe plein écran | À mesurer |
| Lueur des ruines au-dessus du brouillard | Toujours visible | Ordre de rendu ou additif : surdessin localisé | Accepté (9 ruines au plus) |

### Recette d'un asset

Un asset n'est accepté qu'après ces six contrôles, faits dans Godot avec la caméra du jeu :

1. Nom et format conformes.
2. Silhouette noire reconnaissable à 31 pt ; les types d'unités se distinguent côte à côte.
3. Test en gris : sur une capture désaturée, l'asset se détache de ses voisins par la
   valeur et la forme.
4. Aucune couleur de sommet hors du nuancier (vérifié par un script qui relève les écarts
   sans trancher, dans `tools/`).
5. Budget en triangles respecté ; origine et échelle justes sur une tuile de test.
6. Capture conservée dans `production/qa/evidence/`.

### Prototype de rendu (avant de figer ces chiffres)

Sur un Android d'entrée de gamme, renderer Mobile :
1. **Pire cas des unités, en premier** : 60 unités avec leurs coques inversées (environ
   24 000 triangles de plus que les 85 000 estimés), en MultiMesh puis dessinées une à
   une : triangles, appels de dessin, temps GPU. Si le budget ne tient pas, le repli du
   contour est retenu avant de modéliser la moindre unité.
2. Carte 16 × 16 pleine, 60 unités, 10 nœuds, 9 ruines, brouillard, en portrait et en
   paysage : images par seconde, temps GPU, appels de dessin.
3. MultiMesh avec données par instance contre instances séparées avec uniform par instance.
4. Coût de la lisière transparente du brouillard et du voile du tour ennemi, comparé à
   leurs replis.
5. Mémoire des illustrations selon le format de compression.
6. Démarrage avec et sans le Shader Baker (Godot 4.5 et suivants).
7. Version de Godot réellement installée.

## 9. Reference Direction

*Ces références s'étudient (jeux publiés, film, œuvre du domaine public). Aucun asset
n'est tracé, échantillonné ni reproduit. The Battle of Polytopia n'est pas une référence
visuelle : le pilier 3 lui emprunte la lisibilité, rien de sa présentation, de ses noms
ni de ses icônes. Chaque référence a un seul rôle.*

### 1. Référence d'ambiance du projet — la composition

`design/art/references/ambiance-carte-grille-carree.png` (et sa variante hexagonale,
`ambiance-carte-grille-hex.png`).
- **Prendre** : la structure de valeurs — des plateaux clairs bordés de falaises striées
  sombres, et une ruine monumentale posée au centre d'un plateau comme point focal.
- **Éviter** : en jeu, sa palette chaude, qui va aux illustrations (section 1) ; ses
  canyons rouges, son trait encré et sa densité de détail (une tuile garde au plus un
  décor, section 6).

### 2. Monument Valley (ustwo games, 2014) — l'aplat lisible

- **Prendre** : trois valeurs par volume, cuites dans la couleur sans texture — un dessus
  clair, une face éclairée moyenne, une face d'ombre sombre. La forme se lit par les
  seules facettes : c'est le test en gris de la section 8.
- **Éviter** : les pastels, la géométrie impossible, l'ornement architectural, les
  dégradés de ciel. Nos facettes sont en gris froid ; la couleur vient du shader de
  faction.

### 3. Pleasantville (Gary Ross, 1998) — le gris qui se recolore

- **Prendre** : la couleur qui naît sur un seul élément au milieu d'un entourage resté
  strictement gris, puis qui se propage par contact. C'est le modèle de l'onde de
  recoloration (section 2) et du réveil des drones (section 5).
- **Éviter** : la colorisation photographique, la couleur naturelle et toute
  recoloration de la scène entière : chez nous, la couleur revient en teinte de faction.

### 4. Hubert Robert, *Vue imaginaire de la Grande Galerie du Louvre en ruines* (1796, musée du Louvre, domaine public) — la mémoire peinte

- **Prendre** : la ruine comme cadre monumental — une voûte brisée qui se découpe contre
  un ciel occupant au moins un tiers de l'image ; une lumière rasante qui chauffe la
  pierre et laisse le premier plan dans l'ombre.
- **Éviter** : **toute figure humaine**, y compris dans les illustrations (décision du
  2026-10-30 : les humains ne sont plus là, seules leurs ruines parlent — pilier 5) ; le
  vocabulaire antique pris au pied de la lettre (nos ruines sont civiques et modernes,
  section 6) ; le vernis jauni (le grain vient du papier, pas d'un craquelé).

### 5. Into the Breach (Subset Games, 2018) — la menace annoncée

- **Prendre** : l'intention dessinée sur la tuile visée, et non sur l'attaquant, avec son
  ordre d'exécution numéroté : le joueur lit la conséquence avant le coup.
- **Éviter** : le pixel art, les mechas, le clignotement des tuiles et les cadres de son
  interface. Chez nous, la menace est une hachure orange-rouge fixe à 135° avec un « ! »,
  un numéro sous l'unité qui agit, et la carte n'est jamais rééclairée. Notre
  orange-rouge est voisin des teintes de danger de ce jeu (convention du genre) : la
  distinction passe par la forme.

*Rédigé par l'art-director.*
