#!/usr/bin/env python3
"""Dogs of Gods - reproducible terrain mesh generator (12 GLB / glTF 2.0).
Coordinate system: X right, Y up, Z toward camera; meter-scale 1 tile=1 unit.
Authoring sources are procedural and fully editable. No external textures.
"""
import json, math, pathlib, random
import numpy as np
import trimesh

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'terrain'
OUT.mkdir(exist_ok=True)
HEX = {'plain':'#7A848E','forest_ground':'#68737E','forest':'#5A6772','mountain':'#98A2AC','water':'#34495C'}

def rgb(hexstr): return np.array([int(hexstr[i:i+2],16) for i in (1,3,5)])
def mix(a,b,t): return np.clip(np.round(np.array(a)*(1-t)+np.array(b)*t),0,255).astype(np.uint8)
def tone(c, f): return np.clip(np.round(np.asarray(c)*f),0,255).astype(np.uint8)
class Mesh:
 def __init__(self): self.v=[];self.f=[];self.c=[]
 def tri(self,a,b,c,color):
  start=len(self.v); self.v.extend([a,b,c]);self.f.append((start,start+2,start+1));self.c.extend([list(color)+[255]]*3)  # (a, c, b): glTF front faces are counter-clockwise seen from outside; (a, b, c) put every face inside out (fixed 2026-11-04)
 def quad(self,a,b,c,d,color):
  self.tri(a,b,c,color);self.tri(a,c,d,color)
 def poly(self,pts,color):
  for k in range(1,len(pts)-1): self.tri(pts[0],pts[k],pts[k+1],color)
 def prism(self,footprint,bottom,top,color, wall=None, cap=True, bottom_cap=False, facet=None):
  n=len(footprint); wall=tone(color,.72) if wall is None else wall
  if cap:
   self.poly([(x,top,z) for x,z in footprint],color)
  if bottom_cap: self.poly([(x,bottom,z) for x,z in footprint[::-1]],tone(color,.6))
  for j in range(n):
   a=footprint[j];b=footprint[(j+1)%n]
   fc=wall if facet is None else tone(wall,facet[j%len(facet)])
   self.quad((a[0],bottom,a[1]),(b[0],bottom,b[1]),(b[0],top,b[1]),(a[0],top,a[1]),fc)
 def slab(self,top,col):
  self.prism([(-.49,-.49),(.49,-.49),(.49,.49),(-.49,.49)],top-.22,top,col,facet=[.91, .78, 1.02,.85])
 def rock(self,x,z,r,base,peak,color,n=5,seed=0,cap=0.0, tilt=(0,0)):
  rnd=random.Random(seed)
  angles=[(2*math.pi*i/n)+rnd.uniform(-.1,.1) for i in range(n)]
  lower=[(x+r*(.83+rnd.uniform(-.13,.1))*math.cos(a),base,z+r*(.82+rnd.uniform(-.12,.11))*math.sin(a)) for a in angles]
  upper=[(x+tilt[0]+r*.25*math.cos(a),peak,z+tilt[1]+r*.25*math.sin(a)) for a in angles]
  for j in range(n):
   k=(j+1)%n
   shade=[.78,.94,.67,1.03,.86,.73,.97][j%7]
   self.quad(lower[j],lower[k],upper[k],upper[j],tone(color,shade))
  self.poly(upper,tone(color,1.08))
 def cone(self,x,z,rad,base,top,color,faces=5,seed=0,trunc=.24, angle=0):
  rnd=random.Random(seed)
  angles=[angle+2*math.pi*i/faces for i in range(faces)]
  lower=[(x+rad*math.cos(a),base,z+rad*math.sin(a)) for a in angles]
  upper=[(x+rad*trunc*math.cos(a+.10),top,z+rad*trunc*math.sin(a+.10)) for a in angles]
  for j in range(faces):
   k=(j+1)%faces
   self.quad(lower[j],lower[k],upper[k],upper[j],tone(color,[.72,.94,.83,1.03,.68,.91][j%6]))
  self.poly(upper,tone(color,1.08))
 def ridge(self,coordinates, width, height, color):
  # Angular low relief ribbon, never a texture or a decal
  for (x1,z1),(x2,z2) in zip(coordinates,coordinates[1:]):
   dx=x2-x1;dz=z2-z1;ll=math.hypot(dx,dz);nx=-dz/ll*width/2;nz=dx/ll*width/2
   self.quad((x1+nx,height,z1+nz),(x2+nx,height,z2+nz),(x2-nx,height,z2-nz),(x1-nx,height,z1-nz),color)
 def mesh(self):
  if not self.f: raise Exception('empty')
  m=trimesh.Trimesh(vertices=np.asarray(self.v), faces=np.asarray(self.f),process=False)
  m.visual.vertex_colors=np.array(self.c,dtype=np.uint8)
  return m

