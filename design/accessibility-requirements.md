# Accessibility Requirements

> **Status**: Committed (palier engagé le 2026-10-29 ; sections à compléter au fil des GDD)
> **Author**: user + Claude (ux-designer role)
> **Last Updated**: 2026-10-29
> **Accessibility Tier Target**: Standard, avec trois éléments du palier Comprehensive (voir « This Project's Commitment »)
> **Platform(s)**: Android (d'abord), iOS (ensuite) — tactile uniquement
> **External Standards Targeted**:
> - WCAG 2.1 Level AA (contraste, taille et redimensionnement du texte)
> - AbleGamers / Game Accessibility Guidelines (référence de conception, pas de certification)
> - Xbox Accessibility Guidelines (XAG) : No — pas de version console prévue
> - PlayStation Accessibility (Sony Guidelines) : No — pas de version console prévue
> - Apple / Google Accessibility Guidelines : Partial — tailles de cibles tactiles et réglages système ; lecteur d'écran sous réserve (voir Platform Accessibility API Integration)
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/game-concept.md`, `design/ux/hud.md`. `design/gdd/systems-index.md` et `design/ux/interaction-patterns.md` n'existent pas encore.
> **Template**: Accessibility Requirements

> **Why this document exists** : les annotations par écran vont dans les UX specs. Ce
> document porte les engagements valables pour tout le projet, la matrice par système,
> le plan de test et l'historique des audits. Si une fonctionnalité contredit un
> engagement pris ici, ce document l'emporte : on change la fonctionnalité, pas
> l'engagement, sauf révision formelle approuvée par le producer.
>
> **When to update** : après chaque `/gate-check`, après chaque audit d'accessibilité, et
> à chaque ajout d'un système dans `design/gdd/systems-index.md`.

---

## Accessibility Tier Definition

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical player-facing text is readable at standard resolution. No feature requires color discrimination alone. Volume controls exist for music, SFX, and voice independently. The game is completable without photosensitivity risk. | Low — primarily design constraints |
| **Standard** | All of Basic, plus: full input remapping on all platforms, subtitle support with speaker identification, adjustable text size, at least one colorblind mode, and no timed input that cannot be extended or toggled. | Medium — requires dedicated implementation work |
| **Comprehensive** | All of Standard, plus: screen reader support for menus, mono audio option, difficulty assist modes, HUD element repositioning, reduced motion mode, and visual indicators for all gameplay-critical audio. | High — requires platform API integration and significant UI architecture |
| **Exemplary** | All of Comprehensive, plus: full subtitle customization (font, size, color, background, position), high contrast mode, cognitive load assist tools, tactile/haptic alternatives for all audio-only cues, and external third-party accessibility audit. | Very High — requires dedicated accessibility budget and specialist consultation |

### This Project's Commitment

**Target Tier**: **Standard**, plus three Comprehensive elements (listed below).

**Rationale** : *La Meute Orpheline* est une stratégie au tour par tour sur mobile, pour des
joueurs de 18 à 40 ans qui jouent souvent dans les transports, sans le son et d'une
main. Le tour par tour supprime les barrières motrices les plus lourdes (aucune
action en temps limité), mais la carte en tuiles repose sur la couleur (possession,
factions, menaces) et sur de petites cibles tactiles, ce qui crée des barrières
visuelles et de précision. Le palier Standard couvre ces barrières, et une bonne
partie est déjà prévue par `design/ux/hud.md` (doublure non colorée de chaque
signal, texte de 100 à 150%). Le palier Comprehensive complet n'est pas tenable en
solo, surtout parce que la prise en charge du lecteur d'écran sur mobile par le
moteur n'est pas établie (voir Platform Accessibility API Integration). Descendre à
Basic ferait perdre l'échelle du texte et la réduction des animations, dont le HUD
dépend déjà, et exclurait les joueurs daltoniens, soit environ 8% des hommes de la
cible.

**Ce que « Standard » veut dire sur un jeu tactile sans voix** :
- *Full input remapping* devient **des alternatives de geste** : aucune action n'exige
  un geste complexe (appui long, pincement, glissement à deux doigts) sans
  équivalent en un appui simple. Il n'y a pas de touches à réassigner.
- *Subtitle support* est **sans objet** : le jeu n'a ni voix ni dialogue (anti-pilier
  « pas de cinématiques ni de dialogues »). Les fragments sont du texte à l'écran et
  suivent les règles de texte.
- *At least one colorblind mode* : une **palette de faction alternative** adaptée aux
  daltonismes rouge-vert, en plus des doublures de forme déjà prévues.
- *No timed input* : aucun input n'est limité dans le temps ; aucun message portant
  une information à agir ne disparaît seul.

**Features explicitly in scope (beyond tier baseline)** :
- **Mode d'animations réduites** (Comprehensive) — déjà spécifié dans `design/ux/hud.md`
  § 10.3 ; il suit par défaut le réglage système quand le moteur peut le lire.
- **Équivalent visuel pour chaque son qui porte une information de jeu** (Comprehensive)
  — le jeu doit se jouer entièrement sans le son (pilier 3 et usage en transports).
- **Disposition paysage inversée** (partie du *HUD element repositioning*, Comprehensive)
  — rail et panneau échangés, pour les gauchers et l'usage à une main gauche.

**Features explicitly out of scope** (détail dans Known Intentional Limitations) :
- Repositionnement libre de chaque élément du HUD.
- Audio mono (le jeu n'a pas de son spatialisé qui porte une information).
- Personnalisation complète des sous-titres (sans objet, pas de voix).
- **Lecteur d'écran pour les menus** : objectif, **pas engagement**, tant que la prise en
  charge de TalkBack et VoiceOver par Godot n'est pas vérifiée (NOT SOURCEABLE).

---

## Visual Accessibility

Le jeu se lit sur un téléphone tenu à 30 cm, souvent en plein jour. Les deux risques
principaux sont la couleur (possession des tuiles, factions, menaces) et la petite
taille des tuiles et des textes en paysage.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Taille minimale du texte — HUD | Standard | HUD en partie | Not Started | 12 pt minimum à l'échelle 100% (règle de `design/ux/hud.md` § 7). Les chiffres critiques (tour, énergie) sont à 15 pt ou plus. |
| Taille minimale du texte — menus | Standard | Menus, écran de chronique, pause | Not Started | 14 pt minimum pour le texte courant, 12 pt pour les libellés secondaires. |
| Échelle du texte | Standard | Tout le texte | Not Started | 100% à 150% dans les réglages du jeu. Le jeu suit aussi la taille de police du système quand le moteur peut la lire (NOT SOURCEABLE, voir Platform). Aucun texte ne doit être coupé à 150% : défilement ou retour à la ligne. |
| Contraste du texte | Standard | Tout le texte | Not Started | 4,5:1 minimum (WCAG AA), 3:1 pour le texte de 24 pt et plus. Vérifié sur les vraies couleurs de fond, y compris le panneau papier des fragments. |
| Contraste des éléments non textuels | Standard | Icônes, contours, marqueurs de carte | Not Started | 3:1 minimum contre la tuile ou le panneau en dessous (WCAG 2.1 SC 1.4.11). |
| Palette daltonienne — Protanopie / Deutéranopie | Standard | Couleurs de faction, menace, ruines | Not Started | Une palette alternative unique couvre les deux. Les couleurs de faction sont déjà un réglage unique (tweak « factionColor » des mockups), ce qui rend le changement peu coûteux. L'orange-rouge de menace ne doit jamais servir seul (voir l'audit ci-dessous). Menace et ruines gardent leurs couleurs dans la palette alternative (art bible, section 4). |
| Palette daltonienne — Tritanopie | Standard | Mêmes éléments | Not Started | Estimation à la main dans l'art bible (section 4, « Tritanopie ») : seule paire à risque, F1 teal / F3 cobalt, doublée par le motif ; repli = lisière de F3 en trait double. L'ambre des PV bas est retiré (jauge blanche). À confirmer au simulateur ; pas de palette dédiée si les doublures suffisent. |
| Audit couleur-seule | Basic | Toute l'interface et la carte | Not Started | Tableau ci-dessous. Chaque ligne a une doublure non colorée avant la sortie. |
| Mode contraste élevé | Comprehensive | — | Out of scope | Retiré des réglages du HUD le 2026-10-29. Voir Known Intentional Limitations. |
| Luminosité / gamma | Basic | — | N/A | Rendu en aplats sans zones sombres critiques ; la luminosité est celle du téléphone. Le brouillard ne doit jamais cacher une information de jeu (règle de lecture : les ruines restent visibles sous le brouillard). |
| Flashs et clignotements | Basic | Effets visuels, recoloration, pulsations | Not Started | Pas plus de 3 flashs par seconde (seuil de Harding). Les pulsations (drone réveillé, cible choisie) restent lentes et à faible amplitude. Pas d'écran d'avertissement prévu si l'audit ne trouve aucun effet à risque. |
| Animations réduites | Comprehensive (engagé) | Toutes les animations du HUD et de la carte | Not Started | Liste complète dans `design/ux/hud.md` § 10.3. Le jeu reste entièrement lisible quand toutes les animations sont coupées. |
| Taille des tuiles | Standard (projet) | Carte | Not Started | 31 pt minimum au zoom le plus éloigné ; zoom jusqu'à 2× disponible sans geste à deux doigts (voir Motor). |

### Color-as-Only-Indicator Audit

Repris de `design/ux/hud.md` § 10.1 ; toute nouvelle couleur porteuse de sens s'ajoute ici.

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| Tuiles de la carte | Gris contre couleur de faction | Possession | Motif de faction sur les nœuds et les unités (à dessiner dans l'art bible) ; changement de saturation, pas seulement de teinte | Not Started |
| Unités | Teinte de faction | Unité du joueur ou ennemie | Silhouettes différentes : hexagone (joueur), losange (ennemi) | Designed (mockups) |
| Menace annoncée | Orange-rouge | Une attaque frappera cette tuile au prochain tour | Hachuré à 135° et pastille « ! » ; texte dans la puce | Designed (mockups) |
| Ruine | Ocre et lueur sépia | Lieu narratif à atteindre | Glyphe en arche brisée | Designed (mockups) |
| Attaque esquivée | Blanc contourné | L'attaque annoncée n'a pas eu lieu | Coche ✓ et texte | Designed (mockups) |
| Intention annulée | Orange | Plus de menace sur cette tuile | Croix × sur la tuile | Designed (mockups) |
| Cible d'attaque | Blanc | Unité ennemie attaquable | Crochets d'angle (forme) | Designed (mockups) |
| PV bas | Blanc (aucune teinte) | Unité à moins de la moitié de ses PV | Longueur de la jauge, repère fixe à 50 % ; valeur dans le panneau | Designed (mockups) |
| Perte | Gris | Unité, nœud ou tuile perdus | Glyphe de débris ; liseré en pointillés ; texte dans la puce et le journal | Designed (mockups) |
| Énergie insuffisante | À choisir | Action trop chère | Coût affiché en chiffres sur le bouton ; bouton désactivé | Open (couleur non choisie) |
| Tour ennemi | Teinte violette | Les commandes sont verrouillées | Étiquette « Tour ennemi » et journal | Designed (mockups) |

---

## Motor Accessibility

Le jeu se joue au doigt sur un petit écran, souvent d'une main dans les transports.
Il n'y a ni manette ni clavier à prendre en charge. Les risques sont la précision
(petites tuiles, tremblements) et les gestes complexes.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Taille des cibles tactiles | Standard | Tous les éléments interactifs | Not Started | **48 × 48 dp sur Android, 44 × 44 pt sur iOS** (recommandations de Google et d'Apple). Il s'agit de la zone qui réagit à l'appui : elle peut déborder du dessin de l'élément (puces d'alerte, bouton pause, boutons d'action en paysage), ce qui garde la mise en page du HUD (décision du 2026-10-29, `design/ux/hud.md` § 7). |
| Alternatives de geste | Standard (remplace le remappage) | Toute la partie | Not Started | Tout se joue avec des appuis simples. Le pincement pour zoomer a un équivalent en boutons ou en double appui. L'appui long n'est jamais le seul accès à une information (la phrase d'une unité est déjà dans le panneau). Pas de geste à plusieurs doigts obligatoire. |
| Protection contre l'appui involontaire | Standard (projet) | Attaque, fin de tour, actions coûteuses | Not Started | Une attaque se confirme toujours (`design/ux/hud.md`). « Fin du tour » est à au moins 8 dp de tout autre bouton. Le déplacement en un appui reste une question ouverte (annulation). |
| Tolérance au glissement du doigt | Standard (projet) | Carte | Not Started | Un appui qui glisse de moins d'une demi-tuile reste un appui, pas un défilement de la carte. Seuil à régler en test. |
| Pas d'appui maintenu obligatoire | Standard | Toute la partie | Not Started | Aucun « maintenir pour… ». Si un appui long existe (aperçu d'unité), il a un équivalent en appui simple. |
| Pas d'input en temps limité | Standard | Toute la partie | Designed | Jeu au tour par tour, sans minuterie. Le tour ennemi se joue sans action du joueur, et peut être accéléré ou rejoué. |
| Pas d'input rapide | Standard | Toute la partie | Designed | Aucune répétition rapide d'appuis. |
| Disposition paysage inversée | Comprehensive (engagé) | HUD en paysage | Not Started | Option « Panneau à gauche » de `design/ux/hud.md` § 10.5 : rail et panneau échangés, pour les gauchers. |
| Usage à une main en portrait | Standard (projet) | HUD en portrait | Not Started | Les boutons d'action et « Fin du tour » sont dans le tiers bas de l'écran. La sélection d'une tuile en haut de la carte demande de faire défiler la carte vers le bas ; aucune action ne demande d'atteindre le haut de l'écran. |
| Repositionnement libre du HUD | Comprehensive | — | Out of scope | Voir Known Intentional Limitations. |

---

## Cognitive Accessibility

Un 4X demande de suivre beaucoup d'informations à la fois. Le pilier 3 (« Lisible
comme Polytopia ») est déjà une exigence cognitive : une unité ou un protocole
s'explique en une phrase.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Pause partout | Basic | Tous les états de jeu | Not Started | Pause possible pendant le tour du joueur, le tour ennemi, le panneau de fragment et la résolution d'une attaque. Une mise en arrière-plan de l'application met en pause et sauvegarde. |
| Sauvegarde automatique | Standard (projet) | Toute la partie | Not Started | Fin de chaque tour et mise en pause (`technical-preferences.md`). Un joueur interrompu ne perd rien et reprend dans le même état. |
| Règles toujours consultables | Standard | Unités, protocoles, règles de base | Not Started | Une section « Aide » dans le menu pause reprend la phrase de chaque unité et de chaque protocole, et les règles de base (menaces annoncées, riposte, ruines). Les explications vues une fois restent consultables. |
| Objectif clair | Standard | Partie | Not Started | L'objectif (domination ou score au 30e tour) et le score en cours sont visibles depuis le menu pause, en un appui. |
| Résultat connu avant d'agir | Standard (projet) | Combat | Designed | Aperçu de combat obligatoire avant toute attaque (`design/ux/hud.md`). |
| Menaces annoncées et lisibles | Standard (projet) | IA ennemie | Designed | Pilier 4 : toute perte annoncée peut être évitée ; les intentions ne sont jamais masquées. |
| Temps de lecture | Standard | Tous les messages | Not Started | Aucun message portant une information à agir ne disparaît seul. Les chiffres de dégâts (800 ms) disparaissent, mais l'information reste dans les jauges de PV et le journal. Le panneau de fragment attend « Continuer ». |
| Niveaux de difficulté | Standard | IA | Not Started | 3 niveaux (concept). Le concept fixe une IA « juste mais dure » (pilier 4) : la difficulté change l'agressivité de l'IA, jamais la lisibilité des menaces. Les paramètres ajustables restent à lister dans le GDD de l'IA. |
| Charge cognitive par système | Comprehensive | Par système | NOT ASSESSED | Pas encore de `systems-index.md`. Voir la matrice ci-dessous, provisoire. |
| Aides à la navigation | Standard | Carte | Not Started | Appui sur une puce (menace, ruine, perte) = la carte se centre sur l'élément (`design/ux/hud.md`). |
| Fragments et texte narratif | Standard (projet) | Panneau de fragment, chronique | Not Started | Textes courts, police serif lisible à 15 pt minimum, retour à la ligne à 150%. Pas de texte animé lettre par lettre. |

---

## Auditory Accessibility

Le jeu n'a pas de voix. Les joueurs jouent souvent sans le son, dans les transports :
le son ne porte jamais seul une information de jeu.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Sous-titres des dialogues | Basic | — | N/A | Pas de voix ni de dialogue. |
| Volumes indépendants | Basic | Musique / effets / interface | Not Started | Trois curseurs (pas de bus voix). 0–100%, conservés d'une session à l'autre, accessibles depuis le menu pause. |
| Équivalent visuel de chaque son de jeu | Comprehensive (engagé) | Tous les sons qui changent ce que le joueur doit faire | Not Started | Tableau ci-dessous. Le jeu se joue entièrement son coupé. |
| Audio mono | Comprehensive | — | Out of scope | Pas de son spatialisé porteur d'information. |
| Indicateurs pour le son directionnel | Comprehensive | — | N/A | Pas de son directionnel ; les menaces hors écran ont déjà la puce de menace. |
| Sons graves / aigus | Standard | Sons de jeu | Not Started | Aucune information portée seulement par un son aigu (au-dessus de 4 kHz) ; de toute façon chaque son a un équivalent visuel. |
| Retour haptique | Exemplary | — | Optional | Vibration courte possible au réveil d'un drone ou à une perte, désactivable. Jamais seul canal d'une information. |

### Gameplay-Critical SFX Audit

Aucun son n'est encore conçu ; ces lignes sont les sons attendus d'après `design/ux/hud.md`.
À compléter quand la direction sonore existera.

| Sound Effect | What It Communicates | Visual Backup | Caption Required | Status |
|-------------|---------------------|--------------|-----------------|--------|
| Intention ennemie annoncée | Une attaque frappera au prochain tour | Hachuré + « ! » sur la tuile ; puce de menace | No — visual is sufficient | Not Started |
| Début du tour ennemi | Commandes verrouillées | Étiquette « Tour ennemi », teinte violette | No | Not Started |
| Unité du joueur touchée | Perte de PV | Chiffre de dégâts, jauge de PV | No | Not Started |
| Unité du joueur détruite | Perte d'une unité | Débris, puce de perte, ligne du journal | No | Not Started |
| Nœud perdu | Perte de territoire | Désaturation, puce de perte, journal | No | Not Started |
| Drone réveillé | Nouvelle unité | Pulsation et nouvelle unité sur la carte | No | Not Started |
| Ruine lue / fragment trouvé | Nouveau fragment | Recoloration, panneau de fragment | No | Not Started |
| Derniers tours | Fin de partie proche | Chiffre en blanc plein 700, contour blanc de 2 pt sur la barre, puce « DERNIERS TOURS » | No | Not Started |

---

## Platform Accessibility API Integration

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| Android | AccessibilityService / TalkBack | Annonce des boutons et menus (objectif, non engagé) ; respect de la taille de police et de « Supprimer les animations » du système | NOT SOURCEABLE | `docs/engine-reference/godot/` indique que les Control nodes de Godot 4.5+ fonctionnent avec les lecteurs d'écran via AccessKit (`modules/ui.md`, `current-best-practices.md`), mais ne dit pas si AccessKit est relié à TalkBack sur Android, ni si le moteur expose la taille de police ou le réglage d'animations du système. À vérifier avant de s'engager. |
| iOS | UIAccessibility / VoiceOver | Mêmes objectifs ; respect de « Réduire les animations » et de la taille de texte dynamique | NOT SOURCEABLE | Même lacune que pour Android. Export iOS prévu plus tard. |
| PC (Screen Reader) | — | — | N/A | Pas de version PC prévue. |
| Xbox / PlayStation / Steam | — | — | N/A | Pas de version prévue. |

**Conséquence sur le palier** : tant que ces deux lignes sont NOT SOURCEABLE, le lecteur
d'écran reste hors engagement, et le réglage « animations réduites » doit exister **dans
le jeu** (il ne peut pas compter sur le réglage système seul).

---

## Per-Feature Accessibility Matrix

> **Provisoire — NOT ASSESSED.** `design/gdd/systems-index.md` n'existe pas encore.
> Les lignes ci-dessous viennent des Core Mechanics de `design/gdd/game-concept.md` ;
> elles seront remplacées par la liste de `/map-systems`, et chaque nouveau système
> ajoutera sa ligne. Aucun système ne peut être marqué Approved avec une case non traitée.

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| Carte en tuiles et brouillard | Possession par la couleur ; petites tuiles en paysage | Précision des appuis ; pincement pour zoomer | Lire l'état de 80 à 120 tuiles | Aucune | Partial | Doublures de forme et de saturation ; zoom sans pincement à spécifier |
| Énergie et nœuds | Couleur « énergie insuffisante » non choisie | Aucune | Suivre le stock et le revenu | Aucune | Partial | Coût en chiffres sur les boutons |
| Unités et combat | PV bas (jauge blanche) ; cibles | Confirmation des attaques | Dégâts, riposte, portée | Sons de coup | Partial | Aperçu de combat obligatoire ; jauges ; chiffres |
| IA à intentions | Menaces en orange-rouge | Aucune (le joueur n'agit pas pendant le tour ennemi) | Retenir les menaces d'un tour à l'autre | Son d'annonce | Partial | Hachuré + « ! » ; puce ; journal ; menaces jamais masquées |
| Arbre de protocoles | Non conçu | Non conçu | 10 à 12 protocoles | Non conçu | Not Started | Une phrase par protocole (pilier 3) |
| Ruines, fragments et chronique | Panneau papier : contraste du texte serif | Aucune | Lecture de textes narratifs | Son de découverte | Partial | Pas d'effacement automatique ; échelle de texte |

---

## Accessibility Test Plan

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---------|------------|------------|--------------|-------------|--------|
| Contraste du texte | Automatisé — analyseur de contraste sur des captures de chaque état du HUD et de chaque menu | Tous les couples texte / fond, y compris le panneau papier et le tour ennemi violet | Texte courant ≥ 4,5:1 ; texte ≥ 24 pt ≥ 3:1 ; éléments non textuels ≥ 3:1 | ux-designer | Not Started |
| Couleur-seule | Manuel — captures en niveaux de gris et simulateur (Coblis) en protanopie, deutéranopie, tritanopie | Les 12 mockups du HUD, puis les captures de la vraie partie | Chaque information de l'audit couleur-seule reste lisible dans chaque mode | ux-designer | Not Started |
| Palette daltonienne | Manuel — palette alternative activée, simulateur | Partie complète sur la carte de test | Possession, factions et menaces distinctes sans aide | ux-designer | Not Started |
| Échelle du texte | Manuel — 100%, 125%, 150%, sur le plus petit écran visé (360 dp de large) | Tous les états de `design/ux/hud.md` § 5, tous les menus | Aucun texte coupé ni chevauchant | qa-tester | Not Started |
| Cibles tactiles | Manuel — mesure sur appareil | Tous les éléments interactifs | ≥ 48 dp sur Android, ≥ 44 pt sur iOS | qa-tester | Not Started |
| Gestes | Manuel — partie complète sans pincement ni appui long | Partie de 30 tours | La partie se joue entièrement en appuis simples | qa-tester | Not Started |
| Son coupé | Manuel — partie complète, son coupé | Partie de 30 tours | Le joueur ne manque aucune menace, perte ni découverte | qa-tester | Not Started |
| Animations réduites | Manuel — réglage activé | Tous les éléments de `design/ux/hud.md` § 10.3 | Aucune animation listée ne joue ; le jeu reste lisible | ux-designer | Not Started |
| Flashs | Manuel — revue image par image des effets | Recoloration, éclatement, pulsations, tour ennemi | ≤ 3 flashs par seconde | ux-designer | Not Started |
| Lecteur d'écran (objectif) | Manuel — TalkBack, puis VoiceOver | Menus, boutons du HUD | Chaque bouton a un nom et un état annoncés | ux-designer | NOT ASSESSED (prise en charge moteur non vérifiée) |
| Tests utilisateurs — daltonisme | Tests avec des joueurs daltoniens | Partie complète | Aucune demande d'aide sur les couleurs | producer | Not Started |
| Tests utilisateurs — une main | Tests en portrait, une seule main | Partie complète | Partie terminée sans changer de main | producer | Not Started |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Lecteur d'écran pour les menus (engagement) | Comprehensive | Prise en charge de TalkBack et VoiceOver par Godot non vérifiée (NOT SOURCEABLE) | Les joueurs aveugles ou malvoyants ne peuvent pas naviguer dans les menus | Garder les noms accessibles sur chaque bouton dès le départ ; vérifier le moteur avant la production (Open Questions) |
| Lecteur d'écran pour la carte | Exemplary | Une carte de 80 à 120 tuiles ne se décrit pas par un lecteur d'écran standard | Le jeu n'est pas jouable sans la vue | Aucune pour le lancement ; à réévaluer après la sortie |
| Repositionnement libre du HUD | Comprehensive | Mise en page optimisée pour un écran de téléphone ; coût élevé en solo | Les joueurs ayant une couverture visuelle réduite ne peuvent pas rapprocher les éléments | Disposition paysage inversée (engagée) |
| Audio mono | Comprehensive | Pas de son spatialisé porteur d'information | Faible | Chaque son a un équivalent visuel |
| Mode contraste élevé | Comprehensive | Retiré le 2026-10-29 : demande des variantes de chaque élément dans l'art bible, coût élevé en solo | Joueurs malvoyants, et lecture en plein soleil | Contraste AA partout ; éléments non textuels à 3:1 ; palette daltonienne ; à réévaluer après les tests utilisateurs |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| 2026-10-29 | Internal — `/ux-review` | Revue de spec | `design/ux/hud.md` | Doublures non colorées pour chaque signal ; animations réduites listées ; palier non engagé à ce moment (NOT ASSESSED), engagé depuis par ce document | Closed |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 (Web Content Accessibility Guidelines) | https://www.w3.org/TR/WCAG21/ | Contraste, taille et redimensionnement du texte |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Liste de référence par catégorie et par coût |
| AbleGamers Player Panel | https://ablegamers.org/player-panel/ | Tests avec des joueurs en situation de handicap |
| Colour Blindness Simulator (Coblis) | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Simulation du daltonisme sur des captures |
| Accessible Games Database | https://accessible.games | Exemples de choix de conception accessibles |
| Android — Accessibility (tailles de cibles, TalkBack) | https://developer.android.com/guide/topics/ui/accessibility | Cibles de 48 dp, lecteur d'écran |
| Apple — Human Interface Guidelines, Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility | Cibles de 44 pt, VoiceOver, réduction des animations |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Godot (version installée, 4.7 visée) relie-t-il AccessKit à TalkBack sur Android et à VoiceOver sur iOS ? Expose-t-il la taille de police et le réglage d'animations du système ? Non couvert par `docs/engine-reference/godot/`. | godot-specialist | Avant le gate Technical Setup → Pre-Production | |
| Les mockups et `design/ux/hud.md` utilisent des cibles de 44 px ; Android recommande 48 dp. Passer le HUD à 48 dp, ou accepter 44 sur Android ? | ux-designer | Avant `/ux-review` suivant | **Résolu le 2026-10-29** : zones tactiles étendues au-delà du dessin (48 dp Android, 44 pt iOS) ; mise en page inchangée |
| Le mode contraste élevé est listé dans `design/ux/hud.md` § 10.5 mais non engagé ici. L'engager, ou le retirer du HUD ? | user | Avant `/art-bible` | **Résolu le 2026-10-29** : retiré du HUD ; dans Known Intentional Limitations |
| Quelle palette alternative pour les daltoniens ? Dépend des couleurs de faction de l'art bible. | art-director | `/art-bible` | **Résolu le 2026-10-30** : azur #3A8EE6, jaune pâle #F0DC6E, gris #5F6266 ; menace et ruines inchangées (art bible, section 4) |
| Le déplacement en un appui peut-il être annulé ? (Protection contre l'appui involontaire.) | game-designer | GDD des unités | |
| Zoom sans pincement : boutons +/− ou double appui ? | ux-designer | Pattern library | |
| Aucune carte du parcours joueur (`design/player-journey.md`) : le contexte d'usage (transports, une main, son coupé) vient du concept. À écrire depuis `.claude/docs/templates/player-journey.md`. | user | Avant les specs d'écran suivantes | |
