<!-- PROTOTYPE - NOT FOR PRODUCTION -->
<!-- Question: coût de copie et de sérialisation de trois représentations de l'état de partie -->
<!-- Date: 2026-10-30 -->

# etat-copie

Hypothèse : des colonnes de tableaux typés (PackedInt32Array, PackedByteArray) copient et se sérialisent bien plus vite que des objets `RefCounted` ou des `Dictionary` imbriqués, pour un état de 256 tuiles, 2 factions, 60 unités, 10 nœuds, 3 ruines, 60 intentions.

Lancer : `Godot_v4.7.2-stable_win64_console.exe --headless --path prototypes/etat-copie -s bench.gd`.

Statut : conclu 2026-10-30. Résultats dans `REPORT.md` ; ils fondent l'ADR-0003. Mesures sur PC Windows en mode headless : **non mesuré sur Android**.
