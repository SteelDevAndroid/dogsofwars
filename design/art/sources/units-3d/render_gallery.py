from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from generate_units import build
import matplotlib;matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
import numpy as np
names=['eclaireur','assaut','rempart','ouvrier','sentinelle','chasseur','bastion']
fig=plt.figure(figsize=(16,8),facecolor='#171c25')
for i,n in enumerate(names):
 for dormant in [False,True]:
  ax=fig.add_subplot(2,7,(int(dormant)*7)+i+1,projection='3d',computed_zorder=False)
  m=build(n,dormant)
  # collapse identical colors by face; avoid translucence
  facecols=m.visual.vertex_colors[m.faces[:,0],:3].astype(float)/255
  polygons=m.vertices[m.faces]
  collection=Poly3DCollection(polygons,facecolors=facecols,edgecolors=(.11,.14,.18,.48),linewidths=.24,zsort='average')
  ax.add_collection3d(collection)
  ax.set_xlim(-.30,.30);ax.set_ylim(-.30,.30);ax.set_zlim(0,.5)
  ax.set_box_aspect((1,1,1.15));ax.view_init(elev=23,azim=-72)
  ax.set_axis_off();ax.set_facecolor('#171c25')
  ax.set_title(n.upper()+('\nENDORMI' if dormant else '\nEVEILLE'),fontsize=9,color='#e5e4df',pad=-3)
  # matplotlib 3d coordinate xyz = model xyz, camera approx +z
fig.subplots_adjust(wspace=0,hspace=.06,left=.01,right=.99,top=.97,bottom=.02)
fig.savefig(Path(__file__).parent/'previews/units_gallery.png',dpi=150,facecolor=fig.get_facecolor());plt.close(fig)
# reverse angle niche detail, four wolves
fig=plt.figure(figsize=(12,3.8),facecolor='#171c25')
for i,n in enumerate(names[:4]):
 ax=fig.add_subplot(1,4,i+1,projection='3d');m=build(n,False)
 cols=m.visual.vertex_colors[m.faces[:,0],:3].astype(float)/255
 ax.add_collection3d(Poly3DCollection(m.vertices[m.faces],facecolors=cols,edgecolors=(.1,.12,.16,.4),linewidths=.24,zsort='average'))
 ax.set_xlim(-.3,.3);ax.set_ylim(-.3,.3);ax.set_zlim(0,.5);ax.set_box_aspect((1,1,1.1));ax.view_init(elev=19,azim=108);ax.set_axis_off();ax.set_facecolor('#171c25');ax.set_title(n.upper()+' - NICHE ARRIERE',color='#e5e4df',fontsize=9)
fig.subplots_adjust(wspace=0,left=.01,right=.99,top=.96,bottom=.04);fig.savefig(Path(__file__).parent/'previews/command_niches.png',dpi=150,facecolor=fig.get_facecolor())
