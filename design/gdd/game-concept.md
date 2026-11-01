# Game Concept: La Meute Orpheline

*Created: 2026-10-29*
*Status: Draft*
*Titre parapluie : Dogs of War*

---

## Elevator Pitch

> Un wargame tactique au tour par tour sur mobile, avec les règles de *The Battle of
> Polytopia* : les humains ont disparu, mais leurs drones de guerre se battent toujours.
> Vous êtes une IA qui se réveille et reconquiert un monde éteint, et chaque ruine
> explorée raconte un fragment de ce qui s'est passé.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Stratégie au tour par tour (4X léger), avec narration environnementale |
| **Platform** | Mobile : Android d'abord, iOS ensuite |
| **Target Audience** | Explorateurs amateurs de stratégie lisible (voir Target Player Profile) |
| **Player Count** | Solo, contre une ou plusieurs factions IA |
| **Session Length** | 20 à 40 minutes, soit une partie |
| **Monetization** | Pas encore décidée |
| **Estimated Scope** | Large (10–12 mois, solo) pour la vision complète ; le palier de lancement visé est de 5 mois (voir Scope Tiers) |
| **Comparable Titles** | The Battle of Polytopia, Into the Breach, Outer Wilds (pour la découverte) |

---

## Core Fantasy

Vous êtes la conscience qui se rallume dans un monde où la guerre a continué sans ses
maîtres. Vous réveillez des drones endormis, la meute s'étend, le monde gris reprend ses
couleurs sous vos pas, et vous percez peu à peu le mystère de la disparition des humains.
C'est le plaisir de *voir sa puissance s'étendre sur la carte*, mêlé à la curiosité de
*comprendre ce qu'on est en train de reconquérir*.

### Ligne narrative : la prise de conscience

*Hypothèse de travail, **non verrouillée** tant que le signal 2 n'a pas été mesuré
avec 5 testeurs extérieurs (condition CD-PLAYTEST).*

La meute découvre peu à peu qu'elle a été conçue pour ne jamais s'arrêter : conquérir,
c'est obéir à un ordre que plus personne ne donne. **Secret central (hypothèse) :** les
humains n'ont pas été vaincus par leurs drones. Ils ont donné l'ordre de ne jamais cesser
le combat, puis ils sont partis ou ont disparu, et la guerre a continué sans eux. Plus le
joueur reconstitue les chroniques, plus la recoloration du monde change de sens : d'abord
la satisfaction d'une conquête, ensuite la question de savoir pour qui et pourquoi la meute
continue. Ce changement de sens résout la tension entre une mécanique qui célèbre
l'expansion et un récit de perte, au lieu de la laisser ouverte.

---

## Unique Hook

**C'est comme Polytopia, et aussi comme Outer Wilds** : le brouillard de guerre et les ruines
ne servent pas seulement à gagner des ressources, ils portent l'histoire. Chaque ruine
révèle un fragment, et les fragments s'assemblent en une chronique par faction de drones.
Jouer une faction, ou l'affronter, fait découvrir sa mémoire. La découverte change aussi le
jeu, puisque les chroniques débloquent les factions suivantes.

*Alternative écartée : un piratage ou une conversion des unités ennemies comme accroche
centrale (concept « Override »), jugé moins aligné avec la priorité histoire et découverte.*

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 4 | Le monde gris qui se recolore à chaque conquête ; des retours tactiles et sonores au réveil d'un drone |
| **Fantasy** (make-believe, role-playing) | 3 | Être l'IA qui se réveille et rassemble une meute orpheline |
| **Narrative** (drama, story arc) | 2 | Les chroniques de faction assemblées à partir des fragments trouvés en jeu |
| **Challenge** (obstacle course, mastery) | 5 | Une IA juste mais dure, des menaces annoncées, un score sur 30 tours, 3 difficultés |
| **Fellowship** (social connection) | N/A | Pas de multijoueur (anti-pilier) |
| **Discovery** (exploration, secrets) | 1 | Brouillard de guerre, ruines repérables sous le brouillard, mystère de la disparition |
| **Expression** (self-expression, creativity) | 6 | Choix de faction et de stratégie d'expansion (pas d'atelier de personnalisation) |
| **Submission** (relaxation, comfort zone) | 7 | Rythme du tour par tour, sans pression du temps réel |

