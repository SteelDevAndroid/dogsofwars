# Revue d'architecture — 2026-11-03

**Périmètre** : ce qui a changé depuis la revue du 2026-11-02, sur `main` (`81e2d7b`) : ADR-0012 (rendu immédiat, qui remplace ADR-0001), les anneaux, le fondu binaire et la réécriture de l'onde de recoloration (PR #17 et #18), les créneaux des animations réduites, la borne du tour de l'IA, et la PR #16 d'une autre session (sons, deuxième carte, résumé du tour ennemi, textures et éléments de l'art livré, polices, sauvegarde automatique d'Android). Code relu, motifs interdits revérifiés, ADR et registre recoupés.

**Verdict : PASS WITH CONCERNS.** Aucun défaut de conception bloquant. Les revues du 30/10, du 01/11 et du 02/11 sont soldées, sauf les mesures sur appareil. Il reste trois sujets à décider, et une dérive de documentation : des décisions d'architecture s'écrivent dans des notes d'ADR qui n'en sont pas le sujet.

---

## 1. À décider

### D1. Ondes « en parallèle » (GDD 15) ou lot après lot (GDD 17) : la tenue d'une onde bloque le joueur
- Le GDD 15 (règle 15, E1) veut que les ondes de commandes successives se jouent en parallèle. Le GDD 17 (règles 10 à 13) et ADR-0002 jouent un lot entier avant le suivant.
- Depuis les anneaux, une capture tient la présentation jusqu'à 1 000 ms, et le joueur ne peut rien toucher pendant ce temps (boutons inactifs hors de l'état inactif, HUD règle 6). Une phase ennemie gagne aussi 1 s par capture de l'IA.
- Le chemin de réécriture en cours d'onde est construit et testé, mais il ne se déclenche jamais en jeu (ADR-0012, Decision 4 ter).

**Recommandation** : demander au game-designer de choisir.
- **Ondes non bloquantes** : le séquenceur passe à l'étape suivante sans attendre la fin de l'onde, qui reste un effet ; la réécriture devient active. C'est une modification d'ADR-0002 §5 et du GDD 17, règle 10.
- **Lot après lot** : retirer la règle 15 et E1 du GDD 15, et supprimer le chemin de réécriture.

Garder les deux, c'est garder du code mort et deux GDD contradictoires.

### D2. Mesures sur appareil (inchangé depuis le 02/11)
`t_write`, la pire image de la phase ennemie (compteurs `SaveCoordinator.worst_write_usec` et `AiRunner.worst_advance_usec`) et le coût d'un redessin complet de la carte (ADR-0012, Verification 1 et 2) ne sont toujours pas mesurés. Ces mesures décident trois replis : le fil d'écriture (ADR-0006 §7), le fil de planification (ADR-0005 §7) et la couche statique, puis le MultiMesh (ADR-0012 §8). Il faut nommer l'appareil de référence.

### D3. Choix de la carte par la graine
`graine % nombre de cartes` choisit la carte d'une nouvelle partie (ADR-0008, note du 2026-11-02). C'est une règle de jeu : le joueur ne choisit pas sa carte, et l'ajout d'une carte change la carte de toutes les graines existantes. Elle n'est écrite dans aucun GDD (2, 3 ou 21). À confirmer par le game-designer, puis à écrire dans le GDD 2.

---

## 2. Documentation à aligner

