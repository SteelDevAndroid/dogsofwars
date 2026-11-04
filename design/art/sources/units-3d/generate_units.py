#!/usr/bin/env python3
"""Procedural flat-shaded sci-fi low-poly units with vertex RGBA masks for Godot."""
from pathlib import Path
import os, numpy as np, trimesh, math, json, hashlib
OUT=Path(os.environ.get('DOGS_OUT','out'));OUT.mkdir(parents=True,exist_ok=True)
SILVER=(180,187,195); DARK=(78,88,98); EDGE=(99,110,121)
class Model:
 def __init__(self):self.parts=[]
 def add(self,vertices,faces,color,mask=0):
  v=np.asarray(vertices,dtype=float); f=np.asarray(faces,dtype=int)
  # glTF: front faces are counter-clockwise seen from outside. Every part is convex, so a face
  # looking toward the part's centre is wound the wrong way: swap it.
  tri=v[f]; normal=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]); inward=np.einsum('ij,ij->i',normal,tri.mean(axis=1)-v.mean(axis=0))<0
  f=np.where(inward[:,None],f[:,[0,2,1]],f)
  mesh=trimesh.Trimesh(vertices=v,faces=f,process=False)
  rgba=np.tile(np.array([*color,255 if mask else 0],dtype=np.uint8),(len(v),1));mesh.visual.vertex_colors=rgba
  self.parts.append(mesh)
 def prism(self,n,rad,y0,y1,color=SILVER,mask=0,axis='hex',cz=0,rx=None,rz=None,phase=0):
  rx=rad if rx is None else rx;rz=rad if rz is None else rz
  angles=[2*math.pi*i/n+phase for i in range(n)]
  vb=[(rx*math.cos(a),y0,cz+rz*math.sin(a)) for a in angles]
  vt=[(rx*math.cos(a),y1,cz+rz*math.sin(a)) for a in angles]
  vs=vb+vt;fs=[]
  for i in range(1,n-1):fs.extend([[0,i+1,i],[n,n+i,n+i+1]])
  for i in range(n): j=(i+1)%n;fs.extend([[i,j,n+j],[i,n+j,n+i]])
  self.add(vs,fs,color,mask)
 def tapered(self,n,r0,r1,y0,y1,color=SILVER,mask=0,cz=0,phase=0,ellip=1):
  angles=[2*math.pi*i/n+phase for i in range(n)]
  vs=[(r0*math.cos(a),y0,cz+r0*math.sin(a)*ellip) for a in angles]+[(r1*math.cos(a),y1,cz+r1*math.sin(a)*ellip) for a in angles]
  fs=[]
  for i in range(1,n-1):fs.extend([[0,i+1,i],[n,n+i,n+i+1]])
  for i in range(n):j=(i+1)%n;fs.extend([[i,j,n+j],[i,n+j,n+i]])
  self.add(vs,fs,color,mask)
 def box(self,x0,x1,y0,y1,z0,z1,c=SILVER,mask=0):
  vs=[(x0,y0,z0),(x1,y0,z0),(x1,y0,z1),(x0,y0,z1),(x0,y1,z0),(x1,y1,z0),(x1,y1,z1),(x0,y1,z1)]
  f=[[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],[1,2,6],[1,6,5],[2,3,7],[2,7,6],[3,0,4],[3,4,7]]
  self.add(vs,f,c,mask)
 def wedge(self,points,c=SILVER,mask=0):
  # bottom triangle and top triangle supplied
  self.add(points,[[0,2,1],[3,4,5],[0,1,4],[0,4,3],[1,2,5],[1,5,4],[2,0,3],[2,3,5]],c,mask)
 def seam(self,y,r,mask=0): self.prism(8,r,y,y+.008,EDGE,mask)
 def mesh(self):
  mesh=trimesh.util.concatenate(self.parts)
  return mesh

