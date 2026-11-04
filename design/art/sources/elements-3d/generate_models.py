#!/usr/bin/env python3
"""Procedural source: generate chapter 5 Godot GLB low-poly assets without textures."""
import os, math, json, zipfile
from pathlib import Path
import numpy as np
import trimesh

# Where the models are written: DOGS_OUT (a folder), else ./out next to this script. The files
# then go to assets/art/3d/ of the game.
OUT=Path(os.environ.get('DOGS_OUT', str(Path(__file__).resolve().parent/'out')))
GLB=OUT/'assets'/'art'/'3d'
GLB.mkdir(parents=True,exist_ok=True)
PALETTE={'unit':'#B4BBC3','neutral':'#7A848E','side':'#4E5862','shadow':'#1E2329','ruin':'#C8955A'}

def color(s,a=0):
    h=PALETTE.get(s,s).lstrip('#'); return tuple(int(h[i:i+2],16) for i in (0,2,4))+(int(255*a),)
def dark(c, factor=.72,alpha=None):
    return tuple(int(k*factor) for k in c[:3])+(c[3] if alpha is None else int(alpha*255),)

def regular(n,r,phase=0,aspect=1):
    return [(r*math.cos(phase+2*math.pi*i/n), r*math.sin(phase+2*math.pi*i/n)*aspect) for i in range(n)]
def subdivide(poly,num):
    out=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        for j in range(num):
            t=j/num
            out.append((a[0]*(1-t)+b[0]*t,a[1]*(1-t)+b[1]*t))
    return out
def area(poly):
    """Signed area of a polygon on (x, z): positive when its corners go by increasing angle (x=cos, z=sin)."""
    return sum(poly[i][0]*poly[(i+1)%len(poly)][1]-poly[(i+1)%len(poly)][0]*poly[i][1] for i in range(len(poly)))/2.0

# glTF 2.0: the front of a face is counter-clockwise seen from outside. The first delivery wrote the
# walls inside out and the caps of one polygon direction only; the walls and the caps now follow the
# direction of their polygon (fixed 2026-11-04, after a render in the game).
class Model:
    def __init__(self,name):self.name=name;self.v=[];self.f=[];self.cs=[]
    def tri(self,a,b,c,rgba):
        idx=len(self.v);self.v.extend([a,b,c]);self.f.append([idx,idx+1,idx+2]);self.cs.extend([rgba]*3)
    def slab(self, poly,y0,y1, top, side=None, bottom=False,top_mask=None, facet=False):
        # polygon on x,z, not x,y; positive y up
        n=len(poly); side=side or dark(top); up=area(poly)>0
        for i in range(n):
            j=(i+1)%n
            x,z=poly[i]; xx,zz=poly[j]
            a=(x,y0,z);b=(xx,y0,zz);c=(xx,y1,zz);d=(x,y1,z)
            cc=dark(side, (.90 if i%3==0 else 1.0)) if facet else side
            if up: self.tri(a,c,b,cc);self.tri(a,d,c,cc)
            else: self.tri(a,b,c,cc);self.tri(a,c,d,cc)
        tc=top if top_mask is None else top[:3]+(int(255*top_mask),)
        for i in range(n):
            j=(i+1)%n
            mid=(sum(p[0] for p in poly)/n,sum(p[1] for p in poly)/n)
            first,second=(j,i) if up else (i,j)
            self.tri((mid[0],y1,mid[1]),(poly[first][0],y1,poly[first][1]),(poly[second][0],y1,poly[second][1]),tc)
            if bottom:self.tri((mid[0],y0,mid[1]),(poly[second][0],y0,poly[second][1]),(poly[first][0],y0,poly[first][1]),side)
    def loft(self, base, top_poly,y0,y1,c_top,c_side,base_offset=(0,0),top_offset=(0,0),mask=None):
        n=len(base);assert len(top_poly)==n; up=area(base)>0
        for i in range(n):
            j=(i+1)%n
            a=(base[i][0]+base_offset[0],y0,base[i][1]+base_offset[1]);b=(base[j][0]+base_offset[0],y0,base[j][1]+base_offset[1])
            c=(top_poly[j][0]+top_offset[0],y1,top_poly[j][1]+top_offset[1]);d=(top_poly[i][0]+top_offset[0],y1,top_poly[i][1]+top_offset[1])
            shade=dark(c_side,.96 if i%4 else .86)
            if up: self.tri(a,c,b,shade);self.tri(a,d,c,shade)
            else: self.tri(a,b,c,shade);self.tri(a,c,d,shade)
        center=(top_offset[0],y1,top_offset[1]); tc=c_top[:3]+(int(mask*255) if mask is not None else c_top[3],)
        for i in range(n):
            j=(i+1)%n
            first,second=(j,i) if up else (i,j)
            self.tri(center,(top_poly[first][0]+top_offset[0],y1,top_poly[first][1]+top_offset[1]),(top_poly[second][0]+top_offset[0],y1,top_poly[second][1]+top_offset[1]),tc)
    def box(self,center,size,c,side=None,topmask=None):
        # x,z plane rectangles, built with 12 subdivided contour vertices
        x,y,z=center;dx,dy,dz=size
        p=subdivide([(-dx/2,-dz/2),(dx/2,-dz/2),(dx/2,dz/2),(-dx/2,dz/2)],3)
        shifted=[(q[0]+x,q[1]+z) for q in p]
        self.slab(shifted,y-dy/2,y+dy/2,c,side or dark(c),top_mask=topmask,facet=True)
    def mesh(self):
        mesh=trimesh.Trimesh(vertices=np.array(self.v,dtype=np.float32),faces=np.array(self.f,dtype=np.int64),process=False,validate=False)
        mesh.visual.vertex_colors=np.array(self.cs,dtype=np.uint8)
        return mesh
    def save(self):
        mesh=self.mesh();path=GLB/(self.name+'.glb');mesh.export(path,file_type='glb');return mesh

