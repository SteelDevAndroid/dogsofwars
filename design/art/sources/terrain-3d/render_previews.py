#!/usr/bin/env python3
"""Orthographic gallery renders for terrain asset QA. Requires PIL + trimesh."""
from pathlib import Path
import numpy as np, trimesh, math
from PIL import Image,ImageDraw,ImageFont,ImageFilter
R=Path(__file__).resolve().parents[1]; F=R/'previews';F.mkdir(exist_ok=True)
ang=math.radians(42)
W,H=520,480
try:
 ft=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',18)
 ftbig=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',25)
except: ft=ImageFont.load_default();ftbig=ft

def render(name,showlabel=True):
 mesh=next(iter(trimesh.load(R/'terrain'/f'{name}.glb',force='scene').geometry.values()))
 im=Image.new('RGB',(W,H),(29,35,44));d=ImageDraw.Draw(im)
 # muted shadow under piece
 d.ellipse([76,313,452,407],fill=(19,24,31))
 V=mesh.vertices
 scale=350
 screen=np.column_stack((W/2+V[:,0]*scale,245+(V[:,2]*math.sin(ang)-V[:,1]*math.cos(ang))*scale))
 dep=V[:,1]*math.sin(ang)+V[:,2]*math.cos(ang)
 light=np.array([-0.43,0.79,0.44]);light/=np.linalg.norm(light)
 polys=[]
 for inds in mesh.faces:
  v=V[inds]; n=np.cross(v[1]-v[0],v[2]-v[0]);nm=np.linalg.norm(n)
  if nm<1e-9: continue
  n/=nm
  # vertex color + simulated game lighting, no bake in the GLB
  c=mesh.visual.vertex_colors[inds].mean(axis=0)[:3]
  shading=.83+.24*max(0,float(n@light))
  c=tuple(int(np.clip(x*shading,0,255)) for x in c)
  polys.append((float(dep[inds].mean()),[tuple(p) for p in screen[inds]],c))
 for _,pts,c in sorted(polys,key=lambda q:q[0]):
  d.polygon(pts,fill=c)
  d.line(pts+[pts[0]],fill=tuple(max(0,int(x*.80)) for x in c),width=1,joint='curve')
 if showlabel:
  d.text((25,24),name.replace('terrain_','').replace('_','  ').upper(),font=ftbig,fill=(232,226,211))
  d.text((25,429),f'{len(mesh.faces)} triangles  |  vertex colors  |  42°',font=ft,fill=(154,166,177))
 return im

names=[f'terrain_{t}_{i:02d}' for t in ['plaine','foret','montagne','eau'] for i in range(1,4)]
for n in names:render(n).save(F/f'{n}.png')
gap=12; margin=20; header=90
sheet=Image.new('RGB',(3*W+4*gap,4*H+5*gap+header),(17,22,29))
d=ImageDraw.Draw(sheet)
d.text((28,22),'DOGS OF GODS  /  TERRAIN LIBRARY',font=ftbig,fill=(241,231,209))
d.text((28,57),'12 meshes   •   GLB 2.0   •   orthographic 42°   •   no textures',font=ft,fill=(156,168,184))
for j,n in enumerate(names):sheet.paste(render(n),(gap+(j%3)*(W+gap),header+gap+(j//3)*(H+gap)))
sheet.save(F/'terrain_gallery.png',optimize=True)
print(F/'terrain_gallery.png')