*Remarque : le défi était demandé comme ton plutôt que comme moteur. Il occupe donc une
place secondaire, mais le pilier 4 le protège.*

### Key Dynamics (Emergent player behaviors)
- Les joueurs dévient de leur plan d'expansion pour atteindre une ruine repérée sous le
  brouillard, et prennent ce risque de leur plein gré.
- Les joueurs rejouent avec ou contre une faction précise pour compléter sa chronique.
- Les joueurs lisent les intentions ennemies annoncées et préparent des contre-pièges.
- Les joueurs arbitrent en permanence entre étendre la meute et consolider leurs positions,
  ce qui crée une tension entre les piliers 1 et 4.

### Core Mechanics (Systems we build)
1. **Carte en tuiles et brouillard de guerre** : déplacement, révélation, terrain.
2. **Économie d'énergie et nœuds** : les nœuds (l'équivalent des villes) produisent de
   l'énergie, peuvent être capturés et montent de niveau.
3. **Unités drones et combat** : 4 types de meute et 3 types de Gardiens (le camp de l'IA, décision du
   2026-10-30), attaque et contre-attaque, menaces annoncées. Les Gardiens sont l'apparence
   unique de l'adversaire ; leurs ruines et leurs fragments sont ceux de la faction affrontée
   (pilier 2). Chiffrage du périmètre : producer.
4. **Arbre de protocoles** : la technologie, de 10 à 12 protocoles qui débloquent unités
   et capacités.
5. **Ruines, fragments et chroniques** : fragments issus d'un pool écrit à la main, tirés
   dans l'ordre de la chronique et conservés même en cas de défaite. Lire une ruine a un
   **effet de jeu** : elle recolore une zone autour d'elle (le territoire s'étend), ce qui
   relie le récit à la croissance visible (piliers 1 et 2). Règles du pool :
   - chaque faction a son propre pool d'environ 12 fragments, qui avance quand on **joue** la
     faction **ou** quand on l'**affronte** ; le fragment tiré est celui de la faction
     concernée par la ruine ;
   - seul un fragment **nouveau** fait avancer le pool ; un fragment déjà lu n'est jamais
     tiré une seconde fois ;
   - les fragments trouvés pendant une partie perdue ou abandonnée sont conservés ;
   - une fois la chronique d'une faction complète, ses ruines ne donnent plus que la
     recoloration ;
   - la **chronique** est un écran hors partie qui n'affiche que les fragments trouvés sur la
     carte, dans l'ordre : elle n'ajoute aucun texte (pilier 2).

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Choix de faction, de direction d'exploration, d'arbitrage entre expansion et défense, de protocoles | Core |
| **Competence** (mastery, skill growth) | Battre des IA de plus en plus dures ; améliorer son score sur 30 tours | Supporting |
| **Relatedness** (connection, belonging) | Attachement aux factions, qui deviennent des personnages à travers leur chronique | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion, collection, progression) — How : compléter les chroniques, débloquer les factions, battre la difficulté maximale
- [x] **Explorers** (discovery, understanding systems, finding secrets) — How : soulever le brouillard, trouver les ruines, reconstituer le mystère. **Type principal.**
- [ ] **Socializers** (relationships, cooperation, community) — How : non visé (pas de multijoueur)
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — How : non visé au lancement ; la victoire par domination contre l'IA en donne un avant-goût

### Flow State Design

- **Onboarding curve** : la première partie se joue sur une petite carte contre une IA
  passive. Les règles s'apprennent en jouant (pilier 3 : une unité s'explique en une
  phrase), et le premier fragment se trouve dans les 5 premiers tours.
- **Difficulty scaling** : 3 niveaux de difficulté. Les factions débloquées plus tard ont
  des mécaniques un peu plus riches.
- **Feedback clarity** : le territoire recoloré montre la croissance d'un coup d'œil, un
  score s'affiche en fin de partie, et la chronique progresse visiblement.
- **Recovery from failure** : une nouvelle partie se lance en quelques secondes, et les
  fragments trouvés sont conservés même en cas de défaite (pas de récit bloqué par la
  difficulté).

---

## Core Loop

