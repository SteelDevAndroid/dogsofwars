from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance, ImageOps
import os, math, random, json, io
ROOT='/mnt/data/dogsofgods_hors_carte'
SRC='/mnt/data/a_detailed_composite_game_asset_sheet_in_a_gritty.png'
base=Image.open(SRC).convert('RGB')
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf'
FONTS='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
COLD=(22,30,39); PALE=(233,228,213); RUST=(182,81,69)

def font(sz,b=True):return ImageFont.truetype(FONT if b else FONTS,sz)
def cover(im, wh, anchor=(.5,.5)):
    w,h=wh; sw,sh=im.size; s=max(w/sw,h/sh); nw,nh=round(sw*s),round(sh*s)
    temp=im.resize((nw,nh),Image.Resampling.LANCZOS)
    left=max(0,min(nw-w,int((nw-w)*anchor[0]))); top=max(0,min(nh-h,int((nh-h)*anchor[1])))
    return temp.crop((left,top,left+w,top+h))
def grade(img,over=.15):
    im=ImageEnhance.Contrast(img).enhance(1.08)
    tint=Image.new('RGB',im.size,(25,38,54)); return Image.blend(im,tint,over)
def edge_vignette(img):
    w,h=img.size
    mask=Image.new('L',(w,h)); px=mask.load()
    # generate mask smaller, upscale for efficiency
    s=Image.new('L',(100,100)); p=s.load()
    for y in range(100):
        for x in range(100):
            d=((x-50)/65)**2+((y-50)/65)**2
            p[x,y]=min(175, int(max(0,d)*135))
    m=s.resize((w,h),Image.Resampling.BILINEAR)
    return Image.composite(Image.new('RGB',(w,h),COLD),img,m)
def overlay_gradient(img, at='bottom', strength=220):
    w,h=img.size; l=Image.new('RGBA',(1,h)); p=l.load()
    for y in range(h):
        t=y/h if at=='bottom' else 1-y/h
        a=int(max(0,(t-.35)/.65)**1.6*strength)
        p[0,y]=(12,18,24,a)
    lay=l.resize((w,h)); return Image.alpha_composite(img.convert('RGBA'),lay)
def crop_panel(i):
    coords=[(12,128,597,394),(13,431,597,675),(13,716,598,960)]
    im=base.crop(coords[i]); return grade(im)
def title_text(im, center, main, sub=None, width=None):
    d=ImageDraw.Draw(im)
    w,h=im.size; f=font(round(w*.080 if w<h else h*.13))
    if width:
        while d.textbbox((0,0),main,font=f)[2]>width and f.size>12:f=font(f.size-2)
    tw=d.textbbox((0,0),main,font=f,stroke_width=0)[2]
    x=int(center[0]-tw/2); y=int(center[1]-f.size/2)
    d.text((x+2,y+3),main,font=f,fill=(7,9,12),stroke_width=4,stroke_fill=(7,9,12))
    d.text((x,y),main,font=f,fill=PALE)
    if sub:
        fs=font(max(12,int(f.size*.23)),False); sw=d.textbbox((0,0),sub,font=fs)[2]
        d.text((center[0]-sw/2,y+f.size+25),sub,font=fs,fill=(210,209,201))
    return im
# independent scene crops from generated contact sheet (not native-resolution paintings)
for idx,name in enumerate(['chronique_introduction','chronique_briefing','chronique_revelation']):
    src=crop_panel(idx)
    square=cover(src,(2560,2560), anchor=[(.47,.48),(.54,.5),(.53,.5)][idx]); square=edge_vignette(square)
    square.save(f'{ROOT}/illus/{name}.webp','WEBP',quality=94,method=6)
