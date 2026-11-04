from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageFilter
import cairosvg, math, random, zipfile, json, io
root=Path('/mnt/data/dogsofgods_interface'); (root/'ui').mkdir(parents=True,exist_ok=True); (root/'previews').mkdir(exist_ok=True); (root/'source').mkdir(exist_ok=True)
# All primitives use white #FFFFFF, stroke-width 2, square caps/joins. Native SVG at 24x24.
icons={
 'tour': '''<path d="M4 8V4h4M20 16v4h-4"/><path d="M8 4h8l4 4v4M16 20H8l-4-4v-4"/><path d="M9 12h6M12 9v6"/>''',
 'energie': '''<path d="M13 2 5 13h6l-1 9 9-13h-6l0-7Z"/><path d="M4 4h3M17 20h3"/>''',
 'recherche': '''<path d="M4 7V4h3M17 4h3v3M4 17v3h3M20 17v3h-3"/><circle cx="11" cy="11" r="5"/><path d="m15 15 5 5M9 11h4M11 9v4"/>''',
 'ruine': '''<path d="M3 20h18M6 20V9l4-5 4 4-2 4M18 20v-9l3-3"/><path d="M7 10h3l3 3-1 4M15 8l3-5 3 3M3 16l3-2M15 16l3-3"/>''',
 'noeud': '''<path d="m12 2 8 5v10l-8 5-8-5V7Z"/><path d="m12 6 5 3v6l-5 3-5-3V9Z"/><path d="M12 9v6M9 12h6"/>''',
 'attaque': '''<path d="M4 20 19 5M12 5h7v7M3 14l7 7M4 10l10 10"/><path d="m16 3 5 5"/>''',
 'reveil': '''<path d="M5 12a7 7 0 0 1 12-5M19 12a7 7 0 0 1-12 5"/><path d="m13 3 4 4-4 3M11 21l-4-4 4-3"/><path d="M11 9v4l3 2"/>''',
 'montee_de_niveau': '''<path d="M4 20h16M6 17h4v3M10 13h4v7M14 9h4v11"/><path d="M5 10 12 3l7 7M12 3v8"/>''',
 'pause': '''<path d="M5 4h5v16H5ZM14 4h5v16h-5Z"/>''',
 'zoom_plus': '''<circle cx="10.5" cy="10.5" r="6.5"/><path d="m15.5 15.5 5 5M7 10.5h7M10.5 7v7"/>''',
 'zoom_moins': '''<circle cx="10.5" cy="10.5" r="6.5"/><path d="m15.5 15.5 5 5M7 10.5h7"/>''',
 'recentrer': '''<path d="M3 9V4h5M16 4h5v5M21 15v5h-5M8 20H3v-5"/><path d="M12 6v3M12 15v3M6 12h3M15 12h3"/><path d="m12 10 2 2-2 2-2-2Z"/>''',
 'reglages': '''<path d="M4 6h16M4 12h16M4 18h16"/><path d="M8 3v6M16 9v6M10 15v6"/><rect x="6" y="4" width="4" height="4"/><rect x="14" y="10" width="4" height="4"/><rect x="8" y="16" width="4" height="4"/>''',
 'chronique': '''<path d="M6 3h11l3 3v15H6l-3-3V6Z"/><path d="M17 3v5h3M7 10h8M7 14h10M7 18h6"/><path d="M3 6h3M3 18h3"/>''',
 'menace': '''<path d="m12 2 10 18H2Z"/><path d="M12 8v6M12 17v1"/><path d="M4 3h3M17 3h3"/>''',
 'perte': '''<path d="m12 3 8 4v7l-8 7-8-7V7Z"/><path d="m8 9 8 6M16 9l-8 6"/>''',
 'vitesse': '''<path d="M4 17a9 9 0 1 1 16 0M12 17l5-8"/><path d="M12 4v3M5 9l2 2M19 9l-2 2M7 20h10"/><circle cx="12" cy="17" r="1" fill="white" stroke="none"/>''',
 'retour': '''<path d="M11 4 3 12l8 8M4 12h10a6 6 0 0 1 6 6v2"/>''',
 'mouvement': '''<path d="M12 2v20M2 12h20M12 2l-3 3M12 2l3 3M12 22l-3-3M12 22l3-3M2 12l3-3M2 12l3 3M22 12l-3-3M22 12l-3 3"/><path d="m10 10 2-2 2 2-2 2Z"/>''',
 'defense': '''<path d="m12 2 9 4v6c0 5-4 8-9 10-5-2-9-5-9-10V6Z"/><path d="M7 12h10M12 7v10"/>''',
 'vue': '''<path d="M2 12c3-5 6-7 10-7s7 2 10 7c-3 5-6 7-10 7S5 17 2 12Z"/><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3"/>'''
}
labels={'tour':'Tour','energie':'Énergie','recherche':'Recherche','ruine':'Ruine','noeud':'Nœud','attaque':'Attaque','reveil':'Réveil','montee_de_niveau':'Montée de niveau','pause':'Pause','zoom_plus':'Zoom +','zoom_moins':'Zoom −','recentrer':'Recentrer','reglages':'Réglages','chronique':'Chronique','menace':'Menace','perte':'Perte','vitesse':'Vitesse','retour':'Retour','mouvement':'Mouvement','defense':'Défense','vue':'Vue'}
for name,shapes in icons.items():
 svg=f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" role="img" aria-label="{labels[name]}"><g stroke="#FFFFFF" stroke-width="2" stroke-linecap="square" stroke-linejoin="miter" fill="none">{shapes}</g></svg>'''
 (root/'ui'/f'ui_{name}.svg').write_text(svg,encoding='utf-8')