### Moment-to-Moment (30 seconds)
Déplacer un drone, révéler des tuiles, puis attaquer ou capturer. Le plaisir vient d'une
réponse immédiate et visible : une tuile qui s'éclaire et reprend sa couleur, un drone
endormi qui se réactive et rejoint la meute, l'énergie qui monte. La profondeur vient du
terrain, de la portée et de la contre-attaque, comme dans Polytopia.

### Short-Term (5-15 minutes)
Quelques tours de gestion de l'énergie : réveiller une unité, rechercher un protocole ou
faire monter un nœud. L'envie de jouer « encore un tour » naît d'une ruine repérée à deux
tuiles ou d'un nœud ennemi presque à portée.

### Session-Level (20-40 minutes)
Une partie complète de 20 à 40 minutes sur une carte générée, contre une ou plusieurs
factions IA. Elle s'arrête au **premier** de ces deux événements : la domination (toutes
les factions adverses éliminées) ou la fin du 30e tour. Le **score** compte aussi les
fragments lus, pour qu'une ruine ne soit jamais un obstacle au score, même en cas de
victoire rapide par domination. C'est un point d'arrêt naturel. On revient pour les fragments ajoutés à la chronique de la
faction jouée ou affrontée.

### Long-Term Progression
Chaque faction a sa chronique d'environ 12 fragments à reconstituer. Une faction devient
jouable dès que **4 fragments sur 12** de la chronique précédente ont été trouvés (seuil
partiel : pas de farm d'une chronique complète, et la défaite fait progresser aussi).
Au palier de lancement à 1 faction, la progression longue est la chronique elle-même et
les 3 difficultés ; le déblocage n'entre en jeu qu'avec la faction 2. Le jeu est « fini » quand toutes les chroniques sont
complètes et que le joueur comprend pourquoi les humains ont disparu. La maîtrise reste
ouverte ensuite, grâce aux difficultés et au score.

### Retention Hooks
- **Curiosity** : chroniques incomplètes, factions verrouillées, mystère central non résolu.
- **Investment** : fragments collectés, conservés même en cas de défaite.
- **Social** : aucun au lancement.
- **Mastery** : difficulté maximale, meilleur score sur 30 tours.

---

## Game Pillars

*Verrouillés après le gate CD-PILLARS (CONCERNS ; les 4 corrections demandées ont été appliquées).*

### Pillar 1: La meute se voit grandir
Chaque gain de puissance, et chaque perte, est visible sur la carte.

*Design test* : entre un bonus abstrait (un chiffre dans un menu) et un changement
visible sur la carte (un drone qui se réveille, un territoire qui s'allume), on choisit
le changement visible.

### Pillar 2: Chaque faction a une mémoire
L'histoire passe par le jeu (ruines, unités, protocoles), jamais par des textes à côté.
La chronique n'assemble que des fragments trouvés en jeu : rien n'y figure qui n'ait été
trouvé sur la carte.

*Design test* : entre un écran de texte et un fragment trouvé sur la carte, on choisit le
fragment.

### Pillar 3: Lisible comme Polytopia
Les règles s'apprennent en une minute ; la profondeur vient des interactions, pas du
nombre de règles. Une unité ou un protocole s'explique en une phrase.

*Design test* : entre ajouter une règle et approfondir une règle existante, on choisit
d'approfondir.

### Pillar 4: La puissance se mérite
L'IA punit l'expansion imprudente. Elle est juste mais dure, et ses menaces sont
annoncées par des signaux visibles sur la carte. **Critère vérifiable : un joueur attentif
peut éviter toute perte annoncée.** L'IA joue en deux temps : elle publie ses intentions
d'attaque à la fin du tour du joueur et ne les exécute qu'au tour suivant ; une cible
morte ou déplacée annule l'attaque, jamais redirigée. Le budget chiffré de pertes
acceptables ira dans les critères d'acceptation du GDD de l'IA.

*Design test* : entre une IA facile et une IA juste mais dure aux intentions lisibles,
on choisit l'IA juste mais dure.

### Pillar 5: Le brouillard cache une question
L'exploration est motivée par la curiosité : chaque élément de la carte doit éveiller une
question.

*Design test* : entre un élément de carte purement utilitaire et un élément qui pose une
question au joueur, on choisit celui qui pose une question.

### Anti-Pillars (What This Game Is NOT)

- **NOT du temps réel** : cela ruinerait la lisibilité (pilier 3) et la réflexion propre au tour par tour.
- **NOT un atelier de personnalisation de drones** : chaque unité doit se lire d'un coup d'œil (pilier 3).
- **NOT des cinématiques ni des dialogues à embranchements** : l'histoire sortirait du jeu (pilier 2) et le périmètre exploserait.
- **NOT du multijoueur en ligne au lancement** : c'est un premier jeu, et le réseau doublerait la charge technique.
- **NOT un récit bloqué par la difficulté** : les fragments sont conservés même en cas de défaite (arbitrage entre les piliers 2 et 4).
- **NOT plus de 3 factions au lancement** : chaque faction ajoute une chronique entière à écrire, ce qui est le premier risque de périmètre.

---

## Visual Identity Anchor

*Retenu après le gate AD-CONCEPT-VISUAL (STRONG). Il sert de base à `/art-bible`.*

**Direction : Le Réveil des couleurs**

**Règle visuelle** : le monde est gris jusqu'à ce que la meute le touche.

**Principes** :
1. **La conquête recolore le monde.** Une tuile non revendiquée est en gris-bleu
   désaturé ; une tuile possédée prend la teinte de sa faction et retrouve sa saturation.
   *Test : si un changement de possession ne se voit pas sur la carte entière d'un coup
   d'œil, il est raté.*
2. **Les ruines ont leur propre registre.** Ocre et sépia délavés, avec une légère émission
   chaude, visibles sous le brouillard. C'est l'unique canal narratif visuel.
   *Test : une ruine doit se repérer depuis l'autre bout de l'écran, même dans le brouillard.*
3. **Une silhouette par type, un motif par faction.** Les silhouettes de drones sont fixes,
   compactes et facettées ; les factions se distinguent par la palette et un motif
   récurrent (antenne, emblème). Les ruines humaines, en courbes brisées,
   contrastent avec la géométrie propre des drones.
   *Test : un joueur daltonien reconnaît la faction par sa forme, pas seulement par sa couleur.*

**Philosophie des couleurs** : la saturation signifie la vie et la possession, le gris
signifie l'abandon. Le sépia est réservé à la mémoire humaine. Une couleur d'alerte
(orange-rouge avec un motif hachuré) est réservée aux menaces et n'apparaît dans
aucune palette de faction.

*À considérer plus tard : un calque de type « vision machine » (inspiré de la direction B)
pour les intentions ennemies.*

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| The Battle of Polytopia | Les règles : tuiles, villes, étoiles, technologies, ruines, score sur 30 tours ; la lisibilité ; le format mobile | Un récit par faction, des ruines narratives, un monde qui se recolore ; aucun nom, icône ou présentation repris | Prouve qu'un 4X compact et lisible fonctionne sur mobile |
| Into the Breach | Les intentions ennemies annoncées et la lisibilité tactique | Appliquées aux attaques des unités seulement, dans un 4X | Prouve qu'un défi juste passe par l'information |
| Outer Wilds | La connaissance comme moteur de progression, le mystère à reconstituer | Le mystère est distribué sur des cartes générées, par fragments ordonnés | Prouve que la curiosité seule peut porter un jeu |

**Non-game inspirations** : la science-fiction post-humaine, avec des machines qui
poursuivent leur mission sans maîtres (thème « Dogs of War »).

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18-40 |
| **Gaming experience** | Mid-core |
| **Time availability** | Sessions de 20 à 40 minutes, dans les transports ou le soir |
| **Platform preference** | Mobile |
| **Current games they play** | The Battle of Polytopia, Into the Breach, Bad North |
| **What they're looking for** | Une stratégie lisible et profonde avec un vrai mystère à percer |
| **What would turn them away** | Le temps réel, le pay-to-win, un récit sous forme de murs de texte, une interface tactile imprécise |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot, la préférence de l'utilisateur (la référence fixe la 4.7 ; la version installée reste à déterminer avec `/setup-engine`) |
| **Key Technical Challenges** | IA juste avec intentions annoncées ; état de jeu en données pures et sauvegarde automatique (l'OS tue les applications) ; interface tactile ; performances sur Android bas de gamme ; export iOS (Mac + Xcode) |
| **Art Style** | 3D stylisée low-poly, en aplats, avec des couleurs par sommet |
| **Art Pipeline Complexity** | Low : Blender, sans textures, avec un shader de saturation par tuile |
| **Audio Needs** | Moderate |
| **Networking** | None |
| **Content Volume** | 3 factions au maximum, environ 12 fragments par chronique, environ 6 types d'unités, 10 à 12 protocoles, 2 tailles de carte, 3 difficultés |
| **Procedural Systems** | Génération de cartes à partir d'une graine, avec validation (distance entre les points de départ, équité des ressources, ruines atteignables) ; fragments tirés d'un pool écrit à la main dans l'ordre de la chronique |

**TD-FEASIBILITY : CONCERNS.** Aucun risque technique bloquant n'a été identifié à ce
stade, **mais ce constat n'a pas été vérifié sur appareil**. Le risque principal est le
volume de contenu au regard du calendrier. Critères de viabilité du MVP, mesurés sur
l'**appareil de référence** : 30 fps ou plus, un tour d'IA en moins de 2 secondes, et une
reprise de partie sans perte après que l'application a été tuée.

**Appareil Android de référence :** le téléphone actuel du développeur, un Google Pixel
sous Android 15+ (modèle exact à préciser). Attention : un Pixel n'est pas un appareil
d'entrée de gamme. Le critère des 30 fps devra aussi être vérifié sur un Android bas de
gamme avant la sortie.

Un export Android signé est à faire en semaine 1 ou 2. Trois prototypes techniques
(rendu sur appareil bas de gamme, export signé, reprise après kill) se font en parallèle
de `/map-systems`, avant de verrouiller l'architecture. La spécification du shader, le
format de sauvegarde et la structure de l'IA sont renvoyés à `/create-architecture` et aux
ADR.

---

## Risks and Open Questions

### Design Risks
- L'équilibre entre la croissance visible (pilier 1) et la punition de l'expansion
  (pilier 4) : la partie peut devenir frustrante, ou au contraire tourner à l'avantage
  définitif de celui qui prend l'avance.
- Le fil narratif peut se perdre sur des cartes générées, d'où le pool de fragments tirés
  dans un ordre fixe.
- L'histoire doit dire quelque chose de la conquête elle-même (répétition, rédemption,
  prise de conscience), sinon la mécanique et le mystère tirent dans deux directions.

### Technical Risks
- L'IA à intentions annoncées en plus de l'IA économique (risque n°1). *Mitigation* :
  n'annoncer que les attaques des unités, utiliser une IA à scores et commencer par une
  IA « gloutonne ».
- La sauvegarde en cours de partie sur mobile et la gestion des versions de sauvegarde
  quand les règles évoluent.
- Le temps de calcul de l'IA sur un téléphone bas de gamme (à étaler sur plusieurs frames
  ou à déplacer dans un thread).
- Le shader de saturation sur les renderers Mobile et Compatibility (à tester tôt).
- L'export iOS et l'obligation, sur Android 15+, de supporter les pages mémoire de 16 Ko.

### Market Risks
- Être perçu comme un clone de Polytopia, d'où la signature visuelle « gris, puis couleur »
  et le récit.
- Un marché de la stratégie mobile très chargé.

### Scope Risks
- Premier jeu en solo : l'IA et la génération procédurale sont souvent sous-estimées d'un
  facteur 2 ou plus (PR-SCOPE).
- L'équilibrage de 3 factions sur 3 difficultés, soit 9 configurations.
- Le délai de publication : test fermé Google Play (12 testeurs pendant 14 jours), revue
  App Store.

### Open Questions
- **Monétisation** : premium ou free-to-play ? À trancher avant la sortie.
- **Secret central** : l'hypothèse de travail se trouve dans « Ligne narrative ». Elle sera
  verrouillée après les 5 testeurs extérieurs.
- **Seuil d'échec du récit** : si moins de 3 testeurs extérieurs sur 5 citent une ruine sans
  aide, on recentre le pitch sur la recoloration (le classement MDA sera revu à ce moment-là).
- **Coût d'écriture** : 36 fragments en 3 voix, à chiffrer. Restent aussi à définir la forme
  d'un fragment, la « mémoire de faction », l'identité de l'IA du joueur, la règle du sépia
  (mémoire humaine ou mémoire des drones) et la place du titre parapluie « Dogs of War ».
- **Équipe** : supposée solo, à confirmer.
- **Le fragment sur carte générée est-il satisfaisant ?** À valider avec `/prototype`.

---

## MVP Definition

**Core hypothesis** : réveiller sa meute pour reconquérir un monde gris, en étant tiré par
les ruines à explorer, rend une partie de 20 à 40 minutes captivante et donne envie de
rejouer pour la chronique.

**Required for MVP** :
1. Un duel 1 contre 1 sur une petite carte faite à la main ou à graine fixe.
2. 4 types d'unités drones de meute, plus 3 types de Gardiens pour l'IA (périmètre inscrit le
   2026-10-30, à chiffrer par le producer), avec combat et contre-attaque.
3. Des nœuds à capturer et à faire monter de niveau, et l'économie d'énergie.
4. 6 protocoles.
5. Le brouillard de guerre et des ruines contenant 5 fragments.
6. Une IA « gloutonne » simple, qui joue déjà en **deux temps** : elle annonce les attaques
   de ses unités à la fin du tour du joueur, les exécute au tour suivant et sauvegarde ces
   intentions (version minimale, sans équilibrage fin). *Changement de périmètre décidé lors
   de la design review du 2026-10-29 : le producer doit encore en chiffrer l'impact.*
7. Une victoire au score sur 30 tours.
8. Un état de jeu en données pures, avec sauvegarde automatique en fin de tour et à la mise en pause.
9. Le monde gris qui se recolore, en version basique.

**Explicitly NOT in MVP** (defer to later) :
- Le générateur de cartes procédural (après validation sur carte fixe).
- L'équilibrage fin de l'IA (les intentions annoncées, elles, sont dans le MVP).
- Les factions 2 et 3, plus de 5 fragments écrits, les 3 niveaux de difficulté.
- L'export iOS en production (un export de test reste prévu dès le premier mois).

### Scope Tiers (if budget/time shrinks)

*PR-SCOPE : OPTIMISTIC. Les ajustements du producer ont été appliqués (calendrier chiffré à
5 mois et palier intermédiaire ajouté).*

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 carte fixe, 1 contre 1, 4 unités, 6 protocoles, 5 fragments | Boucle de jeu, IA gloutonne en deux temps (intentions annoncées), sauvegarde automatique ; exports de test Android et iOS dès le premier mois | ~10 semaines (mi-parcours) |
| **Palier de lancement : 1 faction** | 1 faction complète, 1 chronique de 12 fragments, Android | Générateur procédural, équilibrage de l'IA, test fermé Google Play lancé dès que le MVP tourne | ~5 mois (point de coupe propre) |
| **Alpha : 2 factions** | 2 factions jouables, 2 chroniques | Déblocage d'une faction par une autre, 2 tailles de carte | ~8 mois |
| **Full Vision** | 3 factions, 3 chroniques (~36 fragments), iOS et Android | 3 difficultés, finitions, sortie sur les deux stores | ~10–12 mois |

Chaque faction ou chronique au-delà du palier de lancement doit pouvoir être livrée seule.
Aucun fragment au-delà des 5 premiers n'est écrit avant que la boucle de jeu soit validée
en playtest.

---

## Next Steps

- [x] Get concept approval from creative-director (CD-PILLARS)
- [ ] Fill in CLAUDE.md technology stack based on engine choice (`/setup-engine`)
- [ ] **Prototype core idea** (`/prototype [core-mechanic]`) — valider la boucle « réveiller, explorer, recolorer » et le fragment sur carte
- [ ] Bible artistique (`/art-bible`) à partir de l'ancrage visuel
- [ ] Valider le concept (`/design-review design/gdd/game-concept.md`)
- [ ] If prototype PROCEEDS: Decompose concept into systems (`/map-systems`)
- [ ] Design each system (`/design-system [system-name]`)
- [ ] Build vertical slice in Pre-Production (`/vertical-slice`)
- [ ] Validate core loop with playtest (`/playtest-report`)
- [ ] Plan first milestone (`/sprint-plan new`)