U=color('unit');N=color('neutral');S=color('side');R=color('ruin')

def make_node(level):
    m=Model('node_niveau_'+str(level))
    radii=[.42,.32,.215]
    for i in range(level):
        poly=subdivide(regular(6,radii[i],phase=math.pi/6),2)
        m.slab(poly,i*.05,(i+1)*.05,N,dark(N,.70),top_mask=1.0,facet=True)
    return m

def piece(m,x,y,z,dx,dy,dz,poly=None,color_=R):
    if poly is None:
        q=[(x-dx/2,z-dz/2),(x+dx/2,z-dz/2),(x+dx/2,z+dz/2),(x-dx/2,z+dz/2)]
        m.slab(q,y-dy/2,y+dy/2,color_,dark(color_,.72))
    else:m.loft([(a+x,b+z) for a,b in poly],[(a+x,b+z) for a,b in poly],y-dy/2,y+dy/2,color_,dark(color_,.70))

def make_ruin(kind):
    m=Model(kind)
    # Broken arcs from heavy connected fractured stone blocks. Deliberately incomplete.
    if 'arche' in kind:
        is_b='02' in kind
        for sx in [-1,1]:
            x=sx*(.25 if not is_b else .28)
            piece(m,x,.20,0,.13,.40,.17)
            piece(m,x-sx*.032,.435,0,.12,.12,.16)
            piece(m,x-sx*.085,.53,0,.16,.10,.16)
        if not is_b:
            piece(m,-.105,.61,0,.14,.09,.15)
            piece(m,.10,.65,0,.13,.08,.16)
        else:
            piece(m,-.115,.635,.02,.15,.09,.16)
            piece(m,.055,.63,-.015,.14,.10,.16)
            # break near right cap
        piece(m,-.285,.035,.19,.14,.07,.12)
        piece(m,.20,.032,-.19,.19,.06,.14)
    else:
        # Fragmented dome ring: polygonal angled blocks around a missing roof
        count=9
        for i in range(count):
            if i in (1,5,7):continue
            theta=2*math.pi*i/count
            x=.235*math.cos(theta); z=.235*math.sin(theta)
            h=.30+.36*math.sin(math.pi*(i+1)/(count+2))
            piece(m,x,h/2,z,.13,h,.13)
        # jagged surviving cap and spandrel
        piece(m,-.12,.63,.04,.16,.11,.15)
        piece(m,.03,.67,-.08,.14,.06,.13)
        piece(m,.21,.055,.23,.13,.11,.12)
    return m