# panel 96x96 (9-patch margins 24px). Relatively flat center for clean stretching.
p=Image.new('RGBA',(96,96),(0,0,0,0)); d=ImageDraw.Draw(p)
d.rounded_rectangle((1,1,94,94),radius=8,fill=(231,223,205,242),outline=(30,35,41,255),width=2)
d.rounded_rectangle((5,5,90,90),radius=5,outline=(90,97,101,170),width=1)
d.line([(24,7),(72,7)],fill=(160,134,103,160),width=1);d.line([(24,88),(72,88)],fill=(160,134,103,160),width=1)
for x,y,sgnx,sgny in [(10,10,1,1),(85,10,-1,1),(10,85,1,-1),(85,85,-1,-1)]:
 d.line([(x,y+sgny*7),(x,y),(x+sgnx*7,y)],fill=(73,81,87,180),width=2)
 d.line([(x+sgnx*3,y+sgny*3),(x+sgnx*6,y+sgny*6)],fill=(184,143,101,135),width=1)
p.save(root/'ui'/'ui_panneau.png')
# png previews only, SVG master assets
for nm in icons:
 cairosvg.svg2png(url=str(root/'ui'/f'ui_{nm}.svg'),write_to=str(root/'previews'/f'ui_{nm}.png'),output_width=192,output_height=192)
W,H=1500,1050
im=Image.new('RGB',(W,H),(23,29,36)); d=ImageDraw.Draw(im)
fontpath='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
fb='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
titlefont=ImageFont.truetype(fb,38); minor=ImageFont.truetype(fontpath,20); label_font=ImageFont.truetype(fontpath,18)
d.text((56,40),'DOGS OF GODS  /  INTERFACE',font=titlefont,fill=(231,223,203));d.text((57,95),'21 pictogrammes vectoriels • trait blanc 2 px • cadre 24 × 24',font=minor,fill=(157,171,182))
cols=7
for idx,(nm,label) in enumerate(labels.items()):
 r,c=divmod(idx,cols);x=50+c*204;y=165+r*236
 d.rounded_rectangle((x,y,x+186,y+214),radius=12,fill=(33,41,50),outline=(80,91,103),width=2)
 d.line((x+17,y+17,x+48,y+17),fill=(181,138,94),width=3)
 ico=Image.open(root/'previews'/f'ui_{nm}.png').convert('RGBA');ico=ico.resize((104,104),Image.Resampling.LANCZOS)
 im.paste(ico,(x+41,y+38),ico)
 bbox=d.textbbox((0,0),label,font=label_font);tx=x+93-(bbox[2]-bbox[0])/2
 d.text((tx,y+164),label,font=label_font,fill=(224,221,214))