# portrait splash
src=crop_panel(0)
portrait=cover(src,(1440,2560),anchor=(.33,.47))
portrait=edge_vignette(portrait)
portrait=overlay_gradient(portrait,'bottom',225)
d=ImageDraw.Draw(portrait); d.line((190,1550,1250,1550),fill=RUST,width=7)
portrait=title_text(portrait,(720,1640),'DOGS OF GODS',width=1050)
portrait.convert('RGB').save(f'{ROOT}/illus/splash_portrait.png',optimize=True)
# landscape splash
src=crop_panel(2)
land=cover(src,(2560,1440),(.5,.52)); land=edge_vignette(land)
land=overlay_gradient(land,'bottom',200)
d=ImageDraw.Draw(land); d.line((710,935,1850,935),fill=RUST,width=6)
land=title_text(land,(1280,1050),'DOGS OF GODS',width=1400)
land.convert('RGB').save(f'{ROOT}/illus/splash_paysage.png',optimize=True)
# 432x432 launcher symbol as vector shapes programmatically, no third-party fonts
S=432
fg=Image.new('RGBA',(S,S),(0,0,0,0)); d=ImageDraw.Draw(fg)
# muted diamond drone, within central 288 diameter
points=[(216,79),(316,152),(286,282),(216,342),(146,282),(116,152)]
d.polygon(points,fill=(228,228,217,255)); d.line(points+[points[0]], fill=(26,30,37,255),width=14,joint='curve')
d.polygon([(216,110),(290,165),(267,250),(216,300),(165,250),(142,165)],fill=(80,95,105,255))
d.polygon([(216,110),(290,165),(216,195),(142,165)],fill=(183,190,187,255))
d.line((172,214,260,214),fill=(25,31,35,255),width=18)
d.polygon([(216,187),(247,216),(216,243),(185,216)],fill=(194,92,74,255))
d.line((181,275,216,306,251,275),fill=(19,28,35,255),width=13,joint='curve')
fg.save(f'{ROOT}/icons/ic_launcher_foreground.png')
bg=Image.new('RGBA',(S,S),(29,36,44,255)); dd=ImageDraw.Draw(bg)
for k in range(-432,800,54): dd.line((k,0,k-432,432), fill=(42,50,59,255),width=3)
dd.ellipse((51,51,381,381),outline=(94,104,112,255),width=4)
bg.save(f'{ROOT}/icons/ic_launcher_background.png')
mono=Image.new('RGBA',(S,S),(0,0,0,0)); dm=ImageDraw.Draw(mono)
dm.polygon(points,fill=(255,255,255,255)); dm.polygon([(172,216),(216,248),(260,216),(216,190)],fill=(0,0,0,0))
dm.line((181,275,216,306,251,275),fill=(0,0,0,0),width=14,joint='curve')
mono.save(f'{ROOT}/icons/ic_launcher_monochrome.png')
# legacy classic + playstore icon. solid square graphic, signature motif
com=Image.alpha_composite(bg,fg).convert('RGB')
com.resize((192,192),Image.Resampling.LANCZOS).save(f'{ROOT}/icons/icon_classique_192.png')
com.resize((512,512),Image.Resampling.LANCZOS).save(f'{ROOT}/store/icon_play_store_512.png',optimize=True)
# 1024x500 horizontal feature graphic (opaque)
thumb=cover(crop_panel(2),(1024,500),(.52,.52)); thumb=edge_vignette(thumb)
thumb=overlay_gradient(thumb,'bottom',220)
thumb=title_text(thumb,(512,352),'DOGS OF GODS',width=835)
thumb.convert('RGB').save(f'{ROOT}/store/graphique_presentation_1024x500.png',optimize=True)
# contact sheet
thumbs=[]
for filename in ['illus/splash_portrait.png','illus/splash_paysage.png','illus/chronique_introduction.webp','illus/chronique_briefing.webp','illus/chronique_revelation.webp','icons/ic_launcher_foreground.png','store/graphique_presentation_1024x500.png']:
    im=Image.open(f'{ROOT}/{filename}').convert('RGBA'); thumbs.append((filename,im))
can=Image.new('RGB',(1500,1180),(24,30,37)); d=ImageDraw.Draw(can)
d.text((40,23),'DOGS OF GODS  /  HORS CARTE',font=font(41),fill=PALE)
d.text((42,75),'ILLUSTRATIONS  •  ICÔNES ANDROID  •  PLAY STORE',font=font(21,False),fill=(171,183,192))
coords=[(40,140,300,720),(330,140,760,420),(790,140,1140,490),(1170,140,1460,490),(330,530,680,880),(720,540,970,790),(1010,570,1460,810)]
for (name,im),r in zip(thumbs,coords):
 x,y,x2,y2=r; t=cover(im,(x2-x,y2-y)); can.paste(t,(x,y), t if t.mode=='RGBA' else None)
 d.rectangle((x,y,x2,y2),outline=(120,127,132),width=2)
 d.text((x,y2+8),name.split('/')[-1],font=font(17,False),fill=PALE)
d.text((42,1087),'Concept artistique : science-fiction minérale et picturale · Captures d’écran réelles non incluses',font=font(19,False),fill=(192,194,197))
can.save(f'{ROOT}/previews/hors_carte_gallery.jpg',quality=91)
manifest=[]
for folder in ['illus','icons','store']:
 for fn in sorted(os.listdir(f'{ROOT}/{folder}')):
  im=Image.open(f'{ROOT}/{folder}/{fn}'); manifest.append({'path':f'{folder}/{fn}','dimensions':list(im.size),'mode':im.mode,'bytes':os.stat(f'{ROOT}/{folder}/{fn}').st_size})
with open(f'{ROOT}/manifest.json','w') as f:json.dump(manifest,f,indent=2,ensure_ascii=False)
print('Made',len(manifest),'assets',sum(i['bytes'] for i in manifest)/1024**2,'MB')
