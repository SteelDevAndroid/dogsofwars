"""Convert packaged .glb files to .blend sources using Blender 4.x.
Usage: blender -b --python sources/convert_to_blend.py -- /path/to/unpacked/root
Requires bpy (Blender), not bundled.
"""
import bpy,sys
from pathlib import Path
root=Path(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else Path.cwd()
models=root/'assets'/'art'/'3d'
for glb in sorted(models.glob('*.glb')):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    bpy.ops.wm.save_as_mainfile(filepath=str(glb.with_suffix('.blend')))
    print('SAVED',glb.with_suffix('.blend'))