d.text((56,905),'SYSTÈME VISUEL : MONOLINE / SYMBOLIQUE TECHNIQUE / LISIBILITÉ À 20 pt',font=minor,fill=(178,153,125))
d.text((56,946),'Export SVG natif • fond transparent • aucune police intégrée dans les icônes',font=minor,fill=(154,165,172))
im.save(root/'previews'/'interface_gallery.png')
# panel preview large
pv=Image.new('RGB',(620,360),(28,34,42));dd=ImageDraw.Draw(pv);dd.text((34,25),'PANNEAU PAPIER  /  9-PATCH',font=ImageFont.truetype(fb,23),fill=(230,222,204))
large=p.resize((288,288),Image.Resampling.NEAREST);pv.paste(large,(45,65),large)
for v in [24,72]:
 dd.line([(370,65+v*2),(610,65+v*2)],fill=(136,139,143),width=1)
for yy,txt in [(105,'96 × 96 px'),(140,'marges : 24 px'),(175,'coins préservés'),(210,'centre extensible')]:dd.text((370,yy),txt,font=minor,fill=(218,213,203))
pv.save(root/'previews'/'panneau_preview.png')
# font options without redistribution of font files
readme='''# Dogs of Gods — ressources Interface (section 6)

## Livrables
- `ui/ui_*.svg` : 21 icônes monochromes (voir `manifest.json`).
- `ui/ui_panneau.png` : variante de panneau papier **96 × 96 px** avec marges 9-patch **24 px** ; la spécification indique qu’une version existe déjà, donc ce fichier est une proposition de remplacement facultative.
- `previews/interface_gallery.png` : planche de lecture des 21 icônes.
- `previews/panneau_preview.png` : aperçu du panneau.
- `previews/ui_*.png` : images d’aperçu, **pas les ressources à importer**.
- `source/generate_ui.py` : générateur autonome des ressources SVG, du panneau et des aperçus.

## Conformité
Chaque SVG : `viewBox="0 0 24 24"`, trait `2`, `stroke-linecap="square"`, blanc `#FFFFFF`, sans aplats colorés ni fond, utilisable à 20 dp minimum. Les détails suivent une esthétique techno-minérale sombre à géométrie anguleuse, évoquant un univers de SF graphique, sans reproduire une œuvre existante.

## Nommage / intégration
Le document de spécification énumère les **fonctions**, mais **pas les noms exacts des 21 fichiers déjà présents** dans `assets/art/ui/`. Ces fichiers sont nommés ici `ui_tour.svg`, `ui_energie.svg`, etc. **Vérifiez les noms attendus par le dépôt** avant de remplacer les ressources existantes. La table `manifest.json` permet d’automatiser leur correspondance. Importer en Godot via `assets/art/ui/`.

## Polices (non incluses)
Les polices sont des œuvres tierces et ne sont pas redistribuées dans cette livraison. Sélection suggérée à valider dans l'art bible : **IBM Plex Sans** Regular, Medium et SemiBold (SIL OFL 1.1) pour l’interface ; contrôler l’extension latin, les accents français et les chiffres tabulaires (`tnum`) dans le moteur de rendu choisi. Source officielle : https://github.com/IBM/plex .

## Points à valider
- Comparaison à l’écran Android à **20 dp**, et accessibilité (contraste sur les fonds réels).
- Mapping exact des noms et marges 9-patch selon le thème Godot.
- Typographie installée dans le projet, sous sa licence, par le développeur.
- Icônes “tour” et “retour” intentionnellement différentes : tour du jeu et navigation arrière.
'''
(root/'LISEZMOI.md').write_text(readme,encoding='utf-8')
(root/'manifest.json').write_text(json.dumps({'specification':'asset-specs (1).md, section 6','icons':[{'function':labels[n],'file':f'ui_{n}.svg'} for n in icons],'panel':{'file':'ui_panneau.png','size':[96,96],'patch_margin':24},'fonts':{'suggested':'IBM Plex Sans','weights':['Regular','Medium','SemiBold'],'included':False}},indent=2,ensure_ascii=False),encoding='utf-8')
# source code archive generation tool from current script itself
Path(root/'source'/'generate_ui.py').write_text(Path(__file__).read_text(encoding='utf-8'),encoding='utf-8')
out=Path('/mnt/data/dogsofgods_interface_21_icones.zip')
with zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED) as z:
 for path in root.rglob('*'):
  if path.is_file(): z.write(path,path.relative_to(root.parent))
print('ASSETS',len(icons),'PACKAGE',out,'BYTES',out.stat().st_size)
