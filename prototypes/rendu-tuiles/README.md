<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: rendu de 144-256 tuiles en un MultiMesh avec onde dans le shader -->
<!-- Date: 2026-10-30 -->

# rendu-tuiles

Hypothese : un MultiMeshInstance2D (custom data vec4) + shader suffisent pour l'onde de recoloration.
Lancer : `Godot_v4.7.2-stable_win64.exe --path . ` ; bench : ajouter `-- --bench`.
Commandes : clic gauche = capture PROPRE, clic droit = ENNEMI, 1/2/3 rayon, C daltonien, R animations reduites, F brouillard de zone, G 12x12/16x16.
Statut : conclu 2026-10-30 (voir REPORT.md). Résultat : MultiMesh + custom data vec4 + temps global + palette uniforme fonctionnent en 4.7.2 Mobile sur PC (0,6 ms/frame en 16×16) ; **non testé sur Android**. Ce code n'est pas migré : l'ADR du rendu des tuiles et un test sur appareil d'entrée de gamme doivent précéder toute réécriture.
