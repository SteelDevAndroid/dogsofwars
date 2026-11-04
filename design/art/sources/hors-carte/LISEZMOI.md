# Dogs of Gods — Ressources hors carte (section 7)

Pack de **propositions graphiques** produit le 4 novembre 2026 d'après `asset-specs (1).md`, section 7.

## Livré

| Chemin | Dimensions | Usage |
|---|---:|---|
| `illus/splash_portrait.png` | 1440 × 2560 | écran titre portrait, sans appel « Touchez pour jouer » |
| `illus/splash_paysage.png` | 2560 × 1440 | écran titre paysage |
| `illus/chronique_introduction.webp` | 2560 × 2560 | chronique/illustration carrée |
| `illus/chronique_briefing.webp` | 2560 × 2560 | chronique/illustration carrée |
| `illus/chronique_revelation.webp` | 2560 × 2560 | chronique/illustration carrée |
| `icons/ic_launcher_foreground.png` | 432 × 432 | calque premier plan transparent de l'icône adaptative |
| `icons/ic_launcher_background.png` | 432 × 432 | calque de fond opaque de l'icône adaptative |
| `icons/ic_launcher_monochrome.png` | 432 × 432 | variante monochrome pour Android |
| `icons/icon_classique_192.png` | 192 × 192 | icône classique |
| `store/icon_play_store_512.png` | 512 × 512 | icône Play Store, PNG opaque, < 1 Mo |
| `store/graphique_presentation_1024x500.png` | 1024 × 500 | image promotionnelle opaque |

## Écart / avertissement de qualité

- Les illustrations peintes proviennent de **découpes d'une composition générée de 1536 × 1024 pixels**, puis ont été recadrées et suréchantillonnées. La dimension des fichiers est conforme, **mais leur détail natif n'équivaut pas à celui d'une illustration peinte directement à 2560 × 2560**. À réinterpréter/retoucher à l'échelle réelle pour une livraison finale.
- Les trois illustrations de chronique sont des propositions de scènes. Le document n'indique aucun nombre minimal d'illustrations ni leur contenu précis.
- La direction artistique de science-fiction minérale et picturale est inspirée d'un registre de BD dystopique. Ce pack ne prétend pas remplacer les arbitrages de la bible artistique absente de cette livraison.
- La section « magasin » concerne ici les **fichiers du Play Store**, pas un magasin d'achats intégré au jeu. Aucune offre fictive, aucun tarif ni interface de microtransactions ne sont ajoutés.
- Les **captures d'écran réelles** (2 à 8, issues du Pixel 8) **ne sont pas incluses**. Il faut les enregistrer depuis le jeu sur le téléphone, sans cadre de téléphone et aux ratios prévus.
- Les fichiers `.kra` / `.psd` éditables en calques ne sont pas disponibles. Le script `sources/build_assets.py` (Pillow) permet de reproduire les exports depuis l'image source `sources/composition_source.png`.

## Validation avant intégration

1. Vérifier les zones de sécurité et la coupe sur les appareils cibles.
2. Vérifier le rendu des icônes adaptatives avec masque circulaire et autres masques Android.
3. Vérifier les détails picturaux à 100 %, et remplacer les illustrations suréchantillonnées par des peintures natives haute définition si nécessaire.
4. Mesurer le poids des fichiers pour les budgets APK/AAB.
5. Créer les captures réelles depuis le Pixel 8 et mesurer les performances du jeu.

## Organisation

- `illus/` : splash et chronique
- `icons/` : icône Android adaptative et classique
- `store/` : fiche Play Store
- `previews/` : planche d'aperçu
- `sources/` : image générée originale et script de préparation
- `manifest.json` : dimensions, modes et tailles de chaque export
