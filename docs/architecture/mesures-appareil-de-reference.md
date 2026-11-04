# Mesures sur l'appareil de référence

**Appareil de référence (D2, décision de l'utilisateur, 2026-11-04) : Google Pixel 8, Android 15 ou plus.**

C'est sur lui que se lisent tous les budgets « sur l'appareil de référence » des ADR et du registre. Cette décision ne fixe pas la version minimale d'Android acceptée par le jeu (`min_sdk` du préréglage d'export) : c'est une autre décision, qui n'a pas été prise.

## Ce qui est mesuré

À chaque changement de tour, l'écran de partie écrit une ligne dans le journal (`PerfProbe`, `src/app/perf_probe.gd`). La ligne porte sur le tour qui vient de finir. Au début de la partie, une ligne indique aussi le rendu et l'appareil.

```
[mesure] rendu mobile (Mali-G715) · appareil Pixel 8
[mesure] tour 3 · 812 images · moyenne 16.7 ms · pire 41.2 ms · > 33 ms : 2 · écriture pire 3.10 ms · IA pire 7.80 ms
```

| Champ | Ce que c'est | Seuil | Si le seuil est dépassé |
|---|---|---|---|
| moyenne | Intervalle moyen entre deux images | 16,7 ms (60 i/s) | Voir « pire » |
| pire | Plus long intervalle du tour | 33,3 ms (plancher de 30 i/s, ADR-0012 et ADR-0014) | Carte 3D : un `MultiMeshInstance3D` par terrain (ADR-0014 §5), puis des ombres cuites à la place de la lumière dynamique (ADR-0014, Risks) |
| > 33 ms | Nombre d'images sous 30 i/s | 0 au repos, quelques-unes au plus pendant une onde | Comme ci-dessus |
| écriture pire | Plus longue écriture de la sauvegarde (`t_write`, `SaveCoordinator.last_write_usec`) | 8 ms (registre, `save_main_thread_budget`) | Écriture dans un fil séparé (ADR-0006 §7, amendement d'ADR-0004 §4) |
| IA pire | Plus long pas de l'IA dans une image (`AiRunner.last_advance_usec`) | 2 ms (registre) | Planification hors du fil principal (ADR-0005 §7) |

## Protocole

1. Récupérer l'APK : action GitHub `android-export` (lancement manuel ou tag `v*`), artefact `apk`. L'APK de débogage suffit.
2. L'installer sur le Pixel 8 : `adb install -r dogs-of-gods.apk`.
3. Lancer la lecture du journal : `adb logcat -s godot | grep mesure`.
4. Jouer une nouvelle partie sur la carte « plaine », vitesse du tour ennemi **Normale**, sans activer « Réduire les animations ». Jouer au moins 6 tours, avec au moins une capture de nœud (une onde de recoloration) et une attaque.
5. Recommencer sur la carte « marais » (la plus coûteuse pour l'IA : 17 appels par tour).
6. Reporter les lignes dans le tableau ci-dessous. Si un seuil est dépassé, appliquer le repli indiqué, dans l'ordre.

## Relevés

| Date | Carte | Tours | Pire image | > 33 ms | Écriture pire | IA pire | Remarques |
|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | Aucun relevé : il faut l'appareil |