def build(t,asleep=False):
 m=Model(); guardian=t in ('sentinelle','chasseur','bastion'); p=0 if not guardian else math.pi/4
 basecol=(75,85,96) if asleep else (134,146,157)
 bodycol=DARK if asleep else SILVER
 crestcol=(93,104,115) if asleep else (208,213,216)
 # pedestal: differentiated hexagon/diamond, upper surface marked tint; radius <= .30
 m.prism(4 if guardian else 6,.234 if guardian else .228,0,.042,basecol,1,phase=p)
 m.prism(8,.184,.039,.056,EDGE,1)
 # foot collar + primary body: tapered, cut planes, back center for recess
 m.tapered(8,.168,.132,.052,.215 if guardian else .194,bodycol,0,ellip=.83)
 m.seam(.095,.17,1);m.seam(.165,.147,0)
 if guardian:
  m.tapered(8,.129,.107,.205,.32,bodycol,0,ellip=.88)
  m.prism(8,.11,.313,.331,EDGE,0)
 else:
  m.tapered(8,.125,.108,.188,.284,bodycol,0,ellip=.82)
  m.prism(8,.111,.283,.301,EDGE,0)
 # front jewel / eye (positive Z)
 m.box(-.036,.036,.235,.265,.105,.141,crestcol,1)
 m.box(-.021,.021,.243,.260,.142,.151,EDGE,1)
 if not guardian:
  # Rear-mounted recessed command socket: four rim battens framing a dark cavity at Z < 0.
  # No protruding 'operator' inside; cavity face lies 0.027 deeper than visible lip.
  m.box(-.065,.065,.149,.227,-.143,-.139,(35,43,53),0)
  m.box(-.074,-.056,.141,.236,-.166,-.136,crestcol,0)
  m.box(.056,.074,.141,.236,-.166,-.136,crestcol,0)
  m.box(-.056,.056,.220,.236,-.167,-.136,crestcol,0)
  m.box(-.056,.056,.137,.152,-.166,-.136,crestcol,0)
  m.box(-.047,.047,.155,.161,-.158,-.147,EDGE,0)
  # two empty docking contact points recessed at bottom (not pilot/operator)
  for x in [-.032,.032]:m.box(x-.009,x+.009,.170,.183,-.146,-.138,EDGE,0)
 # signature with rested/folded state
 level=.272 if asleep else .377
 if t=='eclaireur':
  m.box(-.020,.020,.261 if asleep else .282,level,-.017,.020,crestcol,1)
  m.tapered(6,.051,.012,level-.012,level+.055 if not asleep else level+.023,crestcol,1)
  for x in [-.096,.096]:m.box(x-.009,x+.009,.195,.28 if asleep else .34,-.015,.018,EDGE,0)
 elif t=='assaut':
  m.box(-.094,.094,.284,.311,.055,.081,crestcol,1)
  m.wedge([(-.061,.285,.08),(.061,.285,.08),(0,.285,.226),(-.061,.334 if not asleep else .308,.08),(.061,.334 if not asleep else .308,.08),(0,.334 if not asleep else .308,.226)],crestcol,1)
  m.box(-.082,.082,.316 if not asleep else .302,.333 if not asleep else .310,-.013,.055,EDGE,1)
 elif t=='rempart':
  m.box(-.151,.151,.281,.305,-.112,.131,crestcol,1)
  for x in [-.142,.132]:m.box(x,x+.01,.304,.344 if not asleep else .321,-.093,.101,EDGE,0)
  m.box(-.115,.115,.305,.333 if not asleep else .312,.099,.118,basecol,1)
 elif t=='ouvrier':
  m.box(-.024,.024,.289,level+.035,-.008,.022,crestcol,1)
  for x in [-.102,.102]:
   m.box(x-.020,x+.020,level-.014,level+.054 if asleep else level+.109,-.007,.025,crestcol,1)
  m.box(-.105,.105,level-.027,level-.005,-.008,.022,EDGE,0)
 elif t=='sentinelle':
  m.tapered(4,.069,.010,.330,level+.086 if not asleep else level+.036,crestcol,1,phase=math.pi/4)
  for x in [-.103,.103]:m.box(x-.019,x+.019,.289,.35 if not asleep else .310,-.01,.018,crestcol,1)
 elif t=='chasseur':
  for x in [-.104,.104]:
   m.wedge([(x-.029,.296,-.040),(x+.029,.296,-.04),(x,.296,.081),
      (x-.025,level+.075 if not asleep else .321,-.034),(x+.025,level+.075 if not asleep else .321,-.034),(x,level+.075 if not asleep else .321,.064)],crestcol,1)
  m.box(-.054,.054,.321,.347 if not asleep else .329,.099,.140,crestcol,1)
 elif t=='bastion':
  m.box(-.145,.145,.315,.351 if not asleep else .329,-.11,.106,crestcol,1)
  for x in [-.126,0,.126]:
   m.box(x-.027,x+.027,.35 if not asleep else .329,.423 if not asleep else .356,-.094,.075,crestcol,1)
  m.box(-.090,.090,.359 if not asleep else .335,.370 if not asleep else .345,.092,.122,EDGE,0)
 return m.mesh()

if __name__=='__main__':
 info=[]
 for t in ['eclaireur','assaut','rempart','ouvrier','sentinelle','chasseur','bastion']:
  for dormant in [False,True]:
   mesh=build(t,dormant); name=f'unit_{t}'+('_endormi' if dormant else '')+'.glb'
   tris=len(mesh.faces); bounds=mesh.bounds
   assert 150<=tris<=400,(name,tris)
   assert bounds[1,1]<=.50,(name,bounds[1,1]);assert bounds[0,1]>=0
   assert max(np.hypot(mesh.vertices[:,0],mesh.vertices[:,2]))<=.30,(name,bounds)
   mesh.export(OUT/name,file_type='glb')
   info.append(dict(file=name,triangles=tris,vertices=len(mesh.vertices),bounds=np.round(bounds,3).tolist(),bytes=(OUT/name).stat().st_size,sha256=hashlib.sha256((OUT/name).read_bytes()).hexdigest()))
 (OUT/'unit_manifest.json').write_text(json.dumps(info,indent=2,ensure_ascii=False))
 print('\n'.join(f'{i["file"]}: {i["triangles"]} triangles' for i in info))