def plain(i):
 m=Mesh(); ht=[0,.05,.025][i-1]; c=rgb(HEX['plain']);m.slab(ht,c)
 if i==1:
  # straight abandoned cultivation trace, paired shallow cracks
  m.ridge([(-.40,-.20),(-.17,-.19),(.09,-.20),(.39,-.20)],.017,ht+.001,tone(c,.67))
  m.ridge([(-.40,-.11),(-.09,-.12),(.22,-.105),(.37,-.11)],.010,ht+.001,tone(c,1.18))
 elif i==2:
  # crisp hexagonal impact basin, the only elevation is extremely low
  outer=[(.12*math.cos(k*math.pi/3)+.14,.12*math.sin(k*math.pi/3)-.12) for k in range(6)]
  inner=[(.074*math.cos(k*math.pi/3)+.14,.074*math.sin(k*math.pi/3)-.12) for k in range(6)]
  for k in range(6):
   j=(k+1)%6;m.quad((outer[k][0],ht+.001,outer[k][1]),(outer[j][0],ht+.001,outer[j][1]),(inner[j][0],ht+.001,inner[j][1]),(inner[k][0],ht+.001,inner[k][1]),tone(c,.64 if k%2 else .78))
  m.poly([(x,ht+.002,z) for x,z in inner],tone(c,.82))
  m.ridge([(-.37,.29),(-.20,.23),(-.13,.15)],.009,ht+.001,tone(c,.8))
 else:
  # angular exposed stratification and a tiny dry fault
  m.ridge([(-.37,.27),(-.16,.19),(.03,.22),(.24,.12),(.38,.16)],.020,ht+.001,tone(c,.73))
  m.ridge([(-.30,.33),(-.14,.29),(.02,.31),(.25,.22)],.008,ht+.002,tone(c,1.20))
  m.ridge([(-.24,-.22),(-.09,-.31),(.12,-.27)],.014,ht+.001,tone(c,.82))
 return m.mesh()

def forest(i):
 m=Mesh();g=rgb(HEX['forest_ground']);b=rgb(HEX['forest']);m.slab(0,g)
 # Deliberate wide center (>0.35 diameter): tree forms clustered at rim
 clusters={
 1:[(-.34,-.30,.124,.27,5),(.33,-.32,.112,.23,5),(-.34,.28,.107,.22,6),(.31,.32,.10,.19,5)],
 2:[(-.34,-.22,.112,.25,5),(.32,-.33,.115,.30,6),(-.31,.34,.096,.21,5),(.32,.32,.108,.24,5),(.02,-.38,.078,.15,5)],
 3:[(-.33,-.35,.114,.30,5),(.30,-.34,.105,.26,5),(-.32,.27,.116,.25,5),(.33,.29,.115,.28,6)]}[i]
 for j,(x,z,r,h,n) in enumerate(clusters):
  m.cone(x,z,r,0,h,tone(b,[.95,1.10,.88,1.01][j%4]),faces=n,seed=i*20+j,trunc=[.3,.2,.28][j%3],angle=j*.32)
 # incised line of clear forest floor; does not compete with silhouettes
 if i==1: m.ridge([(-.12,.36),(-.09,.18),(-.12,.05)],.012,.001,tone(g,.78))
 if i==2: m.ridge([(.13,.38),(.08,.22)],.009,.001,tone(g,1.18))
 if i==3: m.ridge([(-.12,-.37),(-.06,-.22),(-.01,-.17)],.012,.001,tone(g,.72))
 return m.mesh()

def mountain(i):
 m=Mesh(); c=rgb(HEX['mountain']); m.slab(0,tone(c,.9))
 # Wide flat central unit seat at +0.12, deliberately legible from camera
 seat=[(-.17,-.16),(.17,-.16),(.17,.17),(-.17,.17)]
 m.prism(seat,0,.12,tone(c,1.03),facet=[.81,.71,.94,.78])
 # Peaks mostly at rear and far left/right, to leave central elevated platform open
 sets={
 1:[(-.35,-.31,.153,.38,5),(.34,-.30,.15,.32,5),(-.36,.29,.13,.23,5)],
 2:[(-.34,-.30,.14,.29,5),(.31,-.33,.172,.42,5),(.36,.29,.115,.24,5)],
 3:[(-.34,-.31,.155,.40,5),(.32,-.31,.15,.37,5),(-.36,.31,.125,.28,5)]}[i]
 for j,(x,z,r,p,n) in enumerate(sets):m.rock(x,z,r,0,p,tone(c,[.9,1.07,.96][j%3]),n=n,seed=105+i*7+j,tilt=(.012 if j%2 else -.008, -.012))
 # angular back cliff faceting and one readable fault line
 m.ridge([(-.12,-.39),(.04,-.35),(.19,-.40)],.021,.004,tone(c,.75))
 return m.mesh()

def water(i):
 m=Mesh();c=rgb(HEX['water']);h=-.10;m.slab(h,c)
 # One solitary static angular wave / ripple. One visual group of two adjoining facets.
 wave={1:[(-.32,.10),(-.08,.07),(.11,.11),(.32,.075)],
       2:[(-.29,-.13),(-.08,-.08),(.12,-.12),(.30,-.07)],
       3:[(-.28,.0),(-.07,.045),(.10,.015),(.28,.055)]}[i]
 m.ridge(wave,.021,h+.001,tone(c,1.48))
 return m.mesh()

records=[]
for typ, fn in [('plaine',plain),('foret',forest),('montagne',mountain),('eau',water)]:
 for variant in (1,2,3):
  name=f'terrain_{typ}_{variant:02d}'
  mesh=fn(variant)
  # Single mesh/node per .glb, with COLOR_0 vertex RGBA.
  scene=trimesh.Scene()
  scene.add_geometry(mesh,node_name=name,geom_name=name)
  (OUT/f'{name}.glb').write_bytes(scene.export(file_type='glb'))
  b=mesh.bounds
  records.append({'name':name,'file':f'terrain/{name}.glb','triangles':len(mesh.faces),'vertices':len(mesh.vertices), 'bounds':[[round(float(v),4) for v in r] for r in b], 'vertex_rgba':True})
(ROOT/'manifest.json').write_text(json.dumps({'asset_set':'Dogs of Gods / terrain v1','coordinate_system':'+Y up, +Z front','tile_footprint':.98,'thickness':.22,'count':12,'items':records},indent=2),encoding='utf-8')
for item in records: print(item['name'],item['triangles'],item['bounds'][0][1],item['bounds'][1][1])