def make_unit(name):
    m=Model('unit_'+name)
    guardian=name in ('sentinelle','chasseur','bastion')
    # platform: hex for meute, diamond for guardians, alpha=1 on top
    if guardian:
        base=subdivide([(0,-.255),(.235,0),(0,.255),(-.235,0)],4)
    else:
        base=subdivide(regular(6,.247,phase=math.pi/6),3)
    m.slab(base,0,.06,N,dark(N,.69),top_mask=1,facet=True)
    # 2nd major mass, more slender and taller for Guardians
    if guardian:
        hull=subdivide([(-.11,-.12),(.11,-.12),(.14,0),(.09,.14),(-.09,.14),(-.14,0)],3)
        top=subdivide([(-.07,-.08),(.07,-.08),(.10,0),(.06,.10),(-.06,.10),(-.10,0)],3)
        m.loft(hull,top,.06,.36,U,dark(U,.72),mask=0)
    else:
        hull=subdivide(regular(6,.161,phase=math.pi/6,aspect=.84),3)
        top=subdivide(regular(6,.127,phase=math.pi/6,aspect=.84),3)
        m.loft(hull,top,.06,.31,U,dark(U,.72),mask=0)
    # one feature per type; asymmetrically/front-oriented to ensure silhouette
    if name=='eclaireur':
        # upright mast, front-facing array
        m.box((0,.365,.11),(.046,.25,.05),U,topmask=0)
        m.box((0,.475,.135),(.15,.037,.045),N,topmask=0)
    elif name=='assaut':
        # broad forward blade (thin broad wedge), not an actual sharp weapon
        poly=subdivide([(-.13,.13),(.13,.13),(.07,.29),(-.07,.29)],3)
        m.loft(poly,poly,.22,.32,U,dark(U,.72),mask=0)
    elif name=='rempart':
        # heavy flat protective canopy
        m.box((0,.33,.055),(.405,.11,.29),U,topmask=0)
    elif name=='ouvrier':
        # two-pronged fork, extends toward +Z
        m.box((-.10,.34,.19),(.057,.135,.155),U,topmask=0)
        m.box((.10,.34,.19),(.057,.135,.155),U,topmask=0)
    elif name=='sentinelle':
        # forward pointed sensor crown
        poly=subdivide([(0,.265),(-.09,.095),(.09,.095)],6)
        m.loft(poly,poly,.32,.44,U,dark(U,.70),mask=0)
    elif name=='chasseur':
        # twin angular horns
        for sgn in (-1,1):
            poly=subdivide([(sgn*.16,.22),(sgn*.085,.095),(sgn*.07,.26)],6)
            m.loft(poly,poly,.30,.42,U,dark(U,.68),mask=0)
    elif name=='bastion':
        # crenellated armored upper form
        m.box((0,.40,.10),(.26,.10,.18),U,topmask=0)
        for x in (-.12,.12):m.box((x,.47,.12),(.055,.055,.07),N,topmask=0)
    # Simple eye facing +Z, reclaims faction tint
    eye=subdivide(regular(6,.055,phase=math.pi/6,aspect=.55),2)
    eye=[(a,b+.176) for a,b in eye]
    m.slab(eye,.285 if not guardian else .335,.317 if not guardian else .367,U,dark(U,.83),top_mask=1)
    # empty control recess, meute only: rear -Z (not visible from camera, but geometry optional)
    return m

models=[]
for level in (1,2,3):models.append(make_node(level))
for name in ('ruin_arche_brisee_01','ruin_arche_brisee_02','ruin_dome_brise_01'):models.append(make_ruin(name))
for name in ('eclaireur','assaut','rempart','ouvrier','sentinelle','chasseur','bastion'):models.append(make_unit(name))

report=[]
for m in models:
    raw=m.mesh()
    kind=m.name.split('_')[0]
    tri=len(raw.faces)
    bounds=raw.bounds.tolist()
    report.append({'name':m.name+'.glb','triangles':tri,'bounds':bounds,'color_alpha':[int(np.min(raw.visual.vertex_colors[:,3])),int(np.max(raw.visual.vertex_colors[:,3]))], 'file':str((GLB/(m.name+'.glb')).relative_to(OUT))})
    m.save()
print(json.dumps(report,indent=2))
(OUT/'model_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
