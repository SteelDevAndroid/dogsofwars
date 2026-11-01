# HUD Design

> **Status**: In Design
> **Author**: user + Claude (ux-designer role)
> **Last Updated**: 2026-10-29
> **Game**: La Meute Orpheline
> **Platform Targets**: Mobile — Android d'abord, iOS ensuite ; tactile uniquement ; portrait et paysage
> **Related GDDs**: `design/gdd/game-concept.md` (seul document de design existant). Aucun GDD système n'existe encore : carte et brouillard, énergie et nœuds, unités et combat, IA à intentions, ruines et fragments devront chacun confirmer leurs besoins d'interface ici.
> **Accessibility Tier**: Standard + 3 éléments Comprehensive (animations réduites, équivalent visuel de chaque son de jeu, disposition paysage inversée) — engagé dans `design/accessibility-requirements.md` le 2026-10-29
> **Style Reference**: `design/gdd/game-concept.md` § Visual Identity Anchor (pas encore d'art bible)
> **Mockups**: canvas « Meute Orpheline HUD » — https://claude.ai/artifact/URFJTkozqrKHZ5FNuZDjAT (6 artboards : 3 états × portrait et paysage)
> **Template**: HUD Design

> **Scope boundary** : ce document couvre ce qui s'affiche pendant une partie, y compris
> le panneau de fragment et le tour ennemi, qui remplacent le panneau d'unité sans
> quitter la carte. L'écran de chronique (hors partie), le menu pause, l'écran de fin de
> partie et les menus relèvent de `ux-spec.md`.

---

## 1. HUD Philosophy

**What is this game's relationship with on-screen information?**

La carte est l'interface. Comme dans Polytopia, tout ce qui compte se lit d'abord sur les
tuiles : la couleur dit qui possède quoi, la forme dit quel type d'unité, le hachuré
orange dit où frappera l'ennemi, la lueur sépia dit où se trouve une ruine. Le HUD n'est
qu'un cadre autour de la carte : un bandeau de ressources, des puces d'alerte et un
panneau contextuel (unité, fragment ou tour ennemi). Il ne répète pas ce que la carte
montre déjà et ne contient jamais un bonus abstrait qui ne se verrait pas sur la carte
(pilier 1).

**Visibility principle** — CONTEXTUAL. Ce qui est vital pour décider (tour, énergie,
menaces annoncées) est toujours visible ; le reste n'apparaît que lorsqu'une unité est
sélectionnée ou qu'un événement survient.

**The Rule of Necessity for this game** :
« Un élément du HUD mérite sa place quand il change la décision du joueur ce tour-ci et
que la carte ne peut pas la porter seule. »

---

## 2. Information Architecture

### 2.1 Full Information Inventory

- Numéro du tour et nombre de tours restants (limite de 30)
- Énergie stockée et revenu par tour
- Fragments lus pendant la partie, sur le nombre de ruines de la carte
- Progression de la chronique de la faction (n / N, N = taille du pool), hors partie
- Possession des tuiles (grise, recolorée par faction)
- Brouillard de guerre
- Ruines repérées sous le brouillard, et distance à la plus proche
- Drones du joueur, drones endormis, unités ennemies
- Nœuds (l'équivalent des villes) et leur niveau
- Unité sélectionnée : type, phrase d'explication, PV, attaque, défense, mouvement
- Portée de déplacement et cibles d'attaque possibles
- Actions disponibles pour l'unité (déplacer, attaquer, capturer, réveiller) et leur coût
- Cibles d'attaque valables, aperçu des dégâts infligés et de la riposte
- PV des unités blessées, sur la carte
- Dégâts reçus et infligés, au moment où ils se produisent
- Pertes : unité détruite, nœud perdu, tuile perdue
- Intentions d'attaque ennemies annoncées (source, cible, tour d'exécution)
- Résultat des intentions au tour ennemi (exécutée, annulée)
- Fragment trouvé : titre, texte, source
- Effet de la lecture d'une ruine (tuiles recolorées)
- Protocoles recherchés et disponibles (arbre de protocoles)
- Score en cours
- Tour du joueur ou tour ennemi

### 2.2 Categorization

| Information Type | Always Show | Contextual | On Demand | Hidden (sur la carte) | Reasoning |
|---|---|---|---|---|---|
| Tour / 30 | ✔ | | | | Fixe le rythme de la partie et l'urgence du score |
| Énergie et revenu | ✔ | | | | Conditionne chaque action du tour |
| Fragments de la partie (n / 3 ruines) | ✔ | | | | Rappelle le moteur de découverte (pilier 5) |
| Possession des tuiles | | | | ✔ | Pilier 1 : la croissance se voit sur la carte, jamais dans un chiffre |
| Brouillard, ruines, unités, nœuds | | | | ✔ | Portés par les tuiles et les silhouettes |
| Ruine repérée + distance | | ✔ (puce) | | ✔ (lueur) | La lueur suffit à proximité ; la puce donne la distance |
| Intentions ennemies | | ✔ (puce) | | ✔ (hachuré) | Pilier 4 : toute perte annoncée doit pouvoir être évitée |
| Unité sélectionnée | | ✔ (panneau) | | | Seulement quand une unité est sélectionnée |
| Portée de déplacement | | ✔ | | ✔ (points) | Affichée sur la carte à la sélection |
| Cibles d'attaque | | ✔ | | ✔ (viseur) | Affichées sur la carte en mode ciblage |
| Aperçu de combat | | ✔ (panneau) | | | Pilier 4 : le joueur connaît le résultat avant de confirmer |
| PV des unités | | ✔ (jauge sous l'unité blessée) | ✔ (panneau d'unité) | | Une unité intacte n'affiche rien ; une blessure se voit sur la carte (pilier 1) |
| Dégâts | | ✔ (chiffres sur la tuile) | | | Brefs, au moment du coup |
| Pertes (unité, nœud, tuile) | | ✔ (puce + journal) | | ✔ (débris, désaturation) | Pilier 1 : chaque perte se voit sur la carte |
| Fragment trouvé | | ✔ (panneau) | | | Au moment de la lecture d'une ruine |
| Chronique n / N | | ✔ (dans le panneau de fragment) | ✔ (écran chronique) | | Hors partie, sauf au moment d'un nouveau fragment |
| Protocoles | | | ✔ | | Écran dédié, hors de ce document |
| Score en cours | | | ✔ (pause) | | Montré en fin de partie ; ne doit pas distraire pendant le tour |
| Tour ennemi | | ✔ (étiquette + teinte violette) | | | Indique que les commandes sont verrouillées |

---

## 3. Layout Zones

### 3.1 Zone Diagram

Portrait (référence 390 × 844 pt) :

```
 ┌───────────────────────────────┐  0%
 │ [TOP BAR] Tour · Énergie ·    │  ~9%
 │           Fragments · Pause   │
 │ [ALERT ROW] puces menace/ruine│  ~14%
 ├───────────────────────────────┤
 │                               │
 │          [MAP]                │
 │   8 colonnes visibles,        │  ~14–76%
 │   défilement et zoom          │  (~9–76% sans puce)
 │                               │
 ├───────────────────────────────┤
 │ [CONTEXT PANEL]               │
 │  Unité (stats en ligne) /     │  ~76–100%
 │  Aperçu de combat             │  (fragment et tour
 │  [bouton principal]           │   ennemi : ~60–100%)
 └───────────────────────────────┘ 100%
```

Paysage (référence 844 × 390 pt) :

```
 ┌──────────┬──────────────────────────┬──────────────┐
 │ [RAIL]   │                          │ [CONTEXT     │
 │ Tour     │         [MAP]            │  PANEL]      │
 │ Énergie  │   12 colonnes visibles   │ Unité /      │
 │ Fragments│                          │ Fragment /   │
 │ Puces    │                          │ Tour ennemi  │
 │ Pause    │                          │ [bouton]     │
 └──────────┴──────────────────────────┴──────────────┘
  140 pt              reste (~52%)           224 pt
```

Le rail gauche passe de 168 à 140 pt et le panneau de 238 à 224 pt par rapport aux
premiers mockups ; la carte gagne la largeur libérée (tuiles de 36,33 pt en paysage, 44,75 pt en portrait à 8 colonnes).

### 3.2 Zone Specification Table

| Zone Name | Screen Position | Safe Zone Compliant | Primary Elements | Max Simultaneous Elements | Notes |
|---|---|---|---|---|---|
| Top bar (portrait) / rail (paysage) | Haut / gauche | Oui — sous l'encoche et hors des zones de geste | Tour, énergie, ruines, pause ; **score décisif** sur une rangée de 26 pt sous la barre en portrait, pastille du rail en paysage | 5 | Toujours visible |
| Grappe de boutons (+, −, Recentrer) | Flottante sur la carte, bord bas droit | Oui | +, −, Recentrer | 3 | Boutons de 48 dp, écart de 8 dp ; +/− grisés aux bornes du zoom ; icônes avec libellés accessibles ; seule exception à « aucun recouvrement de la carte » (art bible §7) ; marge de défilement de 2 tuiles |
| Alert row | Sous le top bar / dans le rail | Oui | Puce menace, puce dernier nœud, puce perte, puce ruine, puces de résultat | 2 (+ compteur « +n » pour les repliées) | **Hauteur réservée en permanence en portrait** (le rectangle de carte ne bouge jamais pendant le tour du joueur) ; repli si vide uniquement si le HUD dépasse 45 % (GDD 17, AC-HU35) |
| Map | Centre | Oui | Tuiles et marqueurs | — | Zone de focus : aucun panneau ne la recouvre |
| Context panel | Bas / droite | Oui — au-dessus de la barre de geste | Panneau unité, fragment ou tour ennemi ; bouton principal | 1 panneau | Un seul panneau à la fois |

**Safe zone margins by platform** :

| Platform | Top | Bottom | Left | Right | Notes |
|---|---|---|---|---|---|
| Android (portrait) | Inset système (barre d'état / encoche) | Inset de la barre de geste | 16 pt | 16 pt | Utiliser les insets d'affichage fournis par l'OS, pas une marge fixe |
| Android (paysage) | 12 pt | Inset de geste | Inset d'encoche + 12 pt | Inset d'encoche + 12 pt | L'encoche peut être à gauche ou à droite |
| iOS | Safe area | Safe area (indicateur d'accueil) | Safe area | Safe area | Mêmes règles, valeurs fournies par l'OS |

---

## 4. HUD Element Specifications

### 4.1 Element Overview Table

| Element Name | Zone | Always Visible | Visibility Trigger | Data Source | Update Frequency | Max Size (% screen W) | Min Readable Size | Overlap Priority | Accessibility Alt |
|---|---|---|---|---|---|---|---|---|---|
| Compteur de tour | Top bar / rail | Oui | — | Gestion des tours | Début de chaque tour | 35% (portrait) | 12 pt libellé, 20 pt chiffre | 1 | Libellé texte « Tour 7 / 30 » |
| Énergie | Top bar / rail | Oui | — | Économie d'énergie | À chaque dépense ou gain | 20% | 16 pt | 1 | Icône éclair + chiffre |
| Fragments de la partie | Top bar / rail | Oui | — | Ruines et fragments | À la lecture d'une ruine | 20% | 16 pt | 1 | Icône ruine + chiffre |
| Score décisif « Victoire : a contre b » | Rangée sous la top bar / rail | Oui | — | Tours et conditions de victoire (formule 1, F = 0) | Début de chaque tour | 55% (portrait) | 12 pt libellé, 14 pt chiffres | 1 | Texte « Victoire : 42 contre 38 » ; score ennemi en public, sans delta ni décomposition |
| Grappe de boutons (+, −, Recentrer) | Map (bord bas droit) | Oui | — | Contrôles | — | 48 dp × 3 | 48 × 48 dp | 1 | Libellés accessibles ; recouvre la carte (exception assumée) |
| Bouton pause | Top bar / rail | Oui | — | — | — | 44 pt | Zone tactile 48 × 48 dp (Android) / 44 × 44 pt (iOS) | 1 | `aria-label` « Pause » |
| Puce de menace | Alert row | Non | ≥ 1 intention ennemie visant une unité du joueur | IA à intentions | Dès le début du tour du joueur (l'annonce est faite en fin de phase ennemie), tour ennemi | 50% | 13 pt | 2 | Motif hachuré + texte ; variante « Siège · 1/2 » ou « 2/2 » |
| Puce de ruine | Alert row | Non | Ruine repérée non lue | Brouillard, ruines | Après chaque déplacement | 50% | 13 pt | 3 | Libellé « Ruine repérée » et glyphe, **sans chiffre** ; un appui centre la carte sur la plus proche (décision du 2026-10-30) |
| Puces de résultat (tour ennemi) | Alert row | Non | Tour ennemi | IA à intentions | Pendant le tour ennemi | 50% | 13 pt | 2 | Icône ✓ ou hachuré + texte |
| Marqueurs de carte | Map | Selon l'état | — | Carte, unités, IA | Continu | 1 tuile | Tuile ≥ 31 pt | — | Forme distincte par type (voir 10.1) |
| Panneau d'unité | Context panel | Non | Unité du joueur sélectionnée | Unités et combat | À la sélection, après chaque action | 100% (portrait), 27% (paysage) | 12 pt texte | 4 | Texte complet |
| Boutons d'action | Context panel | Non | Unité sélectionnée | Unités et combat | Après chaque action | 1/3 du panneau | Zone tactile 48 dp (Android) / 44 pt (iOS) de haut | 4 | Bouton désactivé = état `disabled` lu par le lecteur d'écran |
| Marqueur de cible | Map | Non | Mode ciblage | Unités et combat | À l'entrée en mode ciblage | 1 tuile | Tuile ≥ 31 pt | — | Forme (crochets d'angle), pas seulement la couleur |
| Aperçu de combat | Context panel | Non | Une cible est choisie | Unités et combat (formule du GDD de combat) | À chaque changement de cible | 100% / 27% | 12 pt | 4 (remplace les actions) | Texte complet : « Inflige −4 · Riposte −2 » |
| Jauge de PV | Map (sous l'unité) | Non | PV < PV max | Unités et combat | À chaque dégât ou soin | 80% de la tuile | 3 pt de haut | — | Valeur dans le panneau d'unité et dans l'annonce du lecteur d'écran |
| Chiffres de dégâts | Map (au-dessus de la tuile) | Non | Un coup est porté | Unités et combat | À chaque coup | 1 tuile | 14 pt | — | Signe « − » et texte, pas seulement la couleur |
| Marqueurs de perte | Map | Non | Unité détruite, nœud ou tuile perdus | Unités et combat, nœuds | À la perte | 1 tuile | Tuile ≥ 31 pt | — | Glyphe de débris ; tuile en gris |
| Puce de perte | Alert row | Non | Perte subie au dernier tour ennemi | Unités et combat, nœuds | Début du tour du joueur | 50% | 13 pt | 2 | Texte : « Drone perdu », « Nœud perdu » |
| Bouton « Fin du tour » | Context panel | Oui pendant le tour du joueur | — | Gestion des tours | — | 100% du panneau | 50 pt de haut | 1 | Texte |
| Panneau de fragment | Context panel | Non | Lecture d'une ruine | Ruines et fragments | Une fois par ruine | 100% / 27% | 15 pt citation | 1 (remplace l'unité) | Texte complet, titre `h2` |
| Journal du tour ennemi | Context panel | Non | Tour ennemi | IA à intentions | À chaque action ennemie | 100% / 27% | 12 pt | 1 | Liste ordonnée `ol` |

### 4.2 Element Detail Blocks

---

**Compteur de tour**

- Visual description : libellé « TOUR » en capitales grises, chiffre en mono gras, « / 30 » en gris ; barre de progression fine (4 pt) en couleur de faction.
- Data displayed : tour actuel, limite de tours.
- Update behavior : le chiffre change au début du tour ; la barre avance avec une transition de 300 ms.
- Urgency states : normal ; derniers tours (seuil en 11) : le chiffre passe en blanc plein, graisse 700, la barre prend un contour blanc de 2 pt et une puce « DERNIERS TOURS » s'ajoute ; aucun clignotement (art bible, section 7).
- Interaction : affichage seul.
- Player customization : aucune.

---

**Énergie**

- Visual description : pastille sombre, icône éclair jaune, stock en mono gras, revenu « +n » en gris clair.
- Data displayed : stock actuel, revenu du prochain tour.
- Update behavior : décompte animé du stock lors d'une dépense (200 ms) ; pas de clignotement.
- Urgency states : normal ; insuffisante pour l'action ciblée : le bouton d'action est désactivé et affiche « manque n » avec l'icône d'énergie, en gris clair à 4,5:1 au moins ; aucune nouvelle teinte (art bible, section 7).
- Interaction : appui = détail du revenu par nœud (à spécifier dans le GDD de l'économie).
- Player customization : aucune.

---

**Fragments de la partie**

- Visual description : pastille sombre, icône ruine ocre, « n / 3 ruines » (compte les ruines lues, pas les fragments). Au tour où un fragment est lu, la pastille passe au fond ocre foncé avec un liseré ocre.
- Data displayed : fragments lus pendant la partie, sur le nombre de ruines de la carte.
- Update behavior : le chiffre s'incrémente quand le panneau de fragment s'ouvre.
- Urgency states : aucun.
- Interaction : affichage seul.
- Player customization : aucune.

---

**Puce de menace**

- Visual description : puce arrondie, fond brun sombre, liseré orange-rouge (#FF6A3D), carré hachuré à 135°, texte « n attaque(s) annoncée(s) ».
- Data displayed : nombre d'intentions ennemies visant une unité ou un nœud du joueur.
- Update behavior : apparaît dès le début du tour du joueur (l'IA publie ses intentions en fin de sa phase) ; disparaît quand l'intention est exécutée ou annulée.
- Urgency states : une seule ; la couleur de menace n'est jamais utilisée ailleurs (Visual Identity Anchor).
- Interaction : appui = la carte se centre sur la prochaine tuile visée (à confirmer, voir 13).
- Player customization : aucune.

---

**Puce de ruine**

- Visual description : puce arrondie, fond ocre très sombre, carré ocre avec une légère lueur, texte « Ruine repérée · n tuiles ».
- Data displayed : distance en tuiles jusqu'à la ruine non lue la plus proche.
- Update behavior : recalculée après chaque déplacement.
- Urgency states : aucun.
- Interaction : appui = la carte se centre sur la ruine.
- Player customization : aucune.

---

**Marqueurs de carte**

- Visual description :
  - brouillard : tuile presque noire ;
  - tuile non revendiquée : gris-bleu désaturé #4E5862 ;
  - tuile possédée : couleur de faction saturée ;
  - tuile recolorée par une ruine : couleur de faction avec un liseré clair et un point clair pendant le tour de la lecture ;
  - ruine : glyphe en arche brisée ocre, lueur sépia visible à travers le brouillard ;
  - drone du joueur : hexagone sombre à contour clair ;
  - drone endormi : hexagone en pointillés ;
  - unité ennemie : losange sombre à contour violet ; territoire ennemi en violet clair #C49BEA ;
  - nœud : trois hexagones concentriques ;
  - unité sélectionnée : double hexagone blanc ;
  - portée de déplacement : point blanc ;
  - tuile visée par une intention : fond hachuré orange-rouge et pastille « ! » ;
  - unité ennemie qui a annoncé l'attaque : contour intérieur orange-rouge ;
  - intention annulée : contour orange et croix sur la tuile ;
  - cible d'attaque valable (mode ciblage) : quatre crochets d'angle blancs autour de l'unité ennemie ; la cible choisie a des crochets épais et légèrement animés ;
  - unité détruite : glyphe de débris gris (hexagone brisé pour le joueur, losange brisé pour l'ennemi) sur la tuile, jusqu'à la fin du tour suivant du joueur ;
  - tuile perdue : désaturation en fondu vers le gris (l'inverse de la recoloration), puis passage à la couleur du nouveau propriétaire s'il y en a un ; la tuile garde un liseré gris clair en pointillés, en retrait de 4 pt, jusqu'à la fin du tour suivant du joueur, pour que la perte reste visible après le fondu.
- Data displayed : état de chaque tuile.
- Update behavior : la recoloration d'une tuile se fait en fondu (durée à régler, voir 11).
- Interaction : appui sur une tuile = sélection ; appui sur une tuile de portée = déplacement. Un appui dont le doigt glisse de moins d'une demi-tuile reste un appui ; au-delà, c'est un défilement de la carte (seuil à régler en test).
- Player customization : affichage de la portée (voir 10.5).

---

**Panneau d'unité**

- Visual description : feuille sombre à coins arrondis, environ 220 pt de haut en portrait. Ligne d'en-tête : vignette de l'unité sur fond de faction (44 pt), nom en gras, et sous le nom les stats en une ligne, en mono 12 pt : « PV 10/10 · ATQ 2 · DÉF 1 · MVT 2 ». Phrase d'explication sous l'en-tête (pilier 3 : une unité s'explique en une phrase). Puis 3 boutons d'action et le bouton « Fin du tour ». La grille de 4 cases de stats des premiers mockups est supprimée.
- Data displayed : type, phrase, PV actuels / max, attaque, défense, mouvement.
- Update behavior : contenu remplacé immédiatement à la sélection d'une autre unité.
- Urgency states : unité visée par une intention : la vignette porte la pastille « ! » (à ajouter aux mockups) ; unité blessée : la jauge reste blanche ; sous la moitié, elle passe sous le repère fixe de 50 % (art bible, section 7).
- Interaction : boutons d'action ; un bouton sans cible valable est désactivé, jamais caché, pour que l'ensemble des actions reste lisible. Toujours 3 places :
  - **Déplacer** : la portée s'affiche ; un appui sur une tuile de portée déplace l'unité (un appui, sans confirmation).
  - **Attaquer** : ouvre le mode ciblage (voir « Aperçu de combat ») ; une attaque se confirme toujours (deux appuis).
  - **Capturer** : actif au moment de l'action quand l'unité est sur un nœud non possédé (seuls l'Ouvrier et le Bastion capturent) ; un appui, la zone du nœud se recolore.
  - **Annuler le déplacement** : remplace « Déplacer » après un déplacement ; grisé avec sa raison (RIEN_À_ANNULER, DÉPLACEMENT_A_RÉVÉLÉ, AUTRE_ACTION_DEPUIS). Dans l'aperçu de combat, le bouton secondaire s'appelle « Retour » ou « Annuler l'attaque », jamais « Annuler le déplacement » (GDD 17, règle 12).
  - **Réveiller** : remplace « Capturer » quand un drone endormi est adjacent ; le coût en énergie s'affiche sur le bouton ; un appui.
- Player customization : aucune.

---

**Aperçu de combat**

- Visual description : remplace la ligne des boutons d'action dans le panneau d'unité. Deux colonnes : à gauche l'unité du joueur, à droite la cible ; sous chacune, sa jauge de PV avec la part perdue hachurée en gris clair. Au centre, deux lignes : « Inflige −4 » et « Riposte −2 » (ou « Pas de riposte » quand la cible meurt ou que l'attaquant est hors de sa portée). Si la cible meurt, sa jauge se vide et le texte dit « Détruit ». Boutons « Annuler » (secondaire) et « Confirmer l'attaque » (principal, couleur de faction) : ils prennent la place du bouton « Fin du tour », masqué pendant le ciblage, ce qui garde le panneau dans le budget de la section 7. En paysage, l'aperçu s'empile verticalement (une ligne par unité) et « Confirmer l'attaque » passe au-dessus d'« Annuler », sur toute la largeur.
- Data displayed : dégâts infligés, PV de la cible après le coup, riposte, PV de l'attaquant après la riposte. Toutes les valeurs viennent de la formule du GDD de combat ; le HUD ne calcule rien.
- Update behavior : recalculé à chaque appui sur une autre cible valable.
- Urgency states : si la riposte détruirait l'attaquant, la ligne « Riposte » passe en blanc gras avec le glyphe de débris et le texte « Votre unité sera détruite ».
- Interaction : appui sur une cible marquée = la choisir ; second appui sur la même cible ou « Confirmer l'attaque » = attaquer ; « Annuler » ou appui hors cible = retour au panneau d'unité. Raccourci : avec une unité sélectionnée, un appui direct sur une unité ennemie à portée ouvre le mode ciblage avec cette cible déjà choisie.
- Player customization : aucune.

---

**Jauge de PV**

- Visual description : barre de 3 pt sous l'unité, 80% de la largeur de la tuile ; blanche sur fond sombre, avec un repère fixe à 50 % ; sous la moitié, seule la longueur change (clignotement lent, fixe avec les animations réduites). Absente quand l'unité est intacte.
- Data displayed : PV actuels / PV max, sans chiffre.
- Update behavior : descend en 300 ms après un coup.
- Interaction : affichage seul.
- Player customization : aucune.

---

**Chiffres de dégâts**

- Visual description : « −4 » en mono gras 14 pt, blanc à contour sombre, au-dessus de la tuile touchée.
- Data displayed : dégâts du coup.
- Update behavior : monte de 12 pt et s'efface en 800 ms ; l'attaque puis la riposte s'affichent l'une après l'autre.
- Interaction : affichage seul.
- Player customization : aucune.

---

**Marqueurs de perte et puce de perte**

- Visual description : sur la carte, glyphe de débris gris pour une unité détruite et désaturation des tuiles perdues (voir « Marqueurs de carte »). Dans la zone d'alerte, puce grise à liseré clair avec le même glyphe et le texte « Drone perdu » ou « Nœud perdu » (avec un compteur si plusieurs pertes).
- Data displayed : nature et nombre des pertes du dernier tour ennemi.
- Update behavior : la puce apparaît au début du tour du joueur et disparaît à la fin de ce tour.
- Urgency states : aucun ; le gris reste la couleur de l'abandon (Visual Identity Anchor), jamais l'orange-rouge réservé aux menaces.
- Interaction : appui sur la puce = la carte se centre sur la perte.
- Player customization : aucune.

---

**Bouton « Fin du tour »**

- Visual description : bouton plein en couleur de faction, texte choisi par faction pour atteindre 4,5:1 (sombre sur teal et sur vert, blanc sur cobalt), flèche ; 54 pt en portrait, 50 pt en paysage ; placé en bas à droite en paysage, à portée du pouce.
- Data displayed : libellé seul.
- Update behavior : désactivé pendant le tour ennemi (le panneau du tour ennemi le remplace).
- Urgency states : aucun ; il ne doit jamais bloquer ni avertir, puisque les menaces sont déjà affichées.
- Interaction : appui = fin du tour. Le bouton est à au moins 8 dp de tout autre élément tactile, pour éviter de finir le tour par erreur.
- Player customization : aucune.

---

**Panneau de fragment**

- Visual description : feuille couleur papier (#EADFC8) avec une lueur ocre, seul élément clair du HUD ; en-tête « FRAGMENT RETROUVÉ » et titre ; citation en Spectral romain sur fond papier plus clair, avec sa source en mono ; barre de chronique à N segments (N = taille du pool, 5 au MVP) (segments lus en brun, nouveau segment en ocre lumineux, segments à venir en beige) ; ligne « Zone recolorée · +n tuiles » (dans le rail en paysage) ; bouton « Continuer » sombre.
- Data displayed : titre du fragment, texte, source, progression de la chronique, nombre de tuiles recolorées.
- Update behavior : glisse depuis le bas (portrait) ou la droite (paysage) en 300 ms, après la recoloration de la zone, pour que le joueur voie d'abord l'effet sur la carte.
- Urgency states : aucun.
- Interaction : « Continuer » ferme le panneau et rend le panneau d'unité.
- Player customization : aucune.

---

**Journal du tour ennemi**

- Visual description : feuille sombre à liseré violet ; titre « Actions des Gardiens » et compteur « n / total » ; liste numérotée des actions ; une intention nouvelle est surlignée en orange-rouge avec le motif hachuré ; une attaque annulée porte une coche blanche contournée. Boutons « Revoir » et « À vous · tour n ».
- Data displayed : chaque action ennemie dans l'ordre d'exécution. Une attaque exécutée affiche ses dégâts (« Votre Éclaireur subit −3 »). Une perte a sa propre ligne, en gris avec le glyphe de débris : « Votre drone est détruit », « Nœud perdu ».
- Update behavior : une ligne apparaît avec chaque action jouée sur la carte ; la carte reçoit un cadre violet et un numéro sous l'unité qui agit.
- Urgency states : intention nouvelle (orange-rouge).
- Interaction : « Revoir » rejoue le tour ennemi ; « À vous » rend la main. Le tour ennemi peut être accéléré (voir 11).
- Player customization : vitesse du tour ennemi (voir 10.5).

---

## 5. HUD States by Gameplay Context

| Context | Elements Shown | Elements Hidden | Elements Modified | Transition Into This State |
|---|---|---|---|---|
| Tour du joueur, aucune sélection | Top bar, puces, « Fin du tour » | Panneau d'unité | Le panneau se réduit au bouton « Fin du tour » | Début du tour |
| Tour du joueur, unité sélectionnée | Top bar, puces, panneau d'unité, portée sur la carte | — | — | Appui sur une unité ; immédiat |
| Tour du joueur, ciblage | Top bar, puces, panneau d'unité avec l'aperçu de combat, marqueurs de cible | Boutons d'action, portée de déplacement, « Fin du tour » | « Annuler » et « Confirmer l'attaque » prennent la place de « Fin du tour » | « Attaquer », ou appui sur un ennemi à portée ; immédiat |
| Résolution d'une attaque | Top bar, chiffres de dégâts, jauges de PV, marqueurs de perte, panneau d'unité (PV à jour, résumé du coup, tous les boutons désactivés) | Aperçu de combat | Commandes verrouillées le temps de l'animation (≈ 1,6 s, voir 11) | « Confirmer l'attaque » |
| Début du tour après des pertes | Comme le tour du joueur, plus la puce de perte | — | Débris et tuiles désaturées encore visibles sur la carte | Fin du tour ennemi |
| Lecture d'une ruine | Top bar, panneau de fragment | Panneau d'unité, puce de ruine | Pastille des fragments en ocre | Fin du déplacement sur la ruine → recoloration → panneau (300 ms) |
| Tour ennemi | Top bar, étiquette « Tour ennemi », puces de résultat, journal | Panneau d'unité, « Fin du tour » | Fond et cadre de carte teintés en violet ; barre de tour en violet | Appui sur « Fin du tour » |
| Pause | Menu pause (voir `ux-spec.md`) | Tout le HUD de jeu | — | Bouton pause ou application mise en arrière-plan |
| Reprise après un kill de l'application | Le même état qu'au moment de la sauvegarde | — | — | Lancement ; aucun panneau ne doit réapparaître à moitié |
| Derniers tours | Comme le tour du joueur, plus la puce « DERNIERS TOURS » | — | Chiffre en blanc plein 700, contour blanc de 2 pt sur la barre | Au seuil de tours restants |
| Fin de partie | Écran de score (voir `ux-spec.md`) | Tout le HUD de jeu | — | Domination ou fin du 30e tour |

---

## 6. Information Hierarchy

| Element | Priority Tier | Reasoning | What Replaces It If Hidden |
|---|---|---|---|
| Marqueurs de menace sur la carte | MUST KEEP | Pilier 4 : toute perte annoncée doit pouvoir être évitée | — |
| Puce de menace | MUST KEEP | Signale les menaces hors de la partie visible de la carte | — |
| Compteur de tour | MUST KEEP | Fixe le rythme et la limite des 30 tours | — |
| Énergie | MUST KEEP | Conditionne chaque action | — |
| « Fin du tour » | MUST KEEP | Seul moyen d'avancer | — |
| Aperçu de combat | MUST KEEP | Pilier 4 : aucune attaque sans connaître le résultat | — |
| Marqueurs de perte | MUST KEEP | Pilier 1 : chaque perte se voit sur la carte | — |
| Jauge de PV | SHOULD KEEP | Rend les blessures visibles sans sélection | PV dans le panneau d'unité |
| Puce de perte | SHOULD KEEP | Signale une perte hors de la partie visible de la carte | Journal du tour ennemi |
| Chiffres de dégâts | CAN HIDE | Redondants avec les jauges de PV | Jauges de PV |
| Panneau d'unité | SHOULD KEEP | Explique l'unité en une phrase (pilier 3) | Appui long sur l'unité (à spécifier) |
| Panneau de fragment | SHOULD KEEP | Cœur du pilier 2 | Écran de chronique hors partie |
| Journal du tour ennemi | SHOULD KEEP | Rend le tour ennemi lisible et donc juste | Animations sur la carte seules |
| Puce de ruine | CAN HIDE | La lueur sur la carte suffit à proximité | Lueur sépia |
| Fragments de la partie | CAN HIDE | Information de suivi, pas de décision | Panneau de fragment |
| Portée de déplacement | CAN HIDE | Option pour joueurs expérimentés | — |
| Score décisif des deux camps (« Victoire : a contre b ») | MUST KEEP (permanent, GDD 17 E07) | Évite « je me crois en tête et je perds » ; hors points de ruine | Barre / rail |

---

## 7. Visual Budget

| Budget Constraint | Limit | Measurement Method | Current Estimate | Status |
|---|---|---|---|---|
| Éléments HUD actifs simultanés | 9 | Compter les éléments visibles hors marqueurs de carte | 9 (tour, énergie avec revenu, ruines, **score décisif**, pause, 2 puces, panneau, fin du tour) ; le passage de 8 à 9 est le prix du score permanent (GDD 17, règle 19) ; la zone d'alerte est plafonnée à 2 puces (règle 4 de la section 8) | OK, à remesurer |
| Part de l'écran couverte par le HUD — portrait, tour du joueur | 45% | Surface des zones HUD / surface de l'écran à 390 × 844, mesurée dans l'état « unité sélectionnée » avec 2 puces (le cas courant le plus chargé) | **≈ 42% avec le score décisif** (remesure du 2026-10-30, calculée sur les mockups mis à jour : top bar 62 pt + rangée du score 30 pt + zone d'alerte réservée 44 pt = 136 pt, panneau ≈ 220 pt, total 356 pt sur 844 ; avant le score : ≈ 40%). Marge de 3 points sous le budget ; la hauteur de l'alerte est réservée même sans puce | OK, à confirmer sur appareil (AC-HU35) |
| Part de l'écran couverte par le HUD — paysage, tour du joueur | 45% | Largeur du rail + largeur du panneau / largeur de l'écran à 844 × 390 | ≈ 43% (rail 140 pt + panneau 224 pt) ; la pastille du score s'ajoute dans la hauteur du rail (≈ 338 pt utilisés sur 366 disponibles, sans changer la largeur) | OK, à confirmer sur appareil |
| Part de l'écran — états à commandes verrouillées (panneau de fragment, tour ennemi) | 55% | Même méthode | Portrait ≈ 50% (≈ 48% avant le score) ; paysage ≈ 43% | OK. Exception assumée : le joueur n'agit pas sur la carte pendant ces états, et la carte reste visible au-dessus du panneau |
| Recouvrement de la carte par un panneau | 0% (hors grappe de boutons : 3 × 48 dp, écart 8 dp) | Aucun panneau ne passe au-dessus des tuiles jouables ; la marge de défilement de 2 tuiles (62 pt) permet de dégager une tuile | 0% sur les mockups, grappe à ajouter | OK |
| Contraste minimal du texte HUD | 4,5:1 (WCAG AA) | Mesuré sur chaque fond réel | Non mesuré | À vérifier |
| Taille minimale des zones tactiles | 48 × 48 dp sur Android, 44 × 44 pt sur iOS (`design/accessibility-requirements.md`) | Zone qui réagit à l'appui, mesurée sur appareil à la plus petite résolution visée ; elle peut déborder du dessin de l'élément sans changer la mise en page | Boutons du panneau et « Fin du tour » : 48 pt et plus dessinés. Bouton pause et boutons d'action en paysage : 44 pt dessinés, zone à étendre. Puces d'alerte : ≈ 30 pt dessinés, zone à étendre à 48 dp | À implémenter ; budget d'écran inchangé |
| Taille minimale d'une tuile | 31 pt | Mesurée au zoom minimal | 36,33 pt en paysage (carte de 436 pt sur 12 colonnes), 44,75 pt en portrait (358 pt sur 8 colonnes) ; 12 colonnes refusées en portrait (29,83 pt) | À valider au doigt sur appareil |
| Taille minimale du texte | 12 pt | Mesurée à l'échelle de texte 100% | 12 pt : les stats passent en une ligne de 12 pt, les libellés de 10 pt disparaissent | OK après réduction |

---

## 8. Feedback & Notification Systems

| Notification Type | Trigger System | Screen Position | Duration (ms) | Animation In / Out | Max Simultaneous | Priority | Queue Behavior | Dismissible? |
|---|---|---|---|---|---|---|---|---|
| Intention ennemie annoncée | IA à intentions | Alert row + carte | Jusqu'à exécution ou annulation | Fondu 200 ms | 1 puce (compteur agrégé) | Critique | Jamais en file ; agrège le nombre | Non |
| Ruine repérée | Brouillard, ruines | Alert row | Tant qu'une ruine est repérée et non lue | Fondu 200 ms | 1 puce | Basse | Une seule puce, la plus proche | Non |
| Fragment trouvé | Ruines et fragments | Context panel | Jusqu'à « Continuer » | Glissement 300 ms | 1 | Haute | Si deux ruines sont lues au même tour, les panneaux s'enchaînent | Oui (« Continuer ») |
| Attaque esquivée / annulée | IA à intentions | Alert row + journal | Durée du tour ennemi | Fondu 200 ms | 1 puce | Moyenne | Agrège le nombre d'attaques annulées | Non |
| Drone réveillé | Unités | Carte (sur la tuile) | 600 | Séquence de réveil en une passe, sans toast | Illimité | Moyenne | Pas de toast : l'effet reste sur la carte (pilier 1) | Non |
| Dégâts (infligés ou reçus) | Unités et combat | Carte (au-dessus de la tuile) | 800 | Montée de 12 pt + fondu | Illimité | Moyenne | L'attaque puis la riposte, l'une après l'autre | Non |
| Unité du joueur détruite | Unités et combat | Carte (débris) + journal + puce de perte | Débris : jusqu'à la fin du tour suivant du joueur ; puce : tour du joueur | Gris puis affaissement 400 ms, puis débris fixe | 1 puce (compteur agrégé) | Haute | Jamais en file ; fusion des pertes du même type | Non |
| Nœud perdu | Nœuds | Carte (désaturation de la zone) + journal + puce de perte | Puce : tour du joueur | Désaturation 400 ms, puis couleur du nouveau propriétaire | 1 puce (compteur agrégé) | Haute | Jamais en file | Non |
| Tuile perdue (hors nœud) | Nœuds, carte | Carte uniquement | Permanent | Désaturation 400 ms | Illimité | Moyenne | Pas de puce : la carte suffit | Non |
| Unité ennemie détruite | Unités et combat | Carte (débris) | Jusqu'à la fin du tour | Gris puis affaissement 400 ms | Illimité | Moyenne | Pas de puce | Non |
| Derniers tours | Gestion des tours | Compteur de tour + puce | Permanent | Changement de graisse et contour, sans clignotement | 1 | Moyenne | — | Non |

**Notification queue rules** :
1. Pendant le tour ennemi, aucune notification de basse priorité n'apparaît ; elles reviennent au début du tour du joueur.
2. Les puces d'un même type se fusionnent en une seule puce avec un compteur.
3. Les intentions ennemies et les pertes ne sont jamais mises en file ni masquées, quel que soit l'état du HUD.
4. La zone d'alerte affiche au plus 2 puces, par priorité : menace (siège compris), puis dernier nœud, puis perte, puis ruine, avec un compteur « +n » pour les puces repliées ; « DERNIERS TOURS » vit dans le compteur de tour et n'occupe pas d'emplacement. Une puce de ruine poussée hors de la zone reste représentée par la lueur sur la carte.

---

## 9. Platform Adaptation

| Platform | Safe Zone | Resolution Range | Input Method | HUD-Specific Notes |
|---|---|---|---|---|
| Android téléphone, portrait | Insets système | 360 × 640 dp à 412 × 915 dp | Tactile | Mise en page de référence ; vérifier le dépassement de budget à 360 dp |
| Android téléphone, paysage | Insets système + encoche | 640 × 360 dp à 915 × 412 dp | Tactile | Rail gauche, panneau droit ; le bouton principal à droite |
| Android tablette | Insets système | 600 dp et plus | Tactile | À spécifier : probablement le paysage avec plus de colonnes de carte |
| iOS téléphone | Safe area | Gamme iPhone actuelle | Tactile | Mêmes règles qu'Android ; indicateur d'accueil en bas |

**HUD repositionability requirement** : le repositionnement libre n'est pas requis sur
mobile pour la certification et reste hors périmètre (`design/accessibility-requirements.md`,
Known Intentional Limitations). La **disposition paysage inversée** est engagée : un
réglage échange le rail et le panneau de contexte en paysage, pour les gauchers et
l'usage à une main gauche (voir 10.5).

---

## 10. Accessibility

> Exigences propres au HUD uniquement. Le standard du projet ira dans
> `design/accessibility-requirements.md` (palier Standard + 3 éléments Comprehensive,
> engagé le 2026-10-29). En cas de conflit, ce document-là l'emporte.

### 10.1 Colorblind Modes

Deux protections s'ajoutent : chaque signal coloré a une doublure non colorée (tableau
ci-dessous), et le réglage **Palette daltonienne** (10.5) remplace les teintes par une
palette adaptée aux daltonismes rouge-vert. La tritanopie est couverte par les
doublures ; une palette dédiée n'est ajoutée que si le test de
`design/accessibility-requirements.md` échoue.

| Element | Color-Only Information Risk | Colorblind Mode Fix |
|---|---|---|
| Possession des tuiles | Faction distinguée par la couleur | Motif de faction sur les nœuds et les unités : chevron (F1), deux barres (F2), deux hexagones concentriques (F3) — art bible, section 3 |
| Unités joueur / ennemi | Teinte | Formes différentes : hexagone pour le joueur, losange pour l'ennemi |
| Menace | Orange-rouge | Motif hachuré et pastille « ! » en plus de la couleur |
| États de la carte | Teinte et luminosité | INCONNUE : aplat de brouillard, aucun glyphe ; EXPLORÉE : terrain assombri, unités masquées ; VISIBLE : plein. Nœud adverse mémorisé : anneaux en contour (niveau inconnu) ; dormant mémorisé : pointillés courts. Intention hors de vue : hachure et « ! » sans auteur ni flèche |
| Ruine | Ocre / sépia | Arche brisée et lueur, visibles en niveaux de gris |
| Attaque esquivée | Blanc contourné | Coche ✓ et texte |
| Intention annulée | Orange | Croix × sur la tuile |
| Bouton d'action désactivé | Gris | État `disabled` + contraste réduit + libellé inchangé |
| Cible d'attaque | Blanc sur la tuile ennemie | Crochets d'angle (forme) |
| Riposte dangereuse | Blanc gras | Glyphe de débris et texte « Votre unité sera détruite » |
| PV bas | Blanc (aucune teinte) | Longueur de la jauge, repère fixe à 50 % + valeur dans le panneau |
| Perte | Gris | Glyphe de débris + texte dans la puce et le journal |

### 10.2 Text Scaling

À 150%, le top bar en portrait ne tient plus sur une ligne : l'énergie et les fragments
passent sous le compteur de tour. En paysage, le rail garde sa largeur et les puces
passent sur deux lignes. Le panneau de fragment défile verticalement plutôt que de
couper la citation. La ligne de stats du panneau d'unité passe sur deux lignes (PV et ATQ, puis DÉF et MVT) au lieu d'être tronquée.

**Text scaling test matrix** :

| Element | 100% (baseline) | 125% | 150% | Overflow behavior |
|---|---|---|---|---|
| Top bar | TBD | TBD | TBD | Passage sur deux lignes |
| Puces d'alerte | TBD | TBD | TBD | Retour à la ligne dans la puce |
| Panneau d'unité | TBD | TBD | TBD | Ligne de stats sur deux lignes |
| Panneau de fragment | TBD | TBD | TBD | Défilement interne |
| Journal du tour ennemi | TBD | TBD | TBD | Défilement interne |

### 10.3 Motion Sensitivity

| Animation / Motion Element | Severity | Disabled by Reduced Motion Setting? | Replacement Behavior |
|---|---|---|---|
| Recoloration des tuiles en fondu | Mild | Optional | Changement instantané |
| Glissement des panneaux | Mild | Yes | Apparition instantanée |
| Séquence de réveil (600 ms) | Mild | Yes | État éveillé direct, son conservé |
| Pulsation de l'œil au repos | Mild | Yes | Œil fixe |
| Lueur des ruines et du nouveau segment de chronique | Mild | Yes (si animée) | Lueur fixe |
| Animations du tour ennemi | Moderate | Yes | Déplacements instantanés, journal conservé |
| Chiffres de dégâts qui montent | Mild | Yes | Chiffre fixe pendant 800 ms |
| Affaissement d'une unité détruite | Moderate | Yes | Passage direct au glyphe de débris |
| Recoloration en fondu (onde) | Moderate | Yes (pas « Optional ») | État final immédiat |
| Désaturation d'une tuile perdue | Mild | Optional | Changement instantané |
| Crochets animés de la cible choisie | Mild | Yes | Crochets épais fixes |

### 10.4 Subtitles Specification

Sans objet : le jeu n'a ni dialogue ni voix (anti-pilier « pas de cinématiques ni de
dialogues »). Si des sons portent une information (menace, réveil), chacun doit avoir un
équivalent visuel déjà décrit plus haut.

### 10.5 HUD Opacity and Visibility Controls

| Setting | Range | Default | Effect |
|---|---|---|---|
| Échelle du texte du HUD | 100% à 150% | 100% | Agrandit tout le texte ; mise en page adaptée (10.2) |
| Réduction des animations | On / Off | Off (suit le réglage système) | Applique 10.3 |
| Portée de déplacement | On / Off | On | Affiche ou masque les points de portée |
| Vitesse du tour ennemi | Normale / Rapide / Instantanée | Normale | Durée des animations du tour ennemi |
| Panneau à gauche (paysage) | On / Off | Off | Échange le rail et le panneau de contexte en paysage ; « Fin du tour » passe en bas à gauche. Engagé (élément Comprehensive de `design/accessibility-requirements.md`) |
| Palette daltonienne | Off / Protanopie-Deutéranopie | Off | Remplace les couleurs de faction, d'ennemi et du gris non revendiqué par la palette alternative de l'art bible (section 4) ; **menace et ruines restent inchangées**, comme les formes, motifs et hachures. Le contour violet des Gardiens est fixe. Exigé par le palier Standard |

---

## 11. Tuning Knobs

| Parameter | Current Value | Range | Effect of Increase | Effect of Decrease | Player Adjustable? | Notes |
|---|---|---|---|---|---|---|
| Durée du fondu de recoloration | 400 ms | 0–1000 ms | Effet plus visible, tour plus lent | Plus nerveux, effet moins lisible | Indirect (réduction des animations) | Pilier 1 : doit rester visible |
| Durée du glissement des panneaux | 300 ms | 0–500 ms | Plus doux | Plus vif | Indirect | |
| Délai entre recoloration et panneau de fragment | 400 ms | 0–1000 ms | Le joueur voit mieux l'effet | Le texte arrive plus vite | Non | Le joueur doit voir la carte changer avant de lire |
| Durée d'une action au tour ennemi (vitesse normale) | 600 ms | 200–1500 ms | Plus lisible, plus long | Plus rapide, moins lisible | Oui (vitesse du tour ennemi) | Budget : tour IA < 2 s de calcul (TD-FEASIBILITY) |
| Seuil « derniers tours » | 5 tours restants | 3–10 | Alerte plus tôt | Alerte plus tard | Non | |
| Durée des chiffres de dégâts | 800 ms | 400–1200 ms | Plus lisible, attaque plus longue | Plus vif | Indirect (réduction des animations) | Attaque + riposte ≈ 1,6 s au total |
| Durée de l'affaissement et de la désaturation | 400 ms | 0–800 ms | Perte plus marquée | Perte plus discrète | Indirect | Pilier 1 : la perte doit rester visible |
| Durée d'affichage des débris | Jusqu'à la fin du tour suivant du joueur | 1–2 tours | Le joueur retrouve mieux ses pertes | Carte plus nette | Non | |
| Colonnes de carte visibles (zoom par défaut) | 8 portrait / 12 paysage | 6–10 / 10–14 | Plus de carte, tuiles plus petites | Tuiles plus grandes | Oui : pincement, et toujours un moyen sans geste à deux doigts (boutons +/− ou double appui, choix ouvert dans `design/accessibility-requirements.md`) | Tuile ≥ 31 pt |

Valeurs de départ choisies pour les mockups ; elles sont à valider en playtest, aucune ne
découle encore d'une formule.

---

## 12. Acceptance Criteria

**Layout & Visibility**
- [ ] Tous les éléments respectent les insets système (encoche, barre de geste, indicateur d'accueil) en portrait et en paysage, sur l'appareil de référence et sur un Android d'entrée de gamme
- [ ] Aucun panneau ne recouvre une tuile jouable, quel que soit l'état de la section 5
- [ ] Pendant le tour du joueur, le HUD couvre au plus 45% de l'écran en portrait et en paysage, mesuré à la résolution de référence dans l'état « unité sélectionnée » avec 2 puces
- [ ] Pendant le panneau de fragment et le tour ennemi, le HUD couvre au plus 55% de l'écran
- [ ] La zone d'alerte n'affiche jamais plus de 2 puces
- [ ] Tout élément qui réagit à l'appui (boutons, puces d'alerte, bouton pause) a une zone tactile d'au moins 48 × 48 dp sur Android et 44 × 44 pt sur iOS, mesurée sur appareil, même quand son dessin est plus petit
- [ ] Une tuile mesure au moins 31 pt au zoom minimal

**Per-Context Correctness**
- [ ] Chaque état de la section 5 affiche exactement les éléments listés, et rien d'autre
- [ ] Pendant le tour ennemi, aucune commande du joueur n'est active, hors pause et « Revoir »
- [ ] Après un kill de l'application, la reprise affiche le même état de HUD qu'à la sauvegarde, sans panneau à moitié ouvert
- [ ] Le panneau de fragment n'apparaît qu'après la fin de la recoloration de la zone

**Readability (piliers)**
- [ ] Toute intention ennemie visant une unité du joueur est visible sur la carte (hachuré + « ! ») et dans la puce de menace dès le début du tour du joueur
- [ ] Une intention dont la cible est morte ou déplacée s'affiche comme annulée au tour ennemi, jamais comme redirigée
- [ ] Une ruine sous le brouillard se repère sur une capture d'écran en niveaux de gris, depuis l'autre bout de la carte visible
- [ ] Un changement de possession se voit sur la carte sans lire aucun texte du HUD

**Combat**
- [ ] « Attaquer » ou un appui sur un ennemi à portée marque toutes les cibles valables, et seulement elles, avec des crochets d'angle
- [ ] Aucune attaque n'est exécutée sans l'affichage préalable de l'aperçu de combat et une confirmation
- [ ] Les dégâts et la riposte affichés dans l'aperçu sont identiques au résultat, dans 100% des attaques d'une partie de test
- [ ] Quand la riposte détruirait l'attaquant, l'aperçu l'annonce en texte avant la confirmation
- [ ] « Annuler » ou un appui hors cible rend le panneau d'unité sans consommer l'action

**Pertes**
- [ ] Chaque perte (unité détruite, nœud perdu, tuile perdue) est visible sur la carte pendant le tour où elle se produit, et au début du tour suivant du joueur
- [ ] Chaque perte subie au tour ennemi a sa ligne dans le journal du tour ennemi
- [ ] Au début du tour du joueur qui suit une perte d'unité ou de nœud, la puce de perte est affichée, et un appui dessus centre la carte sur la perte
- [ ] Une unité blessée affiche sa jauge de PV sur la carte sans être sélectionnée

**Accessibility**
- [ ] Tout texte du HUD atteint 4,5:1 de contraste sur son fond (3:1 pour le texte de 24 pt et plus)
- [ ] Les icônes, contours et marqueurs de carte atteignent 3:1 de contraste contre la tuile ou le panneau en dessous (WCAG 2.1 SC 1.4.11)
- [ ] Avec la palette daltonienne activée, possession, factions, menaces et ruines restent distinctes dans un simulateur de protanopie et de deutéranopie
- [ ] Aucun effet (pulsation, éclatement, recoloration, tour ennemi) ne produit plus de 3 flashs par seconde
- [ ] Aucune information ne passe par la couleur seule (test : capture en niveaux de gris de chacun des 12 mockups, portrait et paysage)
- [ ] À 150% d'échelle de texte, aucun texte n'est coupé ni ne chevauche un autre élément
- [ ] La réduction des animations supprime toutes les animations de 10.3
- [ ] Les réglages de 10.5 fonctionnent et sont conservés d'une session à l'autre
- [ ] Chaque bouton et chaque puce tactile porte un nom accessible et un état (actif, désactivé) dans l'arbre d'interface
- [ ] *Conditionnel* — seulement si la prise en charge de TalkBack et VoiceOver par le moteur est confirmée (NOT SOURCEABLE à ce jour, voir `design/accessibility-requirements.md`) : le lecteur d'écran annonce chaque bouton, l'état désactivé et le titre du panneau de fragment

**Gestes et disposition**
- [ ] Une partie complète se joue sans pincement ni geste à plusieurs doigts, zoom compris
- [ ] Un appui qui glisse de moins d'une demi-tuile sélectionne la tuile au lieu de faire défiler la carte
- [ ] « Fin du tour » est à au moins 8 dp de tout autre élément tactile, dans chaque état et chaque orientation
- [ ] Avec « Panneau à gauche » activé en paysage, le rail et le panneau échangent leurs places sans qu'aucun élément ne se chevauche ni ne sorte des insets système

**Notifications**
- [ ] Les puces d'un même type se fusionnent en une seule avec un compteur
- [ ] Aucune notification de basse priorité n'apparaît pendant le tour ennemi
- [ ] Les intentions ennemies ne sont jamais masquées ni mises en file

**Evidence**
- [ ] Une capture d'écran retenue de chaque état de la section 5, en portrait et en paysage, est déposée dans `production/qa/evidence/`

---

## 13. Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Le HUD dépasse le budget de 45% (≈ 46% en portrait, ≈ 48% en paysage). Réduire le panneau d'unité, ou relever le budget ? | user + ux-designer | Avant `/ux-review` | **Résolu le 2026-10-29** : réduction. Stats en une ligne, rail paysage à 140 pt, panneau paysage à 224 pt, zone d'alerte repliée quand elle est vide ; budget distinct de 55% pour les états à commandes verrouillées (section 7) |
| Les libellés de stats en 10 pt en paysage passent sous le minimum de 12 pt. | ux-designer | Avant `/ux-review` | **Résolu le 2026-10-29** : les stats passent en une ligne de 12 pt |
| Les 6 mockups du canvas montrent encore l'ancienne mise en page (grille de stats, rail de 168 pt, panneau de 238 pt) et aucun ne montre le ciblage ni une perte. | ux-designer | Avant `/ux-review` | **Résolu le 2026-10-29** : les 6 mockups suivent la mise en page réduite ; ajout du ciblage, de la résolution d'une attaque et du début de tour après une perte (sans sélection), en portrait et en paysage |
| Le combat est-il déterministe ? L'aperçu de combat suppose que oui (comme dans Polytopia). Avec une part d'aléatoire, il faudrait afficher une fourchette. | game-designer | GDD de combat | |
| Un déplacement peut-il être annulé ? Un appui suffit pour se déplacer, ce qui rend un mauvais appui coûteux sur une tuile de 31 pt. | game-designer + ux-designer | GDD des unités | |
| Quelle couleur pour « énergie insuffisante », sans empiéter sur l'orange-rouge réservé aux menaces ? | art-director | `/art-bible` | **Résolu le 2026-10-30** : aucune teinte ; bouton désactivé « manque n » en gris clair (art bible, section 7) |
| Un appui sur la puce de menace centre-t-il la carte sur la cible ? Faut-il un mode qui affiche toutes les intentions ? | game-designer | GDD de l'IA | |
| Le panneau de fragment doit-il bloquer le tour (« Continuer » obligatoire) ou pouvoir être replié pour jouer ? | game-designer | GDD des ruines et fragments | |
| Le joueur peut-il passer entièrement le tour ennemi, ou seulement l'accélérer ? Pilier 4 demande que les intentions restent lisibles. | game-designer | GDD de l'IA | |
| Où afficher les protocoles et le niveau des nœuds dans le HUD ? Absents des mockups. | game-designer | GDD des protocoles et des nœuds | |
| Les noms des unités (« Éclaireur », « Gardien ») et le texte du fragment sont provisoires. | narrative-director | Après le signal 2 (5 testeurs extérieurs) | |
| Le motif de faction pour les daltoniens (antenne, emblème) reste à dessiner. | art-director | `/art-bible` | **Résolu le 2026-10-30** : chevron, deux barres, deux hexagones concentriques (art bible, section 3) ; dessin final avec les assets |
| Option de panneau à gauche en paysage pour les gauchers : à garder ? | ux-designer | Avant `/ux-review` | **Résolu le 2026-10-29** : gardée et engagée (élément Comprehensive de `design/accessibility-requirements.md`) |
| `design/accessibility-requirements.md` n'existe pas : le palier Standard est une proposition. | user | `/ux-design accessibility` | **Résolu le 2026-10-29** : palier Standard + 3 éléments Comprehensive engagé |
| Cibles de 44 pt contre les 48 dp recommandés sur Android. | user + ux-designer | Avant `/ux-review` | **Résolu le 2026-10-29** : zones tactiles étendues (48 dp Android, 44 pt iOS) au-delà du dessin quand il le faut ; mise en page et budget inchangés (section 7) |
| Mode contraste élevé : l'engager ou le retirer ? | user | Avant `/art-bible` | **Résolu le 2026-10-29** : retiré des réglages pour l'instant ; noté dans les limitations de `design/accessibility-requirements.md` |


---

> **Corrections du 2026-10-30 (GDD 17, `design/gdd/hud-systeme.md`)** : appliquées ici : tuile 36,33 pt, barre de chronique à N segments, pastille « n / 3 ruines », score décisif permanent, réveil 600 ms sans toast, affaissement à la place de l'éclatement, recoloration non optionnelle en animations réduites. **Appliquées aussi (deuxième passe)** : « Annuler le déplacement » distinct de l'aperçu, états de la carte (brouillard, nœud adverse et dormant mémorisés, intention hors de vue), puce de ruine sans chiffre, menace visible dès le début du tour du joueur, « Capturer » actif au moment de l'action, budget de 9 éléments, zone d'alerte à hauteur réservée. **Grappe de boutons** ajoutée aux §4.1 et §7. **Remesure du 2026-10-30** faite par le calcul (§7) ; **maquettes du canvas mises à jour** (score, grappe, puce de ruine sans chiffre, chronique à 5 segments, repère de 50 % des PV, territoire ennemi `#C49BEA`). **Restent à faire** : croix d'intention annulée (palier de lancement) ; mesure sur appareil (AC-HU35) ; durée d'une action ennemie (600 ms contre environ 1,45 s, à trancher au prototype).
