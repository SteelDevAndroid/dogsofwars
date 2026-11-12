# Dogs of Gods — graphical asset import

This branch adds a **non-destructive import tool** for the generated 58-asset pack.
The binary artwork is **not committed**: the GitHub text-file integration cannot upload
the GLB/PNG/WebP files from the previously generated ZIP.

## Apply

1. Download `dogsofgods_integration_complete_58_assets.zip` from the ChatGPT conversation.
2. Run `python tools/import_graphics_pack.py /path/to/dogsofgods_integration_complete_58_assets.zip`.
3. Open the project with Godot 4.7 and allow GLB and SVG import.
4. Review existing scene references and connect the new assets to the relevant scenes.
5. Validate Android build, appearance, materials and unit color masks.

The archive includes 12 terrain models, 14 unit models (7 awake / 7 sleeping,
command niches embedded in four pack units), 21 UI icons, 5 illustrations,
4 Android icons and 2 store images.

By default the tool skips existing files. `--replace` creates backups in
`.asset-backups/` before replacing any files. No existing scene or project
configuration is modified by the tool.

**Status:** import workflow only; asset binaries, scene wiring and Godot validation
remain outstanding. Keep this pull request in draft until they are completed.