| # | Où | Constat | Correction |
|---|---|---|---|
| N1 | ADR-0008 | Il sert de journal pour des sujets qui ne relèvent pas de la racine de composition : équilibrage, deuxième carte, résumé du tour ennemi, **architecture audio** (`SoundBank`, bus créés à l'exécution, `SoundHandler` dans la liste des gestionnaires), textures, éléments de carte, interface. Les décisions audio n'ont ni ADR ni entrée au registre (seul le consommateur `audio-presenter` du contrat `presentation_handler` existe) | Écrire un ADR-0013 « Audio » court (bus, jeu de lecteurs, `SoundHandler`, règle d'accessibilité « aucun son seul porteur d'information », inscrite au registre comme motif). Ne garder dans ADR-0008 que la composition (où `SoundBank` est construit et injecté). Renvoyer l'art à `design/art/` |
| N2 | ADR-0002 l. 131, ADR-0008 l. 47 et 95 | `TileTimeSource −10` figure encore dans la liste des priorités, alors qu'il n'existe pas (ADR-0012) | Retirer, ou écrire « −10 libre » |
| N3 | ADR-0002, Écarts 7 | « L'ordre des gestionnaires est tuiles puis HUD » : le code fait caméra, tuiles, HUD, son (`match_screen.gd`) | Mettre l'ordre réel dans §5 et dans le registre |
| N4 | ADR-0009 (Enables, Key Interfaces `teintes: TeintesTable`, ligne du GDD 15), GDD 15 (F2, Tuning Knobs `TABLE_TEINTES` « données ») | Aucune `TeintesTable` : les teintes sont les constantes de `TilePalette` (écart déjà noté dans ADR-0012) | Trancher : un fichier `teintes.json` lu par `TilePalette`, ou ADR-0009 et GDD 15 qui disent « constantes de l'art bible dans le code » |
| N5 | GDD 15, l. 319 | « Rendu (avis du technical-artist) : donnée par instance (vec4)… » décrit ADR-0001 | Renvoyer à ADR-0012 |
| N6 | ADR-0002 §5, registre `presentation_handler` | `handle_merged` fait partie du contrat, mais le séquenceur ne l'appelle jamais : les créneaux d'A2 l'ont remplacé. Le code est mort | Retirer `handle_merged` du contrat et de `PresentationHandler`, ou le garder pour D1 et l'écrire |

---

## 3. Points mineurs dans le code et les données

- **Plages des données d'onde plus larges que le GDD 15** : `wave_ring_ms` accepte 100 à 400 alors que le GDD donne 150 à 200 ; `wave_total_max_ms` accepte 400 à 1 500 alors que le GDD donne 600 à 1 200. Rien n'écrit la trace d'AC-RC10 quand `T_ANNEAU_eff` est réduit. Correction : resserrer `PresentationParams.SCHEMA` et ajouter un contrôle croisé au chargement (ADR-0009 §3) qui signale la réduction.
- **Sons à la vitesse Instantanée** : `SoundHandler` joue un son par événement. À ×1 000, une phase ennemie tient en quelques images : huit sons se chevauchent (le jeu de lecteurs) et les suivants coupent les plus anciens. Correction : au plus un son par repère et par image, ou rien en Instantanée sauf la fin du tour.
- **Horloge système dans le Core** : `AiRunner` et `SaveCoordinator` lisent `Time.get_ticks_usec()` pour les compteurs de mesure (A3). Ces lectures n'influencent aucune décision, mais elles côtoient la règle « aucune horloge système dans la logique de 9 ». Correction : l'écrire au registre (exception de mesure, jamais lue par une règle), pour qu'une revue ne la prenne pas pour une violation.
- **`renderer_reads_real_state` n'est pas contrôlé par la CI** : seule la relecture le garantit. Correction : une ligne dans `check-layer-deps` qui refuse `GameState` dans `src/presentation/tiles/` hors de `tile_snapshot.gd` et de la signature de `show_state`.

---

## 4. Conformité revérifiée

| Décision ou motif | Résultat |
|---|---|
| Ni `await` ni `create_timer` (ADR-0002) | Aucun dans `src/` |
| `FileAccess` / `DirAccess` derrière un port | `RealFileStore`, `ResDataSource` (le reste : commentaires) |
| Hasard du moteur | `randi()` pour la graine d'une nouvelle partie seulement (`Bootstrap`) |
| `get_tree()` | `Bootstrap` seulement (application) |
| Anti-fuite des nouveaux chemins | `WaveSource` ne met dans l'événement qu'une source visible du joueur ; `SoundHandler` et le résumé du tour ennemi ne lisent que des événements déjà filtrés par le brouillard ; sur une copie filtrée de l'IA, la ligne du joueur dans le cache de vue est vide (pas d'erreur, aucune source) |
| Animations réduites | Créneaux de temps réel (×scale de l'horloge) pour les changements de couleur ; ondes et glissements à 0 ms ; attaques inchangées |
| Borne du tour de l'IA | Les deux cartes livrées passent : `plaine` 12 appels (12 000 évaluations), `marais` 17 appels (17 000 sur 20 000) |
| Sauvegarde automatique d'Android | Profil sauvegardé, partie exclue (règles du manifeste, option du préréglage) ; vérifié dans l'APK par `aapt2`, pas sur appareil |
| CI | Verte sur la tête de la PR #18 (`aa8feab`, 753 tests), mergée telle quelle dans `main` |

---

## 5. Ce qui est solide

- Le rendu de la recoloration suit maintenant le GDD 15 de bout en bout (source effective, anneaux, fondu binaire), en fonctions pures testées sur leurs exemples chiffrés, et sans jamais révéler la position d'un nœud caché.
- Chaque écart est daté et noté dans l'ADR qui le porte. La revue n'a trouvé aucun écart silencieux entre le code et les décisions.
- Les replis de performance sont ordonnés et écrits avant la mesure : la mesure ne déclenchera pas de discussion d'architecture, seulement un choix déjà préparé.

---

## 6. Suivi (2026-11-03)

| Point | État |
|---|---|
| D1, D3 | **Ouverts**, décision de l'utilisateur et du game-designer |
| D2 | **Décidé le 2026-11-04** : Pixel 8, Android 15+. Relevé par tour dans le journal (`PerfProbe`), protocole et seuils dans `mesures-appareil-de-reference.md`. Les mesures restent à faire sur l'appareil |
| N1 | Fait : ADR-0013 « Audio » (bus, jeu de lecteurs, `SoundHandler`, accessibilité) ; registre : API `audio_cues`, motif `sound_as_only_signal`. ADR-0008 garde un renvoi et la composition ; les notes d'art sont déplacées dans `design/art/integration-2026-11-02.md`. Les notes d'équilibrage, de deuxième carte et de résumé restent dans ADR-0008 en attendant D3 |
| N2 | Fait : `TileTimeSource` retiré des listes d'ADR-0002 et d'ADR-0008 (−10 libre) |
| N3 | Fait : ordre caméra, tuiles, HUD, son dans ADR-0002 (§5, diagramme, Écarts 7) et au registre (`presentation_handler`) |
| N4 | Fait : ADR-0009 et GDD 15 disent que les teintes sont des constantes de `TilePalette` (art bible), pas des données |
| N5 | Fait : la note de rendu du GDD 15 renvoie à ADR-0012 |
| N6 | Fait : `handle_merged` retiré de `PresentationHandler`, d'ADR-0002 et du registre |
| Plages des données d'onde | Fait : `PresentationParams.SCHEMA` suit les plages du GDD 15 (`recolor_ms` 200 à 400, `wave_ring_ms` 150 à 200, `wave_total_max_ms` 600 à 1 200) ; `ring_trace()` écrit la trace d'AC-RC10 au chargement (`push_warning`), testée |
| Sons à la vitesse Instantanée | Fait : un même repère démarre au plus une fois par image (`SoundBank.play`), testé |
| Horloge système dans le Core | Fait : motif `system_clock_in_game_rule` au registre, avec l'exception des compteurs de mesure |
| `renderer_reads_real_state` en CI | Fait : règle dans `check-layer-deps.sh` et deux cas dans son auto-test |

