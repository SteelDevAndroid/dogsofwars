"""Execute with Blender: blender -b -P source/import_to_blender.py
Imports 12 glb individually and saves editable .blend sources beside each GLB.
Unlike the GLB, the generated .blend preserves meshes as native Blender meshes.
"""
import bpy
from pathlib import Path
root=Path(__file__).resolve().parents[1]
for glb in sorted((root/'terrain').glob('terrain_*.glb')):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(glb))
 bpy.ops.wm.save_as_mainfile(filepath=str(glb.with_suffix('.blend')))
 print('Saved',glb.with_suffix('.blend'))
