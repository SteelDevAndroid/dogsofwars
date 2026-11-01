<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: coût de copie et de sérialisation de trois représentations de l'état de partie -->
<!-- Date: 2026-10-30 -->

# Banc etat-copie — rapport

Résultats rapportés par l'agent prototyper, exécutés avec Godot 4.7.2-stable (official), Windows, `--headless`, sans erreur ni avertissement du moteur. La session principale n'a pas relancé le banc. Contenu identique pour les trois représentations : T = 256, F = 2, U = 60, N = 10, R = 3, I = 60, en-tête de 16 entiers, graine 12345. La taille brute de la formule 5 vaut 4 264 octets avec ces paramètres (le GDD cite 6,5 Ko avec F = 4 et R = 20).

Représentations : **A** colonnes `PackedInt32Array` / `PackedByteArray` (42 colonnes, copie par `duplicate()` de chaque colonne) ; **B** objets `RefCounted` typés, copie manuelle profonde ; **C** `Dictionary` / `Array` imbriqués avec `duplicate(true)` et `duplicate_deep()`.

## Vérifications
- Une forme canonique commune reconstruite depuis A, B et C est égale à la source dans les trois cas ; chaque copie est égale à son original ; modifier la copie laisse l'original intact (A, B, C avec `duplicate(true)` ou `duplicate_deep()`). `duplicate()` non profond de C partage les imbriqués.
- `Dictionary.duplicate_deep()` existe en 4.7.2 ; `FileAccess.store_buffer` et `store_32` renvoient un `bool`.
- `var_to_bytes` d'un objet `RefCounted` donne 12 octets : l'objet est perdu.

## Copie (µs, 3 000 copies après 300 d'échauffement)

| Représentation | médiane | p95 | médiane copie + libération | p95 copie + libération |
|---|---|---|---|---|
| A colonnes packed | 15 | 21 | 17 | 25 |
| B objets RefCounted | 711 | 1 307 | 920 | 1 620 |
| C `duplicate(true)` | 284 | 575 | 367 | 700 |
| C `duplicate_deep()` | 283 | 561 | 366 | 671 |

## Sérialisation (µs, médianes sur 500 essais)

| | A | B | C |
|---|---|---|---|
| `var_to_bytes` (octets) | 7 520 | 49 888 | 58 392 |
| JSON (octets) | 8 455 | 20 975 | 21 804 |
| aller-retour var | 59 | 3 443 | 1 204 |
| aller-retour JSON (normalisation incluse) | 2 830 | 8 018 | 6 253 |
| égalité profonde après aller-retour | oui | oui | oui |

Le format sérialisé de B est un tableau de dictionnaires, pas les objets : ses valeurs ne sont pas celles d'un format B optimisé.

## Ordre d'itération d'un `Dictionary`
Observé : l'ordre d'insertion ; après `erase` puis réinsertion, la clé passe en fin de liste. **Observé, pas garanti** par la référence du moteur : la règle 8 du GDD 1 (parcours par id croissant) reste nécessaire.

## Entiers 64 bits et hachage SplitMix32
GDScript déborde en complément à deux sans erreur ; le masque `& 0xFFFFFFFF` redonne la valeur correcte modulo 2³². `draw(6)` pour les graines 0, 1, 1234, 987654321 et 4294967295 est identique entre deux exécutions (même md5) et recoupé avec un calcul Python indépendant pour les graines 1 et 1234. **`hash32(0, 0) = 0` : la graine 0 avec le compteur 0 est un point fixe** ; interdire la graine 0 ou ajouter un décalage.

## Copies par tour d'IA (`floor(2 000 ms × 25 % / t_clone)`, médiane copie + libération)
A : 17 µs → 29 411 ; C : 367 µs → 1 362 ; B : 920 µs → 543 (au p95 : 20 000, 714, 308).

## Non mesuré / NOT SOURCEABLE
Android et tout appareil réel ; mémoire résidente ; coût du ramasse-miettes et de la fragmentation sur longue durée ; débordement d'entier sur ARM ; écriture réelle sur disque ; copie partielle et copy-on-write des tableaux typés au-delà de ces mesures ; garantie d'ordre d'itération des `Dictionary`.

## Recommandation
Retenir A (colonnes typées) pour l'état copié en simulation (environ 19 fois plus rapide que C et 47 fois que B sur ce PC) ; sérialiser par `var_to_bytes` (59 µs pour 7,5 Ko) et réserver le JSON au débogage ; ne pas retenir B.
